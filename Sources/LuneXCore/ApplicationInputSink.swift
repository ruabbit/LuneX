import Foundation

@MainActor
protocol ApplicationInputSink: Sendable {
    func sendRemoteInput(_ event: RemoteInputEvent) async throws
}
