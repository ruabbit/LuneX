## Context

Stage 13 already negotiates Sunshine Opus configurations, decodes bounded interleaved signed 16-bit PCM, schedules it through `SessionAudioRuntime`, rebuilds the graph after route/interruption discontinuities, and owns the processor inside `NativeSessionMediaEnvironment`. The production `AVAudioEngineClient`, however, connects only `AVAudioPlayerNode -> mainMixerNode`; `NativeSessionAudioProcessorFactory` fixes `spatialAudioEnabled` to false. A separate `SpatialAudioController` creates an `AVAudioEnvironmentNode` that is never attached to that engine, so its head-tracking property cannot affect audible session audio.

The Moonlight channel order is WAVE-compatible: stereo is left/right, 5.1 is front-left/front-right/center/LFE/back-left/back-right, and 7.1 adds side-left/side-right after the rear pair. Xcode 26.4 supplies matching Core Audio layouts, including `kAudioChannelLayoutTag_WAVE_7_1`. The SDK also confirms that multichannel environment inputs need an explicit layout and `AVAudio3DMixingSourceMode.ambienceBed`; `.pointSource` would collapse the bed to one position.

Head tracking differs by platform. macOS 15+, iOS 18+, and tvOS 18+ expose `AVAudioEnvironmentNode.isListenerHeadTrackingEnabled` and require the head-pose entitlement for compatible AirPods. visionOS marks that property unavailable, while visionOS 26 exposes `AVAudioOutputNode.intendedSpatialExperience`. iOS/iPadOS/tvOS/visionOS expose `AVAudioSession` multichannel declarations and spatial capability notifications; macOS does not. API availability, successful graph configuration, embedded entitlement, and real hardware behavior remain separate evidence.

## Goals / Non-Goals

**Goals:**

- Preserve one validated logical channel layout from negotiated Opus configuration through PCM scheduling and the actual engine connection format.
- Make the environment node part of the session-owned production graph and spatialize stereo/multichannel game audio as an ambience bed.
- Derive one semantic spatial state from graph configuration, user preference, platform route, embedded entitlement, and head-tracking API result.
- Re-resolve/rebuild that state atomically on route, capability, interruption, reconnect, stop, and processor replacement.
- Publish privacy-bounded diagnostics and accessible native settings/status backed by the active runtime, with deterministic five-platform verification.

**Non-Goals:**

- Claiming Dolby Atmos bitstream passthrough, object-audio authoring, personalized HRTF profile access, custom Core Motion pose processing, or arbitrary channel layouts outside the negotiated Moonlight set.
- Adding placeholder production video/audio network receivers or treating injected media as live Sunshine interoperability.
- Claiming head tracking, speaker localization, channel separation, audible sync, or entitlement provisioning from compilation, property assignment, simulator output, or offline manual rendering alone.
- Completing mobile PiP/background continuity, final tvOS/visionOS product workflows, release signing, or performance/power qualification; later stages own those gates.

## Decisions

### Use an immutable Moonlight channel-layout contract

`StreamAudioChannelLayout` will resolve only the negotiated channel counts LuneX can describe truthfully: mono, stereo, 5.1 WAVE, and 7.1 WAVE. It will carry ordered semantic channel labels, a Core Audio layout tag, spatial eligibility, and a stable diagnostic code. `StreamAudioConfiguration.validate()` and decoded PCM validation will require the same channel count and layout identity.

The existing raw `channelCount` alone was rejected because `AVAudioFormat(channels:)` does not preserve speaker positions. Accepting every count from one through eight was also rejected: three-, four-, five-, and seven-channel layouts have multiple incompatible meanings that Sunshine negotiation does not currently identify.

### Put one environment node inside the existing engine owner

`AVAudioEngineClient` will own `engine`, `player`, and `environment`. For spatial-eligible stereo/5.1/7.1 content it will attach/connect `player -> environment -> mainMixer`, construct the player format from the resolved channel layout, set `player.sourceMode = .ambienceBed`, select `.auto` only when applicable after connection, and retain deterministic bypass/fallback when the graph cannot support spatial rendering. Mono remains nonspatial and connects through the normal mixer path.

Creating one player per channel was rejected because the negotiated PCM arrives as one interleaved bed and the environment node already understands a labeled multichannel bus. Keeping the disconnected controller was rejected because it has no authority over scheduled PCM or graph recovery.

### Resolve capability from observed platform state, not names

The engine client will return a structured `SpatialAudioRuntimeSnapshot` with graph mode, logical layout, route capability, spatial activation, head-tracking availability/activation, platform strategy, and a stable unavailable/fallback reason. Mobile-family adapters inspect `AVAudioSession.currentRoute.outputs[].isSpatialAudioEnabled`, declare multichannel content, and listen to route/interruption/spatial-capability notifications. macOS uses the actual output format plus successful environment connection and leaves route-brand assertions to hardware tests.

Output names remain diagnostic-only and are never used to infer AirPods or spatial capability. A route called “AirPods” is not proof of an enabled spatial path.

### Separate entitlement intent, embedded value, and hardware proof

Repository entitlements for macOS/iOS/tvOS request `com.apple.developer.coremotion.head-pose`. Production reads the embedded signed entitlement through an injectable Security-backed reader; only a literal true value is eligible. Absence, false, read failure, or a provisioning profile that omits the entitlement disables listener head tracking while preserving fixed spatial playback.

visionOS does not use this listener property. On visionOS 26 the output node receives `.headTracked` or `.fixed` intended spatial experience according to the user setting; the runtime reports this platform strategy separately. Neither branch is marked hardware-verified until physical acceptance.

### Make route changes generation-owned recovery inputs

An injectable route monitor produces semantic revisions rather than passing raw notifications into application state. The active `SessionAudioRuntime` serializes route/capability/interruption changes with scheduling. A spatially meaningful revision stops the current player/engine, invalidates scheduled-buffer ownership, rebuilds from the same immutable negotiated configuration, and publishes the new snapshot only if the session/audio generation still matches.

Replacement processor shutdown cancels observation before graph teardown. Late notification callbacks, schedule completions, or rebuild results cannot publish into a replacement generation. The existing concealment and media-clock recovery contract remains intact.

### Route active state through media environment and AppModel

`SessionAudioProcessing` gains an async stream or callback for semantic audio runtime events. `NativeSessionMediaEnvironment` forwards current-generation audio state alongside readiness; `AppModel` owns the latest state only for the active media session and clears it on replacement/stop/failure. Settings contain spatial-audio and head-tracking preferences with backward-compatible decoding for existing settings files.

The stream overlay and Settings show compact fixed labels derived from active runtime state. They do not expose route UID/name, host/app identity, raw entitlement values, channel samples, notification payloads, or unbounded error text.

## Risks / Trade-offs

- [Risk] An incorrect channel tag can rotate or swap surround positions. -> Mitigation: lock Moonlight order against clean-room reference evidence, use WAVE tags, test semantic label order and impulse routing, and retain physical channel-identification acceptance.
- [Risk] Environment-node format negotiation can fail or expose a rendering algorithm unavailable for the current route. -> Mitigation: resolve applicable algorithms after connection, stop/reset atomically on failure, and downgrade to a typed nonspatial mixer path rather than failing the whole stream where PCM playback remains valid.
- [Risk] Route notifications can race packet scheduling and replacement teardown. -> Mitigation: serialize revisions in the session runtime, bind callbacks to generation tokens, invalidate pending buffer receipts, and make stop idempotent.
- [Risk] Requesting a restricted entitlement can prevent device signing when the profile lacks it. -> Mitigation: keep unsigned/simulator builds independent, read the embedded signed value at runtime, degrade cleanly without it, and retain release provisioning as a later gate.
- [Risk] Enabling both the environment renderer and system spatialization can double-process content. -> Mitigation: declare multichannel content, use one repository-owned graph policy, keep platform system-bypass keys explicit, and verify actual route behavior before hardware completion.
- [Risk] Simulator and offline engine tests cannot prove audible head tracking or spatial separation. -> Mitigation: preserve an incomplete hardware task covering AirPods, built-in speakers, wired/HDMI multichannel, entitlement absence, route changes, and channel-identification material.

## Migration Plan

1. Add channel-layout and spatial-state value contracts plus deterministic resolver tests without changing the production graph.
2. Replace the disconnected controller with an injectable engine-owned environment graph and verify schedule/fallback/cleanup.
3. Add platform route, entitlement, multichannel declaration, and visionOS spatial-experience adapters behind protocol boundaries.
4. Connect route/recovery/replacement ownership through the processor, media environment, AppModel, diagnostics, and native UI.
5. Run normal, five-platform Debug/Release, generator/OpenSpec, analyzer, sanitizer, malloc/resource, and fixed-simulator inventory gates.
6. Complete authorized physical route/head-tracking/channel-identification acceptance. Before that gate, rollback is the diagnosed nonspatial mixer path, not a claim that head tracking works.

## Open Questions

- Which authorized AirPods model, built-in speaker devices, and HDMI/USB multichannel output will be used for final acceptance?
- Which signing profile will carry the head-pose entitlement for macOS, iOS, and tvOS physical builds?
- Whether personalized spatial-audio profile access adds useful value is deferred until the base session-owned graph and physical head tracking are accepted.
