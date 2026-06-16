import Foundation
import Network

struct HostDiscoveryCandidate: Equatable, Sendable {
    var name: String
    var endpoint: HostEndpoint
    var source: HostAddressSource
    var serverInfo: ServerInfo?
    var lastSeenAt: Date

    func makeHost(existingID: UUID? = nil) -> MoonlightHost {
        MoonlightHost(
            id: existingID ?? UUID(),
            name: serverInfo?.name ?? name,
            address: endpoint.displayAddress,
            pairingState: .unpaired,
            reachability: .online,
            capabilities: HostCapabilities(
                supportsHDR: serverInfo?.supportsHDR ?? false,
                supportsHEVC: false,
                supportsAV1: false,
                maxResolution: .zero,
                maxRefreshRate: 0
            ),
            lastSeenAt: lastSeenAt
        )
    }
}

protocol HostDiscoveryService: Sendable {
    func candidates() -> AsyncStream<HostDiscoveryCandidate>
}

final class BonjourHostDiscoveryService: HostDiscoveryService, @unchecked Sendable {
    private let queue = DispatchQueue(label: "dev.lunex.discovery.bonjour")

    func candidates() -> AsyncStream<HostDiscoveryCandidate> {
        AsyncStream { continuation in
            let browser = NWBrowser(
                for: .bonjour(type: "_nvstream._tcp", domain: "local"),
                using: .tcp
            )

            browser.browseResultsChangedHandler = { results, _ in
                for result in results {
                    guard case let .service(name, _, _, _) = result.endpoint else { continue }
                    let endpoint = HostEndpoint(host: "\(name).local", port: HostEndpoint.defaultHTTPPort)
                    continuation.yield(
                        HostDiscoveryCandidate(
                            name: name,
                            endpoint: endpoint,
                            source: .mdns,
                            serverInfo: nil,
                            lastSeenAt: Date()
                        )
                    )
                }
            }

            browser.stateUpdateHandler = { state in
                if case .failed = state {
                    continuation.finish()
                }
            }

            continuation.onTermination = { _ in
                browser.cancel()
            }
            browser.start(queue: queue)
        }
    }
}

actor HostLibraryManager {
    private let repository: HostRepository
    private let serverInfoClient: ServerInfoClient

    init(
        repository: HostRepository,
        serverInfoClient: ServerInfoClient
    ) {
        self.repository = repository
        self.serverInfoClient = serverInfoClient
    }

    func loadHosts() async throws -> [MoonlightHost] {
        try await repository.loadHosts()
    }

    func addManualHost(name: String?, address: String) async throws -> [MoonlightHost] {
        let endpoint = try HostEndpointParser.parse(address)
        let serverInfo = try? await serverInfoClient.fetchServerInfo(from: endpoint)
        let candidate = HostDiscoveryCandidate(
            name: name?.isEmpty == false ? name! : serverInfo?.name ?? endpoint.host,
            endpoint: endpoint,
            source: .manual,
            serverInfo: serverInfo,
            lastSeenAt: Date()
        )
        return try await merge(candidate)
    }

    func mergeDiscoveredHost(_ candidate: HostDiscoveryCandidate) async throws -> [MoonlightHost] {
        try await merge(candidate)
    }

    func replaceHost(_ host: MoonlightHost) async throws -> [MoonlightHost] {
        var hosts = try await repository.loadHosts()
        if let index = hosts.firstIndex(where: { $0.id == host.id }) {
            hosts[index] = host
        } else {
            hosts.append(host)
        }
        try await repository.saveHosts(hosts)
        return hosts.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    func removeHost(id: MoonlightHost.ID) async throws -> [MoonlightHost] {
        var hosts = try await repository.loadHosts()
        hosts.removeAll { $0.id == id }
        try await repository.saveHosts(hosts)
        return hosts.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func merge(_ candidate: HostDiscoveryCandidate) async throws -> [MoonlightHost] {
        var hosts = try await repository.loadHosts()
        let canonicalAddress = candidate.endpoint.displayAddress

        if let index = hosts.firstIndex(where: { host in
            host.addresses.contains { $0.rawValue == canonicalAddress }
        }) {
            hosts[index].name = candidate.serverInfo?.name ?? candidate.name
            hosts[index].reachability = .online
            hosts[index].lastSeenAt = candidate.lastSeenAt
            if let serverInfo = candidate.serverInfo {
                hosts[index].capabilities.supportsHDR = serverInfo.supportsHDR
            }
        } else {
            hosts.append(candidate.makeHost())
        }

        try await repository.saveHosts(hosts)
        return hosts.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
}
