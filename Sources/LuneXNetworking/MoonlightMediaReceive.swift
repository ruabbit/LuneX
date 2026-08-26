import Foundation

enum MoonlightMediaReceiveError: Error, Equatable, Sendable,
    CustomStringConvertible
{
    case invalidEndpoint
    case invalidConfiguration
    case invalidLimits
    case receiveBufferOverflow
    case unexpectedTermination

    var description: String {
        switch self {
        case .invalidEndpoint:
            "Media receive requires a valid UDP endpoint."
        case .invalidConfiguration:
            "Media receive configuration is invalid."
        case .invalidLimits:
            "Media receive timing or buffer limits are invalid."
        case .receiveBufferOverflow:
            "The bounded media receive buffer is full."
        case .unexpectedTermination:
            "The media receive loop ended unexpectedly."
        }
    }
}

enum MoonlightAudioRTPPacketError: Error, Equatable, Sendable,
    CustomStringConvertible
{
    case datagramTooSmall
    case datagramTooLarge
    case unsupportedRTPLayout
    case unsupportedPayloadType(UInt8)
    case emptyPayload

    var description: String {
        switch self {
        case .datagramTooSmall:
            "Audio datagram is shorter than the fixed RTP header."
        case .datagramTooLarge:
            "Audio datagram exceeds the negotiated payload bound."
        case .unsupportedRTPLayout:
            "Audio datagram has an unsupported RTP header layout."
        case let .unsupportedPayloadType(payloadType):
            "Audio RTP payload type \(payloadType) is unsupported."
        case .emptyPayload:
            "Audio RTP packet has no payload."
        }
    }
}

struct MoonlightAudioRTPPacket: Equatable, Sendable {
    static let opusPayloadType: UInt8 = 97
    static let fecPayloadType: UInt8 = 127
    static let fixedHeaderBytes = 12

    var payloadType: UInt8
    var sequenceNumber: UInt16
    var timestamp: UInt32
    var ssrc: UInt32
    var payload: Data

    var isFEC: Bool {
        payloadType == Self.fecPayloadType
    }
}

enum MoonlightAudioRTPPacketParser {
    static func parse(
        _ datagram: Data,
        maximumPayloadSize: Int
    ) throws -> MoonlightAudioRTPPacket {
        guard datagram.count >= MoonlightAudioRTPPacket.fixedHeaderBytes else {
            throw MoonlightAudioRTPPacketError.datagramTooSmall
        }
        guard maximumPayloadSize > 0,
              datagram.count <= maximumPayloadSize
                + MoonlightAudioRTPPacket.fixedHeaderBytes else {
            throw MoonlightAudioRTPPacketError.datagramTooLarge
        }

        let first = byte(datagram, at: 0)
        let rtpVersion = first >> 6
        let hasPadding = first & 0x20 != 0
        let hasExtension = first & 0x10 != 0
        let csrcCount = first & 0x0F
        guard rtpVersion == 2,
              !hasPadding,
              !hasExtension,
              csrcCount == 0 else {
            throw MoonlightAudioRTPPacketError.unsupportedRTPLayout
        }

        let payloadType = byte(datagram, at: 1) & 0x7F
        guard payloadType == MoonlightAudioRTPPacket.opusPayloadType
                || payloadType == MoonlightAudioRTPPacket.fecPayloadType else {
            throw MoonlightAudioRTPPacketError
                .unsupportedPayloadType(payloadType)
        }
        let payloadStart = datagram.index(
            datagram.startIndex,
            offsetBy: MoonlightAudioRTPPacket.fixedHeaderBytes
        )
        let payload = Data(datagram[payloadStart...])
        guard !payload.isEmpty else {
            throw MoonlightAudioRTPPacketError.emptyPayload
        }
        return MoonlightAudioRTPPacket(
            payloadType: payloadType,
            sequenceNumber: readBigEndian16(datagram, at: 2),
            timestamp: readBigEndian32(datagram, at: 4),
            ssrc: readBigEndian32(datagram, at: 8),
            payload: payload
        )
    }

    private static func byte(_ data: Data, at offset: Int) -> UInt8 {
        data[data.index(data.startIndex, offsetBy: offset)]
    }

    private static func readBigEndian16(_ data: Data, at offset: Int) -> UInt16 {
        (UInt16(byte(data, at: offset)) << 8)
            | UInt16(byte(data, at: offset + 1))
    }

    private static func readBigEndian32(_ data: Data, at offset: Int) -> UInt32 {
        (UInt32(byte(data, at: offset)) << 24)
            | (UInt32(byte(data, at: offset + 1)) << 16)
            | (UInt32(byte(data, at: offset + 2)) << 8)
            | UInt32(byte(data, at: offset + 3))
    }
}

protocol MoonlightDatagramChannel: Sendable {
    func connect(timeout: Duration) async throws
    func send(_ data: Data, timeout: Duration) async throws
    func receiveWithoutDeadline(
        minimumLength: Int,
        maximumLength: Int?
    ) async throws -> NetworkReceiveChunk
    func cancel() async
}

extension NetworkByteChannel: MoonlightDatagramChannel {}

typealias MoonlightDatagramChannelFactory = @Sendable (
    RuntimeNetworkEndpoint,
    NetworkChannelLimits
) throws -> any MoonlightDatagramChannel

typealias MoonlightMediaReceiveTimeProvider = @Sendable () -> UInt64

struct MoonlightMediaReceiveTiming: Equatable, Sendable {
    var connectTimeout: Duration
    var sendTimeout: Duration
    var pingInterval: Duration

    static let production = MoonlightMediaReceiveTiming(
        connectTimeout: .seconds(5),
        sendTimeout: .seconds(2),
        pingInterval: .milliseconds(500)
    )

    func validate() throws {
        guard connectTimeout > .zero,
              sendTimeout > .zero,
              pingInterval > .zero else {
            throw MoonlightMediaReceiveError.invalidLimits
        }
    }
}

struct MoonlightMediaReceiveSnapshot: Equatable, Sendable {
    var sessionID: UUID?
    var generation: UInt64
    var isActive: Bool
}

private struct MoonlightDatagramPing: Sendable {
    var customPayload: Data?

    init(customPayload: Data?) throws {
        guard customPayload == nil || customPayload?.count == 16 else {
            throw MoonlightMediaReceiveError.invalidConfiguration
        }
        self.customPayload = customPayload
    }

    func datagram(sequence: UInt32) -> Data {
        guard var customPayload else {
            return Data("PING".utf8)
        }
        var bigEndianSequence = sequence.bigEndian
        withUnsafeBytes(of: &bigEndianSequence) {
            customPayload.append(contentsOf: $0)
        }
        return customPayload
    }
}

private actor MoonlightDatagramReceiveRuntime<Event: Sendable> {
    typealias Transform = @Sendable (Data, UInt64) throws -> Event?

    private struct ActiveSession {
        var sessionID: UUID
        var token: UUID
        var channel: any MoonlightDatagramChannel
        var continuation: AsyncThrowingStream<Event, Error>.Continuation
        var task: Task<Void, Never>?
    }

    private let channelFactory: MoonlightDatagramChannelFactory
    private let timing: MoonlightMediaReceiveTiming
    private let eventBufferCapacity: Int
    private let timeProvider: MoonlightMediaReceiveTimeProvider
    private var generation: UInt64 = 0
    private var active: ActiveSession?

    init(
        channelFactory: @escaping MoonlightDatagramChannelFactory,
        timing: MoonlightMediaReceiveTiming,
        eventBufferCapacity: Int,
        timeProvider: @escaping MoonlightMediaReceiveTimeProvider
    ) {
        self.channelFactory = channelFactory
        self.timing = timing
        self.eventBufferCapacity = eventBufferCapacity
        self.timeProvider = timeProvider
    }

    func start(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        maximumDatagramBytes: Int,
        pingPayload: Data?,
        transform: @escaping Transform
    ) async -> AsyncThrowingStream<Event, Error> {
        if let active {
            await stop(active)
        }

        do {
            try endpoint.validate()
            guard endpoint.transport == .udp else {
                throw MoonlightMediaReceiveError.invalidEndpoint
            }
            try timing.validate()
            guard eventBufferCapacity > 0,
                  maximumDatagramBytes > 0,
                  maximumDatagramBytes <= NetworkChannelLimits
                    .moonlightDatagram.maximumReceiveBytes else {
                throw MoonlightMediaReceiveError.invalidLimits
            }
            let ping = try MoonlightDatagramPing(customPayload: pingPayload)
            let channel = try channelFactory(
                endpoint,
                .moonlightDatagram
            )
            var continuation: AsyncThrowingStream<Event, Error>.Continuation!
            let stream = AsyncThrowingStream<Event, Error>(
                bufferingPolicy: .bufferingOldest(eventBufferCapacity)
            ) {
                continuation = $0
            }
            let token = UUID()
            generation &+= 1
            active = ActiveSession(
                sessionID: sessionID,
                token: token,
                channel: channel,
                continuation: continuation,
                task: nil
            )
            let task = Task {
                await self.run(
                    token: token,
                    channel: channel,
                    continuation: continuation,
                    maximumDatagramBytes: maximumDatagramBytes,
                    ping: ping,
                    transform: transform
                )
            }
            active?.task = task
            continuation.onTermination = { @Sendable termination in
                guard case .cancelled = termination else { return }
                Task {
                    await self.cancel(sessionID: sessionID, token: token)
                }
            }
            return stream
        } catch {
            return Self.failedStream(error)
        }
    }

    func stop(sessionID: UUID) async {
        guard let active, active.sessionID == sessionID else { return }
        await stop(active)
    }

    func snapshot() -> MoonlightMediaReceiveSnapshot {
        MoonlightMediaReceiveSnapshot(
            sessionID: active?.sessionID,
            generation: generation,
            isActive: active != nil
        )
    }

    private func run(
        token: UUID,
        channel: any MoonlightDatagramChannel,
        continuation: AsyncThrowingStream<Event, Error>.Continuation,
        maximumDatagramBytes: Int,
        ping: MoonlightDatagramPing,
        transform: @escaping Transform
    ) async {
        do {
            try await channel.connect(timeout: timing.connectTimeout)
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await Self.pingLoop(
                        channel: channel,
                        ping: ping,
                        timing: self.timing
                    )
                }
                group.addTask {
                    try await Self.receiveLoop(
                        channel: channel,
                        continuation: continuation,
                        maximumDatagramBytes: maximumDatagramBytes,
                        timeProvider: self.timeProvider,
                        transform: transform
                    )
                }
                defer { group.cancelAll() }
                guard try await group.next() != nil else {
                    throw MoonlightMediaReceiveError.unexpectedTermination
                }
                throw MoonlightMediaReceiveError.unexpectedTermination
            }
        } catch {
            await complete(token: token, error: error)
        }
    }

    private func complete(token: UUID, error: Error) async {
        guard let active, active.token == token else { return }
        self.active = nil
        await active.channel.cancel()
        if error is CancellationError || Task.isCancelled {
            active.continuation.finish()
        } else {
            active.continuation.finish(throwing: error)
        }
    }

    private func cancel(sessionID: UUID, token: UUID) async {
        guard let active,
              active.sessionID == sessionID,
              active.token == token else { return }
        await stop(active)
    }

    private func stop(_ session: ActiveSession) async {
        guard active?.token == session.token else { return }
        active = nil
        session.task?.cancel()
        await session.channel.cancel()
        await session.task?.value
        session.continuation.finish()
    }

    private static func pingLoop(
        channel: any MoonlightDatagramChannel,
        ping: MoonlightDatagramPing,
        timing: MoonlightMediaReceiveTiming
    ) async throws {
        var sequence: UInt32 = 0
        while true {
            try Task.checkCancellation()
            try await channel.send(
                ping.datagram(sequence: sequence),
                timeout: timing.sendTimeout
            )
            sequence &+= 1
            try await Task.sleep(for: timing.pingInterval)
        }
    }

    private static func receiveLoop(
        channel: any MoonlightDatagramChannel,
        continuation: AsyncThrowingStream<Event, Error>.Continuation,
        maximumDatagramBytes: Int,
        timeProvider: @escaping MoonlightMediaReceiveTimeProvider,
        transform: @escaping Transform
    ) async throws {
        while true {
            try Task.checkCancellation()
            let chunk = try await channel.receiveWithoutDeadline(
                minimumLength: 1,
                maximumLength: maximumDatagramBytes
            )
            guard !chunk.data.isEmpty else {
                throw NetworkChannelError.closed
            }
            guard let event = try transform(
                chunk.data,
                timeProvider()
            ) else {
                continue
            }
            switch continuation.yield(event) {
            case .enqueued:
                break
            case .dropped:
                throw MoonlightMediaReceiveError.receiveBufferOverflow
            case .terminated:
                throw CancellationError()
            @unknown default:
                throw MoonlightMediaReceiveError.unexpectedTermination
            }
        }
    }

    private static func failedStream(
        _ error: Error
    ) -> AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: error)
        }
    }
}

actor MoonlightVideoReceiveProvider: VideoReceiveProvider {
    private let runtime: MoonlightDatagramReceiveRuntime<VideoReceiveEvent>

    init(
        channelFactory: @escaping MoonlightDatagramChannelFactory = {
            endpoint, limits in
            try NetworkByteChannel(endpoint: endpoint, limits: limits)
        },
        timing: MoonlightMediaReceiveTiming = .production,
        eventBufferCapacity: Int = 512,
        timeProvider: @escaping MoonlightMediaReceiveTimeProvider = {
            DispatchTime.now().uptimeNanoseconds
        }
    ) {
        runtime = MoonlightDatagramReceiveRuntime(
            channelFactory: channelFactory,
            timing: timing,
            eventBufferCapacity: eventBufferCapacity,
            timeProvider: timeProvider
        )
    }

    func receiveVideo(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedVideoStreamConfiguration
    ) async -> AsyncThrowingStream<VideoReceiveEvent, Error> {
        do {
            try configuration.validate()
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(
                    throwing: MoonlightMediaReceiveError.invalidConfiguration
                )
            }
        }
        let limits = MoonlightVideoPacketLimits.negotiated(
            maximumPacketSize: configuration.maximumPacketSize
        )
        return await runtime.start(
            sessionID: sessionID,
            endpoint: endpoint,
            maximumDatagramBytes: limits.maximumDatagramBytes,
            pingPayload: configuration.pingPayload
        ) { datagram, receiveTimeNanoseconds in
            let packet = try MoonlightVideoPacketParser.parse(
                datagram,
                receiveTimeNanoseconds: receiveTimeNanoseconds,
                limits: limits
            )
            guard !packet.isParity else { return nil }
            return .packet(ReceivedVideoPacket(
                sequenceNumber: packet.streamSequenceNumber,
                frameIndex: packet.frameIndex,
                rtpTimestamp: packet.rtpTimestamp,
                receiveTimeNanoseconds: packet.receiveTimeNanoseconds,
                isFirstPacket: packet.isTrueFrameStart,
                isLastPacket: packet.isTrueFrameEnd,
                payload: packet.payload
            ))
        }
    }

    func stopVideo(sessionID: UUID) async {
        await runtime.stop(sessionID: sessionID)
    }

    func snapshot() async -> MoonlightMediaReceiveSnapshot {
        await runtime.snapshot()
    }
}

actor MoonlightAudioReceiveProvider: AudioReceiveProvider {
    private let runtime: MoonlightDatagramReceiveRuntime<AudioReceiveEvent>

    init(
        channelFactory: @escaping MoonlightDatagramChannelFactory = {
            endpoint, limits in
            try NetworkByteChannel(endpoint: endpoint, limits: limits)
        },
        timing: MoonlightMediaReceiveTiming = .production,
        eventBufferCapacity: Int = 512,
        timeProvider: @escaping MoonlightMediaReceiveTimeProvider = {
            DispatchTime.now().uptimeNanoseconds
        }
    ) {
        runtime = MoonlightDatagramReceiveRuntime(
            channelFactory: channelFactory,
            timing: timing,
            eventBufferCapacity: eventBufferCapacity,
            timeProvider: timeProvider
        )
    }

    func receiveAudio(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedAudioStreamConfiguration
    ) async -> AsyncThrowingStream<AudioReceiveEvent, Error> {
        do {
            try configuration.validate()
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(
                    throwing: MoonlightMediaReceiveError.invalidConfiguration
                )
            }
        }
        let maximumDatagramBytes = configuration.maximumPacketSize
            + MoonlightAudioRTPPacket.fixedHeaderBytes
        return await runtime.start(
            sessionID: sessionID,
            endpoint: endpoint,
            maximumDatagramBytes: maximumDatagramBytes,
            pingPayload: configuration.pingPayload
        ) { datagram, receiveTimeNanoseconds in
            let packet = try MoonlightAudioRTPPacketParser.parse(
                datagram,
                maximumPayloadSize: configuration.maximumPacketSize
            )
            guard !packet.isFEC else { return nil }
            return .packet(ReceivedAudioPacket(
                sequenceNumber: packet.sequenceNumber,
                timestamp: packet.timestamp,
                receiveTimeNanoseconds: receiveTimeNanoseconds,
                payload: packet.payload
            ))
        }
    }

    func stopAudio(sessionID: UUID) async {
        await runtime.stop(sessionID: sessionID)
    }

    func snapshot() async -> MoonlightMediaReceiveSnapshot {
        await runtime.snapshot()
    }
}
