import Foundation

enum SessionAudioRuntimeStage: String, Equatable, Sendable {
    case idle
    case running
    case interrupted
    case stopped
    case failed
}

enum AudioGraphRebuildReason: String, Equatable, Sendable {
    case routeChanged
    case underrun
    case packetLossExceeded
    case concealmentFailed
}

enum AudioRuntimeRecoveryAction: Equatable, Sendable {
    case none
    case routeChangeDeferred
    case interruptionPaused
    case interruptionResumeDeferred
    case interruptionResumed
    case silenceScheduled(packetCount: Int, frameCount: Int)
    case graphRebuilt(AudioGraphRebuildReason)
    case stopped
}

enum AudioRuntimeDiscontinuity: Equatable, Sendable {
    case routeChanged
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    case underrun
    case packetLoss(
        firstSequenceNumber: UInt16,
        firstRTPTimeStamp: UInt32,
        packetCount: Int,
        samplesPerPacket: Int
    )
}

enum AudioRuntimeRecoveryError: Error, Equatable, Sendable {
    case invalidPolicy
    case invalidState
    case stopped
    case nonMonotonicEventTime
    case graphFailed(String)
    case arithmeticOverflow
}

struct AudioRuntimeRecoveryPolicy: Equatable, Sendable {
    var maximumConcealedPackets: Int
    var maximumConcealedFrames: Int

    static let realtime = AudioRuntimeRecoveryPolicy(
        maximumConcealedPackets: 4,
        maximumConcealedFrames: 960
    )

    func validate() throws {
        guard (1...16).contains(maximumConcealedPackets),
              (1...AVAudioPCMBufferFactory.maximumFramesPerBuffer)
                .contains(maximumConcealedFrames) else {
            throw AudioRuntimeRecoveryError.invalidPolicy
        }
    }
}

struct SessionAudioRuntimeSnapshot: Equatable, Sendable {
    var stage: SessionAudioRuntimeStage
    var pipeline: AudioPipelineSnapshot
    var clock: MediaClockSnapshot
    var concealedFrameCount: UInt64
    var lastAction: AudioRuntimeRecoveryAction
}

actor SessionAudioRuntime {
    private let pipeline: AudioSessionPipeline
    private let clock: MediaClockSynchronizer
    private let configuration: StreamAudioConfiguration
    private let policy: AudioRuntimeRecoveryPolicy
    private var stage: SessionAudioRuntimeStage = .idle
    private var concealedFrameCount: UInt64 = 0
    private var lastAction: AudioRuntimeRecoveryAction = .none
    private var latestEventTimeNanoseconds: UInt64?

    init(
        pipeline: AudioSessionPipeline = AudioSessionPipeline(),
        clock: MediaClockSynchronizer,
        configuration: StreamAudioConfiguration,
        policy: AudioRuntimeRecoveryPolicy = .realtime
    ) throws {
        try configuration.validate()
        try policy.validate()
        self.pipeline = pipeline
        self.clock = clock
        self.configuration = configuration
        self.policy = policy
    }

    func start(at timeNanoseconds: UInt64) async throws -> SessionAudioRuntimeSnapshot {
        guard stage == .idle || stage == .stopped else {
            throw AudioRuntimeRecoveryError.invalidState
        }
        try validateEventTime(timeNanoseconds)
        await clock.reset()
        let configured = try await pipeline.configure(configuration)
        guard configured.stage == .configured else {
            return try await failGraph(configured.lastErrorMessage, at: timeNanoseconds)
        }
        let running = try await pipeline.start()
        guard running.stage == .running else {
            return try await failGraph(running.lastErrorMessage, at: timeNanoseconds)
        }
        stage = .running
        concealedFrameCount = 0
        lastAction = .none
        latestEventTimeNanoseconds = timeNanoseconds
        return try await makeSnapshot(at: timeNanoseconds)
    }

    func schedule(
        _ decoded: DecodedPCMBuffer,
        presentationTimeNanoseconds: UInt64
    ) async throws -> AudioScheduleReceipt {
        guard stage == .running else {
            if stage == .stopped { throw AudioRuntimeRecoveryError.stopped }
            throw AudioRuntimeRecoveryError.invalidState
        }
        try validateEventTime(presentationTimeNanoseconds)
        let receipt = try await pipeline.schedule(decoded)
        do {
            _ = try await clock.observeAudio(
                receipt,
                presentationTimeNanoseconds: presentationTimeNanoseconds
            )
        } catch {
            _ = try await rebuildGraph(
                reason: .concealmentFailed,
                at: presentationTimeNanoseconds
            )
            throw error
        }
        latestEventTimeNanoseconds = presentationTimeNanoseconds
        return receipt
    }

    func handle(
        _ event: AudioRuntimeDiscontinuity,
        at timeNanoseconds: UInt64
    ) async throws -> SessionAudioRuntimeSnapshot {
        guard stage != .stopped else { throw AudioRuntimeRecoveryError.stopped }
        guard stage != .failed else { throw AudioRuntimeRecoveryError.invalidState }
        try validateEventTime(timeNanoseconds)

        switch event {
        case .routeChanged:
            if stage == .interrupted {
                lastAction = .routeChangeDeferred
                latestEventTimeNanoseconds = timeNanoseconds
                return try await makeSnapshot(at: timeNanoseconds)
            }
            guard stage == .running else { throw AudioRuntimeRecoveryError.invalidState }
            return try await rebuildGraph(reason: .routeChanged, at: timeNanoseconds)

        case .interruptionBegan:
            if stage == .interrupted {
                lastAction = .interruptionPaused
                latestEventTimeNanoseconds = timeNanoseconds
                return try await makeSnapshot(at: timeNanoseconds)
            }
            guard stage == .running else { throw AudioRuntimeRecoveryError.invalidState }
            _ = await pipeline.stop(reason: .interruption, drain: false)
            await clock.reset()
            stage = .interrupted
            lastAction = .interruptionPaused
            latestEventTimeNanoseconds = timeNanoseconds
            return try await makeSnapshot(at: timeNanoseconds)

        case let .interruptionEnded(shouldResume):
            guard stage == .interrupted else { throw AudioRuntimeRecoveryError.invalidState }
            guard shouldResume else {
                lastAction = .interruptionResumeDeferred
                latestEventTimeNanoseconds = timeNanoseconds
                return try await makeSnapshot(at: timeNanoseconds)
            }
            let resumed = try await rebuildGraph(
                reason: nil,
                at: timeNanoseconds
            )
            lastAction = .interruptionResumed
            return SessionAudioRuntimeSnapshot(
                stage: resumed.stage,
                pipeline: resumed.pipeline,
                clock: resumed.clock,
                concealedFrameCount: resumed.concealedFrameCount,
                lastAction: .interruptionResumed
            )

        case .underrun:
            guard stage == .running else { throw AudioRuntimeRecoveryError.invalidState }
            return try await rebuildGraph(reason: .underrun, at: timeNanoseconds)

        case let .packetLoss(
            firstSequenceNumber,
            firstRTPTimeStamp,
            packetCount,
            samplesPerPacket
        ):
            guard stage == .running else { throw AudioRuntimeRecoveryError.invalidState }
            return try await concealOrResynchronize(
                firstSequenceNumber: firstSequenceNumber,
                firstRTPTimeStamp: firstRTPTimeStamp,
                packetCount: packetCount,
                samplesPerPacket: samplesPerPacket,
                at: timeNanoseconds
            )
        }
    }

    func stop(at timeNanoseconds: UInt64) async throws -> SessionAudioRuntimeSnapshot {
        try validateEventTime(timeNanoseconds)
        if stage != .stopped {
            _ = await pipeline.stop(reason: .sessionEnded, drain: false)
            await clock.reset()
            stage = .stopped
            lastAction = .stopped
        }
        latestEventTimeNanoseconds = timeNanoseconds
        return try await makeSnapshot(at: timeNanoseconds)
    }

    func snapshot(at timeNanoseconds: UInt64) async throws -> SessionAudioRuntimeSnapshot {
        try validateEventTime(timeNanoseconds)
        return try await makeSnapshot(at: timeNanoseconds)
    }

    private func concealOrResynchronize(
        firstSequenceNumber: UInt16,
        firstRTPTimeStamp: UInt32,
        packetCount: Int,
        samplesPerPacket: Int,
        at timeNanoseconds: UInt64
    ) async throws -> SessionAudioRuntimeSnapshot {
        let (totalFrames, frameOverflow) = packetCount
            .multipliedReportingOverflow(by: samplesPerPacket)
        guard packetCount > 0,
              samplesPerPacket > 0,
              samplesPerPacket <= AVAudioPCMBufferFactory.maximumFramesPerBuffer,
              !frameOverflow,
              packetCount <= policy.maximumConcealedPackets,
              totalFrames <= policy.maximumConcealedFrames else {
            return try await rebuildGraph(
                reason: .packetLossExceeded,
                at: timeNanoseconds
            )
        }

        do {
            for index in 0..<packetCount {
                let frameOffset = index * samplesPerPacket
                let presentationOffset = try durationNanoseconds(frames: frameOffset)
                let (presentationTime, timeOverflow) = timeNanoseconds
                    .addingReportingOverflow(presentationOffset)
                guard !timeOverflow else { throw AudioRuntimeRecoveryError.arithmeticOverflow }
                let timestampOffset = UInt32(frameOffset)
                let silence = DecodedPCMBuffer(
                    sequenceNumber: firstSequenceNumber &+ UInt16(index),
                    rtpTimestamp: firstRTPTimeStamp &+ timestampOffset,
                    format: .signedInt16(
                        sampleRate: Int(configuration.sampleRate),
                        channelCount: configuration.channelCount
                    ),
                    frameCount: samplesPerPacket,
                    interleavedSamples: [Int16](
                        repeating: 0,
                        count: samplesPerPacket * configuration.channelCount
                    )
                )
                let receipt = try await pipeline.schedule(silence)
                _ = try await clock.observeAudio(
                    receipt,
                    presentationTimeNanoseconds: presentationTime
                )
                latestEventTimeNanoseconds = presentationTime
            }
        } catch {
            return try await rebuildGraph(
                reason: .concealmentFailed,
                at: max(timeNanoseconds, latestEventTimeNanoseconds ?? timeNanoseconds)
            )
        }

        let (newConcealedFrameCount, countOverflow) = concealedFrameCount
            .addingReportingOverflow(UInt64(totalFrames))
        guard !countOverflow else {
            return try await rebuildGraph(
                reason: .concealmentFailed,
                at: latestEventTimeNanoseconds ?? timeNanoseconds
            )
        }
        concealedFrameCount = newConcealedFrameCount
        lastAction = .silenceScheduled(
            packetCount: packetCount,
            frameCount: totalFrames
        )
        return try await makeSnapshot(
            at: latestEventTimeNanoseconds ?? timeNanoseconds
        )
    }

    private func rebuildGraph(
        reason: AudioGraphRebuildReason?,
        at timeNanoseconds: UInt64
    ) async throws -> SessionAudioRuntimeSnapshot {
        await clock.reset()
        let configured = try await pipeline.configure(configuration)
        guard configured.stage == .configured else {
            return try await failGraph(configured.lastErrorMessage, at: timeNanoseconds)
        }
        let running = try await pipeline.start()
        guard running.stage == .running else {
            return try await failGraph(running.lastErrorMessage, at: timeNanoseconds)
        }
        stage = .running
        latestEventTimeNanoseconds = timeNanoseconds
        lastAction = reason.map(AudioRuntimeRecoveryAction.graphRebuilt) ?? .none
        return try await makeSnapshot(at: timeNanoseconds)
    }

    private func failGraph(
        _ message: String?,
        at timeNanoseconds: UInt64
    ) async throws -> SessionAudioRuntimeSnapshot {
        await clock.reset()
        stage = .failed
        latestEventTimeNanoseconds = timeNanoseconds
        throw AudioRuntimeRecoveryError.graphFailed(message ?? "Unknown audio graph failure")
    }

    private func makeSnapshot(
        at timeNanoseconds: UInt64
    ) async throws -> SessionAudioRuntimeSnapshot {
        SessionAudioRuntimeSnapshot(
            stage: stage,
            pipeline: await pipeline.snapshot,
            clock: try await clock.snapshot(at: timeNanoseconds),
            concealedFrameCount: concealedFrameCount,
            lastAction: lastAction
        )
    }

    private func durationNanoseconds(frames: Int) throws -> UInt64 {
        guard let frames = UInt64(exactly: frames) else {
            throw AudioRuntimeRecoveryError.arithmeticOverflow
        }
        let (product, overflow) = frames.multipliedReportingOverflow(by: 1_000_000_000)
        guard !overflow else { throw AudioRuntimeRecoveryError.arithmeticOverflow }
        return product / 48_000
    }

    private func validateEventTime(_ timeNanoseconds: UInt64) throws {
        if let latestEventTimeNanoseconds,
           timeNanoseconds < latestEventTimeNanoseconds {
            throw AudioRuntimeRecoveryError.nonMonotonicEventTime
        }
    }
}
