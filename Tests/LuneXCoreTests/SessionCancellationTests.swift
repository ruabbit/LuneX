import Foundation
import XCTest

final class SessionCancellationTests: XCTestCase {
    func testRepeatedLocalStopDuringLaunchExecutesOneTeardownAndOneRemoteCancel() async throws {
        let probe = CancellationProbe()
        let launchClient = CancellationLaunchClient(blockPoint: .launch, probe: probe)
        let connection = CancellationRTSPConnection(responses: [], probe: probe)
        let control = CancellationControlChannel(mode: .block, probe: probe)
        let provider = makeProvider(
            launchClient: launchClient,
            connection: connection,
            control: control
        )
        let sessionID = UUID()
        let collector = collect(await provider.start(sessionID: sessionID, request: makeRequest()))
        try await probe.waitUntilReached(.launch)

        async let firstStop: Void = provider.stop(sessionID: sessionID)
        async let secondStop: Void = provider.stop(sessionID: sessionID)
        _ = await (firstStop, secondStop)
        _ = await collector.value

        let counts = await operationCounts(
            launchClient: launchClient,
            connection: connection,
            control: control
        )
        let teardownSnapshot = await provider.teardownSnapshot(sessionID: sessionID)
        let teardown = try XCTUnwrap(teardownSnapshot)
        XCTAssertEqual(counts.remoteCancels, 1)
        XCTAssertEqual(counts.rtspCancellations, 1)
        XCTAssertEqual(counts.controlStops, 1)
        XCTAssertEqual(teardown.executionCount, 1)
        XCTAssertGreaterThanOrEqual(teardown.requestCount, 2)
        XCTAssertEqual(teardown.report?.trigger, .localStop)
        XCTAssertEqual(teardown.report?.remoteCancelResult, .succeeded)
    }

    func testStreamConsumerCancellationDuringLaunchConvergesToRemoteCancel() async throws {
        let probe = CancellationProbe()
        let launchClient = CancellationLaunchClient(blockPoint: .launch, probe: probe)
        let connection = CancellationRTSPConnection(responses: [], probe: probe)
        let control = CancellationControlChannel(mode: .block, probe: probe)
        let provider = makeProvider(
            launchClient: launchClient,
            connection: connection,
            control: control
        )
        let sessionID = UUID()
        let collector = collect(await provider.start(sessionID: sessionID, request: makeRequest()))
        try await probe.waitUntilReached(.launch)

        collector.cancel()
        _ = await collector.value
        let teardown = try await waitForTeardown(provider: provider, sessionID: sessionID)
        let remoteCancels = await launchClient.stopCount()

        XCTAssertEqual(teardown.executionCount, 1)
        XCTAssertEqual(teardown.report?.trigger, .streamCancellation)
        XCTAssertEqual(teardown.report?.remoteCancelResult, .succeeded)
        XCTAssertEqual(remoteCancels, 1)
    }

    func testLocalStopDuringRTSPTransactionUnblocksAndCancelsRemoteSession() async throws {
        let probe = CancellationProbe()
        let launchClient = CancellationLaunchClient(blockPoint: .none, probe: probe)
        let connection = CancellationRTSPConnection(
            responses: setupSequence(),
            blockTransaction: 1,
            probe: probe
        )
        let control = CancellationControlChannel(mode: .block, probe: probe)
        let provider = makeProvider(
            launchClient: launchClient,
            connection: connection,
            control: control
        )
        let sessionID = UUID()
        let collector = collect(await provider.start(sessionID: sessionID, request: makeRequest()))
        try await probe.waitUntilReached(.rtspTransaction)

        await provider.stop(sessionID: sessionID)
        _ = await collector.value

        let remoteCancels = await launchClient.stopCount()
        let rtspCancellations = await connection.cancelCount()
        let teardownSnapshot = await provider.teardownSnapshot(sessionID: sessionID)
        let teardown = try XCTUnwrap(teardownSnapshot)
        XCTAssertEqual(remoteCancels, 1)
        XCTAssertEqual(rtspCancellations, 1)
        XCTAssertEqual(teardown.executionCount, 1)
        XCTAssertEqual(teardown.report?.remoteCancelResult, .succeeded)
    }

    func testLocalStopDuringReconnectSleepDoesNotContinueToResume() async throws {
        let probe = CancellationProbe()
        let launchClient = CancellationLaunchClient(blockPoint: .none, probe: probe)
        let connection = CancellationRTSPConnection(responses: setupSequence(), probe: probe)
        let control = CancellationControlChannel(mode: .disconnect, probe: probe)
        let sleeper = CancellationSleeper(blocks: true, probe: probe)
        let provider = makeProvider(
            launchClient: launchClient,
            connection: connection,
            control: control,
            sleeper: sleeper
        )
        let sessionID = UUID()
        let collector = collect(await provider.start(sessionID: sessionID, request: makeRequest()))
        try await probe.waitUntilReached(.reconnectSleep)

        await provider.stop(sessionID: sessionID)
        _ = await collector.value

        let counts = await launchClient.counts()
        let teardownSnapshot = await provider.teardownSnapshot(sessionID: sessionID)
        let teardown = try XCTUnwrap(teardownSnapshot)
        XCTAssertEqual(counts.launches, 1)
        XCTAssertEqual(counts.resumes, 0)
        XCTAssertEqual(counts.stops, 1)
        XCTAssertEqual(teardown.executionCount, 1)
    }

    func testLocalStopDuringResumeCancelsInFlightResumeAndDoesNotReconnect() async throws {
        let probe = CancellationProbe()
        let launchClient = CancellationLaunchClient(blockPoint: .resume, probe: probe)
        let connection = CancellationRTSPConnection(responses: setupSequence(), probe: probe)
        let control = CancellationControlChannel(mode: .disconnect, probe: probe)
        let provider = makeProvider(
            launchClient: launchClient,
            connection: connection,
            control: control,
            sleeper: CancellationSleeper(blocks: false, probe: probe)
        )
        let sessionID = UUID()
        let collector = collect(await provider.start(sessionID: sessionID, request: makeRequest()))
        try await probe.waitUntilReached(.resume)

        await provider.stop(sessionID: sessionID)
        _ = await collector.value

        let counts = await launchClient.counts()
        let teardownSnapshot = await provider.teardownSnapshot(sessionID: sessionID)
        let teardown = try XCTUnwrap(teardownSnapshot)
        XCTAssertEqual(counts.launches, 1)
        XCTAssertEqual(counts.resumes, 1)
        XCTAssertEqual(counts.stops, 1)
        XCTAssertEqual(teardown.executionCount, 1)
    }

    func testRemoteTerminationRacingLocalStopUsesOneTeardown() async throws {
        let probe = CancellationProbe()
        let launchClient = CancellationLaunchClient(blockPoint: .none, probe: probe)
        let connection = CancellationRTSPConnection(responses: setupSequence(), probe: probe)
        let control = CancellationControlChannel(mode: .terminate, probe: probe)
        let provider = makeProvider(
            launchClient: launchClient,
            connection: connection,
            control: control
        )
        let sessionID = UUID()
        let collector = collect(await provider.start(sessionID: sessionID, request: makeRequest()))

        async let localStop: Void = provider.stop(sessionID: sessionID)
        _ = await localStop
        _ = await collector.value

        let controlStops = await control.stopCount()
        let rtspCancellations = await connection.cancelCount()
        let remoteCancels = await launchClient.stopCount()
        let teardownSnapshot = await provider.teardownSnapshot(sessionID: sessionID)
        let teardown = try XCTUnwrap(teardownSnapshot)
        XCTAssertEqual(controlStops, 1)
        XCTAssertEqual(rtspCancellations, 1)
        XCTAssertLessThanOrEqual(remoteCancels, 1)
        XCTAssertEqual(teardown.executionCount, 1)
        let trigger = try XCTUnwrap(teardown.report?.trigger)
        XCTAssertTrue([.localStop, .remoteTermination].contains(trigger))
    }

    func testLocalStopAfterRemoteTerminationPreservesNoCancelDecision() async throws {
        let probe = CancellationProbe()
        let launchClient = CancellationLaunchClient(blockPoint: .none, probe: probe)
        let connection = CancellationRTSPConnection(responses: setupSequence(), probe: probe)
        let control = CancellationControlChannel(mode: .terminate, probe: probe)
        let provider = makeProvider(
            launchClient: launchClient,
            connection: connection,
            control: control
        )
        let sessionID = UUID()
        let stream = await provider.start(sessionID: sessionID, request: makeRequest())
        let collector = Task {
            var events: [SessionControlEvent] = []
            do {
                for try await event in stream {
                    events.append(event)
                    if case .terminated = event {
                        await probe.mark(.terminationEvent)
                    }
                }
            } catch {
                // Teardown assertions below capture the terminal behavior.
            }
            return events
        }
        try await probe.waitUntilReached(.terminationEvent)

        await provider.stop(sessionID: sessionID)
        _ = await collector.value

        let remoteCancels = await launchClient.stopCount()
        let teardownSnapshot = await provider.teardownSnapshot(sessionID: sessionID)
        let teardown = try XCTUnwrap(teardownSnapshot)
        XCTAssertEqual(remoteCancels, 0)
        XCTAssertEqual(teardown.executionCount, 1)
        XCTAssertEqual(teardown.report?.trigger, .remoteTermination)
        XCTAssertEqual(teardown.report?.remoteCancelResult, .notRequested)
    }

    func testRemoteCancelFailureStillReleasesEveryLocalResource() async throws {
        let probe = CancellationProbe()
        let launchClient = CancellationLaunchClient(
            blockPoint: .launch,
            probe: probe,
            stopFails: true
        )
        let connection = CancellationRTSPConnection(responses: [], probe: probe)
        let control = CancellationControlChannel(mode: .block, probe: probe)
        let provider = makeProvider(
            launchClient: launchClient,
            connection: connection,
            control: control
        )
        let sessionID = UUID()
        let collector = collect(await provider.start(sessionID: sessionID, request: makeRequest()))
        try await probe.waitUntilReached(.launch)

        await provider.stop(sessionID: sessionID)
        _ = await collector.value

        let counts = await operationCounts(
            launchClient: launchClient,
            connection: connection,
            control: control
        )
        let teardownSnapshot = await provider.teardownSnapshot(sessionID: sessionID)
        let teardown = try XCTUnwrap(teardownSnapshot)
        XCTAssertEqual(counts.remoteCancels, 1)
        XCTAssertEqual(counts.rtspCancellations, 1)
        XCTAssertEqual(counts.controlStops, 1)
        XCTAssertEqual(teardown.executionCount, 1)
        XCTAssertEqual(teardown.report?.remoteCancelResult, .failed)
        XCTAssertEqual(teardown.report?.releasedLocalResources, true)
    }

    private func makeProvider(
        launchClient: CancellationLaunchClient,
        connection: CancellationRTSPConnection,
        control: CancellationControlChannel,
        sleeper: CancellationSleeper? = nil
    ) -> MoonlightSessionControlProvider {
        MoonlightSessionControlProvider(
            launchClient: launchClient,
            connection: connection,
            controlChannel: control,
            reconnectPolicy: .standard,
            reconnectSleeper: sleeper ?? CancellationSleeper(
                blocks: false,
                probe: CancellationProbe()
            ),
            keyMaterialGenerator: CancellationKeyGenerator()
        )
    }

    private func collect(
        _ stream: AsyncThrowingStream<SessionControlEvent, Error>
    ) -> Task<[SessionControlEvent], Never> {
        Task {
            var events: [SessionControlEvent] = []
            do {
                for try await event in stream {
                    events.append(event)
                }
            } catch {
                // Failure behavior is asserted through teardown and provider state.
            }
            return events
        }
    }

    private func waitForTeardown(
        provider: MoonlightSessionControlProvider,
        sessionID: UUID
    ) async throws -> SessionControlTeardownSnapshot {
        for _ in 0..<1_000 {
            if let snapshot = await provider.teardownSnapshot(sessionID: sessionID),
               snapshot.report != nil {
                return snapshot
            }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw CancellationTestError.timedOut
    }

    private func operationCounts(
        launchClient: CancellationLaunchClient,
        connection: CancellationRTSPConnection,
        control: CancellationControlChannel
    ) async -> (remoteCancels: Int, rtspCancellations: Int, controlStops: Int) {
        let remoteCancels = await launchClient.stopCount()
        let rtspCancellations = await connection.cancelCount()
        let controlStops = await control.stopCount()
        return (remoteCancels, rtspCancellations, controlStops)
    }

    private func makeRequest() -> StreamLaunchRequest {
        StreamLaunchRequest(
            host: MoonlightHost(
                id: UUID(uuidString: "7D75E1DA-499F-420D-9DDD-250B3991A068")!,
                name: "Cancellation Host",
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
            remoteInputKey: RemoteInputKeyMaterial(
                keyID: 1,
                key: Data(repeating: 0x11, count: 16)
            ),
            audioPlaybackMode: .clientOnly,
            controllerBitmap: 0,
            optimizeGameSettings: false
        )
    }

    private func setupSequence() -> [RTSPResponse] {
        [
            response(cSeq: "1"),
            response(cSeq: "2", body: Data("v=0\r\n".utf8)),
            setupResponse(cSeq: "3", port: 48_000),
            setupResponse(cSeq: "4", port: 47_998),
            setupResponse(cSeq: "5", port: 47_999, connectData: 7)
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
        port: UInt16,
        connectData: UInt32? = nil
    ) -> RTSPResponse {
        var headers = [
            RTSPHeader(name: "CSeq", value: cSeq),
            RTSPHeader(name: "Session", value: "session-token"),
            RTSPHeader(name: "Transport", value: "server_port=\(port)")
        ]
        if let connectData {
            headers.append(RTSPHeader(name: "X-SS-Connect-Data", value: String(connectData)))
        }
        return RTSPResponse(statusCode: 200, reasonPhrase: "OK", headers: headers)
    }
}

private enum CancellationTestError: Error {
    case timedOut
    case scriptedStopFailure
    case cleanupInheritedCancellation
}

private actor CancellationProbe {
    enum Stage: Hashable {
        case launch
        case rtspTransaction
        case reconnectSleep
        case resume
        case terminationEvent
    }

    private var reached: Set<Stage> = []

    func mark(_ stage: Stage) {
        reached.insert(stage)
    }

    func hasReached(_ stage: Stage) -> Bool {
        reached.contains(stage)
    }

    func waitUntilReached(_ stage: Stage) async throws {
        for _ in 0..<1_000 {
            if reached.contains(stage) { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw CancellationTestError.timedOut
    }
}

private actor CancellationLaunchClient: StreamLaunchClient {
    enum BlockPoint: Equatable {
        case none
        case launch
        case resume
    }

    private let blockPoint: BlockPoint
    private let probe: CancellationProbe
    private let stopFails: Bool
    private var launches = 0
    private var resumes = 0
    private var stops = 0

    init(
        blockPoint: BlockPoint,
        probe: CancellationProbe,
        stopFails: Bool = false
    ) {
        self.blockPoint = blockPoint
        self.probe = probe
        self.stopFails = stopFails
    }

    func launch(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        launches += 1
        if blockPoint == .launch {
            await probe.mark(.launch)
            try await Task.sleep(for: .seconds(60))
        }
        return StreamLaunchResponse(
            sessionURL: "rtsp://example.invalid/session",
            gameSessionID: "session-1",
            rawValues: ["gamesession": "session-1"]
        )
    }

    func resume(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        resumes += 1
        if blockPoint == .resume {
            await probe.mark(.resume)
            try await Task.sleep(for: .seconds(60))
        }
        return StreamLaunchResponse(
            sessionURL: "rtsp://example.invalid/resumed",
            gameSessionID: nil,
            rawValues: ["resume": "1"]
        )
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {
        stops += 1
        if Task.isCancelled {
            throw CancellationTestError.cleanupInheritedCancellation
        }
        if stopFails {
            throw CancellationTestError.scriptedStopFailure
        }
    }

    func counts() -> (launches: Int, resumes: Int, stops: Int) {
        (launches, resumes, stops)
    }

    func stopCount() -> Int {
        stops
    }
}

private actor CancellationRTSPConnection: RTSPConnectionExecuting {
    private var responses: [RTSPResponse]
    private let blockTransaction: Int?
    private let probe: CancellationProbe
    private var transactions = 0
    private var cancellations = 0

    init(
        responses: [RTSPResponse],
        blockTransaction: Int? = nil,
        probe: CancellationProbe
    ) {
        self.responses = responses
        self.blockTransaction = blockTransaction
        self.probe = probe
    }

    func connect(endpoint: RTSPSessionEndpoint, encryptionKey: Data) async throws {}

    func transact(_ request: RTSPRequest) async throws -> RTSPResponse {
        transactions += 1
        if transactions == blockTransaction {
            await probe.mark(.rtspTransaction)
            try await Task.sleep(for: .seconds(60))
        }
        guard !responses.isEmpty else { throw RTSPBootstrapError.connectionClosed }
        return responses.removeFirst()
    }

    func cancel() async {
        cancellations += 1
    }

    func cancelCount() -> Int {
        cancellations
    }
}

private actor CancellationControlChannel: MoonlightControlChannelManaging {
    enum Mode {
        case block
        case disconnect
        case terminate
    }

    private let mode: Mode
    private let probe: CancellationProbe
    private var stops = 0

    init(mode: Mode, probe: CancellationProbe) {
        self.mode = mode
        self.probe = probe
    }

    func connect(
        endpoint: RuntimeNetworkEndpoint,
        connectData: UInt32,
        encryptionKey: Data
    ) async throws {}

    func nextEvent() async throws -> MoonlightControlEvent {
        switch mode {
        case .block:
            try await Task.sleep(for: .seconds(60))
            return .idle
        case .disconnect:
            throw ControlChannelError.disconnected(data: 0)
        case .terminate:
            return .terminated(HostTerminationReason(code: 0x8003_0023, kind: .graceful))
        }
    }

    func requestIDR() async throws {}

    func stop() async {
        stops += 1
    }

    func stopCount() -> Int {
        stops
    }
}

private actor CancellationSleeper: SessionReconnectSleeping {
    private let blocks: Bool
    private let probe: CancellationProbe

    init(blocks: Bool, probe: CancellationProbe) {
        self.blocks = blocks
        self.probe = probe
    }

    func sleep(for delay: Duration) async throws {
        await probe.mark(.reconnectSleep)
        if blocks {
            try await Task.sleep(for: .seconds(60))
        } else {
            try Task.checkCancellation()
        }
    }
}

private final class CancellationKeyGenerator: RemoteInputKeyMaterialGenerating, @unchecked Sendable {
    private let lock = NSLock()
    private var nextKeyID = 2

    func generate() throws -> RemoteInputKeyMaterial {
        lock.withLock {
            defer { nextKeyID += 1 }
            return RemoteInputKeyMaterial(
                keyID: nextKeyID,
                key: Data(repeating: UInt8(nextKeyID), count: 16)
            )
        }
    }
}
