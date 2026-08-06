import Foundation

enum MobileScenePresentationStatus: Equatable, Sendable {
    case noSession
    case unknown
    case active
    case inactive
    case background
    case detached
    case resizing
    case invalidGeometry
}

enum MobilePictureInPicturePresentationStatus: Equatable, Sendable {
    case noSession
    case disabled
    case unavailable
    case preparing
    case ready
    case starting
    case active
    case stopping
    case stopped
    case failed
}

enum MobileContinuityPresentationStatus: Equatable, Sendable {
    case noSession
    case unavailable
    case foreground
    case pictureInPicture
    case audioOnly
    case suspended
    case paused
    case stopped
}

enum MobileDisplayPresentationStatus: Equatable, Sendable {
    case noSession
    case unknown
    case detached
    case sdr
    case edrCapable(potentialHeadroom: Double, currentHeadroom: Double)
    case edrActive(currentHeadroom: Double)
    case sdrFallback
    case invalidHeadroom
    case reconfiguring
}

enum MobilePictureInPictureCommand: Equatable, Sendable {
    case start
    case stop
}

enum MobilePictureInPictureCommandAvailability: Equatable, Sendable {
    case hidden
    case start
    case stop
    case stopPending
}

enum MobilePictureInPictureCommandResult: Equatable, Sendable {
    case accepted
    case unchanged
    case unavailable
    case rejected
    case revisionExhausted
    case unsupportedPlatform
}

struct MobileExperiencePresentationStatus: Equatable, Sendable {
    let scene: MobileScenePresentationStatus
    let pictureInPicture: MobilePictureInPicturePresentationStatus
    let continuity: MobileContinuityPresentationStatus
    let display: MobileDisplayPresentationStatus
    let pictureInPictureCommand: MobilePictureInPictureCommandAvailability
}

enum MobileExperiencePresentationStatusResolver {
    private static let maximumDisplayHeadroom = 64.0

    static func resolve(
        hasActiveSession: Bool,
        scene: MobileSceneWindowState?,
        pictureInPicture: MobilePictureInPictureSemanticState?,
        continuityPath: MobileContinuityPath?,
        streamDirective: MobileMediaStreamDirective?,
        displayEDR: MobileDisplayEDRState?,
        hdrPresentation: HDRPresentationStatus,
        preferences: ContinuityPreferences
    ) -> MobileExperiencePresentationStatus {
        MobileExperiencePresentationStatus(
            scene: sceneStatus(hasActiveSession: hasActiveSession, state: scene),
            pictureInPicture: pictureInPictureStatus(
                hasActiveSession: hasActiveSession,
                state: pictureInPicture,
                preferences: preferences
            ),
            continuity: continuityStatus(
                hasActiveSession: hasActiveSession,
                path: continuityPath,
                streamDirective: streamDirective
            ),
            display: displayStatus(
                hasActiveSession: hasActiveSession,
                state: displayEDR,
                hdrPresentation: hdrPresentation
            ),
            pictureInPictureCommand: pictureInPictureCommandAvailability(
                hasActiveSession: hasActiveSession,
                state: pictureInPicture,
                preferences: preferences
            )
        )
    }

    private static func sceneStatus(
        hasActiveSession: Bool,
        state: MobileSceneWindowState?
    ) -> MobileScenePresentationStatus {
        guard hasActiveSession else { return .noSession }
        guard let state else { return .unknown }

        switch state {
        case .detached:
            return .detached
        case .unavailable:
            return .invalidGeometry
        case let .attached(activity, _, geometry):
            if geometry.resizePhase == .resizing { return .resizing }
            switch activity {
            case .active: return .active
            case .inactive: return .inactive
            case .background: return .background
            }
        }
    }

    private static func pictureInPictureStatus(
        hasActiveSession: Bool,
        state: MobilePictureInPictureSemanticState?,
        preferences: ContinuityPreferences
    ) -> MobilePictureInPicturePresentationStatus {
        guard hasActiveSession else { return .noSession }
        guard preferences.pictureInPictureEnabled else { return .disabled }
        guard let state else { return .unavailable }

        switch state.lifecycle {
        case .unprepared, .unavailable, .invalidated:
            return .unavailable
        case .preparing:
            return .preparing
        case .ready:
            return .ready
        case .startRequested, .starting:
            return .starting
        case .active:
            return .active
        case .stopRequested, .stopping:
            return .stopping
        case .stopped:
            return .stopped
        case .failed:
            return .failed
        }
    }

    private static func continuityStatus(
        hasActiveSession: Bool,
        path: MobileContinuityPath?,
        streamDirective: MobileMediaStreamDirective?
    ) -> MobileContinuityPresentationStatus {
        guard hasActiveSession else { return .noSession }
        switch streamDirective {
        case .stopped:
            return .stopped
        case .paused:
            return .paused
        case .running, .none:
            break
        }
        guard let path else { return .unavailable }
        switch path {
        case .inactive:
            return .suspended
        case .foreground:
            return .foreground
        case .pictureInPicture:
            return .pictureInPicture
        case .audioOnly:
            return .audioOnly
        case .unavailable:
            return .suspended
        }
    }

    private static func displayStatus(
        hasActiveSession: Bool,
        state: MobileDisplayEDRState?,
        hdrPresentation: HDRPresentationStatus
    ) -> MobileDisplayPresentationStatus {
        guard hasActiveSession else { return .noSession }
        guard let state else { return .unknown }

        switch state {
        case .unknown:
            return .unknown
        case .detached:
            return .detached
        case .unavailable:
            return .unknown
        case .sdrFallback:
            return .invalidHeadroom
        case let .available(available):
            if hdrPresentation == .updating { return .reconfiguring }
            if case .sdrFallback = hdrPresentation { return .sdrFallback }
            switch available.capability {
            case .sdr:
                return .sdr
            case .edrCapable:
                let potential = boundedHeadroom(available.headroom.potential)
                let current = boundedHeadroom(available.headroom.current)
                if hdrPresentation == .edr {
                    return .edrActive(currentHeadroom: current)
                }
                return .edrCapable(
                    potentialHeadroom: potential,
                    currentHeadroom: current
                )
            }
        }
    }

    private static func pictureInPictureCommandAvailability(
        hasActiveSession: Bool,
        state: MobilePictureInPictureSemanticState?,
        preferences: ContinuityPreferences
    ) -> MobilePictureInPictureCommandAvailability {
        guard hasActiveSession,
              preferences.pictureInPictureEnabled,
              let state,
              state.capability.isPossible,
              state.frameSink.acceptsCurrentGenerationFrames else {
            return .hidden
        }

        switch state.lifecycle {
        case .ready, .stopped:
            return .start
        case .startRequested, .starting, .active:
            return .stop
        case .stopRequested, .stopping:
            return .stopPending
        case .unprepared, .preparing, .unavailable, .failed, .invalidated:
            return .hidden
        }
    }

    private static func boundedHeadroom(_ value: Double) -> Double {
        min(
            maximumDisplayHeadroom,
            max(1, value)
        )
    }
}
