import Foundation
import XCTest

final class PairingStateMachineTests: XCTestCase {
    func testDigestAlgorithmTracksServerMajorVersion() async {
        let modern = PairingStateMachine(hostID: UUID(uuidString: "A044F248-1312-4C1E-90B6-B79FB405F9C2")!)
        let legacy = PairingStateMachine(hostID: UUID(uuidString: "430450BC-FA8E-4862-9FA2-62644A684FA6")!)

        let modernSnapshot = await modern.begin(serverMajorVersion: 7)
        let legacySnapshot = await legacy.begin(serverMajorVersion: 6)

        XCTAssertEqual(modernSnapshot.digestAlgorithm, .sha256)
        XCTAssertEqual(legacySnapshot.digestAlgorithm, .sha1)
        XCTAssertEqual(modernSnapshot.stage, .waitingForPIN)
    }

    func testRejectsInvalidPIN() async throws {
        for pin in ["12AB", "123", "12345", "１２３４", "١٢٣٤"] {
            let machine = PairingStateMachine(hostID: UUID())
            await machine.begin(serverMajorVersion: 7)

            do {
                try await machine.submitPIN(pin)
                XCTFail("Expected invalid PIN failure for \(pin)")
            } catch let failure as PairingFailure {
                XCTAssertEqual(failure.code, .invalidPIN)
            }

            let snapshot = await machine.snapshot
            XCTAssertEqual(snapshot.stage, .waitingForPIN)
        }
    }

    func testRejectsInvalidTransition() async {
        let machine = PairingStateMachine(hostID: UUID(uuidString: "D5CD9001-23B4-4B8E-82C5-E83A6877D983")!)

        do {
            try await machine.markSecretsExchanged()
            XCTFail("Expected invalid transition")
        } catch let failure as PairingFailure {
            XCTAssertEqual(failure.code, .invalidTransition)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testPinsServerIdentityAndMarksHostPaired() async throws {
        let host = MoonlightHost(
            id: UUID(uuidString: "75DB6123-8DCB-4864-B3C5-51AF7DC46614")!,
            name: "Studio PC",
            address: "192.168.1.50",
            pairingState: .unpaired,
            reachability: .online
        )
        let identity = PairingServerIdentity(
            certificateDER: Data([1, 2, 3, 4]),
            certificateSHA256: "abcdef",
            serverMajorVersion: 7
        )
        let pairedAt = Date(timeIntervalSince1970: 1_800)
        let machine = PairingStateMachine(hostID: host.id)

        await machine.begin(serverMajorVersion: identity.serverMajorVersion)
        try await machine.submitPIN("1234")
        try await machine.markSecretsExchanged()
        let result = try await machine.pinServerIdentity(identity, for: host, pairedAt: pairedAt)
        let snapshot = await machine.snapshot

        XCTAssertEqual(snapshot.stage, .paired)
        XCTAssertEqual(result.digestAlgorithm, .sha256)
        XCTAssertEqual(result.host.pairingState, .paired)
        XCTAssertEqual(result.host.pinnedIdentity?.certificateSHA256, "abcdef")
        XCTAssertEqual(result.host.pinnedIdentity?.pairedAt, pairedAt)
    }
}
