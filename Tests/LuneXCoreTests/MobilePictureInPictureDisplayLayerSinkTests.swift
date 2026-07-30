@preconcurrency import AVFoundation
@preconcurrency import CoreMedia
@preconcurrency import CoreVideo
import XCTest

final class MobilePictureInPictureDisplayLayerSinkTests:
    XCTestCase
{
    @MainActor
    func testReadyRendererEnqueuesCurrentGenerationFrame() throws {
        let generation = try XCTUnwrap(makeGeneration())
        let client = RecordingPictureInPictureDisplayLayerClient()
        let sink = try MobilePictureInPictureDisplayLayerSink(
            generation: generation,
            decoderGeneration: 7,
            client: client
        )
        let sample = try makeSampleBuffer(
            generation: generation,
            decoderGeneration: 7,
            frameID: 41
        ).sample

        XCTAssertEqual(sink.submit(sample), .enqueued)
        XCTAssertEqual(client.enqueuedFrameIDs, [41])
        XCTAssertEqual(sink.snapshot().frameSink.phase, .ready)
        XCTAssertEqual(sink.snapshot().enqueuedFrameCount, 1)
        XCTAssertNil(sink.snapshot().pendingFrameID)
        XCTAssertEqual(client.requestCount, 0)
        XCTAssertEqual(client.stopCount, 0)
    }

    @MainActor
    func testBackpressureKeepsLatestFrameAndBalancesReadiness()
        throws
    {
        let generation = try XCTUnwrap(makeGeneration())
        let client = RecordingPictureInPictureDisplayLayerClient()
        client.isReadyForMoreMediaData = false
        let sink = try MobilePictureInPictureDisplayLayerSink(
            generation: generation,
            decoderGeneration: 7,
            client: client
        )

        XCTAssertEqual(
            sink.submit(try makeSampleBuffer(
                generation: generation,
                decoderGeneration: 7,
                frameID: 1
            ).sample),
            .retainedLatestPending
        )
        XCTAssertEqual(
            sink.submit(try makeSampleBuffer(
                generation: generation,
                decoderGeneration: 7,
                frameID: 2
            ).sample),
            .replacedPending
        )
        XCTAssertEqual(sink.snapshot().pendingFrameID, 2)
        XCTAssertEqual(sink.snapshot().replacedPendingFrameCount, 1)
        XCTAssertEqual(client.requestCount, 1)
        XCTAssertEqual(client.stopCount, 0)

        client.isReadyForMoreMediaData = true
        client.fireReadinessCallback(at: 0)

        XCTAssertEqual(client.enqueuedFrameIDs, [2])
        XCTAssertEqual(client.requestCount, 1)
        XCTAssertEqual(client.stopCount, 1)
        XCTAssertEqual(sink.snapshot().readinessRequestCount, 1)
        XCTAssertEqual(sink.snapshot().readinessStopCount, 1)
        XCTAssertEqual(sink.snapshot().frameSink.phase, .ready)
        XCTAssertNil(sink.snapshot().pendingFrameID)
    }

    @MainActor
    func testStaleReadinessCallbackCannotDrainReplacementRequest()
        throws
    {
        let generation = try XCTUnwrap(makeGeneration())
        let client = RecordingPictureInPictureDisplayLayerClient()
        client.isReadyForMoreMediaData = false
        let sink = try MobilePictureInPictureDisplayLayerSink(
            generation: generation,
            decoderGeneration: 7,
            client: client
        )
        _ = sink.submit(try makeSampleBuffer(
            generation: generation,
            decoderGeneration: 7,
            frameID: 9
        ).sample)

        client.fireReadinessCallback(at: 0)
        XCTAssertEqual(client.requestCount, 2)
        XCTAssertEqual(client.stopCount, 1)

        client.isReadyForMoreMediaData = true
        client.fireReadinessCallback(at: 0)
        XCTAssertTrue(client.enqueuedFrameIDs.isEmpty)
        XCTAssertEqual(client.stopCount, 1)

        client.fireReadinessCallback(at: 1)
        XCTAssertEqual(client.enqueuedFrameIDs, [9])
        XCTAssertEqual(client.requestCount, 2)
        XCTAssertEqual(client.stopCount, 2)
    }

    @MainActor
    func testDirectFrameAfterReadinessRecoveryStopsPendingRequest()
        throws
    {
        let generation = try XCTUnwrap(makeGeneration())
        let client = RecordingPictureInPictureDisplayLayerClient()
        client.isReadyForMoreMediaData = false
        let sink = try MobilePictureInPictureDisplayLayerSink(
            generation: generation,
            decoderGeneration: 7,
            client: client
        )
        _ = sink.submit(try makeSampleBuffer(
            generation: generation,
            decoderGeneration: 7,
            frameID: 1
        ).sample)
        client.isReadyForMoreMediaData = true

        XCTAssertEqual(
            sink.submit(try makeSampleBuffer(
                generation: generation,
                decoderGeneration: 7,
                frameID: 2
            ).sample),
            .enqueued
        )

        XCTAssertEqual(client.enqueuedFrameIDs, [2])
        XCTAssertEqual(client.requestCount, 1)
        XCTAssertEqual(client.stopCount, 1)
        XCTAssertEqual(sink.snapshot().replacedPendingFrameCount, 1)
        XCTAssertNil(sink.snapshot().pendingFrameID)
        client.fireReadinessCallback(at: 0)
        XCTAssertEqual(client.enqueuedFrameIDs, [2])
    }

    @MainActor
    func testFormatChangeAndDiscontinuityFlushPendingFrames()
        throws
    {
        let generation = try XCTUnwrap(makeGeneration())
        let client = RecordingPictureInPictureDisplayLayerClient()
        client.isReadyForMoreMediaData = false
        let sink = try MobilePictureInPictureDisplayLayerSink(
            generation: generation,
            decoderGeneration: 7,
            client: client
        )
        _ = sink.submit(try makeSampleBuffer(
            generation: generation,
            decoderGeneration: 7,
            frameID: 1
        ).sample)
        let hdr = try makeSampleBuffer(
            generation: generation,
            decoderGeneration: 7,
            frameID: 2,
            pixelFormat:
                kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
            metadata: .hdr10VideoRange()
        ).sample

        XCTAssertEqual(sink.submit(hdr), .replacedPending)
        XCTAssertEqual(client.flushRemovingImageValues, [true])
        XCTAssertEqual(sink.snapshot().formatFlushCount, 1)
        XCTAssertEqual(sink.snapshot().pendingFrameID, 2)

        XCTAssertFalse(sink.signalDiscontinuity(
            generation: try XCTUnwrap(makeGeneration(media: 4))
        ))
        XCTAssertTrue(sink.signalDiscontinuity(generation: generation))
        XCTAssertEqual(client.flushRemovingImageValues, [true, true])
        XCTAssertEqual(sink.snapshot().discontinuityFlushCount, 1)
        XCTAssertNil(sink.snapshot().pendingFrameID)
        XCTAssertNil(sink.snapshot().activeFrameContract)
        XCTAssertEqual(client.requestCount, client.stopCount)
    }

    @MainActor
    func testRendererFailureFlushesAndRecoversWithoutRawError()
        throws
    {
        let generation = try XCTUnwrap(makeGeneration())
        let client = RecordingPictureInPictureDisplayLayerClient()
        client.status = .failed
        client.requiresFlushToResumeDecoding = true
        let sink = try MobilePictureInPictureDisplayLayerSink(
            generation: generation,
            decoderGeneration: 7,
            client: client
        )
        XCTAssertEqual(sink.snapshot().failureRecoveryCount, 1)
        XCTAssertEqual(sink.snapshot().frameSink.phase, .ready)

        XCTAssertEqual(
            sink.submit(try makeSampleBuffer(
                generation: generation,
                decoderGeneration: 7,
                frameID: 4
            ).sample),
            .enqueued
        )
        client.failAndNotify()

        XCTAssertEqual(sink.snapshot().failureRecoveryCount, 2)
        XCTAssertEqual(sink.snapshot().frameSink.phase, .ready)
        XCTAssertNil(sink.snapshot().activeFrameContract)
        XCTAssertEqual(client.flushRemovingImageValues, [true, true])
        XCTAssertTrue(client.enqueuedFrameIDs.isEmpty)
    }

    @MainActor
    func testUnrecoverableRendererFailureFailsClosed() throws {
        let generation = try XCTUnwrap(makeGeneration())
        let client = RecordingPictureInPictureDisplayLayerClient()
        client.status = .failed
        client.requiresFlushToResumeDecoding = true
        client.recoversWhenFlushed = false
        let sink = try MobilePictureInPictureDisplayLayerSink(
            generation: generation,
            decoderGeneration: 7,
            client: client
        )

        let outcome = sink.submit(try makeSampleBuffer(
            generation: generation,
            decoderGeneration: 7,
            frameID: 4
        ).sample)

        XCTAssertEqual(outcome, .rejected(.rendererFailed))
        XCTAssertEqual(
            sink.snapshot().frameSink.phase,
            .failed(.frameSinkFailed)
        )
        XCTAssertTrue(client.enqueuedFrameIDs.isEmpty)
    }

    @MainActor
    func testRejectsStaleGenerationAndDecoderWithoutNativeWork()
        throws
    {
        let generation = try XCTUnwrap(makeGeneration())
        let staleGeneration = try XCTUnwrap(makeGeneration(media: 9))
        let client = RecordingPictureInPictureDisplayLayerClient()
        let sink = try MobilePictureInPictureDisplayLayerSink(
            generation: generation,
            decoderGeneration: 7,
            client: client
        )

        XCTAssertEqual(
            sink.submit(try makeSampleBuffer(
                generation: staleGeneration,
                decoderGeneration: 7,
                frameID: 1
            ).sample),
            .rejected(.stalePictureInPictureGeneration)
        )
        XCTAssertEqual(
            sink.submit(try makeSampleBuffer(
                generation: generation,
                decoderGeneration: 8,
                frameID: 2
            ).sample),
            .rejected(.staleDecoderGeneration(
                expected: 7,
                actual: 8
            ))
        )
        XCTAssertEqual(sink.snapshot().rejectedFrameCount, 2)
        XCTAssertTrue(client.enqueuedFrameIDs.isEmpty)
        XCTAssertTrue(client.flushRemovingImageValues.isEmpty)
        XCTAssertEqual(client.requestCount, 0)
    }

    @MainActor
    func testPendingPixelBuffersReleaseOnReplacementAndInvalidate()
        throws
    {
        let generation = try XCTUnwrap(makeGeneration())
        let client = RecordingPictureInPictureDisplayLayerClient()
        client.isReadyForMoreMediaData = false
        let sink = try MobilePictureInPictureDisplayLayerSink(
            generation: generation,
            decoderGeneration: 7,
            client: client
        )
        weak var firstPixelBuffer: CVPixelBuffer?
        weak var secondPixelBuffer: CVPixelBuffer?
        var firstSample: MobilePictureInPictureSampleBuffer?
        var secondSample: MobilePictureInPictureSampleBuffer?

        autoreleasepool {
            let built = try! makeSampleBuffer(
                generation: generation,
                decoderGeneration: 7,
                frameID: 1
            )
            firstPixelBuffer = built.pixelBuffer
            firstSample = built.sample
        }
        _ = sink.submit(try XCTUnwrap(firstSample))
        firstSample = nil
        XCTAssertNotNil(firstPixelBuffer)

        autoreleasepool {
            let built = try! makeSampleBuffer(
                generation: generation,
                decoderGeneration: 7,
                frameID: 2
            )
            secondPixelBuffer = built.pixelBuffer
            secondSample = built.sample
        }
        _ = sink.submit(try XCTUnwrap(secondSample))
        secondSample = nil
        XCTAssertNil(firstPixelBuffer)
        XCTAssertNotNil(secondPixelBuffer)

        sink.invalidate()
        sink.invalidate()
        XCTAssertNil(secondPixelBuffer)
        XCTAssertEqual(client.requestCount, client.stopCount)
        XCTAssertEqual(client.invalidateCount, 1)
        XCTAssertEqual(sink.snapshot().frameSink.phase, .invalidated)
        XCTAssertEqual(
            sink.submit(try makeSampleBuffer(
                generation: generation,
                decoderGeneration: 7,
                frameID: 3
            ).sample),
            .rejected(.invalidated)
        )
    }

    @MainActor
    func testProductionClientOwnsRealDisplayLayerAndInvalidates()
        throws
    {
        let displayLayer = AVSampleBufferDisplayLayer()
        let client = MobilePictureInPictureDisplayLayerClient(
            displayLayer: displayLayer
        )

        XCTAssertTrue(client.displayLayer === displayLayer)
        XCTAssertFalse(client.isInvalidated)
        client.invalidate()
        client.invalidate()
        XCTAssertTrue(client.isInvalidated)
        XCTAssertFalse(client.isReadyForMoreMediaData)
    }

    @MainActor
    func testInitializerRejectsZeroDecoderGeneration() throws {
        XCTAssertThrowsError(
            try MobilePictureInPictureDisplayLayerSink(
                generation: try XCTUnwrap(makeGeneration()),
                decoderGeneration: 0,
                client: RecordingPictureInPictureDisplayLayerClient()
            )
        ) {
            XCTAssertEqual(
                $0 as? MobilePictureInPictureDisplayLayerSinkError,
                .invalidDecoderGeneration
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

    private func makeSampleBuffer(
        generation: MobilePictureInPictureGeneration,
        decoderGeneration: UInt64,
        frameID: UInt64,
        pixelFormat: OSType =
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        metadata: VideoColorMetadata = .rec709VideoRange()
    ) throws -> (
        sample: MobilePictureInPictureSampleBuffer,
        pixelBuffer: CVPixelBuffer
    ) {
        let pixelBuffer = try makePixelBuffer(format: pixelFormat)
        let adapter = try MobilePictureInPictureSampleBufferAdapter(
            generation: generation,
            decoderGeneration: decoderGeneration,
            colorMetadata: metadata
        )
        let frame = DecodedVideoFrame(
            generation: decoderGeneration,
            frameID: frameID,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp:
                CMTime(value: Int64(frameID), timescale: 60),
            duration: CMTime(value: 1, timescale: 60),
            infoFlags: [],
            colorMetadata: metadata
        )
        return (
            try adapter.makeSampleBuffer(
                from: frame,
                generation: generation
            ),
            pixelBuffer
        )
    }

    private func makePixelBuffer(
        format: OSType
    ) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            64,
            48,
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
}

@MainActor
private final class RecordingPictureInPictureDisplayLayerClient:
    MobilePictureInPictureDisplayLayerRendererClient
{
    var status: MobilePictureInPictureVideoRendererStatus = .unknown
    var requiresFlushToResumeDecoding = false
    var isReadyForMoreMediaData = true
    var recoversWhenFlushed = true
    private(set) var enqueuedFrameIDs: [UInt64] = []
    private(set) var flushRemovingImageValues: [Bool] = []
    private(set) var requestCount = 0
    private(set) var stopCount = 0
    private(set) var invalidateCount = 0
    private var stateChangeHandler:
        MobilePictureInPictureRendererCallback?
    private var readinessCallbacks: [
        MobilePictureInPictureRendererCallback
    ] = []
    private var hasActiveReadinessRequest = false
    private var isInvalidated = false

    func setRendererStateChangeHandler(
        _ handler: MobilePictureInPictureRendererCallback?
    ) {
        stateChangeHandler = handler
    }

    func enqueue(
        _ sampleBuffer: MobilePictureInPictureSampleBuffer
    ) {
        guard !isInvalidated else { return }
        enqueuedFrameIDs.append(sampleBuffer.identity.frameID)
        status = .rendering
    }

    func flush(removingDisplayedImage: Bool) {
        guard !isInvalidated else { return }
        flushRemovingImageValues.append(removingDisplayedImage)
        enqueuedFrameIDs.removeAll()
        if recoversWhenFlushed {
            status = .unknown
            requiresFlushToResumeDecoding = false
        }
    }

    func requestMediaDataWhenReady(
        _ handler: @escaping MobilePictureInPictureRendererCallback
    ) {
        guard !isInvalidated else { return }
        requestCount += 1
        hasActiveReadinessRequest = true
        readinessCallbacks.append(handler)
    }

    func stopRequestingMediaData() {
        guard hasActiveReadinessRequest else { return }
        stopCount += 1
        hasActiveReadinessRequest = false
    }

    func invalidate() {
        guard !isInvalidated else { return }
        if hasActiveReadinessRequest {
            stopRequestingMediaData()
        }
        isInvalidated = true
        invalidateCount += 1
        stateChangeHandler = nil
        enqueuedFrameIDs.removeAll()
    }

    func fireReadinessCallback(at index: Int) {
        readinessCallbacks[index]()
    }

    func failAndNotify() {
        status = .failed
        requiresFlushToResumeDecoding = true
        stateChangeHandler?()
    }
}
