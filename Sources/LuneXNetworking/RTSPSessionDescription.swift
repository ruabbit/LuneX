import Foundation

enum SunshineRTSPNegotiationError: Error, Equatable, Sendable {
    case unexpectedResponse
    case descriptionTooLarge
    case tooManyDescriptionLines
    case descriptionLineTooLarge
    case invalidDescriptionEncoding
    case invalidNumericAttribute(String)
    case invalidOpusConfiguration
    case missingSession
    case duplicateHeader(String)
    case invalidSession
    case missingTransport
    case invalidServerPort
    case invalidExtensionValue(String)
}

struct SunshineOpusConfiguration: Equatable, Sendable {
    var channelCount: Int
    var streamCount: Int
    var coupledStreamCount: Int
    var channelMapping: [UInt8]

    func makeRuntimeConfiguration(
        samplesPerFrame: Int,
        maximumPacketSize: Int
    ) throws -> NegotiatedAudioStreamConfiguration {
        let configuration = NegotiatedAudioStreamConfiguration(
            sampleRate: 48_000,
            channelCount: channelCount,
            streamCount: streamCount,
            coupledStreamCount: coupledStreamCount,
            samplesPerFrame: samplesPerFrame,
            channelMapping: channelMapping,
            maximumPacketSize: maximumPacketSize
        )
        try configuration.validate()
        return configuration
    }
}

struct SunshineSessionDescription: Equatable, Sendable {
    var featureFlags: UInt32
    var encryptionSupported: UInt32
    var encryptionRequested: UInt32
    var supportsReferenceFrameInvalidation: Bool
    var availableVideoCodecs: Set<NegotiatedVideoCodec>
    var opusConfigurations: [SunshineOpusConfiguration]
    var attributes: [String: [String]]

    func opusConfiguration(
        channelCount: Int,
        highQuality: Bool
    ) -> SunshineOpusConfiguration? {
        if channelCount == 2 {
            return SunshineOpusConfiguration(
                channelCount: 2,
                streamCount: 1,
                coupledStreamCount: 1,
                channelMapping: [0, 1]
            )
        }
        let matches = opusConfigurations.filter { $0.channelCount == channelCount }
        return highQuality ? matches.last : matches.first
    }
}

enum SunshineSessionDescriptionParser {
    private static let maximumDescriptionBytes = 262_144
    private static let maximumLineCount = 512
    private static let maximumLineBytes = 8_192

    static func parse(_ response: RTSPResponse) throws -> SunshineSessionDescription {
        guard response.statusCode == 200 else {
            throw SunshineRTSPNegotiationError.unexpectedResponse
        }
        guard !response.body.isEmpty,
              response.body.count <= maximumDescriptionBytes else {
            throw SunshineRTSPNegotiationError.descriptionTooLarge
        }
        guard let text = String(data: response.body, encoding: .utf8) else {
            throw SunshineRTSPNegotiationError.invalidDescriptionEncoding
        }
        let lines = text.split(
            omittingEmptySubsequences: true,
            whereSeparator: { $0 == "\r" || $0 == "\n" }
        ).map(String.init)
        guard lines.count <= maximumLineCount else {
            throw SunshineRTSPNegotiationError.tooManyDescriptionLines
        }
        guard lines.allSatisfy({ $0.utf8.count <= maximumLineBytes }) else {
            throw SunshineRTSPNegotiationError.descriptionLineTooLarge
        }

        var attributes: [String: [String]] = [:]
        var opusConfigurations: [SunshineOpusConfiguration] = []
        var codecs: Set<NegotiatedVideoCodec> = [.h264]
        var supportsReferenceFrameInvalidation = false

        for line in lines {
            if line.caseInsensitiveCompare("sprop-parameter-sets=AAAAAU") == .orderedSame {
                codecs.insert(.hevc)
            }
            if line.caseInsensitiveCompare("a=rtpmap:98 AV1/90000") == .orderedSame {
                codecs.insert(.av1)
            }
            if line.hasPrefix("a=") {
                let attribute = String(line.dropFirst(2))
                let parts = attribute.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                let name = String(parts[0])
                let value = parts.count == 2 ? String(parts[1]) : ""
                attributes[name, default: []].append(value)
                if name == "x-nv-video[0].refPicInvalidation" {
                    supportsReferenceFrameInvalidation = true
                }
                if name == "fmtp", value.hasPrefix("97 surround-params=") {
                    let compact = String(value.dropFirst("97 surround-params=".count))
                    opusConfigurations.append(try parseOpusConfiguration(compact))
                }
            }
        }

        return SunshineSessionDescription(
            featureFlags: try numericAttribute(
                "x-ss-general.featureFlags",
                attributes: attributes,
                defaultValue: 0
            ),
            encryptionSupported: try numericAttribute(
                "x-ss-general.encryptionSupported",
                attributes: attributes,
                defaultValue: 0
            ),
            encryptionRequested: try numericAttribute(
                "x-ss-general.encryptionRequested",
                attributes: attributes,
                defaultValue: 0
            ),
            supportsReferenceFrameInvalidation: supportsReferenceFrameInvalidation,
            availableVideoCodecs: codecs,
            opusConfigurations: opusConfigurations,
            attributes: attributes
        )
    }

    private static func numericAttribute(
        _ name: String,
        attributes: [String: [String]],
        defaultValue: UInt32
    ) throws -> UInt32 {
        guard let values = attributes[name] else { return defaultValue }
        guard values.count == 1,
              let value = parseUInt32(values[0]) else {
            throw SunshineRTSPNegotiationError.invalidNumericAttribute(name)
        }
        return value
    }

    private static func parseUInt32(_ value: String) -> UInt32? {
        if value.lowercased().hasPrefix("0x") {
            return UInt32(value.dropFirst(2), radix: 16)
        }
        return UInt32(value, radix: 10)
    }

    private static func parseOpusConfiguration(
        _ compact: String
    ) throws -> SunshineOpusConfiguration {
        let bytes = [UInt8](compact.utf8)
        guard bytes.count >= 5,
              bytes.allSatisfy({ (48...57).contains($0) }) else {
            throw SunshineRTSPNegotiationError.invalidOpusConfiguration
        }
        let channelCount = Int(bytes[0] - 48)
        let streamCount = Int(bytes[1] - 48)
        let coupledStreamCount = Int(bytes[2] - 48)
        guard (1...8).contains(channelCount),
              bytes.count == 3 + channelCount,
              streamCount > 0,
              coupledStreamCount <= streamCount,
              streamCount + coupledStreamCount == channelCount else {
            throw SunshineRTSPNegotiationError.invalidOpusConfiguration
        }
        let mapping = bytes.dropFirst(3).map { $0 - 48 }
        guard mapping.allSatisfy({ Int($0) < channelCount }),
              Set(mapping).count == channelCount else {
            throw SunshineRTSPNegotiationError.invalidOpusConfiguration
        }
        return SunshineOpusConfiguration(
            channelCount: channelCount,
            streamCount: streamCount,
            coupledStreamCount: coupledStreamCount,
            channelMapping: mapping
        )
    }
}

enum RTSPSetupStreamKind: String, Equatable, Sendable {
    case audio
    case video
    case control
}

struct RTSPSetupStreamParameters: Equatable, Sendable {
    var kind: RTSPSetupStreamKind
    var sessionToken: String
    var serverPort: UInt16
    var pingPayload: String?
    var controlConnectData: UInt32?

    func endpoint(host: String) -> RuntimeNetworkEndpoint {
        RuntimeNetworkEndpoint(host: host, port: serverPort, transport: .udp)
    }
}

enum RTSPSetupResponseParser {
    static func parse(
        _ response: RTSPResponse,
        kind: RTSPSetupStreamKind
    ) throws -> RTSPSetupStreamParameters {
        guard response.statusCode == 200 else {
            throw SunshineRTSPNegotiationError.unexpectedResponse
        }
        let sessionValue = try uniqueHeader("Session", response: response)
        guard let sessionValue else {
            throw SunshineRTSPNegotiationError.missingSession
        }
        let sessionToken = sessionValue.split(
            separator: ";",
            maxSplits: 1,
            omittingEmptySubsequences: false
        ).first.map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) } ?? ""
        guard !sessionToken.isEmpty,
              sessionToken.utf8.count <= 128,
              sessionToken.utf8.allSatisfy({ (33...126).contains($0) }) else {
            throw SunshineRTSPNegotiationError.invalidSession
        }

        guard let transport = try uniqueHeader("Transport", response: response) else {
            throw SunshineRTSPNegotiationError.missingTransport
        }
        let port = try parseServerPort(transport)
        let pingPayload = try optionalASCIIHeader(
            "X-SS-Ping-Payload",
            response: response,
            maximumBytes: 64
        )
        let connectValue = try uniqueHeader("X-SS-Connect-Data", response: response)
        let connectData: UInt32?
        if let connectValue {
            guard let parsed = parseUInt32(connectValue) else {
                throw SunshineRTSPNegotiationError.invalidExtensionValue("X-SS-Connect-Data")
            }
            connectData = parsed
        } else {
            connectData = nil
        }

        return RTSPSetupStreamParameters(
            kind: kind,
            sessionToken: sessionToken,
            serverPort: port,
            pingPayload: pingPayload,
            controlConnectData: connectData
        )
    }

    private static func uniqueHeader(
        _ name: String,
        response: RTSPResponse
    ) throws -> String? {
        let values = response.headerValues(named: name)
        guard values.count <= 1 else {
            throw SunshineRTSPNegotiationError.duplicateHeader(name)
        }
        return values.first
    }

    private static func optionalASCIIHeader(
        _ name: String,
        response: RTSPResponse,
        maximumBytes: Int
    ) throws -> String? {
        guard let value = try uniqueHeader(name, response: response) else { return nil }
        guard !value.isEmpty,
              value.utf8.count <= maximumBytes,
              value.utf8.allSatisfy({ (33...126).contains($0) }) else {
            throw SunshineRTSPNegotiationError.invalidExtensionValue(name)
        }
        return value
    }

    private static func parseServerPort(_ transport: String) throws -> UInt16 {
        for component in transport.split(separator: ";", omittingEmptySubsequences: true) {
            let pair = component.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2,
                  pair[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    .caseInsensitiveCompare("server_port") == .orderedSame else {
                continue
            }
            let firstPort = pair[1].split(separator: "-", maxSplits: 1).first ?? ""
            guard let port = UInt16(firstPort.trimmingCharacters(in: .whitespacesAndNewlines)),
                  port > 0 else {
                throw SunshineRTSPNegotiationError.invalidServerPort
            }
            return port
        }
        throw SunshineRTSPNegotiationError.invalidServerPort
    }

    private static func parseUInt32(_ value: String) -> UInt32? {
        if value.lowercased().hasPrefix("0x") {
            return UInt32(value.dropFirst(2), radix: 16)
        }
        return UInt32(value, radix: 10)
    }
}
