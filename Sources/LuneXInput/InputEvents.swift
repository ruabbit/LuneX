import Foundation

enum RemoteInputEvent: Equatable, Sendable {
    case keyboard(KeyboardInputEvent)
    case pointer(PointerInputEvent)
    case touch(TouchInputEvent)
    case virtualController(VirtualControllerInputEvent)
    case gameController(GameControllerInputEvent)
    case tvRemote(TVRemoteInputEvent)
    case focus(FocusInputEvent)
}

struct InputModifiers: OptionSet, Codable, Hashable, Sendable {
    let rawValue: Int

    static let shift = InputModifiers(rawValue: 1 << 0)
    static let control = InputModifiers(rawValue: 1 << 1)
    static let option = InputModifiers(rawValue: 1 << 2)
    static let command = InputModifiers(rawValue: 1 << 3)
    static let capsLock = InputModifiers(rawValue: 1 << 4)
}

struct KeyboardInputEvent: Codable, Equatable, Hashable, Sendable {
    var rawKeyCode: UInt16
    var characters: String?
    var isDown: Bool
    var modifiers: InputModifiers
    var isRepeat: Bool
}

enum PointerButton: String, Codable, Hashable, Sendable {
    case left
    case right
    case middle
    case back
    case forward
}

struct PointerButtonSet: OptionSet, Codable, Hashable, Sendable {
    let rawValue: Int

    static let left = PointerButtonSet(rawValue: 1 << 0)
    static let right = PointerButtonSet(rawValue: 1 << 1)
    static let middle = PointerButtonSet(rawValue: 1 << 2)
    static let back = PointerButtonSet(rawValue: 1 << 3)
    static let forward = PointerButtonSet(rawValue: 1 << 4)
}

enum PointerInputEvent: Equatable, Sendable {
    case absoluteMove(point: RemotePoint, buttons: PointerButtonSet)
    case relativeMove(deltaX: Double, deltaY: Double, buttons: PointerButtonSet)
    case button(button: PointerButton, isDown: Bool, point: RemotePoint?)
    case scroll(deltaX: Double, deltaY: Double, point: RemotePoint?)
}

enum TouchPhase: String, Codable, Hashable, Sendable {
    case began
    case moved
    case ended
    case cancelled
}

struct TouchInputEvent: Codable, Equatable, Hashable, Sendable {
    var id: Int
    var phase: TouchPhase
    var point: RemotePoint
    var pressure: Double
}

enum VirtualControllerControl: String, Codable, Hashable, Sendable {
    case a
    case b
    case x
    case y
    case leftShoulder
    case rightShoulder
    case leftTrigger
    case rightTrigger
    case menu
    case options
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case leftThumbstick
    case rightThumbstick
}

struct VirtualControllerInputEvent: Codable, Equatable, Hashable, Sendable {
    var control: VirtualControllerControl
    var value: Double
    var isPressed: Bool
}

enum GameControllerElement: String, Codable, Hashable, Sendable {
    case a
    case b
    case x
    case y
    case leftShoulder
    case rightShoulder
    case leftTrigger
    case rightTrigger
    case menu
    case options
    case dpadUp
    case dpadDown
    case dpadLeft
    case dpadRight
    case leftThumbstickX
    case leftThumbstickY
    case rightThumbstickX
    case rightThumbstickY
    case leftThumbstickButton
    case rightThumbstickButton
}

struct GameControllerInputEvent: Codable, Equatable, Hashable, Sendable {
    var controllerID: String
    var playerIndex: Int?
    var element: GameControllerElement
    var value: Double
    var isPressed: Bool
}

enum TVRemoteButton: String, Codable, Hashable, Sendable {
    case menu
    case select
    case playPause
    case up
    case down
    case left
    case right
}

struct TVRemoteInputEvent: Codable, Equatable, Hashable, Sendable {
    var button: TVRemoteButton
    var isDown: Bool
}

enum FocusMovementDirection: String, Codable, Hashable, Sendable {
    case up
    case down
    case left
    case right
    case next
    case previous
}

struct FocusInputEvent: Codable, Equatable, Hashable, Sendable {
    var focusedItemID: String?
    var movement: FocusMovementDirection?
    var isFocused: Bool
}

enum InputDeliveryPolicy: Equatable, Sendable {
    case deliver
    case reserveLocally(reason: String)
    case drop(reason: String)
}

struct InputAdapterOutput: Equatable, Sendable {
    var event: RemoteInputEvent?
    var policy: InputDeliveryPolicy
}
