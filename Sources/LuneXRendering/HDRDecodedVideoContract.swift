@preconcurrency import CoreVideo
import Foundation

enum HDRDecodedPixelLayout: String, Hashable, Sendable {
    case nv12VideoRange8
    case p010VideoRange10

    var bitDepth: Int {
        switch self {
        case .nv12VideoRange8: 8
        case .p010VideoRange10: 10
        }
    }
}

enum HDRDecodedPlaneRole: String, Hashable, Sendable {
    case luma
    case chroma
}

struct HDRDecodedPlaneDimensions: Hashable, Sendable {
    let width: Int
    let height: Int
}

struct HDRDecodedPixelBufferLayout: Hashable, Sendable {
    let pixelFormat: OSType
    let width: Int
    let height: Int
    let planes: [HDRDecodedPlaneDimensions]

    init(pixelBuffer: CVPixelBuffer) {
        pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        width = CVPixelBufferGetWidth(pixelBuffer)
        height = CVPixelBufferGetHeight(pixelBuffer)
        planes = (0..<CVPixelBufferGetPlaneCount(pixelBuffer)).map { index in
            HDRDecodedPlaneDimensions(
                width: CVPixelBufferGetWidthOfPlane(pixelBuffer, index),
                height: CVPixelBufferGetHeightOfPlane(pixelBuffer, index)
            )
        }
    }

    init(
        pixelFormat: OSType,
        width: Int,
        height: Int,
        planes: [HDRDecodedPlaneDimensions]
    ) {
        self.pixelFormat = pixelFormat
        self.width = width
        self.height = height
        self.planes = planes
    }
}

struct HDRValidatedDecodedVideoContract: Hashable, Sendable {
    let pixelLayout: HDRDecodedPixelLayout
    let width: Int
    let height: Int
    let codec: NegotiatedVideoCodec
    let colorSignature: HDRRenderColorSignature
}

struct HDRValidatedDecodedFrameContract: Hashable, Sendable {
    let pixelLayout: HDRDecodedPixelLayout
    let width: Int
    let height: Int
    let colorSignature: HDRRenderColorSignature
}

enum HDRDecodedVideoContractError: Error, Equatable, Hashable, Sendable,
    CustomStringConvertible {
    case unsupportedPixelFormat(OSType)
    case unsupportedSignalRange(HDRVideoSignalRange)
    case invalidDimensions
    case invalidPlaneCount(Int)
    case invalidPlaneDimensions(HDRDecodedPlaneRole)
    case incompatibleBitDepth(expected: Int, actual: Int)
    case incompatibleCodec(NegotiatedVideoCodec, HDRSourceDynamicRange)
    case incompatiblePrimaries(expected: VideoColorPrimaries, actual: VideoColorPrimaries)
    case incompatibleTransfer(
        expected: VideoTransferFunction,
        actual: VideoTransferFunction
    )
    case incompatibleMatrix(expected: VideoYCbCrMatrix, actual: VideoYCbCrMatrix)
    case unexpectedHDRMetadata
    case invalidColorMetadata(VideoColorMetadataError)

    var description: String {
        switch self {
        case .unsupportedPixelFormat:
            return "The decoded CoreVideo pixel format is unsupported."
        case let .unsupportedSignalRange(range):
            return "Decoded \(range.rawValue)-range video is unsupported."
        case .invalidDimensions:
            return "The decoded video dimensions are invalid."
        case let .invalidPlaneCount(count):
            return "The decoded video has \(count) planes instead of two."
        case let .invalidPlaneDimensions(role):
            return "The decoded \(role.rawValue) plane dimensions are invalid."
        case let .incompatibleBitDepth(expected, actual):
            return "Decoded bit depth \(actual) does not match required depth \(expected)."
        case let .incompatibleCodec(codec, dynamicRange):
            return "Codec \(codec.rawValue) cannot carry \(dynamicRange.rawValue) output."
        case .incompatiblePrimaries:
            return "Decoded color primaries do not match the dynamic-range contract."
        case .incompatibleTransfer:
            return "Decoded transfer function does not match the dynamic-range contract."
        case .incompatibleMatrix:
            return "Decoded YCbCr matrix does not match the dynamic-range contract."
        case .unexpectedHDRMetadata:
            return "SDR video contains HDR light metadata."
        case let .invalidColorMetadata(error):
            return "Decoded color metadata is invalid: \(error.description)"
        }
    }
}

enum HDRDecodedVideoContractValidator {
    static func validateForMetalMapping(
        pixelBuffer: CVPixelBuffer,
        colorMetadata: VideoColorMetadata
    ) throws -> HDRValidatedDecodedFrameContract {
        try validateForMetalMapping(
            layout: HDRDecodedPixelBufferLayout(pixelBuffer: pixelBuffer),
            colorMetadata: colorMetadata
        )
    }

    static func validateForMetalMapping(
        layout: HDRDecodedPixelBufferLayout,
        colorMetadata: VideoColorMetadata
    ) throws -> HDRValidatedDecodedFrameContract {
        let pixelLayout = try decodedPixelLayout(for: layout.pixelFormat)
        try validatePlanes(layout)
        try validateColorMetadata(colorMetadata, pixelLayout: pixelLayout)
        return HDRValidatedDecodedFrameContract(
            pixelLayout: pixelLayout,
            width: layout.width,
            height: layout.height,
            colorSignature: HDRRenderColorSignature(metadata: colorMetadata)
        )
    }

    static func validate(
        pixelBuffer: CVPixelBuffer,
        codec: NegotiatedVideoCodec,
        colorMetadata: VideoColorMetadata
    ) throws -> HDRValidatedDecodedVideoContract {
        try validate(
            layout: HDRDecodedPixelBufferLayout(pixelBuffer: pixelBuffer),
            codec: codec,
            colorMetadata: colorMetadata
        )
    }

    static func validate(
        layout: HDRDecodedPixelBufferLayout,
        codec: NegotiatedVideoCodec,
        colorMetadata: VideoColorMetadata
    ) throws -> HDRValidatedDecodedVideoContract {
        let frameContract = try validateForMetalMapping(
            layout: layout,
            colorMetadata: colorMetadata
        )
        try validateCodec(codec, dynamicRange: frameContract.colorSignature.dynamicRange)
        return HDRValidatedDecodedVideoContract(
            pixelLayout: frameContract.pixelLayout,
            width: frameContract.width,
            height: frameContract.height,
            codec: codec,
            colorSignature: frameContract.colorSignature
        )
    }

    private static func decodedPixelLayout(
        for pixelFormat: OSType
    ) throws -> HDRDecodedPixelLayout {
        switch pixelFormat {
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            return .nv12VideoRange8
        case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
            return .p010VideoRange10
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
             kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
            throw HDRDecodedVideoContractError.unsupportedSignalRange(.full)
        default:
            throw HDRDecodedVideoContractError.unsupportedPixelFormat(pixelFormat)
        }
    }

    private static func validatePlanes(_ layout: HDRDecodedPixelBufferLayout) throws {
        guard layout.width > 0, layout.height > 0 else {
            throw HDRDecodedVideoContractError.invalidDimensions
        }
        guard layout.planes.count == 2 else {
            throw HDRDecodedVideoContractError.invalidPlaneCount(layout.planes.count)
        }
        let expectedLuma = HDRDecodedPlaneDimensions(
            width: layout.width,
            height: layout.height
        )
        guard layout.planes[0] == expectedLuma else {
            throw HDRDecodedVideoContractError.invalidPlaneDimensions(.luma)
        }
        let expectedChroma = HDRDecodedPlaneDimensions(
            width: layout.width / 2 + layout.width % 2,
            height: layout.height / 2 + layout.height % 2
        )
        guard layout.planes[1] == expectedChroma else {
            throw HDRDecodedVideoContractError.invalidPlaneDimensions(.chroma)
        }
    }

    private static func validateColorMetadata(
        _ metadata: VideoColorMetadata,
        pixelLayout: HDRDecodedPixelLayout
    ) throws {
        guard metadata.bitDepth == pixelLayout.bitDepth else {
            throw HDRDecodedVideoContractError.incompatibleBitDepth(
                expected: metadata.bitDepth,
                actual: pixelLayout.bitDepth
            )
        }
        guard !metadata.isFullRange else {
            throw HDRDecodedVideoContractError.unsupportedSignalRange(.full)
        }

        if metadata.isHDR {
            guard metadata.bitDepth == 10 else {
                throw HDRDecodedVideoContractError.incompatibleBitDepth(
                    expected: 10,
                    actual: metadata.bitDepth
                )
            }
            guard metadata.colorPrimaries == .ituR2020 else {
                throw HDRDecodedVideoContractError.incompatiblePrimaries(
                    expected: .ituR2020,
                    actual: metadata.colorPrimaries
                )
            }
            guard metadata.transferFunction == .smpteST2084PQ else {
                throw HDRDecodedVideoContractError.incompatibleTransfer(
                    expected: .smpteST2084PQ,
                    actual: metadata.transferFunction
                )
            }
            guard metadata.yCbCrMatrix == .ituR2020 else {
                throw HDRDecodedVideoContractError.incompatibleMatrix(
                    expected: .ituR2020,
                    actual: metadata.yCbCrMatrix
                )
            }
        } else {
            guard metadata.bitDepth == 8 else {
                throw HDRDecodedVideoContractError.incompatibleBitDepth(
                    expected: 8,
                    actual: metadata.bitDepth
                )
            }
            guard metadata.colorPrimaries == .ituR709 else {
                throw HDRDecodedVideoContractError.incompatiblePrimaries(
                    expected: .ituR709,
                    actual: metadata.colorPrimaries
                )
            }
            guard metadata.transferFunction == .ituR709 else {
                throw HDRDecodedVideoContractError.incompatibleTransfer(
                    expected: .ituR709,
                    actual: metadata.transferFunction
                )
            }
            guard metadata.yCbCrMatrix == .ituR709 else {
                throw HDRDecodedVideoContractError.incompatibleMatrix(
                    expected: .ituR709,
                    actual: metadata.yCbCrMatrix
                )
            }
            guard metadata.masteringDisplay == nil,
                  metadata.contentLight == nil,
                  metadata.maximumFullFrameLuminanceNits == nil else {
                throw HDRDecodedVideoContractError.unexpectedHDRMetadata
            }
        }

        do {
            try metadata.validate()
        } catch let error as VideoColorMetadataError {
            throw HDRDecodedVideoContractError.invalidColorMetadata(error)
        }
    }

    private static func validateCodec(
        _ codec: NegotiatedVideoCodec,
        dynamicRange: HDRSourceDynamicRange
    ) throws {
        guard dynamicRange != .hdr10 || codec == .hevc || codec == .av1 else {
            throw HDRDecodedVideoContractError.incompatibleCodec(codec, dynamicRange)
        }
    }
}
