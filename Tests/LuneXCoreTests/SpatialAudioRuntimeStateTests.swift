import XCTest

final class SpatialAudioRuntimeStateTests: XCTestCase {
    func testResolverActivatesFixedSpatialBedWithoutHeadTrackingPreference() {
        let snapshot = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .iOS,
            userEnablesHeadTracking: false
        ))

        XCTAssertEqual(snapshot.presentationMode, .fixedSpatial)
        XCTAssertTrue(snapshot.spatialAudioActive)
        XCTAssertFalse(snapshot.headTrackingActive)
        XCTAssertNil(snapshot.fallbackReason)
        XCTAssertEqual(snapshot.diagnosticCode, "spatial_audio_fixed-spatial")
    }

    func testResolverRequiresCompatiblePlatformStrategyForFixedSpatialMode() {
        let mobile = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .iOS,
            strategy: .visionOutputExperience,
            userEnablesHeadTracking: false
        ))
        let vision = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .visionOS,
            entitlement: .notRequired,
            strategy: .environmentListener,
            userEnablesHeadTracking: false
        ))

        XCTAssertEqual(mobile.presentationMode, .nonspatial)
        XCTAssertEqual(mobile.fallbackReason, .incompatiblePlatformStrategy)
        XCTAssertEqual(vision.presentationMode, .nonspatial)
        XCTAssertEqual(vision.fallbackReason, .incompatiblePlatformStrategy)
    }

    func testResolverRequiresEntitlementAndReadbackForListenerHeadTracking() {
        let active = SpatialAudioRuntimeResolver.resolve(makeInput(platform: .tvOS))
        let missing = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .tvOS,
            entitlement: .missing
        ))
        let unreadable = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .tvOS,
            entitlement: .unreadable
        ))
        let notApplied = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .tvOS,
            listenerHeadTrackingReadback: false
        ))

        XCTAssertEqual(active.presentationMode, .headTracked)
        XCTAssertNil(active.fallbackReason)
        XCTAssertEqual(missing.presentationMode, .fixedSpatial)
        XCTAssertEqual(missing.fallbackReason, .missingEntitlement)
        XCTAssertEqual(unreadable.fallbackReason, .unreadableEntitlement)
        XCTAssertEqual(notApplied.fallbackReason, .headTrackingNotApplied)
    }

    func testResolverAllowsUnknownMacRouteOnlyWithApplicableGraph() {
        let active = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .macOS,
            routeSupport: .unknown
        ))
        let unsupported = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .macOS,
            routeSupport: .unsupported
        ))

        XCTAssertEqual(active.presentationMode, .headTracked)
        XCTAssertEqual(unsupported.presentationMode, .nonspatial)
        XCTAssertEqual(unsupported.fallbackReason, .routeUnsupported)
    }

    func testResolverUsesVisionOutputExperienceInsteadOfListenerProperty() {
        let input = makeInput(
            platform: .visionOS,
            entitlement: .notRequired,
            strategy: .visionOutputExperience,
            listenerHeadTrackingCapable: false,
            listenerHeadTrackingReadback: false,
            visionExperienceReadback: .headTracked
        )

        let snapshot = SpatialAudioRuntimeResolver.resolve(input)

        XCTAssertEqual(snapshot.presentationMode, .headTracked)
        XCTAssertEqual(snapshot.platformStrategy, .visionOutputExperience)
        XCTAssertNil(snapshot.fallbackReason)
    }

    func testResolverRequiresVisionFixedExperienceReadback() {
        let active = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .visionOS,
            entitlement: .notRequired,
            strategy: .visionOutputExperience,
            visionExperienceReadback: .fixed,
            userEnablesHeadTracking: false
        ))
        let notApplied = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .visionOS,
            entitlement: .notRequired,
            strategy: .visionOutputExperience,
            visionExperienceReadback: nil,
            userEnablesHeadTracking: false
        ))

        XCTAssertEqual(active.presentationMode, .fixedSpatial)
        XCTAssertNil(active.fallbackReason)
        XCTAssertEqual(notApplied.presentationMode, .nonspatial)
        XCTAssertEqual(notApplied.fallbackReason, .visionExperienceNotApplied)
    }

    func testResolverRejectsStaleAndInvalidRouteSnapshots() {
        let stale = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .iOS,
            graphRevision: SpatialAudioSemanticRevision(rawValue: 6)
        ))
        let invalidRoute = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .iOS,
            currentOutputChannelCount: 3,
            maximumOutputChannelCount: 2
        ))

        XCTAssertEqual(stale.presentationMode, .inactive)
        XCTAssertEqual(stale.fallbackReason, .staleRevision)
        XCTAssertEqual(invalidRoute.presentationMode, .inactive)
        XCTAssertEqual(invalidRoute.fallbackReason, .invalidRouteSnapshot)
    }

    func testResolverDistinguishesLayoutGraphAndRouteFallbacks() {
        let mono = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .iOS,
            layout: .mono,
            graphLayout: .mono
        ))
        let mismatch = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .iOS,
            graphLayout: .wave5Point1
        ))
        let graphUnavailable = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .iOS,
            graphMode: .nonspatialMixer
        ))
        let algorithmUnavailable = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .iOS,
            hasApplicableRenderingAlgorithm: false
        ))

        XCTAssertEqual(mono.fallbackReason, .unsupportedLayout)
        XCTAssertEqual(mismatch.fallbackReason, .layoutMismatch)
        XCTAssertEqual(graphUnavailable.fallbackReason, .graphUnavailable)
        XCTAssertEqual(
            algorithmUnavailable.fallbackReason,
            .renderingAlgorithmUnavailable
        )
    }

    private func makeInput(
        platform: SpatialAudioPlatform,
        layout: StreamAudioChannelLayout = .wave7Point1,
        graphLayout: StreamAudioChannelLayout = .wave7Point1,
        entitlement: SpatialAudioEntitlementState = .granted,
        routeSupport: SpatialAudioRouteSupport = .supported,
        strategy: SpatialAudioPlatformStrategy = .environmentListener,
        graphMode: SpatialAudioGraphMode = .environmentAmbienceBed,
        hasApplicableRenderingAlgorithm: Bool = true,
        listenerHeadTrackingCapable: Bool = true,
        listenerHeadTrackingReadback: Bool = true,
        visionExperienceReadback: VisionSpatialExperienceReadback? = nil,
        userEnablesSpatialAudio: Bool = true,
        userEnablesHeadTracking: Bool = true,
        revision: SpatialAudioSemanticRevision = SpatialAudioSemanticRevision(
            rawValue: 7
        ),
        graphRevision: SpatialAudioSemanticRevision? = nil,
        currentOutputChannelCount: Int = 2,
        maximumOutputChannelCount: Int = 8
    ) -> SpatialAudioResolutionInput {
        SpatialAudioResolutionInput(
            revision: revision,
            platform: platform,
            layout: layout,
            graph: SpatialAudioGraphSnapshot(
                revision: graphRevision ?? revision,
                mode: graphMode,
                layoutSignature: graphLayout.signature,
                hasApplicableRenderingAlgorithm: hasApplicableRenderingAlgorithm,
                platformStrategy: strategy,
                listenerHeadTrackingCapable: listenerHeadTrackingCapable,
                listenerHeadTrackingReadback: listenerHeadTrackingReadback,
                visionExperienceReadback: visionExperienceReadback
            ),
            route: SpatialAudioRouteCapabilitySnapshot(
                revision: revision,
                outputAvailable: true,
                systemSpatialSupport: routeSupport,
                currentOutputChannelCount: currentOutputChannelCount,
                maximumOutputChannelCount: maximumOutputChannelCount
            ),
            entitlement: entitlement,
            userEnablesSpatialAudio: userEnablesSpatialAudio,
            userEnablesHeadTracking: userEnablesHeadTracking
        )
    }
}
