import XCTest

@MainActor
final class MacSessionInputCoordinatorTests: XCTestCase {
    func testSingleConsumerPreservesFIFOAndEnqueueTimeCoordinates() async throws {
        let sink = ControlledApplicationInputSink(blockFirstSend: true)
        let coordinator = MacSessionInputCoordinator(
            sink: sink,
            policy: try MacSessionInputQueuePolicy(maximumPendingSamples: 8)
        )
        let generation = coordinator.activate()
        let first = envelope(
            .keyboard(MacKeyboardSample(
                rawKeyCode: 4,
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
                rawKeyCode: 4,
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
        let firstGeneration = coordinator.activate()
        let sample = envelope(
            .keyboard(MacKeyboardSample(
                rawKeyCode: 5,
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

        let replacementGeneration = coordinator.activate()
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
        let generation = coordinator.activate()
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
        let generation = coordinator.activate()
        let keyDown = envelope(
            .keyboard(MacKeyboardSample(
                rawKeyCode: 6,
                characters: "c",
                isDown: true,
                modifiers: [],
                isRepeat: false
            )),
            snapshot: snapshot(revision: 1, sourceWidth: 100)
        )
        let buttonDown = envelope(
            .button(button: .left, isDown: true, localPoint: nil),
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
                rawKeyCode: 6,
                characters: "c",
                isDown: true,
                modifiers: [],
                isRepeat: false
            ))),
            .event(.pointer(.button(
                button: .left,
                isDown: true,
                point: nil
            ))),
            .release
        ])
        XCTAssertFalse(coordinator.snapshot().acceptsInput)
        XCTAssertEqual(sink.releaseCallCount, 1)
    }

    func testFocusRegainWaitsForInFlightReleaseBarrier() async throws {
        let sink = ControlledApplicationInputSink(blockRelease: true)
        let coordinator = MacSessionInputCoordinator(sink: sink)
        let generation = coordinator.activate()
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
        let firstGeneration = coordinator.activate()
        XCTAssertEqual(
            coordinator.setFocusEligible(false, generation: firstGeneration),
            .applied
        )
        await waitUntil { coordinator.snapshot().hasInFlightReleaseBarrier }

        let replacementGeneration = coordinator.activate()
        XCTAssertEqual(
            coordinator.setFocusEligible(false, generation: firstGeneration),
            .staleGeneration
        )
        XCTAssertTrue(coordinator.snapshot().acceptsInput)
        sink.resumeRelease()
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
        let generation = coordinator.activate()
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
    private let failsRelease: Bool
    private var firstSendContinuation: CheckedContinuation<Void, Never>?
    private var releaseContinuation: CheckedContinuation<Void, Never>?

    init(
        blockFirstSend: Bool = false,
        blockRelease: Bool = false,
        failsRelease: Bool = false
    ) {
        shouldBlockFirstSend = blockFirstSend
        shouldBlockRelease = blockRelease
        self.failsRelease = failsRelease
    }

    func sendRemoteInput(_ event: RemoteInputEvent) async throws {
        events.append(event)
        operations.append(.event(event))
        guard shouldBlockFirstSend else { return }
        shouldBlockFirstSend = false
        await withCheckedContinuation { continuation in
            firstSendContinuation = continuation
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
