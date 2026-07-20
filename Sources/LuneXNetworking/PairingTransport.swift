import CommonCrypto
import Foundation
import Security

enum PairingTransportStage: String, Equatable, Sendable {
    case serverInfo
    case serverCertificate
    case clientChallenge
    case serverChallengeResponse
    case clientPairingSecret
    case pairChallenge
}

enum PairingTransportError: Error, Equatable, Sendable {
    case invalidEndpoint
    case invalidRequest
    case invalidResponse(PairingTransportStage)
    case serverRejected(PairingTransportStage)
    case responseTooLarge
    case invalidHex
    case invalidServerVersion
    case invalidServerCertificate
    case missingTemporaryPin
    case clientIdentityCreationFailed
    case certificateMismatch
}

protocol PairingRequestExecuting: Sendable {
    func data(
        for request: URLRequest,
        expectedServerLeafDER: Data?,
        clientIdentity: ClientIdentityMaterial?
    ) async throws -> (Data, URLResponse)
}

struct URLSessionPairingRequestExecutor: PairingRequestExecuting {
    private static let maximumResponseSize = 1_048_576

    func data(
        for request: URLRequest,
        expectedServerLeafDER: Data?,
        clientIdentity: ClientIdentityMaterial?
    ) async throws -> (Data, URLResponse) {
        guard let scheme = request.url?.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw PairingTransportError.invalidRequest
        }
        let session: URLSession
        let delegate: PairingMutualTLSSessionDelegate?
        if scheme == "https" {
            guard let expectedServerLeafDER else {
                throw PairingTransportError.missingTemporaryPin
            }
            guard let clientIdentity else {
                throw PairingTransportError.clientIdentityCreationFailed
            }
            let createdDelegate = try PairingMutualTLSSessionDelegate(
                expectedServerLeafDER: expectedServerLeafDER,
                clientIdentity: clientIdentity
            )
            delegate = createdDelegate
            session = URLSession(
                configuration: .ephemeral,
                delegate: createdDelegate,
                delegateQueue: nil
            )
        } else {
            delegate = nil
            session = URLSession(configuration: .ephemeral)
        }
        defer { session.finishTasksAndInvalidate() }

        do {
            let result = try await session.data(for: request)
            guard result.0.count <= Self.maximumResponseSize else {
                throw PairingTransportError.responseTooLarge
            }
            return result
        } catch {
            if delegate?.transportError == .certificateMismatch {
                throw PairingTransportError.certificateMismatch
            }
            throw error
        }
    }
}

private final class PairingMutualTLSSessionDelegate: NSObject, URLSessionDelegate, @unchecked Sendable {
    private let expectedServerLeafDER: Data
    private let identity: SecIdentity
    private let certificate: SecCertificate
    private let lock = NSLock()
    private var recordedTransportError: PairingTransportError?

    var transportError: PairingTransportError? {
        lock.withLock { recordedTransportError }
    }

    init(
        expectedServerLeafDER: Data,
        clientIdentity: ClientIdentityMaterial
    ) throws {
        guard let normalizedServerDER = PinnedCertificateValidator.normalizedDER(
            expectedServerLeafDER
        ) else {
            throw PairingTransportError.invalidServerCertificate
        }
        let tlsIdentity = try PairingTLSIdentityFactory.make(clientIdentity)

        self.expectedServerLeafDER = normalizedServerDER
        self.identity = tlsIdentity.identity
        self.certificate = tlsIdentity.certificate
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        switch challenge.protectionSpace.authenticationMethod {
        case NSURLAuthenticationMethodServerTrust:
            guard let trust = challenge.protectionSpace.serverTrust,
                  let chain = SecTrustCopyCertificateChain(trust) as? [SecCertificate],
                  let leaf = chain.first,
                  PinnedCertificateValidator.matches(
                      expectedLeafDER: expectedServerLeafDER,
                      presentedLeafDER: SecCertificateCopyData(leaf) as Data
                  ) else {
                record(.certificateMismatch)
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }
            completionHandler(.useCredential, URLCredential(trust: trust))
        case NSURLAuthenticationMethodClientCertificate:
            completionHandler(
                .useCredential,
                URLCredential(
                    identity: identity,
                    certificates: [certificate],
                    persistence: .forSession
                )
            )
        default:
            completionHandler(.performDefaultHandling, nil)
        }
    }

    private func record(_ error: PairingTransportError) {
        lock.withLock { recordedTransportError = error }
    }
}

struct PairingTLSIdentity {
    let identity: SecIdentity
    let certificate: SecCertificate
}

enum PairingTLSIdentityFactory {
    static func make(_ material: ClientIdentityMaterial) throws -> PairingTLSIdentity {
        guard let certificate = SecCertificateCreateWithData(
            nil,
            material.certificateDER as CFData
        ) else {
            throw PairingTransportError.clientIdentityCreationFailed
        }
        let keyAttributes: [CFString: Any] = [
            kSecAttrKeyType: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits: 2_048
        ]
        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateWithData(
            material.privateKeyDER as CFData,
            keyAttributes as CFDictionary,
            &error
        ) else {
            error?.release()
            throw PairingTransportError.clientIdentityCreationFailed
        }
        guard let identity = SecIdentityCreate(nil, certificate, privateKey) else {
            throw PairingTransportError.clientIdentityCreationFailed
        }
        return PairingTLSIdentity(identity: identity, certificate: certificate)
    }
}

struct PairingXMLResponse: Equatable, Sendable {
    var statusCode: Int
    var statusMessage: String?
    var paired: Bool?
    var values: [String: String]
}

enum PairingXMLParser {
    static func parse(_ data: Data, stage: PairingTransportStage) throws -> PairingXMLResponse {
        guard !data.isEmpty, data.count <= 1_048_576 else {
            throw PairingTransportError.invalidResponse(stage)
        }
        let parser = XMLParser(data: data)
        let delegate = PairingXMLDelegate()
        parser.delegate = delegate
        guard parser.parse(), let statusCode = delegate.statusCode else {
            throw PairingTransportError.invalidResponse(stage)
        }
        return PairingXMLResponse(
            statusCode: statusCode,
            statusMessage: delegate.statusMessage,
            paired: delegate.paired,
            values: delegate.values
        )
    }
}

private final class PairingXMLDelegate: NSObject, XMLParserDelegate {
    private var currentElement: String?
    private var currentText = ""
    private(set) var statusCode: Int?
    private(set) var statusMessage: String?
    private(set) var values: [String: String] = [:]

    var paired: Bool? {
        guard let value = values["paired"] else { return nil }
        if value == "1" { return true }
        if value == "0" { return false }
        return nil
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let key = elementName.lowercased()
        currentElement = key
        currentText = ""
        if key == "root" {
            statusCode = attributeDict["status_code"].flatMap(Int.init)
            statusMessage = attributeDict["status_message"]
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let key = elementName.lowercased()
        let value = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !value.isEmpty {
            values[key] = value
        }
        currentElement = nil
        currentText = ""
    }
}

actor MoonlightPairingProvider: PairingRuntimeProvider {
    private struct Attempt {
        var token: UUID
        var task: Task<Void, Never>
    }

    private let executor: any PairingRequestExecuting
    private let now: @Sendable () -> Date
    private var attempts: [UUID: Attempt] = [:]

    init(
        executor: any PairingRequestExecuting = URLSessionPairingRequestExecutor(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.executor = executor
        self.now = now
    }

    func pair(
        _ request: PairingRuntimeRequest
    ) async -> AsyncThrowingStream<PairingRuntimeEvent, Error> {
        attempts.removeValue(forKey: request.attemptID)?.task.cancel()
        let token = UUID()
        return AsyncThrowingStream { continuation in
            let task = Task {
                await self.runPairing(
                    request,
                    token: token,
                    continuation: continuation
                )
            }
            attempts[request.attemptID] = Attempt(token: token, task: task)
            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.cancelPairing(
                        attemptID: request.attemptID,
                        expectedToken: token
                    )
                }
            }
        }
    }

    func cancelPairing(attemptID: UUID) async {
        attempts.removeValue(forKey: attemptID)?.task.cancel()
    }

    func activeAttemptCount() -> Int {
        attempts.count
    }

    private func runPairing(
        _ request: PairingRuntimeRequest,
        token: UUID,
        continuation: AsyncThrowingStream<PairingRuntimeEvent, Error>.Continuation
    ) async {
        let stateMachine = PairingStateMachine(
            attemptID: request.attemptID,
            hostID: request.host.id,
            now: now()
        )
        do {
            let endpoint = try HostEndpointParser.parse(request.host.address)
            let serverInfo = try await fetchServerInfo(endpoint: endpoint)
            let serverMajorVersion = try parseServerMajorVersion(serverInfo)
            let httpsPort = parseHTTPSPort(serverInfo) ?? HostEndpoint.defaultHTTPSPort
            let crypto = try MoonlightPairingCrypto(serverMajorVersion: serverMajorVersion)

            continuation.yield(.progress(await stateMachine.begin(
                serverMajorVersion: serverMajorVersion,
                now: now()
            )))
            continuation.yield(.progress(try await stateMachine.submitPIN(
                request.pin,
                now: now()
            )))

            let salt = try crypto.generateSalt()
            let getCertificate = try makePairRequest(
                endpoint: endpoint,
                identity: request.clientIdentity,
                parameters: [
                    "phrase": "getservercert",
                    "salt": salt.hexString,
                    "clientcert": Self.pemCertificate(request.clientIdentity.certificateDER).hexString
                ],
                timeout: 180
            )
            let certificateResponse = try await perform(
                getCertificate,
                stage: .serverCertificate
            )
            guard certificateResponse.paired == true,
                  let plainCertificate = certificateResponse.values["plaincert"],
                  let serverCertificatePEM = Data(hexString: plainCertificate),
                  let serverCertificateDER = PinnedCertificateValidator.normalizedDER(
                      serverCertificatePEM
                  ),
                  SecCertificateCreateWithData(nil, serverCertificateDER as CFData) != nil else {
                throw PairingTransportError.invalidServerCertificate
            }

            let aesKey = try crypto.deriveAESKey(salt: salt, pin: request.pin)
            let clientChallenge = try crypto.generateNonce()
            let encryptedChallenge = try crypto.encryptClientChallenge(
                clientChallenge,
                aesKey: aesKey
            )
            let challengeResponse = try await perform(
                makePairRequest(
                    endpoint: endpoint,
                    identity: request.clientIdentity,
                    parameters: ["clientchallenge": encryptedChallenge.hexString]
                ),
                stage: .clientChallenge
            )
            guard challengeResponse.paired == true,
                  let encryptedServerValue = challengeResponse.values["challengeresponse"],
                  let encryptedServerResponse = Data(hexString: encryptedServerValue) else {
                throw PairingTransportError.invalidResponse(.clientChallenge)
            }
            let serverChallengeMaterial = try crypto.decryptServerChallengeResponse(
                encryptedServerResponse,
                aesKey: aesKey
            )

            let clientSecret = try crypto.generateNonce()
            let clientCertificateSignature = try crypto.certificateSignature(
                certificateDER: request.clientIdentity.certificateDER
            )
            let encryptedResponse = try crypto.makeEncryptedChallengeResponse(
                serverChallenge: serverChallengeMaterial.serverChallenge,
                clientCertificateSignature: clientCertificateSignature,
                clientSecret: clientSecret,
                aesKey: aesKey
            )
            let serverSecretResponse = try await perform(
                makePairRequest(
                    endpoint: endpoint,
                    identity: request.clientIdentity,
                    parameters: ["serverchallengeresp": encryptedResponse.hexString]
                ),
                stage: .serverChallengeResponse
            )
            guard serverSecretResponse.paired == true,
                  let pairingSecretValue = serverSecretResponse.values["pairingsecret"],
                  let pairingSecret = Data(hexString: pairingSecretValue) else {
                throw PairingTransportError.invalidResponse(.serverChallengeResponse)
            }
            let serverSecret = try crypto.verifyServerPairingSecret(
                pairingSecret,
                serverCertificateDER: serverCertificateDER
            )
            try crypto.verifyServerResponse(
                responseHash: serverChallengeMaterial.responseHash,
                clientChallenge: clientChallenge,
                serverCertificateSignature: try crypto.certificateSignature(
                    certificateDER: serverCertificateDER
                ),
                serverSecret: serverSecret
            )
            continuation.yield(.progress(try await stateMachine.markSecretsExchanged(now: now())))

            let clientPairingSecret = try crypto.makeClientPairingSecret(
                clientSecret: clientSecret,
                identity: request.clientIdentity
            )
            let clientSecretResponse = try await perform(
                makePairRequest(
                    endpoint: endpoint,
                    identity: request.clientIdentity,
                    parameters: ["clientpairingsecret": clientPairingSecret.hexString]
                ),
                stage: .clientPairingSecret
            )
            guard clientSecretResponse.paired == true else {
                throw PairingTransportError.serverRejected(.clientPairingSecret)
            }

            let pairChallengeRequest = try makePairRequest(
                endpoint: HostEndpoint(host: endpoint.host, port: httpsPort),
                identity: request.clientIdentity,
                parameters: ["phrase": "pairchallenge"],
                scheme: "https"
            )
            let finalResponse = try await perform(
                pairChallengeRequest,
                stage: .pairChallenge,
                expectedServerLeafDER: serverCertificateDER,
                clientIdentity: request.clientIdentity
            )
            guard finalResponse.paired == true else {
                throw PairingTransportError.serverRejected(.pairChallenge)
            }

            let sha256 = try MoonlightPairingCrypto(serverMajorVersion: 7)
                .digest(serverCertificateDER)
                .hexString
            let serverIdentity = PairingServerIdentity(
                certificateDER: serverCertificateDER,
                certificateSHA256: sha256,
                serverMajorVersion: serverMajorVersion
            )
            let result = try await stateMachine.pinServerIdentity(
                serverIdentity,
                for: request.host,
                pairedAt: now()
            )
            continuation.yield(.completed(result))
            continuation.finish()
        } catch is CancellationError {
            let failure = PairingFailure(
                code: .cancelled,
                message: "Pairing was cancelled."
            )
            continuation.yield(.progress(await stateMachine.cancel(now: now())))
            continuation.finish(throwing: failure)
        } catch {
            if Task.isCancelled {
                let failure = PairingFailure(
                    code: .cancelled,
                    message: "Pairing was cancelled."
                )
                continuation.yield(.progress(await stateMachine.cancel(now: now())))
                continuation.finish(throwing: failure)
                removeAttempt(request.attemptID, expectedToken: token)
                return
            }
            let code: PairingFailureCode = error as? PairingTransportError == .certificateMismatch
                ? .certificateMismatch
                : .transportFailed
            let failure = PairingFailure(
                code: code,
                message: "Authenticated pairing failed."
            )
            continuation.yield(.progress(await stateMachine.fail(failure, now: now())))
            continuation.finish(throwing: failure)
        }
        removeAttempt(request.attemptID, expectedToken: token)
    }

    private func cancelPairing(
        attemptID: UUID,
        expectedToken: UUID
    ) {
        guard attempts[attemptID]?.token == expectedToken else { return }
        attempts.removeValue(forKey: attemptID)?.task.cancel()
    }

    private func removeAttempt(
        _ attemptID: UUID,
        expectedToken: UUID
    ) {
        guard attempts[attemptID]?.token == expectedToken else { return }
        attempts.removeValue(forKey: attemptID)
    }

    private func fetchServerInfo(endpoint: HostEndpoint) async throws -> PairingXMLResponse {
        guard let url = endpoint.serverInfoURL else {
            throw PairingTransportError.invalidEndpoint
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        return try await perform(request, stage: .serverInfo)
    }

    private func perform(
        _ request: URLRequest,
        stage: PairingTransportStage,
        expectedServerLeafDER: Data? = nil,
        clientIdentity: ClientIdentityMaterial? = nil
    ) async throws -> PairingXMLResponse {
        try Task.checkCancellation()
        let (data, response) = try await executor.data(
            for: request,
            expectedServerLeafDER: expectedServerLeafDER,
            clientIdentity: clientIdentity
        )
        try Task.checkCancellation()
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw PairingTransportError.serverRejected(stage)
        }
        let parsed = try PairingXMLParser.parse(data, stage: stage)
        guard parsed.statusCode == 200 else {
            throw PairingTransportError.serverRejected(stage)
        }
        return parsed
    }

    private func makePairRequest(
        endpoint: HostEndpoint,
        identity: ClientIdentityMaterial,
        parameters: [String: String],
        scheme: String = "http",
        timeout: TimeInterval = 5
    ) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = scheme
        components.host = endpoint.host
        components.port = endpoint.port
        components.path = "/pair"
        var queryItems = [
            URLQueryItem(name: "uniqueid", value: Self.protocolUniqueID(identity.id)),
            URLQueryItem(name: "devicename", value: "LuneX"),
            URLQueryItem(name: "updateState", value: "1")
        ]
        queryItems.append(contentsOf: parameters.keys.sorted().map {
            URLQueryItem(name: $0, value: parameters[$0])
        })
        components.queryItems = queryItems
        guard let url = components.url else {
            throw PairingTransportError.invalidRequest
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        return request
    }

    private func parseServerMajorVersion(_ response: PairingXMLResponse) throws -> Int {
        guard let version = response.values["appversion"],
              let first = version.split(separator: ".").first,
              let major = Int(first), major > 0 else {
            throw PairingTransportError.invalidServerVersion
        }
        return major
    }

    private func parseHTTPSPort(_ response: PairingXMLResponse) -> Int? {
        guard let value = response.values["httpsport"],
              let port = Int(value), (1...65_535).contains(port) else {
            return nil
        }
        return port
    }

    private static func protocolUniqueID(_ id: UUID) -> String {
        String(id.uuidString.replacingOccurrences(of: "-", with: "").prefix(16)).uppercased()
    }

    private static func pemCertificate(_ der: Data) -> Data {
        let base64 = der.base64EncodedString()
        var lines: [String] = []
        var index = base64.startIndex
        while index < base64.endIndex {
            let end = base64.index(index, offsetBy: 64, limitedBy: base64.endIndex)
                ?? base64.endIndex
            lines.append(String(base64[index..<end]))
            index = end
        }
        return Data(([
            "-----BEGIN CERTIFICATE-----"
        ] + lines + [
            "-----END CERTIFICATE-----", ""
        ]).joined(separator: "\n").utf8)
    }
}

private extension Data {
    init?(hexString: String) {
        guard hexString.count.isMultiple(of: 2), hexString.count <= 131_072 else {
            return nil
        }
        var result = Data()
        result.reserveCapacity(hexString.count / 2)
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<next], radix: 16) else {
                return nil
            }
            result.append(byte)
            index = next
        }
        self = result
    }

    var hexString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
