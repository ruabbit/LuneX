import XCTest

@MainActor
final class MacSessionInputCoordinatorTests: XCTestCase {
    func testSingleConsumerPreservesFIFOAndEnqueueTimeCoordinates() async throws {
        let sink = ControlledApplicationInputSink(blockFirstSend: true)
        let coordinator = MacSessionInputCoordinator(
            sink: sink,
            policy: try MacSessionInputQueuePolicy(maximumPendingSamples: 8)
        )
        let generation = await coordinator.activate()
        let first = envelope(
            .keyboard(MacKeyboardSample(
                rawKeyCode: 0,
                characters: "a",
                isDown: true,
                modifiers: [],
                isRepeat: false
            )),
            snapshot: snapshot(revision: 1, sourceWidth: 100)
        )
        let oldGeometry = envelope(
            .pointerMove(MacPointerSample(
                localPoint: RemotePoint(x: 50, y: 50),
                deltaX: 0,
                deltaY: 0,
                buttons: []
            )),
            snapshot: snapshot(revision: 2, sourceWidth: 100)
        )
        let newGeometry = envelope(
            .pointerMove(MacPointerSample(
                localPoint: RemotePoint(x: 50, y: 50),
                deltaX: 0,
                deltaY: 0,
                buttons: []
            )),
            snapshot: snapshot(revision: 3, sourceWidth: 200)
        )

        XCTAssertEqual(coordinator.enqueue(first, generation: generation), .accepted)
        await waitUntil { coordinator.snapshot().hasInFlightSample }
        XCTAssertEqual(coordinator.enqueue(oldGeometry, generation: generation), .accepted)
        XCTAssertEqual(coordinator.enqueue(newGeometry, generation: generation), .accepted)
        sink.resumeFirstSend()
        await waitUntil { coordinator.snapshot().deliveredEventCount == 3 }

        XCTAssertEqual(sink.events, [
            .keyboard(KeyboardInputEvent(
                rawKeyCode: 0x41,
                characters: "a",
                isDown: true,
                modifiers: [],
                isRepeat: false
            )),
            .pointer(.absoluteMove(
                point: RemotePoint(x: 50, y: 50),
                referenceSize: PixelSize(width: 100, height: 100),
                buttons: []
            )),
            .pointer(.absoluteMove(
                point: RemotePoint(x: 100, y: 50),
                referenceSize: PixelSize(width: 200, height: 100),
                buttons: []
            ))
        ])
        XCTAssertEqual(coordinator.snapshot().queuedSampleCount, 0)
    }

    func testOutstandingCapacityIncludesInFlightAndRejectsStaleGeneration() async throws {
        let sink = ControlledApplicationInputSink(blockFirstSend: true)
        let coordinator = MacSessionInputCoordinator(
            sink: sink,
            policy: try MacSessionInputQueuePolicy(maximumPendingSamples: 2)
        )
        let firstGeneration = await coordinator.activate()
        let sample = envelope(
            .keyboard(MacKeyboardSample(
                rawKeyCode: 11,
                characters: "b",
                isDown: true,
                modifiers: [],
                isRepeat: false
            )),
            snapshot: snapshot(revision: 1, sourceWidth: 100)
        )

        XCTAssertEqual(coordinator.enqueue(sample, generation: firstGeneration), .accepted)
        await waitUntil { coordinator.snapshot().hasInFlightSample }
        XCTAssertEqual(coordinator.enqueue(sample, generation: firstGeneration), .accepted)
        XCTAssertEqual(
            coordinator.enqueue(sample, generation: firstGeneration),
            .rejected(.capacityExceeded(limit: 2))
        )
        sink.resumeFirstSend()
        await waitUntil { coordinator.snapshot().deliveredEventCount == 2 }

        let replacementGeneration = await coordinator.activate()
        XCTAssertEqual(
            coordinator.enqueue(sample, generation: firstGeneration),
            .rejected(.staleGeneration)
        )
        XCTAssertEqual(
            coordinator.enqueue(sample, generation: replacementGeneration),
            .accepted
        )
        await waitUntil { coordinator.snapshot().deliveredEventCount == 1 }
    }

    func testReservedAndOutOfVideoSamplesNeverReachApplicationSink() async throws {
        let sink = ControlledApplicationInputSink()
        let coordinator = MacSessionInputCoordinator(sink: sink)
        let generation = await coordinator.activate()
        let commandQ = envelope(
            .keyboard(MacKeyboardSample(
                rawKeyCode: 12,
                characters: "q",
                isDown: true,
                modifiers: [.command],
                isRepeat: false
            )),
            snapshot: snapshot(revision: 1, sourceWidth: 100)
        )
        let letterbox = envelope(
            .pointerMove(MacPointerSample(
                localPoint: RemotePoint(x: 5, y: 50),
                deltaX: 0,
                deltaY: 0,
                buttons: []
            )),
            snapshot: fitSnapshotWithSideLetterbox()
        )

        XCTAssertEqual(coordinator.enqueue(commandQ, generation: generation), .accepted)
        XCTAssertEqual(coordinator.enqueue(letterbox, generation: generation), .accepted)
        await waitUntil {
            let state = coordinator.snapshot()
            return state.reservedSampleCount == 1 && state.droppedSampleCount == 1
        }
        XCTAssertEqual(sink.events, [])
        XCTAssertEqual(coordinator.snapshot().deliveredEventCount, 0)
    }

    func testFocusLossClosesAdmissionAndReleasesAfterAcceptedFIFO() async throws {
        let sink = ControlledApplicationInputSink(blockFirstSend: true)
        let coordinator = MacSessionInputCoordinator(
            sink: sink,
            policy: try MacSessionInputQueuePolicy(maximumPendingSamples: 4)
        )
        let generation = await coordinator.activate()
        let keyDown = envelope(
            .keyboard(MacKeyboardSample(
                rawKeyCode: 8,
                characters: "c",
                isDown: true,
                modifiers: [],
                isRepeat: false
            )),
            snapshot: snapshot(revision: 1, sourceWidth: 100)
        )
        let buttonDown = envelope(
            .button(
                button: .left,
                isDown: true,
                localPoint: RemotePoint(x: 50, y: 50)
            ),
            snapshot: snapshot(revision: 1, sourceWidth: 100)
        )

        XCTAssertEqual(coordinator.enqueue(keyDown, generation: generation), .accepted)
        await waitUntil { coordinator.snapshot().hasInFlightSample }
        XCTAssertEqual(coordinator.enqueue(buttonDown, generation: generation), .accepted)
        XCTAssertEqual(
            coordinator.setFocusEligible(false, generation: generation),
            .applied
        )
        XCTAssertEqual(
            coordinator.setFocusEligible(false, generation: generation),
            .applied
        )
        XCTAssertEqual(
            coordinator.enqueue(keyDown, generation: generation),
            .rejected(.admissionClosed)
        )
        sink.resumeFirstSend()
        await waitUntil {
            coordinator.snapshot().completedReleaseBarrierCount == 1
        }

        XCTAssertEqual(sink.operations, [
            .event(.keyboard(KeyboardInputEvent(
                rawKeyCode: 0x43,
                characters: "c",
                isDown: true,
                modifiers: [],
                isRepeat: false
            ))),
            .event(.pointer(.button(
                button: .left,
                isDown: true,
                point: RemotePoint(x: 50, y: 50)
            ))),
            .release
        ])
        XCTAssertFalse(coordinator.snapshot().acceptsInput)
        XCTAssertEqual(sink.releaseCallCount, 1)
    }

    func testFocusRegainWaitsForInFlightReleaseBarrier() async throws {
        let sink = ControlledApplicationInputSink(blockRelease: true)
        let coordinator = MacSessionInputCoordinator(sink: sink)
        let generation = await coordinator.activate()
        let sample = envelope(
            .keyboard(MacKeyboardSample(
                rawKeyCode: 7,
                characters: "x",
                isDown: true,
                modifiers: [],
                isRepeat: false
            )),
            snapshot: snapshot(revision: 1, sourceWidth: 100)
        )

        XCTAssertEqual(
            coordinator.setFocusEligible(false, generation: generation),
            .applied
        )
        await waitUntil { coordinator.snapshot().hasInFlightReleaseBarrier }
        XCTAssertEqual(
            coordinator.setFocusEligible(true, generation: generation),
            .applied
        )
        XCTAssertFalse(coordinator.snapshot().acceptsInput)
        XCTAssertEqual(
            coordinator.enqueue(sample, generation: generation),
            .rejected(.admissionClosed)
        )

        sink.resumeRelease()
        await waitUntil { coordinator.snapshot().acceptsInput }
        XCTAssertEqual(coordinator.enqueue(sample, generation: generation), .accepted)
        await waitUntil { coordinator.snapshot().deliveredEventCount == 1 }
        XCTAssertEqual(sink.releaseCallCount, 1)
    }

    func testReplacementGenerationIsUnaffectedByOldFocusRelease() async throws {
        let sink = ControlledApplicationInputSink(blockRelease: true)
        let coordinator = MacSessionInputCoordinator(sink: sink)
        let firstGeneration = await coordinator.activate()
        XCTAssertEqual(
            coordinator.setFocusEligible(false, generation: firstGeneration),
            .applied
        )
        await waitUntil { coordinator.snapshot().hasInFlightReleaseBarrier }

        let replacement = Task { await coordinator.activate() }
        for _ in 0..<20 { await Task.yield() }
        XCTAssertTrue(coordinator.snapshot().hasInFlightReleaseBarrier)
        sink.resumeRelease()
        let replacementGeneration = await replacement.value
        XCTAssertEqual(
            coordinator.setFocusEligible(false, generation: firstGeneration),
            .staleGeneration
        )
        XCTAssertTrue(coordinator.snapshot().acceptsInput)
        for _ in 0..<20 { await Task.yield() }

        let state = coordinator.snapshot()
        XCTAssertEqual(state.generation, replacementGeneration)
        XCTAssertTrue(state.acceptsInput)
        XCTAssertEqual(state.completedReleaseBarrierCount, 0)
        XCTAssertEqual(state.releaseBarrierFailureCount, 0)
        XCTAssertEqual(sink.releaseCallCount, 1)
    }

    func testReleaseFailureKeepsAdmissionClosed() async throws {
        let sink = ControlledApplicationInputSink(failsRelease: true)
        let coordinator = MacSessionInputCoordinator(sink: sink)
        let generation = await coordinator.activate()
        XCTAssertEqual(
            coordinator.setFocusEligible(false, generation: generation),
            .applied
        )
        XCTAssertEqual(
            coordinator.setFocusEligible(true, generation: generation),
            .applied
        )
        await waitUntil { coordinator.snapshot().releaseBarrierFailureCount == 1 }

        XCTAssertFalse(coordinator.snapshot().acceptsInput)
        XCTAssertEqual(coordinator.snapshot().completedReleaseBarrierCount, 0)
        XCTAssertEqual(sink.releaseCallCount, 1)
    }

    func testTerminalTriggersShareCleanupAndWaitForInFlightDelivery() async throws {
        let sink = ControlledApplicationInputSink(blockFirstSend: true)
        let cleanup = CaptureCleanupRecorder()
        let coordinator = MacSessionInputCoordinator(
            sink: sink,
            releaseCapture: { cleanup.releaseCapture() }
        )
        let generation = await coordinator.activate()
        let sample = envelope(
            .keyboard(MacKeyboardSample(
                rawKeyCode: 9,
                characters: "v",
                isDown: true,
                modifiers: [],
                isRepeat: false
            )),
            snapshot: snapshot(revision: 1, sourceWidth: 100)
        )
        XCTAssertEqual(coordinator.enqueue(sample, generation: generation), .accepted)
        await waitUntil { coordinator.snapshot().hasInFlightSample }
        XCTAssertEqual(coordinator.enqueue(sample, generation: generation), .accepted)

        let stop = Task {
            await coordinator.terminate(generation: generation, reason: .stop)
        }
        await waitUntil { coordinator.snapshot().terminationReason == .stop }
        let remote = Task {
            await coordinator.terminate(
                generation: generation,
                reason: .remoteTermination
            )
        }
        await waitUntil {
            let state = coordinator.snapshot()
            return state.terminationReason == .stop
                && state.queuedSampleCount == 0
        }
        XCTAssertFalse(coordinator.snapshot().acceptsInput)
        XCTAssertEqual(coordinator.snapshot().captureCleanupCount, 1)
        XCTAssertEqual(cleanup.releaseCount, 1)
        XCTAssertEqual(
            coordinator.setFocusEligible(true, generation: generation),
            .terminationInProgress
        )
        XCTAssertEqual(
            coordinator.enqueue(sample, generation: generation),
            .rejected(.admissionClosed)
        )

        sink.resumeFirstSend()
        let stopResult = await stop.value
        let remoteResult = await remote.value
        XCTAssertEqual(stopResult, .completed)
        XCTAssertEqual(remoteResult, .completed)
        XCTAssertNil(coordinator.snapshot().generation)
        XCTAssertEqual(sink.events.count, 1)
        XCTAssertEqual(sink.releaseCallCount, 1)
        XCTAssertEqual(cleanup.releaseCount, 1)
    }

    func testSendFailureClosesGenerationBeforeReplacement() async throws {
        let sink = ControlledApplicationInputSink(failsSend: true)
        let cleanup = CaptureCleanupRecorder()
        let coordinator = MacSessionInputCoordinator(
            sink: sink,
            releaseCapture: { cleanup.releaseCapture() }
        )
        let firstGeneration = await coordinator.activate()
        let sample = envelope(
            .keyboard(MacKeyboardSample(
                rawKeyCode: 3,
                characters: "f",
                isDown: true,
                modifiers: [],
                isRepeat: false
            )),
            snapshot: snapshot(revision: 1, sourceWidth: 100)
        )
        XCTAssertEqual(coordinator.enqueue(sample, generation: firstGeneration), .accepted)
        await waitUntil { coordinator.snapshot().terminationReason == .sendFailure }

        XCTAssertFalse(coordinator.snapshot().acceptsInput)
        XCTAssertEqual(coordinator.snapshot().deliveryFailureCount, 1)
        XCTAssertEqual(coordinator.snapshot().captureCleanupCount, 1)
        XCTAssertEqual(cleanup.releaseCount, 1)
        XCTAssertEqual(sink.releaseCallCount, 0)

        let replacementGeneration = await coordinator.activate()
        XCTAssertNotEqual(replacementGeneration, firstGeneration)
        XCTAssertTrue(coordinator.snapshot().acceptsInput)
        XCTAssertNil(coordinator.snapshot().terminationReason)
        XCTAssertEqual(cleanup.releaseCount, 1)
    }

    func testConcurrentReplacementActivationSharesOneGeneration() async throws {
        let sink = ControlledApplicationInputSink(blockRelease: true)
        let coordinator = MacSessionInputCoordinator(sink: sink)
        let firstGeneration = await coordinator.activate()

        let firstReplacement = Task { await coordinator.activate() }
        await waitUntil { coordinator.snapshot().hasInFlightReleaseBarrier }
        let secondReplacement = Task { await coordinator.activate() }
        for _ in 0..<20 { await Task.yield() }
        sink.resumeRelease()

        let firstResult = await firstReplacement.value
        let secondResult = await secondReplacement.value
        XCTAssertNotEqual(firstResult, firstGeneration)
        XCTAssertEqual(firstResult, secondResult)
        XCTAssertEqual(coordinator.snapshot().generation, firstResult)
        XCTAssertTrue(coordinator.snapshot().acceptsInput)
        XCTAssertEqual(sink.releaseCallCount, 1)
    }

    func testEveryExternalTerminalReasonReleasesAndCleansExactlyOnce() async throws {
        let reasons: [MacSessionInputTerminationReason] = [
            .inputChannelFailure,
            .stop,
            .remoteTermination,
            .detached
        ]
        for reason in reasons {
            let sink = ControlledApplicationInputSink()
            let cleanup = CaptureCleanupRecorder()
            let coordinator = MacSessionInputCoordinator(
                sink: sink,
                releaseCapture: { cleanup.releaseCapture() }
            )
            let generation = await coordinator.activate()
            let result = await coordinator.terminate(
                generation: generation,
                reason: reason
            )

            XCTAssertEqual(
                result,
                .completed,
                "Failed terminal reason: \(reason)"
            )
            XCTAssertNil(coordinator.snapshot().generation)
            XCTAssertEqual(sink.releaseCallCount, 1)
            XCTAssertEqual(cleanup.releaseCount, 1)
        }
    }

    func testFocusBarrierBypassesFullOutstandingCapacity() async throws {
        let sink = ControlledApplicationInputSink(blockFirstSend: true)
        let coordinator = MacSessionInputCoordinator(
            sink: sink,
            policy: try MacSessionInputQueuePolicy(maximumPendingSamples: 1)
        )
        let generation = await coordinator.activate()
        let sample = envelope(
            .keyboard(MacKeyboardSample(
                rawKeyCode: 11,
                characters: "b",
                isDown: true,
                modifiers: [],
                isRepeat: false
            )),
            snapshot: snapshot(revision: 1, sourceWidth: 100)
        )
        XCTAssertEqual(coordinator.enqueue(sample, generation: generation), .accepted)
        await waitUntil { coordinator.snapshot().hasInFlightSample }
        XCTAssertEqual(
            coordinator.setFocusEligible(false, generation: generation),
            .applied
        )
        XCTAssertTrue(coordinator.snapshot().hasPendingReleaseBarrier)
        XCTAssertEqual(
            coordinator.enqueue(sample, generation: generation),
            .rejected(.admissionClosed)
        )

        sink.resumeFirstSend()
        await waitUntil {
            coordinator.snapshot().completedReleaseBarrierCount == 1
        }
        XCTAssertEqual(sink.operations.count, 2)
        XCTAssertEqual(sink.operations.last, .release)
    }

    func testTerminalReleaseFailureStillCompletesCleanup() async throws {
        let sink = ControlledApplicationInputSink(failsRelease: true)
        let cleanup = CaptureCleanupRecorder()
        let coordinator = MacSessionInputCoordinator(
            sink: sink,
            releaseCapture: { cleanup.releaseCapture() }
        )
        let generation = await coordinator.activate()

        let result = await coordinator.terminate(
            generation: generation,
            reason: .inputChannelFailure
        )
        XCTAssertEqual(result, .completed)
        XCTAssertNil(coordinator.snapshot().generation)
        XCTAssertEqual(coordinator.snapshot().releaseBarrierFailureCount, 1)
        XCTAssertEqual(sink.releaseCallCount, 1)
        XCTAssertEqual(cleanup.releaseCount, 1)
    }

    func testStaleAndInactiveTerminationCannotAffectReplacement() async throws {
        let sink = ControlledApplicationInputSink()
        let cleanup = CaptureCleanupRecorder()
        let coordinator = MacSessionInputCoordinator(
            sink: sink,
            releaseCapture: { cleanup.releaseCapture() }
        )
        let firstGeneration = await coordinator.activate()
        let replacementGeneration = await coordinator.activate()
        let releaseCount = sink.releaseCallCount
        let cleanupCount = cleanup.releaseCount

        let staleResult = await coordinator.terminate(
            generation: firstGeneration,
            reason: .remoteTermination
        )
        XCTAssertEqual(staleResult, .staleGeneration)
        XCTAssertEqual(coordinator.snapshot().generation, replacementGeneration)
        XCTAssertTrue(coordinator.snapshot().acceptsInput)
        XCTAssertEqual(sink.releaseCallCount, releaseCount)
        XCTAssertEqual(cleanup.releaseCount, cleanupCount)

        let deactivated = await coordinator.deactivate(
            generation: replacementGeneration
        )
        XCTAssertTrue(deactivated)
        let inactiveResult = await coordinator.terminate(
            generation: replacementGeneration,
            reason: .detached
        )
        XCTAssertEqual(inactiveResult, .inactiveGeneration)
        XCTAssertEqual(sink.releaseCallCount, releaseCount + 1)
        XCTAssertEqual(cleanup.releaseCount, cleanupCount + 1)
    }

    func testQueuePolicyRejectsUnsafeCapacities() {
        XCTAssertThrowsError(try MacSessionInputQueuePolicy(maximumPendingSamples: 0))
        XCTAssertThrowsError(try MacSessionInputQueuePolicy(maximumPendingSamples: 4_097))
    }

    private func envelope(
        _ sample: MacPlatformInputSample,
        snapshot: StreamCoordinateSnapshot
    ) -> MacInputSampleEnvelope {
        MacInputSampleEnvelope(
            sample: sample,
            coordinateSnapshot: snapshot,
            cursorPolicy: CursorCapturePolicy(
                hidesSystemCursor: false,
                capturesRelativePointer: false,
                usesRemotePointer: false,
                reason: nil
            ),
            forwardsSystemShortcuts: false
        )
    }

    private func snapshot(
        revision: UInt64,
        sourceWidth: Int
    ) -> StreamCoordinateSnapshot {
        StreamCoordinateSnapshot.resolve(
            revision: revision,
            sourceSize: PixelSize(width: sourceWidth, height: 100),
            drawableSize: PixelSize(width: 100, height: 100),
            mode: .fill
        )!
    }

    private func fitSnapshotWithSideLetterbox() -> StreamCoordinateSnapshot {
        StreamCoordinateSnapshot.resolve(
            revision: 4,
            sourceSize: PixelSize(width: 100, height: 100),
            drawableSize: PixelSize(width: 200, height: 100),
            mode: .fit
        )!
    }

    private func waitUntil(
        _ condition: @escaping @MainActor () -> Bool
    ) async {
        for _ in 0..<200 where !condition() {
            await Task.yield()
        }
        XCTAssertTrue(condition())
    }
}

@MainActor
private final class ControlledApplicationInputSink: ApplicationInputSink {
    enum Operation: Equatable {
        case event(RemoteInputEvent)
        case release
    }

    private(set) var events: [RemoteInputEvent] = []
    private(set) var operations: [Operation] = []
    private(set) var releaseCallCount = 0
    private var shouldBlockFirstSend: Bool
    private var shouldBlockRelease: Bool
    private let failsSend: Bool
    private let failsRelease: Bool
    private var firstSendContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    init(
        blockFirstSend: Bool = false,
        blockRelease: Bool = false,
        failsSend: Bool = false,
        failsRelease: Bool = false
    ) {
        shouldBlockFirstSend = blockFirstSend
        shouldBlockRelease = blockRelease
        self.failsSend = failsSend
        self.failsRelease = failsRelease
    }

    func sendRemoteInput(_ event: RemoteInputEvent) async throws {
        events.append(event)
        operations.append(.event(event))
        if shouldBlockFirstSend {
            shouldBlockFirstSend = false
            await withCheckedContinuation { continuation in
                firstSendContinuation = continuation
            }
        }
        if failsSend {
            throw SessionMediaEnvironmentError.inputUnavailable
        }
    }

    func releaseRemoteInput() async throws {
        releaseCallCount += 1
        operations.append(.release)
        if shouldBlockRelease {
            shouldBlockRelease = false
            await withCheckedContinuation { continuation in
                releaseContinuation = continuation
            }
        }
        if failsRelease {
            throw SessionMediaEnvironmentError.inputUnavailable
        }
    }

    func resumeFirstSend() {
        firstSendContinuation?.resume()
        firstSendContinuation = nil
    }

    func resumeRelease() {
        releaseContinuation?.resume()
        releaseContinuation = nil
    }
}

@MainActor
private final class CaptureCleanupRecorder {
    private(set) var releaseCount = 0

    func releaseCapture() {
        releaseCount += 1
    }
}
