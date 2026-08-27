import Foundation
import XCTest

final class RTSPBootstrapTests: XCTestCase {
    func testInitialSessionOperationLaunchesWhenHostIsFree() {
        XCTAssertEqual(
            MoonlightSessionControlProvider.initialSessionOperation(
                serverInfo: SessionServerInfoClient.freeInfo,
                requestedAppID: "881448767"
            ),
            .launch
        )
    }

    func testInitialSessionOperationResumesMatchingBusyApplication() {
        XCTAssertEqual(
            MoonlightSessionControlProvider.initialSessionOperation(
                serverInfo: SessionServerInfoClient.busyInfo(
                    currentGameID: "881448767"
                ),
                requestedAppID: "881448767"
            ),
            .resume
        )
    }

    func testInitialSessionOperationLaunchesDifferentBusyApplication() {
        XCTAssertEqual(
            MoonlightSessionControlProvider.initialSessionOperation(
                serverInfo: SessionServerInfoClient.busyInfo(
                    currentGameID: "different-app"
                ),
                requestedAppID: "881448767"
            ),
            .launch
        )
    }

    func testInitialSessionOperationLaunchesWhenStateIsMissing() {
        XCTAssertEqual(
            MoonlightSessionControlProvider.initialSessionOperation(
                serverInfo: ServerInfo(
                    name: "Test Host",
                    uniqueID: "test-host",
                    macAddress: nil,
                    state: nil,
                    supportsHDR: true,
                    rawValues: [:]
                ),
                requestedAppID: "881448767"
            ),
            .launch
        )
    }

    func testBusyMatchingApplicationRoutesInitialProviderRequestThroughResume() async {
        let launchResponse = StreamLaunchResponse(
            sessionURL: "rtsp://moon.local/session",
            gameSessionID: nil,
            rawValues: ["resume": "1"]
        )
        let launchClient = BootstrapStubLaunchClient(response: launchResponse)
        let provider = MoonlightSessionControlProvider(
            serverInfoClient: SessionServerInfoClient(
                info: SessionServerInfoClient.busyInfo(currentGameID: "1")
            ),
            launchClient: launchClient,
            connection: BootstrapStubRTSPConnection(responses: [])
        )

        let result = await collectFailure(
            await provider.start(sessionID: UUID(), request: makeRequest())
        )
        let counts = await launchClient.counts()

        XCTAssertEqual(result.events, [.launchAccepted(launchResponse)])
        XCTAssertEqual(result.error as? RTSPBootstrapError, .connectionClosed)
        XCTAssertEqual(counts.launches, 0)
        XCTAssertEqual(counts.resumes, 1)
        XCTAssertEqual(counts.stops, 0)
    }

    func testProductionControlProviderAppliesGenerationScopedMobileGate()
        async throws {
        let sessionID = UUID()
        let launchResponse = StreamLaunchResponse(
            sessionURL: "rtsp://moon.local/session",
            gameSessionID: "mobile-control",
            rawValues: [:]
        )
        let control = BootstrapStubControlChannel(events: [])
        let provider = MoonlightSessionControlProvider(
            serverInfoClient: SessionServerInfoClient(),
            launchClient: BootstrapSleepingLaunchClient(
                response: launchResponse
            ),
            connection: BootstrapStubRTSPConnection(responses: []),
            controlChannel: control
        )
        let stream = await provider.start(
            sessionID: sessionID,
            request: makeRequest()
        )
        let firstGeneration = try XCTUnwrap(
            MobilePictureInPictureGeneration(
                mediaGeneration: 1,
                pictureInPictureGeneration: 9
            )
        )
        let paused = SessionMobileControlApplication(
            sessionID: sessionID,
            mediaGeneration: 1,
            generation: firstGeneration,
            revision: try XCTUnwrap(
                MobileMediaGenerationRevision(rawValue: 8)
            ),
            directive: .pauseSession
        )

        try await provider.applyMobileControl(paused)
        try await provider.applyMobileControl(paused)
        do {
            try await provider.requestIDR(sessionID: sessionID)
            XCTFail("Paused mobile control must reject IDR requests.")
        } catch {
            XCTAssertEqual(error as? ControlChannelError, .invalidState)
        }

        let replacementGeneration = try XCTUnwrap(
            MobilePictureInPictureGeneration(
                mediaGeneration: 2,
                pictureInPictureGeneration: 1
            )
        )
        let resumed = SessionMobileControlApplication(
            sessionID: sessionID,
            mediaGeneration: 2,
            generation: replacementGeneration,
            revision: try XCTUnwrap(
                MobileMediaGenerationRevision(rawValue: 1)
            ),
            directive: .continueSession
        )
        try await provider.applyMobileControl(resumed)
        try await provider.requestIDR(sessionID: sessionID)

        let stale = SessionMobileControlApplication(
            sessionID: sessionID,
            mediaGeneration: 1,
            generation: firstGeneration,
            revision: try XCTUnwrap(
                MobileMediaGenerationRevision(rawValue: 99)
            ),
            directive: .continueSession
        )
        do {
            try await provider.applyMobileControl(stale)
            XCTFail("A prior media generation must remain stale.")
        } catch {
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .staleMobileRuntimeApplication
            )
        }

        let current = await provider.currentMobileControlApplication(
            sessionID: sessionID
        )
        let idrCount = await control.requestIDRCount()
        XCTAssertEqual(current, resumed)
        XCTAssertEqual(idrCount, 1)
        await provider.stop(sessionID: sessionID)
        _ = stream
    }

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

    func testNetworkRTSPConnectionUsesFreshChannelForEveryTransaction() async throws {
        let firstChannel = NetworkRTSPChannelStub(chunks: [
            NetworkReceiveChunk(
                data: try serializedResponse(cSeq: "1"),
                isComplete: true
            )
        ])
        let secondChannel = NetworkRTSPChannelStub(chunks: [
            NetworkReceiveChunk(
                data: try serializedResponse(cSeq: "2"),
                isComplete: true
            )
        ])
        let factory = NetworkRTSPChannelFactoryStub(channels: [
            firstChannel,
            secondChannel
        ])
        let connection = NetworkRTSPConnection(channelFactory: { endpoint in
            try factory.makeChannel(endpoint: endpoint)
        })
        let endpoint = try RTSPSessionEndpoint.parse("rtsp://moon.local/session")
        try await connection.connect(endpoint: endpoint, encryptionKey: Data())

        let options = try await connection.transact(networkRequest(
            method: "OPTIONS",
            cSeq: "1"
        ))
        let describe = try await connection.transact(networkRequest(
            method: "DESCRIBE",
            cSeq: "2"
        ))

        XCTAssertEqual(options.headerValues(named: "CSeq"), ["1"])
        XCTAssertEqual(describe.headerValues(named: "CSeq"), ["2"])
        XCTAssertEqual(factory.recordedEndpoints(), [
            endpoint.networkEndpoint,
            endpoint.networkEndpoint
        ])
        let firstSnapshot = await firstChannel.snapshot()
        let secondSnapshot = await secondChannel.snapshot()
        XCTAssertEqual(firstSnapshot.connects, 1)
        XCTAssertEqual(firstSnapshot.cancellations, 1)
        XCTAssertEqual(secondSnapshot.connects, 1)
        XCTAssertEqual(secondSnapshot.cancellations, 1)
        XCTAssertEqual(
            try RTSPMessageCodec.decodeExact(firstSnapshot.sent[0]),
            .request(networkRequest(method: "OPTIONS", cSeq: "1"))
        )
        XCTAssertEqual(
            try RTSPMessageCodec.decodeExact(secondSnapshot.sent[0]),
            .request(networkRequest(method: "DESCRIBE", cSeq: "2"))
        )
    }

    func testPlaintextDescribeWithoutContentLengthUsesTerminalBody() async throws {
        let body = Data("v=0\r\na=x-ss-general.featureFlags:5\r\n".utf8)
        let wire = Data("RTSP/1.0 200 OK\r\nCSeq: 2\r\n\r\n".utf8) + body
        let channel = NetworkRTSPChannelStub(chunks: [
            NetworkReceiveChunk(data: wire, isComplete: true)
        ])
        let connection = NetworkRTSPConnection(channelFactory: { _ in channel })
        try await connection.connect(
            endpoint: try RTSPSessionEndpoint.parse("rtsp://moon.local/session"),
            encryptionKey: Data()
        )

        let response = try await connection.transact(
            networkRequest(method: "DESCRIBE", cSeq: "2")
        )

        XCTAssertEqual(response.headerValues(named: "CSeq"), ["2"])
        XCTAssertEqual(response.body, body)
    }

    func testPlaintextOptionsWithoutBodyCompletesWhenPeerCloses() async throws {
        let wire = Data("RTSP/1.0 200 OK\r\nCSeq: 1\r\n\r\n".utf8)
        let channel = NetworkRTSPChannelStub(chunks: [
            NetworkReceiveChunk(data: wire, isComplete: false)
        ])
        let connection = NetworkRTSPConnection(channelFactory: { _ in channel })
        try await connection.connect(
            endpoint: try RTSPSessionEndpoint.parse("rtsp://moon.local/session"),
            encryptionKey: Data()
        )

        let response = try await connection.transact(
            networkRequest(method: "OPTIONS", cSeq: "1")
        )

        XCTAssertEqual(response.body, Data())
        let snapshot = await channel.snapshot()
        XCTAssertEqual(snapshot.receiveCalls, 2)
    }

    func testFragmentedCloseDelimitedBodyWaitsForPeerClose() async throws {
        let header = Data("RTSP/1.0 200 OK\r\nCSeq: 2\r\n\r\n".utf8)
        let firstBody = Data("v=0\r\n".utf8)
        let secondBody = Data("a=x-ss-general.featureFlags:5\r\n".utf8)
        let channel = NetworkRTSPChannelStub(chunks: [
            NetworkReceiveChunk(data: header, isComplete: false),
            NetworkReceiveChunk(data: firstBody, isComplete: false),
            NetworkReceiveChunk(data: secondBody, isComplete: false)
        ])
        let connection = NetworkRTSPConnection(channelFactory: { _ in channel })
        try await connection.connect(
            endpoint: try RTSPSessionEndpoint.parse("rtsp://moon.local/session"),
            encryptionKey: Data()
        )

        let response = try await connection.transact(
            networkRequest(method: "DESCRIBE", cSeq: "2")
        )

        XCTAssertEqual(response.body, firstBody + secondBody)
        let snapshot = await channel.snapshot()
        XCTAssertEqual(snapshot.receiveCalls, 4)
    }

    func testCloseDelimitedResponseRejectsEmptyAndIncompleteMessages() async throws {
        let emptyChannel = NetworkRTSPChannelStub(chunks: [])
        let incompleteChannel = NetworkRTSPChannelStub(chunks: [
            NetworkReceiveChunk(
                data: Data("RTSP/1.0 200 OK\r\nCSeq: 2\r\n".utf8),
                isComplete: false
            )
        ])
        let factory = NetworkRTSPChannelFactoryStub(channels: [
            emptyChannel,
            incompleteChannel
        ])
        let connection = NetworkRTSPConnection(channelFactory: { endpoint in
            try factory.makeChannel(endpoint: endpoint)
        })
        try await connection.connect(
            endpoint: try RTSPSessionEndpoint.parse("rtsp://moon.local/session"),
            encryptionKey: Data()
        )

        do {
            _ = try await connection.transact(
                networkRequest(method: "OPTIONS", cSeq: "1")
            )
            XCTFail("Expected empty response to fail closed")
        } catch let error as RTSPBootstrapError {
            XCTAssertEqual(error, .connectionClosed)
        }
        do {
            _ = try await connection.transact(
                networkRequest(method: "DESCRIBE", cSeq: "2")
            )
            XCTFail("Expected incomplete response to fail closed")
        } catch let error as RTSPMessageError {
            XCTAssertEqual(error, .incomplete)
        }
    }

    func testExplicitContentLengthIsExactAndRejectsTrailingOrMismatch() async throws {
        let valid = Data(
            "RTSP/1.0 200 OK\r\nCSeq: 1\r\nContent-Length: 3\r\n\r\nabc".utf8
        )
        let trailing = valid + Data("x".utf8)
        let mismatch = Data(
            "RTSP/1.0 200 OK\r\nCSeq: 3\r\nContent-Length: 4\r\n\r\nabc".utf8
        )
        let factory = NetworkRTSPChannelFactoryStub(channels: [
            NetworkRTSPChannelStub(chunks: [
                NetworkReceiveChunk(data: valid, isComplete: false)
            ]),
            NetworkRTSPChannelStub(chunks: [
                NetworkReceiveChunk(data: trailing, isComplete: true)
            ]),
            NetworkRTSPChannelStub(chunks: [
                NetworkReceiveChunk(data: mismatch, isComplete: false)
            ])
        ])
        let connection = NetworkRTSPConnection(channelFactory: { endpoint in
            try factory.makeChannel(endpoint: endpoint)
        })
        try await connection.connect(
            endpoint: try RTSPSessionEndpoint.parse("rtsp://moon.local/session"),
            encryptionKey: Data()
        )

        let response = try await connection.transact(
            networkRequest(method: "OPTIONS", cSeq: "1")
        )
        XCTAssertEqual(response.body, Data("abc".utf8))
        do {
            _ = try await connection.transact(
                networkRequest(method: "DESCRIBE", cSeq: "2")
            )
            XCTFail("Expected trailing bytes to be rejected")
        } catch let error as RTSPMessageError {
            XCTAssertEqual(error, .trailingBytes)
        }
        do {
            _ = try await connection.transact(
                networkRequest(method: "SETUP", cSeq: "3")
            )
            XCTFail("Expected mismatched content length to be rejected")
        } catch let error as RTSPMessageError {
            XCTAssertEqual(error, .incomplete)
        }
    }

    func testCancellationWinsWhileTerminalResponseIsFinishing() async throws {
        let channel = NetworkRTSPChannelStub(
            chunks: [
                NetworkReceiveChunk(
                    data: try serializedResponse(cSeq: "1"),
                    isComplete: true
                )
            ],
            blocksFirstCancellation: true
        )
        let connection = NetworkRTSPConnection(channelFactory: { _ in channel })
        try await connection.connect(
            endpoint: try RTSPSessionEndpoint.parse("rtsp://moon.local/session"),
            encryptionKey: Data()
        )
        let request = networkRequest(method: "OPTIONS", cSeq: "1")
        let transaction = Task { try await connection.transact(request) }
        try await channel.waitUntilCancellationStarts()

        await connection.cancel()

        do {
            _ = try await transaction.value
            XCTFail("A response must not escape after session cancellation")
        } catch let error as NetworkChannelError {
            XCTAssertEqual(error, .cancelled)
        }
        let snapshot = await channel.snapshot()
        XCTAssertEqual(snapshot.cancellations, 2)
    }

    func testEncryptedRTSPSequenceContinuesAcrossFreshChannels() async throws {
        let key = Data((0..<16).map(UInt8.init))
        let firstResponse = try EncryptedRTSPFrameCodec.seal(
            serializedResponse(cSeq: "1"),
            sequence: 100,
            key: key,
            origin: .host
        )
        let secondResponse = try EncryptedRTSPFrameCodec.seal(
            serializedResponse(cSeq: "2"),
            sequence: 101,
            key: key,
            origin: .host
        )
        let firstChannel = NetworkRTSPChannelStub(chunks: [
            NetworkReceiveChunk(data: firstResponse, isComplete: true)
        ])
        let secondChannel = NetworkRTSPChannelStub(chunks: [
            NetworkReceiveChunk(data: secondResponse, isComplete: true)
        ])
        let factory = NetworkRTSPChannelFactoryStub(channels: [
            firstChannel,
            secondChannel
        ])
        let connection = NetworkRTSPConnection(channelFactory: { endpoint in
            try factory.makeChannel(endpoint: endpoint)
        })
        try await connection.connect(
            endpoint: try RTSPSessionEndpoint.parse("rtspenc://moon.local/session"),
            encryptionKey: key
        )

        _ = try await connection.transact(networkRequest(method: "OPTIONS", cSeq: "1"))
        _ = try await connection.transact(networkRequest(method: "DESCRIBE", cSeq: "2"))

        let firstSnapshot = await firstChannel.snapshot()
        let secondSnapshot = await secondChannel.snapshot()
        let firstSent = try XCTUnwrap(firstSnapshot.sent.first)
        let secondSent = try XCTUnwrap(secondSnapshot.sent.first)
        let firstOpened = try EncryptedRTSPFrameCodec.open(
            firstSent,
            key: key,
            origin: .client
        )
        let secondOpened = try EncryptedRTSPFrameCodec.open(
            secondSent,
            key: key,
            origin: .client
        )
        XCTAssertEqual(firstOpened.sequence, 1)
        XCTAssertEqual(secondOpened.sequence, 2)
        XCTAssertEqual(
            try RTSPMessageCodec.decodeExact(firstOpened.plaintext),
            .request(networkRequest(method: "OPTIONS", cSeq: "1"))
        )
        XCTAssertEqual(
            try RTSPMessageCodec.decodeExact(secondOpened.plaintext),
            .request(networkRequest(method: "DESCRIBE", cSeq: "2"))
        )
        XCTAssertThrowsError(try EncryptedRTSPFrameCodec.open(
            secondSent,
            key: key,
            origin: .host
        ))
    }

    func testCancellingNetworkRTSPConnectionCancelsCurrentTransaction() async throws {
        let channel = NetworkRTSPChannelStub(chunks: [], blocksReceive: true)
        let factory = NetworkRTSPChannelFactoryStub(channels: [channel])
        let connection = NetworkRTSPConnection(channelFactory: { endpoint in
            try factory.makeChannel(endpoint: endpoint)
        })
        try await connection.connect(
            endpoint: try RTSPSessionEndpoint.parse("rtsp://moon.local/session"),
            encryptionKey: Data()
        )
        let request = networkRequest(method: "OPTIONS", cSeq: "1")
        let transaction = Task {
            try await connection.transact(request)
        }
        try await channel.waitUntilReceiveStarts()

        await connection.cancel()

        do {
            _ = try await transaction.value
            XCTFail("Expected the active RTSP transaction to be cancelled.")
        } catch {
            XCTAssertTrue(
                error is CancellationError
                    || error as? NetworkChannelError == .cancelled
            )
        }
        let snapshot = await channel.snapshot()
        XCTAssertEqual(snapshot.cancellations, 1)
        do {
            _ = try await connection.transact(networkRequest(method: "DESCRIBE", cSeq: "2"))
            XCTFail("A cancelled RTSP session must reject later transactions.")
        } catch let error as NetworkChannelError {
            XCTAssertEqual(error, .invalidState)
        }
        XCTAssertEqual(factory.recordedEndpoints().count, 1)
    }

    func testBootstrapPublishesNegotiatedMediaBeforeControlOnlyReadiness() async throws {
        let sessionID = UUID()
        let launchResponse = StreamLaunchResponse(
            sessionURL: "rtsp://moon.local/session",
            gameSessionID: "session-1",
            rawValues: [:]
        )
        let launchClient = BootstrapStubLaunchClient(response: launchResponse)
        let ordering = BootstrapOrderingRecorder()
        let audioChannel = BootstrapOrderingDatagramChannel(recorder: ordering)
        let audioReservations = MoonlightAudioDatagramReservationStore(
            channelFactory: { _, _ in audioChannel },
            timing: MoonlightMediaReceiveTiming(
                connectTimeout: .seconds(1),
                sendTimeout: .seconds(1),
                pingInterval: .milliseconds(10)
            )
        )
        let connection = BootstrapStubRTSPConnection(responses: [
            response(cSeq: "1"),
            response(
                cSeq: "2",
                body: Data(
                    "v=0\r\na=x-ss-general.featureFlags:0\r\na=x-ss-general.encryptionSupported:1\r\nsprop-parameter-sets=AAAAAU\r\n"
                        .utf8
                )
            ),
            setupResponse(
                cSeq: "3",
                session: "session-token",
                port: 48_000,
                pingPayload: "audio-ping-00000"
            ),
            setupResponse(
                cSeq: "4",
                session: "session-token",
                port: 47_998,
                pingPayload: "video-ping-00000"
            ),
            setupResponse(
                cSeq: "5",
                session: "session-token",
                port: 47_999,
                connectData: 0x1234_5678
            ),
            response(cSeq: "6"),
            response(cSeq: "7")
        ], requestObserver: { request in
            ordering.record("rtsp:\(request.method):\(request.target)")
        })
        let hdrMode = SunshineHDRModeMetadata(
            isEnabled: true,
            masteringDisplay: VideoMasteringDisplayMetadata(
                displayPrimaries: [
                    VideoChromaticityPoint(x: 34_000, y: 16_000),
                    VideoChromaticityPoint(x: 13_250, y: 34_500),
                    VideoChromaticityPoint(x: 7_500, y: 3_000)
                ],
                whitePoint: VideoChromaticityPoint(x: 15_635, y: 16_450),
                maximumDisplayLuminanceNits: 1_000,
                minimumDisplayLuminanceTenThousandths: 5
            ),
            contentLight: VideoContentLightMetadata(
                maximumContentLightLevelNits: 1_200,
                maximumFrameAverageLightLevelNits: 400
            ),
            maximumFullFrameLuminanceNits: 500
        )
        let expectedColorMetadata = try hdrMode.colorMetadata()
        let control = BootstrapStubControlChannel(events: [
            .hdrMode(hdrMode),
            .terminated(HostTerminationReason(code: 0x8003_0023, kind: .graceful))
        ])
        let provider = MoonlightSessionControlProvider(
            serverInfoClient: SessionServerInfoClient(),
            launchClient: launchClient,
            connection: connection,
            controlChannel: control,
            videoCodecSelectionPolicy: VideoCodecSelectionPolicy(
                capabilityProvider: BootstrapVideoDecoderCapabilities([.hevc])
            ),
            audioDatagramReservations: audioReservations
        )

        let events = try await collect(await provider.start(
            sessionID: sessionID,
            request: makeRequest(supportsHDR: true)
        ))

        let configuration = try XCTUnwrap(events.compactMap { event in
            if case let .negotiated(configuration) = event {
                return configuration
            }
            return nil
        }.first)
        XCTAssertEqual(events, [
            .launchAccepted(launchResponse),
            .rtspReady,
            .negotiated(configuration),
            .channelsReady(.control),
            .videoColorMetadata(expectedColorMetadata),
            .terminated(reason: "The host ended the streaming session.")
        ])
        let preservedColorMetadata = await provider.videoColorMetadata(sessionID: sessionID)
        XCTAssertEqual(preservedColorMetadata, expectedColorMetadata)
        let requests = await connection.recordedRequests()
        XCTAssertEqual(
            requests.map(\.method),
            ["OPTIONS", "DESCRIBE", "SETUP", "SETUP", "SETUP", "ANNOUNCE", "PLAY"]
        )
        XCTAssertEqual(requests.map(\.target), [
            "rtsp://moon.local/session",
            "rtsp://moon.local/session",
            "streamid=audio/0/0",
            "streamid=video/0/0",
            "streamid=control/13/0",
            "streamid=control/13/0",
            "/"
        ])
        XCTAssertEqual(requests.map { $0.headerValues(named: "CSeq") }, [
            ["1"], ["2"], ["3"], ["4"], ["5"], ["6"], ["7"]
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
        XCTAssertEqual(requests[5].headerValues(named: "Session"), ["session-token"])
        XCTAssertEqual(requests[5].headerValues(named: "Content-Type"), ["application/sdp"])
        XCTAssertEqual(
            requests[5].headerValues(named: "Content-Length"),
            [String(requests[5].body.count)]
        )
        XCTAssertEqual(requests[6].headerValues(named: "Session"), ["session-token"])
        let announce = try XCTUnwrap(String(data: requests[5].body, encoding: .utf8))
        XCTAssertTrue(announce.contains("a=x-ml-general.featureFlags:2\r\n"))
        XCTAssertTrue(announce.contains("a=x-ss-general.encryptionEnabled:1\r\n"))
        XCTAssertTrue(announce.contains("a=x-nv-general.useReliableUdp:13\r\n"))
        XCTAssertTrue(announce.contains("a=x-nv-video[0].clientViewportWd:2560\r\n"))
        XCTAssertTrue(announce.contains("a=x-nv-video[0].clientViewportHt:1440\r\n"))
        XCTAssertTrue(announce.contains("a=x-nv-video[0].maxFPS:120\r\n"))
        XCTAssertTrue(announce.contains("a=x-nv-vqos[0].bitStreamFormat:1\r\n"))
        XCTAssertTrue(announce.contains("a=x-nv-video[0].dynamicRangeMode:1\r\n"))
        XCTAssertTrue(announce.hasSuffix("m=video 47998\r\n"))
        let controlConnect = await control.recordedConnect()
        XCTAssertEqual(controlConnect?.endpoint, RuntimeNetworkEndpoint(
            host: "moon.local",
            port: 47_999,
            transport: .udp
        ))
        XCTAssertEqual(controlConnect?.connectData, 0x1234_5678)
        XCTAssertEqual(controlConnect?.encryptionKey, Data((0..<16).map(UInt8.init)))
        XCTAssertEqual(configuration.sessionID, sessionID)
        XCTAssertEqual(configuration.requiredChannels, .all)
        XCTAssertEqual(configuration.controlEndpoint, controlConnect?.endpoint)
        XCTAssertEqual(configuration.inputEndpoint, controlConnect?.endpoint)
        XCTAssertEqual(configuration.videoEndpoint.port, 47_998)
        XCTAssertEqual(configuration.audioEndpoint.port, 48_000)
        XCTAssertEqual(configuration.video.codec, .hevc)
        XCTAssertEqual(configuration.video.width, StreamPreferences.defaults.width)
        XCTAssertEqual(configuration.video.height, StreamPreferences.defaults.height)
        XCTAssertEqual(configuration.video.frameRate, StreamPreferences.defaults.frameRate)
        XCTAssertEqual(configuration.video.colorMetadata, .hdr10VideoRange())
        XCTAssertEqual(
            configuration.video.pingPayload,
            Data("video-ping-00000".utf8)
        )
        XCTAssertEqual(configuration.audio.channelLayout, .stereo)
        XCTAssertEqual(configuration.audio.samplesPerFrame, 240)
        XCTAssertEqual(
            configuration.audio.pingPayload,
            Data("audio-ping-00000".utf8)
        )
        XCTAssertEqual(configuration.input.keyMaterial, makeRequest().remoteInputKey)
        let orderedSteps = ordering.snapshot()
        let firstAudioPing = try XCTUnwrap(
            orderedSteps.firstIndex(of: "audio-send")
        )
        let videoSetup = try XCTUnwrap(
            orderedSteps.firstIndex(of: "rtsp:SETUP:streamid=video/0/0")
        )
        let secondAudioPing = try XCTUnwrap(
            orderedSteps.lastIndex(of: "audio-send")
        )
        let play = try XCTUnwrap(
            orderedSteps.firstIndex(of: "rtsp:PLAY:/")
        )
        XCTAssertLessThan(firstAudioPing, videoSetup)
        XCTAssertLessThan(secondAudioPing, play)
        let audioConnectionCount = await audioChannel.connectionCount()
        let audioSendCount = await audioChannel.sendCount()
        let audioCancelCount = await audioChannel.cancelCount()
        XCTAssertEqual(audioConnectionCount, 1)
        XCTAssertEqual(audioSendCount, 2)
        XCTAssertEqual(audioCancelCount, 1)
        let controlStops = await control.stopCount()
        let rtspCancellations = await connection.cancelCount()
        let remoteCancellations = await launchClient.stopCount()
        XCTAssertEqual(controlStops, 1)
        XCTAssertEqual(rtspCancellations, 1)
        XCTAssertEqual(remoteCancellations, 0)
        XCTAssertFalse(events.contains { event in
            if case .channelsReady(.all) = event { return true }
            return false
        })
    }

    func testBootstrapCompletesWhenOnlyAudioEncryptionIsRequested() async throws {
        let sessionID = UUID()
        let launchResponse = StreamLaunchResponse(
            sessionURL: "rtsp://moon.local/session",
            gameSessionID: "session-1",
            rawValues: [:]
        )
        let connection = BootstrapStubRTSPConnection(responses: [
            response(cSeq: "1"),
            response(
                cSeq: "2",
                body: Data(
                    "v=0\r\na=x-ss-general.featureFlags:0\r\na=x-ss-general.encryptionSupported:5\r\na=x-ss-general.encryptionRequested:5\r\nsprop-parameter-sets=AAAAAU\r\n"
                        .utf8
                )
            ),
            setupResponse(
                cSeq: "3",
                session: "session-token",
                port: 48_000,
                pingPayload: "audio-ping-00000"
            ),
            setupResponse(
                cSeq: "4",
                session: "session-token",
                port: 47_998,
                pingPayload: "video-ping-00000"
            ),
            setupResponse(
                cSeq: "5",
                session: "session-token",
                port: 47_999,
                connectData: 0x1234_5678
            ),
            response(cSeq: "6"),
            response(cSeq: "7")
        ])
        let control = BootstrapStubControlChannel(events: [
            .terminated(HostTerminationReason(code: 0x8003_0023, kind: .graceful))
        ])
        let provider = MoonlightSessionControlProvider(
            serverInfoClient: SessionServerInfoClient(),
            launchClient: BootstrapStubLaunchClient(response: launchResponse),
            connection: connection,
            controlChannel: control
        )

        let events = try await collect(await provider.start(
            sessionID: sessionID,
            request: makeRequest()
        ))
        let configuration = try XCTUnwrap(events.compactMap { event in
            if case let .negotiated(value) = event { return value }
            return nil
        }.first)

        XCTAssertTrue(configuration.audio.isEncrypted)
        XCTAssertEqual(configuration.audio.encryptionKey, makeRequest().remoteInputKey.key)
        XCTAssertEqual(configuration.audio.encryptionKeyID, makeRequest().remoteInputKey.keyID)
        let requests = await connection.recordedRequests()
        let announce = try XCTUnwrap(String(data: requests[5].body, encoding: .utf8))
        XCTAssertTrue(announce.contains("a=x-ss-general.encryptionEnabled:5\r\n"))
        XCTAssertEqual(requests.map(\.method), [
            "OPTIONS", "DESCRIBE", "SETUP", "SETUP", "SETUP", "ANNOUNCE", "PLAY"
        ])
    }

    func testBootstrapFailsClosedWhenMediaEncryptionIsRequested() async {
        let launchResponse = StreamLaunchResponse(
            sessionURL: "rtsp://moon.local/session",
            gameSessionID: "session-1",
            rawValues: [:]
        )
        let connection = BootstrapStubRTSPConnection(responses: [
            response(cSeq: "1"),
            response(
                cSeq: "2",
                body: Data(
                    "a=x-ss-general.encryptionSupported:7\r\na=x-ss-general.encryptionRequested:3\r\n"
                        .utf8
                )
            )
        ])
        let provider = MoonlightSessionControlProvider(
            serverInfoClient: SessionServerInfoClient(),
            launchClient: BootstrapStubLaunchClient(response: launchResponse),
            connection: connection,
            controlChannel: BootstrapStubControlChannel(events: [])
        )

        let result = await collectFailure(await provider.start(
            sessionID: UUID(),
            request: makeRequest()
        ))

        XCTAssertEqual(result.events, [.launchAccepted(launchResponse)])
        XCTAssertEqual(
            result.error as? SunshineRTSPNegotiationError,
            .unsupportedMediaEncryption(2)
        )
    }

    func testBootstrapFailsBeforeSetupWithoutControlV2EncryptionSupport() async {
        let launchResponse = StreamLaunchResponse(
            sessionURL: "rtsp://moon.local/session",
            gameSessionID: "session-1",
            rawValues: [:]
        )
        let connection = BootstrapStubRTSPConnection(responses: [
            response(cSeq: "1"),
            response(cSeq: "2", body: Data("v=0\r\n".utf8))
        ])
        let control = BootstrapStubControlChannel(events: [])
        let provider = MoonlightSessionControlProvider(
            serverInfoClient: SessionServerInfoClient(),
            launchClient: BootstrapStubLaunchClient(response: launchResponse),
            connection: connection,
            controlChannel: control
        )

        let result = await collectFailure(await provider.start(
            sessionID: UUID(),
            request: makeRequest()
        ))

        XCTAssertEqual(result.events, [.launchAccepted(launchResponse)])
        XCTAssertEqual(
            result.error as? SunshineRTSPAnnounceError,
            .unsupportedControlEncryption
        )
        let requests = await connection.recordedRequests()
        XCTAssertEqual(requests.map(\.method), ["OPTIONS", "DESCRIBE"])
        let controlConnect = await control.recordedConnect()
        XCTAssertNil(controlConnect)
    }

    func testBootstrapDoesNotConnectControlWhenAnnounceOrPlayFails() async {
        for failingCSeq in ["6", "7"] {
            let launchResponse = StreamLaunchResponse(
                sessionURL: "rtsp://moon.local/session",
                gameSessionID: "session-1",
                rawValues: [:]
            )
            var responses = [
                response(cSeq: "1"),
                response(
                    cSeq: "2",
                    body: Data(
                        "v=0\r\na=x-ss-general.encryptionSupported:1\r\n".utf8
                    )
                ),
                setupResponse(cSeq: "3", session: "session-token", port: 48_000),
                setupResponse(cSeq: "4", session: "session-token", port: 47_998),
                setupResponse(
                    cSeq: "5",
                    session: "session-token",
                    port: 47_999,
                    connectData: 0x1234_5678
                )
            ]
            responses.append(failingCSeq == "6"
                ? RTSPResponse(
                    statusCode: 500,
                    reasonPhrase: "Rejected",
                    headers: [RTSPHeader(name: "CSeq", value: "6")]
                )
                : response(cSeq: "6"))
            if failingCSeq == "7" {
                responses.append(RTSPResponse(
                    statusCode: 500,
                    reasonPhrase: "Rejected",
                    headers: [RTSPHeader(name: "CSeq", value: "7")]
                ))
            }
            let connection = BootstrapStubRTSPConnection(responses: responses)
            let control = BootstrapStubControlChannel(events: [])
            let audioChannel = BootstrapOrderingDatagramChannel(
                recorder: BootstrapOrderingRecorder()
            )
            let audioReservations = MoonlightAudioDatagramReservationStore(
                channelFactory: { _, _ in audioChannel },
                timing: MoonlightMediaReceiveTiming(
                    connectTimeout: .seconds(1),
                    sendTimeout: .seconds(1),
                    pingInterval: .milliseconds(10)
                )
            )
            let provider = MoonlightSessionControlProvider(
                serverInfoClient: SessionServerInfoClient(),
                launchClient: BootstrapStubLaunchClient(response: launchResponse),
                connection: connection,
                controlChannel: control,
                audioDatagramReservations: audioReservations
            )
            let sessionID = UUID()

            let result = await collectFailure(await provider.start(
                sessionID: sessionID,
                request: makeRequest()
            ))

            XCTAssertEqual(
                result.events,
                [.launchAccepted(launchResponse), .rtspReady],
                "failing CSeq \(failingCSeq)"
            )
            XCTAssertEqual(
                result.error as? RTSPBootstrapError,
                .unexpectedResponse,
                "failing CSeq \(failingCSeq)"
            )
            let requests = await connection.recordedRequests()
            XCTAssertEqual(
                requests.map(\.method),
                failingCSeq == "6"
                    ? ["OPTIONS", "DESCRIBE", "SETUP", "SETUP", "SETUP", "ANNOUNCE"]
                    : ["OPTIONS", "DESCRIBE", "SETUP", "SETUP", "SETUP", "ANNOUNCE", "PLAY"]
            )
            let controlConnect = await control.recordedConnect()
            XCTAssertNil(controlConnect)
            let audioCancelCount = await audioChannel.cancelCount()
            XCTAssertEqual(audioCancelCount, 1)
        }
    }

    func testBootstrapPersistsDeterministicAV1FallbackSelection() async throws {
        let sessionID = UUID(uuidString: "0AD74D34-BDBC-4557-9183-40EAC7B68D38")!
        let launchResponse = StreamLaunchResponse(
            sessionURL: "rtsp://moon.local/session",
            gameSessionID: "session-1",
            rawValues: [:]
        )
        let describeResponse = response(
            cSeq: "2",
            body: Data(
                "v=0\r\na=x-ss-general.encryptionSupported:1\r\nsprop-parameter-sets=AAAAAU\r\na=rtpmap:98 AV1/90000\r\n"
                    .utf8
            )
        )
        let parsedDescription = try SunshineSessionDescriptionParser.parse(describeResponse)
        XCTAssertEqual(parsedDescription.availableVideoCodecs, [.h264, .hevc, .av1])
        let connection = BootstrapStubRTSPConnection(responses: [
            response(cSeq: "1"),
            describeResponse,
            setupResponse(cSeq: "3", session: "session-token", port: 48_000),
            setupResponse(cSeq: "4", session: "session-token", port: 47_998),
            setupResponse(
                cSeq: "5",
                session: "session-token",
                port: 47_999,
                connectData: 0x1234_5678
            ),
            response(cSeq: "6"),
            response(cSeq: "7")
        ])
        let provider = MoonlightSessionControlProvider(
            serverInfoClient: SessionServerInfoClient(),
            launchClient: BootstrapStubLaunchClient(response: launchResponse),
            connection: connection,
            controlChannel: BootstrapStubControlChannel(events: [
                .terminated(HostTerminationReason(code: 0x8003_0023, kind: .graceful))
            ]),
            videoCodecSelectionPolicy: VideoCodecSelectionPolicy(
                capabilityProvider: BootstrapVideoDecoderCapabilities([.h264, .hevc])
            )
        )

        _ = try await collect(await provider.start(
            sessionID: sessionID,
            request: makeRequest()
        ))
        let selection = await provider.videoCodecSelection(sessionID: sessionID)
        let colorMetadata = await provider.videoColorMetadata(sessionID: sessionID)

        XCTAssertEqual(selection?.codec, .hevc)
        XCTAssertEqual(colorMetadata, .rec709VideoRange())
        XCTAssertEqual(
            selection?.disposition,
            .fallback(from: .av1, reason: .unsupportedByDevice(.av1))
        )
    }

    func testBootstrapRejectsHDRWhenOnlyH264HardwareDecodeIsAvailable() async throws {
        let launchResponse = StreamLaunchResponse(
            sessionURL: "rtsp://moon.local/session",
            gameSessionID: "session-1",
            rawValues: [:]
        )
        let describeResponse = response(
            cSeq: "2",
            body: Data(
                "v=0\r\na=x-ss-general.encryptionSupported:1\r\nsprop-parameter-sets=AAAAAU\r\na=rtpmap:98 AV1/90000\r\n"
                    .utf8
            )
        )
        let parsedDescription = try SunshineSessionDescriptionParser.parse(describeResponse)
        XCTAssertEqual(parsedDescription.availableVideoCodecs, [.h264, .hevc, .av1])
        let connection = BootstrapStubRTSPConnection(responses: [
            response(cSeq: "1"),
            describeResponse
        ])
        let control = BootstrapStubControlChannel(events: [])
        let provider = MoonlightSessionControlProvider(
            serverInfoClient: SessionServerInfoClient(),
            launchClient: BootstrapStubLaunchClient(response: launchResponse),
            connection: connection,
            controlChannel: control,
            videoCodecSelectionPolicy: VideoCodecSelectionPolicy(
                capabilityProvider: BootstrapVideoDecoderCapabilities([.h264])
            )
        )

        let result = await collectFailure(await provider.start(
            sessionID: UUID(),
            request: makeRequest(supportsHDR: true)
        ))

        XCTAssertEqual(result.events, [.launchAccepted(launchResponse)])
        XCTAssertEqual(
            result.error as? VideoCodecSelectionError,
            .noCompatibleHardwareDecoder(
                hostCodecs: [.h264, .hevc, .av1],
                bitDepth: 10,
                isHDR: true
            )
        )
        let requests = await connection.recordedRequests()
        XCTAssertEqual(requests.map(\.method), ["OPTIONS", "DESCRIBE"])
        let controlConnect = await control.recordedConnect()
        XCTAssertNil(controlConnect)
    }

    func testBootstrapFailsClosedOnConflictingSetupSession() async {
        let launchResponse = StreamLaunchResponse(
            sessionURL: "rtsp://moon.local/session",
            gameSessionID: "session-1",
            rawValues: [:]
        )
        let connection = BootstrapStubRTSPConnection(responses: [
            response(cSeq: "1"),
            response(
                cSeq: "2",
                body: Data("v=0\r\na=x-ss-general.encryptionSupported:1\r\n".utf8)
            ),
            setupResponse(cSeq: "3", session: "audio-session", port: 48_000),
            setupResponse(cSeq: "4", session: "different-session", port: 47_998)
        ])
        let control = BootstrapStubControlChannel(events: [])
        let provider = MoonlightSessionControlProvider(
            serverInfoClient: SessionServerInfoClient(),
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
            response(
                cSeq: "2",
                body: Data("v=0\r\na=x-ss-general.encryptionSupported:1\r\n".utf8)
            ),
            setupResponse(cSeq: "3", session: "session-token", port: 48_000),
            setupResponse(cSeq: "4", session: "session-token", port: 47_998),
            setupResponse(cSeq: "5", session: "session-token", port: 47_999)
        ])
        let control = BootstrapStubControlChannel(events: [])
        let provider = MoonlightSessionControlProvider(
            serverInfoClient: SessionServerInfoClient(),
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
            serverInfoClient: SessionServerInfoClient(),
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

    func testAnnounceConfigurationSerializesCodecHDRAndBoundedBitrate() throws {
        let h264 = try SunshineRTSPAnnounceConfiguration(
            width: 1_920,
            height: 1_080,
            frameRate: 60,
            bitrateKbps: 20_000,
            codec: .h264,
            isHDR: false,
            videoPort: 47_998
        ).serialize()
        let h264Text = try XCTUnwrap(String(data: h264, encoding: .utf8))
        XCTAssertTrue(h264Text.contains("a=x-nv-vqos[0].bitStreamFormat:0\r\n"))
        XCTAssertTrue(h264Text.contains("a=x-nv-video[0].dynamicRangeMode:0\r\n"))
        XCTAssertTrue(h264Text.contains("a=x-nv-vqos[0].bw.maximumBitrateKbps:16000\r\n"))

        let av1 = try SunshineRTSPAnnounceConfiguration(
            width: 3_840,
            height: 2_160,
            frameRate: 120,
            bitrateKbps: 200_000,
            codec: .av1,
            isHDR: true,
            videoPort: 50_000
        ).serialize()
        let av1Text = try XCTUnwrap(String(data: av1, encoding: .utf8))
        XCTAssertTrue(av1Text.contains("a=x-nv-vqos[0].bitStreamFormat:2\r\n"))
        XCTAssertTrue(av1Text.contains("a=x-nv-video[0].dynamicRangeMode:1\r\n"))
        XCTAssertTrue(av1Text.contains("a=x-nv-vqos[0].bw.maximumBitrateKbps:100000\r\n"))
        XCTAssertThrowsError(try SunshineRTSPAnnounceConfiguration(
            width: 1_920,
            height: 1_080,
            frameRate: 60,
            bitrateKbps: 20_000,
            codec: .h264,
            isHDR: true,
            videoPort: 47_998
        ).serialize()) {
            XCTAssertEqual(
                $0 as? SunshineRTSPAnnounceError,
                .invalidConfiguration
            )
        }
    }

    func testBootstrapFailsClosedOnCSeqMismatch() async {
        let launchResponse = StreamLaunchResponse(
            sessionURL: "rtsp://moon.local/session",
            gameSessionID: "session-1",
            rawValues: [:]
        )
        let connection = BootstrapStubRTSPConnection(responses: [response(cSeq: "99")])
        let provider = MoonlightSessionControlProvider(
            serverInfoClient: SessionServerInfoClient(),
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
            serverInfoClient: SessionServerInfoClient(),
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

    private func makeRequest(supportsHDR: Bool = false) -> StreamLaunchRequest {
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
            app: RemoteApp(id: "1", name: "Desktop", supportsHDR: supportsHDR, installPath: nil),
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

    private func serializedResponse(cSeq: String) throws -> Data {
        try RTSPMessageCodec.serialize(.response(response(cSeq: cSeq)))
    }

    private func networkRequest(method: String, cSeq: String) -> RTSPRequest {
        RTSPRequest(
            method: method,
            target: "rtsp://moon.local/session",
            headers: [RTSPHeader(name: "CSeq", value: cSeq)]
        )
    }

    private func setupResponse(
        cSeq: String,
        session: String,
        port: UInt16,
        pingPayload: String? = nil,
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
        if let pingPayload {
            headers.append(
                RTSPHeader(name: "X-SS-Ping-Payload", value: pingPayload)
            )
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

private struct NetworkRTSPChannelSnapshot: Sendable {
    var connects: Int
    var sent: [Data]
    var receiveCalls: Int
    var cancellations: Int
}

private actor NetworkRTSPChannelStub: RTSPByteChannel {
    private var chunks: [NetworkReceiveChunk]
    private let blocksReceive: Bool
    private let blocksFirstCancellation: Bool
    private var connects = 0
    private var sent: [Data] = []
    private var receiveCalls = 0
    private var cancellations = 0
    private var isCancelled = false

    init(
        chunks: [NetworkReceiveChunk],
        blocksReceive: Bool = false,
        blocksFirstCancellation: Bool = false
    ) {
        self.chunks = chunks
        self.blocksReceive = blocksReceive
        self.blocksFirstCancellation = blocksFirstCancellation
    }

    func connect(timeout: Duration) async throws {
        _ = timeout
        connects += 1
    }

    func send(_ data: Data, timeout: Duration) async throws {
        _ = timeout
        guard !isCancelled else { throw NetworkChannelError.cancelled }
        sent.append(data)
    }

    func receive(
        minimumLength: Int,
        maximumLength: Int?,
        timeout: Duration
    ) async throws -> NetworkReceiveChunk {
        _ = minimumLength
        _ = maximumLength
        _ = timeout
        receiveCalls += 1
        if blocksReceive {
            while !isCancelled {
                try await Task.sleep(for: .milliseconds(1))
            }
            throw NetworkChannelError.cancelled
        }
        guard !chunks.isEmpty else { throw NetworkChannelError.closed }
        return chunks.removeFirst()
    }

    func cancel() async {
        cancellations += 1
        isCancelled = true
        if blocksFirstCancellation && cancellations == 1 {
            while cancellations < 2 {
                await Task.yield()
            }
        }
    }

    func waitUntilReceiveStarts() async throws {
        for _ in 0..<1_000 {
            if receiveCalls > 0 { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw NetworkChannelError.timedOut(operation: "test receive admission")
    }

    func waitUntilCancellationStarts() async throws {
        for _ in 0..<1_000 {
            if cancellations > 0 { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw NetworkChannelError.timedOut(operation: "test cancellation admission")
    }

    func snapshot() -> NetworkRTSPChannelSnapshot {
        NetworkRTSPChannelSnapshot(
            connects: connects,
            sent: sent,
            receiveCalls: receiveCalls,
            cancellations: cancellations
        )
    }
}

private final class NetworkRTSPChannelFactoryStub: @unchecked Sendable {
    private let lock = NSLock()
    private var channels: [NetworkRTSPChannelStub]
    private var endpoints: [RuntimeNetworkEndpoint] = []

    init(channels: [NetworkRTSPChannelStub]) {
        self.channels = channels
    }

    func makeChannel(endpoint: RuntimeNetworkEndpoint) throws -> any RTSPByteChannel {
        lock.lock()
        defer { lock.unlock() }
        guard !channels.isEmpty else { throw NetworkChannelError.invalidState }
        endpoints.append(endpoint)
        return channels.removeFirst()
    }

    func recordedEndpoints() -> [RuntimeNetworkEndpoint] {
        lock.lock()
        defer { lock.unlock() }
        return endpoints
    }
}

struct SessionServerInfoClient: ServerInfoClient {
    static let freeInfo = ServerInfo(
        name: "Test Host",
        uniqueID: "test-host",
        macAddress: nil,
        state: "SUNSHINE_SERVER_FREE",
        supportsHDR: true,
        rawValues: [
            "state": "SUNSHINE_SERVER_FREE",
            "currentgame": "0"
        ]
    )

    let info: ServerInfo

    init(info: ServerInfo = Self.freeInfo) {
        self.info = info
    }

    static func busyInfo(currentGameID: String) -> ServerInfo {
        ServerInfo(
            name: "Test Host",
            uniqueID: "test-host",
            macAddress: nil,
            state: "SUNSHINE_SERVER_BUSY",
            supportsHDR: true,
            rawValues: [
                "state": "SUNSHINE_SERVER_BUSY",
                "currentgame": currentGameID
            ]
        )
    }

    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        _ = endpoint
        return info
    }
}

private struct BootstrapVideoDecoderCapabilities: VideoDecoderCapabilityProviding {
    var supportedCodecs: Set<NegotiatedVideoCodec>

    init(_ supportedCodecs: Set<NegotiatedVideoCodec>) {
        self.supportedCodecs = supportedCodecs
    }

    func supportsHardwareDecode(_ codec: NegotiatedVideoCodec) -> Bool {
        supportedCodecs.contains(codec)
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
    private var idrRequests = 0

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

    func requestIDR() async throws {
        idrRequests += 1
    }

    func stop() async {
        stops += 1
    }

    func recordedConnect() -> BootstrapControlConnect? {
        connectCall
    }

    func stopCount() -> Int {
        stops
    }

    func requestIDRCount() -> Int {
        idrRequests
    }
}

private struct BootstrapSleepingLaunchClient: StreamLaunchClient {
    let response: StreamLaunchResponse

    func launch(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        _ = request
        _ = parameters
        try await Task.sleep(for: .seconds(30))
        return response
    }

    func resume(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        try await launch(request, parameters: parameters)
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {
        _ = host
        _ = clientUniqueID
    }
}

private actor BootstrapStubLaunchClient: StreamLaunchClient {
    private let response: StreamLaunchResponse
    private var launches = 0
    private var resumes = 0
    private var stops = 0

    init(response: StreamLaunchResponse) {
        self.response = response
    }

    func launch(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        launches += 1
        return response
    }

    func resume(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        resumes += 1
        return response
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {
        stops += 1
    }

    func stopCount() -> Int {
        stops
    }

    func counts() -> (launches: Int, resumes: Int, stops: Int) {
        (launches, resumes, stops)
    }
}

private actor BootstrapStubRTSPConnection: RTSPConnectionExecuting {
    private var responses: [RTSPResponse]
    private var requests: [RTSPRequest] = []
    private var endpoint: RTSPSessionEndpoint?
    private var cancellations = 0
    private let requestObserver: @Sendable (RTSPRequest) -> Void

    init(
        responses: [RTSPResponse],
        requestObserver: @escaping @Sendable (RTSPRequest) -> Void = { _ in }
    ) {
        self.responses = responses
        self.requestObserver = requestObserver
    }

    func connect(endpoint: RTSPSessionEndpoint, encryptionKey: Data) async throws {
        self.endpoint = endpoint
    }

    func transact(_ request: RTSPRequest) async throws -> RTSPResponse {
        requests.append(request)
        requestObserver(request)
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

private final class BootstrapOrderingRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var steps: [String] = []

    func record(_ step: String) {
        lock.withLock { steps.append(step) }
    }

    func snapshot() -> [String] {
        lock.withLock { steps }
    }
}

private actor BootstrapOrderingDatagramChannel: MoonlightDatagramChannel {
    private let recorder: BootstrapOrderingRecorder
    private var connections = 0
    private var sends = 0
    private var cancellations = 0

    init(recorder: BootstrapOrderingRecorder) {
        self.recorder = recorder
    }

    func connect(timeout: Duration) async throws {
        _ = timeout
        connections += 1
        recorder.record("audio-connect")
    }

    func send(_ data: Data, timeout: Duration) async throws {
        _ = data
        _ = timeout
        sends += 1
        recorder.record("audio-send")
    }

    func receiveWithoutDeadline(
        minimumLength: Int,
        maximumLength: Int?
    ) async throws -> NetworkReceiveChunk {
        _ = minimumLength
        _ = maximumLength
        throw NetworkChannelError.closed
    }

    func cancel() async {
        cancellations += 1
        recorder.record("audio-cancel")
    }

    func connectionCount() -> Int { connections }
    func sendCount() -> Int { sends }
    func cancelCount() -> Int { cancellations }
}
