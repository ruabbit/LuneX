import Foundation
import Network

struct HostDiscoveryCandidate: Equatable, Sendable {
    var name: String
    var endpoint: HostEndpoint
    var source: HostAddressSource
    var serverInfo: ServerInfo?
    var lastSeenAt: Date

    func makeHost(existingID: UUID? = nil) -> MoonlightHost {
        var host = MoonlightHost(
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
        host.addresses = [
            HostAddress(
                rawValue: endpoint.displayAddress,
                source: source,
                lastResolvedAt: lastSeenAt
            )
        ]
        return host
    }
}

protocol HostDiscoveryService: Sendable {
    func candidates() -> AsyncStream<HostDiscoveryCandidate>
}

private struct HostReachabilityProbeResult: Sendable {
    let hostID: MoonlightHost.ID
    let serverInfo: ServerInfo?
    let reachableAddress: String?
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

    func refreshReachability() async throws -> [MoonlightHost] {
        let savedHosts = try await repository.loadHosts()
        let client = serverInfoClient
        let probeResults = await withTaskGroup(
            of: HostReachabilityProbeResult.self,
            returning: [MoonlightHost.ID: HostReachabilityProbeResult].self
        ) { group in
            for host in savedHosts {
                group.addTask {
                    for address in host.addresses {
                        guard !Task.isCancelled,
                              let endpoint = try? HostEndpointParser.parse(
                                  address.rawValue
                              ) else { continue }
                        if let info = try? await client.fetchServerInfo(
                            from: endpoint
                        ) {
                            return HostReachabilityProbeResult(
                                hostID: host.id,
                                serverInfo: info,
                                reachableAddress: address.rawValue
                            )
                        }
                    }
                    return HostReachabilityProbeResult(
                        hostID: host.id,
                        serverInfo: nil,
                        reachableAddress: nil
                    )
                }
            }

            var results: [MoonlightHost.ID: HostReachabilityProbeResult] = [:]
            for await result in group {
                results[result.hostID] = result
            }
            return results
        }
        try Task.checkCancellation()

        // Discovery can merge a host while probes are suspended on network I/O.
        // Rebase the results on the latest repository snapshot before saving.
        var hosts = try await repository.loadHosts()
        let now = Date()
        for index in hosts.indices {
            guard let result = probeResults[hosts[index].id] else { continue }
            if let serverInfo = result.serverInfo {
                hosts[index].reachability = .online
                hosts[index].lastSeenAt = now
                hosts[index].name = serverInfo.name ?? hosts[index].name
                hosts[index].capabilities.supportsHDR = serverInfo.supportsHDR
                if let reachableAddress = result.reachableAddress,
                   let addressIndex = hosts[index].addresses.firstIndex(where: {
                       $0.rawValue == reachableAddress
                   }) {
                    var address = hosts[index].addresses.remove(at: addressIndex)
                    address.lastResolvedAt = now
                    hosts[index].addresses.insert(address, at: 0)
                }
            } else {
                hosts[index].reachability = .offline
            }
        }
        try await repository.saveHosts(hosts)
        return hosts.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
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
        let exactAddressIndex = hosts.firstIndex(where: { host in
            host.addresses.contains { $0.rawValue == canonicalAddress }
        })
        let canonicalName = normalizedHostName(
            candidate.serverInfo?.name ?? candidate.name
        )
        let nameMatchIndices = candidate.source == .mdns
            ? hosts.indices.filter {
                normalizedHostName(hosts[$0].name) == canonicalName
            }
            : []
        let trustedNameMatchIndices = nameMatchIndices.filter {
            hosts[$0].pairingState == .paired || hosts[$0].pinnedIdentity != nil
        }

        let targetID: MoonlightHost.ID?
        var redundantID: MoonlightHost.ID?
        if trustedNameMatchIndices.count == 1,
           let trustedIndex = trustedNameMatchIndices.first,
           let exactAddressIndex,
           trustedIndex != exactAddressIndex,
           hosts[exactAddressIndex].pairingState != .paired,
           hosts[exactAddressIndex].pinnedIdentity == nil {
            targetID = hosts[trustedIndex].id
            redundantID = hosts[exactAddressIndex].id
        } else if let exactAddressIndex {
            targetID = hosts[exactAddressIndex].id
        } else if nameMatchIndices.count == 1,
                  let nameMatchIndex = nameMatchIndices.first {
            targetID = hosts[nameMatchIndex].id
        } else {
            targetID = nil
        }

        if let targetID,
           let index = hosts.firstIndex(where: { $0.id == targetID }) {
            hosts[index].name = candidate.serverInfo?.name ?? candidate.name
            hosts[index].reachability = .online
            hosts[index].lastSeenAt = candidate.lastSeenAt
            if !hosts[index].addresses.contains(where: {
                $0.rawValue == canonicalAddress
            }) {
                hosts[index].addresses.append(
                    HostAddress(
                        rawValue: canonicalAddress,
                        source: candidate.source,
                        lastResolvedAt: candidate.lastSeenAt
                    )
                )
            }
            if let serverInfo = candidate.serverInfo {
                hosts[index].capabilities.supportsHDR = serverInfo.supportsHDR
            }
            if let redundantID {
                hosts.removeAll { $0.id == redundantID }
            }
        } else {
            hosts.append(candidate.makeHost())
        }

        try await repository.saveHosts(hosts)
        return hosts.sorted { lhs, rhs in
            lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    private func normalizedHostName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
