import Foundation
import XCTest

@MainActor
final class TVVisionPlatformSettingsPresentationStateTests: XCTestCase {
    func testTVSettingsKeepDesiredAndActualStateDistinct() {
        var settings = AppSettings.defaults
        settings.stream.scaleMode = .fill
        settings.stream.hdrEnabled = true
        settings.audio = AudioPreferences(
            spatialAudioEnabled: true,
            headTrackingEnabled: true
        )

        let state = resolve(
            platform: .tvOS,
            settings: settings,
            tvActualState: tvActualState()
        )

        XCTAssertEqual(state.platform, .tvOS)
        XCTAssertEqual(state.content(for: .input).desiredValue, "Automatic eligible remote capture")
        XCTAssertEqual(state.content(for: .input).actualValue, "Remote")
        XCTAssertEqual(state.content(for: .controllers).actualValue, "2 connected, 1 routed")
        XCTAssertEqual(state.content(for: .render).desiredValue, "Fill")
        XCTAssertEqual(state.content(for: .render).actualValue, "Presenting")
        XCTAssertEqual(state.content(for: .hdr).desiredValue, "On")
        XCTAssertEqual(state.content(for: .hdr).actualValue, "SDR fallback")
        XCTAssertEqual(state.content(for: .spatial).desiredValue, "Head tracked when available")
        XCTAssertEqual(state.content(for: .spatial).actualValue, "6 ch head tracked")
    }

    func testVisionSettingsKeepDesiredAndActualStateDistinct() {
        var settings = AppSettings.defaults
        settings.stream.scaleMode = .fit
        settings.stream.hdrEnabled = false
        settings.audio = AudioPreferences(
            spatialAudioEnabled: true,
            headTrackingEnabled: false
        )

        let state = resolve(
            platform: .visionOS,
            settings: settings,
            visionActualState: visionActualState()
        )

        XCTAssertEqual(state.platform, .visionOS)
        XCTAssertEqual(state.content(for: .input).desiredValue, "Automatic supported hardware input")
        XCTAssertEqual(state.content(for: .input).actualValue, "Captured")
        XCTAssertEqual(state.content(for: .controllers).actualValue, "1 connected, 1 routed")
        XCTAssertEqual(state.content(for: .render).desiredValue, "Fit")
        XCTAssertEqual(state.content(for: .render).actualValue, "Presenting")
        XCTAssertEqual(state.content(for: .hdr).desiredValue, "Off")
        XCTAssertEqual(state.content(for: .hdr).actualValue, "SDR fallback")
        XCTAssertEqual(state.content(for: .spatial).desiredValue, "Fixed spatial when available")
        XCTAssertEqual(state.content(for: .spatial).actualValue, "6 ch fixed")
    }

    func testDisabledSpatialPreferenceDoesNotClaimActualPlaybackChanged() {
        var settings = AppSettings.defaults
        settings.audio = AudioPreferences(
            spatialAudioEnabled: false,
            headTrackingEnabled: true
        )

        let state = resolve(
            platform: .visionOS,
            settings: settings,
            visionActualState: visionActualState()
        )
        let content = state.content(for: .spatial)

        XCTAssertEqual(content.desiredValue, "Off")
        XCTAssertEqual(content.actualValue, "6 ch fixed")
        XCTAssertTrue(content.accessibilityValue.contains("Desired: Off"))
        XCTAssertTrue(content.accessibilityValue.contains("Current: 6 ch fixed"))
    }

    func testInputAndControllerBehaviorAreSystemManagedNotFakeToggles() {
        let state = resolve(
            platform: .tvOS,
            tvActualState: tvActualState()
        )

        XCTAssertFalse(state.content(for: .input).isEditablePreference)
        XCTAssertFalse(state.content(for: .controllers).isEditablePreference)
        XCTAssertTrue(state.content(for: .render).isEditablePreference)
        XCTAssertTrue(state.content(for: .hdr).isEditablePreference)
        XCTAssertTrue(state.content(for: .spatial).isEditablePreference)
    }

    func testForeignOrMixedPlatformActualStateFailsClosed() {
        let foreign = resolve(
            platform: .tvOS,
            visionActualState: visionActualState()
        )
        let mixed = resolve(
            platform: .visionOS,
            tvActualState: tvActualState(),
            visionActualState: visionActualState()
        )

        for state in [foreign, mixed] {
            XCTAssertEqual(
                state.items.map(\.actualValue),
                Array(repeating: "Unavailable", count: 5)
            )
        }
    }

    func testRowsRemainOrderedAccessibleAndPrivacyBounded() {
        let state = resolve(
            platform: .visionOS,
            visionActualState: visionActualState()
        )
        let published = state.items.flatMap {
            [
                $0.title,
                $0.desiredValue,
                $0.actualValue,
                $0.detail,
                $0.accessibilityValue
            ]
        }.joined(separator: " ")

        XCTAssertEqual(
            state.items.map(\.kind),
            TVVisionPlatformSettingsItemKind.allCases
        )
        for content in state.items {
            XCTAssertFalse(content.title.isEmpty)
            XCTAssertFalse(content.desiredValue.isEmpty)
            XCTAssertFalse(content.actualValue.isEmpty)
            XCTAssertFalse(content.detail.isEmpty)
            XCTAssertFalse(content.systemImage.isEmpty)
            XCTAssertFalse(content.accessibilityValue.isEmpty)
        }
        for forbidden in [
            "host-id", "session-id", "generation-id", "revision-id",
            "controller-id", "display-id", "route-id", "frame-id"
        ] {
            XCTAssertFalse(published.contains(forbidden))
        }
    }

    func testAppModelPublishesInactiveTVAndVisionSettingsWithoutRuntime() {
        let tvModel = AppModel(
            runtimeProviders: .unavailable,
            tvVisionPlatform: .tvOS,
            clientIdentityStore: InMemoryClientIdentityStore()
        )
        let visionModel = AppModel(
            runtimeProviders: .unavailable,
            tvVisionPlatform: .visionOS,
            clientIdentityStore: InMemoryClientIdentityStore()
        )

        XCTAssertEqual(
            tvModel.tvVisionPlatformSettingsPresentationState?.platform,
            .tvOS
        )
        XCTAssertEqual(
            tvModel.tvVisionPlatformSettingsPresentationState?
                .content(for: .input).actualValue,
            "Unavailable"
        )
        XCTAssertEqual(
            visionModel.tvVisionPlatformSettingsPresentationState?.platform,
            .visionOS
        )
        XCTAssertEqual(
            visionModel.tvVisionPlatformSettingsPresentationState?
                .content(for: .render).actualValue,
            "Inactive"
        )
    }

    func testRootViewUsesPlatformSettingsWithoutUnsupportedInputToggles()
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
        let generator = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("Tools/generate_xcodeproj.rb"),
            encoding: .utf8
        )
        let settingsStart = try XCTUnwrap(rootView.range(of: "private struct SettingsView"))
        let statusEnd = try XCTUnwrap(rootView.range(
            of: "private struct HDRPresentationStatusRow"
        ))
        let settingsSource = String(rootView[settingsStart.lowerBound..<statusEnd.lowerBound])

        XCTAssertTrue(settingsSource.contains("#if os(tvOS) || os(visionOS)"))
        XCTAssertTrue(settingsSource.contains("platformSettingStatusRow(.input)"))
        XCTAssertTrue(settingsSource.contains("platformSettingStatusRow(.controllers)"))
        XCTAssertTrue(settingsSource.contains("platformSettingStatusRow(.render)"))
        XCTAssertTrue(settingsSource.contains("platformSettingStatusRow(.hdr)"))
        XCTAssertTrue(settingsSource.contains("platformSettingStatusRow(.spatial)"))
        XCTAssertTrue(settingsSource.contains("Desired behavior"))
        XCTAssertTrue(settingsSource.contains("Current state"))
        XCTAssertTrue(settingsSource.contains("accessibilityLabel(content.title)"))
        XCTAssertTrue(settingsSource.contains("accessibilityValue(content.accessibilityValue)"))
        XCTAssertFalse(settingsSource.contains("ImmersiveSpace"))
        XCTAssertFalse(settingsSource.contains("RealityView"))
        XCTAssertTrue(generator.contains("Sources/LuneXCore/TVVisionPlatformSettingsPresentationState.swift"))
        XCTAssertTrue(generator.contains("Tests/LuneXCoreTests/TVVisionPlatformSettingsPresentationStateTests.swift"))
    }

    private func resolve(
        platform: TVVisionPlatform,
        settings: AppSettings = .defaults,
        tvActualState: TVStreamControlPresentationState? = nil,
        visionActualState: VisionStreamControlPresentationState? = nil
    ) -> TVVisionPlatformSettingsPresentationState {
        TVVisionPlatformSettingsPresentationStateResolver.resolve(
            TVVisionPlatformSettingsPresentationInput(
                platform: platform,
                settings: settings,
                tvActualState: tvActualState,
                visionActualState: visionActualState
            )
        )
    }

    private func tvActualState() -> TVStreamControlPresentationState {
        TVStreamControlPresentationState(
            focus: .streamSurface,
            capture: .remote,
            controllers: .active(connected: 2, routed: 1),
            surface: .visible,
            render: .presenting,
            hdr: .sdrFallback(.insufficientHeadroom),
            audio: .spatial(channelCount: 6, mode: .headTracked),
            failure: .none
        )
    }

    private func visionActualState() -> VisionStreamControlPresentationState {
        VisionStreamControlPresentationState(
            window: .visible,
            input: .captured(capabilityCount: 3),
            controllers: .active(connected: 1, routed: 1),
            render: .presenting,
            hdr: .sdrFallback(.headroomUnavailable),
            spatial: .fixed(channelCount: 6),
            immersive: .windowedOnly(.stage18WindowedOnly),
            failure: .none
        )
    }
}
