import Foundation

struct SessionOwnedResourceID: Hashable, Sendable {
    let rawValue: UUID

    init(rawValue: UUID = UUID()) {
        self.rawValue = rawValue
    }
}

enum SessionOwnedResourceKind: String, Equatable, Sendable {
    case task
    case networkChannel
    case decoder
    case renderer
    case audioGraph
    case inputQueue
    case timer
    case other
}

struct SessionOwnedResourceDescriptor: Equatable, Sendable {
    var id: SessionOwnedResourceID
    var kind: SessionOwnedResourceKind
    var name: String
}

enum SessionTrackedTaskOutcome: String, Equatable, Sendable {
    case completed
    case cancelled
    case failed
}

enum SessionResourceTrackerError: Error, Equatable, Sendable {
    case notAcceptingResources
    case invalidGracePeriod
}

struct SessionResourceTrackerSnapshot: Equatable, Sendable {
    enum Phase: String, Equatable, Sendable {
        case active
        case stopping
        case stopped
    }

    var phase: Phase
    var activeTasks: [SessionOwnedResourceDescriptor]
    var activeResources: [SessionOwnedResourceDescriptor]
    var taskOutcomes: [SessionOwnedResourceID: SessionTrackedTaskOutcome]
}

struct SessionTeardownReport: Equatable, Sendable {
    var cancelledTaskCount: Int
    var stoppedResourceCount: Int
    var unfinishedTasks: [SessionOwnedResourceDescriptor]
    var taskOutcomes: [SessionOwnedResourceID: SessionTrackedTaskOutcome]

    var isClean: Bool {
        unfinishedTasks.isEmpty
    }
}

actor SessionResourceTracker {
    private struct TrackedTask {
        var descriptor: SessionOwnedResourceDescriptor
        var task: Task<Void, Never>
    }

    private struct TrackedResource {
        var descriptor: SessionOwnedResourceDescriptor
        var shutdown: @Sendable () async -> Void
    }

    private var phase: SessionResourceTrackerSnapshot.Phase = .active
    private var tasks: [SessionOwnedResourceID: TrackedTask] = [:]
    private var resources: [SessionOwnedResourceID: TrackedResource] = [:]
    private var resourceOrder: [SessionOwnedResourceID] = []
    private var taskOutcomes: [SessionOwnedResourceID: SessionTrackedTaskOutcome] = [:]
    private var teardownReport: SessionTeardownReport?

    @discardableResult
    func startTask(
        name: String,
        operation: @escaping @Sendable () async throws -> Void
    ) throws -> SessionOwnedResourceID {
        guard phase == .active else {
            throw SessionResourceTrackerError.notAcceptingResources
        }

        let descriptor = SessionOwnedResourceDescriptor(
            id: SessionOwnedResourceID(),
            kind: .task,
            name: name
        )
        let task = Task { [weak self] in
            let outcome: SessionTrackedTaskOutcome
            do {
                try await operation()
                outcome = Task.isCancelled ? .cancelled : .completed
            } catch is CancellationError {
                outcome = .cancelled
            } catch {
                outcome = .failed
            }
            await self?.finishTask(id: descriptor.id, outcome: outcome)
        }
        tasks[descriptor.id] = TrackedTask(descriptor: descriptor, task: task)
        return descriptor.id
    }

    @discardableResult
    func registerResource(
        kind: SessionOwnedResourceKind,
        name: String,
        shutdown: @escaping @Sendable () async -> Void
    ) throws -> SessionOwnedResourceID {
        guard phase == .active else {
            throw SessionResourceTrackerError.notAcceptingResources
        }
        let descriptor = SessionOwnedResourceDescriptor(
            id: SessionOwnedResourceID(),
            kind: kind,
            name: name
        )
        resources[descriptor.id] = TrackedResource(
            descriptor: descriptor,
            shutdown: shutdown
        )
        resourceOrder.append(descriptor.id)
        return descriptor.id
    }

    func unregisterResource(id: SessionOwnedResourceID) {
        resources[id] = nil
        resourceOrder.removeAll { $0 == id }
    }

    func snapshot() -> SessionResourceTrackerSnapshot {
        SessionResourceTrackerSnapshot(
            phase: phase,
            activeTasks: tasks.values.map(\.descriptor).sorted(by: Self.sortDescriptors),
            activeResources: resources.values.map(\.descriptor).sorted(by: Self.sortDescriptors),
            taskOutcomes: taskOutcomes
        )
    }

    func teardown(
        gracePeriod: Duration = .seconds(2)
    ) async throws -> SessionTeardownReport {
        guard gracePeriod >= .zero else {
            throw SessionResourceTrackerError.invalidGracePeriod
        }
        if let teardownReport {
            return teardownReport
        }

        phase = .stopping
        let cancelledTaskCount = tasks.count
        for tracked in tasks.values {
            tracked.task.cancel()
        }

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: gracePeriod)
        while !tasks.isEmpty, clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(1))
        }

        let unfinishedTasks = tasks.values
            .map(\.descriptor)
            .sorted(by: Self.sortDescriptors)
        tasks.removeAll()

        var stoppedResourceCount = 0
        for id in resourceOrder.reversed() {
            guard let resource = resources.removeValue(forKey: id) else { continue }
            await resource.shutdown()
            stoppedResourceCount += 1
        }
        resourceOrder.removeAll()
        phase = .stopped

        let report = SessionTeardownReport(
            cancelledTaskCount: cancelledTaskCount,
            stoppedResourceCount: stoppedResourceCount,
            unfinishedTasks: unfinishedTasks,
            taskOutcomes: taskOutcomes
        )
        teardownReport = report
        return report
    }

    private func finishTask(
        id: SessionOwnedResourceID,
        outcome: SessionTrackedTaskOutcome
    ) {
        guard tasks.removeValue(forKey: id) != nil else { return }
        taskOutcomes[id] = outcome
    }

    private static func sortDescriptors(
        _ lhs: SessionOwnedResourceDescriptor,
        _ rhs: SessionOwnedResourceDescriptor
    ) -> Bool {
        if lhs.name != rhs.name {
            return lhs.name < rhs.name
        }
        return lhs.id.rawValue.uuidString < rhs.id.rawValue.uuidString
    }
}
