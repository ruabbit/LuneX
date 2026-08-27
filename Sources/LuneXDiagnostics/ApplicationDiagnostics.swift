import Foundation

enum ApplicationDiagnosticCategory: String, CaseIterable, Hashable, Sendable {
    case pairing
    case transport
    case decoder
    case hdr
    case audio
    case input
    case application

    var label: String {
        switch self {
        case .pairing: "Pairing"
        case .transport: "Transport"
        case .decoder: "Video"
        case .hdr: "HDR"
        case .audio: "Audio"
        case .input: "Input"
        case .application: "Application"
        }
    }

    var systemImage: String {
        switch self {
        case .pairing: "link.badge.plus"
        case .transport: "network"
        case .decoder: "film.stack"
        case .hdr: "sun.max.fill"
        case .audio: "speaker.wave.2"
        case .input: "cursorarrow.motionlines"
        case .application: "app.badge.checkmark"
        }
    }

    static func infer(from subsystem: String) -> ApplicationDiagnosticCategory {
        let normalized = subsystem.lowercased()
        if normalized.contains("pair") || normalized.contains("identity") { return .pairing }
        if normalized.contains("hdr") || normalized.contains("edr") { return .hdr }
        if normalized.contains("video") || normalized.contains("decoder") { return .decoder }
        if normalized.contains("audio") { return .audio }
        if normalized.contains("input") || normalized.contains("controller") { return .input }
        if normalized.contains("stream") || normalized.contains("control") ||
            normalized.contains("network") || normalized.contains("rtsp") {
            return .transport
        }
        return .application
    }
}

enum ApplicationDiagnosticAction: String, Hashable, Sendable {
    case verifyPIN
    case pairAgain
    case checkHost
    case retryStream
    case reviewStreamSettings
    case reviewHDRSettings
    case checkAudioOutput
    case reconnectInput
    case useSupportedController
    case updateBuild

    var label: String {
        switch self {
        case .verifyPIN:
            "Check the four-digit PIN and retry pairing."
        case .pairAgain:
            "Remove the saved pairing and pair this host again."
        case .checkHost:
            "Confirm Sunshine is running and reachable, then retry."
        case .retryStream:
            "Reconnect the stream. If it fails again, review Diagnostics."
        case .reviewStreamSettings:
            "Lower the codec, resolution, frame rate, or bitrate, then retry."
        case .reviewHDRSettings:
            "Review HDR settings and the current display, then retry."
        case .checkAudioOutput:
            "Check the selected audio output, then reconnect the stream."
        case .reconnectInput:
            "Refocus or reconnect the stream to restore remote input."
        case .useSupportedController:
            "Use a connected controller that supports the requested feedback."
        case .updateBuild:
            "Install a build that includes every required streaming provider."
        }
    }
}

enum AudioProcessingFailureCause: String, Equatable, Hashable, Sendable {
    case decoderInvalidConfiguration = "audio_decoder_invalid_configuration"
    case decoderInvalidPayload = "audio_decoder_invalid_payload"
    case decoderSetupFailed = "audio_decoder_setup_failed"
    case decoderDecodeFailed = "audio_decoder_decode_failed"
    case decoderInconsistentPCM = "audio_decoder_inconsistent_pcm"
    case decoderClosed = "audio_decoder_closed"
    case jitterInvalidPolicy = "audio_jitter_invalid_policy"
    case jitterInvalidPayload = "audio_jitter_invalid_payload"
    case jitterNonMonotonicClock = "audio_jitter_non_monotonic_clock"
    case jitterSequenceGap = "audio_jitter_sequence_gap"
    case jitterFinished = "audio_jitter_finished"
    case pipelineConfiguration = "audio_pipeline_configuration_failed"
    case pipelineNotRunning = "audio_pipeline_not_running"
    case pipelineInvalidPCM = "audio_pipeline_invalid_pcm"
    case pipelineScheduleCapacity = "audio_pipeline_schedule_capacity"
    case runtimeInvalidPolicy = "audio_runtime_invalid_policy"
    case runtimeInvalidState = "audio_runtime_invalid_state"
    case runtimeStopped = "audio_runtime_stopped"
    case runtimeClock = "audio_runtime_clock_failed"
    case runtimeSpatialPolicy = "audio_runtime_spatial_policy_failed"
    case runtimeGraph = "audio_runtime_graph_failed"
    case runtimeArithmetic = "audio_runtime_arithmetic_failed"

    static func classify(_ error: Error) -> Self? {
        if let error = error as? OpusDecoderError {
            switch error {
            case .invalidConfiguration: return .decoderInvalidConfiguration
            case .invalidPacketPayload: return .decoderInvalidPayload
            case .converterCreationFailed, .magicCookieRejected:
                return .decoderSetupFailed
            case .decodeFailed: return .decoderDecodeFailed
            case .inconsistentPCMOutput: return .decoderInconsistentPCM
            case .closed: return .decoderClosed
            }
        }
        if let error = error as? AudioJitterBufferError {
            switch error {
            case .invalidPolicy: return .jitterInvalidPolicy
            case .invalidPacketPayload: return .jitterInvalidPayload
            case .nonMonotonicClock: return .jitterNonMonotonicClock
            case .sequenceGapTooLarge: return .jitterSequenceGap
            case .finished: return .jitterFinished
            }
        }
        if let error = error as? AudioPipelineError {
            switch error {
            case .missingConfiguration, .invalidConfiguration, .invalidGraphIntent,
                 .invalidSpatialRuntimeSnapshot:
                return .pipelineConfiguration
            case .notRunning: return .pipelineNotRunning
            case .invalidPCMBuffer: return .pipelineInvalidPCM
            case .scheduleCapacityExceeded: return .pipelineScheduleCapacity
            }
        }
        if let error = error as? AudioRuntimeRecoveryError {
            switch error {
            case .invalidPolicy: return .runtimeInvalidPolicy
            case .invalidState: return .runtimeInvalidState
            case .stopped: return .runtimeStopped
            case .nonMonotonicEventTime: return .runtimeClock
            case .invalidGraphIntent, .staleSpatialPolicyRevision,
                 .conflictingSpatialPolicyRevision:
                return .runtimeSpatialPolicy
            case .graphFailed: return .runtimeGraph
            case .arithmeticOverflow: return .runtimeArithmetic
            }
        }
        return nil
    }
}

struct ApplicationDiagnostic: Hashable, Sendable {
    var category: ApplicationDiagnosticCategory
    var severity: RuntimeDiagnosticSeverity
    var code: String
    var summary: String
    var action: ApplicationDiagnosticAction?

    var subsystem: String {
        switch category {
        case .pairing: "pairing"
        case .transport: "stream.transport"
        case .decoder: "stream.video"
        case .hdr: "stream.hdr"
        case .audio: "stream.audio"
        case .input: "stream.input"
        case .application: "app"
        }
    }
}

enum MacLifecycleDiagnosticState: Hashable, Sendable {
    case inactive
    case active
    case occluded
    case unfocused
    case drawableUnavailable
}

enum MacInputDiagnosticState: Hashable, Sendable {
    case unavailable
    case closed
    case directReady
    case relativeReady
}

enum MobileSceneDiagnosticState: Hashable, Sendable {
    case detached
    case active
    case inactive
    case background
    case resizing
    case settled
    case invalidGeometry
}

enum MobileDisplayDiagnosticState: Hashable, Sendable {
    case detached
    case sdr
    case edr
    case fallback
    case unavailable
}

enum MobilePictureInPictureDiagnosticState: Hashable, Sendable {
    case preparing
    case possible
    case unavailable
    case starting
    case active
    case stopping
    case stopped
    case failed
    case invalidated
}

enum MobileContinuityDiagnosticState: Hashable, Sendable {
    case foreground
    case pictureInPicture
    case audioOnly
    case suspended
    case stopped
    case stale
    case applicationFailed
    case revisionExhausted
}

enum SpatialAudioDiagnosticFallback: CaseIterable, Hashable, Sendable {
    case userDisabled
    case outputUnavailable
    case invalidRoute
    case staleRevision
    case renderingAlgorithmUnavailable
    case incompatiblePlatformStrategy
    case headTrackingNotApplied
    case visionExperienceNotApplied
}

enum SpatialAudioDiagnosticState: Hashable, Sendable {
    case inactive
    case activeNonspatial
    case fixedSpatial
    case headTracked
    case visionFixed
    case visionHeadTracked
    case fallback(SpatialAudioDiagnosticFallback)
    case missingEntitlement
    case unreadableEntitlement
    case unsupportedRoute
    case unsupportedLayout
    case recovery
    case graphFailure

    var clearsCurrentAudioAction: Bool {
        switch self {
        case .activeNonspatial, .fixedSpatial, .headTracked,
             .visionFixed, .visionHeadTracked, .fallback(.userDisabled):
            true
        case .inactive, .fallback, .missingEntitlement, .unreadableEntitlement,
             .unsupportedRoute, .unsupportedLayout, .recovery, .graphFailure:
            false
        }
    }

    init(runtime: SessionAudioRuntimeEvent) {
        if runtime.stage == .idle || runtime.stage == .stopped {
            self = .inactive
            return
        }
        if runtime.stage == .failed || runtime.cause == .failed {
            self = runtime.spatialRuntime?.fallbackReason == .graphUnavailable
                ? .graphFailure
                : .inactive
            return
        }
        if runtime.stage == .interrupted
            || runtime.cause == .interruptionBegan
            || runtime.cause == .mediaServicesLost {
            self = .recovery
            return
        }
        guard let spatial = runtime.spatialRuntime else {
            self = .activeNonspatial
            return
        }
        if let fallback = spatial.fallbackReason {
            switch fallback {
            case .graphUnavailable:
                self = .graphFailure
            case .missingEntitlement:
                self = .missingEntitlement
            case .unreadableEntitlement:
                self = .unreadableEntitlement
            case .routeUnsupported:
                self = .unsupportedRoute
            case .unsupportedLayout, .layoutMismatch:
                self = .unsupportedLayout
            case .userDisabled:
                self = .fallback(.userDisabled)
            case .outputUnavailable:
                self = .fallback(.outputUnavailable)
            case .invalidRouteSnapshot:
                self = .fallback(.invalidRoute)
            case .staleRevision:
                self = .fallback(.staleRevision)
            case .renderingAlgorithmUnavailable:
                self = .fallback(.renderingAlgorithmUnavailable)
            case .incompatiblePlatformStrategy:
                self = .fallback(.incompatiblePlatformStrategy)
            case .headTrackingNotApplied:
                self = .fallback(.headTrackingNotApplied)
            case .visionExperienceNotApplied:
                self = .fallback(.visionExperienceNotApplied)
            }
            return
        }

        switch spatial.presentationMode {
        case .inactive:
            self = .inactive
        case .nonspatial:
            self = .activeNonspatial
        case .fixedSpatial:
            self = spatial.platformStrategy == .visionOutputExperience
                ? .visionFixed
                : .fixedSpatial
        case .headTracked:
            self = spatial.platformStrategy == .visionOutputExperience
                ? .visionHeadTracked
                : .headTracked
        }
    }
}

enum ApplicationDiagnosticFactory {
    static let pairingUnavailable = ApplicationDiagnostic(
        category: .pairing,
        severity: .error,
        code: "pairing_provider_unavailable",
        summary: "Authenticated pairing is unavailable in this build.",
        action: .updateBuild
    )

    static let pairingIdentityUnavailable = ApplicationDiagnostic(
        category: .pairing,
        severity: .error,
        code: "pairing_identity_unavailable",
        summary: "The client identity could not be prepared for pairing.",
        action: .pairAgain
    )

    static let streamUnavailable = ApplicationDiagnostic(
        category: .transport,
        severity: .error,
        code: "stream_provider_unavailable",
        summary: "Streaming is unavailable because a required provider is missing.",
        action: .updateBuild
    )

    static func macLifecycleState(
        _ state: MacLifecycleDiagnosticState
    ) -> ApplicationDiagnostic {
        let code: String
        let summary: String
        switch state {
        case .inactive:
            code = "mac_lifecycle_inactive"
            summary = "The macOS stream lifecycle is inactive."
        case .active:
            code = "mac_lifecycle_active"
            summary = "The macOS stream surface is visible and active."
        case .occluded:
            code = "mac_lifecycle_occluded"
            summary = "The macOS stream surface is hidden; video presentation is paused."
        case .unfocused:
            code = "mac_lifecycle_unfocused"
            summary = "The macOS stream surface is unfocused; remote input is suspended."
        case .drawableUnavailable:
            code = "mac_lifecycle_drawable_unavailable"
            summary = "The macOS stream drawable is unavailable; video presentation is paused."
        }
        return ApplicationDiagnostic(
            category: .application,
            severity: .info,
            code: code,
            summary: summary,
            action: nil
        )
    }

    static func macInputState(
        _ state: MacInputDiagnosticState
    ) -> ApplicationDiagnostic {
        let code: String
        let summary: String
        switch state {
        case .unavailable:
            code = "mac_input_unavailable"
            summary = "Remote input is not active for the macOS stream."
        case .closed:
            code = "mac_input_closed"
            summary = "Remote input capture is suspended by the macOS lifecycle."
        case .directReady:
            code = "mac_input_direct_ready"
            summary = "Direct pointer input is ready for the macOS stream."
        case .relativeReady:
            code = "mac_input_relative_ready"
            summary = "Relative pointer input is ready for the macOS stream."
        }
        return ApplicationDiagnostic(
            category: .input,
            severity: .info,
            code: code,
            summary: summary,
            action: nil
        )
    }

    static func mobileSceneState(
        _ state: MobileSceneDiagnosticState
    ) -> ApplicationDiagnostic {
        let code: String
        let summary: String
        switch state {
        case .detached:
            code = "mobile_scene_detached"
            summary = "The mobile stream surface is detached."
        case .active:
            code = "mobile_scene_active"
            summary = "The mobile stream scene is active."
        case .inactive:
            code = "mobile_scene_inactive"
            summary = "The mobile stream scene is inactive."
        case .background:
            code = "mobile_scene_background"
            summary = "The mobile stream scene is in the background."
        case .resizing:
            code = "mobile_scene_resizing"
            summary = "The mobile stream window is resizing."
        case .settled:
            code = "mobile_scene_settled"
            summary = "The mobile stream window geometry is settled."
        case .invalidGeometry:
            code = "mobile_scene_invalid_geometry"
            summary = "The mobile stream window geometry is invalid."
        }
        return ApplicationDiagnostic(
            category: .application,
            severity: state == .invalidGeometry ? .warning : .info,
            code: code,
            summary: summary,
            action: nil
        )
    }

    static func mobileDisplayState(
        _ state: MobileDisplayDiagnosticState
    ) -> ApplicationDiagnostic {
        let code: String
        let summary: String
        switch state {
        case .detached:
            code = "mobile_edr_detached"
            summary = "The mobile stream display is detached."
        case .sdr:
            code = "mobile_edr_sdr"
            summary = "The mobile stream display is using the SDR path."
        case .edr:
            code = "mobile_edr_active"
            summary = "The mobile stream display is using the EDR path."
        case .fallback:
            code = "mobile_edr_fallback"
            summary = "The mobile stream display is using conservative SDR fallback."
        case .unavailable:
            code = "mobile_edr_unavailable"
            summary = "Mobile display EDR state is unavailable."
        }
        return ApplicationDiagnostic(
            category: .hdr,
            severity: state == .fallback || state == .unavailable
                ? .warning
                : .info,
            code: code,
            summary: summary,
            action: nil
        )
    }

    static func mobilePictureInPictureState(
        _ state: MobilePictureInPictureDiagnosticState
    ) -> ApplicationDiagnostic {
        let code: String
        let summary: String
        switch state {
        case .preparing:
            code = "mobile_pip_preparing"
            summary = "Picture in Picture is preparing."
        case .possible:
            code = "mobile_pip_possible"
            summary = "Picture in Picture is available."
        case .unavailable:
            code = "mobile_pip_unavailable"
            summary = "Picture in Picture is unavailable."
        case .starting:
            code = "mobile_pip_starting"
            summary = "Picture in Picture is starting."
        case .active:
            code = "mobile_pip_active"
            summary = "Picture in Picture is active."
        case .stopping:
            code = "mobile_pip_stopping"
            summary = "Picture in Picture is stopping."
        case .stopped:
            code = "mobile_pip_stopped"
            summary = "Picture in Picture is stopped."
        case .failed:
            code = "mobile_pip_failed"
            summary = "Picture in Picture failed."
        case .invalidated:
            code = "mobile_pip_invalidated"
            summary = "Picture in Picture was invalidated."
        }
        return ApplicationDiagnostic(
            category: .decoder,
            severity: state == .failed ? .warning : .info,
            code: code,
            summary: summary,
            action: nil
        )
    }

    static func mobileContinuityState(
        _ state: MobileContinuityDiagnosticState
    ) -> ApplicationDiagnostic {
        let code: String
        let summary: String
        switch state {
        case .foreground:
            code = "mobile_continuity_foreground"
            summary = "Mobile media is using foreground presentation."
        case .pictureInPicture:
            code = "mobile_continuity_pip"
            summary = "Mobile media is continuing through Picture in Picture."
        case .audioOnly:
            code = "mobile_continuity_audio_only"
            summary = "Mobile media is continuing through active audio only."
        case .suspended:
            code = "mobile_continuity_suspended"
            summary = "Mobile video decoding is suspended because no permitted background media path is active."
        case .stopped:
            code = "mobile_continuity_stopped"
            summary = "The mobile media runtime is stopped."
        case .stale:
            code = "mobile_continuity_stale"
            summary = "A stale mobile media runtime update was rejected."
        case .applicationFailed:
            code = "mobile_continuity_application_failed"
            summary = "The mobile media runtime could not apply its current policy."
        case .revisionExhausted:
            code = "mobile_continuity_revision_exhausted"
            summary = "The mobile media runtime revision was exhausted and the stream is stopping."
        }
        return ApplicationDiagnostic(
            category: .application,
            severity: state == .stale || state == .applicationFailed
                || state == .revisionExhausted
                ? .warning
                : .info,
            code: code,
            summary: summary,
            action: nil
        )
    }

    static func spatialAudioState(
        _ state: SpatialAudioDiagnosticState
    ) -> ApplicationDiagnostic {
        let severity: RuntimeDiagnosticSeverity
        let code: String
        let summary: String
        let action: ApplicationDiagnosticAction?

        switch state {
        case .inactive:
            severity = .info
            code = "spatial_audio_inactive"
            summary = "Spatial audio is inactive."
            action = nil
        case .activeNonspatial:
            severity = .info
            code = "spatial_audio_active_nonspatial"
            summary = "Audio is active on the nonspatial playback path."
            action = nil
        case .fixedSpatial:
            severity = .info
            code = "spatial_audio_active_fixed"
            summary = "Spatial audio is active in fixed mode."
            action = nil
        case .headTracked:
            severity = .info
            code = "spatial_audio_active_head_tracked"
            summary = "Spatial audio and listener head tracking are active."
            action = nil
        case .visionFixed:
            severity = .info
            code = "spatial_audio_active_vision_fixed"
            summary = "visionOS spatial audio is active in fixed mode."
            action = nil
        case .visionHeadTracked:
            severity = .info
            code = "spatial_audio_active_vision_head_tracked"
            summary = "visionOS spatial audio is active with head tracking."
            action = nil
        case let .fallback(fallback):
            switch fallback {
            case .userDisabled:
                severity = .info
                code = "spatial_audio_fallback_user_disabled"
                summary = "Spatial audio is using the nonspatial path because it is disabled."
                action = nil
            case .outputUnavailable:
                severity = .warning
                code = "spatial_audio_fallback_output_unavailable"
                summary = "Spatial audio is unavailable because there is no active audio output."
                action = .checkAudioOutput
            case .invalidRoute:
                severity = .warning
                code = "spatial_audio_fallback_invalid_route"
                summary = "Spatial audio is unavailable because the current output state is invalid."
                action = .checkAudioOutput
            case .staleRevision:
                severity = .warning
                code = "spatial_audio_fallback_stale_revision"
                summary = "A stale spatial audio revision was rejected."
                action = .retryStream
            case .renderingAlgorithmUnavailable:
                severity = .warning
                code = "spatial_audio_fallback_rendering_unavailable"
                summary = "Spatial audio is using the nonspatial path because native rendering is unavailable."
                action = .checkAudioOutput
            case .incompatiblePlatformStrategy:
                severity = .error
                code = "spatial_audio_fallback_platform_strategy"
                summary = "Spatial audio could not apply the required platform playback strategy."
                action = .retryStream
            case .headTrackingNotApplied:
                severity = .warning
                code = "spatial_audio_fallback_head_tracking_not_applied"
                summary = "Spatial audio remains fixed because listener head tracking was not applied."
                action = .checkAudioOutput
            case .visionExperienceNotApplied:
                severity = .warning
                code = "spatial_audio_fallback_vision_experience_not_applied"
                summary = "visionOS spatial audio could not apply the requested experience."
                action = .retryStream
            }
        case .missingEntitlement:
            severity = .warning
            code = "spatial_audio_missing_entitlement"
            summary = "Spatial audio remains fixed because listener head tracking is not authorized."
            action = .updateBuild
        case .unreadableEntitlement:
            severity = .warning
            code = "spatial_audio_unreadable_entitlement"
            summary = "Spatial audio remains fixed because listener head-tracking authorization could not be read."
            action = .updateBuild
        case .unsupportedRoute:
            severity = .warning
            code = "spatial_audio_unsupported_route"
            summary = "Spatial audio is using the nonspatial path on the current output."
            action = .checkAudioOutput
        case .unsupportedLayout:
            severity = .warning
            code = "spatial_audio_unsupported_layout"
            summary = "Spatial audio is unavailable for the negotiated channel layout."
            action = .reviewStreamSettings
        case .recovery:
            severity = .info
            code = "spatial_audio_recovery"
            summary = "Spatial audio playback is paused while native audio recovers."
            action = nil
        case .graphFailure:
            severity = .error
            code = "spatial_audio_graph_failure"
            summary = "The native spatial audio graph failed."
            action = .checkAudioOutput
        }

        return ApplicationDiagnostic(
            category: .audio,
            severity: severity,
            code: code,
            summary: summary,
            action: action
        )
    }

    static func hdrPresentationState(
        _ state: HDRPresentationDiagnosticState
    ) -> ApplicationDiagnostic? {
        let severity: RuntimeDiagnosticSeverity
        let code: String
        let summary: String
        let action: ApplicationDiagnosticAction?

        switch state {
        case .inactive:
            return nil
        case .activeSDR:
            severity = .info
            code = "hdr_active_sdr"
            summary = "The stream is using the standard dynamic range presentation path."
            action = nil
        case .activeEDR:
            severity = .info
            code = "hdr_active_edr"
            summary = "The stream is using the extended dynamic range presentation path."
            action = nil
        case let .sdrFallback(reason):
            severity = .warning
            action = .reviewHDRSettings
            switch reason {
            case .userPreferenceDisabled:
                code = "hdr_sdr_fallback_user_disabled"
                summary = "HDR content is using SDR tone mapping because HDR is disabled."
            case .platformOutputUnsupported:
                code = "hdr_sdr_fallback_unsupported_output"
                summary = "HDR content is using SDR tone mapping because EDR output is unsupported."
            case .currentHeadroomUnavailable:
                code = "hdr_sdr_fallback_headroom_unavailable"
                summary = "HDR content is using SDR tone mapping because display headroom is unavailable."
            case .currentHeadroomInvalid:
                code = "hdr_sdr_fallback_headroom_invalid"
                summary = "HDR content is using SDR tone mapping because display headroom is invalid."
            case .currentHeadroomInsufficient:
                code = "hdr_sdr_fallback_headroom_insufficient"
                summary = "HDR content is using SDR tone mapping because current headroom is insufficient."
            }
        case .invalidInput:
            severity = .error
            code = "hdr_invalid_input"
            summary = "The decoded video does not match the negotiated HDR color contract."
            action = .reviewStreamSettings
        case .unsupportedOutput:
            severity = .error
            code = "hdr_unsupported_output"
            summary = "The requested HDR output cannot be applied on the current presentation path."
            action = .reviewHDRSettings
        case .staleRevision:
            severity = .warning
            code = "hdr_stale_revision"
            summary = "A stale HDR render revision was rejected."
            action = .retryStream
        case .pipelineFailure:
            severity = .error
            code = "hdr_pipeline_failure"
            summary = "The HDR presentation pipeline failed and stopped the current output."
            action = .retryStream
        }

        return ApplicationDiagnostic(
            category: .hdr,
            severity: severity,
            code: code,
            summary: summary,
            action: action
        )
    }

    static func pairingFailure(_ error: Error) -> ApplicationDiagnostic {
        if let failure = error as? PairingFailure {
            switch failure.code {
            case .invalidPIN, .serverRejected:
                return ApplicationDiagnostic(
                    category: .pairing,
                    severity: .error,
                    code: failure.code.rawValue,
                    summary: "The host rejected the pairing request.",
                    action: .verifyPIN
                )
            case .certificateMismatch:
                return ApplicationDiagnostic(
                    category: .pairing,
                    severity: .error,
                    code: failure.code.rawValue,
                    summary: "The host identity did not match the pairing exchange.",
                    action: .pairAgain
                )
            case .missingClientIdentity:
                return pairingIdentityUnavailable
            case .missingHostAddress, .transportFailed:
                return ApplicationDiagnostic(
                    category: .pairing,
                    severity: .error,
                    code: failure.code.rawValue,
                    summary: "The host could not be reached for pairing.",
                    action: .checkHost
                )
            case .invalidTransition:
                return genericPairingFailure(code: failure.code.rawValue)
            case .cancelled:
                return ApplicationDiagnostic(
                    category: .pairing,
                    severity: .info,
                    code: failure.code.rawValue,
                    summary: "Pairing was cancelled.",
                    action: nil
                )
            }
        }
        if error is PairingTransportError {
            return ApplicationDiagnostic(
                category: .pairing,
                severity: .error,
                code: "pairing_transport_failed",
                summary: "The authenticated pairing exchange could not be completed.",
                action: .checkHost
            )
        }
        if error is PairingCryptoError {
            return ApplicationDiagnostic(
                category: .pairing,
                severity: .error,
                code: "pairing_verification_failed",
                summary: "The authenticated pairing response could not be verified.",
                action: .pairAgain
            )
        }
        return genericPairingFailure(code: "pairing_failed")
    }

    static func streamFailure(_ error: Error) -> ApplicationDiagnostic {
        if let failure = error as? StreamNegotiationFailure {
            switch failure.code {
            case .hostNotPaired:
                return ApplicationDiagnostic(
                    category: .pairing,
                    severity: .error,
                    code: failure.code.rawValue,
                    summary: "The host is not paired for this client identity.",
                    action: .pairAgain
                )
            case .invalidResolution, .invalidBitrate:
                return ApplicationDiagnostic(
                    category: .transport,
                    severity: .error,
                    code: failure.code.rawValue,
                    summary: "The requested stream settings are not valid.",
                    action: .reviewStreamSettings
                )
            case .missingHostAddress, .launchRejected, .resumeRejected,
                 .cancelRejected, .reconnectExhausted, .transportUnavailable:
                return transportFailure(code: failure.code.rawValue)
            case .invalidInputKey, .reconnectKeyGenerationFailed:
                return inputFailure(code: failure.code.rawValue)
            case .invalidTransition:
                return transportFailure(code: failure.code.rawValue)
            }
        }
        if let failure = error as? SessionMediaEnvironmentError {
            switch failure {
            case .missingProvider:
                return streamUnavailable
            case let .streamEnded(channel):
                if channel == .video { return decoderFailure(code: "video_stream_ended") }
                if channel == .audio { return audioFailure(code: "audio_stream_ended") }
                if channel == .input { return inputFailure(code: "input_stream_ended") }
                return transportFailure(code: "media_stream_ended")
            case .sessionAlreadyActive, .inactiveSession, .configurationMismatch:
                return transportFailure(code: "media_session_state_invalid")
            case .staleLifecycleApplication:
                return transportFailure(code: "media_lifecycle_stale")
            case .inputUnavailable:
                return inputFailure(code: "application_input_unavailable")
            case .staleInputApplication:
                return inputFailure(code: "application_input_stale")
            case .staleAudioApplication:
                return audioFailure(code: "application_audio_stale")
            case .staleMobileRuntimeApplication:
                return transportFailure(code: "mobile_runtime_stale")
            case .invalidMobileRuntimeApplication:
                return transportFailure(code: "mobile_runtime_invalid")
            case .staleTVVisionPlatformPresentationApplication:
                return transportFailure(code: "platform_presentation_stale")
            case .invalidTVVisionPlatformPresentationApplication:
                return transportFailure(code: "platform_presentation_invalid")
            }
        }
        if error is VideoDecoderError || error is VideoDecodePipelineError ||
            error is VideoFormatDescriptionError || error is VideoColorMetadataError ||
            error is MoonlightVideoPacketError || error is VideoAccessUnitAssemblyError ||
            error is MetalFrameDeliveryError {
            return decoderFailure(code: "video_pipeline_failed")
        }
        if let cause = AudioProcessingFailureCause.classify(error) {
            return audioFailure(code: cause.rawValue)
        }
        if let error = error as? MoonlightAudioPacketDecryptError {
            let code: String
            switch error {
            case .invalidKeyMaterial:
                code = "audio_packet_invalid_key"
            case .invalidCiphertext:
                code = "audio_packet_invalid_ciphertext"
            case .decryptionFailed:
                code = "audio_packet_decryption_failed"
            }
            return audioFailure(code: code)
        }
        if error is RemoteInputRuntimeError || error is RemoteInputCodecError {
            return inputFailure(code: "input_delivery_failed")
        }
        if error is NetworkChannelError || error is ControlChannelError ||
            error is RTSPBootstrapError || error is SunshineRTSPNegotiationError ||
            error is RTSPMessageError {
            return transportFailure(code: "transport_failed")
        }
        return transportFailure(code: "session_failed")
    }

    static func remoteFeedback(
        _ diagnostic: RemoteInputFeedbackDiagnostic
    ) -> ApplicationDiagnostic {
        let summary: String
        switch diagnostic.reason {
        case .controllerUnavailable:
            summary = "The target controller is no longer available for remote feedback."
        case .unsupportedCapability:
            summary = "The controller does not support the requested remote feedback."
        }
        return ApplicationDiagnostic(
            category: .input,
            severity: .warning,
            code: "controller_\(diagnostic.command.rawValue)_\(diagnostic.reason.rawValue)",
            summary: summary,
            action: .useSupportedController
        )
    }

    private static func genericPairingFailure(code: String) -> ApplicationDiagnostic {
        ApplicationDiagnostic(
            category: .pairing,
            severity: .error,
            code: code,
            summary: "Authenticated pairing failed.",
            action: .pairAgain
        )
    }

    private static func transportFailure(code: String) -> ApplicationDiagnostic {
        ApplicationDiagnostic(
            category: .transport,
            severity: .error,
            code: code,
            summary: "The streaming transport stopped unexpectedly.",
            action: .retryStream
        )
    }

    private static func decoderFailure(code: String) -> ApplicationDiagnostic {
        ApplicationDiagnostic(
            category: .decoder,
            severity: .error,
            code: code,
            summary: "Video decoding stopped before the session completed.",
            action: .reviewStreamSettings
        )
    }

    private static func audioFailure(code: String) -> ApplicationDiagnostic {
        ApplicationDiagnostic(
            category: .audio,
            severity: .error,
            code: code,
            summary: "Audio playback stopped before the session completed.",
            action: .checkAudioOutput
        )
    }

    private static func inputFailure(code: String) -> ApplicationDiagnostic {
        ApplicationDiagnostic(
            category: .input,
            severity: .error,
            code: code,
            summary: "Remote input is no longer available for this session.",
            action: .reconnectInput
        )
    }
}
