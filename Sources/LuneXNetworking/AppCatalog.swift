import Foundation

struct RemoteApp: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: String
    var name: String
    var supportsHDR: Bool
    var installPath: String?
    var artworkCacheKey: String {
        "\(id)-poster"
    }
}

struct AppListSnapshot: Codable, Equatable, Sendable {
    var hostID: UUID
    var apps: [RemoteApp]
    var updatedAt: Date
}

struct RemoteAppArtwork: Codable, Equatable, Sendable {
    var appID: String
    var data: Data
    var contentType: String?
    var updatedAt: Date
}

enum AppCatalogError: Error, Equatable, Sendable {
    case invalidResponse
    case serverRejected(String)
    case missingAppListURL
    case missingArtworkURL
}

protocol AppListClient: Sendable {
    func fetchApps(from endpoint: HostEndpoint, clientUniqueID: String) async throws -> [RemoteApp]
    func fetchArtwork(for app: RemoteApp, from endpoint: HostEndpoint, clientUniqueID: String) async throws -> RemoteAppArtwork?
}

protocol ArtworkCache: Sendable {
    func artwork(forKey key: String) async throws -> RemoteAppArtwork?
    func store(_ artwork: RemoteAppArtwork, forKey key: String) async throws
    func removeArtwork(forKey key: String) async throws
}

actor InMemoryArtworkCache: ArtworkCache {
    private var storage: [String: RemoteAppArtwork] = [:]

    func artwork(forKey key: String) async throws -> RemoteAppArtwork? {
        storage[key]
    }

    func store(_ artwork: RemoteAppArtwork, forKey key: String) async throws {
        storage[key] = artwork
    }

    func removeArtwork(forKey key: String) async throws {
        storage[key] = nil
    }
}

struct HTTPAppListClient: AppListClient {
    var session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchApps(from endpoint: HostEndpoint, clientUniqueID: String) async throws -> [RemoteApp] {
        guard let url = MoonlightHTTPURLBuilder.secureURL(
            endpoint: endpoint,
            path: "/applist",
            queryItems: [URLQueryItem(name: "uniqueid", value: clientUniqueID)]
        ) else {
            throw AppCatalogError.missingAppListURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, _) = try await session.data(for: request)
        return try AppListParser.parse(data)
    }

    func fetchArtwork(for app: RemoteApp, from endpoint: HostEndpoint, clientUniqueID: String) async throws -> RemoteAppArtwork? {
        guard let url = MoonlightHTTPURLBuilder.secureURL(
            endpoint: endpoint,
            path: "/appasset",
            queryItems: [
                URLQueryItem(name: "uniqueid", value: clientUniqueID),
                URLQueryItem(name: "appid", value: app.id),
                URLQueryItem(name: "AssetType", value: "2"),
                URLQueryItem(name: "AssetIdx", value: "0")
            ]
        ) else {
            throw AppCatalogError.missingArtworkURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10
        let (data, response) = try await session.data(for: request)
        guard !data.isEmpty else { return nil }
        let contentType = (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Type")
        return RemoteAppArtwork(appID: app.id, data: data, contentType: contentType, updatedAt: Date())
    }
}

enum AppListParser {
    static func parse(_ data: Data) throws -> [RemoteApp] {
        let delegate = AppListXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            throw AppCatalogError.invalidResponse
        }

        if let statusCode = delegate.statusCode, statusCode != 200 {
            throw AppCatalogError.serverRejected(delegate.statusMessage ?? "App list request failed.")
        }

        return delegate.apps.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}

private final class AppListXMLDelegate: NSObject, XMLParserDelegate {
    private var currentElement: String?
    private var currentText = ""
    private var currentAppValues: [String: String]?

    private(set) var apps: [RemoteApp] = []
    private(set) var statusCode: Int?
    private(set) var statusMessage: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let normalized = elementName.lowercased()
        currentElement = normalized
        currentText = ""

        if normalized == "root" {
            if let rawStatusCode = attributeDict["status_code"], let statusCode = Int(rawStatusCode) {
                self.statusCode = statusCode
            }
            statusMessage = attributeDict["status_message"]
        } else if normalized == "app" {
            currentAppValues = [:]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let normalized = elementName.lowercased()
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

        if normalized == "app" {
            if let app = makeApp(from: currentAppValues ?? [:]) {
                apps.append(app)
            }
            currentAppValues = nil
        } else if currentAppValues != nil, !value.isEmpty {
            currentAppValues?[normalized] = value
        }

        currentElement = nil
        currentText = ""
    }

    private func makeApp(from values: [String: String]) -> RemoteApp? {
        guard let id = values["id"], !id.isEmpty else { return nil }
        return RemoteApp(
            id: id,
            name: values["apptitle"] ?? values["name"] ?? "App \(id)",
            supportsHDR: values["ishdrsupported"] == "1" || values["ishdrsupported"]?.lowercased() == "true",
            installPath: values["appinstallpath"]
        )
    }
}

actor AppCatalogManager {
    private let appListClient: AppListClient
    private let artworkCache: ArtworkCache

    init(appListClient: AppListClient, artworkCache: ArtworkCache) {
        self.appListClient = appListClient
        self.artworkCache = artworkCache
    }

    func refreshApps(for host: MoonlightHost, clientUniqueID: String, now: Date = Date()) async throws -> AppListSnapshot {
        let endpoint = try HostEndpointParser.parse(host.address)
        let apps = try await appListClient.fetchApps(from: endpoint, clientUniqueID: clientUniqueID)
        return AppListSnapshot(hostID: host.id, apps: apps, updatedAt: now)
    }

    func artwork(for app: RemoteApp, host: MoonlightHost, clientUniqueID: String) async throws -> RemoteAppArtwork? {
        let cacheKey = artworkCacheKey(for: app, host: host)
        if let cached = try await artworkCache.artwork(forKey: cacheKey) {
            return cached
        }

        let endpoint = try HostEndpointParser.parse(host.address)
        guard let fetched = try await appListClient.fetchArtwork(for: app, from: endpoint, clientUniqueID: clientUniqueID) else {
            return nil
        }
        try await artworkCache.store(fetched, forKey: cacheKey)
        return fetched
    }

    private func artworkCacheKey(for app: RemoteApp, host: MoonlightHost) -> String {
        "\(host.id.uuidString)-\(app.artworkCacheKey)"
    }
}

enum MoonlightHTTPURLBuilder {
    static func secureURL(endpoint: HostEndpoint, path: String, queryItems: [URLQueryItem]) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = endpoint.host
        components.port = endpoint.port == HostEndpoint.defaultHTTPPort ? HostEndpoint.defaultHTTPSPort : endpoint.port
        components.path = path
        components.queryItems = queryItems
        return components.url
    }
}
