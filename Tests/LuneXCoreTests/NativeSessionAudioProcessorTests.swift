import Foundation
import XCTest

final class NativeSessionAudioProcessorTests: XCTestCase {
    func testFactoryBuildsInitialIntentFromSharedCapabilityEntitlementAndPreferences()
        async throws
    {
        let sessionID = UUID()
        let preferences = SessionSpatialAudioPreferences(
            spatialAudioEnabled: true,
            headTrackingEnabled: true
        )
        let harness = try await makeHarness(
            sessionID: sessionID,
            preferences: preferences,
            capability: routeCapability(support: .supported),
            entitlement: .granted
        )
        defer { harness.collection.cancel() }

        try await waitForEventCount(1, recorder: harness.events)
        let initialEvents = await harness.events.snapshot()
        let initial = try XCTUnwrap(initialEvents.first)
        let intents = harness.engine.graphIntents()

        XCTAssertEqual(intents.count, 1)
        XCTAssertEqual(intents[0].revision.rawValue, 0)
        XCTAssertEqual(intents[0].route.systemSpatialSupport, .supported)
        XCTAssertEqual(intents[0].entitlement, .granted)
        XCTAssertTrue(intents[0].userEnablesSpatialAudio)
        XCTAssertTrue(intents[0].userEnablesHeadTracking)
        XCTAssertEqual(harness.engine.capabilityReadCount(), 2)
        XCTAssertEqual(initial.sessionID, sessionID)
        XCTAssertEqual(initial.sequence, 0)
        XCTAssertEqual(initial.graphGeneration, 1)
        XCTAssertEqual(initial.cause, .initial)
        XCTAssertEqual(initial.stage, .running)
        XCTAssertEqual(initial.preferences, preferences)
        XCTAssertEqual(initial.spatialRuntime?.presentationMode, .headTracked)

        await harness.processor.stop()
        await harness.collection.value
    }

    func testRouteAndPreferenceChangesShareOneMonotonicPolicyRevisionDomain()
        async throws
    {
        let harness = try await makeHarness(
            capability: routeCapability(support: .supported),
            entitlement: .granted
        )
        defer { harness.collection.cancel() }
        try await waitForEventCount(1, recorder: harness.events)

        harness.engine.setCapability(routeCapability(support: .unsupported))
        harness.source.emit(.routeChanged)
        try await waitForGraphIntentCount(2, engine: harness.engine)

        try await harness.processor.updateSpatialAudioPreferences(
            SessionSpatialAudioPreferences(
                spatialAudioEnabled: false,
                headTrackingEnabled: false
            )
        )
        try await waitForGraphIntentCount(3, engine: harness.engine)

        harness.engine.setCapability(routeCapability(support: .supported))
        harness.source.emit(.spatialPlaybackCapabilityChanged)
        try await waitForGraphIntentCount(4, engine: harness.engine)
        try await waitForEventCount(4, recorder: harness.events)

        let intents = harness.engine.graphIntents()
        XCTAssertEqual(intents.map(\.revision.rawValue), [0, 1, 2, 3])
        XCTAssertEqual(
            intents.map(\.route.systemSpatialSupport),
            [.supported, .unsupported, .unsupported, .supported]
        )
        XCTAssertEqual(
            intents.map(\.userEnablesSpatialAudio),
            [true, true, false, false]
        )

        let events = await harness.events.snapshot()
        XCTAssertEqual(events.map(\.sequence), [0, 1, 2, 3])
        XCTAssertEqual(events.map(\.graphGeneration), [1, 2, 3, 4])
        XCTAssertEqual(
            events.map(\.cause),
            [
                .initial,
                .routeChanged,
                .preferencesChanged,
                .spatialCapabilityChanged
            ]
        )

        await harness.processor.stop()
        await harness.collection.value
    }

    func testCapabilityDowngradeAndRecoveryPublishTypedMonotonicRuntime()
        async throws
    {
        let harness = try await makeHarness(
            capability: routeCapability(support: .supported),
            entitlement: .granted
        )
        defer { harness.collection.cancel() }
        try await waitForEventCount(1, recorder: harness.events)

        harness.engine.setCapability(routeCapability(support: .unsupported))
        harness.source.emit(.spatialPlaybackCapabilityChanged)
        try await waitForEventCount(2, recorder: harness.events)

        harness.engine.setCapability(routeCapability(support: .supported))
        harness.source.emit(.spatialPlaybackCapabilityChanged)
        try await waitForEventCount(3, recorder: harness.events)

        let events = await harness.events.snapshot()
        XCTAssertEqual(events.map(\.sequence), [0, 1, 2])
        XCTAssertEqual(events.map(\.graphGeneration), [1, 2, 3])
        XCTAssertEqual(
            events.map(\.cause),
            [.initial, .spatialCapabilityChanged, .spatialCapabilityChanged]
        )
        XCTAssertEqual(
            events.map(\.spatialRuntime?.presentationMode),
            [.headTracked, .nonspatial, .headTracked]
        )
        XCTAssertEqual(
            events.map(\.spatialRuntime?.fallbackReason),
            [nil, .routeUnsupported, nil]
        )
        XCTAssertEqual(
            harness.engine.graphIntents().map(\.route.systemSpatialSupport),
            [.supported, .unsupported, .supported]
        )

        await harness.processor.stop()
        await harness.collection.value
    }

    func testInterruptedChangesAreDeferredAndResumeOnlyTheLatestIntent()
        async throws
    {
        let harness = try await makeHarness(
            capability: routeCapability(support: .supported),
            entitlement: .granted
        )
        defer { harness.collection.cancel() }
        try await waitForEventCount(1, recorder: harness.events)

        harness.source.emit(.interruptionBegan)
        try await waitForEventCount(2, recorder: harness.events)

        try await harness.processor.updateSpatialAudioPreferences(
            SessionSpatialAudioPreferences(
                spatialAudioEnabled: false,
                headTrackingEnabled: false
            )
        )
        harness.engine.setCapability(routeCapability(support: .unsupported))
        harness.source.emit(.routeChanged)
        try await waitForEventCount(4, recorder: harness.events)
        try await harness.processor.updateSpatialAudioPreferences(
            SessionSpatialAudioPreferences(
                spatialAudioEnabled: true,
                headTrackingEnabled: false
            )
        )
        try await waitForEventCount(5, recorder: harness.events)

        XCTAssertEqual(harness.engine.graphIntents().count, 1)

        harness.source.emit(.interruptionEnded(shouldResume: true))
        try await waitForGraphIntentCount(2, engine: harness.engine)
        try await waitForEventCount(6, recorder: harness.events)

        let configured = harness.engine.graphIntents()
        XCTAssertEqual(configured.map(\.revision.rawValue), [0, 5])
        XCTAssertEqual(configured.last?.route.systemSpatialSupport, .unsupported)
        XCTAssertEqual(configured.last?.userEnablesSpatialAudio, true)
        XCTAssertEqual(configured.last?.userEnablesHeadTracking, false)

        let events = await harness.events.snapshot()
        XCTAssertEqual(
            Array(events.dropFirst().dropLast().map(\.graphGeneration)),
            [1, 1, 1, 1]
        )
        XCTAssertEqual(events.last?.graphGeneration, 2)
        XCTAssertEqual(events.last?.cause, .interruptionEnded)
        XCTAssertEqual(events.last?.lastAction, .interruptionResumed)

        await harness.processor.stop()
        await harness.collection.value
    }

    func testEquivalentRouteAndPreferenceStateDoesNotRebuildOrPublish()
        async throws
    {
        let harness = try await makeHarness(
            capability: routeCapability(support: .supported)
        )
        defer { harness.collection.cancel() }
        try await waitForEventCount(1, recorder: harness.events)

        harness.source.emit(.routeChanged)
        harness.source.emit(.spatialPlaybackCapabilityChanged)
        try await harness.processor.updateSpatialAudioPreferences(.nativeDefault)
        try await Task.sleep(for: .milliseconds(50))

        XCTAssertEqual(harness.engine.graphIntents().count, 1)
        let eventCount = await harness.events.snapshot().count
        XCTAssertEqual(eventCount, 1)

        await harness.processor.stop()
        await harness.collection.value
    }

    func testBoundedEventStreamKeepsNewestAndConsumerCancellationDoesNotStopProcessor()
        async throws
    {
        let engine = ProcessorRecordingAudioEngineClient(
            capability: routeCapability(support: .supported)
        )
        let source = ProcessorManualRouteEventSource()
        let decoder = ProcessorRecordingDecoder()
        let clock = ProcessorIncrementingClock()
        let factory = NativeSessionAudioProcessorFactory(
            eventCapacity: 2,
            entitlementReader: ProcessorEntitlementReader(state: .granted),
            decoderFactory: { _ in decoder },
            engineClientFactory: { engine },
            routeEventSourceFactory: { source },
            eventTimeProvider: { clock.next() }
        )
        let processor = try await factory.makeAudioProcessor(
            sessionID: UUID(),
            configuration: Self.audioConfiguration()
        )

        for index in 0..<4 {
            try await processor.updateSpatialAudioPreferences(
                SessionSpatialAudioPreferences(
                    spatialAudioEnabled: index.isMultiple(of: 2),
                    headTrackingEnabled: false
                )
            )
        }
        let stream = await processor.audioRuntimeEvents()
        var iterator = stream.makeAsyncIterator()
        let optionalFirst = await iterator.next()
        let optionalSecond = await iterator.next()
        let first = try XCTUnwrap(optionalFirst)
        let second = try XCTUnwrap(optionalSecond)
        XCTAssertEqual([first.sequence, second.sequence], [3, 4])

        let cancelledConsumer = Task {
            var consumer = stream.makeAsyncIterator()
            _ = await consumer.next()
        }
        cancelledConsumer.cancel()
        await Task.yield()

        let priorConfigureCount = engine.graphIntents().count
        try await processor.updateSpatialAudioPreferences(
            SessionSpatialAudioPreferences(
                spatialAudioEnabled: false,
                headTrackingEnabled: true
            )
        )
        XCTAssertEqual(engine.graphIntents().count, priorConfigureCount + 1)
        XCTAssertFalse(source.stopped())

        await processor.stop()
        XCTAssertTrue(source.stopped())
    }

    func testGraphFailurePublishesFailedStateStopsObservationAndRejectsLateCallbacks()
        async throws
    {
        let harness = try await makeHarness(
            capability: routeCapability(support: .supported)
        )
        defer { harness.collection.cancel() }
        try await waitForEventCount(1, recorder: harness.events)

        harness.engine.failNextConfigure()
        harness.engine.setCapability(routeCapability(support: .unsupported))
        harness.source.emit(.routeChanged)
        try await waitForEventCount(2, recorder: harness.events)
        try await waitUntil { harness.source.stopped() }

        let failedEvents = await harness.events.snapshot()
        let failed = try XCTUnwrap(failedEvents.last)
        XCTAssertEqual(failed.cause, .failed)
        XCTAssertEqual(failed.stage, .failed)
        XCTAssertNil(failed.spatialRuntime)

        let configureCount = harness.engine.graphIntents().count
        harness.source.emitLate(.routeChanged)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(harness.engine.graphIntents().count, configureCount)

        await XCTAssertThrowsErrorAsync(
            try await harness.processor.updateSpatialAudioPreferences(
                SessionSpatialAudioPreferences(
                    spatialAudioEnabled: false,
                    headTrackingEnabled: false
                )
            )
        ) { error in
            XCTAssertEqual(
                error as? AudioRuntimeRecoveryError,
                .invalidState
            )
        }

        await harness.processor.stop()
        await harness.collection.value
        let decoderClosed = await harness.decoder.isClosed()
        XCTAssertTrue(decoderClosed)
    }

    func testStopEndsObservationBeforeGraphAndDecoderAndSuppressesLateCallback()
        async throws
    {
        let order = ProcessorCallOrderRecorder()
        let harness = try await makeHarness(
            capability: routeCapability(support: .supported),
            order: order
        )
        defer { harness.collection.cancel() }
        try await waitForEventCount(1, recorder: harness.events)
        order.clear()

        await harness.processor.stop()
        await harness.collection.value

        let calls = order.snapshot()
        let sourceStop = try XCTUnwrap(calls.firstIndex(of: "source.stop"))
        let engineStop = try XCTUnwrap(calls.firstIndex(of: "engine.stop"))
        let decoderClose = try XCTUnwrap(calls.firstIndex(of: "decoder.close"))
        XCTAssertLessThan(sourceStop, engineStop)
        XCTAssertLessThan(engineStop, decoderClose)
        let finalCause = await harness.events.snapshot().last?.cause
        XCTAssertEqual(finalCause, .stopped)

        let configureCount = harness.engine.graphIntents().count
        harness.source.emitLate(.routeChanged)
        try await Task.sleep(for: .milliseconds(50))
        XCTAssertEqual(harness.engine.graphIntents().count, configureCount)
    }

    func testInvalidEventCapacityCleansStartedMonitorGraphAndDecoder() async throws {
        let order = ProcessorCallOrderRecorder()
        let engine = ProcessorRecordingAudioEngineClient(
            capability: routeCapability(support: .supported),
            order: order
        )
        let source = ProcessorManualRouteEventSource(order: order)
        let decoder = ProcessorRecordingDecoder(order: order)
        let factory = NativeSessionAudioProcessorFactory(
            eventCapacity: 0,
            entitlementReader: ProcessorEntitlementReader(state: .missing),
            decoderFactory: { _ in decoder },
            engineClientFactory: { engine },
            routeEventSourceFactory: { source },
            eventTimeProvider: { 0 }
        )

        await XCTAssertThrowsErrorAsync(
            try await factory.makeAudioProcessor(
                sessionID: UUID(),
                configuration: Self.audioConfiguration()
            )
        ) { error in
            XCTAssertEqual(
                error as? NativeSessionAudioProcessorError,
                .invalidEventCapacity(0)
            )
        }

        XCTAssertTrue(source.stopped())
        let decoderClosed = await decoder.isClosed()
        XCTAssertTrue(decoderClosed)
        XCTAssertTrue(engine.wasStopped())
    }

    private func makeHarness(
        sessionID: UUID = UUID(),
        preferences: SessionSpatialAudioPreferences = .nativeDefault,
        capability: SpatialAudioRouteCapabilityState,
        entitlement: SpatialAudioEntitlementState = .missing,
        order: ProcessorCallOrderRecorder? = nil
    ) async throws -> ProcessorHarness {
        let engine = ProcessorRecordingAudioEngineClient(
            capability: capability,
            order: order
        )
        let source = ProcessorManualRouteEventSource(order: order)
        let decoder = ProcessorRecordingDecoder(order: order)
        let clock = ProcessorIncrementingClock()
        let factory = NativeSessionAudioProcessorFactory(
            initialPreferences: preferences,
            entitlementReader: ProcessorEntitlementReader(state: entitlement),
            decoderFactory: { _ in decoder },
            engineClientFactory: { engine },
            routeEventSourceFactory: { source },
            eventTimeProvider: { clock.next() }
        )
        let processor = try await factory.makeAudioProcessor(
            sessionID: sessionID,
            configuration: Self.audioConfiguration()
        )
        let eventStream = await processor.audioRuntimeEvents()
        let events = ProcessorAudioEventRecorder()
        let collection = Task {
            for await event in eventStream {
                await events.append(event)
            }
        }
        return ProcessorHarness(
            processor: processor,
            engine: engine,
            source: source,
            decoder: decoder,
            events: events,
            collection: collection
        )
    }

    private func waitForEventCount(
        _ count: Int,
        recorder: ProcessorAudioEventRecorder
    ) async throws {
        try await waitUntil {
            await recorder.snapshot().count >= count
        }
    }

    private func waitForGraphIntentCount(
        _ count: Int,
        engine: ProcessorRecordingAudioEngineClient
    ) async throws {
        try await waitUntil {
            engine.graphIntents().count >= count
        }
    }

    private func waitUntil(
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<200 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for processor state")
        throw ProcessorTestError.timedOut
    }

    private static func audioConfiguration()
        -> NegotiatedAudioStreamConfiguration
    {
        NegotiatedAudioStreamConfiguration(
            sampleRate: 48_000,
            channelLayout: .stereo,
            streamCount: 1,
            coupledStreamCount: 1,
            samplesPerFrame: 240,
            channelMapping: [0, 1],
            maximumPacketSize: 1_400
        )
    }
}

private struct ProcessorHarness {
    let processor: any SessionAudioProcessing
    let engine: ProcessorRecordingAudioEngineClient
    let source: ProcessorManualRouteEventSource
    let decoder: ProcessorRecordingDecoder
    let events: ProcessorAudioEventRecorder
    let collection: Task<Void, Never>
}

private enum ProcessorTestError: Error {
    case timedOut
}

private actor ProcessorAudioEventRecorder {
    private var events: [SessionAudioRuntimeEvent] = []

    func append(_ event: SessionAudioRuntimeEvent) {
        events.append(event)
    }

    func snapshot() -> [SessionAudioRuntimeEvent] {
        events
    }
}

private final class ProcessorCallOrderRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [String] = []

    func append(_ call: String) {
        lock.withLock {
            calls.append(call)
        }
    }

    func clear() {
        lock.withLock {
            calls.removeAll()
        }
    }

    func snapshot() -> [String] {
        lock.withLock { calls }
    }
}

private final class ProcessorIncrementingClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: UInt64 = 0

    func next() -> UInt64 {
        lock.withLock {
            value += 1
            return value
        }
    }
}

private struct ProcessorEntitlementReader: HeadPoseEntitlementReading {
    let state: SpatialAudioEntitlementState

    func readHeadPoseEntitlement() -> SpatialAudioEntitlementState {
        state
    }
}

private actor ProcessorRecordingDecoder: SessionAudioDecoding {
    private let order: ProcessorCallOrderRecorder?
    private var closed = false

    init(order: ProcessorCallOrderRecorder? = nil) {
        self.order = order
    }

    func decode(_ packet: ReceivedAudioPacket) throws -> DecodedPCMBuffer {
        DecodedPCMBuffer(
            sequenceNumber: packet.sequenceNumber,
            rtpTimestamp: packet.timestamp,
            format: .signedInt16(
                sampleRate: 48_000,
                channelLayout: .stereo
            ),
            frameCount: 240,
            interleavedSamples: [Int16](repeating: 0, count: 480)
        )
    }

    func close() {
        order?.append("decoder.close")
        closed = true
    }

    func isClosed() -> Bool {
        closed
    }
}

private final class ProcessorManualRouteEventSource:
    SpatialAudioRouteMonitorEventSourcing,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let order: ProcessorCallOrderRecorder?
    private var handler:
        (@Sendable (SpatialAudioRouteMonitorEvent) -> Void)?
    private var lateHandler:
        (@Sendable (SpatialAudioRouteMonitorEvent) -> Void)?
    private var isStopped = true

    init(order: ProcessorCallOrderRecorder? = nil) {
        self.order = order
    }

    func start(
        handler: @escaping @Sendable (SpatialAudioRouteMonitorEvent) -> Void
    ) {
        lock.withLock {
            self.handler = handler
            lateHandler = handler
            isStopped = false
        }
        order?.append("source.start")
    }

    func stop() {
        lock.withLock {
            handler = nil
            isStopped = true
        }
        order?.append("source.stop")
    }

    func emit(_ event: SpatialAudioRouteMonitorEvent) {
        lock.withLock { handler }?(event)
    }

    func emitLate(_ event: SpatialAudioRouteMonitorEvent) {
        lock.withLock { lateHandler }?(event)
    }

    func stopped() -> Bool {
        lock.withLock { isStopped }
    }
}

private final class ProcessorRecordingAudioEngineClient:
    AudioEngineClient,
    @unchecked Sendable
{
    private let lock = NSLock()
    private let order: ProcessorCallOrderRecorder?
    private var capability: SpatialAudioRouteCapabilityState
    private var intents: [SpatialAudioGraphIntent] = []
    private var reads = 0
    private var failConfigure = false
    private var stopped = false

    init(
        capability: SpatialAudioRouteCapabilityState,
        order: ProcessorCallOrderRecorder? = nil
    ) {
        self.capability = capability
        self.order = order
    }

    func configure(
        _ configuration: StreamAudioConfiguration,
        graphIntent: SpatialAudioGraphIntent
    ) throws -> SpatialAudioRuntimeSnapshot {
        let shouldFail = lock.withLock { () -> Bool in
            intents.append(graphIntent)
            defer { failConfigure = false }
            return failConfigure
        }
        order?.append("engine.configure")
        if shouldFail {
            throw AudioPipelineError.invalidConfiguration
        }

        let usesEnvironment = graphIntent.userEnablesSpatialAudio
            && configuration.channelLayout.spatialEligibility == .ambienceBed
            && graphIntent.route.outputAvailable
            && graphIntent.route.systemSpatialSupport != .unsupported
        let strategy: SpatialAudioPlatformStrategy = usesEnvironment
            ? .environmentListener
            : .none
        let graph = SpatialAudioGraphSnapshot(
            revision: graphIntent.revision,
            mode: usesEnvironment
                ? .environmentAmbienceBed
                : .nonspatialMixer,
            layoutSignature: configuration.channelLayout.signature,
            hasApplicableRenderingAlgorithm: usesEnvironment,
            platformStrategy: strategy,
            listenerHeadTrackingCapable: usesEnvironment,
            listenerHeadTrackingReadback: usesEnvironment
                && graphIntent.userEnablesHeadTracking
                && graphIntent.entitlement == .granted,
            visionExperienceReadback: nil
        )
        return SpatialAudioRuntimeResolver.resolve(
            intent: graphIntent,
            layout: configuration.channelLayout,
            graph: graph
        )
    }

    func start() throws {
        order?.append("engine.start")
    }

    func schedule(
        _ buffer: DecodedPCMBuffer,
        completion: @escaping @Sendable () -> Void
    ) throws {
        _ = buffer
        completion()
    }

    func stop(drain: Bool) {
        _ = drain
        lock.withLock {
            stopped = true
        }
        order?.append("engine.stop")
    }

    func routeSnapshot() -> AudioRouteSnapshot {
        AudioRouteSnapshot(
            outputNames: ["Bounded Test Output"],
            sampleRate: 48_000,
            outputChannelCount: 2,
            preferredBufferDuration: 0.005
        )
    }

    func currentSpatialRouteCapability() -> SpatialAudioRouteCapabilityState {
        lock.withLock {
            reads += 1
            return capability
        }
    }

    func setCapability(_ capability: SpatialAudioRouteCapabilityState) {
        lock.withLock {
            self.capability = capability
        }
    }

    func failNextConfigure() {
        lock.withLock {
            failConfigure = true
        }
    }

    func graphIntents() -> [SpatialAudioGraphIntent] {
        lock.withLock { intents }
    }

    func capabilityReadCount() -> Int {
        lock.withLock { reads }
    }

    func wasStopped() -> Bool {
        lock.withLock { stopped }
    }
}

private func routeCapability(
    support: SpatialAudioRouteSupport
) -> SpatialAudioRouteCapabilityState {
    SpatialAudioRouteCapabilityState(
        outputAvailable: true,
        systemSpatialSupport: support,
        currentOutputChannelCount: 2,
        maximumOutputChannelCount: 8
    )
}

private func XCTAssertThrowsErrorAsync<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void
) async {
    do {
        _ = try await expression()
        XCTFail("Expected async expression to throw")
    } catch {
        errorHandler(error)
    }
}
