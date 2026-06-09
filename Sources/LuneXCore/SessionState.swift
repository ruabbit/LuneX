import Foundation
import Observation

@Observable
final class StreamingSessionState {
    var phase: StreamingPhase = .disconnected
    var activeHostID: MoonlightHost.ID?
    var lastError: SessionError?

    var isStreaming: Bool {
        phase == .streaming
    }
}

enum StreamingPhase: Equatable {
    case disconnected
    case discovering
    case pairing(pin: String)
    case connecting(stage: String?)
    case streaming
    case suspending(reason: String)
    case stopping
    case failed(SessionError)

    var label: String {
        switch self {
        case .disconnected: "Disconnected"
        case .discovering: "Discovering"
        case .pairing: "Pairing"
        case let .connecting(stage): stage.map { "Connecting: \($0)" } ?? "Connecting"
        case .streaming: "Streaming"
        case let .suspending(reason): "Suspended: \(reason)"
        case .stopping: "Stopping"
        case let .failed(error): "Failed: \(error.message)"
        }
    }
}

struct SessionError: Error, Equatable, Hashable {
    var subsystem: String
    var message: String
}
