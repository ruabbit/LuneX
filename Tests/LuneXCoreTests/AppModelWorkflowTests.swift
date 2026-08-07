@preconcurrency import CoreVideo
@preconcurrency import Metal
import MetalKit
import QuartzCore
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
        lifecycle.updateSurface(
            displayID: "display-a",
            headroom: DisplayHeadroom(potential: 2.0, current: 1.5, reference: 1.0),
            drawableSize: PixelSize(width: 2560, height: 1440)
        )
        model.renderState.transform.sourceSize = PixelSize(width: 1920, height: 1080)

        model.applyPlatformLifecycle(lifecycle)

        XCTAssertEqual(model.renderState.policy, .throttled(reason: "Window or scene not focused"))
        XCTAssertEqual(model.renderState.transform.drawableSize, PixelSize(width: 2560, height: 1440))
        XCTAssertEqual(model.renderState.coordinateSnapshot?.drawableSize, PixelSize(width: 2560, height: 1440))
        XCTAssertEqual(model.renderState.headroom, lifecycle.headroom)
    }

    func testRenderPreferencesDoNotSynthesizeDisplayHeadroomWithoutLifecycle() {
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
            streamSessionCoordinator: StreamSessionCoordinator(
                launchClient: StubStreamLaunchClient()
            ),
            clientIdentityStore: InMemoryClientIdentityStore()
        )

        XCTAssertTrue(model.settings.stream.hdrEnabled)
        XCTAssertEqual(model.renderState.headroom, DisplayHeadroom())
        XCTAssertNil(model.renderState.displaySnapshot)

        model.settings.stream.hdrEnabled = false
        XCTAssertEqual(model.renderState.headroom, DisplayHeadroom())
        XCTAssertNil(model.renderState.displaySnapshot)

        model.settings.stream.hdrEnabled = true
        XCTAssertEqual(model.renderState.headroom, DisplayHeadroom())
        XCTAssertNil(model.renderState.displaySnapshot)
    }

    func testHDRDiagnosticsDeduplicateAndClearOnlyHDRActionOnRecovery() {
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
            streamSessionCoordinator: StreamSessionCoordinator(
                launchClient: StubStreamLaunchClient()
            ),
            clientIdentityStore: InMemoryClientIdentityStore()
        )
        model.diagnostics.record(
            ApplicationDiagnosticFactory.streamFailure(VideoDecoderError.noActiveSession)
        )

        model.publishHDRPresentationDiagnostic(.pipelineFailure)
        model.publishHDRPresentationDiagnostic(.pipelineFailure)
        XCTAssertEqual(
            model.diagnostics.events.filter {
                $0.code == "hdr_pipeline_failure"
            }.count,
            1
        )
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.category,
            .hdr
        )

        model.publishHDRPresentationDiagnostic(.activeEDR)
        model.publishHDRPresentationDiagnostic(.activeEDR)
        XCTAssertEqual(
            model.diagnostics.events.filter { $0.code == "hdr_active_edr" }.count,
            1
        )
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.category,
            .decoder
        )
        XCTAssertTrue(model.diagnostics.events.contains {
            $0.code == "hdr_pipeline_failure"
        })

        model.publishHDRPresentationDiagnostic(
            .sdrFallback(.platformOutputUnsupported(.macOS))
        )
        model.publishHDRPresentationDiagnostic(
            .sdrFallback(.platformOutputUnsupported(.macOS))
        )
        XCTAssertEqual(
            model.diagnostics.events.filter {
                $0.code == "hdr_sdr_fallback_unsupported_output"
            }.count,
            1
        )
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.category,
            .hdr
        )

        model.publishHDRPresentationDiagnostic(.inactive)
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.category,
            .decoder
        )
        XCTAssertEqual(model.diagnostics.events.count, 4)
    }

    func testHDRDiagnosticOwnershipRejectsStalePresenterAfterReplacement() {
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
            streamSessionCoordinator: StreamSessionCoordinator(
                launchClient: StubStreamLaunchClient()
            ),
            clientIdentityStore: InMemoryClientIdentityStore()
        )
        let oldOwner = UUID()
        let replacementOwner = UUID()

        model.claimHDRPresentationDiagnosticOwnership(oldOwner)
        model.publishHDRPresentationDiagnostic(.activeEDR, ownerID: oldOwner)
        model.claimHDRPresentationDiagnosticOwnership(replacementOwner)
        model.publishHDRPresentationDiagnostic(.activeSDR, ownerID: replacementOwner)

        model.publishHDRPresentationDiagnostic(.pipelineFailure, ownerID: oldOwner)
        model.publishHDRPresentationDiagnostic(.inactive, ownerID: oldOwner)
        model.releaseHDRPresentationDiagnosticOwnership(oldOwner)
        model.publishHDRPresentationDiagnostic(.pipelineFailure, ownerID: oldOwner)

        XCTAssertEqual(
            model.diagnostics.events.map(\.code),
            ["hdr_active_edr", "hdr_active_sdr"]
        )
        XCTAssertNil(model.diagnostics.latestStreamActionableEvent)

        model.publishHDRPresentationDiagnostic(
            .pipelineFailure,
            ownerID: replacementOwner
        )
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.code,
            "hdr_pipeline_failure"
        )
        model.publishHDRPresentationDiagnostic(.inactive, ownerID: replacementOwner)
        model.releaseHDRPresentationDiagnosticOwnership(replacementOwner)
        XCTAssertNil(model.diagnostics.latestStreamActionableEvent)
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
        lifecycle.updateSurface(
            displayID: "display-a",
            headroom: DisplayHeadroom(
                potential: 2.4,
                current: 1.8,
                reference: 1.0
            ),
            drawableSize: lifecycle.drawableSize
        )
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

    func testHDREligibilityWaitsForStreamingVideoReadiness() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(
            automaticallyReady: false
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 39,
                    key: Data(repeating: 0x39, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()

        let drawableSize = PixelSize(width: 3_840, height: 2_160)
        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: drawableSize
        )
        _ = lifecycle.updateSurface(
            displayID: "display-a",
            headroom: DisplayHeadroom(
                potential: 4,
                current: 2.5,
                reference: 1
            ),
            drawableSize: drawableSize
        )
        model.applyPlatformLifecycle(lifecycle)

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        let hdrMetadata = VideoColorMetadata.hdr10VideoRange()
        provider.yield(
            .launchAccepted(makeSessionLaunchResponse()),
            sessionID: record.sessionID
        )
        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey,
                videoColorMetadata: hdrMetadata
            )),
            sessionID: record.sessionID
        )
        provider.yield(.channelsReady(.all), sessionID: record.sessionID)
        await waitUntil { mediaEnvironment.currentStartRecords().count == 1 }

        let hdrLayout = HDRDecodedPixelBufferLayout(
            pixelFormat: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
            width: 3_840,
            height: 2_160,
            planes: [
                HDRDecodedPlaneDimensions(width: 3_840, height: 2_160),
                HDRDecodedPlaneDimensions(width: 1_920, height: 1_080)
            ]
        )
        mediaEnvironment.yieldVideoPresentation(
            .decoderStarted(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 1
                ),
                contract: StreamVideoDecoderPresentationContract(
                    decoderGeneration: 1,
                    colorMetadata: hdrMetadata
                )
            ),
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldVideoPresentation(
            .decodedFrame(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 2
                ),
                contract: StreamVideoDecodedPresentationContract(
                    decoderGeneration: 1,
                    colorMetadata: hdrMetadata,
                    decodedLayout: hdrLayout
                )
            ),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.decodedVideoPresentationContract != nil
        }
        XCTAssertFalse(model.session.isStreaming)
        XCTAssertEqual(
            model.renderState.hdrRenderResolution,
            .closed(.inactiveSession)
        )

        mediaEnvironment.yieldReadiness(
            [.video, .audio, .input],
            sessionID: record.sessionID
        )
        await waitUntil { model.session.isStreaming }
        await waitUntil {
            model.renderState.hdrRenderResolution.configuration?.outputMode == .edr
        }

        mediaEnvironment.yieldReadiness(
            [.audio, .input],
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.hdrRenderResolution == .closed(.inactiveSession)
        }
        await waitUntil { model.session.phase.label.contains("Reconnecting") }

        await model.stopStream()
        await launchTask.value
    }

    func testHDRApplicationIntegrationCoversPresentationRevisionsStaleFramesAndCleanStop()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 38,
                    key: Data(repeating: 0x38, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()

        let drawableSize = PixelSize(width: 64, height: 64)
        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: drawableSize
        )
        _ = lifecycle.updateSurface(
            displayID: "display-a",
            headroom: DisplayHeadroom(
                potential: 4,
                current: 2.5,
                reference: 1
            ),
            drawableSize: drawableSize
        )
        model.applyPlatformLifecycle(lifecycle)

        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(
            frame: CGRect(x: 0, y: 0, width: 64, height: 64),
            device: device
        )
        let drawableLayer = CAMetalLayer()
        drawableLayer.device = device
        drawableLayer.pixelFormat = .bgra8Unorm_srgb
        drawableLayer.drawableSize = CGSize(width: 64, height: 64)
        let drawable = try XCTUnwrap(drawableLayer.nextDrawable())
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        var presenterRuntimes: [RecordingStreamMetalPresenterRuntime] = []
        let presenter = StreamMetalPresenter(
            presentationSource: model.videoPresentationSource,
            renderState: model.renderState,
            runtimeFactory: { _, _ in
                let runtime = RecordingStreamMetalPresenterRuntime()
                presenterRuntimes.append(runtime)
                return runtime
            },
            surfaceAdapterFactory: { _ in surfaceAdapter },
            drawableProvider: { _ in drawable },
            diagnosticLease: HDRPresentationDiagnosticLease(
                claim: { model.claimHDRPresentationDiagnosticOwnership($0) },
                publish: { ownerID, state in
                    model.publishHDRPresentationDiagnostic(
                        state,
                        ownerID: ownerID
                    )
                },
                release: { model.releaseHDRPresentationDiagnosticOwnership($0) }
            )
        )
        presenter.configure(view)

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        model.videoPresentationSource.beginSession(
            sessionID: record.sessionID,
            mediaGeneration: 1
        )

        let hdrMetadata = VideoColorMetadata.hdr10VideoRange()
        provider.yield(
            .videoColorMetadata(hdrMetadata),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.negotiatedVideoColorMetadata == hdrMetadata
        }
        XCTAssertEqual(
            model.renderState.hdrRenderResolution,
            .closed(.inactiveSession)
        )

        let hdrFrame = try makeHDRApplicationFrame(
            generation: 10,
            frameID: 1,
            metadata: hdrMetadata
        )
        let hdrLayout = HDRDecodedPixelBufferLayout(
            pixelBuffer: hdrFrame.pixelBuffer
        )
        let sdrMetadata = VideoColorMetadata.rec709VideoRange()
        let sdrFrame = try makeHDRApplicationFrame(
            generation: 11,
            frameID: 2,
            metadata: sdrMetadata
        )
        let sdrLayout = HDRDecodedPixelBufferLayout(
            pixelBuffer: sdrFrame.pixelBuffer
        )
        mediaEnvironment.yieldVideoPresentation(
            .decoderStarted(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 1
                ),
                contract: StreamVideoDecoderPresentationContract(
                    decoderGeneration: 10,
                    colorMetadata: hdrMetadata
                )
            ),
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldVideoPresentation(
            .decodedFrame(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 2
                ),
                contract: StreamVideoDecodedPresentationContract(
                    decoderGeneration: 10,
                    colorMetadata: hdrMetadata,
                    decodedLayout: hdrLayout
                )
            ),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.hdrRenderResolution.configuration?
                .identity.decoderGeneration == 10
        }
        let activeEDR = try XCTUnwrap(
            model.renderState.hdrRenderResolution.configuration
        )
        XCTAssertEqual(activeEDR.outputMode, .edr)
        XCTAssertEqual(activeEDR.identity.mappingMode, .hdrEDR)
        XCTAssertEqual(
            activeEDR.identity.displayRevision,
            lifecycle.displayRevision
        )
        model.videoPresentationSource.consume(
            .sessionStarted(generation: 10, colorMetadata: hdrMetadata),
            sessionID: record.sessionID,
            mediaGeneration: 1
        )
        model.videoPresentationSource.consume(
            .frame(hdrFrame),
            sessionID: record.sessionID,
            mediaGeneration: 1
        )
        presenter.update(renderState: model.renderState)
        presenter.draw(in: view)
        presenter.draw(in: view)
        XCTAssertEqual(
            presenter.snapshot().activeConfiguration,
            activeEDR.identity
        )
        XCTAssertEqual(
            surfaceAdapter.activeContract,
            activeEDR.identity.surfaceContract
        )
        XCTAssertEqual(
            presenterRuntimes.last?.presentedConfigurations.last,
            activeEDR.identity
        )
        XCTAssertEqual(
            model.renderState.transform.sourceSize,
            PixelSize(width: 64, height: 64)
        )

        mediaEnvironment.yieldVideoPresentation(
            .decodedFrame(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 3
                ),
                contract: StreamVideoDecodedPresentationContract(
                    decoderGeneration: 10,
                    colorMetadata: sdrMetadata,
                    decodedLayout: sdrLayout
                )
            ),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.hdrRenderResolution == .closed(.staleColorSignature)
        }
        let presentationCountBeforeClosed = presenterRuntimes.reduce(0) {
            $0 + $1.presentCount
        }
        presenter.update(renderState: model.renderState)
        presenter.draw(in: view)
        XCTAssertNil(presenter.snapshot().activeConfiguration)
        XCTAssertEqual(
            presenterRuntimes.reduce(0) { $0 + $1.presentCount },
            presentationCountBeforeClosed
        )
        mediaEnvironment.yieldVideoPresentation(
            .decodedFrame(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 4
                ),
                contract: StreamVideoDecodedPresentationContract(
                    decoderGeneration: 10,
                    colorMetadata: hdrMetadata,
                    decodedLayout: hdrLayout
                )
            ),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.hdrRenderResolution.configuration?.outputMode == .edr
        }
        presenter.update(renderState: model.renderState)
        presenter.draw(in: view)
        presenter.draw(in: view)
        XCTAssertEqual(
            presenterRuntimes.last?.presentedConfigurations.last?.mappingMode,
            .hdrEDR
        )

        _ = lifecycle.updateSurface(
            displayID: "display-a",
            headroom: DisplayHeadroom(
                potential: 4,
                current: 1,
                reference: 1
            ),
            drawableSize: drawableSize
        )
        model.applyPlatformLifecycle(lifecycle)
        let constrained = try XCTUnwrap(
            model.renderState.hdrRenderResolution.configuration
        )
        XCTAssertEqual(
            constrained.outputMode,
            .sdrFallback(.currentHeadroomInsufficient)
        )
        XCTAssertEqual(constrained.identity.mappingMode, .hdrToSDR)
        XCTAssertEqual(
            constrained.identity.displayRevision,
            lifecycle.displayRevision
        )
        presenter.update(renderState: model.renderState)
        presenter.draw(in: view)
        presenter.draw(in: view)
        XCTAssertEqual(
            presenterRuntimes.last?.presentedConfigurations.last?.mappingMode,
            .hdrToSDR
        )
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.code,
            "hdr_sdr_fallback_headroom_insufficient"
        )

        _ = lifecycle.updateSurface(
            displayID: "display-a",
            headroom: DisplayHeadroom(
                potential: 4,
                current: 2.5,
                reference: 1
            ),
            drawableSize: drawableSize
        )
        model.applyPlatformLifecycle(lifecycle)
        let recovered = try XCTUnwrap(
            model.renderState.hdrRenderResolution.configuration
        )
        XCTAssertEqual(recovered.outputMode, .edr)
        presenter.update(renderState: model.renderState)
        presenter.draw(in: view)
        presenter.draw(in: view)
        XCTAssertEqual(
            presenterRuntimes.last?.presentedConfigurations.last,
            recovered.identity
        )
        XCTAssertNil(model.diagnostics.latestStreamActionableEvent)

        model.settings.stream.hdrEnabled = false
        let disabled = try XCTUnwrap(
            model.renderState.hdrRenderResolution.configuration
        )
        XCTAssertEqual(
            disabled.outputMode,
            .sdrFallback(.userPreferenceDisabled)
        )
        model.settings.stream.hdrEnabled = true

        let revisionBeforeDisplayMove = lifecycle.displayRevision
        _ = lifecycle.updateSurface(
            displayID: "display-b",
            headroom: DisplayHeadroom(
                potential: 4,
                current: 2.5,
                reference: 1
            ),
            drawableSize: drawableSize
        )
        model.applyPlatformLifecycle(lifecycle)
        let movedEDR = try XCTUnwrap(
            model.renderState.hdrRenderResolution.configuration
        )
        XCTAssertGreaterThan(
            movedEDR.identity.displayRevision,
            revisionBeforeDisplayMove
        )
        XCTAssertEqual(movedEDR.outputMode, .edr)
        presenter.update(renderState: model.renderState)
        presenter.draw(in: view)
        presenter.draw(in: view)
        XCTAssertEqual(
            presenterRuntimes.last?.presentedConfigurations.last,
            movedEDR.identity
        )

        provider.yield(
            .videoColorMetadata(sdrMetadata),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.negotiatedVideoColorMetadata == sdrMetadata
                && model.renderState.decodedVideoPresentationContract == nil
        }
        XCTAssertEqual(
            model.renderState.hdrRenderResolution,
            .closed(.inactiveSession)
        )

        mediaEnvironment.yieldVideoPresentation(
            .decodedFrame(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 6
                ),
                contract: StreamVideoDecodedPresentationContract(
                    decoderGeneration: 11,
                    colorMetadata: sdrMetadata,
                    decodedLayout: sdrLayout
                )
            ),
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldVideoPresentation(
            .decoderStarted(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 5
                ),
                contract: StreamVideoDecoderPresentationContract(
                    decoderGeneration: 11,
                    colorMetadata: sdrMetadata
                )
            ),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.hdrRenderResolution.configuration?
                .identity.decoderGeneration == 11
        }
        let activeSDR = try XCTUnwrap(
            model.renderState.hdrRenderResolution.configuration
        )
        XCTAssertEqual(activeSDR.outputMode, .sdr)
        XCTAssertEqual(activeSDR.identity.mappingMode, .sdr)
        model.videoPresentationSource.consume(
            .sessionStarted(generation: 11, colorMetadata: sdrMetadata),
            sessionID: record.sessionID,
            mediaGeneration: 1
        )
        model.videoPresentationSource.consume(
            .frame(sdrFrame),
            sessionID: record.sessionID,
            mediaGeneration: 1
        )
        presenter.update(renderState: model.renderState)
        presenter.draw(in: view)
        presenter.draw(in: view)
        XCTAssertEqual(
            presenterRuntimes.last?.presentedConfigurations.last,
            activeSDR.identity
        )
        XCTAssertEqual(
            surfaceAdapter.activeContract,
            activeSDR.identity.surfaceContract
        )

        mediaEnvironment.yieldVideoPresentation(
            .decodedFrame(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 7
                ),
                contract: StreamVideoDecodedPresentationContract(
                    decoderGeneration: 10,
                    colorMetadata: hdrMetadata,
                    decodedLayout: hdrLayout
                )
            ),
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldVideoPresentation(
            .cleared(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 8
                ),
                decoderGeneration: 10
            ),
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            model.renderState.hdrRenderResolution.configuration?
                .identity.decoderGeneration,
            11
        )
        XCTAssertEqual(
            model.renderState.decodedVideoPresentationContract?
                .decoderGeneration,
            11
        )
        let staleFrameDropsBefore = model.videoPresentationSource.snapshot()
            .staleFrameDropCount
        model.videoPresentationSource.consume(
            .frame(hdrFrame),
            sessionID: record.sessionID,
            mediaGeneration: 1
        )
        XCTAssertEqual(
            model.videoPresentationSource.snapshot().staleFrameDropCount,
            staleFrameDropsBefore + 1
        )
        XCTAssertEqual(
            model.videoPresentationSource.currentFrame()?.frameID,
            sdrFrame.frameID
        )
        presenter.draw(in: view)
        XCTAssertEqual(
            presenterRuntimes.last?.presentedConfigurations.last,
            activeSDR.identity
        )
        mediaEnvironment.yieldVideoPresentation(
            .cleared(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 0,
                    revision: .max
                ),
                decoderGeneration: nil
            ),
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            model.renderState.hdrRenderResolution.configuration?
                .identity.decoderGeneration,
            11
        )

        await model.stopStream()
        await launchTask.value
        presenter.update(renderState: model.renderState)
        presenter.stop()
        XCTAssertNil(model.renderState.negotiatedVideoColorMetadata)
        XCTAssertNil(model.renderState.decodedVideoPresentationContract)
        XCTAssertEqual(
            model.renderState.hdrRenderResolution,
            .closed(.inactiveSession)
        )
        XCTAssertNil(model.videoPresentationSource.currentFrame())
        XCTAssertNil(presenter.snapshot().activeConfiguration)
        XCTAssertEqual(
            surfaceAdapter.activeContract?.extendedRangeIntent,
            .disabled
        )
        XCTAssertTrue(presenterRuntimes.allSatisfy {
            $0.invalidationCount == 1
        })
        XCTAssertNil(model.diagnostics.latestStreamActionableEvent)
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
        await waitUntil {
            model.macSessionInputSnapshot().acceptsInput
                && model.macInputSurfacePolicy.admitsInput
        }

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

    func testMacApplicationIntegrationCoversInputLifecycleResizeAndTeardown() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let presentationSource = StreamVideoPresentationSource()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            videoPresentationSource: presentationSource,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 37,
                    key: Data(repeating: 0x37, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        model.settings.input.preferRelativeMouseMode = false
        model.settings.input.captureSystemShortcuts = false

        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 2_560, height: 1_440)
        )
        model.applyPlatformLifecycle(lifecycle)

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil {
            model.session.isStreaming
                && model.macInputSurfacePolicy.admitsInput
                && mediaEnvironment.currentLifecycleApplications().last?.directive.input == .open
        }

        let initialCoordinate = try XCTUnwrap(model.renderState.coordinateSnapshot)
        let initialLifecycleRevision = try XCTUnwrap(
            mediaEnvironment.currentLifecycleApplications().last?.lifecycleRevision
        )
        presentationSource.beginSession(sessionID: record.sessionID, mediaGeneration: 1)
        presentationSource.consume(
            .sessionStarted(generation: 11, colorMetadata: .rec709VideoRange()),
            sessionID: record.sessionID,
            mediaGeneration: 1
        )
        XCTAssertEqual(initialCoordinate.drawableSize, PixelSize(width: 2_560, height: 1_440))
        XCTAssertEqual(presentationSource.snapshot().sessionID, record.sessionID)
        XCTAssertEqual(presentationSource.snapshot().decoderGeneration, 11)

        let keySample = MacPlatformInputSample.keyboard(MacKeyboardSample(
            rawKeyCode: 0,
            characters: "a",
            isDown: true,
            modifiers: [],
            isRepeat: false
        ))
        XCTAssertEqual(model.submitMacPlatformInput(keySample), .accepted)
        await waitUntil { mediaEnvironment.currentSentInputApplications().count == 1 }
        let deliveredKeyApplication = try XCTUnwrap(
            mediaEnvironment.currentSentInputApplications().first
        )
        XCTAssertEqual(deliveredKeyApplication.sessionID, record.sessionID)
        XCTAssertEqual(deliveredKeyApplication.mediaGeneration, 1)
        XCTAssertEqual(
            deliveredKeyApplication.event,
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
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)
        XCTAssertEqual(
            model.submitMacPlatformInput(keySample),
            .rejected(.admissionClosed)
        )
        let unfocusedDirective = SessionLifecycleDirectiveResolver.resolve(
            isStreamActive: true,
            isVisible: true,
            isFocused: false,
            drawableSize: PixelSize(width: 2_560, height: 1_440)
        )
        await waitUntil {
            model.macSessionInputSnapshot().completedReleaseBarrierCount == 1
                && mediaEnvironment.currentReleasedInputApplications().count == 1
                && mediaEnvironment.currentLifecycleApplications().last?.directive
                    == unfocusedDirective
        }
        let unfocusedLifecycleRevision = try XCTUnwrap(
            mediaEnvironment.currentLifecycleApplications().last?.lifecycleRevision
        )
        let releaseApplication = try XCTUnwrap(
            mediaEnvironment.currentReleasedInputApplications().first
        )
        XCTAssertEqual(releaseApplication.sessionID, record.sessionID)
        XCTAssertEqual(releaseApplication.mediaGeneration, 1)
        XCTAssertGreaterThan(unfocusedLifecycleRevision, initialLifecycleRevision)
        XCTAssertEqual(unfocusedDirective.videoProcessing, .submitDecodedVideo)
        XCTAssertEqual(unfocusedDirective.presentation, .throttled(reason: .notFocused))

        lifecycle.isVisible = false
        lifecycle.isFocused = true
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        let occludedDirective = SessionLifecycleDirectiveResolver.resolve(
            isStreamActive: true,
            isVisible: false,
            isFocused: true,
            drawableSize: PixelSize(width: 2_560, height: 1_440)
        )
        await waitUntil {
            mediaEnvironment.currentLifecycleApplications().last?.directive
                == occludedDirective
        }
        let occludedLifecycleRevision = try XCTUnwrap(
            mediaEnvironment.currentLifecycleApplications().last?.lifecycleRevision
        )
        let occludedPresentationSnapshot = presentationSource.snapshot()
        XCTAssertGreaterThan(occludedLifecycleRevision, unfocusedLifecycleRevision)
        XCTAssertEqual(
            occludedDirective.videoProcessing,
            .drainTransportWithoutDecoding(reason: .notVisible)
        )
        XCTAssertEqual(occludedDirective.presentation, .clear(reason: .notVisible))
        XCTAssertEqual(model.renderState.policy, .paused(reason: "Window or scene not visible"))
        XCTAssertNil(occludedPresentationSnapshot.decoderGeneration)
        XCTAssertNil(occludedPresentationSnapshot.latestFrameID)
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)
        XCTAssertEqual(model.macSessionInputSnapshot().completedReleaseBarrierCount, 1)
        XCTAssertTrue(model.hasActiveStreamSession)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [])
        XCTAssertEqual(mediaEnvironment.currentStoppedSessionIDs(), [])

        lifecycle.isVisible = true
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        let resumedDirective = SessionLifecycleDirectiveResolver.resolve(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 2_560, height: 1_440)
        )
        await waitUntil {
            model.macInputSurfacePolicy.admitsInput
                && mediaEnvironment.currentLifecycleApplications().last?.directive
                    == resumedDirective
        }
        let resumedLifecycleRevision = try XCTUnwrap(
            mediaEnvironment.currentLifecycleApplications().last?.lifecycleRevision
        )
        XCTAssertGreaterThan(resumedLifecycleRevision, occludedLifecycleRevision)
        XCTAssertEqual(resumedDirective.videoProcessing, .submitDecodedVideo)
        XCTAssertEqual(resumedDirective.presentation, .active)
        presentationSource.consume(
            .sessionStarted(generation: 12, colorMetadata: .rec709VideoRange()),
            sessionID: record.sessionID,
            mediaGeneration: 1
        )
        XCTAssertEqual(presentationSource.snapshot().decoderGeneration, 12)

        lifecycle.drawableSize = PixelSize(width: 1_600, height: 1_200)
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        await waitUntil {
            guard let latest = mediaEnvironment.currentLifecycleApplications().last else {
                return false
            }
            return latest.lifecycleRevision > resumedLifecycleRevision
                && latest.directive == resumedDirective
        }
        let lifecycleApplications = mediaEnvironment.currentLifecycleApplications()
        let lifecycleRevisions = lifecycleApplications.map(\.lifecycleRevision)
        XCTAssertTrue(lifecycleApplications.allSatisfy {
            $0.sessionID == record.sessionID && $0.mediaGeneration == 1
        })
        XCTAssertTrue(zip(lifecycleRevisions, lifecycleRevisions.dropFirst()).allSatisfy {
            $0.0 < $0.1
        })
        let resizedCoordinate = try XCTUnwrap(model.renderState.coordinateSnapshot)
        XCTAssertGreaterThan(resizedCoordinate.revision, initialCoordinate.revision)
        XCTAssertEqual(resizedCoordinate.drawableSize, PixelSize(width: 1_600, height: 1_200))
        XCTAssertEqual(resizedCoordinate.resolvedVideo.videoRect.x, 0, accuracy: 0.000_001)
        XCTAssertEqual(resizedCoordinate.resolvedVideo.videoRect.y, 150, accuracy: 0.000_001)
        XCTAssertEqual(resizedCoordinate.resolvedVideo.videoRect.width, 1_600, accuracy: 0.000_001)
        XCTAssertEqual(resizedCoordinate.resolvedVideo.videoRect.height, 900, accuracy: 0.000_001)

        XCTAssertEqual(
            model.submitMacPlatformInput(.pointerMove(MacPointerSample(
                localPoint: RemotePoint(x: 400, y: 375),
                deltaX: 99,
                deltaY: -99,
                buttons: []
            ))),
            .accepted
        )
        await waitUntil { mediaEnvironment.currentSentInputApplications().count == 2 }
        let deliveredPointerApplication = try XCTUnwrap(
            mediaEnvironment.currentSentInputApplications().last
        )
        XCTAssertEqual(deliveredPointerApplication.sessionID, record.sessionID)
        XCTAssertEqual(deliveredPointerApplication.mediaGeneration, 1)
        XCTAssertEqual(
            deliveredPointerApplication.event,
            .pointer(.absoluteMove(
                point: RemotePoint(x: 960, y: 540),
                referenceSize: PixelSize(width: 3_840, height: 2_160),
                buttons: []
            ))
        )

        await model.stopStream()
        await launchTask.value

        let mediaSnapshot = await mediaEnvironment.snapshot()
        let presentationSnapshot = presentationSource.snapshot()
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(mediaEnvironment.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertNil(mediaSnapshot.sessionID)
        XCTAssertNil(mediaSnapshot.resourcePhase)
        XCTAssertEqual(mediaSnapshot.activeResourceCount, 0)
        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)
        XCTAssertNil(model.macSessionInputSnapshot().generation)
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertNil(presentationSnapshot.sessionID)
        XCTAssertNil(presentationSnapshot.mediaGeneration)
        XCTAssertEqual(
            model.submitMacPlatformInput(keySample),
            .rejected(.inactiveGeneration)
        )

        let stoppedLifecycle = makePlatformLifecycle(
            isStreamActive: false,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 1_600, height: 1_200)
        )
        model.applyPlatformLifecycle(stoppedLifecycle)
        await Task.yield()
        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertNil(model.macSessionInputSnapshot().generation)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(mediaEnvironment.currentStoppedSessionIDs(), [record.sessionID])
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
        model.diagnostics.record(ApplicationDiagnosticFactory.pairingUnavailable)
        await model.beginPairing(host: host)

        XCTAssertEqual(model.pairingUI.stage, .waitingForPIN)
        XCTAssertFalse(model.pairingUI.isRunning)
        XCTAssertNotNil(model.pairingUI.attemptID)
        XCTAssertEqual(provider.currentRequestCount(), 0)
        XCTAssertNotEqual(model.diagnostics.latestActionableEvent?.category, .pairing)

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

        model.diagnostics.record(ApplicationDiagnosticFactory.pairingUnavailable)
        provider.completeAuthenticated(request)
        await submitTask.value

        XCTAssertEqual(model.selectedHost?.pairingState, .paired)
        XCTAssertEqual(model.selectedHost?.pinnedIdentity?.serverCertificateDER, Data([0x30, 0x01, 0x02]))
        XCTAssertEqual(model.pairingUI.stage, .paired)
        XCTAssertFalse(model.pairingUI.isRunning)
        XCTAssertNil(model.pairingUI.attemptID)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertNotEqual(model.diagnostics.latestActionableEvent?.category, .pairing)
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
        let drawableSize = PixelSize(width: 3_840, height: 2_160)
        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: drawableSize
        )
        _ = lifecycle.updateSurface(
            displayID: "display-a",
            headroom: DisplayHeadroom(
                potential: 4,
                current: 2.5,
                reference: 1
            ),
            drawableSize: drawableSize
        )
        model.applyPlatformLifecycle(lifecycle)
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { mediaEnvironment.currentStartRecords().count == 1 }
        mediaEnvironment.yieldReadiness(
            [.video, .audio, .input],
            sessionID: record.sessionID
        )
        await waitUntil { model.session.isStreaming }

        let hdrMetadata = VideoColorMetadata.hdr10VideoRange()
        provider.yield(
            .videoColorMetadata(hdrMetadata),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.negotiatedVideoColorMetadata == hdrMetadata
                && model.renderState.decodedVideoPresentationContract == nil
        }
        mediaEnvironment.yieldVideoPresentation(
            .decoderStarted(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 1
                ),
                contract: StreamVideoDecoderPresentationContract(
                    decoderGeneration: 1,
                    colorMetadata: hdrMetadata
                )
            ),
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldVideoPresentation(
            .decodedFrame(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 2
                ),
                contract: StreamVideoDecodedPresentationContract(
                    decoderGeneration: 1,
                    colorMetadata: hdrMetadata,
                    decodedLayout: HDRDecodedPixelBufferLayout(
                        pixelFormat: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
                        width: 3_840,
                        height: 2_160,
                        planes: [
                            HDRDecodedPlaneDimensions(width: 3_840, height: 2_160),
                            HDRDecodedPlaneDimensions(width: 1_920, height: 1_080)
                        ]
                    )
                )
            ),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.hdrRenderResolution.configuration?.outputMode == .edr
        }

        mediaEnvironment.blockNextStop()
        provider.yield(
            .reconnecting(attempt: 1, reason: "Control channel interrupted."),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.hasBlockedStop() }
        XCTAssertEqual(
            model.renderState.hdrRenderResolution,
            .closed(.inactiveSession)
        )
        await waitUntil { model.session.phase.label.contains("Reconnecting") }
        XCTAssertFalse(model.session.isStreaming)
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertTrue(model.hasActiveStreamSession)
        mediaEnvironment.resumeBlockedStop()

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

    func testTVVisionPresentationAcceptsCurrentGenerationAndClearsOnReconnectAndRemoteTermination()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 71,
                    key: Data(repeating: 0x71, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        model.setTVStreamWorkspaceVisible(true)
        model.setTVStreamOverlayVisible(false)
        XCTAssertFalse(model.tvStreamOverlayVisible)

        let currentGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 1,
            revision: 1
        )
        let currentDisplay = try makeTVOSDisplaySnapshot(
            revision: 1,
            displayGeneration: 1,
            current: 2,
            potential: 4
        )
        model.receiveTVVisionGeometryUpdate(currentGeometry)
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: currentGeometry.surfaceGeneration,
            snapshot: currentDisplay
        ))
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 4
        }
        let geometryApplications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(geometryApplications[0].action, .activate)
        guard case .scene = geometryApplications[1].action,
              case .input = geometryApplications[2].action,
              case let .display(appliedDisplay) = geometryApplications[3].action else {
            return XCTFail("Expected geometry, input, then display after activation.")
        }
        XCTAssertEqual(appliedDisplay, currentDisplay)

        let currentAudio = try makeTVOSAudioRouteSnapshot(
            revision: 1,
            graphGeneration: 1,
            presentationMode: .headTracked
        )
        let current = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 2,
            display: currentDisplay,
            audioRoute: currentAudio
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            current,
            sessionID: record.sessionID
        )
        await waitUntil { model.tvVisionPlatformPresentationState == current }
        XCTAssertEqual(
            model.tvVisionPlatformPresentationState?.snapshot.audioRoute,
            current.snapshot.audioRoute
        )
        XCTAssertEqual(
            model.tvVisionPlatformPresentationSnapshot,
            current.snapshot.presentation
        )

        let regressive = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 1
        )
        let wrongPlatform = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .visionOS,
            presentationGeneration: 1,
            sequence: 9
        )
        let wrongGeneration = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 2,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 9
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            regressive,
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            wrongPlatform,
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            wrongGeneration,
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.tvVisionPlatformPresentationState, current)

        mediaEnvironment.blockNextStop()
        provider.yield(
            .reconnecting(attempt: 1, reason: "Control channel interrupted."),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.hasBlockedStop() }
        XCTAssertNil(model.tvVisionPlatformPresentationState)
        XCTAssertNil(model.tvVisionPlatformPresentationSnapshot)
        XCTAssertTrue(model.tvStreamOverlayVisible)
        let reconnectApplications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(reconnectApplications.last?.action, .stop(.reconnect))
        mediaEnvironment.resumeBlockedStop()

        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey
            )),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.currentStartRecords().count == 2 }
        provider.yield(.channelsReady(.control), sessionID: record.sessionID)
        await waitUntil { model.session.isStreaming }
        model.setTVStreamOverlayVisible(false)
        XCTAssertFalse(model.tvStreamOverlayVisible)

        model.receiveTVVisionGeometryUpdate(currentGeometry)
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: currentGeometry.surfaceGeneration,
            snapshot: currentDisplay
        ))
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count
                == reconnectApplications.count + 4
        }
        let replayApplications = Array(
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications()
                .suffix(4)
        )
        XCTAssertEqual(
            replayApplications.map(\.ownership.mediaGeneration),
            [2, 2, 2, 2]
        )
        XCTAssertEqual(replayApplications[0].action, .activate)
        guard case let .scene(replayedGeometry) = replayApplications[1].action,
              case .input = replayApplications[2].action,
              case let .display(replayedDisplay) = replayApplications[3].action else {
            return XCTFail("Expected reconnect replay to restore scene, input, and display.")
        }
        XCTAssertEqual(replayedGeometry, currentGeometry)
        XCTAssertEqual(replayedDisplay, currentDisplay)

        let replacementAudio = try makeTVOSAudioRouteSnapshot(
            revision: 1,
            graphGeneration: 2,
            presentationMode: .fixedSpatial
        )
        let replacement = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 2,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 1,
            display: currentDisplay,
            audioRoute: replacementAudio
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            current,
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            replacement,
            sessionID: record.sessionID
        )
        await waitUntil {
            model.tvVisionPlatformPresentationState == replacement
        }
        XCTAssertEqual(
            model.tvVisionPlatformPresentationState?.snapshot.audioRoute,
            replacement.snapshot.audioRoute
        )
        XCTAssertEqual(
            model.tvVisionPlatformPresentationSnapshot,
            replacement.snapshot.presentation
        )

        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launchTask.value
        XCTAssertNil(model.tvVisionPlatformPresentationState)
        XCTAssertNil(model.tvVisionPlatformPresentationSnapshot)
        XCTAssertTrue(model.tvStreamOverlayVisible)
        let terminatedApplications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(
            terminatedApplications.last?.action,
            .stop(.remoteTermination)
        )
    }

    func testTVVisionPresentationClearsAndAppliesLocalStop() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 72,
                    key: Data(repeating: 0x72, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        let current = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 1,
            display: makeTVOSDisplaySnapshot(
                revision: 1,
                displayGeneration: 1,
                current: 2,
                potential: 4
            ),
            audioRoute: makeTVOSAudioRouteSnapshot(
                revision: 1,
                graphGeneration: 1,
                presentationMode: .fixedSpatial
            )
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            current,
            sessionID: record.sessionID
        )
        await waitUntil { model.tvVisionPlatformPresentationState == current }
        XCTAssertEqual(
            model.tvVisionPlatformPresentationSnapshot,
            current.snapshot.presentation
        )

        await model.stopStream()
        await launchTask.value

        XCTAssertNil(model.tvVisionPlatformPresentationState)
        XCTAssertNil(model.tvVisionPlatformPresentationSnapshot)
        XCTAssertEqual(
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().last?.action,
            .stop(.localStop)
        )
    }

    func testTVVisionGeometryQueueKeepsLatestReplacementAndRejectsLateSurface()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(
            blocksFirstTVVisionActivation: true
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 75,
                    key: Data(repeating: 0x75, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionClosedGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 1
            )
        )
        await waitUntil { mediaEnvironment.hasBlockedTVVisionActivation() }
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionClosedGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 2
            )
        )
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionClosedGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 2,
                revision: 1
            )
        )
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionClosedGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 3
            )
        )
        let lateFirstSurface = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 99
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            lateFirstSurface,
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.tvVisionPlatformPresentationState)

        mediaEnvironment.resumeBlockedTVVisionActivation()
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 3
        }
        let applications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(
            applications.map(\.ownership.presentationGeneration.rawValue),
            [1, 2, 2]
        )
        XCTAssertEqual(applications[0].action, .activate)
        XCTAssertEqual(applications[1].action, .activate)
        guard case let .scene(replacementScene) = applications[2].action else {
            return XCTFail("Expected only the replacement scene to be applied.")
        }
        XCTAssertEqual(replacementScene.surfaceGeneration.rawValue, 2)
        XCTAssertEqual(replacementScene.revision.rawValue, 1)

        let replacement = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 2,
            sequence: 1
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            replacement,
            sessionID: record.sessionID
        )
        await waitUntil { model.tvVisionPlatformPresentationState == replacement }
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            lateFirstSurface,
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.tvVisionPlatformPresentationState, replacement)

        await model.stopStream()
        await launchTask.value
    }

    func testTVOSDisplayHDRAppliesInGeometryOrderAndFailsClosedAcrossReplacement()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 80,
                    key: Data(repeating: 0x80, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        let firstGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 1,
            revision: 1
        )
        let direct = try makeTVOSDisplaySnapshot(
            revision: 1,
            displayGeneration: 1,
            current: 2.5,
            potential: 4
        )
        model.receiveTVVisionGeometryUpdate(firstGeometry)
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: firstGeometry.surfaceGeneration,
            snapshot: direct
        ))
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 4
        }
        let firstApplications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(firstApplications[0].action, .activate)
        guard case .scene = firstApplications[1].action,
              case .input = firstApplications[2].action,
              case let .display(appliedDirect) = firstApplications[3].action else {
            return XCTFail("Display must apply after scene and input geometry state.")
        }
        XCTAssertEqual(appliedDirect, direct)

        let directState = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 4,
            display: direct
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            directState,
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.displaySnapshot?.headroom.current == 2.5
        }
        XCTAssertEqual(model.renderState.headroom.potential, 4)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)

        let fallback = try makeTVOSDisplaySnapshot(
            revision: 2,
            displayGeneration: 1,
            current: .nan,
            potential: 4
        )
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: firstGeometry.surfaceGeneration,
            snapshot: fallback
        ))
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 5
        }
        let fallbackState = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 5,
            display: fallback
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            fallbackState,
            sessionID: record.sessionID
        )
        await waitUntil {
            model.tvOSDisplayHDRFallbackReason == .invalidHeadroom
        }
        XCTAssertEqual(model.renderState.displaySnapshot?.headroom, DisplayHeadroom())
        XCTAssertEqual(model.renderState.headroom, DisplayHeadroom())

        let applicationCount = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications().count
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: firstGeometry.surfaceGeneration,
            snapshot: direct
        ))
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: try TVVisionGeneration(
                domain: .surface,
                rawValue: 2
            ),
            snapshot: try makeTVOSDisplaySnapshot(
                revision: 3,
                displayGeneration: 1,
                current: 3,
                potential: 4
            )
        ))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment.currentTVVisionPlatformPresentationApplications().count,
            applicationCount
        )

        let replacementDisplay = try makeTVOSDisplaySnapshot(
            revision: 1,
            displayGeneration: 2,
            current: 3,
            potential: 4
        )
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: firstGeometry.surfaceGeneration,
            snapshot: replacementDisplay
        ))
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count
                == applicationCount + 1
        }
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: firstGeometry.surfaceGeneration,
            snapshot: try makeTVOSDisplaySnapshot(
                revision: 3,
                displayGeneration: 1,
                current: 3.5,
                potential: 4
            )
        ))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment.currentTVVisionPlatformPresentationApplications().count,
            applicationCount + 1
        )

        let replacementGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 2,
            revision: 1
        )
        model.receiveTVVisionGeometryUpdate(replacementGeometry)
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count
                == applicationCount + 4
        }
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            try makeTVVisionPresentationState(
                sessionID: record.sessionID,
                mediaGeneration: 1,
                platform: .tvOS,
                presentationGeneration: 1,
                sequence: 6,
                display: replacementDisplay
            ),
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: firstGeometry.surfaceGeneration,
            snapshot: replacementDisplay
        ))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment.currentTVVisionPlatformPresentationApplications().count,
            applicationCount + 4
        )

        model.receiveTVOSDisplayHDREvent(.revisionExhausted(
            surfaceGeneration: replacementGeometry.surfaceGeneration
        ))
        XCTAssertTrue(model.renderState.isDisplayRevisionExhausted)
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count
                == applicationCount + 5
        }
        XCTAssertEqual(
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().last?.action,
            .fail(.semanticRevisionExhausted)
        )
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: replacementGeometry.surfaceGeneration,
            snapshot: try makeTVOSDisplaySnapshot(
                revision: 1,
                displayGeneration: 3,
                current: 3,
                potential: 4
            )
        ))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment.currentTVVisionPlatformPresentationApplications().count,
            applicationCount + 5
        )

        await model.stopStream()
        await launchTask.value
        XCTAssertFalse(model.renderState.isDisplayRevisionExhausted)
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)
    }

    func testTVOSDisplayApplicationFailureTerminatesCurrentPresentation()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(
            failsTVOSDisplayApplication: true
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 81,
                    key: Data(repeating: 0x81, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        let geometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 1,
            revision: 1
        )
        model.receiveTVVisionGeometryUpdate(geometry)
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: geometry.surfaceGeneration,
            snapshot: try makeTVOSDisplaySnapshot(
                revision: 1,
                displayGeneration: 1,
                current: 2.5,
                potential: 4
            )
        ))
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 5
        }
        let actions = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications().map(\.action)
        guard case .display = actions[3] else {
            return XCTFail("Expected the failing display application.")
        }
        XCTAssertEqual(actions[4], .fail(.actionFailed(.display)))
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)

        await model.stopStream()
        await launchTask.value
    }

    func testTVRemoteSurfacePressesUseCurrentGeometryAndBalancedInput()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 76,
                    key: Data(repeating: 0x76, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        XCTAssertTrue(model.tvStreamOverlayVisible)
        model.setTVStreamWorkspaceVisible(true)

        let overlayGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 1,
            revision: 1
        )
        model.receiveTVVisionGeometryUpdate(overlayGeometry)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 3
        }
        let platformApplications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(platformApplications[0].action, .activate)
        guard case .scene = platformApplications[1].action else {
            return XCTFail("Expected scene before tvOS input admission.")
        }
        guard case let .input(input, leases) = platformApplications[2].action else {
            return XCTFail("Expected current tvOS input admission.")
        }
        XCTAssertEqual(
            input.supported,
            [.tvRemote, .extendedGamepad, .microGamepad]
        )
        XCTAssertEqual(
            input.focusEligibility,
            .ineligible(.overlayVisible)
        )
        XCTAssertTrue(leases.isEmpty)

        let surface = overlayGeometry.surfaceGeneration
        await waitUntil {
            model.tvRemoteSurfacePressDisposition(for: surface) == .local
        }
        model.setTVStreamOverlayVisible(false)
        XCTAssertFalse(model.tvStreamOverlayVisible)
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )

        let focusedGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 1,
            revision: 2
        )
        model.receiveTVVisionGeometryUpdate(focusedGeometry)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 5
        }
        let focusApplications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        guard case .scene = focusApplications[3].action else {
            return XCTFail("Expected refreshed scene before focus admission.")
        }
        guard case let .input(focusedInput, focusedLeases) =
                focusApplications[4].action else {
            return XCTFail("Expected fresh focused tvOS input admission.")
        }
        XCTAssertEqual(focusedInput.focusEligibility, .eligible)
        XCTAssertTrue(focusedLeases.isEmpty)

        var controllerRuntime = try TVGameControllerSlotRuntime(
            inputGeneration: focusedInput.inputGeneration
        )
        let firstControllerToken = try TVGameControllerDeviceToken(1)
        let controllerRoster = try controllerRuntime.connect(
            token: firstControllerToken,
            profile: .extendedGamepad,
            capabilities: [.analogTriggers, .rgbLED, .accelerometer],
            supportedButtons: .standard,
            completeState: TVGameControllerCompleteState(buttons: [.a])
        )
        model.receiveTVGameControllerRoster(controllerRoster)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 6
        }
        guard case let .input(rosterInput, rosterLeases) = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications().last?.action else {
            return XCTFail("Expected current controller roster input application.")
        }
        XCTAssertEqual(rosterInput, focusedInput)
        XCTAssertEqual(rosterLeases, controllerRoster.controllers.map(\.lease))
        XCTAssertEqual(model.tvControllerRosterState, controllerRoster)
        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count == 1
                && model.tvControllerRoutedRosterState == controllerRoster
        }
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().first?.event,
            .controllerRoster(TVGameControllerRosterRouter.reconcile(
                previous: nil,
                current: controllerRoster
            ))
        )
        XCTAssertEqual(model.tvControllerRoutedRosterState, controllerRoster)

        let lease = try XCTUnwrap(controllerRoster.controllers.first?.lease)
        let controllerID = TVGameControllerRoutingIdentity(lease: lease).rawValue
        mediaEnvironment.yieldFeedback(.led(ControllerLEDFeedback(
            controllerID: controllerID,
            red: 10,
            green: 20,
            blue: 30
        )), sessionID: record.sessionID)
        let feedbackRequest = try TVControllerFeedbackRequest(
            lease: lease,
            payload: .led(red: 10, green: 20, blue: 30)
        )
        await waitUntil {
            model.tvControllerFeedbackDecisionState == .apply(feedbackRequest)
        }

        model.receiveTVGameControllerMotion(try TVGameControllerMotionSample(
            lease: lease,
            type: .accelerometer,
            x: 1,
            y: 2,
            z: 3
        ))
        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count == 2
        }
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().last?.event,
            .controllerMotion(ControllerMotionInputEvent(
                controllerID: controllerID,
                type: .accelerometer,
                x: 1,
                y: 2,
                z: 3
            ))
        )

        mediaEnvironment.blockNextInputSend()
        _ = try controllerRuntime.disconnect(token: firstControllerToken)
        let secondControllerToken = try TVGameControllerDeviceToken(2)
        let secondRoster = try controllerRuntime.connect(
            token: secondControllerToken,
            profile: .extendedGamepad,
            capabilities: [.analogTriggers, .rgbLED, .accelerometer],
            supportedButtons: .standard,
            completeState: TVGameControllerCompleteState(buttons: [.b])
        )
        model.receiveTVGameControllerRoster(secondRoster)
        await waitUntil { mediaEnvironment.hasBlockedInputSend() }

        _ = try controllerRuntime.disconnect(token: secondControllerToken)
        let thirdRoster = try controllerRuntime.connect(
            token: TVGameControllerDeviceToken(3),
            profile: .extendedGamepad,
            capabilities: [.analogTriggers, .rgbLED, .accelerometer],
            supportedButtons: .standard,
            completeState: TVGameControllerCompleteState(buttons: [.x])
        )
        model.receiveTVGameControllerRoster(thirdRoster)
        mediaEnvironment.resumeBlockedInputSend()
        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count == 4
                && model.tvControllerRoutedRosterState == thirdRoster
        }
        let serializedRosters = mediaEnvironment.currentSentInputApplications()
        XCTAssertEqual(
            serializedRosters[2].event,
            .controllerRoster(TVGameControllerRosterRouter.reconcile(
                previous: controllerRoster,
                current: secondRoster
            ))
        )
        XCTAssertEqual(
            serializedRosters[3].event,
            .controllerRoster(TVGameControllerRosterRouter.reconcile(
                previous: secondRoster,
                current: thirdRoster
            ))
        )

        mediaEnvironment.yieldFeedback(.led(ControllerLEDFeedback(
            controllerID: controllerID,
            red: 1,
            green: 2,
            blue: 3
        )), sessionID: record.sessionID)
        await waitUntil {
            model.tvControllerFeedbackDecisionState == .unavailable(
                .controllerUnavailable
            )
        }
        let currentLease = try XCTUnwrap(thirdRoster.controllers.first?.lease)
        let currentControllerID = TVGameControllerRoutingIdentity(
            lease: currentLease
        ).rawValue
        let currentFeedbackRequest = try TVControllerFeedbackRequest(
            lease: currentLease,
            payload: .led(red: 4, green: 5, blue: 6)
        )
        mediaEnvironment.yieldFeedback(.led(ControllerLEDFeedback(
            controllerID: currentControllerID,
            red: 4,
            green: 5,
            blue: 6
        )), sessionID: record.sessionID)
        await waitUntil {
            model.tvControllerFeedbackDecisionState
                == .apply(currentFeedbackRequest)
        }

        model.receiveTVGameControllerMotion(try TVGameControllerMotionSample(
            lease: lease,
            type: .accelerometer,
            x: 7,
            y: 8,
            z: 9
        ))
        model.receiveTVGameControllerMotion(try TVGameControllerMotionSample(
            lease: currentLease,
            type: .accelerometer,
            x: 10,
            y: 11,
            z: 12
        ))
        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count == 5
        }
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().last?.event,
            .controllerMotion(ControllerMotionInputEvent(
                controllerID: currentControllerID,
                type: .accelerometer,
                x: 10,
                y: 11,
                z: 12
            ))
        )
        let controllerInputCount = mediaEnvironment
            .currentSentInputApplications().count

        for _ in 0..<100
        where model.tvRemoteSurfacePressDisposition(for: surface) != .captured {
            await Task.yield()
        }
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .captured,
            "pending=\(model.tvRemoteInputReleasePending) "
                + "overlay=\(model.tvStreamOverlayVisible) "
                + "applications=\(mediaEnvironment.currentTVVisionPlatformPresentationApplications().count)"
        )
        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(surface, 1, .select, .began)
            ),
            .captured
        )
        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(surface, 1, .select, .ended)
            ),
            .captured
        )
        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(surface, 2, .playPause, .began)
            ),
            .captured
        )
        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(surface, 2, .playPause, .cancelled)
            ),
            .captured
        )
        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(surface, 3, .menu, .began)
            ),
            .local
        )
        let foreignSurface = try TVVisionGeneration(
            domain: .surface,
            rawValue: 2
        )
        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(foreignSurface, 1, .right, .began)
            ),
            .local
        )

        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count
                == controllerInputCount + 4
        }
        XCTAssertEqual(
            Array(mediaEnvironment.currentSentInputApplications().suffix(4))
                .map(\.event),
            [
                .tvRemote(TVRemoteInputEvent(button: .select, isDown: true)),
                .tvRemote(TVRemoteInputEvent(button: .select, isDown: false)),
                .tvRemote(TVRemoteInputEvent(button: .playPause, isDown: true)),
                .tvRemote(TVRemoteInputEvent(button: .playPause, isDown: false))
            ]
        )

        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(surface, 4, .right, .began)
            ),
            .captured
        )
        mediaEnvironment.blockNextRelease()
        model.receiveTVRemoteReservedCommand(.backMenu)
        XCTAssertFalse(model.tvStreamOverlayVisible)
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )
        await waitUntil { mediaEnvironment.hasBlockedRelease() }
        XCTAssertTrue(model.tvRemoteInputReleasePending)
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            1
        )
        model.receiveTVRemoteReservedCommand(.backMenu)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            1
        )
        mediaEnvironment.resumeBlockedRelease()
        await waitUntil {
            model.tvStreamOverlayVisible
                && !model.tvRemoteInputReleasePending
        }
        XCTAssertEqual(
            model.tvRemoteReservedCommandState,
            .handledLocally(
                command: .backMenu,
                disposition: .showOverlayOrExitCapture
            )
        )
        model.receiveTVRemoteReservedCommand(.unsupported)
        XCTAssertEqual(
            model.tvRemoteReservedCommandState,
            .unavailable(
                command: .unsupported,
                disposition: .ignoreLocally,
                reason: .unsupportedInteraction
            )
        )
        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count
                == controllerInputCount + 6
        }
        XCTAssertEqual(
            Array(mediaEnvironment.currentSentInputApplications().suffix(2))
                .map(\.event),
            [
                .tvRemote(TVRemoteInputEvent(button: .right, isDown: true)),
                .tvRemote(TVRemoteInputEvent(button: .right, isDown: false))
            ]
        )
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )
        model.setTVStreamOverlayVisible(false)
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )
        let presentationCountBeforeFocusRestore = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications().count
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionActiveGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 3
            )
        )
        for _ in 0..<100
        where model.tvRemoteSurfacePressDisposition(for: surface) != .captured {
            await Task.yield()
        }
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .captured,
            "pending=\(model.tvRemoteInputReleasePending) "
                + "overlay=\(model.tvStreamOverlayVisible) "
                + "applications=\(mediaEnvironment.currentTVVisionPlatformPresentationApplications().count)"
        )
        XCTAssertEqual(
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count,
            presentationCountBeforeFocusRestore + 2
        )

        model.navigationSelection = .settings
        XCTAssertFalse(model.tvStreamOverlayVisible)
        await waitUntil { model.tvStreamOverlayVisible }
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )
        model.navigationSelection = .stream
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )

        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionClosedGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 4
            )
        )
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count
                == presentationCountBeforeFocusRestore + 3
        }
        await waitUntil {
            model.tvRemoteSurfacePressDisposition(for: surface) == .local
        }
        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(surface, 5, .up, .began)
            ),
            .local
        )

        model.setTVStreamOverlayVisible(false)
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionActiveGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 5
            )
        )
        await waitUntil {
            model.tvRemoteSurfacePressDisposition(for: surface) == .captured
        }

        let replacementGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 2,
            revision: 1
        )
        let replacementSurface = replacementGeometry.surfaceGeneration
        let releasesBeforeReplacement = mediaEnvironment
            .currentReleasedInputApplications().count
        mediaEnvironment.blockNextRelease()
        model.receiveTVVisionGeometryUpdate(replacementGeometry)
        await waitUntil { mediaEnvironment.hasBlockedRelease() }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            releasesBeforeReplacement + 1
        )
        XCTAssertTrue(model.tvRemoteInputReleasePending)
        XCTAssertFalse(model.tvStreamOverlayVisible)
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: replacementSurface),
            .local
        )
        model.receiveTVVisionGeometryUpdate(replacementGeometry)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            releasesBeforeReplacement + 1
        )
        mediaEnvironment.resumeBlockedRelease()
        await waitUntil {
            model.tvRemoteSurfacePressDisposition(for: replacementSurface)
                == .captured
                && !model.tvRemoteInputReleasePending
        }
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )
        XCTAssertFalse(model.tvStreamOverlayVisible)

        let sceneLoss = try makeTVVisionClosedGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 2,
            revision: 2
        )
        let releasesBeforeSceneLoss = mediaEnvironment
            .currentReleasedInputApplications().count
        mediaEnvironment.blockNextRelease()
        model.receiveTVVisionGeometryUpdate(sceneLoss)
        await waitUntil { mediaEnvironment.hasBlockedRelease() }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            releasesBeforeSceneLoss + 1
        )
        XCTAssertTrue(model.tvRemoteInputReleasePending)
        XCTAssertFalse(model.tvStreamOverlayVisible)
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: replacementSurface),
            .local
        )
        let inputCountBeforeStaleSceneCallbacks = mediaEnvironment
            .currentSentInputApplications().count
        model.receiveTVGameControllerRoster(controllerRoster)
        model.receiveTVGameControllerMotion(try TVGameControllerMotionSample(
            lease: lease,
            type: .accelerometer,
            x: 13,
            y: 14,
            z: 15
        ))
        model.receiveTVGameControllerMotion(try TVGameControllerMotionSample(
            lease: currentLease,
            type: .accelerometer,
            x: 16,
            y: 17,
            z: 18
        ))
        mediaEnvironment.yieldFeedback(.led(ControllerLEDFeedback(
            controllerID: currentControllerID,
            red: 7,
            green: 8,
            blue: 9
        )), sessionID: record.sessionID)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.tvControllerRosterState, thirdRoster)
        XCTAssertNil(model.tvControllerFeedbackDecisionState)
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().count,
            inputCountBeforeStaleSceneCallbacks
        )
        model.receiveTVVisionGeometryUpdate(sceneLoss)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            releasesBeforeSceneLoss + 1
        )
        mediaEnvironment.resumeBlockedRelease()
        await waitUntil {
            model.tvStreamOverlayVisible
                && !model.tvRemoteInputReleasePending
        }

        model.setTVStreamOverlayVisible(false)
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionActiveGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 2,
                revision: 3
            )
        )
        await waitUntil {
            model.tvRemoteSurfacePressDisposition(for: replacementSurface)
                == .captured
        }
        let releasesBeforeStop = mediaEnvironment
            .currentReleasedInputApplications().count
        mediaEnvironment.blockNextRelease()
        let stopTask = Task { await model.stopStream() }
        await waitUntil { mediaEnvironment.hasBlockedRelease() }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            releasesBeforeStop + 1
        )
        XCTAssertTrue(mediaEnvironment.currentStoppedSessionIDs().isEmpty)
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: replacementSurface),
            .local
        )
        mediaEnvironment.resumeBlockedRelease()
        await stopTask.value
        XCTAssertFalse(model.tvRemoteInputReleasePending)
        XCTAssertTrue(model.tvStreamOverlayVisible)
        XCTAssertNil(model.tvControllerRosterState)
        XCTAssertNil(model.tvControllerRoutedRosterState)
        XCTAssertNil(model.tvControllerFeedbackDecisionState)
        let inputCountAfterStop = mediaEnvironment
            .currentSentInputApplications().count
        model.receiveTVGameControllerRoster(thirdRoster)
        model.receiveTVGameControllerMotion(try TVGameControllerMotionSample(
            lease: currentLease,
            type: .accelerometer,
            x: 19,
            y: 20,
            z: 21
        ))
        mediaEnvironment.yieldFeedback(.led(ControllerLEDFeedback(
            controllerID: currentControllerID,
            red: 10,
            green: 11,
            blue: 12
        )), sessionID: record.sessionID)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.tvControllerRosterState)
        XCTAssertNil(model.tvControllerRoutedRosterState)
        XCTAssertNil(model.tvControllerFeedbackDecisionState)
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().count,
            inputCountAfterStop
        )
        await launchTask.value
    }

    func testTVVisionApplicationFailurePreservesConsumedTerminalStateUntilStop()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(
            blocksFailingTVVisionActivationAfterTerminalEvent: true
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 73,
                    key: Data(repeating: 0x73, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionClosedGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 1
            )
        )
        await waitUntil { mediaEnvironment.hasBlockedTVVisionActivation() }
        await waitUntil {
            model.tvVisionPlatformPresentationState?.snapshot.phase
                == .failed(.invalidComponent(.video))
        }
        let terminal = model.tvVisionPlatformPresentationState
        mediaEnvironment.resumeBlockedTVVisionActivation()
        for _ in 0..<20 { await Task.yield() }

        XCTAssertEqual(model.tvVisionPlatformPresentationState, terminal)
        XCTAssertNil(model.tvVisionPlatformPresentationSnapshot)

        await model.stopStream()
        await launchTask.value
        XCTAssertNil(model.tvVisionPlatformPresentationState)
    }

    func testTVRemoteProviderReleaseFailureRestoresLocalUIAndFailsClosed()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 77,
                    key: Data(repeating: 0x77, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        model.setTVStreamWorkspaceVisible(true)

        let initialGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 1,
            revision: 1
        )
        let surface = initialGeometry.surfaceGeneration
        model.receiveTVVisionGeometryUpdate(initialGeometry)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 3
        }
        model.setTVStreamOverlayVisible(false)
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionActiveGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 2
            )
        )
        await waitUntil {
            model.tvRemoteSurfacePressDisposition(for: surface) == .captured
        }

        let releasesBeforeFailure = mediaEnvironment
            .currentReleasedInputApplications().count
        mediaEnvironment.failNextRelease()
        model.receiveTVRemoteReservedCommand(.backMenu)
        await waitUntil {
            model.tvStreamOverlayVisible
                && !model.tvRemoteInputReleasePending
        }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            releasesBeforeFailure + 1
        )
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )

        model.setTVStreamOverlayVisible(false)
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionActiveGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 3
            )
        )
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )

        await model.stopStream()
        await launchTask.value
    }

    func testTVVisionMediaFailurePreservesOnlyTerminalBoundedState()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 74,
                    key: Data(repeating: 0x74, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        let terminal = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 2,
            phase: .stopped(.failure)
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            terminal,
            sessionID: record.sessionID
        )
        await waitUntil { model.tvVisionPlatformPresentationState == terminal }

        mediaEnvironment.finish(
            sessionID: record.sessionID,
            throwing: MediaEnvironmentApplicationTestError.failed
        )
        await launchTask.value

        guard case .failed = model.session.phase else {
            return XCTFail("A media environment failure must fail the session.")
        }
        XCTAssertEqual(model.tvVisionPlatformPresentationState, terminal)
        XCTAssertNil(model.tvVisionPlatformPresentationSnapshot)
        XCTAssertFalse(model.hasActiveStreamSession)
    }

    func testAppModelReflectsMobileSuspensionAndForegroundRestoration()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 40,
                    key: Data(repeating: 0x40, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        let suspended = try makeMobileRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            revision: 1,
            sceneActivity: .background
        )
        mediaEnvironment.yieldMobileRuntime(
            suspended,
            sessionID: record.sessionID
        )
        await waitUntil { model.mobileRuntimeState == suspended }
        XCTAssertEqual(
            model.session.phase,
            .suspending(reason: "no-active-permitted-media-path")
        )
        XCTAssertTrue(model.session.isStreaming)
        XCTAssertEqual(
            model.renderState.policy,
            .paused(reason: "no-active-permitted-media-path")
        )

        let restored = try makeMobileRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            revision: 2,
            sceneActivity: .active,
            foregroundRestorationCount: 1
        )
        mediaEnvironment.yieldMobileRuntime(
            restored,
            sessionID: record.sessionID
        )
        await waitUntil { model.mobileRuntimeState == restored }
        XCTAssertEqual(model.session.phase, .streaming)
        XCTAssertEqual(model.renderState.policy, .active)

        await model.stopStream()
        await launchTask.value
        XCTAssertNil(model.mobileRuntimeState)
        XCTAssertEqual(model.session.phase, .disconnected)
    }

    func testMobileContinuityRegressionProjectsActualStateAcrossReplacementAndCleanStop()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 41,
                    key: Data(repeating: 0x41, count: 16)
                )),
                .success(RemoteInputKeyMaterial(
                    keyID: 42,
                    key: Data(repeating: 0x42, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let firstLaunch = Task { await model.launchSelectedApp() }
        let firstRecord = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: firstRecord)
        await waitUntil { model.session.isStreaming }
        model.diagnostics.record(
            ApplicationDiagnosticFactory.streamFailure(
                VideoDecoderError.noActiveSession
            )
        )

        let pictureInPicture = try makeMobileRuntimeState(
            sessionID: firstRecord.sessionID,
            mediaGeneration: 1,
            revision: 1,
            sceneActivity: .background,
            pictureInPictureLifecycle: .active,
            includesActualSceneAndDisplay: true
        )
        mediaEnvironment.yieldMobileRuntime(
            pictureInPicture,
            sessionID: firstRecord.sessionID
        )
        await waitUntil { model.mobileRuntimeState == pictureInPicture }
        XCTAssertEqual(model.mobileExperiencePresentationStatus.scene, .background)
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.pictureInPicture,
            .active
        )
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.continuity,
            .pictureInPicture
        )
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.display,
            .edrCapable(potentialHeadroom: 4, currentHeadroom: 2)
        )
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.pictureInPictureCommand,
            .stop
        )
        XCTAssertEqual(
            model.renderState.policy,
            .paused(reason: "picture-in-picture-active")
        )

        let duplicatePictureInPicture = try makeMobileRuntimeState(
            sessionID: firstRecord.sessionID,
            mediaGeneration: 1,
            revision: 2,
            sceneActivity: .background,
            pictureInPictureLifecycle: .active,
            includesActualSceneAndDisplay: true
        )
        mediaEnvironment.yieldMobileRuntime(
            duplicatePictureInPicture,
            sessionID: firstRecord.sessionID
        )
        await waitUntil {
            model.mobileRuntimeState == duplicatePictureInPicture
        }
        XCTAssertEqual(
            model.diagnostics.events.filter {
                $0.code == "mobile_continuity_pip"
            }.count,
            1
        )

        let audioOnly = try makeMobileRuntimeState(
            sessionID: firstRecord.sessionID,
            mediaGeneration: 1,
            revision: 3,
            sceneActivity: .background,
            isAudioSessionActive: true,
            includesActualSceneAndDisplay: true
        )
        mediaEnvironment.yieldMobileRuntime(
            audioOnly,
            sessionID: firstRecord.sessionID
        )
        await waitUntil { model.mobileRuntimeState == audioOnly }
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.continuity,
            .audioOnly
        )
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.pictureInPicture,
            .unavailable
        )

        let policyLoss = try makeMobileRuntimeState(
            sessionID: firstRecord.sessionID,
            mediaGeneration: 1,
            revision: 4,
            sceneActivity: .background,
            includesActualSceneAndDisplay: true
        )
        mediaEnvironment.yieldMobileRuntime(
            policyLoss,
            sessionID: firstRecord.sessionID
        )
        await waitUntil { model.mobileRuntimeState == policyLoss }
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.continuity,
            .paused
        )
        XCTAssertEqual(
            model.session.phase,
            .suspending(reason: "no-active-permitted-media-path")
        )

        let foreground = try makeMobileRuntimeState(
            sessionID: firstRecord.sessionID,
            mediaGeneration: 1,
            revision: 5,
            sceneActivity: .active,
            foregroundRestorationCount: 1,
            includesActualSceneAndDisplay: true
        )
        mediaEnvironment.yieldMobileRuntime(
            foreground,
            sessionID: firstRecord.sessionID
        )
        await waitUntil { model.mobileRuntimeState == foreground }
        XCTAssertEqual(model.mobileExperiencePresentationStatus.scene, .active)
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.continuity,
            .foreground
        )
        XCTAssertEqual(model.renderState.policy, .active)
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.category,
            .decoder
        )

        let firstMobileEvents = model.diagnostics.events.filter {
            $0.code.hasPrefix("mobile_")
        }
        for event in firstMobileEvents {
            XCTAssertFalse(event.message.contains(firstRecord.sessionID.uuidString))
            XCTAssertFalse(event.message.contains("moon.local"))
        }

        await model.stopStream()
        await firstLaunch.value
        XCTAssertNil(model.mobileRuntimeState)
        XCTAssertNil(model.mobileSceneWindowSnapshot)
        XCTAssertNil(model.mobileDisplayEDRSnapshot)
        XCTAssertNil(model.mobilePictureInPictureSnapshot)
        XCTAssertNil(model.mobileAudioSessionActive)
        XCTAssertEqual(model.mobileExperiencePresentationStatus.scene, .noSession)
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.pictureInPicture,
            .noSession
        )
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.continuity,
            .noSession
        )
        XCTAssertEqual(model.mobileExperiencePresentationStatus.display, .noSession)

        let replacementLaunch = Task { await model.launchSelectedApp() }
        await waitUntil { provider.currentStartRecords().count == 2 }
        let replacementRecord = try XCTUnwrap(provider.currentStartRecords().last)
        driveSessionToStreaming(provider, record: replacementRecord)
        await waitUntil { model.session.isStreaming }
        let replacementPictureInPicture = try makeMobileRuntimeState(
            sessionID: replacementRecord.sessionID,
            mediaGeneration: 2,
            revision: 1,
            sceneActivity: .background,
            pictureInPictureLifecycle: .active,
            includesActualSceneAndDisplay: true
        )
        mediaEnvironment.yieldMobileRuntime(
            replacementPictureInPicture,
            sessionID: replacementRecord.sessionID
        )
        await waitUntil {
            model.mobileRuntimeState == replacementPictureInPicture
        }
        XCTAssertNotEqual(firstRecord.sessionID, replacementRecord.sessionID)
        XCTAssertEqual(
            model.diagnostics.events.filter {
                $0.code == "mobile_continuity_pip"
            }.count,
            2
        )
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.continuity,
            .pictureInPicture
        )

        await model.stopStream()
        await replacementLaunch.value
        XCTAssertNil(model.mobileRuntimeState)
        XCTAssertEqual(model.mobileExperiencePresentationStatus.scene, .noSession)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertEqual(mediaEnvironment.currentStoppedSessionIDs().count, 2)
    }

    func testAppModelBindsSpatialPreferencesAndCurrentAudioRuntime() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let persistedPreferences = SessionSpatialAudioPreferences(
            spatialAudioEnabled: true,
            headTrackingEnabled: false
        )
        var persistedSettings = AppSettings.defaults
        persistedSettings.audio = AudioPreferences(persistedPreferences)
        let settingsRepository = InMemoryAppSettingsRepository(
            settings: persistedSettings
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 41,
                    key: Data(repeating: 0x41, count: 16)
                ))
            ]),
            settingsRepository: settingsRepository
        )

        await model.loadInitialState()
        XCTAssertEqual(model.spatialAudioPreferences, persistedPreferences)
        XCTAssertEqual(model.settings.audio, AudioPreferences(persistedPreferences))
        XCTAssertNil(model.audioRuntimeState)
        XCTAssertEqual(model.spatialAudioPresentationStatus, .inactive)
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil {
            model.session.isStreaming
                && mediaEnvironment
                    .currentSpatialAudioPreferenceApplications().count == 1
        }

        XCTAssertEqual(
            mediaEnvironment.currentSpatialAudioPreferenceApplications(),
            [SessionSpatialAudioPreferenceApplication(
                sessionID: record.sessionID,
                mediaGeneration: 1,
                preferences: persistedPreferences
            )]
        )
        let current = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            sequence: 0,
            graphGeneration: 1,
            preferences: persistedPreferences,
            spatialRuntime: SpatialAudioRuntimeSnapshot(
                revision: SpatialAudioSemanticRevision(rawValue: 1),
                layoutSignature: StreamAudioChannelLayout.stereo.signature,
                graphMode: .environmentAmbienceBed,
                platformStrategy: .environmentListener,
                routeSupport: .supported,
                presentationMode: .fixedSpatial,
                fallbackReason: .missingEntitlement
            )
        )
        mediaEnvironment.yieldAudioRuntime(current, sessionID: record.sessionID)
        await waitUntil { model.audioRuntimeState == current }
        XCTAssertEqual(
            model.spatialAudioPresentationStatus,
            SpatialAudioPresentationStatus(
                mode: .fixedSpatial,
                fallback: .missingEntitlement
            )
        )
        XCTAssertEqual(
            model.diagnostics.events
                .filter { $0.code.hasPrefix("spatial_audio_") }
                .map(\.code),
            ["spatial_audio_missing_entitlement"]
        )
        model.diagnostics.record(ApplicationDiagnosticFactory.pairingUnavailable)
        model.diagnostics.record(
            ApplicationDiagnosticFactory.streamFailure(NetworkChannelError.closed)
        )
        model.diagnostics.record(
            ApplicationDiagnosticFactory.streamFailure(
                VideoDecoderError.noActiveSession
            )
        )
        model.diagnostics.record(
            ApplicationDiagnosticFactory.hdrPresentationState(.pipelineFailure)!
        )
        model.diagnostics.record(
            ApplicationDiagnosticFactory.streamFailure(
                RemoteInputRuntimeError.deliveryFailed
            )
        )
        XCTAssertEqual(
            model.diagnostics.currentActionableEvent(in: .audio)?.code,
            "spatial_audio_missing_entitlement"
        )

        let recovered = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            sequence: 1,
            graphGeneration: 2,
            preferences: persistedPreferences,
            spatialRuntime: SpatialAudioRuntimeSnapshot(
                revision: SpatialAudioSemanticRevision(rawValue: 2),
                layoutSignature: StreamAudioChannelLayout.stereo.signature,
                graphMode: .environmentAmbienceBed,
                platformStrategy: .environmentListener,
                routeSupport: .supported,
                presentationMode: .fixedSpatial,
                fallbackReason: nil
            )
        )
        mediaEnvironment.yieldAudioRuntime(recovered, sessionID: record.sessionID)
        await waitUntil { model.audioRuntimeState == recovered }
        XCTAssertEqual(
            model.spatialAudioPresentationStatus,
            SpatialAudioPresentationStatus(
                mode: .fixedSpatial,
                fallback: nil
            )
        )
        let equivalentRecovery = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            sequence: 2,
            graphGeneration: 2,
            preferences: persistedPreferences,
            spatialRuntime: recovered.runtime.spatialRuntime
        )
        mediaEnvironment.yieldAudioRuntime(
            equivalentRecovery,
            sessionID: record.sessionID
        )
        await waitUntil { model.audioRuntimeState == equivalentRecovery }

        XCTAssertNil(model.diagnostics.currentActionableEvent(in: .audio))
        XCTAssertEqual(
            model.diagnostics.currentActionableEvent(in: .pairing)?.code,
            "pairing_provider_unavailable"
        )
        XCTAssertEqual(
            model.diagnostics.currentActionableEvent(in: .transport)?.code,
            "transport_failed"
        )
        XCTAssertEqual(
            model.diagnostics.currentActionableEvent(in: .decoder)?.code,
            "video_pipeline_failed"
        )
        XCTAssertEqual(
            model.diagnostics.currentActionableEvent(in: .hdr)?.code,
            "hdr_pipeline_failure"
        )
        XCTAssertEqual(
            model.diagnostics.currentActionableEvent(in: .input)?.code,
            "input_delivery_failed"
        )
        XCTAssertEqual(
            model.diagnostics.events
                .filter { $0.code == "spatial_audio_active_fixed" }
                .count,
            2
        )

        let updatedPreferences = SessionSpatialAudioPreferences(
            spatialAudioEnabled: false,
            headTrackingEnabled: false
        )
        try await model.updateSpatialAudioPreferences(updatedPreferences)
        await waitUntil {
            mediaEnvironment
                .currentSpatialAudioPreferenceApplications().count == 2
        }
        XCTAssertEqual(model.spatialAudioPreferences, updatedPreferences)
        XCTAssertEqual(model.settings.audio, AudioPreferences(updatedPreferences))
        XCTAssertEqual(
            model.spatialAudioPresentationStatus,
            SpatialAudioPresentationStatus(
                mode: .fixedSpatial,
                fallback: nil
            )
        )
        XCTAssertEqual(
            mediaEnvironment.currentSpatialAudioPreferenceApplications().last,
            SessionSpatialAudioPreferenceApplication(
                sessionID: record.sessionID,
                mediaGeneration: 1,
                preferences: updatedPreferences
            )
        )

        let wrongGeneration = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 2,
            sequence: 100,
            graphGeneration: 100,
            preferences: .nativeDefault
        )
        mediaEnvironment.yieldAudioRuntime(
            wrongGeneration,
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.audioRuntimeState, equivalentRecovery)
        XCTAssertEqual(
            model.diagnostics.events
                .filter { $0.code.hasPrefix("spatial_audio_") }
                .map(\.code),
            [
                "spatial_audio_missing_entitlement",
                "spatial_audio_active_fixed",
                "spatial_audio_active_fixed"
            ]
        )

        await model.saveSettings()
        let savedSettings = try await settingsRepository.loadSettings()
        XCTAssertEqual(
            savedSettings.audio,
            AudioPreferences(updatedPreferences)
        )
        await model.stopStream()
        await launchTask.value
        XCTAssertNil(model.audioRuntimeState)
        XCTAssertEqual(model.spatialAudioPresentationStatus, .inactive)
        XCTAssertEqual(
            model.diagnostics.events
                .filter { $0.code.hasPrefix("spatial_audio_") }
                .map(\.code),
            [
                "spatial_audio_missing_entitlement",
                "spatial_audio_active_fixed",
                "spatial_audio_active_fixed",
                "spatial_audio_inactive"
            ]
        )
        XCTAssertEqual(model.spatialAudioPreferences, updatedPreferences)
    }

    func testReconnectClearsAudioRuntimeAndRejectsPriorMediaGeneration() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 42,
                    key: Data(repeating: 0x42, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        let first = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            sequence: 0,
            graphGeneration: 1
        )
        mediaEnvironment.yieldAudioRuntime(first, sessionID: record.sessionID)
        await waitUntil { model.audioRuntimeState == first }

        mediaEnvironment.blockNextStop()
        provider.yield(
            .reconnecting(attempt: 1, reason: "Control channel interrupted."),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.hasBlockedStop() }
        XCTAssertNil(model.audioRuntimeState)
        mediaEnvironment.resumeBlockedStop()
        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey
            )),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.currentStartRecords().count == 2 }

        let stale = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            sequence: 99,
            graphGeneration: 99
        )
        mediaEnvironment.yieldAudioRuntime(stale, sessionID: record.sessionID)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.audioRuntimeState)

        let replacement = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 2,
            sequence: 0,
            graphGeneration: 1
        )
        mediaEnvironment.yieldAudioRuntime(
            replacement,
            sessionID: record.sessionID
        )
        await waitUntil { model.audioRuntimeState == replacement }

        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launchTask.value
        XCTAssertNil(model.audioRuntimeState)
    }

    func testNativeApplicationIntegrationCoversSpatialAudioReplacementAndCleanStop()
        async throws
    {
        let control = ControlledSessionControlProvider()
        let videoReceive = ApplicationIntegrationVideoReceiveProvider()
        let audioReceive = ApplicationIntegrationAudioReceiveProvider()
        let remoteInput = ApplicationIntegrationRemoteInputProvider()
        let videoProcessors = ApplicationIntegrationVideoProcessorFactory()
        let audioRegistry = ApplicationIntegrationAudioRegistry(
            initialCapability: applicationIntegrationRouteCapability(.supported)
        )
        let audioFactory = NativeSessionAudioProcessorFactory(
            entitlementReader: ApplicationIntegrationEntitlementReader(state: .missing),
            decoderFactory: { configuration in
                try audioRegistry.makeDecoder(configuration: configuration)
            },
            engineClientFactory: {
                audioRegistry.makeEngine()
            },
            routeEventSourceFactory: {
                audioRegistry.makeRouteSource()
            },
            eventTimeProvider: {
                audioRegistry.nextEventTime()
            }
        )
        let environment = NativeSessionMediaEnvironment(
            videoReceiveProvider: videoReceive,
            audioReceiveProvider: audioReceive,
            remoteInputProvider: remoteInput,
            videoProcessorFactory: videoProcessors,
            audioProcessorFactory: audioFactory,
            teardownGracePeriod: .seconds(1)
        )
        let runtimeProviders = RuntimeProviderInventory(
            sessionControl: control,
            videoReceive: videoReceive,
            audioReceive: audioReceive,
            remoteInput: remoteInput
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: control,
            sessionMediaEnvironment: environment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 46,
                    key: Data(repeating: 0x46, count: 16)
                ))
            ]),
            runtimeProviders: runtimeProviders
        )
        let audioConfiguration = try makeWave7Point1AudioConfiguration()

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(control)
        let configuration = makeSessionConfiguration(
            sessionID: record.sessionID,
            keyMaterial: record.request.remoteInputKey,
            audioConfiguration: audioConfiguration
        )

        control.yield(.launchAccepted(makeSessionLaunchResponse()), sessionID: record.sessionID)
        control.yield(.rtspReady, sessionID: record.sessionID)
        control.yield(.negotiated(configuration), sessionID: record.sessionID)
        control.yield(.channelsReady(.all), sessionID: record.sessionID)
        await waitUntil {
            videoReceive.startCount() == 1
                && audioReceive.startCount() == 1
                && audioRegistry.engineCount() == 1
                && model.audioRuntimeState != nil
        }

        let firstState = try XCTUnwrap(model.audioRuntimeState)
        let firstSpatial = try XCTUnwrap(firstState.runtime.spatialRuntime)
        let firstEngine = try XCTUnwrap(audioRegistry.engine(at: 0))
        let firstDecoder = try XCTUnwrap(audioRegistry.decoder(at: 0))
        let firstSource = try XCTUnwrap(audioRegistry.routeSource(at: 0))
        XCTAssertEqual(firstState.mediaGeneration, 1)
        XCTAssertEqual(firstState.runtime.graphGeneration, 1)
        XCTAssertEqual(firstSpatial.presentationMode, .fixedSpatial)
        XCTAssertEqual(firstSpatial.fallbackReason, .missingEntitlement)
        XCTAssertEqual(
            firstSpatial.diagnosticCode,
            "spatial_audio_fixed-spatial_missing-entitlement"
        )
        XCTAssertEqual(firstEngine.configurations().map(\.channelLayout), [.wave7Point1])
        XCTAssertEqual(firstEngine.graphIntents().map(\.entitlement), [.missing])
        XCTAssertEqual(firstEngine.graphModes(), [.environmentAmbienceBed])
        XCTAssertEqual(firstDecoder.configuration(), audioConfiguration)
        XCTAssertFalse(model.session.isStreaming)

        videoReceive.yield(
            .packet(ReceivedVideoPacket(
                sequenceNumber: 1,
                frameIndex: 1,
                receiveTimeNanoseconds: 1,
                isFirstPacket: true,
                isLastPacket: true,
                payload: Data([0x01])
            )),
            startIndex: 0
        )
        await waitUntil { videoProcessors.consumeCount(at: 0) == 1 }
        XCTAssertFalse(model.session.isStreaming)

        audioReceive.yield(
            .packet(ReceivedAudioPacket(
                sequenceNumber: 1,
                timestamp: 0,
                receiveTimeNanoseconds: 1_000_000,
                payload: Data([0xA1])
            )),
            startIndex: 0
        )
        audioReceive.yield(
            .packet(ReceivedAudioPacket(
                sequenceNumber: 2,
                timestamp: 240,
                receiveTimeNanoseconds: 12_000_000,
                payload: Data([0xA2])
            )),
            startIndex: 0
        )
        await waitUntil {
            model.session.isStreaming && !firstEngine.scheduledBuffers().isEmpty
        }
        let firstPCM = try XCTUnwrap(firstEngine.scheduledBuffers().first)
        XCTAssertEqual(firstPCM.format.channelLayout, .wave7Point1)
        XCTAssertEqual(firstPCM.format.channelCount, 8)
        XCTAssertEqual(firstPCM.frameCount, 240)
        XCTAssertEqual(firstPCM.interleavedSamples.count, 1_920)

        firstEngine.setCapability(applicationIntegrationRouteCapability(.unsupported))
        firstSource.emit(.routeChanged)
        await waitUntil {
            model.audioRuntimeState?.runtime.spatialRuntime?.fallbackReason
                == .routeUnsupported
        }
        let downgraded = try XCTUnwrap(model.audioRuntimeState)
        let downgradedSpatial = try XCTUnwrap(downgraded.runtime.spatialRuntime)
        XCTAssertEqual(downgraded.runtime.sequence, 1)
        XCTAssertEqual(downgraded.runtime.graphGeneration, 2)
        XCTAssertEqual(downgradedSpatial.presentationMode, .nonspatial)
        XCTAssertEqual(downgradedSpatial.fallbackReason, .routeUnsupported)
        XCTAssertEqual(
            downgradedSpatial.diagnosticCode,
            "spatial_audio_nonspatial_route-unsupported"
        )

        control.yield(
            .reconnecting(attempt: 1, reason: "Control channel interrupted."),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.audioRuntimeState == nil
                && firstEngine.wasStopped()
                && firstDecoder.isClosed()
                && firstSource.wasStopped()
                && videoProcessors.wasStopped(at: 0)
                && videoReceive.stopCount() == 1
                && audioReceive.stopCount() == 1
        }
        XCTAssertFalse(model.session.isStreaming)
        let firstGenerationSnapshot = await waitForEnvironmentTeardown(environment)
        XCTAssertNil(firstGenerationSnapshot.sessionID)
        XCTAssertNil(firstGenerationSnapshot.audioRuntime)
        XCTAssertTrue(firstGenerationSnapshot.lastTeardownReport?.isClean == true)

        firstEngine.setCapability(applicationIntegrationRouteCapability(.supported))
        firstSource.emitLate(.routeChanged)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.audioRuntimeState)
        XCTAssertEqual(firstEngine.graphIntents().count, 2)

        control.yield(.rtspReady, sessionID: record.sessionID)
        control.yield(.negotiated(configuration), sessionID: record.sessionID)
        await waitUntil {
            videoReceive.startCount() == 2
                && audioReceive.startCount() == 2
                && audioRegistry.engineCount() == 2
                && model.audioRuntimeState?.mediaGeneration == 2
        }
        control.yield(.channelsReady(.control), sessionID: record.sessionID)
        let replacement = try XCTUnwrap(model.audioRuntimeState)
        let replacementSpatial = try XCTUnwrap(replacement.runtime.spatialRuntime)
        let replacementEngine = try XCTUnwrap(audioRegistry.engine(at: 1))
        let replacementDecoder = try XCTUnwrap(audioRegistry.decoder(at: 1))
        let replacementSource = try XCTUnwrap(audioRegistry.routeSource(at: 1))
        XCTAssertEqual(replacement.runtime.sequence, 0)
        XCTAssertEqual(replacement.runtime.graphGeneration, 1)
        XCTAssertEqual(replacementSpatial.presentationMode, .fixedSpatial)
        XCTAssertEqual(replacementSpatial.fallbackReason, .missingEntitlement)
        XCTAssertEqual(replacementEngine.graphModes(), [.environmentAmbienceBed])
        XCTAssertFalse(model.session.isStreaming)

        videoReceive.yield(
            .packet(ReceivedVideoPacket(
                sequenceNumber: 2,
                frameIndex: 2,
                receiveTimeNanoseconds: 2,
                isFirstPacket: true,
                isLastPacket: true,
                payload: Data([0x02])
            )),
            startIndex: 1
        )
        audioReceive.yield(
            .packet(ReceivedAudioPacket(
                sequenceNumber: 3,
                timestamp: 480,
                receiveTimeNanoseconds: 2_000_000,
                payload: Data([0xA3])
            )),
            startIndex: 1
        )
        audioReceive.yield(
            .packet(ReceivedAudioPacket(
                sequenceNumber: 4,
                timestamp: 720,
                receiveTimeNanoseconds: 13_000_000,
                payload: Data([0xA4])
            )),
            startIndex: 1
        )
        await waitUntil {
            model.session.isStreaming && !replacementEngine.scheduledBuffers().isEmpty
        }

        await model.stopStream()
        await launchTask.value
        let stoppedSnapshot = await environment.snapshot()
        let remoteInputSnapshot = remoteInput.snapshot()
        XCTAssertNil(model.audioRuntimeState)
        XCTAssertEqual(model.spatialAudioPreferences, .nativeDefault)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertNil(stoppedSnapshot.sessionID)
        XCTAssertNil(stoppedSnapshot.audioRuntime)
        XCTAssertEqual(stoppedSnapshot.activeTaskCount, 0)
        XCTAssertEqual(stoppedSnapshot.activeResourceCount, 0)
        XCTAssertTrue(stoppedSnapshot.lastTeardownReport?.isClean == true)
        XCTAssertEqual(videoReceive.stopCount(), 2)
        XCTAssertEqual(audioReceive.stopCount(), 2)
        XCTAssertEqual(remoteInputSnapshot.startCount, 2)
        XCTAssertEqual(remoteInputSnapshot.releaseCount, 4)
        XCTAssertEqual(remoteInputSnapshot.stopCount, 2)
        XCTAssertTrue(videoProcessors.wasStopped(at: 1))
        XCTAssertTrue(replacementEngine.wasStopped())
        XCTAssertTrue(replacementDecoder.isClosed())
        XCTAssertTrue(replacementSource.wasStopped())
        XCTAssertEqual(control.currentStoppedSessionIDs(), [record.sessionID])
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
        let audioRuntime = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            sequence: 0,
            graphGeneration: 1
        )
        mediaEnvironment.yieldAudioRuntime(
            audioRuntime,
            sessionID: record.sessionID
        )
        await waitUntil { model.audioRuntimeState == audioRuntime }

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
        XCTAssertNil(model.audioRuntimeState)
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

    func testMacDiagnosticsDeduplicateAndClearOnlyRecoveredActions() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(failsInputSend: true)
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 36,
                    key: Data(repeating: 0x36, count: 16)
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

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.macInputSurfacePolicy.admitsInput }
        XCTAssertTrue(model.diagnostics.events.contains { $0.code == "mac_lifecycle_active" })
        XCTAssertTrue(model.diagnostics.events.contains { $0.code == "mac_input_relative_ready" })

        model.diagnostics.record(
            ApplicationDiagnosticFactory.streamFailure(VideoDecoderError.noActiveSession)
        )
        XCTAssertEqual(
            model.submitMacPlatformInput(.pointerMove(MacPointerSample(
                localPoint: RemotePoint(x: 1_280, y: 720),
                deltaX: 4,
                deltaY: -2,
                buttons: []
            ))),
            .accepted
        )
        await waitUntil {
            model.diagnostics.latestStreamActionableEvent?.category == .input
                && model.macSessionInputSnapshot().terminationReason == .sendFailure
                && !model.macInputSurfacePolicy.admitsInput
        }
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.code,
            "input_delivery_failed"
        )

        lifecycle.isFocused = false
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        let lifecycleEventCount = model.diagnostics.events.filter {
            $0.code.hasPrefix("mac_lifecycle_")
        }.count
        model.applyPlatformLifecycle(lifecycle)
        XCTAssertEqual(
            model.diagnostics.events.filter { $0.code.hasPrefix("mac_lifecycle_") }.count,
            lifecycleEventCount
        )
        XCTAssertEqual(model.diagnostics.latestStreamActionableEvent?.category, .input)
        XCTAssertTrue(model.diagnostics.events.contains { $0.code == "mac_lifecycle_unfocused" })

        mediaEnvironment.yieldReadiness(
            [.video, .audio],
            sessionID: record.sessionID
        )
        await waitUntil { model.macSessionInputSnapshot().generation == nil }
        mediaEnvironment.yieldReadiness(
            [.video, .audio, .input],
            sessionID: record.sessionID
        )
        await waitUntil {
            model.macSessionInputSnapshot().generation != nil
                && model.diagnostics.latestStreamActionableEvent?.category == .decoder
        }
        XCTAssertEqual(model.diagnostics.latestStreamActionableEvent?.category, .decoder)

        lifecycle.isVisible = false
        lifecycle.isFocused = true
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        XCTAssertEqual(model.diagnostics.latestStreamActionableEvent?.category, .decoder)
        XCTAssertTrue(model.diagnostics.events.contains { $0.code == "mac_lifecycle_occluded" })

        let historicalActionCount = model.diagnostics.events.filter {
            $0.action != nil || $0.severity == .error
        }.count
        await model.stopStream()
        await launchTask.value

        XCTAssertNil(model.diagnostics.latestStreamActionableEvent)
        XCTAssertGreaterThanOrEqual(
            model.diagnostics.events.filter { $0.action != nil || $0.severity == .error }.count,
            historicalActionCount
        )
        let publicStateEvents = model.diagnostics.events.filter {
            $0.code.hasPrefix("mac_lifecycle_") || $0.code.hasPrefix("mac_input_")
        }
        for event in publicStateEvents {
            XCTAssertFalse(event.message.contains(record.sessionID.uuidString))
            XCTAssertFalse(event.message.contains("moon.local"))
            XCTAssertFalse(event.message.contains("2560"))
            XCTAssertFalse(event.message.contains("1440"))
        }
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
        videoPresentationSource: StreamVideoPresentationSource? = nil,
        tvVisionPlatform: TVVisionPlatform? = nil,
        launchClient: StubStreamLaunchClient,
        remoteInputKeyGenerator: any RemoteInputKeyMaterialGenerating,
        runtimeProviders: RuntimeProviderInventory? = nil,
        settingsRepository: any AppSettingsRepository =
            InMemoryAppSettingsRepository()
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
            settingsRepository: settingsRepository,
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
            videoPresentationSource: videoPresentationSource,
            tvVisionPlatform: tvVisionPlatform,
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

    private func makeTVVisionClosedGeometryUpdate(
        platform: TVVisionPlatform,
        surfaceGeneration: UInt64,
        revision: UInt64
    ) throws -> TVVisionStreamGeometryBindingUpdate {
        TVVisionStreamGeometryBindingUpdate(
            platform: platform,
            surfaceGeneration: try TVVisionGeneration(
                domain: .surface,
                rawValue: surfaceGeneration
            ),
            revision: try TVVisionSemanticRevision(rawValue: revision),
            status: .closed(.detached),
            binding: nil
        )
    }

    private func makeTVVisionActiveGeometryUpdate(
        platform: TVVisionPlatform,
        surfaceGeneration rawSurfaceGeneration: UInt64,
        revision rawRevision: UInt64
    ) throws -> TVVisionStreamGeometryBindingUpdate {
        let surfaceGeneration = try TVVisionGeneration(
            domain: .surface,
            rawValue: rawSurfaceGeneration
        )
        let revision = try TVVisionSemanticRevision(rawValue: rawRevision)
        let geometry = try TVVisionSurfaceGeometry(
            platform: platform,
            surfaceGeneration: surfaceGeneration,
            viewBounds: TVVisionRect(x: 0, y: 0, width: 640, height: 360),
            windowBounds: TVVisionRect(x: 0, y: 0, width: 640, height: 360),
            safeAreaInsets: .zero,
            scale: 2
        )
        let scene = try TVVisionSceneSurfaceSnapshot(
            platform: platform,
            revision: revision,
            surfaceGeneration: surfaceGeneration,
            activity: .active,
            attachment: .attached,
            isVisible: true,
            geometry: geometry
        )
        let sourceSize = PixelSize(width: 1_920, height: 1_080)
        let coordinateSnapshot = try XCTUnwrap(
            StreamCoordinateSnapshot.resolve(
                revision: revision.rawValue,
                sourceSize: sourceSize,
                drawableSize: geometry.drawableSize,
                mode: .fit
            )
        )
        let binding = TVVisionStreamGeometryBindingSnapshot(
            platform: platform,
            surfaceGeneration: surfaceGeneration,
            revision: revision,
            sceneSurfaceSnapshot: scene,
            isFocusEligible: true,
            coordinateSnapshot: coordinateSnapshot,
            inputReferenceSize: sourceSize
        )
        return TVVisionStreamGeometryBindingUpdate(
            platform: platform,
            surfaceGeneration: surfaceGeneration,
            revision: revision,
            status: .active,
            binding: binding
        )
    }

    private func makeTVRemoteSurfacePress(
        _ surfaceGeneration: TVVisionGeneration,
        _ pressID: UInt64,
        _ button: TVRemoteButton,
        _ phase: TVRemoteSurfacePressPhase
    ) throws -> TVRemoteSurfacePressEvent {
        try TVRemoteSurfacePressEvent(
            surfaceGeneration: surfaceGeneration,
            pressID: pressID,
            button: button,
            phase: phase
        )
    }

    private func makeTVVisionPresentationState(
        sessionID: UUID,
        mediaGeneration: UInt64,
        platform: TVVisionPlatform,
        presentationGeneration: UInt64,
        sequence: UInt64,
        phase: TVVisionPlatformPresentationPhase = .active,
        display sourceDisplay: TVVisionDisplaySnapshot? = nil,
        audioRoute sourceAudioRoute: TVVisionAudioRouteSnapshot? = nil,
        isSemanticRevisionExhausted: Bool = false
    ) throws -> SessionTVVisionPlatformPresentationState {
        let ownership = try TVVisionPresentationOwnership(
            platform: platform,
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            presentationGeneration: TVVisionGeneration(
                domain: .presentation,
                rawValue: presentationGeneration
            ),
            inputGeneration: TVVisionGeneration(
                domain: .input,
                rawValue: mediaGeneration
            )
        )
        let revision = try TVVisionSemanticRevision(rawValue: sequence)
        let display = try sourceDisplay.map {
            try TVVisionDisplaySnapshot(
                platform: $0.platform,
                revision: revision,
                displayGeneration: $0.displayGeneration,
                isOutputAvailable: $0.isOutputAvailable,
                headroomSource: $0.headroomSource,
                currentEDRHeadroom: $0.currentEDRHeadroom,
                potentialEDRHeadroom: $0.potentialEDRHeadroom,
                layerCapability: $0.layerCapability,
                tvOSHDRCapabilityResolution: $0.tvOSHDRCapabilityResolution
            )
        }
        let audioRoute = try sourceAudioRoute.map {
            try TVVisionAudioRouteSnapshot(
                platform: $0.platform,
                revision: revision,
                routeGeneration: $0.routeGeneration,
                outputAvailable: $0.outputAvailable,
                currentOutputChannelCount: $0.currentOutputChannelCount,
                maximumOutputChannelCount: $0.maximumOutputChannelCount,
                spatialSupport: $0.spatialSupport,
                platformStrategy: $0.platformStrategy,
                headTrackingCapability: $0.headTrackingCapability,
                runtimeStage: $0.runtimeStage,
                eventCause: $0.eventCause,
                spatialPresentationMode: $0.spatialPresentationMode,
                spatialFallbackReason: $0.spatialFallbackReason
            )
        }
        let presentation = try display.flatMap { display in
            try audioRoute.map { audioRoute in
                let scene = try TVVisionSceneSurfaceSnapshot(
                    platform: platform,
                    revision: revision,
                    surfaceGeneration: TVVisionGeneration(
                        domain: .surface,
                        rawValue: presentationGeneration
                    ),
                    activity: .inactive,
                    attachment: .detached,
                    isVisible: false,
                    geometry: nil
                )
                let input = try TVVisionInputCapabilitySnapshot(
                    platform: platform,
                    revision: revision,
                    inputGeneration: ownership.inputGeneration,
                    supported: [],
                    focusEligibility: .ineligible(.detached)
                )
                return try TVVisionPlatformPresentationSnapshot(
                    ownership: ownership,
                    revision: revision,
                    sceneSurface: scene,
                    inputCapabilities: input,
                    controllerLeases: [],
                    display: display,
                    audioRoute: audioRoute
                )
            }
        }
        return SessionTVVisionPlatformPresentationState(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            snapshot: TVVisionPlatformPresentationCoordinatorSnapshot(
                ownership: ownership,
                sequence: sequence,
                revision: revision,
                phase: phase,
                presentation: phase == .active ? presentation : nil,
                display: phase == .active ? display : nil,
                audioRoute: phase == .active ? audioRoute : nil,
                video: TVVisionPlatformVideoSnapshot(
                    phase: .idle,
                    lastDeliveryRevision: nil,
                    isPresented: false
                ),
                diagnostics: [],
                teardownCount: 0,
                isSemanticRevisionExhausted: isSemanticRevisionExhausted,
                isSequenceExhausted: false
            )
        )
    }

    private func makeTVOSDisplaySnapshot(
        revision: UInt64,
        displayGeneration: UInt64,
        current: Double?,
        potential: Double?
    ) throws -> TVVisionDisplaySnapshot {
        let resolution = TVOSDisplayHDRCapabilityResolver.resolve(
            TVOSDisplayHDRCapabilityInputs(
                isOutputAvailable: true,
                layerCapability: .preferredDynamicRange,
                supportsToneMapControl: true,
                supportsContentsHeadroom: true,
                supportedEDRGamuts: [.displayP3, .ituR2020],
                currentEDRHeadroom: current,
                potentialEDRHeadroom: potential
            )
        )
        let capabilities = resolution.capabilities
        return try TVVisionDisplaySnapshot(
            platform: .tvOS,
            revision: TVVisionSemanticRevision(rawValue: revision),
            displayGeneration: TVVisionGeneration(
                domain: .display,
                rawValue: displayGeneration
            ),
            isOutputAvailable: true,
            headroomSource: capabilities.currentEDRHeadroom == nil
                ? .unavailable
                : .platformReported,
            currentEDRHeadroom: capabilities.currentEDRHeadroom,
            potentialEDRHeadroom: capabilities.potentialEDRHeadroom,
            layerCapability: capabilities.layerCapability,
            tvOSHDRCapabilityResolution: resolution
        )
    }

    private func makeTVOSAudioRouteSnapshot(
        revision: UInt64,
        graphGeneration: UInt64,
        presentationMode: SpatialAudioPresentationMode
    ) throws -> TVVisionAudioRouteSnapshot {
        try TVVisionAudioRouteSnapshot(
            platform: .tvOS,
            revision: TVVisionSemanticRevision(rawValue: revision),
            routeGeneration: TVVisionGeneration(
                domain: .audioRoute,
                rawValue: graphGeneration
            ),
            outputAvailable: true,
            currentOutputChannelCount: 2,
            maximumOutputChannelCount: 8,
            spatialSupport: .supported,
            platformStrategy: .environmentListener,
            headTrackingCapability: .entitlementRequired,
            runtimeStage: .running,
            eventCause: .initial,
            spatialPresentationMode: presentationMode,
            spatialFallbackReason: nil
        )
    }

    private func makeAudioRuntimeState(
        sessionID: UUID,
        mediaGeneration: UInt64,
        sequence: UInt64,
        graphGeneration: UInt64,
        preferences: SessionSpatialAudioPreferences = .nativeDefault,
        spatialRuntime: SpatialAudioRuntimeSnapshot? = nil
    ) -> SessionMediaAudioRuntimeState {
        SessionMediaAudioRuntimeState(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            runtime: SessionAudioRuntimeEvent(
                sessionID: sessionID,
                sequence: sequence,
                graphGeneration: graphGeneration,
                cause: .initial,
                stage: .running,
                spatialRuntime: spatialRuntime,
                routeCapability: SpatialAudioRouteCapabilitySnapshot(
                    revision: spatialRuntime?.revision ?? .init(rawValue: 0),
                    outputAvailable: true,
                    systemSpatialSupport: .supported,
                    currentOutputChannelCount: 2,
                    maximumOutputChannelCount: 8
                ),
                entitlement: .granted,
                preferences: preferences,
                concealedFrameCount: 0,
                lastAction: .none
            )
        )
    }

    private func makeMobileRuntimeState(
        sessionID: UUID,
        mediaGeneration: UInt64,
        revision: UInt64,
        sceneActivity: AppSceneActivity,
        foregroundRestorationCount: UInt64 = 0,
        pictureInPictureLifecycle: MobilePictureInPictureLifecycle? = nil,
        isAudioSessionActive: Bool? = nil,
        includesActualSceneAndDisplay: Bool = false
    ) throws -> SessionMobileRuntimeState {
        let generation = try XCTUnwrap(MobilePictureInPictureGeneration(
            mediaGeneration: mediaGeneration,
            pictureInPictureGeneration: 1
        ))
        let surfaceGeneration = includesActualSceneAndDisplay
            ? try XCTUnwrap(MobileSceneSurfaceGeneration(
                rawValue: mediaGeneration
            ))
            : nil
        let sceneWindow = surfaceGeneration.map {
            MobileSceneWindowSnapshot(
                surfaceGeneration: $0,
                revision: MobileSceneWindowRevision(rawValue: revision),
                state: .attached(
                    activity: sceneActivity,
                    display: MobileDisplayGeneration(rawValue: mediaGeneration)!,
                    geometry: MobileSceneWindowGeometry(
                        viewBounds: MobileSceneRect(
                            x: 0,
                            y: 0,
                            width: 1_024,
                            height: 768
                        ),
                        windowBounds: MobileSceneRect(
                            x: 0,
                            y: 0,
                            width: 1_024,
                            height: 768
                        ),
                        safeAreaInsets: .zero,
                        scale: 2,
                        drawableSize: PixelSize(width: 2_048, height: 1_536),
                        orientation: .landscapeLeft,
                        traits: MobileSceneTraits(
                            horizontalSizeClass: .regular,
                            verticalSizeClass: .regular,
                            interfaceStyle: .dark
                        ),
                        resizePhase: .settled
                    )
                )
            )
        }
        let displayEDR = surfaceGeneration.map { surfaceGeneration in
            var publisher = MobileDisplayEDRSnapshotPublisher(
                surfaceGeneration: surfaceGeneration
            )
            _ = publisher.update(MobileDisplayEDREventEnvelope(
                surfaceGeneration: surfaceGeneration,
                sample: .attached(MobileDisplayEDRReading(
                    displayGeneration: mediaGeneration,
                    potentialHeadroom: 4,
                    currentHeadroom: 2
                ))
            ))
            return publisher.snapshot!
        }
        let pictureInPicture = pictureInPictureLifecycle.map { lifecycle in
            MobilePictureInPictureSnapshot(
                generation: generation,
                revision: MobilePictureInPictureRevision(rawValue: revision),
                state: MobilePictureInPictureSemanticState(
                    isPrepared: true,
                    capability: .possible,
                    lifecycle: lifecycle,
                    frameSink: .ready(decoderGeneration: 1)!,
                    restoration: .idle,
                    failure: nil
                )
            )
        }
        let application = SessionMobileRuntimeApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            revision: try XCTUnwrap(SessionMobileRuntimeRevision(
                rawValue: revision
            )),
            generation: generation,
            platform: .iOS,
            sceneActivity: sceneActivity,
            surfaceGeneration: surfaceGeneration,
            sceneWindow: sceneWindow,
            displayEDR: displayEDR,
            pictureInPicture: pictureInPicture,
            isAudioSessionActive: isAudioSessionActive,
            isAudioContinuityPermitted: isAudioSessionActive == true,
            preferences: .defaults,
            capabilities: PlatformContinuityCapabilities(
                supportsAudioBackgroundMode: true,
                supportsPictureInPicture: true,
                hasAudioBackgroundModeDeclared: true
            ),
            foregroundBaseline: .active
        )
        let input = application.generationInput
        let plan = MobileMediaGenerationPlanResolver.resolve(
            input.continuityContext,
            foregroundBaseline: input.foregroundBaseline,
            restoringForeground: foregroundRestorationCount > 0
        )
        return SessionMobileRuntimeState(
            application: application,
            media: MobileMediaGenerationSnapshot(
                ownership: input.ownership,
                revision: input.revision,
                phase: plan.stream == .stopped ? .stopped : .active,
                input: input,
                plan: plan,
                foregroundRestorationCount: foregroundRestorationCount
            )
        )
    }

    private func makeHDRApplicationFrame(
        generation: UInt64,
        frameID: UInt64,
        metadata: VideoColorMetadata
    ) throws -> DecodedVideoFrame {
        let bitDepth: VideoOutputBitDepth = metadata.isHDR ? .ten : .eight
        let pixelFormat = metadata.isHDR
            ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        var pixelBuffer: CVPixelBuffer?
        let result = CVPixelBufferCreate(
            kCFAllocatorDefault,
            64,
            64,
            pixelFormat,
            VideoToolboxDecompressionSessionFactory
                .destinationAttributes(for: bitDepth) as CFDictionary,
            &pixelBuffer
        )
        XCTAssertEqual(result, kCVReturnSuccess)
        return DecodedVideoFrame(
            generation: generation,
            frameID: frameID,
            pixelBuffer: try XCTUnwrap(pixelBuffer),
            presentationTimeStamp: .invalid,
            duration: .invalid,
            infoFlags: [],
            colorMetadata: metadata
        )
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

    private func waitUntil(
        _ condition: () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<100 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail(
            "Timed out waiting for application session state.",
            file: file,
            line: line
        )
    }

    private func waitForEnvironmentTeardown(
        _ environment: NativeSessionMediaEnvironment,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> SessionMediaEnvironmentSnapshot {
        var snapshot = await environment.snapshot()
        for _ in 0..<200 {
            if snapshot.sessionID == nil, snapshot.lastTeardownReport != nil {
                return snapshot
            }
            await Task.yield()
            snapshot = await environment.snapshot()
        }
        XCTFail(
            "Timed out waiting for media environment teardown.",
            file: file,
            line: line
        )
        return snapshot
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
        keyMaterial: RemoteInputKeyMaterial,
        videoColorMetadata: VideoColorMetadata = .rec709VideoRange(),
        audioConfiguration: NegotiatedAudioStreamConfiguration? = nil
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
                colorMetadata: videoColorMetadata,
                maximumPacketSize: 1_400
            ),
            audio: audioConfiguration ?? NegotiatedAudioStreamConfiguration(
                sampleRate: 48_000,
                channelLayout: .stereo,
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

    private func makeWave7Point1AudioConfiguration()
        throws -> NegotiatedAudioStreamConfiguration
    {
        let configuration = NegotiatedAudioStreamConfiguration(
            sampleRate: 48_000,
            channelLayout: .wave7Point1,
            streamCount: 5,
            coupledStreamCount: 3,
            samplesPerFrame: 240,
            channelMapping: [0, 1, 2, 3, 4, 5, 6, 7],
            maximumPacketSize: 1_400
        )
        try configuration.validate()
        return configuration
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

private func applicationIntegrationRouteCapability(
    _ support: SpatialAudioRouteSupport
) -> SpatialAudioRouteCapabilityState {
    SpatialAudioRouteCapabilityState(
        outputAvailable: true,
        systemSpatialSupport: support,
        currentOutputChannelCount: 8,
        maximumOutputChannelCount: 8
    )
}

private struct ApplicationIntegrationEntitlementReader: HeadPoseEntitlementReading {
    let state: SpatialAudioEntitlementState

    func readHeadPoseEntitlement() -> SpatialAudioEntitlementState {
        state
    }
}

private final class ApplicationIntegrationVideoReceiveProvider:
    VideoReceiveProvider,
    @unchecked Sendable
{
    private typealias Continuation =
        AsyncThrowingStream<VideoReceiveEvent, Error>.Continuation

    private struct Start {
        let sessionID: UUID
        let continuation: Continuation
    }

    private let lock = NSLock()
    private var starts: [Start] = []
    private var stoppedSessionIDs: [UUID] = []

    func receiveVideo(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedVideoStreamConfiguration
    ) async -> AsyncThrowingStream<VideoReceiveEvent, Error> {
        _ = endpoint
        _ = configuration
        let pair = AsyncThrowingStream<VideoReceiveEvent, Error>.makeStream()
        withLock {
            starts.append(Start(sessionID: sessionID, continuation: pair.continuation))
        }
        return pair.stream
    }

    func stopVideo(sessionID: UUID) async {
        let continuations = withLock { () -> [Continuation] in
            stoppedSessionIDs.append(sessionID)
            return starts
                .filter { $0.sessionID == sessionID }
                .map(\.continuation)
        }
        continuations.forEach { $0.finish() }
    }

    func yield(_ event: VideoReceiveEvent, startIndex: Int) {
        let continuation = withLock {
            starts.indices.contains(startIndex) ? starts[startIndex].continuation : nil
        }
        continuation?.yield(event)
    }

    func startCount() -> Int {
        withLock { starts.count }
    }

    func stopCount() -> Int {
        withLock { stoppedSessionIDs.count }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationAudioReceiveProvider:
    AudioReceiveProvider,
    @unchecked Sendable
{
    private typealias Continuation =
        AsyncThrowingStream<AudioReceiveEvent, Error>.Continuation

    private struct Start {
        let sessionID: UUID
        let continuation: Continuation
    }

    private let lock = NSLock()
    private var starts: [Start] = []
    private var stoppedSessionIDs: [UUID] = []

    func receiveAudio(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedAudioStreamConfiguration
    ) async -> AsyncThrowingStream<AudioReceiveEvent, Error> {
        _ = endpoint
        _ = configuration
        let pair = AsyncThrowingStream<AudioReceiveEvent, Error>.makeStream()
        withLock {
            starts.append(Start(sessionID: sessionID, continuation: pair.continuation))
        }
        return pair.stream
    }

    func stopAudio(sessionID: UUID) async {
        let continuations = withLock { () -> [Continuation] in
            stoppedSessionIDs.append(sessionID)
            return starts
                .filter { $0.sessionID == sessionID }
                .map(\.continuation)
        }
        continuations.forEach { $0.finish() }
    }

    func yield(_ event: AudioReceiveEvent, startIndex: Int) {
        let continuation = withLock {
            starts.indices.contains(startIndex) ? starts[startIndex].continuation : nil
        }
        continuation?.yield(event)
    }

    func startCount() -> Int {
        withLock { starts.count }
    }

    func stopCount() -> Int {
        withLock { stoppedSessionIDs.count }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationRemoteInputProvider:
    RemoteInputProvider,
    @unchecked Sendable
{
    struct Snapshot {
        let startCount: Int
        let releaseCount: Int
        let stopCount: Int
    }

    private let lock = NSLock()
    private var activeSessionID: UUID?
    private var startCounter = 0
    private var releaseCounter = 0
    private var stopCounter = 0
    private var feedbackContinuations: [AsyncStream<RemoteInputFeedback>.Continuation] = []

    func startInput(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedInputConfiguration
    ) async throws {
        _ = endpoint
        _ = configuration
        withLock {
            activeSessionID = sessionID
            startCounter += 1
        }
    }

    func send(_ event: RemoteInputEvent, sessionID: UUID) async throws {
        _ = event
        guard withLock({ activeSessionID == sessionID }) else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
    }

    func feedback(sessionID: UUID) async -> AsyncStream<RemoteInputFeedback> {
        _ = sessionID
        let pair = AsyncStream<RemoteInputFeedback>.makeStream()
        withLock { feedbackContinuations.append(pair.continuation) }
        return pair.stream
    }

    func releaseAll(sessionID: UUID) async {
        withLock {
            guard activeSessionID == sessionID else { return }
            releaseCounter += 1
        }
    }

    func stopInput(sessionID: UUID) async {
        let continuation = withLock { () -> AsyncStream<RemoteInputFeedback>.Continuation? in
            guard activeSessionID == sessionID else { return nil }
            activeSessionID = nil
            stopCounter += 1
            return feedbackContinuations.popLast()
        }
        continuation?.finish()
    }

    func snapshot() -> Snapshot {
        withLock {
            Snapshot(
                startCount: startCounter,
                releaseCount: releaseCounter,
                stopCount: stopCounter
            )
        }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationVideoProcessorFactory:
    SessionVideoProcessorCreating,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var processors: [ApplicationIntegrationVideoProcessor] = []

    func makeVideoProcessor(
        sessionID: UUID,
        mediaGeneration: UInt64,
        configuration: NegotiatedVideoStreamConfiguration,
        controlProvider: any SessionControlProvider,
        presentationEventSink: @escaping @Sendable (
            StreamVideoPresentationEvent
        ) -> Void
    ) async throws -> any SessionVideoProcessing {
        _ = sessionID
        _ = mediaGeneration
        _ = configuration
        _ = controlProvider
        _ = presentationEventSink
        let processor = ApplicationIntegrationVideoProcessor()
        withLock { processors.append(processor) }
        return processor
    }

    func consumeCount(at index: Int) -> Int {
        withLock {
            processors.indices.contains(index) ? processors[index].consumeCount() : 0
        }
    }

    func wasStopped(at index: Int) -> Bool {
        withLock {
            processors.indices.contains(index) && processors[index].wasStopped()
        }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationVideoProcessor:
    SessionVideoProcessing,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var consumed = 0
    private var stopped = false

    func consume(_ event: VideoReceiveEvent) async throws -> Bool {
        _ = event
        return withLock {
            guard !stopped else { return false }
            consumed += 1
            return true
        }
    }

    func updateColorMetadata(_ metadata: VideoColorMetadata) async throws {
        _ = metadata
    }

    func applyLifecycle(_ application: SessionLifecycleApplication) async throws {
        _ = application
    }

    func applyMobileVideo(
        _ application: SessionMobileVideoApplication
    ) async throws {
        _ = application
    }

    func stop() async {
        withLock { stopped = true }
    }

    func consumeCount() -> Int {
        withLock { consumed }
    }

    func wasStopped() -> Bool {
        withLock { stopped }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationAudioRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private let initialCapability: SpatialAudioRouteCapabilityState
    private var engines: [ApplicationIntegrationAudioEngineClient] = []
    private var decoders: [ApplicationIntegrationAudioDecoder] = []
    private var routeSources: [ApplicationIntegrationRouteEventSource] = []
    private var eventTime: UInt64 = 1_000_000

    init(initialCapability: SpatialAudioRouteCapabilityState) {
        self.initialCapability = initialCapability
    }

    func makeDecoder(
        configuration: NegotiatedAudioStreamConfiguration
    ) throws -> any SessionAudioDecoding {
        try configuration.validate()
        let decoder = ApplicationIntegrationAudioDecoder(configuration: configuration)
        withLock { decoders.append(decoder) }
        return decoder
    }

    func makeEngine() -> any AudioEngineClient {
        let engine = ApplicationIntegrationAudioEngineClient(
            capability: initialCapability
        )
        withLock { engines.append(engine) }
        return engine
    }

    func makeRouteSource() -> any SpatialAudioRouteMonitorEventSourcing {
        let source = ApplicationIntegrationRouteEventSource()
        withLock { routeSources.append(source) }
        return source
    }

    func nextEventTime() -> UInt64 {
        withLock {
            eventTime += 1_000_000
            return eventTime
        }
    }

    func engineCount() -> Int {
        withLock { engines.count }
    }

    func engine(at index: Int) -> ApplicationIntegrationAudioEngineClient? {
        withLock { engines.indices.contains(index) ? engines[index] : nil }
    }

    func decoder(at index: Int) -> ApplicationIntegrationAudioDecoder? {
        withLock { decoders.indices.contains(index) ? decoders[index] : nil }
    }

    func routeSource(at index: Int) -> ApplicationIntegrationRouteEventSource? {
        withLock { routeSources.indices.contains(index) ? routeSources[index] : nil }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationAudioDecoder:
    SessionAudioDecoding,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let negotiatedConfiguration: NegotiatedAudioStreamConfiguration
    private var closed = false

    init(configuration: NegotiatedAudioStreamConfiguration) {
        negotiatedConfiguration = configuration
    }

    func decode(_ packet: ReceivedAudioPacket) async throws -> DecodedPCMBuffer {
        let configuration = negotiatedConfiguration
        guard !withLock({ closed }) else {
            throw OpusDecoderError.closed
        }
        return DecodedPCMBuffer(
            sequenceNumber: packet.sequenceNumber,
            rtpTimestamp: packet.timestamp,
            format: .signedInt16(
                sampleRate: configuration.sampleRate,
                channelLayout: configuration.channelLayout
            ),
            frameCount: configuration.samplesPerFrame,
            interleavedSamples: [Int16](
                repeating: Int16(packet.sequenceNumber),
                count: configuration.samplesPerFrame * configuration.channelCount
            )
        )
    }

    func close() async {
        withLock { closed = true }
    }

    func configuration() -> NegotiatedAudioStreamConfiguration {
        negotiatedConfiguration
    }

    func isClosed() -> Bool {
        withLock { closed }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationAudioEngineClient:
    AudioEngineClient,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var capability: SpatialAudioRouteCapabilityState
    private var configuredAudio: [StreamAudioConfiguration] = []
    private var intents: [SpatialAudioGraphIntent] = []
    private var modes: [SpatialAudioGraphMode] = []
    private var scheduled: [DecodedPCMBuffer] = []
    private var stopped = false

    init(capability: SpatialAudioRouteCapabilityState) {
        self.capability = capability
    }

    func configure(
        _ configuration: StreamAudioConfiguration,
        graphIntent: SpatialAudioGraphIntent
    ) throws -> SpatialAudioRuntimeSnapshot {
        try configuration.validate()
        let usesEnvironment = graphIntent.userEnablesSpatialAudio
            && configuration.channelLayout.spatialEligibility == .ambienceBed
            && graphIntent.route.outputAvailable
            && graphIntent.route.systemSpatialSupport != .unsupported
        let graphMode: SpatialAudioGraphMode = usesEnvironment
            ? .environmentAmbienceBed
            : .nonspatialMixer
        let strategy: SpatialAudioPlatformStrategy = usesEnvironment
            ? .environmentListener
            : .none
        let graph = SpatialAudioGraphSnapshot(
            revision: graphIntent.revision,
            mode: graphMode,
            layoutSignature: configuration.channelLayout.signature,
            hasApplicableRenderingAlgorithm: usesEnvironment,
            platformStrategy: strategy,
            listenerHeadTrackingCapable: usesEnvironment,
            listenerHeadTrackingReadback: false,
            visionExperienceReadback: nil
        )
        withLock {
            configuredAudio.append(configuration)
            intents.append(graphIntent)
            modes.append(graphMode)
            stopped = false
        }
        return SpatialAudioRuntimeResolver.resolve(
            intent: graphIntent,
            layout: configuration.channelLayout,
            graph: graph
        )
    }

    func start() throws {
        withLock { stopped = false }
    }

    func schedule(
        _ buffer: DecodedPCMBuffer,
        completion: @escaping @Sendable () -> Void
    ) throws {
        withLock { scheduled.append(buffer) }
        completion()
    }

    func stop(drain: Bool) {
        _ = drain
        withLock { stopped = true }
    }

    func routeSnapshot() -> AudioRouteSnapshot {
        AudioRouteSnapshot(
            outputNames: ["Bounded Integration Output"],
            sampleRate: 48_000,
            outputChannelCount: 8,
            preferredBufferDuration: 0.005
        )
    }

    func currentSpatialRouteCapability() -> SpatialAudioRouteCapabilityState {
        withLock { capability }
    }

    func setCapability(_ capability: SpatialAudioRouteCapabilityState) {
        withLock { self.capability = capability }
    }

    func configurations() -> [StreamAudioConfiguration] {
        withLock { configuredAudio }
    }

    func graphIntents() -> [SpatialAudioGraphIntent] {
        withLock { intents }
    }

    func graphModes() -> [SpatialAudioGraphMode] {
        withLock { modes }
    }

    func scheduledBuffers() -> [DecodedPCMBuffer] {
        withLock { scheduled }
    }

    func wasStopped() -> Bool {
        withLock { stopped }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationRouteEventSource:
    SpatialAudioRouteMonitorEventSourcing,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var handler: (@Sendable (SpatialAudioRouteMonitorEvent) -> Void)?
    private var lateHandler: (@Sendable (SpatialAudioRouteMonitorEvent) -> Void)?
    private var stopped = false

    func start(
        handler: @escaping @Sendable (SpatialAudioRouteMonitorEvent) -> Void
    ) {
        withLock {
            self.handler = handler
            lateHandler = handler
            stopped = false
        }
    }

    func stop() {
        withLock {
            handler = nil
            stopped = true
        }
    }

    func emit(_ event: SpatialAudioRouteMonitorEvent) {
        withLock { handler }?(event)
    }

    func emitLate(_ event: SpatialAudioRouteMonitorEvent) {
        withLock { lateHandler }?(event)
    }

    func wasStopped() -> Bool {
        withLock { stopped }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
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
                channelLayout: .stereo,
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
    private let failsInputSend: Bool
    private let failsTVOSDisplayApplication: Bool
    private let blocksFirstTVVisionActivation: Bool
    private let blocksFailingTVVisionActivationAfterTerminalEvent: Bool
    private var startRecords: [StartRecord] = []
    private var stoppedSessionIDs: [UUID] = []
    private var continuations: [UUID: Continuation] = [:]
    private var sentInputApplications: [SessionInputApplication] = []
    private var releasedInputApplications: [SessionInputReleaseApplication] = []
    private var lifecycleApplications: [SessionLifecycleApplication] = []
    private var spatialAudioPreferenceApplications:
        [SessionSpatialAudioPreferenceApplication] = []
    private var tvVisionPlatformPresentationApplications:
        [SessionTVVisionPlatformPresentationApplication] = []
    private var shouldBlockNextRelease = false
    private var shouldFailNextRelease = false
    private var blockedReleaseContinuation: CheckedContinuation<Void, Never>?
    private var shouldBlockNextInputSend = false
    private var blockedInputSendContinuation: CheckedContinuation<Void, Never>?
    private var shouldBlockNextStop = false
    private var blockedStopContinuation: CheckedContinuation<Void, Never>?
    private var blockedTVVisionActivationContinuation:
        CheckedContinuation<Void, Never>?
    private var shouldBlockTVVisionActivation: Bool

    init(
        automaticallyReady: Bool = true,
        failsLifecycleApplication: Bool = false,
        failsInputSend: Bool = false,
        failsTVOSDisplayApplication: Bool = false,
        blocksFirstTVVisionActivation: Bool = false,
        blocksFailingTVVisionActivationAfterTerminalEvent: Bool = false
    ) {
        self.automaticallyReady = automaticallyReady
        self.failsLifecycleApplication = failsLifecycleApplication
        self.failsInputSend = failsInputSend
        self.failsTVOSDisplayApplication = failsTVOSDisplayApplication
        self.blocksFirstTVVisionActivation = blocksFirstTVVisionActivation
        shouldBlockTVVisionActivation = blocksFirstTVVisionActivation
        self.blocksFailingTVVisionActivationAfterTerminalEvent =
            blocksFailingTVVisionActivationAfterTerminalEvent
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

    func updateSpatialAudioPreferences(
        _ application: SessionSpatialAudioPreferenceApplication
    ) async throws {
        let state = withLock {
            (
                continuations[application.sessionID] != nil,
                UInt64(startRecords.count)
            )
        }
        guard state.0 else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard application.mediaGeneration == state.1 else {
            throw SessionMediaEnvironmentError.staleAudioApplication
        }
        withLock {
            spatialAudioPreferenceApplications.append(application)
        }
    }

    func applyTVVisionPlatformPresentation(
        _ application: SessionTVVisionPlatformPresentationApplication
    ) async throws {
        let state = withLock {
            (
                continuations[application.ownership.sessionID] != nil,
                UInt64(startRecords.count)
            )
        }
        guard state.0 else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard application.ownership.mediaGeneration == state.1 else {
            throw SessionMediaEnvironmentError
                .staleTVVisionPlatformPresentationApplication
        }
        withLock {
            tvVisionPlatformPresentationApplications.append(application)
        }
        if failsTVOSDisplayApplication,
           case .display = application.action {
            throw MediaEnvironmentApplicationTestError.failed
        }
        if blocksFirstTVVisionActivation,
           application.action == .activate,
           withLock({
               guard shouldBlockTVVisionActivation else { return false }
               shouldBlockTVVisionActivation = false
               return true
           }) {
            await withCheckedContinuation { continuation in
                withLock {
                    blockedTVVisionActivationContinuation = continuation
                }
            }
        }
        if blocksFailingTVVisionActivationAfterTerminalEvent,
           application.action == .activate {
            let revision = try TVVisionSemanticRevision(rawValue: 1)
            let terminal = SessionTVVisionPlatformPresentationState(
                sessionID: application.ownership.sessionID,
                mediaGeneration: application.ownership.mediaGeneration,
                snapshot: TVVisionPlatformPresentationCoordinatorSnapshot(
                    ownership: application.ownership,
                    sequence: 1,
                    revision: revision,
                    phase: .failed(.invalidComponent(.video)),
                    presentation: nil,
                    display: nil,
                    audioRoute: nil,
                    video: TVVisionPlatformVideoSnapshot(
                        phase: .idle,
                        lastDeliveryRevision: nil,
                        isPresented: false
                    ),
                    diagnostics: [],
                    teardownCount: 1,
                    isSemanticRevisionExhausted: false,
                    isSequenceExhausted: false
                )
            )
            continuation(for: application.ownership.sessionID)?.yield(
                .tvVisionPlatformPresentation(terminal)
            )
            await withCheckedContinuation { continuation in
                withLock {
                    blockedTVVisionActivationContinuation = continuation
                }
            }
            throw SessionMediaEnvironmentError
                .invalidTVVisionPlatformPresentationApplication
        }
    }

    func sendInput(_ application: SessionInputApplication) async throws {
        let currentGeneration = withLock { UInt64(startRecords.count) }
        guard continuation(for: application.sessionID) != nil else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard application.mediaGeneration == currentGeneration else {
            throw SessionMediaEnvironmentError.staleInputApplication
        }
        if failsInputSend {
            throw RemoteInputRuntimeError.deliveryFailed
        }
        let shouldBlock = withLock {
            let value = shouldBlockNextInputSend
            shouldBlockNextInputSend = false
            return value
        }
        if shouldBlock {
            await withCheckedContinuation { continuation in
                withLock { blockedInputSendContinuation = continuation }
            }
            guard continuation(for: application.sessionID) != nil else {
                throw SessionMediaEnvironmentError.inactiveSession
            }
            guard application.mediaGeneration
                    == withLock({ UInt64(startRecords.count) }) else {
                throw SessionMediaEnvironmentError.staleInputApplication
            }
        }
        withLock { sentInputApplications.append(application) }
    }

    func releaseInput(_ application: SessionInputReleaseApplication) async throws {
        try validateRelease(application)
        let behavior = withLock {
            let value = (shouldBlockNextRelease, shouldFailNextRelease)
            shouldBlockNextRelease = false
            shouldFailNextRelease = false
            releasedInputApplications.append(application)
            return value
        }
        if behavior.0 {
            await withCheckedContinuation { continuation in
                withLock { blockedReleaseContinuation = continuation }
            }
        }
        if behavior.1 {
            throw RemoteInputRuntimeError.deliveryFailed
        }
        try validateRelease(application)
    }

    func stop(sessionID: UUID) async -> SessionTeardownReport? {
        let state = withLock {
            stoppedSessionIDs.append(sessionID)
            let continuation = continuations.removeValue(forKey: sessionID)
            let shouldBlock = shouldBlockNextStop
            shouldBlockNextStop = false
            return (continuation, shouldBlock)
        }
        state.0?.finish()
        if state.1 {
            await withCheckedContinuation { continuation in
                withLock { blockedStopContinuation = continuation }
            }
        }
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

    func yieldVideoPresentation(
        _ event: StreamVideoPresentationEvent,
        sessionID: UUID
    ) {
        continuation(for: sessionID)?.yield(.videoPresentation(event))
    }

    func yieldAudioRuntime(
        _ state: SessionMediaAudioRuntimeState,
        sessionID: UUID
    ) {
        continuation(for: sessionID)?.yield(.audioRuntime(state))
    }

    func yieldMobileRuntime(
        _ state: SessionMobileRuntimeState,
        sessionID: UUID
    ) {
        continuation(for: sessionID)?.yield(.mobileRuntime(state))
    }

    func yieldTVVisionPlatformPresentation(
        _ state: SessionTVVisionPlatformPresentationState,
        sessionID: UUID
    ) {
        continuation(for: sessionID)?.yield(
            .tvVisionPlatformPresentation(state)
        )
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

    func blockNextInputSend() {
        withLock { shouldBlockNextInputSend = true }
    }

    func hasBlockedInputSend() -> Bool {
        withLock { blockedInputSendContinuation != nil }
    }

    func resumeBlockedInputSend() {
        let continuation = withLock {
            defer { blockedInputSendContinuation = nil }
            return blockedInputSendContinuation
        }
        continuation?.resume()
    }

    func currentLifecycleApplications() -> [SessionLifecycleApplication] {
        withLock { lifecycleApplications }
    }

    func currentTVVisionPlatformPresentationApplications()
        -> [SessionTVVisionPlatformPresentationApplication] {
        withLock { tvVisionPlatformPresentationApplications }
    }

    func hasBlockedTVVisionActivation() -> Bool {
        withLock { blockedTVVisionActivationContinuation != nil }
    }

    func resumeBlockedTVVisionActivation() {
        let continuation = withLock {
            defer { blockedTVVisionActivationContinuation = nil }
            return blockedTVVisionActivationContinuation
        }
        continuation?.resume()
    }

    func currentSpatialAudioPreferenceApplications()
        -> [SessionSpatialAudioPreferenceApplication] {
        withLock { spatialAudioPreferenceApplications }
    }

    func blockNextRelease() {
        withLock { shouldBlockNextRelease = true }
    }

    func failNextRelease() {
        withLock { shouldFailNextRelease = true }
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

    func blockNextStop() {
        withLock { shouldBlockNextStop = true }
    }

    func hasBlockedStop() -> Bool {
        withLock { blockedStopContinuation != nil }
    }

    func resumeBlockedStop() {
        let continuation = withLock {
            let value = blockedStopContinuation
            blockedStopContinuation = nil
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

    func updateSpatialAudioPreferences(
        _ application: SessionSpatialAudioPreferenceApplication
    ) async throws {
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
