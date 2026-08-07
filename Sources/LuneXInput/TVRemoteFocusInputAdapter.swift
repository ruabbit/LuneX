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
        guard sample.button != .menu else {
            return InputAdapterOutput(
                event: nil,
                policy: .reserveLocally(
                    reason: "tvOS Menu remains local for native escape"
                )
            )
        }
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
        _ = sample
        return InputAdapterOutput(
            event: nil,
            policy: .reserveLocally(
                reason: "tvOS focus identity remains local"
            )
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
    typealias EffectApplication = @MainActor @Sendable (
        TVRemoteCaptureEffect
    ) async throws -> Void
    typealias Delivery = @MainActor @Sendable (
        TVVisionGeneration,
        TVRemoteInputEvent
    ) async throws -> Void

    private let effectApplication: EffectApplication
    private let delivery: Delivery
    private var surfaceGeneration: TVVisionGeneration?
    private var input: TVVisionInputCapabilitySnapshot?
    private var state: TVRemoteCaptureState?
    private var controllerLeases: [TVVisionControllerLease] = []
    private var failedInputGeneration: TVVisionGeneration?
    private var operationTask: Task<Void, Never>?
    private var operationID: UUID?
    private var pendingReleaseOperationCounts: [UUID: Int] = [:]
    private var admissionIntentRevision = UUID()
    private(set) var admittedInputGeneration: TVVisionGeneration?

    var isReleasePending: Bool {
        !pendingReleaseOperationCounts.isEmpty
    }

    init(
        effectApplication: @escaping EffectApplication = { _ in },
        delivery: @escaping Delivery
    ) {
        self.effectApplication = effectApplication
        self.delivery = delivery
    }

    func update(
        surfaceGeneration: TVVisionGeneration,
        input requestedInput: TVVisionInputCapabilitySnapshot,
        controllerLeases requestedControllerLeases: [TVVisionControllerLease] = []
    ) throws {
        try surfaceGeneration.require(.surface)
        guard requestedInput.platform == .tvOS else {
            throw TVRemoteCaptureContractError.platformMismatch
        }
        _ = try TVPlatformInputReleasePlan(
            inputGeneration: requestedInput.inputGeneration,
            activePresses: [],
            controllerLeases: requestedControllerLeases,
            restoreReason: nil
        )

        if let currentGeneration = input?.inputGeneration,
           currentGeneration != requestedInput.inputGeneration {
            failedInputGeneration = nil
        }
        let resolvedInput = try resolvedInput(requestedInput)
        if self.surfaceGeneration != surfaceGeneration {
            advanceAdmissionIntentRevision()
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
                deliveryGeneration: currentState.inputGeneration,
                controllerLeases: controllerLeases
            )
        }

        self.surfaceGeneration = surfaceGeneration
        input = resolvedInput
        controllerLeases = requestedControllerLeases
        if let currentState = state {
            let transition = try currentState.reducing(.updateInput(resolvedInput))
            apply(
                transition,
                deliveryGeneration: currentState.inputGeneration,
                controllerLeases: requestedControllerLeases
            )
        } else {
            let initialState = try TVRemoteCaptureState(input: resolvedInput)
            advanceAdmissionIntentRevision()
            state = initialState
            if initialState.ownership == .stream(
                inputGeneration: initialState.inputGeneration
            ) {
                enqueue(
                    [.openRemoteAdmission(
                        inputGeneration: initialState.inputGeneration
                    )],
                    inputGeneration: initialState.inputGeneration
                )
            }
        }
    }

    func handle(
        _ event: TVRemoteSurfacePressEvent
    ) -> TVRemoteSurfacePressDisposition {
        guard event.surfaceGeneration == surfaceGeneration,
              let currentState = state,
              input?.inputGeneration == currentState.inputGeneration,
              admittedInputGeneration == currentState.inputGeneration,
              currentState.ownership == .stream(
                inputGeneration: currentState.inputGeneration
              ),
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
                    guard case .sendRemote(let remote) = effect else {
                        return false
                    }
                    return remote.isDown
                })
                apply(
                    transition,
                    deliveryGeneration: currentState.inputGeneration,
                    controllerLeases: controllerLeases
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
                    deliveryGeneration: currentState.inputGeneration,
                    controllerLeases: controllerLeases
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
              admittedInputGeneration == state.inputGeneration,
              state.ownership == .stream(
                inputGeneration: state.inputGeneration
              ) else {
            return .local
        }
        return .captured
    }

    func invalidate() {
        advanceAdmissionIntentRevision()
        failedInputGeneration = input?.inputGeneration
        admittedInputGeneration = nil
        pendingReleaseOperationCounts.removeAll()
        surfaceGeneration = nil
        input = nil
        state = nil
        controllerLeases = []
    }

    func waitForPendingDeliveries() async {
        while let task = operationTask {
            let currentOperationID = operationID
            await task.value
            if currentOperationID == operationID { return }
        }
    }

    func releaseForTerminal(
        controllerLeases requestedControllerLeases: [TVVisionControllerLease],
        reason: TVRemoteLocalOwnershipReason = .stopped
    ) async {
        guard let currentState = state,
              let currentInput = input,
              let stoppedInput = try? TVVisionInputCapabilitySnapshot(
                platform: .tvOS,
                revision: currentInput.revision,
                inputGeneration: currentInput.inputGeneration,
                supported: currentInput.supported,
                focusEligibility: .ineligible(.stopped)
              ),
              let transition = try? currentState.reducing(
                .updateInput(stoppedInput)
              ) else {
            admittedInputGeneration = nil
            surfaceGeneration = nil
            await waitForPendingDeliveries()
            invalidate()
            return
        }
        input = stoppedInput
        controllerLeases = requestedControllerLeases
        apply(
            transition,
            deliveryGeneration: currentState.inputGeneration,
            controllerLeases: requestedControllerLeases,
            restoreReasonOverride: reason
        )
        admittedInputGeneration = nil
        surfaceGeneration = nil
        await waitForPendingDeliveries()
        invalidate()
    }

    func failClosedForContractViolation() {
        guard let currentState = state,
              let currentInput = input else {
            invalidate()
            return
        }
        markInputFailed(currentInput.inputGeneration)
        guard let unavailable = try? TVVisionInputCapabilitySnapshot(
            platform: .tvOS,
            revision: currentInput.revision,
            inputGeneration: currentInput.inputGeneration,
            supported: currentInput.supported,
            focusEligibility: .ineligible(.inputUnavailable)
        ),
              let transition = try? currentState.reducing(
                .updateInput(unavailable)
              ) else {
            invalidate()
            return
        }
        input = unavailable
        apply(
            transition,
            deliveryGeneration: currentInput.inputGeneration,
            controllerLeases: controllerLeases
        )
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
        controllerLeases: [TVVisionControllerLease],
        prependingEvents: [TVRemoteInputEvent] = [],
        restoreReasonOverride: TVRemoteLocalOwnershipReason? = nil
    ) {
        if state?.ownership != transition.state.ownership {
            advanceAdmissionIntentRevision()
        }
        state = transition.state
        var effects = transition.effects
        if let restoreReasonOverride,
           let restoreIndex = effects.lastIndex(where: {
               if case .restoreLocalFocus = $0 { return true }
               return false
           }) {
            effects[restoreIndex] = .restoreLocalFocus(restoreReasonOverride)
        }
        effects = releaseEffects(
            effects,
            controllerLeases: controllerLeases,
            prependingEvents: prependingEvents
        )
        if effects.contains(where: {
            if case .closeRemoteAdmission = $0 { return true }
            return false
        }) {
            admittedInputGeneration = nil
        }
        enqueue(effects, inputGeneration: deliveryGeneration)
    }

    private func enqueue(
        _ effects: [TVRemoteCaptureEffect],
        inputGeneration: TVVisionGeneration
    ) {
        guard !effects.isEmpty else { return }
        let previous = operationTask
        let effectApplication = self.effectApplication
        let delivery = self.delivery
        let operationAdmissionIntentRevision = admissionIntentRevision
        let releaseOperationCount = effects.filter {
            if case .closeRemoteAdmission = $0 { return true }
            return false
        }.count
        let nextOperationID = UUID()
        if releaseOperationCount > 0 {
            pendingReleaseOperationCounts[nextOperationID] = releaseOperationCount
        }
        operationID = nextOperationID
        operationTask = Task { @MainActor [weak self] in
            await previous?.value
            guard let self else { return }
            defer {
                self.pendingReleaseOperationCounts.removeValue(
                    forKey: nextOperationID
                )
                if self.operationID == nextOperationID {
                    self.operationTask = nil
                }
            }
            for (index, effect) in effects.enumerated() {
                if case let .openRemoteAdmission(generation) = effect,
                   !self.canApplyOpenAdmission(
                    generation,
                    admissionIntentRevision: operationAdmissionIntentRevision
                   ) {
                    continue
                }
                switch effect {
                case .sendRemote(let event):
                    if self.failedInputGeneration == inputGeneration,
                       event.isDown {
                        continue
                    }
                    do {
                        try await delivery(inputGeneration, event)
                    } catch {
                        if effects.suffix(from: effects.index(
                            effects.startIndex,
                            offsetBy: index + 1
                        )).contains(where: {
                            if case .awaitRemoteReleaseBarrier = $0 { return true }
                            return false
                        }) {
                            self.markInputFailed(inputGeneration)
                            continue
                        }
                        self.handleDeliveryFailure(
                            inputGeneration,
                            failedEvent: event
                        )
                        return
                    }
                default:
                    do {
                        try await effectApplication(effect)
                        self.complete(
                            effect,
                            admissionIntentRevision:
                                operationAdmissionIntentRevision
                        )
                    } catch {
                        switch effect {
                        case .openRemoteAdmission(let generation):
                            self.markInputFailed(generation)
                            self.failCurrentInput(generation)
                            return
                        default:
                            self.markInputFailed(inputGeneration)
                            continue
                        }
                    }
                }
            }
        }
    }

    private func canApplyOpenAdmission(
        _ generation: TVVisionGeneration,
        admissionIntentRevision: UUID
    ) -> Bool {
        self.admissionIntentRevision == admissionIntentRevision
            && failedInputGeneration != generation
            && input?.inputGeneration == generation
            && state?.ownership == .stream(inputGeneration: generation)
            && surfaceGeneration != nil
    }

    private func releaseEffects(
        _ effects: [TVRemoteCaptureEffect],
        controllerLeases: [TVVisionControllerLease],
        prependingEvents: [TVRemoteInputEvent]
    ) -> [TVRemoteCaptureEffect] {
        guard let closeIndex = effects.firstIndex(where: {
            if case .closeRemoteAdmission = $0 { return true }
            return false
        }) else {
            return prependingEvents.map(TVRemoteCaptureEffect.sendRemote) + effects
        }
        var result = effects
        var insertionIndex = result.index(after: closeIndex)
        result.insert(
            .removeControllerHandlers(
                controllerLeases.sorted { $0.slot < $1.slot }
            ),
            at: insertionIndex
        )
        insertionIndex = result.index(after: insertionIndex)
        for event in prependingEvents.reversed()
        where !result.contains(.sendRemote(event)) {
            result.insert(.sendRemote(event), at: insertionIndex)
        }
        return result
    }

    private func complete(
        _ effect: TVRemoteCaptureEffect,
        admissionIntentRevision: UUID
    ) {
        switch effect {
        case .openRemoteAdmission(let generation):
            guard canApplyOpenAdmission(
                generation,
                admissionIntentRevision: admissionIntentRevision
            ) else { return }
            admittedInputGeneration = generation
        case .closeRemoteAdmission(let generation):
            if admittedInputGeneration == generation {
                admittedInputGeneration = nil
            }
        default:
            break
        }
    }

    private func markInputFailed(_ inputGeneration: TVVisionGeneration) {
        failedInputGeneration = inputGeneration
        if admittedInputGeneration == inputGeneration {
            admittedInputGeneration = nil
        }
    }

    private func advanceAdmissionIntentRevision() {
        admissionIntentRevision = UUID()
    }

    private func handleDeliveryFailure(
        _ inputGeneration: TVVisionGeneration,
        failedEvent: TVRemoteInputEvent
    ) {
        guard failedInputGeneration != inputGeneration else { return }
        markInputFailed(inputGeneration)
        failCurrentInput(
            inputGeneration,
            prependingEvents: [TVRemoteInputEvent(
                button: failedEvent.button,
                isDown: false
            )]
        )
    }

    private func failCurrentInput(
        _ inputGeneration: TVVisionGeneration,
        prependingEvents: [TVRemoteInputEvent] = []
    ) {
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
            controllerLeases: controllerLeases,
            prependingEvents: prependingEvents
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
