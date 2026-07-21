import Foundation

enum RuntimeContractError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidEndpoint
    case invalidVideoConfiguration
    case invalidAudioConfiguration
    case invalidInputConfiguration

    var description: String {
        switch self {
        case .invalidEndpoint:
            return "Runtime endpoint host and port must be usable."
        case .invalidVideoConfiguration:
            return "Negotiated video dimensions, frame rate, or packet size are invalid."
        case .invalidAudioConfiguration:
            return "Negotiated Opus channel, stream, mapping, or frame configuration is invalid."
        case .invalidInputConfiguration:
            return "Negotiated input key material is invalid."
        }
    }
}

enum RuntimeTransportKind: String, Codable, Equatable, Sendable {
    case tcp
    case udp
}

struct RuntimeNetworkEndpoint: Codable, Equatable, Sendable {
    var host: String
    var port: UInt16
    var transport: RuntimeTransportKind

    func validate() throws {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              port > 0 else {
            throw RuntimeContractError.invalidEndpoint
        }
    }
}

enum NegotiatedVideoCodec: String, Codable, Equatable, Hashable, Sendable {
    case h264
    case hevc
    case av1
}

struct NegotiatedVideoStreamConfiguration: Codable, Equatable, Sendable {
    var codec: NegotiatedVideoCodec
    var width: Int
    var height: Int
    var frameRate: Int
    var colorMetadata: VideoColorMetadata
    var maximumPacketSize: Int

    var bitDepth: Int { colorMetadata.bitDepth }
    var isHDR: Bool { colorMetadata.isHDR }

    func validate() throws {
        guard width > 0,
              height > 0,
              frameRate > 0,
              maximumPacketSize > 0 else {
            throw RuntimeContractError.invalidVideoConfiguration
        }
        do {
            try colorMetadata.validate()
        } catch {
            throw RuntimeContractError.invalidVideoConfiguration
        }
        if codec == .h264, colorMetadata.bitDepth == 10 || colorMetadata.isHDR {
            throw RuntimeContractError.invalidVideoConfiguration
        }
    }
}

struct NegotiatedAudioStreamConfiguration: Codable, Equatable, Sendable {
    var sampleRate: Int
    var channelCount: Int
    var streamCount: Int
    var coupledStreamCount: Int
    var samplesPerFrame: Int
    var channelMapping: [UInt8]
    var maximumPacketSize: Int

    func validate() throws {
        let codedChannelCount = streamCount + coupledStreamCount
        guard sampleRate == 48_000,
              (1...8).contains(channelCount),
              streamCount > 0,
              coupledStreamCount >= 0,
              coupledStreamCount <= streamCount,
              codedChannelCount == channelCount,
              samplesPerFrame > 0,
              channelMapping.count == channelCount,
              channelMapping.allSatisfy({ Int($0) < codedChannelCount }),
              maximumPacketSize > 0,
              maximumPacketSize <= 1_400 else {
            throw RuntimeContractError.invalidAudioConfiguration
        }
    }
}

struct NegotiatedInputConfiguration: Codable, Equatable, Sendable {
    var keyMaterial: RemoteInputKeyMaterial
    var encrypted: Bool
    var maximumMessageSize: Int

    func validate() throws {
        guard keyMaterial.isValidAES128Material,
              encrypted,
              (RemoteInputWireCodec.minimumPacketSize...RemoteInputWireCodec.maximumPacketSize)
                  .contains(maximumMessageSize) else {
            throw RuntimeContractError.invalidInputConfiguration
        }
    }
}

struct NegotiatedSessionConfiguration: Codable, Equatable, Sendable {
    var sessionID: UUID
    var controlEndpoint: RuntimeNetworkEndpoint
    var videoEndpoint: RuntimeNetworkEndpoint
    var audioEndpoint: RuntimeNetworkEndpoint
    var inputEndpoint: RuntimeNetworkEndpoint
    var video: NegotiatedVideoStreamConfiguration
    var audio: NegotiatedAudioStreamConfiguration
    var input: NegotiatedInputConfiguration
    var requiredChannels: SessionChannelReadiness

    func validate() throws {
        try controlEndpoint.validate()
        try videoEndpoint.validate()
        try audioEndpoint.validate()
        try inputEndpoint.validate()
        try video.validate()
        try audio.validate()
        try input.validate()
    }
}

struct SessionChannelReadiness: OptionSet, Codable, Hashable, Sendable {
    let rawValue: Int

    static let control = SessionChannelReadiness(rawValue: 1 << 0)
    static let video = SessionChannelReadiness(rawValue: 1 << 1)
    static let audio = SessionChannelReadiness(rawValue: 1 << 2)
    static let input = SessionChannelReadiness(rawValue: 1 << 3)
    static let all: SessionChannelReadiness = [.control, .video, .audio, .input]

    func satisfies(_ required: SessionChannelReadiness) -> Bool {
        intersection(required) == required
    }
}

struct PairingRuntimeRequest: Sendable {
    var attemptID: UUID
    var host: MoonlightHost
    var pin: String
    var clientIdentity: ClientIdentityMaterial
}

enum PairingRuntimeEvent: Equatable, Sendable {
    case progress(PairingSnapshot)
    case completed(PairingResult)
}

protocol PairingRuntimeProvider: Sendable {
    func pair(
        _ request: PairingRuntimeRequest
    ) async -> AsyncThrowingStream<PairingRuntimeEvent, Error>

    func cancelPairing(attemptID: UUID) async
}

enum SessionControlEvent: Equatable, Sendable {
    case launchAccepted(StreamLaunchResponse)
    case videoColorMetadata(VideoColorMetadata)
    case rtspReady
    case negotiated(NegotiatedSessionConfiguration)
    case channelsReady(SessionChannelReadiness)
    case reconnecting(attempt: Int, reason: String)
    case terminated(reason: String?)
}

protocol SessionControlProvider: Sendable {
    func start(
        sessionID: UUID,
        request: StreamLaunchRequest
    ) async -> AsyncThrowingStream<SessionControlEvent, Error>

    func requestIDR(sessionID: UUID) async throws
    func stop(sessionID: UUID) async
}

struct ReceivedVideoPacket: Equatable, Sendable {
    var sequenceNumber: UInt32
    var frameIndex: UInt32
    var receiveTimeNanoseconds: UInt64
    var isFirstPacket: Bool
    var isLastPacket: Bool
    var payload: Data
}

enum VideoReceiveEvent: Equatable, Sendable {
    case packet(ReceivedVideoPacket)
    case packetLoss(expected: UInt32, received: UInt32)
    case closed
}

protocol VideoReceiveProvider: Sendable {
    func receiveVideo(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedVideoStreamConfiguration
    ) async -> AsyncThrowingStream<VideoReceiveEvent, Error>

    func stopVideo(sessionID: UUID) async
}

struct ReceivedAudioPacket: Equatable, Sendable {
    var sequenceNumber: UInt16
    var timestamp: UInt32
    var receiveTimeNanoseconds: UInt64
    var payload: Data
}

enum AudioReceiveEvent: Equatable, Sendable {
    case packet(ReceivedAudioPacket)
    case packetLoss(expected: UInt16, received: UInt16)
    case closed
}

protocol AudioReceiveProvider: Sendable {
    func receiveAudio(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedAudioStreamConfiguration
    ) async -> AsyncThrowingStream<AudioReceiveEvent, Error>

    func stopAudio(sessionID: UUID) async
}

struct ControllerRumbleFeedback: Equatable, Sendable {
    var controllerID: String
    var lowFrequency: Float
    var highFrequency: Float
}

struct ControllerTriggerFeedback: Equatable, Sendable {
    var controllerID: String
    var leftMotor: Float
    var rightMotor: Float
}

struct ControllerLEDFeedback: Equatable, Sendable {
    var controllerID: String
    var red: UInt8
    var green: UInt8
    var blue: UInt8
}

enum RemoteControllerFeedbackCommand: String, Equatable, Sendable {
    case rumble
    case triggerRumble
    case motionRate
    case led
}

enum RemoteInputFeedbackDiagnosticReason: String, Equatable, Sendable {
    case controllerUnavailable
    case unsupportedCapability
}

struct RemoteInputFeedbackDiagnostic: Equatable, Sendable {
    var controllerID: String?
    var controllerIndex: UInt8
    var command: RemoteControllerFeedbackCommand
    var reason: RemoteInputFeedbackDiagnosticReason
}

enum RemoteInputFeedback: Equatable, Sendable {
    case rumble(ControllerRumbleFeedback)
    case triggerRumble(ControllerTriggerFeedback)
    case led(ControllerLEDFeedback)
    case motionRate(controllerID: String, motionType: ControllerMotionType, reportRateHz: Int)
    case diagnostic(RemoteInputFeedbackDiagnostic)
}

protocol RemoteInputProvider: Sendable {
    func startInput(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedInputConfiguration
    ) async throws

    func send(_ event: RemoteInputEvent, sessionID: UUID) async throws
    func feedback(sessionID: UUID) async -> AsyncStream<RemoteInputFeedback>
    func releaseAll(sessionID: UUID) async
    func stopInput(sessionID: UUID) async
}
