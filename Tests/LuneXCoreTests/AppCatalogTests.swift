import Foundation
import XCTest

final class AppCatalogTests: XCTestCase {
    func testAppListParserExtractsAppsAndSortsByName() throws {
        let xml = """
        <root status_code="200" status_message="OK">
          <App>
            <AppTitle>Steam</AppTitle>
            <ID>109</ID>
            <IsHdrSupported>1</IsHdrSupported>
            <AppInstallPath>C:\\Steam\\</AppInstallPath>
          </App>
          <App>
            <AppTitle>Desktop</AppTitle>
            <ID>0</ID>
            <IsHdrSupported>0</IsHdrSupported>
          </App>
        </root>
        """

        let apps = try AppListParser.parse(Data(xml.utf8))

        XCTAssertEqual(apps.map(\.name), ["Desktop", "Steam"])
        XCTAssertEqual(apps[1].id, "109")
        XCTAssertTrue(apps[1].supportsHDR)
        XCTAssertEqual(apps[1].installPath, "C:\\Steam\\")
    }

    func testAppListParserRejectsNonOKStatus() {
        let xml = """
        <root status_code="401" status_message="Device not paired"></root>
        """

        XCTAssertThrowsError(try AppListParser.parse(Data(xml.utf8))) { error in
            XCTAssertEqual(error as? AppCatalogError, .serverRejected("Device not paired"))
        }
    }

    func testCatalogManagerRefreshesAppsAndCachesArtwork() async throws {
        let host = MoonlightHost(
            id: UUID(uuidString: "7E725F13-9BD6-43CD-AC17-D5C57FDB83F2")!,
            name: "Studio PC",
            address: "192.168.1.50",
            pairingState: .paired,
            reachability: .online
        )
        let app = RemoteApp(id: "109", name: "Steam", supportsHDR: true, installPath: nil)
        let client = StubAppListClient(apps: [app], artwork: RemoteAppArtwork(
            appID: "109",
            data: Data([1, 2, 3]),
            contentType: "image/png",
            updatedAt: Date(timeIntervalSince1970: 10)
        ))
        let manager = AppCatalogManager(appListClient: client, artworkCache: InMemoryArtworkCache())

        let snapshot = try await manager.refreshApps(for: host, clientUniqueID: "client")
        let firstArtwork = try await manager.artwork(for: app, host: host, clientUniqueID: "client")
        let secondArtwork = try await manager.artwork(for: app, host: host, clientUniqueID: "client")

        XCTAssertEqual(snapshot.hostID, host.id)
        XCTAssertEqual(snapshot.apps, [app])
        XCTAssertEqual(firstArtwork?.data, Data([1, 2, 3]))
        XCTAssertEqual(secondArtwork?.data, Data([1, 2, 3]))
        let artworkFetchCount = await client.currentArtworkFetchCount()
        XCTAssertEqual(artworkFetchCount, 1)
    }

    func testArtworkCacheIsScopedByHost() async throws {
        let firstHost = MoonlightHost(
            id: UUID(uuidString: "7E725F13-9BD6-43CD-AC17-D5C57FDB83F2")!,
            name: "Studio PC",
            address: "192.168.1.50",
            pairingState: .paired,
            reachability: .online
        )
        let secondHost = MoonlightHost(
            id: UUID(uuidString: "D3E2F650-18EF-47E2-97B8-12DAE9EB084B")!,
            name: "Living Room PC",
            address: "192.168.1.51",
            pairingState: .paired,
            reachability: .online
        )
        let app = RemoteApp(id: "109", name: "Steam", supportsHDR: true, installPath: nil)
        let client = StubAppListClient(apps: [app], artwork: RemoteAppArtwork(
            appID: "109",
            data: Data([9]),
            contentType: "image/png",
            updatedAt: Date(timeIntervalSince1970: 10)
        ))
        let manager = AppCatalogManager(appListClient: client, artworkCache: InMemoryArtworkCache())

        _ = try await manager.artwork(for: app, host: firstHost, clientUniqueID: "client")
        _ = try await manager.artwork(for: app, host: secondHost, clientUniqueID: "client")

        let artworkFetchCount = await client.currentArtworkFetchCount()
        XCTAssertEqual(artworkFetchCount, 2)
    }
}

private actor StubAppListClient: AppListClient {
    let apps: [RemoteApp]
    let artwork: RemoteAppArtwork?
    private(set) var artworkFetchCount = 0

    init(apps: [RemoteApp], artwork: RemoteAppArtwork?) {
        self.apps = apps
        self.artwork = artwork
    }

    func fetchApps(from endpoint: HostEndpoint, clientUniqueID: String) async throws -> [RemoteApp] {
        apps
    }

    func fetchArtwork(for app: RemoteApp, from endpoint: HostEndpoint, clientUniqueID: String) async throws -> RemoteAppArtwork? {
        artworkFetchCount += 1
        return artwork
    }

    func currentArtworkFetchCount() -> Int {
        artworkFetchCount
    }
}
