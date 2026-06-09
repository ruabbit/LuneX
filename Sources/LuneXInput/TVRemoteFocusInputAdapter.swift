import Foundation

struct TVRemoteSample: Codable, Equatable, Sendable {
    var button: TVRemoteButton
    var isDown: Bool
}

struct FocusSample: Codable, Equatable, Sendable {
    var focusedItemID: String?
    var movement: FocusMovementDirection?
    var isFocused: Bool
}

struct TVRemoteFocusInputAdapter: Sendable {
    var isStreamActive: Bool

    func remoteButton(_ sample: TVRemoteSample) -> InputAdapterOutput {
        guard isStreamActive else {
            return InputAdapterOutput(
                event: nil,
                policy: .reserveLocally(reason: "tvOS remote input remains local until a stream is active")
            )
        }

        return InputAdapterOutput(
            event: .tvRemote(TVRemoteInputEvent(button: sample.button, isDown: sample.isDown)),
            policy: .deliver
        )
    }

    func focus(_ sample: FocusSample) -> InputAdapterOutput {
        InputAdapterOutput(
            event: .focus(FocusInputEvent(
                focusedItemID: sample.focusedItemID,
                movement: sample.movement,
                isFocused: sample.isFocused
            )),
            policy: .deliver
        )
    }
}

#if os(tvOS)
import UIKit

enum TVRemotePressMapper {
    static func button(for pressType: UIPress.PressType) -> TVRemoteButton? {
        switch pressType {
        case .menu: .menu
        case .select: .select
        case .playPause: .playPause
        case .upArrow: .up
        case .downArrow: .down
        case .leftArrow: .left
        case .rightArrow: .right
        default: nil
        }
    }
}
#endif
