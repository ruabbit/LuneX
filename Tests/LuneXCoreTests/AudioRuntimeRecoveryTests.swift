import Foundation
import XCTest

final class AudioRuntimeRecoveryTests: XCTestCase {
    func testStartScheduleAndIdempotentStopOwnPipelineAndClock() async throws {
        let harness = try makeHarness()
        let started = try await harness.runtime.start(at: 0)
        _ = try await harness.runtime.schedule(
            pcm(sequence: 1, timestamp: 0),
            presentationTimeNanoseconds: 1
        )

        let stopped = try await harness.runtime.stop(at: 2)
        let stoppedAgain = try await harness.runtime.stop(at: 3)

        XCTAssertEqual(started.stage, .running)
        XCTAssertEqual(stopped.stage, .stopped)
        XCTAssertEqual(stopped.clock.master, .unavailable)
        XCTAssertEqual(stoppedAgain.lastAction, .stopped)
        await RecoveryXCTAssertThrowsErrorAsync(
            try await harness.runtime.schedule(
                pcm(sequence: 2, timestamp: 240),
                presentationTimeNanoseconds: 4
            )
        ) { error in
            XCTAssertEqual(error as? AudioRuntimeRecoveryError, .stopped)
        }
    }

    func testRouteChangeRebuildsGraphAndClearsClock() async throws {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 0)
        _ = try await harness.runtime.schedule(
            pcm(sequence: 1, timestamp: 0),
            presentationTimeNanoseconds: 1
        )

        let rebuilt = try await harness.runtime.handle(.routeChanged, at: 2)

        XCTAssertEqual(rebuilt.stage, .running)
        XCTAssertEqual(rebuilt.lastAction, .graphRebuilt(.routeChanged))
        XCTAssertEqual(rebuilt.clock.master, .unavailable)
        XCTAssertEqual(
            harness.client.snapshotCalls(),
            [
                "configure", "route", "start", "route", "schedule:1",
                "stop:false", "configure", "route", "start", "route"
            ]
        )
    }

    func testInterruptionPausesAndConditionallyResumesGraph() async throws {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 0)

        let paused = try await harness.runtime.handle(.interruptionBegan, at: 1)
        let deferred = try await harness.runtime.handle(
            .interruptionEnded(shouldResume: false),
            at: 2
        )
        let resumed = try await harness.runtime.handle(
            .interruptionEnded(shouldResume: true),
            at: 3
        )

        XCTAssertEqual(paused.stage, .interrupted)
        XCTAssertEqual(paused.lastAction, .interruptionPaused)
        XCTAssertEqual(deferred.stage, .interrupted)
        XCTAssertEqual(deferred.lastAction, .interruptionResumeDeferred)
        XCTAssertEqual(resumed.stage, .running)
        XCTAssertEqual(resumed.lastAction, .interruptionResumed)
    }

    func testRouteChangeDuringInterruptionDefersUntilResume() async throws {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 0)
        _ = try await harness.runtime.handle(.interruptionBegan, at: 1)

        let deferred = try await harness.runtime.handle(.routeChanged, at: 2)
        let resumed = try await harness.runtime.handle(
            .interruptionEnded(shouldResume: true),
            at: 3
        )

        XCTAssertEqual(deferred.stage, .interrupted)
        XCTAssertEqual(deferred.lastAction, .routeChangeDeferred)
        XCTAssertEqual(resumed.stage, .running)
        XCTAssertEqual(resumed.lastAction, .interruptionResumed)
    }

    func testUnderrunRebuildsGraphAndResetsClock() async throws {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 0)
        _ = try await harness.runtime.schedule(
            pcm(sequence: 1, timestamp: 0),
            presentationTimeNanoseconds: 1
        )

        let recovered = try await harness.runtime.handle(.underrun, at: 2)

        XCTAssertEqual(recovered.lastAction, .graphRebuilt(.underrun))
        XCTAssertEqual(recovered.clock.master, .unavailable)
        XCTAssertEqual(recovered.pipeline.stage, .running)
    }

    func testShortPacketLossSchedulesBoundedSilenceAndAdvancesClock() async throws {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 0)

        let concealed = try await harness.runtime.handle(
            .packetLoss(
                firstSequenceNumber: UInt16.max,
                firstRTPTimeStamp: UInt32.max - 100,
                packetCount: 2,
                samplesPerPacket: 240
            ),
            at: 1
        )

        XCTAssertEqual(
            concealed.lastAction,
            .silenceScheduled(packetCount: 2, frameCount: 480)
        )
        XCTAssertEqual(concealed.concealedFrameCount, 480)
        XCTAssertEqual(concealed.clock.audioScheduledFrameCount, 480)
        let scheduled = harness.client.snapshotScheduledBuffers()
        XCTAssertEqual(scheduled.map(\.sequenceNumber), [UInt16.max, 0])
        XCTAssertEqual(scheduled.map(\.rtpTimestamp), [UInt32.max - 100, 139])
        XCTAssertTrue(scheduled.allSatisfy { $0.interleavedSamples.allSatisfy { $0 == 0 } })
    }

    func testLargePacketLossRebuildsWithoutAllocatingSilence() async throws {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 0)

        let recovered = try await harness.runtime.handle(
            .packetLoss(
                firstSequenceNumber: 1,
                firstRTPTimeStamp: 1,
                packetCount: 5,
                samplesPerPacket: 240
            ),
            at: 1
        )

        XCTAssertEqual(recovered.lastAction, .graphRebuilt(.packetLossExceeded))
        XCTAssertTrue(harness.client.snapshotScheduledBuffers().isEmpty)
        XCTAssertEqual(recovered.clock.master, .unavailable)
    }

    func testPartialConcealmentFailureRebuildsAndClearsScheduledBuffers() async throws {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 0)
        harness.client.failScheduleCall(2)

        let recovered = try await harness.runtime.handle(
            .packetLoss(
                firstSequenceNumber: 1,
                firstRTPTimeStamp: 1,
                packetCount: 2,
                samplesPerPacket: 240
            ),
            at: 1
        )

        XCTAssertEqual(recovered.lastAction, .graphRebuilt(.concealmentFailed))
        XCTAssertEqual(recovered.pipeline.stage, .running)
        XCTAssertEqual(recovered.clock.master, .unavailable)
        XCTAssertTrue(harness.client.snapshotScheduledBuffers().isEmpty)
    }

    func testGraphFailureStopsResourcesAndFailsClosed() async throws {
        let harness = try makeHarness()
        harness.client.failNextConfigure()

        await RecoveryXCTAssertThrowsErrorAsync(
            try await harness.runtime.start(at: 0)
        ) { error in
            XCTAssertEqual(
                error as? AudioRuntimeRecoveryError,
                .graphFailed("invalidConfiguration")
            )
        }
        let calls = harness.client.snapshotCalls()
        XCTAssertEqual(calls, ["configure", "stop:false"])
    }

    func testBackwardEventTimeAndInvalidPolicyFailClosed() async throws {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 10)

        await RecoveryXCTAssertThrowsErrorAsync(
            try await harness.runtime.handle(.underrun, at: 9)
        ) { error in
            XCTAssertEqual(error as? AudioRuntimeRecoveryError, .nonMonotonicEventTime)
        }
        XCTAssertThrowsError(try AudioRuntimeRecoveryPolicy(
            maximumConcealedPackets: 0,
            maximumConcealedFrames: 0
        ).validate()) { error in
            XCTAssertEqual(error as? AudioRuntimeRecoveryError, .invalidPolicy)
        }
    }

    private func makeHarness() throws -> RecoveryHarness {
        let client = RecoveryAudioEngineClient()
        let pipeline = AudioSessionPipeline(engineClient: client)
        let clock = try MediaClockSynchronizer()
        let runtime = try SessionAudioRuntime(
            pipeline: pipeline,
            clock: clock,
            configuration: .stereoLowLatency
        )
        return RecoveryHarness(runtime: runtime, client: client)
    }

    private func pcm(sequence: UInt16, timestamp: UInt32) -> DecodedPCMBuffer {
        DecodedPCMBuffer(
            sequenceNumber: sequence,
            rtpTimestamp: timestamp,
            format: .signedInt16(sampleRate: 48_000, channelCount: 2),
            frameCount: 240,
            interleavedSamples: [Int16](repeating: 1, count: 480)
        )
    }
}

private struct RecoveryHarness {
    var runtime: SessionAudioRuntime
    var client: RecoveryAudioEngineClient
}

private final class RecoveryAudioEngineClient: AudioEngineClient, @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [String] = []
    private var scheduledBuffers: [DecodedPCMBuffer] = []
    private var scheduleCallCount = 0
    private var failingScheduleCall: Int?
    private var shouldFailNextConfigure = false

    func configure(_ configuration: StreamAudioConfiguration) throws {
        lock.withLock {
            calls.append("configure")
        }
        let shouldFail = lock.withLock { () -> Bool in
            defer { shouldFailNextConfigure = false }
            return shouldFailNextConfigure
        }
        if shouldFail { throw AudioPipelineError.invalidConfiguration }
    }

    func start() throws {
        lock.withLock { calls.append("start") }
    }

    func schedule(
        _ buffer: DecodedPCMBuffer,
        completion: @escaping @Sendable () -> Void
    ) throws {
        let shouldFail = lock.withLock { () -> Bool in
            scheduleCallCount += 1
            calls.append("schedule:\(buffer.sequenceNumber)")
            return scheduleCallCount == failingScheduleCall
        }
        if shouldFail { throw AudioPipelineError.invalidPCMBuffer }
        lock.withLock { scheduledBuffers.append(buffer) }
    }

    func stop(drain: Bool) {
        lock.withLock {
            calls.append("stop:\(drain)")
            scheduledBuffers.removeAll()
        }
    }

    func routeSnapshot() -> AudioRouteSnapshot {
        lock.withLock { calls.append("route") }
        return AudioRouteSnapshot(
            outputNames: ["Test Output"],
            sampleRate: 48_000,
            outputChannelCount: 2,
            preferredBufferDuration: 0.005
        )
    }

    func failNextConfigure() {
        lock.withLock { shouldFailNextConfigure = true }
    }

    func failScheduleCall(_ call: Int) {
        lock.withLock { failingScheduleCall = call }
    }

    func snapshotCalls() -> [String] {
        lock.withLock { calls }
    }

    func snapshotScheduledBuffers() -> [DecodedPCMBuffer] {
        lock.withLock { scheduledBuffers }
    }
}

private func RecoveryXCTAssertThrowsErrorAsync<T>(
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
