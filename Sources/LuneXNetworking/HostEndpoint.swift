import Foundation

struct HostEndpoint: Codable, Equatable, Hashable, Sendable {
    static let defaultHTTPPort = 47989
    static let defaultHTTPSPort = 47984

    var host: String
    var port: Int

    var displayAddress: String {
        if host.contains(":") && !host.hasPrefix("[") {
            return "[\(host)]:\(port)"
        }
        return port == Self.defaultHTTPPort ? host : "\(host):\(port)"
    }

    var serverInfoURL: URL? {
        URL(string: "http://\(displayAddress)/serverinfo")
    }
}

enum HostEndpointParseError: Error, Equatable {
    case emptyAddress
    case invalidPort
    case invalidAddress
}

enum HostEndpointParser {
    static func parse(_ input: String) throws -> HostEndpoint {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HostEndpointParseError.emptyAddress }

        if let endpoint = parseURLLike(trimmed) {
            return endpoint
        }

        if trimmed.hasPrefix("[") {
            return try parseBracketedIPv6(trimmed)
        }

        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        if parts.count == 2, let port = Int(parts[1]) {
            guard isValidPort(port) else { throw HostEndpointParseError.invalidPort }
            return HostEndpoint(host: String(parts[0]), port: port)
        }

        if parts.count == 2 {
            throw HostEndpointParseError.invalidPort
        }

        return HostEndpoint(host: trimmed, port: HostEndpoint.defaultHTTPPort)
    }

    private static func parseURLLike(_ value: String) -> HostEndpoint? {
        guard value.contains("://"),
              let components = URLComponents(string: value),
              let host = components.host,
              !host.isEmpty
        else { return nil }
        return HostEndpoint(host: host, port: components.port ?? HostEndpoint.defaultHTTPPort)
    }

    private static func parseBracketedIPv6(_ value: String) throws -> HostEndpoint {
        guard let closeIndex = value.firstIndex(of: "]") else {
            throw HostEndpointParseError.invalidAddress
        }

        let hostStart = value.index(after: value.startIndex)
        let host = String(value[hostStart..<closeIndex])
        let remainderStart = value.index(after: closeIndex)
        guard remainderStart < value.endIndex else {
            return HostEndpoint(host: host, port: HostEndpoint.defaultHTTPPort)
        }

        guard value[remainderStart] == ":" else {
            throw HostEndpointParseError.invalidAddress
        }

        let portStart = value.index(after: remainderStart)
        guard let port = Int(value[portStart...]), isValidPort(port) else {
            throw HostEndpointParseError.invalidPort
        }

        return HostEndpoint(host: host, port: port)
    }

    private static func isValidPort(_ port: Int) -> Bool {
        port > 0 && port <= 65_535
    }
}
