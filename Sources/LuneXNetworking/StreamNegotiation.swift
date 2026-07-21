import Foundation

struct RemoteInputKeyMaterial: Codable, Equatable, Hashable, Sendable {
    var keyID: Int
    var key: Data

    var hexKey: String {
        key.map { String(format: "%02X", $0) }.joined()
    }
}

enum AudioPlaybackMode: String, Codable, Equatable, Sendable {
    case clientOnly
    case hostAndClient
}

struct StreamLaunchRequest: Codable, Equatable, Sendable {
    var host: MoonlightHost
    var app: RemoteApp
    var preferences: StreamPreferences
    var clientUniqueID: String
    var remoteInputKey: RemoteInputKeyMaterial
    var audioPlaybackMode: AudioPlaybackMode
    var controllerBitmap: Int
    var optimizeGameSettings: Bool
}

struct StreamNegotiationParameters: Codable, Equatable, Sendable {
    var hostID: UUID
    var appID: String
    var appName: String
    var mode: String
    var bitrateKbps: Int
    var frameRate: Int
    var hdrRequested: Bool
    var remoteInputKeyID: Int
    var remoteInputKeyHex: String
    var audioPlaybackMode: AudioPlaybackMode
    var controllerBitmap: Int
}

enum StreamNegotiationStage: String, Codable, Equatable, Sendable {
    case idle
    case resolvingHost
    case validatingPairing
    case preparingParameters
    case launching
    case readyForTransport
    case streaming
    case reconnecting
    case stopping
    case disconnected
    case failed
}

enum StreamNegotiationFailureCode: String, Codable, Equatable, Sendable {
    case hostNotPaired
    case missingHostAddress
    case invalidResolution
    case invalidBitrate
    case launchRejected
    case resumeRejected
    case cancelRejected
    case reconnectExhausted
    case reconnectKeyGenerationFailed
    case transportUnavailable
    case invalidTransition
}

struct StreamNegotiationFailure: Error, Codable, Equatable, Sendable, CustomStringConvertible {
    var code: StreamNegotiationFailureCode
    var subsystem: String
    var message: String

    var description: String {
        "\(subsystem): \(code.rawValue): \(message)"
    }
}

struct StreamLaunchResponse: Codable, Equatable, Sendable {
    var sessionURL: String?
    var gameSessionID: String?
    var rawValues: [String: String]
}

struct StreamSessionSnapshot: Codable, Equatable, Sendable {
    var sessionID: UUID
    var hostID: UUID?
    var appID: String?
    var stage: StreamNegotiationStage
    var parameters: StreamNegotiationParameters?
    var launchResponse: StreamLaunchResponse?
    var videoColorMetadata: VideoColorMetadata?
    var negotiatedConfiguration: NegotiatedSessionConfiguration?
    var channelHealth: SessionChannelHealthSnapshot
    var reconnectAttempt: Int?
    var terminationReason: String?
    var failure: StreamNegotiationFailure?
    var updatedAt: Date
}

protocol StreamLaunchClient: Sendable {
    func launch(_ request: StreamLaunchRequest, parameters: StreamNegotiationParameters) async throws -> StreamLaunchResponse
    func resume(_ request: StreamLaunchRequest, parameters: StreamNegotiationParameters) async throws -> StreamLaunchResponse
    func stop(host: MoonlightHost, clientUniqueID: String) async throws
}

struct HTTPStreamLaunchClient: StreamLaunchClient {
    var requestExecutor: any PinnedHTTPSRequestExecuting

    init(requestExecutor: any PinnedHTTPSRequestExecuting = PinnedHTTPSRequestExecutor()) {
        self.requestExecutor = requestExecutor
    }

    func launch(_ request: StreamLaunchRequest, parameters: StreamNegotiationParameters) async throws -> StreamLaunchResponse {
        try await launchOrResume(
            request,
            parameters: parameters,
            path: "/launch",
            operation: .launch
        )
    }

    func resume(_ request: StreamLaunchRequest, parameters: StreamNegotiationParameters) async throws -> StreamLaunchResponse {
        try await launchOrResume(
            request,
            parameters: parameters,
            path: "/resume",
            operation: .resume
        )
    }

    private func launchOrResume(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters,
        path: String,
        operation: StreamLaunchResponseParser.Operation
    ) async throws -> StreamLaunchResponse {
        let endpoint = try HostEndpointParser.parse(request.host.address)
        var queryItems = [
            URLQueryItem(name: "uniqueid", value: request.clientUniqueID),
            URLQueryItem(name: "appid", value: parameters.appID),
            URLQueryItem(name: "mode", value: parameters.mode),
            URLQueryItem(name: "additionalStates", value: "1"),
            URLQueryItem(name: "sops", value: request.optimizeGameSettings ? "1" : "0"),
            URLQueryItem(name: "rikey", value: parameters.remoteInputKeyHex),
            URLQueryItem(name: "rikeyid", value: String(parameters.remoteInputKeyID)),
            URLQueryItem(name: "localAudioPlayMode", value: parameters.audioPlaybackMode == .hostAndClient ? "1" : "0"),
            URLQueryItem(name: "remoteControllersBitmap", value: String(parameters.controllerBitmap)),
            URLQueryItem(name: "gcmap", value: String(parameters.controllerBitmap)),
            URLQueryItem(name: "gcpersist", value: "1")
        ]

        if parameters.hdrRequested {
            queryItems.append(contentsOf: [
                URLQueryItem(name: "hdrMode", value: "1"),
                URLQueryItem(name: "clientHdrCapVersion", value: "0"),
                URLQueryItem(name: "clientHdrCapSupportedFlagsInUint32", value: "0"),
                URLQueryItem(name: "clientHdrCapMetaDataId", value: "NV_STATIC_METADATA_TYPE_1"),
                URLQueryItem(name: "clientHdrCapDisplayData", value: "0x0x0x0x0x0x0x0x0x0x0")
            ])
        }

        guard let url = MoonlightHTTPURLBuilder.secureURL(endpoint: endpoint, path: path, queryItems: queryItems) else {
            throw StreamNegotiationFailure(
                code: operation == .launch ? .launchRejected : .resumeRejected,
                subsystem: operation.rawValue,
                message: "Failed to construct session request URL."
            )
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 30
        let (data, _) = try await requestExecutor.data(for: urlRequest, pinnedIdentity: request.host.pinnedIdentity)
        return try StreamLaunchResponseParser.parse(data, operation: operation)
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {
        let endpoint = try HostEndpointParser.parse(host.address)
        guard let url = MoonlightHTTPURLBuilder.secureURL(
            endpoint: endpoint,
            path: "/cancel",
            queryItems: [URLQueryItem(name: "uniqueid", value: clientUniqueID)]
        ) else {
            throw StreamNegotiationFailure(code: .launchRejected, subsystem: "stop", message: "Failed to construct cancel URL.")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.timeoutInterval = 30
        let (data, _) = try await requestExecutor.data(for: urlRequest, pinnedIdentity: host.pinnedIdentity)
        try StreamLaunchResponseParser.parseCancel(data)
    }
}

enum StreamLaunchResponseParser {
    enum Operation: String, Equatable, Sendable {
        case launch
        case resume
    }

    static func parse(
        _ data: Data,
        operation: Operation = .launch
    ) throws -> StreamLaunchResponse {
        let delegate = SimpleMoonlightXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse() else {
            throw StreamNegotiationFailure(
                code: operation == .launch ? .launchRejected : .resumeRejected,
                subsystem: operation.rawValue,
                message: "Invalid session response."
            )
        }

        if let statusCode = delegate.statusCode, statusCode != 200 {
            throw StreamNegotiationFailure(
                code: operation == .launch ? .launchRejected : .resumeRejected,
                subsystem: operation.rawValue,
                message: delegate.statusMessage ?? "Session request was rejected."
            )
        }

        if operation == .resume, delegate.values["resume"] != "1" {
            throw StreamNegotiationFailure(
                code: .resumeRejected,
                subsystem: operation.rawValue,
                message: "Host did not accept session resume."
            )
        }

        return StreamLaunchResponse(
            sessionURL: delegate.values["sessionurl0"]
                ?? delegate.values["sessionurl"]
                ?? delegate.values["rtspurl"],
            gameSessionID: delegate.values["gamesession"],
            rawValues: delegate.values
        )
    }

    static func parseCancel(_ data: Data) throws {
        let delegate = SimpleMoonlightXMLDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        guard parser.parse(),
              delegate.statusCode == 200,
              delegate.values["cancel"] == "1" else {
            throw StreamNegotiationFailure(
                code: .cancelRejected,
                subsystem: "stop",
                message: "Host did not confirm session cancellation."
            )
        }
    }
}

private final class SimpleMoonlightXMLDelegate: NSObject, XMLParserDelegate {
    private var currentText = ""
    private(set) var values: [String: String] = [:]
    private(set) var statusCode: Int?
    private(set) var statusMessage: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentText = ""
        if elementName.lowercased() == "root" {
            if let rawStatusCode = attributeDict["status_code"], let statusCode = Int(rawStatusCode) {
                self.statusCode = statusCode
            }
            statusMessage = attributeDict["status_message"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            values[elementName.lowercased()] = value
        }
        currentText = ""
    }
}

struct StreamNegotiator: Sendable {
    func makeParameters(from request: StreamLaunchRequest) throws -> StreamNegotiationParameters {
        guard !request.host.address.isEmpty else {
            throw StreamNegotiationFailure(code: .missingHostAddress, subsystem: "host", message: "Host has no usable address.")
        }
        guard request.host.pairingState == .paired else {
            throw StreamNegotiationFailure(code: .hostNotPaired, subsystem: "pairing", message: "Host must be paired before streaming.")
        }
        guard request.preferences.width > 0, request.preferences.height > 0, request.preferences.frameRate > 0 else {
            throw StreamNegotiationFailure(code: .invalidResolution, subsystem: "settings", message: "Stream resolution and frame rate must be positive.")
        }
        guard request.preferences.bitrateKbps > 0 else {
            throw StreamNegotiationFailure(code: .invalidBitrate, subsystem: "settings", message: "Stream bitrate must be positive.")
        }

        return StreamNegotiationParameters(
            hostID: request.host.id,
            appID: request.app.id,
            appName: request.app.name,
            mode: "\(request.preferences.width)x\(request.preferences.height)x\(request.preferences.frameRate)",
            bitrateKbps: request.preferences.bitrateKbps,
            frameRate: request.preferences.frameRate,
            hdrRequested: request.preferences.hdrEnabled && request.app.supportsHDR,
            remoteInputKeyID: request.remoteInputKey.keyID,
            remoteInputKeyHex: request.remoteInputKey.hexKey,
            audioPlaybackMode: request.audioPlaybackMode,
            controllerBitmap: request.controllerBitmap
        )
    }
}

private enum SessionControlProgress: Int, Sendable {
    case idle
    case launchAccepted
    case rtspReady
    case negotiated
    case terminal
}

actor StreamSessionCoordinator {
    private let negotiator: StreamNegotiator
    private let launchClient: StreamLaunchClient
    private var healthAggregator: SessionChannelHealthAggregator
    private var controlProgress: SessionControlProgress = .idle
    private var lastReconnectAttempt = 0
    private(set) var snapshot: StreamSessionSnapshot

    init(
        negotiator: StreamNegotiator = StreamNegotiator(),
        launchClient: StreamLaunchClient,
        requiredChannels: SessionChannelReadiness = .all,
        now: Date = Date()
    ) {
        self.negotiator = negotiator
        self.launchClient = launchClient
        let healthAggregator = SessionChannelHealthAggregator(requiredChannels: requiredChannels)
        self.healthAggregator = healthAggregator
        self.snapshot = StreamSessionSnapshot(
            sessionID: UUID(),
            hostID: nil,
            appID: nil,
            stage: .idle,
            parameters: nil,
            launchResponse: nil,
            videoColorMetadata: nil,
            negotiatedConfiguration: nil,
            channelHealth: healthAggregator.snapshot,
            reconnectAttempt: nil,
            terminationReason: nil,
            failure: nil,
            updatedAt: now
        )
    }

    func prepare(
        _ request: StreamLaunchRequest,
        sessionID: UUID = UUID(),
        now: Date = Date()
    ) throws -> StreamSessionSnapshot {
        guard [.idle, .disconnected, .failed].contains(snapshot.stage) else {
            throw invalidTransition("A new session cannot replace an active coordinator generation.")
        }

        snapshot.sessionID = sessionID
        snapshot.stage = .preparingParameters
        snapshot.hostID = request.host.id
        snapshot.appID = request.app.id
        snapshot.parameters = nil
        snapshot.launchResponse = nil
        snapshot.videoColorMetadata = nil
        snapshot.negotiatedConfiguration = nil
        snapshot.failure = nil
        snapshot.channelHealth = healthAggregator.replaceHealthyChannels([])
        snapshot.reconnectAttempt = nil
        snapshot.terminationReason = nil
        snapshot.updatedAt = now
        controlProgress = .idle
        lastReconnectAttempt = 0

        do {
            let parameters = try negotiator.makeParameters(from: request)
            snapshot.parameters = parameters
            snapshot.stage = .launching
            snapshot.updatedAt = now
            return snapshot
        } catch let failure as StreamNegotiationFailure {
            transitionToFailure(failure, now: now)
            throw failure
        }
    }

    func launch(_ request: StreamLaunchRequest, now: Date = Date()) async throws -> StreamSessionSnapshot {
        do {
            let prepared = try prepare(request, now: now)
            guard let parameters = prepared.parameters else {
                throw invalidTransition("Launch parameters are missing.")
            }
            let response = try await launchClient.launch(request, parameters: parameters)
            return try apply(
                .launchAccepted(response),
                sessionID: prepared.sessionID,
                now: Date()
            )
        } catch let failure as StreamNegotiationFailure {
            if snapshot.stage != .failed {
                transitionToFailure(failure, now: Date())
            }
            throw failure
        } catch {
            let failure = StreamNegotiationFailure(
                code: .launchRejected,
                subsystem: "launch",
                message: String(describing: error)
            )
            transitionToFailure(failure, now: Date())
            throw failure
        }
    }

    func apply(
        _ event: SessionControlEvent,
        sessionID: UUID,
        now: Date = Date()
    ) throws -> StreamSessionSnapshot {
        guard sessionID == snapshot.sessionID else {
            throw invalidTransition("A stale session generation cannot mutate the active session.")
        }

        switch event {
        case let .launchAccepted(response):
            if controlProgress.rawValue >= SessionControlProgress.launchAccepted.rawValue,
               snapshot.launchResponse == response,
               [.readyForTransport, .streaming, .reconnecting].contains(snapshot.stage) {
                return snapshot
            }
            guard snapshot.stage == .launching, controlProgress == .idle else {
                throw invalidTransition("Launch acceptance arrived outside the launching stage.")
            }
            snapshot.launchResponse = response
            snapshot.stage = .readyForTransport
            controlProgress = .launchAccepted

        case let .videoColorMetadata(metadata):
            guard controlProgress != .idle,
                  [.readyForTransport, .streaming, .reconnecting].contains(snapshot.stage) else {
                throw invalidTransition("Video color metadata arrived outside an active transport generation.")
            }
            do {
                try metadata.validate()
            } catch {
                throw invalidTransition("Video color metadata failed runtime contract validation.")
            }
            if snapshot.videoColorMetadata == metadata {
                return snapshot
            }
            var updatedConfiguration = snapshot.negotiatedConfiguration
            if var configuration = snapshot.negotiatedConfiguration {
                configuration.video.colorMetadata = metadata
                do {
                    try configuration.validate()
                } catch {
                    throw invalidTransition("Video color metadata is incompatible with the negotiated stream.")
                }
                updatedConfiguration = configuration
            }
            snapshot.videoColorMetadata = metadata
            snapshot.negotiatedConfiguration = updatedConfiguration

        case .rtspReady:
            if controlProgress.rawValue >= SessionControlProgress.rtspReady.rawValue,
               [.readyForTransport, .streaming, .reconnecting].contains(snapshot.stage) {
                return snapshot
            }
            guard controlProgress == .launchAccepted,
                  [.readyForTransport, .reconnecting].contains(snapshot.stage) else {
                throw invalidTransition("RTSP readiness requires an accepted launch or resume generation.")
            }
            controlProgress = .rtspReady

        case let .negotiated(configuration):
            if controlProgress == .negotiated,
               snapshot.negotiatedConfiguration == configuration,
               [.readyForTransport, .reconnecting, .streaming].contains(snapshot.stage) {
                return snapshot
            }
            guard controlProgress == .rtspReady,
                  [.readyForTransport, .reconnecting].contains(snapshot.stage),
                  configuration.sessionID == sessionID,
                  configuration.requiredChannels == snapshot.channelHealth.requiredChannels else {
                throw invalidTransition("Negotiated configuration does not match the active RTSP generation.")
            }
            do {
                try configuration.validate()
            } catch {
                throw invalidTransition("Negotiated configuration failed runtime contract validation.")
            }
            if let videoColorMetadata = snapshot.videoColorMetadata,
               videoColorMetadata != configuration.video.colorMetadata {
                throw invalidTransition("Negotiated video color metadata is stale.")
            }
            snapshot.videoColorMetadata = configuration.video.colorMetadata
            snapshot.negotiatedConfiguration = configuration
            controlProgress = .negotiated

        case let .channelsReady(healthyChannels):
            guard healthyChannels.subtracting(.all).isEmpty else {
                throw invalidTransition("Channel health contains unsupported readiness bits.")
            }
            if healthyChannels.satisfies(snapshot.channelHealth.requiredChannels),
               controlProgress != .negotiated {
                throw invalidTransition("Streaming readiness arrived before negotiated configuration.")
            }
            if healthyChannels == snapshot.channelHealth.healthyChannels {
                return snapshot
            }
            _ = try updateChannelHealth(healthyChannels, now: now)

        case let .reconnecting(attempt, _):
            guard attempt > 0,
                  [.readyForTransport, .streaming, .reconnecting].contains(snapshot.stage) else {
                throw invalidTransition("Reconnect attempt arrived outside an active transport stage.")
            }
            if attempt == lastReconnectAttempt, snapshot.stage == .reconnecting {
                return snapshot
            }
            guard attempt > lastReconnectAttempt else {
                throw invalidTransition("Reconnect attempts must be strictly increasing.")
            }
            lastReconnectAttempt = attempt
            snapshot.reconnectAttempt = attempt
            snapshot.videoColorMetadata = nil
            snapshot.negotiatedConfiguration = nil
            snapshot.channelHealth = healthAggregator.replaceHealthyChannels([])
            snapshot.stage = .reconnecting
            controlProgress = .launchAccepted

        case let .terminated(reason):
            if snapshot.stage == .disconnected,
               controlProgress == .terminal,
               snapshot.terminationReason == reason {
                return snapshot
            }
            guard ![.idle, .disconnected, .failed].contains(snapshot.stage) else {
                throw invalidTransition("Remote termination arrived outside an active session.")
            }
            snapshot.channelHealth = healthAggregator.replaceHealthyChannels([])
            snapshot.stage = .disconnected
            snapshot.terminationReason = reason
            snapshot.failure = nil
            controlProgress = .terminal
        }

        snapshot.updatedAt = now
        return snapshot
    }

    func fail(
        _ error: Error,
        sessionID: UUID,
        now: Date = Date()
    ) throws -> StreamSessionSnapshot {
        guard sessionID == snapshot.sessionID else {
            throw invalidTransition("A stale session failure cannot mutate the active session.")
        }
        if [.disconnected, .failed].contains(snapshot.stage),
           controlProgress == .terminal {
            return snapshot
        }
        let failure = (error as? StreamNegotiationFailure) ?? StreamNegotiationFailure(
            code: .transportUnavailable,
            subsystem: "session.control",
            message: "Session control failed."
        )
        transitionToFailure(failure, now: now)
        return snapshot
    }

    func markTransportStarted(
        readiness: SessionChannelReadiness,
        requiredChannels: SessionChannelReadiness = .all,
        now: Date = Date()
    ) throws -> StreamSessionSnapshot {
        guard snapshot.stage == .readyForTransport,
              requiredChannels == healthAggregator.snapshot.requiredChannels,
              snapshot.negotiatedConfiguration != nil,
              readiness.satisfies(requiredChannels) else {
            throw StreamNegotiationFailure(
                code: .invalidTransition,
                subsystem: "transport",
                message: "Streaming requires launch plus every required transport channel."
            )
        }
        snapshot.channelHealth = healthAggregator.replaceHealthyChannels(readiness)
        snapshot.stage = .streaming
        snapshot.updatedAt = now
        return snapshot
    }

    func updateChannelHealth(
        _ healthyChannels: SessionChannelReadiness,
        now: Date = Date()
    ) throws -> StreamSessionSnapshot {
        guard healthyChannels.subtracting(.all).isEmpty else {
            throw invalidTransition("Channel health contains unsupported readiness bits.")
        }
        guard [.readyForTransport, .streaming, .reconnecting].contains(snapshot.stage) else {
            throw StreamNegotiationFailure(
                code: .invalidTransition,
                subsystem: "transport",
                message: "Channel health is unavailable before launch transport begins."
            )
        }

        if healthyChannels.satisfies(snapshot.channelHealth.requiredChannels),
           snapshot.negotiatedConfiguration == nil {
            throw invalidTransition("Streaming requires a negotiated session configuration.")
        }

        let previousStage = snapshot.stage
        snapshot.channelHealth = healthAggregator.replaceHealthyChannels(healthyChannels)
        if snapshot.channelHealth.canStream {
            snapshot.stage = .streaming
        } else if previousStage == .streaming || previousStage == .reconnecting {
            snapshot.stage = .reconnecting
        }
        snapshot.updatedAt = now
        return snapshot
    }

    func stop(host: MoonlightHost, clientUniqueID: String, now: Date = Date()) async throws -> StreamSessionSnapshot {
        if snapshot.stage == .disconnected {
            return snapshot
        }
        if snapshot.stage == .idle {
            snapshot.stage = .disconnected
            snapshot.updatedAt = now
            controlProgress = .terminal
            return snapshot
        }
        snapshot.stage = .stopping
        snapshot.updatedAt = now
        do {
            try await launchClient.stop(host: host, clientUniqueID: clientUniqueID)
            transitionToDisconnected(now: Date())
            return snapshot
        } catch {
            transitionToDisconnected(now: Date())
            throw error
        }
    }

    private func transitionToFailure(
        _ failure: StreamNegotiationFailure,
        now: Date
    ) {
        snapshot.channelHealth = healthAggregator.replaceHealthyChannels([])
        snapshot.stage = .failed
        snapshot.failure = failure
        snapshot.terminationReason = nil
        snapshot.updatedAt = now
        controlProgress = .terminal
    }

    private func transitionToDisconnected(now: Date) {
        snapshot.channelHealth = healthAggregator.replaceHealthyChannels([])
        snapshot.stage = .disconnected
        snapshot.failure = nil
        snapshot.terminationReason = nil
        snapshot.updatedAt = now
        controlProgress = .terminal
    }

    private func invalidTransition(_ message: String) -> StreamNegotiationFailure {
        StreamNegotiationFailure(
            code: .invalidTransition,
            subsystem: "session.state",
            message: message
        )
    }
}
