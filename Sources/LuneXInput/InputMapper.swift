import Foundation

struct InputMapper {
    var transform: RenderTransform

    func remotePoint(localX: Double, localY: Double) -> RemotePoint? {
        guard transform.drawableSize.width > 0,
              transform.drawableSize.height > 0,
              transform.sourceSize.width > 0,
              transform.sourceSize.height > 0
        else { return nil }

        let drawableWidth = Double(transform.drawableSize.width)
        let drawableHeight = Double(transform.drawableSize.height)
        let sourceWidth = Double(transform.sourceSize.width)
        let sourceHeight = Double(transform.sourceSize.height)
        let scale: Double

        switch transform.mode {
        case .fit:
            scale = min(drawableWidth / sourceWidth, drawableHeight / sourceHeight)
        case .fill:
            scale = max(drawableWidth / sourceWidth, drawableHeight / sourceHeight)
        }

        let videoWidth = sourceWidth * scale
        let videoHeight = sourceHeight * scale
        let originX = (drawableWidth - videoWidth) / 2.0
        let originY = (drawableHeight - videoHeight) / 2.0
        let clampedX = min(max(localX, originX), originX + videoWidth) - originX
        let clampedY = min(max(localY, originY), originY + videoHeight) - originY

        return RemotePoint(x: clampedX / scale, y: clampedY / scale)
    }
}

struct RemotePoint: Equatable {
    var x: Double
    var y: Double
}
