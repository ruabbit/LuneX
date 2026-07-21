import Foundation

struct InputMapper: Sendable {
    let snapshot: StreamCoordinateSnapshot

    func remotePoint(localX: Double, localY: Double) -> RemotePoint? {
        let localPoint = StreamCoordinatePoint(x: localX, y: localY)
        let resolved = snapshot.resolvedVideo
        guard resolved.drawableBounds.contains(localPoint),
              resolved.videoRect.contains(localPoint) else {
            return nil
        }

        let sourceWidth = Double(snapshot.sourceSize.width)
        let sourceHeight = Double(snapshot.sourceSize.height)
        let sourceX = (localX - resolved.videoRect.minX) / resolved.scale
        let sourceY = (localY - resolved.videoRect.minY) / resolved.scale
        guard sourceX.isFinite, sourceY.isFinite else { return nil }
        return RemotePoint(
            x: min(max(sourceX, 0), sourceWidth),
            y: min(max(sourceY, 0), sourceHeight)
        )
    }
}

struct RemotePoint: Codable, Equatable, Hashable, Sendable {
    var x: Double
    var y: Double
}
