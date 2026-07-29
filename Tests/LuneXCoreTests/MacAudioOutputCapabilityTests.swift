import AVFAudio
import XCTest

final class MacAudioOutputCapabilityTests: XCTestCase {
    func testEnvironmentGraphAndActualOutputResolveSupportedCapability() {
        let revision = SpatialAudioSemanticRevision(rawValue: 11)
        let capability = MacAudioOutputCapabilityResolver.resolve(
            revision: revision,
            output: MacAudioOutputFormatSnapshot(
                sampleRate: 48_000,
                channelCount: 2
            ),
            graph: makeGraphReadback(
                mode: .environmentAmbienceBed,
                environmentConnectedToMainMixer: true,
                applicableRenderingAlgorithmRawValues: [
                    AVAudio3DMixingRenderingAlgorithm.auto.rawValue
                ]
            )
        )

        XCTAssertEqual(
            capability,
            SpatialAudioRouteCapabilitySnapshot(
                revision: revision,
                outputAvailable: true,
                systemSpatialSupport: .supported,
                currentOutputChannelCount: 2,
                maximumOutputChannelCount: 2
            )
        )
    }

    func testEnvironmentGraphRequiresConnectionAndApplicableAlgorithm() {
        let cases = [
            makeGraphReadback(
                mode: .environmentAmbienceBed,
                environmentConnectedToMainMixer: false,
                applicableRenderingAlgorithmRawValues: [
                    AVAudio3DMixingRenderingAlgorithm.auto.rawValue
                ]
            ),
            makeGraphReadback(
                mode: .environmentAmbienceBed,
                environmentConnectedToMainMixer: true,
                applicableRenderingAlgorithmRawValues: []
            )
        ]

        for graph in cases {
            let capability = MacAudioOutputCapabilityResolver.resolve(
                revision: .init(rawValue: 12),
                output: MacAudioOutputFormatSnapshot(
                    sampleRate: 48_000,
                    channelCount: 2
                ),
                graph: graph
            )

            XCTAssertEqual(capability.systemSpatialSupport, .unknown)
        }
    }

    func testTypedGraphFailuresResolveUnsupportedCapability() {
        for fallback in SpatialAudioGraphFallbackReason.allCases {
            let capability = MacAudioOutputCapabilityResolver.resolve(
                revision: .init(rawValue: 13),
                output: MacAudioOutputFormatSnapshot(
                    sampleRate: 96_000,
                    channelCount: 8
                ),
                graph: makeGraphReadback(
                    mode: .nonspatialMixer,
                    fallbackReason: fallback
                )
            )

            XCTAssertTrue(capability.outputAvailable)
            XCTAssertEqual(
                capability.systemSpatialSupport,
                .unsupported
            )
            XCTAssertEqual(capability.currentOutputChannelCount, 8)
            XCTAssertEqual(capability.maximumOutputChannelCount, 8)
        }
    }

    func testDirectOrUnconfiguredGraphRemainsUnknown() {
        for mode in [
            SpatialAudioGraphMode.unconfigured,
            .nonspatialMixer
        ] {
            let capability = MacAudioOutputCapabilityResolver.resolve(
                revision: .init(rawValue: 14),
                output: MacAudioOutputFormatSnapshot(
                    sampleRate: 48_000,
                    channelCount: 2
                ),
                graph: makeGraphReadback(mode: mode)
            )

            XCTAssertTrue(capability.outputAvailable)
            XCTAssertEqual(capability.systemSpatialSupport, .unknown)
        }
    }

    func testInvalidActualOutputFormatFailsClosed() {
        let invalidOutputs = [
            MacAudioOutputFormatSnapshot(
                sampleRate: .nan,
                channelCount: 2
            ),
            MacAudioOutputFormatSnapshot(
                sampleRate: .infinity,
                channelCount: 2
            ),
            MacAudioOutputFormatSnapshot(
                sampleRate: 0,
                channelCount: 2
            ),
            MacAudioOutputFormatSnapshot(
                sampleRate: 48_000,
                channelCount: 0
            ),
            MacAudioOutputFormatSnapshot(
                sampleRate: 48_000,
                channelCount:
                    MacAudioOutputCapabilityResolver
                        .maximumObservedChannelCount + 1
            )
        ]

        for output in invalidOutputs {
            let capability = MacAudioOutputCapabilityResolver.resolve(
                revision: .init(rawValue: 15),
                output: output,
                graph: makeGraphReadback(
                    mode: .environmentAmbienceBed,
                    environmentConnectedToMainMixer: true,
                    applicableRenderingAlgorithmRawValues: [
                        AVAudio3DMixingRenderingAlgorithm.auto.rawValue
                    ]
                )
            )

            XCTAssertFalse(capability.outputAvailable)
            XCTAssertEqual(capability.systemSpatialSupport, .unknown)
            XCTAssertEqual(capability.currentOutputChannelCount, 0)
            XCTAssertEqual(capability.maximumOutputChannelCount, 0)
        }
    }

    func testProductionClientUsesActualOutputAndGraphReadback() throws {
        let client = AVAudioEngineClient()
        let revision = SpatialAudioSemanticRevision(rawValue: 16)
        let intent = makeAudioGraphIntent(
            channelCount: 2,
            revision: revision,
            platform: .macOS,
            routeSupport: .unknown,
            entitlement: .missing,
            userEnablesSpatialAudio: true
        )

        let runtime = try client.configure(
            .stereoLowLatency,
            graphIntent: intent
        )
        let route = client.routeSnapshot()
        let capability = client.macOSRouteOutputCapability(
            revision: revision
        )

        XCTAssertEqual(runtime.graphMode, .environmentAmbienceBed)
        XCTAssertEqual(capability.revision, revision)
        XCTAssertTrue(capability.outputAvailable)
        XCTAssertEqual(
            capability.currentOutputChannelCount,
            route.outputChannelCount
        )
        XCTAssertEqual(
            capability.maximumOutputChannelCount,
            route.outputChannelCount
        )
        XCTAssertEqual(capability.systemSpatialSupport, .supported)

        client.stop(drain: false)
        let stopped = client.macOSRouteOutputCapability(
            revision: .init(rawValue: 17)
        )
        XCTAssertTrue(stopped.outputAvailable)
        XCTAssertEqual(stopped.systemSpatialSupport, .unknown)
    }

    private func makeGraphReadback(
        mode: SpatialAudioGraphMode,
        fallbackReason: SpatialAudioGraphFallbackReason? = nil,
        environmentConnectedToMainMixer: Bool = false,
        applicableRenderingAlgorithmRawValues: [Int] = []
    ) -> AVAudioEngineGraphReadback {
        AVAudioEngineGraphReadback(
            mode: mode,
            fallbackReason: fallbackReason,
            platformStrategy: .none,
            listenerHeadTrackingCapable: false,
            listenerHeadTrackingReadback: false,
            visionExperienceReadback: nil,
            playerAttached: true,
            environmentAttached: true,
            playerConnectedToEnvironment: false,
            playerConnectedToMainMixer:
                mode == .nonspatialMixer,
            environmentConnectedToMainMixer:
                environmentConnectedToMainMixer,
            sourceModeRawValue: nil,
            selectedRenderingAlgorithmRawValue: nil,
            applicableRenderingAlgorithmRawValues:
                applicableRenderingAlgorithmRawValues,
            inputLayoutTagRawValue: nil
        )
    }
}
