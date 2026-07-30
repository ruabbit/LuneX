import CoreVideo
import Foundation
@preconcurrency import Metal
import MetalKit
import XCTest

final class StreamMetalPresenterTests: XCTestCase {
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
            constrained.revision
        )
        XCTAssertEqual(
            geometryOwner.invalidate(
                surface: surface,
                surfaceGeneration: currentGeneration
            ),
            .invalidated
        )
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

    var clearCount: UInt64 { lock.withLock { storedClearCount } }
    var stopCount: UInt64 { lock.withLock { storedStopCount } }
    var invalidationCount: UInt64 { lock.withLock { storedInvalidationCount } }
    var presentCount: UInt64 {
        lock.withLock { UInt64(storedPresentedConfigurations.count) }
    }
    var presentedConfigurations: [HDRRenderConfigurationIdentity] {
        lock.withLock { storedPresentedConfigurations }
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
