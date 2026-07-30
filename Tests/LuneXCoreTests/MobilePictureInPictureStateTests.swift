import XCTest

final class MobilePictureInPictureStateTests: XCTestCase {
    func testGenerationRejectsZeroComponents() {
        XCTAssertNil(makeGeneration(media: 0, pictureInPicture: 1))
        XCTAssertNil(makeGeneration(media: 1, pictureInPicture: 0))
        XCTAssertEqual(
            makeGeneration(media: .max, pictureInPicture: .max)?
                .pictureInPictureGeneration,
            .max
        )
    }

    func testStartBecomesActiveOnlyAfterNativeConfirmation() throws {
        var reducer = makePreparedReducer()

        let requested = try applied(
            reducer.apply(envelope(.startRequested))
        )
        XCTAssertEqual(requested.state.lifecycle, .startRequested)
        XCTAssertFalse(requested.state.lifecycle.isConfirmedActive)
        XCTAssertEqual(
            effects(reducer.apply(envelope(.willStart))),
            []
        )
        XCTAssertEqual(reducer.snapshot?.state.lifecycle, .starting)

        let confirmed = try applied(
            reducer.apply(envelope(.didStart))
        )
        XCTAssertEqual(confirmed.state.lifecycle, .active)
        XCTAssertTrue(confirmed.state.lifecycle.isConfirmedActive)
    }

    func testStartRequiresPossibleCapabilityAndCurrentFrameSink() {
        var impossible = makeReducer()
        _ = impossible.apply(envelope(.prepareRequested))
        _ = impossible.apply(envelope(.prepared(
            capability: .unavailable(.notPossible),
            frameSink: readySink()
        )))

        XCTAssertEqual(
            impossible.apply(envelope(.startRequested)),
            .rejected(.pictureInPictureUnavailable)
        )

        var detached = makeReducer()
        _ = detached.apply(envelope(.prepareRequested))
        _ = detached.apply(envelope(.prepared(
            capability: .possible,
            frameSink: .detached
        )))

        XCTAssertEqual(
            detached.apply(envelope(.startRequested)),
            .rejected(.frameSinkUnavailable)
        )
    }

    func testStaleGenerationCannotMutateCurrentSnapshot() {
        var reducer = makePreparedReducer()
        let before = reducer.snapshot
        let stale = makeGeneration(media: 9, pictureInPicture: 2)!

        XCTAssertEqual(
            reducer.apply(MobilePictureInPictureEventEnvelope(
                generation: stale,
                event: .startRequested
            )),
            .rejected(.staleGeneration)
        )
        XCTAssertEqual(reducer.snapshot, before)
    }

    func testNativeStartFailureIsStableAndFlushesSink() throws {
        var reducer = makePreparedReducer()
        _ = reducer.apply(envelope(.startRequested))
        _ = reducer.apply(envelope(.willStart))

        let outcome = reducer.apply(envelope(
            .startFailed(.nativeStartFailed)
        ))
        let snapshot = try applied(outcome)

        XCTAssertEqual(snapshot.state.lifecycle, .failed)
        XCTAssertEqual(snapshot.state.failure, .nativeStartFailed)
        XCTAssertEqual(effects(outcome), [.flushFrameSink])
    }

    func testCapabilityLossDoesNotInventNativeStopWhileActive() throws {
        var reducer = makeActiveReducer()

        let snapshot = try applied(reducer.apply(envelope(
            .capabilityChanged(.unavailable(.notPossible))
        )))

        XCTAssertEqual(snapshot.state.capability, .unavailable(.notPossible))
        XCTAssertEqual(snapshot.state.lifecycle, .active)
        XCTAssertTrue(snapshot.state.lifecycle.isConfirmedActive)
    }

    func testNativeStartConfirmationSurvivesPossibilityAndSinkChanges()
        throws
    {
        var reducer = makePreparedReducer()
        _ = reducer.apply(envelope(.startRequested))
        _ = reducer.apply(envelope(.willStart))
        _ = reducer.apply(envelope(
            .capabilityChanged(.unavailable(.notPossible))
        ))
        _ = reducer.apply(envelope(
            .frameSinkChanged(.failed(.frameSinkFailed))
        ))

        let confirmed = try applied(reducer.apply(envelope(.didStart)))

        XCTAssertEqual(confirmed.state.lifecycle, .active)
        XCTAssertEqual(confirmed.state.failure, .frameSinkFailed)
        XCTAssertFalse(
            confirmed.state.frameSink.acceptsCurrentGenerationFrames
        )
    }

    func testFrameSinkCapacityAndGenerationAreClosed() {
        XCTAssertNil(
            MobilePictureInPictureFrameSinkSnapshot.ready(
                decoderGeneration: 0
            )
        )
        XCTAssertNil(
            MobilePictureInPictureFrameSinkSnapshot.backpressured(
                decoderGeneration: 4,
                pendingFrameCount: 2
            )
        )
        XCTAssertEqual(
            MobilePictureInPictureFrameSinkSnapshot.backpressured(
                decoderGeneration: 4,
                pendingFrameCount: 1
            )?.pendingFrameCount,
            1
        )
    }

    func testRestorationLeaseCompletesExactlyOnce() throws {
        var reducer = makeActiveReducer()
        _ = reducer.apply(envelope(.stopRequested))
        _ = reducer.apply(envelope(.willStop))

        let requested = reducer.apply(envelope(.restorationRequested))
        let lease = try XCTUnwrap(
            try applied(requested).state.restoration.pendingLease
        )
        XCTAssertEqual(effects(requested), [.restoreInterface(lease)])

        let completedEvent = MobilePictureInPictureEvent.restorationCompleted(
            lease: lease,
            result: .restored
        )
        let completed = reducer.apply(envelope(completedEvent))
        XCTAssertEqual(
            effects(completed),
            [.completeRestoration(lease: lease, restored: true)]
        )
        XCTAssertEqual(
            reducer.apply(envelope(completedEvent)),
            .rejected(.staleRestorationLease)
        )
    }

    func testInvalidationCompletesPendingRestorationAndReleasesSink() throws {
        var reducer = makeActiveReducer()
        _ = reducer.apply(envelope(.stopRequested))
        let requested = reducer.apply(envelope(.restorationRequested))
        let lease = try XCTUnwrap(
            try applied(requested).state.restoration.pendingLease
        )

        let invalidated = reducer.apply(envelope(.invalidate))

        XCTAssertEqual(
            effects(invalidated),
            [
                .completeRestoration(lease: lease, restored: false),
                .flushFrameSink,
                .releaseFrameSink
            ]
        )
        XCTAssertEqual(
            reducer.snapshot?.state.lifecycle,
            .invalidated
        )
        XCTAssertEqual(
            reducer.apply(envelope(.invalidate)),
            .unchanged
        )
    }

    func testContinuityRequiresConfirmedActivePathAndConfiguration() {
        let requestOnly = resolvePath(
            pictureInPictureLifecycle: .startRequested,
            audioActive: false,
            configurationDeclared: true
        )
        let configurationOnly = resolvePath(
            pictureInPictureLifecycle: .ready,
            audioActive: false,
            configurationDeclared: true
        )
        let missingConfiguration = resolvePath(
            pictureInPictureLifecycle: .active,
            pictureInPictureSinkOperational: true,
            audioActive: false,
            configurationDeclared: false
        )
        let failedSink = resolvePath(
            pictureInPictureLifecycle: .active,
            pictureInPictureSinkOperational: false,
            audioActive: false,
            configurationDeclared: true
        )

        XCTAssertEqual(
            requestOnly,
            MobileContinuityPathResolution(
                path: .unavailable,
                unavailableReason: .noActivePermittedMediaPath
            )
        )
        XCTAssertEqual(configurationOnly, requestOnly)
        XCTAssertEqual(
            missingConfiguration,
            MobileContinuityPathResolution(
                path: .unavailable,
                unavailableReason: .backgroundConfigurationMissing
            )
        )
        XCTAssertEqual(failedSink, requestOnly)
    }

    func testContinuityPrefersActivePictureInPictureThenAudio() {
        XCTAssertEqual(
            resolvePath(
                pictureInPictureLifecycle: .active,
                audioActive: true,
                configurationDeclared: true
            ).path,
            .pictureInPicture
        )
        XCTAssertEqual(
            resolvePath(
                pictureInPictureLifecycle: .stopped,
                audioActive: true,
                configurationDeclared: true
            ).path,
            .audioOnly
        )
    }

    func testContinuityReducerDeduplicatesAndRejectsStaleGeneration()
        throws
    {
        let generation = makeGeneration()!
        var reducer = MobileContinuityPathStateReducer(
            generation: generation
        )
        let input = makePathInput(
            pictureInPictureLifecycle: .active,
            audioActive: true,
            configurationDeclared: true
        )

        let first = try publishedPath(
            reducer.update(input, generation: generation)
        )
        XCTAssertEqual(first.revision.rawValue, 1)
        XCTAssertEqual(
            reducer.update(input, generation: generation),
            .unchanged
        )

        let stale = makeGeneration(media: 8, pictureInPicture: 2)!
        XCTAssertEqual(
            reducer.update(input, generation: stale),
            .staleGeneration
        )
        XCTAssertEqual(reducer.snapshot, first)
    }

    func testRevisionOverflowFailsClosedAndEmitsCleanup() {
        var reducer = MobilePictureInPictureStateReducer(
            generation: makeGeneration()!,
            initialRevision: MobilePictureInPictureRevision(rawValue: .max)
        )

        XCTAssertEqual(
            reducer.apply(envelope(.prepareRequested)),
            .revisionExhausted([
                .flushFrameSink,
                .releaseFrameSink
            ])
        )
        XCTAssertNil(reducer.snapshot)
        XCTAssertTrue(reducer.isRevisionExhausted)
        XCTAssertEqual(
            reducer.apply(envelope(.prepareRequested)),
            .revisionExhausted([])
        )
    }

    func testRevisionOverflowDoesNotEmitRequestedNativeStart() {
        var reducer = MobilePictureInPictureStateReducer(
            generation: makeGeneration()!,
            initialRevision: MobilePictureInPictureRevision(
                rawValue: .max - 2
            )
        )
        _ = reducer.apply(envelope(.prepareRequested))
        _ = reducer.apply(envelope(.prepared(
            capability: .possible,
            frameSink: readySink()
        )))

        XCTAssertEqual(
            reducer.apply(envelope(.startRequested)),
            .revisionExhausted([
                .flushFrameSink,
                .releaseFrameSink
            ])
        )
        XCTAssertNil(reducer.snapshot)
    }

    private func makePreparedReducer()
        -> MobilePictureInPictureStateReducer
    {
        var reducer = makeReducer()
        _ = reducer.apply(envelope(.prepareRequested))
        _ = reducer.apply(envelope(.prepared(
            capability: .possible,
            frameSink: readySink()
        )))
        return reducer
    }

    private func makeActiveReducer()
        -> MobilePictureInPictureStateReducer
    {
        var reducer = makePreparedReducer()
        _ = reducer.apply(envelope(.startRequested))
        _ = reducer.apply(envelope(.willStart))
        _ = reducer.apply(envelope(.didStart))
        return reducer
    }

    private func makeReducer() -> MobilePictureInPictureStateReducer {
        MobilePictureInPictureStateReducer(generation: makeGeneration()!)
    }

    private func makeGeneration(
        media: UInt64 = 8,
        pictureInPicture: UInt64 = 1
    ) -> MobilePictureInPictureGeneration? {
        MobilePictureInPictureGeneration(
            mediaGeneration: media,
            pictureInPictureGeneration: pictureInPicture
        )
    }

    private func envelope(
        _ event: MobilePictureInPictureEvent
    ) -> MobilePictureInPictureEventEnvelope {
        MobilePictureInPictureEventEnvelope(
            generation: makeGeneration()!,
            event: event
        )
    }

    private func readySink()
        -> MobilePictureInPictureFrameSinkSnapshot
    {
        MobilePictureInPictureFrameSinkSnapshot.ready(
            decoderGeneration: 4
        )!
    }

    private func resolvePath(
        pictureInPictureLifecycle: MobilePictureInPictureLifecycle,
        pictureInPictureSinkOperational: Bool = true,
        audioActive: Bool,
        configurationDeclared: Bool
    ) -> MobileContinuityPathResolution {
        MobileContinuityPathResolver.resolve(makePathInput(
            pictureInPictureLifecycle: pictureInPictureLifecycle,
            pictureInPictureSinkOperational:
                pictureInPictureSinkOperational,
            audioActive: audioActive,
            configurationDeclared: configurationDeclared
        ))
    }

    private func makePathInput(
        pictureInPictureLifecycle: MobilePictureInPictureLifecycle,
        pictureInPictureSinkOperational: Bool = true,
        audioActive: Bool,
        configurationDeclared: Bool
    ) -> MobileContinuityPathInput {
        MobileContinuityPathInput(
            platform: .iPadOS,
            sceneActivity: .background,
            isStreamActive: true,
            pictureInPictureLifecycle: pictureInPictureLifecycle,
            isPictureInPictureFrameSinkOperational:
                pictureInPictureSinkOperational,
            isAudioSessionActive: audioActive,
            isAudioContinuityPermitted: true,
            hasPlaybackBackgroundModeDeclared: configurationDeclared,
            preferences: .defaults
        )
    }

    private func applied(
        _ outcome: MobilePictureInPictureReductionOutcome,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> MobilePictureInPictureSnapshot {
        guard case let .applied(snapshot, _) = outcome else {
            XCTFail(
                "Expected applied outcome, got \(outcome)",
                file: file,
                line: line
            )
            throw TestFailure.expectedAppliedOutcome
        }
        return snapshot
    }

    private func effects(
        _ outcome: MobilePictureInPictureReductionOutcome
    ) -> [MobilePictureInPictureEffect] {
        guard case let .applied(_, effects) = outcome else {
            return []
        }
        return effects
    }

    private func publishedPath(
        _ outcome: MobileContinuityPathPublicationOutcome,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> MobileContinuityPathSnapshot {
        guard case let .published(snapshot) = outcome else {
            XCTFail(
                "Expected published path, got \(outcome)",
                file: file,
                line: line
            )
            throw TestFailure.expectedPublishedPath
        }
        return snapshot
    }

    private enum TestFailure: Error {
        case expectedAppliedOutcome
        case expectedPublishedPath
    }
}
