import Foundation
import Security

enum KeychainIdentityStoreError: Error, Equatable {
    case unexpectedData
    case unhandledStatus(OSStatus)
}

actor KeychainClientIdentityStore: ClientIdentityStore {
    private let service: String
    private let account: String

    init(service: String = "dev.lunex.client.identity", account: String = "moonlight-client") {
        self.service = service
        self.account = account
    }

    func loadIdentity() async throws -> ClientIdentityMaterial? {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            throw KeychainIdentityStoreError.unhandledStatus(status)
        }
        guard let data = result as? Data else {
            throw KeychainIdentityStoreError.unexpectedData
        }
        return try JSONDecoder().decode(ClientIdentityMaterial.self, from: data)
    }

    func saveIdentity(_ identity: ClientIdentityMaterial) async throws {
        let data = try JSONEncoder().encode(identity)
        var query = baseQuery()
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecDuplicateItem {
            let updateStatus = SecItemUpdate(
                baseQuery() as CFDictionary,
                [kSecValueData as String: data] as CFDictionary
            )
            guard updateStatus == errSecSuccess else {
                throw KeychainIdentityStoreError.unhandledStatus(updateStatus)
            }
            return
        }

        guard status == errSecSuccess else {
            throw KeychainIdentityStoreError.unhandledStatus(status)
        }
    }

    func deleteIdentity() async throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainIdentityStoreError.unhandledStatus(status)
        }
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }
}
