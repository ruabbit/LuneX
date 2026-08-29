import Foundation
import XCTest

@MainActor
final class HDRPresentationStatusTests: XCTestCase {
    func testDiagnosticStatesMapToPrivacyBoundedPresentationStatuses() {
        let mappings: [(HDRPresentationDiagnosticState, HDRPresentationStatus)] = [
            (.inactive, .inactive),
            (.activeSDR, .sdr),
            (.activeEDR, .edr),
            (
                .sdrFallback(.userPreferenceDisabled),
                .sdrFallback(.disabledByUser)
            ),
            (
                .sdrFallback(.platformOutputUnsupported(.macOS)),
                .sdrFallback(.platformUnavailable)
            ),
            (
                .sdrFallback(.currentHeadroomUnavailable),
                .sdrFallback(.displayCapabilityUnavailable)
            ),
            (
                .sdrFallback(.currentHeadroomInvalid),
                .sdrFallback(.displayCapabilityUnavailable)
            ),
            (
                .sdrFallback(.currentHeadroomInsufficient),
                .sdrFallback(.displayConstrained)
            ),
            (.invalidInput, .invalidInput),
            (.unsupportedOutput, .unsupportedOutput),
            (.staleRevision, .updating),
            (.pipelineFailure, .pipelineFailure)
        ]

        for (diagnostic, expected) in mappings {
            XCTAssertEqual(HDRPresentationStatus(diagnostic), expected)
        }
        XCTAssertEqual(
            HDRPresentationStatus(
                .sdrFallback(.platformOutputUnsupported(.macOS))
            ),
            HDRPresentationStatus(
                .sdrFallback(.platformOutputUnsupported(.tvOS))
            )
        )
    }

    func testPresentationContentUsesFixedAccessibleCopyWithoutIdentifiers() {
        let statuses: [HDRPresentationStatus] = [
            .inactive,
            .sdr,
            .edr,
            .sdrFallback(.disabledByUser),
            .sdrFallback(.platformUnavailable),
            .sdrFallback(.displayCapabilityUnavailable),
            .sdrFallback(.displayConstrained),
            .invalidInput,
            .unsupportedOutput,
            .updating,
            .pipelineFailure
        ]
        let forbiddenFragments = [
            "192.0.2.44",
            "living-room-host",
            "remote-app-name",
            "display-serial-123",
            "revision 42",
            "frame 9001",
            "metadata="
        ]

        for status in statuses {
            let content = status.content
            let publishedText = [
                content.overlayLabel,
                content.settingsValue,
                content.detail,
                content.accessibilityValue
            ].joined(separator: " ")

            XCTAssertFalse(content.overlayLabel.isEmpty)
            XCTAssertFalse(content.settingsValue.isEmpty)
            XCTAssertFalse(content.detail.isEmpty)
            XCTAssertFalse(content.systemImage.isEmpty)
            XCTAssertFalse(content.accessibilityValue.isEmpty)
            for fragment in forbiddenFragments {
                XCTAssertFalse(publishedText.contains(fragment))
            }
        }
    }

    func testAppModelPublishesCurrentStatusAndRejectsStaleOwnerUpdates() {
        let model = makeModel()
        let oldOwner = UUID()
        let replacementOwner = UUID()

        XCTAssertEqual(model.hdrPresentationStatus, .inactive)

        model.claimHDRPresentationDiagnosticOwnership(oldOwner)
        model.publishHDRPresentationDiagnostic(.activeEDR, ownerID: oldOwner)
        XCTAssertEqual(model.hdrPresentationStatus, .edr)

        model.claimHDRPresentationDiagnosticOwnership(replacementOwner)
        model.publishHDRPresentationDiagnostic(.activeSDR, ownerID: replacementOwner)
        XCTAssertEqual(model.hdrPresentationStatus, .sdr)

        model.publishHDRPresentationDiagnostic(.pipelineFailure, ownerID: oldOwner)
        model.publishHDRPresentationDiagnostic(.inactive, ownerID: oldOwner)
        XCTAssertEqual(model.hdrPresentationStatus, .sdr)

        model.publishHDRPresentationDiagnostic(
            .sdrFallback(.currentHeadroomInsufficient),
            ownerID: replacementOwner
        )
        XCTAssertEqual(
            model.hdrPresentationStatus,
            .sdrFallback(.displayConstrained)
        )

        model.publishHDRPresentationDiagnostic(.activeEDR, ownerID: replacementOwner)
        XCTAssertEqual(model.hdrPresentationStatus, .edr)

        model.publishHDRPresentationDiagnostic(.inactive, ownerID: replacementOwner)
        XCTAssertEqual(model.hdrPresentationStatus, .inactive)
    }

    func testRootViewUsesActualStatusWithExplicitAccessibilitySemantics() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let rootViewURL = repositoryRoot
            .appendingPathComponent("Sources/LuneXApp/RootView.swift")
        let source = try String(contentsOf: rootViewURL, encoding: .utf8)

        XCTAssertTrue(source.contains("Toggle(isOn: hdrEnabledBinding)"))
        XCTAssertTrue(source.contains("ViewThatFits(in: .horizontal)"))
        XCTAssertTrue(source.contains(
            "HDRPresentationStatusRow(status: appModel.hdrPresentationStatus)"
        ))
        XCTAssertTrue(source.contains(
            ".accessibilityLabel(\"HDR and EDR\")"
        ))
        XCTAssertTrue(source.contains(
            ".accessibilityLabel(\"Current HDR presentation\")"
        ))
        XCTAssertTrue(source.contains(
            ".accessibilityValue(content.accessibilityValue)"
        ))
        XCTAssertFalse(source.contains(
            "appModel.settings.stream.hdrEnabled ? \"HDR/EDR on\" : \"SDR\""
        ))
    }

    private func makeModel() -> AppModel {
        AppModel(
            runtimeProviders: .unavailable,
            clientIdentityStore: InMemoryClientIdentityStore()
        )
    }
}
