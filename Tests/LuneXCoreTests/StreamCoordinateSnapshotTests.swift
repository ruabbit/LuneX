import XCTest

final class StreamCoordinateSnapshotTests: XCTestCase {
    func testFitCentersFullSourceInsideDrawable() throws {
        let resolved = try XCTUnwrap(StreamVideoRectangleResolver.resolve(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 800, height: 600),
            mode: .fit
        ))

        XCTAssertEqual(resolved.scale, 5.0 / 12.0, accuracy: 0.000_001)
        assertRect(resolved.drawableBounds, x: 0, y: 0, width: 800, height: 600)
        assertRect(resolved.videoRect, x: 0, y: 75, width: 800, height: 450)
        assertRect(resolved.sourceCropRect, x: 0, y: 0, width: 1920, height: 1080)
    }

    func testFillDescribesCenteredSourceCrop() throws {
        let resolved = try XCTUnwrap(StreamVideoRectangleResolver.resolve(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 800, height: 600),
            mode: .fill
        ))

        XCTAssertEqual(resolved.scale, 5.0 / 9.0, accuracy: 0.000_001)
        assertRect(
            resolved.videoRect,
            x: -133.333_333,
            y: 0,
            width: 1_066.666_667,
            height: 600
        )
        assertRect(resolved.sourceCropRect, x: 240, y: 0, width: 1440, height: 1080)
    }

    func testInvalidGeometryDoesNotPublishSnapshot() {
        var publisher = StreamCoordinateSnapshotPublisher()

        XCTAssertNil(publisher.update(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: .zero,
            mode: .fit
        ))
        XCTAssertEqual(publisher.revision, 1)
        XCTAssertNil(publisher.snapshot)
    }

    func testPublisherReusesSnapshotUntilInputsChange() throws {
        var publisher = StreamCoordinateSnapshotPublisher()
        let first = try XCTUnwrap(publisher.update(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 800, height: 600),
            mode: .fit
        ))
        let unchanged = try XCTUnwrap(publisher.update(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 800, height: 600),
            mode: .fit
        ))
        let resized = try XCTUnwrap(publisher.update(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 1600, height: 900),
            mode: .fit
        ))

        XCTAssertEqual(first.revision, 1)
        XCTAssertEqual(unchanged, first)
        XCTAssertEqual(resized.revision, 2)
        XCTAssertEqual(publisher.snapshot, resized)
    }

    func testValidSnapshotAfterInvalidGeometryHasNewRevision() throws {
        var publisher = StreamCoordinateSnapshotPublisher()
        XCTAssertNil(publisher.update(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: .zero,
            mode: .fit
        ))

        let recovered = try XCTUnwrap(publisher.update(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 800, height: 600),
            mode: .fit
        ))
        XCTAssertEqual(recovered.revision, 2)
    }

    func testRevisionOverflowFailsClosed() {
        var publisher = StreamCoordinateSnapshotPublisher(initialRevision: .max)

        XCTAssertNil(publisher.update(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 800, height: 600),
            mode: .fit
        ))
        XCTAssertEqual(publisher.revision, .max)
        XCTAssertNil(publisher.snapshot)
    }

    func testRenderStatePublishesImmutableSnapshotForTransformChanges() throws {
        let state = StreamRenderState(transform: RenderTransform(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 800, height: 600),
            mode: .fit
        ))
        let first = try XCTUnwrap(state.coordinateSnapshot)

        state.transform.drawableSize = PixelSize(width: 1600, height: 900)
        let resized = try XCTUnwrap(state.coordinateSnapshot)
        state.transform.drawableSize = .zero

        XCTAssertEqual(first.revision, 1)
        XCTAssertEqual(first.drawableSize, PixelSize(width: 800, height: 600))
        XCTAssertEqual(resized.revision, 2)
        XCTAssertEqual(resized.drawableSize, PixelSize(width: 1600, height: 900))
        XCTAssertNil(state.coordinateSnapshot)
    }

    func testFitRejectsEveryLetterboxRegionWithoutClamping() throws {
        let landscape = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: 1,
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 800, height: 600),
            mode: .fit
        ))
        let portrait = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: 2,
            sourceSize: PixelSize(width: 1080, height: 1920),
            drawableSize: PixelSize(width: 800, height: 600),
            mode: .fit
        ))

        let landscapeMapper = InputMapper(snapshot: landscape)
        XCTAssertNil(landscapeMapper.remotePoint(localX: 400, localY: 74))
        XCTAssertNil(landscapeMapper.remotePoint(localX: 400, localY: 526))

        let portraitMapper = InputMapper(snapshot: portrait)
        XCTAssertNil(portraitMapper.remotePoint(localX: 230, localY: 300))
        XCTAssertNil(portraitMapper.remotePoint(localX: 570, localY: 300))
    }

    func testFillDrawableEdgesMatchResolvedSourceCropEdges() throws {
        let snapshot = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: 7,
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 800, height: 600),
            mode: .fill
        ))
        let mapper = InputMapper(snapshot: snapshot)
        let crop = snapshot.resolvedVideo.sourceCropRect

        let topLeft = try XCTUnwrap(mapper.remotePoint(localX: 0, localY: 0))
        let bottomRight = try XCTUnwrap(mapper.remotePoint(localX: 800, localY: 600))

        XCTAssertEqual(topLeft.x, crop.minX, accuracy: 0.000_001)
        XCTAssertEqual(topLeft.y, crop.minY, accuracy: 0.000_001)
        XCTAssertEqual(bottomRight.x, crop.maxX, accuracy: 0.000_001)
        XCTAssertEqual(bottomRight.y, crop.maxY, accuracy: 0.000_001)
    }

    func testBackingScaleChangeUsesScaledPointAndDrawableInOneRevision() throws {
        var publisher = StreamCoordinateSnapshotPublisher()
        let oneX = try XCTUnwrap(publisher.update(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 960, height: 540),
            mode: .fit
        ))
        let twoX = try XCTUnwrap(publisher.update(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 1920, height: 1080),
            mode: .fit
        ))

        let oneXPoint = try XCTUnwrap(InputMapper(snapshot: oneX).remotePoint(localX: 480, localY: 270))
        let twoXPoint = try XCTUnwrap(InputMapper(snapshot: twoX).remotePoint(localX: 960, localY: 540))

        XCTAssertEqual(oneX.revision, 1)
        XCTAssertEqual(twoX.revision, 2)
        XCTAssertEqual(oneXPoint, twoXPoint)
        XCTAssertEqual(twoXPoint, RemotePoint(x: 960, y: 540))
    }

    func testEveryNonPositiveDimensionFailsClosed() {
        let cases = [
            (PixelSize(width: 0, height: 1080), PixelSize(width: 800, height: 600)),
            (PixelSize(width: 1920, height: 0), PixelSize(width: 800, height: 600)),
            (PixelSize(width: -1, height: 1080), PixelSize(width: 800, height: 600)),
            (PixelSize(width: 1920, height: -1), PixelSize(width: 800, height: 600)),
            (PixelSize(width: 1920, height: 1080), PixelSize(width: 0, height: 600)),
            (PixelSize(width: 1920, height: 1080), PixelSize(width: 800, height: 0)),
            (PixelSize(width: 1920, height: 1080), PixelSize(width: -1, height: 600)),
            (PixelSize(width: 1920, height: 1080), PixelSize(width: 800, height: -1))
        ]

        for (source, drawable) in cases {
            XCTAssertNil(StreamCoordinateSnapshot.resolve(
                revision: 1,
                sourceSize: source,
                drawableSize: drawable,
                mode: .fit
            ))
        }
    }

    func testResizePublishesNewGeometryWithoutMutatingCapturedSnapshot() throws {
        var publisher = StreamCoordinateSnapshotPublisher()
        let captured = try XCTUnwrap(publisher.update(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 800, height: 600),
            mode: .fit
        ))
        let capturedMapper = InputMapper(snapshot: captured)
        let acceptedBeforeResize = try XCTUnwrap(capturedMapper.remotePoint(localX: 400, localY: 300))

        let current = try XCTUnwrap(publisher.update(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 1200, height: 600),
            mode: .fit
        ))
        let acceptedAfterResize = try XCTUnwrap(
            InputMapper(snapshot: current).remotePoint(localX: 400, localY: 300)
        )

        XCTAssertEqual(captured.revision, 1)
        XCTAssertEqual(current.revision, 2)
        XCTAssertEqual(captured.drawableSize, PixelSize(width: 800, height: 600))
        XCTAssertEqual(current.drawableSize, PixelSize(width: 1200, height: 600))
        XCTAssertEqual(acceptedBeforeResize, RemotePoint(x: 960, y: 540))
        XCTAssertEqual(
            capturedMapper.remotePoint(localX: 400, localY: 300),
            acceptedBeforeResize
        )
        XCTAssertEqual(acceptedAfterResize.x, 600, accuracy: 0.000_001)
        XCTAssertEqual(acceptedAfterResize.y, 540, accuracy: 0.000_001)
    }

    func testScaleModeChangeRevisesWithoutChangingEarlierSnapshot() throws {
        var publisher = StreamCoordinateSnapshotPublisher()
        let fit = try XCTUnwrap(publisher.update(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 800, height: 600),
            mode: .fit
        ))
        let fill = try XCTUnwrap(publisher.update(
            sourceSize: PixelSize(width: 1920, height: 1080),
            drawableSize: PixelSize(width: 800, height: 600),
            mode: .fill
        ))

        XCTAssertEqual(fit.revision, 1)
        XCTAssertEqual(fill.revision, 2)
        XCTAssertEqual(fit.mode, .fit)
        XCTAssertEqual(fill.mode, .fill)
        assertRect(fit.resolvedVideo.videoRect, x: 0, y: 75, width: 800, height: 450)
        assertRect(
            fill.resolvedVideo.sourceCropRect,
            x: 240,
            y: 0,
            width: 1440,
            height: 1080
        )
    }

    private func assertRect(
        _ rect: StreamCoordinateRect,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(rect.x, x, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(rect.y, y, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(rect.width, width, accuracy: 0.000_001, file: file, line: line)
        XCTAssertEqual(rect.height, height, accuracy: 0.000_001, file: file, line: line)
    }
}
