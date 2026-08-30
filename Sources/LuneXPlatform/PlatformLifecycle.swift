import Foundation
import Observation

@Observable
final class PlatformLifecycleState {
    var isStreamActive = false
    var isVisible = true
    var isFocused = true
    private(set) var displayID: String?
    var drawableSize: PixelSize = .zero
    private(set) var headroom = DisplayHeadroom()
    private(set) var displayRevision = HDRDisplayRevision(rawValue: 0)
    private(set) var displaySnapshot: HDRDisplaySnapshot?
    private(set) var isDisplayRevisionExhausted = false
    var renderPolicy: RenderPolicy = .idle
    private(set) var revision = 0
    @ObservationIgnored private var activeSurfaceAttachmentID: UUID?
    @ObservationIgnored private var displayPublisher = HDRDisplaySnapshotPublisher()

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

    func isCurrentSurfaceAttachment(_ attachmentID: UUID) -> Bool {
        activeSurfaceAttachmentID == attachmentID
    }

    @discardableResult
    func updateSurface(
        displayID: String?,
        headroom: DisplayHeadroom,
        drawableSize: PixelSize
    ) -> HDRDisplayPublicationOutcome {
        self.displayID = displayID
        self.headroom = headroom
        self.drawableSize = drawableSize
        let outcome = publishDisplayState(isSurfaceAttached: true)
        updateRenderPolicy()
        return outcome
    }

    @discardableResult
    func updateSurface(
        for attachmentID: UUID,
        displayID: String?,
        headroom: DisplayHeadroom,
        drawableSize: PixelSize
    ) -> HDRDisplayPublicationOutcome? {
        guard activeSurfaceAttachmentID == attachmentID else { return nil }
        return updateSurface(
            displayID: displayID,
            headroom: headroom,
            drawableSize: drawableSize
        )
    }

    func clearSurfaceAttachment(_ attachmentID: UUID) -> Bool {
        guard releaseSurfaceAttachment(attachmentID) else { return false }
        isVisible = false
        isFocused = false
        displayID = nil
        headroom = DisplayHeadroom()
        drawableSize = .zero
        _ = publishDisplayState(isSurfaceAttached: false)
        updateRenderPolicy()
        return true
    }

    @discardableResult
    func releaseSurfaceAttachment(_ attachmentID: UUID) -> Bool {
        guard activeSurfaceAttachmentID == attachmentID else { return false }
        activeSurfaceAttachmentID = nil
        return true
    }

    private func publishDisplayState(
        isSurfaceAttached: Bool
    ) -> HDRDisplayPublicationOutcome {
        let outcome = displayPublisher.update(
            isSurfaceAttached: isSurfaceAttached,
            displayID: displayID,
            headroom: headroom
        )
        displayRevision = displayPublisher.revision
        displaySnapshot = displayPublisher.snapshot
        isDisplayRevisionExhausted = displayPublisher.isRevisionExhausted
        return outcome
    }
}

@Observable
final class StreamRenderState {
    var policy: RenderPolicy = .idle {
        didSet { publishRevisionIfChanged(policy, oldValue: oldValue) }
    }
    var transform: RenderTransform {
        didSet {
            publishCoordinateSnapshot()
            publishRevisionIfChanged(transform, oldValue: oldValue)
        }
    }
    private(set) var coordinateSnapshot: StreamCoordinateSnapshot?
    var headroom = DisplayHeadroom() {
        didSet { publishRevisionIfChanged(headroom, oldValue: oldValue) }
    }
    var displaySnapshot: HDRDisplaySnapshot? {
        didSet { publishRevisionIfChanged(displaySnapshot, oldValue: oldValue) }
    }
    var isDisplayRevisionExhausted = false {
        didSet {
            publishRevisionIfChanged(
                isDisplayRevisionExhausted,
                oldValue: oldValue
            )
        }
    }
    var negotiatedVideoColorMetadata: VideoColorMetadata? {
        didSet {
            publishRevisionIfChanged(
                negotiatedVideoColorMetadata,
                oldValue: oldValue
            )
        }
    }
    var decodedVideoPresentationContract: StreamVideoDecodedPresentationContract? {
        didSet {
            publishRevisionIfChanged(
                decodedVideoPresentationContract,
                oldValue: oldValue
            )
        }
    }
    var hdrRenderResolution: HDRRenderConfigurationResolution = .closed(.inactiveSession) {
        didSet {
            publishRevisionIfChanged(hdrRenderResolution, oldValue: oldValue)
        }
    }
    private(set) var revision: UInt64 = 0
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

    func applyPlatformCoordinateSnapshot(
        _ snapshot: StreamCoordinateSnapshot?
    ) {
        let previousSnapshot = coordinateSnapshot
        defer {
            if coordinateSnapshot != previousSnapshot {
                publishRevision()
            }
        }
        guard let snapshot else {
            if transform.drawableSize != .zero {
                transform.drawableSize = .zero
            }
            coordinateSnapshot = nil
            return
        }
        guard transform.sourceSize == snapshot.sourceSize,
              transform.mode == snapshot.mode else {
            if transform.drawableSize != .zero {
                transform.drawableSize = .zero
            }
            coordinateSnapshot = nil
            return
        }
        if transform.drawableSize != snapshot.drawableSize {
            transform.drawableSize = snapshot.drawableSize
        }
        coordinateSnapshot = snapshot
    }

    private func publishCoordinateSnapshot() {
        coordinateSnapshot = coordinatePublisher.update(
            sourceSize: transform.sourceSize,
            drawableSize: transform.drawableSize,
            mode: transform.mode
        )
    }

    private func publishRevisionIfChanged<Value: Equatable>(
        _ value: Value,
        oldValue: Value
    ) {
        guard value != oldValue else { return }
        publishRevision()
    }

    private func publishRevision() {
        revision &+= 1
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
