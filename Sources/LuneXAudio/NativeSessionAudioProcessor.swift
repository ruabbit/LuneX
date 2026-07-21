import Foundation

struct NativeSessionAudioProcessorFactory: SessionAudioProcessorCreating {
    func makeAudioProcessor(
        sessionID: UUID,
        configuration: NegotiatedAudioStreamConfiguration
    ) async throws -> any SessionAudioProcessing {
        _ = sessionID
        let decoder = try AudioToolboxOpusDecoder(configuration: configuration)
        do {
            let streamConfiguration = StreamAudioConfiguration(
                sampleRate: Double(configuration.sampleRate),
                channelCount: configuration.channelCount,
                latencyPolicy: .lowLatency,
                spatialAudioEnabled: false
            )
            let runtime = try SessionAudioRuntime(
                clock: MediaClockSynchronizer(),
                configuration: streamConfiguration
            )
            do {
                _ = try await runtime.start(at: 0)
                return try NativeSessionAudioProcessor(
                    configuration: configuration,
                    decoder: decoder,
                    runtime: runtime
                )
            } catch {
                _ = try? await runtime.stop(at: 0)
                throw error
            }
        } catch {
            await decoder.close()
            throw error
        }
    }
}

actor NativeSessionAudioProcessor: SessionAudioProcessing {
    private let configuration: NegotiatedAudioStreamConfiguration
    private let samplesPerFrame: UInt32
    private let decoder: AudioToolboxOpusDecoder
    private let runtime: SessionAudioRuntime
    private var jitterBuffer: AudioPacketJitterBuffer
    private var latestEventTimeNanoseconds: UInt64 = 0
    private var nextPresentationTimeNanoseconds: UInt64 = 0
    private var nextRTPTimeStamp: UInt32?
    private var isStopped = false

    init(
        configuration: NegotiatedAudioStreamConfiguration,
        decoder: AudioToolboxOpusDecoder,
        runtime: SessionAudioRuntime
    ) throws {
        guard let samplesPerFrame = UInt32(exactly: configuration.samplesPerFrame) else {
            throw RuntimeContractError.invalidAudioConfiguration
        }
        self.configuration = configuration
        self.samplesPerFrame = samplesPerFrame
        self.decoder = decoder
        self.runtime = runtime
        jitterBuffer = try AudioPacketJitterBuffer(
            policy: AudioJitterBufferPolicy.realtime(configuration: configuration)
        )
    }

    func consume(_ event: AudioReceiveEvent) async throws -> Bool {
        guard !isStopped else { throw AudioRuntimeRecoveryError.stopped }
        switch event {
        case let .packet(packet):
            latestEventTimeNanoseconds = max(
                latestEventTimeNanoseconds,
                packet.receiveTimeNanoseconds
            )
            var events = try jitterBuffer.ingest(packet)
            events += try jitterBuffer.advanceTime(to: latestEventTimeNanoseconds)
            return try await process(
                events,
                eventTimeNanoseconds: latestEventTimeNanoseconds
            )
        case .packetLoss:
            return false
        case .closed:
            let events = try jitterBuffer.finish(at: latestEventTimeNanoseconds)
            return try await process(
                events,
                eventTimeNanoseconds: latestEventTimeNanoseconds
            )
        }
    }

    func stop() async {
        guard !isStopped else { return }
        isStopped = true
        _ = try? await runtime.stop(at: max(
            latestEventTimeNanoseconds,
            nextPresentationTimeNanoseconds
        ))
        await decoder.close()
    }

    private func process(
        _ events: [AudioJitterBufferEvent],
        eventTimeNanoseconds: UInt64
    ) async throws -> Bool {
        var scheduledDecodedAudio = false
        for (index, event) in events.enumerated() {
            switch event {
            case let .packetReady(packet):
                let decoded = try await decoder.decode(packet)
                let presentationTime = max(
                    eventTimeNanoseconds,
                    nextPresentationTimeNanoseconds
                )
                _ = try await runtime.schedule(
                    decoded,
                    presentationTimeNanoseconds: presentationTime
                )
                scheduledDecodedAudio = true
                nextPresentationTimeNanoseconds = try addingDuration(
                    frames: decoded.frameCount,
                    to: presentationTime
                )
                nextRTPTimeStamp = packet.timestamp &+ samplesPerFrame

            case let .packetsLost(loss):
                let firstRTPTimeStamp = nextRTPTimeStamp
                    ?? inferredLossTimestamp(loss, remainingEvents: events[(index + 1)...])
                    ?? 0
                let presentationTime = max(
                    eventTimeNanoseconds,
                    nextPresentationTimeNanoseconds
                )
                _ = try await runtime.handle(
                    .packetLoss(
                        firstSequenceNumber: loss.firstSequenceNumber,
                        firstRTPTimeStamp: firstRTPTimeStamp,
                        packetCount: loss.packetCount,
                        samplesPerPacket: configuration.samplesPerFrame
                    ),
                    at: presentationTime
                )
                let totalFrames = try multipliedFrames(packetCount: loss.packetCount)
                nextPresentationTimeNanoseconds = try addingDuration(
                    frames: totalFrames,
                    to: presentationTime
                )
                guard let totalFrames = UInt32(exactly: totalFrames) else {
                    throw AudioRuntimeRecoveryError.arithmeticOverflow
                }
                nextRTPTimeStamp = firstRTPTimeStamp &+ totalFrames

            case .packetDiscarded:
                break
            }
        }
        return scheduledDecodedAudio
    }

    private func inferredLossTimestamp(
        _ loss: AudioPacketLossRange,
        remainingEvents: ArraySlice<AudioJitterBufferEvent>
    ) -> UInt32? {
        let (missingFrameCount, overflow) = loss.packetCount.multipliedReportingOverflow(
            by: configuration.samplesPerFrame
        )
        guard !overflow,
              let futureTimestamp = remainingEvents.compactMap({ event -> UInt32? in
            guard case let .packetReady(packet) = event else { return nil }
            return packet.timestamp
        }).first,
        let missingFrames = UInt32(exactly: missingFrameCount) else {
            return nil
        }
        return futureTimestamp &- missingFrames
    }

    private func multipliedFrames(packetCount: Int) throws -> Int {
        let (frames, overflow) = packetCount.multipliedReportingOverflow(
            by: configuration.samplesPerFrame
        )
        guard packetCount > 0, !overflow else {
            throw AudioRuntimeRecoveryError.arithmeticOverflow
        }
        return frames
    }

    private func addingDuration(frames: Int, to time: UInt64) throws -> UInt64 {
        guard let frames = UInt64(exactly: frames) else {
            throw AudioRuntimeRecoveryError.arithmeticOverflow
        }
        let (product, productOverflow) = frames.multipliedReportingOverflow(
            by: 1_000_000_000
        )
        guard !productOverflow else {
            throw AudioRuntimeRecoveryError.arithmeticOverflow
        }
        let duration = product / UInt64(configuration.sampleRate)
        let (result, additionOverflow) = time.addingReportingOverflow(duration)
        guard !additionOverflow else {
            throw AudioRuntimeRecoveryError.arithmeticOverflow
        }
        return result
    }
}
