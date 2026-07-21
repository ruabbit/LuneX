import CoreMedia
import Foundation

enum VideoParameterSetKind: String, Equatable, Sendable {
    case video
    case sequence
    case picture
}

enum VideoFormatDescriptionError: Error, Equatable, Sendable, CustomStringConvertible {
    case invalidLimits
    case emptyAccessUnit
    case accessUnitTooLarge
    case missingAnnexBStartCode
    case emptyNALUnit
    case tooManyNALUnits
    case nalUnitTooLarge
    case parameterSetTooLarge
    case malformedNALUnit
    case conflictingParameterSet(VideoParameterSetKind)
    case missingParameterSet(VideoParameterSetKind)
    case unsupportedCodec
    case coreMediaFailure(OSStatus)

    var description: String {
        switch self {
        case .invalidLimits:
            return "Video parameter-set parser limits are invalid."
        case .emptyAccessUnit:
            return "Video access unit is empty."
        case .accessUnitTooLarge:
            return "Video access unit exceeds the parser bound."
        case .missingAnnexBStartCode:
            return "Video access unit is not Annex-B framed."
        case .emptyNALUnit:
            return "Video access unit contains an empty NAL unit."
        case .tooManyNALUnits:
            return "Video access unit contains too many NAL units."
        case .nalUnitTooLarge:
            return "Video NAL unit exceeds the parser bound."
        case .parameterSetTooLarge:
            return "Video parameter set exceeds the parser bound."
        case .malformedNALUnit:
            return "Video access unit contains a malformed NAL header."
        case let .conflictingParameterSet(kind):
            return "Video access unit contains conflicting \(kind.rawValue) parameter sets."
        case let .missingParameterSet(kind):
            return "Video access unit is missing its \(kind.rawValue) parameter set."
        case .unsupportedCodec:
            return "Video parameter-set parsing is unavailable for this codec."
        case let .coreMediaFailure(status):
            return "CoreMedia rejected the video parameter sets with status \(status)."
        }
    }
}

struct AnnexBNALParserLimits: Equatable, Sendable {
    var maximumAccessUnitBytes: Int
    var maximumNALUnitBytes: Int
    var maximumNALUnitCount: Int
    var maximumParameterSetBytes: Int

    static let realtime = AnnexBNALParserLimits(
        maximumAccessUnitBytes: 32 * 1_024 * 1_024,
        maximumNALUnitBytes: 16 * 1_024 * 1_024,
        maximumNALUnitCount: 1_024,
        maximumParameterSetBytes: 1 * 1_024 * 1_024
    )

    func validate() throws {
        guard maximumAccessUnitBytes > 0,
              maximumNALUnitBytes > 0,
              maximumNALUnitBytes <= maximumAccessUnitBytes,
              maximumNALUnitCount > 0,
              maximumNALUnitCount <= 4_096,
              maximumParameterSetBytes > 0,
              maximumParameterSetBytes <= maximumNALUnitBytes else {
            throw VideoFormatDescriptionError.invalidLimits
        }
    }
}

struct VideoParameterSets: Equatable, Sendable {
    var codec: NegotiatedVideoCodec
    var videoParameterSet: Data?
    var sequenceParameterSet: Data
    var pictureParameterSet: Data

    var coreMediaOrder: [Data] {
        switch codec {
        case .h264:
            return [sequenceParameterSet, pictureParameterSet]
        case .hevc:
            guard let videoParameterSet else { return [] }
            return [videoParameterSet, sequenceParameterSet, pictureParameterSet]
        case .av1:
            return []
        }
    }
}

struct VideoParameterSetParser: Sendable {
    let limits: AnnexBNALParserLimits

    init(limits: AnnexBNALParserLimits = .realtime) throws {
        try limits.validate()
        self.limits = limits
    }

    func parse(_ accessUnit: Data, codec: NegotiatedVideoCodec) throws -> VideoParameterSets {
        guard codec != .av1 else {
            throw VideoFormatDescriptionError.unsupportedCodec
        }
        let nalUnits = try splitNALUnits(accessUnit)
        var video: Data?
        var sequence: Data?
        var picture: Data?

        for nalUnit in nalUnits {
            let kind = try parameterSetKind(for: nalUnit, codec: codec)
            guard let kind else { continue }
            guard nalUnit.count <= limits.maximumParameterSetBytes else {
                throw VideoFormatDescriptionError.parameterSetTooLarge
            }
            switch kind {
            case .video:
                try merge(nalUnit, into: &video, kind: kind)
            case .sequence:
                try merge(nalUnit, into: &sequence, kind: kind)
            case .picture:
                try merge(nalUnit, into: &picture, kind: kind)
            }
        }

        if codec == .hevc, video == nil {
            throw VideoFormatDescriptionError.missingParameterSet(.video)
        }
        guard let sequence else {
            throw VideoFormatDescriptionError.missingParameterSet(.sequence)
        }
        guard let picture else {
            throw VideoFormatDescriptionError.missingParameterSet(.picture)
        }
        return VideoParameterSets(
            codec: codec,
            videoParameterSet: video,
            sequenceParameterSet: sequence,
            pictureParameterSet: picture
        )
    }

    func splitNALUnits(_ accessUnit: Data) throws -> [Data] {
        guard !accessUnit.isEmpty else {
            throw VideoFormatDescriptionError.emptyAccessUnit
        }
        guard accessUnit.count <= limits.maximumAccessUnitBytes else {
            throw VideoFormatDescriptionError.accessUnitTooLarge
        }

        var startOffset: Int?
        var offset = 0
        while offset < accessUnit.count {
            if startCodeLength(in: accessUnit, at: offset) != nil {
                startOffset = offset
                break
            }
            guard byte(accessUnit, at: offset) == 0 else {
                throw VideoFormatDescriptionError.missingAnnexBStartCode
            }
            offset += 1
        }
        guard var currentStart = startOffset else {
            throw VideoFormatDescriptionError.missingAnnexBStartCode
        }

        var nalUnits: [Data] = []
        while currentStart < accessUnit.count {
            guard let startLength = startCodeLength(in: accessUnit, at: currentStart) else {
                throw VideoFormatDescriptionError.missingAnnexBStartCode
            }
            let payloadStart = currentStart + startLength
            var nextStart: Int?
            var searchOffset = payloadStart
            while searchOffset < accessUnit.count {
                if startCodeLength(in: accessUnit, at: searchOffset) != nil {
                    nextStart = searchOffset
                    break
                }
                searchOffset += 1
            }

            var payloadEnd = nextStart ?? accessUnit.count
            while payloadEnd > payloadStart, byte(accessUnit, at: payloadEnd - 1) == 0 {
                payloadEnd -= 1
            }
            guard payloadEnd > payloadStart else {
                throw VideoFormatDescriptionError.emptyNALUnit
            }
            let payloadLength = payloadEnd - payloadStart
            guard payloadLength <= limits.maximumNALUnitBytes else {
                throw VideoFormatDescriptionError.nalUnitTooLarge
            }
            guard nalUnits.count < limits.maximumNALUnitCount else {
                throw VideoFormatDescriptionError.tooManyNALUnits
            }
            let lower = accessUnit.index(accessUnit.startIndex, offsetBy: payloadStart)
            let upper = accessUnit.index(lower, offsetBy: payloadLength)
            nalUnits.append(Data(accessUnit[lower..<upper]))

            guard let nextStart else { break }
            currentStart = nextStart
        }
        return nalUnits
    }

    private func parameterSetKind(
        for nalUnit: Data,
        codec: NegotiatedVideoCodec
    ) throws -> VideoParameterSetKind? {
        guard let first = nalUnit.first, first & 0x80 == 0 else {
            throw VideoFormatDescriptionError.malformedNALUnit
        }
        switch codec {
        case .h264:
            switch first & 0x1F {
            case 7:
                return .sequence
            case 8:
                return .picture
            default:
                return nil
            }
        case .hevc:
            guard nalUnit.count >= 2,
                  byte(nalUnit, at: 1) & 0x07 != 0 else {
                throw VideoFormatDescriptionError.malformedNALUnit
            }
            switch (first >> 1) & 0x3F {
            case 32:
                return .video
            case 33:
                return .sequence
            case 34:
                return .picture
            default:
                return nil
            }
        case .av1:
            throw VideoFormatDescriptionError.unsupportedCodec
        }
    }

    private func merge(
        _ candidate: Data,
        into stored: inout Data?,
        kind: VideoParameterSetKind
    ) throws {
        if let stored {
            guard stored == candidate else {
                throw VideoFormatDescriptionError.conflictingParameterSet(kind)
            }
            return
        }
        stored = candidate
    }

    private func startCodeLength(in data: Data, at offset: Int) -> Int? {
        if offset + 4 <= data.count,
           byte(data, at: offset) == 0,
           byte(data, at: offset + 1) == 0,
           byte(data, at: offset + 2) == 0,
           byte(data, at: offset + 3) == 1 {
            return 4
        }
        if offset + 3 <= data.count,
           byte(data, at: offset) == 0,
           byte(data, at: offset + 1) == 0,
           byte(data, at: offset + 2) == 1 {
            return 3
        }
        return nil
    }

    private func byte(_ data: Data, at offset: Int) -> UInt8 {
        data[data.index(data.startIndex, offsetBy: offset)]
    }
}

enum VideoFormatDescriptionFactory {
    static func make(from parameterSets: VideoParameterSets) throws -> CMFormatDescription {
        let ordered = parameterSets.coreMediaOrder
        guard !ordered.isEmpty else {
            throw VideoFormatDescriptionError.unsupportedCodec
        }

        var flattened = Data()
        var offsets: [Int] = []
        var sizes: [Int] = []
        for parameterSet in ordered {
            offsets.append(flattened.count)
            sizes.append(parameterSet.count)
            flattened.append(parameterSet)
        }

        return try flattened.withUnsafeBytes { rawBuffer in
            guard let rawBaseAddress = rawBuffer.baseAddress else {
                throw VideoFormatDescriptionError.emptyAccessUnit
            }
            let baseAddress = rawBaseAddress.assumingMemoryBound(to: UInt8.self)
            let pointers: [UnsafePointer<UInt8>] = offsets.map {
                UnsafePointer(baseAddress.advanced(by: $0))
            }
            var description: CMFormatDescription?
            let status = pointers.withUnsafeBufferPointer { pointerBuffer in
                sizes.withUnsafeBufferPointer { sizeBuffer in
                    guard let pointerBase = pointerBuffer.baseAddress,
                          let sizeBase = sizeBuffer.baseAddress else {
                        return kCMFormatDescriptionError_InvalidParameter
                    }
                    switch parameterSets.codec {
                    case .h264:
                        return CMVideoFormatDescriptionCreateFromH264ParameterSets(
                            allocator: kCFAllocatorDefault,
                            parameterSetCount: ordered.count,
                            parameterSetPointers: pointerBase,
                            parameterSetSizes: sizeBase,
                            nalUnitHeaderLength: 4,
                            formatDescriptionOut: &description
                        )
                    case .hevc:
                        return CMVideoFormatDescriptionCreateFromHEVCParameterSets(
                            allocator: kCFAllocatorDefault,
                            parameterSetCount: ordered.count,
                            parameterSetPointers: pointerBase,
                            parameterSetSizes: sizeBase,
                            nalUnitHeaderLength: 4,
                            extensions: nil,
                            formatDescriptionOut: &description
                        )
                    case .av1:
                        return kCMFormatDescriptionError_InvalidParameter
                    }
                }
            }
            guard status == noErr, let description else {
                throw VideoFormatDescriptionError.coreMediaFailure(status)
            }
            return description
        }
    }
}
