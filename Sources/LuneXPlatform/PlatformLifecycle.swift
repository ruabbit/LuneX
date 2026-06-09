import Foundation
import Observation

@Observable
final class PlatformLifecycleState {
    var isStreamActive = false
    var isVisible = true
    var isFocused = true
    var displayID: String?
    var drawableSize: PixelSize = .zero
    var renderPolicy: RenderPolicy = .idle

    func updateRenderPolicy() {
        renderPolicy = LifecycleRenderPolicyResolver.resolve(
            isStreamActive: isStreamActive,
            isVisible: isVisible,
            isFocused: isFocused,
            drawableSize: drawableSize
        )
    }

    func setStreamActive(_ active: Bool) {
        isStreamActive = active
        updateRenderPolicy()
    }
}

@Observable
final class StreamRenderState {
    var policy: RenderPolicy = .idle
    var transform = RenderTransform()
    var headroom = DisplayHeadroom()
}

enum RenderPolicy: Equatable {
    case idle
    case active
    case throttled(reason: String)
    case paused(reason: String)
}

enum LifecycleRenderPolicyResolver {
    static func resolve(
        isStreamActive: Bool,
        isVisible: Bool,
        isFocused: Bool,
        drawableSize: PixelSize
    ) -> RenderPolicy {
        guard isStreamActive else { return .idle }

        guard isVisible else {
            return .paused(reason: "Window or scene not visible")
        }

        guard drawableSize.width > 0, drawableSize.height > 0 else {
            return .paused(reason: "Drawable is not ready")
        }

        guard isFocused else {
            return .throttled(reason: "Window or scene not focused")
        }

        return .active
    }
}

struct PixelSize: Codable, Equatable, Hashable, Sendable {
    static let zero = PixelSize(width: 0, height: 0)

    var width: Int
    var height: Int
}

struct RenderTransform: Equatable {
    var sourceSize = PixelSize.zero
    var drawableSize = PixelSize.zero
    var mode: RenderScaleMode = .fit
}

enum RenderScaleMode: String, Codable, CaseIterable, Sendable {
    case fit
    case fill
}
