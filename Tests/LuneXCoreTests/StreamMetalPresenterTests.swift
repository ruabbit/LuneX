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

    func testResolvedPlanUsesActiveDisplayRevisionAndEDRLuminanceMapping() throws {
        let frame = try makeFrame(
            generation: 30,
            frameID: 10,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 41,
            currentHeadroom: 2.5
        )
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            resolvedConfiguration: resolved
        )

        XCTAssertEqual(plan.configuration, resolved.identity)
        XCTAssertEqual(plan.configuration.displayRevision.rawValue, 41)
        XCTAssertEqual(plan.configuration.mappingMode, .hdrEDR)
        XCTAssertEqual(plan.uniforms.mappingMode, 1)
        XCTAssertEqual(plan.uniforms.currentHeadroom, 2.5)

        let stale = try makeFrame(
            generation: 29,
            frameID: 11,
            metadata: .hdr10VideoRange()
        )
        XCTAssertThrowsError(try StreamMetalPresentationPlanResolver.resolve(
            frame: stale,
            resolvedConfiguration: resolved
        )) { error in
            XCTAssertEqual(
                error as? HDRRenderResolutionError,
                .staleDecoderGeneration(expected: 30, actual: 29)
            )
        }
    }

    @MainActor
    func testResolvedTransitionInvalidatesOldRuntimeAndPublishesNewOwnership() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        let replacementRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimes = [initialRuntime, replacementRuntime]
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        var diagnosticStates: [HDRPresentationDiagnosticState] = []
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in runtimes.removeFirst() },
            surfaceAdapterFactory: { _ in surfaceAdapter },
            diagnosticHandler: { diagnosticStates.append($0) }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 31,
            frameID: 12,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 42,
            currentHeadroom: 3,
            appliedSurfaceContract: try makeSDRSurface()
        )

        let outcome = presenter.transition(.resolved(resolved), on: view)

        XCTAssertEqual(outcome, .applied(
            previous: nil,
            current: resolved.identity
        ))
        XCTAssertEqual(initialRuntime.invalidationCount, 1)
        XCTAssertEqual(replacementRuntime.invalidationCount, 0)
        XCTAssertEqual(surfaceAdapter.contracts, [
            try makeSDRSurface(),
            resolved.identity.surfaceContract
        ])
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: resolved.identity,
            appliedSurfaceContract: resolved.identity.surfaceContract,
            requiresClearBeforePresentation: true,
            configurationTransitionCount: 1,
            closedTransitionCount: 0
        ))
        XCTAssertEqual(diagnosticStates, [.activeEDR])
    }

    @MainActor
    func testReplacementDiagnosticLeaseRejectsOldPresenterStopAndLateFailure() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let oldView = MTKView(frame: .zero, device: device)
        let replacementView = MTKView(frame: .zero, device: device)
        var activeOwner: UUID?
        var acceptedStates: [HDRPresentationDiagnosticState] = []
        let lease = HDRPresentationDiagnosticLease(
            claim: { activeOwner = $0 },
            publish: { ownerID, state in
                guard activeOwner == ownerID else { return }
                acceptedStates.append(state)
            },
            release: { ownerID in
                guard activeOwner == ownerID else { return }
                activeOwner = nil
            }
        )
        var oldRuntimes: [any StreamMetalPresenterRuntiming] = [
            RecordingStreamMetalPresenterRuntime(),
            RecordingStreamMetalPresenterRuntime()
        ]
        let oldPresenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in oldRuntimes.removeFirst() },
            surfaceAdapterFactory: { _ in RecordingPresenterSurfaceAdapter() },
            diagnosticLease: lease
        )
        oldPresenter.configure(oldView)
        let oldFrame = try makeFrame(
            generation: 70,
            frameID: 1,
            metadata: .hdr10VideoRange()
        )
        let oldConfiguration = try makeResolvedConfiguration(
            for: oldFrame,
            displayRevision: 60,
            currentHeadroom: 2
        )
        _ = oldPresenter.transition(.resolved(oldConfiguration), on: oldView)
        XCTAssertEqual(acceptedStates, [.activeEDR])

        var replacementRuntimes: [any StreamMetalPresenterRuntiming] = [
            RecordingStreamMetalPresenterRuntime(),
            RecordingStreamMetalPresenterRuntime()
        ]
        let replacementPresenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in replacementRuntimes.removeFirst() },
            surfaceAdapterFactory: { _ in RecordingPresenterSurfaceAdapter() },
            diagnosticLease: lease
        )
        replacementPresenter.configure(replacementView)
        let replacementFrame = try makeFrame(
            generation: 71,
            frameID: 2,
            metadata: .rec709VideoRange()
        )
        let replacementConfiguration = try makeResolvedConfiguration(
            for: replacementFrame,
            displayRevision: 61,
            currentHeadroom: 2
        )
        _ = replacementPresenter.transition(
            .resolved(replacementConfiguration),
            on: replacementView
        )
        XCTAssertEqual(acceptedStates, [.activeEDR, .activeSDR])

        _ = oldPresenter.transition(.closed(.invalidSourceContract), on: oldView)
        oldPresenter.stop()
        XCTAssertEqual(acceptedStates, [.activeEDR, .activeSDR])

        replacementPresenter.stop()
        XCTAssertEqual(acceptedStates, [.activeEDR, .activeSDR, .inactive])
        XCTAssertNil(activeOwner)
    }

    @MainActor
    func testSurfaceReadinessChangeDoesNotRebuildMatchingPresentation() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        let replacementRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimeCreationCount = 0
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in
                runtimeCreationCount += 1
                return runtimeCreationCount == 1
                    ? initialRuntime
                    : replacementRuntime
            },
            surfaceAdapterFactory: { _ in surfaceAdapter }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 39,
            frameID: 20,
            metadata: .hdr10VideoRange()
        )
        let requiresApplication = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 50,
            currentHeadroom: 3,
            appliedSurfaceContract: try makeSDRSurface()
        )
        XCTAssertEqual(
            requiresApplication.surfaceState,
            .requiresApplication(previous: try makeSDRSurface())
        )
        XCTAssertEqual(
            presenter.transition(.resolved(requiresApplication), on: view),
            .applied(previous: nil, current: requiresApplication.identity)
        )
        let ready = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 50,
            currentHeadroom: 3,
            appliedSurfaceContract: requiresApplication.identity.surfaceContract
        )
        XCTAssertEqual(ready.surfaceState, .ready)
        XCTAssertNotEqual(requiresApplication, ready)
        let appliedContracts = surfaceAdapter.contracts

        let outcome = presenter.transition(.resolved(ready), on: view)

        XCTAssertEqual(outcome, .unchanged(ready.identity))
        XCTAssertEqual(runtimeCreationCount, 2)
        XCTAssertEqual(initialRuntime.invalidationCount, 1)
        XCTAssertEqual(replacementRuntime.invalidationCount, 0)
        XCTAssertEqual(surfaceAdapter.contracts, appliedContracts)
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: ready.identity,
            appliedSurfaceContract: ready.identity.surfaceContract,
            requiresClearBeforePresentation: true,
            configurationTransitionCount: 1,
            closedTransitionCount: 0
        ))
    }

    @MainActor
    func testClosedResolutionInvalidatesEDRRuntimeAndRestoresSDRSurface() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        let edrRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimes = [initialRuntime, edrRuntime]
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in runtimes.removeFirst() },
            surfaceAdapterFactory: { _ in surfaceAdapter }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 32,
            frameID: 13,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 43,
            currentHeadroom: 2
        )
        XCTAssertEqual(
            presenter.transition(.resolved(resolved), on: view),
            .applied(previous: nil, current: resolved.identity)
        )

        let outcome = presenter.transition(
            .closed(.invalidCurrentDisplayHeadroom),
            on: view
        )

        XCTAssertEqual(
            outcome,
            .closed(.resolutionClosed(.invalidCurrentDisplayHeadroom))
        )
        XCTAssertEqual(edrRuntime.invalidationCount, 1)
        XCTAssertEqual(surfaceAdapter.contracts, [
            try makeSDRSurface(),
            resolved.identity.surfaceContract,
            try makeSDRSurface()
        ])
        XCTAssertTrue(view.isPaused)
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: nil,
            appliedSurfaceContract: try makeSDRSurface(),
            requiresClearBeforePresentation: false,
            configurationTransitionCount: 1,
            closedTransitionCount: 1
        ))
    }

    @MainActor
    func testCoordinateRevisionClearsPresentationAndPipelineWithoutSurfaceChange() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        let activeRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimes = [initialRuntime, activeRuntime]
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        let renderState = StreamRenderState(transform: RenderTransform(
            sourceSize: PixelSize(width: 64, height: 64),
            drawableSize: PixelSize(width: 128, height: 96),
            mode: .fit
        ))
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: renderState,
            runtimeFactory: { _, _ in runtimes.removeFirst() },
            surfaceAdapterFactory: { _ in surfaceAdapter }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 60,
            frameID: 16,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 52,
            currentHeadroom: 2
        )
        renderState.hdrRenderResolution = .resolved(resolved)
        presenter.update(renderState: renderState)

        renderState.transform.drawableSize = PixelSize(width: 192, height: 108)
        presenter.update(renderState: renderState)

        XCTAssertEqual(initialRuntime.invalidationCount, 1)
        XCTAssertEqual(activeRuntime.stopCount, 1)
        XCTAssertEqual(activeRuntime.invalidationCount, 0)
        XCTAssertEqual(surfaceAdapter.contracts, [
            try makeSDRSurface(),
            resolved.identity.surfaceContract
        ])
        XCTAssertEqual(
            presenter.snapshot().configurationTransitionCount,
            1
        )
        XCTAssertTrue(presenter.snapshot().requiresClearBeforePresentation)
    }

    @MainActor
    func testRuntimeCreationFailureRestoresPreviousSurfaceAndDetaches() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        var shouldFail = false
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        var diagnosticStates: [HDRPresentationDiagnosticState] = []
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in
                if shouldFail { throw TestError.runtimeCreationFailed }
                return initialRuntime
            },
            surfaceAdapterFactory: { _ in surfaceAdapter },
            diagnosticHandler: { diagnosticStates.append($0) }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 33,
            frameID: 14,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 44,
            currentHeadroom: 2
        )
        shouldFail = true

        let outcome = presenter.transition(.resolved(resolved), on: view)

        XCTAssertEqual(outcome, .closed(.runtimeCreationFailed))
        XCTAssertEqual(initialRuntime.invalidationCount, 1)
        XCTAssertEqual(surfaceAdapter.contracts, [
            try makeSDRSurface(),
            resolved.identity.surfaceContract,
            try makeSDRSurface()
        ])
        XCTAssertNil(view.delegate)
        XCTAssertTrue(view.isPaused)
        XCTAssertNil(presenter.snapshot().activeConfiguration)
        XCTAssertEqual(diagnosticStates, [.pipelineFailure])
    }

    @MainActor
    func testClosedResolutionCanRecoverWithReplacementRuntimeAndSurface() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        let edrRuntime = RecordingStreamMetalPresenterRuntime()
        let recoveredRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimes = [initialRuntime, edrRuntime, recoveredRuntime]
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        var diagnosticStates: [HDRPresentationDiagnosticState] = []
        let renderState = StreamRenderState()
        renderState.policy = .active
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: renderState,
            runtimeFactory: { _, _ in runtimes.removeFirst() },
            surfaceAdapterFactory: { _ in surfaceAdapter },
            diagnosticHandler: { diagnosticStates.append($0) }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 34,
            frameID: 15,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 45,
            currentHeadroom: 2.5
        )
        XCTAssertEqual(
            presenter.transition(.resolved(resolved), on: view),
            .applied(previous: nil, current: resolved.identity)
        )
        XCTAssertEqual(
            presenter.transition(
                .closed(.invalidCurrentDisplayHeadroom),
                on: view
            ),
            .closed(.resolutionClosed(.invalidCurrentDisplayHeadroom))
        )

        let outcome = presenter.transition(.resolved(resolved), on: view)

        XCTAssertEqual(
            outcome,
            .applied(previous: nil, current: resolved.identity)
        )
        XCTAssertEqual(initialRuntime.invalidationCount, 1)
        XCTAssertEqual(edrRuntime.invalidationCount, 1)
        XCTAssertEqual(recoveredRuntime.invalidationCount, 0)
        XCTAssertEqual(surfaceAdapter.contracts, [
            try makeSDRSurface(),
            resolved.identity.surfaceContract,
            try makeSDRSurface(),
            resolved.identity.surfaceContract
        ])
        XCTAssertTrue((view.delegate as AnyObject?) === presenter)
        XCTAssertFalse(view.isPaused)
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: resolved.identity,
            appliedSurfaceContract: resolved.identity.surfaceContract,
            requiresClearBeforePresentation: true,
            configurationTransitionCount: 2,
            closedTransitionCount: 1
        ))
        XCTAssertEqual(
            diagnosticStates,
            [.activeEDR, .unsupportedOutput, .activeEDR]
        )
    }

    @MainActor
    func testStopFromEDRRestoresSDRAndIsIdempotent() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        let edrRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimes = [initialRuntime, edrRuntime]
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in runtimes.removeFirst() },
            surfaceAdapterFactory: { _ in surfaceAdapter }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 35,
            frameID: 16,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 46,
            currentHeadroom: 2
        )
        XCTAssertEqual(
            presenter.transition(.resolved(resolved), on: view),
            .applied(previous: nil, current: resolved.identity)
        )

        presenter.stop()
        presenter.stop()

        XCTAssertEqual(initialRuntime.invalidationCount, 1)
        XCTAssertEqual(edrRuntime.invalidationCount, 1)
        XCTAssertEqual(surfaceAdapter.contracts, [
            try makeSDRSurface(),
            resolved.identity.surfaceContract,
            try makeSDRSurface()
        ])
        XCTAssertTrue(view.isPaused)
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: nil,
            appliedSurfaceContract: try makeSDRSurface(),
            requiresClearBeforePresentation: false,
            configurationTransitionCount: 1,
            closedTransitionCount: 0
        ))
    }

    @MainActor
    func testStaleOldViewTransitionCannotMutateReplacementSurface() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let oldView = MTKView(frame: .zero, device: device)
        let replacementView = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        let edrRuntime = RecordingStreamMetalPresenterRuntime()
        let replacementRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimes = [initialRuntime, edrRuntime, replacementRuntime]
        let oldAdapter = RecordingPresenterSurfaceAdapter()
        let replacementAdapter = RecordingPresenterSurfaceAdapter()
        var adapters = [oldAdapter, replacementAdapter]
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in runtimes.removeFirst() },
            surfaceAdapterFactory: { _ in adapters.removeFirst() }
        )
        presenter.configure(oldView)
        let frame = try makeFrame(
            generation: 36,
            frameID: 17,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 47,
            currentHeadroom: 3
        )
        XCTAssertEqual(
            presenter.transition(.resolved(resolved), on: oldView),
            .applied(previous: nil, current: resolved.identity)
        )
        presenter.configure(replacementView)
        let oldContracts = oldAdapter.contracts
        let replacementContracts = replacementAdapter.contracts

        let outcome = presenter.transition(.resolved(resolved), on: oldView)

        XCTAssertEqual(outcome, .closed(.staleSurface))
        XCTAssertEqual(oldAdapter.contracts, oldContracts)
        XCTAssertEqual(replacementAdapter.contracts, replacementContracts)
        XCTAssertEqual(initialRuntime.invalidationCount, 1)
        XCTAssertEqual(edrRuntime.invalidationCount, 1)
        XCTAssertEqual(replacementRuntime.invalidationCount, 0)
        XCTAssertTrue((replacementView.delegate as AnyObject?) === presenter)
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: nil,
            appliedSurfaceContract: try makeSDRSurface(),
            requiresClearBeforePresentation: false,
            configurationTransitionCount: 1,
            closedTransitionCount: 1
        ))
    }

    @MainActor
    func testUnsupportedTransitionClosesWithoutClaimingSurfaceOwnership() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let runtime = RecordingStreamMetalPresenterRuntime()
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in runtime },
            surfaceAdapterFactory: { _ in surfaceAdapter }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 37,
            frameID: 18,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 48,
            currentHeadroom: 2
        )
        surfaceAdapter.unsupportedPlatform = .tvOS

        let outcome = presenter.transition(.resolved(resolved), on: view)

        XCTAssertEqual(outcome, .closed(.surfaceUnsupported(.tvOS)))
        XCTAssertEqual(runtime.invalidationCount, 1)
        XCTAssertEqual(surfaceAdapter.activeContract, try makeSDRSurface())
        XCTAssertEqual(surfaceAdapter.contracts, [try makeSDRSurface()])
        XCTAssertNil(view.delegate)
        XCTAssertTrue(view.isPaused)
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: nil,
            appliedSurfaceContract: nil,
            requiresClearBeforePresentation: false,
            configurationTransitionCount: 0,
            closedTransitionCount: 1
        ))
    }

    @MainActor
    func testSurfaceMutationFailureClosesWithoutClaimingRolledBackSurface() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let runtime = RecordingStreamMetalPresenterRuntime()
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in runtime },
            surfaceAdapterFactory: { _ in surfaceAdapter }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 38,
            frameID: 19,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 49,
            currentHeadroom: 2
        )
        surfaceAdapter.failure = .mutationFailed(
            .drawablePixelFormat(.rgba16Float)
        )

        let outcome = presenter.transition(.resolved(resolved), on: view)

        XCTAssertEqual(outcome, .closed(.surfaceApplicationFailed))
        XCTAssertEqual(runtime.invalidationCount, 1)
        XCTAssertEqual(surfaceAdapter.activeContract, try makeSDRSurface())
        XCTAssertEqual(surfaceAdapter.contracts, [try makeSDRSurface()])
        XCTAssertNil(view.delegate)
        XCTAssertTrue(view.isPaused)
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: nil,
            appliedSurfaceContract: nil,
            requiresClearBeforePresentation: false,
            configurationTransitionCount: 0,
            closedTransitionCount: 1
        ))
    }

    private func makeResolvedConfiguration(
        for frame: DecodedVideoFrame,
        displayRevision: UInt64,
        currentHeadroom: Double,
        appliedSurfaceContract: HDRSurfaceContract? = nil
    ) throws -> HDRResolvedRenderConfiguration {
        let resolution = HDRRenderConfigurationResolver.resolve(
            HDRRenderConfigurationResolverInput(
                decodedLayout: HDRDecodedPixelBufferLayout(
                    pixelBuffer: frame.pixelBuffer
                ),
                colorMetadata: frame.colorMetadata,
                decoderGeneration: frame.generation,
                userAllowsHDR: true,
                platformCapabilities: HDRPlatformOutputCapabilities(
                    platform: .macOS,
                    headroomSource: .currentPotentialAndReference,
                    extendedRangeSurfaceSupport: .intentAndMetadata,
                    supportedEDRGamuts: [.displayP3, .ituR2020],
                    supportsSDRToneMapping: true
                ),
                displaySnapshot: HDRDisplaySnapshot(
                    revision: HDRDisplayRevision(rawValue: displayRevision),
                    displayID: "not-published",
                    headroom: DisplayHeadroom(
                        potential: max(currentHeadroom, 4),
                        current: currentHeadroom,
                        reference: 1
                    )
                ),
                isDisplayRevisionExhausted: false,
                drawableState: HDRDrawableState(
                    isAvailable: true,
                    appliedSurfaceContract: appliedSurfaceContract
                )
            )
        )
        guard let configuration = resolution.configuration else {
            throw TestError.configurationResolutionFailed
        }
        return configuration
    }

    private func makeSDRSurface() throws -> HDRSurfaceContract {
        try HDRSurfaceContract(
            drawablePixelFormat: .bgra8UnormSRGB,
            outputColorSpace: .sRGB,
            outputGamut: .sRGB,
            extendedRangeIntent: .disabled,
            metadataMode: .none
        )
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
        case configurationResolutionFailed
    }
}

@MainActor
private final class RecordingPresenterSurfaceAdapter: HDRSurfaceApplying {
    var failure: HDRSurfaceApplicationError?
    var unsupportedPlatform: AppleRenderingPlatform?
    private(set) var activeContract: HDRSurfaceContract?
    private(set) var contracts: [HDRSurfaceContract] = []

    func apply(_ contract: HDRSurfaceContract) throws -> HDRSurfaceApplicationOutcome {
        if let failure { throw failure }
        if let unsupportedPlatform,
           contract.extendedRangeIntent == .enabled {
            return .unsupported(
                platform: unsupportedPlatform,
                requested: contract
            )
        }
        guard activeContract != contract else {
            return .unchanged(contract)
        }
        let previous = activeContract
        activeContract = contract
        contracts.append(contract)
        return .applied(previous: previous, current: contract)
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
    private var storedClearCount: UInt64 = 0
    private var storedStopCount: UInt64 = 0
    private var storedInvalidationCount: UInt64 = 0

    var clearCount: UInt64 { lock.withLock { storedClearCount } }
    var stopCount: UInt64 { lock.withLock { storedStopCount } }
    var invalidationCount: UInt64 { lock.withLock { storedInvalidationCount } }

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
        lock.withLock { storedClearCount &+= 1 }
    }

    func stop() {
        lock.withLock { storedStopCount &+= 1 }
    }

    func invalidate() {
        lock.withLock { storedInvalidationCount &+= 1 }
    }

    func snapshot() -> StreamMetalPresenterRuntimeSnapshot {
        lock.withLock {
            StreamMetalPresenterRuntimeSnapshot(
                activeConfiguration: nil,
                mappedFrameGeneration: nil,
                mappedFrameID: nil,
                isInvalidated: storedInvalidationCount > 0,
                submittedFrameCount: 0,
                failedPresentationCount: 0,
                stopCount: storedStopCount,
                invalidationCount: storedInvalidationCount
            )
        }
    }
}
