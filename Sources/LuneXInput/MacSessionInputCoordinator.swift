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
    case capacityExceeded(limit: Int)
    case deliveryFailed
}

enum MacSessionInputEnqueueResult: Equatable, Sendable {
    case accepted
    case rejected(MacSessionInputRejection)
}

struct MacSessionInputCoordinatorSnapshot: Equatable, Sendable {
    var generation: MacSessionInputGeneration?
    var acceptsInput: Bool
    var queuedSampleCount: Int
    var hasInFlightSample: Bool
    var acceptedSampleCount: UInt64
    var deliveredEventCount: UInt64
    var reservedSampleCount: UInt64
    var droppedSampleCount: UInt64
    var rejectedSampleCount: UInt64
    var deliveryFailureCount: UInt64
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
    private var acceptsInput = false
    private var queue: MacInputSampleFIFO
    private var hasInFlightSample = false
    private var signalContinuation: AsyncStream<Void>.Continuation?
    private var consumerTask: Task<Void, Never>?
    private var acceptedSampleCount: UInt64 = 0
    private var deliveredEventCount: UInt64 = 0
    private var reservedSampleCount: UInt64 = 0
    private var droppedSampleCount: UInt64 = 0
    private var rejectedSampleCount: UInt64 = 0
    private var deliveryFailureCount: UInt64 = 0

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
            return .rejected(.deliveryFailed)
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

    func snapshot() -> MacSessionInputCoordinatorSnapshot {
        MacSessionInputCoordinatorSnapshot(
            generation: generation,
            acceptsInput: acceptsInput,
            queuedSampleCount: queue.count,
            hasInFlightSample: hasInFlightSample,
            acceptedSampleCount: acceptedSampleCount,
            deliveredEventCount: deliveredEventCount,
            reservedSampleCount: reservedSampleCount,
            droppedSampleCount: droppedSampleCount,
            rejectedSampleCount: rejectedSampleCount,
            deliveryFailureCount: deliveryFailureCount
        )
    }

    private func drain(generation: MacSessionInputGeneration) async {
        while self.generation == generation, acceptsInput, !Task.isCancelled {
            guard let envelope = queue.popFirst() else { return }
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
        }
    }

    private func invalidateCurrentGeneration() {
        acceptsInput = false
        generation = nil
        droppedSampleCount &+= UInt64(queue.count)
        queue.removeAll()
        hasInFlightSample = false
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
    }
}
