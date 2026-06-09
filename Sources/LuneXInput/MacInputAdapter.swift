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
        if let reason = reservedShortcutReason(for: sample), !forwardsSystemShortcuts {
            return InputAdapterOutput(event: nil, policy: .reserveLocally(reason: reason))
        }

        return InputAdapterOutput(
            event: .keyboard(KeyboardInputEvent(
                rawKeyCode: sample.rawKeyCode,
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
            event: .pointer(.absoluteMove(point: remotePoint, buttons: sample.buttons)),
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

    private func reservedShortcutReason(for sample: MacKeyboardSample) -> String? {
        guard sample.isDown, sample.modifiers.contains(.command) else { return nil }

        switch sample.rawKeyCode {
        case 12:
            return "Command-Q remains local until explicit system shortcut forwarding is enabled"
        case 48:
            return "Command-Tab remains local until explicit system shortcut forwarding is enabled"
        case 4:
            return "Command-H remains local until explicit system shortcut forwarding is enabled"
        default:
            return nil
        }
    }
}
