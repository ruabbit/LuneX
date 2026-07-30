import Foundation

struct MobilePictureInPictureGeneration:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    let mediaGeneration: UInt64
    let pictureInPictureGeneration: UInt64

    init?(
        mediaGeneration: UInt64,
        pictureInPictureGeneration: UInt64
    ) {
        guard mediaGeneration > 0, pictureInPictureGeneration > 0 else {
            return nil
        }
        self.mediaGeneration = mediaGeneration
        self.pictureInPictureGeneration = pictureInPictureGeneration
    }
}

struct MobilePictureInPictureRevision:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    let rawValue: UInt64
}

enum MobilePictureInPictureUnavailableReason:
    String,
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case platformUnsupported = "platform-unsupported"
    case contentSourceUnavailable = "content-source-unavailable"
    case controllerUnavailable = "controller-unavailable"
    case notPossible = "not-possible"
    case invalidated
}

enum MobilePictureInPictureCapability:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case unknown
    case unavailable(MobilePictureInPictureUnavailableReason)
    case possible

    var isPossible: Bool {
        self == .possible
    }
}

enum MobilePictureInPictureLifecycle:
    String,
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case unprepared
    case preparing
    case unavailable
    case ready
    case startRequested = "start-requested"
    case starting
    case active
    case stopRequested = "stop-requested"
    case stopping
    case stopped
    case failed
    case invalidated

    var isConfirmedActive: Bool {
        self == .active
    }
}

enum MobilePictureInPictureFailureClass:
    String,
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case contentSourceUnavailable = "content-source-unavailable"
    case controllerUnavailable = "controller-unavailable"
    case nativeStartFailed = "native-start-failed"
    case frameSinkFailed = "frame-sink-failed"
    case playbackDelegateFailed = "playback-delegate-failed"
    case restorationFailed = "restoration-failed"
    case restorationLeaseExhausted = "restoration-lease-exhausted"
}

enum MobilePictureInPictureFrameSinkPhase:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case detached
    case ready
    case backpressured
    case failed(MobilePictureInPictureFailureClass)
    case invalidated
}

struct MobilePictureInPictureFrameSinkSnapshot:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    static let maximumPendingFrameCount = 1

    let phase: MobilePictureInPictureFrameSinkPhase
    let decoderGeneration: UInt64?
    let pendingFrameCount: Int

    static let detached = MobilePictureInPictureFrameSinkSnapshot(
        validatedPhase: .detached,
        decoderGeneration: nil,
        pendingFrameCount: 0
    )

    static let invalidated = MobilePictureInPictureFrameSinkSnapshot(
        validatedPhase: .invalidated,
        decoderGeneration: nil,
        pendingFrameCount: 0
    )

    static func ready(
        decoderGeneration: UInt64
    ) -> MobilePictureInPictureFrameSinkSnapshot? {
        guard decoderGeneration > 0 else { return nil }
        return MobilePictureInPictureFrameSinkSnapshot(
            validatedPhase: .ready,
            decoderGeneration: decoderGeneration,
            pendingFrameCount: 0
        )
    }

    static func backpressured(
        decoderGeneration: UInt64,
        pendingFrameCount: Int
    ) -> MobilePictureInPictureFrameSinkSnapshot? {
        guard decoderGeneration > 0,
              (0...maximumPendingFrameCount).contains(
                pendingFrameCount
              ) else {
            return nil
        }
        return MobilePictureInPictureFrameSinkSnapshot(
            validatedPhase: .backpressured,
            decoderGeneration: decoderGeneration,
            pendingFrameCount: pendingFrameCount
        )
    }

    static func failed(
        _ failure: MobilePictureInPictureFailureClass
    ) -> MobilePictureInPictureFrameSinkSnapshot {
        MobilePictureInPictureFrameSinkSnapshot(
            validatedPhase: .failed(failure),
            decoderGeneration: nil,
            pendingFrameCount: 0
        )
    }

    var acceptsCurrentGenerationFrames: Bool {
        switch phase {
        case .ready, .backpressured:
            decoderGeneration != nil
        case .detached, .failed, .invalidated:
            false
        }
    }

    private init(
        validatedPhase: MobilePictureInPictureFrameSinkPhase,
        decoderGeneration: UInt64?,
        pendingFrameCount: Int
    ) {
        phase = validatedPhase
        self.decoderGeneration = decoderGeneration
        self.pendingFrameCount = pendingFrameCount
    }
}

struct MobilePictureInPictureRestorationLease:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    let generation: MobilePictureInPictureGeneration
    let ordinal: UInt64

    init?(
        generation: MobilePictureInPictureGeneration,
        ordinal: UInt64
    ) {
        guard ordinal > 0 else { return nil }
        self.generation = generation
        self.ordinal = ordinal
    }
}

enum MobilePictureInPictureRestorationResult:
    String,
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case restored
    case declined
    case sessionUnavailable = "session-unavailable"

    var didRestore: Bool {
        self == .restored
    }
}

enum MobilePictureInPictureRestorationState:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case idle
    case pending(MobilePictureInPictureRestorationLease)
    case completed(
        MobilePictureInPictureRestorationLease,
        MobilePictureInPictureRestorationResult
    )
    case invalidated

    var pendingLease: MobilePictureInPictureRestorationLease? {
        guard case let .pending(lease) = self else { return nil }
        return lease
    }
}

struct MobilePictureInPictureSemanticState:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    let isPrepared: Bool
    let capability: MobilePictureInPictureCapability
    let lifecycle: MobilePictureInPictureLifecycle
    let frameSink: MobilePictureInPictureFrameSinkSnapshot
    let restoration: MobilePictureInPictureRestorationState
    let failure: MobilePictureInPictureFailureClass?
}

struct MobilePictureInPictureSnapshot:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    let generation: MobilePictureInPictureGeneration
    let revision: MobilePictureInPictureRevision
    let state: MobilePictureInPictureSemanticState
}

enum MobilePictureInPictureEvent: Equatable, Sendable {
    case prepareRequested
    case prepared(
        capability: MobilePictureInPictureCapability,
        frameSink: MobilePictureInPictureFrameSinkSnapshot
    )
    case capabilityChanged(MobilePictureInPictureCapability)
    case frameSinkChanged(MobilePictureInPictureFrameSinkSnapshot)
    case startRequested
    case willStart
    case didStart
    case startFailed(MobilePictureInPictureFailureClass)
    case stopRequested
    case willStop
    case didStop
    case restorationRequested
    case restorationCompleted(
        lease: MobilePictureInPictureRestorationLease,
        result: MobilePictureInPictureRestorationResult
    )
    case invalidate
}

struct MobilePictureInPictureEventEnvelope: Equatable, Sendable {
    let generation: MobilePictureInPictureGeneration
    let event: MobilePictureInPictureEvent
}

enum MobilePictureInPictureEffect: Equatable, Sendable {
    case requestNativeStart
    case requestNativeStop
    case restoreInterface(MobilePictureInPictureRestorationLease)
    case completeRestoration(
        lease: MobilePictureInPictureRestorationLease,
        restored: Bool
    )
    case flushFrameSink
    case releaseFrameSink
}

enum MobilePictureInPictureRejection: Equatable, Sendable {
    case staleGeneration
    case invalidTransition(
        lifecycle: MobilePictureInPictureLifecycle,
        event: String
    )
    case pictureInPictureUnavailable
    case frameSinkUnavailable
    case restorationAlreadyPending
    case staleRestorationLease
}

enum MobilePictureInPictureReductionOutcome: Equatable, Sendable {
    case unchanged
    case applied(
        snapshot: MobilePictureInPictureSnapshot,
        effects: [MobilePictureInPictureEffect]
    )
    case rejected(MobilePictureInPictureRejection)
    case revisionExhausted([MobilePictureInPictureEffect])
}

struct MobilePictureInPictureStateReducer: Sendable {
    let generation: MobilePictureInPictureGeneration
    private(set) var revision: MobilePictureInPictureRevision
    private(set) var snapshot: MobilePictureInPictureSnapshot?
    private(set) var isRevisionExhausted = false

    private var state: MobilePictureInPictureSemanticState
    private var lastRestorationOrdinal: UInt64

    init(
        generation: MobilePictureInPictureGeneration,
        initialRevision: MobilePictureInPictureRevision =
            MobilePictureInPictureRevision(rawValue: 0),
        initialRestorationOrdinal: UInt64 = 0
    ) {
        self.generation = generation
        revision = initialRevision
        lastRestorationOrdinal = initialRestorationOrdinal
        state = MobilePictureInPictureSemanticState(
            isPrepared: false,
            capability: .unknown,
            lifecycle: .unprepared,
            frameSink: .detached,
            restoration: .idle,
            failure: nil
        )
        snapshot = MobilePictureInPictureSnapshot(
            generation: generation,
            revision: initialRevision,
            state: state
        )
    }

    @discardableResult
    mutating func apply(
        _ envelope: MobilePictureInPictureEventEnvelope
    ) -> MobilePictureInPictureReductionOutcome {
        guard envelope.generation == generation else {
            return .rejected(.staleGeneration)
        }
        guard !isRevisionExhausted else {
            return .revisionExhausted([])
        }

        var next = state
        var effects: [MobilePictureInPictureEffect] = []

        switch envelope.event {
        case .prepareRequested:
            guard [
                .unprepared,
                .unavailable,
                .stopped,
                .failed
            ].contains(state.lifecycle) else {
                return reject(envelope.event)
            }
            next = MobilePictureInPictureSemanticState(
                isPrepared: false,
                capability: .unknown,
                lifecycle: .preparing,
                frameSink: .detached,
                restoration: .idle,
                failure: nil
            )

        case let .prepared(capability, frameSink):
            guard state.lifecycle == .preparing else {
                return reject(envelope.event)
            }
            let ready = capability.isPossible
                && frameSink.acceptsCurrentGenerationFrames
            next = MobilePictureInPictureSemanticState(
                isPrepared: true,
                capability: capability,
                lifecycle: ready ? .ready : .unavailable,
                frameSink: frameSink,
                restoration: .idle,
                failure: ready
                    ? nil
                    : Self.preparationFailure(
                        capability: capability,
                        frameSink: frameSink
                    )
            )

        case let .capabilityChanged(capability):
            next = changingCapability(capability, in: next)

        case let .frameSinkChanged(frameSink):
            next = changingFrameSink(frameSink, in: next)

        case .startRequested:
            guard state.isPrepared,
                  state.capability.isPossible else {
                return .rejected(.pictureInPictureUnavailable)
            }
            guard state.frameSink.acceptsCurrentGenerationFrames else {
                return .rejected(.frameSinkUnavailable)
            }
            guard state.lifecycle == .ready
                    || state.lifecycle == .stopped else {
                return reject(envelope.event)
            }
            next = replacing(
                state,
                lifecycle: .startRequested,
                failure: .replace(nil)
            )
            effects.append(.requestNativeStart)

        case .willStart:
            guard state.lifecycle == .startRequested else {
                return reject(envelope.event)
            }
            next = replacing(state, lifecycle: .starting)

        case .didStart:
            guard state.lifecycle == .startRequested
                    || state.lifecycle == .starting else {
                return reject(envelope.event)
            }
            next = replacing(state, lifecycle: .active)

        case let .startFailed(failure):
            guard state.lifecycle == .startRequested
                    || state.lifecycle == .starting else {
                return reject(envelope.event)
            }
            next = replacing(
                state,
                lifecycle: .failed,
                failure: .replace(failure)
            )
            effects.append(.flushFrameSink)

        case .stopRequested:
            guard [
                .startRequested,
                .starting,
                .active
            ].contains(state.lifecycle) else {
                return reject(envelope.event)
            }
            next = replacing(state, lifecycle: .stopRequested)
            effects.append(.requestNativeStop)

        case .willStop:
            guard [
                .startRequested,
                .starting,
                .active,
                .stopRequested
            ].contains(state.lifecycle) else {
                return reject(envelope.event)
            }
            next = replacing(state, lifecycle: .stopping)

        case .didStop:
            guard [
                .startRequested,
                .starting,
                .active,
                .stopRequested,
                .stopping
            ].contains(state.lifecycle) else {
                return reject(envelope.event)
            }
            next = replacing(state, lifecycle: .stopped)
            effects.append(.flushFrameSink)

        case .restorationRequested:
            guard [
                .active,
                .stopRequested,
                .stopping,
                .stopped
            ].contains(state.lifecycle) else {
                return reject(envelope.event)
            }
            guard state.restoration.pendingLease == nil else {
                return .rejected(.restorationAlreadyPending)
            }
            let nextOrdinal = lastRestorationOrdinal.addingReportingOverflow(1)
            guard !nextOrdinal.overflow,
                  let lease = MobilePictureInPictureRestorationLease(
                    generation: generation,
                    ordinal: nextOrdinal.partialValue
                  ) else {
                next = replacing(
                    state,
                    lifecycle: .failed,
                    failure: .replace(.restorationLeaseExhausted)
                )
                break
            }
            lastRestorationOrdinal = nextOrdinal.partialValue
            next = replacing(
                state,
                restoration: .pending(lease)
            )
            effects.append(.restoreInterface(lease))

        case let .restorationCompleted(lease, result):
            guard lease.generation == generation,
                  state.restoration.pendingLease == lease else {
                return .rejected(.staleRestorationLease)
            }
            next = replacing(
                state,
                restoration: .completed(lease, result),
                failure: .replace(
                    result.didRestore ? nil : .restorationFailed
                )
            )
            effects.append(.completeRestoration(
                lease: lease,
                restored: result.didRestore
            ))

        case .invalidate:
            guard state.lifecycle != .invalidated else {
                return .unchanged
            }
            effects = cleanupEffects(for: state)
            next = Self.invalidatedState
        }

        guard next != state else { return .unchanged }
        return publish(next, effects: effects)
    }

    private mutating func publish(
        _ next: MobilePictureInPictureSemanticState,
        effects: [MobilePictureInPictureEffect]
    ) -> MobilePictureInPictureReductionOutcome {
        let nextRevision = revision.rawValue.addingReportingOverflow(1)
        guard !nextRevision.overflow else {
            let cleanup = cleanupEffects(for: state)
            state = Self.invalidatedState
            snapshot = nil
            isRevisionExhausted = true
            return .revisionExhausted(cleanup)
        }

        revision = MobilePictureInPictureRevision(
            rawValue: nextRevision.partialValue
        )
        state = next
        let nextSnapshot = MobilePictureInPictureSnapshot(
            generation: generation,
            revision: revision,
            state: next
        )
        snapshot = nextSnapshot
        return .applied(snapshot: nextSnapshot, effects: effects)
    }

    private func changingCapability(
        _ capability: MobilePictureInPictureCapability,
        in current: MobilePictureInPictureSemanticState
    ) -> MobilePictureInPictureSemanticState {
        var lifecycle = current.lifecycle
        var failure = current.failure

        if current.isPrepared {
            if capability.isPossible,
               current.frameSink.acceptsCurrentGenerationFrames,
               [.unavailable, .failed].contains(lifecycle) {
                lifecycle = .ready
                failure = nil
            } else if !capability.isPossible,
                      [
                        .ready,
                        .stopped,
                        .failed
                      ].contains(lifecycle) {
                lifecycle = .unavailable
            }
        }

        return MobilePictureInPictureSemanticState(
            isPrepared: current.isPrepared,
            capability: capability,
            lifecycle: lifecycle,
            frameSink: current.frameSink,
            restoration: current.restoration,
            failure: failure
        )
    }

    private func changingFrameSink(
        _ frameSink: MobilePictureInPictureFrameSinkSnapshot,
        in current: MobilePictureInPictureSemanticState
    ) -> MobilePictureInPictureSemanticState {
        var lifecycle = current.lifecycle
        var failure = current.failure

        switch frameSink.phase {
        case let .failed(sinkFailure):
            failure = sinkFailure
            if [
                .unprepared,
                .preparing,
                .unavailable,
                .ready,
                .stopped,
                .failed
            ].contains(lifecycle) {
                lifecycle = .failed
            }
        case .detached, .invalidated:
            if current.isPrepared,
               [
                .unavailable,
                .ready,
                .stopped,
                .failed
               ].contains(lifecycle) {
                lifecycle = .unavailable
            }
        case .ready, .backpressured:
            if current.isPrepared,
               current.capability.isPossible,
               [.unavailable, .failed].contains(lifecycle) {
                lifecycle = .ready
                failure = nil
            }
        }

        return MobilePictureInPictureSemanticState(
            isPrepared: current.isPrepared,
            capability: current.capability,
            lifecycle: lifecycle,
            frameSink: frameSink,
            restoration: current.restoration,
            failure: failure
        )
    }

    private func reject(
        _ event: MobilePictureInPictureEvent
    ) -> MobilePictureInPictureReductionOutcome {
        .rejected(.invalidTransition(
            lifecycle: state.lifecycle,
            event: Self.eventCode(event)
        ))
    }

    private static func eventCode(
        _ event: MobilePictureInPictureEvent
    ) -> String {
        switch event {
        case .prepareRequested: "prepare-requested"
        case .prepared: "prepared"
        case .capabilityChanged: "capability-changed"
        case .frameSinkChanged: "frame-sink-changed"
        case .startRequested: "start-requested"
        case .willStart: "will-start"
        case .didStart: "did-start"
        case .startFailed: "start-failed"
        case .stopRequested: "stop-requested"
        case .willStop: "will-stop"
        case .didStop: "did-stop"
        case .restorationRequested: "restoration-requested"
        case .restorationCompleted: "restoration-completed"
        case .invalidate: "invalidate"
        }
    }

    private static func preparationFailure(
        capability: MobilePictureInPictureCapability,
        frameSink: MobilePictureInPictureFrameSinkSnapshot
    ) -> MobilePictureInPictureFailureClass? {
        if !frameSink.acceptsCurrentGenerationFrames {
            return .frameSinkFailed
        }
        guard case let .unavailable(reason) = capability else {
            return nil
        }
        switch reason {
        case .contentSourceUnavailable:
            return .contentSourceUnavailable
        case .controllerUnavailable, .notPossible, .invalidated,
             .platformUnsupported:
            return .controllerUnavailable
        }
    }

    private func replacing(
        _ state: MobilePictureInPictureSemanticState,
        lifecycle: MobilePictureInPictureLifecycle? = nil,
        restoration: MobilePictureInPictureRestorationState? = nil,
        failure: FailureReplacement = .preserve
    ) -> MobilePictureInPictureSemanticState {
        MobilePictureInPictureSemanticState(
            isPrepared: state.isPrepared,
            capability: state.capability,
            lifecycle: lifecycle ?? state.lifecycle,
            frameSink: state.frameSink,
            restoration: restoration ?? state.restoration,
            failure: failure.value(preserving: state.failure)
        )
    }

    private enum FailureReplacement {
        case preserve
        case replace(MobilePictureInPictureFailureClass?)

        func value(
            preserving current: MobilePictureInPictureFailureClass?
        ) -> MobilePictureInPictureFailureClass? {
            switch self {
            case .preserve:
                current
            case let .replace(replacement):
                replacement
            }
        }
    }

    private static var invalidatedState: MobilePictureInPictureSemanticState {
        MobilePictureInPictureSemanticState(
            isPrepared: false,
            capability: .unavailable(.invalidated),
            lifecycle: .invalidated,
            frameSink: .invalidated,
            restoration: .invalidated,
            failure: nil
        )
    }

    private func cleanupEffects(
        for state: MobilePictureInPictureSemanticState
    ) -> [MobilePictureInPictureEffect] {
        var effects: [MobilePictureInPictureEffect] = []
        if let lease = state.restoration.pendingLease {
            effects.append(.completeRestoration(
                lease: lease,
                restored: false
            ))
        }
        effects.append(.flushFrameSink)
        effects.append(.releaseFrameSink)
        return effects
    }

}

enum MobileContinuityPath:
    String,
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case inactive
    case foreground
    case pictureInPicture = "picture-in-picture"
    case audioOnly = "audio-only"
    case unavailable
}

enum MobileContinuityUnavailableReason:
    String,
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case unsupportedPlatform = "unsupported-platform"
    case backgroundConfigurationMissing = "background-configuration-missing"
    case noActivePermittedMediaPath = "no-active-permitted-media-path"
}

struct MobileContinuityPathInput: Equatable, Hashable, Sendable {
    let platform: ApplePlatformFamily
    let sceneActivity: AppSceneActivity
    let isStreamActive: Bool
    let pictureInPictureLifecycle: MobilePictureInPictureLifecycle
    let isPictureInPictureFrameSinkOperational: Bool
    let isAudioSessionActive: Bool
    let isAudioContinuityPermitted: Bool
    let hasPlaybackBackgroundModeDeclared: Bool
    let preferences: ContinuityPreferences
}

struct MobileContinuityPathResolution:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    let path: MobileContinuityPath
    let unavailableReason: MobileContinuityUnavailableReason?
}

enum MobileContinuityPathResolver {
    static func resolve(
        _ input: MobileContinuityPathInput
    ) -> MobileContinuityPathResolution {
        guard input.platform == .iOS || input.platform == .iPadOS else {
            return MobileContinuityPathResolution(
                path: .unavailable,
                unavailableReason: .unsupportedPlatform
            )
        }
        guard input.isStreamActive else {
            return MobileContinuityPathResolution(
                path: .inactive,
                unavailableReason: nil
            )
        }
        guard input.sceneActivity == .background else {
            return MobileContinuityPathResolution(
                path: .foreground,
                unavailableReason: nil
            )
        }

        let hasActivePictureInPicture =
            input.preferences.pictureInPictureEnabled
                && input.pictureInPictureLifecycle.isConfirmedActive
                && input.isPictureInPictureFrameSinkOperational
        let hasActivePermittedAudio =
            input.preferences.audioContinuityEnabled
                && input.isAudioSessionActive
                && input.isAudioContinuityPermitted

        guard hasActivePictureInPicture || hasActivePermittedAudio else {
            return MobileContinuityPathResolution(
                path: .unavailable,
                unavailableReason: .noActivePermittedMediaPath
            )
        }
        guard input.hasPlaybackBackgroundModeDeclared else {
            return MobileContinuityPathResolution(
                path: .unavailable,
                unavailableReason: .backgroundConfigurationMissing
            )
        }
        if hasActivePictureInPicture {
            return MobileContinuityPathResolution(
                path: .pictureInPicture,
                unavailableReason: nil
            )
        }
        return MobileContinuityPathResolution(
            path: .audioOnly,
            unavailableReason: nil
        )
    }
}

struct MobileContinuityPathSnapshot:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    let generation: MobilePictureInPictureGeneration
    let revision: MobilePictureInPictureRevision
    let resolution: MobileContinuityPathResolution
}

enum MobileContinuityPathPublicationOutcome: Equatable, Sendable {
    case unchanged
    case published(MobileContinuityPathSnapshot)
    case staleGeneration
    case revisionExhausted
}

struct MobileContinuityPathStateReducer: Sendable {
    let generation: MobilePictureInPictureGeneration
    private(set) var revision: MobilePictureInPictureRevision
    private(set) var snapshot: MobileContinuityPathSnapshot?
    private(set) var isRevisionExhausted = false

    private var resolution: MobileContinuityPathResolution?

    init(
        generation: MobilePictureInPictureGeneration,
        initialRevision: MobilePictureInPictureRevision =
            MobilePictureInPictureRevision(rawValue: 0)
    ) {
        self.generation = generation
        revision = initialRevision
    }

    @discardableResult
    mutating func update(
        _ input: MobileContinuityPathInput,
        generation incomingGeneration: MobilePictureInPictureGeneration
    ) -> MobileContinuityPathPublicationOutcome {
        guard incomingGeneration == generation else {
            return .staleGeneration
        }
        guard !isRevisionExhausted else {
            return .revisionExhausted
        }
        let nextResolution = MobileContinuityPathResolver.resolve(input)
        guard nextResolution != resolution else {
            return .unchanged
        }

        let nextRevision = revision.rawValue.addingReportingOverflow(1)
        guard !nextRevision.overflow else {
            resolution = nil
            snapshot = nil
            isRevisionExhausted = true
            return .revisionExhausted
        }
        revision = MobilePictureInPictureRevision(
            rawValue: nextRevision.partialValue
        )
        resolution = nextResolution
        let nextSnapshot = MobileContinuityPathSnapshot(
            generation: generation,
            revision: revision,
            resolution: nextResolution
        )
        snapshot = nextSnapshot
        return .published(nextSnapshot)
    }
}
