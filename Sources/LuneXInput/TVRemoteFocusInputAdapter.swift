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

enum TVRemoteSurfacePressPhase: Equatable, Sendable {
    case began
    case ended
    case cancelled
}

enum TVRemoteSurfacePressDisposition: Equatable, Sendable {
    case captured
    case local
}

struct TVRemoteSurfacePressEvent: Equatable, Sendable {
    let surfaceGeneration: TVVisionGeneration
    let pressID: UInt64
    let button: TVRemoteButton
    let phase: TVRemoteSurfacePressPhase

    init(
        surfaceGeneration: TVVisionGeneration,
        pressID: UInt64,
        button: TVRemoteButton,
        phase: TVRemoteSurfacePressPhase
    ) throws {
        try surfaceGeneration.require(.surface)
        guard pressID > 0 else {
            throw TVRemoteCaptureContractError.invalidPressToken
        }
        self.surfaceGeneration = surfaceGeneration
        self.pressID = pressID
        self.button = button
        self.phase = phase
    }
}

@MainActor
final class TVRemoteSurfacePressCaptureOwner {
    typealias Delivery = @MainActor @Sendable (
        TVVisionGeneration,
        TVRemoteInputEvent
    ) async throws -> Void

    private let delivery: Delivery
    private var surfaceGeneration: TVVisionGeneration?
    private var input: TVVisionInputCapabilitySnapshot?
    private var state: TVRemoteCaptureState?
    private var failedInputGeneration: TVVisionGeneration?
    private var deliveryTask: Task<Void, Never>?
    private var deliveryOperationID: UUID?

    init(delivery: @escaping Delivery) {
        self.delivery = delivery
    }

    func update(
        surfaceGeneration: TVVisionGeneration,
        input requestedInput: TVVisionInputCapabilitySnapshot
    ) throws {
        try surfaceGeneration.require(.surface)
        guard requestedInput.platform == .tvOS else {
            throw TVRemoteCaptureContractError.platformMismatch
        }

        if let currentGeneration = input?.inputGeneration,
           currentGeneration != requestedInput.inputGeneration {
            failedInputGeneration = nil
        }
        if let currentSurface = self.surfaceGeneration,
           currentSurface != surfaceGeneration,
           let currentState = state,
           let currentInput = input {
            let replacing = try TVVisionInputCapabilitySnapshot(
                platform: .tvOS,
                revision: currentInput.revision,
                inputGeneration: currentInput.inputGeneration,
                supported: currentInput.supported,
                focusEligibility: .ineligible(.replacing)
            )
            let transition = try currentState.reducing(.updateInput(replacing))
            apply(
                transition,
                deliveryGeneration: currentState.inputGeneration
            )
            state = nil
        }

        self.surfaceGeneration = surfaceGeneration
        let resolvedInput = try resolvedInput(requestedInput)
        input = resolvedInput
        if let currentState = state {
            let transition = try currentState.reducing(.updateInput(resolvedInput))
            apply(
                transition,
                deliveryGeneration: currentState.inputGeneration
            )
        } else {
            state = try TVRemoteCaptureState(input: resolvedInput)
        }
    }

    func handle(
        _ event: TVRemoteSurfacePressEvent
    ) -> TVRemoteSurfacePressDisposition {
        guard event.surfaceGeneration == surfaceGeneration,
              let currentState = state,
              input?.inputGeneration == currentState.inputGeneration,
              let token = try? TVRemotePressToken(
                inputGeneration: currentState.inputGeneration,
                rawValue: event.pressID
              ) else {
            return .local
        }

        switch event.phase {
        case .began:
            if currentState.activePresses.contains(where: {
                $0.token == token || $0.button == event.button
            }) {
                return .captured
            }
            do {
                let transition = try currentState.reducing(.pressBegan(
                    token: token,
                    button: event.button
                ))
                let captured = transition.effects.contains(where: { effect in
                    guard case let .sendRemote(remote) = effect else {
                        return false
                    }
                    return remote.isDown
                })
                apply(
                    transition,
                    deliveryGeneration: currentState.inputGeneration
                )
                return captured ? .captured : .local
            } catch TVRemoteCaptureContractError.pressCapacityExceeded {
                return .captured
            } catch {
                return .local
            }
        case .ended, .cancelled:
            let wasCaptured = currentState.activePresses.contains(where: {
                $0.token == token
            })
            guard wasCaptured else { return .local }
            do {
                let action: TVRemoteCaptureAction = event.phase == .ended
                    ? .pressEnded(token: token)
                    : .pressCancelled(token: token)
                let transition = try currentState.reducing(action)
                apply(
                    transition,
                    deliveryGeneration: currentState.inputGeneration
                )
                return .captured
            } catch {
                return .local
            }
        }
    }

    func disposition(
        for surfaceGeneration: TVVisionGeneration
    ) -> TVRemoteSurfacePressDisposition {
        guard surfaceGeneration == self.surfaceGeneration,
              let state,
              input?.inputGeneration == state.inputGeneration,
              state.ownership == .stream(
                inputGeneration: state.inputGeneration
              ) else {
            return .local
        }
        return .captured
    }

    func invalidate() {
        failedInputGeneration = input?.inputGeneration
        surfaceGeneration = nil
        input = nil
        state = nil
    }

    func waitForPendingDeliveries() async {
        while let task = deliveryTask {
            let operationID = deliveryOperationID
            await task.value
            if operationID == deliveryOperationID { return }
        }
    }

    private func resolvedInput(
        _ requestedInput: TVVisionInputCapabilitySnapshot
    ) throws -> TVVisionInputCapabilitySnapshot {
        guard failedInputGeneration == requestedInput.inputGeneration else {
            return requestedInput
        }
        return try TVVisionInputCapabilitySnapshot(
            platform: requestedInput.platform,
            revision: requestedInput.revision,
            inputGeneration: requestedInput.inputGeneration,
            supported: requestedInput.supported,
            focusEligibility: .ineligible(.inputUnavailable)
        )
    }

    private func apply(
        _ transition: TVRemoteCaptureTransition,
        deliveryGeneration: TVVisionGeneration,
        prependingEvents: [TVRemoteInputEvent] = []
    ) {
        state = transition.state
        var events = prependingEvents
        let transitionEvents = transition.effects.compactMap {
            effect -> TVRemoteInputEvent? in
            guard case let .sendRemote(event) = effect else { return nil }
            return event
        }
        for event in transitionEvents where !events.contains(event) {
            events.append(event)
        }
        enqueue(events, inputGeneration: deliveryGeneration)
    }

    private func enqueue(
        _ events: [TVRemoteInputEvent],
        inputGeneration: TVVisionGeneration
    ) {
        guard !events.isEmpty else { return }
        let previous = deliveryTask
        let delivery = self.delivery
        deliveryOperationID = UUID()
        deliveryTask = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            for event in events {
                if self.failedInputGeneration == inputGeneration,
                   event.isDown {
                    continue
                }
                do {
                    try await delivery(inputGeneration, event)
                } catch {
                    self.handleDeliveryFailure(
                        inputGeneration,
                        failedEvent: event
                    )
                    return
                }
            }
        }
    }

    private func handleDeliveryFailure(
        _ inputGeneration: TVVisionGeneration,
        failedEvent: TVRemoteInputEvent
    ) {
        guard failedInputGeneration != inputGeneration else { return }
        failedInputGeneration = inputGeneration
        guard let currentState = state,
              currentState.inputGeneration == inputGeneration,
              let input else { return }
        guard let unavailable = try? TVVisionInputCapabilitySnapshot(
            platform: .tvOS,
            revision: input.revision,
            inputGeneration: input.inputGeneration,
            supported: input.supported,
            focusEligibility: .ineligible(.inputUnavailable)
        ),
              let transition = try? currentState.reducing(
                .updateInput(unavailable)
              ) else { return }
        self.input = unavailable
        apply(
            transition,
            deliveryGeneration: inputGeneration,
            prependingEvents: [TVRemoteInputEvent(
                button: failedEvent.button,
                isDown: false
            )]
        )
    }
}

#if os(tvOS)
import UIKit

enum TVRemotePressMapper {
    static func reservedCommand(
        for pressType: UIPress.PressType
    ) -> TVRemoteReservedCommand? {
        if pressType == .menu { return .backMenu }
        return button(for: pressType) == nil ? .unsupported : nil
    }

    static func button(for pressType: UIPress.PressType) -> TVRemoteButton? {
        switch pressType {
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
