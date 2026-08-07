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
        let workspaceID = UUID(uuidString: "20000000-0000-0000-0000-000000000001")!
        let sessionID = UUID(uuidString: "20000000-0000-0000-0000-000000000002")!
        let tokenID = UUID(uuidString: "20000000-0000-0000-0000-000000000003")!
        let workspace = ProductActionToken(
            id: tokenID,
            kind: .retryPairing,
            scope: .workspace(id: workspaceID, generation: 7)
        )
        let session = ProductActionToken(
            id: tokenID,
            kind: .reconnectStream,
            scope: .session(
                workspaceID: workspaceID,
                workspaceGeneration: 7,
                sessionID: sessionID
            )
        )

        XCTAssertEqual(
            workspace.scope,
            .workspace(id: workspaceID, generation: 7)
        )
        XCTAssertEqual(
            session.scope,
            .session(
                workspaceID: workspaceID,
                workspaceGeneration: 7,
                sessionID: sessionID
            )
        )
        XCTAssertNotEqual(workspace, session)
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
