import Foundation
import Security
import XCTest

final class ClientIdentityGenerationTests: XCTestCase {
    func testSecurityGeneratorCreatesImportableRSA2048Identity() throws {
        let createdAt = Date(timeIntervalSince1970: 1_800_000_000)
        let identity = try SecurityClientIdentityGenerator().generateIdentity(createdAt: createdAt)

        XCTAssertEqual(identity.createdAt, createdAt)
        XCTAssertFalse(identity.certificateDER.isEmpty)
        XCTAssertFalse(identity.privateKeyDER.isEmpty)

        let privateKey = try importPrivateKey(identity.privateKeyDER)
        guard let privateAttributes = SecKeyCopyAttributes(privateKey) as NSDictionary? else {
            return XCTFail("Could not inspect generated RSA private key")
        }
        XCTAssertEqual(privateAttributes[kSecAttrKeyType] as? String, kSecAttrKeyTypeRSA as String)
        XCTAssertEqual(privateAttributes[kSecAttrKeySizeInBits] as? Int, 2_048)

        guard let certificate = SecCertificateCreateWithData(nil, identity.certificateDER as CFData) else {
            return XCTFail("Security.framework rejected generated certificate DER")
        }
        guard let certificatePublicKey = SecCertificateCopyKey(certificate),
              let privatePublicKey = SecKeyCopyPublicKey(privateKey) else {
            return XCTFail("Could not extract generated RSA public keys")
        }

        XCTAssertEqual(
            try externalRepresentation(certificatePublicKey),
            try externalRepresentation(privatePublicKey)
        )
    }

    func testGeneratorProducesDistinctIdentityAndKeyMaterial() throws {
        let generator = SecurityClientIdentityGenerator()
        let first = try generator.generateIdentity(createdAt: Date(timeIntervalSince1970: 100))
        let second = try generator.generateIdentity(createdAt: Date(timeIntervalSince1970: 100))

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertNotEqual(first.privateKeyDER, second.privateKeyDER)
        XCTAssertNotEqual(first.certificateDER, second.certificateDER)
    }

    private func importPrivateKey(_ data: Data) throws -> SecKey {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits: 2_048
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(data as CFData, attributes as CFDictionary, &error) else {
            throw error?.takeRetainedValue() ?? ClientIdentityGenerationError.keyGenerationFailed
        }
        return key
    }

    private func externalRepresentation(_ key: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            throw error?.takeRetainedValue() ?? ClientIdentityGenerationError.keyExportFailed
        }
        return data
    }
}
