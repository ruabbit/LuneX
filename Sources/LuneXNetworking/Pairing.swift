import Foundation

enum PairingDigestAlgorithm: String, Codable, Equatable, Sendable {
    case sha1
    case sha256

    static func algorithm(forServerMajorVersion majorVersion: Int) -> PairingDigestAlgorithm {
        majorVersion >= 7 ? .sha256 : .sha1
    }
}

enum PairingStage: String, Codable, Equatable, Sendable {
    case idle
    case waitingForPIN
    case exchangingSecrets
    case verifyingServer
    case pinningIdentity
    case paired
    case failed
    case cancelled
}

enum PairingFailureCode: String, Codable, Equatable, Sendable {
    case invalidPIN
    case invalidTransition
    case missingClientIdentity
    case missingHostAddress
    case transportFailed
    case serverRejected
    case certificateMismatch
    case cancelled
}

struct PairingFailure: Error, Codable, Equatable, Sendable, CustomStringConvertible {
    var code: PairingFailureCode
    var message: String

    var description: String {
        "\(code.rawValue): \(message)"
    }
}

struct PairingSnapshot: Codable, Equatable, Sendable {
    var attemptID: UUID
    var hostID: UUID
    var stage: PairingStage
    var digestAlgorithm: PairingDigestAlgorithm?
    var failure: PairingFailure?
    var updatedAt: Date
}

struct PairingServerIdentity: Codable, Equatable, Sendable {
    var certificateDER: Data
    var certificateSHA256: String
    var serverMajorVersion: Int
}

struct PairingResult: Codable, Equatable, Sendable {
    var host: MoonlightHost
    var serverIdentity: PairingServerIdentity
    var digestAlgorithm: PairingDigestAlgorithm
    var pairedAt: Date
}

actor PairingStateMachine {
    private(set) var snapshot: PairingSnapshot

    init(hostID: UUID, now: Date = Date()) {
        snapshot = PairingSnapshot(
            attemptID: UUID(),
            hostID: hostID,
            stage: .idle,
            digestAlgorithm: nil,
            failure: nil,
            updatedAt: now
        )
    }

    @discardableResult
    func begin(serverMajorVersion: Int, now: Date = Date()) -> PairingSnapshot {
        snapshot.stage = .waitingForPIN
        snapshot.digestAlgorithm = PairingDigestAlgorithm.algorithm(forServerMajorVersion: serverMajorVersion)
        snapshot.failure = nil
        snapshot.updatedAt = now
        return snapshot
    }

    @discardableResult
    func submitPIN(_ pin: String, now: Date = Date()) throws -> PairingSnapshot {
        try requireStage(.waitingForPIN)

        guard Self.isValidPIN(pin) else {
            throw transitionFailure(.invalidPIN, "PIN must contain exactly four decimal digits.")
        }

        snapshot.stage = .exchangingSecrets
        snapshot.failure = nil
        snapshot.updatedAt = now
        return snapshot
    }

    @discardableResult
    func markSecretsExchanged(now: Date = Date()) throws -> PairingSnapshot {
        try requireStage(.exchangingSecrets)
        snapshot.stage = .verifyingServer
        snapshot.failure = nil
        snapshot.updatedAt = now
        return snapshot
    }

    @discardableResult
    func pinServerIdentity(
        _ serverIdentity: PairingServerIdentity,
        for host: MoonlightHost,
        pairedAt: Date = Date()
    ) throws -> PairingResult {
        try requireStage(.verifyingServer)

        guard let digestAlgorithm = snapshot.digestAlgorithm else {
            throw transitionFailure(.invalidTransition, "Pairing digest algorithm was not negotiated.")
        }

        snapshot.stage = .pinningIdentity
        snapshot.failure = nil
        snapshot.updatedAt = pairedAt

        var pairedHost = host
        pairedHost.pairingState = .paired
        pairedHost.pinnedIdentity = PinnedHostIdentity(
            certificateSHA256: serverIdentity.certificateSHA256,
            serverCertificateDER: serverIdentity.certificateDER,
            pairedAt: pairedAt
        )

        snapshot.stage = .paired
        snapshot.updatedAt = pairedAt

        return PairingResult(
            host: pairedHost,
            serverIdentity: serverIdentity,
            digestAlgorithm: digestAlgorithm,
            pairedAt: pairedAt
        )
    }

    @discardableResult
    func fail(_ failure: PairingFailure, now: Date = Date()) -> PairingSnapshot {
        snapshot.stage = .failed
        snapshot.failure = failure
        snapshot.updatedAt = now
        return snapshot
    }

    @discardableResult
    func cancel(now: Date = Date()) -> PairingSnapshot {
        fail(
            PairingFailure(code: .cancelled, message: "Pairing was cancelled."),
            now: now
        )
    }

    private static func isValidPIN(_ pin: String) -> Bool {
        pin.count == 4 && pin.allSatisfy(\.isNumber)
    }

    private func requireStage(_ expected: PairingStage) throws {
        guard snapshot.stage == expected else {
            throw transitionFailure(
                .invalidTransition,
                "Expected pairing stage \(expected.rawValue), found \(snapshot.stage.rawValue)."
            )
        }
    }

    private func transitionFailure(_ code: PairingFailureCode, _ message: String) -> PairingFailure {
        PairingFailure(code: code, message: message)
    }
}
