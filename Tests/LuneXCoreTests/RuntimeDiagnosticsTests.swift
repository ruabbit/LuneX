import Foundation
import XCTest

final class RuntimeDiagnosticsTests: XCTestCase {
    func testRecorderRedactsSecretAndPrivateFields() async {
        let recorder = RuntimeDiagnosticsRecorder()
        let event = await recorder.record(
            sessionID: nil,
            subsystem: "pairing",
            stage: "challenge",
            severity: .info,
            code: "request",
            fields: [
                RuntimeDiagnosticField("pin", .string("1234")),
                RuntimeDiagnosticField("privateKeyDER", .string("sensitive")),
                RuntimeDiagnosticField("endpoint", .string("10.0.0.1:47984")),
                RuntimeDiagnosticField("packetCount", .integer(3))
            ]
        )

        XCTAssertEqual(event.fields["pin"], "<redacted>")
        XCTAssertEqual(event.fields["privateKeyDER"], "<redacted>")
        XCTAssertEqual(event.fields["endpoint"], "<private>")
        XCTAssertEqual(event.fields["packetCount"], "3")
    }

    func testEmbeddedSecretIsRedactedEvenWhenMarkedPublic() async {
        let recorder = RuntimeDiagnosticsRecorder()
        let event = await recorder.record(
            sessionID: nil,
            subsystem: "network",
            stage: "request",
            severity: .warning,
            code: "rejected",
            fields: [
                RuntimeDiagnosticField("detail", .string("Authorization: Basic fixture"))
            ]
        )

        XCTAssertEqual(event.fields["detail"], "<redacted>")
    }

    func testStageTimingUsesMonotonicNanoseconds() async {
        let recorder = RuntimeDiagnosticsRecorder()
        let sessionID = UUID(uuidString: "7B1D927C-F4EC-484D-BCC8-662336101618")!
        let token = await recorder.beginStage(
            sessionID: sessionID,
            subsystem: "rtsp",
            stage: "negotiate",
            monotonicNanoseconds: 1_000_000
        )
        let event = await recorder.endStage(
            token,
            code: "ready",
            monotonicNanoseconds: 4_500_000,
            recordedAt: Date(timeIntervalSince1970: 50)
        )

        XCTAssertEqual(event.elapsedMilliseconds, 3.5)
        XCTAssertEqual(event.sessionID, sessionID)
        XCTAssertEqual(event.code, "ready")
    }

    func testRecorderCapacityAndSessionFilterAreBounded() async {
        let recorder = RuntimeDiagnosticsRecorder(capacity: 2)
        let firstSession = UUID(uuidString: "530645CD-D2D8-4D8D-88A7-A487C476C039")!
        let secondSession = UUID(uuidString: "C2491297-ADDF-4779-8EE0-4CE2792BF7D7")!
        _ = await recorder.record(
            sessionID: firstSession,
            subsystem: "one",
            stage: "one",
            severity: .debug,
            code: "one"
        )
        _ = await recorder.record(
            sessionID: firstSession,
            subsystem: "two",
            stage: "two",
            severity: .info,
            code: "two"
        )
        _ = await recorder.record(
            sessionID: secondSession,
            subsystem: "three",
            stage: "three",
            severity: .error,
            code: "three"
        )

        let all = await recorder.snapshot()
        let first = await recorder.snapshot(sessionID: firstSession)
        XCTAssertEqual(all.map(\.code), ["two", "three"])
        XCTAssertEqual(first.map(\.code), ["two"])
    }

    @MainActor
    func testDiagnosticsStoreReceivesOnlyRedactedRuntimeEvent() async {
        let recorder = RuntimeDiagnosticsRecorder()
        let runtimeEvent = await recorder.record(
            sessionID: nil,
            subsystem: "input",
            stage: "send",
            severity: .info,
            code: "complete",
            fields: [RuntimeDiagnosticField("remoteInputKey", .string("secret"))],
            elapsedMilliseconds: 1.25,
            recordedAt: Date(timeIntervalSince1970: 80)
        )
        let store = DiagnosticsStore()

        store.record(runtimeEvent: runtimeEvent)

        XCTAssertEqual(store.events.count, 1)
        XCTAssertTrue(store.events[0].message.contains("remoteInputKey=<redacted>"))
        XCTAssertFalse(store.events[0].message.contains("secret"))
    }
}
