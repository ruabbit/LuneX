import Foundation

enum ApplicationDiagnosticCategory: String, CaseIterable, Hashable, Sendable {
    case pairing
    case transport
    case decoder
    case audio
    case input
    case application

    var label: String {
        switch self {
        case .pairing: "Pairing"
        case .transport: "Transport"
        case .decoder: "Video"
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
        case .audio: "speaker.wave.2"
        case .input: "cursorarrow.motionlines"
        case .application: "app.badge.checkmark"
        }
    }

    static func infer(from subsystem: String) -> ApplicationDiagnosticCategory {
        let normalized = subsystem.lowercased()
        if normalized.contains("pair") || normalized.contains("identity") { return .pairing }
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
        case .audio: "stream.audio"
        case .input: "stream.input"
        case .application: "app"
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
            }
        }
        if error is VideoDecoderError || error is VideoDecodePipelineError ||
            error is VideoFormatDescriptionError || error is VideoColorMetadataError ||
            error is MoonlightVideoPacketError || error is VideoAccessUnitAssemblyError ||
            error is MetalFrameDeliveryError {
            return decoderFailure(code: "video_pipeline_failed")
        }
        if error is OpusDecoderError || error is AudioJitterBufferError ||
            error is AudioPipelineError || error is AudioRuntimeRecoveryError {
            return audioFailure(code: "audio_pipeline_failed")
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
