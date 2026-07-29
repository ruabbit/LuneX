import CoreFoundation

#if os(macOS)
import Security
#endif

enum EmbeddedEntitlementQueryResult: Equatable, Sendable {
    case boolean(Bool)
    case missing
    case malformed
    case unreadable
}

protocol EmbeddedEntitlementQuerying: Sendable {
    func query(entitlement: String) -> EmbeddedEntitlementQueryResult
}

protocol HeadPoseEntitlementReading: Sendable {
    func readHeadPoseEntitlement() -> SpatialAudioEntitlementState
}

struct SecurityEmbeddedEntitlementQuery: EmbeddedEntitlementQuerying {
    func query(entitlement: String) -> EmbeddedEntitlementQueryResult {
        #if os(macOS)
        guard let task = SecTaskCreateFromSelf(nil) else {
            return .unreadable
        }

        var error: Unmanaged<CFError>?
        let value = SecTaskCopyValueForEntitlement(
            task,
            entitlement as CFString,
            &error
        )
        let errorPresent = error != nil
        error?.release()
        return Self.classify(value: value, errorPresent: errorPresent)
        #else
        _ = entitlement
        return .unreadable
        #endif
    }

    static func classify(
        value: CFTypeRef?,
        errorPresent: Bool
    ) -> EmbeddedEntitlementQueryResult {
        guard !errorPresent else {
            return .unreadable
        }
        guard let value else {
            return .missing
        }
        guard CFGetTypeID(value) == CFBooleanGetTypeID() else {
            return .malformed
        }
        return .boolean(CFEqual(value, kCFBooleanTrue))
    }
}

struct SecurityEmbeddedHeadPoseEntitlementReader: HeadPoseEntitlementReading {
    static let entitlement = "com.apple.developer.coremotion.head-pose"

    private let query: any EmbeddedEntitlementQuerying

    init(
        query: any EmbeddedEntitlementQuerying = SecurityEmbeddedEntitlementQuery()
    ) {
        self.query = query
    }

    func readHeadPoseEntitlement() -> SpatialAudioEntitlementState {
        switch query.query(entitlement: Self.entitlement) {
        case .boolean(true):
            .granted
        case .boolean(false), .missing:
            .missing
        case .malformed, .unreadable:
            .unreadable
        }
    }
}
