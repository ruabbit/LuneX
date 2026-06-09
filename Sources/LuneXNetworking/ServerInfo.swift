import Foundation

struct ServerInfo: Codable, Equatable, Sendable {
    var name: String?
    var uniqueID: String?
    var macAddress: String?
    var state: String?
    var supportsHDR: Bool
    var rawValues: [String: String]

    static let empty = ServerInfo(
        name: nil,
        uniqueID: nil,
        macAddress: nil,
        state: nil,
        supportsHDR: false,
        rawValues: [:]
    )
}

enum ServerInfoParser {
    static func parse(_ data: Data) -> ServerInfo {
        let parser = XMLParser(data: data)
        let delegate = ServerInfoXMLDelegate()
        parser.delegate = delegate
        guard parser.parse() else { return .empty }
        return delegate.serverInfo
    }
}

private final class ServerInfoXMLDelegate: NSObject, XMLParserDelegate {
    private var currentElement: String?
    private var currentText = ""
    private var values: [String: String] = [:]

    var serverInfo: ServerInfo {
        let hdrValue = values["hdr"] ?? values["hdrsupported"] ?? values["gfehdrsupported"]
        return ServerInfo(
            name: values["hostname"] ?? values["name"],
            uniqueID: values["uniqueid"] ?? values["uniqueID".lowercased()],
            macAddress: values["mac"] ?? values["macaddress"],
            state: values["state"],
            supportsHDR: hdrValue == "1" || hdrValue?.lowercased() == "true",
            rawValues: values
        )
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName.lowercased()
        currentText = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let key = elementName.lowercased()
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            values[key] = value
        }
        currentElement = nil
        currentText = ""
    }
}

protocol ServerInfoClient: Sendable {
    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo
}

struct HTTPServerInfoClient: ServerInfoClient {
    var session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        guard let url = endpoint.serverInfoURL else {
            throw HostEndpointParseError.invalidAddress
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let (data, _) = try await session.data(for: request)
        return ServerInfoParser.parse(data)
    }
}
