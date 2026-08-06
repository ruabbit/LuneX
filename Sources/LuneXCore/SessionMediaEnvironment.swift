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
    case staleAudioApplication
    case staleMobileRuntimeApplication
    case invalidMobileRuntimeApplication
    case staleTVVisionPlatformPresentationApplication
    case invalidTVVisionPlatformPresentationApplication

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
        case .staleAudioApplication:
            return "The audio preference application does not belong to the current media generation."
        case .staleMobileRuntimeApplication:
            return "The mobile runtime application does not belong to the current media generation or revision."
        case .invalidMobileRuntimeApplication:
            return "The mobile runtime application is internally inconsistent."
        case .staleTVVisionPlatformPresentationApplication:
            return "The platform presentation application does not belong to the current media generation or ownership."
        case .invalidTVVisionPlatformPresentationApplication:
            return "The platform presentation application is internally inconsistent."
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
    case videoPresentation(StreamVideoPresentationEvent)
    case audioRuntime(SessionMediaAudioRuntimeState)
    case mobileRuntime(SessionMobileRuntimeState)
    case tvVisionPlatformPresentation(
        SessionTVVisionPlatformPresentationState
    )
}

enum SessionTVVisionPlatformPresentationAction: Equatable, Sendable {
    case activate
    case scene(TVVisionStreamGeometryBindingUpdate)
    case input(
        snapshot: TVVisionInputCapabilitySnapshot,
        controllerLeases: [TVVisionControllerLease]
    )
    case display(TVVisionDisplaySnapshot)
    case audioRoute(TVVisionAudioRouteSnapshot)
    case fail(TVVisionPlatformPresentationFailure)
    case stop(TVVisionPlatformPresentationStopReason)
}

struct SessionTVVisionPlatformPresentationApplication: Equatable, Sendable {
    let ownership: TVVisionPresentationOwnership
    let action: SessionTVVisionPlatformPresentationAction
}

struct SessionTVVisionPlatformPresentationState: Equatable, Sendable {
    let sessionID: UUID
    let mediaGeneration: UInt64
    let snapshot: TVVisionPlatformPresentationCoordinatorSnapshot
}

struct SessionMediaAudioRuntimeState: Equatable, Sendable {
    var sessionID: UUID
    var mediaGeneration: UInt64
    var runtime: SessionAudioRuntimeEvent
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
    var audioRuntime: SessionMediaAudioRuntimeState? = nil
    var mobileRuntime: SessionMobileRuntimeState? = nil
    var tvVisionPlatformPresentation:
        SessionTVVisionPlatformPresentationState? = nil
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

struct SessionSpatialAudioPreferenceApplication: Equatable, Sendable {
    var sessionID: UUID
    var mediaGeneration: UInt64
    var preferences: SessionSpatialAudioPreferences
}

protocol SessionVideoProcessing: Sendable {
    func consume(_ event: VideoReceiveEvent) async throws -> Bool
    func updateColorMetadata(_ metadata: VideoColorMetadata) async throws
    func applyLifecycle(_ application: SessionLifecycleApplication) async throws
    func applyMobileVideo(
        _ application: SessionMobileVideoApplication
    ) async throws
    func stop() async
}

protocol SessionVideoProcessorCreating: Sendable {
    func makeVideoProcessor(
        sessionID: UUID,
        mediaGeneration: UInt64,
        configuration: NegotiatedVideoStreamConfiguration,
        controlProvider: any SessionControlProvider,
        presentationEventSink: @escaping @Sendable (
            StreamVideoPresentationEvent
        ) -> Void
    ) async throws -> any SessionVideoProcessing
}

protocol SessionAudioProcessing: Sendable {
    func consume(_ event: AudioReceiveEvent) async throws -> Bool
    func audioRuntimeEvents() async -> AsyncStream<SessionAudioRuntimeEvent>
    func updateSpatialAudioPreferences(
        _ preferences: SessionSpatialAudioPreferences
    ) async throws
    func applyMobileAudio(
        _ application: SessionMobileAudioApplication
    ) async throws
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

    func updateSpatialAudioPreferences(
        _ application: SessionSpatialAudioPreferenceApplication
    ) async throws

    func applyMobileRuntime(
        _ application: SessionMobileRuntimeApplication
    ) async throws

    func applyTVVisionPlatformPresentation(
        _ application: SessionTVVisionPlatformPresentationApplication
    ) async throws

    func sendInput(_ application: SessionInputApplication) async throws

    func releaseInput(_ application: SessionInputReleaseApplication) async throws

    @discardableResult
    func stop(sessionID: UUID) async -> SessionTeardownReport?

    func snapshot() async -> SessionMediaEnvironmentSnapshot
}

extension SessionMediaEnvironment {
    func applyMobileRuntime(
        _ application: SessionMobileRuntimeApplication
    ) async throws {
        _ = application
        throw SessionMediaEnvironmentError.invalidMobileRuntimeApplication
    }

    func applyTVVisionPlatformPresentation(
        _ application: SessionTVVisionPlatformPresentationApplication
    ) async throws {
        _ = application
        throw SessionMediaEnvironmentError
            .invalidTVVisionPlatformPresentationApplication
    }
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
        var audioRuntime: SessionMediaAudioRuntimeState?
        var mobileRuntime: SessionMobileRuntimeState?
        var mobileRuntimeReservation: SessionMobileRuntimeApplication?
        var mobileRuntimeOwner: MobileMediaGenerationOwner
        var tvVisionPlatformCoordinator:
            TVVisionPlatformPresentationCoordinator
        var tvVisionPlatformPresentation:
            SessionTVVisionPlatformPresentationState?
        var tvVisionPlatformOwnership: TVVisionPresentationOwnership?
        var tvVisionPlatformSubscription:
            StreamVideoPresentationSubscription?
    }

    private struct TeardownOperation {
        var sessionID: UUID
        var generation: UInt64
        var task: Task<SessionTeardownReport?, Never>
    }

    private struct ActiveTerminationOperation {
        var sessionID: UUID
        var generation: UInt64
        var task: Task<Void, Never>
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

    private struct MobileRuntimeOperation {
        var application: SessionMobileRuntimeApplication
        var task: Task<MobileMediaGenerationPublicationOutcome, Error>
    }

    private let videoReceiveProvider: (any VideoReceiveProvider)?
    private let audioReceiveProvider: (any AudioReceiveProvider)?
    private let remoteInputProvider: (any RemoteInputProvider)?
    private let videoProcessorFactory: any SessionVideoProcessorCreating
    private let audioProcessorFactory: any SessionAudioProcessorCreating
    private let videoPresentationSource: StreamVideoPresentationSource?
    private let tvVisionPlatformCoordinatorFactory:
        @Sendable () throws -> TVVisionPlatformPresentationCoordinator
    private let teardownGracePeriod: Duration

    private var active: ActiveSession?
    private var generation: UInt64 = 0
    private var lastTeardownReport: SessionTeardownReport?
    private var lastStoppedSessionID: UUID?
    private var teardownOperation: TeardownOperation?
    private var activeTerminationOperation: ActiveTerminationOperation?
    private var lifecycleOperation: LifecycleOperation?
    private var mobileRuntimeOperation: MobileRuntimeOperation?
    private var startingSession: StartingSession?
    private var cancelledStartingGenerations: Set<UInt64> = []

    init(
        videoReceiveProvider: (any VideoReceiveProvider)?,
        audioReceiveProvider: (any AudioReceiveProvider)?,
        remoteInputProvider: (any RemoteInputProvider)?,
        videoProcessorFactory: any SessionVideoProcessorCreating,
        audioProcessorFactory: any SessionAudioProcessorCreating,
        videoPresentationSource: StreamVideoPresentationSource? = nil,
        tvVisionPlatformCoordinatorFactory: @escaping @Sendable () throws
            -> TVVisionPlatformPresentationCoordinator = {
                try TVVisionPlatformPresentationCoordinator()
            },
        teardownGracePeriod: Duration = .seconds(2)
    ) {
        self.videoReceiveProvider = videoReceiveProvider
        self.audioReceiveProvider = audioReceiveProvider
        self.remoteInputProvider = remoteInputProvider
        self.videoProcessorFactory = videoProcessorFactory
        self.audioProcessorFactory = audioProcessorFactory
        self.videoPresentationSource = videoPresentationSource
        self.tvVisionPlatformCoordinatorFactory =
            tvVisionPlatformCoordinatorFactory
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
                controlProvider: controlProvider,
                presentationEventSink: { event in
                    pair.continuation.yield(.videoPresentation(event))
                }
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
            let audioRuntimeStream = await audioProcessor.audioRuntimeEvents()
            try await remoteInputProvider.startInput(
                sessionID: sessionID,
                endpoint: configuration.inputEndpoint,
                configuration: configuration.input
            )
            let feedbackStream = await remoteInputProvider.feedback(sessionID: sessionID)
            let tvVisionPlatformCoordinator =
                try tvVisionPlatformCoordinatorFactory()
            guard startingSession?.sessionID == sessionID,
                  startingSession?.generation == mediaGeneration,
                  !cancelledStartingGenerations.contains(mediaGeneration) else {
                throw CancellationError()
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
                lifecycleReservation: nil,
                audioRuntime: nil,
                mobileRuntime: nil,
                mobileRuntimeReservation: nil,
                mobileRuntimeOwner: MobileMediaGenerationOwner(
                    actionClient: SessionMobileMediaActionClient(
                        sessionID: sessionID,
                        mediaGeneration: mediaGeneration,
                        videoProcessor: videoProcessor,
                        audioProcessor: audioProcessor,
                        controlProvider: controlProvider,
                        inputProvider: remoteInputProvider
                    )
                ),
                tvVisionPlatformCoordinator: tvVisionPlatformCoordinator,
                tvVisionPlatformPresentation: nil,
                tvVisionPlatformOwnership: nil,
                tvVisionPlatformSubscription: nil
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
            _ = try await tracker.startTask(name: "audio-runtime-consumer") { [weak self] in
                do {
                    for await event in audioRuntimeStream {
                        try Task.checkCancellation()
                        await self?.publishAudioRuntime(
                            event,
                            sessionID: sessionID,
                            generation: mediaGeneration
                        )
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
            pair.continuation.finish(throwing: error)
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

    func updateSpatialAudioPreferences(
        _ application: SessionSpatialAudioPreferenceApplication
    ) async throws {
        guard let active, active.sessionID == application.sessionID else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard active.generation == application.mediaGeneration else {
            throw SessionMediaEnvironmentError.staleAudioApplication
        }
        let processor = active.audioProcessor
        do {
            try await processor.updateSpatialAudioPreferences(
                application.preferences
            )
        } catch {
            guard let current = self.active,
                  current.sessionID == application.sessionID,
                  current.generation == application.mediaGeneration else {
                throw SessionMediaEnvironmentError.staleAudioApplication
            }
            throw error
        }
        guard let current = self.active,
              current.sessionID == application.sessionID,
              current.generation == application.mediaGeneration else {
            throw SessionMediaEnvironmentError.staleAudioApplication
        }
    }

    func applyMobileRuntime(
        _ application: SessionMobileRuntimeApplication
    ) async throws {
        do {
            try application.validate()
        } catch {
            throw SessionMediaEnvironmentError.invalidMobileRuntimeApplication
        }
        guard var active, active.sessionID == application.sessionID else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard active.generation == application.mediaGeneration else {
            throw SessionMediaEnvironmentError.staleMobileRuntimeApplication
        }
        let effectTask: Task<MobileMediaGenerationPublicationOutcome, Error>
        if let operation = mobileRuntimeOperation,
           operation.application == application,
           active.mobileRuntimeReservation == application {
            effectTask = operation.task
        } else {
            if let reservation = active.mobileRuntimeReservation {
                guard application.revision.rawValue
                        > reservation.revision.rawValue else {
                    throw SessionMediaEnvironmentError
                        .staleMobileRuntimeApplication
                }
            } else if let current = active.mobileRuntime?.application {
                if application == current { return }
                guard application.revision.rawValue
                        > current.revision.rawValue else {
                    throw SessionMediaEnvironmentError
                        .staleMobileRuntimeApplication
                }
            }

            active.mobileRuntimeReservation = application
            self.active = active
            let owner = active.mobileRuntimeOwner
            let task = Task {
                try await owner.apply(application.generationInput)
            }
            mobileRuntimeOperation = MobileRuntimeOperation(
                application: application,
                task: task
            )
            effectTask = task
        }

        let outcome: MobileMediaGenerationPublicationOutcome
        do {
            outcome = try await effectTask.value
        } catch {
            if var current = self.active,
               current.sessionID == application.sessionID,
               current.generation == application.mediaGeneration,
               current.mobileRuntimeReservation == application {
                current.mobileRuntimeReservation = nil
                self.active = current
            }
            if mobileRuntimeOperation?.application == application {
                mobileRuntimeOperation = nil
            }
            if error is MobileMediaGenerationOwnerError {
                throw SessionMediaEnvironmentError
                    .staleMobileRuntimeApplication
            }
            throw error
        }

        guard var current = self.active,
              current.sessionID == application.sessionID,
              current.generation == application.mediaGeneration else {
            throw SessionMediaEnvironmentError.staleMobileRuntimeApplication
        }
        if current.mobileRuntime?.application == application,
           current.mobileRuntimeReservation == nil {
            if mobileRuntimeOperation?.application == application {
                mobileRuntimeOperation = nil
            }
            return
        }
        guard current.mobileRuntimeReservation == application else {
            throw SessionMediaEnvironmentError.staleMobileRuntimeApplication
        }
        let media = outcome.snapshot
        let state = SessionMobileRuntimeState(
            application: application,
            media: media
        )
        current.mobileRuntime = state
        current.mobileRuntimeReservation = nil
        self.active = current
        if mobileRuntimeOperation?.application == application {
            mobileRuntimeOperation = nil
        }
        current.continuation.yield(.mobileRuntime(state))
    }

    func applyTVVisionPlatformPresentation(
        _ application: SessionTVVisionPlatformPresentationApplication
    ) async throws {
        guard let active,
              active.sessionID == application.ownership.sessionID else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard active.generation == application.ownership.mediaGeneration else {
            throw SessionMediaEnvironmentError
                .staleTVVisionPlatformPresentationApplication
        }

        let coordinator = active.tvVisionPlatformCoordinator
        let outcome: TVVisionPlatformPresentationCoordinatorOutcome
        switch application.action {
        case .activate:
            outcome = await coordinator.activate(application.ownership)
        case let .scene(update):
            outcome = await coordinator.applyScene(
                update,
                ownership: application.ownership
            )
        case let .input(snapshot, controllerLeases):
            outcome = await coordinator.applyInput(
                snapshot,
                controllerLeases: controllerLeases,
                ownership: application.ownership
            )
        case let .display(snapshot):
            outcome = await coordinator.applyDisplay(
                snapshot,
                ownership: application.ownership
            )
        case let .audioRoute(snapshot):
            outcome = await coordinator.applyAudioRoute(
                snapshot,
                ownership: application.ownership
            )
        case let .fail(failure):
            outcome = await coordinator.fail(
                ownership: application.ownership,
                failure: failure
            )
        case let .stop(reason):
            outcome = await coordinator.stop(
                ownership: application.ownership,
                reason: reason
            )
        }

        let state = try await publishTVVisionPlatformOutcome(
            outcome,
            expectedOwnership: application.ownership
        )
        switch application.action {
        case .activate where state.snapshot.phase == .active:
            try await installTVVisionPlatformSubscription(
                ownership: application.ownership
            )
        case .fail, .stop:
            clearTVVisionPlatformSubscription(
                ownership: application.ownership
            )
        default:
            if case .failed = state.snapshot.phase {
                clearTVVisionPlatformSubscription(
                    ownership: application.ownership
                )
            }
        }
    }

    private func publishTVVisionPlatformOutcome(
        _ outcome: TVVisionPlatformPresentationCoordinatorOutcome,
        expectedOwnership: TVVisionPresentationOwnership
    ) async throws -> SessionTVVisionPlatformPresentationState {
        let snapshot: TVVisionPlatformPresentationCoordinatorSnapshot
        switch outcome {
        case let .applied(value),
             let .unchanged(value),
             let .failed(value):
            snapshot = value
        case .staleOwnership, .staleRevision:
            throw SessionMediaEnvironmentError
                .staleTVVisionPlatformPresentationApplication
        }
        guard snapshot.ownership == expectedOwnership,
              var current = active,
              current.sessionID == expectedOwnership.sessionID,
              current.generation == expectedOwnership.mediaGeneration else {
            throw SessionMediaEnvironmentError
                .staleTVVisionPlatformPresentationApplication
        }

        let state = SessionTVVisionPlatformPresentationState(
            sessionID: current.sessionID,
            mediaGeneration: current.generation,
            snapshot: snapshot
        )
        if let existing = current.tvVisionPlatformPresentation {
            if existing.snapshot.ownership == snapshot.ownership {
                guard snapshot.sequence >= existing.snapshot.sequence else {
                    throw SessionMediaEnvironmentError
                        .staleTVVisionPlatformPresentationApplication
                }
                if state == existing { return state }
            }
        }
        if current.tvVisionPlatformOwnership != expectedOwnership {
            current.tvVisionPlatformSubscription?.cancel()
            current.tvVisionPlatformSubscription = nil
        }
        current.tvVisionPlatformOwnership = expectedOwnership
        current.tvVisionPlatformPresentation = state
        self.active = current
        current.continuation.yield(.tvVisionPlatformPresentation(state))
        return state
    }

    private func installTVVisionPlatformSubscription(
        ownership: TVVisionPresentationOwnership
    ) async throws {
        guard var current = active,
              current.sessionID == ownership.sessionID,
              current.generation == ownership.mediaGeneration,
              current.tvVisionPlatformOwnership == ownership else {
            throw SessionMediaEnvironmentError
                .staleTVVisionPlatformPresentationApplication
        }
        if current.tvVisionPlatformSubscription != nil { return }
        guard let videoPresentationSource else { return }
        guard let subscription = videoPresentationSource.subscribe(
            sessionID: ownership.sessionID,
            mediaGeneration: ownership.mediaGeneration,
            handler: { [weak self] delivery in
                Task {
                    await self?.receiveTVVisionPlatformVideo(
                        delivery,
                        ownership: ownership
                    )
                }
            }
        ) else {
            let outcome = await current.tvVisionPlatformCoordinator.fail(
                ownership: ownership,
                failure: .invalidComponent(.video)
            )
            _ = try await publishTVVisionPlatformOutcome(
                outcome,
                expectedOwnership: ownership
            )
            throw SessionMediaEnvironmentError
                .invalidTVVisionPlatformPresentationApplication
        }
        guard let latest = active,
              latest.sessionID == ownership.sessionID,
              latest.generation == ownership.mediaGeneration,
              latest.tvVisionPlatformOwnership == ownership else {
            subscription.cancel()
            throw SessionMediaEnvironmentError
                .staleTVVisionPlatformPresentationApplication
        }
        current = latest
        current.tvVisionPlatformSubscription = subscription
        self.active = current
    }

    private func receiveTVVisionPlatformVideo(
        _ delivery: StreamVideoPresentationDelivery,
        ownership: TVVisionPresentationOwnership
    ) async {
        guard let current = active,
              current.sessionID == ownership.sessionID,
              current.generation == ownership.mediaGeneration,
              current.tvVisionPlatformOwnership == ownership else { return }
        let outcome = await current.tvVisionPlatformCoordinator.receiveVideo(
            delivery,
            ownership: ownership
        )
        guard let state = try? await publishTVVisionPlatformOutcome(
            outcome,
            expectedOwnership: ownership
        ) else { return }
        if case .failed = state.snapshot.phase {
            clearTVVisionPlatformSubscription(ownership: ownership)
        }
    }

    private func clearTVVisionPlatformSubscription(
        ownership: TVVisionPresentationOwnership
    ) {
        guard var current = active,
              current.sessionID == ownership.sessionID,
              current.generation == ownership.mediaGeneration,
              current.tvVisionPlatformOwnership == ownership else { return }
        current.tvVisionPlatformSubscription?.cancel()
        current.tvVisionPlatformSubscription = nil
        self.active = current
    }

    func sendInput(_ application: SessionInputApplication) async throws {
        guard let active, active.sessionID == application.sessionID else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard active.generation == application.mediaGeneration else {
            throw SessionMediaEnvironmentError.staleInputApplication
        }
        if let reservation = active.mobileRuntimeReservation {
            let pendingPlan = MobileMediaGenerationPlanResolver.resolve(
                reservation.continuityContext,
                foregroundBaseline: reservation.foregroundBaseline,
                restoringForeground: false
            )
            guard pendingPlan.control == .continueSession else {
                throw SessionMediaEnvironmentError.inputUnavailable
            }
        }
        guard active.mobileRuntime?.media.plan.control != .pauseSession,
              active.mobileRuntime?.media.plan.control != .stopSession else {
            throw SessionMediaEnvironmentError.inputUnavailable
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
        if let operation = activeTerminationOperation,
           operation.sessionID == sessionID {
            await operation.task.value
            return await completedTeardownReport(
                sessionID: sessionID,
                generation: operation.generation
            )
        }
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

        let generation = active.generation
        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.prepareActiveStop(
                sessionID: sessionID,
                generation: generation
            )
        }
        let operation = ActiveTerminationOperation(
            sessionID: sessionID,
            generation: generation,
            task: task
        )
        activeTerminationOperation = operation
        await task.value
        if activeTerminationOperation?.sessionID == sessionID,
           activeTerminationOperation?.generation == generation {
            activeTerminationOperation = nil
        }
        return await completedTeardownReport(
            sessionID: sessionID,
            generation: generation
        )
    }

    private func prepareActiveStop(
        sessionID: UUID,
        generation: UInt64
    ) async {
        guard let active,
              active.sessionID == sessionID,
              active.generation == generation else { return }
        if let ownership = active.tvVisionPlatformOwnership {
            let outcome = await active.tvVisionPlatformCoordinator.stop(
                ownership: ownership,
                reason: .localStop
            )
            _ = try? await publishTVVisionPlatformOutcome(
                outcome,
                expectedOwnership: ownership
            )
        }
        guard let current = self.active,
              current.sessionID == sessionID,
              current.generation == generation else { return }
        current.tvVisionPlatformSubscription?.cancel()
        let operation = makeTeardownOperation(for: current)
        self.active = nil
        lifecycleOperation = nil
        mobileRuntimeOperation = nil
        teardownOperation = operation
        current.continuation.finish()
    }

    private func completedTeardownReport(
        sessionID: UUID,
        generation: UInt64
    ) async -> SessionTeardownReport? {
        guard let operation = teardownOperation,
              operation.sessionID == sessionID,
              operation.generation == generation else {
            return lastStoppedSessionID == sessionID
                ? lastTeardownReport
                : nil
        }
        let report = await operation.task.value
        if teardownOperation?.sessionID == sessionID,
           teardownOperation?.generation == operation.generation {
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
                lifecycleApplication: nil,
                audioRuntime: nil,
                mobileRuntime: nil,
                tvVisionPlatformPresentation: nil
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
            lifecycleApplication: active.lifecycleApplication,
            audioRuntime: active.audioRuntime,
            mobileRuntime: active.mobileRuntime,
            tvVisionPlatformPresentation:
                active.tvVisionPlatformPresentation
        )
    }

    private func publishAudioRuntime(
        _ event: SessionAudioRuntimeEvent,
        sessionID: UUID,
        generation: UInt64
    ) {
        guard var active,
              active.sessionID == sessionID,
              active.generation == generation,
              event.sessionID == sessionID else { return }
        if let current = active.audioRuntime?.runtime {
            guard event.sequence > current.sequence,
                  event.graphGeneration >= current.graphGeneration else {
                return
            }
        }
        let state = SessionMediaAudioRuntimeState(
            sessionID: sessionID,
            mediaGeneration: generation,
            runtime: event
        )
        active.audioRuntime = state
        self.active = active
        active.continuation.yield(.audioRuntime(state))
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
        if let operation = activeTerminationOperation,
           operation.sessionID == sessionID,
           operation.generation == generation {
            await operation.task.value
            return
        }
        guard let active,
              active.sessionID == sessionID,
              active.generation == generation else { return }

        let task = Task<Void, Never> { [weak self] in
            guard let self else { return }
            await self.prepareActiveFailure(
                error,
                sessionID: sessionID,
                generation: generation
            )
        }
        let operation = ActiveTerminationOperation(
            sessionID: sessionID,
            generation: generation,
            task: task
        )
        activeTerminationOperation = operation
        await task.value
        if activeTerminationOperation?.sessionID == sessionID,
           activeTerminationOperation?.generation == generation {
            activeTerminationOperation = nil
        }
    }

    private func prepareActiveFailure(
        _ error: Error,
        sessionID: UUID,
        generation: UInt64
    ) async {
        guard let active,
              active.sessionID == sessionID,
              active.generation == generation else { return }
        if let ownership = active.tvVisionPlatformOwnership {
            let outcome = await active.tvVisionPlatformCoordinator.stop(
                ownership: ownership,
                reason: .failure
            )
            _ = try? await publishTVVisionPlatformOutcome(
                outcome,
                expectedOwnership: ownership
            )
        }
        guard let current = self.active,
              current.sessionID == sessionID,
              current.generation == generation else { return }
        current.tvVisionPlatformSubscription?.cancel()
        let operation = makeTeardownOperation(for: current)
        self.active = nil
        lifecycleOperation = nil
        mobileRuntimeOperation = nil
        teardownOperation = operation
        current.continuation.finish(throwing: error)
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

    private nonisolated static func stopMobileRuntime(
        _ owner: MobileMediaGenerationOwner
    ) async {
        guard let snapshot = await owner.snapshot(),
              snapshot.phase == .active else { return }
        let nextRevision = snapshot.revision.rawValue.addingReportingOverflow(1)
        guard !nextRevision.overflow,
              let revision = MobileMediaGenerationRevision(
                rawValue: nextRevision.partialValue
              ) else { return }
        _ = try? await owner.stop(
            ownership: snapshot.ownership,
            revision: revision
        )
    }

    private func makeTeardownOperation(
        for active: ActiveSession
    ) -> TeardownOperation {
        let gracePeriod = teardownGracePeriod
        let owner = active.mobileRuntimeOwner
        let tvVisionCoordinator = active.tvVisionPlatformCoordinator
        let tvVisionOwnership = active.tvVisionPlatformOwnership
        let tvVisionSubscription = active.tvVisionPlatformSubscription
        let tracker = active.tracker
        return TeardownOperation(
            sessionID: active.sessionID,
            generation: active.generation,
            task: Task {
                tvVisionSubscription?.cancel()
                if let tvVisionOwnership {
                    _ = await tvVisionCoordinator.stop(
                        ownership: tvVisionOwnership,
                        reason: .localStop
                    )
                }
                await Self.stopMobileRuntime(owner)
                return try? await tracker.teardown(gracePeriod: gracePeriod)
            }
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

private extension MobileMediaGenerationPublicationOutcome {
    var snapshot: MobileMediaGenerationSnapshot {
        switch self {
        case let .unchanged(snapshot),
             let .stateUpdated(snapshot),
             let .actionsApplied(snapshot):
            snapshot
        }
    }
}

private actor SessionMobileMediaActionClient:
    MobileMediaGenerationActionApplying
{
    private enum Step: Equatable, Hashable, Sendable {
        case video
        case audio
        case releaseInput
        case control
    }

    private struct Progress: Sendable {
        let application: MobileMediaGenerationActionApplication
        var completed: Set<Step>
    }

    let sessionID: UUID
    let mediaGeneration: UInt64
    let videoProcessor: any SessionVideoProcessing
    let audioProcessor: any SessionAudioProcessing
    let controlProvider: any SessionControlProvider
    let inputProvider: any RemoteInputProvider
    private var progress: Progress?

    init(
        sessionID: UUID,
        mediaGeneration: UInt64,
        videoProcessor: any SessionVideoProcessing,
        audioProcessor: any SessionAudioProcessing,
        controlProvider: any SessionControlProvider,
        inputProvider: any RemoteInputProvider
    ) {
        self.sessionID = sessionID
        self.mediaGeneration = mediaGeneration
        self.videoProcessor = videoProcessor
        self.audioProcessor = audioProcessor
        self.controlProvider = controlProvider
        self.inputProvider = inputProvider
    }

    func apply(
        _ application: MobileMediaGenerationActionApplication
    ) async throws {
        guard application.ownership.sessionID == sessionID,
              application.ownership.generation.mediaGeneration
                == mediaGeneration else {
            throw SessionMediaEnvironmentError
                .staleMobileRuntimeApplication
        }
        let video = SessionMobileVideoApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            generation: application.ownership.generation,
            revision: application.revision,
            directive: application.plan.video
        )
        let audio = SessionMobileAudioApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            generation: application.ownership.generation,
            revision: application.revision,
            directive: application.plan.audio
        )
        let control = SessionMobileControlApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            generation: application.ownership.generation,
            revision: application.revision,
            directive: application.plan.control
        )

        let steps: [Step]
        switch application.plan.control {
        case .continueSession:
            steps = [.control, .audio, .video]
        case .pauseSession, .stopSession:
            steps = [.video, .audio, .releaseInput, .control]
        }

        if let current = progress, current.application != application {
            guard isNewer(application, than: current.application) else {
                throw SessionMediaEnvironmentError
                    .staleMobileRuntimeApplication
            }
            progress = Progress(application: application, completed: [])
        } else if progress == nil {
            progress = Progress(application: application, completed: [])
        }

        for step in steps {
            guard progress?.application == application else {
                throw SessionMediaEnvironmentError
                    .staleMobileRuntimeApplication
            }
            if progress?.completed.contains(step) == true { continue }
            try await apply(
                step,
                video: video,
                audio: audio,
                control: control
            )
            guard progress?.application == application else {
                throw SessionMediaEnvironmentError
                    .staleMobileRuntimeApplication
            }
            progress?.completed.insert(step)
        }
    }

    private func isNewer(
        _ candidate: MobileMediaGenerationActionApplication,
        than current: MobileMediaGenerationActionApplication
    ) -> Bool {
        guard candidate.ownership.sessionID == current.ownership.sessionID else {
            return false
        }
        let candidateGeneration = candidate.ownership.generation
        let currentGeneration = current.ownership.generation
        if candidateGeneration.mediaGeneration
            != currentGeneration.mediaGeneration {
            return candidateGeneration.mediaGeneration
                > currentGeneration.mediaGeneration
        }
        if candidateGeneration.pictureInPictureGeneration
            != currentGeneration.pictureInPictureGeneration {
            return candidateGeneration.pictureInPictureGeneration
                > currentGeneration.pictureInPictureGeneration
        }
        return candidate.revision.rawValue > current.revision.rawValue
    }

    private func apply(
        _ step: Step,
        video: SessionMobileVideoApplication,
        audio: SessionMobileAudioApplication,
        control: SessionMobileControlApplication
    ) async throws {
        var retryAvailable = true
        while true {
            do {
                switch step {
                case .video:
                    try await videoProcessor.applyMobileVideo(video)
                case .audio:
                    try await audioProcessor.applyMobileAudio(audio)
                case .releaseInput:
                    await inputProvider.releaseAll(sessionID: sessionID)
                case .control:
                    try await controlProvider.applyMobileControl(control)
                }
                return
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as SessionMediaEnvironmentError {
                throw error
            } catch {
                guard retryAvailable else { throw error }
                retryAvailable = false
            }
        }
    }
}
