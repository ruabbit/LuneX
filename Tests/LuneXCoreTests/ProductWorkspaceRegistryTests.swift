import XCTest

@MainActor
final class ProductWorkspaceRegistryTests: XCTestCase {
    func testCreateUsesDistinctIdentityAndInitialGeneration() throws {
        let registry = ProductWorkspaceRegistry()
        let first = try registry.create()
        let second = try registry.create()

        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(first.generation, .initial)
        XCTAssertEqual(second.generation, .initial)
        XCTAssertEqual(registry.states.map(\.reference), [first, second].sortedByID())
    }

    func testDuplicateOpenIdentityFailsWithoutReplacingState() throws {
        let registry = ProductWorkspaceRegistry()
        let id = workspaceID(1)
        let reference = try registry.create(id: id)

        XCTAssertThrowsError(try registry.create(id: id)) {
            XCTAssertEqual(
                $0 as? ProductWorkspaceRegistryFailure,
                .workspaceAlreadyOpen(id)
            )
        }
        XCTAssertEqual(registry.states.map(\.reference), [reference])
    }

    func testRestoreReplacesGenerationAndClearsTransientPresentation() throws {
        let registry = ProductWorkspaceRegistry()
        let id = workspaceID(2)
        let hostID = UUID(uuidString: "42000000-0000-0000-0000-000000000001")!
        let first = try registry.create(id: id)
        try registry.update(first) { state in
            state.navigationSelection = .stream
            state.selectedHostID = hostID
            state.selectedAppID = "old-app"
            state.presentation.sheet = .addHost
            state.presentation.issue = ProductIssue(code: .hostAddFailed)
            state.presentation.streamOverlay = .visible
        }

        let replacement = try registry.restore(
            id: id,
            restoration: ProductWorkspaceRestorationState(
                navigationSelection: .settings,
                selectedHostID: hostID,
                selectedAppID: "restored-app"
            )
        )

        XCTAssertEqual(replacement.generation.rawValue, 2)
        XCTAssertNil(registry.state(for: first))
        let state = try XCTUnwrap(registry.state(for: replacement))
        XCTAssertEqual(state.navigationSelection, .settings)
        XCTAssertEqual(state.selectedHostID, hostID)
        XCTAssertEqual(state.selectedAppID, "restored-app")
        XCTAssertEqual(state.presentation, ProductWorkspacePresentationState())
    }

    func testReplacePreservesRestorableValuesAndRejectsOldMutation() throws {
        let registry = ProductWorkspaceRegistry()
        let id = workspaceID(3)
        let hostID = UUID(uuidString: "43000000-0000-0000-0000-000000000001")!
        let first = try registry.create(id: id)
        try registry.update(first) {
            $0.navigationSelection = .diagnostics
            $0.selectedHostID = hostID
            $0.selectedAppID = "app-3"
            $0.presentation.dialog = .removeHost(hostID: hostID)
        }

        let replacement = try registry.replace(first)
        XCTAssertThrowsError(try registry.update(first) { $0.selectedAppID = "stale" }) {
            XCTAssertEqual(
                $0 as? ProductWorkspaceRegistryFailure,
                .staleReference(current: replacement)
            )
        }
        let state = try XCTUnwrap(registry.state(for: replacement))
        XCTAssertEqual(state.navigationSelection, .diagnostics)
        XCTAssertEqual(state.selectedHostID, hostID)
        XCTAssertEqual(state.selectedAppID, "app-3")
        XCTAssertNil(state.presentation.dialog)
    }

    func testCloseRetainsGenerationTombstoneAndRejectsStaleReference() throws {
        let registry = ProductWorkspaceRegistry()
        let id = workspaceID(4)
        let first = try registry.create(id: id)
        _ = try registry.close(first)

        XCTAssertThrowsError(try registry.close(first)) {
            XCTAssertEqual(
                $0 as? ProductWorkspaceRegistryFailure,
                .staleReference(current: nil)
            )
        }
        let reopened = try registry.create(id: id)
        XCTAssertEqual(reopened.generation.rawValue, 2)
        XCTAssertNil(registry.state(for: first))
        XCTAssertNotNil(registry.state(for: reopened))
    }

    func testGenerationExhaustionFailsClosedWithoutChangingState() throws {
        let id = workspaceID(5)
        let maximum = ProductWorkspaceReference(
            id: id,
            generation: try XCTUnwrap(ProductWorkspaceGeneration(rawValue: UInt64.max))
        )
        let state = ProductWorkspaceState(reference: maximum)
        let registry = try ProductWorkspaceRegistry(restoring: [state])

        XCTAssertThrowsError(try registry.replace(maximum)) {
            XCTAssertEqual(
                $0 as? ProductWorkspaceRegistryFailure,
                .generationExhausted(id)
            )
        }
        XCTAssertEqual(registry.state(for: maximum), state)
    }

    func testDuplicateRestoredWorkspaceFailsClosed() throws {
        let id = workspaceID(6)
        let first = ProductWorkspaceState(reference: .init(id: id, generation: .initial))
        var second = first
        second.navigationSelection = .settings

        XCTAssertThrowsError(try ProductWorkspaceRegistry(restoring: [first, second])) {
            XCTAssertEqual(
                $0 as? ProductWorkspaceRegistryFailure,
                .duplicateRestoredWorkspace(id)
            )
        }
    }

    func testReconcileRepairsSelectionsWithoutTouchingOtherPresentation() throws {
        let registry = ProductWorkspaceRegistry()
        let firstHost = UUID(uuidString: "47000000-0000-0000-0000-000000000001")!
        let removedHost = UUID(uuidString: "47000000-0000-0000-0000-000000000002")!
        let first = try registry.create(id: workspaceID(7))
        let second = try registry.create(id: workspaceID(8))
        try registry.update(first) {
            $0.selectedHostID = removedHost
            $0.selectedAppID = "removed-app"
            $0.presentation.sheet = .addHost
        }
        try registry.update(second) {
            $0.selectedHostID = firstHost
            $0.selectedAppID = "stale-app"
            $0.presentation.streamOverlay = .visible
        }

        registry.reconcile(
            availableHostIDs: [firstHost],
            availableAppIDsByHostID: [firstHost: ["current-app"]]
        )

        let firstState = try XCTUnwrap(registry.state(for: first))
        XCTAssertEqual(firstState.selectedHostID, firstHost)
        XCTAssertNil(firstState.selectedAppID)
        XCTAssertEqual(firstState.presentation.sheet, .addHost)
        let secondState = try XCTUnwrap(registry.state(for: second))
        XCTAssertEqual(secondState.selectedHostID, firstHost)
        XCTAssertNil(secondState.selectedAppID)
        XCTAssertEqual(secondState.presentation.streamOverlay, .visible)
    }

    func testStaleUpdateAndCloseCannotMutateOrRemoveReplacement() throws {
        let registry = ProductWorkspaceRegistry()
        let original = try registry.create(id: workspaceID(9))
        try registry.update(original) { $0.selectedAppID = "current" }
        let replacement = try registry.replace(original)

        XCTAssertThrowsError(try registry.update(original) { $0.selectedAppID = "stale" })
        XCTAssertThrowsError(try registry.close(original))
        XCTAssertEqual(registry.state(for: replacement)?.selectedAppID, "current")
        XCTAssertEqual(registry.states.map(\.reference), [replacement])
    }

    func testReconcileEmptyHostsClearsSelectionsAcrossEveryWorkspace() throws {
        let registry = ProductWorkspaceRegistry()
        let hostID = UUID(uuidString: "4A000000-0000-0000-0000-000000000001")!
        let first = try registry.create(id: workspaceID(10))
        let second = try registry.create(id: workspaceID(11))
        for reference in [first, second] {
            try registry.update(reference) {
                $0.selectedHostID = hostID
                $0.selectedAppID = "app"
            }
        }

        registry.reconcile(availableHostIDs: [])

        for reference in [first, second] {
            XCTAssertNil(registry.state(for: reference)?.selectedHostID)
            XCTAssertNil(registry.state(for: reference)?.selectedAppID)
        }
    }

    func testReconcileWithoutCatalogSnapshotPreservesCurrentAppSelection() throws {
        let registry = ProductWorkspaceRegistry()
        let hostID = UUID(uuidString: "4C000000-0000-0000-0000-000000000001")!
        let reference = try registry.create(id: workspaceID(12))
        try registry.update(reference) {
            $0.selectedHostID = hostID
            $0.selectedAppID = "cached-app"
        }

        registry.reconcile(availableHostIDs: [hostID])

        XCTAssertEqual(registry.state(for: reference)?.selectedAppID, "cached-app")
    }

    func testRestoreAfterCloseAdvancesTombstoneAndClearsTransientState() throws {
        let registry = ProductWorkspaceRegistry()
        let id = workspaceID(13)
        let first = try registry.create(id: id)
        try registry.update(first) {
            $0.presentation.issue = ProductIssue(code: .streamInterrupted)
            $0.presentation.streamOverlay = .visible
        }
        _ = try registry.close(first)

        let restored = try registry.restore(
            id: id,
            restoration: ProductWorkspaceRestorationState(
                navigationSelection: .library,
                selectedAppID: "restored-app"
            )
        )

        XCTAssertEqual(restored.generation.rawValue, 2)
        XCTAssertNil(registry.state(for: first))
        XCTAssertEqual(registry.state(for: restored)?.selectedAppID, "restored-app")
        XCTAssertEqual(
            registry.state(for: restored)?.presentation,
            ProductWorkspacePresentationState()
        )
    }

    func testGeneratedIdentityCollisionFailsClosed() throws {
        let id = workspaceID(14)
        let registry = ProductWorkspaceRegistry(generateID: { id })
        let first = try registry.create()

        XCTAssertThrowsError(try registry.create()) {
            XCTAssertEqual(
                $0 as? ProductWorkspaceRegistryFailure,
                .workspaceAlreadyOpen(id)
            )
        }
        XCTAssertEqual(registry.states.map(\.reference), [first])
    }

    private func workspaceID(_ suffix: UInt8) -> ProductWorkspaceID {
        ProductWorkspaceID(rawValue: UUID(uuidString: String(
            format: "40000000-0000-0000-0000-%012d",
            suffix
        ))!)
    }
}

private extension Array where Element == ProductWorkspaceReference {
    func sortedByID() -> [Element] {
        sorted { $0.id.rawValue.uuidString < $1.id.rawValue.uuidString }
    }
}
