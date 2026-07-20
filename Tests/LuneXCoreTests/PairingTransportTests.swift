import Foundation
import Network
import Security
import XCTest

final class PairingTransportTests: XCTestCase {
    func testGeneratedMaterialCreatesInMemoryTLSIdentityWithoutKeychain() throws {
        let material = try SecurityClientIdentityGenerator().generateIdentity(
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let tlsIdentity = try PairingTLSIdentityFactory.make(material)
        var copiedCertificate: SecCertificate?
        var copiedPrivateKey: SecKey?

        XCTAssertEqual(
            SecIdentityCopyCertificate(tlsIdentity.identity, &copiedCertificate),
            errSecSuccess
        )
        XCTAssertEqual(
            SecIdentityCopyPrivateKey(tlsIdentity.identity, &copiedPrivateKey),
            errSecSuccess
        )
        XCTAssertEqual(
            copiedCertificate.map { SecCertificateCopyData($0) as Data },
            material.certificateDER
        )
        guard let copiedPrivateKey,
              let copiedPublicKey = SecKeyCopyPublicKey(copiedPrivateKey),
              let certificatePublicKey = SecCertificateCopyKey(tlsIdentity.certificate) else {
            return XCTFail("Could not read back in-memory TLS identity keys")
        }
        XCTAssertEqual(
            try externalRepresentation(copiedPublicKey),
            try externalRepresentation(certificatePublicKey)
        )
    }

    func testProviderCompletesEveryAuthenticatedPairingStageWithTemporaryPin() async throws {
        let serverIdentity = try SecurityClientIdentityGenerator().generateIdentity(
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let clientIdentity = try SecurityClientIdentityGenerator().generateIdentity(
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let executor = SunshinePairingStub(serverIdentity: serverIdentity, pin: "1234")
        let provider = MoonlightPairingProvider(
            executor: executor,
            now: { Date(timeIntervalSince1970: 300) }
        )
        let request = makeRequest(identity: clientIdentity)

        var events: [PairingRuntimeEvent] = []
        let stream = await provider.pair(request)
        for try await event in stream {
            events.append(event)
        }

        let completed = events.compactMap { event -> PairingResult? in
            guard case let .completed(result) = event else { return nil }
            return result
        }
        XCTAssertEqual(completed.count, 1)
        XCTAssertEqual(completed[0].host.pairingState, .paired)
        XCTAssertTrue(events.allSatisfy { event in
            guard case let .progress(snapshot) = event else { return true }
            return snapshot.attemptID == request.attemptID
        })
        XCTAssertEqual(
            completed[0].host.pinnedIdentity?.serverCertificateDER,
            serverIdentity.certificateDER
        )
        XCTAssertEqual(completed[0].serverIdentity.serverMajorVersion, 7)

        let snapshot = await executor.snapshot()
        XCTAssertEqual(snapshot.requestStages, [
            "serverinfo",
            "getservercert",
            "clientchallenge",
            "serverchallengeresp",
            "clientpairingsecret",
            "pairchallenge"
        ])
        XCTAssertTrue(snapshot.clientSecretVerified)
        XCTAssertTrue(snapshot.finalRequestUsedTemporaryPin)
        XCTAssertTrue(snapshot.finalRequestUsedClientIdentity)
    }

    func testTemporaryPinMismatchFailsWithoutCompletion() async throws {
        let serverIdentity = try SecurityClientIdentityGenerator().generateIdentity(
            createdAt: Date(timeIntervalSince1970: 100)
        )
        let clientIdentity = try SecurityClientIdentityGenerator().generateIdentity(
            createdAt: Date(timeIntervalSince1970: 200)
        )
        let executor = SunshinePairingStub(
            serverIdentity: serverIdentity,
            pin: "1234",
            failFinalPin: true
        )
        let provider = MoonlightPairingProvider(executor: executor)

        var events: [PairingRuntimeEvent] = []
        do {
            let stream = await provider.pair(makeRequest(identity: clientIdentity))
            for try await event in stream {
                events.append(event)
            }
            XCTFail("Expected temporary pin mismatch")
        } catch let failure as PairingFailure {
            XCTAssertEqual(failure.code, .certificateMismatch)
        }

        XCTAssertFalse(events.contains { event in
            if case .completed = event { return true }
            return false
        })
        guard case let .progress(snapshot) = events.last else {
            return XCTFail("Expected failed progress snapshot")
        }
        XCTAssertEqual(snapshot.stage, .failed)
        XCTAssertEqual(snapshot.failure?.code, .certificateMismatch)
    }

    func testPairingXMLParserRejectsMalformedAndMissingStatus() throws {
        XCTAssertThrowsError(try PairingXMLParser.parse(
            Data("<root><paired>1</paired>".utf8),
            stage: .serverCertificate
        ))
        XCTAssertThrowsError(try PairingXMLParser.parse(
            Data("<root><paired>1</paired></root>".utf8),
            stage: .serverCertificate
        ))
        let parsed = try PairingXMLParser.parse(
            xml(["paired": "0"], statusCode: 400, statusMessage: "Rejected"),
            stage: .serverCertificate
        )
        XCTAssertEqual(parsed.statusCode, 400)
        XCTAssertEqual(parsed.statusMessage, "Rejected")
        XCTAssertEqual(parsed.paired, false)
    }

    func testCancellationConvergesAtEveryPairingRequestStage() async throws {
        let stages = [
            "serverinfo",
            "getservercert",
            "clientchallenge",
            "serverchallengeresp",
            "clientpairingsecret",
            "pairchallenge"
        ]

        for stage in stages {
            let serverIdentity = try SecurityClientIdentityGenerator().generateIdentity()
            let clientIdentity = try SecurityClientIdentityGenerator().generateIdentity()
            let executor = SunshinePairingStub(
                serverIdentity: serverIdentity,
                pin: "1234",
                blockingStage: stage
            )
            let provider = MoonlightPairingProvider(executor: executor)
            let request = makeRequest(identity: clientIdentity)
            let collector = Task { () -> ([PairingRuntimeEvent], PairingFailure?) in
                var events: [PairingRuntimeEvent] = []
                do {
                    let stream = await provider.pair(request)
                    for try await event in stream {
                        events.append(event)
                    }
                    return (events, nil)
                } catch let failure as PairingFailure {
                    return (events, failure)
                } catch {
                    return (events, PairingFailure(
                        code: .transportFailed,
                        message: String(describing: error)
                    ))
                }
            }

            try await waitUntilStage(stage, executor: executor)
            await provider.cancelPairing(attemptID: request.attemptID)
            await provider.cancelPairing(attemptID: request.attemptID)
            let outcome = await collector.value

            XCTAssertEqual(outcome.1?.code, .cancelled, "stage=\(stage)")
            XCTAssertFalse(outcome.0.contains { event in
                if case .completed = event { return true }
                return false
            }, "stage=\(stage)")
            guard case let .progress(snapshot) = outcome.0.last else {
                XCTFail("Expected cancelled progress at stage \(stage)")
                continue
            }
            XCTAssertEqual(snapshot.stage, .cancelled, "stage=\(stage)")
            XCTAssertEqual(snapshot.failure?.code, .cancelled, "stage=\(stage)")
            let activeAttemptCount = await provider.activeAttemptCount()
            XCTAssertEqual(activeAttemptCount, 0, "stage=\(stage)")
        }
    }

    func testURLSessionExecutorTaskCancellationConverges() async throws {
        let server = try HangingHTTPServer()
        let port = try await server.start()
        defer { server.cancel() }
        let executor = URLSessionPairingRequestExecutor()
        let request = URLRequest(url: URL(string: "http://127.0.0.1:\(port)/pair")!)
        let operation = Task {
            try await executor.data(
                for: request,
                expectedServerLeafDER: nil,
                clientIdentity: nil
            )
        }

        try await server.waitForConnection()
        let clock = ContinuousClock()
        let started = clock.now
        operation.cancel()
        do {
            _ = try await operation.value
            XCTFail("Expected URLSession cancellation")
        } catch is CancellationError {
            // Expected native async cancellation.
        } catch let error as URLError {
            XCTAssertEqual(error.code, .cancelled)
        }
        XCTAssertLessThan(started.duration(to: clock.now), .seconds(2))
    }

    private func makeRequest(identity: ClientIdentityMaterial) -> PairingRuntimeRequest {
        PairingRuntimeRequest(
            attemptID: UUID(uuidString: "8DAEF149-8468-4D79-A34C-31CBAD9668A0")!,
            host: MoonlightHost(
                id: UUID(uuidString: "91DD3C88-A34B-45AE-A359-D25598A007F0")!,
                name: "Pairing Fixture",
                address: "192.0.2.10",
                pairingState: .unpaired,
                reachability: .online
            ),
            pin: "1234",
            clientIdentity: identity
        )
    }

    private func externalRepresentation(_ key: SecKey) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(key, &error) as Data? else {
            throw error?.takeRetainedValue() ?? PairingTransportTestError.invalidRequest
        }
        return data
    }

    private func waitUntilStage(
        _ stage: String,
        executor: SunshinePairingStub
    ) async throws {
        for _ in 0..<1_000 {
            if (await executor.snapshot()).requestStages.contains(stage) {
                return
            }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw PairingTransportTestError.stageTimeout
    }
}

private struct SunshinePairingStubSnapshot: Sendable {
    var requestStages: [String]
    var clientSecretVerified: Bool
    var finalRequestUsedTemporaryPin: Bool
    var finalRequestUsedClientIdentity: Bool
}

private actor SunshinePairingStub: PairingRequestExecuting {
    private let serverIdentity: ClientIdentityMaterial
    private let pin: String
    private let failFinalPin: Bool
    private let blockingStage: String?
    private let crypto: MoonlightPairingCrypto
    private var aesKey: Data?
    private var clientChallenge: Data?
    private var serverChallenge = Data(repeating: 0x33, count: 16)
    private var serverSecret = Data(repeating: 0x22, count: 16)
    private var clientCertificateDER: Data?
    private var clientResponseHash: Data?
    private var requestStages: [String] = []
    private var clientSecretVerified = false
    private var finalRequestUsedTemporaryPin = false
    private var finalRequestUsedClientIdentity = false

    init(
        serverIdentity: ClientIdentityMaterial,
        pin: String,
        failFinalPin: Bool = false,
        blockingStage: String? = nil
    ) {
        self.serverIdentity = serverIdentity
        self.pin = pin
        self.failFinalPin = failFinalPin
        self.blockingStage = blockingStage
        self.crypto = try! MoonlightPairingCrypto(serverMajorVersion: 7)
    }

    func data(
        for request: URLRequest,
        expectedServerLeafDER: Data?,
        clientIdentity: ClientIdentityMaterial?
    ) async throws -> (Data, URLResponse) {
        guard let url = request.url else { throw PairingTransportTestError.invalidRequest }
        if url.path == "/serverinfo" {
            requestStages.append("serverinfo")
            try await blockIfNeeded("serverinfo")
            return response(
                xml(["appversion": "7.1.431.-1", "httpsport": "47984"]),
                url: url
            )
        }

        let query = Dictionary(uniqueKeysWithValues: URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        )?.queryItems?.compactMap { item in
            item.value.map { (item.name, $0) }
        } ?? [])
        if query["phrase"] == "getservercert" {
            requestStages.append("getservercert")
            try await blockIfNeeded("getservercert")
            guard let saltValue = query["salt"],
                  let salt = Data(testHex: saltValue),
                  let certificateValue = query["clientcert"],
                  let certificatePEM = Data(testHex: certificateValue),
                  let certificateDER = PinnedCertificateValidator.normalizedDER(certificatePEM) else {
                throw PairingTransportTestError.invalidRequest
            }
            aesKey = try crypto.deriveAESKey(salt: salt, pin: pin)
            clientCertificateDER = certificateDER
            return response(
                xml([
                    "paired": "1",
                    "plaincert": pemCertificate(serverIdentity.certificateDER).testHex
                ]),
                url: url
            )
        }
        if let encryptedValue = query["clientchallenge"] {
            requestStages.append("clientchallenge")
            try await blockIfNeeded("clientchallenge")
            guard let aesKey,
                  let encrypted = Data(testHex: encryptedValue) else {
                throw PairingTransportTestError.invalidRequest
            }
            let challenge = try crypto.decryptAES128ECB(encrypted, aesKey: aesKey)
            clientChallenge = challenge
            let certificateSignature = try crypto.certificateSignature(
                certificateDER: serverIdentity.certificateDER
            )
            let responseHash = try crypto.digest(
                challenge + certificateSignature + serverSecret
            )
            let encryptedResponse = try crypto.encryptAES128ECB(
                responseHash + serverChallenge,
                aesKey: aesKey
            )
            return response(
                xml(["paired": "1", "challengeresponse": encryptedResponse.testHex]),
                url: url
            )
        }
        if let encryptedValue = query["serverchallengeresp"] {
            requestStages.append("serverchallengeresp")
            try await blockIfNeeded("serverchallengeresp")
            guard let aesKey,
                  let encrypted = Data(testHex: encryptedValue) else {
                throw PairingTransportTestError.invalidRequest
            }
            clientResponseHash = try crypto.decryptAES128ECB(encrypted, aesKey: aesKey)
            let pairingSecret = try crypto.makeClientPairingSecret(
                clientSecret: serverSecret,
                identity: serverIdentity
            )
            return response(
                xml(["paired": "1", "pairingsecret": pairingSecret.testHex]),
                url: url
            )
        }
        if let pairingSecretValue = query["clientpairingsecret"] {
            requestStages.append("clientpairingsecret")
            try await blockIfNeeded("clientpairingsecret")
            guard let pairingSecret = Data(testHex: pairingSecretValue),
                  let clientCertificateDER,
                  let clientResponseHash else {
                throw PairingTransportTestError.invalidRequest
            }
            let clientSecret = try crypto.verifyServerPairingSecret(
                pairingSecret,
                serverCertificateDER: clientCertificateDER
            )
            let clientCertificateSignature = try crypto.certificateSignature(
                certificateDER: clientCertificateDER
            )
            try crypto.verifyServerResponse(
                responseHash: Data(clientResponseHash.prefix(crypto.digestLength)),
                clientChallenge: serverChallenge,
                serverCertificateSignature: clientCertificateSignature,
                serverSecret: clientSecret
            )
            clientSecretVerified = true
            return response(xml(["paired": "1"]), url: url)
        }
        if query["phrase"] == "pairchallenge" {
            requestStages.append("pairchallenge")
            try await blockIfNeeded("pairchallenge")
            finalRequestUsedTemporaryPin = expectedServerLeafDER == serverIdentity.certificateDER
            finalRequestUsedClientIdentity = clientIdentity != nil
            if failFinalPin {
                throw PairingTransportError.certificateMismatch
            }
            guard finalRequestUsedTemporaryPin, finalRequestUsedClientIdentity else {
                throw PairingTransportTestError.invalidRequest
            }
            return response(xml(["paired": "1"]), url: url)
        }
        throw PairingTransportTestError.invalidRequest
    }

    func snapshot() -> SunshinePairingStubSnapshot {
        SunshinePairingStubSnapshot(
            requestStages: requestStages,
            clientSecretVerified: clientSecretVerified,
            finalRequestUsedTemporaryPin: finalRequestUsedTemporaryPin,
            finalRequestUsedClientIdentity: finalRequestUsedClientIdentity
        )
    }

    private func response(_ data: Data, url: URL) -> (Data, URLResponse) {
        (
            data,
            HTTPURLResponse(
                url: url,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: nil
            )!
        )
    }

    private func blockIfNeeded(_ stage: String) async throws {
        guard blockingStage == stage else { return }
        try await Task.sleep(for: .seconds(60))
    }
}

private final class HangingHTTPServer: @unchecked Sendable {
    private let listener: NWListener
    private let queue = DispatchQueue(label: "dev.lunex.tests.pairing-hanging-http")
    private let lock = NSLock()
    private var connections: [NWConnection] = []

    init() throws {
        listener = try NWListener(using: .tcp, on: .any)
    }

    func start() async throws -> UInt16 {
        try await withCheckedThrowingContinuation { continuation in
            listener.newConnectionHandler = { [weak self] connection in
                guard let self else { return }
                self.lock.withLock { self.connections.append(connection) }
                connection.start(queue: self.queue)
            }
            listener.stateUpdateHandler = { [weak listener] state in
                switch state {
                case .ready:
                    guard let listener, let port = listener.port?.rawValue else {
                        continuation.resume(throwing: PairingTransportTestError.invalidRequest)
                        return
                    }
                    listener.stateUpdateHandler = nil
                    continuation.resume(returning: port)
                case let .failed(error):
                    listener?.stateUpdateHandler = nil
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
            listener.start(queue: queue)
        }
    }

    func waitForConnection() async throws {
        for _ in 0..<1_000 {
            if lock.withLock({ !connections.isEmpty }) {
                return
            }
            try await Task.sleep(for: .milliseconds(1))
        }
        throw PairingTransportTestError.stageTimeout
    }

    func cancel() {
        listener.cancel()
        lock.withLock {
            connections.forEach { $0.cancel() }
            connections.removeAll()
        }
    }
}

private func xml(
    _ values: [String: String],
    statusCode: Int = 200,
    statusMessage: String = "OK"
) -> Data {
    let body = values.keys.sorted().map { key in
        "<\(key)>\(values[key]!)</\(key)>"
    }.joined()
    return Data(
        "<root status_code=\"\(statusCode)\" status_message=\"\(statusMessage)\">\(body)</root>".utf8
    )
}

private func pemCertificate(_ der: Data) -> Data {
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

private extension Data {
    init?(testHex: String) {
        guard testHex.count.isMultiple(of: 2) else { return nil }
        var result = Data()
        var index = testHex.startIndex
        while index < testHex.endIndex {
            let next = testHex.index(index, offsetBy: 2)
            guard let byte = UInt8(testHex[index..<next], radix: 16) else { return nil }
            result.append(byte)
            index = next
        }
        self = result
    }

    var testHex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}

private enum PairingTransportTestError: Error {
    case invalidRequest
    case stageTimeout
}
