import Foundation

@MainActor
protocol MobilePictureInPictureLifecycleFrameSink: AnyObject {
    var generation: MobilePictureInPictureGeneration { get }

    func currentFrameSinkSnapshot()
        -> MobilePictureInPictureFrameSinkSnapshot
    @discardableResult
    func flushForPictureInPictureLifecycle() -> Bool
    func invalidate()
}

enum MobilePictureInPictureLifecycleCoordinatorError:
    Error,
    Equatable,
    Sendable
{
    case clientGenerationMismatch
    case frameSinkGenerationMismatch
}

enum MobilePictureInPictureLifecycleCoordinatorEvent:
    Equatable,
    Sendable
{
    case snapshot(MobilePictureInPictureSnapshot)
    case restoreInterfaceRequested(
        MobilePictureInPictureRestorationLease
    )
    case setPlayingRequested(Bool)
    case skipRequested(
        interval: MobilePictureInPictureSkipInterval,
        completion: MobilePictureInPictureClientCallbackLease
    )
    case renderSizeChanged(MobilePictureInPictureRenderSize)
    case rejected(MobilePictureInPictureRejection)
    case revisionExhausted
}

typealias MobilePictureInPictureLifecycleCoordinatorEventHandler =
    @MainActor (MobilePictureInPictureLifecycleCoordinatorEvent) -> Void

enum MobilePictureInPictureLifecycleCoordinatorOutcome:
    Equatable,
    Sendable
{
    case unchanged
    case applied(MobilePictureInPictureSnapshot)
    case rejected(MobilePictureInPictureRejection)
    case revisionExhausted
    case invalidated
}

@MainActor
final class MobilePictureInPictureLifecycleCoordinator {
    let generation: MobilePictureInPictureGeneration

    var snapshot: MobilePictureInPictureSnapshot? {
        reducer.snapshot
    }

    private let client: any MobilePictureInPictureControllerClient
    private let frameSink:
        any MobilePictureInPictureLifecycleFrameSink
    private var reducer: MobilePictureInPictureStateReducer
    private var eventHandler:
        MobilePictureInPictureLifecycleCoordinatorEventHandler?
    private var pendingRestorationCallbacks: [
        MobilePictureInPictureRestorationLease:
            MobilePictureInPictureClientCallbackLease
    ] = [:]
    private var pendingSkipCallbacks:
        Set<MobilePictureInPictureClientCallbackLease> = []
    private var playbackState: MobilePictureInPicturePlaybackState?
    private var isTerminating = false
    private(set) var isInvalidated = false

    init(
        generation: MobilePictureInPictureGeneration,
        client: any MobilePictureInPictureControllerClient,
        frameSink: any MobilePictureInPictureLifecycleFrameSink,
        initialRevision: MobilePictureInPictureRevision =
            MobilePictureInPictureRevision(rawValue: 0),
        initialRestorationOrdinal: UInt64 = 0
    ) throws {
        guard client.generation == generation else {
            throw MobilePictureInPictureLifecycleCoordinatorError
                .clientGenerationMismatch
        }
        guard frameSink.generation == generation else {
            throw MobilePictureInPictureLifecycleCoordinatorError
                .frameSinkGenerationMismatch
        }
        self.generation = generation
        self.client = client
        self.frameSink = frameSink
        reducer = MobilePictureInPictureStateReducer(
            generation: generation,
            initialRevision: initialRevision,
            initialRestorationOrdinal: initialRestorationOrdinal
        )
        client.setEventHandler { [weak self] envelope in
            self?.handleClientEvent(envelope)
        }
    }

    func setEventHandler(
        _ handler:
            MobilePictureInPictureLifecycleCoordinatorEventHandler?
    ) {
        guard isOperational else { return }
        eventHandler = handler
        if handler == nil {
            completePendingConsumerCallbacks()
        } else if let lease =
                    pendingRestorationCallbacks.keys.first {
            deliverRestorationRequest(lease)
        }
    }

    @discardableResult
    func prepare()
        -> MobilePictureInPictureLifecycleCoordinatorOutcome
    {
        guard isOperational else { return .invalidated }
        let outcome = reduce(.prepareRequested)
        if case .applied = outcome {
            if let preparation = client.preparationSnapshot {
                applyPreparation(preparation)
            } else {
                client.prepare()
            }
        }
        return outcome
    }

    @discardableResult
    func requestStart()
        -> MobilePictureInPictureLifecycleCoordinatorOutcome
    {
        guard isOperational else { return .invalidated }
        return reduce(.startRequested)
    }

    @discardableResult
    func requestStop()
        -> MobilePictureInPictureLifecycleCoordinatorOutcome
    {
        guard isOperational else { return .invalidated }
        return reduce(.stopRequested)
    }

    @discardableResult
    func refreshFrameSink()
        -> MobilePictureInPictureLifecycleCoordinatorOutcome
    {
        guard isOperational else { return .invalidated }
        return reduce(.frameSinkChanged(
            frameSink.currentFrameSinkSnapshot()
        ))
    }

    @discardableResult
    func updatePlaybackState(
        _ state: MobilePictureInPicturePlaybackState
    ) -> Bool {
        guard isOperational, state != playbackState else {
            return false
        }
        playbackState = state
        client.updatePlaybackState(state)
        client.invalidatePlaybackState()
        return true
    }

    @discardableResult
    func completeRestoration(
        _ lease: MobilePictureInPictureRestorationLease,
        result: MobilePictureInPictureRestorationResult
    ) -> MobilePictureInPictureLifecycleCoordinatorOutcome {
        guard isOperational else { return .invalidated }
        return reduce(.restorationCompleted(
            lease: lease,
            result: result
        ))
    }

    @discardableResult
    func completeSkip(
        _ lease: MobilePictureInPictureClientCallbackLease
    ) -> MobilePictureInPictureClientCallbackOutcome {
        guard isOperational else { return .invalidated }
        let outcome = client.completeCallback(lease, with: .skip)
        if outcome == .completed
            || outcome == .alreadyCompleted
            || outcome == .invalidated {
            pendingSkipCallbacks.remove(lease)
        }
        return outcome
    }

    @discardableResult
    func invalidate()
        -> MobilePictureInPictureLifecycleCoordinatorOutcome
    {
        guard isOperational else { return .invalidated }
        isTerminating = true
        let outcome = reduce(.invalidate)
        finishInvalidation(invalidateClient: true)
        return outcome
    }

    private func handleClientEvent(
        _ envelope: MobilePictureInPictureClientEventEnvelope
    ) {
        guard isOperational, envelope.generation == generation else {
            return
        }
        switch envelope.event {
        case let .prepared(preparation):
            applyPreparation(preparation)
        case let .capabilityChanged(capability):
            _ = reduce(.capabilityChanged(capability))
        case .willStart:
            _ = reduce(.willStart)
        case .didStart:
            _ = reduce(.didStart)
        case let .startFailed(failure):
            _ = reduce(.startFailed(failure))
        case .willStop:
            _ = reduce(.willStop)
        case .didStop:
            _ = reduce(.didStop)
        case let .restoreInterfaceRequested(clientLease):
            registerRestoration(clientLease)
        case let .setPlaying(isPlaying):
            emit(.setPlayingRequested(isPlaying))
        case let .skipRequested(interval, completion):
            registerSkip(interval: interval, clientLease: completion)
        case let .renderSizeChanged(renderSize):
            emit(.renderSizeChanged(renderSize))
        case .invalidated:
            isTerminating = true
            _ = reduce(.invalidate)
            finishInvalidation(invalidateClient: false)
        }
    }

    private var isOperational: Bool {
        !isInvalidated && !isTerminating
    }

    private func applyPreparation(
        _ preparation:
            MobilePictureInPictureClientPreparationSnapshot
    ) {
        guard preparation.generation == generation else { return }
        _ = reduce(.prepared(
            capability: preparation.capability,
            frameSink: frameSink.currentFrameSinkSnapshot()
        ))
    }

    private func registerRestoration(
        _ clientLease: MobilePictureInPictureClientCallbackLease
    ) {
        guard clientLease.generation == generation,
              clientLease.kind == .restoreInterface else {
            _ = client.completeCallback(
                clientLease,
                with: .restoreInterface(restored: false)
            )
            return
        }
        let before = reducer.snapshot?.state.restoration.pendingLease
        let outcome = reduce(.restorationRequested)
        guard case let .applied(snapshot) = outcome,
              let runtimeLease = snapshot.state.restoration.pendingLease,
              runtimeLease != before else {
            _ = client.completeCallback(
                clientLease,
                with: .restoreInterface(restored: false)
            )
            return
        }
        pendingRestorationCallbacks[runtimeLease] = clientLease
        deliverRestorationRequest(runtimeLease)
    }

    private func registerSkip(
        interval: MobilePictureInPictureSkipInterval,
        clientLease: MobilePictureInPictureClientCallbackLease
    ) {
        guard clientLease.generation == generation,
              clientLease.kind == .skip else {
            _ = client.completeCallback(clientLease, with: .skip)
            return
        }
        guard eventHandler != nil else {
            _ = client.completeCallback(clientLease, with: .skip)
            return
        }
        pendingSkipCallbacks.insert(clientLease)
        emit(.skipRequested(
            interval: interval,
            completion: clientLease
        ))
    }

    private func reduce(
        _ event: MobilePictureInPictureEvent
    ) -> MobilePictureInPictureLifecycleCoordinatorOutcome {
        let envelope = MobilePictureInPictureEventEnvelope(
            generation: generation,
            event: event
        )
        switch reducer.apply(envelope) {
        case .unchanged:
            return .unchanged
        case let .rejected(rejection):
            emit(.rejected(rejection))
            return .rejected(rejection)
        case let .applied(snapshot, effects):
            emit(.snapshot(snapshot))
            execute(effects)
            return .applied(snapshot)
        case let .revisionExhausted(effects):
            isTerminating = true
            execute(effects)
            emit(.revisionExhausted)
            finishInvalidation(invalidateClient: true)
            return .revisionExhausted
        }
    }

    private func execute(
        _ effects: [MobilePictureInPictureEffect]
    ) {
        for effect in effects {
            switch effect {
            case .requestNativeStart:
                client.requestStart()
            case .requestNativeStop:
                client.requestStop()
            case let .restoreInterface(lease):
                deliverRestorationRequest(lease)
            case let .completeRestoration(lease, restored):
                completeNativeRestoration(
                    lease,
                    restored: restored
                )
            case .flushFrameSink:
                _ = frameSink.flushForPictureInPictureLifecycle()
            case .releaseFrameSink:
                frameSink.invalidate()
            }
        }
    }

    private func deliverRestorationRequest(
        _ lease: MobilePictureInPictureRestorationLease
    ) {
        guard pendingRestorationCallbacks[lease] != nil else {
            return
        }
        guard eventHandler != nil else {
            _ = completeRestoration(lease, result: .declined)
            return
        }
        emit(.restoreInterfaceRequested(lease))
    }

    private func completeNativeRestoration(
        _ lease: MobilePictureInPictureRestorationLease,
        restored: Bool
    ) {
        guard let clientLease =
                pendingRestorationCallbacks.removeValue(
                    forKey: lease
                ) else {
            return
        }
        _ = client.completeCallback(
            clientLease,
            with: .restoreInterface(restored: restored)
        )
    }

    private func completePendingConsumerCallbacks() {
        if let lease =
                pendingRestorationCallbacks.keys.first {
            _ = completeRestoration(lease, result: .declined)
        }
        let skipLeases = Array(pendingSkipCallbacks)
        pendingSkipCallbacks.removeAll(keepingCapacity: false)
        for lease in skipLeases {
            _ = client.completeCallback(lease, with: .skip)
        }
    }

    private func finishInvalidation(invalidateClient: Bool) {
        guard !isInvalidated else { return }
        isInvalidated = true
        isTerminating = true
        playbackState = nil
        eventHandler = nil
        client.setEventHandler(nil)
        drainPendingCallbacksForTerminalInvalidation()
        if invalidateClient {
            client.invalidate()
        }
        frameSink.invalidate()
    }

    private func drainPendingCallbacksForTerminalInvalidation() {
        let restorationLeases =
            Array(pendingRestorationCallbacks.values)
        let skipLeases = Array(pendingSkipCallbacks)
        pendingRestorationCallbacks.removeAll(keepingCapacity: false)
        pendingSkipCallbacks.removeAll(keepingCapacity: false)

        for lease in restorationLeases {
            _ = client.completeCallback(
                lease,
                with: .restoreInterface(restored: false)
            )
        }
        for lease in skipLeases {
            _ = client.completeCallback(lease, with: .skip)
        }
    }

    private func emit(
        _ event: MobilePictureInPictureLifecycleCoordinatorEvent
    ) {
        eventHandler?(event)
    }
}
