import Foundation
import XCTest

final class AudioPacketJitterBufferTests: XCTestCase {
    func testOutOfOrderPacketsBecomeReadyInSequenceAfterTargetDelay() throws {
        var buffer = try makeBuffer()

        XCTAssertEqual(try buffer.ingest(packet(10, at: 0)), [])
        XCTAssertEqual(try buffer.ingest(packet(12, at: milliseconds(5))), [])
        XCTAssertEqual(try buffer.ingest(packet(11, at: milliseconds(9))), [])
        let events = try buffer.advanceTime(to: milliseconds(10))

        XCTAssertEqual(events, [
            .packetReady(packet(10, at: 0)),
            .packetReady(packet(11, at: milliseconds(9))),
            .packetReady(packet(12, at: milliseconds(5)))
        ])
        XCTAssertEqual(buffer.snapshot().deliveredPacketCount, 3)
        XCTAssertEqual(buffer.snapshot().bufferedPacketCount, 0)
    }

    func testUInt16SequenceWrapOrdersPacketsWithoutFalseLoss() throws {
        var buffer = try makeBuffer()
        _ = try buffer.ingest(packet(.max, at: 0))
        _ = try buffer.ingest(packet(1, at: milliseconds(2)))
        _ = try buffer.ingest(packet(0, at: milliseconds(4)))

        let events = try buffer.advanceTime(to: milliseconds(10))

        XCTAssertEqual(events.map(\.readySequence), [UInt16.max, 0, 1])
        XCTAssertEqual(buffer.snapshot().lostPacketCount, 0)
    }

    func testPrePlayoutPacketCanMoveInitialSequenceBackwardWithinWindow() throws {
        var buffer = try makeBuffer()
        _ = try buffer.ingest(packet(101, at: 0))
        _ = try buffer.ingest(packet(100, at: milliseconds(1)))

        let events = try buffer.advanceTime(to: milliseconds(10))

        XCTAssertEqual(events.map(\.readySequence), [100, 101])
    }

    func testDuplicateConflictAndLatePacketsRemainExplicit() throws {
        var buffer = try makeBuffer()
        let original = packet(5, timestamp: 1_000, at: 0, byte: 0x11)
        XCTAssertEqual(try buffer.ingest(original), [])
        XCTAssertEqual(try buffer.ingest(packet(5, timestamp: 1_000, at: 1, byte: 0x11)), [
            .packetDiscarded(sequenceNumber: 5, reason: .duplicate)
        ])
        XCTAssertEqual(try buffer.ingest(packet(5, timestamp: 1_001, at: 2, byte: 0x22)), [
            .packetDiscarded(sequenceNumber: 5, reason: .conflictingDuplicate)
        ])
        _ = try buffer.advanceTime(to: milliseconds(10))
        XCTAssertEqual(try buffer.ingest(packet(4, at: milliseconds(11))), [
            .packetDiscarded(sequenceNumber: 4, reason: .late)
        ])

        let snapshot = buffer.snapshot()
        XCTAssertEqual(snapshot.duplicatePacketCount, 1)
        XCTAssertEqual(snapshot.conflictingDuplicatePacketCount, 1)
        XCTAssertEqual(snapshot.latePacketCount, 1)
    }

    func testJitterDeadlineDeclaresBoundedLossThenReleasesFuturePacket() throws {
        var buffer = try makeBuffer()
        _ = try buffer.ingest(packet(20, at: 0))
        _ = try buffer.ingest(packet(22, at: milliseconds(1)))

        XCTAssertEqual(try buffer.advanceTime(to: milliseconds(10)).map(\.readySequence), [20])
        let events = try buffer.advanceTime(to: milliseconds(41))

        XCTAssertEqual(events, [
            .packetsLost(AudioPacketLossRange(
                firstSequenceNumber: 21,
                lastSequenceNumber: 21,
                packetCount: 1,
                reason: .jitterDeadlineExceeded
            )),
            .packetReady(packet(22, at: milliseconds(1)))
        ])
        XCTAssertEqual(buffer.snapshot().lostPacketCount, 1)
    }

    func testDiscardedArrivalStillAdvancesJitterDeadline() throws {
        var buffer = try makeBuffer()
        _ = try buffer.ingest(packet(20, at: 0))
        _ = try buffer.ingest(packet(22, at: milliseconds(1)))
        _ = try buffer.advanceTime(to: milliseconds(10))

        let events = try buffer.ingest(packet(22, at: milliseconds(41)))

        XCTAssertEqual(events, [
            .packetDiscarded(sequenceNumber: 22, reason: .duplicate),
            .packetsLost(AudioPacketLossRange(
                firstSequenceNumber: 21,
                lastSequenceNumber: 21,
                packetCount: 1,
                reason: .jitterDeadlineExceeded
            )),
            .packetReady(packet(22, at: milliseconds(1)))
        ])
    }

    func testReorderWindowExceededDoesNotWaitForJitterDeadline() throws {
        var buffer = try makeBuffer(maximumReorderDistance: 2)
        _ = try buffer.ingest(packet(30, at: 0))
        _ = try buffer.ingest(packet(34, at: milliseconds(1)))

        let events = try buffer.advanceTime(to: milliseconds(10))

        XCTAssertEqual(events, [
            .packetReady(packet(30, at: 0)),
            .packetsLost(AudioPacketLossRange(
                firstSequenceNumber: 31,
                lastSequenceNumber: 33,
                packetCount: 3,
                reason: .reorderWindowExceeded
            )),
            .packetReady(packet(34, at: milliseconds(1)))
        ])
    }

    func testCapacityPressureStartsPlaybackAndKeepsPacketAndByteBounds() throws {
        var buffer = try makeBuffer(maximumBufferedPackets: 2)
        _ = try buffer.ingest(packet(40, at: 0))
        _ = try buffer.ingest(packet(42, at: 1))

        let events = try buffer.ingest(packet(43, at: 2))

        XCTAssertEqual(events, [
            .packetReady(packet(40, at: 0)),
            .packetsLost(AudioPacketLossRange(
                firstSequenceNumber: 41,
                lastSequenceNumber: 41,
                packetCount: 1,
                reason: .bufferCapacityExceeded
            )),
            .packetReady(packet(42, at: 1)),
            .packetReady(packet(43, at: 2))
        ])
        let snapshot = buffer.snapshot()
        XCTAssertEqual(snapshot.bufferedPacketCount, 0)
        XCTAssertEqual(snapshot.bufferedPayloadBytes, 0)
        XCTAssertEqual(snapshot.capacityRecoveryCount, 1)
    }

    func testFinishFlushesBufferedPacketsAndMarksMissingRange() throws {
        var buffer = try makeBuffer()
        _ = try buffer.ingest(packet(50, at: 0))
        _ = try buffer.ingest(packet(52, at: 1))

        let events = try buffer.finish(at: 2)

        XCTAssertEqual(events, [
            .packetReady(packet(50, at: 0)),
            .packetsLost(AudioPacketLossRange(
                firstSequenceNumber: 51,
                lastSequenceNumber: 51,
                packetCount: 1,
                reason: .endOfStream
            )),
            .packetReady(packet(52, at: 1))
        ])
        XCTAssertTrue(buffer.snapshot().isFinished)
        XCTAssertEqual(try buffer.finish(at: 2), [])
    }

    func testRealtimePolicyDerivesDelayFromNegotiatedPacketCadence() throws {
        let policy = try AudioJitterBufferPolicy.realtime(configuration: audioConfiguration())

        XCTAssertEqual(policy.targetDelayNanoseconds, milliseconds(10))
        XCTAssertEqual(policy.maximumJitterNanoseconds, milliseconds(40))
        XCTAssertEqual(policy.maximumPacketBytes, 1_400)
        XCTAssertEqual(policy.maximumBufferedBytes, 44_800)

        var oversized = audioConfiguration()
        oversized.samplesPerFrame = .max
        XCTAssertThrowsError(try AudioJitterBufferPolicy.realtime(configuration: oversized)) { error in
            XCTAssertEqual(error as? AudioJitterBufferError, .invalidPolicy)
        }
    }

    func testInvalidPolicyPayloadClockAndForwardGapFailClosed() throws {
        XCTAssertThrowsError(try AudioPacketJitterBuffer(policy: AudioJitterBufferPolicy(
            targetDelayNanoseconds: 0,
            maximumJitterNanoseconds: 1,
            maximumReorderDistance: 1,
            maximumForwardGap: 1,
            maximumBufferedPackets: 1,
            maximumBufferedBytes: 1,
            maximumPacketBytes: 1
        )))

        var buffer = try makeBuffer()
        XCTAssertThrowsError(try buffer.ingest(packet(1, at: 0, payload: Data()))) { error in
            XCTAssertEqual(error as? AudioJitterBufferError, .invalidPacketPayload)
        }
        _ = try buffer.ingest(packet(1, at: 10))
        XCTAssertThrowsError(try buffer.advanceTime(to: 9)) { error in
            XCTAssertEqual(error as? AudioJitterBufferError, .nonMonotonicClock)
        }

        var gapBuffer = try makeBuffer(maximumForwardGap: 64)
        _ = try gapBuffer.ingest(packet(1, at: 0))
        XCTAssertThrowsError(try gapBuffer.ingest(packet(100, at: 1))) { error in
            XCTAssertEqual(
                error as? AudioJitterBufferError,
                .sequenceGapTooLarge(expected: 1, received: 100)
            )
        }
        XCTAssertEqual(gapBuffer.snapshot().bufferedPacketCount, 1)
        XCTAssertEqual(try gapBuffer.advanceTime(to: 0), [])
    }

    private func makeBuffer(
        maximumReorderDistance: UInt16 = 8,
        maximumForwardGap: UInt16 = 64,
        maximumBufferedPackets: Int = 4
    ) throws -> AudioPacketJitterBuffer {
        try AudioPacketJitterBuffer(policy: AudioJitterBufferPolicy(
            targetDelayNanoseconds: milliseconds(10),
            maximumJitterNanoseconds: milliseconds(40),
            maximumReorderDistance: maximumReorderDistance,
            maximumForwardGap: maximumForwardGap,
            maximumBufferedPackets: maximumBufferedPackets,
            maximumBufferedBytes: maximumBufferedPackets * 16,
            maximumPacketBytes: 16
        ))
    }

    private func packet(
        _ sequenceNumber: UInt16,
        timestamp: UInt32? = nil,
        at receiveTimeNanoseconds: UInt64,
        byte: UInt8 = 0xAA,
        payload: Data? = nil
    ) -> ReceivedAudioPacket {
        ReceivedAudioPacket(
            sequenceNumber: sequenceNumber,
            timestamp: timestamp ?? UInt32(sequenceNumber) * 240,
            receiveTimeNanoseconds: receiveTimeNanoseconds,
            payload: payload ?? Data([byte])
        )
    }

    private func milliseconds(_ value: UInt64) -> UInt64 {
        value * 1_000_000
    }

    private func audioConfiguration() -> NegotiatedAudioStreamConfiguration {
        NegotiatedAudioStreamConfiguration(
            sampleRate: 48_000,
            channelCount: 2,
            streamCount: 1,
            coupledStreamCount: 1,
            samplesPerFrame: 240,
            channelMapping: [0, 1],
            maximumPacketSize: 1_400
        )
    }
}

private extension AudioJitterBufferEvent {
    var readySequence: UInt16? {
        guard case let .packetReady(packet) = self else { return nil }
        return packet.sequenceNumber
    }
}
