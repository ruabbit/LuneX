import Foundation
import XCTest

final class MobileAudioSessionAdapterTests: XCTestCase {
    func testSurroundActivationDeclaresContentAndClampsPreferredChannels()
        throws
    {
        let client = StubMobileAudioSessionSystemClient(
            maximumOutputNumberOfChannels: 6,
            outputNumberOfChannels: 2,
            outputNames: ["Spatial Route"],
            outputPorts: [
                MobileAudioSessionPortCapabilitySnapshot(
                    spatialAudioEnabled: true
                )
            ]
        )
        let adapter = MobileAudioSessionAdapter(client: client)
        let configuration = StreamAudioConfiguration(
            sampleRate: 48_000,
            channelLayout: .wave7Point1,
            latencyPolicy: .lowLatency
        )

        let snapshot = try adapter.activate(for: configuration)

        XCTAssertEqual(
            client.calls,
            [
                "category:playback:moviePlayback",
                "multichannel:true",
                "sampleRate:48000.0",
                "bufferDuration:0.005",
                "preferredChannels:6",
                "active:true:notify:false"
            ]
        )
        XCTAssertTrue(snapshot.isActive)
        XCTAssertTrue(snapshot.supportsMultichannelContent)
        XCTAssertEqual(snapshot.requestedOutputChannelCount, 6)
        XCTAssertEqual(snapshot.preferredOutputChannelCount, 6)
        XCTAssertEqual(snapshot.maximumOutputChannelCount, 6)
        XCTAssertEqual(snapshot.currentOutputChannelCount, 2)
        XCTAssertTrue(snapshot.outputAvailable)
        XCTAssertEqual(snapshot.systemSpatialSupport, .supported)
        XCTAssertEqual(
            snapshot.routeCapability(revision: .init(rawValue: 7)),
            SpatialAudioRouteCapabilitySnapshot(
                revision: .init(rawValue: 7),
                outputAvailable: true,
                systemSpatialSupport: .supported,
                currentOutputChannelCount: 2,
                maximumOutputChannelCount: 6
            )
        )
    }

    func testPreferredChannelRequestNeverExceedsCurrentHardwareMaximum()
        throws
    {
        let cases: [(
            layout: StreamAudioChannelLayout,
            maximum: Int,
            expected: Int?
        )] = [
            (.mono, 8, 1),
            (.stereo, 1, 1),
            (.stereo, 2, 2),
            (.wave5Point1, 2, 2),
            (.wave5Point1, 6, 6),
            (.wave7Point1, 6, 6),
            (.wave7Point1, 8, 8),
            (.wave7Point1, 0, nil),
            (.wave7Point1, -1, nil)
        ]

        for testCase in cases {
            let client = StubMobileAudioSessionSystemClient(
                maximumOutputNumberOfChannels: testCase.maximum,
                outputNumberOfChannels: max(testCase.maximum, 0),
                outputNames: ["System Output"],
                outputPorts: [
                    MobileAudioSessionPortCapabilitySnapshot(
                        spatialAudioEnabled: false
                    )
                ]
            )
            let adapter = MobileAudioSessionAdapter(client: client)
            let configuration = StreamAudioConfiguration(
                sampleRate: 48_000,
                channelLayout: testCase.layout,
                latencyPolicy: .lowLatency
            )

            let snapshot = try adapter.activate(for: configuration)

            XCTAssertEqual(
                snapshot.requestedOutputChannelCount,
                testCase.expected,
                "layout=\(testCase.layout.signature.identifier) maximum=\(testCase.maximum)"
            )
            XCTAssertEqual(
                client.calls.last(where: {
                    $0.hasPrefix("preferredChannels:")
                }),
                testCase.expected.map { "preferredChannels:\($0)" },
                "layout=\(testCase.layout.signature.identifier) maximum=\(testCase.maximum)"
            )
        }
    }

    func testStereoActivationClearsMultichannelDeclaration() throws {
        let client = StubMobileAudioSessionSystemClient(
            maximumOutputNumberOfChannels: 8,
            outputNumberOfChannels: 2,
            outputNames: ["System Output"],
            outputPorts: [
                MobileAudioSessionPortCapabilitySnapshot(
                    spatialAudioEnabled: false
                )
            ],
            supportsMultichannelContent: true
        )
        let adapter = MobileAudioSessionAdapter(client: client)

        let snapshot = try adapter.activate(for: .stereoLowLatency)

        XCTAssertFalse(snapshot.supportsMultichannelContent)
        XCTAssertEqual(snapshot.requestedOutputChannelCount, 2)
        XCTAssertEqual(snapshot.systemSpatialSupport, .unsupported)
        XCTAssertTrue(client.calls.contains("multichannel:false"))
        XCTAssertTrue(client.calls.contains("preferredChannels:2"))
    }

    func testMissingRouteDoesNotRequestUnsupportedPreferredChannels()
        throws
    {
        let client = StubMobileAudioSessionSystemClient(
            maximumOutputNumberOfChannels: 0,
            outputNumberOfChannels: 0,
            outputNames: [],
            outputPorts: []
        )
        let adapter = MobileAudioSessionAdapter(client: client)

        let snapshot = try adapter.activate(for: .stereoLowLatency)

        XCTAssertNil(snapshot.requestedOutputChannelCount)
        XCTAssertFalse(snapshot.outputAvailable)
        XCTAssertEqual(snapshot.systemSpatialSupport, .unknown)
        XCTAssertFalse(
            client.calls.contains(where: {
                $0.hasPrefix("preferredChannels:")
            })
        )
        XCTAssertEqual(
            snapshot.audioRouteSnapshot(
                preferredConfiguration: .stereoLowLatency
            ),
            AudioRouteSnapshot(
                outputNames: ["System Output"],
                sampleRate: 48_000,
                outputChannelCount: 2,
                preferredBufferDuration: 0.005
            )
        )
    }

    func testOutputNameNeverGrantsSpatialSupport() throws {
        let client = StubMobileAudioSessionSystemClient(
            maximumOutputNumberOfChannels: 2,
            outputNumberOfChannels: 2,
            outputNames: ["AirPods"],
            outputPorts: [
                MobileAudioSessionPortCapabilitySnapshot(
                    spatialAudioEnabled: false
                )
            ]
        )
        let adapter = MobileAudioSessionAdapter(client: client)

        let snapshot = try adapter.activate(for: .stereoLowLatency)

        XCTAssertEqual(snapshot.outputNames, ["AirPods"])
        XCTAssertEqual(snapshot.systemSpatialSupport, .unsupported)
    }

    func testRouteCapabilityUsesPortFlagsAndNeverOutputNames() throws {
        let cases: [(
            names: [String],
            ports: [MobileAudioSessionPortCapabilitySnapshot],
            expected: SpatialAudioRouteSupport
        )] = [
            (
                ["AirPods Pro", "Spatial Audio"],
                [.init(spatialAudioEnabled: false)],
                .unsupported
            ),
            (
                ["Generic Output"],
                [
                    .init(spatialAudioEnabled: false),
                    .init(spatialAudioEnabled: true)
                ],
                .supported
            ),
            (
                ["AirPods Max"],
                [],
                .unknown
            )
        ]

        for testCase in cases {
            let client = StubMobileAudioSessionSystemClient(
                maximumOutputNumberOfChannels: 8,
                outputNumberOfChannels: 2,
                outputNames: testCase.names,
                outputPorts: testCase.ports
            )
            let adapter = MobileAudioSessionAdapter(client: client)

            let snapshot = try adapter.activate(for: .stereoLowLatency)

            XCTAssertEqual(snapshot.outputNames, testCase.names)
            XCTAssertEqual(
                snapshot.systemSpatialSupport,
                testCase.expected,
                "names=\(testCase.names)"
            )
        }
    }

    func testActivationFailureRollsBackDeclarationAndSession() {
        let client = StubMobileAudioSessionSystemClient(
            maximumOutputNumberOfChannels: 8,
            outputNumberOfChannels: 2,
            outputNames: ["System Output"],
            outputPorts: [
                MobileAudioSessionPortCapabilitySnapshot(
                    spatialAudioEnabled: true
                )
            ],
            failActiveTrue: true
        )
        let adapter = MobileAudioSessionAdapter(client: client)

        XCTAssertThrowsError(
            try adapter.activate(for: StreamAudioConfiguration(
                sampleRate: 48_000,
                channelLayout: .wave5Point1,
                latencyPolicy: .balanced
            ))
        ) { error in
            XCTAssertEqual(
                error as? StubMobileAudioSessionSystemClient.Failure,
                .activation
            )
        }

        XCTAssertEqual(
            Array(client.calls.suffix(3)),
            [
                "active:true:notify:false",
                "multichannel:false",
                "active:false:notify:false"
            ]
        )
        XCTAssertFalse(adapter.currentSnapshot().isActive)
        XCTAssertNil(
            adapter.currentSnapshot().requestedOutputChannelCount
        )
        XCTAssertFalse(
            adapter.currentSnapshot().supportsMultichannelContent
        )
    }

    func testDeactivateClearsDeclarationAndNotifiesOtherAudio() throws {
        let client = StubMobileAudioSessionSystemClient(
            maximumOutputNumberOfChannels: 8,
            outputNumberOfChannels: 8,
            outputNames: ["HDMI"],
            outputPorts: [
                MobileAudioSessionPortCapabilitySnapshot(
                    spatialAudioEnabled: false
                )
            ]
        )
        let adapter = MobileAudioSessionAdapter(client: client)
        _ = try adapter.activate(for: StreamAudioConfiguration(
            sampleRate: 48_000,
            channelLayout: .wave7Point1,
            latencyPolicy: .lowLatency
        ))

        let stopped = adapter.deactivate(
            notifyOthersOnDeactivation: true
        )

        XCTAssertEqual(
            Array(client.calls.suffix(2)),
            [
                "multichannel:false",
                "active:false:notify:true"
            ]
        )
        XCTAssertFalse(stopped.isActive)
        XCTAssertFalse(stopped.supportsMultichannelContent)
        XCTAssertNil(stopped.requestedOutputChannelCount)
    }

    func testDeactivateFailureStillClearsAdapterOwnedState() throws {
        let client = StubMobileAudioSessionSystemClient(
            maximumOutputNumberOfChannels: 8,
            outputNumberOfChannels: 8,
            outputNames: ["HDMI"],
            outputPorts: [
                MobileAudioSessionPortCapabilitySnapshot(
                    spatialAudioEnabled: false
                )
            ],
            failActiveFalse: true
        )
        let adapter = MobileAudioSessionAdapter(client: client)
        _ = try adapter.activate(for: StreamAudioConfiguration(
            sampleRate: 48_000,
            channelLayout: .wave7Point1,
            latencyPolicy: .lowLatency
        ))

        let stopped = adapter.deactivate(
            notifyOthersOnDeactivation: true
        )

        XCTAssertEqual(
            Array(client.calls.suffix(2)),
            [
                "multichannel:false",
                "active:false:notify:true"
            ]
        )
        XCTAssertFalse(stopped.isActive)
        XCTAssertFalse(stopped.supportsMultichannelContent)
        XCTAssertNil(stopped.requestedOutputChannelCount)
    }

    func testCapabilityNotificationNameComesFromInjectedSystemClient() {
        let expected = Notification.Name(
            "test.spatial-capability.changed"
        )
        let client = StubMobileAudioSessionSystemClient(
            maximumOutputNumberOfChannels: 2,
            outputNumberOfChannels: 2,
            outputNames: ["System Output"],
            outputPorts: [],
            notificationName: expected
        )
        let adapter = MobileAudioSessionAdapter(client: client)

        XCTAssertEqual(
            adapter
                .spatialPlaybackCapabilitiesChangedNotificationName,
            expected
        )
    }
}

private final class StubMobileAudioSessionSystemClient:
    MobileAudioSessionSystemClient
{
    enum Failure: Error, Equatable {
        case activation
    }

    private(set) var calls: [String] = []
    private(set) var supportsMultichannelContent: Bool
    private(set) var preferredOutputNumberOfChannels = 0
    let maximumOutputNumberOfChannels: Int
    let outputNumberOfChannels: Int
    private(set) var sampleRate = 0.0
    private(set) var ioBufferDuration = 0.0
    let outputNames: [String]
    let outputPorts: [MobileAudioSessionPortCapabilitySnapshot]
    let spatialPlaybackCapabilitiesChangedNotificationName:
        Notification.Name?
    private let failActiveTrue: Bool
    private let failActiveFalse: Bool

    init(
        maximumOutputNumberOfChannels: Int,
        outputNumberOfChannels: Int,
        outputNames: [String],
        outputPorts: [MobileAudioSessionPortCapabilitySnapshot],
        supportsMultichannelContent: Bool = false,
        failActiveTrue: Bool = false,
        failActiveFalse: Bool = false,
        notificationName: Notification.Name? = nil
    ) {
        self.maximumOutputNumberOfChannels =
            maximumOutputNumberOfChannels
        self.outputNumberOfChannels = outputNumberOfChannels
        self.outputNames = outputNames
        self.outputPorts = outputPorts
        self.supportsMultichannelContent =
            supportsMultichannelContent
        self.failActiveTrue = failActiveTrue
        self.failActiveFalse = failActiveFalse
        self.spatialPlaybackCapabilitiesChangedNotificationName =
            notificationName
    }

    func setPlaybackCategory() {
        calls.append("category:playback:moviePlayback")
    }

    func setSupportsMultichannelContent(_ enabled: Bool) {
        calls.append("multichannel:\(enabled)")
        supportsMultichannelContent = enabled
    }

    func setPreferredSampleRate(_ sampleRate: Double) {
        calls.append("sampleRate:\(sampleRate)")
        self.sampleRate = sampleRate
    }

    func setPreferredIOBufferDuration(_ duration: TimeInterval) {
        calls.append("bufferDuration:\(duration)")
        ioBufferDuration = duration
    }

    func setPreferredOutputNumberOfChannels(_ count: Int) {
        calls.append("preferredChannels:\(count)")
        preferredOutputNumberOfChannels = count
    }

    func setActive(
        _ active: Bool,
        notifyOthersOnDeactivation: Bool
    ) throws {
        calls.append(
            "active:\(active):notify:\(notifyOthersOnDeactivation)"
        )
        if active, failActiveTrue {
            throw Failure.activation
        }
        if !active, failActiveFalse {
            throw Failure.activation
        }
    }
}
