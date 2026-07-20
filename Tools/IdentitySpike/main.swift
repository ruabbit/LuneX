import Foundation
import Security

private enum SpikeError: Error, CustomStringConvertible {
    case keyGeneration(CFError?)
    case externalRepresentation(String, CFError?)
    case randomSerial(OSStatus)
    case signature(String, CFError?)
    case certificateParsing
    case certificatePublicKey
    case publicKeyMismatch
    case signatureVerification(String, CFError?)

    var description: String {
        switch self {
        case let .keyGeneration(error):
            return "RSA key generation failed: \(String(describing: error))"
        case let .externalRepresentation(kind, error):
            return "Could not export \(kind): \(String(describing: error))"
        case let .randomSerial(status):
            return "Could not generate certificate serial: OSStatus \(status)"
        case let .signature(kind, error):
            return "Could not create \(kind) signature: \(String(describing: error))"
        case .certificateParsing:
            return "Security.framework rejected the generated X.509 DER"
        case .certificatePublicKey:
            return "Security.framework could not extract the certificate public key"
        case .publicKeyMismatch:
            return "Certificate public key differs from the generated RSA public key"
        case let .signatureVerification(kind, error):
            return "Could not verify \(kind) signature: \(String(describing: error))"
        }
    }
}

private enum DER {
    static func sequence(_ values: Data...) -> Data {
        wrap(tag: 0x30, contents: values.reduce(into: Data(), { $0.append($1) }))
    }

    static func set(_ values: Data...) -> Data {
        wrap(tag: 0x31, contents: values.reduce(into: Data(), { $0.append($1) }))
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

    static func utcTime(_ date: Date) -> Data {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyMMddHHmmss'Z'"
        return wrap(tag: 0x17, contents: Data(formatter.string(from: date).utf8))
    }

    static func bitString(_ bytes: Data) -> Data {
        var contents = Data([0])
        contents.append(bytes)
        return wrap(tag: 0x03, contents: contents)
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

private struct SelfSignedCertificate {
    let der: Data
    let toBeSigned: Data
    let signature: Data
}

private enum CertificateBuilder {
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
        now: Date = Date()
    ) throws -> SelfSignedCertificate {
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
        let expires = now.addingTimeInterval(20 * 365 * 24 * 60 * 60)
        let toBeSigned = DER.sequence(
            DER.explicit(tagNumber: 0, DER.integer(Data([2]))),
            DER.integer(serial),
            signatureAlgorithm,
            name,
            DER.sequence(DER.utcTime(now), DER.utcTime(expires)),
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
            throw SpikeError.signature("certificate", error?.takeRetainedValue())
        }

        let certificate = DER.sequence(
            toBeSigned,
            signatureAlgorithm,
            DER.bitString(signature)
        )
        return SelfSignedCertificate(
            der: certificate,
            toBeSigned: toBeSigned,
            signature: signature
        )
    }

    private static func randomPositiveSerial() throws -> Data {
        var bytes = [UInt8](repeating: 0, count: 20)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        guard status == errSecSuccess else {
            throw SpikeError.randomSerial(status)
        }
        bytes[0] &= 0x7F
        if bytes.allSatisfy({ $0 == 0 }) {
            bytes[bytes.count - 1] = 1
        }
        return Data(bytes)
    }
}

private func externalRepresentation(of key: SecKey, kind: String) throws -> Data {
    var error: Unmanaged<CFError>?
    guard let data = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
        throw SpikeError.externalRepresentation(kind, error?.takeRetainedValue())
    }
    return data
}

private func verify(
    key: SecKey,
    payload: Data,
    signature: Data,
    kind: String
) throws {
    var error: Unmanaged<CFError>?
    guard SecKeyVerifySignature(
        key,
        .rsaSignatureMessagePKCS1v15SHA256,
        payload as CFData,
        signature as CFData,
        &error
    ) else {
        throw SpikeError.signatureVerification(kind, error?.takeRetainedValue())
    }
}

private func runSpike() throws {
    let attributes: [CFString: Any] = [
        kSecAttrKeyType: kSecAttrKeyTypeRSA,
        kSecAttrKeySizeInBits: 2048,
        kSecAttrIsPermanent: false
    ]
    var error: Unmanaged<CFError>?
    guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
        throw SpikeError.keyGeneration(error?.takeRetainedValue())
    }
    guard let generatedPublicKey = SecKeyCopyPublicKey(privateKey) else {
        throw SpikeError.certificatePublicKey
    }

    let privateKeyPKCS1 = try externalRepresentation(of: privateKey, kind: "private key")
    let publicKeyPKCS1 = try externalRepresentation(of: generatedPublicKey, kind: "public key")
    let generatedCertificate = try CertificateBuilder.build(
        commonName: "LuneX Clean Room Client",
        publicKeyPKCS1: publicKeyPKCS1,
        privateKey: privateKey
    )

    guard let certificate = SecCertificateCreateWithData(
        nil,
        generatedCertificate.der as CFData
    ) else {
        throw SpikeError.certificateParsing
    }
    guard let certificatePublicKey = SecCertificateCopyKey(certificate) else {
        throw SpikeError.certificatePublicKey
    }
    let certificatePublicKeyPKCS1 = try externalRepresentation(
        of: certificatePublicKey,
        kind: "certificate public key"
    )
    guard certificatePublicKeyPKCS1 == publicKeyPKCS1 else {
        throw SpikeError.publicKeyMismatch
    }

    try verify(
        key: certificatePublicKey,
        payload: generatedCertificate.toBeSigned,
        signature: generatedCertificate.signature,
        kind: "certificate"
    )

    let challenge = Data("LuneX identity spike challenge".utf8)
    error = nil
    guard let challengeSignature = SecKeyCreateSignature(
        privateKey,
        .rsaSignatureMessagePKCS1v15SHA256,
        challenge as CFData,
        &error
    ) as Data? else {
        throw SpikeError.signature("challenge", error?.takeRetainedValue())
    }
    try verify(
        key: certificatePublicKey,
        payload: challenge,
        signature: challengeSignature,
        kind: "challenge"
    )

    print("PASS: ephemeral Security.framework RSA-2048 key generated")
    print("PASS: X.509 v3 SHA256WithRSA certificate parsed (\(generatedCertificate.der.count) bytes)")
    print("PASS: certificate public key matches generated public key")
    print("PASS: certificate and challenge signatures verified")
    print("PASS: no Keychain or identity-store operation was performed")
    print("INFO: exported PKCS#1 private key size \(privateKeyPKCS1.count) bytes; material not written")
}

do {
    try runSpike()
} catch {
    FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}
