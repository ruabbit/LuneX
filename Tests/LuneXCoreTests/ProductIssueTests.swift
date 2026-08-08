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

        XCTAssertEqual(ProductIssueCode.allCases.count, 25)
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
        for action in ProductActionKind.allCases {
            XCTAssertFalse(String(localized: action.title).isEmpty, action.rawValue)
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
        let second = ProductWorkspaceState(reference: secondReference)

        first.navigationSelection = .stream
        first.selectedHostID = hostID
        first.selectedAppID = "app-1"
        first.presentation.sheet = .pairing(hostID: hostID)
        let removalConfirmation = ProductHostDestructiveConfirmation(
            owner: ProductHostActionOwner(
                workspace: firstReference,
                hostID: hostID,
                hostSelectionGeneration: first.hostSelectionGeneration
            ),
            kind: .remove,
            requiresSessionStop: false
        )
        first.presentation.dialog = .removeHost(removalConfirmation)
        first.presentation.issue = ProductIssue(code: .pairingFailed)
        first.presentation.streamOverlay = .visible

        XCTAssertEqual(first.reference, firstReference)
        XCTAssertEqual(first.navigationSelection, .stream)
        XCTAssertEqual(first.selectedHostID, hostID)
        XCTAssertEqual(first.selectedAppID, "app-1")
        XCTAssertEqual(first.presentation.sheet, .pairing(hostID: hostID))
        XCTAssertEqual(
            first.presentation.dialog,
            .removeHost(removalConfirmation)
        )
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

    func testAppSelectionChangeInvalidatesPresentedSessionAction() {
        let reference = ProductWorkspaceReference(
            id: ProductWorkspaceID(
                rawValue: UUID(uuidString: "30000000-0000-0000-0000-000000000010")!
            ),
            generation: .initial
        )
        var state = ProductWorkspaceState(
            reference: reference,
            selectedAppID: "app-1"
        )
        state.presentation.issue = ProductIssue(
            code: .streamTerminated,
            actionScope: .session(
                workspace: reference,
                sessionID: UUID(
                    uuidString: "30000000-0000-0000-0000-000000000011"
                )!
            )
        )

        state.selectedAppID = "app-2"

        XCTAssertNil(state.presentation.issue)
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

    func testIssueActionAndValidationFailureStoreNoFreeTextOrRejectedDraft() throws {
        let issue = ProductIssue(code: .pairingFailed)
        XCTAssertEqual(
            Set(Mirror(reflecting: issue).children.compactMap(\.label)),
            ["id", "code", "action"]
        )
        let action = try XCTUnwrap(issue.action)
        XCTAssertEqual(
            Set(Mirror(reflecting: action).children.compactMap(\.label)),
            ["id", "kind", "scope"]
        )
        XCTAssertFalse(Mirror(reflecting: issue).children.contains {
            $0.value is String
        })
        XCTAssertFalse(Mirror(reflecting: action).children.contains {
            $0.value is String
        })

        let rejected = "http://private-user:private-password@private-host.local"
        let failure = try XCTUnwrap(ManualHostDraft(address: rejected).validate().failure)
        XCTAssertEqual(
            Set(Mirror(reflecting: failure).children.compactMap(\.label)),
            ["issueCode"]
        )
        XCTAssertFalse(String(reflecting: failure).contains(rejected))
        XCTAssertFalse(String(reflecting: failure).contains("private-password"))
        XCTAssertFalse(String(reflecting: failure).contains("private-host"))

        XCTAssertEqual(
            Set(Mirror(reflecting: StreamLaunchUIState()).children.compactMap(\.label)),
            ["isLaunching"]
        )
    }

    func testScopedIssuePresentationDoesNotExposeWorkspaceOrSessionIdentity() {
        let workspaceUUID = UUID(uuidString: "50000000-0000-0000-0000-000000000001")!
        let sessionUUID = UUID(uuidString: "50000000-0000-0000-0000-000000000002")!
        let reference = ProductWorkspaceReference(
            id: ProductWorkspaceID(rawValue: workspaceUUID),
            generation: ProductWorkspaceGeneration(rawValue: 77)!
        )
        let issue = ProductIssue(
            code: .streamInterrupted,
            actionScope: .session(workspace: reference, sessionID: sessionUUID)
        )
        let presentation = [
            String(localized: issue.presentation.title),
            String(localized: issue.presentation.message),
            issue.presentation.systemImage,
            issue.code.rawValue
        ].joined(separator: " ")

        XCTAssertFalse(presentation.localizedCaseInsensitiveContains(workspaceUUID.uuidString))
        XCTAssertFalse(presentation.localizedCaseInsensitiveContains(sessionUUID.uuidString))
        XCTAssertEqual(
            issue.action?.scope,
            .session(workspace: reference, sessionID: sessionUUID)
        )
    }
}

private extension Result {
    var failure: Failure? {
        guard case let .failure(failure) = self else { return nil }
        return failure
    }
}
