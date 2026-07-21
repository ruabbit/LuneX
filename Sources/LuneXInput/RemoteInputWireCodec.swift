import Foundation

enum RemoteInputCodecError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidConfiguration
    case invalidEvent
    case unsupportedEvent
    case invalidPacket
    case packetTooLarge
    case clipboardTooLarge
    case unexpectedControlType
    case invalidAuthenticatedFrame

    var description: String {
        switch self {
        case .invalidConfiguration:
            return "The negotiated remote-input encryption configuration is invalid."
        case .invalidEvent:
            return "The remote-input event contains an invalid or unrepresentable value."
        case .unsupportedEvent:
            return "The remote-input event is not supported by this delivery stage."
        case .invalidPacket:
            return "The remote-input event packet is malformed."
        case .packetTooLarge:
            return "The remote-input event packet exceeds the negotiated size limit."
        case .clipboardTooLarge:
            return "The clipboard text exceeds the bounded UTF-8 input limit."
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

struct RemoteInputOutboundPacket: Equatable, Sendable {
    var plaintext: RemoteInputPlaintextPacket
    var channelID: UInt8
    var reliable: Bool
}

enum RemoteInputWireCodec {
    static let minimumPacketSize = 8
    static let maximumPacketSize = 128
    static let maximumClipboardUTF8Bytes = 4_096
    static let maximumRelativeMovementPackets = 16

    static let keyboardChannel: UInt8 = 0x02
    static let mouseChannel: UInt8 = 0x03
    static let touchChannel: UInt8 = 0x05
    static let utf8Channel: UInt8 = 0x06
    static let controllerChannelBase: UInt8 = 0x10
    static let controllerMotionChannelBase: UInt8 = 0x20
    static let maximumControllerCount = 16

    private static let keyboardDownMagic: UInt32 = 0x0000_0003
    private static let keyboardUpMagic: UInt32 = 0x0000_0004
    private static let absolutePointerMagic: UInt32 = 0x0000_0005
    private static let relativePointerMagic: UInt32 = 0x0000_0007
    private static let pointerButtonDownMagic: UInt32 = 0x0000_0008
    private static let pointerButtonUpMagic: UInt32 = 0x0000_0009
    private static let verticalScrollMagic: UInt32 = 0x0000_000A
    private static let horizontalScrollMagic: UInt32 = 0x5500_0001
    private static let touchMagic: UInt32 = 0x5500_0002
    private static let multiControllerMagic: UInt32 = 0x0000_000C
    private static let controllerArrivalMagic: UInt32 = 0x5500_0004
    private static let controllerMotionMagic: UInt32 = 0x5500_0006
    private static let controllerBatteryMagic: UInt32 = 0x5500_0007
    private static let utf8Magic: UInt32 = 0x0000_0017
    private static let supportedModifierMask = 0x1F

    static func outboundPackets(for event: RemoteInputEvent) throws -> [RemoteInputOutboundPacket] {
        switch event {
        case let .keyboard(event):
            guard event.modifiers.rawValue >= 0,
                  event.modifiers.rawValue & ~supportedModifierMask == 0,
                  let modifiers = UInt8(exactly: event.modifiers.rawValue) else {
                throw RemoteInputCodecError.invalidEvent
            }
            return [outbound(
                try serialize(RemoteKeyboardWireEvent(
                    keyCode: event.rawKeyCode,
                    isDown: event.isDown,
                    modifiers: modifiers,
                    flags: 0
                )),
                channelID: keyboardChannel
            )]
        case let .pointer(.button(button, isDown, _)):
            return [outbound(
                try serializePointerButton(button, isDown: isDown),
                channelID: mouseChannel
            )]
        case let .pointer(.scroll(deltaX, deltaY, _)):
            return try serializeScroll(deltaX: deltaX, deltaY: deltaY).map {
                outbound($0, channelID: mouseChannel)
            }
        case let .pointer(.relativeMove(deltaX, deltaY, _)):
            return try serializeRelativeMovement(deltaX: deltaX, deltaY: deltaY).map {
                outbound($0, channelID: mouseChannel)
            }
        case let .pointer(.absoluteMove(point, referenceSize, _)):
            return [outbound(
                try serializeAbsoluteMovement(point: point, referenceSize: referenceSize),
                channelID: mouseChannel
            )]
        case let .touch(event):
            return [outbound(try serializeTouch(event), channelID: touchChannel)]
        case let .clipboard(event):
            return try serializeClipboard(event).map {
                outbound($0, channelID: utf8Channel)
            }
        case let .controllerState(state):
            return [outbound(
                try serializeControllerState(state),
                channelID: try controllerChannel(for: state.controllerIndex)
            )]
        case let .controllerArrival(arrival):
            return [outbound(
                try serializeControllerArrival(arrival),
                channelID: try controllerChannel(for: arrival.controllerIndex)
            )]
        case let .controllerMotionState(event):
            return [RemoteInputOutboundPacket(
                plaintext: try serializeControllerMotion(event),
                channelID: try controllerMotionChannel(for: event.controllerIndex),
                reliable: false
            )]
        case let .controllerBatteryState(event):
            return [outbound(
                try serializeControllerBattery(event),
                channelID: try controllerChannel(for: event.controllerIndex)
            )]
        case .virtualController, .gameController, .controllerConnected,
             .controllerDisconnected, .controllerMotion, .controllerBattery,
             .tvRemote, .focus:
            throw RemoteInputCodecError.unsupportedEvent
        }
    }

    static func serializeControllerState(
        _ state: RemoteControllerState
    ) throws -> RemoteInputPlaintextPacket {
        guard Int(state.controllerIndex) < maximumControllerCount,
              state.activeGamepadMask & (1 << UInt16(state.controllerIndex)) != 0
                || state == .empty(
                    controllerIndex: state.controllerIndex,
                    activeGamepadMask: state.activeGamepadMask
                ) else {
            throw RemoteInputCodecError.invalidEvent
        }
        var packet = Data()
        appendBigEndian(UInt32(30), to: &packet)
        appendLittleEndian(multiControllerMagic, to: &packet)
        appendLittleEndian(UInt16(0x001A), to: &packet)
        appendLittleEndian(UInt16(state.controllerIndex), to: &packet)
        appendLittleEndian(state.activeGamepadMask, to: &packet)
        appendLittleEndian(UInt16(0x0014), to: &packet)
        appendLittleEndian(UInt16(truncatingIfNeeded: state.buttons.rawValue), to: &packet)
        packet.append(state.leftTrigger)
        packet.append(state.rightTrigger)
        appendLittleEndian(state.leftStickX, to: &packet)
        appendLittleEndian(state.leftStickY, to: &packet)
        appendLittleEndian(state.rightStickX, to: &packet)
        appendLittleEndian(state.rightStickY, to: &packet)
        appendLittleEndian(UInt16(0x009C), to: &packet)
        appendLittleEndian(UInt16(truncatingIfNeeded: state.buttons.rawValue >> 16), to: &packet)
        appendLittleEndian(UInt16(0x0055), to: &packet)
        return try RemoteInputPlaintextPacket(validating: packet)
    }

    static func serializeControllerArrival(
        _ arrival: RemoteControllerArrival
    ) throws -> RemoteInputPlaintextPacket {
        guard Int(arrival.controllerIndex) < maximumControllerCount else {
            throw RemoteInputCodecError.invalidEvent
        }
        var packet = Data()
        appendBigEndian(UInt32(12), to: &packet)
        appendLittleEndian(controllerArrivalMagic, to: &packet)
        packet.append(arrival.controllerIndex)
        packet.append(arrival.type.rawValue)
        appendLittleEndian(arrival.capabilities.rawValue, to: &packet)
        appendLittleEndian(arrival.supportedButtons.rawValue, to: &packet)
        return try RemoteInputPlaintextPacket(validating: packet)
    }

    static func serializeControllerMotion(
        _ event: RemoteControllerMotion
    ) throws -> RemoteInputPlaintextPacket {
        guard Int(event.controllerIndex) < maximumControllerCount,
              event.x.isFinite,
              event.y.isFinite,
              event.z.isFinite else {
            throw RemoteInputCodecError.invalidEvent
        }
        var packet = Data()
        appendBigEndian(UInt32(20), to: &packet)
        appendLittleEndian(controllerMotionMagic, to: &packet)
        packet.append(event.controllerIndex)
        packet.append(event.type.rawValue)
        appendLittleEndian(UInt16(0), to: &packet)
        appendLittleEndian(event.x, to: &packet)
        appendLittleEndian(event.y, to: &packet)
        appendLittleEndian(event.z, to: &packet)
        return try RemoteInputPlaintextPacket(validating: packet)
    }

    static func serializeControllerBattery(
        _ event: RemoteControllerBattery
    ) throws -> RemoteInputPlaintextPacket {
        guard Int(event.controllerIndex) < maximumControllerCount,
              event.percentage <= 100 || event.percentage == ControllerBatteryInputEvent.unknownPercentage else {
            throw RemoteInputCodecError.invalidEvent
        }
        var packet = Data()
        appendBigEndian(UInt32(8), to: &packet)
        appendLittleEndian(controllerBatteryMagic, to: &packet)
        packet.append(event.controllerIndex)
        packet.append(event.state.rawValue)
        packet.append(event.percentage)
        packet.append(0)
        return try RemoteInputPlaintextPacket(validating: packet)
    }

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

    private static func serializePointerButton(
        _ button: PointerButton,
        isDown: Bool
    ) throws -> RemoteInputPlaintextPacket {
        let code: UInt8
        switch button {
        case .left:
            code = 1
        case .middle:
            code = 2
        case .right:
            code = 3
        case .back:
            code = 4
        case .forward:
            code = 5
        }
        var packet = Data()
        appendBigEndian(UInt32(5), to: &packet)
        appendLittleEndian(isDown ? pointerButtonDownMagic : pointerButtonUpMagic, to: &packet)
        packet.append(code)
        return try RemoteInputPlaintextPacket(validating: packet)
    }

    private static func serializeRelativeMovement(
        deltaX: Double,
        deltaY: Double
    ) throws -> [RemoteInputPlaintextPacket] {
        guard deltaX.isFinite, deltaY.isFinite else {
            throw RemoteInputCodecError.invalidEvent
        }
        let roundedX = deltaX.rounded(.toNearestOrAwayFromZero)
        let roundedY = deltaY.rounded(.toNearestOrAwayFromZero)
        let maximumPositiveDelta = Double(Int16.max) * Double(maximumRelativeMovementPackets)
        let maximumNegativeDelta = Double(Int16.min) * Double(maximumRelativeMovementPackets)
        guard (maximumNegativeDelta...maximumPositiveDelta).contains(roundedX),
              (maximumNegativeDelta...maximumPositiveDelta).contains(roundedY),
              let initialX = Int(exactly: roundedX),
              let initialY = Int(exactly: roundedY) else {
            throw RemoteInputCodecError.invalidEvent
        }

        var remainingX = initialX
        var remainingY = initialY
        var packets: [RemoteInputPlaintextPacket] = []
        packets.reserveCapacity(maximumRelativeMovementPackets)
        while remainingX != 0 || remainingY != 0 {
            guard packets.count < maximumRelativeMovementPackets else {
                throw RemoteInputCodecError.invalidEvent
            }
            let packetX = Int16(clamping: remainingX)
            let packetY = Int16(clamping: remainingY)
            var packet = Data()
            appendBigEndian(UInt32(8), to: &packet)
            appendLittleEndian(relativePointerMagic, to: &packet)
            appendBigEndian(packetX, to: &packet)
            appendBigEndian(packetY, to: &packet)
            packets.append(try RemoteInputPlaintextPacket(validating: packet))
            remainingX -= Int(packetX)
            remainingY -= Int(packetY)
        }
        return packets
    }

    private static func serializeAbsoluteMovement(
        point: RemotePoint,
        referenceSize: PixelSize
    ) throws -> RemoteInputPlaintextPacket {
        guard referenceSize.width > 0,
              referenceSize.height > 0,
              referenceSize.width <= Int(Int16.max),
              referenceSize.height <= Int(Int16.max),
              point.x.isFinite,
              point.y.isFinite,
              (0...Double(referenceSize.width)).contains(point.x),
              (0...Double(referenceSize.height)).contains(point.y),
              let x = Int16(exactly: point.x.rounded(.toNearestOrAwayFromZero)),
              let y = Int16(exactly: point.y.rounded(.toNearestOrAwayFromZero)),
              let width = Int16(exactly: referenceSize.width - 1),
              let height = Int16(exactly: referenceSize.height - 1) else {
            throw RemoteInputCodecError.invalidEvent
        }

        var packet = Data()
        appendBigEndian(UInt32(14), to: &packet)
        appendLittleEndian(absolutePointerMagic, to: &packet)
        appendBigEndian(x, to: &packet)
        appendBigEndian(y, to: &packet)
        appendBigEndian(Int16(0), to: &packet)
        appendBigEndian(width, to: &packet)
        appendBigEndian(height, to: &packet)
        return try RemoteInputPlaintextPacket(validating: packet)
    }

    private static func serializeScroll(
        deltaX: Double,
        deltaY: Double
    ) throws -> [RemoteInputPlaintextPacket] {
        guard deltaX.isFinite, deltaY.isFinite else {
            throw RemoteInputCodecError.invalidEvent
        }
        let horizontal = boundedScrollAmount(deltaX)
        let vertical = boundedScrollAmount(deltaY)
        var packets: [RemoteInputPlaintextPacket] = []
        packets.reserveCapacity(2)
        if vertical != 0 {
            var packet = Data()
            appendBigEndian(UInt32(10), to: &packet)
            appendLittleEndian(verticalScrollMagic, to: &packet)
            appendBigEndian(vertical, to: &packet)
            appendBigEndian(vertical, to: &packet)
            appendBigEndian(UInt16(0), to: &packet)
            packets.append(try RemoteInputPlaintextPacket(validating: packet))
        }
        if horizontal != 0 {
            var packet = Data()
            appendBigEndian(UInt32(6), to: &packet)
            appendLittleEndian(horizontalScrollMagic, to: &packet)
            appendBigEndian(horizontal, to: &packet)
            packets.append(try RemoteInputPlaintextPacket(validating: packet))
        }
        return packets
    }

    private static func serializeTouch(
        _ event: TouchInputEvent
    ) throws -> RemoteInputPlaintextPacket {
        guard event.id >= 0,
              let pointerID = UInt32(exactly: event.id),
              event.referenceSize.width > 0,
              event.referenceSize.height > 0,
              event.point.x.isFinite,
              event.point.y.isFinite,
              event.pressure.isFinite,
              (0...Double(event.referenceSize.width)).contains(event.point.x),
              (0...Double(event.referenceSize.height)).contains(event.point.y),
              (0...1).contains(event.pressure) else {
            throw RemoteInputCodecError.invalidEvent
        }
        let normalizedX = Float(event.point.x / Double(event.referenceSize.width))
        let normalizedY = Float(event.point.y / Double(event.referenceSize.height))
        let pressure = Float(event.pressure)
        guard normalizedX.isFinite, normalizedY.isFinite, pressure.isFinite else {
            throw RemoteInputCodecError.invalidEvent
        }

        let phase: UInt8
        switch event.phase {
        case .began:
            phase = 1
        case .ended:
            phase = 2
        case .moved:
            phase = 3
        case .cancelled:
            phase = 4
        }

        var packet = Data()
        appendBigEndian(UInt32(32), to: &packet)
        appendLittleEndian(touchMagic, to: &packet)
        packet.append(phase)
        packet.append(0)
        appendLittleEndian(UInt16.max, to: &packet)
        appendLittleEndian(pointerID, to: &packet)
        appendLittleEndian(normalizedX, to: &packet)
        appendLittleEndian(normalizedY, to: &packet)
        appendLittleEndian(pressure, to: &packet)
        appendLittleEndian(Float(0), to: &packet)
        appendLittleEndian(Float(0), to: &packet)
        return try RemoteInputPlaintextPacket(validating: packet)
    }

    private static func serializeClipboard(
        _ event: ClipboardInputEvent
    ) throws -> [RemoteInputPlaintextPacket] {
        let utf8Count = event.text.utf8.count
        guard utf8Count <= maximumClipboardUTF8Bytes else {
            throw RemoteInputCodecError.clipboardTooLarge
        }
        guard utf8Count > 0 else { return [] }

        return try event.text.unicodeScalars.map { scalar in
            let utf8 = Data(String(scalar).utf8)
            var packet = Data()
            appendBigEndian(UInt32(4 + utf8.count), to: &packet)
            appendLittleEndian(utf8Magic, to: &packet)
            packet.append(utf8)
            return try RemoteInputPlaintextPacket(validating: packet)
        }
    }

    private static func outbound(
        _ packet: RemoteInputPlaintextPacket,
        channelID: UInt8
    ) -> RemoteInputOutboundPacket {
        RemoteInputOutboundPacket(plaintext: packet, channelID: channelID, reliable: true)
    }

    private static func controllerChannel(for controllerIndex: UInt8) throws -> UInt8 {
        guard Int(controllerIndex) < maximumControllerCount else {
            throw RemoteInputCodecError.invalidEvent
        }
        return controllerChannelBase + controllerIndex
    }

    private static func controllerMotionChannel(for controllerIndex: UInt8) throws -> UInt8 {
        guard Int(controllerIndex) < maximumControllerCount else { throw RemoteInputCodecError.invalidEvent }
        return controllerMotionChannelBase + controllerIndex
    }

    private static func boundedScrollAmount(_ value: Double) -> Int16 {
        let rounded = value.rounded(.toNearestOrAwayFromZero)
        let bounded = min(max(rounded, Double(Int16.min)), Double(Int16.max))
        return Int16(bounded)
    }

    private static func appendBigEndian(_ value: UInt32, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value >> 24))
        data.append(UInt8(truncatingIfNeeded: value >> 16))
        data.append(UInt8(truncatingIfNeeded: value >> 8))
        data.append(UInt8(truncatingIfNeeded: value))
    }

    private static func appendBigEndian(_ value: UInt16, to data: inout Data) {
        data.append(UInt8(truncatingIfNeeded: value >> 8))
        data.append(UInt8(truncatingIfNeeded: value))
    }

    private static func appendBigEndian(_ value: Int16, to data: inout Data) {
        appendBigEndian(UInt16(bitPattern: value), to: &data)
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

    private static func appendLittleEndian(_ value: Int16, to data: inout Data) {
        appendLittleEndian(UInt16(bitPattern: value), to: &data)
    }

    private static func appendLittleEndian(_ value: Float, to data: inout Data) {
        appendLittleEndian(value.bitPattern, to: &data)
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
