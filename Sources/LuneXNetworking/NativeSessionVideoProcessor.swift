import Foundation

enum NormalizedVideoAssemblyError: Error, Equatable, Sendable {
    case invalidPacket
}

struct NativeSessionVideoProcessorFactory: SessionVideoProcessorCreating {
    let presentationSource: StreamVideoPresentationSource

    func makeVideoProcessor(
        sessionID: UUID,
        mediaGeneration: UInt64,
        configuration: NegotiatedVideoStreamConfiguration,
        controlProvider: any SessionControlProvider
    ) async throws -> any SessionVideoProcessing {
        presentationSource.beginSession(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        )
        let source = presentationSource
        do {
            let pipeline = try VideoDecodePipeline.make(
                configuration: configuration,
                idrRequester: SessionControlVideoIDRRequester(
                    sessionID: sessionID,
                    provider: controlProvider
                ),
                decoderEventSink: { event in
                    source.consume(
                        event,
                        sessionID: sessionID,
                        mediaGeneration: mediaGeneration
                    )
                }
            )
            do {
                return try NativeSessionVideoProcessor(
                    sessionID: sessionID,
                    mediaGeneration: mediaGeneration,
                    configuration: configuration,
                    pipeline: pipeline,
                    presentationSource: presentationSource
                )
            } catch {
                await pipeline.stop()
                throw error
            }
        } catch {
            presentationSource.clear(
                sessionID: sessionID,
                mediaGeneration: mediaGeneration
            )
            throw error
        }
    }
}

actor NativeSessionVideoProcessor: SessionVideoProcessing {
    private let sessionID: UUID
    private let mediaGeneration: UInt64
    private let pipeline: VideoDecodePipeline
    private let presentationSource: StreamVideoPresentationSource
    private var assembler: NormalizedVideoAccessUnitAssembler
    private var lifecycleApplication: SessionLifecycleApplication?
    private var isDrainingTransport = false
    private var needsResumeRecovery = false
    private var isStopped = false

    init(
        sessionID: UUID,
        mediaGeneration: UInt64,
        configuration: NegotiatedVideoStreamConfiguration,
        pipeline: VideoDecodePipeline,
        presentationSource: StreamVideoPresentationSource
    ) throws {
        self.sessionID = sessionID
        self.mediaGeneration = mediaGeneration
        self.pipeline = pipeline
        self.presentationSource = presentationSource
        assembler = try NormalizedVideoAccessUnitAssembler(codec: configuration.codec)
    }

    func consume(_ event: VideoReceiveEvent) async throws -> Bool {
        guard !isStopped else { throw VideoDecodePipelineError.stopped }
        guard !isDrainingTransport else { return false }
        var submittedFrame = false
        do {
            switch event {
            case let .packet(packet):
                for assemblyEvent in assembler.ingest(packet) {
                    if case .submitted = try await pipeline.consume(assemblyEvent) {
                        submittedFrame = true
                    }
                }
            case let .packetLoss(expected, received):
                let loss = VideoFrameLoss(
                    firstFrameIndex: expected,
                    lastFrameIndex: received,
                    reason: .superseded,
                    requiresIDR: true
                )
                _ = try await pipeline.consume(.frameLost(loss))
            case .closed:
                for assemblyEvent in assembler.finish() {
                    if case .submitted = try await pipeline.consume(assemblyEvent) {
                        submittedFrame = true
                    }
                }
            }
        } catch VideoDecodePipelineError.submissionInvalidated {
            return false
        }
        return submittedFrame
    }

    func updateColorMetadata(_ metadata: VideoColorMetadata) async throws {
        guard !isStopped else { throw VideoDecodePipelineError.stopped }
        _ = try await pipeline.updateColorMetadata(metadata)
    }

    func applyLifecycle(_ application: SessionLifecycleApplication) async throws {
        guard !isStopped else { throw VideoDecodePipelineError.stopped }
        guard application.sessionID == sessionID,
              application.mediaGeneration == mediaGeneration else {
            throw SessionMediaEnvironmentError.staleLifecycleApplication
        }
        if let current = lifecycleApplication {
            if application != current {
                guard application.lifecycleRevision > current.lifecycleRevision else {
                    throw SessionMediaEnvironmentError.staleLifecycleApplication
                }
            } else if !needsResumeRecovery {
                return
            }
        }
        lifecycleApplication = application

        let shouldDrain: Bool
        switch application.directive.videoProcessing {
        case .submitDecodedVideo:
            shouldDrain = false
        case .inactive, .drainTransportWithoutDecoding:
            shouldDrain = true
        }

        if shouldDrain {
            isDrainingTransport = true
            needsResumeRecovery = false
            assembler.reset()
            presentationSource.discardFrames(
                sessionID: sessionID,
                mediaGeneration: mediaGeneration
            )
            await pipeline.pauseForLifecycle()
            return
        }

        guard isDrainingTransport || needsResumeRecovery else { return }
        isDrainingTransport = false
        needsResumeRecovery = true
        assembler.reset()
        presentationSource.discardFrames(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        )
        do {
            try await pipeline.resumeAfterLifecyclePause()
        } catch {
            guard lifecycleApplication == application else { return }
            throw error
        }
        guard lifecycleApplication == application, !isStopped else { return }
        needsResumeRecovery = false
    }

    func stop() async {
        guard !isStopped else { return }
        isStopped = true
        assembler.reset()
        await pipeline.stop()
        presentationSource.clear(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        )
    }
}

struct NormalizedVideoAccessUnitAssembler: Sendable {
    private struct FrameAssembly: Sendable {
        var frameIndex: UInt32
        var rtpTimestamp: UInt32
        var firstReceiveTimeNanoseconds: UInt64
        var lastReceiveTimeNanoseconds: UInt64
        var payloadBytes: Int
        var firstSequenceNumber: UInt32?
        var lastSequenceNumber: UInt32?
        var packets: [UInt32: ReceivedVideoPacket]
    }

    private let codec: NegotiatedVideoCodec
    private let limits: VideoAccessUnitAssemblyLimits
    private var currentFrame: FrameAssembly?
    private var expectedFrameIndex: UInt32?

    init(
        codec: NegotiatedVideoCodec,
        limits: VideoAccessUnitAssemblyLimits = .realtime
    ) throws {
        try limits.validate()
        self.codec = codec
        self.limits = limits
    }

    mutating func ingest(_ packet: ReceivedVideoPacket) -> [VideoAccessUnitAssemblyEvent] {
        var events = evictExpired(nowNanoseconds: packet.receiveTimeNanoseconds)
        guard !packet.payload.isEmpty,
              packet.payload.count <= limits.maximumAccessUnitBytes else {
            events.append(.frameLost(loss(
                first: packet.frameIndex,
                last: packet.frameIndex,
                reason: .invalidFrameHeader
            )))
            return events
        }

        if let currentFrame, packet.frameIndex != currentFrame.frameIndex {
            if WrappingSequenceComparison.isBefore32(packet.frameIndex, currentFrame.frameIndex) {
                events.append(.packetDiscarded(.lateFrame))
                return events
            }
            events.append(.frameLost(loss(
                first: currentFrame.frameIndex,
                last: packet.frameIndex &- 1,
                reason: .superseded
            )))
            self.currentFrame = nil
            expectedFrameIndex = packet.frameIndex
        } else if currentFrame == nil,
                  let expectedFrameIndex,
                  packet.frameIndex != expectedFrameIndex {
            if WrappingSequenceComparison.isBefore32(packet.frameIndex, expectedFrameIndex) {
                events.append(.packetDiscarded(.lateFrame))
                return events
            }
            events.append(.frameLost(loss(
                first: expectedFrameIndex,
                last: packet.frameIndex &- 1,
                reason: .superseded
            )))
        }

        if currentFrame == nil {
            currentFrame = FrameAssembly(
                frameIndex: packet.frameIndex,
                rtpTimestamp: packet.rtpTimestamp,
                firstReceiveTimeNanoseconds: packet.receiveTimeNanoseconds,
                lastReceiveTimeNanoseconds: packet.receiveTimeNanoseconds,
                payloadBytes: 0,
                firstSequenceNumber: nil,
                lastSequenceNumber: nil,
                packets: [:]
            )
        }
        guard var frame = currentFrame else { return events }
        guard frame.rtpTimestamp == packet.rtpTimestamp else {
            events.append(.frameLost(loss(
                first: frame.frameIndex,
                last: frame.frameIndex,
                reason: .inconsistentFrameMetadata
            )))
            currentFrame = nil
            expectedFrameIndex = frame.frameIndex &+ 1
            return events
        }

        if let existing = frame.packets[packet.sequenceNumber] {
            if existing == packet {
                events.append(.packetDiscarded(.duplicate))
            } else {
                events.append(.frameLost(loss(
                    first: frame.frameIndex,
                    last: frame.frameIndex,
                    reason: .conflictingDuplicate
                )))
                currentFrame = nil
                expectedFrameIndex = frame.frameIndex &+ 1
            }
            return events
        }
        guard frame.packets.count < limits.maximumPacketsPerFrame,
              frame.payloadBytes <= limits.maximumAccessUnitBytes - packet.payload.count else {
            events.append(.frameLost(loss(
                first: frame.frameIndex,
                last: frame.frameIndex,
                reason: frame.packets.count >= limits.maximumPacketsPerFrame
                    ? .packetCapacityExceeded
                    : .accessUnitTooLarge
            )))
            currentFrame = nil
            expectedFrameIndex = frame.frameIndex &+ 1
            return events
        }

        if packet.isFirstPacket {
            guard frame.firstSequenceNumber == nil
                    || frame.firstSequenceNumber == packet.sequenceNumber else {
                return invalidate(&events, frame: frame, reason: .inconsistentFrameMetadata)
            }
            frame.firstSequenceNumber = packet.sequenceNumber
        }
        if packet.isLastPacket {
            guard frame.lastSequenceNumber == nil
                    || frame.lastSequenceNumber == packet.sequenceNumber else {
                return invalidate(&events, frame: frame, reason: .inconsistentFrameMetadata)
            }
            frame.lastSequenceNumber = packet.sequenceNumber
        }
        frame.packets[packet.sequenceNumber] = packet
        frame.payloadBytes += packet.payload.count
        frame.firstReceiveTimeNanoseconds = min(
            frame.firstReceiveTimeNanoseconds,
            packet.receiveTimeNanoseconds
        )
        frame.lastReceiveTimeNanoseconds = max(
            frame.lastReceiveTimeNanoseconds,
            packet.receiveTimeNanoseconds
        )
        currentFrame = frame

        guard isComplete(frame) else { return events }
        do {
            events.append(.accessUnit(try assemble(frame)))
        } catch {
            events.append(.frameLost(loss(
                first: frame.frameIndex,
                last: frame.frameIndex,
                reason: .invalidFrameHeader
            )))
        }
        currentFrame = nil
        expectedFrameIndex = frame.frameIndex &+ 1
        return events
    }

    mutating func evictExpired(nowNanoseconds: UInt64) -> [VideoAccessUnitAssemblyEvent] {
        guard let frame = currentFrame,
              nowNanoseconds >= frame.firstReceiveTimeNanoseconds,
              nowNanoseconds - frame.firstReceiveTimeNanoseconds
                >= limits.maximumAssemblyAgeNanoseconds else { return [] }
        currentFrame = nil
        expectedFrameIndex = frame.frameIndex &+ 1
        return [.frameLost(loss(
            first: frame.frameIndex,
            last: frame.frameIndex,
            reason: .assemblyTimedOut
        ))]
    }

    mutating func finish() -> [VideoAccessUnitAssemblyEvent] {
        guard let frame = currentFrame else { return [] }
        currentFrame = nil
        expectedFrameIndex = frame.frameIndex &+ 1
        return [.frameLost(loss(
            first: frame.frameIndex,
            last: frame.frameIndex,
            reason: .incompleteAtEndOfStream
        ))]
    }

    mutating func reset() {
        currentFrame = nil
        expectedFrameIndex = nil
    }

    private func isComplete(_ frame: FrameAssembly) -> Bool {
        guard let first = frame.firstSequenceNumber,
              let last = frame.lastSequenceNumber else { return false }
        let distance = last &- first
        guard distance < UInt32(limits.maximumPacketsPerFrame),
              let packetCount = Int(exactly: distance &+ 1),
              packetCount == frame.packets.count else { return false }
        for offset in 0..<packetCount where frame.packets[first &+ UInt32(offset)] == nil {
            return false
        }
        return true
    }

    private func assemble(_ frame: FrameAssembly) throws -> VideoAccessUnit {
        guard let firstSequence = frame.firstSequenceNumber,
              let lastSequence = frame.lastSequenceNumber,
              let firstPacket = frame.packets[firstSequence],
              let lastPacket = frame.packets[lastSequence],
              firstPacket.isFirstPacket,
              lastPacket.isLastPacket else {
            throw NormalizedVideoAssemblyError.invalidPacket
        }
        let header = try SunshineShortFrameHeader.parse(firstPacket.payload)
        let packetCount = Int(lastSequence &- firstSequence &+ 1)
        var payload = Data()
        payload.reserveCapacity(max(0, frame.payloadBytes - SunshineShortFrameHeader.byteCount))
        for offset in 0..<packetCount {
            let sequence = firstSequence &+ UInt32(offset)
            guard let packet = frame.packets[sequence] else {
                throw NormalizedVideoAssemblyError.invalidPacket
            }
            var fragment = packet.payload
            if packet.isLastPacket, codec == .av1 {
                guard header.lastPayloadLength <= fragment.count else {
                    throw NormalizedVideoAssemblyError.invalidPacket
                }
                fragment = Data(fragment.prefix(header.lastPayloadLength))
            }
            if packet.isFirstPacket {
                guard fragment.count >= SunshineShortFrameHeader.byteCount else {
                    throw NormalizedVideoAssemblyError.invalidPacket
                }
                fragment.removeFirst(SunshineShortFrameHeader.byteCount)
            }
            payload.append(fragment)
        }
        guard !payload.isEmpty, payload.count <= limits.maximumAccessUnitBytes else {
            throw NormalizedVideoAssemblyError.invalidPacket
        }
        return VideoAccessUnit(
            frameIndex: frame.frameIndex,
            rtpTimestamp: frame.rtpTimestamp,
            codec: codec,
            frameType: header.frameType,
            hostProcessingLatencyTenthsOfMillisecond:
                header.hostProcessingLatencyTenthsOfMillisecond,
            firstReceiveTimeNanoseconds: frame.firstReceiveTimeNanoseconds,
            lastReceiveTimeNanoseconds: frame.lastReceiveTimeNanoseconds,
            packetCount: packetCount,
            payload: payload
        )
    }

    private mutating func invalidate(
        _ events: inout [VideoAccessUnitAssemblyEvent],
        frame: FrameAssembly,
        reason: VideoFrameLossReason
    ) -> [VideoAccessUnitAssemblyEvent] {
        events.append(.frameLost(loss(
            first: frame.frameIndex,
            last: frame.frameIndex,
            reason: reason
        )))
        currentFrame = nil
        expectedFrameIndex = frame.frameIndex &+ 1
        return events
    }

    private func loss(
        first: UInt32,
        last: UInt32,
        reason: VideoFrameLossReason
    ) -> VideoFrameLoss {
        VideoFrameLoss(
            firstFrameIndex: first,
            lastFrameIndex: last,
            reason: reason,
            requiresIDR: true
        )
    }
}
