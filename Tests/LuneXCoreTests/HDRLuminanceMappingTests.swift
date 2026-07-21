import XCTest

final class HDRLuminanceMappingTests: XCTestCase {
    func testSourcePeakUsesDeterministicConstrainingMetadata() throws {
        let mastering = mastering(maximum: 1_000)
        var metadata = VideoColorMetadata.hdr10VideoRange(
            masteringDisplay: mastering,
            contentLight: light(maximum: 4_000)
        )
        XCTAssertEqual(try HDRSourcePeakResolver.resolve(metadata), HDRSourcePeak(
            luminanceNits: 1_000, basis: .masteringDisplay, wasClamped: false
        ))
        metadata.contentLight = light(maximum: 600)
        XCTAssertEqual(try HDRSourcePeakResolver.resolve(metadata).basis, .contentLight)
        metadata.contentLight = light(maximum: 1_000)
        XCTAssertEqual(
            try HDRSourcePeakResolver.resolve(metadata).basis,
            .masteringAndContentLight
        )
    }

    func testMissingMetadataUsesConservativeFallback() throws {
        XCTAssertEqual(
            try HDRSourcePeakResolver.resolve(.hdr10VideoRange()),
            HDRSourcePeak(luminanceNits: 1_000, basis: .fallback, wasClamped: false)
        )
    }

    func testSourcePeakIsClampedToDocumentedBounds() throws {
        let low = try HDRSourcePeakResolver.resolve(.hdr10VideoRange(
            contentLight: light(maximum: 50)
        ))
        let high = try HDRSourcePeakResolver.resolve(.hdr10VideoRange(
            contentLight: light(maximum: 20_000)
        ))
        XCTAssertEqual(low.luminanceNits, 100)
        XCTAssertEqual(high.luminanceNits, 10_000)
        XCTAssertTrue(low.wasClamped)
        XCTAssertTrue(high.wasClamped)
    }

    func testReferenceWhiteAndDirectEDRMappingRemainStable() throws {
        let mapping = try HDRLuminanceMapping(
            sourcePeak: HDRSourcePeak(
                luminanceNits: 400, basis: .contentLight, wasClamped: false
            ),
            currentHeadroom: 4
        )
        XCTAssertEqual(try mapping.map(luminanceNits: 0), 0)
        XCTAssertEqual(try mapping.map(luminanceNits: 50), 0.5)
        XCTAssertEqual(try mapping.map(luminanceNits: 100), 1)
        XCTAssertEqual(try mapping.map(luminanceNits: 250), 2.5)
        XCTAssertEqual(try mapping.map(luminanceNits: 400), 4)
    }

    func testCompressedShoulderIsContinuousMonotonicAndBounded() throws {
        let mapping = try HDRLuminanceMapping(
            sourcePeak: HDRSourcePeak(
                luminanceNits: 1_000, basis: .fallback, wasClamped: false
            ),
            currentHeadroom: 2
        )
        let samples = stride(from: 0.0, through: 1_200.0, by: 1).map {
            try! mapping.map(luminanceNits: $0)
        }
        XCTAssertEqual(try mapping.map(luminanceNits: 100), 1)
        XCTAssertGreaterThan(try mapping.map(luminanceNits: 100.001), 1)
        XCTAssertTrue(zip(samples, samples.dropFirst()).allSatisfy { $0 <= $1 })
        XCTAssertTrue(samples.allSatisfy { $0.isFinite && $0 >= 0 && $0 <= 2 })
        XCTAssertEqual(try mapping.map(luminanceNits: 1_000), 2, accuracy: 1e-12)
        XCTAssertEqual(try mapping.map(luminanceNits: 1_200), 2, accuracy: 1e-12)
    }

    func testSDRFallbackPreservesReferenceAndBoundsHighlights() throws {
        let mapping = try HDRLuminanceMapping(
            sourcePeak: HDRSourcePeak(
                luminanceNits: 1_000, basis: .fallback, wasClamped: false
            ),
            currentHeadroom: 1
        )
        XCTAssertEqual(try mapping.map(luminanceNits: 50), 0.5)
        XCTAssertEqual(try mapping.map(luminanceNits: 100), 1)
        XCTAssertEqual(try mapping.map(luminanceNits: 400), 1)
    }

    func testShoulderConvergesContinuouslyAtDirectMappingHeadroom() throws {
        let peak = HDRSourcePeak(
            luminanceNits: 1_000,
            basis: .fallback,
            wasClamped: false
        )
        let headrooms = [1.0, 2, 4, 8, 9.9, 9.999_999, 10]
        let mapped = try headrooms.map { headroom in
            try HDRLuminanceMapping(
                sourcePeak: peak,
                currentHeadroom: headroom
            ).map(luminanceNits: 500)
        }

        XCTAssertTrue(zip(mapped, mapped.dropFirst()).allSatisfy { $0 <= $1 })
        XCTAssertEqual(mapped.last, 5)
        XCTAssertEqual(mapped[mapped.count - 2], 5, accuracy: 0.000_001)
    }

    func testInvalidMetadataHeadroomAndLuminanceFailClosed() throws {
        XCTAssertThrowsError(try HDRSourcePeakResolver.resolve(.rec709VideoRange()))
        let peak = HDRSourcePeak(luminanceNits: 1_000, basis: .fallback, wasClamped: false)
        for headroom in [Double.nan, 0.9, 65] {
            XCTAssertThrowsError(try HDRLuminanceMapping(
                sourcePeak: peak,
                currentHeadroom: headroom
            ))
        }
        let mapping = try HDRLuminanceMapping(sourcePeak: peak, currentHeadroom: 2)
        for luminance in [Double.nan, -.leastNonzeroMagnitude] {
            XCTAssertThrowsError(try mapping.map(luminanceNits: luminance))
        }
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
}
