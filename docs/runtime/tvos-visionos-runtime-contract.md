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
| Stream surface | `StreamWorkspaceView` and `MetalStreamSurface` | tvOS and visionOS use `TVVisionStreamMetalView`; one checked surface generation owns actual view/window/scene activity, platform-available screen state, and normalized surface-local geometry | No full presentation coordinator applies scene/frame/HDR/audio/input state to `AppModel` |
| Render scheduling | `PlatformLifecycleState`, `StreamMetalPresenter`, and `StreamMetalViewScheduleResolver` | Shared value policy can pause/throttle and one presenter consumes decoded frames; the platform surface now supplies the exact geometry-owned coordinate revision | Scene activity, decoded frames, HDR, audio, and input eligibility are not yet serialized by one presentation coordinator |
| Geometry and input mapping | `TVVisionUIKitStreamGeometryBindingOwner`, `StreamVideoRectangleResolver`, and `InputMapper` | Actual view/window bounds, safe area, and scale publish one deduplicated revision for drawable size, fit/fill, and supported absolute/indirect input reference mapping | Actual tvOS/visionOS input adapters and full media/AppModel application remain later tasks |
| Video | `NativeSessionMediaEnvironment`, `NativeSessionVideoProcessor`, `StreamVideoPresentationSource`, and `StreamMetalPresenter` | One decoder/frame source/presenter path exists | No platform presentation coordinator binds current frames to current tvOS/visionOS surface state |
| Audio | `NativeSessionAudioProcessor`, `SessionAudioRuntime`, and `AVAudioEngineClient` | One canonical PCM and generation-owned audio graph exists | No stage 18 coordinator combines platform scene/input/display/audio state under one teardown |
| Application state | `AppModel` | Current video, HDR diagnostic, and audio runtime state exist; iOS adds a mobile generation owner | No tvOS/visionOS presentation snapshot, input eligibility, or platform actual-state projection |

The non-macOS UIKit surface configures the shared presenter, applies shared
render scheduling, and stops the presenter on dismantle. iOS continues to use
its sealed `MobileStreamMetalView` attachment, scene, EDR, touch, and pointer
pipeline. tvOS and visionOS use a separate `TVVisionStreamMetalView` callback
boundary and checked surface-generation owner; they read only the actual view,
window, scene, and platform-available screen and never select a global scene or
screen. Task 2.3 adds bounds/safe-area geometry normalization and a narrow exact
coordinate application to the existing presenter. The serialized platform
presentation coordinator and `AppModel` integration remain tasks 2.4 and 2.5.

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
| Scene and surface | Actual `TVVisionStreamMetalView` owns one surface generation, actual window/scene/tvOS screen, scene lifecycle tokens, visibility/focus, finite bounds/safe-area/scale geometry, detach, invalid, stale, and teardown state | Combine the current scene surface with frame/HDR/audio/input state in the task 2.4 coordinator |
| Geometry | Surface-local owner publishes one deduplicated `TVVisionSemanticRevision` to actual drawable size, exact fit/fill coordinates, and supported input reference mapping | Keep future actual input adapters branded to this revision and reject incompatible frames |
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

- The actual view now owns a checked surface generation, actual window/scene,
  current-scene lifecycle tokens, visibility, scale, drawable, layout, focus,
  detach, invalid, replacement, and stale-callback rejection. visionOS
  truthfully carries no public screen object.
- One surface semantic revision now applies normalized geometry to drawable,
  fit/fill rendering, and supported absolute/indirect input reference mapping;
  the full media generation and `AppModel` projection remain unconnected.
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
| Surface and video | Actual `TVVisionStreamMetalView` publishes finite effective geometry and one semantic revision to drawable/fit/fill/input reference; the shared presenter consumes the exact coordinate snapshot | Bind matching current frames and the remaining scene/HDR/audio/input state through one presentation coordinator |
| HDR | Layer intent/metadata foundation compiles, but `UIScreen` and current headroom are unavailable; capability resolver returns typed SDR fallback | Probe public layer/color/dynamic-range APIs and keep SDR fallback whenever a finite current output bound cannot be established |
| Spatial audio | Output-node `intendedSpatialExperience` applies `.fixed` or `.headTracked` and resets to `.bypassed`; listener property is unavailable | Bind actual route, preference, typed readback, interruption/reset recovery, graph generation, and AppModel state |
| Teardown | Shared media teardown stops video/audio/input resources | Add one platform presentation coordinator so scene, input, frames, HDR, audio, diagnostics, and replacement clear together |

## Xcode 26.4 public API inventory

This table records Xcode 26.4 header/interface availability plus task 1.6 direct
Swift 6.3 warnings-as-errors compile probes. Header presence and successful
typechecking do not authorize runtime behavior.

| API area | tvOS 26.4 | visionOS 26.4 | Boundary |
|---|---|---|---|
| Actual window scene | `UIWindowScene.effectiveGeometry`, Swift-imported `UIWindowScene.Geometry`, 26.0 delegate, actual `screen`, and focus system typecheck | `effectiveGeometry`, `Geometry`, 26.0 delegate, and focus system typecheck; `screen` fails as explicitly unavailable | Read only from the actual surface window scene; legacy `coordinateSpace` fails the 26.0 warnings-as-errors probe |
| Press lifecycle and focus | `UIView` begin/change/end/cancel overrides and arrow/select/menu/play-pause press values typecheck | Generic responder press overrides and focus eligibility typecheck | Compilation does not prove Siri Remote, keyboard, pointer, system gesture, or focus delivery; focus identity remains ephemeral |
| Controllers | Notifications, extended/micro handlers, player index, battery, motion, light, and haptics typecheck | Same controller surface typechecks | Every optional capability requires a current controller lease; no handler was installed or device connected by the probe |
| Keyboard and pointer symbols | `GCKeyboard` handler typechecks; `GCMouse` current/list/handler also typechecks despite its C availability declaration omitting tvOS | `GCKeyboard`, `GCMouse`, `UIPointerInteraction`, hover, and indirect-pointer touch symbols typecheck | Symbol availability is not runtime support. tvOS pointer remains unadvertised until an actual handler and physical acceptance exist; visionOS admission remains capability-gated |
| Screen headroom | Actual-scene `UIScreen.currentEDRHeadroom` and `potentialEDRHeadroom` typecheck | `UIScreen` and `UIWindowScene.screen` fail as explicitly unavailable | tvOS can sample its actual scene screen; visionOS must keep headroom source unavailable until another public finite source is proven |
| Old Metal EDR properties | `CAMetalLayer.wantsExtendedDynamicRangeContent` and `edrMetadata` fail as explicitly unavailable | Both properties typecheck | Do not share a single old-API implementation across platforms; old-property success still does not provide finite visionOS headroom |
| Dynamic range in SDK 26 | `CALayer.toneMapMode`, `preferredDynamicRange`, and `contentsHeadroom` typecheck | The same three properties typecheck | Candidate public presentation paths for 4.2/6.3, not compositor or panel HDR proof; output must remain bounded by actual finite capability |
| Listener head tracking | `AVAudioEnvironmentNode.isListenerHeadTrackingEnabled` set/read typechecks | Property fails as explicitly unavailable | tvOS still requires declared entitlement, matching signed provisioning, capable route, and physical proof |
| Intended spatial experience | Output-node property fails because the member is unavailable | `.headTracked`, `.fixed`, typed readback, and `.bypassed` reset typecheck | visionOS must use intended experience, not the unavailable listener property; compile success is not audible/head-motion proof |
| Audio recovery | Actual route plus route-change, interruption, and media-services-reset notifications typecheck | Same APIs typecheck | Notifications must be generation-owned and removed before teardown |

Deprecated or unavailable APIs must not be hidden behind broad conditional
compilation and called indirectly. Private compositor, gaze, hand-tracking, or
undocumented display APIs are out of scope.

### Task 1.6 direct probe evidence

The retained evidence directory is:

```text
/tmp/LuneX-18-1_6-api.ZD2a58
```

The probe used Xcode 26.4 build `17E192`, Apple Swift 6.3, tvOS 26.4 SDK build
`23L236`, and visionOS 26.4 SDK build `23O238`. Each source was typechecked with
Swift 6, complete strict concurrency, and warnings as errors. The exact source,
command inputs, stdout/stderr, exit status, toolchain identity, and source
SHA-256 list are retained in the evidence directory.

- 12 positive API-domain sources typechecked against the simulator SDKs and
  the same 12 typechecked against the device SDKs: `24/24` succeeded with zero
  diagnostics.
- Six explicitly unavailable or deprecated sources failed as expected against
  each SDK kind: `12/12` expected failures and zero unexpected successes.
- The first UI probe draft used Objective-C name `UIWindowSceneGeometry` and
  was rejected before other UI checks; Swift 6.3 imports it as
  `UIWindowScene.Geometry`. Corrected tvOS and visionOS UI probes then passed.
- A preliminary assumption that tvOS `GCMouse` would fail was disproved by the
  compiler. Current/list access and a movement-handler assignment typecheck on
  both simulator and device SDKs. This is recorded as a compiler surface only,
  not an actual Apple TV input capability or LuneX feature.

The repository declares `com.apple.developer.coremotion.head-pose = true` in
the tvOS entitlement source and assigns that file to tvOS Debug and Release
configurations. The visionOS target has no entitlement file or
`CODE_SIGN_ENTITLEMENTS` setting. Typechecking validates neither provisioning
authorization nor runtime access; task 8.7 retains signed and physical proof.

No probe called `simctl`, created or booted a simulator, launched an app,
installed or signed an artifact, connected a controller/keyboard/mouse, opened
an audio route, requested Keychain access, rendered HDR, moved a window, or
invoked a runtime API. SDK build identifiers above are not the installed
simulator runtime build identifiers recorded by task 1.1.

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

## Task 1.5 immutable boundary verification

Task 1.5 expands the deterministic foundation tests without creating an actual
tvOS or visionOS runtime owner. It closes one production adapter defect:
`GameControllerInputAdapter` now rejects NaN and either infinity before
normalization, returns no event, and uses a fixed diagnostic reason that does
not contain the controller identity. Finite axis values still clamp to
`[-1, 1]`; finite buttons and triggers clamp to `[0, 1]`.

The expanded test matrix verifies:

- zero and exhausted values for every generation domain plus semantic revision
  exhaustion;
- every invalid geometry class covering view/window bounds, safe-area insets,
  scale, drawable bounds, and drawable-to-view mismatch;
- the exact tvOS and visionOS input capability sets rather than representative
  samples;
- every reserved tvOS command and Menu path produces no remote-delivery effect;
- all 16 controller leases are sorted and removed before the single held-input
  release barrier;
- runtime ownership, snapshot, and effect aggregates carrying session,
  generation, surface, controller, or release state do not conform to
  `Encodable`; only selected bounded raw-value enums cross the tested encoding
  boundary, and their JSON is size-bounded and free of identity or credential
  terms.

Task 1.5 verification used fresh isolated evidence:

- focused macOS tests: `58/58` passed, with zero skips, failures, expected
  failures, or structured build diagnostics;
- complete macOS normal suite: `961 total / 960 passed / 1 skipped / 0 failed`,
  with the sole skip being the explicit real-Keychain round trip and both real
  Keychain and live-host opt-ins unset;
- macOS and fixed iOS 26.4 iPhone/iPad, tvOS 26.4 Apple TV, and visionOS 26.4
  Vision Pro Debug builds: all `succeeded`, with zero structured errors,
  warnings, or analyzer warnings and one AIR plus one metallib artifact each.

The fixed simulator UUIDs were build destinations only. Task 1.5 did not query
simulator inventory or perform create, clone, boot, install, launch, run,
shutdown, or delete operations. These tests and builds do not prove actual
tvOS/visionOS handlers, surface/window observation, remote delivery, physical
controller capacity, device HDR or spatial audio, signed installation, or live
Sunshine behavior.

## Task 2.1 tvOS and visionOS surface callback bridge

Task 2.1 replaces the plain tvOS/visionOS UIKit `MTKView` branch with
`TVVisionStreamMetalView` while leaving the iOS/iPadOS mobile pipeline
unchanged. The main-actor bridge publishes an exact raw callback matrix for
attachment, layout, actual `UIWindowScene?`, visibility, content scale,
drawable size, and focus eligibility. `didMoveToWindow`, layout, safe-area,
registered trait, focus, hidden, alpha, and interaction changes trigger
framework-object-local readings from the actual stream view and its window.

`TVVisionUIKitStreamSurfaceRelay` weakly owns the view, reads raw state once
per callback batch, supports SwiftUI handler replacement, and makes empty,
late, or post-invalidation callbacks inert. Dismantle unregisters the trait
registration, invalidates the relay idempotently, and then stops the existing
presenter. The callback carries the actual scene object only synchronously on
the main actor; it is not Sendable, persisted, or placed in diagnostics.

Task 2.1 verification used fresh isolated evidence:

- focused macOS relay tests: `2/2` passed, covering ordered callbacks, one
  state read per batch, handler replacement, actual scene identity, weak view
  ownership, empty/late callbacks, exact callback cases, and idempotent
  invalidation;
- complete macOS normal suite: `963 total / 962 passed / 1 skipped / 0 failed`,
  with the sole skip being the explicit real-Keychain round trip and both real
  Keychain and live-host opt-ins unset;
- direct tvOS and visionOS compile checks plus macOS and fixed iPhone, iPad,
  Apple TV, and Vision Pro Debug builds: all `succeeded`, with zero structured
  errors, warnings, or analyzer warnings and one AIR plus one metallib each.

The fixed simulator UUIDs were build destinations only. Task 2.1 did not query
simulator inventory or create, clone, boot, install, launch, run, shut down, or
delete a simulator. Task 2.2 now provides checked generation ownership and
actual current-scene activity observation. Task 2.3 finite normalized geometry
and semantic revisions, render/input geometry binding, AppModel/media/input
integration, signed artifacts, physical HDR/spatial/input proof, and live
Sunshine behavior remain incomplete.

## Task 2.2 actual surface generation owner

Task 2.2 adds `TVVisionUIKitStreamSurfaceGenerationOwner`, a main-actor owner
that validates a branded `.surface` generation and weakly owns the current
surface, window, window scene, and optional screen. Its resolver receives only
the callback's actual stream view. tvOS requires the actual window scene's
screen; visionOS uses an explicit absent-screen path because the public 26.4
SDK exposes neither `UIScreen` nor `UIWindowScene.screen` there.

The owner publishes an immutable framework-object-free state containing
platform, surface generation, raw callback class, attachment, actual scene
activity, visibility, finite scale, bounded drawable size, and focus
eligibility. Current detach and invalid state clear all window/scene/screen
ownership before publishing a closed result. Wrong generation, wrong surface,
late callback, and post-invalidation handler replacement are inert. Scene
activity observers are installed only for the actual current window scene,
replaced on attachment change, filtered again against the current view, and
removed before callback relay teardown.

Task 2.2 verification used fresh isolated evidence:

- focused macOS tests: `8/8` passed, covering relay behavior, actual object
  identity/activity, tvOS screen, visionOS absent screen, detach and invalid
  recovery, every bounded invalid class, stale/late callback rejection,
  generation domain, weak ownership, and idempotent invalidation;
- complete macOS normal suite: `969 total / 968 passed / 1 skipped / 0 failed`,
  with the sole skip being the explicit real-Keychain round trip and both real
  Keychain and live-host opt-ins unset;
- macOS and fixed iPhone, iPad, Apple TV, and Vision Pro Debug builds: all
  `succeeded`, with zero structured errors, warnings, or analyzer warnings and
  Metal AIR/metallib artifacts retained.

After the host update, the same scope was revalidated on macOS 27.0 with Xcode
26.4. Focused evidence at `/tmp/LuneX-18-2_2-focused-macos27.5VXuwb` remains
`8/8`; complete normal evidence at
`/tmp/LuneX-18-2_2-normal-macos27.APoh6b` remains
`969/968/1/0` with the exact real-Keychain opt-in skip; and the five-platform
Debug matrix at `/tmp/LuneX-18-2_2-builds-macos27.IgW5lP` remains
`succeeded/0/0/0` with one AIR and one metallib per platform. The fixed UUIDs
were used only as build destinations, without simulator inventory or lifecycle
operations.

The task 2.2 repository pre-gate at
`/tmp/LuneX-18-2_2-repository-pre-macos27.NmlEN1` passed fixture self/tree,
OpenSpec strict `9/9` and pre-mark `7/50 next 2.2`, four identical generator
hashes, the exact seven-file scope, source/test membership, owner, privacy,
clean-room, reference, opt-in, process, retained test/build/Metal, and diff
checks. Task 2.2 was marked complete only after this gate; the authoritative
next task is 2.3.

The fixed UUIDs were build destinations only; no simulator inventory or
lifecycle operation ran. Task 2.2 does not publish bounds, safe-area geometry,
semantic revisions or deduplication, change drawable/render/input mapping,
connect a presentation coordinator or `AppModel`, create a signed artifact, or
prove physical input, HDR, spatial audio, live Sunshine, or performance.

## Task 2.3 normalized geometry binding

Task 2.3 adds `TVVisionUIKitStreamGeometryBindingOwner`, a main-actor,
generation-scoped owner that reads bounds, safe-area insets, and scale only
from the callback's actual stream view and window. It derives the Metal
drawable from finite normalized view geometry; neither a global screen nor a
requested stream resolution can become window geometry.
`TVVisionStreamMetalView` disables `MTKView.autoResizeDrawable`, so the checked
geometry owner is the only runtime writer of drawable size.

One `TVVisionSemanticRevision` brands the checked scene-surface snapshot, the
exact fit/fill `StreamCoordinateSnapshot`, and the supported absolute or
indirect input reference mapping. Raw callback class is deliberately excluded
from semantic inputs. Activity, visibility, focus eligibility, normalized
geometry, source size, or fit/fill mode changes advance the revision; equivalent
layout, trait, visibility, or lifecycle callbacks remain unchanged.

Detached, invalid, inconsistent, coordinate-unavailable, drawable-application,
revision-exhaustion, and invalidation paths clear the binding and input mapping
and attempt to set the actual drawable to zero. Wrong generation and wrong
surface callbacks publish nothing. `MobileStreamSurfaceCoordinator` applies
the exact supplied coordinate snapshot to `StreamRenderState`, avoiding an
independent presenter revision. This is a narrow geometry application only;
task 2.4 still owns the full scene/input/frame/HDR/audio coordinator and task
2.5 still owns media-environment and `AppModel` integration.

Task 2.3 fresh verification currently retains:

- focused evidence `/tmp/LuneX-18-2_3-focused-final.3ydyxX` with
  `14/14 passed / 0 skipped / 0 failed / 0 expected failure` and zero
  structured build diagnostics;
- direct tvOS and visionOS actual-branch builds at
  `/tmp/LuneX-18-2_3-tvos.z5gn3n` and
  `/tmp/LuneX-18-2_3-vision.vvrgyu`, both `succeeded/0/0/0` with Metal
  AIR/metallib output;
- complete macOS normal evidence `/tmp/LuneX-18-2_3-normal.LQmuaL` with
  `975 total / 974 passed / 1 skipped / 0 failed`, where the sole skip is the
  explicit real-Keychain opt-in test;
- five-platform Debug evidence `/tmp/LuneX-18-2_3-builds.a3spj2`, where macOS
  and the fixed iPhone, iPad, Apple TV, and Vision Pro destinations all report
  `succeeded/0 error/0 warning/0 analyzer warning` and one AIR/metallib pair.

The Keychain and live-host opt-ins were unset. Fixed UUIDs were build
destinations only; no simulator inventory or lifecycle command ran. These
results do not prove actual input delivery, signed installation, physical HDR
or spatial audio, live Sunshine, performance, power, thermal state, or comfort.

The task 2.3 repository pre-gate at
`/tmp/LuneX-18-2_3-repository-pre.z6jCCO` passed fixture self/tree, OpenSpec
strict `9/9` and pre-mark `8/50 next 2.3`, four identical generator hashes,
the exact nine-file scope, geometry/revision/fail-closed/clean-room boundaries,
retained focused/normal/five-platform Metal evidence, opt-in and process checks,
and `git diff --check`. Task 2.3 was marked complete only after this gate; the
authoritative next task is 2.4.

The post-mark final-state at `/tmp/LuneX-18-2_3-final-state.LZtrAB` confirmed
OpenSpec strict `9/9`, apply `9/50 next 2.4`, generator SHA-256
`4b641128ba2139552abc2319671e0e4749b818167b5f9151ada3ac16c80774b0`, the
exact ten-file scope, retained focused `14/14`, normal `975/974/1/0`, all five
platform builds and Metal artifacts, privacy and opt-in boundaries, no owned
test process, and `git diff --check`. It did not rerun tests or builds and did
not query or operate simulator inventory.

Final manual diff review closed the remaining automatic drawable-writer gap by
disabling `MTKView.autoResizeDrawable` on the tvOS/visionOS stream view. Fresh
focused evidence `/tmp/LuneX-18-2_3-owner-fix-focused.kY6Oxo` passed `14/14`
with zero structured diagnostics. Fresh direct Apple TV and Vision Pro builds
at `/tmp/LuneX-18-2_3-owner-fix-tvos.FCNNmM` and
`/tmp/LuneX-18-2_3-owner-fix-vision.1Feeyo` both succeeded with zero structured
diagnostics and one AIR/metallib pair. These were build-only destinations; no
simulator inventory or lifecycle operation ran.

The amended final gate at `/tmp/LuneX-18-2_3-final-amend-r2.0HXOJm` confirmed
OpenSpec `9/50 next 2.4`, the exact ten-file scope, the stable generator hash,
the single explicit drawable writer, the three fresh owner-fix results, the
retained full normal and five-platform results, disabled opt-ins, no owned test
process, and `git diff --check`.

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
