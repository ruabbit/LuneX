import XCTest

@MainActor
final class AppModelWorkflowTests: XCTestCase {
    func testProviderAvailabilityIsDerivedFromInjectedInventory() {
        let unavailable = RuntimeProviderInventory.unavailable
        XCTAssertEqual(unavailable.availability, [])
        XCTAssertFalse(unavailable.availability.pairingTransportAvailable)
        XCTAssertFalse(unavailable.availability.streamTransportAvailable)

        let production = ProductionRuntimeProviderFactory.makeDefault()
        XCTAssertEqual(production.availability, [.pairing, .sessionControl, .remoteInput])
        XCTAssertTrue(production.availability.pairingTransportAvailable)
        XCTAssertFalse(production.availability.streamTransportAvailable)

        let complete = RuntimeProviderInventory(
            pairing: production.pairing,
            sessionControl: production.sessionControl,
            videoReceive: AvailabilityVideoReceiveProvider(),
            audioReceive: AvailabilityAudioReceiveProvider(),
            remoteInput: production.remoteInput
        )
        XCTAssertEqual(complete.availability, [
            .pairing,
            .sessionControl,
            .videoReceive,
            .audioReceive,
            .remoteInput
        ])
        XCTAssertTrue(complete.availability.streamTransportAvailable)

        let withoutPairing = RuntimeProviderInventory(
            sessionControl: complete.sessionControl,
            videoReceive: complete.videoReceive,
            audioReceive: complete.audioReceive,
            remoteInput: complete.remoteInput
        )
        XCTAssertFalse(withoutPairing.availability.pairingTransportAvailable)
        XCTAssertTrue(withoutPairing.availability.streamTransportAvailable)

        let missingRequiredProvider = [
            RuntimeProviderInventory(
                videoReceive: complete.videoReceive,
                audioReceive: complete.audioReceive,
                remoteInput: complete.remoteInput
            ),
            RuntimeProviderInventory(
                sessionControl: complete.sessionControl,
                audioReceive: complete.audioReceive,
                remoteInput: complete.remoteInput
            ),
            RuntimeProviderInventory(
                sessionControl: complete.sessionControl,
                videoReceive: complete.videoReceive,
                remoteInput: complete.remoteInput
            ),
            RuntimeProviderInventory(
                sessionControl: complete.sessionControl,
                videoReceive: complete.videoReceive,
                audioReceive: complete.audioReceive
            )
        ]
        XCTAssertTrue(missingRequiredProvider.allSatisfy {
            !$0.availability.streamTransportAvailable
        })
    }

    func testAppModelAppliesPlatformLifecycleToRenderState() {
        let model = AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(),
                serverInfoClient: StubServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: StubAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(launchClient: StubStreamLaunchClient()),
            clientIdentityStore: InMemoryClientIdentityStore()
        )
        let lifecycle = PlatformLifecycleState()
        lifecycle.isStreamActive = true
        lifecycle.isVisible = true
        lifecycle.isFocused = false
        lifecycle.drawableSize = PixelSize(width: 2560, height: 1440)
        lifecycle.headroom = DisplayHeadroom(potential: 2.0, current: 1.5, reference: 1.0)
        lifecycle.updateRenderPolicy()
        model.renderState.transform.sourceSize = PixelSize(width: 1920, height: 1080)

        model.applyPlatformLifecycle(lifecycle)

        XCTAssertEqual(model.renderState.policy, .throttled(reason: "Window or scene not focused"))
        XCTAssertEqual(model.renderState.transform.drawableSize, PixelSize(width: 2560, height: 1440))
        XCTAssertEqual(model.renderState.coordinateSnapshot?.drawableSize, PixelSize(width: 2560, height: 1440))
        XCTAssertEqual(model.renderState.headroom, lifecycle.headroom)
    }

    func testLatestLifecycleIsCachedUntilMediaGenerationStartsAndThenAppliedInOrder() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 31,
                    key: Data(repeating: 0x31, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()

        let lifecycle = makePlatformLifecycle(
            isStreamActive: false,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 2560, height: 1440)
        )
        model.applyPlatformLifecycle(lifecycle)
        lifecycle.isStreamActive = true
        lifecycle.isVisible = false
        lifecycle.headroom = DisplayHeadroom(
            potential: 2.4,
            current: 1.8,
            reference: 1.0
        )
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        XCTAssertEqual(mediaEnvironment.currentLifecycleApplications(), [])

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { mediaEnvironment.currentLifecycleApplications().count == 1 }

        let cachedApplication = try XCTUnwrap(
            mediaEnvironment.currentLifecycleApplications().first
        )
        XCTAssertEqual(cachedApplication.sessionID, record.sessionID)
        XCTAssertEqual(cachedApplication.mediaGeneration, 1)
        XCTAssertEqual(cachedApplication.lifecycleRevision, 2)
        XCTAssertEqual(
            cachedApplication.directive,
            SessionLifecycleDirectiveResolver.resolve(
                isStreamActive: true,
                isVisible: false,
                isFocused: true,
                drawableSize: PixelSize(width: 2560, height: 1440)
            )
        )

        lifecycle.isVisible = true
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        await waitUntil { mediaEnvironment.currentLifecycleApplications().count == 2 }
        await waitUntil { model.session.isStreaming }
        let applications = mediaEnvironment.currentLifecycleApplications()
        XCTAssertEqual(applications.map(\.lifecycleRevision), [2, 3])
        XCTAssertEqual(applications.last?.directive.input, .open)
        XCTAssertEqual(model.renderState.policy, .active)
        XCTAssertEqual(
            model.renderState.transform.sourceSize,
            PixelSize(width: 3840, height: 2160)
        )
        XCTAssertEqual(model.renderState.headroom, lifecycle.headroom)

        await model.stopStream()
        await launchTask.value
    }

    func testMacPlatformSampleFlowsThroughAppModelAndFocusLossReleasesInput() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 32,
                    key: Data(repeating: 0x32, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 2560, height: 1440)
        )
        model.applyPlatformLifecycle(lifecycle)

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        await waitUntil { model.macSessionInputSnapshot().acceptsInput }

        let sample = MacPlatformInputSample.keyboard(MacKeyboardSample(
            rawKeyCode: 0,
            characters: "a",
            isDown: true,
            modifiers: [],
            isRepeat: false
        ))
        XCTAssertEqual(model.submitMacPlatformInput(sample), .accepted)
        await waitUntil { mediaEnvironment.currentSentInputApplications().count == 1 }
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().first?.event,
            .keyboard(KeyboardInputEvent(
                rawKeyCode: 0x41,
                characters: "a",
                isDown: true,
                modifiers: [],
                isRepeat: false
            ))
        )

        lifecycle.isFocused = false
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        XCTAssertFalse(model.macSessionInputSnapshot().acceptsInput)
        XCTAssertEqual(
            model.submitMacPlatformInput(sample),
            .rejected(.admissionClosed)
        )
        await waitUntil {
            model.macSessionInputSnapshot().completedReleaseBarrierCount == 1
        }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            1
        )
        XCTAssertEqual(
            model.macSessionInputSnapshot().completedReleaseBarrierCount,
            1
        )
        XCTAssertEqual(model.renderState.policy, .throttled(
            reason: "Window or scene not focused"
        ))

        await model.stopStream()
        await launchTask.value
        XCTAssertNil(model.macSessionInputSnapshot().generation)
    }

    func testMacPlatformInputFailsClosedWithoutCurrentDrawableGeometry() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 33,
                    key: Data(repeating: 0x33, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: .zero
        )
        model.applyPlatformLifecycle(lifecycle)

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        await waitUntil { model.macSessionInputSnapshot().generation != nil }
        XCTAssertFalse(model.macSessionInputSnapshot().acceptsInput)
        XCTAssertNil(model.renderState.coordinateSnapshot)
        XCTAssertEqual(
            model.submitMacPlatformInput(.pointerMove(MacPointerSample(
                localPoint: RemotePoint(x: 10, y: 10),
                deltaX: 0,
                deltaY: 0,
                buttons: []
            ))),
            .rejected(.admissionClosed)
        )
        XCTAssertEqual(mediaEnvironment.currentSentInputApplications(), [])

        await model.stopStream()
        await launchTask.value
    }

    func testLifecycleEffectFailureFailsSessionAndCleansInputGeneration() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(
            failsLifecycleApplication: true
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 34,
                    key: Data(repeating: 0x34, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        model.applyPlatformLifecycle(makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 2560, height: 1440)
        ))

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await launchTask.value

        XCTAssertFalse(model.hasActiveStreamSession)
        guard case .failed = model.session.phase else {
            return XCTFail("A current lifecycle effect failure must fail the session.")
        }
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertNil(model.macSessionInputSnapshot().generation)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(
            mediaEnvironment.currentStoppedSessionIDs(),
            [record.sessionID]
        )
    }

    func testUnavailablePairingPreservesHostState() async throws {
        let hostRepository = InMemoryHostRepository()
        let hostManager = HostLibraryManager(
            repository: hostRepository,
            serverInfoClient: StubServerInfoClient()
        )
        let catalogManager = AppCatalogManager(
            appListClient: StubAppListClient(),
            artworkCache: InMemoryArtworkCache()
        )
        let streamCoordinator = StreamSessionCoordinator(launchClient: StubStreamLaunchClient())
        let identityProvisioner = ControlledIdentityProvisioner()
        let model = AppModel(
            hostLibraryManager: hostManager,
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: catalogManager,
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: streamCoordinator,
            runtimeProviders: .unavailable,
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientIdentityProvisioner: identityProvisioner,
            clientUniqueID: "test-client",
            remoteInputKey: RemoteInputKeyMaterial(
                keyID: 7,
                key: Data(repeating: 0xAA, count: 16)
            )
        )

        await model.addManualHost(name: nil, address: "moon.local")
        XCTAssertEqual(model.hosts.count, 1)
        XCTAssertEqual(model.selectedHost?.name, "Test Host")

        let host = try XCTUnwrap(model.selectedHost)
        await model.beginPairing(host: host)
        model.pairingUI.pin = "1234"
        await model.submitPairingPIN()

        XCTAssertEqual(model.selectedHost?.pairingState, .unpaired)
        XCTAssertNil(model.selectedHost?.pinnedIdentity)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertTrue(model.pairingUI.message?.contains("unavailable") == true)
        XCTAssertEqual(model.pairingUI.actionMessage, ApplicationDiagnosticAction.updateBuild.label)
        XCTAssertEqual(model.diagnostics.latestActionableEvent?.category, .pairing)
        XCTAssertEqual(model.diagnostics.latestActionableEvent?.code, "pairing_provider_unavailable")
        let identityProvisioningStarted = await identityProvisioner.hasStarted()
        XCTAssertFalse(identityProvisioningStarted)
    }

    func testPairingUIConsumesProgressAndAuthenticatedCompletion() async throws {
        let host = makeUnpairedHost()
        let identity = makePairingIdentity()
        let provider = ControlledPairingProvider()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: FixedIdentityProvisioner(identity: identity)
        )

        await model.loadHosts()
        await model.beginPairing(host: host)

        XCTAssertEqual(model.pairingUI.stage, .waitingForPIN)
        XCTAssertFalse(model.pairingUI.isRunning)
        XCTAssertNotNil(model.pairingUI.attemptID)
        XCTAssertEqual(provider.currentRequestCount(), 0)

        model.pairingUI.pin = "1234"
        let submitTask = Task { await model.submitPairingPIN() }
        for _ in 0..<100 where provider.currentRequestCount() == 0 {
            await Task.yield()
        }
        let request = try XCTUnwrap(provider.latestRequest())
        XCTAssertEqual(request.host.id, host.id)
        XCTAssertEqual(request.pin, "1234")
        XCTAssertEqual(request.clientIdentity, identity)
        XCTAssertEqual(model.pairingUI.pin, "")
        XCTAssertEqual(model.session.phase, .pairing(pin: ""))
        XCTAssertFalse(model.diagnostics.events.contains { $0.message.contains("1234") })

        provider.yieldProgress(.verifyingServer, for: request)
        for _ in 0..<100 where model.pairingUI.stage != .verifyingServer {
            await Task.yield()
        }
        XCTAssertEqual(model.pairingUI.stage, .verifyingServer)
        XCTAssertTrue(model.pairingUI.message?.contains("Verifying") == true)

        provider.completeAuthenticated(request)
        await submitTask.value

        XCTAssertEqual(model.selectedHost?.pairingState, .paired)
        XCTAssertEqual(model.selectedHost?.pinnedIdentity?.serverCertificateDER, Data([0x30, 0x01, 0x02]))
        XCTAssertEqual(model.pairingUI.stage, .paired)
        XCTAssertFalse(model.pairingUI.isRunning)
        XCTAssertNil(model.pairingUI.attemptID)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertFalse(model.diagnostics.events.contains { $0.message.contains("1234") })
    }

    func testPairingCancellationInvalidatesLateCompletion() async throws {
        let host = makeUnpairedHost()
        let provider = ControlledPairingProvider()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: FixedIdentityProvisioner(identity: makePairingIdentity())
        )

        await model.loadHosts()
        await model.beginPairing(host: host)
        model.pairingUI.pin = "4321"
        let submitTask = Task { await model.submitPairingPIN() }
        for _ in 0..<100 where provider.currentRequestCount() == 0 {
            await Task.yield()
        }
        let request = try XCTUnwrap(provider.latestRequest())

        await model.cancelPairing()
        provider.completeAuthenticated(request)
        await submitTask.value

        XCTAssertEqual(provider.currentCancelledAttemptIDs(), [request.attemptID])
        XCTAssertEqual(model.selectedHost?.pairingState, .unpaired)
        XCTAssertNil(model.selectedHost?.pinnedIdentity)
        XCTAssertEqual(model.pairingUI.stage, .cancelled)
        XCTAssertNil(model.pairingUI.attemptID)
        XCTAssertEqual(model.session.phase, .disconnected)
    }

    func testPairingFailsClosedForInvalidOrIncompleteCompletion() async throws {
        for completion in [ControlledPairingProvider.Completion.invalid, .incomplete] {
            let host = makeUnpairedHost()
            let provider = ControlledPairingProvider()
            let model = makePairingModel(
                host: host,
                provider: provider,
                identityProvisioner: FixedIdentityProvisioner(identity: makePairingIdentity())
            )

            await model.loadHosts()
            await model.beginPairing(host: host)
            model.pairingUI.pin = "2468"
            let submitTask = Task { await model.submitPairingPIN() }
            for _ in 0..<100 where provider.currentRequestCount() == 0 {
                await Task.yield()
            }
            let request = try XCTUnwrap(provider.latestRequest())
            provider.finish(request, completion: completion)
            await submitTask.value

            XCTAssertEqual(model.selectedHost?.pairingState, .unpaired)
            XCTAssertNil(model.selectedHost?.pinnedIdentity)
            XCTAssertEqual(model.pairingUI.stage, .failed)
            XCTAssertNil(model.pairingUI.attemptID)
            guard case .failed = model.session.phase else {
                return XCTFail("Invalid or incomplete pairing completion must fail closed.")
            }
            XCTAssertEqual(model.pairingUI.actionMessage, ApplicationDiagnosticAction.pairAgain.label)
            XCTAssertEqual(model.diagnostics.latestActionableEvent?.category, .pairing)
            XCTAssertEqual(model.diagnostics.latestActionableEvent?.code, "pairing_failed")
        }
    }

    func testPairingFailureProgressDoesNotExposeProviderMessage() async throws {
        let host = makeUnpairedHost()
        let provider = ControlledPairingProvider()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: FixedIdentityProvisioner(identity: makePairingIdentity())
        )

        await model.loadHosts()
        await model.beginPairing(host: host)
        model.pairingUI.pin = "9753"
        let submitTask = Task { await model.submitPairingPIN() }
        for _ in 0..<100 where provider.currentRequestCount() == 0 {
            await Task.yield()
        }
        let request = try XCTUnwrap(provider.latestRequest())
        provider.yieldFailure(
            PairingFailure(
                code: .invalidPIN,
                message: "PIN=9753 Authorization: Basic private-value"
            ),
            for: request
        )
        await submitTask.value

        XCTAssertEqual(model.pairingUI.message, "The host rejected the pairing request.")
        XCTAssertEqual(model.pairingUI.actionMessage, ApplicationDiagnosticAction.verifyPIN.label)
        XCTAssertFalse(model.diagnostics.events.contains { $0.message.contains("9753") })
        XCTAssertFalse(model.diagnostics.events.contains {
            $0.message.localizedCaseInsensitiveContains("authorization")
        })
    }

    func testPairingIdentityFailureStopsBeforeRuntimeRequest() async throws {
        let host = makeUnpairedHost()
        let provider = ControlledPairingProvider()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: FailingIdentityProvisioner()
        )

        await model.loadHosts()
        await model.beginPairing(host: host)

        XCTAssertEqual(provider.currentRequestCount(), 0)
        XCTAssertEqual(model.selectedHost?.pairingState, .unpaired)
        XCTAssertEqual(model.pairingUI.stage, .failed)
        XCTAssertNil(model.pairingUI.attemptID)
        XCTAssertTrue(model.pairingUI.message?.contains("identity") == true)
    }

    func testPairingRejectsNonASCIIPINBeforeRuntimeRequest() async throws {
        let host = makeUnpairedHost()
        let provider = ControlledPairingProvider()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: FixedIdentityProvisioner(identity: makePairingIdentity())
        )

        await model.loadHosts()
        await model.beginPairing(host: host)
        model.pairingUI.pin = "１２３４"

        XCTAssertFalse(model.isPairingPINValid)
        await model.submitPairingPIN()
        XCTAssertEqual(provider.currentRequestCount(), 0)
        XCTAssertEqual(model.pairingUI.stage, .waitingForPIN)
    }

    func testPairingCancellationWhileIdentityIsPendingIgnoresLateIdentity() async throws {
        let host = makeUnpairedHost()
        let provider = ControlledPairingProvider()
        let identityProvisioner = ControlledIdentityProvisioner()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: identityProvisioner
        )

        await model.loadHosts()
        let beginTask = Task { await model.beginPairing(host: host) }
        for _ in 0..<100 {
            if await identityProvisioner.hasStarted() { break }
            await Task.yield()
        }
        let identityPreparationStarted = await identityProvisioner.hasStarted()
        XCTAssertTrue(identityPreparationStarted)

        await model.cancelPairing()
        await identityProvisioner.complete(with: makePairingIdentity())
        await beginTask.value

        XCTAssertEqual(model.selectedHost?.pairingState, .unpaired)
        XCTAssertEqual(model.pairingUI.stage, .cancelled)
        XCTAssertNil(model.pairingUI.attemptID)
        XCTAssertEqual(provider.currentRequestCount(), 0)
    }

    func testDuplicatePairingSubmissionDoesNotStartAnotherRuntimeRequest() async throws {
        let host = makeUnpairedHost()
        let provider = ControlledPairingProvider()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: FixedIdentityProvisioner(identity: makePairingIdentity())
        )

        await model.loadHosts()
        await model.beginPairing(host: host)
        model.pairingUI.pin = "1357"
        let firstSubmission = Task { await model.submitPairingPIN() }
        for _ in 0..<100 where provider.currentRequestCount() == 0 {
            await Task.yield()
        }
        let request = try XCTUnwrap(provider.latestRequest())

        model.pairingUI.pin = "2468"
        await model.submitPairingPIN()
        XCTAssertEqual(provider.currentRequestCount(), 1)

        provider.completeAuthenticated(request)
        await firstSubmission.value
        XCTAssertEqual(model.pairingUI.stage, .paired)
    }

    func testMismatchedPairingProgressFailsClosedAndCancelsProvider() async throws {
        let host = makeUnpairedHost()
        let provider = ControlledPairingProvider()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: FixedIdentityProvisioner(identity: makePairingIdentity())
        )

        await model.loadHosts()
        await model.beginPairing(host: host)
        model.pairingUI.pin = "8642"
        let submission = Task { await model.submitPairingPIN() }
        for _ in 0..<100 where provider.currentRequestCount() == 0 {
            await Task.yield()
        }
        let request = try XCTUnwrap(provider.latestRequest())

        provider.yieldProgress(
            .verifyingServer,
            for: request,
            hostID: UUID(uuidString: "7E42A4CF-4619-435F-B30E-133095E952C8")!
        )
        await submission.value

        XCTAssertEqual(model.selectedHost?.pairingState, .unpaired)
        XCTAssertEqual(model.pairingUI.stage, .failed)
        XCTAssertNil(model.pairingUI.attemptID)
        XCTAssertEqual(provider.currentCancelledAttemptIDs(), [request.attemptID])
    }

    func testCancellingWithoutPairingAttemptPreservesActiveSessionState() async {
        let model = AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(),
                serverInfoClient: StubServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: StubAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(launchClient: StubStreamLaunchClient()),
            runtimeProviders: .unavailable,
            clientIdentityStore: InMemoryClientIdentityStore()
        )
        model.session.phase = .streaming

        await model.cancelPairing()

        XCTAssertEqual(model.session.phase, .streaming)
        XCTAssertEqual(model.pairingUI, PairingUIState())
    }

    func testUnavailableTransportDoesNotLaunchOrReportStreaming() async throws {
        let host = MoonlightHost(
            id: UUID(uuidString: "2A666A9A-2C77-451B-B2B1-73E697AE7D5C")!,
            name: "Test Host",
            address: "moon.local",
            pairingState: .paired,
            reachability: .online,
            pinnedIdentity: PinnedHostIdentity(
                certificateSHA256: "existing-cert",
                serverCertificateDER: Data([1, 2, 3]),
                pairedAt: Date(timeIntervalSince1970: 10)
            )
        )
        let hostManager = HostLibraryManager(
            repository: InMemoryHostRepository(hosts: [host]),
            serverInfoClient: StubServerInfoClient()
        )
        let catalogManager = AppCatalogManager(
            appListClient: StubAppListClient(),
            artworkCache: InMemoryArtworkCache()
        )
        let launchClient = StubStreamLaunchClient()
        let model = AppModel(
            hostLibraryManager: hostManager,
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: catalogManager,
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(launchClient: launchClient),
            runtimeProviders: .unavailable,
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientUniqueID: "test-client",
            remoteInputKey: RemoteInputKeyMaterial(
                keyID: 7,
                key: Data(repeating: 0xAA, count: 16)
            )
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        XCTAssertEqual(model.selectedApps.map(\.name), ["Desktop", "Game"])
        XCTAssertEqual(model.selectedApp?.name, "Desktop")

        await model.launchSelectedApp()
        XCTAssertFalse(model.session.isStreaming)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertEqual(model.navigationSelection, .library)
        XCTAssertTrue(model.streamLaunchUI.errorMessage?.contains("unavailable") == true)
        XCTAssertEqual(model.streamLaunchUI.actionMessage, ApplicationDiagnosticAction.updateBuild.label)
        XCTAssertEqual(model.diagnostics.latestActionableEvent?.category, .transport)
        XCTAssertEqual(model.diagnostics.latestActionableEvent?.code, "stream_provider_unavailable")
        let launchCount = await launchClient.currentLaunchCount()
        XCTAssertEqual(launchCount, 0)
    }

    func testEveryMissingRequiredStreamProviderStopsBeforeAnySessionSideEffect() async throws {
        for missingProvider in MissingStreamProvider.allCases {
            let controlProvider = ControlledSessionControlProvider()
            let mediaEnvironment = ControlledSessionMediaEnvironment()
            let launchClient = StubStreamLaunchClient()
            let keyGenerator = ScriptedInputKeyGenerator(results: [])
            let production = ProductionRuntimeProviderFactory.makeDefault()
            let inventory = RuntimeProviderInventory(
                pairing: production.pairing,
                sessionControl: missingProvider == .sessionControl ? nil : controlProvider,
                videoReceive: missingProvider == .videoReceive
                    ? nil
                    : AvailabilityVideoReceiveProvider(),
                audioReceive: missingProvider == .audioReceive
                    ? nil
                    : AvailabilityAudioReceiveProvider(),
                remoteInput: missingProvider == .remoteInput ? nil : production.remoteInput
            )
            let model = makeLaunchReadyModel(
                sessionControlProvider: controlProvider,
                sessionMediaEnvironment: mediaEnvironment,
                launchClient: launchClient,
                remoteInputKeyGenerator: keyGenerator,
                runtimeProviders: inventory
            )

            await model.loadInitialState()
            await model.refreshAppsForSelectedHost()
            await model.launchSelectedApp()

            XCTAssertFalse(
                model.isStreamTransportAvailable,
                "\(missingProvider) must keep stream availability fail closed."
            )
            XCTAssertFalse(model.hasActiveStreamSession)
            XCTAssertFalse(model.session.isStreaming)
            XCTAssertEqual(model.session.phase, .disconnected)
            XCTAssertEqual(model.navigationSelection, .library)
            XCTAssertEqual(model.renderState.policy, .idle)
            XCTAssertEqual(model.streamLaunchUI.errorMessage, ApplicationDiagnosticFactory.streamUnavailable.summary)
            XCTAssertEqual(model.streamLaunchUI.actionMessage, ApplicationDiagnosticAction.updateBuild.label)
            XCTAssertEqual(model.diagnostics.latestActionableEvent?.code, "stream_provider_unavailable")
            XCTAssertEqual(keyGenerator.currentGenerationCount(), 0)
            XCTAssertEqual(controlProvider.currentStartRecords().count, 0)
            XCTAssertEqual(mediaEnvironment.currentStartRecords().count, 0)
            let launchCount = await launchClient.currentLaunchCount()
            XCTAssertEqual(launchCount, 0)
        }
    }

    func testSessionUIRequiresNegotiationAndEveryRequiredChannel() async throws {
        let provider = ControlledSessionControlProvider()
        let launchClient = StubStreamLaunchClient()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: launchClient,
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 7,
                    key: Data(repeating: 0xAA, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)

        XCTAssertTrue(model.hasActiveStreamSession)
        XCTAssertEqual(model.navigationSelection, .stream)
        XCTAssertFalse(model.session.isStreaming)
        let launchCount = await launchClient.currentLaunchCount()
        XCTAssertEqual(launchCount, 0)

        provider.yield(.launchAccepted(makeSessionLaunchResponse()), sessionID: record.sessionID)
        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(.channelsReady(.control), sessionID: record.sessionID)
        await waitUntil { model.session.phase.label.contains("Connecting") }
        XCTAssertFalse(model.session.isStreaming)

        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey
            )),
            sessionID: record.sessionID
        )
        provider.yield(.channelsReady(.all), sessionID: record.sessionID)
        await waitUntil { model.session.isStreaming }

        XCTAssertTrue(model.session.isStreaming)
        XCTAssertEqual(model.renderState.policy, .active)
        XCTAssertFalse(model.streamLaunchUI.isLaunching)

        provider.yield(
            .terminated(reason: "The host ended the streaming session."),
            sessionID: record.sessionID
        )
        provider.finish(sessionID: record.sessionID)
        await launchTask.value

        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertFalse(model.streamLaunchUI.isLaunching)
        XCTAssertNil(model.session.activeHostID)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [])
        XCTAssertTrue(model.diagnostics.events.contains {
            $0.message == "The host ended the streaming session."
        })
    }

    func testOldInputReleaseCannotPublishIntoReplacementGeneration() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 1,
                    key: Data(repeating: 0x11, count: 16)
                )),
                .success(RemoteInputKeyMaterial(
                    keyID: 2,
                    key: Data(repeating: 0x22, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let firstLaunch = Task { await model.launchSelectedApp() }
        let firstRecord = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: firstRecord)
        await waitUntil { model.session.isStreaming }

        mediaEnvironment.blockNextRelease()
        let staleRelease = Task { try await model.releaseRemoteInput() }
        await waitUntil { mediaEnvironment.hasBlockedRelease() }
        await model.stopStream()
        await firstLaunch.value

        let replacementLaunch = Task { await model.launchSelectedApp() }
        await waitUntil { provider.currentStartRecords().count == 2 }
        let replacementRecord = try XCTUnwrap(provider.currentStartRecords().last)
        driveSessionToStreaming(provider, record: replacementRecord)
        await waitUntil { model.session.isStreaming }
        let diagnosticCount = model.diagnostics.events.count

        mediaEnvironment.resumeBlockedRelease()
        do {
            try await staleRelease.value
            XCTFail("A release owned by the stopped generation must fail closed.")
        } catch {
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .inactiveSession
            )
        }
        XCTAssertEqual(model.diagnostics.events.count, diagnosticCount)
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().last?.mediaGeneration,
            1
        )

        await model.stopStream()
        await replacementLaunch.value
    }

    func testReconnectLeavesStreamingUntilFreshNegotiationAndFullReadiness() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(automaticallyReady: false)
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 11,
                    key: Data(repeating: 0xEE, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { mediaEnvironment.currentStartRecords().count == 1 }
        mediaEnvironment.yieldReadiness(
            [.video, .audio, .input],
            sessionID: record.sessionID
        )
        await waitUntil { model.session.isStreaming }

        provider.yield(
            .reconnecting(attempt: 1, reason: "Control channel interrupted."),
            sessionID: record.sessionID
        )
        await waitUntil { model.session.phase.label.contains("Reconnecting") }
        XCTAssertFalse(model.session.isStreaming)
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertTrue(model.hasActiveStreamSession)

        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey
            )),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.currentStartRecords().count == 2 }
        mediaEnvironment.yieldReadiness(
            [.video, .input],
            sessionID: record.sessionID
        )
        provider.yield(.channelsReady(.control), sessionID: record.sessionID)
        for _ in 0..<100 {
            await Task.yield()
        }
        XCTAssertTrue(model.session.phase.label.contains("Reconnecting"))
        XCTAssertFalse(model.session.isStreaming)
        XCTAssertEqual(model.renderState.policy, .idle)

        mediaEnvironment.yieldReadiness(
            [.video, .audio, .input],
            sessionID: record.sessionID
        )
        await waitUntil { model.session.isStreaming }
        XCTAssertEqual(model.renderState.policy, .active)

        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launchTask.value
        XCTAssertEqual(model.session.phase, .disconnected)
    }

    func testControlReadinessCannotBypassMediaEnvironmentReadiness() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(automaticallyReady: false)
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 14,
                    key: Data(repeating: 0xF2, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        provider.yield(.launchAccepted(makeSessionLaunchResponse()), sessionID: record.sessionID)
        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey
            )),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.currentStartRecords().count == 1 }
        provider.yield(.channelsReady(.all), sessionID: record.sessionID)
        for _ in 0..<100 { await Task.yield() }

        XCTAssertFalse(model.session.isStreaming)
        XCTAssertEqual(model.renderState.policy, .idle)
        let inputEvent = RemoteInputEvent.keyboard(KeyboardInputEvent(
            rawKeyCode: 4,
            characters: nil,
            isDown: true,
            modifiers: [],
            isRepeat: false
        ))
        do {
            try await model.sendRemoteInput(inputEvent)
            XCTFail("Input must fail closed until media input readiness is published.")
        } catch {
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .inputUnavailable
            )
        }
        XCTAssertEqual(mediaEnvironment.currentSentInputApplications(), [])
        mediaEnvironment.yieldReadiness(
            [.video, .audio, .input],
            sessionID: record.sessionID
        )
        await waitUntil { model.session.isStreaming }
        try await model.sendRemoteInput(inputEvent)
        try await model.releaseRemoteInput()
        mediaEnvironment.yieldFeedback(
            .led(ControllerLEDFeedback(
                controllerID: "controller-1",
                red: 10,
                green: 20,
                blue: 30
            )),
            sessionID: record.sessionID
        )
        await waitUntil { model.latestRemoteInputFeedback != nil }
        let sentApplications = mediaEnvironment.currentSentInputApplications()
        let mediaSnapshot = await mediaEnvironment.snapshot()
        XCTAssertEqual(sentApplications.count, 1)
        XCTAssertEqual(sentApplications.first?.sessionID, record.sessionID)
        XCTAssertEqual(sentApplications.first?.mediaGeneration, mediaSnapshot.generation)
        XCTAssertEqual(sentApplications.first?.event, inputEvent)
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications(),
            [SessionInputReleaseApplication(
                sessionID: record.sessionID,
                mediaGeneration: mediaSnapshot.generation
            )]
        )
        XCTAssertEqual(model.latestRemoteInputFeedback, .led(ControllerLEDFeedback(
            controllerID: "controller-1",
            red: 10,
            green: 20,
            blue: 30
        )))

        await model.stopStream()
        await launchTask.value
        XCTAssertEqual(mediaEnvironment.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertNil(model.latestRemoteInputFeedback)
        do {
            try await model.sendRemoteInput(inputEvent)
            XCTFail("Stopped media generation must reject remote input.")
        } catch {
            XCTAssertEqual(error as? SessionMediaEnvironmentError, .inactiveSession)
        }
    }

    func testMediaEnvironmentFailureFailsSessionAndStopsControlProviderOnce() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 16,
                    key: Data(repeating: 0xF4, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        mediaEnvironment.finish(
            sessionID: record.sessionID,
            throwing: MediaEnvironmentApplicationTestError.failed
        )
        await launchTask.value

        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertNil(model.session.activeHostID)
        guard case .failed = model.session.phase else {
            return XCTFail("Media environment failure must fail the application session.")
        }
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(mediaEnvironment.currentStoppedSessionIDs(), [record.sessionID])
    }

    func testLocalStopWhileMediaStartupIsPendingCannotRestoreStreaming() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = BlockingSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 15,
                    key: Data(repeating: 0xF3, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        provider.yield(.launchAccepted(makeSessionLaunchResponse()), sessionID: record.sessionID)
        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey
            )),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.hasStarted() }

        await model.stopStream()
        mediaEnvironment.completeStart()
        await launchTask.value

        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(mediaEnvironment.currentStoppedSessionIDs(), [
            record.sessionID,
            record.sessionID
        ])
    }

    func testInvalidSessionEventOrderFailsClosedAndStopsProviderOnce() async throws {
        let provider = ControlledSessionControlProvider()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 12,
                    key: Data(repeating: 0xF0, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)

        provider.yield(.channelsReady(.all), sessionID: record.sessionID)
        await launchTask.value

        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertFalse(model.streamLaunchUI.isLaunching)
        XCTAssertNil(model.session.activeHostID)
        guard case .failed = model.session.phase else {
            return XCTFail("Invalid session event order must fail closed.")
        }
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
    }

    func testLocalStopInvalidatesLateSessionEventsAndStopsProviderOnce() async throws {
        let provider = ControlledSessionControlProvider()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 8,
                    key: Data(repeating: 0xBB, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        model.streamLaunchUI.errorMessage = "stale failure"
        model.streamLaunchUI.actionMessage = "stale action"

        await model.stopStream()
        provider.yield(.channelsReady(.all), sessionID: record.sessionID)
        await launchTask.value

        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertNil(model.streamLaunchUI.errorMessage)
        XCTAssertNil(model.streamLaunchUI.actionMessage)
    }

    func testDuplicateLaunchDoesNotStartAnotherSessionGeneration() async throws {
        let provider = ControlledSessionControlProvider()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 9,
                    key: Data(repeating: 0xCC, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        _ = try await waitForSessionStart(provider)

        await model.launchSelectedApp()
        XCTAssertEqual(provider.currentStartRecords().count, 1)

        await model.stopStream()
        await launchTask.value
    }

    func testControlStreamFailureAndIncompleteEndFailClosed() async throws {
        for ending in ControlledSessionControlProvider.Ending.allCases {
            let provider = ControlledSessionControlProvider()
            let model = makeLaunchReadyModel(
                sessionControlProvider: provider,
                launchClient: StubStreamLaunchClient(),
                remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                    .success(RemoteInputKeyMaterial(
                        keyID: 10,
                        key: Data(repeating: 0xDD, count: 16)
                    ))
                ])
            )

            await model.loadInitialState()
            await model.refreshAppsForSelectedHost()
            let launchTask = Task { await model.launchSelectedApp() }
            let record = try await waitForSessionStart(provider)
            provider.yield(.launchAccepted(makeSessionLaunchResponse()), sessionID: record.sessionID)
            provider.finish(sessionID: record.sessionID, ending: ending)
            await launchTask.value

            XCTAssertFalse(model.hasActiveStreamSession)
            guard case .failed = model.session.phase else {
                return XCTFail("A non-terminal control stream must fail closed.")
            }
            XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
            XCTAssertEqual(model.renderState.policy, .idle)
            XCTAssertEqual(model.diagnostics.latestActionableEvent?.category, .transport)
            XCTAssertEqual(model.streamLaunchUI.actionMessage, ApplicationDiagnosticAction.retryStream.label)
        }
    }

    func testMediaAndControllerFailuresSurfaceSafeActionableDiagnostics() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(automaticallyReady: false)
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 18,
                    key: Data(repeating: 0xC8, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { mediaEnvironment.currentStartRecords().count == 1 }

        mediaEnvironment.yieldFeedback(.diagnostic(RemoteInputFeedbackDiagnostic(
            controllerID: "must-not-appear",
            controllerIndex: 4,
            command: .led,
            reason: .unsupportedCapability
        )), sessionID: record.sessionID)
        await waitUntil { model.diagnostics.latestActionableEvent?.severity == .warning }
        let feedbackEvent = try XCTUnwrap(model.diagnostics.latestActionableEvent)
        XCTAssertEqual(feedbackEvent.category, .input)
        XCTAssertFalse(feedbackEvent.message.contains("must-not-appear"))

        mediaEnvironment.finish(
            sessionID: record.sessionID,
            throwing: VideoDecoderError.noActiveSession
        )
        await launchTask.value

        let failureEvent = try XCTUnwrap(model.diagnostics.latestActionableEvent)
        XCTAssertEqual(failureEvent.category, .decoder)
        XCTAssertEqual(failureEvent.code, "video_pipeline_failed")
        XCTAssertEqual(failureEvent.action, .reviewStreamSettings)
        XCTAssertEqual(
            model.streamLaunchUI.actionMessage,
            ApplicationDiagnosticAction.reviewStreamSettings.label
        )
        XCTAssertFalse(failureEvent.message.contains("must-not-appear"))
    }

    func testMacSurfacePolicyDerivesSessionLifecycleGeometryAndInputSettings() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 35,
                    key: Data(repeating: 0x35, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 2_560, height: 1_440)
        )
        model.applyPlatformLifecycle(lifecycle)
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.macInputSurfacePolicy.admitsInput }

        XCTAssertTrue(model.macInputSurfacePolicy.cursorPolicy.capturesRelativePointer)
        XCTAssertTrue(model.macInputSurfacePolicy.cursorPolicy.hidesSystemCursor)
        XCTAssertTrue(model.macInputSurfacePolicy.forwardsSystemShortcuts)

        model.settings.input.preferRelativeMouseMode = false
        model.settings.input.captureSystemShortcuts = false
        XCTAssertTrue(model.macInputSurfacePolicy.admitsInput)
        XCTAssertFalse(model.macInputSurfacePolicy.cursorPolicy.capturesRelativePointer)
        XCTAssertFalse(model.macInputSurfacePolicy.cursorPolicy.hidesSystemCursor)
        XCTAssertFalse(model.macInputSurfacePolicy.forwardsSystemShortcuts)

        XCTAssertEqual(
            model.submitMacPlatformInput(.pointerMove(MacPointerSample(
                localPoint: RemotePoint(x: 1_280, y: 720),
                deltaX: 9,
                deltaY: -3,
                buttons: []
            ))),
            .accepted
        )
        await waitUntil { mediaEnvironment.currentSentInputApplications().count == 1 }
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().first?.event,
            .pointer(.absoluteMove(
                point: RemotePoint(x: 1_920, y: 1_080),
                referenceSize: PixelSize(width: 3_840, height: 2_160),
                buttons: []
            ))
        )

        lifecycle.isFocused = false
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)
        XCTAssertEqual(
            model.submitMacPlatformInput(.pointerMove(MacPointerSample(
                localPoint: RemotePoint(x: 1_280, y: 720),
                deltaX: 1,
                deltaY: 1,
                buttons: []
            ))),
            .rejected(.admissionClosed)
        )

        lifecycle.isFocused = true
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        await waitUntil { model.macInputSurfacePolicy.admitsInput }
        lifecycle.drawableSize = .zero
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)

        model.settings.input.preferRelativeMouseMode = true
        model.exitMacRelativePointerCapture()
        XCTAssertFalse(model.settings.input.preferRelativeMouseMode)

        await model.stopStream()
        await launchTask.value
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)
    }

    func testDefaultInputKeyGenerationUsesFreshMaterialForEveryLaunch() async throws {
        let firstKey = RemoteInputKeyMaterial(keyID: 1, key: Data(repeating: 0x11, count: 16))
        let secondKey = RemoteInputKeyMaterial(keyID: 2, key: Data(repeating: 0x22, count: 16))
        let keyGenerator = ScriptedInputKeyGenerator(results: [.success(firstKey), .success(secondKey)])
        let provider = ControlledSessionControlProvider(automaticallyCompletes: true)
        let launchClient = StubStreamLaunchClient()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: launchClient,
            remoteInputKeyGenerator: keyGenerator
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        await model.launchSelectedApp()
        await model.launchSelectedApp()

        XCTAssertEqual(provider.currentStartRecords().map(\.request.remoteInputKey), [
            firstKey,
            secondKey
        ])
        XCTAssertEqual(keyGenerator.currentGenerationCount(), 2)
        let launchCount = await launchClient.currentLaunchCount()
        XCTAssertEqual(launchCount, 0)
    }

    func testInputKeyGenerationFailureStopsBeforeNetworkLaunch() async throws {
        let keyGenerator = ScriptedInputKeyGenerator(results: [.failure(InputKeyGeneratorTestError.failed)])
        let provider = ControlledSessionControlProvider()
        let launchClient = StubStreamLaunchClient()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: launchClient,
            remoteInputKeyGenerator: keyGenerator
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        await model.launchSelectedApp()

        XCTAssertEqual(provider.currentStartRecords().count, 0)
        let launchCount = await launchClient.currentLaunchCount()
        XCTAssertEqual(launchCount, 0)
        XCTAssertEqual(keyGenerator.currentGenerationCount(), 1)
        guard case .failed = model.session.phase else {
            return XCTFail("Input-key generation failure must fail the session before launch.")
        }
        XCTAssertEqual(
            model.streamLaunchUI.errorMessage,
            "Remote input is no longer available for this session."
        )
        XCTAssertEqual(model.diagnostics.latestActionableEvent?.category, .input)
        XCTAssertEqual(model.diagnostics.latestActionableEvent?.code, "invalidInputKey")
        XCTAssertEqual(model.streamLaunchUI.actionMessage, ApplicationDiagnosticAction.reconnectInput.label)
        XCTAssertEqual(model.renderState.policy, .idle)
    }

    func testParameterPreparationFailureIsVisibleWithoutStartingProvider() async throws {
        let provider = ControlledSessionControlProvider()
        let launchClient = StubStreamLaunchClient()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: launchClient,
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 13,
                    key: Data(repeating: 0xF1, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        model.settings.stream.width = 0
        await model.launchSelectedApp()

        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertFalse(model.streamLaunchUI.isLaunching)
        XCTAssertNil(model.session.activeHostID)
        guard case .failed = model.session.phase else {
            return XCTFail("Parameter preparation failure must be visible to the application.")
        }
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertEqual(provider.currentStartRecords().count, 0)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [])
        let launchCount = await launchClient.currentLaunchCount()
        XCTAssertEqual(launchCount, 0)
    }

    private func makeLaunchReadyModel(
        sessionControlProvider: any SessionControlProvider,
        sessionMediaEnvironment: any SessionMediaEnvironment =
            ControlledSessionMediaEnvironment(),
        launchClient: StubStreamLaunchClient,
        remoteInputKeyGenerator: any RemoteInputKeyMaterialGenerating,
        runtimeProviders: RuntimeProviderInventory? = nil
    ) -> AppModel {
        let host = MoonlightHost(
            id: UUID(uuidString: "45F0C9CB-D795-49B2-A733-F68397632233")!,
            name: "Test Host",
            address: "moon.local",
            pairingState: .paired,
            reachability: .online,
            pinnedIdentity: PinnedHostIdentity(
                certificateSHA256: "existing-cert",
                serverCertificateDER: Data([1, 2, 3]),
                pairedAt: Date(timeIntervalSince1970: 10)
            )
        )
        return AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(hosts: [host]),
                serverInfoClient: StubServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: StubAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(launchClient: launchClient),
            runtimeProviders: runtimeProviders ?? completeStreamProviderInventory(
                sessionControlProvider: sessionControlProvider
            ),
            sessionMediaEnvironment: sessionMediaEnvironment,
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientUniqueID: "test-client",
            remoteInputKeyGenerator: remoteInputKeyGenerator
        )
    }

    private func makePlatformLifecycle(
        isStreamActive: Bool,
        isVisible: Bool,
        isFocused: Bool,
        drawableSize: PixelSize
    ) -> PlatformLifecycleState {
        let lifecycle = PlatformLifecycleState()
        lifecycle.isStreamActive = isStreamActive
        lifecycle.isVisible = isVisible
        lifecycle.isFocused = isFocused
        lifecycle.drawableSize = drawableSize
        lifecycle.updateRenderPolicy()
        return lifecycle
    }

    private func makePairingModel(
        host: MoonlightHost,
        provider: ControlledPairingProvider,
        identityProvisioner: any ClientIdentityProvisioning
    ) -> AppModel {
        AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(hosts: [host]),
                serverInfoClient: StubServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: StubAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(launchClient: StubStreamLaunchClient()),
            runtimeProviders: RuntimeProviderInventory(pairing: provider),
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientIdentityProvisioner: identityProvisioner,
            clientUniqueID: "test-client"
        )
    }

    private func waitForSessionStart(
        _ provider: ControlledSessionControlProvider
    ) async throws -> ControlledSessionControlProvider.StartRecord {
        for _ in 0..<100 where provider.currentStartRecords().isEmpty {
            await Task.yield()
        }
        return try XCTUnwrap(provider.currentStartRecords().last)
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting for application session state.")
    }

    private func driveSessionToStreaming(
        _ provider: ControlledSessionControlProvider,
        record: ControlledSessionControlProvider.StartRecord
    ) {
        provider.yield(.launchAccepted(makeSessionLaunchResponse()), sessionID: record.sessionID)
        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey
            )),
            sessionID: record.sessionID
        )
        provider.yield(.channelsReady(.all), sessionID: record.sessionID)
    }

    private func makeSessionLaunchResponse() -> StreamLaunchResponse {
        StreamLaunchResponse(
            sessionURL: "rtsp://example.invalid/session",
            gameSessionID: "session-1",
            rawValues: [:]
        )
    }

    private func makeSessionConfiguration(
        sessionID: UUID,
        keyMaterial: RemoteInputKeyMaterial
    ) -> NegotiatedSessionConfiguration {
        NegotiatedSessionConfiguration(
            sessionID: sessionID,
            controlEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 47_999,
                transport: .udp
            ),
            videoEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 48_000,
                transport: .udp
            ),
            audioEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 48_010,
                transport: .udp
            ),
            inputEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 35_043,
                transport: .tcp
            ),
            video: NegotiatedVideoStreamConfiguration(
                codec: .hevc,
                width: 3_840,
                height: 2_160,
                frameRate: 60,
                colorMetadata: .rec709VideoRange(),
                maximumPacketSize: 1_400
            ),
            audio: NegotiatedAudioStreamConfiguration(
                sampleRate: 48_000,
                channelCount: 2,
                streamCount: 1,
                coupledStreamCount: 1,
                samplesPerFrame: 240,
                channelMapping: [0, 1],
                maximumPacketSize: 1_400
            ),
            input: NegotiatedInputConfiguration(
                keyMaterial: keyMaterial,
                encrypted: true,
                maximumMessageSize: RemoteInputWireCodec.maximumPacketSize
            ),
            requiredChannels: .all
        )
    }

    private func makeUnpairedHost() -> MoonlightHost {
        MoonlightHost(
            id: UUID(uuidString: "C8A319F8-E79F-4F57-AC18-7663D52F1EF8")!,
            name: "Pairing Host",
            address: "moon.local",
            pairingState: .unpaired,
            reachability: .online
        )
    }

    private func makePairingIdentity() -> ClientIdentityMaterial {
        ClientIdentityMaterial(
            id: UUID(uuidString: "09047262-05A7-43F2-A907-BD301920DA0D")!,
            certificateDER: Data([0x30, 0x01]),
            privateKeyDER: Data([0x02, 0x01]),
            createdAt: Date(timeIntervalSince1970: 100)
        )
    }

    private func completeStreamProviderInventory(
        sessionControlProvider: (any SessionControlProvider)? = nil
    ) -> RuntimeProviderInventory {
        let production = ProductionRuntimeProviderFactory.makeDefault()
        return RuntimeProviderInventory(
            pairing: production.pairing,
            sessionControl: sessionControlProvider ?? production.sessionControl,
            videoReceive: AvailabilityVideoReceiveProvider(),
            audioReceive: AvailabilityAudioReceiveProvider(),
            remoteInput: production.remoteInput
        )
    }
}

private enum MissingStreamProvider: String, CaseIterable {
    case sessionControl
    case videoReceive
    case audioReceive
    case remoteInput
}

private struct StubServerInfoClient: ServerInfoClient {
    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        ServerInfo(
            name: "Test Host",
            uniqueID: "host-1",
            macAddress: nil,
            state: "ONLINE",
            supportsHDR: true,
            rawValues: [:]
        )
    }
}

private struct StubAppListClient: AppListClient {
    func fetchApps(from endpoint: HostEndpoint, clientUniqueID: String, pinnedIdentity: PinnedHostIdentity?) async throws -> [RemoteApp] {
        [
            RemoteApp(id: "2", name: "Game", supportsHDR: true, installPath: nil),
            RemoteApp(id: "1", name: "Desktop", supportsHDR: false, installPath: nil)
        ]
    }

    func fetchArtwork(for app: RemoteApp, from endpoint: HostEndpoint, clientUniqueID: String, pinnedIdentity: PinnedHostIdentity?) async throws -> RemoteAppArtwork? {
        nil
    }
}

private actor StubStreamLaunchClient: StreamLaunchClient {
    private var launchCount = 0
    private var launchedKeys: [RemoteInputKeyMaterial] = []

    func launch(_ request: StreamLaunchRequest, parameters: StreamNegotiationParameters) async throws -> StreamLaunchResponse {
        launchCount += 1
        launchedKeys.append(request.remoteInputKey)
        return StreamLaunchResponse(
            sessionURL: "rtsp://test/session",
            gameSessionID: "session-1",
            rawValues: ["sessionurl": "rtsp://test/session"]
        )
    }

    func resume(_ request: StreamLaunchRequest, parameters: StreamNegotiationParameters) async throws -> StreamLaunchResponse {
        StreamLaunchResponse(
            sessionURL: "rtsp://test/session",
            gameSessionID: nil,
            rawValues: ["resume": "1"]
        )
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {
    }

    func currentLaunchCount() -> Int {
        launchCount
    }

    func currentLaunchedKeys() -> [RemoteInputKeyMaterial] {
        launchedKeys
    }
}

private final class ScriptedInputKeyGenerator: RemoteInputKeyMaterialGenerating, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<RemoteInputKeyMaterial, Error>]
    private var generationCount = 0

    init(results: [Result<RemoteInputKeyMaterial, Error>]) {
        self.results = results
    }

    func generate() throws -> RemoteInputKeyMaterial {
        lock.lock()
        defer { lock.unlock() }
        generationCount += 1
        guard !results.isEmpty else {
            throw InputKeyGeneratorTestError.exhausted
        }
        return try results.removeFirst().get()
    }

    func currentGenerationCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return generationCount
    }
}

private enum InputKeyGeneratorTestError: Error {
    case failed
    case exhausted
}

private enum MediaEnvironmentApplicationTestError: Error {
    case failed
}

private struct AvailabilityVideoReceiveProvider: VideoReceiveProvider {
    func receiveVideo(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedVideoStreamConfiguration
    ) async -> AsyncThrowingStream<VideoReceiveEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func stopVideo(sessionID: UUID) async {
    }
}

private struct AvailabilityAudioReceiveProvider: AudioReceiveProvider {
    func receiveAudio(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedAudioStreamConfiguration
    ) async -> AsyncThrowingStream<AudioReceiveEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func stopAudio(sessionID: UUID) async {
    }
}

private struct FixedIdentityProvisioner: ClientIdentityProvisioning {
    let identity: ClientIdentityMaterial

    func loadOrCreateIdentity(createdAt: Date) async throws -> ClientIdentityMaterial {
        identity
    }
}

private struct FailingIdentityProvisioner: ClientIdentityProvisioning {
    func loadOrCreateIdentity(createdAt: Date) async throws -> ClientIdentityMaterial {
        throw PairingTestError.identityFailure
    }
}

private actor ControlledIdentityProvisioner: ClientIdentityProvisioning {
    private var started = false
    private var continuation: CheckedContinuation<ClientIdentityMaterial, Never>?

    func loadOrCreateIdentity(createdAt: Date) async throws -> ClientIdentityMaterial {
        started = true
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func hasStarted() -> Bool {
        started
    }

    func complete(with identity: ClientIdentityMaterial) {
        continuation?.resume(returning: identity)
        continuation = nil
    }
}

private enum PairingTestError: Error {
    case identityFailure
}

private final class ControlledSessionControlProvider: SessionControlProvider, @unchecked Sendable {
    struct StartRecord {
        var sessionID: UUID
        var request: StreamLaunchRequest
    }

    enum Ending: CaseIterable {
        case incomplete
        case failure
    }

    private typealias Continuation = AsyncThrowingStream<
        SessionControlEvent,
        Error
    >.Continuation

    private let lock = NSLock()
    private let automaticallyCompletes: Bool
    private var startRecords: [StartRecord] = []
    private var continuations: [UUID: Continuation] = [:]
    private var stoppedSessionIDs: [UUID] = []

    init(automaticallyCompletes: Bool = false) {
        self.automaticallyCompletes = automaticallyCompletes
    }

    func start(
        sessionID: UUID,
        request: StreamLaunchRequest
    ) async -> AsyncThrowingStream<SessionControlEvent, Error> {
        AsyncThrowingStream { continuation in
            withLock {
                startRecords.append(StartRecord(sessionID: sessionID, request: request))
                continuations[sessionID] = continuation
            }
            guard automaticallyCompletes else { return }
            continuation.yield(.launchAccepted(StreamLaunchResponse(
                sessionURL: "rtsp://example.invalid/session",
                gameSessionID: "session-1",
                rawValues: [:]
            )))
            continuation.yield(.rtspReady)
            continuation.yield(.negotiated(Self.configuration(
                sessionID: sessionID,
                keyMaterial: request.remoteInputKey
            )))
            continuation.yield(.channelsReady(.all))
            continuation.yield(.terminated(reason: nil))
            _ = withLock {
                continuations.removeValue(forKey: sessionID)
            }
            continuation.finish()
        }
    }

    func requestIDR(sessionID: UUID) async throws {
        _ = sessionID
    }

    func stop(sessionID: UUID) async {
        let continuation = withLock {
            stoppedSessionIDs.append(sessionID)
            return continuations.removeValue(forKey: sessionID)
        }
        continuation?.finish()
    }

    func yield(_ event: SessionControlEvent, sessionID: UUID) {
        continuation(for: sessionID)?.yield(event)
    }

    func finish(
        sessionID: UUID,
        ending: Ending = .incomplete
    ) {
        let continuation = withLock {
            continuations.removeValue(forKey: sessionID)
        }
        switch ending {
        case .incomplete:
            continuation?.finish()
        case .failure:
            continuation?.finish(throwing: StreamNegotiationFailure(
                code: .transportUnavailable,
                subsystem: "session.control",
                message: "Session control failed."
            ))
        }
    }

    func currentStartRecords() -> [StartRecord] {
        withLock { startRecords }
    }

    func currentStoppedSessionIDs() -> [UUID] {
        withLock { stoppedSessionIDs }
    }

    private func continuation(for sessionID: UUID) -> Continuation? {
        withLock { continuations[sessionID] }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }

    private static func configuration(
        sessionID: UUID,
        keyMaterial: RemoteInputKeyMaterial
    ) -> NegotiatedSessionConfiguration {
        NegotiatedSessionConfiguration(
            sessionID: sessionID,
            controlEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 47_999,
                transport: .udp
            ),
            videoEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 48_000,
                transport: .udp
            ),
            audioEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 48_010,
                transport: .udp
            ),
            inputEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 35_043,
                transport: .tcp
            ),
            video: NegotiatedVideoStreamConfiguration(
                codec: .hevc,
                width: 3_840,
                height: 2_160,
                frameRate: 60,
                colorMetadata: .rec709VideoRange(),
                maximumPacketSize: 1_400
            ),
            audio: NegotiatedAudioStreamConfiguration(
                sampleRate: 48_000,
                channelCount: 2,
                streamCount: 1,
                coupledStreamCount: 1,
                samplesPerFrame: 240,
                channelMapping: [0, 1],
                maximumPacketSize: 1_400
            ),
            input: NegotiatedInputConfiguration(
                keyMaterial: keyMaterial,
                encrypted: true,
                maximumMessageSize: RemoteInputWireCodec.maximumPacketSize
            ),
            requiredChannels: .all
        )
    }
}

private final class ControlledSessionMediaEnvironment: SessionMediaEnvironment, @unchecked Sendable {
    struct StartRecord {
        var sessionID: UUID
        var configuration: NegotiatedSessionConfiguration
    }

    private typealias Continuation = AsyncThrowingStream<
        SessionMediaEnvironmentEvent,
        Error
    >.Continuation

    private let lock = NSLock()
    private let automaticallyReady: Bool
    private let failsLifecycleApplication: Bool
    private var startRecords: [StartRecord] = []
    private var stoppedSessionIDs: [UUID] = []
    private var continuations: [UUID: Continuation] = [:]
    private var sentInputApplications: [SessionInputApplication] = []
    private var releasedInputApplications: [SessionInputReleaseApplication] = []
    private var lifecycleApplications: [SessionLifecycleApplication] = []
    private var shouldBlockNextRelease = false
    private var blockedReleaseContinuation: CheckedContinuation<Void, Never>?

    init(
        automaticallyReady: Bool = true,
        failsLifecycleApplication: Bool = false
    ) {
        self.automaticallyReady = automaticallyReady
        self.failsLifecycleApplication = failsLifecycleApplication
    }

    func start(
        sessionID: UUID,
        configuration: NegotiatedSessionConfiguration,
        controlProvider: any SessionControlProvider
    ) async throws -> AsyncThrowingStream<SessionMediaEnvironmentEvent, Error> {
        _ = controlProvider
        let pair = AsyncThrowingStream<SessionMediaEnvironmentEvent, Error>.makeStream()
        withLock {
            startRecords.append(StartRecord(
                sessionID: sessionID,
                configuration: configuration
            ))
            continuations[sessionID] = pair.continuation
        }
        if automaticallyReady {
            pair.continuation.yield(.readiness([.video, .audio, .input]))
        }
        return pair.stream
    }

    func updateVideoColorMetadata(
        _ metadata: VideoColorMetadata,
        sessionID: UUID
    ) async throws {
        _ = metadata
        _ = sessionID
    }

    func applyLifecycle(_ application: SessionLifecycleApplication) async throws {
        let state = withLock {
            (
                continuations[application.sessionID] != nil,
                UInt64(startRecords.count),
                lifecycleApplications.last
            )
        }
        guard state.0 else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard application.mediaGeneration == state.1 else {
            throw SessionMediaEnvironmentError.staleLifecycleApplication
        }
        if failsLifecycleApplication {
            throw MediaEnvironmentApplicationTestError.failed
        }
        if let previous = state.2,
           previous.sessionID == application.sessionID,
           previous.mediaGeneration == application.mediaGeneration {
            if previous == application { return }
            guard application.lifecycleRevision > previous.lifecycleRevision else {
                throw SessionMediaEnvironmentError.staleLifecycleApplication
            }
        }
        withLock { lifecycleApplications.append(application) }
    }

    func sendInput(_ application: SessionInputApplication) async throws {
        let currentGeneration = withLock { UInt64(startRecords.count) }
        guard continuation(for: application.sessionID) != nil else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard application.mediaGeneration == currentGeneration else {
            throw SessionMediaEnvironmentError.staleInputApplication
        }
        withLock { sentInputApplications.append(application) }
    }

    func releaseInput(_ application: SessionInputReleaseApplication) async throws {
        try validateRelease(application)
        let shouldBlock = withLock {
            let value = shouldBlockNextRelease
            shouldBlockNextRelease = false
            releasedInputApplications.append(application)
            return value
        }
        if shouldBlock {
            await withCheckedContinuation { continuation in
                withLock { blockedReleaseContinuation = continuation }
            }
        }
        try validateRelease(application)
    }

    func stop(sessionID: UUID) async -> SessionTeardownReport? {
        let continuation = withLock {
            stoppedSessionIDs.append(sessionID)
            return continuations.removeValue(forKey: sessionID)
        }
        continuation?.finish()
        return SessionTeardownReport(
            cancelledTaskCount: 0,
            stoppedResourceCount: 3,
            unfinishedTasks: [],
            taskOutcomes: [:]
        )
    }

    func snapshot() async -> SessionMediaEnvironmentSnapshot {
        let state = withLock {
            (
                startRecords.last?.sessionID,
                startRecords.count,
                continuations.isEmpty,
                lifecycleApplications.last
            )
        }
        return SessionMediaEnvironmentSnapshot(
            sessionID: state.2 ? nil : state.0,
            generation: UInt64(state.1),
            readiness: state.2 ? [] : [.video, .audio, .input],
            resourcePhase: state.2 ? nil : .active,
            activeTaskCount: 0,
            activeResourceCount: state.2 ? 0 : 3,
            lastTeardownReport: nil,
            lifecycleApplication: state.3
        )
    }

    func yieldReadiness(
        _ readiness: SessionChannelReadiness,
        sessionID: UUID
    ) {
        continuation(for: sessionID)?.yield(.readiness(readiness))
    }

    func yieldFeedback(_ feedback: RemoteInputFeedback, sessionID: UUID) {
        continuation(for: sessionID)?.yield(.feedback(feedback))
    }

    func finish(sessionID: UUID, throwing error: Error) {
        let continuation = withLock { continuations.removeValue(forKey: sessionID) }
        continuation?.finish(throwing: error)
    }

    func currentStartRecords() -> [StartRecord] {
        withLock { startRecords }
    }

    func currentStoppedSessionIDs() -> [UUID] {
        withLock { stoppedSessionIDs }
    }

    func currentSentInputApplications() -> [SessionInputApplication] {
        withLock { sentInputApplications }
    }

    func currentReleasedInputApplications() -> [SessionInputReleaseApplication] {
        withLock { releasedInputApplications }
    }

    func currentLifecycleApplications() -> [SessionLifecycleApplication] {
        withLock { lifecycleApplications }
    }

    func blockNextRelease() {
        withLock { shouldBlockNextRelease = true }
    }

    func hasBlockedRelease() -> Bool {
        withLock { blockedReleaseContinuation != nil }
    }

    func resumeBlockedRelease() {
        let continuation = withLock {
            let value = blockedReleaseContinuation
            blockedReleaseContinuation = nil
            return value
        }
        continuation?.resume()
    }

    private func validateRelease(
        _ application: SessionInputReleaseApplication
    ) throws {
        let state = withLock {
            (continuations[application.sessionID] != nil, UInt64(startRecords.count))
        }
        guard state.0 else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard application.mediaGeneration == state.1 else {
            throw SessionMediaEnvironmentError.staleInputApplication
        }
    }

    private func continuation(for sessionID: UUID) -> Continuation? {
        withLock { continuations[sessionID] }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class BlockingSessionMediaEnvironment: SessionMediaEnvironment, @unchecked Sendable {
    private let lock = NSLock()
    private var started = false
    private var startContinuation: CheckedContinuation<
        AsyncThrowingStream<SessionMediaEnvironmentEvent, Error>,
        Never
    >?
    private var stoppedSessionIDs: [UUID] = []

    func start(
        sessionID: UUID,
        configuration: NegotiatedSessionConfiguration,
        controlProvider: any SessionControlProvider
    ) async throws -> AsyncThrowingStream<SessionMediaEnvironmentEvent, Error> {
        _ = sessionID
        _ = configuration
        _ = controlProvider
        setStarted()
        return await withCheckedContinuation { continuation in
            withLock { startContinuation = continuation }
        }
    }

    func updateVideoColorMetadata(
        _ metadata: VideoColorMetadata,
        sessionID: UUID
    ) async throws {
        _ = metadata
        _ = sessionID
    }

    func applyLifecycle(_ application: SessionLifecycleApplication) async throws {
        _ = application
    }

    func sendInput(_ application: SessionInputApplication) async throws {
        _ = application
    }

    func releaseInput(_ application: SessionInputReleaseApplication) async throws {
        _ = application
    }

    func stop(sessionID: UUID) async -> SessionTeardownReport? {
        withLock { stoppedSessionIDs.append(sessionID) }
        return SessionTeardownReport(
            cancelledTaskCount: 0,
            stoppedResourceCount: 0,
            unfinishedTasks: [],
            taskOutcomes: [:]
        )
    }

    func snapshot() async -> SessionMediaEnvironmentSnapshot {
        SessionMediaEnvironmentSnapshot(
            sessionID: nil,
            generation: 0,
            readiness: [],
            resourcePhase: nil,
            activeTaskCount: 0,
            activeResourceCount: 0,
            lastTeardownReport: nil
        )
    }

    func hasStarted() -> Bool {
        withLock { started }
    }

    func completeStart() {
        let continuation = withLock { () -> CheckedContinuation<
            AsyncThrowingStream<SessionMediaEnvironmentEvent, Error>,
            Never
        >? in
            defer { startContinuation = nil }
            return startContinuation
        }
        let stream = AsyncThrowingStream<SessionMediaEnvironmentEvent, Error> { continuation in
            continuation.yield(.readiness([.video, .audio, .input]))
        }
        continuation?.resume(returning: stream)
    }

    func currentStoppedSessionIDs() -> [UUID] {
        withLock { stoppedSessionIDs }
    }

    private func setStarted() {
        withLock { started = true }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ControlledPairingProvider: PairingRuntimeProvider, @unchecked Sendable {
    enum Completion {
        case invalid
        case incomplete
    }

    private typealias Continuation = AsyncThrowingStream<PairingRuntimeEvent, Error>.Continuation
    private let lock = NSLock()
    private var requests: [PairingRuntimeRequest] = []
    private var continuations: [UUID: Continuation] = [:]
    private var cancelledAttemptIDs: [UUID] = []

    func pair(
        _ request: PairingRuntimeRequest
    ) async -> AsyncThrowingStream<PairingRuntimeEvent, Error> {
        AsyncThrowingStream { continuation in
            lock.lock()
            requests.append(request)
            continuations[request.attemptID] = continuation
            lock.unlock()
        }
    }

    func cancelPairing(attemptID: UUID) async {
        withLock {
            cancelledAttemptIDs.append(attemptID)
        }
    }

    func currentRequestCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return requests.count
    }

    func latestRequest() -> PairingRuntimeRequest? {
        lock.lock()
        defer { lock.unlock() }
        return requests.last
    }

    func currentCancelledAttemptIDs() -> [UUID] {
        lock.lock()
        defer { lock.unlock() }
        return cancelledAttemptIDs
    }

    func yieldProgress(
        _ stage: PairingStage,
        for request: PairingRuntimeRequest,
        attemptID: UUID? = nil,
        hostID: UUID? = nil
    ) {
        let continuation = continuation(for: request.attemptID)
        continuation?.yield(.progress(PairingSnapshot(
            attemptID: attemptID ?? request.attemptID,
            hostID: hostID ?? request.host.id,
            stage: stage,
            digestAlgorithm: .sha256,
            failure: nil,
            updatedAt: Date(timeIntervalSince1970: 200)
        )))
    }

    func yieldFailure(
        _ failure: PairingFailure,
        for request: PairingRuntimeRequest
    ) {
        continuation(for: request.attemptID)?.yield(.progress(PairingSnapshot(
            attemptID: request.attemptID,
            hostID: request.host.id,
            stage: .failed,
            digestAlgorithm: .sha256,
            failure: failure,
            updatedAt: Date(timeIntervalSince1970: 201)
        )))
    }

    func completeAuthenticated(_ request: PairingRuntimeRequest) {
        let continuation = removeContinuation(for: request.attemptID)
        continuation?.yield(.completed(authenticatedResult(for: request)))
        continuation?.finish()
    }

    func finish(_ request: PairingRuntimeRequest, completion: Completion) {
        let continuation = removeContinuation(for: request.attemptID)
        switch completion {
        case .invalid:
            var result = authenticatedResult(for: request)
            result.host.pinnedIdentity = nil
            continuation?.yield(.completed(result))
        case .incomplete:
            break
        }
        continuation?.finish()
    }

    private func continuation(for attemptID: UUID) -> Continuation? {
        lock.lock()
        defer { lock.unlock() }
        return continuations[attemptID]
    }

    private func removeContinuation(for attemptID: UUID) -> Continuation? {
        lock.lock()
        defer { lock.unlock() }
        return continuations.removeValue(forKey: attemptID)
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }

    private func authenticatedResult(for request: PairingRuntimeRequest) -> PairingResult {
        let certificate = Data([0x30, 0x01, 0x02])
        let fingerprint = "verified-certificate"
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
