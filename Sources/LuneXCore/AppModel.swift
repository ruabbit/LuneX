import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    var hosts: [MoonlightHost] = []
    var settings = AppSettings.defaults
    var session = StreamingSessionState()
    var renderState = StreamRenderState()
    var diagnostics = DiagnosticsStore()
    private let hostLibraryManager = HostLibraryManager(
        repository: InMemoryHostRepository(),
        serverInfoClient: HTTPServerInfoClient()
    )

    func loadHosts() async {
        do {
            hosts = try await hostLibraryManager.loadHosts()
            diagnostics.record("Loaded \(hosts.count) saved hosts")
        } catch {
            diagnostics.record("Failed to load hosts: \(error)")
        }
    }

    func addManualHost(name: String? = nil, address: String) async {
        do {
            hosts = try await hostLibraryManager.addManualHost(name: name, address: address)
            diagnostics.record("Added host \(address)")
        } catch {
            diagnostics.record("Failed to add host \(address): \(error)")
        }
    }

    func toggleDemoSession() {
        if session.isStreaming {
            session.phase = .disconnected
            renderState.policy = .idle
            diagnostics.record("Stopped demo stream")
        } else {
            session.phase = .streaming
            renderState.policy = .active
            renderState.transform.sourceSize = PixelSize(width: settings.stream.width, height: settings.stream.height)
            renderState.transform.mode = settings.stream.scaleMode
            diagnostics.record("Started demo stream")
        }
    }
}
