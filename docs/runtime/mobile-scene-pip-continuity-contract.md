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
| Mobile stream surface | `MetalStreamSurface` mobile `UIViewRepresentable` in `Sources/LuneXRendering/MetalStreamSurface.swift` | Creates a plain `MTKView`, installs `StreamMetalPresenter`, applies render schedule, and copies an existing coordinate snapshot into `drawableSize` | No actual view/window attachment owner, layout callback, safe-area callback, registered trait callback, scene identity, or attached-screen publication |
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
