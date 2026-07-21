import Foundation

enum MacSessionInputQueuePolicyError: Error, Equatable, Sendable {
    case invalidCapacity(Int)
}

struct MacSessionInputQueuePolicy: Equatable, Sendable {
    static let realtime = MacSessionInputQueuePolicy(
        validatedMaximumPendingSamples: 256
    )

    let maximumPendingSamples: Int

    init(maximumPendingSamples: Int) throws {
        guard (1...4_096).contains(maximumPendingSamples) else {
            throw MacSessionInputQueuePolicyError.invalidCapacity(maximumPendingSamples)
        }
        self.maximumPendingSamples = maximumPendingSamples
    }

    private init(validatedMaximumPendingSamples: Int) {
        maximumPendingSamples = validatedMaximumPendingSamples
    }
}

enum MacPlatformInputSample: Equatable, Sendable {
    case keyboard(MacKeyboardSample)
    case pointerMove(MacPointerSample)
    case button(button: PointerButton, isDown: Bool, localPoint: RemotePoint?)
    case scroll(MacScrollSample)
}

struct MacInputSampleEnvelope: Equatable, Sendable {
    var sample: MacPlatformInputSample
    var coordinateSnapshot: StreamCoordinateSnapshot
    var cursorPolicy: CursorCapturePolicy
    var forwardsSystemShortcuts: Bool

    func resolve() -> InputAdapterOutput {
        let adapter = MacInputAdapter(
            mapper: InputMapper(snapshot: coordinateSnapshot),
            cursorPolicy: cursorPolicy,
            forwardsSystemShortcuts: forwardsSystemShortcuts
        )
        switch sample {
        case let .keyboard(sample):
            return adapter.keyboard(sample)
        case let .pointerMove(sample):
            return adapter.pointerMove(sample)
        case let .button(button, isDown, localPoint):
            return adapter.button(button, isDown: isDown, localPoint: localPoint)
        case let .scroll(sample):
            return adapter.scroll(sample)
        }
    }
}

struct MacSessionInputGeneration: Equatable, Hashable, Sendable {
    fileprivate let id: UUID
}

enum MacSessionInputRejection: Equatable, Sendable {
    case inactiveGeneration
    case staleGeneration
    case admissionClosed
    case capacityExceeded(limit: Int)
}

enum MacSessionInputEnqueueResult: Equatable, Sendable {
    case accepted
    case rejected(MacSessionInputRejection)
}

enum MacSessionInputFocusUpdateResult: Equatable, Sendable {
    case applied
    case inactiveGeneration
    case staleGeneration
    case terminationInProgress
}

enum MacSessionInputTerminationReason: Equatable, Sendable {
    case sendFailure
    case inputChannelFailure
    case stop
    case remoteTermination
    case detached
    case replacement
}

enum MacSessionInputTerminationResult: Equatable, Sendable {
    case completed
    case inactiveGeneration
    case staleGeneration
}

struct MacSessionInputCoordinatorSnapshot: Equatable, Sendable {
    var generation: MacSessionInputGeneration?
    var isFocusEligible: Bool
    var acceptsInput: Bool
    var queuedSampleCount: Int
    var hasInFlightSample: Bool
    var acceptedSampleCount: UInt64
    var deliveredEventCount: UInt64
    var reservedSampleCount: UInt64
    var droppedSampleCount: UInt64
    var rejectedSampleCount: UInt64
    var deliveryFailureCount: UInt64
    var hasPendingReleaseBarrier: Bool
    var hasInFlightReleaseBarrier: Bool
    var completedReleaseBarrierCount: UInt64
    var releaseBarrierFailureCount: UInt64
    var terminationReason: MacSessionInputTerminationReason?
    var captureCleanupCount: UInt64
}

private struct MacInputSampleFIFO {
    private var storage: [MacInputSampleEnvelope?]
    private var head = 0
    private var tail = 0
    private(set) var count = 0

    init(capacity: Int) {
        storage = Array(repeating: nil, count: capacity)
    }

    mutating func append(_ envelope: MacInputSampleEnvelope) -> Bool {
        guard count < storage.count else { return false }
        storage[tail] = envelope
        tail = (tail + 1) % storage.count
        count += 1
        return true
    }

    mutating func popFirst() -> MacInputSampleEnvelope? {
        guard count > 0 else { return nil }
        let envelope = storage[head]
        storage[head] = nil
        head = (head + 1) % storage.count
        count -= 1
        return envelope
    }

    mutating func removeAll() {
        storage = Array(repeating: nil, count: storage.count)
        head = 0
        tail = 0
        count = 0
    }
}

@MainActor
final class MacSessionInputCoordinator {
    private struct ActivationOperation {
        var id: UUID
        var task: Task<MacSessionInputGeneration, Never>
    }

    private let sink: any ApplicationInputSink
    private let policy: MacSessionInputQueuePolicy
    private let releaseCapture: @MainActor @Sendable () -> Void

    private var generation: MacSessionInputGeneration?
    private var isFocusEligible = false
    private var acceptsInput = false
    private var queue: MacInputSampleFIFO
    private var hasInFlightSample = false
    private var hasPendingReleaseBarrier = false
    private var hasInFlightReleaseBarrier = false
    private var signalContinuation: AsyncStream<Void>.Continuation?
    private var consumerTask: Task<Void, Never>?
    private var activationOperation: ActivationOperation?
    private var acceptedSampleCount: UInt64 = 0
    private var deliveredEventCount: UInt64 = 0
    private var reservedSampleCount: UInt64 = 0
    private var droppedSampleCount: UInt64 = 0
    private var rejectedSampleCount: UInt64 = 0
    private var deliveryFailureCount: UInt64 = 0
    private var completedReleaseBarrierCount: UInt64 = 0
    private var releaseBarrierFailureCount: UInt64 = 0
    private var terminationReason: MacSessionInputTerminationReason?
    private var captureCleanupCount: UInt64 = 0
    private var didReleaseCapture = false

    init(
        sink: any ApplicationInputSink,
        policy: MacSessionInputQueuePolicy = .realtime,
        releaseCapture: @escaping @MainActor @Sendable () -> Void = {}
    ) {
        self.sink = sink
        self.policy = policy
        self.releaseCapture = releaseCapture
        queue = MacInputSampleFIFO(capacity: policy.maximumPendingSamples)
    }

    deinit {
        signalContinuation?.finish()
        consumerTask?.cancel()
        activationOperation?.task.cancel()
    }

    func activate() async -> MacSessionInputGeneration {
        if let activationOperation {
            return await activationOperation.task.value
        }
        let id = UUID()
        let task = Task { [self] in
            await performActivation()
        }
        activationOperation = ActivationOperation(id: id, task: task)
        let generation = await task.value
        if activationOperation?.id == id {
            activationOperation = nil
        }
        return generation
    }

    private func performActivation() async -> MacSessionInputGeneration {
        if let generation {
            _ = await terminate(generation: generation, reason: .replacement)
        }
        resetCounters()
        let generation = MacSessionInputGeneration(id: UUID())
        let signals = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        self.generation = generation
        isFocusEligible = true
        acceptsInput = true
        signalContinuation = signals.continuation
        consumerTask = Task { [weak self] in
            for await _ in signals.stream {
                guard !Task.isCancelled, let self else { return }
                await self.drain(generation: generation)
            }
        }
        return generation
    }

    @discardableResult
    func deactivate(generation: MacSessionInputGeneration) async -> Bool {
        await terminate(generation: generation, reason: .stop) == .completed
    }

    func enqueue(
        _ envelope: MacInputSampleEnvelope,
        generation: MacSessionInputGeneration
    ) -> MacSessionInputEnqueueResult {
        guard let currentGeneration = self.generation else {
            rejectedSampleCount &+= 1
            return .rejected(.inactiveGeneration)
        }
        guard currentGeneration == generation else {
            rejectedSampleCount &+= 1
            return .rejected(.staleGeneration)
        }
        guard acceptsInput else {
            rejectedSampleCount &+= 1
            return .rejected(.admissionClosed)
        }
        let outstanding = queue.count + (hasInFlightSample ? 1 : 0)
        guard outstanding < policy.maximumPendingSamples else {
            rejectedSampleCount &+= 1
            return .rejected(.capacityExceeded(
                limit: policy.maximumPendingSamples
            ))
        }
        guard queue.append(envelope) else {
            rejectedSampleCount &+= 1
            return .rejected(.capacityExceeded(
                limit: policy.maximumPendingSamples
            ))
        }
        acceptedSampleCount &+= 1
        signalContinuation?.yield(())
        return .accepted
    }

    @discardableResult
    func setFocusEligible(
        _ eligible: Bool,
        generation: MacSessionInputGeneration
    ) -> MacSessionInputFocusUpdateResult {
        guard let currentGeneration = self.generation else {
            return .inactiveGeneration
        }
        guard currentGeneration == generation else {
            return .staleGeneration
        }
        guard terminationReason == nil else {
            return .terminationInProgress
        }
        guard isFocusEligible != eligible else { return .applied }

        isFocusEligible = eligible
        if eligible {
            if !hasPendingReleaseBarrier && !hasInFlightReleaseBarrier {
                acceptsInput = true
            }
        } else {
            acceptsInput = false
            if !hasPendingReleaseBarrier && !hasInFlightReleaseBarrier {
                hasPendingReleaseBarrier = true
                signalContinuation?.yield(())
            }
        }
        return .applied
    }

    func terminate(
        generation: MacSessionInputGeneration,
        reason: MacSessionInputTerminationReason
    ) async -> MacSessionInputTerminationResult {
        guard let currentGeneration = self.generation else {
            return .inactiveGeneration
        }
        guard currentGeneration == generation else {
            return .staleGeneration
        }

        beginTermination(reason: reason, requiresReleaseBarrier: true)
        let task = consumerTask
        signalContinuation?.yield(())
        await task?.value
        if self.generation == generation {
            invalidateCurrentGeneration()
        }
        return .completed
    }

    func snapshot() -> MacSessionInputCoordinatorSnapshot {
        MacSessionInputCoordinatorSnapshot(
            generation: generation,
            isFocusEligible: isFocusEligible,
            acceptsInput: acceptsInput,
            queuedSampleCount: queue.count,
            hasInFlightSample: hasInFlightSample,
            acceptedSampleCount: acceptedSampleCount,
            deliveredEventCount: deliveredEventCount,
            reservedSampleCount: reservedSampleCount,
            droppedSampleCount: droppedSampleCount,
            rejectedSampleCount: rejectedSampleCount,
            deliveryFailureCount: deliveryFailureCount,
            hasPendingReleaseBarrier: hasPendingReleaseBarrier,
            hasInFlightReleaseBarrier: hasInFlightReleaseBarrier,
            completedReleaseBarrierCount: completedReleaseBarrierCount,
            releaseBarrierFailureCount: releaseBarrierFailureCount,
            terminationReason: terminationReason,
            captureCleanupCount: captureCleanupCount
        )
    }

    private func drain(generation: MacSessionInputGeneration) async {
        while self.generation == generation, !Task.isCancelled {
            if let envelope = queue.popFirst() {
                hasInFlightSample = true
                let output = envelope.resolve()

                switch output.policy {
                case .deliver:
                    guard let event = output.event else {
                        droppedSampleCount &+= 1
                        hasInFlightSample = false
                        continue
                    }
                    do {
                        try await sink.sendRemoteInput(event)
                    } catch {
                        guard self.generation == generation else { return }
                        deliveryFailureCount &+= 1
                        hasInFlightSample = false
                        beginTermination(
                            reason: .sendFailure,
                            requiresReleaseBarrier: false
                        )
                        signalContinuation?.finish()
                        return
                    }
                    guard self.generation == generation else { return }
                    deliveredEventCount &+= 1
                case .reserveLocally:
                    reservedSampleCount &+= 1
                case .drop:
                    droppedSampleCount &+= 1
                }
                hasInFlightSample = false
                continue
            }

            guard hasPendingReleaseBarrier else {
                if terminationReason != nil {
                    signalContinuation?.finish()
                }
                return
            }
            hasPendingReleaseBarrier = false
            hasInFlightReleaseBarrier = true
            do {
                try await sink.releaseRemoteInput()
            } catch {
                guard self.generation == generation else { return }
                releaseBarrierFailureCount &+= 1
                hasInFlightReleaseBarrier = false
                acceptsInput = false
                if terminationReason != nil {
                    signalContinuation?.finish()
                }
                return
            }
            guard self.generation == generation else { return }
            hasInFlightReleaseBarrier = false
            completedReleaseBarrierCount &+= 1
            if terminationReason != nil {
                signalContinuation?.finish()
                return
            }
            acceptsInput = isFocusEligible
        }
    }

    private func beginTermination(
        reason: MacSessionInputTerminationReason,
        requiresReleaseBarrier: Bool
    ) {
        if terminationReason == nil {
            terminationReason = reason
        }
        acceptsInput = false
        isFocusEligible = false
        droppedSampleCount &+= UInt64(queue.count)
        queue.removeAll()
        if !didReleaseCapture {
            didReleaseCapture = true
            captureCleanupCount &+= 1
            releaseCapture()
        }
        if requiresReleaseBarrier {
            if !hasPendingReleaseBarrier && !hasInFlightReleaseBarrier {
                hasPendingReleaseBarrier = true
            }
        } else {
            hasPendingReleaseBarrier = false
        }
    }

    private func invalidateCurrentGeneration() {
        acceptsInput = false
        isFocusEligible = false
        generation = nil
        droppedSampleCount &+= UInt64(queue.count)
        queue.removeAll()
        hasInFlightSample = false
        hasPendingReleaseBarrier = false
        hasInFlightReleaseBarrier = false
        signalContinuation?.finish()
        signalContinuation = nil
        consumerTask?.cancel()
        consumerTask = nil
    }

    private func resetCounters() {
        acceptedSampleCount = 0
        deliveredEventCount = 0
        reservedSampleCount = 0
        droppedSampleCount = 0
        rejectedSampleCount = 0
        deliveryFailureCount = 0
        completedReleaseBarrierCount = 0
        releaseBarrierFailureCount = 0
        terminationReason = nil
        captureCleanupCount = 0
        didReleaseCapture = false
    }
}
