import Foundation

enum SpatialAudioPresentationFallback: Hashable, Sendable {
    case staleRevision
    case outputUnavailable
    case invalidRoute
    case layoutMismatch
    case userDisabled
    case unsupportedLayout
    case graphUnavailable
    case renderingAlgorithmUnavailable
    case routeUnsupported
    case missingEntitlement
    case unreadableEntitlement
    case incompatiblePlatformStrategy
    case headTrackingNotApplied
    case visionExperienceNotApplied

    init(_ reason: SpatialAudioFallbackReason) {
        switch reason {
        case .staleRevision:
            self = .staleRevision
        case .outputUnavailable:
            self = .outputUnavailable
        case .invalidRouteSnapshot:
            self = .invalidRoute
        case .layoutMismatch:
            self = .layoutMismatch
        case .userDisabled:
            self = .userDisabled
        case .unsupportedLayout:
            self = .unsupportedLayout
        case .graphUnavailable:
            self = .graphUnavailable
        case .renderingAlgorithmUnavailable:
            self = .renderingAlgorithmUnavailable
        case .routeUnsupported:
            self = .routeUnsupported
        case .missingEntitlement:
            self = .missingEntitlement
        case .unreadableEntitlement:
            self = .unreadableEntitlement
        case .incompatiblePlatformStrategy:
            self = .incompatiblePlatformStrategy
        case .headTrackingNotApplied:
            self = .headTrackingNotApplied
        case .visionExperienceNotApplied:
            self = .visionExperienceNotApplied
        }
    }

    var detail: LocalizedStringResource {
        switch self {
        case .staleRevision:
            "Waiting for current audio route state."
        case .outputUnavailable:
            "No active audio output is available."
        case .invalidRoute:
            "Current audio output capability is invalid."
        case .layoutMismatch:
            "Current channel layout does not match the spatial graph."
        case .userDisabled:
            "Spatial audio is disabled in settings."
        case .unsupportedLayout:
            "Current channel layout does not support spatial playback."
        case .graphUnavailable:
            "The spatial audio graph is unavailable."
        case .renderingAlgorithmUnavailable:
            "No spatial rendering algorithm is available for the current output."
        case .routeUnsupported:
            "Current audio output does not support spatial playback."
        case .missingEntitlement:
            "Fixed spatial playback is active; head tracking needs a signed entitlement."
        case .unreadableEntitlement:
            "Fixed spatial playback is active; head-tracking entitlement status is unavailable."
        case .incompatiblePlatformStrategy:
            "The current platform cannot apply the requested spatial mode."
        case .headTrackingNotApplied:
            "Fixed spatial playback is active; head tracking was not applied."
        case .visionExperienceNotApplied:
            "The requested visionOS spatial experience was not applied."
        }
    }
}

struct SpatialAudioPresentationStatus: Hashable, Sendable {
    enum Mode: Hashable, Sendable {
        case inactive
        case nonspatial
        case fixedSpatial
        case headTracked
        case visionFixed
        case visionHeadTracked
        case recovering
        case failed
    }

    let mode: Mode
    let fallback: SpatialAudioPresentationFallback?

    init(
        mode: Mode,
        fallback: SpatialAudioPresentationFallback?
    ) {
        self.mode = mode
        self.fallback = fallback
    }

    static let inactive = SpatialAudioPresentationStatus(
        mode: .inactive,
        fallback: nil
    )

    init(_ state: SessionMediaAudioRuntimeState?) {
        self.init(state?.runtime)
    }

    init(_ runtime: SessionAudioRuntimeEvent?) {
        guard let runtime else {
            self = .inactive
            return
        }
        if runtime.stage == .idle || runtime.stage == .stopped {
            self = .inactive
            return
        }
        if runtime.stage == .failed || runtime.cause == .failed {
            self = SpatialAudioPresentationStatus(
                mode: .failed,
                fallback: runtime.spatialRuntime?.fallbackReason.map(
                    SpatialAudioPresentationFallback.init
                )
            )
            return
        }
        if runtime.stage == .interrupted
            || runtime.cause == .interruptionBegan
            || runtime.cause == .mediaServicesLost {
            self = SpatialAudioPresentationStatus(
                mode: .recovering,
                fallback: nil
            )
            return
        }
        guard let spatial = runtime.spatialRuntime else {
            self = SpatialAudioPresentationStatus(
                mode: .nonspatial,
                fallback: nil
            )
            return
        }

        let mode: Mode
        switch spatial.presentationMode {
        case .inactive:
            mode = .inactive
        case .nonspatial:
            mode = .nonspatial
        case .fixedSpatial:
            mode = spatial.platformStrategy == .visionOutputExperience
                ? .visionFixed
                : .fixedSpatial
        case .headTracked:
            mode = spatial.platformStrategy == .visionOutputExperience
                ? .visionHeadTracked
                : .headTracked
        }
        self = SpatialAudioPresentationStatus(
            mode: mode,
            fallback: spatial.fallbackReason.map(
                SpatialAudioPresentationFallback.init
            )
        )
    }

    var content: SpatialAudioPresentationStatusContent {
        let base: SpatialAudioPresentationStatusContent
        switch mode {
        case .inactive:
            base = SpatialAudioPresentationStatusContent(
                overlayLabel: "Spatial inactive",
                settingsValue: "Inactive",
                detail: "No active audio presentation.",
                systemImage: "speaker.slash"
            )
        case .nonspatial:
            base = SpatialAudioPresentationStatusContent(
                overlayLabel: "Nonspatial",
                settingsValue: "Nonspatial",
                detail: "Current audio is using standard channel playback.",
                systemImage: "speaker.wave.2"
            )
        case .fixedSpatial:
            base = SpatialAudioPresentationStatusContent(
                overlayLabel: "Fixed spatial",
                settingsValue: "Fixed spatial",
                detail: "Current audio is using fixed spatial playback.",
                systemImage: "wave.3.right.circle"
            )
        case .headTracked:
            base = SpatialAudioPresentationStatusContent(
                overlayLabel: "Head tracked",
                settingsValue: "Head tracked",
                detail: "Current spatial audio is following listener head movement.",
                systemImage: "person.wave.2"
            )
        case .visionFixed:
            base = SpatialAudioPresentationStatusContent(
                overlayLabel: "Vision fixed",
                settingsValue: "visionOS fixed spatial",
                detail: "Current audio is using a fixed visionOS spatial experience.",
                systemImage: "viewfinder.circle"
            )
        case .visionHeadTracked:
            base = SpatialAudioPresentationStatusContent(
                overlayLabel: "Vision head tracked",
                settingsValue: "visionOS head tracked",
                detail: "Current audio is using a head-tracked visionOS spatial experience.",
                systemImage: "person.wave.2"
            )
        case .recovering:
            base = SpatialAudioPresentationStatusContent(
                overlayLabel: "Audio recovering",
                settingsValue: "Recovering",
                detail: "Waiting for the current audio graph to resume.",
                systemImage: "arrow.triangle.2.circlepath"
            )
        case .failed:
            base = SpatialAudioPresentationStatusContent(
                overlayLabel: "Audio stopped",
                settingsValue: "Output stopped",
                detail: "The current audio graph could not continue.",
                systemImage: "xmark.octagon"
            )
        }
        guard let fallback else { return base }
        let detail = fallback.detail
        return SpatialAudioPresentationStatusContent(
            overlayLabel: fallback == .userDisabled
                ? "Spatial off"
                : base.overlayLabel,
            settingsValue: base.settingsValue,
            detail: detail,
            systemImage: base.systemImage
        )
    }
}

struct SpatialAudioPresentationStatusContent: Sendable {
    let overlayLabel: LocalizedStringResource
    let settingsValue: LocalizedStringResource
    let detail: LocalizedStringResource
    let systemImage: String
}

enum SpatialAudioSettingsLayout: Hashable, Sendable {
    case compact
    case wide

    init(
        horizontalSizeClassIsCompact: Bool,
        usesAccessibilityTextSize: Bool
    ) {
        self = horizontalSizeClassIsCompact || usesAccessibilityTextSize
            ? .compact
            : .wide
    }
}
