import Foundation

enum AudioJitterBufferError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidPolicy
    case invalidPacketPayload
    case nonMonotonicClock
    case sequenceGapTooLarge(expected: UInt16, received: UInt16)
    case finished

    var description: String {
        switch self {
        case .invalidPolicy:
            return "Audio jitter-buffer limits are invalid."
        case .invalidPacketPayload:
            return "Audio packet payload is empty or exceeds the negotiated bound."
        case .nonMonotonicClock:
            return "Audio jitter-buffer time moved backwards."
        case let .sequenceGapTooLarge(expected, received):
            return "Audio sequence gap from \(expected) to \(received) exceeds the recovery bound."
        case .finished:
            return "The audio jitter buffer has already finished."
        }
    }
}

struct AudioJitterBufferPolicy: Equatable, Sendable {
    var targetDelayNanoseconds: UInt64
    var maximumJitterNanoseconds: UInt64
    var maximumReorderDistance: UInt16
    var maximumForwardGap: UInt16
    var maximumBufferedPackets: Int
    var maximumBufferedBytes: Int
    var maximumPacketBytes: Int

    static func realtime(
        configuration: NegotiatedAudioStreamConfiguration
    ) throws -> AudioJitterBufferPolicy {
        try configuration.validate()
        guard let samplesPerFrame = UInt64(exactly: configuration.samplesPerFrame) else {
            throw AudioJitterBufferError.invalidPolicy
        }
        let durationNumerator = samplesPerFrame.multipliedReportingOverflow(by: 1_000_000_000)
        guard !durationNumerator.overflow else {
            throw AudioJitterBufferError.invalidPolicy
        }
        let packetDurationNanoseconds = durationNumerator.partialValue
            / UInt64(configuration.sampleRate)
        let targetDelay = packetDurationNanoseconds.multipliedReportingOverflow(by: 2)
        let maximumJitter = packetDurationNanoseconds.multipliedReportingOverflow(by: 8)
        guard packetDurationNanoseconds > 0,
              !targetDelay.overflow,
              !maximumJitter.overflow else {
            throw AudioJitterBufferError.invalidPolicy
        }
        let policy = AudioJitterBufferPolicy(
            targetDelayNanoseconds: targetDelay.partialValue,
            maximumJitterNanoseconds: maximumJitter.partialValue,
            maximumReorderDistance: 8,
            maximumForwardGap: 1_024,
            maximumBufferedPackets: 32,
            maximumBufferedBytes: configuration.maximumPacketSize * 32,
            maximumPacketBytes: configuration.maximumPacketSize
        )
        try policy.validate()
        return policy
    }

    func validate() throws {
        guard targetDelayNanoseconds > 0,
              maximumJitterNanoseconds >= targetDelayNanoseconds,
              maximumReorderDistance > 0,
              maximumReorderDistance < UInt16.max / 2,
              maximumForwardGap >= maximumReorderDistance,
              maximumForwardGap < UInt16.max / 2,
              maximumBufferedPackets > 0,
              maximumBufferedPackets <= 256,
              maximumPacketBytes > 0,
              maximumPacketBytes <= 1_400,
              maximumBufferedBytes >= maximumPacketBytes,
              maximumBufferedBytes <= maximumPacketBytes * maximumBufferedPackets else {
            throw AudioJitterBufferError.invalidPolicy
        }
    }
}

enum AudioPacketLossReason: String, Codable, Equatable, Sendable {
    case jitterDeadlineExceeded
    case reorderWindowExceeded
    case bufferCapacityExceeded
    case endOfStream
}

struct AudioPacketLossRange: Equatable, Sendable {
    var firstSequenceNumber: UInt16
    var lastSequenceNumber: UInt16
    var packetCount: Int
    var reason: AudioPacketLossReason
}

enum AudioPacketDiscardReason: String, Codable, Equatable, Sendable {
    case duplicate
    case conflictingDuplicate
    case late
}

enum AudioJitterBufferEvent: Equatable, Sendable {
    case packetReady(ReceivedAudioPacket)
    case packetsLost(AudioPacketLossRange)
    case packetDiscarded(sequenceNumber: UInt16, reason: AudioPacketDiscardReason)
}

struct AudioJitterBufferSnapshot: Equatable, Sendable {
    var nextSequenceNumber: UInt16?
    var isPlaybackStarted: Bool
    var isFinished: Bool
    var bufferedPacketCount: Int
    var bufferedPayloadBytes: Int
    var deliveredPacketCount: UInt64
    var lostPacketCount: UInt64
    var duplicatePacketCount: UInt64
    var conflictingDuplicatePacketCount: UInt64
    var latePacketCount: UInt64
    var capacityRecoveryCount: UInt64
}

struct AudioPacketJitterBuffer: Sendable {
    let policy: AudioJitterBufferPolicy

    private var packets: [UInt16: ReceivedAudioPacket] = [:]
    private var nextSequenceNumber: UInt16?
    private var lastClockNanoseconds: UInt64?
    private var bufferedPayloadBytes = 0
    private var isPlaybackStarted = false
    private var isFinished = false
    private var deliveredPacketCount: UInt64 = 0
    private var lostPacketCount: UInt64 = 0
    private var duplicatePacketCount: UInt64 = 0
    private var conflictingDuplicatePacketCount: UInt64 = 0
    private var latePacketCount: UInt64 = 0
    private var capacityRecoveryCount: UInt64 = 0

    init(policy: AudioJitterBufferPolicy) throws {
        try policy.validate()
        self.policy = policy
    }

    mutating func ingest(_ packet: ReceivedAudioPacket) throws -> [AudioJitterBufferEvent] {
        guard !isFinished else { throw AudioJitterBufferError.finished }
        guard !packet.payload.isEmpty,
              packet.payload.count <= policy.maximumPacketBytes else {
            throw AudioJitterBufferError.invalidPacketPayload
        }
        try validateClock(packet.receiveTimeNanoseconds)

        if let existing = packets[packet.sequenceNumber] {
            lastClockNanoseconds = packet.receiveTimeNanoseconds
            if existing.hasSameAudioWireContent(as: packet) {
                duplicatePacketCount &+= 1
                return discardAndDrain(.packetDiscarded(
                    sequenceNumber: packet.sequenceNumber,
                    reason: .duplicate
                ), nowNanoseconds: packet.receiveTimeNanoseconds)
            }
            conflictingDuplicatePacketCount &+= 1
            return discardAndDrain(.packetDiscarded(
                sequenceNumber: packet.sequenceNumber,
                reason: .conflictingDuplicate
            ), nowNanoseconds: packet.receiveTimeNanoseconds)
        }

        if let expected = nextSequenceNumber {
            if WrappingSequenceComparison.isBefore16(packet.sequenceNumber, expected) {
                let backwardDistance = expected &- packet.sequenceNumber
                if !isPlaybackStarted, backwardDistance <= policy.maximumReorderDistance {
                    nextSequenceNumber = packet.sequenceNumber
                } else {
                    lastClockNanoseconds = packet.receiveTimeNanoseconds
                    latePacketCount &+= 1
                    return discardAndDrain(.packetDiscarded(
                        sequenceNumber: packet.sequenceNumber,
                        reason: .late
                    ), nowNanoseconds: packet.receiveTimeNanoseconds)
                }
            } else {
                let forwardDistance = packet.sequenceNumber &- expected
                guard forwardDistance <= policy.maximumForwardGap else {
                    throw AudioJitterBufferError.sequenceGapTooLarge(
                        expected: expected,
                        received: packet.sequenceNumber
                    )
                }
            }
        } else {
            nextSequenceNumber = packet.sequenceNumber
        }

        lastClockNanoseconds = packet.receiveTimeNanoseconds
        packets[packet.sequenceNumber] = packet
        bufferedPayloadBytes += packet.payload.count
        let capacityPressure = packets.count > policy.maximumBufferedPackets
            || bufferedPayloadBytes > policy.maximumBufferedBytes
        return drain(
            nowNanoseconds: packet.receiveTimeNanoseconds,
            capacityPressure: capacityPressure,
            finishing: false
        )
    }

    mutating func advanceTime(to nowNanoseconds: UInt64) throws -> [AudioJitterBufferEvent] {
        guard !isFinished else { throw AudioJitterBufferError.finished }
        try observeClock(nowNanoseconds)
        return drain(
            nowNanoseconds: nowNanoseconds,
            capacityPressure: false,
            finishing: false
        )
    }

    mutating func finish(at nowNanoseconds: UInt64) throws -> [AudioJitterBufferEvent] {
        guard !isFinished else { return [] }
        try observeClock(nowNanoseconds)
        isFinished = true
        return drain(
            nowNanoseconds: nowNanoseconds,
            capacityPressure: false,
            finishing: true
        )
    }

    func snapshot() -> AudioJitterBufferSnapshot {
        AudioJitterBufferSnapshot(
            nextSequenceNumber: nextSequenceNumber,
            isPlaybackStarted: isPlaybackStarted,
            isFinished: isFinished,
            bufferedPacketCount: packets.count,
            bufferedPayloadBytes: bufferedPayloadBytes,
            deliveredPacketCount: deliveredPacketCount,
            lostPacketCount: lostPacketCount,
            duplicatePacketCount: duplicatePacketCount,
            conflictingDuplicatePacketCount: conflictingDuplicatePacketCount,
            latePacketCount: latePacketCount,
            capacityRecoveryCount: capacityRecoveryCount
        )
    }

    private mutating func observeClock(_ nowNanoseconds: UInt64) throws {
        try validateClock(nowNanoseconds)
        lastClockNanoseconds = nowNanoseconds
    }

    private func validateClock(_ nowNanoseconds: UInt64) throws {
        if let lastClockNanoseconds, nowNanoseconds < lastClockNanoseconds {
            throw AudioJitterBufferError.nonMonotonicClock
        }
    }

    private mutating func discardAndDrain(
        _ discard: AudioJitterBufferEvent,
        nowNanoseconds: UInt64
    ) -> [AudioJitterBufferEvent] {
        [discard] + drain(
            nowNanoseconds: nowNanoseconds,
            capacityPressure: false,
            finishing: false
        )
    }

    private mutating func drain(
        nowNanoseconds: UInt64,
        capacityPressure: Bool,
        finishing: Bool
    ) -> [AudioJitterBufferEvent] {
        guard !packets.isEmpty, nextSequenceNumber != nil else { return [] }
        if !isPlaybackStarted {
            let oldestArrival = packets.values.map(\.receiveTimeNanoseconds).min() ?? nowNanoseconds
            let targetReached = nowNanoseconds &- oldestArrival >= policy.targetDelayNanoseconds
            guard targetReached || capacityPressure || finishing else { return [] }
            isPlaybackStarted = true
        }

        var events: [AudioJitterBufferEvent] = []
        var isUnderCapacityPressure = capacityPressure
        while let expected = nextSequenceNumber {
            if let packet = packets.removeValue(forKey: expected) {
                bufferedPayloadBytes -= packet.payload.count
                deliveredPacketCount &+= 1
                events.append(.packetReady(packet))
                nextSequenceNumber = expected &+ 1
                continue
            }
            guard !packets.isEmpty,
                  let nearest = nearestFutureSequence(after: expected) else { break }
            let distance = Int(nearest &- expected)
            let oldestFutureArrival = packets.values
                .map(\.receiveTimeNanoseconds)
                .min() ?? nowNanoseconds
            let waitedNanoseconds = nowNanoseconds &- oldestFutureArrival
            let reason: AudioPacketLossReason
            if finishing {
                reason = .endOfStream
            } else if isUnderCapacityPressure {
                reason = .bufferCapacityExceeded
                capacityRecoveryCount &+= 1
            } else if distance > Int(policy.maximumReorderDistance) {
                reason = .reorderWindowExceeded
            } else if waitedNanoseconds >= policy.maximumJitterNanoseconds {
                reason = .jitterDeadlineExceeded
            } else {
                break
            }
            lostPacketCount &+= UInt64(distance)
            events.append(.packetsLost(AudioPacketLossRange(
                firstSequenceNumber: expected,
                lastSequenceNumber: nearest &- 1,
                packetCount: distance,
                reason: reason
            )))
            nextSequenceNumber = nearest
            isUnderCapacityPressure = false
        }
        return events
    }

    private func nearestFutureSequence(after expected: UInt16) -> UInt16? {
        packets.keys.min { lhs, rhs in
            lhs &- expected < rhs &- expected
        }
    }
}

private extension ReceivedAudioPacket {
    func hasSameAudioWireContent(as other: ReceivedAudioPacket) -> Bool {
        sequenceNumber == other.sequenceNumber
            && timestamp == other.timestamp
            && payload == other.payload
    }
}
