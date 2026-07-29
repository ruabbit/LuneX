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

    static var current: SpatialAudioPlatform {
        #if os(macOS)
        .macOS
        #elseif os(iOS)
        .iOS
        #elseif os(tvOS)
        .tvOS
        #elseif os(visionOS)
        .visionOS
        #else
        #error("Unsupported Apple platform")
        #endif
    }
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
