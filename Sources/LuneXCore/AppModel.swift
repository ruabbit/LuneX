import Foundation
import Observation
import OSLog

enum AppNavigationSelection: Hashable {
    case library
    case stream
    case diagnostics
    case settings
}

struct PairingUIState: Equatable {
    var hostID: MoonlightHost.ID?
    var attemptID: UUID?
    var stage: PairingStage = .idle
    var pin: String = ""
    var isRunning = false
    var message: String?
}

private enum PairingApplicationError: Error {
    case incompleteRuntimeStream
    case invalidAuthenticatedCompletion
}

private enum SessionApplicationError: Error {
    case incompleteControlStream
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

struct RuntimeProviderAvailability: OptionSet, Equatable, Sendable {
    let rawValue: UInt8

    static let pairing = RuntimeProviderAvailability(rawValue: 1 << 0)
    static let sessionControl = RuntimeProviderAvailability(rawValue: 1 << 1)
    static let videoReceive = RuntimeProviderAvailability(rawValue: 1 << 2)
    static let audioReceive = RuntimeProviderAvailability(rawValue: 1 << 3)
    static let remoteInput = RuntimeProviderAvailability(rawValue: 1 << 4)
    static let requiredStream: RuntimeProviderAvailability = [
        .sessionControl,
        .videoReceive,
        .audioReceive,
        .remoteInput
    ]

    var pairingTransportAvailable: Bool {
        contains(.pairing)
    }

    var streamTransportAvailable: Bool {
        contains(.requiredStream)
    }
}

struct RuntimeProviderInventory: Sendable {
    let pairing: (any PairingRuntimeProvider)?
    let sessionControl: (any SessionControlProvider)?
    let videoReceive: (any VideoReceiveProvider)?
    let audioReceive: (any AudioReceiveProvider)?
    let remoteInput: (any RemoteInputProvider)?

    init(
        pairing: (any PairingRuntimeProvider)? = nil,
        sessionControl: (any SessionControlProvider)? = nil,
        videoReceive: (any VideoReceiveProvider)? = nil,
        audioReceive: (any AudioReceiveProvider)? = nil,
        remoteInput: (any RemoteInputProvider)? = nil
    ) {
        self.pairing = pairing
        self.sessionControl = sessionControl
        self.videoReceive = videoReceive
        self.audioReceive = audioReceive
        self.remoteInput = remoteInput
    }

    var availability: RuntimeProviderAvailability {
        var result: RuntimeProviderAvailability = []
        if pairing != nil { result.insert(.pairing) }
        if sessionControl != nil { result.insert(.sessionControl) }
        if videoReceive != nil { result.insert(.videoReceive) }
        if audioReceive != nil { result.insert(.audioReceive) }
        if remoteInput != nil { result.insert(.remoteInput) }
        return result
    }

    static let unavailable = RuntimeProviderInventory()
}

enum ProductionRuntimeProviderFactory {
    static func makeDefault() -> RuntimeProviderInventory {
        let controlChannel = MoonlightControlChannel()
        let pairingProvider = PersistingPairingProvider(
            provider: MoonlightPairingProvider(),
            repository: JSONFileHostRepository(fileURL: AppStorageLocations.hostsFile)
        )
        return RuntimeProviderInventory(
            pairing: pairingProvider,
            sessionControl: MoonlightSessionControlProvider(controlChannel: controlChannel),
            remoteInput: MoonlightRemoteInputProvider(
                sender: controlChannel,
                feedbackSource: controlChannel
            )
        )
    }
}

@MainActor
@Observable
final class AppModel {
    private let logger = Logger(subsystem: "dev.lunex.client", category: "app.model")
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
    var latestRemoteInputFeedback: RemoteInputFeedback?

    let videoPresentationSource: StreamVideoPresentationSource

    private let hostLibraryManager: HostLibraryManager
    private let settingsRepository: AppSettingsRepository
    private let appCatalogManager: AppCatalogManager
    private let appCatalogRepository: AppCatalogSnapshotRepository
    private let streamSessionCoordinator: StreamSessionCoordinator
    private let runtimeProviders: RuntimeProviderInventory
    private let sessionMediaEnvironment: any SessionMediaEnvironment
    private let clientIdentityStore: any ClientIdentityStore
    private let clientIdentityProvisioner: any ClientIdentityProvisioning
    private var clientUniqueID: String
    private var preparedPairingIdentity: ClientIdentityMaterial?
    private var activeStreamSessionID: UUID?
    private var activeMediaSessionID: UUID?
    private var activeControlReadiness: SessionChannelReadiness = []
    private var activeMediaReadiness: SessionChannelReadiness = []
    private var mediaConsumerTask: Task<Void, Never>?
    private let remoteInputKeyOverride: RemoteInputKeyMaterial?
    private let remoteInputKeyGenerator: any RemoteInputKeyMaterialGenerating

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
        runtimeProviders: RuntimeProviderInventory = ProductionRuntimeProviderFactory.makeDefault(),
        sessionMediaEnvironment: (any SessionMediaEnvironment)? = nil,
        videoPresentationSource: StreamVideoPresentationSource? = nil,
        clientIdentityStore: any ClientIdentityStore = ClientIdentityStoreFactory.makeDefault(),
        clientIdentityProvisioner: (any ClientIdentityProvisioning)? = nil,
        clientUniqueID: String = "LuneX-\(UUID().uuidString)",
        remoteInputKey: RemoteInputKeyMaterial? = nil,
        remoteInputKeyGenerator: any RemoteInputKeyMaterialGenerating = SecureRemoteInputKeyMaterialGenerator()
    ) {
        self.hostLibraryManager = hostLibraryManager
        self.settingsRepository = settingsRepository
        self.appCatalogManager = appCatalogManager
        self.appCatalogRepository = appCatalogRepository
        self.streamSessionCoordinator = streamSessionCoordinator
        self.runtimeProviders = runtimeProviders
        let presentationSource = videoPresentationSource ?? StreamVideoPresentationSource()
        self.videoPresentationSource = presentationSource
        self.sessionMediaEnvironment = sessionMediaEnvironment
            ?? NativeSessionMediaEnvironment(
                videoReceiveProvider: runtimeProviders.videoReceive,
                audioReceiveProvider: runtimeProviders.audioReceive,
                remoteInputProvider: runtimeProviders.remoteInput,
                videoProcessorFactory: NativeSessionVideoProcessorFactory(
                    presentationSource: presentationSource
                ),
                audioProcessorFactory: NativeSessionAudioProcessorFactory()
            )
        self.clientIdentityStore = clientIdentityStore
        self.clientIdentityProvisioner = clientIdentityProvisioner
            ?? ClientIdentityManager(store: clientIdentityStore)
        self.clientUniqueID = clientUniqueID
        self.remoteInputKeyOverride = remoteInputKey
        self.remoteInputKeyGenerator = remoteInputKeyGenerator
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

    var runtimeProviderAvailability: RuntimeProviderAvailability {
        runtimeProviders.availability
    }

    var isPairingTransportAvailable: Bool {
        runtimeProviderAvailability.pairingTransportAvailable
    }

    var isStreamTransportAvailable: Bool {
        runtimeProviderAvailability.streamTransportAvailable
    }

    var hasActiveStreamSession: Bool {
        activeStreamSessionID != nil
    }

    var isPairingPINValid: Bool {
        let bytes = Array(pairingUI.pin.utf8)
        return bytes.count == 4 && bytes.allSatisfy { (48...57).contains($0) }
    }

    func loadInitialState() async {
        await loadClientIdentity()
        await loadSettings()
        await loadHosts()
        await loadCachedApps()
    }

    func loadClientIdentity() async {
        do {
            guard let identity = try await clientIdentityStore.loadIdentity() else {
                diagnostics.record("No persisted client identity; pairing remains unavailable", subsystem: "identity")
                logger.info("No persisted client identity in selected store")
                return
            }
            clientUniqueID = identity.id.uuidString
            diagnostics.record("Loaded persisted client identity", subsystem: "identity")
            logger.info("Loaded persisted client identity")
        } catch {
            diagnostics.record("Failed to load client identity: \(error)", subsystem: "identity")
            logger.error("Failed to load client identity: \(String(describing: error), privacy: .public)")
        }
    }

    func applyPlatformLifecycle(_ lifecycle: PlatformLifecycleState) {
        renderState.policy = lifecycle.renderPolicy
        renderState.transform.drawableSize = lifecycle.drawableSize
        renderState.headroom = lifecycle.headroom
    }

    func loadHosts() async {
        do {
            hosts = try await hostLibraryManager.loadHosts()
            if selectedHostID == nil {
                selectedHostID = hosts.first?.id
            }
            diagnostics.record("Loaded \(hosts.count) saved hosts")
            logger.info("Loaded \(self.hosts.count, privacy: .public) saved hosts")
        } catch {
            diagnostics.record("Failed to load hosts: \(error)", subsystem: "hosts")
            logger.error("Failed to load hosts: \(String(describing: error), privacy: .public)")
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

    func beginPairing(host: MoonlightHost) async {
        guard runtimeProviders.pairing != nil else {
            pairingUI = PairingUIState(
                hostID: host.id,
                stage: .failed,
                message: "Pairing is unavailable until authenticated Moonlight transport is installed."
            )
            session.phase = .disconnected
            diagnostics.record("Blocked placeholder pairing for \(host.name); pinned identity was preserved", subsystem: "pairing")
            return
        }

        await cancelPairing(showCancelledState: false)
        let attemptID = UUID()
        pairingUI = PairingUIState(
            hostID: host.id,
            attemptID: attemptID,
            stage: .idle,
            isRunning: true,
            message: "Preparing client identity..."
        )
        session.phase = .pairing(pin: "")
        preparedPairingIdentity = nil

        do {
            let identity = try await clientIdentityProvisioner.loadOrCreateIdentity(
                createdAt: Date()
            )
            guard pairingUI.attemptID == attemptID else { return }
            preparedPairingIdentity = identity
            clientUniqueID = identity.id.uuidString
            pairingUI.stage = .waitingForPIN
            pairingUI.isRunning = false
            pairingUI.message = "Enter the PIN shown on \(host.name)."
            diagnostics.record("Prepared client identity for pairing", subsystem: "pairing")
        } catch {
            guard pairingUI.attemptID == attemptID else { return }
            failPairingAttempt(
                attemptID: attemptID,
                message: "Client identity could not be prepared.",
                diagnostic: "Client identity preparation failed"
            )
        }
    }

    func submitPairingPIN() async {
        guard let hostID = pairingUI.hostID,
              let host = hosts.first(where: { $0.id == hostID }),
              let attemptID = pairingUI.attemptID
        else { return }

        guard !pairingUI.isRunning,
              pairingUI.stage == .waitingForPIN else {
            return
        }

        guard let provider = runtimeProviders.pairing else {
            failPairingAttempt(
                attemptID: attemptID,
                message: "Pairing is unavailable until authenticated Moonlight transport is installed.",
                diagnostic: "Pairing provider became unavailable"
            )
            return
        }
        guard let identity = preparedPairingIdentity else {
            failPairingAttempt(
                attemptID: attemptID,
                message: "Client identity is not ready. Start pairing again.",
                diagnostic: "Pairing request rejected without prepared identity"
            )
            return
        }

        let pin = pairingUI.pin
        guard isPairingPINValid else {
            pairingUI.message = "PIN must contain exactly four digits."
            return
        }

        let request = PairingRuntimeRequest(
            attemptID: attemptID,
            host: host,
            pin: pin,
            clientIdentity: identity
        )
        pairingUI.pin = ""
        pairingUI.isRunning = true
        pairingUI.stage = .exchangingSecrets
        pairingUI.message = pairingMessage(for: .exchangingSecrets, hostName: host.name)
        session.phase = .pairing(pin: "")

        var completedResult: PairingResult?
        do {
            let events = await provider.pair(request)
            for try await event in events {
                guard pairingUI.attemptID == attemptID else { return }
                switch event {
                case let .progress(snapshot):
                    guard snapshot.attemptID == attemptID,
                          snapshot.hostID == hostID else {
                        throw PairingApplicationError.invalidAuthenticatedCompletion
                    }
                    pairingUI.stage = snapshot.stage
                    pairingUI.message = snapshot.failure?.message
                        ?? pairingMessage(for: snapshot.stage, hostName: host.name)
                case let .completed(result):
                    try validatePairingCompletion(result, expectedHostID: hostID)
                    completedResult = result
                }
            }
            guard let result = completedResult else {
                throw PairingApplicationError.incompleteRuntimeStream
            }
            guard pairingUI.attemptID == attemptID else { return }
            applyPairingCompletion(result)
        } catch {
            guard pairingUI.attemptID == attemptID else { return }
            if let failure = error as? PairingFailure, failure.code == .cancelled {
                await cancelPairing(showCancelledState: true)
                return
            }
            failPairingAttempt(
                attemptID: attemptID,
                message: "Authenticated pairing failed. Try again.",
                diagnostic: "Authenticated pairing failed for \(host.name)"
            )
            await provider.cancelPairing(attemptID: attemptID)
        }
    }

    func cancelPairing() async {
        await cancelPairing(showCancelledState: true)
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

        guard activeStreamSessionID == nil else {
            return
        }

        guard isStreamTransportAvailable,
              let sessionControlProvider = runtimeProviders.sessionControl else {
            let message = "Streaming is unavailable until Moonlight media transport is installed."
            streamLaunchUI.errorMessage = message
            session.activeHostID = nil
            session.phase = .disconnected
            renderState.policy = .idle
            diagnostics.record("Blocked launch of \(app.name) on \(host.name): media transport unavailable", subsystem: "stream.transport")
            return
        }

        let request: StreamLaunchRequest
        do {
            let remoteInputKey = try remoteInputKeyOverride ?? remoteInputKeyGenerator.generate()
            request = StreamLaunchRequest(
                host: host,
                app: app,
                preferences: settings.stream,
                clientUniqueID: clientUniqueID,
                remoteInputKey: remoteInputKey,
                audioPlaybackMode: .clientOnly,
                controllerBitmap: 0,
                optimizeGameSettings: true
            )
        } catch {
            failStreamSession(error, sessionID: nil)
            return
        }

        let sessionID = UUID()
        var didPrepareSession = false
        do {
            let snapshot = try await streamSessionCoordinator.prepare(
                request,
                sessionID: sessionID
            )
            activeStreamSessionID = sessionID
            didPrepareSession = true
            activeControlReadiness = []
            activeMediaReadiness = []
            streamLaunchUI.isLaunching = true
            streamLaunchUI.errorMessage = nil
            session.activeHostID = host.id
            session.lastError = nil
            navigationSelection = .stream
            applySessionSnapshot(snapshot)

            var receivedTerminalEvent = false
            let events = await sessionControlProvider.start(
                sessionID: sessionID,
                request: request
            )
            for try await event in events {
                guard activeStreamSessionID == sessionID else { return }
                try await consumeSessionControlEvent(
                    event,
                    sessionID: sessionID,
                    sessionControlProvider: sessionControlProvider
                )
                if case .terminated = event {
                    receivedTerminalEvent = true
                }
            }

            guard activeStreamSessionID == sessionID else { return }
            guard receivedTerminalEvent else {
                throw SessionApplicationError.incompleteControlStream
            }
            activeStreamSessionID = nil
            streamLaunchUI.isLaunching = false
        } catch {
            guard activeStreamSessionID == nil || activeStreamSessionID == sessionID else {
                return
            }
            guard activeStreamSessionID == sessionID else {
                if !didPrepareSession {
                    failStreamSession(error, sessionID: nil)
                }
                return
            }
            await stopMediaEnvironment(sessionID: sessionID)
            _ = try? await streamSessionCoordinator.fail(
                error,
                sessionID: sessionID
            )
            failStreamSession(error, sessionID: sessionID)
            await sessionControlProvider.stop(sessionID: sessionID)
        }
    }

    func stopStream() async {
        guard let sessionID = activeStreamSessionID,
              let sessionControlProvider = runtimeProviders.sessionControl else {
            return
        }
        activeStreamSessionID = nil
        streamLaunchUI.isLaunching = false
        session.phase = .stopping
        _ = try? await streamSessionCoordinator.beginLocalStop(sessionID: sessionID)
        await stopMediaEnvironment(sessionID: sessionID)
        await sessionControlProvider.stop(sessionID: sessionID)
        _ = try? await streamSessionCoordinator.completeLocalStop(sessionID: sessionID)
        diagnostics.record("Stopped stream session", subsystem: "stream")
        session.activeHostID = nil
        session.lastError = nil
        session.phase = .disconnected
        renderState.policy = .idle
    }

    func sendRemoteInput(_ event: RemoteInputEvent) async throws {
        guard let sessionID = activeStreamSessionID,
              activeMediaSessionID == sessionID,
              activeMediaReadiness.contains(.input) else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        try await sessionMediaEnvironment.sendInput(event, sessionID: sessionID)
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

    private func cancelPairing(showCancelledState: Bool) async {
        guard let attemptID = pairingUI.attemptID else { return }
        let hostID = pairingUI.hostID
        pairingUI.attemptID = nil
        pairingUI.pin = ""
        pairingUI.isRunning = false
        preparedPairingIdentity = nil
        session.phase = .disconnected

        if showCancelledState {
            pairingUI.stage = .cancelled
            pairingUI.message = "Pairing was cancelled."
            diagnostics.record("Cancelled pairing attempt", subsystem: "pairing")
        } else if !showCancelledState {
            pairingUI = PairingUIState(hostID: hostID)
        }

        if let provider = runtimeProviders.pairing {
            await provider.cancelPairing(attemptID: attemptID)
        }
    }

    private func applyPairingCompletion(_ result: PairingResult) {
        if let index = hosts.firstIndex(where: { $0.id == result.host.id }) {
            hosts[index] = result.host
        } else {
            hosts.append(result.host)
        }
        selectedHostID = result.host.id
        pairingUI = PairingUIState(
            hostID: result.host.id,
            stage: .paired,
            message: "Paired with \(result.host.name)."
        )
        preparedPairingIdentity = nil
        session.phase = .disconnected
        diagnostics.record("Authenticated pairing completed", subsystem: "pairing")
    }

    private func failPairingAttempt(
        attemptID: UUID,
        message: String,
        diagnostic: String
    ) {
        guard pairingUI.attemptID == attemptID else { return }
        pairingUI.attemptID = nil
        pairingUI.stage = .failed
        pairingUI.pin = ""
        pairingUI.isRunning = false
        pairingUI.message = message
        preparedPairingIdentity = nil
        let failure = SessionError(subsystem: "pairing", message: message)
        session.phase = .failed(failure)
        diagnostics.record(diagnostic, subsystem: "pairing")
    }

    private func validatePairingCompletion(
        _ result: PairingResult,
        expectedHostID: MoonlightHost.ID
    ) throws {
        guard result.host.id == expectedHostID,
              result.host.pairingState == .paired,
              let pin = result.host.pinnedIdentity,
              pin.serverCertificateDER == result.serverIdentity.certificateDER,
              pin.certificateSHA256.caseInsensitiveCompare(
                  result.serverIdentity.certificateSHA256
              ) == .orderedSame else {
            throw PairingApplicationError.invalidAuthenticatedCompletion
        }
    }

    private func pairingMessage(for stage: PairingStage, hostName: String) -> String {
        switch stage {
        case .idle:
            return "Preparing pairing with \(hostName)..."
        case .waitingForPIN:
            return "Preparing PIN exchange with \(hostName)..."
        case .exchangingSecrets:
            return "Exchanging authenticated pairing secrets..."
        case .verifyingServer:
            return "Verifying the host identity..."
        case .pinningIdentity:
            return "Saving the verified host identity..."
        case .paired:
            return "Authenticated pairing completed."
        case .failed:
            return "Authenticated pairing failed."
        case .cancelled:
            return "Pairing was cancelled."
        }
    }

    private func applySessionSnapshot(_ snapshot: StreamSessionSnapshot) {
        switch snapshot.stage {
        case .idle, .disconnected:
            activeStreamSessionID = nil
            activeControlReadiness = []
            activeMediaReadiness = []
            streamLaunchUI.isLaunching = false
            session.activeHostID = nil
            session.lastError = nil
            session.phase = .disconnected
            renderState.policy = .idle
            if let reason = snapshot.terminationReason {
                diagnostics.record(reason, subsystem: "stream.control")
            }

        case .resolvingHost, .validatingPairing, .preparingParameters, .launching:
            session.phase = .connecting(stage: "Launching Stream")
            renderState.policy = .idle

        case .readyForTransport:
            session.phase = .connecting(stage: pendingTransportMessage(for: snapshot))
            renderState.policy = .idle

        case .streaming:
            streamLaunchUI.isLaunching = false
            session.phase = .streaming
            renderState.policy = .active
            updateRenderPreferences()

        case .reconnecting:
            streamLaunchUI.isLaunching = false
            let suffix = snapshot.reconnectAttempt.map { " (Attempt \($0))" } ?? ""
            session.phase = .connecting(stage: "Reconnecting\(suffix)")
            renderState.policy = .idle

        case .stopping:
            streamLaunchUI.isLaunching = false
            session.phase = .stopping
            renderState.policy = .idle

        case .failed:
            let message = snapshot.failure?.message ?? "Session control failed."
            failStreamSession(
                SessionError(subsystem: snapshot.failure?.subsystem ?? "stream", message: message),
                sessionID: snapshot.sessionID
            )
        }
    }

    private func consumeSessionControlEvent(
        _ event: SessionControlEvent,
        sessionID: UUID,
        sessionControlProvider: any SessionControlProvider
    ) async throws {
        switch event {
        case let .channelsReady(reportedReadiness):
            activeControlReadiness = reportedReadiness.intersection(.control)
            try await applyAggregatedReadiness(sessionID: sessionID)

        case let .negotiated(configuration):
            let snapshot = try await streamSessionCoordinator.apply(
                event,
                sessionID: sessionID
            )
            applySessionSnapshot(snapshot)
            _ = try await startMediaEnvironment(
                sessionID: sessionID,
                configuration: configuration,
                sessionControlProvider: sessionControlProvider
            )

        case .reconnecting:
            await stopMediaEnvironment(sessionID: sessionID)
            guard activeStreamSessionID == sessionID else { return }
            activeControlReadiness = []
            activeMediaReadiness = []
            let snapshot = try await streamSessionCoordinator.apply(
                event,
                sessionID: sessionID
            )
            applySessionSnapshot(snapshot)

        case let .videoColorMetadata(metadata):
            let snapshot = try await streamSessionCoordinator.apply(
                event,
                sessionID: sessionID
            )
            applySessionSnapshot(snapshot)
            if activeMediaSessionID == sessionID {
                try await sessionMediaEnvironment.updateVideoColorMetadata(
                    metadata,
                    sessionID: sessionID
                )
            }

        case .terminated:
            let snapshot = try await streamSessionCoordinator.apply(
                event,
                sessionID: sessionID
            )
            applySessionSnapshot(snapshot)
            await stopMediaEnvironment(sessionID: sessionID)

        case .launchAccepted, .rtspReady:
            let snapshot = try await streamSessionCoordinator.apply(
                event,
                sessionID: sessionID
            )
            applySessionSnapshot(snapshot)
        }
    }

    private func startMediaEnvironment(
        sessionID: UUID,
        configuration: NegotiatedSessionConfiguration,
        sessionControlProvider: any SessionControlProvider
    ) async throws -> Bool {
        guard activeMediaSessionID == nil else {
            throw SessionMediaEnvironmentError.sessionAlreadyActive
        }
        let events = try await sessionMediaEnvironment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: sessionControlProvider
        )
        guard activeStreamSessionID == sessionID else {
            _ = await sessionMediaEnvironment.stop(sessionID: sessionID)
            return false
        }
        latestRemoteInputFeedback = nil
        activeMediaSessionID = sessionID
        mediaConsumerTask = Task { [weak self] in
            do {
                for try await event in events {
                    try Task.checkCancellation()
                    guard let self else { return }
                    await self.consumeMediaEnvironmentEvent(
                        event,
                        sessionID: sessionID,
                        sessionControlProvider: sessionControlProvider
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                await self.failFromMediaEnvironment(
                    error,
                    sessionID: sessionID,
                    sessionControlProvider: sessionControlProvider
                )
            }
        }
        return true
    }

    private func consumeMediaEnvironmentEvent(
        _ event: SessionMediaEnvironmentEvent,
        sessionID: UUID,
        sessionControlProvider: any SessionControlProvider
    ) async {
        guard activeStreamSessionID == sessionID,
              activeMediaSessionID == sessionID else { return }
        switch event {
        case let .readiness(readiness):
            activeMediaReadiness = readiness.intersection([.video, .audio, .input])
            do {
                try await applyAggregatedReadiness(sessionID: sessionID)
            } catch {
                await failFromMediaEnvironment(
                    error,
                    sessionID: sessionID,
                    sessionControlProvider: sessionControlProvider
                )
            }
        case let .feedback(feedback):
            latestRemoteInputFeedback = feedback
        }
    }

    private func applyAggregatedReadiness(sessionID: UUID) async throws {
        let snapshot = try await streamSessionCoordinator.apply(
            .channelsReady(activeControlReadiness.union(activeMediaReadiness)),
            sessionID: sessionID
        )
        applySessionSnapshot(snapshot)
    }

    private func failFromMediaEnvironment(
        _ error: Error,
        sessionID: UUID,
        sessionControlProvider: any SessionControlProvider
    ) async {
        guard activeStreamSessionID == sessionID else { return }
        mediaConsumerTask = nil
        activeMediaSessionID = nil
        activeMediaReadiness = []
        activeControlReadiness = []
        latestRemoteInputFeedback = nil
        _ = await sessionMediaEnvironment.stop(sessionID: sessionID)
        _ = try? await streamSessionCoordinator.fail(error, sessionID: sessionID)
        failStreamSession(error, sessionID: sessionID)
        await sessionControlProvider.stop(sessionID: sessionID)
    }

    private func stopMediaEnvironment(sessionID: UUID) async {
        mediaConsumerTask?.cancel()
        mediaConsumerTask = nil
        activeMediaSessionID = nil
        activeMediaReadiness = []
        latestRemoteInputFeedback = nil
        _ = await sessionMediaEnvironment.stop(sessionID: sessionID)
    }

    private func pendingTransportMessage(for snapshot: StreamSessionSnapshot) -> String {
        guard snapshot.negotiatedConfiguration != nil else {
            return "Negotiating Stream Transport"
        }

        let healthy = snapshot.channelHealth.healthyChannels
        let required = snapshot.channelHealth.requiredChannels
        let channels: [(SessionChannelReadiness, String)] = [
            (.control, "Control"),
            (.video, "Video"),
            (.audio, "Audio"),
            (.input, "Input")
        ]
        let pending = channels.compactMap { channel, name in
            required.contains(channel) && !healthy.contains(channel) ? name : nil
        }
        return pending.isEmpty
            ? "Confirming Stream Readiness"
            : "Waiting for \(pending.joined(separator: ", "))"
    }

    private func failStreamSession(_ error: Error, sessionID: UUID?) {
        if let sessionID,
           activeStreamSessionID != nil,
           activeStreamSessionID != sessionID {
            return
        }

        let sessionError: SessionError
        if let error = error as? SessionError {
            sessionError = error
        } else if let failure = error as? StreamNegotiationFailure {
            sessionError = SessionError(
                subsystem: failure.subsystem,
                message: failure.message
            )
        } else if error is SessionApplicationError {
            sessionError = SessionError(
                subsystem: "stream.control",
                message: "Session control ended unexpectedly."
            )
        } else {
            sessionError = SessionError(
                subsystem: "stream.control",
                message: "Session control failed."
            )
        }

        activeStreamSessionID = nil
        activeMediaSessionID = nil
        activeControlReadiness = []
        activeMediaReadiness = []
        latestRemoteInputFeedback = nil
        streamLaunchUI.isLaunching = false
        streamLaunchUI.errorMessage = sessionError.message
        session.activeHostID = nil
        session.lastError = sessionError
        session.phase = .failed(sessionError)
        renderState.policy = .idle
        diagnostics.record(sessionError.message, subsystem: sessionError.subsystem)
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
