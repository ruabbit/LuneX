import AVFAudio
import Foundation

struct MacAudioOutputFormatSnapshot: Equatable, Sendable {
    let sampleRate: Double
    let channelCount: Int

    init(sampleRate: Double, channelCount: Int) {
        self.sampleRate = sampleRate
        self.channelCount = channelCount
    }

    init(format: AVAudioFormat) {
        sampleRate = format.sampleRate
        channelCount = Int(format.channelCount)
    }
}

enum MacAudioOutputCapabilityResolver {
    static let maximumObservedChannelCount = 64

    static func resolve(
        revision: SpatialAudioSemanticRevision,
        output: MacAudioOutputFormatSnapshot,
        graph: AVAudioEngineGraphReadback
    ) -> SpatialAudioRouteCapabilitySnapshot {
        guard output.sampleRate.isFinite,
              output.sampleRate > 0,
              (1...maximumObservedChannelCount).contains(
                  output.channelCount
              ) else {
            return SpatialAudioRouteCapabilitySnapshot(
                revision: revision,
                outputAvailable: false,
                systemSpatialSupport: .unknown,
                currentOutputChannelCount: 0,
                maximumOutputChannelCount: 0
            )
        }

        let spatialSupport: SpatialAudioRouteSupport
        if graph.mode == .environmentAmbienceBed,
           graph.environmentConnectedToMainMixer,
           graph.applicableRenderingAlgorithmRawValues.contains(
               AVAudio3DMixingRenderingAlgorithm.auto.rawValue
           ) {
            spatialSupport = .supported
        } else if graph.fallbackReason != nil {
            spatialSupport = .unsupported
        } else {
            spatialSupport = .unknown
        }

        return SpatialAudioRouteCapabilitySnapshot(
            revision: revision,
            outputAvailable: true,
            systemSpatialSupport: spatialSupport,
            currentOutputChannelCount: output.channelCount,
            maximumOutputChannelCount: output.channelCount
        )
    }
}
