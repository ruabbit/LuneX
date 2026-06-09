import Foundation
import Observation

@Observable
final class DiagnosticsStore {
    private(set) var events: [DiagnosticEvent] = []

    var latestSummary: String {
        events.last?.message ?? "Native renderer ready"
    }

    func record(_ message: String, subsystem: String = "app") {
        events.append(DiagnosticEvent(subsystem: subsystem, message: message, date: Date()))
    }

    func record(inputDiagnostic: InputDiagnosticRecord) {
        events.append(DiagnosticEvent(
            subsystem: inputDiagnostic.subsystem,
            message: inputDiagnostic.message,
            date: inputDiagnostic.createdAt
        ))
    }
}

struct DiagnosticEvent: Identifiable, Hashable {
    let id = UUID()
    var subsystem: String
    var message: String
    var date: Date
}
