import Foundation

enum TVStreamLocalFocusPresentationStatus: Equatable, Sendable {
    case unavailable
    case localControls
    case streamSurface
    case handoffPending
}

enum TVStreamCapturePresentationStatus: Equatable, Sendable {
    case unavailable
    case local
    case remote
    case releasePending
}

enum TVStreamSurfacePresentationStatus: Equatable, Sendable {
    case unavailable
    case detached
    case inactive
    case hidden
    case visible
}

enum TVStreamControllerPresentationStatus: Equatable, Sendable {
    case unavailable
    case active(connected: Int, routed: Int)
}

enum TVStreamRenderPresentationStatus: Equatable, Sendable {
    case inactive
    case waitingForSurface
    case waitingForDecoder
    case waitingForFrame
    case presenting
    case cleared
    case throttled
    case paused
    case failed
}

enum TVStreamHDRPresentationStatus: Equatable, Sendable {
    case inactive
    case sdr
    case directEDR
    case sdrFallback(TVOSDisplayHDRFallbackReason?)
    case updating
    case unavailable
    case failed
}

enum TVStreamAudioPresentationStatus: Equatable, Sendable {
    case inactive
    case unavailable
    case standard(channelCount: Int)
    case spatial(
        channelCount: Int,
        mode: SpatialAudioPresentationStatus.Mode
    )
    case recovering
    case failed
}

enum TVStreamFailurePresentationStatus: Equatable, Sendable {
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

struct TVStreamControlStatusContent: Identifiable, Equatable, Sendable {
    enum Kind: String, CaseIterable, Equatable, Sendable {
        case focus
        case capture
        case controllers
        case surface
        case render
        case hdr
        case audio
        case failure
    }

    let kind: Kind
    let title: String
    let value: String
    let detail: String
    let systemImage: String
    let isFailure: Bool

    var id: Kind { kind }

    var accessibilityValue: String {
        "\(value). \(detail)"
    }
}

struct TVStreamControlPresentationState: Equatable, Sendable {
    let focus: TVStreamLocalFocusPresentationStatus
    let capture: TVStreamCapturePresentationStatus
    let controllers: TVStreamControllerPresentationStatus
    let surface: TVStreamSurfacePresentationStatus
    let render: TVStreamRenderPresentationStatus
    let hdr: TVStreamHDRPresentationStatus
    let audio: TVStreamAudioPresentationStatus
    let failure: TVStreamFailurePresentationStatus

    var rows: [TVStreamControlStatusContent] {
        [
            focus.content,
            capture.content,
            controllers.content,
            surface.content,
            render.content,
            hdr.content,
            audio.content,
            failure.content
        ]
    }
}

struct TVStreamControlPresentationInput: Equatable, Sendable {
    let hasActiveSession: Bool
    let hasSessionFailure: Bool
    let focusHandoff: TVRemoteFocusHandoffState
    let remoteCaptureDisposition: TVRemoteSurfacePressDisposition
    let isRemoteReleasePending: Bool
    let sceneSurface: TVVisionSceneSurfaceSnapshot?
    let connectedControllerCount: Int
    let routedControllerCount: Int
    let renderPolicy: RenderPolicy
    let video: TVVisionPlatformVideoSnapshot?
    let hdrPresentation: HDRPresentationStatus
    let hdrFallbackReason: TVOSDisplayHDRFallbackReason?
    let audioRoute: TVVisionAudioRouteSnapshot?
    let spatialAudio: SpatialAudioPresentationStatus
    let presentationFailure: TVVisionPlatformPresentationFailure?
}

enum TVStreamControlPresentationStateResolver {
    static func resolve(
        _ input: TVStreamControlPresentationInput
    ) -> TVStreamControlPresentationState {
        let surface = surfaceStatus(input)
        let failure = failureStatus(input)
        return TVStreamControlPresentationState(
            focus: focusStatus(input),
            capture: captureStatus(input),
            controllers: controllerStatus(input),
            surface: surface,
            render: renderStatus(input, surface: surface, failure: failure),
            hdr: hdrStatus(input),
            audio: audioStatus(input),
            failure: failure
        )
    }

    private static func focusStatus(
        _ input: TVStreamControlPresentationInput
    ) -> TVStreamLocalFocusPresentationStatus {
        guard input.hasActiveSession else { return .unavailable }
        if input.isRemoteReleasePending {
            return input.focusHandoff.isOverlayVisible
                ? .localControls
                : .handoffPending
        }
        if input.remoteCaptureDisposition == .captured {
            return .streamSurface
        }
        if input.focusHandoff.isOverlayVisible
            || !input.focusHandoff.isStreamNavigationSelected
            || !input.focusHandoff.isStreamWorkspaceVisible {
            return .localControls
        }
        return .handoffPending
    }

    private static func captureStatus(
        _ input: TVStreamControlPresentationInput
    ) -> TVStreamCapturePresentationStatus {
        guard input.hasActiveSession else { return .unavailable }
        if input.isRemoteReleasePending { return .releasePending }
        return input.remoteCaptureDisposition == .captured ? .remote : .local
    }

    private static func controllerStatus(
        _ input: TVStreamControlPresentationInput
    ) -> TVStreamControllerPresentationStatus {
        guard input.hasActiveSession,
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

    private static func surfaceStatus(
        _ input: TVStreamControlPresentationInput
    ) -> TVStreamSurfacePresentationStatus {
        guard input.hasActiveSession,
              let surface = input.sceneSurface,
              surface.platform == .tvOS else {
            return .unavailable
        }
        guard surface.attachment == .attached else { return .detached }
        guard surface.activity == .active else { return .inactive }
        return surface.isVisible ? .visible : .hidden
    }

    private static func renderStatus(
        _ input: TVStreamControlPresentationInput,
        surface: TVStreamSurfacePresentationStatus,
        failure: TVStreamFailurePresentationStatus
    ) -> TVStreamRenderPresentationStatus {
        guard input.hasActiveSession else { return .inactive }
        guard failure == .none else { return .failed }
        switch input.renderPolicy {
        case .paused:
            return .paused
        case .throttled:
            return .throttled
        case .idle, .active:
            break
        }
        guard surface == .visible else { return .waitingForSurface }
        guard let video = input.video else { return .waitingForDecoder }
        switch video.phase {
        case .idle:
            return .waitingForDecoder
        case .decoderReady:
            return .waitingForFrame
        case .frameReady:
            return video.isPresented ? .presenting : .waitingForFrame
        case .cleared:
            return .cleared
        }
    }

    private static func hdrStatus(
        _ input: TVStreamControlPresentationInput
    ) -> TVStreamHDRPresentationStatus {
        guard input.hasActiveSession else { return .inactive }
        if let fallback = input.hdrFallbackReason {
            return .sdrFallback(fallback)
        }
        switch input.hdrPresentation {
        case .inactive:
            return .inactive
        case .sdr:
            return .sdr
        case .edr:
            return .directEDR
        case .sdrFallback:
            return .sdrFallback(nil)
        case .updating:
            return .updating
        case .invalidInput, .unsupportedOutput:
            return .unavailable
        case .pipelineFailure:
            return .failed
        }
    }

    private static func audioStatus(
        _ input: TVStreamControlPresentationInput
    ) -> TVStreamAudioPresentationStatus {
        guard input.hasActiveSession else { return .inactive }
        switch input.spatialAudio.mode {
        case .recovering:
            return .recovering
        case .failed:
            return .failed
        case .inactive, .nonspatial, .fixedSpatial, .headTracked,
             .visionFixed, .visionHeadTracked:
            break
        }
        guard let route = input.audioRoute,
              route.platform == .tvOS,
              route.outputAvailable,
              (1...64).contains(route.currentOutputChannelCount) else {
            return .unavailable
        }
        switch input.spatialAudio.mode {
        case .fixedSpatial, .headTracked:
            return .spatial(
                channelCount: route.currentOutputChannelCount,
                mode: input.spatialAudio.mode
            )
        case .inactive, .nonspatial:
            return .standard(channelCount: route.currentOutputChannelCount)
        case .visionFixed, .visionHeadTracked, .recovering, .failed:
            return .unavailable
        }
    }

    private static func failureStatus(
        _ input: TVStreamControlPresentationInput
    ) -> TVStreamFailurePresentationStatus {
        if let presentationFailure = input.presentationFailure {
            return TVStreamFailurePresentationStatus(presentationFailure)
        }
        return input.hasSessionFailure ? .session : .none
    }
}

private extension TVStreamLocalFocusPresentationStatus {
    var content: TVStreamControlStatusContent {
        switch self {
        case .unavailable:
            return content("Unavailable", "No active stream owns focus.", "scope")
        case .localControls:
            return content("Local controls", "The focus engine owns remote navigation.", "rectangle.and.hand.point.up.left")
        case .streamSurface:
            return content("Stream surface", "The current stream surface owns focus.", "rectangle.inset.focus")
        case .handoffPending:
            return content("Handoff pending", "Waiting for current surface focus eligibility.", "arrow.left.arrow.right")
        }
    }

    private func content(
        _ value: String,
        _ detail: String,
        _ systemImage: String
    ) -> TVStreamControlStatusContent {
        TVStreamControlStatusContent(
            kind: .focus,
            title: "Focus",
            value: value,
            detail: detail,
            systemImage: systemImage,
            isFailure: false
        )
    }
}

private extension TVStreamCapturePresentationStatus {
    var content: TVStreamControlStatusContent {
        switch self {
        case .unavailable:
            return content("Unavailable", "Remote input capture is not active.", "dot.radiowaves.left.and.right")
        case .local:
            return content("Local", "Remote presses remain with tvOS.", "appletvremote.gen4")
        case .remote:
            return content("Remote", "Supported presses are routed to the current stream.", "arrow.up.forward.app")
        case .releasePending:
            return content("Releasing", "Held input is closing before local focus returns.", "hand.raised")
        }
    }

    private func content(
        _ value: String,
        _ detail: String,
        _ systemImage: String
    ) -> TVStreamControlStatusContent {
        TVStreamControlStatusContent(
            kind: .capture,
            title: "Capture",
            value: value,
            detail: detail,
            systemImage: systemImage,
            isFailure: false
        )
    }
}

private extension TVStreamControllerPresentationStatus {
    var content: TVStreamControlStatusContent {
        switch self {
        case .unavailable:
            return TVStreamControlStatusContent(
                kind: .controllers,
                title: "Controllers",
                value: "Unavailable",
                detail: "No current controller roster is owned by the stream.",
                systemImage: "gamecontroller",
                isFailure: false
            )
        case let .active(connected, routed):
            let value = connected == routed
                ? "\(connected) connected"
                : "\(connected) connected, \(routed) routed"
            return TVStreamControlStatusContent(
                kind: .controllers,
                title: "Controllers",
                value: value,
                detail: routed == connected
                    ? "All current controllers are routed."
                    : "Only current-generation controllers are routed.",
                systemImage: "gamecontroller.fill",
                isFailure: false
            )
        }
    }
}

private extension TVStreamSurfacePresentationStatus {
    var content: TVStreamControlStatusContent {
        let value: String
        let detail: String
        let image: String
        switch self {
        case .unavailable:
            (value, detail, image) = ("Unavailable", "Waiting for the current stream surface.", "rectangle.slash")
        case .detached:
            (value, detail, image) = ("Detached", "The stream surface is not attached.", "rectangle.slash")
        case .inactive:
            (value, detail, image) = ("Inactive", "The current scene is not active.", "pause.rectangle")
        case .hidden:
            (value, detail, image) = ("Hidden", "The current surface is not visible.", "eye.slash")
        case .visible:
            (value, detail, image) = ("Visible", "The current scene and surface are visible.", "rectangle.on.rectangle")
        }
        return TVStreamControlStatusContent(
            kind: .surface,
            title: "Surface",
            value: value,
            detail: detail,
            systemImage: image,
            isFailure: false
        )
    }
}

private extension TVStreamRenderPresentationStatus {
    var content: TVStreamControlStatusContent {
        let value: String
        let detail: String
        let image: String
        switch self {
        case .inactive:
            (value, detail, image) = ("Inactive", "No active video presentation.", "play.slash")
        case .waitingForSurface:
            (value, detail, image) = ("Waiting for surface", "Rendering resumes on an eligible visible surface.", "rectangle.dashed")
        case .waitingForDecoder:
            (value, detail, image) = ("Waiting for decoder", "No current decoder owns video output.", "hourglass")
        case .waitingForFrame:
            (value, detail, image) = ("Waiting for frame", "The current decoder has not presented a frame.", "film.stack")
        case .presenting:
            (value, detail, image) = ("Presenting", "A current decoded frame is on the Metal surface.", "play.rectangle.fill")
        case .cleared:
            (value, detail, image) = ("Cleared", "The current presentation has cleared its frame.", "rectangle.fill")
        case .throttled:
            (value, detail, image) = ("Throttled", "Rendering is reduced by the current lifecycle policy.", "gauge.with.dots.needle.33percent")
        case .paused:
            (value, detail, image) = ("Paused", "Rendering is paused by the current lifecycle policy.", "pause.rectangle.fill")
        case .failed:
            (value, detail, image) = ("Stopped", "The current platform presentation failed.", "xmark.rectangle")
        }
        return TVStreamControlStatusContent(
            kind: .render,
            title: "Render",
            value: value,
            detail: detail,
            systemImage: image,
            isFailure: self == .failed
        )
    }
}

private extension TVStreamHDRPresentationStatus {
    var content: TVStreamControlStatusContent {
        let value: String
        let detail: String
        let image: String
        let failure: Bool
        switch self {
        case .inactive:
            (value, detail, image, failure) = ("Inactive", "No active HDR presentation.", "sun.min", false)
        case .sdr:
            (value, detail, image, failure) = ("SDR", "Current video is using standard dynamic range.", "sun.min.fill", false)
        case .directEDR:
            (value, detail, image, failure) = ("HDR / EDR", "Current video is using direct extended-range output.", "sun.max.fill", false)
        case let .sdrFallback(reason):
            (value, detail, image, failure) = ("SDR fallback", reason?.detail ?? "Current HDR video is mapped to standard dynamic range.", "exclamationmark.triangle", false)
        case .updating:
            (value, detail, image, failure) = ("Updating", "Waiting for video that matches the current output.", "arrow.triangle.2.circlepath", false)
        case .unavailable:
            (value, detail, image, failure) = ("Unavailable", "The current video or output cannot present HDR.", "sun.max.trianglebadge.exclamationmark", true)
        case .failed:
            (value, detail, image, failure) = ("Stopped", "The current HDR pipeline could not continue.", "xmark.octagon", true)
        }
        return TVStreamControlStatusContent(
            kind: .hdr,
            title: "HDR",
            value: value,
            detail: detail,
            systemImage: image,
            isFailure: failure
        )
    }
}

private extension TVOSDisplayHDRFallbackReason {
    var detail: String {
        switch self {
        case .outputUnavailable:
            "The current television output is unavailable."
        case .preferredDynamicRangeUnavailable:
            "The current surface cannot request direct HDR output."
        case .toneMapControlUnavailable:
            "The current surface has no direct tone-map control."
        case .contentsHeadroomUnavailable:
            "The current surface cannot apply content headroom."
        case .extendedColorSpaceUnavailable:
            "The current surface has no supported extended color space."
        case .headroomUnavailable:
            "Current display headroom is unavailable."
        case .invalidHeadroom:
            "Current display headroom is invalid."
        case .insufficientHeadroom:
            "Current display headroom requires standard dynamic range."
        }
    }
}

private extension TVStreamAudioPresentationStatus {
    var content: TVStreamControlStatusContent {
        let value: String
        let detail: String
        let image: String
        let failure: Bool
        switch self {
        case .inactive:
            (value, detail, image, failure) = ("Inactive", "No active audio presentation.", "speaker.slash", false)
        case .unavailable:
            (value, detail, image, failure) = ("Unavailable", "No current audio output route is available.", "speaker.slash", false)
        case let .standard(channelCount):
            (value, detail, image, failure) = ("\(channelCount) ch standard", "Current audio uses the active standard output route.", "speaker.wave.2", false)
        case let .spatial(channelCount, mode):
            let modeLabel = mode == .headTracked ? "head tracked" : "fixed spatial"
            (value, detail, image, failure) = ("\(channelCount) ch \(modeLabel)", "Current audio uses the active spatial output route.", mode == .headTracked ? "person.wave.2" : "wave.3.right.circle", false)
        case .recovering:
            (value, detail, image, failure) = ("Recovering", "Waiting for the current audio graph to resume.", "arrow.triangle.2.circlepath", false)
        case .failed:
            (value, detail, image, failure) = ("Stopped", "The current audio graph could not continue.", "xmark.octagon", true)
        }
        return TVStreamControlStatusContent(
            kind: .audio,
            title: "Audio",
            value: value,
            detail: detail,
            systemImage: image,
            isFailure: failure
        )
    }
}

private extension TVStreamFailurePresentationStatus {
    var content: TVStreamControlStatusContent {
        let value: String
        let detail: String
        switch self {
        case .none:
            (value, detail) = ("None", "No current bounded platform failure.")
        case .session:
            (value, detail) = ("Session stopped", "The current stream session failed.")
        case let .invalidComponent(component):
            (value, detail) = ("Invalid \(component.label)", "The current platform component was rejected.")
        case let .actionFailed(effect):
            (value, detail) = ("\(effect.label) failed", "The current platform action could not complete.")
        case .semanticRevisionExhausted:
            (value, detail) = ("Revision exhausted", "Platform state updates stopped at a bounded revision limit.")
        case .sequenceExhausted:
            (value, detail) = ("Sequence exhausted", "Platform actions stopped at a bounded sequence limit.")
        }
        return TVStreamControlStatusContent(
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
    var label: String {
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
    var label: String {
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
