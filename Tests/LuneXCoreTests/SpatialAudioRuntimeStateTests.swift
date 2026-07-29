import XCTest

final class SpatialAudioRuntimeStateTests: XCTestCase {
    func testGraphIntentAndActualRuntimeAreCodableSendableValues() throws {
        let revision = SpatialAudioSemanticRevision(rawValue: 17)
        let intent = SpatialAudioGraphIntent(
            revision: revision,
            platform: .tvOS,
            route: SpatialAudioRouteCapabilitySnapshot(
                revision: revision,
                outputAvailable: true,
                systemSpatialSupport: .supported,
                currentOutputChannelCount: 8,
                maximumOutputChannelCount: 8
            ),
            entitlement: .granted,
            userEnablesSpatialAudio: true,
            userEnablesHeadTracking: true
        )
        let actual = SpatialAudioRuntimeSnapshot(
            revision: revision,
            layoutSignature: StreamAudioChannelLayout.wave7Point1.signature,
            graphMode: .environmentAmbienceBed,
            platformStrategy: .environmentListener,
            routeSupport: .supported,
            presentationMode: .headTracked,
            fallbackReason: nil
        )

        assertSendable(SpatialAudioGraphIntent.self)
        assertSendable(SpatialAudioRuntimeSnapshot.self)
        XCTAssertEqual(
            try JSONDecoder().decode(
                SpatialAudioGraphIntent.self,
                from: JSONEncoder().encode(intent)
            ),
            intent
        )
        XCTAssertEqual(
            try JSONDecoder().decode(
                SpatialAudioRuntimeSnapshot.self,
                from: JSONEncoder().encode(actual)
            ),
            actual
        )
        XCTAssertTrue(actual.isConsistent(
            with: intent,
            layout: .wave7Point1
        ))
    }

    func testResolverPlatformPreferenceRouteAndEntitlementGrid() {
        let platforms: [SpatialAudioPlatform] = [.macOS, .iOS, .tvOS, .visionOS]
        let routeSupports: [SpatialAudioRouteSupport] = [
            .supported,
            .unsupported,
            .unknown
        ]
        let entitlementStates: [SpatialAudioEntitlementState] = [
            .notRequired,
            .granted,
            .missing,
            .unreadable
        ]

        for platform in platforms {
            for spatialEnabled in [false, true] {
                for headTrackingEnabled in [false, true] {
                    for routeSupport in routeSupports {
                        for entitlement in entitlementStates {
                            let isVision = platform == .visionOS
                            let snapshot = SpatialAudioRuntimeResolver.resolve(
                                makeInput(
                                    platform: platform,
                                    entitlement: entitlement,
                                    routeSupport: routeSupport,
                                    strategy: isVision
                                        ? .visionOutputExperience
                                        : .environmentListener,
                                    visionExperienceReadback: isVision
                                        ? (headTrackingEnabled ? .headTracked : .fixed)
                                        : nil,
                                    userEnablesSpatialAudio: spatialEnabled,
                                    userEnablesHeadTracking: headTrackingEnabled
                                )
                            )
                            let expected = expectedGridResult(
                                platform: platform,
                                spatialEnabled: spatialEnabled,
                                headTrackingEnabled: headTrackingEnabled,
                                routeSupport: routeSupport,
                                entitlement: entitlement
                            )
                            let context = [
                                platform.rawValue,
                                "spatial=\(spatialEnabled)",
                                "head=\(headTrackingEnabled)",
                                "route=\(routeSupport.rawValue)",
                                "entitlement=\(entitlement.rawValue)"
                            ].joined(separator: " ")

                            XCTAssertEqual(
                                snapshot.presentationMode,
                                expected.mode,
                                context
                            )
                            XCTAssertEqual(
                                snapshot.fallbackReason,
                                expected.fallback,
                                context
                            )
                        }
                    }
                }
            }
        }
    }

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
        let staleGraph = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .iOS,
            graphRevision: SpatialAudioSemanticRevision(rawValue: 6)
        ))
        let staleRoute = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .iOS,
            routeRevision: SpatialAudioSemanticRevision(rawValue: 6)
        ))
        let routeLimits = [
            (current: 0, maximum: 8),
            (current: -1, maximum: 8),
            (current: 2, maximum: 0),
            (current: 2, maximum: -1),
            (current: 3, maximum: 2)
        ]

        XCTAssertEqual(staleGraph.presentationMode, .inactive)
        XCTAssertEqual(staleGraph.fallbackReason, .staleRevision)
        XCTAssertEqual(staleRoute.presentationMode, .inactive)
        XCTAssertEqual(staleRoute.fallbackReason, .staleRevision)

        for limits in routeLimits {
            let invalidRoute = SpatialAudioRuntimeResolver.resolve(makeInput(
                platform: .iOS,
                currentOutputChannelCount: limits.current,
                maximumOutputChannelCount: limits.maximum
            ))
            XCTAssertEqual(invalidRoute.presentationMode, .inactive)
            XCTAssertEqual(
                invalidRoute.fallbackReason,
                .invalidRouteSnapshot,
                "current=\(limits.current) maximum=\(limits.maximum)"
            )
        }
    }

    func testResolverRejectsUnavailableOutputBeforePolicyResolution() {
        let snapshot = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .iOS,
            userEnablesSpatialAudio: false,
            outputAvailable: false
        ))

        XCTAssertEqual(snapshot.presentationMode, .inactive)
        XCTAssertEqual(snapshot.fallbackReason, .outputUnavailable)
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

    func testResolverGraphLayoutStrategyAndReadbackGrid() {
        struct Case {
            let name: String
            let input: SpatialAudioResolutionInput
            let mode: SpatialAudioPresentationMode
            let fallback: SpatialAudioFallbackReason?
        }

        let cases = [
            Case(
                name: "layout-mismatch",
                input: makeInput(platform: .iOS, graphLayout: .wave5Point1),
                mode: .nonspatial,
                fallback: .layoutMismatch
            ),
            Case(
                name: "mono",
                input: makeInput(platform: .iOS, layout: .mono, graphLayout: .mono),
                mode: .nonspatial,
                fallback: .unsupportedLayout
            ),
            Case(
                name: "unconfigured",
                input: makeInput(platform: .iOS, graphMode: .unconfigured),
                mode: .nonspatial,
                fallback: .graphUnavailable
            ),
            Case(
                name: "mixer",
                input: makeInput(platform: .iOS, graphMode: .nonspatialMixer),
                mode: .nonspatial,
                fallback: .graphUnavailable
            ),
            Case(
                name: "algorithm",
                input: makeInput(
                    platform: .iOS,
                    hasApplicableRenderingAlgorithm: false
                ),
                mode: .nonspatial,
                fallback: .renderingAlgorithmUnavailable
            ),
            Case(
                name: "listener-strategy",
                input: makeInput(
                    platform: .iOS,
                    strategy: .visionOutputExperience
                ),
                mode: .nonspatial,
                fallback: .incompatiblePlatformStrategy
            ),
            Case(
                name: "vision-strategy",
                input: makeInput(
                    platform: .visionOS,
                    entitlement: .notRequired,
                    strategy: .environmentListener,
                    visionExperienceReadback: .headTracked
                ),
                mode: .nonspatial,
                fallback: .incompatiblePlatformStrategy
            ),
            Case(
                name: "listener-capability",
                input: makeInput(
                    platform: .macOS,
                    listenerHeadTrackingCapable: false
                ),
                mode: .fixedSpatial,
                fallback: .headTrackingNotApplied
            ),
            Case(
                name: "listener-readback",
                input: makeInput(
                    platform: .tvOS,
                    listenerHeadTrackingReadback: false
                ),
                mode: .fixedSpatial,
                fallback: .headTrackingNotApplied
            ),
            Case(
                name: "vision-head-readback",
                input: makeInput(
                    platform: .visionOS,
                    entitlement: .notRequired,
                    strategy: .visionOutputExperience,
                    visionExperienceReadback: .fixed
                ),
                mode: .fixedSpatial,
                fallback: .visionExperienceNotApplied
            ),
            Case(
                name: "vision-fixed-readback",
                input: makeInput(
                    platform: .visionOS,
                    entitlement: .notRequired,
                    strategy: .visionOutputExperience,
                    visionExperienceReadback: nil,
                    userEnablesHeadTracking: false
                ),
                mode: .nonspatial,
                fallback: .visionExperienceNotApplied
            )
        ]

        for testCase in cases {
            let snapshot = SpatialAudioRuntimeResolver.resolve(testCase.input)
            XCTAssertEqual(snapshot.presentationMode, testCase.mode, testCase.name)
            XCTAssertEqual(
                snapshot.fallbackReason,
                testCase.fallback,
                testCase.name
            )
        }
    }

    func testResolverIsDeterministicForDuplicateSemanticRevision() {
        let input = makeInput(platform: .macOS, routeSupport: .unknown)

        let first = SpatialAudioRuntimeResolver.resolve(input)
        let duplicate = SpatialAudioRuntimeResolver.resolve(input)

        XCTAssertEqual(first, duplicate)
        XCTAssertEqual(first.revision, SpatialAudioSemanticRevision(rawValue: 7))
    }

    func testRuntimeSnapshotEncodingIsClosedAndPrivacyBounded() throws {
        let snapshot = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .visionOS,
            entitlement: .notRequired,
            strategy: .visionOutputExperience,
            visionExperienceReadback: .headTracked
        ))
        let encoded = try JSONEncoder().encode(snapshot)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: encoded) as? [String: Any]
        )

        XCTAssertEqual(
            Set(object.keys),
            [
                "revision",
                "layoutSignature",
                "graphMode",
                "platformStrategy",
                "routeSupport",
                "presentationMode"
            ]
        )
        XCTAssertEqual(
            Set(try XCTUnwrap(object["layoutSignature"] as? [String: Any]).keys),
            [
                "identifier",
                "channelCount",
                "moonlightChannelMask",
                "coreAudioLayoutTagRawValue"
            ]
        )

        let json = try XCTUnwrap(String(data: encoded, encoding: .utf8))
        for forbidden in [
            "routeName",
            "routeUID",
            "host",
            "application",
            "entitlementValue",
            "notification",
            "payload",
            "samples",
            "errorDescription"
        ] {
            XCTAssertFalse(json.contains(forbidden), forbidden)
        }
        XCTAssertLessThanOrEqual(encoded.count, 512)
        for mode in SpatialAudioPresentationMode.allCases {
            XCTAssertLessThanOrEqual(
                "spatial_audio_\(mode.rawValue)".utf8.count,
                96
            )
            for fallback in SpatialAudioFallbackReason.allCases {
                XCTAssertLessThanOrEqual(
                    "spatial_audio_\(mode.rawValue)_\(fallback.rawValue)"
                        .utf8.count,
                    96
                )
            }
        }
    }

    func testRuntimeHistoryDeduplicatesAndRejectsConflictingOrStaleRevisions()
        throws
    {
        let first = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .iOS,
            revision: SpatialAudioSemanticRevision(rawValue: 7)
        ))
        let conflicting = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .iOS,
            userEnablesHeadTracking: false,
            revision: SpatialAudioSemanticRevision(rawValue: 7)
        ))
        let stale = SpatialAudioRuntimeResolver.resolve(makeInput(
            platform: .iOS,
            revision: SpatialAudioSemanticRevision(rawValue: 6)
        ))
        var history = try SpatialAudioRuntimeHistory(capacity: 4)

        XCTAssertTrue(try history.append(first))
        XCTAssertFalse(try history.append(first))
        XCTAssertEqual(history.snapshots, [first])
        XCTAssertThrowsError(try history.append(conflicting)) { error in
            XCTAssertEqual(
                error as? SpatialAudioRuntimeHistoryError,
                .conflictingRevision(first.revision)
            )
        }
        XCTAssertThrowsError(try history.append(stale)) { error in
            XCTAssertEqual(
                error as? SpatialAudioRuntimeHistoryError,
                .staleRevision(latest: first.revision, incoming: stale.revision)
            )
        }
        XCTAssertEqual(history.snapshots, [first])
    }

    func testRuntimeHistoryHasStrictFiniteCapacity() throws {
        for invalidCapacity in [
            Int.min,
            -1,
            0,
            SpatialAudioRuntimeHistory.maximumCapacity + 1,
            Int.max
        ] {
            XCTAssertThrowsError(
                try SpatialAudioRuntimeHistory(capacity: invalidCapacity)
            ) { error in
                XCTAssertEqual(
                    error as? SpatialAudioRuntimeHistoryError,
                    .invalidCapacity(invalidCapacity)
                )
            }
        }

        var history = try SpatialAudioRuntimeHistory(capacity: 4)
        for revision in 1...65 {
            let snapshot = SpatialAudioRuntimeResolver.resolve(makeInput(
                platform: .iOS,
                revision: SpatialAudioSemanticRevision(rawValue: UInt64(revision))
            ))
            XCTAssertTrue(try history.append(snapshot))
            XCTAssertLessThanOrEqual(history.snapshots.count, history.capacity)
        }

        XCTAssertEqual(history.snapshots.map(\.revision.rawValue), [62, 63, 64, 65])
    }

    private func expectedGridResult(
        platform: SpatialAudioPlatform,
        spatialEnabled: Bool,
        headTrackingEnabled: Bool,
        routeSupport: SpatialAudioRouteSupport,
        entitlement: SpatialAudioEntitlementState
    ) -> (
        mode: SpatialAudioPresentationMode,
        fallback: SpatialAudioFallbackReason?
    ) {
        guard spatialEnabled else {
            return (.nonspatial, .userDisabled)
        }

        let routeAllowsSpatial: Bool
        switch platform {
        case .macOS:
            routeAllowsSpatial = routeSupport != .unsupported
        case .iOS, .tvOS, .visionOS:
            routeAllowsSpatial = routeSupport == .supported
        }
        guard routeAllowsSpatial else {
            return (.nonspatial, .routeUnsupported)
        }
        guard headTrackingEnabled else {
            return (.fixedSpatial, nil)
        }
        guard platform != .visionOS else {
            return (.headTracked, nil)
        }

        switch entitlement {
        case .granted:
            return (.headTracked, nil)
        case .notRequired, .missing:
            return (.fixedSpatial, .missingEntitlement)
        case .unreadable:
            return (.fixedSpatial, .unreadableEntitlement)
        }
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
        routeRevision: SpatialAudioSemanticRevision? = nil,
        outputAvailable: Bool = true,
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
                revision: routeRevision ?? revision,
                outputAvailable: outputAvailable,
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

private func assertSendable<T: Sendable>(_ type: T.Type) {
    _ = type
}
