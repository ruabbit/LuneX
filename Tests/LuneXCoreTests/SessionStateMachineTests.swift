import Foundation
import XCTest

final class SessionStateMachineTests: XCTestCase {
    func testSuccessRequiresLaunchRTSPNegotiationAndEveryRequiredChannel() async throws {
        let client = StateMachineLaunchClient()
        let coordinator = StreamSessionCoordinator(launchClient: client)
        let request = makeStateMachineRequest()
        let sessionID = UUID()
        let response = makeStateMachineLaunchResponse()

        let preparing = try await coordinator.prepare(request, sessionID: sessionID)
        let launched = try await coordinator.apply(
            .launchAccepted(response),
            sessionID: sessionID
        )
        let rtspReady = try await coordinator.apply(.rtspReady, sessionID: sessionID)
        let partial = try await coordinator.apply(
            .channelsReady(.control),
            sessionID: sessionID
        )

        XCTAssertEqual(preparing.stage, .launching)
        XCTAssertEqual(launched.stage, .readyForTransport)
        XCTAssertEqual(rtspReady.stage, .readyForTransport)
        XCTAssertEqual(partial.stage, .readyForTransport)
        XCTAssertEqual(partial.channelHealth.status, .degraded)
        XCTAssertFalse(partial.channelHealth.canStream)

        do {
            _ = try await coordinator.apply(.channelsReady(.all), sessionID: sessionID)
            XCTFail("Full channel health before negotiation must fail closed.")
        } catch let failure as StreamNegotiationFailure {
            XCTAssertEqual(failure.code, .invalidTransition)
        }
        let stillPartial = await coordinator.snapshot
        XCTAssertEqual(stillPartial.stage, .readyForTransport)
        XCTAssertEqual(stillPartial.channelHealth.healthyChannels, .control)

        let configuration = makeStateMachineNegotiatedConfiguration(sessionID: sessionID)
        let negotiated = try await coordinator.apply(
            .negotiated(configuration),
            sessionID: sessionID
        )
        let streaming = try await coordinator.apply(
            .channelsReady(.all),
            sessionID: sessionID
        )
        let duplicateChannels = try await coordinator.apply(
            .channelsReady(.all),
            sessionID: sessionID
        )
        let lateDuplicateRTSP = try await coordinator.apply(
            .rtspReady,
            sessionID: sessionID
        )

        XCTAssertEqual(negotiated.stage, .readyForTransport)
        XCTAssertEqual(negotiated.negotiatedConfiguration, configuration)
        XCTAssertEqual(streaming.stage, .streaming)
        XCTAssertEqual(streaming, duplicateChannels)
        XCTAssertEqual(streaming, lateDuplicateRTSP)
        XCTAssertTrue(streaming.channelHealth.canStream)
        XCTAssertNil(streaming.failure)
    }

    func testRequiredChannelLossAndReconnectRequireFreshNegotiation() async throws {
        let client = StateMachineLaunchClient()
        let coordinator = StreamSessionCoordinator(launchClient: client)
        let request = makeStateMachineRequest()
        let sessionID = UUID()
        _ = try await makeStreaming(
            coordinator: coordinator,
            request: request,
            sessionID: sessionID
        )

        let lost = try await coordinator.apply(
            .channelsReady([.control, .video, .audio]),
            sessionID: sessionID
        )
        XCTAssertEqual(lost.stage, .reconnecting)
        XCTAssertEqual(lost.channelHealth.status, .degraded)
        XCTAssertFalse(lost.channelHealth.canStream)

        let reconnecting = try await coordinator.apply(
            .reconnecting(attempt: 1, reason: "control_unavailable"),
            sessionID: sessionID
        )
        let duplicate = try await coordinator.apply(
            .reconnecting(attempt: 1, reason: "control_unavailable"),
            sessionID: sessionID
        )
        XCTAssertEqual(reconnecting, duplicate)
        XCTAssertEqual(reconnecting.reconnectAttempt, 1)
        XCTAssertEqual(reconnecting.channelHealth.status, .unavailable)
        XCTAssertNil(reconnecting.negotiatedConfiguration)

        _ = try await coordinator.apply(.rtspReady, sessionID: sessionID)
        let controlOnly = try await coordinator.apply(
            .channelsReady(.control),
            sessionID: sessionID
        )
        XCTAssertEqual(controlOnly.stage, .reconnecting)

        do {
            _ = try await coordinator.apply(.channelsReady(.all), sessionID: sessionID)
            XCTFail("Recovered channels cannot stream before the resumed RTSP configuration is validated.")
        } catch let failure as StreamNegotiationFailure {
            XCTAssertEqual(failure.code, .invalidTransition)
        }

        let resumedConfiguration = makeStateMachineNegotiatedConfiguration(sessionID: sessionID)
        _ = try await coordinator.apply(
            .negotiated(resumedConfiguration),
            sessionID: sessionID
        )
        let recovered = try await coordinator.apply(
            .channelsReady(.all),
            sessionID: sessionID
        )
        XCTAssertEqual(recovered.stage, .streaming)
        XCTAssertEqual(recovered.reconnectAttempt, 1)
        XCTAssertEqual(recovered.negotiatedConfiguration, resumedConfiguration)
    }

    func testTerminalFailureClearsReadinessAndKeepsStructuredFailure() async throws {
        let coordinator = StreamSessionCoordinator(launchClient: StateMachineLaunchClient())
        let sessionID = UUID()
        _ = try await makeStreaming(
            coordinator: coordinator,
            request: makeStateMachineRequest(),
            sessionID: sessionID
        )
        let failure = StreamNegotiationFailure(
            code: .reconnectExhausted,
            subsystem: "reconnect",
            message: "Retry budget exhausted."
        )

        let failed = try await coordinator.fail(failure, sessionID: sessionID)

        XCTAssertEqual(failed.stage, .failed)
        XCTAssertEqual(failed.failure, failure)
        XCTAssertEqual(failed.channelHealth.status, .unavailable)
        XCTAssertFalse(failed.channelHealth.canStream)
        XCTAssertNil(failed.terminationReason)
    }

    func testRemoteTerminationPreservesReasonWithoutSendingCancel() async throws {
        let client = StateMachineLaunchClient()
        let coordinator = StreamSessionCoordinator(launchClient: client)
        let sessionID = UUID()
        _ = try await makeStreaming(
            coordinator: coordinator,
            request: makeStateMachineRequest(),
            sessionID: sessionID
        )

        let terminated = try await coordinator.apply(
            .terminated(reason: "The host ended the streaming session."),
            sessionID: sessionID
        )
        let duplicate = try await coordinator.apply(
            .terminated(reason: "The host ended the streaming session."),
            sessionID: sessionID
        )
        let afterLateFailure = try await coordinator.fail(
            ControlChannelError.invalidFrame,
            sessionID: sessionID
        )
        let stopCount = await client.stopCount()

        XCTAssertEqual(terminated, duplicate)
        XCTAssertEqual(terminated, afterLateFailure)
        XCTAssertEqual(terminated.stage, .disconnected)
        XCTAssertEqual(terminated.terminationReason, "The host ended the streaming session.")
        XCTAssertEqual(terminated.channelHealth.status, .unavailable)
        XCTAssertEqual(stopCount, 0)
    }

    func testLocalStopIsIdempotentAndEndsDisconnected() async throws {
        let client = StateMachineLaunchClient()
        let coordinator = StreamSessionCoordinator(launchClient: client)
        let request = makeStateMachineRequest()
        let sessionID = UUID()
        _ = try await makeStreaming(
            coordinator: coordinator,
            request: request,
            sessionID: sessionID
        )

        let stopped = try await coordinator.stop(
            host: request.host,
            clientUniqueID: request.clientUniqueID
        )
        let duplicate = try await coordinator.stop(
            host: request.host,
            clientUniqueID: request.clientUniqueID
        )
        let stopCount = await client.stopCount()

        XCTAssertEqual(stopped, duplicate)
        XCTAssertEqual(stopped.stage, .disconnected)
        XCTAssertEqual(stopped.channelHealth.status, .unavailable)
        XCTAssertNil(stopped.terminationReason)
        XCTAssertEqual(stopCount, 1)
    }

    func testOldGenerationCannotMutateReplacementState() async throws {
        let coordinator = StreamSessionCoordinator(launchClient: StateMachineLaunchClient())
        let request = makeStateMachineRequest()
        let firstSessionID = UUID()
        _ = try await coordinator.prepare(request, sessionID: firstSessionID)
        _ = try await coordinator.apply(
            .launchAccepted(makeStateMachineLaunchResponse()),
            sessionID: firstSessionID
        )
        _ = try await coordinator.apply(
            .terminated(reason: "Replaced"),
            sessionID: firstSessionID
        )

        let replacementID = UUID()
        let replacement = try await coordinator.prepare(request, sessionID: replacementID)
        do {
            _ = try await coordinator.apply(.rtspReady, sessionID: firstSessionID)
            XCTFail("A stale generation must not publish readiness into its replacement.")
        } catch let failure as StreamNegotiationFailure {
            XCTAssertEqual(failure.code, .invalidTransition)
        }
        let afterStaleEvent = await coordinator.snapshot

        XCTAssertEqual(afterStaleEvent, replacement)
        XCTAssertEqual(afterStaleEvent.sessionID, replacementID)
        XCTAssertEqual(afterStaleEvent.stage, .launching)
        XCTAssertNil(afterStaleEvent.launchResponse)
    }

    func testDuplicateEventsAreIdempotentAndInvalidOrderFailsClosed() async throws {
        let coordinator = StreamSessionCoordinator(launchClient: StateMachineLaunchClient())
        let request = makeStateMachineRequest()
        let sessionID = UUID()
        _ = try await coordinator.prepare(request, sessionID: sessionID)

        do {
            _ = try await coordinator.apply(.rtspReady, sessionID: sessionID)
            XCTFail("RTSP cannot become ready before launch acceptance.")
        } catch let failure as StreamNegotiationFailure {
            XCTAssertEqual(failure.code, .invalidTransition)
        }
        let afterInvalid = await coordinator.snapshot
        XCTAssertEqual(afterInvalid.stage, .launching)

        let response = makeStateMachineLaunchResponse()
        let launched = try await coordinator.apply(.launchAccepted(response), sessionID: sessionID)
        let duplicateLaunch = try await coordinator.apply(.launchAccepted(response), sessionID: sessionID)
        XCTAssertEqual(launched, duplicateLaunch)

        let rtsp = try await coordinator.apply(.rtspReady, sessionID: sessionID)
        let duplicateRTSP = try await coordinator.apply(.rtspReady, sessionID: sessionID)
        XCTAssertEqual(rtsp, duplicateRTSP)

        let configuration = makeStateMachineNegotiatedConfiguration(sessionID: sessionID)
        let negotiated = try await coordinator.apply(.negotiated(configuration), sessionID: sessionID)
        let duplicateNegotiated = try await coordinator.apply(.negotiated(configuration), sessionID: sessionID)
        XCTAssertEqual(negotiated, duplicateNegotiated)
    }

    func testVideoColorMetadataUpdatesNegotiatedConfigurationWithoutBeingDropped() async throws {
        let coordinator = StreamSessionCoordinator(launchClient: StateMachineLaunchClient())
        let sessionID = UUID()
        let streaming = try await makeStreaming(
            coordinator: coordinator,
            request: makeStateMachineRequest(),
            sessionID: sessionID
        )
        let updatedMetadata = VideoColorMetadata.hdr10VideoRange(
            contentLight: VideoContentLightMetadata(
                maximumContentLightLevelNits: 1_200,
                maximumFrameAverageLightLevelNits: 400
            ),
            maximumFullFrameLuminanceNits: 500
        )

        let updated = try await coordinator.apply(
            .videoColorMetadata(updatedMetadata),
            sessionID: sessionID
        )
        let duplicate = try await coordinator.apply(
            .videoColorMetadata(updatedMetadata),
            sessionID: sessionID
        )

        XCTAssertNotEqual(updated, streaming)
        XCTAssertEqual(updated, duplicate)
        XCTAssertEqual(updated.stage, .streaming)
        XCTAssertEqual(updated.videoColorMetadata, updatedMetadata)
        XCTAssertEqual(
            updated.negotiatedConfiguration?.video.colorMetadata,
            updatedMetadata
        )
    }

    private func makeStreaming(
        coordinator: StreamSessionCoordinator,
        request: StreamLaunchRequest,
        sessionID: UUID
    ) async throws -> StreamSessionSnapshot {
        _ = try await coordinator.prepare(request, sessionID: sessionID)
        _ = try await coordinator.apply(
            .launchAccepted(makeStateMachineLaunchResponse()),
            sessionID: sessionID
        )
        _ = try await coordinator.apply(.rtspReady, sessionID: sessionID)
        _ = try await coordinator.apply(
            .negotiated(makeStateMachineNegotiatedConfiguration(sessionID: sessionID)),
            sessionID: sessionID
        )
        return try await coordinator.apply(.channelsReady(.all), sessionID: sessionID)
    }
}

func makeStateMachineNegotiatedConfiguration(
    sessionID: UUID
) -> NegotiatedSessionConfiguration {
    NegotiatedSessionConfiguration(
        sessionID: sessionID,
        controlEndpoint: RuntimeNetworkEndpoint(
            host: "example.invalid",
            port: 47_999,
            transport: .udp
        ),
        videoEndpoint: RuntimeNetworkEndpoint(
            host: "example.invalid",
            port: 48_000,
            transport: .udp
        ),
        audioEndpoint: RuntimeNetworkEndpoint(
            host: "example.invalid",
            port: 48_010,
            transport: .udp
        ),
        inputEndpoint: RuntimeNetworkEndpoint(
            host: "example.invalid",
            port: 35_043,
            transport: .tcp
        ),
        video: NegotiatedVideoStreamConfiguration(
            codec: .hevc,
            width: 3_840,
            height: 2_160,
            frameRate: 60,
            colorMetadata: .hdr10VideoRange(),
            maximumPacketSize: 1_400
        ),
        audio: NegotiatedAudioStreamConfiguration(
            sampleRate: 48_000,
            channelCount: 2,
            streamCount: 1,
            coupledStreamCount: 1,
            samplesPerFrame: 240,
            channelMapping: [0, 1],
            maximumPacketSize: 1_400
        ),
        input: NegotiatedInputConfiguration(
            keyMaterial: RemoteInputKeyMaterial(
                keyID: 1,
                key: Data(repeating: 0x11, count: 16)
            ),
            encrypted: true,
            maximumMessageSize: 1_024
        ),
        requiredChannels: .all
    )
}

private func makeStateMachineRequest() -> StreamLaunchRequest {
    StreamLaunchRequest(
        host: MoonlightHost(
            id: UUID(uuidString: "A9D1905F-DA67-493C-9F4F-D9CE0548D7CE")!,
            name: "State Machine Host",
            address: "example.invalid",
            pairingState: .paired,
            reachability: .online,
            pinnedIdentity: PinnedHostIdentity(
                certificateSHA256: "synthetic-pin",
                serverCertificateDER: Data([1, 2, 3]),
                pairedAt: Date(timeIntervalSince1970: 1)
            )
        ),
        app: RemoteApp(id: "1", name: "Desktop", supportsHDR: true, installPath: nil),
        preferences: .defaults,
        clientUniqueID: "synthetic-client",
        remoteInputKey: RemoteInputKeyMaterial(
            keyID: 1,
            key: Data(repeating: 0x11, count: 16)
        ),
        audioPlaybackMode: .clientOnly,
        controllerBitmap: 0,
        optimizeGameSettings: false
    )
}

private func makeStateMachineLaunchResponse() -> StreamLaunchResponse {
    StreamLaunchResponse(
        sessionURL: "rtsp://example.invalid/session",
        gameSessionID: "session-1",
        rawValues: ["gamesession": "session-1"]
    )
}

private actor StateMachineLaunchClient: StreamLaunchClient {
    private var stops = 0

    func launch(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        makeStateMachineLaunchResponse()
    }

    func resume(
        _ request: StreamLaunchRequest,
        parameters: StreamNegotiationParameters
    ) async throws -> StreamLaunchResponse {
        makeStateMachineLaunchResponse()
    }

    func stop(host: MoonlightHost, clientUniqueID: String) async throws {
        stops += 1
    }

    func stopCount() -> Int {
        stops
    }
}
