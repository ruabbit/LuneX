import Foundation

#if os(tvOS)
import CoreGraphics
import QuartzCore
import UIKit
#endif

enum TVVisionPlatform: String, Codable, CaseIterable, Hashable, Sendable {
    case tvOS
    case visionOS
}

enum TVVisionGenerationDomain: String, Codable, CaseIterable, Hashable, Sendable {
    case presentation
    case surface
    case input
    case controller
    case display
    case audioRoute = "audio-route"
}

enum TVVisionPlatformContractError: Error, Equatable, Sendable {
    case invalidGeneration(TVVisionGenerationDomain)
    case generationExhausted(TVVisionGenerationDomain)
    case generationDomainMismatch(
        expected: TVVisionGenerationDomain,
        actual: TVVisionGenerationDomain
    )
    case invalidSemanticRevision
    case semanticRevisionExhausted
    case invalidMediaGeneration
    case invalidGeometry(TVVisionGeometryValidationError)
    case unsupportedInputCapability(
        platform: TVVisionPlatform,
        capability: TVVisionInputCapability
    )
    case invalidControllerSlot(Int)
    case controllerInputGenerationMismatch
    case invalidDisplaySnapshot
    case invalidAudioRouteSnapshot
    case incompatibleAudioStrategy
    case platformMismatch
    case revisionMismatch
    case inputGenerationMismatch
    case duplicateControllerSlot(UInt8)
    case duplicateControllerLease(UInt64)
    case attachedSurfaceRequired
}

struct TVVisionGeneration: Codable, Comparable, Hashable, Sendable {
    let domain: TVVisionGenerationDomain
    let rawValue: UInt64

    init(
        domain: TVVisionGenerationDomain,
        rawValue: UInt64
    ) throws {
        guard rawValue > 0 else {
            throw TVVisionPlatformContractError.invalidGeneration(domain)
        }
        self.domain = domain
        self.rawValue = rawValue
    }

    func advanced() throws -> TVVisionGeneration {
        let next = rawValue.addingReportingOverflow(1)
        guard !next.overflow else {
            throw TVVisionPlatformContractError.generationExhausted(domain)
        }
        return try TVVisionGeneration(
            domain: domain,
            rawValue: next.partialValue
        )
    }

    func require(_ expected: TVVisionGenerationDomain) throws {
        guard domain == expected else {
            throw TVVisionPlatformContractError.generationDomainMismatch(
                expected: expected,
                actual: domain
            )
        }
    }

    static func < (lhs: TVVisionGeneration, rhs: TVVisionGeneration) -> Bool {
        if lhs.domain != rhs.domain {
            return lhs.domain.rawValue < rhs.domain.rawValue
        }
        return lhs.rawValue < rhs.rawValue
    }

    private enum CodingKeys: String, CodingKey {
        case domain
        case rawValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            domain: container.decode(
                TVVisionGenerationDomain.self,
                forKey: .domain
            ),
            rawValue: container.decode(UInt64.self, forKey: .rawValue)
        )
    }
}

struct TVVisionSemanticRevision: Codable, Comparable, Hashable, Sendable {
    let rawValue: UInt64

    init(rawValue: UInt64) throws {
        guard rawValue > 0 else {
            throw TVVisionPlatformContractError.invalidSemanticRevision
        }
        self.rawValue = rawValue
    }

    func advanced() throws -> TVVisionSemanticRevision {
        let next = rawValue.addingReportingOverflow(1)
        guard !next.overflow else {
            throw TVVisionPlatformContractError.semanticRevisionExhausted
        }
        return try TVVisionSemanticRevision(rawValue: next.partialValue)
    }

    static func < (
        lhs: TVVisionSemanticRevision,
        rhs: TVVisionSemanticRevision
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(rawValue: container.decode(UInt64.self))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

struct TVVisionPresentationOwnership: Equatable, Hashable, Sendable {
    let platform: TVVisionPlatform
    let sessionID: UUID
    let mediaGeneration: UInt64
    let presentationGeneration: TVVisionGeneration
    let inputGeneration: TVVisionGeneration

    init(
        platform: TVVisionPlatform,
        sessionID: UUID,
        mediaGeneration: UInt64,
        presentationGeneration: TVVisionGeneration,
        inputGeneration: TVVisionGeneration
    ) throws {
        guard mediaGeneration > 0 else {
            throw TVVisionPlatformContractError.invalidMediaGeneration
        }
        try presentationGeneration.require(.presentation)
        try inputGeneration.require(.input)
        self.platform = platform
        self.sessionID = sessionID
        self.mediaGeneration = mediaGeneration
        self.presentationGeneration = presentationGeneration
        self.inputGeneration = inputGeneration
    }
}

struct TVVisionRect: Codable, Equatable, Hashable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct TVVisionEdgeInsets: Codable, Equatable, Hashable, Sendable {
    static let zero = TVVisionEdgeInsets(
        top: 0,
        leading: 0,
        bottom: 0,
        trailing: 0
    )

    let top: Double
    let leading: Double
    let bottom: Double
    let trailing: Double
}

enum TVVisionGeometryValidationError:
    String,
    Codable,
    Error,
    Equatable,
    Hashable,
    Sendable
{
    case invalidViewBounds = "invalid-view-bounds"
    case invalidWindowBounds = "invalid-window-bounds"
    case invalidSafeAreaInsets = "invalid-safe-area-insets"
    case invalidScale = "invalid-scale"
    case invalidDrawableSize = "invalid-drawable-size"
    case drawableSizeMismatch = "drawable-size-mismatch"
}

struct TVVisionSurfaceGeometry: Equatable, Hashable, Sendable {
    static let maximumPointCoordinate = 1_000_000.0
    static let maximumPointDimension = 131_072.0
    static let maximumScale = 16.0
    static let maximumDrawableDimension = 1_048_576

    let platform: TVVisionPlatform
    let surfaceGeneration: TVVisionGeneration
    let viewBounds: TVVisionRect
    let windowBounds: TVVisionRect
    let safeAreaInsets: TVVisionEdgeInsets
    let scale: Double
    let drawableSize: PixelSize

    init(
        platform: TVVisionPlatform,
        surfaceGeneration: TVVisionGeneration,
        viewBounds: TVVisionRect,
        windowBounds: TVVisionRect,
        safeAreaInsets: TVVisionEdgeInsets,
        scale: Double
    ) throws {
        guard Self.isValid(rect: viewBounds) else {
            throw TVVisionPlatformContractError.invalidGeometry(
                .invalidViewBounds
            )
        }
        guard Self.isValid(rect: windowBounds) else {
            throw TVVisionPlatformContractError.invalidGeometry(
                .invalidWindowBounds
            )
        }
        guard Self.isValid(insets: safeAreaInsets, inside: viewBounds) else {
            throw TVVisionPlatformContractError.invalidGeometry(
                .invalidSafeAreaInsets
            )
        }
        guard scale.isFinite, scale > 0, scale <= Self.maximumScale else {
            throw TVVisionPlatformContractError.invalidGeometry(.invalidScale)
        }

        let drawableWidth = viewBounds.width * scale
        let drawableHeight = viewBounds.height * scale
        guard drawableWidth.isFinite,
              drawableHeight.isFinite,
              drawableWidth > 0,
              drawableHeight > 0,
              drawableWidth <= Double(Self.maximumDrawableDimension),
              drawableHeight <= Double(Self.maximumDrawableDimension) else {
            throw TVVisionPlatformContractError.invalidGeometry(
                .invalidDrawableSize
            )
        }
        let roundedWidth = drawableWidth.rounded(.toNearestOrAwayFromZero)
        let roundedHeight = drawableHeight.rounded(.toNearestOrAwayFromZero)
        guard roundedWidth > 0,
              roundedHeight > 0,
              roundedWidth <= Double(Int.max),
              roundedHeight <= Double(Int.max) else {
            throw TVVisionPlatformContractError.invalidGeometry(
                .invalidDrawableSize
            )
        }
        try self.init(
            platform: platform,
            surfaceGeneration: surfaceGeneration,
            viewBounds: viewBounds,
            windowBounds: windowBounds,
            safeAreaInsets: safeAreaInsets,
            scale: scale,
            drawableSize: PixelSize(
                width: Int(roundedWidth),
                height: Int(roundedHeight)
            )
        )
    }

    init(
        platform: TVVisionPlatform,
        surfaceGeneration: TVVisionGeneration,
        viewBounds: TVVisionRect,
        windowBounds: TVVisionRect,
        safeAreaInsets: TVVisionEdgeInsets,
        scale: Double,
        drawableSize: PixelSize
    ) throws {
        try surfaceGeneration.require(.surface)
        guard Self.isValid(rect: viewBounds) else {
            throw TVVisionPlatformContractError.invalidGeometry(
                .invalidViewBounds
            )
        }
        guard Self.isValid(rect: windowBounds) else {
            throw TVVisionPlatformContractError.invalidGeometry(
                .invalidWindowBounds
            )
        }
        guard Self.isValid(insets: safeAreaInsets, inside: viewBounds) else {
            throw TVVisionPlatformContractError.invalidGeometry(
                .invalidSafeAreaInsets
            )
        }
        guard scale.isFinite, scale > 0, scale <= Self.maximumScale else {
            throw TVVisionPlatformContractError.invalidGeometry(.invalidScale)
        }
        guard drawableSize.width > 0,
              drawableSize.height > 0,
              drawableSize.width <= Self.maximumDrawableDimension,
              drawableSize.height <= Self.maximumDrawableDimension else {
            throw TVVisionPlatformContractError.invalidGeometry(
                .invalidDrawableSize
            )
        }

        let expectedWidth = viewBounds.width * scale
        let expectedHeight = viewBounds.height * scale
        guard expectedWidth.isFinite,
              expectedHeight.isFinite,
              expectedWidth <= Double(Self.maximumDrawableDimension),
              expectedHeight <= Double(Self.maximumDrawableDimension),
              Int(expectedWidth.rounded(.toNearestOrAwayFromZero))
                == drawableSize.width,
              Int(expectedHeight.rounded(.toNearestOrAwayFromZero))
                == drawableSize.height else {
            throw TVVisionPlatformContractError.invalidGeometry(
                .drawableSizeMismatch
            )
        }

        self.platform = platform
        self.surfaceGeneration = surfaceGeneration
        self.viewBounds = viewBounds
        self.windowBounds = windowBounds
        self.safeAreaInsets = safeAreaInsets
        self.scale = scale
        self.drawableSize = drawableSize
    }

    private static func isValid(rect: TVVisionRect) -> Bool {
        rect.x.isFinite
            && rect.y.isFinite
            && abs(rect.x) <= maximumPointCoordinate
            && abs(rect.y) <= maximumPointCoordinate
            && rect.width.isFinite
            && rect.height.isFinite
            && rect.width > 0
            && rect.height > 0
            && rect.width <= maximumPointDimension
            && rect.height <= maximumPointDimension
            && (rect.x + rect.width).isFinite
            && (rect.y + rect.height).isFinite
            && abs(rect.x + rect.width) <= maximumPointCoordinate
            && abs(rect.y + rect.height) <= maximumPointCoordinate
    }

    private static func isValid(
        insets: TVVisionEdgeInsets,
        inside bounds: TVVisionRect
    ) -> Bool {
        let values = [
            insets.top,
            insets.leading,
            insets.bottom,
            insets.trailing
        ]
        guard values.allSatisfy({
            $0.isFinite && $0 >= 0 && $0 <= maximumPointDimension
        }) else {
            return false
        }
        return insets.leading + insets.trailing <= bounds.width
            && insets.top + insets.bottom <= bounds.height
    }
}

enum TVVisionSurfaceAttachment: String, Codable, Hashable, Sendable {
    case detached
    case attached
}

struct TVVisionSceneSurfaceSnapshot: Equatable, Hashable, Sendable {
    let platform: TVVisionPlatform
    let revision: TVVisionSemanticRevision
    let surfaceGeneration: TVVisionGeneration
    let activity: AppSceneActivity
    let attachment: TVVisionSurfaceAttachment
    let isVisible: Bool
    let geometry: TVVisionSurfaceGeometry?

    init(
        platform: TVVisionPlatform,
        revision: TVVisionSemanticRevision,
        surfaceGeneration: TVVisionGeneration,
        activity: AppSceneActivity,
        attachment: TVVisionSurfaceAttachment,
        isVisible: Bool,
        geometry: TVVisionSurfaceGeometry?
    ) throws {
        try surfaceGeneration.require(.surface)
        switch attachment {
        case .detached:
            guard !isVisible, geometry == nil else {
                throw TVVisionPlatformContractError.attachedSurfaceRequired
            }
        case .attached:
            guard let geometry,
                  geometry.platform == platform,
                  geometry.surfaceGeneration == surfaceGeneration else {
                throw TVVisionPlatformContractError.attachedSurfaceRequired
            }
        }
        self.platform = platform
        self.revision = revision
        self.surfaceGeneration = surfaceGeneration
        self.activity = activity
        self.attachment = attachment
        self.isVisible = isVisible
        self.geometry = geometry
    }
}

enum TVVisionFocusIneligibilityReason:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Sendable
{
    case detached
    case sceneInactive = "scene-inactive"
    case notFocused = "not-focused"
    case overlayVisible = "overlay-visible"
    case inputUnavailable = "input-unavailable"
    case systemReserved = "system-reserved"
    case replacing
    case stopped
}

enum TVVisionFocusEligibility: Equatable, Hashable, Sendable {
    case eligible
    case ineligible(TVVisionFocusIneligibilityReason)
}

enum TVVisionInputCapability:
    String,
    Codable,
    CaseIterable,
    Comparable,
    Hashable,
    Sendable
{
    case tvRemote = "tv-remote"
    case extendedGamepad = "extended-gamepad"
    case microGamepad = "micro-gamepad"
    case keyboard
    case pointer
    case indirectPointer = "indirect-pointer"

    static func < (
        lhs: TVVisionInputCapability,
        rhs: TVVisionInputCapability
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct TVVisionInputCapabilitySnapshot: Equatable, Hashable, Sendable {
    let platform: TVVisionPlatform
    let revision: TVVisionSemanticRevision
    let inputGeneration: TVVisionGeneration
    let supported: Set<TVVisionInputCapability>
    let focusEligibility: TVVisionFocusEligibility

    init(
        platform: TVVisionPlatform,
        revision: TVVisionSemanticRevision,
        inputGeneration: TVVisionGeneration,
        supported: Set<TVVisionInputCapability>,
        focusEligibility: TVVisionFocusEligibility
    ) throws {
        try inputGeneration.require(.input)
        let allowed: Set<TVVisionInputCapability>
        switch platform {
        case .tvOS:
            allowed = [
                .tvRemote,
                .extendedGamepad,
                .microGamepad,
                .keyboard
            ]
        case .visionOS:
            allowed = [
                .extendedGamepad,
                .microGamepad,
                .keyboard,
                .pointer,
                .indirectPointer
            ]
        }
        if let unsupported = supported.subtracting(allowed).sorted().first {
            throw TVVisionPlatformContractError.unsupportedInputCapability(
                platform: platform,
                capability: unsupported
            )
        }
        self.platform = platform
        self.revision = revision
        self.inputGeneration = inputGeneration
        self.supported = supported
        self.focusEligibility = focusEligibility
    }
}

struct TVVisionControllerSlot: Codable, Comparable, Hashable, Sendable {
    static let maximumCount = 16

    let rawValue: UInt8

    init(_ value: Int) throws {
        guard (0..<Self.maximumCount).contains(value) else {
            throw TVVisionPlatformContractError.invalidControllerSlot(value)
        }
        rawValue = UInt8(value)
    }

    static func < (
        lhs: TVVisionControllerSlot,
        rhs: TVVisionControllerSlot
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        try self.init(container.decode(Int.self))
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

enum TVVisionControllerProfile: String, Codable, Hashable, Sendable {
    case extendedGamepad = "extended-gamepad"
    case microGamepad = "micro-gamepad"
}

struct TVVisionControllerLease: Equatable, Hashable, Sendable {
    let platform: TVVisionPlatform
    let leaseGeneration: TVVisionGeneration
    let inputGeneration: TVVisionGeneration
    let slot: TVVisionControllerSlot
    let profile: TVVisionControllerProfile
    let capabilities: RemoteControllerCapabilities

    init(
        platform: TVVisionPlatform,
        leaseGeneration: TVVisionGeneration,
        inputGeneration: TVVisionGeneration,
        slot: TVVisionControllerSlot,
        profile: TVVisionControllerProfile,
        capabilities: RemoteControllerCapabilities
    ) throws {
        try leaseGeneration.require(.controller)
        try inputGeneration.require(.input)
        self.platform = platform
        self.leaseGeneration = leaseGeneration
        self.inputGeneration = inputGeneration
        self.slot = slot
        self.profile = profile
        self.capabilities = capabilities
    }
}

enum TVVisionLayerDynamicRangeCapability:
    String,
    Codable,
    Hashable,
    Sendable
{
    case unavailable
    case toneMappingOnly = "tone-mapping-only"
    case preferredDynamicRange = "preferred-dynamic-range"
}

enum TVVisionDisplayHeadroomSource: String, Codable, Hashable, Sendable {
    case unavailable
    case platformReported = "platform-reported"
}

struct TVVisionDisplaySnapshot: Equatable, Hashable, Sendable {
    let platform: TVVisionPlatform
    let revision: TVVisionSemanticRevision
    let displayGeneration: TVVisionGeneration
    let isOutputAvailable: Bool
    let headroomSource: TVVisionDisplayHeadroomSource
    let currentEDRHeadroom: Double?
    let potentialEDRHeadroom: Double?
    let layerCapability: TVVisionLayerDynamicRangeCapability

    init(
        platform: TVVisionPlatform,
        revision: TVVisionSemanticRevision,
        displayGeneration: TVVisionGeneration,
        isOutputAvailable: Bool,
        headroomSource: TVVisionDisplayHeadroomSource,
        currentEDRHeadroom: Double?,
        potentialEDRHeadroom: Double?,
        layerCapability: TVVisionLayerDynamicRangeCapability
    ) throws {
        try displayGeneration.require(.display)
        let values = [currentEDRHeadroom, potentialEDRHeadroom].compactMap { $0 }
        guard values.allSatisfy({ $0.isFinite && $0 >= 1 }) else {
            throw TVVisionPlatformContractError.invalidDisplaySnapshot
        }
        if let currentEDRHeadroom,
           let potentialEDRHeadroom,
           currentEDRHeadroom > potentialEDRHeadroom {
            throw TVVisionPlatformContractError.invalidDisplaySnapshot
        }
        switch headroomSource {
        case .unavailable:
            guard currentEDRHeadroom == nil,
                  potentialEDRHeadroom == nil else {
                throw TVVisionPlatformContractError.invalidDisplaySnapshot
            }
        case .platformReported:
            guard isOutputAvailable,
                  currentEDRHeadroom != nil else {
                throw TVVisionPlatformContractError.invalidDisplaySnapshot
            }
        }
        self.platform = platform
        self.revision = revision
        self.displayGeneration = displayGeneration
        self.isOutputAvailable = isOutputAvailable
        self.headroomSource = headroomSource
        self.currentEDRHeadroom = currentEDRHeadroom
        self.potentialEDRHeadroom = potentialEDRHeadroom
        self.layerCapability = layerCapability
    }
}

enum TVOSDisplayHDRFallbackReason: String, Codable, Hashable, Sendable {
    case outputUnavailable = "output-unavailable"
    case preferredDynamicRangeUnavailable = "preferred-dynamic-range-unavailable"
    case toneMapControlUnavailable = "tone-map-control-unavailable"
    case contentsHeadroomUnavailable = "contents-headroom-unavailable"
    case extendedColorSpaceUnavailable = "extended-color-space-unavailable"
    case headroomUnavailable = "headroom-unavailable"
    case invalidHeadroom = "invalid-headroom"
    case insufficientHeadroom = "insufficient-headroom"
}

struct TVOSDisplayHDRCapabilityInputs: Equatable, Sendable {
    let isOutputAvailable: Bool
    let layerCapability: TVVisionLayerDynamicRangeCapability
    let supportsToneMapControl: Bool
    let supportsContentsHeadroom: Bool
    let supportedEDRGamuts: Set<HDROutputGamut>
    let currentEDRHeadroom: Double?
    let potentialEDRHeadroom: Double?
}

struct TVOSDisplayHDRCapabilities: Equatable, Sendable {
    let layerCapability: TVVisionLayerDynamicRangeCapability
    let supportedEDRGamuts: Set<HDROutputGamut>
    let currentEDRHeadroom: Double?
    let potentialEDRHeadroom: Double?
}

enum TVOSDisplayHDRCapabilityResolution: Equatable, Sendable {
    case directEDR(TVOSDisplayHDRCapabilities)
    case sdrFallback(
        capabilities: TVOSDisplayHDRCapabilities,
        reason: TVOSDisplayHDRFallbackReason
    )

    var capabilities: TVOSDisplayHDRCapabilities {
        switch self {
        case let .directEDR(capabilities),
             let .sdrFallback(capabilities, _):
            capabilities
        }
    }

    var fallbackReason: TVOSDisplayHDRFallbackReason? {
        guard case let .sdrFallback(_, reason) = self else { return nil }
        return reason
    }
}

enum TVOSDisplayHDRCapabilityResolver {
    static func resolve(
        _ inputs: TVOSDisplayHDRCapabilityInputs
    ) -> TVOSDisplayHDRCapabilityResolution {
        func normalizedHeadroom(_ value: Double?) -> Double? {
            guard let value,
                  value.isFinite,
                  (1...HDRLuminanceMapping.maximumCurrentHeadroom)
                    .contains(value) else { return nil }
            return value
        }
        let capabilities = TVOSDisplayHDRCapabilities(
            layerCapability: inputs.layerCapability,
            supportedEDRGamuts: inputs.supportedEDRGamuts,
            currentEDRHeadroom: normalizedHeadroom(
                inputs.currentEDRHeadroom
            ),
            potentialEDRHeadroom: normalizedHeadroom(
                inputs.potentialEDRHeadroom
            )
        )
        func fallback(
            _ reason: TVOSDisplayHDRFallbackReason
        ) -> TVOSDisplayHDRCapabilityResolution {
            .sdrFallback(capabilities: capabilities, reason: reason)
        }

        guard inputs.isOutputAvailable else {
            return fallback(.outputUnavailable)
        }
        guard inputs.layerCapability == .preferredDynamicRange else {
            return fallback(.preferredDynamicRangeUnavailable)
        }
        guard inputs.supportsToneMapControl else {
            return fallback(.toneMapControlUnavailable)
        }
        guard inputs.supportsContentsHeadroom else {
            return fallback(.contentsHeadroomUnavailable)
        }
        guard !inputs.supportedEDRGamuts.isEmpty else {
            return fallback(.extendedColorSpaceUnavailable)
        }
        guard let current = inputs.currentEDRHeadroom,
              let potential = inputs.potentialEDRHeadroom else {
            return fallback(.headroomUnavailable)
        }
        guard capabilities.currentEDRHeadroom != nil,
              capabilities.potentialEDRHeadroom != nil,
              current <= potential else {
            return fallback(.invalidHeadroom)
        }
        guard current > 1 else {
            return fallback(.insufficientHeadroom)
        }
        return .directEDR(capabilities)
    }
}

#if os(tvOS)
@MainActor
enum TVOSNativeDisplayHDRCapabilityProbe {
    static func resolve(
        screen: UIScreen?,
        layer: CAMetalLayer?
    ) -> TVOSDisplayHDRCapabilityResolution {
        if let layer {
            _ = layer.preferredDynamicRange
            _ = layer.toneMapMode
            _ = layer.contentsHeadroom
        }
        var gamuts: Set<HDROutputGamut> = []
        if CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3) != nil {
            gamuts.insert(.displayP3)
        }
        if CGColorSpace(name: CGColorSpace.extendedLinearITUR_2020) != nil {
            gamuts.insert(.ituR2020)
        }
        return TVOSDisplayHDRCapabilityResolver.resolve(
            TVOSDisplayHDRCapabilityInputs(
                isOutputAvailable: screen != nil && layer != nil,
                layerCapability: layer == nil
                    ? .unavailable
                    : .preferredDynamicRange,
                supportsToneMapControl: layer != nil,
                supportsContentsHeadroom: layer != nil,
                supportedEDRGamuts: gamuts,
                currentEDRHeadroom: screen.map {
                    Double($0.currentEDRHeadroom)
                },
                potentialEDRHeadroom: screen.map {
                    Double($0.potentialEDRHeadroom)
                }
            )
        )
    }
}
#endif

enum TVVisionHeadTrackingCapability:
    String,
    Codable,
    Hashable,
    Sendable
{
    case unavailable
    case entitlementRequired = "entitlement-required"
    case intendedSpatialExperience = "intended-spatial-experience"
}

struct TVVisionAudioRouteSnapshot: Equatable, Hashable, Sendable {
    let platform: TVVisionPlatform
    let revision: TVVisionSemanticRevision
    let routeGeneration: TVVisionGeneration
    let outputAvailable: Bool
    let currentOutputChannelCount: Int
    let maximumOutputChannelCount: Int
    let spatialSupport: SpatialAudioRouteSupport
    let platformStrategy: SpatialAudioPlatformStrategy
    let headTrackingCapability: TVVisionHeadTrackingCapability

    init(
        platform: TVVisionPlatform,
        revision: TVVisionSemanticRevision,
        routeGeneration: TVVisionGeneration,
        outputAvailable: Bool,
        currentOutputChannelCount: Int,
        maximumOutputChannelCount: Int,
        spatialSupport: SpatialAudioRouteSupport,
        platformStrategy: SpatialAudioPlatformStrategy,
        headTrackingCapability: TVVisionHeadTrackingCapability
    ) throws {
        try routeGeneration.require(.audioRoute)
        if outputAvailable {
            guard currentOutputChannelCount > 0,
                  maximumOutputChannelCount > 0,
                  currentOutputChannelCount <= maximumOutputChannelCount,
                  maximumOutputChannelCount <= 64 else {
                throw TVVisionPlatformContractError.invalidAudioRouteSnapshot
            }
        } else {
            guard currentOutputChannelCount == 0,
                  maximumOutputChannelCount == 0,
                  spatialSupport == .unknown,
                  platformStrategy == .none,
                  headTrackingCapability == .unavailable else {
                throw TVVisionPlatformContractError.invalidAudioRouteSnapshot
            }
        }
        switch platform {
        case .tvOS:
            guard platformStrategy != .visionOutputExperience,
                  headTrackingCapability != .intendedSpatialExperience else {
                throw TVVisionPlatformContractError.incompatibleAudioStrategy
            }
        case .visionOS:
            guard platformStrategy != .environmentListener,
                  headTrackingCapability != .entitlementRequired else {
                throw TVVisionPlatformContractError.incompatibleAudioStrategy
            }
        }
        if platformStrategy == .none,
           headTrackingCapability != .unavailable {
            throw TVVisionPlatformContractError.incompatibleAudioStrategy
        }
        self.platform = platform
        self.revision = revision
        self.routeGeneration = routeGeneration
        self.outputAvailable = outputAvailable
        self.currentOutputChannelCount = currentOutputChannelCount
        self.maximumOutputChannelCount = maximumOutputChannelCount
        self.spatialSupport = spatialSupport
        self.platformStrategy = platformStrategy
        self.headTrackingCapability = headTrackingCapability
    }
}

struct TVVisionPlatformPresentationSnapshot: Equatable, Hashable, Sendable {
    let ownership: TVVisionPresentationOwnership
    let revision: TVVisionSemanticRevision
    let sceneSurface: TVVisionSceneSurfaceSnapshot
    let inputCapabilities: TVVisionInputCapabilitySnapshot
    let controllerLeases: [TVVisionControllerLease]
    let display: TVVisionDisplaySnapshot
    let audioRoute: TVVisionAudioRouteSnapshot

    init(
        ownership: TVVisionPresentationOwnership,
        revision: TVVisionSemanticRevision,
        sceneSurface: TVVisionSceneSurfaceSnapshot,
        inputCapabilities: TVVisionInputCapabilitySnapshot,
        controllerLeases: [TVVisionControllerLease],
        display: TVVisionDisplaySnapshot,
        audioRoute: TVVisionAudioRouteSnapshot
    ) throws {
        let platform = ownership.platform
        guard sceneSurface.platform == platform,
              inputCapabilities.platform == platform,
              display.platform == platform,
              audioRoute.platform == platform,
              controllerLeases.allSatisfy({ $0.platform == platform }) else {
            throw TVVisionPlatformContractError.platformMismatch
        }
        guard sceneSurface.revision == revision,
              inputCapabilities.revision == revision,
              display.revision == revision,
              audioRoute.revision == revision else {
            throw TVVisionPlatformContractError.revisionMismatch
        }
        guard inputCapabilities.inputGeneration
                == ownership.inputGeneration,
              controllerLeases.allSatisfy({
                  $0.inputGeneration == ownership.inputGeneration
              }) else {
            throw TVVisionPlatformContractError.inputGenerationMismatch
        }
        if inputCapabilities.focusEligibility == .eligible {
            guard sceneSurface.attachment == .attached,
                  sceneSurface.activity == .active,
                  sceneSurface.isVisible else {
                throw TVVisionPlatformContractError.attachedSurfaceRequired
            }
        }
        var slots = Set<UInt8>()
        var leases = Set<UInt64>()
        for controller in controllerLeases {
            guard slots.insert(controller.slot.rawValue).inserted else {
                throw TVVisionPlatformContractError.duplicateControllerSlot(
                    controller.slot.rawValue
                )
            }
            guard leases.insert(controller.leaseGeneration.rawValue).inserted else {
                throw TVVisionPlatformContractError.duplicateControllerLease(
                    controller.leaseGeneration.rawValue
                )
            }
        }
        self.ownership = ownership
        self.revision = revision
        self.sceneSurface = sceneSurface
        self.inputCapabilities = inputCapabilities
        self.controllerLeases = controllerLeases.sorted { $0.slot < $1.slot }
        self.display = display
        self.audioRoute = audioRoute
    }
}
