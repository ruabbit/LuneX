import Foundation
import XCTest

@MainActor
final class SpatialAudioPresentationStatusTests: XCTestCase {
    func testActualRuntimeMapsInactiveActiveVisionRecoveryAndFailureModes() {
        let noRuntime: SessionMediaAudioRuntimeState? = nil
        XCTAssertEqual(SpatialAudioPresentationStatus(noRuntime), .inactive)
        XCTAssertEqual(
            SpatialAudioPresentationStatus(makeEvent(stage: .idle)),
            .inactive
        )
        XCTAssertEqual(
            SpatialAudioPresentationStatus(makeEvent(
                includesSpatialRuntime: false
            )),
            SpatialAudioPresentationStatus(mode: .nonspatial, fallback: nil)
        )
        XCTAssertEqual(
            SpatialAudioPresentationStatus(makeEvent(
                presentationMode: .fixedSpatial
            )),
            SpatialAudioPresentationStatus(mode: .fixedSpatial, fallback: nil)
        )
        XCTAssertEqual(
            SpatialAudioPresentationStatus(makeEvent(
                presentationMode: .headTracked
            )),
            SpatialAudioPresentationStatus(mode: .headTracked, fallback: nil)
        )
        XCTAssertEqual(
            SpatialAudioPresentationStatus(makeEvent(
                strategy: .visionOutputExperience,
                presentationMode: .fixedSpatial
            )),
            SpatialAudioPresentationStatus(mode: .visionFixed, fallback: nil)
        )
        XCTAssertEqual(
            SpatialAudioPresentationStatus(makeEvent(
                strategy: .visionOutputExperience,
                presentationMode: .headTracked
            )),
            SpatialAudioPresentationStatus(mode: .visionHeadTracked, fallback: nil)
        )
        XCTAssertEqual(
            SpatialAudioPresentationStatus(makeEvent(
                cause: .interruptionBegan,
                stage: .interrupted
            )),
            SpatialAudioPresentationStatus(mode: .recovering, fallback: nil)
        )
        XCTAssertEqual(
            SpatialAudioPresentationStatus(makeEvent(
                cause: .failed,
                stage: .failed,
                fallback: .graphUnavailable
            )),
            SpatialAudioPresentationStatus(
                mode: .failed,
                fallback: .graphUnavailable
            )
        )
    }

    func testActualModeRemainsVisibleWhenHeadTrackingFallsBack() {
        let fixed = SpatialAudioPresentationStatus(makeEvent(
            presentationMode: .fixedSpatial,
            fallback: .missingEntitlement
        ))
        let vision = SpatialAudioPresentationStatus(makeEvent(
            strategy: .visionOutputExperience,
            presentationMode: .fixedSpatial,
            fallback: .visionExperienceNotApplied
        ))
        let disabled = SpatialAudioPresentationStatus(makeEvent(
            presentationMode: .nonspatial,
            fallback: .userDisabled
        ))

        XCTAssertEqual(
            fixed,
            SpatialAudioPresentationStatus(
                mode: .fixedSpatial,
                fallback: .missingEntitlement
            )
        )
        XCTAssertEqual(localized(fixed.content.overlayLabel), "Fixed spatial")
        XCTAssertTrue(
            localized(fixed.content.detail).contains("signed entitlement")
        )
        XCTAssertEqual(
            vision,
            SpatialAudioPresentationStatus(
                mode: .visionFixed,
                fallback: .visionExperienceNotApplied
            )
        )
        XCTAssertEqual(localized(disabled.content.overlayLabel), "Spatial off")
        XCTAssertEqual(localized(disabled.content.settingsValue), "Nonspatial")
    }

    func testPresentationResourcesResolveFixedPrivacyBoundedAccessibleCopy() {
        let fallbacks: [SpatialAudioPresentationFallback] = [
            .staleRevision,
            .outputUnavailable,
            .invalidRoute,
            .layoutMismatch,
            .userDisabled,
            .unsupportedLayout,
            .graphUnavailable,
            .renderingAlgorithmUnavailable,
            .routeUnsupported,
            .missingEntitlement,
            .unreadableEntitlement,
            .incompatiblePlatformStrategy,
            .headTrackingNotApplied,
            .visionExperienceNotApplied
        ]
        let forbiddenFragments = [
            "192.0.2.44",
            "living-room-host",
            "remote-app-name",
            "route-identifier",
            "revision 42",
            "generation 9",
            "entitlement=true"
        ]

        for fallback in fallbacks {
            let content = SpatialAudioPresentationStatus(
                mode: .nonspatial,
                fallback: fallback
            ).content
            let accessibilityValue = [
                localized(content.settingsValue),
                localized(content.detail)
            ].joined(separator: ". ")
            let text = [
                localized(content.overlayLabel),
                localized(content.settingsValue),
                localized(content.detail),
                accessibilityValue
            ].joined(separator: " ")

            XCTAssertFalse(localized(content.overlayLabel).isEmpty)
            XCTAssertFalse(localized(content.settingsValue).isEmpty)
            XCTAssertFalse(localized(content.detail).isEmpty)
            XCTAssertFalse(content.systemImage.isEmpty)
            XCTAssertFalse(accessibilityValue.isEmpty)
            for fragment in forbiddenFragments {
                XCTAssertFalse(text.contains(fragment))
            }
        }
    }

    func testSettingsLayoutUsesCompactForNarrowOrAccessibilityText() {
        XCTAssertEqual(
            SpatialAudioSettingsLayout(
                horizontalSizeClassIsCompact: false,
                usesAccessibilityTextSize: false
            ),
            .wide
        )
        XCTAssertEqual(
            SpatialAudioSettingsLayout(
                horizontalSizeClassIsCompact: true,
                usesAccessibilityTextSize: false
            ),
            .compact
        )
        XCTAssertEqual(
            SpatialAudioSettingsLayout(
                horizontalSizeClassIsCompact: false,
                usesAccessibilityTextSize: true
            ),
            .compact
        )
        XCTAssertEqual(
            SpatialAudioSettingsLayout(
                horizontalSizeClassIsCompact: true,
                usesAccessibilityTextSize: true
            ),
            .compact
        )
    }

    func testRootViewUsesResponsiveLocalizedAccessibleActualState() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let rootViewURL = repositoryRoot
            .appendingPathComponent("Sources/LuneXApp/RootView.swift")
        let source = try String(contentsOf: rootViewURL, encoding: .utf8)

        XCTAssertTrue(source.contains(
            "let spatialContent = appModel.spatialAudioPresentationStatus.content"
        ))
        XCTAssertTrue(source.contains(
            "SpatialAudioPresentationStatusRow("
        ))
        XCTAssertTrue(source.contains(
            "try await appModel.updateSpatialAudioPreferences(preferences)"
        ))
        XCTAssertTrue(source.contains(
            "@Environment(\\.dynamicTypeSize) private var dynamicTypeSize"
        ))
        XCTAssertTrue(source.contains(
            "SpatialAudioSettingsLayout("
        ))
        XCTAssertTrue(source.contains(
            "ViewThatFits(in: .horizontal)"
        ))
        XCTAssertTrue(source.contains(
            "Toggle(isOn: spatialAudioEnabled)"
        ))
        XCTAssertTrue(source.contains(
            "Toggle(isOn: headTrackingEnabled)"
        ))
        XCTAssertTrue(source.contains(
            ".accessibilityLabel(\"Spatial audio presentation\")"
        ))
        XCTAssertTrue(source.contains(
            ".accessibilityLabel(\"Current spatial audio presentation\")"
        ))
        XCTAssertTrue(source.contains(
            ".accessibilityValue(spatialAudioAccessibilityValue("
        ))
        XCTAssertTrue(source.contains(
            "Text(\"\\(Text(content.settingsValue)). \\(Text(content.detail))\")"
        ))
        XCTAssertTrue(source.contains("Text(content.detail)"))
        XCTAssertTrue(source.contains(
            "Label(content.settingsValue, systemImage: content.systemImage)"
        ))
        XCTAssertFalse(source.contains("+ Text(content.detail)"))
        XCTAssertFalse(source.contains(
            "Text(verbatim: content.detail)"
        ))
        XCTAssertFalse(source.contains(
            "StatusPill(label: \"Spatial gated\""
        ))
    }

    private func localized(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }

    private func makeEvent(
        cause: SessionAudioRuntimeEventCause = .initial,
        stage: SessionAudioRuntimeStage = .running,
        strategy: SpatialAudioPlatformStrategy = .environmentListener,
        presentationMode: SpatialAudioPresentationMode = .nonspatial,
        fallback: SpatialAudioFallbackReason? = nil,
        includesSpatialRuntime: Bool = true
    ) -> SessionAudioRuntimeEvent {
        let snapshot: SpatialAudioRuntimeSnapshot? = includesSpatialRuntime
            ? SpatialAudioRuntimeSnapshot(
                revision: .init(rawValue: 1),
                layoutSignature: StreamAudioChannelLayout.stereo.signature,
                graphMode: presentationMode == .nonspatial
                    ? .nonspatialMixer
                    : .environmentAmbienceBed,
                platformStrategy: strategy,
                routeSupport: .supported,
                presentationMode: presentationMode,
                fallbackReason: fallback
            )
            : nil
        return SessionAudioRuntimeEvent(
            sessionID: UUID(),
            sequence: 1,
            graphGeneration: 1,
            cause: cause,
            stage: stage,
            spatialRuntime: snapshot,
            routeCapability: SpatialAudioRouteCapabilitySnapshot(
                revision: snapshot?.revision ?? .init(rawValue: 0),
                outputAvailable: true,
                systemSpatialSupport: .supported,
                currentOutputChannelCount: 2,
                maximumOutputChannelCount: 8
            ),
            entitlement: .granted,
            preferences: .nativeDefault,
            concealedFrameCount: 0,
            lastAction: .none
        )
    }
}
