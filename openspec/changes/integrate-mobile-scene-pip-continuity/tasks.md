## 1. Mobile scene, geometry, and continuity foundation

- [x] 1.1 Inventory the current UIKit surface, SwiftUI scenePhase adapter, renderer/input geometry ownership, decoded-frame source, audio continuity state, AVKit/CoreMedia/UIKit SDK APIs, generator configuration, and physical proof limits without changing runtime behavior
- [x] 1.2 Define immutable mobile attachment, scene activity, window/view geometry, safe-area, trait, scale, drawable, display, generation, and semantic-revision contracts with finite bounds and closed validation
- [x] 1.3 Define immutable PiP capability, controller lifecycle, frame-sink, continuity-path, restoration, failure, and generation snapshots plus deterministic state reducers
- [x] 1.4 Define mobile EDR capability/headroom normalization and display-revision contracts that extend the existing HDR display/render identity without global-screen fallback
- [x] 1.5 Add deterministic normalization, revision overflow, duplicate event, invalid geometry/headroom, policy-grid, state-transition, restoration lease, privacy, and finite-capacity tests

## 2. Actual UIKit scene and window runtime

- [x] 2.1 Extend the mobile `MTKView` surface with an injectable attachment callback boundary for `didMoveToWindow`, layout, safe-area, and registered trait changes
- [x] 2.2 Implement a main-actor current-generation scene/window attachment owner that derives `UIWindowScene`, `UIWindow`, and `UIScreen` only from the actual stream view
- [x] 2.3 Observe the attached scene's activate, deactivate, foreground, and background notifications with scene identity filtering, deduplication, cancellation, and stale-generation rejection
- [x] 2.4 Continuously publish normalized iPhone/iPad view/window geometry, scale, safe area, orientation, traits, drawable size, and resize-settled semantics
- [x] 2.5 Bind the same mobile geometry revision to `MTKView.drawableSize`, video fit/fill mapping, and touch/absolute-pointer input suppression or conversion
- [x] 2.6 Add attachment, multi-scene filtering, resize sequence, rotation, safe-area, trait, invalid geometry, replacement, late callback, teardown, renderer, and input mapping tests

## 3. Mobile display and EDR runtime

- [x] 3.1 Implement an injectable actual-window `UIScreen` EDR reader with finite bounded potential/current headroom and typed detached, SDR, EDR, and invalid states
- [x] 3.2 Observe attached-screen mode and brightness changes plus foreground, trait, and view/window attachment resampling without deprecated global screen-connect notifications
- [x] 3.3 Connect mobile display revisions to the existing `HDRDisplaySnapshot`, render configuration identity, `MetalStreamSurface`, and current-generation stale-frame checks
- [x] 3.4 Implement atomic EDR-to-SDR fallback, screen-move reconfiguration, duplicate suppression, revision exhaustion, and idempotent observer teardown
- [x] 3.5 Add window-screen ownership, headroom normalization, notification filtering, screen move, foreground restore, render-mode transition, stale frame, and resource-release tests

## 4. Native Picture in Picture runtime

- [x] 4.1 Define an injectable PiP controller/content-source/playback-delegate client boundary that keeps AVKit objects on the main actor and emits bounded semantic events
- [x] 4.2 Implement a bounded current-generation `CVPixelBuffer` to `CMSampleBuffer` adapter that preserves timing and color attachments without copying or creating another decoder
- [x] 4.3 Implement the `AVSampleBufferDisplayLayer` sink with readiness backpressure, latest-compatible-frame capacity, format/discontinuity flush, failure recovery, and pixel-buffer release
- [x] 4.4 Implement the production `AVPictureInPictureController.ContentSource(sampleBufferDisplayLayer:playbackDelegate:)` adapter and actual possibility observation
- [x] 4.5 Implement generation-scoped prepare, request-start, confirmed-active, request-stop, confirmed-stop, failed-start, restore-interface, skip/playback, invalidation, and replacement state handling
- [x] 4.6 Subscribe PiP to the existing decoded-frame presentation source and coordinate foreground Metal pause/throttle/resume without duplicating decode work
- [x] 4.7 Add controller event-order, possible/unavailable, start/failure/stop, exactly-once restore, skip completion, playback delegate, backpressure, stale frame/callback, replacement, teardown, and retain-release tests

## 5. Background continuity and application integration

- [x] 5.1 Refine mobile continuity policy to require actual current-generation PiP or permitted active audio state instead of capability/configuration presence alone
- [ ] 5.2 Integrate scene, audio, PiP, foreground renderer, decoder/control continuation, pause/stop, and foreground restoration through one serialized mobile media generation owner
- [ ] 5.3 Generate and verify the narrow iOS/iPadOS playback background-mode configuration while keeping configuration, signed acceptance, and runtime behavior as separate evidence
- [ ] 5.4 Route current scene/geometry/PiP/continuity/mobile-EDR state and bounded diagnostics through `NativeSessionMediaEnvironment` and `AppModel`, clearing actual state on stop/failure/replacement
- [ ] 5.5 Add accessible native PiP commands, actual scene/PiP/background/HDR status, continuity settings, compact/wide layouts, localization-safe copy, and preference migration
- [ ] 5.6 Add policy-loss-in-background, audio-only, active-PiP, foreground restore, media replacement, diagnostic ownership, UI actual-state, accessibility, localization, migration, and clean-stop tests

## 6. Verification and acceptance

- [ ] 6.1 Run normal tests with live-host and real-Keychain opt-ins disabled and verify the only permitted skip remains the explicit real-Keychain test
- [ ] 6.2 Build macOS, fixed iPhone, fixed iPad, tvOS, and visionOS Debug/Release with Swift, Clang, and Metal warnings as errors using isolated DerivedData/result bundles
- [ ] 6.3 Run OpenSpec strict, fixture, generator stability, source/test membership, clean-room/reference/license, generated plist, privacy, API availability, static analyzer, and repository-boundary gates
- [ ] 6.4 Run ASan, TSan, malloc scribble/guard, PiP frame/backpressure release, scene/screen observer cancellation, generation replacement, and restoration-completion resource gates
- [ ] 6.5 Verify fixed iPhone 17 Pro and iPad Pro 13-inch (M5) simulator identity and single-instance inventory, then run only the bounded simulator build/UI checks required by this change without creating or cloning devices
- [ ] 6.6 On authorized physical iPhone/iPad hardware, verify signed background configuration, system PiP start/stop/restore, background audio and duration, interruption/recovery, Stage Manager resize, rotation, external display, input mapping, mobile EDR/visible HDR, spatial audio coexistence, live Sunshine, power/thermal behavior, and clean teardown
- [ ] 6.7 Synchronize OpenSpec, runtime contracts, roadmap, `task_plan.md`, `findings.md`, and `progress.md`; record offline, simulator, signed-build, physical-device, and live-host proof boundaries before archive
