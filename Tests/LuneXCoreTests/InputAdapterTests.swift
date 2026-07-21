import XCTest

final class InputAdapterTests: XCTestCase {
    func testCursorPolicyCapturesOnlyFocusedVisibleActiveStreams() {
        let active = CursorCapturePolicyResolver.resolve(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            prefersRemotePointer: true
        )
        let unfocused = CursorCapturePolicyResolver.resolve(
            isStreamActive: true,
            isVisible: true,
            isFocused: false,
            prefersRemotePointer: true
        )

        XCTAssertTrue(active.hidesSystemCursor)
        XCTAssertTrue(active.capturesRelativePointer)
        XCTAssertTrue(active.usesRemotePointer)
        XCTAssertFalse(unfocused.hidesSystemCursor)
        XCTAssertFalse(unfocused.capturesRelativePointer)
        XCTAssertEqual(unfocused.reason, "Window is not key")
    }

    func testMacPointerUsesRelativeDeltasWhenCaptured() {
        let adapter = MacInputAdapter(
            mapper: makeMapper(),
            cursorPolicy: CursorCapturePolicy(
                hidesSystemCursor: true,
                capturesRelativePointer: true,
                usesRemotePointer: true,
                reason: nil
            )
        )

        let output = adapter.pointerMove(MacPointerSample(
            localPoint: RemotePoint(x: 400, y: 300),
            deltaX: 12,
            deltaY: -4,
            buttons: [.left]
        ))

        XCTAssertEqual(output.policy, .deliver)
        XCTAssertEqual(output.event, .pointer(.relativeMove(deltaX: 12, deltaY: -4, buttons: [.left])))
    }

    func testMacPointerMapsAbsolutePointWhenNotCaptured() {
        let adapter = MacInputAdapter(
            mapper: makeMapper(),
            cursorPolicy: CursorCapturePolicy(
                hidesSystemCursor: false,
                capturesRelativePointer: false,
                usesRemotePointer: false,
                reason: nil
            )
        )

        let output = adapter.pointerMove(MacPointerSample(
            localPoint: RemotePoint(x: 400, y: 300),
            deltaX: 0,
            deltaY: 0,
            buttons: []
        ))

        XCTAssertEqual(output.policy, .deliver)
        XCTAssertEqual(output.event, .pointer(.absoluteMove(
            point: RemotePoint(x: 960, y: 540),
            referenceSize: PixelSize(width: 1920, height: 1080),
            buttons: []
        )))
    }

    func testMacButtonMapsAbsolutePointAndRejectsInvalidDown() {
        let adapter = makeMacAdapter(capturesRelativePointer: false)

        XCTAssertEqual(
            adapter.button(.left, isDown: true, localPoint: RemotePoint(x: 400, y: 300)),
            InputAdapterOutput(
                event: .pointer(.button(
                    button: .left,
                    isDown: true,
                    point: RemotePoint(x: 960, y: 540)
                )),
                policy: .deliver
            )
        )
        XCTAssertEqual(
            adapter.button(.left, isDown: true, localPoint: RemotePoint(x: 400, y: 50)),
            InputAdapterOutput(
                event: nil,
                policy: .drop(reason: "Pointer button is outside a drawable video region")
            )
        )
    }

    func testMacAbsoluteButtonReleaseCannotBeStrandedByLetterbox() {
        let adapter = makeMacAdapter(capturesRelativePointer: false)

        XCTAssertEqual(
            adapter.button(.left, isDown: false, localPoint: RemotePoint(x: 400, y: 50)),
            InputAdapterOutput(
                event: .pointer(.button(button: .left, isDown: false, point: nil)),
                policy: .deliver
            )
        )
        XCTAssertEqual(
            adapter.button(.right, isDown: false, localPoint: nil),
            InputAdapterOutput(
                event: .pointer(.button(button: .right, isDown: false, point: nil)),
                policy: .deliver
            )
        )
    }

    func testMacRelativeButtonDoesNotRequireAbsolutePoint() {
        let adapter = makeMacAdapter(capturesRelativePointer: true)

        XCTAssertEqual(
            adapter.button(.back, isDown: true, localPoint: nil),
            InputAdapterOutput(
                event: .pointer(.button(button: .back, isDown: true, point: nil)),
                policy: .deliver
            )
        )
    }

    func testMacScrollMapsAbsolutePointAndRejectsLetterbox() {
        let adapter = makeMacAdapter(capturesRelativePointer: false)

        XCTAssertEqual(
            adapter.scroll(MacScrollSample(
                localPoint: RemotePoint(x: 400, y: 300),
                deltaX: 120,
                deltaY: -120
            )),
            InputAdapterOutput(
                event: .pointer(.scroll(
                    deltaX: 120,
                    deltaY: -120,
                    point: RemotePoint(x: 960, y: 540)
                )),
                policy: .deliver
            )
        )
        XCTAssertEqual(
            adapter.scroll(MacScrollSample(
                localPoint: RemotePoint(x: 400, y: 50),
                deltaX: 0,
                deltaY: 120
            )),
            InputAdapterOutput(
                event: nil,
                policy: .drop(reason: "Scroll is outside a drawable video region")
            )
        )
    }

    func testMacRelativeScrollDoesNotRequireAbsolutePoint() {
        let adapter = makeMacAdapter(capturesRelativePointer: true)

        XCTAssertEqual(
            adapter.scroll(MacScrollSample(localPoint: nil, deltaX: -120, deltaY: 120)),
            InputAdapterOutput(
                event: .pointer(.scroll(deltaX: -120, deltaY: 120, point: nil)),
                policy: .deliver
            )
        )
    }

    func testMacKeyboardReservesSystemShortcutsByDefault() {
        let adapter = MacInputAdapter(
            mapper: makeMapper(),
            cursorPolicy: CursorCapturePolicy(
                hidesSystemCursor: true,
                capturesRelativePointer: true,
                usesRemotePointer: true,
                reason: nil
            )
        )

        let output = adapter.keyboard(MacKeyboardSample(
            rawKeyCode: 48,
            characters: "\t",
            isDown: true,
            modifiers: [.command],
            isRepeat: false
        ))

        XCTAssertEqual(output.policy, .reserveLocally(reason: "Command-Tab remains local until explicit system shortcut forwarding is enabled"))
        XCTAssertNil(output.event)
    }

    func testMacKeyboardTranslatesVirtualKeyAndDropsUnknownKey() {
        let adapter = MacInputAdapter(
            mapper: makeMapper(),
            cursorPolicy: CursorCapturePolicy(
                hidesSystemCursor: false,
                capturesRelativePointer: false,
                usesRemotePointer: false,
                reason: nil
            )
        )

        XCTAssertEqual(
            adapter.keyboard(MacKeyboardSample(
                rawKeyCode: 0,
                characters: "a",
                isDown: true,
                modifiers: [.shift],
                isRepeat: true
            )),
            InputAdapterOutput(
                event: .keyboard(KeyboardInputEvent(
                    rawKeyCode: 0x41,
                    characters: "a",
                    isDown: true,
                    modifiers: [.shift],
                    isRepeat: true
                )),
                policy: .deliver
            )
        )

        let unknown = adapter.keyboard(MacKeyboardSample(
            rawKeyCode: 63,
            characters: nil,
            isDown: true,
            modifiers: [],
            isRepeat: false
        ))
        XCTAssertNil(unknown.event)
        XCTAssertEqual(
            unknown.policy,
            .drop(reason: "The macOS virtual key has no supported remote mapping")
        )
    }

    func testReservedShortcutClassificationKeepsKeyUpLocal() {
        let adapter = MacInputAdapter(
            mapper: makeMapper(),
            cursorPolicy: CursorCapturePolicy(
                hidesSystemCursor: false,
                capturesRelativePointer: false,
                usesRemotePointer: false,
                reason: nil
            )
        )
        let keyUp = MacKeyboardSample(
            rawKeyCode: 12,
            characters: "q",
            isDown: false,
            modifiers: [],
            isRepeat: false,
            reservedShortcut: .commandQ
        )

        XCTAssertEqual(
            adapter.keyboard(keyUp),
            InputAdapterOutput(
                event: nil,
                policy: .reserveLocally(reason: MacReservedShortcut.commandQ.reason)
            )
        )

        var forwardingAdapter = adapter
        forwardingAdapter.forwardsSystemShortcuts = true
        XCTAssertEqual(
            forwardingAdapter.keyboard(keyUp).event,
            .keyboard(KeyboardInputEvent(
                rawKeyCode: 0x51,
                characters: "q",
                isDown: false,
                modifiers: [],
                isRepeat: false
            ))
        )

        XCTAssertEqual(
            forwardingAdapter.keyboard(MacKeyboardSample(
                rawKeyCode: 53,
                characters: "\u{1B}",
                isDown: true,
                modifiers: [],
                isRepeat: false,
                reservedShortcut: .escapeCapture
            )).policy,
            .reserveLocally(reason: MacReservedShortcut.escapeCapture.reason)
        )
    }

    func testMacVirtualKeyTranslatorCoversLayoutFunctionAndNavigationKeys() {
        let expectedMappings: [UInt16: UInt16] = [
            0: 0x41,
            10: 0xE2,
            64: 0x80,
            71: 0x90,
            90: 0x83,
            110: 0x5D,
            114: 0x2F,
            123: 0x25,
            126: 0x26
        ]

        for (macKeyCode, remoteKeyCode) in expectedMappings {
            XCTAssertEqual(
                MacVirtualKeyTranslator.remoteKeyCode(for: macKeyCode),
                remoteKeyCode,
                "Unexpected mapping for macOS virtual key \(macKeyCode)"
            )
        }
        XCTAssertNil(MacVirtualKeyTranslator.remoteKeyCode(for: 63))
        XCTAssertNil(MacVirtualKeyTranslator.remoteKeyCode(for: 72))
        XCTAssertNil(MacVirtualKeyTranslator.remoteKeyCode(for: 81))
    }

    func testTouchInputMapsThroughRenderTransform() {
        let adapter = TouchInputAdapter(mapper: makeMapper())

        let output = adapter.touch(TouchSample(
            id: 2,
            phase: .moved,
            localPoint: RemotePoint(x: 400, y: 300),
            pressure: 0.5
        ))

        XCTAssertEqual(output.policy, .deliver)
        XCTAssertEqual(output.event, .touch(TouchInputEvent(
            id: 2,
            phase: .moved,
            point: RemotePoint(x: 960, y: 540),
            pressure: 0.5,
            referenceSize: PixelSize(width: 1920, height: 1080)
        )))
    }

    func testFitMapperRejectsLetterboxPoint() {
        let mapper = makeMapper()

        XCTAssertNil(mapper.remotePoint(localX: 400, localY: 50))
    }

    func testFillMapperUsesResolvedSourceCrop() {
        let snapshot = StreamCoordinateSnapshot.resolve(
            revision: 9,
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 800, height: 600),
            mode: .fill
        )
        let mapper = snapshot.map(InputMapper.init(snapshot:))

        let left = mapper?.remotePoint(localX: 0, localY: 300)
        let right = mapper?.remotePoint(localX: 800, localY: 300)
        XCTAssertEqual(left?.x ?? .nan, 240, accuracy: 0.000_001)
        XCTAssertEqual(left?.y ?? .nan, 540, accuracy: 0.000_001)
        XCTAssertEqual(right?.x ?? .nan, 1680, accuracy: 0.000_001)
        XCTAssertEqual(right?.y ?? .nan, 540, accuracy: 0.000_001)
    }

    func testTouchInputClampsPressureToProtocolRange() {
        let adapter = TouchInputAdapter(mapper: makeMapper())

        let output = adapter.touch(TouchSample(
            id: 3,
            phase: .began,
            localPoint: RemotePoint(x: 400, y: 300),
            pressure: 1.5
        ))

        guard case let .touch(event) = output.event else {
            return XCTFail("Expected a touch event.")
        }
        XCTAssertEqual(event.pressure, 1)
        XCTAssertEqual(event.referenceSize, PixelSize(width: 1920, height: 1080))
    }

    func testVirtualControllerClampsAnalogValue() {
        let adapter = TouchInputAdapter(mapper: makeMapper())

        let output = adapter.virtualController(VirtualControllerSample(control: .rightTrigger, value: 1.4))

        XCTAssertEqual(output.policy, .deliver)
        XCTAssertEqual(output.event, .virtualController(VirtualControllerInputEvent(
            control: .rightTrigger,
            value: 1,
            isPressed: true
        )))
    }

    private func makeMapper() -> InputMapper {
        let snapshot = StreamCoordinateSnapshot.resolve(
            revision: 1,
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 800, height: 600),
            mode: .fit
        )
        return InputMapper(snapshot: snapshot!)
    }

    private func makeMacAdapter(capturesRelativePointer: Bool) -> MacInputAdapter {
        MacInputAdapter(
            mapper: makeMapper(),
            cursorPolicy: CursorCapturePolicy(
                hidesSystemCursor: capturesRelativePointer,
                capturesRelativePointer: capturesRelativePointer,
                usesRemotePointer: capturesRelativePointer,
                reason: nil
            )
        )
    }
}
