import Foundation

struct MobileMediaGenerationRevision:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    let rawValue: UInt64

    init?(rawValue: UInt64) {
        guard rawValue > 0 else { return nil }
        self.rawValue = rawValue
    }
}

struct MobileMediaGenerationOwnership:
    Equatable,
    Hashable,
    Sendable
{
    let sessionID: UUID
    let generation: MobilePictureInPictureGeneration
}

enum MobileMediaGenerationSuspensionReason:
    String,
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case pictureInPictureActive = "picture-in-picture-active"
    case audioOnlyContinuity = "audio-only-continuity"
    case unsupportedPlatform = "unsupported-platform"
    case backgroundConfigurationMissing = "background-configuration-missing"
    case noActivePermittedMediaPath = "no-active-permitted-media-path"
    case streamInactive = "stream-inactive"
    case explicitStop = "explicit-stop"
}

enum MobileMediaForegroundDirective: Equatable, Sendable {
    case baseline(RenderPolicy)
    case suspended(reason: MobileMediaGenerationSuspensionReason)
    case restoreAndResample(RenderPolicy)
    case idle
}

enum MobileMediaVideoDirective: Equatable, Sendable {
    case continueForegroundPresentation
    case continuePictureInPictureDelivery
    case drainTransportWithoutDecoding
    case stop
}

enum MobileMediaAudioDirective: Equatable, Sendable {
    case continuePlayback
    case pause
    case stop
}

enum MobileMediaControlDirective: Equatable, Sendable {
    case continueSession
    case pauseSession
    case stopSession
}

enum MobileMediaStreamDirective: Equatable, Sendable {
    case running
    case paused(reason: MobileMediaGenerationSuspensionReason)
    case stopped
}

struct MobileMediaGenerationPlan: Equatable, Sendable {
    let continuityAction: MobileContinuityAction
    let foreground: MobileMediaForegroundDirective
    let video: MobileMediaVideoDirective
    let audio: MobileMediaAudioDirective
    let control: MobileMediaControlDirective
    let stream: MobileMediaStreamDirective
}

struct MobileMediaGenerationInput: Equatable, Sendable {
    let ownership: MobileMediaGenerationOwnership
    let revision: MobileMediaGenerationRevision
    let continuityContext: MobileContinuityContext
    let foregroundBaseline: RenderPolicy
}

enum MobileMediaGenerationTransition: Equatable, Sendable {
    case activate
    case update
    case replace(previous: MobileMediaGenerationOwnership)
    case stop
}

struct MobileMediaGenerationActionApplication: Equatable, Sendable {
    let ownership: MobileMediaGenerationOwnership
    let revision: MobileMediaGenerationRevision
    let transition: MobileMediaGenerationTransition
    let plan: MobileMediaGenerationPlan
}

protocol MobileMediaGenerationActionApplying: Sendable {
    func apply(_ application: MobileMediaGenerationActionApplication) async throws
}

struct MobileMediaGenerationSnapshot: Equatable, Sendable {
    enum Phase: Equatable, Sendable {
        case active
        case stopped
    }

    let ownership: MobileMediaGenerationOwnership
    let revision: MobileMediaGenerationRevision
    let phase: Phase
    let input: MobileMediaGenerationInput?
    let plan: MobileMediaGenerationPlan
    let foregroundRestorationCount: UInt64
}

enum MobileMediaGenerationPublicationOutcome: Equatable, Sendable {
    case unchanged(MobileMediaGenerationSnapshot)
    case stateUpdated(MobileMediaGenerationSnapshot)
    case actionsApplied(MobileMediaGenerationSnapshot)
}

enum MobileMediaGenerationOwnerError:
    Error,
    Equatable,
    Sendable
{
    case generationContextMismatch
    case staleGeneration
    case staleRevision
    case inactiveGeneration
    case foregroundRestorationCountExhausted
    case staleActionCompletion
}

enum MobileMediaGenerationPlanResolver {
    static func resolve(
        _ context: MobileContinuityContext,
        foregroundBaseline: RenderPolicy,
        restoringForeground: Bool
    ) -> MobileMediaGenerationPlan {
        guard context.isStreamActive else {
            return stoppedPlan(
                action: MobileContinuityPolicyResolver.resolve(context),
                reason: .streamInactive
            )
        }

        let action = MobileContinuityPolicyResolver.resolve(context)
        let resolution =
            MobileContinuityPolicyResolver.pathResolution(for: context)
        switch resolution.path {
        case .foreground:
            return MobileMediaGenerationPlan(
                continuityAction: action,
                foreground: restoringForeground
                    ? .restoreAndResample(foregroundBaseline)
                    : .baseline(foregroundBaseline),
                video: .continueForegroundPresentation,
                audio: .continuePlayback,
                control: .continueSession,
                stream: .running
            )
        case .pictureInPicture:
            return MobileMediaGenerationPlan(
                continuityAction: action,
                foreground: .suspended(
                    reason: .pictureInPictureActive
                ),
                video: .continuePictureInPictureDelivery,
                audio: .continuePlayback,
                control: .continueSession,
                stream: .running
            )
        case .audioOnly:
            return MobileMediaGenerationPlan(
                continuityAction: action,
                foreground: .suspended(reason: .audioOnlyContinuity),
                video: .drainTransportWithoutDecoding,
                audio: .continuePlayback,
                control: .continueSession,
                stream: .running
            )
        case .unavailable:
            let reason = suspensionReason(
                resolution.unavailableReason
            )
            return MobileMediaGenerationPlan(
                continuityAction: action,
                foreground: .suspended(reason: reason),
                video: .drainTransportWithoutDecoding,
                audio: .pause,
                control: .pauseSession,
                stream: .paused(reason: reason)
            )
        case .inactive:
            return stoppedPlan(action: action, reason: .streamInactive)
        }
    }

    static func stopPlan() -> MobileMediaGenerationPlan {
        stoppedPlan(
            action: .pauseStream(reason: "The mobile media generation stopped"),
            reason: .explicitStop
        )
    }

    private static func stoppedPlan(
        action: MobileContinuityAction,
        reason: MobileMediaGenerationSuspensionReason
    ) -> MobileMediaGenerationPlan {
        MobileMediaGenerationPlan(
            continuityAction: action,
            foreground: reason == .explicitStop
                ? .idle
                : .suspended(reason: reason),
            video: .stop,
            audio: .stop,
            control: .stopSession,
            stream: .stopped
        )
    }

    private static func suspensionReason(
        _ reason: MobileContinuityUnavailableReason?
    ) -> MobileMediaGenerationSuspensionReason {
        switch reason {
        case .unsupportedPlatform:
            .unsupportedPlatform
        case .backgroundConfigurationMissing:
            .backgroundConfigurationMissing
        case .noActivePermittedMediaPath, .none:
            .noActivePermittedMediaPath
        }
    }
}

private actor MobileMediaGenerationOperationGate {
    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isHeld {
            isHeld = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isHeld = false
            return
        }
        waiters.removeFirst().resume()
    }
}

actor MobileMediaGenerationOwner {
    private let actionClient: any MobileMediaGenerationActionApplying
    private let operationGate = MobileMediaGenerationOperationGate()

    private var activeSnapshot: MobileMediaGenerationSnapshot?
    private var latestSnapshot: MobileMediaGenerationSnapshot?
    private var reservedApplication:
        MobileMediaGenerationActionApplication?

    init(actionClient: any MobileMediaGenerationActionApplying) {
        self.actionClient = actionClient
    }

    func apply(
        _ input: MobileMediaGenerationInput
    ) async throws -> MobileMediaGenerationPublicationOutcome {
        await operationGate.acquire()
        do {
            try Task.checkCancellation()
            let outcome = try await applyLocked(input)
            await operationGate.release()
            return outcome
        } catch {
            await operationGate.release()
            throw error
        }
    }

    func stop(
        ownership: MobileMediaGenerationOwnership,
        revision: MobileMediaGenerationRevision
    ) async throws -> MobileMediaGenerationPublicationOutcome {
        await operationGate.acquire()
        do {
            try Task.checkCancellation()
            let outcome = try await stopLocked(
                ownership: ownership,
                revision: revision
            )
            await operationGate.release()
            return outcome
        } catch {
            await operationGate.release()
            throw error
        }
    }

    func snapshot() -> MobileMediaGenerationSnapshot? {
        latestSnapshot
    }

    private func applyLocked(
        _ input: MobileMediaGenerationInput
    ) async throws -> MobileMediaGenerationPublicationOutcome {
        try validateContextGeneration(input)

        let current = activeSnapshot
        let transition: MobileMediaGenerationTransition
        if let current {
            if input.ownership == current.ownership {
                guard input.revision.rawValue >= current.revision.rawValue else {
                    throw MobileMediaGenerationOwnerError.staleRevision
                }
                if input.revision == current.revision {
                    guard input == current.input else {
                        throw MobileMediaGenerationOwnerError.staleRevision
                    }
                    return .unchanged(current)
                }
                transition = .update
            } else {
                guard isNewer(
                    input.ownership.generation,
                    than: current.ownership.generation
                ) else {
                    throw MobileMediaGenerationOwnerError.staleGeneration
                }
                transition = .replace(previous: current.ownership)
            }
        } else {
            if let latestSnapshot,
               !isNewer(
                   input.ownership.generation,
                   than: latestSnapshot.ownership.generation
               ) {
                throw MobileMediaGenerationOwnerError.staleGeneration
            }
            transition = .activate
        }

        let restoringForeground =
            transition == .update
                && current?.plan.foreground.isSuppressed == true
                && MobileContinuityPolicyResolver.pathResolution(
                    for: input.continuityContext
                ).path == .foreground
        let restorationCount = try nextRestorationCount(
            current: current?.foregroundRestorationCount ?? 0,
            restoring: restoringForeground
        )
        let plan = MobileMediaGenerationPlanResolver.resolve(
            input.continuityContext,
            foregroundBaseline: input.foregroundBaseline,
            restoringForeground: restoringForeground
        )
        let next = MobileMediaGenerationSnapshot(
            ownership: input.ownership,
            revision: input.revision,
            phase: plan.stream == .stopped ? .stopped : .active,
            input: input,
            plan: plan,
            foregroundRestorationCount: restorationCount
        )

        if transition == .update,
           let current,
           current.plan == next.plan {
            activeSnapshot = next.phase == .active ? next : nil
            latestSnapshot = next
            return .stateUpdated(next)
        }

        let application = MobileMediaGenerationActionApplication(
            ownership: input.ownership,
            revision: input.revision,
            transition: plan.stream == .stopped ? .stop : transition,
            plan: plan
        )
        reservedApplication = application
        do {
            try await actionClient.apply(application)
        } catch {
            if reservedApplication == application {
                reservedApplication = nil
            }
            throw error
        }
        guard reservedApplication == application else {
            throw MobileMediaGenerationOwnerError.staleActionCompletion
        }
        reservedApplication = nil
        activeSnapshot = next.phase == .active ? next : nil
        latestSnapshot = next
        return .actionsApplied(next)
    }

    private func stopLocked(
        ownership: MobileMediaGenerationOwnership,
        revision: MobileMediaGenerationRevision
    ) async throws -> MobileMediaGenerationPublicationOutcome {
        guard let current = activeSnapshot else {
            if let latestSnapshot,
               latestSnapshot.ownership == ownership,
               latestSnapshot.phase == .stopped {
                guard revision.rawValue >= latestSnapshot.revision.rawValue else {
                    throw MobileMediaGenerationOwnerError.staleRevision
                }
                guard revision != latestSnapshot.revision else {
                    return .unchanged(latestSnapshot)
                }
                let next = MobileMediaGenerationSnapshot(
                    ownership: ownership,
                    revision: revision,
                    phase: .stopped,
                    input: nil,
                    plan: latestSnapshot.plan,
                    foregroundRestorationCount:
                        latestSnapshot.foregroundRestorationCount
                )
                self.latestSnapshot = next
                return .stateUpdated(next)
            }
            throw MobileMediaGenerationOwnerError.inactiveGeneration
        }
        guard current.ownership == ownership else {
            throw MobileMediaGenerationOwnerError.staleGeneration
        }
        guard revision.rawValue > current.revision.rawValue else {
            throw MobileMediaGenerationOwnerError.staleRevision
        }

        let plan = MobileMediaGenerationPlanResolver.stopPlan()
        let application = MobileMediaGenerationActionApplication(
            ownership: ownership,
            revision: revision,
            transition: .stop,
            plan: plan
        )
        reservedApplication = application
        do {
            try await actionClient.apply(application)
        } catch {
            if reservedApplication == application {
                reservedApplication = nil
            }
            throw error
        }
        guard reservedApplication == application else {
            throw MobileMediaGenerationOwnerError.staleActionCompletion
        }
        reservedApplication = nil
        let next = MobileMediaGenerationSnapshot(
            ownership: ownership,
            revision: revision,
            phase: .stopped,
            input: nil,
            plan: plan,
            foregroundRestorationCount:
                current.foregroundRestorationCount
        )
        activeSnapshot = nil
        latestSnapshot = next
        return .actionsApplied(next)
    }

    private func validateContextGeneration(
        _ input: MobileMediaGenerationInput
    ) throws {
        if let generation = input.continuityContext.activeGeneration,
           generation != input.ownership.generation {
            throw MobileMediaGenerationOwnerError
                .generationContextMismatch
        }
    }

    private func nextRestorationCount(
        current: UInt64,
        restoring: Bool
    ) throws -> UInt64 {
        guard restoring else { return current }
        let next = current.addingReportingOverflow(1)
        guard !next.overflow else {
            throw MobileMediaGenerationOwnerError
                .foregroundRestorationCountExhausted
        }
        return next.partialValue
    }

    private func isNewer(
        _ candidate: MobilePictureInPictureGeneration,
        than current: MobilePictureInPictureGeneration
    ) -> Bool {
        if candidate.mediaGeneration != current.mediaGeneration {
            return candidate.mediaGeneration > current.mediaGeneration
        }
        return candidate.pictureInPictureGeneration
            > current.pictureInPictureGeneration
    }
}

private extension MobileMediaForegroundDirective {
    var isSuppressed: Bool {
        switch self {
        case .suspended:
            true
        case .baseline, .restoreAndResample, .idle:
            false
        }
    }
}
