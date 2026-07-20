import AudioToolbox
import CryptoKit
import Foundation

private enum SpikeError: Error, CustomStringConvertible {
    case usage
    case fixture(String)
    case converterCreation(OSStatus)
    case cookie(OSStatus)
    case decode(OSStatus)
    case decodedFrameCount(maximum: Int, actual: Int)
    case silentOutput

    var description: String {
        switch self {
        case .usage:
            return "usage: lunex-opus-spike <stereo-5ms-opus.json>"
        case let .fixture(message):
            return "invalid fixture: \(message)"
        case let .converterCreation(status):
            return "AudioConverterNew failed: \(fourCharacterCode(status)) (\(status))"
        case let .cookie(status):
            return "setting Opus magic cookie failed: \(fourCharacterCode(status)) (\(status))"
        case let .decode(status):
            return "AudioConverterFillComplexBuffer failed: \(fourCharacterCode(status)) (\(status))"
        case let .decodedFrameCount(maximum, actual):
            return "decoded \(actual) frames, expected 1...\(maximum) after priming"
        case .silentOutput:
            return "decoded PCM contains no non-zero samples"
        }
    }
}

private struct OpusFixture: Decodable {
    let base64Payload: String
    let channelCount: UInt32
    let coupledStreamCount: UInt8
    let expectedDecodedFrames: Int
    let frameDurationMilliseconds: Int
    let sampleRate: Double
    let sha256: String
    let streamCount: UInt8
}

private final class PacketInput {
    let storage: UnsafeMutableRawPointer
    let byteCount: Int
    let packetDescription: UnsafeMutablePointer<AudioStreamPacketDescription>
    private(set) var wasProvided = false

    init(payload: Data, frames: UInt32) {
        byteCount = payload.count
        storage = .allocate(byteCount: payload.count, alignment: 16)
        payload.copyBytes(to: storage.assumingMemoryBound(to: UInt8.self), count: payload.count)
        packetDescription = .allocate(capacity: 1)
        packetDescription.initialize(to: AudioStreamPacketDescription(
            mStartOffset: 0,
            mVariableFramesInPacket: frames,
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

private let packetInputProc: AudioConverterComplexInputDataProc = {
    _, ioNumberDataPackets, ioData, outPacketDescription, userData in
    guard let userData else {
        ioNumberDataPackets.pointee = 0
        return kAudio_ParamError
    }
    let input = Unmanaged<PacketInput>.fromOpaque(userData).takeUnretainedValue()
    guard !input.wasProvided else {
        ioNumberDataPackets.pointee = 0
        return noErr
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

private func decode(_ fixture: OpusFixture, payload: Data) throws -> [Int16] {
    let frameCount = UInt32(fixture.expectedDecodedFrames)
    var source = AudioStreamBasicDescription(
        mSampleRate: fixture.sampleRate,
        mFormatID: kAudioFormatOpus,
        mFormatFlags: 0,
        mBytesPerPacket: 0,
        mFramesPerPacket: frameCount,
        mBytesPerFrame: 0,
        mChannelsPerFrame: fixture.channelCount,
        mBitsPerChannel: 0,
        mReserved: 0
    )
    let bytesPerFrame = UInt32(MemoryLayout<Int16>.size) * fixture.channelCount
    var destination = AudioStreamBasicDescription(
        mSampleRate: fixture.sampleRate,
        mFormatID: kAudioFormatLinearPCM,
        mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
        mBytesPerPacket: bytesPerFrame,
        mFramesPerPacket: 1,
        mBytesPerFrame: bytesPerFrame,
        mChannelsPerFrame: fixture.channelCount,
        mBitsPerChannel: 16,
        mReserved: 0
    )

    var converter: AudioConverterRef?
    let creationStatus = AudioConverterNew(&source, &destination, &converter)
    guard creationStatus == noErr, let converter else {
        throw SpikeError.converterCreation(creationStatus)
    }
    defer { AudioConverterDispose(converter) }

    var cookie = opusHeadCookie(for: fixture)
    let cookieStatus = cookie.withUnsafeMutableBytes { bytes in
        guard let baseAddress = bytes.baseAddress else {
            return kAudio_ParamError
        }
        return AudioConverterSetProperty(
            converter,
            kAudioConverterDecompressionMagicCookie,
            UInt32(bytes.count),
            baseAddress
        )
    }
    guard cookieStatus == noErr else {
        throw SpikeError.cookie(cookieStatus)
    }

    let input = PacketInput(payload: payload, frames: frameCount)
    var output = [Int16](
        repeating: 0,
        count: fixture.expectedDecodedFrames * Int(fixture.channelCount)
    )
    var producedFrames: UInt32 = frameCount
    var producedBytes: UInt32 = 0
    let decodeStatus = output.withUnsafeMutableBytes { bytes -> OSStatus in
        var buffers = AudioBufferList(
            mNumberBuffers: 1,
            mBuffers: AudioBuffer(
                mNumberChannels: fixture.channelCount,
                mDataByteSize: UInt32(bytes.count),
                mData: bytes.baseAddress
            )
        )
        let status = AudioConverterFillComplexBuffer(
            converter,
            packetInputProc,
            Unmanaged.passUnretained(input).toOpaque(),
            &producedFrames,
            &buffers,
            nil
        )
        producedBytes = buffers.mBuffers.mDataByteSize
        return status
    }
    guard decodeStatus == noErr else {
        throw SpikeError.decode(decodeStatus)
    }

    let bytesPerSampleFrame = Int(bytesPerFrame)
    let actualFrames = Int(producedBytes) / bytesPerSampleFrame
    guard actualFrames > 0,
          actualFrames <= fixture.expectedDecodedFrames,
          Int(producedFrames) == actualFrames else {
        throw SpikeError.decodedFrameCount(
            maximum: fixture.expectedDecodedFrames,
            actual: actualFrames
        )
    }
    guard output.contains(where: { $0 != 0 }) else {
        throw SpikeError.silentOutput
    }
    return Array(output.prefix(actualFrames * Int(fixture.channelCount)))
}

private func opusHeadCookie(for fixture: OpusFixture) -> Data {
    var cookie = Data("OpusHead".utf8)
    cookie.append(1)
    cookie.append(UInt8(fixture.channelCount))
    appendLittleEndian(UInt16(0), to: &cookie)
    appendLittleEndian(UInt32(fixture.sampleRate), to: &cookie)
    appendLittleEndian(UInt16(0), to: &cookie)

    if fixture.channelCount <= 2 && fixture.streamCount == 1 {
        cookie.append(0)
    } else {
        cookie.append(1)
        cookie.append(fixture.streamCount)
        cookie.append(fixture.coupledStreamCount)
        for index in 0..<fixture.channelCount {
            cookie.append(UInt8(index))
        }
    }
    return cookie
}

private func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
    var littleEndian = value.littleEndian
    withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
}

private func fourCharacterCode(_ status: OSStatus) -> String {
    let value = UInt32(bitPattern: status)
    let bytes = [
        UInt8((value >> 24) & 0xFF),
        UInt8((value >> 16) & 0xFF),
        UInt8((value >> 8) & 0xFF),
        UInt8(value & 0xFF)
    ]
    guard bytes.allSatisfy({ $0 >= 0x20 && $0 <= 0x7E }) else {
        return "non-printable"
    }
    return String(bytes: bytes, encoding: .ascii) ?? "non-printable"
}

private func run() throws {
    guard CommandLine.arguments.count == 2 else {
        throw SpikeError.usage
    }
    let fixtureURL = URL(fileURLWithPath: CommandLine.arguments[1])
    let fixtureData = try Data(contentsOf: fixtureURL)
    let fixture = try JSONDecoder().decode(OpusFixture.self, from: fixtureData)
    guard fixture.sampleRate == 48_000 else {
        throw SpikeError.fixture("sample rate must be 48000 Hz")
    }
    guard fixture.frameDurationMilliseconds == 5,
          fixture.expectedDecodedFrames == 240 else {
        throw SpikeError.fixture("expected the Sunshine 5 ms / 240-frame profile")
    }
    guard let payload = Data(base64Encoded: fixture.base64Payload) else {
        throw SpikeError.fixture("payload is not valid base64")
    }
    let digest = SHA256.hash(data: payload).map { String(format: "%02x", $0) }.joined()
    guard digest == fixture.sha256 else {
        throw SpikeError.fixture("SHA-256 mismatch")
    }

    let pcm = try decode(fixture, payload: payload)
    let peak = pcm.lazy.map { abs(Int($0)) }.max() ?? 0
    print("PASS: synthetic raw Opus payload hash verified (\(payload.count) bytes)")
    print("PASS: AudioConverter decoded \(pcm.count / Int(fixture.channelCount)) frames across \(fixture.channelCount) channels")
    print("PASS: decoded PCM is non-silent (peak \(peak))")
    print("PASS: input matches post-RTP Sunshine decoder framing")
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("FAIL: \(error)\n".utf8))
    exit(EXIT_FAILURE)
}
