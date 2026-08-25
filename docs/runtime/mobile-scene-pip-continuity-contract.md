# Mobile scene, Picture in Picture, and EDR runtime contract

This document is the stage 17 source of truth for iOS/iPadOS stream-surface
ownership, continuous window geometry, Picture in Picture, legal background
continuity, and mobile EDR integration.

It records the starting inventory before runtime implementation. A source type,
an Info.plist key, a successful compile probe, or a simulator build is not proof
that a physical device entered PiP, remained active in the background, rendered
visible HDR, or mapped input correctly under Stage Manager.

## Scope and proof tiers

Stage 17 uses five separate proof tiers:

1. **Contract and static proof**: value semantics, source membership, public API
   availability, privacy bounds, and deterministic reducers.
2. **Build proof**: the generated project compiles with warnings as errors for
   the required platform and configuration.
3. **Simulator proof**: fixed identity, state, and build compatibility, plus an
   explicitly selected UI or lifecycle path only when a real simulator test
   target exists. This does not prove physical media policy.
4. **Signed artifact proof**: the built application contains the intended
   background configuration and provisioning accepts it.
5. **Physical and live proof**: the system presents PiP, applies real
   background policy, tracks a real resizable window or external display,
   produces visible HDR/EDR, maps input correctly, streams from Sunshine, and
   tears down without residual work.

No lower tier may be reported as a higher tier.

## Baseline inventory

### Product path

| Concern | Current source | Current behavior | Stage 17 gap |
|---|---|---|---|
| Mobile stream surface | `MetalStreamSurface` mobile `UIViewRepresentable` and iOS-only `MobileStreamMetalView` in `Sources/LuneXRendering/MetalStreamSurface.swift` | Installs `StreamMetalPresenter`, owns generation-scoped actual `UIWindow`/`UIWindowScene`/`UIScreen` attachment, publishes normalized geometry/drawable/input and attached-screen EDR revisions, and emits bounded lifecycle callbacks | Physical Stage Manager, external-display, visible EDR, and touch behavior remain unproved |
| SwiftUI lifecycle | `RootView` and the mobile surface callbacks | Routes actual surface attachment, scene lifecycle, normalized window snapshot, and display EDR events into the current `AppModel` media generation; synthetic `ScenePhase` is not the mobile ownership source | Physical multiwindow/background restoration remains pending |
| macOS lifecycle reference | `AppKitLifecycleMonitor`, `MacStreamSurfaceAttachmentOwner`, and `MacStreamInputCaptureView` | Actual window/surface ownership, occlusion/focus, backing pixels, screen EDR, stale attachment rejection, render policy, and input admission are connected | This is a behavioral reference, not reusable UIKit code |
| Coordinate contract | `StreamCoordinateSnapshotPublisher`, `StreamVideoRectangleResolver`, and `InputMapper` | Mobile normalized geometry publishes the same revision used by `MTKView.drawableSize`, fit/fill rendering, touch/absolute mapping, invalid-geometry suppression, and remote reference size | Physical rotation, Stage Manager, and external-display mapping remain unproved |
| Touch and hover mapping | `TouchInputAdapter` | Consumes current-generation `InputMapper`, rejects invalid or letterboxed samples, and carries the actual source reference size | Physical touch, pencil, hover, and external pointer acceptance remains pending |
| Renderer | `StreamMetalPresenter`, `HDRMetalVideoRenderer`, and `CVMetalVideoFrameMapper` | One decoded frame is mapped under the actual mobile geometry/display revision; EDR changes participate in current-generation render identity and stale-frame rejection | Visible mobile EDR/HDR and power behavior require physical evidence |
| Current decoded frame | `StreamVideoPresentationSource` | Owns current session/media/decoder generations and feeds foreground Metal plus one bounded generation-filtered PiP subscription without another decoder | System PiP presentation remains unproved on hardware |
| Decoded frame payload | `DecodedVideoFrame` and `MobilePictureInPictureSampleBufferAdapter` | Preserves the existing pixel buffer, timing, and color attachments while creating a bounded PiP sample-buffer view | Physical color/timing behavior remains unproved |
| Continuity policy | `MobileContinuityPolicyResolver`, `MobileContinuityPathResolver`, and `MobileMediaGenerationOwner` | One serialized generation/revision owner resolves and applies foreground, PiP, audio-only, suspend, pause, or stop from actual current PiP/audio state and configuration eligibility | Background duration and system policy acceptance remain physical proof |
| PiP state | Native PiP lifecycle and presentation coordinators plus the `AppModel` command bridge | Owns content source, playback delegate, possibility/start/stop/failure/restore state, sample layer/sink, generation replacement, bounded callbacks, and generation-checked native start/stop requests | System presentation remains physical task 6.6 proof |
| Audio session | `MobileAudioSessionAdapter`, `AVAudioEngineClient`, and `NativeSessionAudioProcessor` | Carries actual mobile activation readback into `SessionAudioRuntimeEvent`, composes mobile policy pause/resume with interruption/media-services recovery, and feeds continuity state | Audible background continuity and route behavior remain physical proof |
| Media ownership | `NativeSessionMediaEnvironment` | Owns one mobile media owner/action client per media generation, serializes application reservations, publishes actual runtime events/snapshots, gates input/control, and includes mobile stop in shared teardown; policy loss, PiP, audio-only, foreground restore, replacement, and clean-stop regression coverage is complete | 6.x runtime acceptance remains pending |
| App state | `AppModel` and `MobileExperiencePresentationStatusResolver` | Owns current mobile scene/geometry, attached-screen EDR, PiP, actual audio activity, continuity result, bounded diagnostics, revision application, stop/failure/replacement clearing, typed actual-state projection, generation-checked PiP commands, and replacement diagnostic ownership | Physical behavior remains pending |
| Native UI | `StreamWorkspaceView` and `SettingsView` | Shows accessible native PiP start/stop progress, actual scene/PiP/background/mobile-EDR status, spatial-audio status, and separate continuity preference controls with compact/wide fallbacks; deterministic actual-state/accessibility/localization regression coverage is complete | Physical system behavior remains pending |

### Generator and configuration

`Tools/generate_xcodeproj.rb` is the only project-membership authority.

- `LuneX-iOS` targets device families `1,2`, deployment target 26.0, and both
  `iphoneos` and `iphonesimulator`.
- iPhone and iPad orientation declarations are generated.
- `Configuration/Info/LuneX-iOS.plist` supplies the iOS/iPadOS
  `UIBackgroundModes` string array with the single `audio` value. The generated
  project references that source plist in both iOS configurations.
- macOS, tvOS, and visionOS do not receive a stage 17 background-mode
  declaration. Their product-specific background requirements remain owned by
  their later platform stages.
- The iOS entitlement file currently requests the stage 16 head-pose
  entitlement. It does not grant PiP or prove background execution.
- AVKit remains platform-owned: iOS `AppModel` and the PiP bridge/coordinators
  import or call it only behind iOS availability boundaries; shared mobile
  runtime values contain no UIKit or AVKit objects.
- New source and test files must be added to both the product `sources` and the
  test-support membership arrays where their contracts are compiled into
  `LuneXCoreTests`.

The `audio` background declaration is configuration intent only. Stage 17
separately verifies the source plist, generated project, unsigned built plist,
signed artifact acceptance, actual audio-session activation, actual PiP
callback state, and physical background behavior. No lower tier substitutes
for a later tier.

## Reusable runtime contracts

Stage 17 must extend these contracts instead of replacing them:

- `StreamCoordinateSnapshotPublisher` is the sole fit/fill drawable/source
  revision contract.
- `InputMapper` is the sole local drawable to remote source-point mapping
  contract.
- `PlatformLifecycleState` and `SessionLifecycleDirectiveResolver` remain the
  renderer/video/input lifecycle policy boundary, but mobile needs a richer
  normalized input snapshot and generation owner.
- `HDRDisplaySnapshotPublisher` remains the display revision contract.
- `HDRRenderConfigurationIdentity`, `HDRFrameRenderBinding`, and
  `StreamMetalPresenter` remain the decoded-frame/display compatibility and
  actual presentation contracts.
- `StreamVideoPresentationSource` remains the current decoder-frame ownership
  authority. A PiP subscription must not bypass its session/media/decoder
  checks.
- `NativeSessionMediaEnvironment` remains the expensive session resource owner.
- `AppModel` remains the main-actor current application-state owner and must
  accept only active-generation events.
- `DiagnosticStore` continues stable code, fixed summary, scoped recovery, and
  bounded-history behavior.

## Mobile scene/window value foundation

OpenSpec task 1.2 adds
`Sources/LuneXPlatform/MobileSceneWindowState.swift` as a platform-neutral,
immutable contract. It imports Foundation only and does not connect runtime
behavior.

The contract defines:

- nonzero `MobileSceneSurfaceGeneration` and `MobileDisplayGeneration` values;
- checked `MobileSceneWindowRevision`;
- closed orientation, size-class, and interface-style enums;
- finite view/window rectangles and safe-area insets;
- an attached raw sample with semantic activity, opaque display generation,
  geometry, scale, orientation, and traits;
- normalized `attached`, `detached`, and privacy-bounded
  `unavailable(reason:)` states; and
- a publisher fixed to one surface generation.

The normalizer bounds rectangle origins and endpoints to `1,000,000` points,
individual dimensions to `131,072` points, scale to `0 < scale <= 16`, and
drawable dimensions to `1,048,576` pixels. Insets must be finite, nonnegative,
individually bounded, and fit inside the view bounds. Drawable pixels are
derived from view points multiplied by scale and rounded
`toNearestOrAwayFromZero` before checked `Int` conversion.

Invalid samples do not retain the prior renderable geometry. They publish one
closed unavailable state with a stable reason:

- invalid display generation;
- invalid view bounds;
- invalid window bounds;
- invalid safe-area insets;
- invalid scale; or
- drawable-size overflow.

Equivalent valid, detached, or unavailable states do not advance the revision.
Recovery from unavailable state publishes a new revision. Revision overflow
clears the snapshot, marks the publisher exhausted, and remains closed.

The snapshot carries no UIKit object, `ObjectIdentifier`, scene/window/display
name, host identity, endpoint, or localized error text. Later UIKit tasks must
map actual platform objects into this contract on the main actor.

Task 1.2 evidence:

```text
Focused:
/tmp/LuneX-17-1_2-focused-final.rszp6V
10 passed / 0 skipped / 0 failed

Full macOS:
/tmp/LuneX-17-1_2-full-final.ZAkxIp
731 total / 730 passed / 1 explicit Keychain skip / 0 failed

Four generic Debug targets:
/tmp/LuneX-17-1_2-builds-final.D8zUzY
macOS, iOS/iPadOS, tvOS, visionOS succeeded with zero structured diagnostics

Read-only simulator inventory:
/tmp/LuneX-17-1_2-simulator.Dh14B0
fixed iPhone/iPad present exactly once; Booted = 0
```

These results prove the shared value contract and platform compilation only.
They do not prove UIKit attachment, Stage Manager resize, PiP, background
continuity, mobile EDR, physical input mapping, or live Sunshine behavior.

## PiP and continuity value foundation

OpenSpec task 1.3 adds
`Sources/LuneXPlatform/MobilePictureInPictureState.swift` as a
platform-neutral, immutable state contract. It imports Foundation only and
does not create an AVKit controller, sample-buffer layer, frame subscription,
audio session, or background runtime.

The contract defines:

- a nonzero media/PiP generation pair and checked semantic revision;
- closed `unknown`, `unavailable(reason:)`, and `possible` capability states;
- controller lifecycle from unprepared through preparing, ready,
  request/start/active, request/stop/stopped, failed, and invalidated;
- stable capability, controller, frame-sink, playback, and restoration failure
  classes without raw AVKit error text;
- a frame-sink snapshot that accepts only a nonzero decoder generation and at
  most one pending frame;
- a generation-bound, checked-ordinal restoration lease with pending,
  completed, and invalidated states;
- typed native start/stop, restoration completion, flush, and release effects;
  and
- actual `inactive`, `foreground`, `pictureInPicture`, `audioOnly`, or
  `unavailable` continuity paths.

The PiP reducer accepts only the configured generation. A start request can
emit a native-start effect, but lifecycle becomes active only after the native
`didStart` event. Controller capability or content-source configuration never
invents active state. Capability or sink changes during native startup do not
invalidate a later current-generation `didStart`; once active, a capability
loss records truthful availability without inventing a native-stop callback.

Restoration completion is produced only for the matching pending lease.
Duplicate or stale completion cannot mutate the current snapshot. Invalidation
completes a pending restoration as false, flushes and releases the sink, and
makes later events inert. Revision overflow clears the snapshot, permanently
fails closed, and emits cleanup effects only; a start or restore effect from
the event that exhausted the revision is not allowed to escape.

The continuity resolver requires an active stream and background scene before
considering media continuity. PiP continuity requires all of:

- an enabled PiP preference;
- native-confirmed active PiP lifecycle;
- an operational current frame sink; and
- the playback background declaration.

Audio-only continuity requires an enabled preference, an actually active audio
session, explicit continuity permission, and the same background declaration.
PiP has priority when both actual paths are active. Capability, configuration,
or preference presence alone does not produce continuity. Equivalent
resolutions are deduplicated, stale generations are ignored, and revision
overflow clears the published path.

Task 1.3 evidence:

```text
Focused:
/tmp/LuneX-17-1_3-focused-r3.3Mbkb9
15 passed / 0 skipped / 0 failed

Expanded:
/tmp/LuneX-17-1_3-expanded.z64xdg
32 passed / 0 skipped / 0 failed

Full macOS:
/tmp/LuneX-17-1_3-full.nw8ngg
746 total / 745 passed / 1 explicit Keychain skip / 0 failed

Four generic Debug targets:
/tmp/LuneX-17-1_3-builds.Acgnna
macOS, iOS/iPadOS, tvOS, visionOS succeeded with zero structured diagnostics

Read-only simulator inventory:
fixed iPhone/iPad present exactly once, available and Shutdown; Booted = 0
```

These results prove the Foundation value/state contracts, deterministic
reducers, generation/revision behavior, exact test coverage, and four-platform
compilation. They do not prove an `AVPictureInPictureController`,
`AVSampleBufferDisplayLayer`, system PiP, legal background duration, active
mobile audio continuity, signed configuration, Stage Manager, mobile EDR,
physical hardware, or live Sunshine behavior.

## Mobile EDR value foundation

OpenSpec task 1.4 adds
`Sources/LuneXPlatform/MobileDisplayEDRState.swift`. It is a platform-neutral
value boundary that accepts readings already derived from the actual attached
window screen. It does not import UIKit, select a screen, observe
notifications, mutate a Metal surface, or claim physical EDR output.

The publisher is fixed to one nonzero `MobileSceneSurfaceGeneration`. Each
attached reading carries the 1.2 `MobileDisplayGeneration` raw value plus
potential and current headroom. A stale surface generation is rejected without
normalization, revision change, or snapshot mutation. Changing the display
generation publishes a new revision even when headroom is unchanged.

Headroom normalization shares
`HDRLuminanceMapping.maximumCurrentHeadroom == 64.0`:

- values must be finite and in `0...64`;
- subunit values normalize conservatively to `1.0`;
- current headroom must not exceed potential headroom after normalization; and
- potential above one means EDR-capable, while current headroom remains a
  separate actual render bound.

Invalid display generation, potential headroom, current headroom, or
current-greater-than-potential produces a typed conservative-SDR fallback.
The fallback retains at most a valid opaque display generation and a closed
reason; it never retains NaN, infinity, an out-of-range number, object
description, hardware name, or global-screen value. Equivalent invalid
payloads reduce to one semantic state and do not churn revisions.

Available and conservative-fallback states derive an existing
`HDRDisplaySnapshot` with the exact mobile `HDRDisplayRevision`,
`DisplayHeadroom`, and `displayID: nil`. Unknown, detached, and unavailable
states publish no render snapshot. This allows the later production adapter to
use the established HDR render identity while keeping actual screen identity
inside the main-actor owner. Revision overflow clears both mobile and render
snapshots and remains closed.

Task 1.4 evidence:

```text
Focused:
/tmp/LuneX-17-1_4-focused-final.Y6tFJ8
10 passed / 0 skipped / 0 failed

Expanded mobile/display/HDR matrix:
/tmp/LuneX-17-1_4-expanded.7sN4P7
55 passed / 0 skipped / 0 failed

Full macOS:
/tmp/LuneX-17-1_4-full.SQ2yAU
756 total / 755 passed / 1 explicit Keychain skip / 0 failed

Four generic Debug targets:
/tmp/LuneX-17-1_4-builds.yyaIVE
macOS, iOS/iPadOS, tvOS, visionOS succeeded with zero structured diagnostics

Read-only simulator inventory:
fixed iPhone/iPad present exactly once, available and Shutdown; Booted = 0
```

These results prove normalization, semantic revision, privacy-safe render
snapshot bridging, generation rejection, fail-closed overflow, and
four-platform compilation. They do not prove that a UIKit adapter read an
actual `UIScreen`, observed headroom changes, reconfigured a live Metal
surface, presented visible EDR, moved across displays, or ran on physical
hardware.

## Foundation deterministic coverage

OpenSpec task 1.5 expands the three platform-neutral foundation suites without
changing production runtime behavior. The coverage includes:

- every finite geometry failure class, inclusive coordinate limits, bounded
  endpoints, equivalent invalid-payload privacy convergence, semantic
  duplicate suppression, recovery, and revision exhaustion;
- the complete legal PiP controller lifecycle, precise closed rejection from
  the unprepared state, capability/frame-sink duplicates, concurrent
  restoration rejection, checked restoration lease ordinals, exactly-once
  completion, capacity boundaries, and cleanup-only revision exhaustion;
- all 3,840 combinations of platform, activity, stream ownership, actual PiP
  lifecycle/sink state, actual permitted audio state, background
  configuration, and user preferences with closed precedence; and
- mobile EDR subunit normalization, invalid raw-value privacy convergence,
  unavailable-state deduplication, display replacement, maximum revision, and
  typed conservative-SDR exhaustion.

Task 1.5 evidence:

```text
Focused foundation suites:
/tmp/LuneX-17-1_5-focused-final.viWjAE
51 passed / 0 skipped / 0 failed

Full macOS:
/tmp/LuneX-17-1_5-full.YQ8HXp
772 total / 771 passed / 1 explicit Keychain skip / 0 failed

Four generic Debug targets:
/tmp/LuneX-17-1_5-builds.yraPq0
macOS, iOS/iPadOS, tvOS, visionOS succeeded with zero structured diagnostics

Repository and read-only simulator gate:
/tmp/LuneX-17-1_5-repository.gMZ1oo
OpenSpec strict passed; generator stable; privacy and membership passed;
fixed iPhone/iPad available and Shutdown; Booted = 0
```

All normal tests explicitly removed `LUNEX_RUN_KEYCHAIN_TEST`; the only full
suite skip is the explicit real-Keychain opt-in test. These results prove
deterministic value contracts and compilation only. They do not prove an
actual UIKit attachment callback, `UIWindowScene` or `UIScreen` ownership,
Stage Manager resize, an AVKit controller or sample-buffer sink, system PiP,
background duration, active mobile audio continuity, live Metal EDR
reconfiguration, a signed artifact, physical hardware, or live Sunshine.

## Mobile surface attachment callback boundary

OpenSpec task 2.1 replaces the plain iOS `MTKView` with the iOS-only
`MobileStreamMetalView`. tvOS and visionOS continue to construct the prior
plain `MTKView`, so this task does not change their runtime behavior.

The view publishes only four closed semantic events:

- `didMoveToWindow`;
- `layoutSubviews`;
- `safeAreaInsetsDidChange`; and
- `registeredTraitsChanged`.

The registered trait set is horizontal size class, vertical size class, display
scale, and interface style. The main-actor relay weakly owns the surface,
allows SwiftUI updates to replace the handler, and permanently rejects handler
replacement or event delivery after invalidation. Events carry the actual view
only to the injected main-actor handler; they do not publish a raw window,
scene, screen, trait collection, geometry, object identity, or notification
payload into shared state.

`MetalStreamSurface.makeUIView` installs the callback, `updateUIView` replaces
the handler, and `dismantleUIView` unregisters the trait token before
invalidating the relay and stopping the presenter. Task 2.2 must consume this
boundary through a current-generation owner; task 2.1 deliberately does not
derive or retain `UIWindow`, `UIWindowScene`, or `UIScreen`.

Task 2.1 evidence:

```text
Focused relay tests:
/tmp/LuneX-17-2_1-focused-r2.eXTz63
2 passed / 0 skipped / 0 failed

Expanded presenter suite:
/tmp/LuneX-17-2_1-expanded.ozkc9S
28 passed / 0 skipped / 0 failed

Post-update full macOS:
/tmp/LuneX-17-2_1-post-update.4S4rH3
774 total / 773 passed / 1 explicit Keychain skip / 0 failed

Post-update four generic Debug targets:
/tmp/LuneX-17-2_1-builds-post-update.UWtmEU
macOS, iOS/iPadOS, tvOS, visionOS succeeded with zero structured diagnostics

Post-update read-only simulator inventory:
/tmp/LuneX-17-2_1-simulator-post-update.rUDTIT
fixed iPhone/iPad present exactly once, available and Shutdown; Booted = 0
```

All normal tests explicitly removed `LUNEX_RUN_KEYCHAIN_TEST`. These results
prove relay ownership/replacement/invalidation, iOS API compilation, and
cross-platform build isolation. They do not prove a callback fired in a live
UIKit window, actual scene/window/screen ownership, Stage Manager resizing,
geometry/drawable/input publication, PiP, background continuity, mobile EDR,
a signed artifact, physical hardware, or live Sunshine.

## Current-generation actual UIKit attachment owner

OpenSpec task 2.2 adds a main-actor owner fixed to one nonzero
`MobileSceneSurfaceGeneration` and one stream-surface identity. A checked
main-actor sequence assigns a new generation to each iOS
`MobileStreamMetalView`; after `UInt64` exhaustion it returns no owner instead
of wrapping to an old generation.

The production resolver follows exactly this chain:

```text
MobileStreamMetalView
  -> view.window
    -> window.windowScene
    -> window.screen
```

If the window or its window scene is absent, the result is detached. The owner
does not read `UIScreen.main`, enumerate `connectedScenes`, accept a synthetic
SwiftUI phase, or infer attachment from another view.

The owner:

- accepts callbacks only for its exact surface generation and surface object;
- weakly retains the surface, window, scene, and screen;
- synchronously emits actual UIKit objects only to a main-actor injected
  handler;
- replaces the handler during SwiftUI updates without changing ownership;
- emits an invalidated transition during dismantle, clears all weak references,
  and rejects late or repeated work; and
- leaves notification ownership, semantic lifecycle state, normalized
  geometry, display revisions, and actor publication to later tasks.

The raw UIKit attachment update is deliberately not `Sendable`. A later adapter
must convert it into the immutable privacy-bounded contracts before crossing an
actor boundary, persisting state, recording diagnostics, or displaying UI.

Task 2.2 evidence:

```text
Focused relay/owner tests:
/tmp/LuneX-17-2_2-focused.tjvteD
5 passed / 0 skipped / 0 failed

Expanded presenter suite:
/tmp/LuneX-17-2_2-expanded.5sWe4b
31 passed / 0 skipped / 0 failed

Full macOS:
/tmp/LuneX-17-2_2-full.dOhBLh
777 total / 776 passed / 1 explicit Keychain skip / 0 failed

Four generic Debug targets:
/tmp/LuneX-17-2_2-builds.PpGqRf
macOS, iOS/iPadOS, tvOS, visionOS succeeded with zero structured diagnostics

Read-only simulator inventory:
/tmp/LuneX-17-2_2-simulator.5RvcxU
fixed iPhone/iPad present exactly once, available and Shutdown; Booted = 0
```

These results prove deterministic generation/surface rejection,
replacement/detach derivation, invalidation, weak ownership, iOS public API
compilation, and cross-platform isolation. They do not prove a callback fired
in a live UIKit window, scene notification filtering, Stage Manager resizing,
geometry/drawable/input publication, PiP, background continuity, mobile EDR,
a signed artifact, physical hardware, or live Sunshine.

## Attached-scene lifecycle observer

OpenSpec task 2.3 adds a main-actor lifecycle observer fixed to the same
nonzero `MobileSceneSurfaceGeneration` as the actual attachment owner. The iOS
view attaches it only to `view.window?.windowScene`; detached attachment
updates stop observation instead of selecting another application scene.

The observer maps current UIKit state and notifications into a closed semantic
stream:

- initial `foregroundActive` becomes `active`;
- initial `foregroundInactive` becomes `inactive`;
- initial `background` or `unattached` becomes conservative `background`;
- `didActivate` becomes `active`;
- `willDeactivate` and `willEnterForeground` become `inactive`; and
- `didEnterBackground` becomes `background`.

Each attachment receives a private UUID token in addition to its surface
generation. NotificationCenter registers all four tokens with the actual scene
as the object filter. Replacement, detach, and invalidation remove every token
before clearing the weak scene reference. A queued main-actor delivery must
still match the current UUID, current generation-owned observer, a live scene,
and noninvalidated state before publication. Equivalent activity repeats are
deduplicated; replacing the scene publishes its initial state even when the
semantic activity matches the prior scene.

The platform-neutral update carries only the surface generation and
`attached(activity)`, `detached`, or `invalidated`. It does not carry or persist
the scene, notification, object identity, raw activation state, or description.
The observer and actual UIKit handler remain main-actor isolated. A narrow
private token store performs idempotent explicit removal and deinit fallback
without weakening Swift 6 concurrency checking for the rest of the file.

Task 2.3 evidence:

```text
Focused lifecycle tests:
/tmp/LuneX-17-2_3-focused-r2.MJ6961
3 passed / 0 skipped / 0 failed

iOS generic-device API build:
/tmp/LuneX-17-2_3-ios-build.ULp392
succeeded with zero structured diagnostics

Expanded presenter suite:
/tmp/LuneX-17-2_3-expanded.vyNEJV
34 passed / 0 skipped / 0 failed

Full macOS:
/tmp/LuneX-17-2_3-full.sYEcAe
780 total / 779 passed / 1 explicit Keychain skip / 0 failed

Four generic Debug targets:
/tmp/LuneX-17-2_3-build-macOS.UJWiu0
/tmp/LuneX-17-2_3-build-iOS.OGkriA
/tmp/LuneX-17-2_3-build-tvOS.zRSzBF
/tmp/LuneX-17-2_3-build-visionOS.NkirqG
macOS, iOS/iPadOS, tvOS, visionOS succeeded with zero structured diagnostics

Read-only simulator inventory:
/tmp/LuneX-17-2_3-simulator.P2aGEm
fixed iPhone/iPad present exactly once, available and Shutdown; Booted = 0
```

All normal tests explicitly removed `LUNEX_RUN_KEYCHAIN_TEST`. These results
prove deterministic scene filtering, semantic deduplication, replacement,
detach/invalidation cancellation, queued-late rejection, iOS public API
compilation, and cross-platform isolation. They do not prove notifications
fired in a live UIKit window, foreground restoration resampled all state,
Stage Manager geometry, drawable/input mapping, PiP, legal background
continuity, mobile EDR, signed configuration, physical hardware, or live
Sunshine.

## Xcode 26.4 public API inventory

The inventory was verified against Xcode 26.4 build `17E192`, Apple Swift 6.3,
and the iPhoneSimulator 26.4 public SDK with warnings as errors.

### Actual view, window, and scene

The actual mobile Metal view can provide:

- `UIView.didMoveToWindow()` for attach, detach, and window replacement;
- `UIView.layoutSubviews()` for continuous bounds changes;
- `UIView.safeAreaInsetsDidChange()` for inset changes;
- `view.window?.windowScene` for the owning scene;
- `view.window?.screen` for the owning display;
- `view.bounds`, `window.bounds`, `screen.nativeScale`, and
  `windowScene.interfaceOrientation` for normalized geometry; and
- `registerForTraitChanges` with `UITraitHorizontalSizeClass`,
  `UITraitVerticalSizeClass`, `UITraitDisplayScale`, and
  `UITraitUserInterfaceStyle`.

`traitCollectionDidChange` is not the stage 17 observation mechanism.

The current scene notifications are:

- `UIScene.didActivateNotification`;
- `UIScene.willDeactivateNotification`;
- `UIScene.didEnterBackgroundNotification`; and
- `UIScene.willEnterForegroundNotification`.

Every notification must be filtered to the attached `UIWindowScene`. Scanning
all `UIApplication.connectedScenes` or selecting an arbitrary active scene is
not permitted.

### Mobile display and EDR

The attached `UIScreen` exposes:

- `currentEDRHeadroom`;
- `potentialEDRHeadroom`;
- `UIScreen.modeDidChangeNotification`; and
- `UIScreen.brightnessDidChangeNotification`.

`UIScreen.didConnectNotification` and `didDisconnectNotification` are
deprecated under the iOS 26 warnings-as-errors build. Cross-screen changes are
detected by resampling `view.window?.screen` during actual view/window
attachment and lifecycle callbacks.

The current headroom is a render bound, not an HDR-stream flag. Potential
headroom is a capability, not a per-frame output target. Nonfinite, negative,
or unreasonably large values must close to typed SDR fallback.

### Sample-buffer Picture in Picture

The public PiP content path is:

```swift
let source = AVPictureInPictureController.ContentSource(
    sampleBufferDisplayLayer: layer,
    playbackDelegate: delegate
)
let controller = AVPictureInPictureController(contentSource: source)
```

The controller initializer is nonoptional. Runtime possibility is read from
`isPictureInPicturePossible`; controller construction is not proof of
possibility or activation.

`AVPictureInPictureSampleBufferPlaybackDelegate` requires playback state, time
range, render-size transition, and skip methods. Swift 6.3 imports the skip
completion as:

```swift
completion: @escaping @Sendable () -> Void
```

The protocol requirements are nonisolated. A main-actor production owner must
use an explicit Swift isolated conformance:

```swift
final class Delegate: NSObject,
    @MainActor AVPictureInPictureSampleBufferPlaybackDelegate
```

Annotating only the class with `@MainActor` fails Swift 6 strict concurrency.

### Sample-buffer creation and rendering

The existing decoded `CVPixelBuffer` can be wrapped without a second decoder:

- `CMVideoFormatDescriptionCreateForImageBuffer`;
- `CMSampleTimingInfo`; and
- `CMSampleBufferCreateReadyWithImageBuffer`.

The `AVSampleBufferDisplayLayer` is still the object passed to the PiP content
source, but its direct queued-rendering methods are deprecated on iOS 18 and
later. Stage 17 must use:

```swift
let renderer = layer.sampleBufferRenderer
renderer.isReadyForMoreMediaData
renderer.enqueue(sampleBuffer)
renderer.flush(removingDisplayedImage: true, completionHandler: ...)
```

The direct layer `isReadyForMoreMediaData`, `enqueue`, and
`flushAndRemoveImage` APIs fail the iOS 26 warnings-as-errors gate.

The successful strict public API probe is stored outside the repository at:

```text
/tmp/LuneX-17-1_1-api.IsXyyw
```

The probe typechecked with zero diagnostics and did not create, boot, install
to, launch, or otherwise operate a simulator.

### Shared decoded-frame delivery and foreground coordination

OpenSpec task 4.6 keeps `StreamVideoPresentationSource` as the only decoder
presentation authority. Foreground Metal continues to read `currentFrame()`;
PiP subscribes to the same source and receives the same `DecodedVideoFrame` and
`CVPixelBuffer`. The subscription path does not instantiate VideoToolbox,
allocate a replacement pixel buffer, or own a decoder.

The source enforces:

- at most eight cancellable subscribers;
- session and media-generation filtering before callback capture;
- a checked delivery revision independent from the lower-frequency semantic
  presentation revision;
- latest-frame replay for a matching newly attached consumer;
- callback invocation only after releasing the source lock; and
- terminal clear plus subscriber release when either revision space is
  exhausted.

`MobilePictureInPicturePresentationCoordinator` validates the session, media,
PiP and decoder generations plus strictly increasing delivery revision and
frame ID. It converts through the existing sample-buffer adapter and submits to
the existing single-slot display-layer sink. A separate single-slot mailbox
retains only the latest pending source delivery and schedules at most one
main-actor drain, so decode-rate callbacks cannot create an unbounded task or
frame queue.

Foreground presentation suppression is driven only by the reducer snapshot
that follows native `.didStart`. A start request and `.willStart` leave the
current Metal policy unchanged. While PiP is confirmed active, the documented
policy is either paused or throttled; lifecycle baseline changes are retained,
and stop, failure or invalidation restores the latest baseline. Task 4.6 does
not yet connect this coordinator to the serialized application media owner or
claim legal background continuation; those remain 5.x responsibilities.

### PiP cross-layer regression ownership

OpenSpec task 4.7 adds integration regressions without changing the production
PiP runtime. The presentation-level suite now proves:

- a native start failure never suppresses foreground Metal;
- playback state, interface restoration, skip, and render-size callbacks cross
  the presentation owner and complete each native callback lease exactly once;
- retained-latest, replaced-pending, and rejected sink outcomes map to bounded
  submitted/rejected counters without retaining a rejected sample;
- invalidation cancels the source subscription and pending mailbox delivery,
  clears retained samples, releases the old pixel buffer and coordinator, and
  leaves a captured old client handler inert after replacement; and
- the replacement generation alone receives the next decoded frame and cannot
  be marked active by a stale callback.

The focused suite passed `14/14`; the expanded PiP/media/Metal matrix passed
`162/162`; the complete macOS suite passed `866 total / 865 passed / 1 explicit
Keychain skip / 0 failed`; and the four generic Debug platform builds succeeded
with zero structured diagnostics. These are contract, test, and build proof.
They do not prove system PiP presentation, background duration, signing,
installation, physical-device behavior, or live Sunshine operation.

### Actual current-generation continuity policy

OpenSpec task 5.1 removes the capability-only application policy path.
`MobileContinuityContext` now carries an active PiP/media generation and an
optional `MobileContinuityActualMediaState` with native PiP lifecycle, frame
sink operation, audio-session activity, and explicit audio-continuity
permission.

Actual evidence is accepted only when its full generation equals the active
generation. Missing or stale generation, requested/starting/stopping PiP,
nonoperational PiP sink, inactive or denied audio, missing platform
capability, disabled preference, and missing playback declaration all fail
closed. Capability and generated configuration remain eligibility gates; they
cannot synthesize activity.

The application action resolver delegates to the existing
`MobileContinuityPathResolver`, preserving one precedence contract:

- inactive or foreground state remains foreground;
- confirmed active PiP with an operational sink takes priority;
- active and permitted audio selects audio-only continuity;
- missing declaration or actual path suspends foreground rendering when the
  reduction preference is enabled, otherwise it pauses the stream; and
- unsupported platforms return the bounded unsupported warning.

Task 5.1 evidence:

```text
Focused policy/PiP reducer:
/tmp/LuneX-17-5_1-focused-r2.OR9fN0/Focused.xcresult
38 passed / 0 skipped / 0 failed

Expanded policy/PiP/audio/media ownership:
/tmp/LuneX-17-5_1-expanded.WrwNk8/Expanded.xcresult
104 passed / 0 skipped / 0 failed

Full macOS:
/tmp/LuneX-17-5_1-full.3SUqwE/Full.xcresult
870 total / 869 passed / 1 explicit Keychain skip / 0 failed

Four generic Debug targets:
/tmp/LuneX-17-5_1-builds.bPoD3X
macOS, iOS/iPadOS, tvOS, visionOS succeeded with zero structured diagnostics
and one AIR plus one metallib per platform
```

These results prove the offline action-policy contract and platform
compilation only. They do not prove system PiP, background duration, signed
configuration, physical iPhone/iPad behavior, Stage Manager, visible EDR,
power, or live Sunshine.

### Serialized mobile media generation owner

OpenSpec task 5.2 adds `MobileMediaGenerationOwner`, a platform-neutral actor
that turns one generation/revision-scoped continuity input into one typed media
plan. Its input contains Sendable values only: media/PiP/session ownership,
semantic revision, actual scene and generation-matched PiP/audio state,
capability/preference/background eligibility, and the foreground render
baseline. UIKit, AVKit, Metal view, and audio-session objects remain outside
the actor on their platform owners.

The plan applies one closed set of foreground, video, audio, control, and
stream directives:

- foreground keeps the current render baseline and all media paths running;
- native-confirmed PiP suspends foreground Metal while decoder-to-PiP frame
  delivery, audio, control, and the stream continue;
- active and permitted audio-only continuity suspends foreground rendering and
  drains video transport without decoding while audio and control continue;
- losing the final legal background path suspends foreground rendering, drains
  video without decoding, and issues typed audio, control, and stream pause;
- explicit stop issues typed video/audio/control teardown and a stopped stream;
  and
- returning from a background path restores the latest foreground baseline and
  requests one `restoreAndResample`; later foreground revisions do not repeat
  restoration.

Actor isolation alone does not serialize reentrant asynchronous clients. The
owner therefore uses a FIFO operation gate around external action application.
After each awaited application it revalidates the reserved ownership and
revision before committing state. Duplicate inputs and higher-revision
semantically identical plans update state without repeating actions.
Replacement, stop, failed action rollback/retry, stale revision, stale
generation, and late completion all pass through the same owner and fail
closed.

Task 5.2 evidence:

```text
Focused owner/policy:
/tmp/LuneX-17-5_2-focused-final.uVo4ul/Focused.xcresult
22 passed / 0 skipped / 0 failed

Expanded scene/PiP/audio/lifecycle/media ownership:
/tmp/LuneX-17-5_2-expanded.nNWvVN/Expanded.xcresult
154 passed / 0 skipped / 0 failed

Full macOS:
/tmp/LuneX-17-5_2-full.d6TUCM/Full.xcresult
881 total / 880 passed / 1 explicit Keychain skip / 0 failed

Four generic Debug targets:
/tmp/LuneX-17-5_2-builds.XeS4Cp
macOS, iOS/iPadOS, tvOS, visionOS succeeded with zero structured diagnostics
and one AIR plus one metallib per platform

Repository pre-gate:
/tmp/LuneX-17-5_2-repository-pre.bOvRUF
fixtures, OpenSpec strict 8/8, pre-check 24/36 next 5.2, generator stability,
membership, platform-object isolation, reference boundary, and diff check pass
```

All ordinary tests explicitly removed `LUNEX_RUN_KEYCHAIN_TEST`; the only skip
is the opt-in real-Keychain round trip. No simulator was queried, created,
booted, or modified. These results prove the injectable serialized value/action
owner and four-platform compilation. Task 5.4 subsequently connects that owner
to platform adapters, `NativeSessionMediaEnvironment`, and `AppModel`; system
PiP, background duration, signed configuration, physical iPhone/iPad behavior,
Stage Manager, external display, visible EDR, power, and live Sunshine remain
unproved.

### Generated iOS/iPadOS playback background configuration

OpenSpec task 5.3 replaces the ineffective single-value
`INFOPLIST_KEY_UIBackgroundModes` settings with one iOS-specific source plist.
Apple defines `UIBackgroundModes` as an array of strings. The source and both
unsigned iPhoneOS Debug/Release products contain exactly:

```text
UIBackgroundModes = ["audio"]
UIDeviceFamily = [1, 2]
CFBundleSupportedPlatforms = ["iPhoneOS"]
```

The same device binary therefore carries the declaration for iPhone and iPad.
No location, VoIP, fetch, processing, notification, accessory, Bluetooth, or
other background mode is present. Xcode continues to generate and merge the
remaining bundle, version, platform, launch-screen, device-family, and
orientation keys. The generator records the plist as `text.plist.xml`, adds it
to the Configuration group, and references it only from `LuneX-iOS`.

The obsolete settings on tvOS and visionOS were removed because their actual
stage 16 products did not contain the key. Stage 17 does not silently broaden
their configuration; stage 18 must make and verify any platform-specific
background decision against those built products.

Task 5.3 evidence:

```text
iPhoneOS configuration probe:
/tmp/LuneX-17-5_3-config-probe.j3rZDL
source and Debug built UIBackgroundModes = ["audio"]

Unsigned build/configuration matrix:
/tmp/LuneX-17-5_3-build-matrix.LUMoL0
iPhoneOS Debug/Release and macOS/tvOS/visionOS Debug succeeded
validation-r3 proves exact iPhone/iPad plist and absence on other targets
all builds have zero structured diagnostics and AIR/metallib products

Full macOS:
/tmp/LuneX-17-5_3-full.iJCZfF/Full.xcresult
881 total / 880 passed / 1 explicit Keychain skip / 0 failed

Repository pre-gate:
/tmp/LuneX-17-5_3-repository-pre-r2.cCRbWz
fixtures, OpenSpec strict 8/8, pre-check 25/36 next 5.3, generator stability,
source/project/built configuration, build evidence, full result, and diff pass
```

All five application products in the matrix intentionally disabled code
signing. This proves source configuration, generated project ownership, and
unsigned built-plist content only. It does not prove that a provisioning
profile accepts the configuration. The declaration also does not prove an
active `.playback` audio session, system PiP, background execution or duration,
interruption recovery, physical-device behavior, or live Sunshine continuity.

### Application and media-environment integration

OpenSpec task 5.4 connects the actual mobile surface/media state to one current
application and media generation without moving UIKit or AVKit objects into
shared actors.

`SessionMobileRuntimeApplication` is the immutable Sendable boundary. It binds
session ID, media generation, mobile media/PiP generation, semantic revision,
actual scene/window geometry, attached-screen EDR, native PiP snapshot, actual
audio-session activation, continuity eligibility, user preferences, and the
foreground render baseline. Construction validates all generation relations;
missing, stale, exhausted, or inconsistent values fail closed.

`RootView` routes the actual iOS stream surface callbacks into `AppModel`.
`AppModel` accepts only its current stream/media/surface/decoder/PiP generation,
deduplicates monotonic scene/display/PiP revisions, creates one queued runtime
application, and publishes only a successfully applied state. Stop, launch
failure, reconnect, remote termination, media replacement, surface detach, and
revision exhaustion cancel pending work and clear scene, geometry, EDR, PiP,
audio, continuity, and diagnostic ownership before a replacement can publish.

`NativeSessionMediaEnvironment` reserves the application before awaiting the
external action owner, shares matching in-flight work, revalidates ownership
after every await, publishes `.mobileRuntime` only after action success, and
exposes the state in its bounded snapshot. The production action client applies
control/audio/video and input-release steps in a fixed order. Per-step progress
allows one bounded retry without repeating already successful effects. Pending
pause/stop and applied pause/stop both reject new remote input; the control
provider also rejects IDR requests while paused or stopped.

Video processing reconciles the existing platform lifecycle directive with the
mobile directive and allows same-application recovery after a failed resume.
Audio processing keeps mobile policy pause independent from system interruption
and media-services recovery, committing the application only after the pipeline
effect succeeds. Control, audio, and video providers all reject stale session,
media, generation, or revision applications.

Stop, failure, consumer cancellation, and same-session replacement atomically
register one shared teardown operation before any await. That operation first
stops the mobile owner and then tears down the resource tracker, so concurrent
callers cannot publish partial cleanup or reuse an old report. Immediate input
release and the input provider's idempotent teardown fallback remain distinct
ownership layers.

Diagnostics use stable scene, PiP, continuity, and mobile EDR codes with fixed
summaries and bounded history. They do not retain raw scene/window/display,
controller, sample-buffer, host, session-generation, or localized error values.

Task 5.4 evidence:

```text
Focused application/action/replacement/failure gate:
/tmp/LuneX-17-5_4-action-focused-final-r2.wUolwc/Focused.xcresult
18 passed / 0 skipped / 0 failed

Expanded 16-suite media/AppModel/PiP/scene/EDR/audio gate:
/tmp/LuneX-17-5_4-action-expanded-final-r2.U2uuha/Expanded.xcresult
301 passed / 0 skipped / 0 failed

Fresh complete macOS normal:
/tmp/LuneX-17-5_4-action-full-final.BwDZJ2/Full.xcresult
898 total / 897 passed / 1 explicit Keychain skip / 0 failed

Four generic Debug application builds:
/tmp/LuneX-17-5_4-action-builds-final.15Ul1N
macOS, iOS/iPadOS, tvOS, visionOS succeeded with zero structured diagnostics
and one AIR plus one metallib per platform
iOS UIBackgroundModes = ["audio"], UIDeviceFamily = [1, 2]

Repository gate before task marking:
/tmp/LuneX-17-5_4-action-repository-final-r2.Qziu2H
fixtures, OpenSpec strict 8/8, generator stability, compiler membership,
privacy/API/reference/dependency/license/plist/result/artifact/diff gates pass
```

All normal tests removed the real-Keychain opt-in and used the established
file/in-memory fallback. No simulator was queried, created, booted, or modified.
This is deterministic offline and unsigned generic-build proof. It does not
prove accessible PiP commands or status UI (5.5), the full policy-loss and
resource matrix (5.6), signed background acceptance, system PiP, background
duration, Stage Manager, rotation, external display, visible mobile EDR,
spatial-audio hardware behavior, power/thermal behavior, physical input, or
live Sunshine interoperability (6.x).

### Native actual-state UI and PiP commands

OpenSpec task 5.5 adds one platform-neutral presentation projection instead of
another PiP or continuity state machine. `MobileExperiencePresentationStatus`
derives scene, native PiP, continuity, and mobile-display states from the
current values already owned by `AppModel`. Active-session truth requires the
matching stream/media ownership still held during teardown; an enabled
preference never creates an actual active state.

The display projection distinguishes no session, unknown, detached, SDR,
EDR-capable, EDR-active, HDR-to-SDR fallback, invalid headroom, and
reconfiguration. EDR-active requires both an attached EDR-capable mobile
display and actual renderer status `.edr`. Numeric headroom shown to the user
is bounded to the runtime contract range `1...64`.

On iOS, `AppModel.performMobilePictureInPictureCommand` accepts a start or stop
only when the projected command is available and the coordinator, PiP snapshot,
and active media generation still match. It forwards to the existing
generation-owned coordinator and maps only its bounded outcome. Other platforms
return a typed unsupported result; no second `AVPictureInPictureController` or
decoder is created.

The stream overlay uses native `pip.enter`/`pip.exit` icon commands, a fixed
pending-stop progress control, tooltips, and explicit accessibility labels and
values. Settings separates three preference toggles from actual runtime rows.
Compact or accessibility text sizes use a vertical layout; wider layouts use a
two-column form and `ViewThatFits` falls back before content can overflow. Copy
uses static localizable resources and `Text` numeric interpolation.

`AppSettings` now migrates a missing `continuity` object to defaults, while
`ContinuityPreferences` migrates each missing field independently and preserves
every stored Boolean that was present. Malformed present values continue to
fail decoding rather than being silently accepted.

Task 5.5 evidence:

```text
Focused value, command availability, and migration gate:
/tmp/LuneX-17-5_5-focused.xrpILI/Focused.xcresult
9 passed / 0 skipped / 0 failed

Expanded AppModel/PiP/continuity/display/persistence gate:
/tmp/LuneX-17-5_5-expanded.4eDReh/Expanded.xcresult
220 total / 219 passed / 1 explicit Keychain skip / 0 failed

Fresh complete macOS normal:
/tmp/LuneX-17-5_5-full.AFYgqg/Full.xcresult
906 total / 905 passed / 1 explicit Keychain skip / 0 failed

Four generic Debug application builds:
/tmp/LuneX-17-5_5-build-macOS.GXj1up/Build.xcresult
/tmp/LuneX-17-5_5-build-iOS.MteT4o/Build.xcresult
/tmp/LuneX-17-5_5-build-tvOS.oCtGE5/Build.xcresult
/tmp/LuneX-17-5_5-build-visionOS.DzOKpU/Build.xcresult
All succeeded with zero errors, warnings, or analyzer warnings

Repository gate before task marking:
/tmp/LuneX-17-5_5-repository-pre-r3.CQDfTT
fixtures, OpenSpec strict 8/8, generator/compiler membership, UI contract,
privacy/API/reference/dependency/license/plist/result and diff gates pass
```

All ordinary tests explicitly removed `LUNEX_RUN_KEYCHAIN_TEST`; file/in-memory
fallback remained active. No simulator inventory or lifecycle operation was
performed. These results prove implementation, deterministic values, migration,
SDK compilation, and static accessible/localizable UI structure. They do not
prove the complete 5.6 transition matrix, system PiP presentation, signed
background acceptance, background duration, Stage Manager, rotation, external
display, visible EDR/HDR, physical input/spatial audio, power/thermal behavior,
or live Sunshine interoperability.

### Cross-layer continuity regression closure

OpenSpec task 5.6 closes the deterministic application/UI/persistence matrix
without adding another runtime owner. One `AppModel` sequence drives confirmed
PiP, audio-only continuity, loss of the last legal background path, foreground
restoration, clean stop, media-generation replacement, re-owned diagnostics,
and a second clean stop. It verifies that actual mobile state is cleared on
teardown, an unrelated decoder diagnostic remains actionable, and bounded
mobile diagnostics contain neither session UUIDs nor host names.

The UI regression checks that `RootView` consumes only
`mobileExperiencePresentationStatus`, keeps actual status separate from
preferences, preserves the native PiP commands, uses `ViewThatFits` and an
accessibility Dynamic Type fallback, supplies label/value semantics, and keeps
numeric EDR copy in localizable SwiftUI `Text` interpolation. Persistence
regression separately proves that missing fields migrate while a present field
with a malformed type fails closed.

Task 5.6 evidence:

```text
Focused cross-layer/UI/migration gate:
/tmp/LuneX-17-5_6-focused.3oZ597/Focused.xcresult
3 passed / 0 skipped / 0 failed

Expanded AppModel/owner/environment/UI/persistence/PiP/scene/EDR gate:
/tmp/LuneX-17-5_6-expanded.rMzx7g/Expanded.xcresult
246 total / 245 passed / 1 explicit Keychain skip / 0 failed

Fresh complete macOS normal:
/tmp/LuneX-17-5_6-full.vIdYY6/Full.xcresult
909 total / 908 passed / 1 explicit Keychain skip / 0 failed

Four generic Debug application builds:
/tmp/LuneX-17-5_6-build-macOS.Cx4asx/Build.xcresult
/tmp/LuneX-17-5_6-build-iOS.0SUvDM/Build.xcresult
/tmp/LuneX-17-5_6-build-tvOS.pgu2WY/Build.xcresult
/tmp/LuneX-17-5_6-build-visionOS.DrKxPQ/Build.xcresult
All succeeded with zero errors, warnings, or analyzer warnings

Repository gate before task marking:
/tmp/LuneX-17-5_6-repository-pre.yLerRh
fixtures, OpenSpec strict 8/8, stable generator, compiler/test membership,
UI/accessibility/localization, privacy/API, reference/dependency/license,
source/built plist, retained result, artifact, Keychain, and diff gates pass
```

Ordinary tests continued to remove `LUNEX_RUN_KEYCHAIN_TEST`; no simulator was
queried or operated. This closes deterministic task 5.6 only. It does not prove
signed background acceptance, system PiP, background duration, Stage Manager,
rotation, external display, visible mobile EDR, physical input/spatial audio,
power/thermal behavior, or live Sunshine interoperability. Those remain 6.x
acceptance work.

OpenSpec task 6.1 repeated the complete normal suite from committed 5.6 source
with both real-Keychain and live-host opt-ins absent. The retained result is
`/tmp/LuneX-17-6_1-normal.8bwnco/Normal.xcresult`: 909 total, 908 passed,
one skipped, and zero failed or expected failures. The only skipped identifier
is `HostAndPersistenceTests/testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`;
build errors, warnings, and analyzer warnings are zero. The pre-mark repository
gate is `/tmp/LuneX-17-6_1-repository-pre.QcX64y`. This is normal-test proof,
not physical mobile runtime acceptance.

OpenSpec task 6.2 retained ten isolated warnings-as-errors builds under
`/tmp/LuneX-17-6_2-builds.ORyQlN`: macOS, fixed iPhone 17 Pro, fixed iPad Pro
13-inch (M5), tvOS, and visionOS, each in Debug and Release. Every structured
build result is `succeeded` with zero errors, warnings, and analyzer warnings,
and every configuration contains Metal AIR and metallib output. The iPhone and
iPad products are `iphonesimulator` builds with `UIDeviceFamily = [1, 2]` and
the single `audio` background mode; the other platform products have no
`UIBackgroundModes` key. Normalized simulator inventories before and after the
matrix have identical SHA-256
`0470edc00aea815358b4bed51fa43b73b79a5cbc61f80856f9630c6128568d41`;
both fixed devices remained unique, available, and shut down, with zero booted
devices. The pre-mark gate is
`/tmp/LuneX-17-6_2-repository-pre.MR2Y1N`. These unsigned build-only results do
not prove signing, installation, system PiP, background duration, Stage
Manager, visible EDR, physical input or spatial audio, power/thermal behavior,
or live Sunshine interoperability.

OpenSpec task 6.3 repository/API evidence is retained at
`/tmp/LuneX-17-6_3-repository.NHQpyc`. It passes fixture self/tree validation,
OpenSpec strict 8/8, stable generator SHA-256, complete source/test membership,
reference and package isolation, byte-identical pinned ENet plus license
verification, the single iOS `audio` plist declaration, bounded privacy and
forbidden-API checks, a direct iOS 26.4 UIKit/AVKit/AVFoundation/EDR probe, and
strict AVKit/ENet bridge and vendor compilation against four Apple SDKs. The
macOS Debug and Release analyzers are retained under
`/tmp/LuneX-17-6_3-analyzer.ZbHqMU`; both succeeded with zero errors and zero
compiler warnings. Each reported the same four findings, all in byte-identical
pinned ENet: three unused stores and one generic nullable-argument path in
`unix.c`. LuneX first-party sources and bridges have zero analyzer findings;
the production bridge does not call the raw socket receive API, and ENet's only
production call passes both address arguments. The third-party finding remains
recorded as residual dependency risk rather than being hidden or described as
a zero-finding analysis.

OpenSpec task 6.4 complete sanitizer evidence is retained at
`/tmp/LuneX-17-6_4-asan.wtKUhx` and
`/tmp/LuneX-17-6_4-tsan.7v8bx9`. Each full suite passed 909 total, 908 passed,
one explicit real-Keychain skip, and zero failed or expected failures, with
zero structured diagnostics and no AddressSanitizer, LeakSanitizer, or
ThreadSanitizer report. The strengthened malloc/resource gate at
`/tmp/LuneX-17-6_4-resource.6jwPh7` passed 320/320 tests across the exact 16
mobile scene, EDR, PiP, continuity, media, AppModel, diagnostic, and Metal
presenter suites with scribble, pre-scribble, guard edges, stack logging,
per-allocation heap checks, and allocator error abort enabled. It reported no
allocator failure and covers frame backpressure/release, observer cancellation,
generation replacement, restoration completion, and clean stop. The pre-mark
combination gate is `/tmp/LuneX-17-6_4-repository-pre-r3.M8A6Ib`. These
deterministic macOS sanitizer results do not prove physical iOS system PiP,
background duration, mobile EDR, Stage Manager, power/thermal behavior, or
long-running live Sunshine resource use.

OpenSpec task 6.5 fixed-simulator evidence is retained at
`/tmp/LuneX-17-6_5-simulator-audit.wNPE0P`. The normalized CoreSimulator
inventory from task 6.2 before builds, after builds, and the single current
read are byte-identical with SHA-256
`0470edc00aea815358b4bed51fa43b73b79a5cbc61f80856f9630c6128568d41`.
The fixed iOS 26.4 iPhone 17 Pro and iPad Pro 13-inch (M5) runtime/name/UUID
identities each occur once, each UUID occurs once globally, both are available
and shut down, and no simulator is booted. Installed iOS 27.0 provides one
additional shut-down same-name default identity per device class; those are
different runtime identities and were neither created nor run by this change.
The retained task 6.2 Debug and Release builds for both fixed devices remain
successful with zero structured diagnostics, one AIR and metallib per build,
and the expected simulator platform, device family, and single `audio`
background mode. The project has no UI-test product target or
`XCUIApplication` harness, so task 6.5 did not invent a launch-only UI gate or
boot, install, launch, shut down, clone, create, or delete any simulator. This
evidence proves fixed simulator identity, state, and build compatibility only;
it does not prove signed installation, native PiP presentation, background
duration, Stage Manager, external display, physical input, visible EDR,
spatial audio, live Sunshine, power, or thermal behavior.

## Target ownership model

Stage 17 will use the following ownership chain:

```text
AppModel active session
  -> NativeSessionMediaEnvironment media generation
    -> mobile presentation generation
      -> actual MTKView attachment owner
        -> UIWindow / UIWindowScene / UIScreen observation
        -> normalized geometry and display revisions
      -> PiP runtime
        -> AVSampleBufferDisplayLayer
        -> AVSampleBufferVideoRenderer
        -> AVPictureInPictureController and delegates
        -> bounded latest-compatible-frame sink
```

Rules:

- Platform objects stay on the main actor.
- Shared actors receive immutable Sendable semantic snapshots.
- Session ID, media generation, surface generation, decoder generation, PiP
  generation, geometry revision, and display revision are checked at their
  owning boundary.
- Replacement cancels observers and makes late callbacks inert before it
  publishes replacement state.
- Teardown is idempotent and releases notification tokens, trait
  registrations, layer/renderer callbacks, queued pixel buffers, restoration
  leases, and controller delegates.
- Raw `UIWindowScene`, `UIWindow`, `UIScreen`, controller, frame, sample-buffer,
  host, and endpoint identities are not persisted or displayed.

## Geometry and input policy

The UIKit adapter normalizes:

- view bounds in points;
- window bounds in points;
- safe-area insets;
- native/display scale;
- drawable pixels;
- interface orientation;
- horizontal and vertical size class;
- display identity revision; and
- scene activity.

Only finite, positive drawable geometry is eligible. Normalized geometry feeds
`StreamCoordinateSnapshotPublisher`; the resulting exact revision feeds both
the Metal surface and `InputMapper`.

During detach, zero/invalid geometry, or replacement:

- the Metal surface is paused and cleared according to the established render
  policy;
- absolute touch and pointer input is suppressed;
- no global-screen size is substituted; and
- later valid geometry produces a new coordinate revision before rendering or
  input resumes.

## PiP and background policy

PiP actual state comes only from native controller events:

```text
unsupported -> preparing -> possible -> starting -> active
           \-> failed
active -> stopping -> stopped/restoring
any state -> invalidated
```

A request to start does not set active state. A stale delegate callback cannot
change the replacement generation. UI restoration uses an exactly-once
completion lease.

Background continuation requires:

- the active scene is actually backgrounded;
- the same current media generation is still valid;
- a permitted playback audio session is actually active, or native PiP is
  confirmed active;
- the user preference permits that path; and
- the generated configuration declares the required capability.

If the last actual permitted path ends while the scene remains backgrounded,
the runtime immediately reevaluates policy and suspends or stops unsupported
work. It does not use background tasks, timers, silent audio, or arbitrary
network activity to evade system lifecycle policy.

## Verification matrix

### Deterministic and build gates

- Scene/geometry/display normalizers and checked revision exhaustion.
- Multi-scene and attached-screen identity filtering.
- Continuous resize, duplicate layout, safe-area, trait, foreground restore,
  detach, replacement, and late callback behavior.
- PiP reducer event order, possibility, start/failure/stop, restore
  exactly-once, skip completion, playback state, replacement, and invalidation.
- Pixel-buffer to sample-buffer timing/color ownership.
- `AVSampleBufferVideoRenderer` backpressure, latest-frame capacity, failure,
  flush, replacement, and retained-buffer release.
- Actual-audio/PiP continuity policy and loss of the last permitted path.
- Shared geometry use by Metal and `InputMapper`.
- Mobile EDR normalization, headroom changes, screen movement, render
  reconfiguration, stale-frame rejection, and SDR fallback.
- AppModel current-generation state, bounded diagnostics, native UI,
  localization, accessibility, migration, and clean teardown.
- Normal tests with `LUNEX_RUN_KEYCHAIN_TEST` removed.
- macOS, fixed iPhone, fixed iPad, tvOS, and visionOS Debug/Release builds with
  warnings as errors.
- OpenSpec, generator stability, API, analyzer, sanitizer, malloc/resource,
  privacy, clean-room, and repository gates.

### Fixed simulator boundary

The only fixed iOS/iPadOS simulator identities for stage 17 are:

```text
iPhone 17 Pro
23A27088-C19F-4F77-A455-4E50E393167E

iPad Pro 13-inch (M5)
409A5908-8C39-4797-A41C-04503A05FA3D
```

Do not create, clone, or boot a duplicate of either device class. Read-only
inventory and build destinations do not prove runtime PiP, EDR, or background
behavior.

### Required physical acceptance

OpenSpec task 6.6 remains incomplete until authorized physical evidence covers:

- signed iPhone and iPad candidates with the generated background declaration;
- system PiP possible/start/active/stop/restore and failure recovery;
- foreground, background, lock, interruption, route/media reset, and return;
- audio-only and PiP continuity, including loss of the last legal path;
- iPad Stage Manager continuous resize and rotation;
- external-display move, scale, drawable fill, fit/fill, and input mapping;
- SDR, HDR-to-SDR, and mobile EDR visible behavior with headroom change;
- coexistence with the stage 16 spatial-audio runtime;
- live Sunshine video/audio/control behavior;
- bounded CPU/GPU, memory, power, and thermal observations; and
- clean stop with no surviving scene, PiP, frame, observer, decoder, audio, or
  media-generation ownership.

The acceptance receipt must identify the LuneX commit, OS/Xcode versions,
device class, signed configuration class, server-advertised capabilities,
optional Sunshine package-version diagnostic metadata, scenario,
expected result, observed result, bounded runtime state, and teardown result.
It must not contain host endpoints, secrets, profile UUIDs, certificates,
device serial numbers, raw scene/display identities, or media payloads.

## Stage 17 closure status

OpenSpec tasks 1.1 through 6.5 and 6.7 are complete. Task 6.6 is the only
remaining task and stays unchecked until an authorized signed physical receipt
meets the acceptance matrix above. The change remains `in_progress` at 35/36
and must not be archived or described as feature-complete before that receipt.

| Proof tier | Current stage 17 evidence | Explicitly not proven |
|---|---|---|
| Contract/static | Immutable contracts, production ownership, deterministic tests, privacy/API and repository gates | Apple runtime acceptance or live host behavior |
| Build | Ten unsigned Debug/Release Apple-platform builds, generated plist, Metal artifacts, analyzer results | Signing, installation, provisioning, or store acceptance |
| Simulator | Fixed 26.4 identity/state and retained iPhone/iPad builds; no UI target or launch | System PiP, background duration, Stage Manager, visible EDR, physical input/audio |
| Signed artifact | Pending task 6.6 | Background entitlement/configuration acceptance on a device |
| Physical/live | Pending task 6.6 | PiP, background, resize/rotation/external display, HDR, spatial audio, Sunshine, power/thermal, teardown |

Stages 18 through 20 may proceed using the completed deterministic foundation,
but their tests cannot backfill task 6.6. The rollback before physical
acceptance remains foreground-only rendering with typed suspend/pause/stop and
truthful unavailable/fallback UI; it is not an unsupported keepalive path.

The independent stage-level offline acceptance on pushed commit
`c7c9089a965eb1eea100b84e844f87ab003f939d` is retained at
`/tmp/LuneX-17-stage-acceptance.xnt9je` with combination gate
`/tmp/LuneX-17-stage-acceptance-final.k8BdmF`. A fresh complete macOS normal
suite passed 909 total, 908 passed, the one exact authorized-Keychain opt-in
skip, and zero failed or expected failures; structured errors, warnings, and
analyzer warnings are zero. The combination gate also passes fixtures,
OpenSpec strict 8/8, stable generator, exact 35/36 with only task 6.6 pending,
retained fixed-simulator no-launch/no-mutation evidence, clean Git parity, and
an unset Keychain opt-in. This revalidates the offline tier only and does not
change the physical acceptance status.
