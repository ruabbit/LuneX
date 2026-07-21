import Foundation

enum HDRSourceDynamicRange: String, Codable, Hashable, Sendable {
    case sdr
    case hdr10
}

enum HDRVideoSignalRange: String, Codable, Hashable, Sendable {
    case video
    case full
}

struct HDRRenderColorSignature: Codable, Hashable, Sendable {
    let bitDepth: Int
    let dynamicRange: HDRSourceDynamicRange
    let primaries: VideoColorPrimaries
    let transferFunction: VideoTransferFunction
    let matrix: VideoYCbCrMatrix
    let signalRange: HDRVideoSignalRange
    let masteringDisplay: VideoMasteringDisplayMetadata?
    let contentLight: VideoContentLightMetadata?
    let maximumFullFrameLuminanceNits: UInt16?

    init(metadata: VideoColorMetadata) {
        bitDepth = metadata.bitDepth
        dynamicRange = metadata.isHDR ? .hdr10 : .sdr
        primaries = metadata.colorPrimaries
        transferFunction = metadata.transferFunction
        matrix = metadata.yCbCrMatrix
        signalRange = metadata.isFullRange ? .full : .video
        masteringDisplay = metadata.masteringDisplay
        contentLight = metadata.contentLight
        maximumFullFrameLuminanceNits = metadata.maximumFullFrameLuminanceNits
    }
}

struct HDRDisplayRevision: RawRepresentable, Comparable, Codable, Hashable, Sendable {
    let rawValue: UInt64

    init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    static func < (left: HDRDisplayRevision, right: HDRDisplayRevision) -> Bool {
        left.rawValue < right.rawValue
    }
}

enum AppleRenderingPlatform: String, Codable, Hashable, Sendable {
    case macOS
    case iOS
    case tvOS
    case visionOS
}

enum HDRDisplayHeadroomSource: String, Codable, Hashable, Sendable {
    case unavailable
    case currentAndPotential
    case currentPotentialAndReference
}

enum HDRExtendedRangeSurfaceSupport: String, Codable, Hashable, Sendable {
    case unavailable
    case intentOnly
    case intentAndMetadata
}

enum HDROutputGamut: String, Codable, Hashable, Sendable {
    case sRGB
    case displayP3
    case ituR2020
}

struct HDRPlatformOutputCapabilities: Codable, Hashable, Sendable {
    let platform: AppleRenderingPlatform
    let headroomSource: HDRDisplayHeadroomSource
    let extendedRangeSurfaceSupport: HDRExtendedRangeSurfaceSupport
    let supportedEDRGamuts: Set<HDROutputGamut>
    let supportsSDRToneMapping: Bool
}

enum HDRMappingMode: String, Codable, Hashable, Sendable {
    case sdr
    case hdrEDR
    case hdrToSDR
}

enum HDRDrawablePixelFormat: String, Codable, Hashable, Sendable {
    case bgra8UnormSRGB
    case rgba16Float
}

enum HDROutputColorSpace: String, Codable, Hashable, Sendable {
    case sRGB
    case extendedLinearDisplayP3
    case extendedLinearITUR2020
}

enum HDRExtendedRangeIntent: String, Codable, Hashable, Sendable {
    case disabled
    case enabled
}

enum HDRSurfaceMetadataMode: String, Codable, Hashable, Sendable {
    case none
    case hdr10
}

struct HDRSurfaceContract: Hashable, Sendable {
    let drawablePixelFormat: HDRDrawablePixelFormat
    let outputColorSpace: HDROutputColorSpace
    let outputGamut: HDROutputGamut
    let extendedRangeIntent: HDRExtendedRangeIntent
    let metadataMode: HDRSurfaceMetadataMode

    init(
        drawablePixelFormat: HDRDrawablePixelFormat,
        outputColorSpace: HDROutputColorSpace,
        outputGamut: HDROutputGamut,
        extendedRangeIntent: HDRExtendedRangeIntent,
        metadataMode: HDRSurfaceMetadataMode
    ) throws {
        let isSDR = drawablePixelFormat == .bgra8UnormSRGB
            && outputColorSpace == .sRGB
            && outputGamut == .sRGB
            && extendedRangeIntent == .disabled
            && metadataMode == .none
        let isDisplayP3EDR = drawablePixelFormat == .rgba16Float
            && outputColorSpace == .extendedLinearDisplayP3
            && outputGamut == .displayP3
            && extendedRangeIntent == .enabled
            && metadataMode == .hdr10
        let isITU2020EDR = drawablePixelFormat == .rgba16Float
            && outputColorSpace == .extendedLinearITUR2020
            && outputGamut == .ituR2020
            && extendedRangeIntent == .enabled
            && metadataMode == .hdr10
        guard isSDR || isDisplayP3EDR || isITU2020EDR else {
            throw HDRRenderResolutionError.unsupportedSurfaceContract
        }
        self.drawablePixelFormat = drawablePixelFormat
        self.outputColorSpace = outputColorSpace
        self.outputGamut = outputGamut
        self.extendedRangeIntent = extendedRangeIntent
        self.metadataMode = metadataMode
    }
}

struct HDRRenderConfigurationIdentity: Hashable, Sendable {
    let decoderGeneration: UInt64
    let colorSignature: HDRRenderColorSignature
    let displayRevision: HDRDisplayRevision
    let mappingMode: HDRMappingMode
    let surfaceContract: HDRSurfaceContract

    init(
        decoderGeneration: UInt64,
        colorSignature: HDRRenderColorSignature,
        displayRevision: HDRDisplayRevision,
        mappingMode: HDRMappingMode,
        surfaceContract: HDRSurfaceContract
    ) throws {
        guard decoderGeneration > 0 else {
            throw HDRRenderResolutionError.inactiveSession
        }
        guard displayRevision.rawValue > 0 else {
            throw HDRRenderResolutionError.invalidDisplayRevision
        }
        let expectsHDRSource = mappingMode != .sdr
        let usesHDRSource = colorSignature.dynamicRange == .hdr10
        guard expectsHDRSource == usesHDRSource else {
            throw HDRRenderResolutionError.incompatibleSourceAndMapping
        }
        let expectsEDRSurface = mappingMode == .hdrEDR
        let usesEDRSurface = surfaceContract.extendedRangeIntent == .enabled
        guard expectsEDRSurface == usesEDRSurface else {
            throw HDRRenderResolutionError.incompatibleMappingAndSurface
        }
        self.decoderGeneration = decoderGeneration
        self.colorSignature = colorSignature
        self.displayRevision = displayRevision
        self.mappingMode = mappingMode
        self.surfaceContract = surfaceContract
    }
}

enum HDRRenderResolutionError: Error, Equatable, Hashable, Sendable,
    CustomStringConvertible {
    case inactiveSession
    case invalidSourceContract
    case incompatibleSourceAndMapping
    case unsupportedDecodedLayout
    case incompatibleDecodedLayout
    case unsupportedPlatformOutput(AppleRenderingPlatform)
    case missingCurrentDisplayHeadroom
    case invalidCurrentDisplayHeadroom
    case userDisabledHDRWithoutSDRFallback
    case unsupportedSurfaceContract
    case incompatibleMappingAndSurface
    case staleDecoderGeneration(expected: UInt64, actual: UInt64)
    case staleDisplayRevision(expected: HDRDisplayRevision, actual: HDRDisplayRevision)
    case invalidDisplayRevision
    case displayRevisionExhausted

    var description: String {
        switch self {
        case .inactiveSession:
            return "No active stream session owns an HDR render configuration."
        case .invalidSourceContract:
            return "The source color contract is invalid."
        case .incompatibleSourceAndMapping:
            return "The source dynamic range and HDR mapping mode are incompatible."
        case .unsupportedDecodedLayout:
            return "The decoded video layout is unsupported."
        case .incompatibleDecodedLayout:
            return "The decoded video layout does not match the source color contract."
        case let .unsupportedPlatformOutput(platform):
            return "HDR output is unsupported on \(platform.rawValue)."
        case .missingCurrentDisplayHeadroom:
            return "Current display headroom is unavailable."
        case .invalidCurrentDisplayHeadroom:
            return "Current display headroom is invalid."
        case .userDisabledHDRWithoutSDRFallback:
            return "HDR is disabled and no SDR tone-map fallback is available."
        case .unsupportedSurfaceContract:
            return "The requested HDR surface contract is unsupported."
        case .incompatibleMappingAndSurface:
            return "The HDR mapping mode and surface contract are incompatible."
        case let .staleDecoderGeneration(expected, actual):
            return "Decoder generation \(actual) is stale; expected \(expected)."
        case let .staleDisplayRevision(expected, actual):
            return "Display revision \(actual.rawValue) is stale; expected \(expected.rawValue)."
        case .invalidDisplayRevision:
            return "No active display revision owns the render configuration."
        case .displayRevisionExhausted:
            return "The display revision counter is exhausted."
        }
    }
}
