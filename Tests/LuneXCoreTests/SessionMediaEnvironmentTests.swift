@preconcurrency import CoreMedia
@preconcurrency import CoreVideo
import Foundation
import XCTest

final class SessionMediaEnvironmentTests: XCTestCase {
    func testUnifiedEnvironmentStartsEveryMediaOwnerAndTearsDownInReverseOrder() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let video = ControlledVideoReceiveProvider(calls: calls)
        let audio = ControlledAudioReceiveProvider(calls: calls)
        let input = ControlledRemoteInputProvider(calls: calls)
        let environment = makeEnvironment(
            calls: calls,
            video: video,
            audio: audio,
            input: input
        )
        let sessionID = UUID()
        let configuration = makeConfiguration(sessionID: sessionID)
        let stream = try await environment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: MediaEnvironmentControlProvider()
        )
        var iterator = stream.makeAsyncIterator()
        let readiness = try await iterator.next()
        XCTAssertEqual(readiness, .readiness([.input]))

        let active = await environment.snapshot()
        XCTAssertEqual(active.sessionID, sessionID)
        XCTAssertEqual(active.readiness, [.input])
        XCTAssertEqual(active.activeTaskCount, 3)
        XCTAssertEqual(active.activeResourceCount, 5)

        video.yield(.packet(ReceivedVideoPacket(
            sequenceNumber: 1,
            frameIndex: 1,
            rtpTimestamp: 90_000,
            receiveTimeNanoseconds: 10,
            isFirstPacket: true,
            isLastPacket: true,
            payload: Data([1])
        )), sessionID: sessionID)
        audio.yield(.packet(ReceivedAudioPacket(
            sequenceNumber: 2,
            timestamp: 240,
            receiveTimeNanoseconds: 11,
            payload: Data([2])
        )), sessionID: sessionID)
        await input.yield(
            .led(ControllerLEDFeedback(
                controllerID: "controller-1",
                red: 1,
                green: 2,
                blue: 3
            )),
            sessionID: sessionID
        )
        try await environment.sendInput(.keyboard(
            KeyboardInputEvent(
                rawKeyCode: 4,
                characters: nil,
                isDown: true,
                modifiers: [],
                isRepeat: false
            )
        ), sessionID: sessionID)
        await waitUntil {
            let snapshot = await environment.snapshot()
            return snapshot.readiness == [.video, .audio, .input]
        }
        var finalReadiness = SessionChannelReadiness.input
        var observedFeedback: RemoteInputFeedback?
        while finalReadiness != [.video, .audio, .input] || observedFeedback == nil {
            guard let event = try await iterator.next() else { break }
            switch event {
            case let .readiness(readiness):
                finalReadiness = readiness
            case let .feedback(feedback):
                observedFeedback = feedback
            }
        }
        XCTAssertEqual(finalReadiness, [.video, .audio, .input])
        XCTAssertEqual(observedFeedback, .led(ControllerLEDFeedback(
            controllerID: "controller-1",
            red: 1,
            green: 2,
            blue: 3
        )))

        let optionalReport = await environment.stop(sessionID: sessionID)
        let report = try XCTUnwrap(optionalReport)
        XCTAssertTrue(report.isClean)
        XCTAssertEqual(report.cancelledTaskCount, 3)
        XCTAssertEqual(report.stoppedResourceCount, 5)
        let ended = try await iterator.next()
        XCTAssertNil(ended)
        let values = await calls.values()
        XCTAssertEqual(Array(values.suffix(6)), [
            "input.release",
            "input.stop",
            "audio.processor.stop",
            "video.processor.stop",
            "audio.receiver.stop",
            "video.receiver.stop"
        ])
        XCTAssertTrue(values.contains("input.send"))

        let stopped = await environment.snapshot()
        XCTAssertNil(stopped.sessionID)
        XCTAssertEqual(stopped.lastTeardownReport, report)
    }

    func testProcessorCreationFailureRollsBackOnlyCreatedResources() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let video = ControlledVideoReceiveProvider(calls: calls)
        let audio = ControlledAudioReceiveProvider(calls: calls)
        let input = ControlledRemoteInputProvider(calls: calls)
        let environment = NativeSessionMediaEnvironment(
            videoReceiveProvider: video,
            audioReceiveProvider: audio,
            remoteInputProvider: input,
            videoProcessorFactory: RecordingVideoProcessorFactory(calls: calls),
            audioProcessorFactory: RecordingAudioProcessorFactory(
                calls: calls,
                failure: .processorCreation
            ),
            teardownGracePeriod: .seconds(1)
        )
        let sessionID = UUID()

        await XCTAssertThrowsErrorAsync(
            try await environment.start(
                sessionID: sessionID,
                configuration: makeConfiguration(sessionID: sessionID),
                controlProvider: MediaEnvironmentControlProvider()
            )
        ) { error in
            XCTAssertEqual(error as? MediaEnvironmentTestError, .processorCreation)
        }

        let snapshot = await environment.snapshot()
        XCTAssertNil(snapshot.sessionID)
        XCTAssertTrue(snapshot.lastTeardownReport?.isClean == true)
        XCTAssertEqual(snapshot.lastTeardownReport?.stoppedResourceCount, 3)
        let values = await calls.values()
        XCTAssertEqual(Array(values.suffix(3)), [
            "video.processor.stop",
            "audio.receiver.stop",
            "video.receiver.stop"
        ])
        XCTAssertFalse(values.contains("input.start"))
    }

    func testReceiverFailureFailsEventStreamAndReusesSingleCleanTeardown() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let video = ControlledVideoReceiveProvider(calls: calls)
        let audio = ControlledAudioReceiveProvider(calls: calls)
        let input = ControlledRemoteInputProvider(calls: calls)
        let environment = makeEnvironment(
            calls: calls,
            video: video,
            audio: audio,
            input: input
        )
        let sessionID = UUID()
        let stream = try await environment.start(
            sessionID: sessionID,
            configuration: makeConfiguration(sessionID: sessionID),
            controlProvider: MediaEnvironmentControlProvider()
        )
        var iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()

        video.finish(
            sessionID: sessionID,
            throwing: MediaEnvironmentTestError.receiverFailure
        )
        do {
            _ = try await iterator.next()
            XCTFail("A receiver failure must fail the unified media stream.")
        } catch {
            XCTAssertEqual(error as? MediaEnvironmentTestError, .receiverFailure)
        }
        let optionalFirstReport = await environment.stop(sessionID: sessionID)
        let firstReport = try XCTUnwrap(optionalFirstReport)
        let optionalDuplicateReport = await environment.stop(sessionID: sessionID)
        let duplicateReport = try XCTUnwrap(optionalDuplicateReport)
        XCTAssertEqual(firstReport, duplicateReport)
        XCTAssertTrue(firstReport.isClean)
        XCTAssertEqual(firstReport.stoppedResourceCount, 5)
        let values = await calls.values()
        XCTAssertEqual(values.filter { $0 == "video.receiver.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "audio.receiver.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "input.stop" }.count, 1)
    }

    func testStoppedGenerationRejectsLatePacketsAndAllowsFreshGeneration() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let video = ControlledVideoReceiveProvider(calls: calls)
        let audio = ControlledAudioReceiveProvider(calls: calls)
        let input = ControlledRemoteInputProvider(calls: calls)
        let environment = makeEnvironment(
            calls: calls,
            video: video,
            audio: audio,
            input: input
        )
        let sessionID = UUID()
        let configuration = makeConfiguration(sessionID: sessionID)
        let first = try await environment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: MediaEnvironmentControlProvider()
        )
        var firstIterator = first.makeAsyncIterator()
        _ = try await firstIterator.next()
        _ = await environment.stop(sessionID: sessionID)

        let second = try await environment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: MediaEnvironmentControlProvider()
        )
        var secondIterator = second.makeAsyncIterator()
        _ = try await secondIterator.next()
        video.yieldToStart(
            .packet(ReceivedVideoPacket(
                sequenceNumber: 99,
                frameIndex: 99,
                rtpTimestamp: 99,
                receiveTimeNanoseconds: 99,
                isFirstPacket: true,
                isLastPacket: true,
                payload: Data([99])
            )),
            startIndex: 0
        )
        for _ in 0..<50 { await Task.yield() }
        let valuesBeforeFreshPacket = await calls.values()
        XCTAssertEqual(valuesBeforeFreshPacket.filter { $0 == "video.consume" }.count, 0)

        video.yieldToStart(
            .packet(ReceivedVideoPacket(
                sequenceNumber: 100,
                frameIndex: 100,
                rtpTimestamp: 100,
                receiveTimeNanoseconds: 100,
                isFirstPacket: true,
                isLastPacket: true,
                payload: Data([100])
            )),
            startIndex: 1
        )
        await waitUntil {
            let values = await calls.values()
            return values.filter { $0 == "video.consume" }.count == 1
        }
        _ = await environment.stop(sessionID: sessionID)
    }

    func testLifecycleApplicationIsRevisionedAndGenerationScoped() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls)
        )
        let sessionID = UUID()
        let stream = try await environment.start(
            sessionID: sessionID,
            configuration: makeConfiguration(sessionID: sessionID),
            controlProvider: MediaEnvironmentControlProvider()
        )
        var iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        let generation = await environment.snapshot().generation
        let first = SessionLifecycleApplication(
            sessionID: sessionID,
            mediaGeneration: generation,
            lifecycleRevision: 4,
            directive: SessionLifecycleDirectiveResolver.resolve(
                isStreamActive: true,
                isVisible: false,
                isFocused: false,
                drawableSize: PixelSize(width: 1920, height: 1080)
            )
        )

        try await environment.applyLifecycle(first)
        try await environment.applyLifecycle(first)
        let firstSnapshot = await environment.snapshot()
        XCTAssertEqual(firstSnapshot.lifecycleApplication, first)

        var older = first
        older.lifecycleRevision = 3
        await XCTAssertThrowsErrorAsync(
            try await environment.applyLifecycle(older)
        ) { error in
            XCTAssertEqual(error as? SessionMediaEnvironmentError, .staleLifecycleApplication)
        }

        var conflicting = first
        conflicting.directive = SessionLifecycleDirectiveResolver.resolve(
            isStreamActive: true,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 1920, height: 1080)
        )
        await XCTAssertThrowsErrorAsync(
            try await environment.applyLifecycle(conflicting)
        ) { error in
            XCTAssertEqual(error as? SessionMediaEnvironmentError, .staleLifecycleApplication)
        }

        var current = conflicting
        current.lifecycleRevision = 5
        try await environment.applyLifecycle(current)
        let currentSnapshot = await environment.snapshot()
        XCTAssertEqual(currentSnapshot.lifecycleApplication, current)
        _ = await environment.stop(sessionID: sessionID)
    }

    func testReplacementGenerationRejectsPriorLifecycleApplication() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls)
        )
        let sessionID = UUID()
        let configuration = makeConfiguration(sessionID: sessionID)
        let firstStream = try await environment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: MediaEnvironmentControlProvider()
        )
        var firstIterator = firstStream.makeAsyncIterator()
        _ = try await firstIterator.next()
        let firstGeneration = await environment.snapshot().generation
        let stale = SessionLifecycleApplication(
            sessionID: sessionID,
            mediaGeneration: firstGeneration,
            lifecycleRevision: 1,
            directive: SessionLifecycleDirectiveResolver.resolve(
                isStreamActive: true,
                isVisible: false,
                isFocused: false,
                drawableSize: PixelSize(width: 1920, height: 1080)
            )
        )
        try await environment.applyLifecycle(stale)
        _ = await environment.stop(sessionID: sessionID)

        let replacementStream = try await environment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: MediaEnvironmentControlProvider()
        )
        var replacementIterator = replacementStream.makeAsyncIterator()
        _ = try await replacementIterator.next()
        let replacementGeneration = await environment.snapshot().generation
        XCTAssertGreaterThan(replacementGeneration, firstGeneration)
        await XCTAssertThrowsErrorAsync(
            try await environment.applyLifecycle(stale)
        ) { error in
            XCTAssertEqual(error as? SessionMediaEnvironmentError, .staleLifecycleApplication)
        }
        let unappliedReplacementSnapshot = await environment.snapshot()
        XCTAssertNil(unappliedReplacementSnapshot.lifecycleApplication)

        var replacement = stale
        replacement.mediaGeneration = replacementGeneration
        try await environment.applyLifecycle(replacement)
        let appliedReplacementSnapshot = await environment.snapshot()
        XCTAssertEqual(appliedReplacementSnapshot.lifecycleApplication, replacement)
        _ = await environment.stop(sessionID: sessionID)
    }

    func testLifecycleStateSequenceAppliesOcclusionFocusZeroDrawableAndResume() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let processor = ControlledLifecycleVideoProcessor()
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            videoProcessorFactory: ControlledLifecycleVideoProcessorFactory(
                processor: processor
            )
        )
        let sessionID = UUID()
        let stream = try await environment.start(
            sessionID: sessionID,
            configuration: makeConfiguration(sessionID: sessionID),
            controlProvider: MediaEnvironmentControlProvider()
        )
        var iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        let generation = await environment.snapshot().generation
        let applications = [
            lifecycleApplication(
                sessionID: sessionID,
                generation: generation,
                revision: 1,
                isVisible: false,
                isFocused: false,
                drawableSize: PixelSize(width: 1_920, height: 1_080)
            ),
            lifecycleApplication(
                sessionID: sessionID,
                generation: generation,
                revision: 2,
                isVisible: true,
                isFocused: false,
                drawableSize: PixelSize(width: 1_920, height: 1_080)
            ),
            lifecycleApplication(
                sessionID: sessionID,
                generation: generation,
                revision: 3,
                isVisible: true,
                isFocused: true,
                drawableSize: .zero
            ),
            lifecycleApplication(
                sessionID: sessionID,
                generation: generation,
                revision: 4,
                isVisible: true,
                isFocused: true,
                drawableSize: PixelSize(width: 1_920, height: 1_080)
            )
        ]

        for application in applications {
            try await environment.applyLifecycle(application)
        }

        let applied = await processor.applications
        XCTAssertEqual(applied, applications)
        XCTAssertEqual(
            applications.map(\.directive.videoProcessing),
            [
                .drainTransportWithoutDecoding(reason: .notVisible),
                .submitDecodedVideo,
                .drainTransportWithoutDecoding(reason: .drawableUnavailable),
                .submitDecodedVideo
            ]
        )
        let finalSnapshot = await environment.snapshot()
        XCTAssertEqual(finalSnapshot.lifecycleApplication, applications.last)
        _ = await environment.stop(sessionID: sessionID)
    }

    func testConcurrentDuplicateLifecycleApplicationSharesOnePendingEffect() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let processor = ControlledLifecycleVideoProcessor(blockFirstApplication: true)
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            videoProcessorFactory: ControlledLifecycleVideoProcessorFactory(
                processor: processor
            )
        )
        let sessionID = UUID()
        let stream = try await environment.start(
            sessionID: sessionID,
            configuration: makeConfiguration(sessionID: sessionID),
            controlProvider: MediaEnvironmentControlProvider()
        )
        var iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        let generation = await environment.snapshot().generation
        let application = lifecycleApplication(
            sessionID: sessionID,
            generation: generation,
            revision: 1,
            isVisible: false,
            isFocused: false,
            drawableSize: PixelSize(width: 1_920, height: 1_080)
        )
        let first = Task { try await environment.applyLifecycle(application) }
        await waitUntil { await processor.applicationCount == 1 }
        let duplicate = Task { try await environment.applyLifecycle(application) }
        for _ in 0..<20 { await Task.yield() }

        let pendingApplicationCount = await processor.applicationCount
        let pendingSnapshot = await environment.snapshot()
        XCTAssertEqual(pendingApplicationCount, 1)
        XCTAssertNil(pendingSnapshot.lifecycleApplication)
        await processor.resumeFirstApplication()
        try await first.value
        try await duplicate.value
        let appliedSnapshot = await environment.snapshot()
        XCTAssertEqual(appliedSnapshot.lifecycleApplication, application)
        _ = await environment.stop(sessionID: sessionID)
    }

    func testNewerLifecycleRevisionWinsWhileOlderEffectIsSuspended() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let processor = ControlledLifecycleVideoProcessor(blockFirstApplication: true)
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            videoProcessorFactory: ControlledLifecycleVideoProcessorFactory(
                processor: processor
            )
        )
        let sessionID = UUID()
        let stream = try await environment.start(
            sessionID: sessionID,
            configuration: makeConfiguration(sessionID: sessionID),
            controlProvider: MediaEnvironmentControlProvider()
        )
        var iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        let generation = await environment.snapshot().generation
        let older = lifecycleApplication(
            sessionID: sessionID,
            generation: generation,
            revision: 1,
            isVisible: false,
            isFocused: false,
            drawableSize: PixelSize(width: 1_920, height: 1_080)
        )
        let newer = lifecycleApplication(
            sessionID: sessionID,
            generation: generation,
            revision: 2,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 1_920, height: 1_080)
        )
        let olderTask = Task { try await environment.applyLifecycle(older) }
        await waitUntil { await processor.applicationCount == 1 }

        try await environment.applyLifecycle(newer)
        let newerSnapshot = await environment.snapshot()
        XCTAssertEqual(newerSnapshot.lifecycleApplication, newer)
        await processor.resumeFirstApplication()
        await XCTAssertThrowsErrorAsync(try await olderTask.value) { error in
            XCTAssertEqual(error as? SessionMediaEnvironmentError, .staleLifecycleApplication)
        }
        let finalSnapshot = await environment.snapshot()
        XCTAssertEqual(finalSnapshot.lifecycleApplication, newer)
        _ = await environment.stop(sessionID: sessionID)
    }

    func testStopAndSameSessionReplacementRejectSuspendedLifecycleEffect() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let processor = ControlledLifecycleVideoProcessor(blockFirstApplication: true)
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            videoProcessorFactory: ControlledLifecycleVideoProcessorFactory(
                processor: processor
            )
        )
        let sessionID = UUID()
        let configuration = makeConfiguration(sessionID: sessionID)
        var stream = try await environment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: MediaEnvironmentControlProvider()
        )
        var iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        let firstGeneration = await environment.snapshot().generation
        let stale = lifecycleApplication(
            sessionID: sessionID,
            generation: firstGeneration,
            revision: 1,
            isVisible: false,
            isFocused: false,
            drawableSize: PixelSize(width: 1_920, height: 1_080)
        )
        let staleTask = Task { try await environment.applyLifecycle(stale) }
        await waitUntil { await processor.applicationCount == 1 }
        _ = await environment.stop(sessionID: sessionID)

        stream = try await environment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: MediaEnvironmentControlProvider()
        )
        iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        let replacementGeneration = await environment.snapshot().generation
        let replacement = lifecycleApplication(
            sessionID: sessionID,
            generation: replacementGeneration,
            revision: 1,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 1_920, height: 1_080)
        )
        try await environment.applyLifecycle(replacement)
        await processor.resumeFirstApplication()
        await XCTAssertThrowsErrorAsync(try await staleTask.value) { error in
            XCTAssertEqual(error as? SessionMediaEnvironmentError, .inactiveSession)
        }
        XCTAssertGreaterThan(replacementGeneration, firstGeneration)
        let replacementSnapshot = await environment.snapshot()
        XCTAssertEqual(replacementSnapshot.lifecycleApplication, replacement)
        _ = await environment.stop(sessionID: sessionID)
    }

    func testStopUnblocksInputStartupAndRollsBackCleanly() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let video = ControlledVideoReceiveProvider(calls: calls)
        let audio = ControlledAudioReceiveProvider(calls: calls)
        let input = BlockingRemoteInputProvider(calls: calls)
        let environment = NativeSessionMediaEnvironment(
            videoReceiveProvider: video,
            audioReceiveProvider: audio,
            remoteInputProvider: input,
            videoProcessorFactory: RecordingVideoProcessorFactory(calls: calls),
            audioProcessorFactory: RecordingAudioProcessorFactory(calls: calls),
            teardownGracePeriod: .seconds(1)
        )
        let sessionID = UUID()
        let configuration = makeConfiguration(sessionID: sessionID)
        let controlProvider = MediaEnvironmentControlProvider()
        let startTask = Task {
            try await environment.start(
                sessionID: sessionID,
                configuration: configuration,
                controlProvider: controlProvider
            )
        }
        await waitUntil { await input.hasStarted() }
        let stopTask = Task { await environment.stop(sessionID: sessionID) }

        do {
            _ = try await startTask.value
            XCTFail("A stopped startup generation must not publish a media stream.")
        } catch {
            XCTAssertTrue(error is CancellationError)
        }
        let optionalReport = await stopTask.value
        let report = try XCTUnwrap(optionalReport)
        XCTAssertTrue(report.isClean)
        XCTAssertEqual(report.stoppedResourceCount, 5)
        let stoppedSnapshot = await environment.snapshot()
        XCTAssertNil(stoppedSnapshot.sessionID)
    }

    func testFeedbackStreamEndingFailsSessionAndTearsDownCleanly() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let video = ControlledVideoReceiveProvider(calls: calls)
        let audio = ControlledAudioReceiveProvider(calls: calls)
        let input = ControlledRemoteInputProvider(calls: calls)
        let environment = makeEnvironment(
            calls: calls,
            video: video,
            audio: audio,
            input: input
        )
        let sessionID = UUID()
        let stream = try await environment.start(
            sessionID: sessionID,
            configuration: makeConfiguration(sessionID: sessionID),
            controlProvider: MediaEnvironmentControlProvider()
        )
        var iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()

        await input.finishFeedback(sessionID: sessionID)
        do {
            _ = try await iterator.next()
            XCTFail("An ended feedback lifetime must fail the unified media stream.")
        } catch {
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .streamEnded(.input)
            )
        }
        let optionalReport = await environment.stop(sessionID: sessionID)
        let report = try XCTUnwrap(optionalReport)
        XCTAssertTrue(report.isClean)
        XCTAssertEqual(report.stoppedResourceCount, 5)
    }

    func testCancellingEventConsumerTearsDownSessionResources() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let video = ControlledVideoReceiveProvider(calls: calls)
        let audio = ControlledAudioReceiveProvider(calls: calls)
        let input = ControlledRemoteInputProvider(calls: calls)
        let environment = makeEnvironment(
            calls: calls,
            video: video,
            audio: audio,
            input: input
        )
        let sessionID = UUID()
        let stream = try await environment.start(
            sessionID: sessionID,
            configuration: makeConfiguration(sessionID: sessionID),
            controlProvider: MediaEnvironmentControlProvider()
        )
        let consumer = Task {
            for try await _ in stream {
                try Task.checkCancellation()
            }
        }
        await waitUntil {
            let snapshot = await environment.snapshot()
            return snapshot.sessionID == sessionID && snapshot.activeTaskCount == 3
        }

        consumer.cancel()
        _ = await consumer.result
        await waitUntil {
            let snapshot = await environment.snapshot()
            return snapshot.sessionID == nil
        }
        let optionalReport = await environment.stop(sessionID: sessionID)
        let report = try XCTUnwrap(optionalReport)
        XCTAssertTrue(report.isClean)
        XCTAssertEqual(report.stoppedResourceCount, 5)
    }

    func testNormalizedVideoAssemblerReordersPacketsAndPreservesFrameMetadata() throws {
        var assembler = try NormalizedVideoAccessUnitAssembler(codec: .h264)
        let header = Data([0x01, 0x2A, 0x00, 0x02, 0x03, 0x00, 0x00, 0x00])
        let last = ReceivedVideoPacket(
            sequenceNumber: 41,
            frameIndex: 7,
            rtpTimestamp: 90_000,
            receiveTimeNanoseconds: 20,
            isFirstPacket: false,
            isLastPacket: true,
            payload: Data([0x65, 0x88])
        )
        let first = ReceivedVideoPacket(
            sequenceNumber: 40,
            frameIndex: 7,
            rtpTimestamp: 90_000,
            receiveTimeNanoseconds: 10,
            isFirstPacket: true,
            isLastPacket: false,
            payload: header + Data([0x00, 0x00, 0x00, 0x01])
        )
        XCTAssertTrue(assembler.ingest(last).isEmpty)
        let events = assembler.ingest(first)
        guard case let .accessUnit(accessUnit) = try XCTUnwrap(events.last) else {
            return XCTFail("Expected a completed normalized access unit.")
        }
        XCTAssertEqual(accessUnit.frameIndex, 7)
        XCTAssertEqual(accessUnit.rtpTimestamp, 90_000)
        XCTAssertEqual(accessUnit.frameType, .instantaneousDecoderRefresh)
        XCTAssertEqual(accessUnit.hostProcessingLatencyTenthsOfMillisecond, 42)
        XCTAssertEqual(accessUnit.firstReceiveTimeNanoseconds, 10)
        XCTAssertEqual(accessUnit.lastReceiveTimeNanoseconds, 20)
        XCTAssertEqual(accessUnit.packetCount, 2)
        XCTAssertEqual(accessUnit.payload, Data([0x00, 0x00, 0x00, 0x01, 0x65, 0x88]))
    }

    func testNormalizedAV1SinglePacketTruncatesBeforeRemovingShortHeader() throws {
        var assembler = try NormalizedVideoAccessUnitAssembler(codec: .av1)
        let header = Data([0x01, 0x00, 0x00, 0x02, 0x0B, 0x00, 0x00, 0x00])
        let events = assembler.ingest(ReceivedVideoPacket(
            sequenceNumber: 7,
            frameIndex: 8,
            rtpTimestamp: 180_000,
            receiveTimeNanoseconds: 30,
            isFirstPacket: true,
            isLastPacket: true,
            payload: header + Data([0x12, 0x34, 0x56, 0xAA, 0xBB])
        ))
        guard case let .accessUnit(accessUnit) = try XCTUnwrap(events.last) else {
            return XCTFail("Expected a complete AV1 access unit.")
        }
        XCTAssertEqual(accessUnit.payload, Data([0x12, 0x34, 0x56]))
    }

    func testPresentationSourceRejectsStaleDecoderAndSessionFrames() throws {
        let source = StreamVideoPresentationSource()
        let sessionID = UUID()
        let mediaGeneration: UInt64 = 7
        let pixelBuffer = try makePixelBuffer()
        source.beginSession(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        )
        source.consume(
            .sessionStarted(generation: 3, colorMetadata: .rec709VideoRange()),
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        )
        source.consume(.frame(DecodedVideoFrame(
            generation: 3,
            frameID: 10,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: .zero,
            duration: CMTime(value: 1, timescale: 60),
            infoFlags: [],
            colorMetadata: .rec709VideoRange()
        )), sessionID: sessionID, mediaGeneration: mediaGeneration)
        source.consume(.frame(DecodedVideoFrame(
            generation: 2,
            frameID: 11,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: .zero,
            duration: CMTime(value: 1, timescale: 60),
            infoFlags: [],
            colorMetadata: .rec709VideoRange()
        )), sessionID: sessionID, mediaGeneration: mediaGeneration)
        source.consume(.frame(DecodedVideoFrame(
            generation: 3,
            frameID: 12,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: .zero,
            duration: CMTime(value: 1, timescale: 60),
            infoFlags: [],
            colorMetadata: .rec709VideoRange()
        )), sessionID: UUID(), mediaGeneration: mediaGeneration)

        let active = source.snapshot()
        XCTAssertEqual(active.latestFrameID, 10)
        XCTAssertEqual(active.publishedFrameCount, 1)
        XCTAssertEqual(active.staleFrameDropCount, 2)
        source.clear(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        )
        XCTAssertNil(source.currentFrame())
        XCTAssertNil(source.snapshot().sessionID)
    }

    func testPresentationSourceRejectsPriorMediaGenerationWithReusedSessionID() throws {
        let source = StreamVideoPresentationSource()
        let sessionID = UUID()
        let pixelBuffer = try makePixelBuffer()
        source.beginSession(sessionID: sessionID, mediaGeneration: 1)
        source.consume(
            .sessionStarted(generation: 1, colorMetadata: .rec709VideoRange()),
            sessionID: sessionID,
            mediaGeneration: 1
        )

        source.beginSession(sessionID: sessionID, mediaGeneration: 2)
        source.consume(
            .sessionStarted(generation: 1, colorMetadata: .rec709VideoRange()),
            sessionID: sessionID,
            mediaGeneration: 2
        )
        source.consume(.frame(DecodedVideoFrame(
            generation: 1,
            frameID: 41,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: .zero,
            duration: CMTime(value: 1, timescale: 60),
            infoFlags: [],
            colorMetadata: .rec709VideoRange()
        )), sessionID: sessionID, mediaGeneration: 1)
        source.consume(.frame(DecodedVideoFrame(
            generation: 1,
            frameID: 42,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: .zero,
            duration: CMTime(value: 1, timescale: 60),
            infoFlags: [],
            colorMetadata: .rec709VideoRange()
        )), sessionID: sessionID, mediaGeneration: 2)

        let snapshot = source.snapshot()
        XCTAssertEqual(snapshot.sessionID, sessionID)
        XCTAssertEqual(snapshot.mediaGeneration, 2)
        XCTAssertEqual(snapshot.latestFrameID, 42)
        XCTAssertEqual(snapshot.staleFrameDropCount, 1)
    }

    func testNativeVideoProcessorDrainsAndClearsUntilFreshIDRResume() async throws {
        let source = StreamVideoPresentationSource()
        let control = RecordingLifecycleControlProvider()
        let sessionID = UUID()
        let mediaGeneration: UInt64 = 9
        let configuration = makeConfiguration(sessionID: sessionID).video
        let processor = try await NativeSessionVideoProcessorFactory(
            presentationSource: source
        ).makeVideoProcessor(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            configuration: configuration,
            controlProvider: control
        )
        source.consume(
            .sessionStarted(generation: 1, colorMetadata: .rec709VideoRange()),
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        )
        source.consume(.frame(DecodedVideoFrame(
            generation: 1,
            frameID: 55,
            pixelBuffer: try makePixelBuffer(),
            presentationTimeStamp: .zero,
            duration: CMTime(value: 1, timescale: 60),
            infoFlags: [],
            colorMetadata: .rec709VideoRange()
        )), sessionID: sessionID, mediaGeneration: mediaGeneration)
        XCTAssertEqual(source.snapshot().latestFrameID, 55)

        let paused = SessionLifecycleApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            lifecycleRevision: 1,
            directive: SessionLifecycleDirectiveResolver.resolve(
                isStreamActive: true,
                isVisible: false,
                isFocused: false,
                drawableSize: PixelSize(width: 1_920, height: 1_080)
            )
        )
        try await processor.applyLifecycle(paused)
        XCTAssertNil(source.currentFrame())
        XCTAssertNil(source.snapshot().decoderGeneration)
        let becameReady = try await processor.consume(.packet(ReceivedVideoPacket(
            sequenceNumber: 1,
            frameIndex: 1,
            receiveTimeNanoseconds: 1,
            isFirstPacket: true,
            isLastPacket: true,
            payload: Data([0xFF])
        )))
        XCTAssertFalse(becameReady)
        let pausedIDRCount = await control.idrCount
        XCTAssertEqual(pausedIDRCount, 0)
        source.consume(
            .sessionStarted(generation: 1, colorMetadata: .rec709VideoRange()),
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        )
        source.consume(.frame(DecodedVideoFrame(
            generation: 1,
            frameID: 56,
            pixelBuffer: try makePixelBuffer(),
            presentationTimeStamp: .zero,
            duration: CMTime(value: 1, timescale: 60),
            infoFlags: [],
            colorMetadata: .rec709VideoRange()
        )), sessionID: sessionID, mediaGeneration: mediaGeneration)
        XCTAssertNil(source.currentFrame())

        let resumed = SessionLifecycleApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            lifecycleRevision: 2,
            directive: SessionLifecycleDirectiveResolver.resolve(
                isStreamActive: true,
                isVisible: true,
                isFocused: true,
                drawableSize: PixelSize(width: 1_920, height: 1_080)
            )
        )
        try await processor.applyLifecycle(resumed)
        try await processor.applyLifecycle(resumed)
        let resumedIDRCount = await control.idrCount
        XCTAssertEqual(resumedIDRCount, 1)
        XCTAssertNil(source.currentFrame())
        source.consume(
            .sessionStarted(generation: 2, colorMetadata: .rec709VideoRange()),
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        )
        source.consume(.frame(DecodedVideoFrame(
            generation: 2,
            frameID: 57,
            pixelBuffer: try makePixelBuffer(),
            presentationTimeStamp: .zero,
            duration: CMTime(value: 1, timescale: 60),
            infoFlags: [],
            colorMetadata: .rec709VideoRange()
        )), sessionID: sessionID, mediaGeneration: mediaGeneration)
        XCTAssertEqual(source.snapshot().latestFrameID, 57)
        await processor.stop()
    }

    func testNativeAudioProcessorConnectsOpusFixtureToSessionAudioGraph() async throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/audio/stereo-sequence-5ms-opus.json")
        let fixture = try JSONDecoder().decode(
            MediaEnvironmentAudioFixture.self,
            from: Data(contentsOf: fixtureURL)
        )
        let configuration = NegotiatedAudioStreamConfiguration(
            sampleRate: 48_000,
            channelCount: 2,
            streamCount: 1,
            coupledStreamCount: 1,
            samplesPerFrame: 240,
            channelMapping: [0, 1],
            maximumPacketSize: 1_400
        )
        let decoder = try AudioToolboxOpusDecoder(configuration: configuration)
        let engine = MediaEnvironmentAudioEngineClient()
        let runtime = try SessionAudioRuntime(
            pipeline: AudioSessionPipeline(engineClient: engine),
            clock: MediaClockSynchronizer(),
            configuration: .stereoLowLatency
        )
        _ = try await runtime.start(at: 0)
        let processor = try NativeSessionAudioProcessor(
            configuration: configuration,
            decoder: decoder,
            runtime: runtime
        )
        var becameReady = false
        for (index, packet) in fixture.packets.enumerated() {
            let payload = try XCTUnwrap(Data(base64Encoded: packet.base64Payload))
            becameReady = try await processor.consume(.packet(ReceivedAudioPacket(
                sequenceNumber: UInt16(index),
                timestamp: UInt32(index * configuration.samplesPerFrame),
                receiveTimeNanoseconds: UInt64(index) * 2_000_000,
                payload: payload
            ))) || becameReady
        }
        becameReady = try await processor.consume(.closed) || becameReady
        XCTAssertTrue(becameReady)
        let scheduled = engine.scheduledBuffers()
        XCTAssertEqual(scheduled.map(\.sequenceNumber), [0, 1, 2, 3])
        XCTAssertTrue(scheduled.allSatisfy { !$0.interleavedSamples.isEmpty })
        await processor.stop()
        XCTAssertTrue(engine.isStopped())
    }

    private func makeEnvironment(
        calls: MediaEnvironmentCallRecorder,
        video: ControlledVideoReceiveProvider,
        audio: ControlledAudioReceiveProvider,
        input: ControlledRemoteInputProvider,
        videoProcessorFactory: (any SessionVideoProcessorCreating)? = nil
    ) -> NativeSessionMediaEnvironment {
        NativeSessionMediaEnvironment(
            videoReceiveProvider: video,
            audioReceiveProvider: audio,
            remoteInputProvider: input,
            videoProcessorFactory: videoProcessorFactory
                ?? RecordingVideoProcessorFactory(calls: calls),
            audioProcessorFactory: RecordingAudioProcessorFactory(calls: calls),
            teardownGracePeriod: .seconds(1)
        )
    }

    private func lifecycleApplication(
        sessionID: UUID,
        generation: UInt64,
        revision: UInt64,
        isVisible: Bool,
        isFocused: Bool,
        drawableSize: PixelSize
    ) -> SessionLifecycleApplication {
        SessionLifecycleApplication(
            sessionID: sessionID,
            mediaGeneration: generation,
            lifecycleRevision: revision,
            directive: SessionLifecycleDirectiveResolver.resolve(
                isStreamActive: true,
                isVisible: isVisible,
                isFocused: isFocused,
                drawableSize: drawableSize
            )
        )
    }

    private func makeConfiguration(sessionID: UUID) -> NegotiatedSessionConfiguration {
        NegotiatedSessionConfiguration(
            sessionID: sessionID,
            controlEndpoint: endpoint(port: 47_999, transport: .udp),
            videoEndpoint: endpoint(port: 48_000, transport: .udp),
            audioEndpoint: endpoint(port: 48_010, transport: .udp),
            inputEndpoint: endpoint(port: 35_043, transport: .tcp),
            video: NegotiatedVideoStreamConfiguration(
                codec: .h264,
                width: 1_920,
                height: 1_080,
                frameRate: 60,
                colorMetadata: .rec709VideoRange(),
                maximumPacketSize: 1_400
            ),
            audio: NegotiatedAudioStreamConfiguration(
                sampleRate: 48_000,
                channelCount: 2,
                streamCount: 1,
                coupledStreamCount: 1,
                samplesPerFrame: 240,
                channelMapping: [0, 1],
                maximumPacketSize: 1_400
            ),
            input: NegotiatedInputConfiguration(
                keyMaterial: RemoteInputKeyMaterial(
                    keyID: 7,
                    key: Data(repeating: 0xA7, count: 16)
                ),
                encrypted: true,
                maximumMessageSize: RemoteInputWireCodec.maximumPacketSize
            ),
            requiredChannels: .all
        )
    }

    private func endpoint(
        port: UInt16,
        transport: RuntimeTransportKind
    ) -> RuntimeNetworkEndpoint {
        RuntimeNetworkEndpoint(host: "example.invalid", port: port, transport: transport)
    }

    private func makePixelBuffer() throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            16,
            16,
            kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            nil,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        return try XCTUnwrap(pixelBuffer)
    }

    private func waitUntil(
        _ condition: @escaping @Sendable () async -> Bool
    ) async {
        for _ in 0..<200 {
            if await condition() { return }
            await Task.yield()
        }
        XCTFail("Timed out waiting for media environment state.")
    }
}

private enum MediaEnvironmentTestError: Error, Equatable {
    case processorCreation
    case receiverFailure
}

private struct MediaEnvironmentAudioFixture: Decodable {
    struct Packet: Decodable {
        var base64Payload: String
    }

    var packets: [Packet]
}

private final class MediaEnvironmentAudioEngineClient: AudioEngineClient, @unchecked Sendable {
    private let lock = NSLock()
    private var buffers: [DecodedPCMBuffer] = []
    private var stopped = false

    func configure(_ configuration: StreamAudioConfiguration) throws {
        try configuration.validate()
        withLock { stopped = false }
    }

    func start() throws {
        withLock { stopped = false }
    }

    func schedule(
        _ buffer: DecodedPCMBuffer,
        completion: @escaping @Sendable () -> Void
    ) throws {
        _ = completion
        withLock { buffers.append(buffer) }
    }

    func stop(drain: Bool) {
        _ = drain
        withLock {
            stopped = true
            buffers.removeAll()
        }
    }

    func routeSnapshot() -> AudioRouteSnapshot {
        AudioRouteSnapshot(
            outputNames: ["Test Output"],
            sampleRate: 48_000,
            outputChannelCount: 2,
            preferredBufferDuration: 0.005
        )
    }

    func scheduledBuffers() -> [DecodedPCMBuffer] {
        withLock { buffers }
    }

    func isStopped() -> Bool {
        withLock { stopped }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private actor MediaEnvironmentCallRecorder {
    private var calls: [String] = []

    func append(_ call: String) {
        calls.append(call)
    }

    func values() -> [String] {
        calls
    }
}

private struct MediaEnvironmentControlProvider: SessionControlProvider {
    func start(
        sessionID: UUID,
        request: StreamLaunchRequest
    ) async -> AsyncThrowingStream<SessionControlEvent, Error> {
        _ = sessionID
        _ = request
        return AsyncThrowingStream { $0.finish() }
    }

    func requestIDR(sessionID: UUID) async throws {
        _ = sessionID
    }

    func stop(sessionID: UUID) async {
        _ = sessionID
    }
}

private actor RecordingLifecycleControlProvider: SessionControlProvider {
    private(set) var idrCount = 0

    func start(
        sessionID: UUID,
        request: StreamLaunchRequest
    ) async -> AsyncThrowingStream<SessionControlEvent, Error> {
        _ = sessionID
        _ = request
        return AsyncThrowingStream { $0.finish() }
    }

    func requestIDR(sessionID: UUID) async throws {
        _ = sessionID
        idrCount &+= 1
    }

    func stop(sessionID: UUID) async {
        _ = sessionID
    }
}

private struct ControlledLifecycleVideoProcessorFactory: SessionVideoProcessorCreating {
    let processor: ControlledLifecycleVideoProcessor

    func makeVideoProcessor(
        sessionID: UUID,
        mediaGeneration: UInt64,
        configuration: NegotiatedVideoStreamConfiguration,
        controlProvider: any SessionControlProvider
    ) async throws -> any SessionVideoProcessing {
        _ = sessionID
        _ = mediaGeneration
        _ = configuration
        _ = controlProvider
        return processor
    }
}

private actor ControlledLifecycleVideoProcessor: SessionVideoProcessing {
    private(set) var applications: [SessionLifecycleApplication] = []
    private let blockFirstApplication: Bool
    private var firstApplicationContinuation: CheckedContinuation<Void, Never>?

    init(blockFirstApplication: Bool = false) {
        self.blockFirstApplication = blockFirstApplication
    }

    var applicationCount: Int { applications.count }

    func consume(_ event: VideoReceiveEvent) async throws -> Bool {
        _ = event
        return false
    }

    func updateColorMetadata(_ metadata: VideoColorMetadata) async throws {
        _ = metadata
    }

    func applyLifecycle(_ application: SessionLifecycleApplication) async throws {
        applications.append(application)
        guard blockFirstApplication, applications.count == 1 else { return }
        await withCheckedContinuation { continuation in
            firstApplicationContinuation = continuation
        }
    }

    func resumeFirstApplication() {
        firstApplicationContinuation?.resume()
        firstApplicationContinuation = nil
    }

    func stop() async {}
}

private final class ControlledVideoReceiveProvider: VideoReceiveProvider, @unchecked Sendable {
    private typealias Continuation = AsyncThrowingStream<VideoReceiveEvent, Error>.Continuation
    private let lock = NSLock()
    private let calls: MediaEnvironmentCallRecorder
    private var starts: [(UUID, Continuation)] = []

    init(calls: MediaEnvironmentCallRecorder) {
        self.calls = calls
    }

    func receiveVideo(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedVideoStreamConfiguration
    ) async -> AsyncThrowingStream<VideoReceiveEvent, Error> {
        _ = endpoint
        _ = configuration
        await calls.append("video.receiver.start")
        let pair = AsyncThrowingStream<VideoReceiveEvent, Error>.makeStream()
        withLock { starts.append((sessionID, pair.continuation)) }
        return pair.stream
    }

    func stopVideo(sessionID: UUID) async {
        await calls.append("video.receiver.stop")
        let continuations = withLock {
            starts.filter { $0.0 == sessionID }.map(\.1)
        }
        continuations.forEach { $0.finish() }
    }

    func yield(_ event: VideoReceiveEvent, sessionID: UUID) {
        withLock { starts.last(where: { $0.0 == sessionID })?.1 }?.yield(event)
    }

    func yieldToStart(_ event: VideoReceiveEvent, startIndex: Int) {
        withLock {
            starts.indices.contains(startIndex) ? starts[startIndex].1 : nil
        }?.yield(event)
    }

    func finish(sessionID: UUID, throwing error: Error) {
        withLock { starts.last(where: { $0.0 == sessionID })?.1 }?.finish(throwing: error)
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private final class ControlledAudioReceiveProvider: AudioReceiveProvider, @unchecked Sendable {
    private typealias Continuation = AsyncThrowingStream<AudioReceiveEvent, Error>.Continuation
    private let lock = NSLock()
    private let calls: MediaEnvironmentCallRecorder
    private var continuations: [UUID: Continuation] = [:]

    init(calls: MediaEnvironmentCallRecorder) {
        self.calls = calls
    }

    func receiveAudio(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedAudioStreamConfiguration
    ) async -> AsyncThrowingStream<AudioReceiveEvent, Error> {
        _ = endpoint
        _ = configuration
        await calls.append("audio.receiver.start")
        let pair = AsyncThrowingStream<AudioReceiveEvent, Error>.makeStream()
        withLock { continuations[sessionID] = pair.continuation }
        return pair.stream
    }

    func stopAudio(sessionID: UUID) async {
        await calls.append("audio.receiver.stop")
        withLock { continuations[sessionID] }?.finish()
    }

    func yield(_ event: AudioReceiveEvent, sessionID: UUID) {
        withLock { continuations[sessionID] }?.yield(event)
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private actor ControlledRemoteInputProvider: RemoteInputProvider {
    private let calls: MediaEnvironmentCallRecorder
    private var activeSessionID: UUID?
    private var feedbackContinuations: [UUID: AsyncStream<RemoteInputFeedback>.Continuation] = [:]

    init(calls: MediaEnvironmentCallRecorder) {
        self.calls = calls
    }

    func startInput(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedInputConfiguration
    ) async throws {
        _ = endpoint
        _ = configuration
        activeSessionID = sessionID
        await calls.append("input.start")
    }

    func send(_ event: RemoteInputEvent, sessionID: UUID) async throws {
        _ = event
        guard activeSessionID == sessionID else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        await calls.append("input.send")
    }

    func feedback(sessionID: UUID) async -> AsyncStream<RemoteInputFeedback> {
        let pair = AsyncStream<RemoteInputFeedback>.makeStream()
        feedbackContinuations[sessionID] = pair.continuation
        return pair.stream
    }

    func releaseAll(sessionID: UUID) async {
        guard activeSessionID == sessionID else { return }
        await calls.append("input.release")
    }

    func stopInput(sessionID: UUID) async {
        guard activeSessionID == sessionID else { return }
        await calls.append("input.stop")
        activeSessionID = nil
        feedbackContinuations.removeValue(forKey: sessionID)?.finish()
    }

    func yield(_ feedback: RemoteInputFeedback, sessionID: UUID) {
        feedbackContinuations[sessionID]?.yield(feedback)
    }

    func finishFeedback(sessionID: UUID) {
        feedbackContinuations.removeValue(forKey: sessionID)?.finish()
    }
}

private actor BlockingRemoteInputProvider: RemoteInputProvider {
    private let calls: MediaEnvironmentCallRecorder
    private var started = false
    private var activeSessionID: UUID?
    private var startContinuation: CheckedContinuation<Void, Never>?

    init(calls: MediaEnvironmentCallRecorder) {
        self.calls = calls
    }

    func startInput(
        sessionID: UUID,
        endpoint: RuntimeNetworkEndpoint,
        configuration: NegotiatedInputConfiguration
    ) async throws {
        _ = endpoint
        _ = configuration
        started = true
        activeSessionID = sessionID
        await calls.append("input.start")
        await withCheckedContinuation { continuation in
            startContinuation = continuation
        }
    }

    func send(_ event: RemoteInputEvent, sessionID: UUID) async throws {
        _ = event
        guard activeSessionID == sessionID else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
    }

    func feedback(sessionID: UUID) async -> AsyncStream<RemoteInputFeedback> {
        _ = sessionID
        return AsyncStream { _ in }
    }

    func releaseAll(sessionID: UUID) async {
        guard activeSessionID == sessionID else { return }
        await calls.append("input.release")
    }

    func stopInput(sessionID: UUID) async {
        guard activeSessionID == sessionID else { return }
        activeSessionID = nil
        await calls.append("input.stop")
        startContinuation?.resume()
        startContinuation = nil
    }

    func hasStarted() -> Bool {
        started
    }

}

private struct RecordingVideoProcessorFactory: SessionVideoProcessorCreating {
    let calls: MediaEnvironmentCallRecorder

    func makeVideoProcessor(
        sessionID: UUID,
        mediaGeneration: UInt64,
        configuration: NegotiatedVideoStreamConfiguration,
        controlProvider: any SessionControlProvider
    ) async throws -> any SessionVideoProcessing {
        _ = sessionID
        _ = mediaGeneration
        _ = configuration
        _ = controlProvider
        await calls.append("video.processor.start")
        return RecordingVideoProcessor(calls: calls)
    }
}

private actor RecordingVideoProcessor: SessionVideoProcessing {
    let calls: MediaEnvironmentCallRecorder

    init(calls: MediaEnvironmentCallRecorder) {
        self.calls = calls
    }

    func consume(_ event: VideoReceiveEvent) async throws -> Bool {
        _ = event
        await calls.append("video.consume")
        return true
    }

    func updateColorMetadata(_ metadata: VideoColorMetadata) async throws {
        _ = metadata
        await calls.append("video.metadata")
    }

    func applyLifecycle(_ application: SessionLifecycleApplication) async throws {
        _ = application
        await calls.append("video.lifecycle")
    }

    func stop() async {
        await calls.append("video.processor.stop")
    }
}

private struct RecordingAudioProcessorFactory: SessionAudioProcessorCreating {
    let calls: MediaEnvironmentCallRecorder
    var failure: MediaEnvironmentTestError?

    init(
        calls: MediaEnvironmentCallRecorder,
        failure: MediaEnvironmentTestError? = nil
    ) {
        self.calls = calls
        self.failure = failure
    }

    func makeAudioProcessor(
        sessionID: UUID,
        configuration: NegotiatedAudioStreamConfiguration
    ) async throws -> any SessionAudioProcessing {
        _ = sessionID
        _ = configuration
        if let failure { throw failure }
        await calls.append("audio.processor.start")
        return RecordingAudioProcessor(calls: calls)
    }
}

private actor RecordingAudioProcessor: SessionAudioProcessing {
    let calls: MediaEnvironmentCallRecorder

    init(calls: MediaEnvironmentCallRecorder) {
        self.calls = calls
    }

    func consume(_ event: AudioReceiveEvent) async throws -> Bool {
        _ = event
        await calls.append("audio.consume")
        return true
    }

    func stop() async {
        await calls.append("audio.processor.stop")
    }
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected async expression to throw.")
    } catch {
        errorHandler(error)
    }
}
