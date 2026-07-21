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
