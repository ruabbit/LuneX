import AVFAudio
import Foundation

struct AudioRouteState: Codable, Equatable, Hashable, Sendable {
    var spatialAudioAvailable = false
    var headTrackingAvailable = false
    var headTrackingEnabled = false
    var unavailableReason: String?
}

enum SpatialAudioPlatform: String, Codable, Hashable, Sendable {
    case macOS
    case iOS
    case tvOS
    case visionOS
}

struct SpatialAudioCapabilityContext: Codable, Equatable, Hashable, Sendable {
    var platform: SpatialAudioPlatform
    var routeSupportsSpatialAudio: Bool
    var hasHeadPoseEntitlement: Bool
    var channelCount: Int
    var userEnabledHeadTracking: Bool

    var sdkSupportsHeadTracking: Bool {
        switch platform {
        case .macOS, .iOS, .tvOS:
            true
        case .visionOS:
            false
        }
    }
}

enum SpatialAudioAvailabilityResolver {
    static let headPoseEntitlement = "com.apple.developer.coremotion.head-pose"

    static func resolve(_ context: SpatialAudioCapabilityContext) -> AudioRouteState {
        guard context.channelCount >= 2 else {
            return AudioRouteState(
                spatialAudioAvailable: false,
                headTrackingAvailable: false,
                headTrackingEnabled: false,
                unavailableReason: "Spatial audio requires a stereo or multichannel stream"
            )
        }

        guard context.routeSupportsSpatialAudio else {
            return AudioRouteState(
                spatialAudioAvailable: false,
                headTrackingAvailable: false,
                headTrackingEnabled: false,
                unavailableReason: "Current audio route does not report spatial audio support"
            )
        }

        guard context.sdkSupportsHeadTracking else {
            return AudioRouteState(
                spatialAudioAvailable: true,
                headTrackingAvailable: false,
                headTrackingEnabled: false,
                unavailableReason: "Head tracking is unavailable on this platform SDK"
            )
        }

        guard context.hasHeadPoseEntitlement else {
            return AudioRouteState(
                spatialAudioAvailable: true,
                headTrackingAvailable: false,
                headTrackingEnabled: false,
                unavailableReason: "Missing \(headPoseEntitlement) entitlement"
            )
        }

        return AudioRouteState(
            spatialAudioAvailable: true,
            headTrackingAvailable: true,
            headTrackingEnabled: context.userEnabledHeadTracking,
            unavailableReason: nil
        )
    }
}

@MainActor
final class SpatialAudioController {
    private let environmentNode = AVAudioEnvironmentNode()

    func updateHeadTracking(context: SpatialAudioCapabilityContext) -> AudioRouteState {
        let state = SpatialAudioAvailabilityResolver.resolve(context)
        return updateHeadTracking(enabled: state.headTrackingEnabled && state.headTrackingAvailable, state: state)
    }

    func updateHeadTracking(enabled: Bool) -> AudioRouteState {
        updateHeadTracking(enabled: enabled, state: nil)
    }

    private func updateHeadTracking(enabled: Bool, state: AudioRouteState?) -> AudioRouteState {
        #if os(macOS) || os(iOS) || os(tvOS)
        environmentNode.isListenerHeadTrackingEnabled = enabled
        return state.map {
            AudioRouteState(
                spatialAudioAvailable: $0.spatialAudioAvailable,
                headTrackingAvailable: $0.headTrackingAvailable,
                headTrackingEnabled: environmentNode.isListenerHeadTrackingEnabled && $0.headTrackingAvailable,
                unavailableReason: $0.unavailableReason
            )
        } ?? AudioRouteState(
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
