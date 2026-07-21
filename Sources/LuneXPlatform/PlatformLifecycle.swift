import Foundation
import Observation

@Observable
final class PlatformLifecycleState {
    var isStreamActive = false
    var isVisible = true
    var isFocused = true
    var displayID: String?
    var drawableSize: PixelSize = .zero
    var headroom = DisplayHeadroom()
    var renderPolicy: RenderPolicy = .idle
    private(set) var revision = 0
    @ObservationIgnored private var activeSurfaceAttachmentID: UUID?

    func updateRenderPolicy() {
        renderPolicy = LifecycleRenderPolicyResolver.resolve(
            isStreamActive: isStreamActive,
            isVisible: isVisible,
            isFocused: isFocused,
            drawableSize: drawableSize
        )
        revision &+= 1
    }

    func setStreamActive(_ active: Bool) {
        isStreamActive = active
        updateRenderPolicy()
    }

    func claimSurfaceAttachment(_ attachmentID: UUID) {
        activeSurfaceAttachmentID = attachmentID
    }

    func updateSurface(
        displayID: String?,
        headroom: DisplayHeadroom,
        drawableSize: PixelSize
    ) {
        self.displayID = displayID
        self.headroom = headroom
        self.drawableSize = drawableSize
        updateRenderPolicy()
    }

    func clearSurfaceAttachment(_ attachmentID: UUID) -> Bool {
        guard releaseSurfaceAttachment(attachmentID) else { return false }
        isVisible = false
        isFocused = false
        displayID = nil
        headroom = DisplayHeadroom()
        drawableSize = .zero
        updateRenderPolicy()
        return true
    }

    @discardableResult
    func releaseSurfaceAttachment(_ attachmentID: UUID) -> Bool {
        guard activeSurfaceAttachmentID == attachmentID else { return false }
        activeSurfaceAttachmentID = nil
        return true
    }
}

@Observable
final class StreamRenderState {
    var policy: RenderPolicy = .idle
    var transform: RenderTransform {
        didSet { publishCoordinateSnapshot() }
    }
    private(set) var coordinateSnapshot: StreamCoordinateSnapshot?
    var headroom = DisplayHeadroom()
    @ObservationIgnored private var coordinatePublisher: StreamCoordinateSnapshotPublisher

    init(transform: RenderTransform = RenderTransform()) {
        self.transform = transform
        var publisher = StreamCoordinateSnapshotPublisher()
        coordinateSnapshot = publisher.update(
            sourceSize: transform.sourceSize,
            drawableSize: transform.drawableSize,
            mode: transform.mode
        )
        coordinatePublisher = publisher
    }

    private func publishCoordinateSnapshot() {
        coordinateSnapshot = coordinatePublisher.update(
            sourceSize: transform.sourceSize,
            drawableSize: transform.drawableSize,
            mode: transform.mode
        )
    }
}

enum RenderPolicy: Equatable, Sendable {
    case idle
    case active
    case throttled(reason: String)
    case paused(reason: String)
}

enum SessionLifecycleClosureReason: String, Equatable, Sendable {
    case streamInactive
    case notVisible
    case drawableUnavailable
    case notFocused
}

enum VideoProcessingDirective: Equatable, Sendable {
    case inactive
    case submitDecodedVideo
    case drainTransportWithoutDecoding(reason: SessionLifecycleClosureReason)
}

enum PresentationLifecycleDirective: Equatable, Sendable {
    case clear(reason: SessionLifecycleClosureReason)
    case active
    case throttled(reason: SessionLifecycleClosureReason)
}

enum InputLifecycleDirective: Equatable, Sendable {
    case closed(reason: SessionLifecycleClosureReason, requiresReleaseBarrier: Bool)
    case open
}

struct SessionLifecycleDirective: Equatable, Sendable {
    let renderPolicy: RenderPolicy
    let videoProcessing: VideoProcessingDirective
    let presentation: PresentationLifecycleDirective
    let input: InputLifecycleDirective
}

enum SessionLifecycleDirectiveResolver {
    static func resolve(
        isStreamActive: Bool,
        isVisible: Bool,
        isFocused: Bool,
        drawableSize: PixelSize
    ) -> SessionLifecycleDirective {
        guard isStreamActive else {
            return SessionLifecycleDirective(
                renderPolicy: .idle,
                videoProcessing: .inactive,
                presentation: .clear(reason: .streamInactive),
                input: .closed(reason: .streamInactive, requiresReleaseBarrier: false)
            )
        }

        guard isVisible else {
            return pausedDirective(
                reason: .notVisible,
                renderReason: "Window or scene not visible"
            )
        }

        guard drawableSize.width > 0, drawableSize.height > 0 else {
            return pausedDirective(
                reason: .drawableUnavailable,
                renderReason: "Drawable is not ready"
            )
        }

        guard isFocused else {
            return SessionLifecycleDirective(
                renderPolicy: .throttled(reason: "Window or scene not focused"),
                videoProcessing: .submitDecodedVideo,
                presentation: .throttled(reason: .notFocused),
                input: .closed(reason: .notFocused, requiresReleaseBarrier: true)
            )
        }

        return SessionLifecycleDirective(
            renderPolicy: .active,
            videoProcessing: .submitDecodedVideo,
            presentation: .active,
            input: .open
        )
    }

    private static func pausedDirective(
        reason: SessionLifecycleClosureReason,
        renderReason: String
    ) -> SessionLifecycleDirective {
        SessionLifecycleDirective(
            renderPolicy: .paused(reason: renderReason),
            videoProcessing: .drainTransportWithoutDecoding(reason: reason),
            presentation: .clear(reason: reason),
            input: .closed(reason: reason, requiresReleaseBarrier: true)
        )
    }
}

enum LifecycleRenderPolicyResolver {
    static func resolve(
        isStreamActive: Bool,
        isVisible: Bool,
        isFocused: Bool,
        drawableSize: PixelSize
    ) -> RenderPolicy {
        SessionLifecycleDirectiveResolver.resolve(
            isStreamActive: isStreamActive,
            isVisible: isVisible,
            isFocused: isFocused,
            drawableSize: drawableSize
        ).renderPolicy
    }
}

struct PixelSize: Codable, Equatable, Hashable, Sendable {
    static let zero = PixelSize(width: 0, height: 0)

    var width: Int
    var height: Int
}

struct RenderTransform: Equatable, Sendable {
    var sourceSize = PixelSize.zero
    var drawableSize = PixelSize.zero
    var mode: RenderScaleMode = .fit
}

enum RenderScaleMode: String, Codable, CaseIterable, Sendable {
    case fit
    case fill
}
