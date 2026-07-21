import Foundation

enum HDRSourcePeakBasis: String, Codable, Hashable, Sendable {
    case masteringDisplay
    case contentLight
    case masteringAndContentLight
    case fallback
}

struct HDRSourcePeak: Hashable, Sendable {
    let luminanceNits: Double
    let basis: HDRSourcePeakBasis
    let wasClamped: Bool
}

struct HDRLuminanceMapping: Hashable, Sendable {
    static let referenceWhiteNits = 100.0
    static let fallbackSourcePeakNits = 1_000.0
    static let maximumSourcePeakNits = 10_000.0
    static let maximumCurrentHeadroom = 64.0
    static let shoulderStrength = 4.0

    let sourcePeak: HDRSourcePeak
    let currentHeadroom: Double

    init(sourcePeak: HDRSourcePeak, currentHeadroom: Double) throws {
        guard sourcePeak.luminanceNits.isFinite,
              sourcePeak.luminanceNits >= Self.referenceWhiteNits,
              sourcePeak.luminanceNits <= Self.maximumSourcePeakNits else {
            throw HDRLuminanceMappingError.invalidSourcePeak
        }
        guard currentHeadroom.isFinite,
              (1...Self.maximumCurrentHeadroom).contains(currentHeadroom) else {
            throw HDRLuminanceMappingError.invalidCurrentHeadroom
        }
        self.sourcePeak = sourcePeak
        self.currentHeadroom = currentHeadroom
    }

    func map(luminanceNits: Double) throws -> Double {
        guard luminanceNits.isFinite, luminanceNits >= 0 else {
            throw HDRLuminanceMappingError.invalidLuminance
        }
        if luminanceNits <= Self.referenceWhiteNits {
            return luminanceNits / Self.referenceWhiteNits
        }
        let boundedLuminance = min(luminanceNits, sourcePeak.luminanceNits)
        let direct = boundedLuminance / Self.referenceWhiteNits
        if sourcePeak.luminanceNits / Self.referenceWhiteNits <= currentHeadroom {
            return min(direct, currentHeadroom)
        }
        guard currentHeadroom > 1 else { return 1 }
        let sourceHeadroom = sourcePeak.luminanceNits / Self.referenceWhiteNits
        let progress = (boundedLuminance - Self.referenceWhiteNits)
            / (sourcePeak.luminanceNits - Self.referenceWhiteNits)
        let compression = (sourceHeadroom - currentHeadroom) / (sourceHeadroom - 1)
        let strength = Self.shoulderStrength * compression
        let shoulder = strength > Double.ulpOfOne
            ? log1p(strength * progress) / log1p(strength)
            : progress
        let result = 1 + (currentHeadroom - 1) * shoulder
        guard result.isFinite else {
            throw HDRLuminanceMappingError.nonFiniteResult
        }
        return min(max(min(result, direct), 1), currentHeadroom)
    }
}

enum HDRLuminanceMappingError: Error, Equatable, Hashable, Sendable,
    CustomStringConvertible {
    case invalidColorMetadata(VideoColorMetadataError)
    case sourceIsNotHDR10
    case invalidSourcePeak
    case invalidCurrentHeadroom
    case invalidLuminance
    case nonFiniteResult

    var description: String {
        switch self {
        case let .invalidColorMetadata(error): "Invalid HDR metadata: \(error)"
        case .sourceIsNotHDR10: "Source-peak resolution requires HDR10 metadata."
        case .invalidSourcePeak: "The resolved HDR source peak is invalid."
        case .invalidCurrentHeadroom: "Current display headroom is invalid."
        case .invalidLuminance: "Input luminance is invalid."
        case .nonFiniteResult: "Luminance mapping produced a non-finite result."
        }
    }
}

enum HDRSourcePeakResolver {
    static func resolve(_ signature: HDRRenderColorSignature) throws -> HDRSourcePeak {
        try resolve(VideoColorMetadata(
            bitDepth: signature.bitDepth,
            isHDR: signature.dynamicRange == .hdr10,
            colorPrimaries: signature.primaries,
            transferFunction: signature.transferFunction,
            yCbCrMatrix: signature.matrix,
            isFullRange: signature.signalRange == .full,
            masteringDisplay: signature.masteringDisplay,
            contentLight: signature.contentLight,
            maximumFullFrameLuminanceNits: signature.maximumFullFrameLuminanceNits
        ))
    }

    static func resolve(_ metadata: VideoColorMetadata) throws -> HDRSourcePeak {
        do { try metadata.validate() } catch let error as VideoColorMetadataError {
            throw HDRLuminanceMappingError.invalidColorMetadata(error)
        }
        guard metadata.isHDR else { throw HDRLuminanceMappingError.sourceIsNotHDR10 }

        let mastering = metadata.masteringDisplay.map {
            Double($0.maximumDisplayLuminanceNits)
        }
        let content = metadata.contentLight.flatMap {
            $0.maximumContentLightLevelNits > 0
                ? Double($0.maximumContentLightLevelNits) : nil
        }
        let raw: Double
        let basis: HDRSourcePeakBasis
        switch (mastering, content) {
        case let (mastering?, content?) where mastering < content:
            (raw, basis) = (mastering, .masteringDisplay)
        case let (mastering?, content?) where content < mastering:
            (raw, basis) = (content, .contentLight)
        case let (mastering?, content?):
            (raw, basis) = ((mastering + content) / 2, .masteringAndContentLight)
        case let (mastering?, nil):
            (raw, basis) = (mastering, .masteringDisplay)
        case let (nil, content?):
            (raw, basis) = (content, .contentLight)
        case (nil, nil):
            (raw, basis) = (HDRLuminanceMapping.fallbackSourcePeakNits, .fallback)
        }
        let bounded = min(max(raw, HDRLuminanceMapping.referenceWhiteNits),
                          HDRLuminanceMapping.maximumSourcePeakNits)
        return HDRSourcePeak(
            luminanceNits: bounded,
            basis: basis,
            wasClamped: bounded != raw
        )
    }
}
