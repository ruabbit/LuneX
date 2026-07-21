import Foundation
import XCTest

final class ControlChannelTests: XCTestCase {
    func testEncryptedControlFixtureMatchesExactWireBytes() throws {
        let fixture = try loadFixture()
        XCTAssertEqual(fixture.schemaVersion, 1)
        let vector = try XCTUnwrap(fixture.vectors.first)
        let key = try Data(spacedHex: vector.keyHex)
        let message = MoonlightControlMessage(
            type: vector.type,
            payload: try Data(spacedHex: vector.payloadHex)
        )

        let frame = try EncryptedControlFrameCodec.seal(
            message,
            sequence: vector.sequence,
            key: key,
            origin: .client
        )

        XCTAssertEqual(frame, try Data(spacedHex: vector.frameHex))
        let opened = try EncryptedControlFrameCodec.open(frame, key: key, origin: .client)
        XCTAssertEqual(opened, OpenedControlFrame(sequence: vector.sequence, message: message))
    }

    func testEncryptedControlRejectsOriginKeyTypeLengthAndTagMutation() throws {
        let key = Data((0..<16).map(UInt8.init))
        let frame = try EncryptedControlFrameCodec.seal(
            MoonlightControlProtocol.requestIDR,
            sequence: 7,
            key: key,
            origin: .host
        )
        XCTAssertThrowsError(try EncryptedControlFrameCodec.open(frame, key: key, origin: .client))
        XCTAssertThrowsError(try EncryptedControlFrameCodec.open(
            frame,
            key: Data(repeating: 0xA5, count: 16),
            origin: .host
        ))

        var wrongType = frame
        wrongType[wrongType.startIndex] = 2
        XCTAssertThrowsError(try EncryptedControlFrameCodec.open(wrongType, key: key, origin: .host))

        var wrongLength = frame
        wrongLength[wrongLength.startIndex + 2] &+= 1
        XCTAssertThrowsError(try EncryptedControlFrameCodec.open(wrongLength, key: key, origin: .host))

        var wrongTag = frame
        wrongTag[wrongTag.startIndex + 8] ^= 0x80
        XCTAssertThrowsError(try EncryptedControlFrameCodec.open(wrongTag, key: key, origin: .host))
        XCTAssertThrowsError(try EncryptedControlFrameCodec.seal(
            MoonlightControlProtocol.requestIDR,
            sequence: 0,
            key: Data(repeating: 0, count: 15),
            origin: .client
        ))
    }

    func testControlChannelSendsStartsIDRServicesKeepaliveAndTerminates() async throws {
        let key = Data((0..<16).map(UInt8.init))
        let fixture = try loadFixture()
        let hdrMode = MoonlightControlMessage(
            type: MoonlightControlProtocol.hdrModeType,
            payload: try Data(spacedHex: fixture.hdrMode.payloadHex)
        )
        let hdrFrame = try EncryptedControlFrameCodec.seal(
            hdrMode,
            sequence: 18,
            key: key,
            origin: .host
        )
        let termination = MoonlightControlMessage(
            type: MoonlightControlProtocol.terminationType,
            payload: Data([0x80, 0x0E, 0x94, 0x03])
        )
        let hostFrame = try EncryptedControlFrameCodec.seal(
            termination,
            sequence: 19,
            key: key,
            origin: .host
        )
        let driver = ControlDriverStub(serviceEvents: [
            .idle,
            .received(channelID: 0, payload: hdrFrame),
            .received(channelID: 0, payload: hostFrame)
        ])
        let channel = MoonlightControlChannel(driver: driver)
        let endpoint = RuntimeNetworkEndpoint(host: "example.invalid", port: 47_999, transport: .udp)

        try await channel.connect(endpoint: endpoint, connectData: 0x1234_5678, encryptionKey: key)
        try await channel.requestIDR()
        let idleEvent = try await channel.nextEvent()
        XCTAssertEqual(idleEvent, .idle)
        let hdrEvent = try await channel.nextEvent()
        let mastering = VideoMasteringDisplayMetadata(
            displayPrimaries: [
                VideoChromaticityPoint(x: 34_000, y: 16_000),
                VideoChromaticityPoint(x: 13_250, y: 34_500),
                VideoChromaticityPoint(x: 7_500, y: 3_000)
            ],
            whitePoint: VideoChromaticityPoint(x: 15_635, y: 16_450),
            maximumDisplayLuminanceNits: 1_000,
            minimumDisplayLuminanceTenThousandths: 5
        )
        XCTAssertEqual(hdrEvent, .hdrMode(SunshineHDRModeMetadata(
            isEnabled: true,
            masteringDisplay: mastering,
            contentLight: VideoContentLightMetadata(
                maximumContentLightLevelNits: 1_200,
                maximumFrameAverageLightLevelNits: 400
            ),
            maximumFullFrameLuminanceNits: 500
        )))
        let terminationEvent = try await channel.nextEvent()
        XCTAssertEqual(
            terminationEvent,
            .terminated(HostTerminationReason(code: 0x800E_9403, kind: .frameConversion))
        )
        await channel.stop()

        let connect = await driver.recordedConnect()
        XCTAssertEqual(connect, ControlConnectCall(
            host: "example.invalid",
            port: 47_999,
            channelCount: 0x30,
            connectData: 0x1234_5678,
            timeoutMilliseconds: 10_000
        ))
        let sends = await driver.recordedSends()
        XCTAssertEqual(sends.map(\.channelID), [0, 0, 1])
        XCTAssertTrue(sends.allSatisfy(\.reliable))
        let opened = try sends.map {
            try EncryptedControlFrameCodec.open($0.payload, key: key, origin: .client)
        }
        XCTAssertEqual(opened.map(\.sequence), [0, 1, 2])
        XCTAssertEqual(opened.map(\.message), [
            MoonlightControlProtocol.startA,
            MoonlightControlProtocol.startB,
            MoonlightControlProtocol.requestIDR
        ])
        let serviceTimeouts = await driver.recordedServiceTimeouts()
        let disconnects = await driver.disconnectCount()
        XCTAssertEqual(serviceTimeouts, [100, 100, 100])
        XCTAssertEqual(disconnects, 1)
    }

    func testUnexpectedENetDisconnectFailsAndReleasesDriver() async throws {
        let driver = ControlDriverStub(serviceEvents: [.disconnected(data: 0x42)])
        let channel = MoonlightControlChannel(driver: driver)
        try await channel.connect(
            endpoint: RuntimeNetworkEndpoint(host: "example.invalid", port: 47_999, transport: .udp),
            connectData: 0,
            encryptionKey: Data(repeating: 1, count: 16)
        )

        do {
            _ = try await channel.nextEvent()
            XCTFail("Expected disconnect to fail the control channel.")
        } catch let error as ControlChannelError {
            XCTAssertEqual(error, .disconnected(data: 0x42))
        }
        let disconnects = await driver.disconnectCount()
        XCTAssertEqual(disconnects, 1)
    }

    func testUncertainSendFailureConsumesSequenceBeforeRetry() async throws {
        let key = Data(repeating: 0x5A, count: 16)
        let driver = ControlDriverStub(serviceEvents: [], failingSendCalls: [3])
        let channel = MoonlightControlChannel(driver: driver)
        try await channel.connect(
            endpoint: RuntimeNetworkEndpoint(host: "example.invalid", port: 47_999, transport: .udp),
            connectData: 0,
            encryptionKey: key
        )

        do {
            try await channel.requestIDR()
            XCTFail("The scripted third send must fail.")
        } catch let error as ENetTransportError {
            XCTAssertEqual(error, .sendFailed)
        }
        try await channel.requestIDR()

        let sends = await driver.recordedSends()
        let frames = try sends.map {
            try EncryptedControlFrameCodec.open($0.payload, key: key, origin: .client)
        }
        XCTAssertEqual(frames.map(\.sequence), [0, 1, 2, 3])
        XCTAssertEqual(frames.suffix(2).map(\.message), [
            MoonlightControlProtocol.requestIDR,
            MoonlightControlProtocol.requestIDR
        ])
    }

    func testHostTerminationReasonsAreActionableAndMalformedPayloadFails() throws {
        let cases: [(UInt32, HostTerminationKind, String)] = [
            (0x8003_0023, .graceful, "ended the streaming session"),
            (0x800E_9302, .protectedContent, "protected content"),
            (0x800E_9403, .frameConversion, "Disable HDR"),
            (0xDEAD_BEEF, .hostFailure, "0xDEADBEEF")
        ]
        for (code, expectedKind, expectedText) in cases {
            let payload = Data([
                UInt8(truncatingIfNeeded: code >> 24),
                UInt8(truncatingIfNeeded: code >> 16),
                UInt8(truncatingIfNeeded: code >> 8),
                UInt8(truncatingIfNeeded: code)
            ])
            let reason = try HostTerminationReason.parse(MoonlightControlMessage(
                type: MoonlightControlProtocol.terminationType,
                payload: payload
            ))
            XCTAssertEqual(reason.code, code)
            XCTAssertEqual(reason.kind, expectedKind)
            XCTAssertTrue(reason.description.contains(expectedText))
        }
        XCTAssertThrowsError(try HostTerminationReason.parse(MoonlightControlMessage(
            type: MoonlightControlProtocol.terminationType,
            payload: Data([0, 1])
        )))
    }

    private func loadFixture() throws -> ControlFixture {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Moonlight/control/encrypted-vectors.json")
        return try JSONDecoder().decode(ControlFixture.self, from: Data(contentsOf: url))
    }
}

private struct ControlFixture: Decodable {
    var hdrMode: ControlHDRFixture
    var schemaVersion: Int
    var vectors: [ControlFixtureVector]
}

private struct ControlHDRFixture: Decodable {
    var payloadHex: String
    var masteringDisplayColorVolumeHex: String
    var contentLightLevelInfoHex: String
}

private struct ControlFixtureVector: Decodable {
    var keyHex: String
    var sequence: UInt32
    var type: UInt16
    var payloadHex: String
    var frameHex: String
}

private struct ControlConnectCall: Equatable, Sendable {
    var host: String
    var port: UInt16
    var channelCount: UInt8
    var connectData: UInt32
    var timeoutMilliseconds: UInt32
}

private struct ControlSendCall: Equatable, Sendable {
    var payload: Data
    var channelID: UInt8
    var reliable: Bool
}

private actor ControlDriverStub: ENetConnectionDriving {
    private var connectCall: ControlConnectCall?
    private var sends: [ControlSendCall] = []
    private var serviceEvents: [ENetServiceEvent]
    private var serviceTimeouts: [UInt32] = []
    private let failingSendCalls: Set<Int>
    private var disconnects = 0

    init(
        serviceEvents: [ENetServiceEvent],
        failingSendCalls: Set<Int> = []
    ) {
        self.serviceEvents = serviceEvents
        self.failingSendCalls = failingSendCalls
    }

    func connect(
        host: String,
        port: UInt16,
        channelCount: UInt8,
        connectData: UInt32,
        timeoutMilliseconds: UInt32
    ) async throws {
        connectCall = ControlConnectCall(
            host: host,
            port: port,
            channelCount: channelCount,
            connectData: connectData,
            timeoutMilliseconds: timeoutMilliseconds
        )
    }

    func send(_ payload: Data, channelID: UInt8, reliable: Bool) async throws {
        sends.append(ControlSendCall(payload: payload, channelID: channelID, reliable: reliable))
        if failingSendCalls.contains(sends.count) {
            throw ENetTransportError.sendFailed
        }
    }

    func service(timeoutMilliseconds: UInt32) async throws -> ENetServiceEvent {
        serviceTimeouts.append(timeoutMilliseconds)
        return serviceEvents.isEmpty ? .idle : serviceEvents.removeFirst()
    }

    func disconnect() async {
        disconnects += 1
    }

    func recordedConnect() -> ControlConnectCall? {
        connectCall
    }

    func recordedSends() -> [ControlSendCall] {
        sends
    }

    func recordedServiceTimeouts() -> [UInt32] {
        serviceTimeouts
    }

    func disconnectCount() -> Int {
        disconnects
    }
}

private extension Data {
    init(spacedHex: String) throws {
        let components = spacedHex.split(whereSeparator: \.isWhitespace)
        guard components.allSatisfy({ $0.count == 2 }) else {
            throw ControlChannelError.invalidFrame
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(components.count)
        for component in components {
            guard let byte = UInt8(String(component), radix: 16) else {
                throw ControlChannelError.invalidFrame
            }
            bytes.append(byte)
        }
        self = Data(bytes)
    }
}
