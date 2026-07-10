import XCTest

@MainActor
final class AppModelWorkflowTests: XCTestCase {
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
            clientUniqueID: "test-client",
            remoteInputKey: RemoteInputKeyMaterial(keyID: 7, key: Data([0xAA, 0xBB]))
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
            clientUniqueID: "test-client",
            remoteInputKey: RemoteInputKeyMaterial(keyID: 7, key: Data([0xAA, 0xBB]))
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
    func fetchApps(from endpoint: HostEndpoint, clientUniqueID: String) async throws -> [RemoteApp] {
        [
            RemoteApp(id: "2", name: "Game", supportsHDR: true, installPath: nil),
            RemoteApp(id: "1", name: "Desktop", supportsHDR: false, installPath: nil)
        ]
    }

    func fetchArtwork(for app: RemoteApp, from endpoint: HostEndpoint, clientUniqueID: String) async throws -> RemoteAppArtwork? {
        nil
    }
}

private actor StubStreamLaunchClient: StreamLaunchClient {
    private var launchCount = 0

    func launch(_ request: StreamLaunchRequest, parameters: StreamNegotiationParameters) async throws -> StreamLaunchResponse {
        launchCount += 1
        return StreamLaunchResponse(
            sessionURL: "rtsp://test/session",
            gameSessionID: "session-1",
            rawValues: ["sessionurl": "rtsp://test/session"]
        )
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {
    }

    func currentLaunchCount() -> Int {
        launchCount
    }
}
