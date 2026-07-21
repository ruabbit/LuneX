import Foundation

protocol AuthenticatedInputFrameSending: Sendable {
    func activateInput(configuration: NegotiatedInputConfiguration) async throws
    func sendInput(
        _ packet: RemoteInputPlaintextPacket,
        channelID: UInt8,
        reliable: Bool
    ) async throws
    func deactivateInput() async
}

enum RemoteInputRuntimeError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidConfiguration
    case invalidEndpoint
    case inactiveSession
    case sessionMismatch
    case queueFull
    case deliveryFailed
    case controllerLimitReached
    case controllerNotRegistered
    case invalidControllerEvent
    case motionNotEnabled

    var description: String {
        switch self {
        case .invalidConfiguration:
            return "The negotiated remote-input configuration is invalid."
        case .invalidEndpoint:
            return "The negotiated remote-input endpoint is invalid."
        case .inactiveSession:
            return "Remote input is not active for a session."
        case .sessionMismatch:
            return "The remote-input event belongs to a different session."
        case .queueFull:
            return "The bounded remote-input delivery queue is full."
        case .deliveryFailed:
            return "The authenticated remote-input transport failed."
        case .controllerLimitReached:
            return "The remote session already has the maximum number of controllers."
        case .controllerNotRegistered:
            return "The controller is not registered in the active remote-input session."
        case .invalidControllerEvent:
            return "The controller event contains invalid or unsupported state."
        case .motionNotEnabled:
            return "The host has not enabled this controller motion sensor."
        }
    }
}

struct RemoteInputDeliveryLimits: Equatable, Sendable {
    static let production = RemoteInputDeliveryLimits(
        maximumPendingEvents: 256,
        maximumPendingPackets: 8_192,
        maximumPendingCalls: 8_192
    )

    var maximumPendingEvents: Int
    var maximumPendingPackets: Int
    var maximumPendingCalls: Int
}

actor MoonlightRemoteInputProvider: RemoteInputProvider {
    private struct PendingDelivery {
        var event: RemoteInputEvent
        var packets: [RemoteInputOutboundPacket]
        var continuations: [CheckedContinuation<Void, Error>]
        var allowsCoalescing: Bool
    }

    private let sender: any AuthenticatedInputFrameSending
    private let feedbackSource: (any RemoteControllerFeedbackStreaming)?
    private let deliveryLimits: RemoteInputDeliveryLimits
    private var activeSessionID: UUID?
    private var generation: UInt64 = 0
    private var pending: [PendingDelivery] = []
    private var pendingPacketCount = 0
    private var pendingCallCount = 0
    private var drainTask: Task<Void, Never>?
    private var feedbackTask: Task<Void, Never>?
    private var isActivating = false
    private var isTearingDown = false
    private var controllerRegistry = RemoteControllerRegistry()
    private var feedbackContinuations: [UUID: AsyncStream<RemoteInputFeedback>.Continuation] = [:]

    init(
        sender: any AuthenticatedInputFrameSending,
        feedbackSource: (any RemoteControllerFeedbackStreaming)? = nil,
        deliveryLimits: RemoteInputDeliveryLimits = .production
    ) {
        self.sender = sender
        self.feedbackSource = feedbackSource
        self.deliveryLimits = deliveryLimits
    }

    func startInput(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedInputConfiguration
    ) async throws {
        guard activeSessionID == nil, drainTask == nil, !isActivating, !isTearingDown else {
            throw RemoteInputRuntimeError.inactiveSession
        }
        do {
            try endpoint.validate()
        } catch {
            throw RemoteInputRuntimeError.invalidEndpoint
        }
        do {
            try configuration.validate()
        } catch {
            throw RemoteInputRuntimeError.invalidConfiguration
        }

        isActivating = true
        do {
            try await sender.activateInput(configuration: configuration)
        } catch {
            isActivating = false
            throw error
        }
        generation &+= 1
        let inputGeneration = generation
        activeSessionID = sessionID
        controllerRegistry = RemoteControllerRegistry()
        if let feedbackSource {
            let stream = await feedbackSource.controllerFeedbackMessages()
            guard activeSessionID == sessionID, generation == inputGeneration else {
                isActivating = false
                throw RemoteInputRuntimeError.inactiveSession
            }
            let feedbackGeneration = inputGeneration
            feedbackTask = Task {
                for await message in stream {
                    guard !Task.isCancelled else { break }
                    self.handleFeedback(message, generation: feedbackGeneration)
                }
                await self.feedbackSourceDidFinish(generation: feedbackGeneration)
            }
        }
        isActivating = false
    }

    func send(_ event: RemoteInputEvent, sessionID: UUID) async throws {
        guard let activeSessionID else {
            throw RemoteInputRuntimeError.inactiveSession
        }
        guard activeSessionID == sessionID else {
            throw RemoteInputRuntimeError.sessionMismatch
        }
        var nextRegistry = controllerRegistry
        let resolution = try nextRegistry.resolve(event)
        let packets = try resolution.events.flatMap(RemoteInputWireCodec.outboundPackets)
        guard !packets.isEmpty else { return }

        let coalescedEvent: RemoteInputEvent? = pending.last.flatMap { delivery -> RemoteInputEvent? in
            guard delivery.allowsCoalescing, resolution.allowsCoalescing else { return nil }
            return RemoteInputMovementCoalescer.coalesce(
                older: delivery.event,
                newer: resolution.event
            )
        }
        let coalescedPackets = coalescedEvent.flatMap {
            try? RemoteInputWireCodec.outboundPackets(for: $0)
        }
        let canCoalesce = coalescedEvent != nil && coalescedPackets != nil
        let previousPacketCount = canCoalesce ? pending.last?.packets.count ?? 0 : 0
        let nextPacketCount = canCoalesce ? coalescedPackets?.count ?? 0 : packets.count
        let nextEventCount = pending.count + (canCoalesce ? 0 : 1)
        guard deliveryLimits.maximumPendingEvents > 0,
              deliveryLimits.maximumPendingPackets > 0,
              deliveryLimits.maximumPendingCalls > 0,
              nextEventCount <= deliveryLimits.maximumPendingEvents,
              pendingCallCount < deliveryLimits.maximumPendingCalls,
              pendingPacketCount - previousPacketCount + nextPacketCount <= deliveryLimits.maximumPendingPackets else {
            throw RemoteInputRuntimeError.queueFull
        }

        controllerRegistry = nextRegistry
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            if canCoalesce,
               let coalescedEvent,
               let coalescedPackets,
               !pending.isEmpty {
                pendingPacketCount -= pending[pending.count - 1].packets.count
                pending[pending.count - 1].event = coalescedEvent
                pending[pending.count - 1].packets = coalescedPackets
                pending[pending.count - 1].continuations.append(continuation)
                pendingPacketCount += coalescedPackets.count
            } else {
                pending.append(PendingDelivery(
                    event: resolution.event,
                    packets: packets,
                    continuations: [continuation],
                    allowsCoalescing: resolution.allowsCoalescing
                ))
                pendingPacketCount += packets.count
            }
            pendingCallCount += 1
            startDrainIfNeeded()
        }
    }

    func feedback(sessionID: UUID) async -> AsyncStream<RemoteInputFeedback> {
        guard activeSessionID == sessionID else { return AsyncStream { $0.finish() } }
        let id = UUID()
        var continuation: AsyncStream<RemoteInputFeedback>.Continuation!
        let stream = AsyncStream(
            bufferingPolicy: .bufferingNewest(64)
        ) { continuation = $0 }
        continuation.onTermination = { @Sendable _ in
            Task { await self.removeFeedbackContinuation(id) }
        }
        feedbackContinuations[id] = continuation
        return stream
    }

    func releaseAll(sessionID: UUID) async {
        _ = sessionID
        // Held-state tracking and synthesized release events are implemented in task 7.5.
    }

    func stopInput(sessionID: UUID) async {
        guard activeSessionID == sessionID else { return }
        activeSessionID = nil
        generation &+= 1
        isTearingDown = true
        controllerRegistry = RemoteControllerRegistry()
        failPending(with: RemoteInputRuntimeError.inactiveSession)
        let task = drainTask
        let inputFeedbackTask = feedbackTask
        task?.cancel()
        inputFeedbackTask?.cancel()
        finishFeedbackStreams()
        await task?.value
        await inputFeedbackTask?.value
        await sender.deactivateInput()
        drainTask = nil
        feedbackTask = nil
        isTearingDown = false
    }

    private func startDrainIfNeeded() {
        guard drainTask == nil, activeSessionID != nil else { return }
        let drainGeneration = generation
        drainTask = Task {
            await drain(generation: drainGeneration)
        }
    }

    private func drain(generation drainGeneration: UInt64) async {
        while drainGeneration == generation, activeSessionID != nil {
            guard !pending.isEmpty else {
                drainTask = nil
                return
            }
            let delivery = pending.removeFirst()
            pendingPacketCount -= delivery.packets.count
            pendingCallCount -= delivery.continuations.count

            do {
                for packet in delivery.packets {
                    try Task.checkCancellation()
                    try await sender.sendInput(
                        packet.plaintext,
                        channelID: packet.channelID,
                        reliable: packet.reliable
                    )
                    try Task.checkCancellation()
                }
                guard drainGeneration == generation, activeSessionID != nil else {
                    throw CancellationError()
                }
                for continuation in delivery.continuations {
                    continuation.resume()
                }
            } catch {
                let wasCancelled = Task.isCancelled || drainGeneration != generation
                for continuation in delivery.continuations {
                    continuation.resume(throwing: wasCancelled
                        ? RemoteInputRuntimeError.inactiveSession
                        : RemoteInputRuntimeError.deliveryFailed)
                }
                guard !wasCancelled else {
                    drainTask = nil
                    return
                }

                activeSessionID = nil
                generation &+= 1
                isTearingDown = true
                controllerRegistry = RemoteControllerRegistry()
                failPending(with: RemoteInputRuntimeError.deliveryFailed)
                feedbackTask?.cancel()
                feedbackTask = nil
                finishFeedbackStreams()
                await sender.deactivateInput()
                drainTask = nil
                isTearingDown = false
                return
            }
        }
        drainTask = nil
    }

    private func failPending(with error: RemoteInputRuntimeError) {
        let queued = pending
        pending.removeAll(keepingCapacity: false)
        pendingPacketCount = 0
        pendingCallCount = 0
        for delivery in queued {
            for continuation in delivery.continuations {
                continuation.resume(throwing: error)
            }
        }
    }

    private func handleFeedback(
        _ message: RemoteControllerFeedbackMessage,
        generation feedbackGeneration: UInt64
    ) {
        guard feedbackGeneration == generation, activeSessionID != nil else { return }
        let feedback: RemoteInputFeedback
        switch message {
        case let .rumble(controllerIndex, lowFrequency, highFrequency):
            guard let controllerID = controllerRegistry.controllerID(
                at: controllerIndex,
                requiring: .rumble
            ) else { return }
            feedback = .rumble(ControllerRumbleFeedback(
                controllerID: controllerID,
                lowFrequency: normalizedMotor(lowFrequency),
                highFrequency: normalizedMotor(highFrequency)
            ))
        case let .triggerRumble(controllerIndex, leftMotor, rightMotor):
            guard let controllerID = controllerRegistry.controllerID(
                at: controllerIndex,
                requiring: .triggerRumble
            ) else { return }
            feedback = .triggerRumble(ControllerTriggerFeedback(
                controllerID: controllerID,
                leftMotor: normalizedMotor(leftMotor),
                rightMotor: normalizedMotor(rightMotor)
            ))
        case let .motionRate(controllerIndex, motionType, reportRateHz):
            guard let controllerID = controllerRegistry.setMotionRate(
                controllerIndex: controllerIndex,
                motionType: motionType,
                reportRateHz: reportRateHz
            ) else { return }
            feedback = .motionRate(
                controllerID: controllerID,
                motionType: motionType,
                reportRateHz: Int(reportRateHz)
            )
        case let .led(controllerIndex, red, green, blue):
            guard let controllerID = controllerRegistry.controllerID(
                at: controllerIndex,
                requiring: .rgbLED
            ) else { return }
            feedback = .led(ControllerLEDFeedback(
                controllerID: controllerID,
                red: red,
                green: green,
                blue: blue
            ))
        }
        for continuation in feedbackContinuations.values {
            continuation.yield(feedback)
        }
    }

    private func feedbackSourceDidFinish(generation feedbackGeneration: UInt64) async {
        guard feedbackGeneration == generation, activeSessionID != nil else { return }
        activeSessionID = nil
        generation &+= 1
        isTearingDown = true
        controllerRegistry = RemoteControllerRegistry()
        failPending(with: RemoteInputRuntimeError.deliveryFailed)
        let inputDrainTask = drainTask
        inputDrainTask?.cancel()
        feedbackTask = nil
        finishFeedbackStreams()
        await inputDrainTask?.value
        await sender.deactivateInput()
        drainTask = nil
        isTearingDown = false
    }

    private func removeFeedbackContinuation(_ id: UUID) {
        feedbackContinuations[id] = nil
    }

    private func finishFeedbackStreams() {
        let continuations = feedbackContinuations.values
        feedbackContinuations.removeAll(keepingCapacity: false)
        for continuation in continuations {
            continuation.finish()
        }
    }

    private func normalizedMotor(_ value: UInt16) -> Float {
        Float(value) / Float(UInt16.max)
    }
}

enum RemoteInputMovementCoalescer {
    static func coalesce(
        older: RemoteInputEvent,
        newer: RemoteInputEvent
    ) -> RemoteInputEvent? {
        switch (older, newer) {
        case let (
            .pointer(.relativeMove(oldX, oldY, oldButtons)),
            .pointer(.relativeMove(newX, newY, newButtons))
        ) where oldButtons == newButtons:
            let combinedX = oldX + newX
            let combinedY = oldY + newY
            guard combinedX.isFinite, combinedY.isFinite else { return nil }
            return .pointer(.relativeMove(
                deltaX: combinedX,
                deltaY: combinedY,
                buttons: newButtons
            ))
        case let (
            .pointer(.absoluteMove(_, oldReferenceSize, oldButtons)),
            .pointer(.absoluteMove(newPoint, newReferenceSize, newButtons))
        ) where oldReferenceSize == newReferenceSize && oldButtons == newButtons:
            return .pointer(.absoluteMove(
                point: newPoint,
                referenceSize: newReferenceSize,
                buttons: newButtons
            ))
        case let (.controllerState(oldState), .controllerState(newState))
            where oldState.controllerIndex == newState.controllerIndex
                && oldState.activeGamepadMask == newState.activeGamepadMask
                && oldState.buttons == newState.buttons:
            return .controllerState(newState)
        case let (.controllerMotionState(oldMotion), .controllerMotionState(newMotion))
            where oldMotion.controllerIndex == newMotion.controllerIndex
                && oldMotion.type == newMotion.type:
            return .controllerMotionState(newMotion)
        default:
            return nil
        }
    }
}

private struct ResolvedRemoteInputEvent: Sendable {
    var event: RemoteInputEvent
    var events: [RemoteInputEvent]
    var allowsCoalescing: Bool
}

private struct RemoteControllerRegistry: Sendable {
    private struct Entry: Sendable {
        var controllerID: String
        var controllerIndex: UInt8
        var type: RemoteControllerType
        var capabilities: RemoteControllerCapabilities
        var supportedButtons: RemoteControllerButtonFlags
        var state: RemoteControllerState
        var motionRates: [ControllerMotionType: UInt16]
    }

    private var indicesByControllerID: [String: UInt8] = [:]
    private var entriesByIndex: [UInt8: Entry] = [:]

    mutating func resolve(_ event: RemoteInputEvent) throws -> ResolvedRemoteInputEvent {
        switch event {
        case let .controllerConnected(connection):
            let result = try register(connection)
            let arrival = RemoteInputEvent.controllerArrival(RemoteControllerArrival(
                controllerIndex: result.entry.controllerIndex,
                type: result.entry.type,
                capabilities: result.entry.capabilities,
                supportedButtons: result.entry.supportedButtons
            ))
            let fallbackState = RemoteControllerState.empty(
                controllerIndex: result.entry.controllerIndex,
                activeGamepadMask: activeGamepadMask
            )
            let fallback = RemoteInputEvent.controllerState(fallbackState)
            let currentState = snapshot(for: result.entry.controllerIndex)
            let state = RemoteInputEvent.controllerState(currentState)
            let events = currentState == fallbackState ? [arrival, fallback] : [arrival, fallback, state]
            return ResolvedRemoteInputEvent(event: state, events: events, allowsCoalescing: false)
        case let .controllerDisconnected(controllerID):
            guard let controllerIndex = indicesByControllerID.removeValue(forKey: controllerID) else {
                throw RemoteInputRuntimeError.controllerNotRegistered
            }
            entriesByIndex[controllerIndex] = nil
            let state = RemoteInputEvent.controllerState(.empty(
                controllerIndex: controllerIndex,
                activeGamepadMask: activeGamepadMask
            ))
            return ResolvedRemoteInputEvent(event: state, events: [state], allowsCoalescing: false)
        case let .gameController(delta):
            let defaultConnection = ControllerConnectionInputEvent(
                controllerID: delta.controllerID,
                playerIndex: delta.playerIndex,
                type: .unknown,
                capabilities: [.analogTriggers],
                supportedButtons: .standard
            )
            let registration = try register(defaultConnection)
            try update(delta, controllerIndex: registration.entry.controllerIndex)
            let state = RemoteInputEvent.controllerState(snapshot(for: registration.entry.controllerIndex))
            if registration.wasInserted {
                let arrival = RemoteInputEvent.controllerArrival(RemoteControllerArrival(
                    controllerIndex: registration.entry.controllerIndex,
                    type: registration.entry.type,
                    capabilities: registration.entry.capabilities,
                    supportedButtons: registration.entry.supportedButtons
                ))
                let fallback = RemoteInputEvent.controllerState(.empty(
                    controllerIndex: registration.entry.controllerIndex,
                    activeGamepadMask: activeGamepadMask
                ))
                return ResolvedRemoteInputEvent(
                    event: state,
                    events: [arrival, fallback, state],
                    allowsCoalescing: false
                )
            }
            return ResolvedRemoteInputEvent(event: state, events: [state], allowsCoalescing: true)
        case let .virtualController(delta):
            let controllerID = "virtual-controller"
            let registration = try register(ControllerConnectionInputEvent(
                controllerID: controllerID,
                playerIndex: nil,
                type: .xbox,
                capabilities: [.analogTriggers],
                supportedButtons: .standard
            ))
            try update(virtual: delta, controllerID: controllerID, controllerIndex: registration.entry.controllerIndex)
            let state = RemoteInputEvent.controllerState(snapshot(for: registration.entry.controllerIndex))
            if registration.wasInserted {
                let arrival = RemoteInputEvent.controllerArrival(RemoteControllerArrival(
                    controllerIndex: registration.entry.controllerIndex,
                    type: registration.entry.type,
                    capabilities: registration.entry.capabilities,
                    supportedButtons: registration.entry.supportedButtons
                ))
                let fallback = RemoteInputEvent.controllerState(.empty(
                    controllerIndex: registration.entry.controllerIndex,
                    activeGamepadMask: activeGamepadMask
                ))
                return ResolvedRemoteInputEvent(
                    event: state,
                    events: [arrival, fallback, state],
                    allowsCoalescing: false
                )
            }
            return ResolvedRemoteInputEvent(event: state, events: [state], allowsCoalescing: true)
        case let .controllerMotion(motion):
            guard let controllerIndex = indicesByControllerID[motion.controllerID],
                  let entry = entriesByIndex[controllerIndex] else {
                throw RemoteInputRuntimeError.controllerNotRegistered
            }
            let requiredCapability: RemoteControllerCapabilities = motion.type == .accelerometer
                ? .accelerometer
                : .gyroscope
            guard entry.capabilities.contains(requiredCapability) else {
                throw RemoteInputRuntimeError.invalidControllerEvent
            }
            guard entry.motionRates[motion.type, default: 0] > 0 else {
                throw RemoteInputRuntimeError.motionNotEnabled
            }
            guard motion.x.isFinite, motion.y.isFinite, motion.z.isFinite else {
                throw RemoteInputRuntimeError.invalidControllerEvent
            }
            let wireEvent = RemoteInputEvent.controllerMotionState(RemoteControllerMotion(
                controllerIndex: controllerIndex,
                type: motion.type,
                x: motion.x,
                y: motion.y,
                z: motion.z
            ))
            return ResolvedRemoteInputEvent(event: wireEvent, events: [wireEvent], allowsCoalescing: true)
        case let .controllerBattery(battery):
            guard let controllerIndex = indicesByControllerID[battery.controllerID],
                  let entry = entriesByIndex[controllerIndex] else {
                throw RemoteInputRuntimeError.controllerNotRegistered
            }
            guard entry.capabilities.contains(.battery) else {
                throw RemoteInputRuntimeError.invalidControllerEvent
            }
            guard battery.percentage <= 100
                    || battery.percentage == ControllerBatteryInputEvent.unknownPercentage else {
                throw RemoteInputRuntimeError.invalidControllerEvent
            }
            let wireEvent = RemoteInputEvent.controllerBatteryState(RemoteControllerBattery(
                controllerIndex: controllerIndex,
                state: battery.state,
                percentage: battery.percentage
            ))
            return ResolvedRemoteInputEvent(event: wireEvent, events: [wireEvent], allowsCoalescing: false)
        case .controllerState, .controllerArrival, .controllerMotionState, .controllerBatteryState:
            return ResolvedRemoteInputEvent(
                event: event,
                events: [event],
                allowsCoalescing: Self.isCoalescible(event)
            )
        case .keyboard, .pointer, .touch, .clipboard, .tvRemote, .focus:
            return ResolvedRemoteInputEvent(
                event: event,
                events: [event],
                allowsCoalescing: Self.isCoalescible(event)
            )
        }
    }

    func controllerID(at controllerIndex: UInt8) -> String? {
        entriesByIndex[controllerIndex]?.controllerID
    }

    func controllerID(
        at controllerIndex: UInt8,
        requiring capability: RemoteControllerCapabilities
    ) -> String? {
        guard let entry = entriesByIndex[controllerIndex],
              entry.capabilities.contains(capability) else { return nil }
        return entry.controllerID
    }

    mutating func setMotionRate(
        controllerIndex: UInt8,
        motionType: ControllerMotionType,
        reportRateHz: UInt16
    ) -> String? {
        guard var entry = entriesByIndex[controllerIndex] else { return nil }
        let requiredCapability: RemoteControllerCapabilities = motionType == .accelerometer
            ? .accelerometer
            : .gyroscope
        guard entry.capabilities.contains(requiredCapability) else { return nil }
        entry.motionRates[motionType] = reportRateHz
        entriesByIndex[controllerIndex] = entry
        return entry.controllerID
    }

    private var activeGamepadMask: UInt16 {
        entriesByIndex.keys.reduce(UInt16(0)) { mask, controllerIndex in
            mask | (UInt16(1) << controllerIndex)
        }
    }

    private mutating func register(
        _ connection: ControllerConnectionInputEvent
    ) throws -> (entry: Entry, wasInserted: Bool) {
        guard !connection.controllerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RemoteInputRuntimeError.invalidControllerEvent
        }
        if let existingIndex = indicesByControllerID[connection.controllerID],
           var existing = entriesByIndex[existingIndex] {
            var capabilities = connection.capabilities
            if capabilities.contains(.dualTouchpad) {
                capabilities.insert(.touchpad)
            }
            existing.type = connection.type
            existing.capabilities = capabilities
            existing.supportedButtons = connection.supportedButtons
            entriesByIndex[existingIndex] = existing
            return (existing, false)
        }

        let preferredIndex = connection.playerIndex.flatMap { playerIndex -> UInt8? in
            guard (1...4).contains(playerIndex) else { return nil }
            return UInt8(playerIndex - 1)
        }
        let controllerIndex: UInt8
        if let preferredIndex, entriesByIndex[preferredIndex] == nil {
            controllerIndex = preferredIndex
        } else if let available = (0..<RemoteInputWireCodec.maximumControllerCount)
            .map(UInt8.init)
            .first(where: { entriesByIndex[$0] == nil }) {
            controllerIndex = available
        } else {
            throw RemoteInputRuntimeError.controllerLimitReached
        }

        var capabilities = connection.capabilities
        if capabilities.contains(.dualTouchpad) {
            capabilities.insert(.touchpad)
        }
        let entry = Entry(
            controllerID: connection.controllerID,
            controllerIndex: controllerIndex,
            type: connection.type,
            capabilities: capabilities,
            supportedButtons: connection.supportedButtons,
            state: .empty(controllerIndex: controllerIndex, activeGamepadMask: 0),
            motionRates: [:]
        )
        indicesByControllerID[connection.controllerID] = controllerIndex
        entriesByIndex[controllerIndex] = entry
        return (entry, true)
    }

    private mutating func update(
        _ delta: GameControllerInputEvent,
        controllerIndex: UInt8
    ) throws {
        guard var entry = entriesByIndex[controllerIndex], delta.value.isFinite else {
            throw RemoteInputRuntimeError.invalidControllerEvent
        }
        switch delta.element {
        case .leftTrigger:
            entry.state.leftTrigger = try triggerValue(delta.value)
        case .rightTrigger:
            entry.state.rightTrigger = try triggerValue(delta.value)
        case .leftThumbstickX:
            entry.state.leftStickX = try stickValue(delta.value)
        case .leftThumbstickY:
            entry.state.leftStickY = try stickValue(delta.value)
        case .rightThumbstickX:
            entry.state.rightStickX = try stickValue(delta.value)
        case .rightThumbstickY:
            entry.state.rightStickY = try stickValue(delta.value)
        default:
            guard (0...1).contains(delta.value), let flag = buttonFlag(for: delta.element) else {
                throw RemoteInputRuntimeError.invalidControllerEvent
            }
            entry.state.buttons.set(flag, enabled: delta.isPressed)
        }
        entriesByIndex[controllerIndex] = entry
    }

    private mutating func update(
        virtual delta: VirtualControllerInputEvent,
        controllerID: String,
        controllerIndex: UInt8
    ) throws {
        let element: GameControllerElement
        switch delta.control {
        case .a: element = .a
        case .b: element = .b
        case .x: element = .x
        case .y: element = .y
        case .leftShoulder: element = .leftShoulder
        case .rightShoulder: element = .rightShoulder
        case .leftTrigger: element = .leftTrigger
        case .rightTrigger: element = .rightTrigger
        case .menu: element = .menu
        case .options: element = .options
        case .dpadUp: element = .dpadUp
        case .dpadDown: element = .dpadDown
        case .dpadLeft: element = .dpadLeft
        case .dpadRight: element = .dpadRight
        case .leftThumbstick: element = .leftThumbstickButton
        case .rightThumbstick: element = .rightThumbstickButton
        }
        try update(GameControllerInputEvent(
            controllerID: controllerID,
            playerIndex: nil,
            element: element,
            value: delta.value,
            isPressed: delta.isPressed
        ), controllerIndex: controllerIndex)
    }

    private func snapshot(for controllerIndex: UInt8) -> RemoteControllerState {
        guard var state = entriesByIndex[controllerIndex]?.state else {
            return .empty(controllerIndex: controllerIndex, activeGamepadMask: activeGamepadMask)
        }
        state.activeGamepadMask = activeGamepadMask
        return state
    }

    private func buttonFlag(for element: GameControllerElement) -> RemoteControllerButtonFlags? {
        switch element {
        case .a: .a
        case .b: .b
        case .x: .x
        case .y: .y
        case .leftShoulder: .leftShoulder
        case .rightShoulder: .rightShoulder
        case .menu: .menu
        case .options: .options
        case .dpadUp: .dpadUp
        case .dpadDown: .dpadDown
        case .dpadLeft: .dpadLeft
        case .dpadRight: .dpadRight
        case .leftThumbstickButton: .leftThumbstick
        case .rightThumbstickButton: .rightThumbstick
        case .leftTrigger, .rightTrigger,
             .leftThumbstickX, .leftThumbstickY, .rightThumbstickX, .rightThumbstickY:
            nil
        }
    }

    private func triggerValue(_ value: Double) throws -> UInt8 {
        guard (0...1).contains(value) else { throw RemoteInputRuntimeError.invalidControllerEvent }
        return UInt8((value * Double(UInt8.max)).rounded(.toNearestOrAwayFromZero))
    }

    private func stickValue(_ value: Double) throws -> Int16 {
        guard (-1...1).contains(value) else { throw RemoteInputRuntimeError.invalidControllerEvent }
        return Int16((value * Double(Int16.max)).rounded(.toNearestOrAwayFromZero))
    }

    private static func isCoalescible(_ event: RemoteInputEvent) -> Bool {
        switch event {
        case .pointer(.relativeMove), .pointer(.absoluteMove),
             .controllerState, .controllerMotionState:
            true
        default:
            false
        }
    }
}

private extension RemoteControllerButtonFlags {
    mutating func set(_ flag: RemoteControllerButtonFlags, enabled: Bool) {
        if enabled {
            insert(flag)
        } else {
            remove(flag)
        }
    }
}
