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

    func testLibraryDashboardLayoutUsesActualWidthAndAccessibilityText() {
        XCTAssertEqual(
            ProductLibraryDashboardLayout(
                horizontalSizeClassIsCompact: false,
                usesAccessibilityTextSize: false,
                availableWidth: 1_280
            ),
            .wide
        )
        XCTAssertEqual(
            ProductLibraryDashboardLayout(
                horizontalSizeClassIsCompact: true,
                usesAccessibilityTextSize: false,
                availableWidth: 1_280
            ),
            .compact
        )
        XCTAssertEqual(
            ProductLibraryDashboardLayout(
                horizontalSizeClassIsCompact: false,
                usesAccessibilityTextSize: true,
                availableWidth: 1_280
            ),
            .compact
        )
        XCTAssertEqual(
            ProductLibraryDashboardLayout(
                horizontalSizeClassIsCompact: false,
                usesAccessibilityTextSize: false,
                availableWidth: ProductLibraryDashboardLayout.wideMinimumWidth - 1
            ),
            .compact
        )
        XCTAssertEqual(
            ProductLibraryDashboardLayout(
                horizontalSizeClassIsCompact: false,
                usesAccessibilityTextSize: false,
                availableWidth: ProductLibraryDashboardLayout.wideMinimumWidth
            ),
            .wide
        )
        for invalidWidth in [CGFloat.nan, .infinity, -.infinity] {
            XCTAssertEqual(
                ProductLibraryDashboardLayout(
                    horizontalSizeClassIsCompact: false,
                    usesAccessibilityTextSize: false,
                    availableWidth: invalidWidth
                ),
                .compact
            )
        }
    }

    func testInteractionAccessibilityPolicyUsesNativeTouchAndMotionBounds() {
        XCTAssertEqual(
            ProductInteractionAccessibilityPolicy.minimumTouchTargetDimension,
            44
        )
        XCTAssertEqual(
            ProductInteractionAccessibilityPolicy.transitionStyle(
                reduceMotionEnabled: false
            ),
            .opacity
        )
        XCTAssertEqual(
            ProductInteractionAccessibilityPolicy.transitionStyle(
                reduceMotionEnabled: true
            ),
            .immediate
        )
    }

    func testTVStreamFocusPolicyOrdersOverlayAndRestoresStreamSurface() {
        let localControls = tvPresentation(focus: .localControls)
        let handoffPending = tvPresentation(focus: .handoffPending)
        let streamSurface = tvPresentation(focus: .streamSurface)
        let unavailable = tvPresentation(focus: .unavailable)

        XCTAssertEqual(
            ProductTVStreamFocusPolicy.target(
                overlayVisibility: .visible,
                presentation: localControls
            ),
            .hideControls
        )
        XCTAssertEqual(
            ProductTVStreamFocusPolicy.target(
                overlayVisibility: .hidden,
                presentation: handoffPending
            ),
            .streamSurface
        )
        XCTAssertEqual(
            ProductTVStreamFocusPolicy.target(
                overlayVisibility: .hidden,
                presentation: streamSurface
            ),
            .streamSurface
        )
        XCTAssertNil(ProductTVStreamFocusPolicy.target(
            overlayVisibility: .visible,
            presentation: streamSurface
        ))
        XCTAssertNil(ProductTVStreamFocusPolicy.target(
            overlayVisibility: .hidden,
            presentation: unavailable
        ))
        XCTAssertEqual(
            ProductTVStreamFocusPolicy.overlayInitialTarget,
            .hideControls
        )
        XCTAssertEqual(
            ProductTVStreamFocusPolicy.restorationTarget,
            .streamSurface
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

    func testKeyboardFocusPolicyCoversEveryPairingSurfacePhase() {
        let host = makeHost(pairingState: .unpaired)
        let owner = pairingOwner(hostID: host.id)
        let retryIssue = ProductIssue(
            code: .pairingFailed,
            actionScope: .pairing(owner)
        )
        let cases: [(ProductPairingSurface, ProductKeyboardFocusTarget)] = [
            (ProductPairingSurface(
                selectedHost: nil,
                pairing: PairingUIState(),
                transportAvailable: true,
                isPINValid: false
            ), .pairingResult),
            (ProductPairingSurface(
                selectedHost: host,
                pairing: PairingUIState(),
                transportAvailable: true,
                isPINValid: false
            ), .pairingStart),
            (ProductPairingSurface(
                selectedHost: host,
                pairing: PairingUIState(
                    owner: owner,
                    stage: .waitingForPIN
                ),
                transportAvailable: true,
                isPINValid: true
            ), .pairingPIN),
            (ProductPairingSurface(
                selectedHost: host,
                pairing: PairingUIState(
                    owner: owner,
                    stage: .idle,
                    isRunning: true
                ),
                transportAvailable: true,
                isPINValid: false
            ), .pairingProgress),
            (ProductPairingSurface(
                selectedHost: host,
                pairing: PairingUIState(
                    owner: owner,
                    stage: .exchangingSecrets,
                    isRunning: true
                ),
                transportAvailable: true,
                isPINValid: false
            ), .pairingProgress),
            (ProductPairingSurface(
                selectedHost: host,
                pairing: PairingUIState(
                    owner: owner,
                    stage: .verifyingServer,
                    isRunning: true
                ),
                transportAvailable: true,
                isPINValid: false
            ), .pairingProgress),
            (ProductPairingSurface(
                selectedHost: host,
                pairing: PairingUIState(
                    owner: owner,
                    stage: .pinningIdentity,
                    isRunning: true
                ),
                transportAvailable: true,
                isPINValid: false
            ), .pairingProgress),
            (ProductPairingSurface(
                selectedHost: host,
                pairing: PairingUIState(
                    owner: owner,
                    stage: .failed,
                    issue: retryIssue
                ),
                transportAvailable: true,
                isPINValid: false
            ), .pairingRetry),
            (ProductPairingSurface(
                selectedHost: host,
                pairing: PairingUIState(
                    owner: owner,
                    stage: .failed
                ),
                transportAvailable: true,
                isPINValid: false
            ), .pairingResult),
            (ProductPairingSurface(
                selectedHost: host,
                pairing: PairingUIState(
                    owner: owner,
                    stage: .cancelled
                ),
                transportAvailable: true,
                isPINValid: false
            ), .pairingStart),
            (ProductPairingSurface(
                selectedHost: host,
                pairing: PairingUIState(),
                transportAvailable: false,
                isPINValid: false
            ), .pairingResult),
            (ProductPairingSurface(
                selectedHost: makeHost(pairingState: .paired),
                pairing: PairingUIState(),
                transportAvailable: true,
                isPINValid: false
            ), .pairingResult)
        ]

        XCTAssertEqual(
            ProductKeyboardFocusPolicy.addHostInitialTarget,
            .manualHostAddress
        )
        XCTAssertEqual(
            ProductKeyboardFocusPolicy.streamOverlayInitialTarget,
            .streamHideControls
        )
        for (surface, expectedTarget) in cases {
            XCTAssertEqual(
                ProductKeyboardFocusPolicy.pairingTarget(for: surface),
                expectedTarget,
                "Unexpected focus for \(surface.phase)"
            )
        }
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

    func testHostPairingAndCatalogSemanticsExposeCompleteLocalizedActions() throws {
        let host = makeHost(pairingState: .paired)
        let hostSurface = ProductHostLibrarySurface(
            library: ProductHostLibraryWorkspaceState(phase: .available),
            hostCount: 1,
            selectedHost: host
        )
        let hostSemantics = ProductHostSemanticSurface(
            surface: hostSurface,
            hostCount: 1
        )
        XCTAssertEqual(
            Set(hostSemantics.items.map(\.id)),
            Set(ProductHostSemanticID.allCases)
        )
        XCTAssertTrue(localized(try semantic(.libraryStatus, in: hostSemantics.items).value).contains("1"))
        XCTAssertTrue(try semantic(.removeHost, in: hostSemantics.items).isDestructive)
        XCTAssertTrue(try semantic(.resetTrust, in: hostSemantics.items).isDestructive)
        XCTAssertFalse(try semantic(.destructiveStatus, in: hostSemantics.items).isDestructive)
        XCTAssertEqual(
            try semantic(.refreshHosts, in: hostSemantics.items).eligibility,
            .enabled
        )
        let hostItem = ProductHostSemanticSurface.hostItem(host, isSelected: true)
        XCTAssertEqual(hostItem.role, .selectableItem)
        XCTAssertTrue(localized(hostItem.value).contains("Selected"))
        XCTAssertFalse(localized(hostItem.label).contains(host.address))

        let pairingOwner = pairingOwner(hostID: host.id)
        let waitingPairing = ProductPairingSurface(
            selectedHost: MoonlightHost(
                id: host.id,
                name: host.name,
                address: host.address,
                pairingState: .unpaired,
                reachability: .online
            ),
            pairing: PairingUIState(
                owner: pairingOwner,
                stage: .waitingForPIN,
                pin: "1234"
            ),
            transportAvailable: true,
            isPINValid: true
        )
        let pairingSemantics = ProductPairingSemanticSurface(surface: waitingPairing)
        XCTAssertEqual(
            Set(pairingSemantics.items.map(\.id)),
            Set(ProductPairingSemanticID.allCases)
        )
        XCTAssertEqual(
            try semantic(.status, in: pairingSemantics.items).eligibility,
            .inProgress
        )
        XCTAssertEqual(
            try semantic(.submitPIN, in: pairingSemantics.items).eligibility,
            .enabled
        )
        XCTAssertFalse(
            localized(try semantic(.pin, in: pairingSemantics.items).value)
                .contains("1234")
        )

        let catalogSurface = ProductAppCatalogSurface(
            catalog: ProductAppCatalogWorkspaceState(
                owner: catalogOwner(hostID: host.id),
                phase: .current
            ),
            selectedHost: host,
            appCount: 3
        )
        let catalogSemantics = ProductCatalogSemanticSurface(
            surface: catalogSurface,
            appCount: 3
        )
        XCTAssertEqual(
            Set(catalogSemantics.items.map(\.id)),
            Set(ProductCatalogSemanticID.allCases)
        )
        XCTAssertTrue(localized(try semantic(.status, in: catalogSemantics.items).value).contains("3"))
        XCTAssertEqual(
            try semantic(.refresh, in: catalogSemantics.items).eligibility,
            .enabled
        )
        let appItem = ProductCatalogSemanticSurface.appItem(
            name: "Desktop",
            isSelected: false,
            isEnabled: true
        )
        XCTAssertEqual(appItem.role, .selectableItem)
        XCTAssertTrue(localized(appItem.label).contains("Desktop"))
    }

    func testEveryPairingAndCatalogStateHasNonemptyLocalizedSemantics() throws {
        let host = makeHost(pairingState: .unpaired)
        let owner = pairingOwner(hostID: host.id)
        let pairingStates: [ProductPairingSurface] = [
            ProductPairingSurface(
                selectedHost: nil,
                pairing: PairingUIState(),
                transportAvailable: true,
                isPINValid: false
            ),
            ProductPairingSurface(
                selectedHost: host,
                pairing: PairingUIState(),
                transportAvailable: true,
                isPINValid: false
            ),
            ProductPairingSurface(
                selectedHost: host,
                pairing: PairingUIState(),
                transportAvailable: false,
                isPINValid: false
            )
        ] + [
            (PairingStage.idle, true),
            (.waitingForPIN, false),
            (.exchangingSecrets, true),
            (.verifyingServer, true),
            (.pinningIdentity, true),
            (.paired, false),
            (.cancelled, false),
            (.failed, false)
        ].map { stage, running in
            ProductPairingSurface(
                selectedHost: host,
                pairing: PairingUIState(
                    owner: owner,
                    stage: stage,
                    isRunning: running,
                    issue: stage == .failed
                        ? ProductIssue(code: .pairingFailed, actionScope: .pairing(owner))
                        : nil
                ),
                transportAvailable: true,
                isPINValid: false
            )
        }
        for surface in pairingStates {
            let status = try semantic(
                .status,
                in: ProductPairingSemanticSurface(surface: surface).items
            )
            XCTAssertFalse(localized(status.label).isEmpty)
            XCTAssertFalse(localized(status.value).isEmpty)
            XCTAssertEqual(status.role, .status)
        }

        let catalogOwner = catalogOwner(hostID: host.id)
        var pairedHost = host
        pairedHost.pairingState = .paired
        let catalogCases: [(ProductAppCatalogPhase, Int)] = [
            (.unavailable, 0),
            (.idle, 0),
            (.loading(hasCachedApps: false), 0),
            (.loading(hasCachedApps: true), 2),
            (.empty(source: .cached), 0),
            (.empty(source: .current), 0),
            (.cached, 2),
            (.current, 2),
            (.failed(hasCachedApps: false), 0),
            (.failed(hasCachedApps: true), 2)
        ]
        for (phase, count) in catalogCases {
            let surface = ProductAppCatalogSurface(
                catalog: ProductAppCatalogWorkspaceState(
                    owner: catalogOwner,
                    phase: phase,
                    issue: phase == .failed(hasCachedApps: count > 0)
                        ? ProductIssue(
                            code: .catalogRefreshFailed,
                            actionScope: .catalog(catalogOwner)
                        )
                        : nil
                ),
                selectedHost: pairedHost,
                appCount: count
            )
            let status = try semantic(
                .status,
                in: ProductCatalogSemanticSurface(
                    surface: surface,
                    appCount: count
                ).items
            )
            XCTAssertFalse(localized(status.value).isEmpty)
        }
    }

    func testStreamSemanticsMapEveryPhaseReasonAndDestructiveStop() throws {
        let phaseStates: [ProductSessionCommandState] = [
            sessionCommandState(phase: .idle),
            sessionCommandState(phase: .launching, ownership: .current),
            sessionCommandState(phase: .waitingForTransport, ownership: .current),
            sessionCommandState(phase: .streaming, ownership: .current),
            sessionCommandState(phase: .reconnecting(attempt: 2), ownership: .current),
            sessionCommandState(phase: .stopping, ownership: .current),
            sessionCommandState(phase: .remoteTerminated),
            sessionCommandState(phase: .reconnectExhausted),
            sessionCommandState(phase: .failed)
        ]
        for commands in phaseStates {
            let semantics = ProductStreamSemanticSurface(
                commands: commands,
                controlsVisible: true
            )
            XCTAssertEqual(
                Set(semantics.items.map(\.id)),
                Set(ProductStreamSemanticID.allCases)
            )
            let status = try semantic(.status, in: semantics.items)
            XCTAssertFalse(localized(status.value).isEmpty)
            XCTAssertEqual(status.role, .status)
            let stop = try semantic(.stop, in: semantics.items)
            XCTAssertTrue(stop.isDestructive)
            XCTAssertEqual(stop.role, .button)
        }

        let reasonStates = [
            sessionCommandState(phase: .idle, workspaceIsCurrent: false),
            sessionCommandState(phase: .idle, canLaunchTransport: false),
            sessionCommandState(phase: .idle, hasLaunchSelection: false),
            sessionCommandState(phase: .streaming, ownership: .otherWorkspace),
            sessionCommandState(phase: .streaming, ownership: .staleReservation),
            sessionCommandState(phase: .idle),
            sessionCommandState(phase: .streaming, ownership: .current),
            sessionCommandState(phase: .stopping, ownership: .current),
            sessionCommandState(phase: .remoteTerminated),
            sessionCommandState(phase: .streaming)
        ]
        let unavailableValues = try reasonStates.map { commands -> String in
            let semantics = ProductStreamSemanticSurface(
                commands: commands,
                controlsVisible: false
            )
            let descriptor: ProductSemanticDescriptor
            if commands.launch == .available {
                descriptor = try semantic(.stop, in: semantics.items)
            } else if commands.launch == .inProgress {
                descriptor = try semantic(.reconnect, in: semantics.items)
            } else {
                descriptor = try semantic(.launch, in: semantics.items)
            }
            return localized(descriptor.value)
        }
        XCTAssertEqual(unavailableValues.count, 10)
        XCTAssertTrue(unavailableValues.allSatisfy { !$0.isEmpty })

        let nonOwner = ProductStreamSemanticSurface(
            commands: sessionCommandState(
                phase: .streaming,
                ownership: .otherWorkspace
            ),
            controlsVisible: false
        )
        guard case .disabled = try semantic(.showControls, in: nonOwner.items).eligibility,
              case .disabled = try semantic(.hideControls, in: nonOwner.items).eligibility else {
            return XCTFail("Expected non-owner controls to expose disabled eligibility")
        }
        XCTAssertFalse(try semantic(.status, in: nonOwner.items).isDestructive)
    }

    func testSettingsSemanticsCoverEveryValueRoleAndEligibility() throws {
        var settings = AppSettings.defaults
        settings.audio.spatialAudioEnabled = false
        settings.audio.headTrackingEnabled = true
        let surface = ProductSettingsSemanticSurface(
            settings: settings,
            saveInProgress: true
        )
        XCTAssertEqual(
            Set(surface.items.map(\.id)),
            Set(ProductSettingsSemanticID.allCases)
        )
        XCTAssertEqual(surface.items.count, ProductSettingsSemanticID.allCases.count)
        XCTAssertEqual(try semantic(.width, in: surface.items).role, .adjustable)
        XCTAssertEqual(try semantic(.scaleMode, in: surface.items).role, .picker)
        XCTAssertEqual(try semantic(.hdr, in: surface.items).role, .toggle)
        let systemShortcuts = try semantic(.systemShortcuts, in: surface.items)
        XCTAssertEqual(systemShortcuts.role, .status)
        XCTAssertEqual(localized(systemShortcuts.value), "Always local")
        guard case .disabled = systemShortcuts.eligibility else {
            return XCTFail("Expected system shortcuts to remain local")
        }
        XCTAssertEqual(try semantic(.save, in: surface.items).eligibility, .inProgress)
        guard case .disabled = try semantic(.headTracking, in: surface.items).eligibility else {
            return XCTFail("Expected head tracking to expose disabled eligibility")
        }
        for item in surface.items {
            XCTAssertFalse(localized(item.descriptor.label).isEmpty)
            XCTAssertFalse(localized(item.descriptor.value).isEmpty)
            XCTAssertFalse(localized(item.descriptor.hint).isEmpty)
            XCTAssertFalse(item.descriptor.isDestructive)
        }
    }

    func testDiagnosticsSemanticsDistinguishEmptySupportedAndSeverityStates() throws {
        let empty = ProductDiagnosticsSemanticSurface(
            eventCount: 0,
            exportSupported: true
        )
        XCTAssertEqual(
            Set(empty.items.map(\.id)),
            Set(ProductDiagnosticsSemanticID.allCases)
        )
        guard case .disabled = try semantic(.export, in: empty.items).eligibility else {
            return XCTFail("Expected empty diagnostics export to be disabled")
        }

        let populated = ProductDiagnosticsSemanticSurface(
            eventCount: 4,
            exportSupported: true
        )
        XCTAssertEqual(try semantic(.export, in: populated.items).eligibility, .enabled)
        XCTAssertTrue(localized(try semantic(.status, in: populated.items).value).contains("4"))

        let unsupported = ProductDiagnosticsSemanticSurface(
            eventCount: 4,
            exportSupported: false
        )
        guard case .disabled = try semantic(.export, in: unsupported.items).eligibility else {
            return XCTFail("Expected unsupported diagnostics export to be disabled")
        }

        let severities: [RuntimeDiagnosticSeverity] = [.debug, .info, .warning, .error]
        for severity in severities {
            let descriptor = ProductDiagnosticsSemanticSurface.event(
                category: "Stream",
                severity: severity,
                hasAction: severity == .error
            )
            XCTAssertEqual(descriptor.role, .status)
            XCTAssertFalse(localized(descriptor.value).isEmpty)
            XCTAssertFalse(descriptor.isDestructive)
        }
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
        XCTAssertTrue(source.contains(".task(id: workspace)"))
        XCTAssertTrue(source.contains("loadInitialState(in: workspace)"))
        XCTAssertTrue(source.contains("navigationSelectionBinding"))
        XCTAssertTrue(source.contains("workspaceSheet(in: workspace) == .addHost"))
        XCTAssertTrue(source.contains("LibraryDashboardView(\n                    workspace: workspace"))
        XCTAssertTrue(source.contains("AppCatalogPanel(workspace: workspace)"))
        XCTAssertTrue(source.contains("PairingPanel(workspace: workspace)"))
        XCTAssertTrue(source.contains("StreamLaunchPanel(workspace: workspace)"))
        XCTAssertTrue(source.contains("selectedHost(in: workspace)"))
        XCTAssertFalse(source.contains("streamLaunchUI.errorMessage"))
        XCTAssertFalse(source.contains("streamLaunchUI.actionMessage"))
        XCTAssertFalse(source.contains("appModel.primaryWorkspaceReference"))
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
                of: "private struct TVStreamControls: View",
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
            "TVStreamControls(\n                workspace: workspace,\n                workspaceLayout: layout,\n                focusedControl: tvFocusedControl\n            )"
        ))
        XCTAssertTrue(streamOverlay.contains(
            "VisionStreamControls(workspace: workspace, workspaceLayout: layout)"
        ))
        XCTAssertFalse(streamOverlay.contains(".onHover"))
    }

    func testRootViewDeclaresNativeKeyboardAndVoiceControlContracts() throws {
        let source = try String(contentsOf: rootViewURL, encoding: .utf8)
        let requiredContracts = [
            "@FocusState private var focusedField: ProductKeyboardFocusTarget?",
            "focusedField = ProductKeyboardFocusPolicy.addHostInitialTarget",
            ".focused($focusedField, equals: .manualHostAddress)",
            ".keyboardShortcut(.defaultAction)",
            ".keyboardShortcut(.cancelAction)",
            "ProductKeyboardFocusPolicy.pairingTarget(for: surface)",
            ".focused($focusedControl, equals: .pairingPIN)",
            ".focused($focusedControl, equals: .pairingProgress)",
            ".focused($focusedControl, equals: .pairingResult)",
            "focusedControl = ProductKeyboardFocusPolicy.streamOverlayInitialTarget",
            ".focused($focusedControl, equals: .streamHideControls)",
            ".keyboardShortcut(\"s\", modifiers: .command)",
            ".accessibilityLabel(\"Host Address\")",
            ".accessibilityLabel(\"Start Pairing\")",
            ".accessibilityLabel(\"Submit Pairing PIN\")",
            ".accessibilityLabel(\"Cancel Pairing\")",
            ".accessibilityLabel(\"Hide Stream Controls\")",
            ".accessibilityLabel(\"Disconnect Stream\")",
            ".accessibilityLabel(\"Save Settings\")",
            "LabeledContent(\"System shortcuts\", value: \"Always local\")"
        ]
        for contract in requiredContracts {
            XCTAssertTrue(
                source.contains(contract),
                "Missing native keyboard contract: \(contract)"
            )
        }
        XCTAssertFalse(source.contains("Forward system shortcuts"))
    }

    func testRootViewEnforcesTouchTextNonColorAndReducedMotionContracts()
        throws
    {
        let source = try String(contentsOf: rootViewURL, encoding: .utf8)
        let requiredContracts = [
            "@Environment(\\.accessibilityReduceMotion) private var reduceMotionEnabled",
            "ProductInteractionAccessibilityPolicy.transitionStyle(",
            ".transition(streamOverlayTransition)",
            ".animation(",
            "case .immediate:",
            ".identity",
            "func productActionTarget() -> some View",
            "#if os(iOS)",
            ".fixedSize(horizontal: false, vertical: true)",
            "ProductInteractionAccessibilityPolicy.minimumTouchTargetDimension",
            ".contentShape(Rectangle())",
            "Image(systemName: \"checkmark\")",
            ".accessibilityHidden(true)",
            "Label(\"Selected\", systemImage: \"checkmark.circle.fill\")",
            ".accessibilityValue(",
            "? \"Selected\"",
            ": \"Not selected\"",
            "Text(severityLabel(for: event.severity))",
            "case .warning: \"Warning\"",
            "case .error: \"Error\""
        ]
        for contract in requiredContracts {
            XCTAssertTrue(
                source.contains(contract),
                "Missing interaction accessibility contract: \(contract)"
            )
        }

        let actionTargetCount = source.components(
            separatedBy: ".productActionTarget()"
        ).count - 1
        XCTAssertGreaterThanOrEqual(actionTargetCount, 30)
        XCTAssertFalse(source.contains(".frame(width: 36, height: 32)"))
        XCTAssertFalse(source.contains(".lineLimit(2)"))
    }

    func testLibraryDashboardAndCommandsReflowWithoutPlatformAssumptions() throws {
        let source = try String(contentsOf: rootViewURL, encoding: .utf8)
        let dashboardStart = try XCTUnwrap(
            source.range(of: "private struct LibraryDashboardView: View")
        )
        let streamStart = try XCTUnwrap(
            source.range(
                of: "private struct StreamWorkspaceView: View",
                range: dashboardStart.upperBound..<source.endIndex
            )
        )
        let workflowSource = String(
            source[dashboardStart.lowerBound..<streamStart.lowerBound]
        )

        let requiredContracts = [
            "@Environment(\\.dynamicTypeSize) private var dynamicTypeSize",
            "GeometryReader { geometry in",
            "ProductLibraryDashboardLayout(",
            "availableWidth: geometry.size.width",
            "dynamicTypeSize.isAccessibilitySize",
            "case .compact:",
            "LazyVStack(alignment: .leading, spacing: 16)",
            "case .wide:",
            "dashboardGrid",
            "ViewThatFits(in: .horizontal)",
            "hostActionButtons(surface)",
            "pairingPINField(workspace: workspace, maxWidth: .infinity)",
            "refreshAppsButton(surface)",
            "refreshAppsButton(surface)\n                    }\n                    .fixedSize(horizontal: true, vertical: false)",
            ".fixedSize(horizontal: true, vertical: false)"
        ]
        for contract in requiredContracts {
            XCTAssertTrue(
                workflowSource.contains(contract),
                "Missing adaptive workflow contract: \(contract)"
            )
        }
        XCTAssertFalse(workflowSource.contains("#if os(iOS)\n            if horizontalSizeClass == .compact"))
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

    func testUnsupportedPlatformsExposeOnlySingleWorkspaceScenes() throws {
        let appSource = try String(contentsOf: appSourceURL, encoding: .utf8)

        let tvStart = try XCTUnwrap(appSource.range(of: "#if os(tvOS)"))
        let macStart = try XCTUnwrap(appSource.range(
            of: "#elseif os(macOS)",
            range: tvStart.upperBound..<appSource.endIndex
        ))
        let tvBranch = String(
            appSource[tvStart.upperBound..<macStart.lowerBound]
        )
        let visionStart = try XCTUnwrap(appSource.range(
            of: "        #else\n",
            range: macStart.upperBound..<appSource.endIndex
        ))
        let visionEnd = try XCTUnwrap(appSource.range(
            of: "#endif",
            range: visionStart.upperBound..<appSource.endIndex
        ))
        let visionBranch = String(
            appSource[visionStart.upperBound..<visionEnd.lowerBound]
        )

        XCTAssertTrue(tvBranch.contains("WindowGroup"))
        XCTAssertTrue(tvBranch.contains(
            "RootView(workspace: appModel.primaryWorkspaceReference)"
        ))
        XCTAssertFalse(tvBranch.contains("ProductWorkspaceSceneRoot"))
        XCTAssertTrue(visionBranch.contains("Window(\"LuneX\", id: \"main\")"))
        XCTAssertTrue(visionBranch.contains(
            "RootView(workspace: appModel.primaryWorkspaceReference)"
        ))
        XCTAssertFalse(visionBranch.contains("WindowGroup"))
        XCTAssertFalse(appSource.contains("openWindow"))
        XCTAssertFalse(appSource.contains("dismissWindow"))
        XCTAssertFalse(appSource.contains("CommandGroup"))
        XCTAssertFalse(appSource.contains("CommandMenu"))
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

    private func tvPresentation(
        focus: TVStreamLocalFocusPresentationStatus
    ) -> TVStreamControlPresentationState {
        TVStreamControlPresentationState(
            focus: focus,
            capture: .local,
            controllers: .unavailable,
            surface: .visible,
            render: .waitingForDecoder,
            hdr: .inactive,
            audio: .inactive,
            failure: .none
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

    private func semantic<ID>(
        _ id: ID,
        in items: [ProductSemanticItem<ID>]
    ) throws -> ProductSemanticDescriptor where ID: Hashable & Sendable {
        try XCTUnwrap(items.first { $0.id == id }?.descriptor)
    }

    private func localized(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
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
