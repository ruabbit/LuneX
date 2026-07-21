import Foundation

enum RuntimeDiagnosticSeverity: String, Codable, Equatable, Hashable, Sendable {
    case debug
    case info
    case warning
    case error
}

enum RuntimeDiagnosticPrivacy: String, Codable, Equatable, Sendable {
    case `public`
    case `private`
    case secret
}

enum RuntimeDiagnosticValue: Equatable, Sendable {
    case string(String)
    case integer(Int)
    case decimal(Double)
    case boolean(Bool)

    var rendered: String {
        switch self {
        case let .string(value):
            return value
        case let .integer(value):
            return String(value)
        case let .decimal(value):
            return String(value)
        case let .boolean(value):
            return String(value)
        }
    }
}

struct RuntimeDiagnosticField: Equatable, Sendable {
    var name: String
    var value: RuntimeDiagnosticValue
    var privacy: RuntimeDiagnosticPrivacy

    init(
        _ name: String,
        _ value: RuntimeDiagnosticValue,
        privacy: RuntimeDiagnosticPrivacy = .public
    ) {
        self.name = name
        self.value = value
        self.privacy = privacy
    }
}

struct RuntimeDiagnosticEvent: Identifiable, Equatable, Sendable {
    var id: UUID
    var sessionID: UUID?
    var subsystem: String
    var stage: String
    var severity: RuntimeDiagnosticSeverity
    var code: String
    var fields: [String: String]
    var elapsedMilliseconds: Double?
    var recordedAt: Date
}

struct RuntimeStageToken: Equatable, Sendable {
    var id: UUID
    var sessionID: UUID?
    var subsystem: String
    var stage: String
    var startedAtNanoseconds: UInt64
}

enum RuntimeDiagnosticRedactor {
    private static let secretNames: Set<String> = [
        "authorization",
        "clientsecret",
        "password",
        "pin",
        "privatekey",
        "privatekeyder",
        "remotekey",
        "remoteinputkey",
        "rikey",
        "token"
    ]
    private static let privateNames: Set<String> = [
        "address",
        "endpoint",
        "host",
        "hostname",
        "serveraddress",
        "servername",
        "url"
    ]
    private static let embeddedSecret = try! NSRegularExpression(
        pattern: #"(?i)(-----BEGIN (?:RSA |EC )?PRIVATE KEY-----|\b(?:authorization|password|pin|privatekey|rikey|token)\s*[:=])"#
    )

    static func redact(_ field: RuntimeDiagnosticField) -> String {
        let normalizedName = field.name
            .lowercased()
            .filter { $0.isLetter || $0.isNumber }
        if field.privacy == .secret || secretNames.contains(normalizedName) {
            return "<redacted>"
        }
        if field.privacy == .private || privateNames.contains(normalizedName) {
            return "<private>"
        }

        let rendered = field.value.rendered
        let range = NSRange(rendered.startIndex..<rendered.endIndex, in: rendered)
        if embeddedSecret.firstMatch(in: rendered, range: range) != nil {
            return "<redacted>"
        }
        return rendered
    }
}

actor RuntimeDiagnosticsRecorder {
    private let capacity: Int
    private var events: [RuntimeDiagnosticEvent] = []

    init(capacity: Int = 500) {
        self.capacity = max(1, capacity)
    }

    @discardableResult
    func record(
        sessionID: UUID?,
        subsystem: String,
        stage: String,
        severity: RuntimeDiagnosticSeverity,
        code: String,
        fields: [RuntimeDiagnosticField] = [],
        elapsedMilliseconds: Double? = nil,
        recordedAt: Date = Date()
    ) -> RuntimeDiagnosticEvent {
        var redactedFields: [String: String] = [:]
        for field in fields {
            redactedFields[field.name] = RuntimeDiagnosticRedactor.redact(field)
        }
        let event = RuntimeDiagnosticEvent(
            id: UUID(),
            sessionID: sessionID,
            subsystem: subsystem,
            stage: stage,
            severity: severity,
            code: code,
            fields: redactedFields,
            elapsedMilliseconds: elapsedMilliseconds,
            recordedAt: recordedAt
        )
        events.append(event)
        if events.count > capacity {
            events.removeFirst(events.count - capacity)
        }
        return event
    }

    func beginStage(
        sessionID: UUID?,
        subsystem: String,
        stage: String,
        monotonicNanoseconds: UInt64 = DispatchTime.now().uptimeNanoseconds
    ) -> RuntimeStageToken {
        RuntimeStageToken(
            id: UUID(),
            sessionID: sessionID,
            subsystem: subsystem,
            stage: stage,
            startedAtNanoseconds: monotonicNanoseconds
        )
    }

    @discardableResult
    func endStage(
        _ token: RuntimeStageToken,
        severity: RuntimeDiagnosticSeverity = .info,
        code: String,
        fields: [RuntimeDiagnosticField] = [],
        monotonicNanoseconds: UInt64 = DispatchTime.now().uptimeNanoseconds,
        recordedAt: Date = Date()
    ) -> RuntimeDiagnosticEvent {
        let elapsedNanoseconds = monotonicNanoseconds >= token.startedAtNanoseconds
            ? monotonicNanoseconds - token.startedAtNanoseconds
            : 0
        return record(
            sessionID: token.sessionID,
            subsystem: token.subsystem,
            stage: token.stage,
            severity: severity,
            code: code,
            fields: fields,
            elapsedMilliseconds: Double(elapsedNanoseconds) / 1_000_000,
            recordedAt: recordedAt
        )
    }

    func snapshot(sessionID: UUID? = nil) -> [RuntimeDiagnosticEvent] {
        guard let sessionID else { return events }
        return events.filter { $0.sessionID == sessionID }
    }

    func reset() {
        events.removeAll(keepingCapacity: true)
    }
}
