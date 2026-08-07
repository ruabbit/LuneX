import CoreVideo
import Foundation
@preconcurrency import Metal
import MetalKit
import XCTest

final class StreamMetalPresenterTests: XCTestCase {
    @MainActor
    func testTVVisionSurfaceRelayPublishesOrderedStateAndReplacesHandler() {
        let scene = TVVisionSurfaceRelayTestScene()
        let surface = TVVisionSurfaceRelayTestSurface(
            isAttached: true,
            scene: scene,
            isVisible: true,
            scale: 2,
            drawableSize: CGSize(width: 1920, height: 1080),
            isFocusEligible: true
        )
        var firstCallbacks: [TVVisionUIKitStreamSurfaceCallback] = []
        var replacementCallbacks: [TVVisionUIKitStreamSurfaceCallback] = []
        var stateReadCount = 0
        let relay = TVVisionUIKitStreamSurfaceRelay(
            surface: surface,
            stateReader: { candidate in
                stateReadCount += 1
                return tvVisionSurfaceRelayTestState(candidate)
            },
            handler: { candidate, callback, state in
                XCTAssertTrue(candidate === surface)
                XCTAssertTrue(state.windowScene === scene)
                XCTAssertTrue(state.isAttached)
                XCTAssertTrue(state.isVisible)
                XCTAssertEqual(state.scale, 2)
                XCTAssertEqual(
                    state.drawableSize,
                    CGSize(width: 1920, height: 1080)
                )
                XCTAssertTrue(state.isFocusEligible)
                firstCallbacks.append(callback)
            }
        )

        relay.publish([
            .attachment,
            .windowScene,
            .visibility,
            .scale,
            .drawable,
            .focusEligibility
        ])
        relay.updateHandler { candidate, callback, state in
            XCTAssertTrue(candidate === surface)
            XCTAssertNil(state.windowScene)
            XCTAssertFalse(state.isAttached)
            XCTAssertFalse(state.isVisible)
            XCTAssertEqual(state.scale, 1)
            XCTAssertEqual(state.drawableSize, .zero)
            XCTAssertFalse(state.isFocusEligible)
            replacementCallbacks.append(callback)
        }
        surface.isAttached = false
        surface.scene = nil
        surface.isVisible = false
        surface.scale = 1
        surface.drawableSize = .zero
        surface.isFocusEligible = false
        relay.publish([.attachment, .windowScene, .visibility])

        XCTAssertEqual(stateReadCount, 2)
        XCTAssertEqual(
            firstCallbacks,
            [
                .attachment,
                .windowScene,
                .visibility,
                .scale,
                .drawable,
                .focusEligibility
            ]
        )
        XCTAssertEqual(
            replacementCallbacks,
            [.attachment, .windowScene, .visibility]
        )
    }

    @MainActor
    func testTVVisionSurfaceRelayRejectsLateCallbacksAndRetainsNoSurface() {
        var surface: TVVisionSurfaceRelayTestSurface? =
            TVVisionSurfaceRelayTestSurface()
        weak let weakSurface = surface
        var callbacks: [TVVisionUIKitStreamSurfaceCallback] = []
        let relay = TVVisionUIKitStreamSurfaceRelay(
            surface: surface!,
            stateReader: tvVisionSurfaceRelayTestState,
            handler: { _, callback, _ in callbacks.append(callback) }
        )

        relay.publish([])
        surface = nil
        relay.publish(TVVisionUIKitStreamSurfaceCallback.allCases)
        XCTAssertNil(weakSurface)
        relay.invalidate()
        relay.invalidate()
        relay.updateHandler { _, callback, _ in callbacks.append(callback) }
        relay.publish(TVVisionUIKitStreamSurfaceCallback.allCases)

        XCTAssertTrue(callbacks.isEmpty)
        XCTAssertEqual(
            TVVisionUIKitStreamSurfaceCallback.allCases,
            [
                .attachment,
                .layout,
                .windowScene,
                .visibility,
                .scale,
                .drawable,
                .focusEligibility
            ]
        )
    }

    @MainActor
    func testTVVisionSurfaceGenerationOwnerDerivesActualAttachmentState()
        throws
    {
        let generation = try tvVisionSurfaceGeneration(201)
        let scene = TVVisionSurfaceGenerationTestScene(activity: .active)
        let screen = TVVisionSurfaceGenerationTestScreen()
        let window = TVVisionSurfaceGenerationTestWindow(
            scene: scene,
            screen: screen
        )
        let surface = TVVisionSurfaceGenerationTestSurface(window: window)
        var statuses: [TVVisionUIKitStreamSurfaceGenerationStatus] = []
        var states: [TVVisionUIKitStreamSurfaceGenerationState] = []
        let owner = try TVVisionSurfaceGenerationTestOwner(
            platform: .tvOS,
            surfaceGeneration: generation,
            surface: surface,
            resolver: tvVisionSurfaceGenerationTestResolver,
            handler: { update in
                statuses.append(update.status)
                if let state = update.state { states.append(state) }
            }
        )

        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                callback: .attachment,
                rawState: tvVisionSurfaceGenerationTestRawState(surface)
            ),
            .attached
        )
        XCTAssertTrue(owner.currentSurface === surface)
        XCTAssertTrue(owner.currentWindow === window)
        XCTAssertTrue(owner.currentWindowScene === scene)
        XCTAssertTrue(owner.currentScreen === screen)
        XCTAssertEqual(statuses, [.attached])
        XCTAssertEqual(states.last?.platform, .tvOS)
        XCTAssertEqual(states.last?.surfaceGeneration, generation)
        XCTAssertEqual(states.last?.callback, .attachment)
        XCTAssertEqual(states.last?.activity, .active)
        XCTAssertEqual(states.last?.attachment, .attached)
        XCTAssertEqual(states.last?.scale, 2)
        XCTAssertEqual(
            states.last?.drawableSize,
            PixelSize(width: 1920, height: 1080)
        )
        XCTAssertEqual(states.last?.isFocusEligible, true)

        scene.activity = .inactive
        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                callback: .windowScene,
                rawState: tvVisionSurfaceGenerationTestRawState(surface)
            ),
            .attached
        )
        XCTAssertEqual(states.last?.activity, .inactive)
        XCTAssertEqual(states.last?.isFocusEligible, false)
    }

    @MainActor
    func testTVVisionSurfaceGenerationOwnerFailsClosedAndRecovers() throws {
        let generation = try tvVisionSurfaceGeneration(211)
        let scene = TVVisionSurfaceGenerationTestScene(activity: .active)
        let screen = TVVisionSurfaceGenerationTestScreen()
        let window = TVVisionSurfaceGenerationTestWindow(
            scene: scene,
            screen: screen
        )
        let surface = TVVisionSurfaceGenerationTestSurface(window: window)
        var statuses: [TVVisionUIKitStreamSurfaceGenerationStatus] = []
        let owner = try TVVisionSurfaceGenerationTestOwner(
            platform: .tvOS,
            surfaceGeneration: generation,
            surface: surface,
            resolver: tvVisionSurfaceGenerationTestResolver,
            handler: { statuses.append($0.status) }
        )

        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                callback: .attachment,
                rawState: tvVisionSurfaceGenerationTestRawState(surface)
            ),
            .attached
        )
        surface.window = nil
        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                callback: .attachment,
                rawState: tvVisionSurfaceGenerationTestRawState(surface)
            ),
            .detached
        )
        XCTAssertNil(owner.currentWindow)
        XCTAssertEqual(owner.currentState?.attachment, .detached)

        surface.window = window
        surface.drawableSize = CGSize(width: CGFloat.infinity, height: 1080)
        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                callback: .drawable,
                rawState: tvVisionSurfaceGenerationTestRawState(surface)
            ),
            .invalid(.invalidDrawableSize)
        )
        XCTAssertNil(owner.currentWindow)
        XCTAssertNil(owner.currentState)

        surface.drawableSize = CGSize(width: 1920, height: 1080)
        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                callback: .layout,
                rawState: tvVisionSurfaceGenerationTestRawState(surface)
            ),
            .attached
        )
        XCTAssertTrue(owner.currentWindow === window)
        XCTAssertEqual(
            statuses,
            [
                .attached,
                .detached,
                .invalid(.invalidDrawableSize),
                .attached
            ]
        )
    }

    @MainActor
    func testTVVisionSurfaceGenerationOwnerRejectsStaleAndLateCallbacks()
        throws
    {
        let generation = try tvVisionSurfaceGeneration(221)
        let staleGeneration = try tvVisionSurfaceGeneration(222)
        let surface = TVVisionSurfaceGenerationTestSurface(
            window: TVVisionSurfaceGenerationTestWindow(
                scene: TVVisionSurfaceGenerationTestScene(activity: .active),
                screen: nil
            )
        )
        let otherSurface = TVVisionSurfaceGenerationTestSurface()
        var statuses: [TVVisionUIKitStreamSurfaceGenerationStatus] = []
        let owner = try TVVisionSurfaceGenerationTestOwner(
            platform: .visionOS,
            surfaceGeneration: generation,
            surface: surface,
            resolver: tvVisionSurfaceGenerationTestResolver,
            handler: { statuses.append($0.status) }
        )

        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                callback: .attachment,
                rawState: tvVisionSurfaceGenerationTestRawState(surface)
            ),
            .attached
        )
        XCTAssertNil(owner.currentScreen)
        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: staleGeneration,
                callback: .layout,
                rawState: tvVisionSurfaceGenerationTestRawState(surface)
            ),
            .staleSurfaceGeneration
        )
        XCTAssertEqual(
            owner.handle(
                surface: otherSurface,
                surfaceGeneration: generation,
                callback: .layout,
                rawState: tvVisionSurfaceGenerationTestRawState(otherSurface)
            ),
            .staleSurface
        )
        XCTAssertEqual(
            owner.invalidate(
                surface: otherSurface,
                surfaceGeneration: generation
            ),
            .staleSurface
        )
        XCTAssertEqual(
            owner.invalidate(
                surface: surface,
                surfaceGeneration: generation
            ),
            .invalidated
        )
        owner.updateHandler { _ in
            XCTFail("An invalidated owner must reject handler replacement")
        }
        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                callback: .visibility,
                rawState: tvVisionSurfaceGenerationTestRawState(surface)
            ),
            .alreadyInvalidated
        )
        XCTAssertEqual(
            owner.invalidate(
                surface: surface,
                surfaceGeneration: generation
            ),
            .alreadyInvalidated
        )
        XCTAssertEqual(statuses, [.attached, .invalidated])
    }

    @MainActor
    func testTVVisionSurfaceGenerationOwnerRetainsNoPlatformObjects() throws {
        let generation = try tvVisionSurfaceGeneration(231)
        var scene: TVVisionSurfaceGenerationTestScene? =
            TVVisionSurfaceGenerationTestScene(activity: .active)
        var screen: TVVisionSurfaceGenerationTestScreen? =
            TVVisionSurfaceGenerationTestScreen()
        var window: TVVisionSurfaceGenerationTestWindow? =
            TVVisionSurfaceGenerationTestWindow(
                scene: scene!,
                screen: screen
            )
        var surface: TVVisionSurfaceGenerationTestSurface? =
            TVVisionSurfaceGenerationTestSurface(window: window)
        weak let weakScene = scene
        weak let weakScreen = screen
        weak let weakWindow = window
        weak let weakSurface = surface
        let owner = try TVVisionSurfaceGenerationTestOwner(
            platform: .tvOS,
            surfaceGeneration: generation,
            surface: surface!,
            resolver: tvVisionSurfaceGenerationTestResolver,
            handler: { _ in }
        )

        XCTAssertEqual(
            owner.handle(
                surface: surface!,
                surfaceGeneration: generation,
                callback: .attachment,
                rawState: tvVisionSurfaceGenerationTestRawState(surface!)
            ),
            .attached
        )
        surface?.window = nil
        surface = nil
        window = nil
        scene = nil
        screen = nil

        XCTAssertNil(weakSurface)
        XCTAssertNil(weakWindow)
        XCTAssertNil(weakScene)
        XCTAssertNil(weakScreen)
        XCTAssertNil(owner.currentSurface)
        XCTAssertNil(owner.currentWindow)
        XCTAssertNil(owner.currentWindowScene)
        XCTAssertNil(owner.currentScreen)
    }

    @MainActor
    func testTVVisionSurfaceGenerationOwnerRequiresSurfaceDomain() throws {
        let surface = TVVisionSurfaceGenerationTestSurface()

        XCTAssertThrowsError(try TVVisionSurfaceGenerationTestOwner(
            platform: .tvOS,
            surfaceGeneration: TVVisionGeneration(
                domain: .presentation,
                rawValue: 1
            ),
            surface: surface,
            resolver: tvVisionSurfaceGenerationTestResolver,
            handler: { _ in }
        )) { error in
            XCTAssertEqual(
                error as? TVVisionPlatformContractError,
                .generationDomainMismatch(
                    expected: .surface,
                    actual: .presentation
                )
            )
        }
    }

    @MainActor
    func testTVVisionSurfaceGenerationOwnerRejectsEveryInvalidStateClass()
        throws
    {
        let generation = try tvVisionSurfaceGeneration(241)
        let scene = TVVisionSurfaceGenerationTestScene(activity: .active)
        let screen = TVVisionSurfaceGenerationTestScreen()
        let window = TVVisionSurfaceGenerationTestWindow(
            scene: scene,
            screen: screen
        )
        let surface = TVVisionSurfaceGenerationTestSurface(window: window)
        let owner = try TVVisionSurfaceGenerationTestOwner(
            platform: .tvOS,
            surfaceGeneration: generation,
            surface: surface,
            resolver: tvVisionSurfaceGenerationTestResolver,
            handler: { _ in }
        )
        let otherScene = TVVisionSurfaceGenerationTestScene(activity: .active)

        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                callback: .attachment,
                rawState: TVVisionSurfaceGenerationTestOwner.RawState(
                    isAttached: false,
                    windowScene: scene,
                    isVisible: false,
                    scale: 2,
                    drawableSize: CGSize(width: 1920, height: 1080),
                    isFocusEligible: false
                )
            ),
            .invalid(.inconsistentAttachment)
        )
        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                callback: .windowScene,
                rawState: TVVisionSurfaceGenerationTestOwner.RawState(
                    isAttached: true,
                    windowScene: otherScene,
                    isVisible: true,
                    scale: 2,
                    drawableSize: CGSize(width: 1920, height: 1080),
                    isFocusEligible: true
                )
            ),
            .invalid(.windowSceneMismatch)
        )

        surface.window = TVVisionSurfaceGenerationTestWindow(
            scene: scene,
            screen: nil
        )
        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                callback: .windowScene,
                rawState: tvVisionSurfaceGenerationTestRawState(surface)
            ),
            .invalid(.tvOSScreenUnavailable)
        )

        surface.window = window
        surface.scale = .nan
        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                callback: .scale,
                rawState: tvVisionSurfaceGenerationTestRawState(surface)
            ),
            .invalid(.invalidScale)
        )
        surface.scale = 2
        surface.drawableSize = .zero
        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                callback: .drawable,
                rawState: tvVisionSurfaceGenerationTestRawState(surface)
            ),
            .invalid(.invalidDrawableSize)
        )

        surface.drawableSize = CGSize(width: 1920, height: 1080)
        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                callback: .focusEligibility,
                rawState: TVVisionSurfaceGenerationTestOwner.RawState(
                    isAttached: true,
                    windowScene: scene,
                    isVisible: false,
                    scale: 2,
                    drawableSize: CGSize(width: 1920, height: 1080),
                    isFocusEligible: true
                )
            ),
            .invalid(.focusEligibleWhileInvisible)
        )
        XCTAssertNil(owner.currentState)
        XCTAssertNil(owner.currentWindow)
    }

    @MainActor
    func testTVVisionGeometryBindingNormalizesDrawableRenderAndInputRevision()
        throws
    {
        let generation = try tvVisionSurfaceGeneration(251)
        let surface = tvVisionGeometryBindingTestSurface(
            geometry: TVVisionUIKitStreamSurfaceGeometryReading(
                viewBounds: TVVisionRect(
                    x: 10,
                    y: 20,
                    width: 400,
                    height: 300
                ),
                windowBounds: TVVisionRect(
                    x: 0,
                    y: 0,
                    width: 800,
                    height: 600
                ),
                safeAreaInsets: .zero,
                scale: 2
            )
        )
        var updates: [TVVisionStreamGeometryBindingUpdate] = []
        let owner = try tvVisionGeometryBindingTestOwner(
            platform: .tvOS,
            generation: generation,
            surface: surface,
            handler: { updates.append($0) }
        )

        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestAttachedUpdate(
                platform: .tvOS,
                generation: generation,
                surface: surface
            )),
            .published
        )

        let update = try XCTUnwrap(updates.last)
        let binding = try XCTUnwrap(update.binding)
        XCTAssertEqual(update.status, .active)
        XCTAssertEqual(update.revision.rawValue, 1)
        XCTAssertEqual(binding.revision, update.revision)
        XCTAssertEqual(
            binding.sceneSurfaceSnapshot.revision,
            update.revision
        )
        XCTAssertEqual(
            binding.coordinateSnapshot.revision,
            update.revision.rawValue
        )
        XCTAssertEqual(
            binding.coordinateSnapshot.drawableSize,
            PixelSize(width: 800, height: 600)
        )
        XCTAssertEqual(
            binding.coordinateSnapshot.resolvedVideo.videoRect,
            StreamCoordinateRect(x: 0, y: 75, width: 800, height: 450)
        )
        XCTAssertEqual(
            surface.appliedDrawableSizes,
            [PixelSize(width: 800, height: 600)]
        )

        let input = try XCTUnwrap(owner.absoluteInputMapping(
            localPoint: RemotePoint(x: 210, y: 170)
        ))
        XCTAssertEqual(input.revision, update.revision)
        XCTAssertEqual(input.point, RemotePoint(x: 960, y: 540))
        XCTAssertEqual(
            input.referenceSize,
            PixelSize(width: 1_920, height: 1_080)
        )
    }

    @MainActor
    func testTVVisionGeometryBindingDeduplicatesCallbacksAndRevisesFitFill()
        throws
    {
        let generation = try tvVisionSurfaceGeneration(261)
        let surface = tvVisionGeometryBindingTestSurface()
        var updates: [TVVisionStreamGeometryBindingUpdate] = []
        let owner = try tvVisionGeometryBindingTestOwner(
            platform: .visionOS,
            generation: generation,
            surface: surface,
            handler: { updates.append($0) }
        )
        let attached = tvVisionGeometryBindingTestAttachedUpdate(
            platform: .visionOS,
            generation: generation,
            surface: surface
        )

        XCTAssertEqual(owner.handle(attached), .published)
        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestAttachedUpdate(
                platform: .visionOS,
                generation: generation,
                surface: surface,
                callback: .layout
            )),
            .unchanged
        )
        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestAttachedUpdate(
                platform: .visionOS,
                generation: generation,
                surface: surface,
                callback: .visibility
            )),
            .unchanged
        )
        XCTAssertEqual(
            owner.updateRenderInputs(
                sourceSize: PixelSize(width: 1_920, height: 1_080),
                mode: .fit,
                surface: surface,
                surfaceGeneration: generation
            ),
            .unchanged
        )
        XCTAssertEqual(updates.count, 1)
        XCTAssertTrue(owner.replayCurrentUpdate(
            surface: surface,
            surfaceGeneration: generation
        ))
        XCTAssertEqual(updates.count, 2)
        XCTAssertEqual(updates[0], updates[1])
        XCTAssertEqual(updates[1].revision.rawValue, 1)
        XCTAssertFalse(owner.replayCurrentUpdate(
            surface: surface,
            surfaceGeneration: try tvVisionSurfaceGeneration(260)
        ))

        XCTAssertEqual(
            owner.updateRenderInputs(
                sourceSize: PixelSize(width: 1_920, height: 1_080),
                mode: .fill,
                surface: surface,
                surfaceGeneration: generation
            ),
            .published
        )
        XCTAssertEqual(
            owner.updateRenderInputs(
                sourceSize: PixelSize(width: 1_920, height: 1_080),
                mode: .fill,
                surface: surface,
                surfaceGeneration: generation
            ),
            .unchanged
        )
        XCTAssertEqual(updates.count, 3)
        let binding = try XCTUnwrap(updates.last?.binding)
        XCTAssertEqual(binding.revision.rawValue, 2)
        XCTAssertEqual(binding.coordinateSnapshot.mode, .fill)
        XCTAssertEqual(
            binding.sceneSurfaceSnapshot.revision,
            binding.revision
        )
        XCTAssertEqual(
            owner.absoluteInputMapping(
                localPoint: RemotePoint(x: 200, y: 150)
            )?.revision,
            binding.revision
        )
        XCTAssertEqual(
            surface.appliedDrawableSizes,
            [PixelSize(width: 800, height: 600)]
        )
    }

    @MainActor
    func testTVVisionGeometryBindingResizesClosesAndRecovers() throws {
        let generation = try tvVisionSurfaceGeneration(271)
        let surface = tvVisionGeometryBindingTestSurface()
        var updates: [TVVisionStreamGeometryBindingUpdate] = []
        let owner = try tvVisionGeometryBindingTestOwner(
            platform: .visionOS,
            generation: generation,
            surface: surface,
            handler: { updates.append($0) }
        )

        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestAttachedUpdate(
                platform: .visionOS,
                generation: generation,
                surface: surface
            )),
            .published
        )
        surface.geometryReading = TVVisionUIKitStreamSurfaceGeometryReading(
            viewBounds: TVVisionRect(
                x: 0,
                y: 0,
                width: 600,
                height: 400
            ),
            windowBounds: TVVisionRect(
                x: 0,
                y: 0,
                width: 600,
                height: 400
            ),
            safeAreaInsets: .zero,
            scale: 2
        )
        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestAttachedUpdate(
                platform: .visionOS,
                generation: generation,
                surface: surface,
                callback: .layout
            )),
            .published
        )
        XCTAssertEqual(
            owner.currentBinding?.coordinateSnapshot.drawableSize,
            PixelSize(width: 1_200, height: 800)
        )

        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestDetachedUpdate(
                platform: .visionOS,
                generation: generation,
                surface: surface
            )),
            .closed(.detached)
        )
        XCTAssertNil(owner.currentBinding)
        XCTAssertNil(owner.absoluteInputMapping(
            localPoint: RemotePoint(x: 300, y: 200)
        ))
        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestDetachedUpdate(
                platform: .visionOS,
                generation: generation,
                surface: surface,
                callback: .visibility
            )),
            .unchanged
        )

        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestAttachedUpdate(
                platform: .visionOS,
                generation: generation,
                surface: surface,
                callback: .attachment
            )),
            .published
        )
        XCTAssertEqual(owner.currentRevision?.rawValue, 4)

        XCTAssertEqual(
            owner.updateRenderInputs(
                sourceSize: .zero,
                mode: .fit,
                surface: surface,
                surfaceGeneration: generation
            ),
            .closed(.coordinateUnavailable)
        )
        XCTAssertNil(owner.currentBinding)
        XCTAssertEqual(surface.appliedDrawableSizes.last, .zero)

        surface.geometryReading = TVVisionUIKitStreamSurfaceGeometryReading(
            viewBounds: TVVisionRect(
                x: 0,
                y: 0,
                width: .nan,
                height: 400
            ),
            windowBounds: TVVisionRect(
                x: 0,
                y: 0,
                width: 600,
                height: 400
            ),
            safeAreaInsets: .zero,
            scale: 2
        )
        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestAttachedUpdate(
                platform: .visionOS,
                generation: generation,
                surface: surface,
                callback: .layout
            )),
            .closed(.invalidGeometry(.invalidViewBounds))
        )
        XCTAssertNil(owner.currentBinding)
        XCTAssertEqual(updates.last?.revision.rawValue, 6)
    }

    @MainActor
    func testTVVisionGeometryBindingRejectsStaleAndInvalidatesIdempotently()
        throws
    {
        let generation = try tvVisionSurfaceGeneration(281)
        let staleGeneration = try tvVisionSurfaceGeneration(282)
        let surface = tvVisionGeometryBindingTestSurface()
        let otherSurface = tvVisionGeometryBindingTestSurface()
        var updates: [TVVisionStreamGeometryBindingUpdate] = []
        let owner = try tvVisionGeometryBindingTestOwner(
            platform: .tvOS,
            generation: generation,
            surface: surface,
            handler: { updates.append($0) }
        )

        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestAttachedUpdate(
                platform: .tvOS,
                generation: generation,
                surface: surface
            )),
            .published
        )
        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestAttachedUpdate(
                platform: .tvOS,
                generation: staleGeneration,
                surface: surface
            )),
            .staleSurfaceGeneration
        )
        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestAttachedUpdate(
                platform: .tvOS,
                generation: generation,
                surface: otherSurface
            )),
            .staleSurface
        )
        XCTAssertEqual(updates.count, 1)
        XCTAssertEqual(
            owner.invalidate(
                surface: otherSurface,
                surfaceGeneration: generation
            ),
            .staleSurface
        )
        XCTAssertEqual(
            owner.invalidate(
                surface: surface,
                surfaceGeneration: generation
            ),
            .invalidated
        )
        XCTAssertNil(owner.currentSurface)
        XCTAssertNil(owner.currentBinding)
        XCTAssertEqual(updates.last?.status, .closed(.invalidated))
        owner.updateHandler { _ in
            XCTFail("An invalidated geometry owner must reject handlers")
        }
        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestAttachedUpdate(
                platform: .tvOS,
                generation: generation,
                surface: surface,
                callback: .layout
            )),
            .alreadyInvalidated
        )
        XCTAssertEqual(
            owner.invalidate(
                surface: surface,
                surfaceGeneration: generation
            ),
            .alreadyInvalidated
        )
        XCTAssertEqual(updates.count, 2)
    }

    @MainActor
    func testTVVisionGeometryBindingFailsClosedOnRevisionExhaustion()
        throws
    {
        let generation = try tvVisionSurfaceGeneration(291)
        let surface = tvVisionGeometryBindingTestSurface()
        var updates: [TVVisionStreamGeometryBindingUpdate] = []
        let owner = try tvVisionGeometryBindingTestOwner(
            platform: .tvOS,
            generation: generation,
            surface: surface,
            initialRevision: try TVVisionSemanticRevision(rawValue: .max),
            handler: { updates.append($0) }
        )

        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestAttachedUpdate(
                platform: .tvOS,
                generation: generation,
                surface: surface
            )),
            .revisionExhausted
        )
        XCTAssertTrue(owner.isRevisionExhausted)
        XCTAssertNil(owner.currentBinding)
        XCTAssertNil(owner.currentUpdate)
        XCTAssertNil(owner.absoluteInputMapping(
            localPoint: RemotePoint(x: 200, y: 150)
        ))
        XCTAssertTrue(updates.isEmpty)
        XCTAssertEqual(
            surface.appliedDrawableSizes,
            [PixelSize(width: 800, height: 600), .zero]
        )
        XCTAssertEqual(
            owner.updateRenderInputs(
                sourceSize: PixelSize(width: 1_280, height: 720),
                mode: .fill,
                surface: surface,
                surfaceGeneration: generation
            ),
            .revisionExhausted
        )
    }

    @MainActor
    func testTVVisionSurfaceCoordinatorConsumesExactGeometryRevision()
        throws
    {
        let generation = try tvVisionSurfaceGeneration(301)
        let staleGeneration = try tvVisionSurfaceGeneration(302)
        let surface = tvVisionGeometryBindingTestSurface()
        var updates: [TVVisionStreamGeometryBindingUpdate] = []
        let owner = try tvVisionGeometryBindingTestOwner(
            platform: .visionOS,
            generation: generation,
            surface: surface,
            handler: { updates.append($0) }
        )
        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestAttachedUpdate(
                platform: .visionOS,
                generation: generation,
                surface: surface
            )),
            .published
        )
        let activeUpdate = try XCTUnwrap(updates.last)
        let exactCoordinates = try XCTUnwrap(
            activeUpdate.binding?.coordinateSnapshot
        )
        let renderState = StreamRenderState(transform: RenderTransform(
            sourceSize: exactCoordinates.sourceSize,
            drawableSize: .zero,
            mode: exactCoordinates.mode
        ))
        let coordinator = MobileStreamSurfaceCoordinator(
            presentationSource: StreamVideoPresentationSource(),
            renderState: renderState
        )
        coordinator.activateTVVisionSurfaceGeneration(generation)

        XCTAssertEqual(
            coordinator.handleTVVisionGeometryUpdate(activeUpdate),
            .applied
        )
        XCTAssertEqual(renderState.coordinateSnapshot, exactCoordinates)
        XCTAssertEqual(
            renderState.coordinateSnapshot?.revision,
            activeUpdate.revision.rawValue
        )
        XCTAssertEqual(
            coordinator.handleTVVisionGeometryUpdate(
                TVVisionStreamGeometryBindingUpdate(
                    platform: .visionOS,
                    surfaceGeneration: staleGeneration,
                    revision: activeUpdate.revision,
                    status: activeUpdate.status,
                    binding: activeUpdate.binding
                )
            ),
            .staleSurfaceGeneration
        )
        XCTAssertEqual(renderState.coordinateSnapshot, exactCoordinates)

        XCTAssertEqual(
            owner.handle(tvVisionGeometryBindingTestDetachedUpdate(
                platform: .visionOS,
                generation: generation,
                surface: surface
            )),
            .closed(.detached)
        )
        let closedUpdate = try XCTUnwrap(updates.last)
        XCTAssertEqual(
            coordinator.handleTVVisionGeometryUpdate(closedUpdate),
            .applied
        )
        XCTAssertNil(renderState.coordinateSnapshot)
        XCTAssertEqual(renderState.transform.drawableSize, .zero)
    }

    @MainActor
    func testMobileSurfaceAttachmentRelayReplacesAndInvalidatesHandler() {
        let surface = MobileSurfaceAttachmentTestSurface()
        var firstEvents: [MobileStreamSurfaceAttachmentEvent] = []
        var replacementEvents: [MobileStreamSurfaceAttachmentEvent] = []
        let relay = MobileStreamSurfaceAttachmentRelay(
            surface: surface,
            handler: { candidate, event in
                XCTAssertTrue(candidate === surface)
                firstEvents.append(event)
            }
        )

        relay.publish(.didMoveToWindow)
        relay.updateHandler { candidate, event in
            XCTAssertTrue(candidate === surface)
            replacementEvents.append(event)
        }
        relay.publish(.layoutSubviews)
        relay.invalidate()
        relay.updateHandler { _, event in
            replacementEvents.append(event)
        }
        relay.publish(.safeAreaInsetsDidChange)

        XCTAssertEqual(firstEvents, [.didMoveToWindow])
        XCTAssertEqual(replacementEvents, [.layoutSubviews])
    }

    @MainActor
    func testMobileSurfaceAttachmentRelayDoesNotRetainSurface() {
        var surface: MobileSurfaceAttachmentTestSurface? =
            MobileSurfaceAttachmentTestSurface()
        weak let weakSurface = surface
        var events: [MobileStreamSurfaceAttachmentEvent] = []
        let relay = MobileStreamSurfaceAttachmentRelay(
            surface: surface!,
            handler: { _, event in events.append(event) }
        )

        surface = nil
        relay.publish(.didMoveToWindow)

        XCTAssertNil(weakSurface)
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(
            MobileStreamSurfaceAttachmentEvent.allCases,
            [
                .didMoveToWindow,
                .layoutSubviews,
                .safeAreaInsetsDidChange,
                .registeredTraitsChanged
            ]
        )
    }

    @MainActor
    func testMobileSurfaceAttachmentOwnerDerivesReplacementAndDetach() {
        let generation = MobileSceneSurfaceGeneration(rawValue: 41)!
        let surface = MobileSurfaceAttachmentTestSurface()
        let firstScene = MobileSurfaceAttachmentTestScene(name: "first-scene")
        let firstScreen = MobileSurfaceAttachmentTestScreen(name: "first-screen")
        let firstWindow = MobileSurfaceAttachmentTestWindow(
            name: "first-window",
            scene: firstScene,
            screen: firstScreen
        )
        let replacementScene = MobileSurfaceAttachmentTestScene(
            name: "replacement-scene"
        )
        let replacementScreen = MobileSurfaceAttachmentTestScreen(
            name: "replacement-screen"
        )
        let replacementWindow = MobileSurfaceAttachmentTestWindow(
            name: "replacement-window",
            scene: replacementScene,
            screen: replacementScreen
        )
        var transitions: [MobileStreamSurfaceAttachmentTransition] = []
        var windowNames: [String?] = []
        let owner = MobileSurfaceAttachmentTestOwner(
            surfaceGeneration: generation,
            surface: surface,
            resolver: mobileSurfaceAttachmentTestResolver,
            handler: { update in
                XCTAssertTrue(update.surface === surface)
                transitions.append(update.transition)
                windowNames.append(update.attachment?.window.name)
            }
        )

        surface.window = firstWindow
        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                event: .didMoveToWindow
            ),
            .attached
        )
        XCTAssertTrue(owner.currentWindow === firstWindow)
        XCTAssertTrue(owner.currentScene === firstScene)
        XCTAssertTrue(owner.currentScreen === firstScreen)

        surface.window = replacementWindow
        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                event: .layoutSubviews
            ),
            .attached
        )
        XCTAssertTrue(owner.currentWindow === replacementWindow)
        XCTAssertTrue(owner.currentScene === replacementScene)
        XCTAssertTrue(owner.currentScreen === replacementScreen)

        surface.window = nil
        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                event: .didMoveToWindow
            ),
            .detached
        )
        XCTAssertNil(owner.currentWindow)
        XCTAssertNil(owner.currentScene)
        XCTAssertNil(owner.currentScreen)
        XCTAssertEqual(
            transitions,
            [
                .callback(.didMoveToWindow),
                .callback(.layoutSubviews),
                .callback(.didMoveToWindow)
            ]
        )
        XCTAssertEqual(
            windowNames,
            ["first-window", "replacement-window", nil]
        )
    }

    @MainActor
    func testMobileSurfaceAttachmentOwnerRejectsStaleAndLateCallbacks() {
        let generation = MobileSceneSurfaceGeneration(rawValue: 51)!
        let staleGeneration = MobileSceneSurfaceGeneration(rawValue: 52)!
        let surface = MobileSurfaceAttachmentTestSurface()
        let otherSurface = MobileSurfaceAttachmentTestSurface()
        var transitions: [MobileStreamSurfaceAttachmentTransition] = []
        let owner = MobileSurfaceAttachmentTestOwner(
            surfaceGeneration: generation,
            surface: surface,
            resolver: mobileSurfaceAttachmentTestResolver,
            handler: { update in transitions.append(update.transition) }
        )

        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: staleGeneration,
                event: .layoutSubviews
            ),
            .staleSurfaceGeneration
        )
        XCTAssertEqual(
            owner.handle(
                surface: otherSurface,
                surfaceGeneration: generation,
                event: .layoutSubviews
            ),
            .staleSurface
        )
        XCTAssertEqual(
            owner.invalidate(
                surface: otherSurface,
                surfaceGeneration: generation
            ),
            .staleSurface
        )
        XCTAssertEqual(
            owner.invalidate(
                surface: surface,
                surfaceGeneration: generation
            ),
            .invalidated
        )
        owner.updateHandler { _ in
            XCTFail("An invalidated owner must not accept a replacement handler")
        }
        XCTAssertEqual(
            owner.handle(
                surface: surface,
                surfaceGeneration: generation,
                event: .safeAreaInsetsDidChange
            ),
            .alreadyInvalidated
        )
        XCTAssertEqual(
            owner.invalidate(
                surface: surface,
                surfaceGeneration: generation
            ),
            .alreadyInvalidated
        )
        XCTAssertEqual(transitions, [.invalidated])
        XCTAssertNil(owner.currentSurface)
    }

    @MainActor
    func testMobileSurfaceAttachmentOwnerRetainsNoPlatformObjects() {
        let generation = MobileSceneSurfaceGeneration(rawValue: 61)!
        var scene: MobileSurfaceAttachmentTestScene? =
            MobileSurfaceAttachmentTestScene(name: "scene")
        var screen: MobileSurfaceAttachmentTestScreen? =
            MobileSurfaceAttachmentTestScreen(name: "screen")
        var window: MobileSurfaceAttachmentTestWindow? =
            MobileSurfaceAttachmentTestWindow(
                name: "window",
                scene: scene!,
                screen: screen!
            )
        var surface: MobileSurfaceAttachmentTestSurface? =
            MobileSurfaceAttachmentTestSurface(window: window)
        weak let weakScene = scene
        weak let weakScreen = screen
        weak let weakWindow = window
        weak let weakSurface = surface
        let owner = MobileSurfaceAttachmentTestOwner(
            surfaceGeneration: generation,
            surface: surface!,
            resolver: mobileSurfaceAttachmentTestResolver,
            handler: { _ in }
        )

        XCTAssertEqual(
            owner.handle(
                surface: surface!,
                surfaceGeneration: generation,
                event: .didMoveToWindow
            ),
            .attached
        )
        surface?.window = nil
        surface = nil
        window = nil
        scene = nil
        screen = nil

        XCTAssertNil(weakSurface)
        XCTAssertNil(weakWindow)
        XCTAssertNil(weakScene)
        XCTAssertNil(weakScreen)
        XCTAssertNil(owner.currentSurface)
        XCTAssertNil(owner.currentWindow)
        XCTAssertNil(owner.currentScene)
        XCTAssertNil(owner.currentScreen)
    }

    @MainActor
    func testMobileSceneLifecycleObserverFiltersAndDeduplicatesSceneEvents() async {
        let generation = MobileSceneSurfaceGeneration(rawValue: 71)!
        let notificationCenter = NotificationCenter()
        let names = mobileSceneLifecycleTestNotificationNames()
        let scene = MobileSceneLifecycleTestScene(activity: .active)
        let otherScene = MobileSceneLifecycleTestScene(activity: .background)
        var observations: [MobileStreamSceneLifecycleObservation] = []
        let observer = MobileSceneLifecycleTestObserver(
            surfaceGeneration: generation,
            notificationCenter: notificationCenter,
            names: names,
            activityReader: { $0.activity },
            handler: { observations.append($0.observation) }
        )

        XCTAssertEqual(
            observer.attach(
                to: scene,
                surfaceGeneration: generation
            ),
            .published
        )
        notificationCenter.post(name: names.didActivate, object: scene)
        notificationCenter.post(name: names.willDeactivate, object: otherScene)
        await drainMobileSceneLifecycleNotificationTasks()
        XCTAssertEqual(observations, [.attached(.active)])

        notificationCenter.post(name: names.willDeactivate, object: scene)
        notificationCenter.post(name: names.willEnterForeground, object: scene)
        await drainMobileSceneLifecycleNotificationTasks()
        XCTAssertEqual(
            observations,
            [.attached(.active), .attached(.inactive)]
        )

        notificationCenter.post(name: names.didEnterBackground, object: scene)
        await drainMobileSceneLifecycleNotificationTasks()
        XCTAssertEqual(
            observations,
            [
                .attached(.active),
                .attached(.inactive),
                .attached(.background)
            ]
        )
    }

    @MainActor
    func testMobileSceneLifecycleObserverReplacesAndCancelsScene() async {
        let generation = MobileSceneSurfaceGeneration(rawValue: 81)!
        let notificationCenter = NotificationCenter()
        let names = mobileSceneLifecycleTestNotificationNames()
        let firstScene = MobileSceneLifecycleTestScene(activity: .active)
        let replacementScene = MobileSceneLifecycleTestScene(activity: .active)
        var observations: [MobileStreamSceneLifecycleObservation] = []
        let observer = MobileSceneLifecycleTestObserver(
            surfaceGeneration: generation,
            notificationCenter: notificationCenter,
            names: names,
            activityReader: { $0.activity },
            handler: { observations.append($0.observation) }
        )

        XCTAssertEqual(
            observer.attach(
                to: firstScene,
                surfaceGeneration: generation
            ),
            .published
        )
        XCTAssertEqual(
            observer.attach(
                to: replacementScene,
                surfaceGeneration: generation
            ),
            .published
        )
        notificationCenter.post(
            name: names.didEnterBackground,
            object: firstScene
        )
        await drainMobileSceneLifecycleNotificationTasks()
        XCTAssertEqual(
            observations,
            [.attached(.active), .attached(.active)]
        )

        notificationCenter.post(
            name: names.didEnterBackground,
            object: replacementScene
        )
        await drainMobileSceneLifecycleNotificationTasks()
        XCTAssertEqual(observations.last, .attached(.background))
        XCTAssertEqual(
            observer.detach(surfaceGeneration: generation),
            .published
        )
        notificationCenter.post(
            name: names.didActivate,
            object: replacementScene
        )
        await drainMobileSceneLifecycleNotificationTasks()
        XCTAssertEqual(observations.last, .detached)
        XCTAssertNil(observer.currentScene)
    }

    @MainActor
    func testMobileSceneLifecycleObserverRejectsStaleAndLateEvents() async {
        let generation = MobileSceneSurfaceGeneration(rawValue: 91)!
        let staleGeneration = MobileSceneSurfaceGeneration(rawValue: 92)!
        let notificationCenter = NotificationCenter()
        let names = mobileSceneLifecycleTestNotificationNames()
        let scene = MobileSceneLifecycleTestScene(activity: .inactive)
        var observations: [MobileStreamSceneLifecycleObservation] = []
        let observer = MobileSceneLifecycleTestObserver(
            surfaceGeneration: generation,
            notificationCenter: notificationCenter,
            names: names,
            activityReader: { $0.activity },
            handler: { observations.append($0.observation) }
        )

        XCTAssertEqual(
            observer.attach(
                to: scene,
                surfaceGeneration: staleGeneration
            ),
            .staleSurfaceGeneration
        )
        XCTAssertEqual(
            observer.attach(
                to: scene,
                surfaceGeneration: generation
            ),
            .published
        )
        notificationCenter.post(name: names.didActivate, object: scene)
        XCTAssertEqual(
            observer.invalidate(surfaceGeneration: staleGeneration),
            .staleSurfaceGeneration
        )
        XCTAssertEqual(
            observer.invalidate(surfaceGeneration: generation),
            .invalidated
        )
        observer.updateHandler { _ in
            XCTFail("An invalidated observer must reject handler replacement")
        }
        await drainMobileSceneLifecycleNotificationTasks()
        XCTAssertEqual(
            observations,
            [.attached(.inactive), .invalidated]
        )
        XCTAssertEqual(
            observer.attach(
                to: scene,
                surfaceGeneration: generation
            ),
            .alreadyInvalidated
        )
        XCTAssertEqual(
            observer.invalidate(surfaceGeneration: generation),
            .alreadyInvalidated
        )
    }

    @MainActor
    func testMobileSceneGeometryObserverPublishesContinuousResizeAndSettle()
        throws
    {
        let generation = MobileSceneSurfaceGeneration(rawValue: 101)!
        let surface = MobileSceneGeometryTestSurface()
        let window = MobileSceneGeometryTestWindow()
        let scene = MobileSceneGeometryTestScene()
        let screen = MobileSceneGeometryTestScreen()
        var snapshots: [MobileSceneWindowSnapshot] = []
        var settleRequests: [MobileStreamSceneGeometrySettleRequest] = []
        let observer = MobileSceneGeometryTestObserver(
            surfaceGeneration: generation,
            surface: surface,
            reader: mobileSceneGeometryTestReader,
            handler: { snapshots.append($0) },
            settleRequestHandler: { request in
                if let request {
                    settleRequests.append(request)
                }
            }
        )

        XCTAssertEqual(
            observer.updateActivity(
                .active,
                surfaceGeneration: generation
            ),
            .unchanged
        )
        XCTAssertEqual(
            observer.attach(
                surface: surface,
                window: window,
                scene: scene,
                screen: screen,
                surfaceGeneration: generation,
                event: .didMoveToWindow
            ),
            .published
        )
        XCTAssertEqual(
            snapshots.last?.state.geometry?.resizePhase,
            .settled
        )

        surface.reading = mobileSceneGeometryTestReading(width: 900)
        XCTAssertEqual(
            observer.attach(
                surface: surface,
                window: window,
                scene: scene,
                screen: screen,
                surfaceGeneration: generation,
                event: .layoutSubviews
            ),
            .published
        )
        surface.reading = mobileSceneGeometryTestReading(width: 880)
        XCTAssertEqual(
            observer.attach(
                surface: surface,
                window: window,
                scene: scene,
                screen: screen,
                surfaceGeneration: generation,
                event: .layoutSubviews
            ),
            .published
        )
        XCTAssertEqual(settleRequests.count, 2)
        XCTAssertEqual(
            snapshots.last?.state.geometry?.drawableSize,
            PixelSize(width: 1_760, height: 1_536)
        )
        XCTAssertEqual(
            snapshots.last?.state.geometry?.resizePhase,
            .resizing
        )
        XCTAssertEqual(observer.settle(settleRequests[0]), .staleSettleRequest)
        XCTAssertEqual(observer.settle(settleRequests[1]), .published)
        XCTAssertEqual(
            snapshots.last?.state.geometry?.resizePhase,
            .settled
        )
        XCTAssertEqual(snapshots.map(\.revision.rawValue), [1, 2, 3, 4])
    }

    @MainActor
    func testMobileSceneGeometryObserverDeduplicatesButRenewsSettleToken()
        throws
    {
        let generation = MobileSceneSurfaceGeneration(rawValue: 111)!
        let surface = MobileSceneGeometryTestSurface()
        let window = MobileSceneGeometryTestWindow()
        let scene = MobileSceneGeometryTestScene()
        let screen = MobileSceneGeometryTestScreen()
        var snapshots: [MobileSceneWindowSnapshot] = []
        var settleRequests: [MobileStreamSceneGeometrySettleRequest] = []
        let observer = MobileSceneGeometryTestObserver(
            surfaceGeneration: generation,
            surface: surface,
            reader: mobileSceneGeometryTestReader,
            handler: { snapshots.append($0) },
            settleRequestHandler: { request in
                if let request {
                    settleRequests.append(request)
                }
            }
        )

        _ = observer.updateActivity(.active, surfaceGeneration: generation)
        _ = observer.attach(
            surface: surface,
            window: window,
            scene: scene,
            screen: screen,
            surfaceGeneration: generation,
            event: .didMoveToWindow
        )
        XCTAssertEqual(
            observer.attach(
                surface: surface,
                window: window,
                scene: scene,
                screen: screen,
                surfaceGeneration: generation,
                event: .safeAreaInsetsDidChange
            ),
            .published
        )
        XCTAssertEqual(
            observer.attach(
                surface: surface,
                window: window,
                scene: scene,
                screen: screen,
                surfaceGeneration: generation,
                event: .registeredTraitsChanged
            ),
            .unchanged
        )

        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(settleRequests.count, 2)
        XCTAssertNotEqual(settleRequests[0], settleRequests[1])
        XCTAssertEqual(observer.settle(settleRequests[0]), .staleSettleRequest)
        XCTAssertEqual(observer.settle(settleRequests[1]), .published)
        XCTAssertEqual(snapshots.map(\.revision.rawValue), [1, 2, 3])
    }

    @MainActor
    func testMobileSceneGeometryObserverPublishesRotationSafeAreaAndTraits()
        throws
    {
        let generation = MobileSceneSurfaceGeneration(rawValue: 116)!
        let surface = MobileSceneGeometryTestSurface()
        let window = MobileSceneGeometryTestWindow()
        let scene = MobileSceneGeometryTestScene()
        let screen = MobileSceneGeometryTestScreen()
        var snapshots: [MobileSceneWindowSnapshot] = []
        let observer = MobileSceneGeometryTestObserver(
            surfaceGeneration: generation,
            surface: surface,
            reader: mobileSceneGeometryTestReader,
            handler: { snapshots.append($0) },
            settleRequestHandler: { _ in }
        )

        _ = observer.updateActivity(.active, surfaceGeneration: generation)
        _ = observer.attach(
            surface: surface,
            window: window,
            scene: scene,
            screen: screen,
            surfaceGeneration: generation,
            event: .didMoveToWindow
        )
        guard case let .attached(_, initialDisplay, _) =
            snapshots.last?.state else {
            return XCTFail("Expected initial attached geometry")
        }

        surface.reading = mobileSceneGeometryTestReading(
            width: 768,
            height: 1_024,
            safeAreaInsets: MobileSceneEdgeInsets(
                top: 59,
                leading: 0,
                bottom: 34,
                trailing: 0
            ),
            orientation: .portrait,
            traits: MobileSceneTraits(
                horizontalSizeClass: .compact,
                verticalSizeClass: .regular,
                interfaceStyle: .dark
            )
        )
        XCTAssertEqual(
            observer.attach(
                surface: surface,
                window: window,
                scene: scene,
                screen: screen,
                surfaceGeneration: generation,
                event: .layoutSubviews
            ),
            .published
        )
        guard case let .attached(_, rotatedDisplay, rotatedGeometry) =
            snapshots.last?.state else {
            return XCTFail("Expected rotated geometry")
        }
        XCTAssertEqual(rotatedDisplay, initialDisplay)
        XCTAssertEqual(rotatedGeometry.orientation, .portrait)
        XCTAssertEqual(rotatedGeometry.resizePhase, .resizing)
        XCTAssertEqual(
            rotatedGeometry.drawableSize,
            PixelSize(width: 1_536, height: 2_048)
        )

        surface.reading = mobileSceneGeometryTestReading(
            width: 768,
            height: 1_024,
            safeAreaInsets: MobileSceneEdgeInsets(
                top: 47,
                leading: 0,
                bottom: 21,
                trailing: 0
            ),
            orientation: .portrait,
            traits: rotatedGeometry.traits
        )
        XCTAssertEqual(
            observer.attach(
                surface: surface,
                window: window,
                scene: scene,
                screen: screen,
                surfaceGeneration: generation,
                event: .safeAreaInsetsDidChange
            ),
            .published
        )
        XCTAssertEqual(
            snapshots.last?.state.geometry?.safeAreaInsets,
            MobileSceneEdgeInsets(
                top: 47,
                leading: 0,
                bottom: 21,
                trailing: 0
            )
        )

        let lightTraits = MobileSceneTraits(
            horizontalSizeClass: .compact,
            verticalSizeClass: .regular,
            interfaceStyle: .light
        )
        surface.reading = mobileSceneGeometryTestReading(
            width: 768,
            height: 1_024,
            safeAreaInsets: MobileSceneEdgeInsets(
                top: 47,
                leading: 0,
                bottom: 21,
                trailing: 0
            ),
            orientation: .portrait,
            traits: lightTraits
        )
        XCTAssertEqual(
            observer.attach(
                surface: surface,
                window: window,
                scene: scene,
                screen: screen,
                surfaceGeneration: generation,
                event: .registeredTraitsChanged
            ),
            .published
        )
        XCTAssertEqual(snapshots.last?.state.geometry?.traits, lightTraits)
        XCTAssertEqual(snapshots.map(\.revision.rawValue), [1, 2, 3, 4])
    }

    @MainActor
    func testMobileSceneGeometryObserverTracksDisplayActivityAndDetach()
        throws
    {
        let generation = MobileSceneSurfaceGeneration(rawValue: 121)!
        let surface = MobileSceneGeometryTestSurface()
        let window = MobileSceneGeometryTestWindow()
        let scene = MobileSceneGeometryTestScene()
        let firstScreen = MobileSceneGeometryTestScreen()
        let replacementScreen = MobileSceneGeometryTestScreen()
        var snapshots: [MobileSceneWindowSnapshot] = []
        var lastSettleRequest: MobileStreamSceneGeometrySettleRequest?
        let observer = MobileSceneGeometryTestObserver(
            surfaceGeneration: generation,
            surface: surface,
            reader: mobileSceneGeometryTestReader,
            handler: { snapshots.append($0) },
            settleRequestHandler: { lastSettleRequest = $0 }
        )

        _ = observer.updateActivity(.active, surfaceGeneration: generation)
        _ = observer.attach(
            surface: surface,
            window: window,
            scene: scene,
            screen: firstScreen,
            surfaceGeneration: generation,
            event: .didMoveToWindow
        )
        guard case let .attached(_, firstDisplay, _) = snapshots.last?.state else {
            return XCTFail("Expected the first attached display")
        }
        XCTAssertEqual(firstDisplay.rawValue, 1)

        XCTAssertEqual(
            observer.attach(
                surface: surface,
                window: window,
                scene: scene,
                screen: replacementScreen,
                surfaceGeneration: generation,
                event: .didMoveToWindow
            ),
            .published
        )
        guard case let .attached(_, replacementDisplay, _) =
            snapshots.last?.state else {
            return XCTFail("Expected the replacement attached display")
        }
        XCTAssertEqual(replacementDisplay.rawValue, 2)
        XCTAssertEqual(
            observer.updateActivity(
                .background,
                surfaceGeneration: generation
            ),
            .published
        )
        XCTAssertEqual(snapshots.last?.state.activity, .background)

        _ = observer.attach(
            surface: surface,
            window: window,
            scene: scene,
            screen: replacementScreen,
            surfaceGeneration: generation,
            event: .layoutSubviews
        )
        let staleSettleRequest = try XCTUnwrap(lastSettleRequest)
        XCTAssertEqual(
            observer.detach(
                surface: surface,
                surfaceGeneration: generation
            ),
            .published
        )
        XCTAssertEqual(
            snapshots.last?.state,
            .detached(activity: .background)
        )
        XCTAssertNil(observer.currentWindow)
        XCTAssertNil(observer.currentScene)
        XCTAssertNil(observer.currentScreen)
        XCTAssertEqual(
            observer.settle(staleSettleRequest),
            .staleSettleRequest
        )
    }

    @MainActor
    func testMobileSceneGeometryObserverFailsClosedAndRejectsStaleWork()
        throws
    {
        let generation = MobileSceneSurfaceGeneration(rawValue: 131)!
        let staleGeneration = MobileSceneSurfaceGeneration(rawValue: 132)!
        let surface = MobileSceneGeometryTestSurface()
        let otherSurface = MobileSceneGeometryTestSurface()
        let window = MobileSceneGeometryTestWindow()
        let scene = MobileSceneGeometryTestScene()
        let screen = MobileSceneGeometryTestScreen()
        var snapshots: [MobileSceneWindowSnapshot] = []
        var settleRequest: MobileStreamSceneGeometrySettleRequest?
        let observer = MobileSceneGeometryTestObserver(
            surfaceGeneration: generation,
            surface: surface,
            reader: mobileSceneGeometryTestReader,
            handler: { snapshots.append($0) },
            settleRequestHandler: { settleRequest = $0 }
        )

        XCTAssertEqual(
            observer.attach(
                surface: surface,
                window: window,
                scene: scene,
                screen: screen,
                surfaceGeneration: staleGeneration,
                event: .layoutSubviews
            ),
            .staleSurfaceGeneration
        )
        XCTAssertEqual(
            observer.attach(
                surface: otherSurface,
                window: window,
                scene: scene,
                screen: screen,
                surfaceGeneration: generation,
                event: .layoutSubviews
            ),
            .staleSurface
        )
        surface.reading = mobileSceneGeometryTestReading(width: 0)
        XCTAssertEqual(
            observer.attach(
                surface: surface,
                window: window,
                scene: scene,
                screen: screen,
                surfaceGeneration: generation,
                event: .layoutSubviews
            ),
            .published
        )
        XCTAssertEqual(
            snapshots.last?.state,
            .unavailable(
                activity: .background,
                reason: .invalidViewBounds
            )
        )
        let pendingSettleRequest = try XCTUnwrap(settleRequest)
        XCTAssertEqual(
            observer.invalidate(
                surface: surface,
                surfaceGeneration: staleGeneration
            ),
            .staleSurfaceGeneration
        )
        XCTAssertEqual(
            observer.invalidate(
                surface: surface,
                surfaceGeneration: generation
            ),
            .invalidated
        )
        observer.updateHandler { _ in
            XCTFail("Invalidated geometry observer must reject a new handler")
        }
        XCTAssertEqual(
            observer.settle(pendingSettleRequest),
            .alreadyInvalidated
        )
        XCTAssertEqual(
            observer.detach(
                surface: surface,
                surfaceGeneration: generation
            ),
            .alreadyInvalidated
        )
        XCTAssertNil(observer.currentSurface)
    }

    @MainActor
    func testMobileGeometryBindingAppliesOneRevisionToDrawableVideoAndInput()
        throws
    {
        let generation = MobileSceneSurfaceGeneration(rawValue: 141)!
        let surface = MobileGeometryBindingTestSurface()
        var bindings: [MobileStreamGeometryBindingSnapshot?] = []
        let owner = MobileGeometryBindingTestOwner(
            surfaceGeneration: generation,
            surface: surface,
            sourceSize: PixelSize(width: 1_920, height: 1_080),
            mode: .fit,
            drawableApplier: { surface, size in
                surface.appliedDrawableSizes.append(size)
                return true
            },
            handler: { bindings.append($0) }
        )
        let sceneSnapshot = mobileGeometryBindingTestSnapshot(
            generation: generation,
            revision: 7,
            viewBounds: MobileSceneRect(
                x: 10,
                y: 20,
                width: 400,
                height: 300
            ),
            scale: 2
        )

        XCTAssertEqual(
            owner.update(
                sceneSnapshot,
                surface: surface,
                surfaceGeneration: generation
            ),
            .published
        )

        let binding = try XCTUnwrap(owner.currentBinding)
        XCTAssertEqual(binding.sceneWindowRevision.rawValue, 7)
        XCTAssertEqual(
            binding.coordinateSnapshot.drawableSize,
            PixelSize(width: 800, height: 600)
        )
        XCTAssertEqual(
            surface.appliedDrawableSizes,
            [PixelSize(width: 800, height: 600)]
        )
        XCTAssertEqual(bindings, [binding])

        let touch = owner.touch(TouchSample(
            id: 3,
            phase: .moved,
            localPoint: RemotePoint(x: 210, y: 170),
            pressure: 0.5
        ))
        XCTAssertEqual(touch.policy, .deliver)
        XCTAssertEqual(touch.event, .touch(TouchInputEvent(
            id: 3,
            phase: .moved,
            point: RemotePoint(x: 960, y: 540),
            pressure: 0.5,
            referenceSize: PixelSize(width: 1_920, height: 1_080)
        )))
        XCTAssertNil(owner.touch(TouchSample(
            id: 4,
            phase: .began,
            localPoint: RemotePoint(x: 210, y: 40),
            pressure: 1
        )).event)
    }

    @MainActor
    func testMobileGeometryBindingRevisesResizeAndFitFillAtomically()
        throws
    {
        let generation = MobileSceneSurfaceGeneration(rawValue: 151)!
        let surface = MobileGeometryBindingTestSurface()
        let owner = MobileGeometryBindingTestOwner(
            surfaceGeneration: generation,
            surface: surface,
            sourceSize: PixelSize(width: 1_920, height: 1_080),
            mode: .fit,
            drawableApplier: { surface, size in
                surface.appliedDrawableSizes.append(size)
                return true
            },
            handler: { _ in }
        )
        _ = owner.update(
            mobileGeometryBindingTestSnapshot(
                generation: generation,
                revision: 1
            ),
            surface: surface,
            surfaceGeneration: generation
        )
        let fit = try XCTUnwrap(owner.currentBinding)

        XCTAssertEqual(
            owner.updateRenderInputs(
                sourceSize: PixelSize(width: 1_920, height: 1_080),
                mode: .fill,
                surface: surface,
                surfaceGeneration: generation
            ),
            .published
        )
        let fill = try XCTUnwrap(owner.currentBinding)
        XCTAssertEqual(fill.sceneWindowRevision, fit.sceneWindowRevision)
        XCTAssertNotEqual(
            fill.coordinateSnapshot.revision,
            fit.coordinateSnapshot.revision
        )
        XCTAssertEqual(fill.coordinateSnapshot.mode, .fill)
        XCTAssertEqual(surface.appliedDrawableSizes.count, 1)
        guard case let .pointer(.absoluteMove(point, referenceSize, _)) =
            owner.pointerHover(PointerHoverSample(
                localPoint: RemotePoint(x: 0, y: 150),
                buttons: []
            )).event else {
            return XCTFail("Expected a fill-mapped absolute pointer")
        }
        XCTAssertEqual(point.x, 240, accuracy: 0.000_001)
        XCTAssertEqual(point.y, 540, accuracy: 0.000_001)
        XCTAssertEqual(
            referenceSize,
            PixelSize(width: 1_920, height: 1_080)
        )

        XCTAssertEqual(
            owner.update(
                mobileGeometryBindingTestSnapshot(
                    generation: generation,
                    revision: 2,
                    viewBounds: MobileSceneRect(
                        x: 0,
                        y: 0,
                        width: 600,
                        height: 300
                    ),
                    scale: 2
                ),
                surface: surface,
                surfaceGeneration: generation
            ),
            .published
        )
        XCTAssertEqual(
            owner.currentBinding?.coordinateSnapshot.drawableSize,
            PixelSize(width: 1_200, height: 600)
        )
        XCTAssertEqual(
            surface.appliedDrawableSizes,
            [
                PixelSize(width: 800, height: 600),
                PixelSize(width: 1_200, height: 600)
            ]
        )
    }

    @MainActor
    func testMobileGeometryBindingSeparatesSceneAndCoordinateRevisions()
        throws
    {
        let generation = MobileSceneSurfaceGeneration(rawValue: 156)!
        let surface = MobileGeometryBindingTestSurface()
        var bindings: [MobileStreamGeometryBindingSnapshot] = []
        let owner = MobileGeometryBindingTestOwner(
            surfaceGeneration: generation,
            surface: surface,
            sourceSize: PixelSize(width: 1_920, height: 1_080),
            mode: .fit,
            drawableApplier: { surface, size in
                surface.appliedDrawableSizes.append(size)
                return true
            },
            handler: { binding in
                if let binding {
                    bindings.append(binding)
                }
            }
        )

        _ = owner.update(
            mobileGeometryBindingTestSnapshot(
                generation: generation,
                revision: 1
            ),
            surface: surface,
            surfaceGeneration: generation
        )
        let initial = try XCTUnwrap(bindings.last)

        let compactTraits = MobileSceneTraits(
            horizontalSizeClass: .compact,
            verticalSizeClass: .regular,
            interfaceStyle: .light
        )
        _ = owner.update(
            mobileGeometryBindingTestSnapshot(
                generation: generation,
                revision: 2,
                safeAreaInsets: MobileSceneEdgeInsets(
                    top: 24,
                    leading: 0,
                    bottom: 16,
                    trailing: 0
                ),
                traits: compactTraits
            ),
            surface: surface,
            surfaceGeneration: generation
        )
        let nonCoordinateChange = try XCTUnwrap(bindings.last)
        XCTAssertEqual(nonCoordinateChange.sceneWindowRevision.rawValue, 2)
        XCTAssertEqual(
            nonCoordinateChange.coordinateSnapshot.revision,
            initial.coordinateSnapshot.revision
        )
        XCTAssertEqual(
            nonCoordinateChange.geometry.safeAreaInsets.top,
            24
        )
        XCTAssertEqual(nonCoordinateChange.geometry.traits, compactTraits)
        XCTAssertEqual(surface.appliedDrawableSizes.count, 1)

        _ = owner.update(
            mobileGeometryBindingTestSnapshot(
                generation: generation,
                revision: 3,
                viewBounds: MobileSceneRect(
                    x: 0,
                    y: 0,
                    width: 300,
                    height: 600
                ),
                orientation: .portrait,
                safeAreaInsets: MobileSceneEdgeInsets(
                    top: 24,
                    leading: 0,
                    bottom: 16,
                    trailing: 0
                ),
                traits: compactTraits
            ),
            surface: surface,
            surfaceGeneration: generation
        )
        let rotation = try XCTUnwrap(bindings.last)
        XCTAssertEqual(rotation.sceneWindowRevision.rawValue, 3)
        XCTAssertNotEqual(
            rotation.coordinateSnapshot.revision,
            nonCoordinateChange.coordinateSnapshot.revision
        )
        XCTAssertEqual(rotation.geometry.orientation, .portrait)
        XCTAssertEqual(
            rotation.coordinateSnapshot.drawableSize,
            PixelSize(width: 600, height: 1_200)
        )
        XCTAssertEqual(
            surface.appliedDrawableSizes,
            [
                PixelSize(width: 800, height: 600),
                PixelSize(width: 600, height: 1_200)
            ]
        )
    }

    @MainActor
    func testMobileGeometryBindingClearsInvalidGeometryAndSuppressesInput()
        throws
    {
        let generation = MobileSceneSurfaceGeneration(rawValue: 161)!
        let surface = MobileGeometryBindingTestSurface()
        var bindings: [MobileStreamGeometryBindingSnapshot?] = []
        let owner = MobileGeometryBindingTestOwner(
            surfaceGeneration: generation,
            surface: surface,
            sourceSize: PixelSize(width: 1_920, height: 1_080),
            mode: .fit,
            drawableApplier: { surface, size in
                surface.appliedDrawableSizes.append(size)
                return true
            },
            handler: { bindings.append($0) }
        )
        _ = owner.update(
            mobileGeometryBindingTestSnapshot(
                generation: generation,
                revision: 1
            ),
            surface: surface,
            surfaceGeneration: generation
        )

        XCTAssertEqual(
            owner.update(
                MobileSceneWindowSnapshot(
                    surfaceGeneration: generation,
                    revision: MobileSceneWindowRevision(rawValue: 2),
                    state: .unavailable(
                        activity: .active,
                        reason: .invalidViewBounds
                    )
                ),
                surface: surface,
                surfaceGeneration: generation
            ),
            .closed
        )
        XCTAssertNil(owner.currentBinding)
        XCTAssertEqual(surface.appliedDrawableSizes.last, .zero)
        XCTAssertEqual(bindings.count, 2)
        XCTAssertNil(bindings.last!)
        let touch = owner.touch(TouchSample(
            id: 1,
            phase: .began,
            localPoint: RemotePoint(x: 200, y: 150),
            pressure: 1
        ))
        XCTAssertNil(touch.event)
        XCTAssertEqual(
            touch.policy,
            .drop(reason: "Mobile geometry is unavailable")
        )
        XCTAssertEqual(
            owner.pointerHover(PointerHoverSample(
                localPoint: RemotePoint(x: 200, y: 150),
                buttons: []
            )).policy,
            .drop(reason: "Mobile geometry is unavailable")
        )
    }

    @MainActor
    func testMobileGeometryBindingRejectsStaleFailureAndLateWork()
        throws
    {
        let generation = MobileSceneSurfaceGeneration(rawValue: 171)!
        let staleGeneration = MobileSceneSurfaceGeneration(rawValue: 172)!
        let surface = MobileGeometryBindingTestSurface()
        let otherSurface = MobileGeometryBindingTestSurface()
        let owner = MobileGeometryBindingTestOwner(
            surfaceGeneration: generation,
            surface: surface,
            sourceSize: PixelSize(width: 1_920, height: 1_080),
            mode: .fit,
            drawableApplier: { surface, size in
                surface.appliedDrawableSizes.append(size)
                return !surface.rejectDrawableApplication
            },
            handler: { _ in }
        )
        let snapshot = mobileGeometryBindingTestSnapshot(
            generation: generation,
            revision: 1
        )

        XCTAssertEqual(
            owner.update(
                snapshot,
                surface: surface,
                surfaceGeneration: staleGeneration
            ),
            .staleSurfaceGeneration
        )
        XCTAssertEqual(
            owner.update(
                snapshot,
                surface: otherSurface,
                surfaceGeneration: generation
            ),
            .staleSurface
        )
        surface.rejectDrawableApplication = true
        XCTAssertEqual(
            owner.update(
                snapshot,
                surface: surface,
                surfaceGeneration: generation
            ),
            .drawableApplicationFailed
        )
        XCTAssertNil(owner.currentBinding)
        surface.rejectDrawableApplication = false
        XCTAssertEqual(
            owner.update(
                snapshot,
                surface: surface,
                surfaceGeneration: generation
            ),
            .published
        )
        XCTAssertNotNil(owner.currentBinding)
        XCTAssertEqual(
            owner.invalidate(
                surface: surface,
                surfaceGeneration: generation
            ),
            .invalidated
        )
        XCTAssertEqual(
            owner.update(
                mobileGeometryBindingTestSnapshot(
                    generation: generation,
                    revision: 2
                ),
                surface: surface,
                surfaceGeneration: generation
            ),
            .alreadyInvalidated
        )
        XCTAssertNil(owner.currentSurface)
    }

    @MainActor
    func testMobileSurfaceCoordinatorSynchronizesGeometryAndInputBoundary()
        throws
    {
        let generation = MobileSceneSurfaceGeneration(rawValue: 181)!
        let sceneSnapshot = mobileGeometryBindingTestSnapshot(
            generation: generation,
            revision: 9,
            viewBounds: MobileSceneRect(
                x: 0,
                y: 0,
                width: 600,
                height: 400
            ),
            scale: 2
        )
        guard case let .attached(_, _, geometry) = sceneSnapshot.state else {
            return XCTFail("Expected attached mobile geometry")
        }
        let coordinates = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: 7,
            sourceSize: PixelSize(width: 1_920, height: 1_080),
            drawableSize: geometry.drawableSize,
            mode: .fill
        ))
        let binding = MobileStreamGeometryBindingSnapshot(
            surfaceGeneration: generation,
            sceneWindowRevision: sceneSnapshot.revision,
            geometry: geometry,
            coordinateSnapshot: coordinates
        )
        let initialState = StreamRenderState(transform: RenderTransform(
            sourceSize: coordinates.sourceSize,
            drawableSize: PixelSize(width: 320, height: 240),
            mode: coordinates.mode
        ))
        var firstOutputs: [InputAdapterOutput] = []
        let coordinator = MobileStreamSurfaceCoordinator(
            presentationSource: StreamVideoPresentationSource(),
            renderState: initialState,
            inputOutputHandler: { firstOutputs.append($0) }
        )
        coordinator.activateSurfaceGeneration(generation)

        coordinator.handleGeometryBinding(binding)

        XCTAssertEqual(coordinator.currentGeometryBinding, binding)
        XCTAssertEqual(
            initialState.transform,
            RenderTransform(
                sourceSize: coordinates.sourceSize,
                drawableSize: coordinates.drawableSize,
                mode: coordinates.mode
            )
        )
        XCTAssertEqual(
            initialState.coordinateSnapshot?.resolvedVideo,
            coordinates.resolvedVideo
        )

        let replacementState = StreamRenderState()
        var replacementOutputs: [InputAdapterOutput] = []
        coordinator.update(
            renderState: replacementState,
            inputOutputHandler: { replacementOutputs.append($0) }
        )
        XCTAssertEqual(replacementState.transform, RenderTransform())

        replacementState.transform.sourceSize = coordinates.sourceSize
        replacementState.transform.mode = coordinates.mode
        coordinator.update(
            renderState: replacementState,
            inputOutputHandler: { replacementOutputs.append($0) }
        )
        XCTAssertEqual(
            replacementState.transform,
            RenderTransform(
                sourceSize: coordinates.sourceSize,
                drawableSize: coordinates.drawableSize,
                mode: coordinates.mode
            )
        )

        let output = InputAdapterOutput(
            event: nil,
            policy: .drop(reason: "bounded mobile input")
        )
        coordinator.handleInputOutput(output)
        XCTAssertTrue(firstOutputs.isEmpty)
        XCTAssertEqual(replacementOutputs, [output])

        coordinator.handleGeometryBinding(nil)
        XCTAssertNil(coordinator.currentGeometryBinding)
        XCTAssertEqual(replacementState.transform.drawableSize, .zero)
        XCTAssertNil(replacementState.coordinateSnapshot)
    }

    @MainActor
    func testMobileGeometryReplacementTeardownKeepsLateWorkInert()
        throws
    {
        let firstGeneration = MobileSceneSurfaceGeneration(rawValue: 186)!
        let replacementGeneration =
            MobileSceneSurfaceGeneration(rawValue: 187)!
        let surface = MobileGeometryBindingTestSurface()
        let renderState = StreamRenderState(transform: RenderTransform(
            sourceSize: PixelSize(width: 1_920, height: 1_080),
            drawableSize: .zero,
            mode: .fit
        ))
        let coordinator = MobileStreamSurfaceCoordinator(
            presentationSource: StreamVideoPresentationSource(),
            renderState: renderState
        )
        coordinator.activateSurfaceGeneration(firstGeneration)
        let firstOwner = MobileGeometryBindingTestOwner(
            surfaceGeneration: firstGeneration,
            surface: surface,
            sourceSize: renderState.transform.sourceSize,
            mode: renderState.transform.mode,
            drawableApplier: { surface, size in
                surface.appliedDrawableSizes.append(size)
                return true
            },
            handler: { coordinator.handleGeometryBinding($0) }
        )
        let firstSnapshot = mobileGeometryBindingTestSnapshot(
            generation: firstGeneration,
            revision: 1
        )

        _ = firstOwner.update(
            firstSnapshot,
            surface: surface,
            surfaceGeneration: firstGeneration
        )
        XCTAssertEqual(
            renderState.transform.drawableSize,
            PixelSize(width: 800, height: 600)
        )
        XCTAssertEqual(
            firstOwner.touch(TouchSample(
                id: 1,
                phase: .began,
                localPoint: RemotePoint(x: 200, y: 150),
                pressure: 1
            )).policy,
            .deliver
        )

        XCTAssertEqual(
            firstOwner.invalidate(
                surface: surface,
                surfaceGeneration: firstGeneration
            ),
            .invalidated
        )
        XCTAssertNil(coordinator.currentGeometryBinding)
        XCTAssertEqual(renderState.transform.drawableSize, .zero)
        XCTAssertNil(renderState.coordinateSnapshot)
        XCTAssertEqual(
            firstOwner.touch(TouchSample(
                id: 1,
                phase: .cancelled,
                localPoint: RemotePoint(x: 200, y: 150),
                pressure: 0
            )).policy,
            .drop(reason: "Mobile geometry is unavailable")
        )

        coordinator.activateSurfaceGeneration(replacementGeneration)
        let replacementOwner = MobileGeometryBindingTestOwner(
            surfaceGeneration: replacementGeneration,
            surface: surface,
            sourceSize: renderState.transform.sourceSize,
            mode: renderState.transform.mode,
            drawableApplier: { surface, size in
                surface.appliedDrawableSizes.append(size)
                return true
            },
            handler: { coordinator.handleGeometryBinding($0) }
        )
        _ = replacementOwner.update(
            mobileGeometryBindingTestSnapshot(
                generation: replacementGeneration,
                revision: 1,
                viewBounds: MobileSceneRect(
                    x: 0,
                    y: 0,
                    width: 600,
                    height: 400
                )
            ),
            surface: surface,
            surfaceGeneration: replacementGeneration
        )
        let replacementBinding = try XCTUnwrap(
            coordinator.currentGeometryBinding
        )
        XCTAssertEqual(
            renderState.transform.drawableSize,
            PixelSize(width: 1_200, height: 800)
        )

        XCTAssertEqual(
            firstOwner.update(
                firstSnapshot,
                surface: surface,
                surfaceGeneration: firstGeneration
            ),
            .alreadyInvalidated
        )
        XCTAssertEqual(
            coordinator.currentGeometryBinding,
            replacementBinding
        )
        XCTAssertEqual(
            renderState.transform.drawableSize,
            PixelSize(width: 1_200, height: 800)
        )
        XCTAssertEqual(
            replacementOwner.invalidate(
                surface: surface,
                surfaceGeneration: replacementGeneration
            ),
            .invalidated
        )
        XCTAssertNil(coordinator.currentGeometryBinding)
        XCTAssertEqual(renderState.transform.drawableSize, .zero)
        XCTAssertEqual(
            surface.appliedDrawableSizes,
            [
                PixelSize(width: 800, height: 600),
                .zero,
                PixelSize(width: 1_200, height: 800),
                .zero
            ]
        )
    }

    @MainActor
    func testMobileDisplayRevisionBindsOnlyCurrentSurfaceToHDRResolution()
        throws
    {
        let currentGeneration = MobileSceneSurfaceGeneration(rawValue: 188)!
        let staleGeneration = MobileSceneSurfaceGeneration(rawValue: 189)!
        let metadata = VideoColorMetadata.hdr10VideoRange()
        let frame = try makeFrame(
            generation: 81,
            frameID: 1,
            metadata: metadata
        )
        let renderState = StreamRenderState(transform: RenderTransform(
            sourceSize: PixelSize(width: 64, height: 64),
            drawableSize: PixelSize(width: 128, height: 96),
            mode: .fit
        ))
        renderState.negotiatedVideoColorMetadata = metadata
        renderState.decodedVideoPresentationContract =
            StreamVideoDecodedPresentationContract(
                decoderGeneration: frame.generation,
                colorMetadata: metadata,
                decodedLayout: HDRDecodedPixelBufferLayout(
                    pixelBuffer: frame.pixelBuffer
                )
            )
        let coordinator = MobileStreamSurfaceCoordinator(
            presentationSource: StreamVideoPresentationSource(),
            renderState: renderState,
            userAllowsHDR: true,
            platformCapabilities:
                HDRPlatformOutputCapabilityAdapter.resolve(for: .iOS)
                    .capabilities
        )
        coordinator.activateSurfaceGeneration(currentGeneration)
        let surface = MobileGeometryBindingTestSurface()
        let geometryOwner = MobileGeometryBindingTestOwner(
            surfaceGeneration: currentGeneration,
            surface: surface,
            sourceSize: renderState.transform.sourceSize,
            mode: renderState.transform.mode,
            drawableApplier: { surface, size in
                surface.appliedDrawableSizes.append(size)
                return true
            },
            handler: { coordinator.handleGeometryBinding($0) }
        )
        XCTAssertEqual(
            geometryOwner.update(
                mobileGeometryBindingTestSnapshot(
                    generation: currentGeneration,
                    revision: 1,
                    viewBounds: MobileSceneRect(
                        x: 0,
                        y: 0,
                        width: 64,
                        height: 48
                    )
                ),
                surface: surface,
                surfaceGeneration: currentGeneration
            ),
            .published
        )
        var currentPublisher = MobileDisplayEDRSnapshotPublisher(
            surfaceGeneration: currentGeneration
        )

        let first = try publishedMobileDisplaySnapshot(
            currentPublisher.update(MobileDisplayEDREventEnvelope(
                surfaceGeneration: currentGeneration,
                sample: .attached(MobileDisplayEDRReading(
                    displayGeneration: 1,
                    potentialHeadroom: 4,
                    currentHeadroom: 2
                ))
            ))
        )
        XCTAssertEqual(
            coordinator.handleDisplayEDRSnapshot(first),
            .applied
        )
        let activeEDR = try XCTUnwrap(
            renderState.hdrRenderResolution.configuration
        )
        XCTAssertEqual(coordinator.currentDisplayEDRSnapshot, first)
        XCTAssertEqual(renderState.displaySnapshot, first.renderSnapshot)
        XCTAssertEqual(renderState.headroom.current, 2)
        XCTAssertEqual(activeEDR.identity.displayRevision, first.revision)
        XCTAssertEqual(activeEDR.identity.mappingMode, .hdrEDR)
        XCTAssertEqual(activeEDR.outputMode, .edr)
        XCTAssertEqual(
            coordinator.handleDisplayEDRSnapshot(first),
            .unchanged
        )

        var stalePublisher = MobileDisplayEDRSnapshotPublisher(
            surfaceGeneration: staleGeneration
        )
        let stale = try publishedMobileDisplaySnapshot(
            stalePublisher.update(MobileDisplayEDREventEnvelope(
                surfaceGeneration: staleGeneration,
                sample: .attached(MobileDisplayEDRReading(
                    displayGeneration: 2,
                    potentialHeadroom: 8,
                    currentHeadroom: 7
                ))
            ))
        )
        XCTAssertEqual(
            coordinator.handleDisplayEDRSnapshot(stale),
            .staleSurfaceGeneration
        )
        XCTAssertEqual(
            renderState.hdrRenderResolution.configuration?.identity,
            activeEDR.identity
        )

        let constrained = try publishedMobileDisplaySnapshot(
            currentPublisher.update(MobileDisplayEDREventEnvelope(
                surfaceGeneration: currentGeneration,
                sample: .attached(MobileDisplayEDRReading(
                    displayGeneration: 1,
                    potentialHeadroom: 4,
                    currentHeadroom: 1
                ))
            ))
        )
        XCTAssertEqual(
            coordinator.handleDisplayEDRSnapshot(constrained),
            .applied
        )
        let fallback = try XCTUnwrap(
            renderState.hdrRenderResolution.configuration
        )
        XCTAssertEqual(
            fallback.identity.displayRevision,
            constrained.revision
        )
        XCTAssertEqual(fallback.identity.mappingMode, .hdrToSDR)
        XCTAssertEqual(
            fallback.outputMode,
            .sdrFallback(.currentHeadroomInsufficient)
        )
        XCTAssertNotEqual(fallback.identity, activeEDR.identity)

        let replacement = try publishedMobileDisplaySnapshot(
            currentPublisher.update(MobileDisplayEDREventEnvelope(
                surfaceGeneration: currentGeneration,
                sample: .attached(MobileDisplayEDRReading(
                    displayGeneration: 2,
                    potentialHeadroom: 4,
                    currentHeadroom: 2
                ))
            ))
        )
        XCTAssertEqual(
            coordinator.handleDisplayEDREvent(.snapshot(replacement)),
            .applied
        )
        let replacementEDR = try XCTUnwrap(
            renderState.hdrRenderResolution.configuration
        )
        XCTAssertEqual(
            replacementEDR.identity.displayRevision,
            replacement.revision
        )
        XCTAssertEqual(replacementEDR.identity.mappingMode, .hdrEDR)
        XCTAssertNotEqual(replacementEDR.identity, fallback.identity)

        coordinator.update(
            renderState: renderState,
            inputOutputHandler: { _ in },
            userAllowsHDR: false
        )
        XCTAssertEqual(
            renderState.hdrRenderResolution.configuration?.outputMode,
            .sdrFallback(.userPreferenceDisabled)
        )
        XCTAssertEqual(
            renderState.hdrRenderResolution.configuration?.identity
                .displayRevision,
            replacement.revision
        )
        XCTAssertEqual(
            geometryOwner.invalidate(
                surface: surface,
                surfaceGeneration: currentGeneration
            ),
            .invalidated
        )
    }

    @MainActor
    func testMobileDisplayRevisionExhaustionClosesUntilSurfaceReplacement()
        throws
    {
        let generation = MobileSceneSurfaceGeneration(rawValue: 190)!
        let replacementGeneration =
            MobileSceneSurfaceGeneration(rawValue: 191)!
        let staleGeneration = MobileSceneSurfaceGeneration(rawValue: 192)!
        let metadata = VideoColorMetadata.hdr10VideoRange()
        let frame = try makeFrame(
            generation: 82,
            frameID: 1,
            metadata: metadata
        )
        let renderState = StreamRenderState(transform: RenderTransform(
            sourceSize: PixelSize(width: 64, height: 64),
            drawableSize: PixelSize(width: 128, height: 96),
            mode: .fit
        ))
        renderState.negotiatedVideoColorMetadata = metadata
        renderState.decodedVideoPresentationContract =
            StreamVideoDecodedPresentationContract(
                decoderGeneration: frame.generation,
                colorMetadata: metadata,
                decodedLayout: HDRDecodedPixelBufferLayout(
                    pixelBuffer: frame.pixelBuffer
                )
            )
        let coordinator = MobileStreamSurfaceCoordinator(
            presentationSource: StreamVideoPresentationSource(),
            renderState: renderState,
            userAllowsHDR: true,
            platformCapabilities:
                HDRPlatformOutputCapabilityAdapter.resolve(for: .iOS)
                    .capabilities
        )
        coordinator.activateSurfaceGeneration(generation)
        let surface = MobileGeometryBindingTestSurface()
        let geometryOwner = MobileGeometryBindingTestOwner(
            surfaceGeneration: generation,
            surface: surface,
            sourceSize: renderState.transform.sourceSize,
            mode: renderState.transform.mode,
            drawableApplier: { _, _ in true },
            handler: { coordinator.handleGeometryBinding($0) }
        )
        XCTAssertEqual(
            geometryOwner.update(
                mobileGeometryBindingTestSnapshot(
                    generation: generation,
                    revision: 1,
                    viewBounds: MobileSceneRect(
                        x: 0,
                        y: 0,
                        width: 64,
                        height: 48
                    )
                ),
                surface: surface,
                surfaceGeneration: generation
            ),
            .published
        )
        var publisher = MobileDisplayEDRSnapshotPublisher(
            surfaceGeneration: generation
        )
        let active = try publishedMobileDisplaySnapshot(
            publisher.update(MobileDisplayEDREventEnvelope(
                surfaceGeneration: generation,
                sample: .attached(MobileDisplayEDRReading(
                    displayGeneration: 1,
                    potentialHeadroom: 4,
                    currentHeadroom: 2
                ))
            ))
        )
        XCTAssertEqual(
            coordinator.handleDisplayEDREvent(.snapshot(active)),
            .applied
        )
        XCTAssertNotNil(renderState.hdrRenderResolution.configuration)

        XCTAssertEqual(
            coordinator.handleDisplayEDREvent(.revisionExhausted(
                surfaceGeneration: staleGeneration
            )),
            .staleSurfaceGeneration
        )
        XCTAssertEqual(
            coordinator.handleDisplayEDREvent(.revisionExhausted(
                surfaceGeneration: generation
            )),
            .revisionExhausted
        )
        XCTAssertNil(coordinator.currentDisplayEDRSnapshot)
        XCTAssertTrue(coordinator.isDisplayRevisionExhausted)
        XCTAssertNil(renderState.displaySnapshot)
        XCTAssertEqual(renderState.headroom, DisplayHeadroom())
        XCTAssertTrue(renderState.isDisplayRevisionExhausted)
        XCTAssertEqual(
            renderState.hdrRenderResolution,
            .closed(.displayRevisionExhausted)
        )
        XCTAssertEqual(
            coordinator.handleDisplayEDREvent(.snapshot(active)),
            .revisionExhausted
        )
        XCTAssertEqual(
            coordinator.handleDisplayEDREvent(.revisionExhausted(
                surfaceGeneration: generation
            )),
            .unchanged
        )

        coordinator.activateSurfaceGeneration(replacementGeneration)
        XCTAssertFalse(coordinator.isDisplayRevisionExhausted)
        XCTAssertFalse(renderState.isDisplayRevisionExhausted)
        XCTAssertNil(renderState.displaySnapshot)
        XCTAssertEqual(
            renderState.hdrRenderResolution,
            .closed(.invalidDisplayRevision)
        )
        XCTAssertEqual(
            geometryOwner.invalidate(
                surface: surface,
                surfaceGeneration: generation
            ),
            .invalidated
        )
    }

    @MainActor
    func testDisplayMoveDuringDrawDropsPlanFromPriorRevision() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(
            frame: CGRect(x: 0, y: 0, width: 64, height: 64),
            device: device
        )
        let drawableLayer = CAMetalLayer()
        drawableLayer.device = device
        drawableLayer.pixelFormat = .bgra8Unorm_srgb
        drawableLayer.drawableSize = CGSize(width: 64, height: 64)
        let drawable = try XCTUnwrap(drawableLayer.nextDrawable())
        let source = StreamVideoPresentationSource()
        let sessionID = UUID()
        source.beginSession(sessionID: sessionID, mediaGeneration: 1)
        let metadata = VideoColorMetadata.hdr10VideoRange()
        let frame = try makeFrame(
            generation: 83,
            frameID: 1,
            metadata: metadata
        )
        source.consume(
            .sessionStarted(
                generation: frame.generation,
                colorMetadata: metadata
            ),
            sessionID: sessionID,
            mediaGeneration: 1
        )
        source.consume(
            .frame(frame),
            sessionID: sessionID,
            mediaGeneration: 1
        )

        let renderState = StreamRenderState(transform: RenderTransform(
            sourceSize: PixelSize(width: 64, height: 64),
            drawableSize: PixelSize(width: 64, height: 64),
            mode: .fit
        ))
        renderState.policy = .active
        let first = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 70,
            currentHeadroom: 2
        )
        let replacement = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 71,
            currentHeadroom: 3
        )
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        let firstRuntime = RecordingStreamMetalPresenterRuntime()
        let replacementRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimes = [
            initialRuntime,
            firstRuntime,
            replacementRuntime
        ]
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        var shouldMoveDisplay = false
        var presenter: StreamMetalPresenter!
        presenter = StreamMetalPresenter(
            presentationSource: source,
            renderState: renderState,
            runtimeFactory: { _, _ in runtimes.removeFirst() },
            surfaceAdapterFactory: { _ in surfaceAdapter },
            drawableProvider: { _ in
                if shouldMoveDisplay {
                    shouldMoveDisplay = false
                    renderState.hdrRenderResolution = .resolved(replacement)
                    presenter.update(renderState: renderState)
                }
                return drawable
            }
        )
        presenter.configure(view)
        XCTAssertEqual(
            presenter.transition(.resolved(first), on: view),
            .applied(previous: nil, current: first.identity)
        )
        presenter.draw(in: view)
        presenter.draw(in: view)
        XCTAssertEqual(firstRuntime.presentedConfigurations, [first.identity])

        shouldMoveDisplay = true
        presenter.draw(in: view)

        XCTAssertEqual(firstRuntime.presentedConfigurations, [first.identity])
        XCTAssertEqual(firstRuntime.invalidationCount, 1)
        XCTAssertTrue(replacementRuntime.presentedConfigurations.isEmpty)
        XCTAssertEqual(
            presenter.snapshot().activeConfiguration,
            replacement.identity
        )

        presenter.draw(in: view)
        presenter.draw(in: view)
        XCTAssertEqual(
            replacementRuntime.presentedConfigurations,
            [replacement.identity]
        )
        XCTAssertEqual(
            replacementRuntime.presentedConfigurations.first?.displayRevision,
            HDRDisplayRevision(rawValue: 71)
        )
        presenter.stop()
        XCTAssertEqual(replacementRuntime.invalidationCount, 1)
    }

    func testSDRFrameResolvesExplicitSRGBMetalPresentation() throws {
        let frame = try makeFrame(
            generation: 7,
            frameID: 11,
            metadata: .rec709VideoRange()
        )
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: try makeSnapshot(revision: 3)
        )

        XCTAssertEqual(plan.configuration.decoderGeneration, 7)
        XCTAssertEqual(plan.configuration.displayRevision.rawValue, 3)
        XCTAssertEqual(plan.configuration.mappingMode, .sdr)
        XCTAssertEqual(plan.configuration.surfaceContract.drawablePixelFormat, .bgra8UnormSRGB)
        XCTAssertEqual(plan.configuration.surfaceContract.outputColorSpace, .sRGB)
        XCTAssertEqual(plan.configuration.surfaceContract.outputGamut, .sRGB)
        XCTAssertEqual(plan.configuration.surfaceContract.extendedRangeIntent, .disabled)
        XCTAssertEqual(plan.configuration.surfaceContract.metadataMode, .none)
        XCTAssertEqual(plan.uniforms.inputBitDepth, 8)
        XCTAssertEqual(plan.uniforms.mappingMode, 0)
        XCTAssertEqual(plan.uniforms.currentHeadroom, 1)
    }

    func testHDRFrameResolvesExplicitSDRFallbackUntilEDRSurfaceAdapterOwnsIntent() throws {
        let metadata = VideoColorMetadata.hdr10VideoRange()
        let frame = try makeFrame(
            generation: 9,
            frameID: 12,
            metadata: metadata
        )
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: try makeSnapshot(revision: 4)
        )

        XCTAssertEqual(plan.configuration.colorSignature, HDRRenderColorSignature(metadata: metadata))
        XCTAssertEqual(plan.configuration.mappingMode, .hdrToSDR)
        XCTAssertEqual(plan.configuration.surfaceContract.drawablePixelFormat, .bgra8UnormSRGB)
        XCTAssertEqual(plan.configuration.surfaceContract.extendedRangeIntent, .disabled)
        XCTAssertEqual(plan.uniforms.inputBitDepth, 10)
        XCTAssertEqual(plan.uniforms.mappingMode, 2)
        XCTAssertEqual(plan.uniforms.currentHeadroom, 1)
        XCTAssertGreaterThan(plan.uniforms.sourcePeakNits, 100)
    }

    func testCoordinateRevisionTemporarilyOwnsPresentationRevision() throws {
        let frame = try makeFrame(
            generation: 2,
            frameID: 1,
            metadata: .rec709VideoRange()
        )
        let first = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: try makeSnapshot(revision: 5)
        )
        let replacement = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: try makeSnapshot(revision: 6)
        )

        XCTAssertNotEqual(first.configuration, replacement.configuration)
        XCTAssertEqual(first.configuration.displayRevision.rawValue, 5)
        XCTAssertEqual(replacement.configuration.displayRevision.rawValue, 6)
        XCTAssertEqual(first.uniforms, replacement.uniforms)
    }

    func testZeroCoordinateRevisionFailsClosed() throws {
        let frame = try makeFrame(
            generation: 2,
            frameID: 1,
            metadata: .rec709VideoRange()
        )
        XCTAssertThrowsError(try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: try makeSnapshot(revision: 0)
        )) { error in
            XCTAssertEqual(error as? HDRRenderResolutionError, .invalidDisplayRevision)
        }
    }

    func testProductionRuntimeMapsAndRendersDecodedSDRFrameOffscreen() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let frame = try makeFrame(
            generation: 12,
            frameID: 40,
            metadata: .rec709VideoRange()
        )
        try fillSDRWhite(frame.pixelBuffer)
        let coordinates = try makeSnapshot(revision: 9)
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: coordinates
        )
        let target = try makeTarget(
            device: device,
            width: coordinates.drawableSize.width,
            height: coordinates.drawableSize.height
        )
        let runtime = try StreamMetalPresenterRuntime(
            device: device,
            bundle: Bundle(for: Self.self)
        )

        let result = try runtime.present(
            frame: frame,
            plan: plan,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .waitUntilCompleted
        )

        XCTAssertEqual(result, .submitted(
            frameID: 40,
            decoderGeneration: 12,
            displayRevision: HDRDisplayRevision(rawValue: 9),
            coordinateRevision: 9
        ))
        let pixel = readPixel(
            target,
            x: coordinates.drawableSize.width / 2,
            y: coordinates.drawableSize.height / 2
        )
        XCTAssertGreaterThan(pixel.red, 220)
        XCTAssertGreaterThan(pixel.green, 220)
        XCTAssertGreaterThan(pixel.blue, 220)
        XCTAssertEqual(pixel.alpha, 255)

        runtime.invalidate()
        XCTAssertThrowsError(try runtime.present(
            frame: frame,
            plan: plan,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .waitUntilCompleted
        )) { error in
            XCTAssertEqual(error as? StreamMetalPresenterError, .invalidatedRuntime)
        }
    }

    func testFrameDecisionCoversDrawableMismatchMissingStateAndPause() {
        XCTAssertEqual(StreamMetalFrameDecisionResolver.resolve(
            policy: .active,
            hasDrawable: false,
            hasCoordinates: true,
            drawableMatchesCoordinates: true,
            hasFrame: true
        ), .waitForDrawable)
        XCTAssertEqual(StreamMetalFrameDecisionResolver.resolve(
            policy: .paused(reason: "background"),
            hasDrawable: false,
            hasCoordinates: true,
            drawableMatchesCoordinates: true,
            hasFrame: true
        ), .clear(.inactivePolicy))
        XCTAssertEqual(StreamMetalFrameDecisionResolver.resolve(
            policy: .paused(reason: "background"),
            hasDrawable: true,
            hasCoordinates: true,
            drawableMatchesCoordinates: true,
            hasFrame: true
        ), .clear(.inactivePolicy))
        XCTAssertEqual(StreamMetalFrameDecisionResolver.resolve(
            policy: .active,
            hasDrawable: true,
            hasCoordinates: false,
            drawableMatchesCoordinates: false,
            hasFrame: true
        ), .clear(.missingCoordinates))
        XCTAssertEqual(StreamMetalFrameDecisionResolver.resolve(
            policy: .active,
            hasDrawable: true,
            hasCoordinates: true,
            drawableMatchesCoordinates: false,
            hasFrame: true
        ), .clear(.drawableMismatch))
        XCTAssertEqual(StreamMetalFrameDecisionResolver.resolve(
            policy: .throttled(reason: "occluded"),
            hasDrawable: true,
            hasCoordinates: true,
            drawableMatchesCoordinates: true,
            hasFrame: false
        ), .clear(.missingFrame))
        XCTAssertEqual(StreamMetalFrameDecisionResolver.resolve(
            policy: .throttled(reason: "occluded"),
            hasDrawable: true,
            hasCoordinates: true,
            drawableMatchesCoordinates: true,
            hasFrame: true
        ), .present)
    }

    func testViewScheduleResumesAt60ThrottlesAt15AndRequestsOnePausedDraw() {
        XCTAssertEqual(
            StreamMetalViewScheduleResolver.resolve(.active),
            StreamMetalViewSchedule(
                isPaused: false,
                preferredFramesPerSecond: 60,
                requestsImmediateDraw: false
            )
        )
        XCTAssertEqual(
            StreamMetalViewScheduleResolver.resolve(.throttled(reason: "occluded")),
            StreamMetalViewSchedule(
                isPaused: false,
                preferredFramesPerSecond: 15,
                requestsImmediateDraw: false
            )
        )
        let paused = StreamMetalViewSchedule(
            isPaused: true,
            preferredFramesPerSecond: 60,
            requestsImmediateDraw: true
        )
        XCTAssertEqual(StreamMetalViewScheduleResolver.resolve(.idle), paused)
        XCTAssertEqual(
            StreamMetalViewScheduleResolver.resolve(.paused(reason: "background")),
            paused
        )
    }

    func testRuntimeCachesFrameAndRebuildsOnCoordinateRevisionAndReplacement() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let mapper = try RecordingMetalVideoFrameMapper(device: device)
        let renderer = RecordingHDRMetalVideoRenderer()
        let runtime = try makeRuntime(device: device, mapper: mapper, renderer: renderer)
        let firstFrame = try makeFrame(
            generation: 20,
            frameID: 1,
            metadata: .rec709VideoRange()
        )
        let firstCoordinates = try makeSnapshot(revision: 30)
        let firstPlan = try StreamMetalPresentationPlanResolver.resolve(
            frame: firstFrame,
            coordinateSnapshot: firstCoordinates
        )
        let target = try makeTarget(
            device: device,
            width: firstCoordinates.drawableSize.width,
            height: firstCoordinates.drawableSize.height
        )

        for _ in 0..<2 {
            try runtime.present(
                frame: firstFrame,
                plan: firstPlan,
                coordinateSnapshot: firstCoordinates,
                target: HDRMetalRenderTarget(texture: target),
                completion: .asynchronous
            )
        }
        XCTAssertEqual(mapper.mapCount, 1)
        XCTAssertEqual(renderer.renderCount, 2)
        XCTAssertEqual(renderer.configurations, [firstPlan.configuration])

        let resizedCoordinates = try makeSnapshot(revision: 31)
        let resizedPlan = try StreamMetalPresentationPlanResolver.resolve(
            frame: firstFrame,
            coordinateSnapshot: resizedCoordinates
        )
        try runtime.present(
            frame: firstFrame,
            plan: resizedPlan,
            coordinateSnapshot: resizedCoordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .asynchronous
        )
        let replacementFrame = try makeFrame(
            generation: 20,
            frameID: 2,
            metadata: .rec709VideoRange()
        )
        try runtime.present(
            frame: replacementFrame,
            plan: resizedPlan,
            coordinateSnapshot: resizedCoordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .asynchronous
        )

        XCTAssertEqual(mapper.mapCount, 3)
        XCTAssertEqual(mapper.flushCount, 2)
        XCTAssertEqual(renderer.configurations, [
            firstPlan.configuration,
            resizedPlan.configuration
        ])
        XCTAssertEqual(runtime.snapshot(), StreamMetalPresenterRuntimeSnapshot(
            activeConfiguration: resizedPlan.configuration,
            mappedFrameGeneration: 20,
            mappedFrameID: 2,
            isInvalidated: false,
            submittedFrameCount: 4,
            failedPresentationCount: 0,
            stopCount: 0,
            invalidationCount: 0
        ))
    }

    func testPipelineFailureFlushesConfigurationAndMappedFrame() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let mapper = try RecordingMetalVideoFrameMapper(device: device)
        let renderer = RecordingHDRMetalVideoRenderer(renderError: .pipelineFailure)
        let runtime = try makeRuntime(device: device, mapper: mapper, renderer: renderer)
        let frame = try makeFrame(
            generation: 21,
            frameID: 3,
            metadata: .rec709VideoRange()
        )
        let coordinates = try makeSnapshot(revision: 32)
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: coordinates
        )
        let target = try makeTarget(
            device: device,
            width: coordinates.drawableSize.width,
            height: coordinates.drawableSize.height
        )

        XCTAssertThrowsError(try runtime.present(
            frame: frame,
            plan: plan,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .asynchronous
        )) { error in
            XCTAssertEqual(error as? RecordingRendererError, .pipelineFailure)
        }
        let snapshot = runtime.snapshot()
        XCTAssertNil(snapshot.activeConfiguration)
        XCTAssertNil(snapshot.mappedFrameGeneration)
        XCTAssertNil(snapshot.mappedFrameID)
        XCTAssertEqual(snapshot.submittedFrameCount, 0)
        XCTAssertEqual(snapshot.failedPresentationCount, 1)
        XCTAssertEqual(mapper.mapCount, 1)
        XCTAssertEqual(mapper.flushCount, 2)
        XCTAssertEqual(renderer.stopCount, 1)

        runtime.stop()
        XCTAssertEqual(runtime.snapshot().stopCount, 0)
        XCTAssertEqual(mapper.flushCount, 2)
        XCTAssertEqual(renderer.stopCount, 1)
    }

    func testConfigurationFailureFailsClosedBeforeMapping() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let mapper = try RecordingMetalVideoFrameMapper(device: device)
        let renderer = RecordingHDRMetalVideoRenderer(
            configurationError: .configurationFailure
        )
        let runtime = try makeRuntime(device: device, mapper: mapper, renderer: renderer)
        let frame = try makeFrame(
            generation: 22,
            frameID: 4,
            metadata: .rec709VideoRange()
        )
        let coordinates = try makeSnapshot(revision: 33)
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: coordinates
        )
        let target = try makeTarget(
            device: device,
            width: coordinates.drawableSize.width,
            height: coordinates.drawableSize.height
        )

        XCTAssertThrowsError(try runtime.present(
            frame: frame,
            plan: plan,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .asynchronous
        )) { error in
            XCTAssertEqual(error as? RecordingRendererError, .configurationFailure)
        }
        XCTAssertEqual(mapper.mapCount, 0)
        XCTAssertEqual(mapper.flushCount, 1)
        XCTAssertEqual(renderer.stopCount, 1)
        XCTAssertEqual(runtime.snapshot().failedPresentationCount, 1)
    }

    func testStopAndInvalidateReleaseOwnershipIdempotently() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let mapper = try RecordingMetalVideoFrameMapper(device: device)
        let renderer = RecordingHDRMetalVideoRenderer()
        let runtime = try makeRuntime(device: device, mapper: mapper, renderer: renderer)
        let frame = try makeFrame(
            generation: 23,
            frameID: 5,
            metadata: .rec709VideoRange()
        )
        let coordinates = try makeSnapshot(revision: 34)
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: coordinates
        )
        let target = try makeTarget(
            device: device,
            width: coordinates.drawableSize.width,
            height: coordinates.drawableSize.height
        )
        try runtime.present(
            frame: frame,
            plan: plan,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .asynchronous
        )

        runtime.stop()
        runtime.stop()
        var snapshot = runtime.snapshot()
        XCTAssertNil(snapshot.activeConfiguration)
        XCTAssertEqual(snapshot.stopCount, 1)
        XCTAssertFalse(snapshot.isInvalidated)

        runtime.invalidate()
        runtime.invalidate()
        snapshot = runtime.snapshot()
        XCTAssertTrue(snapshot.isInvalidated)
        XCTAssertEqual(snapshot.stopCount, 1)
        XCTAssertEqual(snapshot.invalidationCount, 1)
        XCTAssertEqual(renderer.stopCount, 1)
        XCTAssertEqual(mapper.flushCount, 2)
    }

    @MainActor
    func testConfigureReplacementAndStopInvalidateExactlyCurrentRuntime() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let firstRuntime = RecordingStreamMetalPresenterRuntime()
        let replacementRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimes = [firstRuntime, replacementRuntime]
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in runtimes.removeFirst() }
        )

        presenter.configure(view)
        XCTAssertEqual(view.colorPixelFormat, .bgra8Unorm_srgb)
        XCTAssertTrue(view.framebufferOnly)
        XCTAssertTrue((view.delegate as AnyObject?) === presenter)
        let layer = try XCTUnwrap(view.layer as? CAMetalLayer)
        XCTAssertEqual(layer.pixelFormat, .bgra8Unorm_srgb)
        XCTAssertEqual(layer.colorspace?.name, CGColorSpace.sRGB)
        XCTAssertFalse(layer.wantsExtendedDynamicRangeContent)
        XCTAssertNil(layer.edrMetadata)
        XCTAssertEqual(firstRuntime.snapshot().invalidationCount, 0)

        presenter.configure(view)
        XCTAssertEqual(firstRuntime.snapshot().invalidationCount, 1)
        XCTAssertEqual(replacementRuntime.snapshot().invalidationCount, 0)

        presenter.stop()
        presenter.stop()
        XCTAssertEqual(firstRuntime.snapshot().invalidationCount, 1)
        XCTAssertEqual(replacementRuntime.snapshot().invalidationCount, 1)
    }

    @MainActor
    func testFailedConfigureInvalidatesPreviousRuntimeWithoutLeavingStaleOwnership() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let runtime = RecordingStreamMetalPresenterRuntime()
        var shouldFail = false
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in
                if shouldFail { throw TestError.runtimeCreationFailed }
                return runtime
            }
        )

        presenter.configure(view)
        XCTAssertEqual(runtime.snapshot().invalidationCount, 0)

        shouldFail = true
        presenter.configure(view)
        XCTAssertEqual(runtime.snapshot().invalidationCount, 1)
        XCTAssertTrue((view.delegate as AnyObject?) === presenter)

        presenter.stop()
        XCTAssertEqual(runtime.snapshot().invalidationCount, 1)
    }

    @MainActor
    func testSurfaceFailureInvalidatesRuntimeAndDetachesPresenter() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let runtime = RecordingStreamMetalPresenterRuntime()
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        var runtimeCreationCount = 0
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in
                runtimeCreationCount += 1
                return runtime
            },
            surfaceAdapterFactory: { _ in surfaceAdapter }
        )

        presenter.configure(view)
        XCTAssertEqual(runtimeCreationCount, 1)
        XCTAssertTrue((view.delegate as AnyObject?) === presenter)
        XCTAssertEqual(runtime.snapshot().invalidationCount, 0)

        surfaceAdapter.failure = .mutationFailed(.outputColorSpace(.sRGB))
        presenter.configure(view)

        XCTAssertEqual(runtimeCreationCount, 1)
        XCTAssertEqual(runtime.snapshot().invalidationCount, 1)
        XCTAssertNil(view.delegate)
        XCTAssertTrue(view.isPaused)
    }

    func testResolvedPlanUsesActiveDisplayRevisionAndEDRLuminanceMapping() throws {
        let frame = try makeFrame(
            generation: 30,
            frameID: 10,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 41,
            currentHeadroom: 2.5
        )
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            resolvedConfiguration: resolved
        )

        XCTAssertEqual(plan.configuration, resolved.identity)
        XCTAssertEqual(plan.configuration.displayRevision.rawValue, 41)
        XCTAssertEqual(plan.configuration.mappingMode, .hdrEDR)
        XCTAssertEqual(plan.uniforms.mappingMode, 1)
        XCTAssertEqual(plan.uniforms.currentHeadroom, 2.5)

        let stale = try makeFrame(
            generation: 29,
            frameID: 11,
            metadata: .hdr10VideoRange()
        )
        XCTAssertThrowsError(try StreamMetalPresentationPlanResolver.resolve(
            frame: stale,
            resolvedConfiguration: resolved
        )) { error in
            XCTAssertEqual(
                error as? HDRRenderResolutionError,
                .staleDecoderGeneration(expected: 30, actual: 29)
            )
        }
    }

    @MainActor
    func testResolvedTransitionInvalidatesOldRuntimeAndPublishesNewOwnership() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        let replacementRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimes = [initialRuntime, replacementRuntime]
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        var diagnosticStates: [HDRPresentationDiagnosticState] = []
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in runtimes.removeFirst() },
            surfaceAdapterFactory: { _ in surfaceAdapter },
            diagnosticHandler: { diagnosticStates.append($0) }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 31,
            frameID: 12,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 42,
            currentHeadroom: 3,
            appliedSurfaceContract: try makeSDRSurface()
        )

        let outcome = presenter.transition(.resolved(resolved), on: view)

        XCTAssertEqual(outcome, .applied(
            previous: nil,
            current: resolved.identity
        ))
        XCTAssertEqual(initialRuntime.invalidationCount, 1)
        XCTAssertEqual(replacementRuntime.invalidationCount, 0)
        XCTAssertEqual(surfaceAdapter.contracts, [
            try makeSDRSurface(),
            resolved.identity.surfaceContract
        ])
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: resolved.identity,
            appliedSurfaceContract: resolved.identity.surfaceContract,
            requiresClearBeforePresentation: true,
            configurationTransitionCount: 1,
            closedTransitionCount: 0
        ))
        XCTAssertEqual(diagnosticStates, [.activeEDR])
    }

    @MainActor
    func testReplacementDiagnosticLeaseRejectsOldPresenterStopAndLateFailure() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let oldView = MTKView(frame: .zero, device: device)
        let replacementView = MTKView(frame: .zero, device: device)
        var activeOwner: UUID?
        var acceptedStates: [HDRPresentationDiagnosticState] = []
        let lease = HDRPresentationDiagnosticLease(
            claim: { activeOwner = $0 },
            publish: { ownerID, state in
                guard activeOwner == ownerID else { return }
                acceptedStates.append(state)
            },
            release: { ownerID in
                guard activeOwner == ownerID else { return }
                activeOwner = nil
            }
        )
        var oldRuntimes: [any StreamMetalPresenterRuntiming] = [
            RecordingStreamMetalPresenterRuntime(),
            RecordingStreamMetalPresenterRuntime()
        ]
        let oldPresenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in oldRuntimes.removeFirst() },
            surfaceAdapterFactory: { _ in RecordingPresenterSurfaceAdapter() },
            diagnosticLease: lease
        )
        oldPresenter.configure(oldView)
        let oldFrame = try makeFrame(
            generation: 70,
            frameID: 1,
            metadata: .hdr10VideoRange()
        )
        let oldConfiguration = try makeResolvedConfiguration(
            for: oldFrame,
            displayRevision: 60,
            currentHeadroom: 2
        )
        _ = oldPresenter.transition(.resolved(oldConfiguration), on: oldView)
        XCTAssertEqual(acceptedStates, [.activeEDR])

        var replacementRuntimes: [any StreamMetalPresenterRuntiming] = [
            RecordingStreamMetalPresenterRuntime(),
            RecordingStreamMetalPresenterRuntime()
        ]
        let replacementPresenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in replacementRuntimes.removeFirst() },
            surfaceAdapterFactory: { _ in RecordingPresenterSurfaceAdapter() },
            diagnosticLease: lease
        )
        replacementPresenter.configure(replacementView)
        let replacementFrame = try makeFrame(
            generation: 71,
            frameID: 2,
            metadata: .rec709VideoRange()
        )
        let replacementConfiguration = try makeResolvedConfiguration(
            for: replacementFrame,
            displayRevision: 61,
            currentHeadroom: 2
        )
        _ = replacementPresenter.transition(
            .resolved(replacementConfiguration),
            on: replacementView
        )
        XCTAssertEqual(acceptedStates, [.activeEDR, .activeSDR])

        _ = oldPresenter.transition(.closed(.invalidSourceContract), on: oldView)
        oldPresenter.stop()
        XCTAssertEqual(acceptedStates, [.activeEDR, .activeSDR])

        replacementPresenter.stop()
        XCTAssertEqual(acceptedStates, [.activeEDR, .activeSDR, .inactive])
        XCTAssertNil(activeOwner)
    }

    @MainActor
    func testSurfaceReadinessChangeDoesNotRebuildMatchingPresentation() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        let replacementRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimeCreationCount = 0
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in
                runtimeCreationCount += 1
                return runtimeCreationCount == 1
                    ? initialRuntime
                    : replacementRuntime
            },
            surfaceAdapterFactory: { _ in surfaceAdapter }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 39,
            frameID: 20,
            metadata: .hdr10VideoRange()
        )
        let requiresApplication = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 50,
            currentHeadroom: 3,
            appliedSurfaceContract: try makeSDRSurface()
        )
        XCTAssertEqual(
            requiresApplication.surfaceState,
            .requiresApplication(previous: try makeSDRSurface())
        )
        XCTAssertEqual(
            presenter.transition(.resolved(requiresApplication), on: view),
            .applied(previous: nil, current: requiresApplication.identity)
        )
        let ready = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 50,
            currentHeadroom: 3,
            appliedSurfaceContract: requiresApplication.identity.surfaceContract
        )
        XCTAssertEqual(ready.surfaceState, .ready)
        XCTAssertNotEqual(requiresApplication, ready)
        let appliedContracts = surfaceAdapter.contracts

        let outcome = presenter.transition(.resolved(ready), on: view)

        XCTAssertEqual(outcome, .unchanged(ready.identity))
        XCTAssertEqual(runtimeCreationCount, 2)
        XCTAssertEqual(initialRuntime.invalidationCount, 1)
        XCTAssertEqual(replacementRuntime.invalidationCount, 0)
        XCTAssertEqual(surfaceAdapter.contracts, appliedContracts)
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: ready.identity,
            appliedSurfaceContract: ready.identity.surfaceContract,
            requiresClearBeforePresentation: true,
            configurationTransitionCount: 1,
            closedTransitionCount: 0
        ))
    }

    @MainActor
    func testClosedResolutionInvalidatesEDRRuntimeAndRestoresSDRSurface() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        let edrRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimes = [initialRuntime, edrRuntime]
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in runtimes.removeFirst() },
            surfaceAdapterFactory: { _ in surfaceAdapter }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 32,
            frameID: 13,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 43,
            currentHeadroom: 2
        )
        XCTAssertEqual(
            presenter.transition(.resolved(resolved), on: view),
            .applied(previous: nil, current: resolved.identity)
        )

        let outcome = presenter.transition(
            .closed(.invalidCurrentDisplayHeadroom),
            on: view
        )

        XCTAssertEqual(
            outcome,
            .closed(.resolutionClosed(.invalidCurrentDisplayHeadroom))
        )
        XCTAssertEqual(edrRuntime.invalidationCount, 1)
        XCTAssertEqual(surfaceAdapter.contracts, [
            try makeSDRSurface(),
            resolved.identity.surfaceContract,
            try makeSDRSurface()
        ])
        XCTAssertTrue(view.isPaused)
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: nil,
            appliedSurfaceContract: try makeSDRSurface(),
            requiresClearBeforePresentation: false,
            configurationTransitionCount: 1,
            closedTransitionCount: 1
        ))
    }

    @MainActor
    func testCoordinateRevisionClearsPresentationAndPipelineWithoutSurfaceChange() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        let activeRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimes = [initialRuntime, activeRuntime]
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        let renderState = StreamRenderState(transform: RenderTransform(
            sourceSize: PixelSize(width: 64, height: 64),
            drawableSize: PixelSize(width: 128, height: 96),
            mode: .fit
        ))
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: renderState,
            runtimeFactory: { _, _ in runtimes.removeFirst() },
            surfaceAdapterFactory: { _ in surfaceAdapter }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 60,
            frameID: 16,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 52,
            currentHeadroom: 2
        )
        renderState.hdrRenderResolution = .resolved(resolved)
        presenter.update(renderState: renderState)

        renderState.transform.drawableSize = PixelSize(width: 192, height: 108)
        presenter.update(renderState: renderState)

        XCTAssertEqual(initialRuntime.invalidationCount, 1)
        XCTAssertEqual(activeRuntime.stopCount, 1)
        XCTAssertEqual(activeRuntime.invalidationCount, 0)
        XCTAssertEqual(surfaceAdapter.contracts, [
            try makeSDRSurface(),
            resolved.identity.surfaceContract
        ])
        XCTAssertEqual(
            presenter.snapshot().configurationTransitionCount,
            1
        )
        XCTAssertTrue(presenter.snapshot().requiresClearBeforePresentation)
    }

    @MainActor
    func testRuntimeCreationFailureRestoresPreviousSurfaceAndDetaches() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        var shouldFail = false
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        var diagnosticStates: [HDRPresentationDiagnosticState] = []
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in
                if shouldFail { throw TestError.runtimeCreationFailed }
                return initialRuntime
            },
            surfaceAdapterFactory: { _ in surfaceAdapter },
            diagnosticHandler: { diagnosticStates.append($0) }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 33,
            frameID: 14,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 44,
            currentHeadroom: 2
        )
        shouldFail = true

        let outcome = presenter.transition(.resolved(resolved), on: view)

        XCTAssertEqual(outcome, .closed(.runtimeCreationFailed))
        XCTAssertEqual(initialRuntime.invalidationCount, 1)
        XCTAssertEqual(surfaceAdapter.contracts, [
            try makeSDRSurface(),
            resolved.identity.surfaceContract,
            try makeSDRSurface()
        ])
        XCTAssertNil(view.delegate)
        XCTAssertTrue(view.isPaused)
        XCTAssertNil(presenter.snapshot().activeConfiguration)
        XCTAssertEqual(diagnosticStates, [.pipelineFailure])
    }

    @MainActor
    func testClosedResolutionCanRecoverWithReplacementRuntimeAndSurface() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        let edrRuntime = RecordingStreamMetalPresenterRuntime()
        let recoveredRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimes = [initialRuntime, edrRuntime, recoveredRuntime]
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        var diagnosticStates: [HDRPresentationDiagnosticState] = []
        let renderState = StreamRenderState()
        renderState.policy = .active
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: renderState,
            runtimeFactory: { _, _ in runtimes.removeFirst() },
            surfaceAdapterFactory: { _ in surfaceAdapter },
            diagnosticHandler: { diagnosticStates.append($0) }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 34,
            frameID: 15,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 45,
            currentHeadroom: 2.5
        )
        XCTAssertEqual(
            presenter.transition(.resolved(resolved), on: view),
            .applied(previous: nil, current: resolved.identity)
        )
        XCTAssertEqual(
            presenter.transition(
                .closed(.invalidCurrentDisplayHeadroom),
                on: view
            ),
            .closed(.resolutionClosed(.invalidCurrentDisplayHeadroom))
        )

        let outcome = presenter.transition(.resolved(resolved), on: view)

        XCTAssertEqual(
            outcome,
            .applied(previous: nil, current: resolved.identity)
        )
        XCTAssertEqual(initialRuntime.invalidationCount, 1)
        XCTAssertEqual(edrRuntime.invalidationCount, 1)
        XCTAssertEqual(recoveredRuntime.invalidationCount, 0)
        XCTAssertEqual(surfaceAdapter.contracts, [
            try makeSDRSurface(),
            resolved.identity.surfaceContract,
            try makeSDRSurface(),
            resolved.identity.surfaceContract
        ])
        XCTAssertTrue((view.delegate as AnyObject?) === presenter)
        XCTAssertFalse(view.isPaused)
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: resolved.identity,
            appliedSurfaceContract: resolved.identity.surfaceContract,
            requiresClearBeforePresentation: true,
            configurationTransitionCount: 2,
            closedTransitionCount: 1
        ))
        XCTAssertEqual(
            diagnosticStates,
            [.activeEDR, .unsupportedOutput, .activeEDR]
        )
    }

    @MainActor
    func testStopFromEDRRestoresSDRAndIsIdempotent() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        let edrRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimes = [initialRuntime, edrRuntime]
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in runtimes.removeFirst() },
            surfaceAdapterFactory: { _ in surfaceAdapter }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 35,
            frameID: 16,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 46,
            currentHeadroom: 2
        )
        XCTAssertEqual(
            presenter.transition(.resolved(resolved), on: view),
            .applied(previous: nil, current: resolved.identity)
        )

        presenter.stop()
        presenter.stop()

        XCTAssertEqual(initialRuntime.invalidationCount, 1)
        XCTAssertEqual(edrRuntime.invalidationCount, 1)
        XCTAssertEqual(surfaceAdapter.contracts, [
            try makeSDRSurface(),
            resolved.identity.surfaceContract,
            try makeSDRSurface()
        ])
        XCTAssertTrue(view.isPaused)
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: nil,
            appliedSurfaceContract: try makeSDRSurface(),
            requiresClearBeforePresentation: false,
            configurationTransitionCount: 1,
            closedTransitionCount: 0
        ))
    }

    @MainActor
    func testStaleOldViewTransitionCannotMutateReplacementSurface() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let oldView = MTKView(frame: .zero, device: device)
        let replacementView = MTKView(frame: .zero, device: device)
        let initialRuntime = RecordingStreamMetalPresenterRuntime()
        let edrRuntime = RecordingStreamMetalPresenterRuntime()
        let replacementRuntime = RecordingStreamMetalPresenterRuntime()
        var runtimes = [initialRuntime, edrRuntime, replacementRuntime]
        let oldAdapter = RecordingPresenterSurfaceAdapter()
        let replacementAdapter = RecordingPresenterSurfaceAdapter()
        var adapters = [oldAdapter, replacementAdapter]
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in runtimes.removeFirst() },
            surfaceAdapterFactory: { _ in adapters.removeFirst() }
        )
        presenter.configure(oldView)
        let frame = try makeFrame(
            generation: 36,
            frameID: 17,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 47,
            currentHeadroom: 3
        )
        XCTAssertEqual(
            presenter.transition(.resolved(resolved), on: oldView),
            .applied(previous: nil, current: resolved.identity)
        )
        presenter.configure(replacementView)
        let oldContracts = oldAdapter.contracts
        let replacementContracts = replacementAdapter.contracts

        let outcome = presenter.transition(.resolved(resolved), on: oldView)

        XCTAssertEqual(outcome, .closed(.staleSurface))
        XCTAssertEqual(oldAdapter.contracts, oldContracts)
        XCTAssertEqual(replacementAdapter.contracts, replacementContracts)
        XCTAssertEqual(initialRuntime.invalidationCount, 1)
        XCTAssertEqual(edrRuntime.invalidationCount, 1)
        XCTAssertEqual(replacementRuntime.invalidationCount, 0)
        XCTAssertTrue((replacementView.delegate as AnyObject?) === presenter)
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: nil,
            appliedSurfaceContract: try makeSDRSurface(),
            requiresClearBeforePresentation: false,
            configurationTransitionCount: 1,
            closedTransitionCount: 1
        ))
    }

    @MainActor
    func testUnsupportedTransitionClosesWithoutClaimingSurfaceOwnership() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let runtime = RecordingStreamMetalPresenterRuntime()
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in runtime },
            surfaceAdapterFactory: { _ in surfaceAdapter }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 37,
            frameID: 18,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 48,
            currentHeadroom: 2
        )
        surfaceAdapter.unsupportedPlatform = .tvOS

        let outcome = presenter.transition(.resolved(resolved), on: view)

        XCTAssertEqual(outcome, .closed(.surfaceUnsupported(.tvOS)))
        XCTAssertEqual(runtime.invalidationCount, 1)
        XCTAssertEqual(surfaceAdapter.activeContract, try makeSDRSurface())
        XCTAssertEqual(surfaceAdapter.contracts, [try makeSDRSurface()])
        XCTAssertNil(view.delegate)
        XCTAssertTrue(view.isPaused)
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: nil,
            appliedSurfaceContract: nil,
            requiresClearBeforePresentation: false,
            configurationTransitionCount: 0,
            closedTransitionCount: 1
        ))
    }

    @MainActor
    func testSurfaceMutationFailureClosesWithoutClaimingRolledBackSurface() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let runtime = RecordingStreamMetalPresenterRuntime()
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        let presenter = StreamMetalPresenter(
            presentationSource: StreamVideoPresentationSource(),
            renderState: StreamRenderState(),
            runtimeFactory: { _, _ in runtime },
            surfaceAdapterFactory: { _ in surfaceAdapter }
        )
        presenter.configure(view)
        let frame = try makeFrame(
            generation: 38,
            frameID: 19,
            metadata: .hdr10VideoRange()
        )
        let resolved = try makeResolvedConfiguration(
            for: frame,
            displayRevision: 49,
            currentHeadroom: 2
        )
        surfaceAdapter.failure = .mutationFailed(
            .drawablePixelFormat(.rgba16Float)
        )

        let outcome = presenter.transition(.resolved(resolved), on: view)

        XCTAssertEqual(outcome, .closed(.surfaceApplicationFailed))
        XCTAssertEqual(runtime.invalidationCount, 1)
        XCTAssertEqual(surfaceAdapter.activeContract, try makeSDRSurface())
        XCTAssertEqual(surfaceAdapter.contracts, [try makeSDRSurface()])
        XCTAssertNil(view.delegate)
        XCTAssertTrue(view.isPaused)
        XCTAssertEqual(presenter.snapshot(), StreamMetalPresenterSnapshot(
            activeConfiguration: nil,
            appliedSurfaceContract: nil,
            requiresClearBeforePresentation: false,
            configurationTransitionCount: 0,
            closedTransitionCount: 1
        ))
    }

    @MainActor
    func testTVVisionPlatformAdmissionDoesNotReadSharedLatestFrame() throws {
        let source = StreamVideoPresentationSource()
        let ownership = try makeTVVisionPresentationOwnership()
        let sharedFrame = try makeFrame(
            generation: 7,
            frameID: 40,
            metadata: .rec709VideoRange()
        )
        source.beginSession(
            sessionID: ownership.sessionID,
            mediaGeneration: ownership.mediaGeneration
        )
        source.consume(
            .sessionStarted(
                generation: sharedFrame.generation,
                colorMetadata: sharedFrame.colorMetadata
            ),
            sessionID: ownership.sessionID,
            mediaGeneration: ownership.mediaGeneration
        )
        source.consume(
            .frame(sharedFrame),
            sessionID: ownership.sessionID,
            mediaGeneration: ownership.mediaGeneration
        )
        let harness = try makeTVVisionPresenterHarness(source: source)
        let owner = TVVisionMetalPresentationOwner()
        let surfaceGeneration = try makeTVVisionSurfaceGeneration(1)

        owner.bind(
            presenter: harness.presenter,
            surfaceGeneration: surfaceGeneration
        )
        harness.presenter.draw(in: harness.view)

        XCTAssertEqual(harness.runtime.presentedFrameIDs, [])
        XCTAssertEqual(harness.runtime.clearCount, 1)
        XCTAssertEqual(owner.snapshot().surfaceGeneration, surfaceGeneration)
        harness.presenter.stop()
    }

    @MainActor
    func testTVVisionOwnerPresentsCoordinatorFrameAndClearsSceneLoss()
        async throws
    {
        let source = StreamVideoPresentationSource()
        let harness = try makeTVVisionPresenterHarness(source: source)
        let owner = TVVisionMetalPresentationOwner()
        let ownership = try makeTVVisionPresentationOwnership()
        let surfaceGeneration = try makeTVVisionSurfaceGeneration(1)
        owner.bind(
            presenter: harness.presenter,
            surfaceGeneration: surfaceGeneration
        )
        harness.presenter.draw(in: harness.view)
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: owner
        )
        guard case .applied = await coordinator.activate(ownership) else {
            return XCTFail("Expected platform presentation activation")
        }
        guard case .applied = await coordinator.applyScene(
            try makeTVVisionSceneUpdate(
                ownership: ownership,
                surfaceGeneration: surfaceGeneration,
                sourceRevision: 1
            ),
            ownership: ownership
        ) else {
            return XCTFail("Expected the actual scene to apply")
        }
        let frame = try makeFrame(
            generation: 9,
            frameID: 41,
            metadata: .rec709VideoRange()
        )
        let delivery = makeTVVisionFrameDelivery(
            ownership: ownership,
            revision: 1,
            frame: frame
        )

        guard case let .applied(presented) = await coordinator.receiveVideo(
            delivery,
            ownership: ownership
        ) else {
            return XCTFail("Expected the decoded frame to apply")
        }
        harness.presenter.draw(in: harness.view)
        XCTAssertTrue(presented.video.isPresented)
        XCTAssertEqual(harness.runtime.presentedFrameIDs, [frame.frameID])
        XCTAssertEqual(owner.snapshot().frameID, frame.frameID)
        XCTAssertTrue(owner.snapshot().isSceneEligible)
        XCTAssertNil(owner.snapshot().isDisplayAvailable)

        guard case .applied = await coordinator.applyScene(
            try makeTVVisionSceneUpdate(
                ownership: ownership,
                surfaceGeneration: surfaceGeneration,
                sourceRevision: 2,
                attached: false
            ),
            ownership: ownership
        ) else {
            return XCTFail("Expected scene loss to apply")
        }
        harness.presenter.draw(in: harness.view)
        XCTAssertEqual(harness.runtime.clearCount, 2)
        XCTAssertNil(owner.snapshot().frameID)
        XCTAssertFalse(owner.snapshot().isSceneEligible)
        harness.presenter.stop()
    }

    @MainActor
    func testTVVisionOwnerRebindsOnlyMatchingSurfaceFrameAndRejectsStaleWork()
        async throws
    {
        let source = StreamVideoPresentationSource()
        let firstHarness = try makeTVVisionPresenterHarness(source: source)
        let replacementHarness = try makeTVVisionPresenterHarness(source: source)
        let owner = TVVisionMetalPresentationOwner()
        let ownership = try makeTVVisionPresentationOwnership()
        let firstSurface = try makeTVVisionSurfaceGeneration(1)
        let replacementSurface = try makeTVVisionSurfaceGeneration(2)
        owner.bind(
            presenter: firstHarness.presenter,
            surfaceGeneration: firstSurface
        )
        firstHarness.presenter.draw(in: firstHarness.view)
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: owner
        )
        _ = await coordinator.activate(ownership)
        _ = await coordinator.applyScene(
            try makeTVVisionSceneUpdate(
                ownership: ownership,
                surfaceGeneration: firstSurface,
                sourceRevision: 1
            ),
            ownership: ownership
        )
        let frame = try makeFrame(
            generation: 11,
            frameID: 42,
            metadata: .rec709VideoRange()
        )
        let delivery = makeTVVisionFrameDelivery(
            ownership: ownership,
            revision: 1,
            frame: frame
        )
        _ = await coordinator.receiveVideo(delivery, ownership: ownership)
        firstHarness.presenter.draw(in: firstHarness.view)
        XCTAssertEqual(firstHarness.runtime.presentedFrameIDs, [frame.frameID])

        owner.bind(
            presenter: replacementHarness.presenter,
            surfaceGeneration: replacementSurface
        )
        firstHarness.presenter.draw(in: firstHarness.view)
        replacementHarness.presenter.draw(in: replacementHarness.view)
        XCTAssertEqual(replacementHarness.runtime.presentedFrameIDs, [])
        let current = owner.snapshot()
        let nextSequence = try XCTUnwrap(current.sequence).addingReportingOverflow(1)
        XCTAssertFalse(nextSequence.overflow)
        let currentRevision = try XCTUnwrap(current.platformRevision)
        let nextRevisionValue = currentRevision.rawValue.addingReportingOverflow(1)
        XCTAssertFalse(nextRevisionValue.overflow)
        let nextRevision = try TVVisionSemanticRevision(
            rawValue: nextRevisionValue.partialValue
        )
        let replacementScene = try XCTUnwrap(
            makeTVVisionSceneUpdate(
                ownership: ownership,
                surfaceGeneration: replacementSurface,
                sourceRevision: 2
            ).binding?.sceneSurfaceSnapshot
        )
        try await owner.apply(TVVisionPlatformPresentationActionApplication(
            ownership: ownership,
            sequence: nextSequence.partialValue,
            effect: .scene(replacementScene)
        ))
        XCTAssertEqual(replacementHarness.runtime.presentedFrameIDs, [])

        let replacementVideo = TVVisionPlatformVideoPresentationApplication(
            ownership: ownership,
            sequence: nextSequence.partialValue,
            platformRevision: nextRevision,
            surfaceGeneration: replacementSurface,
            delivery: delivery
        )
        try await owner.apply(TVVisionPlatformPresentationActionApplication(
            ownership: ownership,
            sequence: nextSequence.partialValue,
            effect: .video(replacementVideo)
        ))
        replacementHarness.presenter.draw(in: replacementHarness.view)
        XCTAssertEqual(replacementHarness.runtime.presentedFrameIDs, [frame.frameID])
        XCTAssertEqual(
            owner.snapshot().admittedFrameSurfaceGeneration,
            replacementSurface
        )

        let staleSurfaceVideo = TVVisionPlatformVideoPresentationApplication(
            ownership: ownership,
            sequence: nextSequence.partialValue,
            platformRevision: nextRevision,
            surfaceGeneration: firstSurface,
            delivery: delivery
        )
        try await owner.apply(TVVisionPlatformPresentationActionApplication(
            ownership: ownership,
            sequence: nextSequence.partialValue,
            effect: .video(staleSurfaceVideo)
        ))
        XCTAssertEqual(replacementHarness.runtime.presentedFrameIDs, [frame.frameID])

        owner.unbind(
            presenter: firstHarness.presenter,
            surfaceGeneration: firstSurface
        )
        XCTAssertEqual(owner.snapshot().surfaceGeneration, replacementSurface)

        owner.unbind(
            presenter: replacementHarness.presenter,
            surfaceGeneration: replacementSurface
        )
        replacementHarness.presenter.draw(in: replacementHarness.view)
        XCTAssertNil(owner.snapshot().surfaceGeneration)
        owner.bind(
            presenter: replacementHarness.presenter,
            surfaceGeneration: replacementSurface
        )
        replacementHarness.presenter.draw(in: replacementHarness.view)
        XCTAssertEqual(
            replacementHarness.runtime.presentedFrameIDs,
            [frame.frameID, frame.frameID]
        )
        firstHarness.presenter.stop()
        replacementHarness.presenter.stop()
    }

    @MainActor
    func testTVVisionOwnerRejectsStaleFrameDimensionsAndUnavailableDisplay()
        async throws
    {
        let source = StreamVideoPresentationSource()
        let harness = try makeTVVisionPresenterHarness(source: source)
        let owner = TVVisionMetalPresentationOwner()
        let ownership = try makeTVVisionPresentationOwnership()
        let surfaceGeneration = try makeTVVisionSurfaceGeneration(1)
        owner.bind(
            presenter: harness.presenter,
            surfaceGeneration: surfaceGeneration
        )
        harness.presenter.draw(in: harness.view)
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: owner
        )
        _ = await coordinator.activate(ownership)
        _ = await coordinator.applyScene(
            try makeTVVisionSceneUpdate(
                ownership: ownership,
                surfaceGeneration: surfaceGeneration,
                sourceRevision: 1
            ),
            ownership: ownership
        )
        let currentFrame = try makeFrame(
            generation: 20,
            frameID: 50,
            metadata: .rec709VideoRange()
        )
        let currentDelivery = makeTVVisionFrameDelivery(
            ownership: ownership,
            revision: 1,
            frame: currentFrame
        )
        _ = await coordinator.receiveVideo(
            currentDelivery,
            ownership: ownership
        )
        harness.presenter.draw(in: harness.view)
        XCTAssertEqual(harness.runtime.presentedFrameIDs, [currentFrame.frameID])
        let current = owner.snapshot()
        let sequence = try XCTUnwrap(current.sequence)
        let revision = try XCTUnwrap(current.platformRevision)

        let stalePlatformFrame = try makeFrame(
            generation: 20,
            frameID: 51,
            metadata: .rec709VideoRange()
        )
        try await owner.apply(TVVisionPlatformPresentationActionApplication(
            ownership: ownership,
            sequence: sequence,
            effect: .video(TVVisionPlatformVideoPresentationApplication(
                ownership: ownership,
                sequence: sequence,
                platformRevision: try TVVisionSemanticRevision(rawValue: 1),
                surfaceGeneration: surfaceGeneration,
                delivery: makeTVVisionFrameDelivery(
                    ownership: ownership,
                    revision: 2,
                    frame: stalePlatformFrame
                )
            ))
        ))
        let inconsistentDeliveryFrame = try makeFrame(
            generation: 20,
            frameID: 49,
            metadata: .rec709VideoRange()
        )
        try await owner.apply(TVVisionPlatformPresentationActionApplication(
            ownership: ownership,
            sequence: sequence,
            effect: .video(TVVisionPlatformVideoPresentationApplication(
                ownership: ownership,
                sequence: sequence,
                platformRevision: try revision.advanced(),
                surfaceGeneration: surfaceGeneration,
                delivery: makeTVVisionFrameDelivery(
                    ownership: ownership,
                    revision: 1,
                    frame: inconsistentDeliveryFrame
                )
            ))
        ))
        let staleDecoderFrame = try makeFrame(
            generation: 19,
            frameID: 52,
            metadata: .rec709VideoRange()
        )
        try await owner.apply(TVVisionPlatformPresentationActionApplication(
            ownership: ownership,
            sequence: sequence,
            effect: .video(TVVisionPlatformVideoPresentationApplication(
                ownership: ownership,
                sequence: sequence,
                platformRevision: try revision.advanced(),
                surfaceGeneration: surfaceGeneration,
                delivery: makeTVVisionFrameDelivery(
                    ownership: ownership,
                    revision: 2,
                    frame: staleDecoderFrame
                )
            ))
        ))
        harness.presenter.draw(in: harness.view)
        XCTAssertEqual(
            harness.runtime.presentedFrameIDs,
            [currentFrame.frameID, currentFrame.frameID]
        )
        XCTAssertEqual(owner.snapshot().acceptedFrameCount, 1)

        let displayRevision = try revision.advanced()
        let unavailableDisplay = try TVVisionDisplaySnapshot(
            platform: ownership.platform,
            revision: displayRevision,
            displayGeneration: TVVisionGeneration(
                domain: .display,
                rawValue: 1
            ),
            isOutputAvailable: false,
            headroomSource: .unavailable,
            currentEDRHeadroom: nil,
            potentialEDRHeadroom: nil,
            layerCapability: .unavailable
        )
        try await owner.apply(TVVisionPlatformPresentationActionApplication(
            ownership: ownership,
            sequence: sequence,
            effect: .display(unavailableDisplay)
        ))
        let lateFrame = try makeFrame(
            generation: 20,
            frameID: 53,
            metadata: .rec709VideoRange()
        )
        try await owner.apply(TVVisionPlatformPresentationActionApplication(
            ownership: ownership,
            sequence: sequence,
            effect: .video(TVVisionPlatformVideoPresentationApplication(
                ownership: ownership,
                sequence: sequence,
                platformRevision: displayRevision,
                surfaceGeneration: surfaceGeneration,
                delivery: makeTVVisionFrameDelivery(
                    ownership: ownership,
                    revision: 3,
                    frame: lateFrame
                )
            ))
        ))
        harness.presenter.draw(in: harness.view)
        XCTAssertEqual(
            harness.runtime.presentedFrameIDs,
            [currentFrame.frameID, currentFrame.frameID]
        )
        XCTAssertEqual(owner.snapshot().isDisplayAvailable, false)
        harness.presenter.stop()
    }

    @MainActor
    func testTVVisionOwnershipReplacementMakesOldVideoAndTeardownInert()
        async throws
    {
        let source = StreamVideoPresentationSource()
        let harness = try makeTVVisionPresenterHarness(source: source)
        let owner = TVVisionMetalPresentationOwner()
        let surfaceGeneration = try makeTVVisionSurfaceGeneration(1)
        owner.bind(
            presenter: harness.presenter,
            surfaceGeneration: surfaceGeneration
        )
        harness.presenter.draw(in: harness.view)
        let oldOwnership = try makeTVVisionPresentationOwnership()
        let oldCoordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: owner
        )
        _ = await oldCoordinator.activate(oldOwnership)
        _ = await oldCoordinator.applyScene(
            try makeTVVisionSceneUpdate(
                ownership: oldOwnership,
                surfaceGeneration: surfaceGeneration,
                sourceRevision: 1
            ),
            ownership: oldOwnership
        )
        let oldFrame = try makeFrame(
            generation: 30,
            frameID: 60,
            metadata: .rec709VideoRange()
        )
        _ = await oldCoordinator.receiveVideo(
            makeTVVisionFrameDelivery(
                ownership: oldOwnership,
                revision: 1,
                frame: oldFrame
            ),
            ownership: oldOwnership
        )
        harness.presenter.draw(in: harness.view)

        let replacementOwnership = try makeTVVisionPresentationOwnership(
            mediaGeneration: 2,
            presentationGeneration: 2,
            inputGeneration: 2
        )
        let replacementCoordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: owner
        )
        _ = await replacementCoordinator.activate(replacementOwnership)
        harness.presenter.draw(in: harness.view)
        _ = await replacementCoordinator.applyScene(
            try makeTVVisionSceneUpdate(
                ownership: replacementOwnership,
                surfaceGeneration: surfaceGeneration,
                sourceRevision: 1
            ),
            ownership: replacementOwnership
        )
        let replacementFrame = try makeFrame(
            generation: 31,
            frameID: 61,
            metadata: .rec709VideoRange()
        )
        _ = await replacementCoordinator.receiveVideo(
            makeTVVisionFrameDelivery(
                ownership: replacementOwnership,
                revision: 1,
                frame: replacementFrame
            ),
            ownership: replacementOwnership
        )
        harness.presenter.draw(in: harness.view)
        XCTAssertEqual(
            harness.runtime.presentedFrameIDs,
            [oldFrame.frameID, replacementFrame.frameID]
        )
        let clearCount = harness.runtime.clearCount

        let lateOldFrame = try makeFrame(
            generation: 30,
            frameID: 62,
            metadata: .rec709VideoRange()
        )
        _ = await oldCoordinator.receiveVideo(
            makeTVVisionFrameDelivery(
                ownership: oldOwnership,
                revision: 2,
                frame: lateOldFrame
            ),
            ownership: oldOwnership
        )
        _ = await oldCoordinator.stop(
            ownership: oldOwnership,
            reason: .replacement
        )
        harness.presenter.draw(in: harness.view)

        XCTAssertEqual(
            harness.runtime.presentedFrameIDs,
            [oldFrame.frameID, replacementFrame.frameID, replacementFrame.frameID]
        )
        XCTAssertEqual(harness.runtime.clearCount, clearCount)
        XCTAssertEqual(owner.snapshot().ownership, replacementOwnership)
        XCTAssertEqual(owner.snapshot().frameID, replacementFrame.frameID)
        harness.presenter.stop()
    }

    @MainActor
    func testTVVisionOwnershipReplacementRequiresSameSessionAndNewerGeneration()
        async throws
    {
        let owner = TVVisionMetalPresentationOwner()
        let initialOwnership = try makeTVVisionPresentationOwnership()
        let initialCoordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: owner
        )
        _ = await initialCoordinator.activate(initialOwnership)
        XCTAssertEqual(owner.snapshot().ownership, initialOwnership)

        let foreignOwnership = try makeTVVisionPresentationOwnership(
            sessionID: UUID(
                uuidString: "00000000-0000-0000-0000-000000000442"
            )!,
            mediaGeneration: 2,
            presentationGeneration: 2,
            inputGeneration: 2
        )
        let foreignCoordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: owner
        )
        _ = await foreignCoordinator.activate(foreignOwnership)
        XCTAssertEqual(owner.snapshot().ownership, initialOwnership)

        let inputReplacement = try makeTVVisionPresentationOwnership(
            inputGeneration: 2
        )
        let replacementCoordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: owner
        )
        _ = await replacementCoordinator.activate(inputReplacement)
        XCTAssertEqual(owner.snapshot().ownership, inputReplacement)
    }

    private func makeResolvedConfiguration(
        for frame: DecodedVideoFrame,
        displayRevision: UInt64,
        currentHeadroom: Double,
        appliedSurfaceContract: HDRSurfaceContract? = nil
    ) throws -> HDRResolvedRenderConfiguration {
        let resolution = HDRRenderConfigurationResolver.resolve(
            HDRRenderConfigurationResolverInput(
                decodedLayout: HDRDecodedPixelBufferLayout(
                    pixelBuffer: frame.pixelBuffer
                ),
                colorMetadata: frame.colorMetadata,
                decoderGeneration: frame.generation,
                userAllowsHDR: true,
                platformCapabilities: HDRPlatformOutputCapabilities(
                    platform: .macOS,
                    headroomSource: .currentPotentialAndReference,
                    extendedRangeSurfaceSupport: .intentAndMetadata,
                    supportedEDRGamuts: [.displayP3, .ituR2020],
                    supportsSDRToneMapping: true
                ),
                displaySnapshot: HDRDisplaySnapshot(
                    revision: HDRDisplayRevision(rawValue: displayRevision),
                    displayID: "not-published",
                    headroom: DisplayHeadroom(
                        potential: max(currentHeadroom, 4),
                        current: currentHeadroom,
                        reference: 1
                    )
                ),
                isDisplayRevisionExhausted: false,
                drawableState: HDRDrawableState(
                    isAvailable: true,
                    appliedSurfaceContract: appliedSurfaceContract
                )
            )
        )
        guard let configuration = resolution.configuration else {
            throw TestError.configurationResolutionFailed
        }
        return configuration
    }

    private func makeSDRSurface() throws -> HDRSurfaceContract {
        try HDRSurfaceContract(
            drawablePixelFormat: .bgra8UnormSRGB,
            outputColorSpace: .sRGB,
            outputGamut: .sRGB,
            extendedRangeIntent: .disabled,
            metadataMode: .none
        )
    }

    private func makeFrame(
        generation: UInt64,
        frameID: UInt64,
        metadata: VideoColorMetadata
    ) throws -> DecodedVideoFrame {
        let format = metadata.isHDR
            ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        let bitDepth: VideoOutputBitDepth = metadata.isHDR ? .ten : .eight
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            64,
            64,
            format,
            VideoToolboxDecompressionSessionFactory
                .destinationAttributes(for: bitDepth) as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw TestError.pixelBufferCreationFailed(status)
        }
        return DecodedVideoFrame(
            generation: generation,
            frameID: frameID,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: .invalid,
            duration: .invalid,
            infoFlags: [],
            colorMetadata: metadata
        )
    }

    @MainActor
    private func makeTVVisionPresenterHarness(
        source: StreamVideoPresentationSource
    ) throws -> (
        presenter: StreamMetalPresenter,
        runtime: RecordingStreamMetalPresenterRuntime,
        view: MTKView
    ) {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(
            frame: CGRect(x: 0, y: 0, width: 64, height: 64),
            device: device
        )
        let drawableLayer = CAMetalLayer()
        drawableLayer.device = device
        drawableLayer.pixelFormat = .bgra8Unorm_srgb
        drawableLayer.drawableSize = CGSize(width: 64, height: 64)
        let drawable = try XCTUnwrap(drawableLayer.nextDrawable())
        let renderState = StreamRenderState(transform: RenderTransform(
            sourceSize: PixelSize(width: 64, height: 64),
            drawableSize: PixelSize(width: 64, height: 64),
            mode: .fit
        ))
        renderState.policy = .active
        let runtime = RecordingStreamMetalPresenterRuntime()
        let presenter = StreamMetalPresenter(
            presentationSource: source,
            renderState: renderState,
            runtimeFactory: { _, _ in runtime },
            surfaceAdapterFactory: { _ in RecordingPresenterSurfaceAdapter() },
            drawableProvider: { _ in drawable }
        )
        presenter.configure(view)
        return (presenter, runtime, view)
    }

    private func makeTVVisionPresentationOwnership(
        sessionID: UUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000441"
        )!,
        mediaGeneration: UInt64 = 1,
        presentationGeneration: UInt64 = 1,
        inputGeneration: UInt64 = 1
    ) throws -> TVVisionPresentationOwnership {
        try TVVisionPresentationOwnership(
            platform: .tvOS,
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            presentationGeneration: TVVisionGeneration(
                domain: .presentation,
                rawValue: presentationGeneration
            ),
            inputGeneration: TVVisionGeneration(
                domain: .input,
                rawValue: inputGeneration
            )
        )
    }

    private func makeTVVisionSurfaceGeneration(
        _ rawValue: UInt64
    ) throws -> TVVisionGeneration {
        try TVVisionGeneration(domain: .surface, rawValue: rawValue)
    }

    private func makeTVVisionSceneUpdate(
        ownership: TVVisionPresentationOwnership,
        surfaceGeneration: TVVisionGeneration,
        sourceRevision: UInt64,
        attached: Bool = true
    ) throws -> TVVisionStreamGeometryBindingUpdate {
        let revision = try TVVisionSemanticRevision(rawValue: sourceRevision)
        guard attached else {
            return TVVisionStreamGeometryBindingUpdate(
                platform: ownership.platform,
                surfaceGeneration: surfaceGeneration,
                revision: revision,
                status: .closed(.detached),
                binding: nil
            )
        }
        let geometry = try TVVisionSurfaceGeometry(
            platform: ownership.platform,
            surfaceGeneration: surfaceGeneration,
            viewBounds: TVVisionRect(x: 0, y: 0, width: 64, height: 64),
            windowBounds: TVVisionRect(x: 0, y: 0, width: 64, height: 64),
            safeAreaInsets: .zero,
            scale: 1
        )
        let scene = try TVVisionSceneSurfaceSnapshot(
            platform: ownership.platform,
            revision: revision,
            surfaceGeneration: surfaceGeneration,
            activity: .active,
            attachment: .attached,
            isVisible: true,
            geometry: geometry
        )
        let sourceSize = PixelSize(width: 64, height: 64)
        let coordinates = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: revision.rawValue,
            sourceSize: sourceSize,
            drawableSize: geometry.drawableSize,
            mode: .fit
        ))
        return TVVisionStreamGeometryBindingUpdate(
            platform: ownership.platform,
            surfaceGeneration: surfaceGeneration,
            revision: revision,
            status: .active,
            binding: TVVisionStreamGeometryBindingSnapshot(
                platform: ownership.platform,
                surfaceGeneration: surfaceGeneration,
                revision: revision,
                sceneSurfaceSnapshot: scene,
                isFocusEligible: true,
                coordinateSnapshot: coordinates,
                inputReferenceSize: sourceSize
            )
        )
    }

    private func makeTVVisionFrameDelivery(
        ownership: TVVisionPresentationOwnership,
        revision: UInt64,
        frame: DecodedVideoFrame
    ) -> StreamVideoPresentationDelivery {
        .decodedFrame(
            ownership: StreamVideoPresentationDeliveryOwnership(
                sessionID: ownership.sessionID,
                mediaGeneration: ownership.mediaGeneration,
                revision: revision
            ),
            frame: frame
        )
    }

    private func makeSnapshot(revision: UInt64) throws -> StreamCoordinateSnapshot {
        guard let snapshot = StreamCoordinateSnapshot.resolve(
            revision: revision,
            sourceSize: PixelSize(width: 64, height: 64),
            drawableSize: PixelSize(width: 128, height: 96),
            mode: .fit
        ) else {
            throw TestError.coordinateResolutionFailed
        }
        return snapshot
    }

    private func fillSDRWhite(_ pixelBuffer: CVPixelBuffer) throws {
        guard CVPixelBufferLockBaseAddress(pixelBuffer, []) == kCVReturnSuccess else {
            throw TestError.pixelBufferLockFailed
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let luma = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
              let chroma = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
            throw TestError.pixelBufferPlaneMissing
        }
        memset(
            luma,
            235,
            CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
                * CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        )
        memset(
            chroma,
            128,
            CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
                * CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        )
    }

    private func makeTarget(
        device: any MTLDevice,
        width: Int,
        height: Int
    ) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw TestError.targetCreationFailed
        }
        return texture
    }

    private func makeRuntime(
        device: any MTLDevice,
        mapper: any MetalVideoFrameMapping,
        renderer: any HDRMetalVideoRendering
    ) throws -> StreamMetalPresenterRuntime {
        guard let commandQueue = device.makeCommandQueue() else {
            throw TestError.commandQueueCreationFailed
        }
        return StreamMetalPresenterRuntime(
            mapper: mapper,
            renderer: renderer,
            commandQueue: commandQueue
        )
    }

    private func readPixel(
        _ texture: any MTLTexture,
        x: Int,
        y: Int
    ) -> (blue: UInt8, green: UInt8, red: UInt8, alpha: UInt8) {
        var bytes = [UInt8](repeating: 0, count: 4)
        texture.getBytes(
            &bytes,
            bytesPerRow: 4,
            from: MTLRegionMake2D(x, y, 1, 1),
            mipmapLevel: 0
        )
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }

    private enum TestError: Error {
        case pixelBufferCreationFailed(CVReturn)
        case coordinateResolutionFailed
        case pixelBufferLockFailed
        case pixelBufferPlaneMissing
        case targetCreationFailed
        case commandQueueCreationFailed
        case runtimeCreationFailed
        case configurationResolutionFailed
    }
}

private typealias MobileSurfaceAttachmentTestOwner =
    MobileStreamSurfaceAttachmentOwner<
        MobileSurfaceAttachmentTestSurface,
        MobileSurfaceAttachmentTestWindow,
        MobileSurfaceAttachmentTestScene,
        MobileSurfaceAttachmentTestScreen
    >

private final class TVVisionSurfaceRelayTestScene {}

private final class TVVisionSurfaceRelayTestSurface {
    var isAttached: Bool
    var scene: TVVisionSurfaceRelayTestScene?
    var isVisible: Bool
    var scale: Double
    var drawableSize: CGSize
    var isFocusEligible: Bool

    init(
        isAttached: Bool = false,
        scene: TVVisionSurfaceRelayTestScene? = nil,
        isVisible: Bool = false,
        scale: Double = 0,
        drawableSize: CGSize = .zero,
        isFocusEligible: Bool = false
    ) {
        self.isAttached = isAttached
        self.scene = scene
        self.isVisible = isVisible
        self.scale = scale
        self.drawableSize = drawableSize
        self.isFocusEligible = isFocusEligible
    }
}

private func tvVisionSurfaceRelayTestState(
    _ surface: TVVisionSurfaceRelayTestSurface
) -> TVVisionUIKitStreamSurfaceState<TVVisionSurfaceRelayTestScene> {
    TVVisionUIKitStreamSurfaceState(
        isAttached: surface.isAttached,
        windowScene: surface.scene,
        isVisible: surface.isVisible,
        scale: surface.scale,
        drawableSize: surface.drawableSize,
        isFocusEligible: surface.isFocusEligible
    )
}

private typealias TVVisionSurfaceGenerationTestOwner =
    TVVisionUIKitStreamSurfaceGenerationOwner<
        TVVisionSurfaceGenerationTestSurface,
        TVVisionSurfaceGenerationTestWindow,
        TVVisionSurfaceGenerationTestScene,
        TVVisionSurfaceGenerationTestScreen
    >

private typealias TVVisionGeometryBindingTestOwner =
    TVVisionUIKitStreamGeometryBindingOwner<
        TVVisionSurfaceGenerationTestSurface,
        TVVisionSurfaceGenerationTestWindow,
        TVVisionSurfaceGenerationTestScene,
        TVVisionSurfaceGenerationTestScreen
    >

private final class TVVisionSurfaceGenerationTestSurface {
    var window: TVVisionSurfaceGenerationTestWindow?
    var isVisible: Bool
    var scale: Double
    var drawableSize: CGSize
    var isFocusEligible: Bool
    var geometryReading: TVVisionUIKitStreamSurfaceGeometryReading
    var appliedDrawableSizes: [PixelSize] = []
    var rejectsDrawableApplication = false

    init(
        window: TVVisionSurfaceGenerationTestWindow? = nil,
        isVisible: Bool = true,
        scale: Double = 2,
        drawableSize: CGSize = CGSize(width: 1920, height: 1080),
        isFocusEligible: Bool = true,
        geometryReading: TVVisionUIKitStreamSurfaceGeometryReading =
            TVVisionUIKitStreamSurfaceGeometryReading(
                viewBounds: TVVisionRect(
                    x: 0,
                    y: 0,
                    width: 400,
                    height: 300
                ),
                windowBounds: TVVisionRect(
                    x: 0,
                    y: 0,
                    width: 400,
                    height: 300
                ),
                safeAreaInsets: .zero,
                scale: 2
            )
    ) {
        self.window = window
        self.isVisible = isVisible
        self.scale = scale
        self.drawableSize = drawableSize
        self.isFocusEligible = isFocusEligible
        self.geometryReading = geometryReading
    }
}

private final class TVVisionSurfaceGenerationTestWindow {
    let scene: TVVisionSurfaceGenerationTestScene
    let screen: TVVisionSurfaceGenerationTestScreen?

    init(
        scene: TVVisionSurfaceGenerationTestScene,
        screen: TVVisionSurfaceGenerationTestScreen?
    ) {
        self.scene = scene
        self.screen = screen
    }
}

private final class TVVisionSurfaceGenerationTestScene {
    var activity: AppSceneActivity

    init(activity: AppSceneActivity) {
        self.activity = activity
    }
}

private final class TVVisionSurfaceGenerationTestScreen {}

private func tvVisionSurfaceGeneration(
    _ rawValue: UInt64
) throws -> TVVisionGeneration {
    try TVVisionGeneration(domain: .surface, rawValue: rawValue)
}

private func tvVisionSurfaceGenerationTestResolver(
    _ surface: TVVisionSurfaceGenerationTestSurface
) -> TVVisionSurfaceGenerationTestOwner.ResolvedAttachment? {
    guard let window = surface.window else { return nil }
    return TVVisionSurfaceGenerationTestOwner.ResolvedAttachment(
        window: window,
        windowScene: window.scene,
        screen: window.screen,
        activity: window.scene.activity
    )
}

private func tvVisionSurfaceGenerationTestRawState(
    _ surface: TVVisionSurfaceGenerationTestSurface
) -> TVVisionSurfaceGenerationTestOwner.RawState {
    let isAttached = surface.window != nil
    return TVVisionSurfaceGenerationTestOwner.RawState(
        isAttached: isAttached,
        windowScene: surface.window?.scene,
        isVisible: isAttached && surface.isVisible,
        scale: surface.scale,
        drawableSize: surface.drawableSize,
        isFocusEligible: isAttached
            && surface.isVisible
            && surface.isFocusEligible
    )
}

@MainActor
private func tvVisionGeometryBindingTestSurface(
    geometry: TVVisionUIKitStreamSurfaceGeometryReading =
        TVVisionUIKitStreamSurfaceGeometryReading(
            viewBounds: TVVisionRect(
                x: 0,
                y: 0,
                width: 400,
                height: 300
            ),
            windowBounds: TVVisionRect(
                x: 0,
                y: 0,
                width: 400,
                height: 300
            ),
            safeAreaInsets: .zero,
            scale: 2
        )
) -> TVVisionSurfaceGenerationTestSurface {
    TVVisionSurfaceGenerationTestSurface(
        window: TVVisionSurfaceGenerationTestWindow(
            scene: TVVisionSurfaceGenerationTestScene(activity: .active),
            screen: TVVisionSurfaceGenerationTestScreen()
        ),
        scale: geometry.scale,
        drawableSize: CGSize(
            width: geometry.viewBounds.width * geometry.scale,
            height: geometry.viewBounds.height * geometry.scale
        ),
        geometryReading: geometry
    )
}

@MainActor
private func tvVisionGeometryBindingTestOwner(
    platform: TVVisionPlatform,
    generation: TVVisionGeneration,
    surface: TVVisionSurfaceGenerationTestSurface,
    initialRevision: TVVisionSemanticRevision? = nil,
    handler: @escaping TVVisionGeometryBindingTestOwner.Handler
) throws -> TVVisionGeometryBindingTestOwner {
    try TVVisionGeometryBindingTestOwner(
        platform: platform,
        surfaceGeneration: generation,
        surface: surface,
        sourceSize: PixelSize(width: 1_920, height: 1_080),
        mode: .fit,
        initialRevision: initialRevision,
        geometryReader: { $0.geometryReading },
        drawableApplier: { surface, size in
            surface.appliedDrawableSizes.append(size)
            return !surface.rejectsDrawableApplication
        },
        handler: handler
    )
}

private func tvVisionGeometryBindingTestAttachedUpdate(
    platform: TVVisionPlatform,
    generation: TVVisionGeneration,
    surface: TVVisionSurfaceGenerationTestSurface,
    callback: TVVisionUIKitStreamSurfaceCallback = .attachment
) -> TVVisionSurfaceGenerationTestOwner.Update {
    let window = surface.window!
    let geometry = surface.geometryReading
    return TVVisionSurfaceGenerationTestOwner.Update(
        surfaceGeneration: generation,
        status: .attached,
        state: TVVisionUIKitStreamSurfaceGenerationState(
            platform: platform,
            surfaceGeneration: generation,
            callback: callback,
            attachment: .attached,
            activity: window.scene.activity,
            isVisible: surface.isVisible,
            scale: geometry.scale,
            drawableSize: PixelSize(
                width: Int(surface.drawableSize.width.rounded()),
                height: Int(surface.drawableSize.height.rounded())
            ),
            isFocusEligible: surface.isFocusEligible
                && window.scene.activity == .active
        ),
        surface: surface,
        attachment: TVVisionSurfaceGenerationTestOwner.ResolvedAttachment(
            window: window,
            windowScene: window.scene,
            screen: window.screen,
            activity: window.scene.activity
        )
    )
}

private func tvVisionGeometryBindingTestDetachedUpdate(
    platform: TVVisionPlatform,
    generation: TVVisionGeneration,
    surface: TVVisionSurfaceGenerationTestSurface,
    callback: TVVisionUIKitStreamSurfaceCallback = .attachment
) -> TVVisionSurfaceGenerationTestOwner.Update {
    TVVisionSurfaceGenerationTestOwner.Update(
        surfaceGeneration: generation,
        status: .detached,
        state: TVVisionUIKitStreamSurfaceGenerationState(
            platform: platform,
            surfaceGeneration: generation,
            callback: callback,
            attachment: .detached,
            activity: .background,
            isVisible: false,
            scale: nil,
            drawableSize: nil,
            isFocusEligible: false
        ),
        surface: surface,
        attachment: nil
    )
}

private typealias MobileSceneLifecycleTestObserver =
    MobileStreamSceneLifecycleObserver<MobileSceneLifecycleTestScene>

private typealias MobileSceneGeometryTestObserver =
    MobileStreamSceneGeometryObserver<
        MobileSceneGeometryTestSurface,
        MobileSceneGeometryTestWindow,
        MobileSceneGeometryTestScene,
        MobileSceneGeometryTestScreen
    >

private typealias MobileGeometryBindingTestOwner =
    MobileStreamGeometryBindingOwner<MobileGeometryBindingTestSurface>

private enum MobileDisplaySnapshotTestError: Error {
    case expectedPublishedSnapshot
}

private func publishedMobileDisplaySnapshot(
    _ outcome: MobileDisplayEDRPublicationOutcome
) throws -> MobileDisplayEDRSnapshot {
    guard case let .published(snapshot) = outcome else {
        throw MobileDisplaySnapshotTestError.expectedPublishedSnapshot
    }
    return snapshot
}

private final class MobileSurfaceAttachmentTestSurface {
    var window: MobileSurfaceAttachmentTestWindow?

    init(window: MobileSurfaceAttachmentTestWindow? = nil) {
        self.window = window
    }
}

private final class MobileSurfaceAttachmentTestWindow {
    let name: String
    let scene: MobileSurfaceAttachmentTestScene
    let screen: MobileSurfaceAttachmentTestScreen

    init(
        name: String,
        scene: MobileSurfaceAttachmentTestScene,
        screen: MobileSurfaceAttachmentTestScreen
    ) {
        self.name = name
        self.scene = scene
        self.screen = screen
    }
}

private final class MobileSurfaceAttachmentTestScene {
    let name: String

    init(name: String) {
        self.name = name
    }
}

private final class MobileSurfaceAttachmentTestScreen {
    let name: String

    init(name: String) {
        self.name = name
    }
}

private final class MobileSceneLifecycleTestScene: NSObject {
    var activity: AppSceneActivity

    init(activity: AppSceneActivity) {
        self.activity = activity
    }
}

private final class MobileSceneGeometryTestSurface {
    var reading = mobileSceneGeometryTestReading()
}

private final class MobileSceneGeometryTestWindow {}
private final class MobileSceneGeometryTestScene {}
private final class MobileSceneGeometryTestScreen {}

private final class MobileGeometryBindingTestSurface {
    var appliedDrawableSizes: [PixelSize] = []
    var rejectDrawableApplication = false
}

@MainActor
private func mobileSceneGeometryTestReader(
    _ surface: MobileSceneGeometryTestSurface,
    _: MobileSceneGeometryTestWindow,
    _: MobileSceneGeometryTestScene,
    _: MobileSceneGeometryTestScreen
) -> MobileStreamSceneGeometryReading {
    surface.reading
}

private func mobileSceneGeometryTestReading(
    width: Double = 1_024,
    height: Double = 768,
    safeAreaInsets: MobileSceneEdgeInsets = .zero,
    orientation: MobileInterfaceOrientation = .landscapeLeft,
    traits: MobileSceneTraits = MobileSceneTraits(
        horizontalSizeClass: .regular,
        verticalSizeClass: .regular,
        interfaceStyle: .dark
    )
) -> MobileStreamSceneGeometryReading {
    MobileStreamSceneGeometryReading(
        viewBounds: MobileSceneRect(
            x: 0,
            y: 0,
            width: width,
            height: height
        ),
        windowBounds: MobileSceneRect(
            x: 0,
            y: 0,
            width: width,
            height: height
        ),
        safeAreaInsets: safeAreaInsets,
        scale: 2,
        orientation: orientation,
        traits: traits
    )
}

private func mobileGeometryBindingTestSnapshot(
    generation: MobileSceneSurfaceGeneration,
    revision: UInt64,
    viewBounds: MobileSceneRect = MobileSceneRect(
        x: 0,
        y: 0,
        width: 400,
        height: 300
    ),
    scale: Double = 2,
    orientation: MobileInterfaceOrientation = .landscapeLeft,
    safeAreaInsets: MobileSceneEdgeInsets = .zero,
    traits: MobileSceneTraits = MobileSceneTraits(
        horizontalSizeClass: .regular,
        verticalSizeClass: .regular,
        interfaceStyle: .dark
    )
) -> MobileSceneWindowSnapshot {
    MobileSceneWindowSnapshot(
        surfaceGeneration: generation,
        revision: MobileSceneWindowRevision(rawValue: revision),
        state: .attached(
            activity: .active,
            display: MobileDisplayGeneration(rawValue: 1)!,
            geometry: MobileSceneWindowGeometry(
                viewBounds: viewBounds,
                windowBounds: viewBounds,
                safeAreaInsets: safeAreaInsets,
                scale: scale,
                drawableSize: PixelSize(
                    width: Int(viewBounds.width * scale),
                    height: Int(viewBounds.height * scale)
                ),
                orientation: orientation,
                traits: traits,
                resizePhase: .settled
            )
        )
    )
}

private func mobileSceneLifecycleTestNotificationNames()
    -> MobileStreamSceneLifecycleNotificationNames
{
    MobileStreamSceneLifecycleNotificationNames(
        didActivate: Notification.Name("test.mobile.scene.did-activate"),
        willDeactivate: Notification.Name(
            "test.mobile.scene.will-deactivate"
        ),
        didEnterBackground: Notification.Name(
            "test.mobile.scene.did-enter-background"
        ),
        willEnterForeground: Notification.Name(
            "test.mobile.scene.will-enter-foreground"
        )
    )
}

@MainActor
private func drainMobileSceneLifecycleNotificationTasks() async {
    await Task.yield()
    await Task.yield()
}

@MainActor
private func mobileSurfaceAttachmentTestResolver(
    _ surface: MobileSurfaceAttachmentTestSurface
) -> MobileSurfaceAttachmentTestOwner.ResolvedAttachment? {
    guard let window = surface.window else { return nil }
    return MobileSurfaceAttachmentTestOwner.ResolvedAttachment(
        window: window,
        scene: window.scene,
        screen: window.screen
    )
}

@MainActor
final class RecordingPresenterSurfaceAdapter: HDRSurfaceApplying {
    var failure: HDRSurfaceApplicationError?
    var unsupportedPlatform: AppleRenderingPlatform?
    private(set) var activeContract: HDRSurfaceContract?
    private(set) var contracts: [HDRSurfaceContract] = []

    func apply(_ contract: HDRSurfaceContract) throws -> HDRSurfaceApplicationOutcome {
        if let failure { throw failure }
        if let unsupportedPlatform,
           contract.extendedRangeIntent == .enabled {
            return .unsupported(
                platform: unsupportedPlatform,
                requested: contract
            )
        }
        guard activeContract != contract else {
            return .unchanged(contract)
        }
        let previous = activeContract
        activeContract = contract
        contracts.append(contract)
        return .applied(previous: previous, current: contract)
    }
}

private enum RecordingRendererError: Error, Equatable {
    case configurationFailure
    case pipelineFailure
}

private final class RecordingMetalVideoFrameMapper: MetalVideoFrameMapping,
    @unchecked Sendable {
    private let base: CVMetalVideoFrameMapper
    private let lock = NSLock()
    private var storedMapCount = 0
    private var storedFlushCount = 0

    var mapCount: Int { lock.withLock { storedMapCount } }
    var flushCount: Int { lock.withLock { storedFlushCount } }

    init(device: any MTLDevice) throws {
        base = try CVMetalVideoFrameMapper(device: device)
    }

    func map(_ frame: DecodedVideoFrame) throws -> MetalVideoFrame {
        lock.withLock { storedMapCount += 1 }
        return try base.map(frame)
    }

    func flush() {
        lock.withLock { storedFlushCount += 1 }
        base.flush()
    }
}

private final class RecordingHDRMetalVideoRenderer: HDRMetalVideoRendering,
    @unchecked Sendable {
    private let lock = NSLock()
    private let configurationError: RecordingRendererError?
    private let renderError: RecordingRendererError?
    private var storedConfigurations: [HDRRenderConfigurationIdentity] = []
    private var storedRenderCount = 0
    private var storedStopCount = 0

    var configurations: [HDRRenderConfigurationIdentity] {
        lock.withLock { storedConfigurations }
    }
    var renderCount: Int { lock.withLock { storedRenderCount } }
    var stopCount: Int { lock.withLock { storedStopCount } }

    init(
        configurationError: RecordingRendererError? = nil,
        renderError: RecordingRendererError? = nil
    ) {
        self.configurationError = configurationError
        self.renderError = renderError
    }

    func replaceConfiguration(_ configuration: HDRRenderConfigurationIdentity) throws {
        if let configurationError { throw configurationError }
        lock.withLock { storedConfigurations.append(configuration) }
    }

    func render(
        frame: MetalVideoFrame,
        configuration: HDRRenderConfigurationIdentity,
        uniforms: HDRMetalShaderUniforms,
        coordinateSnapshot: StreamCoordinateSnapshot,
        target: HDRMetalRenderTarget,
        completion: HDRMetalCommandCompletion
    ) throws -> HDRMetalVideoRendererResult {
        _ = uniforms
        _ = target
        _ = completion
        if let renderError { throw renderError }
        lock.withLock { storedRenderCount += 1 }
        return .submitted(
            frameID: frame.frameID,
            decoderGeneration: configuration.decoderGeneration,
            displayRevision: configuration.displayRevision,
            coordinateRevision: coordinateSnapshot.revision
        )
    }

    func stop() {
        lock.withLock { storedStopCount += 1 }
    }
}

final class RecordingStreamMetalPresenterRuntime:
    StreamMetalPresenterRuntiming, @unchecked Sendable {
    private let lock = NSLock()
    private var storedClearCount: UInt64 = 0
    private var storedStopCount: UInt64 = 0
    private var storedInvalidationCount: UInt64 = 0
    private var storedPresentedConfigurations: [HDRRenderConfigurationIdentity] = []
    private var storedPresentedFrameIDs: [UInt64] = []

    var clearCount: UInt64 { lock.withLock { storedClearCount } }
    var stopCount: UInt64 { lock.withLock { storedStopCount } }
    var invalidationCount: UInt64 { lock.withLock { storedInvalidationCount } }
    var presentCount: UInt64 {
        lock.withLock { UInt64(storedPresentedConfigurations.count) }
    }
    var presentedConfigurations: [HDRRenderConfigurationIdentity] {
        lock.withLock { storedPresentedConfigurations }
    }
    var presentedFrameIDs: [UInt64] {
        lock.withLock { storedPresentedFrameIDs }
    }

    func present(
        frame: DecodedVideoFrame,
        plan: StreamMetalPresentationPlan,
        coordinateSnapshot: StreamCoordinateSnapshot,
        target: HDRMetalRenderTarget,
        completion: HDRMetalCommandCompletion
    ) throws -> HDRMetalVideoRendererResult {
        _ = target
        _ = completion
        lock.withLock {
            storedPresentedConfigurations.append(plan.configuration)
            storedPresentedFrameIDs.append(frame.frameID)
        }
        return .submitted(
            frameID: frame.frameID,
            decoderGeneration: plan.configuration.decoderGeneration,
            displayRevision: plan.configuration.displayRevision,
            coordinateRevision: coordinateSnapshot.revision
        )
    }

    func clear(drawable: any CAMetalDrawable, color: MTLClearColor) throws {
        _ = drawable
        _ = color
        lock.withLock { storedClearCount &+= 1 }
    }

    func stop() {
        lock.withLock { storedStopCount &+= 1 }
    }

    func invalidate() {
        lock.withLock { storedInvalidationCount &+= 1 }
    }

    func snapshot() -> StreamMetalPresenterRuntimeSnapshot {
        lock.withLock {
            StreamMetalPresenterRuntimeSnapshot(
                activeConfiguration: nil,
                mappedFrameGeneration: nil,
                mappedFrameID: nil,
                isInvalidated: storedInvalidationCount > 0,
                submittedFrameCount: UInt64(storedPresentedConfigurations.count),
                failedPresentationCount: 0,
                stopCount: storedStopCount,
                invalidationCount: storedInvalidationCount
            )
        }
    }
}
