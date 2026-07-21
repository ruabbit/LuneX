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

    func validate() throws {
        guard sampleRate == 48_000,
              (1...8).contains(channelCount) else {
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
    var lastStopReason: AudioStopReason?
    var lastErrorMessage: String?
    var updatedAt: Date
}

protocol AudioEngineClient: Sendable {
    func configure(_ configuration: StreamAudioConfiguration) throws
    func start() throws
    func schedule(
        _ buffer: DecodedPCMBuffer,
        completion: @escaping @Sendable () -> Void
    ) throws
    func stop(drain: Bool)
    func routeSnapshot() -> AudioRouteSnapshot
}

final class AVAudioEngineClient: AudioEngineClient, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var configuration: StreamAudioConfiguration?

    init() {
        engine.attach(player)
    }

    func configure(_ configuration: StreamAudioConfiguration) throws {
        try configuration.validate()
        guard let format = AVAudioFormat(
                  commonFormat: .pcmFormatInt16,
                  sampleRate: configuration.sampleRate,
                  channels: AVAudioChannelCount(configuration.channelCount),
                  interleaved: true
              ) else {
            throw AudioPipelineError.invalidConfiguration
        }

        player.stop()
        if engine.isRunning {
            engine.stop()
        }
        engine.disconnectNodeOutput(player)
        self.configuration = nil
        #if os(iOS) || os(tvOS) || os(visionOS)
        let session = AVAudioSession.sharedInstance()
        try session.setPreferredSampleRate(configuration.sampleRate)
        try session.setPreferredIOBufferDuration(configuration.latencyPolicy.preferredBufferDuration)
        try session.setActive(true)
        #endif
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.prepare()
        self.configuration = configuration
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
        configuration = nil
        #if os(iOS) || os(tvOS) || os(visionOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif
    }

    func routeSnapshot() -> AudioRouteSnapshot {
        AudioRouteInspector.currentRoute(engine: engine, preferredConfiguration: configuration)
    }
}

enum AVAudioPCMBufferFactory {
    static let maximumFramesPerBuffer = 5_760

    static func makeBuffer(from decoded: DecodedPCMBuffer) throws -> AVAudioPCMBuffer {
        let format = decoded.format
        guard format.sampleRate == 48_000,
              (1...8).contains(format.channelCount),
              format.bitsPerChannel == 16,
              format.isSignedInteger,
              format.isInterleaved,
              (1...maximumFramesPerBuffer).contains(decoded.frameCount),
              decoded.interleavedSamples.count == decoded.frameCount * format.channelCount,
              let frameCapacity = AVAudioFrameCount(exactly: decoded.frameCount),
              let audioFormat = AVAudioFormat(
                  commonFormat: .pcmFormatInt16,
                  sampleRate: Double(format.sampleRate),
                  channels: AVAudioChannelCount(format.channelCount),
                  interleaved: true
              ),
              let buffer = AVAudioPCMBuffer(
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
              Int(audioBuffers[0].mDataByteSize) >= byteCount,
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
            lastStopReason: nil,
            lastErrorMessage: nil,
            updatedAt: now
        )
    }

    func configure(_ configuration: StreamAudioConfiguration, now: Date = Date()) throws -> AudioPipelineSnapshot {
        if snapshot.stage == .configured || snapshot.stage == .running || snapshot.stage == .draining {
            invalidateScheduledBuffers()
            engineClient.stop(drain: false)
        }
        do {
            try configuration.validate()
            try engineClient.configure(configuration)
            snapshot.stage = .configured
            snapshot.configuration = configuration
            snapshot.route = engineClient.routeSnapshot()
            snapshot.lastStopReason = nil
            snapshot.lastErrorMessage = nil
            snapshot.updatedAt = now
            return snapshot
        } catch {
            invalidateScheduledBuffers()
            engineClient.stop(drain: false)
            snapshot.configuration = nil
            snapshot.route = nil
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
            return fail(error, now: now)
        }
    }

    func schedule(_ buffer: DecodedPCMBuffer) throws -> AudioScheduleReceipt {
        guard snapshot.stage == .running,
              let configuration = snapshot.configuration else {
            throw AudioPipelineError.notRunning
        }
        guard buffer.format.sampleRate == Int(configuration.sampleRate),
              buffer.format.channelCount == configuration.channelCount,
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
    case notRunning
    case invalidPCMBuffer
    case scheduleCapacityExceeded
}
