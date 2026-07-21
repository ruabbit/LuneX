import XCTest

@MainActor
final class AppModelWorkflowTests: XCTestCase {
    func testProviderAvailabilityIsDerivedFromInjectedInventory() {
        let unavailable = RuntimeProviderInventory.unavailable
        XCTAssertEqual(unavailable.availability, [])
        XCTAssertFalse(unavailable.availability.pairingTransportAvailable)
        XCTAssertFalse(unavailable.availability.streamTransportAvailable)

        let production = ProductionRuntimeProviderFactory.makeDefault()
        XCTAssertEqual(production.availability, [.pairing, .sessionControl, .remoteInput])
        XCTAssertTrue(production.availability.pairingTransportAvailable)
        XCTAssertFalse(production.availability.streamTransportAvailable)

        let complete = RuntimeProviderInventory(
            pairing: production.pairing,
            sessionControl: production.sessionControl,
            videoReceive: AvailabilityVideoReceiveProvider(),
            audioReceive: AvailabilityAudioReceiveProvider(),
            remoteInput: production.remoteInput
        )
        XCTAssertEqual(complete.availability, [
            .pairing,
            .sessionControl,
            .videoReceive,
            .audioReceive,
            .remoteInput
        ])
        XCTAssertTrue(complete.availability.streamTransportAvailable)

        let withoutPairing = RuntimeProviderInventory(
            sessionControl: complete.sessionControl,
            videoReceive: complete.videoReceive,
            audioReceive: complete.audioReceive,
            remoteInput: complete.remoteInput
        )
        XCTAssertFalse(withoutPairing.availability.pairingTransportAvailable)
        XCTAssertTrue(withoutPairing.availability.streamTransportAvailable)

        let missingRequiredProvider = [
            RuntimeProviderInventory(
                videoReceive: complete.videoReceive,
                audioReceive: complete.audioReceive,
                remoteInput: complete.remoteInput
            ),
            RuntimeProviderInventory(
                sessionControl: complete.sessionControl,
                audioReceive: complete.audioReceive,
                remoteInput: complete.remoteInput
            ),
            RuntimeProviderInventory(
                sessionControl: complete.sessionControl,
                videoReceive: complete.videoReceive,
                remoteInput: complete.remoteInput
            ),
            RuntimeProviderInventory(
                sessionControl: complete.sessionControl,
                videoReceive: complete.videoReceive,
                audioReceive: complete.audioReceive
            )
        ]
        XCTAssertTrue(missingRequiredProvider.allSatisfy {
            !$0.availability.streamTransportAvailable
        })
    }

    func testAppModelAppliesPlatformLifecycleToRenderState() {
        let model = AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(),
                serverInfoClient: StubServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: StubAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(launchClient: StubStreamLaunchClient()),
            clientIdentityStore: InMemoryClientIdentityStore()
        )
        let lifecycle = PlatformLifecycleState()
        lifecycle.isStreamActive = true
        lifecycle.isVisible = true
        lifecycle.isFocused = false
        lifecycle.drawableSize = PixelSize(width: 2560, height: 1440)
        lifecycle.headroom = DisplayHeadroom(potential: 2.0, current: 1.5, reference: 1.0)
        lifecycle.updateRenderPolicy()

        model.applyPlatformLifecycle(lifecycle)

        XCTAssertEqual(model.renderState.policy, .throttled(reason: "Window or scene not focused"))
        XCTAssertEqual(model.renderState.transform.drawableSize, PixelSize(width: 2560, height: 1440))
        XCTAssertEqual(model.renderState.headroom, lifecycle.headroom)
    }

    func testUnavailablePairingPreservesHostState() async throws {
        let hostRepository = InMemoryHostRepository()
        let hostManager = HostLibraryManager(
            repository: hostRepository,
            serverInfoClient: StubServerInfoClient()
        )
        let catalogManager = AppCatalogManager(
            appListClient: StubAppListClient(),
            artworkCache: InMemoryArtworkCache()
        )
        let streamCoordinator = StreamSessionCoordinator(launchClient: StubStreamLaunchClient())
        let model = AppModel(
            hostLibraryManager: hostManager,
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: catalogManager,
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: streamCoordinator,
            runtimeProviders: .unavailable,
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientUniqueID: "test-client",
            remoteInputKey: RemoteInputKeyMaterial(
                keyID: 7,
                key: Data(repeating: 0xAA, count: 16)
            )
        )

        await model.addManualHost(name: nil, address: "moon.local")
        XCTAssertEqual(model.hosts.count, 1)
        XCTAssertEqual(model.selectedHost?.name, "Test Host")

        let host = try XCTUnwrap(model.selectedHost)
        model.beginPairing(host: host)
        model.pairingUI.pin = "1234"
        await model.submitPairingPIN()

        XCTAssertEqual(model.selectedHost?.pairingState, .unpaired)
        XCTAssertNil(model.selectedHost?.pinnedIdentity)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertTrue(model.pairingUI.message?.contains("unavailable") == true)
    }

    func testUnavailableTransportDoesNotLaunchOrReportStreaming() async throws {
        let host = MoonlightHost(
            id: UUID(uuidString: "2A666A9A-2C77-451B-B2B1-73E697AE7D5C")!,
            name: "Test Host",
            address: "moon.local",
            pairingState: .paired,
            reachability: .online,
            pinnedIdentity: PinnedHostIdentity(
                certificateSHA256: "existing-cert",
                serverCertificateDER: Data([1, 2, 3]),
                pairedAt: Date(timeIntervalSince1970: 10)
            )
        )
        let hostManager = HostLibraryManager(
            repository: InMemoryHostRepository(hosts: [host]),
            serverInfoClient: StubServerInfoClient()
        )
        let catalogManager = AppCatalogManager(
            appListClient: StubAppListClient(),
            artworkCache: InMemoryArtworkCache()
        )
        let launchClient = StubStreamLaunchClient()
        let model = AppModel(
            hostLibraryManager: hostManager,
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: catalogManager,
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(launchClient: launchClient),
            runtimeProviders: .unavailable,
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientUniqueID: "test-client",
            remoteInputKey: RemoteInputKeyMaterial(
                keyID: 7,
                key: Data(repeating: 0xAA, count: 16)
            )
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        XCTAssertEqual(model.selectedApps.map(\.name), ["Desktop", "Game"])
        XCTAssertEqual(model.selectedApp?.name, "Desktop")

        await model.launchSelectedApp()
        XCTAssertFalse(model.session.isStreaming)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertEqual(model.navigationSelection, .library)
        XCTAssertTrue(model.streamLaunchUI.errorMessage?.contains("unavailable") == true)
        let launchCount = await launchClient.currentLaunchCount()
        XCTAssertEqual(launchCount, 0)
    }

    func testLaunchAcceptanceAloneNeverReportsStreaming() async throws {
        let host = MoonlightHost(
            id: UUID(uuidString: "E7919769-7548-45D0-AF14-B516694D7AE5")!,
            name: "Test Host",
            address: "moon.local",
            pairingState: .paired,
            reachability: .online,
            pinnedIdentity: PinnedHostIdentity(
                certificateSHA256: "existing-cert",
                serverCertificateDER: Data([1, 2, 3]),
                pairedAt: Date(timeIntervalSince1970: 10)
            )
        )
        let launchClient = StubStreamLaunchClient()
        let model = AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(hosts: [host]),
                serverInfoClient: StubServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: StubAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(launchClient: launchClient),
            runtimeProviders: completeStreamProviderInventory(),
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientUniqueID: "test-client",
            remoteInputKey: RemoteInputKeyMaterial(keyID: 7, key: Data(repeating: 0xAA, count: 16))
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        await model.launchSelectedApp()

        XCTAssertFalse(model.session.isStreaming)
        guard case .failed = model.session.phase else {
            return XCTFail("Launch-only flow must fail closed while the session provider is disconnected.")
        }
        XCTAssertEqual(model.navigationSelection, .library)
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertTrue(model.streamLaunchUI.errorMessage?.contains("no session control provider") == true)
        let launchCount = await launchClient.currentLaunchCount()
        XCTAssertEqual(launchCount, 1)
    }

    func testDefaultInputKeyGenerationUsesFreshMaterialForEveryLaunch() async throws {
        let firstKey = RemoteInputKeyMaterial(keyID: 1, key: Data(repeating: 0x11, count: 16))
        let secondKey = RemoteInputKeyMaterial(keyID: 2, key: Data(repeating: 0x22, count: 16))
        let keyGenerator = ScriptedInputKeyGenerator(results: [.success(firstKey), .success(secondKey)])
        let launchClient = StubStreamLaunchClient()
        let model = makeLaunchReadyModel(
            launchClient: launchClient,
            remoteInputKeyGenerator: keyGenerator
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        await model.launchSelectedApp()
        await model.stopStream()
        await model.launchSelectedApp()

        let launchedKeys = await launchClient.currentLaunchedKeys()
        XCTAssertEqual(launchedKeys, [firstKey, secondKey])
        XCTAssertEqual(keyGenerator.currentGenerationCount(), 2)
    }

    func testInputKeyGenerationFailureStopsBeforeNetworkLaunch() async throws {
        let keyGenerator = ScriptedInputKeyGenerator(results: [.failure(InputKeyGeneratorTestError.failed)])
        let launchClient = StubStreamLaunchClient()
        let model = makeLaunchReadyModel(
            launchClient: launchClient,
            remoteInputKeyGenerator: keyGenerator
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        await model.launchSelectedApp()

        let launchCount = await launchClient.currentLaunchCount()
        XCTAssertEqual(launchCount, 0)
        XCTAssertEqual(keyGenerator.currentGenerationCount(), 1)
        guard case .failed = model.session.phase else {
            return XCTFail("Input-key generation failure must fail the session before launch.")
        }
        XCTAssertTrue(model.streamLaunchUI.errorMessage?.contains("failed") == true)
        XCTAssertEqual(model.renderState.policy, .idle)
    }

    private func makeLaunchReadyModel(
        launchClient: StubStreamLaunchClient,
        remoteInputKeyGenerator: any RemoteInputKeyMaterialGenerating
    ) -> AppModel {
        let host = MoonlightHost(
            id: UUID(uuidString: "45F0C9CB-D795-49B2-A733-F68397632233")!,
            name: "Test Host",
            address: "moon.local",
            pairingState: .paired,
            reachability: .online,
            pinnedIdentity: PinnedHostIdentity(
                certificateSHA256: "existing-cert",
                serverCertificateDER: Data([1, 2, 3]),
                pairedAt: Date(timeIntervalSince1970: 10)
            )
        )
        return AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(hosts: [host]),
                serverInfoClient: StubServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: StubAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(launchClient: launchClient),
            runtimeProviders: completeStreamProviderInventory(),
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientUniqueID: "test-client",
            remoteInputKeyGenerator: remoteInputKeyGenerator
        )
    }

    private func completeStreamProviderInventory() -> RuntimeProviderInventory {
        let production = ProductionRuntimeProviderFactory.makeDefault()
        return RuntimeProviderInventory(
            pairing: production.pairing,
            sessionControl: production.sessionControl,
            videoReceive: AvailabilityVideoReceiveProvider(),
            audioReceive: AvailabilityAudioReceiveProvider(),
            remoteInput: production.remoteInput
        )
    }
}

private struct StubServerInfoClient: ServerInfoClient {
    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        ServerInfo(
            name: "Test Host",
            uniqueID: "host-1",
            macAddress: nil,
            state: "ONLINE",
            supportsHDR: true,
            rawValues: [:]
        )
    }
}

private struct StubAppListClient: AppListClient {
    func fetchApps(from endpoint: HostEndpoint, clientUniqueID: String, pinnedIdentity: PinnedHostIdentity?) async throws -> [RemoteApp] {
        [
            RemoteApp(id: "2", name: "Game", supportsHDR: true, installPath: nil),
            RemoteApp(id: "1", name: "Desktop", supportsHDR: false, installPath: nil)
        ]
    }

    func fetchArtwork(for app: RemoteApp, from endpoint: HostEndpoint, clientUniqueID: String, pinnedIdentity: PinnedHostIdentity?) async throws -> RemoteAppArtwork? {
        nil
    }
}

private actor StubStreamLaunchClient: StreamLaunchClient {
    private var launchCount = 0
    private var launchedKeys: [RemoteInputKeyMaterial] = []

    func launch(_ request: StreamLaunchRequest, parameters: StreamNegotiationParameters) async throws -> StreamLaunchResponse {
        launchCount += 1
        launchedKeys.append(request.remoteInputKey)
        return StreamLaunchResponse(
            sessionURL: "rtsp://test/session",
            gameSessionID: "session-1",
            rawValues: ["sessionurl": "rtsp://test/session"]
        )
    }

    func resume(_ request: StreamLaunchRequest, parameters: StreamNegotiationParameters) async throws -> StreamLaunchResponse {
        StreamLaunchResponse(
            sessionURL: "rtsp://test/session",
            gameSessionID: nil,
            rawValues: ["resume": "1"]
        )
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {
    }

    func currentLaunchCount() -> Int {
        launchCount
    }

    func currentLaunchedKeys() -> [RemoteInputKeyMaterial] {
        launchedKeys
    }
}

private final class ScriptedInputKeyGenerator: RemoteInputKeyMaterialGenerating, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<RemoteInputKeyMaterial, Error>]
    private var generationCount = 0

    init(results: [Result<RemoteInputKeyMaterial, Error>]) {
        self.results = results
    }

    func generate() throws -> RemoteInputKeyMaterial {
        lock.lock()
        defer { lock.unlock() }
        generationCount += 1
        guard !results.isEmpty else {
            throw InputKeyGeneratorTestError.exhausted
        }
        return try results.removeFirst().get()
    }

    func currentGenerationCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return generationCount
    }
}

private enum InputKeyGeneratorTestError: Error {
    case failed
    case exhausted
}

private struct AvailabilityVideoReceiveProvider: VideoReceiveProvider {
    func receiveVideo(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedVideoStreamConfiguration
    ) async -> AsyncThrowingStream<VideoReceiveEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func stopVideo(sessionID: UUID) async {
    }
}

private struct AvailabilityAudioReceiveProvider: AudioReceiveProvider {
    func receiveAudio(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedAudioStreamConfiguration
    ) async -> AsyncThrowingStream<AudioReceiveEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func stopAudio(sessionID: UUID) async {
    }
}
