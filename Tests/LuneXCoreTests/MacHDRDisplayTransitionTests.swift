#if os(macOS)
import AppKit
import CoreMedia
import CoreVideo
@preconcurrency import Metal
import MetalKit
import QuartzCore
import XCTest

@MainActor
final class MacHDRDisplayTransitionTests: XCTestCase {
    func testScreenAndSameDisplayHeadroomChangesRebuildRevisionOwnedRuntime() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let lifecycle = PlatformLifecycleState()
        let oldOwner = UUID()
        lifecycle.claimSurfaceAttachment(oldOwner)
        XCTAssertNotNil(lifecycle.updateSurface(
            for: oldOwner,
            displayID: "display-a",
            headroom: headroom(current: 4),
            drawableSize: PixelSize(width: 64, height: 64)
        ))

        let source = StreamVideoPresentationSource()
        let renderState = activeRenderState()
        let adapter = MacHDRRecordingSurfaceAdapter()
        var runtimes: [MacHDRRecordingPresenterRuntime] = []
        let presenter = StreamMetalPresenter(
            presentationSource: source,
            renderState: renderState,
            runtimeFactory: { _, _ in
                let runtime = MacHDRRecordingPresenterRuntime()
                runtimes.append(runtime)
                return runtime
            },
            surfaceAdapterFactory: { _ in adapter }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 41,
            frameID: 1,
            metadata: .hdr10VideoRange()
        )

        let first = try resolve(
            frame: frame,
            lifecycle: lifecycle,
            appliedSurface: presenter.snapshot().appliedSurfaceContract
        )
        XCTAssertEqual(first.identity.displayRevision.rawValue, 1)
        XCTAssertEqual(first.identity.mappingMode, .hdrEDR)
        XCTAssertEqual(first.luminanceMapping?.currentHeadroom, 4)
        XCTAssertEqual(
            presenter.transition(.resolved(first), on: view),
            .applied(previous: nil, current: first.identity)
        )
        XCTAssertEqual(runtimes.count, 2)

        XCTAssertNotNil(lifecycle.updateSurface(
            for: oldOwner,
            displayID: "display-a",
            headroom: headroom(current: 2),
            drawableSize: PixelSize(width: 64, height: 64)
        ))
        let reduced = try resolve(
            frame: frame,
            lifecycle: lifecycle,
            appliedSurface: presenter.snapshot().appliedSurfaceContract
        )
        XCTAssertEqual(reduced.identity.displayRevision.rawValue, 2)
        XCTAssertEqual(reduced.luminanceMapping?.currentHeadroom, 2)
        XCTAssertEqual(
            presenter.transition(.resolved(reduced), on: view),
            .applied(previous: first.identity, current: reduced.identity)
        )
        XCTAssertEqual(runtimes.count, 3)
        XCTAssertEqual(runtimes[1].invalidationCount, 1)

        XCTAssertNotNil(lifecycle.updateSurface(
            for: oldOwner,
            displayID: "display-b",
            headroom: headroom(current: 2),
            drawableSize: PixelSize(width: 64, height: 64)
        ))
        let moved = try resolve(
            frame: frame,
            lifecycle: lifecycle,
            appliedSurface: presenter.snapshot().appliedSurfaceContract
        )
        XCTAssertEqual(moved.identity.displayRevision.rawValue, 3)
        XCTAssertEqual(
            presenter.transition(.resolved(moved), on: view),
            .applied(previous: reduced.identity, current: moved.identity)
        )
        XCTAssertEqual(runtimes.count, 4)
        XCTAssertEqual(runtimes[2].invalidationCount, 1)

        let replacementOwner = UUID()
        lifecycle.claimSurfaceAttachment(replacementOwner)
        let replacementSnapshot = lifecycle.displaySnapshot
        XCTAssertNil(lifecycle.updateSurface(
            for: oldOwner,
            displayID: "stale-display",
            headroom: headroom(current: 8),
            drawableSize: PixelSize(width: 777, height: 555)
        ))
        XCTAssertEqual(lifecycle.displaySnapshot, replacementSnapshot)
        XCTAssertEqual(lifecycle.displayID, "display-b")
        XCTAssertEqual(lifecycle.drawableSize, PixelSize(width: 64, height: 64))

        presenter.stop()
        XCTAssertEqual(runtimes[3].invalidationCount, 1)
        XCTAssertEqual(adapter.activeContract, try makeSDRSurface())
        XCTAssertTrue(lifecycle.clearSurfaceAttachment(replacementOwner))
        XCTAssertNil(lifecycle.displaySnapshot)
        XCTAssertEqual(lifecycle.displayRevision.rawValue, 4)
    }

    func testSDROnEDRAndHDRFallbackRecoveryUseExplicitSurfaceModes() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let lifecycle = PlatformLifecycleState()
        let owner = UUID()
        lifecycle.claimSurfaceAttachment(owner)
        XCTAssertNotNil(lifecycle.updateSurface(
            for: owner,
            displayID: "display-a",
            headroom: headroom(current: 4),
            drawableSize: PixelSize(width: 64, height: 64)
        ))

        let adapter = MacHDRRecordingSurfaceAdapter()
        var runtimes: [MacHDRRecordingPresenterRuntime] = []
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: activeRenderState(),
            runtimeFactory: { _, _ in
                let runtime = MacHDRRecordingPresenterRuntime()
                runtimes.append(runtime)
                return runtime
            },
            surfaceAdapterFactory: { _ in adapter }
        )
        presenter.configure(view)

        let sdrFrame = try makeFrame(
            generation: 51,
            frameID: 1,
            metadata: .rec709VideoRange()
        )
        let sdr = try resolve(
            frame: sdrFrame,
            lifecycle: lifecycle,
            appliedSurface: presenter.snapshot().appliedSurfaceContract
        )
        XCTAssertEqual(sdr.outputMode, .sdr)
        XCTAssertEqual(sdr.identity.mappingMode, .sdr)
        XCTAssertEqual(sdr.identity.surfaceContract, try makeSDRSurface())
        XCTAssertEqual(
            presenter.transition(.resolved(sdr), on: view),
            .applied(previous: nil, current: sdr.identity)
        )

        XCTAssertNotNil(lifecycle.updateSurface(
            for: owner,
            displayID: "display-a",
            headroom: headroom(current: 1),
            drawableSize: PixelSize(width: 64, height: 64)
        ))
        let hdrFrame = try makeFrame(
            generation: 52,
            frameID: 2,
            metadata: .hdr10VideoRange()
        )
        let fallback = try resolve(
            frame: hdrFrame,
            lifecycle: lifecycle,
            appliedSurface: presenter.snapshot().appliedSurfaceContract
        )
        XCTAssertEqual(
            fallback.outputMode,
            .sdrFallback(.currentHeadroomInsufficient)
        )
        XCTAssertEqual(fallback.identity.mappingMode, .hdrToSDR)
        XCTAssertEqual(fallback.luminanceMapping?.currentHeadroom, 1)
        XCTAssertEqual(fallback.identity.surfaceContract, try makeSDRSurface())
        XCTAssertEqual(
            presenter.transition(.resolved(fallback), on: view),
            .applied(previous: sdr.identity, current: fallback.identity)
        )

        XCTAssertNotNil(lifecycle.updateSurface(
            for: owner,
            displayID: "display-a",
            headroom: headroom(current: 3),
            drawableSize: PixelSize(width: 64, height: 64)
        ))
        let edr = try resolve(
            frame: hdrFrame,
            lifecycle: lifecycle,
            appliedSurface: presenter.snapshot().appliedSurfaceContract
        )
        XCTAssertEqual(edr.outputMode, .edr)
        XCTAssertEqual(edr.identity.mappingMode, .hdrEDR)
        XCTAssertEqual(edr.luminanceMapping?.currentHeadroom, 3)
        XCTAssertEqual(edr.identity.surfaceContract.extendedRangeIntent, .enabled)
        XCTAssertEqual(
            presenter.transition(.resolved(edr), on: view),
            .applied(previous: fallback.identity, current: edr.identity)
        )

        XCTAssertEqual(runtimes.count, 4)
        XCTAssertEqual(runtimes[1].invalidationCount, 1)
        XCTAssertEqual(runtimes[2].invalidationCount, 1)
        XCTAssertEqual(adapter.activeContract, edr.identity.surfaceContract)
    }

    func testFirstOpaqueClearCompletesBeforeMatchingFramePresentation() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let layer = CAMetalLayer()
        layer.device = device
        layer.pixelFormat = .bgra8Unorm_srgb
        layer.drawableSize = CGSize(width: 64, height: 64)
        let drawable = try XCTUnwrap(layer.nextDrawable())
        let view = MTKView(frame: .zero, device: device)
        let lifecycle = PlatformLifecycleState()
        lifecycle.updateSurface(
            displayID: "display-a",
            headroom: headroom(current: 3),
            drawableSize: PixelSize(width: 64, height: 64)
        )
        let source = StreamVideoPresentationSource()
        let frame = try makeFrame(
            generation: 61,
            frameID: 3,
            metadata: .hdr10VideoRange()
        )
        let sessionID = UUID()
        source.beginSession(sessionID: sessionID, mediaGeneration: 1)
        source.consume(
            .sessionStarted(
                generation: frame.generation,
                colorMetadata: frame.colorMetadata
            ),
            sessionID: sessionID,
            mediaGeneration: 1
        )
        source.consume(
            .frame(frame),
            sessionID: sessionID,
            mediaGeneration: 1
        )

        let adapter = MacHDRRecordingSurfaceAdapter()
        var runtimes: [MacHDRRecordingPresenterRuntime] = []
        let presenter = StreamMetalPresenter(
            presentationSource: source,
            renderState: activeRenderState(),
            runtimeFactory: { _, _ in
                let runtime = MacHDRRecordingPresenterRuntime()
                runtimes.append(runtime)
                return runtime
            },
            surfaceAdapterFactory: { _ in adapter },
            drawableProvider: { _ in drawable }
        )
        presenter.configure(view)
        let configuration = try resolve(
            frame: frame,
            lifecycle: lifecycle,
            appliedSurface: presenter.snapshot().appliedSurfaceContract
        )

        XCTAssertEqual(
            presenter.transition(.resolved(configuration), on: view),
            .applied(previous: nil, current: configuration.identity)
        )
        XCTAssertEqual(runtimes.count, 2)
        XCTAssertEqual(runtimes[0].clearCount, 1)
        XCTAssertEqual(runtimes[0].invalidationCount, 1)
        XCTAssertEqual(runtimes[1].clearCount, 0)
        XCTAssertEqual(runtimes[1].presentCount, 0)
        XCTAssertTrue(presenter.snapshot().requiresClearBeforePresentation)

        presenter.draw(in: view)

        XCTAssertEqual(runtimes[1].clearCount, 1)
        XCTAssertEqual(runtimes[1].presentCount, 0)
        XCTAssertFalse(presenter.snapshot().requiresClearBeforePresentation)

        presenter.draw(in: view)

        XCTAssertEqual(runtimes[1].clearCount, 1)
        XCTAssertEqual(runtimes[1].presentCount, 1)
        XCTAssertEqual(
            runtimes[1].presentedConfigurations,
            [configuration.identity]
        )
    }

    private func resolve(
        frame: DecodedVideoFrame,
        lifecycle: PlatformLifecycleState,
        appliedSurface: HDRSurfaceContract?
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
                displaySnapshot: lifecycle.displaySnapshot,
                isDisplayRevisionExhausted: lifecycle.isDisplayRevisionExhausted,
                drawableState: HDRDrawableState(
                    isAvailable: lifecycle.drawableSize.width > 0
                        && lifecycle.drawableSize.height > 0,
                    appliedSurfaceContract: appliedSurface
                )
            )
        )
        guard let configuration = resolution.configuration else {
            throw MacHDRTransitionTestError.configurationResolutionFailed(
                resolution.error
            )
        }
        return configuration
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
            throw MacHDRTransitionTestError.pixelBufferCreationFailed(status)
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

    private func activeRenderState() -> StreamRenderState {
        let state = StreamRenderState(transform: RenderTransform(
            sourceSize: PixelSize(width: 64, height: 64),
            drawableSize: PixelSize(width: 64, height: 64),
            mode: .fit
        ))
        state.policy = .active
        return state
    }

    private func headroom(current: Double) -> DisplayHeadroom {
        DisplayHeadroom(
            potential: max(current, 4),
            current: current,
            reference: 1
        )
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
}

private enum MacHDRTransitionTestError: Error {
    case pixelBufferCreationFailed(CVReturn)
    case configurationResolutionFailed(HDRRenderResolutionError?)
}

@MainActor
private final class MacHDRRecordingSurfaceAdapter: HDRSurfaceApplying {
    private(set) var activeContract: HDRSurfaceContract?
    private(set) var requests: [HDRSurfaceContract] = []

    func apply(_ contract: HDRSurfaceContract) throws -> HDRSurfaceApplicationOutcome {
        requests.append(contract)
        guard activeContract != contract else {
            return .unchanged(contract)
        }
        let previous = activeContract
        activeContract = contract
        return .applied(previous: previous, current: contract)
    }
}

private final class MacHDRRecordingPresenterRuntime:
    StreamMetalPresenterRuntiming, @unchecked Sendable {
    private let lock = NSLock()
    private var storedClearCount: UInt64 = 0
    private var storedPresentCount: UInt64 = 0
    private var storedStopCount: UInt64 = 0
    private var storedInvalidationCount: UInt64 = 0
    private var storedConfigurations: [HDRRenderConfigurationIdentity] = []

    var clearCount: UInt64 { lock.withLock { storedClearCount } }
    var presentCount: UInt64 { lock.withLock { storedPresentCount } }
    var invalidationCount: UInt64 {
        lock.withLock { storedInvalidationCount }
    }
    var presentedConfigurations: [HDRRenderConfigurationIdentity] {
        lock.withLock { storedConfigurations }
    }

    func present(
        frame: DecodedVideoFrame,
        plan: StreamMetalPresentationPlan,
        coordinateSnapshot: StreamCoordinateSnapshot,
        target: HDRMetalRenderTarget,
        completion: HDRMetalCommandCompletion
    ) throws -> HDRMetalVideoRendererResult {
        _ = target
        _ = completion
        lock.withLock {
            storedPresentCount &+= 1
            storedConfigurations.append(plan.configuration)
        }
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
                activeConfiguration: storedConfigurations.last,
                mappedFrameGeneration: nil,
                mappedFrameID: nil,
                isInvalidated: storedInvalidationCount > 0,
                submittedFrameCount: storedPresentCount,
                failedPresentationCount: 0,
                stopCount: storedStopCount,
                invalidationCount: storedInvalidationCount
            )
        }
    }
}
#endif
