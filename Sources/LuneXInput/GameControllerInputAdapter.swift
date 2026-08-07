import Foundation

struct GameControllerConnectionState: Codable, Equatable, Hashable, Sendable, Identifiable {
    var id: String
    var vendorName: String?
    var playerIndex: Int?
    var isConnected: Bool
    var supportsExtendedGamepad: Bool
    var supportsMicroGamepad: Bool
}

struct GameControllerElementSample: Codable, Equatable, Sendable {
    var controllerID: String
    var playerIndex: Int?
    var element: GameControllerElement
    var value: Double
}

struct GameControllerBindingSnapshot: Codable, Equatable, Sendable {
    var controllers: [GameControllerConnectionState]

    var connectedControllers: [GameControllerConnectionState] {
        controllers.filter(\.isConnected)
    }

    var remoteControllersBitmap: Int {
        connectedControllers.prefix(8).enumerated().reduce(0) { bitmap, entry in
            bitmap | (1 << entry.offset)
        }
    }
}

enum TVGameControllerRuntimeError: Error, Equatable, Sendable {
    case invalidDeviceToken
    case duplicateDeviceToken(UInt64)
    case deviceUnavailable(UInt64)
    case controllerCapacityExceeded
    case leaseGenerationExhausted
    case invalidCompleteState
}

struct TVGameControllerDeviceToken: Equatable, Hashable, Sendable {
    let rawValue: UInt64

    init(_ rawValue: UInt64) throws {
        guard rawValue > 0 else {
            throw TVGameControllerRuntimeError.invalidDeviceToken
        }
        self.rawValue = rawValue
    }
}

struct TVGameControllerCompleteState: Equatable, Sendable {
    let buttons: RemoteControllerButtonFlags
    let leftTrigger: Float
    let rightTrigger: Float
    let leftStickX: Float
    let leftStickY: Float
    let rightStickX: Float
    let rightStickY: Float

    init(
        buttons: RemoteControllerButtonFlags = [],
        leftTrigger: Float = 0,
        rightTrigger: Float = 0,
        leftStickX: Float = 0,
        leftStickY: Float = 0,
        rightStickX: Float = 0,
        rightStickY: Float = 0
    ) throws {
        let values = [
            leftTrigger,
            rightTrigger,
            leftStickX,
            leftStickY,
            rightStickX,
            rightStickY
        ]
        guard values.allSatisfy(\.isFinite) else {
            throw TVGameControllerRuntimeError.invalidCompleteState
        }
        self.buttons = buttons
        self.leftTrigger = min(max(leftTrigger, 0), 1)
        self.rightTrigger = min(max(rightTrigger, 0), 1)
        self.leftStickX = min(max(leftStickX, -1), 1)
        self.leftStickY = min(max(leftStickY, -1), 1)
        self.rightStickX = min(max(rightStickX, -1), 1)
        self.rightStickY = min(max(rightStickY, -1), 1)
    }

    fileprivate func remoteState(
        slot: TVVisionControllerSlot,
        activeGamepadMask: UInt16,
        profile: TVVisionControllerProfile,
        supportedButtons: RemoteControllerButtonFlags
    ) throws -> RemoteControllerState {
        guard buttons.intersection(supportedButtons) == buttons else {
            throw TVGameControllerRuntimeError.invalidCompleteState
        }
        if profile == .microGamepad,
           leftTrigger != 0 || rightTrigger != 0
            || leftStickX != 0 || leftStickY != 0
            || rightStickX != 0 || rightStickY != 0 {
            throw TVGameControllerRuntimeError.invalidCompleteState
        }
        return RemoteControllerState(
            controllerIndex: slot.rawValue,
            activeGamepadMask: activeGamepadMask,
            buttons: buttons,
            leftTrigger: Self.triggerValue(leftTrigger),
            rightTrigger: Self.triggerValue(rightTrigger),
            leftStickX: Self.stickValue(leftStickX),
            leftStickY: Self.stickValue(leftStickY),
            rightStickX: Self.stickValue(rightStickX),
            rightStickY: Self.stickValue(rightStickY)
        )
    }

    private static func triggerValue(_ value: Float) -> UInt8 {
        UInt8((Double(value) * Double(UInt8.max)).rounded(.toNearestOrAwayFromZero))
    }

    private static func stickValue(_ value: Float) -> Int16 {
        Int16((Double(value) * Double(Int16.max)).rounded(.toNearestOrAwayFromZero))
    }
}

struct TVGameControllerSlotRuntime: Sendable {
    private struct Entry: Sendable {
        let token: TVGameControllerDeviceToken
        let lease: TVVisionControllerLease
        let supportedButtons: RemoteControllerButtonFlags
        var completeState: TVGameControllerCompleteState
    }

    let inputGeneration: TVVisionGeneration
    private var entries: [TVGameControllerDeviceToken: Entry] = [:]
    private var nextLeaseGeneration: UInt64? = 1

    init(inputGeneration: TVVisionGeneration) throws {
        try inputGeneration.require(.input)
        self.inputGeneration = inputGeneration
    }

    var roster: TVControllerRosterSnapshot {
        get throws { try makeRoster() }
    }

    mutating func connect(
        token: TVGameControllerDeviceToken,
        profile: TVVisionControllerProfile,
        capabilities: RemoteControllerCapabilities,
        supportedButtons: RemoteControllerButtonFlags,
        completeState: TVGameControllerCompleteState
    ) throws -> TVControllerRosterSnapshot {
        guard entries[token] == nil else {
            throw TVGameControllerRuntimeError.duplicateDeviceToken(token.rawValue)
        }
        guard entries.count < TVVisionControllerSlot.maximumCount else {
            throw TVGameControllerRuntimeError.controllerCapacityExceeded
        }
        guard let rawLeaseGeneration = nextLeaseGeneration else {
            throw TVGameControllerRuntimeError.leaseGenerationExhausted
        }
        let occupiedSlots = Set(entries.values.map(\.lease.slot.rawValue))
        guard let slotValue = (0..<TVVisionControllerSlot.maximumCount).first(where: {
            !occupiedSlots.contains(UInt8($0))
        }) else {
            throw TVGameControllerRuntimeError.controllerCapacityExceeded
        }
        let slot = try TVVisionControllerSlot(slotValue)
        let lease = try TVVisionControllerLease(
            platform: .tvOS,
            leaseGeneration: TVVisionGeneration(
                domain: .controller,
                rawValue: rawLeaseGeneration
            ),
            inputGeneration: inputGeneration,
            slot: slot,
            profile: profile,
            capabilities: capabilities
        )
        var candidate = self
        candidate.entries[token] = Entry(
            token: token,
            lease: lease,
            supportedButtons: supportedButtons,
            completeState: completeState
        )
        candidate.nextLeaseGeneration = rawLeaseGeneration == UInt64.max
            ? nil
            : rawLeaseGeneration + 1
        let roster = try candidate.makeRoster()
        self = candidate
        return roster
    }

    mutating func update(
        token: TVGameControllerDeviceToken,
        completeState: TVGameControllerCompleteState
    ) throws -> TVControllerRosterSnapshot {
        guard var entry = entries[token] else {
            throw TVGameControllerRuntimeError.deviceUnavailable(token.rawValue)
        }
        var candidate = self
        entry.completeState = completeState
        candidate.entries[token] = entry
        let roster = try candidate.makeRoster()
        self = candidate
        return roster
    }

    mutating func disconnect(
        token: TVGameControllerDeviceToken
    ) throws -> TVControllerRosterSnapshot {
        guard entries[token] != nil else { return try makeRoster() }
        var candidate = self
        candidate.entries[token] = nil
        let roster = try candidate.makeRoster()
        self = candidate
        return roster
    }

    private func makeRoster() throws -> TVControllerRosterSnapshot {
        let activeGamepadMask = entries.values.reduce(UInt16(0)) { mask, entry in
            mask | (UInt16(1) << UInt16(entry.lease.slot.rawValue))
        }
        let controllers = try entries.values.map { entry in
            try TVControllerInputSnapshot(
                lease: entry.lease,
                supportedButtons: entry.supportedButtons,
                state: entry.completeState.remoteState(
                    slot: entry.lease.slot,
                    activeGamepadMask: activeGamepadMask,
                    profile: entry.lease.profile,
                    supportedButtons: entry.supportedButtons
                )
            )
        }
        return try TVControllerRosterSnapshot(
            inputGeneration: inputGeneration,
            controllers: controllers
        )
    }
}

struct GameControllerInputAdapter: Sendable {
    var pressedThreshold = 0.5

    func controllerElement(_ sample: GameControllerElementSample) -> InputAdapterOutput {
        guard sample.value.isFinite else {
            return InputAdapterOutput(
                event: nil,
                policy: .drop(reason: "Controller element value must be finite")
            )
        }
        return InputAdapterOutput(
            event: .gameController(GameControllerInputEvent(
                controllerID: sample.controllerID,
                playerIndex: sample.playerIndex,
                element: sample.element,
                value: normalizedValue(sample.value, for: sample.element),
                isPressed: isPressed(sample.value, for: sample.element)
            )),
            policy: .deliver
        )
    }

    func unsupportedElement(controllerID: String, elementName: String) -> InputAdapterOutput {
        InputAdapterOutput(
            event: nil,
            policy: .drop(reason: "Controller \(controllerID) element \(elementName) is not mapped")
        )
    }

    private func normalizedValue(_ value: Double, for element: GameControllerElement) -> Double {
        switch element {
        case .leftThumbstickX, .leftThumbstickY, .rightThumbstickX, .rightThumbstickY:
            return min(max(value, -1), 1)
        default:
            return min(max(value, 0), 1)
        }
    }

    private func isPressed(_ value: Double, for element: GameControllerElement) -> Bool {
        switch element {
        case .leftThumbstickX, .leftThumbstickY, .rightThumbstickX, .rightThumbstickY:
            return abs(value) >= pressedThreshold
        default:
            return value >= pressedThreshold
        }
    }
}

#if canImport(GameController) && os(tvOS)
import GameController

private final class MainQueueGameControllerReference: @unchecked Sendable {
    let controller: GCController

    init(_ controller: GCController) {
        self.controller = controller
    }
}

@MainActor
final class TVGameControllerRuntimeOwner {
    typealias RosterHandler = @MainActor (TVControllerRosterSnapshot) -> Void

    private struct Binding {
        let controller: GCController
        let token: TVGameControllerDeviceToken
        let previousHandlerQueue: DispatchQueue
        let profile: TVVisionControllerProfile
    }

    private var observers: [NSObjectProtocol] = []
    private var notificationCenter: NotificationCenter?
    private var bindings: [ObjectIdentifier: Binding] = [:]
    private var runtime: TVGameControllerSlotRuntime?
    private var rosterHandler: RosterHandler = { _ in }
    private var nextDeviceToken: UInt64? = 1
    private(set) var latestRoster: TVControllerRosterSnapshot?
    private(set) var latestFailure: TVGameControllerRuntimeError?

    func start(
        inputGeneration: TVVisionGeneration,
        notificationCenter: NotificationCenter = .default,
        rosterHandler: @escaping RosterHandler
    ) throws {
        stop()
        runtime = try TVGameControllerSlotRuntime(
            inputGeneration: inputGeneration
        )
        self.notificationCenter = notificationCenter
        self.rosterHandler = rosterHandler
        nextDeviceToken = 1
        latestFailure = nil

        observers = [
            notificationCenter.addObserver(
                forName: Notification.Name.GCControllerDidConnect,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard Thread.isMainThread,
                      let controller = notification.object as? GCController else {
                    return
                }
                let reference = MainQueueGameControllerReference(controller)
                MainActor.assumeIsolated {
                    self?.attach(reference.controller, publishesRoster: true)
                }
            },
            notificationCenter.addObserver(
                forName: Notification.Name.GCControllerDidDisconnect,
                object: nil,
                queue: .main
            ) { [weak self] notification in
                guard Thread.isMainThread,
                      let controller = notification.object as? GCController else {
                    return
                }
                let reference = MainQueueGameControllerReference(controller)
                MainActor.assumeIsolated {
                    self?.detach(reference.controller, publishesRoster: true)
                }
            }
        ]
        for controller in GCController.controllers() {
            attach(controller, publishesRoster: false)
        }
        publishCurrentRoster()
    }

    func stop() {
        if let notificationCenter {
            observers.forEach(notificationCenter.removeObserver)
        }
        observers.removeAll()
        for binding in bindings.values {
            clearHandler(binding)
        }
        bindings.removeAll()
        notificationCenter = nil
        runtime = nil
        rosterHandler = { _ in }
        nextDeviceToken = 1
        latestRoster = nil
        latestFailure = nil
    }

    private func attach(
        _ controller: GCController,
        publishesRoster: Bool
    ) {
        let identity = ObjectIdentifier(controller)
        guard bindings[identity] == nil,
              var runtime,
              let token = takeNextDeviceToken() else { return }
        let previousHandlerQueue = controller.handlerQueue
        controller.handlerQueue = .main

        do {
            let binding: Binding
            if let gamepad = controller.extendedGamepad {
                let supportedButtons = Self.supportedButtons(gamepad)
                let completeState = try Self.completeState(gamepad)
                _ = try runtime.connect(
                    token: token,
                    profile: .extendedGamepad,
                    capabilities: [.analogTriggers],
                    supportedButtons: supportedButtons,
                    completeState: completeState
                )
                binding = Binding(
                    controller: controller,
                    token: token,
                    previousHandlerQueue: previousHandlerQueue,
                    profile: .extendedGamepad
                )
                gamepad.valueChangedHandler = { [weak self, weak controller] gamepad, _ in
                    MainActor.assumeIsolated {
                        guard let controller else { return }
                        self?.handleExtendedChange(gamepad, controller: controller)
                    }
                }
            } else if let gamepad = controller.microGamepad {
                let supportedButtons = Self.supportedButtons(gamepad)
                let completeState = try Self.completeState(gamepad)
                _ = try runtime.connect(
                    token: token,
                    profile: .microGamepad,
                    capabilities: [],
                    supportedButtons: supportedButtons,
                    completeState: completeState
                )
                binding = Binding(
                    controller: controller,
                    token: token,
                    previousHandlerQueue: previousHandlerQueue,
                    profile: .microGamepad
                )
                gamepad.valueChangedHandler = { [weak self, weak controller] gamepad, _ in
                    MainActor.assumeIsolated {
                        guard let controller else { return }
                        self?.handleMicroChange(gamepad, controller: controller)
                    }
                }
            } else {
                controller.handlerQueue = previousHandlerQueue
                return
            }
            self.runtime = runtime
            bindings[identity] = binding
            if publishesRoster { publishCurrentRoster() }
        } catch let error as TVGameControllerRuntimeError {
            controller.handlerQueue = previousHandlerQueue
            latestFailure = error
        } catch {
            controller.handlerQueue = previousHandlerQueue
            latestFailure = .invalidCompleteState
        }
    }

    private func detach(
        _ controller: GCController,
        publishesRoster: Bool
    ) {
        let identity = ObjectIdentifier(controller)
        guard let binding = bindings.removeValue(forKey: identity),
              var runtime else { return }
        clearHandler(binding)
        do {
            _ = try runtime.disconnect(token: binding.token)
            self.runtime = runtime
            latestFailure = nil
            if publishesRoster { publishCurrentRoster() }
        } catch let error as TVGameControllerRuntimeError {
            latestFailure = error
        } catch {
            latestFailure = .invalidCompleteState
        }
    }

    private func handleExtendedChange(
        _ gamepad: GCExtendedGamepad,
        controller: GCController
    ) {
        update(
            controller: controller,
            expectedProfile: .extendedGamepad,
            completeState: { try Self.completeState(gamepad) }
        )
    }

    private func handleMicroChange(
        _ gamepad: GCMicroGamepad,
        controller: GCController
    ) {
        update(
            controller: controller,
            expectedProfile: .microGamepad,
            completeState: { try Self.completeState(gamepad) }
        )
    }

    private func update(
        controller: GCController,
        expectedProfile: TVVisionControllerProfile,
        completeState: () throws -> TVGameControllerCompleteState
    ) {
        let identity = ObjectIdentifier(controller)
        guard let binding = bindings[identity],
              binding.profile == expectedProfile,
              var runtime else { return }
        do {
            _ = try runtime.update(
                token: binding.token,
                completeState: completeState()
            )
            self.runtime = runtime
            latestFailure = nil
            publishCurrentRoster()
        } catch let error as TVGameControllerRuntimeError {
            latestFailure = error
        } catch {
            latestFailure = .invalidCompleteState
        }
    }

    private func publishCurrentRoster() {
        guard let runtime else { return }
        do {
            let roster = try runtime.roster
            guard roster != latestRoster else { return }
            latestRoster = roster
            rosterHandler(roster)
        } catch let error as TVGameControllerRuntimeError {
            latestFailure = error
        } catch {
            latestFailure = .invalidCompleteState
        }
    }

    private func clearHandler(_ binding: Binding) {
        switch binding.profile {
        case .extendedGamepad:
            binding.controller.extendedGamepad?.valueChangedHandler = nil
        case .microGamepad:
            binding.controller.microGamepad?.valueChangedHandler = nil
        }
        binding.controller.handlerQueue = binding.previousHandlerQueue
    }

    private func takeNextDeviceToken() -> TVGameControllerDeviceToken? {
        guard let rawValue = nextDeviceToken,
              let token = try? TVGameControllerDeviceToken(rawValue) else {
            return nil
        }
        nextDeviceToken = rawValue == UInt64.max ? nil : rawValue + 1
        return token
    }

    private static func supportedButtons(
        _ gamepad: GCExtendedGamepad
    ) -> RemoteControllerButtonFlags {
        var buttons: RemoteControllerButtonFlags = [
            .dpadUp, .dpadDown, .dpadLeft, .dpadRight,
            .menu, .leftShoulder, .rightShoulder, .a, .b, .x, .y
        ]
        if gamepad.buttonOptions != nil { buttons.insert(.options) }
        if gamepad.leftThumbstickButton != nil { buttons.insert(.leftThumbstick) }
        if gamepad.rightThumbstickButton != nil { buttons.insert(.rightThumbstick) }
        return buttons
    }

    private static func supportedButtons(
        _ gamepad: GCMicroGamepad
    ) -> RemoteControllerButtonFlags {
        _ = gamepad
        return [.dpadUp, .dpadDown, .dpadLeft, .dpadRight, .menu, .a, .x]
    }

    private static func completeState(
        _ gamepad: GCExtendedGamepad
    ) throws -> TVGameControllerCompleteState {
        var buttons: RemoteControllerButtonFlags = []
        set(&buttons, .dpadUp, gamepad.dpad.up.isPressed)
        set(&buttons, .dpadDown, gamepad.dpad.down.isPressed)
        set(&buttons, .dpadLeft, gamepad.dpad.left.isPressed)
        set(&buttons, .dpadRight, gamepad.dpad.right.isPressed)
        set(&buttons, .menu, gamepad.buttonMenu.isPressed)
        set(&buttons, .options, gamepad.buttonOptions?.isPressed == true)
        set(&buttons, .leftThumbstick, gamepad.leftThumbstickButton?.isPressed == true)
        set(&buttons, .rightThumbstick, gamepad.rightThumbstickButton?.isPressed == true)
        set(&buttons, .leftShoulder, gamepad.leftShoulder.isPressed)
        set(&buttons, .rightShoulder, gamepad.rightShoulder.isPressed)
        set(&buttons, .a, gamepad.buttonA.isPressed)
        set(&buttons, .b, gamepad.buttonB.isPressed)
        set(&buttons, .x, gamepad.buttonX.isPressed)
        set(&buttons, .y, gamepad.buttonY.isPressed)
        return try TVGameControllerCompleteState(
            buttons: buttons,
            leftTrigger: gamepad.leftTrigger.value,
            rightTrigger: gamepad.rightTrigger.value,
            leftStickX: gamepad.leftThumbstick.xAxis.value,
            leftStickY: gamepad.leftThumbstick.yAxis.value,
            rightStickX: gamepad.rightThumbstick.xAxis.value,
            rightStickY: gamepad.rightThumbstick.yAxis.value
        )
    }

    private static func completeState(
        _ gamepad: GCMicroGamepad
    ) throws -> TVGameControllerCompleteState {
        var buttons: RemoteControllerButtonFlags = []
        set(&buttons, .dpadUp, gamepad.dpad.up.isPressed)
        set(&buttons, .dpadDown, gamepad.dpad.down.isPressed)
        set(&buttons, .dpadLeft, gamepad.dpad.left.isPressed)
        set(&buttons, .dpadRight, gamepad.dpad.right.isPressed)
        set(&buttons, .menu, gamepad.buttonMenu.isPressed)
        set(&buttons, .a, gamepad.buttonA.isPressed)
        set(&buttons, .x, gamepad.buttonX.isPressed)
        return try TVGameControllerCompleteState(buttons: buttons)
    }

    private static func set(
        _ buttons: inout RemoteControllerButtonFlags,
        _ flag: RemoteControllerButtonFlags,
        _ enabled: Bool
    ) {
        if enabled { buttons.insert(flag) }
    }
}
#endif
