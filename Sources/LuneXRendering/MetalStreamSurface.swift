import Foundation
import MetalKit
import SwiftUI

enum StreamMetalPresenterError: Error, Equatable, Sendable {
    case commandQueueUnavailable
    case clearCommandUnavailable
    case clearEncoderUnavailable
    case invalidatedRuntime
}

enum StreamMetalClearReason: Equatable, Sendable {
    case inactivePolicy
    case missingCoordinates
    case drawableMismatch
    case missingFrame
}

enum StreamMetalFrameDecision: Equatable, Sendable {
    case waitForDrawable
    case clear(StreamMetalClearReason)
    case present
}

enum StreamMetalFrameDecisionResolver {
    static func resolve(
        policy: RenderPolicy,
        hasDrawable: Bool,
        hasCoordinates: Bool,
        drawableMatchesCoordinates: Bool,
        hasFrame: Bool
    ) -> StreamMetalFrameDecision {
        guard policy == .active || policy.isThrottled else {
            return .clear(.inactivePolicy)
        }
        guard hasDrawable else { return .waitForDrawable }
        guard hasCoordinates else { return .clear(.missingCoordinates) }
        guard drawableMatchesCoordinates else { return .clear(.drawableMismatch) }
        guard hasFrame else { return .clear(.missingFrame) }
        return .present
    }
}

struct StreamMetalViewSchedule: Equatable, Sendable {
    let isPaused: Bool
    let preferredFramesPerSecond: Int
    let requestsImmediateDraw: Bool
}

enum StreamMetalViewScheduleResolver {
    static func resolve(_ policy: RenderPolicy) -> StreamMetalViewSchedule {
        switch policy {
        case .active:
            return StreamMetalViewSchedule(
                isPaused: false,
                preferredFramesPerSecond: 60,
                requestsImmediateDraw: false
            )
        case .throttled:
            return StreamMetalViewSchedule(
                isPaused: false,
                preferredFramesPerSecond: 15,
                requestsImmediateDraw: false
            )
        case .idle, .paused:
            return StreamMetalViewSchedule(
                isPaused: true,
                preferredFramesPerSecond: 60,
                requestsImmediateDraw: true
            )
        }
    }
}

enum MobileStreamSurfaceAttachmentEvent: CaseIterable, Equatable, Sendable {
    case didMoveToWindow
    case layoutSubviews
    case safeAreaInsetsDidChange
    case registeredTraitsChanged
}

enum TVVisionUIKitStreamSurfaceCallback: CaseIterable, Equatable, Sendable {
    case attachment
    case layout
    case windowScene
    case visibility
    case scale
    case drawable
    case focusEligibility
}

struct TVVisionUIKitStreamSurfaceState<WindowScene: AnyObject> {
    let isAttached: Bool
    let windowScene: WindowScene?
    let isVisible: Bool
    let scale: Double
    let drawableSize: CGSize
    let isFocusEligible: Bool
}

@MainActor
final class TVVisionUIKitStreamSurfaceRelay<
    Surface: AnyObject,
    WindowScene: AnyObject
> {
    typealias State = TVVisionUIKitStreamSurfaceState<WindowScene>
    typealias StateReader = @MainActor (Surface) -> State
    typealias Handler = @MainActor (
        Surface,
        TVVisionUIKitStreamSurfaceCallback,
        State
    ) -> Void

    private weak var surface: Surface?
    private var stateReader: StateReader?
    private var handler: Handler?
    private var isInvalidated = false

    init(
        surface: Surface,
        stateReader: @escaping StateReader,
        handler: @escaping Handler
    ) {
        self.surface = surface
        self.stateReader = stateReader
        self.handler = handler
    }

    func updateHandler(_ handler: @escaping Handler) {
        guard !isInvalidated else { return }
        self.handler = handler
    }

    func publish(_ callbacks: [TVVisionUIKitStreamSurfaceCallback]) {
        guard !isInvalidated,
              !callbacks.isEmpty,
              let surface,
              let stateReader else {
            return
        }
        let state = stateReader(surface)
        for callback in callbacks {
            handler?(surface, callback, state)
        }
    }

    func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        handler = nil
        stateReader = nil
        surface = nil
    }
}

@MainActor
final class MobileStreamSurfaceAttachmentRelay<Surface: AnyObject> {
    typealias Handler = @MainActor (
        Surface,
        MobileStreamSurfaceAttachmentEvent
    ) -> Void

    private weak var surface: Surface?
    private var handler: Handler?
    private var isInvalidated = false

    init(
        surface: Surface,
        handler: @escaping Handler
    ) {
        self.surface = surface
        self.handler = handler
    }

    func updateHandler(_ handler: @escaping Handler) {
        guard !isInvalidated else { return }
        self.handler = handler
    }

    func publish(_ event: MobileStreamSurfaceAttachmentEvent) {
        guard !isInvalidated, let surface else { return }
        handler?(surface, event)
    }

    func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        handler = nil
        surface = nil
    }
}

enum MobileStreamSurfaceAttachmentTransition: Equatable, Sendable {
    case callback(MobileStreamSurfaceAttachmentEvent)
    case invalidated
}

struct MobileStreamSurfaceResolvedAttachment<
    Window: AnyObject,
    Scene: AnyObject,
    Screen: AnyObject
> {
    let window: Window
    let scene: Scene
    let screen: Screen
}

struct MobileStreamSurfaceAttachmentUpdate<
    Surface: AnyObject,
    Window: AnyObject,
    Scene: AnyObject,
    Screen: AnyObject
> {
    let surfaceGeneration: MobileSceneSurfaceGeneration
    let transition: MobileStreamSurfaceAttachmentTransition
    let surface: Surface?
    let attachment:
        MobileStreamSurfaceResolvedAttachment<Window, Scene, Screen>?
}

enum MobileStreamSurfaceAttachmentOwnerOutcome: Equatable, Sendable {
    case attached
    case detached
    case staleSurfaceGeneration
    case staleSurface
    case invalidated
    case alreadyInvalidated
}

@MainActor
final class MobileStreamSurfaceAttachmentOwner<
    Surface: AnyObject,
    Window: AnyObject,
    Scene: AnyObject,
    Screen: AnyObject
> {
    typealias ResolvedAttachment =
        MobileStreamSurfaceResolvedAttachment<Window, Scene, Screen>
    typealias Update =
        MobileStreamSurfaceAttachmentUpdate<Surface, Window, Scene, Screen>
    typealias Resolver = @MainActor (Surface) -> ResolvedAttachment?
    typealias Handler = @MainActor (Update) -> Void

    let surfaceGeneration: MobileSceneSurfaceGeneration
    var currentSurface: Surface? { surface }
    var currentWindow: Window? { window }
    var currentScene: Scene? { scene }
    var currentScreen: Screen? { screen }

    private weak var surface: Surface?
    private weak var window: Window?
    private weak var scene: Scene?
    private weak var screen: Screen?
    private var resolver: Resolver?
    private var handler: Handler?
    private var isInvalidated = false

    init(
        surfaceGeneration: MobileSceneSurfaceGeneration,
        surface: Surface,
        resolver: @escaping Resolver,
        handler: @escaping Handler
    ) {
        self.surfaceGeneration = surfaceGeneration
        self.surface = surface
        self.resolver = resolver
        self.handler = handler
    }

    func updateHandler(_ handler: @escaping Handler) {
        guard !isInvalidated else { return }
        self.handler = handler
    }

    @discardableResult
    func handle(
        surface candidate: Surface,
        surfaceGeneration candidateGeneration: MobileSceneSurfaceGeneration,
        event: MobileStreamSurfaceAttachmentEvent
    ) -> MobileStreamSurfaceAttachmentOwnerOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        guard surface === candidate else { return .staleSurface }

        let attachment = resolver?(candidate)
        if let attachment {
            window = attachment.window
            scene = attachment.scene
            screen = attachment.screen
        } else {
            window = nil
            scene = nil
            screen = nil
        }
        handler?(
            Update(
                surfaceGeneration: surfaceGeneration,
                transition: .callback(event),
                surface: candidate,
                attachment: attachment
            )
        )
        return attachment == nil ? .detached : .attached
    }

    @discardableResult
    func invalidate(
        surface candidate: Surface? = nil,
        surfaceGeneration candidateGeneration: MobileSceneSurfaceGeneration
    ) -> MobileStreamSurfaceAttachmentOwnerOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        if let candidate, surface !== candidate { return .staleSurface }

        isInvalidated = true
        let update = Update(
            surfaceGeneration: surfaceGeneration,
            transition: .invalidated,
            surface: surface,
            attachment: nil
        )
        window = nil
        scene = nil
        screen = nil
        surface = nil
        resolver = nil
        let currentHandler = handler
        handler = nil
        currentHandler?(update)
        return .invalidated
    }
}

struct MobileStreamSceneLifecycleNotificationNames: Equatable, Sendable {
    let didActivate: Notification.Name
    let willDeactivate: Notification.Name
    let didEnterBackground: Notification.Name
    let willEnterForeground: Notification.Name
}

enum MobileStreamSceneLifecycleObservation: Equatable, Sendable {
    case attached(AppSceneActivity)
    case detached
    case invalidated
}

struct MobileStreamSceneLifecycleUpdate: Equatable, Sendable {
    let surfaceGeneration: MobileSceneSurfaceGeneration
    let observation: MobileStreamSceneLifecycleObservation
}

enum MobileStreamSceneLifecycleObserverOutcome: Equatable, Sendable {
    case published
    case unchanged
    case staleSurfaceGeneration
    case invalidated
    case alreadyInvalidated
}

private final class MobileStreamSceneLifecycleObserverTokens:
    @unchecked Sendable
{
    private let notificationCenter: NotificationCenter
    private var observers: [NSObjectProtocol] = []

    init(notificationCenter: NotificationCenter) {
        self.notificationCenter = notificationCenter
    }

    func replace(_ observers: [NSObjectProtocol]) {
        removeAll()
        self.observers = observers
    }

    func removeAll() {
        observers.forEach(notificationCenter.removeObserver)
        observers.removeAll()
    }

    deinit {
        removeAll()
    }
}

@MainActor
final class MobileStreamSceneLifecycleObserver<Scene: AnyObject> {
    typealias ActivityReader = @MainActor (Scene) -> AppSceneActivity
    typealias Handler = @MainActor (MobileStreamSceneLifecycleUpdate) -> Void

    let surfaceGeneration: MobileSceneSurfaceGeneration
    var currentScene: Scene? { scene }
    private(set) var currentObservation:
        MobileStreamSceneLifecycleObservation?

    private let notificationCenter: NotificationCenter
    private let observerTokens: MobileStreamSceneLifecycleObserverTokens
    private let names: MobileStreamSceneLifecycleNotificationNames
    private let activityReader: ActivityReader
    private weak var scene: Scene?
    private var observationID: UUID?
    private var handler: Handler?
    private var isInvalidated = false

    init(
        surfaceGeneration: MobileSceneSurfaceGeneration,
        notificationCenter: NotificationCenter,
        names: MobileStreamSceneLifecycleNotificationNames,
        activityReader: @escaping ActivityReader,
        handler: @escaping Handler
    ) {
        self.surfaceGeneration = surfaceGeneration
        self.notificationCenter = notificationCenter
        observerTokens = MobileStreamSceneLifecycleObserverTokens(
            notificationCenter: notificationCenter
        )
        self.names = names
        self.activityReader = activityReader
        self.handler = handler
    }

    func updateHandler(_ handler: @escaping Handler) {
        guard !isInvalidated else { return }
        self.handler = handler
    }

    @discardableResult
    func attach(
        to candidate: Scene,
        surfaceGeneration candidateGeneration: MobileSceneSurfaceGeneration
    ) -> MobileStreamSceneLifecycleObserverOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        if scene === candidate {
            return publish(.attached(activityReader(candidate)))
        }

        stopObserving()
        scene = candidate
        currentObservation = nil
        let nextObservationID = UUID()
        observationID = nextObservationID
        observerTokens.replace([
            observe(
                name: names.didActivate,
                object: candidate,
                observationID: nextObservationID,
                activity: .active
            ),
            observe(
                name: names.willDeactivate,
                object: candidate,
                observationID: nextObservationID,
                activity: .inactive
            ),
            observe(
                name: names.didEnterBackground,
                object: candidate,
                observationID: nextObservationID,
                activity: .background
            ),
            observe(
                name: names.willEnterForeground,
                object: candidate,
                observationID: nextObservationID,
                activity: .inactive
            )
        ])
        return publish(.attached(activityReader(candidate)))
    }

    @discardableResult
    func detach(
        surfaceGeneration candidateGeneration: MobileSceneSurfaceGeneration
    ) -> MobileStreamSceneLifecycleObserverOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        stopObserving()
        return publish(.detached)
    }

    @discardableResult
    func invalidate(
        surfaceGeneration candidateGeneration: MobileSceneSurfaceGeneration
    ) -> MobileStreamSceneLifecycleObserverOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        isInvalidated = true
        stopObserving()
        let outcome = publish(.invalidated)
        handler = nil
        return outcome == .published ? .invalidated : outcome
    }

    private func observe(
        name: Notification.Name,
        object: Scene,
        observationID: UUID,
        activity: AppSceneActivity
    ) -> NSObjectProtocol {
        notificationCenter.addObserver(
            forName: name,
            object: object,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.receive(
                    observationID: observationID,
                    activity: activity
                )
            }
        }
    }

    private func receive(
        observationID candidateObservationID: UUID,
        activity: AppSceneActivity
    ) {
        guard !isInvalidated,
              observationID == candidateObservationID,
              scene != nil else {
            return
        }
        _ = publish(.attached(activity))
    }

    private func stopObserving() {
        observerTokens.removeAll()
        observationID = nil
        scene = nil
    }

    private func publish(
        _ observation: MobileStreamSceneLifecycleObservation
    ) -> MobileStreamSceneLifecycleObserverOutcome {
        guard observation != currentObservation else { return .unchanged }
        currentObservation = observation
        handler?(
            MobileStreamSceneLifecycleUpdate(
                surfaceGeneration: surfaceGeneration,
                observation: observation
            )
        )
        return .published
    }
}

struct MobileStreamSceneGeometryReading: Equatable, Sendable {
    let viewBounds: MobileSceneRect
    let windowBounds: MobileSceneRect
    let safeAreaInsets: MobileSceneEdgeInsets
    let scale: Double
    let orientation: MobileInterfaceOrientation
    let traits: MobileSceneTraits
}

struct MobileStreamSceneGeometrySettleRequest: Equatable, Sendable {
    let surfaceGeneration: MobileSceneSurfaceGeneration
    let id: UUID
}

enum MobileStreamSceneGeometryObserverOutcome: Equatable, Sendable {
    case published
    case unchanged
    case staleSurfaceGeneration
    case staleSurface
    case staleSettleRequest
    case revisionExhausted
    case invalidated
    case alreadyInvalidated
}

@MainActor
final class MobileStreamSceneGeometryObserver<
    Surface: AnyObject,
    Window: AnyObject,
    Scene: AnyObject,
    Screen: AnyObject
> {
    typealias Reader = @MainActor (
        Surface,
        Window,
        Scene,
        Screen
    ) -> MobileStreamSceneGeometryReading
    typealias Handler = @MainActor (MobileSceneWindowSnapshot) -> Void
    typealias SettleRequestHandler = @MainActor (
        MobileStreamSceneGeometrySettleRequest?
    ) -> Void

    let surfaceGeneration: MobileSceneSurfaceGeneration
    var currentSurface: Surface? { surface }
    var currentWindow: Window? { window }
    var currentScene: Scene? { scene }
    var currentScreen: Screen? { screen }
    var currentSnapshot: MobileSceneWindowSnapshot? { publisher.snapshot }
    private(set) var currentSettleRequest:
        MobileStreamSceneGeometrySettleRequest?

    private weak var surface: Surface?
    private weak var window: Window?
    private weak var scene: Scene?
    private weak var screen: Screen?
    private var publisher: MobileSceneWindowSnapshotPublisher
    private var activity: AppSceneActivity = .background
    private var resizePhase: MobileSceneResizePhase = .settled
    private var displayGenerationRawValue: UInt64 = 0
    private var isDisplayGenerationExhausted = false
    private var hasReceivedAttachment = false
    private var reader: Reader?
    private var handler: Handler?
    private var settleRequestHandler: SettleRequestHandler?
    private var isInvalidated = false

    init(
        surfaceGeneration: MobileSceneSurfaceGeneration,
        surface: Surface,
        reader: @escaping Reader,
        handler: @escaping Handler,
        settleRequestHandler: @escaping SettleRequestHandler
    ) {
        self.surfaceGeneration = surfaceGeneration
        self.surface = surface
        publisher = MobileSceneWindowSnapshotPublisher(
            surfaceGeneration: surfaceGeneration
        )
        self.reader = reader
        self.handler = handler
        self.settleRequestHandler = settleRequestHandler
    }

    func updateHandler(_ handler: @escaping Handler) {
        guard !isInvalidated else { return }
        self.handler = handler
    }

    func updateSettleRequestHandler(
        _ handler: @escaping SettleRequestHandler
    ) {
        guard !isInvalidated else { return }
        settleRequestHandler = handler
    }

    @discardableResult
    func attach(
        surface candidateSurface: Surface,
        window candidateWindow: Window,
        scene candidateScene: Scene,
        screen candidateScreen: Screen,
        surfaceGeneration candidateGeneration: MobileSceneSurfaceGeneration,
        event: MobileStreamSurfaceAttachmentEvent
    ) -> MobileStreamSceneGeometryObserverOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        guard surface === candidateSurface else { return .staleSurface }

        if screen !== candidateScreen {
            advanceDisplayGeneration()
        }
        window = candidateWindow
        scene = candidateScene
        screen = candidateScreen
        hasReceivedAttachment = true

        switch event {
        case .didMoveToWindow:
            resizePhase = .settled
            cancelSettleRequest()
        case .layoutSubviews,
             .safeAreaInsetsDidChange,
             .registeredTraitsChanged:
            resizePhase = .resizing
            renewSettleRequest()
        }
        return publishAttached()
    }

    @discardableResult
    func updateActivity(
        _ activity: AppSceneActivity,
        surfaceGeneration candidateGeneration: MobileSceneSurfaceGeneration
    ) -> MobileStreamSceneGeometryObserverOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        self.activity = activity
        guard hasReceivedAttachment else { return .unchanged }
        guard window != nil, scene != nil, screen != nil else {
            return publish(.detached(activity: activity))
        }
        return publishAttached()
    }

    @discardableResult
    func settle(
        _ request: MobileStreamSceneGeometrySettleRequest
    ) -> MobileStreamSceneGeometryObserverOutcome {
        guard request.surfaceGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        guard request == currentSettleRequest else {
            return .staleSettleRequest
        }
        currentSettleRequest = nil
        resizePhase = .settled
        return publishAttached()
    }

    @discardableResult
    func detach(
        surface candidateSurface: Surface,
        surfaceGeneration candidateGeneration: MobileSceneSurfaceGeneration
    ) -> MobileStreamSceneGeometryObserverOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        guard surface === candidateSurface else { return .staleSurface }
        stopAttachment()
        hasReceivedAttachment = true
        return publish(.detached(activity: activity))
    }

    @discardableResult
    func invalidate(
        surface candidateSurface: Surface? = nil,
        surfaceGeneration candidateGeneration: MobileSceneSurfaceGeneration
    ) -> MobileStreamSceneGeometryObserverOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        if let candidateSurface, surface !== candidateSurface {
            return .staleSurface
        }

        isInvalidated = true
        stopAttachment()
        surface = nil
        reader = nil
        let outcome = publish(.detached(activity: activity))
        handler = nil
        settleRequestHandler = nil
        return outcome == .revisionExhausted ? outcome : .invalidated
    }

    private func publishAttached()
        -> MobileStreamSceneGeometryObserverOutcome
    {
        guard !isDisplayGenerationExhausted,
              displayGenerationRawValue > 0,
              let surface,
              let window,
              let scene,
              let screen,
              let reading = reader?(surface, window, scene, screen) else {
            return publish(.attached(MobileSceneWindowAttachedSample(
                activity: activity,
                displayGeneration: 0,
                viewBounds: MobileSceneRect(
                    x: 0,
                    y: 0,
                    width: 0,
                    height: 0
                ),
                windowBounds: MobileSceneRect(
                    x: 0,
                    y: 0,
                    width: 0,
                    height: 0
                ),
                safeAreaInsets: .zero,
                scale: 0,
                orientation: .unknown,
                traits: MobileSceneTraits(
                    horizontalSizeClass: .unspecified,
                    verticalSizeClass: .unspecified,
                    interfaceStyle: .unspecified
                ),
                resizePhase: resizePhase
            )))
        }
        return publish(.attached(MobileSceneWindowAttachedSample(
            activity: activity,
            displayGeneration: displayGenerationRawValue,
            viewBounds: reading.viewBounds,
            windowBounds: reading.windowBounds,
            safeAreaInsets: reading.safeAreaInsets,
            scale: reading.scale,
            orientation: reading.orientation,
            traits: reading.traits,
            resizePhase: resizePhase
        )))
    }

    private func publish(
        _ sample: MobileSceneWindowSample
    ) -> MobileStreamSceneGeometryObserverOutcome {
        switch publisher.update(sample) {
        case .unchanged:
            return .unchanged
        case let .published(snapshot):
            handler?(snapshot)
            return .published
        case .revisionExhausted:
            cancelSettleRequest()
            return .revisionExhausted
        }
    }

    private func advanceDisplayGeneration() {
        guard !isDisplayGenerationExhausted else { return }
        let next = displayGenerationRawValue.addingReportingOverflow(1)
        if next.overflow || next.partialValue == 0 {
            isDisplayGenerationExhausted = true
            displayGenerationRawValue = 0
        } else {
            displayGenerationRawValue = next.partialValue
        }
    }

    private func renewSettleRequest() {
        let request = MobileStreamSceneGeometrySettleRequest(
            surfaceGeneration: surfaceGeneration,
            id: UUID()
        )
        currentSettleRequest = request
        settleRequestHandler?(request)
    }

    private func cancelSettleRequest() {
        guard currentSettleRequest != nil else { return }
        currentSettleRequest = nil
        settleRequestHandler?(nil)
    }

    private func stopAttachment() {
        cancelSettleRequest()
        resizePhase = .settled
        window = nil
        scene = nil
        screen = nil
    }
}

struct MobileStreamGeometryBindingSnapshot: Equatable, Sendable {
    let surfaceGeneration: MobileSceneSurfaceGeneration
    let sceneWindowRevision: MobileSceneWindowRevision
    let geometry: MobileSceneWindowGeometry
    let coordinateSnapshot: StreamCoordinateSnapshot
}

enum MobileStreamGeometryBindingOutcome: Equatable, Sendable {
    case published
    case unchanged
    case closed
    case staleSurfaceGeneration
    case staleSurface
    case drawableApplicationFailed
    case invalidated
    case alreadyInvalidated
}

@MainActor
final class MobileStreamGeometryBindingOwner<Surface: AnyObject> {
    typealias DrawableApplier = @MainActor (Surface, PixelSize) -> Bool
    typealias Handler = @MainActor (
        MobileStreamGeometryBindingSnapshot?
    ) -> Void

    let surfaceGeneration: MobileSceneSurfaceGeneration
    var currentSurface: Surface? { surface }
    private(set) var currentBinding:
        MobileStreamGeometryBindingSnapshot?

    private weak var surface: Surface?
    private var sourceSize: PixelSize
    private var mode: RenderScaleMode
    private var sceneSnapshot: MobileSceneWindowSnapshot?
    private var coordinatePublisher = StreamCoordinateSnapshotPublisher()
    private var appliedDrawableSize: PixelSize?
    private var drawableApplier: DrawableApplier?
    private var handler: Handler?
    private var isInvalidated = false

    init(
        surfaceGeneration: MobileSceneSurfaceGeneration,
        surface: Surface,
        sourceSize: PixelSize,
        mode: RenderScaleMode,
        drawableApplier: @escaping DrawableApplier,
        handler: @escaping Handler
    ) {
        self.surfaceGeneration = surfaceGeneration
        self.surface = surface
        self.sourceSize = sourceSize
        self.mode = mode
        self.drawableApplier = drawableApplier
        self.handler = handler
    }

    func updateHandler(_ handler: @escaping Handler) {
        guard !isInvalidated else { return }
        self.handler = handler
    }

    @discardableResult
    func updateRenderInputs(
        sourceSize: PixelSize,
        mode: RenderScaleMode,
        surface candidateSurface: Surface,
        surfaceGeneration candidateGeneration: MobileSceneSurfaceGeneration
    ) -> MobileStreamGeometryBindingOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        guard surface === candidateSurface else { return .staleSurface }
        guard self.sourceSize != sourceSize || self.mode != mode else {
            return currentBinding == nil ? resolveBinding() : .unchanged
        }
        self.sourceSize = sourceSize
        self.mode = mode
        return resolveBinding()
    }

    @discardableResult
    func update(
        _ snapshot: MobileSceneWindowSnapshot,
        surface candidateSurface: Surface,
        surfaceGeneration candidateGeneration: MobileSceneSurfaceGeneration
    ) -> MobileStreamGeometryBindingOutcome {
        guard candidateGeneration == surfaceGeneration,
              snapshot.surfaceGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        guard surface === candidateSurface else { return .staleSurface }
        guard sceneSnapshot != snapshot else {
            return currentBinding == nil ? resolveBinding() : .unchanged
        }
        sceneSnapshot = snapshot
        return resolveBinding()
    }

    func touch(_ sample: TouchSample) -> InputAdapterOutput {
        guard sample.pressure.isFinite else {
            return droppedInput("Mobile touch pressure is invalid")
        }
        guard let localPoint = drawablePoint(from: sample.localPoint),
              let coordinateSnapshot = currentBinding?.coordinateSnapshot else {
            return droppedInput("Mobile geometry is unavailable")
        }
        return TouchInputAdapter(
            mapper: InputMapper(snapshot: coordinateSnapshot)
        ).touch(TouchSample(
            id: sample.id,
            phase: sample.phase,
            localPoint: localPoint,
            pressure: sample.pressure
        ))
    }

    func pointerHover(_ sample: PointerHoverSample) -> InputAdapterOutput {
        guard let localPoint = drawablePoint(from: sample.localPoint),
              let coordinateSnapshot = currentBinding?.coordinateSnapshot else {
            return droppedInput("Mobile geometry is unavailable")
        }
        return TouchInputAdapter(
            mapper: InputMapper(snapshot: coordinateSnapshot)
        ).pointerHover(PointerHoverSample(
            localPoint: localPoint,
            buttons: sample.buttons
        ))
    }

    @discardableResult
    func invalidate(
        surface candidateSurface: Surface? = nil,
        surfaceGeneration candidateGeneration: MobileSceneSurfaceGeneration
    ) -> MobileStreamGeometryBindingOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        if let candidateSurface, surface !== candidateSurface {
            return .staleSurface
        }
        isInvalidated = true
        _ = closeBinding()
        sceneSnapshot = nil
        surface = nil
        drawableApplier = nil
        handler = nil
        return .invalidated
    }

    private func resolveBinding() -> MobileStreamGeometryBindingOutcome {
        guard let sceneSnapshot,
              case let .attached(_, _, geometry) = sceneSnapshot.state else {
            return closeBinding()
        }
        guard let coordinateSnapshot = coordinatePublisher.update(
            sourceSize: sourceSize,
            drawableSize: geometry.drawableSize,
            mode: mode
        ) else {
            return closeBinding()
        }
        guard applyDrawableSize(geometry.drawableSize) else {
            _ = coordinatePublisher.update(
                sourceSize: sourceSize,
                drawableSize: .zero,
                mode: mode
            )
            let hadBinding = currentBinding != nil
            currentBinding = nil
            if hadBinding {
                handler?(nil)
            }
            return .drawableApplicationFailed
        }
        let next = MobileStreamGeometryBindingSnapshot(
            surfaceGeneration: surfaceGeneration,
            sceneWindowRevision: sceneSnapshot.revision,
            geometry: geometry,
            coordinateSnapshot: coordinateSnapshot
        )
        guard next != currentBinding else { return .unchanged }
        currentBinding = next
        handler?(next)
        return .published
    }

    private func closeBinding() -> MobileStreamGeometryBindingOutcome {
        _ = coordinatePublisher.update(
            sourceSize: sourceSize,
            drawableSize: .zero,
            mode: mode
        )
        let hadBinding = currentBinding != nil
        currentBinding = nil
        let applied = applyDrawableSize(.zero)
        if hadBinding {
            handler?(nil)
        }
        return applied ? (hadBinding ? .closed : .unchanged)
            : .drawableApplicationFailed
    }

    private func applyDrawableSize(_ size: PixelSize) -> Bool {
        guard appliedDrawableSize != size else { return true }
        guard let surface,
              drawableApplier?(surface, size) == true else {
            appliedDrawableSize = nil
            return false
        }
        appliedDrawableSize = size
        return true
    }

    private func drawablePoint(from point: RemotePoint) -> RemotePoint? {
        guard let geometry = currentBinding?.geometry,
              point.x.isFinite,
              point.y.isFinite,
              point.x >= geometry.viewBounds.x,
              point.y >= geometry.viewBounds.y,
              point.x <= geometry.viewBounds.x + geometry.viewBounds.width,
              point.y <= geometry.viewBounds.y + geometry.viewBounds.height else {
            return nil
        }
        let x = (point.x - geometry.viewBounds.x) * geometry.scale
        let y = (point.y - geometry.viewBounds.y) * geometry.scale
        guard x.isFinite, y.isFinite else { return nil }
        return RemotePoint(x: x, y: y)
    }

    private func droppedInput(_ reason: String) -> InputAdapterOutput {
        InputAdapterOutput(event: nil, policy: .drop(reason: reason))
    }
}

struct StreamMetalPresentationPlan: Sendable {
    let configuration: HDRRenderConfigurationIdentity
    let uniforms: HDRMetalShaderUniforms
}

enum StreamMetalConfigurationTransitionError: Error, Equatable, Sendable {
    case resolutionClosed(HDRRenderResolutionError)
    case staleSurface
    case surfaceApplicationFailed
    case surfaceUnsupported(AppleRenderingPlatform)
    case runtimeCreationFailed
}

enum StreamMetalConfigurationTransitionOutcome: Equatable, Sendable {
    case applied(
        previous: HDRRenderConfigurationIdentity?,
        current: HDRRenderConfigurationIdentity
    )
    case unchanged(HDRRenderConfigurationIdentity)
    case closed(StreamMetalConfigurationTransitionError)
}

struct StreamMetalPresenterSnapshot: Equatable, Sendable {
    let activeConfiguration: HDRRenderConfigurationIdentity?
    let appliedSurfaceContract: HDRSurfaceContract?
    let requiresClearBeforePresentation: Bool
    let configurationTransitionCount: UInt64
    let closedTransitionCount: UInt64
}

enum StreamMetalPresentationPlanResolver {
    static func resolve(
        frame: DecodedVideoFrame,
        coordinateSnapshot: StreamCoordinateSnapshot
    ) throws -> StreamMetalPresentationPlan {
        let frameContract = try HDRDecodedVideoContractValidator.validateForMetalMapping(
            pixelBuffer: frame.pixelBuffer,
            colorMetadata: frame.colorMetadata
        )
        guard frameContract.colorSignature == frame.renderBinding.colorSignature else {
            throw MetalFrameDeliveryError.incompatibleColorSignature
        }

        let mappingMode: HDRMappingMode = frame.colorMetadata.isHDR ? .hdrToSDR : .sdr
        let surface = try HDRSurfaceContract(
            drawablePixelFormat: .bgra8UnormSRGB,
            outputColorSpace: .sRGB,
            outputGamut: .sRGB,
            extendedRangeIntent: .disabled,
            metadataMode: .none
        )
        let configuration = try HDRRenderConfigurationIdentity(
            decoderGeneration: frame.generation,
            colorSignature: frame.renderBinding.colorSignature,
            displayRevision: HDRDisplayRevision(rawValue: coordinateSnapshot.revision),
            mappingMode: mappingMode,
            surfaceContract: surface
        )
        let luminanceMapping: HDRLuminanceMapping? = frame.colorMetadata.isHDR
            ? try HDRLuminanceMapping(
                sourcePeak: HDRSourcePeakResolver.resolve(frame.colorMetadata),
                currentHeadroom: 1
            )
            : nil
        return StreamMetalPresentationPlan(
            configuration: configuration,
            uniforms: try HDRMetalShaderUniforms(
                frameContract: frameContract,
                configuration: configuration,
                luminanceMapping: luminanceMapping
            )
        )
    }

    static func resolve(
        frame: DecodedVideoFrame,
        resolvedConfiguration: HDRResolvedRenderConfiguration
    ) throws -> StreamMetalPresentationPlan {
        let frameContract = try HDRDecodedVideoContractValidator.validateForMetalMapping(
            pixelBuffer: frame.pixelBuffer,
            colorMetadata: frame.colorMetadata
        )
        let expected = resolvedConfiguration.identity
        guard frame.generation == expected.decoderGeneration else {
            throw HDRRenderResolutionError.staleDecoderGeneration(
                expected: expected.decoderGeneration,
                actual: frame.generation
            )
        }
        guard frame.renderBinding.colorSignature == expected.colorSignature,
              frameContract.colorSignature == expected.colorSignature else {
            throw HDRRenderResolutionError.staleColorSignature
        }
        guard frameContract == resolvedConfiguration.frameContract else {
            throw HDRRenderResolutionError.incompatibleDecodedLayout
        }
        return StreamMetalPresentationPlan(
            configuration: expected,
            uniforms: try HDRMetalShaderUniforms(
                frameContract: frameContract,
                configuration: expected,
                luminanceMapping: resolvedConfiguration.luminanceMapping
            )
        )
    }
}

private struct StreamMetalMappedFrameIdentity: Equatable {
    let generation: UInt64
    let frameID: UInt64
    let colorSignature: HDRRenderColorSignature
    let pixelBuffer: ObjectIdentifier

    init(_ frame: DecodedVideoFrame) {
        generation = frame.generation
        frameID = frame.frameID
        colorSignature = frame.renderBinding.colorSignature
        pixelBuffer = ObjectIdentifier(frame.pixelBuffer)
    }
}

protocol HDRMetalVideoRendering: Sendable {
    func replaceConfiguration(_ configuration: HDRRenderConfigurationIdentity) throws
    func render(
        frame: MetalVideoFrame,
        configuration: HDRRenderConfigurationIdentity,
        uniforms: HDRMetalShaderUniforms,
        coordinateSnapshot: StreamCoordinateSnapshot,
        target: HDRMetalRenderTarget,
        completion: HDRMetalCommandCompletion
    ) throws -> HDRMetalVideoRendererResult
    func stop()
}

extension HDRMetalVideoRenderer: HDRMetalVideoRendering {}

struct StreamMetalPresenterRuntimeSnapshot: Equatable, Sendable {
    let activeConfiguration: HDRRenderConfigurationIdentity?
    let mappedFrameGeneration: UInt64?
    let mappedFrameID: UInt64?
    let isInvalidated: Bool
    let submittedFrameCount: UInt64
    let failedPresentationCount: UInt64
    let stopCount: UInt64
    let invalidationCount: UInt64
}

protocol StreamMetalPresenterRuntiming: AnyObject, Sendable {
    func present(
        frame: DecodedVideoFrame,
        plan: StreamMetalPresentationPlan,
        coordinateSnapshot: StreamCoordinateSnapshot,
        target: HDRMetalRenderTarget,
        completion: HDRMetalCommandCompletion
    ) throws -> HDRMetalVideoRendererResult
    func clear(drawable: any CAMetalDrawable, color: MTLClearColor) throws
    func stop()
    func invalidate()
    func snapshot() -> StreamMetalPresenterRuntimeSnapshot
}

final class StreamMetalPresenterRuntime: StreamMetalPresenterRuntiming,
    @unchecked Sendable {
    private let mapper: any MetalVideoFrameMapping
    private let renderer: any HDRMetalVideoRendering
    private let commandQueue: any MTLCommandQueue
    private let lock = NSLock()
    private var activeConfiguration: HDRRenderConfigurationIdentity?
    private var mappedFrame: MetalVideoFrame?
    private var mappedFrameIdentity: StreamMetalMappedFrameIdentity?
    private var ownsPresentationResources = false
    private var isInvalidated = false
    private var submittedFrameCount: UInt64 = 0
    private var failedPresentationCount: UInt64 = 0
    private var stopCount: UInt64 = 0
    private var invalidationCount: UInt64 = 0

    convenience init(device: any MTLDevice, bundle: Bundle) throws {
        guard let commandQueue = device.makeCommandQueue() else {
            throw StreamMetalPresenterError.commandQueueUnavailable
        }
        try self.init(
            mapper: CVMetalVideoFrameMapper(device: device),
            renderer: HDRMetalVideoRenderer(device: device, bundle: bundle),
            commandQueue: commandQueue
        )
    }

    init(
        mapper: any MetalVideoFrameMapping,
        renderer: any HDRMetalVideoRendering,
        commandQueue: any MTLCommandQueue
    ) {
        self.mapper = mapper
        self.renderer = renderer
        self.commandQueue = commandQueue
    }

    @discardableResult
    func present(
        frame: DecodedVideoFrame,
        plan: StreamMetalPresentationPlan,
        coordinateSnapshot: StreamCoordinateSnapshot,
        target: HDRMetalRenderTarget,
        completion: HDRMetalCommandCompletion = .asynchronous
    ) throws -> HDRMetalVideoRendererResult {
        try lock.withLock {
            guard !isInvalidated else {
                throw StreamMetalPresenterError.invalidatedRuntime
            }
            do {
                if activeConfiguration != plan.configuration {
                    ownsPresentationResources = true
                    try renderer.replaceConfiguration(plan.configuration)
                    mapper.flush()
                    mappedFrame = nil
                    mappedFrameIdentity = nil
                    activeConfiguration = plan.configuration
                }
                let identity = StreamMetalMappedFrameIdentity(frame)
                let metalFrame: MetalVideoFrame
                if mappedFrameIdentity == identity, let mappedFrame {
                    metalFrame = mappedFrame
                } else {
                    metalFrame = try mapper.map(frame)
                    mappedFrame = metalFrame
                    mappedFrameIdentity = identity
                }
                let result = try renderer.render(
                    frame: metalFrame,
                    configuration: plan.configuration,
                    uniforms: plan.uniforms,
                    coordinateSnapshot: coordinateSnapshot,
                    target: target,
                    completion: completion
                )
                submittedFrameCount &+= 1
                return result
            } catch {
                failedPresentationCount &+= 1
                releasePresentationLocked()
                throw error
            }
        }
    }

    func clear(drawable: any CAMetalDrawable, color: MTLClearColor) throws {
        try lock.withLock {
            guard !isInvalidated else {
                throw StreamMetalPresenterError.invalidatedRuntime
            }
            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                throw StreamMetalPresenterError.clearCommandUnavailable
            }
            let descriptor = MTLRenderPassDescriptor()
            descriptor.colorAttachments[0].texture = drawable.texture
            descriptor.colorAttachments[0].loadAction = .clear
            descriptor.colorAttachments[0].storeAction = .store
            descriptor.colorAttachments[0].clearColor = color
            guard let encoder = commandBuffer.makeRenderCommandEncoder(
                descriptor: descriptor
            ) else {
                throw StreamMetalPresenterError.clearEncoderUnavailable
            }
            encoder.endEncoding()
            commandBuffer.present(drawable)
            commandBuffer.commit()
        }
    }

    func stop() {
        lock.withLock {
            guard ownsPresentationResources else { return }
            stopCount &+= 1
            releasePresentationLocked()
        }
    }

    func invalidate() {
        lock.withLock {
            guard !isInvalidated else { return }
            isInvalidated = true
            invalidationCount &+= 1
            releasePresentationLocked()
        }
    }

    func snapshot() -> StreamMetalPresenterRuntimeSnapshot {
        lock.withLock {
            StreamMetalPresenterRuntimeSnapshot(
                activeConfiguration: activeConfiguration,
                mappedFrameGeneration: mappedFrameIdentity?.generation,
                mappedFrameID: mappedFrameIdentity?.frameID,
                isInvalidated: isInvalidated,
                submittedFrameCount: submittedFrameCount,
                failedPresentationCount: failedPresentationCount,
                stopCount: stopCount,
                invalidationCount: invalidationCount
            )
        }
    }

    private func releasePresentationLocked() {
        guard ownsPresentationResources else {
            activeConfiguration = nil
            mappedFrame = nil
            mappedFrameIdentity = nil
            return
        }
        renderer.stop()
        mapper.flush()
        ownsPresentationResources = false
        activeConfiguration = nil
        mappedFrame = nil
        mappedFrameIdentity = nil
    }
}

struct HDRPresentationDiagnosticLease {
    typealias ClaimHandler = @MainActor (UUID) -> Void
    typealias PublishHandler = @MainActor (
        UUID,
        HDRPresentationDiagnosticState
    ) -> Void
    typealias ReleaseHandler = @MainActor (UUID) -> Void

    let claim: ClaimHandler
    let publish: PublishHandler
    let release: ReleaseHandler

    static let unmanaged = HDRPresentationDiagnosticLease(
        claim: { _ in },
        publish: { _, _ in },
        release: { _ in }
    )
}

final class StreamMetalPresenter: NSObject, MTKViewDelegate {
    typealias RuntimeFactory = (any MTLDevice, Bundle) throws
        -> any StreamMetalPresenterRuntiming
    typealias SurfaceAdapterFactory = @MainActor (MTKView) -> any HDRSurfaceApplying
    typealias DrawableProvider = @MainActor (MTKView) -> (any CAMetalDrawable)?
    typealias DiagnosticHandler = @MainActor (HDRPresentationDiagnosticState) -> Void

    private let presentationSource: StreamVideoPresentationSource
    private let runtimeFactory: RuntimeFactory
    private let surfaceAdapterFactory: SurfaceAdapterFactory
    private let drawableProvider: DrawableProvider
    private let diagnosticHandler: DiagnosticHandler
    private let diagnosticLease: HDRPresentationDiagnosticLease
    private let diagnosticOwnerID = UUID()
    private let lock = NSLock()
    private var renderPolicy: RenderPolicy
    private var coordinateSnapshot: StreamCoordinateSnapshot?
    private var runtime: (any StreamMetalPresenterRuntiming)?
    private var surfaceAdapter: (any HDRSurfaceApplying)?
    private weak var surfaceView: MTKView?
    private var activeResolvedConfiguration: HDRResolvedRenderConfiguration?
    private var appliedSurfaceContract: HDRSurfaceContract?
    private var lastRequestedResolution: HDRRenderConfigurationResolution?
    private var requiresClearBeforePresentation = false
    private var presentationRevision: UInt64 = 0
    private var configurationTransitionCount: UInt64 = 0
    private var closedTransitionCount: UInt64 = 0
    private var ownsDiagnosticLease = false

    init(
        presentationSource: StreamVideoPresentationSource,
        renderState: StreamRenderState,
        runtimeFactory: @escaping RuntimeFactory = { device, bundle in
            try StreamMetalPresenterRuntime(device: device, bundle: bundle)
        },
        surfaceAdapterFactory: @escaping SurfaceAdapterFactory = { view in
            AppleMetalSurfaceAdapter(view: view)
        },
        drawableProvider: @escaping DrawableProvider = { view in
            view.currentDrawable
        },
        diagnosticHandler: @escaping DiagnosticHandler = { _ in },
        diagnosticLease: HDRPresentationDiagnosticLease = .unmanaged
    ) {
        self.presentationSource = presentationSource
        self.runtimeFactory = runtimeFactory
        self.surfaceAdapterFactory = surfaceAdapterFactory
        self.drawableProvider = drawableProvider
        self.diagnosticHandler = diagnosticHandler
        self.diagnosticLease = diagnosticLease
        renderPolicy = renderState.policy
        coordinateSnapshot = renderState.coordinateSnapshot
    }

    @MainActor
    func configure(_ view: MTKView) {
        if let previousView = surfaceView, previousView !== view {
            stop()
        }
        claimDiagnosticLease()
        guard let device = view.device else {
            publishDiagnostic(.pipelineFailure)
            return
        }
        let adapter: any HDRSurfaceApplying
        if surfaceView === view, let surfaceAdapter {
            adapter = surfaceAdapter
        } else {
            adapter = surfaceAdapterFactory(view)
        }
        let surface: HDRSurfaceContract
        do {
            surface = try HDRSurfaceContract(
                drawablePixelFormat: .bgra8UnormSRGB,
                outputColorSpace: .sRGB,
                outputGamut: .sRGB,
                extendedRangeIntent: .disabled,
                metadataMode: .none
            )
            let outcome = try adapter.apply(surface)
            guard outcome.activeContract == surface else {
                failSurfaceConfiguration(view)
                publishDiagnostic(.pipelineFailure)
                return
            }
        } catch {
            failSurfaceConfiguration(view)
            publishDiagnostic(.pipelineFailure)
            return
        }
        surfaceAdapter = adapter
        surfaceView = view
        let runtime: (any StreamMetalPresenterRuntiming)?
        do {
            runtime = try runtimeFactory(device, Bundle(for: StreamMetalPresenter.self))
        } catch {
            runtime = nil
            publishDiagnostic(.pipelineFailure)
        }
        let previousRuntime = withLock {
            let previous = self.runtime
            self.runtime = runtime
            activeResolvedConfiguration = nil
            appliedSurfaceContract = surface
            lastRequestedResolution = nil
            requiresClearBeforePresentation = false
            presentationRevision &+= 1
            return previous
        }
        previousRuntime?.invalidate()
        view.framebufferOnly = true
        view.delegate = self
    }

    @MainActor
    func update(renderState: StreamRenderState) {
        let update = withLock {
            let previousRevision = coordinateSnapshot?.revision
            renderPolicy = renderState.policy
            coordinateSnapshot = renderState.coordinateSnapshot
            let coordinateChanged = previousRevision != coordinateSnapshot?.revision
            let resolutionChanged =
                lastRequestedResolution != renderState.hdrRenderResolution
            if resolutionChanged {
                lastRequestedResolution = renderState.hdrRenderResolution
            }
            if coordinateChanged {
                requiresClearBeforePresentation = true
                presentationRevision &+= 1
            }
            return (
                coordinateChanged,
                resolutionChanged,
                runtime,
                renderState.hdrRenderResolution
            )
        }
        if update.0 {
            update.2?.stop()
        }
        if update.1, let view = surfaceView {
            _ = transition(update.3, on: view)
        }
        if StreamMetalViewScheduleResolver.resolve(renderState.policy).requestsImmediateDraw {
            surfaceView?.draw()
        }
    }

    @MainActor
    @discardableResult
    func transition(
        _ resolution: HDRRenderConfigurationResolution,
        on view: MTKView
    ) -> StreamMetalConfigurationTransitionOutcome {
        guard surfaceView === view, let adapter = surfaceAdapter else {
            return closeTransition(.staleSurface)
        }
        switch resolution {
        case let .closed(error):
            closeActivePresentation(on: view, adapter: adapter, restoreSDR: true)
            return closeTransition(.resolutionClosed(error))
        case let .resolved(configuration):
            let targetSurface = configuration.identity.surfaceContract
            let state = withLock {
                (
                    activeResolvedConfiguration,
                    appliedSurfaceContract,
                    runtime
                )
            }
            if let activeConfiguration = state.0,
               activeConfiguration.identity == configuration.identity,
               activeConfiguration.frameContract == configuration.frameContract,
               activeConfiguration.luminanceMapping == configuration.luminanceMapping,
               state.1 == targetSurface,
               state.2 != nil {
                withLock {
                    activeResolvedConfiguration = configuration
                }
                publishDiagnostic(.resolved(configuration))
                return .unchanged(configuration.identity)
            }

            let previousIdentity = state.0?.identity
            let previousSurface = state.1
            view.isPaused = true
            clearCurrentDrawable(on: view, runtime: state.2)
            deactivateRuntimeForTransition()

            let surfaceOutcome: HDRSurfaceApplicationOutcome
            do {
                surfaceOutcome = try adapter.apply(targetSurface)
            } catch {
                failSurfaceConfiguration(view)
                return closeTransition(.surfaceApplicationFailed)
            }
            guard surfaceOutcome.activeContract == targetSurface else {
                failSurfaceConfiguration(view)
                if case let .unsupported(platform, _) = surfaceOutcome {
                    return closeTransition(.surfaceUnsupported(platform))
                }
                return closeTransition(.surfaceApplicationFailed)
            }

            let replacementRuntime: any StreamMetalPresenterRuntiming
            do {
                guard let device = view.device else {
                    throw StreamMetalPresenterError.commandQueueUnavailable
                }
                replacementRuntime = try runtimeFactory(
                    device,
                    Bundle(for: StreamMetalPresenter.self)
                )
            } catch {
                restoreSurfaceAfterFailedTransition(
                    previousSurface,
                    adapter: adapter
                )
                failSurfaceConfiguration(view)
                return closeTransition(.runtimeCreationFailed)
            }

            withLock {
                runtime = replacementRuntime
                activeResolvedConfiguration = configuration
                appliedSurfaceContract = targetSurface
                requiresClearBeforePresentation = true
                presentationRevision &+= 1
                configurationTransitionCount &+= 1
            }
            view.delegate = self
            let schedule = withLock {
                StreamMetalViewScheduleResolver.resolve(renderPolicy)
            }
            view.isPaused = schedule.isPaused
            view.preferredFramesPerSecond = schedule.preferredFramesPerSecond
            publishDiagnostic(.resolved(configuration))
            view.draw()
            return .applied(
                previous: previousIdentity,
                current: configuration.identity
            )
        }
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        _ = size
    }

    func draw(in view: MTKView) {
        let snapshot = withLock {
            (
                renderPolicy,
                coordinateSnapshot,
                runtime,
                activeResolvedConfiguration,
                requiresClearBeforePresentation,
                presentationRevision
            )
        }
        guard let runtime = snapshot.2 else { return }
        let drawable = drawableProvider(view)
        if snapshot.4 {
            guard let drawable else { return }
            do {
                try runtime.clear(drawable: drawable, color: view.clearColor)
                withLock {
                    guard presentationRevision == snapshot.5 else { return }
                    requiresClearBeforePresentation = false
                }
            } catch {
                runtime.stop()
                publishDiagnostic(.pipelineFailure)
            }
            return
        }
        let frame = presentationSource.currentFrame()
        let drawableMatchesCoordinates = snapshot.1.map { coordinates in
            coordinates.drawableSize.width == drawable?.texture.width
                && coordinates.drawableSize.height == drawable?.texture.height
        } ?? false
        let decision = StreamMetalFrameDecisionResolver.resolve(
            policy: snapshot.0,
            hasDrawable: drawable != nil,
            hasCoordinates: snapshot.1 != nil,
            drawableMatchesCoordinates: drawableMatchesCoordinates,
            hasFrame: frame != nil
        )
        switch decision {
        case .waitForDrawable:
            return
        case let .clear(reason):
            if reason == .inactivePolicy { runtime.stop() }
            if let drawable {
                do {
                    try runtime.clear(drawable: drawable, color: view.clearColor)
                } catch {
                    runtime.stop()
                    publishDiagnostic(.pipelineFailure)
                }
            }
            return
        case .present:
            break
        }
        guard let coordinateSnapshot = snapshot.1,
              let frame,
              let drawable else { return }
        do {
            let plan: StreamMetalPresentationPlan
            if let resolvedConfiguration = snapshot.3 {
                plan = try StreamMetalPresentationPlanResolver.resolve(
                    frame: frame,
                    resolvedConfiguration: resolvedConfiguration
                )
            } else {
                plan = try StreamMetalPresentationPlanResolver.resolve(
                    frame: frame,
                    coordinateSnapshot: coordinateSnapshot
                )
            }
            guard withLock({
                presentationRevision == snapshot.5
                    && activeResolvedConfiguration == snapshot.3
            }) else {
                return
            }
            _ = try runtime.present(
                frame: frame,
                plan: plan,
                coordinateSnapshot: coordinateSnapshot,
                target: HDRMetalRenderTarget(
                    texture: drawable.texture,
                    drawable: drawable
                ),
                completion: .asynchronous
            )
            if let resolvedConfiguration = snapshot.3 {
                publishDiagnostic(.resolved(resolvedConfiguration))
            }
        } catch {
            runtime.stop()
            try? runtime.clear(drawable: drawable, color: view.clearColor)
            publishDiagnostic(Self.diagnosticState(for: error))
        }
    }

    @MainActor
    func stop() {
        let view = surfaceView
        view?.isPaused = true
        let oldRuntime = withLock {
            let previous = runtime
            runtime = nil
            activeResolvedConfiguration = nil
            lastRequestedResolution = nil
            requiresClearBeforePresentation = false
            presentationRevision &+= 1
            return previous
        }
        if let view {
            clearCurrentDrawable(on: view, runtime: oldRuntime)
        }
        oldRuntime?.invalidate()
        let restoredSurface: HDRSurfaceContract?
        if let adapter = surfaceAdapter {
            restoredSurface = applySDRSurface(using: adapter)
        } else {
            restoredSurface = nil
        }
        withLock { appliedSurfaceContract = restoredSurface }
        publishDiagnostic(.inactive)
        releaseDiagnosticLease()
    }

    func snapshot() -> StreamMetalPresenterSnapshot {
        withLock {
            StreamMetalPresenterSnapshot(
                activeConfiguration: activeResolvedConfiguration?.identity,
                appliedSurfaceContract: appliedSurfaceContract,
                requiresClearBeforePresentation: requiresClearBeforePresentation,
                configurationTransitionCount: configurationTransitionCount,
                closedTransitionCount: closedTransitionCount
            )
        }
    }

    @MainActor
    private func failSurfaceConfiguration(_ view: MTKView) {
        let previousRuntime = withLock {
            let previous = runtime
            runtime = nil
            activeResolvedConfiguration = nil
            lastRequestedResolution = nil
            appliedSurfaceContract = nil
            requiresClearBeforePresentation = false
            presentationRevision &+= 1
            return previous
        }
        previousRuntime?.invalidate()
        view.delegate = nil
        view.isPaused = true
    }

    @MainActor
    private func closeActivePresentation(
        on view: MTKView,
        adapter: any HDRSurfaceApplying,
        restoreSDR: Bool
    ) {
        view.isPaused = true
        let previousRuntime = withLock { runtime }
        clearCurrentDrawable(on: view, runtime: previousRuntime)
        deactivateRuntimeForTransition()
        let restoredSurface = restoreSDR
            ? applySDRSurface(using: adapter)
            : nil
        withLock {
            appliedSurfaceContract = restoredSurface
            requiresClearBeforePresentation = false
        }
    }

    private func deactivateRuntimeForTransition() {
        let previousRuntime = withLock {
            let previous = runtime
            runtime = nil
            activeResolvedConfiguration = nil
            requiresClearBeforePresentation = true
            presentationRevision &+= 1
            return previous
        }
        previousRuntime?.invalidate()
    }

    @MainActor
    private func clearCurrentDrawable(
        on view: MTKView,
        runtime: (any StreamMetalPresenterRuntiming)?
    ) {
        guard let runtime, let drawable = drawableProvider(view) else { return }
        try? runtime.clear(drawable: drawable, color: view.clearColor)
    }

    @MainActor
    private func applySDRSurface(
        using adapter: any HDRSurfaceApplying
    ) -> HDRSurfaceContract? {
        guard let surface = try? HDRSurfaceContract(
            drawablePixelFormat: .bgra8UnormSRGB,
            outputColorSpace: .sRGB,
            outputGamut: .sRGB,
            extendedRangeIntent: .disabled,
            metadataMode: .none
        ), let outcome = try? adapter.apply(surface),
              outcome.activeContract == surface else {
            return nil
        }
        return surface
    }

    @MainActor
    private func restoreSurfaceAfterFailedTransition(
        _ previousSurface: HDRSurfaceContract?,
        adapter: any HDRSurfaceApplying
    ) {
        if let previousSurface,
           let outcome = try? adapter.apply(previousSurface),
           outcome.activeContract == previousSurface {
            withLock { appliedSurfaceContract = previousSurface }
        } else {
            let restoredSurface = applySDRSurface(using: adapter)
            withLock { appliedSurfaceContract = restoredSurface }
        }
    }

    @MainActor
    private func closeTransition(
        _ error: StreamMetalConfigurationTransitionError
    ) -> StreamMetalConfigurationTransitionOutcome {
        withLock { closedTransitionCount &+= 1 }
        publishDiagnostic(Self.diagnosticState(for: error))
        return .closed(error)
    }

    @MainActor
    private func claimDiagnosticLease() {
        guard !ownsDiagnosticLease else { return }
        ownsDiagnosticLease = true
        diagnosticLease.claim(diagnosticOwnerID)
    }

    @MainActor
    private func publishDiagnostic(_ state: HDRPresentationDiagnosticState) {
        guard ownsDiagnosticLease else { return }
        diagnosticHandler(state)
        diagnosticLease.publish(diagnosticOwnerID, state)
    }

    @MainActor
    private func releaseDiagnosticLease() {
        guard ownsDiagnosticLease else { return }
        ownsDiagnosticLease = false
        diagnosticLease.release(diagnosticOwnerID)
    }

    private static func diagnosticState(
        for error: StreamMetalConfigurationTransitionError
    ) -> HDRPresentationDiagnosticState {
        switch error {
        case let .resolutionClosed(error):
            return .closed(error)
        case .staleSurface:
            return .staleRevision
        case .surfaceUnsupported:
            return .unsupportedOutput
        case .surfaceApplicationFailed, .runtimeCreationFailed:
            return .pipelineFailure
        }
    }

    private static func diagnosticState(
        for error: Error
    ) -> HDRPresentationDiagnosticState {
        if let error = error as? HDRRenderResolutionError {
            return .closed(error)
        }
        if let error = error as? MetalFrameDeliveryError {
            switch error {
            case .incompatibleColorSignature:
                return .staleRevision
            case .invalidDecodedContract, .unsupportedPixelFormat,
                 .invalidPixelBufferDimensions, .invalidPlaneCount,
                 .invalidPlaneDimensions, .unexpectedMetalTextureDimensions,
                 .unexpectedMetalTexturePixelFormat,
                 .unexpectedMetalTextureDevice:
                return .invalidInput
            case .invalidQueueCapacity, .textureCacheCreationFailed,
                 .textureCreationFailed, .missingMetalTexture:
                return .pipelineFailure
            }
        }
        if let error = error as? HDRMetalPipelineError {
            switch error {
            case .staleColorSignature, .staleLuminanceMapping:
                return .staleRevision
            default:
                return .pipelineFailure
            }
        }
        return .pipelineFailure
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private extension RenderPolicy {
    var isThrottled: Bool {
        if case .throttled = self { return true }
        return false
    }
}

enum MobileStreamDisplayBindingOutcome: Equatable, Sendable {
    case applied
    case unchanged
    case inactiveSurfaceGeneration
    case staleSurfaceGeneration
    case revisionExhausted
}

@MainActor
final class MobileStreamSurfaceCoordinator {
    typealias InputOutputHandler = @MainActor (InputAdapterOutput) -> Void

    let presenter: StreamMetalPresenter
    private(set) var currentSurfaceGeneration:
        MobileSceneSurfaceGeneration?
    private(set) var currentGeometryBinding:
        MobileStreamGeometryBindingSnapshot?
    private(set) var currentDisplayEDRSnapshot:
        MobileDisplayEDRSnapshot?
    private(set) var isDisplayRevisionExhausted = false
    private var renderState: StreamRenderState
    private var inputOutputHandler: InputOutputHandler
    private var userAllowsHDR: Bool
    private let platformCapabilities: HDRPlatformOutputCapabilities
    private var ownsMobileGeometry = false
    private var ownsMobileDisplay = false

    init(
        presentationSource: StreamVideoPresentationSource,
        renderState: StreamRenderState,
        userAllowsHDR: Bool = true,
        platformCapabilities: HDRPlatformOutputCapabilities =
            HDRPlatformOutputCapabilityAdapter.current.capabilities,
        inputOutputHandler: @escaping InputOutputHandler = { _ in },
        diagnosticHandler: @escaping StreamMetalPresenter.DiagnosticHandler = {
            _ in
        },
        diagnosticLease: HDRPresentationDiagnosticLease = .unmanaged
    ) {
        self.renderState = renderState
        self.userAllowsHDR = userAllowsHDR
        self.platformCapabilities = platformCapabilities
        self.inputOutputHandler = inputOutputHandler
        presenter = StreamMetalPresenter(
            presentationSource: presentationSource,
            renderState: renderState,
            diagnosticHandler: diagnosticHandler,
            diagnosticLease: diagnosticLease
        )
    }

    func update(
        renderState: StreamRenderState,
        inputOutputHandler: @escaping InputOutputHandler,
        userAllowsHDR: Bool? = nil
    ) {
        self.renderState = renderState
        self.inputOutputHandler = inputOutputHandler
        if let userAllowsHDR {
            self.userAllowsHDR = userAllowsHDR
        }
        applyCurrentState()
    }

    func activateSurfaceGeneration(
        _ surfaceGeneration: MobileSceneSurfaceGeneration
    ) {
        guard currentSurfaceGeneration != surfaceGeneration else { return }
        currentSurfaceGeneration = surfaceGeneration
        currentGeometryBinding = nil
        currentDisplayEDRSnapshot = nil
        isDisplayRevisionExhausted = false
        ownsMobileGeometry = true
        ownsMobileDisplay = true
        applyCurrentState()
    }

    func deactivateSurfaceGeneration(
        _ surfaceGeneration: MobileSceneSurfaceGeneration
    ) {
        guard currentSurfaceGeneration == surfaceGeneration else { return }
        currentGeometryBinding = nil
        currentDisplayEDRSnapshot = nil
        isDisplayRevisionExhausted = false
        ownsMobileGeometry = true
        ownsMobileDisplay = true
        applyCurrentState()
        currentSurfaceGeneration = nil
        ownsMobileGeometry = false
        ownsMobileDisplay = false
    }

    func handleGeometryBinding(
        _ binding: MobileStreamGeometryBindingSnapshot?
    ) {
        if let binding {
            guard let currentSurfaceGeneration else { return }
            guard binding.surfaceGeneration == currentSurfaceGeneration else {
                return
            }
        }
        ownsMobileGeometry = true
        currentGeometryBinding = binding
        applyCurrentState()
    }

    @discardableResult
    func handleDisplayEDREvent(
        _ event: MobileDisplayEDRObserverEvent
    ) -> MobileStreamDisplayBindingOutcome {
        switch event {
        case let .snapshot(snapshot):
            return handleDisplayEDRSnapshot(snapshot)
        case let .revisionExhausted(surfaceGeneration):
            return handleDisplayEDRRevisionExhaustion(
                surfaceGeneration: surfaceGeneration
            )
        }
    }

    @discardableResult
    func handleDisplayEDRSnapshot(
        _ snapshot: MobileDisplayEDRSnapshot
    ) -> MobileStreamDisplayBindingOutcome {
        guard let currentSurfaceGeneration else {
            return .inactiveSurfaceGeneration
        }
        guard snapshot.surfaceGeneration == currentSurfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isDisplayRevisionExhausted else {
            return .revisionExhausted
        }
        guard currentDisplayEDRSnapshot != snapshot else {
            return .unchanged
        }
        ownsMobileDisplay = true
        currentDisplayEDRSnapshot = snapshot
        applyCurrentState()
        return .applied
    }

    @discardableResult
    private func handleDisplayEDRRevisionExhaustion(
        surfaceGeneration: MobileSceneSurfaceGeneration
    ) -> MobileStreamDisplayBindingOutcome {
        guard let currentSurfaceGeneration else {
            return .inactiveSurfaceGeneration
        }
        guard surfaceGeneration == currentSurfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isDisplayRevisionExhausted else { return .unchanged }

        ownsMobileDisplay = true
        currentDisplayEDRSnapshot = nil
        isDisplayRevisionExhausted = true
        applyCurrentState()
        return .revisionExhausted
    }

    func handleInputOutput(_ output: InputAdapterOutput) {
        inputOutputHandler(output)
    }

    private func applyCurrentState() {
        if let coordinateSnapshot = currentGeometryBinding?.coordinateSnapshot {
            if renderState.transform.sourceSize == coordinateSnapshot.sourceSize,
               renderState.transform.mode == coordinateSnapshot.mode {
                if renderState.transform.drawableSize
                    != coordinateSnapshot.drawableSize {
                    renderState.transform.drawableSize =
                        coordinateSnapshot.drawableSize
                }
            } else if renderState.transform.drawableSize != .zero {
                renderState.transform.drawableSize = .zero
            }
        } else if ownsMobileGeometry,
                  renderState.transform.drawableSize != .zero {
            renderState.transform.drawableSize = .zero
        }
        if ownsMobileDisplay {
            renderState.displaySnapshot =
                currentDisplayEDRSnapshot?.renderSnapshot
            renderState.headroom =
                currentDisplayEDRSnapshot?.renderSnapshot?.headroom
                ?? DisplayHeadroom()
            renderState.isDisplayRevisionExhausted =
                isDisplayRevisionExhausted
            let drawableSize = renderState.coordinateSnapshot?.drawableSize
            let drawableAvailable = drawableSize.map {
                $0.width > 0 && $0.height > 0
            } ?? false
            renderState.hdrRenderResolution =
                StreamHDRRenderResolutionResolver.resolve(
                    StreamHDRRenderResolutionResolverInput(
                        decodedPresentationContract:
                            renderState.decodedVideoPresentationContract,
                        negotiatedVideoColorMetadata:
                            renderState.negotiatedVideoColorMetadata,
                        userAllowsHDR: userAllowsHDR,
                        platformCapabilities: platformCapabilities,
                        displaySnapshot: renderState.displaySnapshot,
                        isDisplayRevisionExhausted:
                            renderState.isDisplayRevisionExhausted,
                        drawableState: HDRDrawableState(
                            isAvailable: drawableAvailable,
                            appliedSurfaceContract:
                                presenter.snapshot().appliedSurfaceContract
                        )
                    )
                )
        }
        presenter.update(renderState: renderState)
    }
}

#if os(macOS)
@MainActor
final class MacStreamSurfaceAttachmentOwner {
    private let lifecycleMonitor: any AppKitLifecycleMonitoring
    private let attachmentHandler: @MainActor (MacStreamInputCaptureView, Bool) -> Void
    private weak var view: MacStreamInputCaptureView?
    private weak var observedWindow: NSWindow?
    private var isMonitoringWindow = false

    init(
        lifecycleMonitor: any AppKitLifecycleMonitoring,
        attachmentHandler: @escaping @MainActor (MacStreamInputCaptureView, Bool) -> Void = { _, _ in }
    ) {
        self.lifecycleMonitor = lifecycleMonitor
        self.attachmentHandler = attachmentHandler
    }

    func attach(to view: MacStreamInputCaptureView) {
        guard self.view !== view else { return }
        detach()
        self.view = view
        view.onWindowChange = { [weak self, weak view] window in
            guard let self, let view, self.view === view else { return }
            self.observe(window)
            self.attachmentHandler(view, window != nil)
        }
        view.onGeometryChange = { [weak self, weak view] in
            guard let self, let view, self.view === view else { return }
            self.lifecycleMonitor.surfaceGeometryDidChange()
        }
        observe(view.window)
        attachmentHandler(view, view.window != nil)
    }

    func detach(from candidate: MacStreamInputCaptureView? = nil) {
        guard let view else { return }
        if let candidate, view !== candidate { return }
        view.onWindowChange = nil
        view.onGeometryChange = nil
        attachmentHandler(view, false)
        view.resetTransientInputState()
        self.view = nil
        if isMonitoringWindow {
            lifecycleMonitor.detach()
            observedWindow = nil
            isMonitoringWindow = false
        }
    }

    private func observe(_ window: NSWindow?) {
        guard let view else { return }
        guard let window else {
            guard isMonitoringWindow else { return }
            lifecycleMonitor.detach()
            observedWindow = nil
            isMonitoringWindow = false
            return
        }
        guard !isMonitoringWindow || observedWindow !== window else { return }
        observedWindow = window
        isMonitoringWindow = true
        lifecycleMonitor.attach(to: window, surface: view)
    }
}

@MainActor
final class MacStreamSurfaceCaptureController {
    private let broker: MacCursorCaptureBroker
    private let leaseID = UUID()
    private weak var view: MacStreamInputCaptureView?
    private var policy = MacInputSurfacePolicy.inactive
    private var isAttached = false

    init(broker: MacCursorCaptureBroker) {
        self.broker = broker
    }

    func update(
        _ policy: MacInputSurfacePolicy,
        for view: MacStreamInputCaptureView
    ) {
        if self.view !== view {
            detach()
            self.view = view
            isAttached = view.window != nil
        }
        self.policy = policy
        applyCurrentPolicy()
    }

    func attachmentDidChange(
        for view: MacStreamInputCaptureView,
        isAttached: Bool
    ) {
        guard isAttached else {
            guard self.view === view else { return }
            view.isInputCaptureEnabled = false
            self.isAttached = false
            _ = broker.release(leaseID: leaseID)
            self.view = nil
            return
        }
        guard self.view == nil || self.view === view else { return }
        self.view = view
        self.isAttached = true
        applyCurrentPolicy()
    }

    func exitRelativeCapture() {
        guard policy.cursorPolicy.capturesRelativePointer,
              let view else { return }
        view.isInputCaptureEnabled = false
        _ = broker.apply(
            CursorCapturePolicyResolver.resolve(
                isStreamActive: false,
                isVisible: false,
                isFocused: false,
                prefersRemotePointer: false
            ),
            leaseID: leaseID
        )
    }

    func detach(from candidate: MacStreamInputCaptureView? = nil) {
        guard let view else { return }
        if let candidate, view !== candidate { return }
        view.isInputCaptureEnabled = false
        _ = broker.release(leaseID: leaseID)
        self.view = nil
        isAttached = false
        policy = .inactive
    }

    private func applyCurrentPolicy() {
        guard let view else { return }
        guard isAttached else {
            view.isInputCaptureEnabled = false
            _ = broker.release(leaseID: leaseID)
            return
        }
        guard policy.admitsInput else {
            view.isInputCaptureEnabled = false
            _ = broker.apply(
                MacInputSurfacePolicy.inactive.cursorPolicy,
                leaseID: leaseID
            )
            return
        }

        let cursorReady = broker.apply(policy.cursorPolicy, leaseID: leaseID)
        view.isInputCaptureEnabled = cursorReady
    }
}

@MainActor
final class MacStreamSurfaceCoordinator {
    let presenter: StreamMetalPresenter
    let attachmentOwner: MacStreamSurfaceAttachmentOwner
    let captureController: MacStreamSurfaceCaptureController
    private var inputSampleHandler: MacStreamInputCaptureView.SampleHandler
    private var captureExitHandler: @MainActor () -> Void

    init(
        presentationSource: StreamVideoPresentationSource,
        renderState: StreamRenderState,
        lifecycle: PlatformLifecycleState,
        inputSampleHandler: @escaping MacStreamInputCaptureView.SampleHandler,
        captureExitHandler: @escaping @MainActor () -> Void,
        diagnosticHandler: @escaping StreamMetalPresenter.DiagnosticHandler = { _ in },
        diagnosticLease: HDRPresentationDiagnosticLease = .unmanaged,
        cursorBroker: MacCursorCaptureBroker = .shared
    ) {
        presenter = StreamMetalPresenter(
            presentationSource: presentationSource,
            renderState: renderState,
            diagnosticHandler: diagnosticHandler,
            diagnosticLease: diagnosticLease
        )
        let captureController = MacStreamSurfaceCaptureController(broker: cursorBroker)
        self.captureController = captureController
        attachmentOwner = MacStreamSurfaceAttachmentOwner(
            lifecycleMonitor: AppKitLifecycleMonitor(lifecycle: lifecycle),
            attachmentHandler: { view, isAttached in
                captureController.attachmentDidChange(
                    for: view,
                    isAttached: isAttached
                )
            }
        )
        self.inputSampleHandler = inputSampleHandler
        self.captureExitHandler = captureExitHandler
    }

    func update(
        renderState: StreamRenderState,
        inputPolicy: MacInputSurfacePolicy,
        view: MacStreamInputCaptureView,
        inputSampleHandler: @escaping MacStreamInputCaptureView.SampleHandler,
        captureExitHandler: @escaping @MainActor () -> Void
    ) {
        presenter.update(renderState: renderState)
        captureController.update(inputPolicy, for: view)
        self.inputSampleHandler = inputSampleHandler
        self.captureExitHandler = captureExitHandler
    }

    func handle(_ sample: MacPlatformInputSample) {
        inputSampleHandler(sample)
    }

    func exitCapture() {
        captureController.exitRelativeCapture()
        captureExitHandler()
    }

    func detach(_ view: MacStreamInputCaptureView) {
        presenter.stop()
        captureController.detach(from: view)
        attachmentOwner.detach(from: view)
        view.delegate = nil
        view.isPaused = true
    }
}

struct MetalStreamSurface: NSViewRepresentable {
    let renderState: StreamRenderState
    let presentationSource: StreamVideoPresentationSource
    let lifecycle: PlatformLifecycleState
    var inputPolicy = MacInputSurfacePolicy.inactive
    var inputSampleHandler: MacStreamInputCaptureView.SampleHandler = { _ in }
    var captureExitHandler: @MainActor () -> Void = {}
    var diagnosticHandler: StreamMetalPresenter.DiagnosticHandler = { _ in }
    var diagnosticLease: HDRPresentationDiagnosticLease = .unmanaged

    func makeCoordinator() -> MacStreamSurfaceCoordinator {
        MacStreamSurfaceCoordinator(
            presentationSource: presentationSource,
            renderState: renderState,
            lifecycle: lifecycle,
            inputSampleHandler: inputSampleHandler,
            captureExitHandler: captureExitHandler,
            diagnosticHandler: diagnosticHandler,
            diagnosticLease: diagnosticLease
        )
    }

    func makeNSView(context: Context) -> MacStreamInputCaptureView {
        let view = MacStreamInputCaptureView(
            frame: .zero,
            device: MTLCreateSystemDefaultDevice(),
            isInputCaptureEnabled: false,
            forwardsSystemShortcuts: inputPolicy.forwardsSystemShortcuts,
            captureExitHandler: { context.coordinator.exitCapture() },
            sampleHandler: { context.coordinator.handle($0) }
        )
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.enableSetNeedsDisplay = false
        view.isPaused = true
        context.coordinator.presenter.configure(view)
        context.coordinator.captureController.update(inputPolicy, for: view)
        context.coordinator.attachmentOwner.attach(to: view)
        return view
    }

    func updateNSView(_ view: MacStreamInputCaptureView, context: Context) {
        view.forwardsSystemShortcuts = inputPolicy.forwardsSystemShortcuts
        context.coordinator.update(
            renderState: renderState,
            inputPolicy: inputPolicy,
            view: view,
            inputSampleHandler: inputSampleHandler,
            captureExitHandler: captureExitHandler
        )
        context.coordinator.attachmentOwner.attach(to: view)
        let schedule = apply(renderState, to: view)
        if schedule.requestsImmediateDraw { view.draw() }
    }

    static func dismantleNSView(
        _ view: MacStreamInputCaptureView,
        coordinator: MacStreamSurfaceCoordinator
    ) {
        coordinator.detach(view)
    }

    private func apply(
        _ state: StreamRenderState,
        to view: MTKView
    ) -> StreamMetalViewSchedule {
        let schedule = StreamMetalViewScheduleResolver.resolve(state.policy)
        view.isPaused = schedule.isPaused
        view.preferredFramesPerSecond = schedule.preferredFramesPerSecond
        return schedule
    }
}
#else
#if os(tvOS) || os(visionOS)
@MainActor
final class TVVisionStreamMetalView: MTKView {
    typealias SurfaceRelay = TVVisionUIKitStreamSurfaceRelay<
        TVVisionStreamMetalView,
        UIWindowScene
    >
    typealias SurfaceCallbackHandler = SurfaceRelay.Handler

    private var surfaceRelay: SurfaceRelay?
    private var traitChangeRegistration:
        (any UITraitChangeRegistration)?

    override var isHidden: Bool {
        didSet {
            guard isHidden != oldValue else { return }
            publishSurfaceCallbacks([.visibility, .focusEligibility])
        }
    }

    override var alpha: CGFloat {
        didSet {
            guard alpha != oldValue else { return }
            publishSurfaceCallbacks([.visibility, .focusEligibility])
        }
    }

    override var isUserInteractionEnabled: Bool {
        didSet {
            guard isUserInteractionEnabled != oldValue else { return }
            publishSurfaceCallbacks([.focusEligibility])
        }
    }

    init(
        frame frameRect: CGRect = .zero,
        device: (any MTLDevice)? = nil,
        surfaceCallbackHandler:
            @escaping SurfaceCallbackHandler = { _, _, _ in }
    ) {
        super.init(frame: frameRect, device: device)
        surfaceRelay = SurfaceRelay(
            surface: self,
            stateReader: { surface in
                let window = surface.window
                let isAttached = window != nil
                let isVisible = isAttached
                    && !surface.isHidden
                    && surface.alpha > 0
                    && window?.isHidden == false
                return TVVisionUIKitStreamSurfaceState(
                    isAttached: isAttached,
                    windowScene: window?.windowScene,
                    isVisible: isVisible,
                    scale: Double(surface.contentScaleFactor),
                    drawableSize: surface.drawableSize,
                    isFocusEligible: isVisible
                        && surface.isUserInteractionEnabled
                        && surface.canBecomeFocused
                )
            },
            handler: surfaceCallbackHandler
        )
        traitChangeRegistration = registerForTraitChanges([
            UITraitDisplayScale.self,
            UITraitUserInterfaceStyle.self
        ]) { (view: TVVisionStreamMetalView, _) in
            view.publishSurfaceCallbacks([
                .visibility,
                .scale,
                .drawable,
                .focusEligibility
            ])
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("TVVisionStreamMetalView must be created programmatically")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        publishSurfaceCallbacks([
            .attachment,
            .windowScene,
            .visibility,
            .scale,
            .drawable,
            .focusEligibility
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        publishSurfaceCallbacks([
            .layout,
            .visibility,
            .scale,
            .drawable,
            .focusEligibility
        ])
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        publishSurfaceCallbacks([.layout, .drawable])
    }

    override func didUpdateFocus(
        in context: UIFocusUpdateContext,
        with coordinator: UIFocusAnimationCoordinator
    ) {
        super.didUpdateFocus(in: context, with: coordinator)
        publishSurfaceCallbacks([.focusEligibility])
    }

    func updateSurfaceCallbackHandler(
        _ handler: @escaping SurfaceCallbackHandler
    ) {
        surfaceRelay?.updateHandler(handler)
    }

    func refreshSurfaceCallbacks() {
        publishSurfaceCallbacks(TVVisionUIKitStreamSurfaceCallback.allCases)
    }

    func invalidateSurfaceCallbacks() {
        if let traitChangeRegistration {
            unregisterForTraitChanges(traitChangeRegistration)
            self.traitChangeRegistration = nil
        }
        surfaceRelay?.invalidate()
        surfaceRelay = nil
    }

    private func publishSurfaceCallbacks(
        _ callbacks: [TVVisionUIKitStreamSurfaceCallback]
    ) {
        surfaceRelay?.publish(callbacks)
    }
}
#endif

#if os(iOS)
extension MobileStreamSceneLifecycleNotificationNames {
    static let current = MobileStreamSceneLifecycleNotificationNames(
        didActivate: UIScene.didActivateNotification,
        willDeactivate: UIScene.willDeactivateNotification,
        didEnterBackground: UIScene.didEnterBackgroundNotification,
        willEnterForeground: UIScene.willEnterForegroundNotification
    )
}

@MainActor
enum MobileStreamSurfaceGenerationSequence {
    private static var nextRawValue: UInt64 = 1
    private static var isExhausted = false

    static func next() -> MobileSceneSurfaceGeneration? {
        guard !isExhausted,
              let generation = MobileSceneSurfaceGeneration(
                  rawValue: nextRawValue
              ) else {
            return nil
        }
        if nextRawValue == UInt64.max {
            isExhausted = true
        } else {
            nextRawValue += 1
        }
        return generation
    }
}

@MainActor
final class MobileStreamMetalView: MTKView {
    typealias AttachmentEventHandler =
        MobileStreamSurfaceAttachmentRelay<MobileStreamMetalView>.Handler
    typealias AttachmentOwner = MobileStreamSurfaceAttachmentOwner<
        MobileStreamMetalView,
        UIWindow,
        UIWindowScene,
        UIScreen
    >
    typealias AttachmentUpdateHandler = AttachmentOwner.Handler
    typealias SceneLifecycleObserver =
        MobileStreamSceneLifecycleObserver<UIWindowScene>
    typealias SceneLifecycleUpdateHandler = SceneLifecycleObserver.Handler
    typealias SceneGeometryObserver = MobileStreamSceneGeometryObserver<
        MobileStreamMetalView,
        UIWindow,
        UIWindowScene,
        UIScreen
    >
    typealias SceneWindowSnapshotHandler = SceneGeometryObserver.Handler
    typealias DisplayEDRObserver =
        MobileDisplayEDRObserver<UIWindow, UIScreen>
    typealias DisplayEDREventHandler = DisplayEDRObserver.Handler
    typealias GeometryBindingOwner =
        MobileStreamGeometryBindingOwner<MobileStreamMetalView>
    typealias GeometryBindingUpdateHandler = GeometryBindingOwner.Handler
    typealias InputOutputHandler = MobileStreamSurfaceCoordinator.InputOutputHandler

    var surfaceGeneration: MobileSceneSurfaceGeneration? {
        geometryBindingOwner?.surfaceGeneration
    }

    private var attachmentRelay:
        MobileStreamSurfaceAttachmentRelay<MobileStreamMetalView>?
    private var attachmentOwner: AttachmentOwner?
    private var sceneLifecycleObserver: SceneLifecycleObserver?
    private var sceneGeometryObserver: SceneGeometryObserver?
    private var displayEDRObserver: DisplayEDRObserver?
    private var geometryBindingOwner: GeometryBindingOwner?
    private var sceneGeometrySettleTask: Task<Void, Never>?
    private var attachmentUpdateHandler: AttachmentUpdateHandler?
    private var sceneLifecycleUpdateHandler: SceneLifecycleUpdateHandler?
    private var sceneWindowSnapshotHandler: SceneWindowSnapshotHandler?
    private var displayEDREventHandler: DisplayEDREventHandler?
    private var inputOutputHandler: InputOutputHandler?
    private var hoverGestureRecognizer: UIHoverGestureRecognizer?
    private var touchIDs: [ObjectIdentifier: Int] = [:]
    private var nextTouchID = 1
    private var isTouchIDSequenceExhausted = false
    private var traitChangeRegistration:
        (any UITraitChangeRegistration)?

    init(
        frame frameRect: CGRect = .zero,
        device: (any MTLDevice)? = nil,
        sourceSize: PixelSize = .zero,
        mode: RenderScaleMode = .fit,
        attachmentEventHandler: @escaping AttachmentEventHandler = { _, _ in },
        attachmentUpdateHandler: @escaping AttachmentUpdateHandler = { _ in },
        sceneLifecycleUpdateHandler:
            @escaping SceneLifecycleUpdateHandler = { _ in },
        sceneWindowSnapshotHandler:
            @escaping SceneWindowSnapshotHandler = { _ in },
        displayEDREventHandler:
            @escaping DisplayEDREventHandler = { _ in },
        geometryBindingUpdateHandler:
            @escaping GeometryBindingUpdateHandler = { _ in },
        inputOutputHandler: @escaping InputOutputHandler = { _ in }
    ) {
        super.init(frame: frameRect, device: device)
        autoResizeDrawable = false
        isMultipleTouchEnabled = true
        self.attachmentUpdateHandler = attachmentUpdateHandler
        self.sceneLifecycleUpdateHandler = sceneLifecycleUpdateHandler
        self.sceneWindowSnapshotHandler = sceneWindowSnapshotHandler
        self.displayEDREventHandler = displayEDREventHandler
        self.inputOutputHandler = inputOutputHandler
        attachmentRelay = MobileStreamSurfaceAttachmentRelay(
            surface: self,
            handler: attachmentEventHandler
        )
        if let surfaceGeneration = MobileStreamSurfaceGenerationSequence.next() {
            geometryBindingOwner = GeometryBindingOwner(
                surfaceGeneration: surfaceGeneration,
                surface: self,
                sourceSize: sourceSize,
                mode: mode,
                drawableApplier: { surface, size in
                    surface.drawableSize = CGSize(
                        width: size.width,
                        height: size.height
                    )
                    return surface.drawableSize == CGSize(
                        width: size.width,
                        height: size.height
                    )
                },
                handler: geometryBindingUpdateHandler
            )
            sceneLifecycleObserver = SceneLifecycleObserver(
                surfaceGeneration: surfaceGeneration,
                notificationCenter: .default,
                names: .current,
                activityReader: { scene in
                    switch scene.activationState {
                    case .foregroundActive:
                        return .active
                    case .foregroundInactive:
                        return .inactive
                    case .background, .unattached:
                        return .background
                    @unknown default:
                        return .background
                    }
                },
                handler: { [weak self] update in
                    self?.handleSceneLifecycleUpdate(update)
                }
            )
            sceneGeometryObserver = SceneGeometryObserver(
                surfaceGeneration: surfaceGeneration,
                surface: self,
                reader: { surface, window, scene, _ in
                    MobileStreamSceneGeometryReading(
                        viewBounds: Self.sceneRect(surface.bounds),
                        windowBounds: Self.sceneRect(window.bounds),
                        safeAreaInsets: MobileSceneEdgeInsets(
                            top: Double(surface.safeAreaInsets.top),
                            leading: Double(surface.safeAreaInsets.left),
                            bottom: Double(surface.safeAreaInsets.bottom),
                            trailing: Double(surface.safeAreaInsets.right)
                        ),
                        scale: Double(surface.contentScaleFactor),
                        orientation: Self.orientation(
                            scene.effectiveGeometry.interfaceOrientation
                        ),
                        traits: MobileSceneTraits(
                            horizontalSizeClass: Self.sizeClass(
                                surface.traitCollection.horizontalSizeClass
                            ),
                            verticalSizeClass: Self.sizeClass(
                                surface.traitCollection.verticalSizeClass
                            ),
                            interfaceStyle: Self.interfaceStyle(
                                surface.traitCollection.userInterfaceStyle
                            )
                        )
                    )
                },
                handler: { [weak self] snapshot in
                    self?.handleSceneWindowSnapshot(snapshot)
                },
                settleRequestHandler: { [weak self] request in
                    self?.scheduleGeometrySettle(request)
                }
            )
            let displayEDRReader =
                MobileDisplayEDRWindowReader<UIWindow, UIScreen>.actualWindow
            displayEDRObserver = DisplayEDRObserver(
                surfaceGeneration: surfaceGeneration,
                notificationCenter: .default,
                names: .current,
                screenResolver: { $0.screen },
                reader: { window, displayGeneration in
                    displayEDRReader.read(
                        window: window,
                        displayGeneration: displayGeneration
                    )
                },
                handler: { [weak self] event in
                    self?.displayEDREventHandler?(event)
                }
            )
            attachmentOwner = AttachmentOwner(
                surfaceGeneration: surfaceGeneration,
                surface: self,
                resolver: { surface in
                    guard let window = surface.window,
                          let scene = window.windowScene else {
                        return nil
                    }
                    return AttachmentOwner.ResolvedAttachment(
                        window: window,
                        scene: scene,
                        screen: window.screen
                    )
                },
                handler: { [weak self] update in
                    self?.handleAttachmentUpdate(update)
                }
            )
        }
        let hoverGestureRecognizer = UIHoverGestureRecognizer(
            target: self,
            action: #selector(handlePointerHover(_:))
        )
        addGestureRecognizer(hoverGestureRecognizer)
        self.hoverGestureRecognizer = hoverGestureRecognizer
        traitChangeRegistration = registerForTraitChanges([
            UITraitHorizontalSizeClass.self,
            UITraitVerticalSizeClass.self,
            UITraitDisplayScale.self,
            UITraitUserInterfaceStyle.self
        ]) { (view: MobileStreamMetalView, _) in
            view.publishAttachmentEvent(.registeredTraitsChanged)
        }
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("MobileStreamMetalView must be created programmatically")
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        publishAttachmentEvent(.didMoveToWindow)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        publishAttachmentEvent(.layoutSubviews)
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()
        publishAttachmentEvent(.safeAreaInsetsDidChange)
    }

    override func touchesBegan(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        super.touchesBegan(touches, with: event)
        publishTouches(touches, phase: .began)
    }

    override func touchesMoved(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        super.touchesMoved(touches, with: event)
        publishTouches(touches, phase: .moved)
    }

    override func touchesEnded(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        super.touchesEnded(touches, with: event)
        publishTouches(touches, phase: .ended)
    }

    override func touchesCancelled(
        _ touches: Set<UITouch>,
        with event: UIEvent?
    ) {
        super.touchesCancelled(touches, with: event)
        publishTouches(touches, phase: .cancelled)
    }

    func updateAttachmentEventHandler(
        _ handler: @escaping AttachmentEventHandler
    ) {
        attachmentRelay?.updateHandler(handler)
    }

    func updateAttachmentUpdateHandler(
        _ handler: @escaping AttachmentUpdateHandler
    ) {
        attachmentUpdateHandler = handler
    }

    func updateSceneLifecycleUpdateHandler(
        _ handler: @escaping SceneLifecycleUpdateHandler
    ) {
        sceneLifecycleUpdateHandler = handler
    }

    func updateSceneWindowSnapshotHandler(
        _ handler: @escaping SceneWindowSnapshotHandler
    ) {
        sceneWindowSnapshotHandler = handler
    }

    func updateDisplayEDREventHandler(
        _ handler: @escaping DisplayEDREventHandler
    ) {
        displayEDREventHandler = handler
    }

    func updateGeometryBinding(
        sourceSize: PixelSize,
        mode: RenderScaleMode,
        handler: @escaping GeometryBindingUpdateHandler,
        inputOutputHandler: @escaping InputOutputHandler
    ) {
        self.inputOutputHandler = inputOutputHandler
        guard let geometryBindingOwner else { return }
        geometryBindingOwner.updateHandler(handler)
        geometryBindingOwner.updateRenderInputs(
            sourceSize: sourceSize,
            mode: mode,
            surface: self,
            surfaceGeneration: geometryBindingOwner.surfaceGeneration
        )
    }

    func invalidateAttachmentCallbacks() {
        if let traitChangeRegistration {
            unregisterForTraitChanges(traitChangeRegistration)
            self.traitChangeRegistration = nil
        }
        if let hoverGestureRecognizer {
            removeGestureRecognizer(hoverGestureRecognizer)
            self.hoverGestureRecognizer = nil
        }
        if let geometryBindingOwner {
            geometryBindingOwner.invalidate(
                surface: self,
                surfaceGeneration: geometryBindingOwner.surfaceGeneration
            )
            self.geometryBindingOwner = nil
        }
        if let attachmentOwner {
            attachmentOwner.invalidate(
                surface: self,
                surfaceGeneration: attachmentOwner.surfaceGeneration
            )
            self.attachmentOwner = nil
        }
        sceneGeometrySettleTask?.cancel()
        sceneGeometrySettleTask = nil
        sceneLifecycleObserver = nil
        sceneGeometryObserver = nil
        displayEDRObserver = nil
        attachmentUpdateHandler = nil
        sceneLifecycleUpdateHandler = nil
        sceneWindowSnapshotHandler = nil
        displayEDREventHandler = nil
        inputOutputHandler = nil
        touchIDs.removeAll(keepingCapacity: false)
        attachmentRelay?.invalidate()
        attachmentRelay = nil
    }

    private func publishAttachmentEvent(
        _ event: MobileStreamSurfaceAttachmentEvent
    ) {
        if let attachmentOwner {
            attachmentOwner.handle(
                surface: self,
                surfaceGeneration: attachmentOwner.surfaceGeneration,
                event: event
            )
        }
        attachmentRelay?.publish(event)
    }

    private func handleAttachmentUpdate(
        _ update: AttachmentOwner.Update
    ) {
        switch update.transition {
        case let .callback(event):
            if let surface = update.surface,
               let attachment = update.attachment {
                sceneLifecycleObserver?.attach(
                    to: attachment.scene,
                    surfaceGeneration: update.surfaceGeneration
                )
                sceneGeometryObserver?.attach(
                    surface: surface,
                    window: attachment.window,
                    scene: attachment.scene,
                    screen: attachment.screen,
                    surfaceGeneration: update.surfaceGeneration,
                    event: event
                )
                displayEDRObserver?.attach(
                    window: attachment.window,
                    screen: attachment.screen,
                    displayGeneration: currentDisplayGeneration(),
                    surfaceGeneration: update.surfaceGeneration,
                    reason: displayEDRResampleReason(for: event)
                )
            } else {
                sceneLifecycleObserver?.detach(
                    surfaceGeneration: update.surfaceGeneration
                )
                displayEDRObserver?.detach(
                    surfaceGeneration: update.surfaceGeneration
                )
                if let surface = update.surface {
                    sceneGeometryObserver?.detach(
                        surface: surface,
                        surfaceGeneration: update.surfaceGeneration
                    )
                }
            }
        case .invalidated:
            sceneLifecycleObserver?.invalidate(
                surfaceGeneration: update.surfaceGeneration
            )
            sceneGeometryObserver?.invalidate(
                surface: update.surface,
                surfaceGeneration: update.surfaceGeneration
            )
            displayEDRObserver?.invalidate(
                surfaceGeneration: update.surfaceGeneration
            )
        }
        attachmentUpdateHandler?(update)
    }

    private func handleSceneLifecycleUpdate(
        _ update: MobileStreamSceneLifecycleUpdate
    ) {
        if case let .attached(activity) = update.observation {
            sceneGeometryObserver?.updateActivity(
                activity,
                surfaceGeneration: update.surfaceGeneration
            )
            if activity != .background {
                displayEDRObserver?.resample(
                    .foreground,
                    surfaceGeneration: update.surfaceGeneration
                )
            }
        }
        sceneLifecycleUpdateHandler?(update)
    }

    private func currentDisplayGeneration() -> MobileDisplayGeneration? {
        guard let snapshot = sceneGeometryObserver?.currentSnapshot,
              case let .attached(_, display, _) = snapshot.state else {
            return nil
        }
        return display
    }

    private func displayEDRResampleReason(
        for event: MobileStreamSurfaceAttachmentEvent
    ) -> MobileDisplayEDRResampleReason {
        switch event {
        case .didMoveToWindow:
            return .attachment
        case .layoutSubviews, .safeAreaInsetsDidChange:
            return .layout
        case .registeredTraitsChanged:
            return .traits
        }
    }

    private func handleSceneWindowSnapshot(
        _ snapshot: MobileSceneWindowSnapshot
    ) {
        if let geometryBindingOwner {
            geometryBindingOwner.update(
                snapshot,
                surface: self,
                surfaceGeneration: geometryBindingOwner.surfaceGeneration
            )
        }
        sceneWindowSnapshotHandler?(snapshot)
    }

    private func publishTouches(
        _ touches: Set<UITouch>,
        phase: TouchPhase
    ) {
        let samples = touches.compactMap { touch -> TouchSample? in
            let identity = ObjectIdentifier(touch)
            guard let id = touchID(for: identity, phase: phase) else {
                return nil
            }
            let location = touch.location(in: self)
            let maximumForce = Double(touch.maximumPossibleForce)
            let pressure = maximumForce > 0
                ? Double(touch.force) / maximumForce
                : 0
            return TouchSample(
                id: id,
                phase: phase,
                localPoint: RemotePoint(
                    x: Double(location.x),
                    y: Double(location.y)
                ),
                pressure: pressure
            )
        }.sorted { $0.id < $1.id }

        for sample in samples {
            publishInputOutput(
                geometryBindingOwner?.touch(sample)
                    ?? unavailableInputOutput()
            )
        }
        if phase == .ended || phase == .cancelled {
            for touch in touches {
                touchIDs.removeValue(forKey: ObjectIdentifier(touch))
            }
        }
    }

    private func touchID(
        for identity: ObjectIdentifier,
        phase: TouchPhase
    ) -> Int? {
        if let existing = touchIDs[identity] {
            return existing
        }
        guard phase == .began,
              !isTouchIDSequenceExhausted,
              nextTouchID > 0 else {
            return nil
        }
        let assigned = nextTouchID
        touchIDs[identity] = assigned
        if nextTouchID == Int.max {
            isTouchIDSequenceExhausted = true
        } else {
            nextTouchID += 1
        }
        return assigned
    }

    @objc
    private func handlePointerHover(
        _ recognizer: UIHoverGestureRecognizer
    ) {
        guard recognizer.state == .began || recognizer.state == .changed else {
            return
        }
        let location = recognizer.location(in: self)
        publishInputOutput(
            geometryBindingOwner?.pointerHover(PointerHoverSample(
                localPoint: RemotePoint(
                    x: Double(location.x),
                    y: Double(location.y)
                ),
                buttons: []
            )) ?? unavailableInputOutput()
        )
    }

    private func publishInputOutput(_ output: InputAdapterOutput) {
        inputOutputHandler?(output)
    }

    private func unavailableInputOutput() -> InputAdapterOutput {
        InputAdapterOutput(
            event: nil,
            policy: .drop(reason: "Mobile geometry is unavailable")
        )
    }

    private func scheduleGeometrySettle(
        _ request: MobileStreamSceneGeometrySettleRequest?
    ) {
        sceneGeometrySettleTask?.cancel()
        sceneGeometrySettleTask = nil
        guard let request else { return }
        sceneGeometrySettleTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(120))
            } catch {
                return
            }
            self?.sceneGeometryObserver?.settle(request)
        }
    }

    private static func sceneRect(_ rect: CGRect) -> MobileSceneRect {
        MobileSceneRect(
            x: Double(rect.origin.x),
            y: Double(rect.origin.y),
            width: Double(rect.size.width),
            height: Double(rect.size.height)
        )
    }

    private static func orientation(
        _ orientation: UIInterfaceOrientation
    ) -> MobileInterfaceOrientation {
        switch orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeLeft
        case .landscapeRight:
            return .landscapeRight
        case .unknown:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    private static func sizeClass(
        _ sizeClass: UIUserInterfaceSizeClass
    ) -> MobileSceneSizeClass {
        switch sizeClass {
        case .compact:
            return .compact
        case .regular:
            return .regular
        case .unspecified:
            return .unspecified
        @unknown default:
            return .unspecified
        }
    }

    private static func interfaceStyle(
        _ style: UIUserInterfaceStyle
    ) -> MobileInterfaceStyle {
        switch style {
        case .light:
            return .light
        case .dark:
            return .dark
        case .unspecified:
            return .unspecified
        @unknown default:
            return .unspecified
        }
    }
}
#endif

struct MetalStreamSurface: UIViewRepresentable {
    let renderState: StreamRenderState
    let presentationSource: StreamVideoPresentationSource
    var userAllowsHDR = true
    var diagnosticHandler: StreamMetalPresenter.DiagnosticHandler = { _ in }
    var diagnosticLease: HDRPresentationDiagnosticLease = .unmanaged
    var inputOutputHandler: MobileStreamSurfaceCoordinator.InputOutputHandler = {
        _ in
    }
#if os(iOS)
    var attachmentEventHandler: MobileStreamMetalView.AttachmentEventHandler = {
        _, _ in
    }
    var attachmentUpdateHandler:
        MobileStreamMetalView.AttachmentUpdateHandler = { _ in }
    var sceneLifecycleUpdateHandler:
        MobileStreamMetalView.SceneLifecycleUpdateHandler = { _ in }
    var sceneWindowSnapshotHandler:
        MobileStreamMetalView.SceneWindowSnapshotHandler = { _ in }
    var displayEDREventHandler:
        MobileStreamMetalView.DisplayEDREventHandler = { _ in }
#elseif os(tvOS) || os(visionOS)
    var surfaceCallbackHandler:
        TVVisionStreamMetalView.SurfaceCallbackHandler = { _, _, _ in }
#endif

    func makeCoordinator() -> MobileStreamSurfaceCoordinator {
        MobileStreamSurfaceCoordinator(
            presentationSource: presentationSource,
            renderState: renderState,
            userAllowsHDR: userAllowsHDR,
            inputOutputHandler: inputOutputHandler,
            diagnosticHandler: diagnosticHandler,
            diagnosticLease: diagnosticLease
        )
    }

    func makeUIView(context: Context) -> MTKView {
#if os(iOS)
        context.coordinator.handleGeometryBinding(nil)
        let externalDisplayEDREventHandler =
            displayEDREventHandler
        let view = MobileStreamMetalView(
            frame: .zero,
            device: MTLCreateSystemDefaultDevice(),
            sourceSize: renderState.transform.sourceSize,
            mode: renderState.transform.mode,
            attachmentEventHandler: attachmentEventHandler,
            attachmentUpdateHandler: attachmentUpdateHandler,
            sceneLifecycleUpdateHandler: sceneLifecycleUpdateHandler,
            sceneWindowSnapshotHandler: sceneWindowSnapshotHandler,
            displayEDREventHandler: {
                [weak coordinator = context.coordinator] event in
                coordinator?.handleDisplayEDREvent(event)
                externalDisplayEDREventHandler(event)
            },
            geometryBindingUpdateHandler: { [weak coordinator = context.coordinator]
                binding in
                coordinator?.handleGeometryBinding(binding)
            },
            inputOutputHandler: { [weak coordinator = context.coordinator]
                output in
                coordinator?.handleInputOutput(output)
            }
        )
        if let surfaceGeneration = view.surfaceGeneration {
            context.coordinator.activateSurfaceGeneration(surfaceGeneration)
        }
#elseif os(tvOS) || os(visionOS)
        let view = TVVisionStreamMetalView(
            frame: .zero,
            device: MTLCreateSystemDefaultDevice(),
            surfaceCallbackHandler: surfaceCallbackHandler
        )
#else
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
#endif
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.enableSetNeedsDisplay = false
        view.isPaused = true
        context.coordinator.presenter.configure(view)
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
#if os(iOS)
        context.coordinator.update(
            renderState: renderState,
            inputOutputHandler: inputOutputHandler,
            userAllowsHDR: userAllowsHDR
        )
        (view as? MobileStreamMetalView)?
            .updateAttachmentEventHandler(attachmentEventHandler)
        (view as? MobileStreamMetalView)?
            .updateAttachmentUpdateHandler(attachmentUpdateHandler)
        (view as? MobileStreamMetalView)?
            .updateSceneLifecycleUpdateHandler(sceneLifecycleUpdateHandler)
        (view as? MobileStreamMetalView)?
            .updateSceneWindowSnapshotHandler(sceneWindowSnapshotHandler)
        (view as? MobileStreamMetalView)?
            .updateDisplayEDREventHandler({
                [weak coordinator = context.coordinator] event in
                coordinator?.handleDisplayEDREvent(event)
                displayEDREventHandler(event)
            })
        (view as? MobileStreamMetalView)?
            .updateGeometryBinding(
                sourceSize: renderState.transform.sourceSize,
                mode: renderState.transform.mode,
                handler: { [weak coordinator = context.coordinator] binding in
                    coordinator?.handleGeometryBinding(binding)
                },
                inputOutputHandler: {
                    [weak coordinator = context.coordinator] output in
                    coordinator?.handleInputOutput(output)
                }
            )
#elseif os(tvOS) || os(visionOS)
        (view as? TVVisionStreamMetalView)?
            .updateSurfaceCallbackHandler(surfaceCallbackHandler)
        context.coordinator.update(
            renderState: renderState,
            inputOutputHandler: { _ in }
        )
#else
        context.coordinator.update(
            renderState: renderState,
            inputOutputHandler: { _ in }
        )
#endif
        let schedule = StreamMetalViewScheduleResolver.resolve(renderState.policy)
        view.isPaused = schedule.isPaused
        view.preferredFramesPerSecond = schedule.preferredFramesPerSecond
#if !os(iOS)
        if let snapshot = renderState.coordinateSnapshot {
            view.drawableSize = CGSize(
                width: snapshot.drawableSize.width,
                height: snapshot.drawableSize.height
            )
        }
#endif
#if os(tvOS) || os(visionOS)
        (view as? TVVisionStreamMetalView)?.refreshSurfaceCallbacks()
#endif
        if schedule.requestsImmediateDraw { view.draw() }
    }

    static func dismantleUIView(
        _ view: MTKView,
        coordinator: MobileStreamSurfaceCoordinator
    ) {
#if os(iOS)
        if let mobileView = view as? MobileStreamMetalView {
            if let surfaceGeneration = mobileView.surfaceGeneration {
                coordinator.deactivateSurfaceGeneration(surfaceGeneration)
            }
            mobileView.invalidateAttachmentCallbacks()
        }
#elseif os(tvOS) || os(visionOS)
        (view as? TVVisionStreamMetalView)?.invalidateSurfaceCallbacks()
#endif
        coordinator.presenter.stop()
        view.delegate = nil
        view.isPaused = true
    }
}
#endif
