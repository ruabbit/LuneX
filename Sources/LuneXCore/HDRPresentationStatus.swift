import Foundation

enum HDRPresentationFallback: Hashable, Sendable {
    case disabledByUser
    case platformUnavailable
    case displayCapabilityUnavailable
    case displayConstrained

    init(_ reason: HDRSDRFallbackReason) {
        switch reason {
        case .userPreferenceDisabled:
            self = .disabledByUser
        case .platformOutputUnsupported:
            self = .platformUnavailable
        case .currentHeadroomUnavailable, .currentHeadroomInvalid:
            self = .displayCapabilityUnavailable
        case .currentHeadroomInsufficient:
            self = .displayConstrained
        }
    }
}

enum HDRPresentationStatus: Hashable, Sendable {
    case inactive
    case sdr
    case edr
    case sdrFallback(HDRPresentationFallback)
    case invalidInput
    case unsupportedOutput
    case updating
    case pipelineFailure

    init(_ diagnosticState: HDRPresentationDiagnosticState) {
        switch diagnosticState {
        case .inactive:
            self = .inactive
        case .activeSDR:
            self = .sdr
        case .activeEDR:
            self = .edr
        case let .sdrFallback(reason):
            self = .sdrFallback(HDRPresentationFallback(reason))
        case .invalidInput:
            self = .invalidInput
        case .unsupportedOutput:
            self = .unsupportedOutput
        case .staleRevision:
            self = .updating
        case .pipelineFailure:
            self = .pipelineFailure
        }
    }

    var content: HDRPresentationStatusContent {
        switch self {
        case .inactive:
            return HDRPresentationStatusContent(
                overlayLabel: "HDR inactive",
                settingsValue: "Inactive",
                detail: "No active video presentation.",
                systemImage: "sun.max",
                accessibilityValue: "Inactive. No active video presentation."
            )
        case .sdr:
            return HDRPresentationStatusContent(
                overlayLabel: "SDR",
                settingsValue: "SDR",
                detail: "Current video is using standard dynamic range.",
                systemImage: "sun.min",
                accessibilityValue:
                    "SDR. Current video is using standard dynamic range."
            )
        case .edr:
            return HDRPresentationStatusContent(
                overlayLabel: "HDR / EDR",
                settingsValue: "HDR / EDR",
                detail: "Current video is using extended dynamic range.",
                systemImage: "sun.max.fill",
                accessibilityValue:
                    "HDR and EDR. Current video is using extended dynamic range."
            )
        case let .sdrFallback(reason):
            let detail = switch reason {
            case .disabledByUser:
                "HDR output is disabled in settings."
            case .platformUnavailable:
                "HDR output is unavailable on this platform."
            case .displayCapabilityUnavailable:
                "Current display HDR capability is unavailable."
            case .displayConstrained:
                "Current display conditions require standard dynamic range."
            }
            return HDRPresentationStatusContent(
                overlayLabel: "HDR to SDR",
                settingsValue: "SDR fallback",
                detail: detail,
                systemImage: "exclamationmark.triangle",
                accessibilityValue: "SDR fallback. \(detail)"
            )
        case .invalidInput:
            return HDRPresentationStatusContent(
                overlayLabel: "HDR unavailable",
                settingsValue: "Invalid video input",
                detail: "The current video color format cannot be presented.",
                systemImage: "exclamationmark.triangle",
                accessibilityValue:
                    "HDR unavailable. The current video color format cannot be presented."
            )
        case .unsupportedOutput:
            return HDRPresentationStatusContent(
                overlayLabel: "HDR unavailable",
                settingsValue: "Output unavailable",
                detail: "The current output cannot present this HDR mode.",
                systemImage: "exclamationmark.triangle",
                accessibilityValue:
                    "HDR unavailable. The current output cannot present this HDR mode."
            )
        case .updating:
            return HDRPresentationStatusContent(
                overlayLabel: "HDR updating",
                settingsValue: "Updating output",
                detail: "Waiting for video that matches the current display.",
                systemImage: "arrow.triangle.2.circlepath",
                accessibilityValue:
                    "HDR updating. Waiting for video that matches the current display."
            )
        case .pipelineFailure:
            return HDRPresentationStatusContent(
                overlayLabel: "HDR stopped",
                settingsValue: "Output stopped",
                detail: "The video output pipeline could not present the current HDR mode.",
                systemImage: "xmark.octagon",
                accessibilityValue:
                    "HDR stopped. The video output pipeline could not present the current HDR mode."
            )
        }
    }
}

struct HDRPresentationStatusContent: Hashable, Sendable {
    let overlayLabel: String
    let settingsValue: String
    let detail: String
    let systemImage: String
    let accessibilityValue: String
}
