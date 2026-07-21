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

    func testInactiveDirectiveClosesEveryRuntimeSurfaceWithoutReleaseBarrier() {
        let directive = resolve(
            isStreamActive: false,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 1920, height: 1080)
        )

        XCTAssertEqual(directive.renderPolicy, .idle)
        XCTAssertEqual(directive.videoProcessing, .inactive)
        XCTAssertEqual(directive.presentation, .clear(reason: .streamInactive))
        XCTAssertEqual(
            directive.input,
            .closed(reason: .streamInactive, requiresReleaseBarrier: false)
        )
    }

    func testOccludedDirectiveDrainsTransportAndClearsPresentation() {
        let directive = resolve(
            isStreamActive: true,
            isVisible: false,
            isFocused: true,
            drawableSize: PixelSize(width: 1920, height: 1080)
        )

        XCTAssertEqual(
            directive.videoProcessing,
            .drainTransportWithoutDecoding(reason: .notVisible)
        )
        XCTAssertEqual(directive.presentation, .clear(reason: .notVisible))
        XCTAssertEqual(
            directive.input,
            .closed(reason: .notVisible, requiresReleaseBarrier: true)
        )
    }

    func testZeroDrawableDirectiveDrainsTransportAndClearsPresentation() {
        let directive = resolve(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: .zero
        )

        XCTAssertEqual(
            directive.videoProcessing,
            .drainTransportWithoutDecoding(reason: .drawableUnavailable)
        )
        XCTAssertEqual(directive.presentation, .clear(reason: .drawableUnavailable))
        XCTAssertEqual(
            directive.input,
            .closed(reason: .drawableUnavailable, requiresReleaseBarrier: true)
        )
    }

    func testUnfocusedDirectiveKeepsDecodeSubmissionAndThrottlesPresentation() {
        let directive = resolve(
            isStreamActive: true,
            isVisible: true,
            isFocused: false,
            drawableSize: PixelSize(width: 1920, height: 1080)
        )

        XCTAssertEqual(directive.videoProcessing, .submitDecodedVideo)
        XCTAssertEqual(directive.presentation, .throttled(reason: .notFocused))
        XCTAssertEqual(
            directive.input,
            .closed(reason: .notFocused, requiresReleaseBarrier: true)
        )
    }

    func testFocusedDirectiveOpensEveryActiveRuntimeSurface() {
        let directive = resolve(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 1920, height: 1080)
        )

        XCTAssertEqual(directive.renderPolicy, .active)
        XCTAssertEqual(directive.videoProcessing, .submitDecodedVideo)
        XCTAssertEqual(directive.presentation, .active)
        XCTAssertEqual(directive.input, .open)
    }

    func testLifecyclePrecedenceIsClosedAcrossBooleanStateMatrix() {
        for isStreamActive in [false, true] {
            for isVisible in [false, true] {
                for isFocused in [false, true] {
                    for drawableSize in [.zero, PixelSize(width: 1920, height: 1080)] {
                        let directive = resolve(
                            isStreamActive: isStreamActive,
                            isVisible: isVisible,
                            isFocused: isFocused,
                            drawableSize: drawableSize
                        )

                        if !isStreamActive {
                            XCTAssertEqual(directive.videoProcessing, .inactive)
                        } else if !isVisible {
                            XCTAssertEqual(
                                directive.videoProcessing,
                                .drainTransportWithoutDecoding(reason: .notVisible)
                            )
                        } else if drawableSize == .zero {
                            XCTAssertEqual(
                                directive.videoProcessing,
                                .drainTransportWithoutDecoding(reason: .drawableUnavailable)
                            )
                        } else if !isFocused {
                            XCTAssertEqual(directive.presentation, .throttled(reason: .notFocused))
                        } else {
                            XCTAssertEqual(directive.input, .open)
                        }
                    }
                }
            }
        }
    }

    private func resolve(
        isStreamActive: Bool,
        isVisible: Bool,
        isFocused: Bool,
        drawableSize: PixelSize
    ) -> SessionLifecycleDirective {
        SessionLifecycleDirectiveResolver.resolve(
            isStreamActive: isStreamActive,
            isVisible: isVisible,
            isFocused: isFocused,
            drawableSize: drawableSize
        )
    }
}
