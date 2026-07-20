import Foundation
@preconcurrency import Network

enum NetworkChannelError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidEndpoint
    case invalidReadBounds
    case payloadTooLarge(maximum: Int)
    case invalidTimeout
    case invalidState
    case timedOut(operation: String)
    case cancelled
    case closed
    case posixFailure(code: Int32)
    case dnsFailure(code: Int32)
    case tlsFailure(code: Int32)
    case wifiAwareFailure(code: Int32)
    case unknownTransportFailure

    var description: String {
        switch self {
        case .invalidEndpoint:
            return "Network endpoint is invalid."
        case .invalidReadBounds:
            return "Network read bounds are invalid."
        case let .payloadTooLarge(maximum):
            return "Network payload exceeds the \(maximum)-byte limit."
        case .invalidTimeout:
            return "Network timeout must be positive."
        case .invalidState:
            return "Network channel operation is invalid in the current state."
        case let .timedOut(operation):
            return "Network \(operation) timed out."
        case .cancelled:
            return "Network channel was cancelled."
        case .closed:
            return "Network peer closed the channel."
        case let .posixFailure(code):
            return "Network POSIX failure \(code)."
        case let .dnsFailure(code):
            return "Network DNS failure \(code)."
        case let .tlsFailure(code):
            return "Network TLS failure \(code)."
        case let .wifiAwareFailure(code):
            return "Network Wi-Fi Aware failure \(code)."
        case .unknownTransportFailure:
            return "Network transport failed."
        }
    }
}

struct NetworkChannelLimits: Equatable, Sendable {
    var maximumSendBytes: Int
    var maximumReceiveBytes: Int

    static let moonlightControl = NetworkChannelLimits(
        maximumSendBytes: 64 * 1_024,
        maximumReceiveBytes: 64 * 1_024
    )

    static let moonlightDatagram = NetworkChannelLimits(
        maximumSendBytes: 1_500,
        maximumReceiveBytes: 1_500
    )

    func validate() throws {
        guard maximumSendBytes > 0, maximumReceiveBytes > 0 else {
            throw NetworkChannelError.invalidReadBounds
        }
    }
}

struct NetworkReceiveChunk: Equatable, Sendable {
    var data: Data
    var isComplete: Bool
}

protocol NetworkConnectionDriving: Sendable {
    func start() async throws
    func send(_ data: Data) async throws
    func receive(minimumLength: Int, maximumLength: Int) async throws -> NetworkReceiveChunk
    func cancel() async
}

private final class ContinuationGate<Success: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    func resume(
        _ continuation: CheckedContinuation<Success, Error>,
        with result: Result<Success, Error>
    ) {
        lock.lock()
        guard !didResume else {
            lock.unlock()
            return
        }
        didResume = true
        lock.unlock()
        continuation.resume(with: result)
    }
}

final class NWConnectionDriver: NetworkConnectionDriving, @unchecked Sendable {
    private let connection: NWConnection
    private let queue = DispatchQueue(label: "dev.lunex.network.connection")

    init(endpoint: RuntimeNetworkEndpoint) throws {
        try endpoint.validate()
        guard let port = NWEndpoint.Port(rawValue: endpoint.port) else {
            throw NetworkChannelError.invalidEndpoint
        }
        let parameters: NWParameters = endpoint.transport == .tcp ? .tcp : .udp
        connection = NWConnection(
            host: NWEndpoint.Host(endpoint.host),
            port: port,
            using: parameters
        )
    }

    func start() async throws {
        let connection = connection
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let gate = ContinuationGate<Void>()
                connection.stateUpdateHandler = { state in
                    switch state {
                    case .ready:
                        gate.resume(continuation, with: .success(()))
                    case let .failed(error):
                        gate.resume(continuation, with: .failure(Self.map(error)))
                    case .cancelled:
                        gate.resume(continuation, with: .failure(NetworkChannelError.cancelled))
                    default:
                        break
                    }
                }
                connection.start(queue: queue)
            }
        } onCancel: {
            connection.cancel()
        }
    }

    func send(_ data: Data) async throws {
        let connection = connection
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let gate = ContinuationGate<Void>()
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error {
                        gate.resume(continuation, with: .failure(Self.map(error)))
                    } else {
                        gate.resume(continuation, with: .success(()))
                    }
                })
            }
        } onCancel: {
            connection.cancel()
        }
    }

    func receive(
        minimumLength: Int,
        maximumLength: Int
    ) async throws -> NetworkReceiveChunk {
        let connection = connection
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let gate = ContinuationGate<NetworkReceiveChunk>()
                connection.receive(
                    minimumIncompleteLength: minimumLength,
                    maximumLength: maximumLength
                ) { data, _, isComplete, error in
                    if let error {
                        gate.resume(continuation, with: .failure(Self.map(error)))
                    } else {
                        gate.resume(
                            continuation,
                            with: .success(NetworkReceiveChunk(
                                data: data ?? Data(),
                                isComplete: isComplete
                            ))
                        )
                    }
                }
            }
        } onCancel: {
            connection.cancel()
        }
    }

    func cancel() async {
        connection.cancel()
    }

    private static func map(_ error: NWError) -> NetworkChannelError {
        switch error {
        case let .posix(code):
            return .posixFailure(code: code.rawValue)
        case let .dns(code):
            return .dnsFailure(code: code)
        case let .tls(code):
            return .tlsFailure(code: code)
        case let .wifiAware(code):
            return .wifiAwareFailure(code: code)
        @unknown default:
            return .unknownTransportFailure
        }
    }
}

actor NetworkByteChannel {
    enum State: Equatable, Sendable {
        case idle
        case connecting
        case ready
        case closed
        case cancelled
        case failed
    }

    private let driver: any NetworkConnectionDriving
    private let limits: NetworkChannelLimits
    private(set) var state: State = .idle

    init(
        endpoint: RuntimeNetworkEndpoint,
        limits: NetworkChannelLimits
    ) throws {
        try limits.validate()
        driver = try NWConnectionDriver(endpoint: endpoint)
        self.limits = limits
    }

    init(
        driver: any NetworkConnectionDriving,
        limits: NetworkChannelLimits
    ) throws {
        try limits.validate()
        self.driver = driver
        self.limits = limits
    }

    func connect(timeout: Duration) async throws {
        guard state == .idle else {
            throw NetworkChannelError.invalidState
        }
        state = .connecting
        do {
            try await Self.withTimeout(timeout, operationName: "connect") {
                try await self.driver.start()
            }
            state = .ready
        } catch {
            state = error is CancellationError ? .cancelled : .failed
            await driver.cancel()
            throw error
        }
    }

    func send(_ data: Data, timeout: Duration) async throws {
        guard state == .ready else {
            throw NetworkChannelError.invalidState
        }
        guard data.count <= limits.maximumSendBytes else {
            throw NetworkChannelError.payloadTooLarge(maximum: limits.maximumSendBytes)
        }
        do {
            try await Self.withTimeout(timeout, operationName: "send") {
                try await self.driver.send(data)
            }
        } catch {
            state = error is CancellationError ? .cancelled : .failed
            await driver.cancel()
            throw error
        }
    }

    func receive(
        minimumLength: Int = 1,
        maximumLength: Int? = nil,
        timeout: Duration
    ) async throws -> NetworkReceiveChunk {
        guard state == .ready else {
            throw NetworkChannelError.invalidState
        }
        let maximumLength = maximumLength ?? limits.maximumReceiveBytes
        guard minimumLength >= 0,
              maximumLength > 0,
              minimumLength <= maximumLength,
              maximumLength <= limits.maximumReceiveBytes else {
            throw NetworkChannelError.invalidReadBounds
        }

        do {
            let chunk = try await Self.withTimeout(timeout, operationName: "receive") {
                try await self.driver.receive(
                    minimumLength: minimumLength,
                    maximumLength: maximumLength
                )
            }
            guard chunk.data.count <= maximumLength else {
                state = .failed
                await driver.cancel()
                throw NetworkChannelError.payloadTooLarge(maximum: maximumLength)
            }
            if chunk.isComplete && chunk.data.isEmpty {
                state = .closed
                throw NetworkChannelError.closed
            }
            return chunk
        } catch {
            if state != .closed {
                state = error is CancellationError ? .cancelled : .failed
                await driver.cancel()
            }
            throw error
        }
    }

    func cancel() async {
        guard state != .cancelled else { return }
        state = .cancelled
        await driver.cancel()
    }

    private static func withTimeout<Success: Sendable>(
        _ timeout: Duration,
        operationName: String,
        operation: @escaping @Sendable () async throws -> Success
    ) async throws -> Success {
        guard timeout > .zero else {
            throw NetworkChannelError.invalidTimeout
        }
        return try await withThrowingTaskGroup(of: Success.self) { group in
            group.addTask(operation: operation)
            group.addTask {
                try await Task.sleep(for: timeout)
                throw NetworkChannelError.timedOut(operation: operationName)
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else {
                throw NetworkChannelError.cancelled
            }
            return result
        }
    }
}
