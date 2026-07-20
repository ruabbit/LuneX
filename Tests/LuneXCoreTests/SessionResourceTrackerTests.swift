import Foundation
import XCTest

final class SessionResourceTrackerTests: XCTestCase {
    func testTeardownCancelsTasksAndStopsResourcesInReverseOrder() async throws {
        let tracker = SessionResourceTracker()
        let recorder = TeardownRecorder()
        let taskID = try await tracker.startTask(name: "receive-loop") {
            while !Task.isCancelled {
                try await Task.sleep(for: .milliseconds(1))
            }
        }
        _ = try await tracker.registerResource(kind: .networkChannel, name: "control") {
            await recorder.append("control")
        }
        _ = try await tracker.registerResource(kind: .decoder, name: "video-decoder") {
            await recorder.append("video-decoder")
        }

        let report = try await tracker.teardown(gracePeriod: .seconds(1))

        XCTAssertTrue(report.isClean)
        XCTAssertEqual(report.cancelledTaskCount, 1)
        XCTAssertEqual(report.stoppedResourceCount, 2)
        XCTAssertEqual(report.taskOutcomes[taskID], .cancelled)
        let shutdownOrder = await recorder.values
        XCTAssertEqual(shutdownOrder, ["video-decoder", "control"])
        let snapshot = await tracker.snapshot()
        XCTAssertEqual(snapshot.phase, .stopped)
        XCTAssertTrue(snapshot.activeTasks.isEmpty)
        XCTAssertTrue(snapshot.activeResources.isEmpty)
    }

    func testTeardownIsIdempotent() async throws {
        let tracker = SessionResourceTracker()
        let recorder = TeardownRecorder()
        _ = try await tracker.registerResource(kind: .audioGraph, name: "audio") {
            await recorder.append("audio")
        }

        let first = try await tracker.teardown()
        let second = try await tracker.teardown()

        XCTAssertEqual(first, second)
        let shutdownOrder = await recorder.values
        XCTAssertEqual(shutdownOrder, ["audio"])
    }

    func testCompletedTaskLeavesOutcomeWithoutActiveOwnership() async throws {
        let tracker = SessionResourceTracker()
        let taskID = try await tracker.startTask(name: "one-shot") {}

        for _ in 0..<100 {
            let snapshot = await tracker.snapshot()
            if snapshot.activeTasks.isEmpty {
                XCTAssertEqual(snapshot.taskOutcomes[taskID], .completed)
                return
            }
            try await Task.sleep(for: .milliseconds(1))
        }
        XCTFail("Task did not leave the tracker")
    }

    func testTrackerRejectsNewOwnershipAfterTeardown() async throws {
        let tracker = SessionResourceTracker()
        _ = try await tracker.teardown()

        do {
            _ = try await tracker.startTask(name: "late") {}
            XCTFail("Expected tracker to reject late task")
        } catch let error as SessionResourceTrackerError {
            XCTAssertEqual(error, .notAcceptingResources)
        }
    }

    func testTeardownReportsTaskThatIgnoresCancellationBudget() async throws {
        let tracker = SessionResourceTracker()
        _ = try await tracker.startTask(name: "non-cooperative") {
            await withCheckedContinuation { continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + 0.03) {
                    continuation.resume()
                }
            }
        }

        let report = try await tracker.teardown(gracePeriod: .zero)

        XCTAssertFalse(report.isClean)
        XCTAssertEqual(report.unfinishedTasks.map(\.name), ["non-cooperative"])
        try await Task.sleep(for: .milliseconds(40))
    }
}

private actor TeardownRecorder {
    private(set) var values: [String] = []

    func append(_ value: String) {
        values.append(value)
    }
}
