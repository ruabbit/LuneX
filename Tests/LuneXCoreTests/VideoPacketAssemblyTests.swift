import Foundation
import XCTest

final class VideoPacketAssemblyTests: XCTestCase {
    func testSyntheticFixtureParsesReordersAndAssemblesByteExactly() throws {
        let fixture = try loadFixture()
        let limits = MoonlightVideoPacketLimits(
            maximumDatagramBytes: 256,
            maximumDataShardsPerBlock: 16,
            maximumTotalShardsPerBlock: 32
        )
        let byName = Dictionary(uniqueKeysWithValues: fixture.packets.map { ($0.name, $0) })
        let order = ["first", "last", "middle"]
        let receiveTimes: [UInt64] = [100, 300, 200]
        var parsed: [MoonlightVideoPacket] = []
        for (index, name) in order.enumerated() {
            let vector = try XCTUnwrap(byName[name])
            parsed.append(try MoonlightVideoPacketParser.parse(
                Data(spacedVideoHex: vector.datagramHex),
                receiveTimeNanoseconds: receiveTimes[index],
                limits: limits
            ))
        }

        XCTAssertEqual(parsed[0].rtpSequenceNumber, 100)
        XCTAssertEqual(parsed[0].streamSequenceNumber, 100)
        XCTAssertEqual(parsed[0].frameIndex, 7)
        XCTAssertEqual(parsed[0].rtpTimestamp, 90_000)
        XCTAssertEqual(parsed[0].ssrc, 0x1234_5678)
        XCTAssertTrue(parsed[0].isTrueFrameStart)
        XCTAssertTrue(parsed[1].isTrueFrameEnd)

        var assembler = try VideoAccessUnitAssembler(codec: try XCTUnwrap(
            NegotiatedVideoCodec(rawValue: fixture.codec)
        ))
        let events = parsed.flatMap { assembler.ingest($0) }
        let accessUnit = try XCTUnwrap(events.compactMap(\.accessUnit).only)

        XCTAssertEqual(accessUnit.frameIndex, fixture.expected.frameIndex)
        XCTAssertEqual(accessUnit.frameType.rawValue, fixture.expected.frameType)
        XCTAssertEqual(
            accessUnit.hostProcessingLatencyTenthsOfMillisecond,
            fixture.expected.hostProcessingLatencyTenthsOfMillisecond
        )
        XCTAssertEqual(accessUnit.firstReceiveTimeNanoseconds, 100)
        XCTAssertEqual(accessUnit.lastReceiveTimeNanoseconds, 300)
        XCTAssertEqual(accessUnit.packetCount, 3)
        XCTAssertEqual(accessUnit.payload, try Data(spacedVideoHex: fixture.expected.payloadHex))
        XCTAssertTrue(events.compactMap(\.frameLoss).isEmpty)
    }

    func testParserUsesDataStartIndexAndRejectsMalformedBoundsAndHeaders() throws {
        let valid = makeDatagram(
            rtpSequence: 9,
            streamSequence: 9,
            frameIndex: 1,
            shardIndex: 0,
            dataShardCount: 1,
            flags: [.containsPictureData, .startOfFrame, .endOfFrame],
            payload: shortHeader(lastPayloadLength: 9) + Data([0x65])
        )
        var shifted = Data([0xFF]) + valid
        shifted.removeFirst()
        let packet = try MoonlightVideoPacketParser.parse(
            shifted,
            receiveTimeNanoseconds: 1,
            limits: packetLimits(maximumDatagramBytes: valid.count)
        )
        XCTAssertEqual(packet.frameIndex, 1)

        let highFECParity = makeDatagram(
            rtpSequence: 11,
            streamSequence: 99,
            frameIndex: 1,
            shardIndex: 2,
            dataShardCount: 1,
            fecPercentage: 200,
            flags: [],
            payload: Data([0xAA])
        )
        let parsedParity = try MoonlightVideoPacketParser.parse(
            highFECParity,
            receiveTimeNanoseconds: 2,
            limits: packetLimits()
        )
        XCTAssertTrue(parsedParity.isParity)
        XCTAssertEqual(parsedParity.parityShardCount, 2)

        assertPacketError(.invalidLimits) {
            _ = try MoonlightVideoPacketParser.parse(
                valid,
                receiveTimeNanoseconds: 0,
                limits: MoonlightVideoPacketLimits(
                    maximumDatagramBytes: 32,
                    maximumDataShardsPerBlock: 1,
                    maximumTotalShardsPerBlock: 1
                )
            )
        }
        assertPacketError(.datagramTooSmall) {
            _ = try MoonlightVideoPacketParser.parse(
                Data(valid.prefix(31)),
                receiveTimeNanoseconds: 0,
                limits: packetLimits()
            )
        }
        assertPacketError(.datagramTooLarge) {
            _ = try MoonlightVideoPacketParser.parse(
                valid + Data([0]),
                receiveTimeNanoseconds: 0,
                limits: packetLimits(maximumDatagramBytes: valid.count)
            )
        }

        var noExtension = valid
        noExtension[noExtension.startIndex] = 0x80
        assertPacketError(.unsupportedRTPLayout) {
            _ = try MoonlightVideoPacketParser.parse(
                noExtension,
                receiveTimeNanoseconds: 0,
                limits: packetLimits()
            )
        }

        var unknownFlag = valid
        unknownFlag[unknownFlag.startIndex + 24] = 0x0F
        assertPacketError(.invalidPacketFlags) {
            _ = try MoonlightVideoPacketParser.parse(
                unknownFlag,
                receiveTimeNanoseconds: 0,
                limits: packetLimits()
            )
        }

        var zeroDataShards = valid
        replaceLittleEndian32(in: &zeroDataShards, at: 28, with: 0)
        assertPacketError(.invalidFECEnvelope) {
            _ = try MoonlightVideoPacketParser.parse(
                zeroDataShards,
                receiveTimeNanoseconds: 0,
                limits: packetLimits()
            )
        }

        var inconsistentSequence = valid
        inconsistentSequence[inconsistentSequence.startIndex + 17] = 10
        assertPacketError(.invalidPacketSequence) {
            _ = try MoonlightVideoPacketParser.parse(
                inconsistentSequence,
                receiveTimeNanoseconds: 0,
                limits: packetLimits()
            )
        }

        assertPacketError(.emptyPayload) {
            _ = try MoonlightVideoPacketParser.parse(
                Data(valid.prefix(32)),
                receiveTimeNanoseconds: 0,
                limits: packetLimits()
            )
        }
    }

    func testMultiBlockFrameUsesTrueBoundariesAndIgnoresParity() throws {
        var assembler = try VideoAccessUnitAssembler(codec: .hevc)
        let blockOne = makePacket(
            sequence: 102,
            frameIndex: 20,
            blockIndex: 1,
            lastBlockIndex: 1,
            shardIndex: 0,
            dataShardCount: 1,
            payload: Data([0xBB])
        )
        let parity = makePacket(
            sequence: 101,
            frameIndex: 20,
            blockIndex: 0,
            lastBlockIndex: 1,
            shardIndex: 1,
            dataShardCount: 1,
            fecPercentage: 100,
            payload: Data([0xCC])
        )
        let blockZero = makePacket(
            sequence: 100,
            frameIndex: 20,
            blockIndex: 0,
            lastBlockIndex: 1,
            shardIndex: 0,
            dataShardCount: 1,
            fecPercentage: 100,
            payload: shortHeader(lastPayloadLength: 1) + Data([0xAA])
        )

        XCTAssertFalse(blockOne.isTrueFrameStart)
        XCTAssertTrue(blockOne.isTrueFrameEnd)
        XCTAssertEqual(assembler.ingest(blockOne), [])
        XCTAssertEqual(assembler.ingest(parity), [.packetDiscarded(.parity)])
        let events = assembler.ingest(blockZero)
        let unit = try XCTUnwrap(events.compactMap(\.accessUnit).only)
        XCTAssertEqual(unit.payload, Data([0xAA, 0xBB]))
        XCTAssertEqual(unit.packetCount, 2)
    }

    func testDuplicateIsIdempotentAndConflictingDuplicateDropsFrame() throws {
        var assembler = try VideoAccessUnitAssembler(codec: .h264)
        let first = makePacket(
            sequence: 40,
            frameIndex: 9,
            shardIndex: 0,
            dataShardCount: 2,
            payload: shortHeader(lastPayloadLength: 1) + Data([0x01])
        )
        var laterDuplicate = first
        laterDuplicate.receiveTimeNanoseconds = 200

        XCTAssertEqual(assembler.ingest(first), [])
        XCTAssertEqual(assembler.ingest(laterDuplicate), [.packetDiscarded(.duplicate)])

        var conflict = first
        conflict.payload[conflict.payload.startIndex + 8] = 0x02
        let events = assembler.ingest(conflict)
        XCTAssertEqual(events.compactMap(\.frameLoss).only?.reason, .conflictingDuplicate)
        XCTAssertTrue(events.compactMap(\.frameLoss).only?.requiresIDR == true)
        XCTAssertEqual(assembler.finish(), [])
    }

    func testSupersededAndSkippedFramesProduceOneIDRRangeAndLatePacketIsIgnored() throws {
        var assembler = try VideoAccessUnitAssembler(codec: .h264)
        let incomplete = makePacket(
            sequence: 50,
            frameIndex: 10,
            shardIndex: 0,
            dataShardCount: 2,
            payload: shortHeader(lastPayloadLength: 1) + Data([0x10])
        )
        let frameTwelve = makePacket(
            sequence: 60,
            frameIndex: 12,
            shardIndex: 0,
            dataShardCount: 1,
            payload: shortHeader(lastPayloadLength: 9) + Data([0x12])
        )
        XCTAssertEqual(assembler.ingest(incomplete), [])

        let events = assembler.ingest(frameTwelve)
        XCTAssertEqual(events.compactMap(\.frameLoss).only, VideoFrameLoss(
            firstFrameIndex: 10,
            lastFrameIndex: 11,
            reason: .superseded,
            requiresIDR: true
        ))
        XCTAssertEqual(events.compactMap(\.accessUnit).only?.frameIndex, 12)
        XCTAssertEqual(assembler.ingest(incomplete), [.packetDiscarded(.lateFrame)])
    }

    func testSequenceAndFrameWrapDoNotCreateFalseLoss() throws {
        XCTAssertTrue(WrappingSequenceComparison.isBefore16(UInt16.max, 0))
        XCTAssertTrue(WrappingSequenceComparison.isBefore24(0x00FF_FFFF, 0))
        XCTAssertTrue(WrappingSequenceComparison.isBefore32(UInt32.max, 0))
        XCTAssertFalse(WrappingSequenceComparison.isBefore32(0, UInt32.max))

        var assembler = try VideoAccessUnitAssembler(codec: .h264)
        let first = makePacket(
            sequence: UInt16.max,
            streamSequence: 0x00FF_FFFF,
            frameIndex: UInt32.max,
            shardIndex: 0,
            dataShardCount: 2,
            payload: shortHeader(lastPayloadLength: 1) + Data([0xA0])
        )
        let second = makePacket(
            sequence: 0,
            streamSequence: 0,
            frameIndex: UInt32.max,
            shardIndex: 1,
            dataShardCount: 2,
            payload: Data([0xA1])
        )
        let wrappedFrame = makePacket(
            sequence: 1,
            streamSequence: 1,
            frameIndex: 0,
            shardIndex: 0,
            dataShardCount: 1,
            payload: shortHeader(lastPayloadLength: 9) + Data([0xB0])
        )

        let events = assembler.ingest(first) + assembler.ingest(second) + assembler.ingest(wrappedFrame)
        XCTAssertEqual(events.compactMap(\.accessUnit).map(\.frameIndex), [UInt32.max, 0])
        XCTAssertTrue(events.compactMap(\.frameLoss).isEmpty)
    }

    func testAV1UsesFinalLengthWhileAnnexBCodecsPreservePadding() throws {
        let payload = shortHeader(lastPayloadLength: 11, frameType: .instantaneousDecoderRefresh)
            + Data([0x11, 0x22, 0x33, 0, 0, 0])
        let packet = makePacket(
            sequence: 70,
            frameIndex: 30,
            shardIndex: 0,
            dataShardCount: 1,
            payload: payload
        )

        var av1Assembler = try VideoAccessUnitAssembler(codec: .av1)
        let av1 = try XCTUnwrap(av1Assembler.ingest(packet).compactMap(\.accessUnit).only)
        XCTAssertEqual(av1.payload, Data([0x11, 0x22, 0x33]))

        var h264Assembler = try VideoAccessUnitAssembler(codec: .h264)
        let h264 = try XCTUnwrap(h264Assembler.ingest(packet).compactMap(\.accessUnit).only)
        XCTAssertEqual(h264.payload, Data([0x11, 0x22, 0x33, 0, 0, 0]))

        var badPacket = packet
        badPacket.payload[badPacket.payload.startIndex] = 0x81
        var badAssembler = try VideoAccessUnitAssembler(codec: .h264)
        XCTAssertEqual(
            badAssembler.ingest(badPacket).compactMap(\.frameLoss).only?.reason,
            .invalidFrameHeader
        )
    }

    func testTimeoutPacketByteAndFinishBoundsFailClosed() throws {
        let first = makePacket(
            sequence: 80,
            frameIndex: 40,
            shardIndex: 0,
            dataShardCount: 2,
            receiveTimeNanoseconds: 100,
            payload: shortHeader(lastPayloadLength: 1) + Data([0x01])
        )
        let second = makePacket(
            sequence: 81,
            frameIndex: 40,
            shardIndex: 1,
            dataShardCount: 2,
            receiveTimeNanoseconds: 101,
            payload: Data([0x02, 0x03, 0x04])
        )

        var timeout = try VideoAccessUnitAssembler(
            codec: .h264,
            limits: VideoAccessUnitAssemblyLimits(
                maximumPacketsPerFrame: 2,
                maximumAccessUnitBytes: 64,
                maximumAssemblyAgeNanoseconds: 10
            )
        )
        XCTAssertEqual(timeout.ingest(first), [])
        XCTAssertEqual(
            timeout.evictExpired(nowNanoseconds: 110).compactMap(\.frameLoss).only?.reason,
            .assemblyTimedOut
        )

        var packetBound = try VideoAccessUnitAssembler(
            codec: .h264,
            limits: VideoAccessUnitAssemblyLimits(
                maximumPacketsPerFrame: 1,
                maximumAccessUnitBytes: 64,
                maximumAssemblyAgeNanoseconds: 100
            )
        )
        XCTAssertEqual(packetBound.ingest(first), [])
        XCTAssertEqual(
            packetBound.ingest(second).compactMap(\.frameLoss).only?.reason,
            .packetCapacityExceeded
        )

        var byteBound = try VideoAccessUnitAssembler(
            codec: .h264,
            limits: VideoAccessUnitAssemblyLimits(
                maximumPacketsPerFrame: 2,
                maximumAccessUnitBytes: 11,
                maximumAssemblyAgeNanoseconds: 100
            )
        )
        XCTAssertEqual(byteBound.ingest(first), [])
        XCTAssertEqual(
            byteBound.ingest(second).compactMap(\.frameLoss).only?.reason,
            .accessUnitTooLarge
        )

        var finish = try VideoAccessUnitAssembler(codec: .h264)
        XCTAssertEqual(finish.ingest(first), [])
        XCTAssertEqual(
            finish.finish().compactMap(\.frameLoss).only?.reason,
            .incompleteAtEndOfStream
        )
        XCTAssertEqual(finish.finish(), [])
    }

    func testMetadataDriftAndInvalidAssemblyLimitsFailClosed() throws {
        XCTAssertThrowsError(try VideoAccessUnitAssembler(
            codec: .h264,
            limits: VideoAccessUnitAssemblyLimits(
                maximumPacketsPerFrame: 0,
                maximumAccessUnitBytes: 1,
                maximumAssemblyAgeNanoseconds: 0
            )
        )) { error in
            XCTAssertEqual(error as? VideoAccessUnitAssemblyError, .invalidLimits)
        }

        var assembler = try VideoAccessUnitAssembler(codec: .h264)
        let first = makePacket(
            sequence: 90,
            frameIndex: 50,
            shardIndex: 0,
            dataShardCount: 2,
            payload: shortHeader(lastPayloadLength: 1) + Data([0x01])
        )
        var drifted = makePacket(
            sequence: 91,
            frameIndex: 50,
            shardIndex: 1,
            dataShardCount: 2,
            payload: Data([0x02])
        )
        drifted.rtpTimestamp &+= 1
        XCTAssertEqual(assembler.ingest(first), [])
        XCTAssertEqual(
            assembler.ingest(drifted).compactMap(\.frameLoss).only?.reason,
            .inconsistentFrameMetadata
        )
    }

    private func loadFixture() throws -> VideoPacketAssemblyFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/video/packet-assembly.json")
        return try JSONDecoder().decode(
            VideoPacketAssemblyFixture.self,
            from: Data(contentsOf: url)
        )
    }

    private func packetLimits(maximumDatagramBytes: Int = 256) -> MoonlightVideoPacketLimits {
        MoonlightVideoPacketLimits(
            maximumDatagramBytes: maximumDatagramBytes,
            maximumDataShardsPerBlock: 16,
            maximumTotalShardsPerBlock: 32
        )
    }

    private func assertPacketError(
        _ expected: MoonlightVideoPacketError,
        operation: () throws -> Void
    ) {
        XCTAssertThrowsError(try operation()) { error in
            XCTAssertEqual(error as? MoonlightVideoPacketError, expected)
        }
    }
}

private struct VideoPacketAssemblyFixture: Decodable {
    struct Packet: Decodable {
        var datagramHex: String
        var name: String
    }

    struct Expected: Decodable {
        var frameIndex: UInt32
        var frameType: UInt8
        var hostProcessingLatencyTenthsOfMillisecond: UInt16
        var payloadHex: String
    }

    var codec: String
    var expected: Expected
    var packets: [Packet]
    var schemaVersion: Int
}

private extension VideoAccessUnitAssemblyEvent {
    var accessUnit: VideoAccessUnit? {
        guard case let .accessUnit(value) = self else { return nil }
        return value
    }

    var frameLoss: VideoFrameLoss? {
        guard case let .frameLost(value) = self else { return nil }
        return value
    }
}

private extension Collection {
    var only: Element? {
        count == 1 ? first : nil
    }
}

private extension Data {
    init(spacedVideoHex: String) throws {
        let fields = spacedVideoHex.split(whereSeparator: \Character.isWhitespace)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(fields.count)
        for field in fields {
            guard field.count == 2, let byte = UInt8(field, radix: 16) else {
                throw VideoFixtureError.invalidHex
            }
            bytes.append(byte)
        }
        self.init(bytes)
    }
}

private enum VideoFixtureError: Error {
    case invalidHex
}

private func shortHeader(
    lastPayloadLength: UInt16,
    frameType: SunshineVideoFrameType = .predicted,
    latency: UInt16 = 25
) -> Data {
    Data([
        0x01,
        UInt8(truncatingIfNeeded: latency),
        UInt8(truncatingIfNeeded: latency >> 8),
        frameType.rawValue,
        UInt8(truncatingIfNeeded: lastPayloadLength),
        UInt8(truncatingIfNeeded: lastPayloadLength >> 8),
        0,
        0
    ])
}

private func makePacket(
    sequence: UInt16,
    streamSequence: UInt32? = nil,
    frameIndex: UInt32,
    blockIndex: UInt8 = 0,
    lastBlockIndex: UInt8 = 0,
    shardIndex: Int,
    dataShardCount: Int,
    fecPercentage: Int = 0,
    receiveTimeNanoseconds: UInt64 = 100,
    payload: Data
) -> MoonlightVideoPacket {
    let parityShardCount = (dataShardCount * fecPercentage + 99) / 100
    let isParity = shardIndex >= dataShardCount
    var flags: MoonlightVideoPacketFlags = isParity ? [] : [.containsPictureData]
    if !isParity && shardIndex == 0 {
        flags.insert(.startOfFrame)
    }
    if !isParity && shardIndex == dataShardCount - 1 {
        flags.insert(.endOfFrame)
    }
    return MoonlightVideoPacket(
        rtpSequenceNumber: sequence,
        streamSequenceNumber: streamSequence ?? UInt32(sequence),
        frameIndex: frameIndex,
        rtpTimestamp: 90_000,
        ssrc: 0x1234_5678,
        flags: flags,
        extraFlags: 0,
        fecBlockIndex: blockIndex,
        lastFECBlockIndex: lastBlockIndex,
        fecShardIndex: shardIndex,
        dataShardCount: dataShardCount,
        parityShardCount: parityShardCount,
        fecPercentage: fecPercentage,
        receiveTimeNanoseconds: receiveTimeNanoseconds,
        payload: payload
    )
}

private func makeDatagram(
    rtpSequence: UInt16,
    streamSequence: UInt32,
    frameIndex: UInt32,
    blockIndex: UInt8 = 0,
    lastBlockIndex: UInt8 = 0,
    shardIndex: Int,
    dataShardCount: Int,
    fecPercentage: Int = 0,
    flags: MoonlightVideoPacketFlags,
    payload: Data
) -> Data {
    var bytes = [UInt8](repeating: 0, count: 32)
    bytes[0] = 0x90
    bytes[1] = 0x60
    bytes[2] = UInt8(truncatingIfNeeded: rtpSequence >> 8)
    bytes[3] = UInt8(truncatingIfNeeded: rtpSequence)
    writeBigEndian32(90_000, to: &bytes, at: 4)
    writeBigEndian32(0x1234_5678, to: &bytes, at: 8)
    writeLittleEndian32((streamSequence & 0x00FF_FFFF) << 8, to: &bytes, at: 16)
    writeLittleEndian32(frameIndex, to: &bytes, at: 20)
    bytes[24] = flags.rawValue
    bytes[26] = 0x10
    bytes[27] = (blockIndex << 4) | (lastBlockIndex << 6)
    let fecInfo = UInt32(shardIndex << 12)
        | UInt32(dataShardCount << 22)
        | UInt32(fecPercentage << 4)
    writeLittleEndian32(fecInfo, to: &bytes, at: 28)
    return Data(bytes) + payload
}

private func writeBigEndian32(_ value: UInt32, to bytes: inout [UInt8], at offset: Int) {
    bytes[offset] = UInt8(truncatingIfNeeded: value >> 24)
    bytes[offset + 1] = UInt8(truncatingIfNeeded: value >> 16)
    bytes[offset + 2] = UInt8(truncatingIfNeeded: value >> 8)
    bytes[offset + 3] = UInt8(truncatingIfNeeded: value)
}

private func writeLittleEndian32(_ value: UInt32, to bytes: inout [UInt8], at offset: Int) {
    bytes[offset] = UInt8(truncatingIfNeeded: value)
    bytes[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    bytes[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
    bytes[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
}

private func replaceLittleEndian32(in data: inout Data, at offset: Int, with value: UInt32) {
    data[data.startIndex + offset] = UInt8(truncatingIfNeeded: value)
    data[data.startIndex + offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
    data[data.startIndex + offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
    data[data.startIndex + offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
}
