import Foundation
import XCTest

final class RTSPSessionDescriptionTests: XCTestCase {
    func testDescribeFixtureParsesCapabilitiesCodecsAndOpusProfiles() throws {
        let fixture = try loadFixture()
        let response = RTSPResponse(
            statusCode: 200,
            reasonPhrase: "OK",
            body: Data(fixture.describeBody.utf8)
        )

        let description = try SunshineSessionDescriptionParser.parse(response)

        XCTAssertEqual(description.featureFlags, 5)
        XCTAssertEqual(description.encryptionSupported, 7)
        XCTAssertEqual(description.encryptionRequested, 1)
        XCTAssertTrue(description.supportsReferenceFrameInvalidation)
        XCTAssertEqual(description.availableVideoCodecs, [.h264, .hevc, .av1])
        XCTAssertEqual(description.opusConfigurations.count, 3)
        XCTAssertEqual(description.opusConfiguration(channelCount: 6, highQuality: false)?.channelMapping,
                       [0, 1, 2, 3, 4, 5])
        XCTAssertEqual(description.opusConfiguration(channelCount: 6, highQuality: true)?.streamCount, 4)
        let stereo = try XCTUnwrap(description.opusConfiguration(channelCount: 2, highQuality: false))
        XCTAssertNoThrow(try stereo.makeRuntimeConfiguration(
            samplesPerFrame: 240,
            maximumPacketSize: 1_400
        ))
    }

    func testSetupFixturesParseSessionPortsAndExtensions() throws {
        let fixture = try loadFixture()
        let audio = try RTSPSetupResponseParser.parse(
            fixture.audioSetup.response,
            kind: .audio
        )
        let video = try RTSPSetupResponseParser.parse(
            fixture.videoSetup.response,
            kind: .video
        )
        let control = try RTSPSetupResponseParser.parse(
            fixture.controlSetup.response,
            kind: .control
        )

        XCTAssertEqual(audio.sessionToken, "DEADBEEFCAFE")
        XCTAssertEqual(audio.serverPort, 48_000)
        XCTAssertEqual(audio.pingPayload, "synthetic-ping")
        XCTAssertEqual(video.serverPort, 47_998)
        XCTAssertEqual(control.serverPort, 47_999)
        XCTAssertEqual(control.controlConnectData, 305_419_896)
        XCTAssertEqual(control.endpoint(host: "example.invalid").transport, .udp)
    }

    func testDescriptionRejectsMalformedKnownAttributesAndOpusMappings() throws {
        XCTAssertThrowsError(try SunshineSessionDescriptionParser.parse(RTSPResponse(
            statusCode: 200,
            reasonPhrase: "OK",
            body: Data("a=x-ss-general.featureFlags:not-a-number\n".utf8)
        )))
        XCTAssertThrowsError(try SunshineSessionDescriptionParser.parse(RTSPResponse(
            statusCode: 200,
            reasonPhrase: "OK",
            body: Data("a=fmtp:97 surround-params=642012344\n".utf8)
        )))
        XCTAssertThrowsError(try SunshineSessionDescriptionParser.parse(RTSPResponse(
            statusCode: 500,
            reasonPhrase: "Failed",
            body: Data("a=x-ss-general.featureFlags:0\n".utf8)
        )))
    }

    func testSetupRejectsMissingConflictingAndInvalidNegotiatedFields() throws {
        let base = RTSPResponse(
            statusCode: 200,
            reasonPhrase: "OK",
            headers: [RTSPHeader(name: "Session", value: "session")]
        )
        XCTAssertThrowsError(try RTSPSetupResponseParser.parse(base, kind: .audio))

        var duplicate = base
        duplicate.headers = [
            RTSPHeader(name: "Session", value: "one"),
            RTSPHeader(name: "session", value: "two"),
            RTSPHeader(name: "Transport", value: "server_port=48000")
        ]
        XCTAssertThrowsError(try RTSPSetupResponseParser.parse(duplicate, kind: .audio))

        var invalidPort = base
        invalidPort.headers.append(RTSPHeader(name: "Transport", value: "server_port=0"))
        XCTAssertThrowsError(try RTSPSetupResponseParser.parse(invalidPort, kind: .audio))
    }

    private func loadFixture() throws -> NegotiationFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/rtsp/negotiation.json")
        return try JSONDecoder().decode(NegotiationFixture.self, from: Data(contentsOf: url))
    }
}

private struct NegotiationFixture: Decodable {
    var describeBody: String
    var audioSetup: SetupFixture
    var videoSetup: SetupFixture
    var controlSetup: SetupFixture
}

private struct SetupFixture: Decodable {
    var session: String
    var transport: String
    var pingPayload: String?
    var connectData: String?

    var response: RTSPResponse {
        var headers = [
            RTSPHeader(name: "Session", value: session),
            RTSPHeader(name: "Transport", value: transport)
        ]
        if let pingPayload {
            headers.append(RTSPHeader(name: "X-SS-Ping-Payload", value: pingPayload))
        }
        if let connectData {
            headers.append(RTSPHeader(name: "X-SS-Connect-Data", value: connectData))
        }
        return RTSPResponse(statusCode: 200, reasonPhrase: "OK", headers: headers)
    }
}
