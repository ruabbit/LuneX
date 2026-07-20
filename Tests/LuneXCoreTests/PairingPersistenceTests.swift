import Foundation
import XCTest

final class PairingPersistenceTests: XCTestCase {
    func testCompletedResultIsPublishedOnlyAfterExactSaveAndReload() async throws {
        let fixture = try makeFixture()
        let repository = PairingCommitRepository(hosts: [fixture.originalHost])
        let provider = PersistingPairingProvider(
            provider: CompletedPairingProvider(result: fixture.result),
            repository: repository
        )

        let events = try await collect(
            provider,
            request: fixture.request
        )

        guard case let .completed(result) = events.last else {
            return XCTFail("Expected persisted completion")
        }
        XCTAssertEqual(result, fixture.result)
        let snapshot = await repository.snapshot()
        XCTAssertEqual(snapshot.hosts, [fixture.result.host])
        XCTAssertEqual(snapshot.saveCount, 1)
        XCTAssertGreaterThanOrEqual(snapshot.loadCount, 2)
    }

    func testTransportFailureDoesNotWriteOrReplacePreviousPin() async throws {
        let fixture = try makeFixture()
        let repository = PairingCommitRepository(hosts: [fixture.originalHost])
        let provider = PersistingPairingProvider(
            provider: FailedPairingProvider(),
            repository: repository
        )

        await XCTAssertThrowsErrorAsync {
            _ = try await self.collect(provider, request: fixture.request)
        }

        let snapshot = await repository.snapshot()
        XCTAssertEqual(snapshot.hosts, [fixture.originalHost])
        XCTAssertEqual(snapshot.saveCount, 0)
    }

    func testSaveFailureDoesNotPublishCompletionOrReplacePreviousPin() async throws {
        let fixture = try makeFixture()
        let repository = PairingCommitRepository(
            hosts: [fixture.originalHost],
            failureMode: .failFirstSave
        )
        let provider = PersistingPairingProvider(
            provider: CompletedPairingProvider(result: fixture.result),
            repository: repository
        )

        await XCTAssertThrowsErrorAsync(
            PairingPersistenceError.repositorySaveFailed
        ) {
            _ = try await self.collect(provider, request: fixture.request)
        }

        let snapshot = await repository.snapshot()
        XCTAssertEqual(snapshot.hosts, [fixture.originalHost])
        XCTAssertEqual(snapshot.saveCount, 1)
    }

    func testReloadMismatchRollsBackPreviousTrustedHost() async throws {
        let fixture = try makeFixture()
        let repository = PairingCommitRepository(
            hosts: [fixture.originalHost],
            failureMode: .mismatchFirstReloadAfterSave
        )
        let provider = PersistingPairingProvider(
            provider: CompletedPairingProvider(result: fixture.result),
            repository: repository
        )

        await XCTAssertThrowsErrorAsync(
            PairingPersistenceError.persistedStateMismatch
        ) {
            _ = try await self.collect(provider, request: fixture.request)
        }

        let snapshot = await repository.snapshot()
        XCTAssertEqual(snapshot.hosts, [fixture.originalHost])
        XCTAssertEqual(snapshot.saveCount, 2)
    }

    func testInvalidAuthenticatedResultIsRejectedBeforeRepositoryAccess() async throws {
        var fixture = try makeFixture()
        fixture.result.serverIdentity.certificateSHA256 = String(repeating: "0", count: 64)
        let repository = PairingCommitRepository(hosts: [fixture.originalHost])
        let provider = PersistingPairingProvider(
            provider: CompletedPairingProvider(result: fixture.result),
            repository: repository
        )

        await XCTAssertThrowsErrorAsync(
            PairingPersistenceError.invalidAuthenticatedResult
        ) {
            _ = try await self.collect(provider, request: fixture.request)
        }

        let snapshot = await repository.snapshot()
        XCTAssertEqual(snapshot.loadCount, 0)
        XCTAssertEqual(snapshot.saveCount, 0)
        XCTAssertEqual(snapshot.hosts, [fixture.originalHost])
    }

    private func collect(
        _ provider: any PairingRuntimeProvider,
        request: PairingRuntimeRequest
    ) async throws -> [PairingRuntimeEvent] {
        var events: [PairingRuntimeEvent] = []
        let stream = await provider.pair(request)
        for try await event in stream {
            events.append(event)
        }
        return events
    }

    private func makeFixture() throws -> PairingPersistenceFixture {
        let hostID = UUID(uuidString: "A15FC2C1-E9DB-42B2-97E8-36A64E239753")!
        let attemptID = UUID(uuidString: "0E3358C3-89D4-48C2-9A50-0798425325E2")!
        let oldCertificate = Data(repeating: 0x11, count: 32)
        let newCertificate = Data(repeating: 0x22, count: 64)
        let digest = try MoonlightPairingCrypto(serverMajorVersion: 7)
            .digest(newCertificate)
            .pairingPersistenceTestHex
        let oldPin = PinnedHostIdentity(
            certificateSHA256: String(repeating: "1", count: 64),
            serverCertificateDER: oldCertificate,
            pairedAt: Date(timeIntervalSince1970: 50)
        )
        let originalHost = MoonlightHost(
            id: hostID,
            name: "Existing Host",
            address: "192.0.2.20",
            pairingState: .paired,
            reachability: .online,
            pinnedIdentity: oldPin
        )
        var pairedHost = originalHost
        pairedHost.pinnedIdentity = PinnedHostIdentity(
            certificateSHA256: digest,
            serverCertificateDER: newCertificate,
            pairedAt: Date(timeIntervalSince1970: 100)
        )
        let serverIdentity = PairingServerIdentity(
            certificateDER: newCertificate,
            certificateSHA256: digest,
            serverMajorVersion: 7
        )
        let result = PairingResult(
            host: pairedHost,
            serverIdentity: serverIdentity,
            digestAlgorithm: .sha256,
            pairedAt: Date(timeIntervalSince1970: 100)
        )
        let request = PairingRuntimeRequest(
            attemptID: attemptID,
            host: originalHost,
            pin: "1234",
            clientIdentity: ClientIdentityMaterial(
                id: UUID(uuidString: "CE4A7C79-6D8A-407F-B981-570647774B2D")!,
                certificateDER: Data([1]),
                privateKeyDER: Data([2]),
                createdAt: Date(timeIntervalSince1970: 10)
            )
        )
        return PairingPersistenceFixture(
            originalHost: originalHost,
            request: request,
            result: result
        )
    }
}

private struct PairingPersistenceFixture {
    var originalHost: MoonlightHost
    var request: PairingRuntimeRequest
    var result: PairingResult
}

private struct CompletedPairingProvider: PairingRuntimeProvider {
    var result: PairingResult

    func pair(
        _ request: PairingRuntimeRequest
    ) async -> AsyncThrowingStream<PairingRuntimeEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(.completed(result))
            continuation.finish()
        }
    }

    func cancelPairing(attemptID: UUID) async {}
}

private struct FailedPairingProvider: PairingRuntimeProvider {
    func pair(
        _ request: PairingRuntimeRequest
    ) async -> AsyncThrowingStream<PairingRuntimeEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish(throwing: PairingFailure(
                code: .certificateMismatch,
                message: "Synthetic failure"
            ))
        }
    }

    func cancelPairing(attemptID: UUID) async {}
}

private actor PairingCommitRepository: HostRepository {
    enum FailureMode {
        case none
        case failFirstSave
        case mismatchFirstReloadAfterSave
    }

    private var hosts: [MoonlightHost]
    private let failureMode: FailureMode
    private var loadCount = 0
    private var saveCount = 0
    private var hasReturnedMismatch = false

    init(
        hosts: [MoonlightHost],
        failureMode: FailureMode = .none
    ) {
        self.hosts = hosts
        self.failureMode = failureMode
    }

    func loadHosts() async throws -> [MoonlightHost] {
        loadCount += 1
        if failureMode == .mismatchFirstReloadAfterSave,
           saveCount == 1,
           !hasReturnedMismatch {
            hasReturnedMismatch = true
            return []
        }
        return hosts
    }

    func saveHosts(_ hosts: [MoonlightHost]) async throws {
        saveCount += 1
        if failureMode == .failFirstSave, saveCount == 1 {
            throw PairingPersistenceTestError.synthetic
        }
        self.hosts = hosts
    }

    func snapshot() -> (hosts: [MoonlightHost], loadCount: Int, saveCount: Int) {
        (hosts, loadCount, saveCount)
    }
}

private enum PairingPersistenceTestError: Error {
    case synthetic
}

private extension Data {
    var pairingPersistenceTestHex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expected: (any Error)? = nil,
    operation: () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await operation()
        XCTFail("Expected operation to throw", file: file, line: line)
    } catch {
        if let expected {
            XCTAssertEqual(
                String(describing: error),
                String(describing: expected),
                file: file,
                line: line
            )
        }
    }
}
