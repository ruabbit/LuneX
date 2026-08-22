import Foundation

enum VisionStreamWindowPresentationStatus: Equatable, Sendable {
    case unavailable
    case detached
    case inactive
    case hidden
    case visible
}

enum VisionStreamInputPresentationStatus: Equatable, Sendable {
    case unavailable
    case local(TVVisionFocusIneligibilityReason?)
    case captured(capabilityCount: Int)
    case releasing
}

enum VisionStreamControllerPresentationStatus: Equatable, Sendable {
    case unavailable
    case active(connected: Int, routed: Int)
}

enum VisionStreamRenderPresentationStatus: Equatable, Sendable {
    case inactive
    case waitingForWindow
    case waitingForDecoder
    case waitingForFrame
    case presenting
    case cleared
    case throttled
    case paused
    case failed
}

enum VisionStreamHDRPresentationStatus: Equatable, Sendable {
    case inactive
    case sdr
    case directEDR
    case sdrFallback(TVVisionDisplayHDRFallbackReason?)
    case updating
    case unavailable
    case failed
}

enum VisionStreamSpatialPresentationStatus: Equatable, Sendable {
    case inactive
    case unavailable
    case standard(channelCount: Int)
    case fixed(channelCount: Int)
    case headTracked(channelCount: Int)
    case recovering
    case failed
}

enum VisionStreamImmersivePresentationStatus: Equatable, Sendable {
    case unavailable
    case windowedOnly(VisionPresentationUnavailableReason?)
}

enum VisionStreamFailurePresentationStatus: Equatable, Sendable {
    case none
    case session
    case invalidComponent(TVVisionPlatformPresentationComponent)
    case actionFailed(TVVisionPlatformPresentationEffectKind)
    case semanticRevisionExhausted
    case sequenceExhausted

    init(_ failure: TVVisionPlatformPresentationFailure) {
        switch failure {
        case let .invalidComponent(component):
            self = .invalidComponent(component)
        case let .actionFailed(effect):
            self = .actionFailed(effect)
        case .semanticRevisionExhausted:
            self = .semanticRevisionExhausted
        case .sequenceExhausted:
            self = .sequenceExhausted
        }
    }
}

struct VisionStreamControlStatusContent: Identifiable, Equatable, Sendable {
    enum Kind: String, CaseIterable, Equatable, Sendable {
        case window
        case input
        case controllers
        case render
        case hdr
        case spatial
        case immersive
        case failure
    }

    let kind: Kind
    let title: LocalizedStringResource
    let value: LocalizedStringResource
    let detail: LocalizedStringResource
    let systemImage: String
    let isFailure: Bool

    var id: Kind { kind }
    var accessibilityValue: LocalizedStringResource { "\(value). \(detail)" }
}

struct VisionStreamControlReachability: Equatable, Sendable {
    let canHideControls: Bool
    let hideControlsAccessibilityValue: LocalizedStringResource
}

struct VisionStreamControlPresentationState: Equatable, Sendable {
    let window: VisionStreamWindowPresentationStatus
    let input: VisionStreamInputPresentationStatus
    let controllers: VisionStreamControllerPresentationStatus
    let render: VisionStreamRenderPresentationStatus
    let hdr: VisionStreamHDRPresentationStatus
    let spatial: VisionStreamSpatialPresentationStatus
    let immersive: VisionStreamImmersivePresentationStatus
    let failure: VisionStreamFailurePresentationStatus
    let reachability: VisionStreamControlReachability

    init(
        window: VisionStreamWindowPresentationStatus,
        input: VisionStreamInputPresentationStatus,
        controllers: VisionStreamControllerPresentationStatus,
        render: VisionStreamRenderPresentationStatus,
        hdr: VisionStreamHDRPresentationStatus,
        spatial: VisionStreamSpatialPresentationStatus,
        immersive: VisionStreamImmersivePresentationStatus,
        failure: VisionStreamFailurePresentationStatus,
        reachability: VisionStreamControlReachability =
            VisionStreamControlReachability(
                canHideControls: false,
                hideControlsAccessibilityValue:
                    "Remote input reachability is unavailable."
            )
    ) {
        self.window = window
        self.input = input
        self.controllers = controllers
        self.render = render
        self.hdr = hdr
        self.spatial = spatial
        self.immersive = immersive
        self.failure = failure
        self.reachability = reachability
    }

    var rows: [VisionStreamControlStatusContent] {
        [
            window.content,
            input.content,
            controllers.content,
            render.content,
            hdr.content,
            spatial.content,
            immersive.content,
            failure.content
        ]
    }
}

struct VisionStreamControlPresentationInput: Equatable, Sendable {
    let hasActiveSession: Bool
    let hasSessionFailure: Bool
    let windowedPresentation: VisionWindowedPresentationState?
    let sceneSurface: TVVisionSceneSurfaceSnapshot?
    let inputCapabilities: TVVisionInputCapabilitySnapshot?
    let inputCaptureEnabled: Bool
    let inputReleasePending: Bool
    let connectedControllerCount: Int
    let routedControllerCount: Int
    let renderPolicy: RenderPolicy
    let video: TVVisionPlatformVideoSnapshot?
    let hdrPresentation: HDRPresentationStatus
    let hdrFallbackReason: TVVisionDisplayHDRFallbackReason?
    let audioRoute: TVVisionAudioRouteSnapshot?
    let spatialAudio: SpatialAudioPresentationStatus
    let presentationFailure: TVVisionPlatformPresentationFailure?
}

enum VisionStreamControlPresentationStateResolver {
    static func resolve(
        _ input: VisionStreamControlPresentationInput
    ) -> VisionStreamControlPresentationState {
        let window = windowStatus(input)
        let inputStatus = inputStatus(input, window: window)
        let failure = failureStatus(input)
        return VisionStreamControlPresentationState(
            window: window,
            input: inputStatus,
            controllers: controllerStatus(input),
            render: renderStatus(input, window: window, failure: failure),
            hdr: hdrStatus(input),
            spatial: spatialStatus(input),
            immersive: immersiveStatus(input),
            failure: failure,
            reachability: reachabilityStatus(
                input,
                window: window,
                inputStatus: inputStatus
            )
        )
    }

    private static func windowStatus(
        _ input: VisionStreamControlPresentationInput
    ) -> VisionStreamWindowPresentationStatus {
        guard input.hasActiveSession,
              let presentation = input.windowedPresentation,
              presentation.mode == .windowed,
              let surface = input.sceneSurface,
              surface.platform == .visionOS,
              presentation.revision == surface.revision,
              presentation.surfaceGeneration
                == surface.surfaceGeneration else { return .unavailable }
        guard surface.attachment == .attached else { return .detached }
        guard surface.activity == .active else { return .inactive }
        return surface.isVisible ? .visible : .hidden
    }

    private static func inputStatus(
        _ input: VisionStreamControlPresentationInput,
        window: VisionStreamWindowPresentationStatus
    ) -> VisionStreamInputPresentationStatus {
        guard input.hasActiveSession,
              let presentation = input.windowedPresentation,
              let capabilities = input.inputCapabilities,
              capabilities.platform == .visionOS,
              presentation.revision == capabilities.revision,
              presentation.ownership.inputGeneration
                == capabilities.inputGeneration else { return .unavailable }
        if input.inputReleasePending { return .releasing }
        if input.inputCaptureEnabled,
           capabilities.focusEligibility == .eligible,
           window == .visible {
            return .captured(capabilityCount: capabilities.supported.count)
        }
        if case let .ineligible(reason) = capabilities.focusEligibility {
            return .local(reason)
        }
        return .local(nil)
    }

    private static func reachabilityStatus(
        _ input: VisionStreamControlPresentationInput,
        window: VisionStreamWindowPresentationStatus,
        inputStatus: VisionStreamInputPresentationStatus
    ) -> VisionStreamControlReachability {
        guard window == .visible,
              let presentation = input.windowedPresentation,
              let capabilities = input.inputCapabilities,
              capabilities.platform == .visionOS,
              presentation.revision == capabilities.revision,
              presentation.ownership.inputGeneration
                == capabilities.inputGeneration else {
            return VisionStreamControlReachability(
                canHideControls: false,
                hideControlsAccessibilityValue:
                    "Remote input is unavailable for the current window."
            )
        }

        switch inputStatus {
        case .local(.overlayVisible) where !capabilities.supported.isEmpty:
            return VisionStreamControlReachability(
                canHideControls: true,
                hideControlsAccessibilityValue:
                    "\(capabilities.supported.count) remote input paths available after controls close."
            )
        case .local(.overlayVisible):
            return VisionStreamControlReachability(
                canHideControls: false,
                hideControlsAccessibilityValue:
                    "No current remote input path is available."
            )
        case .releasing:
            return VisionStreamControlReachability(
                canHideControls: false,
                hideControlsAccessibilityValue:
                    "Remote input release is in progress."
            )
        case let .captured(capabilityCount):
            return VisionStreamControlReachability(
                canHideControls: false,
                hideControlsAccessibilityValue:
                    "Remote input is already active on \(capabilityCount) paths."
            )
        case let .local(reason):
            return VisionStreamControlReachability(
                canHideControls: false,
                hideControlsAccessibilityValue: reason?.visionDetail
                    ?? "Remote input is not currently eligible."
            )
        case .unavailable:
            return VisionStreamControlReachability(
                canHideControls: false,
                hideControlsAccessibilityValue:
                    "No current window input ownership is available."
            )
        }
    }

    private static func controllerStatus(
        _ input: VisionStreamControlPresentationInput
    ) -> VisionStreamControllerPresentationStatus {
        guard input.hasActiveSession,
              let presentation = input.windowedPresentation,
              let capabilities = input.inputCapabilities,
              capabilities.platform == .visionOS,
              presentation.revision == capabilities.revision,
              presentation.ownership.inputGeneration
                == capabilities.inputGeneration,
              (0...TVVisionControllerSlot.maximumCount)
                .contains(input.connectedControllerCount),
              (0...input.connectedControllerCount)
                .contains(input.routedControllerCount) else {
            return .unavailable
        }
        return .active(
            connected: input.connectedControllerCount,
            routed: input.routedControllerCount
        )
    }

    private static func renderStatus(
        _ input: VisionStreamControlPresentationInput,
        window: VisionStreamWindowPresentationStatus,
        failure: VisionStreamFailurePresentationStatus
    ) -> VisionStreamRenderPresentationStatus {
        guard input.hasActiveSession else { return .inactive }
        guard failure == .none else { return .failed }
        switch input.renderPolicy {
        case .paused: return .paused
        case .throttled: return .throttled
        case .idle, .active: break
        }
        guard window == .visible else { return .waitingForWindow }
        guard let video = input.video else { return .waitingForDecoder }
        switch video.phase {
        case .idle: return .waitingForDecoder
        case .decoderReady: return .waitingForFrame
        case .frameReady:
            return video.isPresented ? .presenting : .waitingForFrame
        case .cleared: return .cleared
        }
    }

    private static func hdrStatus(
        _ input: VisionStreamControlPresentationInput
    ) -> VisionStreamHDRPresentationStatus {
        guard input.hasActiveSession else { return .inactive }
        if let fallback = input.hdrFallbackReason {
            return .sdrFallback(fallback)
        }
        switch input.hdrPresentation {
        case .inactive: return .inactive
        case .sdr: return .sdr
        case .edr: return .directEDR
        case .sdrFallback: return .sdrFallback(nil)
        case .updating: return .updating
        case .invalidInput, .unsupportedOutput: return .unavailable
        case .pipelineFailure: return .failed
        }
    }

    private static func spatialStatus(
        _ input: VisionStreamControlPresentationInput
    ) -> VisionStreamSpatialPresentationStatus {
        guard input.hasActiveSession else { return .inactive }
        switch input.spatialAudio.mode {
        case .recovering: return .recovering
        case .failed: return .failed
        case .inactive, .nonspatial, .fixedSpatial, .headTracked,
             .visionFixed, .visionHeadTracked:
            break
        }
        guard let route = input.audioRoute,
              route.platform == .visionOS,
              route.outputAvailable,
              (1...64).contains(route.currentOutputChannelCount) else {
            return .unavailable
        }
        switch input.spatialAudio.mode {
        case .nonspatial:
            return .standard(channelCount: route.currentOutputChannelCount)
        case .visionFixed:
            return .fixed(channelCount: route.currentOutputChannelCount)
        case .visionHeadTracked:
            return .headTracked(channelCount: route.currentOutputChannelCount)
        case .inactive, .fixedSpatial, .headTracked, .recovering, .failed:
            return .unavailable
        }
    }

    private static func immersiveStatus(
        _ input: VisionStreamControlPresentationInput
    ) -> VisionStreamImmersivePresentationStatus {
        guard input.hasActiveSession,
              let presentation = input.windowedPresentation,
              presentation.mode == .windowed,
              Set(presentation.unavailableFeatures.map(\.feature))
                == Set(VisionUnavailablePresentationFeature.allCases) else {
            return .unavailable
        }
        let reasons = Set(presentation.unavailableFeatures.map(\.reason))
        return .windowedOnly(reasons.count == 1 ? reasons.first : nil)
    }

    private static func failureStatus(
        _ input: VisionStreamControlPresentationInput
    ) -> VisionStreamFailurePresentationStatus {
        if let failure = input.presentationFailure {
            return VisionStreamFailurePresentationStatus(failure)
        }
        return input.hasSessionFailure ? .session : .none
    }
}

private extension VisionStreamWindowPresentationStatus {
    var content: VisionStreamControlStatusContent {
        switch self {
        case .unavailable:
            content("Unavailable", "No current windowed stream presentation.", "macwindow.badge.plus")
        case .detached:
            content("Detached", "The current stream surface is detached.", "rectangle.slash")
        case .inactive:
            content("Inactive", "The current window scene is inactive.", "pause.rectangle")
        case .hidden:
            content("Hidden", "The current stream surface is not visible.", "eye.slash")
        case .visible:
            content("Visible", "The current window and stream surface are visible.", "macwindow")
        }
    }

    private func content(
        _ value: LocalizedStringResource,
        _ detail: LocalizedStringResource,
        _ systemImage: String
    ) -> VisionStreamControlStatusContent {
        VisionStreamControlStatusContent(
            kind: .window,
            title: "Window",
            value: value,
            detail: detail,
            systemImage: systemImage,
            isFailure: false
        )
    }
}

private extension VisionStreamInputPresentationStatus {
    var content: VisionStreamControlStatusContent {
        switch self {
        case .unavailable:
            content("Unavailable", "No current window input ownership.", "hand.raised.slash")
        case let .local(reason):
            content("Local", reason?.visionDetail ?? "System interaction remains local.", "hand.point.up.left")
        case let .captured(count):
            content("Captured", "\(count) supported input paths are current and eligible.", "scope")
        case .releasing:
            content("Releasing", "Held input is closing before local interaction returns.", "hand.raised")
        }
    }

    private func content(
        _ value: LocalizedStringResource,
        _ detail: LocalizedStringResource,
        _ systemImage: String
    ) -> VisionStreamControlStatusContent {
        VisionStreamControlStatusContent(
            kind: .input,
            title: "Input",
            value: value,
            detail: detail,
            systemImage: systemImage,
            isFailure: false
        )
    }
}

private extension TVVisionFocusIneligibilityReason {
    var visionDetail: LocalizedStringResource {
        switch self {
        case .detached: "The current stream surface is detached."
        case .sceneInactive: "The current window scene is inactive."
        case .notFocused: "The current window is not input eligible."
        case .overlayVisible: "Native stream controls own interaction."
        case .inputUnavailable: "Remote input is not ready."
        case .systemReserved: "The current interaction is system reserved."
        case .replacing: "Input ownership is being replaced."
        case .stopped: "Remote input is stopped."
        }
    }
}

private extension VisionStreamControllerPresentationStatus {
    var content: VisionStreamControlStatusContent {
        switch self {
        case .unavailable:
            VisionStreamControlStatusContent(
                kind: .controllers,
                title: "Controllers",
                value: "Unavailable",
                detail: "No valid current controller roster.",
                systemImage: "gamecontroller",
                isFailure: false
            )
        case let .active(connected, routed):
            VisionStreamControlStatusContent(
                kind: .controllers,
                title: "Controllers",
                value: "\(connected) connected, \(routed) routed",
                detail: routed == connected
                    ? "All current controllers are routed."
                    : "Only current-generation controllers are routed.",
                systemImage: "gamecontroller.fill",
                isFailure: false
            )
        }
    }
}

private extension VisionStreamRenderPresentationStatus {
    var content: VisionStreamControlStatusContent {
        let value: LocalizedStringResource
        let detail: LocalizedStringResource
        let image: String
        switch self {
        case .inactive: (value, detail, image) = ("Inactive", "No active video presentation.", "play.slash")
        case .waitingForWindow: (value, detail, image) = ("Waiting for window", "Rendering resumes in an eligible visible window.", "macwindow")
        case .waitingForDecoder: (value, detail, image) = ("Waiting for decoder", "No current decoder owns video output.", "hourglass")
        case .waitingForFrame: (value, detail, image) = ("Waiting for frame", "The current decoder has not presented a frame.", "film.stack")
        case .presenting: (value, detail, image) = ("Presenting", "A current decoded frame is on the Metal surface.", "play.rectangle.fill")
        case .cleared: (value, detail, image) = ("Cleared", "The current presentation has cleared its frame.", "rectangle.fill")
        case .throttled: (value, detail, image) = ("Throttled", "Rendering is reduced by the current lifecycle policy.", "gauge.with.dots.needle.33percent")
        case .paused: (value, detail, image) = ("Paused", "Rendering is paused by the current lifecycle policy.", "pause.rectangle.fill")
        case .failed: (value, detail, image) = ("Stopped", "The current platform presentation failed.", "xmark.rectangle")
        }
        return VisionStreamControlStatusContent(
            kind: .render,
            title: "Render",
            value: value,
            detail: detail,
            systemImage: image,
            isFailure: self == .failed
        )
    }
}

private extension VisionStreamHDRPresentationStatus {
    var content: VisionStreamControlStatusContent {
        let value: LocalizedStringResource
        let detail: LocalizedStringResource
        let image: String
        let failure: Bool
        switch self {
        case .inactive: (value, detail, image, failure) = ("Inactive", "No active HDR presentation.", "sun.min", false)
        case .sdr: (value, detail, image, failure) = ("SDR", "Current video uses standard dynamic range.", "sun.min.fill", false)
        case .directEDR: (value, detail, image, failure) = ("HDR / EDR", "Current video uses direct extended-range output.", "sun.max.fill", false)
        case let .sdrFallback(reason): (value, detail, image, failure) = ("SDR fallback", reason?.visionDetail ?? "Current HDR video is mapped to standard dynamic range.", "exclamationmark.triangle", false)
        case .updating: (value, detail, image, failure) = ("Updating", "Waiting for video matching the current output.", "arrow.triangle.2.circlepath", false)
        case .unavailable: (value, detail, image, failure) = ("Unavailable", "The current video or output cannot present HDR.", "sun.max.trianglebadge.exclamationmark", true)
        case .failed: (value, detail, image, failure) = ("Stopped", "The current HDR pipeline could not continue.", "xmark.octagon", true)
        }
        return VisionStreamControlStatusContent(
            kind: .hdr,
            title: "HDR",
            value: value,
            detail: detail,
            systemImage: image,
            isFailure: failure
        )
    }
}

private extension TVVisionDisplayHDRFallbackReason {
    var visionDetail: LocalizedStringResource {
        switch self {
        case .outputUnavailable: "The current window output is unavailable."
        case .preferredDynamicRangeUnavailable: "The current layer cannot request direct HDR output."
        case .toneMapControlUnavailable: "The current layer has no direct tone-map control."
        case .contentsHeadroomUnavailable: "The current layer cannot apply content headroom."
        case .extendedColorSpaceUnavailable: "The current layer has no supported extended color space."
        case .headroomUnavailable: "Current public display headroom is unavailable."
        case .invalidHeadroom: "Current display headroom is invalid."
        case .insufficientHeadroom: "Current headroom requires standard dynamic range."
        }
    }
}

private extension VisionStreamSpatialPresentationStatus {
    var content: VisionStreamControlStatusContent {
        let value: LocalizedStringResource
        let detail: LocalizedStringResource
        let image: String
        let failure: Bool
        switch self {
        case .inactive: (value, detail, image, failure) = ("Inactive", "No active spatial presentation.", "speaker.slash", false)
        case .unavailable: (value, detail, image, failure) = ("Unavailable", "No current visionOS audio route is available.", "speaker.slash", false)
        case let .standard(count): (value, detail, image, failure) = ("\(count) ch standard", "Current audio uses the standard output route.", "speaker.wave.2", false)
        case let .fixed(count): (value, detail, image, failure) = ("\(count) ch fixed", "Current audio uses the intended fixed spatial experience.", "wave.3.right.circle", false)
        case let .headTracked(count): (value, detail, image, failure) = ("\(count) ch head tracked", "Current audio uses the intended head-tracked experience.", "person.wave.2", false)
        case .recovering: (value, detail, image, failure) = ("Recovering", "Waiting for the current audio graph to resume.", "arrow.triangle.2.circlepath", false)
        case .failed: (value, detail, image, failure) = ("Stopped", "The current audio graph could not continue.", "xmark.octagon", true)
        }
        return VisionStreamControlStatusContent(
            kind: .spatial,
            title: "Spatial",
            value: value,
            detail: detail,
            systemImage: image,
            isFailure: failure
        )
    }
}

private extension VisionStreamImmersivePresentationStatus {
    var content: VisionStreamControlStatusContent {
        switch self {
        case .unavailable:
            VisionStreamControlStatusContent(
                kind: .immersive,
                title: "Immersive",
                value: "Unavailable",
                detail: "No current windowed presentation contract.",
                systemImage: "vision.pro",
                isFailure: false
            )
        case let .windowedOnly(reason):
            VisionStreamControlStatusContent(
                kind: .immersive,
                title: "Immersive",
                value: "Windowed only",
                detail: reason?.detail
                    ?? "Immersive, passthrough, stereoscopic, and volumetric presentation are unavailable.",
                systemImage: "vision.pro.slash",
                isFailure: false
            )
        }
    }
}

private extension VisionPresentationUnavailableReason {
    var detail: LocalizedStringResource {
        switch self {
        case .stage18WindowedOnly: "This runtime supports windowed streaming only."
        case .runtimeUnavailable: "Immersive presentation runtime is unavailable."
        case .publicCapabilityUnavailable: "Required public immersive capability is unavailable."
        }
    }
}

private extension VisionStreamFailurePresentationStatus {
    var content: VisionStreamControlStatusContent {
        let value: LocalizedStringResource
        let detail: LocalizedStringResource
        switch self {
        case .none: (value, detail) = ("None", "No current bounded platform failure.")
        case .session: (value, detail) = ("Session stopped", "The current stream session failed.")
        case let .invalidComponent(component): (value, detail) = ("Invalid \(component.visionLabel)", "The current platform component was rejected.")
        case let .actionFailed(effect): (value, detail) = ("\(effect.visionLabel) failed", "The current platform action could not complete.")
        case .semanticRevisionExhausted: (value, detail) = ("Revision exhausted", "Platform state updates stopped at a bounded revision limit.")
        case .sequenceExhausted: (value, detail) = ("Sequence exhausted", "Platform actions stopped at a bounded sequence limit.")
        }
        return VisionStreamControlStatusContent(
            kind: .failure,
            title: "Failure",
            value: value,
            detail: detail,
            systemImage: self == .none ? "checkmark.circle" : "exclamationmark.octagon",
            isFailure: self != .none
        )
    }
}

private extension TVVisionPlatformPresentationComponent {
    var visionLabel: LocalizedStringResource {
        switch self {
        case .scene: "scene"
        case .input: "input"
        case .display: "display"
        case .audioRoute: "audio route"
        case .video: "video"
        }
    }
}

private extension TVVisionPlatformPresentationEffectKind {
    var visionLabel: LocalizedStringResource {
        switch self {
        case .scene: "Scene"
        case .input: "Input"
        case .display: "Display"
        case .audioRoute: "Audio route"
        case .video: "Video"
        case .clearVideo: "Video clear"
        case .teardown: "Teardown"
        case .snapshot: "State publication"
        }
    }
}
