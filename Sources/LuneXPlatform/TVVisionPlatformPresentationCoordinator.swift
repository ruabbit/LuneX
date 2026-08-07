import Foundation

enum TVVisionPlatformPresentationComponent: String, Equatable, Sendable {
    case scene
    case input
    case display
    case audioRoute = "audio-route"
    case video
}

enum TVVisionPlatformPresentationEffectKind: String, Equatable, Sendable {
    case scene
    case input
    case display
    case audioRoute = "audio-route"
    case video
    case clearVideo = "clear-video"
    case teardown
    case snapshot
}

enum TVVisionPlatformPresentationStopReason: String, Equatable, Sendable {
    case replacement
    case failure
    case reconnect
    case remoteTermination = "remote-termination"
    case localStop = "local-stop"
}

enum TVVisionPlatformPresentationFailure: Equatable, Sendable {
    case invalidComponent(TVVisionPlatformPresentationComponent)
    case actionFailed(TVVisionPlatformPresentationEffectKind)
    case semanticRevisionExhausted
    case sequenceExhausted
}

enum TVVisionPlatformPresentationDiagnosticClass: Equatable, Sendable {
    case activated
    case sceneClosed
    case displayDirectEDR
    case displayFallback(TVOSDisplayHDRFallbackReason)
    case replaced
    case stopped(TVVisionPlatformPresentationStopReason)
    case failed(TVVisionPlatformPresentationFailure)
}

struct TVVisionPlatformPresentationDiagnostic: Equatable, Sendable {
    let sequence: UInt64
    let classification: TVVisionPlatformPresentationDiagnosticClass
}

enum TVVisionPlatformVideoPhase: Equatable, Sendable {
    case idle
    case decoderReady(decoderGeneration: UInt64)
    case frameReady(decoderGeneration: UInt64, frameID: UInt64)
    case cleared(decoderGeneration: UInt64?)
}

struct TVVisionPlatformVideoSnapshot: Equatable, Sendable {
    let phase: TVVisionPlatformVideoPhase
    let lastDeliveryRevision: UInt64?
    let isPresented: Bool
}

enum TVVisionPlatformPresentationPhase: Equatable, Sendable {
    case active
    case stopped(TVVisionPlatformPresentationStopReason)
    case failed(TVVisionPlatformPresentationFailure)
}

struct TVVisionPlatformPresentationCoordinatorSnapshot: Equatable, Sendable {
    let ownership: TVVisionPresentationOwnership
    let sequence: UInt64
    let revision: TVVisionSemanticRevision
    let phase: TVVisionPlatformPresentationPhase
    let presentation: TVVisionPlatformPresentationSnapshot?
    let display: TVVisionDisplaySnapshot?
    let video: TVVisionPlatformVideoSnapshot
    let diagnostics: [TVVisionPlatformPresentationDiagnostic]
    let teardownCount: UInt64
    let isSemanticRevisionExhausted: Bool
    let isSequenceExhausted: Bool
}

struct TVVisionPlatformVideoPresentationApplication: @unchecked Sendable {
    let ownership: TVVisionPresentationOwnership
    let sequence: UInt64
    let platformRevision: TVVisionSemanticRevision
    let surfaceGeneration: TVVisionGeneration
    let delivery: StreamVideoPresentationDelivery
}

enum TVVisionPlatformPresentationEffect: @unchecked Sendable {
    case scene(TVVisionSceneSurfaceSnapshot?)
    case input(TVVisionInputCapabilitySnapshot?)
    case display(TVVisionDisplaySnapshot?)
    case audioRoute(TVVisionAudioRouteSnapshot?)
    case video(TVVisionPlatformVideoPresentationApplication)
    case clearVideo
    case teardown(TVVisionPlatformPresentationStopReason)
    case snapshot(TVVisionPlatformPresentationCoordinatorSnapshot)

    var kind: TVVisionPlatformPresentationEffectKind {
        switch self {
        case .scene: .scene
        case .input: .input
        case .display: .display
        case .audioRoute: .audioRoute
        case .video: .video
        case .clearVideo: .clearVideo
        case .teardown: .teardown
        case .snapshot: .snapshot
        }
    }
}

struct TVVisionPlatformPresentationActionApplication: @unchecked Sendable {
    let ownership: TVVisionPresentationOwnership
    let sequence: UInt64
    let effect: TVVisionPlatformPresentationEffect
}

protocol TVVisionPlatformPresentationActionApplying: Sendable {
    func apply(
        _ application: TVVisionPlatformPresentationActionApplication
    ) async throws
}

struct TVVisionPlatformPresentationNoopActionClient:
    TVVisionPlatformPresentationActionApplying
{
    func apply(
        _ application: TVVisionPlatformPresentationActionApplication
    ) async throws {
        _ = application
    }
}

enum TVVisionPlatformPresentationCoordinatorOutcome: Equatable, Sendable {
    case applied(TVVisionPlatformPresentationCoordinatorSnapshot)
    case unchanged(TVVisionPlatformPresentationCoordinatorSnapshot)
    case staleOwnership
    case staleRevision
    case failed(TVVisionPlatformPresentationCoordinatorSnapshot)
}

enum TVVisionPlatformPresentationCoordinatorError: Error, Equatable, Sendable {
    case invalidDiagnosticCapacity(Int)
}

private actor TVVisionPlatformPresentationOperationGate {
    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isHeld {
            isHeld = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isHeld = false
            return
        }
        waiters.removeFirst().resume()
    }
}

actor TVVisionPlatformPresentationCoordinator {
    static let maximumDiagnosticCapacity = 64

    private struct SceneComponent: Equatable {
        let sourceGeneration: TVVisionGeneration
        let sourceRevision: TVVisionSemanticRevision
        let snapshot: TVVisionSceneSurfaceSnapshot
        let isFocusEligible: Bool
    }

    private struct InputComponent: Equatable {
        let sourceRevision: TVVisionSemanticRevision
        let snapshot: TVVisionInputCapabilitySnapshot
        let controllerLeases: [TVVisionControllerLease]
    }

    private struct DisplayComponent: Equatable {
        let sourceGeneration: TVVisionGeneration
        let sourceRevision: TVVisionSemanticRevision
        let snapshot: TVVisionDisplaySnapshot
    }

    private struct AudioComponent: Equatable {
        let sourceGeneration: TVVisionGeneration
        let sourceRevision: TVVisionSemanticRevision
        let snapshot: TVVisionAudioRouteSnapshot
    }

    private struct ActiveState {
        let ownership: TVVisionPresentationOwnership
        var revision: TVVisionSemanticRevision
        var scene: SceneComponent?
        var input: InputComponent?
        var display: DisplayComponent?
        var audio: AudioComponent?
        var latestVideoDelivery: StreamVideoPresentationDelivery?
        var video: TVVisionPlatformVideoSnapshot
        var presentation: TVVisionPlatformPresentationSnapshot?
    }

    private enum ComponentDecision {
        case changed
        case unchanged
        case stale
        case conflicting
    }

    private enum PresentationAssemblyError: Error {
        case invalidComponent(TVVisionPlatformPresentationComponent)
    }

    private let actionClient: any TVVisionPlatformPresentationActionApplying
    private let diagnosticCapacity: Int
    private let operationGate = TVVisionPlatformPresentationOperationGate()

    private var activeState: ActiveState?
    private var latestSnapshot: TVVisionPlatformPresentationCoordinatorSnapshot?
    private var currentRevision: TVVisionSemanticRevision?
    private var sequence: UInt64
    private var diagnostics: [TVVisionPlatformPresentationDiagnostic] = []
    private var teardownCount: UInt64 = 0
    private var isSemanticRevisionExhausted = false
    private var isSequenceExhausted = false

    init(
        actionClient: any TVVisionPlatformPresentationActionApplying =
            TVVisionPlatformPresentationNoopActionClient(),
        diagnosticCapacity: Int = 16,
        initialRevision: TVVisionSemanticRevision? = nil,
        initialSequence: UInt64 = 0
    ) throws {
        guard (1...Self.maximumDiagnosticCapacity).contains(
            diagnosticCapacity
        ) else {
            throw TVVisionPlatformPresentationCoordinatorError
                .invalidDiagnosticCapacity(diagnosticCapacity)
        }
        self.actionClient = actionClient
        self.diagnosticCapacity = diagnosticCapacity
        currentRevision = initialRevision
        sequence = initialSequence
    }

    func activate(
        _ ownership: TVVisionPresentationOwnership
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        await operationGate.acquire()
        let outcome = await activateLocked(ownership)
        await operationGate.release()
        return outcome
    }

    func applyScene(
        _ update: TVVisionStreamGeometryBindingUpdate,
        ownership: TVVisionPresentationOwnership
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        await operationGate.acquire()
        let outcome = await applySceneLocked(update, ownership: ownership)
        await operationGate.release()
        return outcome
    }

    func applyInput(
        _ snapshot: TVVisionInputCapabilitySnapshot,
        controllerLeases: [TVVisionControllerLease],
        ownership: TVVisionPresentationOwnership
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        await operationGate.acquire()
        let outcome = await applyInputLocked(
            snapshot,
            controllerLeases: controllerLeases,
            ownership: ownership
        )
        await operationGate.release()
        return outcome
    }

    func applyDisplay(
        _ snapshot: TVVisionDisplaySnapshot,
        ownership: TVVisionPresentationOwnership
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        await operationGate.acquire()
        let outcome = await applyDisplayLocked(snapshot, ownership: ownership)
        await operationGate.release()
        return outcome
    }

    func applyAudioRoute(
        _ snapshot: TVVisionAudioRouteSnapshot,
        ownership: TVVisionPresentationOwnership
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        await operationGate.acquire()
        let outcome = await applyAudioLocked(snapshot, ownership: ownership)
        await operationGate.release()
        return outcome
    }

    func receiveVideo(
        _ delivery: StreamVideoPresentationDelivery,
        ownership: TVVisionPresentationOwnership
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        await operationGate.acquire()
        let outcome = await receiveVideoLocked(delivery, ownership: ownership)
        await operationGate.release()
        return outcome
    }

    func fail(
        ownership: TVVisionPresentationOwnership,
        failure: TVVisionPlatformPresentationFailure =
            .invalidComponent(.video)
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        await operationGate.acquire()
        let outcome: TVVisionPlatformPresentationCoordinatorOutcome
        if let state = activeState, state.ownership == ownership {
            let terminal = await terminateLocked(
                state,
                reason: .failure,
                requestedPhase: .failed(failure)
            )
            outcome = .failed(terminal)
        } else {
            outcome = .staleOwnership
        }
        await operationGate.release()
        return outcome
    }

    func stop(
        ownership: TVVisionPresentationOwnership,
        reason: TVVisionPlatformPresentationStopReason
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        await operationGate.acquire()
        let outcome = await stopLocked(ownership: ownership, reason: reason)
        await operationGate.release()
        return outcome
    }

    func snapshot() -> TVVisionPlatformPresentationCoordinatorSnapshot? {
        latestSnapshot
    }

    private func activateLocked(
        _ ownership: TVVisionPresentationOwnership
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        if let current = activeState {
            if current.ownership == ownership,
               let latestSnapshot {
                return .unchanged(latestSnapshot)
            }
            guard isNewer(ownership, than: current.ownership) else {
                return .staleOwnership
            }
            let terminal = await terminateLocked(
                current,
                reason: .replacement,
                requestedPhase: .stopped(.replacement)
            )
            if case .failed = terminal.phase {
                return .failed(terminal)
            }
        } else if let latestSnapshot,
                  !isNewer(ownership, than: latestSnapshot.ownership) {
            return .staleOwnership
        }

        guard let revision = advanceRevision() else {
            return await failWithoutActiveState(
                ownership: ownership,
                failure: .semanticRevisionExhausted
            )
        }
        guard let nextSequence = advanceSequence() else {
            return await failWithoutActiveState(
                ownership: ownership,
                failure: .sequenceExhausted
            )
        }

        appendDiagnostic(.activated, sequence: nextSequence)
        let state = ActiveState(
            ownership: ownership,
            revision: revision,
            scene: nil,
            input: nil,
            display: nil,
            audio: nil,
            latestVideoDelivery: nil,
            video: TVVisionPlatformVideoSnapshot(
                phase: .idle,
                lastDeliveryRevision: nil,
                isPresented: false
            ),
            presentation: nil
        )
        let snapshot = makeSnapshot(state, sequence: nextSequence)
        do {
            try await applyEffect(
                .snapshot(snapshot),
                ownership: ownership,
                sequence: nextSequence
            )
        } catch {
            return await failState(
                state,
                failure: .actionFailed(.snapshot)
            )
        }
        activeState = state
        latestSnapshot = snapshot
        return .applied(snapshot)
    }

    private func applySceneLocked(
        _ update: TVVisionStreamGeometryBindingUpdate,
        ownership: TVVisionPresentationOwnership
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        guard var state = activeState, state.ownership == ownership else {
            return .staleOwnership
        }
        guard update.platform == ownership.platform,
              update.surfaceGeneration.domain == .surface else {
            return await failState(
                state,
                failure: .invalidComponent(.scene)
            )
        }

        let candidate: SceneComponent
        switch update.status {
        case .active:
            guard let binding = update.binding,
                  binding.platform == update.platform,
                  binding.surfaceGeneration == update.surfaceGeneration,
                  binding.revision == update.revision,
                  binding.sceneSurfaceSnapshot.revision == update.revision,
                  binding.sceneSurfaceSnapshot.attachment == .attached else {
                return await failState(
                    state,
                    failure: .invalidComponent(.scene)
                )
            }
            candidate = SceneComponent(
                sourceGeneration: update.surfaceGeneration,
                sourceRevision: update.revision,
                snapshot: binding.sceneSurfaceSnapshot,
                isFocusEligible: binding.isFocusEligible
            )
        case .closed:
            guard update.binding == nil,
                  let detached = try? TVVisionSceneSurfaceSnapshot(
                      platform: update.platform,
                      revision: update.revision,
                      surfaceGeneration: update.surfaceGeneration,
                      activity: .background,
                      attachment: .detached,
                      isVisible: false,
                      geometry: nil
                  ) else {
                return await failState(
                    state,
                    failure: .invalidComponent(.scene)
                )
            }
            candidate = SceneComponent(
                sourceGeneration: update.surfaceGeneration,
                sourceRevision: update.revision,
                snapshot: detached,
                isFocusEligible: false
            )
        }

        switch componentDecision(current: state.scene, candidate: candidate) {
        case .unchanged:
            return .unchanged(makeSnapshot(state, sequence: sequence))
        case .stale:
            return .staleRevision
        case .conflicting:
            return await failState(
                state,
                failure: .invalidComponent(.scene)
            )
        case .changed:
            break
        }
        guard let revision = advanceRevision() else {
            return await failState(
                state,
                failure: .semanticRevisionExhausted
            )
        }
        state.revision = revision
        state.scene = candidate
        let diagnostic: TVVisionPlatformPresentationDiagnosticClass? =
            if case .closed = update.status { .sceneClosed } else { nil }
        return await commitComponentState(state, diagnostic: diagnostic)
    }

    private func applyInputLocked(
        _ snapshot: TVVisionInputCapabilitySnapshot,
        controllerLeases: [TVVisionControllerLease],
        ownership: TVVisionPresentationOwnership
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        guard var state = activeState, state.ownership == ownership else {
            return .staleOwnership
        }
        guard snapshot.platform == ownership.platform,
              snapshot.inputGeneration == ownership.inputGeneration,
              controllerLeases.allSatisfy({
                  $0.platform == ownership.platform
                      && $0.inputGeneration == ownership.inputGeneration
              }),
              controllerLeases.count <= TVVisionControllerSlot.maximumCount,
              Set(controllerLeases.map(\.slot.rawValue)).count
                == controllerLeases.count,
              Set(controllerLeases.map(\.leaseGeneration.rawValue)).count
                == controllerLeases.count else {
            return await failState(
                state,
                failure: .invalidComponent(.input)
            )
        }
        let candidate = InputComponent(
            sourceRevision: snapshot.revision,
            snapshot: snapshot,
            controllerLeases: controllerLeases.sorted { $0.slot < $1.slot }
        )
        switch inputDecision(current: state.input, candidate: candidate) {
        case .unchanged:
            return .unchanged(makeSnapshot(state, sequence: sequence))
        case .stale:
            return .staleRevision
        case .conflicting:
            return await failState(
                state,
                failure: .invalidComponent(.input)
            )
        case .changed:
            break
        }
        guard let revision = advanceRevision() else {
            return await failState(
                state,
                failure: .semanticRevisionExhausted
            )
        }
        state.revision = revision
        state.input = candidate
        return await commitComponentState(state)
    }

    private func applyDisplayLocked(
        _ snapshot: TVVisionDisplaySnapshot,
        ownership: TVVisionPresentationOwnership
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        guard var state = activeState, state.ownership == ownership else {
            return .staleOwnership
        }
        guard snapshot.platform == ownership.platform else {
            return await failState(
                state,
                failure: .invalidComponent(.display)
            )
        }
        let candidate = DisplayComponent(
            sourceGeneration: snapshot.displayGeneration,
            sourceRevision: snapshot.revision,
            snapshot: snapshot
        )
        switch componentDecision(current: state.display, candidate: candidate) {
        case .unchanged:
            return .unchanged(makeSnapshot(state, sequence: sequence))
        case .stale:
            return .staleRevision
        case .conflicting:
            return await failState(
                state,
                failure: .invalidComponent(.display)
            )
        case .changed:
            break
        }
        guard let revision = advanceRevision() else {
            return await failState(
                state,
                failure: .semanticRevisionExhausted
            )
        }
        state.revision = revision
        state.display = candidate
        let diagnostic: TVVisionPlatformPresentationDiagnosticClass?
        switch snapshot.tvOSHDRCapabilityResolution {
        case .directEDR:
            diagnostic = .displayDirectEDR
        case let .sdrFallback(_, reason):
            diagnostic = .displayFallback(reason)
        case nil:
            diagnostic = nil
        }
        return await commitComponentState(state, diagnostic: diagnostic)
    }

    private func applyAudioLocked(
        _ snapshot: TVVisionAudioRouteSnapshot,
        ownership: TVVisionPresentationOwnership
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        guard var state = activeState, state.ownership == ownership else {
            return .staleOwnership
        }
        guard snapshot.platform == ownership.platform else {
            return await failState(
                state,
                failure: .invalidComponent(.audioRoute)
            )
        }
        let candidate = AudioComponent(
            sourceGeneration: snapshot.routeGeneration,
            sourceRevision: snapshot.revision,
            snapshot: snapshot
        )
        switch componentDecision(current: state.audio, candidate: candidate) {
        case .unchanged:
            return .unchanged(makeSnapshot(state, sequence: sequence))
        case .stale:
            return .staleRevision
        case .conflicting:
            return await failState(
                state,
                failure: .invalidComponent(.audioRoute)
            )
        case .changed:
            break
        }
        guard let revision = advanceRevision() else {
            return await failState(
                state,
                failure: .semanticRevisionExhausted
            )
        }
        state.revision = revision
        state.audio = candidate
        return await commitComponentState(state)
    }

    private func receiveVideoLocked(
        _ delivery: StreamVideoPresentationDelivery,
        ownership: TVVisionPresentationOwnership
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        guard var state = activeState, state.ownership == ownership else {
            return .staleOwnership
        }
        let deliveryOwnership = delivery.ownership
        guard deliveryOwnership.sessionID == ownership.sessionID,
              deliveryOwnership.mediaGeneration == ownership.mediaGeneration else {
            return .staleOwnership
        }
        if let current = state.video.lastDeliveryRevision,
           deliveryOwnership.revision <= current {
            return .staleRevision
        }
        guard let nextSequence = advanceSequence() else {
            return await failState(state, failure: .sequenceExhausted)
        }

        switch delivery {
        case let .decoderStarted(_, contract):
            guard contract.decoderGeneration > 0 else {
                return await failState(
                    state,
                    failure: .invalidComponent(.video)
                )
            }
            if let current = decoderGeneration(state),
               contract.decoderGeneration <= current {
                return .staleRevision
            }
            state.latestVideoDelivery = delivery
            state.video = TVVisionPlatformVideoSnapshot(
                phase: .decoderReady(
                    decoderGeneration: contract.decoderGeneration
                ),
                lastDeliveryRevision: deliveryOwnership.revision,
                isPresented: false
            )
        case let .decodedFrame(_, frame):
            guard frame.generation > 0 else {
                return await failState(
                    state,
                    failure: .invalidComponent(.video)
                )
            }
            if case let .cleared(clearedGeneration) = state.video.phase,
               let clearedGeneration {
                if frame.generation <= clearedGeneration {
                    return .staleRevision
                }
                return await failState(
                    state,
                    failure: .invalidComponent(.video)
                )
            } else if let current = decoderGeneration(state),
                      frame.generation != current {
                if frame.generation < current { return .staleRevision }
                return await failState(
                    state,
                    failure: .invalidComponent(.video)
                )
            }
            state.latestVideoDelivery = delivery
            state.video = TVVisionPlatformVideoSnapshot(
                phase: .frameReady(
                    decoderGeneration: frame.generation,
                    frameID: frame.frameID
                ),
                lastDeliveryRevision: deliveryOwnership.revision,
                isPresented: false
            )
        case let .cleared(_, decoderGeneration):
            if let decoderGeneration {
                guard decoderGeneration > 0 else {
                    return await failState(
                        state,
                        failure: .invalidComponent(.video)
                    )
                }
                if let current = self.decoderGeneration(state),
                   decoderGeneration != current {
                    if decoderGeneration < current { return .staleRevision }
                    return await failState(
                        state,
                        failure: .invalidComponent(.video)
                    )
                }
            }
            state.latestVideoDelivery = nil
            state.video = TVVisionPlatformVideoSnapshot(
                phase: .cleared(decoderGeneration: decoderGeneration),
                lastDeliveryRevision: deliveryOwnership.revision,
                isPresented: false
            )
        }

        var effects: [TVVisionPlatformPresentationEffect] = []
        if case .cleared = delivery {
            effects.append(.clearVideo)
        } else if let application = makeVideoApplication(
            state,
            sequence: nextSequence
        ) {
            state.video = TVVisionPlatformVideoSnapshot(
                phase: state.video.phase,
                lastDeliveryRevision: state.video.lastDeliveryRevision,
                isPresented: true
            )
            effects.append(.video(application))
        } else if activeState?.video.isPresented == true {
            effects.append(.clearVideo)
        }

        let snapshot = makeSnapshot(state, sequence: nextSequence)
        effects.append(.snapshot(snapshot))
        return await commit(
            state,
            sequence: nextSequence,
            snapshot: snapshot,
            effects: effects
        )
    }

    private func commitComponentState(
        _ candidate: ActiveState,
        diagnostic: TVVisionPlatformPresentationDiagnosticClass? = nil
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        guard let nextSequence = advanceSequence() else {
            return await failState(candidate, failure: .sequenceExhausted)
        }
        var state = candidate
        do {
            state.presentation = try makePresentation(state)
        } catch let error as PresentationAssemblyError {
            switch error {
            case let .invalidComponent(component):
                return await failState(
                    state,
                    failure: .invalidComponent(component)
                )
            }
        } catch {
            return await failState(
                state,
                failure: .invalidComponent(.scene)
            )
        }

        if let diagnostic {
            appendDiagnostic(diagnostic, sequence: nextSequence)
        }

        let synchronized = makeSynchronizedEffects(
            &state,
            sequence: nextSequence
        )
        let snapshot = makeSnapshot(state, sequence: nextSequence)
        return await commit(
            state,
            sequence: nextSequence,
            snapshot: snapshot,
            effects: synchronized + [.snapshot(snapshot)]
        )
    }

    private func commit(
        _ state: ActiveState,
        sequence: UInt64,
        snapshot: TVVisionPlatformPresentationCoordinatorSnapshot,
        effects: [TVVisionPlatformPresentationEffect]
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        for effect in effects {
            do {
                try await applyEffect(
                    effect,
                    ownership: state.ownership,
                    sequence: sequence
                )
            } catch {
                return await failState(
                    state,
                    failure: .actionFailed(effect.kind)
                )
            }
        }
        activeState = state
        latestSnapshot = snapshot
        return .applied(snapshot)
    }

    private func failState(
        _ state: ActiveState,
        failure: TVVisionPlatformPresentationFailure
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        let terminal = await terminateLocked(
            state,
            reason: .failure,
            requestedPhase: .failed(failure)
        )
        return .failed(terminal)
    }

    private func failWithoutActiveState(
        ownership: TVVisionPresentationOwnership,
        failure: TVVisionPlatformPresentationFailure
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        let revision = currentRevision
            ?? (try! TVVisionSemanticRevision(rawValue: 1))
        let state = ActiveState(
            ownership: ownership,
            revision: revision,
            scene: nil,
            input: nil,
            display: nil,
            audio: nil,
            latestVideoDelivery: nil,
            video: TVVisionPlatformVideoSnapshot(
                phase: .idle,
                lastDeliveryRevision: nil,
                isPresented: false
            ),
            presentation: nil
        )
        let terminal = await terminateLocked(
            state,
            reason: .failure,
            requestedPhase: .failed(failure)
        )
        return .failed(terminal)
    }

    private func stopLocked(
        ownership: TVVisionPresentationOwnership,
        reason: TVVisionPlatformPresentationStopReason
    ) async -> TVVisionPlatformPresentationCoordinatorOutcome {
        guard let state = activeState else {
            if let latestSnapshot,
               latestSnapshot.ownership == ownership,
               latestSnapshot.phase != .active {
                return .unchanged(latestSnapshot)
            }
            return .staleOwnership
        }
        guard state.ownership == ownership else { return .staleOwnership }
        let terminal = await terminateLocked(
            state,
            reason: reason,
            requestedPhase: .stopped(reason)
        )
        if case .failed = terminal.phase {
            return .failed(terminal)
        }
        return .applied(terminal)
    }

    private func terminateLocked(
        _ state: ActiveState,
        reason: TVVisionPlatformPresentationStopReason,
        requestedPhase: TVVisionPlatformPresentationPhase
    ) async -> TVVisionPlatformPresentationCoordinatorSnapshot {
        let terminalRevision = advanceRevision() ?? state.revision
        let terminalSequence = advanceSequence() ?? sequence
        let nextTeardown = teardownCount.addingReportingOverflow(1)
        teardownCount = nextTeardown.overflow
            ? UInt64.max
            : nextTeardown.partialValue

        let effects: [TVVisionPlatformPresentationEffect] = [
            .input(nil),
            .clearVideo,
            .display(nil),
            .audioRoute(nil),
            .scene(nil),
            .teardown(reason)
        ]
        var firstFailure: TVVisionPlatformPresentationEffectKind?
        for effect in effects {
            do {
                try await applyEffect(
                    effect,
                    ownership: state.ownership,
                    sequence: terminalSequence
                )
            } catch {
                if firstFailure == nil { firstFailure = effect.kind }
            }
        }

        var phase: TVVisionPlatformPresentationPhase
        if isSemanticRevisionExhausted {
            phase = .failed(.semanticRevisionExhausted)
        } else if isSequenceExhausted {
            phase = .failed(.sequenceExhausted)
        } else if let firstFailure {
            phase = .failed(.actionFailed(firstFailure))
        } else {
            phase = requestedPhase
        }
        switch phase {
        case let .stopped(stopReason):
            appendDiagnostic(.stopped(stopReason), sequence: terminalSequence)
        case let .failed(failure):
            appendDiagnostic(.failed(failure), sequence: terminalSequence)
        case .active:
            break
        }
        if reason == .replacement, phase == .stopped(.replacement) {
            appendDiagnostic(.replaced, sequence: terminalSequence)
        }

        var terminal = TVVisionPlatformPresentationCoordinatorSnapshot(
            ownership: state.ownership,
            sequence: terminalSequence,
            revision: terminalRevision,
            phase: phase,
            presentation: nil,
            display: nil,
            video: TVVisionPlatformVideoSnapshot(
                phase: .cleared(decoderGeneration: decoderGeneration(state)),
                lastDeliveryRevision: state.video.lastDeliveryRevision,
                isPresented: false
            ),
            diagnostics: diagnostics,
            teardownCount: teardownCount,
            isSemanticRevisionExhausted: isSemanticRevisionExhausted,
            isSequenceExhausted: isSequenceExhausted
        )
        do {
            try await applyEffect(
                .snapshot(terminal),
                ownership: state.ownership,
                sequence: terminalSequence
            )
        } catch {
            let snapshotFailure = TVVisionPlatformPresentationFailure
                .actionFailed(.snapshot)
            appendDiagnostic(.failed(snapshotFailure), sequence: terminalSequence)
            if case .stopped = phase {
                phase = .failed(snapshotFailure)
            }
            terminal = TVVisionPlatformPresentationCoordinatorSnapshot(
                ownership: state.ownership,
                sequence: terminalSequence,
                revision: terminalRevision,
                phase: phase,
                presentation: nil,
                display: nil,
                video: terminal.video,
                diagnostics: diagnostics,
                teardownCount: teardownCount,
                isSemanticRevisionExhausted: isSemanticRevisionExhausted,
                isSequenceExhausted: isSequenceExhausted
            )
        }
        activeState = nil
        latestSnapshot = terminal
        return terminal
    }

    private func makePresentation(
        _ state: ActiveState
    ) throws -> TVVisionPlatformPresentationSnapshot? {
        guard state.scene != nil,
              state.input != nil,
              state.display != nil,
              state.audio != nil else {
            return nil
        }
        guard let scene = rebrandScene(state.scene, revision: state.revision) else {
            throw PresentationAssemblyError.invalidComponent(.scene)
        }
        let input: TVVisionInputCapabilitySnapshot
        do {
            guard let value = try rebrandInput(
                state.input,
                scene: state.scene,
                componentsComplete:
                    state.display?.snapshot.isOutputAvailable == true,
                revision: state.revision
            ) else {
                throw PresentationAssemblyError.invalidComponent(.input)
            }
            input = value
        } catch let error as PresentationAssemblyError {
            throw error
        } catch {
            throw PresentationAssemblyError.invalidComponent(.input)
        }
        guard let display = rebrandDisplay(
            state.display,
            revision: state.revision
        ) else {
            throw PresentationAssemblyError.invalidComponent(.display)
        }
        guard let audio = rebrandAudio(
            state.audio,
            revision: state.revision
        ) else {
            throw PresentationAssemblyError.invalidComponent(.audioRoute)
        }
        do {
            return try TVVisionPlatformPresentationSnapshot(
                ownership: state.ownership,
                revision: state.revision,
                sceneSurface: scene,
                inputCapabilities: input,
                controllerLeases: state.input?.controllerLeases ?? [],
                display: display,
                audioRoute: audio
            )
        } catch let error as TVVisionPlatformContractError {
            switch error {
            case .invalidDisplaySnapshot:
                throw PresentationAssemblyError.invalidComponent(.display)
            case .invalidAudioRouteSnapshot, .incompatibleAudioStrategy:
                throw PresentationAssemblyError.invalidComponent(.audioRoute)
            case .inputGenerationMismatch,
                 .duplicateControllerSlot,
                 .duplicateControllerLease,
                 .unsupportedInputCapability:
                throw PresentationAssemblyError.invalidComponent(.input)
            default:
                throw PresentationAssemblyError.invalidComponent(.scene)
            }
        }
    }

    private func makeSynchronizedEffects(
        _ state: inout ActiveState,
        sequence: UInt64
    ) -> [TVVisionPlatformPresentationEffect] {
        let complete = state.presentation != nil
            && state.presentation?.display.isOutputAvailable == true
        let scene = rebrandScene(state.scene, revision: state.revision)
        let input = try? rebrandInput(
            state.input,
            scene: state.scene,
            componentsComplete: complete,
            revision: state.revision
        )
        let display = rebrandDisplay(state.display, revision: state.revision)
        let audio = rebrandAudio(state.audio, revision: state.revision)
        let eligible = isRenderEligible(state)

        var effects: [TVVisionPlatformPresentationEffect] = []
        if !eligible {
            effects.append(.input(input ?? nil))
            if activeState?.video.isPresented == true {
                effects.append(.clearVideo)
            }
            state.video = TVVisionPlatformVideoSnapshot(
                phase: state.video.phase,
                lastDeliveryRevision: state.video.lastDeliveryRevision,
                isPresented: false
            )
        }
        effects.append(.scene(scene))
        effects.append(.display(display))
        effects.append(.audioRoute(audio))
        if eligible {
            effects.append(.input(input ?? nil))
            if let application = makeVideoApplication(state, sequence: sequence) {
                state.video = TVVisionPlatformVideoSnapshot(
                    phase: state.video.phase,
                    lastDeliveryRevision: state.video.lastDeliveryRevision,
                    isPresented: true
                )
                effects.append(.video(application))
            }
        }
        return effects
    }

    private func makeVideoApplication(
        _ state: ActiveState,
        sequence: UInt64
    ) -> TVVisionPlatformVideoPresentationApplication? {
        guard isRenderEligible(state),
              let delivery = state.latestVideoDelivery,
              case .decodedFrame = delivery,
              let surfaceGeneration = state.scene?
                .snapshot.surfaceGeneration else {
            return nil
        }
        return TVVisionPlatformVideoPresentationApplication(
            ownership: state.ownership,
            sequence: sequence,
            platformRevision: state.revision,
            surfaceGeneration: surfaceGeneration,
            delivery: delivery
        )
    }

    private func isRenderEligible(_ state: ActiveState) -> Bool {
        guard let scene = rebrandScene(
            state.scene,
            revision: state.revision
        ) else { return false }
        return scene.attachment == .attached
            && scene.activity == .active
            && scene.isVisible
            && scene.geometry != nil
            && state.display?.snapshot.isOutputAvailable != false
    }

    private func rebrandScene(
        _ component: SceneComponent?,
        revision: TVVisionSemanticRevision
    ) -> TVVisionSceneSurfaceSnapshot? {
        guard let component else { return nil }
        return try? TVVisionSceneSurfaceSnapshot(
            platform: component.snapshot.platform,
            revision: revision,
            surfaceGeneration: component.snapshot.surfaceGeneration,
            activity: component.snapshot.activity,
            attachment: component.snapshot.attachment,
            isVisible: component.snapshot.isVisible,
            geometry: component.snapshot.geometry
        )
    }

    private func rebrandInput(
        _ component: InputComponent?,
        scene: SceneComponent?,
        componentsComplete: Bool,
        revision: TVVisionSemanticRevision
    ) throws -> TVVisionInputCapabilitySnapshot? {
        guard let component else { return nil }
        let eligibility: TVVisionFocusEligibility
        if !componentsComplete {
            eligibility = .ineligible(.inputUnavailable)
        } else if scene?.snapshot.attachment != .attached {
            eligibility = .ineligible(.detached)
        } else if scene?.snapshot.activity != .active {
            eligibility = .ineligible(.sceneInactive)
        } else if scene?.snapshot.isVisible != true
                    || scene?.isFocusEligible != true {
            eligibility = .ineligible(.notFocused)
        } else {
            eligibility = component.snapshot.focusEligibility
        }
        return try TVVisionInputCapabilitySnapshot(
            platform: component.snapshot.platform,
            revision: revision,
            inputGeneration: component.snapshot.inputGeneration,
            supported: component.snapshot.supported,
            focusEligibility: eligibility
        )
    }

    private func rebrandDisplay(
        _ component: DisplayComponent?,
        revision: TVVisionSemanticRevision
    ) -> TVVisionDisplaySnapshot? {
        guard let value = component?.snapshot else { return nil }
        return try? TVVisionDisplaySnapshot(
            platform: value.platform,
            revision: revision,
            displayGeneration: value.displayGeneration,
            isOutputAvailable: value.isOutputAvailable,
            headroomSource: value.headroomSource,
            currentEDRHeadroom: value.currentEDRHeadroom,
            potentialEDRHeadroom: value.potentialEDRHeadroom,
            layerCapability: value.layerCapability,
            tvOSHDRCapabilityResolution: value.tvOSHDRCapabilityResolution
        )
    }

    private func rebrandAudio(
        _ component: AudioComponent?,
        revision: TVVisionSemanticRevision
    ) -> TVVisionAudioRouteSnapshot? {
        guard let value = component?.snapshot else { return nil }
        return try? TVVisionAudioRouteSnapshot(
            platform: value.platform,
            revision: revision,
            routeGeneration: value.routeGeneration,
            outputAvailable: value.outputAvailable,
            currentOutputChannelCount: value.currentOutputChannelCount,
            maximumOutputChannelCount: value.maximumOutputChannelCount,
            spatialSupport: value.spatialSupport,
            platformStrategy: value.platformStrategy,
            headTrackingCapability: value.headTrackingCapability
        )
    }

    private func componentDecision(
        current: SceneComponent?,
        candidate: SceneComponent
    ) -> ComponentDecision {
        guard let current else { return .changed }
        return decision(
            currentGeneration: current.sourceGeneration,
            currentRevision: current.sourceRevision,
            currentValue: current,
            candidateGeneration: candidate.sourceGeneration,
            candidateRevision: candidate.sourceRevision,
            candidateValue: candidate
        )
    }

    private func componentDecision(
        current: DisplayComponent?,
        candidate: DisplayComponent
    ) -> ComponentDecision {
        guard let current else { return .changed }
        return decision(
            currentGeneration: current.sourceGeneration,
            currentRevision: current.sourceRevision,
            currentValue: current,
            candidateGeneration: candidate.sourceGeneration,
            candidateRevision: candidate.sourceRevision,
            candidateValue: candidate
        )
    }

    private func componentDecision(
        current: AudioComponent?,
        candidate: AudioComponent
    ) -> ComponentDecision {
        guard let current else { return .changed }
        return decision(
            currentGeneration: current.sourceGeneration,
            currentRevision: current.sourceRevision,
            currentValue: current,
            candidateGeneration: candidate.sourceGeneration,
            candidateRevision: candidate.sourceRevision,
            candidateValue: candidate
        )
    }

    private func inputDecision(
        current: InputComponent?,
        candidate: InputComponent
    ) -> ComponentDecision {
        guard let current else { return .changed }
        if candidate.sourceRevision < current.sourceRevision { return .stale }
        if candidate.sourceRevision == current.sourceRevision {
            guard candidate.snapshot == current.snapshot else {
                return .conflicting
            }
            return candidate.controllerLeases == current.controllerLeases
                ? .unchanged
                : .changed
        }
        return .changed
    }

    private func decision<Value: Equatable>(
        currentGeneration: TVVisionGeneration,
        currentRevision: TVVisionSemanticRevision,
        currentValue: Value,
        candidateGeneration: TVVisionGeneration,
        candidateRevision: TVVisionSemanticRevision,
        candidateValue: Value
    ) -> ComponentDecision {
        if candidateGeneration == currentGeneration {
            if candidateRevision < currentRevision { return .stale }
            if candidateRevision == currentRevision {
                return candidateValue == currentValue
                    ? .unchanged
                    : .conflicting
            }
            return .changed
        }
        return candidateGeneration.rawValue > currentGeneration.rawValue
            ? .changed
            : .stale
    }

    private func makeSnapshot(
        _ state: ActiveState,
        sequence: UInt64,
        phase: TVVisionPlatformPresentationPhase = .active
    ) -> TVVisionPlatformPresentationCoordinatorSnapshot {
        TVVisionPlatformPresentationCoordinatorSnapshot(
            ownership: state.ownership,
            sequence: sequence,
            revision: state.revision,
            phase: phase,
            presentation: phase == .active ? state.presentation : nil,
            display: phase == .active
                ? rebrandDisplay(state.display, revision: state.revision)
                : nil,
            video: state.video,
            diagnostics: diagnostics,
            teardownCount: teardownCount,
            isSemanticRevisionExhausted: isSemanticRevisionExhausted,
            isSequenceExhausted: isSequenceExhausted
        )
    }

    private func appendDiagnostic(
        _ classification: TVVisionPlatformPresentationDiagnosticClass,
        sequence: UInt64
    ) {
        diagnostics.append(TVVisionPlatformPresentationDiagnostic(
            sequence: sequence,
            classification: classification
        ))
        if diagnostics.count > diagnosticCapacity {
            diagnostics.removeFirst(diagnostics.count - diagnosticCapacity)
        }
    }

    private func applyEffect(
        _ effect: TVVisionPlatformPresentationEffect,
        ownership: TVVisionPresentationOwnership,
        sequence: UInt64
    ) async throws {
        try await actionClient.apply(
            TVVisionPlatformPresentationActionApplication(
                ownership: ownership,
                sequence: sequence,
                effect: effect
            )
        )
    }

    private func advanceRevision() -> TVVisionSemanticRevision? {
        guard !isSemanticRevisionExhausted else { return nil }
        if let currentRevision {
            guard let next = try? currentRevision.advanced() else {
                isSemanticRevisionExhausted = true
                return nil
            }
            self.currentRevision = next
            return next
        }
        let first = try? TVVisionSemanticRevision(rawValue: 1)
        currentRevision = first
        return first
    }

    private func advanceSequence() -> UInt64? {
        guard !isSequenceExhausted else { return nil }
        let next = sequence.addingReportingOverflow(1)
        guard !next.overflow else {
            isSequenceExhausted = true
            return nil
        }
        sequence = next.partialValue
        return sequence
    }

    private func decoderGeneration(_ state: ActiveState) -> UInt64? {
        switch state.video.phase {
        case .idle:
            nil
        case let .decoderReady(decoderGeneration),
             let .frameReady(decoderGeneration, _):
            decoderGeneration
        case let .cleared(decoderGeneration):
            decoderGeneration
        }
    }

    private func isNewer(
        _ candidate: TVVisionPresentationOwnership,
        than current: TVVisionPresentationOwnership
    ) -> Bool {
        guard candidate.platform == current.platform,
              candidate.sessionID == current.sessionID else {
            return false
        }
        if candidate.mediaGeneration != current.mediaGeneration {
            return candidate.mediaGeneration > current.mediaGeneration
        }
        if candidate.presentationGeneration != current.presentationGeneration {
            return candidate.presentationGeneration.rawValue
                > current.presentationGeneration.rawValue
        }
        return candidate.inputGeneration.rawValue
            > current.inputGeneration.rawValue
    }
}
