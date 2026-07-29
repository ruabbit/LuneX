import CoreGraphics
import Foundation
import MetalKit
import QuartzCore

struct HDRSurfaceAdapterCapabilities: Equatable, Sendable {
    let platform: AppleRenderingPlatform
    let extendedRangeSurfaceSupport: HDRExtendedRangeSurfaceSupport
    let supportedEDRGamuts: Set<HDROutputGamut>

    init(
        platform: AppleRenderingPlatform,
        extendedRangeSurfaceSupport: HDRExtendedRangeSurfaceSupport,
        supportedEDRGamuts: Set<HDROutputGamut>
    ) {
        self.platform = platform
        self.extendedRangeSurfaceSupport = extendedRangeSurfaceSupport
        self.supportedEDRGamuts = supportedEDRGamuts
    }

    init(platformCapabilities: HDRPlatformOutputCapabilities) {
        self.init(
            platform: platformCapabilities.platform,
            extendedRangeSurfaceSupport:
                platformCapabilities.extendedRangeSurfaceSupport,
            supportedEDRGamuts: platformCapabilities.supportedEDRGamuts
        )
    }

    func supports(_ contract: HDRSurfaceContract) -> Bool {
        guard contract.extendedRangeIntent == .enabled else { return true }
        return extendedRangeSurfaceSupport != .unavailable
            && supportedEDRGamuts.contains(contract.outputGamut)
    }

    static var current: Self {
        Self(platformCapabilities: HDRPlatformOutputCapabilityAdapter.current.capabilities)
    }
}

enum HDRSurfaceMutation: Equatable, Sendable {
    case drawablePixelFormat(HDRDrawablePixelFormat)
    case outputColorSpace(HDROutputColorSpace)
    case metadata(HDRSurfaceMetadataMode)
    case extendedRangeIntent(HDRExtendedRangeIntent)
}

enum HDRSurfaceApplicationOutcome: Equatable, Sendable {
    case applied(previous: HDRSurfaceContract?, current: HDRSurfaceContract)
    case unchanged(HDRSurfaceContract)
    case unsupported(
        platform: AppleRenderingPlatform,
        requested: HDRSurfaceContract
    )

    var activeContract: HDRSurfaceContract? {
        switch self {
        case let .applied(_, current), let .unchanged(current):
            return current
        case .unsupported:
            return nil
        }
    }
}

enum HDRSurfaceApplicationError: Error, Equatable, Sendable,
    CustomStringConvertible {
    case snapshotFailed
    case mutationFailed(HDRSurfaceMutation)
    case rollbackFailed(HDRSurfaceMutation)

    var description: String {
        switch self {
        case .snapshotFailed:
            return "The native Metal surface could not be inspected."
        case let .mutationFailed(mutation):
            return "The Metal surface rejected \(mutation). Its previous state was restored."
        case let .rollbackFailed(mutation):
            return "The Metal surface rejected \(mutation), and restoring its previous state failed."
        }
    }
}

@MainActor
protocol HDRSurfaceApplying: AnyObject {
    func apply(_ contract: HDRSurfaceContract) throws -> HDRSurfaceApplicationOutcome
}

@MainActor
protocol HDRSurfaceMutationBacking: AnyObject {
    associatedtype Snapshot

    var capabilities: HDRSurfaceAdapterCapabilities { get }

    func captureSnapshot() throws -> Snapshot
    func beginTransaction()
    func perform(_ mutation: HDRSurfaceMutation) throws
    func restore(_ snapshot: Snapshot) throws
    func endTransaction()
}

@MainActor
final class HDRSurfaceTransactionAdapter<Backend: HDRSurfaceMutationBacking>:
    HDRSurfaceApplying {
    private let backend: Backend
    private(set) var activeContract: HDRSurfaceContract?

    init(backend: Backend) {
        self.backend = backend
    }

    func apply(_ contract: HDRSurfaceContract) throws -> HDRSurfaceApplicationOutcome {
        guard backend.capabilities.supports(contract) else {
            return .unsupported(
                platform: backend.capabilities.platform,
                requested: contract
            )
        }
        guard activeContract != contract else {
            return .unchanged(contract)
        }

        let snapshot: Backend.Snapshot
        do {
            snapshot = try backend.captureSnapshot()
        } catch {
            throw HDRSurfaceApplicationError.snapshotFailed
        }

        let previous = activeContract
        backend.beginTransaction()
        for mutation in mutations(
            for: contract,
            support: backend.capabilities.extendedRangeSurfaceSupport
        ) {
            do {
                try backend.perform(mutation)
            } catch {
                do {
                    try backend.restore(snapshot)
                } catch {
                    activeContract = nil
                    backend.endTransaction()
                    throw HDRSurfaceApplicationError.rollbackFailed(mutation)
                }
                backend.endTransaction()
                throw HDRSurfaceApplicationError.mutationFailed(mutation)
            }
        }
        backend.endTransaction()
        activeContract = contract
        return .applied(previous: previous, current: contract)
    }

    private func mutations(
        for contract: HDRSurfaceContract,
        support: HDRExtendedRangeSurfaceSupport
    ) -> [HDRSurfaceMutation] {
        if contract.extendedRangeIntent == .disabled {
            var result: [HDRSurfaceMutation] = []
            if support != .unavailable {
                result.append(.extendedRangeIntent(.disabled))
            }
            if support == .intentAndMetadata {
                result.append(.metadata(.none))
            }
            result.append(.drawablePixelFormat(contract.drawablePixelFormat))
            result.append(.outputColorSpace(contract.outputColorSpace))
            return result
        }

        var result: [HDRSurfaceMutation] = [
            .drawablePixelFormat(contract.drawablePixelFormat),
            .outputColorSpace(contract.outputColorSpace)
        ]
        if support == .intentAndMetadata {
            result.append(.metadata(contract.metadataMode))
        }
        result.append(.extendedRangeIntent(contract.extendedRangeIntent))
        return result
    }
}

@MainActor
final class AppleMetalSurfaceAdapter: HDRSurfaceApplying {
    private let transactionAdapter:
        HDRSurfaceTransactionAdapter<AppleMetalSurfaceMutationBackend>

    init(
        view: MTKView,
        capabilities: HDRSurfaceAdapterCapabilities = .current
    ) {
        transactionAdapter = HDRSurfaceTransactionAdapter(
            backend: AppleMetalSurfaceMutationBackend(
                view: view,
                capabilities: capabilities
            )
        )
    }

    func apply(_ contract: HDRSurfaceContract) throws -> HDRSurfaceApplicationOutcome {
        try transactionAdapter.apply(contract)
    }
}

@MainActor
private final class AppleMetalSurfaceMutationBackend: HDRSurfaceMutationBacking {
    struct Snapshot {
        let viewPixelFormat: MTLPixelFormat
        let layerPixelFormat: MTLPixelFormat
        let colorSpace: CGColorSpace?
        let wantsExtendedRange: Bool?
        let metadata: AnyObject?
    }

    let capabilities: HDRSurfaceAdapterCapabilities
    private weak var view: MTKView?

    init(view: MTKView, capabilities: HDRSurfaceAdapterCapabilities) {
        self.view = view
        self.capabilities = capabilities
    }

    func captureSnapshot() throws -> Snapshot {
        let (view, layer) = try nativeSurface()
        #if os(macOS) || os(iOS) || os(visionOS)
        return Snapshot(
            viewPixelFormat: view.colorPixelFormat,
            layerPixelFormat: layer.pixelFormat,
            colorSpace: layer.colorspace,
            wantsExtendedRange: layer.wantsExtendedDynamicRangeContent,
            metadata: layer.edrMetadata
        )
        #else
        return Snapshot(
            viewPixelFormat: view.colorPixelFormat,
            layerPixelFormat: layer.pixelFormat,
            colorSpace: layer.colorspace,
            wantsExtendedRange: nil,
            metadata: nil
        )
        #endif
    }

    func beginTransaction() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
    }

    func perform(_ mutation: HDRSurfaceMutation) throws {
        let (view, layer) = try nativeSurface()
        switch mutation {
        case let .drawablePixelFormat(format):
            let metalFormat = format.metalPixelFormat
            view.colorPixelFormat = metalFormat
            layer.pixelFormat = metalFormat
        case let .outputColorSpace(outputColorSpace):
            guard let colorSpace = CGColorSpace(name: outputColorSpace.coreGraphicsName)
            else {
                throw AppleMetalSurfaceBackendError.colorSpaceUnavailable
            }
            layer.colorspace = colorSpace
        case let .metadata(mode):
            #if os(macOS) || os(iOS) || os(visionOS)
            switch mode {
            case .none:
                layer.edrMetadata = nil
            case .hdr10:
                guard CAEDRMetadata.isAvailable else {
                    throw AppleMetalSurfaceBackendError.metadataUnavailable
                }
                layer.edrMetadata = CAEDRMetadata.hdr10(
                    displayInfo: nil,
                    contentInfo: nil,
                    opticalOutputScale: Float(HDRLuminanceMapping.referenceWhiteNits)
                )
            }
            #else
            _ = mode
            throw AppleMetalSurfaceBackendError.extendedRangeUnavailable
            #endif
        case let .extendedRangeIntent(intent):
            #if os(macOS) || os(iOS) || os(visionOS)
            layer.wantsExtendedDynamicRangeContent = intent == .enabled
            #else
            _ = intent
            throw AppleMetalSurfaceBackendError.extendedRangeUnavailable
            #endif
        }
    }

    func restore(_ snapshot: Snapshot) throws {
        let (view, layer) = try nativeSurface()
        #if os(macOS) || os(iOS) || os(visionOS)
        layer.wantsExtendedDynamicRangeContent = false
        layer.edrMetadata = snapshot.metadata as? CAEDRMetadata
        #endif
        view.colorPixelFormat = snapshot.viewPixelFormat
        layer.pixelFormat = snapshot.layerPixelFormat
        layer.colorspace = snapshot.colorSpace
        #if os(macOS) || os(iOS) || os(visionOS)
        layer.wantsExtendedDynamicRangeContent = snapshot.wantsExtendedRange ?? false
        #endif
    }

    func endTransaction() {
        CATransaction.commit()
    }

    private func nativeSurface() throws -> (MTKView, CAMetalLayer) {
        guard let view, let layer = view.layer as? CAMetalLayer else {
            throw AppleMetalSurfaceBackendError.surfaceUnavailable
        }
        return (view, layer)
    }
}

private enum AppleMetalSurfaceBackendError: Error {
    case surfaceUnavailable
    case colorSpaceUnavailable
    case extendedRangeUnavailable
    case metadataUnavailable
}

private extension HDRDrawablePixelFormat {
    var metalPixelFormat: MTLPixelFormat {
        switch self {
        case .bgra8UnormSRGB:
            return .bgra8Unorm_srgb
        case .rgba16Float:
            return .rgba16Float
        }
    }
}

private extension HDROutputColorSpace {
    var coreGraphicsName: CFString {
        switch self {
        case .sRGB:
            return CGColorSpace.sRGB
        case .extendedLinearDisplayP3:
            return CGColorSpace.extendedLinearDisplayP3
        case .extendedLinearITUR2020:
            return CGColorSpace.extendedLinearITUR_2020
        }
    }
}
