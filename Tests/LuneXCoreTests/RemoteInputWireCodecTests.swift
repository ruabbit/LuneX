import Foundation
import XCTest

final class RemoteInputWireCodecTests: XCTestCase {
    func testNegotiatedKeyboardPacketAndAuthenticatedFrameMatchIndependentVector() throws {
        let fixture = try loadFixture()
        let context = try AuthenticatedRemoteInputContext(configuration: configuration(
            keyID: fixture.keyID,
            key: try decodeHex(fixture.keyHex)
        ))
        let packet = try RemoteInputWireCodec.serialize(RemoteKeyboardWireEvent(
            keyCode: fixture.keyboard.keyCode,
            isDown: fixture.keyboard.isDown,
            modifiers: fixture.keyboard.modifiers,
            flags: fixture.keyboard.flags
        ))

        XCTAssertEqual(packet.bytes, try decodeHex(fixture.plaintextPacketHex))
        let frame = try context.seal(packet, controlSequence: fixture.sequence)
        XCTAssertEqual(frame, try decodeHex(fixture.sealedFrameHex))

        let opened = try context.open(frame)
        XCTAssertEqual(opened.sequence, fixture.sequence)
        XCTAssertEqual(opened.packet, packet)
    }

    func testKeyboardUpPacketPreservesMixedEndianFields() throws {
        let packet = try RemoteInputWireCodec.serialize(RemoteKeyboardWireEvent(
            keyCode: 0xA35C,
            isDown: false,
            modifiers: 0x0F,
            flags: 0x03
        ))

        XCTAssertEqual([UInt8](packet.bytes), [
            0x00, 0x00, 0x00, 0x0A,
            0x04, 0x00, 0x00, 0x00,
            0x03, 0x5C, 0xA3, 0x0F, 0x00, 0x00
        ])
    }

    func testConfigurationAndPacketBoundsFailClosed() throws {
        var invalid = configuration(keyID: -1, key: Data(repeating: 1, count: 16))
        assertInvalidConfiguration(invalid)
        invalid = configuration(keyID: Int(UInt32.max) + 1, key: Data(repeating: 1, count: 16))
        assertInvalidConfiguration(invalid)
        invalid = configuration(keyID: 1, key: Data(repeating: 1, count: 15))
        assertInvalidConfiguration(invalid)
        invalid = configuration(keyID: 1, key: Data(repeating: 1, count: 16))
        invalid.encrypted = false
        assertInvalidConfiguration(invalid)
        invalid.encrypted = true
        invalid.maximumMessageSize = RemoteInputWireCodec.minimumPacketSize - 1
        assertInvalidConfiguration(invalid)
        invalid.maximumMessageSize = RemoteInputWireCodec.maximumPacketSize + 1
        assertInvalidConfiguration(invalid)

        XCTAssertThrowsError(try RemoteInputPlaintextPacket(validating: Data(repeating: 0, count: 8))) { error in
            XCTAssertEqual(error as? RemoteInputCodecError, .invalidPacket)
        }
        XCTAssertThrowsError(
            try RemoteInputPlaintextPacket(validating: Data([0, 0, 0, 4, 0, 0, 0, 0]))
        ) { error in
            XCTAssertEqual(error as? RemoteInputCodecError, .invalidPacket)
        }
        XCTAssertThrowsError(
            try RemoteInputPlaintextPacket(
                validating: Data(repeating: 0, count: RemoteInputWireCodec.maximumPacketSize + 1)
            )
        ) { error in
            XCTAssertEqual(error as? RemoteInputCodecError, .packetTooLarge)
        }

        let smallContext = try AuthenticatedRemoteInputContext(configuration: NegotiatedInputConfiguration(
            keyMaterial: RemoteInputKeyMaterial(keyID: 1, key: Data(repeating: 1, count: 16)),
            encrypted: true,
            maximumMessageSize: RemoteInputWireCodec.minimumPacketSize
        ))
        let keyboard = try RemoteInputWireCodec.serialize(RemoteKeyboardWireEvent(
            keyCode: 1,
            isDown: true,
            modifiers: 0,
            flags: 0
        ))
        XCTAssertThrowsError(try smallContext.seal(keyboard, controlSequence: 0)) { error in
            XCTAssertEqual(error as? RemoteInputCodecError, .packetTooLarge)
        }
    }

    func testAuthenticatedFrameRejectsMutationWrongOriginAndControlType() throws {
        let fixture = try loadFixture()
        let key = try decodeHex(fixture.keyHex)
        let context = try AuthenticatedRemoteInputContext(configuration: configuration(
            keyID: fixture.keyID,
            key: key
        ))
        let frame = try decodeHex(fixture.sealedFrameHex)

        var mutated = frame
        mutated[mutated.index(before: mutated.endIndex)] ^= 0x01
        XCTAssertThrowsError(try context.open(mutated)) { error in
            XCTAssertEqual(error as? RemoteInputCodecError, .invalidAuthenticatedFrame)
        }
        XCTAssertThrowsError(try context.open(frame, origin: .host)) { error in
            XCTAssertEqual(error as? RemoteInputCodecError, .invalidAuthenticatedFrame)
        }

        let wrongType = try EncryptedControlFrameCodec.seal(
            MoonlightControlMessage(type: 0x0302, payload: Data([0, 0])),
            sequence: fixture.sequence,
            key: key,
            origin: .client
        )
        XCTAssertThrowsError(try context.open(wrongType)) { error in
            XCTAssertEqual(error as? RemoteInputCodecError, .unexpectedControlType)
        }
    }

    func testStreamNegotiationRejectsInvalidInputKeyBeforeLaunch() throws {
        var request = try makeLaunchRequest()
        request.remoteInputKey = RemoteInputKeyMaterial(keyID: 7, key: Data(repeating: 0, count: 15))

        XCTAssertThrowsError(try StreamNegotiator().makeParameters(from: request)) { error in
            XCTAssertEqual(
                (error as? StreamNegotiationFailure)?.code,
                .invalidInputKey
            )
        }
    }

    func testControllerPacketsMatchReviewedVectorsAndChannelSemantics() throws {
        let fixture = try loadControllerFixture()
        let state = RemoteControllerState(
            controllerIndex: 1,
            activeGamepadMask: 0x0003,
            buttons: RemoteControllerButtonFlags(rawValue: 0x0010_5001),
            leftTrigger: 0x40,
            rightTrigger: 0x80,
            leftStickX: 0x1234,
            leftStickY: -0x1234,
            rightStickX: .min,
            rightStickY: .max
        )
        let arrival = RemoteControllerArrival(
            controllerIndex: 1,
            type: .playStation,
            capabilities: RemoteControllerCapabilities(rawValue: 0x00F7),
            supportedButtons: RemoteControllerButtonFlags(rawValue: 0x0010_5001)
        )
        let motion = RemoteControllerMotion(
            controllerIndex: 1,
            type: .gyroscope,
            x: 1.5,
            y: -2.25,
            z: 0.125
        )
        let battery = RemoteControllerBattery(
            controllerIndex: 1,
            state: .charging,
            percentage: 87
        )

        let statePacket = try XCTUnwrap(RemoteInputWireCodec.outboundPackets(for: .controllerState(state)).first)
        XCTAssertEqual(statePacket.plaintext.bytes, try decodeHex(fixture.statePacketHex))
        XCTAssertEqual(statePacket.channelID, 0x11)
        XCTAssertTrue(statePacket.reliable)

        let arrivalPacket = try XCTUnwrap(RemoteInputWireCodec.outboundPackets(for: .controllerArrival(arrival)).first)
        XCTAssertEqual(arrivalPacket.plaintext.bytes, try decodeHex(fixture.arrivalPacketHex))
        XCTAssertEqual(arrivalPacket.channelID, 0x11)
        XCTAssertTrue(arrivalPacket.reliable)

        let motionPacket = try XCTUnwrap(RemoteInputWireCodec.outboundPackets(for: .controllerMotionState(motion)).first)
        XCTAssertEqual(motionPacket.plaintext.bytes, try decodeHex(fixture.motionPacketHex))
        XCTAssertEqual(motionPacket.channelID, 0x21)
        XCTAssertFalse(motionPacket.reliable)

        let batteryPacket = try XCTUnwrap(RemoteInputWireCodec.outboundPackets(for: .controllerBatteryState(battery)).first)
        XCTAssertEqual(batteryPacket.plaintext.bytes, try decodeHex(fixture.batteryPacketHex))
        XCTAssertEqual(batteryPacket.channelID, 0x11)
        XCTAssertTrue(batteryPacket.reliable)
    }

    func testControllerCodecRejectsInvalidIndexBatteryAndDetachedNonEmptyState() throws {
        XCTAssertThrowsError(try RemoteInputWireCodec.outboundPackets(for: .controllerArrival(
            RemoteControllerArrival(
                controllerIndex: 16,
                type: .unknown,
                capabilities: [],
                supportedButtons: []
            )
        )))
        XCTAssertThrowsError(try RemoteInputWireCodec.outboundPackets(for: .controllerBatteryState(
            RemoteControllerBattery(controllerIndex: 0, state: .charging, percentage: 101)
        )))
        var detached = RemoteControllerState.empty(controllerIndex: 0, activeGamepadMask: 0)
        detached.buttons = .a
        XCTAssertThrowsError(try RemoteInputWireCodec.outboundPackets(for: .controllerState(detached)))
    }

    private func configuration(keyID: Int, key: Data) -> NegotiatedInputConfiguration {
        NegotiatedInputConfiguration(
            keyMaterial: RemoteInputKeyMaterial(keyID: keyID, key: key),
            encrypted: true,
            maximumMessageSize: RemoteInputWireCodec.maximumPacketSize
        )
    }

    private func assertInvalidConfiguration(
        _ configuration: NegotiatedInputConfiguration,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try AuthenticatedRemoteInputContext(configuration: configuration),
            file: file,
            line: line
        ) { error in
            XCTAssertEqual(error as? RemoteInputCodecError, .invalidConfiguration, file: file, line: line)
        }
    }

    private func loadFixture() throws -> RemoteInputFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/input/authenticated-keyboard-vectors.json")
        return try JSONDecoder().decode(RemoteInputFixture.self, from: Data(contentsOf: url))
    }

    private func loadControllerFixture() throws -> ControllerWireFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/input/controller-vectors.json")
        return try JSONDecoder().decode(ControllerWireFixture.self, from: Data(contentsOf: url))
    }

    private func decodeHex(_ value: String) throws -> Data {
        let compact = value.filter { !$0.isWhitespace }
        guard compact.count.isMultiple(of: 2) else { throw RemoteInputFixtureError.invalidHex }
        var output = Data()
        output.reserveCapacity(compact.count / 2)
        var index = compact.startIndex
        while index < compact.endIndex {
            let next = compact.index(index, offsetBy: 2)
            guard let byte = UInt8(compact[index..<next], radix: 16) else {
                throw RemoteInputFixtureError.invalidHex
            }
            output.append(byte)
            index = next
        }
        return output
    }

    private func makeLaunchRequest() throws -> StreamLaunchRequest {
        let host = MoonlightHost(
            name: "Input Test Host",
            address: "192.0.2.20",
            pairingState: .paired,
            reachability: .online,
            pinnedIdentity: PinnedHostIdentity(
                certificateSHA256: "synthetic",
                serverCertificateDER: Data([1]),
                pairedAt: Date(timeIntervalSince1970: 1)
            )
        )
        return StreamLaunchRequest(
            host: host,
            app: RemoteApp(id: "1", name: "Desktop", supportsHDR: false),
            preferences: .defaults,
            clientUniqueID: "input-test-client",
            remoteInputKey: RemoteInputKeyMaterial(
                keyID: 1,
                key: Data(repeating: 1, count: 16)
            ),
            audioPlaybackMode: .clientOnly,
            controllerBitmap: 0,
            optimizeGameSettings: false
        )
    }
}

private struct RemoteInputFixture: Decodable {
    struct Keyboard: Decodable {
        var flags: UInt8
        var isDown: Bool
        var keyCode: UInt16
        var modifiers: UInt8
    }

    var keyHex: String
    var keyID: Int
    var keyboard: Keyboard
    var plaintextPacketHex: String
    var sealedFrameHex: String
    var sequence: UInt32
}

private struct ControllerWireFixture: Decodable {
    var arrivalPacketHex: String
    var batteryPacketHex: String
    var motionPacketHex: String
    var schemaVersion: Int
    var statePacketHex: String
}

private enum RemoteInputFixtureError: Error {
    case invalidHex
}
