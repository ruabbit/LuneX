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

        let relativeMove = try onePacket(.pointer(.relativeMove(
            deltaX: 300,
            deltaY: -200,
            buttons: []
        )))
        XCTAssertEqual(relativeMove.channelID, RemoteInputWireCodec.mouseChannel)
        XCTAssertTrue(relativeMove.reliable)
        XCTAssertEqual(relativeMove.plaintext.bytes, try Data(hex: fixture.relativeMovePacketHex))

        let absoluteMove = try onePacket(.pointer(.absoluteMove(
            point: RemotePoint(x: 960, y: 540),
            referenceSize: PixelSize(width: 1920, height: 1080),
            buttons: []
        )))
        XCTAssertEqual(absoluteMove.channelID, RemoteInputWireCodec.mouseChannel)
        XCTAssertTrue(absoluteMove.reliable)
        XCTAssertEqual(absoluteMove.plaintext.bytes, try Data(hex: fixture.absoluteMovePacketHex))

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

    func testLargeRelativeMovementSplitsWithoutLosingEitherAxis() throws {
        let expectedX = Int(Int16.max) * RemoteInputWireCodec.maximumRelativeMovementPackets
        let expectedY = Int(Int16.min) * RemoteInputWireCodec.maximumRelativeMovementPackets
        let packets = try RemoteInputWireCodec.outboundPackets(for: .pointer(.relativeMove(
            deltaX: Double(expectedX),
            deltaY: Double(expectedY),
            buttons: [.left]
        )))

        XCTAssertEqual(packets.count, RemoteInputWireCodec.maximumRelativeMovementPackets)
        XCTAssertTrue(packets.allSatisfy {
            $0.channelID == RemoteInputWireCodec.mouseChannel && $0.reliable
        })
        let deltas = try packets.map { try relativeMovementDelta($0.plaintext) }
        XCTAssertEqual(deltas.reduce(0) { $0 + Int($1.x) }, expectedX)
        XCTAssertEqual(deltas.reduce(0) { $0 + Int($1.y) }, expectedY)
    }

    func testInvalidRelativeAndAbsoluteMovementFailsClosed() throws {
        let maximumPositiveDelta = Double(Int16.max) * Double(RemoteInputWireCodec.maximumRelativeMovementPackets)
        let maximumNegativeDelta = Double(Int16.min) * Double(RemoteInputWireCodec.maximumRelativeMovementPackets)
        let invalidRelativeValues: [(Double, Double)] = [
            (.nan, 0),
            (0, .infinity),
            (maximumPositiveDelta + 1, 0),
            (0, maximumNegativeDelta - 1)
        ]
        for (deltaX, deltaY) in invalidRelativeValues {
            XCTAssertThrowsError(try RemoteInputWireCodec.outboundPackets(for: .pointer(.relativeMove(
                deltaX: deltaX,
                deltaY: deltaY,
                buttons: []
            )))) { error in
                XCTAssertEqual(error as? RemoteInputCodecError, .invalidEvent)
            }
        }

        let invalidAbsoluteValues: [(RemotePoint, PixelSize)] = [
            (RemotePoint(x: .nan, y: 0), PixelSize(width: 1920, height: 1080)),
            (RemotePoint(x: -1, y: 0), PixelSize(width: 1920, height: 1080)),
            (RemotePoint(x: 1921, y: 0), PixelSize(width: 1920, height: 1080)),
            (RemotePoint(x: 1, y: 1), .zero),
            (RemotePoint(x: 1, y: 1), PixelSize(width: Int(Int16.max) + 1, height: 1080))
        ]
        for (point, referenceSize) in invalidAbsoluteValues {
            XCTAssertThrowsError(try RemoteInputWireCodec.outboundPackets(for: .pointer(.absoluteMove(
                point: point,
                referenceSize: referenceSize,
                buttons: []
            )))) { error in
                XCTAssertEqual(error as? RemoteInputCodecError, .invalidEvent)
            }
        }
    }

    func testMovementCoalescerPreservesStateAndEventBarriers() {
        let relative = RemoteInputEvent.pointer(.relativeMove(deltaX: 10, deltaY: -4, buttons: [.left]))
        XCTAssertEqual(
            RemoteInputMovementCoalescer.coalesce(
                older: relative,
                newer: .pointer(.relativeMove(deltaX: 5, deltaY: 2, buttons: [.left]))
            ),
            .pointer(.relativeMove(deltaX: 15, deltaY: -2, buttons: [.left]))
        )
        XCTAssertNil(RemoteInputMovementCoalescer.coalesce(
            older: relative,
            newer: .pointer(.relativeMove(deltaX: 5, deltaY: 2, buttons: []))
        ))

        let referenceSize = PixelSize(width: 1920, height: 1080)
        let absolute = RemoteInputEvent.pointer(.absoluteMove(
            point: RemotePoint(x: 100, y: 200),
            referenceSize: referenceSize,
            buttons: []
        ))
        XCTAssertEqual(
            RemoteInputMovementCoalescer.coalesce(
                older: absolute,
                newer: .pointer(.absoluteMove(
                    point: RemotePoint(x: 300, y: 400),
                    referenceSize: referenceSize,
                    buttons: []
                ))
            ),
            .pointer(.absoluteMove(
                point: RemotePoint(x: 300, y: 400),
                referenceSize: referenceSize,
                buttons: []
            ))
        )
        XCTAssertNil(RemoteInputMovementCoalescer.coalesce(
            older: absolute,
            newer: .pointer(.absoluteMove(
                point: RemotePoint(x: 300, y: 400),
                referenceSize: PixelSize(width: 1280, height: 720),
                buttons: []
            ))
        ))
        XCTAssertNil(RemoteInputMovementCoalescer.coalesce(older: relative, newer: absolute))

        let barriers: [RemoteInputEvent] = [
            .keyboard(KeyboardInputEvent(
                rawKeyCode: 0x41,
                characters: nil,
                isDown: true,
                modifiers: [],
                isRepeat: false
            )),
            .pointer(.button(button: .left, isDown: false, point: nil)),
            .pointer(.scroll(deltaX: 0, deltaY: 1, point: nil)),
            .touch(TouchInputEvent(
                id: 1,
                phase: .moved,
                point: RemotePoint(x: 1, y: 1),
                pressure: 0.5,
                referenceSize: referenceSize
            )),
            .clipboard(ClipboardInputEvent(text: "barrier"))
        ]
        for barrier in barriers {
            XCTAssertNil(RemoteInputMovementCoalescer.coalesce(older: relative, newer: barrier))
            XCTAssertNil(RemoteInputMovementCoalescer.coalesce(older: barrier, newer: relative))
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

    func testProviderCoalescesPendingRelativeMovementAndCompletesEveryCallerAfterSend() async throws {
        let sender = InputSenderStub(delayNanosecondsByCall: [1: 100_000_000, 2: 50_000_000])
        let provider = MoonlightRemoteInputProvider(sender: sender)
        let completions = InputCompletionRecorder()
        let sessionID = UUID()
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 6, count: 16))
        )

        let barrier = Task {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "A")), sessionID: sessionID)
        }
        try await waitForSendCount(1, sender: sender)
        let firstMove = Task {
            try await provider.send(.pointer(.relativeMove(
                deltaX: 10,
                deltaY: 20,
                buttons: [.left]
            )), sessionID: sessionID)
            await completions.record(1)
        }
        try await Task.sleep(nanoseconds: 5_000_000)
        let secondMove = Task {
            try await provider.send(.pointer(.relativeMove(
                deltaX: 5,
                deltaY: -4,
                buttons: [.left]
            )), sessionID: sessionID)
            await completions.record(2)
        }

        try await waitForSendCount(2, sender: sender)
        let completionsDuringPhysicalSend = await completions.values()
        XCTAssertEqual(completionsDuringPhysicalSend, [])
        try await barrier.value
        try await firstMove.value
        try await secondMove.value

        let sends = await sender.recordedSends()
        XCTAssertEqual(sends.count, 2)
        XCTAssertEqual(try relativeMovementDelta(sends[1].packet), RelativeMovementDelta(x: 15, y: 16))
        let finalCompletions = await completions.values()
        XCTAssertEqual(Set(finalCompletions), Set([1, 2]))
        await provider.stopInput(sessionID: sessionID)
    }

    func testProviderCoalescesPendingAbsoluteMovementUsingCapturedReferenceSize() async throws {
        let sender = InputSenderStub(delayNanosecondsByCall: [1: 100_000_000])
        let provider = MoonlightRemoteInputProvider(sender: sender)
        let sessionID = UUID()
        let referenceSize = PixelSize(width: 1920, height: 1080)
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 7, count: 16))
        )

        let barrier = Task {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "A")), sessionID: sessionID)
        }
        try await waitForSendCount(1, sender: sender)
        let firstMove = Task {
            try await provider.send(.pointer(.absoluteMove(
                point: RemotePoint(x: 100, y: 200),
                referenceSize: referenceSize,
                buttons: []
            )), sessionID: sessionID)
        }
        try await Task.sleep(nanoseconds: 5_000_000)
        let secondMove = Task {
            try await provider.send(.pointer(.absoluteMove(
                point: RemotePoint(x: 300, y: 400),
                referenceSize: referenceSize,
                buttons: []
            )), sessionID: sessionID)
        }

        try await barrier.value
        try await firstMove.value
        try await secondMove.value
        let sends = await sender.recordedSends()
        XCTAssertEqual(sends.count, 2)
        let expected = try onePacket(.pointer(.absoluteMove(
            point: RemotePoint(x: 300, y: 400),
            referenceSize: referenceSize,
            buttons: []
        )))
        XCTAssertEqual(sends[1].packet, expected.plaintext)
        await provider.stopInput(sessionID: sessionID)
    }

    func testProviderDoesNotCoalesceAcrossButtonSnapshotOrStateTransition() async throws {
        let sender = InputSenderStub(delayNanosecondsByCall: [1: 100_000_000])
        let provider = MoonlightRemoteInputProvider(sender: sender)
        let sessionID = UUID()
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 8, count: 16))
        )

        let barrier = Task {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "A")), sessionID: sessionID)
        }
        try await waitForSendCount(1, sender: sender)
        let firstMove = Task {
            try await provider.send(.pointer(.relativeMove(deltaX: 1, deltaY: 2, buttons: [])), sessionID: sessionID)
        }
        try await Task.sleep(nanoseconds: 5_000_000)
        let buttonDown = Task {
            try await provider.send(.pointer(.button(button: .left, isDown: true, point: nil)), sessionID: sessionID)
        }
        try await Task.sleep(nanoseconds: 5_000_000)
        let secondMove = Task {
            try await provider.send(.pointer(.relativeMove(deltaX: 3, deltaY: 4, buttons: [.left])), sessionID: sessionID)
        }

        try await barrier.value
        try await firstMove.value
        try await buttonDown.value
        try await secondMove.value
        let sends = await sender.recordedSends()
        XCTAssertEqual(sends.count, 4)
        XCTAssertEqual(try relativeMovementDelta(sends[1].packet), RelativeMovementDelta(x: 1, y: 2))
        XCTAssertEqual(try relativeMovementDelta(sends[3].packet), RelativeMovementDelta(x: 3, y: 4))
        await provider.stopInput(sessionID: sessionID)
    }

    func testProviderFailsEveryCoalescedCallerOnTransportFailure() async throws {
        let sender = InputSenderStub(
            delayNanosecondsByCall: [1: 100_000_000, 2: 20_000_000],
            failingCalls: [2]
        )
        let provider = MoonlightRemoteInputProvider(sender: sender)
        let sessionID = UUID()
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 9, count: 16))
        )

        let barrier = Task {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "A")), sessionID: sessionID)
        }
        try await waitForSendCount(1, sender: sender)
        let firstMove = Task {
            try await provider.send(.pointer(.relativeMove(deltaX: 10, deltaY: 20, buttons: [])), sessionID: sessionID)
        }
        try await Task.sleep(nanoseconds: 5_000_000)
        let secondMove = Task {
            try await provider.send(.pointer(.relativeMove(deltaX: 5, deltaY: 6, buttons: [])), sessionID: sessionID)
        }

        try await barrier.value
        await assertTaskError(.deliveryFailed, task: firstMove)
        await assertTaskError(.deliveryFailed, task: secondMove)
        let sends = await sender.recordedSends()
        XCTAssertEqual(sends.count, 2)
        let deactivateCount = await sender.deactivateCount()
        XCTAssertEqual(deactivateCount, 1)
    }

    func testProviderStopFailsCurrentAndEveryCoalescedCaller() async throws {
        let sender = InputSenderStub(delayNanosecondsByCall: [1: 200_000_000])
        let provider = MoonlightRemoteInputProvider(sender: sender)
        let sessionID = UUID()
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 10, count: 16))
        )

        let current = Task {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "A")), sessionID: sessionID)
        }
        try await waitForSendCount(1, sender: sender)
        let firstMove = Task {
            try await provider.send(.pointer(.relativeMove(deltaX: 1, deltaY: 2, buttons: [])), sessionID: sessionID)
        }
        try await Task.sleep(nanoseconds: 5_000_000)
        let secondMove = Task {
            try await provider.send(.pointer(.relativeMove(deltaX: 3, deltaY: 4, buttons: [])), sessionID: sessionID)
        }
        try await Task.sleep(nanoseconds: 5_000_000)

        await provider.stopInput(sessionID: sessionID)
        await assertTaskError(.inactiveSession, task: current)
        await assertTaskError(.inactiveSession, task: firstMove)
        await assertTaskError(.inactiveSession, task: secondMove)
        let deactivateCount = await sender.deactivateCount()
        XCTAssertEqual(deactivateCount, 1)
    }

    func testProviderEnforcesCoalescedCallerBound() async throws {
        let sender = InputSenderStub(delayNanosecondsByCall: [1: 150_000_000])
        let provider = MoonlightRemoteInputProvider(
            sender: sender,
            deliveryLimits: RemoteInputDeliveryLimits(
                maximumPendingEvents: 2,
                maximumPendingPackets: 1,
                maximumPendingCalls: 2
            )
        )
        let sessionID = UUID()
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 11, count: 16))
        )

        let barrier = Task {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "A")), sessionID: sessionID)
        }
        try await waitForSendCount(1, sender: sender)
        let firstMove = Task {
            try await provider.send(.pointer(.relativeMove(deltaX: 1, deltaY: 1, buttons: [])), sessionID: sessionID)
        }
        try await Task.sleep(nanoseconds: 5_000_000)
        let secondMove = Task {
            try await provider.send(.pointer(.relativeMove(deltaX: 2, deltaY: 2, buttons: [])), sessionID: sessionID)
        }
        try await Task.sleep(nanoseconds: 5_000_000)
        await assertProviderError(.queueFull) {
            try await provider.send(.pointer(.relativeMove(deltaX: 3, deltaY: 3, buttons: [])), sessionID: sessionID)
        }

        try await barrier.value
        try await firstMove.value
        try await secondMove.value
        let sends = await sender.recordedSends()
        XCTAssertEqual(sends.count, 2)
        XCTAssertEqual(try relativeMovementDelta(sends[1].packet), RelativeMovementDelta(x: 3, y: 3))
        await provider.stopInput(sessionID: sessionID)
    }

    func testProviderRejectsCoalescingThatWouldExceedPendingPacketBound() async throws {
        let sender = InputSenderStub(delayNanosecondsByCall: [1: 150_000_000])
        let provider = MoonlightRemoteInputProvider(
            sender: sender,
            deliveryLimits: RemoteInputDeliveryLimits(
                maximumPendingEvents: 2,
                maximumPendingPackets: 1,
                maximumPendingCalls: 10
            )
        )
        let sessionID = UUID()
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 12, count: 16))
        )

        let barrier = Task {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "A")), sessionID: sessionID)
        }
        try await waitForSendCount(1, sender: sender)
        let pendingMove = Task {
            try await provider.send(.pointer(.relativeMove(deltaX: 1, deltaY: 0, buttons: [])), sessionID: sessionID)
        }
        try await Task.sleep(nanoseconds: 5_000_000)
        await assertProviderError(.queueFull) {
            try await provider.send(.pointer(.relativeMove(
                deltaX: Double(Int16.max),
                deltaY: 0,
                buttons: []
            )), sessionID: sessionID)
        }

        try await barrier.value
        try await pendingMove.value
        let sends = await sender.recordedSends()
        XCTAssertEqual(sends.count, 2)
        XCTAssertEqual(try relativeMovementDelta(sends[1].packet), RelativeMovementDelta(x: 1, y: 0))
        await provider.stopInput(sessionID: sessionID)
    }

    func testProviderFallsBackToSeparateDeliveriesWhenCombinedDeltaExceedsCodecBound() async throws {
        let sender = InputSenderStub(delayNanosecondsByCall: [1: 150_000_000])
        let provider = MoonlightRemoteInputProvider(sender: sender)
        let sessionID = UUID()
        let maximumDelta = Int(Int16.max) * RemoteInputWireCodec.maximumRelativeMovementPackets
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 13, count: 16))
        )

        let barrier = Task {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "A")), sessionID: sessionID)
        }
        try await waitForSendCount(1, sender: sender)
        let maximumMove = Task {
            try await provider.send(.pointer(.relativeMove(
                deltaX: Double(maximumDelta),
                deltaY: 0,
                buttons: []
            )), sessionID: sessionID)
        }
        try await Task.sleep(nanoseconds: 5_000_000)
        let remainderMove = Task {
            try await provider.send(.pointer(.relativeMove(deltaX: 1, deltaY: 0, buttons: [])), sessionID: sessionID)
        }

        try await barrier.value
        try await maximumMove.value
        try await remainderMove.value
        let sends = await sender.recordedSends()
        XCTAssertEqual(sends.count, 1 + RemoteInputWireCodec.maximumRelativeMovementPackets + 1)
        let movementDeltas = try sends.dropFirst().map { try relativeMovementDelta($0.packet) }
        XCTAssertEqual(movementDeltas.reduce(0) { $0 + Int($1.x) }, maximumDelta + 1)
        XCTAssertEqual(movementDeltas.reduce(0) { $0 + Int($1.y) }, 0)
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

    func testProviderRejectsSendBeforeStartAndStillUnsupportedEventWithoutDeactivating() async throws {
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
            try await provider.send(.tvRemote(TVRemoteInputEvent(
                button: .playPause,
                isDown: true
            )), sessionID: sessionID)
            XCTFail("Expected unsupported TV remote input to fail.")
        } catch let error as RemoteInputCodecError {
            XCTAssertEqual(error, .unsupportedEvent)
        }
        try await provider.send(.clipboard(ClipboardInputEvent(text: "A")), sessionID: sessionID)
        let sendCount = await sender.recordedSends().count
        XCTAssertEqual(sendCount, 1)
        await provider.stopInput(sessionID: sessionID)
    }

    func testProviderRegistersControllerAccumulatesFullStateAndDisconnectsWithMask() async throws {
        let sender = InputSenderStub()
        let provider = MoonlightRemoteInputProvider(sender: sender)
        let sessionID = UUID()
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 0x31, count: 16))
        )

        try await provider.send(.gameController(GameControllerInputEvent(
            controllerID: "controller-two",
            playerIndex: 2,
            element: .a,
            value: 1,
            isPressed: true
        )), sessionID: sessionID)
        try await provider.send(.gameController(GameControllerInputEvent(
            controllerID: "controller-two",
            playerIndex: 2,
            element: .leftThumbstickX,
            value: 0.5,
            isPressed: true
        )), sessionID: sessionID)

        var sends = await sender.recordedSends()
        XCTAssertEqual(sends.count, 4)
        XCTAssertEqual(sends.map(\.channelID), [0x11, 0x11, 0x11, 0x11])
        XCTAssertTrue(sends.allSatisfy(\.reliable))
        XCTAssertEqual([UInt8](sends[0].packet.bytes)[8], 1)
        let pressed = try controllerState(from: sends[2].packet)
        XCTAssertEqual(pressed.controllerIndex, 1)
        XCTAssertEqual(pressed.activeMask, 0x0002)
        XCTAssertEqual(pressed.buttons & RemoteControllerButtonFlags.a.rawValue, RemoteControllerButtonFlags.a.rawValue)
        XCTAssertEqual(pressed.leftStickX, 0)
        let moved = try controllerState(from: sends[3].packet)
        XCTAssertEqual(moved.buttons & RemoteControllerButtonFlags.a.rawValue, RemoteControllerButtonFlags.a.rawValue)
        XCTAssertEqual(moved.leftStickX, 16_384)

        try await provider.send(.controllerDisconnected(controllerID: "controller-two"), sessionID: sessionID)
        sends = await sender.recordedSends()
        let disconnected = try controllerState(from: try XCTUnwrap(sends.last).packet)
        XCTAssertEqual(disconnected.controllerIndex, 1)
        XCTAssertEqual(disconnected.activeMask, 0)
        XCTAssertEqual(disconnected.buttons, 0)
        XCTAssertEqual(disconnected.leftStickX, 0)
        await provider.stopInput(sessionID: sessionID)
    }

    func testProviderBoundsControllerRegistryAtSixteenStableSlots() async throws {
        let sender = InputSenderStub()
        let provider = MoonlightRemoteInputProvider(sender: sender)
        let sessionID = UUID()
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 0x32, count: 16))
        )
        for index in 0..<RemoteInputWireCodec.maximumControllerCount {
            try await provider.send(.controllerConnected(ControllerConnectionInputEvent(
                controllerID: "controller-\(index)",
                playerIndex: index < 4 ? index + 1 : nil,
                type: .unknown,
                capabilities: [],
                supportedButtons: .standard
            )), sessionID: sessionID)
        }
        await assertProviderError(.controllerLimitReached) {
            try await provider.send(.controllerConnected(ControllerConnectionInputEvent(
                controllerID: "controller-overflow",
                playerIndex: nil,
                type: .unknown,
                capabilities: [],
                supportedButtons: .standard
            )), sessionID: sessionID)
        }
        let sends = await sender.recordedSends()
        XCTAssertEqual(sends.count, 32)
        XCTAssertEqual(
            Set(sends.enumerated().filter { $0.offset.isMultiple(of: 2) }.map(\.element.channelID)),
            Set((0x10...0x1F).map(UInt8.init))
        )
        await provider.stopInput(sessionID: sessionID)
    }

    func testProviderMapsFeedbackAndGatesMotionUntilHostRequest() async throws {
        let sender = InputSenderStub()
        let source = InputFeedbackSourceStub()
        let provider = MoonlightRemoteInputProvider(sender: sender, feedbackSource: source)
        let sessionID = UUID()
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 0x33, count: 16))
        )
        try await provider.send(.controllerConnected(ControllerConnectionInputEvent(
            controllerID: "physical-one",
            playerIndex: 1,
            type: .playStation,
            capabilities: [.rumble, .triggerRumble, .accelerometer, .gyroscope, .battery, .rgbLED],
            supportedButtons: .standard
        )), sessionID: sessionID)
        let feedback = await provider.feedback(sessionID: sessionID)
        var iterator = feedback.makeAsyncIterator()

        await assertProviderError(.motionNotEnabled) {
            try await provider.send(.controllerMotion(ControllerMotionInputEvent(
                controllerID: "physical-one",
                type: .accelerometer,
                x: 1,
                y: 2,
                z: 3
            )), sessionID: sessionID)
        }

        await source.yield(.motionRate(
            controllerIndex: 0,
            motionType: .accelerometer,
            reportRateHz: 120
        ))
        let motionRate = await iterator.next()
        XCTAssertEqual(motionRate, .motionRate(
            controllerID: "physical-one",
            motionType: .accelerometer,
            reportRateHz: 120
        ))
        try await provider.send(.controllerMotion(ControllerMotionInputEvent(
            controllerID: "physical-one",
            type: .accelerometer,
            x: 1,
            y: 2,
            z: 3
        )), sessionID: sessionID)
        var sends = await sender.recordedSends()
        XCTAssertEqual(try XCTUnwrap(sends.last).channelID, 0x20)
        XCTAssertFalse(try XCTUnwrap(sends.last).reliable)

        await source.yield(.rumble(controllerIndex: 0, lowFrequency: 0, highFrequency: .max))
        let rumble = await iterator.next()
        XCTAssertEqual(rumble, .rumble(ControllerRumbleFeedback(
            controllerID: "physical-one",
            lowFrequency: 0,
            highFrequency: 1
        )))
        await source.yield(.triggerRumble(controllerIndex: 0, leftMotor: 0x8000, rightMotor: .max))
        guard case let .triggerRumble(trigger)? = await iterator.next() else {
            return XCTFail("Expected mapped trigger-rumble feedback.")
        }
        XCTAssertEqual(trigger.controllerID, "physical-one")
        XCTAssertEqual(trigger.leftMotor, Float(0x8000) / Float(UInt16.max), accuracy: 0.000_001)
        XCTAssertEqual(trigger.rightMotor, 1)
        await source.yield(.led(controllerIndex: 0, red: 1, green: 2, blue: 3))
        let led = await iterator.next()
        XCTAssertEqual(led, .led(ControllerLEDFeedback(
            controllerID: "physical-one",
            red: 1,
            green: 2,
            blue: 3
        )))

        try await provider.send(.controllerBattery(ControllerBatteryInputEvent(
            controllerID: "physical-one",
            state: .discharging,
            percentage: 75
        )), sessionID: sessionID)
        sends = await sender.recordedSends()
        XCTAssertEqual(try XCTUnwrap(sends.last).channelID, 0x10)
        XCTAssertTrue(try XCTUnwrap(sends.last).reliable)

        await source.yield(.motionRate(
            controllerIndex: 0,
            motionType: .accelerometer,
            reportRateHz: 0
        ))
        _ = await iterator.next()
        await assertProviderError(.motionNotEnabled) {
            try await provider.send(.controllerMotion(ControllerMotionInputEvent(
                controllerID: "physical-one",
                type: .accelerometer,
                x: 1,
                y: 2,
                z: 3
            )), sessionID: sessionID)
        }

        await provider.stopInput(sessionID: sessionID)
        let finished = await iterator.next()
        XCTAssertNil(finished)
    }

    func testControllerAndMotionCoalescingPreservesButtonTransitionsAndSensorType() {
        var first = RemoteControllerState.empty(controllerIndex: 0, activeGamepadMask: 1)
        first.buttons = .a
        var axis = first
        axis.leftStickX = 1_000
        XCTAssertEqual(
            RemoteInputMovementCoalescer.coalesce(
                older: .controllerState(first),
                newer: .controllerState(axis)
            ),
            .controllerState(axis)
        )
        var released = axis
        released.buttons = []
        XCTAssertNil(RemoteInputMovementCoalescer.coalesce(
            older: .controllerState(axis),
            newer: .controllerState(released)
        ))

        let accelerometer = RemoteControllerMotion(
            controllerIndex: 0,
            type: .accelerometer,
            x: 1,
            y: 2,
            z: 3
        )
        var latest = accelerometer
        latest.x = 4
        XCTAssertEqual(RemoteInputMovementCoalescer.coalesce(
            older: .controllerMotionState(accelerometer),
            newer: .controllerMotionState(latest)
        ), .controllerMotionState(latest))
        var gyroscope = latest
        gyroscope.type = .gyroscope
        XCTAssertNil(RemoteInputMovementCoalescer.coalesce(
            older: .controllerMotionState(latest),
            newer: .controllerMotionState(gyroscope)
        ))
    }

    func testFeedbackSourceEndFailsSessionAndFinishesSubscribers() async throws {
        let sender = InputSenderStub()
        let source = InputFeedbackSourceStub()
        let provider = MoonlightRemoteInputProvider(sender: sender, feedbackSource: source)
        let sessionID = UUID()
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 0x34, count: 16))
        )
        let feedback = await provider.feedback(sessionID: sessionID)
        var iterator = feedback.makeAsyncIterator()

        await source.finish()
        let finished = await iterator.next()
        XCTAssertNil(finished)
        await assertProviderError(.inactiveSession) {
            try await provider.send(.clipboard(ClipboardInputEvent(text: "late")), sessionID: sessionID)
        }
        let deactivationCount = await sender.deactivateCount()
        XCTAssertEqual(deactivationCount, 1)
    }

    func testProviderRejectsConcurrentActivationAndRestartDuringTeardown() async throws {
        let sender = InputSenderStub(
            activationDelayNanoseconds: 30_000_000,
            deactivationDelayNanoseconds: 30_000_000
        )
        let provider = MoonlightRemoteInputProvider(sender: sender)
        let firstSession = UUID()
        let firstEndpoint = inputEndpoint()
        let firstConfiguration = inputConfiguration(key: Data(repeating: 0x35, count: 16))
        let firstStart = Task {
            try await provider.startInput(
                sessionID: firstSession,
                endpoint: firstEndpoint,
                configuration: firstConfiguration
            )
        }
        try await Task.sleep(nanoseconds: 2_000_000)
        await assertProviderError(.inactiveSession) {
            try await provider.startInput(
                sessionID: UUID(),
                endpoint: inputEndpoint(),
                configuration: inputConfiguration(key: Data(repeating: 0x36, count: 16))
            )
        }
        try await firstStart.value

        let stop = Task { await provider.stopInput(sessionID: firstSession) }
        try await Task.sleep(nanoseconds: 2_000_000)
        await assertProviderError(.inactiveSession) {
            try await provider.startInput(
                sessionID: UUID(),
                endpoint: inputEndpoint(),
                configuration: inputConfiguration(key: Data(repeating: 0x37, count: 16))
            )
        }
        await stop.value

        let replacementSession = UUID()
        try await provider.startInput(
            sessionID: replacementSession,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 0x38, count: 16))
        )
        await provider.stopInput(sessionID: replacementSession)
    }

    func testControllerCapabilitiesGateMotionAndBatteryData() async throws {
        let sender = InputSenderStub()
        let source = InputFeedbackSourceStub()
        let provider = MoonlightRemoteInputProvider(sender: sender, feedbackSource: source)
        let sessionID = UUID()
        try await provider.startInput(
            sessionID: sessionID,
            endpoint: inputEndpoint(),
            configuration: inputConfiguration(key: Data(repeating: 0x39, count: 16))
        )
        try await provider.send(.controllerConnected(ControllerConnectionInputEvent(
            controllerID: "limited",
            playerIndex: 1,
            type: .unknown,
            capabilities: [],
            supportedButtons: .standard
        )), sessionID: sessionID)
        await source.yield(.motionRate(
            controllerIndex: 0,
            motionType: .accelerometer,
            reportRateHz: 120
        ))
        try await Task.sleep(nanoseconds: 2_000_000)

        await assertProviderError(.invalidControllerEvent) {
            try await provider.send(.controllerMotion(ControllerMotionInputEvent(
                controllerID: "limited",
                type: .accelerometer,
                x: 1,
                y: 2,
                z: 3
            )), sessionID: sessionID)
        }
        await assertProviderError(.invalidControllerEvent) {
            try await provider.send(.controllerBattery(ControllerBatteryInputEvent(
                controllerID: "limited",
                state: .full,
                percentage: 100
            )), sessionID: sessionID)
        }
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

    private func relativeMovementDelta(
        _ packet: RemoteInputPlaintextPacket
    ) throws -> RelativeMovementDelta {
        let bytes = [UInt8](packet.bytes)
        guard bytes.count == 12,
              Array(bytes[0...7]) == [0x00, 0x00, 0x00, 0x08, 0x07, 0x00, 0x00, 0x00] else {
            throw RemoteInputCodecError.invalidPacket
        }
        return RelativeMovementDelta(
            x: Int16(bitPattern: UInt16(bytes[8]) << 8 | UInt16(bytes[9])),
            y: Int16(bitPattern: UInt16(bytes[10]) << 8 | UInt16(bytes[11]))
        )
    }

    private func controllerState(
        from packet: RemoteInputPlaintextPacket
    ) throws -> ParsedControllerState {
        let bytes = [UInt8](packet.bytes)
        guard bytes.count == 34,
              Array(bytes[0...7]) == [0x00, 0x00, 0x00, 0x1E, 0x0C, 0x00, 0x00, 0x00] else {
            throw RemoteInputCodecError.invalidPacket
        }
        return ParsedControllerState(
            controllerIndex: UInt8(readLittleEndianUInt16(bytes, offset: 10)),
            activeMask: readLittleEndianUInt16(bytes, offset: 12),
            buttons: UInt32(readLittleEndianUInt16(bytes, offset: 16))
                | UInt32(readLittleEndianUInt16(bytes, offset: 30)) << 16,
            leftStickX: Int16(bitPattern: readLittleEndianUInt16(bytes, offset: 20))
        )
    }

    private func readLittleEndianUInt16(_ bytes: [UInt8], offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | UInt16(bytes[offset + 1]) << 8
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
    var absoluteMovePacketHex: String
    var clipboardPacketsHex: [String]
    var horizontalScrollPacketHex: String
    var pointerButtonPacketHex: String
    var relativeMovePacketHex: String
    var schemaVersion: Int
    var touchPacketHex: String
    var verticalScrollPacketHex: String
}

private struct RelativeMovementDelta: Equatable, Sendable {
    var x: Int16
    var y: Int16
}

private struct ParsedControllerState: Equatable, Sendable {
    var controllerIndex: UInt8
    var activeMask: UInt16
    var buttons: UInt32
    var leftStickX: Int16
}

private actor InputCompletionRecorder {
    private var recordedValues: [Int] = []

    func record(_ value: Int) {
        recordedValues.append(value)
    }

    func values() -> [Int] {
        recordedValues
    }
}

private struct InputSendRecord: Equatable, Sendable {
    var packet: RemoteInputPlaintextPacket
    var channelID: UInt8
    var reliable: Bool
}

private actor InputSenderStub: AuthenticatedInputFrameSending {
    private let activationDelayNanoseconds: UInt64
    private let deactivationDelayNanoseconds: UInt64
    private let delayNanosecondsByCall: [Int: UInt64]
    private let failingCalls: Set<Int>
    private var sends: [InputSendRecord] = []
    private var deactivations = 0

    init(
        activationDelayNanoseconds: UInt64 = 0,
        deactivationDelayNanoseconds: UInt64 = 0,
        delayNanosecondsByCall: [Int: UInt64] = [:],
        failingCalls: Set<Int> = []
    ) {
        self.activationDelayNanoseconds = activationDelayNanoseconds
        self.deactivationDelayNanoseconds = deactivationDelayNanoseconds
        self.delayNanosecondsByCall = delayNanosecondsByCall
        self.failingCalls = failingCalls
    }

    func activateInput(configuration: NegotiatedInputConfiguration) async throws {
        if activationDelayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: activationDelayNanoseconds)
        }
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
        if deactivationDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: deactivationDelayNanoseconds)
        }
        deactivations += 1
    }

    func recordedSends() -> [InputSendRecord] {
        sends
    }

    func deactivateCount() -> Int {
        deactivations
    }
}

private actor InputFeedbackSourceStub: RemoteControllerFeedbackStreaming {
    private var continuation: AsyncStream<RemoteControllerFeedbackMessage>.Continuation?

    func controllerFeedbackMessages() async -> AsyncStream<RemoteControllerFeedbackMessage> {
        var createdContinuation: AsyncStream<RemoteControllerFeedbackMessage>.Continuation!
        let stream = AsyncStream(
            bufferingPolicy: .bufferingNewest(64)
        ) { createdContinuation = $0 }
        continuation = createdContinuation
        return stream
    }

    func yield(_ message: RemoteControllerFeedbackMessage) {
        continuation?.yield(message)
    }

    func finish() {
        continuation?.finish()
        continuation = nil
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
