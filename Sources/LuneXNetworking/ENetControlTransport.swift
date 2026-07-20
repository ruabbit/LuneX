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

final class ENetConnectionDriver: ENetConnectionDriving, @unchecked Sendable {
    private static let maximumPayloadBytes = 64 * 1_024

    private let queue = DispatchQueue(label: "dev.lunex.enet.control")
    private var connection: OpaquePointer?

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
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                guard let connection = self.connection,
                      !payload.isEmpty,
                      payload.count <= Self.maximumPayloadBytes else {
                    continuation.resume(throwing: ENetTransportError.invalidArgument)
                    return
                }
                let result = payload.withUnsafeBytes { rawBuffer in
                    lunex_enet_send(
                        connection,
                        channelID,
                        rawBuffer.bindMemory(to: UInt8.self).baseAddress,
                        payload.count,
                        reliable
                    )
                }
                do {
                    try Self.validate(result)
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func service(timeoutMilliseconds: UInt32) async throws -> ENetServiceEvent {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                guard let connection = self.connection else {
                    continuation.resume(throwing: ENetTransportError.disconnected)
                    return
                }
                var payload = [UInt8](repeating: 0, count: Self.maximumPayloadBytes)
                var event = LuneXENetEvent()
                let result = payload.withUnsafeMutableBufferPointer { buffer in
                    lunex_enet_service(
                        connection,
                        timeoutMilliseconds,
                        buffer.baseAddress,
                        buffer.count,
                        &event
                    )
                }
                do {
                    try Self.validate(result)
                    switch event.type {
                    case LUNEX_ENET_EVENT_NONE:
                        continuation.resume(returning: .idle)
                    case LUNEX_ENET_EVENT_RECEIVE:
                        guard event.payloadLength <= payload.count else {
                            throw ENetTransportError.payloadTooLarge
                        }
                        continuation.resume(returning: .received(
                            channelID: event.channelID,
                            payload: Data(payload.prefix(event.payloadLength))
                        ))
                    case LUNEX_ENET_EVENT_DISCONNECT:
                        continuation.resume(returning: .disconnected(data: event.data))
                    default:
                        continuation.resume(throwing: ENetTransportError.serviceFailed)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
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
                continuation.resume()
            }
        }
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
