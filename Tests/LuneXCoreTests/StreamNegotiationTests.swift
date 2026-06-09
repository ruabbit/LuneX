import Foundation
import XCTest

final class StreamNegotiationTests: XCTestCase {
    func testNegotiatorBuildsLaunchParameters() throws {
        let request = try makeRequest(
            app: RemoteApp(id: "109", name: "Steam", supportsHDR: true, installPath: nil),
            preferences: StreamPreferences(width: 3840, height: 2160, frameRate: 120, bitrateKbps: 100_000, hdrEnabled: true, scaleMode: .fit)
        )

        let parameters = try StreamNegotiator().makeParameters(from: request)

        XCTAssertEqual(parameters.appID, "109")
        XCTAssertEqual(parameters.mode, "3840x2160x120")
        XCTAssertTrue(parameters.hdrRequested)
        XCTAssertEqual(parameters.remoteInputKeyHex, "0A0B0C")
        XCTAssertEqual(parameters.controllerBitmap, 3)
    }

    func testNegotiatorRejectsUnpairedHost() throws {
        var request = try makeRequest()
        request.host.pairingState = .unpaired

        XCTAssertThrowsError(try StreamNegotiator().makeParameters(from: request)) { error in
            let failure = error as? StreamNegotiationFailure
            XCTAssertEqual(failure?.code, .hostNotPaired)
            XCTAssertEqual(failure?.subsystem, "pairing")
        }
    }

    func testLaunchResponseParserExtractsSessionFields() throws {
        let xml = """
        <root status_code="200" status_message="OK">
          <gamesession>123</gamesession>
          <sessionurl>rtsp://192.168.1.50/session</sessionurl>
        </root>
        """

        let response = try StreamLaunchResponseParser.parse(Data(xml.utf8))

        XCTAssertEqual(response.gameSessionID, "123")
        XCTAssertEqual(response.sessionURL, "rtsp://192.168.1.50/session")
    }

    func testCoordinatorLaunchesAndTransitionsToStreaming() async throws {
        let request = try makeRequest()
        let launchClient = StubStreamLaunchClient()
        let coordinator = StreamSessionCoordinator(launchClient: launchClient)

        let ready = try await coordinator.launch(request)
        let streaming = try await coordinator.markTransportStarted()
        let stopped = try await coordinator.stop(host: request.host, clientUniqueID: request.clientUniqueID)

        XCTAssertEqual(ready.stage, .readyForTransport)
        XCTAssertEqual(streaming.stage, .streaming)
        XCTAssertEqual(stopped.stage, .disconnected)
        XCTAssertEqual(ready.parameters?.appID, request.app.id)
        let launchCount = await launchClient.currentLaunchCount()
        let stopCount = await launchClient.currentStopCount()
        XCTAssertEqual(launchCount, 1)
        XCTAssertEqual(stopCount, 1)
    }

    private func makeRequest(
        app: RemoteApp = RemoteApp(id: "0", name: "Desktop", supportsHDR: false, installPath: nil),
        preferences: StreamPreferences = .defaults
    ) throws -> StreamLaunchRequest {
        StreamLaunchRequest(
            host: MoonlightHost(
                id: UUID(uuidString: "5F758E80-B382-48E2-BE86-A594E01A7419")!,
                name: "Studio PC",
                address: "192.168.1.50",
                pairingState: .paired,
                reachability: .online,
                pinnedIdentity: PinnedHostIdentity(
                    certificateSHA256: "abcdef",
                    serverCertificateDER: Data([1, 2, 3]),
                    pairedAt: Date(timeIntervalSince1970: 20)
                )
            ),
            app: app,
            preferences: preferences,
            clientUniqueID: "client",
            remoteInputKey: RemoteInputKeyMaterial(keyID: 7, key: Data([10, 11, 12])),
            audioPlaybackMode: .clientOnly,
            controllerBitmap: 3,
            optimizeGameSettings: false
        )
    }
}

private actor StubStreamLaunchClient: StreamLaunchClient {
    private(set) var launchCount = 0
    private(set) var stopCount = 0

    func launch(_ request: StreamLaunchRequest, parameters: StreamNegotiationParameters) async throws -> StreamLaunchResponse {
        launchCount += 1
        return StreamLaunchResponse(
            sessionURL: "rtsp://\(request.host.address)/session",
            gameSessionID: "123",
            rawValues: ["gamesession": "123"]
        )
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {
        stopCount += 1
    }

    func currentLaunchCount() -> Int {
        launchCount
    }

    func currentStopCount() -> Int {
        stopCount
    }
}
