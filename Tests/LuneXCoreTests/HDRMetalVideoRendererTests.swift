import CoreMedia
@preconcurrency import CoreVideo
import Foundation
@preconcurrency import Metal
import XCTest

final class HDRMetalVideoRendererTests: XCTestCase {
    func testGeometryUniformsHaveExactABIAndResolveFitAndFill() throws {
        XCTAssertTrue(HDRMetalGeometryUniforms.hasExpectedMemoryLayout)
        XCTAssertEqual(MemoryLayout<HDRMetalGeometryUniforms>.size, 16)
        XCTAssertEqual(MemoryLayout<HDRMetalGeometryUniforms>.stride, 16)

        let fit = try HDRMetalPresentationGeometryResolver.resolve(XCTUnwrap(
            StreamCoordinateSnapshot.resolve(
                revision: 7,
                sourceSize: PixelSize(width: 64, height: 48),
                drawableSize: PixelSize(width: 1_920, height: 1_080),
                mode: .fit
            )
        ))
        XCTAssertEqual(fit.coordinateRevision, 7)
        XCTAssertEqual(fit.viewport, HDRMetalViewport(
            originX: 240,
            originY: 0,
            width: 1_440,
            height: 1_080
        ))
        XCTAssertEqual(fit.scissorRectangle, HDRMetalScissorRectangle(
            x: 0,
            y: 0,
            width: 1_920,
            height: 1_080
        ))
        XCTAssertEqual(fit.uniforms, HDRMetalGeometryUniforms(
            textureOriginX: 0,
            textureOriginY: 0,
            textureScaleX: 1,
            textureScaleY: 1
        ))

        let fill = try HDRMetalPresentationGeometryResolver.resolve(XCTUnwrap(
            StreamCoordinateSnapshot.resolve(
                revision: 8,
                sourceSize: PixelSize(width: 64, height: 48),
                drawableSize: PixelSize(width: 1_920, height: 1_080),
                mode: .fill
            )
        ))
        XCTAssertEqual(fill.viewport, HDRMetalViewport(
            originX: 0,
            originY: 0,
            width: 1_920,
            height: 1_080
        ))
        XCTAssertEqual(fill.uniforms.textureOriginX, 0, accuracy: .ulpOfOne)
        XCTAssertEqual(fill.uniforms.textureOriginY, 0.125, accuracy: .ulpOfOne)
        XCTAssertEqual(fill.uniforms.textureScaleX, 1, accuracy: .ulpOfOne)
        XCTAssertEqual(fill.uniforms.textureScaleY, 0.75, accuracy: .ulpOfOne)

        let inconsistent = StreamCoordinateSnapshot(
            revision: 9,
            sourceSize: PixelSize(width: 64, height: 48),
            drawableSize: PixelSize(width: 1_920, height: 1_080),
            mode: .fit,
            resolvedVideo: try XCTUnwrap(StreamCoordinateSnapshot.resolve(
                revision: 9,
                sourceSize: PixelSize(width: 64, height: 48),
                drawableSize: PixelSize(width: 1_920, height: 1_080),
                mode: .fill
            )).resolvedVideo
        )
        XCTAssertThrowsError(try HDRMetalPresentationGeometryResolver.resolve(inconsistent)) {
            XCTAssertEqual(
                $0 as? HDRMetalVideoRendererError,
                .invalidCoordinateSnapshot
            )
        }
    }

    func testRendererSubmitsOriginalZeroCopyPlanesAndExplicitGeometry() throws {
        let fixture = try makeFixture(generation: 4, frameID: 44)
        let submitter = RecordingHDRMetalCommandSubmitter()
        let renderer = try makeRenderer(device: fixture.device, submitter: submitter)
        try renderer.replaceConfiguration(fixture.configuration)
        let coordinates = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: 9,
            sourceSize: PixelSize(width: 64, height: 48),
            drawableSize: PixelSize(width: 160, height: 90),
            mode: .fill
        ))
        let target = try makeTarget(
            device: fixture.device,
            width: 160,
            height: 90,
            pixelFormat: .bgra8Unorm_srgb
        )

        let result = try renderer.render(
            frame: fixture.frame,
            configuration: fixture.configuration,
            uniforms: fixture.uniforms,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target)
        )

        XCTAssertEqual(result, .submitted(
            frameID: 44,
            decoderGeneration: 4,
            displayRevision: HDRDisplayRevision(rawValue: 1),
            coordinateRevision: 9
        ))
        let request = try XCTUnwrap(submitter.lastRequest)
        XCTAssertEqual(
            ObjectIdentifier(request.lumaTexture as AnyObject),
            ObjectIdentifier(fixture.frame.luma.texture as AnyObject)
        )
        XCTAssertEqual(
            ObjectIdentifier(request.chromaTexture as AnyObject),
            ObjectIdentifier(fixture.frame.chroma.texture as AnyObject)
        )
        XCTAssertEqual(request.geometry.uniforms.textureOriginY, 0.125, accuracy: .ulpOfOne)
        XCTAssertEqual(request.geometry.uniforms.textureScaleY, 0.75, accuracy: .ulpOfOne)
        XCTAssertEqual(request.completion, .asynchronous)
        XCTAssertEqual(renderer.snapshot().submittedFrameCount, 1)
        XCTAssertEqual(renderer.snapshot().lastCoordinateRevision, 9)
    }

    func testRendererFailsClosedForInactiveStaleAndMismatchedTargets() throws {
        let fixture = try makeFixture(generation: 5, frameID: 55)
        let submitter = RecordingHDRMetalCommandSubmitter()
        let renderer = try makeRenderer(device: fixture.device, submitter: submitter)
        let coordinates = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: 3,
            sourceSize: PixelSize(width: 64, height: 48),
            drawableSize: PixelSize(width: 64, height: 48),
            mode: .fit
        ))
        let target = try makeTarget(
            device: fixture.device,
            width: 64,
            height: 48,
            pixelFormat: .bgra8Unorm_srgb
        )

        XCTAssertRendererError(.inactiveRenderer) {
            try renderer.render(
                frame: fixture.frame,
                configuration: fixture.configuration,
                uniforms: fixture.uniforms,
                coordinateSnapshot: coordinates,
                target: HDRMetalRenderTarget(texture: target)
            )
        }
        try renderer.replaceConfiguration(fixture.configuration)
        let staleDisplay = try makeConfiguration(
            generation: 5,
            metadata: .rec709VideoRange(),
            displayRevision: 2
        )
        XCTAssertRendererError(.staleRenderConfiguration) {
            try renderer.render(
                frame: fixture.frame,
                configuration: staleDisplay,
                uniforms: fixture.uniforms,
                coordinateSnapshot: coordinates,
                target: HDRMetalRenderTarget(texture: target)
            )
        }
        let wrongSize = try makeTarget(
            device: fixture.device,
            width: 63,
            height: 48,
            pixelFormat: .bgra8Unorm_srgb
        )
        XCTAssertRendererError(.incompatibleDrawableGeometry) {
            try renderer.render(
                frame: fixture.frame,
                configuration: fixture.configuration,
                uniforms: fixture.uniforms,
                coordinateSnapshot: coordinates,
                target: HDRMetalRenderTarget(texture: wrongSize)
            )
        }
        let wrongFormat = try makeTarget(
            device: fixture.device,
            width: 64,
            height: 48,
            pixelFormat: .rgba16Float
        )
        XCTAssertRendererError(.incompatibleDrawablePixelFormat) {
            try renderer.render(
                frame: fixture.frame,
                configuration: fixture.configuration,
                uniforms: fixture.uniforms,
                coordinateSnapshot: coordinates,
                target: HDRMetalRenderTarget(texture: wrongFormat)
            )
        }
        XCTAssertEqual(submitter.submissionCount, 0)
        XCTAssertEqual(renderer.snapshot().rejectedFrameCount, 4)
    }

    func testRendererRejectsStaleFrameUniformsAndCoordinateSource() throws {
        let fixture = try makeFixture(generation: 6, frameID: 66)
        let replacement = try makeFixture(generation: 7, frameID: 77)
        let submitter = RecordingHDRMetalCommandSubmitter()
        let renderer = try makeRenderer(device: fixture.device, submitter: submitter)
        try renderer.replaceConfiguration(replacement.configuration)
        let coordinates = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: 4,
            sourceSize: PixelSize(width: 64, height: 48),
            drawableSize: PixelSize(width: 64, height: 48),
            mode: .fit
        ))
        let target = try makeTarget(
            device: fixture.device,
            width: 64,
            height: 48,
            pixelFormat: .bgra8Unorm_srgb
        )

        XCTAssertRendererError(.staleFrameGeneration) {
            try renderer.render(
                frame: fixture.frame,
                configuration: replacement.configuration,
                uniforms: replacement.uniforms,
                coordinateSnapshot: coordinates,
                target: HDRMetalRenderTarget(texture: target)
            )
        }
        let hdrMetadata = VideoColorMetadata.hdr10VideoRange()
        let hdrConfiguration = try HDRRenderConfigurationIdentity(
            decoderGeneration: 7,
            colorSignature: HDRRenderColorSignature(metadata: hdrMetadata),
            displayRevision: HDRDisplayRevision(rawValue: 1),
            mappingMode: .hdrEDR,
            surfaceContract: HDRSurfaceContract(
                drawablePixelFormat: .rgba16Float,
                outputColorSpace: .extendedLinearDisplayP3,
                outputGamut: .displayP3,
                extendedRangeIntent: .enabled,
                metadataMode: .hdr10
            )
        )
        let invalidUniforms = try HDRMetalShaderUniforms(
            frameContract: HDRValidatedDecodedFrameContract(
                pixelLayout: .p010VideoRange10,
                width: 64,
                height: 48,
                colorSignature: HDRRenderColorSignature(metadata: hdrMetadata)
            ),
            configuration: hdrConfiguration,
            luminanceMapping: HDRLuminanceMapping(
                sourcePeak: HDRSourcePeakResolver.resolve(hdrMetadata),
                currentHeadroom: 2
            )
        )
        XCTAssertRendererError(.invalidShaderUniforms) {
            try renderer.render(
                frame: replacement.frame,
                configuration: replacement.configuration,
                uniforms: invalidUniforms,
                coordinateSnapshot: coordinates,
                target: HDRMetalRenderTarget(texture: target)
            )
        }
        let wrongSource = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: 5,
            sourceSize: PixelSize(width: 128, height: 96),
            drawableSize: PixelSize(width: 64, height: 48),
            mode: .fit
        ))
        XCTAssertRendererError(.incompatibleSourceGeometry) {
            try renderer.render(
                frame: replacement.frame,
                configuration: replacement.configuration,
                uniforms: replacement.uniforms,
                coordinateSnapshot: wrongSource,
                target: HDRMetalRenderTarget(texture: target)
            )
        }
        XCTAssertEqual(submitter.submissionCount, 0)
    }

    func testRendererRejectsSameGenerationFrameWithStaleHDRColorSignature() throws {
        let active = try makeFixture(
            generation: 8,
            frameID: 80,
            metadata: .hdr10VideoRange(maximumFullFrameLuminanceNits: 400)
        )
        let stale = try makeFixture(
            generation: 8,
            frameID: 81,
            metadata: .hdr10VideoRange(maximumFullFrameLuminanceNits: 600)
        )
        let submitter = RecordingHDRMetalCommandSubmitter()
        let renderer = try makeRenderer(device: active.device, submitter: submitter)
        try renderer.replaceConfiguration(active.configuration)
        let coordinates = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: 6,
            sourceSize: PixelSize(width: 64, height: 48),
            drawableSize: PixelSize(width: 64, height: 48),
            mode: .fit
        ))
        let target = try makeTarget(
            device: active.device,
            width: 64,
            height: 48,
            pixelFormat: .rgba16Float
        )

        XCTAssertRendererError(.staleFrameColorSignature) {
            try renderer.render(
                frame: stale.frame,
                configuration: active.configuration,
                uniforms: active.uniforms,
                coordinateSnapshot: coordinates,
                target: HDRMetalRenderTarget(texture: target)
            )
        }
        XCTAssertEqual(submitter.submissionCount, 0)
    }

    func testReplacementAndStopFlushOwnedPipelineStateIdempotently() throws {
        let first = try makeFixture(generation: 10, frameID: 100)
        let second = try makeFixture(generation: 11, frameID: 110)
        let submitter = RecordingHDRMetalCommandSubmitter()
        let factory = try AppleHDRMetalPipelineStateFactory(
            device: first.device,
            bundle: Bundle(for: Self.self)
        )
        let cache = try HDRMetalPipelineStateCache(capacity: 3, factory: factory)
        let renderer = HDRMetalVideoRenderer(
            device: first.device,
            pipelineCache: cache,
            commandSubmitter: submitter
        )
        let coordinates = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: 12,
            sourceSize: PixelSize(width: 64, height: 48),
            drawableSize: PixelSize(width: 64, height: 48),
            mode: .fit
        ))
        let target = try makeTarget(
            device: first.device,
            width: 64,
            height: 48,
            pixelFormat: .bgra8Unorm_srgb
        )
        try renderer.replaceConfiguration(first.configuration)
        _ = try renderer.render(
            frame: first.frame,
            configuration: first.configuration,
            uniforms: first.uniforms,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target)
        )
        XCTAssertEqual(cache.snapshot().keysByLeastRecentUse.count, 1)

        try renderer.replaceConfiguration(second.configuration)
        XCTAssertTrue(cache.snapshot().keysByLeastRecentUse.isEmpty)
        XCTAssertEqual(cache.snapshot().flushCount, 1)
        XCTAssertEqual(renderer.snapshot().replacementCount, 1)
        _ = try renderer.render(
            frame: second.frame,
            configuration: second.configuration,
            uniforms: second.uniforms,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target)
        )
        renderer.stop()
        renderer.stop()
        XCTAssertTrue(cache.snapshot().keysByLeastRecentUse.isEmpty)
        XCTAssertEqual(cache.snapshot().flushCount, 2)
        XCTAssertEqual(renderer.snapshot().stopCount, 1)
        XCTAssertNil(renderer.snapshot().activeConfiguration)
    }

    func testProductionSubmitterEncodesAndCompletesOffscreenRender() throws {
        let fixture = try makeFixture(generation: 12, frameID: 120)
        let renderer = try HDRMetalVideoRenderer(
            device: fixture.device,
            bundle: Bundle(for: Self.self)
        )
        try renderer.replaceConfiguration(fixture.configuration)
        let coordinates = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: 13,
            sourceSize: PixelSize(width: 64, height: 48),
            drawableSize: PixelSize(width: 64, height: 48),
            mode: .fit
        ))
        let target = try makeTarget(
            device: fixture.device,
            width: 64,
            height: 48,
            pixelFormat: .bgra8Unorm_srgb
        )

        XCTAssertNoThrow(try renderer.render(
            frame: fixture.frame,
            configuration: fixture.configuration,
            uniforms: fixture.uniforms,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .waitUntilCompleted
        ))
        XCTAssertEqual(renderer.snapshot().submittedFrameCount, 1)
        XCTAssertEqual(renderer.snapshot().completedFrameCount, 1)
        XCTAssertEqual(renderer.snapshot().failedFrameCount, 0)
        XCTAssertEqual(renderer.snapshot().lastCompletedFrameID, 120)
    }

    func testSubmissionFailureIsTypedAndDoesNotAdvanceOwnership() throws {
        let fixture = try makeFixture(generation: 13, frameID: 130)
        let submitter = RecordingHDRMetalCommandSubmitter(shouldFail: true)
        let renderer = try makeRenderer(device: fixture.device, submitter: submitter)
        try renderer.replaceConfiguration(fixture.configuration)
        let coordinates = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: 14,
            sourceSize: PixelSize(width: 64, height: 48),
            drawableSize: PixelSize(width: 64, height: 48),
            mode: .fit
        ))
        let target = try makeTarget(
            device: fixture.device,
            width: 64,
            height: 48,
            pixelFormat: .bgra8Unorm_srgb
        )

        XCTAssertRendererError(.commandSubmissionFailed) {
            try renderer.render(
                frame: fixture.frame,
                configuration: fixture.configuration,
                uniforms: fixture.uniforms,
                coordinateSnapshot: coordinates,
                target: HDRMetalRenderTarget(texture: target)
            )
        }
        let snapshot = renderer.snapshot()
        XCTAssertEqual(snapshot.submittedFrameCount, 0)
        XCTAssertEqual(snapshot.rejectedFrameCount, 1)
        XCTAssertNil(snapshot.lastCoordinateRevision)
    }

    func testLateCompletionsCannotRestoreReplacedOrStoppedOwnership() throws {
        let first = try makeFixture(generation: 20, frameID: 200)
        let second = try makeFixture(generation: 21, frameID: 210)
        let submitter = RecordingHDRMetalCommandSubmitter(completesImmediately: false)
        let renderer = try makeRenderer(device: first.device, submitter: submitter)
        let coordinates = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: 20,
            sourceSize: PixelSize(width: 64, height: 48),
            drawableSize: PixelSize(width: 64, height: 48),
            mode: .fit
        ))
        let target = try makeTarget(
            device: first.device,
            width: 64,
            height: 48,
            pixelFormat: .bgra8Unorm_srgb
        )

        try renderer.replaceConfiguration(first.configuration)
        _ = try renderer.render(
            frame: first.frame,
            configuration: first.configuration,
            uniforms: first.uniforms,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target)
        )
        let firstOwnership = renderer.snapshot().ownershipRevision

        try renderer.replaceConfiguration(second.configuration)
        let secondOwnership = renderer.snapshot().ownershipRevision
        XCTAssertGreaterThan(secondOwnership, firstOwnership)
        submitter.completeSubmission(at: 0, status: .completed)
        var snapshot = renderer.snapshot()
        XCTAssertEqual(snapshot.staleCompletionCount, 1)
        XCTAssertEqual(snapshot.completedFrameCount, 0)
        XCTAssertNil(snapshot.lastCompletedFrameID)
        XCTAssertEqual(snapshot.activeConfiguration, second.configuration)

        _ = try renderer.render(
            frame: second.frame,
            configuration: second.configuration,
            uniforms: second.uniforms,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target)
        )
        submitter.completeSubmission(at: 1, status: .completed)
        snapshot = renderer.snapshot()
        XCTAssertEqual(snapshot.completedFrameCount, 1)
        XCTAssertEqual(snapshot.lastCompletedFrameID, second.frame.frameID)

        _ = try renderer.render(
            frame: second.frame,
            configuration: second.configuration,
            uniforms: second.uniforms,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target)
        )
        renderer.stop()
        submitter.completeSubmission(at: 2, status: .completed)
        snapshot = renderer.snapshot()
        XCTAssertEqual(snapshot.staleCompletionCount, 2)
        XCTAssertEqual(snapshot.completedFrameCount, 1)
        XCTAssertNil(snapshot.lastCompletedFrameID)
        XCTAssertNil(snapshot.activeConfiguration)
    }

    private func makeRenderer(
        device: any MTLDevice,
        submitter: any HDRMetalCommandSubmitting
    ) throws -> HDRMetalVideoRenderer {
        let factory = try AppleHDRMetalPipelineStateFactory(
            device: device,
            bundle: Bundle(for: Self.self)
        )
        return HDRMetalVideoRenderer(
            device: device,
            pipelineCache: try HDRMetalPipelineStateCache(capacity: 3, factory: factory),
            commandSubmitter: submitter
        )
    }

    private func makeFixture(
        generation: UInt64,
        frameID: UInt64,
        metadata: VideoColorMetadata = .rec709VideoRange()
    ) throws -> RendererFixture {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let pixelBuffer = try makeMetalPixelBuffer(isHDR: metadata.isHDR)
        let decoded = DecodedVideoFrame(
            generation: generation,
            frameID: frameID,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: .invalid,
            duration: .invalid,
            infoFlags: [],
            colorMetadata: metadata
        )
        let frame = try CVMetalVideoFrameMapper(device: device).map(decoded)
        let configuration = try makeConfiguration(
            generation: generation,
            metadata: metadata
        )
        let contract = try HDRDecodedVideoContractValidator.validateForMetalMapping(
            pixelBuffer: pixelBuffer,
            colorMetadata: metadata
        )
        let uniforms = try HDRMetalShaderUniforms(
            frameContract: contract,
            configuration: configuration,
            luminanceMapping: metadata.isHDR
                ? HDRLuminanceMapping(
                    sourcePeak: HDRSourcePeakResolver.resolve(metadata),
                    currentHeadroom: 2
                )
                : nil
        )
        return RendererFixture(
            device: device,
            frame: frame,
            configuration: configuration,
            uniforms: uniforms
        )
    }

    private func makeConfiguration(
        generation: UInt64,
        metadata: VideoColorMetadata,
        displayRevision: UInt64 = 1
    ) throws -> HDRRenderConfigurationIdentity {
        let isHDR = metadata.isHDR
        return try HDRRenderConfigurationIdentity(
            decoderGeneration: generation,
            colorSignature: HDRRenderColorSignature(metadata: metadata),
            displayRevision: HDRDisplayRevision(rawValue: displayRevision),
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

    private func makeMetalPixelBuffer(isHDR: Bool = false) throws -> CVPixelBuffer {
        let attributes = VideoToolboxDecompressionSessionFactory
            .destinationAttributes(for: isHDR ? .ten : .eight) as CFDictionary
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            64,
            48,
            isHDR
                ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
                : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            attributes,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        return try XCTUnwrap(pixelBuffer)
    }

    private func makeTarget(
        device: any MTLDevice,
        width: Int,
        height: Int,
        pixelFormat: MTLPixelFormat
    ) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        return try XCTUnwrap(device.makeTexture(descriptor: descriptor))
    }
}

private struct RendererFixture {
    let device: any MTLDevice
    let frame: MetalVideoFrame
    let configuration: HDRRenderConfigurationIdentity
    let uniforms: HDRMetalShaderUniforms
}

private final class RecordingHDRMetalCommandSubmitter: HDRMetalCommandSubmitting,
    @unchecked Sendable {
    private let lock = NSLock()
    private let shouldFail: Bool
    private let completesImmediately: Bool
    private var requests: [HDRMetalCommandRequest] = []
    private var completionHandlers: [
        @Sendable (HDRMetalCommandCompletionStatus) -> Void
    ] = []

    var submissionCount: Int { lock.withLock { requests.count } }
    var lastRequest: HDRMetalCommandRequest? { lock.withLock { requests.last } }

    init(shouldFail: Bool = false, completesImmediately: Bool = true) {
        self.shouldFail = shouldFail
        self.completesImmediately = completesImmediately
    }

    func submit(
        _ request: HDRMetalCommandRequest,
        completionHandler: @escaping @Sendable (HDRMetalCommandCompletionStatus) -> Void
    ) throws {
        lock.withLock {
            requests.append(request)
            if !shouldFail && !completesImmediately {
                completionHandlers.append(completionHandler)
            }
        }
        if shouldFail {
            throw AppleHDRMetalCommandSubmitterError.commandExecutionFailed
        }
        if completesImmediately {
            completionHandler(.completed)
        }
    }

    func completeSubmission(
        at index: Int,
        status: HDRMetalCommandCompletionStatus
    ) {
        let completionHandler = lock.withLock { completionHandlers[index] }
        completionHandler(status)
    }
}

private extension HDRMetalVideoRendererTests {
    func XCTAssertRendererError<T>(
        _ expected: HDRMetalVideoRendererError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () throws -> T
    ) {
        XCTAssertThrowsError(try body(), file: file, line: line) { error in
            XCTAssertEqual(
                error as? HDRMetalVideoRendererError,
                expected,
                file: file,
                line: line
            )
        }
    }
}
