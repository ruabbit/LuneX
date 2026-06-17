import Foundation
import Observation

enum AppNavigationSelection: Hashable {
    case library
    case stream
    case diagnostics
    case settings
}

struct PairingUIState: Equatable {
    var hostID: MoonlightHost.ID?
    var pin: String = ""
    var isRunning = false
    var message: String?
}

struct AppCatalogUIState: Equatable {
    var isRefreshing = false
    var lastUpdatedAt: Date?
    var errorMessage: String?
}

struct StreamLaunchUIState: Equatable {
    var selectedAppID: RemoteApp.ID?
    var isLaunching = false
    var errorMessage: String?
}

@MainActor
@Observable
final class AppModel {
    var hosts: [MoonlightHost] = []
    var settings = AppSettings.defaults
    var session = StreamingSessionState()
    var renderState = StreamRenderState()
    var diagnostics = DiagnosticsStore()
    var navigationSelection: AppNavigationSelection = .library
    var selectedHostID: MoonlightHost.ID?
    var appsByHostID: [MoonlightHost.ID: [RemoteApp]] = [:]
    var pairingUI = PairingUIState()
    var appCatalogUI = AppCatalogUIState()
    var streamLaunchUI = StreamLaunchUIState()

    private let hostLibraryManager: HostLibraryManager
    private let settingsRepository: AppSettingsRepository
    private let appCatalogManager: AppCatalogManager
    private let appCatalogRepository: AppCatalogSnapshotRepository
    private let streamSessionCoordinator: StreamSessionCoordinator
    private let clientUniqueID: String
    private let remoteInputKey: RemoteInputKeyMaterial

    init(
        hostLibraryManager: HostLibraryManager = HostLibraryManager(
            repository: JSONFileHostRepository(fileURL: AppStorageLocations.hostsFile),
            serverInfoClient: HTTPServerInfoClient()
        ),
        settingsRepository: AppSettingsRepository = JSONFileAppSettingsRepository(fileURL: AppStorageLocations.settingsFile),
        appCatalogManager: AppCatalogManager = AppCatalogManager(
            appListClient: HTTPAppListClient(),
            artworkCache: InMemoryArtworkCache()
        ),
        appCatalogRepository: AppCatalogSnapshotRepository = JSONFileAppCatalogSnapshotRepository(fileURL: AppStorageLocations.appCatalogFile),
        streamSessionCoordinator: StreamSessionCoordinator = StreamSessionCoordinator(
            launchClient: HTTPStreamLaunchClient()
        ),
        clientUniqueID: String = "LuneX-\(UUID().uuidString)",
        remoteInputKey: RemoteInputKeyMaterial = RemoteInputKeyMaterial(
            keyID: 1,
            key: Data((0..<16).map { UInt8($0 + 1) })
        )
    ) {
        self.hostLibraryManager = hostLibraryManager
        self.settingsRepository = settingsRepository
        self.appCatalogManager = appCatalogManager
        self.appCatalogRepository = appCatalogRepository
        self.streamSessionCoordinator = streamSessionCoordinator
        self.clientUniqueID = clientUniqueID
        self.remoteInputKey = remoteInputKey
    }

    var selectedHost: MoonlightHost? {
        guard let selectedHostID else { return hosts.first }
        return hosts.first { $0.id == selectedHostID }
    }

    var selectedApps: [RemoteApp] {
        guard let hostID = selectedHost?.id else { return [] }
        return appsByHostID[hostID] ?? []
    }

    var selectedApp: RemoteApp? {
        selectedApps.first { $0.id == streamLaunchUI.selectedAppID } ?? selectedApps.first
    }

    func loadInitialState() async {
        await loadSettings()
        await loadHosts()
        await loadCachedApps()
    }

    func loadHosts() async {
        do {
            hosts = try await hostLibraryManager.loadHosts()
            if selectedHostID == nil {
                selectedHostID = hosts.first?.id
            }
            diagnostics.record("Loaded \(hosts.count) saved hosts")
        } catch {
            diagnostics.record("Failed to load hosts: \(error)", subsystem: "hosts")
        }
    }

    func loadSettings() async {
        do {
            settings = try await settingsRepository.loadSettings()
            updateRenderPreferences()
            diagnostics.record("Loaded stream and platform settings", subsystem: "settings")
        } catch {
            diagnostics.record("Failed to load settings: \(error)", subsystem: "settings")
        }
    }

    func loadCachedApps() async {
        do {
            let snapshots = try await appCatalogRepository.loadSnapshots()
            appsByHostID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.hostID, $0.apps) })
            if let selectedHostID, streamLaunchUI.selectedAppID == nil {
                streamLaunchUI.selectedAppID = appsByHostID[selectedHostID]?.first?.id
            }
            diagnostics.record("Loaded cached app lists for \(snapshots.count) hosts", subsystem: "apps")
        } catch {
            diagnostics.record("Failed to load cached apps: \(error)", subsystem: "apps")
        }
    }

    func saveSettings() async {
        do {
            try await settingsRepository.saveSettings(settings)
            updateRenderPreferences()
            diagnostics.record("Saved settings", subsystem: "settings")
        } catch {
            diagnostics.record("Failed to save settings: \(error)", subsystem: "settings")
        }
    }

    func addManualHost(name: String? = nil, address: String) async {
        do {
            hosts = try await hostLibraryManager.addManualHost(name: name, address: address)
            selectedHostID = hosts.first { $0.address == address }?.id ?? selectedHostID ?? hosts.first?.id
            diagnostics.record("Added host \(address)", subsystem: "hosts")
        } catch {
            diagnostics.record("Failed to add host \(address): \(error)", subsystem: "hosts")
        }
    }

    func removeSelectedHost() async {
        guard let hostID = selectedHost?.id else { return }
        do {
            hosts = try await hostLibraryManager.removeHost(id: hostID)
            appsByHostID[hostID] = nil
            if selectedHostID == hostID {
                selectedHostID = hosts.first?.id
            }
            diagnostics.record("Removed host", subsystem: "hosts")
        } catch {
            diagnostics.record("Failed to remove host: \(error)", subsystem: "hosts")
        }
    }

    func beginPairing(host: MoonlightHost) {
        pairingUI = PairingUIState(
            hostID: host.id,
            pin: "",
            isRunning: false,
            message: "Enter the PIN shown on \(host.name)."
        )
        session.phase = .pairing(pin: "")
    }

    func submitPairingPIN() async {
        guard let hostID = pairingUI.hostID,
              let host = hosts.first(where: { $0.id == hostID })
        else { return }

        pairingUI.isRunning = true
        defer { pairingUI.isRunning = false }

        do {
            let machine = PairingStateMachine(hostID: host.id)
            _ = await machine.begin(serverMajorVersion: 7)
            _ = try await machine.submitPIN(pairingUI.pin)
            _ = try await machine.markSecretsExchanged()
            let identity = PairingServerIdentity(
                certificateDER: Data(pairingUI.pin.utf8),
                certificateSHA256: "lunex-ui-skeleton-\(host.id.uuidString)",
                serverMajorVersion: 7
            )
            let result = try await machine.pinServerIdentity(identity, for: host)
            hosts = try await hostLibraryManager.replaceHost(result.host)
            selectedHostID = result.host.id
            pairingUI.message = "Pairing state saved. Full Moonlight transport will replace the current local skeleton."
            session.phase = .disconnected
            diagnostics.record("Paired \(result.host.name) using \(result.digestAlgorithm.rawValue)", subsystem: "pairing")
        } catch {
            pairingUI.message = "Pairing failed: \(error)"
            session.phase = .failed(SessionError(subsystem: "pairing", message: String(describing: error)))
            diagnostics.record("Pairing failed for \(host.name): \(error)", subsystem: "pairing")
        }
    }

    func refreshAppsForSelectedHost() async {
        guard let host = selectedHost else { return }
        guard host.pairingState == .paired else {
            appCatalogUI.errorMessage = "Pair the host before refreshing apps."
            diagnostics.record("App refresh requires a paired host", subsystem: "apps")
            return
        }

        appCatalogUI.isRefreshing = true
        appCatalogUI.errorMessage = nil
        defer { appCatalogUI.isRefreshing = false }

        do {
            let snapshot = try await appCatalogManager.refreshApps(for: host, clientUniqueID: clientUniqueID)
            appsByHostID[host.id] = snapshot.apps
            let snapshots = appsByHostID.map { hostID, apps in
                AppListSnapshot(hostID: hostID, apps: apps, updatedAt: hostID == host.id ? snapshot.updatedAt : Date())
            }
            try await appCatalogRepository.saveSnapshots(snapshots)
            streamLaunchUI.selectedAppID = snapshot.apps.first?.id
            appCatalogUI.lastUpdatedAt = snapshot.updatedAt
            diagnostics.record("Loaded \(snapshot.apps.count) apps from \(host.name)", subsystem: "apps")
        } catch {
            appCatalogUI.errorMessage = String(describing: error)
            diagnostics.record("Failed to refresh apps from \(host.name): \(error)", subsystem: "apps")
        }
    }

    func select(host: MoonlightHost) {
        selectedHostID = host.id
        streamLaunchUI.selectedAppID = appsByHostID[host.id]?.first?.id
    }

    func select(app: RemoteApp) {
        streamLaunchUI.selectedAppID = app.id
    }

    func launchSelectedApp() async {
        guard let host = selectedHost, let app = selectedApp else {
            streamLaunchUI.errorMessage = "Select a host and app first."
            return
        }

        streamLaunchUI.isLaunching = true
        streamLaunchUI.errorMessage = nil
        session.activeHostID = host.id
        session.phase = .connecting(stage: "Negotiating \(app.name)")
        updateRenderPreferences()
        defer { streamLaunchUI.isLaunching = false }

        let request = StreamLaunchRequest(
            host: host,
            app: app,
            preferences: settings.stream,
            clientUniqueID: clientUniqueID,
            remoteInputKey: remoteInputKey,
            audioPlaybackMode: .clientOnly,
            controllerBitmap: 0,
            optimizeGameSettings: true
        )

        do {
            _ = try await streamSessionCoordinator.launch(request)
            _ = try await streamSessionCoordinator.markTransportStarted()
            session.phase = .streaming
            renderState.policy = .active
            navigationSelection = .stream
            diagnostics.record("Streaming \(app.name) from \(host.name)", subsystem: "stream")
            diagnostics.record("Transport/media decode remains the next integration layer", subsystem: "stream.transport")
        } catch {
            let message = String(describing: error)
            streamLaunchUI.errorMessage = message
            session.lastError = SessionError(subsystem: "stream", message: message)
            session.phase = .failed(SessionError(subsystem: "stream", message: message))
            renderState.policy = .idle
            diagnostics.record("Launch failed: \(message)", subsystem: "stream")
        }
    }

    func stopStream() async {
        guard let host = selectedHost else {
            session.phase = .disconnected
            renderState.policy = .idle
            return
        }

        session.phase = .stopping
        do {
            _ = try await streamSessionCoordinator.stop(host: host, clientUniqueID: clientUniqueID)
            diagnostics.record("Stopped stream on \(host.name)", subsystem: "stream")
        } catch {
            diagnostics.record("Stop command failed: \(error)", subsystem: "stream")
        }
        session.phase = .disconnected
        renderState.policy = .idle
    }

    func toggleDemoSession() {
        if session.isStreaming {
            session.phase = .disconnected
            renderState.policy = .idle
            diagnostics.record("Stopped demo stream", subsystem: "stream")
        } else {
            session.phase = .streaming
            renderState.policy = .active
            updateRenderPreferences()
            diagnostics.record("Started demo stream", subsystem: "stream")
        }
    }

    private func updateRenderPreferences() {
        renderState.transform.sourceSize = PixelSize(width: settings.stream.width, height: settings.stream.height)
        renderState.transform.mode = settings.stream.scaleMode
        renderState.headroom = DisplayHeadroom(
            potential: settings.stream.hdrEnabled ? 1.5 : 1.0,
            current: settings.stream.hdrEnabled ? 1.25 : 1.0,
            reference: 1.0
        )
    }
}
