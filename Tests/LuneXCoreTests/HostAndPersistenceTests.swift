import Foundation
import XCTest

final class HostAndPersistenceTests: XCTestCase {
    func testHostCodableRoundTripPreservesConnectionMetadata() throws {
        let host = MoonlightHost(
            id: UUID(uuidString: "2E327651-76AE-49F1-BA8A-D523FA88A58F")!,
            name: "Studio PC",
            address: "192.168.1.20",
            pairingState: .paired,
            reachability: .online,
            capabilities: HostCapabilities(
                supportsHDR: true,
                supportsHEVC: true,
                supportsAV1: false,
                maxResolution: PixelSize(width: 3840, height: 2160),
                maxRefreshRate: 120
            ),
            pinnedIdentity: PinnedHostIdentity(
                certificateSHA256: "abc123",
                serverCertificateDER: Data([1, 2, 3]),
                pairedAt: Date(timeIntervalSince1970: 100)
            ),
            lastSeenAt: Date(timeIntervalSince1970: 200)
        )

        let encoded = try JSONEncoder().encode(host)
        let decoded = try JSONDecoder().decode(MoonlightHost.self, from: encoded)

        XCTAssertEqual(decoded, host)
        XCTAssertEqual(decoded.address, "192.168.1.20")
        XCTAssertTrue(decoded.capabilities.supportsHDR)
    }

    func testInMemoryIdentityStoreSupportsSaveLoadDelete() async throws {
        let store = InMemoryClientIdentityStore()
        let identity = ClientIdentityMaterial(
            id: UUID(uuidString: "88C33C52-6F54-46BE-AD58-D3FB0C7C7895")!,
            certificateDER: Data([10, 11, 12]),
            privateKeyDER: Data([20, 21, 22]),
            createdAt: Date(timeIntervalSince1970: 300)
        )

        try await store.saveIdentity(identity)
        let loaded = try await store.loadIdentity()
        XCTAssertEqual(loaded, identity)

        try await store.deleteIdentity()
        let deleted = try await store.loadIdentity()
        XCTAssertNil(deleted)
    }

    func testSettingsDefaultsRepresentNativeHighQualityStream() {
        let settings = AppSettings.defaults

        XCTAssertTrue(settings.discoveryEnabled)
        XCTAssertTrue(settings.stream.hdrEnabled)
        XCTAssertEqual(settings.stream.frameRate, 120)
        XCTAssertEqual(settings.stream.scaleMode, .fit)
        XCTAssertTrue(settings.input.preferRelativeMouseMode)
    }

    func testJSONFileAppCatalogSnapshotRepositoryRoundTripsSnapshots() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("app_catalog.json")
        let repository = JSONFileAppCatalogSnapshotRepository(fileURL: fileURL)
        let snapshot = AppListSnapshot(
            hostID: UUID(uuidString: "9942D8B8-8625-4E2A-926C-F05F15D1812D")!,
            apps: [
                RemoteApp(id: "1", name: "Desktop", supportsHDR: true, installPath: nil),
                RemoteApp(id: "2", name: "Steam Big Picture", supportsHDR: false, installPath: "/Applications/Steam.app")
            ],
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )
        defer {
            try? FileManager.default.removeItem(at: directory)
        }

        let emptySnapshots = try await repository.loadSnapshots()
        XCTAssertEqual(emptySnapshots, [])

        try await repository.saveSnapshots([snapshot])
        let loaded = try await repository.loadSnapshots()

        XCTAssertEqual(loaded, [snapshot])
    }

    func testJSONFileIdentityStoreUsesPrivatePermissionsAndRoundTrips() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("client_identity.debug.json")
        let store = JSONFileClientIdentityStore(fileURL: fileURL)
        let identity = ClientIdentityMaterial(
            id: UUID(uuidString: "01CDA768-A358-4341-93D9-326E92E09AE6")!,
            certificateDER: Data([1, 2, 3]),
            privateKeyDER: Data([4, 5, 6]),
            createdAt: Date(timeIntervalSince1970: 100)
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        try await store.saveIdentity(identity)
        let loaded = try await store.loadIdentity()
        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
        let permissions = attributes[.posixPermissions] as? NSNumber

        XCTAssertEqual(loaded, identity)
        XCTAssertEqual(permissions?.intValue, 0o600)

        try await store.deleteIdentity()
        let deleted = try await store.loadIdentity()
        XCTAssertNil(deleted)
    }

    func testRealKeychainIdentityRoundTripWhenExplicitlyEnabled() async throws {
        guard ProcessInfo.processInfo.environment["LUNEX_RUN_KEYCHAIN_TEST"] == "1" else {
            throw XCTSkip("Set LUNEX_RUN_KEYCHAIN_TEST=1 for the one-time authorized Keychain verification.")
        }

        let suffix = UUID().uuidString
        let store = KeychainClientIdentityStore(
            service: "dev.lunex.client.identity.integration.\(suffix)",
            account: "moonlight-client-\(suffix)"
        )
        let identity = ClientIdentityMaterial(
            certificateDER: Data([10, 20, 30]),
            privateKeyDER: Data([40, 50, 60])
        )
        defer {
            Task { try? await store.deleteIdentity() }
        }

        try await store.saveIdentity(identity)
        let loaded = try await store.loadIdentity()
        XCTAssertEqual(loaded, identity)
        try await store.deleteIdentity()
    }

    #if DEBUG
    func testDebugIdentityStoreFactoryUsesFileFallback() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("factory-identity.json")
        let store = ClientIdentityStoreFactory.makeDefault(debugFileURL: fileURL)
        let identity = ClientIdentityMaterial(
            certificateDER: Data([1, 3, 5]),
            privateKeyDER: Data([2, 4, 6])
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        try await store.saveIdentity(identity)
        let loaded = try await store.loadIdentity()

        XCTAssertEqual(loaded, identity)
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))

        try await store.deleteIdentity()
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }
    #endif
}
