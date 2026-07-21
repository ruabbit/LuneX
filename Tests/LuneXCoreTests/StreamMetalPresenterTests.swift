import CoreVideo
import Foundation
@preconcurrency import Metal
import XCTest

final class StreamMetalPresenterTests: XCTestCase {
    func testSDRFrameResolvesExplicitSRGBMetalPresentation() throws {
        let frame = try makeFrame(
            generation: 7,
            frameID: 11,
            metadata: .rec709VideoRange()
        )
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: try makeSnapshot(revision: 3)
        )

        XCTAssertEqual(plan.configuration.decoderGeneration, 7)
        XCTAssertEqual(plan.configuration.displayRevision.rawValue, 3)
        XCTAssertEqual(plan.configuration.mappingMode, .sdr)
        XCTAssertEqual(plan.configuration.surfaceContract.drawablePixelFormat, .bgra8UnormSRGB)
        XCTAssertEqual(plan.configuration.surfaceContract.outputColorSpace, .sRGB)
        XCTAssertEqual(plan.configuration.surfaceContract.outputGamut, .sRGB)
        XCTAssertEqual(plan.configuration.surfaceContract.extendedRangeIntent, .disabled)
        XCTAssertEqual(plan.configuration.surfaceContract.metadataMode, .none)
        XCTAssertEqual(plan.uniforms.inputBitDepth, 8)
        XCTAssertEqual(plan.uniforms.mappingMode, 0)
        XCTAssertEqual(plan.uniforms.currentHeadroom, 1)
    }

    func testHDRFrameResolvesExplicitSDRFallbackUntilEDRSurfaceAdapterOwnsIntent() throws {
        let metadata = VideoColorMetadata.hdr10VideoRange()
        let frame = try makeFrame(
            generation: 9,
            frameID: 12,
            metadata: metadata
        )
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: try makeSnapshot(revision: 4)
        )

        XCTAssertEqual(plan.configuration.colorSignature, HDRRenderColorSignature(metadata: metadata))
        XCTAssertEqual(plan.configuration.mappingMode, .hdrToSDR)
        XCTAssertEqual(plan.configuration.surfaceContract.drawablePixelFormat, .bgra8UnormSRGB)
        XCTAssertEqual(plan.configuration.surfaceContract.extendedRangeIntent, .disabled)
        XCTAssertEqual(plan.uniforms.inputBitDepth, 10)
        XCTAssertEqual(plan.uniforms.mappingMode, 2)
        XCTAssertEqual(plan.uniforms.currentHeadroom, 1)
        XCTAssertGreaterThan(plan.uniforms.sourcePeakNits, 100)
    }

    func testCoordinateRevisionTemporarilyOwnsPresentationRevision() throws {
        let frame = try makeFrame(
            generation: 2,
            frameID: 1,
            metadata: .rec709VideoRange()
        )
        let first = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: try makeSnapshot(revision: 5)
        )
        let replacement = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: try makeSnapshot(revision: 6)
        )

        XCTAssertNotEqual(first.configuration, replacement.configuration)
        XCTAssertEqual(first.configuration.displayRevision.rawValue, 5)
        XCTAssertEqual(replacement.configuration.displayRevision.rawValue, 6)
        XCTAssertEqual(first.uniforms, replacement.uniforms)
    }

    func testZeroCoordinateRevisionFailsClosed() throws {
        let frame = try makeFrame(
            generation: 2,
            frameID: 1,
            metadata: .rec709VideoRange()
        )
        XCTAssertThrowsError(try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: try makeSnapshot(revision: 0)
        )) { error in
            XCTAssertEqual(error as? HDRRenderResolutionError, .invalidDisplayRevision)
        }
    }

    func testProductionRuntimeMapsAndRendersDecodedSDRFrameOffscreen() throws {
        let device = try XCTUnwrap(MTLCreateSystemDefaultDevice())
        let frame = try makeFrame(
            generation: 12,
            frameID: 40,
            metadata: .rec709VideoRange()
        )
        try fillSDRWhite(frame.pixelBuffer)
        let coordinates = try makeSnapshot(revision: 9)
        let plan = try StreamMetalPresentationPlanResolver.resolve(
            frame: frame,
            coordinateSnapshot: coordinates
        )
        let target = try makeTarget(
            device: device,
            width: coordinates.drawableSize.width,
            height: coordinates.drawableSize.height
        )
        let runtime = try StreamMetalPresenterRuntime(
            device: device,
            bundle: Bundle(for: Self.self)
        )

        let result = try runtime.present(
            frame: frame,
            plan: plan,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .waitUntilCompleted
        )

        XCTAssertEqual(result, .submitted(
            frameID: 40,
            decoderGeneration: 12,
            displayRevision: HDRDisplayRevision(rawValue: 9),
            coordinateRevision: 9
        ))
        let pixel = readPixel(
            target,
            x: coordinates.drawableSize.width / 2,
            y: coordinates.drawableSize.height / 2
        )
        XCTAssertGreaterThan(pixel.red, 220)
        XCTAssertGreaterThan(pixel.green, 220)
        XCTAssertGreaterThan(pixel.blue, 220)
        XCTAssertEqual(pixel.alpha, 255)

        runtime.invalidate()
        XCTAssertThrowsError(try runtime.present(
            frame: frame,
            plan: plan,
            coordinateSnapshot: coordinates,
            target: HDRMetalRenderTarget(texture: target),
            completion: .waitUntilCompleted
        )) { error in
            XCTAssertEqual(error as? StreamMetalPresenterError, .invalidatedRuntime)
        }
    }

    private func makeFrame(
        generation: UInt64,
        frameID: UInt64,
        metadata: VideoColorMetadata
    ) throws -> DecodedVideoFrame {
        let format = metadata.isHDR
            ? kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
            : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
        let bitDepth: VideoOutputBitDepth = metadata.isHDR ? .ten : .eight
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            64,
            64,
            format,
            VideoToolboxDecompressionSessionFactory
                .destinationAttributes(for: bitDepth) as CFDictionary,
            &pixelBuffer
        )
        guard status == kCVReturnSuccess, let pixelBuffer else {
            throw TestError.pixelBufferCreationFailed(status)
        }
        return DecodedVideoFrame(
            generation: generation,
            frameID: frameID,
            pixelBuffer: pixelBuffer,
            presentationTimeStamp: .invalid,
            duration: .invalid,
            infoFlags: [],
            colorMetadata: metadata
        )
    }

    private func makeSnapshot(revision: UInt64) throws -> StreamCoordinateSnapshot {
        guard let snapshot = StreamCoordinateSnapshot.resolve(
            revision: revision,
            sourceSize: PixelSize(width: 64, height: 64),
            drawableSize: PixelSize(width: 128, height: 96),
            mode: .fit
        ) else {
            throw TestError.coordinateResolutionFailed
        }
        return snapshot
    }

    private func fillSDRWhite(_ pixelBuffer: CVPixelBuffer) throws {
        guard CVPixelBufferLockBaseAddress(pixelBuffer, []) == kCVReturnSuccess else {
            throw TestError.pixelBufferLockFailed
        }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let luma = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0),
              let chroma = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1) else {
            throw TestError.pixelBufferPlaneMissing
        }
        memset(
            luma,
            235,
            CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
                * CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
        )
        memset(
            chroma,
            128,
            CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1)
                * CVPixelBufferGetHeightOfPlane(pixelBuffer, 1)
        )
    }

    private func makeTarget(
        device: any MTLDevice,
        width: Int,
        height: Int
    ) throws -> any MTLTexture {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .bgra8Unorm_srgb,
            width: width,
            height: height,
            mipmapped: false
        )
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: descriptor) else {
            throw TestError.targetCreationFailed
        }
        return texture
    }

    private func readPixel(
        _ texture: any MTLTexture,
        x: Int,
        y: Int
    ) -> (blue: UInt8, green: UInt8, red: UInt8, alpha: UInt8) {
        var bytes = [UInt8](repeating: 0, count: 4)
        texture.getBytes(
            &bytes,
            bytesPerRow: 4,
            from: MTLRegionMake2D(x, y, 1, 1),
            mipmapLevel: 0
        )
        return (bytes[0], bytes[1], bytes[2], bytes[3])
    }

    private enum TestError: Error {
        case pixelBufferCreationFailed(CVReturn)
        case coordinateResolutionFailed
        case pixelBufferLockFailed
        case pixelBufferPlaneMissing
        case targetCreationFailed
    }
}
