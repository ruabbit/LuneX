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

    func testHTTPLaunchAndStopRoutePinnedIdentityToExecutor() async throws {
        let request = try makeRequest()
        let parameters = try StreamNegotiator().makeParameters(from: request)
        let executor = RecordingPinnedStreamRequestExecutor()
        let client = HTTPStreamLaunchClient(requestExecutor: executor)

        let response = try await client.launch(request, parameters: parameters)
        try await client.stop(host: request.host, clientUniqueID: request.clientUniqueID)
        let calls = await executor.recordedCalls()

        XCTAssertEqual(response.gameSessionID, "123")
        XCTAssertEqual(calls.map(\.url.path), ["/launch", "/cancel"])
        XCTAssertEqual(calls.map(\.pin), [request.host.pinnedIdentity, request.host.pinnedIdentity])
        XCTAssertTrue(calls.allSatisfy { $0.url.scheme == "https" })
        XCTAssertTrue(calls.allSatisfy { $0.url.port == HostEndpoint.defaultHTTPSPort })
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

private actor RecordingPinnedStreamRequestExecutor: PinnedHTTPSRequestExecuting {
    struct Call: Sendable {
        var url: URL
        var pin: PinnedHostIdentity?
    }

    private var calls: [Call] = []

    func data(for request: URLRequest, pinnedIdentity: PinnedHostIdentity?) async throws -> (Data, URLResponse) {
        let url = try XCTUnwrap(request.url)
        calls.append(Call(url: url, pin: pinnedIdentity))
        let data: Data
        if url.path == "/launch" {
            data = Data("<root status_code=\"200\"><gamesession>123</gamesession></root>".utf8)
        } else {
            data = Data()
        }
        return (data, URLResponse(url: url, mimeType: "application/xml", expectedContentLength: data.count, textEncodingName: "utf-8"))
    }

    func recordedCalls() -> [Call] {
        calls
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
