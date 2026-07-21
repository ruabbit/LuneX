import Foundation

enum MediaClockMaster: String, Equatable, Sendable {
    case unavailable
    case audio
    case video
}

enum MediaResynchronizationAction: Equatable, Sendable {
    case none
    case holdVideo(nanoseconds: UInt64)
    case dropVideoFrame
    case reanchorVideo
}

enum MediaClockError: Error, Equatable, Sendable {
    case invalidPolicy
    case invalidAudioFrameCount
    case nonMonotonicObservationTime
    case nonForwardAudioTimestamp
    case nonForwardVideoTimestamp
    case arithmeticOverflow
}

struct MediaClockPolicy: Equatable, Sendable {
    var driftToleranceNanoseconds: Int64
    var maximumVideoHoldNanoseconds: UInt64
    var hardResynchronizationNanoseconds: Int64
    var streamStaleNanoseconds: UInt64

    static let realtime = MediaClockPolicy(
        driftToleranceNanoseconds: 15_000_000,
        maximumVideoHoldNanoseconds: 10_000_000,
        hardResynchronizationNanoseconds: 250_000_000,
        streamStaleNanoseconds: 100_000_000
    )

    func validate() throws {
        guard driftToleranceNanoseconds >= 0,
              maximumVideoHoldNanoseconds > 0,
              hardResynchronizationNanoseconds > driftToleranceNanoseconds,
              maximumVideoHoldNanoseconds <= UInt64(hardResynchronizationNanoseconds),
              streamStaleNanoseconds > 0 else {
            throw MediaClockError.invalidPolicy
        }
    }
}

struct MediaClockSnapshot: Equatable, Sendable {
    var master: MediaClockMaster
    var driftNanoseconds: Int64?
    var audioScheduledFrameCount: UInt64
    var videoElapsedTimestampTicks: UInt64
    var lastAction: MediaResynchronizationAction
}

actor MediaClockSynchronizer {
    private static let audioTimescale: UInt64 = 48_000
    private static let videoTimescale: UInt64 = 90_000

    private struct AudioState {
        var anchorPresentationTimeNanoseconds: UInt64
        var latestPresentationTimeNanoseconds: UInt64
        var latestMediaFramePosition: UInt64
        var nextMediaFramePosition: UInt64
        var latestRTPTimeStamp: UInt32
    }

    private struct VideoState {
        var anchorPresentationTimeNanoseconds: UInt64
        var latestPresentationTimeNanoseconds: UInt64
        var elapsedTimestampTicks: UInt64
        var latestRTPTimeStamp: UInt32
    }

    private let policy: MediaClockPolicy
    private var audioState: AudioState?
    private var videoState: VideoState?
    private var latestObservationTimeNanoseconds: UInt64?
    private var lastAction: MediaResynchronizationAction = .none

    init(policy: MediaClockPolicy = .realtime) throws {
        try policy.validate()
        self.policy = policy
    }

    func observeAudio(
        _ receipt: AudioScheduleReceipt,
        presentationTimeNanoseconds: UInt64
    ) throws -> MediaClockSnapshot {
        try validateObservationTime(presentationTimeNanoseconds)
        guard (1...AVAudioPCMBufferFactory.maximumFramesPerBuffer).contains(receipt.frameCount),
              let decodedFrames = UInt64(exactly: receipt.frameCount) else {
            throw MediaClockError.invalidAudioFrameCount
        }

        let candidate: AudioState
        if let audioState {
            let timestampDelta = receipt.rtpTimestamp &- audioState.latestRTPTimeStamp
            guard timestampDelta > 0, timestampDelta < UInt32(1 << 31) else {
                throw MediaClockError.nonForwardAudioTimestamp
            }
            let (nextFramePosition, overflow) = audioState.nextMediaFramePosition
                .addingReportingOverflow(decodedFrames)
            guard !overflow else { throw MediaClockError.arithmeticOverflow }
            candidate = AudioState(
                anchorPresentationTimeNanoseconds: audioState.anchorPresentationTimeNanoseconds,
                latestPresentationTimeNanoseconds: presentationTimeNanoseconds,
                latestMediaFramePosition: audioState.nextMediaFramePosition,
                nextMediaFramePosition: nextFramePosition,
                latestRTPTimeStamp: receipt.rtpTimestamp
            )
        } else {
            candidate = AudioState(
                anchorPresentationTimeNanoseconds: presentationTimeNanoseconds,
                latestPresentationTimeNanoseconds: presentationTimeNanoseconds,
                latestMediaFramePosition: 0,
                nextMediaFramePosition: decodedFrames,
                latestRTPTimeStamp: receipt.rtpTimestamp
            )
        }

        _ = try offsetNanoseconds(for: candidate)
        let previousAudioState = audioState
        let previousObservationTime = latestObservationTimeNanoseconds
        let previousAction = lastAction
        audioState = candidate
        latestObservationTimeNanoseconds = presentationTimeNanoseconds
        lastAction = .none
        do {
            return try makeSnapshot(at: presentationTimeNanoseconds, action: .none)
        } catch {
            audioState = previousAudioState
            latestObservationTimeNanoseconds = previousObservationTime
            lastAction = previousAction
            throw error
        }
    }

    func observeVideo(
        rtpTimestamp: UInt32,
        presentationTimeNanoseconds: UInt64
    ) throws -> MediaClockSnapshot {
        try validateObservationTime(presentationTimeNanoseconds)

        let candidate: VideoState
        if let videoState {
            let timestampDelta = rtpTimestamp &- videoState.latestRTPTimeStamp
            guard timestampDelta > 0, timestampDelta < UInt32(1 << 31) else {
                throw MediaClockError.nonForwardVideoTimestamp
            }
            let (elapsedTicks, overflow) = videoState.elapsedTimestampTicks
                .addingReportingOverflow(UInt64(timestampDelta))
            guard !overflow else { throw MediaClockError.arithmeticOverflow }
            candidate = VideoState(
                anchorPresentationTimeNanoseconds: videoState.anchorPresentationTimeNanoseconds,
                latestPresentationTimeNanoseconds: presentationTimeNanoseconds,
                elapsedTimestampTicks: elapsedTicks,
                latestRTPTimeStamp: rtpTimestamp
            )
        } else {
            candidate = VideoState(
                anchorPresentationTimeNanoseconds: presentationTimeNanoseconds,
                latestPresentationTimeNanoseconds: presentationTimeNanoseconds,
                elapsedTimestampTicks: 0,
                latestRTPTimeStamp: rtpTimestamp
            )
        }

        _ = try offsetNanoseconds(for: candidate)
        let previousVideoState = videoState
        let previousObservationTime = latestObservationTimeNanoseconds
        let previousAction = lastAction
        videoState = candidate
        latestObservationTimeNanoseconds = presentationTimeNanoseconds
        do {
            return try decideVideoCorrection(at: presentationTimeNanoseconds)
        } catch {
            videoState = previousVideoState
            latestObservationTimeNanoseconds = previousObservationTime
            lastAction = previousAction
            throw error
        }
    }

    func snapshot(at nowNanoseconds: UInt64) throws -> MediaClockSnapshot {
        try validateQueryTime(nowNanoseconds)
        return try makeSnapshot(at: nowNanoseconds, action: lastAction)
    }

    func reset() {
        audioState = nil
        videoState = nil
        latestObservationTimeNanoseconds = nil
        lastAction = .none
    }

    private func decideVideoCorrection(at nowNanoseconds: UInt64) throws -> MediaClockSnapshot {
        let master = selectedMaster(at: nowNanoseconds)
        guard master == .audio,
              let drift = try currentDriftNanoseconds() else {
            lastAction = .none
            return try makeSnapshot(at: nowNanoseconds, action: .none)
        }

        let action: MediaResynchronizationAction
        if drift >= policy.hardResynchronizationNanoseconds
            || drift <= -policy.hardResynchronizationNanoseconds {
            guard let videoState else { throw MediaClockError.arithmeticOverflow }
            self.videoState = VideoState(
                anchorPresentationTimeNanoseconds: videoState.latestPresentationTimeNanoseconds,
                latestPresentationTimeNanoseconds: videoState.latestPresentationTimeNanoseconds,
                elapsedTimestampTicks: 0,
                latestRTPTimeStamp: videoState.latestRTPTimeStamp
            )
            action = .reanchorVideo
        } else if drift > policy.driftToleranceNanoseconds {
            action = .dropVideoFrame
        } else if drift < -policy.driftToleranceNanoseconds {
            let requiredHold = UInt64(-drift)
            action = .holdVideo(
                nanoseconds: min(requiredHold, policy.maximumVideoHoldNanoseconds)
            )
        } else {
            action = .none
        }
        lastAction = action
        return try makeSnapshot(at: nowNanoseconds, action: action)
    }

    private func makeSnapshot(
        at nowNanoseconds: UInt64,
        action: MediaResynchronizationAction
    ) throws -> MediaClockSnapshot {
        MediaClockSnapshot(
            master: selectedMaster(at: nowNanoseconds),
            driftNanoseconds: try currentDriftNanoseconds(),
            audioScheduledFrameCount: audioState?.nextMediaFramePosition ?? 0,
            videoElapsedTimestampTicks: videoState?.elapsedTimestampTicks ?? 0,
            lastAction: action
        )
    }

    private func selectedMaster(at nowNanoseconds: UInt64) -> MediaClockMaster {
        if let audioState,
           nowNanoseconds >= audioState.latestPresentationTimeNanoseconds,
           nowNanoseconds - audioState.latestPresentationTimeNanoseconds
               <= policy.streamStaleNanoseconds {
            return .audio
        }
        if let videoState,
           nowNanoseconds >= videoState.latestPresentationTimeNanoseconds,
           nowNanoseconds - videoState.latestPresentationTimeNanoseconds
               <= policy.streamStaleNanoseconds {
            return .video
        }
        return .unavailable
    }

    private func currentDriftNanoseconds() throws -> Int64? {
        guard let audioState, let videoState else { return nil }
        let audioOffset = try offsetNanoseconds(for: audioState)
        let videoOffset = try offsetNanoseconds(for: videoState)
        let (drift, overflow) = videoOffset.subtractingReportingOverflow(audioOffset)
        guard !overflow else { throw MediaClockError.arithmeticOverflow }
        return drift
    }

    private func offsetNanoseconds(for state: AudioState) throws -> Int64 {
        let localElapsed = state.latestPresentationTimeNanoseconds
            - state.anchorPresentationTimeNanoseconds
        let mediaElapsed = try nanoseconds(
            forTicks: state.latestMediaFramePosition,
            timescale: Self.audioTimescale
        )
        return try signedDifference(localElapsed, mediaElapsed)
    }

    private func offsetNanoseconds(for state: VideoState) throws -> Int64 {
        let localElapsed = state.latestPresentationTimeNanoseconds
            - state.anchorPresentationTimeNanoseconds
        let mediaElapsed = try nanoseconds(
            forTicks: state.elapsedTimestampTicks,
            timescale: Self.videoTimescale
        )
        return try signedDifference(localElapsed, mediaElapsed)
    }

    private func nanoseconds(forTicks ticks: UInt64, timescale: UInt64) throws -> UInt64 {
        let wholeSeconds = ticks / timescale
        let remainingTicks = ticks % timescale
        let (wholeNanoseconds, wholeOverflow) = wholeSeconds
            .multipliedReportingOverflow(by: 1_000_000_000)
        let (partialProduct, partialOverflow) = remainingTicks
            .multipliedReportingOverflow(by: 1_000_000_000)
        guard !wholeOverflow, !partialOverflow else {
            throw MediaClockError.arithmeticOverflow
        }
        let partialNanoseconds = partialProduct / timescale
        let (total, totalOverflow) = wholeNanoseconds
            .addingReportingOverflow(partialNanoseconds)
        guard !totalOverflow else { throw MediaClockError.arithmeticOverflow }
        return total
    }

    private func signedDifference(_ lhs: UInt64, _ rhs: UInt64) throws -> Int64 {
        guard let signedLHS = Int64(exactly: lhs),
              let signedRHS = Int64(exactly: rhs) else {
            throw MediaClockError.arithmeticOverflow
        }
        let (difference, overflow) = signedLHS.subtractingReportingOverflow(signedRHS)
        guard !overflow else { throw MediaClockError.arithmeticOverflow }
        return difference
    }

    private func validateObservationTime(_ timeNanoseconds: UInt64) throws {
        if let latestObservationTimeNanoseconds,
           timeNanoseconds < latestObservationTimeNanoseconds {
            throw MediaClockError.nonMonotonicObservationTime
        }
    }

    private func validateQueryTime(_ timeNanoseconds: UInt64) throws {
        if let latestObservationTimeNanoseconds,
           timeNanoseconds < latestObservationTimeNanoseconds {
            throw MediaClockError.nonMonotonicObservationTime
        }
    }
}
