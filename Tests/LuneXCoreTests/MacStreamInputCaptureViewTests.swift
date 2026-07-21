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
}
#endif
