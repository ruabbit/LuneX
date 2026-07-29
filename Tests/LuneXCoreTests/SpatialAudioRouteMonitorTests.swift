import XCTest

final class SpatialAudioRouteMonitorTests: XCTestCase {
    func testStartPublishesInitialSemanticSnapshot() async throws {
        let reader = StubSpatialAudioRouteCapabilityReader(.supported)
        let source = StubSpatialAudioRouteEventSource()
        let monitor = try SpatialAudioRouteMonitor(
            initialRevision: .init(rawValue: 40),
            capabilityReader: reader,
            eventSource: source
        )

        let stream = monitor.start()
        var iterator = stream.makeAsyncIterator()
        let snapshot = await iterator.next()

        XCTAssertEqual(snapshot?.revision.rawValue, 40)
        XCTAssertEqual(snapshot?.trigger, .initial)
        XCTAssertEqual(snapshot?.state.route, .supported)
        XCTAssertEqual(snapshot?.state.interruption, .active)
        XCTAssertEqual(snapshot?.state.mediaServices, .available)
        XCTAssertEqual(snapshot?.route.revision.rawValue, 40)
        XCTAssertEqual(source.startCount, 1)
        monitor.stop()
    }

    func testRouteAndSpatialCapabilityChangesDeduplicateSemanticState() async throws {
        let reader = StubSpatialAudioRouteCapabilityReader(.supported)
        let source = StubSpatialAudioRouteEventSource()
        let monitor = try SpatialAudioRouteMonitor(
            capabilityReader: reader,
            eventSource: source
        )
        let stream = monitor.start()

        source.emit(.routeChanged)
        source.emit(.spatialPlaybackCapabilityChanged)
        reader.capability = .unsupported
        source.emit(.routeChanged)
        source.emit(.routeChanged)
        source.emit(.spatialPlaybackCapabilityChanged)
        monitor.stop()

        let snapshots = await collect(stream)
        XCTAssertEqual(snapshots.map(\.revision.rawValue), [0, 1])
        XCTAssertEqual(snapshots.last?.trigger, .routeChanged)
        XCTAssertEqual(snapshots.last?.state.route, .unsupported)
    }

    func testInterruptionAndMediaServiceTransitionsEmitOncePerState() async throws {
        let reader = StubSpatialAudioRouteCapabilityReader(.supported)
        let source = StubSpatialAudioRouteEventSource()
        let monitor = try SpatialAudioRouteMonitor(
            capabilityReader: reader,
            eventSource: source
        )
        let stream = monitor.start()

        source.emit(.interruptionBegan)
        source.emit(.interruptionBegan)
        source.emit(.interruptionEnded(shouldResume: true))
        source.emit(.interruptionEnded(shouldResume: false))
        source.emit(.mediaServicesLost)
        source.emit(.mediaServicesLost)
        reader.capability = .unsupported
        source.emit(.mediaServicesReset)
        source.emit(.mediaServicesReset)
        monitor.stop()

        let snapshots = await collect(stream)
        XCTAssertEqual(snapshots.map(\.revision.rawValue), [0, 1, 2, 3, 4])
        XCTAssertEqual(
            snapshots.map(\.trigger),
            [
                .initial,
                .interruptionBegan,
                .interruptionEnded(shouldResume: true),
                .mediaServicesLost,
                .mediaServicesReset,
            ]
        )
        XCTAssertEqual(snapshots[1].state.interruption, .interrupted)
        XCTAssertEqual(snapshots[2].state.interruption, .active)
        XCTAssertEqual(snapshots[3].state.mediaServices, .lost)
        XCTAssertEqual(snapshots[4].state.mediaServices, .reset)
        XCTAssertEqual(snapshots[4].state.route, .unsupported)
    }

    func testMediaServicesResetWithoutLostEmitsOneRecoveryRevision() async throws {
        let reader = StubSpatialAudioRouteCapabilityReader(.supported)
        let source = StubSpatialAudioRouteEventSource()
        let monitor = try SpatialAudioRouteMonitor(
            capabilityReader: reader,
            eventSource: source
        )
        let stream = monitor.start()

        source.emit(.mediaServicesReset)
        source.emit(.mediaServicesReset)
        monitor.stop()

        let snapshots = await collect(stream)
        XCTAssertEqual(snapshots.map(\.revision.rawValue), [0, 1])
        XCTAssertEqual(snapshots.last?.trigger, .mediaServicesReset)
        XCTAssertEqual(snapshots.last?.state.mediaServices, .reset)
    }

    func testRefreshReadsInjectedCapabilityWithoutRawNotificationData() async throws {
        let reader = StubSpatialAudioRouteCapabilityReader(.missing)
        let source = StubSpatialAudioRouteEventSource()
        let monitor = try SpatialAudioRouteMonitor(
            capabilityReader: reader,
            eventSource: source
        )
        let stream = monitor.start()

        reader.capability = .supported
        source.emit(.refresh)
        monitor.stop()

        let snapshots = await collect(stream)
        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots.last?.trigger, .refresh)
        XCTAssertEqual(snapshots.last?.state.route, .supported)
    }

    func testBufferingNewestKeepsOnlyConfiguredCapacity() async throws {
        let reader = StubSpatialAudioRouteCapabilityReader(.supported)
        let source = StubSpatialAudioRouteEventSource()
        let monitor = try SpatialAudioRouteMonitor(
            capacity: 2,
            capabilityReader: reader,
            eventSource: source
        )
        let stream = monitor.start()

        source.emit(.interruptionBegan)
        source.emit(.interruptionEnded(shouldResume: true))
        source.emit(.mediaServicesLost)
        source.emit(.mediaServicesReset)
        monitor.stop()

        let snapshots = await collect(stream)
        XCTAssertEqual(snapshots.map(\.revision.rawValue), [3, 4])
        XCTAssertEqual(
            snapshots.map(\.trigger),
            [.mediaServicesLost, .mediaServicesReset]
        )
    }

    func testStopFinishesStreamAndSuppressesLateCallback() async throws {
        let reader = StubSpatialAudioRouteCapabilityReader(.supported)
        let source = StubSpatialAudioRouteEventSource()
        let monitor = try SpatialAudioRouteMonitor(
            capabilityReader: reader,
            eventSource: source
        )
        let stream = monitor.start()

        monitor.stop()
        reader.capability = .unsupported
        source.emitLate(.routeChanged)

        let snapshots = await collect(stream)
        XCTAssertEqual(snapshots.map(\.revision.rawValue), [0])
        XCTAssertEqual(monitor.latestSnapshot?.state.route, .supported)
        XCTAssertEqual(source.stopCount, 1)
    }

    func testDeinitStopsSourceAndLateHandlerDoesNotRetainMonitor() throws {
        let reader = StubSpatialAudioRouteCapabilityReader(.supported)
        let source = StubSpatialAudioRouteEventSource()
        weak var weakMonitor: SpatialAudioRouteMonitor?

        do {
            let monitor = try SpatialAudioRouteMonitor(
                capabilityReader: reader,
                eventSource: source
            )
            weakMonitor = monitor
            _ = monitor.start()
        }

        XCTAssertNil(weakMonitor)
        XCTAssertEqual(source.stopCount, 1)
        source.emitLate(.mediaServicesLost)
    }

    func testInvalidCapacityAndRevisionExhaustionFailClosed() async throws {
        let reader = StubSpatialAudioRouteCapabilityReader(.supported)
        let source = StubSpatialAudioRouteEventSource()

        for capacity in [0, SpatialAudioRouteMonitor.maximumCapacity + 1] {
            XCTAssertThrowsError(
                try SpatialAudioRouteMonitor(
                    capacity: capacity,
                    capabilityReader: reader,
                    eventSource: source
                )
            ) {
                XCTAssertEqual(
                    $0 as? SpatialAudioRouteMonitorError,
                    .invalidCapacity(capacity)
                )
            }
        }

        let monitor = try SpatialAudioRouteMonitor(
            initialRevision: .init(rawValue: UInt64.max),
            capabilityReader: reader,
            eventSource: source
        )
        let stream = monitor.start()
        source.emit(.interruptionBegan)
        monitor.stop()

        let snapshots = await collect(stream)
        XCTAssertEqual(snapshots.map(\.revision.rawValue), [UInt64.max])
        XCTAssertTrue(monitor.isRevisionExhausted)
    }
}

private extension SpatialAudioRouteCapabilityState {
    static let supported = SpatialAudioRouteCapabilityState(
        outputAvailable: true,
        systemSpatialSupport: .supported,
        currentOutputChannelCount: 8,
        maximumOutputChannelCount: 8
    )
    static let unsupported = SpatialAudioRouteCapabilityState(
        outputAvailable: true,
        systemSpatialSupport: .unsupported,
        currentOutputChannelCount: 2,
        maximumOutputChannelCount: 2
    )
    static let missing = SpatialAudioRouteCapabilityState(
        outputAvailable: false,
        systemSpatialSupport: .unknown,
        currentOutputChannelCount: 0,
        maximumOutputChannelCount: 0
    )
}

private final class StubSpatialAudioRouteCapabilityReader:
    SpatialAudioRouteCapabilityReading,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var storedCapability: SpatialAudioRouteCapabilityState

    init(_ capability: SpatialAudioRouteCapabilityState) {
        storedCapability = capability
    }

    var capability: SpatialAudioRouteCapabilityState {
        get { lock.withLock { storedCapability } }
        set { lock.withLock { storedCapability = newValue } }
    }

    func currentRouteCapability() -> SpatialAudioRouteCapabilityState {
        capability
    }
}

private final class StubSpatialAudioRouteEventSource:
    SpatialAudioRouteMonitorEventSourcing,
    @unchecked Sendable
{
    private let lock = NSLock()
    private var activeHandler:
        (@Sendable (SpatialAudioRouteMonitorEvent) -> Void)?
    private var retainedHandler:
        (@Sendable (SpatialAudioRouteMonitorEvent) -> Void)?
    private(set) var startCount = 0
    private(set) var stopCount = 0

    func start(
        handler: @escaping @Sendable (SpatialAudioRouteMonitorEvent) -> Void
    ) {
        lock.withLock {
            startCount += 1
            activeHandler = handler
            retainedHandler = handler
        }
    }

    func stop() {
        lock.withLock {
            guard activeHandler != nil else { return }
            stopCount += 1
            activeHandler = nil
        }
    }

    func emit(_ event: SpatialAudioRouteMonitorEvent) {
        let handler = lock.withLock { activeHandler }
        handler?(event)
    }

    func emitLate(_ event: SpatialAudioRouteMonitorEvent) {
        let handler = lock.withLock { retainedHandler }
        handler?(event)
    }
}

private func collect<Element: Sendable>(
    _ stream: AsyncStream<Element>
) async -> [Element] {
    var elements: [Element] = []
    for await element in stream {
        elements.append(element)
    }
    return elements
}
