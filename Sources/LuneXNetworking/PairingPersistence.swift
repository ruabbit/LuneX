import Foundation

enum PairingPersistenceError: Error, Equatable, Sendable {
    case invalidAuthenticatedResult
    case repositoryLoadFailed
    case repositorySaveFailed
    case persistedStateMismatch
    case rollbackFailed
}

actor PersistingPairingProvider: PairingRuntimeProvider {
    private let provider: any PairingRuntimeProvider
    private let repository: any HostRepository

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
        AsyncThrowingStream { continuation in
            Task {
                await self.forwardPairing(request, continuation: continuation)
            }
        }
    }

    func cancelPairing(attemptID: UUID) async {
        await provider.cancelPairing(attemptID: attemptID)
    }

    private func forwardPairing(
        _ request: PairingRuntimeRequest,
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
        } catch {
            continuation.finish(throwing: error)
        }
    }

    private func commit(
        _ result: PairingResult,
        expectedHostID: UUID
    ) async throws -> PairingResult {
        try validate(result, expectedHostID: expectedHostID)

        let previousHosts: [MoonlightHost]
        do {
            previousHosts = try await repository.loadHosts()
        } catch {
            throw PairingPersistenceError.repositoryLoadFailed
        }

        var updatedHosts = previousHosts
        if let index = updatedHosts.firstIndex(where: { $0.id == expectedHostID }) {
            updatedHosts[index] = result.host
        } else {
            updatedHosts.append(result.host)
        }

        do {
            try await repository.saveHosts(updatedHosts)
        } catch {
            throw PairingPersistenceError.repositorySaveFailed
        }

        do {
            let reloadedHosts = try await repository.loadHosts()
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
