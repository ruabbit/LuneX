import XCTest

final class ProductIssueTests: XCTestCase {
    func testEveryIssueCodeHasStablePrivacyBoundedPresentation() {
        let forbidden = [
            "sunshine.internal",
            "47989",
            "1234",
            "certificate",
            "private key",
            "authorization"
        ]

        XCTAssertEqual(ProductIssueCode.allCases.count, 24)
        XCTAssertEqual(
            Set(ProductIssueCode.allCases.map(\.rawValue)).count,
            ProductIssueCode.allCases.count
        )

        for code in ProductIssueCode.allCases {
            let presentation = code.presentation
            let title = String(localized: presentation.title)
            let message = String(localized: presentation.message)

            XCTAssertFalse(title.isEmpty, code.rawValue)
            XCTAssertFalse(message.isEmpty, code.rawValue)
            XCTAssertFalse(presentation.systemImage.isEmpty, code.rawValue)
            for secret in forbidden {
                XCTAssertFalse(title.localizedCaseInsensitiveContains(secret), code.rawValue)
                XCTAssertFalse(message.localizedCaseInsensitiveContains(secret), code.rawValue)
                XCTAssertFalse(code.rawValue.localizedCaseInsensitiveContains(secret), code.rawValue)
            }
        }
    }

    func testIssueDerivesDomainSeverityPresentationAndActionFromStableCode() {
        let actionID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
        let issue = ProductIssue(
            id: UUID(uuidString: "10000000-0000-0000-0000-000000000002")!,
            code: .catalogRefreshFailed,
            actionScope: .application,
            actionID: actionID
        )

        XCTAssertEqual(issue.domain, .catalog)
        XCTAssertEqual(issue.severity, .error)
        XCTAssertEqual(String(localized: issue.presentation.title), "Apps not updated")
        XCTAssertEqual(issue.action?.id, actionID)
        XCTAssertEqual(issue.action?.kind, .refreshCatalog)
        XCTAssertEqual(issue.action?.scope, .application)
    }

    func testActionTokenCarriesCheckedWorkspaceAndSessionScopesWithoutDisplayText() {
        let workspaceID = ProductWorkspaceID(
            rawValue: UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        )
        let sessionID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        let tokenID = UUID(uuidString: "20000000-0000-0000-0000-000000000003")!
        let reference = ProductWorkspaceReference(
            id: workspaceID,
            generation: ProductWorkspaceGeneration(rawValue: 7)!
        )
        let workspace = ProductActionToken(
            id: tokenID,
            kind: .retryPairing,
            scope: .workspace(reference)
        )
        let session = ProductActionToken(
            id: tokenID,
            kind: .reconnectStream,
            scope: .session(
                workspace: reference,
                sessionID: sessionID
            )
        )

        XCTAssertEqual(workspace.scope, .workspace(reference))
        XCTAssertEqual(
            session.scope,
            .session(
                workspace: reference,
                sessionID: sessionID
            )
        )
        XCTAssertNotEqual(workspace, session)
    }

    func testWorkspaceGenerationStartsAtOneAdvancesAndNeverWraps() throws {
        XCTAssertNil(ProductWorkspaceGeneration(rawValue: 0))
        XCTAssertEqual(ProductWorkspaceGeneration.initial.rawValue, 1)
        XCTAssertEqual(ProductWorkspaceGeneration.initial.advanced()?.rawValue, 2)

        let maximum = try XCTUnwrap(ProductWorkspaceGeneration(rawValue: UInt64.max))
        XCTAssertNil(maximum.advanced())
    }

    func testWorkspaceStateKeepsNavigationSelectionAndPresentationLocal() throws {
        let firstReference = ProductWorkspaceReference(
            id: ProductWorkspaceID(
                rawValue: UUID(uuidString: "30000000-0000-0000-0000-000000000001")!
            ),
            generation: .initial
        )
        let secondReference = ProductWorkspaceReference(
            id: ProductWorkspaceID(
                rawValue: UUID(uuidString: "30000000-0000-0000-0000-000000000002")!
            ),
            generation: .initial
        )
        let hostID = UUID(uuidString: "30000000-0000-0000-0000-000000000003")!
        var first = ProductWorkspaceState(reference: firstReference)
        var second = ProductWorkspaceState(reference: secondReference)

        first.navigationSelection = .stream
        first.selectedHostID = hostID
        first.selectedAppID = "app-1"
        first.presentation.sheet = .pairing(hostID: hostID)
        first.presentation.dialog = .removeHost(hostID: hostID)
        first.presentation.issue = ProductIssue(code: .pairingFailed)
        first.presentation.streamOverlay = .visible

        XCTAssertEqual(first.reference, firstReference)
        XCTAssertEqual(first.navigationSelection, .stream)
        XCTAssertEqual(first.selectedHostID, hostID)
        XCTAssertEqual(first.selectedAppID, "app-1")
        XCTAssertEqual(first.presentation.sheet, .pairing(hostID: hostID))
        XCTAssertEqual(first.presentation.dialog, .removeHost(hostID: hostID))
        XCTAssertEqual(first.presentation.issue?.code, .pairingFailed)
        XCTAssertEqual(first.presentation.streamOverlay, .visible)

        XCTAssertEqual(second.reference, secondReference)
        XCTAssertEqual(second.navigationSelection, .library)
        XCTAssertNil(second.selectedHostID)
        XCTAssertNil(second.selectedAppID)
        XCTAssertNil(second.presentation.sheet)
        XCTAssertNil(second.presentation.dialog)
        XCTAssertNil(second.presentation.issue)
        XCTAssertEqual(second.presentation.streamOverlay, .hidden)
    }

    func testInformationalAndStaleIssuesDoNotInventRecoveryActions() {
        let cancelled = ProductIssue(code: .pairingCancelled)
        let stale = ProductIssue(code: .staleAction)

        XCTAssertEqual(cancelled.severity, .information)
        XCTAssertNil(cancelled.action)
        XCTAssertEqual(stale.severity, .warning)
        XCTAssertNil(stale.action)
    }

    func testAllActionableIssuesMintOnlyTheirDeclaredAction() {
        for code in ProductIssueCode.allCases {
            let issue = ProductIssue(code: code)
            XCTAssertEqual(issue.action?.kind, code.defaultAction, code.rawValue)
            XCTAssertEqual(issue.action?.scope, code.defaultAction == nil ? nil : .application)
        }
    }
}
