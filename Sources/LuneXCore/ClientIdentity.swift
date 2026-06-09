import Foundation

struct ClientIdentityMaterial: Codable, Equatable, Sendable {
    var id: UUID
    var certificateDER: Data
    var privateKeyDER: Data
    var createdAt: Date

    init(
        id: UUID = UUID(),
        certificateDER: Data,
        privateKeyDER: Data,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.certificateDER = certificateDER
        self.privateKeyDER = privateKeyDER
        self.createdAt = createdAt
    }
}

protocol ClientIdentityStore: Sendable {
    func loadIdentity() async throws -> ClientIdentityMaterial?
    func saveIdentity(_ identity: ClientIdentityMaterial) async throws
    func deleteIdentity() async throws
}

actor InMemoryClientIdentityStore: ClientIdentityStore {
    private var identity: ClientIdentityMaterial?

    init(identity: ClientIdentityMaterial? = nil) {
        self.identity = identity
    }

    func loadIdentity() async throws -> ClientIdentityMaterial? {
        identity
    }

    func saveIdentity(_ identity: ClientIdentityMaterial) async throws {
        self.identity = identity
    }

    func deleteIdentity() async throws {
        identity = nil
    }
}
