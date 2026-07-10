import Foundation
import XCTest

final class AppCatalogTests: XCTestCase {
    func testPinnedCertificateValidatorRequiresExactLeafData() {
        let expected = Data([1, 2, 3])

        XCTAssertTrue(PinnedCertificateValidator.matches(expectedLeafDER: expected, presentedLeafDER: expected))
        XCTAssertFalse(PinnedCertificateValidator.matches(expectedLeafDER: expected, presentedLeafDER: Data([1, 2, 4])))
        XCTAssertFalse(PinnedCertificateValidator.matches(expectedLeafDER: expected, presentedLeafDER: nil))
        XCTAssertFalse(PinnedCertificateValidator.matches(expectedLeafDER: Data(), presentedLeafDER: expected))
    }

    func testPinnedCertificateValidatorNormalizesPEMToDER() throws {
        let der = Data([1, 2, 3, 4, 5])
        let pem = """
        -----BEGIN CERTIFICATE-----
        \(der.base64EncodedString())
        -----END CERTIFICATE-----
        """

        XCTAssertEqual(PinnedCertificateValidator.normalizedDER(Data(pem.utf8)), der)
        XCTAssertTrue(PinnedCertificateValidator.matches(
            expectedLeafDER: Data(pem.utf8),
            presentedLeafDER: der
        ))
    }

    func testPinnedRequestExecutorRejectsMissingIdentityBeforeNetworkAccess() async {
        let request = URLRequest(url: URL(string: "https://moon.local:47984/applist")!)

        do {
            _ = try await PinnedHTTPSRequestExecutor().data(for: request, pinnedIdentity: nil)
            XCTFail("Expected a missing-pin failure")
        } catch {
            XCTAssertEqual(error as? PinnedTransportError, .missingPinnedIdentity)
        }
    }

    func testHTTPAppListClientRoutesPinnedIdentityToExecutor() async throws {
        let xml = """
        <root status_code="200" status_message="OK">
          <App><AppTitle>Desktop</AppTitle><ID>0</ID></App>
        </root>
        """
        let executor = RecordingPinnedRequestExecutor(responseData: Data(xml.utf8))
        let client = HTTPAppListClient(requestExecutor: executor)
        let pin = PinnedHostIdentity(
            certificateSHA256: "pin",
            serverCertificateDER: Data([9, 8, 7]),
            pairedAt: Date(timeIntervalSince1970: 1)
        )

        let apps = try await client.fetchApps(
            from: HostEndpoint(host: "moon.local", port: HostEndpoint.defaultHTTPPort),
            clientUniqueID: "client",
            pinnedIdentity: pin
        )
        let recordedPin = await executor.recordedPinnedIdentity()
        let recordedURL = await executor.recordedRequestURL()

        XCTAssertEqual(apps.map(\.name), ["Desktop"])
        XCTAssertEqual(recordedPin, pin)
        XCTAssertEqual(recordedURL?.scheme, "https")
        XCTAssertEqual(recordedURL?.port, HostEndpoint.defaultHTTPSPort)
    }

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

private actor RecordingPinnedRequestExecutor: PinnedHTTPSRequestExecuting {
    private let responseData: Data
    private var requestURL: URL?
    private var pin: PinnedHostIdentity?

    init(responseData: Data) {
        self.responseData = responseData
    }

    func data(for request: URLRequest, pinnedIdentity: PinnedHostIdentity?) async throws -> (Data, URLResponse) {
        requestURL = request.url
        pin = pinnedIdentity
        let response = URLResponse(
            url: request.url!,
            mimeType: "application/xml",
            expectedContentLength: responseData.count,
            textEncodingName: "utf-8"
        )
        return (responseData, response)
    }

    func recordedPinnedIdentity() -> PinnedHostIdentity? {
        pin
    }

    func recordedRequestURL() -> URL? {
        requestURL
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

    func fetchApps(from endpoint: HostEndpoint, clientUniqueID: String, pinnedIdentity: PinnedHostIdentity?) async throws -> [RemoteApp] {
        apps
    }

    func fetchArtwork(for app: RemoteApp, from endpoint: HostEndpoint, clientUniqueID: String, pinnedIdentity: PinnedHostIdentity?) async throws -> RemoteAppArtwork? {
        artworkFetchCount += 1
        return artwork
    }

    func currentArtworkFetchCount() -> Int {
        artworkFetchCount
    }
}
