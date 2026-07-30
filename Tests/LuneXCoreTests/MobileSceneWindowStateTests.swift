import XCTest

final class MobileSceneWindowStateTests: XCTestCase {
    func testAttachedSamplePublishesValidatedDrawableAndTraits() throws {
        var publisher = makePublisher()

        let outcome = publisher.update(.attached(makeAttachedSample()))
        let snapshot = try publishedSnapshot(outcome)
        let geometry = try XCTUnwrap(snapshot.state.geometry)

        XCTAssertEqual(snapshot.surfaceGeneration.rawValue, 7)
        XCTAssertEqual(snapshot.revision.rawValue, 1)
        XCTAssertEqual(snapshot.state.activity, .active)
        XCTAssertEqual(
            geometry.drawableSize,
            PixelSize(width: 2_048, height: 1_536)
        )
        XCTAssertEqual(geometry.safeAreaInsets.top, 24)
        XCTAssertEqual(geometry.orientation, .landscapeLeft)
        XCTAssertEqual(geometry.traits.horizontalSizeClass, .regular)
    }

    func testEquivalentSampleDoesNotAdvanceRevision() throws {
        var publisher = makePublisher()
        let first = try publishedSnapshot(
            publisher.update(.attached(makeAttachedSample()))
        )

        XCTAssertEqual(
            publisher.update(.attached(makeAttachedSample())),
            .unchanged
        )
        XCTAssertEqual(publisher.revision.rawValue, 1)
        XCTAssertEqual(publisher.snapshot, first)
    }

    func testActivityChangePublishesWithoutChangingGeometry() throws {
        var publisher = makePublisher()
        let active = try publishedSnapshot(
            publisher.update(.attached(makeAttachedSample()))
        )
        let inactive = try publishedSnapshot(
            publisher.update(.attached(makeAttachedSample(activity: .inactive)))
        )

        XCTAssertEqual(active.revision.rawValue, 1)
        XCTAssertEqual(inactive.revision.rawValue, 2)
        XCTAssertEqual(inactive.state.activity, .inactive)
        XCTAssertEqual(active.state.geometry, inactive.state.geometry)
    }

    func testDetachClearsGeometryAndPreservesImmutablePriorSnapshot() throws {
        var publisher = makePublisher()
        let attached = try publishedSnapshot(
            publisher.update(.attached(makeAttachedSample()))
        )
        let detached = try publishedSnapshot(
            publisher.update(.detached(activity: .background))
        )

        XCTAssertNotNil(attached.state.geometry)
        XCTAssertNil(detached.state.geometry)
        XCTAssertEqual(detached.revision.rawValue, 2)
        XCTAssertEqual(
            detached.state,
            .detached(activity: .background)
        )
        XCTAssertNotNil(attached.state.geometry)
    }

    func testInvalidGeometryPublishesClosedStateAndDeduplicates() throws {
        var publisher = makePublisher()
        _ = publisher.update(.attached(makeAttachedSample()))
        let invalidSample = makeAttachedSample(
            viewBounds: MobileSceneRect(
                x: 0,
                y: 0,
                width: .nan,
                height: 768
            )
        )

        let closed = try publishedSnapshot(
            publisher.update(.attached(invalidSample))
        )

        XCTAssertEqual(
            closed.state,
            .unavailable(activity: .active, reason: .invalidViewBounds)
        )
        XCTAssertNil(closed.state.geometry)
        XCTAssertEqual(
            publisher.update(.attached(invalidSample)),
            .unchanged
        )
        XCTAssertEqual(publisher.revision.rawValue, 2)
    }

    func testValidGeometryRecoversAfterClosedState() throws {
        var publisher = makePublisher()
        _ = publisher.update(.attached(makeAttachedSample(scale: .infinity)))

        let recovered = try publishedSnapshot(
            publisher.update(.attached(makeAttachedSample()))
        )

        XCTAssertEqual(recovered.revision.rawValue, 2)
        XCTAssertNotNil(recovered.state.geometry)
    }

    func testInvalidInputsMapToStableClosedReasons() throws {
        let cases: [
            (
                MobileSceneWindowAttachedSample,
                MobileSceneWindowValidationError
            )
        ] = [
            (
                makeAttachedSample(displayGeneration: 0),
                .invalidDisplayGeneration
            ),
            (
                makeAttachedSample(viewBounds: MobileSceneRect(
                    x: 0,
                    y: 0,
                    width: 0,
                    height: 768
                )),
                .invalidViewBounds
            ),
            (
                makeAttachedSample(viewBounds: MobileSceneRect(
                    x: 1_000_000,
                    y: 0,
                    width: 1,
                    height: 768
                )),
                .invalidViewBounds
            ),
            (
                makeAttachedSample(windowBounds: MobileSceneRect(
                    x: 0,
                    y: 0,
                    width: -1,
                    height: 768
                )),
                .invalidWindowBounds
            ),
            (
                makeAttachedSample(safeAreaInsets: MobileSceneEdgeInsets(
                    top: 400,
                    leading: 0,
                    bottom: 400,
                    trailing: 0
                )),
                .invalidSafeAreaInsets
            ),
            (
                makeAttachedSample(scale: 0),
                .invalidScale
            ),
            (
                makeAttachedSample(
                    viewBounds: MobileSceneRect(
                        x: 0,
                        y: 0,
                        width: 131_072,
                        height: 768
                    ),
                    scale: 16
                ),
                .drawableSizeOverflow
            )
        ]

        for (index, pair) in cases.enumerated() {
            var publisher = makePublisher()
            let snapshot = try publishedSnapshot(
                publisher.update(.attached(pair.0))
            )
            XCTAssertEqual(
                snapshot.state,
                .unavailable(activity: .active, reason: pair.1),
                "case \(index)"
            )
        }
    }

    func testFractionalScaleRoundsDrawableDeterministically() throws {
        var publisher = makePublisher()
        let sample = makeAttachedSample(
            viewBounds: MobileSceneRect(
                x: 0,
                y: 0,
                width: 333.25,
                height: 222.25
            ),
            scale: 2
        )

        let snapshot = try publishedSnapshot(
            publisher.update(.attached(sample))
        )

        XCTAssertEqual(
            snapshot.state.geometry?.drawableSize,
            PixelSize(width: 667, height: 445)
        )
    }

    func testRevisionOverflowClearsSnapshotAndRemainsClosed() throws {
        let generation = try XCTUnwrap(
            MobileSceneSurfaceGeneration(rawValue: 7)
        )
        var publisher = MobileSceneWindowSnapshotPublisher(
            surfaceGeneration: generation,
            initialRevision: MobileSceneWindowRevision(rawValue: .max)
        )

        XCTAssertEqual(
            publisher.update(.attached(makeAttachedSample())),
            .revisionExhausted
        )
        XCTAssertNil(publisher.snapshot)
        XCTAssertTrue(publisher.isRevisionExhausted)
        XCTAssertEqual(
            publisher.update(.detached(activity: .background)),
            .revisionExhausted
        )
        XCTAssertEqual(publisher.revision.rawValue, .max)
    }

    func testGenerationValuesRejectZero() {
        XCTAssertNil(MobileSceneSurfaceGeneration(rawValue: 0))
        XCTAssertNil(MobileDisplayGeneration(rawValue: 0))
        XCTAssertEqual(
            MobileSceneSurfaceGeneration(rawValue: .max)?.rawValue,
            .max
        )
        XCTAssertEqual(
            MobileDisplayGeneration(rawValue: .max)?.rawValue,
            .max
        )
    }

    func testEquivalentInvalidGeometryClassesDoNotRetainRawPayloads()
        throws
    {
        var publisher = makePublisher()
        let nan = try publishedSnapshot(publisher.update(.attached(
            makeAttachedSample(viewBounds: MobileSceneRect(
                x: 0,
                y: 0,
                width: .nan,
                height: 768
            ))
        )))

        XCTAssertEqual(
            publisher.update(.attached(makeAttachedSample(
                viewBounds: MobileSceneRect(
                    x: 0,
                    y: 0,
                    width: .infinity,
                    height: 768
                )
            ))),
            .unchanged
        )
        XCTAssertEqual(
            nan.state,
            .unavailable(activity: .active, reason: .invalidViewBounds)
        )
        XCTAssertFalse(String(reflecting: nan.state).lowercased().contains(
            "nan"
        ))
        XCTAssertFalse(String(reflecting: nan.state).lowercased().contains(
            "inf"
        ))
    }

    func testGeometryValidationCoversEveryFiniteBoundaryClass() throws {
        let invalidSamples: [
            (MobileSceneWindowAttachedSample, MobileSceneWindowValidationError)
        ] = [
            (
                makeAttachedSample(viewBounds: MobileSceneRect(
                    x: -.infinity,
                    y: 0,
                    width: 1_024,
                    height: 768
                )),
                .invalidViewBounds
            ),
            (
                makeAttachedSample(windowBounds: MobileSceneRect(
                    x: 0,
                    y: .nan,
                    width: 1_024,
                    height: 768
                )),
                .invalidWindowBounds
            ),
            (
                makeAttachedSample(safeAreaInsets: MobileSceneEdgeInsets(
                    top: .nan,
                    leading: 0,
                    bottom: 0,
                    trailing: 0
                )),
                .invalidSafeAreaInsets
            ),
            (
                makeAttachedSample(safeAreaInsets: MobileSceneEdgeInsets(
                    top: 0,
                    leading: -1,
                    bottom: 0,
                    trailing: 0
                )),
                .invalidSafeAreaInsets
            ),
            (
                makeAttachedSample(scale: 16.nextUp),
                .invalidScale
            ),
            (
                makeAttachedSample(
                    viewBounds: MobileSceneRect(
                        x: 0,
                        y: 0,
                        width: 0.01,
                        height: 768
                    ),
                    scale: 1
                ),
                .drawableSizeOverflow
            )
        ]

        for (index, entry) in invalidSamples.enumerated() {
            var publisher = makePublisher()
            let snapshot = try publishedSnapshot(
                publisher.update(.attached(entry.0))
            )
            XCTAssertEqual(
                snapshot.state,
                .unavailable(activity: .active, reason: entry.1),
                "case \(index)"
            )
        }
    }

    func testCoordinateBoundaryIsInclusiveButEndpointMustRemainBounded()
        throws
    {
        var publisher = makePublisher()
        let valid = try publishedSnapshot(publisher.update(.attached(
            makeAttachedSample(viewBounds: MobileSceneRect(
                x: -1_000_000,
                y: -1_000_000,
                width: 1,
                height: 1
            ), safeAreaInsets: .zero)
        )))

        XCTAssertNotNil(valid.state.geometry)
        let invalid = try publishedSnapshot(publisher.update(.attached(
            makeAttachedSample(viewBounds: MobileSceneRect(
                x: 999_999.5,
                y: 0,
                width: 1,
                height: 1
            ), safeAreaInsets: .zero)
        )))
        XCTAssertEqual(
            invalid.state,
            .unavailable(activity: .active, reason: .invalidViewBounds)
        )
    }

    func testRevisionCanReachMaximumBeforeNextChangeFailsClosed() throws {
        let generation = MobileSceneSurfaceGeneration(rawValue: 7)!
        var publisher = MobileSceneWindowSnapshotPublisher(
            surfaceGeneration: generation,
            initialRevision: MobileSceneWindowRevision(rawValue: .max - 1)
        )

        let maximum = try publishedSnapshot(
            publisher.update(.attached(makeAttachedSample()))
        )
        XCTAssertEqual(maximum.revision.rawValue, .max)
        XCTAssertEqual(
            publisher.update(.detached(activity: .background)),
            .revisionExhausted
        )
        XCTAssertNil(publisher.snapshot)
        XCTAssertTrue(publisher.isRevisionExhausted)
    }

    private func makePublisher() -> MobileSceneWindowSnapshotPublisher {
        MobileSceneWindowSnapshotPublisher(
            surfaceGeneration: MobileSceneSurfaceGeneration(rawValue: 7)!
        )
    }

    private func makeAttachedSample(
        activity: AppSceneActivity = .active,
        displayGeneration: UInt64 = 11,
        viewBounds: MobileSceneRect = MobileSceneRect(
            x: 0,
            y: 0,
            width: 1_024,
            height: 768
        ),
        windowBounds: MobileSceneRect = MobileSceneRect(
            x: 0,
            y: 0,
            width: 1_024,
            height: 768
        ),
        safeAreaInsets: MobileSceneEdgeInsets = MobileSceneEdgeInsets(
            top: 24,
            leading: 0,
            bottom: 20,
            trailing: 0
        ),
        scale: Double = 2
    ) -> MobileSceneWindowAttachedSample {
        MobileSceneWindowAttachedSample(
            activity: activity,
            displayGeneration: displayGeneration,
            viewBounds: viewBounds,
            windowBounds: windowBounds,
            safeAreaInsets: safeAreaInsets,
            scale: scale,
            orientation: .landscapeLeft,
            traits: MobileSceneTraits(
                horizontalSizeClass: .regular,
                verticalSizeClass: .regular,
                interfaceStyle: .dark
            )
        )
    }

    private func publishedSnapshot(
        _ outcome: MobileSceneWindowPublicationOutcome,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> MobileSceneWindowSnapshot {
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
