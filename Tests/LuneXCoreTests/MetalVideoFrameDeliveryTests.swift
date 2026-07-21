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
            XCTAssertEqual(mapped.chroma.role, .chroma)
            XCTAssertEqual(mapped.chroma.texture.pixelFormat, expectedFormats.1)
            XCTAssertEqual(mapped.chroma.texture.width, 32)
            XCTAssertEqual(mapped.chroma.texture.height, 32)
            XCTAssertTrue(
                CVMetalTextureGetTexture(mapped.luma.coreVideoTexture) === mapped.luma.texture
            )
            XCTAssertTrue(
                CVMetalTextureGetTexture(mapped.chroma.coreVideoTexture) === mapped.chroma.texture
            )
        }
        mapper.flush()
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
        let startResult = await queue.startGeneration(11)
        XCTAssertEqual(
            startResult,
            .generationStarted(generation: 11, discardedFrames: 0)
        )

        for frameID in UInt64(1)...3 {
            let result = try await queue.enqueue(decodedFrame(
                generation: 11,
                frameID: frameID,
                pixelBuffer: pixelBuffer
            ))
            XCTAssertEqual(
                result,
                .enqueued(
                    generation: 11,
                    frameID: frameID,
                    evictedFrames: frameID == 3 ? 1 : 0
                )
            )
        }

        var snapshot = await queue.snapshot()
        XCTAssertEqual(snapshot.queuedFrameCount, 2)
        XCTAssertEqual(snapshot.enqueuedFrameCount, 3)
        XCTAssertEqual(snapshot.capacityDropCount, 1)

        let latestCandidate = await queue.dequeueLatest()
        let latest = try XCTUnwrap(latestCandidate)
        XCTAssertEqual(latest.frameID, 3)
        snapshot = await queue.snapshot()
        XCTAssertEqual(snapshot.queuedFrameCount, 0)
        XCTAssertEqual(snapshot.deliveredFrameCount, 1)
        XCTAssertEqual(snapshot.latestFrameSupersededCount, 1)
        let emptyLatest = await queue.dequeueLatest()
        XCTAssertNil(emptyLatest)
    }

    func testGenerationReplacementAndStopRejectStaleFramesBeforeMapping() async throws {
        let mapper = CountingMetalFrameMapper(
            delegate: try CVMetalVideoFrameMapper(device: XCTUnwrap(MTLCreateSystemDefaultDevice()))
        )
        let queue = try BoundedMetalFrameQueue(mapper: mapper)
        let pixelBuffer = try makeMetalPixelBuffer()
        _ = await queue.startGeneration(1)
        _ = try await queue.enqueue(decodedFrame(
            generation: 1,
            frameID: 1,
            pixelBuffer: pixelBuffer
        ))
        let replacementResult = await queue.startGeneration(2)
        XCTAssertEqual(
            replacementResult,
            .generationStarted(generation: 2, discardedFrames: 1)
        )

        let stale = try await queue.enqueue(decodedFrame(
            generation: 1,
            frameID: 2,
            pixelBuffer: pixelBuffer
        ))
        XCTAssertEqual(stale, .rejectedStale(generation: 1, frameID: 2))
        XCTAssertEqual(mapper.mapCount, 1)
        let staleStopResult = await queue.stopGeneration(1)
        XCTAssertEqual(staleStopResult, .ignored)
        let activeStopResult = await queue.stopGeneration(2)
        XCTAssertEqual(
            activeStopResult,
            .generationStopped(generation: 2, discardedFrames: 0)
        )

        let inactive = try await queue.enqueue(decodedFrame(
            generation: 2,
            frameID: 3,
            pixelBuffer: pixelBuffer
        ))
        XCTAssertEqual(inactive, .rejectedInactive(frameID: 3))
        let snapshot = await queue.snapshot()
        XCTAssertNil(snapshot.activeGeneration)
        XCTAssertEqual(snapshot.staleGenerationDropCount, 1)
        XCTAssertEqual(snapshot.generationResetDropCount, 1)
        XCTAssertGreaterThanOrEqual(mapper.flushCount, 2)
    }

    func testDecoderEventsDriveQueueGenerationAndTeardown() async throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let queue = try BoundedMetalFrameQueue(
            mapper: CVMetalVideoFrameMapper(device: device)
        )
        let pixelBuffer = try makeMetalPixelBuffer()

        let startResult = try await queue.consume(.sessionStarted(
            generation: 4,
            colorMetadata: .rec709VideoRange()
        ))
        XCTAssertEqual(
            startResult,
            .generationStarted(generation: 4, discardedFrames: 0)
        )
        let frameResult = try await queue.consume(.frame(decodedFrame(
            generation: 4,
            frameID: 40,
            pixelBuffer: pixelBuffer
        )))
        XCTAssertEqual(
            frameResult,
            .enqueued(generation: 4, frameID: 40, evictedFrames: 0)
        )
        let stopResult = try await queue.consume(.sessionStopped(generation: 4))
        XCTAssertEqual(
            stopResult,
            .generationStopped(generation: 4, discardedFrames: 1)
        )
        let emptyLatest = await queue.dequeueLatest()
        XCTAssertNil(emptyLatest)
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
        pixelBuffer: CVPixelBuffer
    ) -> DecodedVideoFrame {
        DecodedVideoFrame(
            generation: generation,
            frameID: frameID,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: .invalid,
            duration: .invalid,
            infoFlags: [],
            colorMetadata: .rec709VideoRange()
        )
    }

    private func makeMetalPixelBuffer() throws -> CVPixelBuffer {
        let attributes = VideoToolboxDecompressionSessionFactory
            .destinationAttributes(for: .eight) as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            64,
            64,
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            attributes,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        return try XCTUnwrap(pixelBuffer)
    }

    private func makeConfiguration(
        generation: UInt64,
        metadata: VideoColorMetadata
    ) throws -> HDRRenderConfigurationIdentity {
        let isHDR = metadata.isHDR
        return try HDRRenderConfigurationIdentity(
            decoderGeneration: generation,
            colorSignature: HDRRenderColorSignature(metadata: metadata),
            displayRevision: HDRDisplayRevision(rawValue: 1),
            mappingMode: isHDR ? .hdrEDR : .sdr,
            surfaceContract: HDRSurfaceContract(
                drawablePixelFormat: isHDR ? .rgba16Float : .bgra8UnormSRGB,
                outputColorSpace: isHDR ? .extendedLinearDisplayP3 : .sRGB,
                outputGamut: isHDR ? .displayP3 : .sRGB,
                extendedRangeIntent: isHDR ? .enabled : .disabled,
                metadataMode: isHDR ? .hdr10 : .none
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
