@preconcurrency import CoreVideo
@preconcurrency import Metal
import Foundation
import MetalKit
import QuartzCore
import XCTest

private enum LiveSunshineAcceptanceScope: Equatable {
    case disabled
    case catalog
    case desktopSession
}

private enum LiveSunshineAcceptanceConfiguration {
    static let hostID = UUID(
        uuidString: "494b1a48-cccc-5e5d-9eef-4edfcea7205e"
    )!
    static let hostName = "tanmy-white"
    static let hostAddress = "10.1.100.69"
    static let appID = "881448767"
    static let appName = "Desktop"

    static func scope(
        environment: [String: String]
    ) -> LiveSunshineAcceptanceScope {
        guard environment["LUNEX_RUN_LIVE_HOST_TEST"] == "1" else {
            return .disabled
        }
        guard environment["LUNEX_RUN_LIVE_DESKTOP_SESSION"] == "1" else {
            return .catalog
        }
        return .desktopSession
    }

}

private enum LiveSunshineAcceptanceError: Error {
    case invalidServerInfoResponse
}

private actor LiveRecordingStreamLaunchClient: StreamLaunchClient {
    private let base: any StreamLaunchClient
    private var launches = 0
    private var resumes = 0
    private var stops = 0

    init(base: any StreamLaunchClient) {
        self.base = base
    }

    func launch(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        launches += 1
        return try await base.launch(request, parameters: parameters)
    }

    func resume(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        resumes += 1
        return try await base.resume(request, parameters: parameters)
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {
        stops += 1
        try await base.stop(host: host, clientUniqueID: clientUniqueID)
    }

    func counts() -> (launches: Int, resumes: Int, stops: Int) {
        (launches, resumes, stops)
    }
}

private enum LiveSessionControlFailureCause: String, Equatable, Sendable {
    case streamNegotiation = "stream_negotiation"
    case rtspBootstrap = "rtsp_bootstrap"
    case rtspMessage = "rtsp_message"
    case rtspNegotiation = "rtsp_negotiation"
    case rtspAnnounce = "rtsp_announce"
    case controlChannel = "control_channel"
    case enetTransport = "enet_transport"
    case networkChannel = "network_channel"
    case unclassified

    static func classify(_ error: Error) -> Self? {
        if error is CancellationError {
            return nil
        }
        if let networkError = error as? NetworkChannelError {
            if case .cancelled = networkError {
                return nil
            }
            return .networkChannel
        }
        if error is StreamNegotiationFailure { return .streamNegotiation }
        if error is RTSPBootstrapError { return .rtspBootstrap }
        if error is RTSPMessageError { return .rtspMessage }
        if error is SunshineRTSPNegotiationError { return .rtspNegotiation }
        if error is SunshineRTSPAnnounceError { return .rtspAnnounce }
        if error is ControlChannelError { return .controlChannel }
        if error is ENetTransportError { return .enetTransport }
        return .unclassified
    }
}

private struct LiveSessionControlReceipt: Sendable {
    var events: [String]
    var failure: LiveSessionControlFailureCause?
}

private struct LiveAdversarialControlError: Error, CustomStringConvertible {
    var description: String {
        "secret endpoint payload certificate operation"
    }
}

private enum LiveMediaFailureStage: String, Equatable, Hashable, Sendable {
    case videoReceive = "video_receive"
    case audioReceive = "audio_receive"
}

private enum LiveMediaFailureCause: String, Equatable, Sendable {
    case networkInvalidEndpoint = "network_invalid_endpoint"
    case networkInvalidReadBounds = "network_invalid_read_bounds"
    case networkPayloadTooLarge = "network_payload_too_large"
    case networkInvalidTimeout = "network_invalid_timeout"
    case networkInvalidState = "network_invalid_state"
    case networkConnectTimedOut = "network_connect_timed_out"
    case networkSendTimedOut = "network_send_timed_out"
    case networkReceiveTimedOut = "network_receive_timed_out"
    case networkOtherTimedOut = "network_other_timed_out"
    case networkClosed = "network_closed"
    case networkPOSIXFailure = "network_posix_failure"
    case networkDNSFailure = "network_dns_failure"
    case networkTLSFailure = "network_tls_failure"
    case networkWiFiAwareFailure = "network_wifi_aware_failure"
    case networkUnknownFailure = "network_unknown_failure"
    case mediaInvalidEndpoint = "media_invalid_endpoint"
    case mediaInvalidConfiguration = "media_invalid_configuration"
    case mediaInvalidLimits = "media_invalid_limits"
    case mediaMissingAudioReservation = "media_missing_audio_reservation"
    case mediaReceiveBufferOverflow = "media_receive_buffer_overflow"
    case mediaUnexpectedTermination = "media_unexpected_termination"
    case videoPacketInvalidLimits = "video_packet_invalid_limits"
    case videoPacketDatagramTooSmall = "video_packet_datagram_too_small"
    case videoPacketDatagramTooLarge = "video_packet_datagram_too_large"
    case videoPacketUnsupportedRTPLayout = "video_packet_unsupported_rtp_layout"
    case videoPacketInvalidFECEnvelope = "video_packet_invalid_fec_envelope"
    case videoPacketInvalidFlags = "video_packet_invalid_flags"
    case videoPacketInvalidSequence = "video_packet_invalid_sequence"
    case videoPacketEmptyPayload = "video_packet_empty_payload"
    case audioPacketDatagramTooSmall = "audio_packet_datagram_too_small"
    case audioPacketDatagramTooLarge = "audio_packet_datagram_too_large"
    case audioPacketUnsupportedRTPLayout = "audio_packet_unsupported_rtp_layout"
    case audioPacketUnsupportedPayloadType = "audio_packet_unsupported_payload_type"
    case audioPacketEmptyPayload = "audio_packet_empty_payload"
    case unclassified = "unclassified"
}

private struct LiveMediaFailure: Equatable, Sendable {
    var stage: LiveMediaFailureStage
    var cause: LiveMediaFailureCause
}

private struct LiveMediaReceipt: Equatable, Sendable {
    var failures: [LiveMediaFailure]

    var summary: String {
        guard !failures.isEmpty else { return "none" }
        return failures.map { "\($0.stage.rawValue):\($0.cause.rawValue)" }
            .joined(separator: ",")
    }
}

private enum LiveMediaEndpointKind: String, Equatable, Sendable {
    case ipv4
    case ipv6
    case name
}

private struct LiveMediaActivityStageReceipt: Equatable, Sendable {
    var stage: LiveMediaFailureStage
    var endpointKind: LiveMediaEndpointKind
    var transport: RuntimeTransportKind
    var port: UInt16
    var usesCustomPing: Bool
    var connections: Int
    var pingsSent: Int
    var datagramsReceived: Int
    var eventsProduced: Int

    var summary: String {
        let pingKind = usesCustomPing ? "custom" : "legacy"
        return "\(stage.rawValue)(endpoint=\(endpointKind.rawValue)_\(transport.rawValue):\(port),ping=\(pingKind),connections=\(connections),pings=\(pingsSent),datagrams=\(datagramsReceived),events=\(eventsProduced))"
    }
}

private struct LiveMediaActivityReceipt: Equatable, Sendable {
    var stages: [LiveMediaActivityStageReceipt]

    var summary: String {
        guard !stages.isEmpty else { return "none" }
        return stages.map(\.summary).joined(separator: ";")
    }
}

private struct LiveVideoFrameLossCounts: Equatable, Sendable {
    var superseded = 0
    var assemblyTimedOut = 0
    var packetCapacityExceeded = 0
    var accessUnitTooLarge = 0
    var inconsistentFrameMetadata = 0
    var conflictingDuplicate = 0
    var invalidFrameHeader = 0
    var incompleteAtEndOfStream = 0

    var summary: String {
        "superseded=\(superseded),assemblyTimedOut=\(assemblyTimedOut),packetCapacityExceeded=\(packetCapacityExceeded),accessUnitTooLarge=\(accessUnitTooLarge),inconsistentFrameMetadata=\(inconsistentFrameMetadata),conflictingDuplicate=\(conflictingDuplicate),invalidFrameHeader=\(invalidFrameHeader),incompleteAtEndOfStream=\(incompleteAtEndOfStream)"
    }
}

private struct LiveVideoDecodePipelineReceipt: Equatable, Sendable {
    var decoderActive: Bool
    var isAwaitingIDR: Bool
    var hasOutstandingIDRRequest: Bool
    var isStopped: Bool
    var isLifecyclePaused: Bool
    var sessionCreationCount: Int
    var decoderResetCount: Int
    var formatChangeCount: Int
    var colorMetadataChangeCount: Int
    var idrRequestCount: Int
    var idrRequestFailureCount: Int
    var droppedAccessUnitCount: Int
    var decoderDroppedFrameCount: Int
    var decoderFailureCount: Int
    var teardownCount: Int
    var lifecyclePauseCount: Int
    var lifecycleResumeCount: Int

    var summary: String {
        "decoderActive=\(decoderActive),awaitingIDR=\(isAwaitingIDR),outstandingIDR=\(hasOutstandingIDRRequest),stopped=\(isStopped),lifecyclePaused=\(isLifecyclePaused),sessions=\(sessionCreationCount),resets=\(decoderResetCount),formatChanges=\(formatChangeCount),colorChanges=\(colorMetadataChangeCount),idrRequests=\(idrRequestCount),idrRequestFailures=\(idrRequestFailureCount),droppedAccessUnits=\(droppedAccessUnitCount),decoderDrops=\(decoderDroppedFrameCount),decoderFailures=\(decoderFailureCount),teardowns=\(teardownCount),lifecyclePauses=\(lifecyclePauseCount),lifecycleResumes=\(lifecycleResumeCount)"
    }
}

private struct LiveVideoProcessingReceipt: Equatable, Sendable {
    var codec: NegotiatedVideoCodec?
    var packetsReceived: Int
    var firstPacketsReceived: Int
    var lastPacketsReceived: Int
    var transportLossEvents: Int
    var accessUnitsAssembled: Int
    var frameLosses: LiveVideoFrameLossCounts
    var discardedDuplicates: Int
    var discardedParityPackets: Int
    var discardedLatePackets: Int
    var submittedFrames: Int
    var decodePipeline: LiveVideoDecodePipelineReceipt?

    var summary: String {
        let codecSummary = codec?.rawValue ?? "none"
        let pipelineSummary = decodePipeline?.summary ?? "none"
        return "codec=\(codecSummary),packets=\(packetsReceived),first=\(firstPacketsReceived),last=\(lastPacketsReceived),transportLoss=\(transportLossEvents),accessUnits=\(accessUnitsAssembled),frameLosses=[\(frameLosses.summary)],discardedDuplicate=\(discardedDuplicates),discardedParity=\(discardedParityPackets),discardedLate=\(discardedLatePackets),submitted=\(submittedFrames),decode=[\(pipelineSummary)]"
    }
}

private final class LiveVideoProcessingRecorder: @unchecked Sendable {
    private static let maximumCount = 1_000_000
    private let lock = NSLock()
    private var packetsReceived = 0
    private var firstPacketsReceived = 0
    private var lastPacketsReceived = 0
    private var transportLossEvents = 0
    private var accessUnitsAssembled = 0
    private var frameLosses = LiveVideoFrameLossCounts()
    private var discardedDuplicates = 0
    private var discardedParityPackets = 0
    private var discardedLatePackets = 0
    private var submittedFrames = 0
    private var codec: NegotiatedVideoCodec?
    private var decodePipeline: LiveVideoDecodePipelineReceipt?

    func record(codec: NegotiatedVideoCodec) {
        lock.lock()
        self.codec = codec
        lock.unlock()
    }

    func record(_ event: VideoReceiveEvent) {
        lock.lock()
        defer { lock.unlock() }
        switch event {
        case let .packet(packet):
            packetsReceived = Self.increment(packetsReceived)
            if packet.isFirstPacket {
                firstPacketsReceived = Self.increment(firstPacketsReceived)
            }
            if packet.isLastPacket {
                lastPacketsReceived = Self.increment(lastPacketsReceived)
            }
        case .packetLoss:
            transportLossEvents = Self.increment(transportLossEvents)
        case .closed:
            break
        }
    }

    func record(_ events: [VideoAccessUnitAssemblyEvent]) {
        lock.lock()
        defer { lock.unlock() }
        for event in events {
            switch event {
            case .accessUnit:
                accessUnitsAssembled = Self.increment(accessUnitsAssembled)
            case let .frameLost(loss):
                switch loss.reason {
                case .superseded:
                    frameLosses.superseded = Self.increment(frameLosses.superseded)
                case .assemblyTimedOut:
                    frameLosses.assemblyTimedOut = Self.increment(
                        frameLosses.assemblyTimedOut
                    )
                case .packetCapacityExceeded:
                    frameLosses.packetCapacityExceeded = Self.increment(
                        frameLosses.packetCapacityExceeded
                    )
                case .accessUnitTooLarge:
                    frameLosses.accessUnitTooLarge = Self.increment(
                        frameLosses.accessUnitTooLarge
                    )
                case .inconsistentFrameMetadata:
                    frameLosses.inconsistentFrameMetadata = Self.increment(
                        frameLosses.inconsistentFrameMetadata
                    )
                case .conflictingDuplicate:
                    frameLosses.conflictingDuplicate = Self.increment(
                        frameLosses.conflictingDuplicate
                    )
                case .invalidFrameHeader:
                    frameLosses.invalidFrameHeader = Self.increment(
                        frameLosses.invalidFrameHeader
                    )
                case .incompleteAtEndOfStream:
                    frameLosses.incompleteAtEndOfStream = Self.increment(
                        frameLosses.incompleteAtEndOfStream
                    )
                }
            case let .packetDiscarded(reason):
                switch reason {
                case .duplicate:
                    discardedDuplicates = Self.increment(discardedDuplicates)
                case .parity:
                    discardedParityPackets = Self.increment(discardedParityPackets)
                case .lateFrame:
                    discardedLatePackets = Self.increment(discardedLatePackets)
                }
            }
        }
    }

    func recordSubmittedFrame() {
        lock.lock()
        submittedFrames = Self.increment(submittedFrames)
        lock.unlock()
    }

    func record(_ snapshot: VideoDecodePipelineSnapshot) {
        lock.lock()
        decodePipeline = LiveVideoDecodePipelineReceipt(
            decoderActive: snapshot.activeDecoderGeneration != nil,
            isAwaitingIDR: snapshot.isAwaitingIDR,
            hasOutstandingIDRRequest: snapshot.hasOutstandingIDRRequest,
            isStopped: snapshot.isStopped,
            isLifecyclePaused: snapshot.isLifecyclePaused,
            sessionCreationCount: Self.bounded(snapshot.sessionCreationCount),
            decoderResetCount: Self.bounded(snapshot.decoderResetCount),
            formatChangeCount: Self.bounded(snapshot.formatChangeCount),
            colorMetadataChangeCount: Self.bounded(
                snapshot.colorMetadataChangeCount
            ),
            idrRequestCount: Self.bounded(snapshot.idrRequestCount),
            idrRequestFailureCount: Self.bounded(
                snapshot.idrRequestFailureCount
            ),
            droppedAccessUnitCount: Self.bounded(
                snapshot.droppedAccessUnitCount
            ),
            decoderDroppedFrameCount: Self.bounded(
                snapshot.decoderDroppedFrameCount
            ),
            decoderFailureCount: Self.bounded(snapshot.decoderFailureCount),
            teardownCount: Self.bounded(snapshot.teardownCount),
            lifecyclePauseCount: Self.bounded(snapshot.lifecyclePauseCount),
            lifecycleResumeCount: Self.bounded(snapshot.lifecycleResumeCount)
        )
        lock.unlock()
    }

    func receipt() -> LiveVideoProcessingReceipt {
        lock.lock()
        defer { lock.unlock() }
        return LiveVideoProcessingReceipt(
            codec: codec,
            packetsReceived: packetsReceived,
            firstPacketsReceived: firstPacketsReceived,
            lastPacketsReceived: lastPacketsReceived,
            transportLossEvents: transportLossEvents,
            accessUnitsAssembled: accessUnitsAssembled,
            frameLosses: frameLosses,
            discardedDuplicates: discardedDuplicates,
            discardedParityPackets: discardedParityPackets,
            discardedLatePackets: discardedLatePackets,
            submittedFrames: submittedFrames,
            decodePipeline: decodePipeline
        )
    }

    private static func increment(_ count: Int) -> Int {
        min(count + 1, maximumCount)
    }

    private static func bounded(_ count: UInt64) -> Int {
        Int(min(count, UInt64(maximumCount)))
    }
}

private struct LiveRecordingVideoProcessorFactory: SessionVideoProcessorCreating {
    let base: any SessionVideoProcessorCreating
    let recorder: LiveVideoProcessingRecorder

    func makeVideoProcessor(
        sessionID: UUID,
        mediaGeneration: UInt64,
        configuration: NegotiatedVideoStreamConfiguration,
        controlProvider: any SessionControlProvider,
        presentationEventSink: @escaping @Sendable (
            StreamVideoPresentationEvent
        ) -> Void
    ) async throws -> any SessionVideoProcessing {
        let processor = try await base.makeVideoProcessor(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            configuration: configuration,
            controlProvider: controlProvider,
            presentationEventSink: presentationEventSink
        )
        return try LiveRecordingVideoProcessor(
            base: processor,
            configuration: configuration,
            recorder: recorder
        )
    }
}

private actor LiveRecordingVideoProcessor: SessionVideoProcessing {
    private let base: any SessionVideoProcessing
    private let recorder: LiveVideoProcessingRecorder
    private var shadowAssembler: NormalizedVideoAccessUnitAssembler

    init(
        base: any SessionVideoProcessing,
        configuration: NegotiatedVideoStreamConfiguration,
        recorder: LiveVideoProcessingRecorder
    ) throws {
        self.base = base
        self.recorder = recorder
        recorder.record(codec: configuration.codec)
        shadowAssembler = try NormalizedVideoAccessUnitAssembler(
            codec: configuration.codec
        )
    }

    func consume(_ event: VideoReceiveEvent) async throws -> Bool {
        recorder.record(event)
        let assemblyEvents: [VideoAccessUnitAssemblyEvent]
        switch event {
        case let .packet(packet):
            assemblyEvents = shadowAssembler.ingest(packet)
        case .packetLoss:
            assemblyEvents = []
        case .closed:
            assemblyEvents = shadowAssembler.finish()
        }
        recorder.record(assemblyEvents)
        let submitted = try await base.consume(event)
        if submitted {
            recorder.recordSubmittedFrame()
        }
        if submitted || !assemblyEvents.isEmpty {
            await recordDecodePipelineSnapshot()
        }
        return submitted
    }

    func updateColorMetadata(_ metadata: VideoColorMetadata) async throws {
        try await base.updateColorMetadata(metadata)
        await recordDecodePipelineSnapshot()
    }

    func applyLifecycle(_ application: SessionLifecycleApplication) async throws {
        try await base.applyLifecycle(application)
        await recordDecodePipelineSnapshot()
    }

    func applyMobileVideo(
        _ application: SessionMobileVideoApplication
    ) async throws {
        try await base.applyMobileVideo(application)
    }

    func stop() async {
        shadowAssembler.reset()
        await base.stop()
    }

    private func recordDecodePipelineSnapshot() async {
        guard let provider = base as? any VideoDecodePipelineSnapshotProviding else {
            return
        }
        recorder.record(await provider.videoDecodePipelineSnapshot())
    }
}

private actor LiveVideoProcessingSpy: SessionVideoProcessing,
    VideoDecodePipelineSnapshotProviding {
    private let submissionResult: Bool
    private var events: [VideoReceiveEvent] = []
    private var stopCount = 0

    init(submissionResult: Bool) {
        self.submissionResult = submissionResult
    }

    func consume(_ event: VideoReceiveEvent) async throws -> Bool {
        events.append(event)
        return submissionResult
    }

    func updateColorMetadata(_ metadata: VideoColorMetadata) async throws {
        _ = metadata
    }

    func applyLifecycle(_ application: SessionLifecycleApplication) async throws {
        _ = application
    }

    func applyMobileVideo(
        _ application: SessionMobileVideoApplication
    ) async throws {
        _ = application
    }

    func stop() async {
        stopCount += 1
    }

    func videoDecodePipelineSnapshot() -> VideoDecodePipelineSnapshot {
        VideoDecodePipelineSnapshot(
            activeDecoderGeneration: 3,
            isAwaitingIDR: false,
            hasOutstandingIDRRequest: false,
            isStopped: false,
            isLifecyclePaused: false,
            sessionCreationCount: 1,
            decoderResetCount: 0,
            formatChangeCount: 0,
            colorMetadataChangeCount: 0,
            idrRequestCount: 1,
            idrRequestFailureCount: 0,
            droppedAccessUnitCount: 0,
            decoderDroppedFrameCount: 0,
            decoderFailureCount: 0,
            teardownCount: 0,
            lifecyclePauseCount: 0,
            lifecycleResumeCount: 0
        )
    }

    func receipt() -> (events: [VideoReceiveEvent], stopCount: Int) {
        (events, stopCount)
    }
}

private final class LiveMediaActivityRecorder: @unchecked Sendable {
    private struct StageState {
        var endpointKind: LiveMediaEndpointKind
        var transport: RuntimeTransportKind
        var port: UInt16
        var usesCustomPing: Bool
        var connections = 0
        var pingsSent = 0
        var datagramsReceived = 0
        var eventsProduced = 0
    }

    private static let maximumCount = 1_000_000
    private let lock = NSLock()
    private var states: [LiveMediaFailureStage: StageState] = [:]

    func recordConfiguration(
        stage: LiveMediaFailureStage,
        endpoint: RuntimeNetworkEndpoint,
        usesCustomPing: Bool
    ) {
        lock.lock()
        defer { lock.unlock() }
        states[stage] = StageState(
            endpointKind: Self.endpointKind(endpoint.host),
            transport: endpoint.transport,
            port: endpoint.port,
            usesCustomPing: usesCustomPing
        )
    }

    func recordConnection(stage: LiveMediaFailureStage) {
        update(stage) { $0.connections = Self.increment($0.connections) }
    }

    func recordPing(stage: LiveMediaFailureStage) {
        update(stage) { $0.pingsSent = Self.increment($0.pingsSent) }
    }

    func recordDatagram(stage: LiveMediaFailureStage) {
        update(stage) {
            $0.datagramsReceived = Self.increment($0.datagramsReceived)
        }
    }

    func recordEvent(stage: LiveMediaFailureStage) {
        update(stage) { $0.eventsProduced = Self.increment($0.eventsProduced) }
    }

    func receipt() -> LiveMediaActivityReceipt {
        lock.lock()
        defer { lock.unlock() }
        let orderedStages: [LiveMediaFailureStage] = [
            .videoReceive,
            .audioReceive,
        ]
        return LiveMediaActivityReceipt(stages: orderedStages.compactMap { stage in
            guard let state = states[stage] else { return nil }
            return LiveMediaActivityStageReceipt(
                stage: stage,
                endpointKind: state.endpointKind,
                transport: state.transport,
                port: state.port,
                usesCustomPing: state.usesCustomPing,
                connections: state.connections,
                pingsSent: state.pingsSent,
                datagramsReceived: state.datagramsReceived,
                eventsProduced: state.eventsProduced
            )
        })
    }

    private func update(
        _ stage: LiveMediaFailureStage,
        mutation: (inout StageState) -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }
        guard var state = states[stage] else { return }
        mutation(&state)
        states[stage] = state
    }

    private static func increment(_ count: Int) -> Int {
        min(count + 1, maximumCount)
    }

    private static func endpointKind(_ host: String) -> LiveMediaEndpointKind {
        if host.contains(":") { return .ipv6 }
        let components = host.split(separator: ".", omittingEmptySubsequences: false)
        if components.count == 4,
           components.allSatisfy({ component in
               guard let octet = UInt8(component) else { return false }
               return String(octet) == String(component)
           }) {
            return .ipv4
        }
        return .name
    }
}

private actor LiveMediaFailureRecorder {
    private var failures: [LiveMediaFailure] = []

    func record(stage: LiveMediaFailureStage, error: Error) {
        guard let cause = Self.boundedCause(for: error) else { return }
        failures.append(LiveMediaFailure(stage: stage, cause: cause))
    }

    func receipt() -> LiveMediaReceipt {
        LiveMediaReceipt(failures: failures)
    }

    private static func boundedCause(_ error: NetworkChannelError)
        -> LiveMediaFailureCause?
    {
        switch error {
        case .invalidEndpoint: .networkInvalidEndpoint
        case .invalidReadBounds: .networkInvalidReadBounds
        case .payloadTooLarge: .networkPayloadTooLarge
        case .invalidTimeout: .networkInvalidTimeout
        case .invalidState: .networkInvalidState
        case let .timedOut(operation): switch operation {
            case "connect": .networkConnectTimedOut
            case "send": .networkSendTimedOut
            case "receive": .networkReceiveTimedOut
            default: .networkOtherTimedOut
            }
        case .cancelled: nil
        case .closed: .networkClosed
        case .posixFailure: .networkPOSIXFailure
        case .dnsFailure: .networkDNSFailure
        case .tlsFailure: .networkTLSFailure
        case .wifiAwareFailure: .networkWiFiAwareFailure
        case .unknownTransportFailure: .networkUnknownFailure
        }
    }

    private static func boundedCause(_ error: MoonlightMediaReceiveError)
        -> LiveMediaFailureCause
    {
        switch error {
        case .invalidEndpoint: .mediaInvalidEndpoint
        case .invalidConfiguration: .mediaInvalidConfiguration
        case .invalidLimits: .mediaInvalidLimits
        case .missingAudioReservation: .mediaMissingAudioReservation
        case .receiveBufferOverflow: .mediaReceiveBufferOverflow
        case .unexpectedTermination: .mediaUnexpectedTermination
        }
    }

    private static func boundedCause(_ error: MoonlightVideoPacketError)
        -> LiveMediaFailureCause
    {
        switch error {
        case .invalidLimits: .videoPacketInvalidLimits
        case .datagramTooSmall: .videoPacketDatagramTooSmall
        case .datagramTooLarge: .videoPacketDatagramTooLarge
        case .unsupportedRTPLayout: .videoPacketUnsupportedRTPLayout
        case .invalidFECEnvelope: .videoPacketInvalidFECEnvelope
        case .invalidPacketFlags: .videoPacketInvalidFlags
        case .invalidPacketSequence: .videoPacketInvalidSequence
        case .emptyPayload: .videoPacketEmptyPayload
        }
    }

    private static func boundedCause(_ error: MoonlightAudioRTPPacketError)
        -> LiveMediaFailureCause
    {
        switch error {
        case .datagramTooSmall: .audioPacketDatagramTooSmall
        case .datagramTooLarge: .audioPacketDatagramTooLarge
        case .unsupportedRTPLayout: .audioPacketUnsupportedRTPLayout
        case .unsupportedPayloadType: .audioPacketUnsupportedPayloadType
        case .emptyPayload: .audioPacketEmptyPayload
        }
    }

    private static func boundedCause(for error: Error) -> LiveMediaFailureCause? {
        if error is CancellationError { return nil }
        if let error = error as? NetworkChannelError {
            return boundedCause(error)
        }
        if let error = error as? MoonlightMediaReceiveError {
            return boundedCause(error)
        }
        if let error = error as? MoonlightVideoPacketError {
            return boundedCause(error)
        }
        if let error = error as? MoonlightAudioRTPPacketError {
            return boundedCause(error)
        }
        return .unclassified
    }
}

private func recordingLiveMediaStream<Event: Sendable>(
    _ upstream: AsyncThrowingStream<Event, Error>,
    stage: LiveMediaFailureStage,
    recorder: LiveMediaFailureRecorder,
    activityRecorder: LiveMediaActivityRecorder?
) -> AsyncThrowingStream<Event, Error> {
    AsyncThrowingStream { continuation in
        let forwarding = Task {
            do {
                for try await event in upstream {
                    activityRecorder?.recordEvent(stage: stage)
                    if case .terminated = continuation.yield(event) {
                        break
                    }
                }
                continuation.finish()
            } catch {
                if !Task.isCancelled {
                    await recorder.record(stage: stage, error: error)
                }
                continuation.finish(throwing: error)
            }
        }
        continuation.onTermination = { @Sendable _ in
            forwarding.cancel()
        }
    }
}

private struct LiveRecordingVideoReceiveProvider: VideoReceiveProvider {
    let base: any VideoReceiveProvider
    let recorder: LiveMediaFailureRecorder
    var activityRecorder: LiveMediaActivityRecorder? = nil

    func receiveVideo(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedVideoStreamConfiguration
    ) async -> AsyncThrowingStream<VideoReceiveEvent, Error> {
        activityRecorder?.recordConfiguration(
            stage: .videoReceive,
            endpoint: endpoint,
            usesCustomPing: configuration.pingPayload != nil
        )
        let upstream = await base.receiveVideo(
            sessionID: sessionID,
            endpoint: endpoint,
            configuration: configuration
        )
        return recordingLiveMediaStream(
            upstream,
            stage: .videoReceive,
            recorder: recorder,
            activityRecorder: activityRecorder
        )
    }

    func stopVideo(sessionID: UUID) async {
        await base.stopVideo(sessionID: sessionID)
    }
}

private struct LiveRecordingAudioReceiveProvider: AudioReceiveProvider {
    let base: any AudioReceiveProvider
    let recorder: LiveMediaFailureRecorder
    var activityRecorder: LiveMediaActivityRecorder? = nil

    func receiveAudio(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedAudioStreamConfiguration
    ) async -> AsyncThrowingStream<AudioReceiveEvent, Error> {
        activityRecorder?.recordConfiguration(
            stage: .audioReceive,
            endpoint: endpoint,
            usesCustomPing: configuration.pingPayload != nil
        )
        let upstream = await base.receiveAudio(
            sessionID: sessionID,
            endpoint: endpoint,
            configuration: configuration
        )
        return recordingLiveMediaStream(
            upstream,
            stage: .audioReceive,
            recorder: recorder,
            activityRecorder: activityRecorder
        )
    }

    func stopAudio(sessionID: UUID) async {
        await base.stopAudio(sessionID: sessionID)
    }
}

private struct LiveRecordingDatagramChannel: MoonlightDatagramChannel {
    let base: any MoonlightDatagramChannel
    let stage: LiveMediaFailureStage
    let recorder: LiveMediaActivityRecorder

    func connect(timeout: Duration) async throws {
        try await base.connect(timeout: timeout)
        recorder.recordConnection(stage: stage)
    }

    func send(_ data: Data, timeout: Duration) async throws {
        try await base.send(data, timeout: timeout)
        recorder.recordPing(stage: stage)
    }

    func receiveWithoutDeadline(
        minimumLength: Int,
        maximumLength: Int?
    ) async throws -> NetworkReceiveChunk {
        let chunk = try await base.receiveWithoutDeadline(
            minimumLength: minimumLength,
            maximumLength: maximumLength
        )
        recorder.recordDatagram(stage: stage)
        return chunk
    }

    func cancel() async {
        await base.cancel()
    }
}

private func liveRecordingDatagramChannelFactory(
    stage: LiveMediaFailureStage,
    recorder: LiveMediaActivityRecorder
) -> MoonlightDatagramChannelFactory {
    { endpoint, limits in
        LiveRecordingDatagramChannel(
            base: try NetworkByteChannel(endpoint: endpoint, limits: limits),
            stage: stage,
            recorder: recorder
        )
    }
}

private actor LiveRecordingSessionControlProvider: SessionControlProvider {
    private let base: any SessionControlProvider
    private var events: [String] = []
    private var failure: LiveSessionControlFailureCause?

    init(base: any SessionControlProvider) {
        self.base = base
    }

    func start(
        sessionID: UUID,
        request: StreamLaunchRequest
    ) async -> AsyncThrowingStream<SessionControlEvent, Error> {
        let upstream = await base.start(sessionID: sessionID, request: request)
        return AsyncThrowingStream { continuation in
            let forwarding = Task {
                do {
                    for try await event in upstream {
                        self.record(event)
                        if case .terminated = continuation.yield(event) {
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    self.record(error)
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { @Sendable _ in
                forwarding.cancel()
            }
        }
    }

    func requestIDR(sessionID: UUID) async throws {
        try await base.requestIDR(sessionID: sessionID)
    }

    func applyMobileControl(
        _ application: SessionMobileControlApplication
    ) async throws {
        try await base.applyMobileControl(application)
    }

    func stop(sessionID: UUID) async {
        await base.stop(sessionID: sessionID)
    }

    func receipt() -> LiveSessionControlReceipt {
        LiveSessionControlReceipt(events: events, failure: failure)
    }

    private func record(_ event: SessionControlEvent) {
        let code = switch event {
        case .launchAccepted: "launch_accepted"
        case .rtspReady: "rtsp_ready"
        case .videoColorMetadata: "video_color_metadata"
        case .negotiated: "negotiated"
        case let .channelsReady(readiness): "channels_\(readiness.rawValue)"
        case let .reconnecting(attempt, _): "reconnecting_\(attempt)"
        case .terminated: "terminated"
        }
        events.append(code)
    }

    private func record(_ error: Error) {
        failure = LiveSessionControlFailureCause.classify(error)
    }
}

@MainActor
final class AppModelWorkflowTests: XCTestCase {
    func testLiveControlFailureReceiptIsFiniteAndPrivacyBounded() {
        let arbitrary = LiveSessionControlFailureCause.classify(
            LiveAdversarialControlError()
        )
        XCTAssertEqual(arbitrary, .unclassified)
        XCTAssertNil(
            LiveSessionControlFailureCause.classify(CancellationError())
        )
        XCTAssertNil(
            LiveSessionControlFailureCause.classify(
                NetworkChannelError.cancelled
            )
        )
        XCTAssertEqual(
            LiveSessionControlFailureCause.classify(
                NetworkChannelError.timedOut(operation: "secret operation")
            ),
            .networkChannel
        )
        let summary = arbitrary?.rawValue ?? "none"
        XCTAssertFalse(summary.contains("secret"))
        XCTAssertFalse(summary.contains("endpoint"))
        XCTAssertFalse(summary.contains("payload"))
        XCTAssertFalse(summary.contains("certificate"))
        XCTAssertFalse(summary.contains("operation"))
    }

    func testLiveSunshineAcceptanceRequiresExactOptIns() {
        XCTAssertEqual(
            LiveSunshineAcceptanceConfiguration.scope(environment: [:]),
            .disabled
        )
        XCTAssertEqual(
            LiveSunshineAcceptanceConfiguration.scope(environment: [
                "LUNEX_RUN_LIVE_DESKTOP_SESSION": "1"
            ]),
            .disabled
        )
        XCTAssertEqual(
            LiveSunshineAcceptanceConfiguration.scope(environment: [
                "LUNEX_RUN_LIVE_HOST_TEST": "true",
                "LUNEX_RUN_LIVE_DESKTOP_SESSION": "1"
            ]),
            .disabled
        )
        XCTAssertEqual(
            LiveSunshineAcceptanceConfiguration.scope(environment: [
                "LUNEX_RUN_LIVE_HOST_TEST": "1"
            ]),
            .catalog
        )
        XCTAssertEqual(
            LiveSunshineAcceptanceConfiguration.scope(environment: [
                "LUNEX_RUN_LIVE_HOST_TEST": "1",
                "LUNEX_RUN_LIVE_DESKTOP_SESSION": "true"
            ]),
            .catalog
        )
        XCTAssertEqual(
            LiveSunshineAcceptanceConfiguration.scope(environment: [
                "LUNEX_RUN_LIVE_HOST_TEST": "1",
                "LUNEX_RUN_LIVE_DESKTOP_SESSION": "1"
            ]),
            .desktopSession
        )
    }

    func testLiveMediaRecorderAttributesVideoFailureAndPreservesStream()
        async throws
    {
        let expectedEvent = VideoReceiveEvent.packetLoss(expected: 10, received: 12)
        let expectedError = NetworkChannelError.posixFailure(code: 61)
        let stops = LiveMediaTestStopRecorder()
        let recorder = LiveMediaFailureRecorder()
        let activityRecorder = LiveMediaActivityRecorder()
        let provider = LiveRecordingVideoReceiveProvider(
            base: LiveMediaTestVideoProvider(
                stops: stops,
                makeStream: {
                    AsyncThrowingStream { continuation in
                        continuation.yield(expectedEvent)
                        continuation.finish(throwing: expectedError)
                    }
                }
            ),
            recorder: recorder,
            activityRecorder: activityRecorder
        )
        let sessionID = UUID()
        let stream = await provider.receiveVideo(
            sessionID: sessionID,
            endpoint: liveMediaTestEndpoint(port: 48_000),
            configuration: liveMediaTestVideoConfiguration()
        )
        var iterator = stream.makeAsyncIterator()
        let forwardedEvent = try await iterator.next()
        XCTAssertEqual(forwardedEvent, expectedEvent)
        do {
            _ = try await iterator.next()
            XCTFail("The original video receive error was not forwarded.")
        } catch let error as NetworkChannelError {
            XCTAssertEqual(error, expectedError)
        }
        await provider.stopVideo(sessionID: sessionID)
        let stoppedSessionIDs = await stops.videoSessionIDs()
        XCTAssertEqual(stoppedSessionIDs, [sessionID])
        let receipt = await recorder.receipt()
        XCTAssertEqual(
            receipt,
            LiveMediaReceipt(failures: [LiveMediaFailure(
                stage: .videoReceive,
                cause: .networkPOSIXFailure
            )])
        )
        XCTAssertEqual(receipt.summary, "video_receive:network_posix_failure")
        XCTAssertFalse(receipt.summary.contains("61"))
        let activity = activityRecorder.receipt()
        XCTAssertEqual(
            activity,
            LiveMediaActivityReceipt(stages: [
                LiveMediaActivityStageReceipt(
                    stage: .videoReceive,
                    endpointKind: .name,
                    transport: .udp,
                    port: 48_000,
                    usesCustomPing: false,
                    connections: 0,
                    pingsSent: 0,
                    datagramsReceived: 0,
                    eventsProduced: 1
                )
            ])
        )
    }

    func testLiveMediaRecorderAttributesAudioParserFailureAndPreservesError()
        async
    {
        let expectedError = MoonlightAudioRTPPacketError.unsupportedPayloadType(42)
        let recorder = LiveMediaFailureRecorder()
        let provider = LiveRecordingAudioReceiveProvider(
            base: LiveMediaTestAudioProvider(
                stops: LiveMediaTestStopRecorder(),
                makeStream: {
                    AsyncThrowingStream { continuation in
                        continuation.finish(throwing: expectedError)
                    }
                }
            ),
            recorder: recorder
        )
        let stream = await provider.receiveAudio(
            sessionID: UUID(),
            endpoint: liveMediaTestEndpoint(port: 48_010),
            configuration: liveMediaTestAudioConfiguration()
        )
        do {
            for try await _ in stream {}
            XCTFail("The original audio receive error was not forwarded.")
        } catch let error as MoonlightAudioRTPPacketError {
            XCTAssertEqual(error, expectedError)
        } catch {
            XCTFail("Unexpected audio error type.")
        }
        let receipt = await recorder.receipt()
        XCTAssertEqual(
            receipt.failures,
            [LiveMediaFailure(
                stage: .audioReceive,
                cause: .audioPacketUnsupportedPayloadType
            )]
        )
        XCTAssertFalse(receipt.summary.contains("42"))
    }

    func testLiveMediaRecorderBoundsUnknownTextAndSuppressesCancellation()
        async
    {
        let recorder = LiveMediaFailureRecorder()
        await recorder.record(
            stage: .videoReceive,
            error: LiveMediaPrivateTestError.failure(
                "secret.example:47998 certificate payload"
            )
        )
        await recorder.record(stage: .audioReceive, error: CancellationError())
        await recorder.record(
            stage: .audioReceive,
            error: NetworkChannelError.cancelled
        )
        await recorder.record(
            stage: .audioReceive,
            error: NetworkChannelError.timedOut(
                operation: "secret endpoint operation"
            )
        )
        await recorder.record(
            stage: .videoReceive,
            error: NetworkChannelError.timedOut(operation: "connect")
        )
        await recorder.record(
            stage: .videoReceive,
            error: NetworkChannelError.timedOut(operation: "send")
        )
        await recorder.record(
            stage: .videoReceive,
            error: NetworkChannelError.timedOut(operation: "receive")
        )
        let receipt = await recorder.receipt()
        XCTAssertEqual(
            receipt.failures,
            [
                LiveMediaFailure(stage: .videoReceive, cause: .unclassified),
                LiveMediaFailure(stage: .audioReceive, cause: .networkOtherTimedOut),
                LiveMediaFailure(stage: .videoReceive, cause: .networkConnectTimedOut),
                LiveMediaFailure(stage: .videoReceive, cause: .networkSendTimedOut),
                LiveMediaFailure(stage: .videoReceive, cause: .networkReceiveTimedOut),
            ]
        )
        XCTAssertEqual(
            receipt.summary,
            "video_receive:unclassified,audio_receive:network_other_timed_out,video_receive:network_connect_timed_out,video_receive:network_send_timed_out,video_receive:network_receive_timed_out"
        )
        XCTAssertFalse(receipt.summary.contains("secret"))
        XCTAssertFalse(receipt.summary.contains("47998"))
        XCTAssertFalse(receipt.summary.contains("certificate"))
        XCTAssertFalse(receipt.summary.contains("payload"))
        XCTAssertFalse(receipt.summary.contains("operation"))
    }

    func testLiveMediaActivityRecorderForwardsChannelAndBoundsReceipt()
        async throws
    {
        let recorder = LiveMediaActivityRecorder()
        let endpoint = RuntimeNetworkEndpoint(
            host: "198.51.100.42",
            port: 48_098,
            transport: .udp
        )
        recorder.recordConfiguration(
            stage: .videoReceive,
            endpoint: endpoint,
            usesCustomPing: true
        )
        let base = LiveMediaTestDatagramChannel(
            receiveChunk: NetworkReceiveChunk(
                data: Data("private-packet-payload".utf8),
                isComplete: true
            )
        )
        let channel = LiveRecordingDatagramChannel(
            base: base,
            stage: .videoReceive,
            recorder: recorder
        )

        try await channel.connect(timeout: .seconds(1))
        try await channel.send(
            Data("private-ping-payload".utf8),
            timeout: .seconds(1)
        )
        _ = try await channel.receiveWithoutDeadline(
            minimumLength: 1,
            maximumLength: 1_500
        )
        recorder.recordEvent(stage: .videoReceive)
        await channel.cancel()

        let receipt = recorder.receipt()
        XCTAssertEqual(
            receipt,
            LiveMediaActivityReceipt(stages: [
                LiveMediaActivityStageReceipt(
                    stage: .videoReceive,
                    endpointKind: .ipv4,
                    transport: .udp,
                    port: 48_098,
                    usesCustomPing: true,
                    connections: 1,
                    pingsSent: 1,
                    datagramsReceived: 1,
                    eventsProduced: 1
                )
            ])
        )
        XCTAssertEqual(
            receipt.summary,
            "video_receive(endpoint=ipv4_udp:48098,ping=custom,connections=1,pings=1,datagrams=1,events=1)"
        )
        XCTAssertFalse(receipt.summary.contains("198.51.100.42"))
        XCTAssertFalse(receipt.summary.contains("private-ping"))
        XCTAssertFalse(receipt.summary.contains("private-packet"))
        let calls = await base.calls()
        XCTAssertEqual(calls.connections, 1)
        XCTAssertEqual(calls.sends, 1)
        XCTAssertEqual(calls.receives, 1)
        XCTAssertEqual(calls.cancels, 1)
    }

    func testLiveVideoProcessingReceiptIsFiniteAndPrivacyBounded() {
        let recorder = LiveVideoProcessingRecorder()
        recorder.record(.packet(ReceivedVideoPacket(
            sequenceNumber: 987_654,
            frameIndex: 456_789,
            rtpTimestamp: 123_456,
            receiveTimeNanoseconds: 42,
            isFirstPacket: true,
            isLastPacket: true,
            payload: Data("secret payload certificate key endpoint".utf8)
        )))
        recorder.record(.packetLoss(expected: 123_450, received: 123_456))
        recorder.record([
            .accessUnit(VideoAccessUnit(
                frameIndex: 456_789,
                rtpTimestamp: 123_456,
                codec: .hevc,
                frameType: .instantaneousDecoderRefresh,
                hostProcessingLatencyTenthsOfMillisecond: 12,
                firstReceiveTimeNanoseconds: 10,
                lastReceiveTimeNanoseconds: 42,
                packetCount: 1,
                payload: Data("private access unit".utf8)
            )),
            .frameLost(VideoFrameLoss(
                firstFrameIndex: 456_790,
                lastFrameIndex: 456_790,
                reason: .inconsistentFrameMetadata,
                requiresIDR: true
            )),
            .packetDiscarded(.duplicate),
            .packetDiscarded(.parity),
            .packetDiscarded(.lateFrame),
        ])
        recorder.recordSubmittedFrame()
        recorder.record(VideoDecodePipelineSnapshot(
            activeDecoderGeneration: nil,
            isAwaitingIDR: true,
            hasOutstandingIDRRequest: true,
            isStopped: false,
            isLifecyclePaused: false,
            sessionCreationCount: 0,
            decoderResetCount: 0,
            formatChangeCount: 0,
            colorMetadataChangeCount: 0,
            idrRequestCount: 1,
            idrRequestFailureCount: 0,
            droppedAccessUnitCount: 1,
            decoderDroppedFrameCount: 0,
            decoderFailureCount: 0,
            teardownCount: 0,
            lifecyclePauseCount: 0,
            lifecycleResumeCount: 0
        ))

        let receipt = recorder.receipt()
        XCTAssertEqual(receipt.packetsReceived, 1)
        XCTAssertEqual(receipt.firstPacketsReceived, 1)
        XCTAssertEqual(receipt.lastPacketsReceived, 1)
        XCTAssertEqual(receipt.transportLossEvents, 1)
        XCTAssertEqual(receipt.accessUnitsAssembled, 1)
        XCTAssertEqual(receipt.frameLosses.inconsistentFrameMetadata, 1)
        XCTAssertEqual(receipt.discardedDuplicates, 1)
        XCTAssertEqual(receipt.discardedParityPackets, 1)
        XCTAssertEqual(receipt.discardedLatePackets, 1)
        XCTAssertEqual(receipt.submittedFrames, 1)
        XCTAssertTrue(receipt.decodePipeline?.isAwaitingIDR == true)
        XCTAssertTrue(
            receipt.decodePipeline?.hasOutstandingIDRRequest == true
        )
        XCTAssertEqual(receipt.decodePipeline?.idrRequestCount, 1)
        XCTAssertEqual(receipt.decodePipeline?.droppedAccessUnitCount, 1)
        XCTAssertFalse(receipt.summary.contains("987654"))
        XCTAssertFalse(receipt.summary.contains("456789"))
        XCTAssertFalse(receipt.summary.contains("123456"))
        XCTAssertFalse(receipt.summary.contains("secret"))
        XCTAssertFalse(receipt.summary.contains("payload"))
        XCTAssertFalse(receipt.summary.contains("certificate"))
        XCTAssertFalse(receipt.summary.contains("key"))
        XCTAssertFalse(receipt.summary.contains("endpoint"))
        XCTAssertFalse(receipt.summary.contains("private"))
    }

    func testLiveVideoProcessingWrapperForwardsProductionEventAndResult()
        async throws
    {
        let recorder = LiveVideoProcessingRecorder()
        let base = LiveVideoProcessingSpy(submissionResult: true)
        let processor = try LiveRecordingVideoProcessor(
            base: base,
            configuration: liveMediaTestVideoConfiguration(),
            recorder: recorder
        )
        var payload = Data([0x01, 0x00, 0x00, 0x02, 0x01, 0x00, 0x00, 0x00])
        payload.append(contentsOf: [0x00, 0x00, 0x01, 0x26, 0x01])
        let event = VideoReceiveEvent.packet(ReceivedVideoPacket(
            sequenceNumber: 9,
            frameIndex: 7,
            rtpTimestamp: 6,
            receiveTimeNanoseconds: 5,
            isFirstPacket: true,
            isLastPacket: true,
            payload: payload
        ))

        let submitted = try await processor.consume(event)
        XCTAssertTrue(submitted)
        await processor.stop()

        let processingReceipt = recorder.receipt()
        XCTAssertEqual(processingReceipt.packetsReceived, 1)
        XCTAssertEqual(processingReceipt.accessUnitsAssembled, 1)
        XCTAssertEqual(processingReceipt.submittedFrames, 1)
        XCTAssertEqual(processingReceipt.codec, .hevc)
        XCTAssertTrue(processingReceipt.decodePipeline?.decoderActive == true)
        XCTAssertEqual(processingReceipt.decodePipeline?.sessionCreationCount, 1)
        XCTAssertEqual(processingReceipt.decodePipeline?.idrRequestCount, 1)
        let baseReceipt = await base.receipt()
        XCTAssertEqual(baseReceipt.events, [event])
        XCTAssertEqual(baseReceipt.stopCount, 1)
    }

    func testLiveMediaRecorderConsumerTerminationCancelsUpstreamWithoutFailure()
        async
    {
        let base = LiveMediaControllableVideoProvider()
        let recorder = LiveMediaFailureRecorder()
        let provider = LiveRecordingVideoReceiveProvider(
            base: base,
            recorder: recorder
        )
        let stream = await provider.receiveVideo(
            sessionID: UUID(),
            endpoint: liveMediaTestEndpoint(port: 48_000),
            configuration: liveMediaTestVideoConfiguration()
        )
        let consumer = Task {
            for try await _ in stream {}
        }
        consumer.cancel()

        var upstreamTerminated = false
        for _ in 0..<1_000 {
            upstreamTerminated = await base.didTerminate()
            if upstreamTerminated { break }
            await Task.yield()
        }
        if !upstreamTerminated {
            await base.finish()
        }
        _ = await consumer.result

        XCTAssertTrue(upstreamTerminated)
        let receipt = await recorder.receipt()
        XCTAssertEqual(receipt.failures, [])
    }

    func testLiveTanmyWhiteProductionAcceptanceWhenExplicitlyEnabled()
        async throws
    {
        let scope = LiveSunshineAcceptanceConfiguration.scope(
            environment: ProcessInfo.processInfo.environment
        )
        guard scope != .disabled else {
            throw XCTSkip(
                "Set LUNEX_RUN_LIVE_HOST_TEST=1 for the bounded live catalog gate."
            )
        }

#if os(macOS) && DEBUG
        let liveRuntime = makeLiveSunshineProductionModel()
        let model = liveRuntime.model
        await model.loadInitialState()

        let matchingHosts = model.hosts.filter {
            $0.id == LiveSunshineAcceptanceConfiguration.hostID
                && $0.name == LiveSunshineAcceptanceConfiguration.hostName
                && $0.address == LiveSunshineAcceptanceConfiguration.hostAddress
        }
        guard matchingHosts.count == 1,
              let host = matchingHosts.first,
              host.pairingState == .paired,
              host.pinnedIdentity != nil else {
            XCTFail("The fixed paired and pinned tanmy-white host was not found.")
            return
        }

        let endpoint = try HostEndpointParser.parse(host.address)
        let serverInfo = try await fetchLiveServerInfoOnce(from: endpoint)
        guard serverInfo.name == LiveSunshineAcceptanceConfiguration.hostName else {
            XCTFail("The fixed endpoint did not identify itself as tanmy-white.")
            return
        }
        model.select(host: host)
        await model.refreshAppsForSelectedHost()
        guard model.primaryWorkspaceState?.catalog.phase == .current,
              model.primaryWorkspaceState?.catalog.issue == nil else {
            XCTFail("The production pinned-mTLS catalog did not become current.")
            return
        }

        let matchingApps = model.selectedApps.filter {
            $0.id == LiveSunshineAcceptanceConfiguration.appID
                && $0.name == LiveSunshineAcceptanceConfiguration.appName
        }
        let desktop = try XCTUnwrap(matchingApps.first)
        XCTAssertEqual(matchingApps.count, 1)
        guard scope == .desktopSession else { return }
        model.select(app: desktop)

        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(
                width: model.settings.stream.width,
                height: model.settings.stream.height
            )
        )
        XCTAssertEqual(lifecycle.renderPolicy, .active)
        model.applyPlatformLifecycle(lifecycle)

        let framesBeforeLaunch = model.videoPresentationSource
            .snapshot().publishedFrameCount
        let launchTask = Task { await model.launchSelectedApp() }
        let reachedStreaming = await waitForLiveSunshineCondition(
            timeout: .seconds(45)
        ) {
            model.session.isStreaming
                || [.failed, .remoteTerminated, .reconnectExhausted]
                    .contains(model.productSessionActualPhase)
        }
        guard reachedStreaming, model.session.isStreaming else {
            let phaseBeforeCleanup = model.productSessionActualPhase
            let issueCode = model.streamProductIssue?.code.rawValue ?? "none"
            let diagnostic = model.diagnostics.latestStreamActionableEvent
            let frameCount = model.videoPresentationSource
                .snapshot().publishedFrameCount
            let audioStage = model.audioRuntimeState?.runtime.stage.rawValue
                ?? "none"
            let calls = await liveRuntime.launchClient.counts()
            let control = await liveRuntime.controlProvider.receipt()
            let media = await liveRuntime.mediaRecorder.receipt()
            let mediaActivity = liveRuntime.mediaActivityRecorder.receipt()
            let videoProcessing = liveRuntime.videoProcessingRecorder.receipt()
            _ = await model.stopStream(in: model.primaryWorkspaceReference)
            launchTask.cancel()
            await launchTask.value
            XCTFail(
                "The production session did not reach streaming; preCleanupPhase=\(phaseBeforeCleanup), issue=\(issueCode), diagnostic=\(diagnostic?.code ?? "none"), subsystem=\(diagnostic?.subsystem ?? "none"), frames=\(frameCount), audioStage=\(audioStage), launch=\(calls.launches), resume=\(calls.resumes), cancel=\(calls.stops), controlEvents=\(control.events.joined(separator: ",")), controlFailure=\(control.failure?.rawValue ?? "none"), mediaFailures=\(media.summary), mediaActivity=\(mediaActivity.summary), videoProcessing=\(videoProcessing.summary)."
            )
            return
        }

        let mediaBecameActive = await waitForLiveSunshineCondition(
            timeout: .seconds(20)
        ) {
            model.videoPresentationSource.snapshot().publishedFrameCount
                > framesBeforeLaunch
                && model.audioRuntimeState?.runtime.stage == .running
        }
        guard mediaBecameActive else {
            let phaseBeforeCleanup = model.productSessionActualPhase
            let frameCount = model.videoPresentationSource
                .snapshot().publishedFrameCount
            let audioStage = model.audioRuntimeState?.runtime.stage.rawValue
                ?? "none"
            let media = await liveRuntime.mediaRecorder.receipt()
            let mediaActivity = liveRuntime.mediaActivityRecorder.receipt()
            let videoProcessing = liveRuntime.videoProcessingRecorder.receipt()
            _ = await model.stopStream(in: model.primaryWorkspaceReference)
            launchTask.cancel()
            await launchTask.value
            XCTFail(
                "Production video/audio runtime signals did not become active; preCleanupPhase=\(phaseBeforeCleanup), frames=\(frameCount), audioStage=\(audioStage), mediaFailures=\(media.summary), mediaActivity=\(mediaActivity.summary), videoProcessing=\(videoProcessing.summary)."
            )
            return
        }

        let firstSustainedFrameCount = model.videoPresentationSource
            .snapshot().publishedFrameCount
        do {
            try await model.sendRemoteInput(.pointer(.relativeMove(
                deltaX: 1,
                deltaY: 0,
                buttons: []
            )))
            try await model.sendRemoteInput(.pointer(.relativeMove(
                deltaX: -1,
                deltaY: 0,
                buttons: []
            )))
            try await model.releaseRemoteInput()
        } catch {
            _ = await model.stopStream(in: model.primaryWorkspaceReference)
            launchTask.cancel()
            await launchTask.value
            throw error
        }

        let sustainedVideo = await waitForLiveSunshineCondition(
            timeout: .seconds(10)
        ) {
            model.videoPresentationSource.snapshot().publishedFrameCount
                >= firstSustainedFrameCount + 30
        }
        XCTAssertTrue(sustainedVideo)
        XCTAssertEqual(model.audioRuntimeState?.runtime.stage, .running)

        let stopped = await model.stopStream(
            in: model.primaryWorkspaceReference
        )
        guard stopped else {
            launchTask.cancel()
            await launchTask.value
            XCTFail("The production session did not accept its bounded stop.")
            return
        }
        launchTask.cancel()
        await launchTask.value
        let teardownCompleted = await waitForLiveSunshineCondition(
            timeout: .seconds(10)
        ) {
            !model.hasActiveStreamSession
                && model.activeProductSessionOwner == nil
                && model.productSessionActualPhase == .idle
                && !model.session.isStreaming
                && model.audioRuntimeState == nil
                && model.videoPresentationSource.snapshot().sessionID == nil
        }
        XCTAssertTrue(teardownCompleted)
        let repeatedStop = await model.stopStream(
            in: model.primaryWorkspaceReference
        )
        XCTAssertFalse(repeatedStop)
        let calls = await liveRuntime.launchClient.counts()
        let selectedApplicationWasRunning =
            serverInfo.state?.hasSuffix("_SERVER_BUSY") == true
                && serverInfo.rawValues["currentgame"] == desktop.id
        if selectedApplicationWasRunning {
            XCTAssertEqual(calls.launches, 0)
            XCTAssertEqual(calls.resumes, 1)
        } else {
            XCTAssertEqual(calls.launches, 1)
            XCTAssertEqual(calls.resumes, 0)
        }
        XCTAssertEqual(calls.stops, 0)
        let control = await liveRuntime.controlProvider.receipt()
        XCTAssertNil(control.failure)
        let media = await liveRuntime.mediaRecorder.receipt()
        XCTAssertEqual(media.failures, [])
#else
        throw XCTSkip(
            "The live harness is limited to macOS Debug so it always uses the explicit file identity fallback."
        )
#endif
    }

    func testSceneConnectionsRestoreThroughAppModelAndKeepUnsupportedPrimary()
        async throws
    {
        let model = AppModel()
        let initialPrimary = model.primaryWorkspaceReference
        let restoredID = ProductWorkspaceID(
            rawValue: UUID(uuidString: "49000000-0000-0000-0000-000000000001")!
        )

        let first = try model.connectProductWorkspaceScene(
            restoring: ProductWorkspaceSceneIdentity(workspaceID: restoredID),
            supportsMultipleWindows: true
        )
        XCTAssertEqual(model.primaryWorkspaceReference, first.workspace)
        XCTAssertEqual(first.workspace.id, restoredID)
        XCTAssertNil(model.workspaceState(for: initialPrimary))

        let firstClose = await model.disconnectProductWorkspaceScene(first)
        XCTAssertEqual(firstClose, .detached)
        let replacement = try model.connectProductWorkspaceScene(
            restoring: first.identity,
            supportsMultipleWindows: true
        )
        XCTAssertEqual(replacement.workspace.id, restoredID)
        XCTAssertEqual(replacement.workspace.generation.rawValue, 2)
        XCTAssertEqual(model.primaryWorkspaceReference, replacement.workspace)
        XCTAssertNil(model.workspaceState(for: first.workspace))

        let unsupported = try model.connectProductWorkspaceScene(
            restoring: ProductWorkspaceSceneIdentity(),
            supportsMultipleWindows: false
        )
        XCTAssertEqual(unsupported.workspace, replacement.workspace)
        XCTAssertEqual(model.workspaceRegistry.states.count, 1)
    }

    func testProviderAvailabilityIsDerivedFromInjectedInventory() {
        let unavailable = RuntimeProviderInventory.unavailable
        XCTAssertEqual(unavailable.availability, [])
        XCTAssertFalse(unavailable.availability.pairingTransportAvailable)
        XCTAssertFalse(unavailable.availability.streamTransportAvailable)

        let production = ProductionRuntimeProviderFactory.makeDefault()
        XCTAssertEqual(production.availability, [
            .pairing,
            .sessionControl,
            .videoReceive,
            .audioReceive,
            .remoteInput
        ])
        XCTAssertTrue(production.availability.pairingTransportAvailable)
        XCTAssertTrue(production.availability.streamTransportAvailable)

        let complete = RuntimeProviderInventory(
            pairing: production.pairing,
            sessionControl: production.sessionControl,
            videoReceive: AvailabilityVideoReceiveProvider(),
            audioReceive: AvailabilityAudioReceiveProvider(),
            remoteInput: production.remoteInput
        )
        XCTAssertEqual(complete.availability, [
            .pairing,
            .sessionControl,
            .videoReceive,
            .audioReceive,
            .remoteInput
        ])
        XCTAssertTrue(complete.availability.streamTransportAvailable)

        let withoutPairing = RuntimeProviderInventory(
            sessionControl: complete.sessionControl,
            videoReceive: complete.videoReceive,
            audioReceive: complete.audioReceive,
            remoteInput: complete.remoteInput
        )
        XCTAssertFalse(withoutPairing.availability.pairingTransportAvailable)
        XCTAssertTrue(withoutPairing.availability.streamTransportAvailable)

        let missingRequiredProvider = [
            RuntimeProviderInventory(
                videoReceive: complete.videoReceive,
                audioReceive: complete.audioReceive,
                remoteInput: complete.remoteInput
            ),
            RuntimeProviderInventory(
                sessionControl: complete.sessionControl,
                audioReceive: complete.audioReceive,
                remoteInput: complete.remoteInput
            ),
            RuntimeProviderInventory(
                sessionControl: complete.sessionControl,
                videoReceive: complete.videoReceive,
                remoteInput: complete.remoteInput
            ),
            RuntimeProviderInventory(
                sessionControl: complete.sessionControl,
                videoReceive: complete.videoReceive,
                audioReceive: complete.audioReceive
            )
        ]
        XCTAssertTrue(missingRequiredProvider.allSatisfy {
            !$0.availability.streamTransportAvailable
        })
    }

    func testAppModelAppliesPlatformLifecycleToRenderState() {
        let model = AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(),
                serverInfoClient: StubServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: StubAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(launchClient: StubStreamLaunchClient()),
            clientIdentityStore: InMemoryClientIdentityStore()
        )
        let lifecycle = PlatformLifecycleState()
        lifecycle.isStreamActive = true
        lifecycle.isVisible = true
        lifecycle.isFocused = false
        lifecycle.updateSurface(
            displayID: "display-a",
            headroom: DisplayHeadroom(potential: 2.0, current: 1.5, reference: 1.0),
            drawableSize: PixelSize(width: 2560, height: 1440)
        )
        model.renderState.transform.sourceSize = PixelSize(width: 1920, height: 1080)

        model.applyPlatformLifecycle(lifecycle)

        XCTAssertEqual(model.renderState.policy, .throttled(reason: "Window or scene not focused"))
        XCTAssertEqual(model.renderState.transform.drawableSize, PixelSize(width: 2560, height: 1440))
        XCTAssertEqual(model.renderState.coordinateSnapshot?.drawableSize, PixelSize(width: 2560, height: 1440))
        XCTAssertEqual(model.renderState.headroom, lifecycle.headroom)
    }

    func testRenderPreferencesDoNotSynthesizeDisplayHeadroomWithoutLifecycle() {
        let model = AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(),
                serverInfoClient: StubServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: StubAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(
                launchClient: StubStreamLaunchClient()
            ),
            clientIdentityStore: InMemoryClientIdentityStore()
        )

        XCTAssertTrue(model.settings.stream.hdrEnabled)
        XCTAssertEqual(model.renderState.headroom, DisplayHeadroom())
        XCTAssertNil(model.renderState.displaySnapshot)

        model.settings.stream.hdrEnabled = false
        XCTAssertEqual(model.renderState.headroom, DisplayHeadroom())
        XCTAssertNil(model.renderState.displaySnapshot)

        model.settings.stream.hdrEnabled = true
        XCTAssertEqual(model.renderState.headroom, DisplayHeadroom())
        XCTAssertNil(model.renderState.displaySnapshot)
    }

    func testHDRDiagnosticsDeduplicateAndClearOnlyHDRActionOnRecovery() {
        let model = AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(),
                serverInfoClient: StubServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: StubAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(
                launchClient: StubStreamLaunchClient()
            ),
            clientIdentityStore: InMemoryClientIdentityStore()
        )
        model.diagnostics.record(
            ApplicationDiagnosticFactory.streamFailure(VideoDecoderError.noActiveSession)
        )

        model.publishHDRPresentationDiagnostic(.pipelineFailure)
        model.publishHDRPresentationDiagnostic(.pipelineFailure)
        XCTAssertEqual(
            model.diagnostics.events.filter {
                $0.code == "hdr_pipeline_failure"
            }.count,
            1
        )
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.category,
            .hdr
        )

        model.publishHDRPresentationDiagnostic(.activeEDR)
        model.publishHDRPresentationDiagnostic(.activeEDR)
        XCTAssertEqual(
            model.diagnostics.events.filter { $0.code == "hdr_active_edr" }.count,
            1
        )
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.category,
            .decoder
        )
        XCTAssertTrue(model.diagnostics.events.contains {
            $0.code == "hdr_pipeline_failure"
        })

        model.publishHDRPresentationDiagnostic(
            .sdrFallback(.platformOutputUnsupported(.macOS))
        )
        model.publishHDRPresentationDiagnostic(
            .sdrFallback(.platformOutputUnsupported(.macOS))
        )
        XCTAssertEqual(
            model.diagnostics.events.filter {
                $0.code == "hdr_sdr_fallback_unsupported_output"
            }.count,
            1
        )
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.category,
            .hdr
        )

        model.publishHDRPresentationDiagnostic(.inactive)
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.category,
            .decoder
        )
        XCTAssertEqual(model.diagnostics.events.count, 4)
    }

    func testHDRDiagnosticOwnershipRejectsStalePresenterAfterReplacement() {
        let model = AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(),
                serverInfoClient: StubServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: StubAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(
                launchClient: StubStreamLaunchClient()
            ),
            clientIdentityStore: InMemoryClientIdentityStore()
        )
        let oldOwner = UUID()
        let replacementOwner = UUID()

        model.claimHDRPresentationDiagnosticOwnership(oldOwner)
        model.publishHDRPresentationDiagnostic(.activeEDR, ownerID: oldOwner)
        model.claimHDRPresentationDiagnosticOwnership(replacementOwner)
        model.publishHDRPresentationDiagnostic(.activeSDR, ownerID: replacementOwner)

        model.publishHDRPresentationDiagnostic(.pipelineFailure, ownerID: oldOwner)
        model.publishHDRPresentationDiagnostic(.inactive, ownerID: oldOwner)
        model.releaseHDRPresentationDiagnosticOwnership(oldOwner)
        model.publishHDRPresentationDiagnostic(.pipelineFailure, ownerID: oldOwner)

        XCTAssertEqual(
            model.diagnostics.events.map(\.code),
            ["hdr_active_edr", "hdr_active_sdr"]
        )
        XCTAssertNil(model.diagnostics.latestStreamActionableEvent)

        model.publishHDRPresentationDiagnostic(
            .pipelineFailure,
            ownerID: replacementOwner
        )
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.code,
            "hdr_pipeline_failure"
        )
        model.publishHDRPresentationDiagnostic(.inactive, ownerID: replacementOwner)
        model.releaseHDRPresentationDiagnosticOwnership(replacementOwner)
        XCTAssertNil(model.diagnostics.latestStreamActionableEvent)
    }

    func testLatestLifecycleIsCachedUntilMediaGenerationStartsAndThenAppliedInOrder() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 31,
                    key: Data(repeating: 0x31, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()

        let lifecycle = makePlatformLifecycle(
            isStreamActive: false,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 2560, height: 1440)
        )
        model.applyPlatformLifecycle(lifecycle)
        lifecycle.isStreamActive = true
        lifecycle.isVisible = false
        lifecycle.updateSurface(
            displayID: "display-a",
            headroom: DisplayHeadroom(
                potential: 2.4,
                current: 1.8,
                reference: 1.0
            ),
            drawableSize: lifecycle.drawableSize
        )
        model.applyPlatformLifecycle(lifecycle)
        XCTAssertEqual(mediaEnvironment.currentLifecycleApplications(), [])

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        XCTAssertTrue(model.isPlatformStreamLifecycleActive)
        XCTAssertFalse(model.session.isStreaming)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { mediaEnvironment.currentLifecycleApplications().count == 1 }

        let cachedApplication = try XCTUnwrap(
            mediaEnvironment.currentLifecycleApplications().first
        )
        XCTAssertEqual(cachedApplication.sessionID, record.sessionID)
        XCTAssertEqual(cachedApplication.mediaGeneration, 1)
        XCTAssertEqual(cachedApplication.lifecycleRevision, 2)
        XCTAssertEqual(
            cachedApplication.directive,
            SessionLifecycleDirectiveResolver.resolve(
                isStreamActive: true,
                isVisible: false,
                isFocused: true,
                drawableSize: PixelSize(width: 2560, height: 1440)
            )
        )

        lifecycle.isVisible = true
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        await waitUntil { mediaEnvironment.currentLifecycleApplications().count == 2 }
        await waitUntil { model.session.isStreaming }
        let applications = mediaEnvironment.currentLifecycleApplications()
        XCTAssertEqual(applications.map(\.lifecycleRevision), [2, 3])
        XCTAssertEqual(applications.last?.directive.input, .open)
        XCTAssertEqual(model.renderState.policy, .active)
        XCTAssertEqual(
            model.renderState.transform.sourceSize,
            PixelSize(width: 3840, height: 2160)
        )
        XCTAssertEqual(model.renderState.headroom, lifecycle.headroom)

        await model.stopStream()
        await launchTask.value
    }

    func testHDREligibilityWaitsForStreamingVideoReadiness() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(
            automaticallyReady: false
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 39,
                    key: Data(repeating: 0x39, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()

        let drawableSize = PixelSize(width: 3_840, height: 2_160)
        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: drawableSize
        )
        _ = lifecycle.updateSurface(
            displayID: "display-a",
            headroom: DisplayHeadroom(
                potential: 4,
                current: 2.5,
                reference: 1
            ),
            drawableSize: drawableSize
        )
        model.applyPlatformLifecycle(lifecycle)

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        let hdrMetadata = VideoColorMetadata.hdr10VideoRange()
        provider.yield(
            .launchAccepted(makeSessionLaunchResponse()),
            sessionID: record.sessionID
        )
        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey,
                videoColorMetadata: hdrMetadata
            )),
            sessionID: record.sessionID
        )
        provider.yield(.channelsReady(.all), sessionID: record.sessionID)
        await waitUntil { mediaEnvironment.currentStartRecords().count == 1 }

        let hdrLayout = HDRDecodedPixelBufferLayout(
            pixelFormat: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
            width: 3_840,
            height: 2_160,
            planes: [
                HDRDecodedPlaneDimensions(width: 3_840, height: 2_160),
                HDRDecodedPlaneDimensions(width: 1_920, height: 1_080)
            ]
        )
        mediaEnvironment.yieldVideoPresentation(
            .decoderStarted(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 1
                ),
                contract: StreamVideoDecoderPresentationContract(
                    decoderGeneration: 1,
                    colorMetadata: hdrMetadata
                )
            ),
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldVideoPresentation(
            .decodedFrame(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 2
                ),
                contract: StreamVideoDecodedPresentationContract(
                    decoderGeneration: 1,
                    colorMetadata: hdrMetadata,
                    decodedLayout: hdrLayout
                )
            ),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.decodedVideoPresentationContract != nil
        }
        XCTAssertFalse(model.session.isStreaming)
        XCTAssertEqual(
            model.renderState.hdrRenderResolution,
            .closed(.inactiveSession)
        )

        mediaEnvironment.yieldReadiness(
            [.video, .audio, .input],
            sessionID: record.sessionID
        )
        await waitUntil { model.session.isStreaming }
        await waitUntil {
            model.renderState.hdrRenderResolution.configuration?.outputMode == .edr
        }

        mediaEnvironment.yieldReadiness(
            [.audio, .input],
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.hdrRenderResolution == .closed(.inactiveSession)
        }
        await waitUntil { model.session.phase.label.contains("Reconnecting") }

        await model.stopStream()
        await launchTask.value
    }

    func testHDRApplicationIntegrationCoversPresentationRevisionsStaleFramesAndCleanStop()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 38,
                    key: Data(repeating: 0x38, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()

        let drawableSize = PixelSize(width: 64, height: 64)
        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: drawableSize
        )
        _ = lifecycle.updateSurface(
            displayID: "display-a",
            headroom: DisplayHeadroom(
                potential: 4,
                current: 2.5,
                reference: 1
            ),
            drawableSize: drawableSize
        )
        model.applyPlatformLifecycle(lifecycle)

        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(
            frame: CGRect(x: 0, y: 0, width: 64, height: 64),
            device: device
        )
        let drawableLayer = CAMetalLayer()
        drawableLayer.device = device
        drawableLayer.pixelFormat = .bgra8Unorm_srgb
        drawableLayer.drawableSize = CGSize(width: 64, height: 64)
        let drawable = try XCTUnwrap(drawableLayer.nextDrawable())
        let surfaceAdapter = RecordingPresenterSurfaceAdapter()
        var presenterRuntimes: [RecordingStreamMetalPresenterRuntime] = []
        let presenter = StreamMetalPresenter(
            presentationSource: model.videoPresentationSource,
            renderState: model.renderState,
            runtimeFactory: { _, _ in
                let runtime = RecordingStreamMetalPresenterRuntime()
                presenterRuntimes.append(runtime)
                return runtime
            },
            surfaceAdapterFactory: { _ in surfaceAdapter },
            drawableProvider: { _ in drawable },
            diagnosticLease: HDRPresentationDiagnosticLease(
                claim: { model.claimHDRPresentationDiagnosticOwnership($0) },
                publish: { ownerID, state in
                    model.publishHDRPresentationDiagnostic(
                        state,
                        ownerID: ownerID
                    )
                },
                release: { model.releaseHDRPresentationDiagnosticOwnership($0) }
            )
        )
        presenter.configure(view)

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        model.videoPresentationSource.beginSession(
            sessionID: record.sessionID,
            mediaGeneration: 1
        )

        let hdrMetadata = VideoColorMetadata.hdr10VideoRange()
        provider.yield(
            .videoColorMetadata(hdrMetadata),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.negotiatedVideoColorMetadata == hdrMetadata
        }
        XCTAssertEqual(
            model.renderState.hdrRenderResolution,
            .closed(.inactiveSession)
        )

        let hdrFrame = try makeHDRApplicationFrame(
            generation: 10,
            frameID: 1,
            metadata: hdrMetadata
        )
        let hdrLayout = HDRDecodedPixelBufferLayout(
            pixelBuffer: hdrFrame.pixelBuffer
        )
        let sdrMetadata = VideoColorMetadata.rec709VideoRange()
        let sdrFrame = try makeHDRApplicationFrame(
            generation: 11,
            frameID: 2,
            metadata: sdrMetadata
        )
        let sdrLayout = HDRDecodedPixelBufferLayout(
            pixelBuffer: sdrFrame.pixelBuffer
        )
        mediaEnvironment.yieldVideoPresentation(
            .decoderStarted(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 1
                ),
                contract: StreamVideoDecoderPresentationContract(
                    decoderGeneration: 10,
                    colorMetadata: hdrMetadata
                )
            ),
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldVideoPresentation(
            .decodedFrame(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 2
                ),
                contract: StreamVideoDecodedPresentationContract(
                    decoderGeneration: 10,
                    colorMetadata: hdrMetadata,
                    decodedLayout: hdrLayout
                )
            ),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.hdrRenderResolution.configuration?
                .identity.decoderGeneration == 10
        }
        let activeEDR = try XCTUnwrap(
            model.renderState.hdrRenderResolution.configuration
        )
        XCTAssertEqual(activeEDR.outputMode, .edr)
        XCTAssertEqual(activeEDR.identity.mappingMode, .hdrEDR)
        XCTAssertEqual(
            activeEDR.identity.displayRevision,
            lifecycle.displayRevision
        )
        model.videoPresentationSource.consume(
            .sessionStarted(generation: 10, colorMetadata: hdrMetadata),
            sessionID: record.sessionID,
            mediaGeneration: 1
        )
        model.videoPresentationSource.consume(
            .frame(hdrFrame),
            sessionID: record.sessionID,
            mediaGeneration: 1
        )
        presenter.update(renderState: model.renderState)
        presenter.draw(in: view)
        presenter.draw(in: view)
        XCTAssertEqual(
            presenter.snapshot().activeConfiguration,
            activeEDR.identity
        )
        XCTAssertEqual(
            surfaceAdapter.activeContract,
            activeEDR.identity.surfaceContract
        )
        XCTAssertEqual(
            presenterRuntimes.last?.presentedConfigurations.last,
            activeEDR.identity
        )
        XCTAssertEqual(
            model.renderState.transform.sourceSize,
            PixelSize(width: 64, height: 64)
        )

        mediaEnvironment.yieldVideoPresentation(
            .decodedFrame(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 3
                ),
                contract: StreamVideoDecodedPresentationContract(
                    decoderGeneration: 10,
                    colorMetadata: sdrMetadata,
                    decodedLayout: sdrLayout
                )
            ),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.hdrRenderResolution == .closed(.staleColorSignature)
        }
        let presentationCountBeforeClosed = presenterRuntimes.reduce(0) {
            $0 + $1.presentCount
        }
        presenter.update(renderState: model.renderState)
        presenter.draw(in: view)
        XCTAssertNil(presenter.snapshot().activeConfiguration)
        XCTAssertEqual(
            presenterRuntimes.reduce(0) { $0 + $1.presentCount },
            presentationCountBeforeClosed
        )
        mediaEnvironment.yieldVideoPresentation(
            .decodedFrame(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 4
                ),
                contract: StreamVideoDecodedPresentationContract(
                    decoderGeneration: 10,
                    colorMetadata: hdrMetadata,
                    decodedLayout: hdrLayout
                )
            ),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.hdrRenderResolution.configuration?.outputMode == .edr
        }
        presenter.update(renderState: model.renderState)
        presenter.draw(in: view)
        presenter.draw(in: view)
        XCTAssertEqual(
            presenterRuntimes.last?.presentedConfigurations.last?.mappingMode,
            .hdrEDR
        )

        _ = lifecycle.updateSurface(
            displayID: "display-a",
            headroom: DisplayHeadroom(
                potential: 4,
                current: 1,
                reference: 1
            ),
            drawableSize: drawableSize
        )
        model.applyPlatformLifecycle(lifecycle)
        let constrained = try XCTUnwrap(
            model.renderState.hdrRenderResolution.configuration
        )
        XCTAssertEqual(
            constrained.outputMode,
            .sdrFallback(.currentHeadroomInsufficient)
        )
        XCTAssertEqual(constrained.identity.mappingMode, .hdrToSDR)
        XCTAssertEqual(
            constrained.identity.displayRevision,
            lifecycle.displayRevision
        )
        presenter.update(renderState: model.renderState)
        presenter.draw(in: view)
        presenter.draw(in: view)
        XCTAssertEqual(
            presenterRuntimes.last?.presentedConfigurations.last?.mappingMode,
            .hdrToSDR
        )
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.code,
            "hdr_sdr_fallback_headroom_insufficient"
        )

        _ = lifecycle.updateSurface(
            displayID: "display-a",
            headroom: DisplayHeadroom(
                potential: 4,
                current: 2.5,
                reference: 1
            ),
            drawableSize: drawableSize
        )
        model.applyPlatformLifecycle(lifecycle)
        let recovered = try XCTUnwrap(
            model.renderState.hdrRenderResolution.configuration
        )
        XCTAssertEqual(recovered.outputMode, .edr)
        presenter.update(renderState: model.renderState)
        presenter.draw(in: view)
        presenter.draw(in: view)
        XCTAssertEqual(
            presenterRuntimes.last?.presentedConfigurations.last,
            recovered.identity
        )
        XCTAssertNil(model.diagnostics.latestStreamActionableEvent)

        model.settings.stream.hdrEnabled = false
        let disabled = try XCTUnwrap(
            model.renderState.hdrRenderResolution.configuration
        )
        XCTAssertEqual(
            disabled.outputMode,
            .sdrFallback(.userPreferenceDisabled)
        )
        model.settings.stream.hdrEnabled = true

        let revisionBeforeDisplayMove = lifecycle.displayRevision
        _ = lifecycle.updateSurface(
            displayID: "display-b",
            headroom: DisplayHeadroom(
                potential: 4,
                current: 2.5,
                reference: 1
            ),
            drawableSize: drawableSize
        )
        model.applyPlatformLifecycle(lifecycle)
        let movedEDR = try XCTUnwrap(
            model.renderState.hdrRenderResolution.configuration
        )
        XCTAssertGreaterThan(
            movedEDR.identity.displayRevision,
            revisionBeforeDisplayMove
        )
        XCTAssertEqual(movedEDR.outputMode, .edr)
        presenter.update(renderState: model.renderState)
        presenter.draw(in: view)
        presenter.draw(in: view)
        XCTAssertEqual(
            presenterRuntimes.last?.presentedConfigurations.last,
            movedEDR.identity
        )

        provider.yield(
            .videoColorMetadata(sdrMetadata),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.negotiatedVideoColorMetadata == sdrMetadata
                && model.renderState.decodedVideoPresentationContract == nil
        }
        XCTAssertEqual(
            model.renderState.hdrRenderResolution,
            .closed(.inactiveSession)
        )

        mediaEnvironment.yieldVideoPresentation(
            .decodedFrame(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 6
                ),
                contract: StreamVideoDecodedPresentationContract(
                    decoderGeneration: 11,
                    colorMetadata: sdrMetadata,
                    decodedLayout: sdrLayout
                )
            ),
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldVideoPresentation(
            .decoderStarted(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 5
                ),
                contract: StreamVideoDecoderPresentationContract(
                    decoderGeneration: 11,
                    colorMetadata: sdrMetadata
                )
            ),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.hdrRenderResolution.configuration?
                .identity.decoderGeneration == 11
        }
        let activeSDR = try XCTUnwrap(
            model.renderState.hdrRenderResolution.configuration
        )
        XCTAssertEqual(activeSDR.outputMode, .sdr)
        XCTAssertEqual(activeSDR.identity.mappingMode, .sdr)
        model.videoPresentationSource.consume(
            .sessionStarted(generation: 11, colorMetadata: sdrMetadata),
            sessionID: record.sessionID,
            mediaGeneration: 1
        )
        model.videoPresentationSource.consume(
            .frame(sdrFrame),
            sessionID: record.sessionID,
            mediaGeneration: 1
        )
        presenter.update(renderState: model.renderState)
        presenter.draw(in: view)
        presenter.draw(in: view)
        XCTAssertEqual(
            presenterRuntimes.last?.presentedConfigurations.last,
            activeSDR.identity
        )
        XCTAssertEqual(
            surfaceAdapter.activeContract,
            activeSDR.identity.surfaceContract
        )

        mediaEnvironment.yieldVideoPresentation(
            .decodedFrame(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 7
                ),
                contract: StreamVideoDecodedPresentationContract(
                    decoderGeneration: 10,
                    colorMetadata: hdrMetadata,
                    decodedLayout: hdrLayout
                )
            ),
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldVideoPresentation(
            .cleared(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 8
                ),
                decoderGeneration: 10
            ),
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            model.renderState.hdrRenderResolution.configuration?
                .identity.decoderGeneration,
            11
        )
        XCTAssertEqual(
            model.renderState.decodedVideoPresentationContract?
                .decoderGeneration,
            11
        )
        let staleFrameDropsBefore = model.videoPresentationSource.snapshot()
            .staleFrameDropCount
        model.videoPresentationSource.consume(
            .frame(hdrFrame),
            sessionID: record.sessionID,
            mediaGeneration: 1
        )
        XCTAssertEqual(
            model.videoPresentationSource.snapshot().staleFrameDropCount,
            staleFrameDropsBefore + 1
        )
        XCTAssertEqual(
            model.videoPresentationSource.currentFrame()?.frameID,
            sdrFrame.frameID
        )
        presenter.draw(in: view)
        XCTAssertEqual(
            presenterRuntimes.last?.presentedConfigurations.last,
            activeSDR.identity
        )
        mediaEnvironment.yieldVideoPresentation(
            .cleared(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 0,
                    revision: .max
                ),
                decoderGeneration: nil
            ),
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            model.renderState.hdrRenderResolution.configuration?
                .identity.decoderGeneration,
            11
        )

        await model.stopStream()
        await launchTask.value
        presenter.update(renderState: model.renderState)
        presenter.stop()
        XCTAssertNil(model.renderState.negotiatedVideoColorMetadata)
        XCTAssertNil(model.renderState.decodedVideoPresentationContract)
        XCTAssertEqual(
            model.renderState.hdrRenderResolution,
            .closed(.inactiveSession)
        )
        XCTAssertNil(model.videoPresentationSource.currentFrame())
        XCTAssertNil(presenter.snapshot().activeConfiguration)
        XCTAssertEqual(
            surfaceAdapter.activeContract?.extendedRangeIntent,
            .disabled
        )
        XCTAssertTrue(presenterRuntimes.allSatisfy {
            $0.invalidationCount == 1
        })
        XCTAssertNil(model.diagnostics.latestStreamActionableEvent)
    }

    func testMacPlatformSampleFlowsThroughAppModelAndFocusLossReleasesInput() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 32,
                    key: Data(repeating: 0x32, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 2560, height: 1440)
        )
        model.applyPlatformLifecycle(lifecycle)

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        await waitUntil {
            model.macSessionInputSnapshot().acceptsInput
                && model.macInputSurfacePolicy.admitsInput
        }

        let sample = MacPlatformInputSample.keyboard(MacKeyboardSample(
            rawKeyCode: 0,
            characters: "a",
            isDown: true,
            modifiers: [],
            isRepeat: false
        ))
        XCTAssertEqual(model.submitMacPlatformInput(sample), .accepted)
        await waitUntil { mediaEnvironment.currentSentInputApplications().count == 1 }
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().first?.event,
            .keyboard(KeyboardInputEvent(
                rawKeyCode: 0x41,
                characters: "a",
                isDown: true,
                modifiers: [],
                isRepeat: false
            ))
        )

        lifecycle.isFocused = false
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        XCTAssertFalse(model.macSessionInputSnapshot().acceptsInput)
        XCTAssertEqual(
            model.submitMacPlatformInput(sample),
            .rejected(.admissionClosed)
        )
        await waitUntil {
            model.macSessionInputSnapshot().completedReleaseBarrierCount == 1
        }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            1
        )
        XCTAssertEqual(
            model.macSessionInputSnapshot().completedReleaseBarrierCount,
            1
        )
        XCTAssertEqual(model.renderState.policy, .throttled(
            reason: "Window or scene not focused"
        ))

        await model.stopStream()
        await launchTask.value
        XCTAssertNil(model.macSessionInputSnapshot().generation)
    }

    func testMacApplicationIntegrationCoversInputLifecycleResizeAndTeardown() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let presentationSource = StreamVideoPresentationSource()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            videoPresentationSource: presentationSource,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 37,
                    key: Data(repeating: 0x37, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        model.settings.input.preferRelativeMouseMode = false
        model.settings.input.captureSystemShortcuts = false

        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 2_560, height: 1_440)
        )
        model.applyPlatformLifecycle(lifecycle)

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil {
            model.session.isStreaming
                && model.macInputSurfacePolicy.admitsInput
                && mediaEnvironment.currentLifecycleApplications().last?.directive.input == .open
        }

        let initialCoordinate = try XCTUnwrap(model.renderState.coordinateSnapshot)
        let initialLifecycleRevision = try XCTUnwrap(
            mediaEnvironment.currentLifecycleApplications().last?.lifecycleRevision
        )
        presentationSource.beginSession(sessionID: record.sessionID, mediaGeneration: 1)
        presentationSource.consume(
            .sessionStarted(generation: 11, colorMetadata: .rec709VideoRange()),
            sessionID: record.sessionID,
            mediaGeneration: 1
        )
        XCTAssertEqual(initialCoordinate.drawableSize, PixelSize(width: 2_560, height: 1_440))
        XCTAssertEqual(presentationSource.snapshot().sessionID, record.sessionID)
        XCTAssertEqual(presentationSource.snapshot().decoderGeneration, 11)

        let keySample = MacPlatformInputSample.keyboard(MacKeyboardSample(
            rawKeyCode: 0,
            characters: "a",
            isDown: true,
            modifiers: [],
            isRepeat: false
        ))
        XCTAssertEqual(model.submitMacPlatformInput(keySample), .accepted)
        await waitUntil { mediaEnvironment.currentSentInputApplications().count == 1 }
        let deliveredKeyApplication = try XCTUnwrap(
            mediaEnvironment.currentSentInputApplications().first
        )
        XCTAssertEqual(deliveredKeyApplication.sessionID, record.sessionID)
        XCTAssertEqual(deliveredKeyApplication.mediaGeneration, 1)
        XCTAssertEqual(
            deliveredKeyApplication.event,
            .keyboard(KeyboardInputEvent(
                rawKeyCode: 0x41,
                characters: "a",
                isDown: true,
                modifiers: [],
                isRepeat: false
            ))
        )

        lifecycle.isFocused = false
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)
        XCTAssertEqual(
            model.submitMacPlatformInput(keySample),
            .rejected(.admissionClosed)
        )
        let unfocusedDirective = SessionLifecycleDirectiveResolver.resolve(
            isStreamActive: true,
            isVisible: true,
            isFocused: false,
            drawableSize: PixelSize(width: 2_560, height: 1_440)
        )
        await waitUntil {
            model.macSessionInputSnapshot().completedReleaseBarrierCount == 1
                && mediaEnvironment.currentReleasedInputApplications().count == 1
                && mediaEnvironment.currentLifecycleApplications().last?.directive
                    == unfocusedDirective
        }
        let unfocusedLifecycleRevision = try XCTUnwrap(
            mediaEnvironment.currentLifecycleApplications().last?.lifecycleRevision
        )
        let releaseApplication = try XCTUnwrap(
            mediaEnvironment.currentReleasedInputApplications().first
        )
        XCTAssertEqual(releaseApplication.sessionID, record.sessionID)
        XCTAssertEqual(releaseApplication.mediaGeneration, 1)
        XCTAssertGreaterThan(unfocusedLifecycleRevision, initialLifecycleRevision)
        XCTAssertEqual(unfocusedDirective.videoProcessing, .submitDecodedVideo)
        XCTAssertEqual(unfocusedDirective.presentation, .throttled(reason: .notFocused))

        lifecycle.isVisible = false
        lifecycle.isFocused = true
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        let occludedDirective = SessionLifecycleDirectiveResolver.resolve(
            isStreamActive: true,
            isVisible: false,
            isFocused: true,
            drawableSize: PixelSize(width: 2_560, height: 1_440)
        )
        await waitUntil {
            mediaEnvironment.currentLifecycleApplications().last?.directive
                == occludedDirective
        }
        let occludedLifecycleRevision = try XCTUnwrap(
            mediaEnvironment.currentLifecycleApplications().last?.lifecycleRevision
        )
        let occludedPresentationSnapshot = presentationSource.snapshot()
        XCTAssertGreaterThan(occludedLifecycleRevision, unfocusedLifecycleRevision)
        XCTAssertEqual(
            occludedDirective.videoProcessing,
            .drainTransportWithoutDecoding(reason: .notVisible)
        )
        XCTAssertEqual(occludedDirective.presentation, .clear(reason: .notVisible))
        XCTAssertEqual(model.renderState.policy, .paused(reason: "Window or scene not visible"))
        XCTAssertNil(occludedPresentationSnapshot.decoderGeneration)
        XCTAssertNil(occludedPresentationSnapshot.latestFrameID)
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)
        XCTAssertEqual(model.macSessionInputSnapshot().completedReleaseBarrierCount, 1)
        XCTAssertTrue(model.hasActiveStreamSession)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [])
        XCTAssertEqual(mediaEnvironment.currentStoppedSessionIDs(), [])

        lifecycle.isVisible = true
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        let resumedDirective = SessionLifecycleDirectiveResolver.resolve(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 2_560, height: 1_440)
        )
        await waitUntil {
            model.macInputSurfacePolicy.admitsInput
                && mediaEnvironment.currentLifecycleApplications().last?.directive
                    == resumedDirective
        }
        let resumedLifecycleRevision = try XCTUnwrap(
            mediaEnvironment.currentLifecycleApplications().last?.lifecycleRevision
        )
        XCTAssertGreaterThan(resumedLifecycleRevision, occludedLifecycleRevision)
        XCTAssertEqual(resumedDirective.videoProcessing, .submitDecodedVideo)
        XCTAssertEqual(resumedDirective.presentation, .active)
        presentationSource.consume(
            .sessionStarted(generation: 12, colorMetadata: .rec709VideoRange()),
            sessionID: record.sessionID,
            mediaGeneration: 1
        )
        XCTAssertEqual(presentationSource.snapshot().decoderGeneration, 12)

        lifecycle.drawableSize = PixelSize(width: 1_600, height: 1_200)
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        await waitUntil {
            guard let latest = mediaEnvironment.currentLifecycleApplications().last else {
                return false
            }
            return latest.lifecycleRevision > resumedLifecycleRevision
                && latest.directive == resumedDirective
        }
        let lifecycleApplications = mediaEnvironment.currentLifecycleApplications()
        let lifecycleRevisions = lifecycleApplications.map(\.lifecycleRevision)
        XCTAssertTrue(lifecycleApplications.allSatisfy {
            $0.sessionID == record.sessionID && $0.mediaGeneration == 1
        })
        XCTAssertTrue(zip(lifecycleRevisions, lifecycleRevisions.dropFirst()).allSatisfy {
            $0.0 < $0.1
        })
        let resizedCoordinate = try XCTUnwrap(model.renderState.coordinateSnapshot)
        XCTAssertGreaterThan(resizedCoordinate.revision, initialCoordinate.revision)
        XCTAssertEqual(resizedCoordinate.drawableSize, PixelSize(width: 1_600, height: 1_200))
        XCTAssertEqual(resizedCoordinate.resolvedVideo.videoRect.x, 0, accuracy: 0.000_001)
        XCTAssertEqual(resizedCoordinate.resolvedVideo.videoRect.y, 150, accuracy: 0.000_001)
        XCTAssertEqual(resizedCoordinate.resolvedVideo.videoRect.width, 1_600, accuracy: 0.000_001)
        XCTAssertEqual(resizedCoordinate.resolvedVideo.videoRect.height, 900, accuracy: 0.000_001)

        XCTAssertEqual(
            model.submitMacPlatformInput(.pointerMove(MacPointerSample(
                localPoint: RemotePoint(x: 400, y: 375),
                deltaX: 99,
                deltaY: -99,
                buttons: []
            ))),
            .accepted
        )
        await waitUntil { mediaEnvironment.currentSentInputApplications().count == 2 }
        let deliveredPointerApplication = try XCTUnwrap(
            mediaEnvironment.currentSentInputApplications().last
        )
        XCTAssertEqual(deliveredPointerApplication.sessionID, record.sessionID)
        XCTAssertEqual(deliveredPointerApplication.mediaGeneration, 1)
        XCTAssertEqual(
            deliveredPointerApplication.event,
            .pointer(.absoluteMove(
                point: RemotePoint(x: 960, y: 540),
                referenceSize: PixelSize(width: 3_840, height: 2_160),
                buttons: []
            ))
        )

        await model.stopStream()
        await launchTask.value

        let mediaSnapshot = await mediaEnvironment.snapshot()
        let presentationSnapshot = presentationSource.snapshot()
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(mediaEnvironment.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertNil(mediaSnapshot.sessionID)
        XCTAssertNil(mediaSnapshot.resourcePhase)
        XCTAssertEqual(mediaSnapshot.activeResourceCount, 0)
        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertFalse(model.isPlatformStreamLifecycleActive)
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)
        XCTAssertNil(model.macSessionInputSnapshot().generation)
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertNil(presentationSnapshot.sessionID)
        XCTAssertNil(presentationSnapshot.mediaGeneration)
        XCTAssertEqual(
            model.submitMacPlatformInput(keySample),
            .rejected(.inactiveGeneration)
        )

        let stoppedLifecycle = makePlatformLifecycle(
            isStreamActive: false,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 1_600, height: 1_200)
        )
        model.applyPlatformLifecycle(stoppedLifecycle)
        await Task.yield()
        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertNil(model.macSessionInputSnapshot().generation)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(mediaEnvironment.currentStoppedSessionIDs(), [record.sessionID])
    }

    func testMacPlatformInputFailsClosedWithoutCurrentDrawableGeometry() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 33,
                    key: Data(repeating: 0x33, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: .zero
        )
        model.applyPlatformLifecycle(lifecycle)

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        await waitUntil { model.macSessionInputSnapshot().generation != nil }
        XCTAssertFalse(model.macSessionInputSnapshot().acceptsInput)
        XCTAssertNil(model.renderState.coordinateSnapshot)
        XCTAssertEqual(
            model.submitMacPlatformInput(.pointerMove(MacPointerSample(
                localPoint: RemotePoint(x: 10, y: 10),
                deltaX: 0,
                deltaY: 0,
                buttons: []
            ))),
            .rejected(.admissionClosed)
        )
        XCTAssertEqual(mediaEnvironment.currentSentInputApplications(), [])

        await model.stopStream()
        await launchTask.value
    }

    func testLifecycleEffectFailureFailsSessionAndCleansInputGeneration() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(
            failsLifecycleApplication: true
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 34,
                    key: Data(repeating: 0x34, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        model.applyPlatformLifecycle(makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 2560, height: 1440)
        ))

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await launchTask.value

        XCTAssertFalse(model.hasActiveStreamSession)
        guard case .failed = model.session.phase else {
            return XCTFail("A current lifecycle effect failure must fail the session.")
        }
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertNil(model.macSessionInputSnapshot().generation)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(
            mediaEnvironment.currentStoppedSessionIDs(),
            [record.sessionID]
        )
    }

    func testUnavailablePairingPreservesHostState() async throws {
        let hostRepository = InMemoryHostRepository()
        let hostManager = HostLibraryManager(
            repository: hostRepository,
            serverInfoClient: StubServerInfoClient()
        )
        let catalogManager = AppCatalogManager(
            appListClient: StubAppListClient(),
            artworkCache: InMemoryArtworkCache()
        )
        let streamCoordinator = StreamSessionCoordinator(launchClient: StubStreamLaunchClient())
        let identityProvisioner = ControlledIdentityProvisioner()
        let model = AppModel(
            hostLibraryManager: hostManager,
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: catalogManager,
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: streamCoordinator,
            runtimeProviders: .unavailable,
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientIdentityProvisioner: identityProvisioner,
            clientUniqueID: "test-client",
            remoteInputKey: RemoteInputKeyMaterial(
                keyID: 7,
                key: Data(repeating: 0xAA, count: 16)
            )
        )

        await model.addManualHost(name: nil, address: "moon.local")
        XCTAssertEqual(model.hosts.count, 1)
        XCTAssertEqual(model.selectedHost?.name, "Test Host")

        let host = try XCTUnwrap(model.selectedHost)
        await model.beginPairing(host: host)
        model.updatePairingPIN("1234", in: model.primaryWorkspaceReference)
        await model.submitPairingPIN()

        XCTAssertEqual(model.selectedHost?.pairingState, .unpaired)
        XCTAssertNil(model.selectedHost?.pinnedIdentity)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertTrue(model.pairingUI.message?.contains("unavailable") == true)
        XCTAssertEqual(model.pairingUI.actionMessage, ApplicationDiagnosticAction.updateBuild.label)
        XCTAssertEqual(model.diagnostics.latestActionableEvent?.category, .pairing)
        XCTAssertEqual(model.diagnostics.latestActionableEvent?.code, "pairing_provider_unavailable")
        let identityProvisioningStarted = await identityProvisioner.hasStarted()
        XCTAssertFalse(identityProvisioningStarted)
    }

    func testPersistedIdentityRestoresMoonlightProtocolIDForCatalogRequests() async throws {
        let identity = ClientIdentityMaterial(
            id: UUID(uuidString: "7C84A0AB-69D4-40AA-949D-4345BF5DD75B")!,
            certificateDER: Data([1, 2, 3]),
            privateKeyDER: Data([4, 5, 6]),
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let client = RecordingUniqueIDAppListClient()
        let host = MoonlightHost(
            name: "Test Host",
            address: "moon.local",
            pairingState: .paired,
            reachability: .online,
            pinnedIdentity: PinnedHostIdentity(
                certificateSHA256: "existing-cert",
                serverCertificateDER: Data([7, 8, 9]),
                pairedAt: Date(timeIntervalSince1970: 10)
            )
        )
        let model = AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(hosts: [host]),
                serverInfoClient: StubServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: client,
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(
                launchClient: StubStreamLaunchClient()
            ),
            runtimeProviders: .unavailable,
            clientIdentityStore: InMemoryClientIdentityStore(identity: identity),
            clientUniqueID: "preload-value"
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()

        let recordedUniqueIDs = await client.recordedUniqueIDs()
        XCTAssertEqual(recordedUniqueIDs, [identity.protocolUniqueID])
    }

    func testPairingUIConsumesProgressAndAuthenticatedCompletion() async throws {
        let host = makeUnpairedHost()
        let identity = makePairingIdentity()
        let provider = ControlledPairingProvider()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: FixedIdentityProvisioner(identity: identity)
        )

        await model.loadHosts()
        model.diagnostics.record(ApplicationDiagnosticFactory.pairingUnavailable)
        await model.beginPairing(host: host)

        XCTAssertEqual(model.pairingUI.stage, .waitingForPIN)
        XCTAssertFalse(model.pairingUI.isRunning)
        XCTAssertNotNil(model.pairingUI.attemptID)
        XCTAssertEqual(provider.currentRequestCount(), 0)
        XCTAssertNotEqual(model.diagnostics.latestActionableEvent?.category, .pairing)

        model.updatePairingPIN("1234", in: model.primaryWorkspaceReference)
        let submitTask = Task { await model.submitPairingPIN() }
        for _ in 0..<100 where provider.currentRequestCount() == 0 {
            await Task.yield()
        }
        let request = try XCTUnwrap(provider.latestRequest())
        XCTAssertEqual(request.host.id, host.id)
        XCTAssertEqual(request.pin, "1234")
        XCTAssertEqual(request.clientIdentity, identity)
        XCTAssertEqual(model.pairingUI.pin, "")
        XCTAssertEqual(model.session.phase, .pairing(pin: ""))
        XCTAssertFalse(model.diagnostics.events.contains { $0.message.contains("1234") })

        provider.yieldProgress(.verifyingServer, for: request)
        for _ in 0..<100 where model.pairingUI.stage != .verifyingServer {
            await Task.yield()
        }
        XCTAssertEqual(model.pairingUI.stage, .verifyingServer)
        XCTAssertTrue(model.pairingUI.message?.contains("Verifying") == true)

        model.diagnostics.record(ApplicationDiagnosticFactory.pairingUnavailable)
        provider.completeAuthenticated(request)
        await submitTask.value

        XCTAssertEqual(model.selectedHost?.pairingState, .paired)
        XCTAssertEqual(model.selectedHost?.pinnedIdentity?.serverCertificateDER, Data([0x30, 0x01, 0x02]))
        XCTAssertEqual(model.pairingUI.stage, .paired)
        XCTAssertFalse(model.pairingUI.isRunning)
        XCTAssertNil(model.pairingUI.attemptID)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertNotEqual(model.diagnostics.latestActionableEvent?.category, .pairing)
        XCTAssertFalse(model.diagnostics.events.contains { $0.message.contains("1234") })
    }

    func testPairingCancellationInvalidatesLateCompletion() async throws {
        let host = makeUnpairedHost()
        let provider = ControlledPairingProvider()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: FixedIdentityProvisioner(identity: makePairingIdentity())
        )

        await model.loadHosts()
        await model.beginPairing(host: host)
        model.updatePairingPIN("4321", in: model.primaryWorkspaceReference)
        let submitTask = Task { await model.submitPairingPIN() }
        for _ in 0..<100 where provider.currentRequestCount() == 0 {
            await Task.yield()
        }
        let request = try XCTUnwrap(provider.latestRequest())

        await model.cancelPairing()
        provider.completeAuthenticated(request)
        await submitTask.value

        XCTAssertEqual(provider.currentCancelledAttemptIDs(), [request.attemptID])
        XCTAssertEqual(model.selectedHost?.pairingState, .unpaired)
        XCTAssertNil(model.selectedHost?.pinnedIdentity)
        XCTAssertEqual(model.pairingUI.stage, .cancelled)
        XCTAssertNil(model.pairingUI.attemptID)
        XCTAssertEqual(model.session.phase, .disconnected)
    }

    func testPairingFailsClosedForInvalidOrIncompleteCompletion() async throws {
        for completion in [ControlledPairingProvider.Completion.invalid, .incomplete] {
            let host = makeUnpairedHost()
            let provider = ControlledPairingProvider()
            let model = makePairingModel(
                host: host,
                provider: provider,
                identityProvisioner: FixedIdentityProvisioner(identity: makePairingIdentity())
            )

            await model.loadHosts()
            await model.beginPairing(host: host)
            model.updatePairingPIN("2468", in: model.primaryWorkspaceReference)
            let submitTask = Task { await model.submitPairingPIN() }
            for _ in 0..<100 where provider.currentRequestCount() == 0 {
                await Task.yield()
            }
            let request = try XCTUnwrap(provider.latestRequest())
            provider.finish(request, completion: completion)
            await submitTask.value

            XCTAssertEqual(model.selectedHost?.pairingState, .unpaired)
            XCTAssertNil(model.selectedHost?.pinnedIdentity)
            XCTAssertEqual(model.pairingUI.stage, .failed)
            XCTAssertNil(model.pairingUI.attemptID)
            guard case .failed = model.session.phase else {
                return XCTFail("Invalid or incomplete pairing completion must fail closed.")
            }
            XCTAssertEqual(model.pairingUI.actionMessage, ApplicationDiagnosticAction.pairAgain.label)
            XCTAssertEqual(model.diagnostics.latestActionableEvent?.category, .pairing)
            XCTAssertEqual(model.diagnostics.latestActionableEvent?.code, "pairing_failed")
        }
    }

    func testPairingFailureProgressDoesNotExposeProviderMessage() async throws {
        let host = makeUnpairedHost()
        let provider = ControlledPairingProvider()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: FixedIdentityProvisioner(identity: makePairingIdentity())
        )

        await model.loadHosts()
        await model.beginPairing(host: host)
        model.updatePairingPIN("9753", in: model.primaryWorkspaceReference)
        let submitTask = Task { await model.submitPairingPIN() }
        for _ in 0..<100 where provider.currentRequestCount() == 0 {
            await Task.yield()
        }
        let request = try XCTUnwrap(provider.latestRequest())
        provider.yieldFailure(
            PairingFailure(
                code: .invalidPIN,
                message: "PIN=9753 Authorization: Basic private-value"
            ),
            for: request
        )
        await submitTask.value

        XCTAssertEqual(model.pairingUI.message, "The host rejected the pairing request.")
        XCTAssertEqual(model.pairingUI.actionMessage, ApplicationDiagnosticAction.verifyPIN.label)
        XCTAssertFalse(model.diagnostics.events.contains { $0.message.contains("9753") })
        XCTAssertFalse(model.diagnostics.events.contains {
            $0.message.localizedCaseInsensitiveContains("authorization")
        })
    }

    func testPairingIdentityFailureStopsBeforeRuntimeRequest() async throws {
        let host = makeUnpairedHost()
        let provider = ControlledPairingProvider()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: FailingIdentityProvisioner()
        )

        await model.loadHosts()
        await model.beginPairing(host: host)

        XCTAssertEqual(provider.currentRequestCount(), 0)
        XCTAssertEqual(model.selectedHost?.pairingState, .unpaired)
        XCTAssertEqual(model.pairingUI.stage, .failed)
        XCTAssertNil(model.pairingUI.attemptID)
        XCTAssertTrue(model.pairingUI.message?.contains("identity") == true)
    }

    func testPairingRejectsNonASCIIPINBeforeRuntimeRequest() async throws {
        let host = makeUnpairedHost()
        let provider = ControlledPairingProvider()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: FixedIdentityProvisioner(identity: makePairingIdentity())
        )

        await model.loadHosts()
        await model.beginPairing(host: host)
        model.updatePairingPIN("１２３４", in: model.primaryWorkspaceReference)

        XCTAssertFalse(model.isPairingPINValid)
        await model.submitPairingPIN()
        XCTAssertEqual(provider.currentRequestCount(), 0)
        XCTAssertEqual(model.pairingUI.stage, .waitingForPIN)
    }

    func testPairingCancellationWhileIdentityIsPendingIgnoresLateIdentity() async throws {
        let host = makeUnpairedHost()
        let provider = ControlledPairingProvider()
        let identityProvisioner = ControlledIdentityProvisioner()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: identityProvisioner
        )

        await model.loadHosts()
        let beginTask = Task { await model.beginPairing(host: host) }
        for _ in 0..<100 {
            if await identityProvisioner.hasStarted() { break }
            await Task.yield()
        }
        let identityPreparationStarted = await identityProvisioner.hasStarted()
        XCTAssertTrue(identityPreparationStarted)

        await model.cancelPairing()
        await identityProvisioner.complete(with: makePairingIdentity())
        await beginTask.value

        XCTAssertEqual(model.selectedHost?.pairingState, .unpaired)
        XCTAssertEqual(model.pairingUI.stage, .cancelled)
        XCTAssertNil(model.pairingUI.attemptID)
        XCTAssertEqual(provider.currentRequestCount(), 0)
    }

    func testDuplicatePairingSubmissionDoesNotStartAnotherRuntimeRequest() async throws {
        let host = makeUnpairedHost()
        let provider = ControlledPairingProvider()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: FixedIdentityProvisioner(identity: makePairingIdentity())
        )

        await model.loadHosts()
        await model.beginPairing(host: host)
        model.updatePairingPIN("1357", in: model.primaryWorkspaceReference)
        let firstSubmission = Task { await model.submitPairingPIN() }
        for _ in 0..<100 where provider.currentRequestCount() == 0 {
            await Task.yield()
        }
        let request = try XCTUnwrap(provider.latestRequest())

        model.updatePairingPIN("2468", in: model.primaryWorkspaceReference)
        await model.submitPairingPIN()
        XCTAssertEqual(provider.currentRequestCount(), 1)

        provider.completeAuthenticated(request)
        await firstSubmission.value
        XCTAssertEqual(model.pairingUI.stage, .paired)
    }

    func testMismatchedPairingProgressFailsClosedAndCancelsProvider() async throws {
        let host = makeUnpairedHost()
        let provider = ControlledPairingProvider()
        let model = makePairingModel(
            host: host,
            provider: provider,
            identityProvisioner: FixedIdentityProvisioner(identity: makePairingIdentity())
        )

        await model.loadHosts()
        await model.beginPairing(host: host)
        model.updatePairingPIN("8642", in: model.primaryWorkspaceReference)
        let submission = Task { await model.submitPairingPIN() }
        for _ in 0..<100 where provider.currentRequestCount() == 0 {
            await Task.yield()
        }
        let request = try XCTUnwrap(provider.latestRequest())

        provider.yieldProgress(
            .verifyingServer,
            for: request,
            hostID: UUID(uuidString: "7E42A4CF-4619-435F-B30E-133095E952C8")!
        )
        await submission.value

        XCTAssertEqual(model.selectedHost?.pairingState, .unpaired)
        XCTAssertEqual(model.pairingUI.stage, .failed)
        XCTAssertNil(model.pairingUI.attemptID)
        XCTAssertEqual(provider.currentCancelledAttemptIDs(), [request.attemptID])
    }

    func testCancellingWithoutPairingAttemptPreservesActiveSessionState() async {
        let model = AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(),
                serverInfoClient: StubServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: StubAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(launchClient: StubStreamLaunchClient()),
            runtimeProviders: .unavailable,
            clientIdentityStore: InMemoryClientIdentityStore()
        )
        model.session.phase = .streaming

        await model.cancelPairing()

        XCTAssertEqual(model.session.phase, .streaming)
        XCTAssertEqual(model.pairingUI, PairingUIState())
    }

    func testUnavailableTransportDoesNotLaunchOrReportStreaming() async throws {
        let host = MoonlightHost(
            id: UUID(uuidString: "2A666A9A-2C77-451B-B2B1-73E697AE7D5C")!,
            name: "Test Host",
            address: "moon.local",
            pairingState: .paired,
            reachability: .online,
            pinnedIdentity: PinnedHostIdentity(
                certificateSHA256: "existing-cert",
                serverCertificateDER: Data([1, 2, 3]),
                pairedAt: Date(timeIntervalSince1970: 10)
            )
        )
        let hostManager = HostLibraryManager(
            repository: InMemoryHostRepository(hosts: [host]),
            serverInfoClient: StubServerInfoClient()
        )
        let catalogManager = AppCatalogManager(
            appListClient: StubAppListClient(),
            artworkCache: InMemoryArtworkCache()
        )
        let launchClient = StubStreamLaunchClient()
        let model = AppModel(
            hostLibraryManager: hostManager,
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: catalogManager,
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(launchClient: launchClient),
            runtimeProviders: .unavailable,
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientUniqueID: "test-client",
            remoteInputKey: RemoteInputKeyMaterial(
                keyID: 7,
                key: Data(repeating: 0xAA, count: 16)
            )
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        XCTAssertEqual(model.selectedApps.map(\.name), ["Desktop", "Game"])
        XCTAssertEqual(model.selectedApp?.name, "Desktop")

        await model.launchSelectedApp()
        XCTAssertFalse(model.session.isStreaming)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertEqual(model.navigationSelection, .library)
        let issue = try XCTUnwrap(model.streamProductIssue)
        XCTAssertEqual(issue.code, .streamUnavailable)
        XCTAssertEqual(issue.action?.kind, .updateBuild)
        XCTAssertEqual(
            issue.action?.scope,
            .workspace(model.primaryWorkspaceReference)
        )
        XCTAssertEqual(model.diagnostics.latestActionableEvent?.category, .transport)
        XCTAssertEqual(model.diagnostics.latestActionableEvent?.code, "stream_provider_unavailable")
        let launchCount = await launchClient.currentLaunchCount()
        XCTAssertEqual(launchCount, 0)
    }

    func testEveryMissingRequiredStreamProviderStopsBeforeAnySessionSideEffect() async throws {
        for missingProvider in MissingStreamProvider.allCases {
            let controlProvider = ControlledSessionControlProvider()
            let mediaEnvironment = ControlledSessionMediaEnvironment()
            let launchClient = StubStreamLaunchClient()
            let keyGenerator = ScriptedInputKeyGenerator(results: [])
            let production = ProductionRuntimeProviderFactory.makeDefault()
            let inventory = RuntimeProviderInventory(
                pairing: production.pairing,
                sessionControl: missingProvider == .sessionControl ? nil : controlProvider,
                videoReceive: missingProvider == .videoReceive
                    ? nil
                    : AvailabilityVideoReceiveProvider(),
                audioReceive: missingProvider == .audioReceive
                    ? nil
                    : AvailabilityAudioReceiveProvider(),
                remoteInput: missingProvider == .remoteInput ? nil : production.remoteInput
            )
            let model = makeLaunchReadyModel(
                sessionControlProvider: controlProvider,
                sessionMediaEnvironment: mediaEnvironment,
                launchClient: launchClient,
                remoteInputKeyGenerator: keyGenerator,
                runtimeProviders: inventory
            )

            await model.loadInitialState()
            await model.refreshAppsForSelectedHost()
            let commands = model.sessionCommandState(
                in: model.primaryWorkspaceReference
            )
            XCTAssertEqual(commands.phase, .idle)
            XCTAssertEqual(
                commands.launch,
                .unavailable(.providersUnavailable),
                "\(missingProvider) must close launch from the actual inventory."
            )
            await model.launchSelectedApp()

            XCTAssertFalse(
                model.isStreamTransportAvailable,
                "\(missingProvider) must keep stream availability fail closed."
            )
            XCTAssertFalse(model.hasActiveStreamSession)
            XCTAssertFalse(model.session.isStreaming)
            XCTAssertEqual(model.session.phase, .disconnected)
            XCTAssertEqual(model.navigationSelection, .library)
            XCTAssertEqual(model.renderState.policy, .idle)
            let issue = try XCTUnwrap(model.streamProductIssue)
            XCTAssertEqual(issue.code, .streamUnavailable)
            XCTAssertEqual(issue.action?.kind, .updateBuild)
            XCTAssertEqual(
                issue.action?.scope,
                .workspace(model.primaryWorkspaceReference)
            )
            XCTAssertEqual(model.diagnostics.latestActionableEvent?.code, "stream_provider_unavailable")
            XCTAssertEqual(keyGenerator.currentGenerationCount(), 0)
            XCTAssertEqual(controlProvider.currentStartRecords().count, 0)
            XCTAssertEqual(mediaEnvironment.currentStartRecords().count, 0)
            let launchCount = await launchClient.currentLaunchCount()
            XCTAssertEqual(launchCount, 0)
        }
    }

    func testLaunchSelectionIssueUsesCheckedWorkspaceAction() async throws {
        let provider = ControlledSessionControlProvider()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let workspace = model.primaryWorkspaceReference
        model.selectedHostID = nil
        model.navigationSelection = .stream

        await model.launchSelectedApp(in: workspace)

        let issue = try XCTUnwrap(model.streamProductIssue(in: workspace))
        XCTAssertEqual(issue.code, .launchSelectionRequired)
        let action = try XCTUnwrap(issue.action)
        XCTAssertEqual(action.kind, .chooseHostAndApp)
        XCTAssertEqual(action.scope, .workspace(workspace))
        XCTAssertTrue(model.canPerformProductAction(action))
        XCTAssertTrue(provider.currentStartRecords().isEmpty)

        let result = await model.performProductAction(action)
        XCTAssertEqual(result, .performed)
        XCTAssertEqual(model.navigationSelection, .library)
        XCTAssertNil(model.streamProductIssue(in: workspace))
    }

    func testSessionUIRequiresNegotiationAndEveryRequiredChannel() async throws {
        let provider = ControlledSessionControlProvider()
        let launchClient = StubStreamLaunchClient()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: launchClient,
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 7,
                    key: Data(repeating: 0xAA, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)

        XCTAssertTrue(model.hasActiveStreamSession)
        XCTAssertEqual(model.navigationSelection, .stream)
        XCTAssertFalse(model.session.isStreaming)
        let launchCount = await launchClient.currentLaunchCount()
        XCTAssertEqual(launchCount, 0)

        provider.yield(.launchAccepted(makeSessionLaunchResponse()), sessionID: record.sessionID)
        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(.channelsReady(.control), sessionID: record.sessionID)
        await waitUntil { model.session.phase.label.contains("Connecting") }
        XCTAssertFalse(model.session.isStreaming)

        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey
            )),
            sessionID: record.sessionID
        )
        provider.yield(.channelsReady(.all), sessionID: record.sessionID)
        await waitUntil { model.session.isStreaming }

        XCTAssertTrue(model.session.isStreaming)
        XCTAssertEqual(model.renderState.policy, .active)
        XCTAssertFalse(model.streamLaunchUI.isLaunching)

        provider.yield(
            .terminated(reason: "The host ended the streaming session."),
            sessionID: record.sessionID
        )
        provider.finish(sessionID: record.sessionID)
        await launchTask.value

        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertFalse(model.streamLaunchUI.isLaunching)
        XCTAssertNil(model.session.activeHostID)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [])
        XCTAssertTrue(model.diagnostics.events.contains {
            $0.message == "The host ended the streaming session."
        })
    }

    func testOldInputReleaseCannotPublishIntoReplacementGeneration() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 1,
                    key: Data(repeating: 0x11, count: 16)
                )),
                .success(RemoteInputKeyMaterial(
                    keyID: 2,
                    key: Data(repeating: 0x22, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let firstLaunch = Task { await model.launchSelectedApp() }
        let firstRecord = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: firstRecord)
        await waitUntil { model.session.isStreaming }

        mediaEnvironment.blockNextRelease()
        let staleRelease = Task { try await model.releaseRemoteInput() }
        await waitUntil { mediaEnvironment.hasBlockedRelease() }
        await model.stopStream()
        await firstLaunch.value

        let replacementLaunch = Task { await model.launchSelectedApp() }
        await waitUntil { provider.currentStartRecords().count == 2 }
        let replacementRecord = try XCTUnwrap(provider.currentStartRecords().last)
        driveSessionToStreaming(provider, record: replacementRecord)
        await waitUntil { model.session.isStreaming }
        let diagnosticCount = model.diagnostics.events.count

        mediaEnvironment.resumeBlockedRelease()
        do {
            try await staleRelease.value
            XCTFail("A release owned by the stopped generation must fail closed.")
        } catch {
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .inactiveSession
            )
        }
        XCTAssertEqual(model.diagnostics.events.count, diagnosticCount)
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().last?.mediaGeneration,
            1
        )

        await model.stopStream()
        await replacementLaunch.value
    }

    func testReconnectLeavesStreamingUntilFreshNegotiationAndFullReadiness() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(automaticallyReady: false)
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 11,
                    key: Data(repeating: 0xEE, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let drawableSize = PixelSize(width: 3_840, height: 2_160)
        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: drawableSize
        )
        _ = lifecycle.updateSurface(
            displayID: "display-a",
            headroom: DisplayHeadroom(
                potential: 4,
                current: 2.5,
                reference: 1
            ),
            drawableSize: drawableSize
        )
        model.applyPlatformLifecycle(lifecycle)
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { mediaEnvironment.currentStartRecords().count == 1 }
        mediaEnvironment.yieldReadiness(
            [.video, .audio, .input],
            sessionID: record.sessionID
        )
        await waitUntil { model.session.isStreaming }

        let hdrMetadata = VideoColorMetadata.hdr10VideoRange()
        provider.yield(
            .videoColorMetadata(hdrMetadata),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.negotiatedVideoColorMetadata == hdrMetadata
                && model.renderState.decodedVideoPresentationContract == nil
        }
        mediaEnvironment.yieldVideoPresentation(
            .decoderStarted(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 1
                ),
                contract: StreamVideoDecoderPresentationContract(
                    decoderGeneration: 1,
                    colorMetadata: hdrMetadata
                )
            ),
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldVideoPresentation(
            .decodedFrame(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: 1,
                    revision: 2
                ),
                contract: StreamVideoDecodedPresentationContract(
                    decoderGeneration: 1,
                    colorMetadata: hdrMetadata,
                    decodedLayout: HDRDecodedPixelBufferLayout(
                        pixelFormat: kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
                        width: 3_840,
                        height: 2_160,
                        planes: [
                            HDRDecodedPlaneDimensions(width: 3_840, height: 2_160),
                            HDRDecodedPlaneDimensions(width: 1_920, height: 1_080)
                        ]
                    )
                )
            ),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.hdrRenderResolution.configuration?.outputMode == .edr
        }

        mediaEnvironment.blockNextStop()
        provider.yield(
            .reconnecting(attempt: 1, reason: "Control channel interrupted."),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.hasBlockedStop() }
        XCTAssertEqual(
            model.renderState.hdrRenderResolution,
            .closed(.inactiveSession)
        )
        await waitUntil { model.session.phase.label.contains("Reconnecting") }
        XCTAssertFalse(model.session.isStreaming)
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertTrue(model.hasActiveStreamSession)
        mediaEnvironment.resumeBlockedStop()

        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey
            )),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.currentStartRecords().count == 2 }
        mediaEnvironment.yieldReadiness(
            [.video, .input],
            sessionID: record.sessionID
        )
        provider.yield(.channelsReady(.control), sessionID: record.sessionID)
        for _ in 0..<100 {
            await Task.yield()
        }
        XCTAssertTrue(model.session.phase.label.contains("Reconnecting"))
        XCTAssertFalse(model.session.isStreaming)
        XCTAssertEqual(model.renderState.policy, .idle)

        mediaEnvironment.yieldReadiness(
            [.video, .audio, .input],
            sessionID: record.sessionID
        )
        await waitUntil { model.session.isStreaming }
        XCTAssertEqual(model.renderState.policy, .active)

        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launchTask.value
        XCTAssertEqual(model.session.phase, .disconnected)
    }

    func testVisionWindowObservationAppliesSceneReplacementAndDetach()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .visionOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 70,
                    key: Data(repeating: 0x70, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        let current = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 1,
            revision: 1
        )
        model.receiveTVVisionGeometryUpdate(current)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 3
                && model.visionInputCaptureEnabled
        }
        var applications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(applications[0].action, .activate)
        XCTAssertEqual(applications[0].ownership.platform, .visionOS)
        guard case let .scene(currentScene) = applications[1].action else {
            return XCTFail("Expected current visionOS scene application")
        }
        XCTAssertEqual(currentScene, current)
        guard case let .input(currentInput, currentLeases) =
                applications[2].action else {
            return XCTFail("Expected current visionOS input application")
        }
        XCTAssertEqual(currentInput.platform, .visionOS)
        XCTAssertEqual(currentInput.focusEligibility, .eligible)
        XCTAssertTrue(currentLeases.isEmpty)

        let replacement = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 2,
            revision: 1
        )
        model.receiveTVVisionGeometryUpdate(replacement)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 6
        }
        applications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(applications[3].action, .activate)
        XCTAssertEqual(
            applications[3].ownership.presentationGeneration.rawValue,
            2
        )
        guard case let .scene(replacementScene) = applications[4].action else {
            return XCTFail("Expected replacement visionOS scene application")
        }
        XCTAssertEqual(replacementScene, replacement)
        guard case let .input(replacementInput, replacementLeases) =
                applications[5].action else {
            return XCTFail("Expected replacement visionOS input application")
        }
        XCTAssertEqual(replacementInput.platform, .visionOS)
        XCTAssertEqual(replacementInput.focusEligibility, .eligible)
        XCTAssertTrue(replacementLeases.isEmpty)

        let stale = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 1,
            revision: 2
        )
        model.receiveTVVisionGeometryUpdate(stale)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count,
            6
        )

        let detached = try makeTVVisionClosedGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 2,
            revision: 2
        )
        model.receiveTVVisionGeometryUpdate(detached)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 7
        }
        applications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        guard case let .scene(detachedScene) = applications[6].action else {
            return XCTFail("Expected detached visionOS scene application")
        }
        XCTAssertEqual(detachedScene, detached)
        XCTAssertNil(detachedScene.binding)
        XCTAssertEqual(applications.filter { application in
            if case .input = application.action { return true }
            return false
        }.count, 2)

        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launchTask.value
        XCTAssertEqual(model.session.phase, .disconnected)
    }

    func testVisionResizePreservesCaptureUntilReplacementAndTeardown()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .visionOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 75,
                    key: Data(repeating: 0x75, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        let initial = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 1,
            revision: 1,
            viewSize: PixelSize(width: 640, height: 360)
        )
        model.receiveTVVisionGeometryUpdate(initial)
        await waitUntil { model.visionInputCaptureEnabled }

        let surface1 = try TVVisionGeneration(
            domain: .surface,
            rawValue: 1
        )
        let heldKey = RemoteInputEvent.keyboard(KeyboardInputEvent(
            rawKeyCode: 0x52,
            characters: "r",
            isDown: true,
            modifiers: [],
            isRepeat: false
        ))
        let heldEvent = try VisionSurfaceInputEvent(
            surfaceGeneration: surface1,
            path: .keyboard,
            event: heldKey
        )
        XCTAssertEqual(
            model.receiveVisionSurfaceInputEvent(heldEvent),
            .captured
        )
        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count == 1
        }

        for (revision, size, mode) in [
            (UInt64(2), PixelSize(width: 800, height: 600), RenderScaleMode.fit),
            (UInt64(3), PixelSize(width: 1_024, height: 720), .fill)
        ] {
            let resized = try makeTVVisionActiveGeometryUpdate(
                platform: .visionOS,
                surfaceGeneration: 1,
                revision: revision,
                viewSize: size,
                mode: mode
            )
            model.receiveTVVisionGeometryUpdate(resized)
            await waitUntil {
                let latestScene = mediaEnvironment
                    .currentTVVisionPlatformPresentationApplications()
                    .last { application in
                        if case .scene = application.action { return true }
                        return false
                    }
                return latestScene?.action == .scene(resized)
                    && model.visionInputCaptureEnabled
            }
            XCTAssertTrue(
                mediaEnvironment.currentReleasedInputApplications().isEmpty
            )
            XCTAssertEqual(
                model.visionInputOwnershipState?.surfaceGeneration,
                surface1
            )
        }

        let reserved = try VisionSurfaceSystemInteractionEvent(
            surfaceGeneration: surface1,
            decision: VisionSystemInteractionDecision.resolve(.volume)
        )
        model.receiveVisionSystemInteractionEvent(reserved)
        XCTAssertEqual(
            model.visionSystemInteractionDecisionState,
            .resolve(.volume)
        )
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().map(\.event),
            [heldKey]
        )

        let replacement = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 2,
            revision: 1,
            viewSize: PixelSize(width: 900, height: 700)
        )
        model.receiveTVVisionGeometryUpdate(replacement)
        await waitUntil {
            mediaEnvironment.currentReleasedInputApplications().count == 1
                && model.visionInputCaptureEnabled
        }
        XCTAssertEqual(
            model.receiveVisionSurfaceInputEvent(heldEvent),
            .local
        )
        XCTAssertNil(model.visionSystemInteractionDecisionState)
        XCTAssertEqual(
            model.visionInputOwnershipState?.surfaceGeneration.rawValue,
            2
        )

        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launchTask.value
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertNil(model.visionInputOwnershipState)
        XCTAssertFalse(model.visionInputCaptureEnabled)
        XCTAssertEqual(model.visionLocalNavigationRestoreReason, .stopped)
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            2
        )
    }

    func testVisionInputRequiresCurrentFocusedSurfaceAndMatchingControllerLease()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .visionOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 71,
                    key: Data(repeating: 0x71, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        let currentGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 1,
            revision: 1
        )
        model.receiveTVVisionGeometryUpdate(currentGeometry)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 3
        }
        await waitUntil { model.visionInputCaptureEnabled }

        let firstKey = RemoteInputEvent.keyboard(KeyboardInputEvent(
            rawKeyCode: 0x41,
            characters: "a",
            isDown: true,
            modifiers: [],
            isRepeat: false
        ))
        let secondKey = RemoteInputEvent.keyboard(KeyboardInputEvent(
            rawKeyCode: 0x42,
            characters: "b",
            isDown: true,
            modifiers: [],
            isRepeat: false
        ))
        let currentSurface = try TVVisionGeneration(
            domain: .surface,
            rawValue: 1
        )
        let inputGeneration = try TVVisionGeneration(
            domain: .input,
            rawValue: 1
        )
        let currentSystemInteraction = try VisionSurfaceSystemInteractionEvent(
            surfaceGeneration: currentSurface,
            decision: VisionSystemInteractionDecision.resolve(.volume)
        )
        model.receiveVisionSystemInteractionEvent(currentSystemInteraction)
        XCTAssertEqual(
            model.visionSystemInteractionDecisionState,
            .resolve(.volume)
        )
        XCTAssertTrue(mediaEnvironment.currentSentInputApplications().isEmpty)
        let firstEvent = try VisionSurfaceInputEvent(
            surfaceGeneration: currentSurface,
            path: .keyboard,
            event: firstKey
        )
        let secondEvent = try VisionSurfaceInputEvent(
            surfaceGeneration: currentSurface,
            path: .keyboard,
            event: secondKey
        )

        mediaEnvironment.blockNextInputSend()
        XCTAssertEqual(model.receiveVisionSurfaceInputEvent(firstEvent), .captured)
        await waitUntil { mediaEnvironment.hasBlockedInputSend() }
        XCTAssertEqual(model.receiveVisionSurfaceInputEvent(secondEvent), .captured)

        let replacementGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 2,
            revision: 1
        )
        model.receiveTVVisionGeometryUpdate(replacementGeometry)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 6
        }
        XCTAssertTrue(model.visionInputReleasePending)
        XCTAssertFalse(model.visionInputCaptureEnabled)
        XCTAssertTrue(
            mediaEnvironment.currentReleasedInputApplications().isEmpty
        )
        XCTAssertNil(model.visionSystemInteractionDecisionState)
        model.receiveVisionSystemInteractionEvent(currentSystemInteraction)
        XCTAssertNil(model.visionSystemInteractionDecisionState)
        let replacementSurface = try TVVisionGeneration(
            domain: .surface,
            rawValue: 2
        )
        let replacementSystemInteraction =
            try VisionSurfaceSystemInteractionEvent(
                surfaceGeneration: replacementSurface,
                decision: VisionSystemInteractionDecision.resolve(.capture)
            )
        model.receiveVisionSystemInteractionEvent(replacementSystemInteraction)
        XCTAssertNil(model.visionSystemInteractionDecisionState)
        mediaEnvironment.resumeBlockedInputSend()
        await waitUntil {
            mediaEnvironment.currentReleasedInputApplications().count == 1
                && model.visionInputCaptureEnabled
        }
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().map(\.event),
            [firstKey]
        )
        XCTAssertNil(model.visionLocalNavigationRestoreReason)
        XCTAssertEqual(
            model.visionInputReleaseEffects,
            [
                .closeAdmission(inputGeneration: inputGeneration),
                .cancelSystemInteractionObservers,
                .cancelInputMonitors([
                    .indirectPointer,
                    .keyboard,
                    .pointer
                ]),
                .awaitHeldInputRelease(inputGeneration: inputGeneration),
                .releaseSurfaceLease(surfaceGeneration: currentSurface),
                .restoreLocalNavigation(.replacing)
            ]
        )
        model.receiveVisionSystemInteractionEvent(replacementSystemInteraction)
        XCTAssertEqual(
            model.visionSystemInteractionDecisionState,
            .resolve(.capture)
        )
        for _ in 0..<50 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().map(\.event),
            [firstKey]
        )
        XCTAssertEqual(model.receiveVisionSurfaceInputEvent(secondEvent), .local)

        let replacementEvent = try VisionSurfaceInputEvent(
            surfaceGeneration: replacementSurface,
            path: .keyboard,
            event: secondKey
        )
        XCTAssertEqual(
            model.receiveVisionSurfaceInputEvent(replacementEvent),
            .captured
        )
        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count == 2
        }

        let hiddenGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 2,
            revision: 2,
            isVisible: false
        )
        model.receiveTVVisionGeometryUpdate(hiddenGeometry)
        XCTAssertEqual(model.receiveVisionSurfaceInputEvent(replacementEvent), .local)
        await waitUntil {
            mediaEnvironment.currentReleasedInputApplications().count == 2
                && model.visionLocalNavigationRestoreReason == .notFocused
        }
        XCTAssertFalse(model.visionInputCaptureEnabled)

        let inactiveGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 2,
            revision: 3,
            activity: .inactive
        )
        model.receiveTVVisionGeometryUpdate(inactiveGeometry)
        XCTAssertEqual(model.receiveVisionSurfaceInputEvent(replacementEvent), .local)
        await waitUntil {
            model.visionLocalNavigationRestoreReason == .sceneInactive
        }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            2
        )

        let unfocusedGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 2,
            revision: 4,
            isFocusEligible: false
        )
        model.receiveTVVisionGeometryUpdate(unfocusedGeometry)
        XCTAssertEqual(model.receiveVisionSurfaceInputEvent(replacementEvent), .local)
        await waitUntil {
            model.visionLocalNavigationRestoreReason == .notFocused
        }

        let restoredGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 2,
            revision: 5
        )
        model.receiveTVVisionGeometryUpdate(restoredGeometry)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().last?.action
                == .scene(restoredGeometry)
                && model.visionInputCaptureEnabled
        }

        var tvRuntime = try TVGameControllerSlotRuntime(
            inputGeneration: inputGeneration
        )
        let tvRoster = try tvRuntime.connect(
            token: TVGameControllerDeviceToken(10),
            profile: .extendedGamepad,
            capabilities: [],
            supportedButtons: .standard,
            completeState: TVGameControllerCompleteState(buttons: [.a])
        )
        model.receiveTVGameControllerRoster(tvRoster)
        for _ in 0..<50 { await Task.yield() }
        XCTAssertNil(model.tvControllerRosterState)
        XCTAssertEqual(mediaEnvironment.currentSentInputApplications().count, 2)

        var visionRuntime = try TVGameControllerSlotRuntime(
            inputGeneration: inputGeneration,
            platform: .visionOS
        )
        let visionRoster = try visionRuntime.connect(
            token: TVGameControllerDeviceToken(11),
            profile: .extendedGamepad,
            capabilities: [],
            supportedButtons: .standard,
            completeState: TVGameControllerCompleteState(buttons: [.b])
        )
        model.receiveTVGameControllerRoster(visionRoster)
        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count == 3
                && model.tvControllerRoutedRosterState == visionRoster
        }
        XCTAssertEqual(model.tvControllerRosterState, visionRoster)
        XCTAssertTrue(visionRoster.controllers.allSatisfy {
            $0.lease.platform == .visionOS
        })
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().last?.event,
            .controllerRoster(TVGameControllerRosterRouter.reconcile(
                previous: nil,
                current: visionRoster
            ))
        )

        mediaEnvironment.blockNextInputSend()
        let updatedVisionRoster = try visionRuntime.update(
            token: TVGameControllerDeviceToken(11),
            completeState: TVGameControllerCompleteState(buttons: [.a])
        )
        model.receiveTVGameControllerRoster(updatedVisionRoster)
        await waitUntil { mediaEnvironment.hasBlockedInputSend() }
        let controllerFocusLost = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 2,
            revision: 6,
            isFocusEligible: false
        )
        model.receiveTVVisionGeometryUpdate(controllerFocusLost)
        XCTAssertTrue(model.visionInputReleasePending)
        XCTAssertFalse(model.visionInputCaptureEnabled)
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            2
        )
        mediaEnvironment.resumeBlockedInputSend()
        await waitUntil {
            mediaEnvironment.currentReleasedInputApplications().count == 3
                && model.visionLocalNavigationRestoreReason == .notFocused
        }
        XCTAssertNil(model.tvControllerRosterState)
        XCTAssertNil(model.tvControllerRoutedRosterState)

        let controllerRestored = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 2,
            revision: 7
        )
        model.receiveTVVisionGeometryUpdate(controllerRestored)
        await waitUntil { model.visionInputCaptureEnabled }

        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launchTask.value
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertNil(model.visionSystemInteractionDecisionState)
        XCTAssertNil(model.visionInputOwnershipState)
        XCTAssertFalse(model.visionInputCaptureEnabled)
        XCTAssertEqual(model.visionLocalNavigationRestoreReason, .stopped)
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            4
        )
        XCTAssertTrue(
            mediaEnvironment.currentReleasedInputApplications().allSatisfy {
                $0.mediaGeneration == 1
            }
        )
    }

    func testVisionInputProviderFailureRunsTerminalReleaseBeforeLocalRestore()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(
            failsInputSend: true
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .visionOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 72,
                    key: Data(repeating: 0x72, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        let geometry = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 1,
            revision: 1
        )
        model.receiveTVVisionGeometryUpdate(geometry)
        await waitUntil { model.visionInputCaptureEnabled }
        let surface = try TVVisionGeneration(
            domain: .surface,
            rawValue: 1
        )
        let inputGeneration = try TVVisionGeneration(
            domain: .input,
            rawValue: 1
        )
        let event = try VisionSurfaceInputEvent(
            surfaceGeneration: surface,
            path: .keyboard,
            event: .keyboard(KeyboardInputEvent(
                rawKeyCode: 0x41,
                characters: "a",
                isDown: true,
                modifiers: [],
                isRepeat: false
            ))
        )

        XCTAssertEqual(model.receiveVisionSurfaceInputEvent(event), .captured)
        await waitUntil {
            mediaEnvironment.currentReleasedInputApplications().count == 1
                && model.visionLocalNavigationRestoreReason == .inputUnavailable
        }
        XCTAssertTrue(mediaEnvironment.currentSentInputApplications().isEmpty)
        XCTAssertFalse(model.visionInputCaptureEnabled)
        XCTAssertFalse(model.visionInputReleasePending)
        XCTAssertEqual(
            model.visionInputReleaseEffects,
            [
                .closeAdmission(inputGeneration: inputGeneration),
                .cancelSystemInteractionObservers,
                .cancelInputMonitors([
                    .indirectPointer,
                    .keyboard,
                    .pointer
                ]),
                .awaitHeldInputRelease(inputGeneration: inputGeneration),
                .releaseSurfaceLease(surfaceGeneration: surface),
                .restoreLocalNavigation(.inputUnavailable)
            ]
        )
        XCTAssertEqual(model.receiveVisionSurfaceInputEvent(event), .local)

        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launchTask.value
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            1
        )
    }

    func testVisionReleaseFailureLatchesCaptureWithoutSecondRelease()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .visionOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 74,
                    key: Data(repeating: 0x74, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        let geometry = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 1,
            revision: 1
        )
        model.receiveTVVisionGeometryUpdate(geometry)
        await waitUntil { model.visionInputCaptureEnabled }

        mediaEnvironment.failNextRelease()
        let focusLost = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 1,
            revision: 2,
            isFocusEligible: false
        )
        model.receiveTVVisionGeometryUpdate(focusLost)
        await waitUntil {
            mediaEnvironment.currentReleasedInputApplications().count == 1
                && model.visionLocalNavigationRestoreReason == .inputUnavailable
        }
        XCTAssertFalse(model.visionInputCaptureEnabled)
        XCTAssertFalse(model.visionInputReleasePending)

        let lateEligibleGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 1,
            revision: 3
        )
        model.receiveTVVisionGeometryUpdate(lateEligibleGeometry)
        for _ in 0..<50 { await Task.yield() }
        XCTAssertFalse(model.visionInputCaptureEnabled)
        XCTAssertEqual(
            model.visionLocalNavigationRestoreReason,
            .inputUnavailable
        )
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            1
        )

        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launchTask.value
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            1
        )
    }

    func testTVVisionPresentationAcceptsCurrentGenerationAndClearsOnReconnectAndRemoteTermination()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 71,
                    key: Data(repeating: 0x71, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        model.setTVStreamWorkspaceVisible(true)
        model.setTVStreamOverlayVisible(false)
        XCTAssertFalse(model.tvStreamOverlayVisible)

        let currentGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 1,
            revision: 1
        )
        let currentDisplay = try makeTVOSDisplaySnapshot(
            revision: 1,
            displayGeneration: 1,
            current: 2,
            potential: 4
        )
        model.receiveTVVisionGeometryUpdate(currentGeometry)
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: currentGeometry.surfaceGeneration,
            snapshot: currentDisplay
        ))
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 4
        }
        let geometryApplications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(geometryApplications[0].action, .activate)
        guard case .scene = geometryApplications[1].action,
              case .input = geometryApplications[2].action,
              case let .display(appliedDisplay) = geometryApplications[3].action else {
            return XCTFail("Expected geometry, input, then display after activation.")
        }
        XCTAssertEqual(appliedDisplay, currentDisplay)

        let currentAudio = try makeTVOSAudioRouteSnapshot(
            revision: 1,
            graphGeneration: 1,
            presentationMode: .headTracked
        )
        let current = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 2,
            display: currentDisplay,
            audioRoute: currentAudio
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            current,
            sessionID: record.sessionID
        )
        await waitUntil { model.tvVisionPlatformPresentationState == current }
        XCTAssertEqual(
            model.tvVisionPlatformPresentationState?.snapshot.audioRoute,
            current.snapshot.audioRoute
        )
        XCTAssertEqual(
            model.tvVisionPlatformPresentationSnapshot,
            current.snapshot.presentation
        )
        XCTAssertEqual(model.renderState.displaySnapshot?.headroom.current, 2)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)
        XCTAssertEqual(
            model.tvVisionPlatformPresentationSnapshot?
                .audioRoute.spatialPresentationMode,
            .headTracked
        )

        let regressive = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 1
        )
        let wrongPlatform = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .visionOS,
            presentationGeneration: 1,
            sequence: 9
        )
        let wrongGeneration = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 2,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 9
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            regressive,
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            wrongPlatform,
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            wrongGeneration,
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.tvVisionPlatformPresentationState, current)

        mediaEnvironment.blockNextStop()
        provider.yield(
            .reconnecting(attempt: 1, reason: "Control channel interrupted."),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.hasBlockedStop() }
        XCTAssertNil(model.tvVisionPlatformPresentationState)
        XCTAssertNil(model.tvVisionPlatformPresentationSnapshot)
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)
        XCTAssertTrue(model.tvStreamOverlayVisible)
        let reconnectApplications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(reconnectApplications.last?.action, .stop(.reconnect))
        mediaEnvironment.resumeBlockedStop()

        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey
            )),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.currentStartRecords().count == 2 }
        provider.yield(.channelsReady(.control), sessionID: record.sessionID)
        await waitUntil { model.session.isStreaming }
        model.setTVStreamOverlayVisible(false)
        XCTAssertFalse(model.tvStreamOverlayVisible)

        model.receiveTVVisionGeometryUpdate(currentGeometry)
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: currentGeometry.surfaceGeneration,
            snapshot: currentDisplay
        ))
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count
                == reconnectApplications.count + 4
        }
        let replayApplications = Array(
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications()
                .suffix(4)
        )
        XCTAssertEqual(
            replayApplications.map(\.ownership.mediaGeneration),
            [2, 2, 2, 2]
        )
        XCTAssertEqual(replayApplications[0].action, .activate)
        guard case let .scene(replayedGeometry) = replayApplications[1].action,
              case .input = replayApplications[2].action,
              case let .display(replayedDisplay) = replayApplications[3].action else {
            return XCTFail("Expected reconnect replay to restore scene, input, and display.")
        }
        XCTAssertEqual(replayedGeometry, currentGeometry)
        XCTAssertEqual(replayedDisplay, currentDisplay)

        let replacementAudio = try makeTVOSAudioRouteSnapshot(
            revision: 1,
            graphGeneration: 2,
            presentationMode: .fixedSpatial
        )
        let replacement = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 2,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 1,
            display: currentDisplay,
            audioRoute: replacementAudio
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            current,
            sessionID: record.sessionID
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            replacement,
            sessionID: record.sessionID
        )
        await waitUntil {
            model.tvVisionPlatformPresentationState == replacement
        }
        XCTAssertEqual(
            model.tvVisionPlatformPresentationState?.snapshot.audioRoute,
            replacement.snapshot.audioRoute
        )
        XCTAssertEqual(
            model.tvVisionPlatformPresentationSnapshot,
            replacement.snapshot.presentation
        )
        XCTAssertEqual(model.renderState.displaySnapshot?.headroom.current, 2)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)
        XCTAssertEqual(
            model.tvVisionPlatformPresentationSnapshot?
                .audioRoute.routeGeneration.rawValue,
            2
        )
        XCTAssertEqual(
            model.tvVisionPlatformPresentationSnapshot?
                .audioRoute.spatialPresentationMode,
            .fixedSpatial
        )

        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launchTask.value
        XCTAssertNil(model.tvVisionPlatformPresentationState)
        XCTAssertNil(model.tvVisionPlatformPresentationSnapshot)
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)
        XCTAssertFalse(model.tvStreamOverlayVisible)
        XCTAssertEqual(
            model.workspaceState(for: model.primaryWorkspaceReference)?
                .presentation.streamOverlay,
            .hidden
        )
        let terminatedApplications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(
            terminatedApplications.last?.action,
            .stop(.remoteTermination)
        )
    }

    func testVisionWindowedPresentationReportsOnlyCurrentOwnership()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .visionOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 76,
                    key: Data(repeating: 0x76, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionActiveGeometryUpdate(
                platform: .visionOS,
                surfaceGeneration: 1,
                revision: 1
            )
        )
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 3
        }
        let first = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .visionOS,
            presentationGeneration: 1,
            sequence: 2,
            visionSurfaceGeneration: 1
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            first,
            sessionID: record.sessionID
        )
        await waitUntil {
            model.visionWindowedPresentationState
                == first.snapshot.visionWindowedPresentation
        }
        XCTAssertEqual(
            model.visionStreamControlPresentationState.window,
            .unavailable
        )
        XCTAssertEqual(
            model.visionStreamControlPresentationState.input,
            .unavailable
        )
        XCTAssertEqual(model.visionWindowedPresentationState?.mode, .windowed)
        XCTAssertEqual(
            model.visionWindowedPresentationState?
                .unavailableFeatures.map(\.feature),
            VisionUnavailablePresentationFeature.allCases.sorted()
        )

        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionActiveGeometryUpdate(
                platform: .visionOS,
                surfaceGeneration: 2,
                revision: 1
            )
        )
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 6
                && model.visionWindowedPresentationState == nil
        }
        XCTAssertEqual(
            model.visionStreamControlPresentationState.window,
            .unavailable
        )
        XCTAssertEqual(
            model.visionStreamControlPresentationState.input,
            .unavailable
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            first,
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.visionWindowedPresentationState)
        XCTAssertEqual(
            model.visionStreamControlPresentationState.window,
            .unavailable
        )

        let replacement = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .visionOS,
            presentationGeneration: 2,
            sequence: 2,
            visionSurfaceGeneration: 2
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            replacement,
            sessionID: record.sessionID
        )
        await waitUntil {
            model.visionWindowedPresentationState
                == replacement.snapshot.visionWindowedPresentation
        }
        XCTAssertEqual(
            model.visionStreamControlPresentationState.window,
            .unavailable
        )
        XCTAssertEqual(
            model.visionWindowedPresentationState?.surfaceGeneration.rawValue,
            2
        )

        let detached = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .visionOS,
            presentationGeneration: 2,
            sequence: 3
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            detached,
            sessionID: record.sessionID
        )
        await waitUntil { model.visionWindowedPresentationState == nil }
        XCTAssertEqual(
            model.visionStreamControlPresentationState.window,
            .unavailable
        )

        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launchTask.value
        XCTAssertNil(model.visionWindowedPresentationState)
    }

    func testVisionPresentationCoordinatesCurrentMediaReconnectAndRemoteStop()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .visionOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 82,
                    key: Data(repeating: 0x82, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        let geometry = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 1,
            revision: 1
        )
        let display = try makeVisionOSDisplaySnapshot(
            revision: 1,
            displayGeneration: 1
        )
        let audio = try makeVisionOSAudioRouteSnapshot(
            revision: 1,
            graphGeneration: 1,
            presentationMode: .headTracked
        )
        model.receiveTVVisionGeometryUpdate(geometry)
        model.receiveTVVisionDisplayHDREvent(.snapshot(
            surfaceGeneration: geometry.surfaceGeneration,
            snapshot: display
        ))
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 4
        }
        let applications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(applications[0].action, .activate)
        guard case let .scene(appliedGeometry) = applications[1].action,
              case let .input(input, leases) = applications[2].action,
              case let .display(appliedDisplay) = applications[3].action else {
            return XCTFail(
                "Expected visionOS activation, scene, input, then display."
            )
        }
        XCTAssertEqual(appliedGeometry, geometry)
        XCTAssertEqual(input.platform, .visionOS)
        XCTAssertEqual(input.focusEligibility, .eligible)
        XCTAssertTrue(leases.isEmpty)
        XCTAssertEqual(appliedDisplay, display)

        let ownership = applications[0].ownership
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            diagnosticCapacity: 4
        )
        _ = await coordinator.activate(ownership)
        _ = await coordinator.applyScene(geometry, ownership: ownership)
        _ = await coordinator.applyInput(
            input,
            controllerLeases: [],
            ownership: ownership
        )
        _ = await coordinator.applyDisplay(display, ownership: ownership)
        _ = await coordinator.applyAudioRoute(audio, ownership: ownership)
        let videoOwnership = StreamVideoPresentationDeliveryOwnership(
            sessionID: record.sessionID,
            mediaGeneration: ownership.mediaGeneration,
            revision: 1
        )
        _ = await coordinator.receiveVideo(
            .decoderStarted(
                ownership: videoOwnership,
                contract: StreamVideoDecoderPresentationContract(
                    decoderGeneration: 7,
                    colorMetadata: .rec709VideoRange()
                )
            ),
            ownership: ownership
        )
        _ = await coordinator.receiveVideo(
            .decodedFrame(
                ownership: StreamVideoPresentationDeliveryOwnership(
                    sessionID: record.sessionID,
                    mediaGeneration: ownership.mediaGeneration,
                    revision: 2
                ),
                frame: try makeHDRApplicationFrame(
                    generation: 7,
                    frameID: 42,
                    metadata: .rec709VideoRange()
                )
            ),
            ownership: ownership
        )
        let optionalCoordinatedSnapshot = await coordinator.snapshot()
        let coordinatedSnapshot = try XCTUnwrap(optionalCoordinatedSnapshot)
        let coordinated = SessionTVVisionPlatformPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: ownership.mediaGeneration,
            snapshot: coordinatedSnapshot
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            coordinated,
            sessionID: record.sessionID
        )
        await waitUntil {
            model.tvVisionPlatformPresentationState == coordinated
        }
        XCTAssertEqual(
            model.visionStreamControlPresentationState.window,
            .visible
        )
        XCTAssertEqual(
            model.visionStreamControlPresentationState.input,
            .captured(
                capabilityCount: coordinatedSnapshot.presentation?
                    .inputCapabilities.supported.count ?? 0
            )
        )
        XCTAssertEqual(
            model.visionStreamControlPresentationState.immersive,
            .windowedOnly(.stage18WindowedOnly)
        )
        XCTAssertEqual(model.visionWindowedPresentationState?.mode, .windowed)
        XCTAssertEqual(
            model.tvVisionPlatformPresentationSnapshot?.inputCapabilities,
            coordinatedSnapshot.presentation?.inputCapabilities
        )
        XCTAssertEqual(
            model.tvVisionPlatformPresentationSnapshot?
                .audioRoute.platformStrategy,
            .visionOutputExperience
        )
        XCTAssertEqual(
            model.tvVisionPlatformPresentationSnapshot?
                .audioRoute.headTrackingCapability,
            .intendedSpatialExperience
        )
        XCTAssertEqual(
            model.tvVisionPlatformPresentationSnapshot?
                .audioRoute.spatialPresentationMode,
            .headTracked
        )
        XCTAssertEqual(
            model.tvVisionPlatformPresentationSnapshot?
                .audioRoute.routeGeneration.rawValue,
            1
        )
        XCTAssertEqual(
            model.tvVisionPlatformPresentationSnapshot?
                .display.visionOSHDRCapabilityResolution?.fallbackReason,
            .headroomUnavailable
        )
        XCTAssertEqual(
            model.tvVisionDisplayHDRFallbackReason,
            .headroomUnavailable
        )
        XCTAssertEqual(model.renderState.displaySnapshot?.headroom, DisplayHeadroom())
        guard case .frameReady(decoderGeneration: 7, frameID: 42) =
                coordinatedSnapshot.video.phase else {
            return XCTFail("Expected the current decoded visionOS frame.")
        }
        XCTAssertLessThanOrEqual(coordinatedSnapshot.diagnostics.count, 4)
        XCTAssertTrue(coordinatedSnapshot.diagnostics.contains {
            $0.classification == .displayFallback(.headroomUnavailable)
        })
        await waitUntil {
            model.diagnostics.events.contains {
                $0.code == "platform_visionos_display_fallback"
            }
        }
        let platformDiagnostic = try XCTUnwrap(
            model.diagnostics.events.last {
                $0.code == "platform_visionos_display_fallback"
            }
        )
        XCTAssertEqual(
            platformDiagnostic.message,
            "Vision Pro is using HDR-to-SDR fallback."
        )
        XCTAssertFalse(platformDiagnostic.message.contains(record.sessionID.uuidString))
        XCTAssertFalse(platformDiagnostic.code.contains(String(ownership.mediaGeneration)))

        mediaEnvironment.blockNextStop()
        provider.yield(
            .reconnecting(attempt: 1, reason: "Control channel interrupted."),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.hasBlockedStop() }
        XCTAssertNil(model.tvVisionPlatformPresentationState)
        XCTAssertNil(model.visionWindowedPresentationState)
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvVisionDisplayHDRFallbackReason)
        XCTAssertFalse(model.visionInputCaptureEnabled)
        XCTAssertEqual(
            model.visionStreamControlPresentationState.window,
            .unavailable
        )
        XCTAssertEqual(
            model.visionStreamControlPresentationState.input,
            .unavailable
        )
        let reconnectApplications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(reconnectApplications.last?.action, .stop(.reconnect))
        mediaEnvironment.resumeBlockedStop()

        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey
            )),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.currentStartRecords().count == 2 }
        provider.yield(.channelsReady(.control), sessionID: record.sessionID)
        await waitUntil { model.session.isStreaming }

        model.receiveTVVisionGeometryUpdate(geometry)
        model.receiveTVVisionDisplayHDREvent(.snapshot(
            surfaceGeneration: geometry.surfaceGeneration,
            snapshot: display
        ))
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count
                == reconnectApplications.count + 4
        }
        let replay = Array(mediaEnvironment
            .currentTVVisionPlatformPresentationApplications().suffix(4))
        XCTAssertEqual(replay.map(\.ownership.mediaGeneration), [2, 2, 2, 2])
        XCTAssertEqual(replay[0].action, .activate)
        guard case .scene = replay[1].action,
              case .input = replay[2].action,
              case .display = replay[3].action else {
            return XCTFail("Expected current visionOS reconnect replay.")
        }
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            coordinated,
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.tvVisionPlatformPresentationState)

        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launchTask.value
        XCTAssertNil(model.tvVisionPlatformPresentationState)
        XCTAssertNil(model.visionWindowedPresentationState)
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvVisionDisplayHDRFallbackReason)
        XCTAssertFalse(model.visionInputCaptureEnabled)
        XCTAssertEqual(
            model.visionStreamControlPresentationState.window,
            .unavailable
        )
        XCTAssertEqual(
            model.visionStreamControlPresentationState.input,
            .unavailable
        )
        XCTAssertEqual(
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().last?.action,
            .stop(.remoteTermination)
        )
    }

    func testVisionPresentationClearsAndAppliesLocalStop() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .visionOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 83,
                    key: Data(repeating: 0x83, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionActiveGeometryUpdate(
                platform: .visionOS,
                surfaceGeneration: 1,
                revision: 1
            )
        )
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 3
                && model.visionInputCaptureEnabled
        }

        await model.stopStream()
        await launchTask.value

        XCTAssertNil(model.tvVisionPlatformPresentationState)
        XCTAssertNil(model.visionWindowedPresentationState)
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvVisionDisplayHDRFallbackReason)
        XCTAssertFalse(model.visionInputCaptureEnabled)
        XCTAssertEqual(
            model.visionStreamControlPresentationState.window,
            .unavailable
        )
        XCTAssertEqual(
            model.visionStreamControlPresentationState.input,
            .unavailable
        )
        XCTAssertEqual(
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().last?.action,
            .stop(.localStop)
        )
    }

    func testTVVisionPresentationClearsAndAppliesLocalStop() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 72,
                    key: Data(repeating: 0x72, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        let current = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 1,
            display: makeTVOSDisplaySnapshot(
                revision: 1,
                displayGeneration: 1,
                current: 2,
                potential: 4
            ),
            audioRoute: makeTVOSAudioRouteSnapshot(
                revision: 1,
                graphGeneration: 1,
                presentationMode: .fixedSpatial
            )
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            current,
            sessionID: record.sessionID
        )
        await waitUntil { model.tvVisionPlatformPresentationState == current }
        XCTAssertEqual(
            model.tvVisionPlatformPresentationSnapshot,
            current.snapshot.presentation
        )

        await model.stopStream()
        await launchTask.value

        XCTAssertNil(model.tvVisionPlatformPresentationState)
        XCTAssertNil(model.tvVisionPlatformPresentationSnapshot)
        XCTAssertEqual(model.tvStreamControlPresentationState.focus, .unavailable)
        XCTAssertEqual(model.tvStreamControlPresentationState.capture, .unavailable)
        XCTAssertEqual(model.tvStreamControlPresentationState.render, .inactive)
        XCTAssertEqual(
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().last?.action,
            .stop(.localStop)
        )
    }

    func testTVVisionGeometryQueueKeepsLatestReplacementAndRejectsLateSurface()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(
            blocksFirstTVVisionActivation: true
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 75,
                    key: Data(repeating: 0x75, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionClosedGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 1
            )
        )
        await waitUntil { mediaEnvironment.hasBlockedTVVisionActivation() }
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionClosedGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 2
            )
        )
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionClosedGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 2,
                revision: 1
            )
        )
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionClosedGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 3
            )
        )
        let lateFirstSurface = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 99
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            lateFirstSurface,
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.tvVisionPlatformPresentationState)

        mediaEnvironment.resumeBlockedTVVisionActivation()
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 3
        }
        let applications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(
            applications.map(\.ownership.presentationGeneration.rawValue),
            [1, 2, 2]
        )
        XCTAssertEqual(applications[0].action, .activate)
        XCTAssertEqual(applications[1].action, .activate)
        guard case let .scene(replacementScene) = applications[2].action else {
            return XCTFail("Expected only the replacement scene to be applied.")
        }
        XCTAssertEqual(replacementScene.surfaceGeneration.rawValue, 2)
        XCTAssertEqual(replacementScene.revision.rawValue, 1)

        let replacement = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 2,
            sequence: 1
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            replacement,
            sessionID: record.sessionID
        )
        await waitUntil { model.tvVisionPlatformPresentationState == replacement }
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            lateFirstSurface,
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.tvVisionPlatformPresentationState, replacement)

        await model.stopStream()
        await launchTask.value
    }

    func testTVOSDisplayHDRAppliesInGeometryOrderAndFailsClosedAcrossReplacement()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 80,
                    key: Data(repeating: 0x80, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        let firstGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 1,
            revision: 1
        )
        let direct = try makeTVOSDisplaySnapshot(
            revision: 1,
            displayGeneration: 1,
            current: 2.5,
            potential: 4
        )
        model.receiveTVVisionGeometryUpdate(firstGeometry)
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: firstGeometry.surfaceGeneration,
            snapshot: direct
        ))
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 4
        }
        let firstApplications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(firstApplications[0].action, .activate)
        guard case .scene = firstApplications[1].action,
              case .input = firstApplications[2].action,
              case let .display(appliedDirect) = firstApplications[3].action else {
            return XCTFail("Display must apply after scene and input geometry state.")
        }
        XCTAssertEqual(appliedDirect, direct)

        let directState = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 4,
            display: direct
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            directState,
            sessionID: record.sessionID
        )
        await waitUntil {
            model.renderState.displaySnapshot?.headroom.current == 2.5
        }
        XCTAssertEqual(model.renderState.headroom.potential, 4)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)

        let fallback = try makeTVOSDisplaySnapshot(
            revision: 2,
            displayGeneration: 1,
            current: .nan,
            potential: 4
        )
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: firstGeometry.surfaceGeneration,
            snapshot: fallback
        ))
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 5
        }
        let fallbackState = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 5,
            display: fallback
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            fallbackState,
            sessionID: record.sessionID
        )
        await waitUntil {
            model.tvOSDisplayHDRFallbackReason == .invalidHeadroom
        }
        XCTAssertEqual(model.renderState.displaySnapshot?.headroom, DisplayHeadroom())
        XCTAssertEqual(model.renderState.headroom, DisplayHeadroom())

        let applicationCount = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications().count
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: firstGeometry.surfaceGeneration,
            snapshot: direct
        ))
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: try TVVisionGeneration(
                domain: .surface,
                rawValue: 2
            ),
            snapshot: try makeTVOSDisplaySnapshot(
                revision: 3,
                displayGeneration: 1,
                current: 3,
                potential: 4
            )
        ))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment.currentTVVisionPlatformPresentationApplications().count,
            applicationCount
        )

        let replacementDisplay = try makeTVOSDisplaySnapshot(
            revision: 1,
            displayGeneration: 2,
            current: 3,
            potential: 4
        )
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: firstGeometry.surfaceGeneration,
            snapshot: replacementDisplay
        ))
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count
                == applicationCount + 1
        }
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: firstGeometry.surfaceGeneration,
            snapshot: try makeTVOSDisplaySnapshot(
                revision: 3,
                displayGeneration: 1,
                current: 3.5,
                potential: 4
            )
        ))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment.currentTVVisionPlatformPresentationApplications().count,
            applicationCount + 1
        )

        let replacementGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 2,
            revision: 1
        )
        model.receiveTVVisionGeometryUpdate(replacementGeometry)
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count
                == applicationCount + 4
        }
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            try makeTVVisionPresentationState(
                sessionID: record.sessionID,
                mediaGeneration: 1,
                platform: .tvOS,
                presentationGeneration: 1,
                sequence: 6,
                display: replacementDisplay
            ),
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: firstGeometry.surfaceGeneration,
            snapshot: replacementDisplay
        ))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment.currentTVVisionPlatformPresentationApplications().count,
            applicationCount + 4
        )

        model.receiveTVOSDisplayHDREvent(.revisionExhausted(
            surfaceGeneration: replacementGeometry.surfaceGeneration
        ))
        XCTAssertTrue(model.renderState.isDisplayRevisionExhausted)
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count
                == applicationCount + 5
        }
        XCTAssertEqual(
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().last?.action,
            .fail(.semanticRevisionExhausted)
        )
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: replacementGeometry.surfaceGeneration,
            snapshot: try makeTVOSDisplaySnapshot(
                revision: 1,
                displayGeneration: 3,
                current: 3,
                potential: 4
            )
        ))
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment.currentTVVisionPlatformPresentationApplications().count,
            applicationCount + 5
        )

        await model.stopStream()
        await launchTask.value
        XCTAssertFalse(model.renderState.isDisplayRevisionExhausted)
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)
    }

    func testTVOSDisplayApplicationFailureTerminatesCurrentPresentation()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(
            failsTVVisionDisplayApplication: true
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 81,
                    key: Data(repeating: 0x81, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        let geometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 1,
            revision: 1
        )
        model.receiveTVVisionGeometryUpdate(geometry)
        model.receiveTVOSDisplayHDREvent(.snapshot(
            surfaceGeneration: geometry.surfaceGeneration,
            snapshot: try makeTVOSDisplaySnapshot(
                revision: 1,
                displayGeneration: 1,
                current: 2.5,
                potential: 4
            )
        ))
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 5
        }
        let actions = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications().map(\.action)
        guard case .display = actions[3] else {
            return XCTFail("Expected the failing display application.")
        }
        XCTAssertEqual(actions[4], .fail(.actionFailed(.display)))
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvOSDisplayHDRFallbackReason)

        await model.stopStream()
        await launchTask.value
    }

    func testVisionDisplayApplicationFailureTerminatesCurrentPresentation()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(
            failsTVVisionDisplayApplication: true
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .visionOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 84,
                    key: Data(repeating: 0x84, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        let geometry = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 1,
            revision: 1
        )
        model.receiveTVVisionGeometryUpdate(geometry)
        model.receiveTVVisionDisplayHDREvent(.snapshot(
            surfaceGeneration: geometry.surfaceGeneration,
            snapshot: try makeVisionOSDisplaySnapshot(
                revision: 1,
                displayGeneration: 1
            )
        ))
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 5
        }
        let actions = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications().map(\.action)
        guard case .display = actions[3] else {
            return XCTFail("Expected the failing visionOS display application.")
        }
        XCTAssertEqual(actions[4], .fail(.actionFailed(.display)))
        XCTAssertNil(model.renderState.displaySnapshot)
        XCTAssertNil(model.tvVisionDisplayHDRFallbackReason)

        await model.stopStream()
        await launchTask.value
    }

    func testVisionDisplayReplaysAgainstLatestPendingGeometry() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(
            blocksFirstTVVisionActivation: true
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .visionOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 85,
                    key: Data(repeating: 0x85, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        let initialGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 1,
            revision: 1
        )
        let display = try makeVisionOSDisplaySnapshot(
            revision: 1,
            displayGeneration: 1
        )
        model.receiveTVVisionGeometryUpdate(initialGeometry)
        await waitUntil { mediaEnvironment.hasBlockedTVVisionActivation() }
        model.receiveTVVisionDisplayHDREvent(.snapshot(
            surfaceGeneration: initialGeometry.surfaceGeneration,
            snapshot: display
        ))
        let replacementGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 1,
            revision: 2
        )
        model.receiveTVVisionGeometryUpdate(replacementGeometry)

        mediaEnvironment.resumeBlockedTVVisionActivation()
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 4
        }
        let applications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(applications.map(\.action).first, .activate)
        guard case let .scene(appliedGeometry) = applications[1].action,
              case let .input(appliedInput, leases) = applications[2].action,
              case let .display(appliedDisplay) = applications[3].action else {
            return XCTFail(
                "Expected latest scene and input before replayed display."
            )
        }
        XCTAssertEqual(appliedGeometry, replacementGeometry)
        XCTAssertEqual(appliedInput.revision, replacementGeometry.revision)
        XCTAssertTrue(leases.isEmpty)
        XCTAssertEqual(appliedDisplay, display)

        await model.stopStream()
        await launchTask.value
    }

    func testTVRemoteSurfacePressesUseCurrentGeometryAndBalancedInput()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 76,
                    key: Data(repeating: 0x76, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        XCTAssertTrue(model.tvStreamOverlayVisible)
        model.setTVStreamWorkspaceVisible(true)

        let overlayGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 1,
            revision: 1
        )
        model.receiveTVVisionGeometryUpdate(overlayGeometry)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 3
        }
        let platformApplications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        XCTAssertEqual(platformApplications[0].action, .activate)
        guard case .scene = platformApplications[1].action else {
            return XCTFail("Expected scene before tvOS input admission.")
        }
        guard case let .input(input, leases) = platformApplications[2].action else {
            return XCTFail("Expected current tvOS input admission.")
        }
        XCTAssertEqual(
            input.supported,
            [.tvRemote, .extendedGamepad, .microGamepad]
        )
        XCTAssertEqual(
            input.focusEligibility,
            .ineligible(.overlayVisible)
        )
        XCTAssertTrue(leases.isEmpty)

        let surface = overlayGeometry.surfaceGeneration
        await waitUntil {
            model.tvRemoteSurfacePressDisposition(for: surface) == .local
        }
        model.setTVStreamOverlayVisible(false)
        XCTAssertFalse(model.tvStreamOverlayVisible)
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )

        let focusedGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 1,
            revision: 2
        )
        model.receiveTVVisionGeometryUpdate(focusedGeometry)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 5
        }
        let focusApplications = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications()
        guard case .scene = focusApplications[3].action else {
            return XCTFail("Expected refreshed scene before focus admission.")
        }
        guard case let .input(focusedInput, focusedLeases) =
                focusApplications[4].action else {
            return XCTFail("Expected fresh focused tvOS input admission.")
        }
        XCTAssertEqual(focusedInput.focusEligibility, .eligible)
        XCTAssertTrue(focusedLeases.isEmpty)

        var controllerRuntime = try TVGameControllerSlotRuntime(
            inputGeneration: focusedInput.inputGeneration
        )
        let firstControllerToken = try TVGameControllerDeviceToken(1)
        let controllerRoster = try controllerRuntime.connect(
            token: firstControllerToken,
            profile: .extendedGamepad,
            capabilities: [.analogTriggers, .rgbLED, .accelerometer],
            supportedButtons: .standard,
            completeState: TVGameControllerCompleteState(buttons: [.a])
        )
        model.receiveTVGameControllerRoster(controllerRoster)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 6
        }
        guard case let .input(rosterInput, rosterLeases) = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications().last?.action else {
            return XCTFail("Expected current controller roster input application.")
        }
        XCTAssertEqual(rosterInput, focusedInput)
        XCTAssertEqual(rosterLeases, controllerRoster.controllers.map(\.lease))
        XCTAssertEqual(model.tvControllerRosterState, controllerRoster)
        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count == 1
                && model.tvControllerRoutedRosterState == controllerRoster
        }
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().first?.event,
            .controllerRoster(TVGameControllerRosterRouter.reconcile(
                previous: nil,
                current: controllerRoster
            ))
        )
        XCTAssertEqual(model.tvControllerRoutedRosterState, controllerRoster)

        let lease = try XCTUnwrap(controllerRoster.controllers.first?.lease)
        let controllerID = TVGameControllerRoutingIdentity(lease: lease).rawValue
        mediaEnvironment.yieldFeedback(.led(ControllerLEDFeedback(
            controllerID: controllerID,
            red: 10,
            green: 20,
            blue: 30
        )), sessionID: record.sessionID)
        let feedbackRequest = try TVControllerFeedbackRequest(
            lease: lease,
            payload: .led(red: 10, green: 20, blue: 30)
        )
        await waitUntil {
            model.tvControllerFeedbackDecisionState == .apply(feedbackRequest)
        }

        model.receiveTVGameControllerMotion(try TVGameControllerMotionSample(
            lease: lease,
            type: .accelerometer,
            x: 1,
            y: 2,
            z: 3
        ))
        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count == 2
        }
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().last?.event,
            .controllerMotion(ControllerMotionInputEvent(
                controllerID: controllerID,
                type: .accelerometer,
                x: 1,
                y: 2,
                z: 3
            ))
        )

        mediaEnvironment.blockNextInputSend()
        _ = try controllerRuntime.disconnect(token: firstControllerToken)
        let secondControllerToken = try TVGameControllerDeviceToken(2)
        let secondRoster = try controllerRuntime.connect(
            token: secondControllerToken,
            profile: .extendedGamepad,
            capabilities: [.analogTriggers, .rgbLED, .accelerometer],
            supportedButtons: .standard,
            completeState: TVGameControllerCompleteState(buttons: [.b])
        )
        model.receiveTVGameControllerRoster(secondRoster)
        await waitUntil { mediaEnvironment.hasBlockedInputSend() }

        _ = try controllerRuntime.disconnect(token: secondControllerToken)
        let thirdRoster = try controllerRuntime.connect(
            token: TVGameControllerDeviceToken(3),
            profile: .extendedGamepad,
            capabilities: [.analogTriggers, .rgbLED, .accelerometer],
            supportedButtons: .standard,
            completeState: TVGameControllerCompleteState(buttons: [.x])
        )
        model.receiveTVGameControllerRoster(thirdRoster)
        mediaEnvironment.resumeBlockedInputSend()
        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count == 4
                && model.tvControllerRoutedRosterState == thirdRoster
        }
        let serializedRosters = mediaEnvironment.currentSentInputApplications()
        XCTAssertEqual(
            serializedRosters[2].event,
            .controllerRoster(TVGameControllerRosterRouter.reconcile(
                previous: controllerRoster,
                current: secondRoster
            ))
        )
        XCTAssertEqual(
            serializedRosters[3].event,
            .controllerRoster(TVGameControllerRosterRouter.reconcile(
                previous: secondRoster,
                current: thirdRoster
            ))
        )

        mediaEnvironment.yieldFeedback(.led(ControllerLEDFeedback(
            controllerID: controllerID,
            red: 1,
            green: 2,
            blue: 3
        )), sessionID: record.sessionID)
        await waitUntil {
            model.tvControllerFeedbackDecisionState == .unavailable(
                .controllerUnavailable
            )
        }
        let currentLease = try XCTUnwrap(thirdRoster.controllers.first?.lease)
        let currentControllerID = TVGameControllerRoutingIdentity(
            lease: currentLease
        ).rawValue
        let currentFeedbackRequest = try TVControllerFeedbackRequest(
            lease: currentLease,
            payload: .led(red: 4, green: 5, blue: 6)
        )
        mediaEnvironment.yieldFeedback(.led(ControllerLEDFeedback(
            controllerID: currentControllerID,
            red: 4,
            green: 5,
            blue: 6
        )), sessionID: record.sessionID)
        await waitUntil {
            model.tvControllerFeedbackDecisionState
                == .apply(currentFeedbackRequest)
        }

        model.receiveTVGameControllerMotion(try TVGameControllerMotionSample(
            lease: lease,
            type: .accelerometer,
            x: 7,
            y: 8,
            z: 9
        ))
        model.receiveTVGameControllerMotion(try TVGameControllerMotionSample(
            lease: currentLease,
            type: .accelerometer,
            x: 10,
            y: 11,
            z: 12
        ))
        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count == 5
        }
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().last?.event,
            .controllerMotion(ControllerMotionInputEvent(
                controllerID: currentControllerID,
                type: .accelerometer,
                x: 10,
                y: 11,
                z: 12
            ))
        )
        let controllerInputCount = mediaEnvironment
            .currentSentInputApplications().count

        for _ in 0..<100
        where model.tvRemoteSurfacePressDisposition(for: surface) != .captured {
            await Task.yield()
        }
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .captured,
            "pending=\(model.tvRemoteInputReleasePending) "
                + "overlay=\(model.tvStreamOverlayVisible) "
                + "applications=\(mediaEnvironment.currentTVVisionPlatformPresentationApplications().count)"
        )
        XCTAssertEqual(
            model.tvStreamControlPresentationState.focus,
            .streamSurface
        )
        XCTAssertEqual(model.tvStreamControlPresentationState.capture, .remote)
        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(surface, 1, .select, .began)
            ),
            .captured
        )
        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(surface, 1, .select, .ended)
            ),
            .captured
        )
        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(surface, 2, .playPause, .began)
            ),
            .captured
        )
        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(surface, 2, .playPause, .cancelled)
            ),
            .captured
        )
        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(surface, 3, .menu, .began)
            ),
            .local
        )
        let foreignSurface = try TVVisionGeneration(
            domain: .surface,
            rawValue: 2
        )
        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(foreignSurface, 1, .right, .began)
            ),
            .local
        )

        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count
                == controllerInputCount + 4
        }
        XCTAssertEqual(
            Array(mediaEnvironment.currentSentInputApplications().suffix(4))
                .map(\.event),
            [
                .tvRemote(TVRemoteInputEvent(button: .select, isDown: true)),
                .tvRemote(TVRemoteInputEvent(button: .select, isDown: false)),
                .tvRemote(TVRemoteInputEvent(button: .playPause, isDown: true)),
                .tvRemote(TVRemoteInputEvent(button: .playPause, isDown: false))
            ]
        )

        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(surface, 4, .right, .began)
            ),
            .captured
        )
        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count
                == controllerInputCount + 5
        }
        let nonOwnerWorkspace = try model.workspaceRegistry.create()
        let inputCountBeforeNonOwnerCommand = mediaEnvironment
            .currentSentInputApplications().count
        model.receiveTVRemoteReservedCommand(
            .backMenu,
            in: nonOwnerWorkspace
        )
        XCTAssertFalse(model.tvStreamOverlayVisible)
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .captured
        )
        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(surface, 40, .right, .began),
                in: nonOwnerWorkspace
            ),
            .local
        )
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().count,
            inputCountBeforeNonOwnerCommand
        )
        mediaEnvironment.blockNextRelease()
        model.receiveTVRemoteReservedCommand(
            .backMenu,
            in: model.primaryWorkspaceReference
        )
        XCTAssertFalse(model.tvStreamOverlayVisible)
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )
        await waitUntil { mediaEnvironment.hasBlockedRelease() }
        XCTAssertTrue(model.tvRemoteInputReleasePending)
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            1
        )
        model.receiveTVRemoteReservedCommand(.backMenu)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            1
        )
        mediaEnvironment.resumeBlockedRelease()
        await waitUntil {
            model.tvStreamOverlayVisible
                && !model.tvRemoteInputReleasePending
        }
        XCTAssertEqual(
            model.tvRemoteReservedCommandState,
            .handledLocally(
                command: .backMenu,
                disposition: .showOverlayOrExitCapture
            )
        )
        model.receiveTVRemoteReservedCommand(.unsupported)
        XCTAssertEqual(
            model.tvRemoteReservedCommandState,
            .unavailable(
                command: .unsupported,
                disposition: .ignoreLocally,
                reason: .unsupportedInteraction
            )
        )
        await waitUntil {
            mediaEnvironment.currentSentInputApplications().count
                == controllerInputCount + 6
        }
        XCTAssertEqual(
            Array(mediaEnvironment.currentSentInputApplications().suffix(2))
                .map(\.event),
            [
                .tvRemote(TVRemoteInputEvent(button: .right, isDown: true)),
                .tvRemote(TVRemoteInputEvent(button: .right, isDown: false))
            ]
        )
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )
        model.setTVStreamOverlayVisible(false)
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )
        let presentationCountBeforeFocusRestore = mediaEnvironment
            .currentTVVisionPlatformPresentationApplications().count
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionActiveGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 3
            )
        )
        for _ in 0..<100
        where model.tvRemoteSurfacePressDisposition(for: surface) != .captured {
            await Task.yield()
        }
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .captured,
            "pending=\(model.tvRemoteInputReleasePending) "
                + "overlay=\(model.tvStreamOverlayVisible) "
                + "applications=\(mediaEnvironment.currentTVVisionPlatformPresentationApplications().count)"
        )
        XCTAssertEqual(
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count,
            presentationCountBeforeFocusRestore + 2
        )

        model.navigationSelection = .settings
        XCTAssertFalse(model.tvStreamOverlayVisible)
        await waitUntil { model.tvStreamOverlayVisible }
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )
        model.navigationSelection = .stream
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )

        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionClosedGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 4
            )
        )
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count
                == presentationCountBeforeFocusRestore + 3
        }
        await waitUntil {
            model.tvRemoteSurfacePressDisposition(for: surface) == .local
        }
        XCTAssertEqual(
            model.receiveTVRemoteSurfacePressEvent(
                try makeTVRemoteSurfacePress(surface, 5, .up, .began)
            ),
            .local
        )

        model.setTVStreamOverlayVisible(false)
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionActiveGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 5
            )
        )
        await waitUntil {
            model.tvRemoteSurfacePressDisposition(for: surface) == .captured
        }

        let replacementGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 2,
            revision: 1
        )
        let replacementSurface = replacementGeometry.surfaceGeneration
        let releasesBeforeReplacement = mediaEnvironment
            .currentReleasedInputApplications().count
        mediaEnvironment.blockNextRelease()
        model.receiveTVVisionGeometryUpdate(replacementGeometry)
        await waitUntil { mediaEnvironment.hasBlockedRelease() }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            releasesBeforeReplacement + 1
        )
        XCTAssertTrue(model.tvRemoteInputReleasePending)
        XCTAssertFalse(model.tvStreamOverlayVisible)
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: replacementSurface),
            .local
        )
        model.receiveTVVisionGeometryUpdate(replacementGeometry)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            releasesBeforeReplacement + 1
        )
        mediaEnvironment.resumeBlockedRelease()
        await waitUntil {
            model.tvRemoteSurfacePressDisposition(for: replacementSurface)
                == .captured
                && !model.tvRemoteInputReleasePending
        }
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )
        XCTAssertFalse(model.tvStreamOverlayVisible)

        let sceneLoss = try makeTVVisionClosedGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 2,
            revision: 2
        )
        let releasesBeforeSceneLoss = mediaEnvironment
            .currentReleasedInputApplications().count
        mediaEnvironment.blockNextRelease()
        model.receiveTVVisionGeometryUpdate(sceneLoss)
        await waitUntil { mediaEnvironment.hasBlockedRelease() }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            releasesBeforeSceneLoss + 1
        )
        XCTAssertTrue(model.tvRemoteInputReleasePending)
        XCTAssertFalse(model.tvStreamOverlayVisible)
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: replacementSurface),
            .local
        )
        let inputCountBeforeStaleSceneCallbacks = mediaEnvironment
            .currentSentInputApplications().count
        model.receiveTVGameControllerRoster(controllerRoster)
        model.receiveTVGameControllerMotion(try TVGameControllerMotionSample(
            lease: lease,
            type: .accelerometer,
            x: 13,
            y: 14,
            z: 15
        ))
        model.receiveTVGameControllerMotion(try TVGameControllerMotionSample(
            lease: currentLease,
            type: .accelerometer,
            x: 16,
            y: 17,
            z: 18
        ))
        mediaEnvironment.yieldFeedback(.led(ControllerLEDFeedback(
            controllerID: currentControllerID,
            red: 7,
            green: 8,
            blue: 9
        )), sessionID: record.sessionID)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.tvControllerRosterState, thirdRoster)
        XCTAssertNil(model.tvControllerFeedbackDecisionState)
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().count,
            inputCountBeforeStaleSceneCallbacks
        )
        model.receiveTVVisionGeometryUpdate(sceneLoss)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            releasesBeforeSceneLoss + 1
        )
        mediaEnvironment.resumeBlockedRelease()
        await waitUntil {
            model.tvStreamOverlayVisible
                && !model.tvRemoteInputReleasePending
        }

        model.setTVStreamOverlayVisible(false)
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionActiveGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 2,
                revision: 3
            )
        )
        await waitUntil {
            model.tvRemoteSurfacePressDisposition(for: replacementSurface)
                == .captured
        }
        let releasesBeforeStop = mediaEnvironment
            .currentReleasedInputApplications().count
        mediaEnvironment.blockNextRelease()
        let stopTask = Task { await model.stopStream() }
        await waitUntil { mediaEnvironment.hasBlockedRelease() }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            releasesBeforeStop + 1
        )
        XCTAssertTrue(mediaEnvironment.currentStoppedSessionIDs().isEmpty)
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: replacementSurface),
            .local
        )
        mediaEnvironment.resumeBlockedRelease()
        await stopTask.value
        XCTAssertFalse(model.tvRemoteInputReleasePending)
        XCTAssertFalse(model.tvStreamOverlayVisible)
        XCTAssertEqual(
            model.workspaceState(for: model.primaryWorkspaceReference)?
                .presentation.streamOverlay,
            .hidden
        )
        XCTAssertEqual(model.tvStreamControlPresentationState.focus, .unavailable)
        XCTAssertEqual(model.tvStreamControlPresentationState.capture, .unavailable)
        XCTAssertEqual(model.tvStreamControlPresentationState.render, .inactive)
        XCTAssertNil(model.tvControllerRosterState)
        XCTAssertNil(model.tvControllerRoutedRosterState)
        XCTAssertNil(model.tvControllerFeedbackDecisionState)
        let inputCountAfterStop = mediaEnvironment
            .currentSentInputApplications().count
        model.receiveTVGameControllerRoster(thirdRoster)
        model.receiveTVGameControllerMotion(try TVGameControllerMotionSample(
            lease: currentLease,
            type: .accelerometer,
            x: 19,
            y: 20,
            z: 21
        ))
        mediaEnvironment.yieldFeedback(.led(ControllerLEDFeedback(
            controllerID: currentControllerID,
            red: 10,
            green: 11,
            blue: 12
        )), sessionID: record.sessionID)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.tvControllerRosterState)
        XCTAssertNil(model.tvControllerRoutedRosterState)
        XCTAssertNil(model.tvControllerFeedbackDecisionState)
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().count,
            inputCountAfterStop
        )
        await launchTask.value
    }

    func testTVVisionApplicationFailurePreservesConsumedTerminalStateUntilStop()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(
            blocksFailingTVVisionActivationAfterTerminalEvent: true
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 73,
                    key: Data(repeating: 0x73, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionClosedGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 1
            )
        )
        await waitUntil { mediaEnvironment.hasBlockedTVVisionActivation() }
        await waitUntil {
            model.tvVisionPlatformPresentationState?.snapshot.phase
                == .failed(.invalidComponent(.video))
        }
        let terminal = model.tvVisionPlatformPresentationState
        mediaEnvironment.resumeBlockedTVVisionActivation()
        for _ in 0..<20 { await Task.yield() }

        XCTAssertEqual(model.tvVisionPlatformPresentationState, terminal)
        XCTAssertNil(model.tvVisionPlatformPresentationSnapshot)

        await model.stopStream()
        await launchTask.value
        XCTAssertNil(model.tvVisionPlatformPresentationState)
    }

    func testTVRemoteProviderReleaseFailureRestoresLocalUIAndFailsClosed()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 77,
                    key: Data(repeating: 0x77, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        model.setTVStreamWorkspaceVisible(true)

        let initialGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .tvOS,
            surfaceGeneration: 1,
            revision: 1
        )
        let surface = initialGeometry.surfaceGeneration
        model.receiveTVVisionGeometryUpdate(initialGeometry)
        await waitUntil {
            mediaEnvironment
                .currentTVVisionPlatformPresentationApplications().count == 3
        }
        model.setTVStreamOverlayVisible(false)
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionActiveGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 2
            )
        )
        await waitUntil {
            model.tvRemoteSurfacePressDisposition(for: surface) == .captured
        }

        let releasesBeforeFailure = mediaEnvironment
            .currentReleasedInputApplications().count
        mediaEnvironment.failNextRelease()
        model.receiveTVRemoteReservedCommand(.backMenu)
        await waitUntil {
            model.tvStreamOverlayVisible
                && !model.tvRemoteInputReleasePending
        }
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications().count,
            releasesBeforeFailure + 1
        )
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )

        model.setTVStreamOverlayVisible(false)
        model.receiveTVVisionGeometryUpdate(
            try makeTVVisionActiveGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 3
            )
        )
        for _ in 0..<100 { await Task.yield() }
        XCTAssertEqual(
            model.tvRemoteSurfacePressDisposition(for: surface),
            .local
        )

        await model.stopStream()
        await launchTask.value
    }

    func testTVVisionMediaFailurePreservesOnlyTerminalBoundedState()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 74,
                    key: Data(repeating: 0x74, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        let terminal = try makeTVVisionPresentationState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            platform: .tvOS,
            presentationGeneration: 1,
            sequence: 2,
            phase: .stopped(.failure)
        )
        mediaEnvironment.yieldTVVisionPlatformPresentation(
            terminal,
            sessionID: record.sessionID
        )
        await waitUntil { model.tvVisionPlatformPresentationState == terminal }

        mediaEnvironment.finish(
            sessionID: record.sessionID,
            throwing: MediaEnvironmentApplicationTestError.failed
        )
        await launchTask.value

        guard case .failed = model.session.phase else {
            return XCTFail("A media environment failure must fail the session.")
        }
        XCTAssertEqual(model.tvVisionPlatformPresentationState, terminal)
        XCTAssertNil(model.tvVisionPlatformPresentationSnapshot)
        XCTAssertFalse(model.hasActiveStreamSession)
    }

    func testAppModelReflectsMobileSuspensionAndForegroundRestoration()
        async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 40,
                    key: Data(repeating: 0x40, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        let suspended = try makeMobileRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            revision: 1,
            sceneActivity: .background
        )
        mediaEnvironment.yieldMobileRuntime(
            suspended,
            sessionID: record.sessionID
        )
        await waitUntil { model.mobileRuntimeState == suspended }
        XCTAssertEqual(
            model.session.phase,
            .suspending(reason: "no-active-permitted-media-path")
        )
        XCTAssertTrue(model.session.isStreaming)
        XCTAssertEqual(
            model.renderState.policy,
            .paused(reason: "no-active-permitted-media-path")
        )

        let restored = try makeMobileRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            revision: 2,
            sceneActivity: .active,
            foregroundRestorationCount: 1
        )
        mediaEnvironment.yieldMobileRuntime(
            restored,
            sessionID: record.sessionID
        )
        await waitUntil { model.mobileRuntimeState == restored }
        XCTAssertEqual(model.session.phase, .streaming)
        XCTAssertEqual(model.renderState.policy, .active)

        await model.stopStream()
        await launchTask.value
        XCTAssertNil(model.mobileRuntimeState)
        XCTAssertEqual(model.session.phase, .disconnected)
    }

    func testMobileContinuityRegressionProjectsActualStateAcrossReplacementAndCleanStop()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 41,
                    key: Data(repeating: 0x41, count: 16)
                )),
                .success(RemoteInputKeyMaterial(
                    keyID: 42,
                    key: Data(repeating: 0x42, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let firstLaunch = Task { await model.launchSelectedApp() }
        let firstRecord = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: firstRecord)
        await waitUntil { model.session.isStreaming }
        model.diagnostics.record(
            ApplicationDiagnosticFactory.streamFailure(
                VideoDecoderError.noActiveSession
            )
        )

        let pictureInPicture = try makeMobileRuntimeState(
            sessionID: firstRecord.sessionID,
            mediaGeneration: 1,
            revision: 1,
            sceneActivity: .background,
            pictureInPictureLifecycle: .active,
            includesActualSceneAndDisplay: true
        )
        mediaEnvironment.yieldMobileRuntime(
            pictureInPicture,
            sessionID: firstRecord.sessionID
        )
        await waitUntil { model.mobileRuntimeState == pictureInPicture }
        XCTAssertEqual(model.mobileExperiencePresentationStatus.scene, .background)
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.pictureInPicture,
            .active
        )
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.continuity,
            .pictureInPicture
        )
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.display,
            .edrCapable(potentialHeadroom: 4, currentHeadroom: 2)
        )
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.pictureInPictureCommand,
            .stop
        )
        XCTAssertEqual(
            model.renderState.policy,
            .paused(reason: "picture-in-picture-active")
        )

        let duplicatePictureInPicture = try makeMobileRuntimeState(
            sessionID: firstRecord.sessionID,
            mediaGeneration: 1,
            revision: 2,
            sceneActivity: .background,
            pictureInPictureLifecycle: .active,
            includesActualSceneAndDisplay: true
        )
        mediaEnvironment.yieldMobileRuntime(
            duplicatePictureInPicture,
            sessionID: firstRecord.sessionID
        )
        await waitUntil {
            model.mobileRuntimeState == duplicatePictureInPicture
        }
        XCTAssertEqual(
            model.diagnostics.events.filter {
                $0.code == "mobile_continuity_pip"
            }.count,
            1
        )

        let audioOnly = try makeMobileRuntimeState(
            sessionID: firstRecord.sessionID,
            mediaGeneration: 1,
            revision: 3,
            sceneActivity: .background,
            isAudioSessionActive: true,
            includesActualSceneAndDisplay: true
        )
        mediaEnvironment.yieldMobileRuntime(
            audioOnly,
            sessionID: firstRecord.sessionID
        )
        await waitUntil { model.mobileRuntimeState == audioOnly }
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.continuity,
            .audioOnly
        )
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.pictureInPicture,
            .unavailable
        )

        let policyLoss = try makeMobileRuntimeState(
            sessionID: firstRecord.sessionID,
            mediaGeneration: 1,
            revision: 4,
            sceneActivity: .background,
            includesActualSceneAndDisplay: true
        )
        mediaEnvironment.yieldMobileRuntime(
            policyLoss,
            sessionID: firstRecord.sessionID
        )
        await waitUntil { model.mobileRuntimeState == policyLoss }
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.continuity,
            .paused
        )
        XCTAssertEqual(
            model.session.phase,
            .suspending(reason: "no-active-permitted-media-path")
        )

        let foreground = try makeMobileRuntimeState(
            sessionID: firstRecord.sessionID,
            mediaGeneration: 1,
            revision: 5,
            sceneActivity: .active,
            foregroundRestorationCount: 1,
            includesActualSceneAndDisplay: true
        )
        mediaEnvironment.yieldMobileRuntime(
            foreground,
            sessionID: firstRecord.sessionID
        )
        await waitUntil { model.mobileRuntimeState == foreground }
        XCTAssertEqual(model.mobileExperiencePresentationStatus.scene, .active)
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.continuity,
            .foreground
        )
        XCTAssertEqual(model.renderState.policy, .active)
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.category,
            .decoder
        )

        let firstMobileEvents = model.diagnostics.events.filter {
            $0.code.hasPrefix("mobile_")
        }
        for event in firstMobileEvents {
            XCTAssertFalse(event.message.contains(firstRecord.sessionID.uuidString))
            XCTAssertFalse(event.message.contains("moon.local"))
        }

        await model.stopStream()
        await firstLaunch.value
        XCTAssertNil(model.mobileRuntimeState)
        XCTAssertNil(model.mobileSceneWindowSnapshot)
        XCTAssertNil(model.mobileDisplayEDRSnapshot)
        XCTAssertNil(model.mobilePictureInPictureSnapshot)
        XCTAssertNil(model.mobileAudioSessionActive)
        XCTAssertEqual(model.mobileExperiencePresentationStatus.scene, .noSession)
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.pictureInPicture,
            .noSession
        )
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.continuity,
            .noSession
        )
        XCTAssertEqual(model.mobileExperiencePresentationStatus.display, .noSession)

        let replacementLaunch = Task { await model.launchSelectedApp() }
        await waitUntil { provider.currentStartRecords().count == 2 }
        let replacementRecord = try XCTUnwrap(provider.currentStartRecords().last)
        driveSessionToStreaming(provider, record: replacementRecord)
        await waitUntil { model.session.isStreaming }
        let replacementPictureInPicture = try makeMobileRuntimeState(
            sessionID: replacementRecord.sessionID,
            mediaGeneration: 2,
            revision: 1,
            sceneActivity: .background,
            pictureInPictureLifecycle: .active,
            includesActualSceneAndDisplay: true
        )
        mediaEnvironment.yieldMobileRuntime(
            replacementPictureInPicture,
            sessionID: replacementRecord.sessionID
        )
        await waitUntil {
            model.mobileRuntimeState == replacementPictureInPicture
        }
        XCTAssertNotEqual(firstRecord.sessionID, replacementRecord.sessionID)
        XCTAssertEqual(
            model.diagnostics.events.filter {
                $0.code == "mobile_continuity_pip"
            }.count,
            2
        )
        XCTAssertEqual(
            model.mobileExperiencePresentationStatus.continuity,
            .pictureInPicture
        )

        await model.stopStream()
        await replacementLaunch.value
        XCTAssertNil(model.mobileRuntimeState)
        XCTAssertEqual(model.mobileExperiencePresentationStatus.scene, .noSession)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertEqual(mediaEnvironment.currentStoppedSessionIDs().count, 2)
    }

    func testAppModelBindsSpatialPreferencesAndCurrentAudioRuntime() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let persistedPreferences = SessionSpatialAudioPreferences(
            spatialAudioEnabled: true,
            headTrackingEnabled: false
        )
        var persistedSettings = AppSettings.defaults
        persistedSettings.audio = AudioPreferences(persistedPreferences)
        let settingsRepository = InMemoryAppSettingsRepository(
            settings: persistedSettings
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 41,
                    key: Data(repeating: 0x41, count: 16)
                ))
            ]),
            settingsRepository: settingsRepository
        )

        await model.loadInitialState()
        XCTAssertEqual(model.spatialAudioPreferences, persistedPreferences)
        XCTAssertEqual(model.settings.audio, AudioPreferences(persistedPreferences))
        XCTAssertNil(model.audioRuntimeState)
        XCTAssertEqual(model.spatialAudioPresentationStatus, .inactive)
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil {
            model.session.isStreaming
                && mediaEnvironment
                    .currentSpatialAudioPreferenceApplications().count == 1
        }

        XCTAssertEqual(
            mediaEnvironment.currentSpatialAudioPreferenceApplications(),
            [SessionSpatialAudioPreferenceApplication(
                sessionID: record.sessionID,
                mediaGeneration: 1,
                preferences: persistedPreferences
            )]
        )
        let current = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            sequence: 0,
            graphGeneration: 1,
            preferences: persistedPreferences,
            spatialRuntime: SpatialAudioRuntimeSnapshot(
                revision: SpatialAudioSemanticRevision(rawValue: 1),
                layoutSignature: StreamAudioChannelLayout.stereo.signature,
                graphMode: .environmentAmbienceBed,
                platformStrategy: .environmentListener,
                routeSupport: .supported,
                presentationMode: .fixedSpatial,
                fallbackReason: .missingEntitlement
            )
        )
        mediaEnvironment.yieldAudioRuntime(current, sessionID: record.sessionID)
        await waitUntil { model.audioRuntimeState == current }
        XCTAssertEqual(
            model.spatialAudioPresentationStatus,
            SpatialAudioPresentationStatus(
                mode: .fixedSpatial,
                fallback: .missingEntitlement
            )
        )
        XCTAssertEqual(
            model.diagnostics.events
                .filter { $0.code.hasPrefix("spatial_audio_") }
                .map(\.code),
            ["spatial_audio_missing_entitlement"]
        )
        model.diagnostics.record(ApplicationDiagnosticFactory.pairingUnavailable)
        model.diagnostics.record(
            ApplicationDiagnosticFactory.streamFailure(NetworkChannelError.closed)
        )
        model.diagnostics.record(
            ApplicationDiagnosticFactory.streamFailure(
                VideoDecoderError.noActiveSession
            )
        )
        model.diagnostics.record(
            ApplicationDiagnosticFactory.hdrPresentationState(.pipelineFailure)!
        )
        model.diagnostics.record(
            ApplicationDiagnosticFactory.streamFailure(
                RemoteInputRuntimeError.deliveryFailed
            )
        )
        XCTAssertEqual(
            model.diagnostics.currentActionableEvent(in: .audio)?.code,
            "spatial_audio_missing_entitlement"
        )

        let recovered = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            sequence: 1,
            graphGeneration: 2,
            preferences: persistedPreferences,
            spatialRuntime: SpatialAudioRuntimeSnapshot(
                revision: SpatialAudioSemanticRevision(rawValue: 2),
                layoutSignature: StreamAudioChannelLayout.stereo.signature,
                graphMode: .environmentAmbienceBed,
                platformStrategy: .environmentListener,
                routeSupport: .supported,
                presentationMode: .fixedSpatial,
                fallbackReason: nil
            )
        )
        mediaEnvironment.yieldAudioRuntime(recovered, sessionID: record.sessionID)
        await waitUntil { model.audioRuntimeState == recovered }
        XCTAssertEqual(
            model.spatialAudioPresentationStatus,
            SpatialAudioPresentationStatus(
                mode: .fixedSpatial,
                fallback: nil
            )
        )
        let equivalentRecovery = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            sequence: 2,
            graphGeneration: 2,
            preferences: persistedPreferences,
            spatialRuntime: recovered.runtime.spatialRuntime
        )
        mediaEnvironment.yieldAudioRuntime(
            equivalentRecovery,
            sessionID: record.sessionID
        )
        await waitUntil { model.audioRuntimeState == equivalentRecovery }

        XCTAssertNil(model.diagnostics.currentActionableEvent(in: .audio))
        XCTAssertEqual(
            model.diagnostics.currentActionableEvent(in: .pairing)?.code,
            "pairing_provider_unavailable"
        )
        XCTAssertEqual(
            model.diagnostics.currentActionableEvent(in: .transport)?.code,
            "transport_failed"
        )
        XCTAssertEqual(
            model.diagnostics.currentActionableEvent(in: .decoder)?.code,
            "video_pipeline_failed"
        )
        XCTAssertEqual(
            model.diagnostics.currentActionableEvent(in: .hdr)?.code,
            "hdr_pipeline_failure"
        )
        XCTAssertEqual(
            model.diagnostics.currentActionableEvent(in: .input)?.code,
            "input_delivery_failed"
        )
        XCTAssertEqual(
            model.diagnostics.events
                .filter { $0.code == "spatial_audio_active_fixed" }
                .count,
            2
        )

        let updatedPreferences = SessionSpatialAudioPreferences(
            spatialAudioEnabled: false,
            headTrackingEnabled: false
        )
        try await model.updateSpatialAudioPreferences(updatedPreferences)
        await waitUntil {
            mediaEnvironment
                .currentSpatialAudioPreferenceApplications().count == 2
        }
        XCTAssertEqual(model.spatialAudioPreferences, updatedPreferences)
        XCTAssertEqual(model.settings.audio, AudioPreferences(updatedPreferences))
        XCTAssertEqual(
            model.spatialAudioPresentationStatus,
            SpatialAudioPresentationStatus(
                mode: .fixedSpatial,
                fallback: nil
            )
        )
        XCTAssertEqual(
            mediaEnvironment.currentSpatialAudioPreferenceApplications().last,
            SessionSpatialAudioPreferenceApplication(
                sessionID: record.sessionID,
                mediaGeneration: 1,
                preferences: updatedPreferences
            )
        )

        let wrongGeneration = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 2,
            sequence: 100,
            graphGeneration: 100,
            preferences: .nativeDefault
        )
        mediaEnvironment.yieldAudioRuntime(
            wrongGeneration,
            sessionID: record.sessionID
        )
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(model.audioRuntimeState, equivalentRecovery)
        XCTAssertEqual(
            model.diagnostics.events
                .filter { $0.code.hasPrefix("spatial_audio_") }
                .map(\.code),
            [
                "spatial_audio_missing_entitlement",
                "spatial_audio_active_fixed",
                "spatial_audio_active_fixed"
            ]
        )

        await model.saveSettings()
        let savedSettings = try await settingsRepository.loadSettings()
        XCTAssertEqual(
            savedSettings.audio,
            AudioPreferences(updatedPreferences)
        )
        await model.stopStream()
        await launchTask.value
        XCTAssertNil(model.audioRuntimeState)
        XCTAssertEqual(model.spatialAudioPresentationStatus, .inactive)
        XCTAssertEqual(
            model.diagnostics.events
                .filter { $0.code.hasPrefix("spatial_audio_") }
                .map(\.code),
            [
                "spatial_audio_missing_entitlement",
                "spatial_audio_active_fixed",
                "spatial_audio_active_fixed",
                "spatial_audio_inactive"
            ]
        )
        XCTAssertEqual(model.spatialAudioPreferences, updatedPreferences)
    }

    func testReconnectClearsAudioRuntimeAndRejectsPriorMediaGeneration() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 42,
                    key: Data(repeating: 0x42, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        let first = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            sequence: 0,
            graphGeneration: 1
        )
        mediaEnvironment.yieldAudioRuntime(first, sessionID: record.sessionID)
        await waitUntil { model.audioRuntimeState == first }

        mediaEnvironment.blockNextStop()
        provider.yield(
            .reconnecting(attempt: 1, reason: "Control channel interrupted."),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.hasBlockedStop() }
        XCTAssertNil(model.audioRuntimeState)
        mediaEnvironment.resumeBlockedStop()
        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey
            )),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.currentStartRecords().count == 2 }

        let stale = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            sequence: 99,
            graphGeneration: 99
        )
        mediaEnvironment.yieldAudioRuntime(stale, sessionID: record.sessionID)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.audioRuntimeState)

        let replacement = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 2,
            sequence: 0,
            graphGeneration: 1
        )
        mediaEnvironment.yieldAudioRuntime(
            replacement,
            sessionID: record.sessionID
        )
        await waitUntil { model.audioRuntimeState == replacement }

        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launchTask.value
        XCTAssertNil(model.audioRuntimeState)
    }

    func testNativeApplicationIntegrationCoversSpatialAudioReplacementAndCleanStop()
        async throws
    {
        let control = ControlledSessionControlProvider()
        let videoReceive = ApplicationIntegrationVideoReceiveProvider()
        let audioReceive = ApplicationIntegrationAudioReceiveProvider()
        let remoteInput = ApplicationIntegrationRemoteInputProvider()
        let videoProcessors = ApplicationIntegrationVideoProcessorFactory()
        let audioRegistry = ApplicationIntegrationAudioRegistry(
            initialCapability: applicationIntegrationRouteCapability(.supported)
        )
        let audioFactory = NativeSessionAudioProcessorFactory(
            entitlementReader: ApplicationIntegrationEntitlementReader(state: .missing),
            decoderFactory: { configuration in
                try audioRegistry.makeDecoder(configuration: configuration)
            },
            engineClientFactory: {
                audioRegistry.makeEngine()
            },
            routeEventSourceFactory: {
                audioRegistry.makeRouteSource()
            },
            eventTimeProvider: {
                audioRegistry.nextEventTime()
            }
        )
        let environment = NativeSessionMediaEnvironment(
            videoReceiveProvider: videoReceive,
            audioReceiveProvider: audioReceive,
            remoteInputProvider: remoteInput,
            videoProcessorFactory: videoProcessors,
            audioProcessorFactory: audioFactory,
            teardownGracePeriod: .seconds(1)
        )
        let runtimeProviders = RuntimeProviderInventory(
            sessionControl: control,
            videoReceive: videoReceive,
            audioReceive: audioReceive,
            remoteInput: remoteInput
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: control,
            sessionMediaEnvironment: environment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 46,
                    key: Data(repeating: 0x46, count: 16)
                ))
            ]),
            runtimeProviders: runtimeProviders
        )
        let audioConfiguration = try makeWave7Point1AudioConfiguration()

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(control)
        let configuration = makeSessionConfiguration(
            sessionID: record.sessionID,
            keyMaterial: record.request.remoteInputKey,
            audioConfiguration: audioConfiguration
        )

        control.yield(.launchAccepted(makeSessionLaunchResponse()), sessionID: record.sessionID)
        control.yield(.rtspReady, sessionID: record.sessionID)
        control.yield(.negotiated(configuration), sessionID: record.sessionID)
        control.yield(.channelsReady(.all), sessionID: record.sessionID)
        guard await waitForApplicationIntegrationState(
            diagnostic: {
                "videoStarts=\(videoReceive.startCount()) "
                    + "audioStarts=\(audioReceive.startCount()) "
                    + "audioEngines=\(audioRegistry.engineCount()) "
                    + "hasAudioRuntime=\(model.audioRuntimeState != nil) "
                    + "sessionPhase=\(model.session.phase.label)"
            },
            condition: {
                videoReceive.startCount() == 1
                    && audioReceive.startCount() == 1
                    && audioRegistry.engineCount() == 1
                    && model.audioRuntimeState != nil
            }
        ) else { return }

        let firstState = try XCTUnwrap(model.audioRuntimeState)
        let firstSpatial = try XCTUnwrap(firstState.runtime.spatialRuntime)
        let firstEngine = try XCTUnwrap(audioRegistry.engine(at: 0))
        let firstDecoder = try XCTUnwrap(audioRegistry.decoder(at: 0))
        let firstSource = try XCTUnwrap(audioRegistry.routeSource(at: 0))
        XCTAssertEqual(firstState.mediaGeneration, 1)
        XCTAssertEqual(firstState.runtime.graphGeneration, 1)
        XCTAssertEqual(firstSpatial.presentationMode, .fixedSpatial)
        XCTAssertEqual(firstSpatial.fallbackReason, .missingEntitlement)
        XCTAssertEqual(
            firstSpatial.diagnosticCode,
            "spatial_audio_fixed-spatial_missing-entitlement"
        )
        XCTAssertEqual(firstEngine.configurations().map(\.channelLayout), [.wave7Point1])
        XCTAssertEqual(firstEngine.graphIntents().map(\.entitlement), [.missing])
        XCTAssertEqual(firstEngine.graphModes(), [.environmentAmbienceBed])
        XCTAssertEqual(firstDecoder.configuration(), audioConfiguration)
        XCTAssertFalse(model.session.isStreaming)

        videoReceive.yield(
            .packet(ReceivedVideoPacket(
                sequenceNumber: 1,
                frameIndex: 1,
                receiveTimeNanoseconds: 1,
                isFirstPacket: true,
                isLastPacket: true,
                payload: Data([0x01])
            )),
            startIndex: 0
        )
        await waitUntil { videoProcessors.consumeCount(at: 0) == 1 }
        XCTAssertFalse(model.session.isStreaming)

        audioReceive.yield(
            .packet(ReceivedAudioPacket(
                sequenceNumber: 1,
                timestamp: 0,
                receiveTimeNanoseconds: 1_000_000,
                payload: Data([0xA1])
            )),
            startIndex: 0
        )
        audioReceive.yield(
            .packet(ReceivedAudioPacket(
                sequenceNumber: 2,
                timestamp: 240,
                receiveTimeNanoseconds: 12_000_000,
                payload: Data([0xA2])
            )),
            startIndex: 0
        )
        await waitUntil {
            model.session.isStreaming && !firstEngine.scheduledBuffers().isEmpty
        }
        let firstPCM = try XCTUnwrap(firstEngine.scheduledBuffers().first)
        XCTAssertEqual(firstPCM.format.channelLayout, .wave7Point1)
        XCTAssertEqual(firstPCM.format.channelCount, 8)
        XCTAssertEqual(firstPCM.frameCount, 240)
        XCTAssertEqual(firstPCM.interleavedSamples.count, 1_920)

        firstEngine.setCapability(applicationIntegrationRouteCapability(.unsupported))
        firstSource.emit(.routeChanged)
        await waitUntil {
            model.audioRuntimeState?.runtime.spatialRuntime?.fallbackReason
                == .routeUnsupported
        }
        let downgraded = try XCTUnwrap(model.audioRuntimeState)
        let downgradedSpatial = try XCTUnwrap(downgraded.runtime.spatialRuntime)
        XCTAssertEqual(downgraded.runtime.sequence, 1)
        XCTAssertEqual(downgraded.runtime.graphGeneration, 2)
        XCTAssertEqual(downgradedSpatial.presentationMode, .nonspatial)
        XCTAssertEqual(downgradedSpatial.fallbackReason, .routeUnsupported)
        XCTAssertEqual(
            downgradedSpatial.diagnosticCode,
            "spatial_audio_nonspatial_route-unsupported"
        )

        control.yield(
            .reconnecting(attempt: 1, reason: "Control channel interrupted."),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.audioRuntimeState == nil
                && firstEngine.wasStopped()
                && firstDecoder.isClosed()
                && firstSource.wasStopped()
                && videoProcessors.wasStopped(at: 0)
                && videoReceive.stopCount() == 1
                && audioReceive.stopCount() == 1
        }
        XCTAssertFalse(model.session.isStreaming)
        let firstGenerationSnapshot = await waitForEnvironmentTeardown(environment)
        XCTAssertNil(firstGenerationSnapshot.sessionID)
        XCTAssertNil(firstGenerationSnapshot.audioRuntime)
        XCTAssertTrue(firstGenerationSnapshot.lastTeardownReport?.isClean == true)

        firstEngine.setCapability(applicationIntegrationRouteCapability(.supported))
        firstSource.emitLate(.routeChanged)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertNil(model.audioRuntimeState)
        XCTAssertEqual(firstEngine.graphIntents().count, 2)

        control.yield(.rtspReady, sessionID: record.sessionID)
        control.yield(.negotiated(configuration), sessionID: record.sessionID)
        await waitUntil {
            videoReceive.startCount() == 2
                && audioReceive.startCount() == 2
                && audioRegistry.engineCount() == 2
                && model.audioRuntimeState?.mediaGeneration == 2
        }
        control.yield(.channelsReady(.control), sessionID: record.sessionID)
        let replacement = try XCTUnwrap(model.audioRuntimeState)
        let replacementSpatial = try XCTUnwrap(replacement.runtime.spatialRuntime)
        let replacementEngine = try XCTUnwrap(audioRegistry.engine(at: 1))
        let replacementDecoder = try XCTUnwrap(audioRegistry.decoder(at: 1))
        let replacementSource = try XCTUnwrap(audioRegistry.routeSource(at: 1))
        XCTAssertEqual(replacement.runtime.sequence, 0)
        XCTAssertEqual(replacement.runtime.graphGeneration, 1)
        XCTAssertEqual(replacementSpatial.presentationMode, .fixedSpatial)
        XCTAssertEqual(replacementSpatial.fallbackReason, .missingEntitlement)
        XCTAssertEqual(replacementEngine.graphModes(), [.environmentAmbienceBed])
        XCTAssertFalse(model.session.isStreaming)

        videoReceive.yield(
            .packet(ReceivedVideoPacket(
                sequenceNumber: 2,
                frameIndex: 2,
                receiveTimeNanoseconds: 2,
                isFirstPacket: true,
                isLastPacket: true,
                payload: Data([0x02])
            )),
            startIndex: 1
        )
        audioReceive.yield(
            .packet(ReceivedAudioPacket(
                sequenceNumber: 3,
                timestamp: 480,
                receiveTimeNanoseconds: 2_000_000,
                payload: Data([0xA3])
            )),
            startIndex: 1
        )
        audioReceive.yield(
            .packet(ReceivedAudioPacket(
                sequenceNumber: 4,
                timestamp: 720,
                receiveTimeNanoseconds: 13_000_000,
                payload: Data([0xA4])
            )),
            startIndex: 1
        )
        await waitUntil {
            model.session.isStreaming && !replacementEngine.scheduledBuffers().isEmpty
        }

        await model.stopStream()
        await launchTask.value
        let stoppedSnapshot = await environment.snapshot()
        let remoteInputSnapshot = remoteInput.snapshot()
        XCTAssertNil(model.audioRuntimeState)
        XCTAssertEqual(model.spatialAudioPreferences, .nativeDefault)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertNil(stoppedSnapshot.sessionID)
        XCTAssertNil(stoppedSnapshot.audioRuntime)
        XCTAssertEqual(stoppedSnapshot.activeTaskCount, 0)
        XCTAssertEqual(stoppedSnapshot.activeResourceCount, 0)
        XCTAssertTrue(stoppedSnapshot.lastTeardownReport?.isClean == true)
        XCTAssertEqual(videoReceive.stopCount(), 2)
        XCTAssertEqual(audioReceive.stopCount(), 2)
        XCTAssertEqual(remoteInputSnapshot.startCount, 2)
        XCTAssertEqual(remoteInputSnapshot.releaseCount, 4)
        XCTAssertEqual(remoteInputSnapshot.stopCount, 2)
        XCTAssertTrue(videoProcessors.wasStopped(at: 1))
        XCTAssertTrue(replacementEngine.wasStopped())
        XCTAssertTrue(replacementDecoder.isClosed())
        XCTAssertTrue(replacementSource.wasStopped())
        XCTAssertEqual(control.currentStoppedSessionIDs(), [record.sessionID])
    }

    func testControlReadinessCannotBypassMediaEnvironmentReadiness() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(automaticallyReady: false)
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 14,
                    key: Data(repeating: 0xF2, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        provider.yield(.launchAccepted(makeSessionLaunchResponse()), sessionID: record.sessionID)
        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey
            )),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.currentStartRecords().count == 1 }
        provider.yield(.channelsReady(.all), sessionID: record.sessionID)
        for _ in 0..<100 { await Task.yield() }

        XCTAssertFalse(model.session.isStreaming)
        XCTAssertEqual(model.renderState.policy, .idle)
        let inputEvent = RemoteInputEvent.keyboard(KeyboardInputEvent(
            rawKeyCode: 4,
            characters: nil,
            isDown: true,
            modifiers: [],
            isRepeat: false
        ))
        do {
            try await model.sendRemoteInput(inputEvent)
            XCTFail("Input must fail closed until media input readiness is published.")
        } catch {
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .inputUnavailable
            )
        }
        XCTAssertEqual(mediaEnvironment.currentSentInputApplications(), [])
        mediaEnvironment.yieldReadiness(
            [.video, .audio, .input],
            sessionID: record.sessionID
        )
        await waitUntil { model.session.isStreaming }
        try await model.sendRemoteInput(inputEvent)
        try await model.releaseRemoteInput()
        mediaEnvironment.yieldFeedback(
            .led(ControllerLEDFeedback(
                controllerID: "controller-1",
                red: 10,
                green: 20,
                blue: 30
            )),
            sessionID: record.sessionID
        )
        await waitUntil { model.latestRemoteInputFeedback != nil }
        let sentApplications = mediaEnvironment.currentSentInputApplications()
        let mediaSnapshot = await mediaEnvironment.snapshot()
        XCTAssertEqual(sentApplications.count, 1)
        XCTAssertEqual(sentApplications.first?.sessionID, record.sessionID)
        XCTAssertEqual(sentApplications.first?.mediaGeneration, mediaSnapshot.generation)
        XCTAssertEqual(sentApplications.first?.event, inputEvent)
        XCTAssertEqual(
            mediaEnvironment.currentReleasedInputApplications(),
            [SessionInputReleaseApplication(
                sessionID: record.sessionID,
                mediaGeneration: mediaSnapshot.generation
            )]
        )
        XCTAssertEqual(model.latestRemoteInputFeedback, .led(ControllerLEDFeedback(
            controllerID: "controller-1",
            red: 10,
            green: 20,
            blue: 30
        )))

        await model.stopStream()
        await launchTask.value
        XCTAssertEqual(mediaEnvironment.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertNil(model.latestRemoteInputFeedback)
        do {
            try await model.sendRemoteInput(inputEvent)
            XCTFail("Stopped media generation must reject remote input.")
        } catch {
            XCTAssertEqual(error as? SessionMediaEnvironmentError, .inactiveSession)
        }
    }

    func testMediaEnvironmentFailureFailsSessionAndStopsControlProviderOnce() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 16,
                    key: Data(repeating: 0xF4, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        let audioRuntime = makeAudioRuntimeState(
            sessionID: record.sessionID,
            mediaGeneration: 1,
            sequence: 0,
            graphGeneration: 1
        )
        mediaEnvironment.yieldAudioRuntime(
            audioRuntime,
            sessionID: record.sessionID
        )
        await waitUntil { model.audioRuntimeState == audioRuntime }

        mediaEnvironment.finish(
            sessionID: record.sessionID,
            throwing: MediaEnvironmentApplicationTestError.failed
        )
        await launchTask.value

        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertNil(model.session.activeHostID)
        guard case .failed = model.session.phase else {
            return XCTFail("Media environment failure must fail the application session.")
        }
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertNil(model.audioRuntimeState)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(mediaEnvironment.currentStoppedSessionIDs(), [record.sessionID])
    }

    func testLocalStopWhileMediaStartupIsPendingCannotRestoreStreaming() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = BlockingSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 15,
                    key: Data(repeating: 0xF3, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        provider.yield(.launchAccepted(makeSessionLaunchResponse()), sessionID: record.sessionID)
        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey
            )),
            sessionID: record.sessionID
        )
        await waitUntil { mediaEnvironment.hasStarted() }

        await model.stopStream()
        mediaEnvironment.completeStart()
        await launchTask.value

        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(mediaEnvironment.currentStoppedSessionIDs(), [
            record.sessionID,
            record.sessionID
        ])
    }

    func testInvalidSessionEventOrderFailsClosedAndStopsProviderOnce() async throws {
        let provider = ControlledSessionControlProvider()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 12,
                    key: Data(repeating: 0xF0, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)

        provider.yield(.channelsReady(.all), sessionID: record.sessionID)
        await launchTask.value

        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertFalse(model.streamLaunchUI.isLaunching)
        XCTAssertNil(model.session.activeHostID)
        guard case .failed = model.session.phase else {
            return XCTFail("Invalid session event order must fail closed.")
        }
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
    }

    func testLocalStopInvalidatesLateSessionEventsAndStopsProviderOnce() async throws {
        let provider = ControlledSessionControlProvider()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 8,
                    key: Data(repeating: 0xBB, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        let owner = try XCTUnwrap(model.activeProductSessionOwner)
        try model.workspaceRegistry.update(owner.workspace) {
            $0.presentation.issue = ProductIssue(
                code: .streamInterrupted,
                actionScope: .session(
                    workspace: owner.workspace,
                    sessionID: owner.sessionID
                )
            )
        }

        await model.stopStream()
        provider.yield(.channelsReady(.all), sessionID: record.sessionID)
        await launchTask.value

        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertEqual(model.session.phase, .disconnected)
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertNil(model.streamProductIssue)
    }

    func testDuplicateLaunchDoesNotStartAnotherSessionGeneration() async throws {
        let provider = ControlledSessionControlProvider()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 9,
                    key: Data(repeating: 0xCC, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        _ = try await waitForSessionStart(provider)

        await model.launchSelectedApp()
        XCTAssertEqual(provider.currentStartRecords().count, 1)

        await model.stopStream()
        await launchTask.value
    }

    func testControlStreamFailureAndIncompleteEndFailClosed() async throws {
        for ending in ControlledSessionControlProvider.Ending.allCases {
            let provider = ControlledSessionControlProvider()
            let model = makeLaunchReadyModel(
                sessionControlProvider: provider,
                launchClient: StubStreamLaunchClient(),
                remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                    .success(RemoteInputKeyMaterial(
                        keyID: 10,
                        key: Data(repeating: 0xDD, count: 16)
                    ))
                ])
            )

            await model.loadInitialState()
            await model.refreshAppsForSelectedHost()
            let launchTask = Task { await model.launchSelectedApp() }
            let record = try await waitForSessionStart(provider)
            provider.yield(.launchAccepted(makeSessionLaunchResponse()), sessionID: record.sessionID)
            provider.finish(sessionID: record.sessionID, ending: ending)
            await launchTask.value

            XCTAssertFalse(model.hasActiveStreamSession)
            guard case .failed = model.session.phase else {
                return XCTFail("A non-terminal control stream must fail closed.")
            }
            XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
            XCTAssertEqual(model.renderState.policy, .idle)
            XCTAssertEqual(model.diagnostics.latestActionableEvent?.category, .transport)
            XCTAssertEqual(model.streamProductIssue?.code, .streamInterrupted)
            XCTAssertEqual(
                model.streamProductIssue?.action?.kind,
                .reconnectStream
            )
        }
    }

    func testMediaAndControllerFailuresSurfaceSafeActionableDiagnostics() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(automaticallyReady: false)
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 18,
                    key: Data(repeating: 0xC8, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { mediaEnvironment.currentStartRecords().count == 1 }

        mediaEnvironment.yieldFeedback(.diagnostic(RemoteInputFeedbackDiagnostic(
            controllerID: "must-not-appear",
            controllerIndex: 4,
            command: .led,
            reason: .unsupportedCapability
        )), sessionID: record.sessionID)
        await waitUntil { model.diagnostics.latestActionableEvent?.severity == .warning }
        let feedbackEvent = try XCTUnwrap(model.diagnostics.latestActionableEvent)
        XCTAssertEqual(feedbackEvent.category, .input)
        XCTAssertFalse(feedbackEvent.message.contains("must-not-appear"))

        mediaEnvironment.finish(
            sessionID: record.sessionID,
            throwing: VideoDecoderError.noActiveSession
        )
        await launchTask.value

        let failureEvent = try XCTUnwrap(model.diagnostics.latestActionableEvent)
        XCTAssertEqual(failureEvent.category, .decoder)
        XCTAssertEqual(failureEvent.code, "video_pipeline_failed")
        XCTAssertEqual(failureEvent.action, .reviewStreamSettings)
        XCTAssertEqual(model.streamProductIssue?.code, .mediaPresentationFailed)
        XCTAssertEqual(
            model.streamProductIssue?.action?.kind,
            .reviewStreamSettings
        )
        XCTAssertFalse(failureEvent.message.contains("must-not-appear"))
    }

    func testLaunchPairingFailureUsesCheckedLibraryRecoveryAction() async throws {
        let provider = ControlledSessionControlProvider()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 82,
                    key: Data(repeating: 0x82, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let workspace = model.primaryWorkspaceReference
        let launchTask = Task { await model.launchSelectedApp(in: workspace) }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        provider.finish(
            sessionID: record.sessionID,
            throwing: StreamNegotiationFailure(
                code: .hostNotPaired,
                subsystem: "must-not-appear",
                message: "https://user:1234@sunshine.internal provider-body"
            )
        )
        await launchTask.value

        let issue = try XCTUnwrap(model.streamProductIssue(in: workspace))
        XCTAssertEqual(issue.code, .streamRequiresPairing)
        XCTAssertEqual(issue.action?.kind, .chooseHostAndApp)
        let action = try XCTUnwrap(issue.action)
        XCTAssertTrue(model.canPerformProductAction(action))
        let actionResult = await model.performProductAction(action)
        XCTAssertEqual(actionResult, .performed)
        XCTAssertEqual(
            model.workspaceState(for: workspace)?.navigationSelection,
            .library
        )
        let presentation = [
            String(localized: issue.presentation.title),
            String(localized: issue.presentation.message)
        ].joined(separator: " ")
        XCTAssertFalse(presentation.contains("sunshine.internal"))
        XCTAssertFalse(presentation.contains("1234"))
        XCTAssertFalse(presentation.contains("provider-body"))
    }

    func testMacSurfacePolicyDerivesSessionLifecycleGeometryAndInputSettings() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 35,
                    key: Data(repeating: 0x35, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 2_560, height: 1_440)
        )
        model.applyPlatformLifecycle(lifecycle)
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.macInputSurfacePolicy.admitsInput }

        XCTAssertTrue(model.macInputSurfacePolicy.cursorPolicy.capturesRelativePointer)
        XCTAssertTrue(model.macInputSurfacePolicy.cursorPolicy.hidesSystemCursor)
        XCTAssertFalse(model.macInputSurfacePolicy.forwardsSystemShortcuts)

        model.settings.input.preferRelativeMouseMode = false
        model.settings.input.captureSystemShortcuts = true
        XCTAssertTrue(model.macInputSurfacePolicy.admitsInput)
        XCTAssertFalse(model.macInputSurfacePolicy.cursorPolicy.capturesRelativePointer)
        XCTAssertFalse(model.macInputSurfacePolicy.cursorPolicy.hidesSystemCursor)
        XCTAssertFalse(model.macInputSurfacePolicy.forwardsSystemShortcuts)

        XCTAssertEqual(
            model.submitMacPlatformInput(.pointerMove(MacPointerSample(
                localPoint: RemotePoint(x: 1_280, y: 720),
                deltaX: 9,
                deltaY: -3,
                buttons: []
            ))),
            .accepted
        )
        await waitUntil { mediaEnvironment.currentSentInputApplications().count == 1 }
        XCTAssertEqual(
            mediaEnvironment.currentSentInputApplications().first?.event,
            .pointer(.absoluteMove(
                point: RemotePoint(x: 1_920, y: 1_080),
                referenceSize: PixelSize(width: 3_840, height: 2_160),
                buttons: []
            ))
        )

        lifecycle.isFocused = false
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)
        XCTAssertEqual(
            model.submitMacPlatformInput(.pointerMove(MacPointerSample(
                localPoint: RemotePoint(x: 1_280, y: 720),
                deltaX: 1,
                deltaY: 1,
                buttons: []
            ))),
            .rejected(.admissionClosed)
        )

        lifecycle.isFocused = true
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        await waitUntil { model.macInputSurfacePolicy.admitsInput }
        lifecycle.drawableSize = .zero
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)

        model.settings.input.preferRelativeMouseMode = true
        model.exitMacRelativePointerCapture()
        XCTAssertFalse(model.settings.input.preferRelativeMouseMode)

        await model.stopStream()
        await launchTask.value
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)
    }

    func testMacDiagnosticsDeduplicateAndClearOnlyRecoveredActions() async throws {
        let provider = ControlledSessionControlProvider()
        let mediaEnvironment = ControlledSessionMediaEnvironment(failsInputSend: true)
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: mediaEnvironment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 36,
                    key: Data(repeating: 0x36, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 2_560, height: 1_440)
        )
        model.applyPlatformLifecycle(lifecycle)

        let launchTask = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.macInputSurfacePolicy.admitsInput }
        XCTAssertTrue(model.diagnostics.events.contains { $0.code == "mac_lifecycle_active" })
        XCTAssertTrue(model.diagnostics.events.contains { $0.code == "mac_input_relative_ready" })

        model.diagnostics.record(
            ApplicationDiagnosticFactory.streamFailure(VideoDecoderError.noActiveSession)
        )
        XCTAssertEqual(
            model.submitMacPlatformInput(.pointerMove(MacPointerSample(
                localPoint: RemotePoint(x: 1_280, y: 720),
                deltaX: 4,
                deltaY: -2,
                buttons: []
            ))),
            .accepted
        )
        await waitUntil {
            model.diagnostics.latestStreamActionableEvent?.category == .input
                && model.macSessionInputSnapshot().terminationReason == .sendFailure
                && !model.macInputSurfacePolicy.admitsInput
        }
        XCTAssertEqual(
            model.diagnostics.latestStreamActionableEvent?.code,
            "input_delivery_failed"
        )

        lifecycle.isFocused = false
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        let lifecycleEventCount = model.diagnostics.events.filter {
            $0.code.hasPrefix("mac_lifecycle_")
        }.count
        model.applyPlatformLifecycle(lifecycle)
        XCTAssertEqual(
            model.diagnostics.events.filter { $0.code.hasPrefix("mac_lifecycle_") }.count,
            lifecycleEventCount
        )
        XCTAssertEqual(model.diagnostics.latestStreamActionableEvent?.category, .input)
        XCTAssertTrue(model.diagnostics.events.contains { $0.code == "mac_lifecycle_unfocused" })

        mediaEnvironment.yieldReadiness(
            [.video, .audio],
            sessionID: record.sessionID
        )
        await waitUntil { model.macSessionInputSnapshot().generation == nil }
        mediaEnvironment.yieldReadiness(
            [.video, .audio, .input],
            sessionID: record.sessionID
        )
        await waitUntil {
            model.macSessionInputSnapshot().generation != nil
                && model.diagnostics.latestStreamActionableEvent?.category == .decoder
        }
        XCTAssertEqual(model.diagnostics.latestStreamActionableEvent?.category, .decoder)

        lifecycle.isVisible = false
        lifecycle.isFocused = true
        lifecycle.updateRenderPolicy()
        model.applyPlatformLifecycle(lifecycle)
        XCTAssertEqual(model.diagnostics.latestStreamActionableEvent?.category, .decoder)
        XCTAssertTrue(model.diagnostics.events.contains { $0.code == "mac_lifecycle_occluded" })

        let historicalActionCount = model.diagnostics.events.filter {
            $0.action != nil || $0.severity == .error
        }.count
        await model.stopStream()
        await launchTask.value

        XCTAssertNil(model.diagnostics.latestStreamActionableEvent)
        XCTAssertGreaterThanOrEqual(
            model.diagnostics.events.filter { $0.action != nil || $0.severity == .error }.count,
            historicalActionCount
        )
        let publicStateEvents = model.diagnostics.events.filter {
            $0.code.hasPrefix("mac_lifecycle_") || $0.code.hasPrefix("mac_input_")
        }
        for event in publicStateEvents {
            XCTAssertFalse(event.message.contains(record.sessionID.uuidString))
            XCTAssertFalse(event.message.contains("moon.local"))
            XCTAssertFalse(event.message.contains("2560"))
            XCTAssertFalse(event.message.contains("1440"))
        }
    }

    func testDefaultInputKeyGenerationUsesFreshMaterialForEveryLaunch() async throws {
        let firstKey = RemoteInputKeyMaterial(keyID: 1, key: Data(repeating: 0x11, count: 16))
        let secondKey = RemoteInputKeyMaterial(keyID: 2, key: Data(repeating: 0x22, count: 16))
        let keyGenerator = ScriptedInputKeyGenerator(results: [.success(firstKey), .success(secondKey)])
        let provider = ControlledSessionControlProvider(automaticallyCompletes: true)
        let launchClient = StubStreamLaunchClient()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: launchClient,
            remoteInputKeyGenerator: keyGenerator
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        await model.launchSelectedApp()
        await model.launchSelectedApp()

        XCTAssertEqual(provider.currentStartRecords().map(\.request.remoteInputKey), [
            firstKey,
            secondKey
        ])
        XCTAssertEqual(keyGenerator.currentGenerationCount(), 2)
        let launchCount = await launchClient.currentLaunchCount()
        XCTAssertEqual(launchCount, 0)
    }

    func testInputKeyGenerationFailureStopsBeforeNetworkLaunch() async throws {
        let keyGenerator = ScriptedInputKeyGenerator(results: [.failure(InputKeyGeneratorTestError.failed)])
        let provider = ControlledSessionControlProvider()
        let launchClient = StubStreamLaunchClient()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: launchClient,
            remoteInputKeyGenerator: keyGenerator
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        await model.launchSelectedApp()

        XCTAssertEqual(provider.currentStartRecords().count, 0)
        let launchCount = await launchClient.currentLaunchCount()
        XCTAssertEqual(launchCount, 0)
        XCTAssertEqual(keyGenerator.currentGenerationCount(), 1)
        guard case .failed = model.session.phase else {
            return XCTFail("Input-key generation failure must fail the session before launch.")
        }
        XCTAssertEqual(model.streamProductIssue?.code, .inputUnavailable)
        XCTAssertEqual(model.diagnostics.latestActionableEvent?.category, .input)
        XCTAssertEqual(model.diagnostics.latestActionableEvent?.code, "invalidInputKey")
        XCTAssertEqual(model.streamProductIssue?.action?.kind, .reconnectInput)
        XCTAssertEqual(model.renderState.policy, .idle)
    }

    func testParameterPreparationFailureIsVisibleWithoutStartingProvider() async throws {
        let provider = ControlledSessionControlProvider()
        let launchClient = StubStreamLaunchClient()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: launchClient,
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 13,
                    key: Data(repeating: 0xF1, count: 16)
                ))
            ])
        )

        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        model.settings.stream.width = 0
        await model.launchSelectedApp()

        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertFalse(model.streamLaunchUI.isLaunching)
        XCTAssertNil(model.session.activeHostID)
        guard case .failed = model.session.phase else {
            return XCTFail("Parameter preparation failure must be visible to the application.")
        }
        XCTAssertEqual(model.renderState.policy, .idle)
        XCTAssertEqual(provider.currentStartRecords().count, 0)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [])
        let launchCount = await launchClient.currentLaunchCount()
        XCTAssertEqual(launchCount, 0)
    }

    func testPrimaryCompatibilityLaunchRecordsAndClearsProductSessionOwner()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 31,
                    key: Data(repeating: 0x31, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()

        let launch = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)

        XCTAssertEqual(
            model.activeProductSessionOwner,
            ProductSessionOwner(
                workspace: model.primaryWorkspaceReference,
                sessionID: record.sessionID
            )
        )
        let didStop = await model.stopStream(in: model.primaryWorkspaceReference)
        XCTAssertTrue(didStop)
        await launch.value
        XCTAssertNil(model.activeProductSessionOwner)
        XCTAssertFalse(model.hasActiveStreamSession)
    }

    func testOwningSceneCloseStopsLaunchingStreamingAndReconnectingSessions()
        async throws
    {
        let phases: [ProductSessionActualPhase] = [
            .launching,
            .streaming,
            .reconnecting(attempt: 1)
        ]

        for (index, phase) in phases.enumerated() {
            let fixture = try await makeSceneCloseFixture(keyID: 60 + index)
            let launch = Task {
                await fixture.model.launchSelectedApp(
                    in: fixture.attachment.workspace
                )
            }
            let record = try await waitForSessionStart(fixture.provider)
            if phase != .launching {
                driveSessionToStreaming(fixture.provider, record: record)
                await waitUntil {
                    fixture.model.productSessionActualPhase == .streaming
                }
            }
            if case .reconnecting = phase {
                fixture.provider.yield(
                    .reconnecting(
                        attempt: 1,
                        reason: "control_unavailable"
                    ),
                    sessionID: record.sessionID
                )
                await waitUntil {
                    fixture.model.productSessionActualPhase
                        == .reconnecting(attempt: 1)
                }
            }

            XCTAssertEqual(fixture.model.productSessionActualPhase, phase)
            let close = await fixture.model.disconnectProductWorkspaceScene(
                fixture.attachment
            )
            XCTAssertEqual(close, .stoppedSession)
            await launch.value

            XCTAssertNil(fixture.model.activeProductSessionOwner)
            XCTAssertEqual(
                fixture.provider.currentStoppedSessionIDs(),
                [record.sessionID]
            )
            XCTAssertEqual(
                fixture.environment.currentStoppedSessionIDs(),
                phase == .reconnecting(attempt: 1)
                    ? [record.sessionID, record.sessionID]
                    : [record.sessionID]
            )
        }
    }

    func testOwningSceneCloseRetainsActualMobileContinuityPresentation()
        async throws
    {
        struct Mode {
            let pictureInPicture: MobilePictureInPictureLifecycle?
            let audioActive: Bool?
            let expectedPath: MobileContinuityPath
        }
        let modes = [
            Mode(
                pictureInPicture: .active,
                audioActive: nil,
                expectedPath: .pictureInPicture
            ),
            Mode(
                pictureInPicture: nil,
                audioActive: true,
                expectedPath: .audioOnly
            )
        ]

        for (index, mode) in modes.enumerated() {
            let fixture = try await makeSceneCloseFixture(keyID: 64 + index)
            let launch = Task {
                await fixture.model.launchSelectedApp(
                    in: fixture.attachment.workspace
                )
            }
            let record = try await waitForSessionStart(fixture.provider)
            driveSessionToStreaming(fixture.provider, record: record)
            await waitUntil {
                fixture.model.productSessionActualPhase == .streaming
            }
            let runtime = try makeMobileRuntimeState(
                sessionID: record.sessionID,
                mediaGeneration: 1,
                revision: 1,
                sceneActivity: .background,
                pictureInPictureLifecycle: mode.pictureInPicture,
                isAudioSessionActive: mode.audioActive,
                includesActualSceneAndDisplay: true
            )
            fixture.environment.yieldMobileRuntime(
                runtime,
                sessionID: record.sessionID
            )
            await waitUntil { fixture.model.mobileRuntimeState == runtime }
            XCTAssertEqual(
                fixture.model.mobileRuntimeState?.continuityPath,
                mode.expectedPath
            )

            let owner = try XCTUnwrap(
                fixture.model.activeProductSessionOwner
            )
            let close = await fixture.model.disconnectProductWorkspaceScene(
                fixture.attachment
            )
            XCTAssertEqual(close, .retainedSession)
            XCTAssertEqual(fixture.model.activeProductSessionOwner, owner)
            XCTAssertTrue(fixture.provider.currentStoppedSessionIDs().isEmpty)
            XCTAssertTrue(
                fixture.environment.currentStoppedSessionIDs().isEmpty
            )

            let didStop = await fixture.model.stopStream(
                in: fixture.attachment.workspace
            )
            XCTAssertTrue(didStop)
            await launch.value
            XCTAssertEqual(
                fixture.provider.currentStoppedSessionIDs(),
                [record.sessionID]
            )
        }
    }

    func testOwningSceneCloseRetainsSessionForAnotherSameWorkspaceAttachment()
        async throws
    {
        let fixture = try await makeSceneCloseFixture(
            keyID: 66,
            supportsMultipleWindows: false
        )
        let second = try fixture.model.connectProductWorkspaceScene(
            restoring: nil,
            supportsMultipleWindows: false
        )
        XCTAssertEqual(second.workspace, fixture.attachment.workspace)
        let launch = Task {
            await fixture.model.launchSelectedApp(
                in: fixture.attachment.workspace
            )
        }
        let record = try await waitForSessionStart(fixture.provider)
        driveSessionToStreaming(fixture.provider, record: record)
        await waitUntil {
            fixture.model.productSessionActualPhase == .streaming
        }

        let firstClose = await fixture.model.disconnectProductWorkspaceScene(
            fixture.attachment
        )
        XCTAssertEqual(firstClose, .retainedSession)
        XCTAssertEqual(
            fixture.model.activeProductSessionOwner?.sessionID,
            record.sessionID
        )
        XCTAssertTrue(fixture.provider.currentStoppedSessionIDs().isEmpty)

        let secondClose = await fixture.model.disconnectProductWorkspaceScene(
            second
        )
        XCTAssertEqual(secondClose, .stoppedSession)
        await launch.value
        XCTAssertEqual(
            fixture.provider.currentStoppedSessionIDs(),
            [record.sessionID]
        )
    }

    func testReplacedSceneCloseCannotStopReplacementWorkspaceSession()
        async throws
    {
        let fixture = try await makeSceneCloseFixture(keyID: 67)
        let initialClose = await fixture.model.disconnectProductWorkspaceScene(
            fixture.attachment
        )
        XCTAssertEqual(initialClose, .detached)
        let replacement = try fixture.model.connectProductWorkspaceScene(
            restoring: fixture.attachment.identity,
            supportsMultipleWindows: true
        )
        XCTAssertNotEqual(
            replacement.workspace.generation,
            fixture.attachment.workspace.generation
        )
        let launch = Task {
            await fixture.model.launchSelectedApp(in: replacement.workspace)
        }
        let record = try await waitForSessionStart(fixture.provider)
        driveSessionToStreaming(fixture.provider, record: record)
        await waitUntil {
            fixture.model.productSessionActualPhase == .streaming
        }

        let staleClose = await fixture.model.disconnectProductWorkspaceScene(
            fixture.attachment
        )
        XCTAssertEqual(staleClose, .rejectedStaleAttachment)
        XCTAssertEqual(
            fixture.model.activeProductSessionOwner,
            ProductSessionOwner(
                workspace: replacement.workspace,
                sessionID: record.sessionID
            )
        )
        XCTAssertTrue(fixture.provider.currentStoppedSessionIDs().isEmpty)

        let replacementClose = await fixture.model
            .disconnectProductWorkspaceScene(replacement)
        XCTAssertEqual(replacementClose, .stoppedSession)
        await launch.value
        XCTAssertEqual(
            fixture.provider.currentStoppedSessionIDs(),
            [record.sessionID]
        )
    }

    func testAlreadyStoppingOwnerSceneCloseJoinsExistingTeardown()
        async throws
    {
        let fixture = try await makeSceneCloseFixture(keyID: 68)
        let launch = Task {
            await fixture.model.launchSelectedApp(
                in: fixture.attachment.workspace
            )
        }
        let record = try await waitForSessionStart(fixture.provider)
        driveSessionToStreaming(fixture.provider, record: record)
        await waitUntil {
            fixture.model.productSessionActualPhase == .streaming
        }

        fixture.environment.blockNextStop()
        let directStop = Task {
            await fixture.model.stopStream(in: fixture.attachment.workspace)
        }
        await waitUntil { fixture.environment.hasBlockedStop() }
        XCTAssertNil(fixture.model.activeProductSessionOwner)
        XCTAssertEqual(fixture.model.productSessionActualPhase, .stopping)

        let close = Task {
            await fixture.model.disconnectProductWorkspaceScene(
                fixture.attachment
            )
        }
        for _ in 0..<3 { await Task.yield() }
        XCTAssertTrue(fixture.provider.currentStoppedSessionIDs().isEmpty)
        fixture.environment.resumeBlockedStop()

        let directStopResult = await directStop.value
        let closeResult = await close.value
        XCTAssertTrue(directStopResult)
        XCTAssertEqual(closeResult, .stoppedSession)
        await launch.value
        XCTAssertEqual(
            fixture.environment.currentStoppedSessionIDs(),
            [record.sessionID]
        )
        XCTAssertEqual(
            fixture.provider.currentStoppedSessionIDs(),
            [record.sessionID]
        )
    }

    func testExplicitWorkspaceOwnerRejectsNonOwnerStop() async throws {
        let provider = ControlledSessionControlProvider()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 32,
                    key: Data(repeating: 0x32, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let hostID = try XCTUnwrap(model.selectedHostID)
        let appID = try XCTUnwrap(model.selectedAppID)
        let workspace = try model.workspaceRegistry.create(
            restoration: ProductWorkspaceRestorationState(
                selectedHostID: hostID,
                selectedAppID: appID
            )
        )

        let launch = Task { await model.launchSelectedApp(in: workspace) }
        let record = try await waitForSessionStart(provider)
        let owner = try XCTUnwrap(model.activeProductSessionOwner)
        XCTAssertEqual(owner.workspace, workspace)
        XCTAssertEqual(owner.sessionID, record.sessionID)
        XCTAssertEqual(
            model.sessionCommandState(in: workspace).stop,
            .available
        )
        XCTAssertEqual(
            model.sessionCommandState(in: model.primaryWorkspaceReference).stop,
            .unavailable(.ownedByAnotherWorkspace)
        )

        let nonOwnerStop = await model.stopStream(
            in: model.primaryWorkspaceReference
        )
        XCTAssertFalse(nonOwnerStop)
        XCTAssertEqual(model.activeProductSessionOwner, owner)
        XCTAssertTrue(provider.currentStoppedSessionIDs().isEmpty)

        let ownerStop = await model.stopStream(in: workspace)
        XCTAssertTrue(ownerStop)
        await launch.value
        XCTAssertNil(model.activeProductSessionOwner)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
    }

    func testSessionCommandStateTracksReconnectAndRemoteTermination()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 36,
                    key: Data(repeating: 0x36, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let workspace = model.primaryWorkspaceReference
        XCTAssertEqual(model.sessionCommandState(in: workspace).launch, .available)

        let launch = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        XCTAssertEqual(model.productSessionActualPhase, .launching)
        XCTAssertEqual(model.sessionCommandState(in: workspace).launch, .inProgress)
        XCTAssertEqual(model.sessionCommandState(in: workspace).stop, .available)

        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.productSessionActualPhase == .streaming }
        XCTAssertEqual(
            model.sessionCommandState(in: workspace).launch,
            .unavailable(.sessionActive)
        )

        provider.yield(
            .reconnecting(attempt: 1, reason: "control_unavailable"),
            sessionID: record.sessionID
        )
        await waitUntil {
            model.productSessionActualPhase == .reconnecting(attempt: 1)
        }
        let reconnecting = model.sessionCommandState(in: workspace)
        XCTAssertEqual(reconnecting.reconnect, .inProgress)
        XCTAssertEqual(reconnecting.resume, .inProgress)
        XCTAssertEqual(reconnecting.stop, .available)
        let interruption = try XCTUnwrap(model.streamProductIssue(in: workspace))
        XCTAssertEqual(interruption.code, .streamInterrupted)
        XCTAssertEqual(interruption.action?.kind, .reconnectStream)
        XCTAssertEqual(
            interruption.action?.scope,
            .session(workspace: workspace, sessionID: record.sessionID)
        )
        let interruptionAction = try XCTUnwrap(interruption.action)
        XCTAssertFalse(model.canPerformProductAction(interruptionAction))

        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launch.value

        let terminated = model.sessionCommandState(in: workspace)
        XCTAssertEqual(terminated.phase, .remoteTerminated)
        XCTAssertEqual(terminated.launch, .available)
        XCTAssertEqual(terminated.reconnect, .available)
        XCTAssertEqual(terminated.resume, .unavailable(.terminalSession))
        XCTAssertEqual(terminated.stop, .unavailable(.noActiveSession))
        let issue = try XCTUnwrap(model.streamProductIssue(in: workspace))
        XCTAssertEqual(issue.code, .streamTerminated)
        XCTAssertEqual(issue.action?.kind, .reconnectStream)
        let issueAction = try XCTUnwrap(issue.action)
        XCTAssertTrue(model.canPerformProductAction(issueAction))
    }

    func testRemoteTerminationActionRelaunchesOnceAndRejectsOldSessionToken()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 39,
                    key: Data(repeating: 0x39, count: 16)
                )),
                .success(RemoteInputKeyMaterial(
                    keyID: 40,
                    key: Data(repeating: 0x40, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let workspace = model.primaryWorkspaceReference

        let firstLaunch = Task { await model.launchSelectedApp(in: workspace) }
        let first = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: first)
        await waitUntil { model.productSessionActualPhase == .streaming }
        provider.yield(.terminated(reason: nil), sessionID: first.sessionID)
        provider.finish(sessionID: first.sessionID)
        await firstLaunch.value

        let issue = try XCTUnwrap(model.streamProductIssue(in: workspace))
        let action = try XCTUnwrap(issue.action)
        XCTAssertTrue(model.canPerformProductAction(action))

        let actionTask = Task { await model.performProductAction(action) }
        await waitUntil { provider.currentStartRecords().count == 2 }
        let second = try XCTUnwrap(provider.currentStartRecords().last)
        XCTAssertNotEqual(second.sessionID, first.sessionID)
        XCTAssertNil(model.streamProductIssue(in: workspace))

        let replay = await model.performProductAction(action)
        XCTAssertEqual(replay.issue?.code, .staleAction)
        XCTAssertEqual(provider.currentStartRecords().count, 2)

        let didStop = await model.stopStream(in: workspace)
        XCTAssertTrue(didStop)
        let actionResult = await actionTask.value
        XCTAssertEqual(actionResult, .performed)
        XCTAssertEqual(
            provider.currentStoppedSessionIDs(),
            [second.sessionID]
        )
    }

    func testTerminalActionRejectsReplacedWorkspaceGeneration()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 41,
                    key: Data(repeating: 0x41, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let workspace = try model.workspaceRegistry.create(
            restoration: ProductWorkspaceRestorationState(
                selectedHostID: try XCTUnwrap(model.selectedHostID),
                selectedAppID: try XCTUnwrap(model.selectedAppID)
            )
        )
        let launch = Task { await model.launchSelectedApp(in: workspace) }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.productSessionActualPhase == .streaming }
        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launch.value

        let action = try XCTUnwrap(
            model.streamProductIssue(in: workspace)?.action
        )
        let replacement = try model.workspaceRegistry.replace(workspace)
        XCTAssertNotEqual(replacement.generation, workspace.generation)
        XCTAssertFalse(model.canPerformProductAction(action))

        let result = await model.performProductAction(action)
        XCTAssertEqual(result.issue?.code, .staleAction)
        XCTAssertEqual(provider.currentStartRecords().count, 1)
        XCTAssertNil(model.activeProductSessionOwner)
        XCTAssertNil(model.streamProductIssue(in: replacement))
    }

    func testReconnectExhaustionBecomesTerminalReconnectCommandState()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let environment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: environment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 37,
                    key: Data(repeating: 0x37, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launch = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.productSessionActualPhase == .streaming }

        environment.finish(
            sessionID: record.sessionID,
            throwing: StreamNegotiationFailure(
                code: .reconnectExhausted,
                subsystem: "reconnect",
                message: "Reconnect budget exhausted."
            )
        )
        await launch.value

        let terminal = model.sessionCommandState(
            in: model.primaryWorkspaceReference
        )
        XCTAssertEqual(terminal.phase, .reconnectExhausted)
        XCTAssertEqual(terminal.launch, .available)
        XCTAssertEqual(terminal.reconnect, .available)
        XCTAssertEqual(terminal.resume, .unavailable(.terminalSession))
        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
    }

    func testSessionCommandStateRemainsStoppingDuringUnownedTeardown()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let environment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: environment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 38,
                    key: Data(repeating: 0x38, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launch = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.productSessionActualPhase == .streaming }

        environment.blockNextStop()
        let stop = Task {
            await model.stopStream(in: model.primaryWorkspaceReference)
        }
        await waitUntil { environment.hasBlockedStop() }
        XCTAssertNil(model.activeProductSessionOwner)
        let stopping = model.sessionCommandState(
            in: model.primaryWorkspaceReference
        )
        XCTAssertEqual(stopping.phase, .stopping)
        XCTAssertEqual(stopping.stop, .inProgress)
        XCTAssertEqual(stopping.launch, .unavailable(.commandInProgress))

        environment.resumeBlockedStop()
        let didStop = await stop.value
        XCTAssertTrue(didStop)
        await launch.value
        let idle = model.sessionCommandState(in: model.primaryWorkspaceReference)
        XCTAssertEqual(idle.phase, .idle)
        XCTAssertEqual(idle.launch, .available)
    }

    func testConcurrentStopActionAndDirectCallersShareOneTeardownResult()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let environment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: environment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 42,
                    key: Data(repeating: 0x42, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let workspace = model.primaryWorkspaceReference
        let launch = Task { await model.launchSelectedApp(in: workspace) }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.productSessionActualPhase == .streaming }
        let owner = try XCTUnwrap(model.activeProductSessionOwner)
        let issue = ProductIssue(
            code: .streamStopFailed,
            actionScope: .session(
                workspace: workspace,
                sessionID: owner.sessionID
            )
        )
        try model.workspaceRegistry.update(workspace) {
            $0.presentation.issue = issue
        }
        let token = try XCTUnwrap(issue.action)

        environment.blockNextStop()
        let firstAction = Task { await model.performProductAction(token) }
        await waitUntil { environment.hasBlockedStop() }
        XCTAssertNil(model.activeProductSessionOwner)
        XCTAssertNil(model.streamProductIssue(in: workspace))

        let repeatedAction = Task { await model.performProductAction(token) }
        let directStop = Task { await model.stopStream(in: workspace) }
        for _ in 0..<3 { await Task.yield() }
        XCTAssertEqual(provider.currentStartRecords().count, 1)
        XCTAssertEqual(environment.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertTrue(provider.currentStoppedSessionIDs().isEmpty)

        environment.resumeBlockedStop()
        let firstActionResult = await firstAction.value
        let repeatedActionResult = await repeatedAction.value
        let directStopResult = await directStop.value
        XCTAssertEqual(firstActionResult, .performed)
        XCTAssertEqual(repeatedActionResult, .performed)
        XCTAssertTrue(directStopResult)
        await launch.value

        XCTAssertEqual(environment.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(model.productSessionActualPhase, .idle)
        let replay = await model.performProductAction(token)
        XCTAssertEqual(replay.issue?.code, .staleAction)
        let repeatedStopResult = await model.stopStream(in: workspace)
        XCTAssertFalse(repeatedStopResult)
    }

    func testWorkspaceReplacementCannotJoinOrLaunchAcrossInFlightStop()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let environment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: environment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 43,
                    key: Data(repeating: 0x43, count: 16)
                )),
                .success(RemoteInputKeyMaterial(
                    keyID: 44,
                    key: Data(repeating: 0x44, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let workspace = model.primaryWorkspaceReference
        let firstLaunch = Task { await model.launchSelectedApp(in: workspace) }
        let first = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: first)
        await waitUntil { model.productSessionActualPhase == .streaming }

        environment.blockNextStop()
        let stop = Task { await model.stopStream(in: workspace) }
        await waitUntil { environment.hasBlockedStop() }
        let replacement = try model.workspaceRegistry.replace(workspace)

        let staleStopResult = await model.stopStream(in: workspace)
        let replacementStopResult = await model.stopStream(in: replacement)
        XCTAssertFalse(staleStopResult)
        XCTAssertFalse(replacementStopResult)
        await model.launchSelectedApp(in: replacement)
        XCTAssertEqual(provider.currentStartRecords().count, 1)

        environment.resumeBlockedStop()
        let stopResult = await stop.value
        XCTAssertTrue(stopResult)
        await firstLaunch.value
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [first.sessionID])
        XCTAssertEqual(environment.currentStoppedSessionIDs(), [first.sessionID])

        let replacementLaunch = Task {
            await model.launchSelectedApp(in: replacement)
        }
        await waitUntil { provider.currentStartRecords().count == 2 }
        let second = try XCTUnwrap(provider.currentStartRecords().last)
        XCTAssertNotEqual(second.sessionID, first.sessionID)
        XCTAssertEqual(model.activeProductSessionOwner?.workspace, replacement)
        XCTAssertEqual(model.activeProductSessionOwner?.sessionID, second.sessionID)

        let replacementDidStop = await model.stopStream(in: replacement)
        XCTAssertTrue(replacementDidStop)
        await replacementLaunch.value
        XCTAssertEqual(
            provider.currentStoppedSessionIDs(),
            [first.sessionID, second.sessionID]
        )
    }

    func testStaleTerminationCannotRelabelOrStopReplacementSession()
        async throws
    {
        let provider = ControlledSessionControlProvider(
            retainsStoppedContinuation: true
        )
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 45,
                    key: Data(repeating: 0x45, count: 16)
                )),
                .success(RemoteInputKeyMaterial(
                    keyID: 46,
                    key: Data(repeating: 0x46, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let workspace = model.primaryWorkspaceReference

        let firstLaunch = Task { await model.launchSelectedApp(in: workspace) }
        let first = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: first)
        await waitUntil { model.productSessionActualPhase == .streaming }

        let firstDidStop = await model.stopStream(in: workspace)
        XCTAssertTrue(firstDidStop)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [first.sessionID])

        let secondLaunch = Task { await model.launchSelectedApp(in: workspace) }
        await waitUntil { provider.currentStartRecords().count == 2 }
        let second = try XCTUnwrap(provider.currentStartRecords().last)
        driveSessionToStreaming(provider, record: second)
        await waitUntil {
            model.activeProductSessionOwner?.sessionID == second.sessionID
                && model.productSessionActualPhase == .streaming
        }

        provider.yield(.terminated(reason: nil), sessionID: first.sessionID)
        await firstLaunch.value
        provider.finish(sessionID: first.sessionID)

        XCTAssertEqual(
            model.activeProductSessionOwner,
            ProductSessionOwner(workspace: workspace, sessionID: second.sessionID)
        )
        XCTAssertEqual(model.productSessionActualPhase, .streaming)
        XCTAssertTrue(model.session.isStreaming)
        XCTAssertNil(model.streamProductIssue(in: workspace))
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [first.sessionID])

        let secondDidStop = await model.stopStream(in: workspace)
        XCTAssertTrue(secondDidStop)
        provider.finish(sessionID: second.sessionID)
        await secondLaunch.value
        XCTAssertNil(model.activeProductSessionOwner)
        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertEqual(
            provider.currentStoppedSessionIDs(),
            [first.sessionID, second.sessionID]
        )
    }

    func testWorkspaceReplacementCannotClaimOwnerAndTriggersCheckedCleanup()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 33,
                    key: Data(repeating: 0x33, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let workspace = try model.workspaceRegistry.create(
            restoration: ProductWorkspaceRestorationState(
                selectedHostID: try XCTUnwrap(model.selectedHostID),
                selectedAppID: try XCTUnwrap(model.selectedAppID)
            )
        )
        let launch = Task { await model.launchSelectedApp(in: workspace) }
        let record = try await waitForSessionStart(provider)

        let replacement = try model.workspaceRegistry.replace(workspace)
        XCTAssertEqual(replacement.id, workspace.id)
        XCTAssertNotEqual(replacement.generation, workspace.generation)
        let replacementStop = await model.stopStream(in: replacement)
        let staleStop = await model.stopStream(in: workspace)
        XCTAssertFalse(replacementStop)
        XCTAssertFalse(staleStop)
        XCTAssertEqual(model.activeProductSessionOwner?.workspace, workspace)

        provider.yield(
            .launchAccepted(makeSessionLaunchResponse()),
            sessionID: record.sessionID
        )
        await launch.value

        XCTAssertNil(model.activeProductSessionOwner)
        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertNotEqual(
            model.activeProductSessionOwner?.workspace,
            replacement
        )
    }

    func testMediaEventDetectsReplacedWorkspaceAndStopsOwnedSession()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let environment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: environment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 35,
                    key: Data(repeating: 0x35, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let workspace = try model.workspaceRegistry.create(
            restoration: ProductWorkspaceRestorationState(
                selectedHostID: try XCTUnwrap(model.selectedHostID),
                selectedAppID: try XCTUnwrap(model.selectedAppID)
            )
        )
        let launch = Task { await model.launchSelectedApp(in: workspace) }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        let replacement = try model.workspaceRegistry.replace(workspace)
        environment.yieldFeedback(
            .led(ControllerLEDFeedback(
                controllerID: "stale-owner",
                red: 1,
                green: 2,
                blue: 3
            )),
            sessionID: record.sessionID
        )
        await waitUntil { model.activeProductSessionOwner == nil }
        await launch.value

        XCTAssertNil(model.activeProductSessionOwner)
        XCTAssertFalse(model.hasActiveStreamSession)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(environment.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertNil(model.latestRemoteInputFeedback)
        XCTAssertNotEqual(
            model.activeProductSessionOwner?.workspace,
            replacement
        )
    }

    func testRemoteTerminationClearsWorkspaceSessionAndMediaOwnership()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let environment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: environment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 34,
                    key: Data(repeating: 0x34, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let launch = Task { await model.launchSelectedApp() }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }
        let activeEnvironment = await environment.snapshot()
        XCTAssertEqual(
            model.activeProductSessionOwner?.sessionID,
            activeEnvironment.sessionID
        )
        let workspace = model.primaryWorkspaceReference
        XCTAssertTrue(model.setStreamOverlayVisibility(.visible, in: workspace))
        XCTAssertTrue(model.requestStopStreamConfirmation(in: workspace))
        XCTAssertEqual(
            model.stopStreamConfirmationSessionID(in: workspace),
            record.sessionID
        )

        provider.yield(.terminated(reason: nil), sessionID: record.sessionID)
        provider.finish(sessionID: record.sessionID)
        await launch.value

        XCTAssertNil(model.activeProductSessionOwner)
        XCTAssertFalse(model.hasActiveStreamSession)
        let stoppedEnvironment = await environment.snapshot()
        XCTAssertNil(stoppedEnvironment.sessionID)
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)
        XCTAssertEqual(
            model.workspaceState(for: workspace)?.presentation.streamOverlay,
            .hidden
        )
        XCTAssertNil(
            model.workspaceState(for: workspace)?.presentation.dialog
        )
        XCTAssertNil(model.stopStreamConfirmationSessionID(in: workspace))
    }

    func testOwnerScopedOverlayControlsMacFocusAndRejectsOtherWorkspaces()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let environment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: environment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 45,
                    key: Data(repeating: 0x45, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let ownerWorkspace = model.primaryWorkspaceReference
        let nonOwnerWorkspace = try model.workspaceRegistry.create()
        let lifecycle = makePlatformLifecycle(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 2_560, height: 1_440)
        )
        model.applyPlatformLifecycle(lifecycle)

        let launch = Task {
            await model.launchSelectedApp(in: ownerWorkspace)
        }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.macInputSurfacePolicy.admitsInput }
        XCTAssertEqual(
            model.streamOverlayVisibility(in: ownerWorkspace),
            .hidden
        )

        XCTAssertFalse(model.setStreamOverlayVisibility(
            .visible,
            in: nonOwnerWorkspace
        ))
        XCTAssertTrue(model.setStreamOverlayVisibility(
            .visible,
            in: ownerWorkspace
        ))
        XCTAssertEqual(
            model.streamOverlayVisibility(in: ownerWorkspace),
            .visible
        )
        XCTAssertFalse(model.macInputSurfacePolicy.admitsInput)
        XCTAssertFalse(model.setStreamOverlayVisibility(
            .hidden,
            in: nonOwnerWorkspace
        ))
        XCTAssertEqual(
            model.streamOverlayVisibility(in: ownerWorkspace),
            .visible
        )

        XCTAssertTrue(model.setStreamOverlayVisibility(
            .hidden,
            in: ownerWorkspace
        ))
        await waitUntil { model.macInputSurfacePolicy.admitsInput }

        let replacement = try model.workspaceRegistry.replace(ownerWorkspace)
        XCTAssertFalse(model.setStreamOverlayVisibility(
            .visible,
            in: ownerWorkspace
        ))
        XCTAssertFalse(model.setStreamOverlayVisibility(
            .visible,
            in: replacement
        ))
        XCTAssertEqual(
            model.streamOverlayVisibility(in: replacement),
            .hidden
        )

        environment.yieldFeedback(
            .led(ControllerLEDFeedback(
                controllerID: "replaced-overlay-owner",
                red: 1,
                green: 2,
                blue: 3
            )),
            sessionID: record.sessionID
        )
        await waitUntil { model.activeProductSessionOwner == nil }
        await launch.value
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(environment.currentStoppedSessionIDs(), [record.sessionID])
    }

    func testStopConfirmationCancelAndConfirmedDirectStopShareTeardown()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let environment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: environment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 46,
                    key: Data(repeating: 0x46, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let workspace = model.primaryWorkspaceReference
        let launch = Task { await model.launchSelectedApp(in: workspace) }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.productSessionActualPhase == .streaming }

        XCTAssertTrue(model.setStreamOverlayVisibility(.visible, in: workspace))
        XCTAssertTrue(model.requestStopStreamConfirmation(in: workspace))
        XCTAssertEqual(
            model.stopStreamConfirmationSessionID(in: workspace),
            record.sessionID
        )
        XCTAssertTrue(model.cancelStopStreamConfirmation(in: workspace))
        XCTAssertNil(model.stopStreamConfirmationSessionID(in: workspace))
        XCTAssertEqual(model.activeProductSessionOwner?.sessionID, record.sessionID)
        XCTAssertTrue(provider.currentStoppedSessionIDs().isEmpty)
        XCTAssertTrue(environment.currentStoppedSessionIDs().isEmpty)

        XCTAssertTrue(model.requestStopStreamConfirmation(in: workspace))
        environment.blockNextStop()
        let confirmedStop = try XCTUnwrap(
            model.beginConfirmedStopStream(in: workspace)
        )
        let directStop = Task { await model.stopStream(in: workspace) }
        await waitUntil { environment.hasBlockedStop() }
        XCTAssertNil(model.stopStreamConfirmationSessionID(in: workspace))
        XCTAssertEqual(environment.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertTrue(provider.currentStoppedSessionIDs().isEmpty)

        environment.resumeBlockedStop()
        let confirmedStopResult = await confirmedStop.value
        let directStopResult = await directStop.value
        XCTAssertTrue(confirmedStopResult)
        XCTAssertTrue(directStopResult)
        await launch.value
        XCTAssertEqual(environment.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(
            model.workspaceState(for: workspace)?.presentation.streamOverlay,
            .hidden
        )
        XCTAssertNil(model.workspaceState(for: workspace)?.presentation.dialog)
    }

    func testVisionEscapeShowsOwnerOverlayWithoutRemoteSerialization()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let environment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: environment,
            tvVisionPlatform: .visionOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 47,
                    key: Data(repeating: 0x47, count: 16)
                ))
            ])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()
        let workspace = model.primaryWorkspaceReference
        let nonOwnerWorkspace = try model.workspaceRegistry.create()
        let launch = Task { await model.launchSelectedApp(in: workspace) }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.session.isStreaming }

        let geometry = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 1,
            revision: 1
        )
        model.receiveTVVisionGeometryUpdate(geometry)
        await waitUntil { model.visionInputCaptureEnabled(in: workspace) }
        let escape = try VisionSurfaceSystemInteractionEvent(
            surfaceGeneration: geometry.surfaceGeneration,
            decision: VisionSystemInteractionDecision.resolve(.escape)
        )
        let inputCount = environment.currentSentInputApplications().count

        model.receiveVisionSystemInteractionEvent(
            escape,
            in: nonOwnerWorkspace
        )
        XCTAssertNil(model.visionSystemInteractionDecisionState)
        XCTAssertEqual(model.streamOverlayVisibility(in: workspace), .hidden)
        XCTAssertTrue(model.visionInputCaptureEnabled(in: workspace))

        model.receiveVisionSystemInteractionEvent(escape, in: workspace)
        XCTAssertEqual(
            model.visionSystemInteractionDecisionState,
            .resolve(.escape)
        )
        await waitUntil {
            model.streamOverlayVisibility(in: workspace) == .visible
                && !model.visionInputReleasePending
        }
        XCTAssertFalse(model.visionInputCaptureEnabled(in: workspace))
        XCTAssertEqual(
            environment.currentSentInputApplications().count,
            inputCount
        )

        let didStop = await model.stopStream(in: workspace)
        XCTAssertTrue(didStop)
        await launch.value
    }

    func testTVVisionAdaptersRejectActiveNonPrimaryWorkspaceOwnership()
        async throws
    {
        for (index, platform) in [
            TVVisionPlatform.tvOS,
            TVVisionPlatform.visionOS
        ].enumerated() {
            let provider = ControlledSessionControlProvider()
            let environment = ControlledSessionMediaEnvironment()
            let model = makeLaunchReadyModel(
                sessionControlProvider: provider,
                sessionMediaEnvironment: environment,
                tvVisionPlatform: platform,
                launchClient: StubStreamLaunchClient(),
                remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                    .success(RemoteInputKeyMaterial(
                        keyID: 70 + index,
                        key: Data(repeating: UInt8(70 + index), count: 16)
                    ))
                ])
            )
            await model.loadInitialState()
            await model.refreshAppsForSelectedHost()
            let hostID = try XCTUnwrap(model.selectedHostID)
            let appID = try XCTUnwrap(model.selectedAppID)
            let nonPrimary = try model.workspaceRegistry.create(
                restoration: ProductWorkspaceRestorationState(
                    selectedHostID: hostID,
                    selectedAppID: appID
                )
            )
            let launch = Task {
                await model.launchSelectedApp(in: nonPrimary)
            }
            let record = try await waitForSessionStart(provider)
            driveSessionToStreaming(provider, record: record)
            await waitUntil { model.session.isStreaming }
            XCTAssertEqual(
                model.activeProductSessionOwner?.workspace,
                nonPrimary
            )

            let geometry = try makeTVVisionActiveGeometryUpdate(
                platform: platform,
                surfaceGeneration: 1,
                revision: 1
            )
            model.receiveTVVisionGeometryUpdate(geometry)

            switch platform {
            case .tvOS:
                XCTAssertEqual(
                    model.tvStreamControlPresentationState(in: nonPrimary)
                        .focus,
                    .unavailable
                )
                model.setTVStreamWorkspaceVisible(true, in: nonPrimary)
                model.receiveTVRemoteReservedCommand(
                    .backMenu,
                    in: nonPrimary
                )
                XCTAssertEqual(
                    model.receiveTVRemoteSurfacePressEvent(
                        try makeTVRemoteSurfacePress(
                            geometry.surfaceGeneration,
                            1,
                            .select,
                            .began
                        ),
                        in: nonPrimary
                    ),
                    .local
                )
            case .visionOS:
                XCTAssertEqual(
                    model.visionStreamControlPresentationState(in: nonPrimary)
                        .input,
                    .unavailable
                )
                XCTAssertFalse(
                    model.visionInputCaptureEnabled(in: nonPrimary)
                )
                let input = try VisionSurfaceInputEvent(
                    surfaceGeneration: geometry.surfaceGeneration,
                    path: .pointer,
                    event: .pointer(.absoluteMove(
                        point: RemotePoint(x: 1, y: 1),
                        referenceSize: PixelSize(width: 1_920, height: 1_080),
                        buttons: []
                    ))
                )
                XCTAssertEqual(
                    model.receiveVisionSurfaceInputEvent(
                        input,
                        in: nonPrimary
                    ),
                    .local
                )
            }

            let didStop = await model.stopStream(in: nonPrimary)
            XCTAssertTrue(didStop)
            await launch.value
        }
    }

    func testTwoWorkspaceApplicationMatrixKeepsLocalStateAndSharesRepositories()
        async throws
    {
        let settingsRepository = InMemoryAppSettingsRepository()
        let model = makeLaunchReadyModel(
            sessionControlProvider: ControlledSessionControlProvider(),
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: []),
            settingsRepository: settingsRepository
        )
        let primaryScene = try model.connectProductWorkspaceScene(
            restoring: nil,
            supportsMultipleWindows: true
        )
        let secondaryScene = try model.connectProductWorkspaceScene(
            restoring: nil,
            supportsMultipleWindows: true
        )
        XCTAssertNotEqual(primaryScene.workspace, secondaryScene.workspace)

        await model.loadInitialState(in: primaryScene.workspace)
        await model.refreshAppsForSelectedHost(in: primaryScene.workspace)
        let originalHostID = try XCTUnwrap(
            model.selectedHostID(in: primaryScene.workspace)
        )
        let sharedApps = model.selectedApps(in: primaryScene.workspace)
        XCTAssertFalse(sharedApps.isEmpty)
        XCTAssertEqual(
            model.selectedApps(in: secondaryScene.workspace),
            sharedApps
        )
        XCTAssertEqual(
            model.catalogState(for: primaryScene.workspace)?.phase,
            .current
        )
        XCTAssertEqual(
            model.catalogState(for: secondaryScene.workspace)?.phase,
            .cached
        )

        XCTAssertTrue(model.setNavigationSelection(
            .stream,
            in: primaryScene.workspace
        ))
        XCTAssertTrue(model.setNavigationSelection(
            .settings,
            in: secondaryScene.workspace
        ))
        XCTAssertTrue(model.presentAddHostSheet(in: secondaryScene.workspace))
        let secondaryDraft = ManualHostDraft(
            name: "Secondary Draft",
            address: "secondary.local"
        )
        model.setManualHostDraft(
            secondaryDraft,
            in: secondaryScene.workspace
        )
        XCTAssertEqual(
            model.navigationSelection(in: primaryScene.workspace),
            .stream
        )
        XCTAssertEqual(
            model.navigationSelection(in: secondaryScene.workspace),
            .settings
        )
        XCTAssertNil(model.workspaceSheet(in: primaryScene.workspace))
        XCTAssertEqual(
            model.workspaceSheet(in: secondaryScene.workspace),
            .addHost
        )

        model.settings.stream.frameRate = 144
        await model.saveSettings()
        let persistedSettings = try await settingsRepository.loadSettings()
        XCTAssertEqual(persistedSettings.stream.frameRate, 144)
        XCTAssertEqual(
            model.navigationSelection(in: secondaryScene.workspace),
            .settings
        )

        XCTAssertTrue(model.presentAddHostSheet(in: primaryScene.workspace))
        model.setManualHostDraft(
            ManualHostDraft(name: "Shared Host", address: "shared.local"),
            in: primaryScene.workspace
        )
        guard case let .succeeded(sharedHostID) = await model.addManualHost(
            in: primaryScene.workspace
        ) else {
            return XCTFail("Expected shared host mutation to succeed")
        }
        XCTAssertEqual(model.hosts.count, 2)
        XCTAssertTrue(model.hosts.contains { $0.id == sharedHostID })
        XCTAssertEqual(
            model.selectedHostID(in: primaryScene.workspace),
            sharedHostID
        )
        XCTAssertEqual(
            model.selectedHostID(in: secondaryScene.workspace),
            originalHostID
        )
        XCTAssertEqual(
            model.workspaceState(for: secondaryScene.workspace)?
                .hostLibrary.manualHostDraft,
            secondaryDraft
        )
        XCTAssertEqual(
            model.workspaceSheet(in: secondaryScene.workspace),
            .addHost
        )

        let initialSecondaryClose = await model.disconnectProductWorkspaceScene(
            secondaryScene
        )
        XCTAssertEqual(initialSecondaryClose, .detached)
        let replacementScene = try model.connectProductWorkspaceScene(
            restoring: secondaryScene.identity,
            supportsMultipleWindows: true
        )
        let replacement = replacementScene.workspace
        XCTAssertEqual(model.navigationSelection(in: replacement), .settings)
        XCTAssertEqual(model.selectedHostID(in: replacement), originalHostID)
        XCTAssertNil(model.workspaceSheet(in: replacement))
        XCTAssertFalse(model.setNavigationSelection(
            .diagnostics,
            in: secondaryScene.workspace
        ))
        XCTAssertFalse(model.setSelectedHostID(
            sharedHostID,
            in: secondaryScene.workspace
        ))
        XCTAssertFalse(model.presentAddHostSheet(in: secondaryScene.workspace))
        XCTAssertNil(model.requestHostRemoval(in: secondaryScene.workspace))
        let staleClose = await model.disconnectProductWorkspaceScene(
            secondaryScene
        )
        let replacementClose = await model.disconnectProductWorkspaceScene(
            replacementScene
        )
        let primaryClose = await model.disconnectProductWorkspaceScene(
            primaryScene
        )
        XCTAssertEqual(staleClose, .rejectedStaleAttachment)
        XCTAssertEqual(replacementClose, .detached)
        XCTAssertEqual(primaryClose, .detached)
    }

    func testTwoWorkspaceApplicationMatrixRejectsNonOwnerCommandsAndClosesOwner()
        async throws
    {
        let provider = ControlledSessionControlProvider()
        let environment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: environment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 72,
                    key: Data(repeating: 0x72, count: 16)
                ))
            ])
        )
        let nonOwnerScene = try model.connectProductWorkspaceScene(
            restoring: nil,
            supportsMultipleWindows: true
        )
        let ownerScene = try model.connectProductWorkspaceScene(
            restoring: nil,
            supportsMultipleWindows: true
        )
        await model.loadInitialState(in: nonOwnerScene.workspace)
        await model.refreshAppsForSelectedHost(in: nonOwnerScene.workspace)

        let launch = Task {
            await model.launchSelectedApp(in: ownerScene.workspace)
        }
        let record = try await waitForSessionStart(provider)
        driveSessionToStreaming(provider, record: record)
        await waitUntil { model.productSessionActualPhase == .streaming }
        let owner = try XCTUnwrap(model.activeProductSessionOwner)
        XCTAssertEqual(owner.workspace, ownerScene.workspace)
        XCTAssertEqual(
            model.macOSContentMode(in: ownerScene.workspace),
            .stream
        )
        let nonOwnerHost = try XCTUnwrap(
            model.selectedHost(in: nonOwnerScene.workspace)
        )
        XCTAssertEqual(
            model.macOSContentMode(in: nonOwnerScene.workspace),
            .catalog(hostID: nonOwnerHost.id)
        )
        XCTAssertEqual(
            model.sessionCommandState(in: nonOwnerScene.workspace).stop,
            .unavailable(.ownedByAnotherWorkspace)
        )
        XCTAssertFalse(model.setStreamOverlayVisibility(
            .visible,
            in: nonOwnerScene.workspace
        ))
        let nonOwnerStop = await model.stopStream(in: nonOwnerScene.workspace)
        XCTAssertFalse(nonOwnerStop)
        XCTAssertEqual(model.activeProductSessionOwner, owner)
        XCTAssertTrue(provider.currentStoppedSessionIDs().isEmpty)

        let nonOwnerClose = await model.disconnectProductWorkspaceScene(
            nonOwnerScene
        )
        XCTAssertEqual(nonOwnerClose, .detached)
        XCTAssertEqual(model.activeProductSessionOwner, owner)
        XCTAssertTrue(provider.currentStoppedSessionIDs().isEmpty)

        let ownerClose = await model.disconnectProductWorkspaceScene(ownerScene)
        XCTAssertEqual(ownerClose, .stoppedSession)
        await launch.value
        XCTAssertNil(model.activeProductSessionOwner)
        XCTAssertEqual(provider.currentStoppedSessionIDs(), [record.sessionID])
        XCTAssertEqual(
            environment.currentStoppedSessionIDs(),
            [record.sessionID]
        )
    }

    func testAccessibilityApplicationMatrixConnectsWorkspaceSemanticsAndPolicies()
        async throws
    {
        let model = makeLaunchReadyModel(
            sessionControlProvider: ControlledSessionControlProvider(),
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [])
        )
        await model.loadInitialState()
        await model.refreshAppsForSelectedHost()

        let workspace = model.primaryWorkspaceReference
        let workspaceState = try XCTUnwrap(
            model.workspaceState(for: workspace)
        )
        let selectedHost = try XCTUnwrap(model.selectedHost(in: workspace))
        let apps = model.selectedApps(in: workspace)
        XCTAssertFalse(apps.isEmpty)

        let hostSurface = ProductHostLibrarySurface(
            library: workspaceState.hostLibrary,
            hostCount: model.hosts.count,
            selectedHost: selectedHost
        )
        let pairingSurface = ProductPairingSurface(
            selectedHost: selectedHost,
            pairing: workspaceState.pairing,
            transportAvailable: model.isPairingTransportAvailable,
            isPINValid: false
        )
        let catalogSurface = ProductAppCatalogSurface(
            catalog: workspaceState.catalog,
            selectedHost: selectedHost,
            appCount: apps.count
        )
        let descriptorGroups: [[ProductSemanticDescriptor]] = [
            ProductHostSemanticSurface(
                surface: hostSurface,
                hostCount: model.hosts.count
            ).items.map(\.descriptor),
            ProductPairingSemanticSurface(
                surface: pairingSurface
            ).items.map(\.descriptor),
            ProductCatalogSemanticSurface(
                surface: catalogSurface,
                appCount: apps.count
            ).items.map(\.descriptor),
            ProductStreamSemanticSurface(
                commands: model.sessionCommandState(in: workspace),
                controlsVisible: false
            ).items.map(\.descriptor),
            ProductSettingsSemanticSurface(
                settings: model.settings
            ).items.map(\.descriptor),
            ProductDiagnosticsSemanticSurface(
                eventCount: model.diagnostics.events.count,
                exportSupported: true
            ).items.map(\.descriptor)
        ]
        let descriptors = descriptorGroups.flatMap { $0 }
        XCTAssertEqual(
            descriptors.count,
            ProductHostSemanticID.allCases.count
                + ProductPairingSemanticID.allCases.count
                + ProductCatalogSemanticID.allCases.count
                + ProductStreamSemanticID.allCases.count
                + ProductSettingsSemanticID.allCases.count
                + ProductDiagnosticsSemanticID.allCases.count
        )
        for descriptor in descriptors {
            XCTAssertFalse(localized(descriptor.label).isEmpty)
            XCTAssertFalse(localized(descriptor.value).isEmpty)
            XCTAssertFalse(localized(descriptor.hint).isEmpty)
        }

        let longestName = String(
            repeating: "Maximum Localized Remote Application Name ",
            count: 8
        )
        let longestDescriptor = ProductCatalogSemanticSurface.appItem(
            name: longestName,
            isSelected: true,
            isEnabled: true
        )
        let longestLabel = localized(longestDescriptor.label)
        XCTAssertTrue(longestLabel.contains(longestName))
        XCTAssertGreaterThan(longestLabel.count, 300)
        XCTAssertFalse(
            localized(ProductHostSemanticSurface.hostItem(
                selectedHost,
                isSelected: true
            ).label).contains(selectedHost.address)
        )

        XCTAssertEqual(
            ProductKeyboardFocusPolicy.addHostInitialTarget,
            .manualHostAddress
        )
        XCTAssertEqual(
            ProductKeyboardFocusPolicy.pairingTarget(for: pairingSurface),
            .pairingResult
        )
        XCTAssertEqual(
            ProductKeyboardFocusPolicy.streamOverlayInitialTarget,
            .streamHideControls
        )

        let layoutCases: [(
            compactSizeClass: Bool,
            accessibilityText: Bool,
            width: CGFloat,
            isCompact: Bool
        )] = [
            (false, false, 1_280, false),
            (true, false, 1_280, true),
            (false, true, 1_280, true),
            (false, false, 640, true)
        ]
        for layoutCase in layoutCases {
            let expectedLibrary: ProductLibraryDashboardLayout =
                layoutCase.isCompact ? .compact : .wide
            let expectedStream: ProductStreamWorkspaceLayout =
                layoutCase.isCompact ? .compact : .wide
            XCTAssertEqual(
                ProductLibraryDashboardLayout(
                    horizontalSizeClassIsCompact:
                        layoutCase.compactSizeClass,
                    usesAccessibilityTextSize:
                        layoutCase.accessibilityText,
                    availableWidth: layoutCase.width
                ),
                expectedLibrary
            )
            XCTAssertEqual(
                ProductStreamWorkspaceLayout(
                    horizontalSizeClassIsCompact:
                        layoutCase.compactSizeClass,
                    usesAccessibilityTextSize:
                        layoutCase.accessibilityText,
                    availableWidth: layoutCase.width
                ),
                expectedStream
            )
        }
        XCTAssertEqual(
            TVVisionStreamControlsLayout(
                horizontalSizeClassIsCompact: false,
                usesAccessibilityTextSize: false
            ),
            .wide
        )
        XCTAssertEqual(
            TVVisionStreamControlsLayout(
                horizontalSizeClassIsCompact: false,
                usesAccessibilityTextSize: true
            ),
            .compact
        )
        XCTAssertEqual(
            ProductInteractionAccessibilityPolicy.minimumTouchTargetDimension,
            44
        )
        XCTAssertEqual(
            ProductInteractionAccessibilityPolicy.transitionStyle(
                reduceMotionEnabled: false
            ),
            .opacity
        )
        XCTAssertEqual(
            ProductInteractionAccessibilityPolicy.transitionStyle(
                reduceMotionEnabled: true
            ),
            .immediate
        )

        let inactiveTVModel = makeLaunchReadyModel(
            sessionControlProvider: ControlledSessionControlProvider(),
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [])
        )
        let inactiveTV = inactiveTVModel.tvStreamControlPresentationState
        XCTAssertEqual(inactiveTV.focus, .unavailable)
        XCTAssertNil(ProductTVStreamFocusPolicy.target(
            overlayVisibility: .visible,
            presentation: inactiveTV
        ))

        let inactiveVisionModel = makeLaunchReadyModel(
            sessionControlProvider: ControlledSessionControlProvider(),
            tvVisionPlatform: .visionOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [])
        )
        XCTAssertFalse(
            inactiveVisionModel.visionStreamControlPresentationState
                .reachability.canHideControls
        )
    }

    func testTVVisionAccessibilityApplicationMatrixTracksActualOverlayEligibility()
        async throws
    {
        let tvProvider = ControlledSessionControlProvider()
        let tvModel = makeLaunchReadyModel(
            sessionControlProvider: tvProvider,
            tvVisionPlatform: .tvOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 73,
                    key: Data(repeating: 0x73, count: 16)
                ))
            ])
        )
        await tvModel.loadInitialState()
        await tvModel.refreshAppsForSelectedHost()
        let tvWorkspace = tvModel.primaryWorkspaceReference
        let tvLaunch = Task {
            await tvModel.launchSelectedApp(in: tvWorkspace)
        }
        let tvRecord = try await waitForSessionStart(tvProvider)
        driveSessionToStreaming(tvProvider, record: tvRecord)
        guard await waitForApplicationIntegrationState(
            diagnostic: {
                "phase=\(tvModel.session.phase.label)"
            },
            condition: { tvModel.session.isStreaming }
        ) else { return }
        tvModel.setTVStreamWorkspaceVisible(true, in: tvWorkspace)
        XCTAssertTrue(tvModel.setStreamOverlayVisibility(
            .hidden,
            in: tvWorkspace
        ))
        tvModel.receiveTVVisionGeometryUpdate(
            try makeTVVisionActiveGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 1
            )
        )
        guard await waitForApplicationIntegrationState(
            diagnostic: {
                "focus=\(tvModel.tvStreamControlPresentationState.focus) "
                    + "release=\(tvModel.tvRemoteInputReleasePending)"
            },
            condition: {
                tvModel.tvStreamControlPresentationState.focus
                    == .streamSurface
            }
        ) else { return }
        let hiddenTV = tvModel.tvStreamControlPresentationState
        XCTAssertEqual(
            ProductTVStreamFocusPolicy.target(
                overlayVisibility: .hidden,
                presentation: hiddenTV
            ),
            .streamSurface
        )

        XCTAssertTrue(tvModel.setStreamOverlayVisibility(
            .visible,
            in: tvWorkspace
        ))
        guard await waitForApplicationIntegrationState(
            diagnostic: {
                "overlay=\(tvModel.tvStreamOverlayVisible) "
                    + "focus=\(tvModel.tvStreamControlPresentationState.focus) "
                    + "release=\(tvModel.tvRemoteInputReleasePending)"
            },
            condition: {
                tvModel.tvStreamOverlayVisible
                    && !tvModel.tvRemoteInputReleasePending
                    && tvModel.tvStreamControlPresentationState.focus
                        == .localControls
            }
        ) else { return }
        XCTAssertEqual(
            ProductTVStreamFocusPolicy.target(
                overlayVisibility: .visible,
                presentation: tvModel.tvStreamControlPresentationState
            ),
            .hideControls
        )
        XCTAssertTrue(tvModel.setStreamOverlayVisibility(
            .hidden,
            in: tvWorkspace
        ))
        tvModel.receiveTVVisionGeometryUpdate(
            try makeTVVisionActiveGeometryUpdate(
                platform: .tvOS,
                surfaceGeneration: 1,
                revision: 2
            )
        )
        guard await waitForApplicationIntegrationState(
            diagnostic: {
                "focus=\(tvModel.tvStreamControlPresentationState.focus)"
            },
            condition: {
                tvModel.tvStreamControlPresentationState.focus
                    == .streamSurface
            }
        ) else { return }
        let didStopTVStream = await tvModel.stopStream(in: tvWorkspace)
        XCTAssertTrue(didStopTVStream)
        await tvLaunch.value

        let visionProvider = ControlledSessionControlProvider()
        let visionEnvironment = ControlledSessionMediaEnvironment()
        let visionModel = makeLaunchReadyModel(
            sessionControlProvider: visionProvider,
            sessionMediaEnvironment: visionEnvironment,
            tvVisionPlatform: .visionOS,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: 74,
                    key: Data(repeating: 0x74, count: 16)
                ))
            ])
        )
        await visionModel.loadInitialState()
        await visionModel.refreshAppsForSelectedHost()
        let visionWorkspace = visionModel.primaryWorkspaceReference
        let visionLaunch = Task {
            await visionModel.launchSelectedApp(in: visionWorkspace)
        }
        let visionRecord = try await waitForSessionStart(visionProvider)
        driveSessionToStreaming(visionProvider, record: visionRecord)
        guard await waitForApplicationIntegrationState(
            diagnostic: {
                "phase=\(visionModel.session.phase.label)"
            },
            condition: { visionModel.session.isStreaming }
        ) else { return }
        let visionGeometry = try makeTVVisionActiveGeometryUpdate(
            platform: .visionOS,
            surfaceGeneration: 1,
            revision: 1
        )
        visionModel.receiveTVVisionGeometryUpdate(visionGeometry)
        guard await waitForApplicationIntegrationState(
            diagnostic: {
                "capture=\(visionModel.visionInputCaptureEnabled(in: visionWorkspace)) "
                    + "applications=\(visionEnvironment.currentTVVisionPlatformPresentationApplications().count)"
            },
            condition: {
                visionModel.visionInputCaptureEnabled(in: visionWorkspace)
                    && visionEnvironment
                        .currentTVVisionPlatformPresentationApplications().count
                        == 3
            }
        ) else { return }
        let visionApplications = visionEnvironment
            .currentTVVisionPlatformPresentationApplications()
        let visionOwnership = visionApplications[0].ownership
        guard case let .scene(appliedVisionGeometry) = visionApplications[1].action,
              case let .input(visionInput, controllerLeases) =
                visionApplications[2].action else {
            return XCTFail("Expected visionOS scene and input application.")
        }
        XCTAssertEqual(appliedVisionGeometry, visionGeometry)
        XCTAssertTrue(controllerLeases.isEmpty)
        let visionCoordinator = try TVVisionPlatformPresentationCoordinator(
            diagnosticCapacity: 4
        )
        _ = await visionCoordinator.activate(visionOwnership)
        _ = await visionCoordinator.applyScene(
            appliedVisionGeometry,
            ownership: visionOwnership
        )
        _ = await visionCoordinator.applyInput(
            visionInput,
            controllerLeases: controllerLeases,
            ownership: visionOwnership
        )
        _ = await visionCoordinator.applyDisplay(
            try makeVisionOSDisplaySnapshot(
                revision: 1,
                displayGeneration: 1
            ),
            ownership: visionOwnership
        )
        _ = await visionCoordinator.applyAudioRoute(
            try makeVisionOSAudioRouteSnapshot(
                revision: 1,
                graphGeneration: 1,
                presentationMode: .headTracked
            ),
            ownership: visionOwnership
        )
        let optionalVisionSnapshot = await visionCoordinator.snapshot()
        let visionSnapshot = try XCTUnwrap(optionalVisionSnapshot)
        let visionPresentation = SessionTVVisionPlatformPresentationState(
            sessionID: visionRecord.sessionID,
            mediaGeneration: visionOwnership.mediaGeneration,
            snapshot: visionSnapshot
        )
        visionEnvironment.yieldTVVisionPlatformPresentation(
            visionPresentation,
            sessionID: visionRecord.sessionID
        )
        guard await waitForApplicationIntegrationState(
            diagnostic: {
                let state = visionModel.visionStreamControlPresentationState(
                    in: visionWorkspace
                )
                return "window=\(state.window) input=\(state.input)"
            },
            condition: {
                visionModel.tvVisionPlatformPresentationState
                    == visionPresentation
                    && visionModel.visionStreamControlPresentationState(
                        in: visionWorkspace
                    ).input == .captured(
                        capabilityCount: visionInput.supported.count
                    )
            }
        ) else { return }
        XCTAssertFalse(
            visionModel.visionStreamControlPresentationState(
                in: visionWorkspace
            ).reachability.canHideControls
        )

        XCTAssertTrue(visionModel.setStreamOverlayVisibility(
            .visible,
            in: visionWorkspace
        ))
        guard await waitForApplicationIntegrationState(
            diagnostic: {
                let state = visionModel.visionStreamControlPresentationState(
                    in: visionWorkspace
                )
                return "overlay=\(visionModel.streamOverlayVisibility(in: visionWorkspace)) "
                    + "input=\(state.input) release=\(visionModel.visionInputReleasePending)"
            },
            condition: {
                visionModel.streamOverlayVisibility(in: visionWorkspace)
                    == .visible
                    && !visionModel.visionInputReleasePending
                    && visionModel.visionStreamControlPresentationState(
                        in: visionWorkspace
                    ).reachability.canHideControls
            }
        ) else { return }
        XCTAssertFalse(
            visionModel.visionInputCaptureEnabled(in: visionWorkspace)
        )

        XCTAssertTrue(visionModel.setStreamOverlayVisibility(
            .hidden,
            in: visionWorkspace
        ))
        guard await waitForApplicationIntegrationState(
            diagnostic: {
                "capture=\(visionModel.visionInputCaptureEnabled(in: visionWorkspace))"
            },
            condition: {
                visionModel.visionInputCaptureEnabled(in: visionWorkspace)
            }
        ) else { return }
        XCTAssertFalse(
            visionModel.visionStreamControlPresentationState(
                in: visionWorkspace
            ).reachability.canHideControls
        )
        let didStopVisionStream = await visionModel.stopStream(
            in: visionWorkspace
        )
        XCTAssertTrue(didStopVisionStream)
        await visionLaunch.value
    }

    private func localized(_ resource: LocalizedStringResource) -> String {
        String(localized: resource)
    }

    private func makeLaunchReadyModel(
        sessionControlProvider: any SessionControlProvider,
        sessionMediaEnvironment: any SessionMediaEnvironment =
            ControlledSessionMediaEnvironment(),
        videoPresentationSource: StreamVideoPresentationSource? = nil,
        tvVisionPlatform: TVVisionPlatform? = nil,
        launchClient: StubStreamLaunchClient,
        remoteInputKeyGenerator: any RemoteInputKeyMaterialGenerating,
        runtimeProviders: RuntimeProviderInventory? = nil,
        settingsRepository: any AppSettingsRepository =
            InMemoryAppSettingsRepository()
    ) -> AppModel {
        let host = MoonlightHost(
            id: UUID(uuidString: "45F0C9CB-D795-49B2-A733-F68397632233")!,
            name: "Test Host",
            address: "moon.local",
            pairingState: .paired,
            reachability: .online,
            pinnedIdentity: PinnedHostIdentity(
                certificateSHA256: "existing-cert",
                serverCertificateDER: Data([1, 2, 3]),
                pairedAt: Date(timeIntervalSince1970: 10)
            )
        )
        return AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(hosts: [host]),
                serverInfoClient: StubServerInfoClient()
            ),
            settingsRepository: settingsRepository,
            appCatalogManager: AppCatalogManager(
                appListClient: StubAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(launchClient: launchClient),
            runtimeProviders: runtimeProviders ?? completeStreamProviderInventory(
                sessionControlProvider: sessionControlProvider
            ),
            sessionMediaEnvironment: sessionMediaEnvironment,
            videoPresentationSource: videoPresentationSource,
            tvVisionPlatform: tvVisionPlatform,
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientUniqueID: "test-client",
            remoteInputKeyGenerator: remoteInputKeyGenerator
        )
    }

    private func makeSceneCloseFixture(
        keyID: Int,
        supportsMultipleWindows: Bool = true
    ) async throws -> (
        model: AppModel,
        provider: ControlledSessionControlProvider,
        environment: ControlledSessionMediaEnvironment,
        attachment: ProductWorkspaceSceneAttachment
    ) {
        let provider = ControlledSessionControlProvider()
        let environment = ControlledSessionMediaEnvironment()
        let model = makeLaunchReadyModel(
            sessionControlProvider: provider,
            sessionMediaEnvironment: environment,
            launchClient: StubStreamLaunchClient(),
            remoteInputKeyGenerator: ScriptedInputKeyGenerator(results: [
                .success(RemoteInputKeyMaterial(
                    keyID: keyID,
                    key: Data(repeating: UInt8(keyID), count: 16)
                ))
            ])
        )
        let attachment = try model.connectProductWorkspaceScene(
            restoring: nil,
            supportsMultipleWindows: supportsMultipleWindows
        )
        await model.loadInitialState(in: attachment.workspace)
        await model.refreshAppsForSelectedHost(in: attachment.workspace)
        return (model, provider, environment, attachment)
    }

    private func makePlatformLifecycle(
        isStreamActive: Bool,
        isVisible: Bool,
        isFocused: Bool,
        drawableSize: PixelSize
    ) -> PlatformLifecycleState {
        let lifecycle = PlatformLifecycleState()
        lifecycle.isStreamActive = isStreamActive
        lifecycle.isVisible = isVisible
        lifecycle.isFocused = isFocused
        lifecycle.drawableSize = drawableSize
        lifecycle.updateRenderPolicy()
        return lifecycle
    }

    private func makeTVVisionClosedGeometryUpdate(
        platform: TVVisionPlatform,
        surfaceGeneration: UInt64,
        revision: UInt64
    ) throws -> TVVisionStreamGeometryBindingUpdate {
        TVVisionStreamGeometryBindingUpdate(
            platform: platform,
            surfaceGeneration: try TVVisionGeneration(
                domain: .surface,
                rawValue: surfaceGeneration
            ),
            revision: try TVVisionSemanticRevision(rawValue: revision),
            status: .closed(.detached),
            binding: nil
        )
    }

    private func makeTVVisionActiveGeometryUpdate(
        platform: TVVisionPlatform,
        surfaceGeneration rawSurfaceGeneration: UInt64,
        revision rawRevision: UInt64,
        activity: AppSceneActivity = .active,
        isVisible: Bool = true,
        isFocusEligible: Bool = true,
        viewSize: PixelSize = PixelSize(width: 640, height: 360),
        mode: RenderScaleMode = .fit
    ) throws -> TVVisionStreamGeometryBindingUpdate {
        let surfaceGeneration = try TVVisionGeneration(
            domain: .surface,
            rawValue: rawSurfaceGeneration
        )
        let revision = try TVVisionSemanticRevision(rawValue: rawRevision)
        let geometry = try TVVisionSurfaceGeometry(
            platform: platform,
            surfaceGeneration: surfaceGeneration,
            viewBounds: TVVisionRect(
                x: 0,
                y: 0,
                width: Double(viewSize.width),
                height: Double(viewSize.height)
            ),
            windowBounds: TVVisionRect(
                x: 0,
                y: 0,
                width: Double(viewSize.width),
                height: Double(viewSize.height)
            ),
            safeAreaInsets: .zero,
            scale: 2
        )
        let scene = try TVVisionSceneSurfaceSnapshot(
            platform: platform,
            revision: revision,
            surfaceGeneration: surfaceGeneration,
            activity: activity,
            attachment: .attached,
            isVisible: isVisible,
            geometry: geometry
        )
        let sourceSize = PixelSize(width: 1_920, height: 1_080)
        let coordinateSnapshot = try XCTUnwrap(
            StreamCoordinateSnapshot.resolve(
                revision: revision.rawValue,
                sourceSize: sourceSize,
                drawableSize: geometry.drawableSize,
                mode: mode
            )
        )
        let binding = TVVisionStreamGeometryBindingSnapshot(
            platform: platform,
            surfaceGeneration: surfaceGeneration,
            revision: revision,
            sceneSurfaceSnapshot: scene,
            isFocusEligible: isFocusEligible,
            coordinateSnapshot: coordinateSnapshot,
            inputReferenceSize: sourceSize
        )
        return TVVisionStreamGeometryBindingUpdate(
            platform: platform,
            surfaceGeneration: surfaceGeneration,
            revision: revision,
            status: .active,
            binding: binding
        )
    }

    private func makeTVRemoteSurfacePress(
        _ surfaceGeneration: TVVisionGeneration,
        _ pressID: UInt64,
        _ button: TVRemoteButton,
        _ phase: TVRemoteSurfacePressPhase
    ) throws -> TVRemoteSurfacePressEvent {
        try TVRemoteSurfacePressEvent(
            surfaceGeneration: surfaceGeneration,
            pressID: pressID,
            button: button,
            phase: phase
        )
    }

    private func makeTVVisionPresentationState(
        sessionID: UUID,
        mediaGeneration: UInt64,
        platform: TVVisionPlatform,
        presentationGeneration: UInt64,
        sequence: UInt64,
        phase: TVVisionPlatformPresentationPhase = .active,
        display sourceDisplay: TVVisionDisplaySnapshot? = nil,
        audioRoute sourceAudioRoute: TVVisionAudioRouteSnapshot? = nil,
        visionSurfaceGeneration: UInt64? = nil,
        isSemanticRevisionExhausted: Bool = false
    ) throws -> SessionTVVisionPlatformPresentationState {
        let ownership = try TVVisionPresentationOwnership(
            platform: platform,
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            presentationGeneration: TVVisionGeneration(
                domain: .presentation,
                rawValue: presentationGeneration
            ),
            inputGeneration: TVVisionGeneration(
                domain: .input,
                rawValue: mediaGeneration
            )
        )
        let revision = try TVVisionSemanticRevision(rawValue: sequence)
        let display = try sourceDisplay.map {
            try TVVisionDisplaySnapshot(
                platform: $0.platform,
                revision: revision,
                displayGeneration: $0.displayGeneration,
                isOutputAvailable: $0.isOutputAvailable,
                headroomSource: $0.headroomSource,
                currentEDRHeadroom: $0.currentEDRHeadroom,
                potentialEDRHeadroom: $0.potentialEDRHeadroom,
                layerCapability: $0.layerCapability,
                tvOSHDRCapabilityResolution: $0.tvOSHDRCapabilityResolution,
                visionOSHDRCapabilityResolution:
                    $0.visionOSHDRCapabilityResolution
            )
        }
        let audioRoute = try sourceAudioRoute.map {
            try TVVisionAudioRouteSnapshot(
                platform: $0.platform,
                revision: revision,
                routeGeneration: $0.routeGeneration,
                outputAvailable: $0.outputAvailable,
                currentOutputChannelCount: $0.currentOutputChannelCount,
                maximumOutputChannelCount: $0.maximumOutputChannelCount,
                spatialSupport: $0.spatialSupport,
                platformStrategy: $0.platformStrategy,
                headTrackingCapability: $0.headTrackingCapability,
                runtimeStage: $0.runtimeStage,
                eventCause: $0.eventCause,
                spatialPresentationMode: $0.spatialPresentationMode,
                spatialFallbackReason: $0.spatialFallbackReason
            )
        }
        let presentation = try display.flatMap { display in
            try audioRoute.map { audioRoute in
                let scene = try TVVisionSceneSurfaceSnapshot(
                    platform: platform,
                    revision: revision,
                    surfaceGeneration: TVVisionGeneration(
                        domain: .surface,
                        rawValue: presentationGeneration
                    ),
                    activity: .inactive,
                    attachment: .detached,
                    isVisible: false,
                    geometry: nil
                )
                let input = try TVVisionInputCapabilitySnapshot(
                    platform: platform,
                    revision: revision,
                    inputGeneration: ownership.inputGeneration,
                    supported: [],
                    focusEligibility: .ineligible(.detached)
                )
                return try TVVisionPlatformPresentationSnapshot(
                    ownership: ownership,
                    revision: revision,
                    sceneSurface: scene,
                    inputCapabilities: input,
                    controllerLeases: [],
                    display: display,
                    audioRoute: audioRoute
                )
            }
        }
        let visionWindowedPresentation = try visionSurfaceGeneration.map {
            try VisionWindowedPresentationState.windowedOnly(
                ownership: ownership,
                revision: revision,
                surfaceGeneration: TVVisionGeneration(
                    domain: .surface,
                    rawValue: $0
                )
            )
        }
        return SessionTVVisionPlatformPresentationState(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            snapshot: TVVisionPlatformPresentationCoordinatorSnapshot(
                ownership: ownership,
                sequence: sequence,
                revision: revision,
                phase: phase,
                presentation: phase == .active ? presentation : nil,
                visionWindowedPresentation: phase == .active
                    ? visionWindowedPresentation
                    : nil,
                display: phase == .active ? display : nil,
                audioRoute: phase == .active ? audioRoute : nil,
                video: TVVisionPlatformVideoSnapshot(
                    phase: .idle,
                    lastDeliveryRevision: nil,
                    isPresented: false
                ),
                diagnostics: [],
                teardownCount: 0,
                isSemanticRevisionExhausted: isSemanticRevisionExhausted,
                isSequenceExhausted: false
            )
        )
    }

    private func makeTVOSDisplaySnapshot(
        revision: UInt64,
        displayGeneration: UInt64,
        current: Double?,
        potential: Double?
    ) throws -> TVVisionDisplaySnapshot {
        let resolution = TVOSDisplayHDRCapabilityResolver.resolve(
            TVOSDisplayHDRCapabilityInputs(
                isOutputAvailable: true,
                layerCapability: .preferredDynamicRange,
                supportsToneMapControl: true,
                supportsContentsHeadroom: true,
                supportedEDRGamuts: [.displayP3, .ituR2020],
                currentEDRHeadroom: current,
                potentialEDRHeadroom: potential
            )
        )
        let capabilities = resolution.capabilities
        return try TVVisionDisplaySnapshot(
            platform: .tvOS,
            revision: TVVisionSemanticRevision(rawValue: revision),
            displayGeneration: TVVisionGeneration(
                domain: .display,
                rawValue: displayGeneration
            ),
            isOutputAvailable: true,
            headroomSource: capabilities.currentEDRHeadroom == nil
                ? .unavailable
                : .platformReported,
            currentEDRHeadroom: capabilities.currentEDRHeadroom,
            potentialEDRHeadroom: capabilities.potentialEDRHeadroom,
            layerCapability: capabilities.layerCapability,
            tvOSHDRCapabilityResolution: resolution
        )
    }

    private func makeVisionOSDisplaySnapshot(
        revision: UInt64,
        displayGeneration: UInt64
    ) throws -> TVVisionDisplaySnapshot {
        let resolution = TVVisionDisplayHDRCapabilityResolver.resolve(
            TVVisionDisplayHDRCapabilityInputs(
                isOutputAvailable: true,
                layerCapability: .preferredDynamicRange,
                supportsToneMapControl: true,
                supportsContentsHeadroom: true,
                supportedEDRGamuts: [.displayP3, .ituR2020],
                currentEDRHeadroom: nil,
                potentialEDRHeadroom: nil
            )
        )
        return try TVVisionDisplaySnapshot(
            platform: .visionOS,
            revision: TVVisionSemanticRevision(rawValue: revision),
            displayGeneration: TVVisionGeneration(
                domain: .display,
                rawValue: displayGeneration
            ),
            isOutputAvailable: true,
            headroomSource: .unavailable,
            currentEDRHeadroom: nil,
            potentialEDRHeadroom: nil,
            layerCapability: .preferredDynamicRange,
            visionOSHDRCapabilityResolution: resolution
        )
    }

    private func makeTVOSAudioRouteSnapshot(
        revision: UInt64,
        graphGeneration: UInt64,
        presentationMode: SpatialAudioPresentationMode
    ) throws -> TVVisionAudioRouteSnapshot {
        try TVVisionAudioRouteSnapshot(
            platform: .tvOS,
            revision: TVVisionSemanticRevision(rawValue: revision),
            routeGeneration: TVVisionGeneration(
                domain: .audioRoute,
                rawValue: graphGeneration
            ),
            outputAvailable: true,
            currentOutputChannelCount: 2,
            maximumOutputChannelCount: 8,
            spatialSupport: .supported,
            platformStrategy: .environmentListener,
            headTrackingCapability: .entitlementRequired,
            runtimeStage: .running,
            eventCause: .initial,
            spatialPresentationMode: presentationMode,
            spatialFallbackReason: nil
        )
    }

    private func makeVisionOSAudioRouteSnapshot(
        revision: UInt64,
        graphGeneration: UInt64,
        presentationMode: SpatialAudioPresentationMode
    ) throws -> TVVisionAudioRouteSnapshot {
        try TVVisionAudioRouteSnapshot(
            platform: .visionOS,
            revision: TVVisionSemanticRevision(rawValue: revision),
            routeGeneration: TVVisionGeneration(
                domain: .audioRoute,
                rawValue: graphGeneration
            ),
            outputAvailable: true,
            currentOutputChannelCount: 2,
            maximumOutputChannelCount: 8,
            spatialSupport: .supported,
            platformStrategy: .visionOutputExperience,
            headTrackingCapability: .intendedSpatialExperience,
            runtimeStage: .running,
            eventCause: .initial,
            spatialPresentationMode: presentationMode,
            spatialFallbackReason: nil
        )
    }

    private func makeAudioRuntimeState(
        sessionID: UUID,
        mediaGeneration: UInt64,
        sequence: UInt64,
        graphGeneration: UInt64,
        preferences: SessionSpatialAudioPreferences = .nativeDefault,
        spatialRuntime: SpatialAudioRuntimeSnapshot? = nil
    ) -> SessionMediaAudioRuntimeState {
        SessionMediaAudioRuntimeState(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            runtime: SessionAudioRuntimeEvent(
                sessionID: sessionID,
                sequence: sequence,
                graphGeneration: graphGeneration,
                cause: .initial,
                stage: .running,
                spatialRuntime: spatialRuntime,
                routeCapability: SpatialAudioRouteCapabilitySnapshot(
                    revision: spatialRuntime?.revision ?? .init(rawValue: 0),
                    outputAvailable: true,
                    systemSpatialSupport: .supported,
                    currentOutputChannelCount: 2,
                    maximumOutputChannelCount: 8
                ),
                entitlement: .granted,
                preferences: preferences,
                concealedFrameCount: 0,
                lastAction: .none
            )
        )
    }

    private func makeMobileRuntimeState(
        sessionID: UUID,
        mediaGeneration: UInt64,
        revision: UInt64,
        sceneActivity: AppSceneActivity,
        foregroundRestorationCount: UInt64 = 0,
        pictureInPictureLifecycle: MobilePictureInPictureLifecycle? = nil,
        isAudioSessionActive: Bool? = nil,
        includesActualSceneAndDisplay: Bool = false
    ) throws -> SessionMobileRuntimeState {
        let generation = try XCTUnwrap(MobilePictureInPictureGeneration(
            mediaGeneration: mediaGeneration,
            pictureInPictureGeneration: 1
        ))
        let surfaceGeneration = includesActualSceneAndDisplay
            ? try XCTUnwrap(MobileSceneSurfaceGeneration(
                rawValue: mediaGeneration
            ))
            : nil
        let sceneWindow = surfaceGeneration.map {
            MobileSceneWindowSnapshot(
                surfaceGeneration: $0,
                revision: MobileSceneWindowRevision(rawValue: revision),
                state: .attached(
                    activity: sceneActivity,
                    display: MobileDisplayGeneration(rawValue: mediaGeneration)!,
                    geometry: MobileSceneWindowGeometry(
                        viewBounds: MobileSceneRect(
                            x: 0,
                            y: 0,
                            width: 1_024,
                            height: 768
                        ),
                        windowBounds: MobileSceneRect(
                            x: 0,
                            y: 0,
                            width: 1_024,
                            height: 768
                        ),
                        safeAreaInsets: .zero,
                        scale: 2,
                        drawableSize: PixelSize(width: 2_048, height: 1_536),
                        orientation: .landscapeLeft,
                        traits: MobileSceneTraits(
                            horizontalSizeClass: .regular,
                            verticalSizeClass: .regular,
                            interfaceStyle: .dark
                        ),
                        resizePhase: .settled
                    )
                )
            )
        }
        let displayEDR = surfaceGeneration.map { surfaceGeneration in
            var publisher = MobileDisplayEDRSnapshotPublisher(
                surfaceGeneration: surfaceGeneration
            )
            _ = publisher.update(MobileDisplayEDREventEnvelope(
                surfaceGeneration: surfaceGeneration,
                sample: .attached(MobileDisplayEDRReading(
                    displayGeneration: mediaGeneration,
                    potentialHeadroom: 4,
                    currentHeadroom: 2
                ))
            ))
            return publisher.snapshot!
        }
        let pictureInPicture = pictureInPictureLifecycle.map { lifecycle in
            MobilePictureInPictureSnapshot(
                generation: generation,
                revision: MobilePictureInPictureRevision(rawValue: revision),
                state: MobilePictureInPictureSemanticState(
                    isPrepared: true,
                    capability: .possible,
                    lifecycle: lifecycle,
                    frameSink: .ready(decoderGeneration: 1)!,
                    restoration: .idle,
                    failure: nil
                )
            )
        }
        let application = SessionMobileRuntimeApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            revision: try XCTUnwrap(SessionMobileRuntimeRevision(
                rawValue: revision
            )),
            generation: generation,
            platform: .iOS,
            sceneActivity: sceneActivity,
            surfaceGeneration: surfaceGeneration,
            sceneWindow: sceneWindow,
            displayEDR: displayEDR,
            pictureInPicture: pictureInPicture,
            isAudioSessionActive: isAudioSessionActive,
            isAudioContinuityPermitted: isAudioSessionActive == true,
            preferences: .defaults,
            capabilities: PlatformContinuityCapabilities(
                supportsAudioBackgroundMode: true,
                supportsPictureInPicture: true,
                hasAudioBackgroundModeDeclared: true
            ),
            foregroundBaseline: .active
        )
        let input = application.generationInput
        let plan = MobileMediaGenerationPlanResolver.resolve(
            input.continuityContext,
            foregroundBaseline: input.foregroundBaseline,
            restoringForeground: foregroundRestorationCount > 0
        )
        return SessionMobileRuntimeState(
            application: application,
            media: MobileMediaGenerationSnapshot(
                ownership: input.ownership,
                revision: input.revision,
                phase: plan.stream == .stopped ? .stopped : .active,
                input: input,
                plan: plan,
                foregroundRestorationCount: foregroundRestorationCount
            )
        )
    }

    private func makeHDRApplicationFrame(
        generation: UInt64,
        frameID: UInt64,
        metadata: VideoColorMetadata
    ) throws -> DecodedVideoFrame {
        let bitDepth: VideoOutputBitDepth = metadata.isHDR ? .ten : .eight
        let pixelFormat = metadata.isHDR
            ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        var pixelBuffer: CVPixelBuffer?
        let result = CVPixelBufferCreate(
            kCFAllocatorDefault,
            64,
            64,
            pixelFormat,
            VideoToolboxDecompressionSessionFactory
                .destinationAttributes(for: bitDepth) as CFDictionary,
            &pixelBuffer
        )
        XCTAssertEqual(result, kCVReturnSuccess)
        return DecodedVideoFrame(
            generation: generation,
            frameID: frameID,
            pixelBuffer: try XCTUnwrap(pixelBuffer),
            presentationTimeStamp: .invalid,
            duration: .invalid,
            infoFlags: [],
            colorMetadata: metadata
        )
    }

    private func makePairingModel(
        host: MoonlightHost,
        provider: ControlledPairingProvider,
        identityProvisioner: any ClientIdentityProvisioning
    ) -> AppModel {
        AppModel(
            hostLibraryManager: HostLibraryManager(
                repository: InMemoryHostRepository(hosts: [host]),
                serverInfoClient: StubServerInfoClient()
            ),
            settingsRepository: InMemoryAppSettingsRepository(),
            appCatalogManager: AppCatalogManager(
                appListClient: StubAppListClient(),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(launchClient: StubStreamLaunchClient()),
            runtimeProviders: RuntimeProviderInventory(pairing: provider),
            clientIdentityStore: InMemoryClientIdentityStore(),
            clientIdentityProvisioner: identityProvisioner,
            clientUniqueID: "test-client"
        )
    }

    private func waitForSessionStart(
        _ provider: ControlledSessionControlProvider
    ) async throws -> ControlledSessionControlProvider.StartRecord {
        for _ in 0..<100 where provider.currentStartRecords().isEmpty {
            await Task.yield()
        }
        return try XCTUnwrap(provider.currentStartRecords().last)
    }

    private func waitUntil(
        _ condition: () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<100 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail(
            "Timed out waiting for application session state.",
            file: file,
            line: line
        )
    }

    private func makeLiveSunshineProductionModel() -> (
        model: AppModel,
        launchClient: LiveRecordingStreamLaunchClient,
        controlProvider: LiveRecordingSessionControlProvider,
        mediaRecorder: LiveMediaFailureRecorder,
        mediaActivityRecorder: LiveMediaActivityRecorder,
        videoProcessingRecorder: LiveVideoProcessingRecorder
    ) {
        let identityStore = JSONFileClientIdentityStore(
            fileURL: AppStorageLocations.debugClientIdentityFile
        )
        let requestExecutor = PinnedHTTPSRequestExecutor(
            clientIdentityStore: identityStore
        )
        let launchClient = LiveRecordingStreamLaunchClient(
            base: HTTPStreamLaunchClient(requestExecutor: requestExecutor)
        )
        let controlChannel = MoonlightControlChannel()
        let mediaRecorder = LiveMediaFailureRecorder()
        let mediaActivityRecorder = LiveMediaActivityRecorder()
        let videoProcessingRecorder = LiveVideoProcessingRecorder()
        let audioChannelFactory = liveRecordingDatagramChannelFactory(
            stage: .audioReceive,
            recorder: mediaActivityRecorder
        )
        let audioDatagramReservations = MoonlightAudioDatagramReservationStore(
            channelFactory: audioChannelFactory
        )
        let controlProvider = LiveRecordingSessionControlProvider(
            base: MoonlightSessionControlProvider(
                launchClient: launchClient,
                controlChannel: controlChannel,
                audioDatagramReservations: audioDatagramReservations
            )
        )
        let runtimeProviders = RuntimeProviderInventory(
            sessionControl: controlProvider,
            videoReceive: LiveRecordingVideoReceiveProvider(
                base: MoonlightVideoReceiveProvider(
                    channelFactory: liveRecordingDatagramChannelFactory(
                        stage: .videoReceive,
                        recorder: mediaActivityRecorder
                    )
                ),
                recorder: mediaRecorder,
                activityRecorder: mediaActivityRecorder
            ),
            audioReceive: LiveRecordingAudioReceiveProvider(
                base: MoonlightAudioReceiveProvider(
                    channelFactory: audioChannelFactory,
                    reservationStore: audioDatagramReservations
                ),
                recorder: mediaRecorder,
                activityRecorder: mediaActivityRecorder
            ),
            remoteInput: MoonlightRemoteInputProvider(
                sender: controlChannel,
                feedbackSource: controlChannel
            )
        )
        let presentationSource = StreamVideoPresentationSource()
        let mediaEnvironment = NativeSessionMediaEnvironment(
            videoReceiveProvider: runtimeProviders.videoReceive,
            audioReceiveProvider: runtimeProviders.audioReceive,
            remoteInputProvider: runtimeProviders.remoteInput,
            videoProcessorFactory: LiveRecordingVideoProcessorFactory(
                base: NativeSessionVideoProcessorFactory(
                    presentationSource: presentationSource
                ),
                recorder: videoProcessingRecorder
            ),
            audioProcessorFactory: NativeSessionAudioProcessorFactory(),
            videoPresentationSource: presentationSource
        )
        let model = AppModel(
            appCatalogManager: AppCatalogManager(
                appListClient: HTTPAppListClient(
                    requestExecutor: requestExecutor
                ),
                artworkCache: InMemoryArtworkCache()
            ),
            appCatalogRepository: InMemoryAppCatalogSnapshotRepository(),
            streamSessionCoordinator: StreamSessionCoordinator(
                launchClient: launchClient
            ),
            runtimeProviders: runtimeProviders,
            sessionMediaEnvironment: mediaEnvironment,
            videoPresentationSource: presentationSource,
            clientIdentityStore: identityStore
        )
        return (
            model,
            launchClient,
            controlProvider,
            mediaRecorder,
            mediaActivityRecorder,
            videoProcessingRecorder
        )
    }

    private func fetchLiveServerInfoOnce(
        from endpoint: HostEndpoint
    ) async throws -> ServerInfo {
        guard let url = endpoint.serverInfoURL else {
            throw LiveSunshineAcceptanceError.invalidServerInfoResponse
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse,
              response.statusCode == 200 else {
            throw LiveSunshineAcceptanceError.invalidServerInfoResponse
        }
        return ServerInfoParser.parse(data)
    }

    private func waitForLiveSunshineCondition(
        timeout: Duration,
        condition: () -> Bool
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return condition()
    }

    private func waitForApplicationIntegrationState(
        timeout: Duration = .seconds(2),
        diagnostic: () -> String,
        condition: () -> Bool,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> Bool {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(1))
        }
        if condition() { return true }
        XCTFail(
            "Timed out waiting for native application integration state: \(diagnostic())",
            file: file,
            line: line
        )
        return false
    }

    private func waitForEnvironmentTeardown(
        _ environment: NativeSessionMediaEnvironment,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async -> SessionMediaEnvironmentSnapshot {
        var snapshot = await environment.snapshot()
        for _ in 0..<200 {
            if snapshot.sessionID == nil, snapshot.lastTeardownReport != nil {
                return snapshot
            }
            await Task.yield()
            snapshot = await environment.snapshot()
        }
        XCTFail(
            "Timed out waiting for media environment teardown.",
            file: file,
            line: line
        )
        return snapshot
    }

    private func driveSessionToStreaming(
        _ provider: ControlledSessionControlProvider,
        record: ControlledSessionControlProvider.StartRecord
    ) {
        provider.yield(.launchAccepted(makeSessionLaunchResponse()), sessionID: record.sessionID)
        provider.yield(.rtspReady, sessionID: record.sessionID)
        provider.yield(
            .negotiated(makeSessionConfiguration(
                sessionID: record.sessionID,
                keyMaterial: record.request.remoteInputKey
            )),
            sessionID: record.sessionID
        )
        provider.yield(.channelsReady(.all), sessionID: record.sessionID)
    }

    private func makeSessionLaunchResponse() -> StreamLaunchResponse {
        StreamLaunchResponse(
            sessionURL: "rtsp://example.invalid/session",
            gameSessionID: "session-1",
            rawValues: [:]
        )
    }

    private func makeSessionConfiguration(
        sessionID: UUID,
        keyMaterial: RemoteInputKeyMaterial,
        videoColorMetadata: VideoColorMetadata = .rec709VideoRange(),
        audioConfiguration: NegotiatedAudioStreamConfiguration? = nil
    ) -> NegotiatedSessionConfiguration {
        NegotiatedSessionConfiguration(
            sessionID: sessionID,
            controlEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 47_999,
                transport: .udp
            ),
            videoEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 48_000,
                transport: .udp
            ),
            audioEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 48_010,
                transport: .udp
            ),
            inputEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 35_043,
                transport: .tcp
            ),
            video: NegotiatedVideoStreamConfiguration(
                codec: .hevc,
                width: 3_840,
                height: 2_160,
                frameRate: 60,
                colorMetadata: videoColorMetadata,
                maximumPacketSize: 1_400
            ),
            audio: audioConfiguration ?? NegotiatedAudioStreamConfiguration(
                sampleRate: 48_000,
                channelLayout: .stereo,
                streamCount: 1,
                coupledStreamCount: 1,
                samplesPerFrame: 240,
                channelMapping: [0, 1],
                maximumPacketSize: 1_400
            ),
            input: NegotiatedInputConfiguration(
                keyMaterial: keyMaterial,
                encrypted: true,
                maximumMessageSize: RemoteInputWireCodec.maximumPacketSize
            ),
            requiredChannels: .all
        )
    }

    private func makeWave7Point1AudioConfiguration()
        throws -> NegotiatedAudioStreamConfiguration
    {
        let configuration = NegotiatedAudioStreamConfiguration(
            sampleRate: 48_000,
            channelLayout: .wave7Point1,
            streamCount: 5,
            coupledStreamCount: 3,
            samplesPerFrame: 240,
            channelMapping: [0, 1, 2, 3, 4, 5, 6, 7],
            maximumPacketSize: 1_400
        )
        try configuration.validate()
        return configuration
    }

    private func makeUnpairedHost() -> MoonlightHost {
        MoonlightHost(
            id: UUID(uuidString: "C8A319F8-E79F-4F57-AC18-7663D52F1EF8")!,
            name: "Pairing Host",
            address: "moon.local",
            pairingState: .unpaired,
            reachability: .online
        )
    }

    private func makePairingIdentity() -> ClientIdentityMaterial {
        ClientIdentityMaterial(
            id: UUID(uuidString: "09047262-05A7-43F2-A907-BD301920DA0D")!,
            certificateDER: Data([0x30, 0x01]),
            privateKeyDER: Data([0x02, 0x01]),
            createdAt: Date(timeIntervalSince1970: 100)
        )
    }

    private func completeStreamProviderInventory(
        sessionControlProvider: (any SessionControlProvider)? = nil
    ) -> RuntimeProviderInventory {
        let production = ProductionRuntimeProviderFactory.makeDefault()
        return RuntimeProviderInventory(
            pairing: production.pairing,
            sessionControl: sessionControlProvider ?? production.sessionControl,
            videoReceive: AvailabilityVideoReceiveProvider(),
            audioReceive: AvailabilityAudioReceiveProvider(),
            remoteInput: production.remoteInput
        )
    }
}

private enum MissingStreamProvider: String, CaseIterable {
    case sessionControl
    case videoReceive
    case audioReceive
    case remoteInput
}

private func applicationIntegrationRouteCapability(
    _ support: SpatialAudioRouteSupport
) -> SpatialAudioRouteCapabilityState {
    SpatialAudioRouteCapabilityState(
        outputAvailable: true,
        systemSpatialSupport: support,
        currentOutputChannelCount: 8,
        maximumOutputChannelCount: 8
    )
}

private struct ApplicationIntegrationEntitlementReader: HeadPoseEntitlementReading {
    let state: SpatialAudioEntitlementState

    func readHeadPoseEntitlement() -> SpatialAudioEntitlementState {
        state
    }
}

private enum LiveMediaPrivateTestError: Error, Equatable, Sendable {
    case failure(String)
}

private actor LiveMediaTestStopRecorder {
    private var videoStops: [UUID] = []
    private var audioStops: [UUID] = []

    func recordVideo(_ sessionID: UUID) {
        videoStops.append(sessionID)
    }

    func recordAudio(_ sessionID: UUID) {
        audioStops.append(sessionID)
    }

    func videoSessionIDs() -> [UUID] {
        videoStops
    }

    func audioSessionIDs() -> [UUID] {
        audioStops
    }
}

private actor LiveMediaTestDatagramChannel: MoonlightDatagramChannel {
    private let receiveChunk: NetworkReceiveChunk
    private var connectionCount = 0
    private var sendCount = 0
    private var receiveCount = 0
    private var cancelCount = 0

    init(receiveChunk: NetworkReceiveChunk) {
        self.receiveChunk = receiveChunk
    }

    func connect(timeout: Duration) async throws {
        _ = timeout
        connectionCount += 1
    }

    func send(_ data: Data, timeout: Duration) async throws {
        _ = data
        _ = timeout
        sendCount += 1
    }

    func receiveWithoutDeadline(
        minimumLength: Int,
        maximumLength: Int?
    ) async throws -> NetworkReceiveChunk {
        _ = minimumLength
        _ = maximumLength
        receiveCount += 1
        return receiveChunk
    }

    func cancel() async {
        cancelCount += 1
    }

    func calls() -> (
        connections: Int,
        sends: Int,
        receives: Int,
        cancels: Int
    ) {
        (connectionCount, sendCount, receiveCount, cancelCount)
    }
}

private struct LiveMediaTestVideoProvider: VideoReceiveProvider {
    let stops: LiveMediaTestStopRecorder
    let makeStream: @Sendable () -> AsyncThrowingStream<VideoReceiveEvent, Error>

    func receiveVideo(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedVideoStreamConfiguration
    ) async -> AsyncThrowingStream<VideoReceiveEvent, Error> {
        _ = sessionID
        _ = endpoint
        _ = configuration
        return makeStream()
    }

    func stopVideo(sessionID: UUID) async {
        await stops.recordVideo(sessionID)
    }
}

private struct LiveMediaTestAudioProvider: AudioReceiveProvider {
    let stops: LiveMediaTestStopRecorder
    let makeStream: @Sendable () -> AsyncThrowingStream<AudioReceiveEvent, Error>

    func receiveAudio(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedAudioStreamConfiguration
    ) async -> AsyncThrowingStream<AudioReceiveEvent, Error> {
        _ = sessionID
        _ = endpoint
        _ = configuration
        return makeStream()
    }

    func stopAudio(sessionID: UUID) async {
        await stops.recordAudio(sessionID)
    }
}

private actor LiveMediaControllableVideoProvider: VideoReceiveProvider {
    private typealias Continuation =
        AsyncThrowingStream<VideoReceiveEvent, Error>.Continuation

    private var continuation: Continuation?
    private var terminated = false

    func receiveVideo(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedVideoStreamConfiguration
    ) async -> AsyncThrowingStream<VideoReceiveEvent, Error> {
        _ = sessionID
        _ = endpoint
        _ = configuration
        let pair = AsyncThrowingStream<VideoReceiveEvent, Error>.makeStream()
        pair.continuation.onTermination = { @Sendable _ in
            Task { await self.recordTermination() }
        }
        continuation = pair.continuation
        return pair.stream
    }

    func stopVideo(sessionID: UUID) async {
        _ = sessionID
        continuation?.finish()
    }

    func didTerminate() -> Bool {
        terminated
    }

    func finish() {
        continuation?.finish()
    }

    private func recordTermination() {
        terminated = true
    }
}

private func liveMediaTestEndpoint(port: UInt16) -> RuntimeNetworkEndpoint {
    RuntimeNetworkEndpoint(
        host: "example.invalid",
        port: port,
        transport: .udp
    )
}

private func liveMediaTestVideoConfiguration()
    -> NegotiatedVideoStreamConfiguration
{
    NegotiatedVideoStreamConfiguration(
        codec: .hevc,
        width: 1_920,
        height: 1_080,
        frameRate: 60,
        colorMetadata: .rec709VideoRange(),
        maximumPacketSize: 1_400
    )
}

private func liveMediaTestAudioConfiguration()
    -> NegotiatedAudioStreamConfiguration
{
    NegotiatedAudioStreamConfiguration(
        sampleRate: 48_000,
        channelLayout: .stereo,
        streamCount: 1,
        coupledStreamCount: 1,
        samplesPerFrame: 240,
        channelMapping: [0, 1],
        maximumPacketSize: 1_400
    )
}

private final class ApplicationIntegrationVideoReceiveProvider:
    VideoReceiveProvider,
    @unchecked Sendable
{
    private typealias Continuation =
        AsyncThrowingStream<VideoReceiveEvent, Error>.Continuation

    private struct Start {
        let sessionID: UUID
        let continuation: Continuation
    }

    private let lock = NSLock()
    private var starts: [Start] = []
    private var stoppedSessionIDs: [UUID] = []

    func receiveVideo(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedVideoStreamConfiguration
    ) async -> AsyncThrowingStream<VideoReceiveEvent, Error> {
        _ = endpoint
        _ = configuration
        let pair = AsyncThrowingStream<VideoReceiveEvent, Error>.makeStream()
        withLock {
            starts.append(Start(sessionID: sessionID, continuation: pair.continuation))
        }
        return pair.stream
    }

    func stopVideo(sessionID: UUID) async {
        let continuations = withLock { () -> [Continuation] in
            stoppedSessionIDs.append(sessionID)
            return starts
                .filter { $0.sessionID == sessionID }
                .map(\.continuation)
        }
        continuations.forEach { $0.finish() }
    }

    func yield(_ event: VideoReceiveEvent, startIndex: Int) {
        let continuation = withLock {
            starts.indices.contains(startIndex) ? starts[startIndex].continuation : nil
        }
        continuation?.yield(event)
    }

    func startCount() -> Int {
        withLock { starts.count }
    }

    func stopCount() -> Int {
        withLock { stoppedSessionIDs.count }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationAudioReceiveProvider:
    AudioReceiveProvider,
    @unchecked Sendable
{
    private typealias Continuation =
        AsyncThrowingStream<AudioReceiveEvent, Error>.Continuation

    private struct Start {
        let sessionID: UUID
        let continuation: Continuation
    }

    private let lock = NSLock()
    private var starts: [Start] = []
    private var stoppedSessionIDs: [UUID] = []

    func receiveAudio(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedAudioStreamConfiguration
    ) async -> AsyncThrowingStream<AudioReceiveEvent, Error> {
        _ = endpoint
        _ = configuration
        let pair = AsyncThrowingStream<AudioReceiveEvent, Error>.makeStream()
        withLock {
            starts.append(Start(sessionID: sessionID, continuation: pair.continuation))
        }
        return pair.stream
    }

    func stopAudio(sessionID: UUID) async {
        let continuations = withLock { () -> [Continuation] in
            stoppedSessionIDs.append(sessionID)
            return starts
                .filter { $0.sessionID == sessionID }
                .map(\.continuation)
        }
        continuations.forEach { $0.finish() }
    }

    func yield(_ event: AudioReceiveEvent, startIndex: Int) {
        let continuation = withLock {
            starts.indices.contains(startIndex) ? starts[startIndex].continuation : nil
        }
        continuation?.yield(event)
    }

    func startCount() -> Int {
        withLock { starts.count }
    }

    func stopCount() -> Int {
        withLock { stoppedSessionIDs.count }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationRemoteInputProvider:
    RemoteInputProvider,
    @unchecked Sendable
{
    struct Snapshot {
        let startCount: Int
        let releaseCount: Int
        let stopCount: Int
    }

    private let lock = NSLock()
    private var activeSessionID: UUID?
    private var startCounter = 0
    private var releaseCounter = 0
    private var stopCounter = 0
    private var feedbackContinuations: [AsyncStream<RemoteInputFeedback>.Continuation] = []

    func startInput(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedInputConfiguration
    ) async throws {
        _ = endpoint
        _ = configuration
        withLock {
            activeSessionID = sessionID
            startCounter += 1
        }
    }

    func send(_ event: RemoteInputEvent, sessionID: UUID) async throws {
        _ = event
        guard withLock({ activeSessionID == sessionID }) else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
    }

    func feedback(sessionID: UUID) async -> AsyncStream<RemoteInputFeedback> {
        _ = sessionID
        let pair = AsyncStream<RemoteInputFeedback>.makeStream()
        withLock { feedbackContinuations.append(pair.continuation) }
        return pair.stream
    }

    func releaseAll(sessionID: UUID) async {
        withLock {
            guard activeSessionID == sessionID else { return }
            releaseCounter += 1
        }
    }

    func stopInput(sessionID: UUID) async {
        let continuation = withLock { () -> AsyncStream<RemoteInputFeedback>.Continuation? in
            guard activeSessionID == sessionID else { return nil }
            activeSessionID = nil
            stopCounter += 1
            return feedbackContinuations.popLast()
        }
        continuation?.finish()
    }

    func snapshot() -> Snapshot {
        withLock {
            Snapshot(
                startCount: startCounter,
                releaseCount: releaseCounter,
                stopCount: stopCounter
            )
        }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationVideoProcessorFactory:
    SessionVideoProcessorCreating,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var processors: [ApplicationIntegrationVideoProcessor] = []

    func makeVideoProcessor(
        sessionID: UUID,
        mediaGeneration: UInt64,
        configuration: NegotiatedVideoStreamConfiguration,
        controlProvider: any SessionControlProvider,
        presentationEventSink: @escaping @Sendable (
            StreamVideoPresentationEvent
        ) -> Void
    ) async throws -> any SessionVideoProcessing {
        _ = sessionID
        _ = mediaGeneration
        _ = configuration
        _ = controlProvider
        _ = presentationEventSink
        let processor = ApplicationIntegrationVideoProcessor()
        withLock { processors.append(processor) }
        return processor
    }

    func consumeCount(at index: Int) -> Int {
        withLock {
            processors.indices.contains(index) ? processors[index].consumeCount() : 0
        }
    }

    func wasStopped(at index: Int) -> Bool {
        withLock {
            processors.indices.contains(index) && processors[index].wasStopped()
        }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationVideoProcessor:
    SessionVideoProcessing,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var consumed = 0
    private var stopped = false

    func consume(_ event: VideoReceiveEvent) async throws -> Bool {
        _ = event
        return withLock {
            guard !stopped else { return false }
            consumed += 1
            return true
        }
    }

    func updateColorMetadata(_ metadata: VideoColorMetadata) async throws {
        _ = metadata
    }

    func applyLifecycle(_ application: SessionLifecycleApplication) async throws {
        _ = application
    }

    func applyMobileVideo(
        _ application: SessionMobileVideoApplication
    ) async throws {
        _ = application
    }

    func stop() async {
        withLock { stopped = true }
    }

    func consumeCount() -> Int {
        withLock { consumed }
    }

    func wasStopped() -> Bool {
        withLock { stopped }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationAudioRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private let initialCapability: SpatialAudioRouteCapabilityState
    private var engines: [ApplicationIntegrationAudioEngineClient] = []
    private var decoders: [ApplicationIntegrationAudioDecoder] = []
    private var routeSources: [ApplicationIntegrationRouteEventSource] = []
    private var eventTime: UInt64 = 1_000_000

    init(initialCapability: SpatialAudioRouteCapabilityState) {
        self.initialCapability = initialCapability
    }

    func makeDecoder(
        configuration: NegotiatedAudioStreamConfiguration
    ) throws -> any SessionAudioDecoding {
        try configuration.validate()
        let decoder = ApplicationIntegrationAudioDecoder(configuration: configuration)
        withLock { decoders.append(decoder) }
        return decoder
    }

    func makeEngine() -> any AudioEngineClient {
        let engine = ApplicationIntegrationAudioEngineClient(
            capability: initialCapability
        )
        withLock { engines.append(engine) }
        return engine
    }

    func makeRouteSource() -> any SpatialAudioRouteMonitorEventSourcing {
        let source = ApplicationIntegrationRouteEventSource()
        withLock { routeSources.append(source) }
        return source
    }

    func nextEventTime() -> UInt64 {
        withLock {
            eventTime += 1_000_000
            return eventTime
        }
    }

    func engineCount() -> Int {
        withLock { engines.count }
    }

    func engine(at index: Int) -> ApplicationIntegrationAudioEngineClient? {
        withLock { engines.indices.contains(index) ? engines[index] : nil }
    }

    func decoder(at index: Int) -> ApplicationIntegrationAudioDecoder? {
        withLock { decoders.indices.contains(index) ? decoders[index] : nil }
    }

    func routeSource(at index: Int) -> ApplicationIntegrationRouteEventSource? {
        withLock { routeSources.indices.contains(index) ? routeSources[index] : nil }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationAudioDecoder:
    SessionAudioDecoding,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let negotiatedConfiguration: NegotiatedAudioStreamConfiguration
    private var closed = false

    init(configuration: NegotiatedAudioStreamConfiguration) {
        negotiatedConfiguration = configuration
    }

    func decode(_ packet: ReceivedAudioPacket) async throws -> DecodedPCMBuffer {
        let configuration = negotiatedConfiguration
        guard !withLock({ closed }) else {
            throw OpusDecoderError.closed
        }
        return DecodedPCMBuffer(
            sequenceNumber: packet.sequenceNumber,
            rtpTimestamp: packet.timestamp,
            format: .signedInt16(
                sampleRate: configuration.sampleRate,
                channelLayout: configuration.channelLayout
            ),
            frameCount: configuration.samplesPerFrame,
            interleavedSamples: [Int16](
                repeating: Int16(packet.sequenceNumber),
                count: configuration.samplesPerFrame * configuration.channelCount
            )
        )
    }

    func close() async {
        withLock { closed = true }
    }

    func configuration() -> NegotiatedAudioStreamConfiguration {
        negotiatedConfiguration
    }

    func isClosed() -> Bool {
        withLock { closed }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationAudioEngineClient:
    AudioEngineClient,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var capability: SpatialAudioRouteCapabilityState
    private var configuredAudio: [StreamAudioConfiguration] = []
    private var intents: [SpatialAudioGraphIntent] = []
    private var modes: [SpatialAudioGraphMode] = []
    private var scheduled: [DecodedPCMBuffer] = []
    private var stopped = false

    init(capability: SpatialAudioRouteCapabilityState) {
        self.capability = capability
    }

    func configure(
        _ configuration: StreamAudioConfiguration,
        graphIntent: SpatialAudioGraphIntent
    ) throws -> SpatialAudioRuntimeSnapshot {
        try configuration.validate()
        let usesEnvironment = graphIntent.userEnablesSpatialAudio
            && configuration.channelLayout.spatialEligibility == .ambienceBed
            && graphIntent.route.outputAvailable
            && graphIntent.route.systemSpatialSupport != .unsupported
        let graphMode: SpatialAudioGraphMode = usesEnvironment
            ? .environmentAmbienceBed
            : .nonspatialMixer
        let strategy: SpatialAudioPlatformStrategy = usesEnvironment
            ? .environmentListener
            : .none
        let graph = SpatialAudioGraphSnapshot(
            revision: graphIntent.revision,
            mode: graphMode,
            layoutSignature: configuration.channelLayout.signature,
            hasApplicableRenderingAlgorithm: usesEnvironment,
            platformStrategy: strategy,
            listenerHeadTrackingCapable: usesEnvironment,
            listenerHeadTrackingReadback: false,
            visionExperienceReadback: nil
        )
        withLock {
            configuredAudio.append(configuration)
            intents.append(graphIntent)
            modes.append(graphMode)
            stopped = false
        }
        return SpatialAudioRuntimeResolver.resolve(
            intent: graphIntent,
            layout: configuration.channelLayout,
            graph: graph
        )
    }

    func start() throws {
        withLock { stopped = false }
    }

    func schedule(
        _ buffer: DecodedPCMBuffer,
        completion: @escaping @Sendable () -> Void
    ) throws {
        withLock { scheduled.append(buffer) }
        completion()
    }

    func stop(drain: Bool) {
        _ = drain
        withLock { stopped = true }
    }

    func routeSnapshot() -> AudioRouteSnapshot {
        AudioRouteSnapshot(
            outputNames: ["Bounded Integration Output"],
            sampleRate: 48_000,
            outputChannelCount: 8,
            preferredBufferDuration: 0.005
        )
    }

    func currentSpatialRouteCapability() -> SpatialAudioRouteCapabilityState {
        withLock { capability }
    }

    func setCapability(_ capability: SpatialAudioRouteCapabilityState) {
        withLock { self.capability = capability }
    }

    func configurations() -> [StreamAudioConfiguration] {
        withLock { configuredAudio }
    }

    func graphIntents() -> [SpatialAudioGraphIntent] {
        withLock { intents }
    }

    func graphModes() -> [SpatialAudioGraphMode] {
        withLock { modes }
    }

    func scheduledBuffers() -> [DecodedPCMBuffer] {
        withLock { scheduled }
    }

    func wasStopped() -> Bool {
        withLock { stopped }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ApplicationIntegrationRouteEventSource:
    SpatialAudioRouteMonitorEventSourcing,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var handler: (@Sendable (SpatialAudioRouteMonitorEvent) -> Void)?
    private var lateHandler: (@Sendable (SpatialAudioRouteMonitorEvent) -> Void)?
    private var stopped = false

    func start(
        handler: @escaping @Sendable (SpatialAudioRouteMonitorEvent) -> Void
    ) {
        withLock {
            self.handler = handler
            lateHandler = handler
            stopped = false
        }
    }

    func stop() {
        withLock {
            handler = nil
            stopped = true
        }
    }

    func emit(_ event: SpatialAudioRouteMonitorEvent) {
        withLock { handler }?(event)
    }

    func emitLate(_ event: SpatialAudioRouteMonitorEvent) {
        withLock { lateHandler }?(event)
    }

    func wasStopped() -> Bool {
        withLock { stopped }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private struct StubServerInfoClient: ServerInfoClient {
    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        ServerInfo(
            name: "Test Host",
            uniqueID: "host-1",
            macAddress: nil,
            state: "ONLINE",
            supportsHDR: true,
            rawValues: [:]
        )
    }
}

private struct StubAppListClient: AppListClient {
    func fetchApps(from endpoint: HostEndpoint, clientUniqueID: String, pinnedIdentity: PinnedHostIdentity?) async throws -> [RemoteApp] {
        [
            RemoteApp(id: "2", name: "Game", supportsHDR: true, installPath: nil),
            RemoteApp(id: "1", name: "Desktop", supportsHDR: false, installPath: nil)
        ]
    }

    func fetchArtwork(for app: RemoteApp, from endpoint: HostEndpoint, clientUniqueID: String, pinnedIdentity: PinnedHostIdentity?) async throws -> RemoteAppArtwork? {
        nil
    }
}

private actor RecordingUniqueIDAppListClient: AppListClient {
    private var uniqueIDs: [String] = []

    func fetchApps(
        from endpoint: HostEndpoint,
        clientUniqueID: String,
        pinnedIdentity: PinnedHostIdentity?
    ) async throws -> [RemoteApp] {
        _ = endpoint
        _ = pinnedIdentity
        uniqueIDs.append(clientUniqueID)
        return [RemoteApp(id: "0", name: "Desktop", supportsHDR: false, installPath: nil)]
    }

    func fetchArtwork(
        for app: RemoteApp,
        from endpoint: HostEndpoint,
        clientUniqueID: String,
        pinnedIdentity: PinnedHostIdentity?
    ) async throws -> RemoteAppArtwork? {
        _ = app
        _ = endpoint
        _ = clientUniqueID
        _ = pinnedIdentity
        return nil
    }

    func recordedUniqueIDs() -> [String] {
        uniqueIDs
    }
}

private actor StubStreamLaunchClient: StreamLaunchClient {
    private var launchCount = 0
    private var launchedKeys: [RemoteInputKeyMaterial] = []

    func launch(_ request: StreamLaunchRequest, parameters: StreamNegotiationParameters) async throws -> StreamLaunchResponse {
        launchCount += 1
        launchedKeys.append(request.remoteInputKey)
        return StreamLaunchResponse(
            sessionURL: "rtsp://test/session",
            gameSessionID: "session-1",
            rawValues: ["sessionurl": "rtsp://test/session"]
        )
    }

    func resume(_ request: StreamLaunchRequest, parameters: StreamNegotiationParameters) async throws -> StreamLaunchResponse {
        StreamLaunchResponse(
            sessionURL: "rtsp://test/session",
            gameSessionID: nil,
            rawValues: ["resume": "1"]
        )
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {
    }

    func currentLaunchCount() -> Int {
        launchCount
    }

    func currentLaunchedKeys() -> [RemoteInputKeyMaterial] {
        launchedKeys
    }
}

private final class ScriptedInputKeyGenerator: RemoteInputKeyMaterialGenerating, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [Result<RemoteInputKeyMaterial, Error>]
    private var generationCount = 0

    init(results: [Result<RemoteInputKeyMaterial, Error>]) {
        self.results = results
    }

    func generate() throws -> RemoteInputKeyMaterial {
        lock.lock()
        defer { lock.unlock() }
        generationCount += 1
        guard !results.isEmpty else {
            throw InputKeyGeneratorTestError.exhausted
        }
        return try results.removeFirst().get()
    }

    func currentGenerationCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return generationCount
    }
}

private enum InputKeyGeneratorTestError: Error {
    case failed
    case exhausted
}

private enum MediaEnvironmentApplicationTestError: Error {
    case failed
}

private struct AvailabilityVideoReceiveProvider: VideoReceiveProvider {
    func receiveVideo(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedVideoStreamConfiguration
    ) async -> AsyncThrowingStream<VideoReceiveEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func stopVideo(sessionID: UUID) async {
    }
}

private struct AvailabilityAudioReceiveProvider: AudioReceiveProvider {
    func receiveAudio(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedAudioStreamConfiguration
    ) async -> AsyncThrowingStream<AudioReceiveEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func stopAudio(sessionID: UUID) async {
    }
}

private struct FixedIdentityProvisioner: ClientIdentityProvisioning {
    let identity: ClientIdentityMaterial

    func loadOrCreateIdentity(createdAt: Date) async throws -> ClientIdentityMaterial {
        identity
    }
}

private struct FailingIdentityProvisioner: ClientIdentityProvisioning {
    func loadOrCreateIdentity(createdAt: Date) async throws -> ClientIdentityMaterial {
        throw PairingTestError.identityFailure
    }
}

private actor ControlledIdentityProvisioner: ClientIdentityProvisioning {
    private var started = false
    private var continuation: CheckedContinuation<ClientIdentityMaterial, Never>?

    func loadOrCreateIdentity(createdAt: Date) async throws -> ClientIdentityMaterial {
        started = true
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func hasStarted() -> Bool {
        started
    }

    func complete(with identity: ClientIdentityMaterial) {
        continuation?.resume(returning: identity)
        continuation = nil
    }
}

private enum PairingTestError: Error {
    case identityFailure
}

private final class ControlledSessionControlProvider: SessionControlProvider, @unchecked Sendable {
    struct StartRecord {
        var sessionID: UUID
        var request: StreamLaunchRequest
    }

    enum Ending: CaseIterable {
        case incomplete
        case failure
    }

    private typealias Continuation = AsyncThrowingStream<
        SessionControlEvent,
        Error
    >.Continuation

    private let lock = NSLock()
    private let automaticallyCompletes: Bool
    private let retainsStoppedContinuation: Bool
    private var startRecords: [StartRecord] = []
    private var continuations: [UUID: Continuation] = [:]
    private var stoppedSessionIDs: [UUID] = []

    init(
        automaticallyCompletes: Bool = false,
        retainsStoppedContinuation: Bool = false
    ) {
        self.automaticallyCompletes = automaticallyCompletes
        self.retainsStoppedContinuation = retainsStoppedContinuation
    }

    func start(
        sessionID: UUID,
        request: StreamLaunchRequest
    ) async -> AsyncThrowingStream<SessionControlEvent, Error> {
        AsyncThrowingStream { continuation in
            withLock {
                startRecords.append(StartRecord(sessionID: sessionID, request: request))
                continuations[sessionID] = continuation
            }
            guard automaticallyCompletes else { return }
            continuation.yield(.launchAccepted(StreamLaunchResponse(
                sessionURL: "rtsp://example.invalid/session",
                gameSessionID: "session-1",
                rawValues: [:]
            )))
            continuation.yield(.rtspReady)
            continuation.yield(.negotiated(Self.configuration(
                sessionID: sessionID,
                keyMaterial: request.remoteInputKey
            )))
            continuation.yield(.channelsReady(.all))
            continuation.yield(.terminated(reason: nil))
            _ = withLock {
                continuations.removeValue(forKey: sessionID)
            }
            continuation.finish()
        }
    }

    func requestIDR(sessionID: UUID) async throws {
        _ = sessionID
    }

    func stop(sessionID: UUID) async {
        let continuation = withLock {
            stoppedSessionIDs.append(sessionID)
            guard !retainsStoppedContinuation else {
                return continuations[sessionID]
            }
            return continuations.removeValue(forKey: sessionID)
        }
        guard !retainsStoppedContinuation else { return }
        continuation?.finish()
    }

    func yield(_ event: SessionControlEvent, sessionID: UUID) {
        continuation(for: sessionID)?.yield(event)
    }

    func finish(
        sessionID: UUID,
        ending: Ending = .incomplete
    ) {
        let continuation = withLock {
            continuations.removeValue(forKey: sessionID)
        }
        switch ending {
        case .incomplete:
            continuation?.finish()
        case .failure:
            continuation?.finish(throwing: StreamNegotiationFailure(
                code: .transportUnavailable,
                subsystem: "session.control",
                message: "Session control failed."
            ))
        }
    }

    func finish(sessionID: UUID, throwing error: Error) {
        let continuation = withLock {
            continuations.removeValue(forKey: sessionID)
        }
        continuation?.finish(throwing: error)
    }

    func currentStartRecords() -> [StartRecord] {
        withLock { startRecords }
    }

    func currentStoppedSessionIDs() -> [UUID] {
        withLock { stoppedSessionIDs }
    }

    private func continuation(for sessionID: UUID) -> Continuation? {
        withLock { continuations[sessionID] }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }

    private static func configuration(
        sessionID: UUID,
        keyMaterial: RemoteInputKeyMaterial
    ) -> NegotiatedSessionConfiguration {
        NegotiatedSessionConfiguration(
            sessionID: sessionID,
            controlEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 47_999,
                transport: .udp
            ),
            videoEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 48_000,
                transport: .udp
            ),
            audioEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 48_010,
                transport: .udp
            ),
            inputEndpoint: RuntimeNetworkEndpoint(
                host: "example.invalid",
                port: 35_043,
                transport: .tcp
            ),
            video: NegotiatedVideoStreamConfiguration(
                codec: .hevc,
                width: 3_840,
                height: 2_160,
                frameRate: 60,
                colorMetadata: .rec709VideoRange(),
                maximumPacketSize: 1_400
            ),
            audio: NegotiatedAudioStreamConfiguration(
                sampleRate: 48_000,
                channelLayout: .stereo,
                streamCount: 1,
                coupledStreamCount: 1,
                samplesPerFrame: 240,
                channelMapping: [0, 1],
                maximumPacketSize: 1_400
            ),
            input: NegotiatedInputConfiguration(
                keyMaterial: keyMaterial,
                encrypted: true,
                maximumMessageSize: RemoteInputWireCodec.maximumPacketSize
            ),
            requiredChannels: .all
        )
    }
}

private final class ControlledSessionMediaEnvironment: SessionMediaEnvironment, @unchecked Sendable {
    struct StartRecord {
        var sessionID: UUID
        var configuration: NegotiatedSessionConfiguration
    }

    private typealias Continuation = AsyncThrowingStream<
        SessionMediaEnvironmentEvent,
        Error
    >.Continuation

    private let lock = NSLock()
    private let automaticallyReady: Bool
    private let failsLifecycleApplication: Bool
    private let failsInputSend: Bool
    private let failsTVVisionDisplayApplication: Bool
    private let blocksFirstTVVisionActivation: Bool
    private let blocksFailingTVVisionActivationAfterTerminalEvent: Bool
    private var startRecords: [StartRecord] = []
    private var stoppedSessionIDs: [UUID] = []
    private var continuations: [UUID: Continuation] = [:]
    private var sentInputApplications: [SessionInputApplication] = []
    private var releasedInputApplications: [SessionInputReleaseApplication] = []
    private var lifecycleApplications: [SessionLifecycleApplication] = []
    private var spatialAudioPreferenceApplications:
        [SessionSpatialAudioPreferenceApplication] = []
    private var tvVisionPlatformPresentationApplications:
        [SessionTVVisionPlatformPresentationApplication] = []
    private var shouldBlockNextRelease = false
    private var shouldFailNextRelease = false
    private var blockedReleaseContinuation: CheckedContinuation<Void, Never>?
    private var shouldBlockNextInputSend = false
    private var blockedInputSendContinuation: CheckedContinuation<Void, Never>?
    private var shouldBlockNextStop = false
    private var blockedStopContinuation: CheckedContinuation<Void, Never>?
    private var blockedTVVisionActivationContinuation:
        CheckedContinuation<Void, Never>?
    private var shouldBlockTVVisionActivation: Bool

    init(
        automaticallyReady: Bool = true,
        failsLifecycleApplication: Bool = false,
        failsInputSend: Bool = false,
        failsTVVisionDisplayApplication: Bool = false,
        blocksFirstTVVisionActivation: Bool = false,
        blocksFailingTVVisionActivationAfterTerminalEvent: Bool = false
    ) {
        self.automaticallyReady = automaticallyReady
        self.failsLifecycleApplication = failsLifecycleApplication
        self.failsInputSend = failsInputSend
        self.failsTVVisionDisplayApplication = failsTVVisionDisplayApplication
        self.blocksFirstTVVisionActivation = blocksFirstTVVisionActivation
        shouldBlockTVVisionActivation = blocksFirstTVVisionActivation
        self.blocksFailingTVVisionActivationAfterTerminalEvent =
            blocksFailingTVVisionActivationAfterTerminalEvent
    }

    func start(
        sessionID: UUID,
        configuration: NegotiatedSessionConfiguration,
        controlProvider: any SessionControlProvider
    ) async throws -> AsyncThrowingStream<SessionMediaEnvironmentEvent, Error> {
        _ = controlProvider
        let pair = AsyncThrowingStream<SessionMediaEnvironmentEvent, Error>.makeStream()
        withLock {
            startRecords.append(StartRecord(
                sessionID: sessionID,
                configuration: configuration
            ))
            continuations[sessionID] = pair.continuation
        }
        if automaticallyReady {
            pair.continuation.yield(.readiness([.video, .audio, .input]))
        }
        return pair.stream
    }

    func updateVideoColorMetadata(
        _ metadata: VideoColorMetadata,
        sessionID: UUID
    ) async throws {
        _ = metadata
        _ = sessionID
    }

    func applyLifecycle(_ application: SessionLifecycleApplication) async throws {
        let state = withLock {
            (
                continuations[application.sessionID] != nil,
                UInt64(startRecords.count),
                lifecycleApplications.last
            )
        }
        guard state.0 else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard application.mediaGeneration == state.1 else {
            throw SessionMediaEnvironmentError.staleLifecycleApplication
        }
        if failsLifecycleApplication {
            throw MediaEnvironmentApplicationTestError.failed
        }
        if let previous = state.2,
           previous.sessionID == application.sessionID,
           previous.mediaGeneration == application.mediaGeneration {
            if previous == application { return }
            guard application.lifecycleRevision > previous.lifecycleRevision else {
                throw SessionMediaEnvironmentError.staleLifecycleApplication
            }
        }
        withLock { lifecycleApplications.append(application) }
    }

    func updateSpatialAudioPreferences(
        _ application: SessionSpatialAudioPreferenceApplication
    ) async throws {
        let state = withLock {
            (
                continuations[application.sessionID] != nil,
                UInt64(startRecords.count)
            )
        }
        guard state.0 else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard application.mediaGeneration == state.1 else {
            throw SessionMediaEnvironmentError.staleAudioApplication
        }
        withLock {
            spatialAudioPreferenceApplications.append(application)
        }
    }

    func applyTVVisionPlatformPresentation(
        _ application: SessionTVVisionPlatformPresentationApplication
    ) async throws {
        let state = withLock {
            (
                continuations[application.ownership.sessionID] != nil,
                UInt64(startRecords.count)
            )
        }
        guard state.0 else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard application.ownership.mediaGeneration == state.1 else {
            throw SessionMediaEnvironmentError
                .staleTVVisionPlatformPresentationApplication
        }
        withLock {
            tvVisionPlatformPresentationApplications.append(application)
        }
        if failsTVVisionDisplayApplication,
           case .display = application.action {
            throw MediaEnvironmentApplicationTestError.failed
        }
        if blocksFirstTVVisionActivation,
           application.action == .activate,
           withLock({
               guard shouldBlockTVVisionActivation else { return false }
               shouldBlockTVVisionActivation = false
               return true
           }) {
            await withCheckedContinuation { continuation in
                withLock {
                    blockedTVVisionActivationContinuation = continuation
                }
            }
        }
        if blocksFailingTVVisionActivationAfterTerminalEvent,
           application.action == .activate {
            let revision = try TVVisionSemanticRevision(rawValue: 1)
            let terminal = SessionTVVisionPlatformPresentationState(
                sessionID: application.ownership.sessionID,
                mediaGeneration: application.ownership.mediaGeneration,
                snapshot: TVVisionPlatformPresentationCoordinatorSnapshot(
                    ownership: application.ownership,
                    sequence: 1,
                    revision: revision,
                    phase: .failed(.invalidComponent(.video)),
                    presentation: nil,
                    visionWindowedPresentation: nil,
                    display: nil,
                    audioRoute: nil,
                    video: TVVisionPlatformVideoSnapshot(
                        phase: .idle,
                        lastDeliveryRevision: nil,
                        isPresented: false
                    ),
                    diagnostics: [],
                    teardownCount: 1,
                    isSemanticRevisionExhausted: false,
                    isSequenceExhausted: false
                )
            )
            continuation(for: application.ownership.sessionID)?.yield(
                .tvVisionPlatformPresentation(terminal)
            )
            await withCheckedContinuation { continuation in
                withLock {
                    blockedTVVisionActivationContinuation = continuation
                }
            }
            throw SessionMediaEnvironmentError
                .invalidTVVisionPlatformPresentationApplication
        }
    }

    func sendInput(_ application: SessionInputApplication) async throws {
        let currentGeneration = withLock { UInt64(startRecords.count) }
        guard continuation(for: application.sessionID) != nil else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard application.mediaGeneration == currentGeneration else {
            throw SessionMediaEnvironmentError.staleInputApplication
        }
        if failsInputSend {
            throw RemoteInputRuntimeError.deliveryFailed
        }
        let shouldBlock = withLock {
            let value = shouldBlockNextInputSend
            shouldBlockNextInputSend = false
            return value
        }
        if shouldBlock {
            await withCheckedContinuation { continuation in
                withLock { blockedInputSendContinuation = continuation }
            }
            guard continuation(for: application.sessionID) != nil else {
                throw SessionMediaEnvironmentError.inactiveSession
            }
            guard application.mediaGeneration
                    == withLock({ UInt64(startRecords.count) }) else {
                throw SessionMediaEnvironmentError.staleInputApplication
            }
        }
        withLock { sentInputApplications.append(application) }
    }

    func releaseInput(_ application: SessionInputReleaseApplication) async throws {
        try validateRelease(application)
        let behavior = withLock {
            let value = (shouldBlockNextRelease, shouldFailNextRelease)
            shouldBlockNextRelease = false
            shouldFailNextRelease = false
            releasedInputApplications.append(application)
            return value
        }
        if behavior.0 {
            await withCheckedContinuation { continuation in
                withLock { blockedReleaseContinuation = continuation }
            }
        }
        if behavior.1 {
            throw RemoteInputRuntimeError.deliveryFailed
        }
        try validateRelease(application)
    }

    func stop(sessionID: UUID) async -> SessionTeardownReport? {
        let state = withLock {
            stoppedSessionIDs.append(sessionID)
            let continuation = continuations.removeValue(forKey: sessionID)
            let shouldBlock = shouldBlockNextStop
            shouldBlockNextStop = false
            return (continuation, shouldBlock)
        }
        state.0?.finish()
        if state.1 {
            await withCheckedContinuation { continuation in
                withLock { blockedStopContinuation = continuation }
            }
        }
        return SessionTeardownReport(
            cancelledTaskCount: 0,
            stoppedResourceCount: 3,
            unfinishedTasks: [],
            taskOutcomes: [:]
        )
    }

    func snapshot() async -> SessionMediaEnvironmentSnapshot {
        let state = withLock {
            (
                startRecords.last?.sessionID,
                startRecords.count,
                continuations.isEmpty,
                lifecycleApplications.last
            )
        }
        return SessionMediaEnvironmentSnapshot(
            sessionID: state.2 ? nil : state.0,
            generation: UInt64(state.1),
            readiness: state.2 ? [] : [.video, .audio, .input],
            resourcePhase: state.2 ? nil : .active,
            activeTaskCount: 0,
            activeResourceCount: state.2 ? 0 : 3,
            lastTeardownReport: nil,
            lifecycleApplication: state.3
        )
    }

    func yieldReadiness(
        _ readiness: SessionChannelReadiness,
        sessionID: UUID
    ) {
        continuation(for: sessionID)?.yield(.readiness(readiness))
    }

    func yieldFeedback(_ feedback: RemoteInputFeedback, sessionID: UUID) {
        continuation(for: sessionID)?.yield(.feedback(feedback))
    }

    func yieldVideoPresentation(
        _ event: StreamVideoPresentationEvent,
        sessionID: UUID
    ) {
        continuation(for: sessionID)?.yield(.videoPresentation(event))
    }

    func yieldAudioRuntime(
        _ state: SessionMediaAudioRuntimeState,
        sessionID: UUID
    ) {
        continuation(for: sessionID)?.yield(.audioRuntime(state))
    }

    func yieldMobileRuntime(
        _ state: SessionMobileRuntimeState,
        sessionID: UUID
    ) {
        continuation(for: sessionID)?.yield(.mobileRuntime(state))
    }

    func yieldTVVisionPlatformPresentation(
        _ state: SessionTVVisionPlatformPresentationState,
        sessionID: UUID
    ) {
        continuation(for: sessionID)?.yield(
            .tvVisionPlatformPresentation(state)
        )
    }

    func finish(sessionID: UUID, throwing error: Error) {
        let continuation = withLock { continuations.removeValue(forKey: sessionID) }
        continuation?.finish(throwing: error)
    }

    func currentStartRecords() -> [StartRecord] {
        withLock { startRecords }
    }

    func currentStoppedSessionIDs() -> [UUID] {
        withLock { stoppedSessionIDs }
    }

    func currentSentInputApplications() -> [SessionInputApplication] {
        withLock { sentInputApplications }
    }

    func currentReleasedInputApplications() -> [SessionInputReleaseApplication] {
        withLock { releasedInputApplications }
    }

    func blockNextInputSend() {
        withLock { shouldBlockNextInputSend = true }
    }

    func hasBlockedInputSend() -> Bool {
        withLock { blockedInputSendContinuation != nil }
    }

    func resumeBlockedInputSend() {
        let continuation = withLock {
            defer { blockedInputSendContinuation = nil }
            return blockedInputSendContinuation
        }
        continuation?.resume()
    }

    func currentLifecycleApplications() -> [SessionLifecycleApplication] {
        withLock { lifecycleApplications }
    }

    func currentTVVisionPlatformPresentationApplications()
        -> [SessionTVVisionPlatformPresentationApplication] {
        withLock { tvVisionPlatformPresentationApplications }
    }

    func hasBlockedTVVisionActivation() -> Bool {
        withLock { blockedTVVisionActivationContinuation != nil }
    }

    func resumeBlockedTVVisionActivation() {
        let continuation = withLock {
            defer { blockedTVVisionActivationContinuation = nil }
            return blockedTVVisionActivationContinuation
        }
        continuation?.resume()
    }

    func currentSpatialAudioPreferenceApplications()
        -> [SessionSpatialAudioPreferenceApplication] {
        withLock { spatialAudioPreferenceApplications }
    }

    func blockNextRelease() {
        withLock { shouldBlockNextRelease = true }
    }

    func failNextRelease() {
        withLock { shouldFailNextRelease = true }
    }

    func hasBlockedRelease() -> Bool {
        withLock { blockedReleaseContinuation != nil }
    }

    func resumeBlockedRelease() {
        let continuation = withLock {
            let value = blockedReleaseContinuation
            blockedReleaseContinuation = nil
            return value
        }
        continuation?.resume()
    }

    func blockNextStop() {
        withLock { shouldBlockNextStop = true }
    }

    func hasBlockedStop() -> Bool {
        withLock { blockedStopContinuation != nil }
    }

    func resumeBlockedStop() {
        let continuation = withLock {
            let value = blockedStopContinuation
            blockedStopContinuation = nil
            return value
        }
        continuation?.resume()
    }

    private func validateRelease(
        _ application: SessionInputReleaseApplication
    ) throws {
        let state = withLock {
            (continuations[application.sessionID] != nil, UInt64(startRecords.count))
        }
        guard state.0 else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard application.mediaGeneration == state.1 else {
            throw SessionMediaEnvironmentError.staleInputApplication
        }
    }

    private func continuation(for sessionID: UUID) -> Continuation? {
        withLock { continuations[sessionID] }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class BlockingSessionMediaEnvironment: SessionMediaEnvironment, @unchecked Sendable {
    private let lock = NSLock()
    private var started = false
    private var startContinuation: CheckedContinuation<
        AsyncThrowingStream<SessionMediaEnvironmentEvent, Error>,
        Never
    >?
    private var stoppedSessionIDs: [UUID] = []

    func start(
        sessionID: UUID,
        configuration: NegotiatedSessionConfiguration,
        controlProvider: any SessionControlProvider
    ) async throws -> AsyncThrowingStream<SessionMediaEnvironmentEvent, Error> {
        _ = sessionID
        _ = configuration
        _ = controlProvider
        setStarted()
        return await withCheckedContinuation { continuation in
            withLock { startContinuation = continuation }
        }
    }

    func updateVideoColorMetadata(
        _ metadata: VideoColorMetadata,
        sessionID: UUID
    ) async throws {
        _ = metadata
        _ = sessionID
    }

    func applyLifecycle(_ application: SessionLifecycleApplication) async throws {
        _ = application
    }

    func updateSpatialAudioPreferences(
        _ application: SessionSpatialAudioPreferenceApplication
    ) async throws {
        _ = application
    }

    func sendInput(_ application: SessionInputApplication) async throws {
        _ = application
    }

    func releaseInput(_ application: SessionInputReleaseApplication) async throws {
        _ = application
    }

    func stop(sessionID: UUID) async -> SessionTeardownReport? {
        withLock { stoppedSessionIDs.append(sessionID) }
        return SessionTeardownReport(
            cancelledTaskCount: 0,
            stoppedResourceCount: 0,
            unfinishedTasks: [],
            taskOutcomes: [:]
        )
    }

    func snapshot() async -> SessionMediaEnvironmentSnapshot {
        SessionMediaEnvironmentSnapshot(
            sessionID: nil,
            generation: 0,
            readiness: [],
            resourcePhase: nil,
            activeTaskCount: 0,
            activeResourceCount: 0,
            lastTeardownReport: nil
        )
    }

    func hasStarted() -> Bool {
        withLock { started }
    }

    func completeStart() {
        let continuation = withLock { () -> CheckedContinuation<
            AsyncThrowingStream<SessionMediaEnvironmentEvent, Error>,
            Never
        >? in
            defer { startContinuation = nil }
            return startContinuation
        }
        let stream = AsyncThrowingStream<SessionMediaEnvironmentEvent, Error> { continuation in
            continuation.yield(.readiness([.video, .audio, .input]))
        }
        continuation?.resume(returning: stream)
    }

    func currentStoppedSessionIDs() -> [UUID] {
        withLock { stoppedSessionIDs }
    }

    private func setStarted() {
        withLock { started = true }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ControlledPairingProvider: PairingRuntimeProvider, @unchecked Sendable {
    enum Completion {
        case invalid
        case incomplete
    }

    private typealias Continuation = AsyncThrowingStream<PairingRuntimeEvent, Error>.Continuation
    private let lock = NSLock()
    private var requests: [PairingRuntimeRequest] = []
    private var continuations: [UUID: Continuation] = [:]
    private var cancelledAttemptIDs: [UUID] = []

    func pair(
        _ request: PairingRuntimeRequest
    ) async -> AsyncThrowingStream<PairingRuntimeEvent, Error> {
        AsyncThrowingStream { continuation in
            lock.lock()
            requests.append(request)
            continuations[request.attemptID] = continuation
            lock.unlock()
        }
    }

    func cancelPairing(attemptID: UUID) async {
        withLock {
            cancelledAttemptIDs.append(attemptID)
        }
    }

    func currentRequestCount() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return requests.count
    }

    func latestRequest() -> PairingRuntimeRequest? {
        lock.lock()
        defer { lock.unlock() }
        return requests.last
    }

    func currentCancelledAttemptIDs() -> [UUID] {
        lock.lock()
        defer { lock.unlock() }
        return cancelledAttemptIDs
    }

    func yieldProgress(
        _ stage: PairingStage,
        for request: PairingRuntimeRequest,
        attemptID: UUID? = nil,
        hostID: UUID? = nil
    ) {
        let continuation = continuation(for: request.attemptID)
        continuation?.yield(.progress(PairingSnapshot(
            attemptID: attemptID ?? request.attemptID,
            hostID: hostID ?? request.host.id,
            stage: stage,
            digestAlgorithm: .sha256,
            failure: nil,
            updatedAt: Date(timeIntervalSince1970: 200)
        )))
    }

    func yieldFailure(
        _ failure: PairingFailure,
        for request: PairingRuntimeRequest
    ) {
        continuation(for: request.attemptID)?.yield(.progress(PairingSnapshot(
            attemptID: request.attemptID,
            hostID: request.host.id,
            stage: .failed,
            digestAlgorithm: .sha256,
            failure: failure,
            updatedAt: Date(timeIntervalSince1970: 201)
        )))
    }

    func completeAuthenticated(_ request: PairingRuntimeRequest) {
        let continuation = removeContinuation(for: request.attemptID)
        continuation?.yield(.completed(authenticatedResult(for: request)))
        continuation?.finish()
    }

    func finish(_ request: PairingRuntimeRequest, completion: Completion) {
        let continuation = removeContinuation(for: request.attemptID)
        switch completion {
        case .invalid:
            var result = authenticatedResult(for: request)
            result.host.pinnedIdentity = nil
            continuation?.yield(.completed(result))
        case .incomplete:
            break
        }
        continuation?.finish()
    }

    private func continuation(for attemptID: UUID) -> Continuation? {
        lock.lock()
        defer { lock.unlock() }
        return continuations[attemptID]
    }

    private func removeContinuation(for attemptID: UUID) -> Continuation? {
        lock.lock()
        defer { lock.unlock() }
        return continuations.removeValue(forKey: attemptID)
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }

    private func authenticatedResult(for request: PairingRuntimeRequest) -> PairingResult {
        let certificate = Data([0x30, 0x01, 0x02])
        let fingerprint = "verified-certificate"
        let pairedAt = Date(timeIntervalSince1970: 300)
        var pairedHost = request.host
        pairedHost.pairingState = .paired
        pairedHost.pinnedIdentity = PinnedHostIdentity(
            certificateSHA256: fingerprint,
            serverCertificateDER: certificate,
            pairedAt: pairedAt
        )
        return PairingResult(
            host: pairedHost,
            serverIdentity: PairingServerIdentity(
                certificateDER: certificate,
                certificateSHA256: fingerprint,
                serverMajorVersion: 7
            ),
            digestAlgorithm: .sha256,
            pairedAt: pairedAt
        )
    }
}
