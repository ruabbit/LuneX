@preconcurrency import AVFoundation
@preconcurrency import AVKit
@preconcurrency import CoreMedia
import Foundation

enum MobilePictureInPictureNativeControllerEvent {
    case possibilityChanged(Bool)
    case willStart
    case didStart
    case startFailed
    case willStop
    case didStop
    case restoreInterfaceRequested(@Sendable (Bool) -> Void)
    case setPlaying(Bool)
    case skipRequested(
        MobilePictureInPictureSkipInterval,
        @Sendable () -> Void
    )
    case renderSizeChanged(MobilePictureInPictureRenderSize)
}

typealias MobilePictureInPictureNativeControllerEventHandler =
    @MainActor (MobilePictureInPictureNativeControllerEvent) -> Void

@MainActor
protocol MobilePictureInPictureNativeControllerBridge: AnyObject {
    var isPictureInPicturePossible: Bool { get }
    var isPictureInPictureActive: Bool { get }

    func setEventHandler(
        _ handler: MobilePictureInPictureNativeControllerEventHandler?
    )
    func startPictureInPicture()
    func stopPictureInPicture()
    func updatePlaybackState(
        _ state: MobilePictureInPicturePlaybackState
    )
    func invalidatePlaybackState()
    func invalidate()
}

enum MobilePictureInPictureNativeControllerPreparation {
    case prepared(any MobilePictureInPictureNativeControllerBridge)
    case unavailable(MobilePictureInPictureUnavailableReason)
}

enum MobilePictureInPictureAVKitPlaybackAdapter {
    static func timeRange(
        for state: MobilePictureInPicturePlaybackState?
    ) -> CMTimeRange {
        guard state?.timeline == .live else { return .invalid }
        return CMTimeRange(
            start: .zero,
            duration: .positiveInfinity
        )
    }

    static func isPaused(
        for state: MobilePictureInPicturePlaybackState?
    ) -> Bool {
        state?.isPaused ?? true
    }

    static func prohibitsBackgroundAudio(
        for state: MobilePictureInPicturePlaybackState?
    ) -> Bool {
        state?.backgroundAudioPolicy != .permitted
    }

    static func skipInterval(
        from value: CMTime
    ) -> MobilePictureInPictureSkipInterval? {
        guard value.isNumeric else { return nil }
        let scaledValue = CMTimeConvertScale(
            value,
            timescale: 1_000_000_000,
            method: .default
        )
        guard scaledValue.isNumeric else { return nil }
        return MobilePictureInPictureSkipInterval(
            nanoseconds: scaledValue.value
        )
    }

    static func renderSize(
        from dimensions: CMVideoDimensions
    ) -> MobilePictureInPictureRenderSize? {
        MobilePictureInPictureRenderSize(
            width: dimensions.width,
            height: dimensions.height
        )
    }
}

@MainActor
protocol MobilePictureInPictureNativeControllerFactory: AnyObject {
    func makeController(
        displayLayer: AVSampleBufferDisplayLayer
    ) -> MobilePictureInPictureNativeControllerPreparation
}

@MainActor
final class MobilePictureInPictureAVKitNativeControllerFactory:
    MobilePictureInPictureNativeControllerFactory
{
    private let supportReader: @MainActor () -> Bool

    init(
        supportReader: @escaping @MainActor () -> Bool = {
            AVPictureInPictureController.isPictureInPictureSupported()
        }
    ) {
        self.supportReader = supportReader
    }

    func makeController(
        displayLayer: AVSampleBufferDisplayLayer
    ) -> MobilePictureInPictureNativeControllerPreparation {
        guard supportReader() else {
            return .unavailable(.platformUnsupported)
        }
        guard let bridge =
                MobilePictureInPictureAVKitNativeControllerBridge(
                    displayLayer: displayLayer
                ) else {
            return .unavailable(.controllerUnavailable)
        }
        return .prepared(bridge)
    }
}

@MainActor
final class MobilePictureInPictureAVKitNativeControllerBridge:
    NSObject,
    MobilePictureInPictureNativeControllerBridge,
    @MainActor AVPictureInPictureControllerDelegate,
    @MainActor AVPictureInPictureSampleBufferPlaybackDelegate
{
    private(set) var contentSource:
        AVPictureInPictureController.ContentSource!
    private(set) var controller: AVPictureInPictureController!

    private var eventHandler:
        MobilePictureInPictureNativeControllerEventHandler?
    private var playbackState: MobilePictureInPicturePlaybackState?
    private var possibilityObservation: NSKeyValueObservation?
    private(set) var isInvalidated = false

    init?(displayLayer: AVSampleBufferDisplayLayer) {
        guard AVPictureInPictureController
                .isPictureInPictureSupported() else {
            return nil
        }
        super.init()
        guard let contentSource =
                LuneXCreatePictureInPictureContentSource(
                    displayLayer,
                    self
                ),
              let controller =
                LuneXCreatePictureInPictureController(contentSource) else {
            return nil
        }
        self.contentSource = contentSource
        self.controller = controller
        controller.delegate = self
        installPossibilityObservation()
    }

    var isPictureInPicturePossible: Bool {
        !isInvalidated && controller.isPictureInPicturePossible
    }

    var isPictureInPictureActive: Bool {
        !isInvalidated && controller.isPictureInPictureActive
    }

    var hasPossibilityObservation: Bool {
        possibilityObservation != nil
    }

    func setEventHandler(
        _ handler: MobilePictureInPictureNativeControllerEventHandler?
    ) {
        eventHandler = isInvalidated ? nil : handler
    }

    func startPictureInPicture() {
        guard !isInvalidated else { return }
        controller.startPictureInPicture()
    }

    func stopPictureInPicture() {
        guard !isInvalidated else { return }
        controller.stopPictureInPicture()
    }

    func updatePlaybackState(
        _ state: MobilePictureInPicturePlaybackState
    ) {
        guard !isInvalidated else { return }
        playbackState = state
    }

    func invalidatePlaybackState() {
        guard !isInvalidated else { return }
        controller.invalidatePlaybackState()
    }

    func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        possibilityObservation?.invalidate()
        possibilityObservation = nil
        eventHandler = nil
        playbackState = nil
        if controller.isPictureInPictureActive {
            controller.stopPictureInPicture()
        }
        controller.delegate = nil
        controller.contentSource = nil
    }

    func pictureInPictureControllerWillStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        guard accepts(pictureInPictureController) else { return }
        eventHandler?(.willStart)
    }

    func pictureInPictureControllerDidStartPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        guard accepts(pictureInPictureController) else { return }
        eventHandler?(.didStart)
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        failedToStartPictureInPictureWithError error: any Error
    ) {
        guard accepts(pictureInPictureController) else { return }
        _ = error
        eventHandler?(.startFailed)
    }

    func pictureInPictureControllerWillStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        guard accepts(pictureInPictureController) else { return }
        eventHandler?(.willStop)
    }

    func pictureInPictureControllerDidStopPictureInPicture(
        _ pictureInPictureController: AVPictureInPictureController
    ) {
        guard accepts(pictureInPictureController) else { return }
        eventHandler?(.didStop)
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        restoreUserInterfaceForPictureInPictureStopWithCompletionHandler
            completionHandler: @escaping @Sendable (Bool) -> Void
    ) {
        guard accepts(pictureInPictureController),
              let eventHandler else {
            completionHandler(false)
            return
        }
        eventHandler(.restoreInterfaceRequested(completionHandler))
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        setPlaying playing: Bool
    ) {
        guard accepts(pictureInPictureController) else { return }
        eventHandler?(.setPlaying(playing))
    }

    func pictureInPictureControllerTimeRangeForPlayback(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> CMTimeRange {
        guard accepts(pictureInPictureController) else { return .invalid }
        return MobilePictureInPictureAVKitPlaybackAdapter.timeRange(
            for: playbackState
        )
    }

    func pictureInPictureControllerIsPlaybackPaused(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> Bool {
        guard accepts(pictureInPictureController) else { return true }
        return MobilePictureInPictureAVKitPlaybackAdapter.isPaused(
            for: playbackState
        )
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        didTransitionToRenderSize newRenderSize: CMVideoDimensions
    ) {
        guard accepts(pictureInPictureController),
              let renderSize =
                MobilePictureInPictureAVKitPlaybackAdapter.renderSize(
                    from: newRenderSize
                ) else {
            return
        }
        eventHandler?(.renderSizeChanged(renderSize))
    }

    func pictureInPictureController(
        _ pictureInPictureController: AVPictureInPictureController,
        skipByInterval skipInterval: CMTime,
        completion: @escaping @Sendable () -> Void
    ) {
        guard accepts(pictureInPictureController),
              let interval =
                MobilePictureInPictureAVKitPlaybackAdapter.skipInterval(
                    from: skipInterval
                ),
              let eventHandler else {
            completion()
            return
        }
        eventHandler(.skipRequested(interval, completion))
    }

    func pictureInPictureControllerShouldProhibitBackgroundAudioPlayback(
        _ pictureInPictureController: AVPictureInPictureController
    ) -> Bool {
        guard accepts(pictureInPictureController) else { return true }
        return MobilePictureInPictureAVKitPlaybackAdapter
            .prohibitsBackgroundAudio(for: playbackState)
    }

    private func installPossibilityObservation() {
        possibilityObservation = controller.observe(
            \.isPictureInPicturePossible,
            options: [.new]
        ) { [weak self] _, _ in
            Task { @MainActor [weak self] in
                guard let self, !self.isInvalidated else { return }
                self.eventHandler?(.possibilityChanged(
                    self.controller.isPictureInPicturePossible
                ))
            }
        }
    }

    private func accepts(
        _ candidate: AVPictureInPictureController
    ) -> Bool {
        !isInvalidated && candidate === controller
    }
}

@MainActor
final class MobilePictureInPictureAVKitControllerClient:
    MobilePictureInPictureControllerClient
{
    let generation: MobilePictureInPictureGeneration
    private(set) var preparationSnapshot:
        MobilePictureInPictureClientPreparationSnapshot?

    private enum PendingNativeCallback {
        case restoreInterface(@Sendable (Bool) -> Void)
        case skip(@Sendable () -> Void)
    }

    private struct PendingCallback {
        let lease: MobilePictureInPictureClientCallbackLease
        let nativeCallback: PendingNativeCallback
    }

    private let displayLayer: AVSampleBufferDisplayLayer
    private let factory:
        any MobilePictureInPictureNativeControllerFactory
    private var nativeController:
        (any MobilePictureInPictureNativeControllerBridge)?
    private var eventHandler:
        MobilePictureInPictureClientEventHandler?
    private var pendingCallbacks: [
        MobilePictureInPictureClientCallbackKind: PendingCallback
    ] = [:]
    private var nextCallbackOrdinal: UInt64
    private var isInvalidated = false

    init(
        generation: MobilePictureInPictureGeneration,
        displayLayer: AVSampleBufferDisplayLayer,
        factory: any MobilePictureInPictureNativeControllerFactory =
            MobilePictureInPictureAVKitNativeControllerFactory(),
        initialCallbackOrdinal: UInt64 = 0
    ) {
        self.generation = generation
        self.displayLayer = displayLayer
        self.factory = factory
        nextCallbackOrdinal = initialCallbackOrdinal
    }

    func setEventHandler(
        _ handler: MobilePictureInPictureClientEventHandler?
    ) {
        guard !isInvalidated else {
            if let handler,
               let envelope = MobilePictureInPictureClientEventEnvelope(
                   generation: generation,
                   event: .invalidated
               ) {
                handler(envelope)
            }
            return
        }
        if handler == nil, eventHandler != nil {
            eventHandler = nil
            completePendingCallbacksForInvalidation()
            return
        }
        eventHandler = handler
    }

    func prepare() {
        guard !isInvalidated, preparationSnapshot == nil else { return }
        switch factory.makeController(displayLayer: displayLayer) {
        case let .unavailable(reason):
            let snapshot = MobilePictureInPictureClientPreparationSnapshot(
                generation: generation,
                components: .unprepared,
                capability: .unavailable(reason)
            )
            preparationSnapshot = snapshot
            if let snapshot {
                emit(.prepared(snapshot))
            }
        case let .prepared(nativeController):
            self.nativeController = nativeController
            nativeController.setEventHandler { [weak self] event in
                self?.handleNativeEvent(event)
            }
            let capability: MobilePictureInPictureCapability =
                nativeController.isPictureInPicturePossible
                    ? .possible
                    : .unavailable(.notPossible)
            let snapshot = MobilePictureInPictureClientPreparationSnapshot(
                generation: generation,
                components: .ready,
                capability: capability
            )
            preparationSnapshot = snapshot
            if let snapshot {
                emit(.prepared(snapshot))
            }
        }
    }

    func requestStart() {
        guard !isInvalidated else { return }
        nativeController?.startPictureInPicture()
    }

    func requestStop() {
        guard !isInvalidated else { return }
        nativeController?.stopPictureInPicture()
    }

    func updatePlaybackState(
        _ state: MobilePictureInPicturePlaybackState
    ) {
        guard !isInvalidated else { return }
        nativeController?.updatePlaybackState(state)
    }

    func invalidatePlaybackState() {
        guard !isInvalidated else { return }
        nativeController?.invalidatePlaybackState()
    }

    func completeCallback(
        _ lease: MobilePictureInPictureClientCallbackLease,
        with completion: MobilePictureInPictureClientCallbackCompletion
    ) -> MobilePictureInPictureClientCallbackOutcome {
        guard !isInvalidated else { return .invalidated }
        guard lease.generation == generation else {
            return .staleGeneration
        }
        guard lease.kind == completion.kind else {
            return .kindMismatch
        }
        guard let pending = pendingCallbacks[lease.kind],
              pending.lease == lease else {
            return .alreadyCompleted
        }
        pendingCallbacks.removeValue(forKey: lease.kind)
        switch (pending.nativeCallback, completion) {
        case let (
            .restoreInterface(nativeCompletion),
            .restoreInterface(restored)
        ):
            nativeCompletion(restored)
        case let (.skip(nativeCompletion), .skip):
            nativeCompletion()
        default:
            return .kindMismatch
        }
        return .completed
    }

    func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        completePendingCallbacksForInvalidation()
        nativeController?.setEventHandler(nil)
        nativeController?.invalidate()
        nativeController = nil
        preparationSnapshot =
            MobilePictureInPictureClientPreparationSnapshot(
                generation: generation,
                components: .invalidated,
                capability: .unavailable(.invalidated)
            )
        emit(.invalidated, allowWhenInvalidated: true)
        eventHandler = nil
    }

    private func handleNativeEvent(
        _ event: MobilePictureInPictureNativeControllerEvent
    ) {
        guard !isInvalidated, nativeController != nil else { return }
        switch event {
        case let .possibilityChanged(isPossible):
            applyPossibility(isPossible)
        case .willStart:
            emit(.willStart)
        case .didStart:
            emit(.didStart)
        case .startFailed:
            emit(.startFailed(.nativeStartFailed))
        case .willStop:
            emit(.willStop)
        case .didStop:
            emit(.didStop)
        case let .restoreInterfaceRequested(nativeCompletion):
            registerRestorationCallback(nativeCompletion)
        case let .setPlaying(isPlaying):
            emit(.setPlaying(isPlaying))
        case let .skipRequested(interval, nativeCompletion):
            registerSkipCallback(
                interval: interval,
                nativeCompletion: nativeCompletion
            )
        case let .renderSizeChanged(renderSize):
            emit(.renderSizeChanged(renderSize))
        }
    }

    private func applyPossibility(_ isPossible: Bool) {
        guard preparationSnapshot?.components.allReady == true else {
            return
        }
        let capability: MobilePictureInPictureCapability =
            isPossible ? .possible : .unavailable(.notPossible)
        guard preparationSnapshot?.capability != capability,
              let snapshot =
                MobilePictureInPictureClientPreparationSnapshot(
                    generation: generation,
                    components: .ready,
                    capability: capability
                ) else {
            return
        }
        preparationSnapshot = snapshot
        emit(.capabilityChanged(capability))
    }

    private func registerRestorationCallback(
        _ nativeCompletion: @escaping @Sendable (Bool) -> Void
    ) {
        guard eventHandler != nil else {
            nativeCompletion(false)
            return
        }
        guard pendingCallbacks[.restoreInterface] == nil else {
            nativeCompletion(false)
            return
        }
        guard let lease = makeCallbackLease(kind: .restoreInterface) else {
            nativeCompletion(false)
            emit(.startFailed(.restorationLeaseExhausted))
            return
        }
        pendingCallbacks[.restoreInterface] = PendingCallback(
            lease: lease,
            nativeCallback: .restoreInterface(nativeCompletion)
        )
        emit(.restoreInterfaceRequested(lease))
    }

    private func registerSkipCallback(
        interval: MobilePictureInPictureSkipInterval,
        nativeCompletion: @escaping @Sendable () -> Void
    ) {
        guard eventHandler != nil else {
            nativeCompletion()
            return
        }
        guard pendingCallbacks[.skip] == nil else {
            nativeCompletion()
            return
        }
        guard let lease = makeCallbackLease(kind: .skip) else {
            nativeCompletion()
            return
        }
        pendingCallbacks[.skip] = PendingCallback(
            lease: lease,
            nativeCallback: .skip(nativeCompletion)
        )
        emit(.skipRequested(
            interval: interval,
            completion: lease
        ))
    }

    private func makeCallbackLease(
        kind: MobilePictureInPictureClientCallbackKind
    ) -> MobilePictureInPictureClientCallbackLease? {
        guard nextCallbackOrdinal < .max else { return nil }
        nextCallbackOrdinal += 1
        return MobilePictureInPictureClientCallbackLease(
            generation: generation,
            kind: kind,
            ordinal: nextCallbackOrdinal
        )
    }

    private func completePendingCallbacksForInvalidation() {
        let callbacks = Array(pendingCallbacks.values)
        pendingCallbacks.removeAll(keepingCapacity: false)
        for callback in callbacks {
            switch callback.nativeCallback {
            case let .restoreInterface(nativeCompletion):
                nativeCompletion(false)
            case let .skip(nativeCompletion):
                nativeCompletion()
            }
        }
    }

    private func emit(
        _ event: MobilePictureInPictureClientEvent,
        allowWhenInvalidated: Bool = false
    ) {
        guard (!isInvalidated || allowWhenInvalidated),
              let envelope = MobilePictureInPictureClientEventEnvelope(
                  generation: generation,
                  event: event
              ) else {
            return
        }
        eventHandler?(envelope)
    }
}
