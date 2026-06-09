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

    func record(audioSnapshot: AudioPipelineSnapshot) {
        let route = audioSnapshot.route
        let routeName = route?.outputNames.joined(separator: ", ") ?? "unknown route"
        let sampleRate = Int(route?.sampleRate ?? audioSnapshot.configuration?.sampleRate ?? 0)
        let channels = route?.outputChannelCount ?? audioSnapshot.configuration?.channelCount ?? 0
        events.append(DiagnosticEvent(
            subsystem: "audio",
            message: "Audio \(audioSnapshot.stage.rawValue): \(sampleRate) Hz, \(channels) ch, \(routeName)",
            date: audioSnapshot.updatedAt
        ))
    }

    func record(spatialAudioState: AudioRouteState, date: Date = Date()) {
        let status = spatialAudioState.headTrackingEnabled ? "enabled" : "disabled"
        let reason = spatialAudioState.unavailableReason.map { "; \($0)" } ?? ""
        events.append(DiagnosticEvent(
            subsystem: "audio.spatial",
            message: "Spatial audio \(spatialAudioState.spatialAudioAvailable ? "available" : "unavailable"), head tracking \(status)\(reason)",
            date: date
        ))
    }
}

struct DiagnosticEvent: Identifiable, Hashable {
    let id = UUID()
    var subsystem: String
    var message: String
    var date: Date
}
