import Foundation

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
    static let maximumHeadroom = HDRLuminanceMapping.maximumCurrentHeadroom

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
        guard envelope.surfaceGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isRevisionExhausted else { return .revisionExhausted }

        let nextState = Self.normalize(envelope.sample)
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

    private static func normalize(
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
