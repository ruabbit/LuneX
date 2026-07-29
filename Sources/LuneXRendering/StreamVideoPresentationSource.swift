@preconcurrency import CoreVideo
import Foundation

struct StreamVideoPresentationSnapshot: Equatable, Sendable {
    var sessionID: UUID?
    var mediaGeneration: UInt64?
    var decoderGeneration: UInt64?
    var presentationRevision: UInt64
    var latestFrameID: UInt64?
    var publishedFrameCount: UInt64
    var staleFrameDropCount: UInt64
    var clearCount: UInt64
    var isPresentationRevisionExhausted: Bool
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

final class StreamVideoPresentationSource: @unchecked Sendable {
    private let lock = NSLock()
    private var sessionID: UUID?
    private var mediaGeneration: UInt64?
    private var decoderGeneration: UInt64?
    private var invalidatedDecoderGeneration: UInt64?
    private var latestFrame: DecodedVideoFrame?
    private var lastPublishedContract: StreamVideoDecodedPresentationContract?
    private var presentationRevision: UInt64
    private var isPresentationRevisionExhausted = false
    private var publishedFrameCount: UInt64 = 0
    private var staleFrameDropCount: UInt64 = 0
    private var clearCount: UInt64 = 0

    init(initialPresentationRevision: UInt64 = 0) {
        presentationRevision = initialPresentationRevision
    }

    @discardableResult
    func beginSession(
        sessionID: UUID,
        mediaGeneration: UInt64
    ) -> StreamVideoPresentationEvent? {
        withLock {
            if self.sessionID != sessionID
                || self.mediaGeneration != mediaGeneration
                || latestFrame != nil
                || decoderGeneration != nil {
                clearCount &+= 1
            }
            self.sessionID = sessionID
            self.mediaGeneration = mediaGeneration
            decoderGeneration = nil
            invalidatedDecoderGeneration = nil
            latestFrame = nil
            lastPublishedContract = nil
            return makeEvent { ownership in
                .cleared(ownership: ownership, decoderGeneration: nil)
            }
        }
    }

    @discardableResult
    func consume(
        _ event: VideoDecoderEvent,
        sessionID: UUID,
        mediaGeneration: UInt64
    ) -> StreamVideoPresentationEvent? {
        withLock {
            guard self.sessionID == sessionID,
                  self.mediaGeneration == mediaGeneration else {
                if case .frame = event {
                    staleFrameDropCount &+= 1
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
                lastPublishedContract = nil
                return makeEvent { ownership in
                    .decoderStarted(
                        ownership: ownership,
                        contract: StreamVideoDecoderPresentationContract(
                            decoderGeneration: generation,
                            colorMetadata: colorMetadata
                        )
                    )
                }
            case let .frame(frame):
                guard frame.generation == decoderGeneration else {
                    staleFrameDropCount &+= 1
                    return nil
                }
                latestFrame = frame
                publishedFrameCount &+= 1
                let contract = StreamVideoDecodedPresentationContract(
                    decoderGeneration: frame.generation,
                    colorMetadata: frame.colorMetadata,
                    decodedLayout: HDRDecodedPixelBufferLayout(
                        pixelBuffer: frame.pixelBuffer
                    )
                )
                guard contract != lastPublishedContract else { return nil }
                lastPublishedContract = contract
                return makeEvent { ownership in
                    .decodedFrame(ownership: ownership, contract: contract)
                }
            case let .sessionStopped(generation):
                guard generation == decoderGeneration else { return nil }
                decoderGeneration = nil
                latestFrame = nil
                lastPublishedContract = nil
                clearCount &+= 1
                return makeEvent { ownership in
                    .cleared(
                        ownership: ownership,
                        decoderGeneration: generation
                    )
                }
            case let .failure(failure):
                guard failure.generation == nil || failure.generation == decoderGeneration else {
                    return nil
                }
                latestFrame = nil
                lastPublishedContract = nil
                clearCount &+= 1
                return makeEvent { ownership in
                    .cleared(
                        ownership: ownership,
                        decoderGeneration: failure.generation
                    )
                }
            case .frameDropped:
                return nil
            }
        }
    }

    func currentFrame() -> DecodedVideoFrame? {
        withLock { latestFrame }
    }

    @discardableResult
    func discardFrames(
        sessionID: UUID,
        mediaGeneration: UInt64
    ) -> StreamVideoPresentationEvent? {
        withLock {
            guard self.sessionID == sessionID,
                  self.mediaGeneration == mediaGeneration else { return nil }
            let clearedDecoderGeneration = decoderGeneration
            let hadPresentation = decoderGeneration != nil
                || latestFrame != nil
                || lastPublishedContract != nil
            if decoderGeneration != nil || latestFrame != nil {
                clearCount &+= 1
            }
            if let decoderGeneration {
                invalidatedDecoderGeneration = max(
                    invalidatedDecoderGeneration ?? 0,
                    decoderGeneration
                )
            }
            decoderGeneration = nil
            latestFrame = nil
            lastPublishedContract = nil
            guard hadPresentation else { return nil }
            return makeEvent { ownership in
                .cleared(
                    ownership: ownership,
                    decoderGeneration: clearedDecoderGeneration
                )
            }
        }
    }

    @discardableResult
    func clear(
        sessionID: UUID,
        mediaGeneration: UInt64
    ) -> StreamVideoPresentationEvent? {
        withLock {
            guard self.sessionID == sessionID,
                  self.mediaGeneration == mediaGeneration else { return nil }
            let event = makeEvent { ownership in
                .cleared(ownership: ownership, decoderGeneration: nil)
            }
            self.sessionID = nil
            self.mediaGeneration = nil
            decoderGeneration = nil
            invalidatedDecoderGeneration = nil
            latestFrame = nil
            lastPublishedContract = nil
            clearCount &+= 1
            return event
        }
    }

    func snapshot() -> StreamVideoPresentationSnapshot {
        withLock {
            StreamVideoPresentationSnapshot(
                sessionID: sessionID,
                mediaGeneration: mediaGeneration,
                decoderGeneration: decoderGeneration,
                presentationRevision: presentationRevision,
                latestFrameID: latestFrame?.frameID,
                publishedFrameCount: publishedFrameCount,
                staleFrameDropCount: staleFrameDropCount,
                clearCount: clearCount,
                isPresentationRevisionExhausted:
                    isPresentationRevisionExhausted
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
        lastPublishedContract = nil
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}
