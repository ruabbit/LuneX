import XCTest
import AVFAudio

final class AudioPipelineTests: XCTestCase {
    func testMoonlightChannelLayoutsPreserveSemanticOrderAndCoreAudioTags() throws {
        let mono = try StreamAudioChannelLayout.resolve(channelCount: 1)
        let stereo = try StreamAudioChannelLayout.resolve(channelCount: 2)
        let surround5Point1 = try StreamAudioChannelLayout.resolve(channelCount: 6)
        let surround7Point1 = try StreamAudioChannelLayout.resolve(channelCount: 8)

        XCTAssertEqual(mono.channels, [.frontCenter])
        XCTAssertEqual(mono.coreAudioLayoutTag, kAudioChannelLayoutTag_Mono)
        XCTAssertEqual(mono.spatialEligibility, .nonspatialMono)
        XCTAssertEqual(stereo.channels, [.frontLeft, .frontRight])
        XCTAssertEqual(stereo.moonlightChannelMask, 0x0003)
        XCTAssertEqual(stereo.coreAudioLayoutTag, kAudioChannelLayoutTag_Stereo)
        XCTAssertEqual(
            surround5Point1.channels,
            [
                .frontLeft,
                .frontRight,
                .frontCenter,
                .lowFrequencyEffects,
                .backLeft,
                .backRight
            ]
        )
        XCTAssertEqual(surround5Point1.moonlightChannelMask, 0x003F)
        XCTAssertEqual(
            surround5Point1.coreAudioLayoutTag,
            kAudioChannelLayoutTag_WAVE_5_1_A
        )
        XCTAssertEqual(
            surround7Point1.channels,
            [
                .frontLeft,
                .frontRight,
                .frontCenter,
                .lowFrequencyEffects,
                .backLeft,
                .backRight,
                .sideLeft,
                .sideRight
            ]
        )
        XCTAssertEqual(surround7Point1.moonlightChannelMask, 0x063F)
        XCTAssertEqual(
            surround7Point1.coreAudioLayoutTag,
            kAudioChannelLayoutTag_WAVE_7_1
        )
        XCTAssertEqual(surround7Point1.spatialEligibility, .ambienceBed)
        XCTAssertEqual(
            surround7Point1.signature,
            StreamAudioChannelLayoutSignature(
                identifier: .wave7Point1,
                channelCount: 8,
                moonlightChannelMask: 0x063F,
                coreAudioLayoutTagRawValue: UInt32(kAudioChannelLayoutTag_WAVE_7_1)
            )
        )
    }

    func testMoonlightChannelLayoutRejectsAmbiguousAndOutOfRangeCounts() {
        for channelCount in [Int.min, -1, 0, 3, 4, 5, 7, 9, Int.max] {
            XCTAssertThrowsError(
                try StreamAudioChannelLayout.resolve(channelCount: channelCount)
            ) { error in
                XCTAssertEqual(
                    error as? StreamAudioChannelLayoutError,
                    .unsupportedChannelCount(channelCount)
                )
            }
        }
    }

    func testPipelineRejectsReorderedPCMWithMatchingRawChannelCount() async throws {
        let client = StubAudioEngineClient()
        let pipeline = AudioSessionPipeline(engineClient: client)
        let configuration = StreamAudioConfiguration(
            sampleRate: 48_000,
            channelLayout: .wave5Point1,
            latencyPolicy: .lowLatency
        )
        _ = try await pipeline.configure(
            configuration,
            graphIntent: makeAudioGraphIntent(
                channelCount: configuration.channelCount
            )
        )
        _ = try await pipeline.start()
        let reorderedLayout = StreamAudioChannelLayout(
            kind: .wave5Point1,
            channels: [
                .frontRight,
                .frontLeft,
                .frontCenter,
                .lowFrequencyEffects,
                .backLeft,
                .backRight
            ],
            moonlightChannelMask: 0x003F,
            coreAudioLayoutTagRawValue: StreamAudioChannelLayout.wave5Point1
                .coreAudioLayoutTagRawValue,
            spatialEligibility: .ambienceBed
        )
        let decoded = DecodedPCMBuffer(
            sequenceNumber: 1,
            rtpTimestamp: 0,
            format: .signedInt16(
                sampleRate: 48_000,
                channelLayout: reorderedLayout
            ),
            frameCount: 2,
            interleavedSamples: [Int16](repeating: 1, count: 12)
        )

        XCTAssertEqual(decoded.format.channelCount, configuration.channelCount)
        await AudioPipelineXCTAssertThrowsErrorAsync(
            try await pipeline.schedule(decoded)
        ) { error in
            XCTAssertEqual(error as? AudioPipelineError, .invalidPCMBuffer)
        }
    }

    func testAudioPipelineConfiguresStartsAndStopsWithRouteSnapshot() async throws {
        let client = StubAudioEngineClient(route: AudioRouteSnapshot(
            outputNames: ["USB DAC"],
            sampleRate: 48_000,
            outputChannelCount: 2,
            preferredBufferDuration: 0.005
        ))
        let pipeline = AudioSessionPipeline(engineClient: client, now: Date(timeIntervalSince1970: 1))
        let graphIntent = makeAudioGraphIntent(channelCount: 2)

        let configured = try await pipeline.configure(
            .stereoLowLatency,
            graphIntent: graphIntent,
            now: Date(timeIntervalSince1970: 2)
        )
        let running = try await pipeline.start(now: Date(timeIntervalSince1970: 3))
        let stopped = await pipeline.stop(reason: .userInitiated, drain: false, now: Date(timeIntervalSince1970: 4))

        XCTAssertEqual(configured.stage, .configured)
        XCTAssertEqual(configured.configuration, .stereoLowLatency)
        XCTAssertEqual(configured.route?.outputNames, ["USB DAC"])
        XCTAssertEqual(
            configured.spatialRuntime,
            makeNonspatialRuntime(
                configuration: .stereoLowLatency,
                graphIntent: graphIntent
            )
        )
        XCTAssertEqual(running.stage, .running)
        XCTAssertEqual(stopped.stage, .stopped)
        XCTAssertEqual(stopped.lastStopReason, .userInitiated)
        XCTAssertNil(stopped.spatialRuntime)

        let calls = client.snapshotCalls()
        XCTAssertEqual(calls, ["configure", "route", "start", "route", "stop:false", "route"])
    }

    func testAudioPipelineFailsWhenStartedWithoutConfiguration() async throws {
        let pipeline = AudioSessionPipeline(engineClient: StubAudioEngineClient(), now: Date(timeIntervalSince1970: 1))

        let snapshot = try await pipeline.start(now: Date(timeIntervalSince1970: 2))

        XCTAssertEqual(snapshot.stage, .failed)
        XCTAssertEqual(snapshot.lastStopReason, .failure)
        XCTAssertEqual(snapshot.lastErrorMessage, "missingConfiguration")
    }

    func testPipelineSchedulesBoundedPCMAndReleasesConsumedBuffers() async throws {
        let client = StubAudioEngineClient()
        let pipeline = AudioSessionPipeline(
            engineClient: client,
            maximumScheduledBuffers: 2,
            now: Date(timeIntervalSince1970: 1)
        )
        _ = try await pipeline.configure(
            .stereoLowLatency,
            graphIntent: makeAudioGraphIntent(channelCount: 2)
        )
        _ = try await pipeline.start()

        let first = try await pipeline.schedule(makePCM(sequence: 7, timestamp: 240))
        let second = try await pipeline.schedule(makePCM(sequence: 8, timestamp: 480))

        XCTAssertEqual(first, AudioScheduleReceipt(sequenceNumber: 7, rtpTimestamp: 240, frameCount: 2))
        XCTAssertEqual(second.sequenceNumber, 8)
        let queuedBeforeCompletion = await pipeline.scheduledBufferCount()
        let framesBeforeCompletion = await pipeline.scheduledFrameCount()
        XCTAssertEqual(queuedBeforeCompletion, 2)
        XCTAssertEqual(framesBeforeCompletion, 4)
        await AudioPipelineXCTAssertThrowsErrorAsync(
            try await pipeline.schedule(makePCM(sequence: 9, timestamp: 720))
        ) { error in
            XCTAssertEqual(error as? AudioPipelineError, .scheduleCapacityExceeded)
        }

        client.completeScheduledBuffer(at: 0)
        await waitForScheduledBufferCount(1, pipeline: pipeline)
        let queuedAfterCompletion = await pipeline.scheduledBufferCount()
        let framesAfterCompletion = await pipeline.scheduledFrameCount()
        XCTAssertEqual(queuedAfterCompletion, 1)
        XCTAssertEqual(framesAfterCompletion, 2)
    }

    func testStopClearsQueueAndIgnoresLateCompletion() async throws {
        let client = StubAudioEngineClient()
        let pipeline = AudioSessionPipeline(engineClient: client)
        _ = try await pipeline.configure(
            .stereoLowLatency,
            graphIntent: makeAudioGraphIntent(channelCount: 2)
        )
        _ = try await pipeline.start()
        _ = try await pipeline.schedule(makePCM(sequence: 1, timestamp: 0))

        _ = await pipeline.stop(reason: .sessionEnded, drain: false)
        client.completeScheduledBuffer(at: 0)
        await Task.yield()

        let scheduledCount = await pipeline.scheduledBufferCount()
        XCTAssertEqual(scheduledCount, 0)
        await AudioPipelineXCTAssertThrowsErrorAsync(
            try await pipeline.schedule(makePCM(sequence: 2, timestamp: 240))
        ) { error in
            XCTAssertEqual(error as? AudioPipelineError, .notRunning)
        }
    }

    func testFailedReconfigureClearsOldGraphAndCannotRestart() async throws {
        let client = StubAudioEngineClient()
        let pipeline = AudioSessionPipeline(engineClient: client)
        let graphIntent = makeAudioGraphIntent(channelCount: 2)
        _ = try await pipeline.configure(
            .stereoLowLatency,
            graphIntent: graphIntent
        )
        _ = try await pipeline.start()
        _ = try await pipeline.schedule(makePCM(sequence: 1, timestamp: 0))
        client.failNextConfigure()

        let failed = try await pipeline.configure(
            .stereoLowLatency,
            graphIntent: graphIntent
        )
        let restarted = try await pipeline.start()

        XCTAssertEqual(failed.stage, .failed)
        XCTAssertNil(failed.configuration)
        XCTAssertNil(failed.route)
        XCTAssertNil(failed.spatialRuntime)
        XCTAssertEqual(restarted.stage, .failed)
        XCTAssertEqual(restarted.lastErrorMessage, "missingConfiguration")
        let scheduledCount = await pipeline.scheduledBufferCount()
        XCTAssertEqual(scheduledCount, 0)
    }

    func testScheduleBackendFailureDoesNotConsumeCapacity() async throws {
        let client = StubAudioEngineClient()
        let pipeline = AudioSessionPipeline(
            engineClient: client,
            maximumScheduledBuffers: 1
        )
        _ = try await pipeline.configure(
            .stereoLowLatency,
            graphIntent: makeAudioGraphIntent(channelCount: 2)
        )
        _ = try await pipeline.start()
        client.failNextSchedule()

        await AudioPipelineXCTAssertThrowsErrorAsync(
            try await pipeline.schedule(makePCM(sequence: 1, timestamp: 0))
        ) { error in
            XCTAssertEqual(error as? AudioPipelineError, .invalidPCMBuffer)
        }

        let scheduledCount = await pipeline.scheduledBufferCount()
        XCTAssertEqual(scheduledCount, 0)
        _ = try await pipeline.schedule(makePCM(sequence: 2, timestamp: 240))
    }

    func testPCMBufferFactoryPreservesInterleavedInt16Samples() throws {
        let decoded = makePCM(sequence: 3, timestamp: 960)

        let buffer = try AVAudioPCMBufferFactory.makeBuffer(from: decoded)

        XCTAssertEqual(buffer.frameLength, 2)
        XCTAssertEqual(buffer.format.sampleRate, 48_000)
        XCTAssertEqual(buffer.format.channelCount, 2)
        XCTAssertTrue(buffer.format.isInterleaved)
        let audioBuffers = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        let pointer = try XCTUnwrap(audioBuffers[0].mData?.assumingMemoryBound(to: Int16.self))
        XCTAssertEqual(Array(UnsafeBufferPointer(start: pointer, count: 4)), decoded.interleavedSamples)
    }

    func testAVAudioFormatFactoryPreservesExplicitMoonlightLayouts() throws {
        let layouts: [StreamAudioChannelLayout] = [
            .mono,
            .stereo,
            .wave5Point1,
            .wave7Point1
        ]

        for layout in layouts {
            let format = try AVAudioStreamFormatFactory.makeInterleavedInt16(
                sampleRate: 48_000,
                channelLayout: layout
            )
            let description = format.streamDescription.pointee
            let expectedBytesPerFrame = UInt32(
                layout.channelCount * MemoryLayout<Int16>.size
            )

            XCTAssertEqual(format.commonFormat, .pcmFormatInt16)
            XCTAssertEqual(format.sampleRate, 48_000)
            XCTAssertTrue(format.isInterleaved)
            XCTAssertEqual(Int(format.channelCount), layout.channelCount)
            XCTAssertEqual(
                format.channelLayout?.layoutTag,
                layout.coreAudioLayoutTag
            )
            XCTAssertEqual(
                Int(format.channelLayout?.channelCount ?? 0),
                layout.channelCount
            )
            XCTAssertEqual(description.mFormatID, kAudioFormatLinearPCM)
            XCTAssertNotEqual(
                description.mFormatFlags & kAudioFormatFlagIsSignedInteger,
                0
            )
            XCTAssertNotEqual(
                description.mFormatFlags & kAudioFormatFlagIsPacked,
                0
            )
            XCTAssertEqual(description.mBitsPerChannel, 16)
            XCTAssertEqual(
                Int(description.mChannelsPerFrame),
                layout.channelCount
            )
            XCTAssertEqual(description.mFramesPerPacket, 1)
            XCTAssertEqual(description.mBytesPerFrame, expectedBytesPerFrame)
            XCTAssertEqual(description.mBytesPerPacket, expectedBytesPerFrame)
        }
    }

    func testAVAudioFormatFactoryRejectsInvalidRateAndNoncanonicalOrder() {
        XCTAssertThrowsError(
            try AVAudioStreamFormatFactory.makeInterleavedInt16(
                sampleRate: 44_100,
                channelLayout: .stereo
            )
        ) { error in
            XCTAssertEqual(
                error as? AVAudioStreamFormatError,
                .invalidSampleRate
            )
        }
        let reordered = StreamAudioChannelLayout(
            kind: .wave5Point1,
            channels: [
                .frontRight,
                .frontLeft,
                .frontCenter,
                .lowFrequencyEffects,
                .backLeft,
                .backRight
            ],
            moonlightChannelMask: 0x003F,
            coreAudioLayoutTagRawValue: StreamAudioChannelLayout.wave5Point1
                .coreAudioLayoutTagRawValue,
            spatialEligibility: .ambienceBed
        )

        XCTAssertThrowsError(
            try AVAudioStreamFormatFactory.makeInterleavedInt16(
                sampleRate: 48_000,
                channelLayout: reordered
            )
        ) { error in
            XCTAssertEqual(
                error as? AVAudioStreamFormatError,
                .noncanonicalChannelLayout
            )
        }
    }

    func testPCMBufferFactoryOwnsOneExactInterleavedBufferForEveryLayout() throws {
        let layouts: [StreamAudioChannelLayout] = [
            .mono,
            .stereo,
            .wave5Point1,
            .wave7Point1
        ]

        for layout in layouts {
            let decoded = makePCM(
                channelLayout: layout,
                frameCount: 5
            )
            let buffer = try AVAudioPCMBufferFactory.makeBuffer(from: decoded)
            let audioBuffers = UnsafeMutableAudioBufferListPointer(
                buffer.mutableAudioBufferList
            )
            let byteCount = decoded.interleavedSamples.count
                * MemoryLayout<Int16>.size

            XCTAssertEqual(buffer.frameCapacity, 5)
            XCTAssertEqual(buffer.frameLength, 5)
            XCTAssertEqual(
                buffer.format.channelLayout?.layoutTag,
                layout.coreAudioLayoutTag
            )
            XCTAssertEqual(audioBuffers.count, 1)
            XCTAssertEqual(
                Int(audioBuffers[0].mNumberChannels),
                layout.channelCount
            )
            XCTAssertEqual(Int(audioBuffers[0].mDataByteSize), byteCount)
            XCTAssertEqual(
                Int(buffer.audioBufferList.pointee.mBuffers.mDataByteSize),
                byteCount
            )
            let pointer = try XCTUnwrap(
                audioBuffers[0].mData?.assumingMemoryBound(to: Int16.self)
            )
            XCTAssertEqual(
                Array(UnsafeBufferPointer(
                    start: pointer,
                    count: decoded.interleavedSamples.count
                )),
                decoded.interleavedSamples
            )
        }
    }

    func testProductionClientBuildsEnvironmentAmbienceBedGraphForEveryEligibleLayout() throws {
        let layouts: [StreamAudioChannelLayout] = [
            .stereo,
            .wave5Point1,
            .wave7Point1
        ]

        for layout in layouts {
            let client = AVAudioEngineClient()
            let configuration = StreamAudioConfiguration(
                sampleRate: 48_000,
                channelLayout: layout,
                latencyPolicy: .lowLatency
            )
            let graphIntent = makeAudioGraphIntent(
                channelCount: layout.channelCount,
                userEnablesSpatialAudio: true
            )

            let actual = try client.configure(
                configuration,
                graphIntent: graphIntent
            )

            XCTAssertEqual(actual.revision, graphIntent.revision)
            XCTAssertEqual(actual.layoutSignature, layout.signature)
            XCTAssertEqual(actual.graphMode, .environmentAmbienceBed)
            XCTAssertEqual(actual.platformStrategy, .environmentListener)
            XCTAssertEqual(actual.presentationMode, .fixedSpatial)
            XCTAssertNil(actual.fallbackReason)
            XCTAssertTrue(actual.spatialAudioActive)

            let graph = client.graphReadback()
            XCTAssertEqual(graph.mode, .environmentAmbienceBed)
            XCTAssertTrue(graph.playerAttached)
            XCTAssertTrue(graph.environmentAttached)
            XCTAssertTrue(graph.playerConnectedToEnvironment)
            XCTAssertFalse(graph.playerConnectedToMainMixer)
            XCTAssertTrue(graph.environmentConnectedToMainMixer)
            XCTAssertEqual(
                graph.sourceModeRawValue,
                AVAudio3DMixingSourceMode.ambienceBed.rawValue
            )
            XCTAssertEqual(
                graph.selectedRenderingAlgorithmRawValue,
                AVAudio3DMixingRenderingAlgorithm.auto.rawValue
            )
            XCTAssertTrue(
                graph.applicableRenderingAlgorithmRawValues.contains(
                    AVAudio3DMixingRenderingAlgorithm.auto.rawValue
                )
            )
            XCTAssertEqual(
                graph.inputLayoutTagRawValue,
                layout.coreAudioLayoutTagRawValue
            )

            client.stop(drain: false)
            let stoppedGraph = client.graphReadback()
            XCTAssertEqual(stoppedGraph.mode, .unconfigured)
            XCTAssertFalse(stoppedGraph.playerConnectedToEnvironment)
            XCTAssertFalse(stoppedGraph.environmentConnectedToMainMixer)
            XCTAssertThrowsError(
                try client.schedule(
                    makePCM(sequence: 1, timestamp: 0),
                    completion: {}
                )
            ) { error in
                XCTAssertEqual(
                    error as? AudioPipelineError,
                    .missingConfiguration
                )
            }
        }
    }

    func testProductionClientKeepsDisabledSpatialAudioOnDirectMixerPath() throws {
        let client = AVAudioEngineClient()
        let graphIntent = makeAudioGraphIntent(
            channelCount: 2,
            userEnablesSpatialAudio: false
        )

        let actual = try client.configure(
            .stereoLowLatency,
            graphIntent: graphIntent
        )
        let graph = client.graphReadback()

        XCTAssertEqual(actual.graphMode, .nonspatialMixer)
        XCTAssertEqual(actual.presentationMode, .nonspatial)
        XCTAssertEqual(actual.fallbackReason, .userDisabled)
        XCTAssertEqual(graph.mode, .nonspatialMixer)
        XCTAssertFalse(graph.playerConnectedToEnvironment)
        XCTAssertTrue(graph.playerConnectedToMainMixer)
        XCTAssertFalse(graph.environmentConnectedToMainMixer)
        XCTAssertNil(graph.sourceModeRawValue)
        XCTAssertNil(graph.selectedRenderingAlgorithmRawValue)
        XCTAssertTrue(graph.applicableRenderingAlgorithmRawValues.isEmpty)
        client.stop(drain: false)
    }

    func testInvalidStreamConfigurationFailsBeforeBackendConfiguration() async throws {
        let client = StubAudioEngineClient()
        let pipeline = AudioSessionPipeline(engineClient: client)
        var invalid = StreamAudioConfiguration.stereoLowLatency
        invalid.sampleRate = 44_100

        let failed = try await pipeline.configure(
            invalid,
            graphIntent: makeAudioGraphIntent(channelCount: 2)
        )

        XCTAssertEqual(failed.stage, .failed)
        XCTAssertNil(failed.configuration)
        XCTAssertFalse(client.snapshotCalls().contains("configure"))
    }

    func testEngineStartFailureStopsPartialGraphAndClearsConfiguration() async throws {
        let client = StubAudioEngineClient()
        let pipeline = AudioSessionPipeline(engineClient: client)
        _ = try await pipeline.configure(
            .stereoLowLatency,
            graphIntent: makeAudioGraphIntent(channelCount: 2)
        )
        client.failNextStart()

        let failed = try await pipeline.start()

        XCTAssertEqual(failed.stage, .failed)
        XCTAssertNil(failed.configuration)
        XCTAssertNil(failed.route)
        XCTAssertNil(failed.spatialRuntime)
        XCTAssertEqual(
            client.snapshotCalls(),
            ["configure", "route", "start", "stop:false"]
        )
    }

    @MainActor
    func testDiagnosticsStoreRecordsAudioSnapshot() {
        let diagnostics = DiagnosticsStore()
        diagnostics.record(audioSnapshot: AudioPipelineSnapshot(
            stage: .running,
            configuration: .stereoLowLatency,
            route: AudioRouteSnapshot(
                outputNames: ["Built-in Output"],
                sampleRate: 48_000,
                outputChannelCount: 2,
                preferredBufferDuration: 0.005
            ),
            spatialRuntime: makeNonspatialRuntime(
                configuration: .stereoLowLatency,
                graphIntent: makeAudioGraphIntent(channelCount: 2)
            ),
            lastStopReason: nil,
            lastErrorMessage: nil,
            updatedAt: Date(timeIntervalSince1970: 10)
        ))

        XCTAssertEqual(diagnostics.events.last?.subsystem, "audio")
        XCTAssertEqual(diagnostics.events.last?.message, "Audio running: 48000 Hz, 2 ch, output available")
        XCTAssertFalse(diagnostics.events.last?.message.contains("Built-in Output") == true)
    }

    func testPipelineForwardsExactGraphIntentAndStoresActualRuntime() async throws {
        let client = StubAudioEngineClient()
        let pipeline = AudioSessionPipeline(engineClient: client)
        let configuration = StreamAudioConfiguration(
            sampleRate: 48_000,
            channelLayout: .wave7Point1,
            latencyPolicy: .lowLatency
        )
        let graphIntent = makeAudioGraphIntent(
            channelCount: configuration.channelCount,
            revision: .init(rawValue: 41),
            platform: .iOS,
            routeSupport: .supported,
            entitlement: .granted,
            userEnablesSpatialAudio: true,
            userEnablesHeadTracking: true
        )
        let actual = SpatialAudioRuntimeSnapshot(
            revision: graphIntent.revision,
            layoutSignature: configuration.channelLayout.signature,
            graphMode: .environmentAmbienceBed,
            platformStrategy: .environmentListener,
            routeSupport: .supported,
            presentationMode: .headTracked,
            fallbackReason: nil
        )
        client.returnNextSpatialRuntime(actual)

        let configured = try await pipeline.configure(
            configuration,
            graphIntent: graphIntent
        )

        XCTAssertEqual(client.lastConfigureRequest()?.configuration, configuration)
        XCTAssertEqual(client.lastConfigureRequest()?.graphIntent, graphIntent)
        XCTAssertEqual(configured.spatialRuntime, actual)
    }

    func testPipelineRejectsInconsistentActualRuntimeSnapshots() async throws {
        let configuration = StreamAudioConfiguration.stereoLowLatency
        let graphIntent = makeAudioGraphIntent(
            channelCount: configuration.channelCount,
            revision: .init(rawValue: 42),
            routeSupport: .supported
        )
        let valid = makeNonspatialRuntime(
            configuration: configuration,
            graphIntent: graphIntent
        )
        let invalidSnapshots = [
            SpatialAudioRuntimeSnapshot(
                revision: .init(rawValue: 43),
                layoutSignature: valid.layoutSignature,
                graphMode: valid.graphMode,
                platformStrategy: valid.platformStrategy,
                routeSupport: valid.routeSupport,
                presentationMode: valid.presentationMode,
                fallbackReason: valid.fallbackReason
            ),
            SpatialAudioRuntimeSnapshot(
                revision: valid.revision,
                layoutSignature: StreamAudioChannelLayout.wave5Point1.signature,
                graphMode: valid.graphMode,
                platformStrategy: valid.platformStrategy,
                routeSupport: valid.routeSupport,
                presentationMode: valid.presentationMode,
                fallbackReason: valid.fallbackReason
            ),
            SpatialAudioRuntimeSnapshot(
                revision: valid.revision,
                layoutSignature: valid.layoutSignature,
                graphMode: valid.graphMode,
                platformStrategy: valid.platformStrategy,
                routeSupport: .unknown,
                presentationMode: valid.presentationMode,
                fallbackReason: valid.fallbackReason
            ),
            SpatialAudioRuntimeSnapshot(
                revision: valid.revision,
                layoutSignature: valid.layoutSignature,
                graphMode: .nonspatialMixer,
                platformStrategy: .none,
                routeSupport: valid.routeSupport,
                presentationMode: .fixedSpatial,
                fallbackReason: nil
            )
        ]

        for invalid in invalidSnapshots {
            let client = StubAudioEngineClient()
            client.returnNextSpatialRuntime(invalid)
            let pipeline = AudioSessionPipeline(engineClient: client)

            let failed = try await pipeline.configure(
                configuration,
                graphIntent: graphIntent
            )

            XCTAssertEqual(failed.stage, .failed)
            XCTAssertEqual(
                failed.lastErrorMessage,
                String(describing: AudioPipelineError.invalidSpatialRuntimeSnapshot)
            )
            XCTAssertNil(failed.configuration)
            XCTAssertNil(failed.route)
            XCTAssertNil(failed.spatialRuntime)
            XCTAssertEqual(client.snapshotCalls(), ["configure", "stop:false"])
        }
    }

    func testPipelineRejectsIntentWithMismatchedRouteRevisionBeforeBackend() async throws {
        let client = StubAudioEngineClient()
        let pipeline = AudioSessionPipeline(engineClient: client)
        let revision = SpatialAudioSemanticRevision(rawValue: 50)
        let invalidIntent = SpatialAudioGraphIntent(
            revision: revision,
            platform: .macOS,
            route: SpatialAudioRouteCapabilitySnapshot(
                revision: .init(rawValue: 49),
                outputAvailable: true,
                systemSpatialSupport: .unknown,
                currentOutputChannelCount: 2,
                maximumOutputChannelCount: 2
            ),
            entitlement: .notRequired,
            userEnablesSpatialAudio: false,
            userEnablesHeadTracking: false
        )

        let failed = try await pipeline.configure(
            .stereoLowLatency,
            graphIntent: invalidIntent
        )

        XCTAssertEqual(failed.stage, .failed)
        XCTAssertEqual(
            failed.lastErrorMessage,
            String(describing: AudioPipelineError.invalidGraphIntent)
        )
        XCTAssertNil(failed.spatialRuntime)
        XCTAssertEqual(client.snapshotCalls(), ["stop:false"])
    }

    private func makePCM(sequence: UInt16, timestamp: UInt32) -> DecodedPCMBuffer {
        DecodedPCMBuffer(
            sequenceNumber: sequence,
            rtpTimestamp: timestamp,
            format: .signedInt16(
                sampleRate: 48_000,
                channelLayout: .stereo
            ),
            frameCount: 2,
            interleavedSamples: [100, -100, 200, -200]
        )
    }

    private func makePCM(
        channelLayout: StreamAudioChannelLayout,
        frameCount: Int
    ) -> DecodedPCMBuffer {
        let sampleCount = frameCount * channelLayout.channelCount
        return DecodedPCMBuffer(
            sequenceNumber: 9,
            rtpTimestamp: 1_920,
            format: .signedInt16(
                sampleRate: 48_000,
                channelLayout: channelLayout
            ),
            frameCount: frameCount,
            interleavedSamples: (0..<sampleCount).map {
                Int16($0 - sampleCount / 2)
            }
        )
    }

    private func waitForScheduledBufferCount(
        _ expected: Int,
        pipeline: AudioSessionPipeline
    ) async {
        for _ in 0..<100 {
            if await pipeline.scheduledBufferCount() == expected {
                return
            }
            try? await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Timed out waiting for scheduled audio completion")
    }
}

private final class StubAudioEngineClient: AudioEngineClient, @unchecked Sendable {
    private let route: AudioRouteSnapshot
    private var calls: [String] = []
    private var completions: [@Sendable () -> Void] = []
    private var shouldFailNextConfigure = false
    private var shouldFailNextStart = false
    private var shouldFailNextSchedule = false
    private var nextSpatialRuntime: SpatialAudioRuntimeSnapshot?
    private var configureRequests: [(
        configuration: StreamAudioConfiguration,
        graphIntent: SpatialAudioGraphIntent
    )] = []

    init(route: AudioRouteSnapshot = AudioRouteSnapshot(
        outputNames: ["System Output"],
        sampleRate: 48_000,
        outputChannelCount: 2,
        preferredBufferDuration: 0.005
    )) {
        self.route = route
    }

    func configure(
        _ configuration: StreamAudioConfiguration,
        graphIntent: SpatialAudioGraphIntent
    ) throws -> SpatialAudioRuntimeSnapshot {
        calls.append("configure")
        configureRequests.append((configuration, graphIntent))
        if shouldFailNextConfigure {
            shouldFailNextConfigure = false
            throw AudioPipelineError.invalidConfiguration
        }
        if let nextSpatialRuntime {
            self.nextSpatialRuntime = nil
            return nextSpatialRuntime
        }
        return makeNonspatialRuntime(
            configuration: configuration,
            graphIntent: graphIntent
        )
    }

    func start() throws {
        calls.append("start")
        if shouldFailNextStart {
            shouldFailNextStart = false
            throw AudioPipelineError.invalidConfiguration
        }
    }

    func schedule(
        _ buffer: DecodedPCMBuffer,
        completion: @escaping @Sendable () -> Void
    ) throws {
        calls.append("schedule:\(buffer.sequenceNumber)")
        if shouldFailNextSchedule {
            shouldFailNextSchedule = false
            throw AudioPipelineError.invalidPCMBuffer
        }
        completions.append(completion)
    }

    func stop(drain: Bool) {
        calls.append("stop:\(drain)")
    }

    func routeSnapshot() -> AudioRouteSnapshot {
        calls.append("route")
        return route
    }

    func snapshotCalls() -> [String] {
        calls
    }

    func completeScheduledBuffer(at index: Int) {
        completions[index]()
    }

    func failNextConfigure() {
        shouldFailNextConfigure = true
    }

    func failNextSchedule() {
        shouldFailNextSchedule = true
    }

    func failNextStart() {
        shouldFailNextStart = true
    }

    func returnNextSpatialRuntime(_ spatialRuntime: SpatialAudioRuntimeSnapshot) {
        nextSpatialRuntime = spatialRuntime
    }

    func lastConfigureRequest() -> (
        configuration: StreamAudioConfiguration,
        graphIntent: SpatialAudioGraphIntent
    )? {
        configureRequests.last
    }
}

func makeAudioGraphIntent(
    channelCount: Int,
    revision: SpatialAudioSemanticRevision = .init(rawValue: 1),
    platform: SpatialAudioPlatform = .macOS,
    routeSupport: SpatialAudioRouteSupport = .unknown,
    entitlement: SpatialAudioEntitlementState = .notRequired,
    userEnablesSpatialAudio: Bool = false,
    userEnablesHeadTracking: Bool = false
) -> SpatialAudioGraphIntent {
    SpatialAudioGraphIntent(
        revision: revision,
        platform: platform,
        route: SpatialAudioRouteCapabilitySnapshot(
            revision: revision,
            outputAvailable: true,
            systemSpatialSupport: routeSupport,
            currentOutputChannelCount: channelCount,
            maximumOutputChannelCount: channelCount
        ),
        entitlement: entitlement,
        userEnablesSpatialAudio: userEnablesSpatialAudio,
        userEnablesHeadTracking: userEnablesHeadTracking
    )
}

func makeNonspatialRuntime(
    configuration: StreamAudioConfiguration,
    graphIntent: SpatialAudioGraphIntent
) -> SpatialAudioRuntimeSnapshot {
    SpatialAudioRuntimeResolver.resolve(
        intent: graphIntent,
        layout: configuration.channelLayout,
        graph: SpatialAudioGraphSnapshot(
            revision: graphIntent.revision,
            mode: .nonspatialMixer,
            layoutSignature: configuration.channelLayout.signature,
            hasApplicableRenderingAlgorithm: false,
            platformStrategy: .none,
            listenerHeadTrackingCapable: false,
            listenerHeadTrackingReadback: false,
            visionExperienceReadback: nil
        )
    )
}

private func AudioPipelineXCTAssertThrowsErrorAsync<T>(
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
