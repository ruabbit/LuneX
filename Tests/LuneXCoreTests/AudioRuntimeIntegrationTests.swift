import Foundation
import XCTest

final class AudioRuntimeIntegrationTests: XCTestCase {
    func testReorderedProductionDecodeTracksActualFramesAndTearsDownCleanly() async throws {
        let fixture = try loadStereoFixture()
        let payloads = try fixture.packets.map { packet in
            try XCTUnwrap(Data(base64Encoded: packet.base64Payload))
        }
        let configuration = stereoConfiguration()
        var jitterBuffer = try AudioPacketJitterBuffer(
            policy: AudioJitterBufferPolicy.realtime(configuration: configuration)
        )
        let decoder = try AudioToolboxOpusDecoder(configuration: configuration)
        let engineClient = IntegrationAudioEngineClient()
        let pipeline = AudioSessionPipeline(engineClient: engineClient)
        let clock = try MediaClockSynchronizer()
        let runtime = try SessionAudioRuntime(
            pipeline: pipeline,
            clock: clock,
            configuration: .stereoLowLatency
        )
        let tracker = SessionResourceTracker()
        let teardownRecorder = AudioIntegrationTeardownRecorder()
        let teardownTime = seconds(1)
        _ = try await tracker.registerResource(kind: .decoder, name: "opus-decoder") {
            await teardownRecorder.append("decoder")
            await decoder.close()
        }
        _ = try await tracker.registerResource(kind: .audioGraph, name: "audio-runtime") {
            await teardownRecorder.append("audio")
            _ = try? await runtime.stop(at: teardownTime)
        }
        _ = try await runtime.start(at: 0)

        let first = packet(
            sequence: .max,
            timestamp: UInt32.max &- 239,
            receiveTime: 0,
            payload: payloads[0]
        )
        let second = packet(
            sequence: 0,
            timestamp: 0,
            receiveTime: milliseconds(4),
            payload: payloads[1]
        )
        let third = packet(
            sequence: 1,
            timestamp: 240,
            receiveTime: milliseconds(2),
            payload: payloads[2]
        )
        var events = try jitterBuffer.ingest(first)
        events += try jitterBuffer.ingest(third)
        events += try jitterBuffer.ingest(second)
        events += try jitterBuffer.advanceTime(to: milliseconds(10))
        let orderedPackets = readyPackets(in: events)

        XCTAssertEqual(orderedPackets.map(\.sequenceNumber), [UInt16.max, 0, 1])
        XCTAssertEqual(jitterBuffer.snapshot().deliveredPacketCount, 3)
        XCTAssertEqual(jitterBuffer.snapshot().lostPacketCount, 0)

        var presentationTime = milliseconds(10)
        var decodedBuffers: [DecodedPCMBuffer] = []
        for orderedPacket in orderedPackets {
            decodedBuffers.append(try await decoder.decode(orderedPacket))
        }
        guard decodedBuffers.allSatisfy(isPipelineCompatible) else {
            return XCTFail(
                "Invalid consecutive decoded PCM: "
                    + decodedBuffers.map(decodedSummary).joined(separator: ", ")
            )
        }
        for decoded in decodedBuffers {
            _ = try await runtime.schedule(
                decoded,
                presentationTimeNanoseconds: presentationTime
            )
            presentationTime += nanoseconds(frames: decoded.frameCount)
        }

        let running = try await runtime.snapshot(at: presentationTime)
        let actualDecodedFrames = decodedBuffers.reduce(0) { $0 + $1.frameCount }
        XCTAssertEqual(running.stage, .running)
        XCTAssertEqual(running.clock.master, .audio)
        XCTAssertEqual(running.clock.audioScheduledFrameCount, UInt64(actualDecodedFrames))
        XCTAssertEqual(
            engineClient.snapshotScheduledBuffers().map(\.sequenceNumber),
            [UInt16.max, 0, 1]
        )
        XCTAssertTrue(decodedBuffers.allSatisfy { $0.interleavedSamples.contains(where: { $0 != 0 }) })

        let report = try await tracker.teardown(gracePeriod: .seconds(1))
        let teardownOrder = await teardownRecorder.values
        let scheduledBufferCountAfterTeardown = await pipeline.scheduledBufferCount()

        XCTAssertTrue(report.isClean)
        XCTAssertEqual(report.stoppedResourceCount, 2)
        XCTAssertEqual(teardownOrder, ["audio", "decoder"])
        XCTAssertEqual(scheduledBufferCountAfterTeardown, 0)
        XCTAssertTrue(engineClient.snapshotScheduledBuffers().isEmpty)
        engineClient.fireAllConsumedCallbacks()
        await Task.yield()
        let scheduledBufferCountAfterLateCallbacks = await pipeline.scheduledBufferCount()
        XCTAssertEqual(scheduledBufferCountAfterLateCallbacks, 0)
        let stopped = try await runtime.snapshot(at: teardownTime)
        XCTAssertEqual(stopped.stage, .stopped)
        XCTAssertEqual(stopped.clock.master, .unavailable)
        await AudioIntegrationXCTAssertThrowsErrorAsync(
            try await decoder.decode(first)
        ) { error in
            XCTAssertEqual(error as? OpusDecoderError, .closed)
        }
    }

    func testJitterLossConcealmentKeepsDecodeOrderAndClockBounded() async throws {
        let fixture = try loadStereoFixture()
        let payloads = try fixture.packets.map { packet in
            try XCTUnwrap(Data(base64Encoded: packet.base64Payload))
        }
        let configuration = stereoConfiguration()
        var jitterBuffer = try AudioPacketJitterBuffer(
            policy: AudioJitterBufferPolicy.realtime(configuration: configuration)
        )
        let decoder = try AudioToolboxOpusDecoder(configuration: configuration)
        let engineClient = IntegrationAudioEngineClient()
        let pipeline = AudioSessionPipeline(engineClient: engineClient)
        let runtime = try SessionAudioRuntime(
            pipeline: pipeline,
            clock: MediaClockSynchronizer(),
            configuration: .stereoLowLatency
        )
        _ = try await runtime.start(at: 0)

        let packet10 = packet(
            sequence: 10,
            timestamp: 2_400,
            receiveTime: 0,
            payload: payloads[0]
        )
        let packet12 = packet(
            sequence: 12,
            timestamp: 2_880,
            receiveTime: milliseconds(1),
            payload: payloads[2]
        )
        _ = try jitterBuffer.ingest(packet10)
        _ = try jitterBuffer.ingest(packet12)
        let initialEvents = try jitterBuffer.advanceTime(to: milliseconds(10))
        let firstReady = try XCTUnwrap(readyPackets(in: initialEvents).first)
        let firstDecoded = try await decoder.decode(firstReady)
        guard assertPipelineCompatible(firstDecoded) else { return }
        _ = try await runtime.schedule(
            firstDecoded,
            presentationTimeNanoseconds: milliseconds(10)
        )

        let recoveryEvents = try jitterBuffer.advanceTime(to: milliseconds(41))
        XCTAssertEqual(recoveryEvents.count, 2)
        guard case let .packetsLost(loss) = recoveryEvents[0] else {
            return XCTFail("Expected a bounded loss event before the recovered packet")
        }
        XCTAssertEqual(loss.firstSequenceNumber, 11)
        XCTAssertEqual(loss.packetCount, 1)
        XCTAssertEqual(loss.reason, .jitterDeadlineExceeded)
        let concealed = try await runtime.handle(.packetLoss(
            firstSequenceNumber: loss.firstSequenceNumber,
            firstRTPTimeStamp: 2_640,
            packetCount: loss.packetCount,
            samplesPerPacket: configuration.samplesPerFrame
        ), at: milliseconds(41))
        XCTAssertEqual(concealed.lastAction, .silenceScheduled(packetCount: 1, frameCount: 240))

        guard case let .packetReady(recoveredPacket) = recoveryEvents[1] else {
            return XCTFail("Expected the future packet after loss concealment")
        }
        let recoveredDecoded = try await decoder.decode(recoveredPacket)
        guard assertPipelineCompatible(recoveredDecoded) else { return }
        _ = try await runtime.schedule(
            recoveredDecoded,
            presentationTimeNanoseconds: milliseconds(46)
        )
        let snapshot = try await runtime.snapshot(
            at: milliseconds(46) + nanoseconds(frames: recoveredDecoded.frameCount)
        )
        let scheduled = engineClient.snapshotScheduledBuffers()

        XCTAssertEqual(scheduled.map(\.sequenceNumber), [10, 11, 12])
        XCTAssertTrue(scheduled[1].interleavedSamples.allSatisfy { $0 == 0 })
        XCTAssertEqual(snapshot.concealedFrameCount, 240)
        XCTAssertEqual(
            snapshot.clock.audioScheduledFrameCount,
            UInt64(firstDecoded.frameCount + 240 + recoveredDecoded.frameCount)
        )
        XCTAssertEqual(jitterBuffer.snapshot().deliveredPacketCount, 2)
        XCTAssertEqual(jitterBuffer.snapshot().lostPacketCount, 1)
        XCTAssertEqual(jitterBuffer.snapshot().bufferedPacketCount, 0)

        _ = try await runtime.stop(at: milliseconds(100))
        await decoder.close()
        let scheduledBufferCountAfterStop = await pipeline.scheduledBufferCount()
        XCTAssertEqual(scheduledBufferCountAfterStop, 0)
        XCTAssertTrue(engineClient.snapshotScheduledBuffers().isEmpty)
    }

    private func stereoConfiguration() -> NegotiatedAudioStreamConfiguration {
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

    private func loadStereoFixture() throws -> AudioIntegrationFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/audio/stereo-sequence-5ms-opus.json")
        return try JSONDecoder().decode(
            AudioIntegrationFixture.self,
            from: Data(contentsOf: url)
        )
    }

    private func packet(
        sequence: UInt16,
        timestamp: UInt32,
        receiveTime: UInt64,
        payload: Data
    ) -> ReceivedAudioPacket {
        ReceivedAudioPacket(
            sequenceNumber: sequence,
            timestamp: timestamp,
            receiveTimeNanoseconds: receiveTime,
            payload: payload
        )
    }

    private func readyPackets(in events: [AudioJitterBufferEvent]) -> [ReceivedAudioPacket] {
        events.compactMap { event in
            guard case let .packetReady(packet) = event else { return nil }
            return packet
        }
    }

    private func assertPipelineCompatible(
        _ decoded: DecodedPCMBuffer,
        file: StaticString = #filePath,
        line: UInt = #line
    ) -> Bool {
        let isCompatible = decoded.format == .signedInt16(sampleRate: 48_000, channelCount: 2)
            && (1...AVAudioPCMBufferFactory.maximumFramesPerBuffer).contains(decoded.frameCount)
            && decoded.interleavedSamples.count == decoded.frameCount * 2
        XCTAssertTrue(
            isCompatible,
            "Invalid decoded PCM: sequence=\(decoded.sequenceNumber) frames=\(decoded.frameCount) "
                + "samples=\(decoded.interleavedSamples.count) format=\(decoded.format)",
            file: file,
            line: line
        )
        return isCompatible
    }

    private func isPipelineCompatible(_ decoded: DecodedPCMBuffer) -> Bool {
        decoded.format == .signedInt16(sampleRate: 48_000, channelCount: 2)
            && (1...AVAudioPCMBufferFactory.maximumFramesPerBuffer).contains(decoded.frameCount)
            && decoded.interleavedSamples.count == decoded.frameCount * 2
    }

    private func decodedSummary(_ decoded: DecodedPCMBuffer) -> String {
        "sequence=\(decoded.sequenceNumber)/frames=\(decoded.frameCount)/samples=\(decoded.interleavedSamples.count)"
    }

    private func nanoseconds(frames: Int) -> UInt64 {
        UInt64(frames) * 1_000_000_000 / 48_000
    }

    private func milliseconds(_ value: UInt64) -> UInt64 {
        value * 1_000_000
    }

    private func seconds(_ value: UInt64) -> UInt64 {
        value * 1_000_000_000
    }
}

private struct AudioIntegrationFixture: Decodable {
    struct Packet: Decodable {
        var base64Payload: String
    }

    var packets: [Packet]
}

private actor AudioIntegrationTeardownRecorder {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}

private final class IntegrationAudioEngineClient: AudioEngineClient, @unchecked Sendable {
    private let lock = NSLock()
    private var scheduledBuffers: [DecodedPCMBuffer] = []
    private var consumedCallbacks: [@Sendable () -> Void] = []

    func configure(_ configuration: StreamAudioConfiguration) throws {}

    func start() throws {}

    func schedule(
        _ buffer: DecodedPCMBuffer,
        completion: @escaping @Sendable () -> Void
    ) throws {
        lock.withLock {
            scheduledBuffers.append(buffer)
            consumedCallbacks.append(completion)
        }
    }

    func stop(drain: Bool) {
        lock.withLock {
            scheduledBuffers.removeAll()
        }
    }

    func routeSnapshot() -> AudioRouteSnapshot {
        AudioRouteSnapshot(
            outputNames: ["Integration Output"],
            sampleRate: 48_000,
            outputChannelCount: 2,
            preferredBufferDuration: 0.005
        )
    }

    func snapshotScheduledBuffers() -> [DecodedPCMBuffer] {
        lock.withLock { scheduledBuffers }
    }

    func fireAllConsumedCallbacks() {
        let callbacks = lock.withLock { () -> [@Sendable () -> Void] in
            defer { consumedCallbacks.removeAll() }
            return consumedCallbacks
        }
        callbacks.forEach { $0() }
    }
}

private func AudioIntegrationXCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw")
    } catch {
        errorHandler(error)
    }
}
