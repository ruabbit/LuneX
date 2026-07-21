import XCTest

final class HDRColorReferenceMathTests: XCTestCase {
    func testEightAndTenBitVideoRangeNormalizeToSameReferenceValues() throws {
        let eight = try HDRColorReferenceMath.normalizeVideoRange(
            lumaCode: 235,
            chromaBlueCode: 16,
            chromaRedCode: 240,
            bitDepth: 8
        )
        let ten = try HDRColorReferenceMath.normalizeVideoRange(
            lumaCode: 940,
            chromaBlueCode: 64,
            chromaRedCode: 960,
            bitDepth: 10
        )

        assertClose(eight.luma, 1)
        assertClose(eight.chromaBlue, -0.5)
        assertClose(eight.chromaRed, 0.5)
        assertClose(ten.luma, eight.luma)
        assertClose(ten.chromaBlue, eight.chromaBlue)
        assertClose(ten.chromaRed, eight.chromaRed)
    }

    func testNeutralBlackAndWhiteProduceNeutralRGBForBothMatrices() throws {
        for bitDepth in [8, 10] {
            let scale = bitDepth == 8 ? 1.0 : 4.0
            for (lumaCode, expected) in [(16 * scale, 0.0), (235 * scale, 1.0)] {
                let ycbcr = try HDRColorReferenceMath.normalizeVideoRange(
                    lumaCode: lumaCode,
                    chromaBlueCode: 128 * scale,
                    chromaRedCode: 128 * scale,
                    bitDepth: bitDepth
                )
                for matrix in [VideoYCbCrMatrix.ituR709, .ituR2020] {
                    let rgb = try HDRColorReferenceMath.nonlinearRGB(
                        from: ycbcr,
                        matrix: matrix
                    )
                    assertVectorClose(rgb, HDRColorVector(
                        x: expected,
                        y: expected,
                        z: expected
                    ))
                }
            }
        }
    }

    func testRec709InverseTransferKnownBreakpoints() throws {
        let decoded = try HDRColorReferenceMath.decodeRec709(HDRColorVector(
            x: 0,
            y: 0.081,
            z: HDRColorReferenceMath.rec709EncodedBreakpoint
        ))

        assertClose(decoded.x, 0)
        assertClose(decoded.y, 0.018, tolerance: 0.000_000_001)
        assertClose(
            decoded.z,
            HDRColorReferenceMath.rec709Beta,
            tolerance: 0.000_000_000_001
        )
        assertClose(
            try HDRColorReferenceMath.decodeRec709(
                HDRColorVector(x: 1, y: 1, z: 1)
            ).x,
            1
        )
    }

    func testPQEOTFKnownLuminanceVectors() throws {
        let decoded = try HDRColorReferenceMath.decodePQToNits(HDRColorVector(
            x: 0,
            y: 0.508_078_421_5,
            z: 1
        ))

        assertClose(decoded.x, 0, tolerance: 0.000_001)
        assertClose(decoded.y, 100, tolerance: 0.01)
        assertClose(decoded.z, 10_000, tolerance: 0.001)
    }

    func testLinearGamutNeutralAxisAndRoundTripStayStable() throws {
        let neutral = HDRColorVector(x: 0.18, y: 0.18, z: 0.18)
        let p3 = try HDRColorReferenceMath.convertLinearGamut(
            neutral,
            from: .ituR2020,
            to: .displayP3
        )
        assertVectorClose(p3, neutral, tolerance: 0.000_000_1)

        let source = HDRColorVector(x: 0.7, y: 0.2, z: 0.05)
        let sRGB = try HDRColorReferenceMath.convertLinearGamut(
            source,
            from: .ituR2020,
            to: .sRGB
        )
        let roundTrip = try HDRColorReferenceMath.convertLinearGamut(
            sRGB,
            from: .sRGB,
            to: .ituR2020
        )
        assertVectorClose(roundTrip, source, tolerance: 0.000_000_1)
    }

    func testBT2020PrimaryConversionMatchesPublishedMatrixComposition() throws {
        let red = try HDRColorReferenceMath.convertLinearGamut(
            HDRColorVector(x: 1, y: 0, z: 0),
            from: .ituR2020,
            to: .sRGB
        )

        assertClose(red.x, 1.660_491, tolerance: 0.000_001)
        assertClose(red.y, -0.124_550, tolerance: 0.000_001)
        assertClose(red.z, -0.018_151, tolerance: 0.000_001)
    }

    func testInvalidAndNonFiniteInputsFailClosed() {
        XCTAssertThrowsError(try HDRColorReferenceMath.normalizeVideoRange(
            lumaCode: 16,
            chromaBlueCode: 128,
            chromaRedCode: 128,
            bitDepth: 12
        )) { error in
            XCTAssertEqual(error as? HDRColorReferenceMathError, .unsupportedBitDepth(12))
        }
        XCTAssertThrowsError(try HDRColorReferenceMath.normalizeVideoRange(
            lumaCode: 256,
            chromaBlueCode: 128,
            chromaRedCode: 128,
            bitDepth: 8
        )) { error in
            XCTAssertEqual(error as? HDRColorReferenceMathError, .codeValueOutOfRange)
        }
        XCTAssertThrowsError(try HDRColorReferenceMath.decodePQToNits(
            HDRColorVector(x: -0.1, y: 0.5, z: 1)
        )) { error in
            XCTAssertEqual(error as? HDRColorReferenceMathError, .codeValueOutOfRange)
        }
        XCTAssertThrowsError(try HDRColorReferenceMath.decodeRec709(
            HDRColorVector(x: .nan, y: 0, z: 0)
        )) { error in
            XCTAssertEqual(error as? HDRColorReferenceMathError, .nonFiniteInput)
        }
        XCTAssertThrowsError(try HDRColorReferenceMath.decodeRec709(
            HDRColorVector(
                x: HDRColorReferenceMath.maximumAbsoluteNonlinearComponent + 1,
                y: 0,
                z: 0
            )
        )) { error in
            XCTAssertEqual(
                error as? HDRColorReferenceMathError,
                .unboundedNonlinearValue
            )
        }
        XCTAssertThrowsError(try HDRColorReferenceMath.convertLinearGamut(
            HDRColorVector(
                x: HDRColorReferenceMath.maximumAbsoluteLinearComponent + 1,
                y: 0,
                z: 0
            ),
            from: .sRGB,
            to: .displayP3
        )) { error in
            XCTAssertEqual(error as? HDRColorReferenceMathError, .unboundedLinearInput)
        }
        XCTAssertThrowsError(try HDRColorReferenceMath.convertLinearGamut(
            HDRColorVector(
                x: HDRColorReferenceMath.maximumAbsoluteLinearComponent,
                y: 0,
                z: 0
            ),
            from: .ituR2020,
            to: .sRGB
        )) { error in
            XCTAssertEqual(error as? HDRColorReferenceMathError, .unboundedLinearResult)
        }
    }

    private func assertVectorClose(
        _ actual: HDRColorVector,
        _ expected: HDRColorVector,
        tolerance: Double = 0.000_000_001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertClose(actual.x, expected.x, tolerance: tolerance, file: file, line: line)
        assertClose(actual.y, expected.y, tolerance: tolerance, file: file, line: line)
        assertClose(actual.z, expected.z, tolerance: tolerance, file: file, line: line)
    }

    private func assertClose(
        _ actual: Double,
        _ expected: Double,
        tolerance: Double = 0.000_000_001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual, expected, accuracy: tolerance, file: file, line: line)
    }
}
