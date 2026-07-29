import Foundation

struct AppSettings: Codable, Equatable, Sendable {
    var discoveryEnabled: Bool
    var stream: StreamPreferences
    var input: InputPreferences
    var audio: AudioPreferences
    var continuity: ContinuityPreferences
    var diagnosticsEnabled: Bool

    static let defaults = AppSettings(
        discoveryEnabled: true,
        stream: .defaults,
        input: .defaults,
        audio: .defaults,
        continuity: .defaults,
        diagnosticsEnabled: true
    )
}

extension AppSettings {
    private enum CodingKeys: String, CodingKey {
        case discoveryEnabled
        case stream
        case input
        case audio
        case continuity
        case diagnosticsEnabled
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        discoveryEnabled = try container.decode(
            Bool.self,
            forKey: .discoveryEnabled
        )
        stream = try container.decode(StreamPreferences.self, forKey: .stream)
        input = try container.decode(InputPreferences.self, forKey: .input)
        audio = try container.decodeIfPresent(
            AudioPreferences.self,
            forKey: .audio
        ) ?? .defaults
        continuity = try container.decode(
            ContinuityPreferences.self,
            forKey: .continuity
        )
        diagnosticsEnabled = try container.decode(
            Bool.self,
            forKey: .diagnosticsEnabled
        )
    }
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

struct AudioPreferences: Codable, Equatable, Sendable {
    var spatialAudioEnabled: Bool
    var headTrackingEnabled: Bool

    static let defaults = AudioPreferences(.nativeDefault)

    var sessionPreferences: SessionSpatialAudioPreferences {
        SessionSpatialAudioPreferences(
            spatialAudioEnabled: spatialAudioEnabled,
            headTrackingEnabled: headTrackingEnabled
        )
    }

    init(
        spatialAudioEnabled: Bool,
        headTrackingEnabled: Bool
    ) {
        self.spatialAudioEnabled = spatialAudioEnabled
        self.headTrackingEnabled = headTrackingEnabled
    }

    init(_ preferences: SessionSpatialAudioPreferences) {
        spatialAudioEnabled = preferences.spatialAudioEnabled
        headTrackingEnabled = preferences.headTrackingEnabled
    }
}

extension AudioPreferences {
    private enum CodingKeys: String, CodingKey {
        case spatialAudioEnabled
        case headTrackingEnabled
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        spatialAudioEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .spatialAudioEnabled
        ) ?? Self.defaults.spatialAudioEnabled
        headTrackingEnabled = try container.decodeIfPresent(
            Bool.self,
            forKey: .headTrackingEnabled
        ) ?? Self.defaults.headTrackingEnabled
    }
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
