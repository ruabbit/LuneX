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
    private let sink: any ApplicationInputSink
    private let policy: MacSessionInputQueuePolicy

    private var generation: MacSessionInputGeneration?
    private var isFocusEligible = false
    private var acceptsInput = false
    private var queue: MacInputSampleFIFO
    private var hasInFlightSample = false
    private var hasPendingReleaseBarrier = false
    private var hasInFlightReleaseBarrier = false
    private var signalContinuation: AsyncStream<Void>.Continuation?
    private var consumerTask: Task<Void, Never>?
    private var acceptedSampleCount: UInt64 = 0
    private var deliveredEventCount: UInt64 = 0
    private var reservedSampleCount: UInt64 = 0
    private var droppedSampleCount: UInt64 = 0
    private var rejectedSampleCount: UInt64 = 0
    private var deliveryFailureCount: UInt64 = 0
    private var completedReleaseBarrierCount: UInt64 = 0
    private var releaseBarrierFailureCount: UInt64 = 0

    init(
        sink: any ApplicationInputSink,
        policy: MacSessionInputQueuePolicy = .realtime
    ) {
        self.sink = sink
        self.policy = policy
        queue = MacInputSampleFIFO(capacity: policy.maximumPendingSamples)
    }

    deinit {
        signalContinuation?.finish()
        consumerTask?.cancel()
    }

    func activate() -> MacSessionInputGeneration {
        invalidateCurrentGeneration()
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
    func deactivate(generation: MacSessionInputGeneration) -> Bool {
        guard self.generation == generation else { return false }
        invalidateCurrentGeneration()
        return true
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
            releaseBarrierFailureCount: releaseBarrierFailureCount
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
                        droppedSampleCount &+= UInt64(queue.count)
                        queue.removeAll()
                        acceptsInput = false
                        hasInFlightSample = false
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

            guard hasPendingReleaseBarrier else { return }
            hasPendingReleaseBarrier = false
            hasInFlightReleaseBarrier = true
            do {
                try await sink.releaseRemoteInput()
            } catch {
                guard self.generation == generation else { return }
                releaseBarrierFailureCount &+= 1
                hasInFlightReleaseBarrier = false
                acceptsInput = false
                return
            }
            guard self.generation == generation else { return }
            hasInFlightReleaseBarrier = false
            completedReleaseBarrierCount &+= 1
            acceptsInput = isFocusEligible
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
    }
}
