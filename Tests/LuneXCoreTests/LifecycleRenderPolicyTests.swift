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

    func testDisplayRevisionChangesOnlyForSemanticDisplayState() throws {
        let lifecycle = PlatformLifecycleState()
        let firstHeadroom = DisplayHeadroom(
            potential: 2.0,
            current: 1.5,
            reference: 1.0
        )

        XCTAssertEqual(
            lifecycle.updateSurface(
                displayID: "display-a",
                headroom: firstHeadroom,
                drawableSize: PixelSize(width: 1920, height: 1080)
            ),
            .published(HDRDisplaySnapshot(
                revision: HDRDisplayRevision(rawValue: 1),
                displayID: "display-a",
                headroom: firstHeadroom
            ))
        )
        let first = try XCTUnwrap(lifecycle.displaySnapshot)
        XCTAssertEqual(first.revision, HDRDisplayRevision(rawValue: 1))

        XCTAssertEqual(
            lifecycle.updateSurface(
                displayID: "display-a",
                headroom: firstHeadroom,
                drawableSize: PixelSize(width: 2560, height: 1440)
            ),
            .unchanged
        )
        lifecycle.setStreamActive(true)
        lifecycle.isVisible = false
        lifecycle.updateRenderPolicy()
        lifecycle.isFocused = false
        lifecycle.updateRenderPolicy()
        XCTAssertEqual(lifecycle.displayRevision, first.revision)

        let reducedHeadroom = DisplayHeadroom(
            potential: 2.0,
            current: 1.25,
            reference: 1.0
        )
        XCTAssertEqual(
            lifecycle.updateSurface(
                displayID: "display-a",
                headroom: reducedHeadroom,
                drawableSize: PixelSize(width: 2560, height: 1440)
            ),
            .published(HDRDisplaySnapshot(
                revision: HDRDisplayRevision(rawValue: 2),
                displayID: "display-a",
                headroom: reducedHeadroom
            ))
        )
        XCTAssertEqual(
            lifecycle.updateSurface(
                displayID: "display-b",
                headroom: reducedHeadroom,
                drawableSize: PixelSize(width: 2560, height: 1440)
            ),
            .published(HDRDisplaySnapshot(
                revision: HDRDisplayRevision(rawValue: 3),
                displayID: "display-b",
                headroom: reducedHeadroom
            ))
        )
    }

    func testDisplayDetachPublishesOneRevisionAndRejectsStaleOwner() throws {
        let lifecycle = PlatformLifecycleState()
        let currentOwner = UUID()
        let staleOwner = UUID()
        lifecycle.claimSurfaceAttachment(currentOwner)
        lifecycle.updateSurface(
            displayID: "display-a",
            headroom: DisplayHeadroom(potential: 2.0, current: 1.5, reference: 1.0),
            drawableSize: PixelSize(width: 1920, height: 1080)
        )

        XCTAssertFalse(lifecycle.clearSurfaceAttachment(staleOwner))
        XCTAssertEqual(lifecycle.displayRevision, HDRDisplayRevision(rawValue: 1))
        XCTAssertNotNil(lifecycle.displaySnapshot)

        XCTAssertTrue(lifecycle.clearSurfaceAttachment(currentOwner))
        XCTAssertEqual(lifecycle.displayRevision, HDRDisplayRevision(rawValue: 2))
        XCTAssertNil(lifecycle.displaySnapshot)
        XCTAssertNil(lifecycle.displayID)
        XCTAssertEqual(lifecycle.headroom, DisplayHeadroom())

        XCTAssertFalse(lifecycle.clearSurfaceAttachment(currentOwner))
        XCTAssertEqual(lifecycle.displayRevision, HDRDisplayRevision(rawValue: 2))
    }

    func testSemanticNaNHeadroomDoesNotChurnDisplayRevision() {
        var publisher = HDRDisplaySnapshotPublisher()
        let invalid = DisplayHeadroom(
            potential: .nan,
            current: .nan,
            reference: .nan
        )

        XCTAssertNotEqual(invalid, DisplayHeadroom())
        XCTAssertEqual(
            publisher.update(
                isSurfaceAttached: true,
                displayID: "display-a",
                headroom: invalid
            ),
            .published(HDRDisplaySnapshot(
                revision: HDRDisplayRevision(rawValue: 1),
                displayID: "display-a",
                headroom: invalid
            ))
        )
        XCTAssertEqual(
            publisher.update(
                isSurfaceAttached: true,
                displayID: "display-a",
                headroom: invalid
            ),
            .unchanged
        )
        XCTAssertEqual(publisher.revision, HDRDisplayRevision(rawValue: 1))
    }

    func testDisplayRevisionExhaustionFailsClosed() {
        var publisher = HDRDisplaySnapshotPublisher(
            initialRevision: HDRDisplayRevision(rawValue: .max)
        )

        XCTAssertEqual(
            publisher.update(
                isSurfaceAttached: true,
                displayID: "display-a",
                headroom: DisplayHeadroom()
            ),
            .revisionExhausted
        )
        XCTAssertTrue(publisher.isRevisionExhausted)
        XCTAssertNil(publisher.snapshot)
        XCTAssertEqual(publisher.revision, HDRDisplayRevision(rawValue: .max))
        XCTAssertEqual(
            publisher.update(
                isSurfaceAttached: true,
                displayID: "display-a",
                headroom: DisplayHeadroom()
            ),
            .revisionExhausted
        )
    }

    func testRenderStateRevisionAdvancesOnlyForSemanticSurfaceChanges() {
        let state = StreamRenderState(transform: RenderTransform(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 1280, height: 720),
            mode: .fit
        ))

        XCTAssertEqual(state.revision, 0)

        state.policy = .idle
        state.headroom = DisplayHeadroom()
        state.displaySnapshot = nil
        state.isDisplayRevisionExhausted = false
        state.negotiatedVideoColorMetadata = nil
        state.decodedVideoPresentationContract = nil
        state.hdrRenderResolution = .closed(.inactiveSession)
        XCTAssertEqual(state.revision, 0)

        let changes: [() -> Void] = [
            { state.policy = .active },
            {
                state.headroom = DisplayHeadroom(
                    potential: 2,
                    current: 1.5,
                    reference: 1
                )
            },
            {
                state.displaySnapshot = HDRDisplaySnapshot(
                    revision: HDRDisplayRevision(rawValue: 1),
                    displayID: "display-a",
                    headroom: state.headroom
                )
            },
            { state.isDisplayRevisionExhausted = true },
            { state.negotiatedVideoColorMetadata = .rec709VideoRange() },
            { state.hdrRenderResolution = .closed(.invalidSourceContract) },
            { state.transform.mode = .fill }
        ]

        for change in changes {
            let previousRevision = state.revision
            change()
            XCTAssertGreaterThan(state.revision, previousRevision)

            let unchangedRevision = state.revision
            state.policy = state.policy
            state.headroom = state.headroom
            state.displaySnapshot = state.displaySnapshot
            state.isDisplayRevisionExhausted = state.isDisplayRevisionExhausted
            state.negotiatedVideoColorMetadata = state.negotiatedVideoColorMetadata
            state.decodedVideoPresentationContract = state.decodedVideoPresentationContract
            state.hdrRenderResolution = state.hdrRenderResolution
            state.transform = state.transform
            XCTAssertEqual(state.revision, unchangedRevision)
        }
    }

    func testRenderStateRevisionTracksPlatformCoordinateSnapshotReplacement() throws {
        let state = StreamRenderState(transform: RenderTransform(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 1280, height: 720),
            mode: .fit
        ))
        let initialSnapshot = try XCTUnwrap(state.coordinateSnapshot)

        state.applyPlatformCoordinateSnapshot(initialSnapshot)
        XCTAssertEqual(state.revision, 0)

        let replacement = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: initialSnapshot.revision + 1,
            sourceSize: initialSnapshot.sourceSize,
            drawableSize: PixelSize(width: 1600, height: 900),
            mode: initialSnapshot.mode
        ))
        state.applyPlatformCoordinateSnapshot(replacement)
        let replacementRevision = state.revision

        XCTAssertGreaterThan(replacementRevision, 0)
        XCTAssertEqual(state.coordinateSnapshot, replacement)

        state.applyPlatformCoordinateSnapshot(replacement)
        XCTAssertEqual(state.revision, replacementRevision)
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
