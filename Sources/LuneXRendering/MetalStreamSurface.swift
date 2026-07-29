import Foundation
import MetalKit
import SwiftUI

enum StreamMetalPresenterError: Error, Equatable, Sendable {
    case commandQueueUnavailable
    case clearCommandUnavailable
    case clearEncoderUnavailable
    case invalidatedRuntime
}

enum StreamMetalClearReason: Equatable, Sendable {
    case inactivePolicy
    case missingCoordinates
    case drawableMismatch
    case missingFrame
}

enum StreamMetalFrameDecision: Equatable, Sendable {
    case waitForDrawable
    case clear(StreamMetalClearReason)
    case present
}

enum StreamMetalFrameDecisionResolver {
    static func resolve(
        policy: RenderPolicy,
        hasDrawable: Bool,
        hasCoordinates: Bool,
        drawableMatchesCoordinates: Bool,
        hasFrame: Bool
    ) -> StreamMetalFrameDecision {
        guard policy == .active || policy.isThrottled else {
            return .clear(.inactivePolicy)
        }
        guard hasDrawable else { return .waitForDrawable }
        guard hasCoordinates else { return .clear(.missingCoordinates) }
        guard drawableMatchesCoordinates else { return .clear(.drawableMismatch) }
        guard hasFrame else { return .clear(.missingFrame) }
        return .present
    }
}

struct StreamMetalViewSchedule: Equatable, Sendable {
    let isPaused: Bool
    let preferredFramesPerSecond: Int
    let requestsImmediateDraw: Bool
}

enum StreamMetalViewScheduleResolver {
    static func resolve(_ policy: RenderPolicy) -> StreamMetalViewSchedule {
        switch policy {
        case .active:
            return StreamMetalViewSchedule(
                isPaused: false,
                preferredFramesPerSecond: 60,
                requestsImmediateDraw: false
            )
        case .throttled:
            return StreamMetalViewSchedule(
                isPaused: false,
                preferredFramesPerSecond: 15,
                requestsImmediateDraw: false
            )
        case .idle, .paused:
            return StreamMetalViewSchedule(
                isPaused: true,
                preferredFramesPerSecond: 60,
                requestsImmediateDraw: true
            )
        }
    }
}

struct StreamMetalPresentationPlan: Sendable {
    let configuration: HDRRenderConfigurationIdentity
    let uniforms: HDRMetalShaderUniforms
}

enum StreamMetalConfigurationTransitionError: Error, Equatable, Sendable {
    case resolutionClosed(HDRRenderResolutionError)
    case staleSurface
    case surfaceApplicationFailed
    case surfaceUnsupported(AppleRenderingPlatform)
    case runtimeCreationFailed
}

enum StreamMetalConfigurationTransitionOutcome: Equatable, Sendable {
    case applied(
        previous: HDRRenderConfigurationIdentity?,
        current: HDRRenderConfigurationIdentity
    )
    case unchanged(HDRRenderConfigurationIdentity)
    case closed(StreamMetalConfigurationTransitionError)
}

struct StreamMetalPresenterSnapshot: Equatable, Sendable {
    let activeConfiguration: HDRRenderConfigurationIdentity?
    let appliedSurfaceContract: HDRSurfaceContract?
    let requiresClearBeforePresentation: Bool
    let configurationTransitionCount: UInt64
    let closedTransitionCount: UInt64
}

enum StreamMetalPresentationPlanResolver {
    static func resolve(
        frame: DecodedVideoFrame,
        coordinateSnapshot: StreamCoordinateSnapshot
    ) throws -> StreamMetalPresentationPlan {
        let frameContract = try HDRDecodedVideoContractValidator.validateForMetalMapping(
            pixelBuffer: frame.pixelBuffer,
            colorMetadata: frame.colorMetadata
        )
        guard frameContract.colorSignature == frame.renderBinding.colorSignature else {
            throw MetalFrameDeliveryError.incompatibleColorSignature
        }

        let mappingMode: HDRMappingMode = frame.colorMetadata.isHDR ? .hdrToSDR : .sdr
        let surface = try HDRSurfaceContract(
            drawablePixelFormat: .bgra8UnormSRGB,
            outputColorSpace: .sRGB,
            outputGamut: .sRGB,
            extendedRangeIntent: .disabled,
            metadataMode: .none
        )
        let configuration = try HDRRenderConfigurationIdentity(
            decoderGeneration: frame.generation,
            colorSignature: frame.renderBinding.colorSignature,
            displayRevision: HDRDisplayRevision(rawValue: coordinateSnapshot.revision),
            mappingMode: mappingMode,
            surfaceContract: surface
        )
        let luminanceMapping: HDRLuminanceMapping? = frame.colorMetadata.isHDR
            ? try HDRLuminanceMapping(
                sourcePeak: HDRSourcePeakResolver.resolve(frame.colorMetadata),
                currentHeadroom: 1
            )
            : nil
        return StreamMetalPresentationPlan(
            configuration: configuration,
            uniforms: try HDRMetalShaderUniforms(
                frameContract: frameContract,
                configuration: configuration,
                luminanceMapping: luminanceMapping
            )
        )
    }

    static func resolve(
        frame: DecodedVideoFrame,
        resolvedConfiguration: HDRResolvedRenderConfiguration
    ) throws -> StreamMetalPresentationPlan {
        let frameContract = try HDRDecodedVideoContractValidator.validateForMetalMapping(
            pixelBuffer: frame.pixelBuffer,
            colorMetadata: frame.colorMetadata
        )
        let expected = resolvedConfiguration.identity
        guard frame.generation == expected.decoderGeneration else {
            throw HDRRenderResolutionError.staleDecoderGeneration(
                expected: expected.decoderGeneration,
                actual: frame.generation
            )
        }
        guard frame.renderBinding.colorSignature == expected.colorSignature,
              frameContract.colorSignature == expected.colorSignature else {
            throw HDRRenderResolutionError.staleColorSignature
        }
        guard frameContract == resolvedConfiguration.frameContract else {
            throw HDRRenderResolutionError.incompatibleDecodedLayout
        }
        return StreamMetalPresentationPlan(
            configuration: expected,
            uniforms: try HDRMetalShaderUniforms(
                frameContract: frameContract,
                configuration: expected,
                luminanceMapping: resolvedConfiguration.luminanceMapping
            )
        )
    }
}

private struct StreamMetalMappedFrameIdentity: Equatable {
    let generation: UInt64
    let frameID: UInt64
    let colorSignature: HDRRenderColorSignature
    let pixelBuffer: ObjectIdentifier

    init(_ frame: DecodedVideoFrame) {
        generation = frame.generation
        frameID = frame.frameID
        colorSignature = frame.renderBinding.colorSignature
        pixelBuffer = ObjectIdentifier(frame.pixelBuffer)
    }
}

protocol HDRMetalVideoRendering: Sendable {
    func replaceConfiguration(_ configuration: HDRRenderConfigurationIdentity) throws
    func render(
        frame: MetalVideoFrame,
        configuration: HDRRenderConfigurationIdentity,
        uniforms: HDRMetalShaderUniforms,
        coordinateSnapshot: StreamCoordinateSnapshot,
        target: HDRMetalRenderTarget,
        completion: HDRMetalCommandCompletion
    ) throws -> HDRMetalVideoRendererResult
    func stop()
}

extension HDRMetalVideoRenderer: HDRMetalVideoRendering {}

struct StreamMetalPresenterRuntimeSnapshot: Equatable, Sendable {
    let activeConfiguration: HDRRenderConfigurationIdentity?
    let mappedFrameGeneration: UInt64?
    let mappedFrameID: UInt64?
    let isInvalidated: Bool
    let submittedFrameCount: UInt64
    let failedPresentationCount: UInt64
    let stopCount: UInt64
    let invalidationCount: UInt64
}

protocol StreamMetalPresenterRuntiming: AnyObject, Sendable {
    func present(
        frame: DecodedVideoFrame,
        plan: StreamMetalPresentationPlan,
        coordinateSnapshot: StreamCoordinateSnapshot,
        target: HDRMetalRenderTarget,
        completion: HDRMetalCommandCompletion
    ) throws -> HDRMetalVideoRendererResult
    func clear(drawable: any CAMetalDrawable, color: MTLClearColor) throws
    func stop()
    func invalidate()
    func snapshot() -> StreamMetalPresenterRuntimeSnapshot
}

final class StreamMetalPresenterRuntime: StreamMetalPresenterRuntiming,
    @unchecked Sendable {
    private let mapper: any MetalVideoFrameMapping
    private let renderer: any HDRMetalVideoRendering
    private let commandQueue: any MTLCommandQueue
    private let lock = NSLock()
    private var activeConfiguration: HDRRenderConfigurationIdentity?
    private var mappedFrame: MetalVideoFrame?
    private var mappedFrameIdentity: StreamMetalMappedFrameIdentity?
    private var ownsPresentationResources = false
    private var isInvalidated = false
    private var submittedFrameCount: UInt64 = 0
    private var failedPresentationCount: UInt64 = 0
    private var stopCount: UInt64 = 0
    private var invalidationCount: UInt64 = 0

    convenience init(device: any MTLDevice, bundle: Bundle) throws {
        guard let commandQueue = device.makeCommandQueue() else {
            throw StreamMetalPresenterError.commandQueueUnavailable
        }
        try self.init(
            mapper: CVMetalVideoFrameMapper(device: device),
            renderer: HDRMetalVideoRenderer(device: device, bundle: bundle),
            commandQueue: commandQueue
        )
    }

    init(
        mapper: any MetalVideoFrameMapping,
        renderer: any HDRMetalVideoRendering,
        commandQueue: any MTLCommandQueue
    ) {
        self.mapper = mapper
        self.renderer = renderer
        self.commandQueue = commandQueue
    }

    @discardableResult
    func present(
        frame: DecodedVideoFrame,
        plan: StreamMetalPresentationPlan,
        coordinateSnapshot: StreamCoordinateSnapshot,
        target: HDRMetalRenderTarget,
        completion: HDRMetalCommandCompletion = .asynchronous
    ) throws -> HDRMetalVideoRendererResult {
        try lock.withLock {
            guard !isInvalidated else {
                throw StreamMetalPresenterError.invalidatedRuntime
            }
            do {
                if activeConfiguration != plan.configuration {
                    ownsPresentationResources = true
                    try renderer.replaceConfiguration(plan.configuration)
                    mapper.flush()
                    mappedFrame = nil
                    mappedFrameIdentity = nil
                    activeConfiguration = plan.configuration
                }
                let identity = StreamMetalMappedFrameIdentity(frame)
                let metalFrame: MetalVideoFrame
                if mappedFrameIdentity == identity, let mappedFrame {
                    metalFrame = mappedFrame
                } else {
                    metalFrame = try mapper.map(frame)
                    mappedFrame = metalFrame
                    mappedFrameIdentity = identity
                }
                let result = try renderer.render(
                    frame: metalFrame,
                    configuration: plan.configuration,
                    uniforms: plan.uniforms,
                    coordinateSnapshot: coordinateSnapshot,
                    target: target,
                    completion: completion
                )
                submittedFrameCount &+= 1
                return result
            } catch {
                failedPresentationCount &+= 1
                releasePresentationLocked()
                throw error
            }
        }
    }

    func clear(drawable: any CAMetalDrawable, color: MTLClearColor) throws {
        try lock.withLock {
            guard !isInvalidated else {
                throw StreamMetalPresenterError.invalidatedRuntime
            }
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                throw StreamMetalPresenterError.clearCommandUnavailable
            }
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].texture = drawable.texture
            descriptor.colorAttachments[0].loadAction = .clear
            descriptor.colorAttachments[0].storeAction = .store
            descriptor.colorAttachments[0].clearColor = color
            guard let encoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: descriptor
            ) else {
                throw StreamMetalPresenterError.clearEncoderUnavailable
            }
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }

    func stop() {
        lock.withLock {
            guard ownsPresentationResources else { return }
            stopCount &+= 1
            releasePresentationLocked()
        }
    }

    func invalidate() {
        lock.withLock {
            guard !isInvalidated else { return }
            isInvalidated = true
            invalidationCount &+= 1
            releasePresentationLocked()
        }
    }

    func snapshot() -> StreamMetalPresenterRuntimeSnapshot {
        lock.withLock {
            StreamMetalPresenterRuntimeSnapshot(
                activeConfiguration: activeConfiguration,
                mappedFrameGeneration: mappedFrameIdentity?.generation,
                mappedFrameID: mappedFrameIdentity?.frameID,
                isInvalidated: isInvalidated,
                submittedFrameCount: submittedFrameCount,
                failedPresentationCount: failedPresentationCount,
                stopCount: stopCount,
                invalidationCount: invalidationCount
            )
        }
    }

    private func releasePresentationLocked() {
        guard ownsPresentationResources else {
            activeConfiguration = nil
            mappedFrame = nil
            mappedFrameIdentity = nil
            return
        }
        renderer.stop()
        mapper.flush()
        ownsPresentationResources = false
        activeConfiguration = nil
        mappedFrame = nil
        mappedFrameIdentity = nil
    }
}

final class StreamMetalPresenter: NSObject, MTKViewDelegate {
    typealias RuntimeFactory = (any MTLDevice, Bundle) throws
        -> any StreamMetalPresenterRuntiming
    typealias SurfaceAdapterFactory = @MainActor (MTKView) -> any HDRSurfaceApplying
    typealias DrawableProvider = @MainActor (MTKView) -> (any CAMetalDrawable)?

    private let presentationSource: StreamVideoPresentationSource
    private let runtimeFactory: RuntimeFactory
    private let surfaceAdapterFactory: SurfaceAdapterFactory
    private let drawableProvider: DrawableProvider
    private let lock = NSLock()
    private var renderPolicy: RenderPolicy
    private var coordinateSnapshot: StreamCoordinateSnapshot?
    private var runtime: (any StreamMetalPresenterRuntiming)?
    private var surfaceAdapter: (any HDRSurfaceApplying)?
    private weak var surfaceView: MTKView?
    private var activeResolvedConfiguration: HDRResolvedRenderConfiguration?
    private var appliedSurfaceContract: HDRSurfaceContract?
    private var requiresClearBeforePresentation = false
    private var presentationRevision: UInt64 = 0
    private var configurationTransitionCount: UInt64 = 0
    private var closedTransitionCount: UInt64 = 0

    init(
        presentationSource: StreamVideoPresentationSource,
        renderState: StreamRenderState,
        runtimeFactory: @escaping RuntimeFactory = { device, bundle in
            try StreamMetalPresenterRuntime(device: device, bundle: bundle)
        },
        surfaceAdapterFactory: @escaping SurfaceAdapterFactory = { view in
            AppleMetalSurfaceAdapter(view: view)
        },
        drawableProvider: @escaping DrawableProvider = { view in
            view.currentDrawable
        }
    ) {
        self.presentationSource = presentationSource
        self.runtimeFactory = runtimeFactory
        self.surfaceAdapterFactory = surfaceAdapterFactory
        self.drawableProvider = drawableProvider
        renderPolicy = renderState.policy
        coordinateSnapshot = renderState.coordinateSnapshot
    }

    @MainActor
    func configure(_ view: MTKView) {
        guard let device = view.device else { return }
        if let previousView = surfaceView, previousView !== view {
            stop()
        }
        let adapter: any HDRSurfaceApplying
        if surfaceView === view, let surfaceAdapter {
            adapter = surfaceAdapter
        } else {
            adapter = surfaceAdapterFactory(view)
        }
        let surface: HDRSurfaceContract
        do {
            surface = try HDRSurfaceContract(
                drawablePixelFormat: .bgra8UnormSRGB,
                outputColorSpace: .sRGB,
                outputGamut: .sRGB,
                extendedRangeIntent: .disabled,
                metadataMode: .none
            )
            let outcome = try adapter.apply(surface)
            guard outcome.activeContract == surface else {
                failSurfaceConfiguration(view)
                return
            }
        } catch {
            failSurfaceConfiguration(view)
            return
        }
        surfaceAdapter = adapter
        surfaceView = view
        let runtime = try? runtimeFactory(device, Bundle(for: StreamMetalPresenter.self))
        let previousRuntime = withLock {
            let previous = self.runtime
            self.runtime = runtime
            activeResolvedConfiguration = nil
            appliedSurfaceContract = surface
            requiresClearBeforePresentation = false
            presentationRevision &+= 1
            return previous
        }
        previousRuntime?.invalidate()
        view.framebufferOnly = true
        view.delegate = self
    }

    @MainActor
    func update(renderState: StreamRenderState) {
        let transition = withLock {
            let previousRevision = coordinateSnapshot?.revision
            renderPolicy = renderState.policy
            coordinateSnapshot = renderState.coordinateSnapshot
            guard previousRevision != coordinateSnapshot?.revision else {
                return (false, nil as (any StreamMetalPresenterRuntiming)?)
            }
            requiresClearBeforePresentation = true
            presentationRevision &+= 1
            return (true, runtime)
        }
        guard transition.0 else { return }
        transition.1?.stop()
        if StreamMetalViewScheduleResolver.resolve(renderState.policy).requestsImmediateDraw {
            surfaceView?.draw()
        }
    }

    @MainActor
    @discardableResult
    func transition(
        _ resolution: HDRRenderConfigurationResolution,
        on view: MTKView
    ) -> StreamMetalConfigurationTransitionOutcome {
        guard surfaceView === view, let adapter = surfaceAdapter else {
            return closeTransition(.staleSurface)
        }
        switch resolution {
        case let .closed(error):
            closeActivePresentation(on: view, adapter: adapter, restoreSDR: true)
            return closeTransition(.resolutionClosed(error))
        case let .resolved(configuration):
            let targetSurface = configuration.identity.surfaceContract
            let state = withLock {
                (
                    activeResolvedConfiguration,
                    appliedSurfaceContract,
                    runtime
                )
            }
            if let activeConfiguration = state.0,
               activeConfiguration.identity == configuration.identity,
               activeConfiguration.frameContract == configuration.frameContract,
               activeConfiguration.luminanceMapping == configuration.luminanceMapping,
               state.1 == targetSurface,
               state.2 != nil {
                withLock {
                    activeResolvedConfiguration = configuration
                }
                return .unchanged(configuration.identity)
            }

            let previousIdentity = state.0?.identity
            let previousSurface = state.1
            view.isPaused = true
            clearCurrentDrawable(on: view, runtime: state.2)
            deactivateRuntimeForTransition()

            let surfaceOutcome: HDRSurfaceApplicationOutcome
            do {
                surfaceOutcome = try adapter.apply(targetSurface)
            } catch {
                failSurfaceConfiguration(view)
                return closeTransition(.surfaceApplicationFailed)
            }
            guard surfaceOutcome.activeContract == targetSurface else {
                failSurfaceConfiguration(view)
                if case let .unsupported(platform, _) = surfaceOutcome {
                    return closeTransition(.surfaceUnsupported(platform))
                }
                return closeTransition(.surfaceApplicationFailed)
            }

            let replacementRuntime: any StreamMetalPresenterRuntiming
            do {
                guard let device = view.device else {
                    throw StreamMetalPresenterError.commandQueueUnavailable
                }
                replacementRuntime = try runtimeFactory(
                    device,
                    Bundle(for: StreamMetalPresenter.self)
                )
            } catch {
                restoreSurfaceAfterFailedTransition(
                    previousSurface,
                    adapter: adapter
                )
                failSurfaceConfiguration(view)
                return closeTransition(.runtimeCreationFailed)
            }

            withLock {
                runtime = replacementRuntime
                activeResolvedConfiguration = configuration
                appliedSurfaceContract = targetSurface
                requiresClearBeforePresentation = true
                presentationRevision &+= 1
                configurationTransitionCount &+= 1
            }
            view.delegate = self
            let schedule = withLock {
                StreamMetalViewScheduleResolver.resolve(renderPolicy)
            }
            view.isPaused = schedule.isPaused
            view.preferredFramesPerSecond = schedule.preferredFramesPerSecond
            view.draw()
            return .applied(
                previous: previousIdentity,
                current: configuration.identity
            )
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        _ = size
    }

    func draw(in view: MTKView) {
        let snapshot = withLock {
            (
                renderPolicy,
                coordinateSnapshot,
                runtime,
                activeResolvedConfiguration,
                requiresClearBeforePresentation,
                presentationRevision
            )
        }
        guard let runtime = snapshot.2 else { return }
        let drawable = drawableProvider(view)
        if snapshot.4 {
            guard let drawable else { return }
            do {
                try runtime.clear(drawable: drawable, color: view.clearColor)
                withLock {
                    guard presentationRevision == snapshot.5 else { return }
                    requiresClearBeforePresentation = false
                }
            } catch {
                runtime.stop()
            }
            return
        }
        let frame = presentationSource.currentFrame()
        let drawableMatchesCoordinates = snapshot.1.map { coordinates in
            coordinates.drawableSize.width == drawable?.texture.width
                && coordinates.drawableSize.height == drawable?.texture.height
        } ?? false
        let decision = StreamMetalFrameDecisionResolver.resolve(
            policy: snapshot.0,
            hasDrawable: drawable != nil,
            hasCoordinates: snapshot.1 != nil,
            drawableMatchesCoordinates: drawableMatchesCoordinates,
            hasFrame: frame != nil
        )
        switch decision {
        case .waitForDrawable:
            return
        case let .clear(reason):
            if reason == .inactivePolicy { runtime.stop() }
            if let drawable {
                try? runtime.clear(drawable: drawable, color: view.clearColor)
            }
            return
        case .present:
            break
        }
        guard let coordinateSnapshot = snapshot.1,
              let frame,
              let drawable else { return }
        do {
            let plan: StreamMetalPresentationPlan
            if let resolvedConfiguration = snapshot.3 {
                plan = try StreamMetalPresentationPlanResolver.resolve(
                    frame: frame,
                    resolvedConfiguration: resolvedConfiguration
                )
            } else {
                plan = try StreamMetalPresentationPlanResolver.resolve(
                    frame: frame,
                    coordinateSnapshot: coordinateSnapshot
                )
            }
            _ = try runtime.present(
                frame: frame,
                plan: plan,
                coordinateSnapshot: coordinateSnapshot,
                target: HDRMetalRenderTarget(
                    texture: drawable.texture,
                    drawable: drawable
                ),
                completion: .asynchronous
            )
        } catch {
            runtime.stop()
            try? runtime.clear(drawable: drawable, color: view.clearColor)
        }
    }

    @MainActor
    func stop() {
        let view = surfaceView
        view?.isPaused = true
        let oldRuntime = withLock {
            let previous = runtime
            runtime = nil
            activeResolvedConfiguration = nil
            requiresClearBeforePresentation = false
            presentationRevision &+= 1
            return previous
        }
        if let view {
            clearCurrentDrawable(on: view, runtime: oldRuntime)
        }
        oldRuntime?.invalidate()
        let restoredSurface: HDRSurfaceContract?
        if let adapter = surfaceAdapter {
            restoredSurface = applySDRSurface(using: adapter)
        } else {
            restoredSurface = nil
        }
        withLock { appliedSurfaceContract = restoredSurface }
    }

    func snapshot() -> StreamMetalPresenterSnapshot {
        withLock {
            StreamMetalPresenterSnapshot(
                activeConfiguration: activeResolvedConfiguration?.identity,
                appliedSurfaceContract: appliedSurfaceContract,
                requiresClearBeforePresentation: requiresClearBeforePresentation,
                configurationTransitionCount: configurationTransitionCount,
                closedTransitionCount: closedTransitionCount
            )
        }
    }

    @MainActor
    private func failSurfaceConfiguration(_ view: MTKView) {
        let previousRuntime = withLock {
            let previous = runtime
            runtime = nil
            activeResolvedConfiguration = nil
            appliedSurfaceContract = nil
            requiresClearBeforePresentation = false
            presentationRevision &+= 1
            return previous
        }
        previousRuntime?.invalidate()
        view.delegate = nil
        view.isPaused = true
    }

    @MainActor
    private func closeActivePresentation(
        on view: MTKView,
        adapter: any HDRSurfaceApplying,
        restoreSDR: Bool
    ) {
        view.isPaused = true
        let previousRuntime = withLock { runtime }
        clearCurrentDrawable(on: view, runtime: previousRuntime)
        deactivateRuntimeForTransition()
        let restoredSurface = restoreSDR
            ? applySDRSurface(using: adapter)
            : nil
        withLock {
            appliedSurfaceContract = restoredSurface
            requiresClearBeforePresentation = false
        }
    }

    private func deactivateRuntimeForTransition() {
        let previousRuntime = withLock {
            let previous = runtime
            runtime = nil
            activeResolvedConfiguration = nil
            requiresClearBeforePresentation = true
            presentationRevision &+= 1
            return previous
        }
        previousRuntime?.invalidate()
    }

    @MainActor
    private func clearCurrentDrawable(
        on view: MTKView,
        runtime: (any StreamMetalPresenterRuntiming)?
    ) {
        guard let runtime, let drawable = drawableProvider(view) else { return }
        try? runtime.clear(drawable: drawable, color: view.clearColor)
    }

    @MainActor
    private func applySDRSurface(
        using adapter: any HDRSurfaceApplying
    ) -> HDRSurfaceContract? {
        guard let surface = try? HDRSurfaceContract(
            drawablePixelFormat: .bgra8UnormSRGB,
            outputColorSpace: .sRGB,
            outputGamut: .sRGB,
            extendedRangeIntent: .disabled,
            metadataMode: .none
        ), let outcome = try? adapter.apply(surface),
              outcome.activeContract == surface else {
            return nil
        }
        return surface
    }

    @MainActor
    private func restoreSurfaceAfterFailedTransition(
        _ previousSurface: HDRSurfaceContract?,
        adapter: any HDRSurfaceApplying
    ) {
        if let previousSurface,
           let outcome = try? adapter.apply(previousSurface),
           outcome.activeContract == previousSurface {
            withLock { appliedSurfaceContract = previousSurface }
        } else {
            let restoredSurface = applySDRSurface(using: adapter)
            withLock { appliedSurfaceContract = restoredSurface }
        }
    }

    private func closeTransition(
        _ error: StreamMetalConfigurationTransitionError
    ) -> StreamMetalConfigurationTransitionOutcome {
        withLock { closedTransitionCount &+= 1 }
        return .closed(error)
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private extension RenderPolicy {
    var isThrottled: Bool {
        if case .throttled = self { return true }
        return false
    }
}

#if os(macOS)
@MainActor
final class MacStreamSurfaceAttachmentOwner {
    private let lifecycleMonitor: any AppKitLifecycleMonitoring
    private let attachmentHandler: @MainActor (MacStreamInputCaptureView, Bool) -> Void
    private weak var view: MacStreamInputCaptureView?
    private weak var observedWindow: NSWindow?
    private var isMonitoringWindow = false

    init(
        lifecycleMonitor: any AppKitLifecycleMonitoring,
        attachmentHandler: @escaping @MainActor (MacStreamInputCaptureView, Bool) -> Void = { _, _ in }
    ) {
        self.lifecycleMonitor = lifecycleMonitor
        self.attachmentHandler = attachmentHandler
    }

    func attach(to view: MacStreamInputCaptureView) {
        guard self.view !== view else { return }
        detach()
        self.view = view
        view.onWindowChange = { [weak self, weak view] window in
            guard let self, let view, self.view === view else { return }
            self.observe(window)
            self.attachmentHandler(view, window != nil)
        }
        view.onGeometryChange = { [weak self, weak view] in
            guard let self, let view, self.view === view else { return }
            self.lifecycleMonitor.surfaceGeometryDidChange()
        }
        observe(view.window)
        attachmentHandler(view, view.window != nil)
    }

    func detach(from candidate: MacStreamInputCaptureView? = nil) {
        guard let view else { return }
        if let candidate, view !== candidate { return }
        view.onWindowChange = nil
        view.onGeometryChange = nil
        attachmentHandler(view, false)
        view.resetTransientInputState()
        self.view = nil
        if isMonitoringWindow {
            lifecycleMonitor.detach()
            observedWindow = nil
            isMonitoringWindow = false
        }
    }

    private func observe(_ window: NSWindow?) {
        guard let view else { return }
        guard let window else {
            guard isMonitoringWindow else { return }
            lifecycleMonitor.detach()
            observedWindow = nil
            isMonitoringWindow = false
            return
        }
        guard !isMonitoringWindow || observedWindow !== window else { return }
        observedWindow = window
        isMonitoringWindow = true
        lifecycleMonitor.attach(to: window, surface: view)
    }
}

@MainActor
final class MacStreamSurfaceCaptureController {
    private let broker: MacCursorCaptureBroker
    private let leaseID = UUID()
    private weak var view: MacStreamInputCaptureView?
    private var policy = MacInputSurfacePolicy.inactive
    private var isAttached = false

    init(broker: MacCursorCaptureBroker) {
        self.broker = broker
    }

    func update(
        _ policy: MacInputSurfacePolicy,
        for view: MacStreamInputCaptureView
    ) {
        if self.view !== view {
            detach()
            self.view = view
            isAttached = view.window != nil
        }
        self.policy = policy
        applyCurrentPolicy()
    }

    func attachmentDidChange(
        for view: MacStreamInputCaptureView,
        isAttached: Bool
    ) {
        guard isAttached else {
            guard self.view === view else { return }
            view.isInputCaptureEnabled = false
            self.isAttached = false
            _ = broker.release(leaseID: leaseID)
            self.view = nil
            return
        }
        guard self.view == nil || self.view === view else { return }
        self.view = view
        self.isAttached = true
        applyCurrentPolicy()
    }

    func exitRelativeCapture() {
        guard policy.cursorPolicy.capturesRelativePointer,
              let view else { return }
        view.isInputCaptureEnabled = false
        _ = broker.apply(
            CursorCapturePolicyResolver.resolve(
                isStreamActive: false,
                isVisible: false,
                isFocused: false,
                prefersRemotePointer: false
            ),
            leaseID: leaseID
        )
    }

    func detach(from candidate: MacStreamInputCaptureView? = nil) {
        guard let view else { return }
        if let candidate, view !== candidate { return }
        view.isInputCaptureEnabled = false
        _ = broker.release(leaseID: leaseID)
        self.view = nil
        isAttached = false
        policy = .inactive
    }

    private func applyCurrentPolicy() {
        guard let view else { return }
        guard isAttached else {
            view.isInputCaptureEnabled = false
            _ = broker.release(leaseID: leaseID)
            return
        }
        guard policy.admitsInput else {
            view.isInputCaptureEnabled = false
            _ = broker.apply(
                MacInputSurfacePolicy.inactive.cursorPolicy,
                leaseID: leaseID
            )
            return
        }

        let cursorReady = broker.apply(policy.cursorPolicy, leaseID: leaseID)
        view.isInputCaptureEnabled = cursorReady
    }
}

@MainActor
final class MacStreamSurfaceCoordinator {
    let presenter: StreamMetalPresenter
    let attachmentOwner: MacStreamSurfaceAttachmentOwner
    let captureController: MacStreamSurfaceCaptureController
    private var inputSampleHandler: MacStreamInputCaptureView.SampleHandler
    private var captureExitHandler: @MainActor () -> Void

    init(
        presentationSource: StreamVideoPresentationSource,
        renderState: StreamRenderState,
        lifecycle: PlatformLifecycleState,
        inputSampleHandler: @escaping MacStreamInputCaptureView.SampleHandler,
        captureExitHandler: @escaping @MainActor () -> Void,
        cursorBroker: MacCursorCaptureBroker = .shared
    ) {
        presenter = StreamMetalPresenter(
            presentationSource: presentationSource,
            renderState: renderState
        )
        let captureController = MacStreamSurfaceCaptureController(broker: cursorBroker)
        self.captureController = captureController
        attachmentOwner = MacStreamSurfaceAttachmentOwner(
            lifecycleMonitor: AppKitLifecycleMonitor(lifecycle: lifecycle),
            attachmentHandler: { view, isAttached in
                captureController.attachmentDidChange(
                    for: view,
                    isAttached: isAttached
                )
            }
        )
        self.inputSampleHandler = inputSampleHandler
        self.captureExitHandler = captureExitHandler
    }

    func update(
        renderState: StreamRenderState,
        inputPolicy: MacInputSurfacePolicy,
        view: MacStreamInputCaptureView,
        inputSampleHandler: @escaping MacStreamInputCaptureView.SampleHandler,
        captureExitHandler: @escaping @MainActor () -> Void
    ) {
        presenter.update(renderState: renderState)
        captureController.update(inputPolicy, for: view)
        self.inputSampleHandler = inputSampleHandler
        self.captureExitHandler = captureExitHandler
    }

    func handle(_ sample: MacPlatformInputSample) {
        inputSampleHandler(sample)
    }

    func exitCapture() {
        captureController.exitRelativeCapture()
        captureExitHandler()
    }

    func detach(_ view: MacStreamInputCaptureView) {
        presenter.stop()
        captureController.detach(from: view)
        attachmentOwner.detach(from: view)
        view.delegate = nil
        view.isPaused = true
    }
}

struct MetalStreamSurface: NSViewRepresentable {
    let renderState: StreamRenderState
    let presentationSource: StreamVideoPresentationSource
    let lifecycle: PlatformLifecycleState
    var inputPolicy = MacInputSurfacePolicy.inactive
    var inputSampleHandler: MacStreamInputCaptureView.SampleHandler = { _ in }
    var captureExitHandler: @MainActor () -> Void = {}

    func makeCoordinator() -> MacStreamSurfaceCoordinator {
        MacStreamSurfaceCoordinator(
            presentationSource: presentationSource,
            renderState: renderState,
            lifecycle: lifecycle,
            inputSampleHandler: inputSampleHandler,
            captureExitHandler: captureExitHandler
        )
    }

    func makeNSView(context: Context) -> MacStreamInputCaptureView {
        let view = MacStreamInputCaptureView(
            frame: .zero,
            device: MTLCreateSystemDefaultDevice(),
            isInputCaptureEnabled: false,
            forwardsSystemShortcuts: inputPolicy.forwardsSystemShortcuts,
            captureExitHandler: { context.coordinator.exitCapture() },
            sampleHandler: { context.coordinator.handle($0) }
        )
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.enableSetNeedsDisplay = false
        view.isPaused = true
        context.coordinator.presenter.configure(view)
        context.coordinator.captureController.update(inputPolicy, for: view)
        context.coordinator.attachmentOwner.attach(to: view)
        return view
    }

    func updateNSView(_ view: MacStreamInputCaptureView, context: Context) {
        view.forwardsSystemShortcuts = inputPolicy.forwardsSystemShortcuts
        context.coordinator.update(
            renderState: renderState,
            inputPolicy: inputPolicy,
            view: view,
            inputSampleHandler: inputSampleHandler,
            captureExitHandler: captureExitHandler
        )
        context.coordinator.attachmentOwner.attach(to: view)
        let schedule = apply(renderState, to: view)
        if schedule.requestsImmediateDraw { view.draw() }
    }

    static func dismantleNSView(
        _ view: MacStreamInputCaptureView,
        coordinator: MacStreamSurfaceCoordinator
    ) {
        coordinator.detach(view)
    }

    private func apply(
        _ state: StreamRenderState,
        to view: MTKView
    ) -> StreamMetalViewSchedule {
        let schedule = StreamMetalViewScheduleResolver.resolve(state.policy)
        view.isPaused = schedule.isPaused
        view.preferredFramesPerSecond = schedule.preferredFramesPerSecond
        return schedule
    }
}
#else
struct MetalStreamSurface: UIViewRepresentable {
    let renderState: StreamRenderState
    let presentationSource: StreamVideoPresentationSource

    func makeCoordinator() -> StreamMetalPresenter {
        StreamMetalPresenter(
            presentationSource: presentationSource,
            renderState: renderState
        )
    }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.enableSetNeedsDisplay = false
        view.isPaused = true
        context.coordinator.configure(view)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.update(renderState: renderState)
        let schedule = StreamMetalViewScheduleResolver.resolve(renderState.policy)
        view.isPaused = schedule.isPaused
        view.preferredFramesPerSecond = schedule.preferredFramesPerSecond
        if let snapshot = renderState.coordinateSnapshot {
            view.drawableSize = CGSize(
                width: snapshot.drawableSize.width,
                height: snapshot.drawableSize.height
            )
        }
        if schedule.requestsImmediateDraw { view.draw() }
    }

    static func dismantleUIView(_ view: MTKView, coordinator: StreamMetalPresenter) {
        coordinator.stop()
        view.delegate = nil
        view.isPaused = true
    }
}
#endif
