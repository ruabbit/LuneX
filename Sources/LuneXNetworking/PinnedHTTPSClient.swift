import Foundation
import Security

enum PinnedTransportError: Error, Equatable, Sendable {
    case missingPinnedIdentity
    case invalidPinnedCertificate
    case certificateMismatch
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
    func data(for request: URLRequest, pinnedIdentity: PinnedHostIdentity?) async throws -> (Data, URLResponse) {
        guard let pinnedIdentity else {
            throw PinnedTransportError.missingPinnedIdentity
        }
        guard let expectedLeafDER = PinnedCertificateValidator.normalizedDER(
            pinnedIdentity.serverCertificateDER
        ) else {
            throw PinnedTransportError.invalidPinnedCertificate
        }

        let delegate = PinnedCertificateSessionDelegate(expectedLeafDER: expectedLeafDER)
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
    private let lock = NSLock()
    private var recordedTransportError: PinnedTransportError?

    var transportError: PinnedTransportError? {
        lock.withLock { recordedTransportError }
    }

    init(expectedLeafDER: Data) {
        self.expectedLeafDER = expectedLeafDER
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }

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

    private func record(_ error: PinnedTransportError) {
        lock.withLock {
            recordedTransportError = error
        }
    }
}
