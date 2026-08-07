import Foundation
import XCTest

final class TVVisionPlatformPresentationStateTests: XCTestCase {
    func testGenerationIsDomainCheckedMonotonicAndDecodeChecked() throws {
        let generation = try TVVisionGeneration(
            domain: .surface,
            rawValue: 7
        )

        XCTAssertEqual(try generation.advanced().rawValue, 8)
        XCTAssertNoThrow(try generation.require(.surface))
        XCTAssertThrowsError(try generation.require(.input)) { error in
            XCTAssertEqual(
                error as? TVVisionPlatformContractError,
                .generationDomainMismatch(
                    expected: .input,
                    actual: .surface
                )
            )
        }
        XCTAssertThrowsError(
            try TVVisionGeneration(domain: .surface, rawValue: 0)
        ) { error in
            XCTAssertEqual(
                error as? TVVisionPlatformContractError,
                .invalidGeneration(.surface)
            )
        }
        XCTAssertThrowsError(try JSONDecoder().decode(
            TVVisionGeneration.self,
            from: Data(#"{"domain":"input","rawValue":0}"#.utf8)
        ))
        let exhausted = try TVVisionGeneration(
            domain: .controller,
            rawValue: .max
        )
        XCTAssertThrowsError(try exhausted.advanced()) { error in
            XCTAssertEqual(
                error as? TVVisionPlatformContractError,
                .generationExhausted(.controller)
            )
        }
    }

    func testSemanticRevisionRejectsZeroAndExhaustion() throws {
        let revision = try TVVisionSemanticRevision(rawValue: 4)
        XCTAssertEqual(try revision.advanced().rawValue, 5)
        XCTAssertThrowsError(try TVVisionSemanticRevision(rawValue: 0))
        XCTAssertThrowsError(try JSONDecoder().decode(
            TVVisionSemanticRevision.self,
            from: Data("0".utf8)
        ))
        let exhausted = try TVVisionSemanticRevision(rawValue: .max)
        XCTAssertThrowsError(try exhausted.advanced()) { error in
            XCTAssertEqual(
                error as? TVVisionPlatformContractError,
                .semanticRevisionExhausted
            )
        }
    }

    func testOwnershipRequiresBrandedGenerations() throws {
        let presentation = try generation(.presentation, 1)
        let input = try generation(.input, 2)
        let ownership = try TVVisionPresentationOwnership(
            platform: .tvOS,
            sessionID: UUID(),
            mediaGeneration: 3,
            presentationGeneration: presentation,
            inputGeneration: input
        )

        XCTAssertEqual(ownership.presentationGeneration, presentation)
        XCTAssertEqual(ownership.inputGeneration, input)
        XCTAssertThrowsError(try TVVisionPresentationOwnership(
            platform: .tvOS,
            sessionID: UUID(),
            mediaGeneration: 0,
            presentationGeneration: presentation,
            inputGeneration: input
        ))
        XCTAssertThrowsError(try TVVisionPresentationOwnership(
            platform: .tvOS,
            sessionID: UUID(),
            mediaGeneration: 3,
            presentationGeneration: input,
            inputGeneration: input
        ))
    }

    func testGeometryRequiresFiniteBoundsAndMatchingDrawable() throws {
        let geometry = try makeGeometry(platform: .tvOS)

        XCTAssertEqual(geometry.drawableSize, PixelSize(width: 3840, height: 2160))
        XCTAssertThrowsError(try makeGeometry(
            platform: .tvOS,
            scale: .infinity
        )) { error in
            XCTAssertEqual(
                error as? TVVisionPlatformContractError,
                .invalidGeometry(.invalidScale)
            )
        }
        XCTAssertThrowsError(try makeGeometry(
            platform: .tvOS,
            drawableSize: PixelSize(width: 1920, height: 1080)
        )) { error in
            XCTAssertEqual(
                error as? TVVisionPlatformContractError,
                .invalidGeometry(.drawableSizeMismatch)
            )
        }
        XCTAssertThrowsError(try TVVisionSurfaceGeometry(
            platform: .visionOS,
            surfaceGeneration: generation(.surface, 1),
            viewBounds: TVVisionRect(
                x: 0,
                y: 0,
                width: .nan,
                height: 720
            ),
            windowBounds: TVVisionRect(
                x: 0,
                y: 0,
                width: 1280,
                height: 720
            ),
            safeAreaInsets: .zero,
            scale: 1,
            drawableSize: PixelSize(width: 1280, height: 720)
        ))
    }

    func testSceneSurfaceRequiresConsistentAttachment() throws {
        let revision = try semanticRevision()
        let surfaceGeneration = try generation(.surface, 1)
        let geometry = try makeGeometry(platform: .visionOS)
        let attached = try TVVisionSceneSurfaceSnapshot(
            platform: .visionOS,
            revision: revision,
            surfaceGeneration: surfaceGeneration,
            activity: .active,
            attachment: .attached,
            isVisible: true,
            geometry: geometry
        )

        XCTAssertEqual(attached.geometry, geometry)
        XCTAssertThrowsError(try TVVisionSceneSurfaceSnapshot(
            platform: .visionOS,
            revision: revision,
            surfaceGeneration: surfaceGeneration,
            activity: .active,
            attachment: .detached,
            isVisible: true,
            geometry: nil
        ))
        XCTAssertThrowsError(try TVVisionSceneSurfaceSnapshot(
            platform: .tvOS,
            revision: revision,
            surfaceGeneration: surfaceGeneration,
            activity: .active,
            attachment: .attached,
            isVisible: true,
            geometry: geometry
        ))
    }

    func testInputCapabilitiesArePlatformBound() throws {
        let revision = try semanticRevision()
        let inputGeneration = try generation(.input, 1)
        let tvOS = try TVVisionInputCapabilitySnapshot(
            platform: .tvOS,
            revision: revision,
            inputGeneration: inputGeneration,
            supported: [.tvRemote, .extendedGamepad, .keyboard],
            focusEligibility: .eligible
        )
        let visionOS = try TVVisionInputCapabilitySnapshot(
            platform: .visionOS,
            revision: revision,
            inputGeneration: inputGeneration,
            supported: [.extendedGamepad, .keyboard, .pointer, .indirectPointer],
            focusEligibility: .ineligible(.overlayVisible)
        )

        XCTAssertTrue(tvOS.supported.contains(.tvRemote))
        XCTAssertTrue(visionOS.supported.contains(.indirectPointer))
        XCTAssertThrowsError(try TVVisionInputCapabilitySnapshot(
            platform: .visionOS,
            revision: revision,
            inputGeneration: inputGeneration,
            supported: [.tvRemote],
            focusEligibility: .eligible
        )) { error in
            XCTAssertEqual(
                error as? TVVisionPlatformContractError,
                .unsupportedInputCapability(
                    platform: .visionOS,
                    capability: .tvRemote
                )
            )
        }
    }

    func testControllerSlotAndLeaseAreBoundedAndBranded() throws {
        XCTAssertEqual(try TVVisionControllerSlot(15).rawValue, 15)
        XCTAssertThrowsError(try TVVisionControllerSlot(-1))
        XCTAssertThrowsError(try TVVisionControllerSlot(16))
        XCTAssertThrowsError(try JSONDecoder().decode(
            TVVisionControllerSlot.self,
            from: Data("16".utf8)
        ))

        let lease = try makeControllerLease(slot: 3, lease: 9)
        XCTAssertEqual(lease.slot.rawValue, 3)
        XCTAssertThrowsError(try TVVisionControllerLease(
            platform: .tvOS,
            leaseGeneration: generation(.display, 1),
            inputGeneration: generation(.input, 1),
            slot: TVVisionControllerSlot(0),
            profile: .extendedGamepad,
            capabilities: [.rumble]
        ))
    }

    func testDisplaySnapshotPreservesPlatformHeadroomBoundary() throws {
        let revision = try semanticRevision()
        let displayGeneration = try generation(.display, 1)
        let tvOS = try TVVisionDisplaySnapshot(
            platform: .tvOS,
            revision: revision,
            displayGeneration: displayGeneration,
            isOutputAvailable: true,
            headroomSource: .platformReported,
            currentEDRHeadroom: 1.5,
            potentialEDRHeadroom: 4,
            layerCapability: .preferredDynamicRange
        )
        let visionOS = try TVVisionDisplaySnapshot(
            platform: .visionOS,
            revision: revision,
            displayGeneration: displayGeneration,
            isOutputAvailable: true,
            headroomSource: .unavailable,
            currentEDRHeadroom: nil,
            potentialEDRHeadroom: nil,
            layerCapability: .toneMappingOnly
        )

        XCTAssertEqual(tvOS.currentEDRHeadroom, 1.5)
        XCTAssertNil(visionOS.currentEDRHeadroom)
        XCTAssertEqual(visionOS.headroomSource, .unavailable)
        XCTAssertThrowsError(try TVVisionDisplaySnapshot(
            platform: .tvOS,
            revision: revision,
            displayGeneration: displayGeneration,
            isOutputAvailable: true,
            headroomSource: .platformReported,
            currentEDRHeadroom: 4,
            potentialEDRHeadroom: 2,
            layerCapability: .preferredDynamicRange
        ))
        XCTAssertThrowsError(try TVVisionDisplaySnapshot(
            platform: .visionOS,
            revision: revision,
            displayGeneration: displayGeneration,
            isOutputAvailable: true,
            headroomSource: .unavailable,
            currentEDRHeadroom: 1,
            potentialEDRHeadroom: 2,
            layerCapability: .preferredDynamicRange
        ))
        let partialHeadroom = try TVVisionDisplaySnapshot(
            platform: .tvOS,
            revision: revision,
            displayGeneration: displayGeneration,
            isOutputAvailable: true,
            headroomSource: .unavailable,
            currentEDRHeadroom: nil,
            potentialEDRHeadroom: 4,
            layerCapability: .preferredDynamicRange
        )
        XCTAssertEqual(partialHeadroom.potentialEDRHeadroom, 4)
        XCTAssertThrowsError(try TVVisionDisplaySnapshot(
            platform: .tvOS,
            revision: revision,
            displayGeneration: displayGeneration,
            isOutputAvailable: false,
            headroomSource: .unavailable,
            currentEDRHeadroom: nil,
            potentialEDRHeadroom: 4,
            layerCapability: .unavailable
        ))
        let directResolution = TVOSDisplayHDRCapabilityResolution.directEDR(
            TVOSDisplayHDRCapabilities(
                layerCapability: .preferredDynamicRange,
                supportedEDRGamuts: [.displayP3],
                currentEDRHeadroom: 2,
                potentialEDRHeadroom: 4
            )
        )
        XCTAssertThrowsError(try TVVisionDisplaySnapshot(
            platform: .visionOS,
            revision: revision,
            displayGeneration: displayGeneration,
            isOutputAvailable: true,
            headroomSource: .platformReported,
            currentEDRHeadroom: 2,
            potentialEDRHeadroom: 4,
            layerCapability: .preferredDynamicRange,
            tvOSHDRCapabilityResolution: directResolution
        ))
        XCTAssertThrowsError(try TVVisionDisplaySnapshot(
            platform: .tvOS,
            revision: revision,
            displayGeneration: displayGeneration,
            isOutputAvailable: true,
            headroomSource: .platformReported,
            currentEDRHeadroom: 2,
            potentialEDRHeadroom: 3,
            layerCapability: .preferredDynamicRange,
            tvOSHDRCapabilityResolution: directResolution
        ))
        XCTAssertThrowsError(try TVVisionDisplaySnapshot(
            platform: .tvOS,
            revision: revision,
            displayGeneration: displayGeneration,
            isOutputAvailable: true,
            headroomSource: .unavailable,
            currentEDRHeadroom: nil,
            potentialEDRHeadroom: nil,
            layerCapability: .preferredDynamicRange,
            tvOSHDRCapabilityResolution: .directEDR(
                TVOSDisplayHDRCapabilities(
                    layerCapability: .preferredDynamicRange,
                    supportedEDRGamuts: [.displayP3],
                    currentEDRHeadroom: nil,
                    potentialEDRHeadroom: nil
                )
            )
        ))
    }

    func testTVOSDisplayHDRCapabilityRequiresCompletePublicContract() {
        let capabilities = TVOSDisplayHDRCapabilities(
            layerCapability: .preferredDynamicRange,
            supportedEDRGamuts: [.displayP3, .ituR2020],
            currentEDRHeadroom: 2.5,
            potentialEDRHeadroom: 4
        )

        XCTAssertEqual(
            TVOSDisplayHDRCapabilityResolver.resolve(
                TVOSDisplayHDRCapabilityInputs(
                    isOutputAvailable: true,
                    layerCapability: .preferredDynamicRange,
                    supportsToneMapControl: true,
                    supportsContentsHeadroom: true,
                    supportedEDRGamuts: [.displayP3, .ituR2020],
                    currentEDRHeadroom: 2.5,
                    potentialEDRHeadroom: 4
                )
            ),
            .directEDR(capabilities)
        )
    }

    func testTVOSDisplayHDRCapabilityReportsLayerAndColorFallbacks() {
        func fallback(
            output: Bool = true,
            layer: TVVisionLayerDynamicRangeCapability = .preferredDynamicRange,
            toneMap: Bool = true,
            contentsHeadroom: Bool = true,
            gamuts: Set<HDROutputGamut> = [.displayP3]
        ) -> TVOSDisplayHDRFallbackReason? {
            TVOSDisplayHDRCapabilityResolver.resolve(
                TVOSDisplayHDRCapabilityInputs(
                    isOutputAvailable: output,
                    layerCapability: layer,
                    supportsToneMapControl: toneMap,
                    supportsContentsHeadroom: contentsHeadroom,
                    supportedEDRGamuts: gamuts,
                    currentEDRHeadroom: 2,
                    potentialEDRHeadroom: 4
                )
            ).fallbackReason
        }

        XCTAssertEqual(fallback(output: false), .outputUnavailable)
        XCTAssertEqual(
            fallback(layer: .toneMappingOnly),
            .preferredDynamicRangeUnavailable
        )
        XCTAssertEqual(fallback(toneMap: false), .toneMapControlUnavailable)
        XCTAssertEqual(
            fallback(contentsHeadroom: false),
            .contentsHeadroomUnavailable
        )
        XCTAssertEqual(
            fallback(gamuts: []),
            .extendedColorSpaceUnavailable
        )
    }

    func testTVOSDisplayHDRCapabilityClearsHeadroomWhenOutputIsUnavailable() {
        let resolution = TVOSDisplayHDRCapabilityResolver.resolve(
            TVOSDisplayHDRCapabilityInputs(
                isOutputAvailable: false,
                layerCapability: .unavailable,
                supportsToneMapControl: false,
                supportsContentsHeadroom: false,
                supportedEDRGamuts: [.displayP3],
                currentEDRHeadroom: 2.5,
                potentialEDRHeadroom: 4
            )
        )

        XCTAssertEqual(resolution.fallbackReason, .outputUnavailable)
        XCTAssertNil(resolution.capabilities.currentEDRHeadroom)
        XCTAssertNil(resolution.capabilities.potentialEDRHeadroom)
    }

    func testTVOSDisplayHDRCapabilityRejectsMissingInvalidAndSDRHeadroom() {
        func fallback(
            current: Double?,
            potential: Double?
        ) -> TVOSDisplayHDRFallbackReason? {
            TVOSDisplayHDRCapabilityResolver.resolve(
                TVOSDisplayHDRCapabilityInputs(
                    isOutputAvailable: true,
                    layerCapability: .preferredDynamicRange,
                    supportsToneMapControl: true,
                    supportsContentsHeadroom: true,
                    supportedEDRGamuts: [.ituR2020],
                    currentEDRHeadroom: current,
                    potentialEDRHeadroom: potential
                )
            ).fallbackReason
        }

        XCTAssertEqual(
            fallback(current: nil, potential: 4),
            .headroomUnavailable
        )
        XCTAssertEqual(
            fallback(current: 2, potential: nil),
            .headroomUnavailable
        )
        let invalid = TVOSDisplayHDRCapabilityResolver.resolve(
            TVOSDisplayHDRCapabilityInputs(
                isOutputAvailable: true,
                layerCapability: .preferredDynamicRange,
                supportsToneMapControl: true,
                supportsContentsHeadroom: true,
                supportedEDRGamuts: [.ituR2020],
                currentEDRHeadroom: .nan,
                potentialEDRHeadroom: 4
            )
        )
        XCTAssertEqual(invalid.fallbackReason, .invalidHeadroom)
        XCTAssertNil(invalid.capabilities.currentEDRHeadroom)
        XCTAssertEqual(invalid.capabilities.potentialEDRHeadroom, 4)
        let nonfinitePotential = TVOSDisplayHDRCapabilityResolver.resolve(
            TVOSDisplayHDRCapabilityInputs(
                isOutputAvailable: true,
                layerCapability: .preferredDynamicRange,
                supportsToneMapControl: true,
                supportsContentsHeadroom: true,
                supportedEDRGamuts: [.ituR2020],
                currentEDRHeadroom: 2,
                potentialEDRHeadroom: .infinity
            )
        )
        XCTAssertEqual(nonfinitePotential.fallbackReason, .invalidHeadroom)
        XCTAssertEqual(nonfinitePotential.capabilities.currentEDRHeadroom, 2)
        XCTAssertNil(nonfinitePotential.capabilities.potentialEDRHeadroom)
        let outOfRangePotential = TVOSDisplayHDRCapabilityResolver.resolve(
            TVOSDisplayHDRCapabilityInputs(
                isOutputAvailable: true,
                layerCapability: .preferredDynamicRange,
                supportsToneMapControl: true,
                supportsContentsHeadroom: true,
                supportedEDRGamuts: [.ituR2020],
                currentEDRHeadroom: 2,
                potentialEDRHeadroom: 65
            )
        )
        XCTAssertEqual(outOfRangePotential.fallbackReason, .invalidHeadroom)
        XCTAssertNil(outOfRangePotential.capabilities.potentialEDRHeadroom)
        XCTAssertEqual(
            fallback(current: 4, potential: 2),
            .invalidHeadroom
        )
        XCTAssertEqual(
            fallback(current: 65, potential: 65),
            .invalidHeadroom
        )
        XCTAssertEqual(
            fallback(current: 1, potential: 4),
            .insufficientHeadroom
        )
    }

    func testTVOSDisplayPublisherNormalizesFallbackAndSemanticRevisions()
        throws
    {
        let surface = try generation(.surface, 7)
        let display = try generation(.display, 11)
        var publisher = try TVOSDisplayHDRSnapshotPublisher(
            surfaceGeneration: surface
        )
        let direct = TVOSDisplayHDRCapabilityResolver.resolve(
            makeTVOSDisplayInputs(current: 2.5, potential: 4)
        )
        let directObservation = try TVOSDisplayHDRObservation(
            displayGeneration: display,
            resolution: direct
        )

        guard case let .published(first) = publisher.update(
            directObservation,
            surfaceGeneration: surface
        ) else {
            return XCTFail("Expected the first display observation to publish")
        }
        XCTAssertEqual(first.revision.rawValue, 1)
        XCTAssertEqual(first.hdrRenderSnapshot?.headroom.current, 2.5)
        XCTAssertEqual(first.hdrRenderSnapshot?.headroom.potential, 4)
        XCTAssertEqual(
            first.hdrPlatformCapabilities.extendedRangeSurfaceSupport,
            .preferredDynamicRangeAndHeadroom
        )
        XCTAssertEqual(
            publisher.update(directObservation, surfaceGeneration: surface),
            .unchanged
        )

        let invalid = TVOSDisplayHDRCapabilityResolver.resolve(
            makeTVOSDisplayInputs(current: .nan, potential: 4)
        )
        guard case let .published(fallback) = publisher.update(
            try TVOSDisplayHDRObservation(
                displayGeneration: display,
                resolution: invalid
            ),
            surfaceGeneration: surface
        ) else {
            return XCTFail("Expected the fallback observation to publish")
        }
        XCTAssertEqual(fallback.revision.rawValue, 2)
        XCTAssertNil(fallback.currentEDRHeadroom)
        XCTAssertEqual(fallback.potentialEDRHeadroom, 4)
        XCTAssertEqual(fallback.hdrRenderSnapshot?.headroom, DisplayHeadroom())
        XCTAssertEqual(
            fallback.tvOSHDRCapabilityResolution?.fallbackReason,
            .invalidHeadroom
        )
        XCTAssertEqual(
            fallback.hdrPlatformCapabilities.headroomSource,
            .unavailable
        )
    }

    func testTVOSDisplayPublisherRejectsStaleSurfaceAndExhaustsRevision()
        throws
    {
        let surface = try generation(.surface, 3)
        let display = try generation(.display, 4)
        let observation = try TVOSDisplayHDRObservation(
            displayGeneration: display,
            resolution: TVOSDisplayHDRCapabilityResolver.resolve(
                makeTVOSDisplayInputs(current: 2, potential: 3)
            )
        )
        var publisher = try TVOSDisplayHDRSnapshotPublisher(
            surfaceGeneration: surface,
            initialRevisionRawValue: UInt64.max
        )

        XCTAssertEqual(
            publisher.update(
                observation,
                surfaceGeneration: try generation(.surface, 2)
            ),
            .staleSurfaceGeneration
        )
        XCTAssertEqual(
            publisher.update(observation, surfaceGeneration: surface),
            .revisionExhausted
        )
        XCTAssertTrue(publisher.isRevisionExhausted)
        XCTAssertNil(publisher.snapshot)
        XCTAssertEqual(
            publisher.update(observation, surfaceGeneration: surface),
            .revisionExhausted
        )
    }

    @MainActor
    func testTVOSDisplayObserverFiltersScreenIdentityAndInvalidates() throws {
        final class Screen: NSObject {}
        final class Layer: NSObject {}
        final class ResolutionBox {
            var value: TVOSDisplayHDRCapabilityResolution

            init(_ value: TVOSDisplayHDRCapabilityResolution) {
                self.value = value
            }
        }

        let center = NotificationCenter()
        let names = TVOSDisplayHDRNotificationNames(
            modeDidChange: Notification.Name("display-mode"),
            brightnessDidChange: Notification.Name("display-brightness")
        )
        let surface = try generation(.surface, 9)
        var nextDisplayGeneration: UInt64 = 1
        let box = ResolutionBox(TVOSDisplayHDRCapabilityResolver.resolve(
            makeTVOSDisplayInputs(current: 2, potential: 4)
        ))
        var events: [TVOSDisplayHDRObserverEvent] = []
        let observer = try TVOSDisplayHDRObserver<Screen, Layer>(
            surfaceGeneration: surface,
            notificationCenter: center,
            names: names,
            generationProvider: {
                defer { nextDisplayGeneration += 1 }
                return try? TVVisionGeneration(
                    domain: .display,
                    rawValue: nextDisplayGeneration
                )
            },
            reader: { _, _ in box.value },
            handler: { events.append($0) }
        )
        let firstScreen = Screen()
        let replacementScreen = Screen()
        let layer = Layer()

        XCTAssertEqual(
            observer.attach(
                screen: firstScreen,
                layer: layer,
                surfaceGeneration: surface,
                reason: .attachment
            ),
            .published
        )
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(observer.replayCurrentEvent(surfaceGeneration: surface))
        XCTAssertEqual(events.count, 2)
        XCTAssertEqual(events[0], events[1])
        XCTAssertFalse(observer.replayCurrentEvent(
            surfaceGeneration: try generation(.surface, 8)
        ))
        center.post(name: names.modeDidChange, object: replacementScreen)
        XCTAssertEqual(events.count, 2)

        box.value = TVOSDisplayHDRCapabilityResolver.resolve(
            makeTVOSDisplayInputs(current: 3, potential: 4)
        )
        center.post(name: names.modeDidChange, object: firstScreen)
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        XCTAssertEqual(events.count, 3)

        XCTAssertEqual(
            observer.attach(
                screen: replacementScreen,
                layer: layer,
                surfaceGeneration: surface,
                reason: .attachment
            ),
            .published
        )
        guard case let .snapshot(_, replacement) = events.last else {
            return XCTFail("Expected a replacement display snapshot")
        }
        XCTAssertEqual(replacement.displayGeneration.rawValue, 2)
        XCTAssertEqual(
            observer.detach(surfaceGeneration: surface),
            .published
        )
        XCTAssertEqual(
            observer.detach(surfaceGeneration: surface),
            .unchanged
        )
        XCTAssertEqual(
            observer.attach(
                screen: firstScreen,
                layer: layer,
                surfaceGeneration: try generation(.surface, 8),
                reason: .attachment
            ),
            .staleSurfaceGeneration
        )
        XCTAssertEqual(
            observer.invalidate(surfaceGeneration: surface),
            .invalidated
        )
        XCTAssertFalse(observer.replayCurrentEvent(surfaceGeneration: surface))
        let eventCount = events.count
        center.post(name: names.modeDidChange, object: replacementScreen)
        RunLoop.main.run(until: Date().addingTimeInterval(0.01))
        XCTAssertEqual(events.count, eventCount)
        XCTAssertEqual(
            observer.invalidate(surfaceGeneration: surface),
            .alreadyInvalidated
        )
    }

    func testAudioRouteRequiresValidCountsAndPlatformStrategy() throws {
        let tvOS = try makeAudioRoute(platform: .tvOS)
        let visionOS = try makeAudioRoute(platform: .visionOS)

        XCTAssertEqual(tvOS.platformStrategy, .environmentListener)
        XCTAssertEqual(visionOS.platformStrategy, .visionOutputExperience)
        XCTAssertThrowsError(try makeAudioRoute(
            platform: .tvOS,
            currentChannels: 9,
            maximumChannels: 8
        ))
        XCTAssertThrowsError(try makeAudioRoute(
            platform: .visionOS,
            strategy: .environmentListener,
            headTracking: .intendedSpatialExperience
        )) { error in
            XCTAssertEqual(
                error as? TVVisionPlatformContractError,
                .incompatibleAudioStrategy
            )
        }
        XCTAssertThrowsError(try makeAudioRoute(
            platform: .tvOS,
            strategy: SpatialAudioPlatformStrategy.none,
            headTracking: .entitlementRequired
        )) { error in
            XCTAssertEqual(
                error as? TVVisionPlatformContractError,
                .incompatibleAudioStrategy
            )
        }
        XCTAssertNoThrow(try TVVisionAudioRouteSnapshot(
            platform: .visionOS,
            revision: semanticRevision(),
            routeGeneration: generation(.audioRoute, 1),
            outputAvailable: false,
            currentOutputChannelCount: 0,
            maximumOutputChannelCount: 0,
            spatialSupport: .unknown,
            platformStrategy: .none,
            headTrackingCapability: .unavailable,
            runtimeStage: .stopped,
            eventCause: .stopped,
            spatialPresentationMode: .inactive,
            spatialFallbackReason: .outputUnavailable
        ))
    }

    func testTVOSAudioPublisherPublishesDirectFixedAndHeadTrackedRuntime()
        throws
    {
        var publisher = TVOSAudioRouteSnapshotPublisher()

        guard case let .published(direct) = publisher.update(
            makeTVOSAudioRuntimeEvent(sequence: 1, graphGeneration: 1)
        ) else {
            return XCTFail("Expected initial direct audio publication.")
        }
        XCTAssertEqual(direct.revision.rawValue, 1)
        XCTAssertEqual(direct.routeGeneration.rawValue, 1)
        XCTAssertEqual(direct.platformStrategy, .none)
        XCTAssertEqual(direct.spatialPresentationMode, .nonspatial)
        XCTAssertEqual(
            publisher.update(makeTVOSAudioRuntimeEvent(
                sequence: 2,
                graphGeneration: 1
            )),
            .unchanged
        )

        guard case let .published(fixed) = publisher.update(
            makeTVOSAudioRuntimeEvent(
                sequence: 3,
                graphGeneration: 2,
                routeRevision: 2,
                strategy: .environmentListener,
                presentationMode: .fixedSpatial
            )
        ) else {
            return XCTFail("Expected fixed spatial audio publication.")
        }
        XCTAssertEqual(fixed.revision.rawValue, 2)
        XCTAssertEqual(fixed.routeGeneration.rawValue, 2)
        XCTAssertEqual(fixed.headTrackingCapability, .entitlementRequired)
        XCTAssertEqual(fixed.spatialPresentationMode, .fixedSpatial)

        guard case let .published(headTracked) = publisher.update(
            makeTVOSAudioRuntimeEvent(
                sequence: 4,
                graphGeneration: 3,
                routeRevision: 3,
                strategy: .environmentListener,
                presentationMode: .headTracked,
                entitlement: .granted
            )
        ) else {
            return XCTFail("Expected head-tracked audio publication.")
        }
        XCTAssertEqual(headTracked.revision.rawValue, 3)
        XCTAssertEqual(headTracked.routeGeneration.rawValue, 3)
        XCTAssertEqual(headTracked.spatialPresentationMode, .headTracked)
        XCTAssertNil(headTracked.spatialFallbackReason)
    }

    func testTVOSAudioPublisherNormalizesInterruptionLossAndReset() throws {
        var publisher = TVOSAudioRouteSnapshotPublisher()
        _ = publisher.update(makeTVOSAudioRuntimeEvent(
            sequence: 1,
            graphGeneration: 1,
            strategy: .environmentListener,
            presentationMode: .fixedSpatial
        ))

        guard case let .published(interrupted) = publisher.update(
            makeTVOSAudioRuntimeEvent(
                sequence: 2,
                graphGeneration: 1,
                cause: .interruptionBegan,
                stage: .interrupted,
                strategy: .environmentListener,
                presentationMode: .fixedSpatial
            )
        ) else {
            return XCTFail("Expected interrupted audio publication.")
        }
        XCTAssertTrue(interrupted.outputAvailable)
        XCTAssertEqual(interrupted.runtimeStage, .interrupted)
        XCTAssertEqual(interrupted.eventCause, .interruptionBegan)

        guard case let .published(lost) = publisher.update(
            makeTVOSAudioRuntimeEvent(
                sequence: 3,
                graphGeneration: 1,
                cause: .mediaServicesLost,
                stage: .interrupted,
                strategy: .environmentListener,
                presentationMode: .fixedSpatial
            )
        ) else {
            return XCTFail("Expected media-services-lost publication.")
        }
        XCTAssertFalse(lost.outputAvailable)
        XCTAssertEqual(lost.currentOutputChannelCount, 0)
        XCTAssertEqual(lost.maximumOutputChannelCount, 0)
        XCTAssertEqual(lost.platformStrategy, .none)
        XCTAssertEqual(lost.spatialPresentationMode, .inactive)
        XCTAssertEqual(lost.spatialFallbackReason, .outputUnavailable)

        guard case let .published(reset) = publisher.update(
            makeTVOSAudioRuntimeEvent(
                sequence: 4,
                graphGeneration: 2,
                cause: .mediaServicesReset,
                routeRevision: 2,
                strategy: .environmentListener,
                presentationMode: .headTracked
            )
        ) else {
            return XCTFail("Expected media-services-reset recovery publication.")
        }
        XCTAssertTrue(reset.outputAvailable)
        XCTAssertEqual(reset.routeGeneration.rawValue, 2)
        XCTAssertEqual(reset.runtimeStage, .running)
        XCTAssertEqual(reset.eventCause, .mediaServicesReset)
        XCTAssertEqual(reset.spatialPresentationMode, .headTracked)
    }

    func testTVOSAudioPublisherRejectsStaleAndInvalidRuntime() throws {
        var publisher = TVOSAudioRouteSnapshotPublisher()
        guard case let .published(initial) = publisher.update(
            makeTVOSAudioRuntimeEvent(
                sequence: 10,
                graphGeneration: 3,
                routeRevision: 3
            )
        ) else {
            return XCTFail("Expected initial audio publication.")
        }
        XCTAssertEqual(
            publisher.update(makeTVOSAudioRuntimeEvent(
                sequence: 10,
                graphGeneration: 4,
                routeRevision: 4
            )),
            .staleEvent
        )
        XCTAssertEqual(
            publisher.update(makeTVOSAudioRuntimeEvent(
                sequence: 11,
                graphGeneration: 2,
                routeRevision: 2
            )),
            .staleEvent
        )

        let invalidEvents = [
            makeTVOSAudioRuntimeEvent(
                sequence: 11,
                graphGeneration: 3,
                currentChannels: 9,
                maximumChannels: 8
            ),
            makeTVOSAudioRuntimeEvent(
                sequence: 12,
                graphGeneration: 3,
                strategy: .visionOutputExperience,
                presentationMode: .fixedSpatial
            ),
            makeTVOSAudioRuntimeEvent(
                sequence: 13,
                graphGeneration: 3,
                strategy: .none,
                presentationMode: .fixedSpatial
            ),
            makeTVOSAudioRuntimeEvent(
                sequence: 14,
                graphGeneration: 3,
                strategy: .environmentListener,
                presentationMode: .headTracked,
                entitlement: .missing
            ),
            makeTVOSAudioRuntimeEvent(
                sequence: 15,
                graphGeneration: 3,
                routeRevision: 1,
                runtimeRevision: 2
            ),
            makeTVOSAudioRuntimeEvent(sequence: 16, graphGeneration: 0)
        ]
        for event in invalidEvents {
            XCTAssertEqual(publisher.update(event), .invalidRuntime)
            XCTAssertEqual(publisher.snapshot, initial)
            XCTAssertFalse(publisher.isRevisionExhausted)
        }
    }

    func testTVOSAudioPublisherFailsClosedOnRevisionExhaustion() {
        var publisher = TVOSAudioRouteSnapshotPublisher(
            initialRevisionRawValue: .max
        )
        XCTAssertEqual(
            publisher.update(makeTVOSAudioRuntimeEvent(
                sequence: 1,
                graphGeneration: 1
            )),
            .revisionExhausted
        )
        XCTAssertTrue(publisher.isRevisionExhausted)
        XCTAssertNil(publisher.snapshot)
        XCTAssertEqual(
            publisher.update(makeTVOSAudioRuntimeEvent(
                sequence: 2,
                graphGeneration: 2
            )),
            .revisionExhausted
        )
    }

    func testPresentationSnapshotAcceptsOneConsistentGeneration() throws {
        let snapshot = try makePresentationSnapshot()

        XCTAssertEqual(snapshot.ownership.platform, .tvOS)
        XCTAssertEqual(snapshot.controllerLeases.map(\.slot.rawValue), [0, 1])
        XCTAssertEqual(snapshot.inputCapabilities.focusEligibility, .eligible)
    }

    func testPresentationSnapshotRejectsCrossPlatformAndStaleRevisions() throws {
        let values = try makePresentationValues()
        let visionDisplay = try TVVisionDisplaySnapshot(
            platform: .visionOS,
            revision: values.revision,
            displayGeneration: generation(.display, 1),
            isOutputAvailable: true,
            headroomSource: .unavailable,
            currentEDRHeadroom: nil,
            potentialEDRHeadroom: nil,
            layerCapability: .toneMappingOnly
        )
        XCTAssertThrowsError(try TVVisionPlatformPresentationSnapshot(
            ownership: values.ownership,
            revision: values.revision,
            sceneSurface: values.scene,
            inputCapabilities: values.input,
            controllerLeases: values.controllers,
            display: visionDisplay,
            audioRoute: values.audio
        )) { error in
            XCTAssertEqual(
                error as? TVVisionPlatformContractError,
                .platformMismatch
            )
        }

        let staleRevision = try TVVisionSemanticRevision(rawValue: 2)
        let staleInput = try TVVisionInputCapabilitySnapshot(
            platform: .tvOS,
            revision: staleRevision,
            inputGeneration: values.ownership.inputGeneration,
            supported: [.tvRemote],
            focusEligibility: .eligible
        )
        XCTAssertThrowsError(try TVVisionPlatformPresentationSnapshot(
            ownership: values.ownership,
            revision: values.revision,
            sceneSurface: values.scene,
            inputCapabilities: staleInput,
            controllerLeases: values.controllers,
            display: values.display,
            audioRoute: values.audio
        )) { error in
            XCTAssertEqual(
                error as? TVVisionPlatformContractError,
                .revisionMismatch
            )
        }
    }

    func testPresentationSnapshotRejectsDuplicateControllerOwnership() throws {
        let values = try makePresentationValues()
        let duplicateSlot = try makeControllerLease(slot: 0, lease: 3)
        XCTAssertThrowsError(try TVVisionPlatformPresentationSnapshot(
            ownership: values.ownership,
            revision: values.revision,
            sceneSurface: values.scene,
            inputCapabilities: values.input,
            controllerLeases: [values.controllers[0], duplicateSlot],
            display: values.display,
            audioRoute: values.audio
        )) { error in
            XCTAssertEqual(
                error as? TVVisionPlatformContractError,
                .duplicateControllerSlot(0)
            )
        }

        let duplicateLease = try makeControllerLease(slot: 2, lease: 1)
        XCTAssertThrowsError(try TVVisionPlatformPresentationSnapshot(
            ownership: values.ownership,
            revision: values.revision,
            sceneSurface: values.scene,
            inputCapabilities: values.input,
            controllerLeases: [values.controllers[0], duplicateLease],
            display: values.display,
            audioRoute: values.audio
        )) { error in
            XCTAssertEqual(
                error as? TVVisionPlatformContractError,
                .duplicateControllerLease(1)
            )
        }
    }

    func testEligibleInputRequiresVisibleActiveAttachedSurface() throws {
        let values = try makePresentationValues()
        let detached = try TVVisionSceneSurfaceSnapshot(
            platform: .tvOS,
            revision: values.revision,
            surfaceGeneration: generation(.surface, 1),
            activity: .background,
            attachment: .detached,
            isVisible: false,
            geometry: nil
        )

        XCTAssertThrowsError(try TVVisionPlatformPresentationSnapshot(
            ownership: values.ownership,
            revision: values.revision,
            sceneSurface: detached,
            inputCapabilities: values.input,
            controllerLeases: values.controllers,
            display: values.display,
            audioRoute: values.audio
        )) { error in
            XCTAssertEqual(
                error as? TVVisionPlatformContractError,
                .attachedSurfaceRequired
            )
        }
    }

    func testEveryGenerationDomainRejectsZeroAndExhaustion() throws {
        for domain in TVVisionGenerationDomain.allCases {
            XCTAssertThrowsError(try TVVisionGeneration(
                domain: domain,
                rawValue: 0
            )) { error in
                XCTAssertEqual(
                    error as? TVVisionPlatformContractError,
                    .invalidGeneration(domain)
                )
            }
            let exhausted = try TVVisionGeneration(
                domain: domain,
                rawValue: .max
            )
            XCTAssertThrowsError(try exhausted.advanced()) { error in
                XCTAssertEqual(
                    error as? TVVisionPlatformContractError,
                    .generationExhausted(domain)
                )
            }
        }
    }

    func testGeometryRejectsEveryFiniteAndBoundedFailureClass() throws {
        let validView = TVVisionRect(x: 0, y: 0, width: 100, height: 50)
        let validDrawable = PixelSize(width: 200, height: 100)

        func geometry(
            view: TVVisionRect = TVVisionRect(
                x: 0,
                y: 0,
                width: 100,
                height: 50
            ),
            window: TVVisionRect = TVVisionRect(
                x: 0,
                y: 0,
                width: 100,
                height: 50
            ),
            insets: TVVisionEdgeInsets = .zero,
            scale: Double = 2,
            drawable: PixelSize = PixelSize(width: 200, height: 100)
        ) throws -> TVVisionSurfaceGeometry {
            try TVVisionSurfaceGeometry(
                platform: .visionOS,
                surfaceGeneration: generation(.surface, 1),
                viewBounds: view,
                windowBounds: window,
                safeAreaInsets: insets,
                scale: scale,
                drawableSize: drawable
            )
        }

        let cases: [(
            view: TVVisionRect,
            window: TVVisionRect,
            insets: TVVisionEdgeInsets,
            scale: Double,
            drawable: PixelSize,
            error: TVVisionGeometryValidationError
        )] = [
            (
                TVVisionRect(x: .infinity, y: 0, width: 100, height: 50),
                validView,
                .zero,
                2,
                validDrawable,
                .invalidViewBounds
            ),
            (
                TVVisionRect(x: 0, y: 0, width: 0, height: 50),
                validView,
                .zero,
                2,
                validDrawable,
                .invalidViewBounds
            ),
            (
                validView,
                TVVisionRect(x: 0, y: 0, width: 100, height: .nan),
                .zero,
                2,
                validDrawable,
                .invalidWindowBounds
            ),
            (
                validView,
                validView,
                TVVisionEdgeInsets(
                    top: .nan,
                    leading: 0,
                    bottom: 0,
                    trailing: 0
                ),
                2,
                validDrawable,
                .invalidSafeAreaInsets
            ),
            (
                validView,
                validView,
                TVVisionEdgeInsets(
                    top: 0,
                    leading: 60,
                    bottom: 0,
                    trailing: 60
                ),
                2,
                validDrawable,
                .invalidSafeAreaInsets
            ),
            (validView, validView, .zero, .nan, validDrawable, .invalidScale),
            (validView, validView, .zero, 0, validDrawable, .invalidScale),
            (
                validView,
                validView,
                .zero,
                TVVisionSurfaceGeometry.maximumScale + 1,
                validDrawable,
                .invalidScale
            ),
            (
                validView,
                validView,
                .zero,
                2,
                PixelSize(width: 0, height: 100),
                .invalidDrawableSize
            ),
            (
                validView,
                validView,
                .zero,
                2,
                PixelSize(
                    width: TVVisionSurfaceGeometry.maximumDrawableDimension + 1,
                    height: 100
                ),
                .invalidDrawableSize
            ),
            (
                validView,
                validView,
                .zero,
                2,
                PixelSize(width: 201, height: 100),
                .drawableSizeMismatch
            )
        ]

        for value in cases {
            XCTAssertThrowsError(try geometry(
                view: value.view,
                window: value.window,
                insets: value.insets,
                scale: value.scale,
                drawable: value.drawable
            )) { error in
                XCTAssertEqual(
                    error as? TVVisionPlatformContractError,
                    .invalidGeometry(value.error)
                )
            }
        }
    }

    func testInputCapabilityMatrixIsExactForEachPlatform() throws {
        let allowed: [TVVisionPlatform: Set<TVVisionInputCapability>] = [
            .tvOS: [.tvRemote, .extendedGamepad, .microGamepad, .keyboard],
            .visionOS: [
                .extendedGamepad,
                .microGamepad,
                .keyboard,
                .pointer,
                .indirectPointer
            ]
        ]

        for platform in TVVisionPlatform.allCases {
            for capability in TVVisionInputCapability.allCases {
                let create = {
                    try TVVisionInputCapabilitySnapshot(
                        platform: platform,
                        revision: self.semanticRevision(),
                        inputGeneration: self.generation(.input, 1),
                        supported: [capability],
                        focusEligibility: .eligible
                    )
                }
                if allowed[platform, default: []].contains(capability) {
                    XCTAssertNoThrow(try create())
                } else {
                    XCTAssertThrowsError(try create()) { error in
                        XCTAssertEqual(
                            error as? TVVisionPlatformContractError,
                            .unsupportedInputCapability(
                                platform: platform,
                                capability: capability
                            )
                        )
                    }
                }
            }
        }
    }

    private struct PresentationValues {
        let ownership: TVVisionPresentationOwnership
        let revision: TVVisionSemanticRevision
        let scene: TVVisionSceneSurfaceSnapshot
        let input: TVVisionInputCapabilitySnapshot
        let controllers: [TVVisionControllerLease]
        let display: TVVisionDisplaySnapshot
        let audio: TVVisionAudioRouteSnapshot
    }

    private func makePresentationSnapshot() throws
        -> TVVisionPlatformPresentationSnapshot
    {
        let values = try makePresentationValues()
        return try TVVisionPlatformPresentationSnapshot(
            ownership: values.ownership,
            revision: values.revision,
            sceneSurface: values.scene,
            inputCapabilities: values.input,
            controllerLeases: Array(values.controllers.reversed()),
            display: values.display,
            audioRoute: values.audio
        )
    }

    private func makePresentationValues() throws -> PresentationValues {
        let revision = try semanticRevision()
        let ownership = try TVVisionPresentationOwnership(
            platform: .tvOS,
            sessionID: UUID(),
            mediaGeneration: 1,
            presentationGeneration: generation(.presentation, 1),
            inputGeneration: generation(.input, 1)
        )
        let geometry = try makeGeometry(platform: .tvOS)
        let scene = try TVVisionSceneSurfaceSnapshot(
            platform: .tvOS,
            revision: revision,
            surfaceGeneration: geometry.surfaceGeneration,
            activity: .active,
            attachment: .attached,
            isVisible: true,
            geometry: geometry
        )
        let input = try TVVisionInputCapabilitySnapshot(
            platform: .tvOS,
            revision: revision,
            inputGeneration: ownership.inputGeneration,
            supported: [.tvRemote, .extendedGamepad],
            focusEligibility: .eligible
        )
        let display = try TVVisionDisplaySnapshot(
            platform: .tvOS,
            revision: revision,
            displayGeneration: generation(.display, 1),
            isOutputAvailable: true,
            headroomSource: .platformReported,
            currentEDRHeadroom: 1.5,
            potentialEDRHeadroom: 4,
            layerCapability: .preferredDynamicRange
        )
        return PresentationValues(
            ownership: ownership,
            revision: revision,
            scene: scene,
            input: input,
            controllers: [
                try makeControllerLease(slot: 0, lease: 1),
                try makeControllerLease(slot: 1, lease: 2)
            ],
            display: display,
            audio: try makeAudioRoute(platform: .tvOS)
        )
    }

    private func makeGeometry(
        platform: TVVisionPlatform,
        scale: Double = 2,
        drawableSize: PixelSize = PixelSize(width: 3840, height: 2160)
    ) throws -> TVVisionSurfaceGeometry {
        try TVVisionSurfaceGeometry(
            platform: platform,
            surfaceGeneration: generation(.surface, 1),
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
            scale: scale,
            drawableSize: drawableSize
        )
    }

    private func makeControllerLease(
        slot: Int,
        lease: UInt64
    ) throws -> TVVisionControllerLease {
        try TVVisionControllerLease(
            platform: .tvOS,
            leaseGeneration: generation(.controller, lease),
            inputGeneration: generation(.input, 1),
            slot: TVVisionControllerSlot(slot),
            profile: .extendedGamepad,
            capabilities: [.rumble, .battery]
        )
    }

    private func makeAudioRoute(
        platform: TVVisionPlatform,
        currentChannels: Int = 2,
        maximumChannels: Int = 8,
        strategy: SpatialAudioPlatformStrategy? = nil,
        headTracking: TVVisionHeadTrackingCapability? = nil
    ) throws -> TVVisionAudioRouteSnapshot {
        try TVVisionAudioRouteSnapshot(
            platform: platform,
            revision: semanticRevision(),
            routeGeneration: generation(.audioRoute, 1),
            outputAvailable: true,
            currentOutputChannelCount: currentChannels,
            maximumOutputChannelCount: maximumChannels,
            spatialSupport: .supported,
            platformStrategy: strategy ?? (platform == .tvOS
                ? .environmentListener
                : .visionOutputExperience),
            headTrackingCapability: headTracking ?? (platform == .tvOS
                ? .entitlementRequired
                : .intendedSpatialExperience),
            runtimeStage: .running,
            eventCause: .initial,
            spatialPresentationMode: .fixedSpatial,
            spatialFallbackReason: nil
        )
    }

    private func makeTVOSAudioRuntimeEvent(
        sequence: UInt64,
        graphGeneration: UInt64,
        cause: SessionAudioRuntimeEventCause = .initial,
        stage: SessionAudioRuntimeStage = .running,
        outputAvailable: Bool = true,
        currentChannels: Int = 2,
        maximumChannels: Int = 8,
        routeRevision: UInt64 = 1,
        runtimeRevision: UInt64? = nil,
        strategy: SpatialAudioPlatformStrategy = .none,
        presentationMode: SpatialAudioPresentationMode = .nonspatial,
        entitlement: SpatialAudioEntitlementState = .granted
    ) -> SessionAudioRuntimeEvent {
        let routeRevision = SpatialAudioSemanticRevision(rawValue: routeRevision)
        let runtimeRevision = SpatialAudioSemanticRevision(
            rawValue: runtimeRevision ?? routeRevision.rawValue
        )
        return SessionAudioRuntimeEvent(
            sessionID: UUID(),
            sequence: sequence,
            graphGeneration: graphGeneration,
            cause: cause,
            stage: stage,
            spatialRuntime: SpatialAudioRuntimeSnapshot(
                revision: runtimeRevision,
                layoutSignature: StreamAudioChannelLayout.stereo.signature,
                graphMode: strategy == .none
                    ? .nonspatialMixer
                    : .environmentAmbienceBed,
                platformStrategy: strategy,
                routeSupport: .supported,
                presentationMode: presentationMode,
                fallbackReason: nil
            ),
            routeCapability: SpatialAudioRouteCapabilitySnapshot(
                revision: routeRevision,
                outputAvailable: outputAvailable,
                systemSpatialSupport: .supported,
                currentOutputChannelCount: currentChannels,
                maximumOutputChannelCount: maximumChannels
            ),
            entitlement: entitlement,
            preferences: .nativeDefault,
            concealedFrameCount: 0,
            lastAction: .none
        )
    }

    private func makeTVOSDisplayInputs(
        current: Double?,
        potential: Double?
    ) -> TVOSDisplayHDRCapabilityInputs {
        TVOSDisplayHDRCapabilityInputs(
            isOutputAvailable: true,
            layerCapability: .preferredDynamicRange,
            supportsToneMapControl: true,
            supportsContentsHeadroom: true,
            supportedEDRGamuts: [.displayP3, .ituR2020],
            currentEDRHeadroom: current,
            potentialEDRHeadroom: potential
        )
    }

    private func generation(
        _ domain: TVVisionGenerationDomain,
        _ rawValue: UInt64
    ) throws -> TVVisionGeneration {
        try TVVisionGeneration(domain: domain, rawValue: rawValue)
    }

    private func semanticRevision() throws -> TVVisionSemanticRevision {
        try TVVisionSemanticRevision(rawValue: 1)
    }
}
