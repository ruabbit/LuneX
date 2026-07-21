import Foundation
@preconcurrency import Metal

enum HDRMetalPipelineError: Error, Equatable, Hashable, Sendable,
    CustomStringConvertible {
    case invalidCacheCapacity
    case incompatiblePipelineKey
    case staleColorSignature
    case staleLuminanceMapping
    case missingLuminanceMapping
    case unexpectedLuminanceMapping
    case invalidSDRFallbackHeadroom
    case invalidUniformLayout
    case shaderLibraryUnavailable
    case missingShaderFunction(HDRMetalShaderFunction)
    case pipelineCreationFailed

    var description: String {
        switch self {
        case .invalidCacheCapacity:
            return "The Metal pipeline cache capacity is outside its supported bound."
        case .incompatiblePipelineKey:
            return "The input layout, mapping mode, and output format are incompatible."
        case .staleColorSignature:
            return "The shader uniform color signature is stale."
        case .staleLuminanceMapping:
            return "The shader luminance mapping is stale for the color signature."
        case .missingLuminanceMapping:
            return "HDR shader uniforms require a validated luminance mapping."
        case .unexpectedLuminanceMapping:
            return "SDR shader uniforms cannot consume an HDR luminance mapping."
        case .invalidSDRFallbackHeadroom:
            return "HDR-to-SDR shader uniforms require a headroom bound of exactly one."
        case .invalidUniformLayout:
            return "The Swift shader uniform layout does not match the Metal ABI."
        case .shaderLibraryUnavailable:
            return "The repository Metal shader library is unavailable."
        case let .missingShaderFunction(function):
            return "The repository Metal library is missing its \(function.rawValue) function."
        case .pipelineCreationFailed:
            return "Metal could not create the requested video render pipeline."
        }
    }
}

enum HDRMetalShaderFunction: String, Hashable, Sendable {
    case vertex = "lunex_hdr_video_vertex"
    case fragment = "lunex_hdr_video_fragment"
}

struct HDRMetalPipelineKey: Hashable, Sendable {
    let inputLayout: HDRDecodedPixelLayout
    let mappingMode: HDRMappingMode
    let outputPixelFormat: HDRDrawablePixelFormat

    init(
        inputLayout: HDRDecodedPixelLayout,
        mappingMode: HDRMappingMode,
        outputPixelFormat: HDRDrawablePixelFormat
    ) throws {
        let isSDR = inputLayout == .nv12VideoRange8
            && mappingMode == .sdr
            && outputPixelFormat == .bgra8UnormSRGB
        let isEDR = inputLayout == .p010VideoRange10
            && mappingMode == .hdrEDR
            && outputPixelFormat == .rgba16Float
        let isHDRToSDR = inputLayout == .p010VideoRange10
            && mappingMode == .hdrToSDR
            && outputPixelFormat == .bgra8UnormSRGB
        guard isSDR || isEDR || isHDRToSDR else {
            throw HDRMetalPipelineError.incompatiblePipelineKey
        }
        self.inputLayout = inputLayout
        self.mappingMode = mappingMode
        self.outputPixelFormat = outputPixelFormat
    }

    init(
        frameContract: HDRValidatedDecodedFrameContract,
        configuration: HDRRenderConfigurationIdentity
    ) throws {
        guard frameContract.colorSignature == configuration.colorSignature else {
            throw HDRMetalPipelineError.staleColorSignature
        }
        try self.init(
            inputLayout: frameContract.pixelLayout,
            mappingMode: configuration.mappingMode,
            outputPixelFormat: configuration.surfaceContract.drawablePixelFormat
        )
    }

    var metalPixelFormat: MTLPixelFormat {
        switch outputPixelFormat {
        case .bgra8UnormSRGB: .bgra8Unorm_srgb
        case .rgba16Float: .rgba16Float
        }
    }
}

struct HDRMetalShaderUniforms: Equatable, Sendable {
    static let expectedByteCount = 32

    let inputBitDepth: UInt32
    let yCbCrMatrix: UInt32
    let transferFunction: UInt32
    let outputGamut: UInt32
    let mappingMode: UInt32
    let sourcePeakNits: Float
    let currentHeadroom: Float
    let reserved: Float

    init(
        frameContract: HDRValidatedDecodedFrameContract,
        configuration: HDRRenderConfigurationIdentity,
        luminanceMapping: HDRLuminanceMapping?
    ) throws {
        _ = try HDRMetalPipelineKey(
            frameContract: frameContract,
            configuration: configuration
        )
        guard Self.hasExpectedMemoryLayout else {
            throw HDRMetalPipelineError.invalidUniformLayout
        }

        inputBitDepth = UInt32(frameContract.pixelLayout.bitDepth)
        yCbCrMatrix = configuration.colorSignature.matrix == .ituR2020 ? 1 : 0
        transferFunction = configuration.colorSignature.transferFunction == .smpteST2084PQ
            ? 1 : 0
        switch configuration.surfaceContract.outputGamut {
        case .sRGB: outputGamut = 0
        case .displayP3: outputGamut = 1
        case .ituR2020: outputGamut = 2
        }
        switch configuration.mappingMode {
        case .sdr:
            guard luminanceMapping == nil else {
                throw HDRMetalPipelineError.unexpectedLuminanceMapping
            }
            mappingMode = 0
            sourcePeakNits = Float(HDRLuminanceMapping.referenceWhiteNits)
            currentHeadroom = 1
        case .hdrEDR, .hdrToSDR:
            guard let luminanceMapping else {
                throw HDRMetalPipelineError.missingLuminanceMapping
            }
            let expectedSourcePeak: HDRSourcePeak
            do {
                expectedSourcePeak = try HDRSourcePeakResolver.resolve(
                    configuration.colorSignature
                )
            } catch {
                throw HDRMetalPipelineError.staleLuminanceMapping
            }
            guard luminanceMapping.sourcePeak == expectedSourcePeak else {
                throw HDRMetalPipelineError.staleLuminanceMapping
            }
            if configuration.mappingMode == .hdrToSDR,
               luminanceMapping.currentHeadroom != 1 {
                throw HDRMetalPipelineError.invalidSDRFallbackHeadroom
            }
            mappingMode = configuration.mappingMode == .hdrEDR ? 1 : 2
            sourcePeakNits = Float(luminanceMapping.sourcePeak.luminanceNits)
            currentHeadroom = configuration.mappingMode == .hdrEDR
                ? Float(luminanceMapping.currentHeadroom) : 1
        }
        reserved = 0
    }

    static var hasExpectedMemoryLayout: Bool {
        MemoryLayout<Self>.size == expectedByteCount
            && MemoryLayout<Self>.stride == expectedByteCount
            && MemoryLayout<Self>.alignment == MemoryLayout<UInt32>.alignment
            && MemoryLayout<Self>.offset(of: \.inputBitDepth) == 0
            && MemoryLayout<Self>.offset(of: \.yCbCrMatrix) == 4
            && MemoryLayout<Self>.offset(of: \.transferFunction) == 8
            && MemoryLayout<Self>.offset(of: \.outputGamut) == 12
            && MemoryLayout<Self>.offset(of: \.mappingMode) == 16
            && MemoryLayout<Self>.offset(of: \.sourcePeakNits) == 20
            && MemoryLayout<Self>.offset(of: \.currentHeadroom) == 24
            && MemoryLayout<Self>.offset(of: \.reserved) == 28
    }
}

final class HDRMetalPipelineState: @unchecked Sendable {
    let key: HDRMetalPipelineKey
    let rawValue: any MTLRenderPipelineState

    init(key: HDRMetalPipelineKey, rawValue: any MTLRenderPipelineState) {
        self.key = key
        self.rawValue = rawValue
    }
}

protocol HDRMetalPipelineStateCreating: Sendable {
    func makePipelineState(for key: HDRMetalPipelineKey) throws -> HDRMetalPipelineState
}

final class AppleHDRMetalPipelineStateFactory: HDRMetalPipelineStateCreating,
    @unchecked Sendable {
    private let device: any MTLDevice
    private let library: any MTLLibrary

    init(device: any MTLDevice, library: any MTLLibrary) {
        self.device = device
        self.library = library
    }

    convenience init(device: any MTLDevice, bundle: Bundle) throws {
        let library: any MTLLibrary
        do {
            library = try device.makeDefaultLibrary(bundle: bundle)
        } catch {
            throw HDRMetalPipelineError.shaderLibraryUnavailable
        }
        self.init(device: device, library: library)
    }

    func makePipelineState(for key: HDRMetalPipelineKey) throws -> HDRMetalPipelineState {
        guard HDRMetalShaderUniforms.hasExpectedMemoryLayout else {
            throw HDRMetalPipelineError.invalidUniformLayout
        }
        guard let vertex = library.makeFunction(name: HDRMetalShaderFunction.vertex.rawValue) else {
            throw HDRMetalPipelineError.missingShaderFunction(.vertex)
        }
        guard let fragment = library.makeFunction(
            name: HDRMetalShaderFunction.fragment.rawValue
        ) else {
            throw HDRMetalPipelineError.missingShaderFunction(.fragment)
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "LuneX video \(key.inputLayout.rawValue) \(key.mappingMode.rawValue)"
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = key.metalPixelFormat
        descriptor.colorAttachments[0].isBlendingEnabled = false
        descriptor.colorAttachments[0].writeMask = .all
        do {
            let state = try device.makeRenderPipelineState(descriptor: descriptor)
            return HDRMetalPipelineState(key: key, rawValue: state)
        } catch {
            throw HDRMetalPipelineError.pipelineCreationFailed
        }
    }
}

struct HDRMetalPipelineCacheSnapshot: Equatable, Sendable {
    let capacity: Int
    let keysByLeastRecentUse: [HDRMetalPipelineKey]
    let hitCount: UInt64
    let missCount: UInt64
    let creationFailureCount: UInt64
    let evictionCount: UInt64
    let flushCount: UInt64
}

final class HDRMetalPipelineStateCache: @unchecked Sendable {
    static let maximumCapacity = 16

    private let capacity: Int
    private let factory: any HDRMetalPipelineStateCreating
    private let lock = NSLock()
    private var entries: [HDRMetalPipelineKey: HDRMetalPipelineState] = [:]
    private var keysByLeastRecentUse: [HDRMetalPipelineKey] = []
    private var hitCount: UInt64 = 0
    private var missCount: UInt64 = 0
    private var creationFailureCount: UInt64 = 0
    private var evictionCount: UInt64 = 0
    private var flushCount: UInt64 = 0

    init(
        capacity: Int = 6,
        factory: any HDRMetalPipelineStateCreating
    ) throws {
        guard (1...Self.maximumCapacity).contains(capacity) else {
            throw HDRMetalPipelineError.invalidCacheCapacity
        }
        self.capacity = capacity
        self.factory = factory
    }

    func pipelineState(for key: HDRMetalPipelineKey) throws -> HDRMetalPipelineState {
        try lock.withLock {
            if let cached = entries[key] {
                hitCount &+= 1
                touch(key)
                return cached
            }
            missCount &+= 1
            let created: HDRMetalPipelineState
            do {
                created = try factory.makePipelineState(for: key)
            } catch {
                creationFailureCount &+= 1
                throw error
            }
            guard created.key == key else {
                creationFailureCount &+= 1
                throw HDRMetalPipelineError.incompatiblePipelineKey
            }
            entries[key] = created
            keysByLeastRecentUse.append(key)
            if entries.count > capacity, let evicted = keysByLeastRecentUse.first {
                keysByLeastRecentUse.removeFirst()
                entries.removeValue(forKey: evicted)
                evictionCount &+= 1
            }
            return created
        }
    }

    func removeAll() {
        lock.withLock {
            guard !entries.isEmpty else { return }
            entries.removeAll(keepingCapacity: true)
            keysByLeastRecentUse.removeAll(keepingCapacity: true)
            flushCount &+= 1
        }
    }

    func snapshot() -> HDRMetalPipelineCacheSnapshot {
        lock.withLock {
            HDRMetalPipelineCacheSnapshot(
                capacity: capacity,
                keysByLeastRecentUse: keysByLeastRecentUse,
                hitCount: hitCount,
                missCount: missCount,
                creationFailureCount: creationFailureCount,
                evictionCount: evictionCount,
                flushCount: flushCount
            )
        }
    }

    private func touch(_ key: HDRMetalPipelineKey) {
        keysByLeastRecentUse.removeAll { $0 == key }
        keysByLeastRecentUse.append(key)
    }
}
