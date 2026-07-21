import Foundation
import XCTest

final class RuntimeProviderContractTests: XCTestCase {
    func testPairingProviderPublishesOrderedProgressAndCompletion() async throws {
        let host = makeHost(pairingState: .unpaired)
        let identity = ClientIdentityMaterial(
            id: UUID(uuidString: "ED49C4FC-A677-431D-A94B-B75E7607F81B")!,
            certificateDER: Data([1, 2, 3]),
            privateKeyDER: Data([4, 5, 6]),
            createdAt: Date(timeIntervalSince1970: 10)
        )
        let request = PairingRuntimeRequest(
            attemptID: UUID(uuidString: "D6078745-BC5A-4EED-86AE-4971C71183BB")!,
            host: host,
            pin: "1234",
            clientIdentity: identity
        )
        let provider: any PairingRuntimeProvider = ContractPairingProvider()
        let stream = await provider.pair(request)
        var events: [PairingRuntimeEvent] = []
        for try await event in stream {
            events.append(event)
        }

        XCTAssertEqual(events.count, 2)
        guard case let .progress(snapshot) = events[0] else {
            return XCTFail("Expected progress first")
        }
        XCTAssertEqual(snapshot.attemptID, request.attemptID)
        XCTAssertEqual(snapshot.stage, .verifyingServer)
        guard case let .completed(result) = events[1] else {
            return XCTFail("Expected completion second")
        }
        XCTAssertEqual(result.host.pairingState, .paired)
    }

    func testReadinessRequiresEveryNegotiatedRequiredChannel() {
        let ready: SessionChannelReadiness = [.control, .video, .audio]
        XCTAssertTrue(ready.satisfies([.control, .video]))
        XCTAssertFalse(ready.satisfies(.all))
    }

    func testSunshineAudioProfilesSatisfyContract() throws {
        let profiles = [
            makeAudio(channels: 2, streams: 1, coupled: 1),
            makeAudio(channels: 6, streams: 4, coupled: 2),
            makeAudio(channels: 6, streams: 6, coupled: 0),
            makeAudio(channels: 8, streams: 5, coupled: 3),
            makeAudio(channels: 8, streams: 8, coupled: 0)
        ]
        for profile in profiles {
            XCTAssertNoThrow(try profile.validate())
        }
    }

    func testAudioContractRejectsMappingThatDoesNotCoverCodedChannels() {
        var configuration = makeAudio(channels: 6, streams: 4, coupled: 2)
        configuration.channelMapping = [0, 1, 2, 3, 4, 6]

        XCTAssertThrowsError(try configuration.validate()) { error in
            XCTAssertEqual(error as? RuntimeContractError, .invalidAudioConfiguration)
        }
    }

    func testNegotiatedSessionRejectsZeroPort() {
        var configuration = makeSessionConfiguration()
        configuration.audioEndpoint.port = 0

        XCTAssertThrowsError(try configuration.validate()) { error in
            XCTAssertEqual(error as? RuntimeContractError, .invalidEndpoint)
        }
    }

    private func makeSessionConfiguration() -> NegotiatedSessionConfiguration {
        let control = RuntimeNetworkEndpoint(host: "moon.test", port: 47_999, transport: .tcp)
        return NegotiatedSessionConfiguration(
            sessionID: UUID(uuidString: "5F508290-EC3F-4D8B-982E-D0C101C7C531")!,
            controlEndpoint: control,
            videoEndpoint: RuntimeNetworkEndpoint(host: "moon.test", port: 48_000, transport: .udp),
            audioEndpoint: RuntimeNetworkEndpoint(host: "moon.test", port: 48_010, transport: .udp),
            inputEndpoint: RuntimeNetworkEndpoint(host: "moon.test", port: 35_043, transport: .tcp),
            video: NegotiatedVideoStreamConfiguration(
                codec: .hevc,
                width: 3_840,
                height: 2_160,
                frameRate: 60,
                colorMetadata: .hdr10VideoRange(),
                maximumPacketSize: 1_400
            ),
            audio: makeAudio(channels: 2, streams: 1, coupled: 1),
            input: NegotiatedInputConfiguration(
                keyMaterial: RemoteInputKeyMaterial(keyID: 7, key: Data(repeating: 0x11, count: 16)),
                encrypted: true,
                maximumMessageSize: RemoteInputWireCodec.maximumPacketSize
            ),
            requiredChannels: .all
        )
    }

    private func makeAudio(
        channels: Int,
        streams: Int,
        coupled: Int
    ) -> NegotiatedAudioStreamConfiguration {
        NegotiatedAudioStreamConfiguration(
            sampleRate: 48_000,
            channelCount: channels,
            streamCount: streams,
            coupledStreamCount: coupled,
            samplesPerFrame: 240,
            channelMapping: (0..<channels).map(UInt8.init),
            maximumPacketSize: 1_400
        )
    }

    private func makeHost(pairingState: PairingState) -> MoonlightHost {
        MoonlightHost(
            id: UUID(uuidString: "EED27FB4-58C0-4051-93FD-E0F43DB82DF2")!,
            name: "Contract Host",
            address: "moon.test",
            pairingState: pairingState,
            reachability: .online
        )
    }
}

private struct ContractPairingProvider: PairingRuntimeProvider {
    func pair(
        _ request: PairingRuntimeRequest
    ) async -> AsyncThrowingStream<PairingRuntimeEvent, Error> {
        AsyncThrowingStream { continuation in
            let serverIdentity = PairingServerIdentity(
                certificateDER: Data([7, 8, 9]),
                certificateSHA256: "fixture-digest",
                serverMajorVersion: 7
            )
            let pairedHost = MoonlightHost(
                id: request.host.id,
                name: request.host.name,
                address: request.host.address,
                pairingState: .paired,
                reachability: request.host.reachability,
                pinnedIdentity: PinnedHostIdentity(
                    certificateSHA256: serverIdentity.certificateSHA256,
                    serverCertificateDER: serverIdentity.certificateDER,
                    pairedAt: Date(timeIntervalSince1970: 20)
                )
            )
            continuation.yield(.progress(PairingSnapshot(
                attemptID: request.attemptID,
                hostID: request.host.id,
                stage: .verifyingServer,
                digestAlgorithm: .sha256,
                failure: nil,
                updatedAt: Date(timeIntervalSince1970: 19)
            )))
            continuation.yield(.completed(PairingResult(
                host: pairedHost,
                serverIdentity: serverIdentity,
                digestAlgorithm: .sha256,
                pairedAt: Date(timeIntervalSince1970: 20)
            )))
            continuation.finish()
        }
    }

    func cancelPairing(attemptID: UUID) async {
        _ = attemptID
    }
}
