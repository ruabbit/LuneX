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
    case feedbackApplicationFailed
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
    let platform: TVVisionPlatform
    private var entries: [TVGameControllerDeviceToken: Entry] = [:]
    private var nextLeaseGeneration: UInt64? = 1

    init(
        inputGeneration: TVVisionGeneration,
        platform: TVVisionPlatform = .tvOS
    ) throws {
        try inputGeneration.require(.input)
        self.inputGeneration = inputGeneration
        self.platform = platform
    }

    var roster: TVControllerRosterSnapshot {
        get throws { try makeRoster() }
    }

    func lease(
        for token: TVGameControllerDeviceToken
    ) -> TVVisionControllerLease? {
        entries[token]?.lease
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
            platform: platform,
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

struct TVGameControllerRoutingIdentity: Equatable, Hashable, Sendable {
    let lease: TVVisionControllerLease

    var rawValue: String {
        [
            lease.platform == .tvOS ? "tv" : "vision",
            String(lease.inputGeneration.rawValue),
            String(lease.leaseGeneration.rawValue),
            String(lease.slot.rawValue)
        ].joined(separator: ":")
    }
}

enum TVGameControllerRosterRouter {
    static func reconcile(
        previous: TVControllerRosterSnapshot?,
        current: TVControllerRosterSnapshot
    ) -> ControllerRosterInputEvent {
        let currentLeases = Dictionary(uniqueKeysWithValues: current.controllers.map {
            ($0.lease.slot, $0.lease)
        })
        let disconnected = previous?.controllers.compactMap { controller -> String? in
            guard currentLeases[controller.lease.slot] != controller.lease else {
                return nil
            }
            return TVGameControllerRoutingIdentity(
                lease: controller.lease
            ).rawValue
        } ?? []
        let controllers = current.controllers.map { controller in
            ControllerCompleteStateInputEvent(
                connection: ControllerConnectionInputEvent(
                    controllerID: TVGameControllerRoutingIdentity(
                        lease: controller.lease
                    ).rawValue,
                    playerIndex: nil,
                    preferredControllerIndex: controller.lease.slot.rawValue,
                    type: .unknown,
                    capabilities: controller.lease.capabilities,
                    supportedButtons: controller.supportedButtons
                ),
                state: controller.state
            )
        }
        return ControllerRosterInputEvent(
            disconnectedControllerIDs: disconnected,
            controllers: controllers
        )
    }

    static func lease(
        matching remoteControllerID: String,
        in roster: TVControllerRosterSnapshot
    ) -> TVVisionControllerLease? {
        roster.controllers.first {
            TVGameControllerRoutingIdentity(lease: $0.lease).rawValue
                == remoteControllerID
        }?.lease
    }
}

struct TVGameControllerMotionSample: Equatable, Sendable {
    let lease: TVVisionControllerLease
    let type: ControllerMotionType
    let x: Float
    let y: Float
    let z: Float

    init(
        lease: TVVisionControllerLease,
        type: ControllerMotionType,
        x: Float,
        y: Float,
        z: Float
    ) throws {
        guard (lease.platform == .tvOS || lease.platform == .visionOS),
              [x, y, z].allSatisfy(\.isFinite) else {
            throw TVGameControllerRuntimeError.invalidCompleteState
        }
        self.lease = lease
        self.type = type
        self.x = x
        self.y = y
        self.z = z
    }

    var remoteEvent: RemoteInputEvent {
        .controllerMotion(ControllerMotionInputEvent(
            controllerID: TVGameControllerRoutingIdentity(lease: lease).rawValue,
            type: type,
            x: x,
            y: y,
            z: z
        ))
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

#if canImport(GameController) && (os(tvOS) || os(visionOS))
import GameController
import CoreHaptics

private final class MainQueueGameControllerReference: @unchecked Sendable {
    let controller: GCController

    init(_ controller: GCController) {
        self.controller = controller
    }
}

@MainActor
private final class TVGameControllerHapticsRuntime {
    private enum Channel: Hashable {
        case primary
        case leftTrigger
        case rightTrigger
    }

    private struct Playback {
        let engine: CHHapticEngine
        let player: any CHHapticAdvancedPatternPlayer
    }

    private let haptics: GCDeviceHaptics
    private var playbacks: [Channel: Playback] = [:]

    init(haptics: GCDeviceHaptics) {
        self.haptics = haptics
    }

    func applyRumble(lowFrequency: Float, highFrequency: Float) throws {
        let total = lowFrequency + highFrequency
        let intensity = max(lowFrequency, highFrequency)
        let sharpness = total > 0 ? highFrequency / total : 0
        try play(
            channel: .primary,
            locality: .default,
            intensity: intensity,
            sharpness: sharpness
        )
    }

    func applyTriggerRumble(leftMotor: Float, rightMotor: Float) throws {
        try play(
            channel: .leftTrigger,
            locality: .leftTrigger,
            intensity: leftMotor,
            sharpness: 0.5
        )
        try play(
            channel: .rightTrigger,
            locality: .rightTrigger,
            intensity: rightMotor,
            sharpness: 0.5
        )
    }

    func stopAll() {
        for channel in Array(playbacks.keys) {
            stop(channel)
        }
    }

    private func play(
        channel: Channel,
        locality: GCHapticsLocality,
        intensity: Float,
        sharpness: Float
    ) throws {
        stop(channel)
        guard intensity > 0 else { return }
        guard haptics.supportedLocalities.contains(locality),
              let engine = haptics.createEngine(withLocality: locality) else {
            throw TVGameControllerRuntimeError.feedbackApplicationFailed
        }
        let event = CHHapticEvent(
            eventType: .hapticContinuous,
            parameters: [
                CHHapticEventParameter(
                    parameterID: .hapticIntensity,
                    value: intensity
                ),
                CHHapticEventParameter(
                    parameterID: .hapticSharpness,
                    value: sharpness
                )
            ],
            relativeTime: 0,
            duration: 1
        )
        let pattern = try CHHapticPattern(events: [event], parameters: [])
        let player = try engine.makeAdvancedPlayer(with: pattern)
        player.loopEnabled = true
        do {
            try engine.start()
            try player.start(atTime: CHHapticTimeImmediate)
            playbacks[channel] = Playback(engine: engine, player: player)
        } catch {
            try? player.stop(atTime: CHHapticTimeImmediate)
            engine.stop(completionHandler: nil)
            throw error
        }
    }

    private func stop(_ channel: Channel) {
        guard let playback = playbacks.removeValue(forKey: channel) else {
            return
        }
        try? playback.player.stop(atTime: CHHapticTimeImmediate)
        playback.engine.stop(completionHandler: nil)
    }
}

@MainActor
final class TVGameControllerRuntimeOwner {
    typealias RosterHandler = @MainActor (TVControllerRosterSnapshot) -> Void
    typealias MotionHandler = @MainActor (TVGameControllerMotionSample) -> Void

    private struct Binding {
        let controller: GCController
        let token: TVGameControllerDeviceToken
        let lease: TVVisionControllerLease
        let previousHandlerQueue: DispatchQueue
        let profile: TVVisionControllerProfile
        let previousExtendedHandler: GCExtendedGamepadValueChangedHandler?
        let previousMicroHandler: GCMicroGamepadValueChangedHandler?
        let previousMotionHandler: GCMotionValueChangedHandler?
        let previousMotionSensorsActive: Bool
        let hapticsRuntime: TVGameControllerHapticsRuntime?
        var motionRates: [ControllerMotionType: Int] = [:]
        var lastMotionDeliveryNanoseconds: [ControllerMotionType: UInt64] = [:]
    }

    private var observers: [NSObjectProtocol] = []
    private var notificationCenter: NotificationCenter?
    private var bindings: [ObjectIdentifier: Binding] = [:]
    private var runtime: TVGameControllerSlotRuntime?
    private var rosterHandler: RosterHandler = { _ in }
    private var motionHandler: MotionHandler = { _ in }
    private var nextDeviceToken: UInt64? = 1
    private(set) var latestRoster: TVControllerRosterSnapshot?
    private(set) var latestFailure: TVGameControllerRuntimeError?

    func start(
        inputGeneration: TVVisionGeneration,
        platform: TVVisionPlatform = .tvOS,
        notificationCenter: NotificationCenter = .default,
        rosterHandler: @escaping RosterHandler,
        motionHandler: @escaping MotionHandler = { _ in }
    ) throws {
        stop()
        runtime = try TVGameControllerSlotRuntime(
            inputGeneration: inputGeneration,
            platform: platform
        )
        self.notificationCenter = notificationCenter
        self.rosterHandler = rosterHandler
        self.motionHandler = motionHandler
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
        motionHandler = { _ in }
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
        let previousExtendedHandler = controller.extendedGamepad?.valueChangedHandler
        let previousMicroHandler = controller.microGamepad?.valueChangedHandler
        let previousMotionHandler = controller.motion?.valueChangedHandler
        let previousMotionSensorsActive = controller.motion?.sensorsActive ?? false
        let capabilities = Self.capabilities(controller: controller)

        do {
            let profile: TVVisionControllerProfile
            if let gamepad = controller.extendedGamepad {
                let supportedButtons = Self.supportedButtons(gamepad)
                let completeState = try Self.completeState(gamepad)
                _ = try runtime.connect(
                    token: token,
                    profile: .extendedGamepad,
                    capabilities: capabilities.union(.analogTriggers),
                    supportedButtons: supportedButtons,
                    completeState: completeState
                )
                profile = .extendedGamepad
            } else if let gamepad = controller.microGamepad {
                let supportedButtons = Self.supportedButtons(gamepad)
                let completeState = try Self.completeState(gamepad)
                _ = try runtime.connect(
                    token: token,
                    profile: .microGamepad,
                    capabilities: capabilities,
                    supportedButtons: supportedButtons,
                    completeState: completeState
                )
                profile = .microGamepad
            } else {
                controller.handlerQueue = previousHandlerQueue
                return
            }
            guard let lease = runtime.lease(for: token) else {
                throw TVGameControllerRuntimeError.deviceUnavailable(token.rawValue)
            }
            let binding = Binding(
                controller: controller,
                token: token,
                lease: lease,
                previousHandlerQueue: previousHandlerQueue,
                profile: profile,
                previousExtendedHandler: previousExtendedHandler,
                previousMicroHandler: previousMicroHandler,
                previousMotionHandler: previousMotionHandler,
                previousMotionSensorsActive: previousMotionSensorsActive,
                hapticsRuntime: controller.haptics.map(
                    TVGameControllerHapticsRuntime.init
                )
            )
            self.runtime = runtime
            bindings[identity] = binding
            installHandlers(for: binding)
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

    func applyFeedback(
        _ request: TVControllerFeedbackRequest
    ) -> TVControllerFeedbackDecision {
        guard let roster = latestRoster else {
            return .unavailable(.controllerUnavailable)
        }
        let decision = TVControllerFeedbackResolver.resolve(
            request,
            roster: roster
        )
        guard case .apply = decision,
              let identity = bindings.first(where: {
                  $0.value.lease == request.lease
              })?.key,
              var binding = bindings[identity] else {
            return decision
        }
        do {
            switch request.payload {
            case let .rumble(lowFrequency, highFrequency):
                guard let haptics = binding.hapticsRuntime else {
                    return .unavailable(.unsupportedCapability)
                }
                try haptics.applyRumble(
                    lowFrequency: lowFrequency,
                    highFrequency: highFrequency
                )
            case let .triggerRumble(leftMotor, rightMotor):
                guard let haptics = binding.hapticsRuntime else {
                    return .unavailable(.unsupportedCapability)
                }
                try haptics.applyTriggerRumble(
                    leftMotor: leftMotor,
                    rightMotor: rightMotor
                )
            case let .led(red, green, blue):
                guard let light = binding.controller.light else {
                    return .unavailable(.unsupportedCapability)
                }
                light.color = GCColor(
                    red: Float(red) / Float(UInt8.max),
                    green: Float(green) / Float(UInt8.max),
                    blue: Float(blue) / Float(UInt8.max)
                )
            case let .motionRate(type, reportRateHz):
                if reportRateHz == 0 {
                    binding.motionRates[type] = nil
                    binding.lastMotionDeliveryNanoseconds[type] = nil
                } else {
                    binding.motionRates[type] = reportRateHz
                }
                if let motion = binding.controller.motion,
                   motion.sensorsRequireManualActivation {
                    motion.sensorsActive = !binding.motionRates.isEmpty
                }
                bindings[identity] = binding
            }
            latestFailure = nil
        } catch {
            binding.hapticsRuntime?.stopAll()
            latestFailure = .feedbackApplicationFailed
        }
        return decision
    }

    private func installHandlers(for binding: Binding) {
        switch binding.profile {
        case .extendedGamepad:
            binding.controller.extendedGamepad?.valueChangedHandler = {
                [weak self, weak controller = binding.controller] gamepad, _ in
                MainActor.assumeIsolated {
                    guard let controller else { return }
                    self?.handleExtendedChange(gamepad, controller: controller)
                }
            }
        case .microGamepad:
            binding.controller.microGamepad?.valueChangedHandler = {
                [weak self, weak controller = binding.controller] gamepad, _ in
                MainActor.assumeIsolated {
                    guard let controller else { return }
                    self?.handleMicroChange(gamepad, controller: controller)
                }
            }
        }
        binding.controller.motion?.valueChangedHandler = {
            [weak self, weak controller = binding.controller] motion in
            MainActor.assumeIsolated {
                guard let controller else { return }
                self?.handleMotionChange(motion, controller: controller)
            }
        }
    }

    private func handleMotionChange(
        _ motion: GCMotion,
        controller: GCController
    ) {
        let identity = ObjectIdentifier(controller)
        guard var binding = bindings[identity] else { return }
        let now = DispatchTime.now().uptimeNanoseconds
        for type in binding.motionRates.keys.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let rate = binding.motionRates[type], rate > 0 else { continue }
            let interval = UInt64(1_000_000_000 / rate)
            let previous = binding.lastMotionDeliveryNanoseconds[type] ?? 0
            guard previous == 0 || now &- previous >= interval else { continue }
            let vector: (Double, Double, Double)
            switch type {
            case .accelerometer:
                vector = (
                    motion.acceleration.x,
                    motion.acceleration.y,
                    motion.acceleration.z
                )
            case .gyroscope:
                vector = (
                    motion.rotationRate.x,
                    motion.rotationRate.y,
                    motion.rotationRate.z
                )
            }
            guard let sample = try? TVGameControllerMotionSample(
                lease: binding.lease,
                type: type,
                x: Float(vector.0),
                y: Float(vector.1),
                z: Float(vector.2)
            ) else { continue }
            binding.lastMotionDeliveryNanoseconds[type] = now
            motionHandler(sample)
        }
        bindings[identity] = binding
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
            binding.controller.extendedGamepad?.valueChangedHandler =
                binding.previousExtendedHandler
        case .microGamepad:
            binding.controller.microGamepad?.valueChangedHandler =
                binding.previousMicroHandler
        }
        if let motion = binding.controller.motion {
            motion.valueChangedHandler = binding.previousMotionHandler
            if motion.sensorsRequireManualActivation {
                motion.sensorsActive = binding.previousMotionSensorsActive
            }
        }
        binding.hapticsRuntime?.stopAll()
        binding.controller.handlerQueue = binding.previousHandlerQueue
    }

    private static func capabilities(
        controller: GCController
    ) -> RemoteControllerCapabilities {
        var capabilities: RemoteControllerCapabilities = []
        if let haptics = controller.haptics {
            capabilities.insert(.rumble)
            if haptics.supportedLocalities.contains(.leftTrigger),
               haptics.supportedLocalities.contains(.rightTrigger) {
                capabilities.insert(.triggerRumble)
            }
        }
        if controller.light != nil {
            capabilities.insert(.rgbLED)
        }
        if let motion = controller.motion {
            capabilities.insert(.accelerometer)
            if motion.hasRotationRate {
                capabilities.insert(.gyroscope)
            }
        }
        return capabilities
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
