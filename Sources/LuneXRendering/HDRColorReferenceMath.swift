import Foundation

struct HDRColorVector: Hashable, Sendable {
    let x: Double
    let y: Double
    let z: Double

    var components: [Double] { [x, y, z] }
}

struct HDRNormalizedYCbCr: Hashable, Sendable {
    let luma: Double
    let chromaBlue: Double
    let chromaRed: Double
}

enum HDRColorReferenceMathError: Error, Equatable, Hashable, Sendable,
    CustomStringConvertible {
    case unsupportedBitDepth(Int)
    case nonFiniteInput
    case codeValueOutOfRange
    case unboundedNonlinearValue
    case unboundedLinearInput
    case unboundedLinearResult
    case nonFiniteResult

    var description: String {
        switch self {
        case let .unsupportedBitDepth(bitDepth):
            return "Reference color math does not support \(bitDepth)-bit input."
        case .nonFiniteInput:
            return "Reference color math received a non-finite value."
        case .codeValueOutOfRange:
            return "A video code value is outside its bit-depth range."
        case .unboundedNonlinearValue:
            return "A nonlinear color component exceeds the reference math bound."
        case .unboundedLinearInput:
            return "A linear color component exceeds the reference math bound."
        case .unboundedLinearResult:
            return "Linear gamut conversion exceeded the reference math bound."
        case .nonFiniteResult:
            return "Reference color math produced a non-finite value."
        }
    }
}

enum HDRColorReferenceMath {
    static let pqPeakLuminanceNits = 10_000.0
    static let maximumAbsoluteNonlinearComponent = 4.0
    static let maximumAbsoluteLinearComponent = 25_000.0
    static let rec709Alpha = 1.099_296_826_809_442
    static let rec709Beta = 0.018_053_968_510_807
    static let rec709EncodedBreakpoint = 4.5 * rec709Beta

    static func normalizeVideoRange(
        lumaCode: Double,
        chromaBlueCode: Double,
        chromaRedCode: Double,
        bitDepth: Int
    ) throws -> HDRNormalizedYCbCr {
        try requireFinite([lumaCode, chromaBlueCode, chromaRedCode])
        let scale: Double
        switch bitDepth {
        case 8: scale = 1
        case 10: scale = 4
        default: throw HDRColorReferenceMathError.unsupportedBitDepth(bitDepth)
        }
        let maximumCode = Double((1 << bitDepth) - 1)
        guard [lumaCode, chromaBlueCode, chromaRedCode].allSatisfy({
            (0...maximumCode).contains($0)
        }) else {
            throw HDRColorReferenceMathError.codeValueOutOfRange
        }
        return HDRNormalizedYCbCr(
            luma: (lumaCode - 16 * scale) / (219 * scale),
            chromaBlue: (chromaBlueCode - 128 * scale) / (224 * scale),
            chromaRed: (chromaRedCode - 128 * scale) / (224 * scale)
        )
    }

    static func nonlinearRGB(
        from value: HDRNormalizedYCbCr,
        matrix: VideoYCbCrMatrix
    ) throws -> HDRColorVector {
        try requireFinite([value.luma, value.chromaBlue, value.chromaRed])
        let result: HDRColorVector
        switch matrix {
        case .ituR709:
            result = HDRColorVector(
                x: value.luma + 1.5748 * value.chromaRed,
                y: value.luma - 0.187_324 * value.chromaBlue
                    - 0.468_124 * value.chromaRed,
                z: value.luma + 1.8556 * value.chromaBlue
            )
        case .ituR2020:
            result = HDRColorVector(
                x: value.luma + 1.4746 * value.chromaRed,
                y: value.luma - 0.164_553 * value.chromaBlue
                    - 0.571_353 * value.chromaRed,
                z: value.luma + 1.8814 * value.chromaBlue
            )
        }
        let finiteResult = try finite(result)
        guard finiteResult.components.allSatisfy({
            abs($0) <= maximumAbsoluteNonlinearComponent
        }) else {
            throw HDRColorReferenceMathError.unboundedNonlinearValue
        }
        return finiteResult
    }

    static func decodeRec709(_ value: HDRColorVector) throws -> HDRColorVector {
        try requireFinite(value.components)
        guard value.components.allSatisfy({
            abs($0) <= maximumAbsoluteNonlinearComponent
        }) else {
            throw HDRColorReferenceMathError.unboundedNonlinearValue
        }
        return try finite(map(value) { component in
            component < rec709EncodedBreakpoint
                ? component / 4.5
                : pow(
                    (component + rec709Alpha - 1) / rec709Alpha,
                    1 / 0.45
                )
        })
    }

    static func decodePQToNits(_ value: HDRColorVector) throws -> HDRColorVector {
        try requireFinite(value.components)
        guard value.components.allSatisfy({ (0...1).contains($0) }) else {
            throw HDRColorReferenceMathError.codeValueOutOfRange
        }
        let m1 = 2_610.0 / 16_384.0
        let m2 = 2_523.0 / 32.0
        let c1 = 3_424.0 / 4_096.0
        let c2 = 2_413.0 / 128.0
        let c3 = 2_392.0 / 128.0
        return try finite(map(value) { component in
            let powered = pow(component, 1 / m2)
            let numerator = max(powered - c1, 0)
            let denominator = c2 - c3 * powered
            return pqPeakLuminanceNits * pow(numerator / denominator, 1 / m1)
        })
    }

    static func convertLinearGamut(
        _ value: HDRColorVector,
        from source: HDROutputGamut,
        to target: HDROutputGamut
    ) throws -> HDRColorVector {
        try requireFinite(value.components)
        guard value.components.allSatisfy({
            abs($0) <= maximumAbsoluteLinearComponent
        }) else {
            throw HDRColorReferenceMathError.unboundedLinearInput
        }
        guard source != target else { return value }
        let xyz = rgbToXYZ(source).transform(value)
        let result = try finite(xyzToRGB(target).transform(xyz))
        guard result.components.allSatisfy({
            abs($0) <= maximumAbsoluteLinearComponent
        }) else {
            throw HDRColorReferenceMathError.unboundedLinearResult
        }
        return result
    }

    private static func map(
        _ value: HDRColorVector,
        _ transform: (Double) -> Double
    ) -> HDRColorVector {
        HDRColorVector(
            x: transform(value.x),
            y: transform(value.y),
            z: transform(value.z)
        )
    }

    private static func requireFinite(_ values: [Double]) throws {
        guard values.allSatisfy(\.isFinite) else {
            throw HDRColorReferenceMathError.nonFiniteInput
        }
    }

    private static func finite(_ value: HDRColorVector) throws -> HDRColorVector {
        guard value.components.allSatisfy(\.isFinite) else {
            throw HDRColorReferenceMathError.nonFiniteResult
        }
        return value
    }

    private static func rgbToXYZ(_ gamut: HDROutputGamut) -> HDRMatrix3x3 {
        switch gamut {
        case .sRGB:
            HDRMatrix3x3(rows: (
                (0.412_390_799_3, 0.357_584_339_4, 0.180_480_788_4),
                (0.212_639_005_9, 0.715_168_678_8, 0.072_192_315_4),
                (0.019_330_818_7, 0.119_194_779_8, 0.950_532_152_2)
            ))
        case .displayP3:
            HDRMatrix3x3(rows: (
                (0.486_570_948_6, 0.265_667_693_2, 0.198_217_285_2),
                (0.228_974_564_1, 0.691_738_521_8, 0.079_286_914_1),
                (0, 0.045_113_381_9, 1.043_944_368_9)
            ))
        case .ituR2020:
            HDRMatrix3x3(rows: (
                (0.636_958_048_3, 0.144_616_903_6, 0.168_880_975_2),
                (0.262_700_212_0, 0.677_998_071_5, 0.059_301_716_5),
                (0, 0.028_072_693_0, 1.060_985_057_7)
            ))
        }
    }

    private static func xyzToRGB(_ gamut: HDROutputGamut) -> HDRMatrix3x3 {
        switch gamut {
        case .sRGB:
            HDRMatrix3x3(rows: (
                (3.240_969_941_9, -1.537_383_177_6, -0.498_610_760_3),
                (-0.969_243_636_3, 1.875_967_501_5, 0.041_555_057_4),
                (0.055_630_079_7, -0.203_976_958_9, 1.056_971_514_2)
            ))
        case .displayP3:
            HDRMatrix3x3(rows: (
                (2.493_496_911_9, -0.931_383_617_9, -0.402_710_784_5),
                (-0.829_488_969_6, 1.762_664_060_3, 0.023_624_685_8),
                (0.035_845_830_2, -0.076_172_389_3, 0.956_884_524_0)
            ))
        case .ituR2020:
            HDRMatrix3x3(rows: (
                (1.716_651_188_0, -0.355_670_783_8, -0.253_366_281_4),
                (-0.666_684_351_8, 1.616_481_236_6, 0.015_768_545_8),
                (0.017_639_857_4, -0.042_770_613_3, 0.942_103_121_2)
            ))
        }
    }
}

private struct HDRMatrix3x3 {
    let rows: (
        (Double, Double, Double),
        (Double, Double, Double),
        (Double, Double, Double)
    )

    func transform(_ value: HDRColorVector) -> HDRColorVector {
        HDRColorVector(
            x: rows.0.0 * value.x + rows.0.1 * value.y + rows.0.2 * value.z,
            y: rows.1.0 * value.x + rows.1.1 * value.y + rows.1.2 * value.z,
            z: rows.2.0 * value.x + rows.2.1 * value.y + rows.2.2 * value.z
        )
    }
}
