import AudioToolbox
import Foundation

enum OpusDecoderError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidConfiguration
    case invalidPacketPayload
    case converterCreationFailed(OSStatus)
    case magicCookieRejected(OSStatus)
    case decodeFailed(OSStatus)
    case inconsistentPCMOutput
    case closed

    var description: String {
        switch self {
        case .invalidConfiguration:
            return "The negotiated Opus configuration cannot be represented safely."
        case .invalidPacketPayload:
            return "The Opus packet is empty or exceeds the negotiated packet bound."
        case let .converterCreationFailed(status):
            return "AudioToolbox could not create the Opus decoder (status \(status))."
        case let .magicCookieRejected(status):
            return "AudioToolbox rejected the negotiated Opus mapping (status \(status))."
        case let .decodeFailed(status):
            return "AudioToolbox could not decode the Opus packet (status \(status))."
        case .inconsistentPCMOutput:
            return "AudioToolbox returned inconsistent PCM frame and byte counts."
        case .closed:
            return "The Opus decoder has already closed."
        }
    }
}

struct InterleavedPCMFormat: Equatable, Sendable {
    var sampleRate: Int
    var channelCount: Int
    var bitsPerChannel: Int
    var isSignedInteger: Bool
    var isInterleaved: Bool

    static func signedInt16(
        sampleRate: Int,
        channelCount: Int
    ) -> InterleavedPCMFormat {
        InterleavedPCMFormat(
            sampleRate: sampleRate,
            channelCount: channelCount,
            bitsPerChannel: 16,
            isSignedInteger: true,
            isInterleaved: true
        )
    }
}

struct DecodedPCMBuffer: Equatable, Sendable {
    var sequenceNumber: UInt16
    var rtpTimestamp: UInt32
    var format: InterleavedPCMFormat
    var frameCount: Int
    var interleavedSamples: [Int16]
}

enum OpusHeadEncoder {
    static let maximumSamplesPerFrame = 5_760

    static func encode(
        configuration: NegotiatedAudioStreamConfiguration
    ) throws -> Data {
        try validate(configuration)
        guard let channels = UInt8(exactly: configuration.channelCount),
              let streams = UInt8(exactly: configuration.streamCount),
              let coupledStreams = UInt8(exactly: configuration.coupledStreamCount),
              let sampleRate = UInt32(exactly: configuration.sampleRate) else {
            throw OpusDecoderError.invalidConfiguration
        }

        var cookie = Data("OpusHead".utf8)
        cookie.append(1)
        cookie.append(channels)
        appendLittleEndian(UInt16(0), to: &cookie)
        appendLittleEndian(sampleRate, to: &cookie)
        appendLittleEndian(UInt16(0), to: &cookie)

        let identityMapping = configuration.channelMapping
            == (0..<configuration.channelCount).map(UInt8.init)
        let usesMappingFamilyZero = configuration.channelCount <= 2
            && configuration.streamCount == 1
            && configuration.coupledStreamCount == configuration.channelCount - 1
            && identityMapping
        if usesMappingFamilyZero {
            cookie.append(0)
        } else {
            cookie.append(1)
            cookie.append(streams)
            cookie.append(coupledStreams)
            cookie.append(contentsOf: configuration.channelMapping)
        }
        return cookie
    }

    static func validate(
        _ configuration: NegotiatedAudioStreamConfiguration
    ) throws {
        do {
            try configuration.validate()
        } catch {
            throw OpusDecoderError.invalidConfiguration
        }
        guard (1...maximumSamplesPerFrame).contains(configuration.samplesPerFrame) else {
            throw OpusDecoderError.invalidConfiguration
        }
    }

    private static func appendLittleEndian<T: FixedWidthInteger>(
        _ value: T,
        to data: inout Data
    ) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
    }
}

actor AudioToolboxOpusDecoder {
    private let configuration: NegotiatedAudioStreamConfiguration
    private let pcmFormat: InterleavedPCMFormat
    private var converterOwner: OwnedAudioConverter?

    init(configuration: NegotiatedAudioStreamConfiguration) throws {
        try OpusHeadEncoder.validate(configuration)
        self.configuration = configuration
        self.pcmFormat = .signedInt16(
            sampleRate: configuration.sampleRate,
            channelCount: configuration.channelCount
        )

        let channelCount = UInt32(configuration.channelCount)
        let frameCount = UInt32(configuration.samplesPerFrame)
        var source = AudioStreamBasicDescription(
            mSampleRate: Double(configuration.sampleRate),
            mFormatID: kAudioFormatOpus,
            mFormatFlags: 0,
            mBytesPerPacket: 0,
            mFramesPerPacket: frameCount,
            mBytesPerFrame: 0,
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: 0,
            mReserved: 0
        )
        let bytesPerFrame = UInt32(MemoryLayout<Int16>.size) * channelCount
        var destination = AudioStreamBasicDescription(
            mSampleRate: Double(configuration.sampleRate),
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: bytesPerFrame,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytesPerFrame,
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: 16,
            mReserved: 0
        )

        var createdConverter: AudioConverterRef?
        let creationStatus = AudioConverterNew(&source, &destination, &createdConverter)
        guard creationStatus == noErr, let createdConverter else {
            throw OpusDecoderError.converterCreationFailed(creationStatus)
        }
        do {
            let cookie = try OpusHeadEncoder.encode(configuration: configuration)
            let cookieStatus = cookie.withUnsafeBytes { bytes -> OSStatus in
                guard let baseAddress = bytes.baseAddress else {
                    return kAudio_ParamError
                }
                return AudioConverterSetProperty(
                    createdConverter,
                    kAudioConverterDecompressionMagicCookie,
                    UInt32(bytes.count),
                    baseAddress
                )
            }
            guard cookieStatus == noErr else {
                throw OpusDecoderError.magicCookieRejected(cookieStatus)
            }
            converterOwner = OwnedAudioConverter(createdConverter)
        } catch {
            AudioConverterDispose(createdConverter)
            throw error
        }
    }

    func decode(_ packet: ReceivedAudioPacket) throws -> DecodedPCMBuffer {
        guard let converter = converterOwner?.reference else {
            throw OpusDecoderError.closed
        }
        guard !packet.payload.isEmpty,
              packet.payload.count <= configuration.maximumPacketSize else {
            throw OpusDecoderError.invalidPacketPayload
        }

        let input = OwnedOpusPacketInput(
            payload: packet.payload,
            frameCount: UInt32(configuration.samplesPerFrame)
        )
        let maximumSampleCount = configuration.samplesPerFrame * configuration.channelCount
        var output = [Int16](repeating: 0, count: maximumSampleCount)
        var producedFrames = UInt32(configuration.samplesPerFrame)
        var producedBytes: UInt32 = 0
        let channelCount = UInt32(configuration.channelCount)
        let decodeStatus = output.withUnsafeMutableBytes { bytes -> OSStatus in
            var buffers = AudioBufferList(
                mNumberBuffers: 1,
                mBuffers: AudioBuffer(
                    mNumberChannels: channelCount,
                    mDataByteSize: UInt32(bytes.count),
                    mData: bytes.baseAddress
                )
            )
            let status = AudioConverterFillComplexBuffer(
                converter,
                opusPacketInputProc,
                Unmanaged.passUnretained(input).toOpaque(),
                &producedFrames,
                &buffers,
                nil
            )
            producedBytes = buffers.mBuffers.mDataByteSize
            return status
        }
        guard decodeStatus == noErr || decodeStatus == opusInputTemporarilyUnavailableStatus else {
            throw OpusDecoderError.decodeFailed(decodeStatus)
        }

        let bytesPerFrame = MemoryLayout<Int16>.size * configuration.channelCount
        guard Int(producedBytes) <= output.count * MemoryLayout<Int16>.size,
              Int(producedBytes).isMultiple(of: bytesPerFrame) else {
            throw OpusDecoderError.inconsistentPCMOutput
        }
        let actualFrameCount = Int(producedBytes) / bytesPerFrame
        guard actualFrameCount > 0,
              actualFrameCount <= configuration.samplesPerFrame,
              Int(producedFrames) == actualFrameCount else {
            throw OpusDecoderError.inconsistentPCMOutput
        }
        output.removeLast(output.count - actualFrameCount * configuration.channelCount)
        return DecodedPCMBuffer(
            sequenceNumber: packet.sequenceNumber,
            rtpTimestamp: packet.timestamp,
            format: pcmFormat,
            frameCount: actualFrameCount,
            interleavedSamples: output
        )
    }

    func reset() throws {
        guard let converter = converterOwner?.reference else {
            throw OpusDecoderError.closed
        }
        let status = AudioConverterReset(converter)
        guard status == noErr else { throw OpusDecoderError.decodeFailed(status) }
    }

    func close() {
        converterOwner = nil
    }
}

private final class OwnedAudioConverter: @unchecked Sendable {
    let reference: AudioConverterRef

    init(_ reference: AudioConverterRef) {
        self.reference = reference
    }

    deinit {
        AudioConverterDispose(reference)
    }
}

private final class OwnedOpusPacketInput {
    let storage: UnsafeMutableRawPointer
    let byteCount: Int
    let packetDescription: UnsafeMutablePointer<AudioStreamPacketDescription>
    private(set) var wasProvided = false

    init(payload: Data, frameCount: UInt32) {
        byteCount = payload.count
        storage = .allocate(byteCount: payload.count, alignment: 16)
        payload.copyBytes(
            to: storage.assumingMemoryBound(to: UInt8.self),
            count: payload.count
        )
        packetDescription = .allocate(capacity: 1)
        packetDescription.initialize(to: AudioStreamPacketDescription(
            mStartOffset: 0,
            mVariableFramesInPacket: frameCount,
            mDataByteSize: UInt32(payload.count)
        ))
    }

    deinit {
        packetDescription.deinitialize(count: 1)
        packetDescription.deallocate()
        storage.deallocate()
    }

    func markProvided() {
        wasProvided = true
    }
}

// A private callback status keeps the pull converter live when the current network packet is
// exhausted. Returning zero packets with noErr would instead declare a permanent end of stream.
private let opusInputTemporarilyUnavailableStatus = OSStatus(bitPattern: 0x6E646174) // 'ndat'

private let opusPacketInputProc: AudioConverterComplexInputDataProc = {
    _, ioNumberDataPackets, ioData, outPacketDescription, userData in
    guard let userData else {
        ioNumberDataPackets.pointee = 0
        return kAudio_ParamError
    }
    let input = Unmanaged<OwnedOpusPacketInput>
        .fromOpaque(userData)
        .takeUnretainedValue()
    guard !input.wasProvided else {
        ioNumberDataPackets.pointee = 0
        return opusInputTemporarilyUnavailableStatus
    }
    ioNumberDataPackets.pointee = 1
    ioData.pointee.mNumberBuffers = 1
    ioData.pointee.mBuffers.mNumberChannels = 0
    ioData.pointee.mBuffers.mDataByteSize = UInt32(input.byteCount)
    ioData.pointee.mBuffers.mData = input.storage
    outPacketDescription?.pointee = input.packetDescription
    input.markProvided()
    return noErr
}
