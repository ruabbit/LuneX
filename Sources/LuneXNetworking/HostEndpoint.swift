import Foundation
import Darwin

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
        let encodedHost: String
        if host.contains(":") {
            encodedHost = "[\(host.replacingOccurrences(of: "%", with: "%25"))]"
        } else {
            encodedHost = host
        }
        return URL(string: "http://\(encodedHost):\(port)/serverinfo")
    }
}

enum HostEndpointParseError: Error, Equatable {
    case emptyAddress
    case invalidPort
    case invalidAddress
    case unsupportedScheme
    case credentialsNotAllowed
}

enum HostEndpointParser {
    static func parse(_ input: String) throws -> HostEndpoint {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw HostEndpointParseError.emptyAddress }

        guard !trimmed.unicodeScalars.contains(where: {
            CharacterSet.whitespacesAndNewlines.contains($0)
                || CharacterSet.controlCharacters.contains($0)
        }) else {
            throw HostEndpointParseError.invalidAddress
        }

        if trimmed.contains("://") {
            return try parseURLLike(trimmed)
        }

        if trimmed.hasPrefix("[") {
            return try parseBracketedIPv6(trimmed)
        }

        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        if parts.count == 2, let port = Int(parts[1]) {
            guard isValidPort(port) else { throw HostEndpointParseError.invalidPort }
            return try makeEndpoint(host: String(parts[0]), port: port)
        }

        if parts.count == 2 {
            throw HostEndpointParseError.invalidPort
        }

        return try makeEndpoint(host: trimmed, port: HostEndpoint.defaultHTTPPort)
    }

    private static func parseURLLike(_ value: String) throws -> HostEndpoint {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased()
        else {
            throw HostEndpointParseError.invalidAddress
        }
        guard scheme == "http" || scheme == "https" else {
            throw HostEndpointParseError.unsupportedScheme
        }
        guard components.user == nil, components.password == nil else {
            throw HostEndpointParseError.credentialsNotAllowed
        }
        guard components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/",
              let host = components.host,
              !host.isEmpty else {
            throw HostEndpointParseError.invalidAddress
        }

        let port = components.port ?? HostEndpoint.defaultHTTPPort
        guard isValidPort(port) else {
            throw HostEndpointParseError.invalidPort
        }
        return try makeEndpoint(host: host, port: port)
    }

    private static func parseBracketedIPv6(_ value: String) throws -> HostEndpoint {
        guard let closeIndex = value.firstIndex(of: "]") else {
            throw HostEndpointParseError.invalidAddress
        }

        let hostStart = value.index(after: value.startIndex)
        let host = String(value[hostStart..<closeIndex])
        guard host.contains(":") else {
            throw HostEndpointParseError.invalidAddress
        }
        let remainderStart = value.index(after: closeIndex)
        guard remainderStart < value.endIndex else {
            return try makeEndpoint(host: host, port: HostEndpoint.defaultHTTPPort)
        }

        guard value[remainderStart] == ":" else {
            throw HostEndpointParseError.invalidAddress
        }

        let portStart = value.index(after: remainderStart)
        guard let port = Int(value[portStart...]), isValidPort(port) else {
            throw HostEndpointParseError.invalidPort
        }

        return try makeEndpoint(host: host, port: port)
    }

    private static func makeEndpoint(host: String, port: Int) throws -> HostEndpoint {
        let normalizedHost = try normalizeHost(host)
        return HostEndpoint(host: normalizedHost, port: port)
    }

    private static func normalizeHost(_ host: String) throws -> String {
        guard !host.isEmpty,
              host == host.trimmingCharacters(in: .whitespacesAndNewlines),
              !host.unicodeScalars.contains(where: {
                  CharacterSet.whitespacesAndNewlines.contains($0)
                      || CharacterSet.controlCharacters.contains($0)
              }),
              !host.contains(where: { "/?#@[]".contains($0) }) else {
            throw HostEndpointParseError.invalidAddress
        }

        if host.contains(":") {
            let components = host.split(separator: "%", omittingEmptySubsequences: false)
            guard components.count <= 2,
                  !components[0].isEmpty,
                  isIPv6Address(String(components[0])) else {
                throw HostEndpointParseError.invalidAddress
            }
            if components.count == 2 {
                let zone = components[1]
                guard !zone.isEmpty,
                      zone.unicodeScalars.allSatisfy({
                          CharacterSet.alphanumerics.contains($0)
                              || "._-".unicodeScalars.contains($0)
                      }) else {
                    throw HostEndpointParseError.invalidAddress
                }
            }
            return host.lowercased()
        }

        if host.unicodeScalars.allSatisfy({
            CharacterSet.decimalDigits.contains($0) || $0 == "."
        }) {
            guard isIPv4Address(host) else {
                throw HostEndpointParseError.invalidAddress
            }
            return host
        }

        let withoutRootDot = host.hasSuffix(".") ? String(host.dropLast()) : host
        let labels = withoutRootDot.split(separator: ".", omittingEmptySubsequences: false)
        guard !withoutRootDot.isEmpty,
              withoutRootDot.utf8.count <= 253,
              labels.allSatisfy({ label in
                  !label.isEmpty
                      && label.utf8.count <= 63
                      && label.first != "-"
                      && label.last != "-"
                      && label.unicodeScalars.allSatisfy({
                          CharacterSet.alphanumerics.contains($0)
                              || $0 == "-"
                              || $0 == "_"
                      })
              }) else {
            throw HostEndpointParseError.invalidAddress
        }
        return withoutRootDot.lowercased()
    }

    private static func isIPv4Address(_ value: String) -> Bool {
        var address = in_addr()
        return value.withCString { inet_pton(AF_INET, $0, &address) } == 1
    }

    private static func isIPv6Address(_ value: String) -> Bool {
        var address = in6_addr()
        return value.withCString { inet_pton(AF_INET6, $0, &address) } == 1
    }

    private static func isValidPort(_ port: Int) -> Bool {
        port > 0 && port <= 65_535
    }
}
