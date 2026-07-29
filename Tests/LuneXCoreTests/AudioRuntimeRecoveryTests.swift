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
        XCTAssertEqual(
            harness.client.snapshotGraphIntents(),
            [harness.graphIntent, harness.graphIntent]
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

    func testInterruptedRouteAndPolicyRecoveryPreservesConcealmentAndRejectsLateCompletion()
        async throws
    {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 0)
        let concealed = try await harness.runtime.handle(
            .packetLoss(
                firstSequenceNumber: 1,
                firstRTPTimeStamp: 1,
                packetCount: 1,
                samplesPerPacket: 240
            ),
            at: 1
        )
        XCTAssertEqual(concealed.concealedFrameCount, 240)
        let scheduledBeforeInterruption = await harness.pipeline.scheduledBufferCount()
        XCTAssertEqual(scheduledBeforeInterruption, 1)

        _ = try await harness.runtime.handle(.interruptionBegan, at: 2)
        let revisedIntent = makeAudioGraphIntent(
            channelCount: 2,
            revision: .init(rawValue: 2),
            userEnablesSpatialAudio: true,
            userEnablesHeadTracking: true
        )
        let deferredPolicy = try await harness.runtime.applySpatialPolicy(
            revisedIntent,
            at: 3
        )
        let deferredRoute = try await harness.runtime.handle(
            .routeChanged,
            at: 4
        )
        let resumed = try await harness.runtime.handle(
            .interruptionEnded(shouldResume: true),
            at: 5
        )

        harness.client.completeAllSchedules()
        await Task.yield()
        await Task.yield()
        let settled = try await harness.runtime.snapshot(at: 6)

        XCTAssertEqual(
            deferredPolicy.lastAction,
            .spatialPolicyDeferred(revisedIntent.revision)
        )
        XCTAssertEqual(deferredRoute.lastAction, .routeChangeDeferred)
        XCTAssertEqual(resumed.lastAction, .interruptionResumed)
        XCTAssertEqual(resumed.pipeline.spatialRuntime?.revision, revisedIntent.revision)
        XCTAssertEqual(resumed.concealedFrameCount, 240)
        XCTAssertEqual(settled.concealedFrameCount, 240)
        let scheduledAfterLateCompletion = await harness.pipeline.scheduledBufferCount()
        XCTAssertEqual(scheduledAfterLateCompletion, 0)
        XCTAssertEqual(
            harness.client.snapshotGraphIntents(),
            [harness.graphIntent, revisedIntent]
        )
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

    func testNewSpatialPolicyRevisionRebuildsExactlyOnceWithExactIntent() async throws {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 0)
        let revisedIntent = makeAudioGraphIntent(
            channelCount: 2,
            revision: .init(rawValue: 2),
            userEnablesSpatialAudio: true
        )

        let rebuilt = try await harness.runtime.applySpatialPolicy(
            revisedIntent,
            at: 1
        )

        XCTAssertEqual(rebuilt.stage, .running)
        XCTAssertEqual(rebuilt.lastAction, .graphRebuilt(.spatialPolicyChanged))
        XCTAssertEqual(rebuilt.pipeline.spatialRuntime?.revision, revisedIntent.revision)
        XCTAssertEqual(
            harness.client.snapshotGraphIntents(),
            [harness.graphIntent, revisedIntent]
        )
    }

    func testEquivalentSpatialPolicyIsBoundedAndInvalidRevisionsAreRejected() async throws {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 0)

        let unchanged = try await harness.runtime.applySpatialPolicy(
            harness.graphIntent,
            at: 1
        )

        XCTAssertEqual(
            unchanged.lastAction,
            .spatialPolicyUnchanged(harness.graphIntent.revision)
        )
        XCTAssertEqual(harness.client.snapshotGraphIntents(), [harness.graphIntent])

        let staleIntent = makeAudioGraphIntent(
            channelCount: 2,
            revision: .init(rawValue: 0)
        )
        await RecoveryXCTAssertThrowsErrorAsync(
            try await harness.runtime.applySpatialPolicy(staleIntent, at: 2)
        ) { error in
            XCTAssertEqual(
                error as? AudioRuntimeRecoveryError,
                .staleSpatialPolicyRevision(
                    current: harness.graphIntent.revision,
                    incoming: staleIntent.revision
                )
            )
        }

        let conflictingIntent = makeAudioGraphIntent(
            channelCount: 2,
            revision: harness.graphIntent.revision,
            userEnablesSpatialAudio: true
        )
        await RecoveryXCTAssertThrowsErrorAsync(
            try await harness.runtime.applySpatialPolicy(conflictingIntent, at: 2)
        ) { error in
            XCTAssertEqual(
                error as? AudioRuntimeRecoveryError,
                .conflictingSpatialPolicyRevision(harness.graphIntent.revision)
            )
        }

        let wrongPlatform = makeAudioGraphIntent(
            channelCount: 2,
            revision: .init(rawValue: 2),
            platform: .iOS
        )
        await RecoveryXCTAssertThrowsErrorAsync(
            try await harness.runtime.applySpatialPolicy(wrongPlatform, at: 2)
        ) { error in
            XCTAssertEqual(error as? AudioRuntimeRecoveryError, .invalidGraphIntent)
        }

        let inconsistentIntent = SpatialAudioGraphIntent(
            revision: .init(rawValue: 2),
            platform: harness.graphIntent.platform,
            route: harness.graphIntent.route,
            entitlement: harness.graphIntent.entitlement,
            userEnablesSpatialAudio: true,
            userEnablesHeadTracking: false
        )
        await RecoveryXCTAssertThrowsErrorAsync(
            try await harness.runtime.applySpatialPolicy(inconsistentIntent, at: 2)
        ) { error in
            XCTAssertEqual(error as? AudioRuntimeRecoveryError, .invalidGraphIntent)
        }
        XCTAssertEqual(harness.client.snapshotGraphIntents(), [harness.graphIntent])
    }

    func testInterruptedRuntimeDefersAndResumesOnlyLatestSpatialPolicy() async throws {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 0)
        _ = try await harness.runtime.handle(.interruptionBegan, at: 1)
        let revisionTwo = makeAudioGraphIntent(
            channelCount: 2,
            revision: .init(rawValue: 2),
            userEnablesSpatialAudio: true
        )
        let revisionThree = makeAudioGraphIntent(
            channelCount: 2,
            revision: .init(rawValue: 3),
            userEnablesSpatialAudio: true,
            userEnablesHeadTracking: true
        )

        let firstDeferred = try await harness.runtime.applySpatialPolicy(
            revisionTwo,
            at: 2
        )
        let latestDeferred = try await harness.runtime.applySpatialPolicy(
            revisionThree,
            at: 3
        )

        XCTAssertEqual(
            firstDeferred.lastAction,
            .spatialPolicyDeferred(revisionTwo.revision)
        )
        XCTAssertEqual(
            latestDeferred.lastAction,
            .spatialPolicyDeferred(revisionThree.revision)
        )
        XCTAssertEqual(harness.client.snapshotGraphIntents(), [harness.graphIntent])

        let resumed = try await harness.runtime.handle(
            .interruptionEnded(shouldResume: true),
            at: 4
        )

        XCTAssertEqual(resumed.lastAction, .interruptionResumed)
        XCTAssertEqual(resumed.pipeline.spatialRuntime?.revision, revisionThree.revision)
        XCTAssertEqual(
            harness.client.snapshotGraphIntents(),
            [harness.graphIntent, revisionThree]
        )
    }

    func testSpatialPolicyRebuildPreservesConcealmentAndRejectsLateCompletion() async throws {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 0)
        let concealed = try await harness.runtime.handle(
            .packetLoss(
                firstSequenceNumber: 1,
                firstRTPTimeStamp: 1,
                packetCount: 1,
                samplesPerPacket: 240
            ),
            at: 1
        )
        XCTAssertEqual(concealed.concealedFrameCount, 240)
        let scheduledBeforeRebuild = await harness.pipeline.scheduledBufferCount()
        XCTAssertEqual(scheduledBeforeRebuild, 1)
        let revisedIntent = makeAudioGraphIntent(
            channelCount: 2,
            revision: .init(rawValue: 2),
            userEnablesSpatialAudio: true
        )

        let rebuilt = try await harness.runtime.applySpatialPolicy(
            revisedIntent,
            at: 2
        )
        harness.client.completeAllSchedules()
        await Task.yield()
        await Task.yield()

        XCTAssertEqual(rebuilt.concealedFrameCount, 240)
        XCTAssertEqual(rebuilt.clock.master, .unavailable)
        let scheduledAfterLateCompletion = await harness.pipeline.scheduledBufferCount()
        XCTAssertEqual(scheduledAfterLateCompletion, 0)
    }

    func testSpatialPolicyGraphFailureCleansResourcesAndFailsClosed() async throws {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 0)
        harness.client.failNextConfigure()
        let revisedIntent = makeAudioGraphIntent(
            channelCount: 2,
            revision: .init(rawValue: 2),
            userEnablesSpatialAudio: true
        )

        await RecoveryXCTAssertThrowsErrorAsync(
            try await harness.runtime.applySpatialPolicy(revisedIntent, at: 1)
        ) { error in
            XCTAssertEqual(
                error as? AudioRuntimeRecoveryError,
                .graphFailed("invalidConfiguration")
            )
        }
        let failed = try await harness.runtime.snapshot(at: 2)

        XCTAssertEqual(failed.stage, .failed)
        XCTAssertEqual(failed.pipeline.stage, .failed)
        XCTAssertEqual(failed.clock.master, .unavailable)
        XCTAssertTrue(harness.client.snapshotScheduledBuffers().isEmpty)
    }

    func testInFlightSpatialPolicyRebuildSerializesScheduleSnapshotAndStop() async throws {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 0)
        harness.client.blockNextConfigure()
        let revisedIntent = makeAudioGraphIntent(
            channelCount: 2,
            revision: .init(rawValue: 2),
            userEnablesSpatialAudio: true
        )
        let policyTask = Task {
            try await harness.runtime.applySpatialPolicy(revisedIntent, at: 1)
        }
        XCTAssertTrue(harness.client.waitUntilConfigureIsBlocked())
        let probe = RecoveryOperationProbe()
        let scheduledPCM = pcm(sequence: 9, timestamp: 0)
        let scheduleTask = Task {
            do {
                let receipt = try await harness.runtime.schedule(
                    scheduledPCM,
                    presentationTimeNanoseconds: 2
                )
                await probe.markScheduleFinished()
                return receipt
            } catch {
                await probe.markScheduleFinished()
                throw error
            }
        }
        await Task.yield()
        let snapshotTask = Task {
            do {
                let snapshot = try await harness.runtime.snapshot(at: 2)
                await probe.markSnapshotFinished()
                return snapshot
            } catch {
                await probe.markSnapshotFinished()
                throw error
            }
        }
        await Task.yield()
        let stopTask = Task {
            do {
                let snapshot = try await harness.runtime.stop(at: 2)
                await probe.markStopFinished()
                return snapshot
            } catch {
                await probe.markStopFinished()
                throw error
            }
        }
        try await Task.sleep(nanoseconds: 50_000_000)

        let blockedOperations = await probe.snapshot()
        XCTAssertEqual(
            blockedOperations,
            RecoveryOperationProbe.Snapshot(
                scheduleFinished: false,
                snapshotFinished: false,
                stopFinished: false
            )
        )
        XCTAssertFalse(
            harness.client.snapshotCalls().contains("schedule:9")
        )

        harness.client.releaseBlockedConfigure()
        let policySnapshot = try await policyTask.value
        _ = try? await scheduleTask.value
        let observedSnapshot = try await snapshotTask.value
        let stopped = try await stopTask.value

        XCTAssertEqual(
            policySnapshot.pipeline.spatialRuntime?.revision,
            revisedIntent.revision
        )
        XCTAssertNotEqual(observedSnapshot.pipeline.stage, .configured)
        XCTAssertEqual(stopped.stage, .stopped)
        let finishedOperations = await probe.snapshot()
        XCTAssertEqual(
            finishedOperations,
            RecoveryOperationProbe.Snapshot(
                scheduleFinished: true,
                snapshotFinished: true,
                stopFinished: true
            )
        )
    }

    func testCancelledOperationWaitingForSpatialRebuildDoesNotSchedule() async throws {
        let harness = try makeHarness()
        _ = try await harness.runtime.start(at: 0)
        harness.client.blockNextConfigure()
        let revisedIntent = makeAudioGraphIntent(
            channelCount: 2,
            revision: .init(rawValue: 2),
            userEnablesSpatialAudio: true
        )
        let policyTask = Task {
            try await harness.runtime.applySpatialPolicy(revisedIntent, at: 1)
        }
        XCTAssertTrue(harness.client.waitUntilConfigureIsBlocked())
        let scheduledPCM = pcm(sequence: 10, timestamp: 0)
        let scheduleTask = Task {
            try await harness.runtime.schedule(
                scheduledPCM,
                presentationTimeNanoseconds: 2
            )
        }
        await Task.yield()
        scheduleTask.cancel()

        harness.client.releaseBlockedConfigure()
        _ = try await policyTask.value
        await RecoveryXCTAssertThrowsErrorAsync(
            try await scheduleTask.value
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }
        XCTAssertFalse(
            harness.client.snapshotCalls().contains("schedule:10")
        )
    }

    private func makeHarness() throws -> RecoveryHarness {
        let client = RecoveryAudioEngineClient()
        let pipeline = AudioSessionPipeline(engineClient: client)
        let clock = try MediaClockSynchronizer()
        let graphIntent = makeAudioGraphIntent(channelCount: 2)
        let runtime = try SessionAudioRuntime(
            pipeline: pipeline,
            clock: clock,
            configuration: .stereoLowLatency,
            graphIntent: graphIntent
        )
        return RecoveryHarness(
            runtime: runtime,
            pipeline: pipeline,
            client: client,
            graphIntent: graphIntent
        )
    }

    private func pcm(sequence: UInt16, timestamp: UInt32) -> DecodedPCMBuffer {
        DecodedPCMBuffer(
            sequenceNumber: sequence,
            rtpTimestamp: timestamp,
            format: .signedInt16(
                sampleRate: 48_000,
                channelLayout: .stereo
            ),
            frameCount: 240,
            interleavedSamples: [Int16](repeating: 1, count: 480)
        )
    }
}

private struct RecoveryHarness {
    var runtime: SessionAudioRuntime
    var pipeline: AudioSessionPipeline
    var client: RecoveryAudioEngineClient
    var graphIntent: SpatialAudioGraphIntent
}

private actor RecoveryOperationProbe {
    struct Snapshot: Equatable {
        let scheduleFinished: Bool
        let snapshotFinished: Bool
        let stopFinished: Bool
    }

    private var scheduleFinished = false
    private var snapshotFinished = false
    private var stopFinished = false

    func markScheduleFinished() {
        scheduleFinished = true
    }

    func markSnapshotFinished() {
        snapshotFinished = true
    }

    func markStopFinished() {
        stopFinished = true
    }

    func snapshot() -> Snapshot {
        Snapshot(
            scheduleFinished: scheduleFinished,
            snapshotFinished: snapshotFinished,
            stopFinished: stopFinished
        )
    }
}

private final class RecoveryAudioEngineClient: AudioEngineClient, @unchecked Sendable {
    private let lock = NSLock()
    private let blockedConfigureEntered = DispatchSemaphore(value: 0)
    private let blockedConfigureRelease = DispatchSemaphore(value: 0)
    private var calls: [String] = []
    private var scheduledBuffers: [DecodedPCMBuffer] = []
    private var scheduleCompletions: [@Sendable () -> Void] = []
    private var scheduleCallCount = 0
    private var failingScheduleCall: Int?
    private var shouldFailNextConfigure = false
    private var shouldBlockNextConfigure = false
    private var graphIntents: [SpatialAudioGraphIntent] = []

    func configure(
        _ configuration: StreamAudioConfiguration,
        graphIntent: SpatialAudioGraphIntent
    ) throws -> SpatialAudioRuntimeSnapshot {
        lock.withLock {
            calls.append("configure")
            graphIntents.append(graphIntent)
        }
        let shouldFail = lock.withLock { () -> Bool in
            defer { shouldFailNextConfigure = false }
            return shouldFailNextConfigure
        }
        let shouldBlock = lock.withLock { () -> Bool in
            defer { shouldBlockNextConfigure = false }
            return shouldBlockNextConfigure
        }
        if shouldBlock {
            blockedConfigureEntered.signal()
            blockedConfigureRelease.wait()
        }
        if shouldFail { throw AudioPipelineError.invalidConfiguration }
        return makeNonspatialRuntime(
            configuration: configuration,
            graphIntent: graphIntent
        )
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
        lock.withLock {
            scheduledBuffers.append(buffer)
            scheduleCompletions.append(completion)
        }
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

    func blockNextConfigure() {
        lock.withLock { shouldBlockNextConfigure = true }
    }

    func waitUntilConfigureIsBlocked() -> Bool {
        blockedConfigureEntered.wait(timeout: .now() + 2) == .success
    }

    func releaseBlockedConfigure() {
        blockedConfigureRelease.signal()
    }

    func failScheduleCall(_ call: Int) {
        lock.withLock { failingScheduleCall = call }
    }

    func completeAllSchedules() {
        let completions = lock.withLock { () -> [@Sendable () -> Void] in
            defer { scheduleCompletions.removeAll() }
            return scheduleCompletions
        }
        completions.forEach { $0() }
    }

    func snapshotCalls() -> [String] {
        lock.withLock { calls }
    }

    func snapshotScheduledBuffers() -> [DecodedPCMBuffer] {
        lock.withLock { scheduledBuffers }
    }

    func snapshotGraphIntents() -> [SpatialAudioGraphIntent] {
        lock.withLock { graphIntents }
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
