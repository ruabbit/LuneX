import XCTest

@MainActor
final class AppModelWorkflowTests: XCTestCase {
    func testHostPairingCatalogLaunchAndStopWorkflow() async throws {
        let hostRepository = InMemoryHostRepository()
        let hostManager = HostLibraryManager(
            repository: hostRepository,
            serverInfoClient: StubServerInfoClient()
        )
        let catalogManager = AppCatalogManager(
            appListClient: StubAppListClient(),
            artworkCache: InMemoryArtworkCache()
        )
        let streamCoordinator = StreamSessionCoordinator(
            launchClient: StubStreamLaunchClient()
        )
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

        XCTAssertEqual(model.selectedHost?.pairingState, .paired)
        XCTAssertEqual(model.session.phase, .disconnected)

        await model.refreshAppsForSelectedHost()
        XCTAssertEqual(model.selectedApps.map(\.name), ["Desktop", "Game"])
        XCTAssertEqual(model.selectedApp?.name, "Desktop")

        await model.launchSelectedApp()
        XCTAssertTrue(model.session.isStreaming)
        XCTAssertEqual(model.navigationSelection, .stream)

        await model.stopStream()
        XCTAssertEqual(model.session.phase, .disconnected)
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

private struct StubStreamLaunchClient: StreamLaunchClient {
    func launch(_ request: StreamLaunchRequest, parameters: StreamNegotiationParameters) async throws -> StreamLaunchResponse {
        StreamLaunchResponse(
            sessionURL: "rtsp://test/session",
            gameSessionID: "session-1",
            rawValues: ["sessionurl": "rtsp://test/session"]
        )
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {
    }
}
