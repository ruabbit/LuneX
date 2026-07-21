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
}
