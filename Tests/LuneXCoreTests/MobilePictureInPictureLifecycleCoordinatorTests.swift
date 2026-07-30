import XCTest

final class MobilePictureInPictureLifecycleCoordinatorTests:
    XCTestCase
{
    @MainActor
    func testRejectsMismatchedClientAndFrameSinkGenerations()
        throws
    {
        let generation = try makeGeneration(media: 8, pictureInPicture: 3)
        let stale = try makeGeneration(media: 8, pictureInPicture: 2)
        let matchingSink = RecordingLifecycleFrameSink(
            generation: generation,
            snapshot: try readySink()
        )

        XCTAssertThrowsError(try MobilePictureInPictureLifecycleCoordinator(
            generation: generation,
            client: RecordingLifecycleControllerClient(
                generation: stale
            ),
            frameSink: matchingSink
        )) {
            XCTAssertEqual(
                $0 as? MobilePictureInPictureLifecycleCoordinatorError,
                .clientGenerationMismatch
            )
        }
        XCTAssertThrowsError(try MobilePictureInPictureLifecycleCoordinator(
            generation: generation,
            client: RecordingLifecycleControllerClient(
                generation: generation
            ),
            frameSink: RecordingLifecycleFrameSink(
                generation: stale,
                snapshot: try readySink()
            )
        )) {
            XCTAssertEqual(
                $0 as? MobilePictureInPictureLifecycleCoordinatorError,
                .frameSinkGenerationMismatch
            )
        }
    }

    @MainActor
    func testPreparePublishesPreparingBeforeSynchronousReady()
        throws
    {
        let generation = try makeGeneration()
        let preparation = try preparation(
            generation: generation,
            capability: .possible
        )
        let client = RecordingLifecycleControllerClient(
            generation: generation,
            preparationOnPrepare: preparation
        )
        let coordinator = try makeCoordinator(
            generation: generation,
            client: client
        )
        var events: [MobilePictureInPictureLifecycleCoordinatorEvent] = []
        coordinator.setEventHandler { events.append($0) }

        guard case let .applied(requestedPreparation) =
                coordinator.prepare() else {
            return XCTFail("Expected an applied prepare request")
        }
        XCTAssertEqual(
            requestedPreparation.state.lifecycle,
            .preparing
        )
        XCTAssertEqual(coordinator.snapshot?.state.lifecycle, .ready)
        XCTAssertEqual(client.commands, [.prepare])
        XCTAssertEqual(
            snapshotLifecycles(in: events),
            [.preparing, .ready]
        )
        XCTAssertEqual(coordinator.snapshot?.state.capability, .possible)
    }

    @MainActor
    func testPrepareConsumesAlreadyPreparedClientSnapshot()
        throws
    {
        let generation = try makeGeneration()
        let client = RecordingLifecycleControllerClient(
            generation: generation,
            existingPreparation: try preparation(
                generation: generation,
                capability: .possible
            )
        )
        let coordinator = try makeCoordinator(
            generation: generation,
            client: client
        )

        _ = coordinator.prepare()

        XCTAssertEqual(coordinator.snapshot?.state.lifecycle, .ready)
        XCTAssertEqual(client.commands, [])
    }

    @MainActor
    func testStartAndStopRequireNativeConfirmationAndPreserveOrdering()
        throws
    {
        let generation = try makeGeneration()
        let client = RecordingLifecycleControllerClient(
            generation: generation,
            preparationOnPrepare: try preparation(
                generation: generation,
                capability: .possible
            ),
            startEvents: [.willStart, .didStart],
            stopEvents: [.willStop, .didStop]
        )
        let sink = RecordingLifecycleFrameSink(
            generation: generation,
            snapshot: try readySink()
        )
        let coordinator = try MobilePictureInPictureLifecycleCoordinator(
            generation: generation,
            client: client,
            frameSink: sink
        )
        var events: [MobilePictureInPictureLifecycleCoordinatorEvent] = []
        coordinator.setEventHandler { events.append($0) }
        _ = coordinator.prepare()
        events.removeAll()

        let startOutcome = coordinator.requestStart()

        guard case let .applied(requestedStart) = startOutcome else {
            return XCTFail("Expected an applied start request")
        }
        XCTAssertEqual(requestedStart.state.lifecycle, .startRequested)
        XCTAssertEqual(coordinator.snapshot?.state.lifecycle, .active)
        XCTAssertEqual(
            snapshotLifecycles(in: events),
            [.startRequested, .starting, .active]
        )
        events.removeAll()

        let stopOutcome = coordinator.requestStop()

        guard case let .applied(requestedStop) = stopOutcome else {
            return XCTFail("Expected an applied stop request")
        }
        XCTAssertEqual(requestedStop.state.lifecycle, .stopRequested)
        XCTAssertEqual(coordinator.snapshot?.state.lifecycle, .stopped)
        XCTAssertEqual(
            snapshotLifecycles(in: events),
            [.stopRequested, .stopping, .stopped]
        )
        XCTAssertEqual(
            client.commands,
            [.prepare, .start, .stop]
        )
        XCTAssertEqual(sink.flushCount, 1)
    }

    @MainActor
    func testNativeStartFailureFlushesSinkAndRetainsForegroundRuntime()
        throws
    {
        let generation = try makeGeneration()
        let client = RecordingLifecycleControllerClient(
            generation: generation,
            preparationOnPrepare: try preparation(
                generation: generation,
                capability: .possible
            ),
            startEvents: [
                .willStart,
                .startFailed(.nativeStartFailed)
            ]
        )
        let sink = RecordingLifecycleFrameSink(
            generation: generation,
            snapshot: try readySink()
        )
        let coordinator = try MobilePictureInPictureLifecycleCoordinator(
            generation: generation,
            client: client,
            frameSink: sink
        )
        _ = coordinator.prepare()

        _ = coordinator.requestStart()

        XCTAssertEqual(coordinator.snapshot?.state.lifecycle, .failed)
        XCTAssertEqual(
            coordinator.snapshot?.state.failure,
            .nativeStartFailed
        )
        XCTAssertEqual(sink.flushCount, 1)
        XCTAssertEqual(sink.invalidateCount, 0)
        XCTAssertFalse(coordinator.isInvalidated)
    }

    @MainActor
    func testPossibilityAndFrameSinkChangesRecoverReadyState()
        throws
    {
        let generation = try makeGeneration()
        let client = RecordingLifecycleControllerClient(
            generation: generation,
            preparationOnPrepare: try preparation(
                generation: generation,
                capability: .possible
            )
        )
        let sink = RecordingLifecycleFrameSink(
            generation: generation,
            snapshot: try readySink()
        )
        let coordinator = try MobilePictureInPictureLifecycleCoordinator(
            generation: generation,
            client: client,
            frameSink: sink
        )
        _ = coordinator.prepare()

        client.emit(.capabilityChanged(.unavailable(.notPossible)))
        XCTAssertEqual(coordinator.snapshot?.state.lifecycle, .unavailable)
        client.emit(.capabilityChanged(.possible))
        XCTAssertEqual(coordinator.snapshot?.state.lifecycle, .ready)

        sink.snapshot = .failed(.frameSinkFailed)
        _ = coordinator.refreshFrameSink()
        XCTAssertEqual(coordinator.snapshot?.state.lifecycle, .failed)
        sink.snapshot = try readySink()
        _ = coordinator.refreshFrameSink()
        XCTAssertEqual(coordinator.snapshot?.state.lifecycle, .ready)
    }

    @MainActor
    func testPlaybackStateDeduplicatesAndInvalidatesNativePlaybackState()
        throws
    {
        let generation = try makeGeneration()
        let client = RecordingLifecycleControllerClient(
            generation: generation
        )
        let coordinator = try makeCoordinator(
            generation: generation,
            client: client
        )
        let state = try XCTUnwrap(MobilePictureInPicturePlaybackState(
            timeline: .live,
            isPaused: false,
            backgroundAudioPolicy: .permitted
        ))

        XCTAssertTrue(coordinator.updatePlaybackState(state))
        XCTAssertFalse(coordinator.updatePlaybackState(state))

        XCTAssertEqual(
            client.commands,
            [.playback(state), .invalidatePlaybackState]
        )
    }

    @MainActor
    func testPlaybackDelegateRequestsAreForwardedAndSkipCompletesOnce()
        throws
    {
        let generation = try makeGeneration()
        let client = RecordingLifecycleControllerClient(
            generation: generation
        )
        let coordinator = try makeCoordinator(
            generation: generation,
            client: client
        )
        let skipLease = try clientLease(
            generation: generation,
            kind: .skip,
            ordinal: 7
        )
        let interval = try XCTUnwrap(
            MobilePictureInPictureSkipInterval(
                nanoseconds: 5_000_000_000
            )
        )
        let renderSize = try XCTUnwrap(
            MobilePictureInPictureRenderSize(width: 1_920, height: 1_080)
        )
        var events: [MobilePictureInPictureLifecycleCoordinatorEvent] = []
        coordinator.setEventHandler { events.append($0) }

        client.emit(.setPlaying(false))
        client.emit(.skipRequested(
            interval: interval,
            completion: skipLease
        ))
        client.emit(.renderSizeChanged(renderSize))

        XCTAssertEqual(
            events,
            [
                .setPlayingRequested(false),
                .skipRequested(
                    interval: interval,
                    completion: skipLease
                ),
                .renderSizeChanged(renderSize)
            ]
        )
        XCTAssertEqual(
            coordinator.completeSkip(skipLease),
            .completed
        )
        XCTAssertEqual(
            coordinator.completeSkip(skipLease),
            .alreadyCompleted
        )
        XCTAssertEqual(client.completions, [
            .init(lease: skipLease, completion: .skip)
        ])
    }

    @MainActor
    func testRestorationMapsRuntimeLeaseAndCompletesExactlyOnce()
        throws
    {
        let generation = try makeGeneration()
        let client = RecordingLifecycleControllerClient(
            generation: generation,
            preparationOnPrepare: try preparation(
                generation: generation,
                capability: .possible
            )
        )
        let coordinator = try makeCoordinator(
            generation: generation,
            client: client
        )
        _ = coordinator.prepare()
        _ = coordinator.requestStart()
        client.emit(.didStart)
        let nativeLease = try clientLease(
            generation: generation,
            kind: .restoreInterface,
            ordinal: 41
        )
        var runtimeLease: MobilePictureInPictureRestorationLease?
        coordinator.setEventHandler {
            if case let .restoreInterfaceRequested(lease) = $0 {
                runtimeLease = lease
            }
        }

        client.emit(.restoreInterfaceRequested(nativeLease))

        let lease = try XCTUnwrap(runtimeLease)
        XCTAssertNotEqual(lease.ordinal, nativeLease.ordinal)
        XCTAssertEqual(
            coordinator.completeRestoration(
                lease,
                result: .restored
            ),
            .applied(try snapshot(
                from: coordinator,
                lifecycle: .active
            ))
        )
        guard case let .rejected(rejection) =
                coordinator.completeRestoration(
                    lease,
                    result: .declined
                ) else {
            return XCTFail("Duplicate completion must be rejected")
        }
        XCTAssertEqual(rejection, .staleRestorationLease)
        XCTAssertEqual(client.completions, [
            .init(
                lease: nativeLease,
                completion: .restoreInterface(restored: true)
            )
        ])
    }

    @MainActor
    func testMissingOrRemovedConsumerCompletesPendingCallbacks()
        throws
    {
        let generation = try makeGeneration()
        let client = RecordingLifecycleControllerClient(
            generation: generation,
            preparationOnPrepare: try preparation(
                generation: generation,
                capability: .possible
            )
        )
        let coordinator = try makeCoordinator(
            generation: generation,
            client: client
        )
        _ = coordinator.prepare()
        _ = coordinator.requestStart()
        client.emit(.didStart)

        let missingConsumerLease = try clientLease(
            generation: generation,
            kind: .restoreInterface,
            ordinal: 1
        )
        client.emit(.restoreInterfaceRequested(missingConsumerLease))
        XCTAssertEqual(
            client.completions.last,
            .init(
                lease: missingConsumerLease,
                completion: .restoreInterface(restored: false)
            )
        )

        var events: [MobilePictureInPictureLifecycleCoordinatorEvent] = []
        coordinator.setEventHandler { events.append($0) }
        let restorationLease = try clientLease(
            generation: generation,
            kind: .restoreInterface,
            ordinal: 2
        )
        let skipLease = try clientLease(
            generation: generation,
            kind: .skip,
            ordinal: 3
        )
        client.emit(.restoreInterfaceRequested(restorationLease))
        client.emit(.skipRequested(
            interval: try XCTUnwrap(
                MobilePictureInPictureSkipInterval(
                    nanoseconds: 1_000_000_000
                )
            ),
            completion: skipLease
        ))

        coordinator.setEventHandler(nil)

        XCTAssertTrue(events.contains {
            if case .restoreInterfaceRequested = $0 { return true }
            return false
        })
        XCTAssertEqual(
            client.completions.suffix(2),
            [
                .init(
                    lease: restorationLease,
                    completion: .restoreInterface(restored: false)
                ),
                .init(lease: skipLease, completion: .skip)
            ]
        )
    }

    @MainActor
    func testInvalidationAndReplacementRejectLateOldCallbacks()
        throws
    {
        let oldGeneration = try makeGeneration(
            media: 8,
            pictureInPicture: 1
        )
        let newGeneration = try makeGeneration(
            media: 8,
            pictureInPicture: 2
        )
        let oldClient = RecordingLifecycleControllerClient(
            generation: oldGeneration,
            preparationOnPrepare: try preparation(
                generation: oldGeneration,
                capability: .possible
            )
        )
        let oldSink = RecordingLifecycleFrameSink(
            generation: oldGeneration,
            snapshot: try readySink()
        )
        let oldCoordinator =
            try MobilePictureInPictureLifecycleCoordinator(
                generation: oldGeneration,
                client: oldClient,
                frameSink: oldSink
            )
        _ = oldCoordinator.prepare()
        let staleHandler = try XCTUnwrap(oldClient.currentHandler)

        XCTAssertEqual(
            oldCoordinator.invalidate(),
            .applied(try snapshot(
                from: oldCoordinator,
                lifecycle: .invalidated
            ))
        )
        let newClient = RecordingLifecycleControllerClient(
            generation: newGeneration,
            preparationOnPrepare: try preparation(
                generation: newGeneration,
                capability: .possible
            )
        )
        let newCoordinator = try makeCoordinator(
            generation: newGeneration,
            client: newClient
        )
        _ = newCoordinator.prepare()

        staleHandler(try XCTUnwrap(
            MobilePictureInPictureClientEventEnvelope(
                generation: oldGeneration,
                event: .didStart
            )
        ))

        XCTAssertTrue(oldCoordinator.isInvalidated)
        XCTAssertNil(oldCoordinator.snapshot?.state.restoration.pendingLease)
        XCTAssertEqual(oldClient.invalidateCount, 1)
        XCTAssertEqual(oldSink.invalidateCount, 1)
        XCTAssertEqual(newCoordinator.snapshot?.state.lifecycle, .ready)
    }

    @MainActor
    func testUnexpectedClientInvalidationReleasesSinkWithoutReinvalidatingClient()
        throws
    {
        let generation = try makeGeneration()
        let client = RecordingLifecycleControllerClient(
            generation: generation,
            preparationOnPrepare: try preparation(
                generation: generation,
                capability: .possible
            )
        )
        let sink = RecordingLifecycleFrameSink(
            generation: generation,
            snapshot: try readySink()
        )
        let coordinator =
            try MobilePictureInPictureLifecycleCoordinator(
                generation: generation,
                client: client,
                frameSink: sink
            )
        _ = coordinator.prepare()
        var events: [MobilePictureInPictureLifecycleCoordinatorEvent] = []
        coordinator.setEventHandler { events.append($0) }

        client.emit(.invalidated)
        client.emit(.didStart)

        XCTAssertTrue(coordinator.isInvalidated)
        XCTAssertEqual(
            coordinator.snapshot?.state.lifecycle,
            .invalidated
        )
        XCTAssertEqual(client.invalidateCount, 0)
        XCTAssertEqual(sink.flushCount, 1)
        XCTAssertEqual(sink.invalidateCount, 1)
        XCTAssertEqual(
            snapshotLifecycles(in: events),
            [.invalidated]
        )
    }

    @MainActor
    func testRevisionExhaustionDrainsCallbacksWithoutReducerReentry()
        throws
    {
        let generation = try makeGeneration()
        let client = RecordingLifecycleControllerClient(
            generation: generation,
            preparationOnPrepare: try preparation(
                generation: generation,
                capability: .possible
            )
        )
        let sink = RecordingLifecycleFrameSink(
            generation: generation,
            snapshot: try readySink()
        )
        let coordinator =
            try MobilePictureInPictureLifecycleCoordinator(
                generation: generation,
                client: client,
                frameSink: sink,
                initialRevision: MobilePictureInPictureRevision(
                    rawValue: .max - 5
                )
            )
        var events: [MobilePictureInPictureLifecycleCoordinatorEvent] = []
        coordinator.setEventHandler { events.append($0) }
        _ = coordinator.prepare()
        _ = coordinator.requestStart()
        client.emit(.didStart)
        let restorationLease = try clientLease(
            generation: generation,
            kind: .restoreInterface,
            ordinal: 1
        )
        let skipLease = try clientLease(
            generation: generation,
            kind: .skip,
            ordinal: 2
        )
        client.emit(.restoreInterfaceRequested(restorationLease))
        client.emit(.skipRequested(
            interval: try XCTUnwrap(
                MobilePictureInPictureSkipInterval(
                    nanoseconds: 2_000_000_000
                )
            ),
            completion: skipLease
        ))
        sink.snapshot = try XCTUnwrap(
            MobilePictureInPictureFrameSinkSnapshot.backpressured(
                decoderGeneration: 91,
                pendingFrameCount: 1
            )
        )

        XCTAssertEqual(
            coordinator.refreshFrameSink(),
            .revisionExhausted
        )

        XCTAssertTrue(coordinator.isInvalidated)
        XCTAssertNil(coordinator.snapshot)
        XCTAssertEqual(client.invalidateCount, 1)
        XCTAssertEqual(sink.invalidateCount, 1)
        XCTAssertEqual(sink.flushCount, 1)
        XCTAssertEqual(
            client.completions,
            [
                .init(
                    lease: restorationLease,
                    completion: .restoreInterface(restored: false)
                ),
                .init(lease: skipLease, completion: .skip)
            ]
        )
        XCTAssertTrue(events.contains(.revisionExhausted))
        XCTAssertEqual(coordinator.requestStart(), .invalidated)
    }

    @MainActor
    private func makeCoordinator(
        generation: MobilePictureInPictureGeneration,
        client: RecordingLifecycleControllerClient
    ) throws -> MobilePictureInPictureLifecycleCoordinator {
        try MobilePictureInPictureLifecycleCoordinator(
            generation: generation,
            client: client,
            frameSink: RecordingLifecycleFrameSink(
                generation: generation,
                snapshot: try readySink()
            )
        )
    }

    private func makeGeneration(
        media: UInt64 = 8,
        pictureInPicture: UInt64 = 3
    ) throws -> MobilePictureInPictureGeneration {
        try XCTUnwrap(MobilePictureInPictureGeneration(
            mediaGeneration: media,
            pictureInPictureGeneration: pictureInPicture
        ))
    }

    private func readySink()
        throws -> MobilePictureInPictureFrameSinkSnapshot
    {
        try XCTUnwrap(MobilePictureInPictureFrameSinkSnapshot.ready(
            decoderGeneration: 91
        ))
    }

    private func preparation(
        generation: MobilePictureInPictureGeneration,
        capability: MobilePictureInPictureCapability
    ) throws -> MobilePictureInPictureClientPreparationSnapshot {
        try XCTUnwrap(MobilePictureInPictureClientPreparationSnapshot(
            generation: generation,
            components: .ready,
            capability: capability
        ))
    }

    private func clientLease(
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
    private func snapshot(
        from coordinator:
            MobilePictureInPictureLifecycleCoordinator,
        lifecycle: MobilePictureInPictureLifecycle
    ) throws -> MobilePictureInPictureSnapshot {
        let snapshot = try XCTUnwrap(coordinator.snapshot)
        XCTAssertEqual(snapshot.state.lifecycle, lifecycle)
        return snapshot
    }

    private func snapshotLifecycles(
        in events: [MobilePictureInPictureLifecycleCoordinatorEvent]
    ) -> [MobilePictureInPictureLifecycle] {
        events.compactMap {
            guard case let .snapshot(snapshot) = $0 else { return nil }
            return snapshot.state.lifecycle
        }
    }
}

@MainActor
private final class RecordingLifecycleFrameSink:
    MobilePictureInPictureLifecycleFrameSink
{
    let generation: MobilePictureInPictureGeneration
    var snapshot: MobilePictureInPictureFrameSinkSnapshot
    private(set) var flushCount = 0
    private(set) var invalidateCount = 0

    init(
        generation: MobilePictureInPictureGeneration,
        snapshot: MobilePictureInPictureFrameSinkSnapshot
    ) {
        self.generation = generation
        self.snapshot = snapshot
    }

    func currentFrameSinkSnapshot()
        -> MobilePictureInPictureFrameSinkSnapshot
    {
        snapshot
    }

    func flushForPictureInPictureLifecycle() -> Bool {
        flushCount += 1
        return true
    }

    func invalidate() {
        guard snapshot != .invalidated else { return }
        snapshot = .invalidated
        invalidateCount += 1
    }
}

@MainActor
private final class RecordingLifecycleControllerClient:
    MobilePictureInPictureControllerClient
{
    enum Command: Equatable {
        case prepare
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

    private let preparationOnPrepare:
        MobilePictureInPictureClientPreparationSnapshot?
    private let startEvents: [MobilePictureInPictureClientEvent]
    private let stopEvents: [MobilePictureInPictureClientEvent]
    private var completedLeases:
        Set<MobilePictureInPictureClientCallbackLease> = []
    private var isInvalidated = false

    init(
        generation: MobilePictureInPictureGeneration,
        existingPreparation:
            MobilePictureInPictureClientPreparationSnapshot? = nil,
        preparationOnPrepare:
            MobilePictureInPictureClientPreparationSnapshot? = nil,
        startEvents: [MobilePictureInPictureClientEvent] = [],
        stopEvents: [MobilePictureInPictureClientEvent] = []
    ) {
        self.generation = generation
        preparationSnapshot = existingPreparation
        self.preparationOnPrepare = preparationOnPrepare
        self.startEvents = startEvents
        self.stopEvents = stopEvents
    }

    func setEventHandler(
        _ handler: MobilePictureInPictureClientEventHandler?
    ) {
        currentHandler = handler
    }

    func prepare() {
        guard !isInvalidated else { return }
        commands.append(.prepare)
        if let preparationOnPrepare {
            preparationSnapshot = preparationOnPrepare
            emit(.prepared(preparationOnPrepare))
        }
    }

    func requestStart() {
        guard !isInvalidated else { return }
        commands.append(.start)
        for event in startEvents {
            emit(event)
        }
    }

    func requestStop() {
        guard !isInvalidated else { return }
        commands.append(.stop)
        for event in stopEvents {
            emit(event)
        }
    }

    func updatePlaybackState(
        _ state: MobilePictureInPicturePlaybackState
    ) {
        guard !isInvalidated else { return }
        commands.append(.playback(state))
    }

    func invalidatePlaybackState() {
        guard !isInvalidated else { return }
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
