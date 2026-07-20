import Foundation
@preconcurrency import Network
import XCTest

final class NetworkChannelTests: XCTestCase {
    func testChannelConnectsSendsAndReceivesWithinBounds() async throws {
        let driver = InMemoryNetworkDriver(
            receiveChunks: [NetworkReceiveChunk(data: Data([1, 2, 3]), isComplete: false)]
        )
        let channel = try NetworkByteChannel(
            driver: driver,
            limits: NetworkChannelLimits(maximumSendBytes: 8, maximumReceiveBytes: 8)
        )

        try await channel.connect(timeout: .seconds(1))
        try await channel.send(Data([4, 5]), timeout: .seconds(1))
        let chunk = try await channel.receive(maximumLength: 4, timeout: .seconds(1))

        XCTAssertEqual(chunk.data, Data([1, 2, 3]))
        let sent = await driver.sentPayloads
        XCTAssertEqual(sent, [Data([4, 5])])
        let state = await channel.state
        XCTAssertEqual(state, .ready)
    }

    func testChannelRejectsOversizedSendBeforeDriverCall() async throws {
        let driver = InMemoryNetworkDriver()
        let channel = try NetworkByteChannel(
            driver: driver,
            limits: NetworkChannelLimits(maximumSendBytes: 2, maximumReceiveBytes: 8)
        )
        try await channel.connect(timeout: .seconds(1))

        do {
            try await channel.send(Data([1, 2, 3]), timeout: .seconds(1))
            XCTFail("Expected payload limit failure")
        } catch let error as NetworkChannelError {
            XCTAssertEqual(error, .payloadTooLarge(maximum: 2))
        }
        let sent = await driver.sentPayloads
        XCTAssertTrue(sent.isEmpty)
    }

    func testChannelRejectsReceiveBoundAboveConfiguredMaximum() async throws {
        let driver = InMemoryNetworkDriver()
        let channel = try NetworkByteChannel(
            driver: driver,
            limits: NetworkChannelLimits(maximumSendBytes: 8, maximumReceiveBytes: 8)
        )
        try await channel.connect(timeout: .seconds(1))

        do {
            _ = try await channel.receive(maximumLength: 9, timeout: .seconds(1))
            XCTFail("Expected read bound failure")
        } catch let error as NetworkChannelError {
            XCTAssertEqual(error, .invalidReadBounds)
        }
        let receives = await driver.receiveCallCount
        XCTAssertEqual(receives, 0)
    }

    func testConnectTimeoutCancelsUnderlyingDriver() async throws {
        let driver = InMemoryNetworkDriver(blockStartUntilCancelled: true)
        let channel = try NetworkByteChannel(
            driver: driver,
            limits: .moonlightControl
        )

        do {
            try await channel.connect(timeout: .milliseconds(20))
            XCTFail("Expected timeout")
        } catch let error as NetworkChannelError {
            XCTAssertEqual(error, .timedOut(operation: "connect"))
        }

        let cancelled = await driver.isCancelled
        XCTAssertTrue(cancelled)
        let state = await channel.state
        XCTAssertEqual(state, .failed)
    }

    func testEmptyCompleteReceiveMarksChannelClosed() async throws {
        let driver = InMemoryNetworkDriver(
            receiveChunks: [NetworkReceiveChunk(data: Data(), isComplete: true)]
        )
        let channel = try NetworkByteChannel(
            driver: driver,
            limits: .moonlightControl
        )
        try await channel.connect(timeout: .seconds(1))

        do {
            _ = try await channel.receive(timeout: .seconds(1))
            XCTFail("Expected closed channel")
        } catch let error as NetworkChannelError {
            XCTAssertEqual(error, .closed)
        }
        let state = await channel.state
        XCTAssertEqual(state, .closed)
    }

    func testRealTCPDriverRoundTripsBoundedLoopbackPayload() async throws {
        try await assertLoopbackRoundTrip(transport: .tcp)
    }

    func testRealUDPDriverRoundTripsBoundedLoopbackPayload() async throws {
        try await assertLoopbackRoundTrip(transport: .udp)
    }

    func testFrameDecoderHandlesFragmentedAndCoalescedFrames() throws {
        var decoder = try BoundedLengthPrefixedFrameDecoder(
            prefixWidth: .uint16,
            maximumFrameLength: 8
        )

        XCTAssertTrue(try decoder.append(Data([0, 3, 1])).isEmpty)
        let frames = try decoder.append(Data([2, 3, 0, 2, 4, 5]))

        XCTAssertEqual(frames, [Data([1, 2, 3]), Data([4, 5])])
        XCTAssertEqual(decoder.bufferedByteCount, 0)
        XCTAssertNoThrow(try decoder.finish())
    }

    func testFrameDecoderRejectsOversizedDeclarationWithoutPayload() throws {
        var decoder = try BoundedLengthPrefixedFrameDecoder(
            prefixWidth: .uint32,
            maximumFrameLength: 1_024
        )

        XCTAssertThrowsError(try decoder.append(Data([0, 0, 8, 0]))) { error in
            XCTAssertEqual(
                error as? NetworkFrameDecodingError,
                .declaredLengthExceedsLimit(declared: 2_048, maximum: 1_024)
            )
        }
    }

    func testFrameDecoderRejectsTruncatedFrameAtEndOfStream() throws {
        var decoder = try BoundedLengthPrefixedFrameDecoder(
            prefixWidth: .uint16,
            maximumFrameLength: 8
        )
        _ = try decoder.append(Data([0, 3, 1, 2]))

        XCTAssertThrowsError(try decoder.finish()) { error in
            XCTAssertEqual(error as? NetworkFrameDecodingError, .truncatedFrame)
        }
    }

    func testExternalTaskCancellationCancelsConnection() async throws {
        let driver = InMemoryNetworkDriver(blockStartUntilCancelled: true)
        let channel = try NetworkByteChannel(driver: driver, limits: .moonlightControl)
        let task = Task {
            try await channel.connect(timeout: .seconds(5))
        }
        try await Task.sleep(for: .milliseconds(10))
        task.cancel()

        do {
            try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
        }
        let driverCancelled = await driver.isCancelled
        let channelState = await channel.state
        XCTAssertTrue(driverCancelled)
        XCTAssertEqual(channelState, .cancelled)
    }

    func testReceiveTimeoutCancelsConnection() async throws {
        let driver = InMemoryNetworkDriver(blockReceiveUntilCancelled: true)
        let channel = try NetworkByteChannel(driver: driver, limits: .moonlightControl)
        try await channel.connect(timeout: .seconds(1))

        do {
            _ = try await channel.receive(timeout: .milliseconds(20))
            XCTFail("Expected receive timeout")
        } catch let error as NetworkChannelError {
            XCTAssertEqual(error, .timedOut(operation: "receive"))
        }
        let driverCancelled = await driver.isCancelled
        XCTAssertTrue(driverCancelled)
    }

    func testSessionTrackerReleasesOwnedChannelAndReceiveTask() async throws {
        let driver = InMemoryNetworkDriver(blockReceiveUntilCancelled: true)
        let channel = try NetworkByteChannel(driver: driver, limits: .moonlightControl)
        try await channel.connect(timeout: .seconds(1))
        let tracker = SessionResourceTracker()
        _ = try await tracker.registerResource(kind: .networkChannel, name: "control") {
            await channel.cancel()
        }
        _ = try await tracker.startTask(name: "control-receive") {
            _ = try await channel.receive(timeout: .seconds(5))
        }
        try await Task.sleep(for: .milliseconds(5))

        let report = try await tracker.teardown(gracePeriod: .seconds(1))

        XCTAssertTrue(report.isClean)
        XCTAssertEqual(report.stoppedResourceCount, 1)
        let driverCancelled = await driver.isCancelled
        let channelState = await channel.state
        XCTAssertTrue(driverCancelled)
        XCTAssertEqual(channelState, .cancelled)
    }

    private func assertLoopbackRoundTrip(
        transport: RuntimeTransportKind
    ) async throws {
        let server = try LocalNetworkEchoServer(transport: transport)
        let port = try await server.start()
        defer { server.cancel() }

        let channel = try NetworkByteChannel(
            endpoint: RuntimeNetworkEndpoint(
                host: "127.0.0.1",
                port: port,
                transport: transport
            ),
            limits: .moonlightDatagram
        )
        try await channel.connect(timeout: .seconds(2))
        let payload = Data("loopback-runtime-channel".utf8)
        try await channel.send(payload, timeout: .seconds(2))
        let response = try await channel.receive(
            maximumLength: 128,
            timeout: .seconds(2)
        )
        XCTAssertEqual(response.data, payload)
        await channel.cancel()
    }
}

private final class LocalNetworkEchoServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "dev.lunex.tests.network-echo")

    init(transport: RuntimeTransportKind) throws {
        let parameters: NWParameters = transport == .tcp ? .tcp : .udp
        listener = try NWListener(using: parameters, on: .any)
    }

    func start() async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            listener.newConnectionHandler = { connection in
                Self.echoOnce(on: connection)
            }
            listener.stateUpdateHandler = { [weak listener] state in
                switch state {
                case .ready:
                    guard let port = listener?.port?.rawValue else {
                        continuation.resume(throwing: NetworkChannelError.invalidEndpoint)
                        return
                    }
                    continuation.resume(returning: port)
                case let .failed(error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
    }

    func cancel() {
        listener.cancel()
    }

    private static func echoOnce(on connection: NWConnection) {
        let queue = DispatchQueue(label: "dev.lunex.tests.network-echo.connection")
        connection.stateUpdateHandler = { state in
            guard state == .ready else { return }
            connection.receive(
                minimumIncompleteLength: 1,
                maximumLength: 1_500
            ) { data, _, _, error in
                guard error == nil, let data else {
                    connection.cancel()
                    return
                }
                connection.send(content: data, completion: .contentProcessed { _ in
                    connection.cancel()
                })
            }
        }
        connection.start(queue: queue)
    }
}

private actor InMemoryNetworkDriver: NetworkConnectionDriving {
    private let blockStartUntilCancelled: Bool
    private let blockReceiveUntilCancelled: Bool
    private var receiveChunks: [NetworkReceiveChunk]
    private(set) var sentPayloads: [Data] = []
    private(set) var receiveCallCount = 0
    private(set) var isCancelled = false

    init(
        receiveChunks: [NetworkReceiveChunk] = [],
        blockStartUntilCancelled: Bool = false,
        blockReceiveUntilCancelled: Bool = false
    ) {
        self.receiveChunks = receiveChunks
        self.blockStartUntilCancelled = blockStartUntilCancelled
        self.blockReceiveUntilCancelled = blockReceiveUntilCancelled
    }

    func start() async throws {
        if blockStartUntilCancelled {
            while !Task.isCancelled && !isCancelled {
                try await Task.sleep(for: .milliseconds(1))
            }
            throw CancellationError()
        }
    }

    func send(_ data: Data) async throws {
        sentPayloads.append(data)
    }

    func receive(
        minimumLength: Int,
        maximumLength: Int
    ) async throws -> NetworkReceiveChunk {
        _ = minimumLength
        _ = maximumLength
        receiveCallCount += 1
        if blockReceiveUntilCancelled {
            while !Task.isCancelled && !isCancelled {
                try await Task.sleep(for: .milliseconds(1))
            }
            throw CancellationError()
        }
        guard !receiveChunks.isEmpty else {
            return NetworkReceiveChunk(data: Data(), isComplete: true)
        }
        return receiveChunks.removeFirst()
    }

    func cancel() async {
        isCancelled = true
    }
}
