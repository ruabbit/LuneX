import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var appModel
    @State private var isShowingAddHost = false

    var body: some View {
        @Bindable var appModel = appModel

        NavigationStack {
            VStack(spacing: 0) {
                MetalStreamSurface(renderState: appModel.renderState)
                    .overlay(alignment: .topLeading) {
                        StreamStatusOverlay(session: appModel.session, diagnostics: appModel.diagnostics)
                            .padding(16)
                    }

                Divider()

                HostLibraryView(hosts: $appModel.hosts)
            }
            .navigationTitle("LuneX")
            .task {
                await appModel.loadHosts()
            }
            .sheet(isPresented: $isShowingAddHost) {
                AddHostSheet { name, address in
                    Task {
                        await appModel.addManualHost(name: name, address: address)
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        isShowingAddHost = true
                    } label: {
                        Label("Add Host", systemImage: "plus")
                    }

                    Button {
                        appModel.toggleDemoSession()
                    } label: {
                        Label(appModel.session.isStreaming ? "Stop" : "Start", systemImage: appModel.session.isStreaming ? "stop.fill" : "play.fill")
                    }
                }
            }
        }
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
            .frame(width: 360, height: 180)
            #endif
        }
    }
}

private struct HostLibraryView: View {
    @Binding var hosts: [MoonlightHost]

    var body: some View {
        List {
            Section("Hosts") {
                if hosts.isEmpty {
                    ContentUnavailableView("No Hosts", systemImage: "desktopcomputer", description: Text("Add or discover a Sunshine or GameStream host."))
                } else {
                    ForEach(hosts) { host in
                        HStack {
                            Image(systemName: host.pairingState == .paired ? "checkmark.seal.fill" : "lock")
                                .foregroundStyle(host.pairingState == .paired ? .green : .secondary)
                            VStack(alignment: .leading) {
                                Text(host.name)
                                Text(host.address)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(host.reachability.label)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(minHeight: 180)
    }
}

private struct StreamStatusOverlay: View {
    let session: StreamingSessionState
    let diagnostics: DiagnosticsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(session.phase.label, systemImage: session.isStreaming ? "dot.radiowaves.left.and.right" : "moon")
                .font(.headline)
            Text(diagnostics.latestSummary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(10)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
