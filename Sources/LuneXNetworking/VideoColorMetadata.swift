@preconcurrency import CoreMedia
import Foundation

enum VideoColorMetadataError: Error, Equatable, Hashable, Sendable,
    CustomStringConvertible {
    case invalidBitDepth(Int)
    case inconsistentDynamicRange
    case invalidMasteringDisplay
    case invalidContentLight
    case invalidFullFrameLuminance

    var description: String {
        switch self {
        case let .invalidBitDepth(bitDepth):
            return "Video bit depth \(bitDepth) is unsupported."
        case .inconsistentDynamicRange:
            return "Video colorspace and HDR state are inconsistent."
        case .invalidMasteringDisplay:
            return "Mastering display metadata is incomplete or outside protocol bounds."
        case .invalidContentLight:
            return "Content-light metadata contains no usable light level."
        case .invalidFullFrameLuminance:
            return "Maximum full-frame luminance must be positive when present."
        }
    }
}

enum VideoColorPrimaries: String, Codable, Equatable, Hashable, Sendable {
    case ituR709
    case ituR2020

    var coreMediaValue: CFString {
        switch self {
        case .ituR709:
            return kCMFormatDescriptionColorPrimaries_ITU_R_709_2
        case .ituR2020:
            return kCMFormatDescriptionColorPrimaries_ITU_R_2020
        }
    }
}

enum VideoTransferFunction: String, Codable, Equatable, Hashable, Sendable {
    case ituR709
    case smpteST2084PQ

    var coreMediaValue: CFString {
        switch self {
        case .ituR709:
            return kCMFormatDescriptionTransferFunction_ITU_R_709_2
        case .smpteST2084PQ:
            return kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ
        }
    }
}

enum VideoYCbCrMatrix: String, Codable, Equatable, Hashable, Sendable {
    case ituR709
    case ituR2020

    var coreMediaValue: CFString {
        switch self {
        case .ituR709:
            return kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2
        case .ituR2020:
            return kCMFormatDescriptionYCbCrMatrix_ITU_R_2020
        }
    }
}

struct VideoChromaticityPoint: Codable, Equatable, Hashable, Sendable {
    var x: UInt16
    var y: UInt16

    fileprivate var isProtocolNormalized: Bool {
        x <= 50_000 && y <= 50_000
    }
}

struct VideoMasteringDisplayMetadata: Codable, Equatable, Hashable, Sendable {
    static let primaryCount = 3

    /// RGB order, normalized to 50,000 as sent by Sunshine.
    var displayPrimaries: [VideoChromaticityPoint]
    var whitePoint: VideoChromaticityPoint
    var maximumDisplayLuminanceNits: UInt16
    var minimumDisplayLuminanceTenThousandths: UInt16

    func validate() throws {
        guard displayPrimaries.count == Self.primaryCount,
              displayPrimaries.allSatisfy(\.isProtocolNormalized),
              displayPrimaries.allSatisfy({ $0.x != 0 || $0.y != 0 }),
              whitePoint.isProtocolNormalized,
              whitePoint.x != 0 || whitePoint.y != 0,
              maximumDisplayLuminanceNits > 0,
              UInt32(minimumDisplayLuminanceTenThousandths)
                <= UInt32(maximumDisplayLuminanceNits) * 10_000 else {
            throw VideoColorMetadataError.invalidMasteringDisplay
        }
    }

    func coreMediaData() throws -> Data {
        try validate()
        var data = Data()
        data.reserveCapacity(24)
        // ISO/IEC 23008-2 MDCV uses GBR order while Sunshine reports RGB.
        for index in [1, 2, 0] {
            data.appendBigEndian(displayPrimaries[index].x)
            data.appendBigEndian(displayPrimaries[index].y)
        }
        data.appendBigEndian(whitePoint.x)
        data.appendBigEndian(whitePoint.y)
        data.appendBigEndian(UInt32(maximumDisplayLuminanceNits) * 10_000)
        data.appendBigEndian(UInt32(minimumDisplayLuminanceTenThousandths))
        return data
    }
}

struct VideoContentLightMetadata: Codable, Equatable, Hashable, Sendable {
    var maximumContentLightLevelNits: UInt16
    var maximumFrameAverageLightLevelNits: UInt16

    func validate() throws {
        guard maximumContentLightLevelNits > 0
                || maximumFrameAverageLightLevelNits > 0 else {
            throw VideoColorMetadataError.invalidContentLight
        }
    }

    func coreMediaData() throws -> Data {
        try validate()
        var data = Data()
        data.reserveCapacity(4)
        data.appendBigEndian(maximumContentLightLevelNits)
        data.appendBigEndian(maximumFrameAverageLightLevelNits)
        return data
    }
}

struct VideoColorMetadata: Codable, Equatable, Hashable, Sendable {
    var bitDepth: Int
    var isHDR: Bool
    var colorPrimaries: VideoColorPrimaries
    var transferFunction: VideoTransferFunction
    var yCbCrMatrix: VideoYCbCrMatrix
    var isFullRange: Bool
    var masteringDisplay: VideoMasteringDisplayMetadata?
    var contentLight: VideoContentLightMetadata?
    var maximumFullFrameLuminanceNits: UInt16?

    static func rec709VideoRange(bitDepth: Int = 8) -> VideoColorMetadata {
        VideoColorMetadata(
            bitDepth: bitDepth,
            isHDR: false,
            colorPrimaries: .ituR709,
            transferFunction: .ituR709,
            yCbCrMatrix: .ituR709,
            isFullRange: false,
            masteringDisplay: nil,
            contentLight: nil,
            maximumFullFrameLuminanceNits: nil
        )
    }

    static func hdr10VideoRange(
        masteringDisplay: VideoMasteringDisplayMetadata? = nil,
        contentLight: VideoContentLightMetadata? = nil,
        maximumFullFrameLuminanceNits: UInt16? = nil
    ) -> VideoColorMetadata {
        VideoColorMetadata(
            bitDepth: 10,
            isHDR: true,
            colorPrimaries: .ituR2020,
            transferFunction: .smpteST2084PQ,
            yCbCrMatrix: .ituR2020,
            isFullRange: false,
            masteringDisplay: masteringDisplay,
            contentLight: contentLight,
            maximumFullFrameLuminanceNits: maximumFullFrameLuminanceNits
        )
    }

    func validate() throws {
        guard [8, 10].contains(bitDepth) else {
            throw VideoColorMetadataError.invalidBitDepth(bitDepth)
        }
        let isHDR10 = bitDepth == 10
            && colorPrimaries == .ituR2020
            && transferFunction == .smpteST2084PQ
            && yCbCrMatrix == .ituR2020
            && !isFullRange
        let isRec709 = colorPrimaries == .ituR709
            && transferFunction == .ituR709
            && yCbCrMatrix == .ituR709
            && !isFullRange
        guard (isHDR && isHDR10) || (!isHDR && isRec709) else {
            throw VideoColorMetadataError.inconsistentDynamicRange
        }
        if !isHDR, masteringDisplay != nil
            || contentLight != nil
            || maximumFullFrameLuminanceNits != nil {
            throw VideoColorMetadataError.inconsistentDynamicRange
        }
        try masteringDisplay?.validate()
        try contentLight?.validate()
        if let maximumFullFrameLuminanceNits,
           maximumFullFrameLuminanceNits == 0 {
            throw VideoColorMetadataError.invalidFullFrameLuminance
        }
    }

    func coreMediaExtensions() throws -> [CFString: Any] {
        try validate()
        var extensions: [CFString: Any] = [
            kCMFormatDescriptionExtension_ColorPrimaries: colorPrimaries.coreMediaValue,
            kCMFormatDescriptionExtension_TransferFunction: transferFunction.coreMediaValue,
            kCMFormatDescriptionExtension_YCbCrMatrix: yCbCrMatrix.coreMediaValue,
            kCMFormatDescriptionExtension_FullRangeVideo: isFullRange,
            kCMFormatDescriptionExtension_BitsPerComponent: bitDepth
        ]
        if let masteringDisplay {
            extensions[kCMFormatDescriptionExtension_MasteringDisplayColorVolume] =
                try masteringDisplay.coreMediaData()
        }
        if let contentLight {
            extensions[kCMFormatDescriptionExtension_ContentLightLevelInfo] =
                try contentLight.coreMediaData()
        }
        return extensions
    }
}

struct SunshineHDRModeMetadata: Equatable, Sendable {
    var isEnabled: Bool
    var masteringDisplay: VideoMasteringDisplayMetadata?
    var contentLight: VideoContentLightMetadata?
    var maximumFullFrameLuminanceNits: UInt16?

    func colorMetadata() throws -> VideoColorMetadata {
        let metadata = isEnabled
            ? VideoColorMetadata.hdr10VideoRange(
                masteringDisplay: masteringDisplay,
                contentLight: contentLight,
                maximumFullFrameLuminanceNits: maximumFullFrameLuminanceNits
            )
            : VideoColorMetadata.rec709VideoRange()
        try metadata.validate()
        return metadata
    }
}

private extension Data {
    mutating func appendBigEndian(_ value: UInt16) {
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value))
    }

    mutating func appendBigEndian(_ value: UInt32) {
        append(UInt8(truncatingIfNeeded: value >> 24))
        append(UInt8(truncatingIfNeeded: value >> 16))
        append(UInt8(truncatingIfNeeded: value >> 8))
        append(UInt8(truncatingIfNeeded: value))
    }
}
