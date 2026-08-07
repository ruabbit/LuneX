import XCTest

final class ControllerAndDiagnosticsTests: XCTestCase {
    func testGameControllerButtonMapsToRemoteEvent() {
        let adapter = GameControllerInputAdapter()

        let output = adapter.controllerElement(GameControllerElementSample(
            controllerID: "controller-1",
            playerIndex: 1,
            element: .a,
            value: 0.8
        ))

        XCTAssertEqual(output.policy, .deliver)
        XCTAssertEqual(output.event, .gameController(GameControllerInputEvent(
            controllerID: "controller-1",
            playerIndex: 1,
            element: .a,
            value: 0.8,
            isPressed: true
        )))
    }

    func testGameControllerAxesClampSignedValues() {
        let adapter = GameControllerInputAdapter()

        let output = adapter.controllerElement(GameControllerElementSample(
            controllerID: "controller-1",
            playerIndex: nil,
            element: .leftThumbstickX,
            value: -1.4
        ))

        XCTAssertEqual(output.event, .gameController(GameControllerInputEvent(
            controllerID: "controller-1",
            playerIndex: nil,
            element: .leftThumbstickX,
            value: -1,
            isPressed: true
        )))
    }

    func testGameControllerDropsEveryNonFiniteElementValue() {
        let adapter = GameControllerInputAdapter()

        for value in [Double.nan, .infinity, -.infinity] {
            for element in [GameControllerElement.a, .leftThumbstickX] {
                let output = adapter.controllerElement(
                    GameControllerElementSample(
                        controllerID: "private-controller-identity",
                        playerIndex: nil,
                        element: element,
                        value: value
                    )
                )
                XCTAssertNil(output.event)
                XCTAssertEqual(
                    output.policy,
                    .drop(reason: "Controller element value must be finite")
                )
            }
        }
    }

    func testGameControllerFiniteValuesClampToElementDomains() throws {
        let adapter = GameControllerInputAdapter()
        let cases: [(GameControllerElement, Double, Double, Bool)] = [
            (.leftThumbstickX, -2, -1, true),
            (.rightThumbstickY, 2, 1, true),
            (.a, -2, 0, false),
            (.rightTrigger, 2, 1, true)
        ]

        for (element, input, expectedValue, expectedPressed) in cases {
            let output = adapter.controllerElement(GameControllerElementSample(
                controllerID: "controller",
                playerIndex: nil,
                element: element,
                value: input
            ))
            guard case let .gameController(event) = try XCTUnwrap(output.event) else {
                return XCTFail("Expected a normalized controller event")
            }
            XCTAssertEqual(output.policy, .deliver)
            XCTAssertTrue(event.value.isFinite)
            XCTAssertEqual(event.value, expectedValue)
            XCTAssertEqual(event.isPressed, expectedPressed)
        }
    }

    func testControllerSnapshotProducesRemoteBitmap() {
        let snapshot = GameControllerBindingSnapshot(controllers: [
            GameControllerConnectionState(
                id: "first",
                vendorName: "Pad One",
                playerIndex: 1,
                isConnected: true,
                supportsExtendedGamepad: true,
                supportsMicroGamepad: false
            ),
            GameControllerConnectionState(
                id: "second",
                vendorName: "Pad Two",
                playerIndex: 2,
                isConnected: true,
                supportsExtendedGamepad: true,
                supportsMicroGamepad: false
            ),
            GameControllerConnectionState(
                id: "stale",
                vendorName: nil,
                playerIndex: nil,
                isConnected: false,
                supportsExtendedGamepad: false,
                supportsMicroGamepad: false
            )
        ])

        XCTAssertEqual(snapshot.connectedControllers.map(\.id), ["first", "second"])
        XCTAssertEqual(snapshot.remoteControllersBitmap, 0b11)
    }

    func testTVGameControllerRuntimeNormalizesOneCompleteState() throws {
        let inputGeneration = try TVVisionGeneration(
            domain: .input,
            rawValue: 1
        )
        var runtime = try TVGameControllerSlotRuntime(
            inputGeneration: inputGeneration
        )
        let roster = try runtime.connect(
            token: TVGameControllerDeviceToken(1),
            profile: .extendedGamepad,
            capabilities: [.analogTriggers],
            supportedButtons: [.a, .dpadUp],
            completeState: TVGameControllerCompleteState(
                buttons: [.a],
                leftTrigger: 2,
                rightTrigger: -1,
                leftStickX: -2,
                leftStickY: 0.5,
                rightStickX: 2,
                rightStickY: -0.5
            )
        )

        let controller = try XCTUnwrap(roster.controllers.first)
        XCTAssertEqual(controller.lease.slot.rawValue, 0)
        XCTAssertEqual(controller.state.activeGamepadMask, 1)
        XCTAssertEqual(controller.state.buttons, [.a])
        XCTAssertEqual(controller.state.leftTrigger, .max)
        XCTAssertEqual(controller.state.rightTrigger, 0)
        XCTAssertEqual(controller.state.leftStickX, -Int16.max)
        XCTAssertEqual(controller.state.leftStickY, 16_384)
        XCTAssertEqual(controller.state.rightStickX, .max)
        XCTAssertEqual(controller.state.rightStickY, -16_384)

        XCTAssertThrowsError(try TVGameControllerCompleteState(
            leftStickX: .nan
        )) { error in
            XCTAssertEqual(
                error as? TVGameControllerRuntimeError,
                .invalidCompleteState
            )
        }
        var microRuntime = try TVGameControllerSlotRuntime(
            inputGeneration: inputGeneration
        )
        XCTAssertThrowsError(
            try microRuntime.connectingMicroStateWithNonzeroAxisForTest()
        )
    }

    func testTVGameControllerRuntimeUsesStableSlotsAndFreshReplacementLease()
        throws {
        let inputGeneration = try TVVisionGeneration(
            domain: .input,
            rawValue: 7
        )
        var runtime = try TVGameControllerSlotRuntime(
            inputGeneration: inputGeneration
        )
        let firstToken = try TVGameControllerDeviceToken(10)
        let secondToken = try TVGameControllerDeviceToken(20)
        let replacementToken = try TVGameControllerDeviceToken(30)
        _ = try runtime.connect(
            token: firstToken,
            profile: .extendedGamepad,
            capabilities: [.analogTriggers],
            supportedButtons: .standard,
            completeState: TVGameControllerCompleteState(buttons: [.a])
        )
        var roster = try runtime.connect(
            token: secondToken,
            profile: .microGamepad,
            capabilities: [],
            supportedButtons: [.a, .x, .dpadUp, .dpadDown, .dpadLeft, .dpadRight],
            completeState: TVGameControllerCompleteState(buttons: [.x])
        )
        XCTAssertEqual(roster.controllers.map(\.lease.slot.rawValue), [0, 1])
        XCTAssertEqual(
            roster.controllers.map(\.lease.leaseGeneration.rawValue),
            [1, 2]
        )
        XCTAssertEqual(roster.activeGamepadMask, 0b11)
        XCTAssertTrue(roster.controllers.allSatisfy {
            $0.state.activeGamepadMask == 0b11
        })

        roster = try runtime.disconnect(token: firstToken)
        XCTAssertEqual(roster.controllers.map(\.lease.slot.rawValue), [1])
        XCTAssertEqual(roster.activeGamepadMask, 0b10)
        XCTAssertEqual(roster.controllers[0].state.activeGamepadMask, 0b10)

        roster = try runtime.connect(
            token: replacementToken,
            profile: .extendedGamepad,
            capabilities: [.analogTriggers],
            supportedButtons: .standard,
            completeState: TVGameControllerCompleteState(buttons: [.b])
        )
        XCTAssertEqual(roster.controllers.map(\.lease.slot.rawValue), [0, 1])
        XCTAssertEqual(
            roster.controllers.map(\.lease.leaseGeneration.rawValue),
            [3, 2]
        )
        XCTAssertThrowsError(try runtime.update(
            token: firstToken,
            completeState: TVGameControllerCompleteState(buttons: [.y])
        )) { error in
            XCTAssertEqual(
                error as? TVGameControllerRuntimeError,
                .deviceUnavailable(10)
            )
        }
    }

    func testTVGameControllerRuntimeEnforcesSixteenControllerCapacity() throws {
        let inputGeneration = try TVVisionGeneration(
            domain: .input,
            rawValue: 1
        )
        var runtime = try TVGameControllerSlotRuntime(
            inputGeneration: inputGeneration
        )
        for index in 0..<TVVisionControllerSlot.maximumCount {
            _ = try runtime.connect(
                token: TVGameControllerDeviceToken(UInt64(index + 1)),
                profile: .extendedGamepad,
                capabilities: [.analogTriggers],
                supportedButtons: .standard,
                completeState: TVGameControllerCompleteState()
            )
        }
        XCTAssertEqual(try runtime.roster.controllers.count, 16)
        XCTAssertEqual(try runtime.roster.activeGamepadMask, .max)
        XCTAssertThrowsError(try runtime.connect(
            token: TVGameControllerDeviceToken(17),
            profile: .extendedGamepad,
            capabilities: [.analogTriggers],
            supportedButtons: .standard,
            completeState: TVGameControllerCompleteState()
        )) { error in
            XCTAssertEqual(
                error as? TVGameControllerRuntimeError,
                .controllerCapacityExceeded
            )
        }
    }

    func testTVGameControllerRosterRouterUsesOpaqueLeaseIdentityAndExactSlots()
        throws {
        let inputGeneration = try TVVisionGeneration(
            domain: .input,
            rawValue: 9
        )
        var runtime = try TVGameControllerSlotRuntime(
            inputGeneration: inputGeneration
        )
        let firstToken = try TVGameControllerDeviceToken(1)
        _ = try runtime.connect(
            token: firstToken,
            profile: .extendedGamepad,
            capabilities: [.analogTriggers, .rumble],
            supportedButtons: .standard,
            completeState: TVGameControllerCompleteState(buttons: [.a])
        )
        let previous = try runtime.connect(
            token: TVGameControllerDeviceToken(2),
            profile: .microGamepad,
            capabilities: [.rgbLED],
            supportedButtons: [.a, .x, .menu],
            completeState: TVGameControllerCompleteState(buttons: [.x])
        )
        _ = try runtime.disconnect(token: firstToken)
        let current = try runtime.connect(
            token: TVGameControllerDeviceToken(3),
            profile: .extendedGamepad,
            capabilities: [.analogTriggers, .gyroscope],
            supportedButtons: .standard,
            completeState: TVGameControllerCompleteState(buttons: [.b])
        )

        let route = TVGameControllerRosterRouter.reconcile(
            previous: previous,
            current: current
        )
        XCTAssertEqual(route.disconnectedControllerIDs, ["tv:9:1:0"])
        XCTAssertEqual(
            route.controllers.map(\.connection.preferredControllerIndex),
            [0, 1]
        )
        XCTAssertEqual(
            route.controllers.map(\.connection.controllerID),
            ["tv:9:3:0", "tv:9:2:1"]
        )
        XCTAssertEqual(
            TVGameControllerRosterRouter.lease(
                matching: "tv:9:3:0",
                in: current
            ),
            current.controllers[0].lease
        )
        XCTAssertNil(TVGameControllerRosterRouter.lease(
            matching: "controller-vendor-name",
            in: current
        ))
    }

    func testTVGameControllerMotionSampleRejectsNonfiniteAndUsesLeaseIdentity()
        throws {
        let inputGeneration = try TVVisionGeneration(
            domain: .input,
            rawValue: 4
        )
        var runtime = try TVGameControllerSlotRuntime(
            inputGeneration: inputGeneration
        )
        let roster = try runtime.connect(
            token: TVGameControllerDeviceToken(1),
            profile: .extendedGamepad,
            capabilities: [.analogTriggers, .accelerometer],
            supportedButtons: .standard,
            completeState: TVGameControllerCompleteState()
        )
        let lease = try XCTUnwrap(roster.controllers.first?.lease)
        let sample = try TVGameControllerMotionSample(
            lease: lease,
            type: .accelerometer,
            x: 1,
            y: 2,
            z: 3
        )
        XCTAssertEqual(sample.remoteEvent, .controllerMotion(
            ControllerMotionInputEvent(
                controllerID: "tv:4:1:0",
                type: .accelerometer,
                x: 1,
                y: 2,
                z: 3
            )
        ))
        XCTAssertThrowsError(try TVGameControllerMotionSample(
            lease: lease,
            type: .accelerometer,
            x: .nan,
            y: 0,
            z: 0
        ))
    }

    func testTVRemoteReservesInputUntilStreamIsActive() {
        let adapter = TVRemoteFocusInputAdapter(isStreamActive: false)

        let output = adapter.remoteButton(TVRemoteSample(button: .menu, isDown: true))

        XCTAssertEqual(output.policy, .reserveLocally(reason: "tvOS remote input remains local until a stream is active"))
        XCTAssertNil(output.event)
    }

    func testTVRemoteAndFocusEventsDeliverWhenStreaming() {
        let adapter = TVRemoteFocusInputAdapter(isStreamActive: true)

        let remoteOutput = adapter.remoteButton(TVRemoteSample(button: .playPause, isDown: true))
        let focusOutput = adapter.focus(FocusSample(focusedItemID: "host-row", movement: .next, isFocused: true))

        XCTAssertEqual(remoteOutput.event, .tvRemote(TVRemoteInputEvent(button: .playPause, isDown: true)))
        XCTAssertEqual(focusOutput.event, .focus(FocusInputEvent(focusedItemID: "host-row", movement: .next, isFocused: true)))
    }

    func testInputDiagnosticsRecordsReservedDroppedAndControllerStatus() async {
        let recorder = InputDiagnosticsRecorder()
        let reserved = InputAdapterOutput(event: nil, policy: .reserveLocally(reason: "Command-Tab remains local"))
        let dropped = InputAdapterOutput(event: nil, policy: .drop(reason: "Unknown controller element"))
        let snapshot = GameControllerBindingSnapshot(controllers: [
            GameControllerConnectionState(
                id: "first",
                vendorName: "Pad One",
                playerIndex: 1,
                isConnected: true,
                supportsExtendedGamepad: true,
                supportsMicroGamepad: false
            )
        ])

        await recorder.record(reserved, subsystem: "input.keyboard", now: Date(timeIntervalSince1970: 1))
        await recorder.record(dropped, subsystem: "input.controller", now: Date(timeIntervalSince1970: 2))
        await recorder.recordControllerSnapshot(snapshot, now: Date(timeIntervalSince1970: 3))

        let records = await recorder.snapshot()
        XCTAssertEqual(records.map(\.severity), [.info, .warning, .info])
        XCTAssertEqual(records.map(\.subsystem), ["input.keyboard", "input.controller", "input.controller"])
        XCTAssertEqual(records[2].message, "1 controller connected; bitmap=1")
    }
}

private extension TVGameControllerSlotRuntime {
    mutating func connectingMicroStateWithNonzeroAxisForTest()
        throws -> TVControllerRosterSnapshot {
        try connect(
            token: TVGameControllerDeviceToken(2),
            profile: .microGamepad,
            capabilities: [],
            supportedButtons: [.a],
            completeState: TVGameControllerCompleteState(
                buttons: [.a],
                leftStickX: 1
            )
        )
    }
}
