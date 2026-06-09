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
}

struct DiagnosticEvent: Identifiable, Hashable {
    let id = UUID()
    var subsystem: String
    var message: String
    var date: Date
}
