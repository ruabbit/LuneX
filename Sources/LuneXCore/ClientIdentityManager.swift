import Foundation
import Security

protocol ClientIdentityValidating: Sendable {
    func validate(_ identity: ClientIdentityMaterial) throws
}

enum ClientIdentityValidationError: Error, Equatable {
    case certificateParsingFailed
    case certificateSubjectMismatch
    case certificateStructureInvalid
    case certificateSignatureInvalid
    case certificateTrustSetupFailed(OSStatus)
    case certificateTrustFailed
    case certificatePublicKeyUnavailable
    case privateKeyParsingFailed
    case privateKeyAttributesUnavailable
    case invalidPrivateKeyType
    case invalidPrivateKeySize
    case publicKeyUnavailable
    case publicKeyExportFailed
    case publicKeyMismatch
    case challengeSigningFailed
    case challengeVerificationFailed
}

struct SecurityClientIdentityValidator: ClientIdentityValidating {
    func validate(_ identity: ClientIdentityMaterial) throws {
        guard let certificate = SecCertificateCreateWithData(
            nil,
            identity.certificateDER as CFData
        ) else {
            throw ClientIdentityValidationError.certificateParsingFailed
        }
        guard SecCertificateCopySubjectSummary(certificate) as String?
            == SecurityClientIdentityGenerator.sunshineCommonName else {
            throw ClientIdentityValidationError.certificateSubjectMismatch
        }
        guard let certificatePublicKey = SecCertificateCopyKey(certificate) else {
            throw ClientIdentityValidationError.certificatePublicKeyUnavailable
        }
        try validateCertificateSignature(identity.certificateDER, publicKey: certificatePublicKey)
        try validateSelfSignedTrust(certificate, verifyAt: identity.createdAt.addingTimeInterval(1))
        let privateKey = try importPrivateKey(identity.privateKeyDER)
        try validatePrivateKeyAttributes(privateKey)
        guard let privatePublicKey = SecKeyCopyPublicKey(privateKey) else {
            throw ClientIdentityValidationError.publicKeyUnavailable
        }
        guard try externalRepresentation(certificatePublicKey)
            == externalRepresentation(privatePublicKey) else {
            throw ClientIdentityValidationError.publicKeyMismatch
        }
        try validateChallengeSignature(privateKey: privateKey, publicKey: certificatePublicKey)
    }

    private func validateCertificateSignature(_ der: Data, publicKey: SecKey) throws {
        let envelope: X509CertificateEnvelope
        do {
            envelope = try X509CertificateEnvelope.parse(der)
        } catch {
            throw ClientIdentityValidationError.certificateStructureInvalid
        }
        var error: Unmanaged<CFError>?
        guard SecKeyVerifySignature(
            publicKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            envelope.toBeSigned as CFData,
            envelope.signature as CFData,
            &error
        ) else {
            error?.release()
            throw ClientIdentityValidationError.certificateSignatureInvalid
        }
    }

    private func validateSelfSignedTrust(_ certificate: SecCertificate, verifyAt: Date) throws {
        var trust: SecTrust?
        let createStatus = SecTrustCreateWithCertificates(
            certificate,
            SecPolicyCreateBasicX509(),
            &trust
        )
        guard createStatus == errSecSuccess, let trust else {
            throw ClientIdentityValidationError.certificateTrustSetupFailed(createStatus)
        }
        let anchorStatus = SecTrustSetAnchorCertificates(trust, [certificate] as CFArray)
        guard anchorStatus == errSecSuccess else {
            throw ClientIdentityValidationError.certificateTrustSetupFailed(anchorStatus)
        }
        let anchorOnlyStatus = SecTrustSetAnchorCertificatesOnly(trust, true)
        guard anchorOnlyStatus == errSecSuccess else {
            throw ClientIdentityValidationError.certificateTrustSetupFailed(anchorOnlyStatus)
        }
        let networkStatus = SecTrustSetNetworkFetchAllowed(trust, false)
        guard networkStatus == errSecSuccess else {
            throw ClientIdentityValidationError.certificateTrustSetupFailed(networkStatus)
        }
        let dateStatus = SecTrustSetVerifyDate(trust, verifyAt as CFDate)
        guard dateStatus == errSecSuccess else {
            throw ClientIdentityValidationError.certificateTrustSetupFailed(dateStatus)
        }

        var error: CFError?
        guard SecTrustEvaluateWithError(trust, &error) else {
            throw ClientIdentityValidationError.certificateTrustFailed
        }
    }

    private func importPrivateKey(_ data: Data) throws -> SecKey {
        let attributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits: 2_048
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(
            data as CFData,
            attributes as CFDictionary,
            &error
        ) else {
            error?.release()
            throw ClientIdentityValidationError.privateKeyParsingFailed
        }
        return key
    }

    private func validatePrivateKeyAttributes(_ key: SecKey) throws {
        guard let attributes = SecKeyCopyAttributes(key) as NSDictionary? else {
            throw ClientIdentityValidationError.privateKeyAttributesUnavailable
        }
        guard attributes[kSecAttrKeyType] as? String == kSecAttrKeyTypeRSA as String else {
            throw ClientIdentityValidationError.invalidPrivateKeyType
        }
        guard attributes[kSecAttrKeySizeInBits] as? Int == 2_048 else {
            throw ClientIdentityValidationError.invalidPrivateKeySize
        }
    }

    private func externalRepresentation(_ key: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            error?.release()
            throw ClientIdentityValidationError.publicKeyExportFailed
        }
        return data
    }

    private func validateChallengeSignature(privateKey: SecKey, publicKey: SecKey) throws {
        let challenge = Data("LuneX persisted identity validation".utf8)
        var error: Unmanaged<CFError>?
        guard let signature = SecKeyCreateSignature(
            privateKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            challenge as CFData,
            &error
        ) as Data? else {
            error?.release()
            throw ClientIdentityValidationError.challengeSigningFailed
        }
        error = nil
        guard SecKeyVerifySignature(
            publicKey,
            .rsaSignatureMessagePKCS1v15SHA256,
            challenge as CFData,
            signature as CFData,
            &error
        ) else {
            error?.release()
            throw ClientIdentityValidationError.challengeVerificationFailed
        }
    }
}

enum ClientIdentityManagerError: Error, Equatable {
    case persistenceReloadMissing
    case persistenceReloadMismatch
}

protocol ClientIdentityProvisioning: Sendable {
    func loadOrCreateIdentity(createdAt: Date) async throws -> ClientIdentityMaterial
}

actor ClientIdentityManager: ClientIdentityProvisioning {
    private let store: any ClientIdentityStore
    private let generator: any ClientIdentityGenerating
    private let validator: any ClientIdentityValidating

    init(
        store: any ClientIdentityStore,
        generator: any ClientIdentityGenerating = SecurityClientIdentityGenerator(),
        validator: any ClientIdentityValidating = SecurityClientIdentityValidator()
    ) {
        self.store = store
        self.generator = generator
        self.validator = validator
    }

    func loadOrCreateIdentity(createdAt: Date = Date()) async throws -> ClientIdentityMaterial {
        if let existing = try await store.loadIdentity() {
            try validator.validate(existing)
            return existing
        }

        let generated = try generator.generateIdentity(createdAt: createdAt)
        try validator.validate(generated)
        do {
            try await store.saveIdentity(generated)
            guard let reloaded = try await store.loadIdentity() else {
                throw ClientIdentityManagerError.persistenceReloadMissing
            }
            guard reloaded == generated else {
                throw ClientIdentityManagerError.persistenceReloadMismatch
            }
            try validator.validate(reloaded)
            return reloaded
        } catch {
            try? await store.deleteIdentity()
            throw error
        }
    }

    func resetIdentity() async throws {
        try await store.deleteIdentity()
    }
}
