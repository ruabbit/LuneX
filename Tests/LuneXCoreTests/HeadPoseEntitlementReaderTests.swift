import CoreFoundation
import XCTest

final class HeadPoseEntitlementReaderTests: XCTestCase {
    func testReaderAcceptsOnlyGrantedBooleanAndFailsClosedOtherwise() {
        let cases: [
            (
                result: EmbeddedEntitlementQueryResult,
                expected: SpatialAudioEntitlementState
            )
        ] = [
            (.boolean(true), .granted),
            (.boolean(false), .missing),
            (.missing, .missing),
            (.malformed, .unreadable),
            (.unreadable, .unreadable)
        ]

        for testCase in cases {
            let reader = SecurityEmbeddedHeadPoseEntitlementReader(
                query: FixedEmbeddedEntitlementQuery(result: testCase.result)
            )
            XCTAssertEqual(
                reader.readHeadPoseEntitlement(),
                testCase.expected,
                "result=\(testCase.result)"
            )
        }
    }

    func testSecurityClassifierRequiresLiteralCFBoolean() {
        XCTAssertEqual(
            SecurityEmbeddedEntitlementQuery.classify(
                value: kCFBooleanTrue,
                errorPresent: false
            ),
            .boolean(true)
        )
        XCTAssertEqual(
            SecurityEmbeddedEntitlementQuery.classify(
                value: kCFBooleanFalse,
                errorPresent: false
            ),
            .boolean(false)
        )
        XCTAssertEqual(
            SecurityEmbeddedEntitlementQuery.classify(
                value: nil,
                errorPresent: false
            ),
            .missing
        )
        XCTAssertEqual(
            SecurityEmbeddedEntitlementQuery.classify(
                value: "true" as CFString,
                errorPresent: false
            ),
            .malformed
        )
        XCTAssertEqual(
            SecurityEmbeddedEntitlementQuery.classify(
                value: 1 as CFNumber,
                errorPresent: false
            ),
            .malformed
        )
        XCTAssertEqual(
            SecurityEmbeddedEntitlementQuery.classify(
                value: kCFBooleanTrue,
                errorPresent: true
            ),
            .unreadable
        )
    }

    func testReaderUsesExactHeadPoseEntitlementKey() {
        let reader = SecurityEmbeddedHeadPoseEntitlementReader(
            query: ExactKeyEmbeddedEntitlementQuery(
                expectedEntitlement: "com.apple.developer.coremotion.head-pose"
            )
        )

        XCTAssertEqual(
            SecurityEmbeddedHeadPoseEntitlementReader.entitlement,
            "com.apple.developer.coremotion.head-pose"
        )
        XCTAssertEqual(reader.readHeadPoseEntitlement(), .granted)
    }

    func testSecurityBackendReadsCurrentProcessIntoClosedTypedState() {
        let result = SecurityEmbeddedEntitlementQuery().query(
            entitlement: SecurityEmbeddedHeadPoseEntitlementReader.entitlement
        )

        XCTAssertTrue(
            [
                .boolean(true),
                .boolean(false),
                .missing,
                .unreadable
            ].contains(result),
            "result=\(result)"
        )
    }
}

private struct FixedEmbeddedEntitlementQuery: EmbeddedEntitlementQuerying {
    let result: EmbeddedEntitlementQueryResult

    func query(entitlement: String) -> EmbeddedEntitlementQueryResult {
        _ = entitlement
        return result
    }
}

private struct ExactKeyEmbeddedEntitlementQuery: EmbeddedEntitlementQuerying {
    let expectedEntitlement: String

    func query(entitlement: String) -> EmbeddedEntitlementQueryResult {
        entitlement == expectedEntitlement ? .boolean(true) : .malformed
    }
}
