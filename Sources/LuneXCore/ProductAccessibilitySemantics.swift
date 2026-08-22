import Foundation

enum ProductSemanticRole: String, CaseIterable, Equatable, Sendable {
    case status
    case button
    case toggle
    case adjustable
    case picker
    case selectableItem
    case textField
}

enum ProductSemanticEligibility: Equatable, Sendable {
    case enabled
    case inProgress
    case disabled(reason: LocalizedStringResource)

    var isEnabled: Bool {
        self == .enabled
    }
}

struct ProductSemanticDescriptor: Equatable, Sendable {
    let label: LocalizedStringResource
    let value: LocalizedStringResource
    let hint: LocalizedStringResource
    let role: ProductSemanticRole
    let eligibility: ProductSemanticEligibility
    let isDestructive: Bool

    init(
        label: LocalizedStringResource,
        value: LocalizedStringResource,
        hint: LocalizedStringResource,
        role: ProductSemanticRole,
        eligibility: ProductSemanticEligibility = .enabled,
        isDestructive: Bool = false
    ) {
        self.label = label
        self.value = value
        self.hint = hint
        self.role = role
        self.eligibility = eligibility
        self.isDestructive = isDestructive
    }
}

struct ProductSemanticItem<ID>: Identifiable, Equatable, Sendable
where ID: Hashable & Sendable {
    let id: ID
    let descriptor: ProductSemanticDescriptor
}

enum ProductHostSemanticID: String, CaseIterable, Hashable, Sendable {
    case libraryStatus
    case destructiveStatus
    case addHost
    case refreshHosts
    case resetTrust
    case removeHost
}

struct ProductHostSemanticSurface: Equatable, Sendable {
    let items: [ProductSemanticItem<ProductHostSemanticID>]

    init(surface: ProductHostLibrarySurface, hostCount: Int) {
        items = [
            ProductSemanticItem(
                id: .libraryStatus,
                descriptor: ProductSemanticDescriptor(
                    label: "Host library",
                    value: Self.libraryValue(surface, hostCount: hostCount),
                    hint: "Shows the current shared host library state.",
                    role: .status,
                    eligibility: surface.isRefreshing ? .inProgress : .enabled
                )
            ),
            ProductSemanticItem(
                id: .destructiveStatus,
                descriptor: ProductSemanticDescriptor(
                    label: "Host change",
                    value: Self.destructiveValue(surface.destructive),
                    hint: "Shows the current remove-host or reset-trust operation.",
                    role: .status,
                    eligibility: Self.destructiveEligibility(surface.destructive)
                )
            ),
            ProductSemanticItem(
                id: .addHost,
                descriptor: Self.action(
                    label: "Add Host",
                    hint: "Opens validated manual host entry.",
                    enabled: surface.canAddHost,
                    disabledReason: "Host changes are currently unavailable."
                )
            ),
            ProductSemanticItem(
                id: .refreshHosts,
                descriptor: Self.action(
                    label: "Refresh Hosts",
                    hint: "Refreshes the shared host library.",
                    enabled: surface.canRefresh,
                    inProgress: surface.isRefreshing,
                    disabledReason: "Host refresh is currently unavailable."
                )
            ),
            ProductSemanticItem(
                id: .resetTrust,
                descriptor: Self.action(
                    label: "Reset Trust",
                    hint: "Requires confirmation before clearing trust for the selected host.",
                    enabled: surface.canResetTrust,
                    disabledReason: "Select a paired host with no host change in progress.",
                    destructive: true
                )
            ),
            ProductSemanticItem(
                id: .removeHost,
                descriptor: Self.action(
                    label: "Remove Host",
                    hint: "Requires confirmation before removing the selected host.",
                    enabled: surface.canRemove,
                    disabledReason: "Select a host with no host change in progress.",
                    destructive: true
                )
            )
        ]
    }

    static func hostItem(
        _ host: MoonlightHost,
        isSelected: Bool
    ) -> ProductSemanticDescriptor {
        let selection: LocalizedStringResource = isSelected ? "Selected" : "Not selected"
        let reachability: LocalizedStringResource = switch host.reachability {
        case .unknown: "Reachability unknown"
        case .online: "Online"
        case .offline: "Offline"
        }
        let pairing: LocalizedStringResource = switch host.pairingState {
        case .unpaired: "Not paired"
        case .pairing: "Pairing"
        case .paired: "Paired"
        case .failed: "Pairing failed"
        }
        return ProductSemanticDescriptor(
            label: "Host \(host.name)",
            value: "\(selection). \(reachability). \(pairing).",
            hint: "Selects this host in the current window.",
            role: .selectableItem
        )
    }

    private static func libraryValue(
        _ surface: ProductHostLibrarySurface,
        hostCount: Int
    ) -> LocalizedStringResource {
        if surface.isRefreshing { return "Refreshing hosts" }
        return switch surface.content {
        case .loading: "Loading hosts"
        case .firstUse: "No saved hosts"
        case .hosts: "\(hostCount) saved hosts"
        case .failed: "Host library unavailable"
        }
    }

    private static func destructiveValue(
        _ surface: ProductHostDestructiveSurface
    ) -> LocalizedStringResource {
        switch surface {
        case .idle: "No host change pending"
        case .awaitingConfirmation: "Waiting for confirmation"
        case .performing(.remove): "Removing host"
        case .performing(.resetTrust): "Resetting host trust"
        case .failed: "Host change failed"
        case .completed(.remove): "Host removed"
        case .completed(.resetTrust): "Host trust reset"
        }
    }

    private static func destructiveEligibility(
        _ surface: ProductHostDestructiveSurface
    ) -> ProductSemanticEligibility {
        switch surface {
        case .performing: .inProgress
        case .awaitingConfirmation:
            .disabled(reason: "Waiting for destructive action confirmation.")
        case .failed:
            .disabled(reason: "Review the failed host change before continuing.")
        case .idle, .completed: .enabled
        }
    }

    private static func action(
        label: LocalizedStringResource,
        hint: LocalizedStringResource,
        enabled: Bool,
        inProgress: Bool = false,
        disabledReason: LocalizedStringResource,
        destructive: Bool = false
    ) -> ProductSemanticDescriptor {
        ProductSemanticDescriptor(
            label: label,
            value: inProgress ? "In progress" : (enabled ? "Available" : "Unavailable"),
            hint: hint,
            role: .button,
            eligibility: inProgress
                ? .inProgress
                : (enabled ? .enabled : .disabled(reason: disabledReason)),
            isDestructive: destructive
        )
    }
}

enum ProductPairingSemanticID: String, CaseIterable, Hashable, Sendable {
    case status
    case pin
    case start
    case submitPIN
    case cancel
    case retry
}

struct ProductPairingSemanticSurface: Equatable, Sendable {
    let items: [ProductSemanticItem<ProductPairingSemanticID>]

    init(surface: ProductPairingSurface) {
        let pairingInProgress = switch surface.phase {
        case .preparing, .waitingForPIN, .exchangingSecrets, .verifyingServer,
             .savingIdentity:
            true
        case .noHost, .ready, .unavailable, .completed, .cancelled, .failed:
            false
        }
        items = [
            ProductSemanticItem(
                id: .status,
                descriptor: ProductSemanticDescriptor(
                    label: "Pairing status",
                    value: Self.phaseValue(surface.phase),
                    hint: "Shows the current pairing stage for the selected host.",
                    role: .status,
                    eligibility: pairingInProgress ? .inProgress : .enabled
                )
            ),
            ProductSemanticItem(
                id: .pin,
                descriptor: ProductSemanticDescriptor(
                    label: "Pairing PIN",
                    value: surface.phase == .waitingForPIN
                        ? "Four digit PIN required"
                        : "Not requested",
                    hint: "Enter the four digit PIN shown by the host.",
                    role: .textField,
                    eligibility: surface.phase == .waitingForPIN
                        ? .enabled
                        : .disabled(reason: "The pairing PIN is not currently requested.")
                )
            ),
            ProductSemanticItem(
                id: .start,
                descriptor: Self.action(
                    label: "Start Pairing",
                    hint: "Starts a new checked pairing attempt.",
                    enabled: surface.canStart,
                    disabledReason: "Select an unpaired host with pairing transport available."
                )
            ),
            ProductSemanticItem(
                id: .submitPIN,
                descriptor: Self.action(
                    label: "Submit PIN",
                    hint: "Submits the validated four digit PIN.",
                    enabled: surface.canSubmitPIN,
                    disabledReason: "Enter a valid four digit PIN for the current attempt."
                )
            ),
            ProductSemanticItem(
                id: .cancel,
                descriptor: Self.action(
                    label: "Cancel Pairing",
                    hint: "Cancels only the current pairing attempt.",
                    enabled: surface.canCancel,
                    disabledReason: "No cancellable pairing attempt is active."
                )
            ),
            ProductSemanticItem(
                id: .retry,
                descriptor: Self.action(
                    label: "Retry Pairing",
                    hint: "Starts a replacement attempt after a retryable failure.",
                    enabled: surface.canRetry,
                    disabledReason: "The current pairing state is not retryable."
                )
            )
        ]
    }

    private static func phaseValue(
        _ phase: ProductPairingSurfacePhase
    ) -> LocalizedStringResource {
        switch phase {
        case .noHost: "No host selected"
        case .ready: "Ready to pair"
        case .unavailable: "Pairing unavailable"
        case .preparing: "Preparing pairing"
        case .waitingForPIN: "Waiting for PIN"
        case .exchangingSecrets: "Exchanging pairing secrets"
        case .verifyingServer: "Verifying host identity"
        case .savingIdentity: "Saving trusted identity"
        case .completed: "Paired"
        case .cancelled: "Pairing cancelled"
        case .failed: "Pairing failed"
        }
    }

    private static func action(
        label: LocalizedStringResource,
        hint: LocalizedStringResource,
        enabled: Bool,
        disabledReason: LocalizedStringResource
    ) -> ProductSemanticDescriptor {
        ProductSemanticDescriptor(
            label: label,
            value: enabled ? "Available" : "Unavailable",
            hint: hint,
            role: .button,
            eligibility: enabled ? .enabled : .disabled(reason: disabledReason)
        )
    }
}

enum ProductCatalogSemanticID: String, CaseIterable, Hashable, Sendable {
    case status
    case refresh
    case retry
}

struct ProductCatalogSemanticSurface: Equatable, Sendable {
    let items: [ProductSemanticItem<ProductCatalogSemanticID>]

    init(surface: ProductAppCatalogSurface, appCount: Int) {
        let isLoading = switch surface.content {
        case .loading, .loadingCached: true
        default: false
        }
        items = [
            ProductSemanticItem(
                id: .status,
                descriptor: ProductSemanticDescriptor(
                    label: "App catalog",
                    value: Self.contentValue(surface.content, appCount: appCount),
                    hint: "Shows whether apps are current, cached, loading, or unavailable.",
                    role: .status,
                    eligibility: isLoading ? .inProgress : .enabled
                )
            ),
            ProductSemanticItem(
                id: .refresh,
                descriptor: Self.action(
                    label: "Refresh Apps",
                    hint: "Loads the app catalog for the selected paired host.",
                    enabled: surface.canRefresh,
                    inProgress: isLoading,
                    disabledReason: "App refresh is not available for the current host state."
                )
            ),
            ProductSemanticItem(
                id: .retry,
                descriptor: Self.action(
                    label: "Retry App Refresh",
                    hint: "Retries the current scoped catalog failure.",
                    enabled: surface.canRetry,
                    disabledReason: "The current catalog state is not retryable."
                )
            )
        ]
    }

    static func appItem(
        name: String,
        isSelected: Bool,
        isEnabled: Bool
    ) -> ProductSemanticDescriptor {
        ProductSemanticDescriptor(
            label: "App \(name)",
            value: isSelected ? "Selected" : "Not selected",
            hint: "Selects this app for streaming in the current window.",
            role: .selectableItem,
            eligibility: isEnabled
                ? .enabled
                : .disabled(reason: "App selection is unavailable for the current host.")
        )
    }

    private static func contentValue(
        _ content: ProductAppCatalogContentSurface,
        appCount: Int
    ) -> LocalizedStringResource {
        switch content {
        case .unavailable: "Select a host to load apps"
        case let .requiresPairing(hasCachedApps):
            hasCachedApps ? "Cached apps require pairing" : "Pair host to load apps"
        case .idle: "Ready to load apps"
        case .loading: "Loading apps"
        case .loadingCached: "Refreshing \(appCount) cached apps"
        case .empty(.cached): "Cached catalog is empty"
        case .empty(.current): "Current catalog is empty"
        case .cached: "\(appCount) cached apps"
        case .current: "\(appCount) current apps"
        case let .failed(hasCachedApps):
            hasCachedApps ? "Refresh failed; showing \(appCount) cached apps" : "App refresh failed"
        }
    }

    private static func action(
        label: LocalizedStringResource,
        hint: LocalizedStringResource,
        enabled: Bool,
        inProgress: Bool = false,
        disabledReason: LocalizedStringResource
    ) -> ProductSemanticDescriptor {
        ProductSemanticDescriptor(
            label: label,
            value: inProgress ? "In progress" : (enabled ? "Available" : "Unavailable"),
            hint: hint,
            role: .button,
            eligibility: inProgress
                ? .inProgress
                : (enabled ? .enabled : .disabled(reason: disabledReason))
        )
    }
}

enum ProductStreamSemanticID: String, CaseIterable, Hashable, Sendable {
    case status
    case launch
    case reconnect
    case resume
    case stop
    case showControls
    case hideControls
}

struct ProductStreamSemanticSurface: Equatable, Sendable {
    let items: [ProductSemanticItem<ProductStreamSemanticID>]

    init(
        commands: ProductSessionCommandState,
        controlsVisible: Bool
    ) {
        let controlsEligibility = Self.controlsEligibility(commands)
        items = [
            ProductSemanticItem(
                id: .status,
                descriptor: ProductSemanticDescriptor(
                    label: "Stream status",
                    value: Self.phaseValue(commands.phase),
                    hint: "Shows the current checked streaming session state.",
                    role: .status,
                    eligibility: commands.phase.semanticEligibility
                )
            ),
            ProductSemanticItem(
                id: .launch,
                descriptor: Self.command(
                    label: "Start Stream",
                    hint: "Starts the selected app in this window.",
                    disposition: commands.launch
                )
            ),
            ProductSemanticItem(
                id: .reconnect,
                descriptor: Self.command(
                    label: "Reconnect Stream",
                    hint: "Starts a checked replacement connection.",
                    disposition: commands.reconnect
                )
            ),
            ProductSemanticItem(
                id: .resume,
                descriptor: Self.command(
                    label: "Resume Stream",
                    hint: "Resumes only the current eligible session.",
                    disposition: commands.resume
                )
            ),
            ProductSemanticItem(
                id: .stop,
                descriptor: Self.command(
                    label: "Disconnect",
                    hint: "Requires confirmation before stopping the current stream.",
                    disposition: commands.stop,
                    destructive: true
                )
            ),
            ProductSemanticItem(
                id: .showControls,
                descriptor: Self.control(
                    label: "Show Stream Controls",
                    hint: "Shows local controls without sending remote input.",
                    baseEligibility: controlsEligibility,
                    alreadyInRequestedState: controlsVisible,
                    currentStateReason: "Stream controls are already visible."
                )
            ),
            ProductSemanticItem(
                id: .hideControls,
                descriptor: Self.control(
                    label: "Hide Stream Controls",
                    hint: "Hides local controls without sending remote input.",
                    baseEligibility: controlsEligibility,
                    alreadyInRequestedState: !controlsVisible,
                    currentStateReason: "Stream controls are already hidden."
                )
            )
        ]
    }

    private static func phaseValue(
        _ phase: ProductSessionActualPhase
    ) -> LocalizedStringResource {
        switch phase {
        case .idle: "Idle"
        case .launching: "Launching"
        case .waitingForTransport: "Waiting for stream transport"
        case .streaming: "Streaming"
        case let .reconnecting(attempt):
            attempt.map { "Reconnecting, attempt \($0)" } ?? "Reconnecting"
        case .stopping: "Stopping"
        case .remoteTerminated: "Ended by host"
        case .reconnectExhausted: "Reconnect attempts exhausted"
        case .failed: "Stream failed"
        }
    }

    private static func command(
        label: LocalizedStringResource,
        hint: LocalizedStringResource,
        disposition: ProductSessionCommandDisposition,
        destructive: Bool = false
    ) -> ProductSemanticDescriptor {
        ProductSemanticDescriptor(
            label: label,
            value: disposition.semanticValue,
            hint: hint,
            role: .button,
            eligibility: disposition.semanticEligibility,
            isDestructive: destructive
        )
    }

    private static func controlsEligibility(
        _ commands: ProductSessionCommandState
    ) -> ProductSemanticEligibility {
        switch commands.stop {
        case .available:
            return .enabled
        case .inProgress:
            return .disabled(reason: "Stream controls are unavailable while stopping.")
        case .unavailable(.providersUnavailable):
            switch commands.phase {
            case .launching, .waitingForTransport, .streaming, .reconnecting:
                return .enabled
            case .idle, .stopping, .remoteTerminated, .reconnectExhausted, .failed:
                return .disabled(reason: "No controllable session is active in this window.")
            }
        case let .unavailable(reason):
            return .disabled(reason: reason.semanticValue)
        }
    }

    private static func control(
        label: LocalizedStringResource,
        hint: LocalizedStringResource,
        baseEligibility: ProductSemanticEligibility,
        alreadyInRequestedState: Bool,
        currentStateReason: LocalizedStringResource
    ) -> ProductSemanticDescriptor {
        let eligibility = baseEligibility == .enabled && alreadyInRequestedState
            ? ProductSemanticEligibility.disabled(reason: currentStateReason)
            : baseEligibility
        let value: LocalizedStringResource = switch eligibility {
        case .enabled: "Available"
        case .inProgress: "In progress"
        case let .disabled(reason): reason
        }
        return ProductSemanticDescriptor(
            label: label,
            value: value,
            hint: hint,
            role: .button,
            eligibility: eligibility
        )
    }
}

private extension ProductSessionActualPhase {
    var semanticEligibility: ProductSemanticEligibility {
        switch self {
        case .launching, .waitingForTransport, .reconnecting, .stopping:
            .inProgress
        case .idle, .streaming, .remoteTerminated, .reconnectExhausted, .failed:
            .enabled
        }
    }
}

private extension ProductSessionCommandDisposition {
    var semanticValue: LocalizedStringResource {
        switch self {
        case .available: "Available"
        case .inProgress: "In progress"
        case let .unavailable(reason): reason.semanticValue
        }
    }

    var semanticEligibility: ProductSemanticEligibility {
        switch self {
        case .available: .enabled
        case .inProgress: .inProgress
        case let .unavailable(reason): .disabled(reason: reason.semanticValue)
        }
    }
}

private extension ProductSessionCommandUnavailableReason {
    var semanticValue: LocalizedStringResource {
        switch self {
        case .staleWorkspace: "This window state was replaced"
        case .providersUnavailable: "Required stream services are unavailable"
        case .selectionRequired: "Select a host and app first"
        case .ownedByAnotherWorkspace: "The session belongs to another window"
        case .staleSessionOwner: "The session owner was replaced"
        case .noActiveSession: "No active session"
        case .sessionActive: "A session is already active"
        case .commandInProgress: "Another session command is in progress"
        case .terminalSession: "The previous session has ended"
        case .inconsistentActualState: "Current session state is unavailable"
        }
    }
}

enum ProductSettingsSemanticID: String, CaseIterable, Hashable, Sendable {
    case discovery
    case width
    case height
    case frameRate
    case bitrate
    case hdr
    case scaleMode
    case relativeMouse
    case systemShortcuts
    case virtualController
    case spatialAudio
    case headTracking
    case audioContinuity
    case pictureInPicture
    case reduceBackgroundRendering
    case diagnostics
    case save
}

struct ProductSettingsSemanticSurface: Equatable, Sendable {
    let items: [ProductSemanticItem<ProductSettingsSemanticID>]

    init(settings: AppSettings, saveInProgress: Bool = false) {
        items = [
            Self.toggle(.discovery, "Host discovery", settings.discoveryEnabled,
                        "Controls automatic host discovery."),
            Self.value(.width, "Stream width", "\(settings.stream.width) pixels", .adjustable,
                       "Adjusts the requested stream width."),
            Self.value(.height, "Stream height", "\(settings.stream.height) pixels", .adjustable,
                       "Adjusts the requested stream height."),
            Self.value(.frameRate, "Frame rate", "\(settings.stream.frameRate) frames per second", .adjustable,
                       "Adjusts the requested stream frame rate."),
            Self.value(.bitrate, "Bitrate", "\(settings.stream.bitrateKbps) kilobits per second", .adjustable,
                       "Adjusts the requested stream bitrate."),
            Self.toggle(.hdr, "HDR and EDR", settings.stream.hdrEnabled,
                        "Controls the requested high dynamic range presentation."),
            Self.value(.scaleMode, "Scale mode", Self.scaleValue(settings.stream.scaleMode), .picker,
                       "Chooses whether video fits inside or fills the stream surface."),
            Self.toggle(.relativeMouse, "Prefer relative mouse", settings.input.preferRelativeMouseMode,
                        "Controls relative pointer mode when eligible."),
            ProductSemanticItem(
                id: .systemShortcuts,
                descriptor: ProductSemanticDescriptor(
                    label: "System shortcuts",
                    value: "Always local",
                    hint: "System-reserved shortcuts stay on this device.",
                    role: .status,
                    eligibility: .disabled(
                        reason: "System-reserved shortcuts cannot be forwarded."
                    )
                )
            ),
            Self.toggle(.virtualController, "Virtual controller", settings.input.showVirtualController,
                        "Controls the on-screen virtual controller."),
            Self.toggle(.spatialAudio, "Spatial audio", settings.audio.spatialAudioEnabled,
                        "Controls the requested spatial audio experience."),
            ProductSemanticItem(
                id: .headTracking,
                descriptor: ProductSemanticDescriptor(
                    label: "Head tracking",
                    value: Self.booleanValue(settings.audio.headTrackingEnabled),
                    hint: "Controls listener head tracking when spatial audio is enabled.",
                    role: .toggle,
                    eligibility: settings.audio.spatialAudioEnabled
                        ? .enabled
                        : .disabled(reason: "Enable spatial audio before head tracking.")
                )
            ),
            Self.toggle(.audioContinuity, "Audio continuity", settings.continuity.audioContinuityEnabled,
                        "Controls permitted audio-only background continuity."),
            Self.toggle(.pictureInPicture, "Picture in Picture", settings.continuity.pictureInPictureEnabled,
                        "Controls native Picture in Picture continuity."),
            Self.toggle(.reduceBackgroundRendering, "Reduce background rendering",
                        settings.continuity.reduceRenderingInBackground,
                        "Reduces foreground rendering work while background continuity is active."),
            Self.toggle(.diagnostics, "Diagnostics", settings.diagnosticsEnabled,
                        "Controls collection of privacy-bounded diagnostics."),
            ProductSemanticItem(
                id: .save,
                descriptor: ProductSemanticDescriptor(
                    label: "Save Settings",
                    value: saveInProgress ? "Saving" : "Available",
                    hint: "Persists the current settings for every window.",
                    role: .button,
                    eligibility: saveInProgress ? .inProgress : .enabled
                )
            )
        ]
    }

    private static func toggle(
        _ id: ProductSettingsSemanticID,
        _ label: LocalizedStringResource,
        _ enabled: Bool,
        _ hint: LocalizedStringResource
    ) -> ProductSemanticItem<ProductSettingsSemanticID> {
        ProductSemanticItem(
            id: id,
            descriptor: ProductSemanticDescriptor(
                label: label,
                value: booleanValue(enabled),
                hint: hint,
                role: .toggle
            )
        )
    }

    private static func value(
        _ id: ProductSettingsSemanticID,
        _ label: LocalizedStringResource,
        _ value: LocalizedStringResource,
        _ role: ProductSemanticRole,
        _ hint: LocalizedStringResource
    ) -> ProductSemanticItem<ProductSettingsSemanticID> {
        ProductSemanticItem(
            id: id,
            descriptor: ProductSemanticDescriptor(
                label: label,
                value: value,
                hint: hint,
                role: role
            )
        )
    }

    private static func booleanValue(_ enabled: Bool) -> LocalizedStringResource {
        enabled ? "On" : "Off"
    }

    private static func scaleValue(_ mode: RenderScaleMode) -> LocalizedStringResource {
        switch mode {
        case .fit: "Fit"
        case .fill: "Fill"
        }
    }
}

enum ProductDiagnosticsSemanticID: String, CaseIterable, Hashable, Sendable {
    case status
    case export
}

struct ProductDiagnosticsSemanticSurface: Equatable, Sendable {
    let items: [ProductSemanticItem<ProductDiagnosticsSemanticID>]

    init(eventCount: Int, exportSupported: Bool) {
        let normalizedCount = max(0, eventCount)
        let exportEligibility: ProductSemanticEligibility
        let exportValue: LocalizedStringResource
        if !exportSupported {
            exportEligibility = .disabled(
                reason: "Diagnostics export is unavailable on this platform."
            )
            exportValue = "Unsupported"
        } else if normalizedCount == 0 {
            exportEligibility = .disabled(reason: "There are no diagnostics to export.")
            exportValue = "No diagnostics"
        } else {
            exportEligibility = .enabled
            exportValue = "Available"
        }
        items = [
            ProductSemanticItem(
                id: .status,
                descriptor: ProductSemanticDescriptor(
                    label: "Diagnostics status",
                    value: normalizedCount == 0
                        ? "No diagnostics"
                        : "\(normalizedCount) diagnostic events",
                    hint: "Shows the number of privacy-bounded diagnostic events.",
                    role: .status
                )
            ),
            ProductSemanticItem(
                id: .export,
                descriptor: ProductSemanticDescriptor(
                    label: "Export Diagnostics",
                    value: exportValue,
                    hint: "Shares a local privacy-redacted diagnostics report.",
                    role: .button,
                    eligibility: exportEligibility
                )
            )
        ]
    }

    static func event(
        category: LocalizedStringResource,
        severity: RuntimeDiagnosticSeverity,
        hasAction: Bool
    ) -> ProductSemanticDescriptor {
        ProductSemanticDescriptor(
            label: category,
            value: severity.semanticValue,
            hint: hasAction
                ? "A reviewed recovery action is available."
                : "No recovery action is available for this event.",
            role: .status
        )
    }
}

private extension RuntimeDiagnosticSeverity {
    var semanticValue: LocalizedStringResource {
        switch self {
        case .debug: "Debug"
        case .info: "Information"
        case .warning: "Warning"
        case .error: "Error"
        }
    }
}
