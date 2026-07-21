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
        XCTAssertEqual(store.events[0].category, .input)
        XCTAssertEqual(store.events[0].severity, .info)
        XCTAssertEqual(store.events[0].code, "complete")
    }

    @MainActor
    func testApplicationDiagnosticsClassifyEveryRuntimeFailureDomain() {
        let pairing = ApplicationDiagnosticFactory.pairingFailure(PairingFailure(
            code: .invalidPIN,
            message: "host detail must not be copied"
        ))
        let transport = ApplicationDiagnosticFactory.streamFailure(NetworkChannelError.closed)
        let decoder = ApplicationDiagnosticFactory.streamFailure(VideoDecoderError.noActiveSession)
        let audio = ApplicationDiagnosticFactory.streamFailure(OpusDecoderError.closed)
        let input = ApplicationDiagnosticFactory.streamFailure(RemoteInputRuntimeError.deliveryFailed)

        XCTAssertEqual(pairing.category, .pairing)
        XCTAssertEqual(pairing.action, .verifyPIN)
        XCTAssertEqual(transport.category, .transport)
        XCTAssertEqual(transport.action, .retryStream)
        XCTAssertEqual(decoder.category, .decoder)
        XCTAssertEqual(decoder.action, .reviewStreamSettings)
        XCTAssertEqual(audio.category, .audio)
        XCTAssertEqual(audio.action, .checkAudioOutput)
        XCTAssertEqual(input.category, .input)
        XCTAssertEqual(input.action, .reconnectInput)
    }

    @MainActor
    func testUnknownFailureNeverCopiesSecretBearingDescription() {
        let diagnostic = ApplicationDiagnosticFactory.streamFailure(
            SecretBearingDiagnosticError()
        )
        let store = DiagnosticsStore()

        store.record(diagnostic)

        let event = store.events[0]
        XCTAssertEqual(event.code, "session_failed")
        XCTAssertEqual(event.message, "The streaming transport stopped unexpectedly.")
        XCTAssertFalse(event.message.contains("1234"))
        XCTAssertFalse(event.message.localizedCaseInsensitiveContains("authorization"))
    }

    @MainActor
    func testPlainDiagnosticMessagesAlsoRejectEmbeddedSecrets() {
        let store = DiagnosticsStore()

        store.record("Request failed Authorization: Basic private-value")

        XCTAssertEqual(store.events[0].message, "<redacted>")
    }

    @MainActor
    func testActionableStoreIsBoundedAndRetainsRecoveryAction() {
        let store = DiagnosticsStore(capacity: 2)
        store.record("first")
        store.record(ApplicationDiagnosticFactory.streamUnavailable)
        store.record(ApplicationDiagnosticFactory.streamFailure(OpusDecoderError.closed))

        XCTAssertEqual(store.events.count, 2)
        XCTAssertEqual(store.events.map(\.category), [.transport, .audio])
        XCTAssertEqual(store.latestActionableEvent?.action, .checkAudioOutput)
    }

    @MainActor
    func testControllerFeedbackDiagnosticDoesNotExposeControllerIdentity() {
        let diagnostic = ApplicationDiagnosticFactory.remoteFeedback(
            RemoteInputFeedbackDiagnostic(
                controllerID: "private-controller-id",
                controllerIndex: 3,
                command: .rumble,
                reason: .unsupportedCapability
            )
        )

        XCTAssertEqual(diagnostic.category, .input)
        XCTAssertEqual(diagnostic.severity, .warning)
        XCTAssertEqual(diagnostic.action, .useSupportedController)
        XCTAssertFalse(diagnostic.summary.contains("private-controller-id"))
        XCTAssertFalse(diagnostic.code.contains("3"))
    }
}

private struct SecretBearingDiagnosticError: Error, CustomStringConvertible {
    var description: String {
        "Authorization: Basic secret; PIN=1234"
    }
}
