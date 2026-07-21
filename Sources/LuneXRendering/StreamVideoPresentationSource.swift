@preconcurrency import CoreVideo
import Foundation

struct StreamVideoPresentationSnapshot: Equatable, Sendable {
    var sessionID: UUID?
    var mediaGeneration: UInt64?
    var decoderGeneration: UInt64?
    var latestFrameID: UInt64?
    var publishedFrameCount: UInt64
    var staleFrameDropCount: UInt64
    var clearCount: UInt64
}

final class StreamVideoPresentationSource: @unchecked Sendable {
    private let lock = NSLock()
    private var sessionID: UUID?
    private var mediaGeneration: UInt64?
    private var decoderGeneration: UInt64?
    private var invalidatedDecoderGeneration: UInt64?
    private var latestFrame: DecodedVideoFrame?
    private var publishedFrameCount: UInt64 = 0
    private var staleFrameDropCount: UInt64 = 0
    private var clearCount: UInt64 = 0

    func beginSession(sessionID: UUID, mediaGeneration: UInt64) {
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
        }
    }

    func consume(
        _ event: VideoDecoderEvent,
        sessionID: UUID,
        mediaGeneration: UInt64
    ) {
        withLock {
            guard self.sessionID == sessionID,
                  self.mediaGeneration == mediaGeneration else {
                if case .frame = event {
                    staleFrameDropCount &+= 1
                }
                return
            }
            switch event {
            case let .sessionStarted(generation, _):
                if let invalidatedDecoderGeneration,
                   generation <= invalidatedDecoderGeneration {
                    return
                }
                decoderGeneration = generation
                latestFrame = nil
            case let .frame(frame):
                guard frame.generation == decoderGeneration else {
                    staleFrameDropCount &+= 1
                    return
                }
                latestFrame = frame
                publishedFrameCount &+= 1
            case let .sessionStopped(generation):
                guard generation == decoderGeneration else { return }
                decoderGeneration = nil
                latestFrame = nil
                clearCount &+= 1
            case let .failure(failure):
                guard failure.generation == nil || failure.generation == decoderGeneration else {
                    return
                }
                latestFrame = nil
                clearCount &+= 1
            case .frameDropped:
                break
            }
        }
    }

    func currentFrame() -> DecodedVideoFrame? {
        withLock { latestFrame }
    }

    func discardFrames(sessionID: UUID, mediaGeneration: UInt64) {
        withLock {
            guard self.sessionID == sessionID,
                  self.mediaGeneration == mediaGeneration else { return }
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
        }
    }

    func clear(sessionID: UUID, mediaGeneration: UInt64) {
        withLock {
            guard self.sessionID == sessionID,
                  self.mediaGeneration == mediaGeneration else { return }
            self.sessionID = nil
            self.mediaGeneration = nil
            decoderGeneration = nil
            invalidatedDecoderGeneration = nil
            latestFrame = nil
            clearCount &+= 1
        }
    }

    func snapshot() -> StreamVideoPresentationSnapshot {
        withLock {
            StreamVideoPresentationSnapshot(
                sessionID: sessionID,
                mediaGeneration: mediaGeneration,
                decoderGeneration: decoderGeneration,
                latestFrameID: latestFrame?.frameID,
                publishedFrameCount: publishedFrameCount,
                staleFrameDropCount: staleFrameDropCount,
                clearCount: clearCount
            )
        }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}
