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

    func testControllerLifecycleFollowsClosedNativeTransitionSequence() throws {
        var reducer = makeReducer()
        let sequence: [
            (MobilePictureInPictureEvent, MobilePictureInPictureLifecycle)
        ] = [
            (.prepareRequested, .preparing),
            (
                .prepared(
                    capability: .possible,
                    frameSink: readySink()
                ),
                .ready
            ),
            (.startRequested, .startRequested),
            (.willStart, .starting),
            (.didStart, .active),
            (.stopRequested, .stopRequested),
            (.willStop, .stopping),
            (.didStop, .stopped)
        ]

        for (index, entry) in sequence.enumerated() {
            let snapshot = try applied(reducer.apply(envelope(entry.0)))
            XCTAssertEqual(snapshot.state.lifecycle, entry.1, "step \(index)")
            XCTAssertEqual(snapshot.revision.rawValue, UInt64(index + 1))
        }
        XCTAssertFalse(
            reducer.snapshot?.state.lifecycle.isConfirmedActive ?? true
        )
    }

    func testInvalidControllerEventsCannotLeaveUnpreparedState() {
        let invalidEvents: [MobilePictureInPictureEvent] = [
            .prepared(capability: .possible, frameSink: readySink()),
            .willStart,
            .didStart,
            .startFailed(.nativeStartFailed),
            .stopRequested,
            .willStop,
            .didStop,
            .restorationRequested
        ]

        for event in invalidEvents {
            var reducer = makeReducer()
            let before = reducer.snapshot

            guard case .rejected(.invalidTransition(
                lifecycle: .unprepared,
                event: _
            )) = reducer.apply(envelope(event)) else {
                XCTFail("Expected closed rejection for \(event)")
                continue
            }
            XCTAssertEqual(reducer.snapshot, before)
            XCTAssertEqual(reducer.revision.rawValue, 0)
        }

        var reducer = makeReducer()
        let before = reducer.snapshot

        XCTAssertEqual(
            reducer.apply(envelope(.startRequested)),
            .rejected(.pictureInPictureUnavailable)
        )
        XCTAssertEqual(reducer.snapshot, before)
        XCTAssertEqual(reducer.revision.rawValue, 0)
    }

    func testEquivalentCapabilityAndSinkEventsAreSemanticDuplicates() {
        var reducer = makePreparedReducer()
        let before = reducer.snapshot

        XCTAssertEqual(
            reducer.apply(envelope(.capabilityChanged(.possible))),
            .unchanged
        )
        XCTAssertEqual(
            reducer.apply(envelope(.frameSinkChanged(readySink()))),
            .unchanged
        )
        XCTAssertEqual(reducer.snapshot, before)
    }

    func testRestorationRejectsConcurrentRequestAndAdvancesLeaseOrdinal()
        throws
    {
        var reducer = makeActiveReducer()
        _ = reducer.apply(envelope(.stopRequested))
        let firstRequest = reducer.apply(envelope(.restorationRequested))
        let firstLease = try XCTUnwrap(
            try applied(firstRequest).state.restoration.pendingLease
        )
        let pendingSnapshot = reducer.snapshot

        XCTAssertEqual(
            reducer.apply(envelope(.restorationRequested)),
            .rejected(.restorationAlreadyPending)
        )
        XCTAssertEqual(reducer.snapshot, pendingSnapshot)

        _ = reducer.apply(envelope(.restorationCompleted(
            lease: firstLease,
            result: .declined
        )))
        let secondRequest = reducer.apply(envelope(.restorationRequested))
        let secondLease = try XCTUnwrap(
            try applied(secondRequest).state.restoration.pendingLease
        )

        XCTAssertEqual(firstLease.ordinal, 1)
        XCTAssertEqual(secondLease.ordinal, 2)
        XCTAssertEqual(secondLease.generation, firstLease.generation)
    }

    func testRestorationOrdinalOverflowFailsClosedWithoutRestoreEffect()
        throws
    {
        var reducer = MobilePictureInPictureStateReducer(
            generation: makeGeneration()!,
            initialRestorationOrdinal: .max
        )
        _ = reducer.apply(envelope(.prepareRequested))
        _ = reducer.apply(envelope(.prepared(
            capability: .possible,
            frameSink: readySink()
        )))
        _ = reducer.apply(envelope(.startRequested))
        _ = reducer.apply(envelope(.didStart))
        _ = reducer.apply(envelope(.stopRequested))

        let outcome = reducer.apply(envelope(.restorationRequested))
        let snapshot = try applied(outcome)

        XCTAssertEqual(snapshot.state.lifecycle, .failed)
        XCTAssertEqual(
            snapshot.state.failure,
            .restorationLeaseExhausted
        )
        XCTAssertEqual(effects(outcome), [])
        XCTAssertNil(snapshot.state.restoration.pendingLease)
    }

    func testFrameSinkFiniteCapacityCoversEveryBoundary() {
        XCTAssertNil(
            MobilePictureInPictureFrameSinkSnapshot.backpressured(
                decoderGeneration: 4,
                pendingFrameCount: -1
            )
        )
        XCTAssertEqual(
            MobilePictureInPictureFrameSinkSnapshot.backpressured(
                decoderGeneration: 4,
                pendingFrameCount: 0
            )?.pendingFrameCount,
            0
        )
        XCTAssertEqual(
            MobilePictureInPictureFrameSinkSnapshot.backpressured(
                decoderGeneration: 4,
                pendingFrameCount:
                    MobilePictureInPictureFrameSinkSnapshot
                        .maximumPendingFrameCount
            )?.pendingFrameCount,
            1
        )
        XCTAssertNil(
            MobilePictureInPictureFrameSinkSnapshot.backpressured(
                decoderGeneration: .max,
                pendingFrameCount:
                    MobilePictureInPictureFrameSinkSnapshot
                        .maximumPendingFrameCount + 1
            )
        )
    }

    func testContinuityPolicyGridHasDeterministicClosedPrecedence() {
        let platforms: [ApplePlatformFamily] = [
            .macOS,
            .iOS,
            .iPadOS,
            .tvOS,
            .visionOS
        ]
        let activities: [AppSceneActivity] = [
            .active,
            .inactive,
            .background
        ]
        let lifecycles: [MobilePictureInPictureLifecycle] = [
            .ready,
            .active
        ]
        var evaluated = 0

        for platform in platforms {
            for activity in activities {
                for streamActive in [false, true] {
                    for lifecycle in lifecycles {
                        for sinkOperational in [false, true] {
                            for audioActive in [false, true] {
                                for audioPermitted in [false, true] {
                                    for declared in [false, true] {
                                        for pipEnabled in [false, true] {
                                            for audioEnabled in [false, true] {
                                                let input =
                                                    MobileContinuityPathInput(
                                                        platform: platform,
                                                        sceneActivity: activity,
                                                        isStreamActive:
                                                            streamActive,
                                                        pictureInPictureLifecycle:
                                                            lifecycle,
                                                        isPictureInPictureFrameSinkOperational:
                                                            sinkOperational,
                                                        isAudioSessionActive:
                                                            audioActive,
                                                        isAudioContinuityPermitted:
                                                            audioPermitted,
                                                        hasPlaybackBackgroundModeDeclared:
                                                            declared,
                                                        preferences:
                                                            ContinuityPreferences(
                                                                audioContinuityEnabled:
                                                                    audioEnabled,
                                                                pictureInPictureEnabled:
                                                                    pipEnabled,
                                                                reduceRenderingInBackground:
                                                                    true
                                                            )
                                                    )
                                                XCTAssertEqual(
                                                    MobileContinuityPathResolver
                                                        .resolve(input),
                                                    expectedPath(for: input),
                                                    "case \(evaluated)"
                                                )
                                                evaluated += 1
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        XCTAssertEqual(evaluated, 3_840)
    }

    func testContinuityRevisionOverflowClearsPublishedPath() throws {
        let generation = makeGeneration()!
        var reducer = MobileContinuityPathStateReducer(
            generation: generation,
            initialRevision: MobilePictureInPictureRevision(
                rawValue: .max - 1
            )
        )
        let background = makePathInput(
            pictureInPictureLifecycle: .active,
            audioActive: false,
            configurationDeclared: true
        )
        let first = try publishedPath(
            reducer.update(background, generation: generation)
        )

        XCTAssertEqual(first.revision.rawValue, .max)
        XCTAssertEqual(
            reducer.update(
                MobileContinuityPathInput(
                    platform: .iPadOS,
                    sceneActivity: .active,
                    isStreamActive: true,
                    pictureInPictureLifecycle: .active,
                    isPictureInPictureFrameSinkOperational: true,
                    isAudioSessionActive: false,
                    isAudioContinuityPermitted: true,
                    hasPlaybackBackgroundModeDeclared: true,
                    preferences: .defaults
                ),
                generation: generation
            ),
            .revisionExhausted
        )
        XCTAssertNil(reducer.snapshot)
        XCTAssertTrue(reducer.isRevisionExhausted)
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

    private func expectedPath(
        for input: MobileContinuityPathInput
    ) -> MobileContinuityPathResolution {
        guard input.platform == .iOS || input.platform == .iPadOS else {
            return MobileContinuityPathResolution(
                path: .unavailable,
                unavailableReason: .unsupportedPlatform
            )
        }
        guard input.isStreamActive else {
            return MobileContinuityPathResolution(
                path: .inactive,
                unavailableReason: nil
            )
        }
        guard input.sceneActivity == .background else {
            return MobileContinuityPathResolution(
                path: .foreground,
                unavailableReason: nil
            )
        }

        let hasPictureInPicture =
            input.preferences.pictureInPictureEnabled
                && input.pictureInPictureLifecycle == .active
                && input.isPictureInPictureFrameSinkOperational
        let hasAudio =
            input.preferences.audioContinuityEnabled
                && input.isAudioSessionActive
                && input.isAudioContinuityPermitted
        guard hasPictureInPicture || hasAudio else {
            return MobileContinuityPathResolution(
                path: .unavailable,
                unavailableReason: .noActivePermittedMediaPath
            )
        }
        guard input.hasPlaybackBackgroundModeDeclared else {
            return MobileContinuityPathResolution(
                path: .unavailable,
                unavailableReason: .backgroundConfigurationMissing
            )
        }
        return MobileContinuityPathResolution(
            path: hasPictureInPicture ? .pictureInPicture : .audioOnly,
            unavailableReason: nil
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
