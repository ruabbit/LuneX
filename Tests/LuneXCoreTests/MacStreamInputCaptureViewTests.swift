#if os(macOS)
import AppKit
import XCTest

@MainActor
final class MacStreamInputCaptureViewTests: XCTestCase {
    func testViewIsFlippedAndAcceptsFirstResponder() {
        let view = makeView()

        XCTAssertTrue(view.isFlipped)
        XCTAssertTrue(view.acceptsFirstResponder)
    }

    func testKeyDownAndUpPreserveCharactersModifiersAndRepeat() throws {
        let recorder = MacInputSampleRecorder()
        let view = makeView(recorder: recorder)
        let keyDown = try keyEvent(
            type: .keyDown,
            keyCode: 0,
            characters: "A",
            modifiers: [.shift, .command],
            isRepeat: true
        )
        let keyUp = try keyEvent(
            type: .keyUp,
            keyCode: 0,
            characters: "A",
            modifiers: [.command]
        )

        view.keyDown(with: keyDown)
        view.keyUp(with: keyUp)

        XCTAssertEqual(recorder.samples, [
            .keyboard(MacKeyboardSample(
                rawKeyCode: 0,
                characters: "A",
                isDown: true,
                modifiers: [.shift, .command],
                isRepeat: true
            )),
            .keyboard(MacKeyboardSample(
                rawKeyCode: 0,
                characters: "A",
                isDown: false,
                modifiers: [.command],
                isRepeat: false
            ))
        ])
    }

    func testFlagsChangedBalancesLeftAndRightModifierTransitions() throws {
        let recorder = MacInputSampleRecorder()
        let view = makeView(recorder: recorder)

        view.flagsChanged(with: try flagsEvent(keyCode: 56, modifiers: [.shift]))
        view.flagsChanged(with: try flagsEvent(keyCode: 60, modifiers: [.shift]))
        view.flagsChanged(with: try flagsEvent(keyCode: 56, modifiers: [.shift]))
        view.flagsChanged(with: try flagsEvent(keyCode: 60, modifiers: []))

        XCTAssertEqual(recorder.keyboardSamples.map(\.rawKeyCode), [56, 60, 56, 60])
        XCTAssertEqual(recorder.keyboardSamples.map(\.isDown), [true, true, false, false])
        XCTAssertEqual(
            recorder.keyboardSamples.map(\.modifiers),
            [[.shift], [.shift], [.shift], []]
        )
    }

    func testReservedShortcutClassificationSurvivesModifierReleaseAndReset() throws {
        let recorder = MacInputSampleRecorder()
        let view = makeView(recorder: recorder)

        view.keyDown(with: try keyEvent(
            type: .keyDown,
            keyCode: 12,
            characters: "q",
            modifiers: [.command]
        ))
        view.keyUp(with: try keyEvent(
            type: .keyUp,
            keyCode: 12,
            characters: "q",
            modifiers: []
        ))
        view.keyDown(with: try keyEvent(
            type: .keyDown,
            keyCode: 53,
            characters: "\u{1B}",
            modifiers: []
        ))
        view.resetTransientInputState()
        view.keyUp(with: try keyEvent(
            type: .keyUp,
            keyCode: 53,
            characters: "\u{1B}",
            modifiers: []
        ))

        XCTAssertEqual(
            recorder.keyboardSamples.map(\.reservedShortcut),
            [.commandQ, .commandQ, .escapeCapture, nil]
        )
    }

    func testForwardedCommandKeyEquivalentIsCapturedWithoutLocalHandling() throws {
        let recorder = MacInputSampleRecorder()
        let view = makeView(recorder: recorder)
        let commandQ = try keyEvent(
            type: .keyDown,
            keyCode: 12,
            characters: "q",
            modifiers: [.command]
        )

        XCTAssertTrue(view.performKeyEquivalent(with: commandQ))
        view.keyUp(with: try keyEvent(
            type: .keyUp,
            keyCode: 12,
            characters: "q",
            modifiers: []
        ))
        XCTAssertEqual(recorder.keyboardSamples.map(\.isDown), [true, false])
        XCTAssertEqual(
            recorder.keyboardSamples.map(\.reservedShortcut),
            [.commandQ, .commandQ]
        )

        let localRecorder = MacInputSampleRecorder()
        let localView = MacStreamInputCaptureView(
            forwardsSystemShortcuts: false,
            sampleHandler: { localRecorder.samples.append($0) }
        )
        XCTAssertFalse(localView.performKeyEquivalent(with: commandQ))
        XCTAssertTrue(localRecorder.samples.isEmpty)
    }

    func testEscapeRequestsOneCaptureExitAndNeverBecomesRemoteInput() throws {
        let recorder = MacInputSampleRecorder()
        var exitCount = 0
        let view = MacStreamInputCaptureView(
            forwardsSystemShortcuts: true,
            captureExitHandler: { exitCount += 1 },
            sampleHandler: { recorder.samples.append($0) }
        )
        let escape = try keyEvent(
            type: .keyDown,
            keyCode: 53,
            characters: "\u{1B}",
            modifiers: []
        )
        let repeatedEscape = try keyEvent(
            type: .keyDown,
            keyCode: 53,
            characters: "\u{1B}",
            modifiers: [],
            isRepeat: true
        )

        view.keyDown(with: escape)
        view.keyDown(with: repeatedEscape)

        XCTAssertEqual(exitCount, 1)
        XCTAssertEqual(recorder.keyboardSamples.count, 2)
        let adapter = MacInputAdapter(
            mapper: InputMapper(snapshot: coordinateSnapshot),
            cursorPolicy: CursorCapturePolicy(
                hidesSystemCursor: true,
                capturesRelativePointer: true,
                usesRemotePointer: true,
                reason: nil
            ),
            forwardsSystemShortcuts: true
        )
        for sample in recorder.keyboardSamples {
            XCTAssertEqual(
                adapter.keyboard(sample).policy,
                .reserveLocally(reason: MacReservedShortcut.escapeCapture.reason)
            )
        }
    }

    func testPointerButtonTranslatorSupportsKnownButtonsOnly() {
        XCTAssertEqual(MacPointerButtonTranslator.button(for: 0), .left)
        XCTAssertEqual(MacPointerButtonTranslator.button(for: 1), .right)
        XCTAssertEqual(MacPointerButtonTranslator.button(for: 2), .middle)
        XCTAssertEqual(MacPointerButtonTranslator.button(for: 3), .back)
        XCTAssertEqual(MacPointerButtonTranslator.button(for: 4), .forward)
        XCTAssertNil(MacPointerButtonTranslator.button(for: 5))
        XCTAssertNil(MacPointerButtonTranslator.button(for: -1))
    }

    func testScrollDeltaNormalizerClampsPreciseAndNormalizesLineDeltas() {
        XCTAssertEqual(MacScrollDeltaNormalizer.remoteDelta(0.25, hasPreciseDeltas: true), 30)
        XCTAssertEqual(MacScrollDeltaNormalizer.remoteDelta(4, hasPreciseDeltas: true), 120)
        XCTAssertEqual(MacScrollDeltaNormalizer.remoteDelta(-2, hasPreciseDeltas: true), -120)
        XCTAssertEqual(MacScrollDeltaNormalizer.remoteDelta(0, hasPreciseDeltas: true), 0)
        XCTAssertEqual(MacScrollDeltaNormalizer.remoteDelta(0.01, hasPreciseDeltas: false), 120)
        XCTAssertEqual(MacScrollDeltaNormalizer.remoteDelta(-99, hasPreciseDeltas: false), -120)
        XCTAssertEqual(MacScrollDeltaNormalizer.remoteDelta(0, hasPreciseDeltas: false), 0)
        XCTAssertNil(MacScrollDeltaNormalizer.remoteDelta(.infinity, hasPreciseDeltas: true))
        XCTAssertNil(MacScrollDeltaNormalizer.remoteDelta(.nan, hasPreciseDeltas: false))
    }

    func testPointerPointUsesNestedViewRelativeBackingCoordinates() throws {
        let recorder = MacInputSampleRecorder()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 400),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 500, height: 400))
        let container = NSView(frame: NSRect(x: 41, y: 53, width: 260, height: 210))
        let view = MacStreamInputCaptureView(
            frame: NSRect(x: 17, y: 29, width: 160, height: 120),
            sampleHandler: { recorder.samples.append($0) }
        )
        view.bounds = NSRect(x: 11, y: 23, width: 160, height: 120)
        window.contentView = root
        root.addSubview(container)
        container.addSubview(view)

        let localPoint = NSPoint(x: 47, y: 61)
        let locationInWindow = view.convert(localPoint, to: nil)
        view.mouseMoved(with: try mouseEvent(
            type: .mouseMoved,
            location: locationInWindow,
            windowNumber: window.windowNumber
        ))

        let sample = try XCTUnwrap(recorder.pointerSamples.last)
        let actual = try XCTUnwrap(sample.localPoint)
        let backingPoint = view.convertToBacking(localPoint)
        let backingBounds = view.convertToBacking(view.bounds)
        XCTAssertEqual(actual.x, backingPoint.x - backingBounds.minX, accuracy: 0.000_001)
        XCTAssertEqual(actual.y, backingPoint.y - backingBounds.minY, accuracy: 0.000_001)
    }

    func testPointerMovementCarriesDeltasAndPressedButtonState() throws {
        let recorder = MacInputSampleRecorder()
        let view = makeView(recorder: recorder)

        view.mouseDown(with: try mouseEvent(type: .leftMouseDown))
        view.rightMouseDown(with: try mouseEvent(type: .rightMouseDown))
        view.rightMouseDragged(with: try cgMouseEvent(
            type: .rightMouseDragged,
            buttonNumber: 1,
            deltaX: 7,
            deltaY: -3
        ))
        view.mouseUp(with: try mouseEvent(type: .leftMouseUp))
        view.mouseMoved(with: try cgMouseEvent(
            type: .mouseMoved,
            buttonNumber: 0,
            deltaX: -2,
            deltaY: 5
        ))

        XCTAssertEqual(recorder.pointerSamples.count, 2)
        XCTAssertEqual(recorder.pointerSamples[0].deltaX, 7)
        XCTAssertEqual(recorder.pointerSamples[0].deltaY, -3)
        XCTAssertEqual(recorder.pointerSamples[0].buttons, [.left, .right])
        XCTAssertEqual(recorder.pointerSamples[1].deltaX, -2)
        XCTAssertEqual(recorder.pointerSamples[1].deltaY, 5)
        XCTAssertEqual(recorder.pointerSamples[1].buttons, [.right])
    }

    func testButtonCallbacksMapLeftRightMiddleBackAndForward() throws {
        let recorder = MacInputSampleRecorder()
        let view = makeView(recorder: recorder)

        view.mouseDown(with: try mouseEvent(type: .leftMouseDown))
        view.rightMouseDown(with: try mouseEvent(type: .rightMouseDown))
        for buttonNumber in 2...4 {
            view.otherMouseDown(with: try cgMouseEvent(
                type: .otherMouseDown,
                buttonNumber: buttonNumber
            ))
        }
        view.mouseUp(with: try mouseEvent(type: .leftMouseUp))
        view.rightMouseUp(with: try mouseEvent(type: .rightMouseUp))
        for buttonNumber in 2...4 {
            view.otherMouseUp(with: try cgMouseEvent(
                type: .otherMouseUp,
                buttonNumber: buttonNumber
            ))
        }

        XCTAssertEqual(
            recorder.buttonTransitions.map(\.button),
            [.left, .right, .middle, .back, .forward, .left, .right, .middle, .back, .forward]
        )
        XCTAssertEqual(
            recorder.buttonTransitions.map(\.isDown),
            [true, true, true, true, true, false, false, false, false, false]
        )
    }

    func testUnsupportedOtherButtonRemainsLocal() throws {
        let recorder = MacInputSampleRecorder()
        let view = makeView(recorder: recorder)

        view.otherMouseDown(with: try cgMouseEvent(type: .otherMouseDown, buttonNumber: 5))
        view.otherMouseUp(with: try cgMouseEvent(type: .otherMouseUp, buttonNumber: 5))

        XCTAssertTrue(recorder.samples.isEmpty)
    }

    func testResetClearsLocalPointerButtonTracking() throws {
        let recorder = MacInputSampleRecorder()
        let view = makeView(recorder: recorder)

        view.mouseDown(with: try mouseEvent(type: .leftMouseDown))
        view.resetTransientInputState()
        view.mouseDragged(with: try cgMouseEvent(
            type: .leftMouseDragged,
            buttonNumber: 0,
            deltaX: 1,
            deltaY: 1
        ))

        XCTAssertEqual(recorder.pointerSamples.last?.buttons, [])
    }

    func testScrollWheelRoutesPreciseAndLineDeltasAndRejectsZero() throws {
        let recorder = MacInputSampleRecorder()
        let view = makeView(recorder: recorder)
        let precise = try scrollEvent(units: .pixel, vertical: 2, horizontal: -3)
        let line = try scrollEvent(units: .line, vertical: -4, horizontal: 5)

        XCTAssertTrue(precise.hasPreciseScrollingDeltas)
        XCTAssertFalse(line.hasPreciseScrollingDeltas)
        view.scrollWheel(with: precise)
        view.scrollWheel(with: line)
        view.scrollWheel(with: try scrollEvent(units: .line, vertical: 0, horizontal: 0))

        XCTAssertEqual(recorder.scrollSamples.count, 2)
        assertScrollSample(recorder.scrollSamples[0], matches: precise)
        assertScrollSample(recorder.scrollSamples[1], matches: line)
    }

    func testDisabledActualSurfaceDoesNotEmitInputSamples() throws {
        let recorder = MacInputSampleRecorder()
        let view = MacStreamInputCaptureView(
            isInputCaptureEnabled: false,
            sampleHandler: { recorder.samples.append($0) }
        )

        view.mouseDown(with: try mouseEvent(type: .leftMouseDown))
        view.mouseMoved(with: try cgMouseEvent(
            type: .mouseMoved,
            buttonNumber: 0,
            deltaX: 4,
            deltaY: 2
        ))
        view.scrollWheel(with: try scrollEvent(units: .line, vertical: 1, horizontal: 0))

        XCTAssertTrue(recorder.samples.isEmpty)
    }

    func testSurfaceWindowCallbackTracksActualViewAttachment() throws {
        let view = makeView()
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        var observedWindows: [NSWindow?] = []
        view.onWindowChange = { observedWindows.append($0) }

        window.contentView = view
        window.contentView = NSView()

        XCTAssertEqual(observedWindows.count, 2)
        let attachedWindow = try XCTUnwrap(observedWindows[0])
        XCTAssertTrue(attachedWindow === window)
        XCTAssertNil(observedWindows[1])
    }

    func testSurfaceAttachmentOwnerIsIdempotentAndRejectsStaleDismantle() {
        let monitor = RecordingAppKitLifecycleMonitor()
        let owner = MacStreamSurfaceAttachmentOwner(lifecycleMonitor: monitor)
        let firstView = makeView()
        let replacementView = makeView()
        let firstWindow = makeWindow(contentView: firstView)
        let replacementWindow = makeWindow(contentView: replacementView)

        owner.attach(to: firstView)
        owner.attach(to: firstView)
        XCTAssertEqual(monitor.attachedWindowIDs, [ObjectIdentifier(firstWindow)])

        owner.attach(to: replacementView)
        XCTAssertEqual(monitor.detachCount, 1)
        XCTAssertEqual(
            monitor.attachedWindowIDs,
            [ObjectIdentifier(firstWindow), ObjectIdentifier(replacementWindow)]
        )

        owner.detach(from: firstView)
        XCTAssertEqual(monitor.detachCount, 1)

        replacementWindow.contentView = NSView()
        XCTAssertEqual(monitor.detachCount, 2)
        replacementWindow.contentView = replacementView
        XCTAssertEqual(
            monitor.attachedWindowIDs,
            [
                ObjectIdentifier(firstWindow),
                ObjectIdentifier(replacementWindow),
                ObjectIdentifier(replacementWindow)
            ]
        )

        owner.detach(from: replacementView)
        owner.detach(from: replacementView)
        XCTAssertEqual(monitor.detachCount, 3)
        XCTAssertNil(replacementView.onWindowChange)
    }

    func testLifecycleMonitorClearsStateWhenActualSurfaceDetaches() {
        let lifecycle = PlatformLifecycleState()
        let monitor = AppKitLifecycleMonitor(lifecycle: lifecycle)
        let window = makeWindow(contentView: NSView())
        monitor.attach(to: window)
        lifecycle.isVisible = true
        lifecycle.isFocused = true
        lifecycle.drawableSize = PixelSize(width: 640, height: 480)
        lifecycle.updateRenderPolicy()

        monitor.detach()

        XCTAssertFalse(lifecycle.isVisible)
        XCTAssertFalse(lifecycle.isFocused)
        XCTAssertEqual(lifecycle.drawableSize, .zero)
    }

    func testReplacementMonitorOwnsSharedLifecycleBeforeOldDismantle() {
        let lifecycle = PlatformLifecycleState()
        let oldMonitor = AppKitLifecycleMonitor(lifecycle: lifecycle)
        let replacementMonitor = AppKitLifecycleMonitor(lifecycle: lifecycle)
        let oldWindow = makeWindow(contentView: NSView())
        let replacementWindow = makeWindow(contentView: NSView())
        oldMonitor.attach(to: oldWindow)
        replacementMonitor.attach(to: replacementWindow)
        lifecycle.isVisible = true
        lifecycle.isFocused = true
        lifecycle.drawableSize = PixelSize(width: 640, height: 480)
        lifecycle.updateRenderPolicy()

        oldMonitor.detach()

        XCTAssertTrue(lifecycle.isVisible)
        XCTAssertTrue(lifecycle.isFocused)
        XCTAssertEqual(lifecycle.drawableSize, PixelSize(width: 640, height: 480))

        replacementMonitor.detach()
        XCTAssertFalse(lifecycle.isVisible)
        XCTAssertFalse(lifecycle.isFocused)
        XCTAssertEqual(lifecycle.drawableSize, .zero)
    }

    private func makeView(
        recorder: MacInputSampleRecorder = MacInputSampleRecorder()
    ) -> MacStreamInputCaptureView {
        MacStreamInputCaptureView(
            forwardsSystemShortcuts: true,
            sampleHandler: { recorder.samples.append($0) }
        )
    }

    private func keyEvent(
        type: NSEvent.EventType,
        keyCode: UInt16,
        characters: String?,
        modifiers: NSEvent.ModifierFlags,
        isRepeat: Bool = false
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.keyEvent(
            with: type,
            location: .zero,
            modifierFlags: modifiers,
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: characters ?? "",
            charactersIgnoringModifiers: characters ?? "",
            isARepeat: isRepeat,
            keyCode: keyCode
        ))
    }

    private func mouseEvent(
        type: NSEvent.EventType,
        location: NSPoint = .zero,
        windowNumber: Int = 0
    ) throws -> NSEvent {
        try XCTUnwrap(NSEvent.mouseEvent(
            with: type,
            location: location,
            modifierFlags: [],
            timestamp: 0,
            windowNumber: windowNumber,
            context: nil,
            eventNumber: 1,
            clickCount: 1,
            pressure: 1
        ))
    }

    private func makeWindow(contentView: NSView) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.contentView = contentView
        return window
    }

    private func cgMouseEvent(
        type: CGEventType,
        buttonNumber: Int,
        deltaX: Int64 = 0,
        deltaY: Int64 = 0
    ) throws -> NSEvent {
        let button = try XCTUnwrap(CGMouseButton(rawValue: UInt32(buttonNumber)))
        let event = try XCTUnwrap(CGEvent(
            mouseEventSource: nil,
            mouseType: type,
            mouseCursorPosition: .zero,
            mouseButton: button
        ))
        event.setIntegerValueField(.mouseEventDeltaX, value: deltaX)
        event.setIntegerValueField(.mouseEventDeltaY, value: deltaY)
        return try XCTUnwrap(NSEvent(cgEvent: event))
    }

    private func scrollEvent(
        units: CGScrollEventUnit,
        vertical: Int32,
        horizontal: Int32
    ) throws -> NSEvent {
        let event = try XCTUnwrap(CGEvent(
            scrollWheelEvent2Source: nil,
            units: units,
            wheelCount: 2,
            wheel1: vertical,
            wheel2: horizontal,
            wheel3: 0
        ))
        return try XCTUnwrap(NSEvent(cgEvent: event))
    }

    private func assertScrollSample(
        _ sample: MacScrollSample,
        matches event: NSEvent,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let expectedX = MacScrollDeltaNormalizer.remoteDelta(
            Double(event.scrollingDeltaX),
            hasPreciseDeltas: event.hasPreciseScrollingDeltas
        )
        let expectedY = MacScrollDeltaNormalizer.remoteDelta(
            Double(event.scrollingDeltaY),
            hasPreciseDeltas: event.hasPreciseScrollingDeltas
        )
        XCTAssertEqual(sample.deltaX, expectedX, file: file, line: line)
        XCTAssertEqual(sample.deltaY, expectedY, file: file, line: line)
        XCTAssertNotNil(sample.localPoint, file: file, line: line)
    }

    private func flagsEvent(
        keyCode: UInt16,
        modifiers: NSEvent.ModifierFlags
    ) throws -> NSEvent {
        try keyEvent(
            type: .flagsChanged,
            keyCode: keyCode,
            characters: nil,
            modifiers: modifiers
        )
    }

    private var coordinateSnapshot: StreamCoordinateSnapshot {
        StreamCoordinateSnapshot.resolve(
            revision: 1,
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 1920, height: 1080),
            mode: .fit
        )!
    }
}

@MainActor
private final class MacInputSampleRecorder {
    var samples: [MacPlatformInputSample] = []

    var keyboardSamples: [MacKeyboardSample] {
        samples.compactMap {
            guard case let .keyboard(sample) = $0 else { return nil }
            return sample
        }
    }

    var pointerSamples: [MacPointerSample] {
        samples.compactMap {
            guard case let .pointerMove(sample) = $0 else { return nil }
            return sample
        }
    }

    var scrollSamples: [MacScrollSample] {
        samples.compactMap {
            guard case let .scroll(sample) = $0 else { return nil }
            return sample
        }
    }

    var buttonTransitions: [RecordedPointerButtonTransition] {
        samples.compactMap {
            guard case let .button(button, isDown, _) = $0 else { return nil }
            return RecordedPointerButtonTransition(button: button, isDown: isDown)
        }
    }
}

private struct RecordedPointerButtonTransition {
    var button: PointerButton
    var isDown: Bool
}

@MainActor
private final class RecordingAppKitLifecycleMonitor: AppKitLifecycleMonitoring {
    private(set) var attachedWindowIDs: [ObjectIdentifier] = []
    private(set) var detachCount = 0

    func attach(to window: NSWindow) {
        attachedWindowIDs.append(ObjectIdentifier(window))
    }

    func detach() {
        detachCount += 1
    }
}
#endif
