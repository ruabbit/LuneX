import Foundation
import Observation

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
    case refreshHosts
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

    var title: LocalizedStringResource {
        switch self {
        case .correctHostAddress: "Correct Address"
        case .refreshHosts: "Refresh Hosts"
        case .retryHostAdd: "Retry Add Host"
        case .retryHostRemoval: "Retry Host Removal"
        case .resetHostTrust: "Reset Trust"
        case .retryPairing: "Retry Pairing"
        case .refreshCatalog: "Refresh Apps"
        case .chooseHostAndApp: "Choose Host and App"
        case .reconnectStream: "Reconnect Stream"
        case .stopStream: "Stop Stream"
        case .reviewStreamSettings: "Review Stream Settings"
        case .reviewHDRSettings: "Review HDR Settings"
        case .checkAudioOutput: "Check Audio Output"
        case .reconnectInput: "Reconnect Input"
        case .updateBuild: "Review Build"
        case .retrySettingsSave: "Retry Settings Save"
        case .exportDiagnostics: "Export Diagnostics"
        }
    }
}

struct ProductWorkspaceID: Hashable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

struct ProductWorkspaceGeneration: Hashable, Sendable {
    static let initial = ProductWorkspaceGeneration(uncheckedRawValue: 1)

    let rawValue: UInt64

    init?(rawValue: UInt64) {
        guard rawValue > 0 else { return nil }
        self.rawValue = rawValue
    }

    func advanced() -> ProductWorkspaceGeneration? {
        guard rawValue < UInt64.max else { return nil }
        return ProductWorkspaceGeneration(uncheckedRawValue: rawValue + 1)
    }

    private init(uncheckedRawValue: UInt64) {
        rawValue = uncheckedRawValue
    }
}

struct ProductWorkspaceReference: Hashable, Sendable {
    let id: ProductWorkspaceID
    let generation: ProductWorkspaceGeneration
}

struct ProductHostSelectionGeneration: Hashable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

struct ProductCatalogOwner: Hashable, Sendable {
    let workspace: ProductWorkspaceReference
    let hostID: MoonlightHost.ID
    let hostSelectionGeneration: ProductHostSelectionGeneration
}

struct ProductPairingAttemptGeneration: Hashable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

struct ProductPairingOwner: Hashable, Sendable {
    let workspace: ProductWorkspaceReference
    let hostID: MoonlightHost.ID
    let hostSelectionGeneration: ProductHostSelectionGeneration
    let attemptGeneration: ProductPairingAttemptGeneration
}

struct ProductHostActionOwner: Hashable, Sendable {
    let workspace: ProductWorkspaceReference
    let hostID: MoonlightHost.ID
    let hostSelectionGeneration: ProductHostSelectionGeneration
}

struct ProductSessionOwner: Hashable, Sendable {
    let workspace: ProductWorkspaceReference
    let sessionID: UUID
}

enum ProductSessionActualPhase: Equatable, Sendable {
    case idle
    case launching
    case waitingForTransport
    case streaming
    case reconnecting(attempt: Int?)
    case stopping
    case remoteTerminated
    case reconnectExhausted
    case failed
}

enum ProductSessionWorkspaceOwnership: Equatable, Sendable {
    case none
    case current
    case otherWorkspace
    case staleReservation
}

enum ProductActionScope: Hashable, Sendable {
    case application
    case workspace(ProductWorkspaceReference)
    case catalog(ProductCatalogOwner)
    case pairing(ProductPairingOwner)
    case host(ProductHostActionOwner)
    case session(
        workspace: ProductWorkspaceReference,
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

enum ProductActionInvocationResult: Equatable, Sendable {
    case performed
    case rejected(ProductIssue)

    var issue: ProductIssue? {
        guard case let .rejected(issue) = self else { return nil }
        return issue
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
    case hostLibraryLoadFailed = "host_library_load_failed"
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
             .hostRemoveFailed, .hostTrustResetFailed, .hostLibraryLoadFailed:
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
             .hostLibraryLoadFailed,
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
        case .hostLibraryLoadFailed:
            .refreshHosts
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
        case .hostLibraryLoadFailed:
            issue("Hosts not loaded", "The saved host library could not be loaded. Try refreshing again.", "desktopcomputer.trianglebadge.exclamationmark")
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
            issue("Connection interrupted", "Wait for current recovery, or start a new connection when it becomes available.", "network.slash")
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

enum ProductWorkspaceSheet: Equatable, Sendable {
    case addHost
    case pairing(hostID: MoonlightHost.ID)
}

enum ProductWorkspaceDialog: Equatable, Sendable {
    case removeHost(ProductHostDestructiveConfirmation)
    case resetHostTrust(ProductHostDestructiveConfirmation)
    case stopStream(sessionID: UUID)
}

enum ProductStreamOverlayVisibility: Equatable, Sendable {
    case hidden
    case visible
}

struct ProductWorkspacePresentationState: Equatable, Sendable {
    var sheet: ProductWorkspaceSheet?
    var dialog: ProductWorkspaceDialog?
    var issue: ProductIssue?
    var streamOverlay: ProductStreamOverlayVisibility

    init(
        sheet: ProductWorkspaceSheet? = nil,
        dialog: ProductWorkspaceDialog? = nil,
        issue: ProductIssue? = nil,
        streamOverlay: ProductStreamOverlayVisibility = .hidden
    ) {
        self.sheet = sheet
        self.dialog = dialog
        self.issue = issue
        self.streamOverlay = streamOverlay
    }
}

struct PairingUIState: Equatable, Sendable {
    var owner: ProductPairingOwner?
    var attemptID: UUID?
    var stage: PairingStage
    var pin: String
    var isRunning: Bool
    var message: String?
    var actionMessage: String?
    var issue: ProductIssue?

    init(
        owner: ProductPairingOwner? = nil,
        attemptID: UUID? = nil,
        stage: PairingStage = .idle,
        pin: String = "",
        isRunning: Bool = false,
        message: String? = nil,
        actionMessage: String? = nil,
        issue: ProductIssue? = nil
    ) {
        self.owner = owner
        self.attemptID = attemptID
        self.stage = stage
        self.pin = pin
        self.isRunning = isRunning
        self.message = message
        self.actionMessage = actionMessage
        self.issue = issue
    }

    var hostID: MoonlightHost.ID? {
        owner?.hostID
    }
}

enum ProductHostDestructiveKind: Equatable, Sendable {
    case remove
    case resetTrust
}

struct ProductHostDestructiveConfirmation: Equatable, Sendable {
    let owner: ProductHostActionOwner
    let kind: ProductHostDestructiveKind
    let requiresSessionStop: Bool
}

enum ProductHostDestructiveState: Equatable, Sendable {
    case idle
    case awaitingConfirmation(ProductHostDestructiveConfirmation)
    case performing(ProductHostDestructiveConfirmation)
    case failed(ProductHostDestructiveConfirmation, ProductIssue)
    case succeeded(kind: ProductHostDestructiveKind, hostID: MoonlightHost.ID)

    var confirmation: ProductHostDestructiveConfirmation? {
        switch self {
        case let .awaitingConfirmation(confirmation),
             let .performing(confirmation),
             let .failed(confirmation, _):
            confirmation
        case .idle, .succeeded:
            nil
        }
    }

    var isPerforming: Bool {
        guard case .performing = self else { return false }
        return true
    }

    var issue: ProductIssue? {
        guard case let .failed(_, issue) = self else { return nil }
        return issue
    }
}

struct ProductWorkspaceState: Equatable, Sendable {
    let reference: ProductWorkspaceReference
    var navigationSelection: AppNavigationSelection
    var selectedHostID: MoonlightHost.ID? {
        didSet {
            guard selectedHostID != oldValue else { return }
            hostSelectionGeneration = ProductHostSelectionGeneration()
            selectedAppID = nil
            catalog = ProductAppCatalogWorkspaceState(
                owner: catalogOwner,
                phase: selectedHostID == nil ? .unavailable : .idle
            )
            pairing = PairingUIState()
            hostLibrary.destructiveAction = .idle
            switch presentation.dialog {
            case .removeHost, .resetHostTrust:
                presentation.dialog = nil
            case .stopStream, nil:
                break
            }
        }
    }
    private(set) var hostSelectionGeneration: ProductHostSelectionGeneration
    var selectedAppID: RemoteApp.ID? {
        didSet {
            guard selectedAppID != oldValue,
                  presentation.issue?.domain == .session else { return }
            presentation.issue = nil
        }
    }
    var presentation: ProductWorkspacePresentationState
    var hostLibrary: ProductHostLibraryWorkspaceState
    var catalog: ProductAppCatalogWorkspaceState
    var pairing: PairingUIState

    init(
        reference: ProductWorkspaceReference,
        navigationSelection: AppNavigationSelection = .library,
        selectedHostID: MoonlightHost.ID? = nil,
        hostSelectionGeneration: ProductHostSelectionGeneration = .init(),
        selectedAppID: RemoteApp.ID? = nil,
        presentation: ProductWorkspacePresentationState = .init(),
        hostLibrary: ProductHostLibraryWorkspaceState = .init(),
        catalog: ProductAppCatalogWorkspaceState? = nil,
        pairing: PairingUIState = .init()
    ) {
        self.reference = reference
        self.navigationSelection = navigationSelection
        self.selectedHostID = selectedHostID
        self.hostSelectionGeneration = hostSelectionGeneration
        self.selectedAppID = selectedAppID
        self.presentation = presentation
        self.hostLibrary = hostLibrary
        let owner = selectedHostID.map {
            ProductCatalogOwner(
                workspace: reference,
                hostID: $0,
                hostSelectionGeneration: hostSelectionGeneration
            )
        }
        self.catalog = catalog ?? ProductAppCatalogWorkspaceState(
            owner: owner,
            phase: selectedHostID == nil ? .unavailable : .idle
        )
        self.pairing = pairing
    }

    var catalogOwner: ProductCatalogOwner? {
        selectedHostID.map {
            ProductCatalogOwner(
                workspace: reference,
                hostID: $0,
                hostSelectionGeneration: hostSelectionGeneration
            )
        }
    }
}

enum ProductCatalogContentSource: Equatable, Sendable {
    case cached
    case current
}

enum ProductAppCatalogPhase: Equatable, Sendable {
    case unavailable
    case idle
    case loading(hasCachedApps: Bool)
    case empty(source: ProductCatalogContentSource)
    case cached
    case current
    case failed(hasCachedApps: Bool)

    var isRefreshing: Bool {
        guard case .loading = self else { return false }
        return true
    }
}

struct ProductAppCatalogWorkspaceState: Equatable, Sendable {
    var owner: ProductCatalogOwner?
    var phase: ProductAppCatalogPhase
    var updatedAt: Date?
    var issue: ProductIssue?

    init(
        owner: ProductCatalogOwner? = nil,
        phase: ProductAppCatalogPhase = .unavailable,
        updatedAt: Date? = nil,
        issue: ProductIssue? = nil
    ) {
        self.owner = owner
        self.phase = phase
        self.updatedAt = updatedAt
        self.issue = issue
    }
}

enum ProductHostLibraryPhase: Equatable, Sendable {
    case loading
    case firstUse
    case available
    case failed
}

enum ManualHostSubmissionState: Equatable, Sendable {
    case idle
    case validating
    case saving
    case succeeded(hostID: MoonlightHost.ID)
    case failed(ProductIssue)

    var isSubmitting: Bool {
        switch self {
        case .validating, .saving:
            true
        case .idle, .succeeded, .failed:
            false
        }
    }

    var fieldIssue: ProductIssue? {
        guard case let .failed(issue) = self else { return nil }
        return issue
    }

    var shouldDismissSheet: Bool {
        guard case .succeeded = self else { return false }
        return true
    }
}

struct ProductHostLibraryWorkspaceState: Equatable, Sendable {
    var phase: ProductHostLibraryPhase
    var isRefreshing: Bool
    var refreshIssue: ProductIssue?
    var manualHostDraft: ManualHostDraft
    var manualHostSubmission: ManualHostSubmissionState
    var destructiveAction: ProductHostDestructiveState

    init(
        phase: ProductHostLibraryPhase = .loading,
        isRefreshing: Bool = false,
        refreshIssue: ProductIssue? = nil,
        manualHostDraft: ManualHostDraft = .init(),
        manualHostSubmission: ManualHostSubmissionState = .idle,
        destructiveAction: ProductHostDestructiveState = .idle
    ) {
        self.phase = phase
        self.isRefreshing = isRefreshing
        self.refreshIssue = refreshIssue
        self.manualHostDraft = manualHostDraft
        self.manualHostSubmission = manualHostSubmission
        self.destructiveAction = destructiveAction
    }
}

struct ProductWorkspaceRestorationState: Equatable, Sendable {
    var navigationSelection: AppNavigationSelection
    var selectedHostID: MoonlightHost.ID?
    var selectedAppID: RemoteApp.ID?

    init(
        navigationSelection: AppNavigationSelection = .library,
        selectedHostID: MoonlightHost.ID? = nil,
        selectedAppID: RemoteApp.ID? = nil
    ) {
        self.navigationSelection = navigationSelection
        self.selectedHostID = selectedHostID
        self.selectedAppID = selectedAppID
    }

    init(_ state: ProductWorkspaceState) {
        navigationSelection = state.navigationSelection
        selectedHostID = state.selectedHostID
        selectedAppID = state.selectedAppID
    }
}

enum ProductWorkspaceRegistryFailure: Error, Equatable, Sendable {
    case workspaceAlreadyOpen(ProductWorkspaceID)
    case missingWorkspace(ProductWorkspaceID)
    case staleReference(current: ProductWorkspaceReference?)
    case generationExhausted(ProductWorkspaceID)
    case duplicateRestoredWorkspace(ProductWorkspaceID)
}

@MainActor
@Observable
final class ProductWorkspaceRegistry {
    private(set) var statesByID: [ProductWorkspaceID: ProductWorkspaceState]
    @ObservationIgnored private var latestGenerationByID:
        [ProductWorkspaceID: ProductWorkspaceGeneration]
    @ObservationIgnored private let generateID: @MainActor () -> ProductWorkspaceID

    init(
        generateID: @escaping @MainActor () -> ProductWorkspaceID = {
            ProductWorkspaceID()
        }
    ) {
        statesByID = [:]
        latestGenerationByID = [:]
        self.generateID = generateID
    }

    init(
        primaryWorkspaceID: ProductWorkspaceID,
        generateID: @escaping @MainActor () -> ProductWorkspaceID = {
            ProductWorkspaceID()
        }
    ) {
        let reference = ProductWorkspaceReference(
            id: primaryWorkspaceID,
            generation: .initial
        )
        statesByID = [
            primaryWorkspaceID: ProductWorkspaceState(reference: reference)
        ]
        latestGenerationByID = [primaryWorkspaceID: .initial]
        self.generateID = generateID
    }

    init(
        restoring states: [ProductWorkspaceState],
        generateID: @escaping @MainActor () -> ProductWorkspaceID = {
            ProductWorkspaceID()
        }
    ) throws {
        var restored: [ProductWorkspaceID: ProductWorkspaceState] = [:]
        var generations: [ProductWorkspaceID: ProductWorkspaceGeneration] = [:]
        for state in states {
            guard restored[state.reference.id] == nil else {
                throw ProductWorkspaceRegistryFailure
                    .duplicateRestoredWorkspace(state.reference.id)
            }
            restored[state.reference.id] = state
            generations[state.reference.id] = state.reference.generation
        }
        statesByID = restored
        latestGenerationByID = generations
        self.generateID = generateID
    }

    var states: [ProductWorkspaceState] {
        statesByID.values.sorted {
            $0.reference.id.rawValue.uuidString
                < $1.reference.id.rawValue.uuidString
        }
    }

    @discardableResult
    func create(
        id: ProductWorkspaceID? = nil,
        restoration: ProductWorkspaceRestorationState = .init()
    ) throws -> ProductWorkspaceReference {
        let id = id ?? generateID()
        guard statesByID[id] == nil else {
            throw ProductWorkspaceRegistryFailure.workspaceAlreadyOpen(id)
        }
        let generation = try nextGeneration(for: id)
        let reference = ProductWorkspaceReference(id: id, generation: generation)
        statesByID[id] = makeState(reference: reference, restoration: restoration)
        latestGenerationByID[id] = generation
        return reference
    }

    @discardableResult
    func restore(
        id: ProductWorkspaceID,
        restoration: ProductWorkspaceRestorationState
    ) throws -> ProductWorkspaceReference {
        if statesByID[id] != nil {
            let replacement = try nextGeneration(for: id)
            let reference = ProductWorkspaceReference(id: id, generation: replacement)
            statesByID[id] = makeState(reference: reference, restoration: restoration)
            latestGenerationByID[id] = replacement
            return reference
        }
        return try create(id: id, restoration: restoration)
    }

    @discardableResult
    func replace(
        _ reference: ProductWorkspaceReference
    ) throws -> ProductWorkspaceReference {
        let current = try checkedState(for: reference)
        let replacement = try nextGeneration(for: reference.id)
        let nextReference = ProductWorkspaceReference(
            id: reference.id,
            generation: replacement
        )
        statesByID[reference.id] = makeState(
            reference: nextReference,
            restoration: ProductWorkspaceRestorationState(current)
        )
        latestGenerationByID[reference.id] = replacement
        return nextReference
    }

    func state(for reference: ProductWorkspaceReference) -> ProductWorkspaceState? {
        guard let state = statesByID[reference.id], state.reference == reference else {
            return nil
        }
        return state
    }

    func currentState(for id: ProductWorkspaceID) -> ProductWorkspaceState? {
        statesByID[id]
    }

    @discardableResult
    func update(
        _ reference: ProductWorkspaceReference,
        _ mutation: (inout ProductWorkspaceState) -> Void
    ) throws -> ProductWorkspaceState {
        var state = try checkedState(for: reference)
        mutation(&state)
        statesByID[reference.id] = state
        return state
    }

    func reconcile(
        availableHostIDs: [MoonlightHost.ID],
        availableAppIDsByHostID: [MoonlightHost.ID: Set<RemoteApp.ID>] = [:]
    ) {
        let availableHosts = Set(availableHostIDs)
        for id in Array(statesByID.keys) {
            guard var state = statesByID[id] else { continue }
            let priorHostID = state.selectedHostID
            if let selectedHostID = state.selectedHostID,
               !availableHosts.contains(selectedHostID) {
                state.selectedHostID = availableHostIDs.first
            } else if state.selectedHostID == nil {
                state.selectedHostID = availableHostIDs.first
            }
            if state.selectedHostID != priorHostID {
                state.selectedAppID = nil
            } else if let hostID = state.selectedHostID,
                      let availableApps = availableAppIDsByHostID[hostID],
                      let selectedAppID = state.selectedAppID,
                      !availableApps.contains(selectedAppID) {
                state.selectedAppID = nil
            }
            statesByID[id] = state
        }
    }

    @discardableResult
    func close(
        _ reference: ProductWorkspaceReference
    ) throws -> ProductWorkspaceState {
        let state = try checkedState(for: reference)
        statesByID[reference.id] = nil
        return state
    }

    private func checkedState(
        for reference: ProductWorkspaceReference
    ) throws -> ProductWorkspaceState {
        guard let state = statesByID[reference.id] else {
            if latestGenerationByID[reference.id] != nil {
                throw ProductWorkspaceRegistryFailure.staleReference(current: nil)
            }
            throw ProductWorkspaceRegistryFailure.missingWorkspace(reference.id)
        }
        guard state.reference == reference else {
            throw ProductWorkspaceRegistryFailure
                .staleReference(current: state.reference)
        }
        return state
    }

    private func nextGeneration(
        for id: ProductWorkspaceID
    ) throws -> ProductWorkspaceGeneration {
        guard let current = latestGenerationByID[id] else { return .initial }
        guard let next = current.advanced() else {
            throw ProductWorkspaceRegistryFailure.generationExhausted(id)
        }
        return next
    }

    private func makeState(
        reference: ProductWorkspaceReference,
        restoration: ProductWorkspaceRestorationState
    ) -> ProductWorkspaceState {
        ProductWorkspaceState(
            reference: reference,
            navigationSelection: restoration.navigationSelection,
            selectedHostID: restoration.selectedHostID,
            selectedAppID: restoration.selectedAppID
        )
    }
}
