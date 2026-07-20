import Foundation
import XCTest

final class PairingCryptoTests: XCTestCase {
    func testVersionAwareHashKeyAndAESMatchIndependentVectors() throws {
        for vector in try loadVectors() {
            let crypto = try MoonlightPairingCrypto(
                serverMajorVersion: vector.serverMajorVersion
            )
            let salt = try decodeHex(vector.salt)
            let challenge = try decodeHex(vector.challenge)
            let expectedKey = try decodeHex(vector.aesKey)

            XCTAssertEqual(crypto.digestAlgorithm.rawValue, vector.digest)
            XCTAssertEqual(try crypto.deriveAESKey(salt: salt, pin: vector.inputCode), expectedKey)
            XCTAssertEqual(
                try crypto.digest(salt + Data(vector.inputCode.utf8)),
                try decodeHex(vector.derivedDigest)
            )
            XCTAssertEqual(
                try crypto.encryptClientChallenge(challenge, aesKey: expectedKey),
                try decodeHex(vector.encryptedChallenge)
            )
            XCTAssertEqual(
                try crypto.decryptAES128ECB(
                    try decodeHex(vector.encryptedChallenge),
                    aesKey: expectedKey
                ),
                challenge
            )
        }
    }

    func testChallengeResponseMatchesIndependentSHA1AndSHA256Vectors() throws {
        for vector in try loadVectors() {
            let crypto = try MoonlightPairingCrypto(
                serverMajorVersion: vector.serverMajorVersion
            )
            let aesKey = try decodeHex(vector.aesKey)
            let serverChallenge = try decodeHex(vector.serverChallenge)
            let certificateSignature = try decodeHex(vector.clientCertificateSignature)
            let clientNonce = try decodeHex(vector.clientNonce)
            XCTAssertEqual(
                try crypto.digest(serverChallenge + certificateSignature + clientNonce),
                try decodeHex(vector.challengeResponseDigest)
            )
            let encrypted = try crypto.makeEncryptedChallengeResponse(
                serverChallenge: serverChallenge,
                clientCertificateSignature: certificateSignature,
                clientSecret: clientNonce,
                aesKey: aesKey
            )

            XCTAssertEqual(encrypted, try decodeHex(vector.encryptedChallengeResponse))
            XCTAssertEqual(
                try crypto.decryptAES128ECB(encrypted, aesKey: aesKey),
                try decodeHex(vector.paddedChallengeResponse)
            )
        }
    }

    func testClientAndServerPairingSecretSignaturesRoundTrip() throws {
        let crypto = try MoonlightPairingCrypto(serverMajorVersion: 7)
        let identity = try SecurityClientIdentityGenerator().generateIdentity(
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let secret = Data((0..<16).map(UInt8.init))

        let pairingSecret = try crypto.makeClientPairingSecret(
            clientSecret: secret,
            identity: identity
        )
        XCTAssertEqual(
            try crypto.verifyServerPairingSecret(
                pairingSecret,
                serverCertificateDER: identity.certificateDER
            ),
            secret
        )

        var mutated = pairingSecret
        mutated[mutated.index(before: mutated.endIndex)] ^= 0x01
        XCTAssertThrowsError(
            try crypto.verifyServerPairingSecret(
                mutated,
                serverCertificateDER: identity.certificateDER
            )
        ) { error in
            XCTAssertEqual(error as? PairingCryptoError, .signatureVerificationFailed)
        }
    }

    func testServerResponseVerificationUsesCertificateSignatureAndConstantTimeMatch() throws {
        let crypto = try MoonlightPairingCrypto(serverMajorVersion: 7)
        let identity = try SecurityClientIdentityGenerator().generateIdentity(
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let clientChallenge = Data(repeating: 0x11, count: 16)
        let serverSecret = Data(repeating: 0x22, count: 16)
        let certificateSignature = try crypto.certificateSignature(
            certificateDER: identity.certificateDER
        )
        let responseHash = try crypto.digest(
            clientChallenge + certificateSignature + serverSecret
        )

        XCTAssertNoThrow(try crypto.verifyServerResponse(
            responseHash: responseHash,
            clientChallenge: clientChallenge,
            serverCertificateSignature: certificateSignature,
            serverSecret: serverSecret
        ))

        var mismatched = responseHash
        mismatched[mismatched.startIndex] ^= 0x01
        XCTAssertThrowsError(try crypto.verifyServerResponse(
            responseHash: mismatched,
            clientChallenge: clientChallenge,
            serverCertificateSignature: certificateSignature,
            serverSecret: serverSecret
        )) { error in
            XCTAssertEqual(error as? PairingCryptoError, .responseMismatch)
        }
    }

    func testRandomAndMalformedInputBoundaries() throws {
        let crypto = try MoonlightPairingCrypto(serverMajorVersion: 7)
        let firstSalt = try crypto.generateSalt()
        let secondSalt = try crypto.generateSalt()
        XCTAssertEqual(firstSalt.count, 16)
        XCTAssertEqual(secondSalt.count, 16)
        XCTAssertNotEqual(firstSalt, secondSalt)
        XCTAssertEqual(try crypto.generateNonce().count, 16)

        XCTAssertThrowsError(try crypto.deriveAESKey(salt: Data(count: 15), pin: "1234"))
        XCTAssertThrowsError(try crypto.deriveAESKey(salt: Data(count: 16), pin: "１２３４"))
        XCTAssertThrowsError(
            try crypto.encryptClientChallenge(Data(count: 15), aesKey: Data(count: 16))
        )
        XCTAssertThrowsError(
            try crypto.decryptAES128ECB(Data(count: 17), aesKey: Data(count: 16))
        )
    }

    private func loadVectors() throws -> [PairingCryptoVector] {
        let testDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        let fixtureURL = testDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/pairing/crypto-vectors.json")
        let fixture = try JSONDecoder().decode(
            PairingCryptoFixture.self,
            from: Data(contentsOf: fixtureURL)
        )
        XCTAssertEqual(fixture.schemaVersion, 1)
        return fixture.vectors
    }

    private func decodeHex(_ value: String) throws -> Data {
        let compact = value.replacingOccurrences(of: " ", with: "")
        guard compact.count.isMultiple(of: 2) else {
            throw PairingCryptoTestError.invalidHex
        }
        var data = Data()
        var index = compact.startIndex
        while index < compact.endIndex {
            let next = compact.index(index, offsetBy: 2)
            guard let byte = UInt8(compact[index..<next], radix: 16) else {
                throw PairingCryptoTestError.invalidHex
            }
            data.append(byte)
            index = next
        }
        return data
    }
}

private struct PairingCryptoFixture: Decodable {
    var schemaVersion: Int
    var vectors: [PairingCryptoVector]
}

private struct PairingCryptoVector: Decodable {
    var aesKey: String
    var challenge: String
    var challengeResponseDigest: String
    var clientCertificateSignature: String
    var clientNonce: String
    var derivedDigest: String
    var digest: String
    var encryptedChallenge: String
    var encryptedChallengeResponse: String
    var inputCode: String
    var paddedChallengeResponse: String
    var salt: String
    var serverChallenge: String
    var serverMajorVersion: Int
}

private enum PairingCryptoTestError: Error {
    case invalidHex
}
