import Foundation
@preconcurrency import Metal
@preconcurrency import QuartzCore

enum HDRMetalVideoRendererError: Error, Equatable, Hashable, Sendable,
    CustomStringConvertible {
    case inactiveRenderer
    case staleRenderConfiguration
    case staleFrameGeneration
    case staleFrameColorSignature
    case invalidFrameContract
    case invalidPlaneContract
    case invalidShaderUniforms
    case invalidCoordinateSnapshot
    case incompatibleSourceGeometry
    case incompatibleDrawableGeometry
    case incompatibleDrawablePixelFormat
    case incompatibleMetalDevice
    case invalidRenderTarget
    case pipelineUnavailable
    case ownershipRevisionExhausted
    case commandSubmissionFailed

    var description: String {
        switch self {
        case .inactiveRenderer:
            return "No active render configuration owns the Metal video renderer."
        case .staleRenderConfiguration:
            return "The submitted render configuration is no longer active."
        case .staleFrameGeneration:
            return "The submitted video frame belongs to a stale decoder generation."
        case .staleFrameColorSignature:
            return "The submitted video frame has a stale color signature."
        case .invalidFrameContract:
            return "The decoded frame contract is invalid for Metal presentation."
        case .invalidPlaneContract:
            return "The zero-copy Metal plane contract is invalid."
        case .invalidShaderUniforms:
            return "The shader uniforms do not match the active render configuration."
        case .invalidCoordinateSnapshot:
            return "The coordinate snapshot is invalid or internally inconsistent."
        case .incompatibleSourceGeometry:
            return "The coordinate source size does not match the decoded frame."
        case .incompatibleDrawableGeometry:
            return "The render target size does not match the coordinate snapshot."
        case .incompatibleDrawablePixelFormat:
            return "The render target pixel format does not match the active surface contract."
        case .incompatibleMetalDevice:
            return "The frame and render target do not belong to the renderer Metal device."
        case .invalidRenderTarget:
            return "The Metal render target cannot receive a video render pass."
        case .pipelineUnavailable:
            return "A compatible Metal video pipeline is unavailable."
        case .ownershipRevisionExhausted:
            return "The renderer ownership revision is exhausted."
        case .commandSubmissionFailed:
            return "Metal could not submit or complete the video render command."
        }
    }
}

struct HDRMetalGeometryUniforms: Equatable, Sendable {
    static let expectedByteCount = 16

    let textureOriginX: Float
    let textureOriginY: Float
    let textureScaleX: Float
    let textureScaleY: Float

    static var hasExpectedMemoryLayout: Bool {
        MemoryLayout<Self>.size == expectedByteCount
            && MemoryLayout<Self>.stride == expectedByteCount
            && MemoryLayout<Self>.alignment == MemoryLayout<Float>.alignment
            && MemoryLayout<Self>.offset(of: \.textureOriginX) == 0
            && MemoryLayout<Self>.offset(of: \.textureOriginY) == 4
            && MemoryLayout<Self>.offset(of: \.textureScaleX) == 8
            && MemoryLayout<Self>.offset(of: \.textureScaleY) == 12
    }
}

struct HDRMetalViewport: Equatable, Sendable {
    let originX: Double
    let originY: Double
    let width: Double
    let height: Double

    var metalValue: MTLViewport {
        MTLViewport(
            originX: originX,
            originY: originY,
            width: width,
            height: height,
            znear: 0,
            zfar: 1
        )
    }
}

struct HDRMetalScissorRectangle: Equatable, Sendable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    var metalValue: MTLScissorRect {
        MTLScissorRect(x: x, y: y, width: width, height: height)
    }
}

struct HDRMetalPresentationGeometry: Equatable, Sendable {
    let coordinateRevision: UInt64
    let viewport: HDRMetalViewport
    let scissorRectangle: HDRMetalScissorRectangle
    let uniforms: HDRMetalGeometryUniforms
}

enum HDRMetalPresentationGeometryResolver {
    static func resolve(
        _ snapshot: StreamCoordinateSnapshot
    ) throws -> HDRMetalPresentationGeometry {
        guard snapshot.revision > 0,
              let expected = StreamCoordinateSnapshot.resolve(
                  revision: snapshot.revision,
                  sourceSize: snapshot.sourceSize,
                  drawableSize: snapshot.drawableSize,
                  mode: snapshot.mode
              ),
              expected == snapshot else {
            throw HDRMetalVideoRendererError.invalidCoordinateSnapshot
        }

        let drawable = snapshot.resolvedVideo.drawableBounds
        let visibleRectangle: StreamCoordinateRect
        switch snapshot.mode {
        case .fit:
            visibleRectangle = snapshot.resolvedVideo.videoRect
        case .fill:
            visibleRectangle = drawable
        }
        guard contains(drawable, visibleRectangle) else {
            throw HDRMetalVideoRendererError.invalidCoordinateSnapshot
        }

        let sourceWidth = Double(snapshot.sourceSize.width)
        let sourceHeight = Double(snapshot.sourceSize.height)
        let crop = snapshot.resolvedVideo.sourceCropRect
        let uniformValues = [
            crop.x / sourceWidth,
            crop.y / sourceHeight,
            crop.width / sourceWidth,
            crop.height / sourceHeight
        ]
        guard uniformValues.allSatisfy({ $0.isFinite && $0 >= 0 && $0 <= 1 }),
              uniformValues[2] > 0,
              uniformValues[3] > 0,
              uniformValues[0] + uniformValues[2] <= 1,
              uniformValues[1] + uniformValues[3] <= 1,
              HDRMetalGeometryUniforms.hasExpectedMemoryLayout else {
            throw HDRMetalVideoRendererError.invalidCoordinateSnapshot
        }

        return HDRMetalPresentationGeometry(
            coordinateRevision: snapshot.revision,
            viewport: HDRMetalViewport(
                originX: visibleRectangle.x,
                originY: visibleRectangle.y,
                width: visibleRectangle.width,
                height: visibleRectangle.height
            ),
            scissorRectangle: HDRMetalScissorRectangle(
                x: 0,
                y: 0,
                width: snapshot.drawableSize.width,
                height: snapshot.drawableSize.height
            ),
            uniforms: HDRMetalGeometryUniforms(
                textureOriginX: Float(uniformValues[0]),
                textureOriginY: Float(uniformValues[1]),
                textureScaleX: Float(uniformValues[2]),
                textureScaleY: Float(uniformValues[3])
            )
        )
    }

    private static func contains(
        _ outer: StreamCoordinateRect,
        _ inner: StreamCoordinateRect
    ) -> Bool {
        inner.x.isFinite
            && inner.y.isFinite
            && inner.width.isFinite
            && inner.height.isFinite
            && inner.width > 0
            && inner.height > 0
            && inner.minX >= outer.minX
            && inner.minY >= outer.minY
            && inner.maxX <= outer.maxX
            && inner.maxY <= outer.maxY
    }
}

enum HDRMetalCommandCompletion: Equatable, Sendable {
    case asynchronous
    case waitUntilCompleted
}

struct HDRMetalRenderTarget: @unchecked Sendable {
    let texture: any MTLTexture
    let drawable: (any CAMetalDrawable)?

    init(texture: any MTLTexture, drawable: (any CAMetalDrawable)? = nil) {
        self.texture = texture
        self.drawable = drawable
    }
}

struct HDRMetalCommandRequest: @unchecked Sendable {
    let pipelineState: HDRMetalPipelineState
    let lumaTexture: any MTLTexture
    let chromaTexture: any MTLTexture
    let target: HDRMetalRenderTarget
    let videoUniforms: HDRMetalShaderUniforms
    let geometry: HDRMetalPresentationGeometry
    let completion: HDRMetalCommandCompletion
}

enum HDRMetalCommandCompletionStatus: Equatable, Sendable {
    case completed
    case failed
}

protocol HDRMetalCommandSubmitting: Sendable {
    func submit(
        _ request: HDRMetalCommandRequest,
        completionHandler: @escaping @Sendable (HDRMetalCommandCompletionStatus) -> Void
    ) throws
}

enum AppleHDRMetalCommandSubmitterError: Error, Equatable, Sendable {
    case commandBufferUnavailable
    case commandEncoderUnavailable
    case commandExecutionFailed
}

final class AppleHDRMetalCommandSubmitter: HDRMetalCommandSubmitting,
    @unchecked Sendable {
    private let commandQueue: any MTLCommandQueue

    init(commandQueue: any MTLCommandQueue) {
        self.commandQueue = commandQueue
    }

    func submit(
        _ request: HDRMetalCommandRequest,
        completionHandler: @escaping @Sendable (HDRMetalCommandCompletionStatus) -> Void
    ) throws {
        let expectedDevice = commandQueue.device.registryID
        guard request.pipelineState.rawValue.device.registryID == expectedDevice,
              request.lumaTexture.device.registryID == expectedDevice,
              request.chromaTexture.device.registryID == expectedDevice,
              request.target.texture.device.registryID == expectedDevice else {
            throw AppleHDRMetalCommandSubmitterError.commandExecutionFailed
        }
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw AppleHDRMetalCommandSubmitterError.commandBufferUnavailable
        }
        commandBuffer.label = "LuneX video frame"

        let renderPass = MTLRenderPassDescriptor()
        renderPass.colorAttachments[0].texture = request.target.texture
        renderPass.colorAttachments[0].loadAction = .clear
        renderPass.colorAttachments[0].storeAction = .store
        renderPass.colorAttachments[0].clearColor = MTLClearColor(
            red: 0,
            green: 0,
            blue: 0,
            alpha: 1
        )
        guard let encoder = commandBuffer.makeRenderCommandEncoder(
            descriptor: renderPass
        ) else {
            throw AppleHDRMetalCommandSubmitterError.commandEncoderUnavailable
        }
        encoder.label = "LuneX HDR video"
        encoder.setRenderPipelineState(request.pipelineState.rawValue)
        encoder.setViewport(request.geometry.viewport.metalValue)
        encoder.setScissorRect(request.geometry.scissorRectangle.metalValue)
        var geometryUniforms = request.geometry.uniforms
        encoder.setVertexBytes(
            &geometryUniforms,
            length: MemoryLayout<HDRMetalGeometryUniforms>.stride,
            index: 0
        )
        encoder.setFragmentTexture(request.lumaTexture, index: 0)
        encoder.setFragmentTexture(request.chromaTexture, index: 1)
        var videoUniforms = request.videoUniforms
        encoder.setFragmentBytes(
            &videoUniforms,
            length: MemoryLayout<HDRMetalShaderUniforms>.stride,
            index: 0
        )
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        if let drawable = request.target.drawable {
            commandBuffer.present(drawable)
        }
        if request.completion == .waitUntilCompleted {
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            let status: HDRMetalCommandCompletionStatus = commandBuffer.status == .completed
                ? .completed : .failed
            completionHandler(status)
            guard commandBuffer.status == .completed else {
                throw AppleHDRMetalCommandSubmitterError.commandExecutionFailed
            }
        } else {
            commandBuffer.addCompletedHandler { completedBuffer in
                completionHandler(
                    completedBuffer.status == .completed ? .completed : .failed
                )
            }
            commandBuffer.commit()
        }
    }
}

struct HDRMetalVideoRendererSnapshot: Equatable, Sendable {
    let activeConfiguration: HDRRenderConfigurationIdentity?
    let ownershipRevision: UInt64
    let submittedFrameCount: UInt64
    let completedFrameCount: UInt64
    let failedFrameCount: UInt64
    let staleCompletionCount: UInt64
    let rejectedFrameCount: UInt64
    let replacementCount: UInt64
    let stopCount: UInt64
    let lastCoordinateRevision: UInt64?
    let lastCompletedFrameID: UInt64?
}

enum HDRMetalVideoRendererResult: Equatable, Sendable {
    case submitted(
        frameID: UInt64,
        decoderGeneration: UInt64,
        displayRevision: HDRDisplayRevision,
        coordinateRevision: UInt64
    )
}

final class HDRMetalVideoRenderer: @unchecked Sendable {
    private let device: any MTLDevice
    private let pipelineCache: HDRMetalPipelineStateCache
    private let commandSubmitter: any HDRMetalCommandSubmitting
    private let lock = NSRecursiveLock()

    private var activeConfiguration: HDRRenderConfigurationIdentity?
    private var ownershipRevision: UInt64 = 0
    private var submittedFrameCount: UInt64 = 0
    private var completedFrameCount: UInt64 = 0
    private var failedFrameCount: UInt64 = 0
    private var staleCompletionCount: UInt64 = 0
    private var rejectedFrameCount: UInt64 = 0
    private var replacementCount: UInt64 = 0
    private var stopCount: UInt64 = 0
    private var lastCoordinateRevision: UInt64?
    private var lastCompletedFrameID: UInt64?

    init(
        device: any MTLDevice,
        pipelineCache: HDRMetalPipelineStateCache,
        commandSubmitter: any HDRMetalCommandSubmitting
    ) {
        self.device = device
        self.pipelineCache = pipelineCache
        self.commandSubmitter = commandSubmitter
    }

    convenience init(
        device: any MTLDevice,
        bundle: Bundle,
        pipelineCacheCapacity: Int = 6
    ) throws {
        guard let commandQueue = device.makeCommandQueue() else {
            throw HDRMetalVideoRendererError.commandSubmissionFailed
        }
        let factory = try AppleHDRMetalPipelineStateFactory(device: device, bundle: bundle)
        let cache = try HDRMetalPipelineStateCache(
            capacity: pipelineCacheCapacity,
            factory: factory
        )
        self.init(
            device: device,
            pipelineCache: cache,
            commandSubmitter: AppleHDRMetalCommandSubmitter(commandQueue: commandQueue)
        )
    }

    func replaceConfiguration(_ configuration: HDRRenderConfigurationIdentity) throws {
        try lock.withLock {
            guard configuration != activeConfiguration else { return }
            let nextRevision = ownershipRevision.addingReportingOverflow(1)
            guard !nextRevision.overflow else {
                activeConfiguration = nil
                lastCoordinateRevision = nil
                lastCompletedFrameID = nil
                pipelineCache.removeAll()
                throw HDRMetalVideoRendererError.ownershipRevisionExhausted
            }
            if activeConfiguration != nil {
                replacementCount &+= 1
                pipelineCache.removeAll()
            }
            ownershipRevision = nextRevision.partialValue
            activeConfiguration = configuration
            lastCoordinateRevision = nil
            lastCompletedFrameID = nil
        }
    }

    func render(
        frame: MetalVideoFrame,
        configuration: HDRRenderConfigurationIdentity,
        uniforms: HDRMetalShaderUniforms,
        coordinateSnapshot: StreamCoordinateSnapshot,
        target: HDRMetalRenderTarget,
        completion: HDRMetalCommandCompletion = .asynchronous
    ) throws -> HDRMetalVideoRendererResult {
        try lock.withLock {
            do {
                let result = try renderLocked(
                    frame: frame,
                    configuration: configuration,
                    uniforms: uniforms,
                    coordinateSnapshot: coordinateSnapshot,
                    target: target,
                    completion: completion
                )
                submittedFrameCount &+= 1
                lastCoordinateRevision = coordinateSnapshot.revision
                return result
            } catch let error as HDRMetalVideoRendererError {
                rejectedFrameCount &+= 1
                throw error
            } catch {
                rejectedFrameCount &+= 1
                throw HDRMetalVideoRendererError.commandSubmissionFailed
            }
        }
    }

    func stop() {
        lock.withLock {
            guard activeConfiguration != nil else { return }
            activeConfiguration = nil
            if ownershipRevision < .max {
                ownershipRevision += 1
            }
            lastCoordinateRevision = nil
            lastCompletedFrameID = nil
            stopCount &+= 1
            pipelineCache.removeAll()
        }
    }

    func snapshot() -> HDRMetalVideoRendererSnapshot {
        lock.withLock {
            HDRMetalVideoRendererSnapshot(
                activeConfiguration: activeConfiguration,
                ownershipRevision: ownershipRevision,
                submittedFrameCount: submittedFrameCount,
                completedFrameCount: completedFrameCount,
                failedFrameCount: failedFrameCount,
                staleCompletionCount: staleCompletionCount,
                rejectedFrameCount: rejectedFrameCount,
                replacementCount: replacementCount,
                stopCount: stopCount,
                lastCoordinateRevision: lastCoordinateRevision,
                lastCompletedFrameID: lastCompletedFrameID
            )
        }
    }

    deinit {
        stop()
    }

    private func renderLocked(
        frame: MetalVideoFrame,
        configuration: HDRRenderConfigurationIdentity,
        uniforms: HDRMetalShaderUniforms,
        coordinateSnapshot: StreamCoordinateSnapshot,
        target: HDRMetalRenderTarget,
        completion: HDRMetalCommandCompletion
    ) throws -> HDRMetalVideoRendererResult {
        guard let activeConfiguration else {
            throw HDRMetalVideoRendererError.inactiveRenderer
        }
        guard activeConfiguration == configuration else {
            throw HDRMetalVideoRendererError.staleRenderConfiguration
        }
        do {
            try frame.validateRenderCompatibility(with: configuration)
        } catch HDRRenderResolutionError.staleColorSignature {
            throw HDRMetalVideoRendererError.staleFrameColorSignature
        } catch {
            throw HDRMetalVideoRendererError.staleFrameGeneration
        }

        let frameContract: HDRValidatedDecodedFrameContract
        do {
            frameContract = try HDRDecodedVideoContractValidator.validateForMetalMapping(
                pixelBuffer: frame.decodedFrame.pixelBuffer,
                colorMetadata: frame.decodedFrame.colorMetadata
            )
        } catch {
            throw HDRMetalVideoRendererError.invalidFrameContract
        }
        guard frameContract.colorSignature == configuration.colorSignature else {
            throw HDRMetalVideoRendererError.staleFrameColorSignature
        }
        guard coordinateSnapshot.sourceSize == PixelSize(
            width: frameContract.width,
            height: frameContract.height
        ) else {
            throw HDRMetalVideoRendererError.incompatibleSourceGeometry
        }
        try validatePlanes(frame, contract: frameContract)
        try validateUniforms(
            uniforms,
            frameContract: frameContract,
            configuration: configuration
        )

        let geometry = try HDRMetalPresentationGeometryResolver.resolve(
            coordinateSnapshot
        )
        try validateTarget(
            target,
            coordinateSnapshot: coordinateSnapshot,
            configuration: configuration
        )

        let key: HDRMetalPipelineKey
        let state: HDRMetalPipelineState
        do {
            key = try HDRMetalPipelineKey(
                frameContract: frameContract,
                configuration: configuration
            )
            state = try pipelineCache.pipelineState(for: key)
        } catch {
            throw HDRMetalVideoRendererError.pipelineUnavailable
        }
        guard state.rawValue.device.registryID == device.registryID else {
            throw HDRMetalVideoRendererError.incompatibleMetalDevice
        }

        do {
            let submittedOwnershipRevision = ownershipRevision
            let submittedFrameID = frame.frameID
            try commandSubmitter.submit(HDRMetalCommandRequest(
                pipelineState: state,
                lumaTexture: frame.luma.texture,
                chromaTexture: frame.chroma.texture,
                target: target,
                videoUniforms: uniforms,
                geometry: geometry,
                completion: completion
            )) { [weak self] status in
                self?.handleCompletion(
                    status,
                    ownershipRevision: submittedOwnershipRevision,
                    frameID: submittedFrameID
                )
            }
        } catch {
            pipelineCache.removeAll()
            throw HDRMetalVideoRendererError.commandSubmissionFailed
        }
        return .submitted(
            frameID: frame.frameID,
            decoderGeneration: configuration.decoderGeneration,
            displayRevision: configuration.displayRevision,
            coordinateRevision: coordinateSnapshot.revision
        )
    }

    private func validatePlanes(
        _ frame: MetalVideoFrame,
        contract: HDRValidatedDecodedFrameContract
    ) throws {
        guard frame.luma.role == .luma, frame.chroma.role == .chroma else {
            throw HDRMetalVideoRendererError.invalidPlaneContract
        }
        let planeContracts = MetalVideoFrameContractResolver.planeContracts(for: contract)
        do {
            try MetalVideoFrameContractResolver.validateTexture(
                descriptor(frame.luma.texture),
                against: planeContracts.luma,
                deviceRegistryID: device.registryID
            )
            try MetalVideoFrameContractResolver.validateTexture(
                descriptor(frame.chroma.texture),
                against: planeContracts.chroma,
                deviceRegistryID: device.registryID
            )
        } catch {
            throw HDRMetalVideoRendererError.invalidPlaneContract
        }
    }

    private func validateUniforms(
        _ uniforms: HDRMetalShaderUniforms,
        frameContract: HDRValidatedDecodedFrameContract,
        configuration: HDRRenderConfigurationIdentity
    ) throws {
        let expectedMatrix: UInt32 = configuration.colorSignature.matrix == .ituR2020 ? 1 : 0
        let expectedTransfer: UInt32 = configuration.colorSignature.transferFunction
            == .smpteST2084PQ ? 1 : 0
        let expectedGamut: UInt32
        switch configuration.surfaceContract.outputGamut {
        case .sRGB: expectedGamut = 0
        case .displayP3: expectedGamut = 1
        case .ituR2020: expectedGamut = 2
        }
        let expectedMapping: UInt32
        switch configuration.mappingMode {
        case .sdr: expectedMapping = 0
        case .hdrEDR: expectedMapping = 1
        case .hdrToSDR: expectedMapping = 2
        }
        let expectedPeak: Float
        if configuration.mappingMode == .sdr {
            expectedPeak = Float(HDRLuminanceMapping.referenceWhiteNits)
        } else {
            guard let peak = try? HDRSourcePeakResolver.resolve(
                configuration.colorSignature
            ) else {
                throw HDRMetalVideoRendererError.invalidShaderUniforms
            }
            expectedPeak = Float(peak.luminanceNits)
        }
        let headroomIsValid: Bool
        switch configuration.mappingMode {
        case .sdr, .hdrToSDR:
            headroomIsValid = uniforms.currentHeadroom == 1
        case .hdrEDR:
            headroomIsValid = uniforms.currentHeadroom.isFinite
                && uniforms.currentHeadroom >= 1
                && uniforms.currentHeadroom <= 64
        }
        guard HDRMetalShaderUniforms.hasExpectedMemoryLayout,
              uniforms.inputBitDepth == UInt32(frameContract.pixelLayout.bitDepth),
              uniforms.yCbCrMatrix == expectedMatrix,
              uniforms.transferFunction == expectedTransfer,
              uniforms.outputGamut == expectedGamut,
              uniforms.mappingMode == expectedMapping,
              uniforms.sourcePeakNits == expectedPeak,
              headroomIsValid,
              uniforms.reserved == 0 else {
            throw HDRMetalVideoRendererError.invalidShaderUniforms
        }
    }

    private func validateTarget(
        _ target: HDRMetalRenderTarget,
        coordinateSnapshot: StreamCoordinateSnapshot,
        configuration: HDRRenderConfigurationIdentity
    ) throws {
        let texture = target.texture
        guard texture.width == coordinateSnapshot.drawableSize.width,
              texture.height == coordinateSnapshot.drawableSize.height else {
            throw HDRMetalVideoRendererError.incompatibleDrawableGeometry
        }
        guard texture.pixelFormat == configuration.surfaceContract.drawablePixelFormat
            .metalPixelFormat else {
            throw HDRMetalVideoRendererError.incompatibleDrawablePixelFormat
        }
        guard texture.device.registryID == device.registryID else {
            throw HDRMetalVideoRendererError.incompatibleMetalDevice
        }
        if let drawable = target.drawable {
            guard ObjectIdentifier(drawable.texture as AnyObject)
                == ObjectIdentifier(texture as AnyObject) else {
                throw HDRMetalVideoRendererError.invalidRenderTarget
            }
        }
        guard texture.textureType == .type2D,
              texture.sampleCount == 1,
              texture.usage.contains(.renderTarget) else {
            throw HDRMetalVideoRendererError.invalidRenderTarget
        }
    }

    private func descriptor(_ texture: any MTLTexture) -> MetalVideoTextureDescriptor {
        MetalVideoTextureDescriptor(
            pixelFormat: texture.pixelFormat,
            width: texture.width,
            height: texture.height,
            deviceRegistryID: texture.device.registryID
        )
    }

    private func handleCompletion(
        _ status: HDRMetalCommandCompletionStatus,
        ownershipRevision: UInt64,
        frameID: UInt64
    ) {
        lock.withLock {
            guard activeConfiguration != nil,
                  self.ownershipRevision == ownershipRevision else {
                staleCompletionCount &+= 1
                return
            }
            switch status {
            case .completed:
                completedFrameCount &+= 1
                lastCompletedFrameID = frameID
            case .failed:
                failedFrameCount &+= 1
                pipelineCache.removeAll()
            }
        }
    }
}

private extension HDRDrawablePixelFormat {
    var metalPixelFormat: MTLPixelFormat {
        switch self {
        case .bgra8UnormSRGB: .bgra8Unorm_srgb
        case .rgba16Float: .rgba16Float
        }
    }
}
