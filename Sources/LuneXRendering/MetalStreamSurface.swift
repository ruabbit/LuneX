import Foundation
import MetalKit
import SwiftUI

enum StreamMetalPresenterError: Error, Equatable, Sendable {
    case commandQueueUnavailable
    case clearCommandUnavailable
    case clearEncoderUnavailable
    case invalidatedRuntime
}

struct StreamMetalPresentationPlan: Sendable {
    let configuration: HDRRenderConfigurationIdentity
    let uniforms: HDRMetalShaderUniforms
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

final class StreamMetalPresenterRuntime: @unchecked Sendable {
    private let mapper: any MetalVideoFrameMapping
    private let renderer: HDRMetalVideoRenderer
    private let commandQueue: any MTLCommandQueue
    private let lock = NSLock()
    private var activeConfiguration: HDRRenderConfigurationIdentity?
    private var mappedFrame: MetalVideoFrame?
    private var mappedFrameIdentity: StreamMetalMappedFrameIdentity?
    private var isInvalidated = false

    init(device: any MTLDevice, bundle: Bundle) throws {
        guard let commandQueue = device.makeCommandQueue() else {
            throw StreamMetalPresenterError.commandQueueUnavailable
        }
        mapper = try CVMetalVideoFrameMapper(device: device)
        renderer = try HDRMetalVideoRenderer(device: device, bundle: bundle)
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
            if activeConfiguration != plan.configuration {
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
            return try renderer.render(
                frame: metalFrame,
                configuration: plan.configuration,
                uniforms: plan.uniforms,
                coordinateSnapshot: coordinateSnapshot,
                target: target,
                completion: completion
            )
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
            renderer.stop()
            mapper.flush()
            activeConfiguration = nil
            mappedFrame = nil
            mappedFrameIdentity = nil
        }
    }

    func invalidate() {
        lock.withLock {
            guard !isInvalidated else { return }
            isInvalidated = true
            renderer.stop()
            mapper.flush()
            activeConfiguration = nil
            mappedFrame = nil
            mappedFrameIdentity = nil
        }
    }
}

final class StreamMetalPresenter: NSObject, MTKViewDelegate {
    private let presentationSource: StreamVideoPresentationSource
    private let lock = NSLock()
    private var renderPolicy: RenderPolicy
    private var coordinateSnapshot: StreamCoordinateSnapshot?
    private var runtime: StreamMetalPresenterRuntime?

    init(
        presentationSource: StreamVideoPresentationSource,
        renderState: StreamRenderState
    ) {
        self.presentationSource = presentationSource
        renderPolicy = renderState.policy
        coordinateSnapshot = renderState.coordinateSnapshot
    }

    @MainActor
    func configure(_ view: MTKView) {
        guard let device = view.device else { return }
        let runtime = try? StreamMetalPresenterRuntime(
            device: device,
            bundle: Bundle(for: StreamMetalPresenter.self)
        )
        withLock {
            self.runtime?.invalidate()
            self.runtime = runtime
        }
        view.colorPixelFormat = .bgra8Unorm_srgb
        view.framebufferOnly = true
        view.delegate = self
    }

    func update(renderState: StreamRenderState) {
        withLock {
            renderPolicy = renderState.policy
            coordinateSnapshot = renderState.coordinateSnapshot
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        _ = size
    }

    func draw(in view: MTKView) {
        let snapshot = withLock {
            (renderPolicy, coordinateSnapshot, runtime)
        }
        guard let runtime = snapshot.2,
              let drawable = view.currentDrawable else { return }
        guard snapshot.0 == .active || snapshot.0.isThrottled else {
            runtime.stop()
            try? runtime.clear(drawable: drawable, color: view.clearColor)
            return
        }
        guard let coordinateSnapshot = snapshot.1,
              coordinateSnapshot.drawableSize.width == drawable.texture.width,
              coordinateSnapshot.drawableSize.height == drawable.texture.height,
              let frame = presentationSource.currentFrame() else {
            try? runtime.clear(drawable: drawable, color: view.clearColor)
            return
        }
        do {
            try runtime.present(
                frame: frame,
                plan: StreamMetalPresentationPlanResolver.resolve(
                    frame: frame,
                    coordinateSnapshot: coordinateSnapshot
                ),
                coordinateSnapshot: coordinateSnapshot,
                target: HDRMetalRenderTarget(
                    texture: drawable.texture,
                    drawable: drawable
                )
            )
        } catch {
            runtime.stop()
            try? runtime.clear(drawable: drawable, color: view.clearColor)
        }
    }

    func stop() {
        withLock {
            runtime?.invalidate()
            runtime = nil
        }
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
        if let layer = view.layer as? CAMetalLayer {
            DisplayHeadroomReader.configure(layer, forHDRStream: false)
        }
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
        apply(renderState, to: view)
        if view.isPaused { view.draw() }
    }

    static func dismantleNSView(
        _ view: MacStreamInputCaptureView,
        coordinator: MacStreamSurfaceCoordinator
    ) {
        coordinator.detach(view)
    }

    private func apply(_ state: StreamRenderState, to view: MTKView) {
        switch state.policy {
        case .active:
            view.isPaused = false
            view.preferredFramesPerSecond = 60
        case .throttled:
            view.isPaused = false
            view.preferredFramesPerSecond = 15
        case .idle, .paused:
            view.isPaused = true
        }
        if let layer = view.layer as? CAMetalLayer {
            DisplayHeadroomReader.configure(layer, forHDRStream: false)
        }
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
        if let layer = view.layer as? CAMetalLayer {
            DisplayHeadroomReader.configure(layer, forHDRStream: false)
        }
        context.coordinator.configure(view)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        context.coordinator.update(renderState: renderState)
        switch renderState.policy {
        case .active:
            view.isPaused = false
            view.preferredFramesPerSecond = 60
        case .throttled:
            view.isPaused = false
            view.preferredFramesPerSecond = 15
        case .idle, .paused:
            view.isPaused = true
        }
        if let snapshot = renderState.coordinateSnapshot {
            view.drawableSize = CGSize(
                width: snapshot.drawableSize.width,
                height: snapshot.drawableSize.height
            )
        }
        if let layer = view.layer as? CAMetalLayer {
            DisplayHeadroomReader.configure(layer, forHDRStream: false)
        }
        if view.isPaused { view.draw() }
    }

    static func dismantleUIView(_ view: MTKView, coordinator: StreamMetalPresenter) {
        coordinator.stop()
        view.delegate = nil
        view.isPaused = true
    }
}
#endif
