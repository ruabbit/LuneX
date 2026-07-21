@preconcurrency import CoreMedia
import Foundation
import XCTest

final class VideoColorMetadataTests: XCTestCase {
    func testSunshineHDRFixtureParsesAndEncodesAppleMetadataByteExactly() throws {
        let fixture = try loadFixture().hdrMode
        let mode = try SunshineHDRModeMetadataParser.parse(MoonlightControlMessage(
            type: MoonlightControlProtocol.hdrModeType,
            payload: try Data(spacedColorHex: fixture.payloadHex)
        ))
        let metadata = try mode.colorMetadata()

        XCTAssertTrue(metadata.isHDR)
        XCTAssertEqual(metadata.bitDepth, 10)
        XCTAssertEqual(metadata.colorPrimaries, .ituR2020)
        XCTAssertEqual(metadata.transferFunction, .smpteST2084PQ)
        XCTAssertEqual(metadata.yCbCrMatrix, .ituR2020)
        XCTAssertFalse(metadata.isFullRange)
        XCTAssertEqual(metadata.maximumFullFrameLuminanceNits, 500)
        XCTAssertEqual(
            try metadata.masteringDisplay?.coreMediaData(),
            try Data(spacedColorHex: fixture.masteringDisplayColorVolumeHex)
        )
        XCTAssertEqual(
            try metadata.contentLight?.coreMediaData(),
            try Data(spacedColorHex: fixture.contentLightLevelInfoHex)
        )

        let extensions = try metadata.coreMediaExtensions()
        XCTAssertEqual(
            extensions[kCMFormatDescriptionExtension_ColorPrimaries] as? String,
            kCMFormatDescriptionColorPrimaries_ITU_R_2020 as String
        )
        XCTAssertEqual(
            extensions[kCMFormatDescriptionExtension_TransferFunction] as? String,
            kCMFormatDescriptionTransferFunction_SMPTE_ST_2084_PQ as String
        )
        XCTAssertEqual(
            extensions[kCMFormatDescriptionExtension_YCbCrMatrix] as? String,
            kCMFormatDescriptionYCbCrMatrix_ITU_R_2020 as String
        )
        XCTAssertEqual(
            extensions[kCMFormatDescriptionExtension_MasteringDisplayColorVolume] as? Data,
            try Data(spacedColorHex: fixture.masteringDisplayColorVolumeHex)
        )
        XCTAssertEqual(
            extensions[kCMFormatDescriptionExtension_ContentLightLevelInfo] as? Data,
            try Data(spacedColorHex: fixture.contentLightLevelInfoHex)
        )
    }

    func testSDRAndHDRContractsRejectStaleOrInconsistentMetadata() throws {
        XCTAssertNoThrow(try VideoColorMetadata.rec709VideoRange().validate())
        XCTAssertNoThrow(try VideoColorMetadata.rec709VideoRange(bitDepth: 10).validate())
        XCTAssertNoThrow(try VideoColorMetadata.hdr10VideoRange().validate())

        var invalidHDR = VideoColorMetadata.hdr10VideoRange()
        invalidHDR.bitDepth = 8
        XCTAssertThrowsError(try invalidHDR.validate()) { error in
            XCTAssertEqual(
                error as? VideoColorMetadataError,
                .inconsistentDynamicRange
            )
        }

        var staleSDR = VideoColorMetadata.rec709VideoRange()
        staleSDR.contentLight = VideoContentLightMetadata(
            maximumContentLightLevelNits: 1_000,
            maximumFrameAverageLightLevelNits: 400
        )
        XCTAssertThrowsError(try staleSDR.validate()) { error in
            XCTAssertEqual(
                error as? VideoColorMetadataError,
                .inconsistentDynamicRange
            )
        }
    }

    func testHDRParserClearsDisabledMetadataAndRejectsMalformedPayloads() throws {
        let disabled = try SunshineHDRModeMetadataParser.parse(MoonlightControlMessage(
            type: MoonlightControlProtocol.hdrModeType,
            payload: Data([0])
        ))
        XCTAssertFalse(disabled.isEnabled)
        XCTAssertNil(disabled.masteringDisplay)
        XCTAssertEqual(try disabled.colorMetadata(), .rec709VideoRange())

        for payload in [Data(), Data([2]), Data(repeating: 0, count: 26)] {
            XCTAssertThrowsError(try SunshineHDRModeMetadataParser.parse(
                MoonlightControlMessage(
                    type: MoonlightControlProtocol.hdrModeType,
                    payload: payload
                )
            )) { error in
                XCTAssertEqual(
                    error as? ControlChannelError,
                    .invalidHDRMetadataPayload
                )
            }
        }
    }

    func testNegotiatedVideoCodableRoundTripPreservesColorAndLightMetadata() throws {
        let metadata = try SunshineHDRModeMetadataParser.parse(MoonlightControlMessage(
            type: MoonlightControlProtocol.hdrModeType,
            payload: try Data(spacedColorHex: loadFixture().hdrMode.payloadHex)
        )).colorMetadata()
        let configuration = NegotiatedVideoStreamConfiguration(
            codec: .hevc,
            width: 3_840,
            height: 2_160,
            frameRate: 120,
            colorMetadata: metadata,
            maximumPacketSize: 1_400
        )
        try configuration.validate()

        let encoded = try JSONEncoder().encode(configuration)
        let decoded = try JSONDecoder().decode(
            NegotiatedVideoStreamConfiguration.self,
            from: encoded
        )
        XCTAssertEqual(decoded, configuration)
        XCTAssertEqual(decoded.bitDepth, 10)
        XCTAssertTrue(decoded.isHDR)
    }

    private func loadFixture() throws -> ColorControlFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/control/encrypted-vectors.json")
        return try JSONDecoder().decode(ColorControlFixture.self, from: Data(contentsOf: url))
    }
}

private struct ColorControlFixture: Decodable {
    var hdrMode: ColorHDRFixture
}

private struct ColorHDRFixture: Decodable {
    var payloadHex: String
    var masteringDisplayColorVolumeHex: String
    var contentLightLevelInfoHex: String
}

private extension Data {
    init(spacedColorHex: String) throws {
        let components = spacedColorHex.split(whereSeparator: \.isWhitespace)
        guard components.allSatisfy({ $0.count == 2 }) else {
            throw ControlChannelError.invalidHDRMetadataPayload
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(components.count)
        for component in components {
            guard let byte = UInt8(String(component), radix: 16) else {
                throw ControlChannelError.invalidHDRMetadataPayload
            }
            bytes.append(byte)
        }
        self = Data(bytes)
    }
}
