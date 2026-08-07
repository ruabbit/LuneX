import Dispatch
import Foundation

struct SessionSpatialAudioPreferences: Equatable, Hashable, Sendable {
    let spatialAudioEnabled: Bool
    let headTrackingEnabled: Bool

    static let nativeDefault = SessionSpatialAudioPreferences(
        spatialAudioEnabled: true,
        headTrackingEnabled: true
    )
}

enum SessionAudioRuntimeEventCause: String, Equatable, Hashable, Sendable {
    case initial
    case routeChanged = "route-changed"
    case routeRefreshed = "route-refreshed"
    case interruptionBegan = "interruption-began"
    case interruptionEnded = "interruption-ended"
    case mediaServicesLost = "media-services-lost"
    case mediaServicesReset = "media-services-reset"
    case spatialCapabilityChanged = "spatial-capability-changed"
    case preferencesChanged = "preferences-changed"
    case mobilePolicyPaused = "mobile-policy-paused"
    case mobilePolicyResumed = "mobile-policy-resumed"
    case recovery
    case failed
    case stopped
}

struct SessionAudioRuntimeEvent: Equatable, Sendable {
    let sessionID: UUID
    let sequence: UInt64
    let graphGeneration: UInt64
    let cause: SessionAudioRuntimeEventCause
    let stage: SessionAudioRuntimeStage
    let spatialRuntime: SpatialAudioRuntimeSnapshot?
    let routeCapability: SpatialAudioRouteCapabilitySnapshot
    let entitlement: SpatialAudioEntitlementState
    let preferences: SessionSpatialAudioPreferences
    let concealedFrameCount: UInt64
    let lastAction: AudioRuntimeRecoveryAction
    let mobileAudioSessionActive: Bool?

    init(
        sessionID: UUID,
        sequence: UInt64,
        graphGeneration: UInt64,
        cause: SessionAudioRuntimeEventCause,
        stage: SessionAudioRuntimeStage,
        spatialRuntime: SpatialAudioRuntimeSnapshot?,
        routeCapability: SpatialAudioRouteCapabilitySnapshot,
        entitlement: SpatialAudioEntitlementState,
        preferences: SessionSpatialAudioPreferences,
        concealedFrameCount: UInt64,
        lastAction: AudioRuntimeRecoveryAction,
        mobileAudioSessionActive: Bool? = nil
    ) {
        self.sessionID = sessionID
        self.sequence = sequence
        self.graphGeneration = graphGeneration
        self.cause = cause
        self.stage = stage
        self.spatialRuntime = spatialRuntime
        self.routeCapability = routeCapability
        self.entitlement = entitlement
        self.preferences = preferences
        self.concealedFrameCount = concealedFrameCount
        self.lastAction = lastAction
        self.mobileAudioSessionActive = mobileAudioSessionActive
    }
}

enum NativeSessionAudioProcessorError: Error, Equatable, Sendable {
    case invalidEventCapacity(Int)
    case missingInitialRoute
    case policyRevisionExhausted
    case graphGenerationExhausted
    case eventSequenceExhausted
}

private actor NativeSessionAudioProcessorOperationGate {
    private var isHeld = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func acquire() async {
        if !isHeld {
            isHeld = true
            return
        }
        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        guard !waiters.isEmpty else {
            isHeld = false
            return
        }
        waiters.removeFirst().resume()
    }
}

struct NativeSessionAudioProcessorFactory: SessionAudioProcessorCreating {
    typealias EngineClientFactory =
        @Sendable () -> any AudioEngineClient
    typealias DecoderFactory =
        @Sendable (
            NegotiatedAudioStreamConfiguration
        ) throws -> any SessionAudioDecoding
    typealias RouteEventSourceFactory =
        @Sendable () -> any SpatialAudioRouteMonitorEventSourcing
    typealias EventTimeProvider = @Sendable () -> UInt64

    private let initialPreferences: SessionSpatialAudioPreferences
    private let eventCapacity: Int
    private let routeMonitorCapacity: Int
    private let entitlementReader: any HeadPoseEntitlementReading
    private let decoderFactory: DecoderFactory
    private let engineClientFactory: EngineClientFactory
    private let routeEventSourceFactory: RouteEventSourceFactory
    private let eventTimeProvider: EventTimeProvider

    init(
        initialPreferences: SessionSpatialAudioPreferences = .nativeDefault,
        eventCapacity: Int = NativeSessionAudioProcessor.defaultEventCapacity,
        routeMonitorCapacity: Int = SpatialAudioRouteMonitor.defaultCapacity,
        entitlementReader: any HeadPoseEntitlementReading =
            SecurityEmbeddedHeadPoseEntitlementReader(),
        decoderFactory: @escaping DecoderFactory = {
            try AudioToolboxOpusDecoder(configuration: $0)
        },
        engineClientFactory: @escaping EngineClientFactory = {
            AVAudioEngineClient()
        },
        routeEventSourceFactory: @escaping RouteEventSourceFactory = {
            SpatialAudioPlatformNotificationSource()
        },
        eventTimeProvider: @escaping EventTimeProvider = {
            DispatchTime.now().uptimeNanoseconds
        }
    ) {
        self.initialPreferences = initialPreferences
        self.eventCapacity = eventCapacity
        self.routeMonitorCapacity = routeMonitorCapacity
        self.entitlementReader = entitlementReader
        self.decoderFactory = decoderFactory
        self.engineClientFactory = engineClientFactory
        self.routeEventSourceFactory = routeEventSourceFactory
        self.eventTimeProvider = eventTimeProvider
    }

    func makeAudioProcessor(
        sessionID: UUID,
        configuration: NegotiatedAudioStreamConfiguration
    ) async throws -> any SessionAudioProcessing {
        let decoder = try decoderFactory(configuration)
        let engineClient = engineClientFactory()
        let routeMonitor: SpatialAudioRouteMonitor
        do {
            routeMonitor = try SpatialAudioRouteMonitor(
                capacity: routeMonitorCapacity,
                capabilityReader: AudioEngineRouteCapabilityReader(
                    engineClient: engineClient
                ),
                eventSource: routeEventSourceFactory()
            )
        } catch {
            await decoder.close()
            throw error
        }

        let routeStream = routeMonitor.start()
        guard let initialRoute = routeMonitor.latestSnapshot else {
            routeMonitor.stop()
            await decoder.close()
            throw NativeSessionAudioProcessorError.missingInitialRoute
        }

        let streamConfiguration = StreamAudioConfiguration(
            sampleRate: Double(configuration.sampleRate),
            channelLayout: configuration.channelLayout,
            latencyPolicy: .lowLatency
        )
        let entitlement = Self.readEntitlement(
            platform: .current,
            reader: entitlementReader
        )
        let initialIntent = Self.makeIntent(
            revision: .init(rawValue: 0),
            route: initialRoute.state.route,
            entitlement: entitlement,
            preferences: initialPreferences
        )
        let runtime: SessionAudioRuntime
        do {
            runtime = try SessionAudioRuntime(
                pipeline: AudioSessionPipeline(engineClient: engineClient),
                clock: MediaClockSynchronizer(),
                configuration: streamConfiguration,
                graphIntent: initialIntent
            )
        } catch {
            routeMonitor.stop()
            await decoder.close()
            throw error
        }

        do {
            let initialRuntime = try await runtime.start(at: 0)
            let processor = try NativeSessionAudioProcessor(
                sessionID: sessionID,
                configuration: configuration,
                decoder: decoder,
                runtime: runtime,
                routeMonitor: routeMonitor,
                routeStream: routeStream,
                initialRoute: initialRoute,
                initialIntent: initialIntent,
                initialPreferences: initialPreferences,
                initialEntitlement: entitlement,
                entitlementReader: entitlementReader,
                initialRuntime: initialRuntime,
                eventCapacity: eventCapacity,
                eventTimeProvider: eventTimeProvider
            )
            await processor.startRouteObservation()
            routeMonitor.refresh()
            return processor
        } catch {
            routeMonitor.stop()
            _ = try? await runtime.stop(at: 0)
            await decoder.close()
            throw error
        }
    }

    fileprivate static func makeIntent(
        revision: SpatialAudioSemanticRevision,
        route: SpatialAudioRouteCapabilityState,
        entitlement: SpatialAudioEntitlementState,
        preferences: SessionSpatialAudioPreferences
    ) -> SpatialAudioGraphIntent {
        SpatialAudioGraphIntent(
            revision: revision,
            platform: .current,
            route: route.snapshot(revision: revision),
            entitlement: entitlement,
            userEnablesSpatialAudio: preferences.spatialAudioEnabled,
            userEnablesHeadTracking: preferences.headTrackingEnabled
        )
    }

    fileprivate static func readEntitlement(
        platform: SpatialAudioPlatform,
        reader: any HeadPoseEntitlementReading
    ) -> SpatialAudioEntitlementState {
        platform == .visionOS
            ? .notRequired
            : reader.readHeadPoseEntitlement()
    }
}

actor NativeSessionAudioProcessor: SessionAudioProcessing {
    static let defaultEventCapacity = 16
    static let maximumEventCapacity = 64

    private let sessionID: UUID
    private let configuration: NegotiatedAudioStreamConfiguration
    private let samplesPerFrame: UInt32
    private let decoder: any SessionAudioDecoding
    private let runtime: SessionAudioRuntime
    private let routeMonitor: SpatialAudioRouteMonitor
    private let routeStream: AsyncStream<SpatialAudioRouteMonitorSnapshot>
    private let entitlementReader: any HeadPoseEntitlementReading
    private let eventTimeProvider:
        NativeSessionAudioProcessorFactory.EventTimeProvider
    private let operationGate = NativeSessionAudioProcessorOperationGate()
    private let eventStream: AsyncStream<SessionAudioRuntimeEvent>
    private let eventContinuation:
        AsyncStream<SessionAudioRuntimeEvent>.Continuation

    private var jitterBuffer: AudioPacketJitterBuffer
    private var routeObservationTask: Task<Void, Never>?
    private var latestReceiveTimeNanoseconds: UInt64 = 0
    private var latestRuntimeEventTimeNanoseconds: UInt64 = 0
    private var nextPresentationTimeNanoseconds: UInt64 = 0
    private var nextRTPTimeStamp: UInt32?
    private var currentRoute: SpatialAudioRouteSemanticState
    private var lastRouteSourceRevision: SpatialAudioSemanticRevision
    private var currentIntent: SpatialAudioGraphIntent
    private var currentPreferences: SessionSpatialAudioPreferences
    private var currentEntitlement: SpatialAudioEntitlementState
    private var latestRuntime: SessionAudioRuntimeSnapshot
    private var mobileAudioApplication: SessionMobileAudioApplication?
    private var isMobileAudioPolicyPaused = false
    private var isSystemAudioInterrupted = false
    private var graphGeneration: UInt64 = 1
    private var nextEventSequence: UInt64 = 1
    private var isStopping = false
    private var isStopped = false
    private var isFailed = false

    init(
        sessionID: UUID,
        configuration: NegotiatedAudioStreamConfiguration,
        decoder: any SessionAudioDecoding,
        runtime: SessionAudioRuntime,
        routeMonitor: SpatialAudioRouteMonitor,
        routeStream: AsyncStream<SpatialAudioRouteMonitorSnapshot>,
        initialRoute: SpatialAudioRouteMonitorSnapshot,
        initialIntent: SpatialAudioGraphIntent,
        initialPreferences: SessionSpatialAudioPreferences,
        initialEntitlement: SpatialAudioEntitlementState,
        entitlementReader: any HeadPoseEntitlementReading,
        initialRuntime: SessionAudioRuntimeSnapshot,
        eventCapacity: Int = defaultEventCapacity,
        eventTimeProvider: @escaping
            NativeSessionAudioProcessorFactory.EventTimeProvider = {
                DispatchTime.now().uptimeNanoseconds
            }
    ) throws {
        guard let samplesPerFrame = UInt32(exactly: configuration.samplesPerFrame) else {
            throw RuntimeContractError.invalidAudioConfiguration
        }
        guard (1...Self.maximumEventCapacity).contains(eventCapacity) else {
            throw NativeSessionAudioProcessorError.invalidEventCapacity(
                eventCapacity
            )
        }
        let pair = AsyncStream<SessionAudioRuntimeEvent>.makeStream(
            bufferingPolicy: .bufferingNewest(eventCapacity)
        )

        self.sessionID = sessionID
        self.configuration = configuration
        self.samplesPerFrame = samplesPerFrame
        self.decoder = decoder
        self.runtime = runtime
        self.routeMonitor = routeMonitor
        self.routeStream = routeStream
        self.entitlementReader = entitlementReader
        self.eventTimeProvider = eventTimeProvider
        self.eventStream = pair.stream
        self.eventContinuation = pair.continuation
        self.currentRoute = initialRoute.state
        self.lastRouteSourceRevision = initialRoute.revision
        self.currentIntent = initialIntent
        self.currentPreferences = initialPreferences
        self.currentEntitlement = initialEntitlement
        self.latestRuntime = initialRuntime
        jitterBuffer = try AudioPacketJitterBuffer(
            policy: AudioJitterBufferPolicy.realtime(configuration: configuration)
        )

        pair.continuation.yield(SessionAudioRuntimeEvent(
            sessionID: sessionID,
            sequence: 0,
            graphGeneration: graphGeneration,
            cause: .initial,
            stage: initialRuntime.stage,
            spatialRuntime: initialRuntime.pipeline.spatialRuntime,
            routeCapability: initialIntent.route,
            entitlement: initialEntitlement,
            preferences: initialPreferences,
            concealedFrameCount: initialRuntime.concealedFrameCount,
            lastAction: initialRuntime.lastAction,
            mobileAudioSessionActive:
                initialRuntime.pipeline.mobileAudioSessionActive
        ))
    }

    func startRouteObservation() {
        guard routeObservationTask == nil, !isStopping, !isStopped, !isFailed else {
            return
        }
        let stream = routeStream
        routeObservationTask = Task { [weak self] in
            for await snapshot in stream {
                guard !Task.isCancelled else { break }
                await self?.receiveRouteSnapshot(snapshot)
            }
        }
    }

    func audioRuntimeEvents() async -> AsyncStream<SessionAudioRuntimeEvent> {
        eventStream
    }

    func updateSpatialAudioPreferences(
        _ preferences: SessionSpatialAudioPreferences
    ) async throws {
        try await serializedOperation {
            guard !self.isStopping, !self.isStopped else {
                throw AudioRuntimeRecoveryError.stopped
            }
            guard !self.isFailed else {
                throw AudioRuntimeRecoveryError.invalidState
            }
            guard preferences != self.currentPreferences else { return }

            let eventTime = self.nextRuntimeEventTime()
            let intent = try self.makeNextIntent(
                route: self.currentRoute.route,
                preferences: preferences
            )
            do {
                let snapshot = try await self.runtime.applySpatialPolicy(
                    intent,
                    at: eventTime
                )
                self.currentIntent = intent
                self.currentPreferences = preferences
                self.latestRuntimeEventTimeNanoseconds = eventTime
                self.latestRuntime = snapshot
                try self.publish(
                    snapshot,
                    cause: .preferencesChanged
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                await self.convergeRuntimeFailure(at: eventTime)
                throw error
            }
        }
    }

    func applyMobileAudio(
        _ application: SessionMobileAudioApplication
    ) async throws {
        do {
            let shouldStop = try await serializedOperation {
                try await self.applyMobileAudioSerialized(application)
            }
            if shouldStop {
                await stop()
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as SessionMediaEnvironmentError {
            throw error
        } catch {
            await convergeRuntimeFailure(at: nextRuntimeEventTime())
            throw error
        }
    }

    private func applyMobileAudioSerialized(
        _ application: SessionMobileAudioApplication
    ) async throws -> Bool {
        guard application.sessionID == sessionID,
              application.mediaGeneration > 0,
              application.generation.mediaGeneration
                == application.mediaGeneration else {
            throw SessionMediaEnvironmentError.staleMobileRuntimeApplication
        }
        if let current = mobileAudioApplication {
            if application == current { return false }
            guard application.revision.rawValue > current.revision.rawValue else {
                throw SessionMediaEnvironmentError.staleMobileRuntimeApplication
            }
        }
        guard !isStopping, !isStopped else {
            throw AudioRuntimeRecoveryError.stopped
        }
        guard !isFailed else {
            throw AudioRuntimeRecoveryError.invalidState
        }

        switch application.directive {
        case .continuePlayback:
            guard isMobileAudioPolicyPaused else {
                mobileAudioApplication = application
                return false
            }
            try resetJitterBufferForContinuityTransition()
            if !isSystemAudioInterrupted {
                if latestRuntime.stage == .interrupted {
                    let eventTime = nextRuntimeEventTime()
                    let snapshot = try await runtime.handle(
                        .interruptionEnded(shouldResume: true),
                        at: eventTime
                    )
                    latestRuntimeEventTimeNanoseconds = eventTime
                    latestRuntime = snapshot
                    try publish(snapshot, cause: .mobilePolicyResumed)
                } else {
                    guard latestRuntime.stage == .running else {
                        throw AudioRuntimeRecoveryError.invalidState
                    }
                }
            }
            isMobileAudioPolicyPaused = false
            mobileAudioApplication = application
            return false

        case .pause:
            guard !isMobileAudioPolicyPaused else {
                mobileAudioApplication = application
                return false
            }
            try resetJitterBufferForContinuityTransition()
            if latestRuntime.stage == .running {
                let eventTime = nextRuntimeEventTime()
                let snapshot = try await runtime.handle(
                    .interruptionBegan,
                    at: eventTime
                )
                latestRuntimeEventTimeNanoseconds = eventTime
                latestRuntime = snapshot
                try publish(snapshot, cause: .mobilePolicyPaused)
            } else {
                guard latestRuntime.stage == .interrupted else {
                    throw AudioRuntimeRecoveryError.invalidState
                }
            }
            isMobileAudioPolicyPaused = true
            mobileAudioApplication = application
            return false

        case .stop:
            mobileAudioApplication = application
            return true
        }
    }

    func consume(_ event: AudioReceiveEvent) async throws -> Bool {
        try await serializedOperation {
            try await self.consumeSerialized(event)
        }
    }

    private func consumeSerialized(
        _ event: AudioReceiveEvent
    ) async throws -> Bool {
        guard !isStopping, !isStopped else {
            throw AudioRuntimeRecoveryError.stopped
        }
        guard !isFailed else {
            throw AudioRuntimeRecoveryError.invalidState
        }
        if isMobileAudioPolicyPaused {
            if case let .packet(packet) = event {
                latestReceiveTimeNanoseconds = max(
                    latestReceiveTimeNanoseconds,
                    packet.receiveTimeNanoseconds
                )
            }
            return false
        }
        switch event {
        case let .packet(packet):
            latestReceiveTimeNanoseconds = max(
                latestReceiveTimeNanoseconds,
                packet.receiveTimeNanoseconds
            )
            var events = try jitterBuffer.ingest(packet)
            events += try jitterBuffer.advanceTime(to: latestReceiveTimeNanoseconds)
            return try await process(
                events,
                eventTimeNanoseconds: latestReceiveTimeNanoseconds
            )
        case .packetLoss:
            return false
        case .closed:
            let events = try jitterBuffer.finish(at: latestReceiveTimeNanoseconds)
            return try await process(
                events,
                eventTimeNanoseconds: latestReceiveTimeNanoseconds
            )
        }
    }

    func stop() async {
        guard !isStopping, !isStopped else { return }
        isStopping = true

        let observation = routeObservationTask
        routeObservationTask = nil
        observation?.cancel()
        routeMonitor.stop()
        await observation?.value

        await operationGate.acquire()
        if !isStopped {
            let stopTime = max(
                latestReceiveTimeNanoseconds,
                latestRuntimeEventTimeNanoseconds,
                nextPresentationTimeNanoseconds
            )
            if let snapshot = try? await runtime.stop(at: stopTime) {
                latestRuntime = snapshot
                latestRuntimeEventTimeNanoseconds = stopTime
                try? publish(snapshot, cause: .stopped, allowDuringStop: true)
            }
            await decoder.close()
            isStopped = true
            eventContinuation.finish()
        }
        await operationGate.release()
    }

    private func receiveRouteSnapshot(
        _ snapshot: SpatialAudioRouteMonitorSnapshot
    ) async {
        do {
            try await serializedOperation {
                try await self.receiveRouteSnapshotSerialized(snapshot)
            }
        } catch is CancellationError {
            return
        } catch {
            let eventTime = nextRuntimeEventTime()
            await convergeRuntimeFailure(at: eventTime)
        }
    }

    private func receiveRouteSnapshotSerialized(
        _ snapshot: SpatialAudioRouteMonitorSnapshot
    ) async throws {
        guard !isStopping, !isStopped, !isFailed else { return }
        guard snapshot.revision > lastRouteSourceRevision else { return }

        lastRouteSourceRevision = snapshot.revision
        guard snapshot.state != currentRoute else { return }
        currentRoute = snapshot.state

        let eventTime = nextRuntimeEventTime()
        let intent = try makeNextIntent(
            route: snapshot.state.route,
            preferences: currentPreferences
        )
        let runtimeSnapshot: SessionAudioRuntimeSnapshot
        switch snapshot.trigger {
        case .interruptionBegan, .mediaServicesLost:
            isSystemAudioInterrupted = true
            if latestRuntime.stage == .running {
                _ = try await runtime.handle(.interruptionBegan, at: eventTime)
            }
            runtimeSnapshot = try await runtime.applySpatialPolicy(
                intent,
                at: eventTime
            )

        case let .interruptionEnded(shouldResume):
            isSystemAudioInterrupted = !shouldResume
            let applied = try await runtime.applySpatialPolicy(
                intent,
                at: eventTime
            )
            if applied.stage == .interrupted {
                if !shouldResume {
                    runtimeSnapshot = try await runtime.handle(
                        .interruptionEnded(shouldResume: false),
                        at: eventTime
                    )
                } else if !isMobileAudioPolicyPaused {
                    runtimeSnapshot = try await runtime.handle(
                        .interruptionEnded(shouldResume: true),
                        at: eventTime
                    )
                } else {
                    runtimeSnapshot = applied
                }
            } else {
                runtimeSnapshot = applied
            }

        case .mediaServicesReset:
            isSystemAudioInterrupted = false
            let applied = try await runtime.applySpatialPolicy(
                intent,
                at: eventTime
            )
            if applied.stage == .interrupted,
               !isMobileAudioPolicyPaused {
                runtimeSnapshot = try await runtime.handle(
                    .interruptionEnded(shouldResume: true),
                    at: eventTime
                )
            } else {
                runtimeSnapshot = applied
            }

        case .initial, .routeChanged, .spatialPlaybackCapabilityChanged,
             .refresh:
            runtimeSnapshot = try await runtime.applySpatialPolicy(
                intent,
                at: eventTime
            )
        }

        currentIntent = intent
        latestRuntimeEventTimeNanoseconds = eventTime
        latestRuntime = runtimeSnapshot
        try publish(
            runtimeSnapshot,
            cause: Self.eventCause(for: snapshot.trigger)
        )
    }

    private func resetJitterBufferForContinuityTransition() throws {
        jitterBuffer = try AudioPacketJitterBuffer(
            policy: .realtime(configuration: configuration)
        )
        nextRTPTimeStamp = nil
        nextPresentationTimeNanoseconds = latestRuntimeEventTimeNanoseconds
    }

    private func process(
        _ events: [AudioJitterBufferEvent],
        eventTimeNanoseconds: UInt64
    ) async throws -> Bool {
        var scheduledDecodedAudio = false
        for (index, event) in events.enumerated() {
            switch event {
            case let .packetReady(packet):
                let decoded = try await decoder.decode(packet)
                let presentationTime = max(
                    eventTimeNanoseconds,
                    latestRuntimeEventTimeNanoseconds,
                    nextPresentationTimeNanoseconds
                )
                _ = try await runtime.schedule(
                    decoded,
                    presentationTimeNanoseconds: presentationTime
                )
                latestRuntimeEventTimeNanoseconds = presentationTime
                scheduledDecodedAudio = true
                nextPresentationTimeNanoseconds = try addingDuration(
                    frames: decoded.frameCount,
                    to: presentationTime
                )
                nextRTPTimeStamp = packet.timestamp &+ samplesPerFrame

            case let .packetsLost(loss):
                let firstRTPTimeStamp = nextRTPTimeStamp
                    ?? inferredLossTimestamp(loss, remainingEvents: events[(index + 1)...])
                    ?? 0
                let presentationTime = max(
                    eventTimeNanoseconds,
                    latestRuntimeEventTimeNanoseconds,
                    nextPresentationTimeNanoseconds
                )
                let snapshot = try await runtime.handle(
                    .packetLoss(
                        firstSequenceNumber: loss.firstSequenceNumber,
                        firstRTPTimeStamp: firstRTPTimeStamp,
                        packetCount: loss.packetCount,
                        samplesPerPacket: configuration.samplesPerFrame
                    ),
                    at: presentationTime
                )
                latestRuntimeEventTimeNanoseconds = presentationTime
                latestRuntime = snapshot
                try publish(snapshot, cause: .recovery)

                let totalFrames = try multipliedFrames(packetCount: loss.packetCount)
                nextPresentationTimeNanoseconds = try addingDuration(
                    frames: totalFrames,
                    to: presentationTime
                )
                guard let totalFrames = UInt32(exactly: totalFrames) else {
                    throw AudioRuntimeRecoveryError.arithmeticOverflow
                }
                nextRTPTimeStamp = firstRTPTimeStamp &+ totalFrames

            case .packetDiscarded:
                break
            }
        }
        return scheduledDecodedAudio
    }

    private func makeNextIntent(
        route: SpatialAudioRouteCapabilityState,
        preferences: SessionSpatialAudioPreferences
    ) throws -> SpatialAudioGraphIntent {
        guard currentIntent.revision.rawValue < UInt64.max else {
            throw NativeSessionAudioProcessorError.policyRevisionExhausted
        }
        let revision = SpatialAudioSemanticRevision(
            rawValue: currentIntent.revision.rawValue + 1
        )
        currentEntitlement = NativeSessionAudioProcessorFactory.readEntitlement(
            platform: currentIntent.platform,
            reader: entitlementReader
        )
        return NativeSessionAudioProcessorFactory.makeIntent(
            revision: revision,
            route: route,
            entitlement: currentEntitlement,
            preferences: preferences
        )
    }

    private func nextRuntimeEventTime() -> UInt64 {
        max(
            eventTimeProvider(),
            latestReceiveTimeNanoseconds,
            latestRuntimeEventTimeNanoseconds,
            nextPresentationTimeNanoseconds
        )
    }

    private func publish(
        _ snapshot: SessionAudioRuntimeSnapshot,
        cause: SessionAudioRuntimeEventCause,
        allowDuringStop: Bool = false
    ) throws {
        guard !isFailed, !isStopped,
              allowDuringStop || !isStopping else {
            return
        }
        if Self.establishesGraph(snapshot) {
            guard graphGeneration < UInt64.max else {
                throw NativeSessionAudioProcessorError.graphGenerationExhausted
            }
            graphGeneration += 1
        }
        guard nextEventSequence < UInt64.max else {
            throw NativeSessionAudioProcessorError.eventSequenceExhausted
        }
        eventContinuation.yield(SessionAudioRuntimeEvent(
            sessionID: sessionID,
            sequence: nextEventSequence,
            graphGeneration: graphGeneration,
            cause: cause,
            stage: snapshot.stage,
            spatialRuntime: snapshot.pipeline.spatialRuntime,
            routeCapability: currentIntent.route,
            entitlement: currentEntitlement,
            preferences: currentPreferences,
            concealedFrameCount: snapshot.concealedFrameCount,
            lastAction: snapshot.lastAction,
            mobileAudioSessionActive:
                snapshot.pipeline.mobileAudioSessionActive
        ))
        nextEventSequence += 1
    }

    private func convergeRuntimeFailure(at eventTime: UInt64) async {
        guard !isFailed, !isStopped else { return }
        isFailed = true
        routeMonitor.stop()

        let snapshot = try? await runtime.snapshot(
            at: max(eventTime, latestRuntimeEventTimeNanoseconds)
        )
        if let snapshot, nextEventSequence < UInt64.max {
            latestRuntime = snapshot
            eventContinuation.yield(SessionAudioRuntimeEvent(
                sessionID: sessionID,
                sequence: nextEventSequence,
                graphGeneration: graphGeneration,
                cause: .failed,
                stage: snapshot.stage,
                spatialRuntime: snapshot.pipeline.spatialRuntime,
                routeCapability: currentIntent.route,
                entitlement: currentEntitlement,
                preferences: currentPreferences,
                concealedFrameCount: snapshot.concealedFrameCount,
                lastAction: snapshot.lastAction,
                mobileAudioSessionActive:
                    snapshot.pipeline.mobileAudioSessionActive
            ))
            nextEventSequence += 1
        }
        eventContinuation.finish()
    }

    private static func establishesGraph(
        _ snapshot: SessionAudioRuntimeSnapshot
    ) -> Bool {
        switch snapshot.lastAction {
        case .graphRebuilt, .interruptionResumed:
            true
        case .none, .routeChangeDeferred, .spatialPolicyDeferred,
             .spatialPolicyUnchanged, .interruptionPaused,
             .interruptionResumeDeferred, .silenceScheduled, .stopped:
            false
        }
    }

    private static func eventCause(
        for trigger: SpatialAudioRouteMonitorTrigger
    ) -> SessionAudioRuntimeEventCause {
        switch trigger {
        case .initial:
            .initial
        case .routeChanged:
            .routeChanged
        case .interruptionBegan:
            .interruptionBegan
        case .interruptionEnded:
            .interruptionEnded
        case .mediaServicesLost:
            .mediaServicesLost
        case .mediaServicesReset:
            .mediaServicesReset
        case .spatialPlaybackCapabilityChanged:
            .spatialCapabilityChanged
        case .refresh:
            .routeRefreshed
        }
    }

    private func serializedOperation<Value>(
        _ operation: () async throws -> Value
    ) async throws -> Value {
        await operationGate.acquire()
        do {
            try Task.checkCancellation()
            let value = try await operation()
            await operationGate.release()
            return value
        } catch {
            await operationGate.release()
            throw error
        }
    }

    private func inferredLossTimestamp(
        _ loss: AudioPacketLossRange,
        remainingEvents: ArraySlice<AudioJitterBufferEvent>
    ) -> UInt32? {
        let (missingFrameCount, overflow) = loss.packetCount.multipliedReportingOverflow(
            by: configuration.samplesPerFrame
        )
        guard !overflow,
              let futureTimestamp = remainingEvents.compactMap({ event -> UInt32? in
            guard case let .packetReady(packet) = event else { return nil }
            return packet.timestamp
        }).first,
        let missingFrames = UInt32(exactly: missingFrameCount) else {
            return nil
        }
        return futureTimestamp &- missingFrames
    }

    private func multipliedFrames(packetCount: Int) throws -> Int {
        let (frames, overflow) = packetCount.multipliedReportingOverflow(
            by: configuration.samplesPerFrame
        )
        guard packetCount > 0, !overflow else {
            throw AudioRuntimeRecoveryError.arithmeticOverflow
        }
        return frames
    }

    private func addingDuration(frames: Int, to time: UInt64) throws -> UInt64 {
        guard let frames = UInt64(exactly: frames) else {
            throw AudioRuntimeRecoveryError.arithmeticOverflow
        }
        let (product, productOverflow) = frames.multipliedReportingOverflow(
            by: 1_000_000_000
        )
        guard !productOverflow else {
            throw AudioRuntimeRecoveryError.arithmeticOverflow
        }
        let duration = product / UInt64(configuration.sampleRate)
        let (result, additionOverflow) = time.addingReportingOverflow(duration)
        guard !additionOverflow else {
            throw AudioRuntimeRecoveryError.arithmeticOverflow
        }
        return result
    }
}
