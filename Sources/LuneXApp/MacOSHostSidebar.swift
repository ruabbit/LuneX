#if os(macOS)
import SwiftUI

struct MacOSHostSidebar: View {
    @Environment(AppModel.self) private var appModel
    let workspace: ProductWorkspaceReference
    let onAddHost: () -> Void

    var body: some View {
        List(selection: selectedHostID) {
            ForEach(appModel.hosts) { host in
                MacOSHostSidebarRow(host: host)
                    .tag(host.id)
                    .contextMenu {
                        hostContextMenu(host)
                    }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 0) {
                Divider()
                Button(action: onAddHost) {
                    Label("Add Host", systemImage: "plus")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .padding(12)
                .productActionTarget()
            }
            .background(.bar)
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
            .keyboardShortcut(.cancelAction)
        } message: {
            if let confirmation = currentHostConfirmation {
                Text(destructiveActionMessage(confirmation))
            }
        }
    }

    private var selectedHostID: Binding<MoonlightHost.ID?> {
        Binding(
            get: { appModel.selectedHostID(in: workspace) },
            set: { hostID in
                _ = appModel.setSelectedHostID(hostID, in: workspace)
            }
        )
    }

    @ViewBuilder
    private func hostContextMenu(_ host: MoonlightHost) -> some View {
        if host.pairingState != .paired {
            Button {
                select(host)
                Task {
                    await appModel.beginPairing(host: host, in: workspace)
                }
            } label: {
                Label("Pair", systemImage: "lock.open")
            }
            .disabled(host.reachability != .online)
        }

        Button {
            select(host)
            appModel.requestHostTrustReset(in: workspace)
        } label: {
            Label("Reset Trust", systemImage: "checkmark.shield")
        }
        .disabled(host.pairingState != .paired)

        Divider()

        Button(role: .destructive) {
            select(host)
            appModel.requestHostRemoval(in: workspace)
        } label: {
            Label("Remove Host", systemImage: "trash")
        }
    }

    private func select(_ host: MoonlightHost) {
        _ = appModel.setSelectedHostID(host.id, in: workspace)
    }

    private var currentHostConfirmation: ProductHostDestructiveConfirmation? {
        guard case let .awaitingConfirmation(confirmation) =
            appModel.hostDestructiveState(for: workspace),
              let state = appModel.workspaceState(for: workspace) else {
            return nil
        }
        switch state.presentation.dialog {
        case let .removeHost(dialogConfirmation),
             let .resetHostTrust(dialogConfirmation):
            return dialogConfirmation == confirmation ? confirmation : nil
        case .stopStream, nil:
            return nil
        }
    }

    private var hostConfirmationPresented: Binding<Bool> {
        Binding(
            get: { currentHostConfirmation != nil },
            set: { isPresented in
                guard !isPresented,
                      appModel.hostDestructiveState(for: workspace)?
                        .isPerforming != true else { return }
                appModel.cancelHostDestructiveAction(in: workspace)
            }
        )
    }

    private func destructiveActionLabel(
        _ confirmation: ProductHostDestructiveConfirmation
    ) -> String {
        switch (confirmation.kind, confirmation.requiresSessionStop) {
        case (.remove, true): "Stop and Remove"
        case (.remove, false): "Remove Host"
        case (.resetTrust, true): "Stop and Reset Trust"
        case (.resetTrust, false): "Reset Trust"
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

private struct MacOSHostSidebarRow: View {
    let host: MoonlightHost

    var body: some View {
        HStack(spacing: 10) {
            reachabilityIndicator
                .frame(width: 12, height: 12)

            Text(host.name)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if host.pairingState != .paired {
                Image(systemName: "lock.fill")
                    .foregroundStyle(.secondary)
                    .help("Pairing required")
                    .accessibilityLabel("Pairing required")
            }
        }
        .padding(.vertical, 3)
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var reachabilityIndicator: some View {
        switch host.reachability {
        case .unknown:
            ProgressView()
                .controlSize(.mini)
                .help("Checking availability")
                .accessibilityLabel("Checking availability")
        case .online:
            Image(systemName: "circle.fill")
                .font(.system(size: 9))
                .foregroundStyle(.green)
                .help("Online")
                .accessibilityLabel("Online")
        case .offline:
            Image(systemName: "circle.fill")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
                .help("Offline")
                .accessibilityLabel("Offline")
        }
    }

    private var accessibilityValue: String {
        let reachability = switch host.reachability {
        case .unknown: "Checking availability"
        case .online: "Online"
        case .offline: "Offline"
        }
        return host.pairingState == .paired
            ? reachability
            : "\(reachability), pairing required"
    }
}
#endif
