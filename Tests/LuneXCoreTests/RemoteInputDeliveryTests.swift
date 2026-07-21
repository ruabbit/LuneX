import Foundation
import XCTest

final class RemoteInputDeliveryTests: XCTestCase {
    func testOrderedEventPlaintextMatchesReviewedVectors() throws {
        let fixture = try loadFixture()
        XCTAssertEqual(fixture.schemaVersion, 1)

        let button = try onePacket(.pointer(.button(button: .left, isDown: true, point: nil)))
        XCTAssertEqual(button.channelID, RemoteInputWireCodec.mouseChannel)
        XCTAssertTrue(button.reliable)
        XCTAssertEqual(button.plaintext.bytes, try Data(hex: fixture.pointerButtonPacketHex))

        let scroll = try RemoteInputWireCodec.outboundPackets(for: .pointer(.scroll(
            deltaX: 40,
            deltaY: -120,
            point: nil
        )))
        XCTAssertEqual(scroll.map(\.channelID), [
            RemoteInputWireCodec.mouseChannel,
            RemoteInputWireCodec.mouseChannel
        ])
        XCTAssertTrue(scroll.allSatisfy(\.reliable))
        XCTAssertEqual(scroll.map(\.plaintext.bytes), [
            try Data(hex: fixture.verticalScrollPacketHex),
            try Data(hex: fixture.horizontalScrollPacketHex)
        ])

        let touch = try onePacket(.touch(TouchInputEvent(
            id: 42,
            phase: .moved,
            point: RemotePoint(x: 960, y: 270),
            pressure: 0.75,
            referenceSize: PixelSize(width: 1920, height: 1080)
        )))
        XCTAssertEqual(touch.channelID, RemoteInputWireCodec.touchChannel)
        XCTAssertEqual(touch.plaintext.bytes, try Data(hex: fixture.touchPacketHex))

        let clipboard = try RemoteInputWireCodec.outboundPackets(for: .clipboard(ClipboardInputEvent(
            text: "A🙂"
        )))
        XCTAssertEqual(clipboard.map(\.channelID), [
            RemoteInputWireCodec.utf8Channel,
            RemoteInputWireCodec.utf8Channel
        ])
        XCTAssertEqual(
            clipboard.map(\.plaintext.bytes),
            try fixture.clipboardPacketsHex.map { try Data(hex: $0) }
        )
    }

    func testKeyboardEventUsesKeyboardChannelAndPreservesFields() throws {
        let packet = try onePacket(.keyboard(KeyboardInputEvent(
            rawKeyCode: 0x41,
            characters: "a",
            isDown: true,
            modifiers: [.shift, .control],
            isRepeat: true
        )))

        XCTAssertEqual(packet.channelID, RemoteInputWireCodec.keyboardChannel)
        XCTAssertEqual([UInt8](packet.plaintext.bytes), [
            0x00, 0x00, 0x00, 0x0A,
            0x03, 0x00, 0x00, 0x00,
            0x00, 0x41, 0x00, 0x03, 0x00, 0x00
        ])
    }

    func testInvalidTouchClipboardAndUnsupportedEventsFailClosed() throws {
        let invalidTouches = [
            TouchInputEvent(
                id: -1,
                phase: .began,
                point: RemotePoint(x: 0, y: 0),
                pressure: 0,
                referenceSize: PixelSize(width: 1920, height: 1080)
            ),
            TouchInputEvent(
                id: 1,
                phase: .moved,
                point: RemotePoint(x: .nan, y: 0),
                pressure: 0.5,
                referenceSize: PixelSize(width: 1920, height: 1080)
            ),
            TouchInputEvent(
                id: 1,
                phase: .moved,
                point: RemotePoint(x: 1, y: 1),
                pressure: 2,
                referenceSize: .zero
            )
        ]
        for touch in invalidTouches {
            XCTAssertThrowsError(try RemoteInputWireCodec.outboundPackets(for: .touch(touch))) { error in
                XCTAssertEqual(error as? RemoteInputCodecError, .invalidEvent)
            }
        }

        XCTAssertEqual(
            try RemoteInputWireCodec.outboundPackets(for: .clipboard(ClipboardInputEvent(text: ""))),
            []
        )
        XCTAssertThrowsError(try RemoteInputWireCodec.outboundPackets(for: .clipboard(
            ClipboardInputEvent(text: String(repeating: "a", count: 4_097))
        ))) { error in
            XCTAssertEqual(error as? RemoteInputCodecError, .clipboardTooLarge)
        }
        XCTAssertThrowsError(try RemoteInputWireCodec.outboundPackets(for: .pointer(.relativeMove(
            deltaX: 1,
            deltaY: 1,
            buttons: []
        )))) { error in
            XCTAssertEqual(error as? RemoteInputCodecError, .unsupportedEvent)
        }
        XCTAssertThrowsError(try RemoteInputWireCodec.outboundPackets(for: .gameController(
            GameControllerInputEvent(
                controllerID: "fixture",
                playerIndex: 0,
                element: .a,
                value: 1,
                isPressed: true
            )
        ))) { error in
            XCTAssertEqual(error as? RemoteInputCodecError, .unsupportedEvent)
        }
    }

    func testControlInputSharesSequenceWithStartAndIDR() async throws {
        let key = Data((0..<16).map(UInt8.init))
        let driver = InputControlDriverStub()
        let channel = MoonlightControlChannel(driver: driver)
        try await channel.connect(
            endpoint: RuntimeNetworkEndpoint(host: "example.invalid", port: 47_999, transport: .udp),
            connectData: 7,
            encryptionKey: key
        )
        try await channel.requestIDR()
        try await channel.activateInput(configuration: inputConfiguration(key: key))
        let keyboard = try onePacket(.keyboard(KeyboardInputEvent(
            rawKeyCode: 0x41,
            characters: nil,
            isDown: true,
            modifiers: [],
            isRepeat: false
        )))
        try await channel.sendInput(
            keyboard.plaintext,
            channelID: keyboard.channelID,
            reliable: keyboard.reliable
        )

        let sends = await driver.recordedSends()
        let opened = try sends.map {
            try EncryptedControlFrameCodec.open($0.payload, key: key, origin: .client)
        }
        XCTAssertEqual(opened.map(\.sequence), [0, 1, 2, 3])
        XCTAssertEqual(opened.map(\.message.type), [
            MoonlightControlProtocol.startA.type,
            MoonlightControlProtocol.startB.type,
            MoonlightControlProtocol.requestIDR.type,
            AuthenticatedRemoteInputContext.inputControlType
        ])
        XCTAssertEqual(sends.map(\.channelID), [0, 0, 1, RemoteInputWireCodec.keyboardChannel])
        XCTAssertTrue(sends.allSatisfy(\.reliable))
        await channel.stop()
    }

    func testControlInputRejectsInactiveMismatchedAndStoppedSessions() async throws {
        let key = Data(repeating: 0x31, count: 16)
        let channel = MoonlightControlChannel(driver: InputControlDriverStub())
        let packet = try onePacket(.pointer(.button(button: .right, isDown: false, point: nil)))

        await assertAsyncError(.invalidState) {
            try await channel.sendInput(packet.plaintext, channelID: packet.channelID, reliable: true)
        }
        try await channel.connect(
            endpoint: RuntimeNetworkEndpoint(host: "example.invalid", port: 47_999, transport: .udp),
            connectData: 0,
            encryptionKey: key
        )
        await assertAsyncError(.inputNotActive) {
            try await channel.sendInput(packet.plaintext, channelID: packet.channelID, reliable: true)
        }
        await assertAsyncError(.inputKeyMismatch) {
            try await channel.activateInput(configuration: self.inputConfiguration(
                key: Data(repeating: 0x32, count: 16)
            ))
        }
        try await channel.activateInput(configuration: inputConfiguration(key: key))
        await channel.stop()
        await assertAsyncError(.invalidState) {
            try await channel.sendInput(packet.plaintext, channelID: packet.channelID, reliable: true)
        }
    }

    func testUncertainInputSendConsumesSharedSequence() async throws {
        let key = Data(repeating: 0x44, count: 16)
        let driver = InputControlDriverStub(failingSendCalls: [3])
        let channel = MoonlightControlChannel(driver: driver)
        try await channel.connect(
            endpoint: RuntimeNetworkEndpoint(host: "example.invalid", port: 47_999, transport: .udp),
            connectData: 0,
            encryptionKey: key
        )
        try await channel.activateInput(configuration: inputConfiguration(key: key))
        let packet = try onePacket(.pointer(.button(button: .left, isDown: true, point: nil)))
        do {
            try await channel.sendInput(packet.plaintext, channelID: packet.channelID, reliable: true)
            XCTFail("Expected the scripted input send to fail.")
        } catch let error as ENetTransportError {
            XCTAssertEqual(error, .sendFailed)
        }
        try await channel.requestIDR()

        let sends = await driver.recordedSends()
        let opened = try sends.map {
            try EncryptedControlFrameCodec.open($0.payload, key: key, origin: .client)
        }
        XCTAssertEqual(opened.map(\.sequence), [0, 1, 2, 3])
        XCTAssertEqual(opened.suffix(2).map(\.message.type), [
            AuthenticatedRemoteInputContext.inputControlType,
            MoonlightControlProtocol.requestIDR.type
        ])
        await channel.stop()
    }

    func testProviderDeliversEveryStageSevenTwoEventInSubmissionOrder() async throws {
        let sender = InputSenderStub()
        let provider = MoonlightRemoteInputProvider(sender: sender)
        let sessionID = UUID()
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 5, count: 16))
        )

        try await provider.send(.keyboard(KeyboardInputEvent(
            rawKeyCode: 0x41,
            characters: nil,
            isDown: true,
            modifiers: [],
            isRepeat: false
        )), sessionID: sessionID)
        try await provider.send(.pointer(.button(button: .right, isDown: true, point: nil)), sessionID: sessionID)
        try await provider.send(.pointer(.scroll(deltaX: 40, deltaY: -120, point: nil)), sessionID: sessionID)
        try await provider.send(.touch(TouchInputEvent(
            id: 9,
            phase: .began,
            point: RemotePoint(x: 100, y: 200),
            pressure: 0.25,
            referenceSize: PixelSize(width: 1920, height: 1080)
        )), sessionID: sessionID)
        try await provider.send(.clipboard(ClipboardInputEvent(text: "AB")), sessionID: sessionID)

        let sends = await sender.recordedSends()
        XCTAssertEqual(sends.map(\.channelID), [
            RemoteInputWireCodec.keyboardChannel,
            RemoteInputWireCodec.mouseChannel,
            RemoteInputWireCodec.mouseChannel,
            RemoteInputWireCodec.mouseChannel,
            RemoteInputWireCodec.touchChannel,
            RemoteInputWireCodec.utf8Channel,
            RemoteInputWireCodec.utf8Channel
        ])
        XCTAssertTrue(sends.allSatisfy(\.reliable))
        await provider.stopInput(sessionID: sessionID)
    }

    func testProviderKeepsClipboardPacketsAtomicAcrossConcurrentEvents() async throws {
        let sender = InputSenderStub(delayNanosecondsByCall: [1: 50_000_000])
        let provider = MoonlightRemoteInputProvider(sender: sender)
        let sessionID = UUID()
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 1, count: 16))
        )

        let clipboard = Task {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "AB")), sessionID: sessionID)
        }
        try await waitForSendCount(1, sender: sender)
        let keyboard = Task {
            try await provider.send(.keyboard(KeyboardInputEvent(
                rawKeyCode: 0x43,
                characters: nil,
                isDown: true,
                modifiers: [],
                isRepeat: false
            )), sessionID: sessionID)
        }
        try await clipboard.value
        try await keyboard.value

        let sends = await sender.recordedSends()
        XCTAssertEqual(sends.map(\.channelID), [
            RemoteInputWireCodec.utf8Channel,
            RemoteInputWireCodec.utf8Channel,
            RemoteInputWireCodec.keyboardChannel
        ])
        XCTAssertEqual(sends.prefix(2).map(\.packet.bytes.last), [0x41, 0x42])
        await provider.stopInput(sessionID: sessionID)
    }

    func testProviderRejectsWrongSessionAndFailsCurrentPendingAndLateSends() async throws {
        let sender = InputSenderStub(
            delayNanosecondsByCall: [1: 50_000_000],
            failingCalls: [1]
        )
        let provider = MoonlightRemoteInputProvider(sender: sender)
        let sessionID = UUID()
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 2, count: 16))
        )

        await assertProviderError(.sessionMismatch) {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "wrong")), sessionID: UUID())
        }
        let current = Task {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "A")), sessionID: sessionID)
        }
        try await waitForSendCount(1, sender: sender)
        let pending = Task {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "B")), sessionID: sessionID)
        }
        try await Task.sleep(nanoseconds: 5_000_000)
        await assertTaskError(.deliveryFailed, task: current)
        await assertTaskError(.deliveryFailed, task: pending)
        await assertProviderError(.inactiveSession) {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "late")), sessionID: sessionID)
        }
        let deactivateCount = await sender.deactivateCount()
        XCTAssertEqual(deactivateCount, 1)
    }

    func testProviderRejectsSendBeforeStartAndUnsupportedEventWithoutDeactivating() async throws {
        let sender = InputSenderStub()
        let provider = MoonlightRemoteInputProvider(sender: sender)
        let sessionID = UUID()
        await assertProviderError(.inactiveSession) {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "A")), sessionID: sessionID)
        }
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 3, count: 16))
        )
        do {
            try await provider.send(.pointer(.absoluteMove(point: RemotePoint(x: 1, y: 1), buttons: [])), sessionID: sessionID)
            XCTFail("Expected unsupported pointer movement to fail.")
        } catch let error as RemoteInputCodecError {
            XCTAssertEqual(error, .unsupportedEvent)
        }
        try await provider.send(.clipboard(ClipboardInputEvent(text: "A")), sessionID: sessionID)
        let sendCount = await sender.recordedSends().count
        XCTAssertEqual(sendCount, 1)
        await provider.stopInput(sessionID: sessionID)
    }

    func testProviderStopRejectsLateSendAndDeactivatesOnce() async throws {
        let sender = InputSenderStub()
        let provider = MoonlightRemoteInputProvider(sender: sender)
        let sessionID = UUID()
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 4, count: 16))
        )

        await provider.stopInput(sessionID: sessionID)
        await provider.stopInput(sessionID: sessionID)
        await assertProviderError(.inactiveSession) {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "late")), sessionID: sessionID)
        }
        let deactivateCount = await sender.deactivateCount()
        XCTAssertEqual(deactivateCount, 1)
    }

    private func onePacket(_ event: RemoteInputEvent) throws -> RemoteInputOutboundPacket {
        let packets = try RemoteInputWireCodec.outboundPackets(for: event)
        XCTAssertEqual(packets.count, 1)
        return try XCTUnwrap(packets.first)
    }

    private func inputConfiguration(key: Data) -> NegotiatedInputConfiguration {
        NegotiatedInputConfiguration(
            keyMaterial: RemoteInputKeyMaterial(keyID: 7, key: key),
            encrypted: true,
            maximumMessageSize: RemoteInputWireCodec.maximumPacketSize
        )
    }

    private func inputEndpoint() -> RuntimeNetworkEndpoint {
        RuntimeNetworkEndpoint(host: "example.invalid", port: 35_043, transport: .tcp)
    }

    private func loadFixture() throws -> OrderedInputFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/input/ordered-event-vectors.json")
        return try JSONDecoder().decode(OrderedInputFixture.self, from: Data(contentsOf: url))
    }

    private func waitForSendCount(_ count: Int, sender: InputSenderStub) async throws {
        for _ in 0..<200 {
            if await sender.recordedSends().count >= count { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("Timed out waiting for the deterministic sender.")
    }

    private func assertAsyncError(
        _ expected: ControlChannelError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected control operation to fail.")
        } catch let error as ControlChannelError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func assertProviderError(
        _ expected: RemoteInputRuntimeError,
        operation: () async throws -> Void
    ) async {
        do {
            try await operation()
            XCTFail("Expected provider operation to fail.")
        } catch let error as RemoteInputRuntimeError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func assertTaskError(
        _ expected: RemoteInputRuntimeError,
        task: Task<Void, Error>
    ) async {
        do {
            try await task.value
            XCTFail("Expected delivery task to fail.")
        } catch let error as RemoteInputRuntimeError {
            XCTAssertEqual(error, expected)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private struct OrderedInputFixture: Decodable {
    var clipboardPacketsHex: [String]
    var horizontalScrollPacketHex: String
    var pointerButtonPacketHex: String
    var schemaVersion: Int
    var touchPacketHex: String
    var verticalScrollPacketHex: String
}

private struct InputSendRecord: Equatable, Sendable {
    var packet: RemoteInputPlaintextPacket
    var channelID: UInt8
    var reliable: Bool
}

private actor InputSenderStub: AuthenticatedInputFrameSending {
    private let delayNanosecondsByCall: [Int: UInt64]
    private let failingCalls: Set<Int>
    private var sends: [InputSendRecord] = []
    private var deactivations = 0

    init(
        delayNanosecondsByCall: [Int: UInt64] = [:],
        failingCalls: Set<Int> = []
    ) {
        self.delayNanosecondsByCall = delayNanosecondsByCall
        self.failingCalls = failingCalls
    }

    func activateInput(configuration: NegotiatedInputConfiguration) async throws {
        try configuration.validate()
    }

    func sendInput(
        _ packet: RemoteInputPlaintextPacket,
        channelID: UInt8,
        reliable: Bool
    ) async throws {
        sends.append(InputSendRecord(packet: packet, channelID: channelID, reliable: reliable))
        let call = sends.count
        if let delay = delayNanosecondsByCall[call] {
            try await Task.sleep(nanoseconds: delay)
        }
        if failingCalls.contains(call) {
            throw ENetTransportError.sendFailed
        }
    }

    func deactivateInput() async {
        deactivations += 1
    }

    func recordedSends() -> [InputSendRecord] {
        sends
    }

    func deactivateCount() -> Int {
        deactivations
    }
}

private struct InputControlSendRecord: Sendable {
    var payload: Data
    var channelID: UInt8
    var reliable: Bool
}

private actor InputControlDriverStub: ENetConnectionDriving {
    private let failingSendCalls: Set<Int>
    private var sends: [InputControlSendRecord] = []

    init(failingSendCalls: Set<Int> = []) {
        self.failingSendCalls = failingSendCalls
    }

    func connect(
        host: String,
        port: UInt16,
        channelCount: UInt8,
        connectData: UInt32,
        timeoutMilliseconds: UInt32
    ) async throws {
        _ = (host, port, channelCount, connectData, timeoutMilliseconds)
    }

    func send(_ payload: Data, channelID: UInt8, reliable: Bool) async throws {
        sends.append(InputControlSendRecord(payload: payload, channelID: channelID, reliable: reliable))
        if failingSendCalls.contains(sends.count) {
            throw ENetTransportError.sendFailed
        }
    }

    func service(timeoutMilliseconds: UInt32) async throws -> ENetServiceEvent {
        _ = timeoutMilliseconds
        return .idle
    }

    func disconnect() async {}

    func recordedSends() -> [InputControlSendRecord] {
        sends
    }
}

private extension Data {
    init(hex: String) throws {
        let compact = hex.filter { !$0.isWhitespace }
        guard compact.count.isMultiple(of: 2) else { throw RemoteInputCodecError.invalidPacket }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(compact.count / 2)
        var index = compact.startIndex
        while index < compact.endIndex {
            let next = compact.index(index, offsetBy: 2)
            guard let byte = UInt8(compact[index..<next], radix: 16) else {
                throw RemoteInputCodecError.invalidPacket
            }
            bytes.append(byte)
            index = next
        }
        self = Data(bytes)
    }
}
