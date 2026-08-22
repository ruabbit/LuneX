import Foundation
import XCTest

@MainActor
final class VisionStreamControlPresentationStateTests: XCTestCase {
    func testNoSessionNeverClaimsActualVisionState() {
        let state = resolve()

        XCTAssertEqual(state.window, .unavailable)
        XCTAssertEqual(state.input, .unavailable)
        XCTAssertEqual(state.controllers, .unavailable)
        XCTAssertEqual(state.render, .inactive)
        XCTAssertEqual(state.hdr, .inactive)
        XCTAssertEqual(state.spatial, .inactive)
        XCTAssertEqual(state.immersive, .unavailable)
        XCTAssertEqual(state.failure, .none)
        XCTAssertFalse(state.reachability.canHideControls)
        XCTAssertEqual(
            state.rows.map(\.kind),
            VisionStreamControlStatusContent.Kind.allCases
        )
    }

    func testVisibleWindowCapturedInputAndControllerRosterAreActual()
        throws
    {
        let state = resolve(
            hasActiveSession: true,
            windowedPresentation: try presentation(),
            sceneSurface: try sceneSurface(),
            inputCapabilities: try inputCapabilities(
                supported: [.keyboard, .pointer, .indirectPointer],
                focusEligibility: .eligible
            ),
            inputCaptureEnabled: true,
            connectedControllerCount: 2,
            routedControllerCount: 1,
            renderPolicy: .active
        )

        XCTAssertEqual(state.window, .visible)
        XCTAssertEqual(state.input, .captured(capabilityCount: 3))
        XCTAssertFalse(state.reachability.canHideControls)
        XCTAssertEqual(state.controllers, .active(connected: 2, routed: 1))
        XCTAssertEqual(state.render, .waitingForDecoder)
    }

    func testLocalAndReleasingInputKeepTypedOwnershipState() throws {
        let local = resolve(
            hasActiveSession: true,
            windowedPresentation: try presentation(),
            sceneSurface: try sceneSurface(),
            inputCapabilities: try inputCapabilities(
                focusEligibility: .ineligible(.overlayVisible)
            ),
            renderPolicy: .active
        )
        let releasing = resolve(
            hasActiveSession: true,
            windowedPresentation: try presentation(),
            sceneSurface: try sceneSurface(),
            inputCapabilities: try inputCapabilities(
                focusEligibility: .eligible
            ),
            inputCaptureEnabled: true,
            inputReleasePending: true,
            renderPolicy: .active
        )

        XCTAssertEqual(local.input, .local(.overlayVisible))
        XCTAssertEqual(releasing.input, .releasing)
        XCTAssertTrue(local.reachability.canHideControls)
        XCTAssertEqual(
            localized(local.reachability.hideControlsAccessibilityValue),
            "2 remote input paths available after controls close."
        )
        XCTAssertFalse(releasing.reachability.canHideControls)
        XCTAssertEqual(
            localized(releasing.reachability.hideControlsAccessibilityValue),
            "Remote input release is in progress."
        )
    }

    func testHideControlsReachabilityFailsClosedWithoutActualRemoteInput()
        throws
    {
        let notFocused = resolve(
            hasActiveSession: true,
            windowedPresentation: try presentation(),
            sceneSurface: try sceneSurface(),
            inputCapabilities: try inputCapabilities(
                focusEligibility: .ineligible(.notFocused)
            ),
            renderPolicy: .active
        )
        let noCapabilities = resolve(
            hasActiveSession: true,
            windowedPresentation: try presentation(),
            sceneSurface: try sceneSurface(),
            inputCapabilities: try inputCapabilities(
                supported: [],
                focusEligibility: .ineligible(.overlayVisible)
            ),
            renderPolicy: .active
        )

        XCTAssertFalse(notFocused.reachability.canHideControls)
        XCTAssertEqual(
            localized(notFocused.reachability.hideControlsAccessibilityValue),
            "The current window is not input eligible."
        )
        XCTAssertFalse(noCapabilities.reachability.canHideControls)
        XCTAssertEqual(
            localized(noCapabilities.reachability.hideControlsAccessibilityValue),
            "No current remote input path is available."
        )
    }

    func testFrameHDRFallbackAndHeadTrackedSpatialRemainTruthful() throws {
        let state = resolve(
            hasActiveSession: true,
            windowedPresentation: try presentation(),
            sceneSurface: try sceneSurface(),
            inputCapabilities: try inputCapabilities(
                focusEligibility: .eligible
            ),
            inputCaptureEnabled: true,
            connectedControllerCount: 1,
            routedControllerCount: 1,
            renderPolicy: .active,
            video: TVVisionPlatformVideoSnapshot(
                phase: .frameReady(decoderGeneration: 7, frameID: 99),
                lastDeliveryRevision: 10,
                isPresented: true
            ),
            hdrPresentation: .edr,
            hdrFallbackReason: .insufficientHeadroom,
            audioRoute: try audioRoute(channelCount: 8),
            spatialAudio: SpatialAudioPresentationStatus(
                mode: .visionHeadTracked,
                fallback: nil
            )
        )

        XCTAssertEqual(state.render, .presenting)
        XCTAssertEqual(state.hdr, .sdrFallback(.insufficientHeadroom))
        XCTAssertEqual(state.spatial, .headTracked(channelCount: 8))
        XCTAssertEqual(
            state.rows.first(where: { $0.kind == .hdr }).map {
                localized($0.value)
            },
            "SDR fallback"
        )
        XCTAssertEqual(
            state.rows.first(where: { $0.kind == .spatial }).map {
                localized($0.value)
            },
            "8 ch head tracked"
        )
    }

    func testImmersiveUnavailableRequiresCompleteTypedFeatureSet() throws {
        let uniform = resolve(
            hasActiveSession: true,
            windowedPresentation: try presentation(
                reason: .publicCapabilityUnavailable
            ),
            sceneSurface: try sceneSurface(),
            inputCapabilities: try inputCapabilities(),
            renderPolicy: .active
        )
        let ownership = try presentationOwnership()
        let revision = try TVVisionSemanticRevision(rawValue: 1)
        let incomplete = try VisionWindowedPresentationState(
            ownership: ownership,
            revision: revision,
            surfaceGeneration: generation(.surface, 1),
            unavailableFeatures: VisionUnavailablePresentationFeature.allCases
                .map {
                    VisionUnavailablePresentationState(
                        feature: $0,
                        reason: $0 == .immersive
                            ? .runtimeUnavailable
                            : .stage18WindowedOnly
                    )
                }
        )
        let mixed = resolve(
            hasActiveSession: true,
            windowedPresentation: incomplete,
            sceneSurface: try sceneSurface(),
            inputCapabilities: try inputCapabilities(),
            renderPolicy: .active
        )

        XCTAssertEqual(
            uniform.immersive,
            .windowedOnly(.publicCapabilityUnavailable)
        )
        XCTAssertEqual(mixed.immersive, .windowedOnly(nil))
    }

    func testForeignPlatformAndInvalidCountsFailClosed() throws {
        let state = resolve(
            hasActiveSession: true,
            windowedPresentation: try presentation(),
            sceneSurface: try sceneSurface(platform: .tvOS),
            inputCapabilities: try inputCapabilities(
                platform: .tvOS,
                supported: [.extendedGamepad]
            ),
            inputCaptureEnabled: true,
            connectedControllerCount: 1,
            routedControllerCount: 2,
            renderPolicy: .active,
            hdrPresentation: .sdr,
            audioRoute: try audioRoute(platform: .tvOS),
            spatialAudio: SpatialAudioPresentationStatus(
                mode: .visionFixed,
                fallback: nil
            )
        )

        XCTAssertEqual(state.window, .unavailable)
        XCTAssertEqual(state.input, .unavailable)
        XCTAssertEqual(state.controllers, .unavailable)
        XCTAssertEqual(state.render, .waitingForWindow)
        XCTAssertEqual(state.spatial, .unavailable)
    }

    func testMismatchedWindowAndInputRevisionsFailClosed() throws {
        let state = resolve(
            hasActiveSession: true,
            windowedPresentation: try presentation(revision: 2),
            sceneSurface: try sceneSurface(),
            inputCapabilities: try inputCapabilities(),
            inputCaptureEnabled: true,
            connectedControllerCount: 1,
            routedControllerCount: 1,
            renderPolicy: .active
        )

        XCTAssertEqual(state.window, .unavailable)
        XCTAssertEqual(state.input, .unavailable)
        XCTAssertEqual(state.controllers, .unavailable)
        XCTAssertEqual(state.render, .waitingForWindow)
    }

    func testCoordinatorFailureAndRowsArePrivacyBounded() throws {
        let state = resolve(
            hasActiveSession: true,
            hasSessionFailure: true,
            windowedPresentation: try presentation(),
            sceneSurface: try sceneSurface(),
            inputCapabilities: try inputCapabilities(),
            connectedControllerCount: 0,
            routedControllerCount: 0,
            renderPolicy: .throttled(reason: "private-runtime-reason"),
            hdrPresentation: .sdrFallback(.displayCapabilityUnavailable),
            spatialAudio: .inactive,
            presentationFailure: .actionFailed(.audioRoute)
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

        XCTAssertEqual(state.failure, .actionFailed(.audioRoute))
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

    func testAppModelPublishesInactiveVisionProjectionWithoutRuntime() {
        let model = AppModel(
            runtimeProviders: .unavailable,
            tvVisionPlatform: .visionOS,
            clientIdentityStore: InMemoryClientIdentityStore()
        )

        XCTAssertEqual(
            model.visionStreamControlPresentationState.window,
            .unavailable
        )
        XCTAssertEqual(
            model.visionStreamControlPresentationState.render,
            .inactive
        )
        XCTAssertEqual(
            model.visionStreamControlPresentationState.failure,
            .none
        )
    }

    func testRootViewUsesAccessibleNativeVisionControlsWithoutImmersiveRuntime()
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
            rootView.range(of: "private struct VisionStreamControls: View")
        )
        let controlsEnd = try XCTUnwrap(
            rootView.range(
                of: "#endif",
                range: controlsStart.upperBound..<rootView.endIndex
            )
        )
        let controls = String(
            rootView[controlsStart.lowerBound..<controlsEnd.lowerBound]
        )

        let required = [
            "let state = appModel.visionStreamControlPresentationState",
            "Text(\"Actual Windowed Stream State\")",
            "Button(role: .destructive)",
            "Label(\"Disconnect\", systemImage: \"xmark.circle\")",
            ".accessibilityLabel(Text(row.title))",
            ".accessibilityValue(Text(row.accessibilityValue))",
            ".frame(maxWidth: 760, alignment: .leading)",
            "commandHeader(state)",
            ".disabled(!state.reachability.canHideControls)",
            "Text(state.reachability.hideControlsAccessibilityValue)",
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
        XCTAssertFalse(controls.contains("ImmersiveSpace"))
        XCTAssertFalse(controls.contains("RealityView"))
        XCTAssertFalse(controls.contains("minWidth"))
        XCTAssertTrue(appModel.contains(
            "var visionStreamControlPresentationState:"
        ))
        XCTAssertTrue(generator.contains(
            "Sources/LuneXCore/VisionStreamControlPresentationState.swift"
        ))
        XCTAssertTrue(generator.contains(
            "Tests/LuneXCoreTests/VisionStreamControlPresentationStateTests.swift"
        ))
    }

    private func localized(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }

    private func resolve(
        hasActiveSession: Bool = false,
        hasSessionFailure: Bool = false,
        windowedPresentation: VisionWindowedPresentationState? = nil,
        sceneSurface: TVVisionSceneSurfaceSnapshot? = nil,
        inputCapabilities: TVVisionInputCapabilitySnapshot? = nil,
        inputCaptureEnabled: Bool = false,
        inputReleasePending: Bool = false,
        connectedControllerCount: Int = 0,
        routedControllerCount: Int = 0,
        renderPolicy: RenderPolicy = .idle,
        video: TVVisionPlatformVideoSnapshot? = nil,
        hdrPresentation: HDRPresentationStatus = .inactive,
        hdrFallbackReason: TVVisionDisplayHDRFallbackReason? = nil,
        audioRoute: TVVisionAudioRouteSnapshot? = nil,
        spatialAudio: SpatialAudioPresentationStatus = .inactive,
        presentationFailure: TVVisionPlatformPresentationFailure? = nil
    ) -> VisionStreamControlPresentationState {
        VisionStreamControlPresentationStateResolver.resolve(
            VisionStreamControlPresentationInput(
                hasActiveSession: hasActiveSession,
                hasSessionFailure: hasSessionFailure,
                windowedPresentation: windowedPresentation,
                sceneSurface: sceneSurface,
                inputCapabilities: inputCapabilities,
                inputCaptureEnabled: inputCaptureEnabled,
                inputReleasePending: inputReleasePending,
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

    private func presentation(
        reason: VisionPresentationUnavailableReason = .stage18WindowedOnly,
        revision: UInt64 = 1
    ) throws -> VisionWindowedPresentationState {
        try VisionWindowedPresentationState.windowedOnly(
            ownership: presentationOwnership(),
            revision: TVVisionSemanticRevision(rawValue: revision),
            surfaceGeneration: generation(.surface, 1),
            reason: reason
        )
    }

    private func presentationOwnership() throws -> TVVisionPresentationOwnership {
        try TVVisionPresentationOwnership(
            platform: .visionOS,
            sessionID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            mediaGeneration: 1,
            presentationGeneration: generation(.presentation, 1),
            inputGeneration: generation(.input, 1)
        )
    }

    private func sceneSurface(
        platform: TVVisionPlatform = .visionOS
    ) throws -> TVVisionSceneSurfaceSnapshot {
        let surfaceGeneration = try generation(.surface, 1)
        let geometry = try TVVisionSurfaceGeometry(
            platform: platform,
            surfaceGeneration: surfaceGeneration,
            viewBounds: TVVisionRect(
                x: 0,
                y: 0,
                width: 1280,
                height: 720
            ),
            windowBounds: TVVisionRect(
                x: 0,
                y: 0,
                width: 1280,
                height: 720
            ),
            safeAreaInsets: .zero,
            scale: 2,
            drawableSize: PixelSize(width: 2560, height: 1440)
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

    private func inputCapabilities(
        platform: TVVisionPlatform = .visionOS,
        supported: Set<TVVisionInputCapability> = [.keyboard, .pointer],
        focusEligibility: TVVisionFocusEligibility = .eligible
    ) throws -> TVVisionInputCapabilitySnapshot {
        try TVVisionInputCapabilitySnapshot(
            platform: platform,
            revision: TVVisionSemanticRevision(rawValue: 1),
            inputGeneration: generation(.input, 1),
            supported: supported,
            focusEligibility: focusEligibility
        )
    }

    private func audioRoute(
        platform: TVVisionPlatform = .visionOS,
        channelCount: Int = 2
    ) throws -> TVVisionAudioRouteSnapshot {
        try TVVisionAudioRouteSnapshot(
            platform: platform,
            revision: TVVisionSemanticRevision(rawValue: 1),
            routeGeneration: generation(.audioRoute, 1),
            outputAvailable: true,
            currentOutputChannelCount: channelCount,
            maximumOutputChannelCount: max(channelCount, 8),
            spatialSupport: .supported,
            platformStrategy: platform == .visionOS
                ? .visionOutputExperience
                : .environmentListener,
            headTrackingCapability: platform == .visionOS
                ? .intendedSpatialExperience
                : .entitlementRequired,
            runtimeStage: .running,
            eventCause: .initial,
            spatialPresentationMode: .headTracked,
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
