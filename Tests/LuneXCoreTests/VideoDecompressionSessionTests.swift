@preconcurrency import CoreMedia
@preconcurrency import CoreVideo
import Foundation
@preconcurrency import VideoToolbox
import XCTest

final class VideoDecompressionSessionTests: XCTestCase {
    func testH264AnnexBIsConvertedToOwnedFourByteLengthPrefixedSample() throws {
        let fixture = try loadFixture().h264
        let accessUnit = try Data(spacedVideoHex: fixture.accessUnitHex)
        let description = try makeDescription(for: fixture, codec: .h264)
        let sample = try VideoSampleBufferFactory().make(
            sample: CompressedVideoSample(frameID: 1, accessUnit: accessUnit),
            formatDescription: description
        )

        let actual = try compressedBytes(from: sample)
        let expected = try independentlyLengthPrefix(accessUnit)
        XCTAssertEqual(actual, expected)
        XCTAssertEqual(actual.prefix(4), Data([0, 0, 0, 21]))
        XCTAssertNotEqual(actual.prefix(4), Data([0, 0, 0, 1]))
    }

    func testDestinationAttributesRequireIOSurfaceMetalAndDeterministicBitDepth() throws {
        for (bitDepth, expectedFormat) in [
            (VideoOutputBitDepth.eight, kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange),
            (VideoOutputBitDepth.ten, kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange)
        ] {
            let attributes = VideoToolboxDecompressionSessionFactory.destinationAttributes(for: bitDepth)
            XCTAssertNotNil(attributes[kCVPixelBufferIOSurfacePropertiesKey])
            XCTAssertEqual(attributes[kCVPixelBufferMetalCompatibilityKey] as? Bool, true)
            XCTAssertEqual(
                (attributes[kCVPixelBufferPixelFormatTypeKey] as? NSNumber)?.uint32Value,
                expectedFormat
            )
        }
    }

    func testH264SyntheticIDRCreatesHardwareSessionAndDecodesFrame() async throws {
        try await assertProductionDecode(codec: .h264)
    }

    func testHEVCSyntheticIDRCreatesHardwareSessionAndDecodesFrame() async throws {
        try await assertProductionDecode(codec: .hevc)
    }

    func testReplacementInvalidatesOldSessionOnceAndRejectsLateCallback() async throws {
        let fixture = try loadFixture().h264
        let description = try makeDescription(for: fixture, codec: .h264)
        let factory = RecordingVideoSessionFactory()
        let events = VideoDecoderEventStore()
        let decoder = try VideoDecoder(factory: factory, eventSink: events.append)

        let firstGeneration = try await decoder.replaceSession(
            formatDescription: description,
            bitDepth: .eight
        )
        let first = try XCTUnwrap(factory.sessions.first)
        let secondGeneration = try await decoder.replaceSession(
            formatDescription: description,
            bitDepth: .eight
        )

        XCTAssertEqual(firstGeneration, 1)
        XCTAssertEqual(secondGeneration, 2)
        XCTAssertEqual(first.finishCount, 1)
        first.emit(frameID: 91, pixelBuffer: try makePixelBuffer())
        try await Task.sleep(for: .milliseconds(30))
        XCTAssertFalse(events.frameIDs.contains(91))

        await decoder.stop()
        await decoder.stop()
        XCTAssertEqual(first.finishCount, 1)
        XCTAssertEqual(try XCTUnwrap(factory.sessions.last).finishCount, 1)
    }

    func testSynchronousDecodeErrorPublishesWithoutWaitingForCallback() async throws {
        let fixture = try loadFixture().h264
        let description = try makeDescription(for: fixture, codec: .h264)
        let factory = RecordingVideoSessionFactory(decodeError: kVTVideoDecoderBadDataErr)
        let events = VideoDecoderEventStore()
        let decoder = try VideoDecoder(factory: factory, eventSink: events.append)
        _ = try await decoder.replaceSession(formatDescription: description, bitDepth: .eight)

        await XCTAssertThrowsErrorAsync(
            try await decoder.decode(CompressedVideoSample(
                frameID: 7,
                accessUnit: try Data(spacedVideoHex: fixture.accessUnitHex)
            ))
        ) { error in
            XCTAssertEqual(error as? VideoDecoderError, .decodeFailed(kVTVideoDecoderBadDataErr))
        }
        XCTAssertEqual(
            events.failures.last,
            VideoDecoderFailure(
                generation: 1,
                frameID: 7,
                error: .decodeFailed(kVTVideoDecoderBadDataErr)
            )
        )
        await decoder.stop()
    }

    func testCallbackErrorDropAndMissingBufferRemainStructured() async throws {
        let fixture = try loadFixture().h264
        let description = try makeDescription(for: fixture, codec: .h264)
        let factory = RecordingVideoSessionFactory()
        let events = VideoDecoderEventStore()
        let decoder = try VideoDecoder(factory: factory, eventSink: events.append)
        _ = try await decoder.replaceSession(formatDescription: description, bitDepth: .eight)
        let session = try XCTUnwrap(factory.sessions.first)

        session.emit(frameID: 1, status: kVTVideoDecoderBadDataErr)
        session.emit(frameID: 2, infoFlags: [.frameDropped])
        session.emit(frameID: 3)
        try await events.waitForEventCount(4)

        XCTAssertTrue(events.failures.contains(VideoDecoderFailure(
            generation: 1,
            frameID: 1,
            error: .callbackFailed(kVTVideoDecoderBadDataErr)
        )))
        XCTAssertTrue(events.failures.contains(VideoDecoderFailure(
            generation: 1,
            frameID: 3,
            error: .callbackMissingImageBuffer
        )))
        XCTAssertEqual(events.droppedFrameIDs, [2])
        await decoder.stop()
    }

    func testMalformedEmptyAndOversizedSamplesFailBeforeSessionDecode() async throws {
        let fixture = try loadFixture().h264
        let description = try makeDescription(for: fixture, codec: .h264)
        let limits = AnnexBNALParserLimits(
            maximumAccessUnitBytes: 32,
            maximumNALUnitBytes: 32,
            maximumNALUnitCount: 8,
            maximumParameterSetBytes: 32
        )
        let factory = RecordingVideoSessionFactory()
        let decoder = try VideoDecoder(
            factory: factory,
            sampleBufferFactory: VideoSampleBufferFactory(limits: limits)
        )
        _ = try await decoder.replaceSession(formatDescription: description, bitDepth: .eight)

        for (frameID, data, expected) in [
            (UInt64(1), Data(), VideoDecoderError.emptyAccessUnit),
            (UInt64(2), Data(repeating: 0, count: 33), .accessUnitTooLarge),
            (UInt64(3), Data([0x65, 0x80]), .annexB(.missingAnnexBStartCode))
        ] {
            await XCTAssertThrowsErrorAsync(
                try await decoder.decode(CompressedVideoSample(frameID: frameID, accessUnit: data))
            ) { error in
                XCTAssertEqual(error as? VideoDecoderError, expected)
            }
        }
        XCTAssertEqual(try XCTUnwrap(factory.sessions.first).decodeCount, 0)
        await decoder.stop()
    }

    func testHardwareSessionCreationFailureIsStructuredAndLeavesNoActiveSession() async throws {
        let fixture = try loadFixture().h264
        let description = try makeDescription(for: fixture, codec: .h264)
        let events = VideoDecoderEventStore()
        let decoder = try VideoDecoder(
            factory: RecordingVideoSessionFactory(creationError: .sessionCreationFailed(-1234)),
            eventSink: events.append
        )

        await XCTAssertThrowsErrorAsync(
            try await decoder.replaceSession(formatDescription: description, bitDepth: .eight)
        ) { error in
            XCTAssertEqual(error as? VideoDecoderError, .sessionCreationFailed(-1234))
        }
        await XCTAssertThrowsErrorAsync(
            try await decoder.decode(CompressedVideoSample(frameID: 1, accessUnit: Data([1])))
        ) { error in
            XCTAssertEqual(error as? VideoDecoderError, .noActiveSession)
        }
        XCTAssertEqual(
            events.failures,
            [VideoDecoderFailure(
                generation: 1,
                frameID: nil,
                error: .sessionCreationFailed(-1234)
            )]
        )
    }

    func testDecoderDeinitFinishesOwnedSession() async throws {
        let fixture = try loadFixture().h264
        let description = try makeDescription(for: fixture, codec: .h264)
        let factory = RecordingVideoSessionFactory()
        var decoder: VideoDecoder? = try VideoDecoder(factory: factory)
        _ = try await decoder?.replaceSession(formatDescription: description, bitDepth: .eight)
        let session = try XCTUnwrap(factory.sessions.first)
        weak let weakDecoder = decoder

        decoder = nil
        let deadline = ContinuousClock.now + .seconds(1)
        while weakDecoder != nil, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertNil(weakDecoder)
        XCTAssertEqual(session.finishCount, 1)
    }

    private func assertProductionDecode(codec: NegotiatedVideoCodec) async throws {
        let fixture = try loadFixture().codec(codec)
        let description = try makeDescription(for: fixture, codec: codec)
        let events = VideoDecoderEventStore()
        let decoder = try VideoDecoder(eventSink: events.append)
        let bitDepth: VideoOutputBitDepth = codec == .hevc ? .ten : .eight
        let generation = try await decoder.replaceSession(
            formatDescription: description,
            bitDepth: bitDepth
        )
        let frameID = codec == .h264 ? UInt64(264) : UInt64(265)

        _ = try await decoder.decode(CompressedVideoSample(
            frameID: frameID,
            accessUnit: try Data(spacedVideoHex: fixture.accessUnitHex),
            presentationTimeStamp: CMTime(value: 1, timescale: 60),
            duration: CMTime(value: 1, timescale: 60)
        ))
        let frame = try await events.waitForFrame(frameID: frameID)
        XCTAssertEqual(frame.generation, generation)
        XCTAssertEqual(CVPixelBufferGetWidth(frame.pixelBuffer), 64)
        XCTAssertEqual(CVPixelBufferGetHeight(frame.pixelBuffer), 64)
        XCTAssertEqual(
            CVPixelBufferGetPixelFormatType(frame.pixelBuffer),
            bitDepth.pixelFormat
        )
        XCTAssertEqual(frame.presentationTimeStamp, CMTime(value: 1, timescale: 60))
        await decoder.stop()
    }

    private func makeDescription(
        for fixture: VideoDecoderFixture.Codec,
        codec: NegotiatedVideoCodec
    ) throws -> CMVideoFormatDescription {
        let parser = try VideoParameterSetParser()
        let parameterSets = try parser.parse(
            Data(spacedVideoHex: fixture.accessUnitHex),
            codec: codec
        )
        return try VideoFormatDescriptionFactory.make(from: parameterSets)
    }

    private func compressedBytes(from sample: CMSampleBuffer) throws -> Data {
        let blockBuffer = try XCTUnwrap(CMSampleBufferGetDataBuffer(sample))
        let length = CMBlockBufferGetDataLength(blockBuffer)
        var bytes = [UInt8](repeating: 0, count: length)
        let status = CMBlockBufferCopyDataBytes(
            blockBuffer,
            atOffset: 0,
            dataLength: length,
            destination: &bytes
        )
        XCTAssertEqual(status, kCMBlockBufferNoErr)
        return Data(bytes)
    }

    private func independentlyLengthPrefix(_ annexB: Data) throws -> Data {
        let units = try VideoParameterSetParser().splitNALUnits(annexB)
        return units.reduce(into: Data()) { result, unit in
            let length = UInt32(unit.count)
            result.append(contentsOf: [
                UInt8(truncatingIfNeeded: length >> 24),
                UInt8(truncatingIfNeeded: length >> 16),
                UInt8(truncatingIfNeeded: length >> 8),
                UInt8(truncatingIfNeeded: length)
            ])
            result.append(unit)
        }
    }

    private func loadFixture() throws -> VideoDecoderFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/video/parameter-sets.json")
        return try JSONDecoder().decode(VideoDecoderFixture.self, from: Data(contentsOf: url))
    }
}

private final class RecordingVideoSessionFactory: VideoDecompressionSessionCreating, @unchecked Sendable {
    private let lock = NSLock()
    private let creationError: VideoDecoderError?
    private let decodeError: OSStatus?
    private var storedSessions: [RecordingVideoSession] = []

    var sessions: [RecordingVideoSession] {
        lock.withLock { storedSessions }
    }

    init(creationError: VideoDecoderError? = nil, decodeError: OSStatus? = nil) {
        self.creationError = creationError
        self.decodeError = decodeError
    }

    func makeSession(
        formatDescription _: CMVideoFormatDescription,
        bitDepth _: VideoOutputBitDepth,
        callbackBridge: VideoDecompressionCallbackBridge
    ) throws -> any VideoDecompressionSessionOwning {
        if let creationError { throw creationError }
        let session = RecordingVideoSession(
            callbackBridge: callbackBridge,
            decodeError: decodeError
        )
        lock.withLock {
            storedSessions.append(session)
        }
        return session
    }
}

private final class RecordingVideoSession: VideoDecompressionSessionOwning, @unchecked Sendable {
    private let callbackBridge: VideoDecompressionCallbackBridge
    private let decodeError: OSStatus?
    private let lock = NSLock()
    private var storedDecodeCount = 0
    private var storedFinishCount = 0

    var decodeCount: Int { lock.withLock { storedDecodeCount } }
    var finishCount: Int { lock.withLock { storedFinishCount } }

    init(callbackBridge: VideoDecompressionCallbackBridge, decodeError: OSStatus?) {
        self.callbackBridge = callbackBridge
        self.decodeError = decodeError
    }

    func decode(
        _: CMSampleBuffer,
        generation _: UInt64,
        frameID _: UInt64
    ) -> Result<VideoDecodeSubmission, VideoDecoderError> {
        lock.withLock { storedDecodeCount += 1 }
        if let decodeError {
            return .failure(.decodeFailed(decodeError))
        }
        return .success(VideoDecodeSubmission(infoFlags: []))
    }

    func finishAndInvalidate() -> [VideoDecoderError] {
        lock.withLock { storedFinishCount += 1 }
        return []
    }

    func emit(
        frameID: UInt64,
        status: OSStatus = noErr,
        infoFlags: VTDecodeInfoFlags = [],
        pixelBuffer: CVPixelBuffer? = nil
    ) {
        callbackBridge.forward(VideoDecompressionOutput(
            generation: callbackBridge.generation,
            frameID: frameID,
            status: status,
            infoFlags: infoFlags,
            imageBuffer: pixelBuffer,
            presentationTimeStamp: .invalid,
            duration: .invalid
        ))
    }
}

private final class VideoDecoderEventStore: @unchecked Sendable {
    private let lock = NSLock()
    private var storedEvents: [VideoDecoderEvent] = []

    var failures: [VideoDecoderFailure] {
        lock.withLock {
            storedEvents.compactMap {
                guard case let .failure(failure) = $0 else { return nil }
                return failure
            }
        }
    }

    var frameIDs: [UInt64] {
        lock.withLock {
            storedEvents.compactMap {
                guard case let .frame(frame) = $0 else { return nil }
                return frame.frameID
            }
        }
    }

    var droppedFrameIDs: [UInt64] {
        lock.withLock {
            storedEvents.compactMap {
                guard case let .frameDropped(_, frameID, _) = $0 else { return nil }
                return frameID
            }
        }
    }

    func append(_ event: VideoDecoderEvent) {
        lock.withLock {
            storedEvents.append(event)
        }
    }

    func waitForFrame(
        frameID: UInt64,
        timeout: Duration = .seconds(2)
    ) async throws -> DecodedVideoFrame {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if let frame = lock.withLock({
                let frames: [DecodedVideoFrame] = storedEvents.compactMap {
                    guard case let .frame(frame) = $0 else { return nil }
                    return frame
                }
                return frames.first(where: { $0.frameID == frameID })
            }) {
                return frame
            }
            if let failure = failures.first(where: { $0.frameID == frameID }) {
                throw failure.error
            }
            if droppedFrameIDs.contains(frameID) {
                throw VideoDecoderTestError.frameDropped
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw VideoDecoderTestError.timedOut
    }

    func waitForEventCount(_ count: Int, timeout: Duration = .seconds(2)) async throws {
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline {
            if lock.withLock({ storedEvents.count >= count }) { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw VideoDecoderTestError.timedOut
    }
}

private struct VideoDecoderFixture: Decodable {
    struct Codec: Decodable {
        var accessUnitHex: String
        var pictureParameterSetHex: String
        var sequenceParameterSetHex: String
        var videoParameterSetHex: String?
    }

    var h264: Codec
    var hevc: Codec

    func codec(_ codec: NegotiatedVideoCodec) throws -> Codec {
        switch codec {
        case .h264: return h264
        case .hevc: return hevc
        case .av1: throw VideoDecoderTestError.unsupportedFixture
        }
    }
}

private enum VideoDecoderTestError: Error {
    case frameDropped
    case invalidHex
    case timedOut
    case unsupportedFixture
}

private func makePixelBuffer() throws -> CVPixelBuffer {
    var pixelBuffer: CVPixelBuffer?
    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        64,
        64,
        kCVPixelFormatType_32BGRA,
        nil,
        &pixelBuffer
    )
    guard status == kCVReturnSuccess, let pixelBuffer else {
        throw VideoDecoderTestError.timedOut
    }
    return pixelBuffer
}

private extension Data {
    init(spacedVideoHex: String) throws {
        let fields = spacedVideoHex.split(whereSeparator: \Character.isWhitespace)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(fields.count)
        for field in fields {
            guard field.count == 2, let byte = UInt8(field, radix: 16) else {
                throw VideoDecoderTestError.invalidHex
            }
            bytes.append(byte)
        }
        self.init(bytes)
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected expression to throw")
    } catch {
        errorHandler(error)
    }
}
