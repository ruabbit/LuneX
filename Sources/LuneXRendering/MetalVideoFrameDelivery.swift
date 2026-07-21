@preconcurrency import CoreVideo
import Foundation
@preconcurrency import Metal

enum MetalVideoPlaneRole: Int, Equatable, Sendable {
    case luma = 0
    case chroma = 1
}

enum MetalFrameDeliveryError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidQueueCapacity(Int)
    case textureCacheCreationFailed(CVReturn)
    case unsupportedPixelFormat(OSType)
    case invalidDecodedContract(HDRDecodedVideoContractError)
    case invalidPixelBufferDimensions
    case invalidPlaneCount(Int)
    case invalidPlaneDimensions(MetalVideoPlaneRole)
    case incompatibleColorSignature
    case textureCreationFailed(plane: MetalVideoPlaneRole, status: CVReturn)
    case missingMetalTexture(MetalVideoPlaneRole)
    case unexpectedMetalTextureDimensions(MetalVideoPlaneRole)
    case unexpectedMetalTexturePixelFormat(MetalVideoPlaneRole)
    case unexpectedMetalTextureDevice(MetalVideoPlaneRole)

    var description: String {
        switch self {
        case let .invalidQueueCapacity(capacity):
            return "Metal frame queue capacity \(capacity) is outside the supported bound."
        case let .textureCacheCreationFailed(status):
            return "CoreVideo could not create the Metal texture cache (\(status))."
        case let .unsupportedPixelFormat(format):
            return "CVPixelBuffer format \(format) is unsupported by the zero-copy Metal path."
        case let .invalidDecodedContract(error):
            return "The decoded frame is incompatible with Metal mapping: \(error.description)"
        case .invalidPixelBufferDimensions:
            return "The decoded pixel buffer dimensions are invalid."
        case let .invalidPlaneCount(count):
            return "The decoded pixel buffer has \(count) planes instead of two."
        case let .invalidPlaneDimensions(plane):
            return "The decoded \(plane) plane has invalid dimensions."
        case .incompatibleColorSignature:
            return "The decoded frame color signature changed before Metal mapping."
        case let .textureCreationFailed(plane, status):
            return "CoreVideo could not map the \(plane) plane to Metal (\(status))."
        case let .missingMetalTexture(plane):
            return "CoreVideo returned no Metal texture for the \(plane) plane."
        case let .unexpectedMetalTextureDimensions(plane):
            return "CoreVideo returned unexpected Metal texture dimensions for the \(plane) plane."
        case let .unexpectedMetalTexturePixelFormat(plane):
            return "CoreVideo returned an unexpected Metal pixel format for the \(plane) plane."
        case let .unexpectedMetalTextureDevice(plane):
            return "CoreVideo returned the \(plane) plane on an unexpected Metal device."
        }
    }
}

struct MetalVideoPlaneContract: Equatable, Sendable {
    let role: MetalVideoPlaneRole
    let pixelFormat: MTLPixelFormat
    let dimensions: HDRDecodedPlaneDimensions
}

struct MetalVideoTextureDescriptor: Equatable, Sendable {
    let pixelFormat: MTLPixelFormat
    let width: Int
    let height: Int
    let deviceRegistryID: UInt64
}

enum MetalVideoFrameContractResolver {
    static func planeContracts(
        for frameContract: HDRValidatedDecodedFrameContract
    ) -> (luma: MetalVideoPlaneContract, chroma: MetalVideoPlaneContract) {
        let formats: (luma: MTLPixelFormat, chroma: MTLPixelFormat)
        switch frameContract.pixelLayout {
        case .nv12VideoRange8:
            formats = (.r8Unorm, .rg8Unorm)
        case .p010VideoRange10:
            formats = (.r16Unorm, .rg16Unorm)
        }
        return (
            MetalVideoPlaneContract(
                role: .luma,
                pixelFormat: formats.luma,
                dimensions: HDRDecodedPlaneDimensions(
                    width: frameContract.width,
                    height: frameContract.height
                )
            ),
            MetalVideoPlaneContract(
                role: .chroma,
                pixelFormat: formats.chroma,
                dimensions: HDRDecodedPlaneDimensions(
                    width: frameContract.width / 2 + frameContract.width % 2,
                    height: frameContract.height / 2 + frameContract.height % 2
                )
            )
        )
    }

    static func validateTexture(
        _ texture: MetalVideoTextureDescriptor,
        against planeContract: MetalVideoPlaneContract,
        deviceRegistryID: UInt64
    ) throws {
        guard texture.width == planeContract.dimensions.width,
              texture.height == planeContract.dimensions.height else {
            throw MetalFrameDeliveryError.unexpectedMetalTextureDimensions(
                planeContract.role
            )
        }
        guard texture.pixelFormat == planeContract.pixelFormat else {
            throw MetalFrameDeliveryError.unexpectedMetalTexturePixelFormat(
                planeContract.role
            )
        }
        guard texture.deviceRegistryID == deviceRegistryID else {
            throw MetalFrameDeliveryError.unexpectedMetalTextureDevice(
                planeContract.role
            )
        }
    }
}

struct MetalVideoTexturePlane: @unchecked Sendable {
    let role: MetalVideoPlaneRole
    let coreVideoTexture: CVMetalTexture
    let texture: any MTLTexture
}

struct MetalVideoFrame: @unchecked Sendable {
    let decodedFrame: DecodedVideoFrame
    let luma: MetalVideoTexturePlane
    let chroma: MetalVideoTexturePlane

    var generation: UInt64 { decodedFrame.generation }
    var frameID: UInt64 { decodedFrame.frameID }
    var renderBinding: HDRFrameRenderBinding { decodedFrame.renderBinding }

    func validateRenderCompatibility(
        with configuration: HDRRenderConfigurationIdentity
    ) throws {
        try renderBinding.validateCompatibility(with: configuration)
    }
}

protocol MetalVideoFrameMapping: Sendable {
    func map(_ frame: DecodedVideoFrame) throws -> MetalVideoFrame
    func flush()
}

final class CVMetalVideoFrameMapper: MetalVideoFrameMapping, @unchecked Sendable {
    let device: any MTLDevice

    private let lock = NSLock()
    private let textureCache: CVMetalTextureCache

    init(device: any MTLDevice) throws {
        self.device = device
        var cache: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &cache
        )
        guard status == kCVReturnSuccess, let cache else {
            throw MetalFrameDeliveryError.textureCacheCreationFailed(status)
        }
        textureCache = cache
    }

    func map(_ frame: DecodedVideoFrame) throws -> MetalVideoFrame {
        try lock.withLock {
            let pixelBuffer = frame.pixelBuffer
            let frameContract: HDRValidatedDecodedFrameContract
            do {
                frameContract = try HDRDecodedVideoContractValidator.validateForMetalMapping(
                    pixelBuffer: pixelBuffer,
                    colorMetadata: frame.colorMetadata
                )
            } catch let error as HDRDecodedVideoContractError {
                throw metalDeliveryError(for: error)
            }
            guard frameContract.colorSignature == frame.renderBinding.colorSignature else {
                throw MetalFrameDeliveryError.incompatibleColorSignature
            }
            let planeContracts = MetalVideoFrameContractResolver.planeContracts(
                for: frameContract
            )
            let luma = try makePlane(
                contract: planeContracts.luma,
                pixelBuffer: pixelBuffer
            )
            let chroma = try makePlane(
                contract: planeContracts.chroma,
                pixelBuffer: pixelBuffer
            )
            return MetalVideoFrame(
                decodedFrame: frame,
                luma: luma,
                chroma: chroma
            )
        }
    }

    func flush() {
        lock.withLock {
            CVMetalTextureCacheFlush(textureCache, 0)
        }
    }

    deinit {
        CVMetalTextureCacheFlush(textureCache, 0)
    }

    private func metalDeliveryError(
        for error: HDRDecodedVideoContractError
    ) -> MetalFrameDeliveryError {
        switch error {
        case let .unsupportedPixelFormat(format):
            return .unsupportedPixelFormat(format)
        case .invalidDimensions:
            return .invalidPixelBufferDimensions
        case let .invalidPlaneCount(count):
            return .invalidPlaneCount(count)
        case .invalidPlaneDimensions(.luma):
            return .invalidPlaneDimensions(.luma)
        case .invalidPlaneDimensions(.chroma):
            return .invalidPlaneDimensions(.chroma)
        default:
            return .invalidDecodedContract(error)
        }
    }

    private func makePlane(
        contract: MetalVideoPlaneContract,
        pixelBuffer: CVPixelBuffer
    ) throws -> MetalVideoTexturePlane {
        let role = contract.role
        let planeIndex = role.rawValue
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        guard width == contract.dimensions.width,
              height == contract.dimensions.height else {
            throw MetalFrameDeliveryError.invalidPlaneDimensions(role)
        }

        var coreVideoTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            contract.pixelFormat,
            width,
            height,
            planeIndex,
            &coreVideoTexture
        )
        guard status == kCVReturnSuccess, let coreVideoTexture else {
            throw MetalFrameDeliveryError.textureCreationFailed(
                plane: role,
                status: status
            )
        }
        guard let texture = CVMetalTextureGetTexture(coreVideoTexture) else {
            throw MetalFrameDeliveryError.missingMetalTexture(role)
        }
        try MetalVideoFrameContractResolver.validateTexture(
            MetalVideoTextureDescriptor(
                pixelFormat: texture.pixelFormat,
                width: texture.width,
                height: texture.height,
                deviceRegistryID: texture.device.registryID
            ),
            against: contract,
            deviceRegistryID: device.registryID
        )
        return MetalVideoTexturePlane(
            role: role,
            coreVideoTexture: coreVideoTexture,
            texture: texture
        )
    }
}

struct MetalFrameQueueConfiguration: Equatable, Sendable {
    static let realtime = MetalFrameQueueConfiguration(capacity: 3)
    static let maximumCapacity = 8

    var capacity: Int

    func validate() throws {
        guard (1...Self.maximumCapacity).contains(capacity) else {
            throw MetalFrameDeliveryError.invalidQueueCapacity(capacity)
        }
    }
}

struct MetalFrameQueueSnapshot: Equatable, Sendable {
    var activeGeneration: UInt64?
    var activeColorSignature: HDRRenderColorSignature?
    var activeDisplayRevision: HDRDisplayRevision?
    var capacity: Int
    var queuedFrameCount: Int
    var enqueuedFrameCount: UInt64
    var deliveredFrameCount: UInt64
    var capacityDropCount: UInt64
    var latestFrameSupersededCount: UInt64
    var staleGenerationDropCount: UInt64
    var staleColorSignatureDropCount: UInt64
    var staleDisplayRevisionDropCount: UInt64
    var staleRenderContractDropCount: UInt64
    var generationResetDropCount: UInt64
    var renderContractResetDropCount: UInt64
}

enum MetalFrameQueueResult: Equatable, Sendable {
    case configurationStarted(
        generation: UInt64,
        displayRevision: HDRDisplayRevision,
        discardedFrames: Int
    )
    case enqueued(
        generation: UInt64,
        displayRevision: HDRDisplayRevision,
        frameID: UInt64,
        evictedFrames: Int
    )
    case rejectedInactive(frameID: UInt64)
    case rejectedStaleGeneration(expected: UInt64, actual: UInt64, frameID: UInt64)
    case rejectedStaleColorSignature(generation: UInt64, frameID: UInt64)
    case rejectedStaleDisplayRevision(
        expected: HDRDisplayRevision,
        actual: HDRDisplayRevision,
        frameID: UInt64
    )
    case rejectedStaleRenderContract(
        generation: UInt64,
        displayRevision: HDRDisplayRevision,
        frameID: UInt64
    )
    case configurationStopped(
        generation: UInt64,
        displayRevision: HDRDisplayRevision,
        discardedFrames: Int
    )
    case ignored
}

actor BoundedMetalFrameQueue {
    private struct QueuedFrame: @unchecked Sendable {
        let frame: MetalVideoFrame
        let configuration: HDRRenderConfigurationIdentity
    }

    private let configuration: MetalFrameQueueConfiguration
    private let mapper: any MetalVideoFrameMapping
    private var activeRenderConfiguration: HDRRenderConfigurationIdentity?
    private var queuedFrames: [QueuedFrame] = []
    private var enqueuedFrameCount: UInt64 = 0
    private var deliveredFrameCount: UInt64 = 0
    private var capacityDropCount: UInt64 = 0
    private var latestFrameSupersededCount: UInt64 = 0
    private var staleGenerationDropCount: UInt64 = 0
    private var staleColorSignatureDropCount: UInt64 = 0
    private var staleDisplayRevisionDropCount: UInt64 = 0
    private var staleRenderContractDropCount: UInt64 = 0
    private var generationResetDropCount: UInt64 = 0
    private var renderContractResetDropCount: UInt64 = 0

    init(
        configuration: MetalFrameQueueConfiguration = .realtime,
        mapper: any MetalVideoFrameMapping
    ) throws {
        try configuration.validate()
        self.configuration = configuration
        self.mapper = mapper
        queuedFrames.reserveCapacity(configuration.capacity)
    }

    deinit {
        mapper.flush()
    }

    @discardableResult
    func applyRenderConfiguration(
        _ renderConfiguration: HDRRenderConfigurationIdentity
    ) -> MetalFrameQueueResult {
        guard activeRenderConfiguration != renderConfiguration else { return .ignored }
        let discardedFrames = queuedFrames.count
        if let activeRenderConfiguration,
           activeRenderConfiguration.decoderGeneration == renderConfiguration.decoderGeneration {
            renderContractResetDropCount &+= UInt64(discardedFrames)
        } else {
            generationResetDropCount &+= UInt64(discardedFrames)
        }
        queuedFrames.removeAll(keepingCapacity: true)
        mapper.flush()
        activeRenderConfiguration = renderConfiguration
        return .configurationStarted(
            generation: renderConfiguration.decoderGeneration,
            displayRevision: renderConfiguration.displayRevision,
            discardedFrames: discardedFrames
        )
    }

    @discardableResult
    func enqueue(
        _ decodedFrame: DecodedVideoFrame,
        configuration renderConfiguration: HDRRenderConfigurationIdentity
    ) throws -> MetalFrameQueueResult {
        guard let activeRenderConfiguration else {
            return .rejectedInactive(frameID: decodedFrame.frameID)
        }
        if let rejection = rejectMismatch(
            actual: renderConfiguration,
            expected: activeRenderConfiguration,
            frameID: decodedFrame.frameID
        ) {
            return rejection
        }
        guard decodedFrame.generation == activeRenderConfiguration.decoderGeneration else {
            return rejectGeneration(
                expected: activeRenderConfiguration.decoderGeneration,
                actual: decodedFrame.generation,
                frameID: decodedFrame.frameID
            )
        }
        guard decodedFrame.renderBinding.colorSignature
                == activeRenderConfiguration.colorSignature else {
            return rejectColorSignature(
                generation: decodedFrame.generation,
                frameID: decodedFrame.frameID
            )
        }

        let mappedFrame = try mapper.map(decodedFrame)
        let evictionCount = max(0, queuedFrames.count - configuration.capacity + 1)
        if evictionCount > 0 {
            queuedFrames.removeFirst(evictionCount)
            capacityDropCount &+= UInt64(evictionCount)
        }
        queuedFrames.append(QueuedFrame(
            frame: mappedFrame,
            configuration: activeRenderConfiguration
        ))
        enqueuedFrameCount &+= 1
        return .enqueued(
            generation: activeRenderConfiguration.decoderGeneration,
            displayRevision: activeRenderConfiguration.displayRevision,
            frameID: decodedFrame.frameID,
            evictedFrames: evictionCount
        )
    }

    func dequeueLatest(
        configuration renderConfiguration: HDRRenderConfigurationIdentity
    ) -> MetalVideoFrame? {
        guard let activeRenderConfiguration,
              let latestFrame = queuedFrames.last else { return nil }
        guard rejectMismatch(
            actual: renderConfiguration,
            expected: activeRenderConfiguration,
            frameID: latestFrame.frame.frameID
        ) == nil else {
            return nil
        }
        guard latestFrame.configuration == activeRenderConfiguration else {
            staleRenderContractDropCount &+= 1
            queuedFrames.removeAll(keepingCapacity: true)
            mapper.flush()
            return nil
        }
        let supersededCount = queuedFrames.count - 1
        latestFrameSupersededCount &+= UInt64(supersededCount)
        deliveredFrameCount &+= 1
        queuedFrames.removeAll(keepingCapacity: true)
        return latestFrame.frame
    }

    @discardableResult
    func stopRenderConfiguration(
        _ renderConfiguration: HDRRenderConfigurationIdentity
    ) -> MetalFrameQueueResult {
        guard renderConfiguration == activeRenderConfiguration else { return .ignored }
        let discardedFrames = queuedFrames.count
        generationResetDropCount &+= UInt64(discardedFrames)
        queuedFrames.removeAll(keepingCapacity: true)
        activeRenderConfiguration = nil
        mapper.flush()
        return .configurationStopped(
            generation: renderConfiguration.decoderGeneration,
            displayRevision: renderConfiguration.displayRevision,
            discardedFrames: discardedFrames
        )
    }

    func snapshot() -> MetalFrameQueueSnapshot {
        MetalFrameQueueSnapshot(
            activeGeneration: activeRenderConfiguration?.decoderGeneration,
            activeColorSignature: activeRenderConfiguration?.colorSignature,
            activeDisplayRevision: activeRenderConfiguration?.displayRevision,
            capacity: configuration.capacity,
            queuedFrameCount: queuedFrames.count,
            enqueuedFrameCount: enqueuedFrameCount,
            deliveredFrameCount: deliveredFrameCount,
            capacityDropCount: capacityDropCount,
            latestFrameSupersededCount: latestFrameSupersededCount,
            staleGenerationDropCount: staleGenerationDropCount,
            staleColorSignatureDropCount: staleColorSignatureDropCount,
            staleDisplayRevisionDropCount: staleDisplayRevisionDropCount,
            staleRenderContractDropCount: staleRenderContractDropCount,
            generationResetDropCount: generationResetDropCount,
            renderContractResetDropCount: renderContractResetDropCount
        )
    }

    private func rejectMismatch(
        actual: HDRRenderConfigurationIdentity,
        expected: HDRRenderConfigurationIdentity,
        frameID: UInt64
    ) -> MetalFrameQueueResult? {
        guard actual.decoderGeneration == expected.decoderGeneration else {
            return rejectGeneration(
                expected: expected.decoderGeneration,
                actual: actual.decoderGeneration,
                frameID: frameID
            )
        }
        guard actual.colorSignature == expected.colorSignature else {
            return rejectColorSignature(
                generation: actual.decoderGeneration,
                frameID: frameID
            )
        }
        guard actual.displayRevision == expected.displayRevision else {
            staleDisplayRevisionDropCount &+= 1
            return .rejectedStaleDisplayRevision(
                expected: expected.displayRevision,
                actual: actual.displayRevision,
                frameID: frameID
            )
        }
        guard actual == expected else {
            staleRenderContractDropCount &+= 1
            return .rejectedStaleRenderContract(
                generation: actual.decoderGeneration,
                displayRevision: actual.displayRevision,
                frameID: frameID
            )
        }
        return nil
    }

    private func rejectGeneration(
        expected: UInt64,
        actual: UInt64,
        frameID: UInt64
    ) -> MetalFrameQueueResult {
        staleGenerationDropCount &+= 1
        return .rejectedStaleGeneration(
            expected: expected,
            actual: actual,
            frameID: frameID
        )
    }

    private func rejectColorSignature(
        generation: UInt64,
        frameID: UInt64
    ) -> MetalFrameQueueResult {
        staleColorSignatureDropCount &+= 1
        return .rejectedStaleColorSignature(
            generation: generation,
            frameID: frameID
        )
    }
}
