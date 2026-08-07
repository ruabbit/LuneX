import Foundation
import XCTest

@MainActor
final class TVStreamControlPresentationStateTests: XCTestCase {
    func testNoSessionNeverClaimsActualTVState() {
        let state = resolve()

        XCTAssertEqual(state.focus, .unavailable)
        XCTAssertEqual(state.capture, .unavailable)
        XCTAssertEqual(state.controllers, .unavailable)
        XCTAssertEqual(state.surface, .unavailable)
        XCTAssertEqual(state.render, .inactive)
        XCTAssertEqual(state.hdr, .inactive)
        XCTAssertEqual(state.audio, .inactive)
        XCTAssertEqual(state.failure, .none)
        XCTAssertEqual(state.rows.map(\.kind), TVStreamControlStatusContent.Kind.allCases)
    }

    func testOverlayReportsLocalOwnershipAndTruthfulSDRFallback() throws {
        let state = resolve(
            hasActiveSession: true,
            focusHandoff: activeFocusHandoff(overlayVisible: true),
            remoteCaptureDisposition: .local,
            sceneSurface: try sceneSurface(),
            connectedControllerCount: 2,
            routedControllerCount: 1,
            renderPolicy: .active,
            video: TVVisionPlatformVideoSnapshot(
                phase: .decoderReady(decoderGeneration: 4),
                lastDeliveryRevision: nil,
                isPresented: false
            ),
            hdrPresentation: .edr,
            hdrFallbackReason: .insufficientHeadroom,
            audioRoute: try audioRoute(
                channelCount: 6,
                presentationMode: .fixedSpatial
            ),
            spatialAudio: SpatialAudioPresentationStatus(
                mode: .fixedSpatial,
                fallback: nil
            )
        )

        XCTAssertEqual(state.focus, .localControls)
        XCTAssertEqual(state.capture, .local)
        XCTAssertEqual(state.controllers, .active(connected: 2, routed: 1))
        XCTAssertEqual(state.surface, .visible)
        XCTAssertEqual(state.render, .waitingForFrame)
        XCTAssertEqual(state.hdr, .sdrFallback(.insufficientHeadroom))
        XCTAssertEqual(
            state.audio,
            .spatial(channelCount: 6, mode: .fixedSpatial)
        )
        XCTAssertEqual(
            state.rows.first(where: { $0.kind == .hdr }).map {
                localized($0.value)
            },
            "SDR fallback"
        )
        XCTAssertEqual(
            state.rows.first(where: { $0.kind == .controllers }).map {
                localized($0.value)
            },
            "2 connected, 1 routed"
        )
    }

    func testCurrentCaptureFrameEDRAndHeadTrackingReportActualState() throws {
        let state = resolve(
            hasActiveSession: true,
            focusHandoff: try activeFocusedSurfaceHandoff(),
            remoteCaptureDisposition: .captured,
            sceneSurface: try sceneSurface(),
            connectedControllerCount: 1,
            routedControllerCount: 1,
            renderPolicy: .active,
            video: TVVisionPlatformVideoSnapshot(
                phase: .frameReady(decoderGeneration: 7, frameID: 99),
                lastDeliveryRevision: 10,
                isPresented: true
            ),
            hdrPresentation: .edr,
            audioRoute: try audioRoute(
                channelCount: 8,
                presentationMode: .headTracked
            ),
            spatialAudio: SpatialAudioPresentationStatus(
                mode: .headTracked,
                fallback: nil
            )
        )

        XCTAssertEqual(state.focus, .streamSurface)
        XCTAssertEqual(state.capture, .remote)
        XCTAssertEqual(state.render, .presenting)
        XCTAssertEqual(state.hdr, .directEDR)
        XCTAssertEqual(
            state.audio,
            .spatial(channelCount: 8, mode: .headTracked)
        )
        XCTAssertEqual(
            state.rows.first(where: { $0.kind == .render }).map {
                localized($0.value)
            },
            "Presenting"
        )
        XCTAssertEqual(
            state.rows.first(where: { $0.kind == .audio }).map {
                localized($0.value)
            },
            "8 ch head tracked"
        )
    }

    func testReleaseAndBoundedCoordinatorFailureRemainExplicit() throws {
        let state = resolve(
            hasActiveSession: true,
            focusHandoff: activeFocusHandoff(overlayVisible: false),
            remoteCaptureDisposition: .captured,
            isRemoteReleasePending: true,
            sceneSurface: try sceneSurface(),
            connectedControllerCount: 1,
            routedControllerCount: 1,
            renderPolicy: .paused(reason: "test-only"),
            video: TVVisionPlatformVideoSnapshot(
                phase: .cleared(decoderGeneration: 2),
                lastDeliveryRevision: 3,
                isPresented: false
            ),
            hdrPresentation: .pipelineFailure,
            spatialAudio: SpatialAudioPresentationStatus(
                mode: .recovering,
                fallback: nil
            ),
            presentationFailure: .actionFailed(.audioRoute)
        )

        XCTAssertEqual(state.focus, .handoffPending)
        XCTAssertEqual(state.capture, .releasePending)
        XCTAssertEqual(state.render, .failed)
        XCTAssertEqual(state.hdr, .failed)
        XCTAssertEqual(state.audio, .recovering)
        XCTAssertEqual(state.failure, .actionFailed(.audioRoute))
        XCTAssertEqual(
            state.rows.first(where: { $0.kind == .failure }).map {
                localized($0.value)
            },
            "Audio route failed"
        )
    }

    func testInvalidCountsAndForeignPlatformValuesFailClosed() throws {
        let state = resolve(
            hasActiveSession: true,
            focusHandoff: activeFocusHandoff(overlayVisible: true),
            sceneSurface: try sceneSurface(platform: .visionOS),
            connectedControllerCount: 1,
            routedControllerCount: 2,
            renderPolicy: .active,
            hdrPresentation: .sdr,
            audioRoute: try audioRoute(platform: .visionOS),
            spatialAudio: SpatialAudioPresentationStatus(
                mode: .visionFixed,
                fallback: nil
            )
        )

        XCTAssertEqual(state.controllers, .unavailable)
        XCTAssertEqual(state.surface, .unavailable)
        XCTAssertEqual(state.render, .waitingForSurface)
        XCTAssertEqual(state.audio, .unavailable)
    }

    func testRowsUseFixedPrivacyBoundedAccessibleCopy() throws {
        let state = resolve(
            hasActiveSession: true,
            hasSessionFailure: true,
            focusHandoff: activeFocusHandoff(overlayVisible: true),
            sceneSurface: try sceneSurface(),
            connectedControllerCount: 0,
            routedControllerCount: 0,
            renderPolicy: .throttled(reason: "private-runtime-reason"),
            hdrPresentation: .sdrFallback(.displayCapabilityUnavailable),
            spatialAudio: .inactive
        )
        let published = state.rows.flatMap {
            [
                localized($0.title),
                localized($0.value),
                localized($0.detail),
                localized($0.accessibilityValue)
            ]
        }.joined(separator: " ")
        let forbidden = [
            "192.0.2.44",
            "living-room-host",
            "controller-vendor",
            "controller-lease",
            "display-id",
            "route-id",
            "frame 99",
            "private-runtime-reason"
        ]

        XCTAssertEqual(state.failure, .session)
        XCTAssertEqual(state.render, .failed)
        XCTAssertEqual(state.rows.count, 8)
        for row in state.rows {
            XCTAssertFalse(localized(row.title).isEmpty)
            XCTAssertFalse(localized(row.value).isEmpty)
            XCTAssertFalse(localized(row.detail).isEmpty)
            XCTAssertFalse(row.systemImage.isEmpty)
            XCTAssertFalse(localized(row.accessibilityValue).isEmpty)
        }
        for fragment in forbidden {
            XCTAssertFalse(published.contains(fragment))
        }
    }

    func testAppModelPublishesInactiveTVProjectionWithoutStartingRuntime() {
        let model = AppModel(
            runtimeProviders: .unavailable,
            tvVisionPlatform: .tvOS,
            clientIdentityStore: InMemoryClientIdentityStore()
        )

        XCTAssertEqual(model.tvStreamControlPresentationState.focus, .unavailable)
        XCTAssertEqual(model.tvStreamControlPresentationState.render, .inactive)
        XCTAssertEqual(model.tvStreamControlPresentationState.failure, .none)
    }

    func testRootViewUsesPredictableAccessibleTVFocusWithoutHoverDependency()
        throws
    {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let rootView = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("Sources/LuneXApp/RootView.swift"),
            encoding: .utf8
        )
        let appModel = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("Sources/LuneXCore/AppModel.swift"),
            encoding: .utf8
        )
        let generator = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("Tools/generate_xcodeproj.rb"),
            encoding: .utf8
        )
        let controlsStart = try XCTUnwrap(
            rootView.range(of: "private enum TVStreamControlFocusTarget: Hashable")
        )
        let controlsEnd = try XCTUnwrap(
            rootView.range(of: "#endif", range: controlsStart.upperBound..<rootView.endIndex)
        )
        let controls = String(rootView[controlsStart.lowerBound..<controlsEnd.lowerBound])

        let required = [
            "let state = appModel.tvStreamControlPresentationState",
            "case hideControls",
            "case disconnect",
            ".focused($focusedControl, equals: .hideControls)",
            ".focused($focusedControl, equals: .disconnect)",
            ".defaultFocus($focusedControl, .hideControls)",
            ".focusSection()",
            ".accessibilitySortPriority(2)",
            ".accessibilitySortPriority(1)",
            ".accessibilityLabel(Text(row.title))",
            ".accessibilityValue(Text(row.accessibilityValue))",
            "Text(\"Actual Stream State\")",
            "Button(role: .destructive)",
            "TVVisionStreamControlsLayout(",
            "ViewThatFits(in: .horizontal)",
            "compactStatusRows(state)",
            "wideStatusRows(state)"
        ]
        for contract in required {
            XCTAssertTrue(controls.contains(contract), "Missing \(contract)")
        }
        XCTAssertFalse(controls.contains(".onHover"))
        XCTAssertFalse(controls.contains("preferRelativeMouseMode"))
        let hideControls = try XCTUnwrap(controls.range(
            of: "Label(\"Hide Controls\", systemImage: \"eye.slash\")"
        ))
        let disconnect = try XCTUnwrap(controls.range(
            of: "Label(\"Disconnect\", systemImage: \"xmark.circle\")"
        ))
        XCTAssertLessThan(
            controls.distance(from: controls.startIndex, to: hideControls.lowerBound),
            controls.distance(from: controls.startIndex, to: disconnect.lowerBound)
        )
        XCTAssertTrue(appModel.contains(
            "var tvStreamControlPresentationState: TVStreamControlPresentationState"
        ))
        XCTAssertTrue(generator.contains(
            "Sources/LuneXCore/TVStreamControlPresentationState.swift"
        ))
        XCTAssertTrue(generator.contains(
            "Tests/LuneXCoreTests/TVStreamControlPresentationStateTests.swift"
        ))
    }

    private func localized(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }

    private func resolve(
        hasActiveSession: Bool = false,
        hasSessionFailure: Bool = false,
        focusHandoff: TVRemoteFocusHandoffState = .localNavigation,
        remoteCaptureDisposition: TVRemoteSurfacePressDisposition = .local,
        isRemoteReleasePending: Bool = false,
        sceneSurface: TVVisionSceneSurfaceSnapshot? = nil,
        connectedControllerCount: Int = 0,
        routedControllerCount: Int = 0,
        renderPolicy: RenderPolicy = .idle,
        video: TVVisionPlatformVideoSnapshot? = nil,
        hdrPresentation: HDRPresentationStatus = .inactive,
        hdrFallbackReason: TVOSDisplayHDRFallbackReason? = nil,
        audioRoute: TVVisionAudioRouteSnapshot? = nil,
        spatialAudio: SpatialAudioPresentationStatus = .inactive,
        presentationFailure: TVVisionPlatformPresentationFailure? = nil
    ) -> TVStreamControlPresentationState {
        TVStreamControlPresentationStateResolver.resolve(
            TVStreamControlPresentationInput(
                hasActiveSession: hasActiveSession,
                hasSessionFailure: hasSessionFailure,
                focusHandoff: focusHandoff,
                remoteCaptureDisposition: remoteCaptureDisposition,
                isRemoteReleasePending: isRemoteReleasePending,
                sceneSurface: sceneSurface,
                connectedControllerCount: connectedControllerCount,
                routedControllerCount: routedControllerCount,
                renderPolicy: renderPolicy,
                video: video,
                hdrPresentation: hdrPresentation,
                hdrFallbackReason: hdrFallbackReason,
                audioRoute: audioRoute,
                spatialAudio: spatialAudio,
                presentationFailure: presentationFailure
            )
        )
    }

    private func activeFocusHandoff(
        overlayVisible: Bool
    ) -> TVRemoteFocusHandoffState {
        TVRemoteFocusHandoffState.localNavigation
            .selectingStreamNavigation(true, currentGeometryStamp: nil)
            .settingWorkspaceVisible(true, currentGeometryStamp: nil)
            .settingOverlayVisible(overlayVisible, currentGeometryStamp: nil)
    }

    private func activeFocusedSurfaceHandoff()
        throws -> TVRemoteFocusHandoffState
    {
        let stamp = try TVRemoteSurfaceFocusStamp(
            surfaceGeneration: generation(.surface, 1),
            revision: TVVisionSemanticRevision(rawValue: 1)
        )
        return activeFocusHandoff(overlayVisible: false)
            .observingSurfaceFocus(stamp: stamp, actualEligibility: .eligible)
    }

    private func sceneSurface(
        platform: TVVisionPlatform = .tvOS
    ) throws -> TVVisionSceneSurfaceSnapshot {
        let surfaceGeneration = try generation(.surface, 1)
        let geometry = try TVVisionSurfaceGeometry(
            platform: platform,
            surfaceGeneration: surfaceGeneration,
            viewBounds: TVVisionRect(
                x: 0,
                y: 0,
                width: 1920,
                height: 1080
            ),
            windowBounds: TVVisionRect(
                x: 0,
                y: 0,
                width: 1920,
                height: 1080
            ),
            safeAreaInsets: .zero,
            scale: 2,
            drawableSize: PixelSize(width: 3840, height: 2160)
        )
        return try TVVisionSceneSurfaceSnapshot(
            platform: platform,
            revision: TVVisionSemanticRevision(rawValue: 1),
            surfaceGeneration: surfaceGeneration,
            activity: .active,
            attachment: .attached,
            isVisible: true,
            geometry: geometry
        )
    }

    private func audioRoute(
        platform: TVVisionPlatform = .tvOS,
        channelCount: Int = 2,
        presentationMode: SpatialAudioPresentationMode = .fixedSpatial
    ) throws -> TVVisionAudioRouteSnapshot {
        try TVVisionAudioRouteSnapshot(
            platform: platform,
            revision: TVVisionSemanticRevision(rawValue: 1),
            routeGeneration: generation(.audioRoute, 1),
            outputAvailable: true,
            currentOutputChannelCount: channelCount,
            maximumOutputChannelCount: max(channelCount, 8),
            spatialSupport: .supported,
            platformStrategy: platform == .tvOS
                ? .environmentListener
                : .visionOutputExperience,
            headTrackingCapability: platform == .tvOS
                ? .entitlementRequired
                : .intendedSpatialExperience,
            runtimeStage: .running,
            eventCause: .initial,
            spatialPresentationMode: presentationMode,
            spatialFallbackReason: nil
        )
    }

    private func generation(
        _ domain: TVVisionGenerationDomain,
        _ rawValue: UInt64
    ) throws -> TVVisionGeneration {
        try TVVisionGeneration(domain: domain, rawValue: rawValue)
    }
}
