import Foundation

struct MobileSceneSurfaceGeneration: Codable, Equatable, Hashable, Sendable {
    let rawValue: UInt64

    init?(rawValue: UInt64) {
        guard rawValue > 0 else { return nil }
        self.rawValue = rawValue
    }
}

struct MobileDisplayGeneration: Codable, Equatable, Hashable, Sendable {
    let rawValue: UInt64

    init?(rawValue: UInt64) {
        guard rawValue > 0 else { return nil }
        self.rawValue = rawValue
    }
}

struct MobileSceneWindowRevision: Codable, Equatable, Hashable, Sendable {
    let rawValue: UInt64
}

enum MobileInterfaceOrientation: String, Codable, Equatable, Hashable, Sendable {
    case unknown
    case portrait
    case portraitUpsideDown
    case landscapeLeft
    case landscapeRight
}

enum MobileSceneSizeClass: String, Codable, Equatable, Hashable, Sendable {
    case unspecified
    case compact
    case regular
}

enum MobileInterfaceStyle: String, Codable, Equatable, Hashable, Sendable {
    case unspecified
    case light
    case dark
}

enum MobileSceneResizePhase: String, Codable, Equatable, Hashable, Sendable {
    case resizing
    case settled
}

struct MobileSceneTraits: Codable, Equatable, Hashable, Sendable {
    let horizontalSizeClass: MobileSceneSizeClass
    let verticalSizeClass: MobileSceneSizeClass
    let interfaceStyle: MobileInterfaceStyle
}

struct MobileSceneRect: Codable, Equatable, Hashable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
}

struct MobileSceneEdgeInsets: Codable, Equatable, Hashable, Sendable {
    let top: Double
    let leading: Double
    let bottom: Double
    let trailing: Double

    static let zero = MobileSceneEdgeInsets(
        top: 0,
        leading: 0,
        bottom: 0,
        trailing: 0
    )
}

struct MobileSceneWindowAttachedSample: Equatable, Sendable {
    let activity: AppSceneActivity
    let displayGeneration: UInt64
    let viewBounds: MobileSceneRect
    let windowBounds: MobileSceneRect
    let safeAreaInsets: MobileSceneEdgeInsets
    let scale: Double
    let orientation: MobileInterfaceOrientation
    let traits: MobileSceneTraits
    let resizePhase: MobileSceneResizePhase

    init(
        activity: AppSceneActivity,
        displayGeneration: UInt64,
        viewBounds: MobileSceneRect,
        windowBounds: MobileSceneRect,
        safeAreaInsets: MobileSceneEdgeInsets,
        scale: Double,
        orientation: MobileInterfaceOrientation,
        traits: MobileSceneTraits,
        resizePhase: MobileSceneResizePhase = .settled
    ) {
        self.activity = activity
        self.displayGeneration = displayGeneration
        self.viewBounds = viewBounds
        self.windowBounds = windowBounds
        self.safeAreaInsets = safeAreaInsets
        self.scale = scale
        self.orientation = orientation
        self.traits = traits
        self.resizePhase = resizePhase
    }
}

enum MobileSceneWindowSample: Equatable, Sendable {
    case detached(activity: AppSceneActivity)
    case attached(MobileSceneWindowAttachedSample)
}

enum MobileSceneWindowValidationError:
    String,
    Codable,
    Error,
    Equatable,
    Hashable,
    Sendable
{
    case invalidDisplayGeneration = "invalid-display-generation"
    case invalidViewBounds = "invalid-view-bounds"
    case invalidWindowBounds = "invalid-window-bounds"
    case invalidSafeAreaInsets = "invalid-safe-area-insets"
    case invalidScale = "invalid-scale"
    case drawableSizeOverflow = "drawable-size-overflow"
}

struct MobileSceneWindowGeometry: Codable, Equatable, Hashable, Sendable {
    let viewBounds: MobileSceneRect
    let windowBounds: MobileSceneRect
    let safeAreaInsets: MobileSceneEdgeInsets
    let scale: Double
    let drawableSize: PixelSize
    let orientation: MobileInterfaceOrientation
    let traits: MobileSceneTraits
    let resizePhase: MobileSceneResizePhase
}

enum MobileSceneWindowState: Codable, Equatable, Hashable, Sendable {
    case detached(activity: AppSceneActivity)
    case attached(
        activity: AppSceneActivity,
        display: MobileDisplayGeneration,
        geometry: MobileSceneWindowGeometry
    )
    case unavailable(
        activity: AppSceneActivity,
        reason: MobileSceneWindowValidationError
    )

    var activity: AppSceneActivity {
        switch self {
        case let .detached(activity),
             let .attached(activity, _, _),
             let .unavailable(activity, _):
            activity
        }
    }

    var geometry: MobileSceneWindowGeometry? {
        guard case let .attached(_, _, geometry) = self else { return nil }
        return geometry
    }
}

struct MobileSceneWindowSnapshot: Codable, Equatable, Hashable, Sendable {
    let surfaceGeneration: MobileSceneSurfaceGeneration
    let revision: MobileSceneWindowRevision
    let state: MobileSceneWindowState
}

enum MobileSceneWindowPublicationOutcome: Equatable, Sendable {
    case unchanged
    case published(MobileSceneWindowSnapshot)
    case revisionExhausted
}

struct MobileSceneWindowSnapshotPublisher: Sendable {
    static let maximumPointCoordinate = 1_000_000.0
    static let maximumPointDimension = 131_072.0
    static let maximumScale = 16.0
    static let maximumDrawableDimension = 1_048_576.0

    let surfaceGeneration: MobileSceneSurfaceGeneration
    private(set) var revision: MobileSceneWindowRevision
    private(set) var snapshot: MobileSceneWindowSnapshot?
    private(set) var isRevisionExhausted = false

    private var state: MobileSceneWindowState?

    init(
        surfaceGeneration: MobileSceneSurfaceGeneration,
        initialRevision: MobileSceneWindowRevision =
            MobileSceneWindowRevision(rawValue: 0)
    ) {
        self.surfaceGeneration = surfaceGeneration
        revision = initialRevision
    }

    @discardableResult
    mutating func update(
        _ sample: MobileSceneWindowSample
    ) -> MobileSceneWindowPublicationOutcome {
        guard !isRevisionExhausted else { return .revisionExhausted }
        let nextState = Self.normalize(sample)
        guard nextState != state else { return .unchanged }
        state = nextState

        let nextRevision = revision.rawValue.addingReportingOverflow(1)
        guard !nextRevision.overflow else {
            snapshot = nil
            isRevisionExhausted = true
            return .revisionExhausted
        }
        revision = MobileSceneWindowRevision(
            rawValue: nextRevision.partialValue
        )
        let nextSnapshot = MobileSceneWindowSnapshot(
            surfaceGeneration: surfaceGeneration,
            revision: revision,
            state: nextState
        )
        snapshot = nextSnapshot
        return .published(nextSnapshot)
    }

    private static func normalize(
        _ sample: MobileSceneWindowSample
    ) -> MobileSceneWindowState {
        switch sample {
        case let .detached(activity):
            return .detached(activity: activity)
        case let .attached(sample):
            do {
                let display = try normalizedDisplayGeneration(
                    sample.displayGeneration
                )
                let geometry = try normalizedGeometry(sample)
                return .attached(
                    activity: sample.activity,
                    display: display,
                    geometry: geometry
                )
            } catch let error as MobileSceneWindowValidationError {
                return .unavailable(
                    activity: sample.activity,
                    reason: error
                )
            } catch {
                return .unavailable(
                    activity: sample.activity,
                    reason: .invalidViewBounds
                )
            }
        }
    }

    private static func normalizedDisplayGeneration(
        _ rawValue: UInt64
    ) throws -> MobileDisplayGeneration {
        guard let display = MobileDisplayGeneration(rawValue: rawValue) else {
            throw MobileSceneWindowValidationError.invalidDisplayGeneration
        }
        return display
    }

    private static func normalizedGeometry(
        _ sample: MobileSceneWindowAttachedSample
    ) throws -> MobileSceneWindowGeometry {
        guard isValid(rect: sample.viewBounds) else {
            throw MobileSceneWindowValidationError.invalidViewBounds
        }
        guard isValid(rect: sample.windowBounds) else {
            throw MobileSceneWindowValidationError.invalidWindowBounds
        }
        guard isValid(
            insets: sample.safeAreaInsets,
            inside: sample.viewBounds
        ) else {
            throw MobileSceneWindowValidationError.invalidSafeAreaInsets
        }
        guard sample.scale.isFinite,
              sample.scale > 0,
              sample.scale <= maximumScale else {
            throw MobileSceneWindowValidationError.invalidScale
        }

        let drawableWidth = sample.viewBounds.width * sample.scale
        let drawableHeight = sample.viewBounds.height * sample.scale
        guard drawableWidth.isFinite,
              drawableHeight.isFinite,
              drawableWidth > 0,
              drawableHeight > 0,
              drawableWidth <= maximumDrawableDimension,
              drawableHeight <= maximumDrawableDimension else {
            throw MobileSceneWindowValidationError.drawableSizeOverflow
        }
        let roundedWidth = drawableWidth.rounded(.toNearestOrAwayFromZero)
        let roundedHeight = drawableHeight.rounded(.toNearestOrAwayFromZero)
        guard roundedWidth > 0,
              roundedHeight > 0,
              roundedWidth <= Double(Int.max),
              roundedHeight <= Double(Int.max) else {
            throw MobileSceneWindowValidationError.drawableSizeOverflow
        }

        return MobileSceneWindowGeometry(
            viewBounds: sample.viewBounds,
            windowBounds: sample.windowBounds,
            safeAreaInsets: sample.safeAreaInsets,
            scale: sample.scale,
            drawableSize: PixelSize(
                width: Int(roundedWidth),
                height: Int(roundedHeight)
            ),
            orientation: sample.orientation,
            traits: sample.traits,
            resizePhase: sample.resizePhase
        )
    }

    private static func isValid(rect: MobileSceneRect) -> Bool {
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
        insets: MobileSceneEdgeInsets,
        inside bounds: MobileSceneRect
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
