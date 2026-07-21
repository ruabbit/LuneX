import Foundation

struct CursorCapturePolicy: Codable, Equatable, Sendable {
    var hidesSystemCursor: Bool
    var capturesRelativePointer: Bool
    var usesRemotePointer: Bool
    var reason: String?
}

enum CursorCapturePolicyResolver {
    static func resolve(
        isStreamActive: Bool,
        isVisible: Bool,
        isFocused: Bool,
        prefersRemotePointer: Bool
    ) -> CursorCapturePolicy {
        guard isStreamActive else {
            return CursorCapturePolicy(
                hidesSystemCursor: false,
                capturesRelativePointer: false,
                usesRemotePointer: false,
                reason: "Stream is not active"
            )
        }

        guard isVisible else {
            return CursorCapturePolicy(
                hidesSystemCursor: false,
                capturesRelativePointer: false,
                usesRemotePointer: false,
                reason: "Window is not visible"
            )
        }

        guard isFocused else {
            return CursorCapturePolicy(
                hidesSystemCursor: false,
                capturesRelativePointer: false,
                usesRemotePointer: false,
                reason: "Window is not key"
            )
        }

        guard prefersRemotePointer else {
            return CursorCapturePolicy(
                hidesSystemCursor: false,
                capturesRelativePointer: false,
                usesRemotePointer: false,
                reason: "Local pointer mode is selected"
            )
        }

        return CursorCapturePolicy(
            hidesSystemCursor: true,
            capturesRelativePointer: true,
            usesRemotePointer: true,
            reason: nil
        )
    }
}

struct MacKeyboardSample: Codable, Equatable, Sendable {
    var rawKeyCode: UInt16
    var characters: String?
    var isDown: Bool
    var modifiers: InputModifiers
    var isRepeat: Bool
    var reservedShortcut: MacReservedShortcut?

    init(
        rawKeyCode: UInt16,
        characters: String?,
        isDown: Bool,
        modifiers: InputModifiers,
        isRepeat: Bool,
        reservedShortcut: MacReservedShortcut? = nil
    ) {
        self.rawKeyCode = rawKeyCode
        self.characters = characters
        self.isDown = isDown
        self.modifiers = modifiers
        self.isRepeat = isRepeat
        self.reservedShortcut = reservedShortcut
    }
}

enum MacReservedShortcut: String, Codable, Equatable, Sendable {
    case commandQ
    case commandTab
    case commandH
    case escapeCapture

    var reason: String {
        switch self {
        case .commandQ:
            return "Command-Q remains local until explicit system shortcut forwarding is enabled"
        case .commandTab:
            return "Command-Tab remains local until explicit system shortcut forwarding is enabled"
        case .commandH:
            return "Command-H remains local until explicit system shortcut forwarding is enabled"
        case .escapeCapture:
            return "Escape remains local while it exits remote pointer capture"
        }
    }

    var canBeForwarded: Bool {
        self != .escapeCapture
    }

    static func classify(
        rawKeyCode: UInt16,
        modifiers: InputModifiers,
        isDown: Bool
    ) -> MacReservedShortcut? {
        guard isDown, modifiers.contains(.command) else { return nil }
        switch rawKeyCode {
        case 12:
            return .commandQ
        case 48:
            return .commandTab
        case 4:
            return .commandH
        default:
            return nil
        }
    }
}

enum MacVirtualKeyTranslator {
    static func remoteKeyCode(for rawKeyCode: UInt16) -> UInt16? {
        switch rawKeyCode {
        case 0: return 0x41 // A
        case 1: return 0x53 // S
        case 2: return 0x44 // D
        case 3: return 0x46 // F
        case 4: return 0x48 // H
        case 5: return 0x47 // G
        case 6: return 0x5A // Z
        case 7: return 0x58 // X
        case 8: return 0x43 // C
        case 9: return 0x56 // V
        case 10: return 0xE2 // ISO section / OEM 102
        case 11: return 0x42 // B
        case 12: return 0x51 // Q
        case 13: return 0x57 // W
        case 14: return 0x45 // E
        case 15: return 0x52 // R
        case 16: return 0x59 // Y
        case 17: return 0x54 // T
        case 18: return 0x31
        case 19: return 0x32
        case 20: return 0x33
        case 21: return 0x34
        case 22: return 0x36
        case 23: return 0x35
        case 24: return 0xBB // Equals
        case 25: return 0x39
        case 26: return 0x37
        case 27: return 0xBD // Hyphen
        case 28: return 0x38
        case 29: return 0x30
        case 30: return 0xDD // Right bracket
        case 31: return 0x4F // O
        case 32: return 0x55 // U
        case 33: return 0xDB // Left bracket
        case 34: return 0x49 // I
        case 35: return 0x50 // P
        case 36: return 0x0D // Return
        case 37: return 0x4C // L
        case 38: return 0x4A // J
        case 39: return 0xDE // Apostrophe
        case 40: return 0x4B // K
        case 41: return 0xBA // Semicolon
        case 42: return 0xDC // Backslash
        case 43: return 0xBC // Comma
        case 44: return 0xBF // Slash
        case 45: return 0x4E // N
        case 46: return 0x4D // M
        case 47: return 0xBE // Period
        case 48: return 0x09 // Tab
        case 49: return 0x20 // Space
        case 50: return 0xC0 // Grave
        case 51: return 0x08 // Backspace
        case 53: return 0x1B // Escape
        case 54: return 0x5C // Right Command / Win
        case 55: return 0x5B // Left Command / Win
        case 56: return 0xA0 // Left Shift
        case 57: return 0x14 // Caps Lock
        case 58: return 0xA4 // Left Option / Alt
        case 59: return 0xA2 // Left Control
        case 60: return 0xA1 // Right Shift
        case 61: return 0xA5 // Right Option / Alt
        case 62: return 0xA3 // Right Control
        case 64: return 0x80 // F17
        case 65: return 0x6E // Keypad decimal
        case 67: return 0x6A // Keypad multiply
        case 69: return 0x6B // Keypad add
        case 71: return 0x90 // Keypad clear / Num Lock
        case 75: return 0x6F // Keypad divide
        case 76: return 0x0D // Keypad enter
        case 78: return 0x6D // Keypad subtract
        case 79: return 0x81 // F18
        case 80: return 0x82 // F19
        case 82: return 0x60
        case 83: return 0x61
        case 84: return 0x62
        case 85: return 0x63
        case 86: return 0x64
        case 87: return 0x65
        case 88: return 0x66
        case 89: return 0x67
        case 90: return 0x83 // F20
        case 91: return 0x68
        case 92: return 0x69
        case 96: return 0x74 // F5
        case 97: return 0x75 // F6
        case 98: return 0x76 // F7
        case 99: return 0x72 // F3
        case 100: return 0x77 // F8
        case 101: return 0x78 // F9
        case 103: return 0x7A // F11
        case 105: return 0x7C // F13
        case 106: return 0x7F // F16
        case 107: return 0x7D // F14
        case 109: return 0x79 // F10
        case 110: return 0x5D // Context Menu
        case 111: return 0x7B // F12
        case 113: return 0x7E // F15
        case 114: return 0x2F // Help
        case 115: return 0x24 // Home
        case 116: return 0x21 // Page Up
        case 117: return 0x2E // Forward Delete
        case 118: return 0x73 // F4
        case 119: return 0x23 // End
        case 120: return 0x71 // F2
        case 121: return 0x22 // Page Down
        case 122: return 0x70 // F1
        case 123: return 0x25 // Left Arrow
        case 124: return 0x27 // Right Arrow
        case 125: return 0x28 // Down Arrow
        case 126: return 0x26 // Up Arrow
        default: return nil
        }
    }
}

struct MacPointerSample: Codable, Equatable, Sendable {
    var localPoint: RemotePoint?
    var deltaX: Double
    var deltaY: Double
    var buttons: PointerButtonSet
}

struct MacScrollSample: Codable, Equatable, Sendable {
    var localPoint: RemotePoint?
    var deltaX: Double
    var deltaY: Double
}

struct MacInputAdapter: Sendable {
    var mapper: InputMapper
    var cursorPolicy: CursorCapturePolicy
    var forwardsSystemShortcuts = false

    func keyboard(_ sample: MacKeyboardSample) -> InputAdapterOutput {
        let reservedShortcut = sample.reservedShortcut
            ?? MacReservedShortcut.classify(
                rawKeyCode: sample.rawKeyCode,
                modifiers: sample.modifiers,
                isDown: sample.isDown
            )
        if let reservedShortcut,
           !forwardsSystemShortcuts || !reservedShortcut.canBeForwarded {
            return InputAdapterOutput(
                event: nil,
                policy: .reserveLocally(reason: reservedShortcut.reason)
            )
        }

        guard let remoteKeyCode = MacVirtualKeyTranslator.remoteKeyCode(
            for: sample.rawKeyCode
        ) else {
            return InputAdapterOutput(
                event: nil,
                policy: .drop(reason: "The macOS virtual key has no supported remote mapping")
            )
        }

        return InputAdapterOutput(
            event: .keyboard(KeyboardInputEvent(
                rawKeyCode: remoteKeyCode,
                characters: sample.characters,
                isDown: sample.isDown,
                modifiers: sample.modifiers,
                isRepeat: sample.isRepeat
            )),
            policy: .deliver
        )
    }

    func pointerMove(_ sample: MacPointerSample) -> InputAdapterOutput {
        if cursorPolicy.capturesRelativePointer {
            return InputAdapterOutput(
                event: .pointer(.relativeMove(deltaX: sample.deltaX, deltaY: sample.deltaY, buttons: sample.buttons)),
                policy: .deliver
            )
        }

        guard let localPoint = sample.localPoint,
              let remotePoint = mapper.remotePoint(localX: localPoint.x, localY: localPoint.y)
        else {
            return InputAdapterOutput(event: nil, policy: .drop(reason: "Pointer is outside a drawable video region"))
        }

        return InputAdapterOutput(
            event: .pointer(.absoluteMove(
                point: remotePoint,
                referenceSize: mapper.snapshot.sourceSize,
                buttons: sample.buttons
            )),
            policy: .deliver
        )
    }

    func button(_ button: PointerButton, isDown: Bool, localPoint: RemotePoint?) -> InputAdapterOutput {
        let remotePoint = localPoint.flatMap { mapper.remotePoint(localX: $0.x, localY: $0.y) }
        return InputAdapterOutput(
            event: .pointer(.button(button: button, isDown: isDown, point: remotePoint)),
            policy: .deliver
        )
    }

    func scroll(_ sample: MacScrollSample) -> InputAdapterOutput {
        let remotePoint = sample.localPoint.flatMap { mapper.remotePoint(localX: $0.x, localY: $0.y) }
        return InputAdapterOutput(
            event: .pointer(.scroll(deltaX: sample.deltaX, deltaY: sample.deltaY, point: remotePoint)),
            policy: .deliver
        )
    }

}
