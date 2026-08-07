## 1. Platform inventory and immutable foundation

- [x] 1.1 Inventory current tvOS/visionOS targets, SwiftUI navigation, actual surface/lifecycle ownership, remote/focus/controller paths, decoder/Metal/HDR/audio/spatial integration, public SDK APIs, entitlements, simulator identities, and physical proof limits without changing runtime behavior
- [x] 1.2 Define immutable checked platform presentation, scene/surface, focus eligibility, geometry/drawable, input capability, controller lease, display, audio route, generation, and semantic-revision contracts
- [x] 1.3 Define tvOS local-focus versus stream-capture ownership, reserved-command, balanced press, controller slot/state/feedback, and ordered release effects
- [x] 1.4 Define visionOS windowed presentation mode, system-reserved interaction, supported input capability, focus/release, and explicit immersive-unavailable state
- [x] 1.5 Add finite normalization, duplicate/revision exhaustion, invalid geometry, stale generation, reserved command, held release, controller capacity, privacy, and platform capability tests
- [x] 1.6 Add direct tvOS/visionOS 26.4 public API probes and document supported, unavailable, deprecated, entitlement, simulator, and physical-device boundaries

## 2. Shared platform presentation ownership

- [x] 2.1 Extend the non-iOS UIKit Metal surface bridge with injectable attachment, layout, window-scene, visibility, scale, drawable, and focus eligibility callbacks for tvOS and visionOS
- [x] 2.2 Implement a main-actor generation owner that derives platform scene/window/screen state only from the actual stream view and rejects detached, invalid, and stale callbacks
- [x] 2.3 Publish one normalized geometry revision to drawable sizing, fit/fill rendering, and supported input reference mapping with semantic deduplication
- [x] 2.4 Implement a serialized platform presentation coordinator for scene, input eligibility, decoded frames, display/HDR, audio route, diagnostics, replacement, and shared teardown
- [x] 2.5 Connect current-generation presentation snapshots and bounded failures through `NativeSessionMediaEnvironment` and `AppModel`, clearing actual state on failure, reconnect, remote termination, and stop
- [x] 2.6 Add attachment, geometry, lifecycle, focus eligibility, application ordering, replacement, late callback, failure, and idempotent teardown tests

## 3. tvOS remote, focus, and controller runtime

- [x] 3.1 Implement actual tvOS stream-surface press begin/end/cancel capture with current-generation admission and balanced remote events
- [x] 3.2 Coordinate SwiftUI focus and overlay visibility so browser/settings/overlay navigation remains local and stream capture owns only eligible supported presses
- [x] 3.3 Keep Back/Menu/Home, volume, capture, power, and unsupported system commands local with native escape and typed unavailable behavior
- [x] 3.4 Replace connection-list-only controller monitoring with generation-owned extended/micro gamepad handlers, deterministic bounded slots, normalized complete state, and disconnect replacement
- [x] 3.5 Route controller state through the existing remote controller registry and apply supported feedback only to matching current controller leases
- [x] 3.6 Integrate focus/scene/provider/replacement/stop loss with the existing ordered held-state release barrier and local navigation restoration
- [x] 3.7 Add remote event order, local focus, overlay handoff, reserved command, controller profile/slot/capacity, feedback, disconnect, stale callback, release, replacement, and teardown tests

## 4. tvOS media presentation runtime

- [x] 4.1 Bind actual tvOS scene/surface lifecycle and geometry to `StreamMetalPresenter`, current decoded-frame delivery, stale-frame rejection, and clean clear/resume behavior
- [x] 4.2 Probe and implement public tvOS display/layer/color capability, retaining typed HDR-to-SDR output whenever direct extended-range presentation is unavailable
- [x] 4.3 Connect tvOS actual display/HDR revisions and bounded fallback diagnostics to the current render configuration and AppModel state
- [x] 4.4 Connect the current tvOS AVAudioSession route, canonical audio graph, spatial/head-tracking capability, interruption, media reset, and recovery to the media generation
- [ ] 4.5 Coordinate tvOS video, audio, input eligibility, app focus, failure, reconnect, remote termination, and stop through one shared generation teardown
- [ ] 4.6 Add SDR/HDR fallback, geometry/display change, stale frame, route/interruption/reset, graph replacement, AppModel application, and clean teardown tests

## 5. visionOS window and input runtime

- [ ] 5.1 Implement actual visionOS windowed stream-surface attachment, scene activity, visibility, geometry, scale, drawable, focus eligibility, and replacement observation
- [ ] 5.2 Bind the normalized visionOS geometry revision to Metal fit/fill and supported indirect or absolute input mapping, suppressing both on invalid/detached geometry
- [ ] 5.3 Inventory and implement public supported visionOS controller, keyboard, pointer, and indirect-input adapters behind typed capability and current-generation admission
- [ ] 5.4 Reserve system gestures, recentering, capture, safety, volume, escape, and unsupported gaze/hand interactions locally without synthetic Moonlight events
- [ ] 5.5 Integrate controller/keyboard/pointer focus loss, scene loss, provider failure, replacement, and stop with ordered held-state release and local UI restoration
- [ ] 5.6 Add multiwindow filtering, resize sequence, focus, capability matrix, reserved interaction, input mapping, held release, stale callback, replacement, and teardown tests

## 6. visionOS media presentation runtime

- [ ] 6.1 Implement an explicit current-generation windowed presentation mode and typed immersive/stereoscopic/volumetric unavailable states without creating an immersive runtime
- [ ] 6.2 Bind visionOS decoded frames, Metal surface, presentation revision, replacement, clear/resume, and stale-frame rejection to the current actual window surface
- [ ] 6.3 Probe and implement public visionOS layer/color/headroom capability, retaining typed HDR-to-SDR fallback whenever current finite headroom is unavailable
- [ ] 6.4 Connect canonical audio, public intended spatial experience, actual route capability, interruption/media reset recovery, graph replacement, and current-generation state
- [ ] 6.5 Coordinate visionOS scene, video, HDR fallback, audio, input eligibility, diagnostics, failure, reconnect, remote termination, and clean stop through one presentation coordinator
- [ ] 6.6 Add windowed-mode, immersive-unavailable, frame/render, HDR fallback, spatial route/recovery, AppModel application, replacement, resource release, and teardown tests

## 7. Native product integration

- [ ] 7.1 Add accessible native tvOS stream controls and actual focus/capture/controller/render/HDR/audio status with predictable focus order and no hover dependency
- [ ] 7.2 Add accessible native visionOS windowed stream controls and actual window/input/render/HDR/spatial status with typed immersive-unavailable state
- [ ] 7.3 Add platform Settings for supported input, controller, render, HDR, and spatial preferences while keeping desired and actual state distinct
- [ ] 7.4 Add privacy-bounded platform diagnostics, semantic deduplication, replacement ownership, finite history, export redaction, and recovery clearing
- [ ] 7.5 Add tvOS focus/navigation, visionOS window/input, compact/wide layout, localization, accessibility, actual-state, command, migration, and clean-stop application tests

## 8. Verification and acceptance

- [ ] 8.1 Run complete normal tests with real-Keychain and live-host opt-ins disabled and verify the only permitted skip remains the explicit real-Keychain test
- [ ] 8.2 Build macOS, fixed iPhone, fixed iPad, fixed Apple TV, and fixed Apple Vision Pro Debug/Release with Swift, Clang, and Metal warnings as errors using isolated evidence
- [ ] 8.3 Run OpenSpec strict, fixture, generator stability, membership, clean-room/reference/license, entitlement/configuration, privacy, API availability, analyzer, and repository-boundary gates
- [ ] 8.4 Run complete ASan, TSan, malloc scribble/guard, observer/controller handler cancellation, held-release, frame/audio completion, replacement, and teardown resource gates
- [ ] 8.5 Verify fixed simulator runtime/name/UUID identity, availability, shutdown, and single-instance inventory without creating, cloning, or duplicating device classes
- [ ] 8.6 Run only existing bounded tvOS/visionOS simulator navigation or UI targets required by this change, never launching more than one simulator per device class and never treating simulator behavior as physical proof
- [ ] 8.7 On authorized signed Apple TV and Apple Vision Pro hardware, verify remote/controller/keyboard input, focus/window behavior, SDR/HDR, spatial audio/routes, interruptions, live Sunshine, latency, power/thermal/comfort, and clean teardown
- [ ] 8.8 Synchronize OpenSpec, platform runtime contract, roadmap, `task_plan.md`, `findings.md`, and `progress.md`; record offline, simulator, signed-artifact, physical-device, and live-host proof boundaries before archive
