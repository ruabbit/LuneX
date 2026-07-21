import Foundation
import XCTest

final class AudioToolboxOpusDecoderTests: XCTestCase {
    func testStereoOpusHeadIsByteExactMappingFamilyZero() throws {
        let cookie = try OpusHeadEncoder.encode(configuration: stereoConfiguration())

        XCTAssertEqual([UInt8](cookie), [
            0x4f, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64,
            0x01, 0x02, 0x00, 0x00, 0x80, 0xbb, 0x00, 0x00,
            0x00, 0x00, 0x00
        ])
    }

    func testSurroundOpusHeadPreservesSunshineIdentityMapping() throws {
        let configuration = audioConfiguration(
            channels: 6,
            streams: 4,
            coupledStreams: 2
        )
        let cookie = try OpusHeadEncoder.encode(configuration: configuration)

        XCTAssertEqual([UInt8](cookie), [
            0x4f, 0x70, 0x75, 0x73, 0x48, 0x65, 0x61, 0x64,
            0x01, 0x06, 0x00, 0x00, 0x80, 0xbb, 0x00, 0x00,
            0x00, 0x00, 0x01, 0x04, 0x02, 0x00, 0x01, 0x02,
            0x03, 0x04, 0x05
        ])
    }

    func testNonIdentityStereoUsesExplicitMappingFamily() throws {
        var configuration = stereoConfiguration()
        configuration.channelMapping = [1, 0]

        let cookie = try OpusHeadEncoder.encode(configuration: configuration)

        XCTAssertEqual(Array(cookie.suffix(5)), [1, 1, 1, 1, 0])
    }

    func testProductionDecoderEmitsActualInterleavedPCMFrameCount() async throws {
        let fixture = try loadFixture()
        let payload = try XCTUnwrap(Data(base64Encoded: fixture.base64Payload))
        let decoder = try AudioToolboxOpusDecoder(configuration: stereoConfiguration())
        let packet = ReceivedAudioPacket(
            sequenceNumber: 42,
            timestamp: 123_456,
            receiveTimeNanoseconds: 1_000,
            payload: payload
        )

        let decoded = try await decoder.decode(packet)

        XCTAssertEqual(decoded.sequenceNumber, 42)
        XCTAssertEqual(decoded.rtpTimestamp, 123_456)
        XCTAssertEqual(decoded.format, .signedInt16(sampleRate: 48_000, channelCount: 2))
        XCTAssertGreaterThan(decoded.frameCount, 0)
        XCTAssertLessThanOrEqual(decoded.frameCount, fixture.expectedDecodedFrames)
        XCTAssertEqual(decoded.interleavedSamples.count, decoded.frameCount * 2)
        XCTAssertTrue(decoded.interleavedSamples.contains(where: { $0 != 0 }))
        await decoder.close()
    }

    func testResetAllowsASecondSyntheticPacketDecode() async throws {
        let fixture = try loadFixture()
        let payload = try XCTUnwrap(Data(base64Encoded: fixture.base64Payload))
        let decoder = try AudioToolboxOpusDecoder(configuration: stereoConfiguration())
        let packet = ReceivedAudioPacket(
            sequenceNumber: 1,
            timestamp: 0,
            receiveTimeNanoseconds: 0,
            payload: payload
        )

        let first = try await decoder.decode(packet)
        try await decoder.reset()
        let second = try await decoder.decode(packet)

        XCTAssertGreaterThan(first.frameCount, 0)
        XCTAssertGreaterThan(second.frameCount, 0)
        await decoder.close()
    }

    func testEveryApprovedSunshineProfileCreatesAndClosesConverter() async throws {
        let profiles = [
            (2, 1, 1),
            (6, 4, 2),
            (6, 6, 0),
            (8, 5, 3),
            (8, 8, 0)
        ]
        for profile in profiles {
            let decoder = try AudioToolboxOpusDecoder(configuration: audioConfiguration(
                channels: profile.0,
                streams: profile.1,
                coupledStreams: profile.2
            ))
            await decoder.close()
            await decoder.close()
        }
    }

    func testProductionDecoderDecodesEverySyntheticSunshineMultistreamProfile() async throws {
        let fixture = try loadMultistreamFixture()
        for (index, profile) in fixture.profiles.enumerated() {
            let payload = try XCTUnwrap(Data(base64Encoded: profile.base64Payload))
            let decoder = try AudioToolboxOpusDecoder(configuration: audioConfiguration(
                channels: profile.channelCount,
                streams: profile.streamCount,
                coupledStreams: profile.coupledStreamCount
            ))
            let decoded = try await decoder.decode(ReceivedAudioPacket(
                sequenceNumber: UInt16(index),
                timestamp: UInt32(index * 240),
                receiveTimeNanoseconds: UInt64(index),
                payload: payload
            ))

            XCTAssertGreaterThan(decoded.frameCount, 0, profile.name)
            XCTAssertLessThanOrEqual(decoded.frameCount, fixture.samplesPerFrame, profile.name)
            XCTAssertEqual(
                decoded.interleavedSamples.count,
                decoded.frameCount * profile.channelCount,
                profile.name
            )
            XCTAssertTrue(
                decoded.interleavedSamples.contains(where: { $0 != 0 }),
                profile.name
            )
            await decoder.close()
        }
    }

    func testInvalidConfigurationPayloadAndClosedStateFailClosed() async throws {
        var oversizedFrames = stereoConfiguration()
        oversizedFrames.samplesPerFrame = OpusHeadEncoder.maximumSamplesPerFrame + 1
        XCTAssertThrowsError(try AudioToolboxOpusDecoder(configuration: oversizedFrames)) { error in
            XCTAssertEqual(error as? OpusDecoderError, .invalidConfiguration)
        }

        let decoder = try AudioToolboxOpusDecoder(configuration: stereoConfiguration())
        let emptyPacket = ReceivedAudioPacket(
            sequenceNumber: 0,
            timestamp: 0,
            receiveTimeNanoseconds: 0,
            payload: Data()
        )
        await OpusXCTAssertThrowsErrorAsync(try await decoder.decode(emptyPacket)) { error in
            XCTAssertEqual(error as? OpusDecoderError, .invalidPacketPayload)
        }
        var oversizedPacket = emptyPacket
        oversizedPacket.payload = Data(repeating: 0, count: 1_401)
        await OpusXCTAssertThrowsErrorAsync(try await decoder.decode(oversizedPacket)) { error in
            XCTAssertEqual(error as? OpusDecoderError, .invalidPacketPayload)
        }

        await decoder.close()
        await OpusXCTAssertThrowsErrorAsync(try await decoder.decode(oversizedPacket)) { error in
            XCTAssertEqual(error as? OpusDecoderError, .closed)
        }
        await OpusXCTAssertThrowsErrorAsync(try await decoder.reset()) { error in
            XCTAssertEqual(error as? OpusDecoderError, .closed)
        }
    }

    private func stereoConfiguration() -> NegotiatedAudioStreamConfiguration {
        audioConfiguration(channels: 2, streams: 1, coupledStreams: 1)
    }

    private func audioConfiguration(
        channels: Int,
        streams: Int,
        coupledStreams: Int
    ) -> NegotiatedAudioStreamConfiguration {
        NegotiatedAudioStreamConfiguration(
            sampleRate: 48_000,
            channelCount: channels,
            streamCount: streams,
            coupledStreamCount: coupledStreams,
            samplesPerFrame: 240,
            channelMapping: (0..<channels).map(UInt8.init),
            maximumPacketSize: 1_400
        )
    }

    private func loadFixture() throws -> OpusDecoderFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/audio/stereo-5ms-opus.json")
        return try JSONDecoder().decode(
            OpusDecoderFixture.self,
            from: Data(contentsOf: url)
        )
    }

    private func loadMultistreamFixture() throws -> MultistreamOpusDecoderFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/audio/sunshine-multistream-5ms-opus.json")
        return try JSONDecoder().decode(
            MultistreamOpusDecoderFixture.self,
            from: Data(contentsOf: url)
        )
    }
}

private struct OpusDecoderFixture: Decodable {
    var base64Payload: String
    var expectedDecodedFrames: Int
}

private struct MultistreamOpusDecoderFixture: Decodable {
    struct Profile: Decodable {
        var base64Payload: String
        var channelCount: Int
        var coupledStreamCount: Int
        var name: String
        var streamCount: Int
    }

    var profiles: [Profile]
    var samplesPerFrame: Int
}

private func OpusXCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw")
    } catch {
        errorHandler(error)
    }
}
