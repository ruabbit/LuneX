import Foundation

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct DisplayHeadroom: Equatable, Sendable {
    var potential: Double = 1.0
    var current: Double = 1.0
    var reference: Double = 0.0

    var supportsEDR: Bool {
        potential > 1.0 || current > 1.0
    }

    static func == (left: Self, right: Self) -> Bool {
        component(left.potential, equals: right.potential)
            && component(left.current, equals: right.current)
            && component(left.reference, equals: right.reference)
    }

    private static func component(_ left: Double, equals right: Double) -> Bool {
        left == right || (left.isNaN && right.isNaN)
    }
}

struct HDRDisplaySnapshot: Equatable, Sendable {
    let revision: HDRDisplayRevision
    let displayID: String?
    let headroom: DisplayHeadroom
}

enum HDRDisplayPublicationOutcome: Equatable, Sendable {
    case unchanged
    case published(HDRDisplaySnapshot?)
    case revisionExhausted
}

struct HDRDisplaySnapshotPublisher: Sendable {
    private struct Inputs: Equatable, Sendable {
        let isSurfaceAttached: Bool
        let displayID: String?
        let headroom: DisplayHeadroom
    }

    private var inputs: Inputs?
    private(set) var revision: HDRDisplayRevision
    private(set) var snapshot: HDRDisplaySnapshot?
    private(set) var isRevisionExhausted = false

    init(initialRevision: HDRDisplayRevision = HDRDisplayRevision(rawValue: 0)) {
        revision = initialRevision
    }

    @discardableResult
    mutating func update(
        isSurfaceAttached: Bool,
        displayID: String?,
        headroom: DisplayHeadroom
    ) -> HDRDisplayPublicationOutcome {
        guard !isRevisionExhausted else { return .revisionExhausted }
        let nextInputs = Inputs(
            isSurfaceAttached: isSurfaceAttached,
            displayID: displayID,
            headroom: headroom
        )
        guard nextInputs != inputs else { return .unchanged }
        inputs = nextInputs

        let nextRevision = revision.rawValue.addingReportingOverflow(1)
        guard !nextRevision.overflow else {
            snapshot = nil
            isRevisionExhausted = true
            return .revisionExhausted
        }
        revision = HDRDisplayRevision(rawValue: nextRevision.partialValue)
        snapshot = isSurfaceAttached
            ? HDRDisplaySnapshot(
                revision: revision,
                displayID: displayID,
                headroom: headroom
            )
            : nil
        return .published(snapshot)
    }
}

enum DisplayHeadroomReader {
    #if os(macOS)
    static func read(screen: NSScreen?) -> DisplayHeadroom {
        guard let screen else { return DisplayHeadroom() }
        return DisplayHeadroom(
            potential: screen.maximumPotentialExtendedDynamicRangeColorComponentValue,
            current: screen.maximumExtendedDynamicRangeColorComponentValue,
            reference: screen.maximumReferenceExtendedDynamicRangeColorComponentValue
        )
    }
    #elseif os(iOS)
    @MainActor
    static func read(screen: UIScreen) -> DisplayHeadroom {
        DisplayHeadroom(
            potential: max(1.0, Double(screen.potentialEDRHeadroom)),
            current: max(1.0, Double(screen.currentEDRHeadroom)),
            reference: 0.0
        )
    }
    #else
    static func read() -> DisplayHeadroom {
        DisplayHeadroom()
    }
    #endif
}
