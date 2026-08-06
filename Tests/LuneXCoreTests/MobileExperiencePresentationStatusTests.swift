import XCTest

final class MobileExperiencePresentationStatusTests: XCTestCase {
    func testNoSessionNeverClaimsActualMobileState() {
        let status = resolve(hasActiveSession: false)

        XCTAssertEqual(status.scene, .noSession)
        XCTAssertEqual(status.pictureInPicture, .noSession)
        XCTAssertEqual(status.continuity, .noSession)
        XCTAssertEqual(status.display, .noSession)
        XCTAssertEqual(status.pictureInPictureCommand, .hidden)
    }

    func testReadyPictureInPictureExposesStartCommand() {
        let status = resolve(
            hasActiveSession: true,
            scene: attachedScene(activity: .active),
            pictureInPicture: pictureInPictureState(lifecycle: .ready),
            continuityPath: .foreground,
            streamDirective: .running,
            displayEDR: edrState(potential: 4, current: 2),
            hdrPresentation: .sdr
        )

        XCTAssertEqual(status.scene, .active)
        XCTAssertEqual(status.pictureInPicture, .ready)
        XCTAssertEqual(status.continuity, .foreground)
        XCTAssertEqual(
            status.display,
            .edrCapable(potentialHeadroom: 4, currentHeadroom: 2)
        )
        XCTAssertEqual(status.pictureInPictureCommand, .start)
    }

    func testConfirmedPictureInPictureExposesStopAndEDRActiveTruth() {
        let status = resolve(
            hasActiveSession: true,
            scene: attachedScene(activity: .background),
            pictureInPicture: pictureInPictureState(lifecycle: .active),
            continuityPath: .pictureInPicture,
            streamDirective: .running,
            displayEDR: edrState(potential: 6, current: 3.5),
            hdrPresentation: .edr
        )

        XCTAssertEqual(status.scene, .background)
        XCTAssertEqual(status.pictureInPicture, .active)
        XCTAssertEqual(status.continuity, .pictureInPicture)
        XCTAssertEqual(status.display, .edrActive(currentHeadroom: 3.5))
        XCTAssertEqual(status.pictureInPictureCommand, .stop)
    }

    func testPendingStopRemainsVisibleButDisablesDuplicateCommand() {
        let status = resolve(
            hasActiveSession: true,
            pictureInPicture: pictureInPictureState(lifecycle: .stopping),
            continuityPath: .pictureInPicture,
            streamDirective: .running
        )

        XCTAssertEqual(status.pictureInPicture, .stopping)
        XCTAssertEqual(status.pictureInPictureCommand, .stopPending)
    }

    func testPreferenceDoesNotClaimRuntimeAndHidesCommand() {
        var preferences = ContinuityPreferences.defaults
        preferences.pictureInPictureEnabled = false
        let status = resolve(
            hasActiveSession: true,
            pictureInPicture: pictureInPictureState(lifecycle: .active),
            continuityPath: .audioOnly,
            streamDirective: .running,
            preferences: preferences
        )

        XCTAssertEqual(status.pictureInPicture, .disabled)
        XCTAssertEqual(status.continuity, .audioOnly)
        XCTAssertEqual(status.pictureInPictureCommand, .hidden)
    }

    func testPausedPolicyAndInvalidHeadroomRemainExplicit() {
        let status = resolve(
            hasActiveSession: true,
            scene: .unavailable(activity: .inactive, reason: .invalidScale),
            continuityPath: .unavailable,
            streamDirective: .paused(reason: .noActivePermittedMediaPath),
            displayEDR: .sdrFallback(
                display: nil,
                reason: .invalidCurrentHeadroom
            ),
            hdrPresentation: .sdrFallback(.displayCapabilityUnavailable)
        )

        XCTAssertEqual(status.scene, .invalidGeometry)
        XCTAssertEqual(status.continuity, .paused)
        XCTAssertEqual(status.display, .invalidHeadroom)
    }

    func testResizeAndDisplayReconfigurationHaveDistinctStates() {
        let status = resolve(
            hasActiveSession: true,
            scene: attachedScene(activity: .active, resizePhase: .resizing),
            displayEDR: edrState(potential: 4, current: 2),
            hdrPresentation: .updating
        )

        XCTAssertEqual(status.scene, .resizing)
        XCTAssertEqual(status.display, .reconfiguring)
    }

    func testRootViewUsesActualMobileStateWithAccessibleLocalizedLayouts()
        throws
    {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let rootViewURL = repositoryRoot
            .appendingPathComponent("Sources/LuneXApp/RootView.swift")
        let source = try String(contentsOf: rootViewURL, encoding: .utf8)

        let requiredContracts = [
            "let mobileStatus = appModel.mobileExperiencePresentationStatus",
            "MobilePictureInPictureCommandButton()",
            "MobileActualStatusRows(",
            "MobileActualStatusPill(",
            "continuityPreferenceControls",
            "ViewThatFits(in: .horizontal)",
            "dynamicTypeSize.isAccessibilitySize",
            "systemImage: \"pip.enter\"",
            "systemImage: \"pip.exit\"",
            ".accessibilityLabel(Text(label))",
            ".accessibilityValue(value)",
            "let title: LocalizedStringResource",
            "Text(\"Current headroom is \\(current, format:",
            "Text(\"EDR active at \\(current, format:"
        ]
        for contract in requiredContracts {
            XCTAssertTrue(source.contains(contract), "Missing \(contract)")
        }
        XCTAssertFalse(source.contains(
            "settings.continuity.pictureInPictureEnabled ? \"Active\""
        ))
        XCTAssertFalse(source.contains(
            "Text(verbatim: content.accessibilityValue)"
        ))
    }

    private func resolve(
        hasActiveSession: Bool,
        scene: MobileSceneWindowState? = nil,
        pictureInPicture: MobilePictureInPictureSemanticState? = nil,
        continuityPath: MobileContinuityPath? = nil,
        streamDirective: MobileMediaStreamDirective? = nil,
        displayEDR: MobileDisplayEDRState? = nil,
        hdrPresentation: HDRPresentationStatus = .inactive,
        preferences: ContinuityPreferences = .defaults
    ) -> MobileExperiencePresentationStatus {
        MobileExperiencePresentationStatusResolver.resolve(
            hasActiveSession: hasActiveSession,
            scene: scene,
            pictureInPicture: pictureInPicture,
            continuityPath: continuityPath,
            streamDirective: streamDirective,
            displayEDR: displayEDR,
            hdrPresentation: hdrPresentation,
            preferences: preferences
        )
    }

    private func attachedScene(
        activity: AppSceneActivity,
        resizePhase: MobileSceneResizePhase = .settled
    ) -> MobileSceneWindowState {
        .attached(
            activity: activity,
            display: MobileDisplayGeneration(rawValue: 1)!,
            geometry: MobileSceneWindowGeometry(
                viewBounds: MobileSceneRect(x: 0, y: 0, width: 1_024, height: 768),
                windowBounds: MobileSceneRect(x: 0, y: 0, width: 1_024, height: 768),
                safeAreaInsets: .zero,
                scale: 2,
                drawableSize: PixelSize(width: 2_048, height: 1_536),
                orientation: .landscapeLeft,
                traits: MobileSceneTraits(
                    horizontalSizeClass: .regular,
                    verticalSizeClass: .regular,
                    interfaceStyle: .dark
                ),
                resizePhase: resizePhase
            )
        )
    }

    private func pictureInPictureState(
        lifecycle: MobilePictureInPictureLifecycle
    ) -> MobilePictureInPictureSemanticState {
        MobilePictureInPictureSemanticState(
            isPrepared: true,
            capability: .possible,
            lifecycle: lifecycle,
            frameSink: .ready(decoderGeneration: 1)!,
            restoration: .idle,
            failure: nil
        )
    }

    private func edrState(
        potential: Double,
        current: Double
    ) -> MobileDisplayEDRState {
        let surfaceGeneration = MobileSceneSurfaceGeneration(rawValue: 1)!
        var publisher = MobileDisplayEDRSnapshotPublisher(
            surfaceGeneration: surfaceGeneration
        )
        _ = publisher.update(MobileDisplayEDREventEnvelope(
            surfaceGeneration: surfaceGeneration,
            sample: .attached(MobileDisplayEDRReading(
                displayGeneration: 1,
                potentialHeadroom: potential,
                currentHeadroom: current
            ))
        ))
        return publisher.snapshot!.state
    }
}
