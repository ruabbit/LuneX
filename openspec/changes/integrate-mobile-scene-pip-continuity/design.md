## Context

Stages 13-16 established a generation-owned Moonlight session runtime, native
VideoToolbox decode, a Metal HDR/EDR presenter, a session-owned audio graph, and
actual macOS window lifecycle integration. The mobile product path is not at the
same level. `UIKitLifecycleMonitor` currently maps SwiftUI `scenePhase` into two
Booleans and multiplies a supplied point size by a scale. It does not own the
actual `UIView`, `UIWindow`, `UIWindowScene`, or `UIScreen`. The mobile
`MetalStreamSurface` is an ordinary `UIViewRepresentable` around `MTKView`; it
does not publish attachment, safe-area, trait, resize, or display changes.

`MobileContinuityPolicyResolver` and `PictureInPictureStateCoordinator` are
policy/value placeholders. There is no `AVPictureInPictureController`,
`AVSampleBufferDisplayLayer`, playback delegate, frame sink, restoration
callback, or current-generation background runtime. `DisplayHeadroomReader`
can read `UIScreen.currentEDRHeadroom` and `potentialEDRHeadroom`, but no actual
window-screen observer feeds those values into the active renderer.

The existing decoder already publishes `DecodedVideoFrame` values containing a
generation, `CVPixelBuffer`, presentation timestamp, duration, color metadata,
and HDR render binding through `StreamVideoPresentationSource`. Stage 17 must
reuse that output for both foreground Metal and PiP without a second decoder or
unbounded queue.

Xcode 26.4 confirms the supported sample-buffer PiP content source, current
UIKit scene notifications, view attachment/layout/safe-area hooks, registered
trait observation, and mobile EDR properties. Context7's current Apple
documentation index did not expose the detailed signatures, so checked-in
contract decisions and verification use public Xcode 26.4 SDK headers,
compile-time API probes, and deterministic injected adapters. API compilation,
simulator behavior, signed configuration, and physical-device behavior remain
separate proof tiers.

## Goals / Non-Goals

**Goals:**

- Make the actual UIKit stream view the single source of mobile scene, window,
  screen, geometry, scale, safe-area, trait, lifecycle, and display state.
- Track iPad window and Stage Manager geometry continuously and feed one
  revision contract into drawable sizing, video mapping, and remote input.
- Add a real generation-owned sample-buffer PiP runtime that reuses current
  decoded frames and handles start, stop, restore, failure, replacement, and
  teardown truthfully.
- Continue work in the background only through a confirmed system-managed audio
  or PiP path; otherwise suspend foreground rendering and pause or stop
  unsupported work.
- Bind actual mobile EDR headroom and display revisions to the existing Metal
  HDR render identity and surface configuration.
- Publish bounded diagnostics and accessible native UI backed by actual current
  runtime state, with deterministic cross-platform verification.

**Non-Goals:**

- Treating `UIBackgroundModes`, an enabled preference, or a controller object as
  proof that PiP/background execution is active.
- Creating a second decoder, a software copy pipeline, an unbounded PiP frame
  queue, or an `AVPlayer` placeholder unrelated to the Moonlight session.
- Supporting arbitrary background network execution outside Apple's permitted
  media lifecycle, or promising a specific background duration.
- Claiming physical Stage Manager, external-display input accuracy, system PiP,
  visible HDR luminance, thermal/power behavior, or live Sunshine
  interoperability from unit tests, unsigned builds, or simulators.
- Changing macOS window behavior, completing tvOS/visionOS product workflows,
  release signing, or closing the remaining physical gates from stages 13-16.

## Decisions

### Make a UIKit stream attachment view the lifecycle authority

The mobile `MetalStreamSurface` will use a small `MTKView` subclass or adjacent
attachment owner that reports `didMoveToWindow`, `layoutSubviews`,
`safeAreaInsetsDidChange`, and registered trait changes to one `@MainActor`
adapter. The adapter will derive `windowScene`, `window`, and `screen` from that
actual view. It will observe scene activation notifications only for the
attached scene and screen mode/brightness notifications only for the attached
screen.

Using SwiftUI `scenePhase` alone was rejected because it cannot identify which
window or screen owns the stream and cannot provide continuous Stage Manager
geometry. Using `UIScreen.main` or scanning `connectedScenes` was rejected
because multiwindow and external-display ownership would be ambiguous.

### Publish normalized immutable scene and geometry snapshots

Platform objects remain inside the main-actor adapter. Shared state receives
immutable Sendable snapshots with semantic scene activity, attachment state,
finite bounds, safe area, scale, drawable size, orientation/trait classes,
display revision, and monotonically checked generation/revision values. Object
identities are used only for in-process filtering and never persisted or shown.

The normalizer rejects nonfinite, negative, zero drawable, and integer-overflow
inputs. Equivalent normalized snapshots are deduplicated. This keeps UIKit
objects out of actors and allows lifecycle, resize, renderer, input, diagnostic,
and replacement behavior to be exhaustively tested without a live window.

### Feed one geometry revision into Metal and input

The current normalized snapshot becomes the authoritative mobile coordinate
snapshot. It updates `MTKView.drawableSize`, video fit/fill mapping, and
touch/absolute-pointer transforms together. A detached or invalid surface
pauses rendering and suppresses absolute input until a valid revision arrives.

Letting SwiftUI size the view while input separately uses screen bounds was
rejected because it creates pointer drift under Stage Manager, split view,
rotation, safe areas, and external-display moves.

### Reuse the active decoded frame stream for PiP

A protocol-driven PiP frame sink consumes current-generation
`DecodedVideoFrame` values from the same presentation source used by Metal. The
production sink creates timed `CMSampleBuffer` objects around the existing
`CVPixelBuffer`, preserves relevant attachments, and enqueues into one
`AVSampleBufferDisplayLayer`. It never owns a decompressor. Backpressure keeps
at most the latest compatible pending frame and flushes on media generation,
format/color identity, discontinuity, failure, or teardown.

An `AVPlayer` backed by synthetic media was rejected because it would not
represent the Moonlight decoder. A second VideoToolbox session was rejected due
to decode cost, synchronization drift, duplicated format recovery, and resource
ownership complexity.

### Isolate AVKit behind a generation-owned controller adapter

The AVKit layer consists of an injectable controller client, one production
`AVPictureInPictureController`, one sample-buffer content source, and one
playback/delegate owner. It publishes bounded semantic events rather than AVKit
objects or raw errors. An actor serializes request, possible, starting, active,
stopping, failed, restore, invalidated, and replacement transitions and accepts
events only for the current session/media/PiP generation.

Restoration completion is an exactly-once lease. Replacement invalidates the
old client, flushes the layer, cancels observation, and makes all delayed
callbacks inert. Actual active state comes only from native delegate
confirmation, never from the user's request.

### Resolve background continuity from observed media state

`MobileContinuityPolicyResolver` will use actual scene activity, audio runtime
state, PiP state, user preference, and generated capability/configuration
inputs. Background modes declare eligibility but never prove execution.

Confirmed PiP permits bounded frame delivery plus session control/audio;
confirmed playback audio without PiP permits the resources needed for audio
continuity while foreground Metal pauses; no confirmed legal path pauses or
stops the stream according to policy. Losing the last legal path in background
triggers immediate reevaluation. Foreground restoration resamples view,
geometry, display, audio, and PiP state before rendering resumes.

### Bind mobile EDR to the actual window screen and render identity

The attachment adapter reads `potentialEDRHeadroom` and `currentEDRHeadroom`
from `view.window?.screen` and resamples on attachment, foreground restoration,
screen mode, brightness, relevant trait, and window/display changes. Values are
finite and bounded, and duplicate semantic readings do not create revisions.

The resulting mobile display revision enters the existing
`HDRDisplaySnapshot`/render configuration path. Screen movement or headroom
changes atomically reconfigure the renderer; stale incompatible frames are
rejected by the established render binding. Headroom at or below one selects
truthful HDR-to-SDR fallback rather than an EDR claim.

### Route actual state through media ownership and AppModel

One mobile presentation runtime owned alongside
`NativeSessionMediaEnvironment` binds scene attachment, PiP, decoded video,
audio continuity, EDR, and teardown to the active media generation. `AppModel`
accepts only current-generation snapshots and clears actual status on stop,
failure, or replacement while preserving user preferences and bounded
diagnostic history.

Stream UI exposes an icon command for PiP when actually possible, compact
actual scene/PiP/HDR status, and accessible native settings toggles. It does not
show raw object identifiers, raw AVKit errors, host/frame identifiers, or
unbounded notification payloads.

### Keep generator and platform boundaries explicit

New UIKit/AVKit/QuartzCore/CoreMedia implementations compile only on supported
mobile targets; shared value contracts remain platform-neutral. The
generator-owned project controls source/test membership and any
`UIBackgroundModes` values. tvOS and visionOS must continue to build even when
interactive PiP/mobile window features are unavailable or intentionally
excluded.

Every normal test command removes `LUNEX_RUN_KEYCHAIN_TEST`. Simulator checks
reuse the fixed iPhone 17 Pro and iPad Pro 13-inch (M5) instances and never
create, clone, or boot duplicates.

## Risks / Trade-offs

- [Risk] UIKit layout callbacks can be frequent during interactive resize. ->
  Mitigation: normalize and deduplicate snapshots, keep the main-actor work
  bounded, and rebuild expensive render resources only when semantic identity
  changes.
- [Risk] Scene notifications can arrive during detach or replacement. ->
  Mitigation: filter by actual scene identity and generation, cancel observers
  before releasing attachment, and make late events inert.
- [Risk] `AVSampleBufferDisplayLayer` backpressure can grow retained decoder
  frames. -> Mitigation: retain at most one latest compatible pending frame,
  flush on discontinuity/replacement, and test pixel-buffer release.
- [Risk] PiP callbacks and UI restoration can be out of order. -> Mitigation:
  serialize them through a closed state machine and use an exactly-once
  restoration lease.
- [Risk] Background declarations can encourage unsupported keepalive behavior.
  -> Mitigation: require actual audio/PiP state for continuation and fail closed
  as soon as the last legal path ends.
- [Risk] Headroom/brightness changes can race decoded frames. -> Mitigation:
  include display revision in render identity and reject incompatible stale
  frames rather than applying new scaling to old configuration.
- [Risk] Simulator PiP/HDR behavior differs from physical devices. ->
  Mitigation: keep physical PiP, Stage Manager, external-display, visible HDR,
  power, and live-host tasks pending until separately authorized evidence.
- [Risk] Adding background audio configuration can affect review or signing. ->
  Mitigation: generate the narrow playback declaration, document its ownership,
  verify the built plist separately, and retain a rollback to foreground-only
  suspension.

## Migration Plan

1. Add immutable mobile scene, geometry, PiP, continuity, and EDR value
   contracts plus deterministic normalizers/state machines without changing
   product behavior.
2. Add the UIKit attachment/lifecycle/display adapter and connect its geometry
   to the mobile Metal surface and input mapping.
3. Add the bounded decoded-frame PiP sink, injectable controller client,
   production AVKit adapter, and generation-owned state machine.
4. Integrate actual audio/PiP background policy, renderer suspension,
   foreground restoration, and generated configuration.
5. Route actual state through media ownership, AppModel, diagnostics, Settings,
   and stream controls with replacement/teardown tests.
6. Run normal, cross-platform Debug/Release, API, analyzer, sanitizer,
   resource, generator/OpenSpec, and fixed-simulator gates.
7. Complete separately authorized physical iPhone/iPad Stage Manager, PiP,
   background audio, external-display, EDR, input, power, and live Sunshine
   acceptance. Before that gate, rollback is foreground-only rendering with
   typed suspension, not a claim of mobile continuity.

## Open Questions

- Which authorized iPhone and iPad models will provide EDR, Stage Manager,
  external-display, and PiP acceptance evidence?
- Which signed provisioning profile and release configuration will be used to
  validate the generated background audio declaration on physical devices?
- Which external display and input devices will be used to correlate drawable
  size, fit/fill mapping, and remote absolute coordinates?
- What physical background-duration and power budget will be accepted for a
  live Sunshine session after functional PiP/background behavior is proven?
