import XCTest

final class HDRColorPipelineDeterminismTests: XCTestCase {
    func testVideoRangeDomainsRemainFiniteWithinDeclaredExcursions() throws {
        for bitDepth in [8, 10] {
            let maximum = (1 << bitDepth) - 1
            let strideValue = bitDepth == 8 ? 1 : 4
            for code in Swift.stride(from: 0, through: maximum, by: strideValue) {
                let value = try HDRColorReferenceMath.normalizeVideoRange(
                    lumaCode: Double(code),
                    chromaBlueCode: Double(maximum - code),
                    chromaRedCode: Double(code),
                    bitDepth: bitDepth
                )
                XCTAssertTrue(value.luma.isFinite)
                XCTAssertTrue(value.chromaBlue.isFinite)
                XCTAssertTrue(value.chromaRed.isFinite)
                XCTAssertTrue((-0.08...1.1).contains(value.luma))
                XCTAssertTrue((-0.58...0.58).contains(value.chromaBlue))
                XCTAssertTrue((-0.58...0.58).contains(value.chromaRed))
            }
        }
    }

    func testRec709AndPQTransferFunctionsAreMonotonicAndBounded() throws {
        var previousRec709 = -Double.infinity
        var previousPQ = -Double.infinity
        for index in 0...4_096 {
            let encoded = Double(index) / 4_096
            let rec709 = try HDRColorReferenceMath.decodeRec709(
                HDRColorVector(x: encoded, y: encoded, z: encoded)
            ).x
            let pq = try HDRColorReferenceMath.decodePQToNits(
                HDRColorVector(x: encoded, y: encoded, z: encoded)
            ).x
            XCTAssertGreaterThanOrEqual(rec709, previousRec709)
            XCTAssertGreaterThanOrEqual(pq, previousPQ)
            XCTAssertTrue(rec709.isFinite && (0...1).contains(rec709))
            XCTAssertTrue(pq.isFinite && (0...10_000).contains(pq))
            previousRec709 = rec709
            previousPQ = pq
        }
    }

    func testGamutCubeConversionsStayFiniteAndRoundTrip() throws {
        let gamuts: [HDROutputGamut] = [.sRGB, .displayP3, .ituR2020]
        let samples = [0.0, 0.25, 0.5, 0.75, 1]
        for source in gamuts {
            for target in gamuts {
                for red in samples {
                    for green in samples {
                        for blue in samples {
                            let input = HDRColorVector(x: red, y: green, z: blue)
                            let converted = try HDRColorReferenceMath.convertLinearGamut(
                                input,
                                from: source,
                                to: target
                            )
                            XCTAssertTrue(converted.components.allSatisfy(\.isFinite))
                            let roundTrip = try HDRColorReferenceMath.convertLinearGamut(
                                converted,
                                from: target,
                                to: source
                            )
                            assertVector(roundTrip, equals: input, accuracy: 0.000_000_001)
                        }
                    }
                }
            }
        }
    }

    func testShoulderGridIsMonotonicContinuousFiniteAndHeadroomBounded() throws {
        for sourcePeak in [100.0, 400, 1_000, 10_000] {
            for headroom in [1.0, 1.25, 2, 4, 16, 64] {
                let mapping = try HDRLuminanceMapping(
                    sourcePeak: HDRSourcePeak(
                        luminanceNits: sourcePeak,
                        basis: .fallback,
                        wasClamped: false
                    ),
                    currentHeadroom: headroom
                )
                var previous = -Double.infinity
                for index in 0...1_100 {
                    let luminance = sourcePeak * Double(index) / 1_000
                    let mapped = try mapping.map(luminanceNits: luminance)
                    XCTAssertTrue(mapped.isFinite)
                    XCTAssertGreaterThanOrEqual(mapped, previous)
                    XCTAssertTrue((0...headroom).contains(mapped))
                    previous = mapped
                }
                XCTAssertEqual(try mapping.map(luminanceNits: 100), 1)
                let left = try mapping.map(luminanceNits: 100 - 0.000_001)
                let right = try mapping.map(luminanceNits: 100 + 0.000_001)
                XCTAssertEqual(left, 1, accuracy: 0.000_001)
                XCTAssertEqual(right, 1, accuracy: 0.000_001)
            }
        }
    }

    func testSourcePeakMetadataTruthTableAndMissingFallbackAreStable() throws {
        let mastering = mastering(maximum: 1_000)
        let cases: [(VideoColorMetadata, HDRSourcePeakBasis, Double)] = [
            (.hdr10VideoRange(), .fallback, 1_000),
            (.hdr10VideoRange(masteringDisplay: mastering), .masteringDisplay, 1_000),
            (.hdr10VideoRange(contentLight: light(maximum: 600)), .contentLight, 600),
            (.hdr10VideoRange(
                masteringDisplay: mastering,
                contentLight: light(maximum: 600)
            ), .contentLight, 600),
            (.hdr10VideoRange(
                masteringDisplay: mastering,
                contentLight: light(maximum: 1_000)
            ), .masteringAndContentLight, 1_000)
        ]
        for (metadata, basis, peak) in cases {
            let resolved = try HDRSourcePeakResolver.resolve(metadata)
            XCTAssertEqual(resolved.basis, basis)
            XCTAssertEqual(resolved.luminanceNits, peak)
        }
    }

    func testDecodedLayoutCodecAndDynamicRangeTruthTableIsClosed() throws {
        let sdr = layout(format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
        let hdr = layout(format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        for codec in [NegotiatedVideoCodec.h264, .hevc, .av1] {
            XCTAssertNoThrow(try HDRDecodedVideoContractValidator.validate(
                layout: sdr,
                codec: codec,
                colorMetadata: .rec709VideoRange()
            ))
        }
        XCTAssertThrowsError(try HDRDecodedVideoContractValidator.validate(
            layout: hdr,
            codec: .h264,
            colorMetadata: .hdr10VideoRange()
        ))
        for codec in [NegotiatedVideoCodec.hevc, .av1] {
            XCTAssertNoThrow(try HDRDecodedVideoContractValidator.validate(
                layout: hdr,
                codec: codec,
                colorMetadata: .hdr10VideoRange()
            ))
        }
    }

    func testAllReferenceErrorsRemainFinitePrivacyBoundedDescriptions() {
        let errors: [any Error & CustomStringConvertible] = [
            HDRColorReferenceMathError.unsupportedBitDepth(12),
            HDRColorReferenceMathError.nonFiniteInput,
            HDRColorReferenceMathError.codeValueOutOfRange,
            HDRColorReferenceMathError.unboundedNonlinearValue,
            HDRColorReferenceMathError.unboundedLinearInput,
            HDRColorReferenceMathError.unboundedLinearResult,
            HDRColorReferenceMathError.nonFiniteResult,
            HDRLuminanceMappingError.invalidColorMetadata(.invalidContentLight),
            HDRLuminanceMappingError.sourceIsNotHDR10,
            HDRLuminanceMappingError.invalidSourcePeak,
            HDRLuminanceMappingError.invalidCurrentHeadroom,
            HDRLuminanceMappingError.invalidLuminance,
            HDRLuminanceMappingError.nonFiniteResult
        ]
        XCTAssertTrue(errors.allSatisfy { !$0.description.isEmpty })
        XCTAssertTrue(errors.allSatisfy { !$0.description.contains("host") })
        XCTAssertTrue(errors.allSatisfy { !$0.description.contains("displayID") })
    }

    private func layout(format: OSType) -> HDRDecodedPixelBufferLayout {
        HDRDecodedPixelBufferLayout(
            pixelFormat: format,
            width: 64,
            height: 48,
            planes: [
                HDRDecodedPlaneDimensions(width: 64, height: 48),
                HDRDecodedPlaneDimensions(width: 32, height: 24)
            ]
        )
    }

    private func light(maximum: UInt16) -> VideoContentLightMetadata {
        VideoContentLightMetadata(
            maximumContentLightLevelNits: maximum,
            maximumFrameAverageLightLevelNits: min(maximum, 400)
        )
    }

    private func mastering(maximum: UInt16) -> VideoMasteringDisplayMetadata {
        VideoMasteringDisplayMetadata(
            displayPrimaries: [
                VideoChromaticityPoint(x: 35_400, y: 14_600),
                VideoChromaticityPoint(x: 8_500, y: 39_850),
                VideoChromaticityPoint(x: 6_550, y: 2_300)
            ],
            whitePoint: VideoChromaticityPoint(x: 15_635, y: 16_450),
            maximumDisplayLuminanceNits: maximum,
            minimumDisplayLuminanceTenThousandths: 5
        )
    }

    private func assertVector(
        _ actual: HDRColorVector,
        equals expected: HDRColorVector,
        accuracy: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.x, expected.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(actual.z, expected.z, accuracy: accuracy, file: file, line: line)
    }
}
