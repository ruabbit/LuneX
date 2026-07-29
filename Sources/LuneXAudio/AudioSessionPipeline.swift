import AVFAudio
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
}

struct AVAudioEngineGraphReadback: Equatable, Sendable {
    let mode: SpatialAudioGraphMode
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

final class AVAudioEngineClient: AudioEngineClient, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let environment = AVAudioEnvironmentNode()
    private var configuration: StreamAudioConfiguration?
    private var configuredGraphMode = SpatialAudioGraphMode.unconfigured

    init() {
        engine.attach(player)
        engine.attach(environment)
    }

    func configure(
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
        let session = AVAudioSession.sharedInstance()
        try session.setPreferredSampleRate(configuration.sampleRate)
        try session.setPreferredIOBufferDuration(configuration.latencyPolicy.preferredBufferDuration)
        try session.setActive(true)
        #endif

        let usesEnvironment = environmentGraphIsEligible(
            configuration: configuration,
            graphIntent: graphIntent
        )
        if usesEnvironment {
            engine.connect(environment, to: engine.mainMixerNode, format: nil)
            engine.connect(player, to: environment, format: format)
            let applicableAlgorithms = environment.applicableRenderingAlgorithms
                .compactMap {
                    AVAudio3DMixingRenderingAlgorithm(rawValue: $0.intValue)
                }
            guard applicableAlgorithms.contains(.auto) else {
                resetGraphConnections()
                throw AudioPipelineError.invalidConfiguration
            }
            player.sourceMode = .ambienceBed
            player.renderingAlgorithm = .auto
            configuredGraphMode = .environmentAmbienceBed
        } else {
            engine.connect(player, to: engine.mainMixerNode, format: format)
            configuredGraphMode = .nonspatialMixer
        }
        engine.prepare()
        self.configuration = configuration
        let graph = SpatialAudioGraphSnapshot(
            revision: graphIntent.revision,
            mode: configuredGraphMode,
            layoutSignature: configuration.channelLayout.signature,
            hasApplicableRenderingAlgorithm: usesEnvironment,
            platformStrategy: usesEnvironment ? .environmentListener : .none,
            listenerHeadTrackingCapable: false,
            listenerHeadTrackingReadback: false,
            visionExperienceReadback: nil
        )
        return SpatialAudioRuntimeResolver.resolve(
            intent: graphIntent,
            layout: configuration.channelLayout,
            graph: graph
        )
    }

    func start() throws {
        guard !engine.isRunning else { return }
        try engine.start()
        player.play()
    }

    func schedule(
        _ buffer: DecodedPCMBuffer,
        completion: @escaping @Sendable () -> Void
    ) throws {
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

    func stop(drain: Bool) {
        player.stop()
        engine.stop()
        engine.reset()
        resetGraphConnections()
        configuration = nil
        #if os(iOS) || os(tvOS) || os(visionOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif
    }

    func routeSnapshot() -> AudioRouteSnapshot {
        AudioRouteInspector.currentRoute(engine: engine, preferredConfiguration: configuration)
    }

    func graphReadback() -> AVAudioEngineGraphReadback {
        let playerDestinations = engine.outputConnectionPoints(
            for: player,
            outputBus: 0
        )
        let environmentDestinations = engine.outputConnectionPoints(
            for: environment,
            outputBus: 0
        )
        let usesEnvironment = configuredGraphMode == .environmentAmbienceBed
        let applicableAlgorithms = usesEnvironment
            ? environment.applicableRenderingAlgorithms.map(\.intValue)
            : []
        let inputFormat = player.outputFormat(forBus: 0)
        return AVAudioEngineGraphReadback(
            mode: configuredGraphMode,
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
            applicableRenderingAlgorithmRawValues: applicableAlgorithms,
            inputLayoutTagRawValue: inputFormat.channelLayout.map {
                UInt32($0.layoutTag)
            }
        )
    }

    private func resetGraphConnections() {
        engine.disconnectNodeOutput(player)
        engine.disconnectNodeOutput(environment)
        configuredGraphMode = .unconfigured
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
            return false
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
        #if os(iOS) || os(tvOS) || os(visionOS)
        let session = AVAudioSession.sharedInstance()
        let outputNames = session.currentRoute.outputs.map(\.portName)
        return AudioRouteSnapshot(
            outputNames: outputNames.isEmpty ? ["System Output"] : outputNames,
            sampleRate: session.sampleRate > 0 ? session.sampleRate : (preferredConfiguration?.sampleRate ?? 48_000),
            outputChannelCount: session.outputNumberOfChannels > 0 ? session.outputNumberOfChannels : (preferredConfiguration?.channelCount ?? 2),
            preferredBufferDuration: session.ioBufferDuration
        )
        #else
        let format = engine.outputNode.outputFormat(forBus: 0)
        return AudioRouteSnapshot(
            outputNames: ["System Output"],
            sampleRate: format.sampleRate > 0 ? format.sampleRate : (preferredConfiguration?.sampleRate ?? 48_000),
            outputChannelCount: Int(format.channelCount) > 0 ? Int(format.channelCount) : (preferredConfiguration?.channelCount ?? 2),
            preferredBufferDuration: preferredConfiguration?.latencyPolicy.preferredBufferDuration
        )
        #endif
    }
}

actor AudioSessionPipeline {
    private let engineClient: AudioEngineClient
    private let maximumScheduledBuffers: Int
    private var generation: UInt64 = 0
    private var nextScheduleID: UInt64 = 0
    private var scheduledFramesByID: [UInt64: Int] = [:]
    private(set) var snapshot: AudioPipelineSnapshot

    init(
        engineClient: AudioEngineClient = AVAudioEngineClient(),
        maximumScheduledBuffers: Int = 8,
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
            snapshot.lastErrorMessage = nil
            snapshot.updatedAt = now
            return snapshot
        } catch {
            invalidateScheduledBuffers()
            engineClient.stop(drain: false)
            snapshot.configuration = nil
            snapshot.route = nil
            snapshot.spatialRuntime = nil
            return fail(error, now: now)
        }
    }

    func schedule(_ buffer: DecodedPCMBuffer) throws -> AudioScheduleReceipt {
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
        guard scheduledFramesByID.count < maximumScheduledBuffers else {
            throw AudioPipelineError.scheduleCapacityExceeded
        }

        let scheduleID = nextScheduleID
        nextScheduleID &+= 1
        let scheduledGeneration = generation
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

    func stop(reason: AudioStopReason, drain: Bool, now: Date = Date()) -> AudioPipelineSnapshot {
        snapshot.stage = drain ? .draining : .stopped
        snapshot.updatedAt = now
        invalidateScheduledBuffers()
        engineClient.stop(drain: drain)
        snapshot.stage = .stopped
        snapshot.lastStopReason = reason
        snapshot.route = engineClient.routeSnapshot()
        snapshot.spatialRuntime = nil
        snapshot.updatedAt = now
        return snapshot
    }

    private func didConsume(scheduleID: UInt64, generation: UInt64) {
        guard generation == self.generation else { return }
        scheduledFramesByID.removeValue(forKey: scheduleID)
    }

    private func invalidateScheduledBuffers() {
        generation &+= 1
        scheduledFramesByID.removeAll(keepingCapacity: true)
    }

    private func fail(_ error: Error, now: Date) -> AudioPipelineSnapshot {
        snapshot.stage = .failed
        snapshot.lastStopReason = .failure
        snapshot.lastErrorMessage = String(describing: error)
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
