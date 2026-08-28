import SwiftUI

@main
struct LuneXApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        #if os(tvOS)
        WindowGroup {
            RootView(workspace: appModel.primaryWorkspaceReference)
                .environment(appModel)
        }
        #elseif os(macOS)
        WindowGroup(
            id: "workspace",
            for: ProductWorkspaceSceneIdentity.self
        ) { sceneIdentity in
            ProductWorkspaceSceneRoot(sceneIdentity: sceneIdentity)
                .environment(appModel)
        }
        .defaultSize(
            width: CGFloat(ProductWorkspaceWindowSizingPolicy.macOSDefaultSize.width),
            height: CGFloat(ProductWorkspaceWindowSizingPolicy.macOSDefaultSize.height)
        )
        .windowResizability(.contentMinSize)
        Settings {
            MacOSSettingsView()
                .environment(appModel)
        }
        Window("Diagnostics", id: "diagnostics") {
            MacOSDiagnosticsWindow()
                .environment(appModel)
        }
        .defaultSize(width: 760, height: 620)
        .commands {
            MacOSAppCommands(appModel: appModel)
        }
        #elseif os(iOS)
        WindowGroup(
            id: "workspace",
            for: ProductWorkspaceSceneIdentity.self
        ) { sceneIdentity in
            ProductWorkspaceSceneRoot(sceneIdentity: sceneIdentity)
                .environment(appModel)
        }
        .defaultSize(width: 1280, height: 800)
        #else
        Window("LuneX", id: "main") {
            RootView(workspace: appModel.primaryWorkspaceReference)
                .environment(appModel)
        }
        .defaultSize(width: 1280, height: 800)
        #endif
    }
}

#if os(macOS) || os(iOS)
private struct ProductWorkspaceSceneRoot: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.supportsMultipleWindows) private var supportsMultipleWindows
    @Binding var sceneIdentity: ProductWorkspaceSceneIdentity?
    @State private var attachment: ProductWorkspaceSceneAttachment?
    @State private var connectionFailed = false

    var body: some View {
        Group {
            if let attachment {
                RootView(workspace: attachment.workspace)
            } else if connectionFailed {
                ContentUnavailableView(
                    "Window Unavailable",
                    systemImage: "rectangle.on.rectangle.slash",
                    description: Text("Close this window and open a new one.")
                )
            } else {
                ProgressView()
            }
        }
        #if os(macOS)
        .frame(
            minWidth: CGFloat(ProductWorkspaceWindowSizingPolicy.macOSMinimumSize.width),
            minHeight: CGFloat(ProductWorkspaceWindowSizingPolicy.macOSMinimumSize.height)
        )
        #endif
        .onAppear(perform: connect)
        .onDisappear(perform: disconnect)
    }

    private func connect() {
        guard attachment == nil else { return }
        do {
            let attachment = try appModel.connectProductWorkspaceScene(
                restoring: sceneIdentity,
                supportsMultipleWindows: supportsMultipleWindows
            )
            self.attachment = attachment
            connectionFailed = false
            if supportsMultipleWindows, sceneIdentity != attachment.identity {
                sceneIdentity = attachment.identity
            }
        } catch {
            connectionFailed = true
        }
    }

    private func disconnect() {
        guard let attachment else { return }
        self.attachment = nil
        Task { @MainActor in
            _ = await appModel.disconnectProductWorkspaceScene(attachment)
        }
    }
}
#endif
