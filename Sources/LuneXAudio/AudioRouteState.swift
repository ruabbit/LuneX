import AVFAudio
import Foundation

struct AudioRouteState: Equatable {
    var spatialAudioAvailable = false
    var headTrackingAvailable = false
    var headTrackingEnabled = false
    var unavailableReason: String?
}

@MainActor
final class SpatialAudioController {
    private let environmentNode = AVAudioEnvironmentNode()

    func updateHeadTracking(enabled: Bool) -> AudioRouteState {
        #if os(macOS) || os(iOS) || os(tvOS)
        environmentNode.isListenerHeadTrackingEnabled = enabled
        return AudioRouteState(
            spatialAudioAvailable: true,
            headTrackingAvailable: true,
            headTrackingEnabled: environmentNode.isListenerHeadTrackingEnabled,
            unavailableReason: nil
        )
        #else
        return AudioRouteState(
            spatialAudioAvailable: true,
            headTrackingAvailable: false,
            headTrackingEnabled: false,
            unavailableReason: "Head tracking is unavailable on this platform SDK"
        )
        #endif
    }
}
