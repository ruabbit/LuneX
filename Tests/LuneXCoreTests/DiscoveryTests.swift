import Foundation
import XCTest

final class DiscoveryTests: XCTestCase {
    func testEndpointParserHandlesDefaultAndExplicitPorts() throws {
        XCTAssertEqual(try HostEndpointParser.parse("192.168.1.50").displayAddress, "192.168.1.50")
        XCTAssertEqual(try HostEndpointParser.parse("192.168.1.50:48010").displayAddress, "192.168.1.50:48010")
        XCTAssertEqual(try HostEndpointParser.parse("[fe80::1]:47989").displayAddress, "[fe80::1]:47989")
    }

    func testServerInfoURLAlwaysCarriesTheGameStreamHTTPPort() throws {
        XCTAssertEqual(
            try HostEndpointParser.parse("192.168.1.50")
                .serverInfoURL?.absoluteString,
            "http://192.168.1.50:47989/serverinfo"
        )
        XCTAssertEqual(
            try HostEndpointParser.parse("moon.local:48010")
                .serverInfoURL?.absoluteString,
            "http://moon.local:48010/serverinfo"
        )
        XCTAssertEqual(
            try HostEndpointParser.parse("fe80::1%en0")
                .serverInfoURL?.absoluteString,
            "http://[fe80::1%25en0]:47989/serverinfo"
        )
    }

    func testEndpointParserNormalizesWhitespaceNamesURLsAndIPv6() throws {
        XCTAssertEqual(
            try HostEndpointParser.parse("  Moon.Local.  ").displayAddress,
            "moon.local"
        )
        XCTAssertEqual(
            try HostEndpointParser.parse("Moon.Local:48010").displayAddress,
            "moon.local:48010"
        )
        XCTAssertEqual(
            try HostEndpointParser.parse("https://Moon.Local:48010/").displayAddress,
            "moon.local:48010"
        )
        XCTAssertEqual(
            try HostEndpointParser.parse("fe80::1").displayAddress,
            "[fe80::1]:47989"
        )
        XCTAssertEqual(
            try HostEndpointParser.parse("[FE80::1%EN0]").displayAddress,
            "[fe80::1%en0]:47989"
        )
    }

    func testEndpointParserRejectsCredentialsUnsupportedURLsAndPaths() {
        assertParseError("http://user:password@moon.local", .credentialsNotAllowed)
        assertParseError("ftp://moon.local", .unsupportedScheme)
        assertParseError("http://moon.local/apps", .invalidAddress)
        assertParseError("http://moon.local/?token=value", .invalidAddress)
        assertParseError("http://moon.local/#details", .invalidAddress)
    }

    func testEndpointParserRejectsInvalidPortsAddressesAndControlCharacters() {
        assertParseError("", .emptyAddress)
        assertParseError("moon.local:0", .invalidPort)
        assertParseError("moon.local:65536", .invalidPort)
        assertParseError("moon.local:not-a-port", .invalidPort)
        assertParseError(":47989", .invalidAddress)
        assertParseError("999.1.1.1", .invalidAddress)
        assertParseError("moon..local", .invalidAddress)
        assertParseError("-moon.local", .invalidAddress)
        assertParseError("moon local", .invalidAddress)
        assertParseError("moon.local\nother.local", .invalidAddress)
        assertParseError("[fe80::1", .invalidAddress)
        assertParseError("[not-ipv6]", .invalidAddress)
    }

    func testManualHostDraftReturnsNormalizedSubmissionOrFieldSafeIssue() throws {
        let submission = try ManualHostDraft(
            name: "  Studio  ",
            address: "  Moon.Local:48010  "
        ).validate().get()
        XCTAssertEqual(submission.name, "Studio")
        XCTAssertEqual(submission.endpoint, HostEndpoint(host: "moon.local", port: 48_010))
        XCTAssertEqual(submission.normalizedAddress, "moon.local:48010")

        XCTAssertEqual(
            ManualHostDraft(address: "  ").validate(),
            .failure(ManualHostValidationFailure(issueCode: .hostAddressRequired))
        )
        XCTAssertEqual(
            ManualHostDraft(address: "http://user:secret@moon.local").validate(),
            .failure(ManualHostValidationFailure(issueCode: .hostAddressInvalid))
        )
    }

    func testEndpointParserExtendedBoundaryMatrix() throws {
        let valid: [(String, String)] = [
            ("localhost", "localhost"),
            ("HOST_NAME.local.", "host_name.local"),
            ("10.0.0.8:47990", "10.0.0.8:47990"),
            ("http://moon.local/", "moon.local"),
            ("[2001:DB8::10]:48000", "[2001:db8::10]:48000"),
            ("fe80::2%EN1", "[fe80::2%en1]:47989")
        ]
        for (input, expected) in valid {
            XCTAssertEqual(
                try HostEndpointParser.parse(input).displayAddress,
                expected,
                input
            )
        }

        let invalid: [(String, HostEndpointParseError)] = [
            ("https://moon.local:70000", .invalidPort),
            ("http://user%40name:password@moon.local", .credentialsNotAllowed),
            ("http://moon.local//", .invalidAddress),
            ("[fe80::1]trailing", .invalidAddress),
            ("fe80::1%bad zone", .invalidAddress),
            ("moon.local#fragment", .invalidAddress),
            ("moon.local/path", .invalidAddress)
        ]
        for (input, expected) in invalid {
            assertParseError(input, expected)
        }
    }

    func testServerInfoParserExtractsHostMetadata() {
        let xml = """
        <root>
          <hostname>Studio PC</hostname>
          <uniqueid>abc</uniqueid>
          <state>ONLINE</state>
          <hdr>1</hdr>
        </root>
        """

        let info = ServerInfoParser.parse(Data(xml.utf8))

        XCTAssertEqual(info.name, "Studio PC")
        XCTAssertEqual(info.uniqueID, "abc")
        XCTAssertEqual(info.state, "ONLINE")
        XCTAssertTrue(info.supportsHDR)
    }

    func testManualHostAddUpsertsByCanonicalAddress() async throws {
        let repository = InMemoryHostRepository()
        let manager = HostLibraryManager(
            repository: repository,
            serverInfoClient: StubServerInfoClient(info: ServerInfo(
                name: "Studio PC",
                uniqueID: "abc",
                macAddress: nil,
                state: "ONLINE",
                supportsHDR: true,
                rawValues: [:]
            ))
        )

        let first = try await manager.addManualHost(name: nil, address: "192.168.1.50")
        let second = try await manager.addManualHost(name: "Manual Name", address: "192.168.1.50")

        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(second.count, 1)
        XCTAssertEqual(second[0].name, "Studio PC")
        XCTAssertEqual(second[0].reachability, .online)
        XCTAssertTrue(second[0].capabilities.supportsHDR)
    }

    private func assertParseError(
        _ input: String,
        _ expected: HostEndpointParseError,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(try HostEndpointParser.parse(input), file: file, line: line) {
            XCTAssertEqual($0 as? HostEndpointParseError, expected, file: file, line: line)
        }
    }
}

private struct StubServerInfoClient: ServerInfoClient {
    var info: ServerInfo

    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        info
    }
}
