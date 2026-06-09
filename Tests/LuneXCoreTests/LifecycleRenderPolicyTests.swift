import XCTest

final class LifecycleRenderPolicyTests: XCTestCase {
    func testInactiveStreamUsesIdlePolicy() {
        let policy = LifecycleRenderPolicyResolver.resolve(
            isStreamActive: false,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 1920, height: 1080)
        )

        XCTAssertEqual(policy, .idle)
    }

    func testInvisibleActiveStreamPausesRendering() {
        let policy = LifecycleRenderPolicyResolver.resolve(
            isStreamActive: true,
            isVisible: false,
            isFocused: true,
            drawableSize: PixelSize(width: 1920, height: 1080)
        )

        XCTAssertEqual(policy, .paused(reason: "Window or scene not visible"))
    }

    func testActiveStreamWithoutDrawablePausesRendering() {
        let policy = LifecycleRenderPolicyResolver.resolve(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: .zero
        )

        XCTAssertEqual(policy, .paused(reason: "Drawable is not ready"))
    }

    func testUnfocusedVisibleStreamThrottlesRendering() {
        let policy = LifecycleRenderPolicyResolver.resolve(
            isStreamActive: true,
            isVisible: true,
            isFocused: false,
            drawableSize: PixelSize(width: 1920, height: 1080)
        )

        XCTAssertEqual(policy, .throttled(reason: "Window or scene not focused"))
    }

    func testFocusedVisibleStreamUsesActivePolicy() {
        let policy = LifecycleRenderPolicyResolver.resolve(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 1920, height: 1080)
        )

        XCTAssertEqual(policy, .active)
    }
}
