import Foundation

#if os(iOS)
import UIKit
#endif

enum MobileDisplayEDRUnavailableReason:
    String,
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case platformUnsupported = "platform-unsupported"
    case windowScreenUnavailable = "window-screen-unavailable"
    case observationFailed = "observation-failed"
    case invalidated
}

enum MobileDisplayEDRValidationError:
    String,
    Codable,
    Error,
    Equatable,
    Hashable,
    Sendable
{
    case invalidDisplayGeneration = "invalid-display-generation"
    case invalidPotentialHeadroom = "invalid-potential-headroom"
    case invalidCurrentHeadroom = "invalid-current-headroom"
    case currentHeadroomExceedsPotential =
        "current-headroom-exceeds-potential"
}

enum MobileDisplayEDRCapability:
    String,
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case sdr
    case edrCapable = "edr-capable"
}

struct MobileDisplayEDRHeadroom: Equatable, Hashable, Sendable {
    let potential: Double
    let current: Double

    fileprivate init(potential: Double, current: Double) {
        self.potential = potential
        self.current = current
    }

    static let conservativeSDR = MobileDisplayEDRHeadroom(
        potential: 1,
        current: 1
    )

    var displayHeadroom: DisplayHeadroom {
        DisplayHeadroom(
            potential: potential,
            current: current,
            reference: 0
        )
    }
}

struct MobileDisplayEDRReading: Equatable, Sendable {
    let displayGeneration: UInt64
    let potentialHeadroom: Double
    let currentHeadroom: Double
}

struct MobileDisplayEDRHeadroomReading: Equatable, Sendable {
    let potential: Double
    let current: Double
}

enum MobileDisplayEDRSample: Equatable, Sendable {
    case unknown
    case detached
    case unavailable(MobileDisplayEDRUnavailableReason)
    case attached(MobileDisplayEDRReading)
}

struct MobileDisplayEDRAvailableState: Equatable, Hashable, Sendable {
    let display: MobileDisplayGeneration
    let capability: MobileDisplayEDRCapability
    let headroom: MobileDisplayEDRHeadroom

    fileprivate init(
        display: MobileDisplayGeneration,
        capability: MobileDisplayEDRCapability,
        headroom: MobileDisplayEDRHeadroom
    ) {
        self.display = display
        self.capability = capability
        self.headroom = headroom
    }
}

enum MobileDisplayEDRState: Equatable, Hashable, Sendable {
    case unknown
    case detached
    case unavailable(MobileDisplayEDRUnavailableReason)
    case available(MobileDisplayEDRAvailableState)
    case sdrFallback(
        display: MobileDisplayGeneration?,
        reason: MobileDisplayEDRValidationError
    )

    var display: MobileDisplayGeneration? {
        switch self {
        case let .available(state):
            state.display
        case let .sdrFallback(display, _):
            display
        case .unknown, .detached, .unavailable:
            nil
        }
    }

    var capability: MobileDisplayEDRCapability? {
        guard case let .available(state) = self else { return nil }
        return state.capability
    }

    var headroom: MobileDisplayEDRHeadroom? {
        switch self {
        case let .available(state):
            state.headroom
        case .sdrFallback:
            .conservativeSDR
        case .unknown, .detached, .unavailable:
            nil
        }
    }

    var usesConservativeSDRFallback: Bool {
        guard case .sdrFallback = self else { return false }
        return true
    }
}

@MainActor
struct MobileDisplayEDRWindowReader<Window: AnyObject, Screen: AnyObject> {
    typealias ScreenResolver = @MainActor (Window) -> Screen?
    typealias HeadroomReader = @MainActor (
        Screen
    ) throws -> MobileDisplayEDRHeadroomReading

    private let screenResolver: ScreenResolver
    private let headroomReader: HeadroomReader

    init(
        screenResolver: @escaping ScreenResolver,
        headroomReader: @escaping HeadroomReader
    ) {
        self.screenResolver = screenResolver
        self.headroomReader = headroomReader
    }

    func read(
        window: Window?,
        displayGeneration: MobileDisplayGeneration?
    ) -> MobileDisplayEDRState {
        guard let window,
              let screen = screenResolver(window) else {
            return .detached
        }
        guard let displayGeneration else {
            return .sdrFallback(
                display: nil,
                reason: .invalidDisplayGeneration
            )
        }

        do {
            let headroom = try headroomReader(screen)
            return MobileDisplayEDRStateNormalizer.normalize(.attached(
                MobileDisplayEDRReading(
                    displayGeneration: displayGeneration.rawValue,
                    potentialHeadroom: headroom.potential,
                    currentHeadroom: headroom.current
                )
            ))
        } catch {
            return .unavailable(.observationFailed)
        }
    }
}

#if os(iOS)
extension MobileDisplayEDRWindowReader
where Window == UIWindow, Screen == UIScreen {
    static var actualWindow: Self {
        Self(
            screenResolver: { $0.screen },
            headroomReader: {
                MobileDisplayEDRHeadroomReading(
                    potential: Double($0.potentialEDRHeadroom),
                    current: Double($0.currentEDRHeadroom)
                )
            }
        )
    }
}
#endif

struct MobileDisplayEDRNotificationNames: Equatable, Sendable {
    let modeDidChange: Notification.Name
    let brightnessDidChange: Notification.Name
}

enum MobileDisplayEDRResampleReason: Equatable, Sendable {
    case attachment
    case layout
    case traits
    case foreground
    case screenMode
    case brightness
}

enum MobileDisplayEDRObserverOutcome: Equatable, Sendable {
    case published
    case unchanged
    case staleSurfaceGeneration
    case revisionExhausted
    case invalidated
    case alreadyInvalidated
}

private final class MobileDisplayEDRObserverTokens: @unchecked Sendable {
    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter) {
        self.notificationCenter = notificationCenter
    }

    func replace(_ observers: [NSObjectProtocol]) {
        removeAll()
        self.observers = observers
    }

    func removeAll() {
        observers.forEach(notificationCenter.removeObserver)
        observers.removeAll()
    }

    deinit {
        removeAll()
    }
}

@MainActor
final class MobileDisplayEDRObserver<Window: AnyObject, Screen: AnyObject> {
    typealias ScreenResolver = @MainActor (Window) -> Screen?
    typealias Reader = @MainActor (
        Window?,
        MobileDisplayGeneration?
    ) -> MobileDisplayEDRState
    typealias Handler = @MainActor (MobileDisplayEDRSnapshot) -> Void

    let surfaceGeneration: MobileSceneSurfaceGeneration
    var currentWindow: Window? { window }
    var currentScreen: Screen? { screen }
    var currentSnapshot: MobileDisplayEDRSnapshot? { publisher.snapshot }

    private let notificationCenter: NotificationCenter
    private let observerTokens: MobileDisplayEDRObserverTokens
    private let names: MobileDisplayEDRNotificationNames
    private let screenResolver: ScreenResolver
    private weak var window: Window?
    private weak var screen: Screen?
    private var displayGeneration: MobileDisplayGeneration?
    private var observationID: UUID?
    private var reader: Reader?
    private var handler: Handler?
    private var publisher: MobileDisplayEDRSnapshotPublisher
    private var isInvalidated = false

    init(
        surfaceGeneration: MobileSceneSurfaceGeneration,
        notificationCenter: NotificationCenter,
        names: MobileDisplayEDRNotificationNames,
        screenResolver: @escaping ScreenResolver,
        reader: @escaping Reader,
        handler: @escaping Handler
    ) {
        self.surfaceGeneration = surfaceGeneration
        self.notificationCenter = notificationCenter
        observerTokens = MobileDisplayEDRObserverTokens(
            notificationCenter: notificationCenter
        )
        self.names = names
        self.screenResolver = screenResolver
        self.reader = reader
        self.handler = handler
        publisher = MobileDisplayEDRSnapshotPublisher(
            surfaceGeneration: surfaceGeneration
        )
    }

    @discardableResult
    func attach(
        window candidateWindow: Window,
        screen candidateScreen: Screen,
        displayGeneration candidateDisplayGeneration:
            MobileDisplayGeneration?,
        surfaceGeneration candidateSurfaceGeneration:
            MobileSceneSurfaceGeneration,
        reason: MobileDisplayEDRResampleReason
    ) -> MobileDisplayEDRObserverOutcome {
        guard candidateSurfaceGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        guard screenResolver(candidateWindow) === candidateScreen else {
            stopObserving()
            return publish(.detached)
        }

        if window !== candidateWindow || screen !== candidateScreen {
            stopObserving()
            window = candidateWindow
            screen = candidateScreen
            let nextObservationID = UUID()
            observationID = nextObservationID
            observerTokens.replace([
                observe(
                    name: names.modeDidChange,
                    screen: candidateScreen,
                    observationID: nextObservationID,
                    reason: .screenMode
                ),
                observe(
                    name: names.brightnessDidChange,
                    screen: candidateScreen,
                    observationID: nextObservationID,
                    reason: .brightness
                )
            ])
        }
        displayGeneration = candidateDisplayGeneration
        return resample(reason, surfaceGeneration: candidateSurfaceGeneration)
    }

    @discardableResult
    func resample(
        _ reason: MobileDisplayEDRResampleReason,
        surfaceGeneration candidateSurfaceGeneration:
            MobileSceneSurfaceGeneration
    ) -> MobileDisplayEDRObserverOutcome {
        guard candidateSurfaceGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        guard let window,
              let screen,
              screenResolver(window) === screen else {
            stopObserving()
            return publish(.detached)
        }
        guard let reader else {
            return publish(.unavailable(.observationFailed))
        }

        _ = reason
        return publish(reader(window, displayGeneration))
    }

    @discardableResult
    func detach(
        surfaceGeneration candidateSurfaceGeneration:
            MobileSceneSurfaceGeneration
    ) -> MobileDisplayEDRObserverOutcome {
        guard candidateSurfaceGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        stopObserving()
        return publish(.detached)
    }

    @discardableResult
    func invalidate(
        surfaceGeneration candidateSurfaceGeneration:
            MobileSceneSurfaceGeneration
    ) -> MobileDisplayEDRObserverOutcome {
        guard candidateSurfaceGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }

        isInvalidated = true
        stopObserving()
        reader = nil
        let outcome = publish(.unavailable(.invalidated))
        handler = nil
        return outcome == .revisionExhausted ? outcome : .invalidated
    }

    private func observe(
        name: Notification.Name,
        screen: Screen,
        observationID: UUID,
        reason: MobileDisplayEDRResampleReason
    ) -> NSObjectProtocol {
        notificationCenter.addObserver(
            forName: name,
            object: screen,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.receive(
                    observationID: observationID,
                    reason: reason
                )
            }
        }
    }

    private func receive(
        observationID candidateObservationID: UUID,
        reason: MobileDisplayEDRResampleReason
    ) {
        guard !isInvalidated,
              observationID == candidateObservationID,
              screen != nil else {
            return
        }
        _ = resample(reason, surfaceGeneration: surfaceGeneration)
    }

    private func stopObserving() {
        observerTokens.removeAll()
        observationID = nil
        displayGeneration = nil
        window = nil
        screen = nil
    }

    private func publish(
        _ state: MobileDisplayEDRState
    ) -> MobileDisplayEDRObserverOutcome {
        switch publisher.update(
            state,
            surfaceGeneration: surfaceGeneration
        ) {
        case .unchanged:
            return .unchanged
        case let .published(snapshot):
            handler?(snapshot)
            return .published
        case .staleSurfaceGeneration:
            return .staleSurfaceGeneration
        case .revisionExhausted:
            stopObserving()
            return .revisionExhausted
        }
    }
}

#if os(iOS)
extension MobileDisplayEDRNotificationNames {
    static let current = MobileDisplayEDRNotificationNames(
        modeDidChange: UIScreen.modeDidChangeNotification,
        brightnessDidChange: UIScreen.brightnessDidChangeNotification
    )
}
#endif

struct MobileDisplayEDREventEnvelope: Equatable, Sendable {
    let surfaceGeneration: MobileSceneSurfaceGeneration
    let sample: MobileDisplayEDRSample
}

struct MobileDisplayEDRSnapshot: Equatable, Sendable {
    let surfaceGeneration: MobileSceneSurfaceGeneration
    let revision: HDRDisplayRevision
    let state: MobileDisplayEDRState
    let renderSnapshot: HDRDisplaySnapshot?

    fileprivate init(
        surfaceGeneration: MobileSceneSurfaceGeneration,
        revision: HDRDisplayRevision,
        state: MobileDisplayEDRState,
        renderSnapshot: HDRDisplaySnapshot?
    ) {
        self.surfaceGeneration = surfaceGeneration
        self.revision = revision
        self.state = state
        self.renderSnapshot = renderSnapshot
    }
}

enum MobileDisplayEDRPublicationOutcome: Equatable, Sendable {
    case unchanged
    case published(MobileDisplayEDRSnapshot)
    case staleSurfaceGeneration
    case revisionExhausted
}

struct MobileDisplayEDRSnapshotPublisher: Sendable {
    static let maximumHeadroom =
        MobileDisplayEDRStateNormalizer.maximumHeadroom

    let surfaceGeneration: MobileSceneSurfaceGeneration
    private(set) var revision: HDRDisplayRevision
    private(set) var snapshot: MobileDisplayEDRSnapshot?
    private(set) var isRevisionExhausted = false

    private var state: MobileDisplayEDRState?

    init(
        surfaceGeneration: MobileSceneSurfaceGeneration,
        initialRevision: HDRDisplayRevision = HDRDisplayRevision(rawValue: 0)
    ) {
        self.surfaceGeneration = surfaceGeneration
        revision = initialRevision
    }

    @discardableResult
    mutating func update(
        _ envelope: MobileDisplayEDREventEnvelope
    ) -> MobileDisplayEDRPublicationOutcome {
        update(
            MobileDisplayEDRStateNormalizer.normalize(envelope.sample),
            surfaceGeneration: envelope.surfaceGeneration
        )
    }

    @discardableResult
    mutating func update(
        _ nextState: MobileDisplayEDRState,
        surfaceGeneration candidateSurfaceGeneration:
            MobileSceneSurfaceGeneration
    ) -> MobileDisplayEDRPublicationOutcome {
        guard candidateSurfaceGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isRevisionExhausted else { return .revisionExhausted }

        let nextState = MobileDisplayEDRStateNormalizer.normalize(
            nextState
        )
        guard nextState != state else { return .unchanged }

        let nextRevision = revision.rawValue.addingReportingOverflow(1)
        guard !nextRevision.overflow else {
            state = nil
            snapshot = nil
            isRevisionExhausted = true
            return .revisionExhausted
        }

        revision = HDRDisplayRevision(rawValue: nextRevision.partialValue)
        state = nextState
        let nextSnapshot = MobileDisplayEDRSnapshot(
            surfaceGeneration: surfaceGeneration,
            revision: revision,
            state: nextState,
            renderSnapshot: Self.makeRenderSnapshot(
                state: nextState,
                revision: revision
            )
        )
        snapshot = nextSnapshot
        return .published(nextSnapshot)
    }

    private static func makeRenderSnapshot(
        state: MobileDisplayEDRState,
        revision: HDRDisplayRevision
    ) -> HDRDisplaySnapshot? {
        guard let headroom = state.headroom else { return nil }
        return HDRDisplaySnapshot(
            revision: revision,
            displayID: nil,
            headroom: headroom.displayHeadroom
        )
    }
}

private enum MobileDisplayEDRStateNormalizer {
    static let maximumHeadroom =
        HDRLuminanceMapping.maximumCurrentHeadroom

    static func normalize(
        _ sample: MobileDisplayEDRSample
    ) -> MobileDisplayEDRState {
        switch sample {
        case .unknown:
            return .unknown
        case .detached:
            return .detached
        case let .unavailable(reason):
            return .unavailable(reason)
        case let .attached(reading):
            guard let display = MobileDisplayGeneration(
                rawValue: reading.displayGeneration
            ) else {
                return .sdrFallback(
                    display: nil,
                    reason: .invalidDisplayGeneration
                )
            }

            let potential: Double
            do {
                potential = try normalizeHeadroom(
                    reading.potentialHeadroom,
                    invalidReason: .invalidPotentialHeadroom
                )
            } catch let error as MobileDisplayEDRValidationError {
                return .sdrFallback(display: display, reason: error)
            } catch {
                return .sdrFallback(
                    display: display,
                    reason: .invalidPotentialHeadroom
                )
            }

            let current: Double
            do {
                current = try normalizeHeadroom(
                    reading.currentHeadroom,
                    invalidReason: .invalidCurrentHeadroom
                )
            } catch let error as MobileDisplayEDRValidationError {
                return .sdrFallback(display: display, reason: error)
            } catch {
                return .sdrFallback(
                    display: display,
                    reason: .invalidCurrentHeadroom
                )
            }

            guard current <= potential else {
                return .sdrFallback(
                    display: display,
                    reason: .currentHeadroomExceedsPotential
                )
            }

            let headroom = MobileDisplayEDRHeadroom(
                potential: potential,
                current: current
            )
            return .available(MobileDisplayEDRAvailableState(
                display: display,
                capability: potential > 1 ? .edrCapable : .sdr,
                headroom: headroom
            ))
        }
    }

    static func normalize(
        _ state: MobileDisplayEDRState
    ) -> MobileDisplayEDRState {
        switch state {
        case .unknown:
            return .unknown
        case .detached:
            return .detached
        case let .available(available):
            return normalize(.attached(MobileDisplayEDRReading(
                displayGeneration: available.display.rawValue,
                potentialHeadroom: available.headroom.potential,
                currentHeadroom: available.headroom.current
            )))
        case let .sdrFallback(display, reason):
            return .sdrFallback(display: display, reason: reason)
        case let .unavailable(reason):
            return .unavailable(reason)
        }
    }

    private static func normalizeHeadroom(
        _ value: Double,
        invalidReason: MobileDisplayEDRValidationError
    ) throws -> Double {
        guard value.isFinite,
              value >= 0,
              value <= maximumHeadroom else {
            throw invalidReason
        }
        return max(1, value)
    }
}
