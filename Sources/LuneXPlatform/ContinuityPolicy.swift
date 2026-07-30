import Foundation

enum ApplePlatformFamily: String, Codable, Hashable, Sendable {
    case macOS
    case iOS
    case iPadOS
    case tvOS
    case visionOS
}

enum AppSceneActivity: String, Codable, Hashable, Sendable {
    case active
    case inactive
    case background
}

struct ContinuityPreferences: Codable, Equatable, Hashable, Sendable {
    var audioContinuityEnabled: Bool
    var pictureInPictureEnabled: Bool
    var reduceRenderingInBackground: Bool

    static let defaults = ContinuityPreferences(
        audioContinuityEnabled: true,
        pictureInPictureEnabled: true,
        reduceRenderingInBackground: true
    )
}

struct PlatformContinuityCapabilities: Codable, Equatable, Hashable, Sendable {
    var supportsAudioBackgroundMode: Bool
    var supportsPictureInPicture: Bool
    var hasAudioBackgroundModeDeclared: Bool
}

struct MobileContinuityActualMediaState:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    let generation: MobilePictureInPictureGeneration
    let pictureInPictureLifecycle: MobilePictureInPictureLifecycle
    let isPictureInPictureFrameSinkOperational: Bool
    let isAudioSessionActive: Bool
    let isAudioContinuityPermitted: Bool
}

enum MobileContinuityAction: Equatable, Sendable {
    case foreground
    case continueWithAudioAndPictureInPicture
    case continueAudioOnly
    case suspendForegroundRendering(reason: String)
    case pauseStream(reason: String)
    case warn(reason: String)
}

struct MobileContinuityContext: Codable, Equatable, Hashable, Sendable {
    var platform: ApplePlatformFamily
    var sceneActivity: AppSceneActivity
    var isStreamActive: Bool
    var preferences: ContinuityPreferences
    var capabilities: PlatformContinuityCapabilities
    var activeGeneration: MobilePictureInPictureGeneration?
    var actualMediaState: MobileContinuityActualMediaState?
}

enum MobileContinuityPolicyResolver {
    static func resolve(_ context: MobileContinuityContext) -> MobileContinuityAction {
        guard context.platform != .macOS else {
            return .warn(reason: "macOS uses window visibility policy, not mobile background continuity")
        }

        let resolution = MobileContinuityPathResolver.resolve(
            pathInput(for: context)
        )
        switch resolution.path {
        case .inactive, .foreground:
            return .foreground
        case .pictureInPicture:
            return .continueWithAudioAndPictureInPicture
        case .audioOnly:
            return .continueAudioOnly
        case .unavailable:
            switch resolution.unavailableReason {
            case .unsupportedPlatform:
                return .warn(
                    reason: "Mobile background continuity is unavailable on this platform"
                )
            case .backgroundConfigurationMissing:
                return fallback(
                    preferences: context.preferences,
                    reason: "Playback background mode is not declared"
                )
            case .noActivePermittedMediaPath, .none:
                return fallback(
                    preferences: context.preferences,
                    reason: "No supported mobile continuity path is active"
                )
            }
        }
    }

    private static func pathInput(
        for context: MobileContinuityContext
    ) -> MobileContinuityPathInput {
        let actualState: MobileContinuityActualMediaState?
        if let activeGeneration = context.activeGeneration,
           let candidate = context.actualMediaState,
           candidate.generation == activeGeneration {
            actualState = candidate
        } else {
            actualState = nil
        }

        let supportsPictureInPicture =
            context.capabilities.supportsPictureInPicture
        let supportsAudio =
            context.capabilities.supportsAudioBackgroundMode
        return MobileContinuityPathInput(
            platform: context.platform,
            sceneActivity: context.sceneActivity,
            isStreamActive: context.isStreamActive,
            pictureInPictureLifecycle: supportsPictureInPicture
                ? (actualState?.pictureInPictureLifecycle ?? .unprepared)
                : .unavailable,
            isPictureInPictureFrameSinkOperational:
                supportsPictureInPicture
                    && (actualState?
                        .isPictureInPictureFrameSinkOperational ?? false),
            isAudioSessionActive: supportsAudio
                && (actualState?.isAudioSessionActive ?? false),
            isAudioContinuityPermitted: supportsAudio
                && (actualState?.isAudioContinuityPermitted ?? false),
            hasPlaybackBackgroundModeDeclared:
                context.capabilities.hasAudioBackgroundModeDeclared,
            preferences: context.preferences
        )
    }

    private static func fallback(
        preferences: ContinuityPreferences,
        reason: String
    ) -> MobileContinuityAction {
        if preferences.reduceRenderingInBackground {
            return .suspendForegroundRendering(reason: reason)
        }
        return .pauseStream(reason: reason)
    }
}

struct PictureInPicturePresentationState: Codable, Equatable, Hashable, Sendable {
    var isActive: Bool
    var renderSize: PixelSize
    var updatedAt: Date
}

actor PictureInPictureStateCoordinator {
    private(set) var state: PictureInPicturePresentationState

    init(now: Date = Date()) {
        self.state = PictureInPicturePresentationState(isActive: false, renderSize: .zero, updatedAt: now)
    }

    func setActive(_ active: Bool, now: Date = Date()) -> PictureInPicturePresentationState {
        state.isActive = active
        state.updatedAt = now
        return state
    }

    func updateRenderSize(_ size: PixelSize, now: Date = Date()) -> PictureInPicturePresentationState {
        state.renderSize = size
        state.updatedAt = now
        return state
    }
}

enum MacBackgroundPerformanceAction: Equatable, Sendable {
    case idle
    case continueRendering(reason: String)
    case throttleRendering(reason: String)
    case pauseRendering(reason: String)
}

struct MacBackgroundPerformanceContext: Codable, Equatable, Hashable, Sendable {
    var isStreamActive: Bool
    var isAppActive: Bool
    var isWindowVisible: Bool
    var isWindowFocused: Bool
    var drawableSize: PixelSize
}

enum MacBackgroundPerformancePolicyResolver {
    static func resolve(_ context: MacBackgroundPerformanceContext) -> MacBackgroundPerformanceAction {
        guard context.isStreamActive else { return .idle }

        guard context.isWindowVisible else {
            return .pauseRendering(reason: "Stream window is occluded or minimized")
        }

        guard context.drawableSize.width > 0, context.drawableSize.height > 0 else {
            return .pauseRendering(reason: "Drawable is not ready")
        }

        if context.isAppActive && context.isWindowFocused {
            return .continueRendering(reason: "Stream window is active and focused")
        }

        if !context.isAppActive && context.isWindowVisible {
            return .throttleRendering(reason: "App is inactive but stream window remains visible")
        }

        return .throttleRendering(reason: "Stream window is visible but not focused")
    }
}
