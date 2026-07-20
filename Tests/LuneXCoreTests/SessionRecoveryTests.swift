import Foundation
import XCTest

final class SessionRecoveryTests: XCTestCase {
    func testHealthAggregatorReportsUnavailableDegradedAndReady() {
        var aggregator = SessionChannelHealthAggregator(requiredChannels: .all)

        XCTAssertEqual(aggregator.snapshot.status, .unavailable)
        XCTAssertFalse(aggregator.snapshot.canStream)

        let degraded = aggregator.markHealthy(.control)
        XCTAssertEqual(degraded.status, .degraded)
        XCTAssertFalse(degraded.canStream)

        let ready = aggregator.markHealthy([.video, .audio, .input])
        XCTAssertEqual(ready.status, .ready)
        XCTAssertTrue(ready.canStream)

        let lost = aggregator.markUnhealthy(.video)
        XCTAssertEqual(lost.status, .degraded)
        XCTAssertFalse(lost.canStream)

        let unavailable = aggregator.replaceHealthyChannels([])
        XCTAssertEqual(unavailable.status, .unavailable)
        XCTAssertFalse(unavailable.canStream)
    }

    func testCoordinatorCannotRemainStreamingAfterRequiredChannelLoss() async throws {
        let coordinator = StreamSessionCoordinator(
            launchClient: RecoveryLaunchClient(
                launchResponse: launchResponse(),
                resumeResults: []
            )
        )
        _ = try await coordinator.launch(makeRequest())

        let streaming = try await coordinator.updateChannelHealth(.all)
        XCTAssertEqual(streaming.stage, .streaming)
        XCTAssertTrue(streaming.channelHealth.canStream)

        let degraded = try await coordinator.updateChannelHealth([.control, .video, .audio])
        XCTAssertEqual(degraded.stage, .reconnecting)
        XCTAssertEqual(degraded.channelHealth.status, .degraded)
        XCTAssertFalse(degraded.channelHealth.canStream)

        let recovered = try await coordinator.updateChannelHealth(.all)
        XCTAssertEqual(recovered.stage, .streaming)
        XCTAssertTrue(recovered.channelHealth.canStream)
    }

    func testHTTPResumeUsesResumeRouteFreshKeyAndAcceptedSessionURL() async throws {
        let executor = RecoveryHTTPExecutor(response: Data("""
        <root status_code="200"><resume>1</resume><sessionUrl0>rtspenc://example.invalid:48010</sessionUrl0></root>
        """.utf8))
        let client = HTTPStreamLaunchClient(requestExecutor: executor)
        var request = makeRequest()
        request.remoteInputKey = RemoteInputKeyMaterial(
            keyID: 0x0102_0304,
            key: Data(repeating: 0xA5, count: 16)
        )
        let parameters = try StreamNegotiator().makeParameters(from: request)

        let response = try await client.resume(request, parameters: parameters)
        let calls = await executor.recordedCalls()
        let call = try XCTUnwrap(calls.first)
        let components = try XCTUnwrap(URLComponents(url: call.url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        XCTAssertEqual(call.url.path, "/resume")
        XCTAssertEqual(query["rikey"], String(repeating: "A5", count: 16))
        XCTAssertEqual(query["rikeyid"], "16909060")
        XCTAssertEqual(response.sessionURL, "rtspenc://example.invalid:48010")
        XCTAssertEqual(response.rawValues["resume"], "1")
    }

    func testHTTPResumeRejectsMissingAcceptedMarker() async throws {
        let executor = RecoveryHTTPExecutor(response: Data("""
        <root status_code="200"><sessionUrl0>rtsp://example.invalid:48010</sessionUrl0></root>
        """.utf8))
        let client = HTTPStreamLaunchClient(requestExecutor: executor)
        let request = makeRequest()
        let parameters = try StreamNegotiator().makeParameters(from: request)

        do {
            _ = try await client.resume(request, parameters: parameters)
            XCTFail("A resume response without resume=1 must fail closed.")
        } catch let failure as StreamNegotiationFailure {
            XCTAssertEqual(failure.code, .resumeRejected)
            XCTAssertEqual(failure.subsystem, "resume")
        }
    }

    func testTransientControlLossResumesWithFreshKeyWithoutDuplicateLaunch() async throws {
        let initialRequest = makeRequest()
        let freshKey = RemoteInputKeyMaterial(
            keyID: 2,
            key: Data(repeating: 0x22, count: 16)
        )
        let launchClient = RecoveryLaunchClient(
            launchResponse: launchResponse(path: "initial"),
            resumeResults: [.success(launchResponse(path: "resumed", resumed: true))]
        )
        let connection = RecoveryRTSPConnection(
            responses: setupSequence(session: "initial-session")
                + setupSequence(session: "resumed-session")
        )
        let control = RecoveryControlChannel(results: [
            .failure(ControlChannelError.disconnected(data: 7)),
            .success(.terminated(HostTerminationReason(code: 0x8003_0023, kind: .graceful)))
        ])
        let sleeper = RecoverySleeper()
        let provider = MoonlightSessionControlProvider(
            launchClient: launchClient,
            connection: connection,
            controlChannel: control,
            reconnectPolicy: SessionReconnectPolicy(maximumAttempts: 3, delays: [.milliseconds(100), .milliseconds(250), .milliseconds(500)]),
            reconnectSleeper: sleeper,
            keyMaterialGenerator: ScriptedKeyGenerator(materials: [freshKey])
        )

        let events = try await collect(await provider.start(
            sessionID: UUID(),
            request: initialRequest
        ))

        XCTAssertEqual(events, [
            .launchAccepted(launchResponse(path: "initial")),
            .rtspReady,
            .channelsReady(.control),
            .channelsReady([]),
            .reconnecting(attempt: 1, reason: "control_unavailable"),
            .rtspReady,
            .channelsReady(.control),
            .terminated(reason: "The host ended the streaming session.")
        ])
        let calls = await launchClient.recordedCalls()
        XCTAssertEqual(calls.launchRequests.count, 1)
        XCTAssertEqual(calls.resumeRequests.count, 1)
        XCTAssertEqual(calls.launchRequests.first?.remoteInputKey, initialRequest.remoteInputKey)
        XCTAssertEqual(calls.resumeRequests.first?.remoteInputKey, freshKey)
        let connectKeys = await connection.recordedKeys()
        XCTAssertEqual(connectKeys, [initialRequest.remoteInputKey.key, freshKey.key])
        let delays = await sleeper.recordedDelays()
        XCTAssertEqual(delays, [.milliseconds(100)])
        XCTAssertFalse(events.contains(.channelsReady(.all)))
    }

    func testReconnectRetriesAreBoundedAndEventuallySucceed() async throws {
        let keys = (2...3).map {
            RemoteInputKeyMaterial(keyID: $0, key: Data(repeating: UInt8($0), count: 16))
        }
        let launchClient = RecoveryLaunchClient(
            launchResponse: launchResponse(path: "initial"),
            resumeResults: [
                .failure(URLError(.timedOut)),
                .success(launchResponse(path: "recovered", resumed: true))
            ]
        )
        let provider = MoonlightSessionControlProvider(
            launchClient: launchClient,
            connection: RecoveryRTSPConnection(
                responses: setupSequence(session: "initial") + setupSequence(session: "recovered")
            ),
            controlChannel: RecoveryControlChannel(results: [
                .failure(ControlChannelError.disconnected(data: 0)),
                .success(.terminated(HostTerminationReason(code: 0x8003_0023, kind: .graceful)))
            ]),
            reconnectPolicy: SessionReconnectPolicy(maximumAttempts: 3, delays: [.milliseconds(100), .milliseconds(250), .milliseconds(500)]),
            reconnectSleeper: RecoverySleeper(),
            keyMaterialGenerator: ScriptedKeyGenerator(materials: keys)
        )

        let events = try await collect(await provider.start(sessionID: UUID(), request: makeRequest()))
        let calls = await launchClient.recordedCalls()

        XCTAssertEqual(calls.launchRequests.count, 1)
        XCTAssertEqual(calls.resumeRequests.map(\.remoteInputKey), keys)
        XCTAssertTrue(events.contains(.reconnecting(attempt: 1, reason: "control_unavailable")))
        XCTAssertTrue(events.contains(.reconnecting(attempt: 2, reason: "control_unavailable")))
        XCTAssertFalse(events.contains(.reconnecting(attempt: 3, reason: "control_unavailable")))
    }

    func testReconnectBudgetExhaustionStopsResourcesAndFailsStructurally() async {
        let keys = (2...4).map {
            RemoteInputKeyMaterial(keyID: $0, key: Data(repeating: UInt8($0), count: 16))
        }
        let launchClient = RecoveryLaunchClient(
            launchResponse: launchResponse(path: "initial"),
            resumeResults: Array(repeating: .failure(URLError(.networkConnectionLost)), count: 3)
        )
        let connection = RecoveryRTSPConnection(responses: setupSequence(session: "initial"))
        let control = RecoveryControlChannel(results: [
            .failure(ControlChannelError.disconnected(data: 0))
        ])
        let provider = MoonlightSessionControlProvider(
            launchClient: launchClient,
            connection: connection,
            controlChannel: control,
            reconnectPolicy: .standard,
            reconnectSleeper: RecoverySleeper(),
            keyMaterialGenerator: ScriptedKeyGenerator(materials: keys)
        )

        let result = await collectFailure(await provider.start(sessionID: UUID(), request: makeRequest()))
        let failure = result.error as? StreamNegotiationFailure
        let calls = await launchClient.recordedCalls()
        let controlStops = await control.stopCount()
        let rtspStops = await connection.cancelCount()

        XCTAssertEqual(failure?.code, .reconnectExhausted)
        XCTAssertEqual(failure?.subsystem, "reconnect")
        XCTAssertEqual(calls.launchRequests.count, 1)
        XCTAssertEqual(calls.resumeRequests.count, 3)
        XCTAssertEqual(calls.stopCount, 1)
        XCTAssertEqual(result.events.filter { if case .reconnecting = $0 { return true }; return false }.count, 3)
        XCTAssertGreaterThanOrEqual(controlStops, 4)
        XCTAssertGreaterThanOrEqual(rtspStops, 4)
        XCTAssertEqual(result.events.firstIndex(of: .channelsReady([])), 3)
    }

    func testAuthenticatedFrameFailureDoesNotRetryOrResume() async {
        let launchClient = RecoveryLaunchClient(
            launchResponse: launchResponse(path: "initial"),
            resumeResults: []
        )
        let provider = MoonlightSessionControlProvider(
            launchClient: launchClient,
            connection: RecoveryRTSPConnection(responses: setupSequence(session: "initial")),
            controlChannel: RecoveryControlChannel(results: [
                .failure(ControlChannelError.invalidFrame)
            ]),
            reconnectPolicy: .standard,
            reconnectSleeper: RecoverySleeper(),
            keyMaterialGenerator: ScriptedKeyGenerator(materials: [])
        )

        let result = await collectFailure(await provider.start(sessionID: UUID(), request: makeRequest()))
        let calls = await launchClient.recordedCalls()

        XCTAssertEqual(result.error as? ControlChannelError, .invalidFrame)
        XCTAssertEqual(calls.launchRequests.count, 1)
        XCTAssertTrue(calls.resumeRequests.isEmpty)
        XCTAssertTrue(result.events.contains(.channelsReady([])))
        XCTAssertFalse(result.events.contains { if case .reconnecting = $0 { return true }; return false })
    }

    func testDuplicateReconnectKeyMaterialFailsBeforeResume() async {
        let request = makeRequest()
        let launchClient = RecoveryLaunchClient(
            launchResponse: launchResponse(path: "initial"),
            resumeResults: []
        )
        let provider = MoonlightSessionControlProvider(
            launchClient: launchClient,
            connection: RecoveryRTSPConnection(responses: setupSequence(session: "initial")),
            controlChannel: RecoveryControlChannel(results: [
                .failure(ControlChannelError.disconnected(data: 0))
            ]),
            reconnectPolicy: .standard,
            reconnectSleeper: RecoverySleeper(),
            keyMaterialGenerator: ScriptedKeyGenerator(
                materials: Array(repeating: request.remoteInputKey, count: 4)
            )
        )

        let result = await collectFailure(await provider.start(sessionID: UUID(), request: request))
        let calls = await launchClient.recordedCalls()

        XCTAssertEqual((result.error as? StreamNegotiationFailure)?.code, .reconnectKeyGenerationFailed)
        XCTAssertTrue(calls.resumeRequests.isEmpty)
    }

    func testReconnectClassifierSeparatesTransientTransportFromAuthenticationAndFrames() {
        let classifier = SessionReconnectFailureClassifier()

        XCTAssertTrue(classifier.isRetryable(ControlChannelError.disconnected(data: 1)))
        XCTAssertTrue(classifier.isRetryable(ENetTransportError.timedOut))
        XCTAssertTrue(classifier.isRetryable(NetworkChannelError.closed))
        XCTAssertTrue(classifier.isRetryable(URLError(.notConnectedToInternet)))
        XCTAssertFalse(classifier.isRetryable(ControlChannelError.invalidFrame))
        XCTAssertFalse(classifier.isRetryable(PinnedTransportError.certificateMismatch))
        XCTAssertFalse(classifier.isRetryable(RTSPBootstrapError.cSeqMismatch))
    }

    func testSecureReconnectKeyGeneratorProducesValidDistinctMaterial() throws {
        let generator = SecureRemoteInputKeyMaterialGenerator()

        let first = try generator.generate()
        let second = try generator.generate()

        XCTAssertEqual(first.key.count, 16)
        XCTAssertEqual(second.key.count, 16)
        XCTAssertTrue((0...Int(UInt32.max)).contains(first.keyID))
        XCTAssertTrue((0...Int(UInt32.max)).contains(second.keyID))
        XCTAssertNotEqual(first, second)
    }

    func testReconnectPolicyRequiresCompleteNonnegativeBudget() throws {
        XCTAssertEqual(try SessionReconnectPolicy.standard.delay(forAttempt: 1), .milliseconds(100))
        XCTAssertEqual(try SessionReconnectPolicy.standard.delay(forAttempt: 3), .milliseconds(500))
        XCTAssertThrowsError(try SessionReconnectPolicy(
            maximumAttempts: 2,
            delays: [.milliseconds(1)]
        ).validate())
        XCTAssertThrowsError(try SessionReconnectPolicy(
            maximumAttempts: 1,
            delays: [.milliseconds(-1)]
        ).validate())
    }

    func testReplacedAttemptCannotPublishLateReadiness() async throws {
        let launchClient = ReplacementLaunchClient()
        let connection = ReplacementRTSPConnection(
            secondAttemptResponses: setupSequence(session: "replacement")
        )
        let provider = MoonlightSessionControlProvider(
            launchClient: launchClient,
            connection: connection,
            controlChannel: RecoveryControlChannel(results: [
                .success(.terminated(HostTerminationReason(code: 0x8003_0023, kind: .graceful)))
            ]),
            reconnectPolicy: .standard,
            reconnectSleeper: RecoverySleeper(),
            keyMaterialGenerator: ScriptedKeyGenerator(materials: [])
        )
        let firstSessionID = UUID()
        let firstStream = await provider.start(
            sessionID: firstSessionID,
            request: makeRequest()
        )
        let firstCollector = Task { @Sendable in
            var events: [SessionControlEvent] = []
            do {
                for try await event in firstStream {
                    events.append(event)
                }
            } catch {
                // Replacement cancellation is the expected terminal path.
            }
            return events
        }
        await connection.waitUntilFirstAttemptBlocks()

        let secondStream = await provider.start(
            sessionID: UUID(),
            request: makeRequest()
        )
        let secondEvents = try await collect(secondStream)
        let firstEvents = await firstCollector.value
        let launchResponses = await launchClient.recordedResponses()

        XCTAssertEqual(firstEvents, [.launchAccepted(launchResponses[0])])
        XCTAssertFalse(firstEvents.contains(.rtspReady))
        XCTAssertFalse(firstEvents.contains { if case .channelsReady = $0 { return true }; return false })
        XCTAssertEqual(secondEvents, [
            .launchAccepted(launchResponses[1]),
            .rtspReady,
            .channelsReady(.control),
            .terminated(reason: "The host ended the streaming session.")
        ])
    }

    private func makeRequest() -> StreamLaunchRequest {
        StreamLaunchRequest(
            host: MoonlightHost(
                id: UUID(uuidString: "63EE959F-16AE-4E5F-A23B-C58455733BDA")!,
                name: "Recovery Host",
                address: "example.invalid",
                pairingState: .paired,
                reachability: .online,
                pinnedIdentity: PinnedHostIdentity(
                    certificateSHA256: "synthetic-pin",
                    serverCertificateDER: Data([1, 2, 3]),
                    pairedAt: Date(timeIntervalSince1970: 1)
                )
            ),
            app: RemoteApp(id: "1", name: "Desktop", supportsHDR: false, installPath: nil),
            preferences: .defaults,
            clientUniqueID: "synthetic-client",
            remoteInputKey: RemoteInputKeyMaterial(keyID: 1, key: Data(repeating: 0x11, count: 16)),
            audioPlaybackMode: .clientOnly,
            controllerBitmap: 0,
            optimizeGameSettings: false
        )
    }

    private func launchResponse(
        path: String = "session",
        resumed: Bool = false
    ) -> StreamLaunchResponse {
        StreamLaunchResponse(
            sessionURL: "rtsp://example.invalid/\(path)",
            gameSessionID: resumed ? nil : "session-1",
            rawValues: resumed ? ["resume": "1"] : ["gamesession": "session-1"]
        )
    }

    private func setupSequence(session: String) -> [RTSPResponse] {
        [
            response(cSeq: "1"),
            response(cSeq: "2", body: Data("v=0\r\n".utf8)),
            setupResponse(cSeq: "3", session: session, port: 48_000),
            setupResponse(cSeq: "4", session: session, port: 47_998),
            setupResponse(cSeq: "5", session: session, port: 47_999, connectData: 123)
        ]
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

private actor RecoveryHTTPExecutor: PinnedHTTPSRequestExecuting {
    struct Call: Sendable {
        var url: URL
    }

    private let response: Data
    private var calls: [Call] = []

    init(response: Data) {
        self.response = response
    }

    func data(
        for request: URLRequest,
        pinnedIdentity: PinnedHostIdentity?
    ) async throws -> (Data, URLResponse) {
        let url = try XCTUnwrap(request.url)
        calls.append(Call(url: url))
        return (
            response,
            URLResponse(
                url: url,
                mimeType: "application/xml",
                expectedContentLength: response.count,
                textEncodingName: "utf-8"
            )
        )
    }

    func recordedCalls() -> [Call] {
        calls
    }
}

private actor RecoveryLaunchClient: StreamLaunchClient {
    private let launchResponse: StreamLaunchResponse
    private var resumeResults: [Result<StreamLaunchResponse, Error>]
    private var launchRequests: [StreamLaunchRequest] = []
    private var resumeRequests: [StreamLaunchRequest] = []
    private var stops = 0

    init(
        launchResponse: StreamLaunchResponse,
        resumeResults: [Result<StreamLaunchResponse, Error>]
    ) {
        self.launchResponse = launchResponse
        self.resumeResults = resumeResults
    }

    func launch(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        launchRequests.append(request)
        return launchResponse
    }

    func resume(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        resumeRequests.append(request)
        guard !resumeResults.isEmpty else {
            throw StreamNegotiationFailure(
                code: .resumeRejected,
                subsystem: "resume",
                message: "Unexpected resume call."
            )
        }
        return try resumeResults.removeFirst().get()
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {
        stops += 1
    }

    func recordedCalls() -> (
        launchRequests: [StreamLaunchRequest],
        resumeRequests: [StreamLaunchRequest],
        stopCount: Int
    ) {
        (launchRequests, resumeRequests, stops)
    }
}

private actor RecoveryRTSPConnection: RTSPConnectionExecuting {
    private var responses: [RTSPResponse]
    private var keys: [Data] = []
    private var cancellations = 0

    init(responses: [RTSPResponse]) {
        self.responses = responses
    }

    func connect(endpoint: RTSPSessionEndpoint, encryptionKey: Data) async throws {
        keys.append(encryptionKey)
    }

    func transact(_ request: RTSPRequest) async throws -> RTSPResponse {
        guard !responses.isEmpty else { throw RTSPBootstrapError.connectionClosed }
        return responses.removeFirst()
    }

    func cancel() async {
        cancellations += 1
    }

    func recordedKeys() -> [Data] {
        keys
    }

    func cancelCount() -> Int {
        cancellations
    }
}

private actor RecoveryControlChannel: MoonlightControlChannelManaging {
    private var results: [Result<MoonlightControlEvent, Error>]
    private var stops = 0

    init(results: [Result<MoonlightControlEvent, Error>]) {
        self.results = results
    }

    func connect(
        endpoint: RuntimeNetworkEndpoint,
        connectData: UInt32,
        encryptionKey: Data
    ) async throws {}

    func nextEvent() async throws -> MoonlightControlEvent {
        guard !results.isEmpty else { return .idle }
        return try results.removeFirst().get()
    }

    func requestIDR() async throws {}

    func stop() async {
        stops += 1
    }

    func stopCount() -> Int {
        stops
    }
}

private actor RecoverySleeper: SessionReconnectSleeping {
    private var delays: [Duration] = []

    func sleep(for delay: Duration) async throws {
        delays.append(delay)
        try Task.checkCancellation()
    }

    func recordedDelays() -> [Duration] {
        delays
    }
}

private final class ScriptedKeyGenerator: RemoteInputKeyMaterialGenerating, @unchecked Sendable {
    private let lock = NSLock()
    private var materials: [RemoteInputKeyMaterial]

    init(materials: [RemoteInputKeyMaterial]) {
        self.materials = materials
    }

    func generate() throws -> RemoteInputKeyMaterial {
        try lock.withLock {
            guard !materials.isEmpty else {
                throw SessionRecoveryError.randomGenerationFailed(status: -1)
            }
            return materials.removeFirst()
        }
    }
}

private actor ReplacementLaunchClient: StreamLaunchClient {
    private var responses: [StreamLaunchResponse] = []

    func launch(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        let response = StreamLaunchResponse(
            sessionURL: "rtsp://example.invalid/attempt-\(responses.count + 1)",
            gameSessionID: "session-\(responses.count + 1)",
            rawValues: [:]
        )
        responses.append(response)
        return response
    }

    func resume(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        throw StreamNegotiationFailure(
            code: .resumeRejected,
            subsystem: "resume",
            message: "Unexpected resume call."
        )
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {}

    func recordedResponses() -> [StreamLaunchResponse] {
        responses
    }
}

private actor ReplacementRTSPConnection: RTSPConnectionExecuting {
    private var secondAttemptResponses: [RTSPResponse]
    private var transactionCount = 0
    private var firstAttemptBlocked = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(secondAttemptResponses: [RTSPResponse]) {
        self.secondAttemptResponses = secondAttemptResponses
    }

    func connect(endpoint: RTSPSessionEndpoint, encryptionKey: Data) async throws {}

    func transact(_ request: RTSPRequest) async throws -> RTSPResponse {
        transactionCount += 1
        if transactionCount == 1 {
            firstAttemptBlocked = true
            let pending = waiters
            waiters.removeAll()
            pending.forEach { $0.resume() }
            try await Task.sleep(for: .seconds(60))
            throw RTSPBootstrapError.connectionClosed
        }
        guard !secondAttemptResponses.isEmpty else {
            throw RTSPBootstrapError.connectionClosed
        }
        return secondAttemptResponses.removeFirst()
    }

    func cancel() async {}

    func waitUntilFirstAttemptBlocks() async {
        if firstAttemptBlocked { return }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }
}
