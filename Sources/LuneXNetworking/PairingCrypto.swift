import CommonCrypto
import Foundation
import Security

enum PairingCryptoError: Error, Equatable, Sendable {
    case invalidServerMajorVersion
    case invalidSalt
    case invalidPIN
    case invalidAESKey
    case invalidBlockLength
    case invalidChallenge
    case invalidSecret
    case invalidCertificate
    case inputTooLarge
    case randomGenerationFailed(OSStatus)
    case aesFailure(Int32)
    case privateKeyParsingFailed
    case signingFailed
    case signatureVerificationFailed
    case responseMismatch
}

struct PairingServerChallengeMaterial: Equatable, Sendable {
    var responseHash: Data
    var serverChallenge: Data
}

struct MoonlightPairingCrypto: Sendable {
    let serverMajorVersion: Int
    let digestAlgorithm: PairingDigestAlgorithm

    var digestLength: Int {
        digestAlgorithm == .sha256 ? Int(CC_SHA256_DIGEST_LENGTH) : Int(CC_SHA1_DIGEST_LENGTH)
    }

    init(serverMajorVersion: Int) throws {
        guard serverMajorVersion > 0 else {
            throw PairingCryptoError.invalidServerMajorVersion
        }
        self.serverMajorVersion = serverMajorVersion
        self.digestAlgorithm = .algorithm(forServerMajorVersion: serverMajorVersion)
    }

    func generateSalt() throws -> Data {
        try randomBytes(count: 16)
    }

    func generateNonce() throws -> Data {
        try randomBytes(count: 16)
    }

    func deriveAESKey(salt: Data, pin: String) throws -> Data {
        guard salt.count == 16 else {
            throw PairingCryptoError.invalidSalt
        }
        let pinBytes = Data(pin.utf8)
        guard pinBytes.count == 4,
              pinBytes.allSatisfy({ (0x30...0x39).contains($0) }) else {
            throw PairingCryptoError.invalidPIN
        }
        var saltedPIN = Data()
        saltedPIN.reserveCapacity(salt.count + pinBytes.count)
        saltedPIN.append(salt)
        saltedPIN.append(pinBytes)
        return try digest(saltedPIN).prefixData(16)
    }

    func digest(_ data: Data) throws -> Data {
        guard data.count <= Int(UInt32.max) else {
            throw PairingCryptoError.inputTooLarge
        }
        let bytes = [UInt8](data)
        switch digestAlgorithm {
        case .sha1:
            var output = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            bytes.withUnsafeBytes { buffer in
                _ = CC_SHA1(buffer.baseAddress, CC_LONG(bytes.count), &output)
            }
            return Data(output)
        case .sha256:
            var output = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            bytes.withUnsafeBytes { buffer in
                _ = CC_SHA256(buffer.baseAddress, CC_LONG(bytes.count), &output)
            }
            return Data(output)
        }
    }

    func encryptClientChallenge(_ challenge: Data, aesKey: Data) throws -> Data {
        guard challenge.count == 16 else {
            throw PairingCryptoError.invalidChallenge
        }
        return try cryptAES128ECB(challenge, key: aesKey, operation: CCOperation(kCCEncrypt))
    }

    func encryptAES128ECB(_ plaintext: Data, aesKey: Data) throws -> Data {
        try cryptAES128ECB(plaintext, key: aesKey, operation: CCOperation(kCCEncrypt))
    }

    func decryptAES128ECB(_ ciphertext: Data, aesKey: Data) throws -> Data {
        try cryptAES128ECB(ciphertext, key: aesKey, operation: CCOperation(kCCDecrypt))
    }

    func decryptServerChallengeResponse(
        _ encryptedResponse: Data,
        aesKey: Data
    ) throws -> PairingServerChallengeMaterial {
        let plaintext = try decryptAES128ECB(encryptedResponse, aesKey: aesKey)
        let requiredLength = digestLength + 16
        guard plaintext.count >= requiredLength else {
            throw PairingCryptoError.invalidChallenge
        }
        return PairingServerChallengeMaterial(
            responseHash: Data(plaintext.prefix(digestLength)),
            serverChallenge: Data(plaintext.dropFirst(digestLength).prefix(16))
        )
    }

    func makeEncryptedChallengeResponse(
        serverChallenge: Data,
        clientCertificateSignature: Data,
        clientSecret: Data,
        aesKey: Data
    ) throws -> Data {
        guard serverChallenge.count == 16 else {
            throw PairingCryptoError.invalidChallenge
        }
        guard clientSecret.count == 16 else {
            throw PairingCryptoError.invalidSecret
        }
        guard !clientCertificateSignature.isEmpty else {
            throw PairingCryptoError.invalidCertificate
        }
        var input = Data()
        input.reserveCapacity(serverChallenge.count + clientCertificateSignature.count + clientSecret.count)
        input.append(serverChallenge)
        input.append(clientCertificateSignature)
        input.append(clientSecret)
        let responseDigest = try digest(input)
        var paddedResponse = Data(repeating: 0, count: 32)
        paddedResponse.replaceSubrange(0..<responseDigest.count, with: responseDigest)
        return try cryptAES128ECB(
            paddedResponse,
            key: aesKey,
            operation: CCOperation(kCCEncrypt)
        )
    }

    func verifyServerResponse(
        responseHash: Data,
        clientChallenge: Data,
        serverCertificateSignature: Data,
        serverSecret: Data
    ) throws {
        guard responseHash.count == digestLength,
              clientChallenge.count == 16 else {
            throw PairingCryptoError.invalidChallenge
        }
        guard serverSecret.count == 16 else {
            throw PairingCryptoError.invalidSecret
        }
        guard !serverCertificateSignature.isEmpty else {
            throw PairingCryptoError.invalidCertificate
        }
        var input = Data()
        input.append(clientChallenge)
        input.append(serverCertificateSignature)
        input.append(serverSecret)
        guard constantTimeEqual(responseHash, try digest(input)) else {
            throw PairingCryptoError.responseMismatch
        }
    }

    func certificateSignature(certificateDER: Data) throws -> Data {
        do {
            return try X509CertificateEnvelope.parse(certificateDER).signature
        } catch {
            throw PairingCryptoError.invalidCertificate
        }
    }

    func makeClientPairingSecret(
        clientSecret: Data,
        identity: ClientIdentityMaterial
    ) throws -> Data {
        guard clientSecret.count == 16 else {
            throw PairingCryptoError.invalidSecret
        }
        let privateKey = try importPrivateKey(identity.privateKeyDER)
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            clientSecret as CFData,
            &error
        ) as Data? else {
            error?.release()
            throw PairingCryptoError.signingFailed
        }
        var pairingSecret = clientSecret
        pairingSecret.append(signature)
        return pairingSecret
    }

    func verifyServerPairingSecret(
        _ pairingSecret: Data,
        serverCertificateDER: Data
    ) throws -> Data {
        guard pairingSecret.count > 16 else {
            throw PairingCryptoError.invalidSecret
        }
        let secret = Data(pairingSecret.prefix(16))
        let signature = Data(pairingSecret.dropFirst(16))
        guard let certificate = SecCertificateCreateWithData(
            nil,
            serverCertificateDER as CFData
        ), let publicKey = SecCertificateCopyKey(certificate) else {
            throw PairingCryptoError.invalidCertificate
        }
        var error: Unmanaged<CFError>?
        guard SecKeyVerifySignature(
            publicKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            secret as CFData,
            signature as CFData,
            &error
        ) else {
            error?.release()
            throw PairingCryptoError.signatureVerificationFailed
        }
        return secret
    }

    private func randomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw PairingCryptoError.randomGenerationFailed(status)
        }
        return Data(bytes)
    }

    private func cryptAES128ECB(
        _ input: Data,
        key: Data,
        operation: CCOperation
    ) throws -> Data {
        guard key.count == kCCKeySizeAES128 else {
            throw PairingCryptoError.invalidAESKey
        }
        guard !input.isEmpty, input.count.isMultiple(of: kCCBlockSizeAES128) else {
            throw PairingCryptoError.invalidBlockLength
        }

        let inputBytes = [UInt8](input)
        let keyBytes = [UInt8](key)
        var output = [UInt8](repeating: 0, count: input.count)
        let outputCapacity = output.count
        var outputLength = 0
        let status = keyBytes.withUnsafeBytes { keyBuffer in
            inputBytes.withUnsafeBytes { inputBuffer in
                output.withUnsafeMutableBytes { outputBuffer in
                    CCCrypt(
                        operation,
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode),
                        keyBuffer.baseAddress,
                        keyBytes.count,
                        nil,
                        inputBuffer.baseAddress,
                        inputBytes.count,
                        outputBuffer.baseAddress,
                        outputCapacity,
                        &outputLength
                    )
                }
            }
        }
        guard status == kCCSuccess, outputLength == input.count else {
            throw PairingCryptoError.aesFailure(status)
        }
        return Data(output.prefix(outputLength))
    }

    private func importPrivateKey(_ data: Data) throws -> SecKey {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits: 2_048
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateWithData(
            data as CFData,
            attributes as CFDictionary,
            &error
        ) else {
            error?.release()
            throw PairingCryptoError.privateKeyParsingFailed
        }
        return privateKey
    }

    private func constantTimeEqual(_ lhs: Data, _ rhs: Data) -> Bool {
        guard lhs.count == rhs.count else { return false }
        var difference: UInt8 = 0
        for (left, right) in zip(lhs, rhs) {
            difference |= left ^ right
        }
        return difference == 0
    }
}

private extension Data {
    func prefixData(_ count: Int) -> Data {
        Data(prefix(count))
    }
}
