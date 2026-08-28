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
}
#endif
