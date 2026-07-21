import Foundation
import Observation

@Observable
final class DiagnosticsStore {
    private let capacity: Int
    private(set) var events: [DiagnosticEvent] = []

    init(capacity: Int = 500) {
        self.capacity = max(1, capacity)
    }

    var latestSummary: String {
        events.last?.message ?? "Native renderer ready"
    }

    var latestActionableEvent: DiagnosticEvent? {
        events.last { $0.action != nil || $0.severity == .error }
    }

    func record(
        _ message: String,
        subsystem: String = "app",
        severity: RuntimeDiagnosticSeverity = .info,
        code: String = "event"
    ) {
        append(DiagnosticEvent(
            category: .infer(from: subsystem),
            severity: severity,
            code: code,
            subsystem: subsystem,
            message: message,
            action: nil,
            date: Date()
        ))
    }

    func record(_ diagnostic: ApplicationDiagnostic, date: Date = Date()) {
        append(DiagnosticEvent(
            category: diagnostic.category,
            severity: diagnostic.severity,
            code: diagnostic.code,
            subsystem: diagnostic.subsystem,
            message: diagnostic.summary,
            action: diagnostic.action,
            date: date
        ))
    }

    func record(inputDiagnostic: InputDiagnosticRecord) {
        append(DiagnosticEvent(
            category: .input,
            severity: .info,
            code: "input_event",
            subsystem: inputDiagnostic.subsystem,
            message: inputDiagnostic.message,
            action: nil,
            date: inputDiagnostic.createdAt
        ))
    }

    func record(audioSnapshot: AudioPipelineSnapshot) {
        let route = audioSnapshot.route
        let routeStatus = route == nil ? "route unavailable" : "output available"
        let sampleRate = Int(route?.sampleRate ?? audioSnapshot.configuration?.sampleRate ?? 0)
        let channels = route?.outputChannelCount ?? audioSnapshot.configuration?.channelCount ?? 0
        append(DiagnosticEvent(
            category: .audio,
            severity: audioSnapshot.stage == .failed ? .error : .info,
            code: "audio_\(audioSnapshot.stage.rawValue)",
            subsystem: "audio",
            message: "Audio \(audioSnapshot.stage.rawValue): \(sampleRate) Hz, \(channels) ch, \(routeStatus)",
            action: audioSnapshot.stage == .failed ? .checkAudioOutput : nil,
            date: audioSnapshot.updatedAt
        ))
    }

    func record(spatialAudioState: AudioRouteState, date: Date = Date()) {
        let status = spatialAudioState.headTrackingEnabled ? "enabled" : "disabled"
        let reason = spatialAudioState.unavailableReason.map { "; \($0)" } ?? ""
        append(DiagnosticEvent(
            category: .audio,
            severity: spatialAudioState.unavailableReason == nil ? .info : .warning,
            code: "spatial_audio_state",
            subsystem: "audio.spatial",
            message: "Spatial audio \(spatialAudioState.spatialAudioAvailable ? "available" : "unavailable"), head tracking \(status)\(reason)",
            action: nil,
            date: date
        ))
    }

    func record(runtimeEvent: RuntimeDiagnosticEvent) {
        let duration = runtimeEvent.elapsedMilliseconds.map { String(format: " %.2f ms", $0) } ?? ""
        let fieldSummary = runtimeEvent.fields.isEmpty
            ? ""
            : " " + runtimeEvent.fields
                .sorted(by: { $0.key < $1.key })
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
        append(DiagnosticEvent(
            category: .infer(from: runtimeEvent.subsystem),
            severity: runtimeEvent.severity,
            code: runtimeEvent.code,
            subsystem: runtimeEvent.subsystem,
            message: "\(runtimeEvent.stage).\(runtimeEvent.code)\(duration)\(fieldSummary)",
            action: nil,
            date: runtimeEvent.recordedAt
        ))
    }

    private func append(_ event: DiagnosticEvent) {
        var sanitizedEvent = event
        sanitizedEvent.message = RuntimeDiagnosticRedactor.redact(RuntimeDiagnosticField(
            "message",
            .string(event.message)
        ))
        events.append(sanitizedEvent)
        if events.count > capacity {
            events.removeFirst(events.count - capacity)
        }
    }
}

struct DiagnosticEvent: Identifiable, Hashable {
    let id = UUID()
    var category: ApplicationDiagnosticCategory
    var severity: RuntimeDiagnosticSeverity
    var code: String
    var subsystem: String
    var message: String
    var action: ApplicationDiagnosticAction?
    var date: Date
}
