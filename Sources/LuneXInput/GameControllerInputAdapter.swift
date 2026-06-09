import Foundation

struct GameControllerConnectionState: Codable, Equatable, Hashable, Sendable, Identifiable {
    var id: String
    var vendorName: String?
    var playerIndex: Int?
    var isConnected: Bool
    var supportsExtendedGamepad: Bool
    var supportsMicroGamepad: Bool
}

struct GameControllerElementSample: Codable, Equatable, Sendable {
    var controllerID: String
    var playerIndex: Int?
    var element: GameControllerElement
    var value: Double
}

struct GameControllerBindingSnapshot: Codable, Equatable, Sendable {
    var controllers: [GameControllerConnectionState]

    var connectedControllers: [GameControllerConnectionState] {
        controllers.filter(\.isConnected)
    }

    var remoteControllersBitmap: Int {
        connectedControllers.prefix(8).enumerated().reduce(0) { bitmap, entry in
            bitmap | (1 << entry.offset)
        }
    }
}

struct GameControllerInputAdapter: Sendable {
    var pressedThreshold = 0.5

    func controllerElement(_ sample: GameControllerElementSample) -> InputAdapterOutput {
        InputAdapterOutput(
            event: .gameController(GameControllerInputEvent(
                controllerID: sample.controllerID,
                playerIndex: sample.playerIndex,
                element: sample.element,
                value: normalizedValue(sample.value, for: sample.element),
                isPressed: isPressed(sample.value, for: sample.element)
            )),
            policy: .deliver
        )
    }

    func unsupportedElement(controllerID: String, elementName: String) -> InputAdapterOutput {
        InputAdapterOutput(
            event: nil,
            policy: .drop(reason: "Controller \(controllerID) element \(elementName) is not mapped")
        )
    }

    private func normalizedValue(_ value: Double, for element: GameControllerElement) -> Double {
        switch element {
        case .leftThumbstickX, .leftThumbstickY, .rightThumbstickX, .rightThumbstickY:
            return min(max(value, -1), 1)
        default:
            return min(max(value, 0), 1)
        }
    }

    private func isPressed(_ value: Double, for element: GameControllerElement) -> Bool {
        switch element {
        case .leftThumbstickX, .leftThumbstickY, .rightThumbstickX, .rightThumbstickY:
            return abs(value) >= pressedThreshold
        default:
            return value >= pressedThreshold
        }
    }
}

#if canImport(GameController)
import GameController

@MainActor
final class GameControllerPlatformMonitor {
    private var observers: [NSObjectProtocol] = []
    private(set) var snapshot = GameControllerBindingSnapshot(controllers: [])

    func start(notificationCenter: NotificationCenter = .default) {
        stop(notificationCenter: notificationCenter)
        snapshot = snapshotFromConnectedControllers()

        observers = [
            notificationCenter.addObserver(forName: Notification.Name.GCControllerDidConnect, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.snapshot = self?.snapshotFromConnectedControllers() ?? GameControllerBindingSnapshot(controllers: [])
                }
            },
            notificationCenter.addObserver(forName: Notification.Name.GCControllerDidDisconnect, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.snapshot = self?.snapshotFromConnectedControllers() ?? GameControllerBindingSnapshot(controllers: [])
                }
            }
        ]
    }

    func stop(notificationCenter: NotificationCenter = .default) {
        observers.forEach(notificationCenter.removeObserver)
        observers.removeAll()
    }

    private func snapshotFromConnectedControllers() -> GameControllerBindingSnapshot {
        GameControllerBindingSnapshot(
            controllers: GCController.controllers().enumerated().map { index, controller in
                GameControllerConnectionState(
                    id: controller.vendorName.map { "\($0)-\(index)" } ?? "controller-\(index)",
                    vendorName: controller.vendorName,
                    playerIndex: numericPlayerIndex(controller.playerIndex),
                    isConnected: true,
                    supportsExtendedGamepad: controller.extendedGamepad != nil,
                    supportsMicroGamepad: controller.microGamepad != nil
                )
            }
        )
    }

    private func numericPlayerIndex(_ playerIndex: GCControllerPlayerIndex) -> Int? {
        switch playerIndex {
        case .index1: 1
        case .index2: 2
        case .index3: 3
        case .index4: 4
        default: nil
        }
    }
}
#endif
