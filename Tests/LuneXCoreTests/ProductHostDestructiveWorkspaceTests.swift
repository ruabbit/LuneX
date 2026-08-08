import XCTest

@MainActor
final class ProductHostDestructiveWorkspaceTests: XCTestCase {
    func testInactiveRemovalRequiresExplicitConfirmationAndCancelIsNonMutating()
        async throws
    {
        let hosts = [makeHost(1), makeHost(2)]
        let snapshots = makeSnapshots(hosts: hosts)
        let hostRepository = DestructiveHostRepository(hosts: hosts)
        let catalogRepository = DestructiveCatalogRepository(snapshots: snapshots)
        let model = makeModel(
            hostRepository: hostRepository,
            catalogRepository: catalogRepository
        )
        await model.loadInitialState()

        let confirmation = try XCTUnwrap(
            model.requestHostRemoval(in: model.primaryWorkspaceReference)
        )
        XCTAssertEqual(confirmation.kind, .remove)
        XCTAssertFalse(confirmation.requiresSessionStop)
        XCTAssertEqual(
            model.primaryWorkspaceState?.presentation.dialog,
            .removeHost(confirmation)
        )
        XCTAssertEqual(
            model.hostDestructiveState(for: model.primaryWorkspaceReference),
            .awaitingConfirmation(confirmation)
        )

        model.cancelHostDestructiveAction(in: model.primaryWorkspaceReference)

        XCTAssertEqual(
            model.hostDestructiveState(for: model.primaryWorkspaceReference),
            .idle
        )
        XCTAssertNil(model.primaryWorkspaceState?.presentation.dialog)
        let persistedHosts = await hostRepository.currentHosts()
        let persistedSnapshots = await catalogRepository.currentSnapshots()
        XCTAssertEqual(persistedHosts, hosts)
        XCTAssertEqual(persistedSnapshots, snapshots)
        XCTAssertEqual(model.hosts, hosts)
    }

    func testRemovalDeletesOnlyTargetHostAndItsCachedCatalog() async throws {
        let hosts = [makeHost(1), makeHost(2)]
        let snapshots = makeSnapshots(hosts: hosts)
        let hostRepository = DestructiveHostRepository(hosts: hosts)
        let catalogRepository = DestructiveCatalogRepository(snapshots: snapshots)
        let model = makeModel(
            hostRepository: hostRepository,
            catalogRepository: catalogRepository
        )
        await model.loadInitialState()
        model.selectedHostID = hosts[0].id

        _ = try XCTUnwrap(
            model.requestHostRemoval(in: model.primaryWorkspaceReference)
        )
        let result = await model.confirmHostDestructiveAction(
            in: model.primaryWorkspaceReference
        )

        XCTAssertEqual(result, .succeeded(kind: .remove, hostID: hosts[0].id))
        XCTAssertEqual(model.hosts, [hosts[1]])
        let persistedHosts = await hostRepository.currentHosts()
        let persistedSnapshots = await catalogRepository.currentSnapshots()
        XCTAssertEqual(persistedHosts, [hosts[1]])
        XCTAssertEqual(persistedSnapshots, [snapshots[1]])
        XCTAssertEqual(model.selectedHostID, hosts[1].id)
    }

    func testTrustResetPreservesHostAndUnrelatedHostState() async throws {
        let hosts = [makeHost(1), makeHost(2)]
        let hostRepository = DestructiveHostRepository(hosts: hosts)
        let catalogRepository = DestructiveCatalogRepository(
            snapshots: makeSnapshots(hosts: hosts)
        )
        let model = makeModel(
            hostRepository: hostRepository,
            catalogRepository: catalogRepository
        )
        await model.loadInitialState()
        model.selectedHostID = hosts[0].id

        let confirmation = try XCTUnwrap(
            model.requestHostTrustReset(in: model.primaryWorkspaceReference)
        )
        XCTAssertEqual(confirmation.kind, .resetTrust)
        let result = await model.confirmHostDestructiveAction(
            in: model.primaryWorkspaceReference
        )

        XCTAssertEqual(
            result,
            .succeeded(kind: .resetTrust, hostID: hosts[0].id)
        )
        let reset = try XCTUnwrap(model.hosts.first { $0.id == hosts[0].id })
        let unrelated = try XCTUnwrap(model.hosts.first { $0.id == hosts[1].id })
        XCTAssertEqual(reset.pairingState, .unpaired)
        XCTAssertNil(reset.pinnedIdentity)
        XCTAssertEqual(unrelated, hosts[1])
        XCTAssertEqual(model.hosts.count, 2)
        let persisted = await hostRepository.currentHosts()
        XCTAssertEqual(persisted.first { $0.id == hosts[1].id }, hosts[1])
    }

    func testHostRepositoryFailurePreservesHostAndRestoresCatalog() async throws {
        let hosts = [makeHost(1), makeHost(2)]
        let snapshots = makeSnapshots(hosts: hosts)
        let hostRepository = DestructiveHostRepository(
            hosts: hosts,
            failingSaveCount: 1
        )
        let catalogRepository = DestructiveCatalogRepository(snapshots: snapshots)
        let model = makeModel(
            hostRepository: hostRepository,
            catalogRepository: catalogRepository
        )
        await model.loadInitialState()
        model.selectedHostID = hosts[0].id
        _ = try XCTUnwrap(
            model.requestHostRemoval(in: model.primaryWorkspaceReference)
        )

        let result = await model.confirmHostDestructiveAction(
            in: model.primaryWorkspaceReference
        )

        guard case let .failed(confirmation, issue) = result else {
            return XCTFail("Expected a typed removal failure")
        }
        XCTAssertEqual(issue.code, .hostRemoveFailed)
        XCTAssertEqual(issue.action?.scope, .host(confirmation.owner))
        XCTAssertEqual(model.hosts, hosts)
        let persistedHosts = await hostRepository.currentHosts()
        let persistedSnapshots = await catalogRepository.currentSnapshots()
        let catalogSaveCount = await catalogRepository.saveCount()
        XCTAssertEqual(persistedHosts, hosts)
        XCTAssertEqual(persistedSnapshots, snapshots)
        XCTAssertEqual(catalogSaveCount, 2)
    }

    func testHostABAAndWorkspaceReplacementRejectStaleConfirmation() async throws {
        let hosts = [makeHost(1), makeHost(2)]
        let hostRepository = DestructiveHostRepository(hosts: hosts)
        let catalogRepository = DestructiveCatalogRepository(
            snapshots: makeSnapshots(hosts: hosts)
        )
        let model = makeModel(
            hostRepository: hostRepository,
            catalogRepository: catalogRepository
        )
        await model.loadInitialState()
        let workspace = model.primaryWorkspaceReference
        model.selectedHostID = hosts[0].id
        let staleABA = try XCTUnwrap(model.requestHostRemoval(in: workspace))

        model.selectedHostID = hosts[1].id
        model.selectedHostID = hosts[0].id
        XCTAssertNil(model.beginHostDestructiveAction(in: workspace))
        let staleABAResult = await model.performHostDestructiveAction(staleABA)
        XCTAssertEqual(staleABAResult, .idle)

        _ = try XCTUnwrap(model.requestHostRemoval(in: workspace))
        let replacement = try model.workspaceRegistry.replace(workspace)
        XCTAssertNil(model.beginHostDestructiveAction(in: workspace))
        XCTAssertNil(model.workspaceState(for: workspace))
        XCTAssertEqual(model.workspaceState(for: replacement)?.selectedHostID, hosts[0].id)
        let persistedHosts = await hostRepository.currentHosts()
        XCTAssertEqual(persistedHosts, hosts)
    }

    func testNonOwningWorkspaceCannotConfirmAnotherWorkspaceAction() async throws {
        let hosts = [makeHost(1), makeHost(2)]
        let hostRepository = DestructiveHostRepository(hosts: hosts)
        let catalogRepository = DestructiveCatalogRepository(
            snapshots: makeSnapshots(hosts: hosts)
        )
        let model = makeModel(
            hostRepository: hostRepository,
            catalogRepository: catalogRepository
        )
        await model.loadInitialState()
        model.selectedHostID = hosts[0].id
        let ownerWorkspace = model.primaryWorkspaceReference
        let otherWorkspace = try model.workspaceRegistry.create(
            restoration: ProductWorkspaceRestorationState(selectedHostID: hosts[0].id)
        )
        let confirmation = try XCTUnwrap(
            model.requestHostRemoval(in: ownerWorkspace)
        )

        let nonOwnerResult = await model.confirmHostDestructiveAction(
            in: otherWorkspace
        )
        XCTAssertEqual(nonOwnerResult, .idle)
        XCTAssertEqual(
            model.hostDestructiveState(for: ownerWorkspace),
            .awaitingConfirmation(confirmation)
        )
        let saveCount = await hostRepository.saveAttemptCount()
        XCTAssertEqual(saveCount, 0)
        model.cancelHostDestructiveAction(in: ownerWorkspace)
    }

    func testWorkspaceReplacementDuringRepositoryLoadRejectsAndPreservesHost()
        async throws
    {
        let hosts = [makeHost(1), makeHost(2)]
        let hostRepository = DestructiveHostRepository(hosts: hosts)
        let catalogRepository = DestructiveCatalogRepository(
            snapshots: makeSnapshots(hosts: hosts)
        )
        let model = makeModel(
            hostRepository: hostRepository,
            catalogRepository: catalogRepository
        )
        await model.loadHosts()
        model.selectedHostID = hosts[0].id
        let workspace = model.primaryWorkspaceReference
        await catalogRepository.suspendNextLoad()
        _ = try XCTUnwrap(model.requestHostRemoval(in: workspace))

        let operation = Task {
            await model.confirmHostDestructiveAction(in: workspace)
        }
        await catalogRepository.waitUntilLoadIsSuspended()
        let replacement = try model.workspaceRegistry.replace(workspace)
        await catalogRepository.resumeSuspendedLoad()
        let result = await operation.value

        guard case let .failed(_, issue) = result else {
            return XCTFail("Expected a stale checked action")
        }
        XCTAssertEqual(issue.code, .staleAction)
        XCTAssertNil(model.workspaceState(for: workspace))
        XCTAssertEqual(model.workspaceState(for: replacement)?.selectedHostID, hosts[0].id)
        let persistedHosts = await hostRepository.currentHosts()
        let saveCount = await hostRepository.saveAttemptCount()
        XCTAssertEqual(persistedHosts, hosts)
        XCTAssertEqual(saveCount, 0)
    }

    func testSessionAppearingAfterNonStopConfirmationRequiresReconfirmation()
        async throws
    {
        let hosts = [makeHost(1), makeHost(2)]
        let recorder = DestructiveEventRecorder()
        let control = DestructiveSessionControlProvider(recorder: recorder)
        let hostRepository = DestructiveHostRepository(hosts: hosts, recorder: recorder)
        let catalogRepository = DestructiveCatalogRepository(
            snapshots: makeSnapshots(hosts: hosts),
            recorder: recorder
        )
        let model = makeStreamingModel(
            hostRepository: hostRepository,
            catalogRepository: catalogRepository,
            control: control
        )
        await model.loadInitialState()
        model.selectedHostID = hosts[0].id
        let first = try XCTUnwrap(
            model.requestHostRemoval(in: model.primaryWorkspaceReference)
        )
        XCTAssertFalse(first.requiresSessionStop)

        let launch = Task { await model.launchSelectedApp() }
        await control.waitUntilStarted()
        let result = await model.confirmHostDestructiveAction(
            in: model.primaryWorkspaceReference
        )

        guard case let .failed(_, issue) = result else {
            return XCTFail("Expected confirmation to be invalidated by the active session")
        }
        XCTAssertEqual(issue.code, .hostRemoveFailed)
        XCTAssertEqual(model.session.activeHostID, hosts[0].id)
        let stoppedBeforeCleanup = control.stoppedSessionIDs()
        XCTAssertTrue(stoppedBeforeCleanup.isEmpty)
        let retry = try XCTUnwrap(
            model.retryHostDestructiveAction(in: model.primaryWorkspaceReference)
        )
        XCTAssertTrue(retry.requiresSessionStop)
        model.cancelHostDestructiveAction(in: model.primaryWorkspaceReference)
        await model.stopStream()
        await launch.value
        XCTAssertEqual(model.hosts, hosts)
    }

    func testStopAndRemoveCompletesStopBeforeRepositoryMutation() async throws {
        let hosts = [makeHost(1), makeHost(2)]
        let recorder = DestructiveEventRecorder()
        let control = DestructiveSessionControlProvider(recorder: recorder)
        let hostRepository = DestructiveHostRepository(hosts: hosts, recorder: recorder)
        let catalogRepository = DestructiveCatalogRepository(
            snapshots: makeSnapshots(hosts: hosts),
            recorder: recorder
        )
        let model = makeStreamingModel(
            hostRepository: hostRepository,
            catalogRepository: catalogRepository,
            control: control
        )
        await model.loadInitialState()
        model.selectedHostID = hosts[0].id
        let launch = Task { await model.launchSelectedApp() }
        await control.waitUntilStarted()

        let confirmation = try XCTUnwrap(
            model.requestHostRemoval(in: model.primaryWorkspaceReference)
        )
        XCTAssertTrue(confirmation.requiresSessionStop)
        let result = await model.confirmHostDestructiveAction(
            in: model.primaryWorkspaceReference
        )
        await launch.value

        XCTAssertEqual(result, .succeeded(kind: .remove, hostID: hosts[0].id))
        XCTAssertNil(model.session.activeHostID)
        let events = await recorder.currentEvents()
        let stopIndex = try XCTUnwrap(events.firstIndex(of: .sessionStop))
        let catalogIndex = try XCTUnwrap(events.firstIndex(of: .catalogSave))
        let hostIndex = try XCTUnwrap(events.firstIndex(of: .hostSave))
        XCTAssertLessThan(stopIndex, catalogIndex)
        XCTAssertLessThan(stopIndex, hostIndex)
    }

    func testActivePairingIsCancelledBeforeDestructiveMutation() async throws {
        let hosts = [makeHost(1), makeHost(2)]
        let recorder = DestructiveEventRecorder()
        let pairing = DestructivePairingProvider(recorder: recorder)
        let hostRepository = DestructiveHostRepository(hosts: hosts, recorder: recorder)
        let catalogRepository = DestructiveCatalogRepository(
            snapshots: makeSnapshots(hosts: hosts),
            recorder: recorder
        )
        let model = makeModel(
            hostRepository: hostRepository,
            catalogRepository: catalogRepository,
            runtimeProviders: RuntimeProviderInventory(pairing: pairing),
            identityProvisioner: DestructiveIdentityProvisioner()
        )
        await model.loadInitialState()
        model.selectedHostID = hosts[0].id
        await model.beginPairing(
            host: hosts[0],
            in: model.primaryWorkspaceReference
        )
        XCTAssertEqual(model.primaryPairingState?.stage, .waitingForPIN)

        _ = try XCTUnwrap(
            model.requestHostRemoval(in: model.primaryWorkspaceReference)
        )
        let result = await model.confirmHostDestructiveAction(
            in: model.primaryWorkspaceReference
        )

        XCTAssertEqual(result, .succeeded(kind: .remove, hostID: hosts[0].id))
        let events = await recorder.currentEvents()
        let cancelIndex = try XCTUnwrap(events.firstIndex(of: .pairingCancel))
        let catalogIndex = try XCTUnwrap(events.firstIndex(of: .catalogSave))
        let hostIndex = try XCTUnwrap(events.firstIndex(of: .hostSave))
        XCTAssertLessThan(cancelIndex, catalogIndex)
        XCTAssertLessThan(cancelIndex, hostIndex)
    }

    func testApplicationTrustResetAndStopThenRemoveWorkflow() async throws {
        let hosts = [makeHost(1), makeHost(2)]
        let snapshots = makeSnapshots(hosts: hosts)
        let trustRepository = DestructiveHostRepository(hosts: hosts)
        let trustCatalog = DestructiveCatalogRepository(snapshots: snapshots)
        let trustModel = makeModel(
            hostRepository: trustRepository,
            catalogRepository: trustCatalog
        )
        await trustModel.loadInitialState()
        trustModel.selectedHostID = hosts[0].id

        _ = try XCTUnwrap(
            trustModel.requestHostTrustReset(
                in: trustModel.primaryWorkspaceReference
            )
        )
        let reset = await trustModel.confirmHostDestructiveAction(
            in: trustModel.primaryWorkspaceReference
        )
        XCTAssertEqual(
            reset,
            .succeeded(kind: .resetTrust, hostID: hosts[0].id)
        )
        let resetHost = try XCTUnwrap(
            trustModel.hosts.first { $0.id == hosts[0].id }
        )
        XCTAssertEqual(resetHost.pairingState, .unpaired)
        XCTAssertNil(resetHost.pinnedIdentity)
        XCTAssertEqual(
            trustModel.hosts.first { $0.id == hosts[1].id },
            hosts[1]
        )
        let trustSnapshots = await trustCatalog.currentSnapshots()
        XCTAssertEqual(trustSnapshots, snapshots)

        let recorder = DestructiveEventRecorder()
        let control = DestructiveSessionControlProvider(recorder: recorder)
        let removalRepository = DestructiveHostRepository(
            hosts: hosts,
            recorder: recorder
        )
        let removalCatalog = DestructiveCatalogRepository(
            snapshots: snapshots,
            recorder: recorder
        )
        let removalModel = makeStreamingModel(
            hostRepository: removalRepository,
            catalogRepository: removalCatalog,
            control: control
        )
        await removalModel.loadInitialState()
        removalModel.selectedHostID = hosts[0].id
        let launch = Task { await removalModel.launchSelectedApp() }
        await control.waitUntilStarted()

        let confirmation = try XCTUnwrap(
            removalModel.requestHostRemoval(
                in: removalModel.primaryWorkspaceReference
            )
        )
        XCTAssertTrue(confirmation.requiresSessionStop)
        let removal = await removalModel.confirmHostDestructiveAction(
            in: removalModel.primaryWorkspaceReference
        )
        await launch.value

        XCTAssertEqual(
            removal,
            .succeeded(kind: .remove, hostID: hosts[0].id)
        )
        XCTAssertNil(removalModel.session.activeHostID)
        XCTAssertEqual(removalModel.hosts, [hosts[1]])
        let persistedHosts = await removalRepository.currentHosts()
        let persistedSnapshots = await removalCatalog.currentSnapshots()
        XCTAssertEqual(persistedHosts, [hosts[1]])
        XCTAssertEqual(persistedSnapshots, [snapshots[1]])
        let events = await recorder.currentEvents()
        let stopIndex = try XCTUnwrap(events.firstIndex(of: .sessionStop))
        let catalogIndex = try XCTUnwrap(events.firstIndex(of: .catalogSave))
        let hostIndex = try XCTUnwrap(events.firstIndex(of: .hostSave))
        XCTAssertLessThan(stopIndex, catalogIndex)
        XCTAssertLessThan(stopIndex, hostIndex)
    }

    func testDuplicateRequestPerformAndRetryRemainIdempotent() async throws {
        let hosts = [makeHost(1), makeHost(2)]
        let hostRepository = DestructiveHostRepository(
            hosts: hosts,
            failingSaveCount: 1
        )
        let catalogRepository = DestructiveCatalogRepository(
            snapshots: makeSnapshots(hosts: hosts)
        )
        let model = makeModel(
            hostRepository: hostRepository,
            catalogRepository: catalogRepository
        )
        await model.loadInitialState()
        model.selectedHostID = hosts[0].id

        let firstRequest = try XCTUnwrap(
            model.requestHostRemoval(in: model.primaryWorkspaceReference)
        )
        let duplicateRequest = try XCTUnwrap(
            model.requestHostRemoval(in: model.primaryWorkspaceReference)
        )
        XCTAssertEqual(firstRequest, duplicateRequest)
        guard case .failed = await model.confirmHostDestructiveAction(
            in: model.primaryWorkspaceReference
        ) else {
            return XCTFail("Expected the scripted first save to fail")
        }

        let firstRetry = try XCTUnwrap(
            model.retryHostDestructiveAction(in: model.primaryWorkspaceReference)
        )
        XCTAssertNil(
            model.retryHostDestructiveAction(in: model.primaryWorkspaceReference)
        )
        XCTAssertEqual(
            model.hostDestructiveState(for: model.primaryWorkspaceReference),
            .awaitingConfirmation(firstRetry)
        )
        let admitted = try XCTUnwrap(
            model.beginHostDestructiveAction(in: model.primaryWorkspaceReference)
        )
        XCTAssertNil(model.beginHostDestructiveAction(in: model.primaryWorkspaceReference))
        let success = await model.performHostDestructiveAction(admitted)
        XCTAssertEqual(success, .succeeded(kind: .remove, hostID: hosts[0].id))
        let duplicatePerform = await model.performHostDestructiveAction(admitted)
        XCTAssertEqual(duplicatePerform, .idle)
        let saveAttempts = await hostRepository.saveAttemptCount()
        XCTAssertEqual(saveAttempts, 2)
    }

    func testHostLibraryViewUsesConfirmationWorkflowWithoutImmediateMutation()
        throws
    {
        let source = try String(contentsOf: rootViewURL, encoding: .utf8)

        XCTAssertTrue(source.contains("appModel.requestHostRemoval(in: workspace)"))
        XCTAssertTrue(source.contains("appModel.requestHostTrustReset(in: workspace)"))
        XCTAssertTrue(source.contains("appModel.beginHostDestructiveAction("))
        XCTAssertTrue(source.contains("appModel.performHostDestructiveAction(admitted)"))
        XCTAssertTrue(source.contains(".confirmationDialog("))
        XCTAssertTrue(source.contains("if issue.action != nil"))
        XCTAssertFalse(source.contains("removeSelectedHost()"))
    }

    private func makeModel(
        hostRepository: DestructiveHostRepository,
        catalogRepository: DestructiveCatalogRepository,
        runtimeProviders: RuntimeProviderInventory = .unavailable,
        identityProvisioner: (any ClientIdentityProvisioning)? = nil
    ) -> AppModel {
        AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: hostRepository,
                serverInfoClient: DestructiveServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: DestructiveAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: catalogRepository,
            streamSessionCoordinator: StreamSessionCoordinator(
                launchClient: DestructiveStreamLaunchClient()
            ),
            runtimeProviders: runtimeProviders,
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientIdentityProvisioner: identityProvisioner,
            clientUniqueID: "host-destructive-test",
            remoteInputKey: RemoteInputKeyMaterial(
                keyID: 25,
                key: Data(repeating: 0x25, count: 16)
            )
        )
    }

    private func makeStreamingModel(
        hostRepository: DestructiveHostRepository,
        catalogRepository: DestructiveCatalogRepository,
        control: DestructiveSessionControlProvider
    ) -> AppModel {
        makeModel(
            hostRepository: hostRepository,
            catalogRepository: catalogRepository,
            runtimeProviders: RuntimeProviderInventory(
                sessionControl: control,
                videoReceive: DestructiveVideoProvider(),
                audioReceive: DestructiveAudioProvider(),
                remoteInput: DestructiveInputProvider()
            )
        )
    }

    private func makeHost(_ suffix: UInt8) -> MoonlightHost {
        MoonlightHost(
            id: UUID(uuidString: String(
                format: "73000000-0000-0000-0000-%012d",
                suffix
            ))!,
            name: suffix == 1 ? "Alpha" : "Beta",
            address: "host-\(suffix).local",
            pairingState: .paired,
            reachability: .online,
            pinnedIdentity: PinnedHostIdentity(
                certificateSHA256: "certificate-\(suffix)",
                serverCertificateDER: Data([suffix]),
                pairedAt: Date(timeIntervalSince1970: TimeInterval(suffix))
            )
        )
    }

    private func makeSnapshots(hosts: [MoonlightHost]) -> [AppListSnapshot] {
        hosts.enumerated().map { index, host in
            AppListSnapshot(
                hostID: host.id,
                apps: [RemoteApp(
                    id: "app-\(index + 1)",
                    name: "App \(index + 1)",
                    supportsHDR: index == 0,
                    installPath: nil
                )],
                updatedAt: Date(timeIntervalSince1970: TimeInterval(index + 10))
            )
        }
    }

    private var rootViewURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LuneXApp/RootView.swift")
    }
}

private enum DestructiveTestError: Error, Sendable {
    case expectedFailure
}

private enum DestructiveEvent: Equatable, Sendable {
    case sessionStop
    case pairingCancel
    case catalogSave
    case hostSave
}

private actor DestructiveEventRecorder {
    private var events: [DestructiveEvent] = []

    func record(_ event: DestructiveEvent) {
        events.append(event)
    }

    func currentEvents() -> [DestructiveEvent] {
        events
    }
}

private actor DestructiveHostRepository: HostRepository {
    private var hosts: [MoonlightHost]
    private var failingSaveCount: Int
    private var saveAttempts = 0
    private let recorder: DestructiveEventRecorder?

    init(
        hosts: [MoonlightHost],
        failingSaveCount: Int = 0,
        recorder: DestructiveEventRecorder? = nil
    ) {
        self.hosts = hosts
        self.failingSaveCount = failingSaveCount
        self.recorder = recorder
    }

    func loadHosts() async throws -> [MoonlightHost] {
        hosts
    }

    func saveHosts(_ hosts: [MoonlightHost]) async throws {
        saveAttempts += 1
        await recorder?.record(.hostSave)
        if failingSaveCount > 0 {
            failingSaveCount -= 1
            throw DestructiveTestError.expectedFailure
        }
        self.hosts = hosts
    }

    func currentHosts() -> [MoonlightHost] {
        hosts
    }

    func saveAttemptCount() -> Int {
        saveAttempts
    }
}

private actor DestructiveCatalogRepository: AppCatalogSnapshotRepository {
    private var snapshots: [AppListSnapshot]
    private var saves = 0
    private var shouldSuspendNextLoad = false
    private var suspendedLoad: CheckedContinuation<[AppListSnapshot], Never>?
    private let recorder: DestructiveEventRecorder?

    init(
        snapshots: [AppListSnapshot],
        recorder: DestructiveEventRecorder? = nil
    ) {
        self.snapshots = snapshots
        self.recorder = recorder
    }

    func loadSnapshots() async throws -> [AppListSnapshot] {
        guard shouldSuspendNextLoad else { return snapshots }
        shouldSuspendNextLoad = false
        return await withCheckedContinuation { suspendedLoad = $0 }
    }

    func saveSnapshots(_ snapshots: [AppListSnapshot]) async throws {
        saves += 1
        await recorder?.record(.catalogSave)
        self.snapshots = snapshots
    }

    func currentSnapshots() -> [AppListSnapshot] {
        snapshots
    }

    func saveCount() -> Int {
        saves
    }

    func suspendNextLoad() {
        shouldSuspendNextLoad = true
    }

    func waitUntilLoadIsSuspended() async {
        while suspendedLoad == nil { await Task.yield() }
    }

    func resumeSuspendedLoad() {
        suspendedLoad?.resume(returning: snapshots)
        suspendedLoad = nil
    }
}

private final class DestructiveSessionControlProvider:
    SessionControlProvider,
    @unchecked Sendable
{
    private typealias Continuation = AsyncThrowingStream<
        SessionControlEvent,
        Error
    >.Continuation

    private let lock = NSLock()
    private let recorder: DestructiveEventRecorder
    private var starts: [UUID] = []
    private var continuations: [UUID: Continuation] = [:]
    private var stops: [UUID] = []

    init(recorder: DestructiveEventRecorder) {
        self.recorder = recorder
    }

    func start(
        sessionID: UUID,
        request: StreamLaunchRequest
    ) async -> AsyncThrowingStream<SessionControlEvent, Error> {
        _ = request
        return AsyncThrowingStream { continuation in
            withLock {
                starts.append(sessionID)
                continuations[sessionID] = continuation
            }
        }
    }

    func requestIDR(sessionID: UUID) async throws {
        _ = sessionID
    }

    func stop(sessionID: UUID) async {
        await recorder.record(.sessionStop)
        let continuation = withLock {
            stops.append(sessionID)
            return continuations.removeValue(forKey: sessionID)
        }
        continuation?.finish()
    }

    func waitUntilStarted() async {
        while withLock({ starts.isEmpty }) { await Task.yield() }
    }

    func stoppedSessionIDs() -> [UUID] {
        withLock { stops }
    }

    private func withLock<T>(_ operation: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return operation()
    }
}

private actor DestructivePairingProvider: PairingRuntimeProvider {
    private let recorder: DestructiveEventRecorder

    init(recorder: DestructiveEventRecorder) {
        self.recorder = recorder
    }

    func pair(
        _ request: PairingRuntimeRequest
    ) async -> AsyncThrowingStream<PairingRuntimeEvent, Error> {
        _ = request
        return AsyncThrowingStream { _ in }
    }

    func cancelPairing(attemptID: UUID) async {
        _ = attemptID
        await recorder.record(.pairingCancel)
    }
}

private struct DestructiveIdentityProvisioner: ClientIdentityProvisioning {
    func loadOrCreateIdentity(createdAt: Date) async throws -> ClientIdentityMaterial {
        ClientIdentityMaterial(
            id: UUID(uuidString: "74000000-0000-0000-0000-000000000001")!,
            certificateDER: Data([0x30, 0x01]),
            privateKeyDER: Data([0x02, 0x01]),
            createdAt: createdAt
        )
    }
}

private struct DestructiveServerInfoClient: ServerInfoClient {
    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        _ = endpoint
        return ServerInfo(
            name: "Host",
            uniqueID: "host",
            macAddress: nil,
            state: "ONLINE",
            supportsHDR: true,
            rawValues: [:]
        )
    }
}

private struct DestructiveAppListClient: AppListClient {
    func fetchApps(
        from endpoint: HostEndpoint,
        clientUniqueID: String,
        pinnedIdentity: PinnedHostIdentity?
    ) async throws -> [RemoteApp] {
        _ = endpoint
        _ = clientUniqueID
        _ = pinnedIdentity
        return [RemoteApp(
            id: "app-1",
            name: "App 1",
            supportsHDR: true,
            installPath: nil
        )]
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

private actor DestructiveStreamLaunchClient: StreamLaunchClient {
    func launch(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        _ = request
        _ = parameters
        return StreamLaunchResponse(
            sessionURL: "rtsp://example.invalid/session",
            gameSessionID: "session",
            rawValues: [:]
        )
    }

    func resume(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        try await launch(request, parameters: parameters)
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {
        _ = host
        _ = clientUniqueID
    }
}

private struct DestructiveVideoProvider: VideoReceiveProvider {
    func receiveVideo(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedVideoStreamConfiguration
    ) async -> AsyncThrowingStream<VideoReceiveEvent, Error> {
        _ = sessionID
        _ = endpoint
        _ = configuration
        return AsyncThrowingStream { $0.finish() }
    }

    func stopVideo(sessionID: UUID) async {
        _ = sessionID
    }
}

private struct DestructiveAudioProvider: AudioReceiveProvider {
    func receiveAudio(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedAudioStreamConfiguration
    ) async -> AsyncThrowingStream<AudioReceiveEvent, Error> {
        _ = sessionID
        _ = endpoint
        _ = configuration
        return AsyncThrowingStream { $0.finish() }
    }

    func stopAudio(sessionID: UUID) async {
        _ = sessionID
    }
}

private struct DestructiveInputProvider: RemoteInputProvider {
    func startInput(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedInputConfiguration
    ) async throws {
        _ = sessionID
        _ = endpoint
        _ = configuration
    }

    func send(_ event: RemoteInputEvent, sessionID: UUID) async throws {
        _ = event
        _ = sessionID
    }

    func feedback(sessionID: UUID) async -> AsyncStream<RemoteInputFeedback> {
        _ = sessionID
        return AsyncStream { $0.finish() }
    }

    func releaseAll(sessionID: UUID) async {
        _ = sessionID
    }

    func stopInput(sessionID: UUID) async {
        _ = sessionID
    }
}
