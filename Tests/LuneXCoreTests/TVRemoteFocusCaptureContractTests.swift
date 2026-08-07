import XCTest

final class TVRemoteFocusCaptureContractTests: XCTestCase {
    func testOwnershipSeparatesLocalFocusAndStreamCapture() throws {
        let inputGeneration = try generation(.input, 1)
        let eligible = try inputSnapshot(
            generation: inputGeneration,
            eligibility: .eligible
        )
        let overlay = try inputSnapshot(
            generation: inputGeneration,
            eligibility: .ineligible(.overlayVisible)
        )

        XCTAssertEqual(
            try TVRemoteCaptureOwnership.resolve(eligible),
            .stream(inputGeneration: inputGeneration)
        )
        XCTAssertEqual(
            try TVRemoteCaptureOwnership.resolve(overlay),
            .local(.overlayVisible)
        )
        XCTAssertEqual(
            try TVRemoteCaptureOwnership.resolve(inputSnapshot(
                generation: inputGeneration,
                eligibility: .eligible,
                supported: [.keyboard]
            )),
            .local(.remoteCapabilityUnavailable)
        )
    }

    func testVisionOSInputCannotOwnTVRemoteCapture() throws {
        let input = try TVVisionInputCapabilitySnapshot(
            platform: .visionOS,
            revision: semanticRevision(),
            inputGeneration: generation(.input, 1),
            supported: [.keyboard],
            focusEligibility: .eligible
        )

        XCTAssertThrowsError(try TVRemoteCaptureOwnership.resolve(input)) {
            XCTAssertEqual(
                $0 as? TVRemoteCaptureContractError,
                .platformMismatch
            )
        }
    }

    func testPressTokenIsNonzeroAndInputGenerationBranded() throws {
        let inputGeneration = try generation(.input, 2)
        XCTAssertEqual(
            try TVRemotePressToken(
                inputGeneration: inputGeneration,
                rawValue: 9
            ).rawValue,
            9
        )
        XCTAssertThrowsError(try TVRemotePressToken(
            inputGeneration: inputGeneration,
            rawValue: 0
        ))
        XCTAssertThrowsError(try TVRemotePressToken(
            inputGeneration: generation(.surface, 1),
            rawValue: 1
        ))
    }

    func testLocalNavigationReservesDirectionalPressWithoutRemoteEvent() throws {
        let input = try inputSnapshot(eligibility: .ineligible(.overlayVisible))
        let state = try TVRemoteCaptureState(input: input)
        let token = try pressToken(input.inputGeneration, 1)
        let transition = try state.reducing(.pressBegan(
            token: token,
            button: .up
        ))

        XCTAssertEqual(transition.state, state)
        XCTAssertEqual(transition.effects, [
            .reserveLocally(button: .up, reason: .overlayVisible)
        ])
    }

    func testStreamPressBeginEndAndCancelAreBalanced() throws {
        let input = try inputSnapshot()
        let initial = try TVRemoteCaptureState(input: input)
        let select = try pressToken(input.inputGeneration, 1)
        let playPause = try pressToken(input.inputGeneration, 2)

        let selected = try initial.reducing(.pressBegan(
            token: select,
            button: .select
        ))
        XCTAssertEqual(selected.effects, [
            .sendRemote(TVRemoteInputEvent(button: .select, isDown: true))
        ])
        let ended = try selected.state.reducing(.pressEnded(token: select))
        XCTAssertEqual(ended.effects, [
            .sendRemote(TVRemoteInputEvent(button: .select, isDown: false))
        ])
        let playing = try ended.state.reducing(.pressBegan(
            token: playPause,
            button: .playPause
        ))
        let cancelled = try playing.state.reducing(
            .pressCancelled(token: playPause)
        )
        XCTAssertEqual(cancelled.effects, [
            .sendRemote(TVRemoteInputEvent(button: .playPause, isDown: false))
        ])
        XCTAssertTrue(cancelled.state.activePresses.isEmpty)
    }

    func testMenuAndSystemCommandsAlwaysRemainLocal() throws {
        let input = try inputSnapshot()
        let state = try TVRemoteCaptureState(input: input)
        let token = try pressToken(input.inputGeneration, 1)

        let menuEffects = try state.reducing(
            .pressBegan(token: token, button: .menu)
        ).effects
        XCTAssertEqual(
            menuEffects,
            [.handleReserved(
                command: .backMenu,
                disposition: .showOverlayOrExitCapture
            )]
        )
        XCTAssertFalse(containsRemoteDelivery(menuEffects))
        for command in TVRemoteReservedCommand.allCases {
            let effects = try state.reducing(.reserved(command)).effects
            let disposition = TVRemoteReservedDisposition.resolve(command)
            XCTAssertEqual(
                effects,
                [.handleReserved(
                    command: command,
                    disposition: disposition
                )]
            )
            XCTAssertFalse(
                containsRemoteDelivery(effects),
                "Reserved command \(command) must not reach the remote host"
            )
        }
        XCTAssertTrue(state.activePresses.isEmpty)
    }

    func testReservedCommandRuntimeStateIsTypedAndBounded() {
        XCTAssertEqual(
            TVRemoteReservedCommandRuntimeState.resolve(.backMenu),
            .handledLocally(
                command: .backMenu,
                disposition: .showOverlayOrExitCapture
            )
        )
        for command in [
            TVRemoteReservedCommand.home,
            .volumeUp,
            .volumeDown,
            .capture,
            .power
        ] {
            XCTAssertEqual(
                TVRemoteReservedCommandRuntimeState.resolve(command),
                .unavailable(
                    command: command,
                    disposition: .deferToSystem,
                    reason: .systemOwned
                )
            )
        }
        XCTAssertEqual(
            TVRemoteReservedCommandRuntimeState.resolve(.unsupported),
            .unavailable(
                command: .unsupported,
                disposition: .ignoreLocally,
                reason: .unsupportedInteraction
            )
        )
    }

    func testFocusLossClosesAdmissionReleasesReverseAndRestoresFocus() throws {
        let input = try inputSnapshot()
        let first = try pressToken(input.inputGeneration, 1)
        let second = try pressToken(input.inputGeneration, 2)
        var state = try TVRemoteCaptureState(input: input)
        state = try state.reducing(.pressBegan(
            token: first,
            button: .left
        )).state
        state = try state.reducing(.pressBegan(
            token: second,
            button: .select
        )).state

        let transition = try state.reducing(.updateInput(inputSnapshot(
            generation: input.inputGeneration,
            eligibility: .ineligible(.notFocused)
        )))

        XCTAssertEqual(transition.effects, [
            .closeRemoteAdmission(inputGeneration: input.inputGeneration),
            .sendRemote(TVRemoteInputEvent(button: .select, isDown: false)),
            .sendRemote(TVRemoteInputEvent(button: .left, isDown: false)),
            .awaitRemoteReleaseBarrier(inputGeneration: input.inputGeneration),
            .restoreLocalFocus(.notFocused)
        ])
        XCTAssertEqual(transition.state.ownership, .local(.notFocused))
        XCTAssertTrue(transition.state.activePresses.isEmpty)
    }

    func testGenerationReplacementReleasesBeforeOpeningNewAdmission() throws {
        let oldInput = try inputSnapshot(generation: generation(.input, 1))
        let newInput = try inputSnapshot(generation: generation(.input, 2))
        let oldToken = try pressToken(oldInput.inputGeneration, 1)
        var state = try TVRemoteCaptureState(input: oldInput)
        state = try state.reducing(.pressBegan(
            token: oldToken,
            button: .right
        )).state

        let replaced = try state.reducing(.updateInput(newInput))
        XCTAssertEqual(replaced.effects, [
            .closeRemoteAdmission(inputGeneration: oldInput.inputGeneration),
            .sendRemote(TVRemoteInputEvent(button: .right, isDown: false)),
            .awaitRemoteReleaseBarrier(inputGeneration: oldInput.inputGeneration),
            .openRemoteAdmission(inputGeneration: newInput.inputGeneration)
        ])
        XCTAssertThrowsError(try replaced.state.reducing(
            .pressEnded(token: oldToken)
        )) { error in
            XCTAssertEqual(
                error as? TVRemoteCaptureContractError,
                .pressGenerationMismatch
            )
        }
    }

    func testDuplicateTokenButtonAndLateEndAreDeterministic() throws {
        let input = try inputSnapshot()
        let first = try pressToken(input.inputGeneration, 1)
        let second = try pressToken(input.inputGeneration, 2)
        let state = try TVRemoteCaptureState(input: input)
        let active = try state.reducing(.pressBegan(
            token: first,
            button: .up
        )).state

        XCTAssertThrowsError(try active.reducing(.pressBegan(
            token: first,
            button: .down
        )))
        XCTAssertThrowsError(try active.reducing(.pressBegan(
            token: second,
            button: .up
        )))
        XCTAssertEqual(
            try state.reducing(.pressEnded(token: first)).effects,
            [.ignoreUnownedPress(first)]
        )
    }

    func testControllerSnapshotChecksSlotMaskButtonsAndMicroState() throws {
        let lease = try controllerLease(slot: 2, lease: 1)
        let state = remoteState(
            slot: 2,
            mask: 1 << 2,
            buttons: [.a]
        )
        XCTAssertNoThrow(try TVControllerInputSnapshot(
            lease: lease,
            supportedButtons: [.a, .b],
            state: state
        ))
        XCTAssertThrowsError(try TVControllerInputSnapshot(
            lease: lease,
            supportedButtons: [.b],
            state: state
        ))
        XCTAssertThrowsError(try TVControllerInputSnapshot(
            lease: lease,
            supportedButtons: [.a],
            state: remoteState(slot: 2, mask: 0, buttons: [.a])
        ))

        let micro = try controllerLease(
            slot: 0,
            lease: 2,
            profile: .microGamepad
        )
        XCTAssertThrowsError(try TVControllerInputSnapshot(
            lease: micro,
            supportedButtons: [.a],
            state: RemoteControllerState(
                controllerIndex: 0,
                activeGamepadMask: 1,
                buttons: [.a],
                leftTrigger: 0,
                rightTrigger: 0,
                leftStickX: 1,
                leftStickY: 0,
                rightStickX: 0,
                rightStickY: 0
            )
        ))
    }

    func testControllerRosterBuildsExactMaskAndStableSlotOrder() throws {
        let inputGeneration = try generation(.input, 1)
        let first = try controllerSnapshot(
            slot: 3,
            lease: 1,
            mask: 0b1001
        )
        let second = try controllerSnapshot(
            slot: 0,
            lease: 2,
            mask: 0b1001
        )
        let roster = try TVControllerRosterSnapshot(
            inputGeneration: inputGeneration,
            controllers: [first, second]
        )

        XCTAssertEqual(roster.activeGamepadMask, 0b1001)
        XCTAssertEqual(roster.controllers.map(\.lease.slot.rawValue), [0, 3])
        XCTAssertThrowsError(try TVControllerRosterSnapshot(
            inputGeneration: inputGeneration,
            controllers: [first, try controllerSnapshot(
                slot: 0,
                lease: 2,
                mask: 1
            )]
        ))
    }

    func testControllerRosterAcceptsSixteenSlotsAndRejectsDuplicates() throws {
        let inputGeneration = try generation(.input, 1)
        let fullMask = UInt16.max
        let controllers = try (0..<TVVisionControllerSlot.maximumCount).map {
            try controllerSnapshot(
                slot: $0,
                lease: UInt64($0 + 1),
                mask: fullMask
            )
        }
        let roster = try TVControllerRosterSnapshot(
            inputGeneration: inputGeneration,
            controllers: controllers
        )

        XCTAssertEqual(roster.controllers.count, 16)
        XCTAssertEqual(roster.activeGamepadMask, fullMask)
        XCTAssertThrowsError(try TVControllerRosterSnapshot(
            inputGeneration: inputGeneration,
            controllers: [controllers[0], controllers[0]]
        )) { error in
            XCTAssertEqual(
                error as? TVRemoteCaptureContractError,
                .duplicateControllerSlot(0)
            )
        }
        let duplicateLease = try controllerSnapshot(
            slot: 1,
            lease: 1,
            mask: 0b11
        )
        let slotZero = try controllerSnapshot(
            slot: 0,
            lease: 1,
            mask: 0b11
        )
        XCTAssertThrowsError(try TVControllerRosterSnapshot(
            inputGeneration: inputGeneration,
            controllers: [slotZero, duplicateLease]
        )) { error in
            XCTAssertEqual(
                error as? TVRemoteCaptureContractError,
                .duplicateControllerLease(1)
            )
        }
    }

    func testFeedbackRequestValidatesPayloadAndRequiredCapability() throws {
        let lease = try controllerLease(
            slot: 0,
            lease: 1,
            capabilities: [.rumble, .gyroscope]
        )
        let rumble = try TVControllerFeedbackRequest(
            lease: lease,
            payload: .rumble(lowFrequency: 0.25, highFrequency: 1)
        )
        let motion = try TVControllerFeedbackRequest(
            lease: lease,
            payload: .motionRate(type: .gyroscope, reportRateHz: 120)
        )

        XCTAssertEqual(rumble.requiredCapability, .rumble)
        XCTAssertEqual(motion.requiredCapability, .gyroscope)
        XCTAssertThrowsError(try TVControllerFeedbackRequest(
            lease: lease,
            payload: .rumble(lowFrequency: .nan, highFrequency: 1)
        ))
        XCTAssertThrowsError(try TVControllerFeedbackRequest(
            lease: lease,
            payload: .motionRate(type: .gyroscope, reportRateHz: 1_001)
        ))
    }

    func testFeedbackResolverRequiresCurrentLeaseAndCapability() throws {
        let lease = try controllerLease(
            slot: 0,
            lease: 1,
            capabilities: [.rumble]
        )
        let snapshot = try TVControllerInputSnapshot(
            lease: lease,
            supportedButtons: .standard,
            state: remoteState(slot: 0, mask: 1)
        )
        let roster = try TVControllerRosterSnapshot(
            inputGeneration: lease.inputGeneration,
            controllers: [snapshot]
        )
        let rumble = try TVControllerFeedbackRequest(
            lease: lease,
            payload: .rumble(lowFrequency: 0.5, highFrequency: 0.5)
        )
        XCTAssertEqual(
            TVControllerFeedbackResolver.resolve(rumble, roster: roster),
            .apply(rumble)
        )

        let led = try TVControllerFeedbackRequest(
            lease: lease,
            payload: .led(red: 1, green: 2, blue: 3)
        )
        XCTAssertEqual(
            TVControllerFeedbackResolver.resolve(led, roster: roster),
            .unavailable(.unsupportedCapability)
        )
        let replacement = try controllerLease(
            slot: 0,
            lease: 2,
            capabilities: [.rumble]
        )
        let stale = try TVControllerFeedbackRequest(
            lease: replacement,
            payload: .rumble(lowFrequency: 0.5, highFrequency: 0.5)
        )
        XCTAssertEqual(
            TVControllerFeedbackResolver.resolve(stale, roster: roster),
            .unavailable(.staleLease)
        )
        let futureGeneration = try generation(.input, 2)
        let replacedGenerationLease = try controllerLease(
            slot: 0,
            lease: 1,
            capabilities: [.rumble],
            inputGeneration: futureGeneration
        )
        let replacedGenerationRequest = try TVControllerFeedbackRequest(
            lease: replacedGenerationLease,
            payload: .rumble(lowFrequency: 0.5, highFrequency: 0.5)
        )
        XCTAssertEqual(
            TVControllerFeedbackResolver.resolve(
                replacedGenerationRequest,
                roster: roster
            ),
            .unavailable(.staleInputGeneration)
        )
    }

    func testReleasePlanOrdersHandlersPressesBarrierAndFocus() throws {
        let inputGeneration = try generation(.input, 1)
        let first = TVRemoteActivePress(
            token: try pressToken(inputGeneration, 1),
            button: .left
        )
        let second = TVRemoteActivePress(
            token: try pressToken(inputGeneration, 2),
            button: .select
        )
        let lease0 = try controllerLease(slot: 0, lease: 1)
        let lease2 = try controllerLease(slot: 2, lease: 2)
        let plan = try TVPlatformInputReleasePlan(
            inputGeneration: inputGeneration,
            activePresses: [first, second],
            controllerLeases: [lease2, lease0],
            restoreReason: .overlayVisible
        )

        XCTAssertEqual(plan.effects, [
            .closeRemoteAdmission(inputGeneration: inputGeneration),
            .removeControllerHandlers([lease0, lease2]),
            .sendRemote(TVRemoteInputEvent(button: .select, isDown: false)),
            .sendRemote(TVRemoteInputEvent(button: .left, isDown: false)),
            .awaitRemoteReleaseBarrier(inputGeneration: inputGeneration),
            .restoreLocalFocus(.overlayVisible)
        ])
    }

    func testReleasePlanAcceptsMaximumControllerCapacityBeforeBarrier() throws {
        let inputGeneration = try generation(.input, 1)
        let leases = try (0..<TVVisionControllerSlot.maximumCount).reversed().map {
            try controllerLease(slot: $0, lease: UInt64($0 + 1))
        }
        let plan = try TVPlatformInputReleasePlan(
            inputGeneration: inputGeneration,
            activePresses: [],
            controllerLeases: leases,
            restoreReason: nil
        )
        let sortedLeases = leases.sorted { $0.slot < $1.slot }

        XCTAssertEqual(plan.effects, [
            .closeRemoteAdmission(inputGeneration: inputGeneration),
            .removeControllerHandlers(sortedLeases),
            .awaitRemoteReleaseBarrier(inputGeneration: inputGeneration)
        ])
        XCTAssertEqual(
            sortedLeases.map(\.slot.rawValue),
            Array(0..<UInt8(TVVisionControllerSlot.maximumCount))
        )
    }

    func testReleasePlanRejectsInvalidPressAndControllerOwnership() throws {
        let inputGeneration = try generation(.input, 1)
        let otherInputGeneration = try generation(.input, 2)
        let stalePress = TVRemoteActivePress(
            token: try pressToken(otherInputGeneration, 1),
            button: .select
        )
        XCTAssertThrowsError(try TVPlatformInputReleasePlan(
            inputGeneration: inputGeneration,
            activePresses: [stalePress],
            controllerLeases: [],
            restoreReason: nil
        )) { error in
            XCTAssertEqual(
                error as? TVRemoteCaptureContractError,
                .pressGenerationMismatch
            )
        }

        let press = TVRemoteActivePress(
            token: try pressToken(inputGeneration, 1),
            button: .select
        )
        XCTAssertThrowsError(try TVPlatformInputReleasePlan(
            inputGeneration: inputGeneration,
            activePresses: [press, press],
            controllerLeases: [],
            restoreReason: nil
        )) { error in
            XCTAssertEqual(
                error as? TVRemoteCaptureContractError,
                .invalidActivePressState
            )
        }

        let visionLease = try controllerLease(
            slot: 0,
            lease: 1,
            platform: .visionOS
        )
        XCTAssertThrowsError(try TVPlatformInputReleasePlan(
            inputGeneration: inputGeneration,
            activePresses: [],
            controllerLeases: [visionLease],
            restoreReason: nil
        )) { error in
            XCTAssertEqual(
                error as? TVRemoteCaptureContractError,
                .controllerPlatformMismatch
            )
        }

        let staleController = try controllerLease(
            slot: 0,
            lease: 1,
            inputGeneration: otherInputGeneration
        )
        XCTAssertThrowsError(try TVPlatformInputReleasePlan(
            inputGeneration: inputGeneration,
            activePresses: [],
            controllerLeases: [staleController],
            restoreReason: nil
        )) { error in
            XCTAssertEqual(
                error as? TVRemoteCaptureContractError,
                .controllerInputGenerationMismatch
            )
        }
    }

    @MainActor
    func testSurfacePressOwnerDeliversBalancedBeginEndAndCancel() async throws {
        let recorder = TVRemoteSurfaceDeliveryRecorder()
        let owner = TVRemoteSurfacePressCaptureOwner { generation, event in
            try recorder.deliver(generation: generation, event: event)
        }
        let surface = try generation(.surface, 1)
        let inputGeneration = try generation(.input, 1)
        try owner.update(
            surfaceGeneration: surface,
            input: inputSnapshot(generation: inputGeneration)
        )
        XCTAssertEqual(owner.disposition(for: surface), .captured)

        XCTAssertEqual(
            owner.handle(try surfacePress(surface, 1, .select, .began)),
            .captured
        )
        XCTAssertEqual(
            owner.handle(try surfacePress(surface, 1, .select, .ended)),
            .captured
        )
        XCTAssertEqual(
            owner.handle(try surfacePress(surface, 2, .playPause, .began)),
            .captured
        )
        XCTAssertEqual(
            owner.handle(try surfacePress(surface, 2, .playPause, .cancelled)),
            .captured
        )
        XCTAssertEqual(
            owner.handle(try surfacePress(surface, 3, .menu, .began)),
            .local
        )

        await owner.waitForPendingDeliveries()
        XCTAssertEqual(recorder.events, [
            TVRemoteInputEvent(button: .select, isDown: true),
            TVRemoteInputEvent(button: .select, isDown: false),
            TVRemoteInputEvent(button: .playPause, isDown: true),
            TVRemoteInputEvent(button: .playPause, isDown: false)
        ])
        XCTAssertTrue(recorder.generations.allSatisfy { $0 == inputGeneration })

        try owner.update(
            surfaceGeneration: surface,
            input: inputSnapshot(
                generation: inputGeneration,
                eligibility: .ineligible(.overlayVisible)
            )
        )
        XCTAssertEqual(owner.disposition(for: surface), .local)
        XCTAssertEqual(
            owner.handle(try surfacePress(surface, 4, .up, .began)),
            .local
        )
    }

    @MainActor
    func testSurfacePressOwnerReleasesReplacementAndRejectsLateSurface()
        async throws {
        let recorder = TVRemoteSurfaceDeliveryRecorder()
        let owner = TVRemoteSurfacePressCaptureOwner { generation, event in
            try recorder.deliver(generation: generation, event: event)
        }
        let firstSurface = try generation(.surface, 1)
        let replacementSurface = try generation(.surface, 2)
        try owner.update(
            surfaceGeneration: firstSurface,
            input: inputSnapshot()
        )
        XCTAssertEqual(
            owner.handle(try surfacePress(firstSurface, 1, .left, .began)),
            .captured
        )

        try owner.update(
            surfaceGeneration: replacementSurface,
            input: inputSnapshot()
        )
        XCTAssertEqual(
            owner.handle(try surfacePress(firstSurface, 1, .left, .ended)),
            .local
        )
        XCTAssertEqual(
            owner.handle(try surfacePress(replacementSurface, 1, .right, .began)),
            .captured
        )
        XCTAssertEqual(
            owner.handle(try surfacePress(replacementSurface, 1, .right, .ended)),
            .captured
        )

        await owner.waitForPendingDeliveries()
        XCTAssertEqual(recorder.events, [
            TVRemoteInputEvent(button: .left, isDown: true),
            TVRemoteInputEvent(button: .left, isDown: false),
            TVRemoteInputEvent(button: .right, isDown: true),
            TVRemoteInputEvent(button: .right, isDown: false)
        ])
    }

    @MainActor
    func testSurfacePressOwnerFailsClosedAfterDeliveryFailure() async throws {
        let recorder = TVRemoteSurfaceDeliveryRecorder(failuresRemaining: 1)
        let owner = TVRemoteSurfacePressCaptureOwner { generation, event in
            try recorder.deliver(generation: generation, event: event)
        }
        let surface = try generation(.surface, 1)
        try owner.update(
            surfaceGeneration: surface,
            input: inputSnapshot()
        )

        XCTAssertEqual(
            owner.handle(try surfacePress(surface, 1, .select, .began)),
            .captured
        )
        await owner.waitForPendingDeliveries()
        XCTAssertEqual(recorder.attemptedEvents, [
            TVRemoteInputEvent(button: .select, isDown: true),
            TVRemoteInputEvent(button: .select, isDown: false)
        ])
        XCTAssertEqual(recorder.events, [
            TVRemoteInputEvent(button: .select, isDown: false)
        ])
        XCTAssertEqual(
            owner.handle(try surfacePress(surface, 2, .right, .began)),
            .local
        )
    }

    @MainActor
    func testSurfacePressOwnerRetriesFailedReleaseAndDropsQueuedDown()
        async throws {
        let recorder = TVRemoteSurfaceDeliveryRecorder(failingAttempts: [2])
        let owner = TVRemoteSurfacePressCaptureOwner { generation, event in
            try recorder.deliver(generation: generation, event: event)
        }
        let surface = try generation(.surface, 1)
        try owner.update(
            surfaceGeneration: surface,
            input: inputSnapshot()
        )

        XCTAssertEqual(
            owner.handle(try surfacePress(surface, 1, .select, .began)),
            .captured
        )
        XCTAssertEqual(
            owner.handle(try surfacePress(surface, 1, .select, .ended)),
            .captured
        )
        XCTAssertEqual(
            owner.handle(try surfacePress(surface, 2, .right, .began)),
            .captured
        )

        await owner.waitForPendingDeliveries()
        XCTAssertEqual(recorder.attemptedEvents, [
            TVRemoteInputEvent(button: .select, isDown: true),
            TVRemoteInputEvent(button: .select, isDown: false),
            TVRemoteInputEvent(button: .select, isDown: false),
            TVRemoteInputEvent(button: .right, isDown: false)
        ])
        XCTAssertEqual(recorder.events, [
            TVRemoteInputEvent(button: .select, isDown: true),
            TVRemoteInputEvent(button: .select, isDown: false),
            TVRemoteInputEvent(button: .right, isDown: false)
        ])
        XCTAssertFalse(recorder.attemptedEvents.contains(
            TVRemoteInputEvent(button: .right, isDown: true)
        ))
        XCTAssertEqual(owner.disposition(for: surface), .local)
    }

    func testFocusHandoffWaitsForFreshSurfaceFocusAndKeepsLocalUIOwned()
        throws {
        let firstRevision = try TVVisionSemanticRevision(rawValue: 1)
        let secondRevision = try TVVisionSemanticRevision(rawValue: 2)
        let thirdRevision = try TVVisionSemanticRevision(rawValue: 3)
        let firstSurface = try generation(.surface, 1)
        let replacementSurface = try generation(.surface, 2)
        let firstStamp = try TVRemoteSurfaceFocusStamp(
            surfaceGeneration: firstSurface,
            revision: firstRevision
        )
        let secondStamp = try TVRemoteSurfaceFocusStamp(
            surfaceGeneration: firstSurface,
            revision: secondRevision
        )
        let thirdStamp = try TVRemoteSurfaceFocusStamp(
            surfaceGeneration: firstSurface,
            revision: thirdRevision
        )
        let replacementStamp = try TVRemoteSurfaceFocusStamp(
            surfaceGeneration: replacementSurface,
            revision: firstRevision
        )
        var state = TVRemoteFocusHandoffState.localNavigation

        XCTAssertEqual(
            state.resolving(actualEligibility: .eligible),
            .ineligible(.notFocused)
        )
        state = state.selectingStreamNavigation(
            true,
            currentGeometryStamp: nil
        ).settingWorkspaceVisible(
            true,
            currentGeometryStamp: nil
        )
        XCTAssertEqual(
            state.resolving(actualEligibility: .eligible),
            .ineligible(.overlayVisible)
        )

        state = state.settingOverlayVisible(
            false,
            currentGeometryStamp: firstStamp
        )
        XCTAssertEqual(
            state.resolving(actualEligibility: .eligible),
            .ineligible(.notFocused)
        )
        state = state.observingSurfaceFocus(
            stamp: firstStamp,
            actualEligibility: .eligible
        )
        XCTAssertEqual(
            state.resolving(actualEligibility: .eligible),
            .ineligible(.notFocused)
        )
        state = state.observingSurfaceFocus(
            stamp: secondStamp,
            actualEligibility: .ineligible(.notFocused)
        )
        XCTAssertEqual(
            state.resolving(actualEligibility: .eligible),
            .ineligible(.notFocused)
        )
        state = state.observingSurfaceFocus(
            stamp: thirdStamp,
            actualEligibility: .eligible
        )
        XCTAssertEqual(
            state.resolving(actualEligibility: .eligible),
            .eligible
        )
        state = state.settingOverlayVisible(
            false,
            currentGeometryStamp: thirdStamp
        )
        XCTAssertEqual(
            state.resolving(actualEligibility: .eligible),
            .eligible
        )

        state = state.settingOverlayVisible(
            true,
            currentGeometryStamp: thirdStamp
        )
        XCTAssertEqual(
            state.resolving(actualEligibility: .eligible),
            .ineligible(.overlayVisible)
        )
        state = state.settingOverlayVisible(
            false,
            currentGeometryStamp: thirdStamp
        ).observingSurfaceFocus(
            stamp: replacementStamp,
            actualEligibility: .eligible
        )
        XCTAssertEqual(
            state.resolving(actualEligibility: .eligible),
            .eligible
        )
        state = state.selectingStreamNavigation(
            false,
            currentGeometryStamp: replacementStamp
        )
        XCTAssertEqual(
            state.resolving(actualEligibility: .eligible),
            .ineligible(.notFocused)
        )
    }

    @MainActor
    func testSurfacePressOwnerReleasesForOverlayAndReopensAfterFocus()
        async throws {
        let recorder = TVRemoteSurfaceDeliveryRecorder()
        let owner = TVRemoteSurfacePressCaptureOwner { generation, event in
            try recorder.deliver(generation: generation, event: event)
        }
        let surface = try generation(.surface, 1)
        let inputGeneration = try generation(.input, 1)
        try owner.update(
            surfaceGeneration: surface,
            input: inputSnapshot(
                generation: inputGeneration,
                revision: 1
            )
        )
        XCTAssertEqual(
            owner.handle(try surfacePress(surface, 1, .left, .began)),
            .captured
        )

        try owner.update(
            surfaceGeneration: surface,
            input: inputSnapshot(
                generation: inputGeneration,
                eligibility: .ineligible(.overlayVisible),
                revision: 2
            )
        )
        XCTAssertEqual(owner.disposition(for: surface), .local)
        await owner.waitForPendingDeliveries()
        XCTAssertEqual(recorder.events, [
            TVRemoteInputEvent(button: .left, isDown: true),
            TVRemoteInputEvent(button: .left, isDown: false)
        ])

        try owner.update(
            surfaceGeneration: surface,
            input: inputSnapshot(
                generation: inputGeneration,
                revision: 3
            )
        )
        XCTAssertEqual(owner.disposition(for: surface), .captured)
    }

    private func inputSnapshot(
        generation: TVVisionGeneration? = nil,
        eligibility: TVVisionFocusEligibility = .eligible,
        supported: Set<TVVisionInputCapability> = [.tvRemote, .extendedGamepad],
        revision: UInt64 = 1
    ) throws -> TVVisionInputCapabilitySnapshot {
        try TVVisionInputCapabilitySnapshot(
            platform: .tvOS,
            revision: TVVisionSemanticRevision(rawValue: revision),
            inputGeneration: generation ?? self.generation(.input, 1),
            supported: supported,
            focusEligibility: eligibility
        )
    }

    private func surfacePress(
        _ surfaceGeneration: TVVisionGeneration,
        _ pressID: UInt64,
        _ button: TVRemoteButton,
        _ phase: TVRemoteSurfacePressPhase
    ) throws -> TVRemoteSurfacePressEvent {
        try TVRemoteSurfacePressEvent(
            surfaceGeneration: surfaceGeneration,
            pressID: pressID,
            button: button,
            phase: phase
        )
    }

    private func containsRemoteDelivery(
        _ effects: [TVRemoteCaptureEffect]
    ) -> Bool {
        effects.contains {
            if case .sendRemote = $0 {
                return true
            }
            return false
        }
    }

    private func pressToken(
        _ inputGeneration: TVVisionGeneration,
        _ rawValue: UInt64
    ) throws -> TVRemotePressToken {
        try TVRemotePressToken(
            inputGeneration: inputGeneration,
            rawValue: rawValue
        )
    }

    private func controllerLease(
        slot: Int,
        lease: UInt64,
        profile: TVVisionControllerProfile = .extendedGamepad,
        capabilities: RemoteControllerCapabilities = [.rumble],
        platform: TVVisionPlatform = .tvOS,
        inputGeneration: TVVisionGeneration? = nil
    ) throws -> TVVisionControllerLease {
        try TVVisionControllerLease(
            platform: platform,
            leaseGeneration: generation(.controller, lease),
            inputGeneration: inputGeneration ?? generation(.input, 1),
            slot: TVVisionControllerSlot(slot),
            profile: profile,
            capabilities: capabilities
        )
    }

    private func controllerSnapshot(
        slot: Int,
        lease: UInt64,
        mask: UInt16
    ) throws -> TVControllerInputSnapshot {
        try TVControllerInputSnapshot(
            lease: controllerLease(slot: slot, lease: lease),
            supportedButtons: .standard,
            state: remoteState(slot: UInt8(slot), mask: mask)
        )
    }

    private func remoteState(
        slot: UInt8,
        mask: UInt16,
        buttons: RemoteControllerButtonFlags = []
    ) -> RemoteControllerState {
        RemoteControllerState(
            controllerIndex: slot,
            activeGamepadMask: mask,
            buttons: buttons,
            leftTrigger: 0,
            rightTrigger: 0,
            leftStickX: 0,
            leftStickY: 0,
            rightStickX: 0,
            rightStickY: 0
        )
    }

    private func generation(
        _ domain: TVVisionGenerationDomain,
        _ rawValue: UInt64
    ) throws -> TVVisionGeneration {
        try TVVisionGeneration(domain: domain, rawValue: rawValue)
    }

    private func semanticRevision() throws -> TVVisionSemanticRevision {
        try TVVisionSemanticRevision(rawValue: 1)
    }
}

@MainActor
private final class TVRemoteSurfaceDeliveryRecorder {
    private(set) var generations: [TVVisionGeneration] = []
    private(set) var attemptedEvents: [TVRemoteInputEvent] = []
    private(set) var events: [TVRemoteInputEvent] = []
    private var failingAttempts: Set<Int>

    init(failuresRemaining: Int = 0) {
        failingAttempts = Set((0..<failuresRemaining).map { $0 + 1 })
    }

    init(failingAttempts: Set<Int>) {
        self.failingAttempts = failingAttempts
    }

    func deliver(
        generation: TVVisionGeneration,
        event: TVRemoteInputEvent
    ) throws {
        generations.append(generation)
        attemptedEvents.append(event)
        if failingAttempts.remove(attemptedEvents.count) != nil {
            throw TVRemoteSurfaceDeliveryTestError.failed
        }
        events.append(event)
    }
}

private enum TVRemoteSurfaceDeliveryTestError: Error {
    case failed
}
