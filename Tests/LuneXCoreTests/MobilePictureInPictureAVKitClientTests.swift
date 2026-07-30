@preconcurrency import AVFoundation
@preconcurrency import AVKit
@preconcurrency import CoreMedia
import XCTest

final class MobilePictureInPictureAVKitClientTests: XCTestCase {
    @MainActor
    func testUnavailableFactoryPublishesTypedPreparation() throws {
        let generation = try XCTUnwrap(makeGeneration())
        let factory = RecordingPictureInPictureNativeFactory(
            preparation: .unavailable(.platformUnsupported)
        )
        let client = MobilePictureInPictureAVKitControllerClient(
            generation: generation,
            displayLayer: AVSampleBufferDisplayLayer(),
            factory: factory
        )
        var events: [MobilePictureInPictureClientEventEnvelope] = []
        client.setEventHandler { events.append($0) }

        client.prepare()
        client.prepare()
        client.requestStart()

        let snapshot = try XCTUnwrap(client.preparationSnapshot)
        XCTAssertEqual(snapshot.components, .unprepared)
        XCTAssertEqual(
            snapshot.capability,
            .unavailable(.platformUnsupported)
        )
        XCTAssertEqual(events.map(\.event), [.prepared(snapshot)])
        XCTAssertEqual(factory.makeCount, 1)
    }

    @MainActor
    func testPreparationAndPossibilityUseActualNativeState()
        throws
    {
        let generation = try XCTUnwrap(makeGeneration())
        let bridge = RecordingPictureInPictureNativeBridge(
            isPossible: false
        )
        let factory = RecordingPictureInPictureNativeFactory(
            preparation: .prepared(bridge)
        )
        let client = MobilePictureInPictureAVKitControllerClient(
            generation: generation,
            displayLayer: AVSampleBufferDisplayLayer(),
            factory: factory
        )
        var events: [MobilePictureInPictureClientEventEnvelope] = []
        client.setEventHandler { events.append($0) }

        client.prepare()
        let initial = try XCTUnwrap(client.preparationSnapshot)
        XCTAssertEqual(initial.components, .ready)
        XCTAssertEqual(initial.capability, .unavailable(.notPossible))

        bridge.emit(.possibilityChanged(true))
        bridge.emit(.possibilityChanged(true))
        bridge.emit(.possibilityChanged(false))

        XCTAssertEqual(
            events.map(\.event),
            [
                .prepared(initial),
                .capabilityChanged(.possible),
                .capabilityChanged(.unavailable(.notPossible))
            ]
        )
        XCTAssertEqual(
            client.preparationSnapshot?.capability,
            .unavailable(.notPossible)
        )
    }

    @MainActor
    func testCommandsAndNativeLifecycleMapWithoutRawError()
        throws
    {
        let generation = try XCTUnwrap(makeGeneration())
        let bridge = RecordingPictureInPictureNativeBridge(
            isPossible: true
        )
        let client = MobilePictureInPictureAVKitControllerClient(
            generation: generation,
            displayLayer: AVSampleBufferDisplayLayer(),
            factory: RecordingPictureInPictureNativeFactory(
                preparation: .prepared(bridge)
            )
        )
        var events: [MobilePictureInPictureClientEventEnvelope] = []
        client.setEventHandler { events.append($0) }
        client.prepare()
        events.removeAll()

        let playbackState = try XCTUnwrap(
            MobilePictureInPicturePlaybackState(
                timeline: .live,
                isPaused: false,
                backgroundAudioPolicy: .permitted
            )
        )
        client.requestStart()
        client.requestStop()
        client.updatePlaybackState(playbackState)
        client.invalidatePlaybackState()
        bridge.emit(.willStart)
        bridge.emit(.didStart)
        bridge.emit(.startFailed)
        bridge.emit(.willStop)
        bridge.emit(.didStop)
        bridge.emit(.setPlaying(false))
        bridge.emit(.renderSizeChanged(try XCTUnwrap(
            MobilePictureInPictureRenderSize(width: 960, height: 540)
        )))

        XCTAssertEqual(
            bridge.commands,
            [
                .start,
                .stop,
                .updatePlaybackState(playbackState),
                .invalidatePlaybackState
            ]
        )
        XCTAssertEqual(
            events.map(\.event),
            [
                .willStart,
                .didStart,
                .startFailed(.nativeStartFailed),
                .willStop,
                .didStop,
                .setPlaying(false),
                .renderSizeChanged(try XCTUnwrap(
                    MobilePictureInPictureRenderSize(
                        width: 960,
                        height: 540
                    )
                ))
            ]
        )
    }

    @MainActor
    func testRestoreAndSkipCallbacksCompleteExactlyOnce()
        throws
    {
        let generation = try XCTUnwrap(makeGeneration())
        let bridge = RecordingPictureInPictureNativeBridge(
            isPossible: true
        )
        let client = MobilePictureInPictureAVKitControllerClient(
            generation: generation,
            displayLayer: AVSampleBufferDisplayLayer(),
            factory: RecordingPictureInPictureNativeFactory(
                preparation: .prepared(bridge)
            )
        )
        let completion = ThreadSafePictureInPictureCompletionRecorder()
        var events: [MobilePictureInPictureClientEventEnvelope] = []
        client.setEventHandler { events.append($0) }
        client.prepare()
        events.removeAll()

        bridge.emit(.restoreInterfaceRequested {
            completion.recordRestoration($0)
        })
        bridge.emit(.skipRequested(
            try XCTUnwrap(MobilePictureInPictureSkipInterval(
                nanoseconds: 5_000_000_000
            )),
            {
                completion.recordSkip()
            }
        ))

        let restorationLease = try restorationLease(from: events)
        let skipLease = try skipLease(from: events)
        XCTAssertEqual(
            client.completeCallback(
                restorationLease,
                with: .restoreInterface(restored: true)
            ),
            .completed
        )
        XCTAssertEqual(
            client.completeCallback(
                restorationLease,
                with: .restoreInterface(restored: false)
            ),
            .alreadyCompleted
        )
        XCTAssertEqual(
            client.completeCallback(
                skipLease,
                with: .restoreInterface(restored: false)
            ),
            .kindMismatch
        )
        XCTAssertEqual(
            client.completeCallback(skipLease, with: .skip),
            .completed
        )
        XCTAssertEqual(completion.restorationResults, [true])
        XCTAssertEqual(completion.skipCount, 1)
    }

    @MainActor
    func testConcurrentCallbacksAndOrdinalExhaustionFailClosed()
        throws
    {
        let generation = try XCTUnwrap(makeGeneration())
        let bridge = RecordingPictureInPictureNativeBridge(
            isPossible: true
        )
        let client = MobilePictureInPictureAVKitControllerClient(
            generation: generation,
            displayLayer: AVSampleBufferDisplayLayer(),
            factory: RecordingPictureInPictureNativeFactory(
                preparation: .prepared(bridge)
            ),
            initialCallbackOrdinal: .max - 1
        )
        let first = ThreadSafePictureInPictureCompletionRecorder()
        let duplicate = ThreadSafePictureInPictureCompletionRecorder()
        let exhausted = ThreadSafePictureInPictureCompletionRecorder()
        var events: [MobilePictureInPictureClientEventEnvelope] = []
        client.setEventHandler { events.append($0) }
        client.prepare()
        events.removeAll()

        bridge.emit(.restoreInterfaceRequested {
            first.recordRestoration($0)
        })
        bridge.emit(.restoreInterfaceRequested {
            duplicate.recordRestoration($0)
        })
        bridge.emit(.skipRequested(
            try XCTUnwrap(MobilePictureInPictureSkipInterval(
                nanoseconds: 1_000_000_000
            )),
            {
                exhausted.recordSkip()
            }
        ))

        XCTAssertEqual(duplicate.restorationResults, [false])
        XCTAssertEqual(exhausted.skipCount, 1)
        XCTAssertEqual(
            events.map(\.event),
            [
                .restoreInterfaceRequested(
                    try XCTUnwrap(MobilePictureInPictureClientCallbackLease(
                        generation: generation,
                        kind: .restoreInterface,
                        ordinal: .max
                    ))
                )
            ]
        )

        client.invalidate()
        XCTAssertEqual(first.restorationResults, [false])
    }

    @MainActor
    func testMissingOrRemovedConsumerCompletesNativeCallbacks()
        throws
    {
        let generation = try XCTUnwrap(makeGeneration())
        let bridge = RecordingPictureInPictureNativeBridge(
            isPossible: true
        )
        let client = MobilePictureInPictureAVKitControllerClient(
            generation: generation,
            displayLayer: AVSampleBufferDisplayLayer(),
            factory: RecordingPictureInPictureNativeFactory(
                preparation: .prepared(bridge)
            )
        )
        let withoutConsumer =
            ThreadSafePictureInPictureCompletionRecorder()
        client.prepare()

        bridge.emit(.restoreInterfaceRequested {
            withoutConsumer.recordRestoration($0)
        })
        bridge.emit(.skipRequested(
            try XCTUnwrap(MobilePictureInPictureSkipInterval(
                nanoseconds: 1_000_000_000
            )),
            {
                withoutConsumer.recordSkip()
            }
        ))
        XCTAssertEqual(
            withoutConsumer.restorationResults,
            [false]
        )
        XCTAssertEqual(withoutConsumer.skipCount, 1)

        let removedConsumer =
            ThreadSafePictureInPictureCompletionRecorder()
        var events: [MobilePictureInPictureClientEventEnvelope] = []
        client.setEventHandler { events.append($0) }
        bridge.emit(.restoreInterfaceRequested {
            removedConsumer.recordRestoration($0)
        })
        let lease = try restorationLease(from: events)

        client.setEventHandler(nil)

        XCTAssertEqual(
            removedConsumer.restorationResults,
            [false]
        )
        XCTAssertEqual(
            client.completeCallback(
                lease,
                with: .restoreInterface(restored: true)
            ),
            .alreadyCompleted
        )
    }

    @MainActor
    func testInvalidationCompletesCallbacksAndRejectsLateEvents()
        throws
    {
        let generation = try XCTUnwrap(makeGeneration())
        let bridge = RecordingPictureInPictureNativeBridge(
            isPossible: true
        )
        let client = MobilePictureInPictureAVKitControllerClient(
            generation: generation,
            displayLayer: AVSampleBufferDisplayLayer(),
            factory: RecordingPictureInPictureNativeFactory(
                preparation: .prepared(bridge)
            )
        )
        let completion = ThreadSafePictureInPictureCompletionRecorder()
        var events: [MobilePictureInPictureClientEventEnvelope] = []
        client.setEventHandler { events.append($0) }
        client.prepare()
        bridge.emit(.skipRequested(
            try XCTUnwrap(MobilePictureInPictureSkipInterval(
                nanoseconds: 1_000_000_000
            )),
            {
                completion.recordSkip()
            }
        ))
        let lease = try skipLease(from: events)
        let staleHandler = bridge.currentHandler

        client.invalidate()
        client.invalidate()
        staleHandler?(.didStart)

        XCTAssertEqual(completion.skipCount, 1)
        XCTAssertEqual(bridge.invalidateCount, 1)
        XCTAssertEqual(
            client.completeCallback(lease, with: .skip),
            .invalidated
        )
        XCTAssertEqual(events.last?.event, .invalidated)
        XCTAssertEqual(
            client.preparationSnapshot?.components,
            .invalidated
        )
        XCTAssertEqual(
            client.preparationSnapshot?.capability,
            .unavailable(.invalidated)
        )
        XCTAssertFalse(events.map(\.event).suffix(1).contains(.didStart))
    }

    @MainActor
    func testProductionFactoryReportsUnsupportedWithoutCreatingBridge()
        throws
    {
        let factory =
            MobilePictureInPictureAVKitNativeControllerFactory {
                false
            }

        switch factory.makeController(
            displayLayer: AVSampleBufferDisplayLayer()
        ) {
        case let .unavailable(reason):
            XCTAssertEqual(reason, .platformUnsupported)
        case .prepared:
            XCTFail("Unsupported factory must not create a controller")
        }
    }

    @MainActor
    func testProductionFactoryMatchesActualPlatformSupport()
        throws
    {
        let displayLayer = AVSampleBufferDisplayLayer()
        let factory =
            MobilePictureInPictureAVKitNativeControllerFactory()
        let systemSupport =
            AVPictureInPictureController.isPictureInPictureSupported()

        switch factory.makeController(displayLayer: displayLayer) {
        case let .unavailable(reason):
            XCTAssertEqual(
                reason,
                systemSupport
                    ? .controllerUnavailable
                    : .platformUnsupported
            )
        case let .prepared(nativeBridge):
            XCTAssertTrue(systemSupport)
            let bridge = try XCTUnwrap(
                nativeBridge as?
                    MobilePictureInPictureAVKitNativeControllerBridge
            )
            let controller = try XCTUnwrap(bridge.controller)
            let contentSource = try XCTUnwrap(bridge.contentSource)
            XCTAssertTrue(
                contentSource.sampleBufferDisplayLayer === displayLayer
            )
            XCTAssertTrue(
                contentSource.sampleBufferPlaybackDelegate === bridge
            )
            XCTAssertTrue(controller.contentSource === contentSource)
            XCTAssertTrue(controller.delegate === bridge)
            XCTAssertTrue(bridge.hasPossibilityObservation)
            bridge.invalidate()
            XCTAssertFalse(bridge.hasPossibilityObservation)
            XCTAssertNil(controller.delegate)
            XCTAssertNil(controller.contentSource)
        }
    }

    func testPlaybackAdapterUsesTypedStateAndFiniteConversions()
        throws
    {
        let live = try XCTUnwrap(
            MobilePictureInPicturePlaybackState(
                timeline: .live,
                isPaused: false,
                backgroundAudioPolicy: .permitted
            )
        )
        let unavailable = try XCTUnwrap(
            MobilePictureInPicturePlaybackState(
                timeline: .unavailable,
                isPaused: true,
                backgroundAudioPolicy: .prohibited
            )
        )

        let liveRange =
            MobilePictureInPictureAVKitPlaybackAdapter.timeRange(
                for: live
            )
        XCTAssertEqual(liveRange.start, .zero)
        XCTAssertEqual(liveRange.duration, .positiveInfinity)
        XCTAssertEqual(
            MobilePictureInPictureAVKitPlaybackAdapter.timeRange(
                for: unavailable
            ),
            .invalid
        )
        XCTAssertFalse(
            MobilePictureInPictureAVKitPlaybackAdapter.isPaused(
                for: live
            )
        )
        XCTAssertTrue(
            MobilePictureInPictureAVKitPlaybackAdapter.isPaused(
                for: nil
            )
        )
        XCTAssertFalse(
            MobilePictureInPictureAVKitPlaybackAdapter
                .prohibitsBackgroundAudio(for: live)
        )
        XCTAssertTrue(
            MobilePictureInPictureAVKitPlaybackAdapter
                .prohibitsBackgroundAudio(for: unavailable)
        )
        XCTAssertEqual(
            MobilePictureInPictureAVKitPlaybackAdapter.skipInterval(
                from: CMTime(seconds: 3, preferredTimescale: 600)
            )?.nanoseconds,
            3_000_000_000
        )
        XCTAssertNil(
            MobilePictureInPictureAVKitPlaybackAdapter.skipInterval(
                from: .invalid
            )
        )
        XCTAssertNil(
            MobilePictureInPictureAVKitPlaybackAdapter.skipInterval(
                from: .zero
            )
        )
        XCTAssertEqual(
            MobilePictureInPictureAVKitPlaybackAdapter.renderSize(
                from: CMVideoDimensions(width: 640, height: 360)
            ),
            MobilePictureInPictureRenderSize(width: 640, height: 360)
        )
        XCTAssertNil(
            MobilePictureInPictureAVKitPlaybackAdapter.renderSize(
                from: CMVideoDimensions(width: 0, height: 360)
            )
        )
    }

    private func makeGeneration()
        -> MobilePictureInPictureGeneration?
    {
        MobilePictureInPictureGeneration(
            mediaGeneration: 9,
            pictureInPictureGeneration: 4
        )
    }

    private func restorationLease(
        from events: [MobilePictureInPictureClientEventEnvelope]
    ) throws -> MobilePictureInPictureClientCallbackLease {
        for event in events {
            if case let .restoreInterfaceRequested(lease) = event.event {
                return lease
            }
        }
        throw TestFailure.missingRestorationLease
    }

    private func skipLease(
        from events: [MobilePictureInPictureClientEventEnvelope]
    ) throws -> MobilePictureInPictureClientCallbackLease {
        for event in events {
            if case let .skipRequested(_, lease) = event.event {
                return lease
            }
        }
        throw TestFailure.missingSkipLease
    }

    private enum TestFailure: Error {
        case missingRestorationLease
        case missingSkipLease
    }
}

@MainActor
private final class RecordingPictureInPictureNativeFactory:
    MobilePictureInPictureNativeControllerFactory
{
    private let preparation:
        MobilePictureInPictureNativeControllerPreparation
    private(set) var makeCount = 0

    init(
        preparation:
            MobilePictureInPictureNativeControllerPreparation
    ) {
        self.preparation = preparation
    }

    func makeController(
        displayLayer: AVSampleBufferDisplayLayer
    ) -> MobilePictureInPictureNativeControllerPreparation {
        _ = displayLayer
        makeCount += 1
        return preparation
    }
}

@MainActor
private final class RecordingPictureInPictureNativeBridge:
    MobilePictureInPictureNativeControllerBridge
{
    enum Command: Equatable {
        case start
        case stop
        case updatePlaybackState(
            MobilePictureInPicturePlaybackState
        )
        case invalidatePlaybackState
    }

    var isPictureInPicturePossible: Bool
    var isPictureInPictureActive = false
    private(set) var commands: [Command] = []
    private(set) var invalidateCount = 0
    private(set) var currentHandler:
        MobilePictureInPictureNativeControllerEventHandler?
    private var isInvalidated = false

    init(isPossible: Bool) {
        isPictureInPicturePossible = isPossible
    }

    func setEventHandler(
        _ handler: MobilePictureInPictureNativeControllerEventHandler?
    ) {
        currentHandler = handler
    }

    func startPictureInPicture() {
        guard !isInvalidated else { return }
        commands.append(.start)
    }

    func stopPictureInPicture() {
        guard !isInvalidated else { return }
        commands.append(.stop)
    }

    func updatePlaybackState(
        _ state: MobilePictureInPicturePlaybackState
    ) {
        guard !isInvalidated else { return }
        commands.append(.updatePlaybackState(state))
    }

    func invalidatePlaybackState() {
        guard !isInvalidated else { return }
        commands.append(.invalidatePlaybackState)
    }

    func invalidate() {
        guard !isInvalidated else { return }
        isInvalidated = true
        invalidateCount += 1
        currentHandler = nil
    }

    func emit(_ event: MobilePictureInPictureNativeControllerEvent) {
        guard !isInvalidated else { return }
        if case let .possibilityChanged(isPossible) = event {
            isPictureInPicturePossible = isPossible
        }
        currentHandler?(event)
    }
}

private final class ThreadSafePictureInPictureCompletionRecorder:
    @unchecked Sendable
{
    private let lock = NSLock()
    private var storedRestorationResults: [Bool] = []
    private var storedSkipCount = 0

    var restorationResults: [Bool] {
        lock.lock()
        defer { lock.unlock() }
        return storedRestorationResults
    }

    var skipCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return storedSkipCount
    }

    func recordRestoration(_ restored: Bool) {
        lock.lock()
        storedRestorationResults.append(restored)
        lock.unlock()
    }

    func recordSkip() {
        lock.lock()
        storedSkipCount += 1
        lock.unlock()
    }
}
