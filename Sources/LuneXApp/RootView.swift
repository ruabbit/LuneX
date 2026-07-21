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
            .sheet(isPresented: $isShowingAddHost) {
                AddHostSheet { name, address in
                    Task {
                        await appModel.addManualHost(name: name, address: address)
                    }
                }
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
                            isShowingAddHost = true
                        } label: {
                            Label("Add Host", systemImage: "plus")
                        }

                        Button {
                            Task {
                                await appModel.stopStream()
                            }
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
                LibraryDashboardView()
                    .navigationTitle("Library")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                isShowingAddHost = true
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
                StreamWorkspaceView()
                    .navigationTitle("Stream")
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                Task {
                                    await appModel.stopStream()
                                }
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
            LibraryDashboardView()
        case .stream:
            #if os(macOS)
            StreamWorkspaceView(platformLifecycle: platformLifecycle)
            #else
            StreamWorkspaceView()
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
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var address = ""
    let onAdd: (String?, String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("Name", text: $name)
                TextField("Address", text: $address)
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
            }
            .navigationTitle("Add Host")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onAdd(name.isEmpty ? nil : name, address)
                        dismiss()
                    }
                    .disabled(address.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            #if os(macOS)
            .frame(width: 380, height: 190)
            #endif
        }
    }
}

private struct LibraryDashboardView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        @Bindable var appModel = appModel

        ScrollView {
            #if os(iOS)
            if horizontalSizeClass == .compact {
                LazyVStack(alignment: .leading, spacing: 16) {
                    HostLibraryPanel(selectedHostID: $appModel.selectedHostID)
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
                HostLibraryPanel(selectedHostID: selectedHostID)
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

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(title: "Hosts", systemImage: "desktopcomputer")

                if appModel.hosts.isEmpty {
                    ContentUnavailableView("No Hosts", systemImage: "desktopcomputer", description: Text("Add a Sunshine or GameStream host."))
                        .frame(minHeight: 180)
                } else {
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
                    Button {
                        Task {
                            await appModel.loadHosts()
                        }
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }

                    Button(role: .destructive) {
                        Task {
                            await appModel.removeSelectedHost()
                        }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                    .disabled(appModel.selectedHost == nil)
                }
            }
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
        @Bindable var appModel = appModel

        Panel {
            VStack(alignment: .leading, spacing: 12) {
                PanelHeader(title: "Pairing", systemImage: "key")

                if let host = appModel.selectedHost {
                    Text(host.name)
                        .font(.headline)
                    Text(host.pairingState == .paired ? "Paired" : "Unpaired")
                        .font(.caption)
                        .foregroundStyle(host.pairingState == .paired ? .green : .secondary)

                    if host.pairingState == .paired {
                        Label("Pinned identity preserved", systemImage: "checkmark.shield")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !appModel.isPairingTransportAvailable {
                        Label("Authenticated pairing transport unavailable", systemImage: "exclamationmark.shield")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if appModel.pairingUI.isRunning {
                        HStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.small)
                            Button {
                                Task {
                                    await appModel.cancelPairing()
                                }
                            } label: {
                                Label("Cancel", systemImage: "xmark")
                            }
                        }
                    } else if appModel.pairingUI.stage == .waitingForPIN,
                              appModel.pairingUI.hostID == host.id {
                        HStack {
                            TextField("PIN", text: $appModel.pairingUI.pin)
                                #if os(iOS)
                                .keyboardType(.numberPad)
                                #endif
                                #if !os(tvOS)
                                .textFieldStyle(.roundedBorder)
                                #endif
                                .frame(maxWidth: 120)

                            Button {
                                Task {
                                    await appModel.submitPairingPIN()
                                }
                            } label: {
                                Label("Submit", systemImage: "checkmark")
                            }
                            .disabled(!appModel.isPairingPINValid)

                            Button {
                                Task {
                                    await appModel.cancelPairing()
                                }
                            } label: {
                                Label("Cancel", systemImage: "xmark")
                            }
                        }
                    } else {
                        Button {
                            Task {
                                await appModel.beginPairing(host: host)
                            }
                        } label: {
                            Label("Start Pairing", systemImage: "lock.open")
                        }
                    }

                    if let message = appModel.pairingUI.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let action = appModel.pairingUI.actionMessage {
                        Label(action, systemImage: "arrow.forward.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    ContentUnavailableView("Select a Host", systemImage: "key")
                }
            }
        }
        .onChange(of: appModel.selectedHostID) { oldValue, newValue in
            guard oldValue != newValue else { return }
            Task {
                await appModel.cancelPairing()
            }
        }
    }
}

private struct AppCatalogPanel: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    PanelHeader(title: "Apps", systemImage: "square.grid.3x3")
                    Spacer()
                    Button {
                        Task {
                            await appModel.refreshAppsForSelectedHost()
                        }
                    } label: {
                        Label("Refresh Apps", systemImage: "arrow.down.circle")
                    }
                    .disabled(appModel.appCatalogUI.isRefreshing || appModel.selectedHost?.pairingState != .paired)
                }

                if appModel.selectedApps.isEmpty {
                    ContentUnavailableView("No Apps", systemImage: "square.grid.3x3", description: Text(appModel.appCatalogUI.errorMessage ?? "Refresh a paired host to load apps."))
                        .frame(minHeight: 240)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                        ForEach(appModel.selectedApps) { app in
                            RemoteAppTile(
                                app: app,
                                isSelected: appModel.streamLaunchUI.selectedAppID == app.id
                            )
                            .onTapGesture {
                                appModel.select(app: app)
                            }
                        }
                    }
                    .frame(minHeight: 240, alignment: .top)
                }

                if let date = appModel.appCatalogUI.lastUpdatedAt {
                    Text("Updated \(date.formatted(date: .omitted, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
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
                                Task {
                                    await appModel.stopStream()
                                }
                            } label: {
                                Label("Stop Stream", systemImage: "stop.circle")
                            }
                            .disabled(appModel.session.phase == .stopping)
                        } else {
                            Button {
                                Task {
                                    await appModel.launchSelectedApp()
                                }
                            } label: {
                                Label(
                                    appModel.streamLaunchUI.isLaunching ? "Launching" : "Launch Stream",
                                    systemImage: "play.circle.fill"
                                )
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(appModel.streamLaunchUI.isLaunching || host.pairingState != .paired)
                        }
                    } else {
                        Label("Moonlight media transport unavailable", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let error = appModel.streamLaunchUI.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                    if let action = appModel.streamLaunchUI.actionMessage {
                        Label(action, systemImage: "arrow.forward.circle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    ContentUnavailableView("Select an App", systemImage: "play.fill")
                }
            }
        }
    }
}

private struct StreamWorkspaceView: View {
    @Environment(AppModel.self) private var appModel
    #if os(macOS)
    let platformLifecycle: PlatformLifecycleState
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
                    _ = appModel.submitMacPlatformInput(sample)
                },
                captureExitHandler: {
                    appModel.exitMacRelativePointerCapture()
                }
            )
                .ignoresSafeArea()
            #else
            MetalStreamSurface(
                renderState: appModel.renderState,
                presentationSource: appModel.videoPresentationSource
            )
                .ignoresSafeArea()
            #endif

            StreamStatusOverlay()
                .padding(16)

            if appModel.settings.input.showVirtualController && appModel.session.isStreaming {
                VirtualControllerOverlay()
                    .padding(18)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        }
        .background(Color.black)
    }
}

private struct StreamStatusOverlay: View {
    @Environment(AppModel.self) private var appModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Label(appModel.session.phase.label, systemImage: appModel.session.isStreaming ? "dot.radiowaves.left.and.right" : "moon")
                    .font(.headline)
                Button {
                    Task {
                        await appModel.stopStream()
                    }
                } label: {
                    Label("Disconnect", systemImage: "xmark.circle")
                }
                .disabled(appModel.session.phase == .disconnected)
            }

            HStack(spacing: 12) {
                StatusPill(label: appModel.settings.input.preferRelativeMouseMode ? "Relative mouse" : "Direct pointer", systemImage: "cursorarrow.motionlines")
                StatusPill(label: appModel.settings.stream.hdrEnabled ? "HDR/EDR on" : "SDR", systemImage: "sun.max")
                StatusPill(label: "Spatial gated", systemImage: "airpodspro")
            }

            Text(
                appModel.diagnostics.latestActionableEvent?.message
                    ?? appModel.diagnostics.latestSummary
            )
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

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

    var body: some View {
        @Bindable var appModel = appModel

        Form {
            Section("Stream Quality") {
                NumberSettingRow(title: "Width", value: $appModel.settings.stream.width, range: 1280...7680, step: 160, suffix: "px")
                NumberSettingRow(title: "Height", value: $appModel.settings.stream.height, range: 720...4320, step: 90, suffix: "px")
                NumberSettingRow(title: "Frame rate", value: $appModel.settings.stream.frameRate, range: 30...240, step: 30, suffix: "fps")
                NumberSettingRow(title: "Bitrate", value: $appModel.settings.stream.bitrateKbps, range: 10_000...200_000, step: 5_000, suffix: "Kbps")
                Toggle("HDR / EDR", isOn: $appModel.settings.stream.hdrEnabled)
                Picker("Scale", selection: $appModel.settings.stream.scaleMode) {
                    ForEach(RenderScaleMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
            }

            Section("Input") {
                Toggle("Prefer relative mouse", isOn: $appModel.settings.input.preferRelativeMouseMode)
                Toggle("Forward system shortcuts", isOn: $appModel.settings.input.captureSystemShortcuts)
                Toggle("Virtual controller", isOn: $appModel.settings.input.showVirtualController)
            }

            Section("Continuity") {
                Toggle("Audio continuity", isOn: $appModel.settings.continuity.audioContinuityEnabled)
                Toggle("Picture in Picture", isOn: $appModel.settings.continuity.pictureInPictureEnabled)
                Toggle("Reduce rendering in background", isOn: $appModel.settings.continuity.reduceRenderingInBackground)
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
    let label: String
    let systemImage: String

    var body: some View {
        Label(label, systemImage: systemImage)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.quaternary)
            .clipShape(Capsule())
    }
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
