import Foundation

#if os(iOS) || os(tvOS) || os(visionOS)
import AVFAudio
#endif

struct SpatialAudioRouteCapabilityState: Codable, Equatable, Hashable, Sendable {
    let outputAvailable: Bool
    let systemSpatialSupport: SpatialAudioRouteSupport
    let currentOutputChannelCount: Int
    let maximumOutputChannelCount: Int

    init(
        outputAvailable: Bool,
        systemSpatialSupport: SpatialAudioRouteSupport,
        currentOutputChannelCount: Int,
        maximumOutputChannelCount: Int
    ) {
        self.outputAvailable = outputAvailable
        self.systemSpatialSupport = systemSpatialSupport
        self.currentOutputChannelCount = currentOutputChannelCount
        self.maximumOutputChannelCount = maximumOutputChannelCount
    }

    init(_ snapshot: SpatialAudioRouteCapabilitySnapshot) {
        self.init(
            outputAvailable: snapshot.outputAvailable,
            systemSpatialSupport: snapshot.systemSpatialSupport,
            currentOutputChannelCount: snapshot.currentOutputChannelCount,
            maximumOutputChannelCount: snapshot.maximumOutputChannelCount
        )
    }

    func snapshot(
        revision: SpatialAudioSemanticRevision
    ) -> SpatialAudioRouteCapabilitySnapshot {
        SpatialAudioRouteCapabilitySnapshot(
            revision: revision,
            outputAvailable: outputAvailable,
            systemSpatialSupport: systemSpatialSupport,
            currentOutputChannelCount: currentOutputChannelCount,
            maximumOutputChannelCount: maximumOutputChannelCount
        )
    }
}

protocol SpatialAudioRouteCapabilityReading: Sendable {
    func currentRouteCapability() -> SpatialAudioRouteCapabilityState
}

final class MobileAudioSessionRouteCapabilityReader:
    SpatialAudioRouteCapabilityReading,
    @unchecked Sendable
{
    private let adapter: any MobileAudioSessionApplying

    init(adapter: any MobileAudioSessionApplying) {
        self.adapter = adapter
    }

    func currentRouteCapability() -> SpatialAudioRouteCapabilityState {
        let snapshot = adapter.currentSnapshot()
        return SpatialAudioRouteCapabilityState(
            outputAvailable: snapshot.outputAvailable,
            systemSpatialSupport: snapshot.systemSpatialSupport,
            currentOutputChannelCount: snapshot.currentOutputChannelCount,
            maximumOutputChannelCount: snapshot.maximumOutputChannelCount
        )
    }
}

final class AudioEngineRouteCapabilityReader:
    SpatialAudioRouteCapabilityReading,
    @unchecked Sendable
{
    private let engineClient: any AudioEngineClient

    init(engineClient: any AudioEngineClient) {
        self.engineClient = engineClient
    }

    func currentRouteCapability() -> SpatialAudioRouteCapabilityState {
        engineClient.currentSpatialRouteCapability()
    }
}

enum SpatialAudioInterruptionState: String, Codable, Hashable, Sendable {
    case active
    case interrupted
}

enum SpatialAudioMediaServicesState: String, Codable, Hashable, Sendable {
    case available
    case lost
    case reset
}

struct SpatialAudioRouteSemanticState: Codable, Equatable, Hashable, Sendable {
    let route: SpatialAudioRouteCapabilityState
    let interruption: SpatialAudioInterruptionState
    let mediaServices: SpatialAudioMediaServicesState
}

enum SpatialAudioRouteMonitorTrigger: Equatable, Hashable, Sendable {
    case initial
    case routeChanged
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    case mediaServicesLost
    case mediaServicesReset
    case spatialPlaybackCapabilityChanged
    case refresh
}

struct SpatialAudioRouteMonitorSnapshot: Equatable, Hashable, Sendable {
    let revision: SpatialAudioSemanticRevision
    let state: SpatialAudioRouteSemanticState
    let trigger: SpatialAudioRouteMonitorTrigger

    var route: SpatialAudioRouteCapabilitySnapshot {
        state.route.snapshot(revision: revision)
    }
}

enum SpatialAudioRouteMonitorEvent: Equatable, Hashable, Sendable {
    case routeChanged
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    case mediaServicesLost
    case mediaServicesReset
    case spatialPlaybackCapabilityChanged
    case refresh

    fileprivate var trigger: SpatialAudioRouteMonitorTrigger {
        switch self {
        case .routeChanged:
            .routeChanged
        case .interruptionBegan:
            .interruptionBegan
        case let .interruptionEnded(shouldResume):
            .interruptionEnded(shouldResume: shouldResume)
        case .mediaServicesLost:
            .mediaServicesLost
        case .mediaServicesReset:
            .mediaServicesReset
        case .spatialPlaybackCapabilityChanged:
            .spatialPlaybackCapabilityChanged
        case .refresh:
            .refresh
        }
    }

    fileprivate var refreshesRouteCapability: Bool {
        switch self {
        case .routeChanged, .mediaServicesReset,
             .spatialPlaybackCapabilityChanged, .refresh:
            true
        case .interruptionBegan, .interruptionEnded, .mediaServicesLost:
            false
        }
    }
}

protocol SpatialAudioRouteMonitorEventSourcing: AnyObject, Sendable {
    func start(
        handler: @escaping @Sendable (SpatialAudioRouteMonitorEvent) -> Void
    )
    func stop()
}

struct SpatialAudioPlatformNotificationNames: Equatable, Sendable {
    let routeChange: Notification.Name?
    let interruption: Notification.Name?
    let mediaServicesLost: Notification.Name?
    let mediaServicesReset: Notification.Name?
    let spatialPlaybackCapabilityChange: Notification.Name?

    static var current: SpatialAudioPlatformNotificationNames {
        #if os(iOS) || os(tvOS) || os(visionOS)
        SpatialAudioPlatformNotificationNames(
            routeChange: AVAudioSession.routeChangeNotification,
            interruption: AVAudioSession.interruptionNotification,
            mediaServicesLost:
                AVAudioSession.mediaServicesWereLostNotification,
            mediaServicesReset:
                AVAudioSession.mediaServicesWereResetNotification,
            spatialPlaybackCapabilityChange:
                AVAudioSession.spatialPlaybackCapabilitiesChangedNotification
        )
        #else
        SpatialAudioPlatformNotificationNames(
            routeChange: nil,
            interruption: nil,
            mediaServicesLost: nil,
            mediaServicesReset: nil,
            spatialPlaybackCapabilityChange: nil
        )
        #endif
    }
}

final class SpatialAudioPlatformNotificationSource:
    SpatialAudioRouteMonitorEventSourcing,
    @unchecked Sendable
{
    private struct ObservationState {
        var generation: UUID?
        var handler: (@Sendable (SpatialAudioRouteMonitorEvent) -> Void)?
        var observers: [NSObjectProtocol] = []
    }

    private let notificationCenter: NotificationCenter
    private let observedObject: AnyObject?
    private let names: SpatialAudioPlatformNotificationNames
    private let lock = NSLock()
    private var state = ObservationState()

    convenience init() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        self.init(
            notificationCenter: .default,
            observedObject: AVAudioSession.sharedInstance(),
            names: .current
        )
        #else
        self.init(
            notificationCenter: .default,
            observedObject: nil,
            names: .current
        )
        #endif
    }

    init(
        notificationCenter: NotificationCenter,
        observedObject: AnyObject?,
        names: SpatialAudioPlatformNotificationNames
    ) {
        self.notificationCenter = notificationCenter
        self.observedObject = observedObject
        self.names = names
    }

    deinit {
        stop()
    }

    func start(
        handler: @escaping @Sendable (SpatialAudioRouteMonitorEvent) -> Void
    ) {
        stop()
        let generation = UUID()
        lock.withLock {
            state.generation = generation
            state.handler = handler
        }

        var observers: [NSObjectProtocol] = []
        if let name = names.routeChange {
            observers.append(observe(name: name, generation: generation) {
                _ in .routeChanged
            })
        }
        if let name = names.interruption {
            observers.append(observe(name: name, generation: generation) {
                Self.interruptionEvent(from: $0)
            })
        }
        if let name = names.mediaServicesLost {
            observers.append(observe(name: name, generation: generation) {
                _ in .mediaServicesLost
            })
        }
        if let name = names.mediaServicesReset {
            observers.append(observe(name: name, generation: generation) {
                _ in .mediaServicesReset
            })
        }
        if let name = names.spatialPlaybackCapabilityChange {
            observers.append(observe(name: name, generation: generation) {
                _ in .spatialPlaybackCapabilityChanged
            })
        }

        let accepted = lock.withLock {
            guard state.generation == generation else { return false }
            state.observers = observers
            return true
        }
        if !accepted {
            observers.forEach(notificationCenter.removeObserver)
        }
    }

    func stop() {
        let observers = lock.withLock {
            let observers = state.observers
            state = ObservationState()
            return observers
        }
        observers.forEach(notificationCenter.removeObserver)
    }

    private func observe(
        name: Notification.Name,
        generation: UUID,
        event: @escaping @Sendable (Notification) ->
            SpatialAudioRouteMonitorEvent?
    ) -> NSObjectProtocol {
        notificationCenter.addObserver(
            forName: name,
            object: observedObject,
            queue: nil
        ) { [weak self] notification in
            guard let event = event(notification) else { return }
            self?.deliver(event, generation: generation)
        }
    }

    private func deliver(
        _ event: SpatialAudioRouteMonitorEvent,
        generation: UUID
    ) {
        let handler:
            (@Sendable (SpatialAudioRouteMonitorEvent) -> Void)? =
            lock.withLock {
            guard state.generation == generation else { return nil }
            return state.handler
        }
        handler?(event)
    }

    private static func interruptionEvent(
        from notification: Notification
    ) -> SpatialAudioRouteMonitorEvent? {
        #if os(iOS) || os(tvOS) || os(visionOS)
        guard let rawType = (
            notification.userInfo?[AVAudioSessionInterruptionTypeKey]
                as? NSNumber
        )?.uintValue,
              let type = AVAudioSession.InterruptionType(rawValue: rawType)
        else {
            return nil
        }
        switch type {
        case .began:
            return .interruptionBegan
        case .ended:
            let rawOptions = (
                notification.userInfo?[AVAudioSessionInterruptionOptionKey]
                    as? NSNumber
            )?.uintValue ?? 0
            let options = AVAudioSession.InterruptionOptions(
                rawValue: rawOptions
            )
            return .interruptionEnded(
                shouldResume: options.contains(.shouldResume)
            )
        @unknown default:
            return nil
        }
        #else
        _ = notification
        return nil
        #endif
    }
}

enum SpatialAudioRouteMonitorError: Error, Equatable, Sendable {
    case invalidCapacity(Int)
}

final class SpatialAudioRouteMonitor: @unchecked Sendable {
    static let defaultCapacity = 16
    static let maximumCapacity = 64

    private struct State {
        var generation: UUID?
        var revision: SpatialAudioSemanticRevision
        var semanticState: SpatialAudioRouteSemanticState?
        var snapshot: SpatialAudioRouteMonitorSnapshot?
        var continuation:
            AsyncStream<SpatialAudioRouteMonitorSnapshot>.Continuation?
        var revisionExhausted = false
    }

    let capacity: Int
    private let capabilityReader: any SpatialAudioRouteCapabilityReading
    private let eventSource: any SpatialAudioRouteMonitorEventSourcing
    private let lock = NSLock()
    private var state: State

    init(
        capacity: Int = defaultCapacity,
        initialRevision: SpatialAudioSemanticRevision = .init(rawValue: 0),
        capabilityReader: any SpatialAudioRouteCapabilityReading,
        eventSource: any SpatialAudioRouteMonitorEventSourcing
    ) throws {
        guard (1...Self.maximumCapacity).contains(capacity) else {
            throw SpatialAudioRouteMonitorError.invalidCapacity(capacity)
        }
        self.capacity = capacity
        self.capabilityReader = capabilityReader
        self.eventSource = eventSource
        state = State(revision: initialRevision)
    }

    deinit {
        let continuation = lock.withLock {
            state.generation = nil
            let continuation = state.continuation
            state.continuation = nil
            return continuation
        }
        eventSource.stop()
        continuation?.finish()
    }

    func refresh() {
        guard let generation = lock.withLock({ state.generation }) else {
            return
        }
        receive(.refresh, generation: generation)
    }

    func start() -> AsyncStream<SpatialAudioRouteMonitorSnapshot> {
        stop()
        let pair = AsyncStream<SpatialAudioRouteMonitorSnapshot>.makeStream(
            bufferingPolicy: .bufferingNewest(capacity)
        )
        let generation = UUID()
        let semanticState = SpatialAudioRouteSemanticState(
            route: capabilityReader.currentRouteCapability(),
            interruption: .active,
            mediaServices: .available
        )
        let snapshot = lock.withLock {
            let snapshot = SpatialAudioRouteMonitorSnapshot(
                revision: state.revision,
                state: semanticState,
                trigger: .initial
            )
            state.generation = generation
            state.semanticState = semanticState
            state.snapshot = snapshot
            state.continuation = pair.continuation
            state.revisionExhausted = false
            return snapshot
        }
        pair.continuation.yield(snapshot)
        eventSource.start { [weak self] event in
            self?.receive(event, generation: generation)
        }
        return pair.stream
    }

    func stop() {
        let continuation:
            AsyncStream<SpatialAudioRouteMonitorSnapshot>.Continuation? =
            lock.withLock {
            guard state.generation != nil || state.continuation != nil else {
                return nil
            }
            state.generation = nil
            let continuation = state.continuation
            state.continuation = nil
            return continuation
        }
        eventSource.stop()
        continuation?.finish()
    }

    var latestSnapshot: SpatialAudioRouteMonitorSnapshot? {
        lock.withLock { state.snapshot }
    }

    var isRevisionExhausted: Bool {
        lock.withLock { state.revisionExhausted }
    }

    private func receive(
        _ event: SpatialAudioRouteMonitorEvent,
        generation: UUID
    ) {
        let refreshedRoute = event.refreshesRouteCapability
            ? capabilityReader.currentRouteCapability()
            : nil
        let publication: (
            AsyncStream<SpatialAudioRouteMonitorSnapshot>.Continuation,
            SpatialAudioRouteMonitorSnapshot
        )? = lock.withLock {
            guard state.generation == generation,
                  var semanticState = state.semanticState,
                  let continuation = state.continuation else {
                return nil
            }

            if let refreshedRoute {
                semanticState = SpatialAudioRouteSemanticState(
                    route: refreshedRoute,
                    interruption: semanticState.interruption,
                    mediaServices: semanticState.mediaServices
                )
            }
            switch event {
            case .interruptionBegan:
                semanticState = SpatialAudioRouteSemanticState(
                    route: semanticState.route,
                    interruption: .interrupted,
                    mediaServices: semanticState.mediaServices
                )
            case .interruptionEnded:
                semanticState = SpatialAudioRouteSemanticState(
                    route: semanticState.route,
                    interruption: .active,
                    mediaServices: semanticState.mediaServices
                )
            case .mediaServicesLost:
                semanticState = SpatialAudioRouteSemanticState(
                    route: semanticState.route,
                    interruption: semanticState.interruption,
                    mediaServices: .lost
                )
            case .mediaServicesReset:
                semanticState = SpatialAudioRouteSemanticState(
                    route: semanticState.route,
                    interruption: semanticState.interruption,
                    mediaServices: .reset
                )
            case .routeChanged, .spatialPlaybackCapabilityChanged, .refresh:
                break
            }

            guard semanticState != state.semanticState else { return nil }
            guard state.revision.rawValue < UInt64.max else {
                state.revisionExhausted = true
                return nil
            }
            let revision = SpatialAudioSemanticRevision(
                rawValue: state.revision.rawValue + 1
            )
            let snapshot = SpatialAudioRouteMonitorSnapshot(
                revision: revision,
                state: semanticState,
                trigger: event.trigger
            )
            state.revision = revision
            state.semanticState = semanticState
            state.snapshot = snapshot
            return (continuation, snapshot)
        }
        if let publication {
            publication.0.yield(publication.1)
        }
    }
}
