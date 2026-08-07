import Foundation
import Observation

struct TVVisionPlatformDiagnosticLease: Hashable, Sendable {
    fileprivate let id: UUID
}

enum TVVisionPlatformDiagnosticRecordOutcome: Equatable, Sendable {
    case recorded
    case deduplicated
    case staleOwner
    case staleRevision
    case conflictingRevision
}

enum TVVisionPlatformDiagnosticState: Equatable, Sendable {
    case active
    case sceneClosed
    case displayDirectEDR
    case displayFallback(TVOSDisplayHDRFallbackReason)
    case replaced
    case stopped(TVVisionPlatformPresentationStopReason)
    case failed(TVVisionPlatformPresentationFailure)
}

struct TVVisionPlatformDiagnosticValue: Equatable, Sendable {
    let platform: TVVisionPlatform
    let sourceRevision: UInt64
    let state: TVVisionPlatformDiagnosticState

    init(
        platform: TVVisionPlatform,
        sourceRevision: UInt64,
        state: TVVisionPlatformDiagnosticState
    ) {
        self.platform = platform
        self.sourceRevision = sourceRevision
        self.state = state
    }

    init(snapshot: TVVisionPlatformPresentationCoordinatorSnapshot) {
        platform = snapshot.ownership.platform
        sourceRevision = snapshot.sequence
        switch snapshot.phase {
        case let .stopped(reason):
            state = .stopped(reason)
        case let .failed(failure):
            state = .failed(failure)
        case .active:
            switch snapshot.diagnostics.last?.classification {
            case .activated, .none:
                state = .active
            case .sceneClosed:
                state = .sceneClosed
            case .displayDirectEDR:
                state = .displayDirectEDR
            case let .displayFallback(reason):
                state = .displayFallback(reason)
            case .replaced:
                state = .replaced
            case let .stopped(reason):
                state = .stopped(reason)
            case let .failed(failure):
                state = .failed(failure)
            }
        }
    }

    fileprivate var diagnostic: ApplicationDiagnostic {
        let platformCode = platform == .tvOS ? "tvos" : "visionos"
        let platformName = platform == .tvOS ? "Apple TV" : "Vision Pro"
        switch state {
        case .active:
            return fixedDiagnostic(
                category: .application,
                severity: .info,
                code: "platform_\(platformCode)_active",
                summary: "\(platformName) presentation is active."
            )
        case .sceneClosed:
            return fixedDiagnostic(
                category: .transport,
                severity: .warning,
                code: "platform_\(platformCode)_scene_closed",
                summary: "\(platformName) presentation lost its current scene.",
                action: .retryStream
            )
        case .displayDirectEDR:
            return fixedDiagnostic(
                category: .hdr,
                severity: .info,
                code: "platform_\(platformCode)_display_edr",
                summary: "\(platformName) is using direct extended-range output."
            )
        case .displayFallback:
            return fixedDiagnostic(
                category: .hdr,
                severity: .warning,
                code: "platform_\(platformCode)_display_fallback",
                summary: "\(platformName) is using HDR-to-SDR fallback.",
                action: .reviewHDRSettings
            )
        case .replaced:
            return fixedDiagnostic(
                category: .application,
                severity: .info,
                code: "platform_\(platformCode)_replaced",
                summary: "\(platformName) presentation was replaced."
            )
        case let .stopped(reason):
            let isFailure = reason == .failure
            return fixedDiagnostic(
                category: isFailure ? .transport : .application,
                severity: isFailure ? .error : .info,
                code: "platform_\(platformCode)_stopped_\(reason.rawValue)",
                summary: isFailure
                    ? "\(platformName) presentation stopped after a failure."
                    : "\(platformName) presentation stopped.",
                action: isFailure ? .retryStream : nil
            )
        case let .failed(failure):
            let recovery = Self.recovery(for: failure)
            return fixedDiagnostic(
                category: recovery.category,
                severity: .error,
                code: "platform_\(platformCode)_failed_\(recovery.code)",
                summary: "\(platformName) presentation failed.",
                action: recovery.action
            )
        }
    }

    fileprivate var clearsCurrentAction: Bool {
        switch state {
        case .active, .displayDirectEDR, .replaced:
            true
        case let .stopped(reason):
            reason != .failure
        case .sceneClosed, .displayFallback, .failed:
            false
        }
    }

    private func fixedDiagnostic(
        category: ApplicationDiagnosticCategory,
        severity: RuntimeDiagnosticSeverity,
        code: String,
        summary: String,
        action: ApplicationDiagnosticAction? = nil
    ) -> ApplicationDiagnostic {
        ApplicationDiagnostic(
            category: category,
            severity: severity,
            code: code,
            summary: summary,
            action: action
        )
    }

    private static func recovery(
        for failure: TVVisionPlatformPresentationFailure
    ) -> (
        category: ApplicationDiagnosticCategory,
        code: String,
        action: ApplicationDiagnosticAction
    ) {
        switch failure {
        case let .invalidComponent(component):
            return componentRecovery(component, prefix: "invalid")
        case let .actionFailed(effect):
            return effectRecovery(effect)
        case .semanticRevisionExhausted:
            return (.transport, "semantic_revision_exhausted", .retryStream)
        case .sequenceExhausted:
            return (.transport, "sequence_exhausted", .retryStream)
        }
    }

    private static func componentRecovery(
        _ component: TVVisionPlatformPresentationComponent,
        prefix: String
    ) -> (
        category: ApplicationDiagnosticCategory,
        code: String,
        action: ApplicationDiagnosticAction
    ) {
        switch component {
        case .scene:
            return (.transport, "\(prefix)_scene", .retryStream)
        case .input:
            return (.input, "\(prefix)_input", .reconnectInput)
        case .display:
            return (.hdr, "\(prefix)_display", .reviewHDRSettings)
        case .audioRoute:
            return (.audio, "\(prefix)_audio_route", .checkAudioOutput)
        case .video:
            return (.decoder, "\(prefix)_video", .reviewStreamSettings)
        }
    }

    private static func effectRecovery(
        _ effect: TVVisionPlatformPresentationEffectKind
    ) -> (
        category: ApplicationDiagnosticCategory,
        code: String,
        action: ApplicationDiagnosticAction
    ) {
        switch effect {
        case .scene, .teardown, .snapshot:
            return (.transport, "action_\(effect.rawValue)", .retryStream)
        case .input:
            return (.input, "action_input", .reconnectInput)
        case .display:
            return (.hdr, "action_display", .reviewHDRSettings)
        case .audioRoute:
            return (.audio, "action_audio_route", .checkAudioOutput)
        case .video, .clearVideo:
            return (.decoder, "action_\(effect.rawValue)", .reviewStreamSettings)
        }
    }
}

struct DiagnosticExportRecord: Equatable, Sendable {
    let timestamp: String
    let category: String
    let severity: String
    let code: String
    let subsystem: String
    let message: String
    let action: String?
}

@Observable
final class DiagnosticsStore {
    private static let streamCategories: Set<ApplicationDiagnosticCategory> = [
        .transport,
        .decoder,
        .hdr,
        .audio,
        .input
    ]

    private let capacity: Int
    private(set) var events: [DiagnosticEvent] = []
    private var currentActionableEvents: [ApplicationDiagnosticCategory: DiagnosticEvent] = [:]
    @ObservationIgnored private var currentActionableOwnership:
        [ApplicationDiagnosticCategory: TVVisionPlatformDiagnosticLease] = [:]
    @ObservationIgnored private var currentPlatformDiagnosticLease:
        TVVisionPlatformDiagnosticLease?
    @ObservationIgnored private var latestPlatformSourceRevision: UInt64?
    @ObservationIgnored private var latestPlatformSemanticValue:
        TVVisionPlatformDiagnosticValue?

    init(capacity: Int = 500) {
        self.capacity = max(1, capacity)
    }

    var latestSummary: String {
        events.last?.message ?? "Native renderer ready"
    }

    var latestActionableEvent: DiagnosticEvent? {
        currentActionableEvents.values.max { $0.date < $1.date }
    }

    var latestStreamActionableEvent: DiagnosticEvent? {
        currentActionableEvents.values
            .filter { Self.streamCategories.contains($0.category) }
            .max { $0.date < $1.date }
    }

    var exportRecords: [DiagnosticExportRecord] {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return events.map { event in
            DiagnosticExportRecord(
                timestamp: formatter.string(from: event.date),
                category: DiagnosticExportRedactor.redact(event.category.rawValue),
                severity: DiagnosticExportRedactor.redact(event.severity.rawValue),
                code: DiagnosticExportRedactor.redact(event.code),
                subsystem: DiagnosticExportRedactor.redact(event.subsystem),
                message: DiagnosticExportRedactor.redact(event.message),
                action: event.action.map { action in
                    DiagnosticExportRedactor.redact(action.label)
                }
            )
        }
    }

    var exportText: String {
        let rows = exportRecords.map { record in
            [
                record.timestamp,
                record.severity,
                record.category,
                record.code,
                record.subsystem,
                record.message,
                record.action ?? ""
            ].joined(separator: "\t")
        }
        return ([
            "LuneX Diagnostics",
            "timestamp\tseverity\tcategory\tcode\tsubsystem\tmessage\taction"
        ] + rows).joined(separator: "\n")
    }

    func currentActionableEvent(
        in category: ApplicationDiagnosticCategory
    ) -> DiagnosticEvent? {
        currentActionableEvents[category]
    }

    func clearActionableEvents(in categories: Set<ApplicationDiagnosticCategory>) {
        for category in categories {
            currentActionableEvents[category] = nil
            currentActionableOwnership[category] = nil
        }
    }

    func clearStreamActionableEvents() {
        clearActionableEvents(in: Self.streamCategories)
    }

    func clearAllActionableEvents() {
        currentActionableEvents.removeAll()
        currentActionableOwnership.removeAll()
    }

    @discardableResult
    func beginTVVisionPlatformDiagnosticOwnership() -> TVVisionPlatformDiagnosticLease {
        if let currentPlatformDiagnosticLease {
            clearPlatformAction(ownedBy: currentPlatformDiagnosticLease)
        }
        let lease = TVVisionPlatformDiagnosticLease(id: UUID())
        currentPlatformDiagnosticLease = lease
        latestPlatformSourceRevision = nil
        latestPlatformSemanticValue = nil
        return lease
    }

    func endTVVisionPlatformDiagnosticOwnership(
        _ lease: TVVisionPlatformDiagnosticLease
    ) {
        guard currentPlatformDiagnosticLease == lease else { return }
        clearPlatformAction(ownedBy: lease)
        currentPlatformDiagnosticLease = nil
        latestPlatformSourceRevision = nil
        latestPlatformSemanticValue = nil
    }

    @discardableResult
    func record(
        tvVisionPlatform value: TVVisionPlatformDiagnosticValue,
        owner lease: TVVisionPlatformDiagnosticLease,
        date: Date = Date()
    ) -> TVVisionPlatformDiagnosticRecordOutcome {
        guard currentPlatformDiagnosticLease == lease else {
            return .staleOwner
        }
        if let currentRevision = latestPlatformSourceRevision {
            if value.sourceRevision < currentRevision { return .staleRevision }
            if value.sourceRevision == currentRevision {
                return latestPlatformSemanticValue == value
                    ? .deduplicated
                    : .conflictingRevision
            }
            if latestPlatformSemanticValue.map({
                $0.platform == value.platform && $0.state == value.state
            }) == true {
                latestPlatformSourceRevision = value.sourceRevision
                latestPlatformSemanticValue = value
                return .deduplicated
            }
        }

        latestPlatformSourceRevision = value.sourceRevision
        latestPlatformSemanticValue = value
        if value.clearsCurrentAction {
            clearPlatformAction(ownedBy: lease)
        }
        append(value.diagnosticEvent(date: date), platformOwner: lease)
        return .recorded
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

    private func append(
        _ event: DiagnosticEvent,
        platformOwner: TVVisionPlatformDiagnosticLease? = nil
    ) {
        var sanitizedEvent = event
        sanitizedEvent.message = RuntimeDiagnosticRedactor.redact(RuntimeDiagnosticField(
            "message",
            .string(event.message)
        ))
        events.append(sanitizedEvent)
        if sanitizedEvent.action != nil || sanitizedEvent.severity == .error {
            let current = currentActionableEvents[sanitizedEvent.category]
            if current?.hasSameActionOwnership(as: sanitizedEvent) != true {
                currentActionableEvents[sanitizedEvent.category] = sanitizedEvent
                currentActionableOwnership[sanitizedEvent.category] = platformOwner
            } else if platformOwner == nil {
                currentActionableOwnership[sanitizedEvent.category] = nil
            }
        }
        if events.count > capacity {
            events.removeFirst(events.count - capacity)
        }
    }

    private func clearPlatformAction(ownedBy lease: TVVisionPlatformDiagnosticLease) {
        let categories = currentActionableOwnership.compactMap { category, owner in
            owner == lease ? category : nil
        }
        for category in categories {
            currentActionableEvents[category] = nil
            currentActionableOwnership[category] = nil
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

    fileprivate func hasSameActionOwnership(as other: DiagnosticEvent) -> Bool {
        category == other.category
            && severity == other.severity
            && code == other.code
            && subsystem == other.subsystem
            && message == other.message
            && action == other.action
    }
}

private extension TVVisionPlatformDiagnosticValue {
    func diagnosticEvent(date: Date) -> DiagnosticEvent {
        let diagnostic = diagnostic
        return DiagnosticEvent(
            category: diagnostic.category,
            severity: diagnostic.severity,
            code: diagnostic.code,
            subsystem: diagnostic.subsystem,
            message: diagnostic.summary,
            action: diagnostic.action,
            date: date
        )
    }
}

private enum DiagnosticExportRedactor {
    private static let uuid = try! NSRegularExpression(
        pattern: #"(?i)\b[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\b"#
    )
    private static let networkLocation = try! NSRegularExpression(
        pattern: #"(?i)\b(?:(?:https?|rtspu?)://[^\s]+|(?:\d{1,3}\.){3}\d{1,3}(?::\d+)?)"#
    )
    private static let privateAssignment = try! NSRegularExpression(
        pattern: #"(?i)\b(host(?:name)?|address|endpoint|url|session(?:id)?|generation|revision|frame(?:id)?|controller(?:id|lease)?|display(?:id)?|route(?:id)?)\s*[:=]\s*(?:\"[^\"]*\"|'[^']*'|[^\s,;]+)"#
    )

    static func redact(_ value: String) -> String {
        var result = RuntimeDiagnosticRedactor.redact(RuntimeDiagnosticField(
            "export",
            .string(value)
        ))
        result = replace(uuid, in: result, with: "<private>")
        result = replace(networkLocation, in: result, with: "<private>")
        result = replace(privateAssignment, in: result, with: "$1=<private>")
        return result
            .replacingOccurrences(of: "\t", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func replace(
        _ expression: NSRegularExpression,
        in value: String,
        with template: String
    ) -> String {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.stringByReplacingMatches(
            in: value,
            range: range,
            withTemplate: template
        )
    }
}
