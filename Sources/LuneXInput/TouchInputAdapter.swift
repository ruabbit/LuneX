import Foundation

struct TouchSample: Codable, Equatable, Sendable {
    var id: Int
    var phase: TouchPhase
    var localPoint: RemotePoint
    var pressure: Double
}

struct PointerHoverSample: Codable, Equatable, Sendable {
    var localPoint: RemotePoint
    var buttons: PointerButtonSet
}

struct VirtualControllerSample: Codable, Equatable, Sendable {
    var control: VirtualControllerControl
    var value: Double
}

struct TouchInputAdapter: Sendable {
    var mapper: InputMapper

    func touch(_ sample: TouchSample) -> InputAdapterOutput {
        guard let remotePoint = mapper.remotePoint(localX: sample.localPoint.x, localY: sample.localPoint.y) else {
            return InputAdapterOutput(event: nil, policy: .drop(reason: "Touch is outside a drawable video region"))
        }

        return InputAdapterOutput(
            event: .touch(TouchInputEvent(
                id: sample.id,
                phase: sample.phase,
                point: remotePoint,
                pressure: min(max(0, sample.pressure), 1),
                referenceSize: mapper.snapshot.sourceSize
            )),
            policy: .deliver
        )
    }

    func pointerHover(_ sample: PointerHoverSample) -> InputAdapterOutput {
        guard let remotePoint = mapper.remotePoint(localX: sample.localPoint.x, localY: sample.localPoint.y) else {
            return InputAdapterOutput(event: nil, policy: .drop(reason: "Pointer hover is outside a drawable video region"))
        }

        return InputAdapterOutput(
            event: .pointer(.absoluteMove(
                point: remotePoint,
                referenceSize: mapper.snapshot.sourceSize,
                buttons: sample.buttons
            )),
            policy: .deliver
        )
    }

    func virtualController(_ sample: VirtualControllerSample) -> InputAdapterOutput {
        let clampedValue = min(max(sample.value, 0), 1)
        return InputAdapterOutput(
            event: .virtualController(VirtualControllerInputEvent(
                control: sample.control,
                value: clampedValue,
                isPressed: clampedValue > 0
            )),
            policy: .deliver
        )
    }
}
