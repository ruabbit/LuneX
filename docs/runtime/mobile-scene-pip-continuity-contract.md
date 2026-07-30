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
3. **Simulator proof**: a fixed existing simulator executes the explicitly
   selected UI or lifecycle path. This does not prove physical media policy.
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
| Mobile stream surface | `MetalStreamSurface` mobile `UIViewRepresentable` and iOS-only `MobileStreamMetalView` in `Sources/LuneXRendering/MetalStreamSurface.swift` | Installs `StreamMetalPresenter`, applies render schedule, copies an existing coordinate snapshot into `drawableSize`, and publishes closed injectable iOS attachment/layout/safe-area/registered-trait callback events | No actual view/window/scene/screen attachment owner, scene identity, geometry normalization, or attached-screen publication |
| SwiftUI lifecycle | `RootView` and `UIKitLifecycleMonitor` | `RootView` does not construct or retain the mobile monitor; the monitor itself only maps a supplied `ScenePhase` to visible/focused and multiplies a supplied point size by a supplied scale | Not connected to the actual stream view, `UIWindow`, `UIWindowScene`, `UIScreen`, media generation, Stage Manager resize, or AppModel |
| macOS lifecycle reference | `AppKitLifecycleMonitor`, `MacStreamSurfaceAttachmentOwner`, and `MacStreamInputCaptureView` | Actual window/surface ownership, occlusion/focus, backing pixels, screen EDR, stale attachment rejection, render policy, and input admission are connected | This is a behavioral reference, not reusable UIKit code |
| Coordinate contract | `StreamCoordinateSnapshotPublisher`, `StreamVideoRectangleResolver`, and `InputMapper` | Validated fit/fill geometry, checked revision increment, stale/invalid clear, letterbox rejection, source crop, and remote point mapping are implemented | Mobile must publish actual drawable geometry into this contract rather than create a parallel coordinate system |
| Touch and hover mapping | `TouchInputAdapter` | Consumes `InputMapper`, drops samples outside the drawable video region, and carries source reference size | The app does not currently feed actual UIKit touch/hover samples or current mobile geometry into it |
| Renderer | `StreamMetalPresenter`, `HDRMetalVideoRenderer`, and `CVMetalVideoFrameMapper` | One decoded frame is mapped and rendered under a validated HDR render configuration and coordinate snapshot | Mobile view/display lifecycle does not currently produce the actual revision and headroom inputs |
| Current decoded frame | `StreamVideoPresentationSource` | Owns current session/media/decoder generations, the latest `DecodedVideoFrame`, semantic presentation events, stale-frame counts, and clear/replacement behavior | Exposes synchronous `currentFrame()` only; PiP needs a bounded current-generation consumer/event boundary without a second decoder |
| Decoded frame payload | `DecodedVideoFrame` | Carries decoder generation, frame ID, `CVPixelBuffer`, PTS, duration, decode flags, color metadata, and HDR render binding | PiP must convert this existing image buffer and timing into a sample buffer while preserving generation and color ownership |
| Continuity policy | `MobileContinuityPolicyResolver` | Chooses foreground, audio+PiP, audio-only, suspend, or pause from platform, scene, preferences, capability flags, and background-mode declaration | Capability/configuration presence can currently select continuation without actual current-generation audio or native PiP state |
| PiP state | `PictureInPictureStateCoordinator` | Stores only `isActive`, render size, and update time | No native controller, content source, playback delegate, possible/start/stop/failure/restore state, sample layer, frame sink, generation, or teardown |
| Audio session | `MobileAudioSessionAdapter` and `AVAudioEngineClient` | Configures `.playback`/`.moviePlayback`, multichannel intent, sample rate, buffer duration, output channels, activation, deactivation, route state, and spatial capability | `MobileAudioSessionRuntimeSnapshot.isActive` remains inside the audio adapter/pipeline and is not carried by `SessionAudioRuntimeEvent`; continuity cannot yet prove an actual active permitted audio path |
| Media ownership | `NativeSessionMediaEnvironment` | Owns session/media generation, video/audio/input processors and consumer tasks; forwards readiness, video presentation, audio runtime, and feedback | No scene/PiP/mobile-display runtime resource, event, application method, or teardown slot |
| App state | `AppModel` | Applies real macOS lifecycle, render policy, coordinate state, display snapshot, HDR state, audio runtime, and diagnostics | No current mobile scene, geometry, PiP, continuity-path, or attached-screen state |
| Native UI | `StreamWorkspaceView` and `SettingsView` | Shows the Metal surface, actual HDR/spatial status, continuity preference toggles, and native navigation | No actual PiP command, mobile lifecycle/resize status, actual background path, or actual mobile EDR status |

### Generator and configuration

`Tools/generate_xcodeproj.rb` is the only project-membership authority.

- `LuneX-iOS` targets device families `1,2`, deployment target 26.0, and both
  `iphoneos` and `iphonesimulator`.
- iPhone and iPad orientation declarations are generated.
- `INFOPLIST_KEY_UIBackgroundModes` currently contains `audio` for iOS, tvOS,
  and visionOS.
- The iOS entitlement file currently requests the stage 16 head-pose
  entitlement. It does not grant PiP or prove background execution.
- AVKit is available through SDK autolinking, but no source currently imports
  AVKit.
- New source and test files must be added to both the product `sources` and the
  test-support membership arrays where their contracts are compiled into
  `LuneXCoreTests`.

The existing `audio` background declaration is configuration intent only. Stage
17 must separately verify the generated built plist, signed artifact, actual
audio-session activation, actual PiP callback state, and physical background
behavior.

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
device class, signed configuration class, sanitized Sunshine version, scenario,
expected result, observed result, bounded runtime state, and teardown result.
It must not contain host endpoints, secrets, profile UUIDs, certificates,
device serial numbers, raw scene/display identities, or media payloads.
