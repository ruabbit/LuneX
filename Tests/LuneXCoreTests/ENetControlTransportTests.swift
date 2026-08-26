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
}
