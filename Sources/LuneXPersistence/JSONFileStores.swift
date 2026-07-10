import Foundation

actor JSONFileHostRepository: HostRepository {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadHosts() async throws -> [MoonlightHost] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(HostLibrarySnapshot.self, from: data).hosts
    }

    func saveHosts(_ hosts: [MoonlightHost]) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let snapshot = HostLibrarySnapshot(hosts: hosts, updatedAt: Date())
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }
}

actor JSONFileAppSettingsRepository: AppSettingsRepository {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadSettings() async throws -> AppSettings {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .defaults
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(AppSettings.self, from: data)
    }

    func saveSettings(_ settings: AppSettings) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: [.atomic])
    }
}

actor JSONFileAppCatalogSnapshotRepository: AppCatalogSnapshotRepository {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileURL: URL) {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func loadSnapshots() async throws -> [AppListSnapshot] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([AppListSnapshot].self, from: data)
    }

    func saveSnapshots(_ snapshots: [AppListSnapshot]) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try encoder.encode(snapshots)
        try data.write(to: fileURL, options: [.atomic])
    }
}

actor JSONFileClientIdentityStore: ClientIdentityStore {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL) {
        self.fileURL = fileURL
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func loadIdentity() async throws -> ClientIdentityMaterial? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(ClientIdentityMaterial.self, from: data)
    }

    func saveIdentity(_ identity: ClientIdentityMaterial) async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        let data = try encoder.encode(identity)
        try data.write(to: fileURL, options: [.atomic])
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }

    func deleteIdentity() async throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}

enum ClientIdentityStoreFactory {
    static func makeDefault(
        debugFileURL: URL = AppStorageLocations.debugClientIdentityFile
    ) -> any ClientIdentityStore {
        #if DEBUG
        return JSONFileClientIdentityStore(fileURL: debugFileURL)
        #else
        _ = debugFileURL
        return KeychainClientIdentityStore()
        #endif
    }
}

enum AppStorageLocations {
    static var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        return base.appendingPathComponent("LuneX", isDirectory: true)
    }

    static var hostsFile: URL {
        applicationSupportDirectory.appendingPathComponent("hosts.json")
    }

    static var settingsFile: URL {
        applicationSupportDirectory.appendingPathComponent("settings.json")
    }

    static var appCatalogFile: URL {
        applicationSupportDirectory.appendingPathComponent("app_catalog.json")
    }

    static var debugClientIdentityFile: URL {
        applicationSupportDirectory.appendingPathComponent("client_identity.debug.json")
    }
}
