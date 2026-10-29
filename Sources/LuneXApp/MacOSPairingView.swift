#if os(macOS)
import SwiftUI

struct MacOSPairingView: View {
    @Environment(AppModel.self) private var appModel
    @FocusState private var pinFocused: Bool
    @State private var displayedPIN = ""
    let workspace: ProductWorkspaceReference

    var body: some View {
        let host = appModel.selectedHost(in: workspace)
        let pairing = appModel.pairingState(for: workspace) ?? PairingUIState()
        let surface = ProductPairingSurface(
            selectedHost: host,
            pairing: pairing,
            transportAvailable: appModel.isPairingTransportAvailable,
            isPINValid: appModel.isPairingPINValid(in: workspace)
        )

        VStack(spacing: 22) {
            Image(systemName: "lock.shield")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            VStack(spacing: 6) {
                Text(host?.name ?? "Pair Host")
                    .font(.title.weight(.semibold))
                Text(pairingSubtitle(surface))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            pairingControls(surface: surface, host: host)
        }
        .frame(maxWidth: 460)
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(host?.name ?? "Pair Host")
        .onChange(of: surface.phase, initial: true) { _, phase in
            pinFocused = phase == .waitingForPIN
            if phase == .completed || phase == .cancelled || phase == .failed {
                displayedPIN = ""
            }
        }
        .onChange(of: host?.id) { _, _ in
            displayedPIN = ""
        }
    }

    @ViewBuilder
    private func pairingControls(
        surface: ProductPairingSurface,
        host: MoonlightHost?
    ) -> some View {
        switch surface.phase {
        case .noHost:
            EmptyView()
        case .ready:
            Button("Pair Host") {
                guard let host else { return }
                startPairing(host)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
        case .unavailable:
            issueLabel(surface.issue)
        case .preparing, .exchangingSecrets, .verifyingServer, .savingIdentity:
            VStack(spacing: 14) {
                if surface.phase == .exchangingSecrets, !displayedPIN.isEmpty {
                    Text(displayedPIN)
                        .font(.system(size: 36, weight: .semibold, design: .monospaced))
                        .textSelection(.enabled)
                        .accessibilityLabel("Pairing PIN")
                        .accessibilityValue(displayedPIN.map(String.init).joined(separator: " "))
                    Text("Enter this PIN in the Sunshine web interface on your host.")
                        .multilineTextAlignment(.center)
                }
                ProgressView()
                    .controlSize(.large)
                if surface.canCancel {
                    Button("Cancel") {
                        Task {
                            await appModel.cancelPairing(in: workspace)
                        }
                    }
                    .keyboardShortcut(.cancelAction)
                }
            }
        case .waitingForPIN:
            VStack(spacing: 14) {
                TextField("4-digit PIN", text: pinBinding)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .frame(width: 220)
                    .focused($pinFocused)
                    .accessibilityLabel("Pairing PIN")

                HStack(spacing: 10) {
                    Button("Cancel") {
                        Task {
                            await appModel.cancelPairing(in: workspace)
                        }
                    }
                    .keyboardShortcut(.cancelAction)

                    Button("Continue") {
                        Task {
                            await appModel.submitPairingPIN(in: workspace)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!surface.canSubmitPIN)
                }
            }
        case .completed:
            ProgressView("Opening applications...")
        case .cancelled:
            if surface.canStart, let host {
                Button("Pair Host") {
                    startPairing(host)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        case .failed:
            VStack(spacing: 12) {
                issueLabel(surface.issue)
                if surface.canRetry {
                    Button("Retry Pairing") {
                        guard let host else { return }
                        startPairing(host)
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                }
            }
        }
    }

    private var pinBinding: Binding<String> {
        Binding(
            get: { appModel.pairingState(for: workspace)?.pin ?? "" },
            set: { appModel.updatePairingPIN($0, in: workspace) }
        )
    }

    private func startPairing(_ host: MoonlightHost) {
        let pin = String(format: "%04d", Int.random(in: 0...9_999))
        displayedPIN = pin
        Task {
            await appModel.beginPairing(host: host, in: workspace, clientPIN: pin)
        }
    }

    private func pairingSubtitle(
        _ surface: ProductPairingSurface
    ) -> String {
        switch surface.phase {
        case .noHost: "Select a host to continue."
        case .ready: "Pair once to authorize this Mac with Sunshine."
        case .unavailable: "Pairing is unavailable in this build."
        case .preparing: "Preparing a secure pairing request..."
        case .waitingForPIN: "Choose a four-digit PIN, then enter the same PIN in Sunshine."
        case .exchangingSecrets: "Exchanging pairing credentials..."
        case .verifyingServer: "Verifying the host identity..."
        case .savingIdentity: "Saving the verified identity..."
        case .completed: "Pairing completed."
        case .cancelled: "Pair once to authorize this Mac with Sunshine."
        case .failed: "Pairing did not complete."
        }
    }

    @ViewBuilder
    private func issueLabel(_ issue: ProductIssue?) -> some View {
        if let issue {
            Label {
                Text(issue.presentation.message)
            } icon: {
                Image(systemName: issue.presentation.systemImage)
            }
            .foregroundStyle(issue.severity == .error ? Color.red : Color.orange)
            .multilineTextAlignment(.center)
        }
    }
}
#endif
