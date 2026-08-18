import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var isShowingAddHost = false
    #if os(macOS)
    @State private var platformLifecycle = PlatformLifecycleState()
    #endif

    var body: some View {
        platformRoot
            .task {
                await appModel.loadInitialState()
            }
            .confirmationDialog(
                "Disconnect Stream?",
                isPresented: stopStreamConfirmationBinding,
                titleVisibility: .visible
            ) {
                Button("Disconnect", role: .destructive) {
                    _ = appModel.beginConfirmedStopStream(
                        in: appModel.primaryWorkspaceReference
                    )
                }
                Button("Cancel", role: .cancel) {
                    _ = appModel.cancelStopStreamConfirmation(
                        in: appModel.primaryWorkspaceReference
                    )
                }
            } message: {
                Text("Remote input and media playback will stop on this device.")
            }
            .sheet(isPresented: $isShowingAddHost) {
                AddHostSheet(workspace: appModel.primaryWorkspaceReference)
            }
    }

    @ViewBuilder
    private var platformRoot: some View {
        #if os(macOS)
        navigationRoot
            .onChange(of: appModel.session.isStreaming, initial: true) { _, isStreaming in
                platformLifecycle.setStreamActive(isStreaming)
                appModel.applyPlatformLifecycle(platformLifecycle)
            }
            .onChange(of: platformLifecycle.revision, initial: true) { _, _ in
                appModel.applyPlatformLifecycle(platformLifecycle)
            }
        #else
        navigationRoot
        #endif
    }

    @ViewBuilder
    private var navigationRoot: some View {
        #if os(iOS)
        if horizontalSizeClass == .compact {
            compactNavigation
        } else {
            splitNavigation
        }
        #else
        splitNavigation
        #endif
    }

    private var splitNavigation: some View {
        @Bindable var appModel = appModel

        return NavigationSplitView {
            SidebarNavigationList(selection: $appModel.navigationSelection)
                .navigationTitle("LuneX")
                #if os(macOS)
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
                #endif
        } detail: {
            content
                .navigationTitle(title)
                .toolbar {
                    ToolbarItemGroup {
                        Button {
                            presentAddHost()
                        } label: {
                            Label("Add Host", systemImage: "plus")
                        }

                        Button {
                            _ = appModel.requestStopStreamConfirmation(
                                in: appModel.primaryWorkspaceReference
                            )
                        } label: {
                            Label("Disconnect", systemImage: "stop.fill")
                        }
                        .disabled(appModel.session.phase == .disconnected)
                    }
                }
        }
    }

    #if os(iOS)
    private var compactNavigation: some View {
        @Bindable var appModel = appModel

        return TabView(selection: $appModel.navigationSelection) {
            NavigationStack {
                LibraryDashboardView(onAddHost: presentAddHost)
                    .navigationTitle("Library")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                presentAddHost()
                            } label: {
                                Label("Add Host", systemImage: "plus")
                            }
                        }
                    }
            }
            .tabItem {
                Label("Library", systemImage: "rectangle.grid.2x2")
            }
            .tag(AppNavigationSelection.library)

            NavigationStack {
                StreamWorkspaceView(
                    workspace: appModel.primaryWorkspaceReference
                )
                    .navigationTitle("Stream")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                _ = appModel.requestStopStreamConfirmation(
                                    in: appModel.primaryWorkspaceReference
                                )
                            } label: {
                                Label("Disconnect", systemImage: "stop.fill")
                            }
                            .disabled(appModel.session.phase == .disconnected)
                        }
                    }
            }
            .tabItem {
                Label("Stream", systemImage: "play.rectangle")
            }
            .tag(AppNavigationSelection.stream)

            NavigationStack {
                DiagnosticsView()
                    .navigationTitle("Diagnostics")
            }
            .tabItem {
                Label("Diagnostics", systemImage: "waveform.path.ecg")
            }
            .tag(AppNavigationSelection.diagnostics)

            NavigationStack {
                SettingsView()
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "slider.horizontal.3")
            }
            .tag(AppNavigationSelection.settings)
        }
    }
    #endif

    @ViewBuilder
    private var content: some View {
        switch appModel.navigationSelection {
        case .library:
            LibraryDashboardView(onAddHost: presentAddHost)
        case .stream:
            #if os(macOS)
            StreamWorkspaceView(
                workspace: appModel.primaryWorkspaceReference,
                platformLifecycle: platformLifecycle
            )
            #else
            StreamWorkspaceView(
                workspace: appModel.primaryWorkspaceReference
            )
            #endif
        case .diagnostics:
            DiagnosticsView()
        case .settings:
            SettingsView()
        }
    }

    private var title: String {
        switch appModel.navigationSelection {
        case .library: "Library"
        case .stream: "Stream"
        case .diagnostics: "Diagnostics"
        case .settings: "Settings"
        }
    }

    private func presentAddHost() {
        appModel.setManualHostDraft(
            ManualHostDraft(),
            in: appModel.primaryWorkspaceReference
        )
        isShowingAddHost = true
    }

    private var stopStreamConfirmationBinding: Binding<Bool> {
        Binding(
            get: {
                appModel.stopStreamConfirmationSessionID(
                    in: appModel.primaryWorkspaceReference
                ) != nil
            },
            set: { isPresented in
                if !isPresented {
                    _ = appModel.cancelStopStreamConfirmation(
                        in: appModel.primaryWorkspaceReference
                    )
                }
            }
        )
    }
}

private struct SidebarNavigationList: View {
    @Binding var selection: AppNavigationSelection

    var body: some View {
        #if os(macOS)
        List(selection: $selection) {
            navigationRows
        }
        #else
        List {
            Button {
                selection = .library
            } label: {
                NavigationRow(label: "Library", systemImage: "rectangle.grid.2x2", isSelected: selection == .library)
            }
            Button {
                selection = .stream
            } label: {
                NavigationRow(label: "Stream", systemImage: "play.rectangle", isSelected: selection == .stream)
            }
            Button {
                selection = .diagnostics
            } label: {
                NavigationRow(label: "Diagnostics", systemImage: "waveform.path.ecg", isSelected: selection == .diagnostics)
            }
            Button {
                selection = .settings
            } label: {
                NavigationRow(label: "Settings", systemImage: "slider.horizontal.3", isSelected: selection == .settings)
            }
        }
        #endif
    }

    @ViewBuilder
    private var navigationRows: some View {
        Label("Library", systemImage: "rectangle.grid.2x2")
            .tag(AppNavigationSelection.library)
        Label("Stream", systemImage: "play.rectangle")
            .tag(AppNavigationSelection.stream)
        Label("Diagnostics", systemImage: "waveform.path.ecg")
            .tag(AppNavigationSelection.diagnostics)
        Label("Settings", systemImage: "slider.horizontal.3")
            .tag(AppNavigationSelection.settings)
    }
}

private struct NavigationRow: View {
    let label: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        Label(label, systemImage: systemImage)
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AddHostSheet: View {
    private enum Field: Hashable {
        case name
        case address
    }

    @Environment(AppModel.self) private var appModel
    @Environment(\.dismiss) private var dismiss
    @FocusState private var focusedField: Field?
    let workspace: ProductWorkspaceReference

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: nameBinding)
                        .focused($focusedField, equals: .name)
                        .disabled(isSubmitting)

                    TextField("Address", text: addressBinding)
                        .focused($focusedField, equals: .address)
                        .disabled(isSubmitting)
                    #if os(iOS)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                    #endif
                } footer: {
                    if let issue = submission.fieldIssue {
                        Label {
                            Text(issue.presentation.message)
                        } icon: {
                            Image(systemName: issue.presentation.systemImage)
                        }
                        .foregroundStyle(issue.severity == .error ? Color.red : Color.orange)
                    } else if isSubmitting {
                        ProgressView("Adding host...")
                    }
                }
            }
            .navigationTitle("Add Host")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        clearDraft()
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            let result = await appModel.addManualHost(in: workspace)
                            if result.shouldDismissSheet {
                                dismiss()
                            } else if result.fieldIssue != nil {
                                focusedField = .address
                            }
                        }
                    }
                    .disabled(isSubmitting)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
            .onDisappear {
                guard !isSubmitting else { return }
                clearDraft()
            }
            #if os(macOS)
            .frame(
                minWidth: 380,
                idealWidth: 420,
                maxWidth: 480,
                minHeight: 240,
                idealHeight: 260
            )
            #endif
        }
    }

    private var draft: ManualHostDraft {
        appModel.workspaceState(for: workspace)?.hostLibrary.manualHostDraft
            ?? ManualHostDraft()
    }

    private var submission: ManualHostSubmissionState {
        appModel.workspaceState(for: workspace)?.hostLibrary.manualHostSubmission
            ?? .idle
    }

    private var isSubmitting: Bool { submission.isSubmitting }

    private var nameBinding: Binding<String> {
        Binding(
            get: { draft.name },
            set: { name in
                appModel.setManualHostDraft(
                    ManualHostDraft(name: name, address: draft.address),
                    in: workspace
                )
            }
        )
    }

    private var addressBinding: Binding<String> {
        Binding(
            get: { draft.address },
            set: { address in
                appModel.setManualHostDraft(
                    ManualHostDraft(name: draft.name, address: address),
                    in: workspace
                )
            }
        )
    }

    private func clearDraft() {
        appModel.setManualHostDraft(ManualHostDraft(), in: workspace)
    }
}

private struct LibraryDashboardView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    let onAddHost: () -> Void

    var body: some View {
        @Bindable var appModel = appModel

        ScrollView {
            #if os(iOS)
            if horizontalSizeClass == .compact {
                LazyVStack(alignment: .leading, spacing: 16) {
                    HostLibraryPanel(
                        selectedHostID: $appModel.selectedHostID,
                        onAddHost: onAddHost
                    )
                    AppCatalogPanel()
                    PairingPanel()
                    StreamLaunchPanel()
                }
                .padding(.horizontal)
                .padding(.top)
                .padding(.bottom, 96)
            } else {
                dashboardGrid(selectedHostID: $appModel.selectedHostID)
            }
            #else
            dashboardGrid(selectedHostID: $appModel.selectedHostID)
            #endif
        }
    }

    private func dashboardGrid(selectedHostID: Binding<MoonlightHost.ID?>) -> some View {
        Grid(alignment: .topLeading, horizontalSpacing: 16, verticalSpacing: 16) {
            GridRow {
                HostLibraryPanel(
                    selectedHostID: selectedHostID,
                    onAddHost: onAddHost
                )
                AppCatalogPanel()
            }
            GridRow {
                PairingPanel()
                StreamLaunchPanel()
            }
        }
        .padding()
    }
}

private struct HostLibraryPanel: View {
    @Environment(AppModel.self) private var appModel
    @Binding var selectedHostID: MoonlightHost.ID?
    let onAddHost: () -> Void

    var body: some View {
        let workspace = appModel.primaryWorkspaceReference
        let library = appModel.workspaceState(for: workspace)?.hostLibrary
            ?? ProductHostLibraryWorkspaceState()
        let surface = ProductHostLibrarySurface(
            library: library,
            hostCount: appModel.hosts.count,
            selectedHost: appModel.selectedHost
        )

        Panel {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(title: "Hosts", systemImage: "desktopcomputer")

                switch surface.content {
                case .loading:
                    ProgressView("Loading hosts...")
                        .frame(maxWidth: .infinity, minHeight: 180)
                case .firstUse:
                    ContentUnavailableView(
                        "No Hosts",
                        systemImage: "desktopcomputer",
                        description: Text("Refresh discovery or add a host manually.")
                    )
                    .frame(minHeight: 180)
                case .failed:
                    hostLibraryFailure(library.refreshIssue)
                case .hosts:
                    List(selection: $selectedHostID) {
                        ForEach(appModel.hosts) { host in
                            HostRow(host: host)
                                .tag(host.id)
                                .contentShape(Rectangle())
                        }
                    }
                    .frame(minHeight: 240)
                }

                HStack {
                    Button(action: onAddHost) {
                        Label("Add Host", systemImage: "plus")
                    }
                    .disabled(!surface.canAddHost)

                    Button {
                        Task {
                            await appModel.loadHosts(in: workspace)
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .disabled(!surface.canRefresh)

                    Button {
                        appModel.requestHostTrustReset(in: workspace)
                    } label: {
                        Label("Reset Trust", systemImage: "checkmark.shield")
                    }
                    .disabled(!surface.canResetTrust)

                    Button(role: .destructive) {
                        appModel.requestHostRemoval(in: workspace)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .disabled(!surface.canRemove)
                }

                if surface.content == .hosts,
                   let issue = surface.refreshIssue {
                    productIssueLabel(issue)
                    if issue.action?.kind == .refreshHosts {
                        Button {
                            Task {
                                await appModel.retryHostLibraryLoad(in: workspace)
                            }
                        } label: {
                            Label("Retry Host Refresh", systemImage: "arrow.clockwise")
                        }
                    }
                }

                destructiveStatus(surface.destructive, workspace: workspace)
            }
        }
        .confirmationDialog(
            "Confirm Host Action",
            isPresented: hostConfirmationPresented,
            titleVisibility: .visible
        ) {
            if let confirmation = currentHostConfirmation {
                Button(
                    destructiveActionLabel(confirmation),
                    role: .destructive
                ) {
                    guard let admitted = appModel.beginHostDestructiveAction(
                        in: workspace
                    ) else { return }
                    Task {
                        await appModel.performHostDestructiveAction(admitted)
                    }
                }
            }
            Button("Cancel", role: .cancel) {
                appModel.cancelHostDestructiveAction(in: workspace)
            }
        } message: {
            if let confirmation = currentHostConfirmation {
                Text(destructiveActionMessage(confirmation))
            }
        }
    }

    @ViewBuilder
    private func hostLibraryFailure(_ issue: ProductIssue?) -> some View {
        if let issue {
            ContentUnavailableView {
                Label {
                    Text(issue.presentation.title)
                } icon: {
                    Image(systemName: issue.presentation.systemImage)
                }
            } description: {
                Text(issue.presentation.message)
            } actions: {
                if issue.action?.kind == .refreshHosts {
                    Button {
                        Task {
                            await appModel.retryHostLibraryLoad(
                                in: appModel.primaryWorkspaceReference
                            )
                        }
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                }
            }
            .frame(minHeight: 180)
        } else {
            ContentUnavailableView(
                "Hosts Not Loaded",
                systemImage: "desktopcomputer.trianglebadge.exclamationmark",
                description: Text("Try refreshing the host library again.")
            )
            .frame(minHeight: 180)
        }
    }

    @ViewBuilder
    private func destructiveStatus(
        _ destructive: ProductHostDestructiveSurface,
        workspace: ProductWorkspaceReference
    ) -> some View {
        switch destructive {
        case .idle, .awaitingConfirmation:
            EmptyView()
        case let .performing(kind):
            ProgressView(
                kind == .remove ? "Removing host..." : "Resetting trust..."
            )
            .controlSize(.small)
        case let .failed(issue):
            productIssueLabel(issue)
            if issue.action != nil {
                Button {
                    appModel.retryHostDestructiveAction(in: workspace)
                } label: {
                    Label("Retry Host Action", systemImage: "arrow.clockwise")
                }
            }
        case let .completed(kind):
            Label(
                kind == .remove ? "Host removed" : "Trust reset",
                systemImage: "checkmark.circle"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private func productIssueLabel(_ issue: ProductIssue) -> some View {
        Label {
            Text(issue.presentation.message)
        } icon: {
            Image(systemName: issue.presentation.systemImage)
        }
        .font(.caption)
        .foregroundStyle(issue.severity == .error ? Color.red : Color.orange)
    }

    private var currentHostConfirmation: ProductHostDestructiveConfirmation? {
        guard case let .awaitingConfirmation(confirmation) =
            appModel.hostDestructiveState(
                for: appModel.primaryWorkspaceReference
            ) else { return nil }
        return confirmation
    }

    private var hostConfirmationPresented: Binding<Bool> {
        Binding(
            get: { currentHostConfirmation != nil },
            set: { isPresented in
                guard !isPresented,
                      appModel.hostDestructiveState(
                        for: appModel.primaryWorkspaceReference
                      )?.isPerforming != true else { return }
                appModel.cancelHostDestructiveAction(
                    in: appModel.primaryWorkspaceReference
                )
            }
        )
    }

    private func destructiveActionLabel(
        _ confirmation: ProductHostDestructiveConfirmation
    ) -> String {
        switch (confirmation.kind, confirmation.requiresSessionStop) {
        case (.remove, true):
            "Stop and Remove"
        case (.remove, false):
            "Remove Host"
        case (.resetTrust, true):
            "Stop and Reset Trust"
        case (.resetTrust, false):
            "Reset Trust"
        }
    }

    private func destructiveActionMessage(
        _ confirmation: ProductHostDestructiveConfirmation
    ) -> String {
        switch confirmation.kind {
        case .remove:
            confirmation.requiresSessionStop
                ? "The active stream will stop before this host, saved trust, and cached apps are removed."
                : "This removes the host, saved trust, and cached apps from this device."
        case .resetTrust:
            confirmation.requiresSessionStop
                ? "The active stream will stop before saved trust is cleared. The host remains in the library."
                : "Saved trust will be cleared. The host remains in the library."
        }
    }
}

private struct HostRow: View {
    let host: MoonlightHost

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: host.pairingState == .paired ? "checkmark.seal.fill" : "lock")
                .foregroundStyle(host.pairingState == .paired ? .green : .secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(host.name)
                    .font(.headline)
                Text(host.address.isEmpty ? "No address" : host.address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(host.reachability.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(host.pairingState.rawValue.capitalized)
                    .font(.caption2)
                    .foregroundStyle(host.pairingState == .paired ? .green : .secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct PairingPanel: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let workspace = appModel.primaryWorkspaceReference
        let pairing = appModel.pairingState(for: workspace) ?? PairingUIState()
        let surface = ProductPairingSurface(
            selectedHost: appModel.selectedHost,
            pairing: pairing,
            transportAvailable: appModel.isPairingTransportAvailable,
            isPINValid: appModel.isPairingPINValid(in: workspace)
        )

        Panel {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(title: "Pairing", systemImage: "key")

                if let host = appModel.selectedHost {
                    Text(host.name)
                        .font(.headline)
                    pairingContent(
                        surface,
                        host: host,
                        workspace: workspace
                    )
                } else {
                    ContentUnavailableView("Select a Host", systemImage: "key")
                }
            }
        }
    }

    @ViewBuilder
    private func pairingContent(
        _ surface: ProductPairingSurface,
        host: MoonlightHost,
        workspace: ProductWorkspaceReference
    ) -> some View {
        switch surface.phase {
        case .noHost:
            ContentUnavailableView("Select a Host", systemImage: "key")
        case .ready:
            Label("Ready to pair", systemImage: "lock.open")
                .foregroundStyle(.secondary)
            startPairingButton(host: host, workspace: workspace)
        case .unavailable:
            if let issue = surface.issue {
                issueLabel(issue)
            } else {
                Label(
                    "Authenticated pairing transport unavailable",
                    systemImage: "exclamationmark.shield"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        case .preparing:
            pairingProgress("Preparing secure pairing...", surface: surface, workspace: workspace)
        case .waitingForPIN:
            Label("Enter the four-digit PIN shown by the host.", systemImage: "number.square")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                TextField("PIN", text: pairingPINBinding(workspace: workspace))
                    #if os(iOS)
                    .keyboardType(.numberPad)
                    #endif
                    #if !os(tvOS)
                    .textFieldStyle(.roundedBorder)
                    #endif
                    .frame(maxWidth: 120)

                Button {
                    Task {
                        await appModel.submitPairingPIN(in: workspace)
                    }
                } label: {
                    Label("Submit PIN", systemImage: "checkmark")
                }
                .disabled(!surface.canSubmitPIN)

                cancelPairingButton(workspace: workspace)
                    .disabled(!surface.canCancel)
            }
            if let issue = surface.issue {
                issueLabel(issue)
            }
        case .exchangingSecrets:
            pairingProgress("Exchanging pairing secrets...", surface: surface, workspace: workspace)
        case .verifyingServer:
            pairingProgress("Verifying host identity...", surface: surface, workspace: workspace)
        case .savingIdentity:
            pairingProgress("Saving verified identity...", surface: surface, workspace: workspace)
        case .completed:
            Label("Pairing complete", systemImage: "checkmark.shield")
                .font(.caption)
            Text("The verified host identity is saved on this device.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .cancelled:
            if let issue = surface.issue {
                issueLabel(issue)
            } else {
                Label("Pairing cancelled", systemImage: "xmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if surface.canStart {
                startPairingButton(host: host, workspace: workspace)
            }
        case .failed:
            if let issue = surface.issue {
                issueLabel(issue)
            } else {
                Label(
                    "Pairing failed",
                    systemImage: "lock.trianglebadge.exclamationmark"
                )
                .font(.caption)
                .foregroundStyle(.orange)
            }
            if surface.canRetry {
                Button {
                    Task {
                        await appModel.retryPairing(in: workspace)
                    }
                } label: {
                    Label("Retry Pairing", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    private func pairingPINBinding(
        workspace: ProductWorkspaceReference
    ) -> Binding<String> {
        Binding(
            get: { appModel.pairingState(for: workspace)?.pin ?? "" },
            set: { appModel.updatePairingPIN($0, in: workspace) }
        )
    }

    private func startPairingButton(
        host: MoonlightHost,
        workspace: ProductWorkspaceReference
    ) -> some View {
        Button {
            Task {
                await appModel.beginPairing(host: host, in: workspace)
            }
        } label: {
            Label("Start Pairing", systemImage: "lock.open")
        }
    }

    private func cancelPairingButton(
        workspace: ProductWorkspaceReference
    ) -> some View {
        Button {
            Task {
                await appModel.cancelPairing(in: workspace)
            }
        } label: {
            Label("Cancel", systemImage: "xmark")
        }
    }

    private func pairingProgress(
        _ title: LocalizedStringKey,
        surface: ProductPairingSurface,
        workspace: ProductWorkspaceReference
    ) -> some View {
        HStack(spacing: 12) {
            ProgressView(title)
                .controlSize(.small)
            cancelPairingButton(workspace: workspace)
                .disabled(!surface.canCancel)
        }
    }

    private func issueLabel(_ issue: ProductIssue) -> some View {
        Label {
            Text(issue.presentation.message)
        } icon: {
            Image(systemName: issue.presentation.systemImage)
        }
        .font(.caption)
        .foregroundStyle(issue.severity == .error ? Color.red : Color.orange)
    }
}

private struct AppCatalogPanel: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let workspace = appModel.primaryWorkspaceReference
        let catalog = appModel.catalogState(for: workspace)
            ?? ProductAppCatalogWorkspaceState()
        let surface = ProductAppCatalogSurface(
            catalog: catalog,
            selectedHost: appModel.selectedHost,
            appCount: appModel.selectedApps.count
        )

        Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelHeader(title: "Apps", systemImage: "square.grid.3x3")
                    Spacer()
                    Button {
                        Task {
                            await appModel.refreshAppsForSelectedHost(in: workspace)
                        }
                    } label: {
                        Label("Refresh Apps", systemImage: "arrow.down.circle")
                    }
                    .disabled(!surface.canRefresh)
                }

                if surface.showsApps {
                    appGrid(workspace: workspace)
                } else {
                    emptyCatalogContent(surface, workspace: workspace)
                }

                catalogStatus(surface, workspace: workspace)

                if let date = catalog.updatedAt {
                    Text("Updated \(date.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func emptyCatalogContent(
        _ surface: ProductAppCatalogSurface,
        workspace: ProductWorkspaceReference
    ) -> some View {
        switch surface.content {
        case .unavailable:
            ContentUnavailableView("Select a Host", systemImage: "square.grid.3x3")
                .frame(minHeight: 240)
        case .requiresPairing:
            ContentUnavailableView(
                "Pairing Required",
                systemImage: "lock",
                description: Text("Pair this host before loading its apps.")
            )
            .frame(minHeight: 240)
        case .idle:
            ContentUnavailableView(
                "Apps Not Loaded",
                systemImage: "square.grid.3x3",
                description: Text("Refresh this host to load its apps.")
            )
            .frame(minHeight: 240)
        case .loading, .loadingCached:
            ProgressView("Loading apps...")
                .frame(maxWidth: .infinity, minHeight: 240)
        case let .empty(source):
            ContentUnavailableView(
                source == .current ? "No Apps" : "No Saved Apps",
                systemImage: "square.grid.3x3",
                description: Text(
                    source == .current
                        ? "The host returned an empty app list."
                        : "Refresh this host to load its apps."
                )
            )
            .frame(minHeight: 240)
        case .failed:
            if let issue = surface.issue {
                ContentUnavailableView {
                    Label {
                        Text(issue.presentation.title)
                    } icon: {
                        Image(systemName: issue.presentation.systemImage)
                    }
                } description: {
                    Text(issue.presentation.message)
                } actions: {
                    if surface.canRetry {
                        Button {
                            Task {
                                await appModel.retryAppCatalog(in: workspace)
                            }
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                    }
                }
                .frame(minHeight: 240)
            } else {
                ContentUnavailableView(
                    "Apps Not Updated",
                    systemImage: "square.grid.3x3",
                    description: Text("Try refreshing the app catalog again.")
                )
                .frame(minHeight: 240)
            }
        case .cached, .current:
            EmptyView()
        }
    }

    @ViewBuilder
    private func catalogStatus(
        _ surface: ProductAppCatalogSurface,
        workspace: ProductWorkspaceReference
    ) -> some View {
        switch surface.content {
        case .loadingCached:
            ProgressView("Updating apps...")
                .controlSize(.small)
        case .cached:
            Label("Saved app list", systemImage: "clock.arrow.circlepath")
                .foregroundStyle(.secondary)
        case .current:
            Label("Current app list", systemImage: "checkmark.circle")
                .foregroundStyle(.secondary)
        case .requiresPairing(hasCachedApps: true):
            Label("Saved apps require pairing", systemImage: "lock")
                .foregroundStyle(.secondary)
        case .failed(hasCachedApps: true):
            if let issue = surface.issue {
                issueLabel(issue)
            }
            if surface.canRetry {
                Button {
                    Task {
                        await appModel.retryAppCatalog(in: workspace)
                    }
                } label: {
                    Label("Retry App Refresh", systemImage: "arrow.clockwise")
                }
            }
        default:
            EmptyView()
        }
    }

    private func appGrid(
        workspace: ProductWorkspaceReference
    ) -> some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 150), spacing: 12)],
            spacing: 12
        ) {
            ForEach(appModel.selectedApps) { app in
                Button {
                    appModel.select(app: app, in: workspace)
                } label: {
                    RemoteAppTile(
                        app: app,
                        isSelected: appModel.selectedAppID == app.id
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(minHeight: 240, alignment: .top)
    }

    private func issueLabel(_ issue: ProductIssue) -> some View {
        Label {
            Text(issue.presentation.message)
        } icon: {
            Image(systemName: issue.presentation.systemImage)
        }
        .font(.caption)
        .foregroundStyle(issue.severity == .error ? Color.red : Color.orange)
    }
}

private struct RemoteAppTile: View {
    let app: RemoteApp
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                    .aspectRatio(16.0 / 9.0, contentMode: .fit)
                Image(systemName: app.supportsHDR ? "sparkles.tv" : "app")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            Text(app.name)
                .font(.headline)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
            if app.supportsHDR {
                Label("HDR", systemImage: "sun.max")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .background(isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        }
    }
}

private struct StreamLaunchPanel: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        let workspace = appModel.primaryWorkspaceReference
        let commands = appModel.sessionCommandState(in: workspace)
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(title: "Launch", systemImage: "play.fill")

                if let host = appModel.selectedHost, let app = appModel.selectedApp {
                    LabeledContent("Host", value: host.name)
                    LabeledContent("App", value: app.name)
                    LabeledContent("Mode", value: "\(appModel.settings.stream.width)x\(appModel.settings.stream.height)x\(appModel.settings.stream.frameRate)")
                    LabeledContent("Bitrate", value: "\(appModel.settings.stream.bitrateKbps / 1000) Mbps")
                    LabeledContent("HDR", value: appModel.settings.stream.hdrEnabled && app.supportsHDR ? "Requested" : "Off")

                    if appModel.isStreamTransportAvailable {
                        if appModel.hasActiveStreamSession {
                            Button(role: .destructive) {
                                _ = appModel.requestStopStreamConfirmation(
                                    in: workspace
                                )
                            } label: {
                                Label("Stop Stream", systemImage: "stop.circle")
                            }
                            .disabled(commands.stop != .available)
                        } else {
                            Button {
                                Task {
                                    await appModel.launchSelectedApp(in: workspace)
                                }
                            } label: {
                                Label(
                                    appModel.streamLaunchUI.isLaunching ? "Launching" : "Launch Stream",
                                    systemImage: "play.circle.fill"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(commands.launch != .available || host.pairingState != .paired)
                        }
                    } else {
                        Label("Moonlight media transport unavailable", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                } else {
                    ContentUnavailableView("Select an App", systemImage: "play.fill")
                }

                if let issue = appModel.streamProductIssue(in: workspace) {
                    Label {
                        Text(issue.presentation.message)
                    } icon: {
                        Image(systemName: issue.presentation.systemImage)
                    }
                    .font(.caption)
                    .foregroundStyle(
                        issue.severity == .error ? Color.red : Color.orange
                    )
                    if let action = issue.action {
                        Button {
                            Task {
                                await appModel.performProductAction(action)
                            }
                        } label: {
                            Label {
                                Text(action.kind.title)
                            } icon: {
                                Image(systemName: "arrow.forward.circle")
                            }
                        }
                        .disabled(!appModel.canPerformProductAction(action))
                    }
                }
            }
        }
    }
}

private struct StreamWorkspaceView: View {
    @Environment(AppModel.self) private var appModel
    let workspace: ProductWorkspaceReference
    #if os(macOS)
    let platformLifecycle: PlatformLifecycleState
    #endif
    #if os(tvOS)
    @FocusState private var isTVStreamSurfaceFocused: Bool
    #endif

    var body: some View {
        ZStack(alignment: .topLeading) {
            #if os(macOS)
            MetalStreamSurface(
                renderState: appModel.renderState,
                presentationSource: appModel.videoPresentationSource,
                lifecycle: platformLifecycle,
                inputPolicy: appModel.macInputSurfacePolicy,
                inputSampleHandler: { sample in
                    _ = appModel.submitMacPlatformInput(
                        sample,
                        in: workspace
                    )
                },
                captureExitHandler: {
                    appModel.exitMacRelativePointerCapture(in: workspace)
                },
                diagnosticLease: hdrPresentationDiagnosticLease
            )
                .ignoresSafeArea()
            #elseif os(iOS)
            MetalStreamSurface(
                renderState: appModel.renderState,
                presentationSource: appModel.videoPresentationSource,
                userAllowsHDR: appModel.settings.stream.hdrEnabled,
                diagnosticLease: hdrPresentationDiagnosticLease,
                attachmentUpdateHandler: { update in
                    appModel.receiveMobileSurfaceAttachment(
                        surfaceGeneration: update.surfaceGeneration,
                        isAttached: update.attachment != nil
                    )
                },
                sceneLifecycleUpdateHandler: { update in
                    appModel.receiveMobileSceneLifecycle(update)
                },
                sceneWindowSnapshotHandler: { snapshot in
                    appModel.receiveMobileSceneWindowSnapshot(snapshot)
                },
                displayEDREventHandler: { event in
                    appModel.receiveMobileDisplayEDREvent(event)
                }
            )
                .ignoresSafeArea()
            #elseif os(tvOS)
            MetalStreamSurface(
                renderState: appModel.renderState,
                presentationSource: appModel.videoPresentationSource,
                userAllowsHDR: appModel.settings.stream.hdrEnabled,
                diagnosticLease: hdrPresentationDiagnosticLease,
                platformPresentationOwner:
                    appModel.tvVisionMetalPresentationOwner,
                geometryBindingUpdateHandler: { update in
                    appModel.receiveTVVisionGeometryUpdate(update)
                },
                displayHDREventHandler: { event in
                    appModel.receiveTVOSDisplayHDREvent(event)
                },
                remotePressEventHandler: { event in
                    appModel.receiveTVRemoteSurfacePressEvent(
                        event,
                        in: workspace
                    )
                },
                reservedRemoteCommandHandler: { command in
                    appModel.receiveTVRemoteReservedCommand(
                        command,
                        in: workspace
                    )
                }
            )
                .ignoresSafeArea()
                .focusable()
                .focused($isTVStreamSurfaceFocused)
            #else
            MetalStreamSurface(
                renderState: appModel.renderState,
                presentationSource: appModel.videoPresentationSource,
                userAllowsHDR: appModel.settings.stream.hdrEnabled,
                diagnosticLease: hdrPresentationDiagnosticLease,
                platformPresentationOwner:
                    appModel.tvVisionMetalPresentationOwner,
                visionInputCaptureEnabled:
                    appModel.visionInputCaptureEnabled(in: workspace),
                geometryBindingUpdateHandler: { update in
                    appModel.receiveTVVisionGeometryUpdate(update)
                },
                displayHDREventHandler: { event in
                    appModel.receiveTVVisionDisplayHDREvent(event)
                },
                visionSurfaceInputEventHandler: { event in
                    appModel.receiveVisionSurfaceInputEvent(
                        event,
                        in: workspace
                    )
                },
                visionSystemInteractionEventHandler: { event in
                    appModel.receiveVisionSystemInteractionEvent(
                        event,
                        in: workspace
                    )
                }
            )
                .ignoresSafeArea()
            #endif

            if appModel.streamOverlayVisibility(in: workspace) == .visible {
                StreamStatusOverlay(workspace: workspace)
                    .padding(16)
            } else if appModel.hasActiveStreamSession {
                #if !os(tvOS)
                Button {
                    _ = appModel.setStreamOverlayVisibility(
                        .visible,
                        in: workspace
                    )
                } label: {
                    Image(systemName: "eye")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Show Stream Controls")
                .padding(16)
                #endif
            }

            if appModel.settings.input.showVirtualController && appModel.session.isStreaming {
                VirtualControllerOverlay()
                    .padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .background(Color.black)
        #if os(tvOS)
        .onAppear {
            appModel.setTVStreamWorkspaceVisible(true, in: workspace)
            isTVStreamSurfaceFocused =
                appModel.streamOverlayVisibility(in: workspace) == .hidden
        }
        .onDisappear {
            appModel.setTVStreamWorkspaceVisible(false, in: workspace)
            isTVStreamSurfaceFocused = false
        }
        .onChange(
            of: appModel.streamOverlayVisibility(in: workspace),
            initial: true
        ) { _, visibility in
            isTVStreamSurfaceFocused = visibility == .hidden
        }
        #endif
    }

    private var hdrPresentationDiagnosticLease: HDRPresentationDiagnosticLease {
        HDRPresentationDiagnosticLease(
            claim: { ownerID in
                appModel.claimHDRPresentationDiagnosticOwnership(ownerID)
            },
            publish: { ownerID, state in
                appModel.publishHDRPresentationDiagnostic(
                    state,
                    ownerID: ownerID
                )
            },
            release: { ownerID in
                appModel.releaseHDRPresentationDiagnosticOwnership(ownerID)
            }
        )
    }
}

private struct StreamStatusOverlay: View {
    @Environment(AppModel.self) private var appModel
    let workspace: ProductWorkspaceReference

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            #if os(tvOS)
            TVStreamControls(workspace: workspace)
            #elseif os(visionOS)
            VisionStreamControls(workspace: workspace)
            #else
            HStack(spacing: 10) {
                Label(appModel.session.phase.label, systemImage: appModel.session.isStreaming ? "dot.radiowaves.left.and.right" : "moon")
                    .font(.headline)
                #if os(iOS)
                MobilePictureInPictureCommandButton()
                #endif
                Button {
                    _ = appModel.setStreamOverlayVisibility(
                        .hidden,
                        in: workspace
                    )
                } label: {
                    Label("Hide Controls", systemImage: "eye.slash")
                }
                Button {
                    _ = appModel.requestStopStreamConfirmation(in: workspace)
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
                .disabled(appModel.session.phase == .disconnected)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    statusPills
                }
                VStack(alignment: .leading, spacing: 6) {
                    statusPills
                }
            }

            Text(
                appModel.diagnostics.latestStreamActionableEvent?.message
                    ?? appModel.diagnostics.latestSummary
            )
                .font(.caption)
                .foregroundStyle(.secondary)
            #endif
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusPills: some View {
        let spatialContent = appModel.spatialAudioPresentationStatus.content

        #if os(iOS)
        let mobileStatus = appModel.mobileExperiencePresentationStatus
        MobileActualStatusPill(
            content: mobileSceneStatusContent(mobileStatus.scene)
        )
        MobileActualStatusPill(
            content: mobilePictureInPictureStatusContent(
                mobileStatus.pictureInPicture
            )
        )
        MobileActualStatusPill(
            content: mobileContinuityStatusContent(mobileStatus.continuity)
        )
        MobileActualStatusPill(
            content: mobileDisplayStatusContent(mobileStatus.display)
        )
        #else
        let hdrContent = appModel.hdrPresentationStatus.content
        StatusPill(
            label: appModel.settings.input.preferRelativeMouseMode
                ? "Relative mouse"
                : "Direct pointer",
            systemImage: "cursorarrow.motionlines"
        )
        StatusPill(
            label: hdrContent.overlayLabel,
            systemImage: hdrContent.systemImage
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("HDR presentation")
        .accessibilityValue(hdrContent.accessibilityValue)
        #endif
        StatusPill(
            label: spatialContent.overlayLabel,
            systemImage: spatialContent.systemImage
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Spatial audio presentation")
        .accessibilityValue(spatialAudioAccessibilityValue(spatialContent))
    }
}

#if os(tvOS)
private enum TVStreamControlFocusTarget: Hashable {
    case hideControls
    case disconnect
}

private struct TVStreamControls: View {
    @Environment(AppModel.self) private var appModel
    let workspace: ProductWorkspaceReference
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @FocusState private var focusedControl: TVStreamControlFocusTarget?

    var body: some View {
        let state = appModel.tvStreamControlPresentationState(in: workspace)

        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 14) {
                Label(
                    appModel.session.phase.label,
                    systemImage: appModel.session.isStreaming
                        ? "dot.radiowaves.left.and.right"
                        : "moon"
                )
                    .font(.headline)

                Spacer(minLength: 28)

                Button {
                    _ = appModel.setStreamOverlayVisibility(
                        .hidden,
                        in: workspace
                    )
                } label: {
                    Label("Hide Controls", systemImage: "eye.slash")
                }
                .focused($focusedControl, equals: .hideControls)
                .accessibilitySortPriority(2)

                Button(role: .destructive) {
                    _ = appModel.requestStopStreamConfirmation(in: workspace)
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
                .focused($focusedControl, equals: .disconnect)
                .accessibilitySortPriority(1)
                .disabled(appModel.session.phase == .disconnected)
            }
            .focusSection()

            Text("Actual Stream State")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            statusRows(state)
        }
        .frame(maxWidth: 980, alignment: .leading)
        .defaultFocus($focusedControl, .hideControls)
    }

    @ViewBuilder
    private func statusRows(
        _ state: TVStreamControlPresentationState
    ) -> some View {
        switch controlsLayout {
        case .compact:
            compactStatusRows(state)
        case .wide:
            ViewThatFits(in: .horizontal) {
                wideStatusRows(state)
                compactStatusRows(state)
            }
        }
    }

    private var controlsLayout: TVVisionStreamControlsLayout {
        TVVisionStreamControlsLayout(
            horizontalSizeClassIsCompact: horizontalSizeClass == .compact,
            usesAccessibilityTextSize: dynamicTypeSize.isAccessibilitySize
        )
    }

    private func wideStatusRows(
        _ state: TVStreamControlPresentationState
    ) -> some View {
        Grid(
            alignment: .leading,
            horizontalSpacing: 26,
            verticalSpacing: 12
        ) {
            ForEach(state.rows) { row in
                GridRow(alignment: .firstTextBaseline) {
                    Label(row.title, systemImage: row.systemImage)
                        .font(.callout.weight(.semibold))
                        .frame(width: 170, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.value)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(
                                row.isFailure ? Color.red : Color.primary
                            )
                        Text(row.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(row.title))
                .accessibilityValue(Text(row.accessibilityValue))
            }
        }
    }

    private func compactStatusRows(
        _ state: TVStreamControlPresentationState
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(state.rows) { row in
                VStack(alignment: .leading, spacing: 3) {
                    Label(row.title, systemImage: row.systemImage)
                        .font(.callout.weight(.semibold))
                    Text(row.value)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(
                            row.isFailure ? Color.red : Color.primary
                        )
                    Text(row.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(row.title))
                .accessibilityValue(Text(row.accessibilityValue))
            }
        }
    }
}
#endif

#if os(visionOS)
private struct VisionStreamControls: View {
    @Environment(AppModel.self) private var appModel
    let workspace: ProductWorkspaceReference
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let state = appModel.visionStreamControlPresentationState(in: workspace)

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Label(
                    appModel.session.phase.label,
                    systemImage: appModel.session.isStreaming
                        ? "dot.radiowaves.left.and.right"
                        : "moon"
                )
                    .font(.headline)

                Spacer(minLength: 12)

                Button {
                    _ = appModel.setStreamOverlayVisibility(
                        .hidden,
                        in: workspace
                    )
                } label: {
                    Label("Hide Controls", systemImage: "eye.slash")
                }

                Button(role: .destructive) {
                    _ = appModel.requestStopStreamConfirmation(in: workspace)
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
                .disabled(appModel.session.phase == .disconnected)
            }

            Text("Actual Windowed Stream State")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            statusRows(state)
        }
        .frame(maxWidth: 760, alignment: .leading)
    }

    @ViewBuilder
    private func statusRows(
        _ state: VisionStreamControlPresentationState
    ) -> some View {
        switch controlsLayout {
        case .compact:
            compactStatusRows(state)
        case .wide:
            ViewThatFits(in: .horizontal) {
                wideStatusRows(state)
                compactStatusRows(state)
            }
        }
    }

    private var controlsLayout: TVVisionStreamControlsLayout {
        TVVisionStreamControlsLayout(
            horizontalSizeClassIsCompact: horizontalSizeClass == .compact,
            usesAccessibilityTextSize: dynamicTypeSize.isAccessibilitySize
        )
    }

    private func wideStatusRows(
        _ state: VisionStreamControlPresentationState
    ) -> some View {
        Grid(
            alignment: .leading,
            horizontalSpacing: 18,
            verticalSpacing: 10
        ) {
            ForEach(state.rows) { row in
                GridRow(alignment: .firstTextBaseline) {
                    Label(row.title, systemImage: row.systemImage)
                        .font(.callout.weight(.semibold))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.value)
                            .font(.callout.weight(.medium))
                            .foregroundStyle(
                                row.isFailure ? Color.red : Color.primary
                            )
                        Text(row.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(row.title))
                .accessibilityValue(Text(row.accessibilityValue))
            }
        }
    }

    private func compactStatusRows(
        _ state: VisionStreamControlPresentationState
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(state.rows) { row in
                VStack(alignment: .leading, spacing: 3) {
                    Label(row.title, systemImage: row.systemImage)
                        .font(.callout.weight(.semibold))
                    Text(row.value)
                        .font(.callout.weight(.medium))
                        .foregroundStyle(
                            row.isFailure ? Color.red : Color.primary
                        )
                    Text(row.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text(row.title))
                .accessibilityValue(Text(row.accessibilityValue))
            }
        }
    }
}
#endif

private struct VirtualControllerOverlay: View {
    var body: some View {
        HStack {
            Image(systemName: "dpad")
                .font(.system(size: 54))
                .padding(22)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
            Spacer()
            HStack(spacing: 18) {
                ForEach(["a.circle", "b.circle", "x.circle", "y.circle"], id: \.self) { symbol in
                    Image(systemName: symbol)
                        .font(.system(size: 42))
                }
            }
            .padding(18)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct DiagnosticsView: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        List {
            Section("Current") {
                LabeledContent("Session", value: appModel.session.phase.label)
                LabeledContent("Render policy", value: appModel.renderState.policy.label)
                LabeledContent("Display headroom", value: String(format: "%.2fx current", appModel.renderState.headroom.current))
            }

            Section("Events") {
                if appModel.diagnostics.events.isEmpty {
                    ContentUnavailableView("No Diagnostics", systemImage: "waveform.path.ecg")
                } else {
                    ForEach(appModel.diagnostics.events.reversed()) { event in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label(event.category.label, systemImage: event.category.systemImage)
                                    .font(.caption)
                                    .foregroundStyle(color(for: event.severity))
                                Text(event.code)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(event.date.formatted(date: .omitted, time: .standard))
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            Text(event.message)
                            if let action = event.action {
                                Label(action.label, systemImage: "arrow.forward.circle")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                #if os(tvOS)
                Button(action: {}) {
                    Label("Export Unavailable", systemImage: "square.and.arrow.up")
                }
                .disabled(true)
                .accessibilityLabel("Diagnostics export unavailable")
                .accessibilityHint("Diagnostics export is unavailable on Apple TV.")
                #else
                ShareLink(item: appModel.diagnostics.exportText) {
                    Label("Export Diagnostics", systemImage: "square.and.arrow.up")
                }
                .disabled(appModel.diagnostics.events.isEmpty)
                .accessibilityLabel("Export Diagnostics")
                .accessibilityHint("Shares a privacy-redacted diagnostics report.")
                #endif
            }
        }
    }

    private func color(for severity: RuntimeDiagnosticSeverity) -> Color {
        switch severity {
        case .debug, .info: .secondary
        case .warning: .orange
        case .error: .red
        }
    }
}

private struct SettingsView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        @Bindable var appModel = appModel

        Form {
            Section("Stream Quality") {
                NumberSettingRow(title: "Width", value: $appModel.settings.stream.width, range: 1280...7680, step: 160, suffix: "px")
                NumberSettingRow(title: "Height", value: $appModel.settings.stream.height, range: 720...4320, step: 90, suffix: "px")
                NumberSettingRow(title: "Frame rate", value: $appModel.settings.stream.frameRate, range: 30...240, step: 30, suffix: "fps")
                NumberSettingRow(title: "Bitrate", value: $appModel.settings.stream.bitrateKbps, range: 10_000...200_000, step: 5_000, suffix: "Kbps")
                #if os(tvOS) || os(visionOS)
                Picker("Scale", selection: $appModel.settings.stream.scaleMode) {
                    ForEach(RenderScaleMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                platformSettingStatusRow(.render)
                Toggle("HDR / EDR", isOn: $appModel.settings.stream.hdrEnabled)
                platformSettingStatusRow(.hdr)
                #else
                Toggle("HDR / EDR", isOn: $appModel.settings.stream.hdrEnabled)
                HDRPresentationStatusRow(status: appModel.hdrPresentationStatus)
                Picker("Scale", selection: $appModel.settings.stream.scaleMode) {
                    ForEach(RenderScaleMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                #endif
            }

            Section("Input") {
                #if os(tvOS) || os(visionOS)
                platformSettingStatusRow(.input)
                platformSettingStatusRow(.controllers)
                #else
                Toggle("Prefer relative mouse", isOn: $appModel.settings.input.preferRelativeMouseMode)
                Toggle("Forward system shortcuts", isOn: $appModel.settings.input.captureSystemShortcuts)
                Toggle("Virtual controller", isOn: $appModel.settings.input.showVirtualController)
                #endif
            }

            Section("Spatial Audio") {
                spatialAudioSettingsContent
            }

            Section("Continuity") {
                continuitySettingsContent
            }

            Section {
                Button {
                    Task {
                        await appModel.saveSettings()
                    }
                } label: {
                    Label("Save Settings", systemImage: "checkmark.circle")
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    @ViewBuilder
    private var spatialAudioSettingsContent: some View {
        switch spatialAudioSettingsLayout {
        case .compact:
            compactSpatialAudioSettings
        case .wide:
            ViewThatFits(in: .horizontal) {
                wideSpatialAudioSettings
                compactSpatialAudioSettings
            }
        }
    }

    private var spatialAudioSettingsLayout: SpatialAudioSettingsLayout {
        SpatialAudioSettingsLayout(
            horizontalSizeClassIsCompact: horizontalSizeClass == .compact,
            usesAccessibilityTextSize: dynamicTypeSize.isAccessibilitySize
        )
    }

    private var compactSpatialAudioSettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            spatialAudioPreferenceControls
            spatialAudioActualStatus
        }
    }

    private var wideSpatialAudioSettings: some View {
        HStack(alignment: .top, spacing: 20) {
            spatialAudioPreferenceControls
                .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
            Divider()
            spatialAudioActualStatus
            .frame(minWidth: 280, maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var spatialAudioPreferenceControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: spatialAudioEnabled) {
                Label("Spatial audio", systemImage: "wave.3.right.circle")
            }
            Toggle(isOn: headTrackingEnabled) {
                Label("Head tracking", systemImage: "person.wave.2")
            }
            .disabled(!appModel.settings.audio.spatialAudioEnabled)
        }
    }

    @ViewBuilder
    private var spatialAudioActualStatus: some View {
        #if os(tvOS) || os(visionOS)
        platformSettingStatusRow(.spatial)
        #else
        SpatialAudioPresentationStatusRow(
            status: appModel.spatialAudioPresentationStatus
        )
        #endif
    }

    @ViewBuilder
    private func platformSettingStatusRow(
        _ kind: TVVisionPlatformSettingsItemKind
    ) -> some View {
        if let state = appModel.tvVisionPlatformSettingsPresentationState {
            TVVisionPlatformSettingStatusRow(content: state.content(for: kind))
        }
    }

    @ViewBuilder
    private var continuitySettingsContent: some View {
        if horizontalSizeClass == .compact || dynamicTypeSize.isAccessibilitySize {
            compactContinuitySettings
        } else {
            ViewThatFits(in: .horizontal) {
                wideContinuitySettings
                compactContinuitySettings
            }
        }
    }

    private var compactContinuitySettings: some View {
        VStack(alignment: .leading, spacing: 12) {
            continuityPreferenceControls
            Divider()
            MobileActualStatusRows(
                status: appModel.mobileExperiencePresentationStatus
            )
        }
    }

    private var wideContinuitySettings: some View {
        HStack(alignment: .top, spacing: 20) {
            continuityPreferenceControls
                .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
            Divider()
            MobileActualStatusRows(
                status: appModel.mobileExperiencePresentationStatus
            )
            .frame(minWidth: 300, maxWidth: .infinity, alignment: .leading)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var continuityPreferenceControls: some View {
        @Bindable var appModel = appModel

        return VStack(alignment: .leading, spacing: 12) {
            Toggle(isOn: $appModel.settings.continuity.audioContinuityEnabled) {
                Label("Audio continuity", systemImage: "speaker.wave.2")
            }
            Toggle(isOn: $appModel.settings.continuity.pictureInPictureEnabled) {
                Label("Picture in Picture", systemImage: "pip")
            }
            Toggle(
                isOn: $appModel.settings.continuity.reduceRenderingInBackground
            ) {
                Label("Reduce background rendering", systemImage: "gauge.with.dots.needle.33percent")
            }
        }
    }

    private var spatialAudioEnabled: Binding<Bool> {
        Binding(
            get: {
                appModel.settings.audio.spatialAudioEnabled
            },
            set: { enabled in
                applySpatialAudioPreferences(SessionSpatialAudioPreferences(
                    spatialAudioEnabled: enabled,
                    headTrackingEnabled:
                        appModel.settings.audio.headTrackingEnabled
                ))
            }
        )
    }

    private var headTrackingEnabled: Binding<Bool> {
        Binding(
            get: {
                appModel.settings.audio.headTrackingEnabled
            },
            set: { enabled in
                applySpatialAudioPreferences(SessionSpatialAudioPreferences(
                    spatialAudioEnabled:
                        appModel.settings.audio.spatialAudioEnabled,
                    headTrackingEnabled: enabled
                ))
            }
        )
    }

    private func applySpatialAudioPreferences(
        _ preferences: SessionSpatialAudioPreferences
    ) {
        Task {
            do {
                try await appModel.updateSpatialAudioPreferences(preferences)
            } catch {
                appModel.diagnostics.record(
                    ApplicationDiagnosticFactory.streamFailure(error)
                )
            }
        }
    }
}

private struct TVVisionPlatformSettingStatusRow: View {
    let content: TVVisionPlatformSettingsItemContent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            LabeledContent("Desired behavior") {
                Text(content.desiredValue)
            }
            LabeledContent("Current state") {
                Label(content.actualValue, systemImage: content.systemImage)
                    .foregroundStyle(content.isFailure ? Color.red : Color.primary)
            }
            Text(content.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(content.title))
        .accessibilityValue(Text(content.accessibilityValue))
    }
}

private struct HDRPresentationStatusRow: View {
    let status: HDRPresentationStatus

    var body: some View {
        let content = status.content

        VStack(alignment: .leading, spacing: 4) {
            LabeledContent("Current output") {
                Label(content.settingsValue, systemImage: content.systemImage)
            }
            Text(content.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current HDR presentation")
        .accessibilityValue(content.accessibilityValue)
    }
}

private struct SpatialAudioPresentationStatusRow: View {
    let status: SpatialAudioPresentationStatus

    var body: some View {
        let content = status.content

        VStack(alignment: .leading, spacing: 4) {
            LabeledContent("Current playback") {
                Label(content.settingsValue, systemImage: content.systemImage)
            }
            Text(content.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Current spatial audio presentation")
        .accessibilityValue(spatialAudioAccessibilityValue(content))
    }
}

private struct MobilePictureInPictureCommandButton: View {
    @Environment(AppModel.self) private var appModel

    @ViewBuilder
    var body: some View {
        let status = appModel.mobileExperiencePresentationStatus
        switch status.pictureInPictureCommand {
        case .hidden:
            EmptyView()
        case .start:
            commandButton(
                command: .start,
                systemImage: "pip.enter",
                label: "Start Picture in Picture",
                value: mobilePictureInPictureStatusContent(
                    status.pictureInPicture
                ).accessibilityValue
            )
        case .stop:
            commandButton(
                command: .stop,
                systemImage: "pip.exit",
                label: "Stop Picture in Picture",
                value: mobilePictureInPictureStatusContent(
                    status.pictureInPicture
                ).accessibilityValue
            )
        case .stopPending:
            ProgressView()
                .controlSize(.small)
                .frame(width: 32, height: 32)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Picture in Picture command")
                .accessibilityValue("Stopping")
        }
    }

    private func commandButton(
        command: MobilePictureInPictureCommand,
        systemImage: String,
        label: LocalizedStringResource,
        value: Text
    ) -> some View {
        Button {
            _ = appModel.performMobilePictureInPictureCommand(command)
        } label: {
            Image(systemName: systemImage)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.bordered)
        .frame(width: 36, height: 32)
        .help(label)
        .accessibilityLabel(Text(label))
        .accessibilityValue(value)
    }
}

private struct MobileActualStatusRows: View {
    let status: MobileExperiencePresentationStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MobileActualStatusRow(content: mobileSceneStatusContent(status.scene))
            MobileActualStatusRow(
                content: mobilePictureInPictureStatusContent(
                    status.pictureInPicture
                )
            )
            MobileActualStatusRow(
                content: mobileContinuityStatusContent(status.continuity)
            )
            MobileActualStatusRow(content: mobileDisplayStatusContent(status.display))
        }
    }
}

private struct MobileActualStatusRow: View {
    let content: MobileActualStatusContent

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(content.title)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Label {
                    content.value
                } icon: {
                    Image(systemName: content.systemImage)
                }
            }
            content.detail
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(content.title))
        .accessibilityValue(content.accessibilityValue)
    }
}

private struct MobileActualStatusPill: View {
    let content: MobileActualStatusContent

    var body: some View {
        StatusPill(label: content.value, systemImage: content.systemImage)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(content.title))
            .accessibilityValue(content.accessibilityValue)
    }
}

private struct MobileActualStatusContent {
    let title: LocalizedStringResource
    let value: Text
    let detail: Text
    let systemImage: String
    let accessibilityValue: Text
}

private func mobileSceneStatusContent(
    _ status: MobileScenePresentationStatus
) -> MobileActualStatusContent {
    switch status {
    case .noSession:
        MobileActualStatusContent(
            title: "Scene",
            value: Text("No session"),
            detail: Text("No active stream scene is attached."),
            systemImage: "rectangle.slash",
            accessibilityValue: Text("No active stream scene")
        )
    case .unknown:
        MobileActualStatusContent(
            title: "Scene",
            value: Text("Waiting"),
            detail: Text("Waiting for the current stream window."),
            systemImage: "hourglass",
            accessibilityValue: Text("Waiting for the current stream window")
        )
    case .active:
        MobileActualStatusContent(
            title: "Scene",
            value: Text("Active"),
            detail: Text("The stream scene is active in the foreground."),
            systemImage: "rectangle.inset.filled",
            accessibilityValue: Text("Active in the foreground")
        )
    case .inactive:
        MobileActualStatusContent(
            title: "Scene",
            value: Text("Inactive"),
            detail: Text("The stream scene is visible but inactive."),
            systemImage: "rectangle.dashed",
            accessibilityValue: Text("Visible but inactive")
        )
    case .background:
        MobileActualStatusContent(
            title: "Scene",
            value: Text("Background"),
            detail: Text("The stream scene is in the background."),
            systemImage: "rectangle.stack",
            accessibilityValue: Text("In the background")
        )
    case .detached:
        MobileActualStatusContent(
            title: "Scene",
            value: Text("Detached"),
            detail: Text("The stream surface is not attached to a window."),
            systemImage: "rectangle.slash",
            accessibilityValue: Text("Stream surface detached")
        )
    case .resizing:
        MobileActualStatusContent(
            title: "Scene",
            value: Text("Resizing"),
            detail: Text("Window geometry is updating."),
            systemImage: "arrow.up.left.and.arrow.down.right",
            accessibilityValue: Text("Window geometry is updating")
        )
    case .invalidGeometry:
        MobileActualStatusContent(
            title: "Scene",
            value: Text("Unavailable"),
            detail: Text("Current window geometry is unavailable."),
            systemImage: "exclamationmark.triangle",
            accessibilityValue: Text("Current window geometry is unavailable")
        )
    }
}

private func mobilePictureInPictureStatusContent(
    _ status: MobilePictureInPicturePresentationStatus
) -> MobileActualStatusContent {
    switch status {
    case .noSession:
        MobileActualStatusContent(
            title: "Picture in Picture",
            value: Text("No session"),
            detail: Text("Picture in Picture is not running."),
            systemImage: "pip",
            accessibilityValue: Text("No active stream")
        )
    case .disabled:
        MobileActualStatusContent(
            title: "Picture in Picture",
            value: Text("Disabled"),
            detail: Text("Picture in Picture is disabled in settings."),
            systemImage: "pip.remove",
            accessibilityValue: Text("Disabled in settings")
        )
    case .unavailable:
        MobileActualStatusContent(
            title: "Picture in Picture",
            value: Text("Unavailable"),
            detail: Text("Native Picture in Picture is not currently available."),
            systemImage: "pip.remove",
            accessibilityValue: Text("Native Picture in Picture unavailable")
        )
    case .preparing:
        MobileActualStatusContent(
            title: "Picture in Picture",
            value: Text("Preparing"),
            detail: Text("Preparing the native Picture in Picture controller."),
            systemImage: "hourglass",
            accessibilityValue: Text("Preparing")
        )
    case .ready:
        MobileActualStatusContent(
            title: "Picture in Picture",
            value: Text("Ready"),
            detail: Text("Native Picture in Picture can be started."),
            systemImage: "pip.enter",
            accessibilityValue: Text("Ready to start")
        )
    case .starting:
        MobileActualStatusContent(
            title: "Picture in Picture",
            value: Text("Starting"),
            detail: Text("Waiting for native Picture in Picture confirmation."),
            systemImage: "pip.enter",
            accessibilityValue: Text("Start requested, waiting for confirmation")
        )
    case .active:
        MobileActualStatusContent(
            title: "Picture in Picture",
            value: Text("Active"),
            detail: Text("Native Picture in Picture is active."),
            systemImage: "pip.fill",
            accessibilityValue: Text("Native Picture in Picture active")
        )
    case .stopping:
        MobileActualStatusContent(
            title: "Picture in Picture",
            value: Text("Stopping"),
            detail: Text("Waiting for Picture in Picture to stop."),
            systemImage: "pip.exit",
            accessibilityValue: Text("Stop requested, waiting for confirmation")
        )
    case .stopped:
        MobileActualStatusContent(
            title: "Picture in Picture",
            value: Text("Stopped"),
            detail: Text("Picture in Picture is stopped and can be started again."),
            systemImage: "pip",
            accessibilityValue: Text("Stopped and ready to start again")
        )
    case .failed:
        MobileActualStatusContent(
            title: "Picture in Picture",
            value: Text("Failed"),
            detail: Text("Native Picture in Picture could not start or continue."),
            systemImage: "exclamationmark.triangle",
            accessibilityValue: Text("Native Picture in Picture failed")
        )
    }
}

private func mobileContinuityStatusContent(
    _ status: MobileContinuityPresentationStatus
) -> MobileActualStatusContent {
    switch status {
    case .noSession:
        MobileActualStatusContent(
            title: "Background continuity",
            value: Text("No session"),
            detail: Text("No stream is using a background media path."),
            systemImage: "pause.circle",
            accessibilityValue: Text("No active stream")
        )
    case .unavailable:
        MobileActualStatusContent(
            title: "Background continuity",
            value: Text("Waiting"),
            detail: Text("Waiting for actual media continuity state."),
            systemImage: "hourglass",
            accessibilityValue: Text("Waiting for actual media continuity state")
        )
    case .foreground:
        MobileActualStatusContent(
            title: "Background continuity",
            value: Text("Foreground"),
            detail: Text("Video and audio are running in the foreground."),
            systemImage: "play.rectangle",
            accessibilityValue: Text("Foreground video and audio")
        )
    case .pictureInPicture:
        MobileActualStatusContent(
            title: "Background continuity",
            value: Text("Picture in Picture"),
            detail: Text("The confirmed Picture in Picture path is continuing the stream."),
            systemImage: "pip.fill",
            accessibilityValue: Text("Confirmed Picture in Picture continuity")
        )
    case .audioOnly:
        MobileActualStatusContent(
            title: "Background continuity",
            value: Text("Audio only"),
            detail: Text("The active audio session is continuing without video presentation."),
            systemImage: "speaker.wave.2.fill",
            accessibilityValue: Text("Active audio-only continuity")
        )
    case .suspended:
        MobileActualStatusContent(
            title: "Background continuity",
            value: Text("Suspended"),
            detail: Text("No permitted background media path is active."),
            systemImage: "pause.circle",
            accessibilityValue: Text("Suspended because no permitted background media path is active")
        )
    case .paused:
        MobileActualStatusContent(
            title: "Background continuity",
            value: Text("Stream paused"),
            detail: Text("The stream is paused because continuity policy was not satisfied."),
            systemImage: "pause.fill",
            accessibilityValue: Text("Stream paused by continuity policy")
        )
    case .stopped:
        MobileActualStatusContent(
            title: "Background continuity",
            value: Text("Stopped"),
            detail: Text("The mobile media generation is stopped."),
            systemImage: "stop.fill",
            accessibilityValue: Text("Mobile media generation stopped")
        )
    }
}

private func mobileDisplayStatusContent(
    _ status: MobileDisplayPresentationStatus
) -> MobileActualStatusContent {
    switch status {
    case .noSession:
        MobileActualStatusContent(
            title: "Mobile HDR output",
            value: Text("No session"),
            detail: Text("No active mobile video presentation."),
            systemImage: "sun.max",
            accessibilityValue: Text("No active mobile video presentation")
        )
    case .unknown:
        MobileActualStatusContent(
            title: "Mobile HDR output",
            value: Text("Unknown"),
            detail: Text("Actual display headroom is not available yet."),
            systemImage: "questionmark.circle",
            accessibilityValue: Text("Actual display headroom unknown")
        )
    case .detached:
        MobileActualStatusContent(
            title: "Mobile HDR output",
            value: Text("Detached"),
            detail: Text("The stream surface is not attached to a display."),
            systemImage: "rectangle.slash",
            accessibilityValue: Text("Stream surface detached from the display")
        )
    case .sdr:
        MobileActualStatusContent(
            title: "Mobile HDR output",
            value: Text("SDR"),
            detail: Text("The attached display currently reports standard dynamic range."),
            systemImage: "sun.min",
            accessibilityValue: Text("Actual output is standard dynamic range")
        )
    case let .edrCapable(potential, current):
        MobileActualStatusContent(
            title: "Mobile HDR output",
            value: Text("EDR capable"),
            detail: Text("Current headroom is \(current, format: .number.precision(.fractionLength(1))) times; potential headroom is \(potential, format: .number.precision(.fractionLength(1))) times."),
            systemImage: "sun.max",
            accessibilityValue: Text("EDR capable. Current headroom \(current, format: .number.precision(.fractionLength(1))) times. Potential headroom \(potential, format: .number.precision(.fractionLength(1))) times.")
        )
    case let .edrActive(current):
        MobileActualStatusContent(
            title: "Mobile HDR output",
            value: Text("EDR active"),
            detail: Text("The current renderer is presenting EDR at \(current, format: .number.precision(.fractionLength(1))) times headroom."),
            systemImage: "sun.max.fill",
            accessibilityValue: Text("EDR active at \(current, format: .number.precision(.fractionLength(1))) times headroom.")
        )
    case .sdrFallback:
        MobileActualStatusContent(
            title: "Mobile HDR output",
            value: Text("SDR fallback"),
            detail: Text("Actual display conditions require standard dynamic range."),
            systemImage: "exclamationmark.triangle",
            accessibilityValue: Text("HDR to SDR fallback is active")
        )
    case .invalidHeadroom:
        MobileActualStatusContent(
            title: "Mobile HDR output",
            value: Text("Invalid headroom"),
            detail: Text("The display headroom reading was invalid and is not used as HDR proof."),
            systemImage: "exclamationmark.triangle",
            accessibilityValue: Text("Invalid display headroom; HDR is not claimed")
        )
    case .reconfiguring:
        MobileActualStatusContent(
            title: "Mobile HDR output",
            value: Text("Reconfiguring"),
            detail: Text("Waiting for video that matches the current mobile display revision."),
            systemImage: "arrow.triangle.2.circlepath",
            accessibilityValue: Text("Reconfiguring for the current mobile display")
        )
    }
}

private struct NumberSettingRow: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let suffix: String

    var body: some View {
        #if os(tvOS)
        HStack {
            Text(title)
            Spacer()
            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus.circle")
            }
            Text("\(value) \(suffix)")
                .monospacedDigit()
                .frame(minWidth: 120)
            Button {
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus.circle")
            }
        }
        #else
        Stepper("\(title): \(value) \(suffix)", value: $value, in: range, step: step)
        #endif
    }
}

private struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private struct PanelHeader: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.title3.weight(.semibold))
    }
}

private struct StatusPill: View {
    let label: Text
    let systemImage: String

    init(label: String, systemImage: String) {
        self.label = Text(verbatim: label)
        self.systemImage = systemImage
    }

    init(label: LocalizedStringResource, systemImage: String) {
        self.label = Text(label)
        self.systemImage = systemImage
    }

    init(label: Text, systemImage: String) {
        self.label = label
        self.systemImage = systemImage
    }

    var body: some View {
        Label {
            label
        } icon: {
            Image(systemName: systemImage)
        }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary)
            .clipShape(Capsule())
    }
}

private func spatialAudioAccessibilityValue(
    _ content: SpatialAudioPresentationStatusContent
) -> Text {
    Text("\(Text(content.settingsValue)). \(Text(content.detail))")
}

private extension RenderPolicy {
    var label: String {
        switch self {
        case .idle: "Idle"
        case .active: "Active"
        case let .throttled(reason): "Throttled: \(reason)"
        case let .paused(reason): "Paused: \(reason)"
        }
    }
}
