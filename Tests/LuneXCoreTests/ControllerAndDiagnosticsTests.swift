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
