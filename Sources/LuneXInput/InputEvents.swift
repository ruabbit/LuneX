import Foundation

enum RemoteInputEvent: Equatable, Sendable {
    case keyboard(KeyboardInputEvent)
    case pointer(PointerInputEvent)
    case touch(TouchInputEvent)
    case clipboard(ClipboardInputEvent)
    case virtualController(VirtualControllerInputEvent)
    case gameController(GameControllerInputEvent)
    case controllerConnected(ControllerConnectionInputEvent)
    case controllerDisconnected(controllerID: String)
    case controllerMotion(ControllerMotionInputEvent)
    case controllerBattery(ControllerBatteryInputEvent)
    case controllerState(RemoteControllerState)
    case controllerArrival(RemoteControllerArrival)
    case controllerMotionState(RemoteControllerMotion)
    case controllerBatteryState(RemoteControllerBattery)
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
    case absoluteMove(point: RemotePoint, referenceSize: PixelSize, buttons: PointerButtonSet)
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
    var referenceSize: PixelSize
}

struct ClipboardInputEvent: Codable, Equatable, Hashable, Sendable {
    var text: String
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

enum RemoteControllerType: UInt8, Codable, Equatable, Hashable, Sendable {
    case unknown = 0
    case xbox = 1
    case playStation = 2
    case nintendo = 3
}

struct RemoteControllerCapabilities: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt16

    static let analogTriggers = RemoteControllerCapabilities(rawValue: 1 << 0)
    static let rumble = RemoteControllerCapabilities(rawValue: 1 << 1)
    static let triggerRumble = RemoteControllerCapabilities(rawValue: 1 << 2)
    static let touchpad = RemoteControllerCapabilities(rawValue: 1 << 3)
    static let accelerometer = RemoteControllerCapabilities(rawValue: 1 << 4)
    static let gyroscope = RemoteControllerCapabilities(rawValue: 1 << 5)
    static let battery = RemoteControllerCapabilities(rawValue: 1 << 6)
    static let rgbLED = RemoteControllerCapabilities(rawValue: 1 << 7)
    static let dualTouchpad = RemoteControllerCapabilities(rawValue: 1 << 8)
}

struct RemoteControllerButtonFlags: OptionSet, Codable, Hashable, Sendable {
    let rawValue: UInt32

    static let dpadUp = RemoteControllerButtonFlags(rawValue: 0x0000_0001)
    static let dpadDown = RemoteControllerButtonFlags(rawValue: 0x0000_0002)
    static let dpadLeft = RemoteControllerButtonFlags(rawValue: 0x0000_0004)
    static let dpadRight = RemoteControllerButtonFlags(rawValue: 0x0000_0008)
    static let menu = RemoteControllerButtonFlags(rawValue: 0x0000_0010)
    static let options = RemoteControllerButtonFlags(rawValue: 0x0000_0020)
    static let leftThumbstick = RemoteControllerButtonFlags(rawValue: 0x0000_0040)
    static let rightThumbstick = RemoteControllerButtonFlags(rawValue: 0x0000_0080)
    static let leftShoulder = RemoteControllerButtonFlags(rawValue: 0x0000_0100)
    static let rightShoulder = RemoteControllerButtonFlags(rawValue: 0x0000_0200)
    static let a = RemoteControllerButtonFlags(rawValue: 0x0000_1000)
    static let b = RemoteControllerButtonFlags(rawValue: 0x0000_2000)
    static let x = RemoteControllerButtonFlags(rawValue: 0x0000_4000)
    static let y = RemoteControllerButtonFlags(rawValue: 0x0000_8000)

    static let standard: RemoteControllerButtonFlags = [
        .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
        .menu, .options, .leftThumbstick, .rightThumbstick,
        .leftShoulder, .rightShoulder, .a, .b, .x, .y
    ]
}

struct ControllerConnectionInputEvent: Codable, Equatable, Hashable, Sendable {
    var controllerID: String
    var playerIndex: Int?
    var type: RemoteControllerType
    var capabilities: RemoteControllerCapabilities
    var supportedButtons: RemoteControllerButtonFlags
}

enum ControllerMotionType: UInt8, Codable, Equatable, Hashable, Sendable {
    case accelerometer = 1
    case gyroscope = 2
}

struct ControllerMotionInputEvent: Codable, Equatable, Hashable, Sendable {
    var controllerID: String
    var type: ControllerMotionType
    var x: Float
    var y: Float
    var z: Float
}

enum ControllerBatteryState: UInt8, Codable, Equatable, Hashable, Sendable {
    case unknown = 0
    case notPresent = 1
    case discharging = 2
    case charging = 3
    case connectedNotCharging = 4
    case full = 5
}

struct ControllerBatteryInputEvent: Codable, Equatable, Hashable, Sendable {
    static let unknownPercentage: UInt8 = .max

    var controllerID: String
    var state: ControllerBatteryState
    var percentage: UInt8
}

struct RemoteControllerState: Equatable, Hashable, Sendable {
    var controllerIndex: UInt8
    var activeGamepadMask: UInt16
    var buttons: RemoteControllerButtonFlags
    var leftTrigger: UInt8
    var rightTrigger: UInt8
    var leftStickX: Int16
    var leftStickY: Int16
    var rightStickX: Int16
    var rightStickY: Int16

    static func empty(controllerIndex: UInt8, activeGamepadMask: UInt16) -> RemoteControllerState {
        RemoteControllerState(
            controllerIndex: controllerIndex,
            activeGamepadMask: activeGamepadMask,
            buttons: [],
            leftTrigger: 0,
            rightTrigger: 0,
            leftStickX: 0,
            leftStickY: 0,
            rightStickX: 0,
            rightStickY: 0
        )
    }
}

struct RemoteControllerArrival: Equatable, Hashable, Sendable {
    var controllerIndex: UInt8
    var type: RemoteControllerType
    var capabilities: RemoteControllerCapabilities
    var supportedButtons: RemoteControllerButtonFlags
}

struct RemoteControllerMotion: Equatable, Hashable, Sendable {
    var controllerIndex: UInt8
    var type: ControllerMotionType
    var x: Float
    var y: Float
    var z: Float
}

struct RemoteControllerBattery: Equatable, Hashable, Sendable {
    var controllerIndex: UInt8
    var state: ControllerBatteryState
    var percentage: UInt8
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
