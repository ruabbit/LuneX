@preconcurrency import CoreMedia
@preconcurrency import CoreVideo
import Foundation

struct MobilePictureInPictureSampleBufferIdentity:
    Equatable,
    Sendable
{
    let generation: MobilePictureInPictureGeneration
    let decoderGeneration: UInt64
    let frameID: UInt64
    let frameContract: HDRValidatedDecodedFrameContract
}

struct MobilePictureInPictureSampleBuffer: @unchecked Sendable {
    let identity: MobilePictureInPictureSampleBufferIdentity
    let sampleBuffer: CMSampleBuffer
}

enum MobilePictureInPictureSampleBufferAdapterError:
    Error,
    Equatable,
    Sendable,
    CustomStringConvertible
{
    case invalidDecoderGeneration
    case invalidColorMetadata(VideoColorMetadataError)
    case invalidated
    case stalePictureInPictureGeneration
    case staleDecoderGeneration(expected: UInt64, actual: UInt64)
    case staleColorMetadata
    case invalidPresentationTimeStamp
    case invalidDuration
    case invalidDecodedContract(HDRDecodedVideoContractError)
    case dimensionsExceedLimit
    case incompatibleFrameContract
    case formatDescriptionCreationFailed(OSStatus)
    case formatDescriptionMismatch
    case sampleBufferCreationFailed(OSStatus)
    case imageBufferOwnershipLost

    var description: String {
        switch self {
        case .invalidDecoderGeneration:
            return "The PiP sample-buffer adapter requires a decoder generation."
        case let .invalidColorMetadata(error):
            return "The PiP color metadata is invalid: \(error.description)"
        case .invalidated:
            return "The PiP sample-buffer adapter has been invalidated."
        case .stalePictureInPictureGeneration:
            return "The decoded frame belongs to a stale PiP generation."
        case let .staleDecoderGeneration(expected, actual):
            return "Decoder generation \(actual) does not match \(expected)."
        case .staleColorMetadata:
            return "The decoded frame color metadata does not match the adapter."
        case .invalidPresentationTimeStamp:
            return "The decoded frame presentation timestamp is not finite."
        case .invalidDuration:
            return "The decoded frame duration is not finite and positive."
        case let .invalidDecodedContract(error):
            return "The decoded frame contract is invalid: \(error.description)"
        case .dimensionsExceedLimit:
            return "The decoded frame exceeds the PiP dimension limit."
        case .incompatibleFrameContract:
            return "The decoded frame format changed within one adapter generation."
        case let .formatDescriptionCreationFailed(status):
            return "CoreMedia could not create the PiP format description (\(status))."
        case .formatDescriptionMismatch:
            return "The PiP format description does not match the image buffer."
        case let .sampleBufferCreationFailed(status):
            return "CoreMedia could not create the PiP sample buffer (\(status))."
        case .imageBufferOwnershipLost:
            return "The PiP sample buffer did not retain the decoded image buffer."
        }
    }
}

struct MobilePictureInPictureSampleBufferAdapterSnapshot:
    Equatable,
    Sendable
{
    let generation: MobilePictureInPictureGeneration
    let decoderGeneration: UInt64
    let activeFrameContract: HDRValidatedDecodedFrameContract?
    let convertedFrameCount: UInt64
    let rejectedFrameCount: UInt64
    let formatDescriptionCreationCount: UInt64
    let retainsOneFormatDescription: Bool
    let isInvalidated: Bool
}

final class MobilePictureInPictureSampleBufferAdapter:
    @unchecked Sendable
{
    static let maximumDimension =
        Int(MobilePictureInPictureRenderSize.maximumDimension)

    let generation: MobilePictureInPictureGeneration
    let decoderGeneration: UInt64

    private let lock = NSLock()
    private let colorMetadata: VideoColorMetadata
    private let colorSignature: HDRRenderColorSignature
    private var activeFrameContract: HDRValidatedDecodedFrameContract?
    private var formatDescription: CMVideoFormatDescription?
    private var convertedFrameCount: UInt64 = 0
    private var rejectedFrameCount: UInt64 = 0
    private var formatDescriptionCreationCount: UInt64 = 0
    private var isInvalidated = false

    init(
        generation: MobilePictureInPictureGeneration,
        decoderGeneration: UInt64,
        colorMetadata: VideoColorMetadata
    ) throws {
        guard decoderGeneration > 0 else {
            throw MobilePictureInPictureSampleBufferAdapterError
                .invalidDecoderGeneration
        }
        do {
            try colorMetadata.validate()
        } catch let error as VideoColorMetadataError {
            throw MobilePictureInPictureSampleBufferAdapterError
                .invalidColorMetadata(error)
        }
        self.generation = generation
        self.decoderGeneration = decoderGeneration
        self.colorMetadata = colorMetadata
        colorSignature = HDRRenderColorSignature(metadata: colorMetadata)
    }

    func makeSampleBuffer(
        from frame: DecodedVideoFrame,
        generation: MobilePictureInPictureGeneration
    ) throws -> MobilePictureInPictureSampleBuffer {
        try lock.withLock {
            do {
                let output = try makeSampleBufferLocked(
                    from: frame,
                    generation: generation
                )
                increment(&convertedFrameCount)
                return output
            } catch {
                increment(&rejectedFrameCount)
                throw error
            }
        }
    }

    func invalidate() {
        lock.withLock {
            guard !isInvalidated else { return }
            isInvalidated = true
            activeFrameContract = nil
            formatDescription = nil
        }
    }

    func snapshot() -> MobilePictureInPictureSampleBufferAdapterSnapshot {
        lock.withLock {
            MobilePictureInPictureSampleBufferAdapterSnapshot(
                generation: generation,
                decoderGeneration: decoderGeneration,
                activeFrameContract: activeFrameContract,
                convertedFrameCount: convertedFrameCount,
                rejectedFrameCount: rejectedFrameCount,
                formatDescriptionCreationCount:
                    formatDescriptionCreationCount,
                retainsOneFormatDescription: formatDescription != nil,
                isInvalidated: isInvalidated
            )
        }
    }

    private func makeSampleBufferLocked(
        from frame: DecodedVideoFrame,
        generation requestedGeneration: MobilePictureInPictureGeneration
    ) throws -> MobilePictureInPictureSampleBuffer {
        guard !isInvalidated else {
            throw MobilePictureInPictureSampleBufferAdapterError.invalidated
        }
        guard requestedGeneration == generation else {
            throw MobilePictureInPictureSampleBufferAdapterError
                .stalePictureInPictureGeneration
        }
        guard frame.generation == decoderGeneration else {
            throw MobilePictureInPictureSampleBufferAdapterError
                .staleDecoderGeneration(
                    expected: decoderGeneration,
                    actual: frame.generation
                )
        }
        guard frame.colorMetadata == colorMetadata,
              frame.renderBinding.colorSignature == colorSignature else {
            throw MobilePictureInPictureSampleBufferAdapterError
                .staleColorMetadata
        }
        guard frame.presentationTimeStamp.isNumeric else {
            throw MobilePictureInPictureSampleBufferAdapterError
                .invalidPresentationTimeStamp
        }
        guard frame.duration.isNumeric,
              CMTimeCompare(frame.duration, .zero) > 0 else {
            throw MobilePictureInPictureSampleBufferAdapterError
                .invalidDuration
        }

        let frameContract: HDRValidatedDecodedFrameContract
        do {
            frameContract =
                try HDRDecodedVideoContractValidator.validateForMetalMapping(
                    pixelBuffer: frame.pixelBuffer,
                    colorMetadata: frame.colorMetadata
                )
        } catch let error as HDRDecodedVideoContractError {
            throw MobilePictureInPictureSampleBufferAdapterError
                .invalidDecodedContract(error)
        }
        guard frameContract.width <= Self.maximumDimension,
              frameContract.height <= Self.maximumDimension else {
            throw MobilePictureInPictureSampleBufferAdapterError
                .dimensionsExceedLimit
        }
        if let activeFrameContract {
            guard activeFrameContract == frameContract else {
                throw MobilePictureInPictureSampleBufferAdapterError
                    .incompatibleFrameContract
            }
        }

        let attachments: [CFString: Any]
        do {
            attachments = try colorMetadata.coreMediaExtensions()
        } catch let error as VideoColorMetadataError {
            throw MobilePictureInPictureSampleBufferAdapterError
                .invalidColorMetadata(error)
        }
        CVBufferSetAttachments(
            frame.pixelBuffer,
            attachments as CFDictionary,
            .shouldPropagate
        )

        let description = try compatibleFormatDescription(
            for: frame.pixelBuffer
        )
        var timing = CMSampleTimingInfo(
            duration: frame.duration,
            presentationTimeStamp: frame.presentationTimeStamp,
            decodeTimeStamp: .invalid
        )
        var sampleBuffer: CMSampleBuffer?
        let status = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: frame.pixelBuffer,
            formatDescription: description,
            sampleTiming: &timing,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr, let sampleBuffer else {
            throw MobilePictureInPictureSampleBufferAdapterError
                .sampleBufferCreationFailed(status)
        }
        guard let retainedImageBuffer =
                CMSampleBufferGetImageBuffer(sampleBuffer),
              retainedImageBuffer === frame.pixelBuffer else {
            throw MobilePictureInPictureSampleBufferAdapterError
                .imageBufferOwnershipLost
        }
        if activeFrameContract == nil {
            activeFrameContract = frameContract
        }

        return MobilePictureInPictureSampleBuffer(
            identity: MobilePictureInPictureSampleBufferIdentity(
                generation: generation,
                decoderGeneration: frame.generation,
                frameID: frame.frameID,
                frameContract: frameContract
            ),
            sampleBuffer: sampleBuffer
        )
    }

    private func compatibleFormatDescription(
        for pixelBuffer: CVPixelBuffer
    ) throws -> CMVideoFormatDescription {
        if let formatDescription,
           CMVideoFormatDescriptionMatchesImageBuffer(
            formatDescription,
            imageBuffer: pixelBuffer
           ) {
            return formatDescription
        }

        var createdDescription: CMVideoFormatDescription?
        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &createdDescription
        )
        guard status == noErr, let createdDescription else {
            throw MobilePictureInPictureSampleBufferAdapterError
                .formatDescriptionCreationFailed(status)
        }
        guard CMVideoFormatDescriptionMatchesImageBuffer(
            createdDescription,
            imageBuffer: pixelBuffer
        ) else {
            throw MobilePictureInPictureSampleBufferAdapterError
                .formatDescriptionMismatch
        }
        formatDescription = createdDescription
        increment(&formatDescriptionCreationCount)
        return createdDescription
    }

    private func increment(_ value: inout UInt64) {
        if value < .max {
            value += 1
        }
    }
}
