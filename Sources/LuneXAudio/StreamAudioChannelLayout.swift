import CoreAudioTypes
import Foundation

enum StreamAudioChannel: String, Codable, CaseIterable, Hashable, Sendable {
    case frontLeft = "front-left"
    case frontRight = "front-right"
    case frontCenter = "front-center"
    case lowFrequencyEffects = "low-frequency-effects"
    case backLeft = "back-left"
    case backRight = "back-right"
    case sideLeft = "side-left"
    case sideRight = "side-right"
}

enum StreamAudioChannelLayoutKind: String, Codable, Hashable, Sendable {
    case mono
    case stereo
    case wave5Point1 = "wave-5.1"
    case wave7Point1 = "wave-7.1"
}

enum StreamAudioSpatialEligibility: String, Codable, Hashable, Sendable {
    case nonspatialMono = "nonspatial-mono"
    case ambienceBed = "ambience-bed"
}

struct StreamAudioChannelLayoutSignature: Codable, Equatable, Hashable, Sendable {
    let identifier: String
    let channelCount: Int
    let moonlightChannelMask: UInt32
    let coreAudioLayoutTagRawValue: UInt32
}

struct StreamAudioChannelLayout: Codable, Equatable, Hashable, Sendable {
    let kind: StreamAudioChannelLayoutKind
    let channels: [StreamAudioChannel]
    let moonlightChannelMask: UInt32
    let coreAudioLayoutTagRawValue: UInt32
    let spatialEligibility: StreamAudioSpatialEligibility

    var channelCount: Int {
        channels.count
    }

    var coreAudioLayoutTag: AudioChannelLayoutTag {
        AudioChannelLayoutTag(coreAudioLayoutTagRawValue)
    }

    var signature: StreamAudioChannelLayoutSignature {
        StreamAudioChannelLayoutSignature(
            identifier: kind.rawValue,
            channelCount: channelCount,
            moonlightChannelMask: moonlightChannelMask,
            coreAudioLayoutTagRawValue: coreAudioLayoutTagRawValue
        )
    }

    static let mono = StreamAudioChannelLayout(
        kind: .mono,
        channels: [.frontCenter],
        moonlightChannelMask: 0x0004,
        coreAudioLayoutTagRawValue: UInt32(kAudioChannelLayoutTag_Mono),
        spatialEligibility: .nonspatialMono
    )

    static let stereo = StreamAudioChannelLayout(
        kind: .stereo,
        channels: [.frontLeft, .frontRight],
        moonlightChannelMask: 0x0003,
        coreAudioLayoutTagRawValue: UInt32(kAudioChannelLayoutTag_Stereo),
        spatialEligibility: .ambienceBed
    )

    static let wave5Point1 = StreamAudioChannelLayout(
        kind: .wave5Point1,
        channels: [
            .frontLeft,
            .frontRight,
            .frontCenter,
            .lowFrequencyEffects,
            .backLeft,
            .backRight
        ],
        moonlightChannelMask: 0x003F,
        coreAudioLayoutTagRawValue: UInt32(kAudioChannelLayoutTag_WAVE_5_1_A),
        spatialEligibility: .ambienceBed
    )

    static let wave7Point1 = StreamAudioChannelLayout(
        kind: .wave7Point1,
        channels: [
            .frontLeft,
            .frontRight,
            .frontCenter,
            .lowFrequencyEffects,
            .backLeft,
            .backRight,
            .sideLeft,
            .sideRight
        ],
        moonlightChannelMask: 0x063F,
        coreAudioLayoutTagRawValue: UInt32(kAudioChannelLayoutTag_WAVE_7_1),
        spatialEligibility: .ambienceBed
    )

    static func resolve(channelCount: Int) throws -> StreamAudioChannelLayout {
        switch channelCount {
        case 1:
            .mono
        case 2:
            .stereo
        case 6:
            .wave5Point1
        case 8:
            .wave7Point1
        default:
            throw StreamAudioChannelLayoutError.unsupportedChannelCount(channelCount)
        }
    }
}

enum StreamAudioChannelLayoutError: Error, Equatable, Hashable, Sendable,
    CustomStringConvertible
{
    case unsupportedChannelCount(Int)

    var description: String {
        switch self {
        case let .unsupportedChannelCount(channelCount):
            "Unsupported audio channel count: \(channelCount)"
        }
    }
}
