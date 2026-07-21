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
    private(set) var events: [RemoteInputEvent] = []
    private var shouldBlockFirstSend: Bool
    private var firstSendContinuation: CheckedContinuation<Void, Never>?

    init(blockFirstSend: Bool = false) {
        shouldBlockFirstSend = blockFirstSend
    }

    func sendRemoteInput(_ event: RemoteInputEvent) async throws {
        events.append(event)
        guard shouldBlockFirstSend else { return }
        shouldBlockFirstSend = false
        await withCheckedContinuation { continuation in
            firstSendContinuation = continuation
        }
    }

    func resumeFirstSend() {
        firstSendContinuation?.resume()
        firstSendContinuation = nil
    }
}
