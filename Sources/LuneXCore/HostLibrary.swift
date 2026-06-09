import Foundation

struct HostAddress: Codable, Hashable, Sendable {
    var rawValue: String
    var source: HostAddressSource
    var lastResolvedAt: Date?

    init(rawValue: String, source: HostAddressSource = .manual, lastResolvedAt: Date? = nil) {
        self.rawValue = rawValue
        self.source = source
        self.lastResolvedAt = lastResolvedAt
    }
}

enum HostAddressSource: String, Codable, Hashable, Sendable {
    case manual
    case mdns
    case cached
    case vpn
}

struct HostCapabilities: Codable, Equatable, Hashable, Sendable {
    var supportsHDR: Bool
    var supportsHEVC: Bool
    var supportsAV1: Bool
    var maxResolution: PixelSize
    var maxRefreshRate: Int

    static let unknown = HostCapabilities(
        supportsHDR: false,
        supportsHEVC: false,
        supportsAV1: false,
        maxResolution: .zero,
        maxRefreshRate: 0
    )
}

struct PinnedHostIdentity: Codable, Equatable, Hashable, Sendable {
    var certificateSHA256: String
    var serverCertificateDER: Data
    var pairedAt: Date
}

struct HostLibrarySnapshot: Codable, Equatable, Sendable {
    var hosts: [MoonlightHost]
    var updatedAt: Date
}

protocol HostRepository: Sendable {
    func loadHosts() async throws -> [MoonlightHost]
    func saveHosts(_ hosts: [MoonlightHost]) async throws
}

actor InMemoryHostRepository: HostRepository {
    private var hosts: [MoonlightHost]

    init(hosts: [MoonlightHost] = []) {
        self.hosts = hosts
    }

    func loadHosts() async throws -> [MoonlightHost] {
        hosts
    }

    func saveHosts(_ hosts: [MoonlightHost]) async throws {
        self.hosts = hosts
    }
}
