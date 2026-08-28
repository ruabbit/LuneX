import Foundation
import XCTest

final class RuntimeDiagnosticsTests: XCTestCase {
    func testRecorderRedactsSecretAndPrivateFields() async {
        let recorder = RuntimeDiagnosticsRecorder()
        let event = await recorder.record(
            sessionID: nil,
            subsystem: "pairing",
            stage: "challenge",
            severity: .info,
            code: "request",
            fields: [
                RuntimeDiagnosticField("pin", .string("1234")),
                RuntimeDiagnosticField("privateKeyDER", .string("sensitive")),
                RuntimeDiagnosticField("endpoint", .string("10.0.0.1:47984")),
                RuntimeDiagnosticField("packetCount", .integer(3))
            ]
        )

        XCTAssertEqual(event.fields["pin"], "<redacted>")
        XCTAssertEqual(event.fields["privateKeyDER"], "<redacted>")
        XCTAssertEqual(event.fields["endpoint"], "<private>")
        XCTAssertEqual(event.fields["packetCount"], "3")
    }

    func testEmbeddedSecretIsRedactedEvenWhenMarkedPublic() async {
        let recorder = RuntimeDiagnosticsRecorder()
        let event = await recorder.record(
            sessionID: nil,
            subsystem: "network",
            stage: "request",
            severity: .warning,
            code: "rejected",
            fields: [
                RuntimeDiagnosticField("detail", .string("Authorization: Basic fixture"))
            ]
        )

        XCTAssertEqual(event.fields["detail"], "<redacted>")
    }

    func testStageTimingUsesMonotonicNanoseconds() async {
        let recorder = RuntimeDiagnosticsRecorder()
        let sessionID = UUID(uuidString: "7B1D927C-F4EC-484D-BCC8-662336101618")!
        let token = await recorder.beginStage(
            sessionID: sessionID,
            subsystem: "rtsp",
            stage: "negotiate",
            monotonicNanoseconds: 1_000_000
        )
        let event = await recorder.endStage(
            token,
            code: "ready",
            monotonicNanoseconds: 4_500_000,
            recordedAt: Date(timeIntervalSince1970: 50)
        )

        XCTAssertEqual(event.elapsedMilliseconds, 3.5)
        XCTAssertEqual(event.sessionID, sessionID)
        XCTAssertEqual(event.code, "ready")
    }

    func testRecorderCapacityAndSessionFilterAreBounded() async {
        let recorder = RuntimeDiagnosticsRecorder(capacity: 2)
        let firstSession = UUID(uuidString: "530645CD-D2D8-4D8D-88A7-A487C476C039")!
        let secondSession = UUID(uuidString: "C2491297-ADDF-4779-8EE0-4CE2792BF7D7")!
        _ = await recorder.record(
            sessionID: firstSession,
            subsystem: "one",
            stage: "one",
            severity: .debug,
            code: "one"
        )
        _ = await recorder.record(
            sessionID: firstSession,
            subsystem: "two",
            stage: "two",
            severity: .info,
            code: "two"
        )
        _ = await recorder.record(
            sessionID: secondSession,
            subsystem: "three",
            stage: "three",
            severity: .error,
            code: "three"
        )

        let all = await recorder.snapshot()
        let first = await recorder.snapshot(sessionID: firstSession)
        XCTAssertEqual(all.map(\.code), ["two", "three"])
        XCTAssertEqual(first.map(\.code), ["two"])
    }

    @MainActor
    func testDiagnosticsStoreReceivesOnlyRedactedRuntimeEvent() async {
        let recorder = RuntimeDiagnosticsRecorder()
        let runtimeEvent = await recorder.record(
            sessionID: nil,
            subsystem: "input",
            stage: "send",
            severity: .info,
            code: "complete",
            fields: [RuntimeDiagnosticField("remoteInputKey", .string("secret"))],
            elapsedMilliseconds: 1.25,
            recordedAt: Date(timeIntervalSince1970: 80)
        )
        let store = DiagnosticsStore()

        store.record(runtimeEvent: runtimeEvent)

        XCTAssertEqual(store.events.count, 1)
        XCTAssertTrue(store.events[0].message.contains("remoteInputKey=<redacted>"))
        XCTAssertFalse(store.events[0].message.contains("secret"))
        XCTAssertEqual(store.events[0].category, .input)
        XCTAssertEqual(store.events[0].severity, .info)
        XCTAssertEqual(store.events[0].code, "complete")
    }

    @MainActor
    func testApplicationDiagnosticsClassifyEveryRuntimeFailureDomain() {
        let pairing = ApplicationDiagnosticFactory.pairingFailure(PairingFailure(
            code: .invalidPIN,
            message: "host detail must not be copied"
        ))
        let transport = ApplicationDiagnosticFactory.streamFailure(NetworkChannelError.closed)
        let decoder = ApplicationDiagnosticFactory.streamFailure(VideoDecoderError.noActiveSession)
        let audio = ApplicationDiagnosticFactory.streamFailure(OpusDecoderError.closed)
        let input = ApplicationDiagnosticFactory.streamFailure(RemoteInputRuntimeError.deliveryFailed)

        XCTAssertEqual(pairing.category, .pairing)
        XCTAssertEqual(pairing.action, .verifyPIN)
        XCTAssertEqual(transport.category, .transport)
        XCTAssertEqual(transport.action, .retryStream)
        XCTAssertEqual(decoder.category, .decoder)
        XCTAssertEqual(decoder.action, .reviewStreamSettings)
        XCTAssertEqual(audio.category, .audio)
        XCTAssertEqual(audio.action, .checkAudioOutput)
        XCTAssertEqual(input.category, .input)
        XCTAssertEqual(input.action, .reconnectInput)
    }

    @MainActor
    func testApplicationDiagnosticsClassifyEncryptedAudioPacketFailures() {
        let invalidKey = ApplicationDiagnosticFactory.streamFailure(
            MoonlightAudioPacketDecryptError.invalidKeyMaterial
        )
        XCTAssertEqual(invalidKey.category, .audio)
        XCTAssertEqual(invalidKey.code, "audio_packet_invalid_key")
        XCTAssertEqual(invalidKey.action, .checkAudioOutput)

        let invalidCiphertext = ApplicationDiagnosticFactory.streamFailure(
            MoonlightAudioPacketDecryptError.invalidCiphertext
        )
        XCTAssertEqual(invalidCiphertext.category, .audio)
        XCTAssertEqual(invalidCiphertext.code, "audio_packet_invalid_ciphertext")

        let decryptionFailed = ApplicationDiagnosticFactory.streamFailure(
            MoonlightAudioPacketDecryptError.decryptionFailed
        )
        XCTAssertEqual(decryptionFailed.category, .audio)
        XCTAssertEqual(decryptionFailed.code, "audio_packet_decryption_failed")
    }

    @MainActor
    func testApplicationDiagnosticsClassifyAudioProcessingFailuresWithoutDetails() {
        let cases: [(Error, AudioProcessingFailureCause)] = [
            (OpusDecoderError.invalidPacketPayload, .decoderInvalidPayload),
            (OpusDecoderError.decodeFailed(-50), .decoderDecodeFailed),
            (OpusDecoderError.inconsistentPCMOutput, .decoderInconsistentPCM),
            (AudioJitterBufferError.sequenceGapTooLarge(
                expected: 12,
                received: 65_000
            ), .jitterSequenceGap),
            (AudioPipelineError.notRunning, .pipelineNotRunning),
            (AudioPipelineError.invalidPCMBuffer, .pipelineInvalidPCM),
            (AudioPipelineError.scheduleCapacityExceeded, .pipelineScheduleCapacity),
            (AudioRuntimeRecoveryError.nonMonotonicEventTime, .runtimeClock),
            (AudioRuntimeRecoveryError.graphFailed(
                "secret endpoint payload certificate key"
            ), .runtimeGraph),
            (AudioRuntimeRecoveryError.arithmeticOverflow, .runtimeArithmetic),
        ]

        for (error, expectedCause) in cases {
            XCTAssertEqual(
                AudioProcessingFailureCause.classify(error),
                expectedCause
            )
            let diagnostic = ApplicationDiagnosticFactory.streamFailure(error)
            XCTAssertEqual(diagnostic.category, .audio)
            XCTAssertEqual(diagnostic.code, expectedCause.rawValue)
            XCTAssertEqual(diagnostic.action, .checkAudioOutput)
            for forbidden in ["-50", "12", "65000", "secret"] {
                XCTAssertFalse(diagnostic.code.contains(forbidden))
                XCTAssertFalse(
                    diagnostic.summary.localizedCaseInsensitiveContains(forbidden)
                )
            }
        }

        let secretGraph = ApplicationDiagnosticFactory.streamFailure(
            AudioRuntimeRecoveryError.graphFailed(
                "secret endpoint payload certificate key"
            )
        )
        for forbidden in [
            "secret", "endpoint", "payload", "certificate", "key",
        ] {
            XCTAssertFalse(secretGraph.code.contains(forbidden))
            XCTAssertFalse(
                secretGraph.summary.localizedCaseInsensitiveContains(forbidden)
            )
        }
    }

    @MainActor
    func testStaleLifecycleApplicationUsesSafeStableDiagnostic() {
        let diagnostic = ApplicationDiagnosticFactory.streamFailure(
            SessionMediaEnvironmentError.staleLifecycleApplication
        )

        XCTAssertEqual(diagnostic.category, .transport)
        XCTAssertEqual(diagnostic.code, "media_lifecycle_stale")
        XCTAssertEqual(diagnostic.action, .retryStream)
        XCTAssertFalse(diagnostic.summary.localizedCaseInsensitiveContains("generation"))
        XCTAssertFalse(diagnostic.summary.localizedCaseInsensitiveContains("session"))
    }

    @MainActor
    func testApplicationInputFailuresUseSafeInputDiagnostics() {
        let unavailable = ApplicationDiagnosticFactory.streamFailure(
            SessionMediaEnvironmentError.inputUnavailable
        )
        let stale = ApplicationDiagnosticFactory.streamFailure(
            SessionMediaEnvironmentError.staleInputApplication
        )

        XCTAssertEqual(unavailable.category, .input)
        XCTAssertEqual(unavailable.code, "application_input_unavailable")
        XCTAssertEqual(unavailable.action, .reconnectInput)
        XCTAssertEqual(stale.category, .input)
        XCTAssertEqual(stale.code, "application_input_stale")
        XCTAssertEqual(stale.action, .reconnectInput)
        XCTAssertFalse(stale.summary.localizedCaseInsensitiveContains("generation"))
    }

    @MainActor
    func testStaleAudioPreferenceApplicationUsesSafeAudioDiagnostic() {
        let diagnostic = ApplicationDiagnosticFactory.streamFailure(
            SessionMediaEnvironmentError.staleAudioApplication
        )

        XCTAssertEqual(diagnostic.category, .audio)
        XCTAssertEqual(diagnostic.code, "application_audio_stale")
        XCTAssertEqual(diagnostic.action, .checkAudioOutput)
        XCTAssertFalse(diagnostic.summary.localizedCaseInsensitiveContains("generation"))
    }

    @MainActor
    func testTVVisionPresentationApplicationsUseSafeStableDiagnostics() {
        let stale = ApplicationDiagnosticFactory.streamFailure(
            SessionMediaEnvironmentError
                .staleTVVisionPlatformPresentationApplication
        )
        let invalid = ApplicationDiagnosticFactory.streamFailure(
            SessionMediaEnvironmentError
                .invalidTVVisionPlatformPresentationApplication
        )

        XCTAssertEqual(stale.category, .transport)
        XCTAssertEqual(stale.code, "platform_presentation_stale")
        XCTAssertEqual(stale.action, .retryStream)
        XCTAssertEqual(invalid.category, .transport)
        XCTAssertEqual(invalid.code, "platform_presentation_invalid")
        XCTAssertEqual(invalid.action, .retryStream)
        for diagnostic in [stale, invalid] {
            XCTAssertFalse(
                diagnostic.summary.localizedCaseInsensitiveContains("session")
            )
            XCTAssertFalse(
                diagnostic.summary.localizedCaseInsensitiveContains("generation")
            )
            XCTAssertFalse(
                diagnostic.summary.localizedCaseInsensitiveContains("ownership")
            )
        }
    }

    @MainActor
    func testUnknownFailureNeverCopiesSecretBearingDescription() {
        let diagnostic = ApplicationDiagnosticFactory.streamFailure(
            SecretBearingDiagnosticError()
        )
        let store = DiagnosticsStore()

        store.record(diagnostic)

        let event = store.events[0]
        XCTAssertEqual(event.code, "session_failed")
        XCTAssertEqual(event.message, "The streaming transport stopped unexpectedly.")
        XCTAssertFalse(event.message.contains("1234"))
        XCTAssertFalse(event.message.localizedCaseInsensitiveContains("authorization"))
    }

    @MainActor
    func testPlainDiagnosticMessagesAlsoRejectEmbeddedSecrets() {
        let store = DiagnosticsStore()

        store.record("Request failed Authorization: Basic private-value")

        XCTAssertEqual(store.events[0].message, "<redacted>")
    }

    @MainActor
    func testActionableStoreIsBoundedAndRetainsRecoveryAction() {
        let store = DiagnosticsStore(capacity: 2)
        store.record("first")
        store.record(ApplicationDiagnosticFactory.streamUnavailable)
        store.record(ApplicationDiagnosticFactory.streamFailure(OpusDecoderError.closed))

        XCTAssertEqual(store.events.count, 2)
        XCTAssertEqual(store.events.map(\.category), [.transport, .audio])
        XCTAssertEqual(store.latestActionableEvent?.action, .checkAudioOutput)
    }

    @MainActor
    func testCurrentActionsClearByCategoryWithoutDeletingHistory() {
        let store = DiagnosticsStore()
        store.record(ApplicationDiagnosticFactory.pairingUnavailable, date: Date(timeIntervalSince1970: 1))
        store.record(
            ApplicationDiagnosticFactory.streamFailure(VideoDecoderError.noActiveSession),
            date: Date(timeIntervalSince1970: 2)
        )
        store.record(
            ApplicationDiagnosticFactory.streamFailure(RemoteInputRuntimeError.deliveryFailed),
            date: Date(timeIntervalSince1970: 3)
        )

        XCTAssertEqual(store.latestActionableEvent?.category, .input)
        XCTAssertEqual(store.latestStreamActionableEvent?.category, .input)

        store.clearActionableEvents(in: [.input])

        XCTAssertEqual(store.latestActionableEvent?.category, .decoder)
        XCTAssertEqual(store.latestStreamActionableEvent?.category, .decoder)
        XCTAssertEqual(store.events.count, 3)

        store.clearStreamActionableEvents()

        XCTAssertEqual(store.latestActionableEvent?.category, .pairing)
        XCTAssertNil(store.latestStreamActionableEvent)
        XCTAssertEqual(store.events.count, 3)

        store.clearAllActionableEvents()

        XCTAssertNil(store.latestActionableEvent)
        XCTAssertEqual(store.events.count, 3)
    }

    @MainActor
    func testEquivalentAudioActionKeepsCurrentOwnershipAndBoundedHistory() {
        let store = DiagnosticsStore(capacity: 3)
        let audio = ApplicationDiagnosticFactory.spatialAudioState(.unsupportedRoute)
        store.record(audio, date: Date(timeIntervalSince1970: 1))
        store.record(
            ApplicationDiagnosticFactory.streamFailure(VideoDecoderError.noActiveSession),
            date: Date(timeIntervalSince1970: 2)
        )
        store.record(audio, date: Date(timeIntervalSince1970: 3))
        store.record("bounded history tail", code: "tail")

        XCTAssertEqual(store.events.map(\.code), [
            "video_pipeline_failed",
            "spatial_audio_unsupported_route",
            "tail"
        ])
        XCTAssertEqual(
            store.currentActionableEvent(in: .audio)?.date,
            Date(timeIntervalSince1970: 1)
        )
        XCTAssertEqual(store.latestStreamActionableEvent?.category, .decoder)
    }

    @MainActor
    func testAudioRecoveryClearsOnlyAudioCurrentActionAndPreservesHistory() {
        let store = DiagnosticsStore()
        let diagnostics: [ApplicationDiagnostic] = [
            ApplicationDiagnosticFactory.pairingUnavailable,
            ApplicationDiagnosticFactory.streamFailure(NetworkChannelError.closed),
            ApplicationDiagnosticFactory.streamFailure(VideoDecoderError.noActiveSession),
            ApplicationDiagnosticFactory.hdrPresentationState(.pipelineFailure)!,
            ApplicationDiagnosticFactory.spatialAudioState(.graphFailure),
            ApplicationDiagnosticFactory.streamFailure(
                RemoteInputRuntimeError.deliveryFailed
            )
        ]
        for (index, diagnostic) in diagnostics.enumerated() {
            store.record(
                diagnostic,
                date: Date(timeIntervalSince1970: TimeInterval(index + 1))
            )
        }

        store.clearActionableEvents(in: [.audio])
        store.record(
            ApplicationDiagnosticFactory.spatialAudioState(.fixedSpatial),
            date: Date(timeIntervalSince1970: 7)
        )

        XCTAssertNil(store.currentActionableEvent(in: .audio))
        XCTAssertEqual(
            store.currentActionableEvent(in: .pairing)?.code,
            "pairing_provider_unavailable"
        )
        XCTAssertEqual(
            store.currentActionableEvent(in: .transport)?.code,
            "transport_failed"
        )
        XCTAssertEqual(
            store.currentActionableEvent(in: .decoder)?.code,
            "video_pipeline_failed"
        )
        XCTAssertEqual(
            store.currentActionableEvent(in: .hdr)?.code,
            "hdr_pipeline_failure"
        )
        XCTAssertEqual(
            store.currentActionableEvent(in: .input)?.code,
            "input_delivery_failed"
        )
        XCTAssertEqual(store.events.count, 7)
        XCTAssertEqual(
            store.events.map(\.code),
            diagnostics.map(\.code) + ["spatial_audio_active_fixed"]
        )
    }

    func testMacLifecycleAndInputDiagnosticsUseFixedPrivacyBoundedPayloads() {
        let diagnostics = MacLifecycleDiagnosticState.allTestStates.map(
            ApplicationDiagnosticFactory.macLifecycleState
        ) + MacInputDiagnosticState.allTestStates.map(
            ApplicationDiagnosticFactory.macInputState
        )
        let forbiddenValues = [
            "45F0C9CB-D795-49B2-A733-F68397632233",
            "moon.local",
            "2560",
            "1440",
            "keyCode",
            "characters",
            "generation"
        ]

        XCTAssertEqual(Set(diagnostics.map(\.code)).count, diagnostics.count)
        for diagnostic in diagnostics {
            XCTAssertEqual(diagnostic.severity, .info)
            XCTAssertNil(diagnostic.action)
            for value in forbiddenValues {
                XCTAssertFalse(diagnostic.code.localizedCaseInsensitiveContains(value))
                XCTAssertFalse(diagnostic.summary.localizedCaseInsensitiveContains(value))
            }
        }
    }

    func testMobileRuntimeDiagnosticsUseFixedPrivacyBoundedPayloads() {
        let diagnostics = [
            MobileSceneDiagnosticState.detached,
            .active,
            .inactive,
            .background,
            .resizing,
            .settled,
            .invalidGeometry
        ].map(ApplicationDiagnosticFactory.mobileSceneState) + [
            MobileDisplayDiagnosticState.detached,
            .sdr,
            .edr,
            .fallback,
            .unavailable
        ].map(ApplicationDiagnosticFactory.mobileDisplayState) + [
            MobilePictureInPictureDiagnosticState.preparing,
            .possible,
            .unavailable,
            .starting,
            .active,
            .stopping,
            .stopped,
            .failed,
            .invalidated
        ].map(ApplicationDiagnosticFactory.mobilePictureInPictureState) + [
            MobileContinuityDiagnosticState.foreground,
            .pictureInPicture,
            .audioOnly,
            .suspended,
            .stopped,
            .stale,
            .applicationFailed,
            .revisionExhausted
        ].map(ApplicationDiagnosticFactory.mobileContinuityState)
        let forbiddenValues = [
            "45F0C9CB-D795-49B2-A733-F68397632233",
            "private-host.local",
            "sceneIdentifier",
            "windowIdentifier",
            "screenIdentifier",
            "controllerIdentifier",
            "frameIdentifier",
            "sampleBuffer"
        ]

        XCTAssertEqual(Set(diagnostics.map(\.code)).count, diagnostics.count)
        for diagnostic in diagnostics {
            XCTAssertNil(diagnostic.action)
            for value in forbiddenValues {
                XCTAssertFalse(
                    diagnostic.code.localizedCaseInsensitiveContains(value)
                )
                XCTAssertFalse(
                    diagnostic.summary.localizedCaseInsensitiveContains(value)
                )
            }
        }
    }

    func testHDRDiagnosticsUseStablePrivacyBoundedSemanticPayloads() throws {
        let states: [HDRPresentationDiagnosticState] = [
            .activeSDR,
            .activeEDR,
            .sdrFallback(.userPreferenceDisabled),
            .sdrFallback(.platformOutputUnsupported(.macOS)),
            .sdrFallback(.currentHeadroomUnavailable),
            .sdrFallback(.currentHeadroomInvalid),
            .sdrFallback(.currentHeadroomInsufficient),
            .invalidInput,
            .unsupportedOutput,
            .staleRevision,
            .pipelineFailure
        ]
        let diagnostics = try states.map {
            try XCTUnwrap(ApplicationDiagnosticFactory.hdrPresentationState($0))
        }
        let forbiddenValues = [
            "private-host",
            "game-name",
            "display-serial",
            "decoderGeneration",
            "displayRevision",
            "frame",
            "metadata",
            "pixel"
        ]

        XCTAssertNil(ApplicationDiagnosticFactory.hdrPresentationState(.inactive))
        XCTAssertEqual(Set(diagnostics.map(\.code)).count, diagnostics.count)
        XCTAssertTrue(diagnostics.allSatisfy { $0.category == .hdr })
        XCTAssertTrue(diagnostics.allSatisfy { $0.subsystem == "stream.hdr" })
        for diagnostic in diagnostics {
            for value in forbiddenValues {
                XCTAssertFalse(
                    diagnostic.code.localizedCaseInsensitiveContains(value)
                )
                XCTAssertFalse(
                    diagnostic.summary.localizedCaseInsensitiveContains(value)
                )
            }
        }
    }

    func testSpatialAudioDiagnosticsUseStablePrivacyBoundedSemanticPayloads() {
        let states: [SpatialAudioDiagnosticState] = [
            .inactive,
            .activeNonspatial,
            .fixedSpatial,
            .headTracked,
            .visionFixed,
            .visionHeadTracked,
            .fallback(.userDisabled),
            .fallback(.outputUnavailable),
            .fallback(.invalidRoute),
            .fallback(.staleRevision),
            .fallback(.renderingAlgorithmUnavailable),
            .fallback(.incompatiblePlatformStrategy),
            .fallback(.headTrackingNotApplied),
            .fallback(.visionExperienceNotApplied),
            .missingEntitlement,
            .unreadableEntitlement,
            .unsupportedRoute,
            .unsupportedLayout,
            .recovery,
            .graphFailure
        ]
        let diagnostics = states.map(ApplicationDiagnosticFactory.spatialAudioState)
        let forbiddenValues = [
            "private-route-uid",
            "private-output-name",
            "private-host",
            "private-app",
            "raw-entitlement-value",
            "channel-sample",
            "notification-payload",
            "free-form-graph-error",
            "5D41FA2B-B199-46D8-B966-D4EB557AA2B3",
            "mediaGeneration"
        ]

        XCTAssertEqual(Set(diagnostics.map(\.code)).count, diagnostics.count)
        XCTAssertTrue(diagnostics.allSatisfy { $0.category == .audio })
        XCTAssertTrue(diagnostics.allSatisfy { $0.subsystem == "stream.audio" })
        for diagnostic in diagnostics {
            for value in forbiddenValues {
                XCTAssertFalse(
                    diagnostic.code.localizedCaseInsensitiveContains(value)
                )
                XCTAssertFalse(
                    diagnostic.summary.localizedCaseInsensitiveContains(value)
                )
            }
        }
    }

    func testSpatialRuntimeMapsClosedActiveFallbackRecoveryAndFailureStates() {
        let fixed = makeSpatialRuntimeEvent(
            spatialRuntime: makeSpatialRuntime(
                presentationMode: .fixedSpatial
            )
        )
        let visionHeadTracked = makeSpatialRuntimeEvent(
            spatialRuntime: makeSpatialRuntime(
                platformStrategy: .visionOutputExperience,
                presentationMode: .headTracked
            )
        )
        let missingEntitlement = makeSpatialRuntimeEvent(
            spatialRuntime: makeSpatialRuntime(
                presentationMode: .fixedSpatial,
                fallbackReason: .missingEntitlement
            )
        )
        let unsupportedRoute = makeSpatialRuntimeEvent(
            spatialRuntime: makeSpatialRuntime(
                presentationMode: .nonspatial,
                fallbackReason: .routeUnsupported
            )
        )
        let unsupportedLayout = makeSpatialRuntimeEvent(
            spatialRuntime: makeSpatialRuntime(
                presentationMode: .nonspatial,
                fallbackReason: .unsupportedLayout
            )
        )
        let recovery = makeSpatialRuntimeEvent(
            cause: .interruptionBegan,
            stage: .interrupted,
            spatialRuntime: makeSpatialRuntime(
                presentationMode: .fixedSpatial
            )
        )
        let graphFailure = makeSpatialRuntimeEvent(
            spatialRuntime: makeSpatialRuntime(
                presentationMode: .nonspatial,
                fallbackReason: .graphUnavailable
            )
        )
        let nonGraphFailure = makeSpatialRuntimeEvent(
            cause: .failed,
            stage: .failed,
            spatialRuntime: makeSpatialRuntime(
                presentationMode: .fixedSpatial
            )
        )

        XCTAssertEqual(SpatialAudioDiagnosticState(runtime: fixed), .fixedSpatial)
        XCTAssertEqual(
            SpatialAudioDiagnosticState(runtime: visionHeadTracked),
            .visionHeadTracked
        )
        XCTAssertEqual(
            SpatialAudioDiagnosticState(runtime: missingEntitlement),
            .missingEntitlement
        )
        XCTAssertEqual(
            SpatialAudioDiagnosticState(runtime: unsupportedRoute),
            .unsupportedRoute
        )
        XCTAssertEqual(
            SpatialAudioDiagnosticState(runtime: unsupportedLayout),
            .unsupportedLayout
        )
        XCTAssertEqual(SpatialAudioDiagnosticState(runtime: recovery), .recovery)
        XCTAssertEqual(
            SpatialAudioDiagnosticState(runtime: graphFailure),
            .graphFailure
        )
        XCTAssertEqual(
            SpatialAudioDiagnosticState(runtime: nonGraphFailure),
            .inactive
        )
    }

    func testHDRResolutionErrorsMapToClosedSemanticDiagnosticClasses() {
        let invalidInput: [HDRRenderResolutionError] = [
            .invalidSourceContract,
            .incompatibleSourceAndMapping,
            .unsupportedDecodedLayout,
            .incompatibleDecodedLayout
        ]
        let unsupportedOutput: [HDRRenderResolutionError] = [
            .unsupportedPlatformOutput(.macOS),
            .missingCurrentDisplayHeadroom,
            .invalidCurrentDisplayHeadroom,
            .insufficientCurrentDisplayHeadroom,
            .userDisabledHDRWithoutSDRFallback,
            .unsupportedSurfaceContract,
            .incompatibleMappingAndSurface
        ]
        let staleRevision: [HDRRenderResolutionError] = [
            .staleDecoderGeneration(expected: 2, actual: 1),
            .staleColorSignature,
            .staleDisplayRevision(
                expected: HDRDisplayRevision(rawValue: 2),
                actual: HDRDisplayRevision(rawValue: 1)
            ),
            .invalidDisplayRevision,
            .displayRevisionExhausted
        ]

        XCTAssertTrue(invalidInput.allSatisfy {
            HDRPresentationDiagnosticState.closed($0) == .invalidInput
        })
        XCTAssertTrue(unsupportedOutput.allSatisfy {
            HDRPresentationDiagnosticState.closed($0) == .unsupportedOutput
        })
        XCTAssertTrue(staleRevision.allSatisfy {
            HDRPresentationDiagnosticState.closed($0) == .staleRevision
        })
        XCTAssertEqual(
            HDRPresentationDiagnosticState.closed(.inactiveSession),
            .inactive
        )
        XCTAssertEqual(
            HDRPresentationDiagnosticState.closed(.drawableUnavailable),
            .inactive
        )
    }

    @MainActor
    func testHDRActionRecoveryDoesNotClearOtherStreamActionsOrHistory() {
        let store = DiagnosticsStore(capacity: 4)
        store.record(
            ApplicationDiagnosticFactory.streamFailure(VideoDecoderError.noActiveSession),
            date: Date(timeIntervalSince1970: 1)
        )
        store.record(
            ApplicationDiagnosticFactory.hdrPresentationState(.pipelineFailure)!,
            date: Date(timeIntervalSince1970: 2)
        )

        XCTAssertEqual(store.latestStreamActionableEvent?.category, .hdr)
        store.clearActionableEvents(in: [.hdr])

        XCTAssertEqual(store.latestStreamActionableEvent?.category, .decoder)
        XCTAssertEqual(
            store.events.map(\.code),
            ["video_pipeline_failed", "hdr_pipeline_failure"]
        )
    }

    @MainActor
    func testControllerFeedbackDiagnosticDoesNotExposeControllerIdentity() {
        let diagnostic = ApplicationDiagnosticFactory.remoteFeedback(
            RemoteInputFeedbackDiagnostic(
                controllerID: "private-controller-id",
                controllerIndex: 3,
                command: .rumble,
                reason: .unsupportedCapability
            )
        )

        XCTAssertEqual(diagnostic.category, .input)
        XCTAssertEqual(diagnostic.severity, .warning)
        XCTAssertEqual(diagnostic.action, .useSupportedController)
        XCTAssertFalse(diagnostic.summary.contains("private-controller-id"))
        XCTAssertFalse(diagnostic.code.contains("3"))
    }

    @MainActor
    func testPlatformDiagnosticsDeduplicateSemanticStateAndRejectConflicts() {
        let store = DiagnosticsStore(capacity: 2)
        let owner = store.beginTVVisionPlatformDiagnosticOwnership()

        XCTAssertEqual(
            store.record(
                tvVisionPlatform: platformDiagnostic(.active, revision: 1),
                owner: owner,
                date: Date(timeIntervalSince1970: 1)
            ),
            .recorded
        )
        XCTAssertEqual(
            store.record(
                tvVisionPlatform: platformDiagnostic(.active, revision: 1),
                owner: owner
            ),
            .deduplicated
        )
        XCTAssertEqual(
            store.record(
                tvVisionPlatform: platformDiagnostic(.active, revision: 2),
                owner: owner
            ),
            .deduplicated
        )
        XCTAssertEqual(
            store.record(
                tvVisionPlatform: platformDiagnostic(
                    .displayFallback(.headroomUnavailable),
                    revision: 2
                ),
                owner: owner
            ),
            .conflictingRevision
        )
        XCTAssertEqual(
            store.record(
                tvVisionPlatform: platformDiagnostic(
                    .displayFallback(.headroomUnavailable),
                    revision: 1
                ),
                owner: owner
            ),
            .staleRevision
        )
        XCTAssertEqual(
            store.record(
                tvVisionPlatform: platformDiagnostic(
                    .displayFallback(.headroomUnavailable),
                    revision: 3
                ),
                owner: owner,
                date: Date(timeIntervalSince1970: 3)
            ),
            .recorded
        )
        XCTAssertEqual(
            store.record(
                tvVisionPlatform: platformDiagnostic(
                    .failed(.invalidComponent(.video)),
                    revision: 4
                ),
                owner: owner,
                date: Date(timeIntervalSince1970: 4)
            ),
            .recorded
        )

        XCTAssertEqual(store.events.count, 2)
        XCTAssertEqual(store.events.map(\.code), [
            "platform_tvos_display_fallback",
            "platform_tvos_failed_invalid_video"
        ])
    }

    @MainActor
    func testPlatformDiagnosticReplacementMakesOldRecordAndClearInert() {
        let store = DiagnosticsStore()
        let oldOwner = store.beginTVVisionPlatformDiagnosticOwnership()
        XCTAssertEqual(
            store.record(
                tvVisionPlatform: platformDiagnostic(
                    .failed(.invalidComponent(.input)),
                    revision: 1
                ),
                owner: oldOwner
            ),
            .recorded
        )
        XCTAssertEqual(store.currentActionableEvent(in: .input)?.action, .reconnectInput)

        let replacementOwner = store.beginTVVisionPlatformDiagnosticOwnership()
        XCTAssertNil(store.currentActionableEvent(in: .input))
        XCTAssertEqual(
            store.record(
                tvVisionPlatform: platformDiagnostic(.sceneClosed, revision: 2),
                owner: oldOwner
            ),
            .staleOwner
        )
        XCTAssertEqual(
            store.record(
                tvVisionPlatform: platformDiagnostic(
                    .failed(.invalidComponent(.audioRoute)),
                    revision: 1
                ),
                owner: replacementOwner
            ),
            .recorded
        )

        store.endTVVisionPlatformDiagnosticOwnership(oldOwner)
        XCTAssertEqual(store.currentActionableEvent(in: .audio)?.action, .checkAudioOutput)
        store.endTVVisionPlatformDiagnosticOwnership(replacementOwner)
        XCTAssertNil(store.currentActionableEvent(in: .audio))
        XCTAssertEqual(store.events.count, 2)
    }

    @MainActor
    func testPlatformRecoveryClearsOnlyItsOwnedActionAndPreservesHistory() {
        let store = DiagnosticsStore()
        store.record(
            ApplicationDiagnosticFactory.streamFailure(VideoDecoderError.noActiveSession),
            date: Date(timeIntervalSince1970: 1)
        )
        let owner = store.beginTVVisionPlatformDiagnosticOwnership()
        store.record(
            tvVisionPlatform: platformDiagnostic(
                .displayFallback(.headroomUnavailable),
                revision: 1
            ),
            owner: owner,
            date: Date(timeIntervalSince1970: 2)
        )
        store.record(
            tvVisionPlatform: platformDiagnostic(.displayDirectEDR, revision: 2),
            owner: owner,
            date: Date(timeIntervalSince1970: 3)
        )

        XCTAssertNil(store.currentActionableEvent(in: .hdr))
        XCTAssertEqual(
            store.currentActionableEvent(in: .decoder)?.code,
            "video_pipeline_failed"
        )

        store.record(
            tvVisionPlatform: platformDiagnostic(
                .displayFallback(.headroomUnavailable),
                revision: 3
            ),
            owner: owner,
            date: Date(timeIntervalSince1970: 4)
        )
        store.record(
            ApplicationDiagnosticFactory.hdrPresentationState(.pipelineFailure)!,
            date: Date(timeIntervalSince1970: 5)
        )
        store.record(
            tvVisionPlatform: platformDiagnostic(.displayDirectEDR, revision: 4),
            owner: owner,
            date: Date(timeIntervalSince1970: 6)
        )

        XCTAssertEqual(
            store.currentActionableEvent(in: .hdr)?.code,
            "hdr_pipeline_failure"
        )
        XCTAssertEqual(store.events.count, 6)
    }

    @MainActor
    func testIdenticalNonPlatformActionReclaimsCurrentOwnershipWithoutHistoryDeduplication() {
        let store = DiagnosticsStore()
        let owner = store.beginTVVisionPlatformDiagnosticOwnership()
        let fallback = platformDiagnostic(
            .displayFallback(.headroomUnavailable),
            revision: 1
        )

        store.record(tvVisionPlatform: fallback, owner: owner)
        let platformEvent = try? XCTUnwrap(store.currentActionableEvent(in: .hdr))
        XCTAssertNotNil(platformEvent)

        store.record(fallback.applicationDiagnosticForTesting)
        XCTAssertEqual(store.events.count, 2)
        XCTAssertEqual(
            store.currentActionableEvent(in: .hdr)?.id,
            platformEvent?.id
        )

        store.record(
            tvVisionPlatform: platformDiagnostic(.displayDirectEDR, revision: 2),
            owner: owner
        )

        XCTAssertEqual(
            store.currentActionableEvent(in: .hdr)?.id,
            platformEvent?.id
        )
        XCTAssertEqual(store.events.count, 3)
    }

    @MainActor
    func testDiagnosticsExportRedactsIdentityFieldsAgain() {
        let store = DiagnosticsStore(capacity: 2)
        let privateUUID = "4D02BF54-C9ED-4D69-9068-39FD083BD146"
        store.record("safe", subsystem: "app", code: "safe")
        store.record(
            "session=\(privateUUID) host=private.local endpoint=10.0.0.4:47984 "
                + "generation=9 revision=10 frameID=11 controllerID=pad-1 "
                + "displayID=panel-1 routeID=route-1",
            subsystem: "routeID=private-route",
            code: "session=private-session"
        )

        XCTAssertEqual(store.events.count, 2)
        XCTAssertTrue(store.events[1].message.contains(privateUUID))
        let export = store.exportText
        for privateValue in [
            privateUUID,
            "private.local",
            "10.0.0.4",
            "private-session",
            "pad-1",
            "panel-1",
            "route-1",
            "private-route"
        ] {
            XCTAssertFalse(export.contains(privateValue), privateValue)
        }
        XCTAssertTrue(export.contains("<private>"))
        XCTAssertFalse(export.contains(store.events[1].id.uuidString))
        XCTAssertEqual(store.exportRecords.count, 2)
    }

    func testPlatformDiagnosticProjectionUsesFixedSnapshotState() throws {
        let fallbackSnapshot = try makePlatformDiagnosticSnapshot(
            sequence: 4,
            phase: .active,
            diagnostic: .displayFallback(.headroomUnavailable)
        )
        let failedSnapshot = try makePlatformDiagnosticSnapshot(
            sequence: 5,
            phase: .failed(.actionFailed(.audioRoute)),
            diagnostic: .activated
        )

        XCTAssertEqual(
            TVVisionPlatformDiagnosticValue(snapshot: fallbackSnapshot),
            platformDiagnostic(
                .displayFallback(.headroomUnavailable),
                revision: 4
            )
        )
        XCTAssertEqual(
            TVVisionPlatformDiagnosticValue(snapshot: failedSnapshot),
            platformDiagnostic(
                .failed(.actionFailed(.audioRoute)),
                revision: 5
            )
        )
    }

    func testPlatformDiagnosticsAppAndExportSourceContract() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let rootView = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("Sources/LuneXApp/RootView.swift"),
            encoding: .utf8
        )
        let appModel = try String(
            contentsOf: repositoryRoot
                .appendingPathComponent("Sources/LuneXCore/AppModel.swift"),
            encoding: .utf8
        )
        let store = try String(
            contentsOf: repositoryRoot.appendingPathComponent(
                "Sources/LuneXDiagnostics/DiagnosticsStore.swift"
            ),
            encoding: .utf8
        )
        let diagnosticsStart = try XCTUnwrap(
            rootView.range(of: "struct DiagnosticsView")
        )
        let settingsStart = try XCTUnwrap(
            rootView.range(of: "private struct SettingsView")
        )
        let diagnosticsView = String(
            rootView[diagnosticsStart.lowerBound..<settingsStart.lowerBound]
        )

        XCTAssertTrue(diagnosticsView.contains("#if os(tvOS)"))
        XCTAssertTrue(diagnosticsView.contains("Export Unavailable"))
        XCTAssertTrue(diagnosticsView.contains("ShareLink(item:"))
        XCTAssertTrue(diagnosticsView.contains("appModel.diagnostics.exportText"))
        XCTAssertTrue(diagnosticsView.contains("square.and.arrow.up"))
        XCTAssertTrue(diagnosticsView.contains("privacy-redacted"))
        XCTAssertTrue(appModel.contains("publishTVVisionPlatformDiagnostic"))
        XCTAssertTrue(appModel.contains("clearTVVisionPlatformDiagnostics"))
        XCTAssertTrue(appModel.contains("beginTVVisionPlatformDiagnosticOwnership"))
        XCTAssertTrue(store.contains("case staleOwner"))
        XCTAssertTrue(store.contains("case conflictingRevision"))
        XCTAssertTrue(store.contains("DiagnosticExportRedactor.redact"))
        XCTAssertFalse(store.contains("struct DiagnosticExportRecord: Identifiable"))
    }
}

private extension MacLifecycleDiagnosticState {
    static let allTestStates: [Self] = [
        .inactive,
        .active,
        .occluded,
        .unfocused,
        .drawableUnavailable
    ]
}

private extension MacInputDiagnosticState {
    static let allTestStates: [Self] = [
        .unavailable,
        .closed,
        .directReady,
        .relativeReady
    ]
}

private func makeSpatialRuntimeEvent(
    cause: SessionAudioRuntimeEventCause = .initial,
    stage: SessionAudioRuntimeStage = .running,
    spatialRuntime: SpatialAudioRuntimeSnapshot?
) -> SessionAudioRuntimeEvent {
    SessionAudioRuntimeEvent(
        sessionID: UUID(uuidString: "93FBD084-17D1-4DD2-BD11-D8E16921A670")!,
        sequence: 0,
        graphGeneration: 1,
        cause: cause,
        stage: stage,
        spatialRuntime: spatialRuntime,
        routeCapability: SpatialAudioRouteCapabilitySnapshot(
            revision: spatialRuntime?.revision ?? .init(rawValue: 0),
            outputAvailable: true,
            systemSpatialSupport: .supported,
            currentOutputChannelCount: 2,
            maximumOutputChannelCount: 8
        ),
        entitlement: .granted,
        preferences: .nativeDefault,
        concealedFrameCount: 0,
        lastAction: .none
    )
}

private func makeSpatialRuntime(
    platformStrategy: SpatialAudioPlatformStrategy = .environmentListener,
    presentationMode: SpatialAudioPresentationMode,
    fallbackReason: SpatialAudioFallbackReason? = nil
) -> SpatialAudioRuntimeSnapshot {
    SpatialAudioRuntimeSnapshot(
        revision: SpatialAudioSemanticRevision(rawValue: 1),
        layoutSignature: StreamAudioChannelLayout.stereo.signature,
        graphMode: presentationMode == .nonspatial
            ? .nonspatialMixer
            : .environmentAmbienceBed,
        platformStrategy: platformStrategy,
        routeSupport: fallbackReason == .routeUnsupported ? .unsupported : .supported,
        presentationMode: presentationMode,
        fallbackReason: fallbackReason
    )
}

private struct SecretBearingDiagnosticError: Error, CustomStringConvertible {
    var description: String {
        "Authorization: Basic secret; PIN=1234"
    }
}

private func platformDiagnostic(
    _ state: TVVisionPlatformDiagnosticState,
    revision: UInt64
) -> TVVisionPlatformDiagnosticValue {
    TVVisionPlatformDiagnosticValue(
        platform: .tvOS,
        sourceRevision: revision,
        state: state
    )
}

private extension TVVisionPlatformDiagnosticValue {
    var applicationDiagnosticForTesting: ApplicationDiagnostic {
        switch state {
        case .displayFallback:
            return ApplicationDiagnostic(
                category: .hdr,
                severity: .warning,
                code: "platform_tvos_display_fallback",
                summary: "Apple TV is using HDR-to-SDR fallback.",
                action: .reviewHDRSettings
            )
        default:
            preconditionFailure("This helper only recreates the fallback diagnostic")
        }
    }
}

private func makePlatformDiagnosticSnapshot(
    sequence: UInt64,
    phase: TVVisionPlatformPresentationPhase,
    diagnostic: TVVisionPlatformPresentationDiagnosticClass
) throws -> TVVisionPlatformPresentationCoordinatorSnapshot {
    let sessionID = UUID(uuidString: "7CF12CF8-DA94-49A0-81E2-7AC22A322799")!
    let ownership = try TVVisionPresentationOwnership(
        platform: .tvOS,
        sessionID: sessionID,
        mediaGeneration: 1,
        presentationGeneration: TVVisionGeneration(
            domain: .presentation,
            rawValue: 1
        ),
        inputGeneration: TVVisionGeneration(domain: .input, rawValue: 1)
    )
    return TVVisionPlatformPresentationCoordinatorSnapshot(
        ownership: ownership,
        sequence: sequence,
        revision: try TVVisionSemanticRevision(rawValue: sequence),
        phase: phase,
        presentation: nil,
        visionWindowedPresentation: nil,
        display: nil,
        audioRoute: nil,
        video: TVVisionPlatformVideoSnapshot(
            phase: .idle,
            lastDeliveryRevision: nil,
            isPresented: false
        ),
        diagnostics: [TVVisionPlatformPresentationDiagnostic(
            sequence: sequence,
            classification: diagnostic
        )],
        teardownCount: 0,
        isSemanticRevisionExhausted: false,
        isSequenceExhausted: false
    )
}
