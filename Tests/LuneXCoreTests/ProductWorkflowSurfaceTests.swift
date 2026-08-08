import XCTest

final class ProductWorkflowSurfaceTests: XCTestCase {
    func testHostLibraryMapsLoadingFirstUseAvailableAndFailure() {
        let host = makeHost(pairingState: .paired)

        let loading = ProductHostLibrarySurface(
            library: ProductHostLibraryWorkspaceState(
                phase: .loading,
                isRefreshing: true
            ),
            hostCount: 0,
            selectedHost: nil
        )
        XCTAssertEqual(loading.content, .loading)
        XCTAssertFalse(loading.canAddHost)
        XCTAssertFalse(loading.canRefresh)

        let firstUse = ProductHostLibrarySurface(
            library: ProductHostLibraryWorkspaceState(phase: .firstUse),
            hostCount: 0,
            selectedHost: nil
        )
        XCTAssertEqual(firstUse.content, .firstUse)
        XCTAssertTrue(firstUse.canAddHost)
        XCTAssertTrue(firstUse.canRefresh)
        XCTAssertFalse(firstUse.canRemove)

        let available = ProductHostLibrarySurface(
            library: ProductHostLibraryWorkspaceState(phase: .available),
            hostCount: 1,
            selectedHost: host
        )
        XCTAssertEqual(available.content, .hosts)
        XCTAssertTrue(available.canRemove)
        XCTAssertTrue(available.canResetTrust)

        let issue = ProductIssue(
            code: .hostLibraryLoadFailed,
            actionScope: .workspace(workspace)
        )
        let failed = ProductHostLibrarySurface(
            library: ProductHostLibraryWorkspaceState(
                phase: .failed,
                refreshIssue: issue
            ),
            hostCount: 0,
            selectedHost: nil
        )
        XCTAssertEqual(failed.content, .failed)
        XCTAssertEqual(failed.refreshIssue, issue)
        XCTAssertTrue(failed.canAddHost)
        XCTAssertFalse(failed.canRefresh)
    }

    func testHostLibraryMapsDestructiveProgressFailureAndCompletion() {
        let host = makeHost(pairingState: .paired)
        let owner = ProductHostActionOwner(
            workspace: workspace,
            hostID: host.id,
            hostSelectionGeneration: ProductHostSelectionGeneration()
        )
        let confirmation = ProductHostDestructiveConfirmation(
            owner: owner,
            kind: .remove,
            requiresSessionStop: false
        )
        let issue = ProductIssue(
            code: .hostRemoveFailed,
            actionScope: .host(owner)
        )

        let performing = surface(
            host: host,
            destructive: .performing(confirmation)
        )
        XCTAssertEqual(performing.destructive, .performing(.remove))
        XCTAssertFalse(performing.canRemove)
        XCTAssertFalse(performing.canResetTrust)

        let failed = surface(
            host: host,
            destructive: .failed(confirmation, issue)
        )
        XCTAssertEqual(failed.destructive, .failed(issue))
        XCTAssertFalse(failed.canRemove)

        let completed = surface(
            host: host,
            destructive: .succeeded(kind: .resetTrust, hostID: host.id)
        )
        XCTAssertEqual(completed.destructive, .completed(.resetTrust))
        XCTAssertTrue(completed.canRemove)
    }

    func testPairingMapsEveryOwnedStageToOneSurface() {
        let host = makeHost(pairingState: .unpaired)
        let owner = pairingOwner(hostID: host.id)
        let expectations: [(PairingStage, Bool, ProductPairingSurfacePhase)] = [
            (.idle, true, .preparing),
            (.waitingForPIN, false, .waitingForPIN),
            (.exchangingSecrets, true, .exchangingSecrets),
            (.verifyingServer, true, .verifyingServer),
            (.pinningIdentity, true, .savingIdentity),
            (.paired, false, .completed),
            (.cancelled, false, .cancelled)
        ]

        for (stage, isRunning, expected) in expectations {
            let surface = ProductPairingSurface(
                selectedHost: host,
                pairing: PairingUIState(
                    owner: owner,
                    stage: stage,
                    pin: "1234",
                    isRunning: isRunning
                ),
                transportAvailable: true,
                isPINValid: true
            )
            XCTAssertEqual(surface.phase, expected, "Unexpected mapping for \(stage)")
        }

        let waiting = ProductPairingSurface(
            selectedHost: host,
            pairing: PairingUIState(
                owner: owner,
                stage: .waitingForPIN,
                pin: "1234"
            ),
            transportAvailable: true,
            isPINValid: true
        )
        XCTAssertTrue(waiting.canSubmitPIN)
        XCTAssertTrue(waiting.canCancel)
        XCTAssertFalse(waiting.canStart)
    }

    func testPairingTerminalAndUnavailableActionsFailClosed() {
        let host = makeHost(pairingState: .unpaired)
        let owner = pairingOwner(hostID: host.id)
        let retryIssue = ProductIssue(
            code: .pairingFailed,
            actionScope: .pairing(owner)
        )
        let failed = ProductPairingSurface(
            selectedHost: host,
            pairing: PairingUIState(
                owner: owner,
                stage: .failed,
                issue: retryIssue
            ),
            transportAvailable: true,
            isPINValid: false
        )
        XCTAssertEqual(failed.phase, .failed)
        XCTAssertTrue(failed.canRetry)

        let cancelledIssue = ProductIssue(
            code: .pairingCancelled,
            actionScope: .pairing(owner)
        )
        let cancelled = ProductPairingSurface(
            selectedHost: host,
            pairing: PairingUIState(
                owner: owner,
                stage: .cancelled,
                issue: cancelledIssue
            ),
            transportAvailable: true,
            isPINValid: false
        )
        XCTAssertEqual(cancelled.phase, .cancelled)
        XCTAssertTrue(cancelled.canStart)
        XCTAssertFalse(cancelled.canRetry)

        let unavailable = ProductPairingSurface(
            selectedHost: host,
            pairing: PairingUIState(),
            transportAvailable: false,
            isPINValid: false
        )
        XCTAssertEqual(unavailable.phase, .unavailable)
        XCTAssertFalse(unavailable.canStart)

        let stale = ProductPairingSurface(
            selectedHost: host,
            pairing: PairingUIState(
                owner: pairingOwner(hostID: UUID()),
                stage: .failed,
                issue: retryIssue
            ),
            transportAvailable: true,
            isPINValid: false
        )
        XCTAssertEqual(stale.phase, .ready)
        XCTAssertFalse(stale.canRetry)
    }

    func testCatalogDistinguishesLoadingEmptyCachedCurrentAndFailure() {
        let host = makeHost(pairingState: .paired)
        let owner = catalogOwner(hostID: host.id)
        let cases: [(ProductAppCatalogPhase, Int, ProductAppCatalogContentSurface)] = [
            (.idle, 0, .idle),
            (.loading(hasCachedApps: false), 0, .loading),
            (.loading(hasCachedApps: true), 2, .loadingCached),
            (.empty(source: .cached), 0, .empty(.cached)),
            (.empty(source: .current), 0, .empty(.current)),
            (.cached, 2, .cached),
            (.current, 2, .current),
            (.failed(hasCachedApps: false), 0, .failed(hasCachedApps: false)),
            (.failed(hasCachedApps: true), 2, .failed(hasCachedApps: true))
        ]

        for (phase, appCount, expected) in cases {
            let surface = ProductAppCatalogSurface(
                catalog: ProductAppCatalogWorkspaceState(
                    owner: owner,
                    phase: phase
                ),
                selectedHost: host,
                appCount: appCount
            )
            XCTAssertEqual(surface.content, expected, "Unexpected mapping for \(phase)")
        }
    }

    func testCatalogRetryRequiresCurrentScopedActionAndPreservesCachedSurface() {
        let host = makeHost(pairingState: .paired)
        let owner = catalogOwner(hostID: host.id)
        let issue = ProductIssue(
            code: .catalogRefreshFailed,
            actionScope: .catalog(owner)
        )
        let surface = ProductAppCatalogSurface(
            catalog: ProductAppCatalogWorkspaceState(
                owner: owner,
                phase: .failed(hasCachedApps: true),
                issue: issue
            ),
            selectedHost: host,
            appCount: 2
        )
        XCTAssertEqual(surface.content, .failed(hasCachedApps: true))
        XCTAssertTrue(surface.showsApps)
        XCTAssertTrue(surface.canRetry)
        XCTAssertFalse(surface.canRefresh)

        let staleIssue = ProductAppCatalogSurface(
            catalog: ProductAppCatalogWorkspaceState(
                owner: owner,
                phase: .current,
                issue: issue
            ),
            selectedHost: host,
            appCount: 2
        )
        XCTAssertEqual(staleIssue.content, .current)
        XCTAssertFalse(staleIssue.canRetry)
        XCTAssertTrue(staleIssue.canRefresh)

        var unpairedHost = host
        unpairedHost.pairingState = .unpaired
        let requiresPairing = ProductAppCatalogSurface(
            catalog: ProductAppCatalogWorkspaceState(
                owner: owner,
                phase: .cached
            ),
            selectedHost: unpairedHost,
            appCount: 2
        )
        XCTAssertEqual(
            requiresPairing.content,
            .requiresPairing(hasCachedApps: true)
        )
        XCTAssertTrue(requiresPairing.showsApps)
        XCTAssertFalse(requiresPairing.canRefresh)
        XCTAssertFalse(requiresPairing.canRetry)
    }

    func testRootViewConsumesSurfaceContractsAndNativeAppButtons() throws {
        let source = try String(contentsOf: rootViewURL, encoding: .utf8)

        XCTAssertTrue(source.contains("ProductHostLibrarySurface("))
        XCTAssertTrue(source.contains("ProductPairingSurface("))
        XCTAssertTrue(source.contains("ProductAppCatalogSurface("))
        XCTAssertTrue(source.contains("retryHostLibraryLoad(in: workspace)"))
        XCTAssertTrue(source.contains("retryAppCatalog(in: workspace)"))
        XCTAssertTrue(source.contains("Pairing complete"))
        XCTAssertTrue(source.contains("Pairing cancelled"))
        XCTAssertTrue(source.contains("Button {\n                    appModel.select(app: app, in: workspace)"))
        XCTAssertFalse(source.contains(".onTapGesture"))
    }

    private func surface(
        host: MoonlightHost,
        destructive: ProductHostDestructiveState
    ) -> ProductHostLibrarySurface {
        ProductHostLibrarySurface(
            library: ProductHostLibraryWorkspaceState(
                phase: .available,
                destructiveAction: destructive
            ),
            hostCount: 1,
            selectedHost: host
        )
    }

    private func makeHost(pairingState: PairingState) -> MoonlightHost {
        MoonlightHost(
            id: UUID(uuidString: "91000000-0000-0000-0000-000000000001")!,
            name: "Test Host",
            address: "test.local",
            pairingState: pairingState,
            reachability: .online
        )
    }

    private func pairingOwner(hostID: MoonlightHost.ID) -> ProductPairingOwner {
        ProductPairingOwner(
            workspace: workspace,
            hostID: hostID,
            hostSelectionGeneration: ProductHostSelectionGeneration(),
            attemptGeneration: ProductPairingAttemptGeneration()
        )
    }

    private func catalogOwner(hostID: MoonlightHost.ID) -> ProductCatalogOwner {
        ProductCatalogOwner(
            workspace: workspace,
            hostID: hostID,
            hostSelectionGeneration: ProductHostSelectionGeneration()
        )
    }

    private var workspace: ProductWorkspaceReference {
        ProductWorkspaceReference(
            id: ProductWorkspaceID(
                rawValue: UUID(
                    uuidString: "92000000-0000-0000-0000-000000000001"
                )!
            ),
            generation: .initial
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
