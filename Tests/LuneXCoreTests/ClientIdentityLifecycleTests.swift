import Foundation
import XCTest

final class ClientIdentityLifecycleTests: XCTestCase {
    func testValidatorAcceptsGeneratedIdentityAndRejectsMismatchedPrivateKey() throws {
        let generator = SecurityClientIdentityGenerator()
        let validator = SecurityClientIdentityValidator()
        let first = try generator.generateIdentity(createdAt: Date(timeIntervalSince1970: 100))
        let second = try generator.generateIdentity(createdAt: Date(timeIntervalSince1970: 100))

        XCTAssertNoThrow(try validator.validate(first))

        var mismatched = first
        mismatched.privateKeyDER = second.privateKeyDER
        XCTAssertThrowsError(try validator.validate(mismatched)) { error in
            XCTAssertEqual(error as? ClientIdentityValidationError, .publicKeyMismatch)
        }
    }

    func testValidatorRejectsCertificateWithMutatedSignature() throws {
        let generator = SecurityClientIdentityGenerator()
        let validator = SecurityClientIdentityValidator()
        var identity = try generator.generateIdentity(createdAt: Date(timeIntervalSince1970: 100))
        identity.certificateDER[identity.certificateDER.index(before: identity.certificateDER.endIndex)] ^= 0x01

        XCTAssertThrowsError(try validator.validate(identity)) { error in
            XCTAssertEqual(error as? ClientIdentityValidationError, .certificateSignatureInvalid)
        }
    }

    func testManagerPersistsReloadsAndReusesExactJSONIdentity() async throws {
        let fixture = makeJSONStoreFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)

        let firstManager = ClientIdentityManager(store: fixture.store)
        let first = try await firstManager.loadOrCreateIdentity(createdAt: createdAt)
        let secondManager = ClientIdentityManager(store: fixture.store)
        let second = try await secondManager.loadOrCreateIdentity(
            createdAt: createdAt.addingTimeInterval(100)
        )

        XCTAssertEqual(second, first)
        XCTAssertEqual(second.id, first.id)
        XCTAssertEqual(second.createdAt, createdAt)
    }

    func testManagerExplicitResetDeletesIdentityAndAllowsFreshGeneration() async throws {
        let fixture = makeJSONStoreFixture()
        defer { try? FileManager.default.removeItem(at: fixture.directory) }
        let manager = ClientIdentityManager(store: fixture.store)
        let first = try await manager.loadOrCreateIdentity(createdAt: Date(timeIntervalSince1970: 100))

        try await manager.resetIdentity()
        let deleted = try await fixture.store.loadIdentity()
        XCTAssertNil(deleted)

        let second = try await manager.loadOrCreateIdentity(createdAt: Date(timeIntervalSince1970: 200))
        XCTAssertNotEqual(second.id, first.id)
        XCTAssertNotEqual(second.privateKeyDER, first.privateKeyDER)
    }

    func testManagerDoesNotReplaceInvalidPersistedIdentity() async throws {
        let generator = SecurityClientIdentityGenerator()
        var invalid = try generator.generateIdentity(createdAt: Date(timeIntervalSince1970: 100))
        invalid.privateKeyDER = Data([0x01, 0x02, 0x03])
        let store = InMemoryClientIdentityStore(identity: invalid)
        let manager = ClientIdentityManager(store: store)

        await XCTAssertThrowsErrorAsync(try await manager.loadOrCreateIdentity())
        let persisted = try await store.loadIdentity()
        XCTAssertEqual(persisted, invalid)
    }

    private func makeJSONStoreFixture() -> (
        directory: URL,
        store: JSONFileClientIdentityStore
    ) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        return (
            directory,
            JSONFileClientIdentityStore(
                fileURL: directory.appendingPathComponent("client_identity.debug.json")
            )
        )
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    file: StaticString = #filePath,
    line: UInt = #line
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw", file: file, line: line)
    } catch {
        // Expected failure.
    }
}
