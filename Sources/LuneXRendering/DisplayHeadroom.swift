import Foundation
import QuartzCore

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

struct DisplayHeadroom: Equatable {
    var potential: Double = 1.0
    var current: Double = 1.0
    var reference: Double = 0.0

    var supportsEDR: Bool {
        potential > 1.0 || current > 1.0
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
            potential: max(1.0, Double(screen.currentEDRHeadroom)),
            current: max(1.0, Double(screen.currentEDRHeadroom)),
            reference: 0.0
        )
    }
    #else
    static func read() -> DisplayHeadroom {
        DisplayHeadroom()
    }
    #endif

    static func configure(_ layer: CAMetalLayer, forHDRStream isHDR: Bool) {
        #if os(macOS) || os(iOS)
        layer.wantsExtendedDynamicRangeContent = isHDR
        #else
        _ = layer
        _ = isHDR
        #endif
    }
}
