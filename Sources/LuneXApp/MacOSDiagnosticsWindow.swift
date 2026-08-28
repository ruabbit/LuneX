#if os(macOS)
import SwiftUI

struct MacOSDiagnosticsWindow: View {
    var body: some View {
        NavigationStack {
            DiagnosticsView()
                .navigationTitle("Diagnostics")
        }
        .frame(minWidth: 680, minHeight: 520)
    }
}

struct MacOSAppCommands: Commands {
    @FocusedValue(\.productWorkspaceReference) private var workspace
    let appModel: AppModel

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Add Host...") {
                guard let workspace else { return }
                _ = appModel.presentAddHostSheet(in: workspace)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(workspace == nil)
        }
    }
}

private struct ProductWorkspaceFocusedValueKey: FocusedValueKey {
    typealias Value = ProductWorkspaceReference
}

extension FocusedValues {
    var productWorkspaceReference: ProductWorkspaceReference? {
        get { self[ProductWorkspaceFocusedValueKey.self] }
        set { self[ProductWorkspaceFocusedValueKey.self] = newValue }
    }
}
#endif
