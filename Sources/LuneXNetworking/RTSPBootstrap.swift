import CryptoKit
import Foundation

enum RTSPBootstrapError: Error, Equatable, Sendable {
    case invalidSessionURL
    case unsupportedSessionScheme
    case invalidEncryptionKey
    case invalidEncryptedFrame
    case sequenceExhausted
    case unexpectedResponse
    case cSeqMismatch
    case connectionClosed
}

struct RTSPSessionEndpoint: Equatable, Sendable {
    var target: String
    var networkEndpoint: RuntimeNetworkEndpoint
    var encrypted: Bool

    static func parse(_ value: String) throws -> RTSPSessionEndpoint {
        guard let components = URLComponents(string: value),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty else {
            throw RTSPBootstrapError.invalidSessionURL
        }
        guard scheme == "rtsp" || scheme == "rtspenc" else {
            throw RTSPBootstrapError.unsupportedSessionScheme
        }
        let port = components.port ?? 48_010
        guard let networkPort = UInt16(exactly: port), networkPort > 0 else {
            throw RTSPBootstrapError.invalidSessionURL
        }
        return RTSPSessionEndpoint(
            target: value,
            networkEndpoint: RuntimeNetworkEndpoint(
                host: host,
                port: networkPort,
                transport: .tcp
            ),
            encrypted: scheme == "rtspenc"
        )
    }
}

enum EncryptedRTSPOrigin: Sendable {
    case client
    case host
}

enum EncryptedRTSPFrameCodec {
    private static let headerSize = 24
    private static let encryptedBit: UInt32 = 0x8000_0000

    static func seal(
        _ plaintext: Data,
        sequence: UInt32,
        key: Data,
        origin: EncryptedRTSPOrigin
    ) throws -> Data {
        guard key.count == 16 else { throw RTSPBootstrapError.invalidEncryptionKey }
        guard plaintext.count <= Int(UInt32.max & ~encryptedBit) else {
            throw RTSPBootstrapError.invalidEncryptedFrame
        }
        let nonce = try AES.GCM.Nonce(data: nonce(sequence: sequence, origin: origin))
        let box = try AES.GCM.seal(
            plaintext,
            using: SymmetricKey(data: key),
            nonce: nonce
        )
        var frame = Data()
        appendBigEndian(encryptedBit | UInt32(plaintext.count), to: &frame)
        appendBigEndian(sequence, to: &frame)
        frame.append(box.tag)
        frame.append(box.ciphertext)
        return frame
    }

    static func open(
        _ frame: Data,
        key: Data,
        origin: EncryptedRTSPOrigin
    ) throws -> (plaintext: Data, sequence: UInt32) {
        guard key.count == 16, frame.count >= headerSize else {
            throw RTSPBootstrapError.invalidEncryptedFrame
        }
        let bytes = [UInt8](frame)
        let typeAndLength = readBigEndian(bytes[0..<4])
        guard typeAndLength & encryptedBit != 0 else {
            throw RTSPBootstrapError.invalidEncryptedFrame
        }
        let length = Int(typeAndLength & ~encryptedBit)
        guard frame.count == headerSize + length else {
            throw RTSPBootstrapError.invalidEncryptedFrame
        }
        let sequence = readBigEndian(bytes[4..<8])
        let nonce = try AES.GCM.Nonce(data: nonce(sequence: sequence, origin: origin))
        let box = try AES.GCM.SealedBox(
            nonce: nonce,
            ciphertext: frame.subdata(in: headerSize..<frame.count),
            tag: frame.subdata(in: 8..<headerSize)
        )
        let plaintext = try AES.GCM.open(box, using: SymmetricKey(data: key))
        return (plaintext, sequence)
    }

    static func framedLength(in data: Data) throws -> Int? {
        guard data.count >= 4 else { return nil }
        let typeAndLength = readBigEndian([UInt8](data.prefix(4))[0..<4])
        guard typeAndLength & encryptedBit != 0 else {
            throw RTSPBootstrapError.invalidEncryptedFrame
        }
        let total = headerSize + Int(typeAndLength & ~encryptedBit)
        guard total <= RTSPParserLimits.moonlight.maximumMessageBytes + headerSize else {
            throw RTSPBootstrapError.invalidEncryptedFrame
        }
        return data.count >= total ? total : nil
    }

    private static func nonce(sequence: UInt32, origin: EncryptedRTSPOrigin) -> Data {
        var bytes = [UInt8](repeating: 0, count: 12)
        bytes[0] = UInt8(truncatingIfNeeded: sequence)
        bytes[1] = UInt8(truncatingIfNeeded: sequence >> 8)
        bytes[2] = UInt8(truncatingIfNeeded: sequence >> 16)
        bytes[3] = UInt8(truncatingIfNeeded: sequence >> 24)
        bytes[10] = origin == .client ? 67 : 72
        bytes[11] = 82
        return Data(bytes)
    }

    private static func appendBigEndian(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value >> 24))
        data.append(UInt8(truncatingIfNeeded: value >> 16))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
        data.append(UInt8(truncatingIfNeeded: value))
    }

    private static func readBigEndian(_ bytes: ArraySlice<UInt8>) -> UInt32 {
        bytes.reduce(0) { ($0 << 8) | UInt32($1) }
    }
}

protocol RTSPConnectionExecuting: Sendable {
    func connect(endpoint: RTSPSessionEndpoint, encryptionKey: Data) async throws
    func transact(_ request: RTSPRequest) async throws -> RTSPResponse
    func cancel() async
}

actor NetworkRTSPConnection: RTSPConnectionExecuting {
    private var channel: NetworkByteChannel?
    private var endpoint: RTSPSessionEndpoint?
    private var encryptionKey = Data()
    private var sendSequence: UInt32 = 0
    private var receiveBuffer = Data()

    func connect(endpoint: RTSPSessionEndpoint, encryptionKey: Data) async throws {
        guard channel == nil else { throw NetworkChannelError.invalidState }
        if endpoint.encrypted, encryptionKey.count != 16 {
            throw RTSPBootstrapError.invalidEncryptionKey
        }
        let channel = try NetworkByteChannel(
            endpoint: endpoint.networkEndpoint,
            limits: .moonlightControl
        )
        try await channel.connect(timeout: .seconds(10))
        self.channel = channel
        self.endpoint = endpoint
        self.encryptionKey = encryptionKey
        sendSequence = 0
        receiveBuffer.removeAll(keepingCapacity: true)
    }

    func transact(_ request: RTSPRequest) async throws -> RTSPResponse {
        guard let channel, let endpoint else { throw NetworkChannelError.invalidState }
        let plaintext = try RTSPMessageCodec.serialize(.request(request))
        let outbound: Data
        if endpoint.encrypted {
            guard sendSequence < UInt32.max else { throw RTSPBootstrapError.sequenceExhausted }
            sendSequence += 1
            outbound = try EncryptedRTSPFrameCodec.seal(
                plaintext,
                sequence: sendSequence,
                key: encryptionKey,
                origin: .client
            )
        } else {
            outbound = plaintext
        }
        try await channel.send(outbound, timeout: .seconds(10))

        while true {
            if let response = try decodeResponse(encrypted: endpoint.encrypted) {
                return response
            }
            let chunk = try await channel.receive(
                maximumLength: 65_536,
                timeout: .seconds(15)
            )
            receiveBuffer.append(chunk.data)
            guard receiveBuffer.count <= RTSPParserLimits.moonlight.maximumMessageBytes + 24 else {
                throw RTSPMessageError.messageTooLarge
            }
            if chunk.isComplete && chunk.data.isEmpty {
                throw RTSPBootstrapError.connectionClosed
            }
        }
    }

    func cancel() async {
        await channel?.cancel()
        channel = nil
        endpoint = nil
        encryptionKey.removeAll(keepingCapacity: false)
        sendSequence = 0
        receiveBuffer.removeAll(keepingCapacity: false)
    }

    private func decodeResponse(encrypted: Bool) throws -> RTSPResponse? {
        let message: RTSPMessage
        let consumed: Int
        if encrypted {
            guard let length = try EncryptedRTSPFrameCodec.framedLength(in: receiveBuffer) else {
                return nil
            }
            let opened = try EncryptedRTSPFrameCodec.open(
                Data(receiveBuffer.prefix(length)),
                key: encryptionKey,
                origin: .host
            )
            message = try RTSPMessageCodec.decodeExact(opened.plaintext)
            consumed = length
        } else {
            guard let decoded = try RTSPMessageCodec.decodePrefix(receiveBuffer) else { return nil }
            message = decoded.message
            consumed = decoded.consumedBytes
        }
        receiveBuffer.removeFirst(consumed)
        guard case let .response(response) = message else {
            throw RTSPBootstrapError.unexpectedResponse
        }
        return response
    }
}

actor MoonlightSessionControlProvider: SessionControlProvider {
    private static let clientVersion = "14"

    private let launchClient: any StreamLaunchClient
    private let connection: any RTSPConnectionExecuting
    private let controlChannel: any MoonlightControlChannelManaging
    private var task: Task<Void, Never>?
    private var taskToken: UUID?
    private var activeSessionID: UUID?

    init(
        launchClient: any StreamLaunchClient = HTTPStreamLaunchClient(),
        connection: any RTSPConnectionExecuting = NetworkRTSPConnection(),
        controlChannel: any MoonlightControlChannelManaging = MoonlightControlChannel()
    ) {
        self.launchClient = launchClient
        self.connection = connection
        self.controlChannel = controlChannel
    }

    func start(
        sessionID: UUID,
        request: StreamLaunchRequest
    ) async -> AsyncThrowingStream<SessionControlEvent, Error> {
        if let previous = task {
            task = nil
            taskToken = nil
            activeSessionID = nil
            previous.cancel()
            await previous.value
            await controlChannel.stop()
            await connection.cancel()
        } else if activeSessionID != nil {
            activeSessionID = nil
            await controlChannel.stop()
            await connection.cancel()
        }
        let token = UUID()
        activeSessionID = sessionID
        taskToken = token
        return AsyncThrowingStream { continuation in
            task = Task {
                await self.bootstrap(
                    request,
                    token: token,
                    continuation: continuation
                )
            }
            continuation.onTermination = { @Sendable termination in
                guard case .cancelled = termination else { return }
                Task {
                    await self.cancelBootstrap(
                        sessionID: sessionID,
                        expectedToken: token
                    )
                }
            }
        }
    }

    func requestIDR(sessionID: UUID) async throws {
        guard activeSessionID == sessionID else {
            throw ControlChannelError.invalidState
        }
        try await controlChannel.requestIDR()
    }

    func stop(sessionID: UUID) async {
        guard activeSessionID == sessionID else { return }
        let activeTask = task
        task = nil
        taskToken = nil
        activeSessionID = nil
        activeTask?.cancel()
        await activeTask?.value
        await controlChannel.stop()
        await connection.cancel()
    }

    private func bootstrap(
        _ request: StreamLaunchRequest,
        token: UUID,
        continuation: AsyncThrowingStream<SessionControlEvent, Error>.Continuation
    ) async {
        defer {
            if taskToken == token {
                task = nil
                taskToken = nil
            }
        }
        do {
            let parameters = try StreamNegotiator().makeParameters(from: request)
            let launch = try await launchClient.launch(request, parameters: parameters)
            continuation.yield(.launchAccepted(launch))
            guard let sessionURL = launch.sessionURL else {
                throw RTSPBootstrapError.invalidSessionURL
            }
            let endpoint = try RTSPSessionEndpoint.parse(sessionURL)
            try await connection.connect(
                endpoint: endpoint,
                encryptionKey: request.remoteInputKey.key
            )
            _ = try await transact(
                RTSPRequest(
                    method: "OPTIONS",
                    target: endpoint.target,
                    headers: requestHeaders(cSeq: "1", endpoint: endpoint)
                ),
                expectedCSeq: "1"
            )
            let describe = try await transact(
                RTSPRequest(
                    method: "DESCRIBE",
                    target: endpoint.target,
                    headers: requestHeaders(cSeq: "2", endpoint: endpoint) + [
                        RTSPHeader(name: "Accept", value: "application/sdp"),
                        RTSPHeader(name: "If-Modified-Since", value: "Thu, 01 Jan 1970 00:00:00 GMT")
                    ]
                ),
                expectedCSeq: "2"
            )
            _ = try SunshineSessionDescriptionParser.parse(describe)
            continuation.yield(.rtspReady)

            let audioSetup = try await setupStream(
                .audio,
                cSeq: "3",
                endpoint: endpoint,
                sessionToken: nil
            )
            let videoSetup = try await setupStream(
                .video,
                cSeq: "4",
                endpoint: endpoint,
                sessionToken: audioSetup.sessionToken
            )
            guard videoSetup.sessionToken == audioSetup.sessionToken else {
                throw SunshineRTSPNegotiationError.conflictingSession
            }
            let controlSetup = try await setupStream(
                .control,
                cSeq: "5",
                endpoint: endpoint,
                sessionToken: audioSetup.sessionToken
            )
            guard controlSetup.sessionToken == audioSetup.sessionToken else {
                throw SunshineRTSPNegotiationError.conflictingSession
            }
            guard let connectData = controlSetup.controlConnectData else {
                throw SunshineRTSPNegotiationError.missingControlConnectData
            }
            try await controlChannel.connect(
                endpoint: controlSetup.endpoint(host: endpoint.networkEndpoint.host),
                connectData: connectData,
                encryptionKey: request.remoteInputKey.key
            )
            continuation.yield(.channelsReady(.control))

            while !Task.isCancelled {
                switch try await controlChannel.nextEvent() {
                case .idle, .message:
                    continue
                case let .terminated(reason):
                    await controlChannel.stop()
                    await connection.cancel()
                    if taskToken == token {
                        activeSessionID = nil
                    }
                    continuation.yield(.terminated(reason: reason.description))
                    continuation.finish()
                    return
                }
            }
            try Task.checkCancellation()
        } catch {
            await controlChannel.stop()
            await connection.cancel()
            if taskToken == token {
                activeSessionID = nil
            }
            continuation.finish(throwing: error)
        }
    }

    private func requestHeaders(
        cSeq: String,
        endpoint: RTSPSessionEndpoint
    ) -> [RTSPHeader] {
        [
            RTSPHeader(name: "CSeq", value: cSeq),
            RTSPHeader(name: "X-GS-ClientVersion", value: Self.clientVersion),
            RTSPHeader(name: "Host", value: endpoint.networkEndpoint.host)
        ]
    }

    private func cancelBootstrap(
        sessionID: UUID,
        expectedToken: UUID
    ) async {
        guard activeSessionID == sessionID,
              taskToken == expectedToken else { return }
        let activeTask = task
        task = nil
        taskToken = nil
        activeSessionID = nil
        activeTask?.cancel()
        await activeTask?.value
        await controlChannel.stop()
        await connection.cancel()
    }

    private func setupStream(
        _ kind: RTSPSetupStreamKind,
        cSeq: String,
        endpoint: RTSPSessionEndpoint,
        sessionToken: String?
    ) async throws -> RTSPSetupStreamParameters {
        let target: String
        switch kind {
        case .audio:
            target = "streamid=audio/0/0"
        case .video:
            target = "streamid=video/0/0"
        case .control:
            target = "streamid=control/13/0"
        }
        var headers = requestHeaders(cSeq: cSeq, endpoint: endpoint) + [
            RTSPHeader(name: "Transport", value: "unicast;X-GS-ClientPort=50000-50001"),
            RTSPHeader(name: "If-Modified-Since", value: "Thu, 01 Jan 1970 00:00:00 GMT")
        ]
        if let sessionToken {
            headers.append(RTSPHeader(name: "Session", value: sessionToken))
        }
        let response = try await transact(
            RTSPRequest(method: "SETUP", target: target, headers: headers),
            expectedCSeq: cSeq
        )
        return try RTSPSetupResponseParser.parse(response, kind: kind)
    }

    private func transact(
        _ request: RTSPRequest,
        expectedCSeq: String
    ) async throws -> RTSPResponse {
        let response = try await connection.transact(request)
        guard response.statusCode == 200 else {
            throw RTSPBootstrapError.unexpectedResponse
        }
        let cseq = response.headerValues(named: "CSeq")
        guard cseq == [expectedCSeq] else { throw RTSPBootstrapError.cSeqMismatch }
        return response
    }
}
