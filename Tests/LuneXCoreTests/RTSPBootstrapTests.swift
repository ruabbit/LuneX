import Foundation
import XCTest

final class RTSPBootstrapTests: XCTestCase {
    func testSessionEndpointParsesPlaintextAndEncryptedURLs() throws {
        let plaintext = try RTSPSessionEndpoint.parse("rtsp://moon.local/session")
        let encrypted = try RTSPSessionEndpoint.parse("rtspenc://192.0.2.10:49000/session")

        XCTAssertEqual(plaintext.networkEndpoint.host, "moon.local")
        XCTAssertEqual(plaintext.networkEndpoint.port, 48_010)
        XCTAssertFalse(plaintext.encrypted)
        XCTAssertEqual(encrypted.networkEndpoint.port, 49_000)
        XCTAssertTrue(encrypted.encrypted)
        XCTAssertThrowsError(try RTSPSessionEndpoint.parse("https://moon.local/session"))
        XCTAssertThrowsError(try RTSPSessionEndpoint.parse("rtsp://moon.local:0/session"))
    }

    func testEncryptedFrameRoundTripsAndReportsCompleteLength() throws {
        let plaintext = Data("OPTIONS rtsp://moon.local/session RTSP/1.0\r\n\r\n".utf8)
        let key = Data((0..<16).map(UInt8.init))
        let frame = try EncryptedRTSPFrameCodec.seal(
            plaintext,
            sequence: 0x0102_0304,
            key: key,
            origin: .client
        )

        XCTAssertNil(try EncryptedRTSPFrameCodec.framedLength(in: frame.prefix(10)))
        XCTAssertEqual(try EncryptedRTSPFrameCodec.framedLength(in: frame), frame.count)
        let opened = try EncryptedRTSPFrameCodec.open(frame, key: key, origin: .client)
        XCTAssertEqual(opened.plaintext, plaintext)
        XCTAssertEqual(opened.sequence, 0x0102_0304)
        XCTAssertThrowsError(try EncryptedRTSPFrameCodec.open(frame, key: key, origin: .host))
    }

    func testEncryptedFrameRejectsTypeLengthAndTagMutation() throws {
        let key = Data(repeating: 0xA5, count: 16)
        let frame = try EncryptedRTSPFrameCodec.seal(
            Data([1, 2, 3, 4]),
            sequence: 7,
            key: key,
            origin: .host
        )

        var wrongType = frame
        wrongType[wrongType.startIndex] &= 0x7F
        XCTAssertThrowsError(try EncryptedRTSPFrameCodec.open(wrongType, key: key, origin: .host))

        var wrongLength = frame
        wrongLength[wrongLength.startIndex + 3] &+= 1
        XCTAssertThrowsError(try EncryptedRTSPFrameCodec.open(wrongLength, key: key, origin: .host))

        var wrongTag = frame
        wrongTag[wrongTag.startIndex + 8] ^= 0x80
        XCTAssertThrowsError(try EncryptedRTSPFrameCodec.open(wrongTag, key: key, origin: .host))
        XCTAssertThrowsError(try EncryptedRTSPFrameCodec.seal(
            Data(),
            sequence: 1,
            key: Data(repeating: 0, count: 15),
            origin: .client
        ))
    }

    func testBootstrapSetsUpAndPublishesControlReadinessWithoutClaimingAllChannels() async throws {
        let launchResponse = StreamLaunchResponse(
            sessionURL: "rtsp://moon.local/session",
            gameSessionID: "session-1",
            rawValues: [:]
        )
        let launchClient = BootstrapStubLaunchClient(response: launchResponse)
        let connection = BootstrapStubRTSPConnection(responses: [
            response(cSeq: "1"),
            response(cSeq: "2", body: Data("v=0\r\na=x-ss-general.featureFlags:0\r\n".utf8)),
            setupResponse(cSeq: "3", session: "session-token", port: 48_000),
            setupResponse(cSeq: "4", session: "session-token", port: 47_998),
            setupResponse(
                cSeq: "5",
                session: "session-token",
                port: 47_999,
                connectData: 0x1234_5678
            )
        ])
        let control = BootstrapStubControlChannel(events: [
            .terminated(HostTerminationReason(code: 0x8003_0023, kind: .graceful))
        ])
        let provider = MoonlightSessionControlProvider(
            launchClient: launchClient,
            connection: connection,
            controlChannel: control
        )

        let events = try await collect(await provider.start(
            sessionID: UUID(),
            request: makeRequest()
        ))

        XCTAssertEqual(events, [
            .launchAccepted(launchResponse),
            .rtspReady,
            .channelsReady(.control),
            .terminated(reason: "The host ended the streaming session.")
        ])
        let requests = await connection.recordedRequests()
        XCTAssertEqual(requests.map(\.method), ["OPTIONS", "DESCRIBE", "SETUP", "SETUP", "SETUP"])
        XCTAssertEqual(requests.map(\.target), [
            "rtsp://moon.local/session",
            "rtsp://moon.local/session",
            "streamid=audio/0/0",
            "streamid=video/0/0",
            "streamid=control/13/0"
        ])
        XCTAssertEqual(requests.map { $0.headerValues(named: "CSeq") }, [
            ["1"], ["2"], ["3"], ["4"], ["5"]
        ])
        XCTAssertTrue(requests.allSatisfy {
            $0.headerValues(named: "X-GS-ClientVersion") == ["14"]
        })
        XCTAssertTrue(requests.allSatisfy {
            $0.headerValues(named: "Host") == ["moon.local"]
        })
        let endpoint = await connection.recordedEndpoint()
        XCTAssertEqual(endpoint?.networkEndpoint.host, "moon.local")
        XCTAssertEqual(endpoint?.encrypted, false)
        XCTAssertEqual(requests[2].headerValues(named: "Session"), [])
        XCTAssertEqual(requests[3].headerValues(named: "Session"), ["session-token"])
        XCTAssertEqual(requests[4].headerValues(named: "Session"), ["session-token"])
        XCTAssertTrue(requests[2...4].allSatisfy {
            $0.headerValues(named: "Transport") == ["unicast;X-GS-ClientPort=50000-50001"]
        })
        let controlConnect = await control.recordedConnect()
        XCTAssertEqual(controlConnect?.endpoint, RuntimeNetworkEndpoint(
            host: "moon.local",
            port: 47_999,
            transport: .udp
        ))
        XCTAssertEqual(controlConnect?.connectData, 0x1234_5678)
        XCTAssertEqual(controlConnect?.encryptionKey, Data((0..<16).map(UInt8.init)))
        let controlStops = await control.stopCount()
        let rtspCancellations = await connection.cancelCount()
        let remoteCancellations = await launchClient.stopCount()
        XCTAssertEqual(controlStops, 1)
        XCTAssertEqual(rtspCancellations, 1)
        XCTAssertEqual(remoteCancellations, 0)
        XCTAssertFalse(events.contains { event in
            if case .channelsReady(.all) = event { return true }
            if case .negotiated = event { return true }
            return false
        })
    }

    func testBootstrapFailsClosedOnConflictingSetupSession() async {
        let launchResponse = StreamLaunchResponse(
            sessionURL: "rtsp://moon.local/session",
            gameSessionID: "session-1",
            rawValues: [:]
        )
        let connection = BootstrapStubRTSPConnection(responses: [
            response(cSeq: "1"),
            response(cSeq: "2", body: Data("v=0\r\n".utf8)),
            setupResponse(cSeq: "3", session: "audio-session", port: 48_000),
            setupResponse(cSeq: "4", session: "different-session", port: 47_998)
        ])
        let control = BootstrapStubControlChannel(events: [])
        let provider = MoonlightSessionControlProvider(
            launchClient: BootstrapStubLaunchClient(response: launchResponse),
            connection: connection,
            controlChannel: control
        )

        let result = await collectFailure(await provider.start(
            sessionID: UUID(),
            request: makeRequest()
        ))

        XCTAssertEqual(result.events, [.launchAccepted(launchResponse), .rtspReady])
        XCTAssertEqual(result.error as? SunshineRTSPNegotiationError, .conflictingSession)
        let controlConnect = await control.recordedConnect()
        XCTAssertNil(controlConnect)
    }

    func testBootstrapFailsClosedWhenControlConnectDataIsMissing() async {
        let launchResponse = StreamLaunchResponse(
            sessionURL: "rtsp://moon.local/session",
            gameSessionID: "session-1",
            rawValues: [:]
        )
        let connection = BootstrapStubRTSPConnection(responses: [
            response(cSeq: "1"),
            response(cSeq: "2", body: Data("v=0\r\n".utf8)),
            setupResponse(cSeq: "3", session: "session-token", port: 48_000),
            setupResponse(cSeq: "4", session: "session-token", port: 47_998),
            setupResponse(cSeq: "5", session: "session-token", port: 47_999)
        ])
        let control = BootstrapStubControlChannel(events: [])
        let provider = MoonlightSessionControlProvider(
            launchClient: BootstrapStubLaunchClient(response: launchResponse),
            connection: connection,
            controlChannel: control
        )

        let result = await collectFailure(await provider.start(
            sessionID: UUID(),
            request: makeRequest()
        ))

        XCTAssertEqual(result.events, [.launchAccepted(launchResponse), .rtspReady])
        XCTAssertEqual(result.error as? SunshineRTSPNegotiationError, .missingControlConnectData)
        let controlConnect = await control.recordedConnect()
        XCTAssertNil(controlConnect)
    }

    func testBootstrapFailsClosedOnMissingSessionURLAfterLaunchAccepted() async {
        let launchResponse = StreamLaunchResponse(
            sessionURL: nil,
            gameSessionID: "session-1",
            rawValues: [:]
        )
        let connection = BootstrapStubRTSPConnection(responses: [])
        let provider = MoonlightSessionControlProvider(
            launchClient: BootstrapStubLaunchClient(response: launchResponse),
            connection: connection
        )

        let result = await collectFailure(await provider.start(
            sessionID: UUID(),
            request: makeRequest()
        ))

        XCTAssertEqual(result.events, [.launchAccepted(launchResponse)])
        XCTAssertEqual(result.error as? RTSPBootstrapError, .invalidSessionURL)
        let recordedEndpoint = await connection.recordedEndpoint()
        XCTAssertNil(recordedEndpoint)
    }

    func testBootstrapFailsClosedOnCSeqMismatch() async {
        let launchResponse = StreamLaunchResponse(
            sessionURL: "rtsp://moon.local/session",
            gameSessionID: "session-1",
            rawValues: [:]
        )
        let connection = BootstrapStubRTSPConnection(responses: [response(cSeq: "99")])
        let provider = MoonlightSessionControlProvider(
            launchClient: BootstrapStubLaunchClient(response: launchResponse),
            connection: connection
        )

        let result = await collectFailure(await provider.start(
            sessionID: UUID(),
            request: makeRequest()
        ))

        XCTAssertEqual(result.events, [.launchAccepted(launchResponse)])
        XCTAssertEqual(result.error as? RTSPBootstrapError, .cSeqMismatch)
        let cancellations = await connection.cancelCount()
        XCTAssertEqual(cancellations, 1)
    }

    func testBootstrapFailsClosedOnNonSuccessRTSPResponse() async {
        let launchResponse = StreamLaunchResponse(
            sessionURL: "rtsp://moon.local/session",
            gameSessionID: "session-1",
            rawValues: [:]
        )
        let connection = BootstrapStubRTSPConnection(responses: [
            RTSPResponse(
                statusCode: 503,
                reasonPhrase: "Unavailable",
                headers: [RTSPHeader(name: "CSeq", value: "1")]
            )
        ])
        let provider = MoonlightSessionControlProvider(
            launchClient: BootstrapStubLaunchClient(response: launchResponse),
            connection: connection
        )

        let result = await collectFailure(await provider.start(
            sessionID: UUID(),
            request: makeRequest()
        ))

        XCTAssertEqual(result.events, [.launchAccepted(launchResponse)])
        XCTAssertEqual(result.error as? RTSPBootstrapError, .unexpectedResponse)
    }

    func testCoordinatorRejectsPartialReadiness() async throws {
        let coordinator = StreamSessionCoordinator(
            launchClient: BootstrapStubLaunchClient(response: StreamLaunchResponse(
                sessionURL: "rtsp://moon.local/session",
                gameSessionID: "session-1",
                rawValues: [:]
            ))
        )
        _ = try await coordinator.launch(makeRequest())

        do {
            _ = try await coordinator.markTransportStarted(readiness: [.control, .video])
            XCTFail("Partial transport readiness must not enter streaming.")
        } catch let failure as StreamNegotiationFailure {
            XCTAssertEqual(failure.code, .invalidTransition)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        let snapshot = await coordinator.snapshot
        XCTAssertEqual(snapshot.stage, .readyForTransport)
    }

    private func makeRequest() -> StreamLaunchRequest {
        StreamLaunchRequest(
            host: MoonlightHost(
                id: UUID(uuidString: "AFDB6122-1C83-46C6-B0F4-607EE5135726")!,
                name: "Test Host",
                address: "moon.local",
                pairingState: .paired,
                reachability: .online,
                pinnedIdentity: PinnedHostIdentity(
                    certificateSHA256: "test-pin",
                    serverCertificateDER: Data([1, 2, 3]),
                    pairedAt: Date(timeIntervalSince1970: 1)
                )
            ),
            app: RemoteApp(id: "1", name: "Desktop", supportsHDR: false, installPath: nil),
            preferences: .defaults,
            clientUniqueID: "test-client",
            remoteInputKey: RemoteInputKeyMaterial(
                keyID: 1,
                key: Data((0..<16).map(UInt8.init))
            ),
            audioPlaybackMode: .clientOnly,
            controllerBitmap: 0,
            optimizeGameSettings: false
        )
    }

    private func response(cSeq: String, body: Data = Data()) -> RTSPResponse {
        RTSPResponse(
            statusCode: 200,
            reasonPhrase: "OK",
            headers: [RTSPHeader(name: "CSeq", value: cSeq)],
            body: body
        )
    }

    private func setupResponse(
        cSeq: String,
        session: String,
        port: UInt16,
        connectData: UInt32? = nil
    ) -> RTSPResponse {
        var headers = [
            RTSPHeader(name: "CSeq", value: cSeq),
            RTSPHeader(name: "Session", value: session),
            RTSPHeader(name: "Transport", value: "server_port=\(port)")
        ]
        if let connectData {
            headers.append(RTSPHeader(name: "X-SS-Connect-Data", value: String(connectData)))
        }
        return RTSPResponse(statusCode: 200, reasonPhrase: "OK", headers: headers)
    }

    private func collect(
        _ stream: AsyncThrowingStream<SessionControlEvent, Error>
    ) async throws -> [SessionControlEvent] {
        var events: [SessionControlEvent] = []
        for try await event in stream {
            events.append(event)
        }
        return events
    }

    private func collectFailure(
        _ stream: AsyncThrowingStream<SessionControlEvent, Error>
    ) async -> (events: [SessionControlEvent], error: Error?) {
        var events: [SessionControlEvent] = []
        do {
            for try await event in stream {
                events.append(event)
            }
            return (events, nil)
        } catch {
            return (events, error)
        }
    }
}

private struct BootstrapControlConnect: Equatable, Sendable {
    var endpoint: RuntimeNetworkEndpoint
    var connectData: UInt32
    var encryptionKey: Data
}

private actor BootstrapStubControlChannel: MoonlightControlChannelManaging {
    private var events: [MoonlightControlEvent]
    private var connectCall: BootstrapControlConnect?
    private var stops = 0

    init(events: [MoonlightControlEvent]) {
        self.events = events
    }

    func connect(
        endpoint: RuntimeNetworkEndpoint,
        connectData: UInt32,
        encryptionKey: Data
    ) async throws {
        connectCall = BootstrapControlConnect(
            endpoint: endpoint,
            connectData: connectData,
            encryptionKey: encryptionKey
        )
    }

    func nextEvent() async throws -> MoonlightControlEvent {
        guard !events.isEmpty else { throw ControlChannelError.disconnected(data: 0) }
        return events.removeFirst()
    }

    func requestIDR() async throws {}

    func stop() async {
        stops += 1
    }

    func recordedConnect() -> BootstrapControlConnect? {
        connectCall
    }

    func stopCount() -> Int {
        stops
    }
}

private actor BootstrapStubLaunchClient: StreamLaunchClient {
    private let response: StreamLaunchResponse
    private var stops = 0

    init(response: StreamLaunchResponse) {
        self.response = response
    }

    func launch(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        response
    }

    func resume(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        response
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {
        stops += 1
    }

    func stopCount() -> Int {
        stops
    }
}

private actor BootstrapStubRTSPConnection: RTSPConnectionExecuting {
    private var responses: [RTSPResponse]
    private var requests: [RTSPRequest] = []
    private var endpoint: RTSPSessionEndpoint?
    private var cancellations = 0

    init(responses: [RTSPResponse]) {
        self.responses = responses
    }

    func connect(endpoint: RTSPSessionEndpoint, encryptionKey: Data) async throws {
        self.endpoint = endpoint
    }

    func transact(_ request: RTSPRequest) async throws -> RTSPResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw RTSPBootstrapError.connectionClosed }
        return responses.removeFirst()
    }

    func cancel() async {
        cancellations += 1
    }

    func recordedRequests() -> [RTSPRequest] {
        requests
    }

    func recordedEndpoint() -> RTSPSessionEndpoint? {
        endpoint
    }

    func cancelCount() -> Int {
        cancellations
    }
}
