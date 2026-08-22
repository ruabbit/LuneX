import XCTest

final class ProductWorkflowSurfaceTests: XCTestCase {
    func testStreamWorkspaceLayoutUsesCompactForNarrowOrExpandedText() {
        XCTAssertEqual(
            ProductStreamWorkspaceLayout(
                horizontalSizeClassIsCompact: false,
                usesAccessibilityTextSize: false,
                availableWidth: 1_280
            ),
            .wide
        )
        XCTAssertEqual(
            ProductStreamWorkspaceLayout(
                horizontalSizeClassIsCompact: true,
                usesAccessibilityTextSize: false,
                availableWidth: 1_280
            ),
            .compact
        )
        XCTAssertEqual(
            ProductStreamWorkspaceLayout(
                horizontalSizeClassIsCompact: false,
                usesAccessibilityTextSize: true,
                availableWidth: 1_280
            ),
            .compact
        )
        XCTAssertEqual(
            ProductStreamWorkspaceLayout(
                horizontalSizeClassIsCompact: false,
                usesAccessibilityTextSize: false,
                availableWidth: ProductStreamWorkspaceLayout.wideMinimumWidth - 1
            ),
            .compact
        )
        XCTAssertEqual(
            ProductStreamWorkspaceLayout(
                horizontalSizeClassIsCompact: false,
                usesAccessibilityTextSize: false,
                availableWidth: ProductStreamWorkspaceLayout.wideMinimumWidth
            ),
            .wide
        )
        XCTAssertEqual(
            ProductStreamWorkspaceLayout(
                horizontalSizeClassIsCompact: false,
                usesAccessibilityTextSize: false,
                availableWidth: .nan
            ),
            .compact
        )
    }

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

    func testSessionCommandsRequireCurrentWorkspaceProvidersAndSelection() {
        let ready = sessionCommandState(phase: .idle)
        XCTAssertEqual(ready.launch, .available)
        XCTAssertEqual(ready.reconnect, .unavailable(.noActiveSession))
        XCTAssertEqual(ready.resume, .unavailable(.noActiveSession))
        XCTAssertEqual(ready.stop, .unavailable(.noActiveSession))

        let noProviders = sessionCommandState(
            phase: .idle,
            canLaunchTransport: false
        )
        XCTAssertEqual(
            noProviders.launch,
            .unavailable(.providersUnavailable)
        )

        let noSelection = sessionCommandState(
            phase: .idle,
            hasLaunchSelection: false
        )
        XCTAssertEqual(noSelection.launch, .unavailable(.selectionRequired))

        let staleWorkspace = sessionCommandState(
            phase: .idle,
            workspaceIsCurrent: false
        )
        XCTAssertEqual(
            staleWorkspace,
            ProductSessionCommandState(ProductSessionCommandInput(
                workspaceIsCurrent: false,
                ownership: .none,
                phase: .idle,
                hasLaunchSelection: false,
                canLaunchTransport: false,
                canControlSession: false
            ))
        )
        XCTAssertEqual(
            staleWorkspace.launch,
            .unavailable(.staleWorkspace)
        )
    }

    func testOwnedSessionCommandsFollowEveryActivePhase() {
        let launching = sessionCommandState(
            phase: .launching,
            ownership: .current
        )
        XCTAssertEqual(launching.launch, .inProgress)
        XCTAssertEqual(launching.reconnect, .unavailable(.sessionActive))
        XCTAssertEqual(launching.resume, .unavailable(.sessionActive))
        XCTAssertEqual(launching.stop, .available)

        let waiting = sessionCommandState(
            phase: .waitingForTransport,
            ownership: .current
        )
        XCTAssertEqual(waiting.launch, .inProgress)
        XCTAssertEqual(waiting.stop, .available)

        let streaming = sessionCommandState(
            phase: .streaming,
            ownership: .current
        )
        XCTAssertEqual(streaming.launch, .unavailable(.sessionActive))
        XCTAssertEqual(streaming.reconnect, .unavailable(.sessionActive))
        XCTAssertEqual(streaming.resume, .unavailable(.sessionActive))
        XCTAssertEqual(streaming.stop, .available)

        let reconnecting = sessionCommandState(
            phase: .reconnecting(attempt: 2),
            ownership: .current
        )
        XCTAssertEqual(reconnecting.reconnect, .inProgress)
        XCTAssertEqual(reconnecting.resume, .inProgress)
        XCTAssertEqual(reconnecting.stop, .available)

        let stopping = sessionCommandState(
            phase: .stopping,
            ownership: .current
        )
        XCTAssertEqual(stopping.launch, .unavailable(.commandInProgress))
        XCTAssertEqual(stopping.reconnect, .unavailable(.commandInProgress))
        XCTAssertEqual(stopping.resume, .unavailable(.commandInProgress))
        XCTAssertEqual(stopping.stop, .inProgress)
    }

    func testTerminalSessionCommandsStartOnlyANewCheckedConnection() {
        let terminalPhases: [ProductSessionActualPhase] = [
            .remoteTerminated,
            .reconnectExhausted,
            .failed
        ]
        for phase in terminalPhases {
            let state = sessionCommandState(phase: phase)
            XCTAssertEqual(state.launch, .available, "Unexpected launch for \(phase)")
            XCTAssertEqual(
                state.reconnect,
                .available,
                "Unexpected reconnect for \(phase)"
            )
            XCTAssertEqual(state.resume, .unavailable(.terminalSession))
            XCTAssertEqual(state.stop, .unavailable(.noActiveSession))
        }
    }

    func testNonOwnerStaleOwnerAndInconsistentActualStateFailClosed() {
        let nonOwner = sessionCommandState(
            phase: .streaming,
            ownership: .otherWorkspace
        )
        XCTAssertEqual(
            nonOwner.stop,
            .unavailable(.ownedByAnotherWorkspace)
        )

        let staleOwner = sessionCommandState(
            phase: .streaming,
            ownership: .staleReservation
        )
        XCTAssertEqual(staleOwner.stop, .unavailable(.staleSessionOwner))

        let inconsistent = sessionCommandState(phase: .streaming)
        XCTAssertEqual(
            inconsistent.launch,
            .unavailable(.inconsistentActualState)
        )

        let unownedStopping = sessionCommandState(phase: .stopping)
        XCTAssertEqual(unownedStopping.stop, .inProgress)
        XCTAssertEqual(
            unownedStopping.launch,
            .unavailable(.commandInProgress)
        )

        let noControl = sessionCommandState(
            phase: .streaming,
            ownership: .current,
            canControlSession: false
        )
        XCTAssertEqual(noControl.stop, .unavailable(.providersUnavailable))
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
        XCTAssertTrue(source.contains("streamProductIssue(in: workspace)"))
        XCTAssertTrue(source.contains("performProductAction(action)"))
        XCTAssertTrue(source.contains("canPerformProductAction(action)"))
        XCTAssertFalse(source.contains("streamLaunchUI.errorMessage"))
        XCTAssertFalse(source.contains("streamLaunchUI.actionMessage"))
        XCTAssertTrue(source.contains("Button {\n                    appModel.select(app: app, in: workspace)"))
        XCTAssertFalse(source.contains(".onTapGesture"))

        let rootEnd = try XCTUnwrap(
            source.range(of: "private struct SidebarNavigationList: View")
        )
        let root = String(source[..<rootEnd.lowerBound])
        XCTAssertTrue(root.contains("let workspace: ProductWorkspaceReference"))
        XCTAssertFalse(root.contains("appModel.primaryWorkspaceReference"))

        let workspaceStart = try XCTUnwrap(
            source.range(of: "private struct StreamWorkspaceView: View")
        )
        let workspaceEnd = try XCTUnwrap(
            source.range(
                of: "private struct StreamStatusOverlay: View",
                range: workspaceStart.upperBound..<source.endIndex
            )
        )
        let streamWorkspace = String(
            source[workspaceStart.lowerBound..<workspaceEnd.lowerBound]
        )
        let streamContracts = [
            "ProductStreamWorkspaceLayout(",
            "GeometryReader",
            "availableWidth: geometry.size.width",
            "overlayMaximumHeight(",
            "layout == .compact ? 0.48 : 0.82",
            ".safeAreaPadding(16)",
            "alignment: streamOverlayAlignment(for: layout)",
            "streamOverlayVisibility(in: workspace) == .hidden"
        ]
        for contract in streamContracts {
            XCTAssertTrue(
                streamWorkspace.contains(contract),
                "Missing stream workspace contract: \(contract)"
            )
        }
        XCTAssertFalse(streamWorkspace.contains(".onHover"))

        let overlayEnd = try XCTUnwrap(
            source.range(
                of: "private enum TVStreamControlFocusTarget: Hashable",
                range: workspaceEnd.upperBound..<source.endIndex
            )
        )
        let streamOverlay = String(
            source[workspaceEnd.lowerBound..<overlayEnd.lowerBound]
        )
        XCTAssertTrue(streamOverlay.contains("case .compact:"))
        XCTAssertTrue(streamOverlay.contains("ScrollView"))
        XCTAssertTrue(streamOverlay.contains(".scrollBounceBehavior(.basedOnSize)"))
        XCTAssertTrue(streamOverlay.contains("compactCommandHeader"))
        XCTAssertTrue(streamOverlay.contains("wideCommandHeader"))
        XCTAssertTrue(streamOverlay.contains(
            "TVStreamControls(workspace: workspace, workspaceLayout: layout)"
        ))
        XCTAssertTrue(streamOverlay.contains(
            "VisionStreamControls(workspace: workspace, workspaceLayout: layout)"
        ))
        XCTAssertFalse(streamOverlay.contains(".onHover"))
    }

    func testAppSceneUsesRestorableWorkspaceIdentityAndSingleFallback() throws {
        let appSource = try String(contentsOf: appSourceURL, encoding: .utf8)
        let infoSource = try String(contentsOf: iOSInfoURL, encoding: .utf8)

        XCTAssertTrue(appSource.contains("for: ProductWorkspaceSceneIdentity.self"))
        XCTAssertTrue(appSource.contains("@Environment(\\.supportsMultipleWindows)"))
        XCTAssertTrue(appSource.contains("RootView(workspace: attachment.workspace)"))
        XCTAssertTrue(appSource.contains(
            "RootView(workspace: appModel.primaryWorkspaceReference)"
        ))
        XCTAssertTrue(appSource.contains(".onAppear(perform: connect)"))
        XCTAssertTrue(appSource.contains(".onDisappear(perform: disconnect)"))
        XCTAssertTrue(infoSource.contains("UIApplicationSceneManifest"))
        XCTAssertTrue(infoSource.contains("UIApplicationSupportsMultipleScenes"))
        XCTAssertTrue(infoSource.contains("<true/>"))
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

    private func sessionCommandState(
        phase: ProductSessionActualPhase,
        ownership: ProductSessionWorkspaceOwnership = .none,
        workspaceIsCurrent: Bool = true,
        hasLaunchSelection: Bool = true,
        canLaunchTransport: Bool = true,
        canControlSession: Bool = true
    ) -> ProductSessionCommandState {
        ProductSessionCommandState(ProductSessionCommandInput(
            workspaceIsCurrent: workspaceIsCurrent,
            ownership: ownership,
            phase: phase,
            hasLaunchSelection: hasLaunchSelection,
            canLaunchTransport: canLaunchTransport,
            canControlSession: canControlSession
        ))
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

    private var appSourceURL: URL {
        rootViewURL.deletingLastPathComponent()
            .appendingPathComponent("LuneXApp.swift")
    }

    private var iOSInfoURL: URL {
        rootViewURL.deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Configuration/Info/LuneX-iOS.plist")
    }
}
