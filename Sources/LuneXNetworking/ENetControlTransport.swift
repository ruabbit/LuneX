import Foundation

enum ENetTransportError: Error, Equatable, Sendable {
    case invalidArgument
    case initializationFailed
    case resolutionFailed
    case hostCreationFailed
    case connectionFailed
    case timedOut
    case disconnected
    case sendFailed
    case serviceFailed
    case payloadTooLarge
    case unknown(code: Int32)
}

enum ENetServiceEvent: Equatable, Sendable {
    case idle
    case received(channelID: UInt8, payload: Data)
    case disconnected(data: UInt32)
}

protocol ENetConnectionDriving: Sendable {
    func connect(
        host: String,
        port: UInt16,
        channelCount: UInt8,
        connectData: UInt32,
        timeoutMilliseconds: UInt32
    ) async throws

    func send(
        _ payload: Data,
        channelID: UInt8,
        reliable: Bool
    ) async throws

    func service(timeoutMilliseconds: UInt32) async throws -> ENetServiceEvent
    func disconnect() async
}

struct ENetConnectionDriverSnapshot: Equatable, Sendable {
    var pendingSendCount: Int
    var pendingServiceCount: Int
    var enqueuedSendCount: UInt64
    var sentPacketCount: UInt64
    var flushCount: UInt64
    var serviceCallCount: UInt64
    var rejectedSendCount: UInt64
    var rejectedServiceCount: UInt64
    var maximumServiceSliceMilliseconds: UInt32
    var maximumSendQueueDelayNanoseconds: UInt64
}

final class ENetConnectionDriver: ENetConnectionDriving, @unchecked Sendable {
    private static let maximumPayloadBytes = 64 * 1_024
    private static let maximumPendingSends = 256
    private static let maximumPendingServices = 4
    private static let maximumServiceSliceMilliseconds: UInt32 = 1
    private static let outboundBatchDelay = DispatchTimeInterval.milliseconds(1)

    private struct PendingSend {
        var payload: Data
        var channelID: UInt8
        var reliable: Bool
        var enqueuedAtNanoseconds: UInt64
        var continuation: CheckedContinuation<Void, Error>
    }

    private struct PendingService {
        var deadlineNanoseconds: UInt64
        var continuation: CheckedContinuation<ENetServiceEvent, Error>
    }

    private let queue = DispatchQueue(label: "dev.lunex.enet.control")
    private var connection: OpaquePointer?
    private var pendingSends: [PendingSend] = []
    private var pendingServices: [PendingService] = []
    private var isPumpScheduled = false
    private var enqueuedSendCount: UInt64 = 0
    private var sentPacketCount: UInt64 = 0
    private var flushCount: UInt64 = 0
    private var serviceCallCount: UInt64 = 0
    private var rejectedSendCount: UInt64 = 0
    private var rejectedServiceCount: UInt64 = 0
    private var maximumServiceSliceMilliseconds: UInt32 = 0
    private var maximumSendQueueDelayNanoseconds: UInt64 = 0

    func connect(
        host: String,
        port: UInt16,
        channelCount: UInt8,
        connectData: UInt32,
        timeoutMilliseconds: UInt32
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard self.connection == nil else {
                    continuation.resume(throwing: ENetTransportError.invalidArgument)
                    return
                }
                var result = LUNEX_ENET_OK
                let connection = host.withCString { hostPointer in
                    lunex_enet_connect(
                        hostPointer,
                        port,
                        channelCount,
                        connectData,
                        timeoutMilliseconds,
                        &result
                    )
                }
                do {
                    try Self.validate(result)
                    guard let connection else {
                        throw ENetTransportError.connectionFailed
                    }
                    self.connection = connection
                    self.resetMetrics()
                    continuation.resume()
                } catch {
                    if let connection {
                        lunex_enet_disconnect(connection)
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func send(
        _ payload: Data,
        channelID: UInt8,
        reliable: Bool
    ) async throws {
        guard !payload.isEmpty,
              payload.count <= Self.maximumPayloadBytes else {
            throw ENetTransportError.invalidArgument
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard self.connection != nil else {
                    continuation.resume(throwing: ENetTransportError.disconnected)
                    return
                }
                guard self.pendingSends.count < Self.maximumPendingSends else {
                    self.rejectedSendCount = Self.saturatedIncrement(self.rejectedSendCount)
                    continuation.resume(throwing: ENetTransportError.sendFailed)
                    return
                }
                self.enqueuedSendCount = Self.saturatedIncrement(self.enqueuedSendCount)
                self.pendingSends.append(PendingSend(
                    payload: payload,
                    channelID: channelID,
                    reliable: reliable,
                    enqueuedAtNanoseconds: DispatchTime.now().uptimeNanoseconds,
                    continuation: continuation
                ))
                self.schedulePump(after: Self.outboundBatchDelay)
            }
        }
    }

    func service(timeoutMilliseconds: UInt32) async throws -> ENetServiceEvent {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ENetServiceEvent, Error>) in
            queue.async {
                guard self.connection != nil else {
                    continuation.resume(throwing: ENetTransportError.disconnected)
                    return
                }
                guard self.pendingServices.count < Self.maximumPendingServices else {
                    self.rejectedServiceCount = Self.saturatedIncrement(self.rejectedServiceCount)
                    continuation.resume(throwing: ENetTransportError.serviceFailed)
                    return
                }
                let now = DispatchTime.now().uptimeNanoseconds
                let timeoutNanoseconds = UInt64(timeoutMilliseconds) * 1_000_000
                self.pendingServices.append(PendingService(
                    deadlineNanoseconds: Self.saturatedAdd(now, timeoutNanoseconds),
                    continuation: continuation
                ))
                self.schedulePump()
            }
        }
    }

    func disconnect() async {
        await withCheckedContinuation { continuation in
            queue.async {
                if let connection = self.connection {
                    self.connection = nil
                    lunex_enet_disconnect(connection)
                }
                let sends = self.pendingSends
                let services = self.pendingServices
                self.pendingSends.removeAll(keepingCapacity: false)
                self.pendingServices.removeAll(keepingCapacity: false)
                for send in sends {
                    send.continuation.resume(throwing: ENetTransportError.disconnected)
                }
                for service in services {
                    service.continuation.resume(throwing: ENetTransportError.disconnected)
                }
                continuation.resume()
            }
        }
    }

    func snapshot() async -> ENetConnectionDriverSnapshot {
        await withCheckedContinuation { continuation in
            queue.async {
                continuation.resume(returning: ENetConnectionDriverSnapshot(
                    pendingSendCount: self.pendingSends.count,
                    pendingServiceCount: self.pendingServices.count,
                    enqueuedSendCount: self.enqueuedSendCount,
                    sentPacketCount: self.sentPacketCount,
                    flushCount: self.flushCount,
                    serviceCallCount: self.serviceCallCount,
                    rejectedSendCount: self.rejectedSendCount,
                    rejectedServiceCount: self.rejectedServiceCount,
                    maximumServiceSliceMilliseconds: self.maximumServiceSliceMilliseconds,
                    maximumSendQueueDelayNanoseconds: self.maximumSendQueueDelayNanoseconds
                ))
            }
        }
    }

    private func schedulePump(after delay: DispatchTimeInterval? = nil) {
        guard !isPumpScheduled else { return }
        isPumpScheduled = true
        let work: @Sendable () -> Void = { [self] in
            isPumpScheduled = false
            runPumpStep()
        }
        if let delay {
            queue.asyncAfter(deadline: .now() + delay, execute: work)
        } else {
            queue.async(execute: work)
        }
    }

    private func runPumpStep() {
        guard let connection else {
            failPending(with: ENetTransportError.disconnected)
            return
        }

        if !pendingSends.isEmpty {
            let sends = pendingSends
            pendingSends.removeAll(keepingCapacity: true)
            var results: [Result<Void, Error>] = []
            results.reserveCapacity(sends.count)
            var queuedPacket = false
            for send in sends {
                let queueDelay = DispatchTime.now().uptimeNanoseconds
                    .subtractingReportingOverflow(send.enqueuedAtNanoseconds)
                if !queueDelay.overflow {
                    maximumSendQueueDelayNanoseconds = max(
                        maximumSendQueueDelayNanoseconds,
                        queueDelay.partialValue
                    )
                }
                let result = send.payload.withUnsafeBytes { rawBuffer in
                    lunex_enet_queue_send(
                        connection,
                        send.channelID,
                        rawBuffer.bindMemory(to: UInt8.self).baseAddress,
                        send.payload.count,
                        send.reliable
                    )
                }
                do {
                    try Self.validate(result)
                    queuedPacket = true
                    sentPacketCount = Self.saturatedIncrement(sentPacketCount)
                    results.append(.success(()))
                } catch {
                    results.append(.failure(error))
                }
            }
            if queuedPacket {
                do {
                    try Self.validate(lunex_enet_flush(connection))
                    flushCount = Self.saturatedIncrement(flushCount)
                } catch {
                    results = results.map { result in
                        if case .success = result { return .failure(error) }
                        return result
                    }
                }
            }
            for (send, result) in zip(sends, results) {
                send.continuation.resume(with: result)
            }
        }

        if !pendingServices.isEmpty {
            serviceFirstPendingRequest(on: connection)
        }

        if !pendingSends.isEmpty || !pendingServices.isEmpty {
            schedulePump()
        }
    }

    private func serviceFirstPendingRequest(on connection: OpaquePointer) {
        let now = DispatchTime.now().uptimeNanoseconds
        let deadline = pendingServices[0].deadlineNanoseconds
        let timeout: UInt32 = deadline > now ? Self.maximumServiceSliceMilliseconds : 0
        maximumServiceSliceMilliseconds = max(maximumServiceSliceMilliseconds, timeout)
        serviceCallCount = Self.saturatedIncrement(serviceCallCount)

        var payload = [UInt8](repeating: 0, count: Self.maximumPayloadBytes)
        var event = LuneXENetEvent()
        let result = payload.withUnsafeMutableBufferPointer { buffer in
            lunex_enet_service(
                connection,
                timeout,
                buffer.baseAddress,
                buffer.count,
                &event
            )
        }
        do {
            try Self.validate(result)
            let resolved: ENetServiceEvent?
            switch event.type {
            case LUNEX_ENET_EVENT_NONE:
                resolved = DispatchTime.now().uptimeNanoseconds >= deadline ? .idle : nil
            case LUNEX_ENET_EVENT_RECEIVE:
                guard event.payloadLength <= payload.count else {
                    throw ENetTransportError.payloadTooLarge
                }
                resolved = .received(
                    channelID: event.channelID,
                    payload: Data(payload.prefix(event.payloadLength))
                )
            case LUNEX_ENET_EVENT_DISCONNECT:
                resolved = .disconnected(data: event.data)
            default:
                throw ENetTransportError.serviceFailed
            }
            if let resolved {
                let request = pendingServices.removeFirst()
                request.continuation.resume(returning: resolved)
            }
        } catch {
            let request = pendingServices.removeFirst()
            request.continuation.resume(throwing: error)
        }
    }

    private func failPending(with error: Error) {
        let sends = pendingSends
        let services = pendingServices
        pendingSends.removeAll(keepingCapacity: false)
        pendingServices.removeAll(keepingCapacity: false)
        for send in sends { send.continuation.resume(throwing: error) }
        for service in services { service.continuation.resume(throwing: error) }
    }

    private static func saturatedIncrement(_ value: UInt64) -> UInt64 {
        value == .max ? .max : value + 1
    }

    private func resetMetrics() {
        enqueuedSendCount = 0
        sentPacketCount = 0
        flushCount = 0
        serviceCallCount = 0
        rejectedSendCount = 0
        rejectedServiceCount = 0
        maximumServiceSliceMilliseconds = 0
        maximumSendQueueDelayNanoseconds = 0
    }

    private static func saturatedAdd(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 {
        let result = lhs.addingReportingOverflow(rhs)
        return result.overflow ? .max : result.partialValue
    }

    private static func validate(_ result: LuneXENetResult) throws {
        guard result != LUNEX_ENET_OK else { return }
        switch result {
        case LUNEX_ENET_ERROR_INVALID_ARGUMENT:
            throw ENetTransportError.invalidArgument
        case LUNEX_ENET_ERROR_INITIALIZATION:
            throw ENetTransportError.initializationFailed
        case LUNEX_ENET_ERROR_RESOLUTION:
            throw ENetTransportError.resolutionFailed
        case LUNEX_ENET_ERROR_HOST_CREATION:
            throw ENetTransportError.hostCreationFailed
        case LUNEX_ENET_ERROR_CONNECTION:
            throw ENetTransportError.connectionFailed
        case LUNEX_ENET_ERROR_TIMEOUT:
            throw ENetTransportError.timedOut
        case LUNEX_ENET_ERROR_DISCONNECTED:
            throw ENetTransportError.disconnected
        case LUNEX_ENET_ERROR_SEND:
            throw ENetTransportError.sendFailed
        case LUNEX_ENET_ERROR_SERVICE:
            throw ENetTransportError.serviceFailed
        case LUNEX_ENET_ERROR_PAYLOAD_TOO_LARGE:
            throw ENetTransportError.payloadTooLarge
        default:
            throw ENetTransportError.unknown(code: result.rawValue)
        }
    }
}
