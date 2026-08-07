import Foundation

enum TVVisionPlatformSettingsItemKind: String, CaseIterable, Sendable {
    case input
    case controllers
    case render
    case hdr
    case spatial
}

struct TVVisionPlatformSettingsItemContent: Identifiable, Equatable, Sendable {
    let kind: TVVisionPlatformSettingsItemKind
    let title: String
    let desiredValue: String
    let actualValue: String
    let detail: String
    let systemImage: String
    let isEditablePreference: Bool
    let isFailure: Bool

    var id: TVVisionPlatformSettingsItemKind { kind }

    var accessibilityValue: String {
        "Desired: \(desiredValue). Current: \(actualValue). \(detail)"
    }
}

struct TVVisionPlatformSettingsPresentationState: Equatable, Sendable {
    let platform: TVVisionPlatform
    let items: [TVVisionPlatformSettingsItemContent]

    func content(
        for kind: TVVisionPlatformSettingsItemKind
    ) -> TVVisionPlatformSettingsItemContent {
        items.first(where: { $0.kind == kind })
            ?? TVVisionPlatformSettingsItemContent(
                kind: kind,
                title: kind.title,
                desiredValue: "Unavailable",
                actualValue: "Unavailable",
                detail: "No current platform setting state.",
                systemImage: kind.systemImage,
                isEditablePreference: kind.isEditablePreference,
                isFailure: false
            )
    }
}

struct TVVisionPlatformSettingsPresentationInput: Equatable, Sendable {
    let platform: TVVisionPlatform
    let settings: AppSettings
    let tvActualState: TVStreamControlPresentationState?
    let visionActualState: VisionStreamControlPresentationState?
}

enum TVVisionPlatformSettingsPresentationStateResolver {
    private struct ActualContent {
        let value: String
        let detail: String
        let systemImage: String
        let isFailure: Bool
    }

    static func resolve(
        _ input: TVVisionPlatformSettingsPresentationInput
    ) -> TVVisionPlatformSettingsPresentationState {
        TVVisionPlatformSettingsPresentationState(
            platform: input.platform,
            items: TVVisionPlatformSettingsItemKind.allCases.map { kind in
                content(for: kind, input: input)
            }
        )
    }

    private static func content(
        for kind: TVVisionPlatformSettingsItemKind,
        input: TVVisionPlatformSettingsPresentationInput
    ) -> TVVisionPlatformSettingsItemContent {
        let actual = actualContent(for: kind, input: input)
        return TVVisionPlatformSettingsItemContent(
            kind: kind,
            title: kind.title,
            desiredValue: desiredValue(for: kind, input: input),
            actualValue: actual.value,
            detail: actual.detail,
            systemImage: actual.systemImage,
            isEditablePreference: kind.isEditablePreference,
            isFailure: actual.isFailure
        )
    }

    private static func desiredValue(
        for kind: TVVisionPlatformSettingsItemKind,
        input: TVVisionPlatformSettingsPresentationInput
    ) -> String {
        switch kind {
        case .input:
            switch input.platform {
            case .tvOS: "Automatic eligible remote capture"
            case .visionOS: "Automatic supported hardware input"
            }
        case .controllers:
            "Automatic supported controller routing"
        case .render:
            input.settings.stream.scaleMode == .fit ? "Fit" : "Fill"
        case .hdr:
            input.settings.stream.hdrEnabled ? "On" : "Off"
        case .spatial:
            if !input.settings.audio.spatialAudioEnabled {
                "Off"
            } else if input.settings.audio.headTrackingEnabled {
                "Head tracked when available"
            } else {
                "Fixed spatial when available"
            }
        }
    }

    private static func actualContent(
        for kind: TVVisionPlatformSettingsItemKind,
        input: TVVisionPlatformSettingsPresentationInput
    ) -> ActualContent {
        switch input.platform {
        case .tvOS:
            guard let state = input.tvActualState,
                  input.visionActualState == nil else {
                return unavailableActual(for: kind)
            }
            return tvActualContent(for: kind, state: state)
        case .visionOS:
            guard let state = input.visionActualState,
                  input.tvActualState == nil else {
                return unavailableActual(for: kind)
            }
            return visionActualContent(for: kind, state: state)
        }
    }

    private static func tvActualContent(
        for kind: TVVisionPlatformSettingsItemKind,
        state: TVStreamControlPresentationState
    ) -> ActualContent {
        let row: TVStreamControlStatusContent?
        switch kind {
        case .input: row = state.rows.first { $0.kind == .capture }
        case .controllers: row = state.rows.first { $0.kind == .controllers }
        case .render: row = state.rows.first { $0.kind == .render }
        case .hdr: row = state.rows.first { $0.kind == .hdr }
        case .spatial: row = state.rows.first { $0.kind == .audio }
        }
        guard let row else { return unavailableActual(for: kind) }
        return ActualContent(
            value: row.value,
            detail: row.detail,
            systemImage: row.systemImage,
            isFailure: row.isFailure
        )
    }

    private static func visionActualContent(
        for kind: TVVisionPlatformSettingsItemKind,
        state: VisionStreamControlPresentationState
    ) -> ActualContent {
        let row: VisionStreamControlStatusContent?
        switch kind {
        case .input: row = state.rows.first { $0.kind == .input }
        case .controllers: row = state.rows.first { $0.kind == .controllers }
        case .render: row = state.rows.first { $0.kind == .render }
        case .hdr: row = state.rows.first { $0.kind == .hdr }
        case .spatial: row = state.rows.first { $0.kind == .spatial }
        }
        guard let row else { return unavailableActual(for: kind) }
        return ActualContent(
            value: row.value,
            detail: row.detail,
            systemImage: row.systemImage,
            isFailure: row.isFailure
        )
    }

    private static func unavailableActual(
        for kind: TVVisionPlatformSettingsItemKind
    ) -> ActualContent {
        ActualContent(
            value: "Unavailable",
            detail: "No current actual \(kind.detailName) state.",
            systemImage: kind.systemImage,
            isFailure: false
        )
    }
}

private extension TVVisionPlatformSettingsItemKind {
    var title: String {
        switch self {
        case .input: "Input"
        case .controllers: "Controllers"
        case .render: "Render"
        case .hdr: "HDR"
        case .spatial: "Spatial Audio"
        }
    }

    var detailName: String {
        switch self {
        case .input: "input"
        case .controllers: "controller"
        case .render: "render"
        case .hdr: "HDR"
        case .spatial: "spatial audio"
        }
    }

    var systemImage: String {
        switch self {
        case .input: "cursorarrow.motionlines"
        case .controllers: "gamecontroller"
        case .render: "rectangle.on.rectangle"
        case .hdr: "sun.max"
        case .spatial: "wave.3.right.circle"
        }
    }

    var isEditablePreference: Bool {
        switch self {
        case .input, .controllers: false
        case .render, .hdr, .spatial: true
        }
    }
}
