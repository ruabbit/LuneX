import Foundation

struct SpatialAudioSemanticRevision: RawRepresentable, Codable, Equatable, Hashable,
    Comparable, Sendable
{
    let rawValue: UInt64

    static func < (
        lhs: SpatialAudioSemanticRevision,
        rhs: SpatialAudioSemanticRevision
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum SpatialAudioGraphMode: String, Codable, Hashable, Sendable {
    case unconfigured
    case nonspatialMixer = "nonspatial-mixer"
    case environmentAmbienceBed = "environment-ambience-bed"
}

enum SpatialAudioPlatformStrategy: String, Codable, Hashable, Sendable {
    case none
    case environmentListener = "environment-listener"
    case visionOutputExperience = "vision-output-experience"
}

enum SpatialAudioRouteSupport: String, Codable, Hashable, Sendable {
    case supported
    case unsupported
    case unknown
}

enum SpatialAudioEntitlementState: String, Codable, Hashable, Sendable {
    case notRequired = "not-required"
    case granted
    case missing
    case unreadable
}

enum VisionSpatialExperienceReadback: String, Codable, Hashable, Sendable {
    case fixed
    case headTracked = "head-tracked"
}

struct SpatialAudioGraphSnapshot: Codable, Equatable, Hashable, Sendable {
    let revision: SpatialAudioSemanticRevision
    let mode: SpatialAudioGraphMode
    let layoutSignature: StreamAudioChannelLayoutSignature?
    let hasApplicableRenderingAlgorithm: Bool
    let platformStrategy: SpatialAudioPlatformStrategy
    let listenerHeadTrackingCapable: Bool
    let listenerHeadTrackingReadback: Bool
    let visionExperienceReadback: VisionSpatialExperienceReadback?
}

struct SpatialAudioRouteCapabilitySnapshot: Codable, Equatable, Hashable, Sendable {
    let revision: SpatialAudioSemanticRevision
    let outputAvailable: Bool
    let systemSpatialSupport: SpatialAudioRouteSupport
    let currentOutputChannelCount: Int
    let maximumOutputChannelCount: Int
}

struct SpatialAudioGraphIntent: Codable, Equatable, Hashable, Sendable {
    let revision: SpatialAudioSemanticRevision
    let platform: SpatialAudioPlatform
    let route: SpatialAudioRouteCapabilitySnapshot
    let entitlement: SpatialAudioEntitlementState
    let userEnablesSpatialAudio: Bool
    let userEnablesHeadTracking: Bool

    static func disabled(
        platform: SpatialAudioPlatform = .current,
        channelCount: Int,
        revision: SpatialAudioSemanticRevision = .init(rawValue: 0)
    ) -> SpatialAudioGraphIntent {
        SpatialAudioGraphIntent(
            revision: revision,
            platform: platform,
            route: SpatialAudioRouteCapabilitySnapshot(
                revision: revision,
                outputAvailable: true,
                systemSpatialSupport: .unknown,
                currentOutputChannelCount: channelCount,
                maximumOutputChannelCount: channelCount
            ),
            entitlement: .notRequired,
            userEnablesSpatialAudio: false,
            userEnablesHeadTracking: false
        )
    }

    var hasConsistentRevision: Bool {
        route.revision == revision
    }
}

enum SpatialAudioPresentationMode: String, Codable, CaseIterable, Hashable, Sendable {
    case inactive
    case nonspatial
    case fixedSpatial = "fixed-spatial"
    case headTracked = "head-tracked"
}

enum SpatialAudioFallbackReason: String, Codable, CaseIterable, Hashable, Sendable {
    case staleRevision = "stale-revision"
    case outputUnavailable = "output-unavailable"
    case invalidRouteSnapshot = "invalid-route-snapshot"
    case layoutMismatch = "layout-mismatch"
    case userDisabled = "user-disabled"
    case unsupportedLayout = "unsupported-layout"
    case graphUnavailable = "graph-unavailable"
    case renderingAlgorithmUnavailable = "rendering-algorithm-unavailable"
    case routeUnsupported = "route-unsupported"
    case missingEntitlement = "missing-entitlement"
    case unreadableEntitlement = "unreadable-entitlement"
    case incompatiblePlatformStrategy = "incompatible-platform-strategy"
    case headTrackingNotApplied = "head-tracking-not-applied"
    case visionExperienceNotApplied = "vision-experience-not-applied"
}

struct SpatialAudioResolutionInput: Equatable, Hashable, Sendable {
    let revision: SpatialAudioSemanticRevision
    let platform: SpatialAudioPlatform
    let layout: StreamAudioChannelLayout
    let graph: SpatialAudioGraphSnapshot
    let route: SpatialAudioRouteCapabilitySnapshot
    let entitlement: SpatialAudioEntitlementState
    let userEnablesSpatialAudio: Bool
    let userEnablesHeadTracking: Bool
}

struct SpatialAudioRuntimeSnapshot: Codable, Equatable, Hashable, Sendable {
    let revision: SpatialAudioSemanticRevision
    let layoutSignature: StreamAudioChannelLayoutSignature
    let graphMode: SpatialAudioGraphMode
    let platformStrategy: SpatialAudioPlatformStrategy
    let routeSupport: SpatialAudioRouteSupport
    let presentationMode: SpatialAudioPresentationMode
    let fallbackReason: SpatialAudioFallbackReason?

    var spatialAudioActive: Bool {
        presentationMode == .fixedSpatial || presentationMode == .headTracked
    }

    var headTrackingActive: Bool {
        presentationMode == .headTracked
    }

    var diagnosticCode: String {
        if let fallbackReason {
            return "spatial_audio_\(presentationMode.rawValue)_\(fallbackReason.rawValue)"
        }
        return "spatial_audio_\(presentationMode.rawValue)"
    }

    func isConsistent(
        with intent: SpatialAudioGraphIntent,
        layout: StreamAudioChannelLayout
    ) -> Bool {
        guard revision == intent.revision,
              layoutSignature == layout.signature,
              routeSupport == intent.route.systemSpatialSupport,
              graphMode != .unconfigured else {
            return false
        }
        guard spatialAudioActive else {
            return platformStrategy == .none
                || platformStrategy == .environmentListener
                || platformStrategy == .visionOutputExperience
        }
        guard intent.userEnablesSpatialAudio,
              layout.spatialEligibility == .ambienceBed,
              graphMode == .environmentAmbienceBed else {
            return false
        }
        if headTrackingActive && !intent.userEnablesHeadTracking {
            return false
        }
        switch intent.platform {
        case .macOS, .iOS, .tvOS:
            return platformStrategy == .environmentListener
        case .visionOS:
            return platformStrategy == .visionOutputExperience
        }
    }
}

enum SpatialAudioRuntimeHistoryError: Error, Equatable, Hashable, Sendable {
    case invalidCapacity(Int)
    case staleRevision(
        latest: SpatialAudioSemanticRevision,
        incoming: SpatialAudioSemanticRevision
    )
    case conflictingRevision(SpatialAudioSemanticRevision)
}

struct SpatialAudioRuntimeHistory: Equatable, Sendable {
    static let defaultCapacity = 32
    static let maximumCapacity = 64

    let capacity: Int
    private(set) var snapshots: [SpatialAudioRuntimeSnapshot] = []

    init(capacity: Int = defaultCapacity) throws {
        guard (1...Self.maximumCapacity).contains(capacity) else {
            throw SpatialAudioRuntimeHistoryError.invalidCapacity(capacity)
        }
        self.capacity = capacity
    }

    @discardableResult
    mutating func append(_ snapshot: SpatialAudioRuntimeSnapshot) throws -> Bool {
        if let latest = snapshots.last {
            if snapshot.revision == latest.revision {
                guard snapshot == latest else {
                    throw SpatialAudioRuntimeHistoryError.conflictingRevision(
                        snapshot.revision
                    )
                }
                return false
            }
            guard snapshot.revision > latest.revision else {
                throw SpatialAudioRuntimeHistoryError.staleRevision(
                    latest: latest.revision,
                    incoming: snapshot.revision
                )
            }
        }

        snapshots.append(snapshot)
        if snapshots.count > capacity {
            snapshots.removeFirst(snapshots.count - capacity)
        }
        return true
    }
}

enum SpatialAudioRuntimeResolver {
    static func resolve(
        intent: SpatialAudioGraphIntent,
        layout: StreamAudioChannelLayout,
        graph: SpatialAudioGraphSnapshot
    ) -> SpatialAudioRuntimeSnapshot {
        resolve(SpatialAudioResolutionInput(
            revision: intent.revision,
            platform: intent.platform,
            layout: layout,
            graph: graph,
            route: intent.route,
            entitlement: intent.entitlement,
            userEnablesSpatialAudio: intent.userEnablesSpatialAudio,
            userEnablesHeadTracking: intent.userEnablesHeadTracking
        ))
    }

    static func resolve(
        _ input: SpatialAudioResolutionInput
    ) -> SpatialAudioRuntimeSnapshot {
        func snapshot(
            mode: SpatialAudioPresentationMode,
            fallback: SpatialAudioFallbackReason?
        ) -> SpatialAudioRuntimeSnapshot {
            SpatialAudioRuntimeSnapshot(
                revision: input.revision,
                layoutSignature: input.layout.signature,
                graphMode: input.graph.mode,
                platformStrategy: input.graph.platformStrategy,
                routeSupport: input.route.systemSpatialSupport,
                presentationMode: mode,
                fallbackReason: fallback
            )
        }

        guard input.graph.revision == input.revision,
              input.route.revision == input.revision else {
            return snapshot(mode: .inactive, fallback: .staleRevision)
        }
        guard input.route.outputAvailable else {
            return snapshot(mode: .inactive, fallback: .outputUnavailable)
        }
        guard input.route.currentOutputChannelCount > 0,
              input.route.maximumOutputChannelCount > 0,
              input.route.currentOutputChannelCount
                <= input.route.maximumOutputChannelCount else {
            return snapshot(mode: .inactive, fallback: .invalidRouteSnapshot)
        }
        guard input.graph.layoutSignature == input.layout.signature else {
            return snapshot(mode: .nonspatial, fallback: .layoutMismatch)
        }
        guard input.userEnablesSpatialAudio else {
            return snapshot(mode: .nonspatial, fallback: .userDisabled)
        }
        guard input.layout.spatialEligibility == .ambienceBed else {
            return snapshot(mode: .nonspatial, fallback: .unsupportedLayout)
        }
        guard input.graph.mode == .environmentAmbienceBed else {
            return snapshot(mode: .nonspatial, fallback: .graphUnavailable)
        }
        guard input.graph.hasApplicableRenderingAlgorithm else {
            return snapshot(
                mode: .nonspatial,
                fallback: .renderingAlgorithmUnavailable
            )
        }
        guard routeAllowsSpatialAudio(input) else {
            return snapshot(mode: .nonspatial, fallback: .routeUnsupported)
        }
        guard platformStrategyIsCompatible(input) else {
            return snapshot(
                mode: .nonspatial,
                fallback: .incompatiblePlatformStrategy
            )
        }
        guard input.userEnablesHeadTracking else {
            if input.platform == .visionOS,
               input.graph.visionExperienceReadback != .fixed {
                return snapshot(
                    mode: .nonspatial,
                    fallback: .visionExperienceNotApplied
                )
            }
            return snapshot(mode: .fixedSpatial, fallback: nil)
        }

        switch input.platform {
        case .visionOS:
            guard input.graph.visionExperienceReadback == .headTracked else {
                return snapshot(
                    mode: .fixedSpatial,
                    fallback: .visionExperienceNotApplied
                )
            }
            return snapshot(mode: .headTracked, fallback: nil)

        case .macOS, .iOS, .tvOS:
            switch input.entitlement {
            case .granted:
                break
            case .missing, .notRequired:
                return snapshot(
                    mode: .fixedSpatial,
                    fallback: .missingEntitlement
                )
            case .unreadable:
                return snapshot(
                    mode: .fixedSpatial,
                    fallback: .unreadableEntitlement
                )
            }
            guard input.graph.listenerHeadTrackingCapable,
                  input.graph.listenerHeadTrackingReadback else {
                return snapshot(
                    mode: .fixedSpatial,
                    fallback: .headTrackingNotApplied
                )
            }
            return snapshot(mode: .headTracked, fallback: nil)
        }
    }

    private static func routeAllowsSpatialAudio(
        _ input: SpatialAudioResolutionInput
    ) -> Bool {
        switch input.platform {
        case .macOS:
            input.route.systemSpatialSupport != .unsupported
        case .iOS, .tvOS, .visionOS:
            input.route.systemSpatialSupport == .supported
        }
    }

    private static func platformStrategyIsCompatible(
        _ input: SpatialAudioResolutionInput
    ) -> Bool {
        switch input.platform {
        case .macOS, .iOS, .tvOS:
            input.graph.platformStrategy == .environmentListener
        case .visionOS:
            input.graph.platformStrategy == .visionOutputExperience
        }
    }
}
