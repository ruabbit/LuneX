import Foundation

enum SessionControlTeardownTrigger: String, Equatable, Sendable {
    case localStop
    case streamCancellation
    case replacement
    case remoteTermination
    case failure
}

enum SessionRemoteCancelResult: String, Equatable, Sendable {
    case notRequested
    case succeeded
    case failed
}

struct SessionControlTeardownReport: Equatable, Sendable {
    var trigger: SessionControlTeardownTrigger
    var stoppedLocalResourceCount: Int
    var remoteCancelResult: SessionRemoteCancelResult

    var releasedLocalResources: Bool {
        stoppedLocalResourceCount == 2
    }
}

struct SessionControlTeardownSnapshot: Equatable, Sendable {
    var requestCount: Int
    var executionCount: Int
    var report: SessionControlTeardownReport?
}

actor SessionControlTeardownCoordinator {
    private let launchClient: any StreamLaunchClient
    private let connection: any RTSPConnectionExecuting
    private let controlChannel: any MoonlightControlChannelManaging
    private let request: StreamLaunchRequest

    private var requestCount = 0
    private var executionCount = 0
    private var operation: Task<SessionControlTeardownReport, Never>?
    private var report: SessionControlTeardownReport?

    init(
        launchClient: any StreamLaunchClient,
        connection: any RTSPConnectionExecuting,
        controlChannel: any MoonlightControlChannelManaging,
        request: StreamLaunchRequest
    ) {
        self.launchClient = launchClient
        self.connection = connection
        self.controlChannel = controlChannel
        self.request = request
    }

    func teardown(
        trigger: SessionControlTeardownTrigger,
        cancelRemoteSession: Bool
    ) async -> SessionControlTeardownReport {
        requestCount += 1
        if let operation {
            return await operation.value
        }

        executionCount += 1
        let operation = Task.detached { [launchClient, connection, controlChannel, request] in
            await controlChannel.stop()
            await connection.cancel()

            let remoteCancelResult: SessionRemoteCancelResult
            if cancelRemoteSession {
                do {
                    try await launchClient.stop(
                        host: request.host,
                        clientUniqueID: request.clientUniqueID
                    )
                    remoteCancelResult = .succeeded
                } catch {
                    remoteCancelResult = .failed
                }
            } else {
                remoteCancelResult = .notRequested
            }

            return SessionControlTeardownReport(
                trigger: trigger,
                stoppedLocalResourceCount: 2,
                remoteCancelResult: remoteCancelResult
            )
        }
        self.operation = operation
        let report = await operation.value
        self.report = report
        return report
    }

    func snapshot() -> SessionControlTeardownSnapshot {
        SessionControlTeardownSnapshot(
            requestCount: requestCount,
            executionCount: executionCount,
            report: report
        )
    }
}
