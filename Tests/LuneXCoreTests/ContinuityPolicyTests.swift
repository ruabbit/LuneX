import XCTest

final class ContinuityPolicyTests: XCTestCase {
    func testSpatialAudioRequiresRouteEntitlementAndStereoStream() {
        let missingEntitlement = SpatialAudioAvailabilityResolver.resolve(SpatialAudioCapabilityContext(
            platform: .iOS,
            routeSupportsSpatialAudio: true,
            hasHeadPoseEntitlement: false,
            channelCount: 2,
            userEnabledHeadTracking: true
        ))
        let mono = SpatialAudioAvailabilityResolver.resolve(SpatialAudioCapabilityContext(
            platform: .iOS,
            routeSupportsSpatialAudio: true,
            hasHeadPoseEntitlement: true,
            channelCount: 1,
            userEnabledHeadTracking: true
        ))
        let available = SpatialAudioAvailabilityResolver.resolve(SpatialAudioCapabilityContext(
            platform: .iOS,
            routeSupportsSpatialAudio: true,
            hasHeadPoseEntitlement: true,
            channelCount: 6,
            userEnabledHeadTracking: true
        ))

        XCTAssertTrue(missingEntitlement.spatialAudioAvailable)
        XCTAssertFalse(missingEntitlement.headTrackingAvailable)
        XCTAssertEqual(missingEntitlement.unavailableReason, "Missing com.apple.developer.coremotion.head-pose entitlement")
        XCTAssertFalse(mono.spatialAudioAvailable)
        XCTAssertEqual(mono.unavailableReason, "Spatial audio requires a stereo or multichannel stream")
        XCTAssertTrue(available.headTrackingAvailable)
        XCTAssertTrue(available.headTrackingEnabled)
    }

    func testSpatialAudioDisablesHeadTrackingOnVisionOSSDK() {
        let state = SpatialAudioAvailabilityResolver.resolve(SpatialAudioCapabilityContext(
            platform: .visionOS,
            routeSupportsSpatialAudio: true,
            hasHeadPoseEntitlement: true,
            channelCount: 2,
            userEnabledHeadTracking: true
        ))

        XCTAssertTrue(state.spatialAudioAvailable)
        XCTAssertFalse(state.headTrackingAvailable)
        XCTAssertEqual(state.unavailableReason, "Head tracking is unavailable on this platform SDK")
    }

    func testMobileContinuityRejectsCapabilityAndConfigurationPresenceAlone()
        throws
    {
        let context = makeMobileContinuityContext(
            activeGeneration: try generation()
        )

        XCTAssertEqual(
            MobileContinuityPolicyResolver.resolve(context),
            .suspendForegroundRendering(
                reason: "No supported mobile continuity path is active"
            )
        )
    }

    func testMobileContinuityRequiresCurrentConfirmedPictureInPicture()
        throws
    {
        let current = try generation()
        let stale = try generation(media: 2, pictureInPicture: 4)
        let startRequested = makeMobileContinuityContext(
            activeGeneration: current,
            actualMediaState: actualState(
                generation: current,
                pictureInPictureLifecycle: .startRequested,
                sinkOperational: true
            )
        )
        let staleActive = makeMobileContinuityContext(
            activeGeneration: current,
            actualMediaState: actualState(
                generation: stale,
                pictureInPictureLifecycle: .active,
                sinkOperational: true
            )
        )
        let failedSink = makeMobileContinuityContext(
            activeGeneration: current,
            actualMediaState: actualState(
                generation: current,
                pictureInPictureLifecycle: .active,
                sinkOperational: false
            )
        )
        let active = makeMobileContinuityContext(
            activeGeneration: current,
            actualMediaState: actualState(
                generation: current,
                pictureInPictureLifecycle: .active,
                sinkOperational: true
            )
        )

        let unavailable = MobileContinuityAction
            .suspendForegroundRendering(
                reason: "No supported mobile continuity path is active"
            )
        XCTAssertEqual(
            MobileContinuityPolicyResolver.resolve(startRequested),
            unavailable
        )
        XCTAssertEqual(
            MobileContinuityPolicyResolver.resolve(staleActive),
            unavailable
        )
        XCTAssertEqual(
            MobileContinuityPolicyResolver.resolve(failedSink),
            unavailable
        )
        XCTAssertEqual(
            MobileContinuityPolicyResolver.resolve(active),
            .continueWithAudioAndPictureInPicture
        )
    }

    func testMobileContinuityRequiresCurrentActivePermittedAudio()
        throws
    {
        let current = try generation()
        let activePermitted = makeMobileContinuityContext(
            activeGeneration: current,
            actualMediaState: actualState(
                generation: current,
                audioActive: true,
                audioPermitted: true
            )
        )
        let activeDenied = makeMobileContinuityContext(
            activeGeneration: current,
            actualMediaState: actualState(
                generation: current,
                audioActive: true,
                audioPermitted: false
            )
        )

        XCTAssertEqual(
            MobileContinuityPolicyResolver.resolve(activePermitted),
            .continueAudioOnly
        )
        XCTAssertEqual(
            MobileContinuityPolicyResolver.resolve(activeDenied),
            .suspendForegroundRendering(
                reason: "No supported mobile continuity path is active"
            )
        )
    }

    func testMobileContinuityRequiresGenerationAndCapabilityEligibility()
        throws
    {
        let current = try generation()
        let actual = actualState(
            generation: current,
            pictureInPictureLifecycle: .active,
            sinkOperational: true,
            audioActive: true,
            audioPermitted: true
        )
        let missingGeneration = makeMobileContinuityContext(
            activeGeneration: nil,
            actualMediaState: actual
        )
        var unsupportedCapabilities = makeMobileContinuityContext(
            activeGeneration: current,
            actualMediaState: actual
        )
        unsupportedCapabilities.capabilities.supportsAudioBackgroundMode = false
        unsupportedCapabilities.capabilities.supportsPictureInPicture = false

        let unavailable = MobileContinuityAction
            .suspendForegroundRendering(
                reason: "No supported mobile continuity path is active"
            )
        XCTAssertEqual(
            MobileContinuityPolicyResolver.resolve(missingGeneration),
            unavailable
        )
        XCTAssertEqual(
            MobileContinuityPolicyResolver.resolve(unsupportedCapabilities),
            unavailable
        )
    }

    func testMobileContinuityFailsClosedWhenEligibilityDisappears()
        throws
    {
        let current = try generation()
        let actual = actualState(
            generation: current,
            pictureInPictureLifecycle: .active,
            sinkOperational: true,
            audioActive: true,
            audioPermitted: true
        )
        var missingDeclaration = makeMobileContinuityContext(
            activeGeneration: current,
            actualMediaState: actual
        )
        missingDeclaration.capabilities.hasAudioBackgroundModeDeclared = false
        var disabledPreferences = makeMobileContinuityContext(
            activeGeneration: current,
            actualMediaState: actual
        )
        disabledPreferences.preferences.pictureInPictureEnabled = false
        disabledPreferences.preferences.audioContinuityEnabled = false
        disabledPreferences.preferences.reduceRenderingInBackground = false

        XCTAssertEqual(
            MobileContinuityPolicyResolver.resolve(missingDeclaration),
            .suspendForegroundRendering(
                reason: "Playback background mode is not declared"
            )
        )
        XCTAssertEqual(
            MobileContinuityPolicyResolver.resolve(disabledPreferences),
            .pauseStream(
                reason: "No supported mobile continuity path is active"
            )
        )
    }

    func testMobileContinuityReturnsForegroundOrUnsupportedPlatform()
        throws
    {
        let current = try generation()
        let foreground = makeMobileContinuityContext(
            sceneActivity: .active,
            activeGeneration: current
        )
        let inactive = makeMobileContinuityContext(
            isStreamActive: false,
            activeGeneration: nil
        )
        let unsupported = makeMobileContinuityContext(
            platform: .visionOS,
            activeGeneration: current
        )

        XCTAssertEqual(
            MobileContinuityPolicyResolver.resolve(foreground),
            .foreground
        )
        XCTAssertEqual(
            MobileContinuityPolicyResolver.resolve(inactive),
            .foreground
        )
        XCTAssertEqual(
            MobileContinuityPolicyResolver.resolve(unsupported),
            .warn(
                reason: "Mobile background continuity is unavailable on this platform"
            )
        )
    }

    func testPictureInPictureSizeUpdatesDoNotChangeActiveState() async {
        let coordinator = PictureInPictureStateCoordinator(now: Date(timeIntervalSince1970: 1))

        let active = await coordinator.setActive(true, now: Date(timeIntervalSince1970: 2))
        let resized = await coordinator.updateRenderSize(PixelSize(width: 1280, height: 720), now: Date(timeIntervalSince1970: 3))

        XCTAssertTrue(active.isActive)
        XCTAssertTrue(resized.isActive)
        XCTAssertEqual(resized.renderSize, PixelSize(width: 1280, height: 720))
    }

    func testMacBackgroundPolicyKeepsVisibleInactiveWindowThrottledNotPaused() {
        let action = MacBackgroundPerformancePolicyResolver.resolve(MacBackgroundPerformanceContext(
            isStreamActive: true,
            isAppActive: false,
            isWindowVisible: true,
            isWindowFocused: false,
            drawableSize: PixelSize(width: 1920, height: 1080)
        ))

        XCTAssertEqual(action, .throttleRendering(reason: "App is inactive but stream window remains visible"))
    }

    func testMacBackgroundPolicyPausesOccludedWindow() {
        let action = MacBackgroundPerformancePolicyResolver.resolve(MacBackgroundPerformanceContext(
            isStreamActive: true,
            isAppActive: true,
            isWindowVisible: false,
            isWindowFocused: false,
            drawableSize: PixelSize(width: 1920, height: 1080)
        ))

        XCTAssertEqual(action, .pauseRendering(reason: "Stream window is occluded or minimized"))
    }

    private func generation(
        media: UInt64 = 3,
        pictureInPicture: UInt64 = 5
    ) throws -> MobilePictureInPictureGeneration {
        try XCTUnwrap(MobilePictureInPictureGeneration(
            mediaGeneration: media,
            pictureInPictureGeneration: pictureInPicture
        ))
    }

    private func actualState(
        generation: MobilePictureInPictureGeneration,
        pictureInPictureLifecycle:
            MobilePictureInPictureLifecycle = .unprepared,
        sinkOperational: Bool = false,
        audioActive: Bool = false,
        audioPermitted: Bool = false
    ) -> MobileContinuityActualMediaState {
        MobileContinuityActualMediaState(
            generation: generation,
            pictureInPictureLifecycle: pictureInPictureLifecycle,
            isPictureInPictureFrameSinkOperational: sinkOperational,
            isAudioSessionActive: audioActive,
            isAudioContinuityPermitted: audioPermitted
        )
    }

    private func makeMobileContinuityContext(
        platform: ApplePlatformFamily = .iPadOS,
        sceneActivity: AppSceneActivity = .background,
        isStreamActive: Bool = true,
        activeGeneration: MobilePictureInPictureGeneration?,
        actualMediaState: MobileContinuityActualMediaState? = nil
    ) -> MobileContinuityContext {
        MobileContinuityContext(
            platform: platform,
            sceneActivity: sceneActivity,
            isStreamActive: isStreamActive,
            preferences: .defaults,
            capabilities: PlatformContinuityCapabilities(
                supportsAudioBackgroundMode: true,
                supportsPictureInPicture: true,
                hasAudioBackgroundModeDeclared: true
            ),
            activeGeneration: activeGeneration,
            actualMediaState: actualMediaState
        )
    }
}
