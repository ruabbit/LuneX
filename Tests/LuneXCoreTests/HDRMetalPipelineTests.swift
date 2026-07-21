import Foundation
@preconcurrency import Metal
import XCTest

final class HDRMetalPipelineTests: XCTestCase {
    func testShaderUniformsHaveExactMetalABIAndTypedSDRValues() throws {
        let contract = frameContract(metadata: .rec709VideoRange(), layout: .nv12VideoRange8)
        let configuration = try makeConfiguration(
            metadata: .rec709VideoRange(),
            mappingMode: .sdr,
            surface: .sdr
        )
        let uniforms = try HDRMetalShaderUniforms(
            frameContract: contract,
            configuration: configuration,
            luminanceMapping: nil
        )

        XCTAssertTrue(HDRMetalShaderUniforms.hasExpectedMemoryLayout)
        XCTAssertEqual(MemoryLayout<HDRMetalShaderUniforms>.size, 32)
        XCTAssertEqual(MemoryLayout<HDRMetalShaderUniforms>.stride, 32)
        XCTAssertEqual(uniforms.inputBitDepth, 8)
        XCTAssertEqual(uniforms.yCbCrMatrix, 0)
        XCTAssertEqual(uniforms.transferFunction, 0)
        XCTAssertEqual(uniforms.outputGamut, 0)
        XCTAssertEqual(uniforms.mappingMode, 0)
        XCTAssertEqual(uniforms.sourcePeakNits, 100)
        XCTAssertEqual(uniforms.currentHeadroom, 1)
        XCTAssertEqual(uniforms.reserved, 0)
    }

    func testHDRUniformsEncodeEDRAndSDRFallbackWithoutPromotingFallbackWhite() throws {
        let metadata = VideoColorMetadata.hdr10VideoRange()
        let contract = frameContract(metadata: metadata, layout: .p010VideoRange10)
        let mapping = try HDRLuminanceMapping(
            sourcePeak: try HDRSourcePeakResolver.resolve(metadata),
            currentHeadroom: 4
        )
        let edr = try HDRMetalShaderUniforms(
            frameContract: contract,
            configuration: makeConfiguration(
                metadata: metadata,
                mappingMode: .hdrEDR,
                surface: .displayP3EDR
            ),
            luminanceMapping: mapping
        )
        let fallback = try HDRMetalShaderUniforms(
            frameContract: contract,
            configuration: makeConfiguration(
                metadata: metadata,
                mappingMode: .hdrToSDR,
                surface: .sdr
            ),
            luminanceMapping: HDRLuminanceMapping(
                sourcePeak: mapping.sourcePeak,
                currentHeadroom: 1
            )
        )

        XCTAssertEqual(edr.inputBitDepth, 10)
        XCTAssertEqual(edr.yCbCrMatrix, 1)
        XCTAssertEqual(edr.transferFunction, 1)
        XCTAssertEqual(edr.outputGamut, 1)
        XCTAssertEqual(edr.mappingMode, 1)
        XCTAssertEqual(edr.sourcePeakNits, 1_000)
        XCTAssertEqual(edr.currentHeadroom, 4)
        XCTAssertEqual(fallback.outputGamut, 0)
        XCTAssertEqual(fallback.mappingMode, 2)
        XCTAssertEqual(fallback.sourcePeakNits, 1_000)
        XCTAssertEqual(fallback.currentHeadroom, 1)
        XCTAssertThrowsError(try HDRMetalShaderUniforms(
            frameContract: contract,
            configuration: makeConfiguration(
                metadata: metadata,
                mappingMode: .hdrToSDR,
                surface: .sdr
            ),
            luminanceMapping: mapping
        )) { error in
            XCTAssertEqual(error as? HDRMetalPipelineError, .invalidSDRFallbackHeadroom)
        }
    }

    func testUniformAndPipelineKeyValidationFailClosed() throws {
        let sdrMetadata = VideoColorMetadata.rec709VideoRange()
        let sdrContract = frameContract(metadata: sdrMetadata, layout: .nv12VideoRange8)
        let sdrConfiguration = try makeConfiguration(
            metadata: sdrMetadata,
            mappingMode: .sdr,
            surface: .sdr
        )
        let mapping = try HDRLuminanceMapping(
            sourcePeak: try HDRSourcePeakResolver.resolve(
                VideoColorMetadata.hdr10VideoRange()
            ),
            currentHeadroom: 2
        )

        XCTAssertThrowsError(try HDRMetalShaderUniforms(
            frameContract: sdrContract,
            configuration: sdrConfiguration,
            luminanceMapping: mapping
        )) { error in
            XCTAssertEqual(error as? HDRMetalPipelineError, .unexpectedLuminanceMapping)
        }
        XCTAssertThrowsError(try HDRMetalPipelineKey(
            inputLayout: .nv12VideoRange8,
            mappingMode: .hdrEDR,
            outputPixelFormat: .rgba16Float
        )) { error in
            XCTAssertEqual(error as? HDRMetalPipelineError, .incompatiblePipelineKey)
        }

        let hdrMetadata = VideoColorMetadata.hdr10VideoRange()
        let staleMapping = try HDRLuminanceMapping(
            sourcePeak: HDRSourcePeak(
                luminanceNits: 600,
                basis: .contentLight,
                wasClamped: false
            ),
            currentHeadroom: 2
        )
        XCTAssertThrowsError(try HDRMetalShaderUniforms(
            frameContract: frameContract(
                metadata: hdrMetadata,
                layout: .p010VideoRange10
            ),
            configuration: makeConfiguration(
                metadata: hdrMetadata,
                mappingMode: .hdrEDR,
                surface: .displayP3EDR
            ),
            luminanceMapping: staleMapping
        )) { error in
            XCTAssertEqual(error as? HDRMetalPipelineError, .staleLuminanceMapping)
        }
        XCTAssertThrowsError(try HDRMetalPipelineKey(
            inputLayout: .p010VideoRange10,
            mappingMode: .hdrToSDR,
            outputPixelFormat: .rgba16Float
        )) { error in
            XCTAssertEqual(error as? HDRMetalPipelineError, .incompatiblePipelineKey)
        }
    }

    func testProductionFactoryBuildsAllLegalPipelineStates() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let factory = try AppleHDRMetalPipelineStateFactory(
            device: device,
            bundle: Bundle(for: Self.self)
        )
        for key in try legalKeys() {
            let state = try factory.makePipelineState(for: key)
            XCTAssertEqual(state.key, key)
            XCTAssertEqual(state.rawValue.device.registryID, device.registryID)
        }
    }

    func testCacheIsBoundedLRUAndReturnsIdenticalCachedState() async throws {
        let factory = try CountingHDRMetalPipelineFactory()
        let cache = try HDRMetalPipelineStateCache(capacity: 2, factory: factory)
        let keys = try legalKeys()

        let first = try cache.pipelineState(for: keys[0])
        _ = try cache.pipelineState(for: keys[1])
        let hit = try cache.pipelineState(for: keys[0])
        _ = try cache.pipelineState(for: keys[2])

        XCTAssertTrue(first === hit)
        var snapshot = cache.snapshot()
        XCTAssertEqual(snapshot.keysByLeastRecentUse, [keys[0], keys[2]])
        XCTAssertEqual(snapshot.hitCount, 1)
        XCTAssertEqual(snapshot.missCount, 3)
        XCTAssertEqual(snapshot.evictionCount, 1)
        XCTAssertEqual(factory.creationCount, 3)

        cache.removeAll()
        cache.removeAll()
        snapshot = cache.snapshot()
        XCTAssertTrue(snapshot.keysByLeastRecentUse.isEmpty)
        XCTAssertEqual(snapshot.flushCount, 1)
    }

    func testCreationFailureIsNotCachedAndLaterRetrySucceeds() throws {
        let factory = try CountingHDRMetalPipelineFactory(failFirstCreation: true)
        let cache = try HDRMetalPipelineStateCache(capacity: 1, factory: factory)
        let key = try legalKeys()[0]

        XCTAssertThrowsError(try cache.pipelineState(for: key)) { error in
            XCTAssertEqual(error as? HDRMetalPipelineError, .pipelineCreationFailed)
        }
        _ = try cache.pipelineState(for: key)
        let snapshot = cache.snapshot()
        XCTAssertEqual(snapshot.creationFailureCount, 1)
        XCTAssertEqual(snapshot.missCount, 2)
        XCTAssertEqual(snapshot.keysByLeastRecentUse, [key])
        XCTAssertEqual(factory.creationCount, 2)
    }

    func testConcurrentRequestsForOneKeyCreateOneState() async throws {
        let factory = try CountingHDRMetalPipelineFactory()
        let cache = try HDRMetalPipelineStateCache(capacity: 2, factory: factory)
        let key = try legalKeys()[1]

        async let first = cache.pipelineState(for: key)
        async let second = cache.pipelineState(for: key)
        async let third = cache.pipelineState(for: key)
        let states = try await [first, second, third]

        XCTAssertTrue(states[0] === states[1])
        XCTAssertTrue(states[1] === states[2])
        XCTAssertEqual(factory.creationCount, 1)
        let snapshot = cache.snapshot()
        XCTAssertEqual(snapshot.missCount, 1)
        XCTAssertEqual(snapshot.hitCount, 2)
    }

    func testCacheRejectsUnboundedCapacities() throws {
        let factory = try CountingHDRMetalPipelineFactory()
        for capacity in [0, HDRMetalPipelineStateCache.maximumCapacity + 1] {
            XCTAssertThrowsError(try HDRMetalPipelineStateCache(
                capacity: capacity,
                factory: factory
            )) { error in
                XCTAssertEqual(error as? HDRMetalPipelineError, .invalidCacheCapacity)
            }
        }
    }

    private func legalKeys() throws -> [HDRMetalPipelineKey] {
        try [
            HDRMetalPipelineKey(
                inputLayout: .nv12VideoRange8,
                mappingMode: .sdr,
                outputPixelFormat: .bgra8UnormSRGB
            ),
            HDRMetalPipelineKey(
                inputLayout: .p010VideoRange10,
                mappingMode: .hdrEDR,
                outputPixelFormat: .rgba16Float
            ),
            HDRMetalPipelineKey(
                inputLayout: .p010VideoRange10,
                mappingMode: .hdrToSDR,
                outputPixelFormat: .bgra8UnormSRGB
            )
        ]
    }

    private func frameContract(
        metadata: VideoColorMetadata,
        layout: HDRDecodedPixelLayout
    ) -> HDRValidatedDecodedFrameContract {
        HDRValidatedDecodedFrameContract(
            pixelLayout: layout,
            width: 64,
            height: 48,
            colorSignature: HDRRenderColorSignature(metadata: metadata)
        )
    }

    private func makeConfiguration(
        metadata: VideoColorMetadata,
        mappingMode: HDRMappingMode,
        surface: TestSurface
    ) throws -> HDRRenderConfigurationIdentity {
        try HDRRenderConfigurationIdentity(
            decoderGeneration: 1,
            colorSignature: HDRRenderColorSignature(metadata: metadata),
            displayRevision: HDRDisplayRevision(rawValue: 1),
            mappingMode: mappingMode,
            surfaceContract: surface.contract
        )
    }
}

private enum TestSurface {
    case sdr
    case displayP3EDR

    var contract: HDRSurfaceContract {
        get throws {
            switch self {
            case .sdr:
                try HDRSurfaceContract(
                    drawablePixelFormat: .bgra8UnormSRGB,
                    outputColorSpace: .sRGB,
                    outputGamut: .sRGB,
                    extendedRangeIntent: .disabled,
                    metadataMode: .none
                )
            case .displayP3EDR:
                try HDRSurfaceContract(
                    drawablePixelFormat: .rgba16Float,
                    outputColorSpace: .extendedLinearDisplayP3,
                    outputGamut: .displayP3,
                    extendedRangeIntent: .enabled,
                    metadataMode: .hdr10
                )
            }
        }
    }
}

private final class CountingHDRMetalPipelineFactory: HDRMetalPipelineStateCreating,
    @unchecked Sendable {
    private let lock = NSLock()
    private let rawState: any MTLRenderPipelineState
    private var storedCreationCount = 0
    private var shouldFailNextCreation: Bool

    var creationCount: Int { lock.withLock { storedCreationCount } }

    init(failFirstCreation: Bool = false) throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let factory = try AppleHDRMetalPipelineStateFactory(
            device: device,
            bundle: Bundle(for: HDRMetalPipelineTests.self)
        )
        let key = try HDRMetalPipelineKey(
            inputLayout: .nv12VideoRange8,
            mappingMode: .sdr,
            outputPixelFormat: .bgra8UnormSRGB
        )
        rawState = try factory.makePipelineState(for: key).rawValue
        shouldFailNextCreation = failFirstCreation
    }

    func makePipelineState(for key: HDRMetalPipelineKey) throws -> HDRMetalPipelineState {
        let shouldFail = lock.withLock { () -> Bool in
            storedCreationCount += 1
            defer { shouldFailNextCreation = false }
            return shouldFailNextCreation
        }
        if shouldFail {
            throw HDRMetalPipelineError.pipelineCreationFailed
        }
        return HDRMetalPipelineState(key: key, rawValue: rawState)
    }
}
