import Foundation

struct HDRDrawableState: Hashable, Sendable {
    let isAvailable: Bool
    let appliedSurfaceContract: HDRSurfaceContract?
}

enum HDRSDRFallbackReason: Hashable, Sendable {
    case userPreferenceDisabled
    case platformOutputUnsupported(AppleRenderingPlatform)
    case currentHeadroomUnavailable
    case currentHeadroomInvalid
    case currentHeadroomInsufficient
}

enum HDRResolvedOutputMode: Hashable, Sendable {
    case sdr
    case edr
    case sdrFallback(HDRSDRFallbackReason)
}

enum HDRResolvedSurfaceState: Hashable, Sendable {
    case ready
    case requiresApplication(previous: HDRSurfaceContract?)
}

struct HDRResolvedRenderConfiguration: Hashable, Sendable {
    let frameContract: HDRValidatedDecodedFrameContract
    let identity: HDRRenderConfigurationIdentity
    let luminanceMapping: HDRLuminanceMapping?
    let outputMode: HDRResolvedOutputMode
    let surfaceState: HDRResolvedSurfaceState
}

struct HDRRenderConfigurationResolverInput: Sendable {
    let decodedLayout: HDRDecodedPixelBufferLayout
    let colorMetadata: VideoColorMetadata
    let decoderGeneration: UInt64
    let userAllowsHDR: Bool
    let platformCapabilities: HDRPlatformOutputCapabilities
    let displaySnapshot: HDRDisplaySnapshot?
    let isDisplayRevisionExhausted: Bool
    let drawableState: HDRDrawableState
}

enum HDRRenderConfigurationResolution: Hashable, Sendable {
    case resolved(HDRResolvedRenderConfiguration)
    case closed(HDRRenderResolutionError)

    var configuration: HDRResolvedRenderConfiguration? {
        guard case let .resolved(configuration) = self else { return nil }
        return configuration
    }

    var error: HDRRenderResolutionError? {
        guard case let .closed(error) = self else { return nil }
        return error
    }
}

enum HDRRenderConfigurationResolver {
    static func resolve(
        _ input: HDRRenderConfigurationResolverInput
    ) -> HDRRenderConfigurationResolution {
        guard input.decoderGeneration > 0 else {
            return .closed(.inactiveSession)
        }
        guard !input.isDisplayRevisionExhausted else {
            return .closed(.displayRevisionExhausted)
        }
        guard let display = input.displaySnapshot,
              display.revision.rawValue > 0 else {
            return .closed(.invalidDisplayRevision)
        }
        guard input.drawableState.isAvailable else {
            return .closed(.drawableUnavailable)
        }

        let frameContract: HDRValidatedDecodedFrameContract
        do {
            frameContract = try HDRDecodedVideoContractValidator.validateForMetalMapping(
                layout: input.decodedLayout,
                colorMetadata: input.colorMetadata
            )
        } catch let error as HDRDecodedVideoContractError {
            return .closed(mapDecodedContractError(error))
        } catch {
            return .closed(.invalidSourceContract)
        }

        if frameContract.colorSignature.dynamicRange == .sdr {
            return makeResolution(
                frameContract: frameContract,
                decoderGeneration: input.decoderGeneration,
                displayRevision: display.revision,
                mappingMode: .sdr,
                surfaceContract: makeSDRSurface(),
                luminanceMapping: nil,
                outputMode: .sdr,
                drawableState: input.drawableState
            )
        }

        let sourcePeak: HDRSourcePeak
        do {
            sourcePeak = try HDRSourcePeakResolver.resolve(frameContract.colorSignature)
        } catch {
            return .closed(.invalidSourceContract)
        }

        let eligibility = resolveEDREligibility(
            userAllowsHDR: input.userAllowsHDR,
            capabilities: input.platformCapabilities,
            headroom: display.headroom
        )
        switch eligibility {
        case let .eligible(gamut, currentHeadroom):
            let mapping: HDRLuminanceMapping
            do {
                mapping = try HDRLuminanceMapping(
                    sourcePeak: sourcePeak,
                    currentHeadroom: currentHeadroom
                )
            } catch {
                return .closed(.invalidCurrentDisplayHeadroom)
            }
            return makeResolution(
                frameContract: frameContract,
                decoderGeneration: input.decoderGeneration,
                displayRevision: display.revision,
                mappingMode: .hdrEDR,
                surfaceContract: makeEDRSurface(gamut: gamut),
                luminanceMapping: mapping,
                outputMode: .edr,
                drawableState: input.drawableState
            )
        case let .ineligible(reason):
            guard input.platformCapabilities.supportsSDRToneMapping else {
                return .closed(closedError(
                    for: reason,
                    platform: input.platformCapabilities.platform
                ))
            }
            let mapping: HDRLuminanceMapping
            do {
                mapping = try HDRLuminanceMapping(
                    sourcePeak: sourcePeak,
                    currentHeadroom: 1
                )
            } catch {
                return .closed(.invalidSourceContract)
            }
            return makeResolution(
                frameContract: frameContract,
                decoderGeneration: input.decoderGeneration,
                displayRevision: display.revision,
                mappingMode: .hdrToSDR,
                surfaceContract: makeSDRSurface(),
                luminanceMapping: mapping,
                outputMode: .sdrFallback(reason),
                drawableState: input.drawableState
            )
        }
    }

    private enum EDREligibility {
        case eligible(gamut: HDROutputGamut, currentHeadroom: Double)
        case ineligible(HDRSDRFallbackReason)
    }

    private static func resolveEDREligibility(
        userAllowsHDR: Bool,
        capabilities: HDRPlatformOutputCapabilities,
        headroom: DisplayHeadroom
    ) -> EDREligibility {
        guard userAllowsHDR else {
            return .ineligible(.userPreferenceDisabled)
        }
        guard capabilities.headroomSource != .unavailable else {
            return .ineligible(.currentHeadroomUnavailable)
        }
        guard capabilities.extendedRangeSurfaceSupport == .intentAndMetadata else {
            return .ineligible(.platformOutputUnsupported(capabilities.platform))
        }
        let gamut: HDROutputGamut
        if capabilities.supportedEDRGamuts.contains(.ituR2020) {
            gamut = .ituR2020
        } else if capabilities.supportedEDRGamuts.contains(.displayP3) {
            gamut = .displayP3
        } else {
            return .ineligible(.platformOutputUnsupported(capabilities.platform))
        }
        guard headroom.current.isFinite,
              (1...HDRLuminanceMapping.maximumCurrentHeadroom).contains(
                headroom.current
              ) else {
            return .ineligible(.currentHeadroomInvalid)
        }
        guard headroom.current > 1 else {
            return .ineligible(.currentHeadroomInsufficient)
        }
        return .eligible(gamut: gamut, currentHeadroom: headroom.current)
    }

    private static func makeResolution(
        frameContract: HDRValidatedDecodedFrameContract,
        decoderGeneration: UInt64,
        displayRevision: HDRDisplayRevision,
        mappingMode: HDRMappingMode,
        surfaceContract: Result<HDRSurfaceContract, HDRRenderResolutionError>,
        luminanceMapping: HDRLuminanceMapping?,
        outputMode: HDRResolvedOutputMode,
        drawableState: HDRDrawableState
    ) -> HDRRenderConfigurationResolution {
        let surface: HDRSurfaceContract
        switch surfaceContract {
        case let .success(contract):
            surface = contract
        case let .failure(error):
            return .closed(error)
        }
        do {
            let identity = try HDRRenderConfigurationIdentity(
                decoderGeneration: decoderGeneration,
                colorSignature: frameContract.colorSignature,
                displayRevision: displayRevision,
                mappingMode: mappingMode,
                surfaceContract: surface
            )
            return .resolved(HDRResolvedRenderConfiguration(
                frameContract: frameContract,
                identity: identity,
                luminanceMapping: luminanceMapping,
                outputMode: outputMode,
                surfaceState: drawableState.appliedSurfaceContract == surface
                    ? .ready
                    : .requiresApplication(
                        previous: drawableState.appliedSurfaceContract
                    )
            ))
        } catch let error as HDRRenderResolutionError {
            return .closed(error)
        } catch {
            return .closed(.unsupportedSurfaceContract)
        }
    }

    private static func makeSDRSurface()
        -> Result<HDRSurfaceContract, HDRRenderResolutionError> {
        Result {
            try HDRSurfaceContract(
                drawablePixelFormat: .bgra8UnormSRGB,
                outputColorSpace: .sRGB,
                outputGamut: .sRGB,
                extendedRangeIntent: .disabled,
                metadataMode: .none
            )
        }.mapError { _ in .unsupportedSurfaceContract }
    }

    private static func makeEDRSurface(
        gamut: HDROutputGamut
    ) -> Result<HDRSurfaceContract, HDRRenderResolutionError> {
        let colorSpace: HDROutputColorSpace
        switch gamut {
        case .displayP3:
            colorSpace = .extendedLinearDisplayP3
        case .ituR2020:
            colorSpace = .extendedLinearITUR2020
        case .sRGB:
            return .failure(.unsupportedSurfaceContract)
        }
        return Result {
            try HDRSurfaceContract(
                drawablePixelFormat: .rgba16Float,
                outputColorSpace: colorSpace,
                outputGamut: gamut,
                extendedRangeIntent: .enabled,
                metadataMode: .hdr10
            )
        }.mapError { _ in .unsupportedSurfaceContract }
    }

    private static func mapDecodedContractError(
        _ error: HDRDecodedVideoContractError
    ) -> HDRRenderResolutionError {
        switch error {
        case .invalidColorMetadata:
            return .invalidSourceContract
        case .unsupportedPixelFormat, .unsupportedSignalRange:
            return .unsupportedDecodedLayout
        case .invalidDimensions, .invalidPlaneCount, .invalidPlaneDimensions,
             .incompatibleBitDepth, .incompatibleCodec, .incompatiblePrimaries,
             .incompatibleTransfer, .incompatibleMatrix, .unexpectedHDRMetadata:
            return .incompatibleDecodedLayout
        }
    }

    private static func closedError(
        for reason: HDRSDRFallbackReason,
        platform: AppleRenderingPlatform
    ) -> HDRRenderResolutionError {
        switch reason {
        case .userPreferenceDisabled:
            return .userDisabledHDRWithoutSDRFallback
        case .platformOutputUnsupported:
            return .unsupportedPlatformOutput(platform)
        case .currentHeadroomUnavailable:
            return .missingCurrentDisplayHeadroom
        case .currentHeadroomInvalid:
            return .invalidCurrentDisplayHeadroom
        case .currentHeadroomInsufficient:
            return .insufficientCurrentDisplayHeadroom
        }
    }
}
