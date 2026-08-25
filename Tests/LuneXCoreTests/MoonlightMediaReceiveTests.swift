import Foundation
import XCTest

final class MoonlightMediaReceiveTests: XCTestCase {
    func testVideoProviderMapsDataPacketAndSkipsParity() async throws {
        let channel = MediaReceiveStubChannel(chunks: [
            .success(NetworkReceiveChunk(
                data: makeVideoDatagram(
                    sequenceNumber: 7,
                    frameIndex: 41,
                    rtpTimestamp: 90_000,
                    isParity: true,
                    payload: Data([0xEE])
                ),
                isComplete: true
            )),
            .success(NetworkReceiveChunk(
                data: makeVideoDatagram(
                    sequenceNumber: 7,
                    frameIndex: 41,
                    rtpTimestamp: 90_000,
                    isParity: false,
                    payload: Data([0x01, 0x02, 0x03])
                ),
                isComplete: true
            ))
        ])
        let provider = MoonlightVideoReceiveProvider(
            channelFactory: { _, _ in channel },
            timing: testTiming,
            timeProvider: { 123_456 }
        )
        let sessionID = UUID()
        let stream = await provider.receiveVideo(
            sessionID: sessionID,
            endpoint: udpEndpoint(port: 47_998),
            configuration: videoConfiguration()
        )
        var iterator = stream.makeAsyncIterator()

        let event = try await iterator.next()

        XCTAssertEqual(event, .packet(ReceivedVideoPacket(
            sequenceNumber: 7,
            frameIndex: 41,
            rtpTimestamp: 90_000,
            receiveTimeNanoseconds: 123_456,
            isFirstPacket: true,
            isLastPacket: true,
            payload: Data([0x01, 0x02, 0x03])
        )))
        let sentLegacyPing = await waitUntil {
            await channel.sentDatagrams().contains(Data("PING".utf8))
        }
        XCTAssertTrue(sentLegacyPing)
        await provider.stopVideo(sessionID: sessionID)
        let videoCancelCount = await channel.cancelCount()
        XCTAssertEqual(videoCancelCount, 1)
    }

    func testAudioProviderMapsOpusSkipsFECAndSendsSequencedCustomPing()
        async throws
    {
        let channel = MediaReceiveStubChannel(chunks: [
            .success(NetworkReceiveChunk(
                data: makeAudioDatagram(
                    payloadType: MoonlightAudioRTPPacket.fecPayloadType,
                    sequenceNumber: 10,
                    timestamp: 240,
                    payload: Data([0xFE, 0xC0])
                ),
                isComplete: true
            )),
            .success(NetworkReceiveChunk(
                data: makeAudioDatagram(
                    payloadType: MoonlightAudioRTPPacket.opusPayloadType,
                    sequenceNumber: 11,
                    timestamp: 480,
                    payload: Data([0x4F, 0x70, 0x75, 0x73])
                ),
                isComplete: true
            ))
        ])
        let provider = MoonlightAudioReceiveProvider(
            channelFactory: { _, _ in channel },
            timing: testTiming,
            timeProvider: { 777 }
        )
        let pingPayload = Data("audio-ping-00000".utf8)
        let sessionID = UUID()
        let stream = await provider.receiveAudio(
            sessionID: sessionID,
            endpoint: udpEndpoint(port: 48_000),
            configuration: audioConfiguration(pingPayload: pingPayload)
        )
        var iterator = stream.makeAsyncIterator()

        let event = try await iterator.next()

        XCTAssertEqual(event, .packet(ReceivedAudioPacket(
            sequenceNumber: 11,
            timestamp: 480,
            receiveTimeNanoseconds: 777,
            payload: Data([0x4F, 0x70, 0x75, 0x73])
        )))
        let sentCustomPing = await waitUntil {
            await channel.sentDatagrams().count >= 2
        }
        XCTAssertTrue(sentCustomPing)
        let customPings = await channel.sentDatagrams()
        XCTAssertEqual(customPings[0], pingPayload + Data([0, 0, 0, 0]))
        XCTAssertEqual(customPings[1], pingPayload + Data([0, 0, 0, 1]))
        await provider.stopAudio(sessionID: sessionID)
        let audioCancelCount = await channel.cancelCount()
        XCTAssertEqual(audioCancelCount, 1)
    }

    func testAudioParserRejectsUnsupportedLayoutsBoundsAndPayloads() throws {
        let valid = makeAudioDatagram(
            payloadType: MoonlightAudioRTPPacket.opusPayloadType,
            sequenceNumber: 0x1234,
            timestamp: 0x0102_0304,
            payload: Data([0xAA])
        )
        let parsed = try MoonlightAudioRTPPacketParser.parse(
            valid,
            maximumPayloadSize: 1_400
        )
        XCTAssertEqual(parsed.sequenceNumber, 0x1234)
        XCTAssertEqual(parsed.timestamp, 0x0102_0304)
        XCTAssertEqual(parsed.payload, Data([0xAA]))

        XCTAssertThrowsError(try MoonlightAudioRTPPacketParser.parse(
            Data(repeating: 0, count: 11),
            maximumPayloadSize: 1_400
        )) { error in
            XCTAssertEqual(
                error as? MoonlightAudioRTPPacketError,
                .datagramTooSmall
            )
        }

        for layoutMask: UInt8 in [0x20, 0x10, 0x01] {
            var invalidLayout = valid
            invalidLayout[invalidLayout.startIndex] |= layoutMask
            XCTAssertThrowsError(try MoonlightAudioRTPPacketParser.parse(
                invalidLayout,
                maximumPayloadSize: 1_400
            )) { error in
                XCTAssertEqual(
                    error as? MoonlightAudioRTPPacketError,
                    .unsupportedRTPLayout
                )
            }
        }

        let unknownType = makeAudioDatagram(
            payloadType: 96,
            sequenceNumber: 1,
            timestamp: 1,
            payload: Data([1])
        )
        XCTAssertThrowsError(try MoonlightAudioRTPPacketParser.parse(
            unknownType,
            maximumPayloadSize: 1_400
        )) { error in
            XCTAssertEqual(
                error as? MoonlightAudioRTPPacketError,
                .unsupportedPayloadType(96)
            )
        }

        let emptyPayload = Data(valid.prefix(MoonlightAudioRTPPacket.fixedHeaderBytes))
        XCTAssertThrowsError(try MoonlightAudioRTPPacketParser.parse(
            emptyPayload,
            maximumPayloadSize: 1_400
        )) { error in
            XCTAssertEqual(error as? MoonlightAudioRTPPacketError, .emptyPayload)
        }

        let oversized = makeAudioDatagram(
            payloadType: MoonlightAudioRTPPacket.opusPayloadType,
            sequenceNumber: 1,
            timestamp: 1,
            payload: Data(repeating: 0, count: 1_401)
        )
        XCTAssertThrowsError(try MoonlightAudioRTPPacketParser.parse(
            oversized,
            maximumPayloadSize: 1_400
        )) { error in
            XCTAssertEqual(
                error as? MoonlightAudioRTPPacketError,
                .datagramTooLarge
            )
        }
    }

    func testStopIsIdempotentAndWaitsForBlockedReceiveCancellation()
        async throws
    {
        let channel = MediaReceiveStubChannel()
        let provider = MoonlightAudioReceiveProvider(
            channelFactory: { _, _ in channel },
            timing: testTiming
        )
        let sessionID = UUID()
        let stream = await provider.receiveAudio(
            sessionID: sessionID,
            endpoint: udpEndpoint(port: 48_000),
            configuration: audioConfiguration()
        )
        let consumer = Task {
            var iterator = stream.makeAsyncIterator()
            return try await iterator.next()
        }
        let receiveBlocked = await waitUntil { await channel.isReceiveBlocked() }
        XCTAssertTrue(receiveBlocked)

        await provider.stopAudio(sessionID: sessionID)
        await provider.stopAudio(sessionID: sessionID)

        let terminalEvent = try await consumer.value
        let cancelCount = await channel.cancelCount()
        let snapshot = await provider.snapshot()
        XCTAssertNil(terminalEvent)
        XCTAssertEqual(cancelCount, 1)
        XCTAssertFalse(snapshot.isActive)
    }

    func testConsumerCancellationPropagatesToChannel() async throws {
        let channel = MediaReceiveStubChannel()
        let provider = MoonlightVideoReceiveProvider(
            channelFactory: { _, _ in channel },
            timing: testTiming
        )
        let sessionID = UUID()
        let stream = await provider.receiveVideo(
            sessionID: sessionID,
            endpoint: udpEndpoint(port: 47_998),
            configuration: videoConfiguration()
        )
        let consumer = Task {
            var iterator = stream.makeAsyncIterator()
            return try await iterator.next()
        }
        let receiveBlocked = await waitUntil { await channel.isReceiveBlocked() }
        XCTAssertTrue(receiveBlocked)

        consumer.cancel()
        let terminalEvent = try await consumer.value
        let cancelled = await waitUntil { await channel.cancelCount() == 1 }
        let snapshot = await provider.snapshot()

        XCTAssertNil(terminalEvent)
        XCTAssertTrue(cancelled)
        XCTAssertFalse(snapshot.isActive)
    }

    func testReplacementLateCompletionCannotClearCurrentSession() async throws {
        let firstChannel = MediaReceiveStubChannel()
        let secondChannel = MediaReceiveStubChannel()
        let channels = MediaReceiveChannelQueue([
            firstChannel,
            secondChannel
        ])
        let provider = MoonlightVideoReceiveProvider(
            channelFactory: { _, _ in try channels.next() },
            timing: testTiming
        )
        let firstSessionID = UUID()
        let secondSessionID = UUID()
        let firstStream = await provider.receiveVideo(
            sessionID: firstSessionID,
            endpoint: udpEndpoint(port: 47_998),
            configuration: videoConfiguration()
        )
        let firstConsumer = Task {
            var iterator = firstStream.makeAsyncIterator()
            return try await iterator.next()
        }
        let firstReceiveBlocked = await waitUntil {
            await firstChannel.isReceiveBlocked()
        }
        XCTAssertTrue(firstReceiveBlocked)

        let secondStream = await provider.receiveVideo(
            sessionID: secondSessionID,
            endpoint: udpEndpoint(port: 47_998),
            configuration: videoConfiguration()
        )
        let secondConsumer = Task {
            var iterator = secondStream.makeAsyncIterator()
            return try await iterator.next()
        }
        let secondReceiveBlocked = await waitUntil {
            await secondChannel.isReceiveBlocked()
        }
        XCTAssertTrue(secondReceiveBlocked)
        await provider.stopVideo(sessionID: firstSessionID)

        let current = await provider.snapshot()
        XCTAssertEqual(current.sessionID, secondSessionID)
        XCTAssertTrue(current.isActive)
        let firstCancelCount = await firstChannel.cancelCount()
        let secondCancelCountBeforeStop = await secondChannel.cancelCount()
        XCTAssertEqual(firstCancelCount, 1)
        XCTAssertEqual(secondCancelCountBeforeStop, 0)
        let firstTerminalEvent = try await firstConsumer.value
        XCTAssertNil(firstTerminalEvent)

        await provider.stopVideo(sessionID: secondSessionID)
        let secondTerminalEvent = try await secondConsumer.value
        let secondCancelCountAfterStop = await secondChannel.cancelCount()
        let stoppedSnapshot = await provider.snapshot()
        XCTAssertNil(secondTerminalEvent)
        XCTAssertEqual(secondCancelCountAfterStop, 1)
        XCTAssertFalse(stoppedSnapshot.isActive)
    }

    func testProviderRejectsNonUDPEndpointBeforeCreatingChannel() async {
        let provider = MoonlightAudioReceiveProvider(
            channelFactory: { _, _ in
                XCTFail("Invalid endpoints must fail before channel creation.")
                return MediaReceiveStubChannel()
            },
            timing: testTiming
        )
        let stream = await provider.receiveAudio(
            sessionID: UUID(),
            endpoint: RuntimeNetworkEndpoint(
                host: "moon.local",
                port: 48_000,
                transport: .tcp
            ),
            configuration: audioConfiguration()
        )

        do {
            for try await _ in stream {}
            XCTFail("A TCP media endpoint must fail closed.")
        } catch {
            XCTAssertEqual(
                error as? MoonlightMediaReceiveError,
                .invalidEndpoint
            )
        }
    }

    private var testTiming: MoonlightMediaReceiveTiming {
        MoonlightMediaReceiveTiming(
            connectTimeout: .seconds(1),
            sendTimeout: .seconds(1),
            receiveTimeout: .seconds(1),
            pingInterval: .milliseconds(10)
        )
    }

    private func udpEndpoint(port: UInt16) -> RuntimeNetworkEndpoint {
        RuntimeNetworkEndpoint(
            host: "moon.local",
            port: port,
            transport: .udp
        )
    }

    private func videoConfiguration(
        pingPayload: Data? = nil
    ) -> NegotiatedVideoStreamConfiguration {
        NegotiatedVideoStreamConfiguration(
            codec: .hevc,
            width: 1920,
            height: 1080,
            frameRate: 60,
            colorMetadata: .rec709VideoRange(),
            maximumPacketSize: 1_400,
            pingPayload: pingPayload
        )
    }

    private func audioConfiguration(
        pingPayload: Data? = nil
    ) -> NegotiatedAudioStreamConfiguration {
        NegotiatedAudioStreamConfiguration(
            sampleRate: 48_000,
            channelLayout: .stereo,
            streamCount: 1,
            coupledStreamCount: 1,
            samplesPerFrame: 240,
            channelMapping: [0, 1],
            maximumPacketSize: 1_400,
            pingPayload: pingPayload
        )
    }

    private func makeAudioDatagram(
        payloadType: UInt8,
        sequenceNumber: UInt16,
        timestamp: UInt32,
        payload: Data
    ) -> Data {
        var bytes = [UInt8](
            repeating: 0,
            count: MoonlightAudioRTPPacket.fixedHeaderBytes
        )
        bytes[0] = 0x80
        bytes[1] = payloadType
        writeBigEndian(sequenceNumber, into: &bytes, at: 2)
        writeBigEndian(timestamp, into: &bytes, at: 4)
        writeBigEndian(UInt32(0xAABB_CCDD), into: &bytes, at: 8)
        return Data(bytes) + payload
    }

    private func makeVideoDatagram(
        sequenceNumber: UInt32,
        frameIndex: UInt32,
        rtpTimestamp: UInt32,
        isParity: Bool,
        payload: Data
    ) -> Data {
        var bytes = [UInt8](
            repeating: 0,
            count: MoonlightVideoPacketLimits.fixedHeaderBytes
        )
        bytes[0] = 0x90
        writeBigEndian(UInt16(truncatingIfNeeded: sequenceNumber), into: &bytes, at: 2)
        writeBigEndian(rtpTimestamp, into: &bytes, at: 4)
        writeBigEndian(UInt32(0x0102_0304), into: &bytes, at: 8)
        writeLittleEndian((sequenceNumber & 0x00FF_FFFF) << 8, into: &bytes, at: 16)
        writeLittleEndian(frameIndex, into: &bytes, at: 20)
        bytes[24] = isParity ? 0 : 0x07
        bytes[26] = 0x10
        bytes[27] = 0
        let shardIndex: UInt32 = isParity ? 1 : 0
        let fecInfo = (UInt32(1) << 22) | (shardIndex << 12) | (UInt32(100) << 4)
        writeLittleEndian(fecInfo, into: &bytes, at: 28)
        return Data(bytes) + payload
    }

    private func writeBigEndian(
        _ value: UInt16,
        into bytes: inout [UInt8],
        at offset: Int
    ) {
        bytes[offset] = UInt8(truncatingIfNeeded: value >> 8)
        bytes[offset + 1] = UInt8(truncatingIfNeeded: value)
    }

    private func writeBigEndian(
        _ value: UInt32,
        into bytes: inout [UInt8],
        at offset: Int
    ) {
        bytes[offset] = UInt8(truncatingIfNeeded: value >> 24)
        bytes[offset + 1] = UInt8(truncatingIfNeeded: value >> 16)
        bytes[offset + 2] = UInt8(truncatingIfNeeded: value >> 8)
        bytes[offset + 3] = UInt8(truncatingIfNeeded: value)
    }

    private func writeLittleEndian(
        _ value: UInt32,
        into bytes: inout [UInt8],
        at offset: Int
    ) {
        bytes[offset] = UInt8(truncatingIfNeeded: value)
        bytes[offset + 1] = UInt8(truncatingIfNeeded: value >> 8)
        bytes[offset + 2] = UInt8(truncatingIfNeeded: value >> 16)
        bytes[offset + 3] = UInt8(truncatingIfNeeded: value >> 24)
    }

    private func waitUntil(
        _ predicate: @escaping () async -> Bool
    ) async -> Bool {
        for _ in 0..<100 {
            if await predicate() { return true }
            try? await Task.sleep(for: .milliseconds(5))
        }
        return false
    }
}

private final class MediaReceiveStubChannel: MoonlightDatagramChannel,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var chunks: [Result<NetworkReceiveChunk, Error>]
    private var pendingReceive:
        CheckedContinuation<NetworkReceiveChunk, Error>?
    private var sent: [Data] = []
    private var connected = false
    private var cancelled = false
    private var cancellations = 0

    init(chunks: [Result<NetworkReceiveChunk, Error>] = []) {
        self.chunks = chunks
    }

    func connect(timeout: Duration) async throws {
        _ = timeout
        try lock.withLock {
            guard !cancelled else { throw CancellationError() }
            connected = true
        }
    }

    func send(_ data: Data, timeout: Duration) async throws {
        _ = timeout
        try lock.withLock {
            guard connected, !cancelled else { throw CancellationError() }
            sent.append(data)
        }
    }

    func receive(
        minimumLength: Int,
        maximumLength: Int?,
        timeout: Duration
    ) async throws -> NetworkReceiveChunk {
        _ = minimumLength
        _ = maximumLength
        _ = timeout
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let immediate: Result<NetworkReceiveChunk, Error>? = lock.withLock {
                    if cancelled { return .failure(CancellationError()) }
                    if !chunks.isEmpty { return chunks.removeFirst() }
                    pendingReceive = continuation
                    return nil
                }
                immediate.map { continuation.resume(with: $0) }
            }
        } onCancel: {
            self.cancelSynchronously()
        }
    }

    func cancel() async {
        cancelSynchronously()
    }

    func sentDatagrams() async -> [Data] {
        lock.withLock { sent }
    }

    func cancelCount() async -> Int {
        lock.withLock { cancellations }
    }

    func isReceiveBlocked() async -> Bool {
        lock.withLock { pendingReceive != nil }
    }

    private func cancelSynchronously() {
        let continuation: CheckedContinuation<NetworkReceiveChunk, Error>? =
            lock.withLock {
                guard !cancelled else { return nil }
                cancelled = true
                cancellations += 1
                let continuation = pendingReceive
                pendingReceive = nil
                return continuation
            }
        continuation?.resume(throwing: CancellationError())
    }
}

private final class MediaReceiveChannelQueue: @unchecked Sendable {
    enum QueueError: Error {
        case exhausted
    }

    private let lock = NSLock()
    private var channels: [MediaReceiveStubChannel]

    init(_ channels: [MediaReceiveStubChannel]) {
        self.channels = channels
    }

    func next() throws -> MediaReceiveStubChannel {
        try lock.withLock {
            guard !channels.isEmpty else { throw QueueError.exhausted }
            return channels.removeFirst()
        }
    }
}
