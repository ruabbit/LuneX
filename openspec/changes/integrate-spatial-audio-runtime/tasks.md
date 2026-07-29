## 1. Channel-layout and spatial-state foundation

- [x] 1.1 Inventory the current negotiated Opus order, decoded PCM contract, engine graph, recovery ownership, Apple SDK APIs, entitlement boundary, platform differences, and physical proof limits without changing runtime behavior
- [x] 1.2 Define immutable mono, stereo, WAVE 5.1, and WAVE 7.1 semantic channel-layout contracts with Core Audio tags, stable signatures, spatial eligibility, and closed unsupported-layout errors
- [x] 1.3 Define immutable graph, platform-strategy, route-capability, spatial/head-tracking, fallback, and semantic-revision snapshots with a deterministic resolver
- [x] 1.4 Bind negotiated audio configuration and decoded PCM validation to the same channel-layout identity without duplicating raw channel ownership
- [x] 1.5 Add deterministic channel-order, layout-tag, ambiguous-count, resolver-grid, duplicate-revision, privacy-bound, and finite-capacity tests

## 2. Session-owned environment audio graph

- [x] 2.1 Extend the injectable audio-engine client contract to configure graph intent and return actual spatial runtime snapshots without exposing AVFAudio objects across actors
- [x] 2.2 Build interleaved PCM `AVAudioFormat` values with explicit channel layouts and validate buffer-list channel and byte ownership
- [x] 2.3 Attach the production environment node and connect player-to-environment-to-mixer for eligible ambience-bed audio, selecting only an applicable rendering algorithm
- [x] 2.4 Implement typed mono, user-disabled, unsupported-route, unsupported-algorithm, and graph-failure fallback to nonspatial PCM without false activation
- [ ] 2.5 Apply macOS/iOS/tvOS listener head tracking and visionOS 26 output-node intended spatial experience through compile-safe platform strategies
- [ ] 2.6 Add graph topology, schedule/readback, layout mismatch, algorithm fallback, head-tracking readback, visionOS strategy, partial-failure, stop, idempotence, and resource-release tests

## 3. Platform route, entitlement, and capability adapters

- [ ] 3.1 Implement an injectable Security-backed embedded head-pose entitlement reader that treats missing, false, malformed, and unreadable values as unavailable
- [ ] 3.2 Add generator-owned macOS, iOS, and tvOS head-pose entitlement files/build settings while preserving visionOS platform separation and unsigned buildability
- [ ] 3.3 Implement the iOS/iPadOS/tvOS/visionOS `AVAudioSession` playback, multichannel declaration, preferred-channel, spatial-port, deactivation, and capability-notification adapter
- [ ] 3.4 Implement macOS route/output capability resolution from the actual engine output format and graph result without product-name inference
- [ ] 3.5 Implement an injectable bounded route/interruption/media-services/spatial-capability monitor that emits deduplicated semantic revisions
- [ ] 3.6 Add entitlement, platform matrix, multichannel limit, capability notification, equivalent-notification, missing-route, output-name noninference, deactivate, and observer-cleanup tests

## 4. Recovery, session generation, and application ownership

- [ ] 4.1 Extend `SessionAudioRuntime` to serialize route/spatial policy revisions with scheduling, defer changes during interruption, rebuild atomically, and preserve media-clock/concealment behavior
- [ ] 4.2 Extend `NativeSessionAudioProcessor` and its factory to own the route monitor, current spatial preferences, graph generation, and semantic audio-state event stream
- [ ] 4.3 Forward current-generation audio runtime state through `NativeSessionMediaEnvironment` alongside readiness and discard stale processor/rebuild events
- [ ] 4.4 Bind `AppModel` audio/spatial state and preference changes to the active session/media generation, clearing current state on stop, failure, reconnect, and replacement
- [ ] 4.5 Add route-during-interruption, capability downgrade/recovery, preference change, underrun/concealment, stale completion, stop/restart, and generation-replacement tests
- [ ] 4.6 Add one application integration gate spanning negotiated 7.1 PCM, environment graph state, media readiness, route downgrade, entitlement fallback, reconnect replacement, diagnostics, and clean stop

## 5. Settings, diagnostics, and native product state

- [ ] 5.1 Add backward-compatible spatial-audio and head-tracking settings defaults, persistence, migration, and active-stream update behavior
- [ ] 5.2 Replace free-form spatial diagnostics with stable privacy-bounded active, fixed, head-tracked, visionOS, fallback, entitlement, route/layout, recovery, and graph-failure states
- [ ] 5.3 Deduplicate current audio action ownership and scope recovery clearing so transport, decoder, HDR, input, and pairing actions remain intact
- [ ] 5.4 Replace the static stream spatial pill with actual runtime state and add native spatial/head-tracking Settings controls plus inactive/fallback status
- [ ] 5.5 Add responsive compact/wide layout, localization-safe text, accessibility label/value, preference migration, diagnostic ownership, and actual-state UI wiring tests

## 6. Verification, hardware acceptance, and tracking

- [ ] 6.1 Run normal tests with live-host and real-Keychain paths disabled and verify the only allowed Keychain skip
- [ ] 6.2 Build macOS Debug/Release and fixed iPhone, iPad, tvOS, and visionOS targets with warnings as errors and isolated DerivedData
- [ ] 6.3 Run OpenSpec strict, generator stability, clean-room/dependency, direct SDK API probes, static analyzer, and repository-boundary gates
- [ ] 6.4 Run ASan, TSan, malloc scribble/guard/resource ownership, graph replacement, observer cancellation, and scheduled-buffer release gates
- [ ] 6.5 Verify fixed simulator identities remain unique and `Shutdown` without creating, cloning, booting, launching, installing, running, shutting down, or deleting devices
- [ ] 6.6 Validate signed entitlement behavior, AirPods head tracking, fixed/nonspatial route fallback, built-in speakers, wired/HDMI multichannel channel identification, route transitions, audible synchronization, and clean teardown on authorized physical devices with redacted evidence
- [ ] 6.7 Update OpenSpec, planning files, runtime roadmap, audio contract, entitlement/hardware instructions, and proof boundaries; commit and push each completed task and perform a stage-level self-acceptance
