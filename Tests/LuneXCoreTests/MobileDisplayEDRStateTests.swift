import XCTest

final class MobileDisplayEDRStateTests: XCTestCase {
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
