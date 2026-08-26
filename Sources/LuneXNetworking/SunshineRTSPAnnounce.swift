import Foundation

enum SunshineRTSPAnnounceError: Error, Equatable, Sendable {
    case invalidConfiguration
    case unsupportedControlEncryption
}

struct SunshineRTSPAnnounceConfiguration: Equatable, Sendable {
    static let packetSize = 1_392
    static let moonlightFeatureFlags = 2
    static let controlProtocolType = 13

    var width: Int
    var height: Int
    var frameRate: Int
    var bitrateKbps: Int
    var codec: NegotiatedVideoCodec
    var isHDR: Bool
    var videoPort: UInt16

    func serialize() throws -> Data {
        guard width > 0,
              height > 0,
              frameRate > 0,
              frameRate <= Int.max / 100,
              bitrateKbps > 0,
              bitrateKbps <= Int.max / 80,
              videoPort > 0,
              codec != .h264 || !isHDR else {
            throw SunshineRTSPAnnounceError.invalidConfiguration
        }

        let adjustedBitrate = min(100_000, max(1, bitrateKbps * 80 / 100))
        let bitstreamFormat = switch codec {
        case .h264: 0
        case .hevc: 1
        case .av1: 2
        }
        let attributes: [(String, String)] = [
            ("x-ml-general.featureFlags", String(Self.moonlightFeatureFlags)),
            ("x-ss-general.encryptionEnabled", "1"),
            ("x-ss-video[0].chromaSamplingType", "0"),
            ("x-nv-video[0].clientViewportWd", String(width)),
            ("x-nv-video[0].clientViewportHt", String(height)),
            ("x-nv-video[0].maxFPS", String(frameRate)),
            ("x-nv-video[0].packetSize", String(Self.packetSize)),
            ("x-nv-video[0].rateControlMode", "4"),
            ("x-nv-video[0].timeoutLengthMs", "7000"),
            ("x-nv-video[0].framesWithInvalidRefThreshold", "0"),
            ("x-nv-video[0].initialBitrateKbps", String(adjustedBitrate)),
            ("x-nv-video[0].initialPeakBitrateKbps", String(adjustedBitrate)),
            ("x-nv-vqos[0].bw.minimumBitrateKbps", String(adjustedBitrate)),
            ("x-nv-vqos[0].bw.maximumBitrateKbps", String(adjustedBitrate)),
            ("x-ml-video.configuredBitrateKbps", String(bitrateKbps)),
            ("x-nv-vqos[0].fec.enable", "1"),
            ("x-nv-vqos[0].fec.minRequiredFecPackets", "2"),
            ("x-nv-vqos[0].bllFec.enable", "0"),
            ("x-nv-vqos[0].qosTrafficType", "5"),
            ("x-nv-aqos.qosTrafficType", "4"),
            ("x-nv-general.featureFlags", "135"),
            ("x-nv-general.useReliableUdp", String(Self.controlProtocolType)),
            ("x-nv-vqos[0].drc.enable", "0"),
            ("x-nv-general.enableRecoveryMode", "0"),
            ("x-nv-video[0].videoEncoderSlicesPerFrame", "1"),
            ("x-nv-clientSupportHevc", codec == .hevc ? "1" : "0"),
            ("x-nv-vqos[0].bitStreamFormat", String(bitstreamFormat)),
            ("x-nv-video[0].dynamicRangeMode", isHDR ? "1" : "0"),
            ("x-nv-video[0].maxNumReferenceFrames", "1"),
            ("x-nv-video[0].clientRefreshRateX100", String(frameRate * 100)),
            ("x-nv-audio.surround.numChannels", "2"),
            ("x-nv-audio.surround.channelMask", "3"),
            ("x-nv-audio.surround.enable", "0"),
            ("x-nv-audio.surround.AudioQuality", "0"),
            ("x-nv-aqos.packetDuration", "5"),
            ("x-nv-video[0].encoderCscMode", "2")
        ]

        var lines = [
            "v=0",
            "o=android 0 14 IN IPv4 0.0.0.0",
            "s=NVIDIA Streaming Client"
        ]
        lines.append(contentsOf: attributes.map { "a=\($0.0):\($0.1)" })
        lines.append("t=0 0")
        lines.append("m=video \(videoPort)")
        return Data((lines.joined(separator: "\r\n") + "\r\n").utf8)
    }
}
