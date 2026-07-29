import CoreVideo
import Foundation
@preconcurrency import Metal
import MetalKit
import XCTest

final class StreamMetalPresenterTests: XCTestCase {
    func testSDRFrameResolvesExplicitSRGBMetalPresentation() throws {
        let frame = try makeFrame(
            generation: 7,
            frameID: 11,
            metadata: .rec709VideoRange()
        )
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: try makeSnapshot(revision: 3)
        )

        XCTAssertEqual(plan.configuration.decoderGeneration, 7)
        XCTAssertEqual(plan.configuration.displayRevision.rawValue, 3)
        XCTAssertEqual(plan.configuration.mappingMode, .sdr)
        XCTAssertEqual(plan.configuration.surfaceContract.drawablePixelFormat, .bgra8UnormSRGB)
        XCTAssertEqual(plan.configuration.surfaceContract.outputColorSpace, .sRGB)
        XCTAssertEqual(plan.configuration.surfaceContract.outputGamut, .sRGB)
        XCTAssertEqual(plan.configuration.surfaceContract.extendedRangeIntent, .disabled)
        XCTAssertEqual(plan.configuration.surfaceContract.metadataMode, .none)
        XCTAssertEqual(plan.uniforms.inputBitDepth, 8)
        XCTAssertEqual(plan.uniforms.mappingMode, 0)
        XCTAssertEqual(plan.uniforms.currentHeadroom, 1)
    }

    func testHDRFrameResolvesExplicitSDRFallbackUntilEDRSurfaceAdapterOwnsIntent() throws {
        let metadata = VideoColorMetadata.hdr10VideoRange()
        let frame = try makeFrame(
            generation: 9,
            frameID: 12,
            metadata: metadata
        )
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: try makeSnapshot(revision: 4)
        )

        XCTAssertEqual(plan.configuration.colorSignature, HDRRenderColorSignature(metadata: metadata))
        XCTAssertEqual(plan.configuration.mappingMode, .hdrToSDR)
        XCTAssertEqual(plan.configuration.surfaceContract.drawablePixelFormat, .bgra8UnormSRGB)
        XCTAssertEqual(plan.configuration.surfaceContract.extendedRangeIntent, .disabled)
        XCTAssertEqual(plan.uniforms.inputBitDepth, 10)
        XCTAssertEqual(plan.uniforms.mappingMode, 2)
        XCTAssertEqual(plan.uniforms.currentHeadroom, 1)
        XCTAssertGreaterThan(plan.uniforms.sourcePeakNits, 100)
    }

    func testCoordinateRevisionTemporarilyOwnsPresentationRevision() throws {
        let frame = try makeFrame(
            generation: 2,
            frameID: 1,
            metadata: .rec709VideoRange()
        )
        let first = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: try makeSnapshot(revision: 5)
        )
        let replacement = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: try makeSnapshot(revision: 6)
        )

        XCTAssertNotEqual(first.configuration, replacement.configuration)
        XCTAssertEqual(first.configuration.displayRevision.rawValue, 5)
        XCTAssertEqual(replacement.configuration.displayRevision.rawValue, 6)
        XCTAssertEqual(first.uniforms, replacement.uniforms)
    }

    func testZeroCoordinateRevisionFailsClosed() throws {
        let frame = try makeFrame(
            generation: 2,
            frameID: 1,
            metadata: .rec709VideoRange()
        )
        XCTAssertThrowsError(try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: try makeSnapshot(revision: 0)
        )) { error in
            XCTAssertEqual(error as? HDRRenderResolutionError, .invalidDisplayRevision)
        }
    }

    func testProductionRuntimeMapsAndRendersDecodedSDRFrameOffscreen() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let frame = try makeFrame(
            generation: 12,
            frameID: 40,
            metadata: .rec709VideoRange()
        )
        try fillSDRWhite(frame.pixelBuffer)
        let coordinates = try makeSnapshot(revision: 9)
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: coordinates
        )
        let target = try makeTarget(
            device: device,
            width: coordinates.drawableSize.width,
            height: coordinates.drawableSize.height
        )
        let runtime = try StreamMetalPresenterRuntime(
            device: device,
            bundle: Bundle(for: Self.self)
        )

        let result = try runtime.present(
            frame: frame,
            plan: plan,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .waitUntilCompleted
        )

        XCTAssertEqual(result, .submitted(
            frameID: 40,
            decoderGeneration: 12,
            displayRevision: HDRDisplayRevision(rawValue: 9),
            coordinateRevision: 9
        ))
        let pixel = readPixel(
            target,
            x: coordinates.drawableSize.width / 2,
            y: coordinates.drawableSize.height / 2
        )
        XCTAssertGreaterThan(pixel.red, 220)
        XCTAssertGreaterThan(pixel.green, 220)
        XCTAssertGreaterThan(pixel.blue, 220)
        XCTAssertEqual(pixel.alpha, 255)

        runtime.invalidate()
        XCTAssertThrowsError(try runtime.present(
            frame: frame,
            plan: plan,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .waitUntilCompleted
        )) { error in
            XCTAssertEqual(error as? StreamMetalPresenterError, .invalidatedRuntime)
        }
    }

    func testFrameDecisionCoversDrawableMismatchMissingStateAndPause() {
        XCTAssertEqual(StreamMetalFrameDecisionResolver.resolve(
            policy: .active,
            hasDrawable: false,
            hasCoordinates: true,
            drawableMatchesCoordinates: true,
            hasFrame: true
        ), .waitForDrawable)
        XCTAssertEqual(StreamMetalFrameDecisionResolver.resolve(
            policy: .paused(reason: "background"),
            hasDrawable: false,
            hasCoordinates: true,
            drawableMatchesCoordinates: true,
            hasFrame: true
        ), .clear(.inactivePolicy))
        XCTAssertEqual(StreamMetalFrameDecisionResolver.resolve(
            policy: .paused(reason: "background"),
            hasDrawable: true,
            hasCoordinates: true,
            drawableMatchesCoordinates: true,
            hasFrame: true
        ), .clear(.inactivePolicy))
        XCTAssertEqual(StreamMetalFrameDecisionResolver.resolve(
            policy: .active,
            hasDrawable: true,
            hasCoordinates: false,
            drawableMatchesCoordinates: false,
            hasFrame: true
        ), .clear(.missingCoordinates))
        XCTAssertEqual(StreamMetalFrameDecisionResolver.resolve(
            policy: .active,
            hasDrawable: true,
            hasCoordinates: true,
            drawableMatchesCoordinates: false,
            hasFrame: true
        ), .clear(.drawableMismatch))
        XCTAssertEqual(StreamMetalFrameDecisionResolver.resolve(
            policy: .throttled(reason: "occluded"),
            hasDrawable: true,
            hasCoordinates: true,
            drawableMatchesCoordinates: true,
            hasFrame: false
        ), .clear(.missingFrame))
        XCTAssertEqual(StreamMetalFrameDecisionResolver.resolve(
            policy: .throttled(reason: "occluded"),
            hasDrawable: true,
            hasCoordinates: true,
            drawableMatchesCoordinates: true,
            hasFrame: true
        ), .present)
    }

    func testViewScheduleResumesAt60ThrottlesAt15AndRequestsOnePausedDraw() {
        XCTAssertEqual(
            StreamMetalViewScheduleResolver.resolve(.active),
            StreamMetalViewSchedule(
                isPaused: false,
                preferredFramesPerSecond: 60,
                requestsImmediateDraw: false
            )
        )
        XCTAssertEqual(
            StreamMetalViewScheduleResolver.resolve(.throttled(reason: "occluded")),
            StreamMetalViewSchedule(
                isPaused: false,
                preferredFramesPerSecond: 15,
                requestsImmediateDraw: false
            )
        )
        let paused = StreamMetalViewSchedule(
            isPaused: true,
            preferredFramesPerSecond: 60,
            requestsImmediateDraw: true
        )
        XCTAssertEqual(StreamMetalViewScheduleResolver.resolve(.idle), paused)
        XCTAssertEqual(
            StreamMetalViewScheduleResolver.resolve(.paused(reason: "background")),
            paused
        )
    }

    func testRuntimeCachesFrameAndRebuildsOnCoordinateRevisionAndReplacement() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let mapper = try RecordingMetalVideoFrameMapper(device: device)
        let renderer = RecordingHDRMetalVideoRenderer()
        let runtime = try makeRuntime(device: device, mapper: mapper, renderer: renderer)
        let firstFrame = try makeFrame(
            generation: 20,
            frameID: 1,
            metadata: .rec709VideoRange()
        )
        let firstCoordinates = try makeSnapshot(revision: 30)
        let firstPlan = try StreamMetalPresentationPlanResolver.resolve(
            frame: firstFrame,
            coordinateSnapshot: firstCoordinates
        )
        let target = try makeTarget(
            device: device,
            width: firstCoordinates.drawableSize.width,
            height: firstCoordinates.drawableSize.height
        )

        for _ in 0..<2 {
            try runtime.present(
                frame: firstFrame,
                plan: firstPlan,
                coordinateSnapshot: firstCoordinates,
                target: HDRMetalRenderTarget(texture: target),
                completion: .asynchronous
            )
        }
        XCTAssertEqual(mapper.mapCount, 1)
        XCTAssertEqual(renderer.renderCount, 2)
        XCTAssertEqual(renderer.configurations, [firstPlan.configuration])

        let resizedCoordinates = try makeSnapshot(revision: 31)
        let resizedPlan = try StreamMetalPresentationPlanResolver.resolve(
            frame: firstFrame,
            coordinateSnapshot: resizedCoordinates
        )
        try runtime.present(
            frame: firstFrame,
            plan: resizedPlan,
            coordinateSnapshot: resizedCoordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .asynchronous
        )
        let replacementFrame = try makeFrame(
            generation: 20,
            frameID: 2,
            metadata: .rec709VideoRange()
        )
        try runtime.present(
            frame: replacementFrame,
            plan: resizedPlan,
            coordinateSnapshot: resizedCoordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .asynchronous
        )

        XCTAssertEqual(mapper.mapCount, 3)
        XCTAssertEqual(mapper.flushCount, 2)
        XCTAssertEqual(renderer.configurations, [
            firstPlan.configuration,
            resizedPlan.configuration
        ])
        XCTAssertEqual(runtime.snapshot(), StreamMetalPresenterRuntimeSnapshot(
            activeConfiguration: resizedPlan.configuration,
            mappedFrameGeneration: 20,
            mappedFrameID: 2,
            isInvalidated: false,
            submittedFrameCount: 4,
            failedPresentationCount: 0,
            stopCount: 0,
            invalidationCount: 0
        ))
    }

    func testPipelineFailureFlushesConfigurationAndMappedFrame() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let mapper = try RecordingMetalVideoFrameMapper(device: device)
        let renderer = RecordingHDRMetalVideoRenderer(renderError: .pipelineFailure)
        let runtime = try makeRuntime(device: device, mapper: mapper, renderer: renderer)
        let frame = try makeFrame(
            generation: 21,
            frameID: 3,
            metadata: .rec709VideoRange()
        )
        let coordinates = try makeSnapshot(revision: 32)
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: coordinates
        )
        let target = try makeTarget(
            device: device,
            width: coordinates.drawableSize.width,
            height: coordinates.drawableSize.height
        )

        XCTAssertThrowsError(try runtime.present(
            frame: frame,
            plan: plan,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .asynchronous
        )) { error in
            XCTAssertEqual(error as? RecordingRendererError, .pipelineFailure)
        }
        let snapshot = runtime.snapshot()
        XCTAssertNil(snapshot.activeConfiguration)
        XCTAssertNil(snapshot.mappedFrameGeneration)
        XCTAssertNil(snapshot.mappedFrameID)
        XCTAssertEqual(snapshot.submittedFrameCount, 0)
        XCTAssertEqual(snapshot.failedPresentationCount, 1)
        XCTAssertEqual(mapper.mapCount, 1)
        XCTAssertEqual(mapper.flushCount, 2)
        XCTAssertEqual(renderer.stopCount, 1)

        runtime.stop()
        XCTAssertEqual(runtime.snapshot().stopCount, 0)
        XCTAssertEqual(mapper.flushCount, 2)
        XCTAssertEqual(renderer.stopCount, 1)
    }

    func testConfigurationFailureFailsClosedBeforeMapping() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let mapper = try RecordingMetalVideoFrameMapper(device: device)
        let renderer = RecordingHDRMetalVideoRenderer(
            configurationError: .configurationFailure
        )
        let runtime = try makeRuntime(device: device, mapper: mapper, renderer: renderer)
        let frame = try makeFrame(
            generation: 22,
            frameID: 4,
            metadata: .rec709VideoRange()
        )
        let coordinates = try makeSnapshot(revision: 33)
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: coordinates
        )
        let target = try makeTarget(
            device: device,
            width: coordinates.drawableSize.width,
            height: coordinates.drawableSize.height
        )

        XCTAssertThrowsError(try runtime.present(
            frame: frame,
            plan: plan,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .asynchronous
        )) { error in
            XCTAssertEqual(error as? RecordingRendererError, .configurationFailure)
        }
        XCTAssertEqual(mapper.mapCount, 0)
        XCTAssertEqual(mapper.flushCount, 1)
        XCTAssertEqual(renderer.stopCount, 1)
        XCTAssertEqual(runtime.snapshot().failedPresentationCount, 1)
    }

    func testStopAndInvalidateReleaseOwnershipIdempotently() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let mapper = try RecordingMetalVideoFrameMapper(device: device)
        let renderer = RecordingHDRMetalVideoRenderer()
        let runtime = try makeRuntime(device: device, mapper: mapper, renderer: renderer)
        let frame = try makeFrame(
            generation: 23,
            frameID: 5,
            metadata: .rec709VideoRange()
        )
        let coordinates = try makeSnapshot(revision: 34)
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: coordinates
        )
        let target = try makeTarget(
            device: device,
            width: coordinates.drawableSize.width,
            height: coordinates.drawableSize.height
        )
        try runtime.present(
            frame: frame,
            plan: plan,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .asynchronous
        )

        runtime.stop()
        runtime.stop()
        var snapshot = runtime.snapshot()
        XCTAssertNil(snapshot.activeConfiguration)
        XCTAssertEqual(snapshot.stopCount, 1)
        XCTAssertFalse(snapshot.isInvalidated)

        runtime.invalidate()
        runtime.invalidate()
        snapshot = runtime.snapshot()
        XCTAssertTrue(snapshot.isInvalidated)
        XCTAssertEqual(snapshot.stopCount, 1)
        XCTAssertEqual(snapshot.invalidationCount, 1)
        XCTAssertEqual(renderer.stopCount, 1)
        XCTAssertEqual(mapper.flushCount, 2)
    }

    @MainActor
    func testConfigureReplacementAndStopInvalidateExactlyCurrentRuntime() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let firstRuntime = RecordingStreamMetalPresenterRuntime()
        let replacementRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimes = [firstRuntime, replacementRuntime]
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in runtimes.removeFirst() }
        )

        presenter.configure(view)
        XCTAssertEqual(view.colorPixelFormat, .bgra8Unorm_srgb)
        XCTAssertTrue(view.framebufferOnly)
        XCTAssertTrue((view.delegate as AnyObject?) === presenter)
        let layer = try XCTUnwrap(view.layer as? CAMetalLayer)
        XCTAssertEqual(layer.pixelFormat, .bgra8Unorm_srgb)
        XCTAssertEqual(layer.colorspace?.name, CGColorSpace.sRGB)
        XCTAssertFalse(layer.wantsExtendedDynamicRangeContent)
        XCTAssertNil(layer.edrMetadata)
        XCTAssertEqual(firstRuntime.snapshot().invalidationCount, 0)

        presenter.configure(view)
        XCTAssertEqual(firstRuntime.snapshot().invalidationCount, 1)
        XCTAssertEqual(replacementRuntime.snapshot().invalidationCount, 0)

        presenter.stop()
        presenter.stop()
        XCTAssertEqual(firstRuntime.snapshot().invalidationCount, 1)
        XCTAssertEqual(replacementRuntime.snapshot().invalidationCount, 1)
    }

    @MainActor
    func testFailedConfigureInvalidatesPreviousRuntimeWithoutLeavingStaleOwnership() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let runtime = RecordingStreamMetalPresenterRuntime()
        var shouldFail = false
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in
                if shouldFail { throw TestError.runtimeCreationFailed }
                return runtime
            }
        )

        presenter.configure(view)
        XCTAssertEqual(runtime.snapshot().invalidationCount, 0)

        shouldFail = true
        presenter.configure(view)
        XCTAssertEqual(runtime.snapshot().invalidationCount, 1)
        XCTAssertTrue((view.delegate as AnyObject?) === presenter)

        presenter.stop()
        XCTAssertEqual(runtime.snapshot().invalidationCount, 1)
    }

    @MainActor
    func testSurfaceFailureInvalidatesRuntimeAndDetachesPresenter() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let runtime = RecordingStreamMetalPresenterRuntime()
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        var runtimeCreationCount = 0
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in
                runtimeCreationCount += 1
                return runtime
            },
            surfaceAdapterFactory: { _ in surfaceAdapter }
        )

        presenter.configure(view)
        XCTAssertEqual(runtimeCreationCount, 1)
        XCTAssertTrue((view.delegate as AnyObject?) === presenter)
        XCTAssertEqual(runtime.snapshot().invalidationCount, 0)

        surfaceAdapter.failure = .mutationFailed(.outputColorSpace(.sRGB))
        presenter.configure(view)

        XCTAssertEqual(runtimeCreationCount, 1)
        XCTAssertEqual(runtime.snapshot().invalidationCount, 1)
        XCTAssertNil(view.delegate)
        XCTAssertTrue(view.isPaused)
    }

    private func makeFrame(
        generation: UInt64,
        frameID: UInt64,
        metadata: VideoColorMetadata
    ) throws -> DecodedVideoFrame {
        let format = metadata.isHDR
            ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        let bitDepth: VideoOutputBitDepth = metadata.isHDR ? .ten : .eight
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            64,
            64,
            format,
            VideoToolboxDecompressionSessionFactory
                .destinationAttributes(for: bitDepth) as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw TestError.pixelBufferCreationFailed(status)
        }
        return DecodedVideoFrame(
            generation: generation,
            frameID: frameID,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: .invalid,
            duration: .invalid,
            infoFlags: [],
            colorMetadata: metadata
        )
    }

    private func makeSnapshot(revision: UInt64) throws -> StreamCoordinateSnapshot {
        guard let snapshot = StreamCoordinateSnapshot.resolve(
            revision: revision,
            sourceSize: PixelSize(width: 64, height: 64),
            drawableSize: PixelSize(width: 128, height: 96),
            mode: .fit
        ) else {
            throw TestError.coordinateResolutionFailed
        }
        return snapshot
    }

    private func fillSDRWhite(_ pixelBuffer: CVPixelBuffer) throws {
        guard CVPixelBufferLockBaseAddress(pixelBuffer, []) == kCVReturnSuccess else {
            throw TestError.pixelBufferLockFailed
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let luma = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
              let chroma = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
            throw TestError.pixelBufferPlaneMissing
        }
        memset(
            luma,
            235,
            CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
                * CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        )
        memset(
            chroma,
            128,
            CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
                * CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        )
    }

    private func makeTarget(
        device: any MTLDevice,
        width: Int,
        height: Int
    ) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw TestError.targetCreationFailed
        }
        return texture
    }

    private func makeRuntime(
        device: any MTLDevice,
        mapper: any MetalVideoFrameMapping,
        renderer: any HDRMetalVideoRendering
    ) throws -> StreamMetalPresenterRuntime {
        guard let commandQueue = device.makeCommandQueue() else {
            throw TestError.commandQueueCreationFailed
        }
        return StreamMetalPresenterRuntime(
            mapper: mapper,
            renderer: renderer,
            commandQueue: commandQueue
        )
    }

    private func readPixel(
        _ texture: any MTLTexture,
        x: Int,
        y: Int
    ) -> (blue: UInt8, green: UInt8, red: UInt8, alpha: UInt8) {
        var bytes = [UInt8](repeating: 0, count: 4)
        texture.getBytes(
            &bytes,
            bytesPerRow: 4,
            from: MTLRegionMake2D(x, y, 1, 1),
            mipmapLevel: 0
        )
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }

    private enum TestError: Error {
        case pixelBufferCreationFailed(CVReturn)
        case coordinateResolutionFailed
        case pixelBufferLockFailed
        case pixelBufferPlaneMissing
        case targetCreationFailed
        case commandQueueCreationFailed
        case runtimeCreationFailed
    }
}

@MainActor
private final class RecordingPresenterSurfaceAdapter: HDRSurfaceApplying {
    var failure: HDRSurfaceApplicationError?

    func apply(_ contract: HDRSurfaceContract) throws -> HDRSurfaceApplicationOutcome {
        if let failure { throw failure }
        return .applied(previous: nil, current: contract)
    }
}

private enum RecordingRendererError: Error, Equatable {
    case configurationFailure
    case pipelineFailure
}

private final class RecordingMetalVideoFrameMapper: MetalVideoFrameMapping,
    @unchecked Sendable {
    private let base: CVMetalVideoFrameMapper
    private let lock = NSLock()
    private var storedMapCount = 0
    private var storedFlushCount = 0

    var mapCount: Int { lock.withLock { storedMapCount } }
    var flushCount: Int { lock.withLock { storedFlushCount } }

    init(device: any MTLDevice) throws {
        base = try CVMetalVideoFrameMapper(device: device)
    }

    func map(_ frame: DecodedVideoFrame) throws -> MetalVideoFrame {
        lock.withLock { storedMapCount += 1 }
        return try base.map(frame)
    }

    func flush() {
        lock.withLock { storedFlushCount += 1 }
        base.flush()
    }
}

private final class RecordingHDRMetalVideoRenderer: HDRMetalVideoRendering,
    @unchecked Sendable {
    private let lock = NSLock()
    private let configurationError: RecordingRendererError?
    private let renderError: RecordingRendererError?
    private var storedConfigurations: [HDRRenderConfigurationIdentity] = []
    private var storedRenderCount = 0
    private var storedStopCount = 0

    var configurations: [HDRRenderConfigurationIdentity] {
        lock.withLock { storedConfigurations }
    }
    var renderCount: Int { lock.withLock { storedRenderCount } }
    var stopCount: Int { lock.withLock { storedStopCount } }

    init(
        configurationError: RecordingRendererError? = nil,
        renderError: RecordingRendererError? = nil
    ) {
        self.configurationError = configurationError
        self.renderError = renderError
    }

    func replaceConfiguration(_ configuration: HDRRenderConfigurationIdentity) throws {
        if let configurationError { throw configurationError }
        lock.withLock { storedConfigurations.append(configuration) }
    }

    func render(
        frame: MetalVideoFrame,
        configuration: HDRRenderConfigurationIdentity,
        uniforms: HDRMetalShaderUniforms,
        coordinateSnapshot: StreamCoordinateSnapshot,
        target: HDRMetalRenderTarget,
        completion: HDRMetalCommandCompletion
    ) throws -> HDRMetalVideoRendererResult {
        _ = uniforms
        _ = target
        _ = completion
        if let renderError { throw renderError }
        lock.withLock { storedRenderCount += 1 }
        return .submitted(
            frameID: frame.frameID,
            decoderGeneration: configuration.decoderGeneration,
            displayRevision: configuration.displayRevision,
            coordinateRevision: coordinateSnapshot.revision
        )
    }

    func stop() {
        lock.withLock { storedStopCount += 1 }
    }
}

private final class RecordingStreamMetalPresenterRuntime:
    StreamMetalPresenterRuntiming, @unchecked Sendable {
    private let lock = NSLock()
    private var invalidationCount: UInt64 = 0

    func present(
        frame: DecodedVideoFrame,
        plan: StreamMetalPresentationPlan,
        coordinateSnapshot: StreamCoordinateSnapshot,
        target: HDRMetalRenderTarget,
        completion: HDRMetalCommandCompletion
    ) throws -> HDRMetalVideoRendererResult {
        _ = target
        _ = completion
        return .submitted(
            frameID: frame.frameID,
            decoderGeneration: plan.configuration.decoderGeneration,
            displayRevision: plan.configuration.displayRevision,
            coordinateRevision: coordinateSnapshot.revision
        )
    }

    func clear(drawable: any CAMetalDrawable, color: MTLClearColor) throws {
        _ = drawable
        _ = color
    }

    func stop() {}

    func invalidate() {
        lock.withLock { invalidationCount &+= 1 }
    }

    func snapshot() -> StreamMetalPresenterRuntimeSnapshot {
        lock.withLock {
            StreamMetalPresenterRuntimeSnapshot(
                activeConfiguration: nil,
                mappedFrameGeneration: nil,
                mappedFrameID: nil,
                isInvalidated: invalidationCount > 0,
                submittedFrameCount: 0,
                failedPresentationCount: 0,
                stopCount: 0,
                invalidationCount: invalidationCount
            )
        }
    }
}
