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
    var channelHealth: SessionChannelHealthSnapshot
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
        _ = try await requestExecutor.data(for: urlRequest, pinnedIdentity: host.pinnedIdentity)
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

actor StreamSessionCoordinator {
    private let negotiator: StreamNegotiator
    private let launchClient: StreamLaunchClient
    private var healthAggregator: SessionChannelHealthAggregator
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
            channelHealth: healthAggregator.snapshot,
            failure: nil,
            updatedAt: now
        )
    }

    func prepare(_ request: StreamLaunchRequest, now: Date = Date()) throws -> StreamSessionSnapshot {
        snapshot.stage = .preparingParameters
        snapshot.hostID = request.host.id
        snapshot.appID = request.app.id
        snapshot.failure = nil
        snapshot.channelHealth = healthAggregator.replaceHealthyChannels([])
        snapshot.updatedAt = now

        let parameters = try negotiator.makeParameters(from: request)
        snapshot.parameters = parameters
        snapshot.stage = .launching
        snapshot.updatedAt = now
        return snapshot
    }

    func launch(_ request: StreamLaunchRequest, now: Date = Date()) async throws -> StreamSessionSnapshot {
        let prepared = try prepare(request, now: now)
        guard let parameters = prepared.parameters else {
            throw StreamNegotiationFailure(code: .invalidTransition, subsystem: "session", message: "Launch parameters are missing.")
        }

        do {
            let response = try await launchClient.launch(request, parameters: parameters)
            snapshot.launchResponse = response
            snapshot.stage = .readyForTransport
            snapshot.updatedAt = Date()
            return snapshot
        } catch let failure as StreamNegotiationFailure {
            snapshot.stage = .failed
            snapshot.failure = failure
            snapshot.updatedAt = Date()
            throw failure
        } catch {
            let failure = StreamNegotiationFailure(
                code: .launchRejected,
                subsystem: "launch",
                message: String(describing: error)
            )
            snapshot.stage = .failed
            snapshot.failure = failure
            snapshot.updatedAt = Date()
            throw failure
        }
    }

    func markTransportStarted(
        readiness: SessionChannelReadiness,
        requiredChannels: SessionChannelReadiness = .all,
        now: Date = Date()
    ) throws -> StreamSessionSnapshot {
        guard snapshot.stage == .readyForTransport,
              requiredChannels == healthAggregator.snapshot.requiredChannels,
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
        guard [.readyForTransport, .streaming, .reconnecting].contains(snapshot.stage) else {
            throw StreamNegotiationFailure(
                code: .invalidTransition,
                subsystem: "transport",
                message: "Channel health is unavailable before launch transport begins."
            )
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
        snapshot.stage = .stopping
        snapshot.updatedAt = now
        try await launchClient.stop(host: host, clientUniqueID: clientUniqueID)
        snapshot.stage = .disconnected
        snapshot.updatedAt = Date()
        return snapshot
    }
}
