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

    @discardableResult
    func publish(
        _ callbacks: [TVVisionUIKitStreamSurfaceCallback]
    ) -> State? {
        guard !isInvalidated,
              !callbacks.isEmpty,
              let surface,
              let stateReader else {
            return nil
        }
        let state = stateReader(surface)
        for callback in callbacks {
            handler?(surface, callback, state)
        }
        return state
    }

    func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        handler = nil
        stateReader = nil
        surface = nil
    }
}

struct TVVisionUIKitWindowObservationNotificationNames: Equatable, Sendable {
    let didBecomeVisible: Notification.Name
    let didBecomeHidden: Notification.Name
    let didBecomeKey: Notification.Name
    let didResignKey: Notification.Name
    let sceneDidActivate: Notification.Name
    let sceneWillDeactivate: Notification.Name
    let sceneDidEnterBackground: Notification.Name
    let sceneWillEnterForeground: Notification.Name
}

enum TVVisionUIKitWindowObservationOutcome: Equatable, Sendable {
    case attached
    case replaced
    case unchanged
    case detached
    case staleSurfaceGeneration
    case invalidated
    case alreadyInvalidated
}

private final class TVVisionUIKitWindowObservationTokens:
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
final class TVVisionUIKitWindowObservation<
    Window: AnyObject,
    WindowScene: AnyObject
> {
    typealias Handler = @MainActor (
        [TVVisionUIKitStreamSurfaceCallback]
    ) -> Void

    let surfaceGeneration: TVVisionGeneration
    var currentWindow: Window? { window }
    var currentWindowScene: WindowScene? { windowScene }

    private let notificationCenter: NotificationCenter
    private let names: TVVisionUIKitWindowObservationNotificationNames
    private let observerTokens: TVVisionUIKitWindowObservationTokens
    private weak var window: Window?
    private weak var windowScene: WindowScene?
    private var observationID: UUID?
    private var handler: Handler?
    private var isInvalidated = false

    init(
        surfaceGeneration: TVVisionGeneration,
        notificationCenter: NotificationCenter,
        names: TVVisionUIKitWindowObservationNotificationNames,
        handler: @escaping Handler
    ) throws {
        try surfaceGeneration.require(.surface)
        self.surfaceGeneration = surfaceGeneration
        self.notificationCenter = notificationCenter
        self.names = names
        observerTokens = TVVisionUIKitWindowObservationTokens(
            notificationCenter: notificationCenter
        )
        self.handler = handler
    }

    @discardableResult
    func attach(
        window candidateWindow: Window,
        windowScene candidateScene: WindowScene,
        surfaceGeneration candidateGeneration: TVVisionGeneration
    ) -> TVVisionUIKitWindowObservationOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        if window === candidateWindow, windowScene === candidateScene {
            return .unchanged
        }

        let outcome: TVVisionUIKitWindowObservationOutcome =
            window == nil && windowScene == nil ? .attached : .replaced
        stopObserving()
        window = candidateWindow
        windowScene = candidateScene
        let nextObservationID = UUID()
        observationID = nextObservationID
        observerTokens.replace([
            observe(
                name: names.didBecomeVisible,
                object: candidateWindow,
                observationID: nextObservationID,
                callbacks: [.visibility, .focusEligibility]
            ),
            observe(
                name: names.didBecomeHidden,
                object: candidateWindow,
                observationID: nextObservationID,
                callbacks: [.visibility, .focusEligibility]
            ),
            observe(
                name: names.didBecomeKey,
                object: candidateWindow,
                observationID: nextObservationID,
                callbacks: [.focusEligibility]
            ),
            observe(
                name: names.didResignKey,
                object: candidateWindow,
                observationID: nextObservationID,
                callbacks: [.focusEligibility]
            ),
            observe(
                name: names.sceneDidActivate,
                object: candidateScene,
                observationID: nextObservationID,
                callbacks: [.windowScene, .visibility, .focusEligibility]
            ),
            observe(
                name: names.sceneWillDeactivate,
                object: candidateScene,
                observationID: nextObservationID,
                callbacks: [.windowScene, .visibility, .focusEligibility]
            ),
            observe(
                name: names.sceneDidEnterBackground,
                object: candidateScene,
                observationID: nextObservationID,
                callbacks: [.windowScene, .visibility, .focusEligibility]
            ),
            observe(
                name: names.sceneWillEnterForeground,
                object: candidateScene,
                observationID: nextObservationID,
                callbacks: [.windowScene, .visibility, .focusEligibility]
            )
        ])
        return outcome
    }

    @discardableResult
    func detach(
        surfaceGeneration candidateGeneration: TVVisionGeneration
    ) -> TVVisionUIKitWindowObservationOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        guard window != nil || windowScene != nil else { return .unchanged }
        stopObserving()
        return .detached
    }

    @discardableResult
    func invalidate(
        surfaceGeneration candidateGeneration: TVVisionGeneration
    ) -> TVVisionUIKitWindowObservationOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        isInvalidated = true
        stopObserving()
        handler = nil
        return .invalidated
    }

    private func observe<Object: AnyObject>(
        name: Notification.Name,
        object: Object,
        observationID: UUID,
        callbacks: [TVVisionUIKitStreamSurfaceCallback]
    ) -> NSObjectProtocol {
        notificationCenter.addObserver(
            forName: name,
            object: object,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.receive(
                    observationID: observationID,
                    callbacks: callbacks
                )
            }
        }
    }

    private func receive(
        observationID candidateObservationID: UUID,
        callbacks: [TVVisionUIKitStreamSurfaceCallback]
    ) {
        guard !isInvalidated,
              observationID == candidateObservationID,
              window != nil,
              windowScene != nil else { return }
        handler?(callbacks)
    }

    private func stopObserving() {
        observerTokens.removeAll()
        observationID = nil
        window = nil
        windowScene = nil
    }
}

enum TVVisionUIKitStreamSurfaceGenerationValidationError:
    Equatable,
    Sendable
{
    case inconsistentAttachment
    case windowSceneMismatch
    case tvOSScreenUnavailable
    case invalidScale
    case invalidDrawableSize
    case focusEligibleWhileInvisible
}

enum TVVisionUIKitStreamSurfaceGenerationStatus: Equatable, Sendable {
    case attached
    case detached
    case invalid(TVVisionUIKitStreamSurfaceGenerationValidationError)
    case invalidated
}

struct TVVisionUIKitStreamSurfaceGenerationState: Equatable, Sendable {
    let platform: TVVisionPlatform
    let surfaceGeneration: TVVisionGeneration
    let callback: TVVisionUIKitStreamSurfaceCallback
    let attachment: TVVisionSurfaceAttachment
    let activity: AppSceneActivity
    let isVisible: Bool
    let scale: Double?
    let drawableSize: PixelSize?
    let isFocusEligible: Bool
}

struct TVVisionUIKitStreamSurfaceResolvedAttachment<
    Window: AnyObject,
    WindowScene: AnyObject,
    Screen: AnyObject
> {
    let window: Window
    let windowScene: WindowScene
    let screen: Screen?
    let activity: AppSceneActivity
}

struct TVVisionUIKitStreamSurfaceGenerationUpdate<
    Surface: AnyObject,
    Window: AnyObject,
    WindowScene: AnyObject,
    Screen: AnyObject
> {
    typealias ResolvedAttachment =
        TVVisionUIKitStreamSurfaceResolvedAttachment<
            Window,
            WindowScene,
            Screen
        >

    let surfaceGeneration: TVVisionGeneration
    let status: TVVisionUIKitStreamSurfaceGenerationStatus
    let state: TVVisionUIKitStreamSurfaceGenerationState?
    let surface: Surface?
    let attachment: ResolvedAttachment?
}

enum TVVisionUIKitStreamSurfaceGenerationOwnerOutcome: Equatable, Sendable {
    case attached
    case detached
    case invalid(TVVisionUIKitStreamSurfaceGenerationValidationError)
    case staleSurfaceGeneration
    case staleSurface
    case invalidated
    case alreadyInvalidated
}

@MainActor
final class TVVisionUIKitStreamSurfaceGenerationOwner<
    Surface: AnyObject,
    Window: AnyObject,
    WindowScene: AnyObject,
    Screen: AnyObject
> {
    typealias RawState = TVVisionUIKitStreamSurfaceState<WindowScene>
    typealias ResolvedAttachment =
        TVVisionUIKitStreamSurfaceResolvedAttachment<
            Window,
            WindowScene,
            Screen
        >
    typealias Update = TVVisionUIKitStreamSurfaceGenerationUpdate<
        Surface,
        Window,
        WindowScene,
        Screen
    >
    typealias Resolver = @MainActor (Surface) -> ResolvedAttachment?
    typealias Handler = @MainActor (Update) -> Void

    let platform: TVVisionPlatform
    let surfaceGeneration: TVVisionGeneration
    var currentSurface: Surface? { surface }
    var currentWindow: Window? { window }
    var currentWindowScene: WindowScene? { windowScene }
    var currentScreen: Screen? { screen }
    private(set) var currentState: TVVisionUIKitStreamSurfaceGenerationState?

    private weak var surface: Surface?
    private weak var window: Window?
    private weak var windowScene: WindowScene?
    private weak var screen: Screen?
    private var resolver: Resolver?
    private var handler: Handler?
    private var isInvalidated = false

    init(
        platform: TVVisionPlatform,
        surfaceGeneration: TVVisionGeneration,
        surface: Surface,
        resolver: @escaping Resolver,
        handler: @escaping Handler
    ) throws {
        try surfaceGeneration.require(.surface)
        self.platform = platform
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
        surfaceGeneration candidateGeneration: TVVisionGeneration,
        callback: TVVisionUIKitStreamSurfaceCallback,
        rawState: RawState
    ) -> TVVisionUIKitStreamSurfaceGenerationOwnerOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        guard surface === candidate else { return .staleSurface }

        let attachment = resolver?(candidate)
        guard rawState.isAttached else {
            guard attachment == nil,
                  rawState.windowScene == nil,
                  !rawState.isVisible,
                  !rawState.isFocusEligible else {
                return reject(
                    .inconsistentAttachment,
                    surface: candidate
                )
            }
            clearAttachment()
            let state = TVVisionUIKitStreamSurfaceGenerationState(
                platform: platform,
                surfaceGeneration: surfaceGeneration,
                callback: callback,
                attachment: .detached,
                activity: .background,
                isVisible: false,
                scale: nil,
                drawableSize: nil,
                isFocusEligible: false
            )
            currentState = state
            handler?(
                Update(
                    surfaceGeneration: surfaceGeneration,
                    status: .detached,
                    state: state,
                    surface: candidate,
                    attachment: nil
                )
            )
            return .detached
        }

        guard let attachment else {
            return reject(.inconsistentAttachment, surface: candidate)
        }
        guard rawState.windowScene === attachment.windowScene else {
            return reject(.windowSceneMismatch, surface: candidate)
        }
        if platform == .tvOS, attachment.screen == nil {
            return reject(.tvOSScreenUnavailable, surface: candidate)
        }
        guard rawState.scale.isFinite,
              rawState.scale > 0,
              rawState.scale <= TVVisionSurfaceGeometry.maximumScale else {
            return reject(.invalidScale, surface: candidate)
        }
        guard let drawableSize = Self.pixelSize(rawState.drawableSize) else {
            return reject(.invalidDrawableSize, surface: candidate)
        }
        guard !rawState.isFocusEligible || rawState.isVisible else {
            return reject(
                .focusEligibleWhileInvisible,
                surface: candidate
            )
        }

        window = attachment.window
        windowScene = attachment.windowScene
        screen = attachment.screen
        let state = TVVisionUIKitStreamSurfaceGenerationState(
            platform: platform,
            surfaceGeneration: surfaceGeneration,
            callback: callback,
            attachment: .attached,
            activity: attachment.activity,
            isVisible: rawState.isVisible,
            scale: rawState.scale,
            drawableSize: drawableSize,
            isFocusEligible: rawState.isFocusEligible
                && attachment.activity == .active
        )
        currentState = state
        handler?(
            Update(
                surfaceGeneration: surfaceGeneration,
                status: .attached,
                state: state,
                surface: candidate,
                attachment: attachment
            )
        )
        return .attached
    }

    @discardableResult
    func invalidate(
        surface candidate: Surface? = nil,
        surfaceGeneration candidateGeneration: TVVisionGeneration
    ) -> TVVisionUIKitStreamSurfaceGenerationOwnerOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        if let candidate, surface !== candidate { return .staleSurface }

        isInvalidated = true
        let update = Update(
            surfaceGeneration: surfaceGeneration,
            status: .invalidated,
            state: nil,
            surface: surface,
            attachment: nil
        )
        clearAttachment()
        currentState = nil
        surface = nil
        resolver = nil
        let currentHandler = handler
        handler = nil
        currentHandler?(update)
        return .invalidated
    }

    private func reject(
        _ error: TVVisionUIKitStreamSurfaceGenerationValidationError,
        surface candidate: Surface
    ) -> TVVisionUIKitStreamSurfaceGenerationOwnerOutcome {
        clearAttachment()
        currentState = nil
        handler?(
            Update(
                surfaceGeneration: surfaceGeneration,
                status: .invalid(error),
                state: nil,
                surface: candidate,
                attachment: nil
            )
        )
        return .invalid(error)
    }

    private func clearAttachment() {
        window = nil
        windowScene = nil
        screen = nil
    }

    private static func pixelSize(_ size: CGSize) -> PixelSize? {
        let width = Double(size.width)
        let height = Double(size.height)
        let maximum = Double(TVVisionSurfaceGeometry.maximumDrawableDimension)
        guard width.isFinite,
              height.isFinite,
              width > 0,
              height > 0,
              width <= maximum,
              height <= maximum else {
            return nil
        }
        return PixelSize(
            width: Int(width.rounded(.toNearestOrAwayFromZero)),
            height: Int(height.rounded(.toNearestOrAwayFromZero))
        )
    }
}

struct TVVisionUIKitStreamSurfaceGeometryReading: Equatable, Sendable {
    let viewBounds: TVVisionRect
    let windowBounds: TVVisionRect
    let safeAreaInsets: TVVisionEdgeInsets
    let scale: Double
}

enum TVVisionStreamGeometryBindingClosureReason: Equatable, Sendable {
    case detached
    case invalidSurfaceState(
        TVVisionUIKitStreamSurfaceGenerationValidationError
    )
    case inconsistentSurfaceState
    case geometryUnavailable
    case invalidGeometry(TVVisionGeometryValidationError)
    case coordinateUnavailable
    case drawableApplicationFailed
    case invalidated
}

enum TVVisionStreamGeometryBindingStatus: Equatable, Sendable {
    case active
    case closed(TVVisionStreamGeometryBindingClosureReason)
}

struct TVVisionStreamAbsoluteInputMapping: Equatable, Sendable {
    let revision: TVVisionSemanticRevision
    let point: RemotePoint
    let referenceSize: PixelSize
}

struct TVVisionStreamGeometryBindingSnapshot: Equatable, Sendable {
    let platform: TVVisionPlatform
    let surfaceGeneration: TVVisionGeneration
    let revision: TVVisionSemanticRevision
    let sceneSurfaceSnapshot: TVVisionSceneSurfaceSnapshot
    let isFocusEligible: Bool
    let coordinateSnapshot: StreamCoordinateSnapshot
    let inputReferenceSize: PixelSize
}

struct TVVisionStreamGeometryBindingUpdate: Equatable, Sendable {
    let platform: TVVisionPlatform
    let surfaceGeneration: TVVisionGeneration
    let revision: TVVisionSemanticRevision
    let status: TVVisionStreamGeometryBindingStatus
    let binding: TVVisionStreamGeometryBindingSnapshot?
}

enum TVVisionStreamGeometryBindingOutcome: Equatable, Sendable {
    case published
    case unchanged
    case closed(TVVisionStreamGeometryBindingClosureReason)
    case staleSurfaceGeneration
    case staleSurface
    case revisionExhausted
    case invalidated
    case alreadyInvalidated
}

@MainActor
final class TVVisionUIKitStreamGeometryBindingOwner<
    Surface: AnyObject,
    Window: AnyObject,
    WindowScene: AnyObject,
    Screen: AnyObject
> {
    typealias GenerationUpdate = TVVisionUIKitStreamSurfaceGenerationUpdate<
        Surface,
        Window,
        WindowScene,
        Screen
    >
    typealias GeometryReader = @MainActor (
        Surface
    ) -> TVVisionUIKitStreamSurfaceGeometryReading?
    typealias DrawableApplier = @MainActor (Surface, PixelSize) -> Bool
    typealias Handler = @MainActor (TVVisionStreamGeometryBindingUpdate) -> Void

    private struct ActiveInputs: Equatable {
        let activity: AppSceneActivity
        let isVisible: Bool
        let isFocusEligible: Bool
        let geometry: TVVisionSurfaceGeometry
        let sourceSize: PixelSize
        let mode: RenderScaleMode
    }

    private enum SemanticState: Equatable {
        case active(ActiveInputs)
        case closed(TVVisionStreamGeometryBindingClosureReason)
    }

    let platform: TVVisionPlatform
    let surfaceGeneration: TVVisionGeneration
    var currentSurface: Surface? { surface }
    var currentBinding: TVVisionStreamGeometryBindingSnapshot? {
        currentUpdate?.binding
    }
    private(set) var currentRevision: TVVisionSemanticRevision?
    private(set) var currentUpdate: TVVisionStreamGeometryBindingUpdate?
    private(set) var isRevisionExhausted = false

    private weak var surface: Surface?
    private var sourceSize: PixelSize
    private var mode: RenderScaleMode
    private var generationState: TVVisionUIKitStreamSurfaceGenerationState?
    private var semanticState: SemanticState?
    private var appliedDrawableSize: PixelSize?
    private var geometryReader: GeometryReader?
    private var drawableApplier: DrawableApplier?
    private var handler: Handler?
    private var isInvalidated = false

    init(
        platform: TVVisionPlatform,
        surfaceGeneration: TVVisionGeneration,
        surface: Surface,
        sourceSize: PixelSize,
        mode: RenderScaleMode,
        initialRevision: TVVisionSemanticRevision? = nil,
        geometryReader: @escaping GeometryReader,
        drawableApplier: @escaping DrawableApplier,
        handler: @escaping Handler
    ) throws {
        try surfaceGeneration.require(.surface)
        self.platform = platform
        self.surfaceGeneration = surfaceGeneration
        self.surface = surface
        self.sourceSize = sourceSize
        self.mode = mode
        currentRevision = initialRevision
        self.geometryReader = geometryReader
        self.drawableApplier = drawableApplier
        self.handler = handler
    }

    func updateHandler(_ handler: @escaping Handler) {
        guard !isInvalidated else { return }
        self.handler = handler
    }

    @discardableResult
    func handle(
        _ update: GenerationUpdate
    ) -> TVVisionStreamGeometryBindingOutcome {
        guard update.surfaceGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        guard let candidate = update.surface,
              surface === candidate else {
            return .staleSurface
        }

        switch update.status {
        case .attached:
            guard let state = update.state,
                  state.platform == platform,
                  state.surfaceGeneration == surfaceGeneration,
                  state.attachment == .attached else {
                generationState = nil
                return publishClosed(
                    .inconsistentSurfaceState,
                    clearDrawable: true
                )
            }
            generationState = state
            return resolveActiveBinding()
        case .detached:
            generationState = update.state
            return publishClosed(.detached, clearDrawable: true)
        case let .invalid(error):
            generationState = nil
            return publishClosed(
                .invalidSurfaceState(error),
                clearDrawable: true
            )
        case .invalidated:
            return terminateFromGenerationOwner()
        }
    }

    @discardableResult
    func updateRenderInputs(
        sourceSize: PixelSize,
        mode: RenderScaleMode,
        surface candidate: Surface,
        surfaceGeneration candidateGeneration: TVVisionGeneration
    ) -> TVVisionStreamGeometryBindingOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        guard surface === candidate else { return .staleSurface }
        guard self.sourceSize != sourceSize || self.mode != mode else {
            return currentUpdate == nil ? resolveActiveBinding() : .unchanged
        }
        self.sourceSize = sourceSize
        self.mode = mode
        return resolveActiveBinding()
    }

    @discardableResult
    func replayCurrentUpdate(
        surface candidate: Surface,
        surfaceGeneration candidateGeneration: TVVisionGeneration
    ) -> Bool {
        guard candidateGeneration == surfaceGeneration,
              !isInvalidated,
              surface === candidate,
              let currentUpdate else { return false }
        handler?(currentUpdate)
        return true
    }

    func absoluteInputMapping(
        localPoint: RemotePoint
    ) -> TVVisionStreamAbsoluteInputMapping? {
        guard let binding = currentBinding else { return nil }
        let geometry = binding.sceneSurfaceSnapshot.geometry
        guard let geometry,
              localPoint.x.isFinite,
              localPoint.y.isFinite,
              localPoint.x >= geometry.viewBounds.x,
              localPoint.y >= geometry.viewBounds.y,
              localPoint.x <= geometry.viewBounds.x
                + geometry.viewBounds.width,
              localPoint.y <= geometry.viewBounds.y
                + geometry.viewBounds.height else {
            return nil
        }
        let drawableX = (localPoint.x - geometry.viewBounds.x) * geometry.scale
        let drawableY = (localPoint.y - geometry.viewBounds.y) * geometry.scale
        guard drawableX.isFinite,
              drawableY.isFinite,
              let point = InputMapper(
                  snapshot: binding.coordinateSnapshot
              ).remotePoint(localX: drawableX, localY: drawableY) else {
            return nil
        }
        return TVVisionStreamAbsoluteInputMapping(
            revision: binding.revision,
            point: point,
            referenceSize: binding.inputReferenceSize
        )
    }

    @discardableResult
    func invalidate(
        surface candidate: Surface? = nil,
        surfaceGeneration candidateGeneration: TVVisionGeneration
    ) -> TVVisionStreamGeometryBindingOutcome {
        guard candidateGeneration == surfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard !isInvalidated else { return .alreadyInvalidated }
        if let candidate, surface !== candidate { return .staleSurface }
        let outcome = publishClosed(.invalidated, clearDrawable: true)
        finishInvalidation()
        return outcome == .revisionExhausted ? .revisionExhausted : .invalidated
    }

    private func resolveActiveBinding()
        -> TVVisionStreamGeometryBindingOutcome
    {
        guard !isRevisionExhausted else { return .revisionExhausted }
        guard let generationState,
              generationState.attachment == .attached,
              let surface,
              let reading = geometryReader?(surface) else {
            return publishClosed(.geometryUnavailable, clearDrawable: true)
        }

        let geometry: TVVisionSurfaceGeometry
        do {
            geometry = try TVVisionSurfaceGeometry(
                platform: platform,
                surfaceGeneration: surfaceGeneration,
                viewBounds: reading.viewBounds,
                windowBounds: reading.windowBounds,
                safeAreaInsets: reading.safeAreaInsets,
                scale: reading.scale
            )
        } catch let error as TVVisionPlatformContractError {
            guard case let .invalidGeometry(reason) = error else {
                return publishClosed(
                    .inconsistentSurfaceState,
                    clearDrawable: true
                )
            }
            return publishClosed(
                .invalidGeometry(reason),
                clearDrawable: true
            )
        } catch {
            return publishClosed(
                .invalidGeometry(.invalidViewBounds),
                clearDrawable: true
            )
        }

        guard generationState.scale == geometry.scale else {
            return publishClosed(
                .inconsistentSurfaceState,
                clearDrawable: true
            )
        }
        guard applyDrawableSize(geometry.drawableSize) else {
            return publishClosed(
                .drawableApplicationFailed,
                clearDrawable: true
            )
        }

        let inputs = ActiveInputs(
            activity: generationState.activity,
            isVisible: generationState.isVisible,
            isFocusEligible: generationState.isFocusEligible,
            geometry: geometry,
            sourceSize: sourceSize,
            mode: mode
        )
        let nextSemanticState = SemanticState.active(inputs)
        guard nextSemanticState != semanticState else { return .unchanged }
        guard let revision = nextRevision() else {
            exhaustRevision()
            return .revisionExhausted
        }
        guard let coordinateSnapshot = StreamCoordinateSnapshot.resolve(
            revision: revision.rawValue,
            sourceSize: sourceSize,
            drawableSize: geometry.drawableSize,
            mode: mode
        ) else {
            return publishClosed(
                .coordinateUnavailable,
                clearDrawable: true
            )
        }

        let sceneSurfaceSnapshot: TVVisionSceneSurfaceSnapshot
        do {
            sceneSurfaceSnapshot = try TVVisionSceneSurfaceSnapshot(
                platform: platform,
                revision: revision,
                surfaceGeneration: surfaceGeneration,
                activity: generationState.activity,
                attachment: .attached,
                isVisible: generationState.isVisible,
                geometry: geometry
            )
        } catch {
            return publishClosed(
                .inconsistentSurfaceState,
                clearDrawable: true
            )
        }

        let binding = TVVisionStreamGeometryBindingSnapshot(
            platform: platform,
            surfaceGeneration: surfaceGeneration,
            revision: revision,
            sceneSurfaceSnapshot: sceneSurfaceSnapshot,
            isFocusEligible: generationState.isFocusEligible,
            coordinateSnapshot: coordinateSnapshot,
            inputReferenceSize: coordinateSnapshot.sourceSize
        )
        let update = TVVisionStreamGeometryBindingUpdate(
            platform: platform,
            surfaceGeneration: surfaceGeneration,
            revision: revision,
            status: .active,
            binding: binding
        )
        currentRevision = revision
        semanticState = nextSemanticState
        currentUpdate = update
        handler?(update)
        return .published
    }

    private func publishClosed(
        _ requestedReason: TVVisionStreamGeometryBindingClosureReason,
        clearDrawable: Bool
    ) -> TVVisionStreamGeometryBindingOutcome {
        guard !isRevisionExhausted else { return .revisionExhausted }
        let reason: TVVisionStreamGeometryBindingClosureReason
        if clearDrawable, !applyDrawableSize(.zero) {
            reason = .drawableApplicationFailed
        } else {
            reason = requestedReason
        }
        let nextSemanticState = SemanticState.closed(reason)
        guard nextSemanticState != semanticState else { return .unchanged }
        guard let revision = nextRevision() else {
            exhaustRevision()
            return .revisionExhausted
        }
        let update = TVVisionStreamGeometryBindingUpdate(
            platform: platform,
            surfaceGeneration: surfaceGeneration,
            revision: revision,
            status: .closed(reason),
            binding: nil
        )
        currentRevision = revision
        semanticState = nextSemanticState
        currentUpdate = update
        handler?(update)
        return .closed(reason)
    }

    private func nextRevision() -> TVVisionSemanticRevision? {
        if let currentRevision {
            return try? currentRevision.advanced()
        }
        return try? TVVisionSemanticRevision(rawValue: 1)
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

    private func exhaustRevision() {
        isRevisionExhausted = true
        semanticState = nil
        currentUpdate = nil
        generationState = nil
        _ = applyDrawableSize(.zero)
    }

    private func terminateFromGenerationOwner()
        -> TVVisionStreamGeometryBindingOutcome
    {
        let outcome = publishClosed(.invalidated, clearDrawable: true)
        finishInvalidation()
        return outcome == .revisionExhausted ? .revisionExhausted : .invalidated
    }

    private func finishInvalidation() {
        isInvalidated = true
        generationState = nil
        surface = nil
        geometryReader = nil
        drawableApplier = nil
        handler = nil
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
    private var usesPlatformFrameAdmission = false
    private var platformAdmittedFrame: DecodedVideoFrame?
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
            usesPlatformFrameAdmission = false
            platformAdmittedFrame = nil
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
    func beginPlatformFrameAdmission() {
        let shouldClear = withLock {
            let shouldClear = !usesPlatformFrameAdmission
                || platformAdmittedFrame != nil
            usesPlatformFrameAdmission = true
            platformAdmittedFrame = nil
            if shouldClear {
                requiresClearBeforePresentation = true
                presentationRevision &+= 1
            }
            return shouldClear
        }
        if shouldClear { surfaceView?.draw() }
    }

    @MainActor
    func presentPlatformAdmittedFrame(_ frame: DecodedVideoFrame) {
        withLock {
            usesPlatformFrameAdmission = true
            platformAdmittedFrame = frame
            presentationRevision &+= 1
        }
        surfaceView?.draw()
    }

    @MainActor
    func clearPlatformFrameAdmission() {
        let shouldClear = withLock {
            let shouldClear = !usesPlatformFrameAdmission
                || platformAdmittedFrame != nil
            usesPlatformFrameAdmission = true
            platformAdmittedFrame = nil
            if shouldClear {
                requiresClearBeforePresentation = true
                presentationRevision &+= 1
            }
            return shouldClear
        }
        if shouldClear { surfaceView?.draw() }
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
                presentationRevision,
                usesPlatformFrameAdmission,
                platformAdmittedFrame
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
        let frame = snapshot.6
            ? snapshot.7
            : presentationSource.currentFrame()
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
            usesPlatformFrameAdmission = false
            platformAdmittedFrame = nil
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

enum TVVisionMetalPresentationOwnerError: Error, Equatable, Sendable {
    case invalidSnapshot
    case invalidVideoApplication
}

struct TVVisionMetalPresentationOwnerSnapshot: Equatable, Sendable {
    let surfaceGeneration: TVVisionGeneration?
    let coordinatorSurfaceGeneration: TVVisionGeneration?
    let admittedFrameSurfaceGeneration: TVVisionGeneration?
    let ownership: TVVisionPresentationOwnership?
    let sequence: UInt64?
    let platformRevision: TVVisionSemanticRevision?
    let deliveryRevision: UInt64?
    let decoderGeneration: UInt64?
    let frameID: UInt64?
    let isSceneEligible: Bool
    let isDisplayAvailable: Bool?
    let acceptedFrameCount: UInt64
    let clearCount: UInt64
}

@MainActor
final class TVVisionMetalPresentationOwner:
    TVVisionPlatformPresentationActionApplying
{
    private weak var presenter: StreamMetalPresenter?
    private var surfaceGeneration: TVVisionGeneration?
    private var coordinatorSurfaceGeneration: TVVisionGeneration?
    private var admittedFrameSurfaceGeneration: TVVisionGeneration?
    private var ownership: TVVisionPresentationOwnership?
    private var sequence: UInt64?
    private var platformRevision: TVVisionSemanticRevision?
    private var deliveryRevision: UInt64?
    private var decoderGeneration: UInt64?
    private var frameID: UInt64?
    private var admittedFrame: DecodedVideoFrame?
    private var isSceneEligible = false
    private var isDisplayAvailable: Bool?
    private var acceptedFrameCount: UInt64 = 0
    private var clearCount: UInt64 = 0

    func bind(
        presenter: StreamMetalPresenter,
        surfaceGeneration: TVVisionGeneration
    ) {
        guard surfaceGeneration.domain == .surface else { return }
        if self.presenter !== presenter
            || self.surfaceGeneration != surfaceGeneration {
            self.presenter?.clearPlatformFrameAdmission()
        }
        self.presenter = presenter
        self.surfaceGeneration = surfaceGeneration
        presenter.beginPlatformFrameAdmission()
        applyCurrentFrameIfEligible()
    }

    func unbind(
        presenter: StreamMetalPresenter,
        surfaceGeneration: TVVisionGeneration
    ) {
        guard self.presenter === presenter,
              self.surfaceGeneration == surfaceGeneration else { return }
        presenter.clearPlatformFrameAdmission()
        self.presenter = nil
        self.surfaceGeneration = nil
    }

    func apply(
        _ application: TVVisionPlatformPresentationActionApplication
    ) async throws {
        switch application.effect {
        case let .snapshot(snapshot):
            try applySnapshot(snapshot, application: application)
        default:
            guard ownership == application.ownership else { return }
            guard admits(sequence: application.sequence) else { return }
            switch application.effect {
            case let .scene(scene):
                coordinatorSurfaceGeneration = scene?.surfaceGeneration
                isSceneEligible = scene?.attachment == .attached
                    && scene?.activity == .active
                    && scene?.isVisible == true
                    && scene?.geometry != nil
                guard isSceneEligible else {
                    clearFrame()
                    return
                }
                applyCurrentFrameIfEligible()
            case let .video(video):
                try applyVideo(video, application: application)
            case .clearVideo, .teardown:
                clearFrame()
                if case .teardown = application.effect {
                    coordinatorSurfaceGeneration = nil
                    isSceneEligible = false
                    isDisplayAvailable = nil
                    ownership = nil
                }
            case let .display(display):
                isDisplayAvailable = display?.isOutputAvailable
                if isDisplayAvailable == false {
                    clearFrame()
                } else {
                    applyCurrentFrameIfEligible()
                }
            case .input, .audioRoute:
                break
            case .snapshot:
                break
            }
        }
    }

    func snapshot() -> TVVisionMetalPresentationOwnerSnapshot {
        TVVisionMetalPresentationOwnerSnapshot(
            surfaceGeneration: surfaceGeneration,
            coordinatorSurfaceGeneration: coordinatorSurfaceGeneration,
            admittedFrameSurfaceGeneration: admittedFrameSurfaceGeneration,
            ownership: ownership,
            sequence: sequence,
            platformRevision: platformRevision,
            deliveryRevision: deliveryRevision,
            decoderGeneration: decoderGeneration,
            frameID: frameID,
            isSceneEligible: isSceneEligible,
            isDisplayAvailable: isDisplayAvailable,
            acceptedFrameCount: acceptedFrameCount,
            clearCount: clearCount
        )
    }

    private func applySnapshot(
        _ snapshot: TVVisionPlatformPresentationCoordinatorSnapshot,
        application: TVVisionPlatformPresentationActionApplication
    ) throws {
        guard snapshot.ownership == application.ownership,
              snapshot.sequence == application.sequence else {
            throw TVVisionMetalPresentationOwnerError.invalidSnapshot
        }
        switch snapshot.phase {
        case .active:
            if let ownership,
               ownership != application.ownership,
               !isNewer(application.ownership, than: ownership) {
                return
            }
            if ownership != application.ownership {
                clearFrame()
                self.ownership = application.ownership
                sequence = application.sequence
                platformRevision = nil
                deliveryRevision = nil
                decoderGeneration = nil
                frameID = nil
                admittedFrame = nil
                admittedFrameSurfaceGeneration = nil
                coordinatorSurfaceGeneration = nil
                isSceneEligible = false
                isDisplayAvailable = nil
            } else {
                guard admits(sequence: application.sequence) else { return }
            }
        case .stopped, .failed:
            guard ownership == application.ownership,
                  admits(sequence: application.sequence) else { return }
            clearFrame()
            coordinatorSurfaceGeneration = nil
            isSceneEligible = false
            isDisplayAvailable = nil
            ownership = nil
        }
    }

    private func applyVideo(
        _ video: TVVisionPlatformVideoPresentationApplication,
        application: TVVisionPlatformPresentationActionApplication
    ) throws {
        guard video.ownership == application.ownership,
              video.sequence == application.sequence,
              video.surfaceGeneration.domain == .surface,
              video.delivery.ownership.sessionID == video.ownership.sessionID,
              video.delivery.ownership.mediaGeneration
                == video.ownership.mediaGeneration,
              case let .decodedFrame(_, frame) = video.delivery else {
            throw TVVisionMetalPresentationOwnerError.invalidVideoApplication
        }
        guard video.surfaceGeneration == coordinatorSurfaceGeneration else { return }
        let incomingDeliveryRevision = video.delivery.ownership.revision
        if let deliveryRevision,
           incomingDeliveryRevision < deliveryRevision { return }
        if let platformRevision {
            if video.platformRevision < platformRevision { return }
            if video.platformRevision == platformRevision,
               let deliveryRevision,
               incomingDeliveryRevision <= deliveryRevision {
                return
            }
        }
        if incomingDeliveryRevision == deliveryRevision,
           let decoderGeneration,
           let frameID,
           (frame.generation != decoderGeneration || frame.frameID != frameID) {
            return
        }
        if let decoderGeneration {
            if frame.generation < decoderGeneration { return }
            if frame.generation == decoderGeneration,
               let frameID,
               frame.frameID <= frameID,
               video.platformRevision == platformRevision {
                return
            }
        }
        platformRevision = video.platformRevision
        deliveryRevision = incomingDeliveryRevision
        decoderGeneration = frame.generation
        frameID = frame.frameID
        admittedFrame = frame
        admittedFrameSurfaceGeneration = video.surfaceGeneration
        if acceptedFrameCount < .max { acceptedFrameCount += 1 }
        applyCurrentFrameIfEligible()
    }

    private func admits(sequence candidate: UInt64) -> Bool {
        if let sequence, candidate < sequence { return false }
        sequence = candidate
        return true
    }

    private func applyCurrentFrameIfEligible() {
        guard let presenter,
              isSceneEligible,
              isDisplayAvailable != false,
              surfaceGeneration == coordinatorSurfaceGeneration,
              admittedFrameSurfaceGeneration == surfaceGeneration,
              let admittedFrame else { return }
        presenter.presentPlatformAdmittedFrame(admittedFrame)
    }

    private func clearFrame() {
        admittedFrame = nil
        admittedFrameSurfaceGeneration = nil
        decoderGeneration = nil
        frameID = nil
        presenter?.clearPlatformFrameAdmission()
        if clearCount < .max { clearCount += 1 }
    }

    private func isNewer(
        _ candidate: TVVisionPresentationOwnership,
        than current: TVVisionPresentationOwnership
    ) -> Bool {
        guard candidate.platform == current.platform,
              candidate.sessionID == current.sessionID else { return false }
        if candidate.mediaGeneration != current.mediaGeneration {
            return candidate.mediaGeneration > current.mediaGeneration
        }
        if candidate.presentationGeneration != current.presentationGeneration {
            return candidate.presentationGeneration
                > current.presentationGeneration
        }
        return candidate.inputGeneration > current.inputGeneration
    }
}

enum MobileStreamDisplayBindingOutcome: Equatable, Sendable {
    case applied
    case unchanged
    case inactiveSurfaceGeneration
    case staleSurfaceGeneration
    case revisionExhausted
}

enum TVVisionStreamGeometryApplicationOutcome: Equatable, Sendable {
    case applied
    case unchanged
    case inactiveSurfaceGeneration
    case staleSurfaceGeneration
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
    private(set) var currentTVVisionSurfaceGeneration: TVVisionGeneration?
    private(set) var currentTVVisionGeometryUpdate:
        TVVisionStreamGeometryBindingUpdate?
    private(set) var isDisplayRevisionExhausted = false
    private var renderState: StreamRenderState
    private var inputOutputHandler: InputOutputHandler
    private var userAllowsHDR: Bool
    private let platformCapabilities: HDRPlatformOutputCapabilities
    private var ownsMobileGeometry = false
    private var ownsMobileDisplay = false
    private var ownsTVVisionGeometry = false
    private weak var tvVisionPresentationOwner:
        TVVisionMetalPresentationOwner?

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
        currentTVVisionSurfaceGeneration = nil
        currentTVVisionGeometryUpdate = nil
        ownsTVVisionGeometry = false
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

    func activateTVVisionSurfaceGeneration(
        _ surfaceGeneration: TVVisionGeneration
    ) {
        guard surfaceGeneration.domain == .surface else { return }
        guard currentTVVisionSurfaceGeneration != surfaceGeneration else {
            return
        }
        currentSurfaceGeneration = nil
        currentGeometryBinding = nil
        ownsMobileGeometry = false
        currentTVVisionSurfaceGeneration = surfaceGeneration
        currentTVVisionGeometryUpdate = nil
        ownsTVVisionGeometry = true
        applyCurrentState()
    }

    func bindTVVisionPresentationOwner(
        _ owner: TVVisionMetalPresentationOwner,
        surfaceGeneration: TVVisionGeneration
    ) {
        tvVisionPresentationOwner = owner
        owner.bind(
            presenter: presenter,
            surfaceGeneration: surfaceGeneration
        )
    }

    func deactivateTVVisionSurfaceGeneration(
        _ surfaceGeneration: TVVisionGeneration
    ) {
        guard currentTVVisionSurfaceGeneration == surfaceGeneration else {
            return
        }
        currentTVVisionGeometryUpdate = nil
        ownsTVVisionGeometry = true
        applyCurrentState()
        tvVisionPresentationOwner?.unbind(
            presenter: presenter,
            surfaceGeneration: surfaceGeneration
        )
        currentTVVisionSurfaceGeneration = nil
        ownsTVVisionGeometry = false
    }

    @discardableResult
    func handleTVVisionGeometryUpdate(
        _ update: TVVisionStreamGeometryBindingUpdate
    ) -> TVVisionStreamGeometryApplicationOutcome {
        guard let currentTVVisionSurfaceGeneration else {
            return .inactiveSurfaceGeneration
        }
        guard update.surfaceGeneration == currentTVVisionSurfaceGeneration else {
            return .staleSurfaceGeneration
        }
        guard currentTVVisionGeometryUpdate != update else { return .unchanged }
        ownsTVVisionGeometry = true
        currentTVVisionGeometryUpdate = update
        applyCurrentState()
        return .applied
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
        if ownsTVVisionGeometry {
            renderState.applyPlatformCoordinateSnapshot(
                currentTVVisionGeometryUpdate?.binding?.coordinateSnapshot
            )
        } else if let coordinateSnapshot =
            currentGeometryBinding?.coordinateSnapshot {
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
extension TVVisionUIKitWindowObservationNotificationNames {
    static let current = TVVisionUIKitWindowObservationNotificationNames(
        didBecomeVisible: UIWindow.didBecomeVisibleNotification,
        didBecomeHidden: UIWindow.didBecomeHiddenNotification,
        didBecomeKey: UIWindow.didBecomeKeyNotification,
        didResignKey: UIWindow.didResignKeyNotification,
        sceneDidActivate: UIScene.didActivateNotification,
        sceneWillDeactivate: UIScene.willDeactivateNotification,
        sceneDidEnterBackground: UIScene.didEnterBackgroundNotification,
        sceneWillEnterForeground: UIScene.willEnterForegroundNotification
    )
}

@MainActor
enum TVVisionStreamSurfaceGenerationSequence {
    private static var nextRawValue: UInt64 = 1
    private static var isExhausted = false

    static func next() -> TVVisionGeneration? {
        guard !isExhausted else { return nil }
        let generation = try? TVVisionGeneration(
            domain: .surface,
            rawValue: nextRawValue
        )
        if nextRawValue == UInt64.max {
            isExhausted = true
        } else {
            nextRawValue += 1
        }
        return generation
    }
}

@MainActor
final class TVVisionStreamMetalView: MTKView {
    typealias SurfaceRelay = TVVisionUIKitStreamSurfaceRelay<
        TVVisionStreamMetalView,
        UIWindowScene
    >
    typealias SurfaceCallbackHandler = SurfaceRelay.Handler
    typealias WindowObservation = TVVisionUIKitWindowObservation<
        UIWindow,
        UIWindowScene
    >
#if os(tvOS)
    typealias SurfaceGenerationOwner =
        TVVisionUIKitStreamSurfaceGenerationOwner<
            TVVisionStreamMetalView,
            UIWindow,
            UIWindowScene,
            UIScreen
        >
    typealias GeometryBindingOwner =
        TVVisionUIKitStreamGeometryBindingOwner<
            TVVisionStreamMetalView,
            UIWindow,
            UIWindowScene,
            UIScreen
        >
#else
    typealias SurfaceGenerationOwner =
        TVVisionUIKitStreamSurfaceGenerationOwner<
            TVVisionStreamMetalView,
            UIWindow,
            UIWindowScene,
            NSObject
        >
    typealias GeometryBindingOwner =
        TVVisionUIKitStreamGeometryBindingOwner<
            TVVisionStreamMetalView,
            UIWindow,
            UIWindowScene,
            NSObject
        >
#endif
    typealias SurfaceGenerationUpdateHandler = SurfaceGenerationOwner.Handler
    typealias GeometryBindingUpdateHandler = GeometryBindingOwner.Handler
    typealias DisplayHDREventHandler = @MainActor (
        TVOSDisplayHDRObserverEvent
    ) -> Void
    typealias RemotePressEventHandler = @MainActor (
        TVRemoteSurfacePressEvent
    ) -> TVRemoteSurfacePressDisposition
    typealias ReservedRemoteCommandHandler = @MainActor (
        TVRemoteReservedCommand
    ) -> Void

    var surfaceGeneration: TVVisionGeneration? {
        surfaceGenerationOwner?.surfaceGeneration
    }

    private var surfaceRelay: SurfaceRelay?
    private var windowObservation: WindowObservation?
    private var surfaceGenerationOwner: SurfaceGenerationOwner?
    private var geometryBindingOwner: GeometryBindingOwner?
    private var surfaceGenerationUpdateHandler:
        SurfaceGenerationUpdateHandler = { _ in }
    private var geometryBindingUpdateHandler:
        GeometryBindingUpdateHandler = { _ in }
    private var displayHDREventHandler: DisplayHDREventHandler = { _ in }
    private var remotePressEventHandler: RemotePressEventHandler = { _ in .local }
    private var reservedRemoteCommandHandler: ReservedRemoteCommandHandler = { _ in }
    private var traitChangeRegistration:
        (any UITraitChangeRegistration)?
#if os(tvOS)
    private typealias DisplayHDRObserver =
        TVOSDisplayHDRObserver<UIScreen, CAMetalLayer>
    private var displayHDRObserver: DisplayHDRObserver?

    private struct ActiveUIKitPress {
        let surfaceGeneration: TVVisionGeneration
        let pressID: UInt64
        let button: TVRemoteButton
        let disposition: TVRemoteSurfacePressDisposition
    }

    private var activeUIKitPresses: [ObjectIdentifier: ActiveUIKitPress] = [:]
    private var activeReservedPresses = Set<ObjectIdentifier>()
    private var nextRemotePressID: UInt64 = 1

    override var canBecomeFocused: Bool {
        isUserInteractionEnabled && !isHidden && alpha > 0
    }
#endif

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
        sourceSize: PixelSize = .zero,
        mode: RenderScaleMode = .fit,
        surfaceCallbackHandler:
            @escaping SurfaceCallbackHandler = { _, _, _ in },
        surfaceGenerationUpdateHandler:
            @escaping SurfaceGenerationUpdateHandler = { _ in },
        geometryBindingUpdateHandler:
            @escaping GeometryBindingUpdateHandler = { _ in },
        displayHDREventHandler:
            @escaping DisplayHDREventHandler = { _ in },
        remotePressEventHandler:
            @escaping RemotePressEventHandler = { _ in .local },
        reservedRemoteCommandHandler:
            @escaping ReservedRemoteCommandHandler = { _ in }
    ) {
        super.init(frame: frameRect, device: device)
        autoResizeDrawable = false
        self.surfaceGenerationUpdateHandler =
            surfaceGenerationUpdateHandler
        self.geometryBindingUpdateHandler = geometryBindingUpdateHandler
        self.displayHDREventHandler = displayHDREventHandler
        self.remotePressEventHandler = remotePressEventHandler
        self.reservedRemoteCommandHandler = reservedRemoteCommandHandler
        surfaceRelay = SurfaceRelay(
            surface: self,
            stateReader: { surface in
                let window = surface.window
                let isAttached = window != nil
                let isVisible = isAttached
                    && !surface.isHidden
                    && surface.alpha > 0
                    && window?.isHidden == false
#if os(tvOS)
                let isFocusEligible = isVisible
                    && surface.isUserInteractionEnabled
                    && surface.canBecomeFocused
#else
                let isFocusEligible = isVisible
                    && surface.isUserInteractionEnabled
                    && window?.isKeyWindow == true
#endif
                return TVVisionUIKitStreamSurfaceState(
                    isAttached: isAttached,
                    windowScene: window?.windowScene,
                    isVisible: isVisible,
                    scale: Double(surface.contentScaleFactor),
                    drawableSize: surface.drawableSize,
                    isFocusEligible: isFocusEligible
                )
            },
            handler: surfaceCallbackHandler
        )
        if let surfaceGeneration =
            TVVisionStreamSurfaceGenerationSequence.next() {
            windowObservation = try? WindowObservation(
                surfaceGeneration: surfaceGeneration,
                notificationCenter: .default,
                names: .current,
                handler: { [weak self] callbacks in
                    self?.publishSurfaceCallbacks(callbacks)
                }
            )
            geometryBindingOwner = try? GeometryBindingOwner(
                platform: Self.platform,
                surfaceGeneration: surfaceGeneration,
                surface: self,
                sourceSize: sourceSize,
                mode: mode,
                geometryReader: Self.readGeometry,
                drawableApplier: Self.applyDrawableSize,
                handler: { [weak self] update in
                    self?.geometryBindingUpdateHandler(update)
                }
            )
            surfaceGenerationOwner = try? SurfaceGenerationOwner(
                platform: Self.platform,
                surfaceGeneration: surfaceGeneration,
                surface: self,
                resolver: Self.resolveAttachment,
                handler: { [weak self] update in
                    self?.handleSurfaceGenerationUpdate(update)
                }
            )
#if os(tvOS)
            displayHDRObserver = try? DisplayHDRObserver(
                surfaceGeneration: surfaceGeneration,
                notificationCenter: .default,
                names: .current,
                generationProvider: TVOSDisplayGenerationSequence.next,
                reader: { screen, layer in
                    TVOSNativeDisplayHDRCapabilityProbe.resolve(
                        screen: screen,
                        layer: layer
                    )
                },
                handler: { [weak self] event in
                    self?.displayHDREventHandler(event)
                }
            )
#endif
        }
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

#if os(tvOS)
    override func pressesBegan(
        _ presses: Set<UIPress>,
        with event: UIPressesEvent?
    ) {
        var localPresses = Set<UIPress>()
        for press in presses {
            let identity = ObjectIdentifier(press)
            if let active = activeUIKitPresses[identity] {
                if active.disposition == .local { localPresses.insert(press) }
                continue
            }
            if activeReservedPresses.contains(identity) {
                localPresses.insert(press)
                continue
            }
            if let command = TVRemotePressMapper.reservedCommand(for: press.type) {
                activeReservedPresses.insert(identity)
                reservedRemoteCommandHandler(command)
                localPresses.insert(press)
                continue
            }
            guard let surfaceGeneration,
                  let button = TVRemotePressMapper.button(for: press.type),
                  let pressID = takeNextRemotePressID(),
                  let pressEvent = try? TVRemoteSurfacePressEvent(
                    surfaceGeneration: surfaceGeneration,
                    pressID: pressID,
                    button: button,
                    phase: .began
                  ) else {
                localPresses.insert(press)
                continue
            }
            let disposition = remotePressEventHandler(pressEvent)
            activeUIKitPresses[identity] = ActiveUIKitPress(
                surfaceGeneration: surfaceGeneration,
                pressID: pressID,
                button: button,
                disposition: disposition
            )
            if disposition == .local { localPresses.insert(press) }
        }
        if !localPresses.isEmpty {
            super.pressesBegan(localPresses, with: event)
        }
    }

    override func pressesEnded(
        _ presses: Set<UIPress>,
        with event: UIPressesEvent?
    ) {
        finishPresses(presses, phase: .ended, event: event)
    }

    override func pressesChanged(
        _ presses: Set<UIPress>,
        with event: UIPressesEvent?
    ) {
        let localPresses = presses.filter { press in
            activeUIKitPresses[ObjectIdentifier(press)]?.disposition != .captured
        }
        guard !localPresses.isEmpty else { return }
        super.pressesChanged(Set(localPresses), with: event)
    }

    override func pressesCancelled(
        _ presses: Set<UIPress>,
        with event: UIPressesEvent?
    ) {
        finishPresses(presses, phase: .cancelled, event: event)
    }
#endif

    func updateSurfaceCallbackHandler(
        _ handler: @escaping SurfaceCallbackHandler
    ) {
        surfaceRelay?.updateHandler(handler)
    }

    func updateSurfaceGenerationUpdateHandler(
        _ handler: @escaping SurfaceGenerationUpdateHandler
    ) {
        surfaceGenerationUpdateHandler = handler
    }

    func updateDisplayHDREventHandler(
        _ handler: @escaping DisplayHDREventHandler
    ) {
        displayHDREventHandler = handler
    }

    func updateRemotePressEventHandler(
        _ handler: @escaping RemotePressEventHandler
    ) {
        remotePressEventHandler = handler
    }

    func updateReservedRemoteCommandHandler(
        _ handler: @escaping ReservedRemoteCommandHandler
    ) {
        reservedRemoteCommandHandler = handler
    }

    func updateGeometryBinding(
        sourceSize: PixelSize,
        mode: RenderScaleMode,
        handler: @escaping GeometryBindingUpdateHandler
    ) {
        geometryBindingUpdateHandler = handler
        guard let geometryBindingOwner else { return }
        let outcome = geometryBindingOwner.updateRenderInputs(
            sourceSize: sourceSize,
            mode: mode,
            surface: self,
            surfaceGeneration: geometryBindingOwner.surfaceGeneration
        )
        switch outcome {
        case .unchanged:
            _ = geometryBindingOwner.replayCurrentUpdate(
                surface: self,
                surfaceGeneration: geometryBindingOwner.surfaceGeneration
            )
        case .published:
            break
        case .closed, .staleSurfaceGeneration, .staleSurface,
             .revisionExhausted, .invalidated, .alreadyInvalidated:
            return
        }
#if os(tvOS)
        _ = displayHDRObserver?.replayCurrentEvent(
            surfaceGeneration: geometryBindingOwner.surfaceGeneration
        )
#endif
    }

    func absoluteInputMapping(
        localPoint: RemotePoint
    ) -> TVVisionStreamAbsoluteInputMapping? {
        geometryBindingOwner?.absoluteInputMapping(localPoint: localPoint)
    }

    func refreshSurfaceCallbacks() {
        publishSurfaceCallbacks(TVVisionUIKitStreamSurfaceCallback.allCases)
    }

    func invalidateSurfaceCallbacks() {
#if os(tvOS)
        cancelCapturedPresses()
        if let displayHDRObserver {
            _ = displayHDRObserver.invalidate(
                surfaceGeneration: displayHDRObserver.surfaceGeneration
            )
            self.displayHDRObserver = nil
        }
#endif
        if let windowObservation {
            _ = windowObservation.invalidate(
                surfaceGeneration: windowObservation.surfaceGeneration
            )
            self.windowObservation = nil
        }
        if let traitChangeRegistration {
            unregisterForTraitChanges(traitChangeRegistration)
            self.traitChangeRegistration = nil
        }
        if let geometryBindingOwner {
            geometryBindingOwner.invalidate(
                surface: self,
                surfaceGeneration: geometryBindingOwner.surfaceGeneration
            )
            self.geometryBindingOwner = nil
        }
        if let surfaceGenerationOwner {
            surfaceGenerationOwner.invalidate(
                surface: self,
                surfaceGeneration: surfaceGenerationOwner.surfaceGeneration
            )
            self.surfaceGenerationOwner = nil
        }
        surfaceRelay?.invalidate()
        surfaceRelay = nil
        displayHDREventHandler = { _ in }
        remotePressEventHandler = { _ in .local }
        reservedRemoteCommandHandler = { _ in }
    }

#if os(tvOS)
    private func finishPresses(
        _ presses: Set<UIPress>,
        phase: TVRemoteSurfacePressPhase,
        event: UIPressesEvent?
    ) {
        var localPresses = Set<UIPress>()
        for press in presses {
            let identity = ObjectIdentifier(press)
            if activeReservedPresses.remove(identity) != nil {
                localPresses.insert(press)
                continue
            }
            guard let active = activeUIKitPresses.removeValue(forKey: identity) else {
                localPresses.insert(press)
                continue
            }
            guard active.disposition == .captured else {
                localPresses.insert(press)
                continue
            }
            guard let pressEvent = try? TVRemoteSurfacePressEvent(
                    surfaceGeneration: active.surfaceGeneration,
                    pressID: active.pressID,
                    button: active.button,
                    phase: phase
                  ) else {
                continue
            }
            _ = remotePressEventHandler(pressEvent)
        }
        guard !localPresses.isEmpty else { return }
        switch phase {
        case .began:
            break
        case .ended:
            super.pressesEnded(localPresses, with: event)
        case .cancelled:
            super.pressesCancelled(localPresses, with: event)
        }
    }

    private func cancelCapturedPresses() {
        let captured = activeUIKitPresses.values
            .filter { $0.disposition == .captured }
            .sorted { $0.pressID < $1.pressID }
        activeUIKitPresses.removeAll()
        activeReservedPresses.removeAll()
        for active in captured {
            guard let event = try? TVRemoteSurfacePressEvent(
                surfaceGeneration: active.surfaceGeneration,
                pressID: active.pressID,
                button: active.button,
                phase: .cancelled
            ) else { continue }
            _ = remotePressEventHandler(event)
        }
    }

    private func takeNextRemotePressID() -> UInt64? {
        guard nextRemotePressID > 0 else { return nil }
        let result = nextRemotePressID
        nextRemotePressID = result == UInt64.max ? 0 : result + 1
        return result
    }
#endif

    private func handleSurfaceGenerationUpdate(
        _ update: SurfaceGenerationOwner.Update
    ) {
        _ = geometryBindingOwner?.handle(update)
        surfaceGenerationUpdateHandler(update)
    }

    private func publishSurfaceCallbacks(
        _ callbacks: [TVVisionUIKitStreamSurfaceCallback]
    ) {
        refreshWindowObservation()
        guard let rawState = surfaceRelay?.publish(callbacks) else { return }
        if let surfaceGenerationOwner {
            for callback in callbacks {
                surfaceGenerationOwner.handle(
                    surface: self,
                    surfaceGeneration: surfaceGenerationOwner.surfaceGeneration,
                    callback: callback,
                    rawState: rawState
                )
            }
        }
#if os(tvOS)
        refreshDisplayHDRObservation(
            callbacks.contains(.layout) ? .layout : .attachment
        )
#endif
    }

#if os(tvOS)
    private func refreshDisplayHDRObservation(
        _ reason: TVOSDisplayHDRResampleReason
    ) {
        guard let displayHDRObserver else { return }
        guard let windowScene = window?.windowScene,
              let metalLayer = layer as? CAMetalLayer else {
            _ = displayHDRObserver.detach(
                surfaceGeneration: displayHDRObserver.surfaceGeneration
            )
            return
        }
        _ = displayHDRObserver.attach(
            screen: windowScene.screen,
            layer: metalLayer,
            surfaceGeneration: displayHDRObserver.surfaceGeneration,
            reason: reason
        )
    }
#endif

    private func refreshWindowObservation() {
        guard let windowObservation else { return }
        guard let window,
              let windowScene = window.windowScene else {
            _ = windowObservation.detach(
                surfaceGeneration: windowObservation.surfaceGeneration
            )
            return
        }
        _ = windowObservation.attach(
            window: window,
            windowScene: windowScene,
            surfaceGeneration: windowObservation.surfaceGeneration
        )
    }

    private static func sceneActivity(
        _ scene: UIWindowScene
    ) -> AppSceneActivity {
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
    }

    private static var platform: TVVisionPlatform {
#if os(tvOS)
        .tvOS
#else
        .visionOS
#endif
    }

    private static func readGeometry(
        _ surface: TVVisionStreamMetalView
    ) -> TVVisionUIKitStreamSurfaceGeometryReading? {
        guard let window = surface.window else { return nil }
        return TVVisionUIKitStreamSurfaceGeometryReading(
            viewBounds: TVVisionRect(
                x: Double(surface.bounds.origin.x),
                y: Double(surface.bounds.origin.y),
                width: Double(surface.bounds.width),
                height: Double(surface.bounds.height)
            ),
            windowBounds: TVVisionRect(
                x: Double(window.bounds.origin.x),
                y: Double(window.bounds.origin.y),
                width: Double(window.bounds.width),
                height: Double(window.bounds.height)
            ),
            safeAreaInsets: TVVisionEdgeInsets(
                top: Double(surface.safeAreaInsets.top),
                leading: Double(surface.safeAreaInsets.left),
                bottom: Double(surface.safeAreaInsets.bottom),
                trailing: Double(surface.safeAreaInsets.right)
            ),
            scale: Double(surface.contentScaleFactor)
        )
    }

    private static func applyDrawableSize(
        _ surface: TVVisionStreamMetalView,
        _ size: PixelSize
    ) -> Bool {
        guard size.width >= 0, size.height >= 0 else { return false }
        let drawableSize = CGSize(
            width: CGFloat(size.width),
            height: CGFloat(size.height)
        )
        guard drawableSize.width.isFinite,
              drawableSize.height.isFinite else {
            return false
        }
        surface.drawableSize = drawableSize
        return surface.drawableSize == drawableSize
    }

    private static func resolveAttachment(
        _ surface: TVVisionStreamMetalView
    ) -> SurfaceGenerationOwner.ResolvedAttachment? {
        guard let window = surface.window,
              let windowScene = window.windowScene else {
            return nil
        }
#if os(tvOS)
        return SurfaceGenerationOwner.ResolvedAttachment(
            window: window,
            windowScene: windowScene,
            screen: windowScene.screen,
            activity: sceneActivity(windowScene)
        )
#else
        return SurfaceGenerationOwner.ResolvedAttachment(
            window: window,
            windowScene: windowScene,
            screen: nil,
            activity: sceneActivity(windowScene)
        )
#endif
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
    var platformPresentationOwner: TVVisionMetalPresentationOwner?
    var surfaceCallbackHandler:
        TVVisionStreamMetalView.SurfaceCallbackHandler = { _, _, _ in }
    var surfaceGenerationUpdateHandler:
        TVVisionStreamMetalView.SurfaceGenerationUpdateHandler = { _ in }
    var geometryBindingUpdateHandler:
        TVVisionStreamMetalView.GeometryBindingUpdateHandler = { _ in }
    var displayHDREventHandler:
        TVVisionStreamMetalView.DisplayHDREventHandler = { _ in }
    var remotePressEventHandler:
        TVVisionStreamMetalView.RemotePressEventHandler = { _ in .local }
    var reservedRemoteCommandHandler:
        TVVisionStreamMetalView.ReservedRemoteCommandHandler = { _ in }
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
        let externalGeometryBindingUpdateHandler =
            geometryBindingUpdateHandler
        let view = TVVisionStreamMetalView(
            frame: .zero,
            device: MTLCreateSystemDefaultDevice(),
            sourceSize: renderState.transform.sourceSize,
            mode: renderState.transform.mode,
            surfaceCallbackHandler: surfaceCallbackHandler,
            surfaceGenerationUpdateHandler: surfaceGenerationUpdateHandler,
            geometryBindingUpdateHandler: {
                [weak coordinator = context.coordinator] update in
                coordinator?.handleTVVisionGeometryUpdate(update)
                externalGeometryBindingUpdateHandler(update)
            },
            displayHDREventHandler: displayHDREventHandler,
            remotePressEventHandler: remotePressEventHandler,
            reservedRemoteCommandHandler: reservedRemoteCommandHandler
        )
        if let surfaceGeneration = view.surfaceGeneration {
            context.coordinator.activateTVVisionSurfaceGeneration(
                surfaceGeneration
            )
        }
#else
        let view = MTKView(frame: .zero, device: MTLCreateSystemDefaultDevice())
#endif
        view.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        view.enableSetNeedsDisplay = false
        view.isPaused = true
        context.coordinator.presenter.configure(view)
#if os(tvOS) || os(visionOS)
        if let platformPresentationOwner,
           let surfaceGeneration = view.surfaceGeneration {
            context.coordinator.bindTVVisionPresentationOwner(
                platformPresentationOwner,
                surfaceGeneration: surfaceGeneration
            )
        }
#endif
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
        context.coordinator.update(
            renderState: renderState,
            inputOutputHandler: { _ in }
        )
        (view as? TVVisionStreamMetalView)?
            .updateSurfaceCallbackHandler(surfaceCallbackHandler)
        (view as? TVVisionStreamMetalView)?
            .updateSurfaceGenerationUpdateHandler(
                surfaceGenerationUpdateHandler
            )
        (view as? TVVisionStreamMetalView)?
            .updateDisplayHDREventHandler(displayHDREventHandler)
        (view as? TVVisionStreamMetalView)?
            .updateRemotePressEventHandler(remotePressEventHandler)
        (view as? TVVisionStreamMetalView)?
            .updateReservedRemoteCommandHandler(reservedRemoteCommandHandler)
        (view as? TVVisionStreamMetalView)?
            .updateGeometryBinding(
                sourceSize: renderState.transform.sourceSize,
                mode: renderState.transform.mode,
                handler: { [weak coordinator = context.coordinator] update in
                    coordinator?.handleTVVisionGeometryUpdate(update)
                    geometryBindingUpdateHandler(update)
                }
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
        if let platformView = view as? TVVisionStreamMetalView {
            if let surfaceGeneration = platformView.surfaceGeneration {
                coordinator.deactivateTVVisionSurfaceGeneration(
                    surfaceGeneration
                )
            }
            platformView.invalidateSurfaceCallbacks()
        }
#endif
        coordinator.presenter.stop()
        view.delegate = nil
        view.isPaused = true
    }
}
#endif
