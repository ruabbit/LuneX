import Foundation

enum SessionMediaEnvironmentError: Error, Equatable, Sendable, CustomStringConvertible {
    case missingProvider(String)
    case sessionAlreadyActive
    case inactiveSession
    case configurationMismatch
    case streamEnded(SessionChannelReadiness)
    case staleLifecycleApplication
    case inputUnavailable
    case staleInputApplication

    var description: String {
        switch self {
        case let .missingProvider(name):
            return "The required \(name) provider is unavailable."
        case .sessionAlreadyActive:
            return "A media session generation is already active."
        case .inactiveSession:
            return "The requested media session generation is not active."
        case .configurationMismatch:
            return "The negotiated media configuration does not match the session generation."
        case let .streamEnded(channel):
            return "The \(Self.name(for: channel)) receiver ended before session teardown."
        case .staleLifecycleApplication:
            return "The lifecycle application does not belong to the current media generation or revision."
        case .inputUnavailable:
            return "The active media generation is not ready to accept input."
        case .staleInputApplication:
            return "The input application does not belong to the current media generation."
        }
    }

    private static func name(for channel: SessionChannelReadiness) -> String {
        switch channel {
        case .video: "video"
        case .audio: "audio"
        case .input: "input"
        default: "media"
        }
    }
}

enum SessionMediaEnvironmentEvent: Equatable, Sendable {
    case readiness(SessionChannelReadiness)
    case feedback(RemoteInputFeedback)
}

struct SessionMediaEnvironmentSnapshot: Equatable, Sendable {
    var sessionID: UUID?
    var generation: UInt64
    var readiness: SessionChannelReadiness
    var resourcePhase: SessionResourceTrackerSnapshot.Phase?
    var activeTaskCount: Int
    var activeResourceCount: Int
    var lastTeardownReport: SessionTeardownReport?
    var lifecycleApplication: SessionLifecycleApplication? = nil
}

struct SessionLifecycleApplication: Equatable, Sendable {
    var sessionID: UUID
    var mediaGeneration: UInt64
    var lifecycleRevision: UInt64
    var directive: SessionLifecycleDirective
}

struct SessionInputApplication: Equatable, Sendable {
    var sessionID: UUID
    var mediaGeneration: UInt64
    var event: RemoteInputEvent
}

struct SessionInputReleaseApplication: Equatable, Sendable {
    var sessionID: UUID
    var mediaGeneration: UInt64
}

protocol SessionVideoProcessing: Sendable {
    func consume(_ event: VideoReceiveEvent) async throws -> Bool
    func updateColorMetadata(_ metadata: VideoColorMetadata) async throws
    func applyLifecycle(_ application: SessionLifecycleApplication) async throws
    func stop() async
}

protocol SessionVideoProcessorCreating: Sendable {
    func makeVideoProcessor(
        sessionID: UUID,
        mediaGeneration: UInt64,
        configuration: NegotiatedVideoStreamConfiguration,
        controlProvider: any SessionControlProvider
    ) async throws -> any SessionVideoProcessing
}

protocol SessionAudioProcessing: Sendable {
    func consume(_ event: AudioReceiveEvent) async throws -> Bool
    func stop() async
}

protocol SessionAudioProcessorCreating: Sendable {
    func makeAudioProcessor(
        sessionID: UUID,
        configuration: NegotiatedAudioStreamConfiguration
    ) async throws -> any SessionAudioProcessing
}

protocol SessionMediaEnvironment: Sendable {
    func start(
        sessionID: UUID,
        configuration: NegotiatedSessionConfiguration,
        controlProvider: any SessionControlProvider
    ) async throws -> AsyncThrowingStream<SessionMediaEnvironmentEvent, Error>

    func updateVideoColorMetadata(
        _ metadata: VideoColorMetadata,
        sessionID: UUID
    ) async throws

    func applyLifecycle(_ application: SessionLifecycleApplication) async throws

    func sendInput(_ application: SessionInputApplication) async throws

    func releaseInput(_ application: SessionInputReleaseApplication) async throws

    @discardableResult
    func stop(sessionID: UUID) async -> SessionTeardownReport?

    func snapshot() async -> SessionMediaEnvironmentSnapshot
}

actor NativeSessionMediaEnvironment: SessionMediaEnvironment {
    private typealias EventContinuation = AsyncThrowingStream<
        SessionMediaEnvironmentEvent,
        Error
    >.Continuation

    private struct ActiveSession {
        var sessionID: UUID
        var generation: UInt64
        var tracker: SessionResourceTracker
        var continuation: EventContinuation
        var videoProcessor: any SessionVideoProcessing
        var audioProcessor: any SessionAudioProcessing
        var inputProvider: any RemoteInputProvider
        var readiness: SessionChannelReadiness
        var lifecycleApplication: SessionLifecycleApplication?
        var lifecycleReservation: SessionLifecycleApplication?
    }

    private struct TeardownOperation {
        var sessionID: UUID
        var generation: UInt64
        var task: Task<SessionTeardownReport?, Never>
    }

    private struct StartingSession {
        var sessionID: UUID
        var generation: UInt64
        var tracker: SessionResourceTracker
    }

    private struct LifecycleOperation {
        var application: SessionLifecycleApplication
        var task: Task<Void, Error>
    }

    private let videoReceiveProvider: (any VideoReceiveProvider)?
    private let audioReceiveProvider: (any AudioReceiveProvider)?
    private let remoteInputProvider: (any RemoteInputProvider)?
    private let videoProcessorFactory: any SessionVideoProcessorCreating
    private let audioProcessorFactory: any SessionAudioProcessorCreating
    private let teardownGracePeriod: Duration

    private var active: ActiveSession?
    private var generation: UInt64 = 0
    private var lastTeardownReport: SessionTeardownReport?
    private var lastStoppedSessionID: UUID?
    private var teardownOperation: TeardownOperation?
    private var lifecycleOperation: LifecycleOperation?
    private var startingSession: StartingSession?
    private var cancelledStartingGenerations: Set<UInt64> = []

    init(
        videoReceiveProvider: (any VideoReceiveProvider)?,
        audioReceiveProvider: (any AudioReceiveProvider)?,
        remoteInputProvider: (any RemoteInputProvider)?,
        videoProcessorFactory: any SessionVideoProcessorCreating,
        audioProcessorFactory: any SessionAudioProcessorCreating,
        teardownGracePeriod: Duration = .seconds(2)
    ) {
        self.videoReceiveProvider = videoReceiveProvider
        self.audioReceiveProvider = audioReceiveProvider
        self.remoteInputProvider = remoteInputProvider
        self.videoProcessorFactory = videoProcessorFactory
        self.audioProcessorFactory = audioProcessorFactory
        self.teardownGracePeriod = teardownGracePeriod
    }

    func start(
        sessionID: UUID,
        configuration: NegotiatedSessionConfiguration,
        controlProvider: any SessionControlProvider
    ) async throws -> AsyncThrowingStream<SessionMediaEnvironmentEvent, Error> {
        guard active == nil else {
            throw SessionMediaEnvironmentError.sessionAlreadyActive
        }
        guard startingSession == nil else {
            throw SessionMediaEnvironmentError.sessionAlreadyActive
        }
        if let teardownOperation {
            _ = await teardownOperation.task.value
            if self.teardownOperation?.generation == teardownOperation.generation {
                self.teardownOperation = nil
            }
        }
        guard active == nil, startingSession == nil else {
            throw SessionMediaEnvironmentError.sessionAlreadyActive
        }
        guard configuration.sessionID == sessionID else {
            throw SessionMediaEnvironmentError.configurationMismatch
        }
        try configuration.validate()
        guard let videoReceiveProvider else {
            throw SessionMediaEnvironmentError.missingProvider("video receiver")
        }
        guard let audioReceiveProvider else {
            throw SessionMediaEnvironmentError.missingProvider("audio receiver")
        }
        guard let remoteInputProvider else {
            throw SessionMediaEnvironmentError.missingProvider("remote input")
        }

        generation &+= 1
        let mediaGeneration = generation
        let tracker = SessionResourceTracker()
        startingSession = StartingSession(
            sessionID: sessionID,
            generation: mediaGeneration,
            tracker: tracker
        )
        lastTeardownReport = nil
        lastStoppedSessionID = nil

        do {
            _ = try await tracker.registerResource(
                kind: .networkChannel,
                name: "video-receiver"
            ) {
                await videoReceiveProvider.stopVideo(sessionID: sessionID)
            }
            _ = try await tracker.registerResource(
                kind: .networkChannel,
                name: "audio-receiver"
            ) {
                await audioReceiveProvider.stopAudio(sessionID: sessionID)
            }

            let videoProcessor = try await videoProcessorFactory.makeVideoProcessor(
                sessionID: sessionID,
                mediaGeneration: mediaGeneration,
                configuration: configuration.video,
                controlProvider: controlProvider
            )
            do {
                _ = try await tracker.registerResource(kind: .decoder, name: "video-processor") {
                    await videoProcessor.stop()
                }
            } catch {
                await videoProcessor.stop()
                throw error
            }

            let audioProcessor = try await audioProcessorFactory.makeAudioProcessor(
                sessionID: sessionID,
                configuration: configuration.audio
            )
            do {
                _ = try await tracker.registerResource(kind: .audioGraph, name: "audio-processor") {
                    await audioProcessor.stop()
                }
            } catch {
                await audioProcessor.stop()
                throw error
            }

            _ = try await tracker.registerResource(kind: .inputQueue, name: "remote-input") {
                await remoteInputProvider.releaseAll(sessionID: sessionID)
                await remoteInputProvider.stopInput(sessionID: sessionID)
            }

            let videoStream = await videoReceiveProvider.receiveVideo(
                sessionID: sessionID,
                endpoint: configuration.videoEndpoint,
                configuration: configuration.video
            )
            let audioStream = await audioReceiveProvider.receiveAudio(
                sessionID: sessionID,
                endpoint: configuration.audioEndpoint,
                configuration: configuration.audio
            )
            try await remoteInputProvider.startInput(
                sessionID: sessionID,
                endpoint: configuration.inputEndpoint,
                configuration: configuration.input
            )
            let feedbackStream = await remoteInputProvider.feedback(sessionID: sessionID)
            guard startingSession?.sessionID == sessionID,
                  startingSession?.generation == mediaGeneration,
                  !cancelledStartingGenerations.contains(mediaGeneration) else {
                throw CancellationError()
            }
            let pair = AsyncThrowingStream<SessionMediaEnvironmentEvent, Error>.makeStream()
            pair.continuation.onTermination = { [weak self] termination in
                guard case .cancelled = termination else { return }
                Task {
                    await self?.consumerCancelled(
                        sessionID: sessionID,
                        generation: mediaGeneration
                    )
                }
            }
            active = ActiveSession(
                sessionID: sessionID,
                generation: mediaGeneration,
                tracker: tracker,
                continuation: pair.continuation,
                videoProcessor: videoProcessor,
                audioProcessor: audioProcessor,
                inputProvider: remoteInputProvider,
                readiness: [.input],
                lifecycleApplication: nil,
                lifecycleReservation: nil
            )
            startingSession = nil
            cancelledStartingGenerations.remove(mediaGeneration)

            _ = try await tracker.startTask(name: "video-consumer") { [weak self] in
                do {
                    for try await event in videoStream {
                        try Task.checkCancellation()
                        if case .closed = event {
                            throw SessionMediaEnvironmentError.streamEnded(.video)
                        }
                        if try await videoProcessor.consume(event) {
                            await self?.markReady(
                                .video,
                                sessionID: sessionID,
                                generation: mediaGeneration
                            )
                        }
                    }
                    try Task.checkCancellation()
                    throw SessionMediaEnvironmentError.streamEnded(.video)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    await self?.fail(
                        error,
                        sessionID: sessionID,
                        generation: mediaGeneration
                    )
                    throw error
                }
            }
            _ = try await tracker.startTask(name: "audio-consumer") { [weak self] in
                do {
                    for try await event in audioStream {
                        try Task.checkCancellation()
                        if case .closed = event {
                            throw SessionMediaEnvironmentError.streamEnded(.audio)
                        }
                        if try await audioProcessor.consume(event) {
                            await self?.markReady(
                                .audio,
                                sessionID: sessionID,
                                generation: mediaGeneration
                            )
                        }
                    }
                    try Task.checkCancellation()
                    throw SessionMediaEnvironmentError.streamEnded(.audio)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    await self?.fail(
                        error,
                        sessionID: sessionID,
                        generation: mediaGeneration
                    )
                    throw error
                }
            }
            _ = try await tracker.startTask(name: "input-feedback-consumer") { [weak self] in
                do {
                    for await feedback in feedbackStream {
                        try Task.checkCancellation()
                        await self?.publishFeedback(
                            feedback,
                            sessionID: sessionID,
                            generation: mediaGeneration
                        )
                    }
                    try Task.checkCancellation()
                    throw SessionMediaEnvironmentError.streamEnded(.input)
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    await self?.fail(
                        error,
                        sessionID: sessionID,
                        generation: mediaGeneration
                    )
                    throw error
                }
            }

            guard let active,
                  active.sessionID == sessionID,
                  active.generation == mediaGeneration else {
                throw SessionMediaEnvironmentError.inactiveSession
            }
            active.continuation.yield(.readiness(active.readiness))
            return pair.stream
        } catch {
            if let active,
               active.sessionID == sessionID,
               active.generation == mediaGeneration {
                self.active = nil
                active.continuation.finish(throwing: error)
            }
            let report: SessionTeardownReport?
            if let teardownOperation,
               teardownOperation.sessionID == sessionID,
               teardownOperation.generation == mediaGeneration {
                report = await teardownOperation.task.value
                if self.teardownOperation?.generation == mediaGeneration {
                    self.teardownOperation = nil
                }
            } else {
                report = try? await tracker.teardown(gracePeriod: teardownGracePeriod)
            }
            lastTeardownReport = report
            lastStoppedSessionID = sessionID
            if startingSession?.generation == mediaGeneration {
                startingSession = nil
            }
            cancelledStartingGenerations.remove(mediaGeneration)
            throw error
        }
    }

    func updateVideoColorMetadata(
        _ metadata: VideoColorMetadata,
        sessionID: UUID
    ) async throws {
        guard let active, active.sessionID == sessionID else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        try await active.videoProcessor.updateColorMetadata(metadata)
    }

    func applyLifecycle(_ application: SessionLifecycleApplication) async throws {
        guard var active, active.sessionID == application.sessionID else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard active.generation == application.mediaGeneration else {
            throw SessionMediaEnvironmentError.staleLifecycleApplication
        }
        let effectTask: Task<Void, Error>
        if let operation = lifecycleOperation,
           operation.application == application,
           active.lifecycleReservation == application {
            effectTask = operation.task
        } else {
            if let reservation = active.lifecycleReservation {
                guard application.lifecycleRevision > reservation.lifecycleRevision else {
                    throw SessionMediaEnvironmentError.staleLifecycleApplication
                }
            } else if let current = active.lifecycleApplication {
                if application == current { return }
                guard application.lifecycleRevision > current.lifecycleRevision else {
                    throw SessionMediaEnvironmentError.staleLifecycleApplication
                }
            }
            active.lifecycleReservation = application
            self.active = active
            let processor = active.videoProcessor
            let task = Task {
                try await processor.applyLifecycle(application)
            }
            lifecycleOperation = LifecycleOperation(
                application: application,
                task: task
            )
            effectTask = task
        }

        do {
            try await effectTask.value
        } catch {
            if var current = self.active,
               current.sessionID == application.sessionID,
               current.generation == application.mediaGeneration,
               current.lifecycleReservation == application {
                current.lifecycleReservation = nil
                self.active = current
            }
            if lifecycleOperation?.application == application {
                lifecycleOperation = nil
            }
            throw error
        }

        guard var current = self.active,
              current.sessionID == application.sessionID,
              current.generation == application.mediaGeneration else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        if current.lifecycleApplication == application,
           current.lifecycleReservation == nil {
            if lifecycleOperation?.application == application {
                lifecycleOperation = nil
            }
            return
        }
        guard current.lifecycleReservation == application else {
            throw SessionMediaEnvironmentError.staleLifecycleApplication
        }
        current.lifecycleApplication = application
        current.lifecycleReservation = nil
        self.active = current
        if lifecycleOperation?.application == application {
            lifecycleOperation = nil
        }
    }

    func sendInput(_ application: SessionInputApplication) async throws {
        guard let active, active.sessionID == application.sessionID else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard active.generation == application.mediaGeneration else {
            throw SessionMediaEnvironmentError.staleInputApplication
        }
        guard active.readiness.contains(.input) else {
            throw SessionMediaEnvironmentError.inputUnavailable
        }
        try await active.inputProvider.send(
            application.event,
            sessionID: application.sessionID
        )
    }

    func releaseInput(_ application: SessionInputReleaseApplication) async throws {
        guard let active, active.sessionID == application.sessionID else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard active.generation == application.mediaGeneration else {
            throw SessionMediaEnvironmentError.staleInputApplication
        }
        await active.inputProvider.releaseAll(sessionID: application.sessionID)
        guard let current = self.active,
              current.sessionID == application.sessionID else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard current.generation == application.mediaGeneration else {
            throw SessionMediaEnvironmentError.staleInputApplication
        }
    }

    @discardableResult
    func stop(sessionID: UUID) async -> SessionTeardownReport? {
        guard let active else {
            if let startingSession,
               startingSession.sessionID == sessionID {
                cancelledStartingGenerations.insert(startingSession.generation)
                let operation: TeardownOperation
                if let teardownOperation,
                   teardownOperation.sessionID == sessionID,
                   teardownOperation.generation == startingSession.generation {
                    operation = teardownOperation
                } else {
                    operation = makeTeardownOperation(
                        sessionID: sessionID,
                        generation: startingSession.generation,
                        tracker: startingSession.tracker
                    )
                    teardownOperation = operation
                }
                let report = await operation.task.value
                lastTeardownReport = report
                lastStoppedSessionID = sessionID
                return report
            }
            if let teardownOperation,
               teardownOperation.sessionID == sessionID {
                let report = await teardownOperation.task.value
                if self.teardownOperation?.generation == teardownOperation.generation {
                    self.teardownOperation = nil
                }
                lastTeardownReport = report
                lastStoppedSessionID = sessionID
                return report
            }
            return lastStoppedSessionID == sessionID ? lastTeardownReport : nil
        }
        guard active.sessionID == sessionID else { return nil }

        self.active = nil
        lifecycleOperation = nil
        active.continuation.finish()
        let operation = makeTeardownOperation(for: active)
        teardownOperation = operation
        let report = await operation.task.value
        if teardownOperation?.generation == operation.generation {
            teardownOperation = nil
        }
        lastTeardownReport = report
        lastStoppedSessionID = sessionID
        return report
    }

    func snapshot() async -> SessionMediaEnvironmentSnapshot {
        guard let active else {
            return SessionMediaEnvironmentSnapshot(
                sessionID: nil,
                generation: generation,
                readiness: [],
                resourcePhase: nil,
                activeTaskCount: 0,
                activeResourceCount: 0,
                lastTeardownReport: lastTeardownReport,
                lifecycleApplication: nil
            )
        }
        let resources = await active.tracker.snapshot()
        return SessionMediaEnvironmentSnapshot(
            sessionID: active.sessionID,
            generation: active.generation,
            readiness: active.readiness,
            resourcePhase: resources.phase,
            activeTaskCount: resources.activeTasks.count,
            activeResourceCount: resources.activeResources.count,
            lastTeardownReport: lastTeardownReport,
            lifecycleApplication: active.lifecycleApplication
        )
    }

    private func publishFeedback(
        _ feedback: RemoteInputFeedback,
        sessionID: UUID,
        generation: UInt64
    ) {
        guard let active,
              active.sessionID == sessionID,
              active.generation == generation else { return }
        active.continuation.yield(.feedback(feedback))
    }

    private func markReady(
        _ channel: SessionChannelReadiness,
        sessionID: UUID,
        generation: UInt64
    ) {
        guard var active,
              active.sessionID == sessionID,
              active.generation == generation,
              !active.readiness.contains(channel) else { return }
        active.readiness.insert(channel)
        self.active = active
        active.continuation.yield(.readiness(active.readiness))
    }

    private func fail(
        _ error: Error,
        sessionID: UUID,
        generation: UInt64
    ) async {
        guard let active,
              active.sessionID == sessionID,
              active.generation == generation else { return }
        self.active = nil
        lifecycleOperation = nil
        active.continuation.finish(throwing: error)
        let operation = makeTeardownOperation(for: active)
        teardownOperation = operation
        Task { [weak self] in
            let report = await operation.task.value
            await self?.recordTeardown(
                report,
                sessionID: sessionID,
                generation: generation
            )
        }
    }

    private func consumerCancelled(
        sessionID: UUID,
        generation: UInt64
    ) async {
        guard let active,
              active.sessionID == sessionID,
              active.generation == generation else { return }
        _ = await stop(sessionID: sessionID)
    }

    private func makeTeardownOperation(
        for active: ActiveSession
    ) -> TeardownOperation {
        makeTeardownOperation(
            sessionID: active.sessionID,
            generation: active.generation,
            tracker: active.tracker
        )
    }

    private func makeTeardownOperation(
        sessionID: UUID,
        generation: UInt64,
        tracker: SessionResourceTracker
    ) -> TeardownOperation {
        let gracePeriod = teardownGracePeriod
        return TeardownOperation(
            sessionID: sessionID,
            generation: generation,
            task: Task {
                try? await tracker.teardown(gracePeriod: gracePeriod)
            }
        )
    }

    private func recordTeardown(
        _ report: SessionTeardownReport?,
        sessionID: UUID,
        generation: UInt64
    ) {
        guard teardownOperation?.sessionID == sessionID,
              teardownOperation?.generation == generation else { return }
        teardownOperation = nil
        lastTeardownReport = report
        lastStoppedSessionID = sessionID
    }
}
