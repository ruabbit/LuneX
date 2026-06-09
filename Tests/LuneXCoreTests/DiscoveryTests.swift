import Foundation
import XCTest

final class DiscoveryTests: XCTestCase {
    func testEndpointParserHandlesDefaultAndExplicitPorts() throws {
        XCTAssertEqual(try HostEndpointParser.parse("192.168.1.50").displayAddress, "192.168.1.50")
        XCTAssertEqual(try HostEndpointParser.parse("192.168.1.50:48010").displayAddress, "192.168.1.50:48010")
        XCTAssertEqual(try HostEndpointParser.parse("[fe80::1]:47989").displayAddress, "[fe80::1]:47989")
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
}

private struct StubServerInfoClient: ServerInfoClient {
    var info: ServerInfo

    func fetchServerInfo(from endpoint: HostEndpoint) async throws -> ServerInfo {
        info
    }
}
