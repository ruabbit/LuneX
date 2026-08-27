import CommonCrypto
import Foundation

enum MoonlightMediaReceiveError: Error, Equatable, Sendable,
    CustomStringConvertible
{
    case invalidEndpoint
    case invalidConfiguration
    case invalidLimits
    case missingAudioReservation
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
        case .missingAudioReservation:
            "The primed audio datagram channel is unavailable."
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

enum MoonlightAudioPacketDecryptError: Error, Equatable, Sendable {
    case invalidKeyMaterial
    case invalidCiphertext
    case decryptionFailed
}

enum MoonlightAudioPacketDecryptor {
    /// Sunshine encrypts only the RTP payload with AES-128-CBC. The IV is the
    /// big-endian `rikeyid + sequence` value in the first four bytes followed
    /// by twelve zero bytes; PKCS#7 padding is applied by the sender.
    static func decrypt(
        _ packet: MoonlightAudioRTPPacket,
        key: Data,
        keyID: Int
    ) throws -> Data {
        guard key.count == kCCKeySizeAES128,
              UInt32(exactly: keyID) != nil else {
            throw MoonlightAudioPacketDecryptError.invalidKeyMaterial
        }
        let ciphertext = [UInt8](packet.payload)
        guard !ciphertext.isEmpty,
              ciphertext.count.isMultiple(of: kCCBlockSizeAES128) else {
            throw MoonlightAudioPacketDecryptError.invalidCiphertext
        }
        var iv = [UInt8](repeating: 0, count: kCCBlockSizeAES128)
        var ivValue = UInt32(exactly: keyID)! &+ UInt32(packet.sequenceNumber)
        ivValue = ivValue.bigEndian
        withUnsafeBytes(of: &ivValue) { bytes in
            iv.replaceSubrange(0..<MemoryLayout<UInt32>.size, with: bytes)
        }

        var plaintext = [UInt8](repeating: 0, count: ciphertext.count)
        let plaintextCapacity = plaintext.count
        var plaintextLength = 0
        let status = key.withUnsafeBytes { keyBytes in
            ciphertext.withUnsafeBytes { inputBytes in
                iv.withUnsafeBytes { ivBytes in
                    plaintext.withUnsafeMutableBytes { outputBytes in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(kCCOptionPKCS7Padding),
                            keyBytes.baseAddress,
                            kCCKeySizeAES128,
                            ivBytes.baseAddress,
                            inputBytes.baseAddress,
                            ciphertext.count,
                            outputBytes.baseAddress,
                            plaintextCapacity,
                            &plaintextLength
                        )
                    }
                }
            }
        }
        guard status == kCCSuccess,
              (1...ciphertext.count).contains(plaintextLength) else {
            throw MoonlightAudioPacketDecryptError.decryptionFailed
        }
        return Data(plaintext.prefix(plaintextLength))
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

struct MoonlightReservedDatagramChannel: Sendable {
    let channel: any MoonlightDatagramChannel
    let nextPingSequence: UInt32
}

actor MoonlightAudioDatagramReservationStore {
    private struct Reservation: Sendable {
        let token: UUID
        let endpoint: RuntimeNetworkEndpoint
        let pingPayload: Data?
        let ping: MoonlightDatagramPing
        let channel: any MoonlightDatagramChannel
        var nextPingSequence: UInt32
    }

    private let channelFactory: MoonlightDatagramChannelFactory
    private let timing: MoonlightMediaReceiveTiming
    private var reservations: [UUID: Reservation] = [:]

    init(
        channelFactory: @escaping MoonlightDatagramChannelFactory = {
            endpoint, limits in
            try NetworkByteChannel(endpoint: endpoint, limits: limits)
        },
        timing: MoonlightMediaReceiveTiming = .production
    ) {
        self.channelFactory = channelFactory
        self.timing = timing
    }

    func reserve(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        pingPayload: Data?
    ) async throws {
        try endpoint.validate()
        guard endpoint.transport == .udp else {
            throw MoonlightMediaReceiveError.invalidEndpoint
        }
        try timing.validate()
        let ping = try MoonlightDatagramPing(customPayload: pingPayload)

        if let previous = reservations.removeValue(forKey: sessionID) {
            await previous.channel.cancel()
        }

        let channel = try channelFactory(endpoint, .moonlightDatagram)
        let token = UUID()
        reservations[sessionID] = Reservation(
            token: token,
            endpoint: endpoint,
            pingPayload: pingPayload,
            ping: ping,
            channel: channel,
            nextPingSequence: 0
        )

        do {
            try await channel.connect(timeout: timing.connectTimeout)
            try ensureCurrent(sessionID: sessionID, token: token)
            try await sendPing(sessionID: sessionID, expectedToken: token)
        } catch {
            if reservations[sessionID]?.token == token {
                reservations.removeValue(forKey: sessionID)
            }
            await channel.cancel()
            throw error
        }
    }

    func sendPing(sessionID: UUID) async throws {
        guard let reservation = reservations[sessionID] else {
            throw MoonlightMediaReceiveError.missingAudioReservation
        }
        try await sendPing(
            sessionID: sessionID,
            expectedToken: reservation.token
        )
    }

    func claim(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        pingPayload: Data?
    ) async throws -> MoonlightReservedDatagramChannel {
        guard let reservation = reservations.removeValue(forKey: sessionID) else {
            throw MoonlightMediaReceiveError.missingAudioReservation
        }
        guard reservation.endpoint == endpoint,
              reservation.pingPayload == pingPayload else {
            await reservation.channel.cancel()
            throw MoonlightMediaReceiveError.invalidConfiguration
        }
        return MoonlightReservedDatagramChannel(
            channel: reservation.channel,
            nextPingSequence: reservation.nextPingSequence
        )
    }

    func cancel(sessionID: UUID) async {
        guard let reservation = reservations.removeValue(forKey: sessionID) else {
            return
        }
        await reservation.channel.cancel()
    }

    private func sendPing(
        sessionID: UUID,
        expectedToken: UUID
    ) async throws {
        guard let reservation = reservations[sessionID],
              reservation.token == expectedToken else {
            throw CancellationError()
        }
        try await reservation.channel.send(
            reservation.ping.datagram(sequence: reservation.nextPingSequence),
            timeout: timing.sendTimeout
        )
        try ensureCurrent(sessionID: sessionID, token: expectedToken)
        var current = reservations[sessionID]!
        current.nextPingSequence &+= 1
        reservations[sessionID] = current
    }

    private func ensureCurrent(sessionID: UUID, token: UUID) throws {
        guard !Task.isCancelled,
              reservations[sessionID]?.token == token else {
            throw CancellationError()
        }
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
        reservedChannel: MoonlightReservedDatagramChannel? = nil,
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
            let channel = try reservedChannel?.channel ?? channelFactory(
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
                    isConnected: reservedChannel != nil,
                    initialPingSequence: reservedChannel?.nextPingSequence ?? 0,
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
        isConnected: Bool,
        initialPingSequence: UInt32,
        transform: @escaping Transform
    ) async {
        do {
            if !isConnected {
                try await channel.connect(timeout: timing.connectTimeout)
            }
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask {
                    try await Self.pingLoop(
                        channel: channel,
                        ping: ping,
                        initialSequence: initialPingSequence,
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
        initialSequence: UInt32,
        timing: MoonlightMediaReceiveTiming
    ) async throws {
        var sequence = initialSequence
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
            let hasFEC = packet.parityShardCount > 0
            return .packet(ReceivedVideoPacket(
                sequenceNumber: packet.streamSequenceNumber,
                frameIndex: packet.frameIndex,
                rtpTimestamp: packet.rtpTimestamp,
                receiveTimeNanoseconds: packet.receiveTimeNanoseconds,
                isFirstPacket: packet.isTrueFrameStart,
                isLastPacket: packet.isTrueFrameEnd,
                payload: packet.payload,
                fecBlockIndex: hasFEC ? packet.fecBlockIndex : 0,
                lastFECBlockIndex: hasFEC ? packet.lastFECBlockIndex : 0,
                fecShardIndex: hasFEC ? packet.fecShardIndex : 0,
                dataShardCount: hasFEC ? packet.dataShardCount : 0,
                parityShardCount: hasFEC ? packet.parityShardCount : 0,
                fecPercentage: hasFEC ? packet.fecPercentage : 0
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
    private let reservationStore: MoonlightAudioDatagramReservationStore?

    init(
        channelFactory: @escaping MoonlightDatagramChannelFactory = {
            endpoint, limits in
            try NetworkByteChannel(endpoint: endpoint, limits: limits)
        },
        reservationStore: MoonlightAudioDatagramReservationStore? = nil,
        timing: MoonlightMediaReceiveTiming = .production,
        eventBufferCapacity: Int = 512,
        timeProvider: @escaping MoonlightMediaReceiveTimeProvider = {
            DispatchTime.now().uptimeNanoseconds
        }
    ) {
        self.reservationStore = reservationStore
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
        let reservedChannel: MoonlightReservedDatagramChannel?
        do {
            reservedChannel = try await reservationStore?.claim(
                sessionID: sessionID,
                endpoint: endpoint,
                pingPayload: configuration.pingPayload
            )
        } catch {
            return AsyncThrowingStream { continuation in
                continuation.finish(throwing: error)
            }
        }
        return await runtime.start(
            sessionID: sessionID,
            endpoint: endpoint,
            maximumDatagramBytes: maximumDatagramBytes,
            pingPayload: configuration.pingPayload,
            reservedChannel: reservedChannel
        ) { datagram, receiveTimeNanoseconds in
            let packet = try MoonlightAudioRTPPacketParser.parse(
                datagram,
                maximumPayloadSize: configuration.maximumPacketSize
            )
            guard !packet.isFEC else { return nil }
            let payload: Data
            if configuration.isEncrypted {
                guard let key = configuration.encryptionKey,
                      let keyID = configuration.encryptionKeyID else {
                    throw MoonlightAudioPacketDecryptError.invalidKeyMaterial
                }
                payload = try MoonlightAudioPacketDecryptor.decrypt(
                    packet,
                    key: key,
                    keyID: keyID
                )
            } else {
                payload = packet.payload
            }
            return .packet(ReceivedAudioPacket(
                sequenceNumber: packet.sequenceNumber,
                timestamp: packet.timestamp,
                receiveTimeNanoseconds: receiveTimeNanoseconds,
                payload: payload
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
