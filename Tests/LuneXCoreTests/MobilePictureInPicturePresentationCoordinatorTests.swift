@preconcurrency import CoreMedia
@preconcurrency import CoreVideo
import XCTest

final class MobilePictureInPicturePresentationCoordinatorTests:
    XCTestCase
{
    @MainActor
    func testSubmitsTheSameDecodedPixelBufferUsedByForegroundMetal()
        async throws
    {
        let context = try makeContext()
        let runtime = try makeRuntime(context)
        let frame = try makeFrame(
            generation: context.decoderGeneration,
            frameID: 41
        )

        _ = context.source.consume(
            .frame(frame),
            sessionID: context.sessionID,
            mediaGeneration: context.generation.mediaGeneration
        )
        try await waitUntil {
            runtime.snapshot().submittedFrameCount == 1
        }

        let foregroundFrame = try XCTUnwrap(
            context.source.currentFrame()
        )
        let sample = try XCTUnwrap(context.sink.samples.first)
        XCTAssertTrue(foregroundFrame.pixelBuffer === frame.pixelBuffer)
        XCTAssertTrue(
            CMSampleBufferGetImageBuffer(sample.sampleBuffer)
                === frame.pixelBuffer
        )
        XCTAssertEqual(sample.identity.frameID, frame.frameID)
        XCTAssertEqual(context.source.snapshot().activeSubscriptionCount, 1)
        XCTAssertEqual(context.sink.submissionCount, 1)

        _ = runtime.invalidate()
        XCTAssertEqual(context.source.snapshot().activeSubscriptionCount, 0)
    }

    @MainActor
    func testSubscriptionReplaysTheLatestCurrentGenerationFrame()
        async throws
    {
        let context = try makeContext()
        let frame = try makeFrame(
            generation: context.decoderGeneration,
            frameID: 7
        )
        _ = context.source.consume(
            .frame(frame),
            sessionID: context.sessionID,
            mediaGeneration: context.generation.mediaGeneration
        )

        let runtime = try makeRuntime(context)
        try await waitUntil {
            runtime.snapshot().submittedFrameCount == 1
        }

        XCTAssertEqual(context.sink.samples.map(\.identity.frameID), [7])
        XCTAssertTrue(
            CMSampleBufferGetImageBuffer(
                try XCTUnwrap(context.sink.samples.first).sampleBuffer
            ) === frame.pixelBuffer
        )
        _ = runtime.invalidate()
    }

    @MainActor
    func testMailboxRetainsOnlyLatestPendingDelivery()
        async throws
    {
        let context = try makeContext()
        let runtime = try makeRuntime(context)

        for frameID in 1...20 {
            _ = context.source.consume(
                .frame(try makeFrame(
                    generation: context.decoderGeneration,
                    frameID: UInt64(frameID)
                )),
                sessionID: context.sessionID,
                mediaGeneration: context.generation.mediaGeneration
            )
        }
        try await waitUntil {
            runtime.snapshot().lastFrameID == 20
        }

        let snapshot = runtime.snapshot()
        XCTAssertEqual(snapshot.submittedFrameCount, 1)
        XCTAssertEqual(snapshot.mailboxCoalescedDeliveryCount, 19)
        XCTAssertEqual(context.sink.samples.map(\.identity.frameID), [20])
        XCTAssertEqual(context.source.currentFrame()?.frameID, 20)
        _ = runtime.invalidate()
    }

    @MainActor
    func testClearFlushesPiPAndRejectsLateOldDecoderFrame()
        async throws
    {
        let context = try makeContext()
        let runtime = try makeRuntime(context)
        _ = context.source.consume(
            .frame(try makeFrame(
                generation: context.decoderGeneration,
                frameID: 1
            )),
            sessionID: context.sessionID,
            mediaGeneration: context.generation.mediaGeneration
        )
        try await waitUntil {
            runtime.snapshot().submittedFrameCount == 1
        }

        _ = context.source.discardFrames(
            sessionID: context.sessionID,
            mediaGeneration: context.generation.mediaGeneration
        )
        try await waitUntil {
            runtime.snapshot().discontinuityCount == 1
        }
        _ = context.source.consume(
            .frame(try makeFrame(
                generation: context.decoderGeneration,
                frameID: 2
            )),
            sessionID: context.sessionID,
            mediaGeneration: context.generation.mediaGeneration
        )
        await Task.yield()

        XCTAssertEqual(context.sink.submissionCount, 1)
        XCTAssertEqual(context.sink.discontinuityCount, 1)
        XCTAssertNil(runtime.snapshot().lastFrameID)
        XCTAssertNil(context.source.currentFrame())
        _ = runtime.invalidate()
    }

    @MainActor
    func testFormatAndColorChangesReplaceOnlyTheSampleAdapter()
        async throws
    {
        let context = try makeContext()
        let runtime = try makeRuntime(context)
        _ = context.source.consume(
            .frame(try makeFrame(
                generation: context.decoderGeneration,
                frameID: 1,
                width: 64,
                metadata: .rec709VideoRange()
            )),
            sessionID: context.sessionID,
            mediaGeneration: context.generation.mediaGeneration
        )
        try await waitUntil {
            runtime.snapshot().submittedFrameCount == 1
        }
        _ = context.source.consume(
            .frame(try makeFrame(
                generation: context.decoderGeneration,
                frameID: 2,
                width: 80,
                metadata: .rec709VideoRange()
            )),
            sessionID: context.sessionID,
            mediaGeneration: context.generation.mediaGeneration
        )
        try await waitUntil {
            runtime.snapshot().submittedFrameCount == 2
        }
        _ = context.source.consume(
            .frame(try makeFrame(
                generation: context.decoderGeneration,
                frameID: 3,
                width: 80,
                metadata: .hdr10VideoRange()
            )),
            sessionID: context.sessionID,
            mediaGeneration: context.generation.mediaGeneration
        )
        try await waitUntil {
            runtime.snapshot().submittedFrameCount == 3
        }

        XCTAssertEqual(
            runtime.snapshot().sampleBufferAdapterReplacementCount,
            2
        )
        XCTAssertEqual(
            context.sink.samples.map(\.identity.frameID),
            [1, 2, 3]
        )
        XCTAssertEqual(context.sink.decoderGeneration, 9)
        _ = runtime.invalidate()
    }

    @MainActor
    func testForegroundPolicyChangesOnlyAfterConfirmedNativeStart()
        throws
    {
        let context = try makeContext(startEvents: [.willStart])
        var policies: [RenderPolicy] = []
        let runtime = try makeRuntime(
            context,
            foregroundBaseline: .active,
            foregroundPolicyHandler: { policies.append($0) }
        )
        _ = runtime.prepare()
        _ = runtime.requestStart()

        XCTAssertEqual(runtime.snapshot().foregroundPolicy, .active)
        XCTAssertFalse(runtime.snapshot().isConfirmedActive)
        context.client.emit(.didStart)
        XCTAssertEqual(
            runtime.snapshot().foregroundPolicy,
            .paused(
                reason: MobilePictureInPicturePresentationCoordinator
                    .foregroundSuppressionReason
            )
        )
        runtime.updateForegroundBaseline(
            .throttled(reason: "Scene inactive")
        )
        XCTAssertTrue(runtime.snapshot().isConfirmedActive)
        context.client.emit(.willStop)
        XCTAssertTrue(runtime.snapshot().isConfirmedActive)
        context.client.emit(.didStop)

        XCTAssertEqual(
            runtime.snapshot().foregroundPolicy,
            .throttled(reason: "Scene inactive")
        )
        XCTAssertEqual(
            policies,
            [
                .active,
                .paused(
                    reason: MobilePictureInPicturePresentationCoordinator
                        .foregroundSuppressionReason
                ),
                .throttled(reason: "Scene inactive")
            ]
        )
        _ = runtime.invalidate()
    }

    @MainActor
    func testThrottledSuppressionAndInvalidationRestoreLatestBaseline()
        throws
    {
        let context = try makeContext(startEvents: [.willStart])
        var policies: [RenderPolicy] = []
        let runtime = try makeRuntime(
            context,
            foregroundBaseline: .active,
            foregroundSuppression: .throttled,
            foregroundPolicyHandler: { policies.append($0) }
        )
        _ = runtime.prepare()
        _ = runtime.requestStart()
        context.client.emit(.didStart)
        runtime.updateForegroundBaseline(
            .paused(reason: "Scene background")
        )
        context.client.emit(.invalidated)

        XCTAssertEqual(
            policies.prefix(2),
            [
                .active,
                .throttled(
                    reason: MobilePictureInPicturePresentationCoordinator
                        .foregroundSuppressionReason
                )
            ]
        )
        XCTAssertEqual(
            runtime.snapshot().foregroundPolicy,
            .paused(reason: "Scene background")
        )
        _ = runtime.invalidate()
    }

    @MainActor
    func testStartFailureNeverSuppressesForegroundPresentation()
        throws
    {
        let context = try makeContext(startEvents: [.willStart])
        var policies: [RenderPolicy] = []
        let runtime = try makeRuntime(
            context,
            foregroundBaseline: .active,
            foregroundPolicyHandler: { policies.append($0) }
        )
        _ = runtime.prepare()
        _ = runtime.requestStart()
        context.client.emit(.startFailed(.nativeStartFailed))

        XCTAssertEqual(
            runtime.lifecycleCoordinator.snapshot?.state.lifecycle,
            .failed
        )
        XCTAssertFalse(runtime.snapshot().isConfirmedActive)
        XCTAssertEqual(runtime.snapshot().foregroundPolicy, .active)
        XCTAssertEqual(policies, [.active])
        XCTAssertEqual(context.sink.discontinuityCount, 1)
        _ = runtime.invalidate()
    }

    @MainActor
    func testPlaybackRestoreAndSkipTraversePresentationOwnershipExactlyOnce()
        throws
    {
        let context = try makeContext(startEvents: [.willStart])
        let runtime = try makeRuntime(context)
        var events: [MobilePictureInPictureLifecycleCoordinatorEvent] = []
        runtime.setLifecycleEventHandler { events.append($0) }
        _ = runtime.prepare()
        _ = runtime.requestStart()
        context.client.emit(.didStart)

        let playback = try XCTUnwrap(
            MobilePictureInPicturePlaybackState(
                timeline: .live,
                isPaused: false,
                backgroundAudioPolicy: .permitted
            )
        )
        XCTAssertTrue(runtime.updatePlaybackState(playback))
        XCTAssertFalse(runtime.updatePlaybackState(playback))

        let nativeRestorationLease = try callbackLease(
            generation: context.generation,
            kind: .restoreInterface,
            ordinal: 11
        )
        context.client.emit(
            .restoreInterfaceRequested(nativeRestorationLease)
        )
        let runtimeRestorationLease = try XCTUnwrap(
            events.compactMap {
                (event)
                    -> MobilePictureInPictureRestorationLease? in
                guard case let .restoreInterfaceRequested(lease) = event else {
                    return nil
                }
                return lease
            }.last
        )
        guard case .applied = runtime.completeRestoration(
            runtimeRestorationLease,
            result: .restored
        ) else {
            return XCTFail("Expected restoration completion")
        }
        XCTAssertEqual(
            runtime.completeRestoration(
                runtimeRestorationLease,
                result: .declined
            ),
            .rejected(.staleRestorationLease)
        )

        let interval = try XCTUnwrap(
            MobilePictureInPictureSkipInterval(
                nanoseconds: 2_000_000_000
            )
        )
        let nativeSkipLease = try callbackLease(
            generation: context.generation,
            kind: .skip,
            ordinal: 12
        )
        let renderSize = try XCTUnwrap(
            MobilePictureInPictureRenderSize(
                width: 1_920,
                height: 1_080
            )
        )
        context.client.emit(.setPlaying(false))
        context.client.emit(.skipRequested(
            interval: interval,
            completion: nativeSkipLease
        ))
        context.client.emit(.renderSizeChanged(renderSize))

        XCTAssertTrue(events.contains(.setPlayingRequested(false)))
        XCTAssertTrue(events.contains(.skipRequested(
            interval: interval,
            completion: nativeSkipLease
        )))
        XCTAssertTrue(events.contains(.renderSizeChanged(renderSize)))
        XCTAssertEqual(runtime.completeSkip(nativeSkipLease), .completed)
        XCTAssertEqual(
            runtime.completeSkip(nativeSkipLease),
            .alreadyCompleted
        )
        XCTAssertEqual(
            context.client.commands,
            [
                .start,
                .playback(playback),
                .invalidatePlaybackState
            ]
        )
        XCTAssertEqual(
            context.client.completions,
            [
                .init(
                    lease: nativeRestorationLease,
                    completion: .restoreInterface(restored: true)
                ),
                .init(
                    lease: nativeSkipLease,
                    completion: .skip
                )
            ]
        )
        _ = runtime.invalidate()
    }

    @MainActor
    func testBackpressureAndRejectionOutcomesRemainBounded()
        async throws
    {
        let context = try makeContext()
        let runtime = try makeRuntime(context)
        context.sink.submissionOutcome = .retainedLatestPending
        _ = context.source.consume(
            .frame(try makeFrame(
                generation: context.decoderGeneration,
                frameID: 1
            )),
            sessionID: context.sessionID,
            mediaGeneration: context.generation.mediaGeneration
        )
        try await waitUntil {
            runtime.snapshot().submittedFrameCount == 1
        }

        context.sink.submissionOutcome = .replacedPending
        _ = context.source.consume(
            .frame(try makeFrame(
                generation: context.decoderGeneration,
                frameID: 2
            )),
            sessionID: context.sessionID,
            mediaGeneration: context.generation.mediaGeneration
        )
        try await waitUntil {
            runtime.snapshot().submittedFrameCount == 2
        }

        context.sink.submissionOutcome = .rejected(.rendererFailed)
        _ = context.source.consume(
            .frame(try makeFrame(
                generation: context.decoderGeneration,
                frameID: 3
            )),
            sessionID: context.sessionID,
            mediaGeneration: context.generation.mediaGeneration
        )
        try await waitUntil {
            runtime.snapshot().rejectedFrameCount == 1
        }

        XCTAssertEqual(runtime.snapshot().submittedFrameCount, 2)
        XCTAssertEqual(
            context.sink.samples.map(\.identity.frameID),
            [1, 2]
        )
        XCTAssertEqual(context.source.currentFrame()?.frameID, 3)
        _ = runtime.invalidate()
    }

    @MainActor
    func testReplacementReleasesPendingFrameAndRejectsStaleCallback()
        async throws
    {
        let source = StreamVideoPresentationSource()
        let sessionID = UUID()
        let oldContext = try makeContext(
            source: source,
            sessionID: sessionID,
            mediaGeneration: 3,
            pictureInPictureGeneration: 5,
            decoderGeneration: 9
        )
        var oldRuntime:
            MobilePictureInPicturePresentationCoordinator? =
                try makeRuntime(oldContext)
        weak let releasedRuntime = oldRuntime
        let staleHandler = try XCTUnwrap(
            oldContext.client.currentHandler
        )
        weak var releasedPixelBuffer: CVPixelBuffer?
        autoreleasepool {
            let frame = try! makeFrame(
                generation: oldContext.decoderGeneration,
                frameID: 1
            )
            releasedPixelBuffer = frame.pixelBuffer
            _ = source.consume(
                .frame(frame),
                sessionID: sessionID,
                mediaGeneration: oldContext.generation.mediaGeneration
            )
        }
        _ = oldRuntime?.invalidate()
        oldRuntime = nil

        let newContext = try makeContext(
            source: source,
            sessionID: sessionID,
            mediaGeneration: 4,
            pictureInPictureGeneration: 6,
            decoderGeneration: 10
        )
        let newRuntime = try makeRuntime(newContext)
        staleHandler(try XCTUnwrap(
            MobilePictureInPictureClientEventEnvelope(
                generation: oldContext.generation,
                event: .didStart
            )
        ))
        _ = source.consume(
            .frame(try makeFrame(
                generation: newContext.decoderGeneration,
                frameID: 2
            )),
            sessionID: sessionID,
            mediaGeneration: newContext.generation.mediaGeneration
        )
        try await waitUntil {
            newRuntime.snapshot().submittedFrameCount == 1
        }
        await Task.yield()

        XCTAssertNil(releasedRuntime)
        XCTAssertNil(releasedPixelBuffer)
        XCTAssertEqual(oldContext.sink.submissionCount, 0)
        XCTAssertEqual(newContext.sink.samples.map(\.identity.frameID), [2])
        XCTAssertFalse(newRuntime.snapshot().isConfirmedActive)
        XCTAssertEqual(
            source.snapshot().activeSubscriptionCount,
            1
        )
        _ = newRuntime.invalidate()
    }

    func testSourceSubscriptionCapacityCancellationAndRevisionExhaustion()
        throws
    {
        let source = StreamVideoPresentationSource()
        let sessionID = UUID()
        let subscriptions = (0..<StreamVideoPresentationSource
            .maximumSubscriptionCount).map { _ in
            source.subscribe(
                sessionID: sessionID,
                mediaGeneration: 1,
                handler: { _ in }
            )
        }
        XCTAssertTrue(subscriptions.allSatisfy { $0 != nil })
        XCTAssertEqual(
            source.snapshot().activeSubscriptionCount,
            StreamVideoPresentationSource.maximumSubscriptionCount
        )
        XCTAssertNil(source.subscribe(
            sessionID: sessionID,
            mediaGeneration: 1,
            handler: { _ in }
        ))
        subscriptions[0]?.cancel()
        XCTAssertEqual(
            source.snapshot().activeSubscriptionCount,
            StreamVideoPresentationSource.maximumSubscriptionCount - 1
        )

        let exhausted = StreamVideoPresentationSource(
            initialDeliveryRevision: .max
        )
        let exhaustedSubscription = try XCTUnwrap(exhausted.subscribe(
            sessionID: sessionID,
            mediaGeneration: 1,
            handler: { _ in }
        ))
        XCTAssertNil(exhausted.beginSession(
            sessionID: sessionID,
            mediaGeneration: 1
        ))
        XCTAssertTrue(
            exhausted.snapshot().isDeliveryRevisionExhausted
        )
        XCTAssertEqual(exhausted.snapshot().activeSubscriptionCount, 0)
        exhaustedSubscription.cancel()
    }

    func testPresentationRevisionExhaustionClearsAndReleasesSubscribers()
        throws
    {
        let source = StreamVideoPresentationSource(
            initialPresentationRevision: .max - 3
        )
        let sessionID = UUID()
        let mediaGeneration: UInt64 = 1
        let decoderGeneration: UInt64 = 4
        XCTAssertNotNil(source.beginSession(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        ))
        XCTAssertNotNil(source.consume(
            .sessionStarted(
                generation: decoderGeneration,
                colorMetadata: .rec709VideoRange()
            ),
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        ))
        let recorder = PresentationDeliveryRecorder()
        let subscription = try XCTUnwrap(source.subscribe(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            handler: { delivery in
                _ = source.snapshot()
                recorder.record(delivery)
            }
        ))
        XCTAssertNotNil(source.consume(
            .frame(try makeFrame(
                generation: decoderGeneration,
                frameID: 1
            )),
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        ))

        XCTAssertNil(source.discardFrames(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        ))

        let deliveries = recorder.deliveries
        XCTAssertEqual(deliveries.count, 2)
        guard case let .decodedFrame(_, frame) = deliveries.first else {
            return XCTFail("Expected decoded frame before exhaustion")
        }
        XCTAssertEqual(frame.frameID, 1)
        guard case let .cleared(ownership, generation) = deliveries.last else {
            return XCTFail("Expected terminal clear after exhaustion")
        }
        XCTAssertEqual(ownership.revision, 4)
        XCTAssertEqual(generation, decoderGeneration)
        let snapshot = source.snapshot()
        XCTAssertTrue(snapshot.isPresentationRevisionExhausted)
        XCTAssertNil(snapshot.latestFrameID)
        XCTAssertEqual(snapshot.activeSubscriptionCount, 0)
        XCTAssertNil(source.subscribe(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            handler: { _ in }
        ))
        subscription.cancel()
    }

    @MainActor
    func testReplacementAndInvalidationCancelDeliveryOwnership()
        async throws
    {
        let context = try makeContext()
        let runtime = try makeRuntime(context)
        _ = context.source.consume(
            .frame(try makeFrame(
                generation: context.decoderGeneration,
                frameID: 1
            )),
            sessionID: context.sessionID,
            mediaGeneration: context.generation.mediaGeneration
        )
        let outcome = runtime.invalidate()
        guard case let .applied(snapshot) = outcome else {
            return XCTFail("Expected terminal invalidation snapshot")
        }
        XCTAssertEqual(snapshot.state.lifecycle, .invalidated)
        await Task.yield()

        XCTAssertTrue(runtime.snapshot().isInvalidated)
        XCTAssertEqual(runtime.snapshot().submittedFrameCount, 0)
        XCTAssertEqual(context.source.snapshot().activeSubscriptionCount, 0)
        XCTAssertEqual(context.sink.invalidateCount, 1)
        XCTAssertEqual(context.client.invalidateCount, 1)
    }

    @MainActor
    private func makeContext(
        startEvents: [MobilePictureInPictureClientEvent] = [],
        source: StreamVideoPresentationSource =
            StreamVideoPresentationSource(),
        sessionID: UUID = UUID(),
        mediaGeneration: UInt64 = 3,
        pictureInPictureGeneration: UInt64 = 5,
        decoderGeneration: UInt64 = 9
    ) throws -> PresentationTestContext {
        let generation = try XCTUnwrap(
            MobilePictureInPictureGeneration(
                mediaGeneration: mediaGeneration,
                pictureInPictureGeneration: pictureInPictureGeneration
            )
        )
        _ = source.beginSession(
            sessionID: sessionID,
            mediaGeneration: generation.mediaGeneration
        )
        _ = source.consume(
            .sessionStarted(
                generation: decoderGeneration,
                colorMetadata: .rec709VideoRange()
            ),
            sessionID: sessionID,
            mediaGeneration: generation.mediaGeneration
        )
        let client = RecordingPresentationControllerClient(
            generation: generation,
            startEvents: startEvents
        )
        let sink = RecordingPresentationFrameSink(
            generation: generation,
            decoderGeneration: decoderGeneration
        )
        return PresentationTestContext(
            source: source,
            sessionID: sessionID,
            generation: generation,
            decoderGeneration: decoderGeneration,
            client: client,
            sink: sink
        )
    }

    @MainActor
    private func makeRuntime(
        _ context: PresentationTestContext,
        foregroundBaseline: RenderPolicy = .active,
        foregroundSuppression:
            MobilePictureInPictureForegroundSuppression = .paused,
        foregroundPolicyHandler:
            @escaping @MainActor (RenderPolicy) -> Void = { _ in }
    ) throws -> MobilePictureInPicturePresentationCoordinator {
        try MobilePictureInPicturePresentationCoordinator(
            sessionID: context.sessionID,
            generation: context.generation,
            decoderGeneration: context.decoderGeneration,
            source: context.source,
            client: context.client,
            frameSink: context.sink,
            foregroundBaseline: foregroundBaseline,
            foregroundSuppression: foregroundSuppression,
            foregroundPolicyHandler: foregroundPolicyHandler
        )
    }

    private func makeFrame(
        generation: UInt64,
        frameID: UInt64,
        width: Int = 64,
        height: Int = 48,
        metadata: VideoColorMetadata = .rec709VideoRange()
    ) throws -> DecodedVideoFrame {
        let pixelFormat = metadata.transferFunction == .smpteST2084PQ
            ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormat,
            [
                kCVPixelBufferIOSurfacePropertiesKey:
                    [:] as CFDictionary,
                kCVPixelBufferMetalCompatibilityKey: true
            ] as CFDictionary,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        return DecodedVideoFrame(
            generation: generation,
            frameID: frameID,
            pixelBuffer: try XCTUnwrap(pixelBuffer),
            presentationTimeStamp: CMTime(
                value: Int64(frameID),
                timescale: 60
            ),
            duration: CMTime(value: 1, timescale: 60),
            infoFlags: [],
            colorMetadata: metadata
        )
    }

    private func callbackLease(
        generation: MobilePictureInPictureGeneration,
        kind: MobilePictureInPictureClientCallbackKind,
        ordinal: UInt64
    ) throws -> MobilePictureInPictureClientCallbackLease {
        try XCTUnwrap(MobilePictureInPictureClientCallbackLease(
            generation: generation,
            kind: kind,
            ordinal: ordinal
        ))
    }

    @MainActor
    private func waitUntil(
        _ condition: @MainActor () -> Bool
    ) async throws {
        for _ in 0..<100 {
            if condition() {
                return
            }
            await Task.yield()
        }
        XCTFail("Timed out waiting for presentation delivery")
    }
}

@MainActor
private struct PresentationTestContext {
    let source: StreamVideoPresentationSource
    let sessionID: UUID
    let generation: MobilePictureInPictureGeneration
    let decoderGeneration: UInt64
    let client: RecordingPresentationControllerClient
    let sink: RecordingPresentationFrameSink
}

private final class PresentationDeliveryRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var recordedDeliveries: [StreamVideoPresentationDelivery] = []

    var deliveries: [StreamVideoPresentationDelivery] {
        lock.withLock { recordedDeliveries }
    }

    func record(_ delivery: StreamVideoPresentationDelivery) {
        lock.withLock {
            recordedDeliveries.append(delivery)
        }
    }
}

@MainActor
private final class RecordingPresentationFrameSink:
    MobilePictureInPictureFramePresentationSink
{
    let generation: MobilePictureInPictureGeneration
    let decoderGeneration: UInt64
    var submissionOutcome:
        MobilePictureInPictureDisplayLayerSubmissionOutcome = .enqueued
    private(set) var samples: [MobilePictureInPictureSampleBuffer] = []
    private(set) var discontinuityCount = 0
    private(set) var invalidateCount = 0
    private var isInvalidated = false

    var submissionCount: Int {
        samples.count
    }

    init(
        generation: MobilePictureInPictureGeneration,
        decoderGeneration: UInt64
    ) {
        self.generation = generation
        self.decoderGeneration = decoderGeneration
    }

    func currentFrameSinkSnapshot()
        -> MobilePictureInPictureFrameSinkSnapshot
    {
        guard !isInvalidated else { return .invalidated }
        return MobilePictureInPictureFrameSinkSnapshot.ready(
            decoderGeneration: decoderGeneration
        )!
    }

    func submit(
        _ sampleBuffer: MobilePictureInPictureSampleBuffer
    ) -> MobilePictureInPictureDisplayLayerSubmissionOutcome {
        guard !isInvalidated else {
            return .rejected(.invalidated)
        }
        if case .rejected = submissionOutcome {
            return submissionOutcome
        }
        samples.append(sampleBuffer)
        return submissionOutcome
    }

    func signalDiscontinuity(
        generation requestedGeneration:
            MobilePictureInPictureGeneration
    ) -> Bool {
        guard !isInvalidated,
              requestedGeneration == generation else {
            return false
        }
        discontinuityCount += 1
        return true
    }

    func flushForPictureInPictureLifecycle() -> Bool {
        signalDiscontinuity(generation: generation)
    }

    func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        samples.removeAll(keepingCapacity: false)
        invalidateCount += 1
    }
}

@MainActor
private final class RecordingPresentationControllerClient:
    MobilePictureInPictureControllerClient
{
    enum Command: Equatable {
        case start
        case stop
        case playback(MobilePictureInPicturePlaybackState)
        case invalidatePlaybackState
    }

    struct Completion: Equatable {
        let lease: MobilePictureInPictureClientCallbackLease
        let completion: MobilePictureInPictureClientCallbackCompletion
    }

    let generation: MobilePictureInPictureGeneration
    private(set) var preparationSnapshot:
        MobilePictureInPictureClientPreparationSnapshot?
    private(set) var commands: [Command] = []
    private(set) var completions: [Completion] = []
    private(set) var invalidateCount = 0
    private(set) var currentHandler:
        MobilePictureInPictureClientEventHandler?
    private var completedLeases:
        Set<MobilePictureInPictureClientCallbackLease> = []
    private let startEvents: [MobilePictureInPictureClientEvent]
    private var isInvalidated = false

    init(
        generation: MobilePictureInPictureGeneration,
        startEvents: [MobilePictureInPictureClientEvent]
    ) {
        self.generation = generation
        self.startEvents = startEvents
        preparationSnapshot =
            MobilePictureInPictureClientPreparationSnapshot(
                generation: generation,
                components: .ready,
                capability: .possible
            )!
    }

    func setEventHandler(
        _ handler: MobilePictureInPictureClientEventHandler?
    ) {
        currentHandler = handler
    }

    func prepare() {}

    func requestStart() {
        commands.append(.start)
        for event in startEvents {
            emit(event)
        }
    }

    func requestStop() {
        commands.append(.stop)
    }

    func updatePlaybackState(
        _ state: MobilePictureInPicturePlaybackState
    ) {
        commands.append(.playback(state))
    }

    func invalidatePlaybackState() {
        commands.append(.invalidatePlaybackState)
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
        guard completedLeases.insert(lease).inserted else {
            return .alreadyCompleted
        }
        completions.append(.init(
            lease: lease,
            completion: completion
        ))
        return .completed
    }

    func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        invalidateCount += 1
        currentHandler = nil
        preparationSnapshot = nil
    }

    func emit(_ event: MobilePictureInPictureClientEvent) {
        guard !isInvalidated,
              let envelope = MobilePictureInPictureClientEventEnvelope(
                generation: generation,
                event: event
              ) else {
            return
        }
        currentHandler?(envelope)
    }
}
