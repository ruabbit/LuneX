@preconcurrency import CoreImage
import Foundation
import MetalKit
import SwiftUI

final class StreamMetalPresenter: NSObject, MTKViewDelegate {
    private let presentationSource: StreamVideoPresentationSource
    private let lock = NSLock()
    private var renderState: StreamRenderState
    private var commandQueue: (any MTLCommandQueue)?
    private var context: CIContext?
    private let outputColorSpace = CGColorSpace(name: CGColorSpace.sRGB)
        ?? CGColorSpaceCreateDeviceRGB()

    init(
        presentationSource: StreamVideoPresentationSource,
        renderState: StreamRenderState
    ) {
        self.presentationSource = presentationSource
        self.renderState = renderState
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
        withLock { self.renderState = renderState }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        _ = size
    }

    func draw(in view: MTKView) {
        let snapshot = withLock { (renderState, commandQueue, context) }
        guard let commandQueue = snapshot.1,
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

        guard snapshot.0.policy == .active || snapshot.0.policy.isThrottled,
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
            in: bounds,
            mode: snapshot.0.transform.mode
        )
        snapshot.2?.render(
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
        in bounds: CGRect,
        mode: RenderScaleMode
    ) -> CIImage {
        guard image.extent.width > 0,
              image.extent.height > 0,
              bounds.width > 0,
              bounds.height > 0 else { return image }
        let horizontalScale = bounds.width / image.extent.width
        let verticalScale = bounds.height / image.extent.height
        let scale = mode == .fit
            ? min(horizontalScale, verticalScale)
            : max(horizontalScale, verticalScale)
        let scaledWidth = image.extent.width * scale
        let scaledHeight = image.extent.height * scale
        let translationX = bounds.midX - scaledWidth / 2 - image.extent.minX * scale
        let translationY = bounds.midY - scaledHeight / 2 - image.extent.minY * scale
        return image.transformed(by: CGAffineTransform(
            a: scale,
            b: 0,
            c: 0,
            d: scale,
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
struct MetalStreamSurface: NSViewRepresentable {
    let renderState: StreamRenderState
    let presentationSource: StreamVideoPresentationSource

    func makeCoordinator() -> StreamMetalPresenter {
        StreamMetalPresenter(
            presentationSource: presentationSource,
            renderState: renderState
        )
    }

    func makeNSView(context: Context) -> MTKView {
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

    func updateNSView(_ view: MTKView, context: Context) {
        context.coordinator.update(renderState: renderState)
        apply(renderState, to: view)
        if view.isPaused { view.draw() }
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
        if state.transform.drawableSize.width > 0, state.transform.drawableSize.height > 0 {
            view.drawableSize = CGSize(
                width: state.transform.drawableSize.width,
                height: state.transform.drawableSize.height
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
        if let layer = view.layer as? CAMetalLayer {
            DisplayHeadroomReader.configure(layer, forHDRStream: renderState.headroom.supportsEDR)
        }
        if view.isPaused { view.draw() }
    }
}
#endif
