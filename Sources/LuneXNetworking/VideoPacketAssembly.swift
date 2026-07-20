import Foundation

enum MoonlightVideoPacketError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidLimits
    case datagramTooSmall
    case datagramTooLarge
    case unsupportedRTPLayout
    case invalidFECEnvelope
    case invalidPacketFlags
    case invalidPacketSequence
    case emptyPayload

    var description: String {
        switch self {
        case .invalidLimits:
            return "Video packet limits are invalid."
        case .datagramTooSmall:
            return "Video datagram is shorter than its fixed protocol headers."
        case .datagramTooLarge:
            return "Video datagram exceeds the negotiated bound."
        case .unsupportedRTPLayout:
            return "Video datagram has an unsupported RTP header layout."
        case .invalidFECEnvelope:
            return "Video datagram has an invalid FEC block envelope."
        case .invalidPacketFlags:
            return "Video datagram has invalid frame-boundary flags."
        case .invalidPacketSequence:
            return "Video datagram has inconsistent RTP and stream packet sequences."
        case .emptyPayload:
            return "Video data packet has no codec payload."
        }
    }
}

struct MoonlightVideoPacketLimits: Equatable, Sendable {
    static let fixedHeaderBytes = 32

    var maximumDatagramBytes: Int
    var maximumDataShardsPerBlock: Int
    var maximumTotalShardsPerBlock: Int

    static func negotiated(maximumPacketSize: Int) -> MoonlightVideoPacketLimits {
        MoonlightVideoPacketLimits(
            maximumDatagramBytes: maximumPacketSize + 16,
            maximumDataShardsPerBlock: 1_023,
            maximumTotalShardsPerBlock: 1_023
        )
    }

    func validate() throws {
        guard maximumDatagramBytes > Self.fixedHeaderBytes,
              (1...1_023).contains(maximumDataShardsPerBlock),
              maximumTotalShardsPerBlock >= maximumDataShardsPerBlock,
              maximumTotalShardsPerBlock <= 1_023 else {
            throw MoonlightVideoPacketError.invalidLimits
        }
    }
}

struct MoonlightVideoPacketFlags: OptionSet, Equatable, Hashable, Sendable {
    let rawValue: UInt8

    static let containsPictureData = MoonlightVideoPacketFlags(rawValue: 0x01)
    static let endOfFrame = MoonlightVideoPacketFlags(rawValue: 0x02)
    static let startOfFrame = MoonlightVideoPacketFlags(rawValue: 0x04)
    static let known: MoonlightVideoPacketFlags = [.containsPictureData, .endOfFrame, .startOfFrame]
}

struct MoonlightVideoPacket: Equatable, Sendable {
    var rtpSequenceNumber: UInt16
    var streamSequenceNumber: UInt32
    var frameIndex: UInt32
    var rtpTimestamp: UInt32
    var ssrc: UInt32
    var flags: MoonlightVideoPacketFlags
    var extraFlags: UInt8
    var fecBlockIndex: UInt8
    var lastFECBlockIndex: UInt8
    var fecShardIndex: Int
    var dataShardCount: Int
    var parityShardCount: Int
    var fecPercentage: Int
    var receiveTimeNanoseconds: UInt64
    var payload: Data

    var isParity: Bool {
        fecShardIndex >= dataShardCount
    }

    var isTrueFrameStart: Bool {
        !isParity && fecBlockIndex == 0 && fecShardIndex == 0 && flags.contains(.startOfFrame)
    }

    var isTrueFrameEnd: Bool {
        !isParity
            && fecBlockIndex == lastFECBlockIndex
            && fecShardIndex == dataShardCount - 1
            && flags.contains(.endOfFrame)
    }

    fileprivate func hasSameWireContent(as other: MoonlightVideoPacket) -> Bool {
        var lhs = self
        var rhs = other
        lhs.receiveTimeNanoseconds = 0
        rhs.receiveTimeNanoseconds = 0
        return lhs == rhs
    }
}

enum MoonlightVideoPacketParser {
    static func parse(
        _ datagram: Data,
        receiveTimeNanoseconds: UInt64,
        limits: MoonlightVideoPacketLimits
    ) throws -> MoonlightVideoPacket {
        try limits.validate()
        guard datagram.count >= MoonlightVideoPacketLimits.fixedHeaderBytes else {
            throw MoonlightVideoPacketError.datagramTooSmall
        }
        guard datagram.count <= limits.maximumDatagramBytes else {
            throw MoonlightVideoPacketError.datagramTooLarge
        }

        let first = byte(datagram, at: 0)
        let rtpVersion = first >> 6
        let hasPadding = first & 0x20 != 0
        let hasExtension = first & 0x10 != 0
        let csrcCount = first & 0x0F
        guard rtpVersion == 2, !hasPadding, hasExtension, csrcCount == 0 else {
            throw MoonlightVideoPacketError.unsupportedRTPLayout
        }

        let rtpSequence = readBigEndian16(datagram, at: 2)
        let rtpTimestamp = readBigEndian32(datagram, at: 4)
        let ssrc = readBigEndian32(datagram, at: 8)
        let rawStreamPacketIndex = readLittleEndian32(datagram, at: 16)
        let streamSequence = (rawStreamPacketIndex >> 8) & 0x00FF_FFFF
        let frameIndex = readLittleEndian32(datagram, at: 20)
        let flags = MoonlightVideoPacketFlags(rawValue: byte(datagram, at: 24))
        let extraFlags = byte(datagram, at: 25)
        let multiFECFlags = byte(datagram, at: 26)
        let multiFECBlocks = byte(datagram, at: 27)
        let fecInfo = readLittleEndian32(datagram, at: 28)

        let fecShardIndex = Int((fecInfo >> 12) & 0x03FF)
        let dataShardCount = Int((fecInfo >> 22) & 0x03FF)
        let fecPercentage = Int((fecInfo >> 4) & 0x00FF)
        let parityShardCount = (dataShardCount * fecPercentage + 99) / 100
        let totalShardCount = dataShardCount + parityShardCount
        let blockIndex = (multiFECBlocks >> 4) & 0x03
        let lastBlockIndex = (multiFECBlocks >> 6) & 0x03

        guard multiFECFlags == 0x10,
              blockIndex <= lastBlockIndex,
              dataShardCount > 0,
              dataShardCount <= limits.maximumDataShardsPerBlock,
              fecPercentage <= 255,
              totalShardCount <= limits.maximumTotalShardsPerBlock,
              fecShardIndex < totalShardCount else {
            throw MoonlightVideoPacketError.invalidFECEnvelope
        }

        let isParity = fecShardIndex >= dataShardCount
        if !isParity {
            guard flags.subtracting(.known).isEmpty,
                  flags.contains(.containsPictureData),
                  flags.contains(.startOfFrame) == (fecShardIndex == 0),
                  flags.contains(.endOfFrame) == (fecShardIndex == dataShardCount - 1) else {
                throw MoonlightVideoPacketError.invalidPacketFlags
            }
            guard UInt16(truncatingIfNeeded: streamSequence) == rtpSequence else {
                throw MoonlightVideoPacketError.invalidPacketSequence
            }
        }

        let payloadStart = datagram.index(
            datagram.startIndex,
            offsetBy: MoonlightVideoPacketLimits.fixedHeaderBytes
        )
        let payload = Data(datagram[payloadStart...])
        if !isParity && payload.isEmpty {
            throw MoonlightVideoPacketError.emptyPayload
        }

        return MoonlightVideoPacket(
            rtpSequenceNumber: rtpSequence,
            streamSequenceNumber: streamSequence,
            frameIndex: frameIndex,
            rtpTimestamp: rtpTimestamp,
            ssrc: ssrc,
            flags: flags,
            extraFlags: extraFlags,
            fecBlockIndex: blockIndex,
            lastFECBlockIndex: lastBlockIndex,
            fecShardIndex: fecShardIndex,
            dataShardCount: dataShardCount,
            parityShardCount: parityShardCount,
            fecPercentage: fecPercentage,
            receiveTimeNanoseconds: receiveTimeNanoseconds,
            payload: payload
        )
    }

    private static func byte(_ data: Data, at offset: Int) -> UInt8 {
        data[data.index(data.startIndex, offsetBy: offset)]
    }

    private static func readBigEndian16(_ data: Data, at offset: Int) -> UInt16 {
        (UInt16(byte(data, at: offset)) << 8) | UInt16(byte(data, at: offset + 1))
    }

    private static func readBigEndian32(_ data: Data, at offset: Int) -> UInt32 {
        (UInt32(byte(data, at: offset)) << 24)
            | (UInt32(byte(data, at: offset + 1)) << 16)
            | (UInt32(byte(data, at: offset + 2)) << 8)
            | UInt32(byte(data, at: offset + 3))
    }

    private static func readLittleEndian32(_ data: Data, at offset: Int) -> UInt32 {
        UInt32(byte(data, at: offset))
            | (UInt32(byte(data, at: offset + 1)) << 8)
            | (UInt32(byte(data, at: offset + 2)) << 16)
            | (UInt32(byte(data, at: offset + 3)) << 24)
    }
}

enum WrappingSequenceComparison {
    static func isBefore16(_ lhs: UInt16, _ rhs: UInt16) -> Bool {
        lhs != rhs && lhs &- rhs > UInt16.max / 2
    }

    static func isBefore24(_ lhs: UInt32, _ rhs: UInt32) -> Bool {
        let mask: UInt32 = 0x00FF_FFFF
        let difference = (lhs &- rhs) & mask
        return lhs != rhs && difference > mask / 2
    }

    static func isBefore32(_ lhs: UInt32, _ rhs: UInt32) -> Bool {
        lhs != rhs && lhs &- rhs > UInt32.max / 2
    }
}

enum SunshineVideoFrameType: UInt8, Codable, Equatable, Sendable {
    case predicted = 1
    case instantaneousDecoderRefresh = 2
    case intraRefresh = 4
    case referenceInvalidated = 5
}

struct SunshineShortFrameHeader: Equatable, Sendable {
    static let byteCount = 8

    var hostProcessingLatencyTenthsOfMillisecond: UInt16
    var frameType: SunshineVideoFrameType
    var lastPayloadLength: Int

    static func parse(_ payload: Data) throws -> SunshineShortFrameHeader {
        guard payload.count >= byteCount else {
            throw VideoAccessUnitAssemblyError.invalidFrameHeader
        }
        func byte(_ offset: Int) -> UInt8 {
            payload[payload.index(payload.startIndex, offsetBy: offset)]
        }
        guard byte(0) == 0x01,
              let frameType = SunshineVideoFrameType(rawValue: byte(3)) else {
            throw VideoAccessUnitAssemblyError.invalidFrameHeader
        }
        let latency = UInt16(byte(1)) | (UInt16(byte(2)) << 8)
        let lastPayloadLength = Int(UInt16(byte(4)) | (UInt16(byte(5)) << 8))
        guard lastPayloadLength > 0 else {
            throw VideoAccessUnitAssemblyError.invalidFrameHeader
        }
        return SunshineShortFrameHeader(
            hostProcessingLatencyTenthsOfMillisecond: latency,
            frameType: frameType,
            lastPayloadLength: lastPayloadLength
        )
    }
}

struct VideoAccessUnit: Equatable, Sendable {
    var frameIndex: UInt32
    var rtpTimestamp: UInt32
    var codec: NegotiatedVideoCodec
    var frameType: SunshineVideoFrameType
    var hostProcessingLatencyTenthsOfMillisecond: UInt16
    var firstReceiveTimeNanoseconds: UInt64
    var lastReceiveTimeNanoseconds: UInt64
    var packetCount: Int
    var payload: Data
}

enum VideoFrameLossReason: String, Codable, Equatable, Sendable {
    case superseded
    case assemblyTimedOut
    case packetCapacityExceeded
    case accessUnitTooLarge
    case inconsistentFrameMetadata
    case conflictingDuplicate
    case invalidFrameHeader
    case incompleteAtEndOfStream
}

struct VideoFrameLoss: Equatable, Sendable {
    var firstFrameIndex: UInt32
    var lastFrameIndex: UInt32
    var reason: VideoFrameLossReason
    var requiresIDR: Bool
}

enum VideoPacketDiscardReason: String, Codable, Equatable, Sendable {
    case duplicate
    case parity
    case lateFrame
}

enum VideoAccessUnitAssemblyEvent: Equatable, Sendable {
    case accessUnit(VideoAccessUnit)
    case frameLost(VideoFrameLoss)
    case packetDiscarded(VideoPacketDiscardReason)
}

enum VideoAccessUnitAssemblyError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidLimits
    case invalidFrameHeader

    var description: String {
        switch self {
        case .invalidLimits:
            return "Video access-unit assembly limits are invalid."
        case .invalidFrameHeader:
            return "Video access unit has an invalid Sunshine short frame header."
        }
    }
}

struct VideoAccessUnitAssemblyLimits: Equatable, Sendable {
    var maximumPacketsPerFrame: Int
    var maximumAccessUnitBytes: Int
    var maximumAssemblyAgeNanoseconds: UInt64

    static let realtime = VideoAccessUnitAssemblyLimits(
        maximumPacketsPerFrame: 4_092,
        maximumAccessUnitBytes: 32 * 1_024 * 1_024,
        maximumAssemblyAgeNanoseconds: 250_000_000
    )

    func validate() throws {
        guard maximumPacketsPerFrame > 0,
              maximumPacketsPerFrame <= 4_092,
              maximumAccessUnitBytes > SunshineShortFrameHeader.byteCount,
              maximumAssemblyAgeNanoseconds > 0 else {
            throw VideoAccessUnitAssemblyError.invalidLimits
        }
    }
}

struct VideoAccessUnitAssembler: Sendable {
    private struct BlockAssembly: Sendable {
        var dataShardCount: Int
        var fecPercentage: Int
        var lastBlockIndex: UInt8
        var rtpBaseSequence: UInt16
        var streamBaseSequence: UInt32
        var packets: [Int: MoonlightVideoPacket]
    }

    private struct FrameAssembly: Sendable {
        var frameIndex: UInt32
        var rtpTimestamp: UInt32
        var ssrc: UInt32
        var lastBlockIndex: UInt8
        var firstReceiveTimeNanoseconds: UInt64
        var lastReceiveTimeNanoseconds: UInt64
        var packetCount: Int
        var payloadBytes: Int
        var blocks: [UInt8: BlockAssembly]
    }

    let codec: NegotiatedVideoCodec
    let limits: VideoAccessUnitAssemblyLimits
    private var currentFrame: FrameAssembly?
    private var expectedFrameIndex: UInt32?

    init(
        codec: NegotiatedVideoCodec,
        limits: VideoAccessUnitAssemblyLimits = .realtime
    ) throws {
        try limits.validate()
        self.codec = codec
        self.limits = limits
    }

    mutating func ingest(_ packet: MoonlightVideoPacket) -> [VideoAccessUnitAssemblyEvent] {
        var events = evictExpired(nowNanoseconds: packet.receiveTimeNanoseconds)

        if packet.isParity {
            events.append(.packetDiscarded(.parity))
            return events
        }

        if let currentFrame, packet.frameIndex != currentFrame.frameIndex {
            if WrappingSequenceComparison.isBefore32(packet.frameIndex, currentFrame.frameIndex) {
                events.append(.packetDiscarded(.lateFrame))
                return events
            }
            if WrappingSequenceComparison.isBefore32(currentFrame.frameIndex, packet.frameIndex) {
                events.append(.frameLost(loss(
                    first: currentFrame.frameIndex,
                    last: packet.frameIndex &- 1,
                    reason: .superseded
                )))
                self.currentFrame = nil
                expectedFrameIndex = packet.frameIndex
            } else {
                events.append(.frameLost(loss(
                    first: currentFrame.frameIndex,
                    last: currentFrame.frameIndex,
                    reason: .inconsistentFrameMetadata
                )))
                self.currentFrame = nil
                expectedFrameIndex = packet.frameIndex
            }
        } else if currentFrame == nil,
                  let expectedFrameIndex,
                  packet.frameIndex != expectedFrameIndex {
            if WrappingSequenceComparison.isBefore32(packet.frameIndex, expectedFrameIndex) {
                events.append(.packetDiscarded(.lateFrame))
                return events
            }
            if WrappingSequenceComparison.isBefore32(expectedFrameIndex, packet.frameIndex) {
                events.append(.frameLost(loss(
                    first: expectedFrameIndex,
                    last: packet.frameIndex &- 1,
                    reason: .superseded
                )))
                self.expectedFrameIndex = packet.frameIndex
            }
        }

        if currentFrame == nil {
            currentFrame = FrameAssembly(
                frameIndex: packet.frameIndex,
                rtpTimestamp: packet.rtpTimestamp,
                ssrc: packet.ssrc,
                lastBlockIndex: packet.lastFECBlockIndex,
                firstReceiveTimeNanoseconds: packet.receiveTimeNanoseconds,
                lastReceiveTimeNanoseconds: packet.receiveTimeNanoseconds,
                packetCount: 0,
                payloadBytes: 0,
                blocks: [:]
            )
        }

        guard var frame = currentFrame else {
            return events
        }
        guard frame.rtpTimestamp == packet.rtpTimestamp,
              frame.ssrc == packet.ssrc,
              frame.lastBlockIndex == packet.lastFECBlockIndex else {
            events.append(.frameLost(loss(
                first: frame.frameIndex,
                last: frame.frameIndex,
                reason: .inconsistentFrameMetadata
            )))
            currentFrame = nil
            expectedFrameIndex = frame.frameIndex &+ 1
            return events
        }

        let rtpBase = packet.rtpSequenceNumber &- UInt16(truncatingIfNeeded: packet.fecShardIndex)
        let streamBase = (packet.streamSequenceNumber &- UInt32(packet.fecShardIndex)) & 0x00FF_FFFF
        var block = frame.blocks[packet.fecBlockIndex] ?? BlockAssembly(
            dataShardCount: packet.dataShardCount,
            fecPercentage: packet.fecPercentage,
            lastBlockIndex: packet.lastFECBlockIndex,
            rtpBaseSequence: rtpBase,
            streamBaseSequence: streamBase,
            packets: [:]
        )
        guard block.dataShardCount == packet.dataShardCount,
              block.fecPercentage == packet.fecPercentage,
              block.lastBlockIndex == packet.lastFECBlockIndex,
              block.rtpBaseSequence == rtpBase,
              block.streamBaseSequence == streamBase else {
            events.append(.frameLost(loss(
                first: frame.frameIndex,
                last: frame.frameIndex,
                reason: .inconsistentFrameMetadata
            )))
            currentFrame = nil
            expectedFrameIndex = frame.frameIndex &+ 1
            return events
        }

        if let existing = block.packets[packet.fecShardIndex] {
            if existing.hasSameWireContent(as: packet) {
                events.append(.packetDiscarded(.duplicate))
            } else {
                events.append(.frameLost(loss(
                    first: frame.frameIndex,
                    last: frame.frameIndex,
                    reason: .conflictingDuplicate
                )))
                currentFrame = nil
                expectedFrameIndex = frame.frameIndex &+ 1
            }
            return events
        }

        guard frame.packetCount < limits.maximumPacketsPerFrame else {
            events.append(.frameLost(loss(
                first: frame.frameIndex,
                last: frame.frameIndex,
                reason: .packetCapacityExceeded
            )))
            currentFrame = nil
            expectedFrameIndex = frame.frameIndex &+ 1
            return events
        }
        guard packet.payload.count <= limits.maximumAccessUnitBytes,
              frame.payloadBytes <= limits.maximumAccessUnitBytes - packet.payload.count else {
            events.append(.frameLost(loss(
                first: frame.frameIndex,
                last: frame.frameIndex,
                reason: .accessUnitTooLarge
            )))
            currentFrame = nil
            expectedFrameIndex = frame.frameIndex &+ 1
            return events
        }

        block.packets[packet.fecShardIndex] = packet
        frame.blocks[packet.fecBlockIndex] = block
        frame.packetCount += 1
        frame.payloadBytes += packet.payload.count
        frame.firstReceiveTimeNanoseconds = min(
            frame.firstReceiveTimeNanoseconds,
            packet.receiveTimeNanoseconds
        )
        frame.lastReceiveTimeNanoseconds = max(
            frame.lastReceiveTimeNanoseconds,
            packet.receiveTimeNanoseconds
        )
        currentFrame = frame

        guard isComplete(frame) else {
            return events
        }

        do {
            let accessUnit = try assemble(frame)
            events.append(.accessUnit(accessUnit))
        } catch {
            events.append(.frameLost(loss(
                first: frame.frameIndex,
                last: frame.frameIndex,
                reason: .invalidFrameHeader
            )))
        }
        currentFrame = nil
        expectedFrameIndex = frame.frameIndex &+ 1
        return events
    }

    mutating func evictExpired(nowNanoseconds: UInt64) -> [VideoAccessUnitAssemblyEvent] {
        guard let frame = currentFrame,
              nowNanoseconds >= frame.firstReceiveTimeNanoseconds,
              nowNanoseconds - frame.firstReceiveTimeNanoseconds >= limits.maximumAssemblyAgeNanoseconds else {
            return []
        }
        currentFrame = nil
        expectedFrameIndex = frame.frameIndex &+ 1
        return [.frameLost(loss(
            first: frame.frameIndex,
            last: frame.frameIndex,
            reason: .assemblyTimedOut
        ))]
    }

    mutating func finish() -> [VideoAccessUnitAssemblyEvent] {
        guard let frame = currentFrame else {
            return []
        }
        currentFrame = nil
        expectedFrameIndex = frame.frameIndex &+ 1
        return [.frameLost(loss(
            first: frame.frameIndex,
            last: frame.frameIndex,
            reason: .incompleteAtEndOfStream
        ))]
    }

    mutating func reset() {
        currentFrame = nil
        expectedFrameIndex = nil
    }

    private func isComplete(_ frame: FrameAssembly) -> Bool {
        for blockIndex in UInt8(0)...frame.lastBlockIndex {
            guard let block = frame.blocks[blockIndex],
                  block.packets.count == block.dataShardCount else {
                return false
            }
        }
        return true
    }

    private func assemble(_ frame: FrameAssembly) throws -> VideoAccessUnit {
        guard let firstBlock = frame.blocks[0],
              let firstPacket = firstBlock.packets[0],
              firstPacket.isTrueFrameStart,
              let lastBlock = frame.blocks[frame.lastBlockIndex],
              let lastPacket = lastBlock.packets[lastBlock.dataShardCount - 1],
              lastPacket.isTrueFrameEnd else {
            throw VideoAccessUnitAssemblyError.invalidFrameHeader
        }
        let header = try SunshineShortFrameHeader.parse(firstPacket.payload)
        var payload = Data()
        payload.reserveCapacity(max(0, frame.payloadBytes - SunshineShortFrameHeader.byteCount))

        for blockIndex in UInt8(0)...frame.lastBlockIndex {
            guard let block = frame.blocks[blockIndex] else {
                throw VideoAccessUnitAssemblyError.invalidFrameHeader
            }
            for shardIndex in 0..<block.dataShardCount {
                guard let packet = block.packets[shardIndex] else {
                    throw VideoAccessUnitAssemblyError.invalidFrameHeader
                }
                var fragment = packet.payload
                if packet.isTrueFrameEnd && codec == .av1 {
                    guard header.lastPayloadLength <= fragment.count else {
                        throw VideoAccessUnitAssemblyError.invalidFrameHeader
                    }
                    fragment = Data(fragment.prefix(header.lastPayloadLength))
                }
                if packet.isTrueFrameStart {
                    guard fragment.count >= SunshineShortFrameHeader.byteCount else {
                        throw VideoAccessUnitAssemblyError.invalidFrameHeader
                    }
                    fragment.removeFirst(SunshineShortFrameHeader.byteCount)
                }
                payload.append(fragment)
            }
        }
        guard !payload.isEmpty, payload.count <= limits.maximumAccessUnitBytes else {
            throw VideoAccessUnitAssemblyError.invalidFrameHeader
        }

        return VideoAccessUnit(
            frameIndex: frame.frameIndex,
            rtpTimestamp: frame.rtpTimestamp,
            codec: codec,
            frameType: header.frameType,
            hostProcessingLatencyTenthsOfMillisecond: header.hostProcessingLatencyTenthsOfMillisecond,
            firstReceiveTimeNanoseconds: frame.firstReceiveTimeNanoseconds,
            lastReceiveTimeNanoseconds: frame.lastReceiveTimeNanoseconds,
            packetCount: frame.packetCount,
            payload: payload
        )
    }

    private func loss(
        first: UInt32,
        last: UInt32,
        reason: VideoFrameLossReason
    ) -> VideoFrameLoss {
        VideoFrameLoss(
            firstFrameIndex: first,
            lastFrameIndex: last,
            reason: reason,
            requiresIDR: true
        )
    }
}
