import Foundation

protocol AuthenticatedInputFrameSending: Sendable {
    func activateInput(configuration: NegotiatedInputConfiguration) async throws
    func sendInput(
        _ packet: RemoteInputPlaintextPacket,
        channelID: UInt8,
        reliable: Bool
    ) async throws
    func deactivateInput() async
}

enum RemoteInputRuntimeError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidConfiguration
    case invalidEndpoint
    case inactiveSession
    case sessionMismatch
    case queueFull
    case deliveryFailed

    var description: String {
        switch self {
        case .invalidConfiguration:
            return "The negotiated remote-input configuration is invalid."
        case .invalidEndpoint:
            return "The negotiated remote-input endpoint is invalid."
        case .inactiveSession:
            return "Remote input is not active for a session."
        case .sessionMismatch:
            return "The remote-input event belongs to a different session."
        case .queueFull:
            return "The bounded remote-input delivery queue is full."
        case .deliveryFailed:
            return "The authenticated remote-input transport failed."
        }
    }
}

struct RemoteInputDeliveryLimits: Equatable, Sendable {
    static let production = RemoteInputDeliveryLimits(
        maximumPendingEvents: 256,
        maximumPendingPackets: 8_192,
        maximumPendingCalls: 8_192
    )

    var maximumPendingEvents: Int
    var maximumPendingPackets: Int
    var maximumPendingCalls: Int
}

actor MoonlightRemoteInputProvider: RemoteInputProvider {
    private struct PendingDelivery {
        var event: RemoteInputEvent
        var packets: [RemoteInputOutboundPacket]
        var continuations: [CheckedContinuation<Void, Error>]
    }

    private let sender: any AuthenticatedInputFrameSending
    private let deliveryLimits: RemoteInputDeliveryLimits
    private var activeSessionID: UUID?
    private var generation: UInt64 = 0
    private var pending: [PendingDelivery] = []
    private var pendingPacketCount = 0
    private var pendingCallCount = 0
    private var drainTask: Task<Void, Never>?

    init(
        sender: any AuthenticatedInputFrameSending,
        deliveryLimits: RemoteInputDeliveryLimits = .production
    ) {
        self.sender = sender
        self.deliveryLimits = deliveryLimits
    }

    func startInput(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedInputConfiguration
    ) async throws {
        guard activeSessionID == nil, drainTask == nil else {
            throw RemoteInputRuntimeError.inactiveSession
        }
        do {
            try endpoint.validate()
        } catch {
            throw RemoteInputRuntimeError.invalidEndpoint
        }
        do {
            try configuration.validate()
        } catch {
            throw RemoteInputRuntimeError.invalidConfiguration
        }

        try await sender.activateInput(configuration: configuration)
        generation &+= 1
        activeSessionID = sessionID
    }

    func send(_ event: RemoteInputEvent, sessionID: UUID) async throws {
        guard let activeSessionID else {
            throw RemoteInputRuntimeError.inactiveSession
        }
        guard activeSessionID == sessionID else {
            throw RemoteInputRuntimeError.sessionMismatch
        }
        let packets = try RemoteInputWireCodec.outboundPackets(for: event)
        guard !packets.isEmpty else { return }

        let coalescedEvent = pending.last.flatMap {
            RemoteInputMovementCoalescer.coalesce(older: $0.event, newer: event)
        }
        let coalescedPackets = coalescedEvent.flatMap {
            try? RemoteInputWireCodec.outboundPackets(for: $0)
        }
        let canCoalesce = coalescedEvent != nil && coalescedPackets != nil
        let previousPacketCount = canCoalesce ? pending.last?.packets.count ?? 0 : 0
        let nextPacketCount = canCoalesce ? coalescedPackets?.count ?? 0 : packets.count
        let nextEventCount = pending.count + (canCoalesce ? 0 : 1)
        guard deliveryLimits.maximumPendingEvents > 0,
              deliveryLimits.maximumPendingPackets > 0,
              deliveryLimits.maximumPendingCalls > 0,
              nextEventCount <= deliveryLimits.maximumPendingEvents,
              pendingCallCount < deliveryLimits.maximumPendingCalls,
              pendingPacketCount - previousPacketCount + nextPacketCount <= deliveryLimits.maximumPendingPackets else {
            throw RemoteInputRuntimeError.queueFull
        }

        try await withCheckedThrowingContinuation { continuation in
            if canCoalesce,
               let coalescedEvent,
               let coalescedPackets,
               !pending.isEmpty {
                pendingPacketCount -= pending[pending.count - 1].packets.count
                pending[pending.count - 1].event = coalescedEvent
                pending[pending.count - 1].packets = coalescedPackets
                pending[pending.count - 1].continuations.append(continuation)
                pendingPacketCount += coalescedPackets.count
            } else {
                pending.append(PendingDelivery(
                    event: event,
                    packets: packets,
                    continuations: [continuation]
                ))
                pendingPacketCount += packets.count
            }
            pendingCallCount += 1
            startDrainIfNeeded()
        }
    }

    func feedback(sessionID: UUID) async -> AsyncStream<RemoteInputFeedback> {
        _ = sessionID
        return AsyncStream { continuation in
            continuation.finish()
        }
    }

    func releaseAll(sessionID: UUID) async {
        _ = sessionID
        // Held-state tracking and synthesized release events are implemented in task 7.5.
    }

    func stopInput(sessionID: UUID) async {
        guard activeSessionID == sessionID else { return }
        activeSessionID = nil
        generation &+= 1
        failPending(with: RemoteInputRuntimeError.inactiveSession)
        let task = drainTask
        task?.cancel()
        await task?.value
        drainTask = nil
        await sender.deactivateInput()
    }

    private func startDrainIfNeeded() {
        guard drainTask == nil, activeSessionID != nil else { return }
        let drainGeneration = generation
        drainTask = Task {
            await drain(generation: drainGeneration)
        }
    }

    private func drain(generation drainGeneration: UInt64) async {
        while drainGeneration == generation, activeSessionID != nil {
            guard !pending.isEmpty else {
                drainTask = nil
                return
            }
            let delivery = pending.removeFirst()
            pendingPacketCount -= delivery.packets.count
            pendingCallCount -= delivery.continuations.count

            do {
                for packet in delivery.packets {
                    try Task.checkCancellation()
                    try await sender.sendInput(
                        packet.plaintext,
                        channelID: packet.channelID,
                        reliable: packet.reliable
                    )
                    try Task.checkCancellation()
                }
                guard drainGeneration == generation, activeSessionID != nil else {
                    throw CancellationError()
                }
                for continuation in delivery.continuations {
                    continuation.resume()
                }
            } catch {
                let wasCancelled = Task.isCancelled || drainGeneration != generation
                for continuation in delivery.continuations {
                    continuation.resume(throwing: wasCancelled
                        ? RemoteInputRuntimeError.inactiveSession
                        : RemoteInputRuntimeError.deliveryFailed)
                }
                guard !wasCancelled else {
                    drainTask = nil
                    return
                }

                activeSessionID = nil
                generation &+= 1
                failPending(with: RemoteInputRuntimeError.deliveryFailed)
                drainTask = nil
                await sender.deactivateInput()
                return
            }
        }
        drainTask = nil
    }

    private func failPending(with error: RemoteInputRuntimeError) {
        let queued = pending
        pending.removeAll(keepingCapacity: false)
        pendingPacketCount = 0
        pendingCallCount = 0
        for delivery in queued {
            for continuation in delivery.continuations {
                continuation.resume(throwing: error)
            }
        }
    }
}

enum RemoteInputMovementCoalescer {
    static func coalesce(
        older: RemoteInputEvent,
        newer: RemoteInputEvent
    ) -> RemoteInputEvent? {
        switch (older, newer) {
        case let (
            .pointer(.relativeMove(oldX, oldY, oldButtons)),
            .pointer(.relativeMove(newX, newY, newButtons))
        ) where oldButtons == newButtons:
            let combinedX = oldX + newX
            let combinedY = oldY + newY
            guard combinedX.isFinite, combinedY.isFinite else { return nil }
            return .pointer(.relativeMove(
                deltaX: combinedX,
                deltaY: combinedY,
                buttons: newButtons
            ))
        case let (
            .pointer(.absoluteMove(_, oldReferenceSize, oldButtons)),
            .pointer(.absoluteMove(newPoint, newReferenceSize, newButtons))
        ) where oldReferenceSize == newReferenceSize && oldButtons == newButtons:
            return .pointer(.absoluteMove(
                point: newPoint,
                referenceSize: newReferenceSize,
                buttons: newButtons
            ))
        default:
            return nil
        }
    }
}
