import CoreMedia
import CoreVideo
import Foundation
import XCTest

final class TVVisionPlatformPresentationCoordinatorTests: XCTestCase {
    func testCoordinatorPublishesOneRebrandedCompleteSnapshot() async throws {
        let recorder = TVVisionPresentationActionRecorder()
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder
        )
        let ownership = try makeOwnership()

        _ = await coordinator.activate(ownership)
        _ = await coordinator.applyScene(
            try makeSceneUpdate(ownership: ownership),
            ownership: ownership
        )
        _ = await coordinator.applyInput(
            try makeInput(ownership: ownership),
            controllerLeases: [],
            ownership: ownership
        )
        _ = await coordinator.applyDisplay(
            try makeDisplay(ownership: ownership),
            ownership: ownership
        )
        let outcome = await coordinator.applyAudioRoute(
            try makeAudio(ownership: ownership),
            ownership: ownership
        )

        guard case let .applied(snapshot) = outcome else {
            return XCTFail("Expected a complete platform snapshot")
        }
        let presentation = try XCTUnwrap(snapshot.presentation)
        XCTAssertEqual(snapshot.phase, .active)
        XCTAssertEqual(snapshot.revision.rawValue, 5)
        XCTAssertEqual(presentation.revision, snapshot.revision)
        XCTAssertEqual(presentation.sceneSurface.revision, snapshot.revision)
        XCTAssertEqual(
            presentation.inputCapabilities.revision,
            snapshot.revision
        )
        XCTAssertEqual(presentation.display.revision, snapshot.revision)
        XCTAssertEqual(presentation.audioRoute.revision, snapshot.revision)
        XCTAssertEqual(
            presentation.inputCapabilities.focusEligibility,
            .eligible
        )
        XCTAssertEqual(snapshot.diagnostics.count, 1)
        XCTAssertEqual(snapshot.diagnostics.first?.classification, .activated)

        let finalRecords = await recorder.records(for: snapshot.sequence)
        XCTAssertEqual(
            finalRecords.map(\.kind),
            [.scene, .display, .audioRoute, .input, .snapshot]
        )
    }

    func testIncompleteComponentsPublishInputUnavailable() async throws {
        let recorder = TVVisionPresentationActionRecorder()
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder
        )
        let ownership = try makeOwnership()
        _ = await coordinator.activate(ownership)

        let outcome = await coordinator.applyInput(
            try makeInput(ownership: ownership),
            controllerLeases: [],
            ownership: ownership
        )
        guard case let .applied(snapshot) = outcome else {
            return XCTFail("Expected incomplete input state to apply")
        }
        XCTAssertNil(snapshot.presentation)
        let inputEligibilities = await recorder.inputEligibilities
        XCTAssertEqual(
            inputEligibilities.last!,
            .ineligible(.inputUnavailable)
        )
    }

    func testSameInputRevisionAcceptsOnlyControllerLeaseChanges() async throws {
        let recorder = TVVisionPresentationActionRecorder()
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder
        )
        let ownership = try makeOwnership()
        let input = try makeInput(ownership: ownership)
        _ = await coordinator.activate(ownership)
        _ = await coordinator.applyInput(
            input,
            controllerLeases: [],
            ownership: ownership
        )
        let lease = try TVVisionControllerLease(
            platform: .tvOS,
            leaseGeneration: TVVisionGeneration(
                domain: .controller,
                rawValue: 1
            ),
            inputGeneration: ownership.inputGeneration,
            slot: TVVisionControllerSlot(0),
            profile: .extendedGamepad,
            capabilities: [.analogTriggers]
        )

        guard case let .applied(updated) = await coordinator.applyInput(
            input,
            controllerLeases: [lease],
            ownership: ownership
        ) else {
            return XCTFail("Expected a lease-only input update to apply")
        }
        XCTAssertEqual(updated.revision.rawValue, 3)

        let conflictingInput = try TVVisionInputCapabilitySnapshot(
            platform: .tvOS,
            revision: input.revision,
            inputGeneration: input.inputGeneration,
            supported: [.tvRemote],
            focusEligibility: .eligible
        )
        guard case let .failed(failed) = await coordinator.applyInput(
            conflictingInput,
            controllerLeases: [lease],
            ownership: ownership
        ) else {
            return XCTFail("Expected same-revision input conflict to fail closed")
        }
        XCTAssertEqual(failed.phase, .failed(.invalidComponent(.input)))
    }

    func testCoordinatorSerializesCallbacksWhileAnEffectIsSuspended()
        async throws
    {
        let recorder = TVVisionSuspendingPresentationActionRecorder(
            suspending: .scene
        )
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder
        )
        let ownership = try makeOwnership()
        _ = await coordinator.activate(ownership)
        let sceneUpdate = try makeSceneUpdate(ownership: ownership)
        let inputSnapshot = try makeInput(ownership: ownership)

        let sceneTask = Task {
            await coordinator.applyScene(
                sceneUpdate,
                ownership: ownership
            )
        }
        await recorder.waitUntilSuspended()
        let recordCountWhileSuspended = await recorder.records.count
        let inputTask = Task {
            await coordinator.applyInput(
                inputSnapshot,
                controllerLeases: [],
                ownership: ownership
            )
        }
        try await Task.sleep(for: .milliseconds(20))
        let suspendedRecords = await recorder.records
        XCTAssertEqual(suspendedRecords.count, recordCountWhileSuspended)

        await recorder.resume()
        guard case let .applied(sceneSnapshot) = await sceneTask.value,
              case let .applied(inputSnapshot) = await inputTask.value else {
            return XCTFail("Expected both serialized callbacks to apply")
        }
        XCTAssertLessThan(sceneSnapshot.sequence, inputSnapshot.sequence)
        let finalRecords = await recorder.records
        let sceneLastIndex = try XCTUnwrap(finalRecords.lastIndex(where: {
            $0.sequence == sceneSnapshot.sequence
        }))
        let inputFirstIndex = try XCTUnwrap(finalRecords.firstIndex(where: {
            $0.sequence == inputSnapshot.sequence
        }))
        XCTAssertLessThan(sceneLastIndex, inputFirstIndex)
    }

    func testCoordinatorPresentsCurrentDecodedFrameAndRejectsDuplicate()
        async throws
    {
        let recorder = TVVisionPresentationActionRecorder()
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder
        )
        let ownership = try makeOwnership()
        try await makeReady(coordinator, ownership: ownership)
        let delivery = try makeFrameDelivery(
            ownership: ownership,
            deliveryRevision: 1,
            frameID: 42
        )

        let first = await coordinator.receiveVideo(
            delivery,
            ownership: ownership
        )
        guard case let .applied(snapshot) = first else {
            return XCTFail("Expected the decoded frame to be applied")
        }
        XCTAssertEqual(
            snapshot.video.phase,
            .frameReady(decoderGeneration: 7, frameID: 42)
        )
        XCTAssertTrue(snapshot.video.isPresented)
        XCTAssertEqual(snapshot.video.lastDeliveryRevision, 1)
        let presentationRecords = await recorder.records(for: snapshot.sequence)
        XCTAssertEqual(presentationRecords.map(\.kind), [.video, .snapshot])

        let recordCount = await recorder.records.count
        let duplicate = await coordinator.receiveVideo(
            delivery,
            ownership: ownership
        )
        XCTAssertEqual(duplicate, .staleRevision)
        let recordsAfterDuplicate = await recorder.records
        XCTAssertEqual(recordsAfterDuplicate.count, recordCount)
    }

    func testValidScenePresentsBaselineSDRBeforeDisplayAndAudioProbe()
        async throws
    {
        let recorder = TVVisionPresentationActionRecorder()
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder
        )
        let ownership = try makeOwnership()
        _ = await coordinator.activate(ownership)
        _ = await coordinator.applyScene(
            try makeSceneUpdate(ownership: ownership),
            ownership: ownership
        )

        let decoderStarted = await coordinator.receiveVideo(
            makeDecoderStartedDelivery(
                ownership: ownership,
                deliveryRevision: 1,
                decoderGeneration: 7
            ),
            ownership: ownership
        )
        guard case let .applied(decoderSnapshot) = decoderStarted else {
            return XCTFail("Expected decoder start to apply")
        }
        XCTAssertEqual(
            decoderSnapshot.video.phase,
            .decoderReady(decoderGeneration: 7)
        )
        XCTAssertFalse(decoderSnapshot.video.isPresented)
        let decoderRecords = await recorder.records(
            for: decoderSnapshot.sequence
        )
        XCTAssertEqual(decoderRecords.map(\.kind), [.snapshot])

        let decoded = await coordinator.receiveVideo(
            try makeFrameDelivery(
                ownership: ownership,
                deliveryRevision: 2,
                frameID: 43,
                decoderGeneration: 7
            ),
            ownership: ownership
        )
        guard case let .applied(frameSnapshot) = decoded else {
            return XCTFail("Expected baseline SDR frame to apply")
        }
        XCTAssertNil(frameSnapshot.presentation)
        XCTAssertTrue(frameSnapshot.video.isPresented)
        XCTAssertEqual(
            frameSnapshot.video.phase,
            .frameReady(decoderGeneration: 7, frameID: 43)
        )
        let frameRecords = await recorder.records(for: frameSnapshot.sequence)
        XCTAssertEqual(frameRecords.map(\.kind), [.video, .snapshot])
    }

    func testGeometryRevisionResubmitsCurrentDecodedFrame() async throws {
        let recorder = TVVisionPresentationActionRecorder()
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder
        )
        let ownership = try makeOwnership()
        _ = await coordinator.activate(ownership)
        _ = await coordinator.applyScene(
            try makeSceneUpdate(ownership: ownership, sourceRevision: 1),
            ownership: ownership
        )
        _ = await coordinator.receiveVideo(
            try makeFrameDelivery(
                ownership: ownership,
                deliveryRevision: 1,
                frameID: 44
            ),
            ownership: ownership
        )

        let geometryChange = await coordinator.applyScene(
            try makeSceneUpdate(ownership: ownership, sourceRevision: 2),
            ownership: ownership
        )
        guard case let .applied(snapshot) = geometryChange else {
            return XCTFail("Expected semantic geometry change to apply")
        }
        XCTAssertTrue(snapshot.video.isPresented)
        XCTAssertEqual(
            snapshot.video.phase,
            .frameReady(decoderGeneration: 7, frameID: 44)
        )
        let records = await recorder.records(for: snapshot.sequence)
        XCTAssertEqual(
            records.map(\.kind),
            [.scene, .display, .audioRoute, .input, .video, .snapshot]
        )
    }

    func testCoordinatorRejectsOldDecoderAfterNewDecoderStarts() async throws {
        let recorder = TVVisionPresentationActionRecorder()
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder
        )
        let ownership = try makeOwnership()
        try await makeReady(coordinator, ownership: ownership)
        _ = await coordinator.receiveVideo(
            try makeFrameDelivery(
                ownership: ownership,
                deliveryRevision: 1,
                frameID: 1,
                decoderGeneration: 7
            ),
            ownership: ownership
        )
        let newDecoder = await coordinator.receiveVideo(
            makeDecoderStartedDelivery(
                ownership: ownership,
                deliveryRevision: 2,
                decoderGeneration: 8
            ),
            ownership: ownership
        )
        guard case let .applied(newDecoderSnapshot) = newDecoder else {
            return XCTFail("Expected the newer decoder to apply")
        }
        XCTAssertEqual(
            newDecoderSnapshot.video.phase,
            .decoderReady(decoderGeneration: 8)
        )

        let recordCount = await recorder.records.count
        let stale = await coordinator.receiveVideo(
            try makeFrameDelivery(
                ownership: ownership,
                deliveryRevision: 3,
                frameID: 2,
                decoderGeneration: 7
            ),
            ownership: ownership
        )
        XCTAssertEqual(stale, .staleRevision)
        let finalRecords = await recorder.records
        XCTAssertEqual(finalRecords.count, recordCount)
    }

    func testSceneCloseOrdersInputBeforeVideoClearAndSuppressesFrames()
        async throws
    {
        let recorder = TVVisionPresentationActionRecorder()
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder
        )
        let ownership = try makeOwnership()
        try await makeReady(coordinator, ownership: ownership)
        _ = await coordinator.receiveVideo(
            try makeFrameDelivery(
                ownership: ownership,
                deliveryRevision: 1,
                frameID: 1
            ),
            ownership: ownership
        )

        let closed = await coordinator.applyScene(
            try makeSceneUpdate(
                ownership: ownership,
                sourceRevision: 2,
                attached: false
            ),
            ownership: ownership
        )
        guard case let .applied(closedSnapshot) = closed else {
            return XCTFail("Expected the scene close to apply")
        }
        let closeRecords = await recorder.records(for: closedSnapshot.sequence)
        XCTAssertEqual(
            closeRecords.map(\.kind),
            [.input, .clearVideo, .scene, .display, .audioRoute, .snapshot]
        )
        XCTAssertFalse(closedSnapshot.video.isPresented)
        XCTAssertEqual(
            closedSnapshot.presentation?.sceneSurface.attachment,
            .detached
        )
        XCTAssertEqual(
            closedSnapshot.presentation?.inputCapabilities.focusEligibility,
            .ineligible(.detached)
        )
        XCTAssertEqual(
            closedSnapshot.diagnostics.last?.sequence,
            closedSnapshot.sequence
        )

        let suppressed = await coordinator.receiveVideo(
            try makeFrameDelivery(
                ownership: ownership,
                deliveryRevision: 2,
                frameID: 2
            ),
            ownership: ownership
        )
        guard case let .applied(suppressedSnapshot) = suppressed else {
            return XCTFail("Expected the current frame metadata to advance")
        }
        XCTAssertFalse(suppressedSnapshot.video.isPresented)
        let suppressedRecords = await recorder.records(
            for: suppressedSnapshot.sequence
        )
        XCTAssertEqual(suppressedRecords.map(\.kind), [.snapshot])
    }

    func testDisplayUnavailableClosesInputAndVideoUntilRecovery() async throws {
        let recorder = TVVisionPresentationActionRecorder()
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder
        )
        let ownership = try makeOwnership()
        try await makeReady(coordinator, ownership: ownership)
        _ = await coordinator.receiveVideo(
            try makeFrameDelivery(
                ownership: ownership,
                deliveryRevision: 1,
                frameID: 1
            ),
            ownership: ownership
        )

        let unavailable = await coordinator.applyDisplay(
            try makeDisplay(
                ownership: ownership,
                sourceRevision: 2,
                outputAvailable: false
            ),
            ownership: ownership
        )
        guard case let .applied(unavailableSnapshot) = unavailable else {
            return XCTFail("Expected unavailable display to apply")
        }
        XCTAssertFalse(unavailableSnapshot.video.isPresented)
        XCTAssertEqual(
            unavailableSnapshot.presentation?.inputCapabilities.focusEligibility,
            .ineligible(.inputUnavailable)
        )
        let unavailableRecords = await recorder.records(
            for: unavailableSnapshot.sequence
        )
        XCTAssertEqual(
            unavailableRecords.map(\.kind),
            [.input, .clearVideo, .scene, .display, .audioRoute, .snapshot]
        )

        let suppressed = await coordinator.receiveVideo(
            try makeFrameDelivery(
                ownership: ownership,
                deliveryRevision: 2,
                frameID: 2
            ),
            ownership: ownership
        )
        guard case let .applied(suppressedSnapshot) = suppressed else {
            return XCTFail("Expected current frame metadata to advance")
        }
        XCTAssertFalse(suppressedSnapshot.video.isPresented)

        let recovered = await coordinator.applyDisplay(
            try makeDisplay(
                ownership: ownership,
                sourceRevision: 3,
                outputAvailable: true
            ),
            ownership: ownership
        )
        guard case let .applied(recoveredSnapshot) = recovered else {
            return XCTFail("Expected display recovery to apply")
        }
        XCTAssertTrue(recoveredSnapshot.video.isPresented)
        XCTAssertEqual(
            recoveredSnapshot.video.phase,
            .frameReady(decoderGeneration: 7, frameID: 2)
        )
        XCTAssertEqual(
            recoveredSnapshot.presentation?.inputCapabilities.focusEligibility,
            .eligible
        )
    }

    func testReplacementTearsDownOldOwnershipAndRejectsLateCallbacks()
        async throws
    {
        let recorder = TVVisionPresentationActionRecorder()
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder
        )
        let firstOwnership = try makeOwnership(mediaGeneration: 1)
        try await makeReady(coordinator, ownership: firstOwnership)
        let foreignSession = try makeOwnership(
            sessionID: UUID(
                uuidString: "00000000-0000-0000-0000-000000000999"
            )!,
            mediaGeneration: 99,
            presentationGeneration: 99,
            inputGeneration: 99
        )
        let beforeForeign = await recorder.records.count
        let foreignOutcome = await coordinator.activate(foreignSession)
        XCTAssertEqual(foreignOutcome, .staleOwnership)
        let afterForeign = await recorder.records
        XCTAssertEqual(afterForeign.count, beforeForeign)
        let replacement = try makeOwnership(
            mediaGeneration: 2,
            presentationGeneration: 2,
            inputGeneration: 2
        )

        let outcome = await coordinator.activate(replacement)
        guard case let .applied(snapshot) = outcome else {
            return XCTFail("Expected replacement activation")
        }
        XCTAssertEqual(snapshot.ownership, replacement)
        XCTAssertEqual(snapshot.phase, .active)
        XCTAssertEqual(snapshot.teardownCount, 1)
        let records = await recorder.records
        let teardownIndex = try XCTUnwrap(
            records.lastIndex(where: {
                $0.ownership == firstOwnership && $0.kind == .teardown
            })
        )
        let activationIndex = try XCTUnwrap(
            records.lastIndex(where: {
                $0.ownership == replacement && $0.kind == .snapshot
            })
        )
        XCTAssertLessThan(teardownIndex, activationIndex)

        let countBeforeLateCallback = records.count
        let lateOutcome = await coordinator.applyDisplay(
            try makeDisplay(ownership: firstOwnership, sourceRevision: 2),
            ownership: firstOwnership
        )
        XCTAssertEqual(lateOutcome, .staleOwnership)
        let recordsAfterLateCallback = await recorder.records
        XCTAssertEqual(recordsAfterLateCallback.count, countBeforeLateCallback)
    }

    func testActionFailureFailsClosedAndStillRunsSharedTeardown()
        async throws
    {
        let recorder = TVVisionPresentationActionRecorder()
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder,
            diagnosticCapacity: 4
        )
        let ownership = try makeOwnership()
        _ = await coordinator.activate(ownership)
        _ = await coordinator.applyScene(
            try makeSceneUpdate(ownership: ownership),
            ownership: ownership
        )
        _ = await coordinator.applyInput(
            try makeInput(ownership: ownership),
            controllerLeases: [],
            ownership: ownership
        )
        _ = await coordinator.applyDisplay(
            try makeDisplay(ownership: ownership),
            ownership: ownership
        )
        await recorder.failNext(.audioRoute)

        let outcome = await coordinator.applyAudioRoute(
            try makeAudio(ownership: ownership),
            ownership: ownership
        )
        guard case let .failed(snapshot) = outcome else {
            return XCTFail("Expected action failure to fail closed")
        }
        XCTAssertEqual(snapshot.phase, .failed(.actionFailed(.audioRoute)))
        XCTAssertNil(snapshot.presentation)
        XCTAssertEqual(snapshot.teardownCount, 1)
        XCTAssertFalse(snapshot.video.isPresented)
        let failureRecords = await recorder.records
        XCTAssertTrue(failureRecords.contains(where: { $0.kind == .teardown }))
        XCTAssertEqual(
            snapshot.diagnostics.last?.classification,
            .failed(.actionFailed(.audioRoute))
        )
    }

    func testSemanticRevisionExhaustionFailsClosedWithoutPublishingActiveState()
        async throws
    {
        let recorder = TVVisionPresentationActionRecorder()
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder,
            initialRevision: TVVisionSemanticRevision(rawValue: .max)
        )
        let ownership = try makeOwnership()

        let outcome = await coordinator.activate(ownership)
        guard case let .failed(snapshot) = outcome else {
            return XCTFail("Expected revision exhaustion to fail closed")
        }
        XCTAssertEqual(snapshot.phase, .failed(.semanticRevisionExhausted))
        XCTAssertTrue(snapshot.isSemanticRevisionExhausted)
        XCTAssertEqual(snapshot.revision.rawValue, .max)
        XCTAssertEqual(snapshot.teardownCount, 1)
        XCTAssertNil(snapshot.presentation)
    }

    func testSequenceExhaustionFailsClosedWithoutPublishingActiveState()
        async throws
    {
        let recorder = TVVisionPresentationActionRecorder()
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder,
            initialSequence: .max
        )
        let ownership = try makeOwnership()

        let outcome = await coordinator.activate(ownership)
        guard case let .failed(snapshot) = outcome else {
            return XCTFail("Expected sequence exhaustion to fail closed")
        }
        XCTAssertEqual(snapshot.phase, .failed(.sequenceExhausted))
        XCTAssertTrue(snapshot.isSequenceExhausted)
        XCTAssertEqual(snapshot.sequence, .max)
        XCTAssertEqual(snapshot.teardownCount, 1)
        XCTAssertNil(snapshot.presentation)
    }

    func testStopIsIdempotentAndDiagnosticsRemainBounded() async throws {
        let recorder = TVVisionPresentationActionRecorder()
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder,
            diagnosticCapacity: 2
        )
        let ownership = try makeOwnership()
        _ = await coordinator.activate(ownership)

        let first = await coordinator.stop(
            ownership: ownership,
            reason: .remoteTermination
        )
        guard case let .applied(snapshot) = first else {
            return XCTFail("Expected the first stop to apply")
        }
        XCTAssertEqual(snapshot.phase, .stopped(.remoteTermination))
        XCTAssertEqual(snapshot.teardownCount, 1)
        XCTAssertLessThanOrEqual(snapshot.diagnostics.count, 2)
        let teardownEffects = await recorder.records.filter {
            $0.kind == .teardown
        }.count

        let repeated = await coordinator.stop(
            ownership: ownership,
            reason: .remoteTermination
        )
        XCTAssertEqual(repeated, .unchanged(snapshot))
        let finalTeardownEffects = await recorder.records.filter {
            $0.kind == .teardown
        }.count
        XCTAssertEqual(finalTeardownEffects, teardownEffects)
    }

    func testTerminalSnapshotFailureIsReflectedLocallyWithoutSecondTeardown()
        async throws
    {
        let recorder = TVVisionPresentationActionRecorder()
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: recorder
        )
        let ownership = try makeOwnership()
        _ = await coordinator.activate(ownership)
        await recorder.failNext(.snapshot)

        let first = await coordinator.stop(
            ownership: ownership,
            reason: .localStop
        )
        guard case let .failed(snapshot) = first else {
            return XCTFail("Expected terminal snapshot failure")
        }
        XCTAssertEqual(snapshot.phase, .failed(.actionFailed(.snapshot)))
        XCTAssertEqual(snapshot.teardownCount, 1)
        let localSnapshot = await coordinator.snapshot()
        XCTAssertEqual(localSnapshot, snapshot)

        let repeated = await coordinator.stop(
            ownership: ownership,
            reason: .localStop
        )
        XCTAssertEqual(repeated, .unchanged(snapshot))
        let teardownEffects = await recorder.records.filter {
            $0.kind == .teardown
        }.count
        XCTAssertEqual(teardownEffects, 1)
    }

    private func makeReady(
        _ coordinator: TVVisionPlatformPresentationCoordinator,
        ownership: TVVisionPresentationOwnership
    ) async throws {
        _ = await coordinator.activate(ownership)
        _ = await coordinator.applyScene(
            try makeSceneUpdate(ownership: ownership),
            ownership: ownership
        )
        _ = await coordinator.applyInput(
            try makeInput(ownership: ownership),
            controllerLeases: [],
            ownership: ownership
        )
        _ = await coordinator.applyDisplay(
            try makeDisplay(ownership: ownership),
            ownership: ownership
        )
        _ = await coordinator.applyAudioRoute(
            try makeAudio(ownership: ownership),
            ownership: ownership
        )
    }

    private func makeOwnership(
        sessionID: UUID = UUID(
            uuidString: "00000000-0000-0000-0000-000000000123"
        )!,
        mediaGeneration: UInt64 = 1,
        presentationGeneration: UInt64 = 1,
        inputGeneration: UInt64 = 1
    ) throws -> TVVisionPresentationOwnership {
        try TVVisionPresentationOwnership(
            platform: .tvOS,
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            presentationGeneration: TVVisionGeneration(
                domain: .presentation,
                rawValue: presentationGeneration
            ),
            inputGeneration: TVVisionGeneration(
                domain: .input,
                rawValue: inputGeneration
            )
        )
    }

    private func makeSceneUpdate(
        ownership: TVVisionPresentationOwnership,
        sourceRevision: UInt64 = 1,
        attached: Bool = true
    ) throws -> TVVisionStreamGeometryBindingUpdate {
        let revision = try TVVisionSemanticRevision(rawValue: sourceRevision)
        let surfaceGeneration = try TVVisionGeneration(
            domain: .surface,
            rawValue: 1
        )
        guard attached else {
            return TVVisionStreamGeometryBindingUpdate(
                platform: ownership.platform,
                surfaceGeneration: surfaceGeneration,
                revision: revision,
                status: .closed(.detached),
                binding: nil
            )
        }
        let geometry = try TVVisionSurfaceGeometry(
            platform: ownership.platform,
            surfaceGeneration: surfaceGeneration,
            viewBounds: TVVisionRect(x: 0, y: 0, width: 640, height: 360),
            windowBounds: TVVisionRect(x: 0, y: 0, width: 640, height: 360),
            safeAreaInsets: .zero,
            scale: 2
        )
        let scene = try TVVisionSceneSurfaceSnapshot(
            platform: ownership.platform,
            revision: revision,
            surfaceGeneration: surfaceGeneration,
            activity: .active,
            attachment: .attached,
            isVisible: true,
            geometry: geometry
        )
        let sourceSize = PixelSize(width: 1920, height: 1080)
        let coordinates = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: revision.rawValue,
            sourceSize: sourceSize,
            drawableSize: geometry.drawableSize,
            mode: .fit
        ))
        let binding = TVVisionStreamGeometryBindingSnapshot(
            platform: ownership.platform,
            surfaceGeneration: surfaceGeneration,
            revision: revision,
            sceneSurfaceSnapshot: scene,
            isFocusEligible: true,
            coordinateSnapshot: coordinates,
            inputReferenceSize: sourceSize
        )
        return TVVisionStreamGeometryBindingUpdate(
            platform: ownership.platform,
            surfaceGeneration: surfaceGeneration,
            revision: revision,
            status: .active,
            binding: binding
        )
    }

    private func makeInput(
        ownership: TVVisionPresentationOwnership,
        sourceRevision: UInt64 = 1
    ) throws -> TVVisionInputCapabilitySnapshot {
        try TVVisionInputCapabilitySnapshot(
            platform: ownership.platform,
            revision: TVVisionSemanticRevision(rawValue: sourceRevision),
            inputGeneration: ownership.inputGeneration,
            supported: [.tvRemote, .extendedGamepad],
            focusEligibility: .eligible
        )
    }

    private func makeDisplay(
        ownership: TVVisionPresentationOwnership,
        sourceRevision: UInt64 = 1,
        outputAvailable: Bool = true
    ) throws -> TVVisionDisplaySnapshot {
        try TVVisionDisplaySnapshot(
            platform: ownership.platform,
            revision: TVVisionSemanticRevision(rawValue: sourceRevision),
            displayGeneration: TVVisionGeneration(
                domain: .display,
                rawValue: 1
            ),
            isOutputAvailable: outputAvailable,
            headroomSource: outputAvailable ? .platformReported : .unavailable,
            currentEDRHeadroom: outputAvailable ? 1.5 : nil,
            potentialEDRHeadroom: outputAvailable ? 4 : nil,
            layerCapability:
                outputAvailable ? .preferredDynamicRange : .unavailable
        )
    }

    private func makeAudio(
        ownership: TVVisionPresentationOwnership,
        sourceRevision: UInt64 = 1
    ) throws -> TVVisionAudioRouteSnapshot {
        try TVVisionAudioRouteSnapshot(
            platform: ownership.platform,
            revision: TVVisionSemanticRevision(rawValue: sourceRevision),
            routeGeneration: TVVisionGeneration(
                domain: .audioRoute,
                rawValue: 1
            ),
            outputAvailable: true,
            currentOutputChannelCount: 2,
            maximumOutputChannelCount: 8,
            spatialSupport: .supported,
            platformStrategy: .environmentListener,
            headTrackingCapability: .entitlementRequired
        )
    }

    private func makeFrameDelivery(
        ownership: TVVisionPresentationOwnership,
        deliveryRevision: UInt64,
        frameID: UInt64,
        decoderGeneration: UInt64 = 7
    ) throws -> StreamVideoPresentationDelivery {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            64,
            64,
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            nil,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw TVVisionCoordinatorTestError.pixelBuffer(status)
        }
        let frame = DecodedVideoFrame(
            generation: decoderGeneration,
            frameID: frameID,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: .invalid,
            duration: .invalid,
            infoFlags: [],
            colorMetadata: .rec709VideoRange()
        )
        return .decodedFrame(
            ownership: StreamVideoPresentationDeliveryOwnership(
                sessionID: ownership.sessionID,
                mediaGeneration: ownership.mediaGeneration,
                revision: deliveryRevision
            ),
            frame: frame
        )
    }

    private func makeDecoderStartedDelivery(
        ownership: TVVisionPresentationOwnership,
        deliveryRevision: UInt64,
        decoderGeneration: UInt64
    ) -> StreamVideoPresentationDelivery {
        .decoderStarted(
            ownership: StreamVideoPresentationDeliveryOwnership(
                sessionID: ownership.sessionID,
                mediaGeneration: ownership.mediaGeneration,
                revision: deliveryRevision
            ),
            contract: StreamVideoDecoderPresentationContract(
                decoderGeneration: decoderGeneration,
                colorMetadata: .rec709VideoRange()
            )
        )
    }
}

private enum TVVisionCoordinatorTestError: Error {
    case pixelBuffer(CVReturn)
    case injectedActionFailure
}

private struct TVVisionPresentationActionRecord: Equatable, Sendable {
    let ownership: TVVisionPresentationOwnership
    let sequence: UInt64
    let kind: TVVisionPlatformPresentationEffectKind
}

private actor TVVisionPresentationActionRecorder:
    TVVisionPlatformPresentationActionApplying
{
    private(set) var records: [TVVisionPresentationActionRecord] = []
    private(set) var inputEligibilities: [TVVisionFocusEligibility?] = []
    private var failureKind: TVVisionPlatformPresentationEffectKind?

    func failNext(_ kind: TVVisionPlatformPresentationEffectKind) {
        failureKind = kind
    }

    func apply(
        _ application: TVVisionPlatformPresentationActionApplication
    ) async throws {
        records.append(TVVisionPresentationActionRecord(
            ownership: application.ownership,
            sequence: application.sequence,
            kind: application.effect.kind
        ))
        if case let .input(snapshot) = application.effect {
            inputEligibilities.append(snapshot?.focusEligibility)
        }
        if failureKind == application.effect.kind {
            failureKind = nil
            throw TVVisionCoordinatorTestError.injectedActionFailure
        }
    }

    func records(for sequence: UInt64) -> [TVVisionPresentationActionRecord] {
        records.filter { $0.sequence == sequence }
    }
}

private actor TVVisionSuspendingPresentationActionRecorder:
    TVVisionPlatformPresentationActionApplying
{
    private let suspendedKind: TVVisionPlatformPresentationEffectKind
    private(set) var records: [TVVisionPresentationActionRecord] = []
    private var didSuspend = false
    private var isSuspended = false
    private var suspensionWaiters: [CheckedContinuation<Void, Never>] = []
    private var resumeContinuation: CheckedContinuation<Void, Never>?

    init(suspending kind: TVVisionPlatformPresentationEffectKind) {
        suspendedKind = kind
    }

    func apply(
        _ application: TVVisionPlatformPresentationActionApplication
    ) async throws {
        records.append(TVVisionPresentationActionRecord(
            ownership: application.ownership,
            sequence: application.sequence,
            kind: application.effect.kind
        ))
        guard !didSuspend, application.effect.kind == suspendedKind else { return }
        didSuspend = true
        isSuspended = true
        let waiters = suspensionWaiters
        suspensionWaiters.removeAll()
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            resumeContinuation = continuation
        }
        isSuspended = false
    }

    func waitUntilSuspended() async {
        guard !isSuspended else { return }
        await withCheckedContinuation { continuation in
            suspensionWaiters.append(continuation)
        }
    }

    func resume() {
        resumeContinuation?.resume()
        resumeContinuation = nil
    }
}
