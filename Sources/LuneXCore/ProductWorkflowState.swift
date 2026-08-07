import Foundation

enum ProductIssueDomain: String, CaseIterable, Hashable, Sendable {
    case host
    case pairing
    case catalog
    case session
    case settings
    case diagnostics
}

enum ProductIssueSeverity: String, CaseIterable, Hashable, Sendable {
    case information
    case warning
    case error
}

enum ProductActionKind: String, CaseIterable, Hashable, Sendable {
    case correctHostAddress
    case retryHostAdd
    case retryHostRemoval
    case resetHostTrust
    case retryPairing
    case refreshCatalog
    case chooseHostAndApp
    case reconnectStream
    case stopStream
    case reviewStreamSettings
    case reviewHDRSettings
    case checkAudioOutput
    case reconnectInput
    case updateBuild
    case retrySettingsSave
    case exportDiagnostics
}

enum ProductActionScope: Hashable, Sendable {
    case application
    case workspace(id: UUID, generation: UInt64)
    case session(
        workspaceID: UUID,
        workspaceGeneration: UInt64,
        sessionID: UUID
    )
}

struct ProductActionToken: Identifiable, Hashable, Sendable {
    let id: UUID
    let kind: ProductActionKind
    let scope: ProductActionScope

    init(
        id: UUID = UUID(),
        kind: ProductActionKind,
        scope: ProductActionScope
    ) {
        self.id = id
        self.kind = kind
        self.scope = scope
    }
}

struct ProductIssuePresentation: Equatable, Sendable {
    let title: LocalizedStringResource
    let message: LocalizedStringResource
    let systemImage: String
}

enum ProductIssueCode: String, CaseIterable, Hashable, Sendable {
    case hostAddressRequired = "host_address_required"
    case hostAddressInvalid = "host_address_invalid"
    case hostAddFailed = "host_add_failed"
    case hostRemoveFailed = "host_remove_failed"
    case hostTrustResetFailed = "host_trust_reset_failed"
    case pairingUnavailable = "pairing_unavailable"
    case pairingPINInvalid = "pairing_pin_invalid"
    case pairingFailed = "pairing_failed"
    case pairingCancelled = "pairing_cancelled"
    case catalogRequiresPairing = "catalog_requires_pairing"
    case catalogRefreshFailed = "catalog_refresh_failed"
    case launchSelectionRequired = "launch_selection_required"
    case streamUnavailable = "stream_unavailable"
    case streamInterrupted = "stream_interrupted"
    case streamTerminated = "stream_terminated"
    case reconnectExhausted = "reconnect_exhausted"
    case streamStopFailed = "stream_stop_failed"
    case streamSettingsInvalid = "stream_settings_invalid"
    case hdrPresentationFailed = "hdr_presentation_failed"
    case audioOutputUnavailable = "audio_output_unavailable"
    case inputUnavailable = "input_unavailable"
    case staleAction = "stale_action"
    case settingsSaveFailed = "settings_save_failed"
    case diagnosticExportFailed = "diagnostic_export_failed"

    var domain: ProductIssueDomain {
        switch self {
        case .hostAddressRequired, .hostAddressInvalid, .hostAddFailed,
             .hostRemoveFailed, .hostTrustResetFailed:
            .host
        case .pairingUnavailable, .pairingPINInvalid, .pairingFailed,
             .pairingCancelled:
            .pairing
        case .catalogRequiresPairing, .catalogRefreshFailed:
            .catalog
        case .launchSelectionRequired, .streamUnavailable, .streamInterrupted,
             .streamTerminated, .reconnectExhausted, .streamStopFailed,
             .streamSettingsInvalid, .hdrPresentationFailed,
             .audioOutputUnavailable, .inputUnavailable, .staleAction:
            .session
        case .settingsSaveFailed:
            .settings
        case .diagnosticExportFailed:
            .diagnostics
        }
    }

    var severity: ProductIssueSeverity {
        switch self {
        case .pairingCancelled, .streamTerminated:
            .information
        case .hostAddressRequired, .hostAddressInvalid, .pairingPINInvalid,
             .catalogRequiresPairing, .launchSelectionRequired,
             .streamInterrupted, .staleAction:
            .warning
        case .hostAddFailed, .hostRemoveFailed, .hostTrustResetFailed,
             .pairingUnavailable, .pairingFailed, .catalogRefreshFailed,
             .streamUnavailable, .reconnectExhausted, .streamStopFailed,
             .streamSettingsInvalid, .hdrPresentationFailed,
             .audioOutputUnavailable, .inputUnavailable, .settingsSaveFailed,
             .diagnosticExportFailed:
            .error
        }
    }

    var defaultAction: ProductActionKind? {
        switch self {
        case .hostAddressRequired, .hostAddressInvalid:
            .correctHostAddress
        case .hostAddFailed:
            .retryHostAdd
        case .hostRemoveFailed:
            .retryHostRemoval
        case .hostTrustResetFailed:
            .resetHostTrust
        case .pairingUnavailable:
            .updateBuild
        case .pairingPINInvalid, .pairingFailed:
            .retryPairing
        case .catalogRequiresPairing:
            .retryPairing
        case .catalogRefreshFailed:
            .refreshCatalog
        case .launchSelectionRequired:
            .chooseHostAndApp
        case .streamUnavailable:
            .updateBuild
        case .streamInterrupted, .streamTerminated, .reconnectExhausted:
            .reconnectStream
        case .streamStopFailed:
            .stopStream
        case .streamSettingsInvalid:
            .reviewStreamSettings
        case .hdrPresentationFailed:
            .reviewHDRSettings
        case .audioOutputUnavailable:
            .checkAudioOutput
        case .inputUnavailable:
            .reconnectInput
        case .settingsSaveFailed:
            .retrySettingsSave
        case .diagnosticExportFailed:
            .exportDiagnostics
        case .pairingCancelled, .staleAction:
            nil
        }
    }

    var presentation: ProductIssuePresentation {
        switch self {
        case .hostAddressRequired:
            issue("Host address required", "Enter a host name or network address.", "network.badge.shield.half.filled")
        case .hostAddressInvalid:
            issue("Host address invalid", "Check the host name, address, and port, then try again.", "network.badge.shield.half.filled")
        case .hostAddFailed:
            issue("Host not added", "The host could not be saved. Try again.", "plus.rectangle.on.rectangle")
        case .hostRemoveFailed:
            issue("Host not removed", "The host remains in your library. Try again.", "trash.slash")
        case .hostTrustResetFailed:
            issue("Trust not reset", "The saved trust remains unchanged. Try again.", "checkmark.shield")
        case .pairingUnavailable:
            issue("Pairing unavailable", "This build does not include the authenticated pairing provider.", "exclamationmark.shield")
        case .pairingPINInvalid:
            issue("PIN incomplete", "Enter the four-digit PIN and try again.", "number.square")
        case .pairingFailed:
            issue("Pairing failed", "The secure pairing exchange did not complete. Try pairing again.", "lock.trianglebadge.exclamationmark")
        case .pairingCancelled:
            issue("Pairing cancelled", "No pairing changes were saved.", "xmark.circle")
        case .catalogRequiresPairing:
            issue("Pairing required", "Pair this host before loading its apps.", "lock")
        case .catalogRefreshFailed:
            issue("Apps not updated", "The saved app list remains available. Try refreshing again.", "square.grid.3x3")
        case .launchSelectionRequired:
            issue("Choose an app", "Select a paired host and an app before starting a stream.", "play.rectangle")
        case .streamUnavailable:
            issue("Streaming unavailable", "This build does not include every required streaming provider.", "exclamationmark.triangle")
        case .streamInterrupted:
            issue("Connection interrupted", "LuneX is waiting for the current session to recover.", "network.slash")
        case .streamTerminated:
            issue("Stream ended", "The remote host ended this session.", "stop.circle")
        case .reconnectExhausted:
            issue("Reconnect stopped", "The current recovery budget was exhausted. Start a new connection.", "arrow.clockwise.circle")
        case .streamStopFailed:
            issue("Stream did not stop cleanly", "LuneX released local media and input. Retry cleanup if it remains available.", "stop.circle")
        case .streamSettingsInvalid:
            issue("Stream settings unavailable", "Review the codec, resolution, frame rate, and bitrate, then try again.", "slider.horizontal.3")
        case .hdrPresentationFailed:
            issue("HDR presentation unavailable", "Review HDR settings and the current display, then reconnect.", "sun.max.trianglebadge.exclamationmark")
        case .audioOutputUnavailable:
            issue("Audio output unavailable", "Check the current output route, then reconnect the stream.", "speaker.slash")
        case .inputUnavailable:
            issue("Remote input unavailable", "Refocus or reconnect the stream to restore remote input.", "cursorarrow.slash")
        case .staleAction:
            issue("Action no longer available", "The related window or session has changed.", "arrow.triangle.2.circlepath")
        case .settingsSaveFailed:
            issue("Settings not saved", "Your prior settings remain active. Try saving again.", "gearshape")
        case .diagnosticExportFailed:
            issue("Diagnostics not exported", "The local redacted report could not be created. Try again.", "doc.badge.ellipsis")
        }
    }

    private func issue(
        _ title: LocalizedStringResource,
        _ message: LocalizedStringResource,
        _ systemImage: String
    ) -> ProductIssuePresentation {
        ProductIssuePresentation(
            title: title,
            message: message,
            systemImage: systemImage
        )
    }
}

struct ProductIssue: Identifiable, Equatable, Sendable {
    let id: UUID
    let code: ProductIssueCode
    let action: ProductActionToken?

    init(
        id: UUID = UUID(),
        code: ProductIssueCode,
        actionScope: ProductActionScope = .application,
        actionID: UUID = UUID()
    ) {
        self.id = id
        self.code = code
        action = code.defaultAction.map {
            ProductActionToken(id: actionID, kind: $0, scope: actionScope)
        }
    }

    var domain: ProductIssueDomain { code.domain }
    var severity: ProductIssueSeverity { code.severity }
    var presentation: ProductIssuePresentation { code.presentation }
}

struct ManualHostSubmission: Equatable, Sendable {
    let name: String?
    let endpoint: HostEndpoint

    var normalizedAddress: String { endpoint.displayAddress }
}

struct ManualHostValidationFailure: Error, Equatable, Sendable {
    let issueCode: ProductIssueCode
}

struct ManualHostDraft: Equatable, Sendable {
    var name: String
    var address: String

    init(name: String = "", address: String = "") {
        self.name = name
        self.address = address
    }

    func validate() -> Result<ManualHostSubmission, ManualHostValidationFailure> {
        do {
            let endpoint = try HostEndpointParser.parse(address)
            let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            return .success(ManualHostSubmission(
                name: normalizedName.isEmpty ? nil : normalizedName,
                endpoint: endpoint
            ))
        } catch HostEndpointParseError.emptyAddress {
            return .failure(ManualHostValidationFailure(issueCode: .hostAddressRequired))
        } catch {
            return .failure(ManualHostValidationFailure(issueCode: .hostAddressInvalid))
        }
    }
}
