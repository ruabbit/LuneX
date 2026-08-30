import AVFAudio
import AudioToolbox
import Foundation

struct StreamAudioConfiguration: Codable, Equatable, Hashable, Sendable {
    var sampleRate: Double
    var channelLayout: StreamAudioChannelLayout
    var latencyPolicy: AudioLatencyPolicy

    var channelCount: Int {
        channelLayout.channelCount
    }

    static let stereoLowLatency = StreamAudioConfiguration(
        sampleRate: 48_000,
        channelLayout: .stereo,
        latencyPolicy: .lowLatency
    )

    func validate() throws {
        let canonicalLayout = try? StreamAudioChannelLayout.resolve(
            channelCount: channelCount
        )
        guard sampleRate == 48_000,
              canonicalLayout == channelLayout else {
            throw AudioPipelineError.invalidConfiguration
        }
    }
}

enum AudioLatencyPolicy: String, Codable, Hashable, Sendable {
    case lowLatency
    case balanced

    var preferredBufferDuration: TimeInterval {
        switch self {
        case .lowLatency: 0.005
        case .balanced: 0.02
        }
    }
}

enum AudioPipelineStage: String, Codable, Hashable, Sendable {
    case idle
    case configured
    case running
    case draining
    case stopped
    case failed
}

enum AudioStopReason: String, Codable, Hashable, Sendable {
    case userInitiated
    case sessionEnded
    case interruption
    case backgroundPolicy
    case failure
}

struct AudioRouteSnapshot: Codable, Equatable, Hashable, Sendable {
    var outputNames: [String]
    var sampleRate: Double
    var outputChannelCount: Int
    var preferredBufferDuration: TimeInterval?
}

struct AudioPipelineSnapshot: Codable, Equatable, Hashable, Sendable {
    var stage: AudioPipelineStage
    var configuration: StreamAudioConfiguration?
    var route: AudioRouteSnapshot?
    var spatialRuntime: SpatialAudioRuntimeSnapshot?
    var lastStopReason: AudioStopReason?
    var lastErrorMessage: String?
    var updatedAt: Date
    var mobileAudioSessionActive: Bool? = nil
}

protocol AudioEngineClient: Sendable {
    func configure(
        _ configuration: StreamAudioConfiguration,
        graphIntent: SpatialAudioGraphIntent
    ) throws -> SpatialAudioRuntimeSnapshot
    func start() throws
    func schedule(
        _ buffer: DecodedPCMBuffer,
        completion: @escaping @Sendable () -> Void
    ) throws
    func stop(drain: Bool)
    func routeSnapshot() -> AudioRouteSnapshot
    func currentSpatialRouteCapability() -> SpatialAudioRouteCapabilityState
    func mobileAudioSessionActiveReadback() -> Bool?
}

extension AudioEngineClient {
    func currentSpatialRouteCapability() -> SpatialAudioRouteCapabilityState {
        let route = routeSnapshot()
        let channelCount = max(route.outputChannelCount, 0)
        return SpatialAudioRouteCapabilityState(
            outputAvailable: channelCount > 0,
            systemSpatialSupport: .unknown,
            currentOutputChannelCount: channelCount,
            maximumOutputChannelCount: channelCount
        )
    }

    func mobileAudioSessionActiveReadback() -> Bool? { nil }
}

struct AVAudioEngineGraphReadback: Equatable, Sendable {
    let mode: SpatialAudioGraphMode
    let fallbackReason: SpatialAudioGraphFallbackReason?
    let platformStrategy: SpatialAudioPlatformStrategy
    let listenerHeadTrackingCapable: Bool
    let listenerHeadTrackingReadback: Bool
    let visionExperienceReadback: VisionSpatialExperienceReadback?
    let playerAttached: Bool
    let environmentAttached: Bool
    let playerConnectedToEnvironment: Bool
    let playerConnectedToMainMixer: Bool
    let environmentConnectedToMainMixer: Bool
    let sourceModeRawValue: Int?
    let selectedRenderingAlgorithmRawValue: Int?
    let applicableRenderingAlgorithmRawValues: [Int]
    let inputLayoutTagRawValue: UInt32?
}

struct AVAudioSpatialPlatformReadback: Equatable, Sendable {
    let strategy: SpatialAudioPlatformStrategy
    let listenerHeadTrackingCapable: Bool
    let listenerHeadTrackingReadback: Bool
    let visionExperienceReadback: VisionSpatialExperienceReadback?

    static let none = AVAudioSpatialPlatformReadback(
        strategy: .none,
        listenerHeadTrackingCapable: false,
        listenerHeadTrackingReadback: false,
        visionExperienceReadback: nil
    )
}

protocol AVAudioSpatialPlatformApplying {
    func apply(
        engine: AVAudioEngine,
        environment: AVAudioEnvironmentNode,
        intent: SpatialAudioGraphIntent
    ) -> AVAudioSpatialPlatformReadback
    func reset(
        engine: AVAudioEngine,
        environment: AVAudioEnvironmentNode
    )
}

struct ProductionAVAudioSpatialPlatformAdapter:
    AVAudioSpatialPlatformApplying
{
    func apply(
        engine: AVAudioEngine,
        environment: AVAudioEnvironmentNode,
        intent: SpatialAudioGraphIntent
    ) -> AVAudioSpatialPlatformReadback {
        #if os(visionOS)
        engine.outputNode.intendedSpatialExperience =
            intent.userEnablesHeadTracking ? .headTracked : .fixed
        let actual = engine.outputNode.intendedSpatialExperience
        let experience: VisionSpatialExperienceReadback?
        if actual is HeadTrackedSpatialAudio {
            experience = .headTracked
        } else if actual is FixedSpatialAudio {
            experience = .fixed
        } else {
            experience = nil
        }
        return AVAudioSpatialPlatformReadback(
            strategy: .visionOutputExperience,
            listenerHeadTrackingCapable: false,
            listenerHeadTrackingReadback: false,
            visionExperienceReadback: experience
        )
        #else
        let requestsHeadTracking = intent.userEnablesHeadTracking
            && intent.entitlement == .granted
        environment.isListenerHeadTrackingEnabled = requestsHeadTracking
        return AVAudioSpatialPlatformReadback(
            strategy: .environmentListener,
            listenerHeadTrackingCapable: true,
            listenerHeadTrackingReadback:
                environment.isListenerHeadTrackingEnabled,
            visionExperienceReadback: nil
        )
        #endif
    }

    func reset(
        engine: AVAudioEngine,
        environment: AVAudioEnvironmentNode
    ) {
        #if os(visionOS)
        engine.outputNode.intendedSpatialExperience = .bypassed
        #else
        environment.isListenerHeadTrackingEnabled = false
        #endif
    }
}

enum AVAudioEnvironmentGraphBuildError: Error, Equatable, Sendable {
    case renderingAlgorithmUnavailable
    case configurationFailed
}

struct AVAudioEnvironmentGraphBuildResult: Equatable, Sendable {
    let applicableRenderingAlgorithmRawValues: [Int]
}

protocol AVAudioEnvironmentGraphBuilding {
    func configure(
        engine: AVAudioEngine,
        player: AVAudioPlayerNode,
        environment: AVAudioEnvironmentNode,
        format: AVAudioFormat
    ) throws -> AVAudioEnvironmentGraphBuildResult
}

struct ProductionAVAudioEnvironmentGraphBuilder:
    AVAudioEnvironmentGraphBuilding
{
    func configure(
        engine: AVAudioEngine,
        player: AVAudioPlayerNode,
        environment: AVAudioEnvironmentNode,
        format: AVAudioFormat
    ) throws -> AVAudioEnvironmentGraphBuildResult {
        engine.connect(environment, to: engine.mainMixerNode, format: nil)
        engine.connect(player, to: environment, format: format)

        let playerDestinations = engine.outputConnectionPoints(
            for: player,
            outputBus: 0
        )
        let environmentDestinations = engine.outputConnectionPoints(
            for: environment,
            outputBus: 0
        )
        guard playerDestinations.contains(where: { $0.node === environment }),
              environmentDestinations.contains(where: {
                  $0.node === engine.mainMixerNode
              }) else {
            throw AVAudioEnvironmentGraphBuildError.configurationFailed
        }

        let applicableAlgorithms = environment.applicableRenderingAlgorithms
            .compactMap {
                AVAudio3DMixingRenderingAlgorithm(rawValue: $0.intValue)
            }
        guard applicableAlgorithms.contains(.auto) else {
            throw AVAudioEnvironmentGraphBuildError
                .renderingAlgorithmUnavailable
        }

        player.sourceMode = .ambienceBed
        player.renderingAlgorithm = .auto
        guard player.sourceMode == .ambienceBed,
              player.renderingAlgorithm == .auto else {
            throw AVAudioEnvironmentGraphBuildError.configurationFailed
        }
        return AVAudioEnvironmentGraphBuildResult(
            applicableRenderingAlgorithmRawValues: applicableAlgorithms
                .map(\.rawValue)
        )
    }
}

final class AVAudioEngineClient: AudioEngineClient, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let environment = AVAudioEnvironmentNode()
    private let environmentGraphBuilder: any AVAudioEnvironmentGraphBuilding
    private let spatialPlatformAdapter: any AVAudioSpatialPlatformApplying
    private let mobileAudioSessionAdapter: any MobileAudioSessionApplying
    private let lock = NSRecursiveLock()
    private var configuration: StreamAudioConfiguration?
    private var configuredGraphMode = SpatialAudioGraphMode.unconfigured
    private var configuredGraphFallback: SpatialAudioGraphFallbackReason?
    private var applicableRenderingAlgorithmRawValues: [Int] = []
    private var platformReadback = AVAudioSpatialPlatformReadback.none

    init(
        environmentGraphBuilder: any AVAudioEnvironmentGraphBuilding =
            ProductionAVAudioEnvironmentGraphBuilder(),
        spatialPlatformAdapter: any AVAudioSpatialPlatformApplying =
            ProductionAVAudioSpatialPlatformAdapter(),
        mobileAudioSessionAdapter: any MobileAudioSessionApplying =
            MobileAudioSessionAdapter()
    ) {
        self.environmentGraphBuilder = environmentGraphBuilder
        self.spatialPlatformAdapter = spatialPlatformAdapter
        self.mobileAudioSessionAdapter = mobileAudioSessionAdapter
        engine.attach(player)
        engine.attach(environment)
    }

    func configure(
        _ configuration: StreamAudioConfiguration,
        graphIntent: SpatialAudioGraphIntent
    ) throws -> SpatialAudioRuntimeSnapshot {
        try lock.withLock {
            try configureLocked(configuration, graphIntent: graphIntent)
        }
    }

    private func configureLocked(
        _ configuration: StreamAudioConfiguration,
        graphIntent: SpatialAudioGraphIntent
    ) throws -> SpatialAudioRuntimeSnapshot {
        try configuration.validate()
        guard graphIntent.hasConsistentRevision,
              graphIntent.platform == .current else {
            throw AudioPipelineError.invalidGraphIntent
        }
        let format: AVAudioFormat
        do {
            format = try AVAudioStreamFormatFactory.makeInterleavedInt16(
                sampleRate: configuration.sampleRate,
                channelLayout: configuration.channelLayout
            )
        } catch {
            throw AudioPipelineError.invalidConfiguration
        }

        player.stop()
        if engine.isRunning {
            engine.stop()
        }
        resetGraphConnections()
        self.configuration = nil
        #if os(iOS) || os(tvOS) || os(visionOS)
        _ = try mobileAudioSessionAdapter.activate(for: configuration)
        #endif

        let usesEnvironment = environmentGraphIsEligible(
            configuration: configuration,
            graphIntent: graphIntent
        )
        if usesEnvironment {
            do {
                let graphResult = try environmentGraphBuilder.configure(
                    engine: engine,
                    player: player,
                    environment: environment,
                    format: format
                )
                applicableRenderingAlgorithmRawValues =
                    graphResult.applicableRenderingAlgorithmRawValues
                configuredGraphMode = .environmentAmbienceBed
                platformReadback = spatialPlatformAdapter.apply(
                    engine: engine,
                    environment: environment,
                    intent: graphIntent
                )
            } catch {
                resetGraphConnections()
                configuredGraphFallback = graphFallbackReason(for: error)
                try configureDirectMixer(format: format)
            }
        } else {
            try configureDirectMixer(format: format)
        }
        engine.prepare()
        self.configuration = configuration
        let graph = SpatialAudioGraphSnapshot(
            revision: graphIntent.revision,
            mode: configuredGraphMode,
            layoutSignature: configuration.channelLayout.signature,
            hasApplicableRenderingAlgorithm:
                configuredGraphMode == .environmentAmbienceBed
                    && applicableRenderingAlgorithmRawValues.contains(
                        AVAudio3DMixingRenderingAlgorithm.auto.rawValue
                    ),
            fallbackReason: configuredGraphFallback,
            platformStrategy: platformReadback.strategy,
            listenerHeadTrackingCapable:
                platformReadback.listenerHeadTrackingCapable,
            listenerHeadTrackingReadback:
                platformReadback.listenerHeadTrackingReadback,
            visionExperienceReadback:
                platformReadback.visionExperienceReadback
        )
        return SpatialAudioRuntimeResolver.resolve(
            intent: graphIntent,
            layout: configuration.channelLayout,
            graph: graph
        )
    }

    func start() throws {
        try lock.withLock {
            guard !engine.isRunning else { return }
            try engine.start()
            player.play()
        }
    }

    func schedule(
        _ buffer: DecodedPCMBuffer,
        completion: @escaping @Sendable () -> Void
    ) throws {
        try lock.withLock {
            guard configuration != nil else {
                throw AudioPipelineError.missingConfiguration
            }
            let audioBuffer = try AVAudioPCMBufferFactory.makeBuffer(from: buffer)
            player.scheduleBuffer(
                audioBuffer,
                completionCallbackType: .dataConsumed
            ) { _ in
                completion()
            }
        }
    }

    func stop(drain: Bool) {
        lock.withLock {
            player.stop()
            engine.stop()
            engine.reset()
            resetGraphConnections()
            configuration = nil
            #if os(iOS) || os(tvOS) || os(visionOS)
            mobileAudioSessionAdapter.deactivate(
                notifyOthersOnDeactivation: true
            )
            #endif
        }
    }

    func routeSnapshot() -> AudioRouteSnapshot {
        lock.withLock {
            #if os(iOS) || os(tvOS) || os(visionOS)
            return mobileAudioSessionAdapter.currentSnapshot()
                .audioRouteSnapshot(preferredConfiguration: configuration)
            #else
            return AudioRouteInspector.currentRoute(
                engine: engine,
                preferredConfiguration: configuration
            )
            #endif
        }
    }

    func currentSpatialRouteCapability() -> SpatialAudioRouteCapabilityState {
        lock.withLock {
            #if os(iOS) || os(tvOS) || os(visionOS)
            return SpatialAudioRouteCapabilityState(
                mobileAudioSessionAdapter.currentSnapshot().routeCapability(
                    revision: .init(rawValue: 0)
                )
            )
            #else
            return SpatialAudioRouteCapabilityState(
                macOSRouteOutputCapabilityLocked(
                    revision: .init(rawValue: 0)
                )
            )
            #endif
        }
    }

    func mobileAudioSessionActiveReadback() -> Bool? {
        lock.withLock {
            #if os(iOS) || os(tvOS) || os(visionOS)
            mobileAudioSessionAdapter.currentSnapshot().isActive
            #else
            nil
            #endif
        }
    }

    func macOSRouteOutputCapability(
        revision: SpatialAudioSemanticRevision
    ) -> SpatialAudioRouteCapabilitySnapshot {
        lock.withLock {
            macOSRouteOutputCapabilityLocked(revision: revision)
        }
    }

    private func macOSRouteOutputCapabilityLocked(
        revision: SpatialAudioSemanticRevision
    ) -> SpatialAudioRouteCapabilitySnapshot {
        MacAudioOutputCapabilityResolver.resolve(
            revision: revision,
            output: MacAudioOutputFormatSnapshot(
                format: engine.outputNode.outputFormat(forBus: 0)
            ),
            graph: graphReadbackLocked()
        )
    }

    func graphReadback() -> AVAudioEngineGraphReadback {
        lock.withLock {
            graphReadbackLocked()
        }
    }

    private func graphReadbackLocked() -> AVAudioEngineGraphReadback {
        let playerDestinations = engine.outputConnectionPoints(
            for: player,
            outputBus: 0
        )
        let environmentDestinations = engine.outputConnectionPoints(
            for: environment,
            outputBus: 0
        )
        let usesEnvironment = configuredGraphMode == .environmentAmbienceBed
        let inputFormat = player.outputFormat(forBus: 0)
        return AVAudioEngineGraphReadback(
            mode: configuredGraphMode,
            fallbackReason: configuredGraphFallback,
            platformStrategy: platformReadback.strategy,
            listenerHeadTrackingCapable:
                platformReadback.listenerHeadTrackingCapable,
            listenerHeadTrackingReadback:
                platformReadback.listenerHeadTrackingReadback,
            visionExperienceReadback:
                platformReadback.visionExperienceReadback,
            playerAttached: engine.attachedNodes.contains(player),
            environmentAttached: engine.attachedNodes.contains(environment),
            playerConnectedToEnvironment: playerDestinations.contains {
                $0.node === environment
            },
            playerConnectedToMainMixer: playerDestinations.contains {
                $0.node === engine.mainMixerNode
            },
            environmentConnectedToMainMixer: environmentDestinations.contains {
                $0.node === engine.mainMixerNode
            },
            sourceModeRawValue: usesEnvironment ? player.sourceMode.rawValue : nil,
            selectedRenderingAlgorithmRawValue: usesEnvironment
                ? player.renderingAlgorithm.rawValue
                : nil,
            applicableRenderingAlgorithmRawValues:
                applicableRenderingAlgorithmRawValues,
            inputLayoutTagRawValue: inputFormat.channelLayout.map {
                UInt32($0.layoutTag)
            }
        )
    }

    private func resetGraphConnections() {
        spatialPlatformAdapter.reset(
            engine: engine,
            environment: environment
        )
        engine.disconnectNodeOutput(player)
        engine.disconnectNodeOutput(environment)
        configuredGraphMode = .unconfigured
        configuredGraphFallback = nil
        applicableRenderingAlgorithmRawValues = []
        platformReadback = .none
    }

    private func configureDirectMixer(format: AVAudioFormat) throws {
        engine.connect(player, to: engine.mainMixerNode, format: format)
        let destinations = engine.outputConnectionPoints(
            for: player,
            outputBus: 0
        )
        guard destinations.contains(where: {
            $0.node === engine.mainMixerNode
        }) else {
            resetGraphConnections()
            throw AudioPipelineError.invalidConfiguration
        }
        configuredGraphMode = .nonspatialMixer
    }

    private func graphFallbackReason(
        for error: Error
    ) -> SpatialAudioGraphFallbackReason {
        switch error as? AVAudioEnvironmentGraphBuildError {
        case .renderingAlgorithmUnavailable:
            .renderingAlgorithmUnavailable
        case .configurationFailed, .none:
            .configurationFailed
        }
    }

    private func environmentGraphIsEligible(
        configuration: StreamAudioConfiguration,
        graphIntent: SpatialAudioGraphIntent
    ) -> Bool {
        let route = graphIntent.route
        guard graphIntent.userEnablesSpatialAudio,
              configuration.channelLayout.spatialEligibility == .ambienceBed,
              route.outputAvailable,
              route.currentOutputChannelCount > 0,
              route.maximumOutputChannelCount > 0,
              route.currentOutputChannelCount
                <= route.maximumOutputChannelCount else {
            return false
        }
        switch graphIntent.platform {
        case .macOS:
            return route.systemSpatialSupport != .unsupported
        case .iOS, .tvOS:
            return route.systemSpatialSupport == .supported
        case .visionOS:
            return route.systemSpatialSupport == .supported
        }
    }
}

enum AVAudioPCMBufferFactory {
    static let maximumFramesPerBuffer = 5_760

    static func makeBuffer(from decoded: DecodedPCMBuffer) throws -> AVAudioPCMBuffer {
        let format = decoded.format
        let canonicalLayout = try? StreamAudioChannelLayout.resolve(
            channelCount: format.channelCount
        )
        guard format.sampleRate == 48_000,
              canonicalLayout == format.channelLayout,
              format.bitsPerChannel == 16,
              format.isSignedInteger,
              format.isInterleaved,
              (1...maximumFramesPerBuffer).contains(decoded.frameCount),
              decoded.interleavedSamples.count == decoded.frameCount * format.channelCount,
              let frameCapacity = AVAudioFrameCount(exactly: decoded.frameCount) else {
            throw AudioPipelineError.invalidPCMBuffer
        }
        let audioFormat: AVAudioFormat
        do {
            audioFormat = try AVAudioStreamFormatFactory.makeInterleavedInt16(
                sampleRate: Double(format.sampleRate),
                channelLayout: format.channelLayout
            )
        } catch {
            throw AudioPipelineError.invalidPCMBuffer
        }
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: audioFormat,
            frameCapacity: frameCapacity
        ) else {
            throw AudioPipelineError.invalidPCMBuffer
        }

        let byteCount = decoded.interleavedSamples.count * MemoryLayout<Int16>.size
        buffer.frameLength = frameCapacity
        let audioBuffers = UnsafeMutableAudioBufferListPointer(buffer.mutableAudioBufferList)
        guard audioBuffers.count == 1,
              Int(audioBuffers[0].mNumberChannels) == format.channelCount,
              Int(audioBuffers[0].mDataByteSize) == byteCount,
              Int(buffer.audioBufferList.pointee.mBuffers.mDataByteSize)
                == byteCount,
              let destination = audioBuffers[0].mData else {
            throw AudioPipelineError.invalidPCMBuffer
        }
        decoded.interleavedSamples.withUnsafeBytes { samples in
            guard let source = samples.baseAddress else { return }
            destination.copyMemory(from: source, byteCount: byteCount)
        }
        return buffer
    }
}

struct AudioScheduleReceipt: Equatable, Sendable {
    var sequenceNumber: UInt16
    var rtpTimestamp: UInt32
    var frameCount: Int
}

enum AudioRouteInspector {
    static func currentRoute(
        engine: AVAudioEngine = AVAudioEngine(),
        preferredConfiguration: StreamAudioConfiguration? = nil
    ) -> AudioRouteSnapshot {
        let format = engine.outputNode.outputFormat(forBus: 0)
        return AudioRouteSnapshot(
            outputNames: ["System Output"],
            sampleRate: format.sampleRate > 0 ? format.sampleRate : (preferredConfiguration?.sampleRate ?? 48_000),
            outputChannelCount: Int(format.channelCount) > 0 ? Int(format.channelCount) : (preferredConfiguration?.channelCount ?? 2),
            preferredBufferDuration: preferredConfiguration?.latencyPolicy.preferredBufferDuration
        )
    }
}

actor AudioSessionPipeline {
    static let realtimeMaximumScheduledBuffers = 3

    private struct CapacityWaiter {
        let generation: UInt64
        let continuation: CheckedContinuation<Void, Error>
    }

    private let engineClient: AudioEngineClient
    private let maximumScheduledBuffers: Int
    private var generation: UInt64 = 0
    private var nextScheduleID: UInt64 = 0
    private var nextCapacityWaiterID: UInt64 = 0
    private var scheduledFramesByID: [UInt64: Int] = [:]
    private var capacityWaiters: [UInt64: CapacityWaiter] = [:]
    private var capacityWaiterOrder: [UInt64] = []
    private(set) var snapshot: AudioPipelineSnapshot

    init(
        engineClient: AudioEngineClient = AVAudioEngineClient(),
        maximumScheduledBuffers: Int = realtimeMaximumScheduledBuffers,
        now: Date = Date()
    ) {
        self.engineClient = engineClient
        self.maximumScheduledBuffers = min(max(maximumScheduledBuffers, 1), 64)
        self.snapshot = AudioPipelineSnapshot(
            stage: .idle,
            configuration: nil,
            route: nil,
            spatialRuntime: nil,
            lastStopReason: nil,
            lastErrorMessage: nil,
            updatedAt: now
        )
    }

    func configure(
        _ configuration: StreamAudioConfiguration,
        graphIntent: SpatialAudioGraphIntent,
        now: Date = Date()
    ) throws -> AudioPipelineSnapshot {
        if snapshot.stage == .configured || snapshot.stage == .running || snapshot.stage == .draining {
            invalidateScheduledBuffers()
            engineClient.stop(drain: false)
        }
        do {
            try configuration.validate()
            guard graphIntent.hasConsistentRevision else {
                throw AudioPipelineError.invalidGraphIntent
            }
            let spatialRuntime = try engineClient.configure(
                configuration,
                graphIntent: graphIntent
            )
            guard spatialRuntime.isConsistent(
                with: graphIntent,
                layout: configuration.channelLayout
            ) else {
                throw AudioPipelineError.invalidSpatialRuntimeSnapshot
            }
            snapshot.stage = .configured
            snapshot.configuration = configuration
            snapshot.route = engineClient.routeSnapshot()
            snapshot.spatialRuntime = spatialRuntime
            snapshot.mobileAudioSessionActive =
                engineClient.mobileAudioSessionActiveReadback()
            snapshot.lastStopReason = nil
            snapshot.lastErrorMessage = nil
            snapshot.updatedAt = now
            return snapshot
        } catch {
            invalidateScheduledBuffers()
            engineClient.stop(drain: false)
            snapshot.configuration = nil
            snapshot.route = nil
            snapshot.spatialRuntime = nil
            snapshot.mobileAudioSessionActive =
                engineClient.mobileAudioSessionActiveReadback()
            return fail(error, now: now)
        }
    }

    func start(now: Date = Date()) throws -> AudioPipelineSnapshot {
        guard snapshot.configuration != nil,
              snapshot.stage == .configured || snapshot.stage == .running else {
            return fail(AudioPipelineError.missingConfiguration, now: now)
        }

        do {
            try engineClient.start()
            snapshot.stage = .running
            snapshot.route = engineClient.routeSnapshot()
            snapshot.mobileAudioSessionActive =
                engineClient.mobileAudioSessionActiveReadback()
            snapshot.lastErrorMessage = nil
            snapshot.updatedAt = now
            return snapshot
        } catch {
            invalidateScheduledBuffers()
            engineClient.stop(drain: false)
            snapshot.configuration = nil
            snapshot.route = nil
            snapshot.spatialRuntime = nil
            snapshot.mobileAudioSessionActive =
                engineClient.mobileAudioSessionActiveReadback()
            return fail(error, now: now)
        }
    }

    func schedule(_ buffer: DecodedPCMBuffer) async throws -> AudioScheduleReceipt {
        guard snapshot.stage == .running,
              let configuration = snapshot.configuration else {
            throw AudioPipelineError.notRunning
        }
        guard buffer.format.sampleRate == Int(configuration.sampleRate),
              buffer.format.channelLayout == configuration.channelLayout,
              buffer.format.bitsPerChannel == 16,
              buffer.format.isSignedInteger,
              buffer.format.isInterleaved,
              (1...AVAudioPCMBufferFactory.maximumFramesPerBuffer).contains(buffer.frameCount),
              buffer.interleavedSamples.count == buffer.frameCount * configuration.channelCount else {
            throw AudioPipelineError.invalidPCMBuffer
        }
        let scheduledGeneration = generation
        try await waitForScheduleCapacity(generation: scheduledGeneration)
        try Task.checkCancellation()
        guard snapshot.stage == .running,
              generation == scheduledGeneration,
              snapshot.configuration == configuration else {
            throw AudioPipelineError.notRunning
        }

        let scheduleID = nextScheduleID
        nextScheduleID &+= 1
        scheduledFramesByID[scheduleID] = buffer.frameCount
        do {
            try engineClient.schedule(buffer) { [weak self] in
                Task {
                    await self?.didConsume(
                        scheduleID: scheduleID,
                        generation: scheduledGeneration
                    )
                }
            }
        } catch {
            scheduledFramesByID.removeValue(forKey: scheduleID)
            resumeNextCapacityWaiter()
            throw error
        }
        return AudioScheduleReceipt(
            sequenceNumber: buffer.sequenceNumber,
            rtpTimestamp: buffer.rtpTimestamp,
            frameCount: buffer.frameCount
        )
    }

    func scheduledBufferCount() -> Int {
        scheduledFramesByID.count
    }

    func scheduledFrameCount() -> Int {
        scheduledFramesByID.values.reduce(0, +)
    }

    func waitingScheduleCount() -> Int {
        capacityWaiters.count
    }

    func stop(reason: AudioStopReason, drain: Bool, now: Date = Date()) -> AudioPipelineSnapshot {
        snapshot.stage = drain ? .draining : .stopped
        snapshot.updatedAt = now
        invalidateScheduledBuffers()
        engineClient.stop(drain: drain)
        snapshot.stage = .stopped
        snapshot.lastStopReason = reason
        snapshot.route = engineClient.routeSnapshot()
        snapshot.spatialRuntime = nil
        snapshot.mobileAudioSessionActive =
            engineClient.mobileAudioSessionActiveReadback()
        snapshot.updatedAt = now
        return snapshot
    }

    private func didConsume(scheduleID: UInt64, generation: UInt64) {
        guard generation == self.generation else { return }
        guard scheduledFramesByID.removeValue(forKey: scheduleID) != nil else {
            return
        }
        resumeNextCapacityWaiter()
    }

    private func invalidateScheduledBuffers() {
        generation &+= 1
        scheduledFramesByID.removeAll(keepingCapacity: true)
        let continuations = capacityWaiterOrder.compactMap {
            capacityWaiters.removeValue(forKey: $0)?.continuation
        }
        capacityWaiterOrder.removeAll(keepingCapacity: true)
        for continuation in continuations {
            continuation.resume(throwing: AudioPipelineError.notRunning)
        }
    }

    private func waitForScheduleCapacity(generation: UInt64) async throws {
        while scheduledFramesByID.count >= maximumScheduledBuffers {
            try Task.checkCancellation()
            guard snapshot.stage == .running,
                  self.generation == generation else {
                throw AudioPipelineError.notRunning
            }
            let waiterID = nextCapacityWaiterID
            nextCapacityWaiterID &+= 1
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Void, Error>) in
                    if Task.isCancelled {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    capacityWaiters[waiterID] = CapacityWaiter(
                        generation: generation,
                        continuation: continuation
                    )
                    capacityWaiterOrder.append(waiterID)
                }
            } onCancel: {
                Task { await self.cancelCapacityWaiter(waiterID) }
            }
        }
    }

    private func cancelCapacityWaiter(_ waiterID: UInt64) {
        guard let waiter = capacityWaiters.removeValue(forKey: waiterID) else {
            return
        }
        capacityWaiterOrder.removeAll { $0 == waiterID }
        waiter.continuation.resume(throwing: CancellationError())
    }

    private func resumeNextCapacityWaiter() {
        while !capacityWaiterOrder.isEmpty {
            let waiterID = capacityWaiterOrder.removeFirst()
            guard let waiter = capacityWaiters.removeValue(forKey: waiterID) else {
                continue
            }
            if waiter.generation == generation {
                waiter.continuation.resume()
            } else {
                waiter.continuation.resume(
                    throwing: AudioPipelineError.notRunning
                )
            }
            return
        }
    }

    private func fail(_ error: Error, now: Date) -> AudioPipelineSnapshot {
        snapshot.stage = .failed
        snapshot.lastStopReason = .failure
        snapshot.lastErrorMessage = String(describing: error)
        snapshot.mobileAudioSessionActive =
            engineClient.mobileAudioSessionActiveReadback()
        snapshot.updatedAt = now
        return snapshot
    }
}

enum AudioPipelineError: Error, Equatable, Sendable {
    case missingConfiguration
    case invalidConfiguration
    case invalidGraphIntent
    case invalidSpatialRuntimeSnapshot
    case notRunning
    case invalidPCMBuffer
    case scheduleCapacityExceeded
}
