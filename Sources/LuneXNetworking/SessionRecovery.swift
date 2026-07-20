import Foundation
import Security

enum SessionChannelHealthStatus: String, Codable, Equatable, Sendable {
    case unavailable
    case degraded
    case ready
}

struct SessionChannelHealthSnapshot: Codable, Equatable, Sendable {
    let requiredChannels: SessionChannelReadiness
    let healthyChannels: SessionChannelReadiness

    var status: SessionChannelHealthStatus {
        if requiredChannels.isEmpty || healthyChannels.isEmpty {
            return .unavailable
        }
        return healthyChannels.satisfies(requiredChannels) ? .ready : .degraded
    }

    var canStream: Bool {
        status == .ready
    }

    init(
        requiredChannels: SessionChannelReadiness,
        healthyChannels: SessionChannelReadiness
    ) {
        let knownRequired = requiredChannels.intersection(.all)
        let knownHealthy = healthyChannels.intersection(.all)
        self.requiredChannels = knownRequired
        self.healthyChannels = knownHealthy
    }
}

struct SessionChannelHealthAggregator: Sendable {
    private(set) var snapshot: SessionChannelHealthSnapshot

    init(requiredChannels: SessionChannelReadiness = .all) {
        snapshot = SessionChannelHealthSnapshot(
            requiredChannels: requiredChannels,
            healthyChannels: []
        )
    }

    @discardableResult
    mutating func replaceHealthyChannels(
        _ channels: SessionChannelReadiness
    ) -> SessionChannelHealthSnapshot {
        snapshot = SessionChannelHealthSnapshot(
            requiredChannels: snapshot.requiredChannels,
            healthyChannels: channels
        )
        return snapshot
    }

    @discardableResult
    mutating func markHealthy(
        _ channels: SessionChannelReadiness
    ) -> SessionChannelHealthSnapshot {
        replaceHealthyChannels(snapshot.healthyChannels.union(channels))
    }

    @discardableResult
    mutating func markUnhealthy(
        _ channels: SessionChannelReadiness
    ) -> SessionChannelHealthSnapshot {
        replaceHealthyChannels(snapshot.healthyChannels.subtracting(channels))
    }
}

enum SessionRecoveryError: Error, Equatable, Sendable {
    case invalidReconnectPolicy
    case randomGenerationFailed(status: Int32)
}

struct SessionReconnectPolicy: Equatable, Sendable {
    var maximumAttempts: Int
    var delays: [Duration]

    static let standard = SessionReconnectPolicy(
        maximumAttempts: 3,
        delays: [.milliseconds(100), .milliseconds(250), .milliseconds(500)]
    )

    func validate() throws {
        guard maximumAttempts > 0,
              delays.count >= maximumAttempts,
              delays.prefix(maximumAttempts).allSatisfy({ $0 >= .zero }) else {
            throw SessionRecoveryError.invalidReconnectPolicy
        }
    }

    func delay(forAttempt attempt: Int) throws -> Duration {
        try validate()
        guard (1...maximumAttempts).contains(attempt) else {
            throw SessionRecoveryError.invalidReconnectPolicy
        }
        return delays[attempt - 1]
    }
}

protocol SessionReconnectSleeping: Sendable {
    func sleep(for delay: Duration) async throws
}

struct ContinuousSessionReconnectSleeper: SessionReconnectSleeping {
    func sleep(for delay: Duration) async throws {
        try await Task.sleep(for: delay)
    }
}

protocol RemoteInputKeyMaterialGenerating: Sendable {
    func generate() throws -> RemoteInputKeyMaterial
}

struct SecureRemoteInputKeyMaterialGenerator: RemoteInputKeyMaterialGenerating {
    func generate() throws -> RemoteInputKeyMaterial {
        var bytes = [UInt8](repeating: 0, count: 20)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw SessionRecoveryError.randomGenerationFailed(status: status)
        }
        let keyID = bytes[16...19].reduce(UInt32(0)) {
            ($0 << 8) | UInt32($1)
        }
        return RemoteInputKeyMaterial(
            keyID: Int(keyID),
            key: Data(bytes[0..<16])
        )
    }
}

struct SessionReconnectFailureClassifier: Sendable {
    func isRetryable(_ error: Error) -> Bool {
        if error is CancellationError || error is PinnedTransportError {
            return false
        }
        if let error = error as? ControlChannelError {
            if case .disconnected = error { return true }
            return false
        }
        if let error = error as? ENetTransportError {
            switch error {
            case .resolutionFailed, .connectionFailed, .timedOut, .disconnected,
                 .sendFailed, .serviceFailed, .unknown:
                return true
            case .invalidArgument, .initializationFailed, .hostCreationFailed,
                 .payloadTooLarge:
                return false
            }
        }
        if let error = error as? NetworkChannelError {
            switch error {
            case .timedOut, .closed, .posixFailure, .dnsFailure,
                 .wifiAwareFailure, .unknownTransportFailure:
                return true
            case .invalidEndpoint, .invalidReadBounds, .payloadTooLarge,
                 .invalidTimeout, .invalidState, .cancelled, .tlsFailure:
                return false
            }
        }
        if let error = error as? URLError {
            switch error.code {
            case .timedOut, .cannotFindHost, .cannotConnectToHost,
                 .networkConnectionLost, .dnsLookupFailed, .notConnectedToInternet,
                 .internationalRoamingOff, .callIsActive, .dataNotAllowed:
                return true
            default:
                return false
            }
        }
        if let error = error as? RTSPBootstrapError {
            return error == .connectionClosed
        }
        return false
    }
}
