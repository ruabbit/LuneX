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

actor MoonlightRemoteInputProvider: RemoteInputProvider {
    private struct PendingDelivery {
        var packets: [RemoteInputOutboundPacket]
        var continuation: CheckedContinuation<Void, Error>
    }

    private static let maximumPendingEvents = 256
    private static let maximumPendingPackets = 8_192

    private let sender: any AuthenticatedInputFrameSending
    private var activeSessionID: UUID?
    private var generation: UInt64 = 0
    private var pending: [PendingDelivery] = []
    private var pendingPacketCount = 0
    private var drainTask: Task<Void, Never>?

    init(sender: any AuthenticatedInputFrameSending) {
        self.sender = sender
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
        guard pending.count < Self.maximumPendingEvents,
              pendingPacketCount + packets.count <= Self.maximumPendingPackets else {
            throw RemoteInputRuntimeError.queueFull
        }

        try await withCheckedThrowingContinuation { continuation in
            pending.append(PendingDelivery(
                packets: packets,
                continuation: continuation
            ))
            pendingPacketCount += packets.count
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
                delivery.continuation.resume()
            } catch {
                let wasCancelled = Task.isCancelled || drainGeneration != generation
                delivery.continuation.resume(throwing: wasCancelled
                    ? RemoteInputRuntimeError.inactiveSession
                    : RemoteInputRuntimeError.deliveryFailed)
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
        for delivery in queued {
            delivery.continuation.resume(throwing: error)
        }
    }
}
