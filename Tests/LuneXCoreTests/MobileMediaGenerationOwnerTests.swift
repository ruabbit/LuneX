import XCTest

final class MobileMediaGenerationOwnerTests: XCTestCase {
    func testForegroundActivationKeepsAllMediaPathsRunning() async throws {
        let client = RecordingMobileMediaGenerationActionClient()
        let owner = MobileMediaGenerationOwner(actionClient: client)
        let input = try makeInput(revision: 1, sceneActivity: .active)

        let outcome = try await owner.apply(input)
        let snapshot = try snapshot(from: outcome)

        XCTAssertEqual(snapshot.phase, .active)
        XCTAssertEqual(snapshot.plan.foreground, .baseline(.active))
        XCTAssertEqual(
            snapshot.plan.video,
            .continueForegroundPresentation
        )
        XCTAssertEqual(snapshot.plan.audio, .continuePlayback)
        XCTAssertEqual(snapshot.plan.control, .continueSession)
        XCTAssertEqual(snapshot.plan.stream, .running)
        let applications = await client.applications()
        XCTAssertEqual(applications.count, 1)
        XCTAssertEqual(applications.first?.transition, .activate)
    }

    func testConfirmedPictureInPictureSuppressesOnlyForegroundPresentation()
        async throws
    {
        let client = RecordingMobileMediaGenerationActionClient()
        let owner = MobileMediaGenerationOwner(actionClient: client)
        let generation = try makeGeneration()
        let input = try makeInput(
            generation: generation,
            revision: 1,
            sceneActivity: .background,
            actualMediaState: actualState(
                generation: generation,
                pictureInPictureLifecycle: .active,
                sinkOperational: true
            )
        )

        let outcome = try await owner.apply(input)
        let plan = try snapshot(from: outcome).plan

        XCTAssertEqual(
            plan.foreground,
            .suspended(reason: .pictureInPictureActive)
        )
        XCTAssertEqual(
            plan.video,
            .continuePictureInPictureDelivery
        )
        XCTAssertEqual(plan.audio, .continuePlayback)
        XCTAssertEqual(plan.control, .continueSession)
        XCTAssertEqual(plan.stream, .running)
    }

    func testAudioOnlyContinuityDrainsVideoButKeepsAudioAndControl()
        async throws
    {
        let client = RecordingMobileMediaGenerationActionClient()
        let owner = MobileMediaGenerationOwner(actionClient: client)
        let generation = try makeGeneration()
        let input = try makeInput(
            generation: generation,
            revision: 1,
            sceneActivity: .background,
            actualMediaState: actualState(
                generation: generation,
                audioActive: true,
                audioPermitted: true
            )
        )

        let outcome = try await owner.apply(input)
        let plan = try snapshot(from: outcome).plan

        XCTAssertEqual(
            plan.foreground,
            .suspended(reason: .audioOnlyContinuity)
        )
        XCTAssertEqual(plan.video, .drainTransportWithoutDecoding)
        XCTAssertEqual(plan.audio, .continuePlayback)
        XCTAssertEqual(plan.control, .continueSession)
        XCTAssertEqual(plan.stream, .running)
    }

    func testConfigurationOnlyBackgroundStatePausesUnsupportedWork()
        async throws
    {
        let client = RecordingMobileMediaGenerationActionClient()
        let owner = MobileMediaGenerationOwner(actionClient: client)
        let outcome = try await owner.apply(
            makeInput(revision: 1, sceneActivity: .background)
        )
        let plan = try snapshot(from: outcome).plan

        XCTAssertEqual(
            plan.foreground,
            .suspended(reason: .noActivePermittedMediaPath)
        )
        XCTAssertEqual(plan.video, .drainTransportWithoutDecoding)
        XCTAssertEqual(plan.audio, .pause)
        XCTAssertEqual(plan.control, .pauseSession)
        XCTAssertEqual(
            plan.stream,
            .paused(reason: .noActivePermittedMediaPath)
        )
    }

    func testLastLegalBackgroundPathLossImmediatelyPausesWork()
        async throws
    {
        let client = RecordingMobileMediaGenerationActionClient()
        let owner = MobileMediaGenerationOwner(actionClient: client)
        let generation = try makeGeneration()
        _ = try await owner.apply(try makeInput(
            generation: generation,
            revision: 1,
            sceneActivity: .background,
            actualMediaState: actualState(
                generation: generation,
                pictureInPictureLifecycle: .active,
                sinkOperational: true
            )
        ))
        let audioOnly = try await owner.apply(try makeInput(
            generation: generation,
            revision: 2,
            sceneActivity: .background,
            actualMediaState: actualState(
                generation: generation,
                audioActive: true,
                audioPermitted: true
            )
        ))
        XCTAssertEqual(
            try snapshot(from: audioOnly).plan.video,
            .drainTransportWithoutDecoding
        )
        XCTAssertEqual(
            try snapshot(from: audioOnly).plan.stream,
            .running
        )

        let unavailable = try await owner.apply(makeInput(
            generation: generation,
            revision: 3,
            sceneActivity: .background
        ))
        let unavailablePlan = try snapshot(from: unavailable).plan
        XCTAssertEqual(unavailablePlan.audio, .pause)
        XCTAssertEqual(unavailablePlan.control, .pauseSession)
        XCTAssertEqual(
            unavailablePlan.stream,
            .paused(reason: .noActivePermittedMediaPath)
        )
    }

    func testForegroundReturnResamplesExactlyOnce() async throws {
        let client = RecordingMobileMediaGenerationActionClient()
        let owner = MobileMediaGenerationOwner(actionClient: client)
        let generation = try makeGeneration()
        _ = try await owner.apply(try makeInput(
            generation: generation,
            revision: 1,
            sceneActivity: .background,
            actualMediaState: actualState(
                generation: generation,
                pictureInPictureLifecycle: .active,
                sinkOperational: true
            )
        ))

        let restored = try await owner.apply(makeInput(
            generation: generation,
            revision: 2,
            sceneActivity: .active
        ))
        let restoredSnapshot = try snapshot(from: restored)
        XCTAssertEqual(
            restoredSnapshot.plan.foreground,
            .restoreAndResample(.active)
        )
        XCTAssertEqual(restoredSnapshot.foregroundRestorationCount, 1)

        let settled = try await owner.apply(makeInput(
            generation: generation,
            revision: 3,
            sceneActivity: .active,
            foregroundBaseline: .throttled(reason: "Scene inactive")
        ))
        let settledSnapshot = try snapshot(from: settled)
        XCTAssertEqual(
            settledSnapshot.plan.foreground,
            .baseline(.throttled(reason: "Scene inactive"))
        )
        XCTAssertEqual(settledSnapshot.foregroundRestorationCount, 1)
    }

    func testDuplicateAndSemanticallyUnchangedRevisionAvoidActions()
        async throws
    {
        let client = RecordingMobileMediaGenerationActionClient()
        let owner = MobileMediaGenerationOwner(actionClient: client)
        let firstInput = try makeInput(
            revision: 1,
            sceneActivity: .active
        )
        _ = try await owner.apply(firstInput)

        let duplicate = try await owner.apply(firstInput)
        guard case .unchanged = duplicate else {
            return XCTFail("Expected an unchanged duplicate.")
        }
        let next = try await owner.apply(makeInput(
            revision: 2,
            sceneActivity: .active
        ))
        guard case .stateUpdated = next else {
            return XCTFail("Expected a state-only revision update.")
        }
        let applications = await client.applications()
        XCTAssertEqual(applications.count, 1)
    }

    func testRejectsConflictingRevisionAndGenerationContext()
        async throws
    {
        let client = RecordingMobileMediaGenerationActionClient()
        let owner = MobileMediaGenerationOwner(actionClient: client)
        let generation = try makeGeneration()
        _ = try await owner.apply(makeInput(
            generation: generation,
            revision: 2,
            sceneActivity: .active
        ))

        await XCTAssertThrowsErrorAsync {
            _ = try await owner.apply(self.makeInput(
                generation: generation,
                revision: 1,
                sceneActivity: .background
            ))
        } verify: {
            XCTAssertEqual(
                $0 as? MobileMediaGenerationOwnerError,
                .staleRevision
            )
        }

        let otherGeneration = try makeGeneration(media: 9, pictureInPicture: 1)
        var mismatch = try makeInput(
            generation: generation,
            revision: 3,
            sceneActivity: .active
        )
        mismatch = MobileMediaGenerationInput(
            ownership: mismatch.ownership,
            revision: mismatch.revision,
            continuityContext: makeContext(
                generation: otherGeneration,
                sceneActivity: .active
            ),
            foregroundBaseline: mismatch.foregroundBaseline
        )
        await XCTAssertThrowsErrorAsync {
            _ = try await owner.apply(mismatch)
        } verify: {
            XCTAssertEqual(
                $0 as? MobileMediaGenerationOwnerError,
                .generationContextMismatch
            )
        }
    }

    func testActionFailureRollsBackAndSameRevisionCanRetry()
        async throws
    {
        let client = RecordingMobileMediaGenerationActionClient()
        let owner = MobileMediaGenerationOwner(actionClient: client)
        _ = try await owner.apply(
            makeInput(revision: 1, sceneActivity: .active)
        )
        await client.failNextApplication()
        let background = try makeInput(
            revision: 2,
            sceneActivity: .background
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await owner.apply(background)
        } verify: {
            XCTAssertEqual(
                $0 as? RecordingMobileMediaGenerationActionClient.TestError,
                .injected
            )
        }
        let afterFailure = await owner.snapshot()
        XCTAssertEqual(afterFailure?.revision.rawValue, 1)
        XCTAssertEqual(afterFailure?.plan.stream, .running)

        let retried = try await owner.apply(background)
        XCTAssertEqual(
            try snapshot(from: retried).plan.stream,
            .paused(reason: .noActivePermittedMediaPath)
        )
    }

    func testConcurrentApplicationsReachClientInFIFOOrder()
        async throws
    {
        let client = RecordingMobileMediaGenerationActionClient()
        await client.blockNextApplication()
        let owner = MobileMediaGenerationOwner(actionClient: client)
        let firstInput = try makeInput(
            revision: 1,
            sceneActivity: .active
        )
        let secondInput = try makeInput(
            revision: 2,
            sceneActivity: .background
        )
        let first = Task {
            try await owner.apply(firstInput)
        }
        try await waitUntil {
            await client.applicationCount() == 1
        }
        let second = Task {
            try await owner.apply(secondInput)
        }
        await Task.yield()

        let blockedApplicationCount = await client.applicationCount()
        XCTAssertEqual(blockedApplicationCount, 1)
        await client.releaseBlockedApplication()
        _ = try await first.value
        _ = try await second.value

        let applications = await client.applications()
        XCTAssertEqual(applications.map(\.revision.rawValue), [1, 2])
        XCTAssertEqual(
            applications.map(\.transition),
            [.activate, .update]
        )
    }

    func testReplacementAndStopRejectLateOldGenerationCallbacks()
        async throws
    {
        let client = RecordingMobileMediaGenerationActionClient()
        let owner = MobileMediaGenerationOwner(actionClient: client)
        let oldGeneration = try makeGeneration()
        let newGeneration = try makeGeneration(
            media: oldGeneration.mediaGeneration + 1,
            pictureInPicture: 1
        )
        _ = try await owner.apply(makeInput(
            generation: oldGeneration,
            revision: 1,
            sceneActivity: .active
        ))
        let replacement = try await owner.apply(makeInput(
            generation: newGeneration,
            revision: 1,
            sceneActivity: .active
        ))
        let replacementSnapshot = try snapshot(from: replacement)
        XCTAssertEqual(
            replacementSnapshot.ownership.generation,
            newGeneration
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await owner.apply(self.makeInput(
                generation: oldGeneration,
                revision: 2,
                sceneActivity: .background
            ))
        } verify: {
            XCTAssertEqual(
                $0 as? MobileMediaGenerationOwnerError,
                .staleGeneration
            )
        }

        let stopRevision = try XCTUnwrap(
            MobileMediaGenerationRevision(rawValue: 2)
        )
        let stopped = try await owner.stop(
            ownership: replacementSnapshot.ownership,
            revision: stopRevision
        )
        XCTAssertEqual(try snapshot(from: stopped).phase, .stopped)
        let duplicateStop = try await owner.stop(
            ownership: replacementSnapshot.ownership,
            revision: stopRevision
        )
        guard case .unchanged = duplicateStop else {
            return XCTFail("Expected duplicate stop to be unchanged.")
        }
        let laterStopRevision = try XCTUnwrap(
            MobileMediaGenerationRevision(rawValue: 3)
        )
        let laterStop = try await owner.stop(
            ownership: replacementSnapshot.ownership,
            revision: laterStopRevision
        )
        guard case .stateUpdated = laterStop else {
            return XCTFail("Expected a later stop revision without new actions.")
        }

        let applications = await client.applications()
        XCTAssertEqual(
            applications.map(\.transition),
            [
                .activate,
                .replace(previous: MobileMediaGenerationOwnership(
                    sessionID: replacementSnapshot.ownership.sessionID,
                    generation: oldGeneration
                )),
                .stop
            ]
        )
    }

    private func snapshot(
        from outcome: MobileMediaGenerationPublicationOutcome
    ) throws -> MobileMediaGenerationSnapshot {
        switch outcome {
        case let .unchanged(snapshot),
             let .stateUpdated(snapshot),
             let .actionsApplied(snapshot):
            snapshot
        }
    }

    private func makeInput(
        generation: MobilePictureInPictureGeneration? = nil,
        revision: UInt64,
        sceneActivity: AppSceneActivity,
        actualMediaState: MobileContinuityActualMediaState? = nil,
        foregroundBaseline: RenderPolicy = .active
    ) throws -> MobileMediaGenerationInput {
        let generation = try generation ?? makeGeneration()
        let revision = try XCTUnwrap(
            MobileMediaGenerationRevision(rawValue: revision)
        )
        return MobileMediaGenerationInput(
            ownership: MobileMediaGenerationOwnership(
                sessionID: Self.sessionID,
                generation: generation
            ),
            revision: revision,
            continuityContext: makeContext(
                generation: generation,
                sceneActivity: sceneActivity,
                actualMediaState: actualMediaState
            ),
            foregroundBaseline: foregroundBaseline
        )
    }

    private func makeContext(
        generation: MobilePictureInPictureGeneration,
        sceneActivity: AppSceneActivity,
        isStreamActive: Bool = true,
        actualMediaState: MobileContinuityActualMediaState? = nil
    ) -> MobileContinuityContext {
        MobileContinuityContext(
            platform: .iPadOS,
            sceneActivity: sceneActivity,
            isStreamActive: isStreamActive,
            preferences: .defaults,
            capabilities: PlatformContinuityCapabilities(
                supportsAudioBackgroundMode: true,
                supportsPictureInPicture: true,
                hasAudioBackgroundModeDeclared: true
            ),
            activeGeneration: generation,
            actualMediaState: actualMediaState
        )
    }

    private func actualState(
        generation: MobilePictureInPictureGeneration,
        pictureInPictureLifecycle:
            MobilePictureInPictureLifecycle = .unprepared,
        sinkOperational: Bool = false,
        audioActive: Bool = false,
        audioPermitted: Bool = false
    ) -> MobileContinuityActualMediaState {
        MobileContinuityActualMediaState(
            generation: generation,
            pictureInPictureLifecycle: pictureInPictureLifecycle,
            isPictureInPictureFrameSinkOperational: sinkOperational,
            isAudioSessionActive: audioActive,
            isAudioContinuityPermitted: audioPermitted
        )
    }

    private func makeGeneration(
        media: UInt64 = 3,
        pictureInPicture: UInt64 = 5
    ) throws -> MobilePictureInPictureGeneration {
        try XCTUnwrap(MobilePictureInPictureGeneration(
            mediaGeneration: media,
            pictureInPictureGeneration: pictureInPicture
        ))
    }

    private func waitUntil(
        timeout: Duration = .seconds(2),
        condition: @escaping () async -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if await condition() { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting for asynchronous condition.")
    }

    private static let sessionID = UUID(
        uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD"
    )!
}

private actor RecordingMobileMediaGenerationActionClient:
    MobileMediaGenerationActionApplying
{
    enum TestError: Error, Equatable {
        case injected
    }

    private var recorded:
        [MobileMediaGenerationActionApplication] = []
    private var shouldFailNext = false
    private var shouldBlockNext = false
    private var blockedContinuation: CheckedContinuation<Void, Never>?

    func apply(
        _ application: MobileMediaGenerationActionApplication
    ) async throws {
        recorded.append(application)
        if shouldFailNext {
            shouldFailNext = false
            throw TestError.injected
        }
        if shouldBlockNext {
            shouldBlockNext = false
            await withCheckedContinuation { continuation in
                blockedContinuation = continuation
            }
        }
    }

    func applications() -> [MobileMediaGenerationActionApplication] {
        recorded
    }

    func applicationCount() -> Int {
        recorded.count
    }

    func failNextApplication() {
        shouldFailNext = true
    }

    func blockNextApplication() {
        shouldBlockNext = true
    }

    func releaseBlockedApplication() {
        blockedContinuation?.resume()
        blockedContinuation = nil
    }
}

private func XCTAssertThrowsErrorAsync(
    _ expression: () async throws -> Void,
    verify: (Error) -> Void
) async {
    do {
        try await expression()
        XCTFail("Expected expression to throw.")
    } catch {
        verify(error)
    }
}
