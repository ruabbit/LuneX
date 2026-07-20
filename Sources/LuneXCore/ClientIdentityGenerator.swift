import Foundation
import Security

protocol ClientIdentityGenerating: Sendable {
    func generateIdentity(createdAt: Date) throws -> ClientIdentityMaterial
}

enum ClientIdentityGenerationError: Error, Equatable {
    case keyGenerationFailed
    case publicKeyUnavailable
    case keyExportFailed
    case randomSerialFailed(OSStatus)
    case validityCalculationFailed
    case certificateSignatureFailed
}

struct SecurityClientIdentityGenerator: ClientIdentityGenerating {
    static let sunshineCommonName = "NVIDIA GameStream Client"

    func generateIdentity(createdAt: Date = Date()) throws -> ClientIdentityMaterial {
        let privateKey = try makePrivateKey()
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw ClientIdentityGenerationError.publicKeyUnavailable
        }

        let privateKeyPKCS1 = try externalRepresentation(of: privateKey)
        let publicKeyPKCS1 = try externalRepresentation(of: publicKey)
        let certificateDER = try SelfSignedClientCertificateBuilder.build(
            commonName: Self.sunshineCommonName,
            publicKeyPKCS1: publicKeyPKCS1,
            privateKey: privateKey,
            createdAt: createdAt
        )

        return ClientIdentityMaterial(
            certificateDER: certificateDER,
            privateKeyDER: privateKeyPKCS1,
            createdAt: createdAt
        )
    }

    private func makePrivateKey() throws -> SecKey {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits: 2_048,
            kSecAttrIsPermanent: false
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            error?.release()
            throw ClientIdentityGenerationError.keyGenerationFailed
        }
        return key
    }

    private func externalRepresentation(of key: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            error?.release()
            throw ClientIdentityGenerationError.keyExportFailed
        }
        return data
    }
}

private enum SelfSignedClientCertificateBuilder {
    private static let commonNameOID: [UInt8] = [0x55, 0x04, 0x03]
    private static let rsaEncryptionOID: [UInt8] = [
        0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x01
    ]
    private static let sha256WithRSAEncryptionOID: [UInt8] = [
        0x2A, 0x86, 0x48, 0x86, 0xF7, 0x0D, 0x01, 0x01, 0x0B
    ]

    static func build(
        commonName: String,
        publicKeyPKCS1: Data,
        privateKey: SecKey,
        createdAt: Date
    ) throws -> Data {
        let serial = try randomPositiveSerial()
        let signatureAlgorithm = DER.sequence(
            DER.objectIdentifier(sha256WithRSAEncryptionOID),
            DER.null
        )
        let name = DER.sequence(
            DER.set(
                DER.sequence(
                    DER.objectIdentifier(commonNameOID),
                    DER.utf8String(commonName)
                )
            )
        )
        let subjectPublicKeyInfo = DER.sequence(
            DER.sequence(
                DER.objectIdentifier(rsaEncryptionOID),
                DER.null
            ),
            DER.bitString(publicKeyPKCS1)
        )
        guard let expiresAt = certificateCalendar.date(
            byAdding: .year,
            value: 20,
            to: createdAt
        ) else {
            throw ClientIdentityGenerationError.validityCalculationFailed
        }
        let toBeSigned = DER.sequence(
            DER.explicit(tagNumber: 0, DER.integer(Data([2]))),
            DER.integer(serial),
            signatureAlgorithm,
            name,
            DER.sequence(DER.time(createdAt), DER.time(expiresAt)),
            name,
            subjectPublicKeyInfo
        )

        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            toBeSigned as CFData,
            &error
        ) as Data? else {
            error?.release()
            throw ClientIdentityGenerationError.certificateSignatureFailed
        }

        return DER.sequence(
            toBeSigned,
            signatureAlgorithm,
            DER.bitString(signature)
        )
    }

    private static var certificateCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func randomPositiveSerial() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 20)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw ClientIdentityGenerationError.randomSerialFailed(status)
        }
        bytes[0] &= 0x7F
        if bytes.allSatisfy({ $0 == 0 }) {
            bytes[bytes.count - 1] = 1
        }
        return Data(bytes)
    }
}

private enum DER {
    static func sequence(_ values: Data...) -> Data {
        wrap(tag: 0x30, contents: joined(values))
    }

    static func set(_ values: Data...) -> Data {
        wrap(tag: 0x31, contents: joined(values))
    }

    static func explicit(tagNumber: UInt8, _ value: Data) -> Data {
        precondition(tagNumber < 31)
        return wrap(tag: 0xA0 | tagNumber, contents: value)
    }

    static func integer(_ bytes: Data) -> Data {
        var value = Array(bytes.drop(while: { $0 == 0 }))
        if value.isEmpty {
            value = [0]
        } else if value[0] & 0x80 != 0 {
            value.insert(0, at: 0)
        }
        return wrap(tag: 0x02, contents: Data(value))
    }

    static func objectIdentifier(_ encodedComponents: [UInt8]) -> Data {
        wrap(tag: 0x06, contents: Data(encodedComponents))
    }

    static var null: Data {
        wrap(tag: 0x05, contents: Data())
    }

    static func utf8String(_ value: String) -> Data {
        wrap(tag: 0x0C, contents: Data(value.utf8))
    }

    static func time(_ date: Date) -> Data {
        let calendar = Calendar(identifier: .gregorian)
        let year = calendar.component(.year, from: date)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        if (1950..<2050).contains(year) {
            formatter.dateFormat = "yyMMddHHmmss'Z'"
            return wrap(tag: 0x17, contents: Data(formatter.string(from: date).utf8))
        }
        formatter.dateFormat = "yyyyMMddHHmmss'Z'"
        return wrap(tag: 0x18, contents: Data(formatter.string(from: date).utf8))
    }

    static func bitString(_ bytes: Data) -> Data {
        var contents = Data([0])
        contents.append(bytes)
        return wrap(tag: 0x03, contents: contents)
    }

    private static func joined(_ values: [Data]) -> Data {
        values.reduce(into: Data()) { result, value in
            result.append(value)
        }
    }

    private static func wrap(tag: UInt8, contents: Data) -> Data {
        var result = Data([tag])
        result.append(encodedLength(contents.count))
        result.append(contents)
        return result
    }

    private static func encodedLength(_ length: Int) -> Data {
        precondition(length >= 0)
        if length < 0x80 {
            return Data([UInt8(length)])
        }

        var remaining = length
        var octets: [UInt8] = []
        while remaining > 0 {
            octets.insert(UInt8(remaining & 0xFF), at: 0)
            remaining >>= 8
        }
        return Data([0x80 | UInt8(octets.count)] + octets)
    }
}
