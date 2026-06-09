import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var discoveryEnabled: Bool
    var stream: StreamPreferences
    var input: InputPreferences
    var continuity: ContinuityPreferences
    var diagnosticsEnabled: Bool

    static let defaults = AppSettings(
        discoveryEnabled: true,
        stream: .defaults,
        input: .defaults,
        continuity: .defaults,
        diagnosticsEnabled: true
    )
}

struct StreamPreferences: Codable, Equatable, Sendable {
    var width: Int
    var height: Int
    var frameRate: Int
    var bitrateKbps: Int
    var hdrEnabled: Bool
    var scaleMode: RenderScaleMode

    static let defaults = StreamPreferences(
        width: 2560,
        height: 1440,
        frameRate: 120,
        bitrateKbps: 80_000,
        hdrEnabled: true,
        scaleMode: .fit
    )
}

struct InputPreferences: Codable, Equatable, Sendable {
    var preferRelativeMouseMode: Bool
    var captureSystemShortcuts: Bool
    var showVirtualController: Bool

    static let defaults = InputPreferences(
        preferRelativeMouseMode: true,
        captureSystemShortcuts: true,
        showVirtualController: false
    )
}

protocol AppSettingsRepository: Sendable {
    func loadSettings() async throws -> AppSettings
    func saveSettings(_ settings: AppSettings) async throws
}

actor InMemoryAppSettingsRepository: AppSettingsRepository {
    private var settings: AppSettings

    init(settings: AppSettings = .defaults) {
        self.settings = settings
    }

    func loadSettings() async throws -> AppSettings {
        settings
    }

    func saveSettings(_ settings: AppSettings) async throws {
        self.settings = settings
    }
}
