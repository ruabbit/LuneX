import Foundation

struct StreamCoordinatePoint: Equatable, Hashable, Sendable {
    let x: Double
    let y: Double
}

struct StreamCoordinateRect: Equatable, Hashable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    var minX: Double { x }
    var minY: Double { y }
    var maxX: Double { x + width }
    var maxY: Double { y + height }

    func contains(_ point: StreamCoordinatePoint) -> Bool {
        point.x.isFinite
            && point.y.isFinite
            && point.x >= minX
            && point.x <= maxX
            && point.y >= minY
            && point.y <= maxY
    }
}

struct ResolvedVideoRectangle: Equatable, Sendable {
    let drawableBounds: StreamCoordinateRect
    let videoRect: StreamCoordinateRect
    let sourceCropRect: StreamCoordinateRect
    let scale: Double
}

enum StreamVideoRectangleResolver {
    static func resolve(
        sourceSize: PixelSize,
        drawableSize: PixelSize,
        mode: RenderScaleMode
    ) -> ResolvedVideoRectangle? {
        guard sourceSize.width > 0,
              sourceSize.height > 0,
              drawableSize.width > 0,
              drawableSize.height > 0 else {
            return nil
        }

        let sourceWidth = Double(sourceSize.width)
        let sourceHeight = Double(sourceSize.height)
        let drawableWidth = Double(drawableSize.width)
        let drawableHeight = Double(drawableSize.height)
        guard sourceWidth.isFinite,
              sourceHeight.isFinite,
              drawableWidth.isFinite,
              drawableHeight.isFinite else {
            return nil
        }

        let horizontalScale = drawableWidth / sourceWidth
        let verticalScale = drawableHeight / sourceHeight
        let scale = mode == .fit
            ? min(horizontalScale, verticalScale)
            : max(horizontalScale, verticalScale)
        guard scale.isFinite, scale > 0 else { return nil }

        let videoWidth = sourceWidth * scale
        let videoHeight = sourceHeight * scale
        let videoRect = StreamCoordinateRect(
            x: (drawableWidth - videoWidth) / 2,
            y: (drawableHeight - videoHeight) / 2,
            width: videoWidth,
            height: videoHeight
        )
        let drawableBounds = StreamCoordinateRect(
            x: 0,
            y: 0,
            width: drawableWidth,
            height: drawableHeight
        )
        guard isValid(videoRect), isValid(drawableBounds) else { return nil }

        let sourceCropRect: StreamCoordinateRect
        switch mode {
        case .fit:
            sourceCropRect = StreamCoordinateRect(
                x: 0,
                y: 0,
                width: sourceWidth,
                height: sourceHeight
            )
        case .fill:
            guard let visibleVideoRect = intersection(videoRect, drawableBounds) else {
                return nil
            }
            let cropX = max(0, (visibleVideoRect.minX - videoRect.minX) / scale)
            let cropY = max(0, (visibleVideoRect.minY - videoRect.minY) / scale)
            sourceCropRect = StreamCoordinateRect(
                x: min(cropX, sourceWidth),
                y: min(cropY, sourceHeight),
                width: min(visibleVideoRect.width / scale, sourceWidth - cropX),
                height: min(visibleVideoRect.height / scale, sourceHeight - cropY)
            )
        }

        guard isValid(sourceCropRect),
              sourceCropRect.minX >= 0,
              sourceCropRect.minY >= 0,
              sourceCropRect.maxX <= sourceWidth,
              sourceCropRect.maxY <= sourceHeight else {
            return nil
        }
        return ResolvedVideoRectangle(
            drawableBounds: drawableBounds,
            videoRect: videoRect,
            sourceCropRect: sourceCropRect,
            scale: scale
        )
    }

    private static func intersection(
        _ left: StreamCoordinateRect,
        _ right: StreamCoordinateRect
    ) -> StreamCoordinateRect? {
        let minX = max(left.minX, right.minX)
        let minY = max(left.minY, right.minY)
        let maxX = min(left.maxX, right.maxX)
        let maxY = min(left.maxY, right.maxY)
        guard maxX > minX, maxY > minY else { return nil }
        return StreamCoordinateRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    private static func isValid(_ rect: StreamCoordinateRect) -> Bool {
        rect.x.isFinite
            && rect.y.isFinite
            && rect.width.isFinite
            && rect.height.isFinite
            && rect.width > 0
            && rect.height > 0
            && rect.maxX.isFinite
            && rect.maxY.isFinite
    }
}

struct StreamCoordinateSnapshot: Equatable, Sendable {
    let revision: UInt64
    let sourceSize: PixelSize
    let drawableSize: PixelSize
    let mode: RenderScaleMode
    let resolvedVideo: ResolvedVideoRectangle

    static func resolve(
        revision: UInt64,
        sourceSize: PixelSize,
        drawableSize: PixelSize,
        mode: RenderScaleMode
    ) -> StreamCoordinateSnapshot? {
        guard let resolvedVideo = StreamVideoRectangleResolver.resolve(
            sourceSize: sourceSize,
            drawableSize: drawableSize,
            mode: mode
        ) else {
            return nil
        }
        return StreamCoordinateSnapshot(
            revision: revision,
            sourceSize: sourceSize,
            drawableSize: drawableSize,
            mode: mode,
            resolvedVideo: resolvedVideo
        )
    }
}

struct StreamCoordinateSnapshotPublisher: Sendable {
    private struct Inputs: Equatable, Sendable {
        let sourceSize: PixelSize
        let drawableSize: PixelSize
        let mode: RenderScaleMode
    }

    private var inputs: Inputs?
    private(set) var revision: UInt64
    private(set) var snapshot: StreamCoordinateSnapshot?

    init(initialRevision: UInt64 = 0) {
        revision = initialRevision
    }

    @discardableResult
    mutating func update(
        sourceSize: PixelSize,
        drawableSize: PixelSize,
        mode: RenderScaleMode
    ) -> StreamCoordinateSnapshot? {
        let nextInputs = Inputs(
            sourceSize: sourceSize,
            drawableSize: drawableSize,
            mode: mode
        )
        guard nextInputs != inputs else { return snapshot }
        inputs = nextInputs

        let nextRevision = revision.addingReportingOverflow(1)
        guard !nextRevision.overflow else {
            snapshot = nil
            return nil
        }
        revision = nextRevision.partialValue

        guard let updated = StreamCoordinateSnapshot.resolve(
            revision: revision,
            sourceSize: sourceSize,
            drawableSize: drawableSize,
            mode: mode
        ) else {
            snapshot = nil
            return nil
        }
        snapshot = updated
        return updated
    }
}
