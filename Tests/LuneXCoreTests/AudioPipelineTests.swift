import XCTest

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
}

private final class StubAudioEngineClient: AudioEngineClient, @unchecked Sendable {
    private let route: AudioRouteSnapshot
    private var calls: [String] = []

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
    }

    func start() throws {
        calls.append("start")
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
}
