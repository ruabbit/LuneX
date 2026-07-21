@preconcurrency import CoreVideo
import XCTest

final class HDRDecodedVideoContractTests: XCTestCase {
    func testActualNV12PixelBufferValidatesRec709SDR() throws {
        let pixelBuffer = try makePixelBuffer(
            format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        )

        let contract = try HDRDecodedVideoContractValidator.validate(
            pixelBuffer: pixelBuffer,
            codec: .h264,
            colorMetadata: .rec709VideoRange()
        )

        XCTAssertEqual(contract.pixelLayout, .nv12VideoRange8)
        XCTAssertEqual(contract.width, 64)
        XCTAssertEqual(contract.height, 48)
        XCTAssertEqual(contract.codec, .h264)
        XCTAssertEqual(
            contract.colorSignature,
            HDRRenderColorSignature(metadata: .rec709VideoRange())
        )
    }

    func testActualP010PixelBufferValidatesHDR10ForTenBitCodecs() throws {
        let pixelBuffer = try makePixelBuffer(
            format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        )
        let masteringDisplay = VideoMasteringDisplayMetadata(
            displayPrimaries: [
                VideoChromaticityPoint(x: 35_400, y: 14_600),
                VideoChromaticityPoint(x: 8_500, y: 39_850),
                VideoChromaticityPoint(x: 6_550, y: 2_300)
            ],
            whitePoint: VideoChromaticityPoint(x: 15_635, y: 16_450),
            maximumDisplayLuminanceNits: 1_000,
            minimumDisplayLuminanceTenThousandths: 5
        )
        let contentLight = VideoContentLightMetadata(
            maximumContentLightLevelNits: 900,
            maximumFrameAverageLightLevelNits: 400
        )
        let metadata = VideoColorMetadata.hdr10VideoRange(
            masteringDisplay: masteringDisplay,
            contentLight: contentLight,
            maximumFullFrameLuminanceNits: 600
        )

        for codec in [NegotiatedVideoCodec.hevc, .av1] {
            let contract = try HDRDecodedVideoContractValidator.validate(
                pixelBuffer: pixelBuffer,
                codec: codec,
                colorMetadata: metadata
            )
            XCTAssertEqual(contract.pixelLayout, .p010VideoRange10)
            XCTAssertEqual(contract.codec, codec)
            XCTAssertEqual(contract.colorSignature.dynamicRange, .hdr10)
            XCTAssertEqual(contract.colorSignature.masteringDisplay, masteringDisplay)
            XCTAssertEqual(contract.colorSignature.contentLight, contentLight)
            XCTAssertEqual(contract.colorSignature.maximumFullFrameLuminanceNits, 600)
        }
    }

    func testFullRangeAndUnsupportedPixelFormatsFailClosed() throws {
        let fullRange = try makePixelBuffer(
            format: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
        )
        XCTAssertThrowsError(try HDRDecodedVideoContractValidator.validate(
            pixelBuffer: fullRange,
            codec: .h264,
            colorMetadata: .rec709VideoRange()
        )) { error in
            XCTAssertEqual(
                error as? HDRDecodedVideoContractError,
                .unsupportedSignalRange(.full)
            )
        }

        let bgra = try makePixelBuffer(format: kCVPixelFormatType_32BGRA)
        XCTAssertThrowsError(try HDRDecodedVideoContractValidator.validate(
            pixelBuffer: bgra,
            codec: .h264,
            colorMetadata: .rec709VideoRange()
        )) { error in
            XCTAssertEqual(
                error as? HDRDecodedVideoContractError,
                .unsupportedPixelFormat(kCVPixelFormatType_32BGRA)
            )
        }
    }

    func testSyntheticLayoutRejectsInvalidDimensionsAndPlanes() {
        assertLayoutError(
            layout(width: 0, height: 48),
            equals: .invalidDimensions
        )
        assertLayoutError(
            layout(planes: [HDRDecodedPlaneDimensions(width: 64, height: 48)]),
            equals: .invalidPlaneCount(1)
        )
        assertLayoutError(
            layout(planes: [
                HDRDecodedPlaneDimensions(width: 63, height: 48),
                HDRDecodedPlaneDimensions(width: 32, height: 24)
            ]),
            equals: .invalidPlaneDimensions(.luma)
        )
        assertLayoutError(
            layout(planes: [
                HDRDecodedPlaneDimensions(width: 64, height: 48),
                HDRDecodedPlaneDimensions(width: 31, height: 24)
            ]),
            equals: .invalidPlaneDimensions(.chroma)
        )
    }

    func testPixelLayoutAndMetadataBitDepthMustMatch() {
        assertError(
            layout: layout(),
            metadata: .hdr10VideoRange(),
            equals: .incompatibleBitDepth(expected: 10, actual: 8)
        )
        assertError(
            layout: layout(
                pixelFormat: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            ),
            metadata: .rec709VideoRange(),
            equals: .incompatibleBitDepth(expected: 8, actual: 10)
        )
        assertError(
            layout: layout(
                pixelFormat: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            ),
            metadata: .rec709VideoRange(bitDepth: 10),
            equals: .incompatibleBitDepth(expected: 8, actual: 10)
        )
    }

    func testHDR10RejectsH264AndEveryColorFieldMismatch() {
        let p010 = layout(
            pixelFormat: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        )
        assertError(
            layout: p010,
            codec: .h264,
            metadata: .hdr10VideoRange(),
            equals: .incompatibleCodec(.h264, .hdr10)
        )

        var metadata = VideoColorMetadata.hdr10VideoRange()
        metadata.colorPrimaries = .ituR709
        assertError(
            layout: p010,
            metadata: metadata,
            equals: .incompatiblePrimaries(expected: .ituR2020, actual: .ituR709)
        )
        metadata = .hdr10VideoRange()
        metadata.transferFunction = .ituR709
        assertError(
            layout: p010,
            metadata: metadata,
            equals: .incompatibleTransfer(expected: .smpteST2084PQ, actual: .ituR709)
        )
        metadata = .hdr10VideoRange()
        metadata.yCbCrMatrix = .ituR709
        assertError(
            layout: p010,
            metadata: metadata,
            equals: .incompatibleMatrix(expected: .ituR2020, actual: .ituR709)
        )
    }

    func testSDRRejectsColorMismatchFullRangeAndHDRLightMetadata() {
        var metadata = VideoColorMetadata.rec709VideoRange()
        metadata.colorPrimaries = .ituR2020
        assertError(
            layout: layout(),
            metadata: metadata,
            equals: .incompatiblePrimaries(expected: .ituR709, actual: .ituR2020)
        )
        metadata = .rec709VideoRange()
        metadata.transferFunction = .smpteST2084PQ
        assertError(
            layout: layout(),
            metadata: metadata,
            equals: .incompatibleTransfer(expected: .ituR709, actual: .smpteST2084PQ)
        )
        metadata = .rec709VideoRange()
        metadata.yCbCrMatrix = .ituR2020
        assertError(
            layout: layout(),
            metadata: metadata,
            equals: .incompatibleMatrix(expected: .ituR709, actual: .ituR2020)
        )
        metadata = .rec709VideoRange()
        metadata.isFullRange = true
        assertError(
            layout: layout(),
            metadata: metadata,
            equals: .unsupportedSignalRange(.full)
        )
        metadata = .rec709VideoRange()
        metadata.contentLight = VideoContentLightMetadata(
            maximumContentLightLevelNits: 1_000,
            maximumFrameAverageLightLevelNits: 400
        )
        assertError(
            layout: layout(),
            metadata: metadata,
            equals: .unexpectedHDRMetadata
        )
    }

    func testInvalidHDRLightMetadataReturnsTypedError() {
        var metadata = VideoColorMetadata.hdr10VideoRange()
        metadata.masteringDisplay = VideoMasteringDisplayMetadata(
            displayPrimaries: [
                VideoChromaticityPoint(x: 1, y: 1),
                VideoChromaticityPoint(x: 2, y: 2),
                VideoChromaticityPoint(x: 3, y: 3)
            ],
            whitePoint: VideoChromaticityPoint(x: 4, y: 4),
            maximumDisplayLuminanceNits: 0,
            minimumDisplayLuminanceTenThousandths: 0
        )

        assertError(
            layout: layout(
                pixelFormat: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            ),
            metadata: metadata,
            equals: .invalidColorMetadata(.invalidMasteringDisplay)
        )
    }

    private func assertLayoutError(
        _ pixelLayout: HDRDecodedPixelBufferLayout,
        equals expected: HDRDecodedVideoContractError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        assertError(
            layout: pixelLayout,
            metadata: .rec709VideoRange(),
            equals: expected,
            file: file,
            line: line
        )
    }

    private func assertError(
        layout: HDRDecodedPixelBufferLayout,
        codec: NegotiatedVideoCodec = .hevc,
        metadata: VideoColorMetadata,
        equals expected: HDRDecodedVideoContractError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try HDRDecodedVideoContractValidator.validate(
            layout: layout,
            codec: codec,
            colorMetadata: metadata
        ), file: file, line: line) { error in
            XCTAssertEqual(
                error as? HDRDecodedVideoContractError,
                expected,
                file: file,
                line: line
            )
        }
    }

    private func layout(
        pixelFormat: OSType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        width: Int = 64,
        height: Int = 48,
        planes: [HDRDecodedPlaneDimensions]? = nil
    ) -> HDRDecodedPixelBufferLayout {
        HDRDecodedPixelBufferLayout(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            planes: planes ?? [
                HDRDecodedPlaneDimensions(width: width, height: height),
                HDRDecodedPlaneDimensions(
                    width: width / 2 + width % 2,
                    height: height / 2 + height % 2
                )
            ]
        )
    }

    private func makePixelBuffer(format: OSType) throws -> CVPixelBuffer {
        let attributes: [CFString: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey: [:] as CFDictionary,
            kCVPixelBufferMetalCompatibilityKey: true
        ]
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            64,
            48,
            format,
            attributes as CFDictionary,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        return try XCTUnwrap(pixelBuffer)
    }
}
