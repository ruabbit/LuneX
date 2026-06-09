import Foundation

struct MoonlightHost: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var addresses: [HostAddress]
    var pairingState: PairingState
    var reachability: HostReachability
    var capabilities: HostCapabilities
    var pinnedIdentity: PinnedHostIdentity?
    var lastSeenAt: Date?

    var address: String {
        addresses.first?.rawValue ?? ""
    }

    init(
        id: UUID = UUID(),
        name: String,
        address: String,
        pairingState: PairingState,
        reachability: HostReachability,
        capabilities: HostCapabilities = .unknown,
        pinnedIdentity: PinnedHostIdentity? = nil,
        lastSeenAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.addresses = [HostAddress(rawValue: address)]
        self.pairingState = pairingState
        self.reachability = reachability
        self.capabilities = capabilities
        self.pinnedIdentity = pinnedIdentity
        self.lastSeenAt = lastSeenAt
    }
}

enum PairingState: String, Codable, Hashable, Sendable {
    case unpaired
    case pairing
    case paired
    case failed
}

enum HostReachability: String, Codable, Hashable, Sendable {
    case unknown
    case online
    case offline

    var label: String {
        switch self {
        case .unknown: "Unknown"
        case .online: "Online"
        case .offline: "Offline"
        }
    }
}
