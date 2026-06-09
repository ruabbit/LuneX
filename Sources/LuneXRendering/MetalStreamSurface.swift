import MetalKit
import SwiftUI

#if os(macOS)
struct MetalStreamSurface: NSViewRepresentable {
    let renderState: StreamRenderState

    func makeNSView(context: Context) -> MTKView {
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
        view.clearColor = MTLClearColor(red: 0.02, green: 0.025, blue: 0.03, alpha: 1)
        view.enableSetNeedsDisplay = false
        view.isPaused = false
        if let layer = view.layer as? CAMetalLayer {
            DisplayHeadroomReader.configure(layer, forHDRStream: renderState.headroom.supportsEDR)
        }
        return view
    }

    func updateNSView(_ view: MTKView, context: Context) {
        view.isPaused = renderState.policy != .active
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
        view.isPaused = renderState.policy != .active
    }
}
#endif
