#if os(macOS)
import AppKit
import MetalKit

enum MacPointerButtonTranslator {
    static func button(for buttonNumber: Int) -> PointerButton? {
        switch buttonNumber {
        case 0: return .left
        case 1: return .right
        case 2: return .middle
        case 3: return .back
        case 4: return .forward
        default: return nil
        }
    }
}

enum MacScrollDeltaNormalizer {
    private static let wheelDelta = 120.0

    static func remoteDelta(_ value: Double, hasPreciseDeltas: Bool) -> Double? {
        guard value.isFinite else { return nil }
        let normalized: Double
        if hasPreciseDeltas {
            normalized = min(max(value, -1), 1)
        } else if value > 0 {
            normalized = 1
        } else if value < 0 {
            normalized = -1
        } else {
            normalized = 0
        }
        return normalized * wheelDelta
    }
}

@MainActor
final class MacStreamInputCaptureView: MTKView {
    typealias SampleHandler = @MainActor (MacPlatformInputSample) -> Void

    var isInputCaptureEnabled: Bool {
        didSet {
            guard isInputCaptureEnabled != oldValue else { return }
            if isInputCaptureEnabled {
                requestFirstResponderIfNeeded()
            } else {
                resetTransientInputState()
                if window?.firstResponder === self {
                    window?.makeFirstResponder(nil)
                }
            }
        }
    }
    var forwardsSystemShortcuts: Bool
    var onWindowChange: (@MainActor (NSWindow?) -> Void)?

    private let sampleHandler: SampleHandler
    private let captureExitHandler: @MainActor () -> Void
    private var pressedModifierKeyCodes: Set<UInt16> = []
    private var pressedPointerButtons: PointerButtonSet = []
    private var reservedShortcutsByKeyCode: [UInt16: MacReservedShortcut] = [:]

    init(
        frame frameRect: NSRect = .zero,
        device: (any MTLDevice)? = nil,
        isInputCaptureEnabled: Bool = true,
        forwardsSystemShortcuts: Bool = false,
        captureExitHandler: @escaping @MainActor () -> Void = {},
        sampleHandler: @escaping SampleHandler
    ) {
        self.isInputCaptureEnabled = isInputCaptureEnabled
        self.forwardsSystemShortcuts = forwardsSystemShortcuts
        self.captureExitHandler = captureExitHandler
        self.sampleHandler = sampleHandler
        super.init(frame: frameRect, device: device)
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("MacStreamInputCaptureView must be created programmatically")
    }

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
        requestFirstResponderIfNeeded()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isInputCaptureEnabled,
              event.type == .keyDown,
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
        guard isInputCaptureEnabled else {
            super.keyDown(with: event)
            return
        }
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
        guard isInputCaptureEnabled else {
            super.keyUp(with: event)
            return
        }
        let shortcut = reservedShortcutsByKeyCode.removeValue(forKey: event.keyCode)
        emitKeyboard(event, isDown: false, reservedShortcut: shortcut)
        if shouldRemainLocal(shortcut) {
            super.keyUp(with: event)
        }
    }

    override func flagsChanged(with event: NSEvent) {
        guard isInputCaptureEnabled else {
            super.flagsChanged(with: event)
            return
        }
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

    override func mouseMoved(with event: NSEvent) {
        guard isInputCaptureEnabled else {
            super.mouseMoved(with: event)
            return
        }
        emitPointerMovement(event)
    }

    override func mouseDragged(with event: NSEvent) {
        guard isInputCaptureEnabled else {
            super.mouseDragged(with: event)
            return
        }
        emitPointerMovement(event)
    }

    override func rightMouseDragged(with event: NSEvent) {
        guard isInputCaptureEnabled else {
            super.rightMouseDragged(with: event)
            return
        }
        emitPointerMovement(event)
    }

    override func otherMouseDragged(with event: NSEvent) {
        guard isInputCaptureEnabled else {
            super.otherMouseDragged(with: event)
            return
        }
        emitPointerMovement(event)
    }

    override func mouseDown(with event: NSEvent) {
        guard isInputCaptureEnabled else {
            super.mouseDown(with: event)
            return
        }
        requestFirstResponderIfNeeded()
        emitButton(.left, isDown: true, event: event)
    }

    override func mouseUp(with event: NSEvent) {
        guard isInputCaptureEnabled else {
            super.mouseUp(with: event)
            return
        }
        emitButton(.left, isDown: false, event: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard isInputCaptureEnabled else {
            super.rightMouseDown(with: event)
            return
        }
        requestFirstResponderIfNeeded()
        emitButton(.right, isDown: true, event: event)
    }

    override func rightMouseUp(with event: NSEvent) {
        guard isInputCaptureEnabled else {
            super.rightMouseUp(with: event)
            return
        }
        emitButton(.right, isDown: false, event: event)
    }

    override func otherMouseDown(with event: NSEvent) {
        guard isInputCaptureEnabled,
              let button = MacPointerButtonTranslator.button(for: event.buttonNumber) else {
            super.otherMouseDown(with: event)
            return
        }
        requestFirstResponderIfNeeded()
        emitButton(button, isDown: true, event: event)
    }

    override func otherMouseUp(with event: NSEvent) {
        guard isInputCaptureEnabled,
              let button = MacPointerButtonTranslator.button(for: event.buttonNumber) else {
            super.otherMouseUp(with: event)
            return
        }
        emitButton(button, isDown: false, event: event)
    }

    override func scrollWheel(with event: NSEvent) {
        guard isInputCaptureEnabled else {
            super.scrollWheel(with: event)
            return
        }
        guard let deltaX = MacScrollDeltaNormalizer.remoteDelta(
            Double(event.scrollingDeltaX),
            hasPreciseDeltas: event.hasPreciseScrollingDeltas
        ), let deltaY = MacScrollDeltaNormalizer.remoteDelta(
            Double(event.scrollingDeltaY),
            hasPreciseDeltas: event.hasPreciseScrollingDeltas
        ), deltaX != 0 || deltaY != 0 else {
            return
        }
        sampleHandler(.scroll(MacScrollSample(
            localPoint: backingPoint(for: event),
            deltaX: deltaX,
            deltaY: deltaY
        )))
    }

    func resetTransientInputState() {
        pressedModifierKeyCodes.removeAll(keepingCapacity: true)
        pressedPointerButtons = []
        reservedShortcutsByKeyCode.removeAll(keepingCapacity: true)
    }

    @discardableResult
    func requestFirstResponderIfNeeded() -> Bool {
        guard isInputCaptureEnabled, let window else { return false }
        guard window.firstResponder !== self else { return true }
        return window.makeFirstResponder(self)
    }

    private func emitPointerMovement(_ event: NSEvent) {
        let deltaX = Double(event.deltaX)
        let deltaY = Double(event.deltaY)
        guard deltaX.isFinite, deltaY.isFinite else { return }
        sampleHandler(.pointerMove(MacPointerSample(
            localPoint: backingPoint(for: event),
            deltaX: deltaX,
            deltaY: deltaY,
            buttons: pressedPointerButtons
        )))
    }

    private func emitButton(_ button: PointerButton, isDown: Bool, event: NSEvent) {
        let buttonSet = pointerButtonSet(for: button)
        if isDown {
            pressedPointerButtons.insert(buttonSet)
        } else {
            pressedPointerButtons.remove(buttonSet)
        }
        sampleHandler(.button(
            button: button,
            isDown: isDown,
            localPoint: backingPoint(for: event)
        ))
    }

    private func backingPoint(for event: NSEvent) -> RemotePoint? {
        let localPoint = convert(event.locationInWindow, from: nil)
        let backingPoint = convertToBacking(localPoint)
        let backingBounds = convertToBacking(bounds)
        let x = Double(backingPoint.x - backingBounds.minX)
        let y = Double(backingPoint.y - backingBounds.minY)
        guard x.isFinite, y.isFinite else { return nil }
        return RemotePoint(x: x, y: y)
    }

    private func pointerButtonSet(for button: PointerButton) -> PointerButtonSet {
        switch button {
        case .left: return .left
        case .right: return .right
        case .middle: return .middle
        case .back: return .back
        case .forward: return .forward
        }
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
