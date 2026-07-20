import CoreMedia
import Foundation
import XCTest

final class VideoFormatDescriptionTests: XCTestCase {
    func testH264FixtureParsesAndCreatesCoreMediaFormat() throws {
        let fixture = try loadFixture().h264
        let parser = try VideoParameterSetParser()
        var shifted = Data([0xFF]) + (try Data(spacedFormatHex: fixture.accessUnitHex))
        shifted.removeFirst()

        let parameterSets = try parser.parse(shifted, codec: .h264)
        XCTAssertNil(parameterSets.videoParameterSet)
        XCTAssertEqual(
            parameterSets.sequenceParameterSet,
            try Data(spacedFormatHex: fixture.sequenceParameterSetHex)
        )
        XCTAssertEqual(
            parameterSets.pictureParameterSet,
            try Data(spacedFormatHex: fixture.pictureParameterSetHex)
        )

        let description = try VideoFormatDescriptionFactory.make(from: parameterSets)
        XCTAssertEqual(CMFormatDescriptionGetMediaSubType(description), kCMVideoCodecType_H264)
        let dimensions = CMVideoFormatDescriptionGetDimensions(description)
        XCTAssertEqual(dimensions.width, fixture.expectedWidth)
        XCTAssertEqual(dimensions.height, fixture.expectedHeight)
        try assertH264ParameterSets(description, equal: parameterSets.coreMediaOrder)
    }

    func testHEVCFixtureParsesAndCreatesCoreMediaFormat() throws {
        let fixture = try loadFixture().hevc
        let parser = try VideoParameterSetParser()
        let parameterSets = try parser.parse(
            Data(spacedFormatHex: fixture.accessUnitHex),
            codec: .hevc
        )
        XCTAssertEqual(
            parameterSets.videoParameterSet,
            try Data(spacedFormatHex: XCTUnwrap(fixture.videoParameterSetHex))
        )
        XCTAssertEqual(
            parameterSets.sequenceParameterSet,
            try Data(spacedFormatHex: fixture.sequenceParameterSetHex)
        )
        XCTAssertEqual(
            parameterSets.pictureParameterSet,
            try Data(spacedFormatHex: fixture.pictureParameterSetHex)
        )

        let description = try VideoFormatDescriptionFactory.make(from: parameterSets)
        XCTAssertEqual(CMFormatDescriptionGetMediaSubType(description), kCMVideoCodecType_HEVC)
        let dimensions = CMVideoFormatDescriptionGetDimensions(description)
        XCTAssertEqual(dimensions.width, fixture.expectedWidth)
        XCTAssertEqual(dimensions.height, fixture.expectedHeight)
        try assertHEVCParameterSets(description, equal: parameterSets.coreMediaOrder)
    }

    func testExactDuplicatesAreIdempotentAndConflictsFailClosed() throws {
        let parser = try VideoParameterSetParser()
        let fixture = try loadFixture().h264
        let sps = try Data(spacedFormatHex: fixture.sequenceParameterSetHex)
        let pps = try Data(spacedFormatHex: fixture.pictureParameterSetHex)
        let duplicated = annexB(sps) + annexB(sps, startCodeLength: 3) + annexB(pps)
        XCTAssertNoThrow(try parser.parse(duplicated, codec: .h264))

        var changedSPS = sps
        changedSPS[changedSPS.startIndex + 3] ^= 0x01
        XCTAssertThrowsError(try parser.parse(
            duplicated + annexB(changedSPS),
            codec: .h264
        )) { error in
            XCTAssertEqual(
                error as? VideoFormatDescriptionError,
                .conflictingParameterSet(.sequence)
            )
        }
    }

    func testMissingSetsUnsupportedCodecAndMalformedHeadersFailClosed() throws {
        let parser = try VideoParameterSetParser()
        let fixture = try loadFixture()
        let h264SPS = try Data(spacedFormatHex: fixture.h264.sequenceParameterSetHex)
        XCTAssertThrowsError(try parser.parse(Data(), codec: .h264)) { error in
            XCTAssertEqual(error as? VideoFormatDescriptionError, .emptyAccessUnit)
        }
        XCTAssertThrowsError(try parser.parse(annexB(h264SPS), codec: .h264)) { error in
            XCTAssertEqual(error as? VideoFormatDescriptionError, .missingParameterSet(.picture))
        }
        XCTAssertThrowsError(try parser.parse(annexB(h264SPS), codec: .av1)) { error in
            XCTAssertEqual(error as? VideoFormatDescriptionError, .unsupportedCodec)
        }
        XCTAssertThrowsError(try parser.parse(Data([0x67, 0x01]), codec: .h264)) { error in
            XCTAssertEqual(error as? VideoFormatDescriptionError, .missingAnnexBStartCode)
        }
        XCTAssertThrowsError(try parser.parse(Data([0, 0, 1]), codec: .h264)) { error in
            XCTAssertEqual(error as? VideoFormatDescriptionError, .emptyNALUnit)
        }
        XCTAssertThrowsError(try parser.parse(annexB(Data([0xE7, 0x01])), codec: .h264)) { error in
            XCTAssertEqual(error as? VideoFormatDescriptionError, .malformedNALUnit)
        }
        XCTAssertThrowsError(try parser.parse(annexB(Data([0x40, 0x00])), codec: .hevc)) { error in
            XCTAssertEqual(error as? VideoFormatDescriptionError, .malformedNALUnit)
        }

        let invalidParameterSets = VideoParameterSets(
            codec: .h264,
            videoParameterSet: nil,
            sequenceParameterSet: Data([0x67, 0x00]),
            pictureParameterSet: Data([0x68, 0x00])
        )
        XCTAssertThrowsError(try VideoFormatDescriptionFactory.make(from: invalidParameterSets)) { error in
            guard case .coreMediaFailure = error as? VideoFormatDescriptionError else {
                return XCTFail("Expected CoreMedia failure, received \(error)")
            }
        }
    }

    func testParserLimitsBoundAccessUnitsNALUnitsAndParameterSets() throws {
        XCTAssertThrowsError(try VideoParameterSetParser(limits: AnnexBNALParserLimits(
            maximumAccessUnitBytes: 0,
            maximumNALUnitBytes: 0,
            maximumNALUnitCount: 0,
            maximumParameterSetBytes: 0
        ))) { error in
            XCTAssertEqual(error as? VideoFormatDescriptionError, .invalidLimits)
        }

        let fixture = try loadFixture().h264
        let accessUnit = try Data(spacedFormatHex: fixture.accessUnitHex)
        let accessBound = try VideoParameterSetParser(limits: AnnexBNALParserLimits(
            maximumAccessUnitBytes: accessUnit.count - 1,
            maximumNALUnitBytes: accessUnit.count - 1,
            maximumNALUnitCount: 8,
            maximumParameterSetBytes: accessUnit.count - 1
        ))
        XCTAssertThrowsError(try accessBound.parse(accessUnit, codec: .h264)) { error in
            XCTAssertEqual(error as? VideoFormatDescriptionError, .accessUnitTooLarge)
        }

        let countBound = try VideoParameterSetParser(limits: AnnexBNALParserLimits(
            maximumAccessUnitBytes: accessUnit.count,
            maximumNALUnitBytes: accessUnit.count,
            maximumNALUnitCount: 1,
            maximumParameterSetBytes: accessUnit.count
        ))
        XCTAssertThrowsError(try countBound.parse(accessUnit, codec: .h264)) { error in
            XCTAssertEqual(error as? VideoFormatDescriptionError, .tooManyNALUnits)
        }

        let nalBound = try VideoParameterSetParser(limits: AnnexBNALParserLimits(
            maximumAccessUnitBytes: accessUnit.count,
            maximumNALUnitBytes: 8,
            maximumNALUnitCount: 8,
            maximumParameterSetBytes: 8
        ))
        XCTAssertThrowsError(try nalBound.parse(accessUnit, codec: .h264)) { error in
            XCTAssertEqual(error as? VideoFormatDescriptionError, .nalUnitTooLarge)
        }

        let parameterBound = try VideoParameterSetParser(limits: AnnexBNALParserLimits(
            maximumAccessUnitBytes: accessUnit.count,
            maximumNALUnitBytes: accessUnit.count,
            maximumNALUnitCount: 8,
            maximumParameterSetBytes: 4
        ))
        XCTAssertThrowsError(try parameterBound.parse(accessUnit, codec: .h264)) { error in
            XCTAssertEqual(error as? VideoFormatDescriptionError, .parameterSetTooLarge)
        }
    }

    private func assertH264ParameterSets(
        _ description: CMFormatDescription,
        equal expected: [Data]
    ) throws {
        for index in expected.indices {
            var pointer: UnsafePointer<UInt8>?
            var size = 0
            var count = 0
            var headerLength: Int32 = 0
            let status = CMVideoFormatDescriptionGetH264ParameterSetAtIndex(
                description,
                parameterSetIndex: index,
                parameterSetPointerOut: &pointer,
                parameterSetSizeOut: &size,
                parameterSetCountOut: &count,
                nalUnitHeaderLengthOut: &headerLength
            )
            XCTAssertEqual(status, noErr)
            XCTAssertEqual(count, expected.count)
            XCTAssertEqual(headerLength, 4)
            let bytes = try XCTUnwrap(pointer)
            XCTAssertEqual(Data(bytes: bytes, count: size), expected[index])
        }
    }

    private func assertHEVCParameterSets(
        _ description: CMFormatDescription,
        equal expected: [Data]
    ) throws {
        for index in expected.indices {
            var pointer: UnsafePointer<UInt8>?
            var size = 0
            var count = 0
            var headerLength: Int32 = 0
            let status = CMVideoFormatDescriptionGetHEVCParameterSetAtIndex(
                description,
                parameterSetIndex: index,
                parameterSetPointerOut: &pointer,
                parameterSetSizeOut: &size,
                parameterSetCountOut: &count,
                nalUnitHeaderLengthOut: &headerLength
            )
            XCTAssertEqual(status, noErr)
            XCTAssertEqual(count, expected.count)
            XCTAssertEqual(headerLength, 4)
            let bytes = try XCTUnwrap(pointer)
            XCTAssertEqual(Data(bytes: bytes, count: size), expected[index])
        }
    }

    private func loadFixture() throws -> VideoFormatFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/video/parameter-sets.json")
        return try JSONDecoder().decode(VideoFormatFixture.self, from: Data(contentsOf: url))
    }
}

private struct VideoFormatFixture: Decodable {
    struct Codec: Decodable {
        var accessUnitHex: String
        var expectedHeight: Int32
        var expectedWidth: Int32
        var pictureParameterSetHex: String
        var sequenceParameterSetHex: String
        var videoParameterSetHex: String?
    }

    var h264: Codec
    var hevc: Codec
    var schemaVersion: Int
}

private func annexB(_ nalUnit: Data, startCodeLength: Int = 4) -> Data {
    let startCode = startCodeLength == 3 ? Data([0, 0, 1]) : Data([0, 0, 0, 1])
    return startCode + nalUnit
}

private extension Data {
    init(spacedFormatHex: String) throws {
        let fields = spacedFormatHex.split(whereSeparator: \Character.isWhitespace)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(fields.count)
        for field in fields {
            guard field.count == 2, let byte = UInt8(field, radix: 16) else {
                throw VideoFormatFixtureError.invalidHex
            }
            bytes.append(byte)
        }
        self.init(bytes)
    }
}

private enum VideoFormatFixtureError: Error {
    case invalidHex
}
