import AVFAudio
import AudioToolbox
import Foundation

enum AVAudioStreamFormatError: Error, Equatable, Hashable, Sendable {
    case invalidSampleRate
    case noncanonicalChannelLayout
    case channelLayoutCreationFailed
    case formatReadbackMismatch
}

enum AVAudioStreamFormatFactory {
    static func makeInterleavedInt16(
        sampleRate: Double,
        channelLayout: StreamAudioChannelLayout
    ) throws -> AVAudioFormat {
        guard sampleRate == 48_000 else {
            throw AVAudioStreamFormatError.invalidSampleRate
        }
        let canonicalLayout = try? StreamAudioChannelLayout.resolve(
            channelCount: channelLayout.channelCount
        )
        guard canonicalLayout == channelLayout else {
            throw AVAudioStreamFormatError.noncanonicalChannelLayout
        }
        guard let nativeLayout = AVAudioChannelLayout(
            layoutTag: channelLayout.coreAudioLayoutTag
        ) else {
            throw AVAudioStreamFormatError.channelLayoutCreationFailed
        }

        let format = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            interleaved: true,
            channelLayout: nativeLayout
        )
        let description = format.streamDescription.pointee
        let expectedBytesPerFrame = UInt32(
            channelLayout.channelCount * MemoryLayout<Int16>.size
        )
        guard format.commonFormat == .pcmFormatInt16,
              format.sampleRate == sampleRate,
              format.isInterleaved,
              Int(format.channelCount) == channelLayout.channelCount,
              format.channelLayout?.layoutTag == channelLayout.coreAudioLayoutTag,
              Int(format.channelLayout?.channelCount ?? 0)
                == channelLayout.channelCount,
              description.mFormatID == kAudioFormatLinearPCM,
              description.mFormatFlags & kAudioFormatFlagIsSignedInteger != 0,
              description.mFormatFlags & kAudioFormatFlagIsPacked != 0,
              description.mBitsPerChannel == 16,
              description.mChannelsPerFrame
                == AVAudioChannelCount(channelLayout.channelCount),
              description.mFramesPerPacket == 1,
              description.mBytesPerFrame == expectedBytesPerFrame,
              description.mBytesPerPacket == expectedBytesPerFrame else {
            throw AVAudioStreamFormatError.formatReadbackMismatch
        }
        return format
    }
}
