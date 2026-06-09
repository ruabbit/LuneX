import AVFAudio
import Foundation

struct StreamAudioConfiguration: Codable, Equatable, Hashable, Sendable {
    var sampleRate: Double
    var channelCount: Int
    var latencyPolicy: AudioLatencyPolicy
    var spatialAudioEnabled: Bool

    static let stereoLowLatency = StreamAudioConfiguration(
        sampleRate: 48_000,
        channelCount: 2,
        latencyPolicy: .lowLatency,
        spatialAudioEnabled: false
    )
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
    var lastStopReason: AudioStopReason?
    var lastErrorMessage: String?
    var updatedAt: Date
}

protocol AudioEngineClient: Sendable {
    func configure(_ configuration: StreamAudioConfiguration) throws
    func start() throws
    func stop(drain: Bool)
    func routeSnapshot() -> AudioRouteSnapshot
}

final class AVAudioEngineClient: AudioEngineClient, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var configuration: StreamAudioConfiguration?

    func configure(_ configuration: StreamAudioConfiguration) throws {
        self.configuration = configuration
        #if os(iOS) || os(tvOS) || os(visionOS)
        let session = AVAudioSession.sharedInstance()
        try session.setPreferredSampleRate(configuration.sampleRate)
        try session.setPreferredIOBufferDuration(configuration.latencyPolicy.preferredBufferDuration)
        try session.setActive(true)
        #endif
        engine.prepare()
    }

    func start() throws {
        guard !engine.isRunning else { return }
        try engine.start()
    }

    func stop(drain: Bool) {
        if drain {
            engine.pause()
        }
        engine.stop()
        engine.reset()
        #if os(iOS) || os(tvOS) || os(visionOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif
    }

    func routeSnapshot() -> AudioRouteSnapshot {
        AudioRouteInspector.currentRoute(engine: engine, preferredConfiguration: configuration)
    }
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
    private(set) var snapshot: AudioPipelineSnapshot

    init(engineClient: AudioEngineClient, now: Date = Date()) {
        self.engineClient = engineClient
        self.snapshot = AudioPipelineSnapshot(
            stage: .idle,
            configuration: nil,
            route: nil,
            lastStopReason: nil,
            lastErrorMessage: nil,
            updatedAt: now
        )
    }

    func configure(_ configuration: StreamAudioConfiguration, now: Date = Date()) throws -> AudioPipelineSnapshot {
        do {
            try engineClient.configure(configuration)
            snapshot.stage = .configured
            snapshot.configuration = configuration
            snapshot.route = engineClient.routeSnapshot()
            snapshot.lastStopReason = nil
            snapshot.lastErrorMessage = nil
            snapshot.updatedAt = now
            return snapshot
        } catch {
            return fail(error, now: now)
        }
    }

    func start(now: Date = Date()) throws -> AudioPipelineSnapshot {
        guard snapshot.configuration != nil else {
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
            return fail(error, now: now)
        }
    }

    func stop(reason: AudioStopReason, drain: Bool, now: Date = Date()) -> AudioPipelineSnapshot {
        snapshot.stage = drain ? .draining : .stopped
        snapshot.updatedAt = now
        engineClient.stop(drain: drain)
        snapshot.stage = .stopped
        snapshot.lastStopReason = reason
        snapshot.route = engineClient.routeSnapshot()
        snapshot.updatedAt = now
        return snapshot
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
}
