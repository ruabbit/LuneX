import Foundation

enum PairingPersistenceError: Error, Equatable, Sendable {
    case invalidAuthenticatedResult
    case repositoryLoadFailed
    case repositorySaveFailed
    case persistedStateMismatch
    case rollbackFailed
}

actor PersistingPairingProvider: PairingRuntimeProvider {
    private struct Attempt {
        var token: UUID
        var task: Task<Void, Never>
    }

    private let provider: any PairingRuntimeProvider
    private let repository: any HostRepository
    private var attempts: [UUID: Attempt] = [:]

    init(
        provider: any PairingRuntimeProvider,
        repository: any HostRepository
    ) {
        self.provider = provider
        self.repository = repository
    }

    func pair(
        _ request: PairingRuntimeRequest
    ) async -> AsyncThrowingStream<PairingRuntimeEvent, Error> {
        attempts.removeValue(forKey: request.attemptID)?.task.cancel()
        let token = UUID()
        return AsyncThrowingStream { continuation in
            let task = Task {
                await self.forwardPairing(
                    request,
                    token: token,
                    continuation: continuation
                )
            }
            attempts[request.attemptID] = Attempt(token: token, task: task)
            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.cancelPairing(
                        attemptID: request.attemptID,
                        expectedToken: token
                    )
                }
            }
        }
    }

    func cancelPairing(attemptID: UUID) async {
        attempts.removeValue(forKey: attemptID)?.task.cancel()
        await provider.cancelPairing(attemptID: attemptID)
    }

    func activeAttemptCount() -> Int {
        attempts.count
    }

    private func forwardPairing(
        _ request: PairingRuntimeRequest,
        token: UUID,
        continuation: AsyncThrowingStream<PairingRuntimeEvent, Error>.Continuation
    ) async {
        do {
            let events = await provider.pair(request)
            for try await event in events {
                switch event {
                case .progress:
                    continuation.yield(event)
                case let .completed(result):
                    let persisted = try await commit(
                        result,
                        expectedHostID: request.host.id
                    )
                    continuation.yield(.completed(persisted))
                }
            }
            continuation.finish()
        } catch is CancellationError {
            continuation.finish(throwing: PairingFailure(
                code: .cancelled,
                message: "Pairing was cancelled."
            ))
        } catch {
            if Task.isCancelled {
                continuation.finish(throwing: PairingFailure(
                    code: .cancelled,
                    message: "Pairing was cancelled."
                ))
            } else {
                continuation.finish(throwing: error)
            }
        }
        removeAttempt(request.attemptID, expectedToken: token)
    }

    private func commit(
        _ result: PairingResult,
        expectedHostID: UUID
    ) async throws -> PairingResult {
        try validate(result, expectedHostID: expectedHostID)

        try Task.checkCancellation()
        let previousHosts: [MoonlightHost]
        do {
            previousHosts = try await repository.loadHosts()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw PairingPersistenceError.repositoryLoadFailed
        }

        var updatedHosts = previousHosts
        if let index = updatedHosts.firstIndex(where: { $0.id == expectedHostID }) {
            updatedHosts[index] = result.host
        } else {
            updatedHosts.append(result.host)
        }

        try Task.checkCancellation()
        do {
            try await repository.saveHosts(updatedHosts)
        } catch is CancellationError {
            do {
                try await rollback(to: previousHosts)
            } catch {
                throw PairingPersistenceError.rollbackFailed
            }
            throw CancellationError()
        } catch {
            throw PairingPersistenceError.repositorySaveFailed
        }

        do {
            try Task.checkCancellation()
            let reloadedHosts = try await repository.loadHosts()
            try Task.checkCancellation()
            guard Self.sameHosts(reloadedHosts, updatedHosts),
                  let reloadedHost = reloadedHosts.first(where: { $0.id == expectedHostID }),
                  reloadedHost == result.host else {
                try await rollback(to: previousHosts)
                throw PairingPersistenceError.persistedStateMismatch
            }
            var persistedResult = result
            persistedResult.host = reloadedHost
            return persistedResult
        } catch let error as PairingPersistenceError {
            throw error
        } catch is CancellationError {
            do {
                try await rollback(to: previousHosts)
            } catch {
                throw PairingPersistenceError.rollbackFailed
            }
            throw CancellationError()
        } catch {
            do {
                try await rollback(to: previousHosts)
            } catch {
                throw PairingPersistenceError.rollbackFailed
            }
            throw PairingPersistenceError.repositoryLoadFailed
        }
    }

    private func validate(
        _ result: PairingResult,
        expectedHostID: UUID
    ) throws {
        guard result.host.id == expectedHostID,
              result.host.pairingState == .paired,
              let pin = result.host.pinnedIdentity,
              pin.serverCertificateDER == result.serverIdentity.certificateDER,
              pin.certificateSHA256.caseInsensitiveCompare(
                  result.serverIdentity.certificateSHA256
              ) == .orderedSame else {
            throw PairingPersistenceError.invalidAuthenticatedResult
        }
        let actualDigest = try MoonlightPairingCrypto(serverMajorVersion: 7)
            .digest(result.serverIdentity.certificateDER)
            .pairingPersistenceHex
        guard actualDigest.caseInsensitiveCompare(result.serverIdentity.certificateSHA256)
                == .orderedSame else {
            throw PairingPersistenceError.invalidAuthenticatedResult
        }
    }

    private func rollback(to hosts: [MoonlightHost]) async throws {
        try await repository.saveHosts(hosts)
        let restored = try await repository.loadHosts()
        guard Self.sameHosts(restored, hosts) else {
            throw PairingPersistenceError.rollbackFailed
        }
    }

    private func cancelPairing(
        attemptID: UUID,
        expectedToken: UUID
    ) async {
        guard attempts[attemptID]?.token == expectedToken else { return }
        attempts.removeValue(forKey: attemptID)?.task.cancel()
        await provider.cancelPairing(attemptID: attemptID)
    }

    private func removeAttempt(
        _ attemptID: UUID,
        expectedToken: UUID
    ) {
        guard attempts[attemptID]?.token == expectedToken else { return }
        attempts.removeValue(forKey: attemptID)
    }

    private static func sameHosts(
        _ lhs: [MoonlightHost],
        _ rhs: [MoonlightHost]
    ) -> Bool {
        guard lhs.count == rhs.count else { return false }
        let left = Dictionary(lhs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let right = Dictionary(rhs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return left.count == lhs.count && right.count == rhs.count && left == right
    }
}

private extension Data {
    var pairingPersistenceHex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
