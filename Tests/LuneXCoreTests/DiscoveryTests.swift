import Foundation
import XCTest

final class DiscoveryTests: XCTestCase {
    func testEndpointParserHandlesDefaultAndExplicitPorts() throws {
        XCTAssertEqual(try HostEndpointParser.parse("192.168.1.50").displayAddress, "192.168.1.50")
        XCTAssertEqual(try HostEndpointParser.parse("192.168.1.50:48010").displayAddress, "192.168.1.50:48010")
        XCTAssertEqual(try HostEndpointParser.parse("[fe80::1]:47989").displayAddress, "[fe80::1]:47989")
    }

    func testServerInfoURLAlwaysCarriesTheGameStreamHTTPPort() throws {
        XCTAssertEqual(
            try HostEndpointParser.parse("192.168.1.50")
                .serverInfoURL?.absoluteString,
            "http://192.168.1.50:47989/serverinfo"
        )
        XCTAssertEqual(
            try HostEndpointParser.parse("moon.local:48010")
                .serverInfoURL?.absoluteString,
            "http://moon.local:48010/serverinfo"
        )
        XCTAssertEqual(
            try HostEndpointParser.parse("fe80::1%en0")
                .serverInfoURL?.absoluteString,
            "http://[fe80::1%25en0]:47989/serverinfo"
        )
    }

    func testEndpointParserNormalizesWhitespaceNamesURLsAndIPv6() throws {
        XCTAssertEqual(
            try HostEndpointParser.parse("  Moon.Local.  ").displayAddress,
            "moon.local"
        )
        XCTAssertEqual(
            try HostEndpointParser.parse("Moon.Local:48010").displayAddress,
            "moon.local:48010"
        )
        XCTAssertEqual(
            try HostEndpointParser.parse("https://Moon.Local:48010/").displayAddress,
            "moon.local:48010"
        )
        XCTAssertEqual(
            try HostEndpointParser.parse("fe80::1").displayAddress,
            "[fe80::1]:47989"
        )
        XCTAssertEqual(
            try HostEndpointParser.parse("[FE80::1%EN0]").displayAddress,
            "[fe80::1%en0]:47989"
        )
    }

    func testEndpointParserRejectsCredentialsUnsupportedURLsAndPaths() {
        assertParseError("http://user:password@moon.local", .credentialsNotAllowed)
        assertParseError("ftp://moon.local", .unsupportedScheme)
        assertParseError("http://moon.local/apps", .invalidAddress)
        assertParseError("http://moon.local/?token=value", .invalidAddress)
        assertParseError("http://moon.local/#details", .invalidAddress)
    }

    func testEndpointParserRejectsInvalidPortsAddressesAndControlCharacters() {
        assertParseError("", .emptyAddress)
        assertParseError("moon.local:0", .invalidPort)
        assertParseError("moon.local:65536", .invalidPort)
        assertParseError("moon.local:not-a-port", .invalidPort)
        assertParseError(":47989", .invalidAddress)
        assertParseError("999.1.1.1", .invalidAddress)
        assertParseError("moon..local", .invalidAddress)
        assertParseError("-moon.local", .invalidAddress)
        assertParseError("moon local", .invalidAddress)
        assertParseError("moon.local\nother.local", .invalidAddress)
        assertParseError("[fe80::1", .invalidAddress)
        assertParseError("[not-ipv6]", .invalidAddress)
    }

    func testManualHostDraftReturnsNormalizedSubmissionOrFieldSafeIssue() throws {
        let submission = try ManualHostDraft(
            name: "  Studio  ",
            address: "  Moon.Local:48010  "
        ).validate().get()
        XCTAssertEqual(submission.name, "Studio")
        XCTAssertEqual(submission.endpoint, HostEndpoint(host: "moon.local", port: 48_010))
        XCTAssertEqual(submission.normalizedAddress, "moon.local:48010")

        XCTAssertEqual(
            ManualHostDraft(address: "  ").validate(),
            .failure(ManualHostValidationFailure(issueCode: .hostAddressRequired))
        )
        XCTAssertEqual(
            ManualHostDraft(address: "http://user:secret@moon.local").validate(),
            .failure(ManualHostValidationFailure(issueCode: .hostAddressInvalid))
        )
    }

    func testEndpointParserExtendedBoundaryMatrix() throws {
        let valid: [(String, String)] = [
            ("localhost", "localhost"),
            ("HOST_NAME.local.", "host_name.local"),
            ("10.0.0.8:47990", "10.0.0.8:47990"),
            ("http://moon.local/", "moon.local"),
            ("[2001:DB8::10]:48000", "[2001:db8::10]:48000"),
            ("fe80::2%EN1", "[fe80::2%en1]:47989")
        ]
        for (input, expected) in valid {
            XCTAssertEqual(
                try HostEndpointParser.parse(input).displayAddress,
                expected,
                input
            )
        }

        let invalid: [(String, HostEndpointParseError)] = [
            ("https://moon.local:70000", .invalidPort),
            ("http://user%40name:password@moon.local", .credentialsNotAllowed),
            ("http://moon.local//", .invalidAddress),
            ("[fe80::1]trailing", .invalidAddress),
            ("fe80::1%bad zone", .invalidAddress),
            ("moon.local#fragment", .invalidAddress),
            ("moon.local/path", .invalidAddress)
        ]
        for (input, expected) in invalid {
            assertParseError(input, expected)
        }
    }

    func testServerInfoParserExtractsHostMetadata() {
        let xml = """
        <root>
          <hostname>Studio PC</hostname>
          <uniqueid>abc</uniqueid>
          <state>ONLINE</state>
          <hdr>1</hdr>
        </root>
        """

        let info = ServerInfoParser.parse(Data(xml.utf8))

        XCTAssertEqual(info.name, "Studio PC")
        XCTAssertEqual(info.uniqueID, "abc")
        XCTAssertEqual(info.state, "ONLINE")
        XCTAssertTrue(info.supportsHDR)
    }

    func testManualHostAddUpsertsByCanonicalAddress() async throws {
        let repository = InMemoryHostRepository()
        let manager = HostLibraryManager(
            repository: repository,
            serverInfoClient: StubServerInfoClient(info: ServerInfo(
                name: "Studio PC",
                uniqueID: "abc",
                macAddress: nil,
                state: "ONLINE",
                supportsHDR: true,
                rawValues: [:]
            ))
        )

        let first = try await manager.addManualHost(name: nil, address: "192.168.1.50")
        let second = try await manager.addManualHost(name: "Manual Name", address: "192.168.1.50")

        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(second.count, 1)
        XCTAssertEqual(second[0].name, "Studio PC")
        XCTAssertEqual(second[0].reachability, .online)
        XCTAssertTrue(second[0].capabilities.supportsHDR)
    }

    func testBonjourDiscoveryEnrichesUniquePairedHostWithoutDuplicatingIt() async throws {
        let pinnedIdentity = PinnedHostIdentity(
            certificateSHA256: String(repeating: "c", count: 64),
            serverCertificateDER: Data([0x05, 0x06]),
            pairedAt: Date(timeIntervalSince1970: 100)
        )
        let saved = MoonlightHost(
            name: "Studio PC",
            address: "192.168.1.50",
            pairingState: .paired,
            reachability: .offline,
            pinnedIdentity: pinnedIdentity
        )
        let repository = InMemoryHostRepository(hosts: [saved])
        let manager = HostLibraryManager(
            repository: repository,
            serverInfoClient: AlwaysFailingServerInfoClient()
        )
        let seenAt = Date(timeIntervalSince1970: 500)

        let merged = try await manager.mergeDiscoveredHost(
            HostDiscoveryCandidate(
                name: " Studio PC ",
                endpoint: HostEndpoint(host: "studio-pc.local", port: 47_989),
                source: .mdns,
                serverInfo: nil,
                lastSeenAt: seenAt
            )
        )

        let result = try XCTUnwrap(merged.first)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(result.id, saved.id)
        XCTAssertEqual(result.pairingState, .paired)
        XCTAssertEqual(result.pinnedIdentity, pinnedIdentity)
        XCTAssertEqual(result.reachability, .online)
        XCTAssertEqual(result.lastSeenAt, seenAt)
        XCTAssertEqual(
            result.addresses.last,
            HostAddress(
                rawValue: "studio-pc.local",
                source: .mdns,
                lastResolvedAt: seenAt
            )
        )
    }

    func testBonjourDiscoveryCollapsesLegacyUnpairedDuplicateIntoTrustedHost() async throws {
        let trusted = MoonlightHost(
            name: "Studio PC",
            address: "192.168.1.50",
            pairingState: .paired,
            reachability: .online
        )
        var duplicate = MoonlightHost(
            name: "Studio PC",
            address: "studio-pc.local",
            pairingState: .unpaired,
            reachability: .online
        )
        duplicate.addresses[0].source = .mdns
        let repository = InMemoryHostRepository(hosts: [trusted, duplicate])
        let manager = HostLibraryManager(
            repository: repository,
            serverInfoClient: AlwaysFailingServerInfoClient()
        )

        let merged = try await manager.mergeDiscoveredHost(
            HostDiscoveryCandidate(
                name: "Studio PC",
                endpoint: HostEndpoint(host: "studio-pc.local", port: 47_989),
                source: .mdns,
                serverInfo: nil,
                lastSeenAt: Date(timeIntervalSince1970: 600)
            )
        )

        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged[0].id, trusted.id)
        XCTAssertEqual(merged[0].pairingState, .paired)
        XCTAssertTrue(merged[0].addresses.contains {
            $0.rawValue == "studio-pc.local" && $0.source == .mdns
        })
    }

    func testBonjourDiscoveryDoesNotNameMergeAmbiguousTrustedHosts() async throws {
        let first = MoonlightHost(
            name: "Studio PC",
            address: "192.168.1.50",
            pairingState: .paired,
            reachability: .online
        )
        let second = MoonlightHost(
            name: "studio pc",
            address: "192.168.1.51",
            pairingState: .paired,
            reachability: .online
        )
        let repository = InMemoryHostRepository(hosts: [first, second])
        let manager = HostLibraryManager(
            repository: repository,
            serverInfoClient: AlwaysFailingServerInfoClient()
        )

        let merged = try await manager.mergeDiscoveredHost(
            HostDiscoveryCandidate(
                name: "STUDIO PC",
                endpoint: HostEndpoint(host: "studio-pc.local", port: 47_989),
                source: .mdns,
                serverInfo: nil,
                lastSeenAt: Date(timeIntervalSince1970: 700)
            )
        )

        XCTAssertEqual(merged.count, 3)
        XCTAssertTrue(merged.contains { $0.id == first.id })
        XCTAssertTrue(merged.contains { $0.id == second.id })
        let discovered = try XCTUnwrap(merged.first {
            $0.id != first.id && $0.id != second.id
        })
        XCTAssertEqual(discovered.pairingState, .unpaired)
        XCTAssertEqual(discovered.addresses.first?.source, .mdns)
    }

    func testReachabilityRefreshUsesEveryAddressAndPreservesTrust() async throws {
        let pinnedIdentity = PinnedHostIdentity(
            certificateSHA256: String(repeating: "a", count: 64),
            serverCertificateDER: Data([0x01, 0x02, 0x03]),
            pairedAt: Date(timeIntervalSince1970: 100)
        )
        var host = MoonlightHost(
            name: "Saved Name",
            address: "offline.local",
            pairingState: .paired,
            reachability: .unknown,
            pinnedIdentity: pinnedIdentity
        )
        host.addresses.append(HostAddress(
            rawValue: "reachable.local",
            source: .vpn
        ))
        host.capabilities.supportsHEVC = true
        let repository = InMemoryHostRepository(hosts: [host])
        let manager = HostLibraryManager(
            repository: repository,
            serverInfoClient: SelectiveServerInfoClient(
                reachableHost: "reachable.local",
                info: makeServerInfo(name: "Current Name", supportsHDR: true)
            )
        )

        let refreshed = try await manager.refreshReachability()
        let result = try XCTUnwrap(refreshed.first)

        XCTAssertEqual(result.id, host.id)
        XCTAssertEqual(result.reachability, .online)
        XCTAssertEqual(result.name, "Current Name")
        XCTAssertEqual(result.pairingState, .paired)
        XCTAssertEqual(result.pinnedIdentity, pinnedIdentity)
        XCTAssertTrue(result.capabilities.supportsHDR)
        XCTAssertTrue(result.capabilities.supportsHEVC)
        XCTAssertNotNil(result.lastSeenAt)
        XCTAssertEqual(result.addresses.first?.rawValue, "reachable.local")
        XCTAssertEqual(result.addresses.first?.source, .vpn)
        let persisted = try await repository.loadHosts()
        XCTAssertEqual(persisted, refreshed)
    }

    @MainActor
    func testLoadingSavedHostsStartsReachabilityAtChecking() async throws {
        let saved = MoonlightHost(
            name: "Previously Online",
            address: "saved.local",
            pairingState: .paired,
            reachability: .online
        )
        let repository = InMemoryHostRepository(hosts: [saved])
        let model = AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: repository,
                serverInfoClient: AlwaysFailingServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            runtimeProviders: .unavailable,
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientUniqueID: "checking-test"
        )

        await model.loadHosts()

        XCTAssertEqual(model.hosts.count, 1)
        XCTAssertEqual(model.hosts[0].id, saved.id)
        XCTAssertEqual(model.hosts[0].reachability, .unknown)
        let persisted = try await repository.loadHosts()
        XCTAssertEqual(persisted[0].reachability, .online)
    }

    func testReachabilityRefreshMarksOfflineOnlyAfterAllAddressesFail() async throws {
        var host = MoonlightHost(
            name: "Saved Host",
            address: "first.local",
            pairingState: .paired,
            reachability: .online,
            pinnedIdentity: PinnedHostIdentity(
                certificateSHA256: String(repeating: "b", count: 64),
                serverCertificateDER: Data([0x04]),
                pairedAt: Date(timeIntervalSince1970: 200)
            ),
            lastSeenAt: Date(timeIntervalSince1970: 300)
        )
        host.addresses.append(HostAddress(rawValue: "second.local", source: .cached))
        let repository = InMemoryHostRepository(hosts: [host])
        let manager = HostLibraryManager(
            repository: repository,
            serverInfoClient: AlwaysFailingServerInfoClient()
        )

        let refreshed = try await manager.refreshReachability()
        let result = try XCTUnwrap(refreshed.first)

        XCTAssertEqual(result.reachability, .offline)
        XCTAssertEqual(result.name, host.name)
        XCTAssertEqual(result.pairingState, host.pairingState)
        XCTAssertEqual(result.pinnedIdentity, host.pinnedIdentity)
        XCTAssertEqual(result.lastSeenAt, host.lastSeenAt)
    }

    @MainActor
    func testMacOSAutomaticSelectionPromotesReachablePairedHostButPreservesExplicitChoice() async throws {
        let offline = MoonlightHost(
            name: "A Offline",
            address: "offline.local",
            pairingState: .paired,
            reachability: .unknown
        )
        let online = MoonlightHost(
            name: "B Online",
            address: "online.local",
            pairingState: .paired,
            reachability: .unknown
        )
        let model = AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(hosts: [offline, online]),
                serverInfoClient: SelectiveServerInfoClient(
                    reachableHost: "online.local",
                    info: makeServerInfo(name: "B Online", supportsHDR: false)
                )
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            runtimeProviders: .unavailable,
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientUniqueID: "selection-test"
        )

        await model.loadHosts()
        XCTAssertEqual(model.selectedHost?.id, offline.id)

        await model.refreshHostReachability()
        XCTAssertEqual(model.selectedHost?.id, online.id)

        XCTAssertTrue(model.setSelectedHostID(
            offline.id,
            in: model.primaryWorkspaceReference
        ))
        await model.refreshHostReachability()
        XCTAssertEqual(model.selectedHost?.id, offline.id)
        XCTAssertEqual(model.selectedHost?.reachability, .offline)
    }

    func testReachabilityRefreshRebasesConcurrentDiscoveryMerge() async throws {
        let saved = MoonlightHost(
            name: "Saved",
            address: "saved.local",
            pairingState: .paired,
            reachability: .unknown
        )
        let repository = InMemoryHostRepository(hosts: [saved])
        let client = SuspendedServerInfoClient()
        let manager = HostLibraryManager(
            repository: repository,
            serverInfoClient: client
        )

        let refresh = Task { try await manager.refreshReachability() }
        await client.waitUntilFetchIsPending()
        let discovered = HostDiscoveryCandidate(
            name: "Discovered",
            endpoint: HostEndpoint(host: "discovered.local", port: 47_989),
            source: .mdns,
            serverInfo: nil,
            lastSeenAt: Date(timeIntervalSince1970: 400)
        )
        let merged = try await manager.mergeDiscoveredHost(discovered)
        XCTAssertEqual(merged.count, 2)

        await client.resume(with: makeServerInfo(name: "Saved Online"))
        let refreshed = try await refresh.value

        XCTAssertEqual(Set(refreshed.map(\.id)), Set(merged.map(\.id)))
        XCTAssertEqual(refreshed.count, 2)
        XCTAssertEqual(
            refreshed.first(where: { $0.id == saved.id })?.reachability,
            .online
        )
        XCTAssertEqual(
            refreshed.first(where: { $0.address == "discovered.local" })?.reachability,
            .online
        )
    }

    func testReachabilityRefreshPropagatesCancellationWithoutSavingOffline() async throws {
        let host = MoonlightHost(
            name: "Saved",
            address: "saved.local",
            pairingState: .paired,
            reachability: .unknown
        )
        let repository = InMemoryHostRepository(hosts: [host])
        let manager = HostLibraryManager(
            repository: repository,
            serverInfoClient: CancellableServerInfoClient()
        )
        let refresh = Task { try await manager.refreshReachability() }

        await Task.yield()
        refresh.cancel()

        do {
            _ = try await refresh.value
            XCTFail("Expected reachability refresh cancellation")
        } catch is CancellationError {
            let persisted = try await repository.loadHosts()
            XCTAssertEqual(persisted, [host])
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }
    }

    private func assertParseError(
        _ input: String,
        _ expected: HostEndpointParseError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try HostEndpointParser.parse(input), file: file, line: line) {
            XCTAssertEqual($0 as? HostEndpointParseError, expected, file: file, line: line)
        }
    }
}

private enum DiscoveryTestError: Error {
    case unreachable
}

private func makeServerInfo(
    name: String,
    supportsHDR: Bool = false
) -> ServerInfo {
    ServerInfo(
        name: name,
        uniqueID: "test-host",
        macAddress: nil,
        state: "ONLINE",
        supportsHDR: supportsHDR,
        rawValues: [:]
    )
}

private struct SelectiveServerInfoClient: ServerInfoClient {
    let reachableHost: String
    let info: ServerInfo

    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        guard endpoint.host == reachableHost else {
            throw DiscoveryTestError.unreachable
        }
        return info
    }
}

private struct AlwaysFailingServerInfoClient: ServerInfoClient {
    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        _ = endpoint
        throw DiscoveryTestError.unreachable
    }
}

private actor SuspendedServerInfoClient: ServerInfoClient {
    private var continuation: CheckedContinuation<ServerInfo, Error>?

    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        _ = endpoint
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func waitUntilFetchIsPending() async {
        while continuation == nil { await Task.yield() }
    }

    func resume(with info: ServerInfo) {
        continuation?.resume(returning: info)
        continuation = nil
    }
}

private struct CancellableServerInfoClient: ServerInfoClient {
    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        _ = endpoint
        try await Task.sleep(for: .seconds(60))
        throw DiscoveryTestError.unreachable
    }
}

private struct StubServerInfoClient: ServerInfoClient {
    var info: ServerInfo

    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        info
    }
}
