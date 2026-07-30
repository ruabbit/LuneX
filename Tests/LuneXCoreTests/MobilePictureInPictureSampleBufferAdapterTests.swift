@preconcurrency import CoreMedia
@preconcurrency import CoreVideo
import XCTest

final class MobilePictureInPictureSampleBufferAdapterTests:
    XCTestCase
{
    func testWrapsSameSDRPixelBufferAndPreservesTiming() throws {
        let generation = try XCTUnwrap(makeGeneration())
        let metadata = VideoColorMetadata.rec709VideoRange()
        let pixelBuffer = try makePixelBuffer(
            format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        )
        let frame = makeFrame(
            generation: 7,
            frameID: 41,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: CMTime(value: 90_000, timescale: 90_000),
            duration: CMTime(value: 1, timescale: 60),
            metadata: metadata
        )
        let adapter = try MobilePictureInPictureSampleBufferAdapter(
            generation: generation,
            decoderGeneration: 7,
            colorMetadata: metadata
        )

        let output = try adapter.makeSampleBuffer(
            from: frame,
            generation: generation
        )

        XCTAssertEqual(output.identity.generation, generation)
        XCTAssertEqual(output.identity.decoderGeneration, 7)
        XCTAssertEqual(output.identity.frameID, 41)
        XCTAssertEqual(output.identity.frameContract.width, 64)
        XCTAssertTrue(
            CMSampleBufferGetImageBuffer(output.sampleBuffer) === pixelBuffer
        )
        XCTAssertEqual(
            CMSampleBufferGetPresentationTimeStamp(output.sampleBuffer),
            frame.presentationTimeStamp
        )
        XCTAssertEqual(
            CMSampleBufferGetDuration(output.sampleBuffer),
            frame.duration
        )
        XCTAssertFalse(
            CMSampleBufferGetDecodeTimeStamp(output.sampleBuffer).isValid
        )
        XCTAssertTrue(CMSampleBufferDataIsReady(output.sampleBuffer))
        XCTAssertNil(CMSampleBufferGetDataBuffer(output.sampleBuffer))
        XCTAssertEqual(
            copiedAttachment(
                pixelBuffer,
                key: kCVImageBufferColorPrimariesKey
            ) as? String,
            kCVImageBufferColorPrimaries_ITU_R_709_2 as String
        )
        XCTAssertEqual(
            copiedAttachment(
                pixelBuffer,
                key: kCVImageBufferTransferFunctionKey
            ) as? String,
            kCVImageBufferTransferFunction_ITU_R_709_2 as String
        )
        XCTAssertEqual(
            copiedAttachment(
                pixelBuffer,
                key: kCVImageBufferYCbCrMatrixKey
            ) as? String,
            kCVImageBufferYCbCrMatrix_ITU_R_709_2 as String
        )
        XCTAssertEqual(
            adapter.snapshot(),
            MobilePictureInPictureSampleBufferAdapterSnapshot(
                generation: generation,
                decoderGeneration: 7,
                activeFrameContract: output.identity.frameContract,
                convertedFrameCount: 1,
                rejectedFrameCount: 0,
                formatDescriptionCreationCount: 1,
                retainsOneFormatDescription: true,
                isInvalidated: false
            )
        )
    }

    func testPreservesUnrelatedAttachmentAndAddsHDRMetadata() throws {
        let generation = try XCTUnwrap(makeGeneration())
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
        let pixelBuffer = try makePixelBuffer(
            format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        )
        let unrelatedKey = "dev.lunex.test.unrelated" as CFString
        CVBufferSetAttachment(
            pixelBuffer,
            unrelatedKey,
            "preserved" as CFString,
            .shouldNotPropagate
        )
        let adapter = try MobilePictureInPictureSampleBufferAdapter(
            generation: generation,
            decoderGeneration: 11,
            colorMetadata: metadata
        )

        let output = try adapter.makeSampleBuffer(
            from: makeFrame(
                generation: 11,
                pixelBuffer: pixelBuffer,
                metadata: metadata
            ),
            generation: generation
        )

        XCTAssertTrue(
            CMSampleBufferGetImageBuffer(output.sampleBuffer) === pixelBuffer
        )
        XCTAssertEqual(
            copiedAttachment(pixelBuffer, key: unrelatedKey) as? String,
            "preserved"
        )
        XCTAssertEqual(
            copiedAttachment(
                pixelBuffer,
                key: kCVImageBufferColorPrimariesKey
            ) as? String,
            kCVImageBufferColorPrimaries_ITU_R_2020 as String
        )
        XCTAssertEqual(
            copiedAttachment(
                pixelBuffer,
                key: kCVImageBufferTransferFunctionKey
            ) as? String,
            kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String
        )
        XCTAssertEqual(
            copiedAttachment(
                pixelBuffer,
                key: kCVImageBufferMasteringDisplayColorVolumeKey
            ) as? Data,
            try masteringDisplay.coreMediaData()
        )
        XCTAssertEqual(
            copiedAttachment(
                pixelBuffer,
                key: kCVImageBufferContentLightLevelInfoKey
            ) as? Data,
            try contentLight.coreMediaData()
        )
        let description = try XCTUnwrap(
            CMSampleBufferGetFormatDescription(output.sampleBuffer)
        )
        XCTAssertTrue(
            CMVideoFormatDescriptionMatchesImageBuffer(
                description,
                imageBuffer: pixelBuffer
            )
        )
    }

    func testRejectsStaleGenerationsAndColorMetadata() throws {
        let generation = try XCTUnwrap(makeGeneration())
        let staleGeneration = try XCTUnwrap(makeGeneration(media: 4))
        let metadata = VideoColorMetadata.rec709VideoRange()
        let pixelBuffer = try makePixelBuffer(
            format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        )
        let adapter = try MobilePictureInPictureSampleBufferAdapter(
            generation: generation,
            decoderGeneration: 7,
            colorMetadata: metadata
        )

        assertError(
            try adapter.makeSampleBuffer(
                from: makeFrame(
                    generation: 7,
                    pixelBuffer: pixelBuffer,
                    metadata: metadata
                ),
                generation: staleGeneration
            ),
            equals: .stalePictureInPictureGeneration
        )
        assertError(
            try adapter.makeSampleBuffer(
                from: makeFrame(
                    generation: 8,
                    pixelBuffer: pixelBuffer,
                    metadata: metadata
                ),
                generation: generation
            ),
            equals: .staleDecoderGeneration(expected: 7, actual: 8)
        )
        assertError(
            try adapter.makeSampleBuffer(
                from: makeFrame(
                    generation: 7,
                    pixelBuffer: pixelBuffer,
                    metadata: .rec709VideoRange(bitDepth: 10)
                ),
                generation: generation
            ),
            equals: .staleColorMetadata
        )
        XCTAssertEqual(adapter.snapshot().rejectedFrameCount, 3)
        XCTAssertEqual(adapter.snapshot().convertedFrameCount, 0)
    }

    func testRejectsInvalidTimingDimensionsAndContractReplacement()
        throws
    {
        let generation = try XCTUnwrap(makeGeneration())
        let metadata = VideoColorMetadata.rec709VideoRange()
        let adapter = try MobilePictureInPictureSampleBufferAdapter(
            generation: generation,
            decoderGeneration: 7,
            colorMetadata: metadata
        )
        let regular = try makePixelBuffer(
            format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        )

        assertError(
            try adapter.makeSampleBuffer(
                from: makeFrame(
                    generation: 7,
                    pixelBuffer: regular,
                    presentationTimeStamp: .invalid,
                    metadata: metadata
                ),
                generation: generation
            ),
            equals: .invalidPresentationTimeStamp
        )
        assertError(
            try adapter.makeSampleBuffer(
                from: makeFrame(
                    generation: 7,
                    pixelBuffer: regular,
                    duration: .zero,
                    metadata: metadata
                ),
                generation: generation
            ),
            equals: .invalidDuration
        )
        let tooWide = try makePixelBuffer(
            format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            width:
                MobilePictureInPictureSampleBufferAdapter.maximumDimension + 1,
            height: 2
        )
        assertError(
            try adapter.makeSampleBuffer(
                from: makeFrame(
                    generation: 7,
                    pixelBuffer: tooWide,
                    metadata: metadata
                ),
                generation: generation
            ),
            equals: .dimensionsExceedLimit
        )

        _ = try adapter.makeSampleBuffer(
            from: makeFrame(
                generation: 7,
                pixelBuffer: regular,
                metadata: metadata
            ),
            generation: generation
        )
        let changedDimensions = try makePixelBuffer(
            format: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            width: 32,
            height: 32
        )
        assertError(
            try adapter.makeSampleBuffer(
                from: makeFrame(
                    generation: 7,
                    pixelBuffer: changedDimensions,
                    metadata: metadata
                ),
                generation: generation
            ),
            equals: .incompatibleFrameContract
        )
    }

    func testCachesOnlyOneCompatibleFormatAndInvalidatesIdempotently()
        throws
    {
        let generation = try XCTUnwrap(makeGeneration())
        let metadata = VideoColorMetadata.rec709VideoRange()
        let adapter = try MobilePictureInPictureSampleBufferAdapter(
            generation: generation,
            decoderGeneration: 7,
            colorMetadata: metadata
        )
        for frameID in UInt64(1)...2 {
            _ = try adapter.makeSampleBuffer(
                from: makeFrame(
                    generation: 7,
                    frameID: frameID,
                    pixelBuffer: try makePixelBuffer(
                        format:
                            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                    ),
                    metadata: metadata
                ),
                generation: generation
            )
        }
        XCTAssertEqual(adapter.snapshot().convertedFrameCount, 2)
        XCTAssertEqual(
            adapter.snapshot().formatDescriptionCreationCount,
            1
        )
        XCTAssertTrue(adapter.snapshot().retainsOneFormatDescription)

        adapter.invalidate()
        adapter.invalidate()
        XCTAssertTrue(adapter.snapshot().isInvalidated)
        XCTAssertNil(adapter.snapshot().activeFrameContract)
        XCTAssertFalse(adapter.snapshot().retainsOneFormatDescription)
        assertError(
            try adapter.makeSampleBuffer(
                from: makeFrame(
                    generation: 7,
                    pixelBuffer: try makePixelBuffer(
                        format:
                            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                    ),
                    metadata: metadata
                ),
                generation: generation
            ),
            equals: .invalidated
        )
    }

    func testInitializerRejectsInvalidGenerationInputs() throws {
        let generation = try XCTUnwrap(makeGeneration())
        XCTAssertThrowsError(
            try MobilePictureInPictureSampleBufferAdapter(
                generation: generation,
                decoderGeneration: 0,
                colorMetadata: .rec709VideoRange()
            )
        ) { error in
            XCTAssertEqual(
                error as?
                    MobilePictureInPictureSampleBufferAdapterError,
                .invalidDecoderGeneration
            )
        }
        var invalidMetadata = VideoColorMetadata.rec709VideoRange()
        invalidMetadata.bitDepth = 9
        XCTAssertThrowsError(
            try MobilePictureInPictureSampleBufferAdapter(
                generation: generation,
                decoderGeneration: 1,
                colorMetadata: invalidMetadata
            )
        ) { error in
            XCTAssertEqual(
                error as?
                    MobilePictureInPictureSampleBufferAdapterError,
                .invalidColorMetadata(.invalidBitDepth(9))
            )
        }
    }

    private func assertError<T>(
        _ expression: @autoclosure () throws -> T,
        equals expected: MobilePictureInPictureSampleBufferAdapterError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try expression(), file: file, line: line) {
            XCTAssertEqual(
                $0 as? MobilePictureInPictureSampleBufferAdapterError,
                expected,
                file: file,
                line: line
            )
        }
    }

    private func makeGeneration(
        media: UInt64 = 3,
        pictureInPicture: UInt64 = 5
    ) -> MobilePictureInPictureGeneration? {
        MobilePictureInPictureGeneration(
            mediaGeneration: media,
            pictureInPictureGeneration: pictureInPicture
        )
    }

    private func makeFrame(
        generation: UInt64,
        frameID: UInt64 = 1,
        pixelBuffer: CVPixelBuffer,
        presentationTimeStamp: CMTime =
            CMTime(value: 90_000, timescale: 90_000),
        duration: CMTime = CMTime(value: 1, timescale: 60),
        metadata: VideoColorMetadata
    ) -> DecodedVideoFrame {
        DecodedVideoFrame(
            generation: generation,
            frameID: frameID,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: presentationTimeStamp,
            duration: duration,
            infoFlags: [],
            colorMetadata: metadata
        )
    }

    private func makePixelBuffer(
        format: OSType,
        width: Int = 64,
        height: Int = 48
    ) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            format,
            [
                kCVPixelBufferIOSurfacePropertiesKey:
                    [:] as CFDictionary,
                kCVPixelBufferMetalCompatibilityKey: true
            ] as CFDictionary,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        return try XCTUnwrap(pixelBuffer)
    }

    private func copiedAttachment(
        _ pixelBuffer: CVPixelBuffer,
        key: CFString
    ) -> CFTypeRef? {
        CVBufferCopyAttachment(pixelBuffer, key, nil)
    }
}
