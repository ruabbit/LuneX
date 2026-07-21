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
    case invalidPlaneCount(Int)
    case invalidPlaneDimensions(MetalVideoPlaneRole)
    case textureCreationFailed(plane: MetalVideoPlaneRole, status: CVReturn)
    case missingMetalTexture(MetalVideoPlaneRole)
    case unexpectedMetalTextureLayout(MetalVideoPlaneRole)

    var description: String {
        switch self {
        case let .invalidQueueCapacity(capacity):
            return "Metal frame queue capacity \(capacity) is outside the supported bound."
        case let .textureCacheCreationFailed(status):
            return "CoreVideo could not create the Metal texture cache (\(status))."
        case let .unsupportedPixelFormat(format):
            return "CVPixelBuffer format \(format) is unsupported by the zero-copy Metal path."
        case let .invalidPlaneCount(count):
            return "The decoded pixel buffer has \(count) planes instead of two."
        case let .invalidPlaneDimensions(plane):
            return "The decoded \(plane) plane has invalid dimensions."
        case let .textureCreationFailed(plane, status):
            return "CoreVideo could not map the \(plane) plane to Metal (\(status))."
        case let .missingMetalTexture(plane):
            return "CoreVideo returned no Metal texture for the \(plane) plane."
        case let .unexpectedMetalTextureLayout(plane):
            return "CoreVideo returned an unexpected Metal layout for the \(plane) plane."
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
    private struct PlaneLayout {
        var luma: MTLPixelFormat
        var chroma: MTLPixelFormat
    }

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
            let layout = try planeLayout(
                for: CVPixelBufferGetPixelFormatType(pixelBuffer)
            )
            let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
            guard planeCount == 2 else {
                throw MetalFrameDeliveryError.invalidPlaneCount(planeCount)
            }
            let luma = try makePlane(
                role: .luma,
                pixelFormat: layout.luma,
                pixelBuffer: pixelBuffer
            )
            let chroma = try makePlane(
                role: .chroma,
                pixelFormat: layout.chroma,
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

    private func planeLayout(for format: OSType) throws -> PlaneLayout {
        switch format {
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange:
            return PlaneLayout(luma: .r8Unorm, chroma: .rg8Unorm)
        case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange:
            return PlaneLayout(luma: .r16Unorm, chroma: .rg16Unorm)
        default:
            throw MetalFrameDeliveryError.unsupportedPixelFormat(format)
        }
    }

    private func makePlane(
        role: MetalVideoPlaneRole,
        pixelFormat: MTLPixelFormat,
        pixelBuffer: CVPixelBuffer
    ) throws -> MetalVideoTexturePlane {
        let planeIndex = role.rawValue
        let width = CVPixelBufferGetWidthOfPlane(pixelBuffer, planeIndex)
        let height = CVPixelBufferGetHeightOfPlane(pixelBuffer, planeIndex)
        guard width > 0, height > 0 else {
            throw MetalFrameDeliveryError.invalidPlaneDimensions(role)
        }

        var coreVideoTexture: CVMetalTexture?
        let status = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            pixelFormat,
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
        guard texture.width == width,
              texture.height == height,
              texture.pixelFormat == pixelFormat,
              texture.device.registryID == device.registryID else {
            throw MetalFrameDeliveryError.unexpectedMetalTextureLayout(role)
        }
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
    var capacity: Int
    var queuedFrameCount: Int
    var enqueuedFrameCount: UInt64
    var deliveredFrameCount: UInt64
    var capacityDropCount: UInt64
    var latestFrameSupersededCount: UInt64
    var staleGenerationDropCount: UInt64
    var generationResetDropCount: UInt64
}

enum MetalFrameQueueResult: Equatable, Sendable {
    case generationStarted(generation: UInt64, discardedFrames: Int)
    case enqueued(generation: UInt64, frameID: UInt64, evictedFrames: Int)
    case rejectedInactive(frameID: UInt64)
    case rejectedStale(generation: UInt64, frameID: UInt64)
    case generationStopped(generation: UInt64, discardedFrames: Int)
    case ignored
}

actor BoundedMetalFrameQueue {
    private let configuration: MetalFrameQueueConfiguration
    private let mapper: any MetalVideoFrameMapping
    private var activeGeneration: UInt64?
    private var queuedFrames: [MetalVideoFrame] = []
    private var enqueuedFrameCount: UInt64 = 0
    private var deliveredFrameCount: UInt64 = 0
    private var capacityDropCount: UInt64 = 0
    private var latestFrameSupersededCount: UInt64 = 0
    private var staleGenerationDropCount: UInt64 = 0
    private var generationResetDropCount: UInt64 = 0

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
    func startGeneration(_ generation: UInt64) -> MetalFrameQueueResult {
        guard activeGeneration != generation else { return .ignored }
        let discardedFrames = queuedFrames.count
        generationResetDropCount &+= UInt64(discardedFrames)
        queuedFrames.removeAll(keepingCapacity: true)
        mapper.flush()
        activeGeneration = generation
        return .generationStarted(
            generation: generation,
            discardedFrames: discardedFrames
        )
    }

    @discardableResult
    func enqueue(_ decodedFrame: DecodedVideoFrame) throws -> MetalFrameQueueResult {
        guard let activeGeneration else {
            return .rejectedInactive(frameID: decodedFrame.frameID)
        }
        guard decodedFrame.generation == activeGeneration else {
            staleGenerationDropCount &+= 1
            return .rejectedStale(
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
        queuedFrames.append(mappedFrame)
        enqueuedFrameCount &+= 1
        return .enqueued(
            generation: activeGeneration,
            frameID: decodedFrame.frameID,
            evictedFrames: evictionCount
        )
    }

    func dequeueLatest() -> MetalVideoFrame? {
        guard let latestFrame = queuedFrames.last else { return nil }
        let supersededCount = queuedFrames.count - 1
        latestFrameSupersededCount &+= UInt64(supersededCount)
        deliveredFrameCount &+= 1
        queuedFrames.removeAll(keepingCapacity: true)
        return latestFrame
    }

    @discardableResult
    func stopGeneration(_ generation: UInt64) -> MetalFrameQueueResult {
        guard generation == activeGeneration else { return .ignored }
        let discardedFrames = queuedFrames.count
        generationResetDropCount &+= UInt64(discardedFrames)
        queuedFrames.removeAll(keepingCapacity: true)
        activeGeneration = nil
        mapper.flush()
        return .generationStopped(
            generation: generation,
            discardedFrames: discardedFrames
        )
    }

    func consume(_ event: VideoDecoderEvent) throws -> MetalFrameQueueResult {
        switch event {
        case let .sessionStarted(generation, _):
            return startGeneration(generation)
        case let .frame(frame):
            return try enqueue(frame)
        case let .sessionStopped(generation):
            return stopGeneration(generation)
        case .frameDropped, .failure:
            return .ignored
        }
    }

    func snapshot() -> MetalFrameQueueSnapshot {
        MetalFrameQueueSnapshot(
            activeGeneration: activeGeneration,
            capacity: configuration.capacity,
            queuedFrameCount: queuedFrames.count,
            enqueuedFrameCount: enqueuedFrameCount,
            deliveredFrameCount: deliveredFrameCount,
            capacityDropCount: capacityDropCount,
            latestFrameSupersededCount: latestFrameSupersededCount,
            staleGenerationDropCount: staleGenerationDropCount,
            generationResetDropCount: generationResetDropCount
        )
    }
}
