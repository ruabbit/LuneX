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

    @MainActor
    func testDiagnosticsStoreRecordsSpatialAudioUnavailableReason() {
        let diagnostics = DiagnosticsStore()

        diagnostics.record(spatialAudioState: AudioRouteState(
            spatialAudioAvailable: true,
            headTrackingAvailable: false,
            headTrackingEnabled: false,
            unavailableReason: "Missing entitlement"
        ), date: Date(timeIntervalSince1970: 20))

        XCTAssertEqual(diagnostics.events.last?.subsystem, "audio.spatial")
        XCTAssertEqual(diagnostics.events.last?.message, "Spatial audio available, head tracking disabled; Missing entitlement")
    }

    func testMobileContinuityUsesPictureInPictureWhenSupported() {
        let action = MobileContinuityPolicyResolver.resolve(MobileContinuityContext(
            platform: .iPadOS,
            sceneActivity: .background,
            isStreamActive: true,
            preferences: .defaults,
            capabilities: PlatformContinuityCapabilities(
                supportsAudioBackgroundMode: true,
                supportsPictureInPicture: true,
                hasAudioBackgroundModeDeclared: true
            )
        ))

        XCTAssertEqual(action, .continueWithAudioAndPictureInPicture)
    }

    func testMobileContinuitySuspendsWhenNoSupportedPathIsActive() {
        let action = MobileContinuityPolicyResolver.resolve(MobileContinuityContext(
            platform: .iOS,
            sceneActivity: .background,
            isStreamActive: true,
            preferences: .defaults,
            capabilities: PlatformContinuityCapabilities(
                supportsAudioBackgroundMode: true,
                supportsPictureInPicture: false,
                hasAudioBackgroundModeDeclared: false
            )
        ))

        XCTAssertEqual(action, .suspendForegroundRendering(reason: "No supported mobile continuity path is active"))
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
}
