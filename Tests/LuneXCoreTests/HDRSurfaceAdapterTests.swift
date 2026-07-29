import MetalKit
import QuartzCore
import XCTest

final class HDRSurfaceAdapterTests: XCTestCase {
    func testSurfaceCapabilitiesDeriveFromPlatformOutputAdapter() {
        let platforms: [AppleRenderingPlatform] = [
            .macOS, .iOS, .tvOS, .visionOS
        ]

        for platform in platforms {
            let output = HDRPlatformOutputCapabilityAdapter.resolve(for: platform)
            let surface = HDRSurfaceAdapterCapabilities(
                platformCapabilities: output.capabilities
            )

            XCTAssertEqual(surface.platform, output.capabilities.platform)
            XCTAssertEqual(
                surface.extendedRangeSurfaceSupport,
                output.capabilities.extendedRangeSurfaceSupport
            )
            XCTAssertEqual(
                surface.supportedEDRGamuts,
                output.capabilities.supportedEDRGamuts
            )
        }

        #if os(macOS)
        XCTAssertEqual(
            HDRSurfaceAdapterCapabilities.current,
            HDRSurfaceAdapterCapabilities(
                platformCapabilities:
                    HDRPlatformOutputCapabilityAdapter.current.capabilities
            )
        )
        #endif
    }

    @MainActor
    func testEDRApplicationUsesSafeOrderedTransactionAndIsIdempotent() throws {
        let backend = RecordingHDRSurfaceBackend(capabilities: .macOS)
        let adapter = HDRSurfaceTransactionAdapter(backend: backend)
        let contract = try makeEDRSurface()

        let outcome = try adapter.apply(contract)

        XCTAssertEqual(outcome, .applied(previous: nil, current: contract))
        XCTAssertEqual(adapter.activeContract, contract)
        XCTAssertEqual(backend.calls, [
            .captureSnapshot,
            .beginTransaction,
            .mutation(.drawablePixelFormat(.rgba16Float)),
            .mutation(.outputColorSpace(.extendedLinearDisplayP3)),
            .mutation(.metadata(.hdr10)),
            .mutation(.extendedRangeIntent(.enabled)),
            .endTransaction
        ])

        let callCount = backend.calls.count
        XCTAssertEqual(try adapter.apply(contract), .unchanged(contract))
        XCTAssertEqual(backend.calls.count, callCount)
    }

    @MainActor
    func testReturningToSDRDisablesIntentBeforeReplacingSurface() throws {
        let backend = RecordingHDRSurfaceBackend(capabilities: .macOS)
        let adapter = HDRSurfaceTransactionAdapter(backend: backend)
        let edr = try makeEDRSurface()
        let sdr = try makeSDRSurface()
        _ = try adapter.apply(edr)
        backend.calls.removeAll()

        let outcome = try adapter.apply(sdr)

        XCTAssertEqual(outcome, .applied(previous: edr, current: sdr))
        XCTAssertEqual(backend.calls, [
            .captureSnapshot,
            .beginTransaction,
            .mutation(.extendedRangeIntent(.disabled)),
            .mutation(.metadata(.none)),
            .mutation(.drawablePixelFormat(.bgra8UnormSRGB)),
            .mutation(.outputColorSpace(.sRGB)),
            .endTransaction
        ])
    }

    @MainActor
    func testUnsupportedEDRReturnsTypedOutcomeWithoutTouchingBackend() throws {
        let backend = RecordingHDRSurfaceBackend(capabilities: .tvOS)
        let adapter = HDRSurfaceTransactionAdapter(backend: backend)
        let contract = try makeEDRSurface()

        XCTAssertEqual(
            try adapter.apply(contract),
            .unsupported(platform: .tvOS, requested: contract)
        )
        XCTAssertNil(adapter.activeContract)
        XCTAssertTrue(backend.calls.isEmpty)
    }

    @MainActor
    func testUnsupportedPlatformStillAppliesSDRFormatAndColorSpace() throws {
        let backend = RecordingHDRSurfaceBackend(capabilities: .tvOS)
        let adapter = HDRSurfaceTransactionAdapter(backend: backend)
        let contract = try makeSDRSurface()

        XCTAssertEqual(
            try adapter.apply(contract),
            .applied(previous: nil, current: contract)
        )
        XCTAssertEqual(backend.calls, [
            .captureSnapshot,
            .beginTransaction,
            .mutation(.drawablePixelFormat(.bgra8UnormSRGB)),
            .mutation(.outputColorSpace(.sRGB)),
            .endTransaction
        ])
    }

    @MainActor
    func testIntentOnlyCapabilityOmitsUnsupportedMetadataMutation() throws {
        let backend = RecordingHDRSurfaceBackend(
            capabilities: HDRSurfaceAdapterCapabilities(
                platform: .iOS,
                extendedRangeSurfaceSupport: .intentOnly,
                supportedEDRGamuts: [.displayP3]
            )
        )
        let adapter = HDRSurfaceTransactionAdapter(backend: backend)
        let contract = try makeEDRSurface()

        _ = try adapter.apply(contract)

        XCTAssertEqual(backend.calls, [
            .captureSnapshot,
            .beginTransaction,
            .mutation(.drawablePixelFormat(.rgba16Float)),
            .mutation(.outputColorSpace(.extendedLinearDisplayP3)),
            .mutation(.extendedRangeIntent(.enabled)),
            .endTransaction
        ])
    }

    @MainActor
    func testMutationFailureRestoresSnapshotAndPreservesPriorContract() throws {
        let backend = RecordingHDRSurfaceBackend(capabilities: .macOS)
        let adapter = HDRSurfaceTransactionAdapter(backend: backend)
        let sdr = try makeSDRSurface()
        _ = try adapter.apply(sdr)
        let priorState = backend.state
        backend.calls.removeAll()
        backend.failingMutation = .outputColorSpace(.extendedLinearDisplayP3)

        XCTAssertThrowsError(try adapter.apply(makeEDRSurface())) { error in
            XCTAssertEqual(
                error as? HDRSurfaceApplicationError,
                .mutationFailed(.outputColorSpace(.extendedLinearDisplayP3))
            )
        }
        XCTAssertEqual(adapter.activeContract, sdr)
        XCTAssertEqual(backend.state, priorState)
        XCTAssertEqual(backend.calls, [
            .captureSnapshot,
            .beginTransaction,
            .mutation(.drawablePixelFormat(.rgba16Float)),
            .mutation(.outputColorSpace(.extendedLinearDisplayP3)),
            .restoreSnapshot,
            .endTransaction
        ])
    }

    @MainActor
    func testRollbackFailureClearsReportedOwnership() throws {
        let backend = RecordingHDRSurfaceBackend(capabilities: .macOS)
        let adapter = HDRSurfaceTransactionAdapter(backend: backend)
        _ = try adapter.apply(makeSDRSurface())
        backend.calls.removeAll()
        backend.failingMutation = .metadata(.hdr10)
        backend.failsRestore = true

        XCTAssertThrowsError(try adapter.apply(makeEDRSurface())) { error in
            XCTAssertEqual(
                error as? HDRSurfaceApplicationError,
                .rollbackFailed(.metadata(.hdr10))
            )
        }
        XCTAssertNil(adapter.activeContract)
        XCTAssertEqual(backend.calls, [
            .captureSnapshot,
            .beginTransaction,
            .mutation(.drawablePixelFormat(.rgba16Float)),
            .mutation(.outputColorSpace(.extendedLinearDisplayP3)),
            .mutation(.metadata(.hdr10)),
            .restoreSnapshot,
            .endTransaction
        ])
    }

    @MainActor
    func testAppleMetalBackendAppliesAndRestoresNativeSDRAndEDRFields() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let view = MTKView(frame: .zero, device: device)
        let layer = try XCTUnwrap(view.layer as? CAMetalLayer)
        let adapter = AppleMetalSurfaceAdapter(view: view)
        let sdr = try makeSDRSurface()
        let edr = try makeEDRSurface()

        XCTAssertEqual(
            try adapter.apply(sdr),
            .applied(previous: nil, current: sdr)
        )
        XCTAssertEqual(view.colorPixelFormat, .bgra8Unorm_srgb)
        XCTAssertEqual(layer.pixelFormat, .bgra8Unorm_srgb)
        XCTAssertEqual(layer.colorspace?.name, CGColorSpace.sRGB)
        XCTAssertFalse(layer.wantsExtendedDynamicRangeContent)
        XCTAssertNil(layer.edrMetadata)

        XCTAssertTrue(CAEDRMetadata.isAvailable)
        XCTAssertEqual(
            try adapter.apply(edr),
            .applied(previous: sdr, current: edr)
        )
        XCTAssertEqual(view.colorPixelFormat, .rgba16Float)
        XCTAssertEqual(layer.pixelFormat, .rgba16Float)
        XCTAssertEqual(
            layer.colorspace?.name,
            CGColorSpace.extendedLinearDisplayP3
        )
        XCTAssertTrue(layer.wantsExtendedDynamicRangeContent)
        XCTAssertNotNil(layer.edrMetadata)

        XCTAssertEqual(
            try adapter.apply(sdr),
            .applied(previous: edr, current: sdr)
        )
        XCTAssertEqual(view.colorPixelFormat, .bgra8Unorm_srgb)
        XCTAssertEqual(layer.pixelFormat, .bgra8Unorm_srgb)
        XCTAssertEqual(layer.colorspace?.name, CGColorSpace.sRGB)
        XCTAssertFalse(layer.wantsExtendedDynamicRangeContent)
        XCTAssertNil(layer.edrMetadata)
    }

    private func makeSDRSurface() throws -> HDRSurfaceContract {
        try HDRSurfaceContract(
            drawablePixelFormat: .bgra8UnormSRGB,
            outputColorSpace: .sRGB,
            outputGamut: .sRGB,
            extendedRangeIntent: .disabled,
            metadataMode: .none
        )
    }

    private func makeEDRSurface() throws -> HDRSurfaceContract {
        try HDRSurfaceContract(
            drawablePixelFormat: .rgba16Float,
            outputColorSpace: .extendedLinearDisplayP3,
            outputGamut: .displayP3,
            extendedRangeIntent: .enabled,
            metadataMode: .hdr10
        )
    }
}

@MainActor
private final class RecordingHDRSurfaceBackend: HDRSurfaceMutationBacking {
    struct Snapshot {
        let state: [HDRSurfaceMutation]
    }

    enum Call: Equatable {
        case captureSnapshot
        case beginTransaction
        case mutation(HDRSurfaceMutation)
        case restoreSnapshot
        case endTransaction
    }

    let capabilities: HDRSurfaceAdapterCapabilities
    var state: [HDRSurfaceMutation] = []
    var calls: [Call] = []
    var failingMutation: HDRSurfaceMutation?
    var failsRestore = false

    init(capabilities: HDRSurfaceAdapterCapabilities) {
        self.capabilities = capabilities
    }

    func captureSnapshot() throws -> Snapshot {
        calls.append(.captureSnapshot)
        return Snapshot(state: state)
    }

    func beginTransaction() {
        calls.append(.beginTransaction)
    }

    func perform(_ mutation: HDRSurfaceMutation) throws {
        calls.append(.mutation(mutation))
        state.append(mutation)
        if mutation == failingMutation {
            throw RecordingHDRSurfaceBackendError.injectedFailure
        }
    }

    func restore(_ snapshot: Snapshot) throws {
        calls.append(.restoreSnapshot)
        if failsRestore {
            throw RecordingHDRSurfaceBackendError.injectedFailure
        }
        state = snapshot.state
    }

    func endTransaction() {
        calls.append(.endTransaction)
    }
}

private extension HDRSurfaceAdapterCapabilities {
    static let macOS = Self(
        platform: .macOS,
        extendedRangeSurfaceSupport: .intentAndMetadata,
        supportedEDRGamuts: [.displayP3, .ituR2020]
    )

    static let tvOS = Self(
        platform: .tvOS,
        extendedRangeSurfaceSupport: .unavailable,
        supportedEDRGamuts: []
    )
}

private enum RecordingHDRSurfaceBackendError: Error {
    case injectedFailure
}
