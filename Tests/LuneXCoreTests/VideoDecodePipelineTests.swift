@preconcurrency import CoreMedia
@preconcurrency import CoreVideo
import Dispatch
import Foundation
@preconcurrency import VideoToolbox
import XCTest

final class VideoDecodePipelineTests: XCTestCase {
    func testInitialAndRepeatedIDRReuseTheSameDecoderSession() async throws {
        let fixture = try loadFixture()
        let requester = PipelineIDRRequester()
        let factory = PipelineSessionFactory()
        let pipeline = try makePipeline(
            codec: .h264,
            colorMetadata: .rec709VideoRange(),
            requester: requester,
            factory: factory
        )

        let first = try await pipeline.consume(.accessUnit(try accessUnit(
            frameIndex: 1,
            codec: .h264,
            frameType: .instantaneousDecoderRefresh,
            payloadHex: fixture.h264.accessUnitHex
        )))
        let second = try await pipeline.consume(.accessUnit(try accessUnit(
            frameIndex: 2,
            codec: .h264,
            frameType: .instantaneousDecoderRefresh,
            payloadHex: fixture.h264.accessUnitHex
        )))

        XCTAssertEqual(first, .submitted(frameIndex: 1, generation: 1, replacedSession: true))
        XCTAssertEqual(second, .submitted(frameIndex: 2, generation: 1, replacedSession: false))
        XCTAssertEqual(factory.sessions.count, 1)
        XCTAssertEqual(factory.sessions.first?.decodeCount, 2)
        let requesterCount = await requester.count
        XCTAssertEqual(requesterCount, 0)
        let snapshot = await pipeline.snapshot()
        XCTAssertEqual(snapshot.activeDecoderGeneration, 1)
        XCTAssertEqual(snapshot.sessionCreationCount, 1)
        XCTAssertEqual(snapshot.decoderResetCount, 0)
        XCTAssertEqual(snapshot.formatChangeCount, 0)
        await pipeline.stop()
    }

    func testParameterSetChangeDrainsOldGenerationBeforeStartingNewSession() async throws {
        let fixture = try loadFixture()
        let requester = PipelineIDRRequester()
        let factory = PipelineSessionFactory()
        let events = PipelineDecoderEventRecorder()
        let pipeline = try makePipeline(
            codec: .h264,
            colorMetadata: .rec709VideoRange(),
            requester: requester,
            factory: factory,
            eventSink: events.append
        )
        _ = try await pipeline.consume(.accessUnit(try accessUnit(
            frameIndex: 1,
            codec: .h264,
            frameType: .instantaneousDecoderRefresh,
            payloadHex: fixture.h264.accessUnitHex
        )))

        let changed = try await pipeline.consume(.accessUnit(try accessUnit(
            frameIndex: 2,
            codec: .h264,
            frameType: .instantaneousDecoderRefresh,
            payloadHex: try fixture.h264.requiredFormatChangeAccessUnitHex
        )))

        XCTAssertEqual(changed, .submitted(frameIndex: 2, generation: 2, replacedSession: true))
        XCTAssertEqual(factory.sessions.count, 2)
        XCTAssertEqual(factory.sessions[0].finishCount, 1)
        XCTAssertEqual(
            factory.createdDimensions.map(\.width),
            [fixture.h264.expectedWidth, try fixture.h264.requiredFormatChangeExpectedWidth]
        )
        XCTAssertEqual(
            factory.createdDimensions.map(\.height),
            [fixture.h264.expectedHeight, try fixture.h264.requiredFormatChangeExpectedHeight]
        )
        XCTAssertEqual(events.lifecycle, ["start:1", "stop:1", "start:2"])
        let snapshot = await pipeline.snapshot()
        XCTAssertEqual(snapshot.activeDecoderGeneration, 2)
        XCTAssertEqual(snapshot.sessionCreationCount, 2)
        XCTAssertEqual(snapshot.decoderResetCount, 1)
        XCTAssertEqual(snapshot.formatChangeCount, 1)
        await pipeline.stop()
    }

    func testPacketLossCoalescesIDRAndDropsPredictedFramesUntilRecovery() async throws {
        let fixture = try loadFixture()
        let requester = PipelineIDRRequester()
        let factory = PipelineSessionFactory()
        let pipeline = try makePipeline(
            codec: .h264,
            colorMetadata: .rec709VideoRange(),
            requester: requester,
            factory: factory
        )
        _ = try await pipeline.consume(.accessUnit(try accessUnit(
            frameIndex: 1,
            codec: .h264,
            frameType: .instantaneousDecoderRefresh,
            payloadHex: fixture.h264.accessUnitHex
        )))
        let loss = VideoFrameLoss(
            firstFrameIndex: 2,
            lastFrameIndex: 3,
            reason: .superseded,
            requiresIDR: true
        )

        let firstLossResult = try await pipeline.consume(.frameLost(loss))
        let duplicateLossResult = try await pipeline.consume(.frameLost(loss))
        XCTAssertEqual(firstLossResult, .recoveryRequested(.packetLoss(.superseded)))
        XCTAssertEqual(duplicateLossResult, .recoveryRequested(.packetLoss(.superseded)))
        let predicted = try await pipeline.consume(.accessUnit(try accessUnit(
            frameIndex: 4,
            codec: .h264,
            frameType: .predicted,
            payloadHex: fixture.h264.accessUnitHex
        )))

        XCTAssertEqual(predicted, .dropped(frameIndex: 4, reason: .awaitingIDR))
        let requestCountBeforeRecovery = await requester.count
        XCTAssertEqual(requestCountBeforeRecovery, 1)
        XCTAssertEqual(factory.sessions[0].finishCount, 1)

        let recovered = try await pipeline.consume(.accessUnit(try accessUnit(
            frameIndex: 5,
            codec: .h264,
            frameType: .instantaneousDecoderRefresh,
            payloadHex: fixture.h264.accessUnitHex
        )))
        XCTAssertEqual(recovered, .submitted(frameIndex: 5, generation: 2, replacedSession: true))
        let snapshot = await pipeline.snapshot()
        XCTAssertFalse(snapshot.isAwaitingIDR)
        XCTAssertFalse(snapshot.hasOutstandingIDRRequest)
        XCTAssertEqual(snapshot.idrRequestCount, 1)
        XCTAssertEqual(snapshot.droppedAccessUnitCount, 1)
        XCTAssertEqual(snapshot.decoderResetCount, 1)
        await pipeline.stop()
    }

    func testColorMetadataChangeRebuildsHEVCGenerationOnNextIDR() async throws {
        let fixture = try loadFixture()
        let requester = PipelineIDRRequester()
        let factory = PipelineSessionFactory()
        let pipeline = try makePipeline(
            codec: .hevc,
            colorMetadata: .rec709VideoRange(bitDepth: 10),
            requester: requester,
            factory: factory
        )
        _ = try await pipeline.consume(.accessUnit(try accessUnit(
            frameIndex: 10,
            codec: .hevc,
            frameType: .instantaneousDecoderRefresh,
            payloadHex: fixture.hevc.accessUnitHex
        )))

        let metadataUpdate = try await pipeline.updateColorMetadata(.hdr10VideoRange())
        XCTAssertEqual(metadataUpdate, .recoveryRequested(.colorMetadataChanged))
        let recovered = try await pipeline.consume(.accessUnit(try accessUnit(
            frameIndex: 11,
            codec: .hevc,
            frameType: .instantaneousDecoderRefresh,
            payloadHex: fixture.hevc.accessUnitHex
        )))

        XCTAssertEqual(recovered, .submitted(frameIndex: 11, generation: 2, replacedSession: true))
        XCTAssertEqual(factory.sessions.count, 2)
        XCTAssertEqual(factory.sessions[0].finishCount, 1)
        XCTAssertEqual(factory.createdBitDepths, [.ten, .ten])
        let requestCount = await requester.count
        XCTAssertEqual(requestCount, 1)
        let snapshot = await pipeline.snapshot()
        XCTAssertEqual(snapshot.colorMetadataChangeCount, 1)
        XCTAssertEqual(snapshot.decoderResetCount, 1)
        await pipeline.stop()
    }

    func testDecoderDropStopsGenerationAndRequestsOneIDR() async throws {
        let fixture = try loadFixture()
        let requester = PipelineIDRRequester()
        let factory = PipelineSessionFactory()
        let pipeline = try makePipeline(
            codec: .h264,
            colorMetadata: .rec709VideoRange(),
            requester: requester,
            factory: factory
        )
        _ = try await pipeline.consume(.accessUnit(try accessUnit(
            frameIndex: 20,
            codec: .h264,
            frameType: .instantaneousDecoderRefresh,
            payloadHex: fixture.h264.accessUnitHex
        )))
        factory.sessions[0].emit(frameID: 20, infoFlags: [.frameDropped])

        try await waitUntil {
            let snapshot = await pipeline.snapshot()
            let requestCount = await requester.count
            return snapshot.decoderDroppedFrameCount == 1
                && snapshot.activeDecoderGeneration == nil
                && snapshot.isAwaitingIDR
                && snapshot.hasOutstandingIDRRequest
                && snapshot.idrRequestCount == 1
                && requestCount == 1
        }
        let snapshot = await pipeline.snapshot()
        XCTAssertNil(snapshot.activeDecoderGeneration)
        XCTAssertTrue(snapshot.isAwaitingIDR)
        XCTAssertTrue(snapshot.hasOutstandingIDRRequest)
        XCTAssertEqual(snapshot.idrRequestCount, 1)
        XCTAssertEqual(factory.sessions[0].finishCount, 1)
        let requestCount = await requester.count
        XCTAssertEqual(requestCount, 1)
        await pipeline.stop()
    }

    func testStopIsIdempotentAndLateDecoderCallbackCannotRestartRecovery() async throws {
        let fixture = try loadFixture()
        let requester = PipelineIDRRequester()
        let factory = PipelineSessionFactory()
        let pipeline = try makePipeline(
            codec: .h264,
            colorMetadata: .rec709VideoRange(),
            requester: requester,
            factory: factory
        )
        _ = try await pipeline.consume(.accessUnit(try accessUnit(
            frameIndex: 30,
            codec: .h264,
            frameType: .instantaneousDecoderRefresh,
            payloadHex: fixture.h264.accessUnitHex
        )))
        let oldSession = factory.sessions[0]

        await pipeline.stop()
        await pipeline.stop()
        oldSession.emit(frameID: 30, infoFlags: [.frameDropped])
        try await Task.sleep(for: .milliseconds(30))

        XCTAssertEqual(oldSession.finishCount, 1)
        let requestCount = await requester.count
        XCTAssertEqual(requestCount, 0)
        let snapshot = await pipeline.snapshot()
        XCTAssertTrue(snapshot.isStopped)
        XCTAssertNil(snapshot.activeDecoderGeneration)
        XCTAssertEqual(snapshot.teardownCount, 1)
        await PipelineXCTAssertThrowsErrorAsync(
            try await pipeline.consume(.packetDiscarded(.duplicate))
        ) { error in
            XCTAssertEqual(error as? VideoDecodePipelineError, .stopped)
        }
    }

    func testStopWinsWhileIDRRequestIsSuspended() async throws {
        let fixture = try loadFixture()
        let requester = SuspendedPipelineIDRRequester()
        let factory = PipelineSessionFactory()
        let pipeline = try makePipeline(
            codec: .h264,
            colorMetadata: .rec709VideoRange(),
            requester: requester,
            factory: factory
        )
        _ = try await pipeline.consume(.accessUnit(try accessUnit(
            frameIndex: 40,
            codec: .h264,
            frameType: .instantaneousDecoderRefresh,
            payloadHex: fixture.h264.accessUnitHex
        )))
        let loss = VideoFrameLoss(
            firstFrameIndex: 41,
            lastFrameIndex: 41,
            reason: .assemblyTimedOut,
            requiresIDR: true
        )
        let recovery = Task {
            try await pipeline.consume(.frameLost(loss))
        }
        try await waitUntil {
            await requester.count == 1
        }

        await pipeline.stop()
        await requester.resume()
        let recoveryResult = try await recovery.value

        XCTAssertEqual(
            recoveryResult,
            .recoveryRequested(.packetLoss(.assemblyTimedOut))
        )
        XCTAssertEqual(factory.sessions[0].finishCount, 1)
        let snapshot = await pipeline.snapshot()
        XCTAssertTrue(snapshot.isStopped)
        XCTAssertNil(snapshot.activeDecoderGeneration)
        XCTAssertFalse(snapshot.hasOutstandingIDRRequest)
        XCTAssertEqual(snapshot.teardownCount, 1)
    }

    func testStopWinsWhileDecoderSessionCreationIsSuspended() async throws {
        let fixture = try loadFixture()
        let requester = PipelineIDRRequester()
        let factory = SuspendedPipelineSessionFactory()
        let pipeline = try makePipeline(
            codec: .h264,
            colorMetadata: .rec709VideoRange(),
            requester: requester,
            factory: factory
        )
        let idr = try accessUnit(
            frameIndex: 50,
            codec: .h264,
            frameType: .instantaneousDecoderRefresh,
            payloadHex: fixture.h264.accessUnitHex
        )
        let submission = Task {
            try await pipeline.consume(.accessUnit(idr))
        }
        try await waitUntil { factory.hasEnteredCreation }
        let stop = Task { await pipeline.stop() }
        try await waitUntil {
            let snapshot = await pipeline.snapshot()
            return snapshot.isStopped
        }

        factory.resumeCreation()
        await stop.value
        await PipelineXCTAssertThrowsErrorAsync(try await submission.value) { error in
            XCTAssertEqual(error as? VideoDecodePipelineError, .stopped)
        }

        let snapshot = await pipeline.snapshot()
        XCTAssertTrue(snapshot.isStopped)
        XCTAssertNil(snapshot.activeDecoderGeneration)
        XCTAssertEqual(snapshot.sessionCreationCount, 0)
        XCTAssertEqual(snapshot.teardownCount, 1)
        XCTAssertEqual(factory.sessions.first?.finishCount, 1)
    }

    func testSessionControlIDRRequesterRoutesTheExactSession() async throws {
        let provider = PipelineSessionControlProvider()
        let sessionID = UUID()
        let requester = SessionControlVideoIDRRequester(
            sessionID: sessionID,
            provider: provider
        )

        try await requester.requestIDR()

        let requestedSessions = await provider.requestedSessions
        XCTAssertEqual(requestedSessions, [sessionID])
    }

    func testIDRRequestFailureClearsOutstandingStateAndAllowsRetry() async throws {
        let requester = FailingPipelineIDRRequester()
        let factory = PipelineSessionFactory()
        let pipeline = try makePipeline(
            codec: .h264,
            colorMetadata: .rec709VideoRange(),
            requester: requester,
            factory: factory
        )
        let loss = VideoFrameLoss(
            firstFrameIndex: 1,
            lastFrameIndex: 1,
            reason: .assemblyTimedOut,
            requiresIDR: true
        )

        await PipelineXCTAssertThrowsErrorAsync(
            try await pipeline.consume(.frameLost(loss))
        ) { error in
            XCTAssertEqual(error as? PipelineIDRRequestError, .syntheticFailure)
        }
        var snapshot = await pipeline.snapshot()
        XCTAssertTrue(snapshot.isAwaitingIDR)
        XCTAssertFalse(snapshot.hasOutstandingIDRRequest)
        XCTAssertEqual(snapshot.idrRequestCount, 1)
        XCTAssertEqual(snapshot.idrRequestFailureCount, 1)

        let retry = try await pipeline.consume(.frameLost(loss))
        XCTAssertEqual(retry, .recoveryRequested(.packetLoss(.assemblyTimedOut)))
        snapshot = await pipeline.snapshot()
        XCTAssertTrue(snapshot.hasOutstandingIDRRequest)
        XCTAssertEqual(snapshot.idrRequestCount, 2)
        XCTAssertEqual(snapshot.idrRequestFailureCount, 1)
        await pipeline.stop()
    }

    private func makePipeline(
        codec: NegotiatedVideoCodec,
        colorMetadata: VideoColorMetadata,
        requester: any VideoIDRRequesting,
        factory: any VideoDecompressionSessionCreating,
        eventSink: @escaping VideoDecodePipeline.DecoderEventSink = { _ in }
    ) throws -> VideoDecodePipeline {
        try VideoDecodePipeline.make(
            configuration: NegotiatedVideoStreamConfiguration(
                codec: codec,
                width: 3_840,
                height: 2_160,
                frameRate: 60,
                colorMetadata: colorMetadata,
                maximumPacketSize: 1_400
            ),
            idrRequester: requester,
            decoderFactory: factory,
            decoderEventSink: eventSink
        )
    }

    private func accessUnit(
        frameIndex: UInt32,
        codec: NegotiatedVideoCodec,
        frameType: SunshineVideoFrameType,
        payloadHex: String
    ) throws -> VideoAccessUnit {
        VideoAccessUnit(
            frameIndex: frameIndex,
            rtpTimestamp: frameIndex &* 1_500,
            codec: codec,
            frameType: frameType,
            hostProcessingLatencyTenthsOfMillisecond: 10,
            firstReceiveTimeNanoseconds: UInt64(frameIndex) * 1_000,
            lastReceiveTimeNanoseconds: UInt64(frameIndex) * 1_000 + 100,
            packetCount: 1,
            payload: try Data(spacedPipelineHex: payloadHex)
        )
    }

    private func loadFixture() throws -> PipelineVideoFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/video/parameter-sets.json")
        return try JSONDecoder().decode(PipelineVideoFixture.self, from: Data(contentsOf: url))
    }

    private func waitUntil(
        _ predicate: @escaping @Sendable () async -> Bool
    ) async throws {
        let deadline = ContinuousClock.now + .seconds(1)
        while ContinuousClock.now < deadline {
            if await predicate() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        throw PipelineTestError.timedOut
    }
}

private actor PipelineIDRRequester: VideoIDRRequesting {
    private(set) var count = 0

    func requestIDR() async throws {
        count += 1
    }
}

private actor SuspendedPipelineIDRRequester: VideoIDRRequesting {
    private(set) var count = 0
    private var continuation: CheckedContinuation<Void, Never>?

    func requestIDR() async throws {
        count += 1
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func resume() {
        continuation?.resume()
        continuation = nil
    }
}

private actor FailingPipelineIDRRequester: VideoIDRRequesting {
    private var shouldFail = true

    func requestIDR() async throws {
        if shouldFail {
            shouldFail = false
            throw PipelineIDRRequestError.syntheticFailure
        }
    }
}

private actor PipelineSessionControlProvider: SessionControlProvider {
    private(set) var requestedSessions: [UUID] = []

    func start(
        sessionID _: UUID,
        request _: StreamLaunchRequest
    ) async -> AsyncThrowingStream<SessionControlEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.finish()
        }
    }

    func requestIDR(sessionID: UUID) async throws {
        requestedSessions.append(sessionID)
    }

    func stop(sessionID _: UUID) async {}
}

private final class PipelineSessionFactory: VideoDecompressionSessionCreating, @unchecked Sendable {
    private let lock = NSLock()
    private var storedSessions: [PipelineSession] = []
    private var storedDimensions: [CMVideoDimensions] = []
    private var storedBitDepths: [VideoOutputBitDepth] = []

    var sessions: [PipelineSession] { lock.withLock { storedSessions } }
    var createdDimensions: [CMVideoDimensions] { lock.withLock { storedDimensions } }
    var createdBitDepths: [VideoOutputBitDepth] { lock.withLock { storedBitDepths } }

    func makeSession(
        formatDescription: CMVideoFormatDescription,
        bitDepth: VideoOutputBitDepth,
        callbackBridge: VideoDecompressionCallbackBridge
    ) throws -> any VideoDecompressionSessionOwning {
        let session = PipelineSession(callbackBridge: callbackBridge)
        lock.withLock {
            storedSessions.append(session)
            storedDimensions.append(CMVideoFormatDescriptionGetDimensions(formatDescription))
            storedBitDepths.append(bitDepth)
        }
        return session
    }
}

private final class SuspendedPipelineSessionFactory: VideoDecompressionSessionCreating, @unchecked Sendable {
    private let lock = NSLock()
    private let resumeSemaphore = DispatchSemaphore(value: 0)
    private var enteredCreation = false
    private var storedSessions: [PipelineSession] = []

    var hasEnteredCreation: Bool { lock.withLock { enteredCreation } }
    var sessions: [PipelineSession] { lock.withLock { storedSessions } }

    func makeSession(
        formatDescription _: CMVideoFormatDescription,
        bitDepth _: VideoOutputBitDepth,
        callbackBridge: VideoDecompressionCallbackBridge
    ) throws -> any VideoDecompressionSessionOwning {
        lock.withLock { enteredCreation = true }
        resumeSemaphore.wait()
        let session = PipelineSession(callbackBridge: callbackBridge)
        lock.withLock { storedSessions.append(session) }
        return session
    }

    func resumeCreation() {
        resumeSemaphore.signal()
    }
}

private final class PipelineSession: VideoDecompressionSessionOwning, @unchecked Sendable {
    private let callbackBridge: VideoDecompressionCallbackBridge
    private let lock = NSLock()
    private var storedDecodeCount = 0
    private var storedFinishCount = 0

    var decodeCount: Int { lock.withLock { storedDecodeCount } }
    var finishCount: Int { lock.withLock { storedFinishCount } }

    init(callbackBridge: VideoDecompressionCallbackBridge) {
        self.callbackBridge = callbackBridge
    }

    func decode(
        _: CMSampleBuffer,
        generation _: UInt64,
        frameID _: UInt64
    ) -> Result<VideoDecodeSubmission, VideoDecoderError> {
        lock.withLock { storedDecodeCount += 1 }
        return .success(VideoDecodeSubmission(infoFlags: []))
    }

    func finishAndInvalidate() -> [VideoDecoderError] {
        lock.withLock { storedFinishCount += 1 }
        callbackBridge.detach()
        return []
    }

    func emit(frameID: UInt64, infoFlags: VTDecodeInfoFlags) {
        callbackBridge.forward(VideoDecompressionOutput(
            generation: callbackBridge.generation,
            frameID: frameID,
            status: noErr,
            infoFlags: infoFlags,
            imageBuffer: nil,
            presentationTimeStamp: .invalid,
            duration: .invalid
        ))
    }
}

private final class PipelineDecoderEventRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedLifecycle: [String] = []

    var lifecycle: [String] { lock.withLock { storedLifecycle } }

    func append(_ event: VideoDecoderEvent) {
        lock.withLock {
            switch event {
            case let .sessionStarted(generation, _):
                storedLifecycle.append("start:\(generation)")
            case let .sessionStopped(generation):
                storedLifecycle.append("stop:\(generation)")
            case .frame, .frameDropped, .failure:
                break
            }
        }
    }
}

private struct PipelineVideoFixture: Decodable {
    struct Codec: Decodable {
        var accessUnitHex: String
        var expectedHeight: Int32
        var expectedWidth: Int32
        var formatChangeAccessUnitHex: String?
        var formatChangeExpectedHeight: Int32?
        var formatChangeExpectedWidth: Int32?
    }

    var h264: Codec
    var hevc: Codec
}

private extension PipelineVideoFixture.Codec {
    var requiredFormatChangeAccessUnitHex: String {
        get throws {
            guard let formatChangeAccessUnitHex else {
                throw PipelineTestError.missingFormatChangeFixture
            }
            return formatChangeAccessUnitHex
        }
    }

    var requiredFormatChangeExpectedHeight: Int32 {
        get throws {
            guard let formatChangeExpectedHeight else {
                throw PipelineTestError.missingFormatChangeFixture
            }
            return formatChangeExpectedHeight
        }
    }

    var requiredFormatChangeExpectedWidth: Int32 {
        get throws {
            guard let formatChangeExpectedWidth else {
                throw PipelineTestError.missingFormatChangeFixture
            }
            return formatChangeExpectedWidth
        }
    }
}

private extension Data {
    init(spacedPipelineHex: String) throws {
        let parts = spacedPipelineHex.split(whereSeparator: \.isWhitespace)
        guard parts.allSatisfy({ $0.count == 2 }) else {
            throw PipelineTestError.invalidHex
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(parts.count)
        for part in parts {
            guard let byte = UInt8(String(part), radix: 16) else {
                throw PipelineTestError.invalidHex
            }
            bytes.append(byte)
        }
        self = Data(bytes)
    }
}

private enum PipelineTestError: Error {
    case invalidHex
    case missingFormatChangeFixture
    case timedOut
}

private enum PipelineIDRRequestError: Error {
    case syntheticFailure
}

private func PipelineXCTAssertThrowsErrorAsync<T>(
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
