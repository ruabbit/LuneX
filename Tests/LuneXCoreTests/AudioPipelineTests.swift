import XCTest
import AVFAudio

final class AudioPipelineTests: XCTestCase {
    func testAudioPipelineConfiguresStartsAndStopsWithRouteSnapshot() async throws {
        let client = StubAudioEngineClient(route: AudioRouteSnapshot(
            outputNames: ["USB DAC"],
            sampleRate: 48_000,
            outputChannelCount: 2,
            preferredBufferDuration: 0.005
        ))
        let pipeline = AudioSessionPipeline(engineClient: client, now: Date(timeIntervalSince1970: 1))

        let configured = try await pipeline.configure(.stereoLowLatency, now: Date(timeIntervalSince1970: 2))
        let running = try await pipeline.start(now: Date(timeIntervalSince1970: 3))
        let stopped = await pipeline.stop(reason: .userInitiated, drain: false, now: Date(timeIntervalSince1970: 4))

        XCTAssertEqual(configured.stage, .configured)
        XCTAssertEqual(configured.configuration, .stereoLowLatency)
        XCTAssertEqual(configured.route?.outputNames, ["USB DAC"])
        XCTAssertEqual(running.stage, .running)
        XCTAssertEqual(stopped.stage, .stopped)
        XCTAssertEqual(stopped.lastStopReason, .userInitiated)

        let calls = client.snapshotCalls()
        XCTAssertEqual(calls, ["configure", "route", "start", "route", "stop:false", "route"])
    }

    func testAudioPipelineFailsWhenStartedWithoutConfiguration() async throws {
        let pipeline = AudioSessionPipeline(engineClient: StubAudioEngineClient(), now: Date(timeIntervalSince1970: 1))

        let snapshot = try await pipeline.start(now: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(snapshot.stage, .failed)
        XCTAssertEqual(snapshot.lastStopReason, .failure)
        XCTAssertEqual(snapshot.lastErrorMessage, "missingConfiguration")
    }

    func testPipelineSchedulesBoundedPCMAndReleasesConsumedBuffers() async throws {
        let client = StubAudioEngineClient()
        let pipeline = AudioSessionPipeline(
            engineClient: client,
            maximumScheduledBuffers: 2,
            now: Date(timeIntervalSince1970: 1)
        )
        _ = try await pipeline.configure(.stereoLowLatency)
        _ = try await pipeline.start()

        let first = try await pipeline.schedule(makePCM(sequence: 7, timestamp: 240))
        let second = try await pipeline.schedule(makePCM(sequence: 8, timestamp: 480))

        XCTAssertEqual(first, AudioScheduleReceipt(sequenceNumber: 7, rtpTimestamp: 240, frameCount: 2))
        XCTAssertEqual(second.sequenceNumber, 8)
        let queuedBeforeCompletion = await pipeline.scheduledBufferCount()
        let framesBeforeCompletion = await pipeline.scheduledFrameCount()
        XCTAssertEqual(queuedBeforeCompletion, 2)
        XCTAssertEqual(framesBeforeCompletion, 4)
        await AudioPipelineXCTAssertThrowsErrorAsync(
            try await pipeline.schedule(makePCM(sequence: 9, timestamp: 720))
        ) { error in
            XCTAssertEqual(error as? AudioPipelineError, .scheduleCapacityExceeded)
        }

        client.completeScheduledBuffer(at: 0)
        await waitForScheduledBufferCount(1, pipeline: pipeline)
        let queuedAfterCompletion = await pipeline.scheduledBufferCount()
        let framesAfterCompletion = await pipeline.scheduledFrameCount()
        XCTAssertEqual(queuedAfterCompletion, 1)
        XCTAssertEqual(framesAfterCompletion, 2)
    }

    func testStopClearsQueueAndIgnoresLateCompletion() async throws {
        let client = StubAudioEngineClient()
        let pipeline = AudioSessionPipeline(engineClient: client)
        _ = try await pipeline.configure(.stereoLowLatency)
        _ = try await pipeline.start()
        _ = try await pipeline.schedule(makePCM(sequence: 1, timestamp: 0))

        _ = await pipeline.stop(reason: .sessionEnded, drain: false)
        client.completeScheduledBuffer(at: 0)
        await Task.yield()

        let scheduledCount = await pipeline.scheduledBufferCount()
        XCTAssertEqual(scheduledCount, 0)
        await AudioPipelineXCTAssertThrowsErrorAsync(
            try await pipeline.schedule(makePCM(sequence: 2, timestamp: 240))
        ) { error in
            XCTAssertEqual(error as? AudioPipelineError, .notRunning)
        }
    }

    func testFailedReconfigureClearsOldGraphAndCannotRestart() async throws {
        let client = StubAudioEngineClient()
        let pipeline = AudioSessionPipeline(engineClient: client)
        _ = try await pipeline.configure(.stereoLowLatency)
        _ = try await pipeline.start()
        _ = try await pipeline.schedule(makePCM(sequence: 1, timestamp: 0))
        client.failNextConfigure()

        let failed = try await pipeline.configure(.stereoLowLatency)
        let restarted = try await pipeline.start()

        XCTAssertEqual(failed.stage, .failed)
        XCTAssertNil(failed.configuration)
        XCTAssertNil(failed.route)
        XCTAssertEqual(restarted.stage, .failed)
        XCTAssertEqual(restarted.lastErrorMessage, "missingConfiguration")
        let scheduledCount = await pipeline.scheduledBufferCount()
        XCTAssertEqual(scheduledCount, 0)
    }

    func testScheduleBackendFailureDoesNotConsumeCapacity() async throws {
        let client = StubAudioEngineClient()
        let pipeline = AudioSessionPipeline(
            engineClient: client,
            maximumScheduledBuffers: 1
        )
        _ = try await pipeline.configure(.stereoLowLatency)
        _ = try await pipeline.start()
        client.failNextSchedule()

        await AudioPipelineXCTAssertThrowsErrorAsync(
            try await pipeline.schedule(makePCM(sequence: 1, timestamp: 0))
        ) { error in
            XCTAssertEqual(error as? AudioPipelineError, .invalidPCMBuffer)
        }

        let scheduledCount = await pipeline.scheduledBufferCount()
        XCTAssertEqual(scheduledCount, 0)
        _ = try await pipeline.schedule(makePCM(sequence: 2, timestamp: 240))
    }

    func testPCMBufferFactoryPreservesInterleavedInt16Samples() throws {
        let decoded = makePCM(sequence: 3, timestamp: 960)

        let buffer = try AVAudioPCMBufferFactory.makeBuffer(from: decoded)

        XCTAssertEqual(buffer.frameLength, 2)
        XCTAssertEqual(buffer.format.sampleRate, 48_000)
        XCTAssertEqual(buffer.format.channelCount, 2)
        XCTAssertTrue(buffer.format.isInterleaved)
        let audioBuffers = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        let pointer = try XCTUnwrap(audioBuffers[0].mData?.assumingMemoryBound(to: Int16.self))
        XCTAssertEqual(Array(UnsafeBufferPointer(start: pointer, count: 4)), decoded.interleavedSamples)
    }

    func testProductionClientBuildsPlayerMixerGraphWithoutStartingHardware() throws {
        let client = AVAudioEngineClient()

        try client.configure(.stereoLowLatency)
        client.stop(drain: false)
        XCTAssertThrowsError(try client.schedule(makePCM(sequence: 1, timestamp: 0), completion: {})) { error in
            XCTAssertEqual(error as? AudioPipelineError, .missingConfiguration)
        }
    }

    func testInvalidStreamConfigurationFailsBeforeBackendConfiguration() async throws {
        let client = StubAudioEngineClient()
        let pipeline = AudioSessionPipeline(engineClient: client)
        var invalid = StreamAudioConfiguration.stereoLowLatency
        invalid.sampleRate = 44_100

        let failed = try await pipeline.configure(invalid)

        XCTAssertEqual(failed.stage, .failed)
        XCTAssertNil(failed.configuration)
        XCTAssertFalse(client.snapshotCalls().contains("configure"))
    }

    func testEngineStartFailureStopsPartialGraphAndClearsConfiguration() async throws {
        let client = StubAudioEngineClient()
        let pipeline = AudioSessionPipeline(engineClient: client)
        _ = try await pipeline.configure(.stereoLowLatency)
        client.failNextStart()

        let failed = try await pipeline.start()

        XCTAssertEqual(failed.stage, .failed)
        XCTAssertNil(failed.configuration)
        XCTAssertNil(failed.route)
        XCTAssertEqual(
            client.snapshotCalls(),
            ["configure", "route", "start", "stop:false"]
        )
    }

    @MainActor
    func testDiagnosticsStoreRecordsAudioSnapshot() {
        let diagnostics = DiagnosticsStore()
        diagnostics.record(audioSnapshot: AudioPipelineSnapshot(
            stage: .running,
            configuration: .stereoLowLatency,
            route: AudioRouteSnapshot(
                outputNames: ["Built-in Output"],
                sampleRate: 48_000,
                outputChannelCount: 2,
                preferredBufferDuration: 0.005
            ),
            lastStopReason: nil,
            lastErrorMessage: nil,
            updatedAt: Date(timeIntervalSince1970: 10)
        ))

        XCTAssertEqual(diagnostics.events.last?.subsystem, "audio")
        XCTAssertEqual(diagnostics.events.last?.message, "Audio running: 48000 Hz, 2 ch, Built-in Output")
    }

    private func makePCM(sequence: UInt16, timestamp: UInt32) -> DecodedPCMBuffer {
        DecodedPCMBuffer(
            sequenceNumber: sequence,
            rtpTimestamp: timestamp,
            format: .signedInt16(sampleRate: 48_000, channelCount: 2),
            frameCount: 2,
            interleavedSamples: [100, -100, 200, -200]
        )
    }

    private func waitForScheduledBufferCount(
        _ expected: Int,
        pipeline: AudioSessionPipeline
    ) async {
        for _ in 0..<100 {
            if await pipeline.scheduledBufferCount() == expected {
                return
            }
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Timed out waiting for scheduled audio completion")
    }
}

private final class StubAudioEngineClient: AudioEngineClient, @unchecked Sendable {
    private let route: AudioRouteSnapshot
    private var calls: [String] = []
    private var completions: [@Sendable () -> Void] = []
    private var shouldFailNextConfigure = false
    private var shouldFailNextStart = false
    private var shouldFailNextSchedule = false

    init(route: AudioRouteSnapshot = AudioRouteSnapshot(
        outputNames: ["System Output"],
        sampleRate: 48_000,
        outputChannelCount: 2,
        preferredBufferDuration: 0.005
    )) {
        self.route = route
    }

    func configure(_ configuration: StreamAudioConfiguration) throws {
        calls.append("configure")
        if shouldFailNextConfigure {
            shouldFailNextConfigure = false
            throw AudioPipelineError.invalidConfiguration
        }
    }

    func start() throws {
        calls.append("start")
        if shouldFailNextStart {
            shouldFailNextStart = false
            throw AudioPipelineError.invalidConfiguration
        }
    }

    func schedule(
        _ buffer: DecodedPCMBuffer,
        completion: @escaping @Sendable () -> Void
    ) throws {
        calls.append("schedule:\(buffer.sequenceNumber)")
        if shouldFailNextSchedule {
            shouldFailNextSchedule = false
            throw AudioPipelineError.invalidPCMBuffer
        }
        completions.append(completion)
    }

    func stop(drain: Bool) {
        calls.append("stop:\(drain)")
    }

    func routeSnapshot() -> AudioRouteSnapshot {
        calls.append("route")
        return route
    }

    func snapshotCalls() -> [String] {
        calls
    }

    func completeScheduledBuffer(at index: Int) {
        completions[index]()
    }

    func failNextConfigure() {
        shouldFailNextConfigure = true
    }

    func failNextSchedule() {
        shouldFailNextSchedule = true
    }

    func failNextStart() {
        shouldFailNextStart = true
    }
}

private func AudioPipelineXCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw")
    } catch {
        errorHandler(error)
    }
}
