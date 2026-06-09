#if !os(macOS)
import UIKit
import SwiftUI

@MainActor
final class UIKitLifecycleMonitor {
    private let lifecycle: PlatformLifecycleState

    init(lifecycle: PlatformLifecycleState) {
        self.lifecycle = lifecycle
    }

    func update(scenePhase: ScenePhase) {
        lifecycle.isVisible = scenePhase == .active
        lifecycle.isFocused = scenePhase == .active
        lifecycle.updateRenderPolicy()
    }

    func updateViewSize(points: CGSize, scale: CGFloat) {
        lifecycle.drawableSize = PixelSize(
            width: Int(points.width * scale),
            height: Int(points.height * scale)
        )
    }
}
#endif
