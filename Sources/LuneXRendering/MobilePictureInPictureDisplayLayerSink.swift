@preconcurrency import AVFoundation
@preconcurrency import CoreMedia
import Foundation

enum MobilePictureInPictureVideoRendererStatus:
    Equatable,
    Sendable
{
    case unknown
    case rendering
    case failed
}

typealias MobilePictureInPictureRendererCallback =
    @MainActor @Sendable () -> Void

private final class MobilePictureInPictureRendererObserverTokens:
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
protocol MobilePictureInPictureDisplayLayerRendererClient: AnyObject {
    var status: MobilePictureInPictureVideoRendererStatus { get }
    var requiresFlushToResumeDecoding: Bool { get }
    var isReadyForMoreMediaData: Bool { get }

    func setRendererStateChangeHandler(
        _ handler: MobilePictureInPictureRendererCallback?
    )
    func enqueue(_ sampleBuffer: MobilePictureInPictureSampleBuffer)
    func flush(removingDisplayedImage: Bool)
    func requestMediaDataWhenReady(
        _ handler: @escaping MobilePictureInPictureRendererCallback
    )
    func stopRequestingMediaData()
    func invalidate()
}

@MainActor
final class MobilePictureInPictureDisplayLayerClient:
    MobilePictureInPictureDisplayLayerRendererClient
{
    let displayLayer: AVSampleBufferDisplayLayer

    private let renderer: AVSampleBufferVideoRenderer
    private let notificationCenter: NotificationCenter
    private let notificationTokens:
        MobilePictureInPictureRendererObserverTokens
    private let readinessQueue: DispatchQueue
    private var rendererStateChangeHandler:
        MobilePictureInPictureRendererCallback?
    private var readinessHandler:
        MobilePictureInPictureRendererCallback?
    private var readinessRequestOrdinal: UInt64?
    private var nextReadinessRequestOrdinal: UInt64 = 0
    private(set) var isInvalidated = false

    init(
        displayLayer: AVSampleBufferDisplayLayer =
            AVSampleBufferDisplayLayer(),
        notificationCenter: NotificationCenter = .default,
        readinessQueue: DispatchQueue = DispatchQueue(
            label: "dev.lunex.pip.sample-buffer-readiness",
            qos: .userInteractive
        )
    ) {
        self.displayLayer = displayLayer
        renderer = displayLayer.sampleBufferRenderer
        self.notificationCenter = notificationCenter
        notificationTokens =
            MobilePictureInPictureRendererObserverTokens(
                notificationCenter: notificationCenter
            )
        self.readinessQueue = readinessQueue
        installRendererNotifications()
    }

    var status: MobilePictureInPictureVideoRendererStatus {
        switch renderer.status {
        case .unknown:
            .unknown
        case .rendering:
            .rendering
        case .failed:
            .failed
        @unknown default:
            .failed
        }
    }

    var requiresFlushToResumeDecoding: Bool {
        renderer.requiresFlushToResumeDecoding
    }

    var isReadyForMoreMediaData: Bool {
        !isInvalidated && renderer.isReadyForMoreMediaData
    }

    func setRendererStateChangeHandler(
        _ handler: MobilePictureInPictureRendererCallback?
    ) {
        rendererStateChangeHandler = isInvalidated ? nil : handler
    }

    func enqueue(
        _ sampleBuffer: MobilePictureInPictureSampleBuffer
    ) {
        guard !isInvalidated else { return }
        renderer.enqueue(sampleBuffer.sampleBuffer)
    }

    func flush(removingDisplayedImage: Bool) {
        guard !isInvalidated else { return }
        if removingDisplayedImage {
            renderer.flush(
                removingDisplayedImage: true,
                completionHandler: nil
            )
        } else {
            renderer.flush()
        }
    }

    func requestMediaDataWhenReady(
        _ handler: @escaping MobilePictureInPictureRendererCallback
    ) {
        guard !isInvalidated else { return }
        stopRequestingMediaData()
        guard nextReadinessRequestOrdinal < .max else { return }
        nextReadinessRequestOrdinal += 1
        let ordinal = nextReadinessRequestOrdinal
        readinessRequestOrdinal = ordinal
        readinessHandler = handler
        renderer.requestMediaDataWhenReady(on: readinessQueue) {
            [weak self] in
            Task { @MainActor [weak self] in
                guard let self,
                      !self.isInvalidated,
                      self.readinessRequestOrdinal == ordinal else {
                    return
                }
                self.readinessHandler?()
            }
        }
    }

    func stopRequestingMediaData() {
        guard readinessRequestOrdinal != nil else { return }
        readinessRequestOrdinal = nil
        readinessHandler = nil
        renderer.stopRequestingMediaData()
    }

    func invalidate() {
        guard !isInvalidated else { return }
        stopRequestingMediaData()
        isInvalidated = true
        rendererStateChangeHandler = nil
        removeRendererNotifications()
        renderer.flush(
            removingDisplayedImage: true,
            completionHandler: nil
        )
    }

    private func installRendererNotifications() {
        let names: [Notification.Name] = [
            AVSampleBufferVideoRenderer.didFailToDecodeNotification,
            AVSampleBufferVideoRenderer
                .requiresFlushToResumeDecodingDidChangeNotification
        ]
        notificationTokens.replace(names.map { name in
            notificationCenter.addObserver(
                forName: name,
                object: renderer,
                queue: nil
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, !self.isInvalidated else { return }
                    self.rendererStateChangeHandler?()
                }
            }
        })
    }

    private func removeRendererNotifications() {
        notificationTokens.removeAll()
    }

    deinit {
        if readinessRequestOrdinal != nil {
            renderer.stopRequestingMediaData()
        }
    }
}

enum MobilePictureInPictureDisplayLayerRejectionReason:
    Equatable,
    Sendable
{
    case invalidated
    case stalePictureInPictureGeneration
    case staleDecoderGeneration(expected: UInt64, actual: UInt64)
    case rendererFailed
}

enum MobilePictureInPictureDisplayLayerSubmissionOutcome:
    Equatable,
    Sendable
{
    case enqueued
    case retainedLatestPending
    case replacedPending
    case rejected(MobilePictureInPictureDisplayLayerRejectionReason)
}

struct MobilePictureInPictureDisplayLayerSinkSnapshot:
    Equatable,
    Sendable
{
    let generation: MobilePictureInPictureGeneration
    let frameSink: MobilePictureInPictureFrameSinkSnapshot
    let activeFrameContract: HDRValidatedDecodedFrameContract?
    let pendingFrameID: UInt64?
    let enqueuedFrameCount: UInt64
    let replacedPendingFrameCount: UInt64
    let rejectedFrameCount: UInt64
    let formatFlushCount: UInt64
    let discontinuityFlushCount: UInt64
    let failureRecoveryCount: UInt64
    let readinessRequestCount: UInt64
    let readinessStopCount: UInt64
    let isInvalidated: Bool
}

enum MobilePictureInPictureDisplayLayerSinkError:
    Error,
    Equatable,
    Sendable
{
    case invalidDecoderGeneration
}

@MainActor
final class MobilePictureInPictureDisplayLayerSink {
    let generation: MobilePictureInPictureGeneration
    let decoderGeneration: UInt64

    private let client:
        any MobilePictureInPictureDisplayLayerRendererClient
    private var activeFrameContract: HDRValidatedDecodedFrameContract?
    private var pendingSampleBuffer:
        MobilePictureInPictureSampleBuffer?
    private var phase: MobilePictureInPictureFrameSinkPhase = .ready
    private var readinessRequestOrdinal: UInt64?
    private var nextReadinessRequestOrdinal: UInt64 = 0
    private var enqueuedFrameCount: UInt64 = 0
    private var replacedPendingFrameCount: UInt64 = 0
    private var rejectedFrameCount: UInt64 = 0
    private var formatFlushCount: UInt64 = 0
    private var discontinuityFlushCount: UInt64 = 0
    private var failureRecoveryCount: UInt64 = 0
    private var readinessRequestCount: UInt64 = 0
    private var readinessStopCount: UInt64 = 0
    private var isInvalidated = false

    init(
        generation: MobilePictureInPictureGeneration,
        decoderGeneration: UInt64,
        client: any MobilePictureInPictureDisplayLayerRendererClient
    ) throws {
        guard decoderGeneration > 0 else {
            throw MobilePictureInPictureDisplayLayerSinkError
                .invalidDecoderGeneration
        }
        self.generation = generation
        self.decoderGeneration = decoderGeneration
        self.client = client
        client.setRendererStateChangeHandler { [weak self] in
            self?.rendererStateDidChange()
        }
        if client.status == .failed
            || client.requiresFlushToResumeDecoding {
            recoverRendererFailure()
        }
    }

    func submit(
        _ sampleBuffer: MobilePictureInPictureSampleBuffer
    ) -> MobilePictureInPictureDisplayLayerSubmissionOutcome {
        guard !isInvalidated else {
            return reject(.invalidated)
        }
        guard sampleBuffer.identity.generation == generation else {
            return reject(.stalePictureInPictureGeneration)
        }
        guard sampleBuffer.identity.decoderGeneration
                == decoderGeneration else {
            return reject(.staleDecoderGeneration(
                expected: decoderGeneration,
                actual: sampleBuffer.identity.decoderGeneration
            ))
        }
        guard ensureRendererIsUsable() else {
            return reject(.rendererFailed)
        }

        let replacedPending = pendingSampleBuffer != nil
        if let activeFrameContract,
           activeFrameContract != sampleBuffer.identity.frameContract {
            stopReadinessRequest()
            pendingSampleBuffer = nil
            self.activeFrameContract = nil
            client.flush(removingDisplayedImage: true)
            increment(&formatFlushCount)
        }
        if activeFrameContract == nil {
            activeFrameContract = sampleBuffer.identity.frameContract
        }

        guard client.isReadyForMoreMediaData else {
            pendingSampleBuffer = sampleBuffer
            if replacedPending {
                increment(&replacedPendingFrameCount)
            }
            phase = .backpressured
            requestReadinessIfNeeded()
            return replacedPending
                ? .replacedPending
                : .retainedLatestPending
        }

        if replacedPending {
            stopReadinessRequest()
            pendingSampleBuffer = nil
            increment(&replacedPendingFrameCount)
        }
        client.enqueue(sampleBuffer)
        increment(&enqueuedFrameCount)
        if client.status == .failed
            || client.requiresFlushToResumeDecoding {
            recoverRendererFailure()
            return reject(.rendererFailed)
        }
        pendingSampleBuffer = nil
        phase = .ready
        return .enqueued
    }

    @discardableResult
    func signalDiscontinuity(
        generation requestedGeneration:
            MobilePictureInPictureGeneration
    ) -> Bool {
        guard !isInvalidated,
              requestedGeneration == generation else {
            return false
        }
        stopReadinessRequest()
        pendingSampleBuffer = nil
        activeFrameContract = nil
        client.flush(removingDisplayedImage: true)
        increment(&discontinuityFlushCount)
        if client.status == .failed
            || client.requiresFlushToResumeDecoding {
            phase = .failed(.frameSinkFailed)
        } else {
            phase = .ready
        }
        return true
    }

    func snapshot()
        -> MobilePictureInPictureDisplayLayerSinkSnapshot
    {
        let frameSink: MobilePictureInPictureFrameSinkSnapshot
        switch phase {
        case .detached:
            frameSink = .detached
        case .ready:
            frameSink =
                MobilePictureInPictureFrameSinkSnapshot.ready(
                    decoderGeneration: decoderGeneration
                )!
        case .backpressured:
            frameSink =
                MobilePictureInPictureFrameSinkSnapshot.backpressured(
                    decoderGeneration: decoderGeneration,
                    pendingFrameCount:
                        pendingSampleBuffer == nil ? 0 : 1
                )!
        case let .failed(failure):
            frameSink = .failed(failure)
        case .invalidated:
            frameSink = .invalidated
        }
        return MobilePictureInPictureDisplayLayerSinkSnapshot(
            generation: generation,
            frameSink: frameSink,
            activeFrameContract: activeFrameContract,
            pendingFrameID: pendingSampleBuffer?.identity.frameID,
            enqueuedFrameCount: enqueuedFrameCount,
            replacedPendingFrameCount: replacedPendingFrameCount,
            rejectedFrameCount: rejectedFrameCount,
            formatFlushCount: formatFlushCount,
            discontinuityFlushCount: discontinuityFlushCount,
            failureRecoveryCount: failureRecoveryCount,
            readinessRequestCount: readinessRequestCount,
            readinessStopCount: readinessStopCount,
            isInvalidated: isInvalidated
        )
    }

    func invalidate() {
        guard !isInvalidated else { return }
        client.setRendererStateChangeHandler(nil)
        stopReadinessRequest()
        pendingSampleBuffer = nil
        activeFrameContract = nil
        isInvalidated = true
        phase = .invalidated
        client.invalidate()
    }

    private func rendererStateDidChange() {
        guard !isInvalidated,
              client.status == .failed
                || client.requiresFlushToResumeDecoding else {
            return
        }
        recoverRendererFailure()
    }

    private func ensureRendererIsUsable() -> Bool {
        if client.status == .failed
            || client.requiresFlushToResumeDecoding {
            recoverRendererFailure()
        }
        guard client.status != .failed,
              !client.requiresFlushToResumeDecoding else {
            phase = .failed(.frameSinkFailed)
            return false
        }
        return true
    }

    private func recoverRendererFailure() {
        stopReadinessRequest()
        pendingSampleBuffer = nil
        activeFrameContract = nil
        client.flush(removingDisplayedImage: true)
        increment(&failureRecoveryCount)
        if client.status == .failed
            || client.requiresFlushToResumeDecoding {
            phase = .failed(.frameSinkFailed)
        } else {
            phase = .ready
        }
    }

    private func requestReadinessIfNeeded() {
        guard pendingSampleBuffer != nil,
              readinessRequestOrdinal == nil else {
            return
        }
        guard nextReadinessRequestOrdinal < .max else {
            pendingSampleBuffer = nil
            activeFrameContract = nil
            phase = .failed(.frameSinkFailed)
            return
        }
        nextReadinessRequestOrdinal += 1
        let ordinal = nextReadinessRequestOrdinal
        readinessRequestOrdinal = ordinal
        increment(&readinessRequestCount)
        client.requestMediaDataWhenReady { [weak self] in
            self?.readinessDidChange(requestOrdinal: ordinal)
        }
    }

    private func readinessDidChange(requestOrdinal: UInt64) {
        guard !isInvalidated,
              readinessRequestOrdinal == requestOrdinal else {
            return
        }
        stopReadinessRequest()
        guard ensureRendererIsUsable(),
              let pendingSampleBuffer else {
            return
        }
        guard client.isReadyForMoreMediaData else {
            phase = .backpressured
            requestReadinessIfNeeded()
            return
        }
        self.pendingSampleBuffer = nil
        client.enqueue(pendingSampleBuffer)
        increment(&enqueuedFrameCount)
        if client.status == .failed
            || client.requiresFlushToResumeDecoding {
            recoverRendererFailure()
        } else {
            phase = .ready
        }
    }

    private func stopReadinessRequest() {
        guard readinessRequestOrdinal != nil else { return }
        readinessRequestOrdinal = nil
        client.stopRequestingMediaData()
        increment(&readinessStopCount)
    }

    private func reject(
        _ reason: MobilePictureInPictureDisplayLayerRejectionReason
    ) -> MobilePictureInPictureDisplayLayerSubmissionOutcome {
        increment(&rejectedFrameCount)
        return .rejected(reason)
    }

    private func increment(_ value: inout UInt64) {
        if value < .max {
            value += 1
        }
    }
}

extension MobilePictureInPictureDisplayLayerSink:
    MobilePictureInPictureFramePresentationSink
{
    func currentFrameSinkSnapshot()
        -> MobilePictureInPictureFrameSinkSnapshot
    {
        snapshot().frameSink
    }

    func flushForPictureInPictureLifecycle() -> Bool {
        signalDiscontinuity(generation: generation)
    }
}
