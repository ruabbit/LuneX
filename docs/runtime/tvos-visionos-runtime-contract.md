# tvOS and visionOS runtime contract

This document is the stage 18 source of truth for the tvOS remote, focus,
controller, scene, Metal, HDR, and audio runtime and for the visionOS window,
input, Metal, HDR, and spatial-audio runtime.

It starts with the task 1.1 inventory. The inventory changes no production
runtime behavior. A source type, target, entitlement declaration, SDK symbol,
successful build, or simulator identity is not evidence that an Apple TV or
Apple Vision Pro delivered input, presented HDR, rendered spatial audio, or
streamed from Sunshine.

## Scope and proof tiers

Stage 18 keeps five proof tiers separate:

1. **Contract and static proof**: source ownership, immutable value semantics,
   public API availability, generated-project membership, privacy boundaries,
   and deterministic tests.
2. **Build proof**: an unsigned target/configuration compiles with Swift,
   Clang, and Metal warnings treated as errors.
3. **Simulator proof**: a fixed runtime/name/UUID remains unique, available,
   and in the expected state; a bounded navigation or UI path is added only
   when a real simulator test target exists. Simulator output is not physical
   media or input proof.
4. **Signed artifact proof**: the archive, code signature, provisioning, and
   embedded entitlements match the intended platform configuration.
5. **Physical and live proof**: authorized hardware exercises actual remote,
   controller, keyboard, window/focus, display, HDR, route, spatial audio,
   interruption, live Sunshine, latency, power, thermal, comfort, and teardown
   behavior.

No lower tier may be reported as a higher tier.

## Baseline environment

The task 1.1 inventory was performed on:

| Item | Observed value |
|---|---|
| macOS | 27.0 build `26A5388g` |
| Xcode | 26.4 build `17E192` |
| tvOS SDK | 26.4 |
| visionOS SDK | 26.4 |
| Repository baseline | `4411f5548803d3b2a9815265e5d8b40104ecbd70` |
| OpenSpec change | `integrate-tvos-visionos-runtime`, `0/50` before task 1.1 |

Moonlight iOS and Moonlight Qt remain read-only behavioral references. No GPL
implementation is copied, linked, translated, or vendored.

## Target, membership, and configuration inventory

`Tools/generate_xcodeproj.rb` is the only project-membership authority.

| Target | SDK and supported platforms | Deployment | Device family | Bundle | Configuration |
|---|---|---:|---:|---|---|
| `LuneX-tvOS` | `appletvos`; `appletvos appletvsimulator` | 26.0 | 3 | `dev.lunex.client.tvos` | Generated Info.plist; `Configuration/Entitlements/LuneX-tvOS.entitlements` |
| `LuneX-visionOS` | `xros`; `xros xrsimulator` | 26.0 | 7 | `dev.lunex.client.visionos` | Generated Info.plist; no target-specific entitlement file |

Both targets compile the shared App, Core, Platform, Rendering, Input, Audio,
Diagnostics, Networking, and Persistence source lists. The test target compiles
the same shared support list. New stage 18 sources must be added to both product
and test-support membership when their contracts are tested through
`LuneXCoreTests`.

The tvOS entitlement file declares:

```text
com.apple.developer.coremotion.head-pose = true
```

This is configuration intent only. It does not prove that Apple granted the
capability, that a provisioning profile contains it, that the installed
process owns it, or that listener head tracking is active. visionOS deliberately
has no copied tvOS head-pose entitlement and uses its public intended spatial
experience API instead.

Neither target currently supplies a dedicated source Info.plist. Generated
Info.plist output, target membership, and an unsigned product remain build-tier
evidence only.

## Current product ownership

| Concern | Current source owner | Current behavior | Missing stage 18 ownership |
|---|---|---|---|
| App scene | `LuneXApp` | tvOS and visionOS create a SwiftUI `WindowGroup`; visionOS shares the non-tvOS default-size branch | No current session/surface generation owns platform scene state |
| Product navigation | `RootView` | Shared native host, app, stream, Settings, and diagnostics flows compile; a few tvOS control styles avoid text fields | No actual tvOS focus/capture state or visionOS window/input capability state |
| Stream surface | `StreamWorkspaceView` and `MetalStreamSurface` | macOS and iOS have platform callbacks; tvOS and visionOS enter the generic `MTKView` branch | No attachment, scene, visibility, focus, geometry, scale, display, or replacement callbacks reach `AppModel` |
| Render scheduling | `PlatformLifecycleState`, `StreamMetalPresenter`, and `StreamMetalViewScheduleResolver` | Shared value policy can pause/throttle and one presenter consumes decoded frames | No actual tvOS/visionOS view/window owner supplies lifecycle and geometry |
| Geometry and input mapping | `StreamCoordinateSnapshotPublisher`, `StreamVideoRectangleResolver`, and `InputMapper` | Shared finite fit/fill and reference-size contracts exist | Generic surface consumes an existing coordinate snapshot but does not publish one from its actual tvOS/visionOS bounds |
| Video | `NativeSessionMediaEnvironment`, `NativeSessionVideoProcessor`, `StreamVideoPresentationSource`, and `StreamMetalPresenter` | One decoder/frame source/presenter path exists | No platform presentation coordinator binds current frames to current tvOS/visionOS surface state |
| Audio | `NativeSessionAudioProcessor`, `SessionAudioRuntime`, and `AVAudioEngineClient` | One canonical PCM and generation-owned audio graph exists | No stage 18 coordinator combines platform scene/input/display/audio state under one teardown |
| Application state | `AppModel` | Current video, HDR diagnostic, and audio runtime state exist; iOS adds a mobile generation owner | No tvOS/visionOS presentation snapshot, input eligibility, or platform actual-state projection |

The generic UIKit surface creates a plain `MTKView`, configures the presenter,
applies shared render scheduling, and stops the presenter on dismantle. Its
platform callback properties and `MobileStreamMetalView` attachment observers
are compiled only for iOS. That is a usable rendering scaffold, not an actual
tvOS or visionOS runtime.

## tvOS remote, focus, and controller inventory

### Existing reusable contracts

- `TVRemoteFocusInputAdapter` converts value samples to `.tvRemote` and
  `.focus` events. `TVRemotePressMapper` recognizes arrow, select, menu, and
  play/pause press types.
- `GameControllerInputAdapter` normalizes value samples and exposes connection
  value types.
- `RemoteInputRuntime` already owns the Moonlight input transport, bounded
  controller registry, complete controller state, wire encoding, feedback
  stream, and ordered held-state release. Stage 18 must reuse it.
- `PlatformLifecycleState` already resolves visibility, focus, drawable,
  renderer/video/presentation/input directives, and release-barrier intent.

### Missing actual runtime

- No stream-surface responder owns `pressesBegan`, `pressesEnded`, and
  `pressesCancelled`; no actual `UIPress` reaches the adapter or current input
  generation.
- No owner distinguishes SwiftUI navigation focus and overlay ownership from
  eligible stream capture.
- Menu/Back/Home, volume, capture, power, and unsupported system commands have
  no explicit reserved-command application policy at the surface boundary.
- Balanced held remote state is not tracked across cancellation, focus loss,
  scene loss, provider failure, replacement, and stop.
- `GameControllerPlatformMonitor` only observes connect/disconnect and rebuilds
  `GCController.controllers()` into a list. It installs no extended or micro
  gamepad handlers, does not publish complete state, and has no generation
  lease or teardown barrier.
- Controller IDs are currently derived from `vendorName-index`; those values
  are neither stable nor suitable for persistence. Stage 18 requires opaque
  per-generation leases and deterministic bounded remote slots.
- No current controller lease applies haptics or light feedback, controls
  motion/battery forwarding, or removes handlers before disconnect/replacement.

Native focus remains the authority outside an eligible stream surface. Focus
movement itself is local UI state and must never be synthesized as a remote
game event merely because a SwiftUI focus item changed.

## tvOS media inventory

| Concern | Current state | Required stage 18 direction |
|---|---|---|
| Scene and surface | Plain generic `MTKView`; no actual scene callbacks | Derive attachment, `UIWindowScene` activity, effective geometry, scale, drawable, and focus from the actual stream view |
| Geometry | Shared snapshot can be consumed but is not produced by tvOS surface | Publish one finite semantic revision for drawable, fit/fill, and supported input mapping |
| Video | Shared decoder, bounded frame source, and Metal presenter exist | Bind only matching current-generation frames; clear on detach, invalid geometry, replacement, or stop |
| HDR | `HDRPlatformOutputCapabilityAdapter` currently returns typed SDR fallback because the old extended-range surface contract is unavailable | Probe the tvOS 26 dynamic-range layer path; retain HDR-to-SDR until actual public capability and current display state form a complete contract |
| Audio | Canonical PCM graph, tvOS AVAudioSession route handling, listener strategy, interruption, and media-reset foundations exist | Bind actual route/capability and graph recovery to the same current media presentation generation |
| App/UI | Shared HDR and spatial status can render | Publish platform actual scene/input/render/HDR/audio state rather than preference-derived claims |

## visionOS window and input inventory

### Existing reusable contracts

- SwiftUI creates a windowed application scene; stage 18 deliberately does not
  create an `ImmersiveSpace`, stereoscopic renderer, volumetric surface, or
  passthrough composition path.
- The shared coordinate, lifecycle, presenter, input transport, controller,
  audio, diagnostics, and AppModel foundations compile for visionOS.
- `GameController` profiles provide a public controller path. Generic UIKit
  responder APIs compile, but their presence is not evidence that gaze, hand,
  indirect, or system gestures should be translated into Moonlight input.

### Missing actual runtime

- The actual `UIView`/`UIWindow`/`UIWindowScene` attachment, activity,
  visibility, effective geometry, scale, drawable, focus eligibility, and
  replacement are not observed.
- No visionOS presentation generation owns multiwindow filtering or rejects
  callbacks from another or replaced window.
- Supported controller, keyboard, pointer, and indirect-input paths have not
  been individually inventoried and admitted under typed capability.
- System gestures, recentering, capture, safety, volume, escape, gaze, and hand
  interactions do not yet have explicit local/reserved or unavailable results.
- Focus/scene/provider loss is not connected to the existing ordered held-state
  release barrier and local UI restoration.
- There is no actual-state UI for windowed mode, supported input, or explicit
  immersive/stereoscopic/volumetric unavailability.

The actual stream view and its window scene must be the authority. Scanning
`connectedScenes`, selecting a global screen, or using requested stream
resolution as window geometry is prohibited.

## visionOS media inventory

| Concern | Current state | Required stage 18 direction |
|---|---|---|
| Presentation mode | Shared `WindowGroup`; no explicit runtime value | Publish current-generation windowed mode and typed unavailable immersive/stereoscopic/volumetric states |
| Surface and video | Plain generic `MTKView` plus shared decoded-frame presenter | Bind surface attachment/effective geometry and current frames; clear stale or detached presentation |
| HDR | Layer intent/metadata foundation compiles, but `UIScreen` and current headroom are unavailable; capability resolver returns typed SDR fallback | Probe public layer/color/dynamic-range APIs and keep SDR fallback whenever a finite current output bound cannot be established |
| Spatial audio | Output-node `intendedSpatialExperience` applies `.fixed` or `.headTracked` and resets to `.bypassed`; listener property is unavailable | Bind actual route, preference, typed readback, interruption/reset recovery, graph generation, and AppModel state |
| Teardown | Shared media teardown stops video/audio/input resources | Add one platform presentation coordinator so scene, input, frames, HDR, audio, diagnostics, and replacement clear together |

## Xcode 26.4 public API inventory

This table records header/interface availability and already-retained stage 15
or 16 typecheck evidence. Task 1.6 owns new direct compile probes. Header
presence alone does not authorize behavior.

| API area | tvOS 26.4 | visionOS 26.4 | Boundary |
|---|---|---|---|
| Actual window scene | `UIWindowScene`; `effectiveGeometry`; delegate `windowScene(_:didUpdateEffectiveGeometry:)` available in 26.0; `screen` available | `UIWindowScene`; `effectiveGeometry`; 26.0 delegate available; `screen` explicitly unavailable | Read only from the actual surface window scene; legacy `coordinateSpace` is deprecated in 26.0 |
| Press lifecycle | `UIResponder` begin/change/end/cancel and `UIPress` arrow/select/menu/play-pause values available | Generic responder and press types appear in UIKit | tvOS may implement balanced eligible capture; visionOS must prove each supported physical input and keep system interactions local |
| Focus | `UIFocusEnvironment`, `UIFocusSystem`, preferred environments, update callbacks | General focus environment exists; tvOS-only focus sound is unavailable | Focus identity is ephemeral UI state and must not enter persistent diagnostics |
| Controllers | Connect/disconnect/current notifications, extended/micro profiles, value handlers, player index, battery, motion, light, and haptics are public capability surfaces | Same framework surface is present in the SDK | Every optional capability requires current controller lease checks; system Home/Menu semantics remain local |
| Screen headroom | `UIScreen.currentEDRHeadroom` and `potentialEDRHeadroom` compile | `UIScreen` and `UIWindowScene.screen` explicitly unavailable | tvOS can read actual scene screen; visionOS cannot invent a screen/headroom source |
| Old Metal EDR properties | `CAMetalLayer.wantsExtendedDynamicRangeContent` and `EDRMetadata` explicitly unavailable | Retained stage 15 typechecks show the layer intent/metadata surface compiles | Do not share a single old-API implementation across platforms |
| Dynamic range in SDK 26 | `CALayer.toneMapMode`; `preferredDynamicRange`; `contentsHeadroom` available | Same APIs available | These are candidate public paths, not proof of compositor or panel HDR; task 1.6/4.2/6.3 must validate contracts |
| Listener head tracking | `AVAudioEnvironmentNode.isListenerHeadTrackingEnabled` available from tvOS 18 | Explicitly unavailable | tvOS still requires entitlement, route, signed, and physical proof |
| Intended spatial experience | Output-node property is unavailable | Output-node `intendedSpatialExperience` available from visionOS 26 | visionOS uses typed `.fixed`/`.headTracked` readback and `.bypassed` reset |
| Audio recovery | AVAudioSession route, interruption, and media-services-reset notifications available | Same notifications are available | Notifications must be generation-owned and removed before teardown |

Deprecated or unavailable APIs must not be hidden behind broad conditional
compilation and called indirectly. Private compositor, gaze, hand-tracking, or
undocumented display APIs are out of scope.

## Immutable presentation foundation

Task 1.2 adds `TVVisionPlatformPresentationState.swift` as a framework-object-
free value contract shared by all application targets and deterministic tests.
It does not attach a tvOS or visionOS view, install a controller handler, read a
display or audio route, or mutate the current session.

The contract provides:

- branded nonzero, checked, exhaustible generations for presentation, surface,
  input, controller lease, display, and audio route ownership;
- a nonzero monotonic semantic revision and aggregate ownership carrying the
  platform, ephemeral session UUID, media generation, presentation generation,
  and input generation without making the aggregate persistable;
- finite bounded view/window rectangles, safe-area insets, scale, and drawable
  dimensions whose rounded point-to-pixel relationship must agree;
- attached/detached scene and surface state, typed focus ineligibility, and a
  current platform capability set that rejects unavailable tvOS pointer paths
  and visionOS Siri Remote paths;
- sixteen deterministic controller slots with branded controller leases,
  complete remote capability facts, and aggregate duplicate slot/lease checks;
- display output, layer dynamic-range capability, and explicit
  `unavailable`/`platform-reported` headroom source. Current visionOS adapters
  must publish `unavailable` until a public finite source exists, but the value
  model does not mistake the current SDK limitation for a permanent platform
  prohibition;
- output channel bounds, route spatial support, platform strategy, and typed
  head-tracking capability. A `.none` strategy can only carry unavailable head
  tracking, and tvOS listener versus visionOS intended-experience strategies
  cannot be crossed;
- one aggregate snapshot that rejects platform, revision, input-generation,
  duplicate controller, and eligible-but-detached/inactive/invisible state.

No `UIWindowScene`, `UIFocusEnvironment`, `UIPress`, `GCController`, `UIScreen`,
`AVAudioSession`, `CAMetalLayer`, or `AVAudioEnvironmentNode` object enters the
shared contract. Tasks 1.3 through 1.6 own the platform-specific reducers,
reserved behavior, normalization expansion, and direct SDK probes; task 2.x
owns actual surface and media-generation integration.

Task 1.2 verification used fresh isolated evidence:

- focused macOS tests: `13/13` passed with Swift, Clang, and Metal warnings as
  errors;
- complete macOS normal suite: `922 total / 921 passed / 1 skipped / 0 failed`,
  with the sole skip being the explicit real-Keychain round trip and both real
  Keychain and live-host opt-ins unset;
- macOS and fixed iOS 26.4 iPhone/iPad, tvOS 26.4 Apple TV, and visionOS 26.4
  Vision Pro Debug builds: all `succeeded`, with zero structured errors,
  warnings, or analyzer warnings and exact new-source membership;
- fixture validation, OpenSpec strict `9/9`, generator four-run byte stability,
  platform-object, privacy, clean-room/reference, and whitespace gates.

The fixed simulator UUIDs were used only as build destinations. Task 1.2 did
not execute a new simulator inventory and did not create, clone, boot, install,
launch, run, shut down, or delete a simulator. These results are deterministic
contract and unsigned build evidence only. They do not prove actual remote or
controller capture, window ownership, rendering, HDR output, spatial audio,
signed installation, physical behavior, live Sunshine, performance, power, or
thermal acceptance.

## Task 1.3 tvOS focus and capture effect foundation

Task 1.3 adds `TVRemoteFocusCaptureContract.swift` as a framework-object-free
value contract. It defines what a future main-actor tvOS surface and controller
owner may apply; it does not install `UIPress` or `GCController` handlers and
does not send an event to a live Moonlight provider.

The contract provides:

- explicit local SwiftUI focus/navigation ownership versus current-generation
  stream capture ownership, with overlay, focus, scene, surface, and capability
  ineligibility represented as typed local reasons;
- a generation-branded, nonzero opaque press token and a balanced
  begin/end/cancel reducer for exactly six stream-eligible buttons: select,
  play/pause, and the four directions;
- local reservation of Back/Menu, Home, volume, capture, power, and unsupported
  commands. Menu never enters the remote button set; unsupported input produces
  a typed local ignore effect rather than a synthetic Moonlight event;
- complete extended- and micro-gamepad state checks, deterministic bounded
  sixteen-slot controller rosters, exact shared active masks, and duplicate
  slot or lease rejection;
- current-generation and current-lease feedback admission for supported rumble,
  trigger rumble, LED, and bounded motion-rate requests, with typed stale,
  missing-controller, and unsupported-capability decisions;
- one checked release plan ordered as close remote admission, remove controller
  handlers, emit reverse-order remote button-up effects, await the existing
  provider held-release barrier, and then restore local focus.

Focus identity remains ephemeral local UI ownership and never enters a remote
serialization effect. Individual controller snapshots prove that their own slot
bit is present; the roster separately proves that every complete snapshot has
the same exact aggregate active mask. A release plan independently rejects
stale generations, reserved active buttons, duplicate press tokens or buttons,
non-tvOS controllers, and duplicate or stale controller leases.

Task 1.3 verification used fresh isolated evidence:

- focused macOS tests: `16/16` passed after correcting one test-only `Int` to
  `UInt8` conversion, with zero build diagnostics;
- complete macOS normal suite: `938 total / 937 passed / 1 skipped / 0 failed`,
  with the sole skip being the explicit real-Keychain round trip and both real
  Keychain and live-host opt-ins unset;
- macOS and fixed iOS 26.4 iPhone/iPad, tvOS 26.4 Apple TV, and visionOS 26.4
  Vision Pro Debug builds: all `succeeded`, with zero structured errors,
  warnings, or analyzer warnings and one AIR plus one metallib artifact each.

The fixed simulator UUIDs were build destinations only. Task 1.3 did not run a
new simulator inventory or perform a simulator lifecycle operation. These are
contract, deterministic-test, and unsigned-build results. Actual stream-surface
press handlers, controller handlers and feedback, focus handoff, physical Siri
Remote feel, live Sunshine delivery, signed installation, HDR, spatial audio,
performance, power, and thermal behavior remain unproved.

## Task 1.4 visionOS window and input effect foundation

Task 1.4 adds `VisionWindowInputContract.swift` as a framework-object-free
value contract. It defines values and ordered effects for a later main-actor
visionOS owner; it does not attach a view or window, install an input handler,
create an immersive space, or send input to a live Moonlight provider.

The contract provides:

- one explicit `.windowed` presentation mode owned by checked presentation,
  surface, and input generations plus a semantic revision;
- an exact, duplicate-free set of typed unavailable states for immersive,
  stereoscopic, volumetric, and passthrough presentation. There is no available
  immersive branch in the task 1.4 contract;
- five capability-mapped public input paths: extended and micro gamepad,
  keyboard, pointer, and indirect pointer. Siri Remote, gaze, and hand input do
  not enter this capability set;
- typed admission decisions that reject stale presentation, surface, or input
  generations before checking actual attachment, scene activity, visibility,
  focus eligibility, and reported capability;
- local reserve decisions for system gesture, recenter, capture, safety,
  volume, and escape, plus typed local drop for unsupported gaze, hand, or
  unknown interaction. The effect model contains no Moonlight serialization
  case for these interactions;
- separate focus-loss and teardown release scopes. Both close admission,
  remove sorted controller handlers, cancel sorted keyboard/pointer monitors,
  await the existing provider held-input release barrier, and only then restore
  local navigation. Teardown additionally cancels system-interaction observers
  and releases the surface lease after the held-release barrier;
- an active/released ownership phase so a repeated release produces no second
  effect sequence. Checked release rejects stale ownership, non-visionOS or
  stale controller leases, duplicate slots or leases, controller paths passed
  as monitors, and focus loss without a local restoration reason.

Task 1.4 verification used fresh isolated evidence:

- focused macOS tests: `15/15` passed after correcting one test-only throwing
  nil-coalescing expression, with zero build diagnostics;
- complete macOS normal suite: `953 total / 952 passed / 1 skipped / 0 failed`,
  with the sole skip being the explicit real-Keychain round trip and both real
  Keychain and live-host opt-ins unset;
- macOS and fixed iOS 26.4 iPhone/iPad, tvOS 26.4 Apple TV, and visionOS 26.4
  Vision Pro Debug builds: all `succeeded`, with zero structured errors,
  warnings, or analyzer warnings and one AIR plus one metallib artifact each.

The fixed simulator UUIDs were build destinations only. Task 1.4 did not run a
simulator inventory or perform a simulator lifecycle operation. Actual
multiwindow selection, resize observation, focus callbacks, controller,
keyboard, pointer, or indirect-input adapters, system gesture observation,
held-input delivery, immersive presentation, signed installation, physical
Vision Pro behavior, live Sunshine, HDR, spatial audio, performance, power,
thermal, and comfort acceptance remain unproved.

## Fixed simulator inventory

Task 1.1 executed one read-only `xcrun simctl list --json` inventory after the
OS update. It performed no simulator lifecycle operation.

| Fixed class | Runtime | Name | UUID | Available | State |
|---|---|---|---|---|---|
| Apple TV | tvOS 26.4 build `23L243a` | Apple TV 4K (3rd generation) | `6C0EC809-4C15-4AEC-9470-00F91480CAA7` | yes | `Shutdown` |
| Vision Pro | visionOS 26.4 build `23O243` | Apple Vision Pro | `9BF41D0C-B423-4B3F-B75D-00B31E85FE18` | yes | `Shutdown` |

All available simulator devices were `Shutdown`; global `Booted` count was
zero. tvOS 27.0 and visionOS 27.0 runtimes are also installed and contain
same-named default devices. They are distinct runtime identities, all
`Shutdown`, and must not be selected by name. Later gates must select the fixed
26.4 UUID explicitly and may not create, clone, or launch a second device of a
class.

The inventory command did not call `create`, `clone`, `boot`, `bootstatus`,
`install`, `launch`, `run`, `shutdown`, or `delete`.

## Physical and live acceptance boundary

Task 8.7 remains pending until authorized signed Apple TV and Apple Vision Pro
hardware is available. A valid privacy-bounded receipt must correlate client
commit, OS/Xcode, device class, signing configuration class, sanitized
Sunshine version, scenario, expected result, actual bounded runtime state,
observable result, resource observation, and clean teardown.

Apple TV acceptance must cover:

- representative Siri Remote and supported controller profiles, balanced
  begin/end/cancel, local focus/overlay handoff, and reserved system commands;
- controller slot/capacity, disconnect/replacement, supported feedback,
  optional motion/battery, and held-state release;
- television mode/geometry changes, drawable fill, fit/fill input mapping,
  SDR, HDR-to-SDR, any enabled direct HDR path, and stale-frame clearing;
- built-in/HDMI/other authorized routes, spatial/head-tracking actual state,
  interruptions, media reset, audible channel placement, and synchronization;
- live Sunshine start/reconnect/remote termination/stop, latency, dropped
  frames, CPU/GPU/memory, power, thermal behavior, and no residual handlers or
  render/audio/input work.

Vision Pro acceptance must cover:

- window attach/detach, multiwindow filtering, continuous resize, focus and
  supported controller/keyboard/pointer/indirect input, reserved interactions,
  release, and replacement;
- explicit windowed presentation and truthful unavailable immersive modes;
- drawable fill, fit/fill input mapping, SDR/HDR fallback or any validated
  public dynamic-range path, stale-frame rejection, and clean clear/resume;
- fixed/head-tracked intended spatial experience, actual routes,
  interruptions/media reset, synchronization, comfort-duration observations,
  and graph replacement;
- live Sunshine, latency, CPU/GPU/memory, power/thermal state, comfort, and
  complete scene/video/audio/input teardown.

Receipts and diagnostics must not contain host endpoints, credentials, keys,
PINs, pairing material, provisioning profile UUIDs, certificate/device serial
numbers, raw controller/window/display identities, input payloads, media
payloads, or raw frames/audio.

Until those receipts exist, stage 18 may report deterministic implementation,
unsigned builds, fixed simulator compatibility, and signed artifact inspection
at their exact tiers. It may not report physical tvOS/visionOS completion, HDR,
head tracking, remote feel, live Sunshine interoperability, performance, or
power/thermal acceptance.
