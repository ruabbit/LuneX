#if os(macOS)
import AppKit

@MainActor
final class MacStreamInputCaptureView: NSView {
    typealias SampleHandler = @MainActor (MacPlatformInputSample) -> Void

    var forwardsSystemShortcuts: Bool

    private let sampleHandler: SampleHandler
    private let captureExitHandler: @MainActor () -> Void
    private var pressedModifierKeyCodes: Set<UInt16> = []
    private var reservedShortcutsByKeyCode: [UInt16: MacReservedShortcut] = [:]

    init(
        frame frameRect: NSRect = .zero,
        forwardsSystemShortcuts: Bool = false,
        captureExitHandler: @escaping @MainActor () -> Void = {},
        sampleHandler: @escaping SampleHandler
    ) {
        self.forwardsSystemShortcuts = forwardsSystemShortcuts
        self.captureExitHandler = captureExitHandler
        self.sampleHandler = sampleHandler
        super.init(frame: frameRect)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("MacStreamInputCaptureView must be created programmatically")
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown,
              let shortcut = reservedShortcutForKeyDown(event),
              shortcut.canBeForwarded else {
            return super.performKeyEquivalent(with: event)
        }
        guard forwardsSystemShortcuts else {
            return super.performKeyEquivalent(with: event)
        }

        reservedShortcutsByKeyCode[event.keyCode] = shortcut
        emitKeyboard(event, isDown: true, reservedShortcut: shortcut)
        return true
    }

    override func keyDown(with event: NSEvent) {
        let shortcut = reservedShortcutForKeyDown(event)
        if let shortcut {
            reservedShortcutsByKeyCode[event.keyCode] = shortcut
        }
        if shortcut == .escapeCapture && !event.isARepeat {
            captureExitHandler()
        }
        emitKeyboard(event, isDown: true, reservedShortcut: shortcut)
        if shouldRemainLocal(shortcut) {
            super.keyDown(with: event)
        }
    }

    override func keyUp(with event: NSEvent) {
        let shortcut = reservedShortcutsByKeyCode.removeValue(forKey: event.keyCode)
        emitKeyboard(event, isDown: false, reservedShortcut: shortcut)
        if shouldRemainLocal(shortcut) {
            super.keyUp(with: event)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        guard let modifier = modifier(for: event.keyCode) else {
            return
        }

        let modifiers = inputModifiers(from: event.modifierFlags)
        let isDown: Bool
        if modifier == .capsLock {
            isDown = modifiers.contains(.capsLock)
        } else if pressedModifierKeyCodes.remove(event.keyCode) != nil {
            isDown = false
        } else if modifiers.contains(modifier) {
            pressedModifierKeyCodes.insert(event.keyCode)
            isDown = true
        } else {
            isDown = false
        }

        sampleHandler(.keyboard(MacKeyboardSample(
            rawKeyCode: event.keyCode,
            characters: nil,
            isDown: isDown,
            modifiers: modifiers,
            isRepeat: false
        )))
    }

    func resetTransientInputState() {
        pressedModifierKeyCodes.removeAll(keepingCapacity: true)
        reservedShortcutsByKeyCode.removeAll(keepingCapacity: true)
    }

    private func emitKeyboard(
        _ event: NSEvent,
        isDown: Bool,
        reservedShortcut: MacReservedShortcut?
    ) {
        sampleHandler(.keyboard(MacKeyboardSample(
            rawKeyCode: event.keyCode,
            characters: event.characters,
            isDown: isDown,
            modifiers: inputModifiers(from: event.modifierFlags),
            isRepeat: isDown && event.isARepeat,
            reservedShortcut: reservedShortcut
        )))
    }

    private func reservedShortcutForKeyDown(_ event: NSEvent) -> MacReservedShortcut? {
        if event.keyCode == 53 {
            return .escapeCapture
        }
        return MacReservedShortcut.classify(
            rawKeyCode: event.keyCode,
            modifiers: inputModifiers(from: event.modifierFlags),
            isDown: true
        )
    }

    private func shouldRemainLocal(_ shortcut: MacReservedShortcut?) -> Bool {
        guard let shortcut else { return false }
        return !forwardsSystemShortcuts || !shortcut.canBeForwarded
    }

    private func inputModifiers(from flags: NSEvent.ModifierFlags) -> InputModifiers {
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        var modifiers: InputModifiers = []
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.control) { modifiers.insert(.control) }
        if flags.contains(.option) { modifiers.insert(.option) }
        if flags.contains(.command) { modifiers.insert(.command) }
        if flags.contains(.capsLock) { modifiers.insert(.capsLock) }
        return modifiers
    }

    private func modifier(for rawKeyCode: UInt16) -> InputModifiers? {
        switch rawKeyCode {
        case 56, 60:
            return .shift
        case 59, 62:
            return .control
        case 58, 61:
            return .option
        case 54, 55:
            return .command
        case 57:
            return .capsLock
        default:
            return nil
        }
    }
}
#endif
