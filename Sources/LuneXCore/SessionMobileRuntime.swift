import Foundation

struct SessionMobileRuntimeRevision:
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

enum SessionMobileRuntimeValidationError:
    Error,
    Equatable,
    Sendable
{
    case invalidMediaGeneration
    case generationMismatch
    case surfaceGenerationMismatch
    case sceneActivityMismatch
}

struct SessionMobileRuntimeApplication: Equatable, Sendable {
    let sessionID: UUID
    let mediaGeneration: UInt64
    let revision: SessionMobileRuntimeRevision
    let generation: MobilePictureInPictureGeneration
    let platform: ApplePlatformFamily
    let sceneActivity: AppSceneActivity
    let surfaceGeneration: MobileSceneSurfaceGeneration?
    let sceneWindow: MobileSceneWindowSnapshot?
    let displayEDR: MobileDisplayEDRSnapshot?
    let pictureInPicture: MobilePictureInPictureSnapshot?
    let isAudioSessionActive: Bool?
    let isAudioContinuityPermitted: Bool
    let preferences: ContinuityPreferences
    let capabilities: PlatformContinuityCapabilities
    let foregroundBaseline: RenderPolicy

    func validate() throws {
        guard mediaGeneration > 0 else {
            throw SessionMobileRuntimeValidationError.invalidMediaGeneration
        }
        guard generation.mediaGeneration == mediaGeneration,
              pictureInPicture?.generation == nil
                || pictureInPicture?.generation == generation else {
            throw SessionMobileRuntimeValidationError.generationMismatch
        }
        if let sceneWindow {
            guard sceneWindow.surfaceGeneration == surfaceGeneration else {
                throw SessionMobileRuntimeValidationError
                    .surfaceGenerationMismatch
            }
            guard sceneWindow.state.activity == sceneActivity else {
                throw SessionMobileRuntimeValidationError
                    .sceneActivityMismatch
            }
        }
        if let displayEDR {
            guard displayEDR.surfaceGeneration == surfaceGeneration else {
                throw SessionMobileRuntimeValidationError
                    .surfaceGenerationMismatch
            }
        }
    }

    var continuityContext: MobileContinuityContext {
        let lifecycle = pictureInPicture?.state.lifecycle ?? .unprepared
        let frameSinkOperational = pictureInPicture?
            .state.frameSink.acceptsCurrentGenerationFrames ?? false
        return MobileContinuityContext(
            platform: platform,
            sceneActivity: sceneActivity,
            isStreamActive: true,
            preferences: preferences,
            capabilities: capabilities,
            activeGeneration: generation,
            actualMediaState: MobileContinuityActualMediaState(
                generation: generation,
                pictureInPictureLifecycle: lifecycle,
                isPictureInPictureFrameSinkOperational:
                    frameSinkOperational,
                isAudioSessionActive: isAudioSessionActive == true,
                isAudioContinuityPermitted: isAudioContinuityPermitted
            )
        )
    }

    var generationInput: MobileMediaGenerationInput {
        MobileMediaGenerationInput(
            ownership: MobileMediaGenerationOwnership(
                sessionID: sessionID,
                generation: generation
            ),
            revision: MobileMediaGenerationRevision(
                rawValue: revision.rawValue
            )!,
            continuityContext: continuityContext,
            foregroundBaseline: foregroundBaseline
        )
    }
}

struct SessionMobileRuntimeState: Equatable, Sendable {
    let application: SessionMobileRuntimeApplication
    let media: MobileMediaGenerationSnapshot

    var continuityPath: MobileContinuityPath {
        MobileContinuityPolicyResolver.pathResolution(
            for: application.continuityContext
        ).path
    }
}

struct SessionMobileVideoApplication: Equatable, Sendable {
    let sessionID: UUID
    let mediaGeneration: UInt64
    let generation: MobilePictureInPictureGeneration
    let revision: MobileMediaGenerationRevision
    let directive: MobileMediaVideoDirective
}

struct SessionMobileAudioApplication: Equatable, Sendable {
    let sessionID: UUID
    let mediaGeneration: UInt64
    let generation: MobilePictureInPictureGeneration
    let revision: MobileMediaGenerationRevision
    let directive: MobileMediaAudioDirective
}

struct SessionMobileControlApplication: Equatable, Sendable {
    let sessionID: UUID
    let mediaGeneration: UInt64
    let generation: MobilePictureInPictureGeneration
    let revision: MobileMediaGenerationRevision
    let directive: MobileMediaControlDirective

    func isNewer(than current: Self) -> Bool {
        guard sessionID == current.sessionID else { return false }
        if generation.mediaGeneration != current.generation.mediaGeneration {
            return generation.mediaGeneration > current.generation.mediaGeneration
        }
        if generation.pictureInPictureGeneration
            != current.generation.pictureInPictureGeneration {
            return generation.pictureInPictureGeneration
                > current.generation.pictureInPictureGeneration
        }
        return revision.rawValue > current.revision.rawValue
    }
}
