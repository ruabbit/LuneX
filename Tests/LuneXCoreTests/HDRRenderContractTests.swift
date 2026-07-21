import XCTest

final class HDRRenderContractTests: XCTestCase {
    func testColorSignatureCapturesEveryImmutableMetadataField() throws {
        let mastering = VideoMasteringDisplayMetadata(
            displayPrimaries: [
                VideoChromaticityPoint(x: 35_400, y: 14_600),
                VideoChromaticityPoint(x: 8_500, y: 39_850),
                VideoChromaticityPoint(x: 6_550, y: 2_300)
            ],
            whitePoint: VideoChromaticityPoint(x: 15_635, y: 16_450),
            maximumDisplayLuminanceNits: 1_000,
            minimumDisplayLuminanceTenThousandths: 5
        )
        let contentLight = VideoContentLightMetadata(
            maximumContentLightLevelNits: 900,
            maximumFrameAverageLightLevelNits: 400
        )
        let metadata = VideoColorMetadata.hdr10VideoRange(
            masteringDisplay: mastering,
            contentLight: contentLight,
            maximumFullFrameLuminanceNits: 600
        )

        let signature = HDRRenderColorSignature(metadata: metadata)

        XCTAssertEqual(signature.bitDepth, 10)
        XCTAssertEqual(signature.dynamicRange, .hdr10)
        XCTAssertEqual(signature.primaries, .ituR2020)
        XCTAssertEqual(signature.transferFunction, .smpteST2084PQ)
        XCTAssertEqual(signature.matrix, .ituR2020)
        XCTAssertEqual(signature.signalRange, .video)
        XCTAssertEqual(signature.masteringDisplay, mastering)
        XCTAssertEqual(signature.contentLight, contentLight)
        XCTAssertEqual(signature.maximumFullFrameLuminanceNits, 600)
        XCTAssertEqual(Set([signature, signature]).count, 1)
    }

    func testColorSignatureChangesWhenSourceContractChanges() {
        let sdr = HDRRenderColorSignature(metadata: .rec709VideoRange())
        var fullRangeMetadata = VideoColorMetadata.rec709VideoRange()
        fullRangeMetadata.isFullRange = true
        let fullRange = HDRRenderColorSignature(metadata: fullRangeMetadata)

        XCTAssertNotEqual(sdr, fullRange)
        XCTAssertEqual(sdr.dynamicRange, .sdr)
        XCTAssertEqual(sdr.signalRange, .video)
        XCTAssertEqual(fullRange.signalRange, .full)
    }

    func testDisplayRevisionPreservesRawValueAndOrdersMonotonically() {
        let first = HDRDisplayRevision(rawValue: 41)
        let second = HDRDisplayRevision(rawValue: 42)

        XCTAssertEqual(first.rawValue, 41)
        XCTAssertLessThan(first, second)
        XCTAssertEqual(Set([first, second, first]).count, 2)
    }

    func testPlatformCapabilitiesKeepHeadroomSurfaceAndFallbackIndependent() {
        let capabilities = HDRPlatformOutputCapabilities(
            platform: .macOS,
            headroomSource: .currentPotentialAndReference,
            extendedRangeSurfaceSupport: .intentAndMetadata,
            supportedEDRGamuts: [.displayP3, .ituR2020],
            supportsSDRToneMapping: true
        )

        XCTAssertEqual(capabilities.platform, .macOS)
        XCTAssertEqual(capabilities.headroomSource, .currentPotentialAndReference)
        XCTAssertEqual(capabilities.extendedRangeSurfaceSupport, .intentAndMetadata)
        XCTAssertEqual(capabilities.supportedEDRGamuts, [.displayP3, .ituR2020])
        XCTAssertTrue(capabilities.supportsSDRToneMapping)
    }

    func testPlatformCapabilitiesDistinguishTVAndVisionOutputBoundaries() {
        let tvOS = HDRPlatformOutputCapabilities(
            platform: .tvOS,
            headroomSource: .currentAndPotential,
            extendedRangeSurfaceSupport: .unavailable,
            supportedEDRGamuts: [],
            supportsSDRToneMapping: true
        )
        let visionOS = HDRPlatformOutputCapabilities(
            platform: .visionOS,
            headroomSource: .unavailable,
            extendedRangeSurfaceSupport: .intentAndMetadata,
            supportedEDRGamuts: [.displayP3],
            supportsSDRToneMapping: true
        )

        XCTAssertNotEqual(tvOS, visionOS)
        XCTAssertEqual(tvOS.headroomSource, .currentAndPotential)
        XCTAssertEqual(tvOS.extendedRangeSurfaceSupport, .unavailable)
        XCTAssertEqual(visionOS.headroomSource, .unavailable)
        XCTAssertEqual(visionOS.extendedRangeSurfaceSupport, .intentAndMetadata)
    }

    func testConfigurationIdentityIncludesGenerationColorDisplayMappingAndSurface() throws {
        let surface = try HDRSurfaceContract(
            drawablePixelFormat: .rgba16Float,
            outputColorSpace: .extendedLinearDisplayP3,
            outputGamut: .displayP3,
            extendedRangeIntent: .enabled,
            metadataMode: .hdr10
        )
        let identity = try HDRRenderConfigurationIdentity(
            decoderGeneration: 7,
            colorSignature: HDRRenderColorSignature(metadata: .hdr10VideoRange()),
            displayRevision: HDRDisplayRevision(rawValue: 11),
            mappingMode: .hdrEDR,
            surfaceContract: surface
        )
        let changedDisplay = try HDRRenderConfigurationIdentity(
            decoderGeneration: 7,
            colorSignature: identity.colorSignature,
            displayRevision: HDRDisplayRevision(rawValue: 12),
            mappingMode: .hdrEDR,
            surfaceContract: surface
        )

        XCTAssertEqual(identity.surfaceContract, surface)
        XCTAssertNotEqual(identity, changedDisplay)
        XCTAssertEqual(Set([identity, identity, changedDisplay]).count, 2)
    }

    func testSurfaceContractRejectsMixedDrawableColorSpaceGamutAndIntent() {
        XCTAssertThrowsError(try HDRSurfaceContract(
            drawablePixelFormat: .rgba16Float,
            outputColorSpace: .sRGB,
            outputGamut: .displayP3,
            extendedRangeIntent: .enabled,
            metadataMode: .hdr10
        )) { error in
            XCTAssertEqual(
                error as? HDRRenderResolutionError,
                .unsupportedSurfaceContract
            )
        }
    }

    func testConfigurationRejectsMappingAndSurfaceMismatch() throws {
        let sdrSurface = try HDRSurfaceContract(
            drawablePixelFormat: .bgra8UnormSRGB,
            outputColorSpace: .sRGB,
            outputGamut: .sRGB,
            extendedRangeIntent: .disabled,
            metadataMode: .none
        )

        XCTAssertThrowsError(try HDRRenderConfigurationIdentity(
            decoderGeneration: 1,
            colorSignature: HDRRenderColorSignature(metadata: .hdr10VideoRange()),
            displayRevision: HDRDisplayRevision(rawValue: 1),
            mappingMode: .hdrEDR,
            surfaceContract: sdrSurface
        )) { error in
            XCTAssertEqual(
                error as? HDRRenderResolutionError,
                .incompatibleMappingAndSurface
            )
        }
    }

    func testSurfaceContractRequiresHDR10MetadataOnlyForEDR() {
        XCTAssertThrowsError(try HDRSurfaceContract(
            drawablePixelFormat: .rgba16Float,
            outputColorSpace: .extendedLinearITUR2020,
            outputGamut: .ituR2020,
            extendedRangeIntent: .enabled,
            metadataMode: .none
        )) { error in
            XCTAssertEqual(
                error as? HDRRenderResolutionError,
                .unsupportedSurfaceContract
            )
        }
        XCTAssertThrowsError(try HDRSurfaceContract(
            drawablePixelFormat: .bgra8UnormSRGB,
            outputColorSpace: .sRGB,
            outputGamut: .sRGB,
            extendedRangeIntent: .disabled,
            metadataMode: .hdr10
        )) { error in
            XCTAssertEqual(
                error as? HDRRenderResolutionError,
                .unsupportedSurfaceContract
            )
        }
    }

    func testConfigurationRejectsInactiveOwnershipAndSourceMappingMismatch() throws {
        let sdrSurface = try HDRSurfaceContract(
            drawablePixelFormat: .bgra8UnormSRGB,
            outputColorSpace: .sRGB,
            outputGamut: .sRGB,
            extendedRangeIntent: .disabled,
            metadataMode: .none
        )

        XCTAssertThrowsError(try HDRRenderConfigurationIdentity(
            decoderGeneration: 0,
            colorSignature: HDRRenderColorSignature(metadata: .rec709VideoRange()),
            displayRevision: HDRDisplayRevision(rawValue: 1),
            mappingMode: .sdr,
            surfaceContract: sdrSurface
        )) { error in
            XCTAssertEqual(error as? HDRRenderResolutionError, .inactiveSession)
        }
        XCTAssertThrowsError(try HDRRenderConfigurationIdentity(
            decoderGeneration: 1,
            colorSignature: HDRRenderColorSignature(metadata: .rec709VideoRange()),
            displayRevision: HDRDisplayRevision(rawValue: 0),
            mappingMode: .sdr,
            surfaceContract: sdrSurface
        )) { error in
            XCTAssertEqual(error as? HDRRenderResolutionError, .invalidDisplayRevision)
        }
        XCTAssertThrowsError(try HDRRenderConfigurationIdentity(
            decoderGeneration: 1,
            colorSignature: HDRRenderColorSignature(metadata: .hdr10VideoRange()),
            displayRevision: HDRDisplayRevision(rawValue: 1),
            mappingMode: .sdr,
            surfaceContract: sdrSurface
        )) { error in
            XCTAssertEqual(
                error as? HDRRenderResolutionError,
                .incompatibleSourceAndMapping
            )
        }
    }

    func testMappingAndSurfaceEnumsRemainClosed() {
        XCTAssertEqual(HDRMappingMode.allTestNames, ["sdr", "hdr-edr", "hdr-to-sdr"])
        XCTAssertEqual(
            HDRDrawablePixelFormat.allTestNames,
            ["bgra8-srgb", "rgba16-float"]
        )
        XCTAssertEqual(
            HDRExtendedRangeIntent.allTestNames,
            ["disabled", "enabled"]
        )
        XCTAssertEqual(HDRSurfaceMetadataMode.allTestNames, ["none", "hdr10"])
    }

    func testResolutionErrorsAreClosedComparableAndPrivacyBounded() {
        let expectedRevision = HDRDisplayRevision(rawValue: 20)
        let actualRevision = HDRDisplayRevision(rawValue: 19)
        let errors: [HDRRenderResolutionError] = [
            .inactiveSession,
            .invalidSourceContract,
            .incompatibleSourceAndMapping,
            .unsupportedDecodedLayout,
            .incompatibleDecodedLayout,
            .unsupportedPlatformOutput(.visionOS),
            .missingCurrentDisplayHeadroom,
            .invalidCurrentDisplayHeadroom,
            .userDisabledHDRWithoutSDRFallback,
            .unsupportedSurfaceContract,
            .incompatibleMappingAndSurface,
            .staleDecoderGeneration(expected: 4, actual: 3),
            .staleDisplayRevision(expected: expectedRevision, actual: actualRevision),
            .invalidDisplayRevision,
            .displayRevisionExhausted
        ]

        XCTAssertEqual(Set(errors).count, errors.count)
        XCTAssertTrue(errors.allSatisfy { !$0.description.isEmpty })
        XCTAssertEqual(errors.map(\.testCategory), [
            "session", "source", "source", "layout", "layout", "platform", "headroom",
            "headroom", "preference", "surface", "surface", "generation", "display",
            "display", "display"
        ])
    }
}

private extension HDRMappingMode {
    static let allTestNames = [
        HDRMappingMode.sdr.testName,
        HDRMappingMode.hdrEDR.testName,
        HDRMappingMode.hdrToSDR.testName
    ]

    var testName: String {
        switch self {
        case .sdr: "sdr"
        case .hdrEDR: "hdr-edr"
        case .hdrToSDR: "hdr-to-sdr"
        }
    }
}

private extension HDRDrawablePixelFormat {
    static let allTestNames = [
        HDRDrawablePixelFormat.bgra8UnormSRGB.testName,
        HDRDrawablePixelFormat.rgba16Float.testName
    ]

    var testName: String {
        switch self {
        case .bgra8UnormSRGB: "bgra8-srgb"
        case .rgba16Float: "rgba16-float"
        }
    }
}

private extension HDRExtendedRangeIntent {
    static let allTestNames = [
        HDRExtendedRangeIntent.disabled.testName,
        HDRExtendedRangeIntent.enabled.testName
    ]

    var testName: String {
        switch self {
        case .disabled: "disabled"
        case .enabled: "enabled"
        }
    }
}

private extension HDRSurfaceMetadataMode {
    static let allTestNames = [
        HDRSurfaceMetadataMode.none.rawValue,
        HDRSurfaceMetadataMode.hdr10.rawValue
    ]
}

private extension HDRRenderResolutionError {
    var testCategory: String {
        switch self {
        case .inactiveSession: "session"
        case .invalidSourceContract, .incompatibleSourceAndMapping: "source"
        case .unsupportedDecodedLayout, .incompatibleDecodedLayout: "layout"
        case .unsupportedPlatformOutput: "platform"
        case .missingCurrentDisplayHeadroom, .invalidCurrentDisplayHeadroom: "headroom"
        case .userDisabledHDRWithoutSDRFallback: "preference"
        case .unsupportedSurfaceContract, .incompatibleMappingAndSurface: "surface"
        case .staleDecoderGeneration: "generation"
        case .staleDisplayRevision, .invalidDisplayRevision, .displayRevisionExhausted: "display"
        }
    }
}
