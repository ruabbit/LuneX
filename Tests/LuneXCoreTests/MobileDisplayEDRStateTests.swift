import XCTest

final class MobileDisplayEDRStateTests: XCTestCase {
    @MainActor
    func testWindowReaderUsesResolvedActualScreenForEDRState() throws {
        let attachedScreen = MobileDisplayEDRTestScreen(
            potential: 4,
            current: 2.5
        )
        let unrelatedScreen = MobileDisplayEDRTestScreen(
            potential: 8,
            current: 7
        )
        let window = MobileDisplayEDRTestWindow(screen: attachedScreen)
        var resolvedWindows: [MobileDisplayEDRTestWindow] = []
        var readScreens: [MobileDisplayEDRTestScreen] = []
        let reader = MobileDisplayEDRWindowReader<
            MobileDisplayEDRTestWindow,
            MobileDisplayEDRTestScreen
        >(
            screenResolver: {
                resolvedWindows.append($0)
                return $0.screen
            },
            headroomReader: {
                readScreens.append($0)
                return $0.headroom
            }
        )

        let state = reader.read(
            window: window,
            displayGeneration: MobileDisplayGeneration(rawValue: 19)
        )

        XCTAssertTrue(resolvedWindows.first === window)
        XCTAssertTrue(readScreens.first === attachedScreen)
        XCTAssertFalse(readScreens.contains { $0 === unrelatedScreen })
        XCTAssertEqual(state.display?.rawValue, 19)
        XCTAssertEqual(state.capability, .edrCapable)
        XCTAssertEqual(state.headroom?.potential, 4)
        XCTAssertEqual(state.headroom?.current, 2.5)
    }

    @MainActor
    func testWindowReaderPublishesDetachedWithoutActualScreen() {
        let window = MobileDisplayEDRTestWindow(screen: nil)
        var headroomReadCount = 0
        let reader = MobileDisplayEDRWindowReader<
            MobileDisplayEDRTestWindow,
            MobileDisplayEDRTestScreen
        >(
            screenResolver: { $0.screen },
            headroomReader: {
                headroomReadCount += 1
                return $0.headroom
            }
        )
        let generation = MobileDisplayGeneration(rawValue: 20)

        XCTAssertEqual(
            reader.read(window: nil, displayGeneration: generation),
            .detached
        )
        XCTAssertEqual(
            reader.read(window: window, displayGeneration: generation),
            .detached
        )
        XCTAssertEqual(headroomReadCount, 0)
    }

    @MainActor
    func testWindowReaderNormalizesSupportedSDRWithoutEDRClaim() {
        let screen = MobileDisplayEDRTestScreen(
            potential: 0.75,
            current: 0
        )
        let reader = mobileDisplayEDRTestReader()

        let state = reader.read(
            window: MobileDisplayEDRTestWindow(screen: screen),
            displayGeneration: MobileDisplayGeneration(rawValue: 21)
        )

        XCTAssertEqual(state.capability, .sdr)
        XCTAssertEqual(state.headroom, .conservativeSDR)
        XCTAssertFalse(state.usesConservativeSDRFallback)
    }

    @MainActor
    func testWindowReaderFailsInvalidHeadroomClosedWithoutRawValues() {
        let maximum = MobileDisplayEDRSnapshotPublisher.maximumHeadroom
        let cases: [
            (
                MobileDisplayEDRHeadroomReading,
                MobileDisplayEDRValidationError
            )
        ] = [
            (
                MobileDisplayEDRHeadroomReading(
                    potential: .nan,
                    current: 1
                ),
                .invalidPotentialHeadroom
            ),
            (
                MobileDisplayEDRHeadroomReading(
                    potential: -0.01,
                    current: 1
                ),
                .invalidPotentialHeadroom
            ),
            (
                MobileDisplayEDRHeadroomReading(
                    potential: maximum + 1,
                    current: 1
                ),
                .invalidPotentialHeadroom
            ),
            (
                MobileDisplayEDRHeadroomReading(
                    potential: 4,
                    current: .infinity
                ),
                .invalidCurrentHeadroom
            ),
            (
                MobileDisplayEDRHeadroomReading(
                    potential: 2,
                    current: 3
                ),
                .currentHeadroomExceedsPotential
            )
        ]

        for (index, entry) in cases.enumerated() {
            let screen = MobileDisplayEDRTestScreen(headroom: entry.0)
            let state = mobileDisplayEDRTestReader().read(
                window: MobileDisplayEDRTestWindow(screen: screen),
                displayGeneration: MobileDisplayGeneration(rawValue: 22)
            )

            XCTAssertEqual(
                state,
                .sdrFallback(
                    display: MobileDisplayGeneration(rawValue: 22),
                    reason: entry.1
                ),
                "case \(index)"
            )
            XCTAssertEqual(state.headroom, .conservativeSDR)
            let description = String(reflecting: state).lowercased()
            XCTAssertFalse(description.contains("nan"), "case \(index)")
            XCTAssertFalse(
                description.contains("infinity"),
                "case \(index)"
            )
        }
    }

    @MainActor
    func testWindowReaderRejectsMissingGenerationBeforeReadAndTypesFailure() {
        let screen = MobileDisplayEDRTestScreen(potential: 4, current: 2)
        let window = MobileDisplayEDRTestWindow(screen: screen)
        var headroomReadCount = 0
        let reader = MobileDisplayEDRWindowReader<
            MobileDisplayEDRTestWindow,
            MobileDisplayEDRTestScreen
        >(
            screenResolver: { $0.screen },
            headroomReader: {
                headroomReadCount += 1
                if headroomReadCount == 1 {
                    throw MobileDisplayEDRTestError.readFailed
                }
                return $0.headroom
            }
        )

        XCTAssertEqual(
            reader.read(window: window, displayGeneration: nil),
            .sdrFallback(
                display: nil,
                reason: .invalidDisplayGeneration
            )
        )
        XCTAssertEqual(headroomReadCount, 0)
        XCTAssertEqual(
            reader.read(
                window: window,
                displayGeneration: MobileDisplayGeneration(rawValue: 23)
            ),
            .unavailable(.observationFailed)
        )
        XCTAssertEqual(headroomReadCount, 1)
    }

    @MainActor
    func testScreenObserverFiltersNotificationsToActualAttachedScreen() async {
        let generation = MobileSceneSurfaceGeneration(rawValue: 24)!
        let notificationCenter = NotificationCenter()
        let names = mobileDisplayEDRTestNotificationNames()
        let attachedScreen = MobileDisplayEDRTestScreen(
            potential: 4,
            current: 2
        )
        let unrelatedScreen = MobileDisplayEDRTestScreen(
            potential: 8,
            current: 7
        )
        let window = MobileDisplayEDRTestWindow(screen: attachedScreen)
        var headroomReadCount = 0
        var snapshots: [MobileDisplayEDRSnapshot] = []
        let reader = MobileDisplayEDRWindowReader<
            MobileDisplayEDRTestWindow,
            MobileDisplayEDRTestScreen
        >(
            screenResolver: { $0.screen },
            headroomReader: {
                headroomReadCount += 1
                return $0.headroom
            }
        )
        let observer = MobileDisplayEDRTestObserver(
            surfaceGeneration: generation,
            notificationCenter: notificationCenter,
            names: names,
            screenResolver: { $0.screen },
            reader: { reader.read(window: $0, displayGeneration: $1) },
            handler: { event in
                if case let .snapshot(snapshot) = event {
                    snapshots.append(snapshot)
                }
            }
        )

        XCTAssertEqual(
            observer.attach(
                window: window,
                screen: attachedScreen,
                displayGeneration: MobileDisplayGeneration(rawValue: 31),
                surfaceGeneration: generation,
                reason: .attachment
            ),
            .published
        )
        attachedScreen.headroom = MobileDisplayEDRHeadroomReading(
            potential: 4,
            current: 3
        )
        notificationCenter.post(
            name: names.brightnessDidChange,
            object: unrelatedScreen
        )
        notificationCenter.post(
            name: names.modeDidChange,
            object: attachedScreen
        )
        await drainMobileDisplayEDRNotificationTasks()

        XCTAssertEqual(headroomReadCount, 2)
        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots.last?.state.headroom?.current, 3)
        notificationCenter.post(
            name: names.brightnessDidChange,
            object: attachedScreen
        )
        await drainMobileDisplayEDRNotificationTasks()
        XCTAssertEqual(headroomReadCount, 3)
        XCTAssertEqual(snapshots.count, 2)
    }

    @MainActor
    func testScreenObserverResamplesForegroundTraitsAndReplacement() async {
        let generation = MobileSceneSurfaceGeneration(rawValue: 25)!
        let notificationCenter = NotificationCenter()
        let names = mobileDisplayEDRTestNotificationNames()
        let firstScreen = MobileDisplayEDRTestScreen(
            potential: 4,
            current: 1
        )
        let replacementScreen = MobileDisplayEDRTestScreen(
            potential: 6,
            current: 2
        )
        let window = MobileDisplayEDRTestWindow(screen: firstScreen)
        var snapshots: [MobileDisplayEDRSnapshot] = []
        let reader = mobileDisplayEDRTestReader()
        let observer = MobileDisplayEDRTestObserver(
            surfaceGeneration: generation,
            notificationCenter: notificationCenter,
            names: names,
            screenResolver: { $0.screen },
            reader: { reader.read(window: $0, displayGeneration: $1) },
            handler: { event in
                if case let .snapshot(snapshot) = event {
                    snapshots.append(snapshot)
                }
            }
        )

        _ = observer.attach(
            window: window,
            screen: firstScreen,
            displayGeneration: MobileDisplayGeneration(rawValue: 32),
            surfaceGeneration: generation,
            reason: .attachment
        )
        firstScreen.headroom = MobileDisplayEDRHeadroomReading(
            potential: 4,
            current: 2
        )
        XCTAssertEqual(
            observer.resample(
                .foreground,
                surfaceGeneration: generation
            ),
            .published
        )
        firstScreen.headroom = MobileDisplayEDRHeadroomReading(
            potential: 4,
            current: 3
        )
        XCTAssertEqual(
            observer.resample(.traits, surfaceGeneration: generation),
            .published
        )

        window.screen = replacementScreen
        XCTAssertEqual(
            observer.attach(
                window: window,
                screen: replacementScreen,
                displayGeneration: MobileDisplayGeneration(rawValue: 33),
                surfaceGeneration: generation,
                reason: .attachment
            ),
            .published
        )
        firstScreen.headroom = MobileDisplayEDRHeadroomReading(
            potential: 4,
            current: 4
        )
        notificationCenter.post(
            name: names.modeDidChange,
            object: firstScreen
        )
        replacementScreen.headroom = MobileDisplayEDRHeadroomReading(
            potential: 6,
            current: 3
        )
        notificationCenter.post(
            name: names.brightnessDidChange,
            object: replacementScreen
        )
        await drainMobileDisplayEDRNotificationTasks()

        XCTAssertTrue(observer.currentWindow === window)
        XCTAssertTrue(observer.currentScreen === replacementScreen)
        XCTAssertEqual(
            snapshots.map { $0.state.display?.rawValue },
            [32, 32, 32, 33, 33]
        )
        XCTAssertEqual(snapshots.last?.state.headroom?.current, 3)
    }

    @MainActor
    func testScreenObserverRejectsStaleAndQueuedWorkAfterTeardown() async {
        let generation = MobileSceneSurfaceGeneration(rawValue: 26)!
        let staleGeneration = MobileSceneSurfaceGeneration(rawValue: 27)!
        let notificationCenter = NotificationCenter()
        let names = mobileDisplayEDRTestNotificationNames()
        var screen: MobileDisplayEDRTestScreen? =
            MobileDisplayEDRTestScreen(potential: 4, current: 2)
        var window: MobileDisplayEDRTestWindow? =
            MobileDisplayEDRTestWindow(screen: screen)
        weak let weakScreen = screen
        weak let weakWindow = window
        var snapshots: [MobileDisplayEDRSnapshot] = []
        let reader = mobileDisplayEDRTestReader()
        let observer = MobileDisplayEDRTestObserver(
            surfaceGeneration: generation,
            notificationCenter: notificationCenter,
            names: names,
            screenResolver: { $0.screen },
            reader: { reader.read(window: $0, displayGeneration: $1) },
            handler: { event in
                if case let .snapshot(snapshot) = event {
                    snapshots.append(snapshot)
                }
            }
        )

        XCTAssertEqual(
            observer.attach(
                window: window!,
                screen: screen!,
                displayGeneration: MobileDisplayGeneration(rawValue: 34),
                surfaceGeneration: staleGeneration,
                reason: .attachment
            ),
            .staleSurfaceGeneration
        )
        _ = observer.attach(
            window: window!,
            screen: screen!,
            displayGeneration: MobileDisplayGeneration(rawValue: 34),
            surfaceGeneration: generation,
            reason: .attachment
        )
        screen?.headroom = MobileDisplayEDRHeadroomReading(
            potential: 4,
            current: 3
        )
        notificationCenter.post(
            name: names.modeDidChange,
            object: screen
        )
        XCTAssertEqual(
            observer.invalidate(surfaceGeneration: staleGeneration),
            .staleSurfaceGeneration
        )
        XCTAssertEqual(
            observer.invalidate(surfaceGeneration: generation),
            .invalidated
        )
        window = nil
        screen = nil
        await drainMobileDisplayEDRNotificationTasks()

        XCTAssertNil(weakWindow)
        XCTAssertNil(weakScreen)
        XCTAssertNil(observer.currentWindow)
        XCTAssertNil(observer.currentScreen)
        XCTAssertEqual(snapshots.count, 2)
        XCTAssertEqual(snapshots.last?.state, .unavailable(.invalidated))
        XCTAssertEqual(
            observer.resample(.foreground, surfaceGeneration: generation),
            .alreadyInvalidated
        )
        XCTAssertEqual(
            observer.detach(surfaceGeneration: generation),
            .alreadyInvalidated
        )
    }

    @MainActor
    func testScreenObserverReportsRevisionExhaustionOnceAndReleasesOwnership()
        async
    {
        let generation = MobileSceneSurfaceGeneration(rawValue: 28)!
        let notificationCenter = NotificationCenter()
        let names = mobileDisplayEDRTestNotificationNames()
        var screen: MobileDisplayEDRTestScreen? =
            MobileDisplayEDRTestScreen(potential: 4, current: 2)
        var window: MobileDisplayEDRTestWindow? =
            MobileDisplayEDRTestWindow(screen: screen)
        weak let weakScreen = screen
        weak let weakWindow = window
        var readCount = 0
        var events: [MobileDisplayEDRObserverEvent] = []
        let reader = mobileDisplayEDRTestReader()
        let observer = MobileDisplayEDRTestObserver(
            surfaceGeneration: generation,
            initialRevision: HDRDisplayRevision(rawValue: .max),
            notificationCenter: notificationCenter,
            names: names,
            screenResolver: { $0.screen },
            reader: { window, displayGeneration in
                readCount += 1
                return reader.read(
                    window: window,
                    displayGeneration: displayGeneration
                )
            },
            handler: { events.append($0) }
        )

        XCTAssertEqual(
            observer.attach(
                window: window!,
                screen: screen!,
                displayGeneration: MobileDisplayGeneration(rawValue: 35),
                surfaceGeneration: generation,
                reason: .attachment
            ),
            .revisionExhausted
        )
        XCTAssertNil(observer.currentSnapshot)
        XCTAssertNil(observer.currentWindow)
        XCTAssertNil(observer.currentScreen)
        XCTAssertEqual(
            events,
            [.revisionExhausted(surfaceGeneration: generation)]
        )

        notificationCenter.post(
            name: names.brightnessDidChange,
            object: screen
        )
        await drainMobileDisplayEDRNotificationTasks()
        XCTAssertEqual(readCount, 1)
        XCTAssertEqual(
            observer.detach(surfaceGeneration: generation),
            .revisionExhausted
        )
        XCTAssertEqual(
            observer.attach(
                window: window!,
                screen: screen!,
                displayGeneration: MobileDisplayGeneration(rawValue: 36),
                surfaceGeneration: generation,
                reason: .attachment
            ),
            .revisionExhausted
        )
        XCTAssertEqual(readCount, 1)
        XCTAssertNil(observer.currentWindow)
        XCTAssertNil(observer.currentScreen)
        XCTAssertEqual(
            observer.invalidate(surfaceGeneration: generation),
            .revisionExhausted
        )
        XCTAssertEqual(events.count, 1)

        window = nil
        screen = nil
        XCTAssertNil(weakWindow)
        XCTAssertNil(weakScreen)
        XCTAssertEqual(
            observer.invalidate(surfaceGeneration: generation),
            .alreadyInvalidated
        )
    }

    func testSDRReadingNormalizesSubunitHeadroom() throws {
        var publisher = makePublisher()

        let snapshot = try publishedSnapshot(publisher.update(envelope(
            potential: 0.75,
            current: 0
        )))

        XCTAssertEqual(snapshot.revision.rawValue, 1)
        XCTAssertEqual(snapshot.state.capability, .sdr)
        XCTAssertEqual(snapshot.state.headroom, .conservativeSDR)
        XCTAssertEqual(
            snapshot.renderSnapshot?.headroom,
            DisplayHeadroom(potential: 1, current: 1, reference: 0)
        )
        XCTAssertNil(snapshot.renderSnapshot?.displayID)
    }

    func testEDRCapabilityAndCurrentHeadroomRemainDistinct() throws {
        var publisher = makePublisher()

        let sdrCurrent = try publishedSnapshot(publisher.update(envelope(
            potential: 4,
            current: 1
        )))
        let edrCurrent = try publishedSnapshot(publisher.update(envelope(
            potential: 4,
            current: 2.5
        )))

        XCTAssertEqual(sdrCurrent.state.capability, .edrCapable)
        XCTAssertEqual(sdrCurrent.state.headroom?.current, 1)
        XCTAssertEqual(edrCurrent.state.capability, .edrCapable)
        XCTAssertEqual(edrCurrent.state.headroom?.current, 2.5)
        XCTAssertEqual(edrCurrent.renderSnapshot?.revision.rawValue, 2)
    }

    func testEquivalentReadingDoesNotAdvanceRevision() throws {
        var publisher = makePublisher()
        let first = try publishedSnapshot(publisher.update(envelope()))

        XCTAssertEqual(publisher.update(envelope()), .unchanged)
        XCTAssertEqual(publisher.snapshot, first)
        XCTAssertEqual(publisher.revision.rawValue, 1)
    }

    func testDisplayReplacementPublishesEvenWithEqualHeadroom() throws {
        var publisher = makePublisher()
        let first = try publishedSnapshot(publisher.update(envelope(
            displayGeneration: 11
        )))
        let replacement = try publishedSnapshot(publisher.update(envelope(
            displayGeneration: 12
        )))

        XCTAssertEqual(first.state.display?.rawValue, 11)
        XCTAssertEqual(replacement.state.display?.rawValue, 12)
        XCTAssertEqual(replacement.revision.rawValue, 2)
        XCTAssertNil(replacement.renderSnapshot?.displayID)
    }

    func testInvalidReadingsPublishTypedConservativeFallback() throws {
        let cases: [
            (
                MobileDisplayEDRReading,
                MobileDisplayEDRValidationError,
                UInt64?
            )
        ] = [
            (
                MobileDisplayEDRReading(
                    displayGeneration: 0,
                    potentialHeadroom: 4,
                    currentHeadroom: 2
                ),
                .invalidDisplayGeneration,
                nil
            ),
            (
                MobileDisplayEDRReading(
                    displayGeneration: 11,
                    potentialHeadroom: .nan,
                    currentHeadroom: 1
                ),
                .invalidPotentialHeadroom,
                11
            ),
            (
                MobileDisplayEDRReading(
                    displayGeneration: 11,
                    potentialHeadroom: -0.01,
                    currentHeadroom: 1
                ),
                .invalidPotentialHeadroom,
                11
            ),
            (
                MobileDisplayEDRReading(
                    displayGeneration: 11,
                    potentialHeadroom: 4,
                    currentHeadroom: .infinity
                ),
                .invalidCurrentHeadroom,
                11
            ),
            (
                MobileDisplayEDRReading(
                    displayGeneration: 11,
                    potentialHeadroom:
                        MobileDisplayEDRSnapshotPublisher.maximumHeadroom,
                    currentHeadroom:
                        MobileDisplayEDRSnapshotPublisher.maximumHeadroom + 1
                ),
                .invalidCurrentHeadroom,
                11
            ),
            (
                MobileDisplayEDRReading(
                    displayGeneration: 11,
                    potentialHeadroom: 2,
                    currentHeadroom: 3
                ),
                .currentHeadroomExceedsPotential,
                11
            )
        ]

        for (index, entry) in cases.enumerated() {
            var publisher = makePublisher()
            let snapshot = try publishedSnapshot(publisher.update(
                MobileDisplayEDREventEnvelope(
                    surfaceGeneration: surfaceGeneration,
                    sample: .attached(entry.0)
                )
            ))

            XCTAssertEqual(
                snapshot.state,
                .sdrFallback(
                    display: entry.2.flatMap(MobileDisplayGeneration.init),
                    reason: entry.1
                ),
                "case \(index)"
            )
            XCTAssertTrue(snapshot.state.usesConservativeSDRFallback)
            XCTAssertEqual(
                snapshot.renderSnapshot?.headroom,
                DisplayHeadroom(potential: 1, current: 1, reference: 0)
            )
        }
    }

    func testEquivalentInvalidPayloadsDeduplicateWithoutRetainingRawValues()
        throws
    {
        var publisher = makePublisher()
        let first = try publishedSnapshot(publisher.update(envelope(
            potential: .nan
        )))

        XCTAssertEqual(
            publisher.update(envelope(potential: .infinity)),
            .unchanged
        )
        XCTAssertEqual(publisher.snapshot, first)
        XCTAssertEqual(
            first.state,
            .sdrFallback(
                display: MobileDisplayGeneration(rawValue: 11),
                reason: .invalidPotentialHeadroom
            )
        )
    }

    func testUnknownDetachedAndUnavailableDoNotCreateRenderSnapshot() throws {
        var publisher = makePublisher()

        let unknown = try publishedSnapshot(publisher.update(
            MobileDisplayEDREventEnvelope(
                surfaceGeneration: surfaceGeneration,
                sample: .unknown
            )
        ))
        let detached = try publishedSnapshot(publisher.update(
            MobileDisplayEDREventEnvelope(
                surfaceGeneration: surfaceGeneration,
                sample: .detached
            )
        ))
        let unavailable = try publishedSnapshot(publisher.update(
            MobileDisplayEDREventEnvelope(
                surfaceGeneration: surfaceGeneration,
                sample: .unavailable(.windowScreenUnavailable)
            )
        ))

        XCTAssertNil(unknown.renderSnapshot)
        XCTAssertNil(detached.renderSnapshot)
        XCTAssertNil(unavailable.renderSnapshot)
        XCTAssertEqual(unavailable.revision.rawValue, 3)
    }

    func testStaleSurfaceGenerationCannotMutateCurrentSnapshot() throws {
        var publisher = makePublisher()
        let current = try publishedSnapshot(publisher.update(envelope()))
        let stale = MobileSceneSurfaceGeneration(rawValue: 8)!

        XCTAssertEqual(
            publisher.update(MobileDisplayEDREventEnvelope(
                surfaceGeneration: stale,
                sample: .detached
            )),
            .staleSurfaceGeneration
        )
        XCTAssertEqual(publisher.snapshot, current)
        XCTAssertEqual(publisher.revision.rawValue, 1)
    }

    func testMaximumHeadroomMatchesLuminanceMappingContract() throws {
        XCTAssertEqual(
            MobileDisplayEDRSnapshotPublisher.maximumHeadroom,
            HDRLuminanceMapping.maximumCurrentHeadroom
        )
        var publisher = makePublisher()
        let maximum = MobileDisplayEDRSnapshotPublisher.maximumHeadroom

        let snapshot = try publishedSnapshot(publisher.update(envelope(
            potential: maximum,
            current: maximum
        )))

        XCTAssertEqual(snapshot.state.headroom?.potential, maximum)
        XCTAssertEqual(snapshot.state.headroom?.current, maximum)
    }

    func testRevisionOverflowClearsSnapshotAndRemainsClosed() throws {
        var publisher = MobileDisplayEDRSnapshotPublisher(
            surfaceGeneration: surfaceGeneration,
            initialRevision: HDRDisplayRevision(rawValue: .max)
        )

        XCTAssertEqual(
            publisher.update(envelope()),
            .revisionExhausted
        )
        XCTAssertNil(publisher.snapshot)
        XCTAssertTrue(publisher.isRevisionExhausted)
        XCTAssertEqual(
            publisher.update(MobileDisplayEDREventEnvelope(
                surfaceGeneration: surfaceGeneration,
                sample: .detached
            )),
            .revisionExhausted
        )
    }

    func testNormalizedEquivalentSubunitReadingsDeduplicate() throws {
        var publisher = makePublisher()
        let first = try publishedSnapshot(publisher.update(envelope(
            potential: 0,
            current: -0.0
        )))

        XCTAssertEqual(
            publisher.update(envelope(potential: 1, current: 1)),
            .unchanged
        )
        XCTAssertEqual(first.state.headroom, .conservativeSDR)
        XCTAssertEqual(publisher.revision.rawValue, 1)
    }

    func testInvalidHeadroomClassesConvergeWithoutRawNumericLeakage()
        throws
    {
        var publisher = makePublisher()
        let first = try publishedSnapshot(publisher.update(envelope(
            potential: .nan,
            current: 1
        )))
        let description = String(reflecting: first.state).lowercased()

        XCTAssertFalse(description.contains("nan"))
        XCTAssertFalse(description.contains("infinity"))
        XCTAssertFalse(description.contains("64."))
        XCTAssertEqual(
            publisher.update(envelope(
                potential: .infinity,
                current: 1
            )),
            .unchanged
        )
        XCTAssertEqual(
            first.state,
            .sdrFallback(
                display: MobileDisplayGeneration(rawValue: 11),
                reason: .invalidPotentialHeadroom
            )
        )
    }

    func testUnavailableReasonsDeduplicateAndRemainWithoutRenderFallback()
        throws
    {
        var publisher = makePublisher()
        let unavailable = try publishedSnapshot(publisher.update(
            MobileDisplayEDREventEnvelope(
                surfaceGeneration: surfaceGeneration,
                sample: .unavailable(.observationFailed)
            )
        ))

        XCTAssertNil(unavailable.renderSnapshot)
        XCTAssertEqual(
            publisher.update(MobileDisplayEDREventEnvelope(
                surfaceGeneration: surfaceGeneration,
                sample: .unavailable(.observationFailed)
            )),
            .unchanged
        )
        let invalidated = try publishedSnapshot(publisher.update(
            MobileDisplayEDREventEnvelope(
                surfaceGeneration: surfaceGeneration,
                sample: .unavailable(.invalidated)
            )
        ))
        XCTAssertNil(invalidated.renderSnapshot)
        XCTAssertEqual(invalidated.revision.rawValue, 2)
    }

    func testRevisionCanReachMaximumBeforeNextDisplayChangeCloses()
        throws
    {
        var publisher = MobileDisplayEDRSnapshotPublisher(
            surfaceGeneration: surfaceGeneration,
            initialRevision: HDRDisplayRevision(rawValue: .max - 1)
        )
        let maximum = try publishedSnapshot(publisher.update(envelope(
            displayGeneration: 11
        )))

        XCTAssertEqual(maximum.revision.rawValue, .max)
        XCTAssertEqual(maximum.renderSnapshot?.revision.rawValue, .max)
        XCTAssertEqual(
            publisher.update(envelope(displayGeneration: 12)),
            .revisionExhausted
        )
        XCTAssertNil(publisher.snapshot)
        XCTAssertTrue(publisher.isRevisionExhausted)
    }

    private var surfaceGeneration: MobileSceneSurfaceGeneration {
        MobileSceneSurfaceGeneration(rawValue: 7)!
    }

    private func makePublisher() -> MobileDisplayEDRSnapshotPublisher {
        MobileDisplayEDRSnapshotPublisher(
            surfaceGeneration: surfaceGeneration
        )
    }

    private func envelope(
        displayGeneration: UInt64 = 11,
        potential: Double = 4,
        current: Double = 2
    ) -> MobileDisplayEDREventEnvelope {
        MobileDisplayEDREventEnvelope(
            surfaceGeneration: surfaceGeneration,
            sample: .attached(MobileDisplayEDRReading(
                displayGeneration: displayGeneration,
                potentialHeadroom: potential,
                currentHeadroom: current
            ))
        )
    }

    private func publishedSnapshot(
        _ outcome: MobileDisplayEDRPublicationOutcome,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> MobileDisplayEDRSnapshot {
        guard case let .published(snapshot) = outcome else {
            XCTFail(
                "Expected published snapshot, got \(outcome)",
                file: file,
                line: line
            )
            throw TestFailure.expectedPublishedSnapshot
        }
        return snapshot
    }

    private enum TestFailure: Error {
        case expectedPublishedSnapshot
    }
}

private typealias MobileDisplayEDRTestObserver = MobileDisplayEDRObserver<
    MobileDisplayEDRTestWindow,
    MobileDisplayEDRTestScreen
>

@MainActor
private func mobileDisplayEDRTestReader() -> MobileDisplayEDRWindowReader<
    MobileDisplayEDRTestWindow,
    MobileDisplayEDRTestScreen
> {
    MobileDisplayEDRWindowReader(
        screenResolver: { $0.screen },
        headroomReader: { $0.headroom }
    )
}

private func mobileDisplayEDRTestNotificationNames()
    -> MobileDisplayEDRNotificationNames
{
    MobileDisplayEDRNotificationNames(
        modeDidChange: Notification.Name("test.screen.mode"),
        brightnessDidChange: Notification.Name("test.screen.brightness")
    )
}

@MainActor
private func drainMobileDisplayEDRNotificationTasks() async {
    await Task.yield()
    await Task.yield()
}

private final class MobileDisplayEDRTestWindow {
    var screen: MobileDisplayEDRTestScreen?

    init(screen: MobileDisplayEDRTestScreen?) {
        self.screen = screen
    }
}

private final class MobileDisplayEDRTestScreen: NSObject {
    var headroom: MobileDisplayEDRHeadroomReading

    init(headroom: MobileDisplayEDRHeadroomReading) {
        self.headroom = headroom
        super.init()
    }

    convenience init(potential: Double, current: Double) {
        self.init(headroom: MobileDisplayEDRHeadroomReading(
            potential: potential,
            current: current
        ))
    }
}

private enum MobileDisplayEDRTestError: Error {
    case readFailed
}
