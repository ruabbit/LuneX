import Foundation

@MainActor
protocol MacCursorSystemOperating: Sendable {
    func hideCursor()
    func unhideCursor()
    func setPointerAssociation(enabled: Bool) -> Bool
}

struct MacCursorCaptureSnapshot: Equatable, Sendable {
    var ownsHiddenCursor: Bool
    var ownsPointerDisassociation: Bool
    var transitionFailureCount: UInt64
}

@MainActor
final class MacCursorCaptureOwner {
    private let operations: any MacCursorSystemOperating
    private var ownsHiddenCursor = false
    private var ownsPointerDisassociation = false
    private var transitionFailureCount: UInt64 = 0

    init(operations: any MacCursorSystemOperating) {
        self.operations = operations
    }

    @discardableResult
    func apply(_ policy: CursorCapturePolicy) -> Bool {
        let shouldHide = policy.hidesSystemCursor
            || policy.capturesRelativePointer
        var succeeded = true

        if policy.capturesRelativePointer && !ownsPointerDisassociation {
            if operations.setPointerAssociation(enabled: false) {
                ownsPointerDisassociation = true
            } else {
                transitionFailureCount &+= 1
                return false
            }
        } else if !policy.capturesRelativePointer && ownsPointerDisassociation {
            if operations.setPointerAssociation(enabled: true) {
                ownsPointerDisassociation = false
            } else {
                transitionFailureCount &+= 1
                succeeded = false
            }
        }

        if shouldHide && !ownsHiddenCursor {
            operations.hideCursor()
            ownsHiddenCursor = true
        }

        if !shouldHide && ownsHiddenCursor {
            operations.unhideCursor()
            ownsHiddenCursor = false
        }
        return succeeded
    }

    @discardableResult
    func releaseCapture() -> Bool {
        apply(CursorCapturePolicy(
            hidesSystemCursor: false,
            capturesRelativePointer: false,
            usesRemotePointer: false,
            reason: "Capture released"
        ))
    }

    func snapshot() -> MacCursorCaptureSnapshot {
        MacCursorCaptureSnapshot(
            ownsHiddenCursor: ownsHiddenCursor,
            ownsPointerDisassociation: ownsPointerDisassociation,
            transitionFailureCount: transitionFailureCount
        )
    }
}

#if os(macOS)
import AppKit
import CoreGraphics

@MainActor
final class AppKitCursorSystemOperations: MacCursorSystemOperating {
    func hideCursor() {
        NSCursor.hide()
    }

    func unhideCursor() {
        NSCursor.unhide()
    }

    func setPointerAssociation(enabled: Bool) -> Bool {
        CGAssociateMouseAndMouseCursorPosition(enabled ? 1 : 0) == .success
    }
}
#endif
