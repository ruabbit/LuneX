import CoreVideo
import XCTest

final class HDRRenderConfigurationResolverTests: XCTestCase {
    func testSDRRemainsSDROnEligibleEDRDisplay() throws {
        let previous = try makeEDRSurface(gamut: .displayP3)
        let resolution = HDRRenderConfigurationResolver.resolve(makeInput(
            colorMetadata: .rec709VideoRange(),
            userAllowsHDR: false,
            display: makeDisplay(current: 4),
            drawableState: HDRDrawableState(
                isAvailable: true,
                appliedSurfaceContract: previous
            )
        ))
        let configuration = try XCTUnwrap(resolution.configuration)

        XCTAssertEqual(configuration.outputMode, .sdr)
        XCTAssertEqual(configuration.identity.mappingMode, .sdr)
        XCTAssertEqual(configuration.identity.surfaceContract, try makeSDRSurface())
        XCTAssertNil(configuration.luminanceMapping)
        XCTAssertEqual(
            configuration.surfaceState,
            .requiresApplication(previous: previous)
        )
    }

    func testEligibleHDRResolvesEDRUsingCurrentHeadroomAndITU2020() throws {
        let sdr = try makeSDRSurface()
        let resolution = HDRRenderConfigurationResolver.resolve(makeInput(
            colorMetadata: .hdr10VideoRange(),
            display: makeDisplay(
                revision: 9,
                potential: 6,
                current: 2.5,
                reference: 1.25
            ),
            drawableState: HDRDrawableState(
                isAvailable: true,
                appliedSurfaceContract: sdr
            )
        ))
        let configuration = try XCTUnwrap(resolution.configuration)

        XCTAssertEqual(configuration.outputMode, .edr)
        XCTAssertEqual(configuration.identity.decoderGeneration, 7)
        XCTAssertEqual(
            configuration.identity.displayRevision,
            HDRDisplayRevision(rawValue: 9)
        )
        XCTAssertEqual(configuration.identity.mappingMode, .hdrEDR)
        XCTAssertEqual(configuration.identity.surfaceContract.outputGamut, .ituR2020)
        XCTAssertEqual(
            configuration.identity.surfaceContract.outputColorSpace,
            .extendedLinearITUR2020
        )
        XCTAssertEqual(configuration.luminanceMapping?.currentHeadroom, 2.5)
        XCTAssertEqual(
            configuration.surfaceState,
            .requiresApplication(previous: sdr)
        )
    }

    func testEDRSelectsDisplayP3WhenITU2020IsUnavailable() throws {
        let resolution = HDRRenderConfigurationResolver.resolve(makeInput(
            colorMetadata: .hdr10VideoRange(),
            capabilities: HDRPlatformOutputCapabilities(
                platform: .visionOS,
                headroomSource: .currentAndPotential,
                extendedRangeSurfaceSupport: .intentAndMetadata,
                supportedEDRGamuts: [.displayP3],
                supportsSDRToneMapping: true
            ),
            display: makeDisplay(current: 2)
        ))
        let configuration = try XCTUnwrap(resolution.configuration)

        XCTAssertEqual(configuration.outputMode, .edr)
        XCTAssertEqual(configuration.identity.surfaceContract.outputGamut, .displayP3)
        XCTAssertEqual(
            configuration.identity.surfaceContract.outputColorSpace,
            .extendedLinearDisplayP3
        )
    }

    func testMatchingAppliedSurfaceIsReadyWithoutTransition() throws {
        let edr = try makeEDRSurface(gamut: .ituR2020)
        let resolution = HDRRenderConfigurationResolver.resolve(makeInput(
            colorMetadata: .hdr10VideoRange(),
            display: makeDisplay(current: 2),
            drawableState: HDRDrawableState(
                isAvailable: true,
                appliedSurfaceContract: edr
            )
        ))

        XCTAssertEqual(
            try XCTUnwrap(resolution.configuration).surfaceState,
            .ready
        )
    }

    func testUserDisabledHDRUsesTypedSDRFallback() throws {
        let resolution = HDRRenderConfigurationResolver.resolve(makeInput(
            colorMetadata: .hdr10VideoRange(),
            userAllowsHDR: false,
            display: makeDisplay(current: 3)
        ))
        let configuration = try XCTUnwrap(resolution.configuration)

        XCTAssertEqual(
            configuration.outputMode,
            .sdrFallback(.userPreferenceDisabled)
        )
        XCTAssertEqual(configuration.identity.mappingMode, .hdrToSDR)
        XCTAssertEqual(configuration.identity.surfaceContract, try makeSDRSurface())
        XCTAssertEqual(configuration.luminanceMapping?.currentHeadroom, 1)
    }

    func testUnsupportedPlatformUsesTypedSDRFallback() throws {
        let platformResolution = HDRPlatformOutputCapabilityAdapter.resolve(
            for: .tvOS
        )
        XCTAssertEqual(
            platformResolution.fallbackReason,
            .extendedRangeSurfaceUnavailable
        )
        let resolution = HDRRenderConfigurationResolver.resolve(makeInput(
            colorMetadata: .hdr10VideoRange(),
            capabilities: platformResolution.capabilities,
            display: makeDisplay(current: 3)
        ))

        XCTAssertEqual(
            try XCTUnwrap(resolution.configuration).outputMode,
            .sdrFallback(.platformOutputUnsupported(.tvOS))
        )
    }

    func testVisionPlatformUsesCurrentHeadroomUnavailableFallback() throws {
        let platformResolution = HDRPlatformOutputCapabilityAdapter.resolve(
            for: .visionOS
        )
        XCTAssertEqual(
            platformResolution.fallbackReason,
            .currentHeadroomUnavailable
        )

        let resolution = HDRRenderConfigurationResolver.resolve(makeInput(
            colorMetadata: .hdr10VideoRange(),
            capabilities: platformResolution.capabilities,
            display: makeDisplay(current: 3)
        ))

        XCTAssertEqual(
            try XCTUnwrap(resolution.configuration).outputMode,
            .sdrFallback(.currentHeadroomUnavailable)
        )
    }

    func testHeadroomFallbackReasonsRemainDistinct() throws {
        let cases: [(
            HDRPlatformOutputCapabilities,
            DisplayHeadroom,
            HDRSDRFallbackReason
        )] = [
            (
                HDRPlatformOutputCapabilities(
                    platform: .visionOS,
                    headroomSource: .unavailable,
                    extendedRangeSurfaceSupport: .intentAndMetadata,
                    supportedEDRGamuts: [.displayP3],
                    supportsSDRToneMapping: true
                ),
                DisplayHeadroom(potential: 3, current: 2, reference: 1),
                .currentHeadroomUnavailable
            ),
            (
                .macOS,
                DisplayHeadroom(potential: 3, current: .nan, reference: 1),
                .currentHeadroomInvalid
            ),
            (
                .macOS,
                DisplayHeadroom(potential: 3, current: .infinity, reference: 1),
                .currentHeadroomInvalid
            ),
            (
                .macOS,
                DisplayHeadroom(potential: 65, current: 65, reference: 1),
                .currentHeadroomInvalid
            ),
            (
                .macOS,
                DisplayHeadroom(potential: 3, current: 1, reference: 1),
                .currentHeadroomInsufficient
            )
        ]

        for (capabilities, headroom, reason) in cases {
            let resolution = HDRRenderConfigurationResolver.resolve(makeInput(
                colorMetadata: .hdr10VideoRange(),
                capabilities: capabilities,
                display: HDRDisplaySnapshot(
                    revision: HDRDisplayRevision(rawValue: 5),
                    displayID: "not-published",
                    headroom: headroom
                )
            ))
            XCTAssertEqual(
                try XCTUnwrap(resolution.configuration).outputMode,
                .sdrFallback(reason)
            )
        }
    }

    func testUnavailableFallbackReturnsTypedClosedErrors() {
        let capabilities = HDRPlatformOutputCapabilities(
            platform: .macOS,
            headroomSource: .currentPotentialAndReference,
            extendedRangeSurfaceSupport: .intentAndMetadata,
            supportedEDRGamuts: [.displayP3, .ituR2020],
            supportsSDRToneMapping: false
        )

        XCTAssertEqual(
            HDRRenderConfigurationResolver.resolve(makeInput(
                colorMetadata: .hdr10VideoRange(),
                userAllowsHDR: false,
                capabilities: capabilities
            )).error,
            .userDisabledHDRWithoutSDRFallback
        )
        XCTAssertEqual(
            HDRRenderConfigurationResolver.resolve(makeInput(
                colorMetadata: .hdr10VideoRange(),
                capabilities: capabilities,
                display: makeDisplay(current: 1)
            )).error,
            .insufficientCurrentDisplayHeadroom
        )
        XCTAssertEqual(
            HDRRenderConfigurationResolver.resolve(makeInput(
                colorMetadata: .hdr10VideoRange(),
                capabilities: HDRPlatformOutputCapabilities(
                    platform: .tvOS,
                    headroomSource: .currentAndPotential,
                    extendedRangeSurfaceSupport: .unavailable,
                    supportedEDRGamuts: [],
                    supportsSDRToneMapping: false
                )
            )).error,
            .unsupportedPlatformOutput(.tvOS)
        )
    }

    func testOwnershipAndDrawableGatesFailClosed() {
        XCTAssertEqual(
            HDRRenderConfigurationResolver.resolve(makeInput(
                decoderGeneration: 0
            )).error,
            .inactiveSession
        )
        XCTAssertEqual(
            HDRRenderConfigurationResolver.resolve(makeInput(
                display: nil,
                isDisplayRevisionExhausted: true
            )).error,
            .displayRevisionExhausted
        )
        XCTAssertEqual(
            HDRRenderConfigurationResolver.resolve(makeInput(
                includesDisplaySnapshot: false
            )).error,
            .invalidDisplayRevision
        )
        XCTAssertEqual(
            HDRRenderConfigurationResolver.resolve(makeInput(
                display: makeDisplay(revision: 0, current: 2)
            )).error,
            .invalidDisplayRevision
        )
        XCTAssertEqual(
            HDRRenderConfigurationResolver.resolve(makeInput(
                drawableState: HDRDrawableState(
                    isAvailable: false,
                    appliedSurfaceContract: nil
                )
            )).error,
            .drawableUnavailable
        )
    }

    func testInvalidMetadataAndDecodedLayoutFailClosed() {
        let invalidMetadata = VideoColorMetadata.hdr10VideoRange(
            contentLight: VideoContentLightMetadata(
                maximumContentLightLevelNits: 0,
                maximumFrameAverageLightLevelNits: 0
            )
        )
        XCTAssertEqual(
            HDRRenderConfigurationResolver.resolve(makeInput(
                colorMetadata: invalidMetadata
            )).error,
            .invalidSourceContract
        )

        let unsupportedLayout = HDRDecodedPixelBufferLayout(
            pixelFormat: kCVPixelFormatType_32BGRA,
            width: 1_920,
            height: 1_080,
            planes: []
        )
        XCTAssertEqual(
            HDRRenderConfigurationResolver.resolve(makeInput(
                decodedLayout: unsupportedLayout
            )).error,
            .unsupportedDecodedLayout
        )
    }

    func testDisplayIdentityDoesNotEnterResolvedConfiguration() {
        let first = HDRRenderConfigurationResolver.resolve(makeInput(
            display: makeDisplay(displayID: "display-a", current: 2)
        ))
        let second = HDRRenderConfigurationResolver.resolve(makeInput(
            display: makeDisplay(displayID: "display-b", current: 2)
        ))

        XCTAssertEqual(first, second)
    }

    private func makeInput(
        decodedLayout: HDRDecodedPixelBufferLayout? = nil,
        colorMetadata: VideoColorMetadata = .rec709VideoRange(),
        decoderGeneration: UInt64 = 7,
        userAllowsHDR: Bool = true,
        capabilities: HDRPlatformOutputCapabilities = .macOS,
        display: HDRDisplaySnapshot? = nil,
        includesDisplaySnapshot: Bool = true,
        isDisplayRevisionExhausted: Bool = false,
        drawableState: HDRDrawableState = HDRDrawableState(
            isAvailable: true,
            appliedSurfaceContract: nil
        )
    ) -> HDRRenderConfigurationResolverInput {
        HDRRenderConfigurationResolverInput(
            decodedLayout: decodedLayout ?? makeLayout(isHDR: colorMetadata.isHDR),
            colorMetadata: colorMetadata,
            decoderGeneration: decoderGeneration,
            userAllowsHDR: userAllowsHDR,
            platformCapabilities: capabilities,
            displaySnapshot: includesDisplaySnapshot
                ? (display ?? makeDisplay(current: 2))
                : nil,
            isDisplayRevisionExhausted: isDisplayRevisionExhausted,
            drawableState: drawableState
        )
    }

    private func makeLayout(isHDR: Bool) -> HDRDecodedPixelBufferLayout {
        HDRDecodedPixelBufferLayout(
            pixelFormat: isHDR
                ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
                : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            width: 1_920,
            height: 1_080,
            planes: [
                HDRDecodedPlaneDimensions(width: 1_920, height: 1_080),
                HDRDecodedPlaneDimensions(width: 960, height: 540)
            ]
        )
    }

    private func makeDisplay(
        revision: UInt64 = 5,
        displayID: String = "not-published",
        potential: Double = 4,
        current: Double,
        reference: Double = 1
    ) -> HDRDisplaySnapshot {
        HDRDisplaySnapshot(
            revision: HDRDisplayRevision(rawValue: revision),
            displayID: displayID,
            headroom: DisplayHeadroom(
                potential: potential,
                current: current,
                reference: reference
            )
        )
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

    private func makeEDRSurface(gamut: HDROutputGamut) throws -> HDRSurfaceContract {
        try HDRSurfaceContract(
            drawablePixelFormat: .rgba16Float,
            outputColorSpace: gamut == .ituR2020
                ? .extendedLinearITUR2020
                : .extendedLinearDisplayP3,
            outputGamut: gamut,
            extendedRangeIntent: .enabled,
            metadataMode: .hdr10
        )
    }
}

private extension HDRPlatformOutputCapabilities {
    static let macOS = Self(
        platform: .macOS,
        headroomSource: .currentPotentialAndReference,
        extendedRangeSurfaceSupport: .intentAndMetadata,
        supportedEDRGamuts: [.displayP3, .ituR2020],
        supportsSDRToneMapping: true
    )
}
