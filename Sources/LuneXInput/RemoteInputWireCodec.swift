import Foundation

enum RemoteInputCodecError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidConfiguration
    case invalidPacket
    case packetTooLarge
    case unexpectedControlType
    case invalidAuthenticatedFrame

    var description: String {
        switch self {
        case .invalidConfiguration:
            return "The negotiated remote-input encryption configuration is invalid."
        case .invalidPacket:
            return "The remote-input event packet is malformed."
        case .packetTooLarge:
            return "The remote-input event packet exceeds the negotiated size limit."
        case .unexpectedControlType:
            return "The authenticated control frame does not contain remote-input data."
        case .invalidAuthenticatedFrame:
            return "The remote-input control frame failed authentication or framing validation."
        }
    }
}

struct RemoteKeyboardWireEvent: Equatable, Sendable {
    var keyCode: UInt16
    var isDown: Bool
    var modifiers: UInt8
    var flags: UInt8
}

struct RemoteInputPlaintextPacket: Equatable, Sendable {
    let bytes: Data

    init(validating bytes: Data) throws {
        guard bytes.count >= RemoteInputWireCodec.minimumPacketSize,
              bytes.count <= RemoteInputWireCodec.maximumPacketSize else {
            throw bytes.count > RemoteInputWireCodec.maximumPacketSize
                ? RemoteInputCodecError.packetTooLarge
                : RemoteInputCodecError.invalidPacket
        }
        let raw = [UInt8](bytes)
        let declaredPayloadSize = Int(
            UInt32(raw[0]) << 24 |
                UInt32(raw[1]) << 16 |
                UInt32(raw[2]) << 8 |
                UInt32(raw[3])
        )
        guard declaredPayloadSize == bytes.count - MemoryLayout<UInt32>.size else {
            throw RemoteInputCodecError.invalidPacket
        }
        let eventMagic =
            UInt32(raw[4]) |
            UInt32(raw[5]) << 8 |
            UInt32(raw[6]) << 16 |
            UInt32(raw[7]) << 24
        guard eventMagic != 0 else {
            throw RemoteInputCodecError.invalidPacket
        }
        self.bytes = bytes
    }
}

enum RemoteInputWireCodec {
    static let minimumPacketSize = 8
    static let maximumPacketSize = 128

    private static let keyboardDownMagic: UInt32 = 0x0000_0003
    private static let keyboardUpMagic: UInt32 = 0x0000_0004

    static func serialize(_ event: RemoteKeyboardWireEvent) throws -> RemoteInputPlaintextPacket {
        var packet = Data()
        appendBigEndian(UInt32(10), to: &packet)
        appendLittleEndian(event.isDown ? keyboardDownMagic : keyboardUpMagic, to: &packet)
        packet.append(event.flags)
        appendLittleEndian(event.keyCode, to: &packet)
        packet.append(event.modifiers)
        appendLittleEndian(UInt16(0), to: &packet)
        return try RemoteInputPlaintextPacket(validating: packet)
    }

    private static func appendBigEndian(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value >> 24))
        data.append(UInt8(truncatingIfNeeded: value >> 16))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
        data.append(UInt8(truncatingIfNeeded: value))
    }

    private static func appendLittleEndian(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
    }

    private static func appendLittleEndian(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
        data.append(UInt8(truncatingIfNeeded: value >> 16))
        data.append(UInt8(truncatingIfNeeded: value >> 24))
    }
}

struct AuthenticatedRemoteInputContext: Sendable {
    static let inputControlType: UInt16 = 0x0206

    private let key: Data
    private let maximumMessageSize: Int

    init(configuration: NegotiatedInputConfiguration) throws {
        do {
            try configuration.validate()
        } catch {
            throw RemoteInputCodecError.invalidConfiguration
        }
        key = configuration.keyMaterial.key
        maximumMessageSize = configuration.maximumMessageSize
    }

    func seal(
        _ packet: RemoteInputPlaintextPacket,
        controlSequence: UInt32
    ) throws -> Data {
        guard packet.bytes.count <= maximumMessageSize else {
            throw RemoteInputCodecError.packetTooLarge
        }
        do {
            return try EncryptedControlFrameCodec.seal(
                MoonlightControlMessage(
                    type: Self.inputControlType,
                    payload: packet.bytes
                ),
                sequence: controlSequence,
                key: key,
                origin: .client
            )
        } catch {
            throw RemoteInputCodecError.invalidAuthenticatedFrame
        }
    }

    func open(
        _ frame: Data,
        origin: ControlFrameOrigin = .client
    ) throws -> (sequence: UInt32, packet: RemoteInputPlaintextPacket) {
        let opened: OpenedControlFrame
        do {
            opened = try EncryptedControlFrameCodec.open(frame, key: key, origin: origin)
        } catch {
            throw RemoteInputCodecError.invalidAuthenticatedFrame
        }
        guard opened.message.type == Self.inputControlType else {
            throw RemoteInputCodecError.unexpectedControlType
        }
        guard opened.message.payload.count <= maximumMessageSize else {
            throw RemoteInputCodecError.packetTooLarge
        }
        return (
            sequence: opened.sequence,
            packet: try RemoteInputPlaintextPacket(validating: opened.message.payload)
        )
    }
}
