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
        XCTAssertEqual(active.activeTaskCount, 4)
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
        try await environment.sendInput(SessionInputApplication(
            sessionID: sessionID,
            mediaGeneration: active.generation,
            event: .keyboard(KeyboardInputEvent(
                rawKeyCode: 4,
                characters: nil,
                isDown: true,
                modifiers: [],
                isRepeat: false
            ))
        ))
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
            case .videoPresentation:
                break
            case .audioRuntime:
                break
            case .mobileRuntime:
                break
            case .tvVisionPlatformPresentation:
                break
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
        XCTAssertEqual(report.cancelledTaskCount, 4)
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

    func testForwardsCurrentGenerationAudioRuntimeAndStoresSnapshot() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let audioProcessorFactory = ControlledAudioProcessorFactory(calls: calls)
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            audioProcessorFactory: audioProcessorFactory
        )
        let sessionID = UUID()
        let stream = try await environment.start(
            sessionID: sessionID,
            configuration: makeConfiguration(sessionID: sessionID),
            controlProvider: MediaEnvironmentControlProvider()
        )
        var iterator = stream.makeAsyncIterator()
        let readiness = try await iterator.next()
        XCTAssertEqual(readiness, .readiness([.input]))
        let generation = await environment.snapshot().generation
        let processor = try XCTUnwrap(audioProcessorFactory.processor(at: 0))
        let runtime = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 0,
            graphGeneration: 1
        )

        await processor.emit(runtime)
        let expected = SessionMediaAudioRuntimeState(
            sessionID: sessionID,
            mediaGeneration: generation,
            runtime: runtime
        )
        let forwarded = try await iterator.next()
        XCTAssertEqual(forwarded, .audioRuntime(expected))
        let runtimeReadiness = try await iterator.next()
        XCTAssertEqual(runtimeReadiness, .readiness([.audio, .input]))
        let snapshot = await environment.snapshot()
        XCTAssertEqual(snapshot.audioRuntime, expected)
        XCTAssertEqual(snapshot.audioRuntime?.mediaGeneration, snapshot.generation)
        XCTAssertEqual(snapshot.readiness, [.audio, .input])

        _ = await environment.stop(sessionID: sessionID)
    }

    func testMobileRuntimeAppliesCurrentGenerationAndPublishesActualState()
        async throws {
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
        let application = mobileRuntimeApplication(
            sessionID: sessionID,
            mediaGeneration: generation,
            revision: 1,
            sceneActivity: .active
        )

        try await environment.applyMobileRuntime(application)

        let snapshot = await environment.snapshot()
        XCTAssertEqual(snapshot.mobileRuntime?.application, application)
        XCTAssertEqual(snapshot.mobileRuntime?.continuityPath, .foreground)
        XCTAssertEqual(
            snapshot.mobileRuntime?.media.plan.video,
            .continueForegroundPresentation
        )
        let applied = await processor.mobileApplications
        XCTAssertEqual(applied.map(\.directive), [.continueForegroundPresentation])
        let nextEvent = try await iterator.next()
        guard case let .mobileRuntime(state)? = nextEvent else {
            return XCTFail("Expected a mobile runtime event")
        }
        XCTAssertEqual(state, snapshot.mobileRuntime)
        _ = await environment.stop(sessionID: sessionID)
    }

    func testMobileRuntimeRejectsInvalidGenerationAndStaleRevision()
        async throws {
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
        let current = mobileRuntimeApplication(
            sessionID: sessionID,
            mediaGeneration: generation,
            revision: 2,
            sceneActivity: .background,
            isAudioSessionActive: true
        )
        try await environment.applyMobileRuntime(current)

        let stale = mobileRuntimeApplication(
            sessionID: sessionID,
            mediaGeneration: generation,
            revision: 1,
            sceneActivity: .active
        )
        await XCTAssertThrowsErrorAsync(
            try await environment.applyMobileRuntime(stale)
        ) { error in
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .staleMobileRuntimeApplication
            )
        }

        let invalid = mobileRuntimeApplication(
            sessionID: sessionID,
            mediaGeneration: generation,
            revision: 3,
            sceneActivity: .active,
            pictureInPictureMediaGeneration: generation + 1
        )
        await XCTAssertThrowsErrorAsync(
            try await environment.applyMobileRuntime(invalid)
        ) { error in
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .invalidMobileRuntimeApplication
            )
        }
        let applied = await processor.mobileApplications
        XCTAssertEqual(applied.count, 1)
        XCTAssertEqual(applied.first?.directive, .drainTransportWithoutDecoding)
        let final = await environment.snapshot()
        XCTAssertEqual(final.mobileRuntime?.application, current)
        _ = await environment.stop(sessionID: sessionID)
    }

    func testMobileRuntimeRoutesPiPAudioSuspensionAndForegroundRestore()
        async throws {
        let calls = MediaEnvironmentCallRecorder()
        let processor = ControlledLifecycleVideoProcessor()
        let audioProcessorFactory = ControlledAudioProcessorFactory(calls: calls)
        let input = ControlledRemoteInputProvider(calls: calls)
        let control = RecordingMobileControlProvider()
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: input,
            videoProcessorFactory: ControlledLifecycleVideoProcessorFactory(
                processor: processor
            ),
            audioProcessorFactory: audioProcessorFactory
        )
        let sessionID = UUID()
        let stream = try await environment.start(
            sessionID: sessionID,
            configuration: makeConfiguration(sessionID: sessionID),
            controlProvider: control
        )
        var iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        let generation = await environment.snapshot().generation
        let applications = [
            mobileRuntimeApplication(
                sessionID: sessionID,
                mediaGeneration: generation,
                revision: 1,
                sceneActivity: .background,
                pictureInPictureLifecycle: .active
            ),
            mobileRuntimeApplication(
                sessionID: sessionID,
                mediaGeneration: generation,
                revision: 2,
                sceneActivity: .background,
                isAudioSessionActive: true
            ),
            mobileRuntimeApplication(
                sessionID: sessionID,
                mediaGeneration: generation,
                revision: 3,
                sceneActivity: .background
            ),
            mobileRuntimeApplication(
                sessionID: sessionID,
                mediaGeneration: generation,
                revision: 4,
                sceneActivity: .active
            )
        ]

        for application in applications.prefix(3) {
            try await environment.applyMobileRuntime(application)
        }
        await XCTAssertThrowsErrorAsync(
            try await environment.sendInput(SessionInputApplication(
                sessionID: sessionID,
                mediaGeneration: generation,
                event: .keyboard(KeyboardInputEvent(
                    rawKeyCode: 4,
                    characters: nil,
                    isDown: true,
                    modifiers: [],
                    isRepeat: false
                ))
            ))
        ) { error in
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .inputUnavailable
            )
        }
        try await environment.applyMobileRuntime(applications[3])
        try await environment.applyMobileRuntime(applications[3])

        let applied = await processor.mobileApplications
        XCTAssertEqual(applied.map(\.directive), [
            .continuePictureInPictureDelivery,
            .drainTransportWithoutDecoding,
            .drainTransportWithoutDecoding,
            .continueForegroundPresentation
        ])
        let audioProcessor = try XCTUnwrap(audioProcessorFactory.processor(at: 0))
        let audioApplications = await audioProcessor.mobileApplications()
        XCTAssertEqual(audioApplications.map(\.directive), [
            .continuePlayback,
            .continuePlayback,
            .pause,
            .continuePlayback
        ])
        let controlApplications = await control.mobileApplications()
        XCTAssertEqual(controlApplications.map(\.directive), [
            .continueSession,
            .continueSession,
            .pauseSession,
            .continueSession
        ])
        let recordedCalls = await calls.values()
        XCTAssertEqual(
            recordedCalls.filter { $0 == "input.release" }.count,
            1
        )
        let state = await environment.snapshot().mobileRuntime
        XCTAssertEqual(state?.continuityPath, .foreground)
        XCTAssertEqual(state?.media.foregroundRestorationCount, 1)
        XCTAssertEqual(
            state?.media.plan.foreground,
            .restoreAndResample(.active)
        )
        _ = await environment.stop(sessionID: sessionID)
    }

    func testConcurrentStopsShareMobileAndResourceTeardownOperation()
        async throws {
        let calls = MediaEnvironmentCallRecorder()
        let processor = ControlledLifecycleVideoProcessor(
            blockMobileStopApplication: true,
            blockResourceStop: true
        )
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
        try await environment.applyMobileRuntime(mobileRuntimeApplication(
            sessionID: sessionID,
            mediaGeneration: generation,
            revision: 1,
            sceneActivity: .active
        ))
        guard case .mobileRuntime? = try await iterator.next() else {
            return XCTFail("Expected the applied mobile runtime event")
        }
        let completions = StopCompletionRecorder()

        let first = Task {
            let report = await environment.stop(sessionID: sessionID)
            await completions.record(report)
            return report
        }
        guard await waitUntil({ await processor.isMobileStopBlocked }) else {
            await processor.releaseAllBlocks()
            _ = await first.value
            return
        }
        let second = Task {
            let report = await environment.stop(sessionID: sessionID)
            await completions.record(report)
            return report
        }
        for _ in 0..<20 { await Task.yield() }
        let completionsBeforeMobileResume = await completions.count
        XCTAssertEqual(completionsBeforeMobileResume, 0)

        await processor.resumeMobileStopApplication()
        guard await waitUntil({ await processor.isResourceStopBlocked }) else {
            await processor.releaseAllBlocks()
            _ = await first.value
            _ = await second.value
            return
        }
        for _ in 0..<20 { await Task.yield() }
        let completionsBeforeResourceResume = await completions.count
        XCTAssertEqual(completionsBeforeResourceResume, 0)

        await processor.resumeResourceStop()
        let firstOptionalReport = await first.value
        let secondOptionalReport = await second.value
        let firstReport = try XCTUnwrap(firstOptionalReport)
        let secondReport = try XCTUnwrap(secondOptionalReport)
        XCTAssertEqual(firstReport, secondReport)
        XCTAssertTrue(firstReport.isClean)
        XCTAssertEqual(firstReport.stoppedResourceCount, 5)
        let finalCompletionCount = await completions.count
        XCTAssertEqual(finalCompletionCount, 2)
        let ended = try await iterator.next()
        XCTAssertNil(ended)
        let mobileApplications = await processor.mobileApplications
        XCTAssertEqual(mobileApplications.filter { $0.directive == .stop }.count, 1)
        let values = await calls.values()
        // Mobile stop releases held input immediately; transport teardown
        // repeats the idempotent release before closing the input provider.
        XCTAssertEqual(values.filter { $0 == "input.release" }.count, 2)
        XCTAssertEqual(values.filter { $0 == "input.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "video.processor.stop" }.count, 0)
    }

    func testConcurrentStopsShareActiveTVVisionAndResourceTeardown()
        async throws {
        let calls = MediaEnvironmentCallRecorder()
        let source = StreamVideoPresentationSource()
        let actionClient = SuspendingTVVisionPresentationActionClient(
            suspending: .teardown
        )
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: actionClient
        )
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            videoPresentationSource: source,
            tvVisionPlatformCoordinatorFactory: { coordinator }
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
        let ownership = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation
        )
        source.beginSession(sessionID: sessionID, mediaGeneration: generation)
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: ownership,
                action: .activate
            )
        )
        _ = try await iterator.next()
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 1)
        let completions = StopCompletionRecorder()

        let first = Task {
            let report = await environment.stop(sessionID: sessionID)
            await completions.record(report)
            return report
        }
        await actionClient.waitUntilSuspended()
        let second = Task {
            let report = await environment.stop(sessionID: sessionID)
            await completions.record(report)
            return report
        }
        for _ in 0..<20 { await Task.yield() }
        let pendingCompletionCount = await completions.count
        XCTAssertEqual(pendingCompletionCount, 0)

        await actionClient.resume()
        let firstOptionalReport = await first.value
        let secondOptionalReport = await second.value
        let firstReport = try XCTUnwrap(firstOptionalReport)
        let secondReport = try XCTUnwrap(secondOptionalReport)
        XCTAssertEqual(firstReport, secondReport)
        XCTAssertTrue(firstReport.isClean)
        XCTAssertEqual(firstReport.stoppedResourceCount, 5)
        let optionalDuplicateReport = await environment.stop(sessionID: sessionID)
        let duplicateReport = try XCTUnwrap(optionalDuplicateReport)
        XCTAssertEqual(duplicateReport, firstReport)
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 0)
        let optionalTerminal = await coordinator.snapshot()
        let terminal = try XCTUnwrap(optionalTerminal)
        XCTAssertEqual(terminal.phase, .stopped(.localStop))
        XCTAssertEqual(terminal.teardownCount, 1)
        let effects = await actionClient.effectKinds()
        XCTAssertEqual(effects.filter { $0 == .teardown }.count, 1)
        let values = await calls.values()
        XCTAssertEqual(values.filter { $0 == "video.receiver.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "audio.receiver.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "input.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "video.processor.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "audio.processor.stop" }.count, 1)
        guard case let .tvVisionPlatformPresentation(terminalEvent)? =
                try await iterator.next() else {
            return XCTFail("Expected terminal presentation before stream end.")
        }
        XCTAssertEqual(terminalEvent.snapshot.phase, .stopped(.localStop))
        let ended = try await iterator.next()
        XCTAssertNil(ended)
    }

    func testTVVisionProviderFailureAndStopShareOneTerminalTeardown()
        async throws {
        let calls = MediaEnvironmentCallRecorder()
        let video = ControlledVideoReceiveProvider(calls: calls)
        let source = StreamVideoPresentationSource()
        let actionClient = SuspendingTVVisionPresentationActionClient(
            suspending: .teardown
        )
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: actionClient
        )
        let environment = makeEnvironment(
            calls: calls,
            video: video,
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            videoPresentationSource: source,
            tvVisionPlatformCoordinatorFactory: { coordinator }
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
        let ownership = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation
        )
        source.beginSession(sessionID: sessionID, mediaGeneration: generation)
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: ownership,
                action: .activate
            )
        )
        _ = try await iterator.next()

        video.finish(
            sessionID: sessionID,
            throwing: MediaEnvironmentTestError.receiverFailure
        )
        await actionClient.waitUntilSuspended()
        let stopTask = Task { await environment.stop(sessionID: sessionID) }
        for _ in 0..<20 { await Task.yield() }
        await actionClient.resume()

        guard case let .tvVisionPlatformPresentation(terminalEvent)? =
                try await iterator.next() else {
            return XCTFail("Expected the shared terminal snapshot before failure.")
        }
        XCTAssertEqual(terminalEvent.snapshot.phase, .stopped(.failure))
        do {
            _ = try await iterator.next()
            XCTFail("Expected the provider failure after the terminal snapshot.")
        } catch {
            XCTAssertEqual(error as? MediaEnvironmentTestError, .receiverFailure)
        }
        let optionalReport = await stopTask.value
        let report = try XCTUnwrap(optionalReport)
        XCTAssertTrue(report.isClean)
        XCTAssertEqual(report.stoppedResourceCount, 5)
        let optionalDuplicateReport = await environment.stop(sessionID: sessionID)
        let duplicateReport = try XCTUnwrap(optionalDuplicateReport)
        XCTAssertEqual(duplicateReport, report)
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 0)
        let optionalTerminal = await coordinator.snapshot()
        let terminal = try XCTUnwrap(optionalTerminal)
        XCTAssertEqual(terminal.phase, .stopped(.failure))
        XCTAssertEqual(terminal.teardownCount, 1)
        let effects = await actionClient.effectKinds()
        XCTAssertEqual(effects.filter { $0 == .teardown }.count, 1)
        let values = await calls.values()
        XCTAssertEqual(values.filter { $0 == "video.receiver.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "audio.receiver.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "input.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "video.processor.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "audio.processor.stop" }.count, 1)
    }

    func testTVVisionRemoteTerminationAndStopShareOneTerminalTeardown()
        async throws {
        let calls = MediaEnvironmentCallRecorder()
        let source = StreamVideoPresentationSource()
        let actionClient = SuspendingTVVisionPresentationActionClient(
            suspending: .teardown
        )
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: actionClient
        )
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            videoPresentationSource: source,
            tvVisionPlatformCoordinatorFactory: { coordinator }
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
        let ownership = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation
        )
        source.beginSession(sessionID: sessionID, mediaGeneration: generation)
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: ownership,
                action: .activate
            )
        )
        _ = try await iterator.next()
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 1)

        let remoteTermination = Task {
            try await environment.applyTVVisionPlatformPresentation(
                SessionTVVisionPlatformPresentationApplication(
                    ownership: ownership,
                    action: .stop(.remoteTermination)
                )
            )
        }
        await actionClient.waitUntilSuspended()
        let stop = Task { await environment.stop(sessionID: sessionID) }
        for _ in 0..<20 { await Task.yield() }

        await actionClient.resume()
        try await remoteTermination.value
        let optionalReport = await stop.value
        let report = try XCTUnwrap(optionalReport)
        XCTAssertTrue(report.isClean)
        XCTAssertEqual(report.stoppedResourceCount, 5)
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 0)

        let optionalTerminal = await coordinator.snapshot()
        let terminal = try XCTUnwrap(optionalTerminal)
        XCTAssertEqual(terminal.phase, .stopped(.remoteTermination))
        XCTAssertNil(terminal.presentation)
        XCTAssertNil(terminal.display)
        XCTAssertNil(terminal.audioRoute)
        XCTAssertFalse(terminal.video.isPresented)
        XCTAssertEqual(terminal.teardownCount, 1)
        let effects = await actionClient.effectKinds()
        XCTAssertEqual(effects.filter { $0 == .teardown }.count, 1)
        let values = await calls.values()
        XCTAssertEqual(values.filter { $0 == "video.receiver.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "audio.receiver.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "input.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "video.processor.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "audio.processor.stop" }.count, 1)

        guard case let .tvVisionPlatformPresentation(terminalEvent)? =
                try await iterator.next() else {
            return XCTFail("Expected remote terminal presentation before stream end.")
        }
        XCTAssertEqual(terminalEvent.snapshot, terminal)
        let ended = try await iterator.next()
        XCTAssertNil(ended)
    }

    func testDuplicateMobileRuntimeApplicationAwaitsOnePendingEffect()
        async throws {
        let calls = MediaEnvironmentCallRecorder()
        let processor = ControlledLifecycleVideoProcessor(
            blockFirstMobileApplication: true
        )
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
        let application = mobileRuntimeApplication(
            sessionID: sessionID,
            mediaGeneration: generation,
            revision: 1,
            sceneActivity: .background
        )
        let first = Task {
            try await environment.applyMobileRuntime(application)
        }
        await waitUntil { await processor.mobileApplicationCount == 1 }
        let duplicate = Task {
            try await environment.applyMobileRuntime(application)
        }
        for _ in 0..<20 { await Task.yield() }

        let pendingCount = await processor.mobileApplicationCount
        let pendingSnapshot = await environment.snapshot()
        XCTAssertEqual(pendingCount, 1)
        XCTAssertNil(pendingSnapshot.mobileRuntime)
        await XCTAssertThrowsErrorAsync(
            try await environment.sendInput(SessionInputApplication(
                sessionID: sessionID,
                mediaGeneration: generation,
                event: .keyboard(KeyboardInputEvent(
                    rawKeyCode: 4,
                    characters: nil,
                    isDown: true,
                    modifiers: [],
                    isRepeat: false
                ))
            ))
        ) { error in
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .inputUnavailable
            )
        }
        await processor.resumeFirstMobileApplication()
        try await first.value
        try await duplicate.value
        let appliedSnapshot = await environment.snapshot()
        XCTAssertEqual(appliedSnapshot.mobileRuntime?.application, application)
        _ = await environment.stop(sessionID: sessionID)
    }

    func testMobileRuntimeRetryResumesAfterLastCompletedActionStep()
        async throws {
        let calls = MediaEnvironmentCallRecorder()
        let videoProcessor = ControlledLifecycleVideoProcessor()
        let audioProcessorFactory = ControlledAudioProcessorFactory(calls: calls)
        let input = ControlledRemoteInputProvider(calls: calls)
        let control = RecordingMobileControlProvider()
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: input,
            videoProcessorFactory: ControlledLifecycleVideoProcessorFactory(
                processor: videoProcessor
            ),
            audioProcessorFactory: audioProcessorFactory
        )
        let sessionID = UUID()
        let stream = try await environment.start(
            sessionID: sessionID,
            configuration: makeConfiguration(sessionID: sessionID),
            controlProvider: control
        )
        var iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        let generation = await environment.snapshot().generation
        let audioProcessor = try XCTUnwrap(audioProcessorFactory.processor(at: 0))
        await audioProcessor.failNextMobileApplications(count: 2)
        let application = mobileRuntimeApplication(
            sessionID: sessionID,
            mediaGeneration: generation,
            revision: 1,
            sceneActivity: .background
        )

        await XCTAssertThrowsErrorAsync(
            try await environment.applyMobileRuntime(application)
        ) { error in
            XCTAssertEqual(
                error as? MediaEnvironmentTestError,
                .receiverFailure
            )
        }
        let failedSnapshot = await environment.snapshot()
        XCTAssertNil(failedSnapshot.mobileRuntime)

        try await environment.applyMobileRuntime(application)

        let videoApplicationCount = await videoProcessor.mobileApplicationCount
        let audioApplications = await audioProcessor.mobileApplications()
        let controlApplications = await control.mobileApplications()
        XCTAssertEqual(videoApplicationCount, 1)
        XCTAssertEqual(
            audioApplications.map(\.directive),
            [.pause, .pause, .pause]
        )
        XCTAssertEqual(
            controlApplications.map(\.directive),
            [.pauseSession]
        )
        let recordedCalls = await calls.values()
        XCTAssertEqual(
            recordedCalls.filter { $0 == "input.release" }.count,
            1
        )
        let appliedSnapshot = await environment.snapshot()
        XCTAssertEqual(appliedSnapshot.mobileRuntime?.application, application)
        _ = await environment.stop(sessionID: sessionID)
    }

    func testLateMobileRuntimeCompletionCannotPolluteReplacementGeneration()
        async throws {
        let calls = MediaEnvironmentCallRecorder()
        let processor = ControlledLifecycleVideoProcessor(
            blockFirstMobileApplication: true
        )
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
        let stale = mobileRuntimeApplication(
            sessionID: sessionID,
            mediaGeneration: firstGeneration,
            revision: 1,
            sceneActivity: .background
        )
        let staleTask = Task {
            try await environment.applyMobileRuntime(stale)
        }
        await waitUntil { await processor.mobileApplicationCount == 1 }

        _ = await environment.stop(sessionID: sessionID)
        let stoppedSnapshot = await environment.snapshot()
        XCTAssertNil(stoppedSnapshot.mobileRuntime)
        stream = try await environment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: MediaEnvironmentControlProvider()
        )
        iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        let replacementGeneration = await environment.snapshot().generation
        let replacement = mobileRuntimeApplication(
            sessionID: sessionID,
            mediaGeneration: replacementGeneration,
            revision: 1,
            sceneActivity: .active
        )
        try await environment.applyMobileRuntime(replacement)
        await processor.resumeFirstMobileApplication()
        await XCTAssertThrowsErrorAsync(try await staleTask.value) { error in
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .staleMobileRuntimeApplication
            )
        }

        let final = await environment.snapshot()
        XCTAssertGreaterThan(replacementGeneration, firstGeneration)
        XCTAssertEqual(final.mobileRuntime?.application, replacement)
        _ = await environment.stop(sessionID: sessionID)
    }

    func testMediaFailureClearsCurrentMobileRuntimeState() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let video = ControlledVideoReceiveProvider(calls: calls)
        let environment = makeEnvironment(
            calls: calls,
            video: video,
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls)
        )
        let sessionID = UUID()
        let stream = try await environment.start(
            sessionID: sessionID,
            configuration: makeConfiguration(sessionID: sessionID),
            controlProvider: MediaEnvironmentControlProvider()
        )
        let generation = await environment.snapshot().generation
        try await environment.applyMobileRuntime(mobileRuntimeApplication(
            sessionID: sessionID,
            mediaGeneration: generation,
            revision: 1,
            sceneActivity: .active
        ))
        let activeSnapshot = await environment.snapshot()
        XCTAssertNotNil(activeSnapshot.mobileRuntime)

        video.finish(
            sessionID: sessionID,
            throwing: MediaEnvironmentTestError.receiverFailure
        )
        await waitUntil { await environment.snapshot().sessionID == nil }
        let failed = await environment.snapshot()
        XCTAssertNil(failed.mobileRuntime)
        _ = stream
    }

    func testTVVisionPresentationPublishesCurrentSnapshotAndSubscribesToVideo()
        async throws {
        let calls = MediaEnvironmentCallRecorder()
        let source = StreamVideoPresentationSource()
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            videoPresentationSource: source
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
        let ownership = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation
        )
        source.beginSession(
            sessionID: sessionID,
            mediaGeneration: generation
        )

        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: ownership,
                action: .activate
            )
        )

        let activatedEvent = try await iterator.next()
        guard case let .tvVisionPlatformPresentation(activated)? =
                activatedEvent else {
            return XCTFail("Expected an activated platform presentation event.")
        }
        XCTAssertEqual(activated.snapshot.ownership, ownership)
        XCTAssertEqual(activated.snapshot.phase, .active)
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 1)

        let scene = try tvVisionSceneUpdate(ownership: ownership)
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: ownership,
                action: .scene(scene)
            )
        )
        source.consume(
            .sessionStarted(
                generation: 7,
                colorMetadata: .rec709VideoRange()
            ),
            sessionID: sessionID,
            mediaGeneration: generation
        )
        await waitUntil {
            let snapshot = await environment.snapshot()
            return snapshot.tvVisionPlatformPresentation?.snapshot.video.phase
                == .decoderReady(decoderGeneration: 7)
        }
        let current = await environment.snapshot()
        XCTAssertEqual(
            current.tvVisionPlatformPresentation?.snapshot.ownership,
            ownership
        )
        XCTAssertNil(current.tvVisionPlatformPresentation?.snapshot.presentation)

        _ = await environment.stop(sessionID: sessionID)
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 0)
        let stopped = await environment.snapshot()
        XCTAssertNil(stopped.tvVisionPlatformPresentation)
    }

    func testTVVisionPresentationRejectsStaleOwnershipAndIsolatesReplacement()
        async throws {
        let calls = MediaEnvironmentCallRecorder()
        let source = StreamVideoPresentationSource()
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            videoPresentationSource: source
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
        let first = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation,
            presentationGeneration: 1
        )
        let replacement = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation,
            presentationGeneration: 2
        )
        source.beginSession(
            sessionID: sessionID,
            mediaGeneration: generation
        )
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: first,
                action: .activate
            )
        )
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 1)

        let staleGeneration = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation + 1
        )
        await XCTAssertThrowsErrorAsync(
            try await environment.applyTVVisionPlatformPresentation(
                SessionTVVisionPlatformPresentationApplication(
                    ownership: staleGeneration,
                    action: .activate
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .staleTVVisionPlatformPresentationApplication
            )
        }

        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: replacement,
                action: .activate
            )
        )
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 1)
        let replacementSnapshot = await environment.snapshot()
        XCTAssertEqual(
            replacementSnapshot.tvVisionPlatformPresentation?.snapshot.ownership,
            replacement
        )
        await XCTAssertThrowsErrorAsync(
            try await environment.applyTVVisionPlatformPresentation(
                SessionTVVisionPlatformPresentationApplication(
                    ownership: first,
                    action: .scene(try tvVisionSceneUpdate(ownership: first))
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .staleTVVisionPlatformPresentationApplication
            )
        }

        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: replacement,
                action: .fail(.invalidComponent(.display))
            )
        )
        let failed = await environment.snapshot()
        XCTAssertEqual(
            failed.tvVisionPlatformPresentation?.snapshot.phase,
            .failed(.invalidComponent(.display))
        )
        XCTAssertNil(failed.tvVisionPlatformPresentation?.snapshot.presentation)
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 0)
        _ = await environment.stop(sessionID: sessionID)
        _ = stream
    }

    func testTVOSAudioRuntimeReplaysAcrossActivationAndReplacementAndRecovers()
        async throws
    {
        let calls = MediaEnvironmentCallRecorder()
        let audioProcessorFactory = ControlledAudioProcessorFactory(calls: calls)
        let source = StreamVideoPresentationSource()
        let coordinator = try TVVisionPlatformPresentationCoordinator()
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            audioProcessorFactory: audioProcessorFactory,
            videoPresentationSource: source,
            tvVisionPlatformCoordinatorFactory: { coordinator }
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
        let processor = try XCTUnwrap(audioProcessorFactory.processor(at: 0))
        let initial = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 1,
            graphGeneration: 1,
            spatialRuntime: spatialAudioRuntime(
                revision: 1,
                presentationMode: .fixedSpatial
            )
        )
        await processor.emit(initial)
        await waitUntil {
            await environment.snapshot().audioRuntime?.runtime == initial
        }

        let first = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation,
            presentationGeneration: 1
        )
        source.beginSession(sessionID: sessionID, mediaGeneration: generation)
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: first,
                action: .activate
            )
        )
        let firstSnapshot = await environment.snapshot()
        XCTAssertEqual(
            firstSnapshot.tvVisionPlatformPresentation?.snapshot.audioRoute?
                .spatialPresentationMode,
            .fixedSpatial
        )
        XCTAssertNil(
            firstSnapshot.tvVisionPlatformPresentation?.snapshot.presentation
        )

        let replacement = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation,
            presentationGeneration: 2
        )
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: replacement,
                action: .activate
            )
        )
        let replacementSnapshot = await environment.snapshot()
        XCTAssertEqual(
            replacementSnapshot.tvVisionPlatformPresentation?.snapshot.ownership,
            replacement
        )
        XCTAssertEqual(
            replacementSnapshot.tvVisionPlatformPresentation?.snapshot.audioRoute?
                .routeGeneration.rawValue,
            1
        )

        let interrupted = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 2,
            graphGeneration: 1,
            cause: .interruptionBegan,
            stage: .interrupted,
            spatialRuntime: spatialAudioRuntime(
                revision: 1,
                presentationMode: .fixedSpatial
            )
        )
        await processor.emit(interrupted)
        await waitUntil {
            await environment.snapshot().tvVisionPlatformPresentation?.snapshot
                .audioRoute?.runtimeStage == .interrupted
        }
        let interruptionRoute = await environment.snapshot()
            .tvVisionPlatformPresentation?.snapshot.audioRoute
        XCTAssertEqual(interruptionRoute?.eventCause, .interruptionBegan)

        let lost = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 3,
            graphGeneration: 1,
            cause: .mediaServicesLost,
            stage: .interrupted,
            spatialRuntime: spatialAudioRuntime(
                revision: 1,
                presentationMode: .fixedSpatial
            )
        )
        await processor.emit(lost)
        await waitUntil {
            await environment.snapshot().tvVisionPlatformPresentation?.snapshot
                .audioRoute?.eventCause == .mediaServicesLost
        }
        let lostRoute = await environment.snapshot()
            .tvVisionPlatformPresentation?.snapshot.audioRoute
        XCTAssertEqual(lostRoute?.outputAvailable, false)
        XCTAssertEqual(lostRoute?.spatialPresentationMode, .inactive)

        let reset = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 4,
            graphGeneration: 2,
            cause: .mediaServicesReset,
            spatialRuntime: spatialAudioRuntime(
                revision: 2,
                presentationMode: .headTracked
            )
        )
        await processor.emit(reset)
        await waitUntil {
            await environment.snapshot().tvVisionPlatformPresentation?.snapshot
                .audioRoute?.routeGeneration.rawValue == 2
        }
        let resetRoute = await environment.snapshot()
            .tvVisionPlatformPresentation?.snapshot.audioRoute
        XCTAssertEqual(resetRoute?.eventCause, .mediaServicesReset)
        XCTAssertEqual(resetRoute?.spatialPresentationMode, .headTracked)

        await processor.emit(audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 5,
            graphGeneration: 1,
            cause: .recovery
        ))
        for _ in 0..<20 { await Task.yield() }
        let afterStale = await environment.snapshot()
            .tvVisionPlatformPresentation?.snapshot.audioRoute
        XCTAssertEqual(afterStale, resetRoute)

        _ = await environment.stop(sessionID: sessionID)
        let terminal = await coordinator.snapshot()
        let stopped = await environment.snapshot()
        XCTAssertNil(terminal?.audioRoute)
        XCTAssertNil(stopped.tvVisionPlatformPresentation)
        _ = iterator
    }

    func testVisionOSAudioRuntimeReplaysIntendedExperienceAndRecoversGraph()
        async throws
    {
        let calls = MediaEnvironmentCallRecorder()
        let audioProcessorFactory = ControlledAudioProcessorFactory(calls: calls)
        let source = StreamVideoPresentationSource()
        let coordinator = try TVVisionPlatformPresentationCoordinator()
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            audioProcessorFactory: audioProcessorFactory,
            videoPresentationSource: source,
            tvVisionPlatformCoordinatorFactory: { coordinator }
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
        let processor = try XCTUnwrap(audioProcessorFactory.processor(at: 0))
        let route1 = SpatialAudioRouteCapabilitySnapshot(
            revision: .init(rawValue: 1),
            outputAvailable: true,
            systemSpatialSupport: .supported,
            currentOutputChannelCount: 2,
            maximumOutputChannelCount: 12
        )
        let initial = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 1,
            graphGeneration: 1,
            spatialRuntime: spatialAudioRuntime(
                revision: 1,
                platformStrategy: .visionOutputExperience,
                presentationMode: .fixedSpatial
            ),
            routeCapability: route1,
            entitlement: .missing
        )
        await processor.emit(initial)
        await waitUntil {
            await environment.snapshot().audioRuntime?.runtime == initial
        }

        let first = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation,
            presentationGeneration: 1,
            platform: .visionOS
        )
        source.beginSession(sessionID: sessionID, mediaGeneration: generation)
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: first,
                action: .activate
            )
        )
        let firstRoute = await environment.snapshot()
            .tvVisionPlatformPresentation?.snapshot.audioRoute
        XCTAssertEqual(firstRoute?.platform, .visionOS)
        XCTAssertEqual(firstRoute?.platformStrategy, .visionOutputExperience)
        XCTAssertEqual(
            firstRoute?.headTrackingCapability,
            .intendedSpatialExperience
        )
        XCTAssertEqual(firstRoute?.currentOutputChannelCount, 2)
        XCTAssertEqual(firstRoute?.maximumOutputChannelCount, 12)
        XCTAssertEqual(firstRoute?.spatialPresentationMode, .fixedSpatial)

        let replacement = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation,
            presentationGeneration: 2,
            platform: .visionOS
        )
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: replacement,
                action: .activate
            )
        )
        let replayed = await environment.snapshot()
            .tvVisionPlatformPresentation?.snapshot
        XCTAssertEqual(replayed?.ownership, replacement)
        XCTAssertEqual(replayed?.audioRoute?.routeGeneration.rawValue, 1)
        XCTAssertEqual(replayed?.audioRoute?.platform, .visionOS)

        let interrupted = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 2,
            graphGeneration: 1,
            cause: .interruptionBegan,
            stage: .interrupted,
            spatialRuntime: spatialAudioRuntime(
                revision: 1,
                platformStrategy: .visionOutputExperience,
                presentationMode: .fixedSpatial
            ),
            routeCapability: route1,
            entitlement: .missing
        )
        await processor.emit(interrupted)
        await waitUntil {
            await environment.snapshot().tvVisionPlatformPresentation?.snapshot
                .audioRoute?.runtimeStage == .interrupted
        }

        let lost = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 3,
            graphGeneration: 1,
            cause: .mediaServicesLost,
            stage: .interrupted,
            spatialRuntime: spatialAudioRuntime(
                revision: 1,
                platformStrategy: .visionOutputExperience,
                presentationMode: .fixedSpatial
            ),
            routeCapability: route1,
            entitlement: .missing
        )
        await processor.emit(lost)
        await waitUntil {
            await environment.snapshot().tvVisionPlatformPresentation?.snapshot
                .audioRoute?.eventCause == .mediaServicesLost
        }
        let lostRoute = await environment.snapshot()
            .tvVisionPlatformPresentation?.snapshot.audioRoute
        XCTAssertEqual(lostRoute?.outputAvailable, false)
        XCTAssertEqual(
            lostRoute?.platformStrategy,
            SpatialAudioPlatformStrategy.none
        )
        XCTAssertEqual(lostRoute?.spatialPresentationMode, .inactive)

        let route2 = SpatialAudioRouteCapabilitySnapshot(
            revision: .init(rawValue: 2),
            outputAvailable: true,
            systemSpatialSupport: .supported,
            currentOutputChannelCount: 6,
            maximumOutputChannelCount: 12
        )
        let reset = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 4,
            graphGeneration: 2,
            cause: .mediaServicesReset,
            spatialRuntime: spatialAudioRuntime(
                revision: 2,
                platformStrategy: .visionOutputExperience,
                presentationMode: .headTracked
            ),
            routeCapability: route2,
            entitlement: .missing
        )
        await processor.emit(reset)
        await waitUntil {
            await environment.snapshot().tvVisionPlatformPresentation?.snapshot
                .audioRoute?.routeGeneration.rawValue == 2
        }
        let recovered = await environment.snapshot()
            .tvVisionPlatformPresentation?.snapshot.audioRoute
        XCTAssertEqual(recovered?.eventCause, .mediaServicesReset)
        XCTAssertEqual(recovered?.currentOutputChannelCount, 6)
        XCTAssertEqual(recovered?.maximumOutputChannelCount, 12)
        XCTAssertEqual(recovered?.spatialPresentationMode, .headTracked)
        XCTAssertEqual(
            recovered?.headTrackingCapability,
            .intendedSpatialExperience
        )

        await processor.emit(audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 5,
            graphGeneration: 1,
            cause: .recovery,
            spatialRuntime: spatialAudioRuntime(
                revision: 1,
                platformStrategy: .visionOutputExperience,
                presentationMode: .fixedSpatial
            ),
            routeCapability: route1,
            entitlement: .missing
        ))
        for _ in 0..<20 { await Task.yield() }
        let afterStale = await environment.snapshot()
            .tvVisionPlatformPresentation?.snapshot.audioRoute
        XCTAssertEqual(afterStale, recovered)

        _ = await environment.stop(sessionID: sessionID)
        let terminal = await coordinator.snapshot()
        let stopped = await environment.snapshot()
        XCTAssertNil(terminal?.audioRoute)
        XCTAssertNil(stopped.tvVisionPlatformPresentation)
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 0)
        _ = iterator
    }

    func testTVOSInvalidAudioRuntimeFailsCurrentPresentation() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let audioProcessorFactory = ControlledAudioProcessorFactory(calls: calls)
        let source = StreamVideoPresentationSource()
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            audioProcessorFactory: audioProcessorFactory,
            videoPresentationSource: source
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
        let ownership = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation
        )
        source.beginSession(sessionID: sessionID, mediaGeneration: generation)
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: ownership,
                action: .activate
            )
        )
        let processor = try XCTUnwrap(audioProcessorFactory.processor(at: 0))

        await processor.emit(audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 1,
            graphGeneration: 1,
            spatialRuntime: spatialAudioRuntime(
                revision: 1,
                platformStrategy: .visionOutputExperience,
                presentationMode: .fixedSpatial
            )
        ))
        await waitUntil {
            await environment.snapshot().tvVisionPlatformPresentation?.snapshot
                .phase == .failed(.invalidComponent(.audioRoute))
        }
        let failed = await environment.snapshot()
        XCTAssertNil(failed.tvVisionPlatformPresentation?.snapshot.audioRoute)
        XCTAssertNil(failed.tvVisionPlatformPresentation?.snapshot.presentation)
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 0)

        _ = await environment.stop(sessionID: sessionID)
        _ = iterator
    }

    func testTVOSAudioRouteActionFailurePublishesTerminalState() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let audioProcessorFactory = ControlledAudioProcessorFactory(calls: calls)
        let source = StreamVideoPresentationSource()
        let actionClient = FailingTVVisionPresentationActionClient(
            failing: .audioRoute
        )
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: actionClient
        )
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            audioProcessorFactory: audioProcessorFactory,
            videoPresentationSource: source,
            tvVisionPlatformCoordinatorFactory: { coordinator }
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
        let ownership = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation
        )
        source.beginSession(sessionID: sessionID, mediaGeneration: generation)
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: ownership,
                action: .activate
            )
        )
        let processor = try XCTUnwrap(audioProcessorFactory.processor(at: 0))

        await processor.emit(audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 1,
            graphGeneration: 1
        ))
        await waitUntil {
            await environment.snapshot().tvVisionPlatformPresentation?.snapshot
                .phase == .failed(.actionFailed(.audioRoute))
        }
        let effectKinds = await actionClient.effectKinds()
        XCTAssertEqual(effectKinds, [
            .snapshot,
            .input,
            .scene,
            .display,
            .audioRoute,
            .input,
            .clearVideo,
            .display,
            .audioRoute,
            .scene,
            .teardown,
            .snapshot
        ])
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 0)

        _ = await environment.stop(sessionID: sessionID)
        _ = iterator
    }

    func testTVVisionProviderFailurePublishesTerminalStateBeforeStreamError()
        async throws {
        let calls = MediaEnvironmentCallRecorder()
        let video = ControlledVideoReceiveProvider(calls: calls)
        let source = StreamVideoPresentationSource()
        let environment = makeEnvironment(
            calls: calls,
            video: video,
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            videoPresentationSource: source
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
        let ownership = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation
        )
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: ownership,
                action: .activate
            )
        )
        _ = try await iterator.next()

        video.finish(
            sessionID: sessionID,
            throwing: MediaEnvironmentTestError.receiverFailure
        )
        guard case let .tvVisionPlatformPresentation(terminal)? =
                try await iterator.next() else {
            return XCTFail("Expected terminal presentation before stream error.")
        }
        XCTAssertEqual(terminal.snapshot.phase, .stopped(.failure))
        XCTAssertNil(terminal.snapshot.presentation)
        do {
            _ = try await iterator.next()
            XCTFail("Expected the provider error after the terminal snapshot.")
        } catch {
            XCTAssertEqual(error as? MediaEnvironmentTestError, .receiverFailure)
        }
        await waitUntil { await environment.snapshot().sessionID == nil }
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 0)
    }

    func testVisionPresentationRebindsSubscriptionAndReleasesResourcesOnStop()
        async throws
    {
        let calls = MediaEnvironmentCallRecorder()
        let source = StreamVideoPresentationSource()
        let coordinator = try TVVisionPlatformPresentationCoordinator()
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            videoPresentationSource: source,
            tvVisionPlatformCoordinatorFactory: { coordinator }
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
        let first = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation,
            presentationGeneration: 1,
            platform: .visionOS
        )
        let replacement = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation,
            presentationGeneration: 2,
            platform: .visionOS
        )
        source.beginSession(
            sessionID: sessionID,
            mediaGeneration: generation
        )
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: first,
                action: .activate
            )
        )
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: first,
                action: .scene(try tvVisionSceneUpdate(ownership: first))
            )
        )
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 1)

        let pixelBuffer = try makePixelBuffer()
        source.consume(
            .sessionStarted(
                generation: 7,
                colorMetadata: .rec709VideoRange()
            ),
            sessionID: sessionID,
            mediaGeneration: generation
        )
        source.consume(
            .frame(DecodedVideoFrame(
                generation: 7,
                frameID: 70,
                pixelBuffer: pixelBuffer,
                presentationTimeStamp: .zero,
                duration: CMTime(value: 1, timescale: 60),
                infoFlags: [],
                colorMetadata: .rec709VideoRange()
            )),
            sessionID: sessionID,
            mediaGeneration: generation
        )
        await waitUntil {
            let snapshot = await environment.snapshot()
            return snapshot.tvVisionPlatformPresentation?.snapshot.video.phase
                == .frameReady(decoderGeneration: 7, frameID: 70)
                && snapshot.tvVisionPlatformPresentation?.snapshot.video
                    .isPresented == true
        }
        let firstState = await environment.snapshot()
        XCTAssertEqual(
            firstState.tvVisionPlatformPresentation?.snapshot
                .visionWindowedPresentation?.ownership,
            first
        )

        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: replacement,
                action: .activate
            )
        )
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 1)
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: replacement,
                action: .scene(try tvVisionSceneUpdate(
                    ownership: replacement,
                    revision: 1
                ))
            )
        )
        source.consume(
            .frame(DecodedVideoFrame(
                generation: 7,
                frameID: 71,
                pixelBuffer: pixelBuffer,
                presentationTimeStamp: CMTime(value: 1, timescale: 60),
                duration: CMTime(value: 1, timescale: 60),
                infoFlags: [],
                colorMetadata: .rec709VideoRange()
            )),
            sessionID: sessionID,
            mediaGeneration: generation
        )
        await waitUntil {
            let snapshot = await environment.snapshot()
            return snapshot.tvVisionPlatformPresentation?.snapshot.ownership
                == replacement
                && snapshot.tvVisionPlatformPresentation?.snapshot.video.phase
                    == .frameReady(decoderGeneration: 7, frameID: 71)
                && snapshot.tvVisionPlatformPresentation?.snapshot.video
                    .isPresented == true
        }
        let replacementState = await environment.snapshot()
        XCTAssertEqual(
            replacementState.tvVisionPlatformPresentation?.snapshot
                .visionWindowedPresentation?.ownership,
            replacement
        )
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 1)

        await XCTAssertThrowsErrorAsync(
            try await environment.applyTVVisionPlatformPresentation(
                SessionTVVisionPlatformPresentationApplication(
                    ownership: first,
                    action: .scene(try tvVisionSceneUpdate(
                        ownership: first,
                        revision: 2
                    ))
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .staleTVVisionPlatformPresentationApplication
            )
        }
        let afterStale = await environment.snapshot()
        XCTAssertEqual(
            afterStale.tvVisionPlatformPresentation?.snapshot.video.phase,
            .frameReady(decoderGeneration: 7, frameID: 71)
        )

        let active = await environment.snapshot()
        XCTAssertEqual(active.activeTaskCount, 4)
        XCTAssertEqual(active.activeResourceCount, 5)

        let optionalReport = await environment.stop(sessionID: sessionID)
        let report = try XCTUnwrap(optionalReport)
        XCTAssertTrue(report.isClean)
        XCTAssertEqual(report.cancelledTaskCount, 4)
        XCTAssertEqual(report.stoppedResourceCount, 5)
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 0)
        let stopped = await environment.snapshot()
        XCTAssertNil(stopped.tvVisionPlatformPresentation)
        XCTAssertEqual(stopped.activeTaskCount, 0)
        XCTAssertEqual(stopped.activeResourceCount, 0)
        XCTAssertEqual(stopped.lastTeardownReport, report)

        let optionalTerminal = await coordinator.snapshot()
        let terminal = try XCTUnwrap(optionalTerminal)
        XCTAssertEqual(terminal.phase, .stopped(.localStop))
        XCTAssertNil(terminal.visionWindowedPresentation)
        XCTAssertNil(terminal.presentation)
        XCTAssertNil(terminal.display)
        XCTAssertNil(terminal.audioRoute)
        XCTAssertFalse(terminal.video.isPresented)
        XCTAssertEqual(terminal.teardownCount, 2)

        let values = await calls.values()
        XCTAssertEqual(values.filter { $0 == "video.receiver.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "audio.receiver.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "input.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "video.processor.stop" }.count, 1)
        XCTAssertEqual(values.filter { $0 == "audio.processor.stop" }.count, 1)
    }

    func testTVVisionVideoDeliveryPumpPreservesFIFOAndFailsClosedWhenBounded()
        async throws
    {
        let recorder = TVVisionVideoDeliveryPumpRecorder()
        let sessionID = UUID()
        let pump = SessionTVVisionPlatformVideoDeliveryPump { delivery in
            await recorder.receive(delivery)
        }
        let delivery: (UInt64) -> StreamVideoPresentationDelivery = { revision in
            .cleared(
                ownership: StreamVideoPresentationDeliveryOwnership(
                    sessionID: sessionID,
                    mediaGeneration: 1,
                    revision: revision
                ),
                decoderGeneration: nil
            )
        }

        await recorder.block(revision: 1)
        pump.submit(delivery(1))
        await recorder.waitUntilBlocked()
        pump.submit(delivery(2))
        pump.submit(delivery(3))
        let revisionsWhileFirstBlocked = await recorder.revisions()
        XCTAssertEqual(revisionsWhileFirstBlocked, [1])

        await recorder.resume()
        await waitUntil { await recorder.revisions() == [1, 2, 3] }

        await recorder.block(revision: 4)
        pump.submit(delivery(4))
        await recorder.waitUntilBlocked()
        pump.submit(delivery(5))
        pump.cancel()
        await recorder.resume()
        await waitUntil { await recorder.revisions() == [1, 2, 3, 4] }
        pump.submit(delivery(6))
        await Task.yield()
        let revisionsAfterCancel = await recorder.revisions()
        XCTAssertEqual(revisionsAfterCancel, [1, 2, 3, 4])

        let overflowRecorder = TVVisionVideoDeliveryPumpRecorder()
        let overflowPump = SessionTVVisionPlatformVideoDeliveryPump(
            handler: { delivery in
                await overflowRecorder.receive(delivery)
            },
            overflowHandler: {
                await overflowRecorder.recordOverflow()
            }
        )
        await overflowRecorder.block(revision: 10)
        overflowPump.submit(delivery(10))
        await overflowRecorder.waitUntilBlocked()
        for revision in 11...(
            UInt64(SessionTVVisionPlatformVideoDeliveryPump
                .maximumPendingDeliveryCount) + 11
        ) {
            overflowPump.submit(delivery(revision))
        }
        let revisionsBeforeOverflow = await overflowRecorder.revisions()
        XCTAssertEqual(revisionsBeforeOverflow, [10])

        await overflowRecorder.resume()
        await waitUntil { await overflowRecorder.overflowCount() == 1 }
        let revisionsAfterOverflow = await overflowRecorder.revisions()
        XCTAssertEqual(revisionsAfterOverflow, [10])
        overflowPump.submit(delivery(100))
        await Task.yield()
        let overflowCountAfterRejectedSubmit =
            await overflowRecorder.overflowCount()
        XCTAssertEqual(overflowCountAfterRejectedSubmit, 1)
        overflowPump.cancel()
    }

    func testVisionVideoDeliveryOverflowFailsPresentationAndCancelsSubscription()
        async throws
    {
        let calls = MediaEnvironmentCallRecorder()
        let source = StreamVideoPresentationSource()
        let actionClient = SuspendingTVVisionPresentationActionClient(
            suspending: .video
        )
        let coordinator = try TVVisionPlatformPresentationCoordinator(
            actionClient: actionClient
        )
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            videoPresentationSource: source,
            tvVisionPlatformCoordinatorFactory: { coordinator }
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
        let ownership = try tvVisionPresentationOwnership(
            sessionID: sessionID,
            mediaGeneration: generation,
            platform: .visionOS
        )
        source.beginSession(
            sessionID: sessionID,
            mediaGeneration: generation
        )
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: ownership,
                action: .activate
            )
        )
        try await environment.applyTVVisionPlatformPresentation(
            SessionTVVisionPlatformPresentationApplication(
                ownership: ownership,
                action: .scene(try tvVisionSceneUpdate(ownership: ownership))
            )
        )
        source.consume(
            .sessionStarted(
                generation: 7,
                colorMetadata: .rec709VideoRange()
            ),
            sessionID: sessionID,
            mediaGeneration: generation
        )
        let pixelBuffer = try makePixelBuffer()
        source.consume(
            .frame(DecodedVideoFrame(
                generation: 7,
                frameID: 0,
                pixelBuffer: pixelBuffer,
                presentationTimeStamp: .zero,
                duration: CMTime(value: 1, timescale: 60),
                infoFlags: [],
                colorMetadata: .rec709VideoRange()
            )),
            sessionID: sessionID,
            mediaGeneration: generation
        )
        guard await waitUntil({ await actionClient.isCurrentlySuspended }) else {
            _ = await environment.stop(sessionID: sessionID)
            return
        }
        for frameID in 1...(
            UInt64(SessionTVVisionPlatformVideoDeliveryPump
                .maximumPendingDeliveryCount) + 1
        ) {
            source.consume(
                .frame(DecodedVideoFrame(
                    generation: 7,
                    frameID: frameID,
                    pixelBuffer: pixelBuffer,
                    presentationTimeStamp: CMTime(
                        value: CMTimeValue(frameID),
                        timescale: 60
                    ),
                    duration: CMTime(value: 1, timescale: 60),
                    infoFlags: [],
                    colorMetadata: .rec709VideoRange()
                )),
                sessionID: sessionID,
                mediaGeneration: generation
            )
        }
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 1)

        await actionClient.resume()
        await waitUntil {
            let snapshot = await environment.snapshot()
            return snapshot.tvVisionPlatformPresentation?.snapshot.phase
                == .failed(.invalidComponent(.video))
                && source.snapshot().activeSubscriptionCount == 0
        }
        let failed = await environment.snapshot()
        XCTAssertEqual(
            failed.tvVisionPlatformPresentation?.snapshot.phase,
            .failed(.invalidComponent(.video))
        )
        XCTAssertEqual(source.snapshot().activeSubscriptionCount, 0)

        _ = await environment.stop(sessionID: sessionID)
    }

    func testRejectsRegressiveAudioRuntimeSequencesAndGraphGenerations() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let audioProcessorFactory = ControlledAudioProcessorFactory(calls: calls)
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            audioProcessorFactory: audioProcessorFactory
        )
        let sessionID = UUID()
        let stream = try await environment.start(
            sessionID: sessionID,
            configuration: makeConfiguration(sessionID: sessionID),
            controlProvider: MediaEnvironmentControlProvider()
        )
        var iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        let processor = try XCTUnwrap(audioProcessorFactory.processor(at: 0))
        let initial = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 10,
            graphGeneration: 3
        )
        let valid = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 11,
            graphGeneration: 3,
            cause: .routeChanged
        )

        await processor.emit(initial)
        await processor.emit(audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 9,
            graphGeneration: 4
        ))
        await processor.emit(audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 10,
            graphGeneration: 4
        ))
        await processor.emit(audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 11,
            graphGeneration: 2
        ))
        await processor.emit(audioRuntimeEvent(
            sessionID: UUID(),
            sequence: 12,
            graphGeneration: 4
        ))
        await processor.emit(valid)

        guard case let .audioRuntime(first) = try await iterator.next() else {
            return XCTFail("Expected the first current audio runtime event.")
        }
        let runtimeReadiness = try await iterator.next()
        XCTAssertEqual(runtimeReadiness, .readiness([.audio, .input]))
        guard case let .audioRuntime(second) = try await iterator.next() else {
            return XCTFail("Expected the next monotonic audio runtime event.")
        }
        XCTAssertEqual(first.runtime, initial)
        XCTAssertEqual(second.runtime, valid)
        let snapshot = await environment.snapshot()
        XCTAssertEqual(snapshot.audioRuntime?.runtime, valid)

        _ = await environment.stop(sessionID: sessionID)
    }

    func testSameSessionReplacementDiscardsPriorProcessorAudioRuntime() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let audioProcessorFactory = ControlledAudioProcessorFactory(
            calls: calls,
            finishStreamOnStop: false
        )
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            audioProcessorFactory: audioProcessorFactory
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
        let firstProcessor = try XCTUnwrap(audioProcessorFactory.processor(at: 0))
        let firstRuntime = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 0,
            graphGeneration: 1
        )
        await firstProcessor.emit(firstRuntime)
        _ = try await firstIterator.next()
        _ = await environment.stop(sessionID: sessionID)

        let replacementStream = try await environment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: MediaEnvironmentControlProvider()
        )
        var replacementIterator = replacementStream.makeAsyncIterator()
        _ = try await replacementIterator.next()
        let replacementGeneration = await environment.snapshot().generation
        let replacementProcessor = try XCTUnwrap(audioProcessorFactory.processor(at: 1))
        let staleRuntime = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 50,
            graphGeneration: 50,
            cause: .recovery
        )
        let replacementRuntime = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 0,
            graphGeneration: 1
        )

        await firstProcessor.emit(staleRuntime)
        await replacementProcessor.emit(replacementRuntime)
        let expected = SessionMediaAudioRuntimeState(
            sessionID: sessionID,
            mediaGeneration: replacementGeneration,
            runtime: replacementRuntime
        )
        let forwarded = try await replacementIterator.next()
        XCTAssertEqual(forwarded, .audioRuntime(expected))
        let replacementSnapshot = await environment.snapshot()
        XCTAssertGreaterThan(replacementGeneration, firstGeneration)
        XCTAssertEqual(replacementSnapshot.audioRuntime, expected)
        XCTAssertNotEqual(replacementSnapshot.audioRuntime?.runtime, staleRuntime)

        _ = await environment.stop(sessionID: sessionID)
    }

    func testAudioRuntimeStreamEndingFailsSessionAndTearsDownCleanly() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let audioProcessorFactory = ControlledAudioProcessorFactory(calls: calls)
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            audioProcessorFactory: audioProcessorFactory
        )
        let sessionID = UUID()
        let stream = try await environment.start(
            sessionID: sessionID,
            configuration: makeConfiguration(sessionID: sessionID),
            controlProvider: MediaEnvironmentControlProvider()
        )
        var iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        let processor = try XCTUnwrap(audioProcessorFactory.processor(at: 0))

        await processor.finish()
        do {
            _ = try await iterator.next()
            XCTFail("An ended audio runtime lifetime must fail the unified media stream.")
        } catch {
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .streamEnded(.audio)
            )
        }
        let optionalReport = await environment.stop(sessionID: sessionID)
        let report = try XCTUnwrap(optionalReport)
        XCTAssertTrue(report.isClean)
        XCTAssertEqual(report.stoppedResourceCount, 5)
    }

    func testSpatialAudioPreferenceApplicationIsGenerationScopedAcrossReplacement()
        async throws {
        let calls = MediaEnvironmentCallRecorder()
        let audioProcessorFactory = ControlledAudioProcessorFactory(calls: calls)
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            audioProcessorFactory: audioProcessorFactory
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
        let preferences = SessionSpatialAudioPreferences(
            spatialAudioEnabled: false,
            headTrackingEnabled: false
        )
        let firstApplication = SessionSpatialAudioPreferenceApplication(
            sessionID: sessionID,
            mediaGeneration: firstGeneration,
            preferences: preferences
        )
        try await environment.updateSpatialAudioPreferences(firstApplication)
        let firstProcessor = try XCTUnwrap(audioProcessorFactory.processor(at: 0))
        let firstUpdates = await firstProcessor.preferenceUpdates()
        XCTAssertEqual(firstUpdates, [preferences])
        _ = await environment.stop(sessionID: sessionID)

        stream = try await environment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: MediaEnvironmentControlProvider()
        )
        iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        let replacementGeneration = await environment.snapshot().generation
        await XCTAssertThrowsErrorAsync(
            try await environment.updateSpatialAudioPreferences(firstApplication)
        ) { error in
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .staleAudioApplication
            )
        }

        let replacementApplication = SessionSpatialAudioPreferenceApplication(
            sessionID: sessionID,
            mediaGeneration: replacementGeneration,
            preferences: .nativeDefault
        )
        try await environment.updateSpatialAudioPreferences(replacementApplication)
        let replacementProcessor = try XCTUnwrap(
            audioProcessorFactory.processor(at: 1)
        )
        let replacementUpdates = await replacementProcessor.preferenceUpdates()
        XCTAssertGreaterThan(replacementGeneration, firstGeneration)
        XCTAssertEqual(replacementUpdates, [.nativeDefault])
        _ = await environment.stop(sessionID: sessionID)
    }

    func testStoppedAudioGenerationCannotCompletePreferenceIntoRestart()
        async throws
    {
        let calls = MediaEnvironmentCallRecorder()
        let audioProcessorFactory = ControlledAudioProcessorFactory(
            calls: calls,
            finishStreamOnStop: false
        )
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls),
            audioProcessorFactory: audioProcessorFactory
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
        let firstProcessor = try XCTUnwrap(audioProcessorFactory.processor(at: 0))
        let firstRuntime = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 0,
            graphGeneration: 1
        )
        await firstProcessor.emit(firstRuntime)
        _ = try await iterator.next()
        let firstSnapshot = await environment.snapshot()
        XCTAssertEqual(
            firstSnapshot.audioRuntime?.runtime,
            firstRuntime
        )

        await firstProcessor.blockNextPreferenceUpdate()
        let staleApplication = SessionSpatialAudioPreferenceApplication(
            sessionID: sessionID,
            mediaGeneration: firstGeneration,
            preferences: SessionSpatialAudioPreferences(
                spatialAudioEnabled: false,
                headTrackingEnabled: false
            )
        )
        let staleUpdate = Task {
            try await environment.updateSpatialAudioPreferences(staleApplication)
        }
        await waitUntil {
            await firstProcessor.hasBlockedPreferenceUpdate()
        }

        _ = await environment.stop(sessionID: sessionID)
        let stoppedSnapshot = await environment.snapshot()
        XCTAssertNil(stoppedSnapshot.sessionID)
        XCTAssertNil(stoppedSnapshot.audioRuntime)

        stream = try await environment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: MediaEnvironmentControlProvider()
        )
        iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        let replacementSnapshot = await environment.snapshot()
        let replacementGeneration = replacementSnapshot.generation
        XCTAssertGreaterThan(replacementGeneration, firstGeneration)
        XCTAssertNil(replacementSnapshot.audioRuntime)

        await firstProcessor.resumeBlockedPreferenceUpdate()
        await XCTAssertThrowsErrorAsync(try await staleUpdate.value) { error in
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .staleAudioApplication
            )
        }

        let replacementProcessor = try XCTUnwrap(
            audioProcessorFactory.processor(at: 1)
        )
        let staleRuntime = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 99,
            graphGeneration: 99,
            cause: .recovery
        )
        let replacementRuntime = audioRuntimeEvent(
            sessionID: sessionID,
            sequence: 0,
            graphGeneration: 1
        )
        await firstProcessor.emit(staleRuntime)
        await replacementProcessor.emit(replacementRuntime)
        let expected = SessionMediaAudioRuntimeState(
            sessionID: sessionID,
            mediaGeneration: replacementGeneration,
            runtime: replacementRuntime
        )
        let forwarded = try await iterator.next()
        let currentSnapshot = await environment.snapshot()
        XCTAssertEqual(forwarded, .audioRuntime(expected))
        XCTAssertEqual(currentSnapshot.audioRuntime, expected)

        _ = await environment.stop(sessionID: sessionID)
    }

    func testInputApplicationIsGenerationScopedAcrossSameSessionReplacement() async throws {
        let calls = MediaEnvironmentCallRecorder()
        let environment = makeEnvironment(
            calls: calls,
            video: ControlledVideoReceiveProvider(calls: calls),
            audio: ControlledAudioReceiveProvider(calls: calls),
            input: ControlledRemoteInputProvider(calls: calls)
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
        let event = RemoteInputEvent.keyboard(KeyboardInputEvent(
            rawKeyCode: 4,
            characters: nil,
            isDown: true,
            modifiers: [],
            isRepeat: false
        ))
        let staleApplication = SessionInputApplication(
            sessionID: sessionID,
            mediaGeneration: firstGeneration,
            event: event
        )
        try await environment.sendInput(staleApplication)
        let staleReleaseApplication = SessionInputReleaseApplication(
            sessionID: sessionID,
            mediaGeneration: firstGeneration
        )
        try await environment.releaseInput(staleReleaseApplication)
        _ = await environment.stop(sessionID: sessionID)

        stream = try await environment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: MediaEnvironmentControlProvider()
        )
        iterator = stream.makeAsyncIterator()
        _ = try await iterator.next()
        let replacementGeneration = await environment.snapshot().generation

        await XCTAssertThrowsErrorAsync(
            try await environment.sendInput(staleApplication)
        ) { error in
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .staleInputApplication
            )
        }
        await XCTAssertThrowsErrorAsync(
            try await environment.releaseInput(staleReleaseApplication)
        ) { error in
            XCTAssertEqual(
                error as? SessionMediaEnvironmentError,
                .staleInputApplication
            )
        }
        try await environment.sendInput(SessionInputApplication(
            sessionID: sessionID,
            mediaGeneration: replacementGeneration,
            event: event
        ))
        try await environment.releaseInput(SessionInputReleaseApplication(
            sessionID: sessionID,
            mediaGeneration: replacementGeneration
        ))
        XCTAssertGreaterThan(replacementGeneration, firstGeneration)
        let inputSendCount = await calls.values().filter { $0 == "input.send" }.count
        let inputReleaseCount = await calls.values().filter { $0 == "input.release" }.count
        XCTAssertEqual(inputSendCount, 2)
        XCTAssertEqual(inputReleaseCount, 3)
        _ = await environment.stop(sessionID: sessionID)
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
                await calls.append("event.consumer.received")
                try Task.checkCancellation()
            }
        }
        guard await waitUntil(timeout: .seconds(5), {
            await calls.values().contains("event.consumer.received")
        }) else {
            consumer.cancel()
            _ = await consumer.result
            _ = await environment.stop(sessionID: sessionID)
            return
        }

        consumer.cancel()
        _ = await consumer.result
        guard await waitUntil(timeout: .seconds(5), {
            let snapshot = await environment.snapshot()
            return snapshot.sessionID == nil
        }) else {
            _ = await environment.stop(sessionID: sessionID)
            return
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

    func testNormalizedAssemblerCompletesAcrossDiscardedFECParityGaps() throws {
        var assembler = try NormalizedVideoAccessUnitAssembler(codec: .h264)
        let header = Data([0x01, 0x00, 0x00, 0x02, 0x04, 0x00, 0x00, 0x00])
        func packet(
            sequence: UInt32,
            block: UInt8,
            shard: Int,
            payload: Data,
            first: Bool = false,
            last: Bool = false
        ) -> ReceivedVideoPacket {
            ReceivedVideoPacket(
                sequenceNumber: sequence,
                frameIndex: 12,
                rtpTimestamp: 180_000,
                receiveTimeNanoseconds: UInt64(sequence),
                isFirstPacket: first,
                isLastPacket: last,
                payload: payload,
                fecBlockIndex: block,
                lastFECBlockIndex: 1,
                fecShardIndex: shard,
                dataShardCount: 2,
                parityShardCount: 1,
                fecPercentage: 50
            )
        }

        // Sequence 102 and 105 are parity shards and are intentionally absent.
        let packets = [
            packet(sequence: 104, block: 1, shard: 1, payload: Data([0x04]), last: true),
            packet(sequence: 100, block: 0, shard: 0, payload: header + Data([0x01]), first: true),
            packet(sequence: 103, block: 1, shard: 0, payload: Data([0x03])),
            packet(sequence: 101, block: 0, shard: 1, payload: Data([0x02]))
        ]
        let events = packets.flatMap { assembler.ingest($0) }
        let accessUnits = events.compactMap { event -> VideoAccessUnit? in
            guard case let .accessUnit(value) = event else { return nil }
            return value
        }
        let accessUnit = try XCTUnwrap(accessUnits.first)
        XCTAssertEqual(accessUnit.packetCount, 4)
        XCTAssertEqual(accessUnit.payload, Data([0x01, 0x02, 0x03, 0x04]))
        XCTAssertFalse(events.contains { event in
            if case .frameLost = event { return true }
            return false
        })
    }

    func testNormalizedAssemblerAcceptsDifferentShardCountsPerFECBlock() throws {
        var assembler = try NormalizedVideoAccessUnitAssembler(codec: .h264)
        let header = Data([0x01, 0x00, 0x00, 0x02, 0x03, 0x00, 0x00, 0x00])
        func packet(
            sequence: UInt32,
            block: UInt8,
            shard: Int,
            dataShardCount: Int,
            parityShardCount: Int = 1,
            fecPercentage: Int = 50,
            payload: Data,
            first: Bool = false,
            last: Bool = false
        ) -> ReceivedVideoPacket {
            ReceivedVideoPacket(
                sequenceNumber: sequence,
                frameIndex: 13,
                rtpTimestamp: 181_500,
                receiveTimeNanoseconds: UInt64(sequence),
                isFirstPacket: first,
                isLastPacket: last,
                payload: payload,
                fecBlockIndex: block,
                lastFECBlockIndex: 1,
                fecShardIndex: shard,
                dataShardCount: dataShardCount,
                parityShardCount: parityShardCount,
                fecPercentage: fecPercentage
            )
        }

        let packets = [
            packet(
                sequence: 103,
                block: 1,
                shard: 0,
                dataShardCount: 1,
                parityShardCount: 2,
                fecPercentage: 200,
                payload: Data([0x03]),
                last: true
            ),
            packet(
                sequence: 101,
                block: 0,
                shard: 1,
                dataShardCount: 2,
                payload: Data([0x02])
            ),
            packet(
                sequence: 100,
                block: 0,
                shard: 0,
                dataShardCount: 2,
                payload: header + Data([0x01]),
                first: true
            )
        ]
        let events = packets.flatMap { assembler.ingest($0) }
        let accessUnits = events.compactMap { event -> VideoAccessUnit? in
            guard case let .accessUnit(value) = event else { return nil }
            return value
        }

        let accessUnit = try XCTUnwrap(accessUnits.first)
        XCTAssertEqual(accessUnit.packetCount, 3)
        XCTAssertEqual(accessUnit.payload, Data([0x01, 0x02, 0x03]))
        XCTAssertFalse(events.contains { event in
            if case .frameLost = event { return true }
            return false
        })
    }

    func testNormalizedAssemblerRejectsFECMetadataDriftAndConflictingShards() throws {
        let header = Data([0x01, 0x00, 0x00, 0x02, 0x04, 0x00, 0x00, 0x00])
        func packet(
            sequence: UInt32,
            shard: Int,
            payload: Data,
            percentage: Int = 50
        ) -> ReceivedVideoPacket {
            ReceivedVideoPacket(
                sequenceNumber: sequence,
                frameIndex: 20,
                rtpTimestamp: 240_000,
                receiveTimeNanoseconds: UInt64(sequence),
                isFirstPacket: shard == 0,
                isLastPacket: false,
                payload: payload,
                fecBlockIndex: 0,
                lastFECBlockIndex: 1,
                fecShardIndex: shard,
                dataShardCount: 2,
                parityShardCount: 1,
                fecPercentage: percentage
            )
        }

        var metadataAssembler = try NormalizedVideoAccessUnitAssembler(codec: .h264)
        XCTAssertTrue(metadataAssembler.ingest(packet(
            sequence: 200,
            shard: 0,
            payload: header + Data([0x01])
        )).isEmpty)
        let metadataEvents = metadataAssembler.ingest(packet(
            sequence: 201,
            shard: 1,
            payload: Data([0x02]),
            percentage: 100
        ))
        XCTAssertTrue(metadataEvents.contains { event in
            guard case let .frameLost(loss) = event else { return false }
            return loss.reason == .inconsistentFrameMetadata
        })

        var duplicateAssembler = try NormalizedVideoAccessUnitAssembler(codec: .h264)
        XCTAssertTrue(duplicateAssembler.ingest(packet(
            sequence: 300,
            shard: 0,
            payload: header + Data([0x03])
        )).isEmpty)
        let duplicateEvents = duplicateAssembler.ingest(packet(
            sequence: 301,
            shard: 0,
            payload: Data([0x04])
        ))
        XCTAssertTrue(duplicateEvents.contains { event in
            guard case let .frameLost(loss) = event else { return false }
            return loss.reason == .conflictingDuplicate
        })
    }

    func testNormalizedAssemblerRejectsFECBlockOutsideEnvelope() throws {
        var assembler = try NormalizedVideoAccessUnitAssembler(codec: .h264)
        let events = assembler.ingest(ReceivedVideoPacket(
            sequenceNumber: 400,
            frameIndex: 21,
            rtpTimestamp: 300_000,
            receiveTimeNanoseconds: 400,
            isFirstPacket: true,
            isLastPacket: false,
            payload: Data([0x01, 0x00, 0x00, 0x02, 0x04, 0x00, 0x00, 0x00, 0x01]),
            fecBlockIndex: 2,
            lastFECBlockIndex: 1,
            fecShardIndex: 0,
            dataShardCount: 2,
            parityShardCount: 1,
            fecPercentage: 50
        ))
        XCTAssertTrue(events.contains { event in
            guard case let .frameLost(loss) = event else { return false }
            return loss.reason == .inconsistentFrameMetadata
        })
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

    func testPresentationSourcePublishesOnlySemanticDecoderAndFrameRevisions() throws {
        let source = StreamVideoPresentationSource()
        let sessionID = UUID()
        let mediaGeneration: UInt64 = 12
        let metadata = VideoColorMetadata.rec709VideoRange()
        let pixelBuffer = try makePixelBuffer()

        let began = source.beginSession(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        )
        XCTAssertEqual(
            began,
            .cleared(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: sessionID,
                    mediaGeneration: mediaGeneration,
                    revision: 1
                ),
                decoderGeneration: nil
            )
        )
        let started = source.consume(
            .sessionStarted(generation: 4, colorMetadata: metadata),
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        )
        XCTAssertEqual(
            started,
            .decoderStarted(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: sessionID,
                    mediaGeneration: mediaGeneration,
                    revision: 2
                ),
                contract: StreamVideoDecoderPresentationContract(
                    decoderGeneration: 4,
                    colorMetadata: metadata
                )
            )
        )

        let firstFrame = DecodedVideoFrame(
            generation: 4,
            frameID: 70,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: .zero,
            duration: CMTime(value: 1, timescale: 60),
            infoFlags: [],
            colorMetadata: metadata
        )
        let decoded = source.consume(
            .frame(firstFrame),
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        )
        let expectedContract = StreamVideoDecodedPresentationContract(
            decoderGeneration: 4,
            colorMetadata: metadata,
            decodedLayout: HDRDecodedPixelBufferLayout(
                pixelBuffer: pixelBuffer
            )
        )
        XCTAssertEqual(
            decoded,
            .decodedFrame(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: sessionID,
                    mediaGeneration: mediaGeneration,
                    revision: 3
                ),
                contract: expectedContract
            )
        )
        XCTAssertNil(source.consume(
            .frame(DecodedVideoFrame(
                generation: 4,
                frameID: 71,
                pixelBuffer: pixelBuffer,
                presentationTimeStamp: .zero,
                duration: CMTime(value: 1, timescale: 60),
                infoFlags: [],
                colorMetadata: metadata
            )),
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        ))
        XCTAssertEqual(source.snapshot().presentationRevision, 3)
        XCTAssertEqual(source.snapshot().latestFrameID, 71)

        XCTAssertEqual(
            source.discardFrames(
                sessionID: sessionID,
                mediaGeneration: mediaGeneration
            ),
            .cleared(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: sessionID,
                    mediaGeneration: mediaGeneration,
                    revision: 4
                ),
                decoderGeneration: 4
            )
        )
    }

    func testPresentationSourceRevisionExhaustionFailsClosed() throws {
        let source = StreamVideoPresentationSource(
            initialPresentationRevision: .max
        )
        let sessionID = UUID()

        XCTAssertNil(source.beginSession(
            sessionID: sessionID,
            mediaGeneration: 1
        ))
        XCTAssertNil(source.consume(
            .sessionStarted(
                generation: 1,
                colorMetadata: .rec709VideoRange()
            ),
            sessionID: sessionID,
            mediaGeneration: 1
        ))

        let snapshot = source.snapshot()
        XCTAssertEqual(snapshot.presentationRevision, .max)
        XCTAssertTrue(snapshot.isPresentationRevisionExhausted)
        XCTAssertNil(snapshot.decoderGeneration)
        XCTAssertNil(snapshot.latestFrameID)
    }

    func testMediaEnvironmentForwardsGenerationOwnedVideoPresentationEvents()
        async throws {
        let calls = MediaEnvironmentCallRecorder()
        let video = ControlledVideoReceiveProvider(calls: calls)
        let audio = ControlledAudioReceiveProvider(calls: calls)
        let input = ControlledRemoteInputProvider(calls: calls)
        let environment = makeEnvironment(
            calls: calls,
            video: video,
            audio: audio,
            input: input,
            videoProcessorFactory: PublishingVideoProcessorFactory(calls: calls)
        )
        let sessionID = UUID()
        let configuration = makeConfiguration(sessionID: sessionID)
        let stream = try await environment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: RecordingLifecycleControlProvider()
        )
        var iterator = stream.makeAsyncIterator()
        var observed: StreamVideoPresentationEvent?
        for _ in 0..<4 {
            guard let event = try await iterator.next() else { break }
            if case let .videoPresentation(presentation) = event {
                observed = presentation
                break
            }
        }

        XCTAssertEqual(
            observed,
            .decoderStarted(
                ownership: StreamVideoPresentationOwnership(
                    sessionID: sessionID,
                    mediaGeneration: 1,
                    revision: 1
                ),
                contract: StreamVideoDecoderPresentationContract(
                    decoderGeneration: 9,
                    colorMetadata: configuration.video.colorMetadata
                )
            )
        )
        _ = await environment.stop(sessionID: sessionID)
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

    func testNativeVideoProcessorMergesLifecycleWithMobileContinuity()
        async throws {
        let source = StreamVideoPresentationSource()
        let control = RecordingLifecycleControlProvider()
        let sessionID = UUID()
        let mediaGeneration: UInt64 = 12
        let processor = try await NativeSessionVideoProcessorFactory(
            presentationSource: source
        ).makeVideoProcessor(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            configuration: makeConfiguration(sessionID: sessionID).video,
            controlProvider: control
        )
        let pictureInPictureGeneration = MobilePictureInPictureGeneration(
            mediaGeneration: mediaGeneration,
            pictureInPictureGeneration: 1
        )!
        let hidden = lifecycleApplication(
            sessionID: sessionID,
            generation: mediaGeneration,
            revision: 1,
            isVisible: false,
            isFocused: false,
            drawableSize: PixelSize(width: 1_920, height: 1_080)
        )
        try await processor.applyLifecycle(hidden)

        try await processor.applyMobileVideo(SessionMobileVideoApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            generation: pictureInPictureGeneration,
            revision: MobileMediaGenerationRevision(rawValue: 1)!,
            directive: .continuePictureInPictureDelivery
        ))
        let pictureInPictureIDRCount = await control.idrCount
        XCTAssertEqual(pictureInPictureIDRCount, 1)

        try await processor.applyMobileVideo(SessionMobileVideoApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            generation: pictureInPictureGeneration,
            revision: MobileMediaGenerationRevision(rawValue: 2)!,
            directive: .drainTransportWithoutDecoding
        ))
        let visible = lifecycleApplication(
            sessionID: sessionID,
            generation: mediaGeneration,
            revision: 2,
            isVisible: true,
            isFocused: true,
            drawableSize: PixelSize(width: 1_920, height: 1_080)
        )
        try await processor.applyLifecycle(visible)
        let audioOnlyIDRCount = await control.idrCount
        XCTAssertEqual(audioOnlyIDRCount, 1)

        let foreground = SessionMobileVideoApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            generation: pictureInPictureGeneration,
            revision: MobileMediaGenerationRevision(rawValue: 3)!,
            directive: .continueForegroundPresentation
        )
        try await processor.applyMobileVideo(foreground)
        try await processor.applyMobileVideo(foreground)
        let foregroundIDRCount = await control.idrCount
        XCTAssertEqual(foregroundIDRCount, 2)

        try await processor.applyMobileVideo(SessionMobileVideoApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            generation: pictureInPictureGeneration,
            revision: MobileMediaGenerationRevision(rawValue: 4)!,
            directive: .drainTransportWithoutDecoding
        ))
        XCTAssertNil(source.currentFrame())
        await processor.stop()
    }

    func testNativeVideoProcessorRetriesSameMobileResumeAfterIDRFailure()
        async throws {
        let source = StreamVideoPresentationSource()
        let control = FailingOnceLifecycleControlProvider()
        let sessionID = UUID()
        let mediaGeneration: UInt64 = 13
        let processor = try await NativeSessionVideoProcessorFactory(
            presentationSource: source
        ).makeVideoProcessor(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            configuration: makeConfiguration(sessionID: sessionID).video,
            controlProvider: control
        )
        let generation = try XCTUnwrap(MobilePictureInPictureGeneration(
            mediaGeneration: mediaGeneration,
            pictureInPictureGeneration: 1
        ))
        let drain = SessionMobileVideoApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            generation: generation,
            revision: try XCTUnwrap(
                MobileMediaGenerationRevision(rawValue: 1)
            ),
            directive: .drainTransportWithoutDecoding
        )
        let resume = SessionMobileVideoApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            generation: generation,
            revision: try XCTUnwrap(
                MobileMediaGenerationRevision(rawValue: 2)
            ),
            directive: .continueForegroundPresentation
        )

        try await processor.applyMobileVideo(drain)
        do {
            try await processor.applyMobileVideo(resume)
            XCTFail("The first synthetic IDR request must fail.")
        } catch {
            XCTAssertEqual(
                error as? MediaEnvironmentTestError,
                .receiverFailure
            )
        }
        try await processor.applyMobileVideo(resume)

        let idrCount = await control.idrCount
        XCTAssertEqual(idrCount, 2)
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
            channelLayout: .stereo,
            streamCount: 1,
            coupledStreamCount: 1,
            samplesPerFrame: 240,
            channelMapping: [0, 1],
            maximumPacketSize: 1_400
        )
        let engine = MediaEnvironmentAudioEngineClient()
        let factory = NativeSessionAudioProcessorFactory(
            initialPreferences: SessionSpatialAudioPreferences(
                spatialAudioEnabled: false,
                headTrackingEnabled: false
            ),
            engineClientFactory: { engine },
            routeEventSourceFactory: {
                MediaEnvironmentAudioRouteEventSource()
            },
            eventTimeProvider: { 0 }
        )
        let processor = try await factory.makeAudioProcessor(
            sessionID: UUID(),
            configuration: configuration
        )
        let runtimeEvents = await processor.audioRuntimeEvents()
        var runtimeIterator = runtimeEvents.makeAsyncIterator()
        let initialRuntime = await runtimeIterator.next()
        XCTAssertEqual(initialRuntime?.mobileAudioSessionActive, true)
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
        let closeTask = Task {
            try await processor.consume(.closed)
        }
        let reachedRealtimeCapacity = await waitUntil {
            engine.pendingCompletionCount()
                == AudioSessionPipeline.realtimeMaximumScheduledBuffers
        }
        guard reachedRealtimeCapacity else {
            closeTask.cancel()
            _ = try? await closeTask.value
            await processor.stop()
            return
        }
        engine.completeOldestScheduledBuffer()
        becameReady = try await closeTask.value || becameReady
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
        videoProcessorFactory: (any SessionVideoProcessorCreating)? = nil,
        audioProcessorFactory: (any SessionAudioProcessorCreating)? = nil,
        videoPresentationSource: StreamVideoPresentationSource? = nil,
        tvVisionPlatformCoordinatorFactory: @escaping @Sendable () throws
            -> TVVisionPlatformPresentationCoordinator = {
                try TVVisionPlatformPresentationCoordinator()
            }
    ) -> NativeSessionMediaEnvironment {
        NativeSessionMediaEnvironment(
            videoReceiveProvider: video,
            audioReceiveProvider: audio,
            remoteInputProvider: input,
            videoProcessorFactory: videoProcessorFactory
                ?? RecordingVideoProcessorFactory(calls: calls),
            audioProcessorFactory: audioProcessorFactory
                ?? RecordingAudioProcessorFactory(calls: calls),
            videoPresentationSource: videoPresentationSource,
            tvVisionPlatformCoordinatorFactory:
                tvVisionPlatformCoordinatorFactory,
            teardownGracePeriod: .seconds(1)
        )
    }

    private func tvVisionPresentationOwnership(
        sessionID: UUID,
        mediaGeneration: UInt64,
        presentationGeneration: UInt64 = 1,
        platform: TVVisionPlatform = .tvOS
    ) throws -> TVVisionPresentationOwnership {
        try TVVisionPresentationOwnership(
            platform: platform,
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            presentationGeneration: TVVisionGeneration(
                domain: .presentation,
                rawValue: presentationGeneration
            ),
            inputGeneration: TVVisionGeneration(
                domain: .input,
                rawValue: mediaGeneration
            )
        )
    }

    private func tvVisionSceneUpdate(
        ownership: TVVisionPresentationOwnership,
        revision: UInt64 = 1
    ) throws -> TVVisionStreamGeometryBindingUpdate {
        let semanticRevision = try TVVisionSemanticRevision(rawValue: revision)
        let surfaceGeneration = try TVVisionGeneration(
            domain: .surface,
            rawValue: ownership.presentationGeneration.rawValue
        )
        let geometry = try TVVisionSurfaceGeometry(
            platform: ownership.platform,
            surfaceGeneration: surfaceGeneration,
            viewBounds: TVVisionRect(x: 0, y: 0, width: 640, height: 360),
            windowBounds: TVVisionRect(x: 0, y: 0, width: 640, height: 360),
            safeAreaInsets: .zero,
            scale: 2
        )
        let scene = try TVVisionSceneSurfaceSnapshot(
            platform: ownership.platform,
            revision: semanticRevision,
            surfaceGeneration: surfaceGeneration,
            activity: .active,
            attachment: .attached,
            isVisible: true,
            geometry: geometry
        )
        let sourceSize = PixelSize(width: 1_920, height: 1_080)
        let coordinates = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: revision,
            sourceSize: sourceSize,
            drawableSize: geometry.drawableSize,
            mode: .fit
        ))
        return TVVisionStreamGeometryBindingUpdate(
            platform: ownership.platform,
            surfaceGeneration: surfaceGeneration,
            revision: semanticRevision,
            status: .active,
            binding: TVVisionStreamGeometryBindingSnapshot(
                platform: ownership.platform,
                surfaceGeneration: surfaceGeneration,
                revision: semanticRevision,
                sceneSurfaceSnapshot: scene,
                isFocusEligible: true,
                coordinateSnapshot: coordinates,
                inputReferenceSize: sourceSize
            )
        )
    }

    private func audioRuntimeEvent(
        sessionID: UUID,
        sequence: UInt64,
        graphGeneration: UInt64,
        cause: SessionAudioRuntimeEventCause = .initial,
        stage: SessionAudioRuntimeStage = .running,
        spatialRuntime: SpatialAudioRuntimeSnapshot? = nil,
        routeCapability: SpatialAudioRouteCapabilitySnapshot? = nil,
        entitlement: SpatialAudioEntitlementState = .granted
    ) -> SessionAudioRuntimeEvent {
        let routeCapability = routeCapability
            ?? SpatialAudioRouteCapabilitySnapshot(
                revision: spatialRuntime?.revision ?? .init(rawValue: 0),
                outputAvailable: true,
                systemSpatialSupport: .supported,
                currentOutputChannelCount: 2,
                maximumOutputChannelCount: 8
            )
        return SessionAudioRuntimeEvent(
            sessionID: sessionID,
            sequence: sequence,
            graphGeneration: graphGeneration,
            cause: cause,
            stage: stage,
            spatialRuntime: spatialRuntime,
            routeCapability: routeCapability,
            entitlement: entitlement,
            preferences: .nativeDefault,
            concealedFrameCount: 0,
            lastAction: .none
        )
    }

    private func spatialAudioRuntime(
        revision: UInt64,
        platformStrategy: SpatialAudioPlatformStrategy = .environmentListener,
        presentationMode: SpatialAudioPresentationMode
    ) -> SpatialAudioRuntimeSnapshot {
        SpatialAudioRuntimeSnapshot(
            revision: SpatialAudioSemanticRevision(rawValue: revision),
            layoutSignature: StreamAudioChannelLayout.stereo.signature,
            graphMode: .environmentAmbienceBed,
            platformStrategy: platformStrategy,
            routeSupport: .supported,
            presentationMode: presentationMode,
            fallbackReason: nil
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

    private func mobileRuntimeApplication(
        sessionID: UUID,
        mediaGeneration: UInt64,
        revision: UInt64,
        sceneActivity: AppSceneActivity,
        pictureInPictureLifecycle: MobilePictureInPictureLifecycle? = nil,
        isAudioSessionActive: Bool? = nil,
        pictureInPictureMediaGeneration: UInt64? = nil
    ) -> SessionMobileRuntimeApplication {
        let pictureInPictureGeneration = MobilePictureInPictureGeneration(
            mediaGeneration: pictureInPictureMediaGeneration ?? mediaGeneration,
            pictureInPictureGeneration: 1
        )!
        let pictureInPicture = pictureInPictureLifecycle.map { lifecycle in
            MobilePictureInPictureSnapshot(
                generation: pictureInPictureGeneration,
                revision: MobilePictureInPictureRevision(rawValue: revision),
                state: MobilePictureInPictureSemanticState(
                    isPrepared: true,
                    capability: .possible,
                    lifecycle: lifecycle,
                    frameSink: .ready(decoderGeneration: 1)!,
                    restoration: .idle,
                    failure: nil
                )
            )
        }
        return SessionMobileRuntimeApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            revision: SessionMobileRuntimeRevision(rawValue: revision)!,
            generation: pictureInPictureGeneration,
            platform: .iOS,
            sceneActivity: sceneActivity,
            surfaceGeneration: nil,
            sceneWindow: nil,
            displayEDR: nil,
            pictureInPicture: pictureInPicture,
            isAudioSessionActive: isAudioSessionActive,
            isAudioContinuityPermitted: isAudioSessionActive == true,
            preferences: .defaults,
            capabilities: PlatformContinuityCapabilities(
                supportsAudioBackgroundMode: true,
                supportsPictureInPicture: true,
                hasAudioBackgroundModeDeclared: true
            ),
            foregroundBaseline: .active
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
                channelLayout: .stereo,
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

    @discardableResult
    private func waitUntil(
        timeout: Duration = .seconds(2),
        _ condition: @escaping @Sendable () async -> Bool
    ) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if await condition() { return true }
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Timed out waiting for media environment state.")
        return false
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
    private var completions: [@Sendable () -> Void] = []
    private var stopped = false

    func configure(
        _ configuration: StreamAudioConfiguration,
        graphIntent: SpatialAudioGraphIntent
    ) throws -> SpatialAudioRuntimeSnapshot {
        try configuration.validate()
        withLock { stopped = false }
        return makeNonspatialRuntime(
            configuration: configuration,
            graphIntent: graphIntent
        )
    }

    func start() throws {
        withLock { stopped = false }
    }

    func schedule(
        _ buffer: DecodedPCMBuffer,
        completion: @escaping @Sendable () -> Void
    ) throws {
        withLock {
            buffers.append(buffer)
            completions.append(completion)
        }
    }

    func stop(drain: Bool) {
        _ = drain
        withLock {
            stopped = true
            buffers.removeAll()
            completions.removeAll()
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

    func mobileAudioSessionActiveReadback() -> Bool? {
        withLock { !stopped }
    }

    func scheduledBuffers() -> [DecodedPCMBuffer] {
        withLock { buffers }
    }

    func completeOldestScheduledBuffer() {
        let completion = withLock {
            completions.isEmpty ? nil : completions.removeFirst()
        }
        completion?()
    }

    func pendingCompletionCount() -> Int {
        withLock { completions.count }
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

private actor TVVisionVideoDeliveryPumpRecorder {
    private var receivedRevisions: [UInt64] = []
    private var blockedRevision: UInt64?
    private var isBlocked = false
    private var blockedWaiters: [CheckedContinuation<Void, Never>] = []
    private var resumeContinuation: CheckedContinuation<Void, Never>?
    private var overflows = 0

    func block(revision: UInt64) {
        blockedRevision = revision
    }

    func receive(_ delivery: StreamVideoPresentationDelivery) async {
        receivedRevisions.append(delivery.ownership.revision)
        guard delivery.ownership.revision == blockedRevision else { return }
        isBlocked = true
        let waiters = blockedWaiters
        blockedWaiters.removeAll()
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            resumeContinuation = continuation
        }
        isBlocked = false
        blockedRevision = nil
    }

    func waitUntilBlocked() async {
        guard !isBlocked else { return }
        await withCheckedContinuation { continuation in
            blockedWaiters.append(continuation)
        }
    }

    func resume() {
        resumeContinuation?.resume()
        resumeContinuation = nil
    }

    func revisions() -> [UInt64] {
        receivedRevisions
    }

    func recordOverflow() {
        overflows += 1
    }

    func overflowCount() -> Int {
        overflows
    }
}

private actor SuspendingTVVisionPresentationActionClient:
    TVVisionPlatformPresentationActionApplying
{
    private let suspendedKind: TVVisionPlatformPresentationEffectKind
    private var applications: [TVVisionPlatformPresentationActionApplication] = []
    private var didSuspend = false
    private var isSuspended = false
    private var suspensionWaiters: [CheckedContinuation<Void, Never>] = []
    private var resumeContinuation: CheckedContinuation<Void, Never>?

    init(suspending kind: TVVisionPlatformPresentationEffectKind) {
        suspendedKind = kind
    }

    func apply(
        _ application: TVVisionPlatformPresentationActionApplication
    ) async throws {
        applications.append(application)
        guard !didSuspend, application.effect.kind == suspendedKind else { return }
        didSuspend = true
        isSuspended = true
        let waiters = suspensionWaiters
        suspensionWaiters.removeAll()
        waiters.forEach { $0.resume() }
        await withCheckedContinuation { continuation in
            resumeContinuation = continuation
        }
        isSuspended = false
    }

    func waitUntilSuspended() async {
        guard !isSuspended else { return }
        await withCheckedContinuation { continuation in
            suspensionWaiters.append(continuation)
        }
    }

    var isCurrentlySuspended: Bool {
        isSuspended
    }

    func resume() {
        resumeContinuation?.resume()
        resumeContinuation = nil
    }

    func effectKinds() -> [TVVisionPlatformPresentationEffectKind] {
        applications.map(\.effect.kind)
    }
}

private actor FailingTVVisionPresentationActionClient:
    TVVisionPlatformPresentationActionApplying
{
    private let failingKind: TVVisionPlatformPresentationEffectKind
    private var applications: [TVVisionPlatformPresentationActionApplication] = []

    init(failing kind: TVVisionPlatformPresentationEffectKind) {
        failingKind = kind
    }

    func apply(
        _ application: TVVisionPlatformPresentationActionApplication
    ) async throws {
        applications.append(application)
        if application.effect.kind == failingKind {
            throw MediaEnvironmentTestError.receiverFailure
        }
    }

    func effectKinds() -> [TVVisionPlatformPresentationEffectKind] {
        applications.map(\.effect.kind)
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

private actor RecordingMobileControlProvider: SessionControlProvider {
    private var applications: [SessionMobileControlApplication] = []

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

    func applyMobileControl(
        _ application: SessionMobileControlApplication
    ) async throws {
        applications.append(application)
    }

    func mobileApplications() -> [SessionMobileControlApplication] {
        applications
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

private actor FailingOnceLifecycleControlProvider: SessionControlProvider {
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
        idrCount += 1
        if idrCount == 1 {
            throw MediaEnvironmentTestError.receiverFailure
        }
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
        controlProvider: any SessionControlProvider,
        presentationEventSink: @escaping @Sendable (
            StreamVideoPresentationEvent
        ) -> Void
    ) async throws -> any SessionVideoProcessing {
        _ = sessionID
        _ = mediaGeneration
        _ = configuration
        _ = controlProvider
        _ = presentationEventSink
        return processor
    }
}

private actor ControlledLifecycleVideoProcessor: SessionVideoProcessing {
    private(set) var applications: [SessionLifecycleApplication] = []
    private(set) var mobileApplications: [SessionMobileVideoApplication] = []
    private let blockFirstApplication: Bool
    private let blockFirstMobileApplication: Bool
    private var blockMobileStopApplication: Bool
    private var blockResourceStop: Bool
    private var firstApplicationContinuation: CheckedContinuation<Void, Never>?
    private var firstMobileApplicationContinuation:
        CheckedContinuation<Void, Never>?
    private var mobileStopContinuation: CheckedContinuation<Void, Never>?
    private var resourceStopContinuation: CheckedContinuation<Void, Never>?

    init(
        blockFirstApplication: Bool = false,
        blockFirstMobileApplication: Bool = false,
        blockMobileStopApplication: Bool = false,
        blockResourceStop: Bool = false
    ) {
        self.blockFirstApplication = blockFirstApplication
        self.blockFirstMobileApplication = blockFirstMobileApplication
        self.blockMobileStopApplication = blockMobileStopApplication
        self.blockResourceStop = blockResourceStop
    }

    var applicationCount: Int { applications.count }
    var mobileApplicationCount: Int { mobileApplications.count }

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

    func applyMobileVideo(
        _ application: SessionMobileVideoApplication
    ) async throws {
        mobileApplications.append(application)
        if blockFirstMobileApplication,
           mobileApplications.count == 1 {
            await withCheckedContinuation { continuation in
                firstMobileApplicationContinuation = continuation
            }
        }
        await blockMobileStopIfRequired(application)
    }

    private func blockMobileStopIfRequired(
        _ application: SessionMobileVideoApplication
    ) async {
        guard blockMobileStopApplication,
              application.directive == .stop else { return }
        await withCheckedContinuation { continuation in
            mobileStopContinuation = continuation
        }
    }

    func resumeFirstApplication() {
        firstApplicationContinuation?.resume()
        firstApplicationContinuation = nil
    }

    func resumeFirstMobileApplication() {
        firstMobileApplicationContinuation?.resume()
        firstMobileApplicationContinuation = nil
    }

    var isMobileStopBlocked: Bool { mobileStopContinuation != nil }
    var isResourceStopBlocked: Bool { resourceStopContinuation != nil }

    func resumeMobileStopApplication() {
        blockMobileStopApplication = false
        mobileStopContinuation?.resume()
        mobileStopContinuation = nil
    }

    func resumeResourceStop() {
        blockResourceStop = false
        resourceStopContinuation?.resume()
        resourceStopContinuation = nil
    }

    func releaseAllBlocks() {
        blockMobileStopApplication = false
        blockResourceStop = false
        mobileStopContinuation?.resume()
        mobileStopContinuation = nil
        resourceStopContinuation?.resume()
        resourceStopContinuation = nil
    }

    func stop() async {
        guard blockResourceStop else { return }
        await withCheckedContinuation { continuation in
            resourceStopContinuation = continuation
        }
    }
}

private actor StopCompletionRecorder {
    private var reports: [SessionTeardownReport?] = []

    var count: Int { reports.count }

    func record(_ report: SessionTeardownReport?) {
        reports.append(report)
    }
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
        controlProvider: any SessionControlProvider,
        presentationEventSink: @escaping @Sendable (
            StreamVideoPresentationEvent
        ) -> Void
    ) async throws -> any SessionVideoProcessing {
        _ = sessionID
        _ = mediaGeneration
        _ = configuration
        _ = controlProvider
        _ = presentationEventSink
        await calls.append("video.processor.start")
        return RecordingVideoProcessor(calls: calls)
    }
}

private struct PublishingVideoProcessorFactory: SessionVideoProcessorCreating {
    let calls: MediaEnvironmentCallRecorder

    func makeVideoProcessor(
        sessionID: UUID,
        mediaGeneration: UInt64,
        configuration: NegotiatedVideoStreamConfiguration,
        controlProvider: any SessionControlProvider,
        presentationEventSink: @escaping @Sendable (
            StreamVideoPresentationEvent
        ) -> Void
    ) async throws -> any SessionVideoProcessing {
        _ = controlProvider
        presentationEventSink(.decoderStarted(
            ownership: StreamVideoPresentationOwnership(
                sessionID: sessionID,
                mediaGeneration: mediaGeneration,
                revision: 1
            ),
            contract: StreamVideoDecoderPresentationContract(
                decoderGeneration: 9,
                colorMetadata: configuration.colorMetadata
            )
        ))
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

    func applyMobileVideo(
        _ application: SessionMobileVideoApplication
    ) async throws {
        _ = application
        await calls.append("video.mobile")
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
    private let eventStream: AsyncStream<SessionAudioRuntimeEvent>
    private let eventContinuation: AsyncStream<SessionAudioRuntimeEvent>.Continuation

    init(calls: MediaEnvironmentCallRecorder) {
        self.calls = calls
        let pair = AsyncStream<SessionAudioRuntimeEvent>.makeStream()
        eventStream = pair.stream
        eventContinuation = pair.continuation
    }

    func consume(_ event: AudioReceiveEvent) async throws -> Bool {
        _ = event
        await calls.append("audio.consume")
        return true
    }

    func audioRuntimeEvents() async -> AsyncStream<SessionAudioRuntimeEvent> {
        eventStream
    }

    func updateSpatialAudioPreferences(
        _ preferences: SessionSpatialAudioPreferences
    ) async throws {
        _ = preferences
    }

    func applyMobileAudio(
        _ application: SessionMobileAudioApplication
    ) async throws {
        _ = application
        await calls.append("audio.mobile")
    }

    func stop() async {
        eventContinuation.finish()
        await calls.append("audio.processor.stop")
    }
}

private final class ControlledAudioProcessorFactory:
    SessionAudioProcessorCreating,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let calls: MediaEnvironmentCallRecorder
    private let finishStreamOnStop: Bool
    private var processors: [ControlledAudioProcessor] = []

    init(
        calls: MediaEnvironmentCallRecorder,
        finishStreamOnStop: Bool = true
    ) {
        self.calls = calls
        self.finishStreamOnStop = finishStreamOnStop
    }

    func makeAudioProcessor(
        sessionID: UUID,
        configuration: NegotiatedAudioStreamConfiguration
    ) async throws -> any SessionAudioProcessing {
        _ = sessionID
        _ = configuration
        let processor = ControlledAudioProcessor(
            calls: calls,
            finishStreamOnStop: finishStreamOnStop
        )
        withLock { processors.append(processor) }
        await calls.append("audio.processor.start")
        return processor
    }

    func processor(at index: Int) -> ControlledAudioProcessor? {
        withLock {
            processors.indices.contains(index) ? processors[index] : nil
        }
    }

    private func withLock<T>(_ operation: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try operation()
    }
}

private actor ControlledAudioProcessor: SessionAudioProcessing {
    private let calls: MediaEnvironmentCallRecorder
    private let finishStreamOnStop: Bool
    private let eventStream: AsyncStream<SessionAudioRuntimeEvent>
    private let eventContinuation: AsyncStream<SessionAudioRuntimeEvent>.Continuation
    private var appliedPreferences: [SessionSpatialAudioPreferences] = []
    private var appliedMobileApplications: [SessionMobileAudioApplication] = []
    private var mobileApplicationFailuresRemaining = 0
    private var shouldBlockNextPreferenceUpdate = false
    private var blockedPreferenceContinuation:
        CheckedContinuation<Void, Never>?

    init(
        calls: MediaEnvironmentCallRecorder,
        finishStreamOnStop: Bool
    ) {
        self.calls = calls
        self.finishStreamOnStop = finishStreamOnStop
        let pair = AsyncStream<SessionAudioRuntimeEvent>.makeStream()
        eventStream = pair.stream
        eventContinuation = pair.continuation
    }

    func consume(_ event: AudioReceiveEvent) async throws -> Bool {
        _ = event
        await calls.append("audio.consume")
        return true
    }

    func audioRuntimeEvents() async -> AsyncStream<SessionAudioRuntimeEvent> {
        eventStream
    }

    func updateSpatialAudioPreferences(
        _ preferences: SessionSpatialAudioPreferences
    ) async throws {
        if shouldBlockNextPreferenceUpdate {
            shouldBlockNextPreferenceUpdate = false
            await withCheckedContinuation { continuation in
                blockedPreferenceContinuation = continuation
            }
        }
        appliedPreferences.append(preferences)
    }

    func applyMobileAudio(
        _ application: SessionMobileAudioApplication
    ) async throws {
        appliedMobileApplications.append(application)
        if mobileApplicationFailuresRemaining > 0 {
            mobileApplicationFailuresRemaining -= 1
            throw MediaEnvironmentTestError.receiverFailure
        }
    }

    func mobileApplications() -> [SessionMobileAudioApplication] {
        appliedMobileApplications
    }

    func failNextMobileApplications(count: Int) {
        mobileApplicationFailuresRemaining = count
    }

    func preferenceUpdates() -> [SessionSpatialAudioPreferences] {
        appliedPreferences
    }

    func blockNextPreferenceUpdate() {
        shouldBlockNextPreferenceUpdate = true
    }

    func hasBlockedPreferenceUpdate() -> Bool {
        blockedPreferenceContinuation != nil
    }

    func resumeBlockedPreferenceUpdate() {
        blockedPreferenceContinuation?.resume()
        blockedPreferenceContinuation = nil
    }

    func emit(_ event: SessionAudioRuntimeEvent) {
        eventContinuation.yield(event)
    }

    func finish() {
        eventContinuation.finish()
    }

    func stop() async {
        if finishStreamOnStop {
            eventContinuation.finish()
        }
        await calls.append("audio.processor.stop")
    }
}

private final class MediaEnvironmentAudioRouteEventSource:
    SpatialAudioRouteMonitorEventSourcing,
    @unchecked Sendable
{
    func start(
        handler: @escaping @Sendable (SpatialAudioRouteMonitorEvent) -> Void
    ) {
        _ = handler
    }

    func stop() {}
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
