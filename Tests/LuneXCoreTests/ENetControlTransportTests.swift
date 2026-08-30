import Foundation
import XCTest

final class ENetControlTransportTests: XCTestCase {
    func testProductionBridgeCompletesRetransmittedLoopbackHandshakeAndEcho() async throws {
        let channelCount: UInt8 = 0x30
        let connectData: UInt32 = 0x1234_5678
        let server = try XCTUnwrap(lunex_enet_test_server_create(channelCount, true))
        defer { lunex_enet_test_server_destroy(server) }
        let port = lunex_enet_test_server_port(server)
        XCTAssertGreaterThan(port, 0)

        let driver = ENetConnectionDriver()
        try await driver.connect(
            host: "127.0.0.1",
            port: port,
            channelCount: channelCount,
            connectData: connectData,
            timeoutMilliseconds: 3_000
        )
        XCTAssertTrue(lunex_enet_test_server_wait_for_connect(
            server,
            connectData,
            channelCount,
            500
        ))

        let payload = Data("production-enet-echo".utf8)
        try await driver.send(payload, channelID: channelCount - 1, reliable: true)
        let serverReceived = payload.withUnsafeBytes { buffer in
            lunex_enet_test_server_wait_for_receive(
                server,
                channelCount - 1,
                buffer.bindMemory(to: UInt8.self).baseAddress,
                payload.count,
                500
            )
        }
        XCTAssertTrue(serverReceived)

        var receivedEcho: Data?
        for _ in 0..<20 where receivedEcho == nil {
            let event = try await driver.service(timeoutMilliseconds: 100)
            if case let .received(channelID, bytes) = event {
                XCTAssertEqual(channelID, channelCount - 1)
                receivedEcho = bytes
            }
        }
        XCTAssertEqual(receivedEcho, payload)
        await driver.disconnect()
        XCTAssertTrue(lunex_enet_test_server_wait_for_disconnect(server, 500))
    }

    func testOutboundMailboxPreemptsLongServicePoll() async throws {
        let channelCount: UInt8 = 0x30
        let server = try XCTUnwrap(lunex_enet_test_server_create(channelCount, false))
        defer { lunex_enet_test_server_destroy(server) }
        let driver = ENetConnectionDriver()
        try await driver.connect(
            host: "127.0.0.1",
            port: lunex_enet_test_server_port(server),
            channelCount: channelCount,
            connectData: 1,
            timeoutMilliseconds: 3_000
        )
        XCTAssertTrue(lunex_enet_test_server_wait_for_connect(server, 1, channelCount, 500))

        let service = Task { try await driver.service(timeoutMilliseconds: 100) }
        try await Task.sleep(for: .milliseconds(5))
        let start = DispatchTime.now().uptimeNanoseconds
        try await driver.send(Data([0x42]), channelID: 0, reliable: true)
        let elapsed = DispatchTime.now().uptimeNanoseconds - start
        XCTAssertLessThan(elapsed, 50_000_000)
        _ = try await service.value

        let snapshot = await driver.snapshot()
        XCTAssertEqual(snapshot.enqueuedSendCount, 1)
        XCTAssertEqual(snapshot.sentPacketCount, 1)
        XCTAssertEqual(snapshot.flushCount, 1)
        XCTAssertEqual(snapshot.rejectedSendCount, 0)
        XCTAssertEqual(snapshot.rejectedServiceCount, 0)
        XCTAssertEqual(snapshot.maximumServiceSliceMilliseconds, 1)
        XCTAssertLessThan(snapshot.maximumSendQueueDelayNanoseconds, 50_000_000)
        await driver.disconnect()
    }

    func testConcurrentOutboundMailboxUsesBatchFlushBoundaries() async throws {
        let channelCount: UInt8 = 0x30
        let server = try XCTUnwrap(lunex_enet_test_server_create(channelCount, false))
        defer { lunex_enet_test_server_destroy(server) }
        let driver = ENetConnectionDriver()
        try await driver.connect(
            host: "127.0.0.1",
            port: lunex_enet_test_server_port(server),
            channelCount: channelCount,
            connectData: 2,
            timeoutMilliseconds: 3_000
        )
        XCTAssertTrue(lunex_enet_test_server_wait_for_connect(server, 2, channelCount, 500))

        let packetCount = 32
        try await withThrowingTaskGroup(of: Void.self) { group in
            for value in 0..<packetCount {
                group.addTask {
                    try await driver.send(
                        Data([UInt8(value)]),
                        channelID: UInt8(value % Int(channelCount)),
                        reliable: true
                    )
                }
            }
            try await group.waitForAll()
        }

        let snapshot = await driver.snapshot()
        XCTAssertEqual(snapshot.enqueuedSendCount, UInt64(packetCount))
        XCTAssertEqual(snapshot.sentPacketCount, UInt64(packetCount))
        XCTAssertGreaterThan(snapshot.flushCount, 0)
        XCTAssertLessThan(snapshot.flushCount, UInt64(packetCount))
        XCTAssertEqual(snapshot.rejectedSendCount, 0)
        XCTAssertEqual(snapshot.pendingSendCount, 0)
        await driver.disconnect()
    }

    func testDisconnectInterruptsPendingServiceAfterBoundedSlice() async throws {
        let channelCount: UInt8 = 0x30
        let server = try XCTUnwrap(lunex_enet_test_server_create(channelCount, false))
        defer { lunex_enet_test_server_destroy(server) }
        let driver = ENetConnectionDriver()
        try await driver.connect(
            host: "127.0.0.1",
            port: lunex_enet_test_server_port(server),
            channelCount: channelCount,
            connectData: 3,
            timeoutMilliseconds: 3_000
        )
        XCTAssertTrue(lunex_enet_test_server_wait_for_connect(server, 3, channelCount, 500))

        let service = Task { try await driver.service(timeoutMilliseconds: 5_000) }
        try await Task.sleep(for: .milliseconds(5))
        await driver.disconnect()
        do {
            _ = try await service.value
            XCTFail("Disconnect must fail the pending service operation.")
        } catch let error as ENetTransportError {
            XCTAssertEqual(error, .disconnected)
        }
        let snapshot = await driver.snapshot()
        XCTAssertEqual(snapshot.pendingServiceCount, 0)
        XCTAssertEqual(snapshot.rejectedServiceCount, 0)
        XCTAssertEqual(snapshot.maximumServiceSliceMilliseconds, 1)
    }
}
