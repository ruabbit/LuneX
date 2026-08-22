import XCTest

@MainActor
final class ProductHostWorkspaceTests: XCTestCase {
    func testSharedHostAddPublishesAvailabilityWithoutOverwritingLocalPresentation()
        async throws
    {
        let repository = RecordingProductHostRepository()
        let model = makeModel(repository: repository)
        let primary = model.primaryWorkspaceReference
        let secondary = try model.workspaceRegistry.create()

        await model.loadHosts(in: primary)
        XCTAssertEqual(
            model.workspaceState(for: primary)?.hostLibrary.phase,
            .firstUse
        )
        XCTAssertEqual(
            model.workspaceState(for: secondary)?.hostLibrary.phase,
            .firstUse
        )

        XCTAssertTrue(model.setNavigationSelection(.settings, in: secondary))
        XCTAssertTrue(model.presentAddHostSheet(in: secondary))
        let secondaryDraft = ManualHostDraft(
            name: "Keep Local",
            address: "secondary.local"
        )
        model.setManualHostDraft(secondaryDraft, in: secondary)
        model.setManualHostDraft(
            ManualHostDraft(name: "Studio", address: "shared.local"),
            in: primary
        )

        guard case let .succeeded(hostID) = await model.addManualHost(in: primary)
        else {
            return XCTFail("Expected the shared host mutation to succeed")
        }

        XCTAssertEqual(model.hosts.map(\.id), [hostID])
        XCTAssertEqual(
            model.workspaceState(for: primary)?.hostLibrary.phase,
            .available
        )
        XCTAssertEqual(
            model.workspaceState(for: secondary)?.hostLibrary.phase,
            .available
        )
        XCTAssertEqual(model.selectedHostID(in: primary), hostID)
        XCTAssertEqual(model.selectedHostID(in: secondary), hostID)
        XCTAssertEqual(model.navigationSelection(in: secondary), .settings)
        XCTAssertEqual(model.workspaceSheet(in: secondary), .addHost)
        XCTAssertEqual(
            model.workspaceState(for: secondary)?.hostLibrary.manualHostDraft,
            secondaryDraft
        )
    }

    func testSettingsRepositoryRemainsSharedWithoutCopyingWorkspaceState()
        async throws
    {
        let settingsRepository = InMemoryAppSettingsRepository()
        let model = makeModel(
            repository: InMemoryHostRepository(),
            settingsRepository: settingsRepository
        )
        let primary = model.primaryWorkspaceReference
        let secondary = try model.workspaceRegistry.create()
        XCTAssertTrue(model.setNavigationSelection(.settings, in: secondary))

        model.settings.stream.frameRate = 240
        model.settings.input.showVirtualController = true
        await model.saveSettings()

        let persisted = try await settingsRepository.loadSettings()
        XCTAssertEqual(persisted, model.settings)
        XCTAssertEqual(persisted.stream.frameRate, 240)
        XCTAssertTrue(persisted.input.showVirtualController)
        XCTAssertEqual(model.workspaceState(for: primary)?.reference, primary)
        XCTAssertEqual(model.workspaceState(for: secondary)?.reference, secondary)
        XCTAssertEqual(model.navigationSelection(in: primary), .library)
        XCTAssertEqual(model.navigationSelection(in: secondary), .settings)
        XCTAssertNil(model.activeProductSessionOwner)
    }

    func testWorkspaceBindingsKeepNavigationSelectionSheetAndDialogLocal()
        async throws
    {
        let firstHost = makeHost(idSuffix: 30, address: "first.local")
        let secondHost = makeHost(idSuffix: 31, address: "second.local")
        let model = makeModel(repository: InMemoryHostRepository(
            hosts: [firstHost, secondHost]
        ))
        await model.loadHosts()

        let primary = model.primaryWorkspaceReference
        let secondary = try model.workspaceRegistry.create()
        XCTAssertTrue(model.setNavigationSelection(.settings, in: secondary))
        XCTAssertTrue(model.setSelectedHostID(secondHost.id, in: secondary))

        XCTAssertEqual(model.navigationSelection(in: primary), .library)
        XCTAssertEqual(model.navigationSelection(in: secondary), .settings)
        XCTAssertEqual(model.selectedHost(in: primary)?.id, firstHost.id)
        XCTAssertEqual(model.selectedHost(in: secondary)?.id, secondHost.id)

        XCTAssertTrue(model.presentAddHostSheet(in: secondary))
        model.setManualHostDraft(
            ManualHostDraft(name: "Second", address: "invalid address"),
            in: secondary
        )
        XCTAssertNil(model.workspaceSheet(in: primary))
        XCTAssertEqual(model.workspaceSheet(in: secondary), .addHost)
        XCTAssertEqual(
            model.workspaceState(for: secondary)?.hostLibrary.manualHostDraft.name,
            "Second"
        )
        XCTAssertTrue(model.dismissAddHostSheet(in: secondary))
        XCTAssertNil(model.workspaceSheet(in: secondary))
        XCTAssertEqual(
            model.workspaceState(for: secondary)?.hostLibrary.manualHostDraft,
            ManualHostDraft()
        )

        let confirmation = try XCTUnwrap(
            model.requestHostRemoval(in: secondary)
        )
        XCTAssertEqual(
            model.workspaceState(for: secondary)?.presentation.dialog,
            .removeHost(confirmation)
        )
        XCTAssertNil(model.workspaceState(for: primary)?.presentation.dialog)
        model.cancelHostDestructiveAction(in: secondary)
        XCTAssertNil(model.workspaceState(for: secondary)?.presentation.dialog)

        _ = try model.workspaceRegistry.replace(secondary)
        XCTAssertFalse(model.setNavigationSelection(.stream, in: secondary))
        XCTAssertFalse(model.setSelectedHostID(firstHost.id, in: secondary))
        XCTAssertFalse(model.presentAddHostSheet(in: secondary))
        XCTAssertFalse(model.dismissAddHostSheet(in: secondary))
    }

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

    func testHostLoadRetryRequiresCurrentTypedWorkspaceAction() async throws {
        let repository = RetryProductHostRepository()
        let model = makeModel(repository: repository)

        await model.loadHosts()
        let admitted = await model.retryHostLibraryLoad(
            in: model.primaryWorkspaceReference
        )
        let duplicate = await model.retryHostLibraryLoad(
            in: model.primaryWorkspaceReference
        )

        XCTAssertTrue(admitted)
        XCTAssertFalse(duplicate)
        XCTAssertEqual(model.primaryWorkspaceState?.hostLibrary.phase, .firstUse)
        XCTAssertNil(model.primaryWorkspaceState?.hostLibrary.refreshIssue)
        let loadCount = await repository.loadCount()
        XCTAssertEqual(loadCount, 2)
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

    func testManualHostSubmissionPresentationDismissesOnlyAfterSuccess() {
        let hostID = makeHost(idSuffix: 9, address: "state.local").id
        let issue = ProductIssue(code: .hostAddressInvalid)

        for state in [
            ManualHostSubmissionState.idle,
            .validating,
            .saving,
            .failed(issue)
        ] {
            XCTAssertFalse(state.shouldDismissSheet)
        }
        XCTAssertFalse(ManualHostSubmissionState.idle.isSubmitting)
        XCTAssertTrue(ManualHostSubmissionState.validating.isSubmitting)
        XCTAssertTrue(ManualHostSubmissionState.saving.isSubmitting)
        XCTAssertFalse(ManualHostSubmissionState.failed(issue).isSubmitting)
        XCTAssertNil(ManualHostSubmissionState.saving.fieldIssue)
        XCTAssertEqual(ManualHostSubmissionState.failed(issue).fieldIssue, issue)
        XCTAssertTrue(
            ManualHostSubmissionState.succeeded(hostID: hostID).shouldDismissSheet
        )
    }

    func testAddHostSheetAwaitsWorkspaceResultBeforeConditionalDismiss() throws {
        let source = try String(contentsOf: rootViewURL, encoding: .utf8)

        XCTAssertTrue(source.contains("AddHostSheet(workspace:"))
        XCTAssertTrue(source.contains("let result = await appModel.addManualHost(in: workspace)"))
        XCTAssertTrue(source.contains("if result.shouldDismissSheet"))
        XCTAssertTrue(source.contains(".interactiveDismissDisabled(isSubmitting)"))
        XCTAssertTrue(source.contains("Text(issue.presentation.message)"))
        XCTAssertTrue(source.contains("focusedField = .manualHostAddress"))
        XCTAssertFalse(source.contains("let onAdd: (String?, String) -> Void"))
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

    func testDuplicateManualHostSubmissionDoesNotStartAnotherSave() async throws {
        let repository = SuspendedProductHostSaveRepository()
        let model = makeModel(repository: repository)
        let workspace = model.primaryWorkspaceReference
        model.setManualHostDraft(
            ManualHostDraft(name: "Studio", address: "once.local"),
            in: workspace
        )

        let first = Task { await model.addManualHost(in: workspace) }
        await repository.waitUntilSaveIsPending()
        let duplicate = await model.addManualHost(in: workspace)

        XCTAssertEqual(duplicate, .saving)
        let saveCountBeforeCompletion = await repository.saveCount()
        XCTAssertEqual(saveCountBeforeCompletion, 1)
        await repository.resumeSave()
        guard case .succeeded = await first.value else {
            return XCTFail("Expected the original submission to succeed")
        }
        let saveCountAfterCompletion = await repository.saveCount()
        XCTAssertEqual(saveCountAfterCompletion, 1)
    }

    func testApplicationFirstUseManualEntryAndRestorationWorkflow() async throws {
        let repository = RecordingProductHostRepository()
        let model = makeModel(repository: repository)
        let workspace = model.primaryWorkspaceReference

        await model.loadHosts(in: workspace)
        XCTAssertEqual(model.primaryWorkspaceState?.hostLibrary.phase, .firstUse)
        XCTAssertEqual(
            ProductHostLibrarySurface(
                library: try XCTUnwrap(model.primaryWorkspaceState?.hostLibrary),
                hostCount: model.hosts.count,
                selectedHost: model.selectedHost
            ).content,
            .firstUse
        )

        model.setManualHostDraft(
            ManualHostDraft(name: "Invalid", address: "   "),
            in: workspace
        )
        let invalid = await model.addManualHost(in: workspace)
        guard case let .failed(issue) = invalid else {
            return XCTFail("Expected typed invalid manual entry")
        }
        XCTAssertEqual(issue.code, .hostAddressRequired)
        XCTAssertEqual(issue.action?.scope, .workspace(workspace))
        let savesAfterInvalid = await repository.saveCount()
        XCTAssertEqual(savesAfterInvalid, 0)

        model.setManualHostDraft(
            ManualHostDraft(name: "  Studio  ", address: "  Moon.Local.  "),
            in: workspace
        )
        let valid = await model.addManualHost(in: workspace)
        guard case let .succeeded(hostID) = valid else {
            return XCTFail("Expected valid manual entry to persist")
        }
        XCTAssertEqual(model.selectedHostID, hostID)
        XCTAssertEqual(model.selectedHost?.address, "moon.local")
        XCTAssertEqual(model.primaryWorkspaceState?.hostLibrary.phase, .available)

        let restored = makeModel(repository: repository)
        await restored.loadHosts()
        XCTAssertEqual(restored.primaryWorkspaceState?.hostLibrary.phase, .available)
        XCTAssertEqual(restored.selectedHostID, hostID)
        XCTAssertEqual(restored.hosts.map(\.id), [hostID])
        XCTAssertEqual(
            restored.primaryWorkspaceState?.hostLibrary.manualHostSubmission,
            .idle
        )
    }

    private func makeModel(
        repository: any HostRepository,
        settingsRepository: any AppSettingsRepository = InMemoryAppSettingsRepository()
    ) -> AppModel {
        AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: repository,
                serverInfoClient: ProductHostServerInfoClient()
            ),
            settingsRepository: settingsRepository,
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

    private var rootViewURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LuneXApp/RootView.swift")
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

private actor RetryProductHostRepository: HostRepository {
    private var loads = 0

    func loadHosts() async throws -> [MoonlightHost] {
        loads += 1
        if loads == 1 {
            throw ProductHostTestError.expectedFailure
        }
        return []
    }

    func saveHosts(_ hosts: [MoonlightHost]) async throws {
        _ = hosts
    }

    func loadCount() -> Int { loads }
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
    private var saves = 0

    func loadHosts() async throws -> [MoonlightHost] {
        []
    }

    func saveHosts(_ hosts: [MoonlightHost]) async throws {
        _ = hosts
        saves += 1
        await withCheckedContinuation { continuation = $0 }
    }

    func waitUntilSaveIsPending() async {
        while continuation == nil { await Task.yield() }
    }

    func resumeSave() {
        continuation?.resume()
        continuation = nil
    }

    func saveCount() -> Int { saves }
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
