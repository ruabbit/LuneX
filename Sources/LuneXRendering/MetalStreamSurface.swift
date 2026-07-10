import MetalKit
import SwiftUI

#if os(macOS)
struct MetalStreamSurface: NSViewRepresentable {
    let renderState: StreamRenderState

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.clearColor = MTLClearColor(red: 0.02, green: 0.025, blue: 0.03, alpha: 1)
        view.enableSetNeedsDisplay = false
        view.isPaused = true
        if let layer = view.layer as? CAMetalLayer {
            DisplayHeadroomReader.configure(layer, forHDRStream: renderState.headroom.supportsEDR)
        }
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        apply(renderState, to: view)
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

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.clearColor = MTLClearColor(red: 0.02, green: 0.025, blue: 0.03, alpha: 1)
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        if let layer = view.layer as? CAMetalLayer {
            DisplayHeadroomReader.configure(layer, forHDRStream: renderState.headroom.supportsEDR)
        }
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
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
    }
}
#endif
