import Foundation

enum VisionNativeInputAdapterError: Error, Equatable, Sendable {
    case invalidSurfaceGeneration
    case invalidSystemInteractionDecision
    case unsupportedSurfacePath(VisionInputPath)
    case pathEventMismatch(VisionInputPath)
}

enum VisionSurfaceInputDisposition: Equatable, Sendable {
    case captured
    case local
}

struct VisionSurfaceInputEvent: Equatable, Sendable {
    let surfaceGeneration: TVVisionGeneration
    let path: VisionInputPath
    let event: RemoteInputEvent

    init(
        surfaceGeneration: TVVisionGeneration,
        path: VisionInputPath,
        event: RemoteInputEvent
    ) throws {
        do {
            try surfaceGeneration.require(.surface)
        } catch {
            throw VisionNativeInputAdapterError.invalidSurfaceGeneration
        }
        switch (path, event) {
        case (.keyboard, .keyboard),
             (.pointer, .pointer),
             (.indirectPointer, .pointer):
            break
        case (.extendedGamepad, _), (.microGamepad, _):
            throw VisionNativeInputAdapterError.unsupportedSurfacePath(path)
        default:
            throw VisionNativeInputAdapterError.pathEventMismatch(path)
        }
        self.surfaceGeneration = surfaceGeneration
        self.path = path
        self.event = event
    }
}

struct VisionSurfaceSystemInteractionEvent: Equatable, Sendable {
    let surfaceGeneration: TVVisionGeneration
    let decision: VisionSystemInteractionDecision

    init(
        surfaceGeneration: TVVisionGeneration,
        decision: VisionSystemInteractionDecision
    ) throws {
        do {
            try surfaceGeneration.require(.surface)
        } catch {
            throw VisionNativeInputAdapterError.invalidSurfaceGeneration
        }
        guard decision == VisionSystemInteractionDecision.resolve(
            decision.interaction
        ) else {
            throw VisionNativeInputAdapterError.invalidSystemInteractionDecision
        }
        self.surfaceGeneration = surfaceGeneration
        self.decision = decision
    }
}

struct VisionKeyboardSample: Equatable, Sendable {
    let hidUsage: UInt16
    let characters: String?
    let isDown: Bool
    let modifiers: InputModifiers
    let isRepeat: Bool
}

enum VisionKeyboardHIDTranslator {
    static func remoteKeyCode(for usage: UInt16) -> UInt16? {
        switch usage {
        case 0x04...0x1D:
            return 0x41 + usage - 0x04
        case 0x1E...0x26:
            return 0x31 + usage - 0x1E
        case 0x27: return 0x30
        case 0x28: return 0x0D
        case 0x29: return 0x1B
        case 0x2A: return 0x08
        case 0x2B: return 0x09
        case 0x2C: return 0x20
        case 0x2D: return 0xBD
        case 0x2E: return 0xBB
        case 0x2F: return 0xDB
        case 0x30: return 0xDD
        case 0x31: return 0xDC
        case 0x32, 0x64: return 0xE2
        case 0x33: return 0xBA
        case 0x34: return 0xDE
        case 0x35: return 0xC0
        case 0x36: return 0xBC
        case 0x37: return 0xBE
        case 0x38: return 0xBF
        case 0x39: return 0x14
        case 0x3A...0x45:
            return 0x70 + usage - 0x3A
        case 0x46: return 0x2C
        case 0x47: return 0x91
        case 0x48: return 0x13
        case 0x49: return 0x2D
        case 0x4A: return 0x24
        case 0x4B: return 0x21
        case 0x4C: return 0x2E
        case 0x4D: return 0x23
        case 0x4E: return 0x22
        case 0x4F: return 0x27
        case 0x50: return 0x25
        case 0x51: return 0x28
        case 0x52: return 0x26
        case 0x53: return 0x90
        case 0x54: return 0x6F
        case 0x55: return 0x6A
        case 0x56: return 0x6D
        case 0x57: return 0x6B
        case 0x58: return 0x0D
        case 0x59...0x61:
            return 0x61 + usage - 0x59
        case 0x62: return 0x60
        case 0x63: return 0x6E
        case 0x65: return 0x5D
        case 0x68...0x73:
            return 0x7C + usage - 0x68
        case 0xE0: return 0xA2
        case 0xE1: return 0xA0
        case 0xE2: return 0xA4
        case 0xE3: return 0x5B
        case 0xE4: return 0xA3
        case 0xE5: return 0xA1
        case 0xE6: return 0xA5
        case 0xE7: return 0x5C
        default: return nil
        }
    }

    static func reservedInteraction(
        usage: UInt16,
        modifiers: InputModifiers
    ) -> VisionSystemReservedInteraction? {
        switch usage {
        case 0x29:
            return .escape
        case 0x46:
            return .capture
        case 0x7F...0x81:
            return .volume
        default:
            break
        }
        if modifiers.contains([.command, .shift]),
           (0x20...0x22).contains(usage) {
            return .capture
        }
        guard modifiers.contains(.command) else { return nil }
        if usage == 0x14 || usage == 0x0B || usage == 0x2B {
            return .systemGesture
        }
        return nil
    }
}

enum VisionFirstResponderPolicy {
    static func shouldOwnInput(
        isKeyWindow: Bool,
        isUserInteractionEnabled: Bool,
        isVisible: Bool
    ) -> Bool {
        isKeyWindow && isUserInteractionEnabled && isVisible
    }
}

struct VisionNativeInputAdapter: Sendable {
    func keyboard(_ sample: VisionKeyboardSample) -> InputAdapterOutput {
        if let interaction = VisionKeyboardHIDTranslator.reservedInteraction(
            usage: sample.hidUsage,
            modifiers: sample.modifiers
        ) {
            let decision = VisionSystemInteractionDecision.resolve(interaction)
            return InputAdapterOutput(
                event: nil,
                policy: .reserveLocally(
                    reason: decision.interaction.rawValue
                )
            )
        }
        guard let keyCode = VisionKeyboardHIDTranslator.remoteKeyCode(
            for: sample.hidUsage
        ) else {
            return InputAdapterOutput(
                event: nil,
                policy: .drop(
                    reason: "The visionOS hardware key has no supported remote mapping"
                )
            )
        }
        return InputAdapterOutput(
            event: .keyboard(KeyboardInputEvent(
                rawKeyCode: keyCode,
                characters: sample.characters,
                isDown: sample.isDown,
                modifiers: sample.modifiers,
                isRepeat: sample.isRepeat
            )),
            policy: .deliver
        )
    }

    func absolutePointerMove(
        mapping: TVVisionStreamAbsoluteInputMapping?,
        buttons: PointerButtonSet
    ) -> InputAdapterOutput {
        guard let mapping else {
            return unavailablePointerOutput()
        }
        return InputAdapterOutput(
            event: .pointer(.absoluteMove(
                point: mapping.point,
                referenceSize: mapping.referenceSize,
                buttons: buttons
            )),
            policy: .deliver
        )
    }

    func pointerButton(
        _ button: PointerButton,
        isDown: Bool,
        mapping: TVVisionStreamAbsoluteInputMapping?
    ) -> InputAdapterOutput {
        guard mapping != nil || !isDown else {
            return unavailablePointerOutput()
        }
        return InputAdapterOutput(
            event: .pointer(.button(
                button: button,
                isDown: isDown,
                point: mapping?.point
            )),
            policy: .deliver
        )
    }

    func scroll(
        deltaX: Double,
        deltaY: Double,
        mapping: TVVisionStreamAbsoluteInputMapping?
    ) -> InputAdapterOutput {
        guard deltaX.isFinite, deltaY.isFinite else {
            return InputAdapterOutput(
                event: nil,
                policy: .drop(reason: "The visionOS scroll delta must be finite")
            )
        }
        guard let mapping else {
            return unavailablePointerOutput()
        }
        return InputAdapterOutput(
            event: .pointer(.scroll(
                deltaX: deltaX,
                deltaY: deltaY,
                point: mapping.point
            )),
            policy: .deliver
        )
    }

    private func unavailablePointerOutput() -> InputAdapterOutput {
        InputAdapterOutput(
            event: nil,
            policy: .drop(
                reason: "The visionOS pointer is outside current render geometry"
            )
        )
    }
}
