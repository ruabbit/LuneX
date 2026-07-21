import XCTest

@MainActor
final class MacCursorCaptureOwnerTests: XCTestCase {
    func testCaptureAndReleaseAreBalancedAndIdempotent() {
        let operations = CursorSystemOperationsStub()
        let owner = MacCursorCaptureOwner(operations: operations)

        XCTAssertTrue(owner.apply(capturePolicy))
        XCTAssertTrue(owner.apply(capturePolicy))
        XCTAssertEqual(operations.calls, [.association(false), .hide])
        XCTAssertEqual(owner.snapshot(), MacCursorCaptureSnapshot(
            ownsHiddenCursor: true,
            ownsPointerDisassociation: true,
            transitionFailureCount: 0
        ))

        XCTAssertTrue(owner.releaseCapture())
        XCTAssertTrue(owner.releaseCapture())
        XCTAssertEqual(operations.calls, [
            .association(false),
            .hide,
            .association(true),
            .unhide
        ])
        XCTAssertFalse(owner.snapshot().ownsHiddenCursor)
        XCTAssertFalse(owner.snapshot().ownsPointerDisassociation)
    }

    func testAssociationFailureDoesNotClaimOwnership() {
        let operations = CursorSystemOperationsStub(failingAssociationCalls: [1])
        let owner = MacCursorCaptureOwner(operations: operations)

        XCTAssertFalse(owner.apply(capturePolicy))
        XCTAssertFalse(owner.snapshot().ownsHiddenCursor)
        XCTAssertFalse(owner.snapshot().ownsPointerDisassociation)
        XCTAssertEqual(owner.snapshot().transitionFailureCount, 1)

        XCTAssertTrue(owner.releaseCapture())
        XCTAssertEqual(operations.calls, [.association(false)])
    }

    func testFailedAssociationRestoreRemainsOwnedAndCanRetry() {
        let operations = CursorSystemOperationsStub(failingAssociationCalls: [2])
        let owner = MacCursorCaptureOwner(operations: operations)
        XCTAssertTrue(owner.apply(capturePolicy))

        XCTAssertFalse(owner.releaseCapture())
        XCTAssertFalse(owner.snapshot().ownsHiddenCursor)
        XCTAssertTrue(owner.snapshot().ownsPointerDisassociation)
        XCTAssertEqual(operations.calls.last, .unhide)

        XCTAssertTrue(owner.releaseCapture())
        XCTAssertFalse(owner.snapshot().ownsPointerDisassociation)
        XCTAssertEqual(operations.calls.filter { $0 == .association(true) }.count, 2)
        XCTAssertEqual(operations.calls.filter { $0 == .unhide }.count, 1)
    }

    func testHideOnlyPolicyDoesNotChangePointerAssociation() {
        let operations = CursorSystemOperationsStub()
        let owner = MacCursorCaptureOwner(operations: operations)
        let hideOnly = CursorCapturePolicy(
            hidesSystemCursor: true,
            capturesRelativePointer: false,
            usesRemotePointer: true,
            reason: nil
        )

        XCTAssertTrue(owner.apply(hideOnly))
        XCTAssertTrue(owner.releaseCapture())
        XCTAssertEqual(operations.calls, [.hide, .unhide])
    }

    func testRelativeToHideOnlyTransitionRestoresAssociationWithoutShowingCursor() {
        let operations = CursorSystemOperationsStub()
        let owner = MacCursorCaptureOwner(operations: operations)
        let hideOnly = CursorCapturePolicy(
            hidesSystemCursor: true,
            capturesRelativePointer: false,
            usesRemotePointer: true,
            reason: nil
        )

        XCTAssertTrue(owner.apply(capturePolicy))
        XCTAssertTrue(owner.apply(hideOnly))
        XCTAssertEqual(operations.calls, [
            .association(false),
            .hide,
            .association(true)
        ])
        XCTAssertEqual(owner.snapshot(), MacCursorCaptureSnapshot(
            ownsHiddenCursor: true,
            ownsPointerDisassociation: false,
            transitionFailureCount: 0
        ))

        XCTAssertTrue(owner.releaseCapture())
        XCTAssertEqual(operations.calls.last, .unhide)
    }

    private var capturePolicy: CursorCapturePolicy {
        CursorCapturePolicy(
            hidesSystemCursor: true,
            capturesRelativePointer: true,
            usesRemotePointer: true,
            reason: nil
        )
    }
}

@MainActor
private final class CursorSystemOperationsStub: MacCursorSystemOperating {
    enum Call: Equatable {
        case hide
        case unhide
        case association(Bool)
    }

    private(set) var calls: [Call] = []
    private let failingAssociationCalls: Set<Int>
    private var associationCallCount = 0

    init(failingAssociationCalls: Set<Int> = []) {
        self.failingAssociationCalls = failingAssociationCalls
    }

    func hideCursor() {
        calls.append(.hide)
    }

    func unhideCursor() {
        calls.append(.unhide)
    }

    func setPointerAssociation(enabled: Bool) -> Bool {
        associationCallCount += 1
        calls.append(.association(enabled))
        return !failingAssociationCalls.contains(associationCallCount)
    }
}
