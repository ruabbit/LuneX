import XCTest

@MainActor
final class ProductPairingWorkspaceTests: XCTestCase {
    func testFailureAndRetryRotateCheckedAttemptGeneration() async throws {
        let host = makeHost(idSuffix: 1, name: "Retry")
        let provider = PairingWorkspaceProvider()
        let provisioner = FailingPairingWorkspaceIdentityProvisioner()
        let model = makeModel(
            hosts: [host],
            provider: provider,
            identityProvisioner: provisioner
        )
        await model.loadHosts()

        await model.beginPairing(
            host: host,
            in: model.primaryWorkspaceReference
        )
        let failed = try XCTUnwrap(model.primaryPairingState)
        let failedOwner = try XCTUnwrap(failed.owner)

        XCTAssertEqual(failed.stage, .failed)
        XCTAssertNil(failed.attemptID)
        XCTAssertEqual(failed.issue?.code, .pairingFailed)
        XCTAssertEqual(failed.issue?.action?.scope, .pairing(failedOwner))

        let retryAccepted = await model.retryPairing(
            in: model.primaryWorkspaceReference
        )
        XCTAssertTrue(retryAccepted)
        let retriedOwner = try XCTUnwrap(model.primaryPairingState?.owner)
        XCTAssertEqual(retriedOwner.workspace, failedOwner.workspace)
        XCTAssertEqual(retriedOwner.hostID, failedOwner.hostID)
        XCTAssertEqual(
            retriedOwner.hostSelectionGeneration,
            failedOwner.hostSelectionGeneration
        )
        XCTAssertNotEqual(
            retriedOwner.attemptGeneration,
            failedOwner.attemptGeneration
        )
        let attemptCount = await provisioner.attemptCount()
        let requestCount = await provider.requestCount()
        XCTAssertEqual(attemptCount, 2)
        XCTAssertEqual(requestCount, 0)
    }

    func testWorkspaceReplacementRejectsLateIdentityAndCancelsOwner() async throws {
        let host = makeHost(idSuffix: 2, name: "Replacement")
        let provider = PairingWorkspaceProvider()
        let provisioner = SuspendedPairingWorkspaceIdentityProvisioner()
        let model = makeModel(
            hosts: [host],
            provider: provider,
            identityProvisioner: provisioner
        )
        await model.loadHosts()

        let begin = Task {
            await model.beginPairing(
                host: host,
                in: model.primaryWorkspaceReference
            )
        }
        await provisioner.waitUntilPending()
        let staleOwner = try XCTUnwrap(model.primaryPairingState?.owner)
        let replacement = try model.workspaceRegistry.replace(
            model.primaryWorkspaceReference
        )
        await provisioner.resume(with: makeIdentity())
        await begin.value
        await waitForCancellation(
            staleOwner.attemptGeneration.rawValue,
            provider: provider
        )

        XCTAssertEqual(model.workspaceState(for: replacement)?.selectedHostID, host.id)
        XCTAssertEqual(model.workspaceState(for: replacement)?.pairing, PairingUIState())
        XCTAssertEqual(model.session.phase, .disconnected)
        let requestCount = await provider.requestCount()
        XCTAssertEqual(requestCount, 0)
    }

    func testHostABARejectsLateIdentityAndOldRetryOwnership() async throws {
        let first = makeHost(idSuffix: 3, name: "A")
        let second = makeHost(idSuffix: 4, name: "B")
        let provider = PairingWorkspaceProvider()
        let provisioner = SuspendedPairingWorkspaceIdentityProvisioner()
        let model = makeModel(
            hosts: [first, second],
            provider: provider,
            identityProvisioner: provisioner
        )
        await model.loadHosts()
        model.selectedHostID = first.id

        let begin = Task {
            await model.beginPairing(
                host: first,
                in: model.primaryWorkspaceReference
            )
        }
        await provisioner.waitUntilPending()
        let staleOwner = try XCTUnwrap(model.primaryPairingState?.owner)
        model.selectedHostID = second.id
        model.selectedHostID = first.id
        await provisioner.resume(with: makeIdentity())
        await begin.value
        await waitForCancellation(
            staleOwner.attemptGeneration.rawValue,
            provider: provider
        )

        XCTAssertEqual(model.primaryWorkspaceState?.selectedHostID, first.id)
        XCTAssertEqual(model.primaryPairingState, PairingUIState())
        let retryAccepted = await model.retryPairing(
            in: model.primaryWorkspaceReference
        )
        let requestCount = await provider.requestCount()
        XCTAssertFalse(retryAccepted)
        XCTAssertEqual(requestCount, 0)
    }

    func testNonOwningWorkspaceCannotCancelActivePairing() async throws {
        let host = makeHost(idSuffix: 5, name: "Owner")
        let provider = PairingWorkspaceProvider()
        let model = makeModel(
            hosts: [host],
            provider: provider,
            identityProvisioner: FixedPairingWorkspaceIdentityProvisioner(
                identity: makeIdentity()
            )
        )
        await model.loadHosts()
        let other = try model.workspaceRegistry.create()

        await model.beginPairing(
            host: host,
            in: model.primaryWorkspaceReference
        )
        let owner = try XCTUnwrap(model.primaryPairingState?.owner)
        XCTAssertEqual(model.primaryPairingState?.stage, .waitingForPIN)

        await model.beginPairing(host: host, in: other)
        await model.cancelPairing(in: other)

        XCTAssertEqual(model.primaryPairingState?.owner, owner)
        XCTAssertEqual(model.primaryPairingState?.stage, .waitingForPIN)
        let nonOwnerCancellations = await provider.cancelledAttemptIDs()
        XCTAssertTrue(nonOwnerCancellations.isEmpty)

        await model.cancelPairing(in: model.primaryWorkspaceReference)
        await model.cancelPairing(in: model.primaryWorkspaceReference)
        let ownerCancellations = await provider.cancelledAttemptIDs()
        XCTAssertEqual(
            ownerCancellations,
            [owner.attemptGeneration.rawValue]
        )
    }

    func testCancelInvalidatesBeforeLateAuthenticatedCompletion() async throws {
        let host = makeHost(idSuffix: 6, name: "Cancel")
        let provider = PairingWorkspaceProvider()
        let model = makeModel(
            hosts: [host],
            provider: provider,
            identityProvisioner: FixedPairingWorkspaceIdentityProvisioner(
                identity: makeIdentity()
            )
        )
        await model.loadHosts()
        await model.beginPairing(
            host: host,
            in: model.primaryWorkspaceReference
        )
        let owner = try XCTUnwrap(model.primaryPairingState?.owner)
        model.updatePairingPIN("1234", in: model.primaryWorkspaceReference)

        let submit = Task {
            await model.submitPairingPIN(in: model.primaryWorkspaceReference)
        }
        let request = try await provider.waitForLatestRequest()
        await model.cancelPairing(in: model.primaryWorkspaceReference)
        await provider.completeAuthenticated(request)
        await submit.value

        XCTAssertEqual(model.hosts.first?.pairingState, .unpaired)
        XCTAssertNil(model.hosts.first?.pinnedIdentity)
        XCTAssertEqual(model.primaryPairingState?.owner, owner)
        XCTAssertEqual(model.primaryPairingState?.stage, .cancelled)
        XCTAssertNil(model.primaryPairingState?.attemptID)
        XCTAssertEqual(model.primaryPairingState?.issue?.code, .pairingCancelled)
        XCTAssertNil(model.primaryPairingState?.issue?.action)
    }

    func testPairingPanelUsesWorkspaceScopedCommandsAndTypedIssues() throws {
        let source = try String(contentsOf: rootViewURL, encoding: .utf8)

        XCTAssertTrue(source.contains("appModel.pairingState(for: workspace)"))
        XCTAssertTrue(source.contains("appModel.updatePairingPIN($0, in: workspace)"))
        XCTAssertTrue(source.contains("appModel.submitPairingPIN(in: workspace)"))
        XCTAssertTrue(source.contains("appModel.cancelPairing(in: workspace)"))
        XCTAssertTrue(source.contains("appModel.retryPairing(in: workspace)"))
        XCTAssertTrue(source.contains("Text(issue.presentation.message)"))
        XCTAssertFalse(source.contains("$appModel.pairingUI.pin"))
    }

    func testApplicationPairingCancelRetryAndReplacementWorkflow() async throws {
        let host = makeHost(idSuffix: 7, name: "Application")
        let provider = PairingWorkspaceProvider()
        let provisioner = ApplicationPairingIdentityProvisioner(
            identity: makeIdentity()
        )
        let model = makeModel(
            hosts: [host],
            provider: provider,
            identityProvisioner: provisioner
        )
        let workspace = model.primaryWorkspaceReference
        await model.loadHosts()

        await model.beginPairing(host: host, in: workspace)
        let cancelledOwner = try XCTUnwrap(model.primaryPairingState?.owner)
        XCTAssertEqual(model.primaryPairingState?.stage, .waitingForPIN)
        await model.cancelPairing(in: workspace)
        XCTAssertEqual(model.primaryPairingState?.stage, .cancelled)
        XCTAssertNil(model.primaryPairingState?.issue?.action)

        await model.beginPairing(host: host, in: workspace)
        let failedOwner = try XCTUnwrap(model.primaryPairingState?.owner)
        XCTAssertNotEqual(failedOwner, cancelledOwner)
        XCTAssertEqual(model.primaryPairingState?.stage, .failed)
        XCTAssertEqual(
            model.primaryPairingState?.issue?.action?.scope,
            .pairing(failedOwner)
        )

        let retry = Task { await model.retryPairing(in: workspace) }
        await provisioner.waitUntilRetryIsPending()
        let retryOwner = try XCTUnwrap(model.primaryPairingState?.owner)
        XCTAssertNotEqual(retryOwner, failedOwner)
        let duplicateRetryAccepted = await model.retryPairing(in: workspace)
        XCTAssertFalse(duplicateRetryAccepted)
        XCTAssertEqual(model.primaryPairingState?.owner, retryOwner)
        let replacement = try model.workspaceRegistry.replace(workspace)
        await provisioner.resumeRetry()
        let retryAccepted = await retry.value
        await waitForCancellation(
            retryOwner.attemptGeneration.rawValue,
            provider: provider
        )

        XCTAssertTrue(retryAccepted)
        XCTAssertNil(model.workspaceState(for: workspace))
        XCTAssertEqual(model.workspaceState(for: replacement)?.selectedHostID, host.id)
        XCTAssertEqual(model.workspaceState(for: replacement)?.pairing, PairingUIState())
        XCTAssertEqual(model.hosts.first?.pairingState, .unpaired)
        XCTAssertNil(model.hosts.first?.pinnedIdentity)
        let requestCount = await provider.requestCount()
        XCTAssertEqual(requestCount, 0)
        let cancellations = await provider.cancelledAttemptIDs()
        XCTAssertTrue(cancellations.contains(cancelledOwner.attemptGeneration.rawValue))
        XCTAssertFalse(cancellations.contains(failedOwner.attemptGeneration.rawValue))
        XCTAssertTrue(cancellations.contains(retryOwner.attemptGeneration.rawValue))
    }

    private func makeModel(
        hosts: [MoonlightHost],
        provider: PairingWorkspaceProvider,
        identityProvisioner: any ClientIdentityProvisioning
    ) -> AppModel {
        AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(hosts: hosts),
                serverInfoClient: PairingWorkspaceServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: PairingWorkspaceAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(
                launchClient: HTTPStreamLaunchClient()
            ),
            runtimeProviders: RuntimeProviderInventory(pairing: provider),
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientIdentityProvisioner: identityProvisioner,
            clientUniqueID: "pairing-workspace-test"
        )
    }

    private func makeHost(
        idSuffix: UInt8,
        name: String
    ) -> MoonlightHost {
        MoonlightHost(
            id: UUID(uuidString: String(
                format: "71000000-0000-0000-0000-%012d",
                idSuffix
            ))!,
            name: name,
            address: "pairing-\(idSuffix).local",
            pairingState: .unpaired,
            reachability: .online
        )
    }

    private func makeIdentity() -> ClientIdentityMaterial {
        ClientIdentityMaterial(
            id: UUID(uuidString: "72000000-0000-0000-0000-000000000001")!,
            certificateDER: Data([0x30, 0x01]),
            privateKeyDER: Data([0x02, 0x01]),
            createdAt: Date(timeIntervalSince1970: 100)
        )
    }

    private func waitForCancellation(
        _ attemptID: UUID,
        provider: PairingWorkspaceProvider,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<200 {
            if await provider.cancelledAttemptIDs().contains(attemptID) {
                return
            }
            await Task.yield()
        }
        XCTFail("Timed out waiting for pairing owner cancellation.", file: file, line: line)
    }

    private var rootViewURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/LuneXApp/RootView.swift")
    }
}

private enum PairingWorkspaceTestError: Error {
    case identityUnavailable
    case requestTimeout
}

private struct FixedPairingWorkspaceIdentityProvisioner: ClientIdentityProvisioning {
    let identity: ClientIdentityMaterial

    func loadOrCreateIdentity(createdAt: Date) async throws -> ClientIdentityMaterial {
        _ = createdAt
        return identity
    }
}

private actor FailingPairingWorkspaceIdentityProvisioner: ClientIdentityProvisioning {
    private var attempts = 0

    func loadOrCreateIdentity(createdAt: Date) async throws -> ClientIdentityMaterial {
        _ = createdAt
        attempts += 1
        throw PairingWorkspaceTestError.identityUnavailable
    }

    func attemptCount() -> Int { attempts }
}

private actor SuspendedPairingWorkspaceIdentityProvisioner: ClientIdentityProvisioning {
    private var continuation: CheckedContinuation<ClientIdentityMaterial, Error>?

    func loadOrCreateIdentity(createdAt: Date) async throws -> ClientIdentityMaterial {
        _ = createdAt
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }

    func waitUntilPending() async {
        while continuation == nil { await Task.yield() }
    }

    func resume(with identity: ClientIdentityMaterial) {
        continuation?.resume(returning: identity)
        continuation = nil
    }
}

private actor ApplicationPairingIdentityProvisioner: ClientIdentityProvisioning {
    private let identity: ClientIdentityMaterial
    private var attempts = 0
    private var retryContinuation: CheckedContinuation<ClientIdentityMaterial, Error>?

    init(identity: ClientIdentityMaterial) {
        self.identity = identity
    }

    func loadOrCreateIdentity(createdAt: Date) async throws -> ClientIdentityMaterial {
        _ = createdAt
        attempts += 1
        switch attempts {
        case 1:
            return identity
        case 2:
            throw PairingWorkspaceTestError.identityUnavailable
        default:
            return try await withCheckedThrowingContinuation {
                retryContinuation = $0
            }
        }
    }

    func waitUntilRetryIsPending() async {
        while retryContinuation == nil { await Task.yield() }
    }

    func resumeRetry() {
        retryContinuation?.resume(returning: identity)
        retryContinuation = nil
    }
}

private actor PairingWorkspaceProvider: PairingRuntimeProvider {
    private typealias Continuation =
        AsyncThrowingStream<PairingRuntimeEvent, Error>.Continuation

    private var requests: [PairingRuntimeRequest] = []
    private var continuations: [UUID: Continuation] = [:]
    private var cancellations: [UUID] = []

    func pair(
        _ request: PairingRuntimeRequest
    ) async -> AsyncThrowingStream<PairingRuntimeEvent, Error> {
        let (stream, continuation) =
            AsyncThrowingStream<PairingRuntimeEvent, Error>.makeStream()
        requests.append(request)
        continuations[request.attemptID] = continuation
        return stream
    }

    func cancelPairing(attemptID: UUID) async {
        cancellations.append(attemptID)
    }

    func requestCount() -> Int { requests.count }

    func cancelledAttemptIDs() -> [UUID] { cancellations }

    func waitForLatestRequest() async throws -> PairingRuntimeRequest {
        for _ in 0..<200 {
            if let request = requests.last { return request }
            await Task.yield()
        }
        throw PairingWorkspaceTestError.requestTimeout
    }

    func completeAuthenticated(_ request: PairingRuntimeRequest) {
        let continuation = continuations.removeValue(forKey: request.attemptID)
        continuation?.yield(.completed(authenticatedResult(for: request)))
        continuation?.finish()
    }

    private func authenticatedResult(
        for request: PairingRuntimeRequest
    ) -> PairingResult {
        let certificate = Data([0x30, 0x01, 0x02])
        let fingerprint = "pairing-workspace-verified"
        let pairedAt = Date(timeIntervalSince1970: 300)
        var pairedHost = request.host
        pairedHost.pairingState = .paired
        pairedHost.pinnedIdentity = PinnedHostIdentity(
            certificateSHA256: fingerprint,
            serverCertificateDER: certificate,
            pairedAt: pairedAt
        )
        return PairingResult(
            host: pairedHost,
            serverIdentity: PairingServerIdentity(
                certificateDER: certificate,
                certificateSHA256: fingerprint,
                serverMajorVersion: 7
            ),
            digestAlgorithm: .sha256,
            pairedAt: pairedAt
        )
    }
}

private struct PairingWorkspaceAppListClient: AppListClient {
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

private struct PairingWorkspaceServerInfoClient: ServerInfoClient {
    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        _ = endpoint
        return ServerInfo(
            name: "Pairing Workspace Host",
            uniqueID: "pairing-workspace-host",
            macAddress: nil,
            state: "ONLINE",
            supportsHDR: true,
            rawValues: [:]
        )
    }
}
