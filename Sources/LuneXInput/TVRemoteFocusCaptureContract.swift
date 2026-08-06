import Foundation

enum TVRemoteCaptureContractError: Error, Equatable, Sendable {
    case platformMismatch
    case invalidPressToken
    case pressGenerationMismatch
    case duplicatePressToken(UInt64)
    case duplicatePressedButton(TVRemoteButton)
    case pressCapacityExceeded
    case invalidActivePressState
    case controllerPlatformMismatch
    case controllerInputGenerationMismatch
    case controllerIndexMismatch
    case controllerMaskMismatch
    case unsupportedControllerButtons
    case invalidMicroGamepadState
    case duplicateControllerSlot(UInt8)
    case duplicateControllerLease(UInt64)
    case invalidFeedbackPayload
}

enum TVRemoteLocalOwnershipReason: String, Codable, Hashable, Sendable {
    case detached
    case sceneInactive = "scene-inactive"
    case notFocused = "not-focused"
    case overlayVisible = "overlay-visible"
    case inputUnavailable = "input-unavailable"
    case systemReserved = "system-reserved"
    case replacing
    case stopped
    case remoteCapabilityUnavailable = "remote-capability-unavailable"

    init(_ reason: TVVisionFocusIneligibilityReason) {
        switch reason {
        case .detached: self = .detached
        case .sceneInactive: self = .sceneInactive
        case .notFocused: self = .notFocused
        case .overlayVisible: self = .overlayVisible
        case .inputUnavailable: self = .inputUnavailable
        case .systemReserved: self = .systemReserved
        case .replacing: self = .replacing
        case .stopped: self = .stopped
        }
    }
}

enum TVRemoteCaptureOwnership: Equatable, Hashable, Sendable {
    case local(TVRemoteLocalOwnershipReason)
    case stream(inputGeneration: TVVisionGeneration)

    static func resolve(
        _ input: TVVisionInputCapabilitySnapshot
    ) throws -> TVRemoteCaptureOwnership {
        guard input.platform == .tvOS else {
            throw TVRemoteCaptureContractError.platformMismatch
        }
        guard input.supported.contains(.tvRemote) else {
            return .local(.remoteCapabilityUnavailable)
        }
        switch input.focusEligibility {
        case .eligible:
            return .stream(inputGeneration: input.inputGeneration)
        case let .ineligible(reason):
            return .local(TVRemoteLocalOwnershipReason(reason))
        }
    }
}

enum TVRemoteReservedCommand: String, Codable, CaseIterable, Hashable, Sendable {
    case backMenu = "back-menu"
    case home
    case volumeUp = "volume-up"
    case volumeDown = "volume-down"
    case capture
    case power
    case unsupported
}

enum TVRemoteReservedDisposition: String, Codable, Hashable, Sendable {
    case showOverlayOrExitCapture = "show-overlay-or-exit-capture"
    case deferToSystem = "defer-to-system"
    case ignoreLocally = "ignore-locally"

    static func resolve(
        _ command: TVRemoteReservedCommand
    ) -> TVRemoteReservedDisposition {
        switch command {
        case .backMenu:
            return .showOverlayOrExitCapture
        case .home, .volumeUp, .volumeDown, .capture, .power:
            return .deferToSystem
        case .unsupported:
            return .ignoreLocally
        }
    }
}

struct TVRemotePressToken: Equatable, Hashable, Sendable {
    let inputGeneration: TVVisionGeneration
    let rawValue: UInt64

    init(
        inputGeneration: TVVisionGeneration,
        rawValue: UInt64
    ) throws {
        try inputGeneration.require(.input)
        guard rawValue > 0 else {
            throw TVRemoteCaptureContractError.invalidPressToken
        }
        self.inputGeneration = inputGeneration
        self.rawValue = rawValue
    }
}

struct TVRemoteActivePress: Equatable, Hashable, Sendable {
    let token: TVRemotePressToken
    let button: TVRemoteButton
}

enum TVRemoteCaptureEffect: Equatable, Sendable {
    case openRemoteAdmission(inputGeneration: TVVisionGeneration)
    case closeRemoteAdmission(inputGeneration: TVVisionGeneration)
    case removeControllerHandlers([TVVisionControllerLease])
    case sendRemote(TVRemoteInputEvent)
    case awaitRemoteReleaseBarrier(inputGeneration: TVVisionGeneration)
    case restoreLocalFocus(TVRemoteLocalOwnershipReason)
    case reserveLocally(button: TVRemoteButton, reason: TVRemoteLocalOwnershipReason)
    case handleReserved(
        command: TVRemoteReservedCommand,
        disposition: TVRemoteReservedDisposition
    )
    case ignoreUnownedPress(TVRemotePressToken)
}

struct TVPlatformInputReleasePlan: Equatable, Sendable {
    let effects: [TVRemoteCaptureEffect]

    init(
        inputGeneration: TVVisionGeneration,
        activePresses: [TVRemoteActivePress],
        controllerLeases: [TVVisionControllerLease],
        restoreReason: TVRemoteLocalOwnershipReason?
    ) throws {
        try inputGeneration.require(.input)
        guard activePresses.allSatisfy({
            $0.token.inputGeneration == inputGeneration
        }) else {
            throw TVRemoteCaptureContractError.pressGenerationMismatch
        }
        guard activePresses.count <= TVRemoteCaptureState.maximumActivePressCount,
              Set(activePresses.map(\.token)).count == activePresses.count,
              Set(activePresses.map(\.button)).count == activePresses.count,
              activePresses.allSatisfy({ $0.button != .menu }) else {
            throw TVRemoteCaptureContractError.invalidActivePressState
        }
        guard controllerLeases.allSatisfy({ $0.platform == .tvOS }) else {
            throw TVRemoteCaptureContractError.controllerPlatformMismatch
        }
        guard controllerLeases.allSatisfy({
            $0.inputGeneration == inputGeneration
        }) else {
            throw TVRemoteCaptureContractError.controllerInputGenerationMismatch
        }
        var slots = Set<UInt8>()
        var leaseGenerations = Set<UInt64>()
        for lease in controllerLeases {
            guard slots.insert(lease.slot.rawValue).inserted else {
                throw TVRemoteCaptureContractError.duplicateControllerSlot(
                    lease.slot.rawValue
                )
            }
            guard leaseGenerations.insert(lease.leaseGeneration.rawValue).inserted else {
                throw TVRemoteCaptureContractError.duplicateControllerLease(
                    lease.leaseGeneration.rawValue
                )
            }
        }

        var effects: [TVRemoteCaptureEffect] = [
            .closeRemoteAdmission(inputGeneration: inputGeneration)
        ]
        let sortedLeases = controllerLeases.sorted { $0.slot < $1.slot }
        if !sortedLeases.isEmpty {
            effects.append(.removeControllerHandlers(sortedLeases))
        }
        effects.append(contentsOf: activePresses.reversed().map {
            .sendRemote(TVRemoteInputEvent(
                button: $0.button,
                isDown: false
            ))
        })
        effects.append(.awaitRemoteReleaseBarrier(
            inputGeneration: inputGeneration
        ))
        if let restoreReason {
            effects.append(.restoreLocalFocus(restoreReason))
        }
        self.effects = effects
    }
}

enum TVRemoteCaptureAction: Equatable, Sendable {
    case updateInput(TVVisionInputCapabilitySnapshot)
    case pressBegan(token: TVRemotePressToken, button: TVRemoteButton)
    case pressEnded(token: TVRemotePressToken)
    case pressCancelled(token: TVRemotePressToken)
    case reserved(TVRemoteReservedCommand)
}

struct TVRemoteCaptureTransition: Equatable, Sendable {
    let state: TVRemoteCaptureState
    let effects: [TVRemoteCaptureEffect]
}

struct TVRemoteCaptureState: Equatable, Sendable {
    static let maximumActivePressCount = 6

    let inputGeneration: TVVisionGeneration
    let ownership: TVRemoteCaptureOwnership
    let activePresses: [TVRemoteActivePress]

    init(
        input: TVVisionInputCapabilitySnapshot,
        activePresses: [TVRemoteActivePress] = []
    ) throws {
        let ownership = try TVRemoteCaptureOwnership.resolve(input)
        try self.init(
            inputGeneration: input.inputGeneration,
            ownership: ownership,
            activePresses: activePresses
        )
    }

    private init(
        inputGeneration: TVVisionGeneration,
        ownership: TVRemoteCaptureOwnership,
        activePresses: [TVRemoteActivePress]
    ) throws {
        try inputGeneration.require(.input)
        guard activePresses.count <= Self.maximumActivePressCount,
              Set(activePresses.map(\.token)).count == activePresses.count,
              Set(activePresses.map(\.button)).count == activePresses.count,
              activePresses.allSatisfy({
                  $0.token.inputGeneration == inputGeneration
                    && $0.button != .menu
              }) else {
            throw TVRemoteCaptureContractError.invalidActivePressState
        }
        if !activePresses.isEmpty {
            guard ownership == .stream(inputGeneration: inputGeneration) else {
                throw TVRemoteCaptureContractError.invalidActivePressState
            }
        }
        self.inputGeneration = inputGeneration
        self.ownership = ownership
        self.activePresses = activePresses
    }

    func reducing(
        _ action: TVRemoteCaptureAction
    ) throws -> TVRemoteCaptureTransition {
        switch action {
        case let .updateInput(input):
            return try update(input)
        case let .pressBegan(token, button):
            return try pressBegan(token: token, button: button)
        case let .pressEnded(token), let .pressCancelled(token):
            return try finishPress(token)
        case let .reserved(command):
            return TVRemoteCaptureTransition(
                state: self,
                effects: [.handleReserved(
                    command: command,
                    disposition: .resolve(command)
                )]
            )
        }
    }

    private func update(
        _ input: TVVisionInputCapabilitySnapshot
    ) throws -> TVRemoteCaptureTransition {
        let nextOwnership = try TVRemoteCaptureOwnership.resolve(input)
        if input.inputGeneration == inputGeneration,
           nextOwnership == ownership {
            return TVRemoteCaptureTransition(state: self, effects: [])
        }

        var effects: [TVRemoteCaptureEffect] = []
        if case .stream = ownership {
            let restoreReason: TVRemoteLocalOwnershipReason?
            if case let .local(reason) = nextOwnership {
                restoreReason = reason
            } else {
                restoreReason = nil
            }
            effects = try TVPlatformInputReleasePlan(
                inputGeneration: inputGeneration,
                activePresses: activePresses,
                controllerLeases: [],
                restoreReason: restoreReason
            ).effects
        }
        if case .local = ownership,
           case let .local(reason) = nextOwnership,
           input.inputGeneration == inputGeneration {
            effects.append(.restoreLocalFocus(reason))
        }
        if case .stream = nextOwnership {
            effects.append(.openRemoteAdmission(
                inputGeneration: input.inputGeneration
            ))
        }

        let nextState = try TVRemoteCaptureState(
            inputGeneration: input.inputGeneration,
            ownership: nextOwnership,
            activePresses: []
        )
        return TVRemoteCaptureTransition(state: nextState, effects: effects)
    }

    private func pressBegan(
        token: TVRemotePressToken,
        button: TVRemoteButton
    ) throws -> TVRemoteCaptureTransition {
        try requireCurrent(token)
        if button == .menu {
            return TVRemoteCaptureTransition(
                state: self,
                effects: [.handleReserved(
                    command: .backMenu,
                    disposition: .showOverlayOrExitCapture
                )]
            )
        }
        guard case .stream = ownership else {
            let reason: TVRemoteLocalOwnershipReason
            if case let .local(localReason) = ownership {
                reason = localReason
            } else {
                reason = .inputUnavailable
            }
            return TVRemoteCaptureTransition(
                state: self,
                effects: [.reserveLocally(button: button, reason: reason)]
            )
        }
        guard !activePresses.contains(where: { $0.token == token }) else {
            throw TVRemoteCaptureContractError.duplicatePressToken(token.rawValue)
        }
        guard !activePresses.contains(where: { $0.button == button }) else {
            throw TVRemoteCaptureContractError.duplicatePressedButton(button)
        }
        guard activePresses.count < Self.maximumActivePressCount else {
            throw TVRemoteCaptureContractError.pressCapacityExceeded
        }
        let nextPresses = activePresses + [TVRemoteActivePress(
            token: token,
            button: button
        )]
        let nextState = try TVRemoteCaptureState(
            inputGeneration: inputGeneration,
            ownership: ownership,
            activePresses: nextPresses
        )
        return TVRemoteCaptureTransition(
            state: nextState,
            effects: [.sendRemote(TVRemoteInputEvent(
                button: button,
                isDown: true
            ))]
        )
    }

    private func finishPress(
        _ token: TVRemotePressToken
    ) throws -> TVRemoteCaptureTransition {
        try requireCurrent(token)
        guard let index = activePresses.firstIndex(where: {
            $0.token == token
        }) else {
            return TVRemoteCaptureTransition(
                state: self,
                effects: [.ignoreUnownedPress(token)]
            )
        }
        var nextPresses = activePresses
        let press = nextPresses.remove(at: index)
        let nextState = try TVRemoteCaptureState(
            inputGeneration: inputGeneration,
            ownership: ownership,
            activePresses: nextPresses
        )
        return TVRemoteCaptureTransition(
            state: nextState,
            effects: [.sendRemote(TVRemoteInputEvent(
                button: press.button,
                isDown: false
            ))]
        )
    }

    private func requireCurrent(_ token: TVRemotePressToken) throws {
        guard token.inputGeneration == inputGeneration else {
            throw TVRemoteCaptureContractError.pressGenerationMismatch
        }
    }
}

struct TVControllerInputSnapshot: Equatable, Sendable {
    let lease: TVVisionControllerLease
    let supportedButtons: RemoteControllerButtonFlags
    let state: RemoteControllerState

    init(
        lease: TVVisionControllerLease,
        supportedButtons: RemoteControllerButtonFlags,
        state: RemoteControllerState
    ) throws {
        guard lease.platform == .tvOS else {
            throw TVRemoteCaptureContractError.controllerPlatformMismatch
        }
        guard state.controllerIndex == lease.slot.rawValue else {
            throw TVRemoteCaptureContractError.controllerIndexMismatch
        }
        let slotMask = UInt16(1) << UInt16(lease.slot.rawValue)
        guard state.activeGamepadMask & slotMask != 0 else {
            throw TVRemoteCaptureContractError.controllerMaskMismatch
        }
        guard state.buttons.intersection(supportedButtons) == state.buttons else {
            throw TVRemoteCaptureContractError.unsupportedControllerButtons
        }
        if lease.profile == .microGamepad {
            guard state.leftTrigger == 0,
                  state.rightTrigger == 0,
                  state.leftStickX == 0,
                  state.leftStickY == 0,
                  state.rightStickX == 0,
                  state.rightStickY == 0 else {
                throw TVRemoteCaptureContractError.invalidMicroGamepadState
            }
        }
        self.lease = lease
        self.supportedButtons = supportedButtons
        self.state = state
    }
}

struct TVControllerRosterSnapshot: Equatable, Sendable {
    let inputGeneration: TVVisionGeneration
    let activeGamepadMask: UInt16
    let controllers: [TVControllerInputSnapshot]

    init(
        inputGeneration: TVVisionGeneration,
        controllers: [TVControllerInputSnapshot]
    ) throws {
        try inputGeneration.require(.input)
        var slots = Set<UInt8>()
        var leases = Set<UInt64>()
        var activeGamepadMask: UInt16 = 0
        for controller in controllers {
            guard controller.lease.inputGeneration == inputGeneration else {
                throw TVRemoteCaptureContractError.controllerInputGenerationMismatch
            }
            guard slots.insert(controller.lease.slot.rawValue).inserted else {
                throw TVRemoteCaptureContractError.duplicateControllerSlot(
                    controller.lease.slot.rawValue
                )
            }
            guard leases.insert(controller.lease.leaseGeneration.rawValue).inserted else {
                throw TVRemoteCaptureContractError.duplicateControllerLease(
                    controller.lease.leaseGeneration.rawValue
                )
            }
            activeGamepadMask |= UInt16(1) << UInt16(controller.lease.slot.rawValue)
        }
        guard controllers.allSatisfy({
            $0.state.activeGamepadMask == activeGamepadMask
        }) else {
            throw TVRemoteCaptureContractError.controllerMaskMismatch
        }
        self.inputGeneration = inputGeneration
        self.activeGamepadMask = activeGamepadMask
        self.controllers = controllers.sorted {
            $0.lease.slot < $1.lease.slot
        }
    }
}

enum TVControllerFeedbackPayload: Equatable, Sendable {
    case rumble(lowFrequency: Float, highFrequency: Float)
    case triggerRumble(leftMotor: Float, rightMotor: Float)
    case led(red: UInt8, green: UInt8, blue: UInt8)
    case motionRate(type: ControllerMotionType, reportRateHz: Int)
}

struct TVControllerFeedbackRequest: Equatable, Sendable {
    let lease: TVVisionControllerLease
    let payload: TVControllerFeedbackPayload

    init(
        lease: TVVisionControllerLease,
        payload: TVControllerFeedbackPayload
    ) throws {
        guard lease.platform == .tvOS else {
            throw TVRemoteCaptureContractError.controllerPlatformMismatch
        }
        switch payload {
        case let .rumble(lowFrequency, highFrequency):
            guard Self.isUnitValue(lowFrequency),
                  Self.isUnitValue(highFrequency) else {
                throw TVRemoteCaptureContractError.invalidFeedbackPayload
            }
        case let .triggerRumble(leftMotor, rightMotor):
            guard Self.isUnitValue(leftMotor),
                  Self.isUnitValue(rightMotor) else {
                throw TVRemoteCaptureContractError.invalidFeedbackPayload
            }
        case .led:
            break
        case let .motionRate(_, reportRateHz):
            guard (0...1_000).contains(reportRateHz) else {
                throw TVRemoteCaptureContractError.invalidFeedbackPayload
            }
        }
        self.lease = lease
        self.payload = payload
    }

    var requiredCapability: RemoteControllerCapabilities {
        switch payload {
        case .rumble: .rumble
        case .triggerRumble: .triggerRumble
        case .led: .rgbLED
        case let .motionRate(type, _):
            type == .accelerometer ? .accelerometer : .gyroscope
        }
    }

    private static func isUnitValue(_ value: Float) -> Bool {
        value.isFinite && (0...1).contains(value)
    }
}

enum TVControllerFeedbackUnavailableReason: String, Codable, Hashable, Sendable {
    case staleInputGeneration = "stale-input-generation"
    case controllerUnavailable = "controller-unavailable"
    case staleLease = "stale-lease"
    case unsupportedCapability = "unsupported-capability"
}

enum TVControllerFeedbackDecision: Equatable, Sendable {
    case apply(TVControllerFeedbackRequest)
    case unavailable(TVControllerFeedbackUnavailableReason)
}

enum TVControllerFeedbackResolver {
    static func resolve(
        _ request: TVControllerFeedbackRequest,
        roster: TVControllerRosterSnapshot
    ) -> TVControllerFeedbackDecision {
        guard request.lease.inputGeneration == roster.inputGeneration else {
            return .unavailable(.staleInputGeneration)
        }
        guard let controller = roster.controllers.first(where: {
            $0.lease.slot == request.lease.slot
        }) else {
            return .unavailable(.controllerUnavailable)
        }
        guard controller.lease == request.lease else {
            return .unavailable(.staleLease)
        }
        guard controller.lease.capabilities.contains(
            request.requiredCapability
        ) else {
            return .unavailable(.unsupportedCapability)
        }
        return .apply(request)
    }
}
