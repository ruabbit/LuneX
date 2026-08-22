import XCTest

@MainActor
final class ProductCatalogWorkspaceTests: XCTestCase {
    func testCatalogRefreshPublishesSharedAppsWithoutOverwritingLocalPresentation()
        async throws
    {
        let host = makeHost(idSuffix: 20, name: "Shared")
        let apps = makeApps()
        let model = makeModel(
            hosts: [host],
            appListClient: FixedProductCatalogClient(apps: apps)
        )
        await model.loadHosts()
        let primary = model.primaryWorkspaceReference
        let secondary = try model.workspaceRegistry.create(
            restoration: ProductWorkspaceRestorationState(
                navigationSelection: .settings,
                selectedHostID: host.id
            )
        )
        XCTAssertTrue(model.presentAddHostSheet(in: secondary))

        await model.refreshAppsForSelectedHost(in: primary)

        XCTAssertEqual(model.selectedApps(in: primary), apps)
        XCTAssertEqual(model.selectedApps(in: secondary), apps)
        XCTAssertEqual(model.catalogState(for: primary)?.phase, .current)
        XCTAssertEqual(model.catalogState(for: secondary)?.phase, .cached)
        XCTAssertEqual(model.selectedAppID(in: primary), apps.first?.id)
        XCTAssertEqual(model.selectedAppID(in: secondary), apps.first?.id)
        XCTAssertEqual(model.navigationSelection(in: secondary), .settings)
        XCTAssertEqual(model.workspaceSheet(in: secondary), .addHost)
    }

    func testHostSelectionGenerationChangesAcrossABAAndCatalogOwnerTracksIt() async throws {
        let first = makeHost(idSuffix: 1, name: "A")
        let second = makeHost(idSuffix: 2, name: "B")
        let model = makeModel(hosts: [first, second])
        await model.loadHosts()

        model.selectedHostID = first.id
        let firstOwner = try XCTUnwrap(model.primaryWorkspaceState?.catalogOwner)
        model.selectedHostID = second.id
        let secondOwner = try XCTUnwrap(model.primaryWorkspaceState?.catalogOwner)
        model.selectedHostID = first.id
        let replacementOwner = try XCTUnwrap(model.primaryWorkspaceState?.catalogOwner)

        XCTAssertEqual(firstOwner.hostID, replacementOwner.hostID)
        XCTAssertNotEqual(firstOwner.hostSelectionGeneration, secondOwner.hostSelectionGeneration)
        XCTAssertNotEqual(firstOwner.hostSelectionGeneration, replacementOwner.hostSelectionGeneration)
        XCTAssertEqual(model.primaryCatalogState?.owner, replacementOwner)
        XCTAssertEqual(model.primaryCatalogState?.phase, .idle)
    }

    func testCachedCatalogRestoresSelectionTimestampAndCachedPresentation() async throws {
        let host = makeHost(idSuffix: 3, name: "Cached")
        let date = Date(timeIntervalSince1970: 123)
        let apps = makeApps()
        let repository = InMemoryAppCatalogSnapshotRepository(snapshots: [
            AppListSnapshot(hostID: host.id, apps: apps, updatedAt: date)
        ])
        let model = makeModel(hosts: [host], repository: repository)

        await model.loadHosts()
        await model.loadCachedApps(in: model.primaryWorkspaceReference)

        XCTAssertEqual(model.selectedApps, apps)
        XCTAssertEqual(model.selectedAppID, apps.first?.id)
        XCTAssertEqual(model.primaryCatalogState?.phase, .cached)
        XCTAssertEqual(model.primaryCatalogState?.updatedAt, date)
        XCTAssertNil(model.primaryCatalogState?.issue)
    }

    func testDuplicateCachedSnapshotsDeterministicallyKeepNewestHostValue() async throws {
        let host = makeHost(idSuffix: 11, name: "Duplicate")
        let olderDate = Date(timeIntervalSince1970: 100)
        let newerDate = Date(timeIntervalSince1970: 200)
        let olderApps = [
            RemoteApp(id: "old", name: "Old", supportsHDR: false, installPath: nil)
        ]
        let newerApps = makeApps()
        let repository = InMemoryAppCatalogSnapshotRepository(snapshots: [
            AppListSnapshot(hostID: host.id, apps: newerApps, updatedAt: newerDate),
            AppListSnapshot(hostID: host.id, apps: olderApps, updatedAt: olderDate)
        ])
        let model = makeModel(hosts: [host], repository: repository)

        await model.loadHosts()
        await model.loadCachedApps(in: model.primaryWorkspaceReference)

        XCTAssertEqual(model.selectedApps, newerApps)
        XCTAssertEqual(model.primaryCatalogState?.updatedAt, newerDate)
        XCTAssertEqual(model.primaryCatalogState?.phase, .cached)
    }

    func testCachedCatalogLoadCannotPublishAfterWorkspaceReplacement() async throws {
        let host = makeHost(idSuffix: 12, name: "Replacement")
        let apps = makeApps()
        let repository = SuspendedProductCatalogRepository()
        let model = makeModel(hosts: [host], repository: repository)
        await model.loadHosts()

        let load = Task {
            await model.loadCachedApps(in: model.primaryWorkspaceReference)
        }
        await repository.waitUntilPending()
        let replacement = try model.workspaceRegistry.replace(
            model.primaryWorkspaceReference
        )
        await repository.resume(with: [
            AppListSnapshot(
                hostID: host.id,
                apps: apps,
                updatedAt: Date(timeIntervalSince1970: 300)
            )
        ])
        await load.value

        XCTAssertNil(model.appsByHostID[host.id])
        XCTAssertEqual(model.workspaceState(for: replacement)?.selectedHostID, host.id)
        XCTAssertEqual(model.workspaceState(for: replacement)?.catalog.phase, .idle)
        XCTAssertTrue(model.workspaceState(for: replacement)?.catalog.owner?.workspace == replacement)
    }

    func testSuccessfulEmptyRefreshPublishesCurrentEmptyState() async throws {
        let host = makeHost(idSuffix: 4, name: "Empty")
        let repository = RecordingProductCatalogRepository()
        let model = makeModel(
            hosts: [host],
            appListClient: FixedProductCatalogClient(apps: []),
            repository: repository
        )

        await model.loadHosts()
        await model.refreshAppsForSelectedHost(in: model.primaryWorkspaceReference)

        XCTAssertEqual(model.primaryCatalogState?.phase, .empty(source: .current))
        XCTAssertNotNil(model.primaryCatalogState?.updatedAt)
        XCTAssertNil(model.primaryCatalogState?.issue)
        XCTAssertTrue(model.selectedApps.isEmpty)
        XCTAssertNil(model.selectedAppID)
        let saveCount = await repository.saveCount()
        XCTAssertEqual(saveCount, 1)
    }

    func testRefreshFailurePreservesCachedAppsAndPublishesScopedRetry() async throws {
        let host = makeHost(idSuffix: 5, name: "Failure")
        let date = Date(timeIntervalSince1970: 456)
        let apps = makeApps()
        let repository = InMemoryAppCatalogSnapshotRepository(snapshots: [
            AppListSnapshot(hostID: host.id, apps: apps, updatedAt: date)
        ])
        let model = makeModel(
            hosts: [host],
            appListClient: FixedProductCatalogClient(shouldFail: true),
            repository: repository
        )

        await model.loadHosts()
        await model.loadCachedApps(in: model.primaryWorkspaceReference)
        let owner = try XCTUnwrap(model.primaryWorkspaceState?.catalogOwner)
        await model.refreshAppsForSelectedHost(in: model.primaryWorkspaceReference)

        XCTAssertEqual(model.selectedApps, apps)
        XCTAssertEqual(model.selectedAppID, apps.first?.id)
        XCTAssertEqual(model.primaryCatalogState?.phase, .failed(hasCachedApps: true))
        XCTAssertEqual(model.primaryCatalogState?.updatedAt, date)
        XCTAssertEqual(model.primaryCatalogState?.issue?.code, .catalogRefreshFailed)
        XCTAssertEqual(model.primaryCatalogState?.issue?.action?.scope, .catalog(owner))
    }

    func testUnpairedRefreshPublishesPairingRequirementWithoutRequest() async throws {
        var host = makeHost(idSuffix: 6, name: "Unpaired")
        host.pairingState = .unpaired
        let client = ScriptedProductCatalogClient(results: [.success(makeApps())])
        let model = makeModel(hosts: [host], appListClient: client)

        await model.loadHosts()
        let owner = try XCTUnwrap(model.primaryWorkspaceState?.catalogOwner)
        await model.refreshAppsForSelectedHost(in: model.primaryWorkspaceReference)

        XCTAssertEqual(model.primaryCatalogState?.phase, .failed(hasCachedApps: false))
        XCTAssertEqual(model.primaryCatalogState?.issue?.code, .catalogRequiresPairing)
        XCTAssertEqual(model.primaryCatalogState?.issue?.action?.scope, .catalog(owner))
        let requestCount = await client.requestCount()
        XCTAssertEqual(requestCount, 0)
    }

    func testLateRefreshAfterABACannotPublishOrPersist() async throws {
        let first = makeHost(idSuffix: 7, name: "A")
        let second = makeHost(idSuffix: 8, name: "B")
        let client = SuspendedProductCatalogClient()
        let repository = RecordingProductCatalogRepository()
        let model = makeModel(
            hosts: [first, second],
            appListClient: client,
            repository: repository
        )
        await model.loadHosts()
        model.selectedHostID = first.id
        let staleOwner = try XCTUnwrap(model.primaryWorkspaceState?.catalogOwner)

        let refresh = Task {
            await model.refreshAppsForSelectedHost(in: model.primaryWorkspaceReference)
        }
        await client.waitUntilPending()
        XCTAssertTrue(model.primaryCatalogState?.phase.isRefreshing == true)
        model.selectedHostID = second.id
        model.selectedHostID = first.id
        let replacementOwner = try XCTUnwrap(model.primaryWorkspaceState?.catalogOwner)
        await client.resume(with: makeApps())
        await refresh.value

        XCTAssertNotEqual(staleOwner, replacementOwner)
        XCTAssertEqual(model.primaryCatalogState?.owner, replacementOwner)
        XCTAssertEqual(model.primaryCatalogState?.phase, .idle)
        XCTAssertNil(model.appsByHostID[first.id])
        XCTAssertNil(model.selectedAppID)
        let saveCount = await repository.saveCount()
        XCTAssertEqual(saveCount, 0)
    }

    func testAppSelectionRequiresCurrentWorkspaceHostCatalog() async throws {
        let host = makeHost(idSuffix: 9, name: "Selection")
        let apps = makeApps()
        let model = makeModel(
            hosts: [host],
            appListClient: FixedProductCatalogClient(apps: apps)
        )
        await model.loadHosts()
        await model.refreshAppsForSelectedHost(in: model.primaryWorkspaceReference)
        let currentOwner = try XCTUnwrap(model.primaryWorkspaceState?.catalogOwner)
        model.selectedHostID = host.id
        XCTAssertEqual(model.primaryWorkspaceState?.catalogOwner, currentOwner)
        XCTAssertEqual(model.primaryCatalogState?.phase, .current)
        let external = RemoteApp(
            id: "external",
            name: "External",
            supportsHDR: false,
            installPath: nil
        )

        XCTAssertTrue(model.select(app: apps[1], in: model.primaryWorkspaceReference))
        XCTAssertEqual(model.selectedAppID, apps[1].id)
        XCTAssertFalse(model.select(app: external, in: model.primaryWorkspaceReference))
        XCTAssertEqual(model.selectedAppID, apps[1].id)
    }

    func testCatalogRetryReusesCurrentOwnerAndClearsFailure() async throws {
        let host = makeHost(idSuffix: 10, name: "Retry")
        let apps = makeApps()
        let client = ScriptedProductCatalogClient(results: [
            .failure(.expectedFailure),
            .success(apps)
        ])
        let model = makeModel(hosts: [host], appListClient: client)
        await model.loadHosts()
        let owner = try XCTUnwrap(model.primaryWorkspaceState?.catalogOwner)

        await model.refreshAppsForSelectedHost(in: model.primaryWorkspaceReference)
        XCTAssertEqual(model.primaryCatalogState?.issue?.action?.scope, .catalog(owner))
        let admitted = await model.retryAppCatalog(
            in: model.primaryWorkspaceReference
        )
        let duplicate = await model.retryAppCatalog(
            in: model.primaryWorkspaceReference
        )

        XCTAssertTrue(admitted)
        XCTAssertFalse(duplicate)
        XCTAssertEqual(model.primaryCatalogState?.owner, owner)
        XCTAssertEqual(model.primaryCatalogState?.phase, .current)
        XCTAssertNil(model.primaryCatalogState?.issue)
        XCTAssertEqual(model.selectedAppID, apps.first?.id)
        let requestCount = await client.requestCount()
        XCTAssertEqual(requestCount, 2)
    }

    func testConcurrentCatalogRetryAdmitsOneCurrentOwnerRequest() async throws {
        let host = makeHost(idSuffix: 15, name: "Concurrent Retry")
        let apps = makeApps()
        let client = SuspendedRetryProductCatalogClient()
        let model = makeModel(hosts: [host], appListClient: client)
        let workspace = model.primaryWorkspaceReference
        await model.loadHosts()

        await model.refreshAppsForSelectedHost(in: workspace)
        let owner = try XCTUnwrap(model.primaryCatalogState?.owner)
        XCTAssertEqual(
            model.primaryCatalogState?.phase,
            .failed(hasCachedApps: false)
        )

        let retry = Task { await model.retryAppCatalog(in: workspace) }
        await client.waitUntilRetryIsPending()
        XCTAssertEqual(
            model.primaryCatalogState?.phase,
            .loading(hasCachedApps: false)
        )
        let duplicateAccepted = await model.retryAppCatalog(in: workspace)
        let requestCountWhilePending = await client.requestCount()
        XCTAssertFalse(duplicateAccepted)
        XCTAssertEqual(requestCountWhilePending, 2)
        XCTAssertEqual(model.primaryCatalogState?.owner, owner)

        await client.resumeRetry(with: apps)
        let retryAccepted = await retry.value
        XCTAssertTrue(retryAccepted)
        XCTAssertEqual(model.primaryCatalogState?.phase, .current)
        XCTAssertEqual(model.selectedApps, apps)
        let finalRequestCount = await client.requestCount()
        XCTAssertEqual(finalRequestCount, 2)
    }

    func testAppCatalogPanelUsesWorkspaceCatalogAndTypedIssues() throws {
        let source = try String(contentsOf: rootViewURL, encoding: .utf8)

        XCTAssertTrue(source.contains("appModel.catalogState(for: workspace)"))
        XCTAssertTrue(source.contains("refreshAppsForSelectedHost(in: workspace)"))
        XCTAssertTrue(source.contains("appModel.select(app: app, in: workspace)"))
        XCTAssertTrue(source.contains(
            "isSelected: appModel.selectedAppID(in: workspace) == app.id"
        ))
        XCTAssertTrue(source.contains("Text(issue.presentation.message)"))
        XCTAssertFalse(source.contains("appModel.appCatalogUI"))
        XCTAssertFalse(source.contains("appModel.streamLaunchUI.selectedAppID"))
    }

    func testApplicationHostSwitchRejectsStaleRetryAndRecoversCatalog() async throws {
        let first = makeHost(idSuffix: 13, name: "A")
        let second = makeHost(idSuffix: 14, name: "B")
        let apps = makeApps()
        let client = ScriptedProductCatalogClient(results: [
            .failure(.expectedFailure),
            .failure(.expectedFailure),
            .success(apps)
        ])
        let model = makeModel(hosts: [first, second], appListClient: client)
        let workspace = model.primaryWorkspaceReference
        await model.loadHosts()
        model.selectedHostID = first.id

        await model.refreshAppsForSelectedHost(in: workspace)
        let firstOwner = try XCTUnwrap(model.primaryCatalogState?.owner)
        XCTAssertEqual(model.primaryCatalogState?.phase, .failed(hasCachedApps: false))
        XCTAssertEqual(
            model.primaryCatalogState?.issue?.action?.scope,
            .catalog(firstOwner)
        )

        model.selectedHostID = second.id
        let secondOwner = try XCTUnwrap(model.primaryCatalogState?.owner)
        XCTAssertNotEqual(firstOwner, secondOwner)
        let staleRetryAccepted = await model.retryAppCatalog(in: workspace)
        let requestsAfterStaleRetry = await client.requestCount()
        XCTAssertFalse(staleRetryAccepted)
        XCTAssertEqual(requestsAfterStaleRetry, 1)
        XCTAssertEqual(model.primaryCatalogState?.phase, .idle)

        await model.refreshAppsForSelectedHost(in: workspace)
        XCTAssertEqual(model.primaryCatalogState?.phase, .failed(hasCachedApps: false))
        XCTAssertEqual(
            model.primaryCatalogState?.issue?.action?.scope,
            .catalog(secondOwner)
        )
        let recoveryAccepted = await model.retryAppCatalog(in: workspace)

        XCTAssertTrue(recoveryAccepted)
        XCTAssertEqual(model.primaryCatalogState?.owner, secondOwner)
        XCTAssertEqual(model.primaryCatalogState?.phase, .current)
        XCTAssertEqual(model.selectedApps, apps)
        XCTAssertEqual(model.selectedAppID, apps.first?.id)
        let totalRequests = await client.requestCount()
        XCTAssertEqual(totalRequests, 3)
    }

    private func makeModel(
        hosts: [MoonlightHost],
        appListClient: any AppListClient = FixedProductCatalogClient(apps: []),
        repository: any AppCatalogSnapshotRepository = InMemoryAppCatalogSnapshotRepository()
    ) -> AppModel {
        AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(hosts: hosts),
                serverInfoClient: ProductCatalogServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: appListClient,
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: repository,
            streamSessionCoordinator: StreamSessionCoordinator(
                launchClient: HTTPStreamLaunchClient()
            ),
            runtimeProviders: .unavailable,
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientUniqueID: "catalog-workspace-test"
        )
    }

    private func makeHost(
        idSuffix: UInt8,
        name: String
    ) -> MoonlightHost {
        MoonlightHost(
            id: UUID(uuidString: String(
                format: "70000000-0000-0000-0000-%012d",
                idSuffix
            ))!,
            name: name,
            address: "host-\(idSuffix).local",
            pairingState: .paired,
            reachability: .online
        )
    }

    private func makeApps() -> [RemoteApp] {
        [
            RemoteApp(id: "1", name: "Desktop", supportsHDR: false, installPath: nil),
            RemoteApp(id: "2", name: "Game", supportsHDR: true, installPath: nil)
        ]
    }

    private var rootViewURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LuneXApp/RootView.swift")
    }
}

private enum ProductCatalogTestError: Error, Sendable {
    case expectedFailure
}

private struct FixedProductCatalogClient: AppListClient {
    var apps: [RemoteApp] = []
    var shouldFail = false

    func fetchApps(
        from endpoint: HostEndpoint,
        clientUniqueID: String,
        pinnedIdentity: PinnedHostIdentity?
    ) async throws -> [RemoteApp] {
        _ = endpoint
        _ = clientUniqueID
        _ = pinnedIdentity
        if shouldFail { throw ProductCatalogTestError.expectedFailure }
        return apps
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

private actor ScriptedProductCatalogClient: AppListClient {
    private var results: [Result<[RemoteApp], ProductCatalogTestError>]
    private var requests = 0

    init(results: [Result<[RemoteApp], ProductCatalogTestError>]) {
        self.results = results
    }

    func fetchApps(
        from endpoint: HostEndpoint,
        clientUniqueID: String,
        pinnedIdentity: PinnedHostIdentity?
    ) async throws -> [RemoteApp] {
        _ = endpoint
        _ = clientUniqueID
        _ = pinnedIdentity
        requests += 1
        guard !results.isEmpty else { throw ProductCatalogTestError.expectedFailure }
        return try results.removeFirst().get()
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

    func requestCount() -> Int { requests }
}

private actor SuspendedProductCatalogClient: AppListClient {
    private var continuation: CheckedContinuation<[RemoteApp], Error>?

    func fetchApps(
        from endpoint: HostEndpoint,
        clientUniqueID: String,
        pinnedIdentity: PinnedHostIdentity?
    ) async throws -> [RemoteApp] {
        _ = endpoint
        _ = clientUniqueID
        _ = pinnedIdentity
        return try await withCheckedThrowingContinuation { continuation = $0 }
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

    func waitUntilPending() async {
        while continuation == nil { await Task.yield() }
    }

    func resume(with apps: [RemoteApp]) {
        continuation?.resume(returning: apps)
        continuation = nil
    }
}

private actor SuspendedRetryProductCatalogClient: AppListClient {
    private var requests = 0
    private var retryContinuation: CheckedContinuation<[RemoteApp], Error>?

    func fetchApps(
        from endpoint: HostEndpoint,
        clientUniqueID: String,
        pinnedIdentity: PinnedHostIdentity?
    ) async throws -> [RemoteApp] {
        _ = endpoint
        _ = clientUniqueID
        _ = pinnedIdentity
        requests += 1
        guard requests > 1 else {
            throw ProductCatalogTestError.expectedFailure
        }
        return try await withCheckedThrowingContinuation {
            retryContinuation = $0
        }
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

    func waitUntilRetryIsPending() async {
        while retryContinuation == nil { await Task.yield() }
    }

    func resumeRetry(with apps: [RemoteApp]) {
        retryContinuation?.resume(returning: apps)
        retryContinuation = nil
    }

    func requestCount() -> Int { requests }
}

private actor RecordingProductCatalogRepository: AppCatalogSnapshotRepository {
    private var snapshots: [AppListSnapshot] = []
    private var saves = 0

    func loadSnapshots() async throws -> [AppListSnapshot] { snapshots }

    func saveSnapshots(_ snapshots: [AppListSnapshot]) async throws {
        self.snapshots = snapshots
        saves += 1
    }

    func saveCount() -> Int { saves }
}

private actor SuspendedProductCatalogRepository: AppCatalogSnapshotRepository {
    private var continuation: CheckedContinuation<[AppListSnapshot], Error>?

    func loadSnapshots() async throws -> [AppListSnapshot] {
        try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func saveSnapshots(_ snapshots: [AppListSnapshot]) async throws {
        _ = snapshots
    }

    func waitUntilPending() async {
        while continuation == nil { await Task.yield() }
    }

    func resume(with snapshots: [AppListSnapshot]) {
        continuation?.resume(returning: snapshots)
        continuation = nil
    }
}

private struct ProductCatalogServerInfoClient: ServerInfoClient {
    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        _ = endpoint
        return ServerInfo(
            name: "Catalog Host",
            uniqueID: "catalog-host",
            macAddress: nil,
            state: "ONLINE",
            supportsHDR: true,
            rawValues: [:]
        )
    }
}
