import XCTest

@MainActor
final class ProductHostWorkspaceTests: XCTestCase {
    func testPrimaryWorkspaceProjectsLegacyNavigationAndHostSelection() async throws {
        let host = makeHost(idSuffix: 1, address: "moon.local")
        let model = makeModel(repository: InMemoryHostRepository(hosts: [host]))

        await model.loadHosts()
        model.navigationSelection = .settings

        let state = try XCTUnwrap(model.primaryWorkspaceState)
        XCTAssertEqual(state.reference, model.primaryWorkspaceReference)
        XCTAssertEqual(state.navigationSelection, .settings)
        XCTAssertEqual(state.selectedHostID, host.id)
        XCTAssertEqual(model.navigationSelection, .settings)
        XCTAssertEqual(model.selectedHostID, host.id)
        XCTAssertEqual(model.selectedHost?.id, host.id)
    }

    func testHostLoadTransitionsWorkspaceFromLoadingToFirstUse() async throws {
        let model = makeModel(repository: InMemoryHostRepository())
        XCTAssertEqual(model.primaryWorkspaceState?.hostLibrary.phase, .loading)

        await model.loadHosts()

        let library = try XCTUnwrap(model.primaryWorkspaceState?.hostLibrary)
        XCTAssertEqual(library.phase, .firstUse)
        XCTAssertFalse(library.isRefreshing)
        XCTAssertNil(library.refreshIssue)
        XCTAssertNil(model.selectedHostID)
    }

    func testHostLoadSelectsAvailableHostAndClearsRefreshFailure() async throws {
        let host = makeHost(idSuffix: 2, address: "moon.local")
        let model = makeModel(repository: InMemoryHostRepository(hosts: [host]))

        await model.loadHosts()

        let library = try XCTUnwrap(model.primaryWorkspaceState?.hostLibrary)
        XCTAssertEqual(library.phase, .available)
        XCTAssertFalse(library.isRefreshing)
        XCTAssertNil(library.refreshIssue)
        XCTAssertEqual(model.selectedHostID, host.id)
    }

    func testHostLoadFailureIsTypedAndScopedToOwningWorkspace() async throws {
        let model = makeModel(repository: FailingProductHostRepository())

        await model.loadHosts()

        let library = try XCTUnwrap(model.primaryWorkspaceState?.hostLibrary)
        XCTAssertEqual(library.phase, .failed)
        XCTAssertFalse(library.isRefreshing)
        XCTAssertEqual(library.refreshIssue?.code, .hostLibraryLoadFailed)
        XCTAssertEqual(
            library.refreshIssue?.action?.scope,
            .workspace(model.primaryWorkspaceReference)
        )
        XCTAssertTrue(model.hosts.isEmpty)
    }

    func testManualHostValidationFailureDoesNotPersistOrEchoDraft() async throws {
        let repository = RecordingProductHostRepository()
        let model = makeModel(repository: repository)
        let rejected = "http://private-user:private-password@private-host.local"
        model.setManualHostDraft(
            ManualHostDraft(name: "Private", address: rejected),
            in: model.primaryWorkspaceReference
        )

        let result = await model.addManualHost(in: model.primaryWorkspaceReference)

        guard case let .failed(issue) = result else {
            return XCTFail("Expected typed validation failure")
        }
        XCTAssertEqual(issue.code, .hostAddressInvalid)
        XCTAssertEqual(issue.action?.scope, .workspace(model.primaryWorkspaceReference))
        let saveCount = await repository.saveCount()
        XCTAssertEqual(saveCount, 0)
        XCTAssertTrue(model.hosts.isEmpty)
        XCTAssertEqual(
            model.primaryWorkspaceState?.hostLibrary.manualHostDraft.address,
            rejected
        )
    }

    func testManualHostSuccessNormalizesSelectsAndClearsDraft() async throws {
        let repository = RecordingProductHostRepository()
        let model = makeModel(repository: repository)
        model.setManualHostDraft(
            ManualHostDraft(name: "  Studio  ", address: "  Moon.Local.  "),
            in: model.primaryWorkspaceReference
        )

        let result = await model.addManualHost(in: model.primaryWorkspaceReference)

        guard case let .succeeded(hostID) = result else {
            return XCTFail("Expected saved host")
        }
        XCTAssertEqual(model.hosts.count, 1)
        XCTAssertEqual(model.hosts[0].id, hostID)
        XCTAssertEqual(model.hosts[0].name, "Product Host")
        XCTAssertEqual(model.hosts[0].address, "moon.local")
        XCTAssertEqual(model.selectedHostID, hostID)
        XCTAssertEqual(
            model.primaryWorkspaceState?.hostLibrary.manualHostDraft,
            ManualHostDraft()
        )
        XCTAssertEqual(
            model.primaryWorkspaceState?.hostLibrary.manualHostSubmission,
            .succeeded(hostID: hostID)
        )
        let saveCount = await repository.saveCount()
        XCTAssertEqual(saveCount, 1)
    }

    func testLateHostLoadFromReplacedWorkspaceCannotMutateSharedState() async throws {
        let host = makeHost(idSuffix: 3, address: "late.local")
        let repository = SuspendedProductHostRepository(result: [host])
        let model = makeModel(repository: repository)
        let owner = model.primaryWorkspaceReference

        let load = Task { await model.loadHosts(in: owner) }
        await repository.waitUntilLoadIsPending()
        XCTAssertTrue(model.workspaceState(for: owner)?.hostLibrary.isRefreshing == true)
        let replacement = try model.workspaceRegistry.replace(owner)
        await repository.resumeLoad()
        await load.value

        XCTAssertNil(model.workspaceState(for: owner))
        XCTAssertNotNil(model.workspaceState(for: replacement))
        XCTAssertTrue(model.hosts.isEmpty)
        XCTAssertNil(model.workspaceState(for: replacement)?.selectedHostID)
    }

    func testLateManualHostSaveFromReplacedWorkspaceCannotMutateCurrentProjection() async throws {
        let repository = SuspendedProductHostSaveRepository()
        let model = makeModel(repository: repository)
        let owner = model.primaryWorkspaceReference
        model.setManualHostDraft(
            ManualHostDraft(name: "Studio", address: "save.local"),
            in: owner
        )

        let add = Task { await model.addManualHost(in: owner) }
        await repository.waitUntilSaveIsPending()
        XCTAssertEqual(
            model.workspaceState(for: owner)?.hostLibrary.manualHostSubmission,
            .saving
        )
        let replacement = try model.workspaceRegistry.replace(owner)
        await repository.resumeSave()
        let result = await add.value

        guard case let .failed(issue) = result else {
            return XCTFail("Expected stale manual-host result")
        }
        XCTAssertEqual(issue.code, .staleAction)
        XCTAssertNil(model.workspaceState(for: owner))
        XCTAssertTrue(model.hosts.isEmpty)
        XCTAssertNil(model.workspaceState(for: replacement)?.selectedHostID)
        XCTAssertEqual(
            model.workspaceState(for: replacement)?.hostLibrary.manualHostDraft,
            ManualHostDraft()
        )
        XCTAssertEqual(
            model.workspaceState(for: replacement)?.hostLibrary.manualHostSubmission,
            .idle
        )
    }

    private func makeModel(repository: any HostRepository) -> AppModel {
        AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: repository,
                serverInfoClient: ProductHostServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: ProductHostAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(
                launchClient: HTTPStreamLaunchClient()
            ),
            runtimeProviders: .unavailable,
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientUniqueID: "workspace-test"
        )
    }

    private func makeHost(idSuffix: UInt8, address: String) -> MoonlightHost {
        MoonlightHost(
            id: UUID(uuidString: String(
                format: "60000000-0000-0000-0000-%012d",
                idSuffix
            ))!,
            name: "Host \(idSuffix)",
            address: address,
            pairingState: .unpaired,
            reachability: .unknown
        )
    }
}

private enum ProductHostTestError: Error {
    case expectedFailure
}

private actor FailingProductHostRepository: HostRepository {
    func loadHosts() async throws -> [MoonlightHost] {
        throw ProductHostTestError.expectedFailure
    }

    func saveHosts(_ hosts: [MoonlightHost]) async throws {
        _ = hosts
        throw ProductHostTestError.expectedFailure
    }
}

private actor RecordingProductHostRepository: HostRepository {
    private var hosts: [MoonlightHost] = []
    private var saves = 0

    func loadHosts() async throws -> [MoonlightHost] {
        hosts
    }

    func saveHosts(_ hosts: [MoonlightHost]) async throws {
        self.hosts = hosts
        saves += 1
    }

    func saveCount() -> Int { saves }
}

private actor SuspendedProductHostRepository: HostRepository {
    private let result: [MoonlightHost]
    private var continuation: CheckedContinuation<[MoonlightHost], Never>?

    init(result: [MoonlightHost]) {
        self.result = result
    }

    func loadHosts() async throws -> [MoonlightHost] {
        await withCheckedContinuation { continuation = $0 }
    }

    func saveHosts(_ hosts: [MoonlightHost]) async throws {
        _ = hosts
    }

    func waitUntilLoadIsPending() async {
        while continuation == nil { await Task.yield() }
    }

    func resumeLoad() {
        continuation?.resume(returning: result)
        continuation = nil
    }
}

private actor SuspendedProductHostSaveRepository: HostRepository {
    private var continuation: CheckedContinuation<Void, Never>?

    func loadHosts() async throws -> [MoonlightHost] {
        []
    }

    func saveHosts(_ hosts: [MoonlightHost]) async throws {
        _ = hosts
        await withCheckedContinuation { continuation = $0 }
    }

    func waitUntilSaveIsPending() async {
        while continuation == nil { await Task.yield() }
    }

    func resumeSave() {
        continuation?.resume()
        continuation = nil
    }
}

private struct ProductHostServerInfoClient: ServerInfoClient {
    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        _ = endpoint
        return ServerInfo(
            name: "Product Host",
            uniqueID: "product-host",
            macAddress: nil,
            state: "ONLINE",
            supportsHDR: true,
            rawValues: [:]
        )
    }
}

private struct ProductHostAppListClient: AppListClient {
    func fetchApps(
        from endpoint: HostEndpoint,
        clientUniqueID: String,
        pinnedIdentity: PinnedHostIdentity?
    ) async throws -> [RemoteApp] {
        _ = endpoint
        _ = clientUniqueID
        _ = pinnedIdentity
        return []
    }

    func fetchArtwork(
        for app: RemoteApp,
        from endpoint: HostEndpoint,
        clientUniqueID: String,
        pinnedIdentity: PinnedHostIdentity?
    ) async throws -> RemoteAppArtwork? {
        _ = app
        _ = endpoint
        _ = clientUniqueID
        _ = pinnedIdentity
        return nil
    }
}
