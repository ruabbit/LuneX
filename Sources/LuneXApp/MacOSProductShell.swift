#if os(macOS)
import SwiftUI

struct MacOSProductShell: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.openWindow) private var openWindow
    let workspace: ProductWorkspaceReference
    let platformLifecycle: PlatformLifecycleState
    let onAddHost: () -> Void

    var body: some View {
        Group {
            switch appModel.macOSContentMode(in: workspace) {
            case .stream:
                StreamWorkspaceView(
                    workspace: workspace,
                    platformLifecycle: platformLifecycle
                )
            case .firstUse, .pairing, .catalog:
                library
            }
        }
        .focusedSceneValue(\.productWorkspaceReference, workspace)
    }

    private var library: some View {
        NavigationSplitView {
            MacOSHostSidebar(
                workspace: workspace,
                onAddHost: onAddHost
            )
            .navigationTitle("LuneX")
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 300)
        } detail: {
            detail
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if let issue = appModel.streamProductIssue(in: workspace) {
                        streamIssueNotice(issue)
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        Button(action: onAddHost) {
                            Label("Add Host", systemImage: "plus")
                        }
                        .labelStyle(.iconOnly)
                        .help("Add Host")
                        .productActionTarget()

                        SettingsLink {
                            Label("Settings", systemImage: "gearshape")
                        }
                        .labelStyle(.iconOnly)
                        .help("Settings")
                        .productActionTarget()

                        Menu {
                            Button {
                                Task {
                                    await appModel.refreshHostReachability()
                                }
                            } label: {
                                Label("Refresh Hosts", systemImage: "arrow.clockwise")
                            }

                            Divider()

                            Button {
                                openWindow(id: "diagnostics")
                            } label: {
                                Label(
                                    "Diagnostics",
                                    systemImage: "waveform.path.ecg"
                                )
                            }
                        } label: {
                            Label("More", systemImage: "ellipsis.circle")
                        }
                        .labelStyle(.iconOnly)
                        .help("More")
                        .productActionTarget()
                    }
                }
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch appModel.macOSContentMode(in: workspace) {
        case .firstUse:
            ContentUnavailableView {
                Label("No Hosts", systemImage: "desktopcomputer")
            } description: {
                Text("LuneX is looking for Sunshine hosts on your network.")
            } actions: {
                Button(action: onAddHost) {
                    Label("Add Host", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .productActionTarget()
            }
            .navigationTitle("Library")
        case .pairing:
            MacOSPairingView(workspace: workspace)
        case .catalog:
            MacOSCatalogView(workspace: workspace)
        case .stream:
            EmptyView()
        }
    }

    private func streamIssueNotice(_ issue: ProductIssue) -> some View {
        VStack(spacing: 0) {
            Divider()
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: issue.presentation.systemImage)
                    .foregroundStyle(issue.severity == .error ? Color.red : Color.secondary)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(issue.presentation.title).font(.headline)
                    Text(issue.presentation.message)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let action = issue.action {
                        Button {
                            Task { await appModel.performProductAction(action) }
                        } label: {
                            Text(action.kind.title)
                        }
                        .disabled(!appModel.canPerformProductAction(action))
                    }
                }
                Spacer(minLength: 0)
                Button {
                    appModel.dismissStreamIssue(issue.id, in: workspace)
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.plain)
                .help("Dismiss")
                .accessibilityLabel("Dismiss stream error")
            }
            .padding(16)
        }
        .background(.background)
    }
}
#endif
