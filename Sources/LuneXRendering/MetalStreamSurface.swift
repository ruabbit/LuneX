@preconcurrency import CoreImage
import Foundation
import MetalKit
import SwiftUI

final class StreamMetalPresenter: NSObject, MTKViewDelegate {
    private let presentationSource: StreamVideoPresentationSource
    private let lock = NSLock()
    private var renderPolicy: RenderPolicy
    private var coordinateSnapshot: StreamCoordinateSnapshot?
    private var commandQueue: (any MTLCommandQueue)?
    private var context: CIContext?
    private let outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        ?? CGColorSpaceCreateDeviceRGB()

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
        withLock {
            commandQueue = device.makeCommandQueue()
            context = CIContext(mtlDevice: device)
        }
        view.framebufferOnly = false
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
            (renderPolicy, coordinateSnapshot, commandQueue, context)
        }
        guard let commandQueue = snapshot.2,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let drawable = view.currentDrawable,
              let descriptor = view.currentRenderPassDescriptor else { return }

        descriptor.colorAttachments[0].loadAction = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor = view.clearColor
        guard let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor) else {
            return
        }
        encoder.endEncoding()

        guard snapshot.0 == .active || snapshot.0.isThrottled,
              let coordinateSnapshot = snapshot.1,
              coordinateSnapshot.drawableSize.width == drawable.texture.width,
              coordinateSnapshot.drawableSize.height == drawable.texture.height,
              let frame = presentationSource.currentFrame() else {
            commandBuffer.present(drawable)
            commandBuffer.commit()
            return
        }
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: drawable.texture.width,
            height: drawable.texture.height
        )
        let image = positioned(
            CIImage(cvPixelBuffer: frame.pixelBuffer),
            using: coordinateSnapshot.resolvedVideo
        )
        snapshot.3?.render(
            image,
            to: drawable.texture,
            commandBuffer: commandBuffer,
            bounds: bounds,
            colorSpace: outputColorSpace
        )
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }

    private func positioned(
        _ image: CIImage,
        using resolvedVideo: ResolvedVideoRectangle
    ) -> CIImage {
        guard image.extent.width > 0,
              image.extent.height > 0 else { return image }
        let videoRect = resolvedVideo.videoRect
        let horizontalScale = videoRect.width / image.extent.width
        let verticalScale = videoRect.height / image.extent.height
        let translationX = videoRect.minX - image.extent.minX * horizontalScale
        let translationY = videoRect.minY - image.extent.minY * verticalScale
        return image.transformed(by: CGAffineTransform(
            a: horizontalScale,
            b: 0,
            c: 0,
            d: verticalScale,
            tx: translationX,
            ty: translationY
        ))
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
    private weak var view: MacStreamInputCaptureView?
    private weak var observedWindow: NSWindow?
    private var isMonitoringWindow = false

    init(lifecycleMonitor: any AppKitLifecycleMonitoring) {
        self.lifecycleMonitor = lifecycleMonitor
    }

    func attach(to view: MacStreamInputCaptureView) {
        guard self.view !== view else { return }
        detach()
        self.view = view
        view.onWindowChange = { [weak self, weak view] window in
            guard let self, let view, self.view === view else { return }
            self.observe(window)
        }
        observe(view.window)
    }

    func detach(from candidate: MacStreamInputCaptureView? = nil) {
        guard let view else { return }
        if let candidate, view !== candidate { return }
        view.onWindowChange = nil
        view.resetTransientInputState()
        self.view = nil
        if isMonitoringWindow {
            lifecycleMonitor.detach()
            observedWindow = nil
            isMonitoringWindow = false
        }
    }

    private func observe(_ window: NSWindow?) {
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
        lifecycleMonitor.attach(to: window)
    }
}

@MainActor
final class MacStreamSurfaceCoordinator {
    let presenter: StreamMetalPresenter
    let attachmentOwner: MacStreamSurfaceAttachmentOwner
    private var inputSampleHandler: MacStreamInputCaptureView.SampleHandler
    private var captureExitHandler: @MainActor () -> Void

    init(
        presentationSource: StreamVideoPresentationSource,
        renderState: StreamRenderState,
        lifecycle: PlatformLifecycleState,
        inputSampleHandler: @escaping MacStreamInputCaptureView.SampleHandler,
        captureExitHandler: @escaping @MainActor () -> Void
    ) {
        presenter = StreamMetalPresenter(
            presentationSource: presentationSource,
            renderState: renderState
        )
        attachmentOwner = MacStreamSurfaceAttachmentOwner(
            lifecycleMonitor: AppKitLifecycleMonitor(lifecycle: lifecycle)
        )
        self.inputSampleHandler = inputSampleHandler
        self.captureExitHandler = captureExitHandler
    }

    func update(
        renderState: StreamRenderState,
        inputSampleHandler: @escaping MacStreamInputCaptureView.SampleHandler,
        captureExitHandler: @escaping @MainActor () -> Void
    ) {
        presenter.update(renderState: renderState)
        self.inputSampleHandler = inputSampleHandler
        self.captureExitHandler = captureExitHandler
    }

    func handle(_ sample: MacPlatformInputSample) {
        inputSampleHandler(sample)
    }

    func exitCapture() {
        captureExitHandler()
    }

    func detach(_ view: MacStreamInputCaptureView) {
        attachmentOwner.detach(from: view)
        view.delegate = nil
        view.isPaused = true
    }
}

struct MetalStreamSurface: NSViewRepresentable {
    let renderState: StreamRenderState
    let presentationSource: StreamVideoPresentationSource
    let lifecycle: PlatformLifecycleState
    var isInputCaptureEnabled = false
    var forwardsSystemShortcuts = false
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
            isInputCaptureEnabled: isInputCaptureEnabled,
            forwardsSystemShortcuts: forwardsSystemShortcuts,
            captureExitHandler: { context.coordinator.exitCapture() },
            sampleHandler: { context.coordinator.handle($0) }
        )
        view.clearColor = MTLClearColor(red: 0.02, green: 0.025, blue: 0.03, alpha: 1)
        view.enableSetNeedsDisplay = false
        view.isPaused = true
        if let layer = view.layer as? CAMetalLayer {
            DisplayHeadroomReader.configure(layer, forHDRStream: renderState.headroom.supportsEDR)
        }
        context.coordinator.presenter.configure(view)
        context.coordinator.attachmentOwner.attach(to: view)
        return view
    }

    func updateNSView(_ view: MacStreamInputCaptureView, context: Context) {
        context.coordinator.update(
            renderState: renderState,
            inputSampleHandler: inputSampleHandler,
            captureExitHandler: captureExitHandler
        )
        view.isInputCaptureEnabled = isInputCaptureEnabled
        view.forwardsSystemShortcuts = forwardsSystemShortcuts
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
        if let snapshot = state.coordinateSnapshot {
            view.drawableSize = CGSize(
                width: snapshot.drawableSize.width,
                height: snapshot.drawableSize.height
            )
        }
        if let layer = view.layer as? CAMetalLayer {
            DisplayHeadroomReader.configure(layer, forHDRStream: state.headroom.supportsEDR)
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
        view.clearColor = MTLClearColor(red: 0.02, green: 0.025, blue: 0.03, alpha: 1)
        view.enableSetNeedsDisplay = false
        view.isPaused = true
        if let layer = view.layer as? CAMetalLayer {
            DisplayHeadroomReader.configure(layer, forHDRStream: renderState.headroom.supportsEDR)
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
            DisplayHeadroomReader.configure(layer, forHDRStream: renderState.headroom.supportsEDR)
        }
        if view.isPaused { view.draw() }
    }
}
#endif
