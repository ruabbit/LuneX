@preconcurrency import CoreMedia
@preconcurrency import CoreVideo
import Foundation
@preconcurrency import Metal
import XCTest

final class MetalVideoFrameDeliveryTests: XCTestCase {
    func testProductionDecoderFramesMapToLiveEightAndTenBitMetalPlanes() async throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let mapper = try CVMetalVideoFrameMapper(device: device)

        for codec in [NegotiatedVideoCodec.h264, .hevc] {
            let frame = try await decodeFixture(codec: codec)
            let mapped = try mapper.map(frame)
            let expectedFormats: (MTLPixelFormat, MTLPixelFormat) = codec == .h264
                ? (.r8Unorm, .rg8Unorm)
                : (.r16Unorm, .rg16Unorm)

            XCTAssertTrue(mapped.decodedFrame.pixelBuffer === frame.pixelBuffer)
            XCTAssertEqual(
                mapped.decodedFrame.colorMetadata,
                codec == .h264 ? .rec709VideoRange() : .hdr10VideoRange()
            )
            XCTAssertEqual(mapped.renderBinding, frame.renderBinding)
            XCTAssertNoThrow(try mapped.validateRenderCompatibility(
                with: makeConfiguration(
                    generation: frame.generation,
                    metadata: frame.colorMetadata
                )
            ))
            XCTAssertEqual(mapped.luma.role, .luma)
            XCTAssertEqual(mapped.luma.texture.pixelFormat, expectedFormats.0)
            XCTAssertEqual(mapped.luma.texture.width, 64)
            XCTAssertEqual(mapped.luma.texture.height, 64)
            XCTAssertEqual(mapped.luma.texture.device.registryID, device.registryID)
            XCTAssertEqual(mapped.chroma.role, .chroma)
            XCTAssertEqual(mapped.chroma.texture.pixelFormat, expectedFormats.1)
            XCTAssertEqual(mapped.chroma.texture.width, 32)
            XCTAssertEqual(mapped.chroma.texture.height, 32)
            XCTAssertEqual(mapped.chroma.texture.device.registryID, device.registryID)
            XCTAssertTrue(
                CVMetalTextureGetTexture(mapped.luma.coreVideoTexture) === mapped.luma.texture
            )
            XCTAssertTrue(
                CVMetalTextureGetTexture(mapped.chroma.coreVideoTexture) === mapped.chroma.texture
            )
        }
        mapper.flush()
    }

    func testMapperRejectsPixelLayoutAndColorSignatureMismatches() throws {
        let mapper = try CVMetalVideoFrameMapper(
            device: XCTUnwrap(MTLCreateSystemDefaultDevice())
        )
        let eightBitBuffer = try makeMetalPixelBuffer()
        let tenBitBuffer = try makeMetalPixelBuffer(
            format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        )

        XCTAssertThrowsError(try mapper.map(decodedFrame(
            generation: 1,
            frameID: 1,
            pixelBuffer: eightBitBuffer,
            colorMetadata: .hdr10VideoRange()
        ))) { error in
            XCTAssertEqual(
                error as? MetalFrameDeliveryError,
                .invalidDecodedContract(.incompatibleBitDepth(expected: 10, actual: 8))
            )
        }
        XCTAssertThrowsError(try mapper.map(decodedFrame(
            generation: 1,
            frameID: 2,
            pixelBuffer: tenBitBuffer,
            colorMetadata: .rec709VideoRange()
        ))) { error in
            XCTAssertEqual(
                error as? MetalFrameDeliveryError,
                .invalidDecodedContract(.incompatibleBitDepth(expected: 8, actual: 10))
            )
        }

        var invalidSDR = VideoColorMetadata.rec709VideoRange()
        invalidSDR.colorPrimaries = .ituR2020
        XCTAssertThrowsError(try mapper.map(decodedFrame(
            generation: 1,
            frameID: 3,
            pixelBuffer: eightBitBuffer,
            colorMetadata: invalidSDR
        ))) { error in
            XCTAssertEqual(
                error as? MetalFrameDeliveryError,
                .invalidDecodedContract(.incompatiblePrimaries(
                    expected: .ituR709,
                    actual: .ituR2020
                ))
            )
        }
    }

    func testPlaneContractsAndTextureValidationAreFormatDimensionAndDeviceExplicit() throws {
        let frameContract = HDRValidatedDecodedFrameContract(
            pixelLayout: .nv12VideoRange8,
            width: 65,
            height: 49,
            colorSignature: HDRRenderColorSignature(metadata: .rec709VideoRange())
        )
        let planes = MetalVideoFrameContractResolver.planeContracts(for: frameContract)

        XCTAssertEqual(planes.luma, MetalVideoPlaneContract(
            role: .luma,
            pixelFormat: .r8Unorm,
            dimensions: HDRDecodedPlaneDimensions(width: 65, height: 49)
        ))
        XCTAssertEqual(planes.chroma, MetalVideoPlaneContract(
            role: .chroma,
            pixelFormat: .rg8Unorm,
            dimensions: HDRDecodedPlaneDimensions(width: 33, height: 25)
        ))
        XCTAssertNoThrow(try MetalVideoFrameContractResolver.validateTexture(
            MetalVideoTextureDescriptor(
                pixelFormat: .r8Unorm,
                width: 65,
                height: 49,
                deviceRegistryID: 12
            ),
            against: planes.luma,
            deviceRegistryID: 12
        ))

        XCTAssertThrowsError(try MetalVideoFrameContractResolver.validateTexture(
            MetalVideoTextureDescriptor(
                pixelFormat: .r8Unorm,
                width: 64,
                height: 49,
                deviceRegistryID: 12
            ),
            against: planes.luma,
            deviceRegistryID: 12
        )) { error in
            XCTAssertEqual(
                error as? MetalFrameDeliveryError,
                .unexpectedMetalTextureDimensions(.luma)
            )
        }
        XCTAssertThrowsError(try MetalVideoFrameContractResolver.validateTexture(
            MetalVideoTextureDescriptor(
                pixelFormat: .r16Unorm,
                width: 65,
                height: 49,
                deviceRegistryID: 12
            ),
            against: planes.luma,
            deviceRegistryID: 12
        )) { error in
            XCTAssertEqual(
                error as? MetalFrameDeliveryError,
                .unexpectedMetalTexturePixelFormat(.luma)
            )
        }
        XCTAssertThrowsError(try MetalVideoFrameContractResolver.validateTexture(
            MetalVideoTextureDescriptor(
                pixelFormat: .rg8Unorm,
                width: 33,
                height: 25,
                deviceRegistryID: 11
            ),
            against: planes.chroma,
            deviceRegistryID: 12
        )) { error in
            XCTAssertEqual(
                error as? MetalFrameDeliveryError,
                .unexpectedMetalTextureDevice(.chroma)
            )
        }
    }

    func testDecodedAndMappedFramesRetainImmutableRenderBinding() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let mapper = try CVMetalVideoFrameMapper(device: device)
        let pixelBuffer = try makeMetalPixelBuffer()
        var metadata = VideoColorMetadata.rec709VideoRange()
        let frame = DecodedVideoFrame(
            generation: 7,
            frameID: 70,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: .invalid,
            duration: .invalid,
            infoFlags: [],
            colorMetadata: metadata
        )
        metadata.colorPrimaries = .ituR2020
        let expectedBinding = HDRFrameRenderBinding(
            decoderGeneration: 7,
            colorSignature: HDRRenderColorSignature(metadata: .rec709VideoRange())
        )
        let configuration = try makeConfiguration(
            generation: 7,
            metadata: .rec709VideoRange()
        )

        XCTAssertEqual(frame.renderBinding, expectedBinding)
        XCTAssertNoThrow(try frame.validateRenderCompatibility(with: configuration))

        let mapped = try mapper.map(frame)
        XCTAssertEqual(mapped.renderBinding, expectedBinding)
        XCTAssertNoThrow(try mapped.validateRenderCompatibility(with: configuration))
    }

    func testFrameBindingRejectsStaleGenerationAndColorSignature() throws {
        let mapper = try CVMetalVideoFrameMapper(
            device: XCTUnwrap(MTLCreateSystemDefaultDevice())
        )
        let frame = decodedFrame(
            generation: 3,
            frameID: 30,
            pixelBuffer: try makeMetalPixelBuffer()
        )
        let mapped = try mapper.map(frame)

        XCTAssertThrowsError(try frame.validateRenderCompatibility(
            with: makeConfiguration(generation: 4, metadata: .rec709VideoRange())
        )) { error in
            XCTAssertEqual(
                error as? HDRRenderResolutionError,
                .staleDecoderGeneration(expected: 4, actual: 3)
            )
        }

        var changedMetadata = VideoColorMetadata.rec709VideoRange()
        changedMetadata.maximumFullFrameLuminanceNits = 100
        XCTAssertThrowsError(try mapped.validateRenderCompatibility(
            with: makeConfiguration(generation: 3, metadata: changedMetadata)
        )) { error in
            XCTAssertEqual(error as? HDRRenderResolutionError, .staleColorSignature)
        }
    }

    func testBoundedQueueDropsOldestAndDequeuesNewestWithoutBacklog() async throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let mapper = try CVMetalVideoFrameMapper(device: device)
        let queue = try BoundedMetalFrameQueue(
            configuration: MetalFrameQueueConfiguration(capacity: 2),
            mapper: mapper
        )
        let pixelBuffer = try makeMetalPixelBuffer()
        let renderConfiguration = try makeConfiguration(
            generation: 11,
            metadata: .rec709VideoRange()
        )
        let startResult = await queue.applyRenderConfiguration(renderConfiguration)
        XCTAssertEqual(
            startResult,
            .configurationStarted(
                generation: 11,
                displayRevision: HDRDisplayRevision(rawValue: 1),
                discardedFrames: 0
            )
        )

        for frameID in UInt64(1)...3 {
            let result = try await queue.enqueue(decodedFrame(
                generation: 11,
                frameID: frameID,
                pixelBuffer: pixelBuffer
            ), configuration: renderConfiguration)
            XCTAssertEqual(
                result,
                .enqueued(
                    generation: 11,
                    displayRevision: HDRDisplayRevision(rawValue: 1),
                    frameID: frameID,
                    evictedFrames: frameID == 3 ? 1 : 0
                )
            )
        }

        var snapshot = await queue.snapshot()
        XCTAssertEqual(snapshot.queuedFrameCount, 2)
        XCTAssertEqual(snapshot.enqueuedFrameCount, 3)
        XCTAssertEqual(snapshot.capacityDropCount, 1)

        let latestCandidate = await queue.dequeueLatest(configuration: renderConfiguration)
        let latest = try XCTUnwrap(latestCandidate)
        XCTAssertEqual(latest.frameID, 3)
        snapshot = await queue.snapshot()
        XCTAssertEqual(snapshot.queuedFrameCount, 0)
        XCTAssertEqual(snapshot.deliveredFrameCount, 1)
        XCTAssertEqual(snapshot.latestFrameSupersededCount, 1)
        let emptyLatest = await queue.dequeueLatest(configuration: renderConfiguration)
        XCTAssertNil(emptyLatest)
    }

    func testGenerationReplacementAndStopRejectStaleFramesBeforeMapping() async throws {
        let mapper = CountingMetalFrameMapper(
            delegate: try CVMetalVideoFrameMapper(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        )
        let queue = try BoundedMetalFrameQueue(mapper: mapper)
        let pixelBuffer = try makeMetalPixelBuffer()
        let firstConfiguration = try makeConfiguration(
            generation: 1,
            metadata: .rec709VideoRange()
        )
        let replacementConfiguration = try makeConfiguration(
            generation: 2,
            metadata: .rec709VideoRange(),
            displayRevision: 2
        )
        _ = await queue.applyRenderConfiguration(firstConfiguration)
        _ = try await queue.enqueue(decodedFrame(
            generation: 1,
            frameID: 1,
            pixelBuffer: pixelBuffer
        ), configuration: firstConfiguration)
        let replacementResult = await queue.applyRenderConfiguration(replacementConfiguration)
        XCTAssertEqual(
            replacementResult,
            .configurationStarted(
                generation: 2,
                displayRevision: HDRDisplayRevision(rawValue: 2),
                discardedFrames: 1
            )
        )

        let stale = try await queue.enqueue(decodedFrame(
            generation: 1,
            frameID: 2,
            pixelBuffer: pixelBuffer
        ), configuration: firstConfiguration)
        XCTAssertEqual(
            stale,
            .rejectedStaleGeneration(expected: 2, actual: 1, frameID: 2)
        )
        XCTAssertEqual(mapper.mapCount, 1)
        let staleStopResult = await queue.stopRenderConfiguration(firstConfiguration)
        XCTAssertEqual(staleStopResult, .ignored)
        let activeStopResult = await queue.stopRenderConfiguration(replacementConfiguration)
        XCTAssertEqual(
            activeStopResult,
            .configurationStopped(
                generation: 2,
                displayRevision: HDRDisplayRevision(rawValue: 2),
                discardedFrames: 0
            )
        )

        let inactive = try await queue.enqueue(decodedFrame(
            generation: 2,
            frameID: 3,
            pixelBuffer: pixelBuffer
        ), configuration: replacementConfiguration)
        XCTAssertEqual(inactive, .rejectedInactive(frameID: 3))
        let snapshot = await queue.snapshot()
        XCTAssertNil(snapshot.activeGeneration)
        XCTAssertEqual(snapshot.staleGenerationDropCount, 1)
        XCTAssertEqual(snapshot.generationResetDropCount, 1)
        XCTAssertGreaterThanOrEqual(mapper.flushCount, 2)
    }

    func testRenderConfigurationDrivesQueueLifecycleAndTeardown() async throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let queue = try BoundedMetalFrameQueue(
            mapper: CVMetalVideoFrameMapper(device: device)
        )
        let pixelBuffer = try makeMetalPixelBuffer()
        let renderConfiguration = try makeConfiguration(
            generation: 4,
            metadata: .rec709VideoRange()
        )

        let startResult = await queue.applyRenderConfiguration(renderConfiguration)
        XCTAssertEqual(
            startResult,
            .configurationStarted(
                generation: 4,
                displayRevision: HDRDisplayRevision(rawValue: 1),
                discardedFrames: 0
            )
        )
        let frameResult = try await queue.enqueue(decodedFrame(
            generation: 4,
            frameID: 40,
            pixelBuffer: pixelBuffer
        ), configuration: renderConfiguration)
        XCTAssertEqual(
            frameResult,
            .enqueued(
                generation: 4,
                displayRevision: HDRDisplayRevision(rawValue: 1),
                frameID: 40,
                evictedFrames: 0
            )
        )
        let stopResult = await queue.stopRenderConfiguration(renderConfiguration)
        XCTAssertEqual(
            stopResult,
            .configurationStopped(
                generation: 4,
                displayRevision: HDRDisplayRevision(rawValue: 1),
                discardedFrames: 1
            )
        )
        let emptyLatest = await queue.dequeueLatest(configuration: renderConfiguration)
        XCTAssertNil(emptyLatest)
    }

    func testColorDisplayAndSurfaceTransitionsFlushAndRejectStaleWork() async throws {
        let mapper = CountingMetalFrameMapper(
            delegate: try CVMetalVideoFrameMapper(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        )
        let queue = try BoundedMetalFrameQueue(mapper: mapper)
        let sdrBuffer = try makeMetalPixelBuffer()
        let hdrBuffer = try makeMetalPixelBuffer(
            format: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
        )
        let sdr = try makeConfiguration(
            generation: 7,
            metadata: .rec709VideoRange()
        )
        let hdr = try makeConfiguration(
            generation: 7,
            metadata: .hdr10VideoRange()
        )
        let movedDisplay = try makeConfiguration(
            generation: 7,
            metadata: .hdr10VideoRange(),
            displayRevision: 2
        )
        let sdrFallback = try makeConfiguration(
            generation: 7,
            metadata: .hdr10VideoRange(),
            displayRevision: 2,
            mappingMode: .hdrToSDR
        )

        _ = await queue.applyRenderConfiguration(sdr)
        _ = try await queue.enqueue(decodedFrame(
            generation: 7,
            frameID: 1,
            pixelBuffer: sdrBuffer
        ), configuration: sdr)
        let hdrTransition = await queue.applyRenderConfiguration(hdr)
        XCTAssertEqual(
            hdrTransition,
            .configurationStarted(
                generation: 7,
                displayRevision: HDRDisplayRevision(rawValue: 1),
                discardedFrames: 1
            )
        )
        let staleColor = try await queue.enqueue(decodedFrame(
            generation: 7,
            frameID: 2,
            pixelBuffer: sdrBuffer
        ), configuration: sdr)
        XCTAssertEqual(
            staleColor,
            .rejectedStaleColorSignature(generation: 7, frameID: 2)
        )

        _ = try await queue.enqueue(decodedFrame(
            generation: 7,
            frameID: 3,
            pixelBuffer: hdrBuffer,
            colorMetadata: .hdr10VideoRange()
        ), configuration: hdr)
        let displayTransition = await queue.applyRenderConfiguration(movedDisplay)
        XCTAssertEqual(
            displayTransition,
            .configurationStarted(
                generation: 7,
                displayRevision: HDRDisplayRevision(rawValue: 2),
                discardedFrames: 1
            )
        )
        let staleDisplay = try await queue.enqueue(decodedFrame(
            generation: 7,
            frameID: 4,
            pixelBuffer: hdrBuffer,
            colorMetadata: .hdr10VideoRange()
        ), configuration: hdr)
        XCTAssertEqual(
            staleDisplay,
            .rejectedStaleDisplayRevision(
                expected: HDRDisplayRevision(rawValue: 2),
                actual: HDRDisplayRevision(rawValue: 1),
                frameID: 4
            )
        )

        _ = try await queue.enqueue(decodedFrame(
            generation: 7,
            frameID: 5,
            pixelBuffer: hdrBuffer,
            colorMetadata: .hdr10VideoRange()
        ), configuration: movedDisplay)
        let surfaceTransition = await queue.applyRenderConfiguration(sdrFallback)
        XCTAssertEqual(
            surfaceTransition,
            .configurationStarted(
                generation: 7,
                displayRevision: HDRDisplayRevision(rawValue: 2),
                discardedFrames: 1
            )
        )
        let staleSurface = try await queue.enqueue(decodedFrame(
            generation: 7,
            frameID: 6,
            pixelBuffer: hdrBuffer,
            colorMetadata: .hdr10VideoRange()
        ), configuration: movedDisplay)
        XCTAssertEqual(
            staleSurface,
            .rejectedStaleRenderContract(
                generation: 7,
                displayRevision: HDRDisplayRevision(rawValue: 2),
                frameID: 6
            )
        )

        _ = try await queue.enqueue(decodedFrame(
            generation: 7,
            frameID: 7,
            pixelBuffer: hdrBuffer,
            colorMetadata: .hdr10VideoRange()
        ), configuration: sdrFallback)
        let staleDequeue = await queue.dequeueLatest(configuration: movedDisplay)
        XCTAssertNil(staleDequeue)
        let current = await queue.dequeueLatest(configuration: sdrFallback)
        XCTAssertEqual(current?.frameID, 7)

        let snapshot = await queue.snapshot()
        XCTAssertEqual(snapshot.activeColorSignature, sdrFallback.colorSignature)
        XCTAssertEqual(snapshot.activeDisplayRevision, HDRDisplayRevision(rawValue: 2))
        XCTAssertEqual(snapshot.staleColorSignatureDropCount, 1)
        XCTAssertEqual(snapshot.staleDisplayRevisionDropCount, 1)
        XCTAssertEqual(snapshot.staleRenderContractDropCount, 2)
        XCTAssertEqual(snapshot.renderContractResetDropCount, 3)
        XCTAssertGreaterThanOrEqual(mapper.flushCount, 4)
    }

    func testUnsupportedFormatAndInvalidCapacityFailClosed() async throws {
        XCTAssertThrowsError(try BoundedMetalFrameQueue(
            configuration: MetalFrameQueueConfiguration(capacity: 0),
            mapper: CountingMetalFrameMapper(delegate: nil)
        )) { error in
            XCTAssertEqual(error as? MetalFrameDeliveryError, .invalidQueueCapacity(0))
        }
        XCTAssertThrowsError(try BoundedMetalFrameQueue(
            configuration: MetalFrameQueueConfiguration(capacity: 9),
            mapper: CountingMetalFrameMapper(delegate: nil)
        )) { error in
            XCTAssertEqual(error as? MetalFrameDeliveryError, .invalidQueueCapacity(9))
        }

        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let mapper = try CVMetalVideoFrameMapper(device: device)
        var bgraBuffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(
            kCFAllocatorDefault,
            64,
            64,
            kCVPixelFormatType_32BGRA,
            nil,
            &bgraBuffer
        ), kCVReturnSuccess)
        let frame = decodedFrame(
            generation: 1,
            frameID: 1,
            pixelBuffer: try XCTUnwrap(bgraBuffer)
        )
        XCTAssertThrowsError(try mapper.map(frame)) { error in
            XCTAssertEqual(
                error as? MetalFrameDeliveryError,
                .unsupportedPixelFormat(kCVPixelFormatType_32BGRA)
            )
        }
    }

    private func decodeFixture(codec: NegotiatedVideoCodec) async throws -> DecodedVideoFrame {
        let fixture = try loadFixture().codec(codec)
        let parameterSets = try VideoParameterSetParser().parse(
            Data(spacedMetalFixtureHex: fixture.accessUnitHex),
            codec: codec
        )
        let description = try VideoFormatDescriptionFactory.make(from: parameterSets)
        let events = MetalDecoderEventStore()
        let decoder = try VideoDecoder(eventSink: events.append)
        let colorMetadata = codec == .hevc
            ? VideoColorMetadata.hdr10VideoRange()
            : .rec709VideoRange()
        _ = try await decoder.replaceSession(
            formatDescription: description,
            colorMetadata: colorMetadata
        )
        let frameID = codec == .h264 ? UInt64(264) : UInt64(265)
        _ = try await decoder.decode(CompressedVideoSample(
            frameID: frameID,
            accessUnit: try Data(spacedMetalFixtureHex: fixture.accessUnitHex)
        ))
        let frame = try await events.waitForFrame(frameID: frameID)
        await decoder.stop()
        return frame
    }

    private func decodedFrame(
        generation: UInt64,
        frameID: UInt64,
        pixelBuffer: CVPixelBuffer,
        colorMetadata: VideoColorMetadata = .rec709VideoRange()
    ) -> DecodedVideoFrame {
        DecodedVideoFrame(
            generation: generation,
            frameID: frameID,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: .invalid,
            duration: .invalid,
            infoFlags: [],
            colorMetadata: colorMetadata
        )
    }

    private func makeMetalPixelBuffer(
        format: OSType = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
    ) throws -> CVPixelBuffer {
        let bitDepth: VideoOutputBitDepth = format
            == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange ? .ten : .eight
        let attributes = VideoToolboxDecompressionSessionFactory
            .destinationAttributes(for: bitDepth) as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            64,
            64,
            format,
            attributes,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        return try XCTUnwrap(pixelBuffer)
    }

    private func makeConfiguration(
        generation: UInt64,
        metadata: VideoColorMetadata,
        displayRevision: UInt64 = 1,
        mappingMode: HDRMappingMode? = nil
    ) throws -> HDRRenderConfigurationIdentity {
        let isHDR = metadata.isHDR
        let resolvedMappingMode = mappingMode ?? (isHDR ? .hdrEDR : .sdr)
        let usesEDRSurface = resolvedMappingMode == .hdrEDR
        return try HDRRenderConfigurationIdentity(
            decoderGeneration: generation,
            colorSignature: HDRRenderColorSignature(metadata: metadata),
            displayRevision: HDRDisplayRevision(rawValue: displayRevision),
            mappingMode: resolvedMappingMode,
            surfaceContract: HDRSurfaceContract(
                drawablePixelFormat: usesEDRSurface ? .rgba16Float : .bgra8UnormSRGB,
                outputColorSpace: usesEDRSurface ? .extendedLinearDisplayP3 : .sRGB,
                outputGamut: usesEDRSurface ? .displayP3 : .sRGB,
                extendedRangeIntent: usesEDRSurface ? .enabled : .disabled,
                metadataMode: usesEDRSurface ? .hdr10 : .none
            )
        )
    }

    private func loadFixture() throws -> MetalVideoFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/video/parameter-sets.json")
        return try JSONDecoder().decode(MetalVideoFixture.self, from: Data(contentsOf: url))
    }
}

private final class CountingMetalFrameMapper: MetalVideoFrameMapping, @unchecked Sendable {
    private let lock = NSLock()
    private let delegate: CVMetalVideoFrameMapper?
    private var storedMapCount = 0
    private var storedFlushCount = 0

    var mapCount: Int { lock.withLock { storedMapCount } }
    var flushCount: Int { lock.withLock { storedFlushCount } }

    init(delegate: CVMetalVideoFrameMapper?) {
        self.delegate = delegate
    }

    func map(_ frame: DecodedVideoFrame) throws -> MetalVideoFrame {
        lock.withLock { storedMapCount += 1 }
        guard let delegate else {
            throw MetalFrameDeliveryError.textureCacheCreationFailed(kCVReturnError)
        }
        return try delegate.map(frame)
    }

    func flush() {
        lock.withLock { storedFlushCount += 1 }
        delegate?.flush()
    }
}

private final class MetalDecoderEventStore: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: [DecodedVideoFrame] = []
    private var failures: [VideoDecoderFailure] = []

    func append(_ event: VideoDecoderEvent) {
        lock.withLock {
            switch event {
            case let .frame(frame):
                frames.append(frame)
            case let .failure(failure):
                failures.append(failure)
            case .sessionStarted, .frameDropped, .sessionStopped:
                break
            }
        }
    }

    func waitForFrame(frameID: UInt64) async throws -> DecodedVideoFrame {
        let deadline = ContinuousClock.now + .seconds(2)
        while ContinuousClock.now < deadline {
            if let frame = lock.withLock({ frames.first(where: { $0.frameID == frameID }) }) {
                return frame
            }
            if let failure = lock.withLock({ failures.first(where: { $0.frameID == frameID }) }) {
                throw failure.error
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw MetalVideoFixtureError.timedOut
    }
}

private struct MetalVideoFixture: Decodable {
    struct Codec: Decodable {
        var accessUnitHex: String
    }

    var h264: Codec
    var hevc: Codec

    func codec(_ codec: NegotiatedVideoCodec) throws -> Codec {
        switch codec {
        case .h264: return h264
        case .hevc: return hevc
        case .av1: throw MetalVideoFixtureError.unsupportedCodec
        }
    }
}

private enum MetalVideoFixtureError: Error {
    case invalidHex
    case timedOut
    case unsupportedCodec
}

private extension Data {
    init(spacedMetalFixtureHex: String) throws {
        let fields = spacedMetalFixtureHex.split(whereSeparator: \Character.isWhitespace)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(fields.count)
        for field in fields {
            guard field.count == 2, let byte = UInt8(field, radix: 16) else {
                throw MetalVideoFixtureError.invalidHex
            }
            bytes.append(byte)
        }
        self.init(bytes)
    }
}
