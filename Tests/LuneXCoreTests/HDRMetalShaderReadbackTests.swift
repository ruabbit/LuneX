import Foundation
@preconcurrency import Metal
import XCTest

final class HDRMetalShaderReadbackTests: XCTestCase {
    func testNV12SDRBlackReferenceWhiteAndRec709PrimariesMatchCPUReference() throws {
        let harness = try HDRMetalReadbackHarness()
        let cases: [(String, HDRColorVector)] = [
            ("black", HDRColorVector(x: 0, y: 0, z: 0)),
            ("reference white", HDRColorVector(x: 1, y: 1, z: 1)),
            ("red", HDRColorVector(x: 1, y: 0, z: 0)),
            ("green", HDRColorVector(x: 0, y: 1, z: 0)),
            ("blue", HDRColorVector(x: 0, y: 0, z: 1))
        ]

        for (name, nonlinearRGB) in cases {
            let codes = videoRangeCodes(
                nonlinearRGB: nonlinearRGB,
                matrix: .ituR709,
                bitDepth: 8
            )
            let actual = try harness.render(
                lumaCodes: [UInt16(codes.luma)],
                chromaCodes: [(UInt16(codes.chromaBlue), UInt16(codes.chromaRed))],
                width: 1,
                height: 1,
                mode: .sdr
            )
            let expected = try cpuReference(
                codes: codes,
                matrix: .ituR709,
                transfer: .ituR709,
                outputGamut: .sRGB,
                mapping: nil
            )
            assertVector(actual.rgb, equals: expected, accuracy: 0.008, name: name)
            XCTAssertEqual(actual.alpha, 1, accuracy: 1.0 / 255.0, name)
        }
    }

    func testP010HDRNearBlackReferenceWhiteAndPeakMatchCPUReference() throws {
        let harness = try HDRMetalReadbackHarness()
        let mapping = try HDRLuminanceMapping(
            sourcePeak: try HDRSourcePeakResolver.resolve(.hdr10VideoRange()),
            currentHeadroom: 4
        )
        let samples: [(String, Double)] = [
            ("near black", 0.1),
            ("reference white", HDRLuminanceMapping.referenceWhiteNits),
            ("peak highlight", mapping.sourcePeak.luminanceNits)
        ]

        for (name, luminanceNits) in samples {
            let encoded = pqEncode(luminanceNits: luminanceNits)
            let codes = videoRangeCodes(
                nonlinearRGB: HDRColorVector(x: encoded, y: encoded, z: encoded),
                matrix: .ituR2020,
                bitDepth: 10
            )
            let actual = try harness.render(
                lumaCodes: [UInt16(codes.luma)],
                chromaCodes: [(UInt16(codes.chromaBlue), UInt16(codes.chromaRed))],
                width: 1,
                height: 1,
                mode: .hdrEDR(headroom: mapping.currentHeadroom)
            )
            let expected = try cpuReference(
                codes: codes,
                matrix: .ituR2020,
                transfer: .smpteST2084PQ,
                outputGamut: .displayP3,
                mapping: mapping
            )
            assertVector(actual.rgb, equals: expected, accuracy: 0.012, name: name)
            XCTAssertTrue(actual.rgb.components.allSatisfy {
                $0.isFinite && (0...mapping.currentHeadroom).contains($0)
            }, name)
            XCTAssertEqual(actual.alpha, 1, accuracy: 0.001, name)
        }
    }

    func testP010Rec2020PrimaryConversionToDisplayP3MatchesCPUReference() throws {
        let harness = try HDRMetalReadbackHarness()
        let mapping = try HDRLuminanceMapping(
            sourcePeak: try HDRSourcePeakResolver.resolve(.hdr10VideoRange()),
            currentHeadroom: 4
        )
        let encodedRed = pqEncode(luminanceNits: 600)
        let codes = videoRangeCodes(
            nonlinearRGB: HDRColorVector(x: encodedRed, y: 0, z: 0),
            matrix: .ituR2020,
            bitDepth: 10
        )

        let actual = try harness.render(
            lumaCodes: [UInt16(codes.luma)],
            chromaCodes: [(UInt16(codes.chromaBlue), UInt16(codes.chromaRed))],
            width: 1,
            height: 1,
            mode: .hdrEDR(headroom: mapping.currentHeadroom)
        )
        let expected = try cpuReference(
            codes: codes,
            matrix: .ituR2020,
            transfer: .smpteST2084PQ,
            outputGamut: .displayP3,
            mapping: mapping
        )

        assertVector(actual.rgb, equals: expected, accuracy: 0.012, name: "Rec.2020 red")
        XCTAssertGreaterThan(actual.rgb.x, actual.rgb.y)
        XCTAssertGreaterThan(actual.rgb.x, actual.rgb.z)
    }

    func testP010HDRToSDRFallbackMatchesCPUReferenceAndIsFiniteBounded() throws {
        let harness = try HDRMetalReadbackHarness()
        let mapping = try HDRLuminanceMapping(
            sourcePeak: try HDRSourcePeakResolver.resolve(.hdr10VideoRange()),
            currentHeadroom: 1
        )
        let samples = [0.0, 0.1, 100, 400, 1_000]

        for luminanceNits in samples {
            let encoded = pqEncode(luminanceNits: luminanceNits)
            let codes = videoRangeCodes(
                nonlinearRGB: HDRColorVector(x: encoded, y: encoded, z: encoded),
                matrix: .ituR2020,
                bitDepth: 10
            )
            let actual = try harness.render(
                lumaCodes: [UInt16(codes.luma)],
                chromaCodes: [(UInt16(codes.chromaBlue), UInt16(codes.chromaRed))],
                width: 1,
                height: 1,
                mode: .hdrToSDR
            )
            let expected = try cpuReference(
                codes: codes,
                matrix: .ituR2020,
                transfer: .smpteST2084PQ,
                outputGamut: .sRGB,
                mapping: mapping
            )
            assertVector(
                actual.rgb,
                equals: expected,
                accuracy: 0.008,
                name: "HDR-to-SDR \(luminanceNits) nits"
            )
            XCTAssertTrue(actual.rgb.components.allSatisfy {
                $0.isFinite && (0...1).contains($0)
            })
        }
    }

    func testOffscreenReadbackHonorsNonFullFillCrop() throws {
        let harness = try HDRMetalReadbackHarness()
        let black = videoRangeCodes(
            nonlinearRGB: HDRColorVector(x: 0, y: 0, z: 0),
            matrix: .ituR709,
            bitDepth: 8
        )
        let white = videoRangeCodes(
            nonlinearRGB: HDRColorVector(x: 1, y: 1, z: 1),
            matrix: .ituR709,
            bitDepth: 8
        )
        let geometry = HDRMetalPresentationGeometry(
            coordinateRevision: 1,
            viewport: HDRMetalViewport(originX: 0, originY: 0, width: 1, height: 1),
            scissorRectangle: HDRMetalScissorRectangle(x: 0, y: 0, width: 1, height: 1),
            uniforms: HDRMetalGeometryUniforms(
                textureOriginX: 0.5,
                textureOriginY: 0,
                textureScaleX: 0.5,
                textureScaleY: 1
            )
        )

        let actual = try harness.render(
            lumaCodes: [
                UInt16(black.luma), UInt16(black.luma),
                UInt16(white.luma), UInt16(white.luma),
                UInt16(black.luma), UInt16(black.luma),
                UInt16(white.luma), UInt16(white.luma)
            ],
            chromaCodes: [
                (UInt16(black.chromaBlue), UInt16(black.chromaRed)),
                (UInt16(white.chromaBlue), UInt16(white.chromaRed))
            ],
            width: 4,
            height: 2,
            mode: .sdr,
            geometry: geometry
        )

        assertVector(
            actual.rgb,
            equals: HDRColorVector(x: 1, y: 1, z: 1),
            accuracy: 0.008,
            name: "right-half fill crop"
        )
    }

    func testOffscreenFitReadbackPreservesOpaqueBlackLetterbox() throws {
        let harness = try HDRMetalReadbackHarness()
        let white = videoRangeCodes(
            nonlinearRGB: HDRColorVector(x: 1, y: 1, z: 1),
            matrix: .ituR709,
            bitDepth: 8
        )
        let snapshot = try XCTUnwrap(StreamCoordinateSnapshot.resolve(
            revision: 1,
            sourceSize: PixelSize(width: 2, height: 2),
            drawableSize: PixelSize(width: 2, height: 4),
            mode: .fit
        ))
        let geometry = try HDRMetalPresentationGeometryResolver.resolve(snapshot)
        let luma = [UInt16](repeating: UInt16(white.luma), count: 4)
        let chroma = [(UInt16(white.chromaBlue), UInt16(white.chromaRed))]

        let letterbox = try harness.render(
            lumaCodes: luma,
            chromaCodes: chroma,
            width: 2,
            height: 2,
            mode: .sdr,
            targetWidth: 2,
            targetHeight: 4,
            readX: 0,
            readY: 0,
            geometry: geometry
        )
        assertVector(
            letterbox.rgb,
            equals: HDRColorVector(x: 0, y: 0, z: 0),
            accuracy: 0,
            name: "fit letterbox"
        )
        XCTAssertEqual(letterbox.alpha, 1, accuracy: 0)

        let visibleVideo = try harness.render(
            lumaCodes: luma,
            chromaCodes: chroma,
            width: 2,
            height: 2,
            mode: .sdr,
            targetWidth: 2,
            targetHeight: 4,
            readX: 1,
            readY: 2,
            geometry: geometry
        )
        assertVector(
            visibleVideo.rgb,
            equals: HDRColorVector(x: 1, y: 1, z: 1),
            accuracy: 0.008,
            name: "fit visible video"
        )
        XCTAssertEqual(visibleVideo.alpha, 1, accuracy: 1.0 / 255.0)
    }

    func testFragmentSanitizesNonFiniteTextureSamplesToOpaqueBlack() throws {
        let harness = try HDRMetalReadbackHarness()
        let actual = try harness.renderNonFiniteHDRSample()

        assertVector(
            actual.rgb,
            equals: HDRColorVector(x: 0, y: 0, z: 0),
            accuracy: 0,
            name: "NaN guard"
        )
        XCTAssertEqual(actual.alpha, 1, accuracy: 0)
    }

    private func cpuReference(
        codes: VideoRangeCodeVector,
        matrix: VideoYCbCrMatrix,
        transfer: VideoTransferFunction,
        outputGamut: HDROutputGamut,
        mapping: HDRLuminanceMapping?
    ) throws -> HDRColorVector {
        let normalized = try HDRColorReferenceMath.normalizeVideoRange(
            lumaCode: codes.luma,
            chromaBlueCode: codes.chromaBlue,
            chromaRedCode: codes.chromaRed,
            bitDepth: codes.bitDepth
        )
        let nonlinear = try HDRColorReferenceMath.nonlinearRGB(
            from: normalized,
            matrix: matrix
        )
        switch transfer {
        case .ituR709:
            let linear = try HDRColorReferenceMath.decodeRec709(nonlinear)
            let converted = try HDRColorReferenceMath.convertLinearGamut(
                linear,
                from: .sRGB,
                to: outputGamut
            )
            return clamp(converted, lower: 0, upper: 1)
        case .smpteST2084PQ:
            let clampedNonlinear = clamp(nonlinear, lower: 0, upper: 1)
            let nits = try HDRColorReferenceMath.decodePQToNits(clampedNonlinear)
            let converted = try HDRColorReferenceMath.convertLinearGamut(
                nits,
                from: .ituR2020,
                to: outputGamut
            )
            let positive = clamp(converted, lower: 0, upper: .greatestFiniteMagnitude)
            let mapping = try XCTUnwrap(mapping)
            return HDRColorVector(
                x: try mapping.map(luminanceNits: positive.x),
                y: try mapping.map(luminanceNits: positive.y),
                z: try mapping.map(luminanceNits: positive.z)
            )
        }
    }

    private func videoRangeCodes(
        nonlinearRGB: HDRColorVector,
        matrix: VideoYCbCrMatrix,
        bitDepth: Int
    ) -> VideoRangeCodeVector {
        let coefficients: (red: Double, blue: Double, cbScale: Double, crScale: Double)
        switch matrix {
        case .ituR709:
            coefficients = (0.2126, 0.0722, 1.8556, 1.5748)
        case .ituR2020:
            coefficients = (0.2627, 0.0593, 1.8814, 1.4746)
        }
        let green = 1 - coefficients.red - coefficients.blue
        let luma = coefficients.red * nonlinearRGB.x
            + green * nonlinearRGB.y
            + coefficients.blue * nonlinearRGB.z
        let chromaBlue = (nonlinearRGB.z - luma) / coefficients.cbScale
        let chromaRed = (nonlinearRGB.x - luma) / coefficients.crScale
        let scale = bitDepth == 10 ? 4.0 : 1.0
        let maximum = Double((1 << bitDepth) - 1)
        return VideoRangeCodeVector(
            luma: min(max((16 * scale + 219 * scale * luma).rounded(), 0), maximum),
            chromaBlue: min(
                max((128 * scale + 224 * scale * chromaBlue).rounded(), 0),
                maximum
            ),
            chromaRed: min(
                max((128 * scale + 224 * scale * chromaRed).rounded(), 0),
                maximum
            ),
            bitDepth: bitDepth
        )
    }

    private func pqEncode(luminanceNits: Double) -> Double {
        let m1 = 2_610.0 / 16_384.0
        let m2 = 2_523.0 / 32.0
        let c1 = 3_424.0 / 4_096.0
        let c2 = 2_413.0 / 128.0
        let c3 = 2_392.0 / 128.0
        let normalized = min(max(luminanceNits / 10_000, 0), 1)
        let powered = pow(normalized, m1)
        return pow((c1 + c2 * powered) / (1 + c3 * powered), m2)
    }

    private func clamp(
        _ value: HDRColorVector,
        lower: Double,
        upper: Double
    ) -> HDRColorVector {
        HDRColorVector(
            x: min(max(value.x, lower), upper),
            y: min(max(value.y, lower), upper),
            z: min(max(value.z, lower), upper)
        )
    }

    private func assertVector(
        _ actual: HDRColorVector,
        equals expected: HDRColorVector,
        accuracy: Double,
        name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(actual.x, expected.x, accuracy: accuracy, name, file: file, line: line)
        XCTAssertEqual(actual.y, expected.y, accuracy: accuracy, name, file: file, line: line)
        XCTAssertEqual(actual.z, expected.z, accuracy: accuracy, name, file: file, line: line)
    }
}

private struct VideoRangeCodeVector {
    let luma: Double
    let chromaBlue: Double
    let chromaRed: Double
    let bitDepth: Int
}

private struct HDRMetalReadbackPixel {
    let rgb: HDRColorVector
    let alpha: Double
}

private enum HDRMetalReadbackMode {
    case sdr
    case hdrEDR(headroom: Double)
    case hdrToSDR

    var bitDepth: Int {
        switch self {
        case .sdr: 8
        case .hdrEDR, .hdrToSDR: 10
        }
    }

    var layout: HDRDecodedPixelLayout {
        bitDepth == 8 ? .nv12VideoRange8 : .p010VideoRange10
    }

    var mappingMode: HDRMappingMode {
        switch self {
        case .sdr: .sdr
        case .hdrEDR: .hdrEDR
        case .hdrToSDR: .hdrToSDR
        }
    }

    var outputPixelFormat: HDRDrawablePixelFormat {
        switch self {
        case .hdrEDR: .rgba16Float
        case .sdr, .hdrToSDR: .bgra8UnormSRGB
        }
    }
}

private final class HDRMetalReadbackHarness {
    private let device: any MTLDevice
    private let pipelineFactory: AppleHDRMetalPipelineStateFactory
    private let submitter: AppleHDRMetalCommandSubmitter
    private let readbackQueue: any MTLCommandQueue

    init() throws {
        device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        pipelineFactory = try AppleHDRMetalPipelineStateFactory(
            device: device,
            bundle: Bundle(for: HDRMetalShaderReadbackTests.self)
        )
        let commandQueue = try XCTUnwrap(device.makeCommandQueue())
        submitter = AppleHDRMetalCommandSubmitter(commandQueue: commandQueue)
        readbackQueue = commandQueue
    }

    func render(
        lumaCodes: [UInt16],
        chromaCodes: [(UInt16, UInt16)],
        width: Int,
        height: Int,
        mode: HDRMetalReadbackMode,
        targetWidth: Int = 1,
        targetHeight: Int = 1,
        readX: Int = 0,
        readY: Int = 0,
        geometry: HDRMetalPresentationGeometry? = nil
    ) throws -> HDRMetalReadbackPixel {
        let luma = try makeCodeTexture(
            codes: lumaCodes,
            width: width,
            height: height,
            bitDepth: mode.bitDepth,
            isChroma: false
        )
        let chroma = try makeCodeTexture(
            codes: chromaCodes.flatMap { [$0.0, $0.1] },
            width: max(width / 2, 1),
            height: max(height / 2, 1),
            bitDepth: mode.bitDepth,
            isChroma: true
        )
        return try render(
            luma: luma,
            chroma: chroma,
            mode: mode,
            targetWidth: targetWidth,
            targetHeight: targetHeight,
            readX: readX,
            readY: readY,
            geometry: geometry ?? fullTargetGeometry
        )
    }

    func renderNonFiniteHDRSample() throws -> HDRMetalReadbackPixel {
        let luma = try makeFloatTexture(
            pixelFormat: .r32Float,
            values: [.nan],
            width: 1,
            height: 1
        )
        let chroma = try makeFloatTexture(
            pixelFormat: .rg32Float,
            values: [0.5, 0.5],
            width: 1,
            height: 1
        )
        return try render(luma: luma, chroma: chroma, mode: .hdrEDR(headroom: 4), geometry: fullTargetGeometry)
    }

    private func render(
        luma: any MTLTexture,
        chroma: any MTLTexture,
        mode: HDRMetalReadbackMode,
        targetWidth: Int = 1,
        targetHeight: Int = 1,
        readX: Int = 0,
        readY: Int = 0,
        geometry: HDRMetalPresentationGeometry
    ) throws -> HDRMetalReadbackPixel {
        let metadata: VideoColorMetadata = mode.bitDepth == 8
            ? .rec709VideoRange() : .hdr10VideoRange()
        let surface = try HDRSurfaceContract(
            drawablePixelFormat: mode.outputPixelFormat,
            outputColorSpace: mode.mappingMode == .hdrEDR ? .extendedLinearDisplayP3 : .sRGB,
            outputGamut: mode.mappingMode == .hdrEDR ? .displayP3 : .sRGB,
            extendedRangeIntent: mode.mappingMode == .hdrEDR ? .enabled : .disabled,
            metadataMode: mode.mappingMode == .hdrEDR ? .hdr10 : .none
        )
        let configuration = try HDRRenderConfigurationIdentity(
            decoderGeneration: 1,
            colorSignature: HDRRenderColorSignature(metadata: metadata),
            displayRevision: HDRDisplayRevision(rawValue: 1),
            mappingMode: mode.mappingMode,
            surfaceContract: surface
        )
        let frameContract = HDRValidatedDecodedFrameContract(
            pixelLayout: mode.layout,
            width: max(luma.width, 1),
            height: max(luma.height, 1),
            colorSignature: configuration.colorSignature
        )
        let mapping: HDRLuminanceMapping?
        switch mode {
        case .sdr:
            mapping = nil
        case let .hdrEDR(headroom):
            mapping = try HDRLuminanceMapping(
                sourcePeak: HDRSourcePeakResolver.resolve(metadata),
                currentHeadroom: headroom
            )
        case .hdrToSDR:
            mapping = try HDRLuminanceMapping(
                sourcePeak: HDRSourcePeakResolver.resolve(metadata),
                currentHeadroom: 1
            )
        }
        let uniforms = try HDRMetalShaderUniforms(
            frameContract: frameContract,
            configuration: configuration,
            luminanceMapping: mapping
        )
        let key = try HDRMetalPipelineKey(
            frameContract: frameContract,
            configuration: configuration
        )
        let target = try makeTarget(
            pixelFormat: key.metalPixelFormat,
            width: targetWidth,
            height: targetHeight
        )
        let completion = HDRMetalReadbackCompletion()
        try submitter.submit(
            HDRMetalCommandRequest(
                pipelineState: try pipelineFactory.makePipelineState(for: key),
                lumaTexture: luma,
                chromaTexture: chroma,
                target: HDRMetalRenderTarget(texture: target),
                videoUniforms: uniforms,
                geometry: geometry,
                completion: .waitUntilCompleted
            ),
            completionHandler: completion.store
        )
        XCTAssertEqual(completion.value, .completed)
        return try readPixel(from: target, x: readX, y: readY)
    }

    private var fullTargetGeometry: HDRMetalPresentationGeometry {
        HDRMetalPresentationGeometry(
            coordinateRevision: 1,
            viewport: HDRMetalViewport(originX: 0, originY: 0, width: 1, height: 1),
            scissorRectangle: HDRMetalScissorRectangle(x: 0, y: 0, width: 1, height: 1),
            uniforms: HDRMetalGeometryUniforms(
                textureOriginX: 0,
                textureOriginY: 0,
                textureScaleX: 1,
                textureScaleY: 1
            )
        )
    }

    private func makeCodeTexture(
        codes: [UInt16],
        width: Int,
        height: Int,
        bitDepth: Int,
        isChroma: Bool
    ) throws -> any MTLTexture {
        let components = isChroma ? 2 : 1
        guard width > 0,
              height > 0,
              codes.count == width * height * components else {
            throw HDRMetalReadbackTestError.invalidTexturePayload
        }
        let pixelFormat: MTLPixelFormat
        if bitDepth == 8 {
            pixelFormat = isChroma ? .rg8Unorm : .r8Unorm
        } else {
            pixelFormat = isChroma ? .rg16Unorm : .r16Unorm
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = device.hasUnifiedMemory ? .shared : .managed
        descriptor.usage = .shaderRead
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        if bitDepth == 8 {
            let bytes = codes.map { UInt8(clamping: Int($0)) }
            bytes.withUnsafeBytes { raw in
                texture.replace(
                    region: MTLRegionMake2D(0, 0, width, height),
                    mipmapLevel: 0,
                    withBytes: raw.baseAddress!,
                    bytesPerRow: width * components
                )
            }
        } else {
            let words = codes.map { $0 << 6 }
            words.withUnsafeBytes { raw in
                texture.replace(
                    region: MTLRegionMake2D(0, 0, width, height),
                    mipmapLevel: 0,
                    withBytes: raw.baseAddress!,
                    bytesPerRow: width * components * MemoryLayout<UInt16>.size
                )
            }
        }
        return texture
    }

    private func makeFloatTexture(
        pixelFormat: MTLPixelFormat,
        values: [Float],
        width: Int,
        height: Int
    ) throws -> any MTLTexture {
        let components = pixelFormat == .rg32Float ? 2 : 1
        guard width > 0,
              height > 0,
              values.count == width * height * components else {
            throw HDRMetalReadbackTestError.invalidTexturePayload
        }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = device.hasUnifiedMemory ? .shared : .managed
        descriptor.usage = .shaderRead
        let texture = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        values.withUnsafeBytes { raw in
            texture.replace(
                region: MTLRegionMake2D(0, 0, width, height),
                mipmapLevel: 0,
                withBytes: raw.baseAddress!,
                bytesPerRow: width * components * MemoryLayout<Float>.size
            )
        }
        return texture
    }

    private func makeTarget(
        pixelFormat: MTLPixelFormat,
        width: Int,
        height: Int
    ) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: pixelFormat,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.storageMode = .private
        descriptor.usage = [.renderTarget, .shaderRead]
        return try XCTUnwrap(device.makeTexture(descriptor: descriptor))
    }

    private func readPixel(
        from texture: any MTLTexture,
        x: Int,
        y: Int
    ) throws -> HDRMetalReadbackPixel {
        guard (0..<texture.width).contains(x),
              (0..<texture.height).contains(y) else {
            throw HDRMetalReadbackTestError.invalidReadbackCoordinate
        }
        let bytesPerPixel: Int
        switch texture.pixelFormat {
        case .bgra8Unorm_srgb: bytesPerPixel = 4
        case .rgba16Float: bytesPerPixel = 8
        default:
            XCTFail("Unexpected readback pixel format \(texture.pixelFormat.rawValue)")
            return HDRMetalReadbackPixel(
                rgb: HDRColorVector(x: .nan, y: .nan, z: .nan),
                alpha: .nan
            )
        }
        let bytesPerRow = 256
        let buffer = try XCTUnwrap(device.makeBuffer(
            length: bytesPerRow,
            options: .storageModeShared
        ))
        let commandBuffer = try XCTUnwrap(readbackQueue.makeCommandBuffer())
        let blit = try XCTUnwrap(commandBuffer.makeBlitCommandEncoder())
        blit.copy(
            from: texture,
            sourceSlice: 0,
            sourceLevel: 0,
            sourceOrigin: MTLOrigin(x: x, y: y, z: 0),
            sourceSize: MTLSize(width: 1, height: 1, depth: 1),
            to: buffer,
            destinationOffset: 0,
            destinationBytesPerRow: bytesPerRow,
            destinationBytesPerImage: bytesPerRow
        )
        blit.endEncoding()
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        guard commandBuffer.status == .completed else {
            throw HDRMetalReadbackTestError.blitFailed
        }
        let bytes = buffer.contents().assumingMemoryBound(to: UInt8.self)

        switch texture.pixelFormat {
        case .bgra8Unorm_srgb:
            return HDRMetalReadbackPixel(
                rgb: HDRColorVector(
                    x: decodeSRGB(bytes[2]),
                    y: decodeSRGB(bytes[1]),
                    z: decodeSRGB(bytes[0])
                ),
                alpha: Double(bytes[3]) / 255
            )
        case .rgba16Float:
            XCTAssertEqual(bytesPerPixel, 8)
            let words = buffer.contents().assumingMemoryBound(to: UInt16.self)
            return HDRMetalReadbackPixel(
                rgb: HDRColorVector(
                    x: Double(Float16(bitPattern: words[0])),
                    y: Double(Float16(bitPattern: words[1])),
                    z: Double(Float16(bitPattern: words[2]))
                ),
                alpha: Double(Float16(bitPattern: words[3]))
            )
        default:
            preconditionFailure("The readback pixel format was validated before blitting.")
        }
    }

    private func decodeSRGB(_ byte: UInt8) -> Double {
        let encoded = Double(byte) / 255
        return encoded <= 0.04045
            ? encoded / 12.92
            : pow((encoded + 0.055) / 1.055, 2.4)
    }
}

private enum HDRMetalReadbackTestError: Error {
    case invalidTexturePayload
    case invalidReadbackCoordinate
    case blitFailed
}

private final class HDRMetalReadbackCompletion: @unchecked Sendable {
    private let lock = NSLock()
    private var storedValue: HDRMetalCommandCompletionStatus?

    var value: HDRMetalCommandCompletionStatus? {
        lock.withLock { storedValue }
    }

    func store(_ value: HDRMetalCommandCompletionStatus) {
        lock.withLock { storedValue = value }
    }
}
