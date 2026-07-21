import XCTest

final class MediaClockSynchronizerTests: XCTestCase {
    func testAudioIsPreferredAndVideoTakesOverWhenAudioIsStale() async throws {
        let clock = try MediaClockSynchronizer()
        _ = try await clock.observeAudio(audioReceipt(timestamp: 0, frames: 240), presentationTimeNanoseconds: 0)
        _ = try await clock.observeVideo(rtpTimestamp: 0, presentationTimeNanoseconds: 0)
        _ = try await clock.observeVideo(rtpTimestamp: 8_100, presentationTimeNanoseconds: 90_000_000)

        let audioMaster = try await clock.snapshot(at: 100_000_000)
        let videoMaster = try await clock.snapshot(at: 100_000_001)

        XCTAssertEqual(audioMaster.master, .audio)
        XCTAssertEqual(videoMaster.master, .video)
    }

    func testAudioClockAdvancesByActualDecodedFramesAfterPriming() async throws {
        let clock = try MediaClockSynchronizer()
        _ = try await clock.observeAudio(audioReceipt(timestamp: 0, frames: 120), presentationTimeNanoseconds: 0)
        let secondAudio = try await clock.observeAudio(
            audioReceipt(timestamp: 240, frames: 120),
            presentationTimeNanoseconds: 2_500_000
        )
        _ = try await clock.observeVideo(rtpTimestamp: 0, presentationTimeNanoseconds: 2_500_000)
        let video = try await clock.observeVideo(
            rtpTimestamp: 225,
            presentationTimeNanoseconds: 5_000_000
        )

        XCTAssertEqual(secondAudio.audioScheduledFrameCount, 240)
        XCTAssertEqual(video.driftNanoseconds, 0)
        XCTAssertEqual(video.lastAction, .none)
    }

    func testVideoAheadIsHeldByBoundedAmount() async throws {
        let clock = try MediaClockSynchronizer(policy: testPolicy())
        _ = try await clock.observeAudio(audioReceipt(timestamp: 0, frames: 480), presentationTimeNanoseconds: 0)
        _ = try await clock.observeVideo(rtpTimestamp: 0, presentationTimeNanoseconds: 0)
        _ = try await clock.observeAudio(
            audioReceipt(timestamp: 480, frames: 480),
            presentationTimeNanoseconds: 20_000_000
        )
        let decision = try await clock.observeVideo(
            rtpTimestamp: 1_800,
            presentationTimeNanoseconds: 20_000_000
        )

        XCTAssertEqual(decision.driftNanoseconds, -10_000_000)
        XCTAssertEqual(decision.lastAction, .holdVideo(nanoseconds: 5_000_000))
    }

    func testVideoBehindDropsAtMostCurrentFrame() async throws {
        let clock = try MediaClockSynchronizer(policy: testPolicy())
        _ = try await clock.observeAudio(audioReceipt(timestamp: 0, frames: 480), presentationTimeNanoseconds: 0)
        _ = try await clock.observeVideo(rtpTimestamp: 0, presentationTimeNanoseconds: 0)
        _ = try await clock.observeAudio(
            audioReceipt(timestamp: 480, frames: 480),
            presentationTimeNanoseconds: 10_000_000
        )
        let decision = try await clock.observeVideo(
            rtpTimestamp: 900,
            presentationTimeNanoseconds: 30_000_000
        )

        XCTAssertEqual(decision.driftNanoseconds, 20_000_000)
        XCTAssertEqual(decision.lastAction, .dropVideoFrame)
    }

    func testHardDriftReanchorsOnlyVideoClock() async throws {
        var policy = testPolicy()
        policy.streamStaleNanoseconds = 1_000_000_000
        let clock = try MediaClockSynchronizer(policy: policy)
        _ = try await clock.observeAudio(audioReceipt(timestamp: 0, frames: 480), presentationTimeNanoseconds: 0)
        _ = try await clock.observeVideo(rtpTimestamp: 0, presentationTimeNanoseconds: 0)
        _ = try await clock.observeAudio(
            audioReceipt(timestamp: 480, frames: 480),
            presentationTimeNanoseconds: 10_000_000
        )
        let decision = try await clock.observeVideo(
            rtpTimestamp: 900,
            presentationTimeNanoseconds: 300_000_000
        )

        XCTAssertEqual(decision.lastAction, .reanchorVideo)
        XCTAssertEqual(decision.driftNanoseconds, 0)
        XCTAssertEqual(decision.audioScheduledFrameCount, 960)
        XCTAssertEqual(decision.videoElapsedTimestampTicks, 0)
    }

    func testExactHardDriftBoundaryReanchors() async throws {
        var policy = testPolicy()
        policy.streamStaleNanoseconds = 1_000_000_000
        let clock = try MediaClockSynchronizer(policy: policy)
        _ = try await clock.observeAudio(audioReceipt(timestamp: 0, frames: 480), presentationTimeNanoseconds: 0)
        _ = try await clock.observeVideo(rtpTimestamp: 0, presentationTimeNanoseconds: 0)
        _ = try await clock.observeAudio(
            audioReceipt(timestamp: 480, frames: 480),
            presentationTimeNanoseconds: 10_000_000
        )

        let decision = try await clock.observeVideo(
            rtpTimestamp: 900,
            presentationTimeNanoseconds: 260_000_000
        )

        XCTAssertEqual(decision.lastAction, .reanchorVideo)
        XCTAssertEqual(decision.driftNanoseconds, 0)
    }

    func testVideoTimestampWrapIsUnwrappedForward() async throws {
        let clock = try MediaClockSynchronizer(policy: testPolicy())
        _ = try await clock.observeVideo(
            rtpTimestamp: UInt32.max - 100,
            presentationTimeNanoseconds: 0
        )
        let wrapped = try await clock.observeVideo(
            rtpTimestamp: 50,
            presentationTimeNanoseconds: 1_677_777
        )

        XCTAssertEqual(wrapped.videoElapsedTimestampTicks, 151)
        XCTAssertEqual(wrapped.master, .video)
        XCTAssertEqual(wrapped.lastAction, .none)
    }

    func testAudioTimestampWrapStillAdvancesByDecodedFrames() async throws {
        let clock = try MediaClockSynchronizer(policy: testPolicy())
        _ = try await clock.observeAudio(
            audioReceipt(timestamp: UInt32.max - 100, frames: 240),
            presentationTimeNanoseconds: 0
        )
        let wrapped = try await clock.observeAudio(
            audioReceipt(timestamp: 50, frames: 240),
            presentationTimeNanoseconds: 5_000_000
        )

        XCTAssertEqual(wrapped.audioScheduledFrameCount, 480)
        XCTAssertEqual(wrapped.master, .audio)
    }

    func testBackwardVideoTimestampDoesNotPartiallyMutateClock() async throws {
        let clock = try MediaClockSynchronizer(policy: testPolicy())
        _ = try await clock.observeVideo(rtpTimestamp: 100, presentationTimeNanoseconds: 0)
        let before = try await clock.snapshot(at: 0)

        await MediaClockXCTAssertThrowsErrorAsync(
            try await clock.observeVideo(rtpTimestamp: 99, presentationTimeNanoseconds: 1)
        ) { error in
            XCTAssertEqual(error as? MediaClockError, .nonForwardVideoTimestamp)
        }
        let after = try await clock.snapshot(at: 1)

        XCTAssertEqual(after.videoElapsedTimestampTicks, before.videoElapsedTimestampTicks)
        XCTAssertEqual(after.master, .video)
    }

    func testInvalidObservationDoesNotPartiallyMutateClock() async throws {
        let clock = try MediaClockSynchronizer(policy: testPolicy())
        _ = try await clock.observeAudio(audioReceipt(timestamp: 100, frames: 240), presentationTimeNanoseconds: 10)
        let before = try await clock.snapshot(at: 10)

        await MediaClockXCTAssertThrowsErrorAsync(
            try await clock.observeAudio(
                audioReceipt(timestamp: 99, frames: 240),
                presentationTimeNanoseconds: 20
            )
        ) { error in
            XCTAssertEqual(error as? MediaClockError, .nonForwardAudioTimestamp)
        }
        let after = try await clock.snapshot(at: 20)

        XCTAssertEqual(after.audioScheduledFrameCount, before.audioScheduledFrameCount)
        XCTAssertEqual(after.videoElapsedTimestampTicks, before.videoElapsedTimestampTicks)
    }

    func testBackwardMonotonicTimeAndInvalidPolicyFailClosed() async throws {
        XCTAssertThrowsError(try MediaClockSynchronizer(policy: MediaClockPolicy(
            driftToleranceNanoseconds: 10,
            maximumVideoHoldNanoseconds: 0,
            hardResynchronizationNanoseconds: 10,
            streamStaleNanoseconds: 0
        ))) { error in
            XCTAssertEqual(error as? MediaClockError, .invalidPolicy)
        }

        let clock = try MediaClockSynchronizer(policy: testPolicy())
        _ = try await clock.observeVideo(rtpTimestamp: 1, presentationTimeNanoseconds: 100)
        await MediaClockXCTAssertThrowsErrorAsync(
            try await clock.observeAudio(
                audioReceipt(timestamp: 1, frames: 240),
                presentationTimeNanoseconds: 99
            )
        ) { error in
            XCTAssertEqual(error as? MediaClockError, .nonMonotonicObservationTime)
        }
    }

    func testResetReturnsClockToUnavailable() async throws {
        let clock = try MediaClockSynchronizer(policy: testPolicy())
        _ = try await clock.observeAudio(audioReceipt(timestamp: 0, frames: 240), presentationTimeNanoseconds: 0)

        await clock.reset()
        let snapshot = try await clock.snapshot(at: 1)

        XCTAssertEqual(snapshot.master, .unavailable)
        XCTAssertNil(snapshot.driftNanoseconds)
        XCTAssertEqual(snapshot.audioScheduledFrameCount, 0)
        XCTAssertEqual(snapshot.videoElapsedTimestampTicks, 0)
    }

    private func audioReceipt(timestamp: UInt32, frames: Int) -> AudioScheduleReceipt {
        AudioScheduleReceipt(
            sequenceNumber: UInt16(truncatingIfNeeded: timestamp),
            rtpTimestamp: timestamp,
            frameCount: frames
        )
    }

    private func testPolicy() -> MediaClockPolicy {
        MediaClockPolicy(
            driftToleranceNanoseconds: 1_000_000,
            maximumVideoHoldNanoseconds: 5_000_000,
            hardResynchronizationNanoseconds: 250_000_000,
            streamStaleNanoseconds: 100_000_000
        )
    }
}

private func MediaClockXCTAssertThrowsErrorAsync<T>(
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
