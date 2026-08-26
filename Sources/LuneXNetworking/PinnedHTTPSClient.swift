import Foundation
import Security

enum PinnedTransportError: Error, Equatable, Sendable {
    case missingPinnedIdentity
    case invalidPinnedCertificate
    case certificateMismatch
    case missingClientIdentity
    case invalidClientIdentity
}

enum PinnedCertificateValidator {
    static func normalizedDER(_ certificateData: Data) -> Data? {
        guard !certificateData.isEmpty else { return nil }
        guard let pem = String(data: certificateData, encoding: .utf8),
              pem.contains("-----BEGIN CERTIFICATE-----")
        else {
            return certificateData
        }

        let base64 = pem
            .replacingOccurrences(of: "-----BEGIN CERTIFICATE-----", with: "")
            .replacingOccurrences(of: "-----END CERTIFICATE-----", with: "")
            .filter { !$0.isWhitespace }
        return Data(base64Encoded: String(base64))
    }

    static func matches(expectedLeafDER: Data, presentedLeafDER: Data?) -> Bool {
        guard let expected = normalizedDER(expectedLeafDER),
              let presentedLeafDER,
              let presented = normalizedDER(presentedLeafDER)
        else { return false }
        return expected == presented
    }
}

protocol PinnedHTTPSRequestExecuting: Sendable {
    func data(for request: URLRequest, pinnedIdentity: PinnedHostIdentity?) async throws -> (Data, URLResponse)
}

struct PinnedHTTPSRequestExecutor: PinnedHTTPSRequestExecuting {
    private let clientIdentityStore: any ClientIdentityStore
    private let clientIdentityValidator: any ClientIdentityValidating

    init(
        clientIdentityStore: any ClientIdentityStore = ClientIdentityStoreFactory.makeDefault(),
        clientIdentityValidator: any ClientIdentityValidating = SecurityClientIdentityValidator()
    ) {
        self.clientIdentityStore = clientIdentityStore
        self.clientIdentityValidator = clientIdentityValidator
    }

    func data(for request: URLRequest, pinnedIdentity: PinnedHostIdentity?) async throws -> (Data, URLResponse) {
        guard let pinnedIdentity else {
            throw PinnedTransportError.missingPinnedIdentity
        }
        guard let expectedLeafDER = PinnedCertificateValidator.normalizedDER(
            pinnedIdentity.serverCertificateDER
        ) else {
            throw PinnedTransportError.invalidPinnedCertificate
        }

        let clientIdentity: ClientIdentityMaterial
        do {
            guard let storedIdentity = try await clientIdentityStore.loadIdentity() else {
                throw PinnedTransportError.missingClientIdentity
            }
            try clientIdentityValidator.validate(storedIdentity)
            clientIdentity = storedIdentity
        } catch let error as PinnedTransportError {
            throw error
        } catch {
            throw PinnedTransportError.invalidClientIdentity
        }

        let delegate: PinnedCertificateSessionDelegate
        do {
            delegate = try PinnedCertificateSessionDelegate(
                expectedLeafDER: expectedLeafDER,
                clientIdentity: clientIdentity
            )
        } catch {
            throw PinnedTransportError.invalidClientIdentity
        }
        let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        do {
            return try await session.data(for: request)
        } catch {
            if let transportError = delegate.transportError {
                throw transportError
            }
            throw error
        }
    }
}

final class PinnedCertificateSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let expectedLeafDER: Data
    private let identity: SecIdentity
    private let certificate: SecCertificate
    private let lock = NSLock()
    private var recordedTransportError: PinnedTransportError?

    var transportError: PinnedTransportError? {
        lock.withLock { recordedTransportError }
    }

    init(
        expectedLeafDER: Data,
        clientIdentity: ClientIdentityMaterial
    ) throws {
        self.expectedLeafDER = expectedLeafDER
        let tlsIdentity = try PairingTLSIdentityFactory.make(clientIdentity)
        identity = tlsIdentity.identity
        certificate = tlsIdentity.certificate
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            handleServerTrust(challenge, completionHandler: completionHandler)
        case NSURLAuthenticationMethodClientCertificate:
            completionHandler(.useCredential, clientCredential())
        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }

    private func handleServerTrust(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard let trust = challenge.protectionSpace.serverTrust,
              let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
              let leaf = chain.first
        else {
            record(.invalidPinnedCertificate)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        let presentedLeafDER = SecCertificateCopyData(leaf) as Data
        guard PinnedCertificateValidator.matches(
            expectedLeafDER: expectedLeafDER,
            presentedLeafDER: presentedLeafDER
        ) else {
            record(.certificateMismatch)
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }

        completionHandler(.useCredential, URLCredential(trust: trust))
    }

    func clientCredential() -> URLCredential {
        URLCredential(
            identity: identity,
            certificates: [certificate],
            persistence: .forSession
        )
    }

    private func record(_ error: PinnedTransportError) {
        lock.withLock {
            recordedTransportError = error
        }
    }
}
