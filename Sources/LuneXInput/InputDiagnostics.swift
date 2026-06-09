import Foundation

enum InputDiagnosticSeverity: String, Codable, Hashable, Sendable {
    case info
    case warning
    case error
}

struct InputDiagnosticRecord: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var subsystem: String
    var severity: InputDiagnosticSeverity
    var message: String
    var createdAt: Date

    init(
        id: UUID = UUID(),
        subsystem: String = "input",
        severity: InputDiagnosticSeverity,
        message: String,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.subsystem = subsystem
        self.severity = severity
        self.message = message
        self.createdAt = createdAt
    }
}

actor InputDiagnosticsRecorder {
    private(set) var records: [InputDiagnosticRecord] = []

    func record(_ output: InputAdapterOutput, subsystem: String = "input", now: Date = Date()) {
        switch output.policy {
        case .deliver:
            return
        case let .reserveLocally(reason):
            records.append(InputDiagnosticRecord(
                subsystem: subsystem,
                severity: .info,
                message: reason,
                createdAt: now
            ))
        case let .drop(reason):
            records.append(InputDiagnosticRecord(
                subsystem: subsystem,
                severity: .warning,
                message: reason,
                createdAt: now
            ))
        }
    }

    func recordUnsupportedInput(_ message: String, subsystem: String = "input", now: Date = Date()) {
        records.append(InputDiagnosticRecord(
            subsystem: subsystem,
            severity: .warning,
            message: message,
            createdAt: now
        ))
    }

    func recordControllerSnapshot(_ snapshot: GameControllerBindingSnapshot, now: Date = Date()) {
        let count = snapshot.connectedControllers.count
        records.append(InputDiagnosticRecord(
            subsystem: "input.controller",
            severity: .info,
            message: "\(count) controller\(count == 1 ? "" : "s") connected; bitmap=\(snapshot.remoteControllersBitmap)",
            createdAt: now
        ))
    }

    func snapshot() -> [InputDiagnosticRecord] {
        records
    }
}
