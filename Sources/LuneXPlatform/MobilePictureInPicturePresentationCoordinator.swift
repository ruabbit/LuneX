import Foundation

@MainActor
protocol MobilePictureInPictureFramePresentationSink:
    MobilePictureInPictureLifecycleFrameSink
{
    var decoderGeneration: UInt64 { get }

    func submit(
        _ sampleBuffer: MobilePictureInPictureSampleBuffer
    ) -> MobilePictureInPictureDisplayLayerSubmissionOutcome
    @discardableResult
    func signalDiscontinuity(
        generation: MobilePictureInPictureGeneration
    ) -> Bool
}

enum MobilePictureInPictureForegroundSuppression:
    Equatable,
    Sendable
{
    case paused
    case throttled
}

enum MobilePictureInPicturePresentationCoordinatorError:
    Error,
    Equatable,
    Sendable
{
    case clientGenerationMismatch
    case frameSinkGenerationMismatch
    case decoderGenerationMismatch
    case sourceSubscriptionUnavailable
}

enum MobilePictureInPictureFrameDeliveryRejection:
    Equatable,
    Sendable
{
    case staleSession
    case staleMediaGeneration
    case staleDeliveryRevision
    case staleDecoderGeneration
    case staleFrame
    case sampleBufferConversionFailed
    case frameSinkRejected
    case invalidated
}

struct MobilePictureInPicturePresentationCoordinatorSnapshot:
    Equatable,
    Sendable
{
    let generation: MobilePictureInPictureGeneration
    let decoderGeneration: UInt64
    let lastDeliveryRevision: UInt64
    let lastFrameID: UInt64?
    let submittedFrameCount: UInt64
    let rejectedFrameCount: UInt64
    let discontinuityCount: UInt64
    let sampleBufferAdapterReplacementCount: UInt64
    let mailboxCoalescedDeliveryCount: UInt64
    let foregroundPolicy: RenderPolicy
    let isConfirmedActive: Bool
    let isInvalidated: Bool
}

@MainActor
final class MobilePictureInPicturePresentationCoordinator {
    typealias ForegroundPolicyHandler =
        @MainActor (RenderPolicy) -> Void
    typealias SampleBufferAdapterFactory = @MainActor (
        MobilePictureInPictureGeneration,
        UInt64,
        VideoColorMetadata
    ) throws -> MobilePictureInPictureSampleBufferAdapter

    static let foregroundSuppressionReason =
        "Picture in Picture is active"

    let sessionID: UUID
    let generation: MobilePictureInPictureGeneration
    let decoderGeneration: UInt64
    let lifecycleCoordinator:
        MobilePictureInPictureLifecycleCoordinator

    private let frameSink:
        any MobilePictureInPictureFramePresentationSink
    private let adapterFactory: SampleBufferAdapterFactory
    private let foregroundSuppression:
        MobilePictureInPictureForegroundSuppression
    private let foregroundPolicyHandler: ForegroundPolicyHandler
    private let mailbox = StreamVideoPresentationDeliveryMailbox()
    private var subscription: StreamVideoPresentationSubscription?
    private var adapter: MobilePictureInPictureSampleBufferAdapter?
    private var adapterColorMetadata: VideoColorMetadata?
    private var lifecycleEventHandler:
        MobilePictureInPictureLifecycleCoordinatorEventHandler?
    private var pendingRestorationLeases:
        Set<MobilePictureInPictureRestorationLease> = []
    private var pendingSkipLeases:
        Set<MobilePictureInPictureClientCallbackLease> = []
    private var foregroundBaseline: RenderPolicy
    private var appliedForegroundPolicy: RenderPolicy
    private var lastDeliveryRevision: UInt64 = 0
    private var lastFrameID: UInt64?
    private var submittedFrameCount: UInt64 = 0
    private var rejectedFrameCount: UInt64 = 0
    private var discontinuityCount: UInt64 = 0
    private var adapterReplacementCount: UInt64 = 0
    private var isConfirmedActive = false
    private var isTerminating = false
    private(set) var isInvalidated = false

    init(
        sessionID: UUID,
        generation: MobilePictureInPictureGeneration,
        decoderGeneration: UInt64,
        source: StreamVideoPresentationSource,
        client: any MobilePictureInPictureControllerClient,
        frameSink: any MobilePictureInPictureFramePresentationSink,
        foregroundBaseline: RenderPolicy,
        foregroundSuppression:
            MobilePictureInPictureForegroundSuppression = .paused,
        foregroundPolicyHandler:
            @escaping ForegroundPolicyHandler = { _ in },
        adapterFactory:
            @escaping SampleBufferAdapterFactory = {
                generation,
                decoderGeneration,
                colorMetadata in
                try MobilePictureInPictureSampleBufferAdapter(
                    generation: generation,
                    decoderGeneration: decoderGeneration,
                    colorMetadata: colorMetadata
                )
            }
    ) throws {
        guard client.generation == generation else {
            throw MobilePictureInPicturePresentationCoordinatorError
                .clientGenerationMismatch
        }
        guard frameSink.generation == generation else {
            throw MobilePictureInPicturePresentationCoordinatorError
                .frameSinkGenerationMismatch
        }
        guard decoderGeneration > 0,
              frameSink.decoderGeneration == decoderGeneration else {
            throw MobilePictureInPicturePresentationCoordinatorError
                .decoderGenerationMismatch
        }
        self.sessionID = sessionID
        self.generation = generation
        self.decoderGeneration = decoderGeneration
        self.frameSink = frameSink
        self.foregroundBaseline = foregroundBaseline
        self.foregroundSuppression = foregroundSuppression
        self.foregroundPolicyHandler = foregroundPolicyHandler
        self.adapterFactory = adapterFactory
        appliedForegroundPolicy = foregroundBaseline
        lifecycleCoordinator =
            try MobilePictureInPictureLifecycleCoordinator(
                generation: generation,
                client: client,
                frameSink: frameSink
            )

        mailbox.setHandler { [weak self] delivery in
            self?.consume(delivery)
        }
        lifecycleCoordinator.setEventHandler { [weak self] event in
            self?.handleLifecycleEvent(event)
        }
        guard let subscription = source.subscribe(
            sessionID: sessionID,
            mediaGeneration: generation.mediaGeneration,
            handler: { [mailbox] delivery in
                mailbox.enqueue(delivery)
            }
        ) else {
            mailbox.invalidate()
            lifecycleCoordinator.setEventHandler(nil)
            _ = lifecycleCoordinator.invalidate()
            throw MobilePictureInPicturePresentationCoordinatorError
                .sourceSubscriptionUnavailable
        }
        self.subscription = subscription
        foregroundPolicyHandler(foregroundBaseline)
    }

    @discardableResult
    func prepare()
        -> MobilePictureInPictureLifecycleCoordinatorOutcome
    {
        guard isOperational else { return .invalidated }
        return lifecycleCoordinator.prepare()
    }

    @discardableResult
    func requestStart()
        -> MobilePictureInPictureLifecycleCoordinatorOutcome
    {
        guard isOperational else { return .invalidated }
        return lifecycleCoordinator.requestStart()
    }

    @discardableResult
    func requestStop()
        -> MobilePictureInPictureLifecycleCoordinatorOutcome
    {
        guard isOperational else { return .invalidated }
        return lifecycleCoordinator.requestStop()
    }

    @discardableResult
    func updatePlaybackState(
        _ state: MobilePictureInPicturePlaybackState
    ) -> Bool {
        guard isOperational else { return false }
        return lifecycleCoordinator.updatePlaybackState(state)
    }

    func updateForegroundBaseline(_ policy: RenderPolicy) {
        guard isOperational else { return }
        foregroundBaseline = policy
        applyForegroundPolicy()
    }

    func setLifecycleEventHandler(
        _ handler:
            MobilePictureInPictureLifecycleCoordinatorEventHandler?
    ) {
        guard isOperational else { return }
        lifecycleEventHandler = handler
        guard handler == nil else { return }
        completePendingExternalCallbacks()
    }

    @discardableResult
    func completeRestoration(
        _ lease: MobilePictureInPictureRestorationLease,
        result: MobilePictureInPictureRestorationResult
    ) -> MobilePictureInPictureLifecycleCoordinatorOutcome {
        guard isOperational else { return .invalidated }
        let outcome = lifecycleCoordinator.completeRestoration(
            lease,
            result: result
        )
        if case .applied = outcome {
            pendingRestorationLeases.remove(lease)
        }
        return outcome
    }

    @discardableResult
    func completeSkip(
        _ lease: MobilePictureInPictureClientCallbackLease
    ) -> MobilePictureInPictureClientCallbackOutcome {
        guard isOperational else { return .invalidated }
        let outcome = lifecycleCoordinator.completeSkip(lease)
        if outcome == .completed
            || outcome == .alreadyCompleted
            || outcome == .invalidated {
            pendingSkipLeases.remove(lease)
        }
        return outcome
    }

    func snapshot()
        -> MobilePictureInPicturePresentationCoordinatorSnapshot
    {
        MobilePictureInPicturePresentationCoordinatorSnapshot(
            generation: generation,
            decoderGeneration: decoderGeneration,
            lastDeliveryRevision: lastDeliveryRevision,
            lastFrameID: lastFrameID,
            submittedFrameCount: submittedFrameCount,
            rejectedFrameCount: rejectedFrameCount,
            discontinuityCount: discontinuityCount,
            sampleBufferAdapterReplacementCount:
                adapterReplacementCount,
            mailboxCoalescedDeliveryCount:
                mailbox.coalescedDeliveryCount,
            foregroundPolicy: appliedForegroundPolicy,
            isConfirmedActive: isConfirmedActive,
            isInvalidated: isInvalidated
        )
    }

    @discardableResult
    func invalidate()
        -> MobilePictureInPictureLifecycleCoordinatorOutcome
    {
        guard isOperational else { return .invalidated }
        isTerminating = true
        completePendingExternalCallbacks()
        lifecycleCoordinator.setEventHandler(nil)
        subscription?.cancel()
        subscription = nil
        mailbox.invalidate()
        adapter?.invalidate()
        adapter = nil
        adapterColorMetadata = nil
        let outcome = lifecycleCoordinator.invalidate()
        finishInvalidation()
        return outcome
    }

    private var isOperational: Bool {
        !isInvalidated && !isTerminating
    }

    private func consume(_ delivery: StreamVideoPresentationDelivery) {
        guard isOperational else {
            increment(&rejectedFrameCount)
            return
        }
        let ownership = delivery.ownership
        guard ownership.sessionID == sessionID else {
            reject(.staleSession)
            return
        }
        guard ownership.mediaGeneration == generation.mediaGeneration else {
            reject(.staleMediaGeneration)
            return
        }
        guard ownership.revision > lastDeliveryRevision else {
            reject(.staleDeliveryRevision)
            return
        }
        lastDeliveryRevision = ownership.revision

        switch delivery {
        case let .decoderStarted(_, contract):
            guard contract.decoderGeneration == decoderGeneration else {
                reject(.staleDecoderGeneration)
                return
            }
            lastFrameID = nil
            replaceAdapter(with: nil)
            signalDiscontinuity()
        case let .decodedFrame(_, frame):
            submit(frame)
        case let .cleared(_, clearedDecoderGeneration):
            guard clearedDecoderGeneration == nil
                    || clearedDecoderGeneration == decoderGeneration else {
                reject(.staleDecoderGeneration)
                return
            }
            lastFrameID = nil
            replaceAdapter(with: nil)
            signalDiscontinuity()
        }
    }

    private func submit(_ frame: DecodedVideoFrame) {
        guard frame.generation == decoderGeneration else {
            reject(.staleDecoderGeneration)
            return
        }
        guard lastFrameID.map({ frame.frameID > $0 }) ?? true else {
            reject(.staleFrame)
            return
        }
        lastFrameID = frame.frameID

        let sampleBuffer: MobilePictureInPictureSampleBuffer
        do {
            sampleBuffer = try makeSampleBuffer(from: frame)
        } catch {
            reject(.sampleBufferConversionFailed)
            signalDiscontinuity()
            return
        }

        let outcome = frameSink.submit(sampleBuffer)
        switch outcome {
        case .enqueued, .retainedLatestPending, .replacedPending:
            increment(&submittedFrameCount)
        case .rejected:
            reject(.frameSinkRejected)
        }
        _ = lifecycleCoordinator.refreshFrameSink()
    }

    private func makeSampleBuffer(
        from frame: DecodedVideoFrame
    ) throws -> MobilePictureInPictureSampleBuffer {
        if adapter == nil
            || adapterColorMetadata != frame.colorMetadata {
            replaceAdapter(with: try makeAdapter(
                colorMetadata: frame.colorMetadata
            ), colorMetadata: frame.colorMetadata)
        }
        guard let adapter else {
            throw MobilePictureInPictureSampleBufferAdapterError.invalidated
        }
        do {
            return try adapter.makeSampleBuffer(
                from: frame,
                generation: generation
            )
        } catch MobilePictureInPictureSampleBufferAdapterError
                    .incompatibleFrameContract {
            let replacement = try makeAdapter(
                colorMetadata: frame.colorMetadata
            )
            replaceAdapter(
                with: replacement,
                colorMetadata: frame.colorMetadata
            )
            return try replacement.makeSampleBuffer(
                from: frame,
                generation: generation
            )
        }
    }

    private func makeAdapter(
        colorMetadata: VideoColorMetadata
    ) throws -> MobilePictureInPictureSampleBufferAdapter {
        try adapterFactory(
            generation,
            decoderGeneration,
            colorMetadata
        )
    }

    private func replaceAdapter(
        with replacement:
            MobilePictureInPictureSampleBufferAdapter?,
        colorMetadata: VideoColorMetadata? = nil
    ) {
        if adapter != nil, replacement != nil {
            increment(&adapterReplacementCount)
        }
        adapter?.invalidate()
        adapter = replacement
        adapterColorMetadata = replacement == nil ? nil : colorMetadata
    }

    private func signalDiscontinuity() {
        if frameSink.signalDiscontinuity(generation: generation) {
            increment(&discontinuityCount)
        }
        _ = lifecycleCoordinator.refreshFrameSink()
    }

    private func reject(
        _ rejection: MobilePictureInPictureFrameDeliveryRejection
    ) {
        _ = rejection
        increment(&rejectedFrameCount)
    }

    private func handleLifecycleEvent(
        _ event: MobilePictureInPictureLifecycleCoordinatorEvent
    ) {
        guard !isInvalidated else { return }
        switch event {
        case let .snapshot(snapshot):
            updateConfirmedActive(snapshot.state.lifecycle)
            lifecycleEventHandler?(event)
            if snapshot.state.lifecycle == .invalidated {
                finishInvalidation()
            }
        case let .restoreInterfaceRequested(lease):
            guard lifecycleEventHandler != nil else {
                _ = lifecycleCoordinator.completeRestoration(
                    lease,
                    result: .declined
                )
                return
            }
            pendingRestorationLeases.insert(lease)
            lifecycleEventHandler?(event)
        case let .skipRequested(_, completion):
            guard lifecycleEventHandler != nil else {
                _ = lifecycleCoordinator.completeSkip(completion)
                return
            }
            pendingSkipLeases.insert(completion)
            lifecycleEventHandler?(event)
        case .revisionExhausted:
            lifecycleEventHandler?(event)
            finishInvalidation()
        case .setPlayingRequested,
             .renderSizeChanged,
             .rejected:
            lifecycleEventHandler?(event)
        }
    }

    private func updateConfirmedActive(
        _ lifecycle: MobilePictureInPictureLifecycle
    ) {
        switch lifecycle {
        case .active:
            isConfirmedActive = true
        case .unprepared, .preparing, .unavailable, .ready,
             .stopped, .failed, .invalidated:
            isConfirmedActive = false
        case .startRequested, .starting, .stopRequested, .stopping:
            break
        }
        applyForegroundPolicy()
    }

    private func applyForegroundPolicy() {
        let policy: RenderPolicy
        if isConfirmedActive {
            switch foregroundSuppression {
            case .paused:
                policy = .paused(
                    reason: Self.foregroundSuppressionReason
                )
            case .throttled:
                policy = .throttled(
                    reason: Self.foregroundSuppressionReason
                )
            }
        } else {
            policy = foregroundBaseline
        }
        guard policy != appliedForegroundPolicy else { return }
        appliedForegroundPolicy = policy
        foregroundPolicyHandler(policy)
    }

    private func completePendingExternalCallbacks() {
        let restorationLeases = Array(pendingRestorationLeases)
        let skipLeases = Array(pendingSkipLeases)
        pendingRestorationLeases.removeAll(keepingCapacity: false)
        pendingSkipLeases.removeAll(keepingCapacity: false)
        for lease in restorationLeases {
            _ = lifecycleCoordinator.completeRestoration(
                lease,
                result: .declined
            )
        }
        for lease in skipLeases {
            _ = lifecycleCoordinator.completeSkip(lease)
        }
    }

    private func finishInvalidation() {
        guard !isInvalidated else { return }
        isTerminating = true
        subscription?.cancel()
        subscription = nil
        mailbox.invalidate()
        adapter?.invalidate()
        adapter = nil
        adapterColorMetadata = nil
        pendingRestorationLeases.removeAll(keepingCapacity: false)
        pendingSkipLeases.removeAll(keepingCapacity: false)
        lifecycleEventHandler = nil
        isConfirmedActive = false
        applyForegroundPolicy()
        isInvalidated = true
    }

    private func increment(_ value: inout UInt64) {
        if value < .max {
            value += 1
        }
    }
}

private final class StreamVideoPresentationDeliveryMailbox:
    @unchecked Sendable
{
    typealias Handler = @MainActor @Sendable (
        StreamVideoPresentationDelivery
    ) -> Void

    private let lock = NSLock()
    private var handler: Handler?
    private var pendingDelivery: StreamVideoPresentationDelivery?
    private var isDrainScheduled = false
    private var isInvalidated = false
    private var coalescedCount: UInt64 = 0

    var coalescedDeliveryCount: UInt64 {
        lock.withLock { coalescedCount }
    }

    @MainActor
    func setHandler(_ handler: @escaping Handler) {
        lock.withLock {
            guard !isInvalidated else { return }
            self.handler = handler
        }
    }

    func enqueue(_ delivery: StreamVideoPresentationDelivery) {
        let shouldSchedule = lock.withLock {
            guard !isInvalidated else { return false }
            if pendingDelivery != nil, coalescedCount < .max {
                coalescedCount += 1
            }
            pendingDelivery = delivery
            guard !isDrainScheduled else { return false }
            isDrainScheduled = true
            return true
        }
        guard shouldSchedule else { return }
        Task { @MainActor [weak self] in
            self?.drain()
        }
    }

    func invalidate() {
        lock.withLock {
            guard !isInvalidated else { return }
            isInvalidated = true
            handler = nil
            pendingDelivery = nil
            isDrainScheduled = false
        }
    }

    @MainActor
    private func drain() {
        while let next = takeNext() {
            next.handler(next.delivery)
        }
    }

    private func takeNext() -> (
        delivery: StreamVideoPresentationDelivery,
        handler: Handler
    )? {
        lock.withLock {
            guard !isInvalidated,
                  let delivery = pendingDelivery,
                  let handler else {
                isDrainScheduled = false
                return nil
            }
            pendingDelivery = nil
            return (delivery, handler)
        }
    }
}
