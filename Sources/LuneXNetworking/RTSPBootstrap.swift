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

    private struct ActiveSession {
        var sessionID: UUID
        var token: UUID
        var teardown: SessionControlTeardownCoordinator
        var task: Task<Void, Never>?
    }

    private struct TerminalSession {
        var sessionID: UUID
        var token: UUID
        var teardown: SessionControlTeardownCoordinator
        var task: Task<Void, Never>?
        var trigger: SessionControlTeardownTrigger
        var cancelRemoteSession: Bool
    }

    private let launchClient: any StreamLaunchClient
    private let connection: any RTSPConnectionExecuting
    private let controlChannel: any MoonlightControlChannelManaging
    private let reconnectPolicy: SessionReconnectPolicy
    private let reconnectSleeper: any SessionReconnectSleeping
    private let keyMaterialGenerator: any RemoteInputKeyMaterialGenerating
    private let reconnectClassifier: SessionReconnectFailureClassifier
    private let videoCodecSelectionPolicy: VideoCodecSelectionPolicy
    private var activeSession: ActiveSession?
    private var lastSession: TerminalSession?
    private var negotiatedVideoSelection: (
        sessionID: UUID,
        selection: VideoCodecSelection
    )?
    private var negotiatedVideoColorMetadata: (
        sessionID: UUID,
        metadata: VideoColorMetadata
    )?

    init(
        launchClient: any StreamLaunchClient = HTTPStreamLaunchClient(),
        connection: any RTSPConnectionExecuting = NetworkRTSPConnection(),
        controlChannel: any MoonlightControlChannelManaging = MoonlightControlChannel(),
        reconnectPolicy: SessionReconnectPolicy = .standard,
        reconnectSleeper: any SessionReconnectSleeping = ContinuousSessionReconnectSleeper(),
        keyMaterialGenerator: any RemoteInputKeyMaterialGenerating = SecureRemoteInputKeyMaterialGenerator(),
        reconnectClassifier: SessionReconnectFailureClassifier = SessionReconnectFailureClassifier(),
        videoCodecSelectionPolicy: VideoCodecSelectionPolicy = VideoCodecSelectionPolicy()
    ) {
        self.launchClient = launchClient
        self.connection = connection
        self.controlChannel = controlChannel
        self.reconnectPolicy = reconnectPolicy
        self.reconnectSleeper = reconnectSleeper
        self.keyMaterialGenerator = keyMaterialGenerator
        self.reconnectClassifier = reconnectClassifier
        self.videoCodecSelectionPolicy = videoCodecSelectionPolicy
    }

    func start(
        sessionID: UUID,
        request: StreamLaunchRequest
    ) async -> AsyncThrowingStream<SessionControlEvent, Error> {
        if let previous = activeSession {
            await cancelSession(previous, trigger: .replacement)
        }

        let token = UUID()
        negotiatedVideoSelection = nil
        negotiatedVideoColorMetadata = nil
        let teardown = SessionControlTeardownCoordinator(
            launchClient: launchClient,
            connection: connection,
            controlChannel: controlChannel,
            request: request
        )
        var continuation: AsyncThrowingStream<SessionControlEvent, Error>.Continuation!
        let stream = AsyncThrowingStream<SessionControlEvent, Error> {
            continuation = $0
        }
        let task = Task {
            await self.bootstrap(
                request,
                token: token,
                teardown: teardown,
                continuation: continuation
            )
        }
        activeSession = ActiveSession(
            sessionID: sessionID,
            token: token,
            teardown: teardown,
            task: task
        )
        continuation.onTermination = { @Sendable termination in
            guard case .cancelled = termination else { return }
            Task {
                await self.cancelBootstrap(
                    sessionID: sessionID,
                    expectedToken: token
                )
            }
        }
        return stream
    }

    func requestIDR(sessionID: UUID) async throws {
        guard activeSession?.sessionID == sessionID else {
            throw ControlChannelError.invalidState
        }
        try await controlChannel.requestIDR()
    }

    func stop(sessionID: UUID) async {
        if let activeSession, activeSession.sessionID == sessionID {
            await cancelSession(
                activeSession,
                trigger: .localStop,
                cancelRemoteSession: true
            )
        } else if let lastSession, lastSession.sessionID == sessionID {
            _ = await lastSession.teardown.teardown(
                trigger: lastSession.trigger,
                cancelRemoteSession: lastSession.cancelRemoteSession
            )
        }
    }

    func teardownSnapshot(sessionID: UUID) async -> SessionControlTeardownSnapshot? {
        if let activeSession, activeSession.sessionID == sessionID {
            return await activeSession.teardown.snapshot()
        }
        if let lastSession, lastSession.sessionID == sessionID {
            return await lastSession.teardown.snapshot()
        }
        return nil
    }

    func videoCodecSelection(sessionID: UUID) -> VideoCodecSelection? {
        guard negotiatedVideoSelection?.sessionID == sessionID else { return nil }
        return negotiatedVideoSelection?.selection
    }

    func videoColorMetadata(sessionID: UUID) -> VideoColorMetadata? {
        guard negotiatedVideoColorMetadata?.sessionID == sessionID else { return nil }
        return negotiatedVideoColorMetadata?.metadata
    }

    private func bootstrap(
        _ request: StreamLaunchRequest,
        token: UUID,
        teardown: SessionControlTeardownCoordinator,
        continuation: AsyncThrowingStream<SessionControlEvent, Error>.Continuation
    ) async {
        do {
            try reconnectPolicy.validate()
            let parameters = try StreamNegotiator().makeParameters(from: request)
            let launch = try await launchClient.launch(request, parameters: parameters)
            try yield(.launchAccepted(launch), token: token, continuation: continuation)
            try await establishTransport(
                request: request,
                response: launch,
                token: token,
                continuation: continuation
            )

            var activeRequest = request
            var usedKeyMaterial: Set<RemoteInputKeyMaterial> = [request.remoteInputKey]

            while !Task.isCancelled {
                do {
                    let event = try await controlChannel.nextEvent()
                    try ensureCurrent(token: token)
                    switch event {
                    case .idle, .message:
                        continue
                    case let .hdrMode(hdrMode):
                        let metadata = try hdrMode.colorMetadata()
                        guard let activeSession, activeSession.token == token else {
                            throw CancellationError()
                        }
                        if metadata.isHDR,
                           negotiatedVideoSelection?.selection.codec == .h264 {
                            throw ControlChannelError.invalidHDRMetadataPayload
                        }
                        negotiatedVideoColorMetadata = (
                            sessionID: activeSession.sessionID,
                            metadata: metadata
                        )
                        try yield(
                            .videoColorMetadata(metadata),
                            token: token,
                            continuation: continuation
                        )
                    case let .terminated(reason):
                        try yield(
                            .terminated(reason: reason.description),
                            token: token,
                            continuation: continuation
                        )
                        let terminalSession = claimTerminalSession(
                            token: token,
                            trigger: .remoteTermination,
                            cancelRemoteSession: false
                        )
                        if let terminalSession {
                            _ = await executeTeardown(terminalSession)
                        }
                        continuation.finish()
                        return
                    }
                } catch {
                    try Task.checkCancellation()
                    try ensureCurrent(token: token)
                    try yield(.channelsReady([]), token: token, continuation: continuation)
                    guard reconnectClassifier.isRetryable(error) else { throw error }
                    activeRequest = try await recoverTransport(
                        request: activeRequest,
                        usedKeyMaterial: &usedKeyMaterial,
                        token: token,
                        continuation: continuation
                    )
                }
            }
            try Task.checkCancellation()
        } catch {
            let cancelled = error is CancellationError
                || Task.isCancelled
                || activeSession?.token != token
            let terminalSession = claimTerminalSession(
                token: token,
                trigger: .failure,
                cancelRemoteSession: true
            )
            if let terminalSession {
                _ = await executeTeardown(terminalSession)
            } else {
                _ = await teardown.teardown(
                    trigger: .failure,
                    cancelRemoteSession: true
                )
            }
            if cancelled {
                continuation.finish()
            } else {
                continuation.finish(throwing: error)
            }
        }
    }

    private func establishTransport(
        request: StreamLaunchRequest,
        response: StreamLaunchResponse,
        token: UUID,
        continuation: AsyncThrowingStream<SessionControlEvent, Error>.Continuation
    ) async throws {
        try ensureCurrent(token: token)
        negotiatedVideoSelection = nil
        negotiatedVideoColorMetadata = nil
        guard let sessionURL = response.sessionURL else {
            throw RTSPBootstrapError.invalidSessionURL
        }
        let endpoint = try RTSPSessionEndpoint.parse(sessionURL)
        try await connection.connect(
            endpoint: endpoint,
            encryptionKey: request.remoteInputKey.key
        )
        try ensureCurrent(token: token)
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
        let description = try SunshineSessionDescriptionParser.parse(describe)
        let hdrRequested = request.preferences.hdrEnabled && request.app.supportsHDR
        let videoSelection = try videoCodecSelectionPolicy.select(
            hostCodecs: description.availableVideoCodecs,
            bitDepth: hdrRequested ? 10 : 8,
            isHDR: hdrRequested
        )
        try ensureCurrent(token: token)
        guard let activeSession, activeSession.token == token else {
            throw CancellationError()
        }
        negotiatedVideoSelection = (
            sessionID: activeSession.sessionID,
            selection: videoSelection
        )
        let colorMetadata = videoSelection.isHDR
            ? VideoColorMetadata.hdr10VideoRange()
            : .rec709VideoRange(bitDepth: videoSelection.bitDepth)
        try colorMetadata.validate()
        negotiatedVideoColorMetadata = (
            sessionID: activeSession.sessionID,
            metadata: colorMetadata
        )
        try yield(.rtspReady, token: token, continuation: continuation)

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
        try yield(.channelsReady(.control), token: token, continuation: continuation)
    }

    private func recoverTransport(
        request: StreamLaunchRequest,
        usedKeyMaterial: inout Set<RemoteInputKeyMaterial>,
        token: UUID,
        continuation: AsyncThrowingStream<SessionControlEvent, Error>.Continuation
    ) async throws -> StreamLaunchRequest {
        for attempt in 1...reconnectPolicy.maximumAttempts {
            try ensureCurrent(token: token)
            try yield(
                .reconnecting(attempt: attempt, reason: "control_unavailable"),
                token: token,
                continuation: continuation
            )
            await controlChannel.stop()
            await connection.cancel()
            try await reconnectSleeper.sleep(for: reconnectPolicy.delay(forAttempt: attempt))
            try ensureCurrent(token: token)

            var resumedRequest = request
            resumedRequest.remoteInputKey = try freshKeyMaterial(excluding: &usedKeyMaterial)
            let parameters = try StreamNegotiator().makeParameters(from: resumedRequest)

            do {
                let response = try await launchClient.resume(
                    resumedRequest,
                    parameters: parameters
                )
                try await establishTransport(
                    request: resumedRequest,
                    response: response,
                    token: token,
                    continuation: continuation
                )
                return resumedRequest
            } catch {
                await controlChannel.stop()
                await connection.cancel()
                try Task.checkCancellation()
                try ensureCurrent(token: token)
                guard reconnectClassifier.isRetryable(error) else { throw error }
            }
        }

        throw StreamNegotiationFailure(
            code: .reconnectExhausted,
            subsystem: "reconnect",
            message: "Required session channels did not recover within the retry budget."
        )
    }

    private func freshKeyMaterial(
        excluding usedKeyMaterial: inout Set<RemoteInputKeyMaterial>
    ) throws -> RemoteInputKeyMaterial {
        for _ in 0..<4 {
            let candidate: RemoteInputKeyMaterial
            do {
                candidate = try keyMaterialGenerator.generate()
            } catch {
                throw StreamNegotiationFailure(
                    code: .reconnectKeyGenerationFailed,
                    subsystem: "reconnect",
                    message: "Failed to generate reconnect key material."
                )
            }
            guard candidate.key.count == 16,
                  candidate.keyID >= 0,
                  candidate.keyID <= Int(UInt32.max) else {
                throw StreamNegotiationFailure(
                    code: .reconnectKeyGenerationFailed,
                    subsystem: "reconnect",
                    message: "Failed to generate valid reconnect key material."
                )
            }
            if usedKeyMaterial.insert(candidate).inserted {
                return candidate
            }
        }
        throw StreamNegotiationFailure(
            code: .reconnectKeyGenerationFailed,
            subsystem: "reconnect",
            message: "Failed to generate unique reconnect key material."
        )
    }

    private func ensureCurrent(token: UUID) throws {
        guard !Task.isCancelled, activeSession?.token == token else {
            throw CancellationError()
        }
    }

    private func yield(
        _ event: SessionControlEvent,
        token: UUID,
        continuation: AsyncThrowingStream<SessionControlEvent, Error>.Continuation
    ) throws {
        try ensureCurrent(token: token)
        if case .terminated = continuation.yield(event) {
            throw CancellationError()
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
        guard let activeSession,
              activeSession.sessionID == sessionID,
              activeSession.token == expectedToken else { return }
        await cancelSession(activeSession, trigger: .streamCancellation)
    }

    private func cancelSession(
        _ session: ActiveSession,
        trigger: SessionControlTeardownTrigger,
        cancelRemoteSession: Bool = true
    ) async {
        guard let terminalSession = claimTerminalSession(
            token: session.token,
            trigger: trigger,
            cancelRemoteSession: cancelRemoteSession
        ) else {
            return
        }
        terminalSession.task?.cancel()
        _ = await executeTeardown(terminalSession)
        await terminalSession.task?.value
    }

    private func claimTerminalSession(
        token: UUID,
        trigger: SessionControlTeardownTrigger,
        cancelRemoteSession: Bool
    ) -> TerminalSession? {
        if let session = activeSession, session.token == token {
            activeSession = nil
            let terminalSession = TerminalSession(
                sessionID: session.sessionID,
                token: session.token,
                teardown: session.teardown,
                task: session.task,
                trigger: trigger,
                cancelRemoteSession: cancelRemoteSession
            )
            lastSession = terminalSession
            return terminalSession
        }
        if let lastSession, lastSession.token == token {
            return lastSession
        }
        return nil
    }

    private func executeTeardown(
        _ session: TerminalSession
    ) async -> SessionControlTeardownReport {
        await session.teardown.teardown(
            trigger: session.trigger,
            cancelRemoteSession: session.cancelRemoteSession
        )
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
