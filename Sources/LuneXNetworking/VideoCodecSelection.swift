import CoreMedia
import Foundation
import VideoToolbox

enum VideoCodecPreference: String, Codable, Equatable, Sendable {
    case automatic
    case h264
    case hevc
    case av1
}

enum VideoCodecFallbackReason: Equatable, Sendable {
    case unavailableOnHost(NegotiatedVideoCodec)
    case unsupportedByDevice(NegotiatedVideoCodec)
    case incompatibleWithRequestedDynamicRange(NegotiatedVideoCodec)
}

enum VideoCodecSelectionDisposition: Equatable, Sendable {
    case automatic
    case preferred
    case fallback(from: NegotiatedVideoCodec, reason: VideoCodecFallbackReason)
}

struct VideoCodecSelection: Equatable, Sendable {
    var codec: NegotiatedVideoCodec
    var bitDepth: Int
    var isHDR: Bool
    var disposition: VideoCodecSelectionDisposition
}

enum VideoCodecSelectionError: Error, Equatable, Sendable {
    case invalidBitDepth(Int)
    case hdrRequiresTenBit
    case noCompatibleHardwareDecoder(
        hostCodecs: Set<NegotiatedVideoCodec>,
        bitDepth: Int,
        isHDR: Bool
    )
}

protocol VideoDecoderCapabilityProviding: Sendable {
    func supportsHardwareDecode(_ codec: NegotiatedVideoCodec) -> Bool
}

struct VideoToolboxDecoderCapabilities: VideoDecoderCapabilityProviding {
    func supportsHardwareDecode(_ codec: NegotiatedVideoCodec) -> Bool {
        VTIsHardwareDecodeSupported(codec.coreMediaCodecType)
    }
}

struct VideoCodecSelectionPolicy: Sendable {
    private let capabilityProvider: any VideoDecoderCapabilityProviding

    init(
        capabilityProvider: any VideoDecoderCapabilityProviding = VideoToolboxDecoderCapabilities()
    ) {
        self.capabilityProvider = capabilityProvider
    }

    func select(
        preference: VideoCodecPreference = .automatic,
        hostCodecs: Set<NegotiatedVideoCodec>,
        bitDepth: Int,
        isHDR: Bool
    ) throws -> VideoCodecSelection {
        guard bitDepth == 8 || bitDepth == 10 else {
            throw VideoCodecSelectionError.invalidBitDepth(bitDepth)
        }
        guard !isHDR || bitDepth == 10 else {
            throw VideoCodecSelectionError.hdrRequiresTenBit
        }

        let priority = priority(for: preference)
        let requiresTenBitCodec = isHDR || bitDepth == 10
        guard let selected = priority.first(where: { codec in
            hostCodecs.contains(codec)
                && (!requiresTenBitCodec || codec != .h264)
                && capabilityProvider.supportsHardwareDecode(codec)
        }) else {
            throw VideoCodecSelectionError.noCompatibleHardwareDecoder(
                hostCodecs: hostCodecs,
                bitDepth: bitDepth,
                isHDR: isHDR
            )
        }

        let disposition: VideoCodecSelectionDisposition
        if preference == .automatic {
            if selected == priority[0] {
                disposition = .automatic
            } else {
                disposition = .fallback(
                    from: priority[0],
                    reason: fallbackReason(
                        for: priority[0],
                        hostCodecs: hostCodecs,
                        requiresTenBitCodec: requiresTenBitCodec
                    )
                )
            }
        } else {
            let requested = priority[0]
            if selected == requested {
                disposition = .preferred
            } else {
                disposition = .fallback(
                    from: requested,
                    reason: fallbackReason(
                        for: requested,
                        hostCodecs: hostCodecs,
                        requiresTenBitCodec: requiresTenBitCodec
                    )
                )
            }
        }

        return VideoCodecSelection(
            codec: selected,
            bitDepth: bitDepth,
            isHDR: isHDR,
            disposition: disposition
        )
    }

    private func priority(
        for preference: VideoCodecPreference
    ) -> [NegotiatedVideoCodec] {
        switch preference {
        case .automatic, .av1:
            return [.av1, .hevc, .h264]
        case .hevc:
            return [.hevc, .h264]
        case .h264:
            return [.h264]
        }
    }

    private func fallbackReason(
        for codec: NegotiatedVideoCodec,
        hostCodecs: Set<NegotiatedVideoCodec>,
        requiresTenBitCodec: Bool
    ) -> VideoCodecFallbackReason {
        if !hostCodecs.contains(codec) {
            return .unavailableOnHost(codec)
        }
        if requiresTenBitCodec, codec == .h264 {
            return .incompatibleWithRequestedDynamicRange(codec)
        }
        return .unsupportedByDevice(codec)
    }
}

extension NegotiatedVideoCodec {
    var coreMediaCodecType: CMVideoCodecType {
        switch self {
        case .h264:
            return kCMVideoCodecType_H264
        case .hevc:
            return kCMVideoCodecType_HEVC
        case .av1:
            return kCMVideoCodecType_AV1
        }
    }
}
