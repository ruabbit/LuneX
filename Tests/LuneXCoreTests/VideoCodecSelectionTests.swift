import CoreMedia
import Foundation
import XCTest

final class VideoCodecSelectionTests: XCTestCase {
    func testAutomaticSelectsAV1WhenHostAndDeviceSupportIt() throws {
        let policy = makePolicy([.h264, .hevc, .av1])

        let selection = try policy.select(
            hostCodecs: [.h264, .hevc, .av1],
            bitDepth: 10,
            isHDR: true
        )

        XCTAssertEqual(selection.codec, .av1)
        XCTAssertEqual(selection.disposition, .automatic)
    }

    func testAV1PreferenceFallsBackToHEVCWhenDeviceLacksAV1() throws {
        let policy = makePolicy([.h264, .hevc])

        let selection = try policy.select(
            preference: .av1,
            hostCodecs: [.h264, .hevc, .av1],
            bitDepth: 10,
            isHDR: true
        )

        XCTAssertEqual(selection.codec, .hevc)
        XCTAssertEqual(
            selection.disposition,
            .fallback(from: .av1, reason: .unsupportedByDevice(.av1))
        )
    }

    func testAV1PreferenceReportsHostFallbackToHEVC() throws {
        let policy = makePolicy([.h264, .hevc, .av1])

        let selection = try policy.select(
            preference: .av1,
            hostCodecs: [.h264, .hevc],
            bitDepth: 8,
            isHDR: false
        )

        XCTAssertEqual(selection.codec, .hevc)
        XCTAssertEqual(
            selection.disposition,
            .fallback(from: .av1, reason: .unavailableOnHost(.av1))
        )
    }

    func testSDREightBitFallsBackToH264() throws {
        let policy = makePolicy([.h264])

        let selection = try policy.select(
            preference: .av1,
            hostCodecs: [.h264, .hevc, .av1],
            bitDepth: 8,
            isHDR: false
        )

        XCTAssertEqual(selection.codec, .h264)
        XCTAssertFalse(selection.isHDR)
    }

    func testHDRAndTenBitNeverSilentlyFallBackToH264() {
        let policy = makePolicy([.h264])

        for request in [(10, true), (10, false)] {
            XCTAssertThrowsError(try policy.select(
                hostCodecs: [.h264, .hevc, .av1],
                bitDepth: request.0,
                isHDR: request.1
            )) { error in
                XCTAssertEqual(
                    error as? VideoCodecSelectionError,
                    .noCompatibleHardwareDecoder(
                        hostCodecs: [.h264, .hevc, .av1],
                        bitDepth: request.0,
                        isHDR: request.1
                    )
                )
            }
        }
    }

    func testInvalidDynamicRangeRequestsFailClosed() {
        let policy = makePolicy([.h264, .hevc, .av1])

        XCTAssertThrowsError(try policy.select(
            hostCodecs: [.h264],
            bitDepth: 12,
            isHDR: false
        )) { error in
            XCTAssertEqual(error as? VideoCodecSelectionError, .invalidBitDepth(12))
        }
        XCTAssertThrowsError(try policy.select(
            hostCodecs: [.hevc],
            bitDepth: 8,
            isHDR: true
        )) { error in
            XCTAssertEqual(error as? VideoCodecSelectionError, .hdrRequiresTenBit)
        }
    }

    func testHostOrderAndDuplicatesCannotChangeSelection() throws {
        let policy = makePolicy([.hevc, .av1])
        let first = try policy.select(
            hostCodecs: Set([.h264, .av1, .hevc, .av1]),
            bitDepth: 8,
            isHDR: false
        )
        let second = try policy.select(
            hostCodecs: Set([.hevc, .h264, .av1]),
            bitDepth: 8,
            isHDR: false
        )

        XCTAssertEqual(first, second)
        XCTAssertEqual(first.codec, .av1)
    }

    func testProductionProviderReturnsVideoToolboxResultsForEveryCodec() {
        let provider = VideoToolboxDecoderCapabilities()

        XCTAssertEqual(NegotiatedVideoCodec.h264.coreMediaCodecType, kCMVideoCodecType_H264)
        XCTAssertEqual(NegotiatedVideoCodec.hevc.coreMediaCodecType, kCMVideoCodecType_HEVC)
        XCTAssertEqual(NegotiatedVideoCodec.av1.coreMediaCodecType, kCMVideoCodecType_AV1)
        _ = provider.supportsHardwareDecode(.h264)
        _ = provider.supportsHardwareDecode(.hevc)
        _ = provider.supportsHardwareDecode(.av1)
    }

    private func makePolicy(
        _ supportedCodecs: Set<NegotiatedVideoCodec>
    ) -> VideoCodecSelectionPolicy {
        VideoCodecSelectionPolicy(
            capabilityProvider: StubVideoDecoderCapabilities(supportedCodecs)
        )
    }
}

private struct StubVideoDecoderCapabilities: VideoDecoderCapabilityProviding {
    var supportedCodecs: Set<NegotiatedVideoCodec>

    init(_ supportedCodecs: Set<NegotiatedVideoCodec>) {
        self.supportedCodecs = supportedCodecs
    }

    func supportsHardwareDecode(_ codec: NegotiatedVideoCodec) -> Bool {
        supportedCodecs.contains(codec)
    }
}
