import CryptoKit
import Foundation

enum ControlChannelError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidEncryptionKey
    case invalidEndpoint
    case invalidFrame
    case payloadTooLarge
    case sequenceExhausted
    case invalidState
    case disconnected(data: UInt32)
    case invalidTerminationPayload
    case invalidHDRMetadataPayload
    case inputKeyMismatch
    case inputNotActive

    var description: String {
        switch self {
        case .invalidEncryptionKey:
            return "The negotiated control encryption key is invalid."
        case .invalidEndpoint:
            return "The negotiated control endpoint is invalid."
        case .invalidFrame:
            return "The host sent an invalid or unauthenticated control message."
        case .payloadTooLarge:
            return "The control message exceeds the protocol size limit."
        case .sequenceExhausted:
            return "The control encryption sequence is exhausted."
        case .invalidState:
            return "The control channel is not in a valid state for this operation."
        case let .disconnected(data):
            return String(format: "The control connection closed unexpectedly (0x%08X).", data)
        case .invalidTerminationPayload:
            return "The host sent a malformed termination reason."
        case .invalidHDRMetadataPayload:
            return "The host sent malformed HDR mode or static metadata."
        case .inputKeyMismatch:
            return "The negotiated remote-input key does not match the active control session."
        case .inputNotActive:
            return "Authenticated remote input is not active on the control session."
        }
    }
}

enum ControlFrameOrigin: Sendable {
    case client
    case host
}

struct MoonlightControlMessage: Equatable, Sendable {
    var type: UInt16
    var payload: Data
}

struct OpenedControlFrame: Equatable, Sendable {
    var sequence: UInt32
    var message: MoonlightControlMessage
}

enum EncryptedControlFrameCodec {
    private static let encryptedHeaderType: UInt16 = 0x0001
    private static let outerHeaderSize = 8
    private static let tagSize = 16
    private static let innerHeaderSize = 4
    private static let maximumPayloadSize = Int(UInt16.max) - 24

    static func seal(
        _ message: MoonlightControlMessage,
        sequence: UInt32,
        key: Data,
        origin: ControlFrameOrigin
    ) throws -> Data {
        guard key.count == 16 else { throw ControlChannelError.invalidEncryptionKey }
        guard message.payload.count <= maximumPayloadSize,
              let payloadLength = UInt16(exactly: message.payload.count) else {
            throw ControlChannelError.payloadTooLarge
        }

        var plaintext = Data()
        appendLittleEndian(message.type, to: &plaintext)
        appendLittleEndian(payloadLength, to: &plaintext)
        plaintext.append(message.payload)

        do {
            let nonce = try AES.GCM.Nonce(data: nonce(sequence: sequence, origin: origin))
            let sealed = try AES.GCM.seal(
                plaintext,
                using: SymmetricKey(data: key),
                nonce: nonce
            )
            let encodedLength = 4 + tagSize + plaintext.count
            guard let outerLength = UInt16(exactly: encodedLength) else {
                throw ControlChannelError.payloadTooLarge
            }
            var frame = Data()
            appendLittleEndian(encryptedHeaderType, to: &frame)
            appendLittleEndian(outerLength, to: &frame)
            appendLittleEndian(sequence, to: &frame)
            frame.append(sealed.tag)
            frame.append(sealed.ciphertext)
            return frame
        } catch let error as ControlChannelError {
            throw error
        } catch {
            throw ControlChannelError.invalidFrame
        }
    }

    static func open(
        _ frame: Data,
        key: Data,
        origin: ControlFrameOrigin
    ) throws -> OpenedControlFrame {
        guard key.count == 16 else { throw ControlChannelError.invalidEncryptionKey }
        guard frame.count >= outerHeaderSize + tagSize + innerHeaderSize else {
            throw ControlChannelError.invalidFrame
        }
        let bytes = [UInt8](frame)
        guard readLittleEndianUInt16(bytes, offset: 0) == encryptedHeaderType else {
            throw ControlChannelError.invalidFrame
        }
        let outerLength = Int(readLittleEndianUInt16(bytes, offset: 2))
        guard frame.count == 4 + outerLength,
              outerLength >= 4 + tagSize + innerHeaderSize else {
            throw ControlChannelError.invalidFrame
        }
        let sequence = readLittleEndianUInt32(bytes, offset: 4)

        do {
            let nonce = try AES.GCM.Nonce(data: nonce(sequence: sequence, origin: origin))
            let box = try AES.GCM.SealedBox(
                nonce: nonce,
                ciphertext: frame.subdata(in: (outerHeaderSize + tagSize)..<frame.count),
                tag: frame.subdata(in: outerHeaderSize..<(outerHeaderSize + tagSize))
            )
            let plaintext = try AES.GCM.open(box, using: SymmetricKey(data: key))
            guard plaintext.count >= innerHeaderSize else {
                throw ControlChannelError.invalidFrame
            }
            let plaintextBytes = [UInt8](plaintext)
            let type = readLittleEndianUInt16(plaintextBytes, offset: 0)
            let payloadLength = Int(readLittleEndianUInt16(plaintextBytes, offset: 2))
            guard plaintext.count == innerHeaderSize + payloadLength else {
                throw ControlChannelError.invalidFrame
            }
            return OpenedControlFrame(
                sequence: sequence,
                message: MoonlightControlMessage(
                    type: type,
                    payload: plaintext.subdata(in: innerHeaderSize..<plaintext.count)
                )
            )
        } catch let error as ControlChannelError {
            throw error
        } catch {
            throw ControlChannelError.invalidFrame
        }
    }

    private static func nonce(sequence: UInt32, origin: ControlFrameOrigin) -> Data {
        var bytes = [UInt8](repeating: 0, count: 12)
        bytes[0] = UInt8(truncatingIfNeeded: sequence)
        bytes[1] = UInt8(truncatingIfNeeded: sequence >> 8)
        bytes[2] = UInt8(truncatingIfNeeded: sequence >> 16)
        bytes[3] = UInt8(truncatingIfNeeded: sequence >> 24)
        bytes[10] = origin == .client ? 67 : 72
        bytes[11] = 67
        return Data(bytes)
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

    private static func readLittleEndianUInt16(_ bytes: [UInt8], offset: Int) -> UInt16 {
        UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }

    private static func readLittleEndianUInt32(_ bytes: [UInt8], offset: Int) -> UInt32 {
        UInt32(bytes[offset]) |
            (UInt32(bytes[offset + 1]) << 8) |
            (UInt32(bytes[offset + 2]) << 16) |
            (UInt32(bytes[offset + 3]) << 24)
    }
}

enum HostTerminationKind: String, Equatable, Sendable {
    case graceful
    case protectedContent
    case frameConversion
    case hostFailure
}

struct HostTerminationReason: Equatable, Sendable, CustomStringConvertible {
    var code: UInt32
    var kind: HostTerminationKind

    var description: String {
        switch kind {
        case .graceful:
            return "The host ended the streaming session."
        case .protectedContent:
            return "The host blocked capture because protected content is open. Close protected content and retry."
        case .frameConversion:
            return "The host reported a fatal video conversion error. Disable HDR or align the stream and host display resolutions."
        case .hostFailure:
            return String(format: "The host terminated the stream (error 0x%08X).", code)
        }
    }

    static func parse(_ message: MoonlightControlMessage) throws -> HostTerminationReason {
        guard message.type == MoonlightControlProtocol.terminationType,
              message.payload.count == 4 else {
            throw ControlChannelError.invalidTerminationPayload
        }
        let bytes = [UInt8](message.payload)
        let code = bytes.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        let kind: HostTerminationKind
        switch code {
        case 0x8003_0023:
            kind = .graceful
        case 0x800E_9302:
            kind = .protectedContent
        case 0x800E_9403:
            kind = .frameConversion
        default:
            kind = .hostFailure
        }
        return HostTerminationReason(code: code, kind: kind)
    }
}

enum MoonlightControlProtocol {
    static let channelCount: UInt8 = 0x30
    static let genericChannel: UInt8 = 0x00
    static let urgentChannel: UInt8 = 0x01
    static let requestIDRType: UInt16 = 0x0302
    static let startBType: UInt16 = 0x0307
    static let terminationType: UInt16 = 0x0109
    static let hdrModeType: UInt16 = 0x010E
    static let requestIDR = MoonlightControlMessage(type: requestIDRType, payload: Data([0, 0]))
    static let startA = requestIDR
    static let startB = MoonlightControlMessage(type: startBType, payload: Data([0]))
}

enum MoonlightControlEvent: Equatable, Sendable {
    case idle
    case message(MoonlightControlMessage)
    case hdrMode(SunshineHDRModeMetadata)
    case terminated(HostTerminationReason)
}

enum SunshineHDRModeMetadataParser {
    private static let legacyPayloadSize = 1
    private static let sunshinePayloadSize = 27

    static func parse(_ message: MoonlightControlMessage) throws -> SunshineHDRModeMetadata {
        guard message.type == MoonlightControlProtocol.hdrModeType,
              [legacyPayloadSize, sunshinePayloadSize].contains(message.payload.count) else {
            throw ControlChannelError.invalidHDRMetadataPayload
        }
        let bytes = [UInt8](message.payload)
        guard bytes[0] == 0 || bytes[0] == 1 else {
            throw ControlChannelError.invalidHDRMetadataPayload
        }
        let isEnabled = bytes[0] == 1
        guard message.payload.count == sunshinePayloadSize else {
            return SunshineHDRModeMetadata(
                isEnabled: isEnabled,
                masteringDisplay: nil,
                contentLight: nil,
                maximumFullFrameLuminanceNits: nil
            )
        }

        var offset = 1
        var primaries: [VideoChromaticityPoint] = []
        primaries.reserveCapacity(VideoMasteringDisplayMetadata.primaryCount)
        for _ in 0..<VideoMasteringDisplayMetadata.primaryCount {
            primaries.append(VideoChromaticityPoint(
                x: readLittleEndianUInt16(bytes, offset: &offset),
                y: readLittleEndianUInt16(bytes, offset: &offset)
            ))
        }
        let whitePoint = VideoChromaticityPoint(
            x: readLittleEndianUInt16(bytes, offset: &offset),
            y: readLittleEndianUInt16(bytes, offset: &offset)
        )
        let maximumDisplayLuminance = readLittleEndianUInt16(bytes, offset: &offset)
        let minimumDisplayLuminance = readLittleEndianUInt16(bytes, offset: &offset)
        let maximumContentLightLevel = readLittleEndianUInt16(bytes, offset: &offset)
        let maximumFrameAverageLightLevel = readLittleEndianUInt16(bytes, offset: &offset)
        let maximumFullFrameLuminance = readLittleEndianUInt16(bytes, offset: &offset)
        guard offset == bytes.count else {
            throw ControlChannelError.invalidHDRMetadataPayload
        }

        guard isEnabled else {
            return SunshineHDRModeMetadata(
                isEnabled: false,
                masteringDisplay: nil,
                contentLight: nil,
                maximumFullFrameLuminanceNits: nil
            )
        }
        let hasMastering = primaries.contains(where: { $0.x != 0 || $0.y != 0 })
            || whitePoint.x != 0
            || whitePoint.y != 0
            || maximumDisplayLuminance != 0
            || minimumDisplayLuminance != 0
        let masteringDisplay = hasMastering ? VideoMasteringDisplayMetadata(
            displayPrimaries: primaries,
            whitePoint: whitePoint,
            maximumDisplayLuminanceNits: maximumDisplayLuminance,
            minimumDisplayLuminanceTenThousandths: minimumDisplayLuminance
        ) : nil
        let hasContentLight = maximumContentLightLevel != 0
            || maximumFrameAverageLightLevel != 0
        let contentLight = hasContentLight ? VideoContentLightMetadata(
            maximumContentLightLevelNits: maximumContentLightLevel,
            maximumFrameAverageLightLevelNits: maximumFrameAverageLightLevel
        ) : nil
        let metadata = SunshineHDRModeMetadata(
            isEnabled: true,
            masteringDisplay: masteringDisplay,
            contentLight: contentLight,
            maximumFullFrameLuminanceNits: maximumFullFrameLuminance == 0
                ? nil
                : maximumFullFrameLuminance
        )
        do {
            _ = try metadata.colorMetadata()
            return metadata
        } catch {
            throw ControlChannelError.invalidHDRMetadataPayload
        }
    }

    private static func readLittleEndianUInt16(
        _ bytes: [UInt8],
        offset: inout Int
    ) -> UInt16 {
        defer { offset += 2 }
        return UInt16(bytes[offset]) | (UInt16(bytes[offset + 1]) << 8)
    }
}

protocol MoonlightControlChannelManaging: Sendable {
    func connect(
        endpoint: RuntimeNetworkEndpoint,
        connectData: UInt32,
        encryptionKey: Data
    ) async throws
    func nextEvent() async throws -> MoonlightControlEvent
    func requestIDR() async throws
    func stop() async
}

actor MoonlightControlChannel: MoonlightControlChannelManaging, AuthenticatedInputFrameSending {
    private let driver: any ENetConnectionDriving
    private var encryptionKey = Data()
    private var nextSequence: UInt32 = 0
    private var connected = false
    private var inputContext: AuthenticatedRemoteInputContext?

    init(driver: any ENetConnectionDriving = ENetConnectionDriver()) {
        self.driver = driver
    }

    func connect(
        endpoint: RuntimeNetworkEndpoint,
        connectData: UInt32,
        encryptionKey: Data
    ) async throws {
        guard !connected else { throw ControlChannelError.invalidState }
        guard endpoint.transport == .udp,
              !endpoint.host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              endpoint.port > 0 else {
            throw ControlChannelError.invalidEndpoint
        }
        guard encryptionKey.count == 16 else {
            throw ControlChannelError.invalidEncryptionKey
        }

        do {
            try await driver.connect(
                host: endpoint.host,
                port: endpoint.port,
                channelCount: MoonlightControlProtocol.channelCount,
                connectData: connectData,
                timeoutMilliseconds: 10_000
            )
            self.encryptionKey = encryptionKey
            nextSequence = 0
            connected = true
            try await send(MoonlightControlProtocol.startA, channelID: MoonlightControlProtocol.genericChannel)
            try await send(MoonlightControlProtocol.startB, channelID: MoonlightControlProtocol.genericChannel)
        } catch {
            await stop()
            throw error
        }
    }

    func nextEvent() async throws -> MoonlightControlEvent {
        guard connected else { throw ControlChannelError.invalidState }
        let event = try await driver.service(timeoutMilliseconds: 100)
        guard connected else { throw ControlChannelError.invalidState }
        switch event {
        case .idle:
            return .idle
        case let .received(_, payload):
            let opened = try EncryptedControlFrameCodec.open(
                payload,
                key: encryptionKey,
                origin: .host
            )
            if opened.message.type == MoonlightControlProtocol.terminationType {
                return .terminated(try HostTerminationReason.parse(opened.message))
            }
            if opened.message.type == MoonlightControlProtocol.hdrModeType {
                return .hdrMode(try SunshineHDRModeMetadataParser.parse(opened.message))
            }
            return .message(opened.message)
        case let .disconnected(data):
            await stop()
            throw ControlChannelError.disconnected(data: data)
        }
    }

    func requestIDR() async throws {
        try await send(
            MoonlightControlProtocol.requestIDR,
            channelID: MoonlightControlProtocol.urgentChannel
        )
    }

    func activateInput(configuration: NegotiatedInputConfiguration) async throws {
        guard connected else { throw ControlChannelError.invalidState }
        guard configuration.keyMaterial.key == encryptionKey else {
            throw ControlChannelError.inputKeyMismatch
        }
        inputContext = try AuthenticatedRemoteInputContext(configuration: configuration)
    }

    func sendInput(
        _ packet: RemoteInputPlaintextPacket,
        channelID: UInt8,
        reliable: Bool
    ) async throws {
        guard connected else { throw ControlChannelError.invalidState }
        guard let inputContext else { throw ControlChannelError.inputNotActive }
        guard channelID < MoonlightControlProtocol.channelCount else {
            throw ControlChannelError.invalidState
        }
        guard nextSequence < UInt32.max else { throw ControlChannelError.sequenceExhausted }
        let sequence = nextSequence
        let frame = try inputContext.seal(packet, controlSequence: sequence)
        nextSequence += 1
        try await driver.send(frame, channelID: channelID, reliable: reliable)
        guard connected else { throw ControlChannelError.invalidState }
    }

    func deactivateInput() async {
        inputContext = nil
    }

    func stop() async {
        connected = false
        nextSequence = 0
        inputContext = nil
        encryptionKey.removeAll(keepingCapacity: false)
        await driver.disconnect()
    }

    private func send(_ message: MoonlightControlMessage, channelID: UInt8) async throws {
        guard connected else { throw ControlChannelError.invalidState }
        guard nextSequence < UInt32.max else { throw ControlChannelError.sequenceExhausted }
        let sequence = nextSequence
        let frame = try EncryptedControlFrameCodec.seal(
            message,
            sequence: sequence,
            key: encryptionKey,
            origin: .client
        )
        nextSequence += 1
        try await driver.send(frame, channelID: channelID, reliable: true)
        guard connected else { throw ControlChannelError.invalidState }
    }
}
