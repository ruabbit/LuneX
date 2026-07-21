@preconcurrency import CoreMedia
@preconcurrency import CoreVideo
import Foundation
@preconcurrency import VideoToolbox

enum VideoOutputBitDepth: Int, Equatable, Sendable {
    case eight = 8
    case ten = 10

    var pixelFormat: OSType {
        switch self {
        case .eight:
            return kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        case .ten:
            return kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        }
    }
}

struct CompressedVideoSample: Equatable, Sendable {
    var frameID: UInt64
    var accessUnit: Data
    var presentationTimeStamp: CMTime
    var duration: CMTime

    init(
        frameID: UInt64,
        accessUnit: Data,
        presentationTimeStamp: CMTime = .invalid,
        duration: CMTime = .invalid
    ) {
        self.frameID = frameID
        self.accessUnit = accessUnit
        self.presentationTimeStamp = presentationTimeStamp
        self.duration = duration
    }
}

enum VideoDecoderError: Error, Equatable, Sendable, CustomStringConvertible {
    case emptyAccessUnit
    case accessUnitTooLarge
    case unsupportedCodec(OSType)
    case annexB(VideoFormatDescriptionError)
    case blockBufferCreationFailed(OSStatus)
    case blockBufferCopyFailed(OSStatus)
    case sampleBufferCreationFailed(OSStatus)
    case sessionCreationFailed(OSStatus)
    case noActiveSession
    case decodeFailed(OSStatus)
    case callbackFailed(OSStatus)
    case callbackMissingImageBuffer
    case finishDelayedFramesFailed(OSStatus)
    case waitForAsynchronousFramesFailed(OSStatus)
    case invalidColorMetadata(VideoColorMetadataError)

    var description: String {
        switch self {
        case .emptyAccessUnit:
            return "The compressed video access unit is empty."
        case .accessUnitTooLarge:
            return "The compressed video access unit exceeds the decoder bound."
        case let .unsupportedCodec(codec):
            return "The CoreMedia video codec \(codec) is unsupported by this sample path."
        case let .annexB(error):
            return "The compressed Annex-B access unit is invalid: \(error)"
        case let .blockBufferCreationFailed(status):
            return "CoreMedia could not allocate the compressed block buffer (\(status))."
        case let .blockBufferCopyFailed(status):
            return "CoreMedia could not copy the compressed access unit (\(status))."
        case let .sampleBufferCreationFailed(status):
            return "CoreMedia could not create the compressed sample buffer (\(status))."
        case let .sessionCreationFailed(status):
            return "VideoToolbox could not create a required hardware decoder (\(status))."
        case .noActiveSession:
            return "No active VideoToolbox decompression session owns this sample."
        case let .decodeFailed(status):
            return "VideoToolbox rejected the compressed sample synchronously (\(status))."
        case let .callbackFailed(status):
            return "VideoToolbox reported an asynchronous decode failure (\(status))."
        case .callbackMissingImageBuffer:
            return "VideoToolbox completed a frame without an image buffer or drop evidence."
        case let .finishDelayedFramesFailed(status):
            return "VideoToolbox could not finish delayed frames during teardown (\(status))."
        case let .waitForAsynchronousFramesFailed(status):
            return "VideoToolbox could not drain asynchronous frames during teardown (\(status))."
        case let .invalidColorMetadata(error):
            return "The decoder color metadata is invalid: \(error)"
        }
    }
}

struct VideoDecoderFailure: Equatable, Sendable {
    var generation: UInt64?
    var frameID: UInt64?
    var error: VideoDecoderError
}

struct DecodedVideoFrame: @unchecked Sendable {
    var generation: UInt64
    var frameID: UInt64
    var pixelBuffer: CVPixelBuffer
    var presentationTimeStamp: CMTime
    var duration: CMTime
    var infoFlags: VTDecodeInfoFlags
    var colorMetadata: VideoColorMetadata
}

enum VideoDecoderEvent: @unchecked Sendable {
    case sessionStarted(generation: UInt64, colorMetadata: VideoColorMetadata)
    case frame(DecodedVideoFrame)
    case frameDropped(generation: UInt64, frameID: UInt64, infoFlags: VTDecodeInfoFlags)
    case failure(VideoDecoderFailure)
    case sessionStopped(generation: UInt64)
}

struct VideoDecodeSubmission: Equatable, Sendable {
    var infoFlags: VTDecodeInfoFlags
}

struct VideoSampleBufferFactory: Sendable {
    let limits: AnnexBNALParserLimits

    init(limits: AnnexBNALParserLimits = .realtime) throws {
        try limits.validate()
        self.limits = limits
    }

    func make(
        sample: CompressedVideoSample,
        formatDescription: CMVideoFormatDescription
    ) throws -> CMSampleBuffer {
        guard !sample.accessUnit.isEmpty else {
            throw VideoDecoderError.emptyAccessUnit
        }
        guard sample.accessUnit.count <= limits.maximumAccessUnitBytes else {
            throw VideoDecoderError.accessUnitTooLarge
        }

        let codec = CMFormatDescriptionGetMediaSubType(formatDescription)
        let encodedAccessUnit: Data
        switch codec {
        case kCMVideoCodecType_H264, kCMVideoCodecType_HEVC:
            do {
                let parser = try VideoParameterSetParser(limits: limits)
                let nalUnits = try parser.splitNALUnits(sample.accessUnit)
                encodedAccessUnit = try lengthPrefix(nalUnits)
            } catch let error as VideoFormatDescriptionError {
                throw VideoDecoderError.annexB(error)
            }
        case kCMVideoCodecType_AV1:
            encodedAccessUnit = sample.accessUnit
        default:
            throw VideoDecoderError.unsupportedCodec(codec)
        }

        var blockBuffer: CMBlockBuffer?
        let createStatus = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: encodedAccessUnit.count,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: encodedAccessUnit.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard createStatus == kCMBlockBufferNoErr, let blockBuffer else {
            throw VideoDecoderError.blockBufferCreationFailed(createStatus)
        }

        let copyStatus = encodedAccessUnit.withUnsafeBytes { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return kCMBlockBufferBadLengthParameterErr
            }
            return CMBlockBufferReplaceDataBytes(
                with: baseAddress,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: encodedAccessUnit.count
            )
        }
        guard copyStatus == kCMBlockBufferNoErr else {
            throw VideoDecoderError.blockBufferCopyFailed(copyStatus)
        }

        var timing = CMSampleTimingInfo(
            duration: sample.duration,
            presentationTimeStamp: sample.presentationTimeStamp,
            decodeTimeStamp: .invalid
        )
        var sampleSize = encodedAccessUnit.count
        var sampleBuffer: CMSampleBuffer?
        let sampleStatus = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )
        guard sampleStatus == noErr, let sampleBuffer else {
            throw VideoDecoderError.sampleBufferCreationFailed(sampleStatus)
        }
        return sampleBuffer
    }

    private func lengthPrefix(_ nalUnits: [Data]) throws -> Data {
        var output = Data()
        output.reserveCapacity(nalUnits.reduce(0) { $0 + 4 + $1.count })
        for nalUnit in nalUnits {
            guard let length = UInt32(exactly: nalUnit.count) else {
                throw VideoDecoderError.accessUnitTooLarge
            }
            output.append(UInt8(truncatingIfNeeded: length >> 24))
            output.append(UInt8(truncatingIfNeeded: length >> 16))
            output.append(UInt8(truncatingIfNeeded: length >> 8))
            output.append(UInt8(truncatingIfNeeded: length))
            output.append(nalUnit)
        }
        return output
    }
}

protocol VideoDecompressionSessionOwning: AnyObject, Sendable {
    func decode(
        _ sampleBuffer: CMSampleBuffer,
        generation: UInt64,
        frameID: UInt64
    ) -> Result<VideoDecodeSubmission, VideoDecoderError>

    func finishAndInvalidate() -> [VideoDecoderError]
}

protocol VideoDecompressionSessionCreating: Sendable {
    func makeSession(
        formatDescription: CMVideoFormatDescription,
        bitDepth: VideoOutputBitDepth,
        callbackBridge: VideoDecompressionCallbackBridge
    ) throws -> any VideoDecompressionSessionOwning
}

struct VideoDecompressionOutput: @unchecked Sendable {
    var generation: UInt64
    var frameID: UInt64
    var status: OSStatus
    var infoFlags: VTDecodeInfoFlags
    var imageBuffer: CVImageBuffer?
    var presentationTimeStamp: CMTime
    var duration: CMTime
}

final class VideoDecompressionCallbackBridge: @unchecked Sendable {
    let generation: UInt64

    private let lock = NSLock()
    private weak var decoder: VideoDecoder?

    init(generation: UInt64, decoder: VideoDecoder) {
        self.generation = generation
        self.decoder = decoder
    }

    func forward(_ output: VideoDecompressionOutput) {
        let decoder = lock.withLock { self.decoder }
        guard let decoder else { return }
        Task {
            await decoder.receive(output)
        }
    }

    func detach() {
        lock.withLock {
            decoder = nil
        }
    }
}

private final class VideoFrameCallbackContext: @unchecked Sendable {
    let generation: UInt64
    let frameID: UInt64

    init(generation: UInt64, frameID: UInt64) {
        self.generation = generation
        self.frameID = frameID
    }
}

struct VideoToolboxDecompressionSessionFactory: VideoDecompressionSessionCreating {
    func makeSession(
        formatDescription: CMVideoFormatDescription,
        bitDepth: VideoOutputBitDepth,
        callbackBridge: VideoDecompressionCallbackBridge
    ) throws -> any VideoDecompressionSessionOwning {
        try VideoToolboxDecompressionSession(
            formatDescription: formatDescription,
            bitDepth: bitDepth,
            callbackBridge: callbackBridge
        )
    }

    static func destinationAttributes(for bitDepth: VideoOutputBitDepth) -> [CFString: Any] {
        [
            kCVPixelBufferPixelFormatTypeKey: bitDepth.pixelFormat,
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
            kCVPixelBufferMetalCompatibilityKey: true
        ]
    }
}

final class VideoToolboxDecompressionSession: VideoDecompressionSessionOwning, @unchecked Sendable {
    private let callbackBridge: VideoDecompressionCallbackBridge
    private let lock = NSLock()
    private var session: VTDecompressionSession?

    init(
        formatDescription: CMVideoFormatDescription,
        bitDepth: VideoOutputBitDepth,
        callbackBridge: VideoDecompressionCallbackBridge
    ) throws {
        self.callbackBridge = callbackBridge

        var callbackRecord = VTDecompressionOutputCallbackRecord(
            decompressionOutputCallback: { callbackRefCon, frameRefCon, status, infoFlags, imageBuffer, presentationTimeStamp, duration in
                guard let frameRefCon else { return }
                let context = Unmanaged<VideoFrameCallbackContext>
                    .fromOpaque(frameRefCon)
                    .takeRetainedValue()
                guard let callbackRefCon else { return }
                let bridge = Unmanaged<VideoDecompressionCallbackBridge>
                    .fromOpaque(callbackRefCon)
                    .takeUnretainedValue()
                bridge.forward(VideoDecompressionOutput(
                    generation: context.generation,
                    frameID: context.frameID,
                    status: status,
                    infoFlags: infoFlags,
                    imageBuffer: imageBuffer,
                    presentationTimeStamp: presentationTimeStamp,
                    duration: duration
                ))
            },
            decompressionOutputRefCon: Unmanaged.passUnretained(callbackBridge).toOpaque()
        )
        let decoderSpecification = [
            kVTVideoDecoderSpecification_RequireHardwareAcceleratedVideoDecoder: true
        ] as CFDictionary
        let attributes = VideoToolboxDecompressionSessionFactory
            .destinationAttributes(for: bitDepth) as CFDictionary
        var createdSession: VTDecompressionSession?
        let status = VTDecompressionSessionCreate(
            allocator: kCFAllocatorDefault,
            formatDescription: formatDescription,
            decoderSpecification: decoderSpecification,
            imageBufferAttributes: attributes,
            outputCallback: &callbackRecord,
            decompressionSessionOut: &createdSession
        )
        guard status == noErr, let createdSession else {
            callbackBridge.detach()
            throw VideoDecoderError.sessionCreationFailed(status)
        }
        session = createdSession
    }

    func decode(
        _ sampleBuffer: CMSampleBuffer,
        generation: UInt64,
        frameID: UInt64
    ) -> Result<VideoDecodeSubmission, VideoDecoderError> {
        lock.withLock {
            guard let session else {
                return .failure(.noActiveSession)
            }
            let context = VideoFrameCallbackContext(generation: generation, frameID: frameID)
            let opaqueContext = Unmanaged.passRetained(context).toOpaque()
            var infoFlags = VTDecodeInfoFlags()
            let status = VTDecompressionSessionDecodeFrame(
                session,
                sampleBuffer: sampleBuffer,
                flags: [._EnableAsynchronousDecompression, ._1xRealTimePlayback],
                frameRefcon: opaqueContext,
                infoFlagsOut: &infoFlags
            )
            if status != noErr {
                Unmanaged<VideoFrameCallbackContext>.fromOpaque(opaqueContext).release()
                return .failure(.decodeFailed(status))
            }
            return .success(VideoDecodeSubmission(infoFlags: infoFlags))
        }
    }

    func finishAndInvalidate() -> [VideoDecoderError] {
        lock.withLock {
            guard let session else { return [] }
            self.session = nil
            var errors: [VideoDecoderError] = []
            let finishStatus = VTDecompressionSessionFinishDelayedFrames(session)
            if finishStatus != noErr {
                errors.append(.finishDelayedFramesFailed(finishStatus))
            }
            let waitStatus = VTDecompressionSessionWaitForAsynchronousFrames(session)
            if waitStatus != noErr {
                errors.append(.waitForAsynchronousFramesFailed(waitStatus))
            }
            VTDecompressionSessionInvalidate(session)
            callbackBridge.detach()
            return errors
        }
    }

    deinit {
        if let session = lock.withLock({ () -> VTDecompressionSession? in
            defer { self.session = nil }
            return self.session
        }) {
            VTDecompressionSessionInvalidate(session)
        }
        callbackBridge.detach()
    }
}

actor VideoDecoder {
    typealias EventSink = @Sendable (VideoDecoderEvent) -> Void

    private let factory: any VideoDecompressionSessionCreating
    private let sampleBufferFactory: VideoSampleBufferFactory
    private let eventSink: EventSink
    private var generation: UInt64 = 0
    private var activeGeneration: UInt64?
    private var formatDescription: CMVideoFormatDescription?
    private var colorMetadata: VideoColorMetadata?
    private var session: (any VideoDecompressionSessionOwning)?

    init(
        factory: any VideoDecompressionSessionCreating = VideoToolboxDecompressionSessionFactory(),
        sampleBufferFactory: VideoSampleBufferFactory? = nil,
        eventSink: @escaping EventSink = { _ in }
    ) throws {
        self.factory = factory
        self.sampleBufferFactory = try sampleBufferFactory ?? VideoSampleBufferFactory()
        self.eventSink = eventSink
    }

    deinit {
        _ = session?.finishAndInvalidate()
    }

    @discardableResult
    func replaceSession(
        formatDescription: CMVideoFormatDescription,
        colorMetadata: VideoColorMetadata
    ) throws -> UInt64 {
        do {
            try colorMetadata.validate()
        } catch let error as VideoColorMetadataError {
            throw VideoDecoderError.invalidColorMetadata(error)
        }
        guard let bitDepth = VideoOutputBitDepth(rawValue: colorMetadata.bitDepth) else {
            throw VideoDecoderError.invalidColorMetadata(
                .invalidBitDepth(colorMetadata.bitDepth)
            )
        }
        generation &+= 1
        let nextGeneration = generation
        stopCurrentSession()

        let bridge = VideoDecompressionCallbackBridge(
            generation: nextGeneration,
            decoder: self
        )
        do {
            let session = try factory.makeSession(
                formatDescription: formatDescription,
                bitDepth: bitDepth,
                callbackBridge: bridge
            )
            self.formatDescription = formatDescription
            self.colorMetadata = colorMetadata
            self.session = session
            activeGeneration = nextGeneration
            eventSink(.sessionStarted(
                generation: nextGeneration,
                colorMetadata: colorMetadata
            ))
            return nextGeneration
        } catch let error as VideoDecoderError {
            bridge.detach()
            eventSink(.failure(VideoDecoderFailure(
                generation: nextGeneration,
                frameID: nil,
                error: error
            )))
            throw error
        }
    }

    @discardableResult
    func decode(_ sample: CompressedVideoSample) throws -> VideoDecodeSubmission {
        guard let generation = activeGeneration,
              let formatDescription,
              colorMetadata != nil,
              let session else {
            throw VideoDecoderError.noActiveSession
        }

        let sampleBuffer: CMSampleBuffer
        do {
            sampleBuffer = try sampleBufferFactory.make(
                sample: sample,
                formatDescription: formatDescription
            )
        } catch let error as VideoDecoderError {
            eventSink(.failure(VideoDecoderFailure(
                generation: generation,
                frameID: sample.frameID,
                error: error
            )))
            throw error
        }

        switch session.decode(
            sampleBuffer,
            generation: generation,
            frameID: sample.frameID
        ) {
        case let .success(submission):
            return submission
        case let .failure(error):
            eventSink(.failure(VideoDecoderFailure(
                generation: generation,
                frameID: sample.frameID,
                error: error
            )))
            throw error
        }
    }

    func stop() {
        stopCurrentSession()
    }

    fileprivate func receive(_ output: VideoDecompressionOutput) {
        guard output.generation == activeGeneration else { return }
        if output.status != noErr {
            eventSink(.failure(VideoDecoderFailure(
                generation: output.generation,
                frameID: output.frameID,
                error: .callbackFailed(output.status)
            )))
            return
        }
        if output.infoFlags.contains(.frameDropped) {
            eventSink(.frameDropped(
                generation: output.generation,
                frameID: output.frameID,
                infoFlags: output.infoFlags
            ))
            return
        }
        guard let pixelBuffer = output.imageBuffer else {
            eventSink(.failure(VideoDecoderFailure(
                generation: output.generation,
                frameID: output.frameID,
                error: .callbackMissingImageBuffer
            )))
            return
        }
        guard let colorMetadata else { return }
        eventSink(.frame(DecodedVideoFrame(
            generation: output.generation,
            frameID: output.frameID,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: output.presentationTimeStamp,
            duration: output.duration,
            infoFlags: output.infoFlags,
            colorMetadata: colorMetadata
        )))
    }

    private func stopCurrentSession() {
        guard let generation = activeGeneration, let session else {
            activeGeneration = nil
            formatDescription = nil
            colorMetadata = nil
            self.session = nil
            return
        }
        activeGeneration = nil
        formatDescription = nil
        colorMetadata = nil
        self.session = nil
        for error in session.finishAndInvalidate() {
            eventSink(.failure(VideoDecoderFailure(
                generation: generation,
                frameID: nil,
                error: error
            )))
        }
        eventSink(.sessionStopped(generation: generation))
    }
}
