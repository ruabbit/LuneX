import Foundation
import XCTest

final class RTSPMessageTests: XCTestCase {
    func testGeneratedFixturesDecodeAndSerializeByteExactly() throws {
        let fixture = try loadFixture()
        for wire in [fixture.optionsRequest, fixture.successResponse] {
            let data = Data(wire.utf8)
            let message = try RTSPMessageCodec.decodeExact(data)
            XCTAssertEqual(try RTSPMessageCodec.serialize(message), data)
        }
    }

    func testBinaryBodyRemainsByteExact() throws {
        let body = Data([0, 13, 10, 13, 10, 255, 1])
        let response = RTSPMessage.response(RTSPResponse(
            statusCode: 200,
            reasonPhrase: "OK",
            headers: [RTSPHeader(name: "Content-Length", value: "7")],
            body: body
        ))

        let wire = try RTSPMessageCodec.serialize(response)
        let decoded = try RTSPMessageCodec.decodeExact(wire)

        XCTAssertEqual(decoded.body, body)
        XCTAssertEqual(decoded, response)
    }

    func testPrefixDecoderHandlesFragmentedAndCoalescedMessages() throws {
        let fixture = try loadFixture()
        let first = Data(fixture.optionsRequest.utf8)
        let second = Data(fixture.successResponse.utf8)
        XCTAssertNil(try RTSPMessageCodec.decodePrefix(first.prefix(8)))

        let combined = first + second
        let decodedFirst = try XCTUnwrap(RTSPMessageCodec.decodePrefix(combined))
        XCTAssertEqual(decodedFirst.consumedBytes, first.count)
        let remaining = combined.dropFirst(decodedFirst.consumedBytes)
        let decodedSecond = try XCTUnwrap(RTSPMessageCodec.decodePrefix(remaining))
        XCTAssertEqual(decodedSecond.consumedBytes, second.count)

        var limits = RTSPParserLimits.moonlight
        limits.maximumMessageBytes = max(first.count, second.count)
        XCTAssertGreaterThan(combined.count, limits.maximumMessageBytes)
        XCTAssertEqual(
            try RTSPMessageCodec.decodePrefix(combined, limits: limits)?.consumedBytes,
            first.count
        )
    }

    func testHeaderLookupIsCaseInsensitiveAndPreservesDuplicates() throws {
        let wire = Data("RTSP/1.0 200 OK\r\nX-Test: one\r\nx-test: two\r\n\r\n".utf8)
        guard case let .response(response) = try RTSPMessageCodec.decodeExact(wire) else {
            return XCTFail("Expected response")
        }
        XCTAssertEqual(response.headerValues(named: "X-TEST"), ["one", "two"])
        XCTAssertEqual(response.headers.map(\.name), ["X-Test", "x-test"])
    }

    func testMalformedAndBoundedInputsFailClosed() throws {
        XCTAssertThrowsError(try RTSPMessageCodec.decodeExact(
            Data("RTSP/1.0 200 OK\n\n".utf8)
        ))
        XCTAssertThrowsError(try RTSPMessageCodec.decodeExact(
            Data("RTSP/1.0 200 OK\r\nBad Header: value\r\n\r\n".utf8)
        ))
        XCTAssertThrowsError(try RTSPMessageCodec.decodeExact(
            Data("RTSP/1.0 200 OK\r\nContent-Length: 1\r\ncontent-length: 1\r\n\r\nx".utf8)
        ))
        XCTAssertThrowsError(try RTSPMessageCodec.decodeExact(
            Data("RTSP/2.0 200 OK\r\n\r\n".utf8)
        ))
        XCTAssertThrowsError(try RTSPMessageCodec.decodeExact(
            Data("RTSP/1.0 200 OK\r\nContent-Length: 2\r\n\r\nx".utf8)
        ))
        XCTAssertThrowsError(try RTSPMessageCodec.decodeExact(
            Data("RTSP/1.0 200 OK\r\n\r\ntrailing".utf8)
        ))

        var limits = RTSPParserLimits.moonlight
        limits.maximumHeaderBytes = 20
        XCTAssertThrowsError(try RTSPMessageCodec.decodePrefix(
            Data(repeating: 65, count: 21),
            limits: limits
        ))
    }

    func testSerializerRejectsInjectionAndLengthMismatch() throws {
        let injected = RTSPMessage.request(RTSPRequest(
            method: "OPTIONS",
            target: "rtsp://example.invalid/session",
            headers: [RTSPHeader(name: "X-Test", value: "ok\r\nInjected: yes")]
        ))
        XCTAssertThrowsError(try RTSPMessageCodec.serialize(injected))

        let mismatch = RTSPMessage.response(RTSPResponse(
            statusCode: 200,
            reasonPhrase: "OK",
            headers: [RTSPHeader(name: "Content-Length", value: "4")],
            body: Data("five!".utf8)
        ))
        XCTAssertThrowsError(try RTSPMessageCodec.serialize(mismatch))
    }

    private func loadFixture() throws -> RTSPWireFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/rtsp/messages.json")
        return try JSONDecoder().decode(RTSPWireFixture.self, from: Data(contentsOf: url))
    }
}

private struct RTSPWireFixture: Decodable {
    var optionsRequest: String
    var successResponse: String
}
