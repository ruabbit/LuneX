@preconcurrency import CoreVideo
import Foundation

struct StreamVideoPresentationSnapshot: Equatable, Sendable {
    var sessionID: UUID?
    var mediaGeneration: UInt64?
    var decoderGeneration: UInt64?
    var presentationRevision: UInt64
    var deliveryRevision: UInt64
    var latestFrameID: UInt64?
    var publishedFrameCount: UInt64
    var presentedFrameCount: UInt64
    var supersededBeforePresentationCount: UInt64
    var lastPresentedFrameID: UInt64?
    var latestFrameAgeNanoseconds: UInt64
    var lastPresentationDelayNanoseconds: UInt64
    var maximumPresentationDelayNanoseconds: UInt64
    var staleFrameDropCount: UInt64
    var clearCount: UInt64
    var activeSubscriptionCount: Int
    var isPresentationRevisionExhausted: Bool
    var isDeliveryRevisionExhausted: Bool
}

struct StreamVideoPresentationOwnership: Equatable, Sendable {
    let sessionID: UUID
    let mediaGeneration: UInt64
    let revision: UInt64
}

struct StreamVideoDecoderPresentationContract: Equatable, Sendable {
    let decoderGeneration: UInt64
    let colorMetadata: VideoColorMetadata
}

struct StreamVideoDecodedPresentationContract: Equatable, Sendable {
    let decoderGeneration: UInt64
    let colorMetadata: VideoColorMetadata
    let decodedLayout: HDRDecodedPixelBufferLayout
}

enum StreamVideoPresentationEvent: Equatable, Sendable {
    case decoderStarted(
        ownership: StreamVideoPresentationOwnership,
        contract: StreamVideoDecoderPresentationContract
    )
    case decodedFrame(
        ownership: StreamVideoPresentationOwnership,
        contract: StreamVideoDecodedPresentationContract
    )
    case cleared(
        ownership: StreamVideoPresentationOwnership,
        decoderGeneration: UInt64?
    )

    var ownership: StreamVideoPresentationOwnership {
        switch self {
        case let .decoderStarted(ownership, _),
             let .decodedFrame(ownership, _),
             let .cleared(ownership, _):
            return ownership
        }
    }
}

struct StreamVideoPresentationDeliveryOwnership: Equatable, Sendable {
    let sessionID: UUID
    let mediaGeneration: UInt64
    let revision: UInt64
}

enum StreamVideoPresentationDelivery: @unchecked Sendable {
    case decoderStarted(
        ownership: StreamVideoPresentationDeliveryOwnership,
        contract: StreamVideoDecoderPresentationContract
    )
    case decodedFrame(
        ownership: StreamVideoPresentationDeliveryOwnership,
        frame: DecodedVideoFrame
    )
    case cleared(
        ownership: StreamVideoPresentationDeliveryOwnership,
        decoderGeneration: UInt64?
    )

    var ownership: StreamVideoPresentationDeliveryOwnership {
        switch self {
        case let .decoderStarted(ownership, _),
             let .decodedFrame(ownership, _),
             let .cleared(ownership, _):
            return ownership
        }
    }
}

final class StreamVideoPresentationSubscription: @unchecked Sendable {
    private let lock = NSLock()
    private var cancellation: (@Sendable () -> Void)?

    init(cancellation: @escaping @Sendable () -> Void) {
        self.cancellation = cancellation
    }

    func cancel() {
        let operation: (@Sendable () -> Void)? = lock.withLock {
            defer { cancellation = nil }
            return cancellation
        }
        operation?()
    }

    deinit {
        cancel()
    }
}

final class StreamVideoPresentationSource: @unchecked Sendable {
    static let maximumSubscriptionCount = 8

    typealias DeliveryHandler =
        @Sendable (StreamVideoPresentationDelivery) -> Void

    private struct Subscriber {
        let sessionID: UUID
        let mediaGeneration: UInt64
        let handler: DeliveryHandler
    }

    private struct DeliveryPublication {
        let delivery: StreamVideoPresentationDelivery
        let handlers: [DeliveryHandler]
    }

    private let lock = NSLock()
    private let nowNanoseconds: @Sendable () -> UInt64
    private var sessionID: UUID?
    private var mediaGeneration: UInt64?
    private var decoderGeneration: UInt64?
    private var invalidatedDecoderGeneration: UInt64?
    private var latestFrame: DecodedVideoFrame?
    private var latestFramePublishedAtNanoseconds: UInt64?
    private var lastPresentedFrameID: UInt64?
    private var lastPublishedContract: StreamVideoDecodedPresentationContract?
    private var presentationRevision: UInt64
    private var deliveryRevision: UInt64
    private var isPresentationRevisionExhausted = false
    private var isDeliveryRevisionExhausted = false
    private var publishedFrameCount: UInt64 = 0
    private var presentedFrameCount: UInt64 = 0
    private var supersededBeforePresentationCount: UInt64 = 0
    private var lastPresentationDelayNanoseconds: UInt64 = 0
    private var maximumPresentationDelayNanoseconds: UInt64 = 0
    private var staleFrameDropCount: UInt64 = 0
    private var clearCount: UInt64 = 0
    private var subscribers: [UUID: Subscriber] = [:]

    init(
        initialPresentationRevision: UInt64 = 0,
        initialDeliveryRevision: UInt64 = 0,
        nowNanoseconds: @escaping @Sendable () -> UInt64 = {
            DispatchTime.now().uptimeNanoseconds
        }
    ) {
        presentationRevision = initialPresentationRevision
        deliveryRevision = initialDeliveryRevision
        self.nowNanoseconds = nowNanoseconds
    }

    @discardableResult
    func beginSession(
        sessionID: UUID,
        mediaGeneration: UInt64
    ) -> StreamVideoPresentationEvent? {
        var publication: DeliveryPublication?
        let event: StreamVideoPresentationEvent? = withLock {
            if self.sessionID != sessionID
                || self.mediaGeneration != mediaGeneration
                || latestFrame != nil
                || decoderGeneration != nil {
                clearCount = Self.saturatedIncrement(clearCount)
            }
            self.sessionID = sessionID
            self.mediaGeneration = mediaGeneration
            decoderGeneration = nil
            invalidatedDecoderGeneration = nil
            latestFrame = nil
            latestFramePublishedAtNanoseconds = nil
            lastPresentedFrameID = nil
            lastPublishedContract = nil
            guard let event = makeEvent({ ownership in
                .cleared(ownership: ownership, decoderGeneration: nil)
            }) else {
                publication = makePresentationExhaustionPublication(
                    decoderGeneration: nil
                )
                return nil
            }
            publication = makeDeliveryPublication { ownership in
                .cleared(ownership: ownership, decoderGeneration: nil)
            }
            return publication == nil || isDeliveryRevisionExhausted
                ? nil
                : event
        }
        publish(publication)
        return event
    }

    @discardableResult
    func consume(
        _ event: VideoDecoderEvent,
        sessionID: UUID,
        mediaGeneration: UInt64
    ) -> StreamVideoPresentationEvent? {
        var publication: DeliveryPublication?
        let presentationEvent: StreamVideoPresentationEvent? = withLock {
            guard self.sessionID == sessionID,
                  self.mediaGeneration == mediaGeneration else {
                if case .frame = event {
                    staleFrameDropCount = Self.saturatedIncrement(staleFrameDropCount)
                }
                return nil
            }
            guard !isPresentationRevisionExhausted,
                  !isDeliveryRevisionExhausted else {
                if case .frame = event {
                    staleFrameDropCount = Self.saturatedIncrement(staleFrameDropCount)
                }
                return nil
            }
            switch event {
            case let .sessionStarted(generation, colorMetadata):
                if let invalidatedDecoderGeneration,
                   generation <= invalidatedDecoderGeneration {
                    return nil
                }
                decoderGeneration = generation
                latestFrame = nil
                latestFramePublishedAtNanoseconds = nil
                lastPresentedFrameID = nil
                let decoderContract = StreamVideoDecoderPresentationContract(
                    decoderGeneration: generation,
                    colorMetadata: colorMetadata
                )
                lastPublishedContract = nil
                guard let presentationEvent = makeEvent({ ownership in
                    .decoderStarted(
                        ownership: ownership,
                        contract: decoderContract
                    )
                }) else {
                    publication = makePresentationExhaustionPublication(
                        decoderGeneration: generation
                    )
                    return nil
                }
                publication = makeDeliveryPublication { ownership in
                    .decoderStarted(
                        ownership: ownership,
                        contract: decoderContract
                    )
                }
                return publication == nil || isDeliveryRevisionExhausted
                    ? nil
                    : presentationEvent
            case let .frame(frame):
                guard frame.generation == decoderGeneration else {
                    staleFrameDropCount = Self.saturatedIncrement(staleFrameDropCount)
                    return nil
                }
                if let latestFrame,
                   latestFrame.frameID != lastPresentedFrameID {
                    supersededBeforePresentationCount = Self.saturatedIncrement(
                        supersededBeforePresentationCount
                    )
                }
                latestFrame = frame
                latestFramePublishedAtNanoseconds = nowNanoseconds()
                publishedFrameCount = Self.saturatedIncrement(publishedFrameCount)
                let contract = StreamVideoDecodedPresentationContract(
                    decoderGeneration: frame.generation,
                    colorMetadata: frame.colorMetadata,
                    decodedLayout: HDRDecodedPixelBufferLayout(
                        pixelBuffer: frame.pixelBuffer
                    )
                )
                let presentationEvent: StreamVideoPresentationEvent?
                if contract != lastPublishedContract {
                    lastPublishedContract = contract
                    guard let event = makeEvent({ ownership in
                        .decodedFrame(
                            ownership: ownership,
                            contract: contract
                        )
                    }) else {
                        publication =
                            makePresentationExhaustionPublication(
                                decoderGeneration: frame.generation
                            )
                        return nil
                    }
                    presentationEvent = event
                } else {
                    presentationEvent = nil
                }
                publication = makeDeliveryPublication { ownership in
                    .decodedFrame(ownership: ownership, frame: frame)
                }
                return publication == nil || isDeliveryRevisionExhausted
                    ? nil
                    : presentationEvent
            case let .sessionStopped(generation):
                guard generation == decoderGeneration else { return nil }
                decoderGeneration = nil
                latestFrame = nil
                latestFramePublishedAtNanoseconds = nil
                lastPresentedFrameID = nil
                lastPublishedContract = nil
                clearCount = Self.saturatedIncrement(clearCount)
                guard let presentationEvent = makeEvent({ ownership in
                    .cleared(
                        ownership: ownership,
                        decoderGeneration: generation
                    )
                }) else {
                    publication = makePresentationExhaustionPublication(
                        decoderGeneration: generation
                    )
                    return nil
                }
                publication = makeDeliveryPublication { ownership in
                    .cleared(
                        ownership: ownership,
                        decoderGeneration: generation
                    )
                }
                return publication == nil || isDeliveryRevisionExhausted
                    ? nil
                    : presentationEvent
            case let .failure(failure):
                guard failure.generation == nil || failure.generation == decoderGeneration else {
                    return nil
                }
                latestFrame = nil
                latestFramePublishedAtNanoseconds = nil
                lastPresentedFrameID = nil
                lastPublishedContract = nil
                clearCount = Self.saturatedIncrement(clearCount)
                guard let presentationEvent = makeEvent({ ownership in
                    .cleared(
                        ownership: ownership,
                        decoderGeneration: failure.generation
                    )
                }) else {
                    publication = makePresentationExhaustionPublication(
                        decoderGeneration: failure.generation
                    )
                    return nil
                }
                publication = makeDeliveryPublication { ownership in
                    .cleared(
                        ownership: ownership,
                        decoderGeneration: failure.generation
                    )
                }
                return publication == nil || isDeliveryRevisionExhausted
                    ? nil
                    : presentationEvent
            case .frameDropped:
                return nil
            }
        }
        publish(publication)
        return presentationEvent
    }

    func currentFrame() -> DecodedVideoFrame? {
        withLock { latestFrame }
    }

    func recordPresentedFrame(_ frameID: UInt64) {
        let now = nowNanoseconds()
        withLock {
            guard latestFrame?.frameID == frameID,
                  lastPresentedFrameID != frameID else { return }
            lastPresentedFrameID = frameID
            presentedFrameCount = Self.saturatedIncrement(presentedFrameCount)
            let delay = Self.elapsedNanoseconds(
                since: latestFramePublishedAtNanoseconds,
                now: now
            )
            lastPresentationDelayNanoseconds = delay
            maximumPresentationDelayNanoseconds = max(
                maximumPresentationDelayNanoseconds,
                delay
            )
        }
    }

    func subscribe(
        sessionID: UUID,
        mediaGeneration: UInt64,
        handler: @escaping DeliveryHandler
    ) -> StreamVideoPresentationSubscription? {
        let subscriptionID = UUID()
        var replay: StreamVideoPresentationDelivery?
        let registered = withLock {
            guard !isPresentationRevisionExhausted,
                  !isDeliveryRevisionExhausted,
                  subscribers.count < Self.maximumSubscriptionCount else {
                return false
            }
            subscribers[subscriptionID] = Subscriber(
                sessionID: sessionID,
                mediaGeneration: mediaGeneration,
                handler: handler
            )
            if self.sessionID == sessionID,
               self.mediaGeneration == mediaGeneration,
               deliveryRevision > 0,
               let latestFrame {
                replay = .decodedFrame(
                    ownership: StreamVideoPresentationDeliveryOwnership(
                        sessionID: sessionID,
                        mediaGeneration: mediaGeneration,
                        revision: deliveryRevision
                    ),
                    frame: latestFrame
                )
            }
            return true
        }
        guard registered else { return nil }
        let subscription = StreamVideoPresentationSubscription {
            [weak self] in
            self?.removeSubscriber(subscriptionID)
        }
        if let replay {
            handler(replay)
        }
        return subscription
    }

    @discardableResult
    func discardFrames(
        sessionID: UUID,
        mediaGeneration: UInt64
    ) -> StreamVideoPresentationEvent? {
        var publication: DeliveryPublication?
        let event: StreamVideoPresentationEvent? = withLock {
            guard self.sessionID == sessionID,
                  self.mediaGeneration == mediaGeneration,
                  !isPresentationRevisionExhausted,
                  !isDeliveryRevisionExhausted else { return nil }
            let clearedDecoderGeneration = decoderGeneration
            let hadPresentation = decoderGeneration != nil
                || latestFrame != nil
                || lastPublishedContract != nil
            if decoderGeneration != nil || latestFrame != nil {
                clearCount = Self.saturatedIncrement(clearCount)
            }
            if let decoderGeneration {
                invalidatedDecoderGeneration = max(
                    invalidatedDecoderGeneration ?? 0,
                    decoderGeneration
                )
            }
            decoderGeneration = nil
            latestFrame = nil
            latestFramePublishedAtNanoseconds = nil
            lastPresentedFrameID = nil
            lastPublishedContract = nil
            guard hadPresentation else { return nil }
            guard let event = makeEvent({ ownership in
                .cleared(
                    ownership: ownership,
                    decoderGeneration: clearedDecoderGeneration
                )
            }) else {
                publication = makePresentationExhaustionPublication(
                    decoderGeneration: clearedDecoderGeneration
                )
                return nil
            }
            publication = makeDeliveryPublication { ownership in
                .cleared(
                    ownership: ownership,
                    decoderGeneration: clearedDecoderGeneration
                )
            }
            return publication == nil || isDeliveryRevisionExhausted
                ? nil
                : event
        }
        publish(publication)
        return event
    }

    @discardableResult
    func clear(
        sessionID: UUID,
        mediaGeneration: UInt64
    ) -> StreamVideoPresentationEvent? {
        var publication: DeliveryPublication?
        let event: StreamVideoPresentationEvent? = withLock {
            guard self.sessionID == sessionID,
                  self.mediaGeneration == mediaGeneration else { return nil }
            let event = makeEvent { ownership in
                .cleared(ownership: ownership, decoderGeneration: nil)
            }
            if event != nil {
                publication = makeDeliveryPublication { ownership in
                    .cleared(ownership: ownership, decoderGeneration: nil)
                }
            } else {
                publication = makePresentationExhaustionPublication(
                    decoderGeneration: nil
                )
            }
            self.sessionID = nil
            self.mediaGeneration = nil
            decoderGeneration = nil
            invalidatedDecoderGeneration = nil
            latestFrame = nil
            latestFramePublishedAtNanoseconds = nil
            lastPresentedFrameID = nil
            lastPublishedContract = nil
            clearCount = Self.saturatedIncrement(clearCount)
            return publication == nil || isDeliveryRevisionExhausted
                ? nil
                : event
        }
        publish(publication)
        return event
    }

    func snapshot() -> StreamVideoPresentationSnapshot {
        let now = nowNanoseconds()
        return withLock {
            StreamVideoPresentationSnapshot(
                sessionID: sessionID,
                mediaGeneration: mediaGeneration,
                decoderGeneration: decoderGeneration,
                presentationRevision: presentationRevision,
                deliveryRevision: deliveryRevision,
                latestFrameID: latestFrame?.frameID,
                publishedFrameCount: publishedFrameCount,
                presentedFrameCount: presentedFrameCount,
                supersededBeforePresentationCount:
                    supersededBeforePresentationCount,
                lastPresentedFrameID: lastPresentedFrameID,
                latestFrameAgeNanoseconds: Self.elapsedNanoseconds(
                    since: latestFramePublishedAtNanoseconds,
                    now: now
                ),
                lastPresentationDelayNanoseconds:
                    lastPresentationDelayNanoseconds,
                maximumPresentationDelayNanoseconds:
                    maximumPresentationDelayNanoseconds,
                staleFrameDropCount: staleFrameDropCount,
                clearCount: clearCount,
                activeSubscriptionCount: subscribers.count,
                isPresentationRevisionExhausted:
                    isPresentationRevisionExhausted,
                isDeliveryRevisionExhausted:
                    isDeliveryRevisionExhausted
            )
        }
    }

    private func makeEvent(
        _ make: (StreamVideoPresentationOwnership) -> StreamVideoPresentationEvent
    ) -> StreamVideoPresentationEvent? {
        guard !isPresentationRevisionExhausted else {
            clearRevisionOwnedPresentation()
            return nil
        }
        let nextRevision = presentationRevision.addingReportingOverflow(1)
        guard !nextRevision.overflow else {
            clearRevisionOwnedPresentation()
            isPresentationRevisionExhausted = true
            return nil
        }
        presentationRevision = nextRevision.partialValue
        return make(StreamVideoPresentationOwnership(
            sessionID: sessionID!,
            mediaGeneration: mediaGeneration!,
            revision: presentationRevision
        ))
    }

    private func clearRevisionOwnedPresentation() {
        decoderGeneration = nil
        invalidatedDecoderGeneration = nil
        latestFrame = nil
        latestFramePublishedAtNanoseconds = nil
        lastPresentedFrameID = nil
        lastPublishedContract = nil
    }

    private func makeDeliveryPublication(
        _ make: (StreamVideoPresentationDeliveryOwnership)
            -> StreamVideoPresentationDelivery
    ) -> DeliveryPublication? {
        guard !isDeliveryRevisionExhausted else {
            clearRevisionOwnedPresentation()
            return nil
        }
        let nextRevision = deliveryRevision.addingReportingOverflow(1)
        guard !nextRevision.overflow else {
            clearRevisionOwnedPresentation()
            isDeliveryRevisionExhausted = true
            subscribers.removeAll(keepingCapacity: false)
            return nil
        }
        deliveryRevision = nextRevision.partialValue
        let ownership = StreamVideoPresentationDeliveryOwnership(
            sessionID: sessionID!,
            mediaGeneration: mediaGeneration!,
            revision: deliveryRevision
        )
        let handlers = subscribers.values.compactMap { subscriber in
            subscriber.sessionID == ownership.sessionID
                && subscriber.mediaGeneration == ownership.mediaGeneration
                ? subscriber.handler
                : nil
        }
        if deliveryRevision == .max {
            clearRevisionOwnedPresentation()
            isDeliveryRevisionExhausted = true
            subscribers.removeAll(keepingCapacity: false)
            return DeliveryPublication(
                delivery: .cleared(
                    ownership: ownership,
                    decoderGeneration: nil
                ),
                handlers: handlers
            )
        }
        return DeliveryPublication(
            delivery: make(ownership),
            handlers: handlers
        )
    }

    private func makePresentationExhaustionPublication(
        decoderGeneration: UInt64?
    ) -> DeliveryPublication? {
        guard isPresentationRevisionExhausted else { return nil }
        let publication = makeDeliveryPublication { ownership in
            .cleared(
                ownership: ownership,
                decoderGeneration: decoderGeneration
            )
        }
        subscribers.removeAll(keepingCapacity: false)
        return publication
    }

    private func publish(_ publication: DeliveryPublication?) {
        guard let publication else { return }
        for handler in publication.handlers {
            handler(publication.delivery)
        }
    }

    private func removeSubscriber(_ subscriptionID: UUID) {
        _ = withLock {
            subscribers.removeValue(forKey: subscriptionID)
        }
    }

    private static func saturatedIncrement(_ value: UInt64) -> UInt64 {
        value == .max ? .max : value + 1
    }

    private static func elapsedNanoseconds(
        since start: UInt64?,
        now: UInt64
    ) -> UInt64 {
        guard let start, now >= start else { return 0 }
        return now - start
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}
