@preconcurrency import CoreMedia
import Foundation

protocol VideoIDRRequesting: Sendable {
    func requestIDR() async throws
}

struct SessionControlVideoIDRRequester: VideoIDRRequesting {
    let sessionID: UUID
    let provider: any SessionControlProvider

    func requestIDR() async throws {
        try await provider.requestIDR(sessionID: sessionID)
    }
}

enum VideoDecodePipelineError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidFrameRate(Int)
    case codecMismatch(expected: NegotiatedVideoCodec, received: NegotiatedVideoCodec)
    case stopped

    var description: String {
        switch self {
        case let .invalidFrameRate(frameRate):
            return "Video frame rate \(frameRate) cannot be represented by CoreMedia."
        case let .codecMismatch(expected, received):
            return "Video access unit codec \(received.rawValue) does not match \(expected.rawValue)."
        case .stopped:
            return "The video decode pipeline has already stopped."
        }
    }
}

enum VideoDecodeRecoveryReason: Equatable, Sendable {
    case missingInitialIDR
    case packetLoss(VideoFrameLossReason)
    case colorMetadataChanged
    case malformedIDR
    case decoderFrameDropped
    case decoderFailure(VideoDecoderError)
}

enum VideoDecodePipelineDropReason: Equatable, Sendable {
    case awaitingIDR
}

enum VideoDecodePipelineResult: Equatable, Sendable {
    case submitted(frameIndex: UInt32, generation: UInt64, replacedSession: Bool)
    case recoveryRequested(VideoDecodeRecoveryReason)
    case dropped(frameIndex: UInt32, reason: VideoDecodePipelineDropReason)
    case packetDiscarded(VideoPacketDiscardReason)
    case ignored
}

struct VideoDecodePipelineSnapshot: Equatable, Sendable {
    var activeDecoderGeneration: UInt64?
    var isAwaitingIDR: Bool
    var hasOutstandingIDRRequest: Bool
    var isStopped: Bool
    var sessionCreationCount: UInt64
    var decoderResetCount: UInt64
    var formatChangeCount: UInt64
    var colorMetadataChangeCount: UInt64
    var idrRequestCount: UInt64
    var idrRequestFailureCount: UInt64
    var droppedAccessUnitCount: UInt64
    var decoderDroppedFrameCount: UInt64
    var decoderFailureCount: UInt64
    var teardownCount: UInt64
}

actor VideoDecodePipeline {
    typealias DecoderEventSink = @Sendable (VideoDecoderEvent) -> Void

    private let decoder: VideoDecoder
    private let parameterSetParser: VideoParameterSetParser
    private let idrRequester: any VideoIDRRequesting
    private let eventBridge: VideoDecodePipelineEventBridge
    private var configuration: NegotiatedVideoStreamConfiguration
    private var lastParameterSets: VideoParameterSets?
    private var lastSessionColorMetadata: VideoColorMetadata?
    private var activeDecoderGeneration: UInt64?
    private var isAwaitingIDR = true
    private var hasOutstandingIDRRequest = false
    private var isStopped = false
    private var lifecycleToken: UInt64 = 0
    private var recoveryGeneration: UInt64 = 0
    private var sessionCreationCount: UInt64 = 0
    private var decoderResetCount: UInt64 = 0
    private var formatChangeCount: UInt64 = 0
    private var colorMetadataChangeCount: UInt64 = 0
    private var idrRequestCount: UInt64 = 0
    private var idrRequestFailureCount: UInt64 = 0
    private var droppedAccessUnitCount: UInt64 = 0
    private var decoderDroppedFrameCount: UInt64 = 0
    private var decoderFailureCount: UInt64 = 0
    private var teardownCount: UInt64 = 0

    static func make(
        configuration: NegotiatedVideoStreamConfiguration,
        idrRequester: any VideoIDRRequesting,
        decoderFactory: any VideoDecompressionSessionCreating =
            VideoToolboxDecompressionSessionFactory(),
        sampleBufferFactory: VideoSampleBufferFactory? = nil,
        decoderEventSink: @escaping DecoderEventSink = { _ in }
    ) throws -> VideoDecodePipeline {
        try configuration.validate()
        guard let _ = Int32(exactly: configuration.frameRate) else {
            throw VideoDecodePipelineError.invalidFrameRate(configuration.frameRate)
        }
        let bridge = VideoDecodePipelineEventBridge(downstream: decoderEventSink)
        let decoder = try VideoDecoder(
            factory: decoderFactory,
            sampleBufferFactory: sampleBufferFactory,
            eventSink: bridge.forward
        )
        let pipeline = VideoDecodePipeline(
            configuration: configuration,
            parameterSetParser: try VideoParameterSetParser(),
            decoder: decoder,
            idrRequester: idrRequester,
            eventBridge: bridge
        )
        bridge.attach(pipeline)
        return pipeline
    }

    private init(
        configuration: NegotiatedVideoStreamConfiguration,
        parameterSetParser: VideoParameterSetParser,
        decoder: VideoDecoder,
        idrRequester: any VideoIDRRequesting,
        eventBridge: VideoDecodePipelineEventBridge
    ) {
        self.configuration = configuration
        self.parameterSetParser = parameterSetParser
        self.decoder = decoder
        self.idrRequester = idrRequester
        self.eventBridge = eventBridge
    }

    deinit {
        eventBridge.detach()
    }

    func consume(_ event: VideoAccessUnitAssemblyEvent) async throws -> VideoDecodePipelineResult {
        guard !isStopped else { throw VideoDecodePipelineError.stopped }
        switch event {
        case let .accessUnit(accessUnit):
            return try await submit(accessUnit)
        case let .frameLost(loss):
            guard loss.requiresIDR else { return .ignored }
            let reason = VideoDecodeRecoveryReason.packetLoss(loss.reason)
            try await beginRecovery(reason)
            return .recoveryRequested(reason)
        case let .packetDiscarded(reason):
            return .packetDiscarded(reason)
        }
    }

    func updateColorMetadata(
        _ metadata: VideoColorMetadata
    ) async throws -> VideoDecodePipelineResult {
        guard !isStopped else { throw VideoDecodePipelineError.stopped }
        if metadata == configuration.colorMetadata {
            return .ignored
        }
        var updatedConfiguration = configuration
        updatedConfiguration.colorMetadata = metadata
        try updatedConfiguration.validate()
        configuration = updatedConfiguration
        try await beginRecovery(.colorMetadataChanged)
        return .recoveryRequested(.colorMetadataChanged)
    }

    func stop() async {
        guard !isStopped else { return }
        isStopped = true
        lifecycleToken &+= 1
        recoveryGeneration &+= 1
        activeDecoderGeneration = nil
        isAwaitingIDR = true
        hasOutstandingIDRRequest = false
        lastParameterSets = nil
        lastSessionColorMetadata = nil
        teardownCount &+= 1
        await decoder.stop()
        eventBridge.detach()
    }

    func snapshot() -> VideoDecodePipelineSnapshot {
        VideoDecodePipelineSnapshot(
            activeDecoderGeneration: activeDecoderGeneration,
            isAwaitingIDR: isAwaitingIDR,
            hasOutstandingIDRRequest: hasOutstandingIDRRequest,
            isStopped: isStopped,
            sessionCreationCount: sessionCreationCount,
            decoderResetCount: decoderResetCount,
            formatChangeCount: formatChangeCount,
            colorMetadataChangeCount: colorMetadataChangeCount,
            idrRequestCount: idrRequestCount,
            idrRequestFailureCount: idrRequestFailureCount,
            droppedAccessUnitCount: droppedAccessUnitCount,
            decoderDroppedFrameCount: decoderDroppedFrameCount,
            decoderFailureCount: decoderFailureCount,
            teardownCount: teardownCount
        )
    }

    private func submit(_ accessUnit: VideoAccessUnit) async throws -> VideoDecodePipelineResult {
        guard accessUnit.codec == configuration.codec else {
            throw VideoDecodePipelineError.codecMismatch(
                expected: configuration.codec,
                received: accessUnit.codec
            )
        }
        if accessUnit.frameType == .instantaneousDecoderRefresh {
            return try await submitIDR(accessUnit)
        }
        guard !isAwaitingIDR, let generation = activeDecoderGeneration else {
            droppedAccessUnitCount &+= 1
            try await beginRecovery(.missingInitialIDR)
            return .dropped(frameIndex: accessUnit.frameIndex, reason: .awaitingIDR)
        }

        let token = lifecycleToken
        do {
            _ = try await decoder.decode(compressedSample(from: accessUnit))
            guard !isStopped, lifecycleToken == token else {
                throw VideoDecodePipelineError.stopped
            }
            return .submitted(
                frameIndex: accessUnit.frameIndex,
                generation: generation,
                replacedSession: false
            )
        } catch let error as VideoDecoderError {
            try? await beginRecovery(.decoderFailure(error))
            throw error
        }
    }

    private func submitIDR(
        _ accessUnit: VideoAccessUnit
    ) async throws -> VideoDecodePipelineResult {
        let token = lifecycleToken
        hasOutstandingIDRRequest = false
        let parameterSets: VideoParameterSets
        do {
            parameterSets = try parameterSetParser.parse(
                accessUnit.payload,
                codec: accessUnit.codec
            )
        } catch {
            try? await beginRecovery(.malformedIDR)
            throw error
        }

        let parameterSetsChanged = lastParameterSets != nil
            && lastParameterSets != parameterSets
        let metadataChanged = lastSessionColorMetadata != nil
            && lastSessionColorMetadata != configuration.colorMetadata
        let needsReplacement = activeDecoderGeneration == nil
            || parameterSetsChanged
            || metadataChanged
        var generation = activeDecoderGeneration

        if needsReplacement {
            let isReset = lastParameterSets != nil || lastSessionColorMetadata != nil
            do {
                let description = try VideoFormatDescriptionFactory.make(from: parameterSets)
                generation = try await decoder.replaceSession(
                    formatDescription: description,
                    colorMetadata: configuration.colorMetadata
                )
                guard !isStopped, lifecycleToken == token else {
                    throw VideoDecodePipelineError.stopped
                }
            } catch {
                guard !isStopped, lifecycleToken == token else {
                    throw VideoDecodePipelineError.stopped
                }
                try? await beginRecovery(.malformedIDR)
                throw error
            }
            sessionCreationCount &+= 1
            if isReset { decoderResetCount &+= 1 }
            if parameterSetsChanged { formatChangeCount &+= 1 }
            if metadataChanged { colorMetadataChangeCount &+= 1 }
            activeDecoderGeneration = generation
            lastParameterSets = parameterSets
            lastSessionColorMetadata = configuration.colorMetadata
        }

        guard let generation else {
            try await beginRecovery(.missingInitialIDR)
            return .dropped(frameIndex: accessUnit.frameIndex, reason: .awaitingIDR)
        }
        do {
            _ = try await decoder.decode(compressedSample(from: accessUnit))
            guard !isStopped, lifecycleToken == token else {
                throw VideoDecodePipelineError.stopped
            }
        } catch let error as VideoDecoderError {
            guard !isStopped, lifecycleToken == token else {
                throw VideoDecodePipelineError.stopped
            }
            try? await beginRecovery(.decoderFailure(error))
            throw error
        }
        isAwaitingIDR = false
        hasOutstandingIDRRequest = false
        recoveryGeneration &+= 1
        return .submitted(
            frameIndex: accessUnit.frameIndex,
            generation: generation,
            replacedSession: needsReplacement
        )
    }

    private func compressedSample(from accessUnit: VideoAccessUnit) -> CompressedVideoSample {
        CompressedVideoSample(
            frameID: UInt64(accessUnit.frameIndex),
            accessUnit: accessUnit.payload,
            presentationTimeStamp: CMTime(
                value: Int64(accessUnit.rtpTimestamp),
                timescale: 90_000
            ),
            duration: CMTime(
                value: 1,
                timescale: Int32(configuration.frameRate)
            )
        )
    }

    private func beginRecovery(_ reason: VideoDecodeRecoveryReason) async throws {
        guard !isStopped else { return }
        let token = lifecycleToken
        let wasAwaitingIDR = isAwaitingIDR
        if !wasAwaitingIDR {
            recoveryGeneration &+= 1
        }
        let recovery = recoveryGeneration
        let hadActiveDecoder = activeDecoderGeneration != nil
        isAwaitingIDR = true
        activeDecoderGeneration = nil
        if hadActiveDecoder {
            await decoder.stop()
        }
        guard !isStopped,
              lifecycleToken == token,
              recoveryGeneration == recovery else { return }
        guard !hasOutstandingIDRRequest else { return }

        hasOutstandingIDRRequest = true
        idrRequestCount &+= 1
        do {
            try await idrRequester.requestIDR()
        } catch {
            guard !isStopped,
                  lifecycleToken == token,
                  recoveryGeneration == recovery else { return }
            if !isStopped {
                hasOutstandingIDRRequest = false
                idrRequestFailureCount &+= 1
            }
            throw error
        }
        guard !isStopped,
              lifecycleToken == token,
              recoveryGeneration == recovery else { return }
        _ = reason
    }

    fileprivate func receiveDecoderEvent(_ event: VideoDecoderEvent) async {
        guard !isStopped else { return }
        switch event {
        case let .frameDropped(generation, _, _)
            where generation == activeDecoderGeneration:
            decoderDroppedFrameCount &+= 1
            try? await beginRecovery(.decoderFrameDropped)
        case let .failure(failure)
            where failure.generation == activeDecoderGeneration && failure.frameID != nil:
            decoderFailureCount &+= 1
            try? await beginRecovery(.decoderFailure(failure.error))
        case .sessionStarted, .frame, .frameDropped, .failure, .sessionStopped:
            break
        }
    }
}

private final class VideoDecodePipelineEventBridge: @unchecked Sendable {
    private let lock = NSLock()
    private let downstream: VideoDecodePipeline.DecoderEventSink
    private weak var pipeline: VideoDecodePipeline?

    init(downstream: @escaping VideoDecodePipeline.DecoderEventSink) {
        self.downstream = downstream
    }

    func attach(_ pipeline: VideoDecodePipeline) {
        lock.withLock {
            self.pipeline = pipeline
        }
    }

    func detach() {
        lock.withLock {
            pipeline = nil
        }
    }

    func forward(_ event: VideoDecoderEvent) {
        downstream(event)
        let pipeline = lock.withLock { self.pipeline }
        guard let pipeline else { return }
        Task {
            await pipeline.receiveDecoderEvent(event)
        }
    }
}
