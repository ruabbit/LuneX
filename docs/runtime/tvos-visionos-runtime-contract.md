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
| App scene | `LuneXApp`, `TVVisionUIKitSurfaceGenerationOwner`, and `AppModel` | tvOS and visionOS create a SwiftUI `WindowGroup`; the actual stream view publishes current surface/window-scene state into the current media application, including current visionOS display and audio actual state | Dedicated platform actual-state controls remain 7.x |
| Product navigation | `RootView` | Shared native host, app, stream, Settings, and diagnostics flows compile; tvOS forwards only eligible supported remote presses, while visionOS routes admitted hardware-key/indirect-pointer input, keeps system interaction local, and restores local ownership only after ordered release | Dedicated visionOS input-status and product UI remain 7.x |
| Stream surface | `StreamWorkspaceView`, `MetalStreamSurface`, `NativeSessionMediaEnvironment`, and `AppModel` | tvOS and visionOS use `TVVisionStreamMetalView`; one checked surface generation owns actual view/window/scene activity and normalized geometry; visionOS capture closure clears active input handlers and its layer-only HDR observer samples actual attachment/layout/trait state and clears on detach/invalidation | Platform controls and signed physical acceptance remain 7.x/8.7 |
| Render scheduling | `PlatformLifecycleState`, `StreamMetalPresenter`, `StreamMetalViewScheduleResolver`, `TVVisionMetalPresentationOwner`, and `TVVisionPlatformPresentationCoordinator` | Shared value policy can pause/throttle; the actual tvOS/visionOS surface and production coordinator share one main-actor owner, a bound presenter consumes only coordinator-admitted current frames, and platform-branded display resolution retains typed HDR-to-SDR whenever current finite headroom is absent | Physical headset/television output remains 8.7 |
| Geometry and input mapping | `TVVisionUIKitStreamGeometryBindingOwner`, `TVRemoteSurfacePressCaptureOwner`, `VisionNativeInputAdapter`, `StreamVideoRectangleResolver`, and `InputMapper` | Actual view/window bounds, safe area, and scale publish one deduplicated drawable/render/input revision; tvOS remote capture and visionOS crop-aware input are admitted only for the current eligible generation, while focus/scene/provider/replacement/stop loss drains accepted work and performs one ordered held-state release; task 5.6 connects multiwindow, resize, capability, stale, replacement, and teardown behavior in three deterministic matrices | Dedicated actual-state UI remains 7.x |
| Video | `NativeSessionMediaEnvironment`, `NativeSessionVideoProcessor`, `StreamVideoPresentationSource`, `StreamMetalPresenter`, `TVVisionMetalPresentationOwner`, and `TVVisionPlatformPresentationCoordinator` | One decoder/frame source/presenter path exists; current tvOS and visionOS frames and displays are admitted by checked ownership, revisions, source identity, and surface generation, with bounded FIFO delivery plus clear/rebind/replacement fences | Physical rendering, latency, and long-run acceptance remain 8.7/phase 20 |
| Audio | `SpatialAudioPlatformNotificationSource`, `AudioEngineRouteCapabilityReader`, `NativeSessionAudioProcessor`, `SessionAudioRuntime`, `AVAudioEngineClient`, `NativeSessionMediaEnvironment`, and `TVVisionPlatformPresentationCoordinator` | One canonical PCM graph publishes actual route/capability, entitlement, spatial readback, interruption/media-reset recovery, and graph generation; tvOS and visionOS normalize and apply only current platform strategy, replay on presentation replacement, and clear audio on terminal state | Audible signed physical route acceptance remains 8.7 |
| Application state | `AppModel` | Current tvOS/visionOS presentation is admitted by media generation, platform, ownership, sequence, and highest surface ownership; visionOS rechecks input admission before capture/delivery, publishes current window/render/HDR/audio state, and serializes terminal-latched ordered release plus bounded local restoration | Complete product UI projection remains 7.x |

The non-macOS UIKit surface configures the shared presenter, applies shared
render scheduling, and stops the presenter on dismantle. iOS continues to use
its sealed `MobileStreamMetalView` attachment, scene, EDR, touch, and pointer
pipeline. tvOS and visionOS use a separate `TVVisionStreamMetalView` callback
boundary and checked surface-generation owner; they read only the actual view,
window, scene, and platform-available screen and never select a global scene or
screen. Task 2.3 adds bounds/safe-area geometry normalization and a narrow exact
coordinate application to the existing presenter. Task 2.4 adds the serialized
platform presentation coordinator contract; task 2.5 connects current media
ownership, the existing frame source, actual geometry application, and
`AppModel` state. Task 2.6 hardens queued replacement and shared terminal races.
Task 3.1 connects actual tvOS press begin/end/cancel callbacks to one
current-surface owner and the existing remote input provider path.

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

### Current press runtime and remaining ownership

- `TVVisionStreamMetalView` now owns actual tvOS `pressesBegan`,
  `pressesEnded`, and `pressesCancelled` callbacks. It maps ephemeral
  `UIPress` identity to one monotonic surface-local press ID, retains the
  begin-time surface generation, and suppresses UIKit only when the
  current-generation owner returns `.captured`.
- `TVRemoteSurfacePressCaptureOwner` reuses `TVRemoteCaptureState`, serializes
  remote delivery through `AppModel.sendRemoteInput`, releases replacement
  presses, rejects late surfaces, and fails closed after delivery failure.
  A failed release receives one best-effort button-up; already queued
  button-down events for that failed generation are suppressed while queued
  button-up cleanup may continue.
- No owner distinguishes SwiftUI navigation focus and overlay ownership from
  eligible stream capture.
- Menu and unsupported press types remain local through UIKit. Full
  Back/Menu/Home, volume, capture, power, and unsupported system-command
  application policy remains task 3.3.
- Begin/end/cancel, replacement, dismantle cancellation, and delivery-failure
  balancing now exist. Focus loss, scene loss, provider failure, stop, and the
  ordered held-release barrier remain tasks 3.2 and 3.6.
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
| Scene and surface | Actual `TVVisionStreamMetalView` owns one surface generation, actual window/scene/tvOS screen, lifecycle, finite geometry, detach, invalid, stale state, and display observer invalidation; current geometry activates media-owned coordinator state, binds the actual presenter owner, and replays the current audio route through `AppModel` | Connect shared reconnect replay components in 4.5 |
| Geometry | Surface-local owner publishes one deduplicated `TVVisionSemanticRevision` to actual drawable size, exact fit/fill coordinates, and supported input reference mapping | Keep future actual input adapters branded to this revision and reject incompatible frames |
| Video | Shared decoder, bounded frame source, Metal presenter, and main-actor coordinator-to-surface owner are connected; platform admission disables latest-frame fallback and validates ownership/revisions/decoder/frame/surface identity | Keep 4.1 clear/rebind/replacement fences and coordinate same-view media reconnect replay in 4.5 |
| HDR | The actual attached tvOS screen and underlying Metal layer publish deduplicated, surface-owned display revisions; complete public preferred-range capability selects the headroom-tagged EDR contract, otherwise the existing bounded HDR-to-SDR path and typed fallback remain active | Physical compositor/HDMI/television HDR remains task 8.7; visionOS has its own 6.3 capability boundary |
| Audio | Canonical PCM graph, actual AVAudioSession route/capability source, listener strategy/readback, entitlement, interruption, media loss/reset, recovery, graph generation, bounded semantic publisher, replacement replay, and terminal clearing are connected to current tvOS presentation ownership | Coordinate audio with same-view video/input reconnect replay in 4.5; physical route and head tracking remain 8.7 |
| App/UI | AppModel receives current/terminal coordinator state carrying actual display and audio route/runtime/spatial fields | Add accessible dedicated actual-state controls and Settings in 7.x rather than preference-derived claims |

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

### Current actual runtime and remaining gaps

- The actual view now owns a checked surface generation, actual window/scene,
  current-scene lifecycle tokens, visibility, scale, drawable, layout, focus,
  detach, invalid, replacement, and stale-callback rejection. visionOS
  truthfully carries no public screen object.
- One surface semantic revision now applies normalized geometry to drawable,
  fit/fill rendering, and supported absolute/indirect input reference mapping.
  The media environment and `AppModel` now admit that scene under current
  presentation ownership. Input effects are connected; display/audio component
  effects remain unconnected.
- Public controller, hardware-key, pointer, and indirect-input paths are
  individually typed and admitted under current generation, focus, and surface
  ownership. Direct touch, gaze, and hand interaction do not become mouse input.
- Observable reserved hardware keys publish bounded current-surface local state;
  recentering, safety, system-owned capture/volume, gaze, and hand interactions
  retain no synthetic Moonlight event source.
- Focus, scene, provider, replacement, and stop loss close capture, drain
  accepted input/controller work, execute one held-state release, and restore
  bounded local ownership. Terminal closure rejects late geometry until a new
  media runtime begins.
- There is no actual-state UI for windowed mode, supported input, or explicit
  immersive/stereoscopic/volumetric unavailability.

The actual stream view and its window scene must be the authority. Scanning
`connectedScenes`, selecting a global screen, or using requested stream
resolution as window geometry is prohibited.

## visionOS media inventory

| Concern | Current state | Required stage 18 direction |
|---|---|---|
| Presentation mode | Shared `WindowGroup`; current attached visionOS scene publishes checked `.windowed` state through `TVVisionPlatformPresentationCoordinator` and `AppModel`, with immersive/passthrough/stereoscopic/volumetric all typed unavailable | Native actual-state UI remains 7.2 |
| Surface and video | Actual `TVVisionStreamMetalView` publishes finite geometry and one revision to drawable/fit/fill/input reference; current media ownership uses one bounded FIFO frame subscription, resubmits only current frames, and rejects stale decoder/surface/revision state | Physical window rendering and performance remain 8.7/phase 20 |
| HDR | The actual Metal layer is observed without a screen token; XROS 26.4 layer/color capabilities compile, but `UIScreen` and current headroom are unavailable, so the native resolver publishes platform-branded `.headroomUnavailable` HDR-to-SDR through AppModel and clears output on detach | Physical compositor/headset HDR remains 8.7 |
| Spatial audio | Output-node `intendedSpatialExperience` applies `.fixed` or `.headTracked` and resets to `.bypassed`; listener property is unavailable; current route, interruption/loss/reset/recovery and graph replacement flow through the single canonical graph | Audible signed physical route acceptance remains 8.7 |
| Teardown | Shared media teardown and the platform coordinator share current-generation terminal admission; replacement keeps one subscription and bounded pump, while stop cancels four tasks and stops five media resources exactly once | Sanitizer/resource tools remain 8.4 and signed physical teardown remains 8.7 |

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

## Task 2.4 serialized platform presentation coordinator

Task 2.4 adds `TVVisionPlatformPresentationCoordinator`, one actor per owned
platform presentation path. A separate FIFO operation gate prevents logical
actor reentrancy while an injected action client is suspended. Independently
revisioned scene, input, display, and audio components are validated and
rebranded into one `TVVisionSemanticRevision`; decoded-frame deliveries retain
their independent bounded source revision and do not churn the platform
semantic revision frame by frame.

The coordinator retains at most one current `StreamVideoPresentationDelivery`.
It validates session/media ownership, monotonic delivery revision, and decoder
generation watermark before emitting a video application branded with the
current platform and surface revisions. Incomplete component state makes input
explicitly `.inputUnavailable`; detached, inactive, hidden, or unfocused scene
state closes input and clears any presented video. Unavailable display output
also closes input and video; recovery may replay only that one current delivery.

Replacement accepts only a newer presentation within the same platform and
session. It tears down old ownership before publishing replacement activation;
foreign-session and late old callbacks are inert. Shared terminal effects run
best effort in this fixed order: input close, video clear, display clear, audio
route clear, scene clear, platform teardown, then terminal snapshot. Action,
snapshot, semantic-revision, or sequence failure leaves a truthful failed local
snapshot and performs at most one shared teardown. Diagnostics retain only a
bounded sequence plus typed activation/scene-close/replace/stop/failure class
and effect kind, never framework identity, host data, route label, payload, or
arbitrary error text.

Task 2.4 fresh verification currently retains:

- focused evidence `/tmp/LuneX-18-2_4-display-fix-focused-r2.cp7W6C` with `13/13 passed`,
  no skip/failure/expected failure, and zero structured build diagnostics;
- normal evidence `/tmp/LuneX-18-2_4-display-fix-normal.HPUEMu` with
  `988 total / 987 passed / 1 skipped / 0 failed`, where the sole skip is the
  explicit real-Keychain opt-in test;
- macOS, fixed iPhone, fixed iPad, fixed Apple TV, and fixed Vision Pro Debug
  app builds in `/tmp/LuneX-18-2_4-display-fix-builds.Zcj3Gg`, all
  `succeeded/0/0/0` with one AIR/metallib pair.

All commands removed real-Keychain and live-host opt-ins. Fixed device UUIDs
were build destinations only; this task did not read or operate simulator
inventory. These results prove deterministic coordinator ownership and unsigned
SDK branch compatibility only. Task 2.5 media-environment/`AppModel` wiring,
actual platform input/HDR/audio adapters, signed installation, physical input,
HDR/spatial audio, live Sunshine, latency, power, thermal behavior, and comfort
remain unproved.

The initial task 2.4 repository pre-gate at
`/tmp/LuneX-18-2_4-repository-pre.YGBLze` passed fixture self/tree, all nine
OpenSpec objects strict, pre-mark apply `9/50 next 2.4`, four identical project
hashes `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`,
the exact nine-file scope, source/test membership, FIFO/single-delivery/ordered
teardown/privacy/clean-room boundaries, every retained structured test/build
result and Metal artifact, disabled opt-ins, no owned test process, reference
isolation, and `git diff --check`. A later manual review invalidated that gate
after finding display availability absent from render/input eligibility. The
corrected `13/13`, `988/987/1/0`, and five-platform results above supersede the
earlier retained test/build results. The corrected final repository gate at
`/tmp/LuneX-18-2_4-display-fix-final-r3-cXPKxC` passed fixture self/tree,
OpenSpec strict `9/9` and apply `10/50 next 2.5`, four identical project hashes,
the exact ten-file scope, source/test membership, coordinator semantics,
privacy/clean-room boundaries, every corrected structured result and Metal
artifact, disabled opt-ins, no owned test process, reference isolation, and
`git diff --check`. OpenSpec remains marked `10/50`, next task 2.5.

## Task 2.5 media environment and AppModel application

`NativeSessionMediaEnvironment` now creates exactly one
`TVVisionPlatformPresentationCoordinator` for each current media generation.
It accepts typed activate, scene, input, display, audio-route, failure, and stop
applications only when the session, media generation, and complete presentation
ownership are current. Every coordinator result is checked again after actor
suspension before it can become environment state or an event.

Activation subscribes to the existing `StreamVideoPresentationSource` for the
same session and media generation. The source still owns the single bounded
latest-frame delivery; task 2.5 creates no decoder, frame queue, audio graph, or
platform transport. Replacement cancels the old subscription before storing the
new ownership, and subscription callbacks re-enter the environment actor before
current-generation admission. Provider failure publishes one typed terminal
snapshot before finishing the media event stream with its bounded error.

`AppModel` injects that same presentation source into the production media
environment and forwards actual tvOS/visionOS stream-surface geometry from
`RootView`. Geometry applications are serialized and coalesced as activation
followed by scene application. Operation identity plus session, media,
platform, ownership, and monotonic-sequence checks prevent an old queued task or
event from mutating a replacement. macOS and iOS/iPadOS default to no platform
application; tvOS and visionOS select only their compile-time platform.

Reconnect, remote termination, and local stop request their distinct coordinator
stop reasons before environment teardown. Failure retains only a typed bounded
terminal snapshot for diagnosis while the active presentation accessor becomes
`nil`; replacement and normal stop clear state and ownership. Subscription
cancellation and coordinator stop are idempotent: the shared resource teardown's
second stop returns the existing terminal state and does not increment teardown
or overwrite its first reason. Diagnostics use only the fixed codes
`platform_presentation_stale` and `platform_presentation_invalid`.

Task 2.5 verification retains:

- focused evidence `/tmp/LuneX-18-2_5-focused-third.ILQdlM` with `8/8 passed`,
  no skip/failure/expected failure, and zero structured build diagnostics;
- normal evidence `/tmp/LuneX-18-2_5-normal-r2.6qYfC2` with
  `996 total / 995 passed / 1 skipped / 0 failed`, where the sole skip is the
  explicitly disabled real-Keychain round trip;
- macOS, fixed iPhone, fixed iPad, fixed Apple TV, and fixed Vision Pro Debug
  evidence `/tmp/LuneX-18-2_5-builds.zPlpja`, all `succeeded/0/0/0` with one
  AIR/metallib pair; and
- pre-mark repository evidence
  `/tmp/LuneX-18-2_5-repository-pre-r2.27GQDW`, which passed fixture self/tree,
  OpenSpec strict `9/9`, four identical generator hashes
  `ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`, exact
  scope, ownership, privacy, reference, opt-in, process, and diff gates; and
- post-mark read-only evidence `/tmp/LuneX-18-2_5-final-state-r2.6tknnX`, which
  confirmed OpenSpec `11/50 next 2.6`, exact 13-file scope, the retained focused,
  normal, five-platform, and Metal results, stable project hash, and all boundary
  checks without rerunning tests, builds, the generator, or simulator operations.

All normal commands removed the real-Keychain and live-host opt-ins. Fixed
simulator UUIDs were build destinations only; task 2.5 did not read inventory or
perform simulator lifecycle operations. These results prove current-generation
application and unsigned SDK branch compatibility. Actual platform input,
display/HDR, and audio-route adapters remain in tasks 3.x through 6.x. Signed
installation, physical input/HDR/spatial behavior, live Sunshine, latency,
power, thermal behavior, and comfort remain unproved.

## Task 2.6 replacement and shared teardown verification

`NativeSessionMediaEnvironment` now reserves one active termination operation
for the current session and media generation before awaiting any platform
terminal effect. Concurrent local stops await that same operation and the same
resource teardown report. A provider failure racing a stop preserves whichever
terminal operation was admitted first. The provider-failure path finishes the
event stream and starts resource teardown asynchronously rather than waiting on
the tracker-owned consumer task that reported the failure.

`AppModel` retains the highest admitted presentation generation and, within
that surface, the highest geometry revision until the platform runtime clears.
Queued geometry work still waits for its predecessor, but only the latest exact
admission may activate ownership and apply its scene. A replacement already in
the queue therefore cannot be displaced by a late old-surface callback. The
same watermark rejects an old platform state both while replacement activation
is suspended and after replacement becomes current.

Task 2.6 verification retains:

- focused evidence `/tmp/LuneX-18-2_6-focused-final-r3.VB6cr5` with `3/3`
  passed and zero warnings or errors;
- related evidence `/tmp/LuneX-18-2_6-related-final.OQl0xr` with `88/88`
  passed across complete surface/presenter and presentation-coordinator suites
  plus the relevant environment and application paths;
- normal evidence `/tmp/LuneX-18-2_6-normal.rKKWHh` with
  `999 total / 998 passed / 1 skipped / 0 failed`, where the only skip is the
  explicitly disabled real-Keychain round trip; and
- macOS, fixed iPhone, fixed iPad, fixed Apple TV, and fixed Vision Pro Debug
  evidence `/tmp/LuneX-18-2_6-builds.k6M12b`, all `succeeded/0/0/0` with one
  AIR/metallib pair; and
- corrected repository pre-gate evidence
  `/tmp/LuneX-18-2_6-repository-pre-r2.MNeROJ`, which passed fixture self/tree,
  OpenSpec strict `9/9`, pre-mark `11/50 next 2.6`, four identical generator
  hashes, exact nine-file scope, semantic membership, retained test/build
  evidence, opt-in, reference, process, and diff boundaries.

The fixed UUIDs were used only as build destinations. No simulator inventory or
lifecycle command ran. These tests and unsigned builds prove deterministic
application, replacement, and teardown ownership; they do not prove actual
remote/controller delivery, HDR output, spatial audio, signed installation,
physical-device behavior, live Sunshine, performance, power, thermal state, or
comfort.

## Task 3.1 actual tvOS stream-surface press capture

The tvOS `TVVisionStreamMetalView` is now focusable and handles actual public
UIKit press begin, end, and cancel callbacks. Supported arrow, select, and
play/pause presses are converted to framework-object-free events carrying the
surface generation, an opaque nonzero press ID, button, and phase. Menu,
unknown, detached, stale, ineligible, and unsupported presses remain local and
continue through UIKit. A captured press never later receives a local UIKit
finish without a corresponding local begin.

The main-actor owner uses the existing `TVRemoteCaptureState` reducer instead
of duplicating press state. Geometry-derived tvOS input eligibility requires
the current media input generation, active/visible/focus-eligible actual
surface, and `.tvRemote` capability. Balanced events use the existing
`sendRemoteInput -> SessionInputApplication -> NativeSessionMediaEnvironment`
provider path. Delivery is FIFO; replacement releases the old surface before
admitting the new one; late surface callbacks are local; a delivery failure
closes the current input generation, retries one release for the failed
button, suppresses queued down events, and permits queued release cleanup.

Task 3.1 verification retains:

- focused evidence `/tmp/LuneX-18-3_1-focused-r4.e1UeNI` with `5/5` passed and
  zero structured diagnostics;
- related evidence `/tmp/LuneX-18-3_1-related.SpHKnV` with `41/41` passed
  across the complete remote contract/owner suite, tvOS/visionOS surface and
  geometry lifecycle, and relevant AppModel paths;
- normal evidence `/tmp/LuneX-18-3_1-normal.nIpesJ` with
  `1004 total / 1003 passed / 1 skipped / 0 failed`, where the sole skip is the
  explicitly disabled real-Keychain round trip; and
- macOS, fixed iPhone, fixed iPad, fixed Apple TV, and fixed Vision Pro Debug
  evidence `/tmp/LuneX-18-3_1-builds.hQ7AVJ`, all `succeeded/0/0/0` with one
  AIR/metallib pair; and
- repository pre-gate `/tmp/LuneX-18-3_1-repository-pre.nYAHpJ`, which passed
  fixture self/tree, OpenSpec strict `9/9`, pre-mark `12/50 next 3.1`, four
  identical generator hashes, exact 11-file scope, source/membership semantics,
  all retained test/build evidence, privacy/clean-room/reference boundaries,
  disabled opt-ins, process checks, and `git diff --check`; and
- corrected final-state evidence
  `/tmp/LuneX-18-3_1-final-state-r2.f0WIxl`, which retained the first read-only
  gate's strict `9/9`, apply `13/50 next 3.2`, project hash, and exact 12-file
  scope, then passed corrected source/task semantics, all retained test/build
  summaries and Metal artifacts, privacy/reference boundaries, disabled
  opt-ins, process checks, and `git diff --check` without rerunning tests,
  builds, the generator, or simulator operations.

All test commands removed real-Keychain and live-host opt-ins. Fixed UUIDs were
build destinations only; no simulator inventory or lifecycle command ran.
These results prove deterministic ownership and unsigned SDK branch
compatibility. They do not prove physical Siri Remote feel, system focus
behavior, signed installation, actual host receipt, controller behavior,
HDR/spatial output, live Sunshine, latency, performance, power, or thermal
acceptance. Tasks 3.2 through 3.7 retain overlay/focus, reserved command,
controller, release-barrier, and broader application verification.

## Task 3.2 SwiftUI focus and overlay handoff

The tvOS stream workspace now has an explicit application-level focus handoff
contract shared by SwiftUI and the current surface press owner. Remote capture
requires stream navigation to be selected, the stream workspace to be visible,
the controls overlay to be hidden, and a fresh actual surface callback to report
an active, visible, focus-eligible surface. Browser, settings, diagnostics, a
visible overlay, and a disappearing workspace remain local.

Showing the overlay or leaving stream navigation updates the current press owner
synchronously before SwiftUI moves focus. Existing held presses therefore enter
the reducer's ordered release path before local controls can own subsequent
presses. Hiding the overlay does not reuse the last eligible geometry: capture
waits for a newer `(surface generation, semantic revision)` stamp. A replacement
surface may restart at a lower semantic revision, while an old surface or the
same revision cannot satisfy the fresh-focus requirement. Repeating the current
overlay visibility is a strict no-op so an idempotent hide cannot strand capture
waiting for a geometry callback that no UI change will produce.

The tvOS SwiftUI branch conditionally presents the status controls, exposes a
`Hide Controls` command, and makes the Metal surface an explicit `FocusState`
target. Back/Menu/Home, volume, capture, power, and unsupported system-command
policy remain task 3.3. Controller handlers, feedback, and the broader
stop/focus-loss provider release barrier remain tasks 3.4 through 3.6.
Reconnect, remote termination, provider failure, and other platform-runtime
clear paths restore the controls overlay before discarding current geometry and
ownership, so Stream navigation cannot remain on a control-free terminal view.

Task 3.2 verification retains:

- focused evidence `/tmp/LuneX-18-3_2-focused-r3.b9ciW0` with `5/5` passed and
  zero structured diagnostics;
- related evidence `/tmp/LuneX-18-3_2-related-r2.FdIxGY` with `43/43` passed across
  the complete remote contract/owner suite, surface and geometry lifecycle, and
  relevant AppModel replacement and terminal paths;
- normal evidence `/tmp/LuneX-18-3_2-normal-r2.7WhDLh` with
  `1006 total / 1005 passed / 1 skipped / 0 failed`, where the sole skip is the
  explicitly disabled real-Keychain round trip; and
- macOS, fixed iPhone, fixed iPad, fixed Apple TV, and fixed Vision Pro Debug
  evidence `/tmp/LuneX-18-3_2-builds-r2.huymlz`, all `succeeded/0/0/0` with one
  AIR/metallib pair. The Apple TV build covers the actual tvOS SwiftUI branch;
  the Vision Pro build proves compile-time isolation after the terminal fix;
  and
- revised repository pre-gate
  `/tmp/LuneX-18-3_2-repository-pre-r3.rICtus`, which passed fixture self/tree,
  OpenSpec strict `9/9`, pre-mark `13/50 next 3.2`, four identical generator
  hashes, exact ten-file scope, current source/test semantics, all revised
  retained evidence, privacy/clean-room/reference boundaries, disabled opt-ins,
  process checks, and `git diff --check`; and
- revised post-mark final-state evidence
  `/tmp/LuneX-18-3_2-final-state-r2.dFJcBe`, which confirmed OpenSpec
  `14/50 next 3.3`, exact 11-file scope, stable project hash, current terminal
  and focus semantics, all revised retained evidence, and every boundary without
  rerunning tests, builds, the generator, or simulator operations.

The earlier pre-mark and post-mark gates were superseded when final diff review
found that a hidden overlay was not restored by terminal runtime clear. They are
not retained as final task evidence. The revised pre-gate passed before task 3.2
was marked again; post-mark final-state remains a separate proof tier.

All test commands removed real-Keychain and live-host opt-ins. Fixed UUIDs were
build destinations only; no simulator inventory or lifecycle command ran. The
results prove deterministic handoff ownership and unsigned SDK branch
compatibility. They do not prove actual tvOS focus-engine behavior, physical
Siri Remote feel, signed installation, host receipt, HDR/spatial output, live
Sunshine, latency, performance, power, or thermal acceptance.

## Task 3.3 local system-reserved commands and native escape

The actual tvOS stream surface now separates public UIKit presses into three
lifecycles at `pressesBegan`: captured Moonlight input, ordinary local UIKit
input, and reserved or unsupported local input. Menu maps to the finite
`backMenu` command; Page Up, Page Down, TV Remote 123, TV Remote Four Colors,
and any future unmapped public press type map to `unsupported`. Reserved and
unsupported presses publish one framework-object-free command intent while
their begin, change, end, and cancel callbacks continue through UIKit. Captured
press changes remain with the Moonlight owner and do not enter a native
responder sequence that never received their begin.

Back/Menu application is admitted only on the tvOS product path. It publishes
a bounded handled-local state and reveals the native controls overlay. The
existing task 3.2 handoff closes remote admission and releases any held remote
press before local controls regain focus. Neither Back/Menu nor unsupported
presses enter the Moonlight remote event handler. The runtime retains only
finite enums and transient `ObjectIdentifier` membership; it does not retain or
diagnose `UIPress`, focus item, controller, host, or payload identity.

The public tvOS 26.4 application responder surface does not expose Home,
volume, system capture, or power as `UIPress.PressType` cases. LuneX therefore
does not fabricate callbacks for them. Their finite contract states remain
`deferToSystem/systemOwned`; unsupported interactions remain
`ignoreLocally/unsupportedInteraction`. These typed unavailable values prove
policy and application behavior only, not that an app observed a physical
system command.

Task 3.3 verification retains:

- revised focused evidence `/tmp/LuneX-18-3_3-focused-r2.BKpneI` with `3/3`
  passed, no skips, failures, or expected failures, and zero structured build
  diagnostics;
- revised direct Apple TV evidence `/tmp/LuneX-18-3_3-tvos-r2.m8QkzS` and
  fresh direct Vision Pro evidence `/tmp/LuneX-18-3_3-vision-r2.fmO2Sl`, both
  `succeeded/0/0/0` with one AIR and one metallib;
- related evidence `/tmp/LuneX-18-3_3-related.PgiNcV` with `44/44` passed and
  zero structured diagnostics across the complete remote/focus contract,
  surface owner/geometry, and relevant AppModel lifecycle paths;
- normal evidence `/tmp/LuneX-18-3_3-normal.5ChBp1` with
  `1007 total / 1006 passed / 1 skipped / 0 failed`, where the sole skip is the
  explicitly disabled real-Keychain round trip; and
- macOS, fixed iPhone, fixed iPad, fixed Apple TV, and fixed Vision Pro Debug
  evidence `/tmp/LuneX-18-3_3-builds.K29Tfl`, all `succeeded/0/0/0` with one
  AIR/metallib pair per platform. The fixed UUIDs were build destinations only;
  and
- repository pre-gate `/tmp/LuneX-18-3_3-repository-pre.y7lh71`, which passed
  fixture self/tree, OpenSpec strict `9/9`, pre-mark `14/50 next 3.3`, four
  identical generator hashes, exact 12-file scope, source/membership and
  no-delivery semantics, all retained test/build evidence, privacy,
  clean-room/reference, disabled opt-ins, process checks, and
  `git diff --check`; and
- post-mark final-state `/tmp/LuneX-18-3_3-final-state.ZREyZa`, which confirmed
  OpenSpec `15/50 next 3.4`, exact 13-file scope, stable project hash, current
  task/source semantics, all retained test/build evidence, and every boundary
  without rerunning tests, builds, the generator, or simulator operations.

The earlier focused and direct-build evidence predating the `pressesChanged`
ownership split is superseded and is not final task evidence. No simulator
inventory or lifecycle command ran, and all tests removed real-Keychain and
live-host opt-ins. These results prove the finite contract, AppModel
application, checked no-delivery paths, and unsigned tvOS/visionOS SDK branch
compatibility. They do not prove physical Siri Remote feel, physical
Home/volume/capture/power behavior, actual focus-engine execution, signed
installation, host receipt, controller behavior, HDR/spatial output, live
Sunshine, latency, performance, power, or thermal acceptance.

## Task 3.4 generation-owned tvOS controller runtime

The tvOS product path replaces the unused connection-list monitor with a
main-actor runtime owner for actual `GCController` instances. Connect and
disconnect notifications run on the main queue. Extended and micro profiles
install complete-state `valueChangedHandler` callbacks on the controller's
main handler queue. Stop and disconnect clear those callbacks before restoring
the previous queue. Framework controller identity remains transient inside the
owner; cross-layer state contains only checked opaque device tokens, leases,
profiles, capabilities, supported-button masks, and complete finite state.

The framework-free slot runtime is owned by one current input generation. It
assigns the lowest free slot in `0...15`, issues monotonically increasing
controller-generation leases, rejects duplicate or stale device tokens, and
normalizes all triggers and sticks after rejecting nonfinite input. Disconnect
rebuilds every remaining controller's exact active-gamepad mask. A replacement
may reuse the released slot but must receive a fresh lease, so a late callback
from the old controller remains inert.

`AppModel` starts and stops the actual owner with the current tvOS media/input
generation, retains only the complete current roster, and includes its leases
in both geometry-driven and independent roster-driven platform input
applications. Reconnect, failure, remote termination, and local stop cancel the
application task, stop the owner, and clear the roster. The presentation
coordinator permits a same-source-revision update only when the normalized
input snapshot is identical and controller leases alone changed; a capability
or focus change at the same revision remains a fail-closed conflict.

Task 3.4 intentionally does not route controller state into the remote
controller registry or input transport, and it does not apply rumble, trigger,
LED, or motion feedback. Those remain task 3.5. Focus-, scene-, provider-,
replacement-, and stop-owned ordered held-state release remains task 3.6.

Retained verification consists of:

- focused evidence `/tmp/LuneX-18-3_4-focused-r2.MyATKc` with `5/5` passed,
  no skips, failures, or expected failures, and zero structured build
  diagnostics;
- related evidence `/tmp/LuneX-18-3_4-related.USzkjv` with `85/85` passed and
  zero structured diagnostics across controller, coordinator, and AppModel
  ownership paths;
- normal evidence `/tmp/LuneX-18-3_4-normal.PblBXf` with
  `1011 total / 1010 passed / 1 skipped / 0 failed`, where the sole skip is the
  explicitly disabled real-Keychain round trip;
- direct actual tvOS evidence `/tmp/LuneX-18-3_4-tvos-r2.9WJTuS` and isolated
  visionOS evidence `/tmp/LuneX-18-3_4-vision.uUQVaS`, both
  `succeeded/0 warning/0 error/0 analyzer warning` with one AIR and one
  metallib; and
- macOS, fixed iPhone, fixed iPad, fixed Apple TV, and fixed Vision Pro Debug
  evidence `/tmp/LuneX-18-3_4-builds.ygHyOW`, all `succeeded/0/0/0` with one
  AIR/metallib pair per platform; and
- repository pre-gate `/tmp/LuneX-18-3_4-repository-pre-r2.cKwJoH`, which
  passed fixture self/tree, OpenSpec strict `9/9`, pre-mark `15/50 next 3.4`,
  four identical generator hashes, exact 11-file scope, current source/test
  and no-delivery semantics, all retained evidence, privacy, reference,
  disabled opt-ins, process checks, and `git diff --check`; and
- post-mark final-state `/tmp/LuneX-18-3_4-final-state.0GVsGm`, which confirmed
  OpenSpec `16/50 next 3.5`, exact 12-file scope, the stable project hash,
  current task/source/documentation semantics, all retained evidence, and all
  proof boundaries without rerunning tests, builds, the generator, or any
  simulator operation.

The fixed UUIDs were build destinations only. Task 3.4 did not query, create,
clone, boot, install, launch, run, shut down, or delete a simulator. Real
Keychain and live-host opt-ins remained disabled. These results prove the
deterministic controller ownership contract and unsigned SDK branch
compatibility. They do not prove physical controller mapping, host receipt,
feedback behavior, signed installation, HDR or spatial output, live Sunshine,
latency, performance, power, or thermal acceptance.

## Task 3.5 controller registry routing and current-lease feedback

The tvOS controller roster now enters the existing session-owned
`RemoteControllerRegistry` as one complete high-level snapshot. Reconciliation
first builds a candidate registry, admits exact preferred slots in `0...15`,
and validates the entire replacement before committing it. Invalid duplicate,
out-of-range, or capacity-exhausted replacements leave the previous registry
and wire state unchanged. A valid replacement emits ordered disconnects,
arrivals, and complete states using the final active-controller mask, so the
existing held-state registry and later `releaseAllControllerStates()` observe
the same complete state that was sent to the host.

The routing identity is an opaque, process-local value of the form
`tv:<input generation>:<controller lease generation>:<slot>`. It carries no
vendor or framework-object identity. `AppModel` serializes complete roster
applications through one FIFO task, maps provider feedback back to the current
slot and lease only, and makes feedback for a disconnected or replaced lease
inert. A controlled A to B to C replacement test blocks the first provider send
and proves that later roster applications cannot overtake it. Only C receives
feedback and motion after the replacement completes. Motion is bounded as the
latest sample per current lease and motion type before main-actor application,
rather than an unbounded callback queue.

The actual tvOS main-actor owner derives supported feedback capability from the
current public `GCController` object. It applies default-locality continuous
Core Haptics rumble, paired left/right trigger localities when both exist,
`GCDeviceLight` color, and finite motion sampling at the admitted rate. It
restores any pre-existing extended or micro gamepad `valueChangedHandler` when
the controller disconnects or the owner stops. If a haptic engine starts but a
player cannot start, the partial player and engine are stopped immediately;
disconnect, replacement, and stop also stop all registered feedback resources.
The registry remains the capability gate, so unsupported feedback is rejected
before it reaches the actual owner.

Retained verification before the repository pre-gate consists of:

- final focused evidence `/tmp/LuneX-18-3_5-focused-final-r2.qj3Kuj` with `5/5`
  passed, no skips, failures, or expected failures, and
  `succeeded/0 error/0 warning/0 analyzer warning`;
- related evidence `/tmp/LuneX-18-3_5-related-final.xOsmvX` with `170/170`
  passed and zero structured diagnostics across remote provider/wire,
  controller contracts, tvOS remote/focus, platform coordinator/state, and the
  complete AppModel workflow;
- normal evidence `/tmp/LuneX-18-3_5-normal-final.fFbr02` with
  `1015 total / 1014 passed / 1 skipped / 0 failed`, where the sole skip is the
  explicitly disabled real-Keychain round trip;
- direct actual tvOS evidence `/tmp/LuneX-18-3_5-tvos-final.Tnldhb` with
  `succeeded/0/0/0`, one AIR, and one metallib; and
- macOS, fixed iPhone, fixed iPad, fixed Apple TV, and fixed Vision Pro Debug
  evidence `/tmp/LuneX-18-3_5-builds-final.10FtDl`, all
  `succeeded/0 error/0 warning/0 analyzer warning` with one AIR and one metallib
  per platform; and
- repository pre-gate `/tmp/LuneX-18-3_5-repository-pre.qGGaan`, which passed
  fixture self/tree, OpenSpec strict `9/9`, pre-mark `16/50 next 3.5`, four
  identical generator hashes, exact 13-file scope, current source/test and
  membership semantics, all retained evidence, privacy, clean-room/reference,
  disabled opt-ins, process checks, and `git diff --check`; and
- post-mark final-state `/tmp/LuneX-18-3_5-final-state.efZjqf`, which confirmed
  OpenSpec `17/50 next 3.6`, exact 14-file scope, the stable project hash,
  current routing, feedback, cleanup, task, and documentation semantics, all
  retained evidence, and all proof boundaries without rerunning tests, builds,
  the generator, or any simulator operation.

An earlier final-candidate focused run had `4/5` because its AppModel test still
asserted presentation counts from before two deliberate roster applications;
the production race path completed correctly. The test now records its geometry
baseline and expects `+2/+3`, and the fresh focused evidence above is the final
result. A subsequent read-only diagnostics wrapper initially used an invalid
`jq` expression without the required spacing around `//`; corrected inspection
of the same retained xcresult confirmed all four diagnostic counts were zero.
Neither wrapper issue is production evidence.

The fixed UUIDs were build destinations only. Task 3.5 did not query, create,
clone, boot, install, launch, run, shut down, or delete a simulator. Real
Keychain and live-host opt-ins remained disabled. These results prove atomic
registry routing, deterministic current-lease feedback admission, cleanup
ownership, and unsigned SDK branch compatibility. They do not prove physical
controller mapping or haptics/light/motion behavior, host receipt, the complete
focus/scene/provider/replacement/stop ordered release barrier reserved for task
3.6, signed installation, HDR or spatial output, live Sunshine, latency,
performance, power, or thermal acceptance.

## Task 3.6 ordered held-state release and local navigation restoration

`TVRemoteSurfacePressCaptureOwner` now executes every reducer effect through one
main-actor FIFO rather than extracting only remote press deliveries. A release
operation closes actual admission, removes current controller handlers, sends
balanced remote-button ups in reducer order, joins the existing input
provider's release barrier, and only then restores local navigation. Each FIFO
operation owns its own UUID-keyed release count, so completion of an older
operation cannot clear a newer pending release, including after explicit owner
invalidation and reuse.

Actual admission is separate from desired capture ownership. A private UUID
intent token changes whenever surface or ownership intent changes and on
invalidation, avoiding numeric revision wraparound. An admission open must
match that token, the current surface, current input generation, current stream
ownership, and a nonfailed generation both before the side effect and before
the owner records admission. This suppresses an obsolete open in queued
`release(A), open(B), release(B), open(C)` surface replacement and prevents a
terminal release from restarting controller handlers. Duplicate eligible and
semantic-revision-only updates preserve a legitimate pending open.

`AppModel` applies the same effects to the current tvOS generation. Handler
removal stops the actual `TVGameControllerRuntimeOwner`, clears pending
feedback/motion, and joins roster application, registry routing, and motion
delivery tasks. The barrier then calls the existing
`NativeSessionMediaEnvironment.releaseInput` application path; no second held
registry or release provider exists. Local overlay/focus is restored only after
a completed release and is not flashed during replacement. A fresh eligible
open restarts controller observation only after the barrier. Roster, routing,
motion, feedback, and surface press admission all remain closed while any
release operation is pending.

Stop, reconnect, remote termination, media failure, presentation application
failure, and provider failure join the same owner FIFO before platform runtime
clear. Repeated terminal callers join current work and do not create an
additional held-state registry or stale controller restart. A provider release
failure marks that input generation failed, keeps remote admission closed, and
still completes bounded local UI restoration. A replacement admission failure
marks and closes the generation named by the open effect, not the older
delivery generation carried by the preceding release.

Final verification before the repository pre-gate consists of:

- focused evidence `/tmp/LuneX-18-3_6-focused-r5.I6eHeU` with `37/37` passed,
  no skips, failures, or expected failures, and zero structured build
  diagnostics. It includes A to B to C replacement, cross-input-generation
  replacement and admission failure, invalidate/reuse release accounting,
  overlapping terminal release, provider failure, and five AppModel terminal
  workflows;
- related evidence `/tmp/LuneX-18-3_6-related-r4.B4s4Tw` with `233/233` passed
  and zero structured diagnostics across AppModel, controller/diagnostics,
  input adapters, remote provider delivery/release, media environment,
  remote/focus ownership, and shared tvOS/visionOS presentation teardown;
- normal evidence `/tmp/LuneX-18-3_6-normal-r2.fzHNaM` with
  `1024 total / 1023 passed / 1 skipped / 0 failed`, where the sole skip is the
  explicitly disabled real-Keychain round trip, and zero structured build
  diagnostics;
- direct fixed Apple TV evidence `/tmp/LuneX-18-3_6-tvos-r4.wGNQq9` with
  `succeeded/0 warning/0 error/0 analyzer warning`, one AIR, and one metallib;
  and
- macOS, fixed iPhone, fixed iPad, fixed Apple TV, and fixed Vision Pro Debug
  evidence `/tmp/LuneX-18-3_6-builds-r2.cEhpxR`, all
  `succeeded/0 warning/0 error/0 analyzer warning` with one AIR and one
  metallib per platform; and
- repository pre-gate `/tmp/LuneX-18-3_6-repository-pre.w3TVP6`, which passed
  fixture self/tree, OpenSpec strict `9/9`, pre-mark `17/50 next 3.6`, four
  identical generator hashes, exact nine-file scope, current source/test
  membership and ordered-release semantics, all retained evidence, privacy,
  clean-room/reference, disabled opt-ins, process checks, and
  `git diff --check`; and
- post-mark final-state `/tmp/LuneX-18-3_6-final-state.a7qNA6`, which read back
  strict `9/9`, `18/50 next 3.7`, the unchanged project hash, exact ten-file
  scope, current semantics, all retained evidence, and the same repository
  boundaries without rerunning tests, builds, the generator, or simulator
  operations.

Earlier 33/35-item focused, 229/231-item related, direct-build, normal, and
five-platform candidates predate the final generation-failure and per-operation
accounting corrections and are not final task evidence. One related candidate
also exposed a test-only wait race between coordinator readiness and AppModel
admission; the test now waits for both without changing production macOS input
behavior.

The fixed UUIDs were build destinations only. Task 3.6 did not query, create,
clone, boot, install, launch, run, shut down, or delete a simulator. Real
Keychain and live-host opt-ins remained disabled. These results prove the
deterministic FIFO, generation and failure fences, application ordering, and
unsigned SDK branch compatibility. They do not prove simulator navigation or
Siri Remote callbacks, a signed install, physical controller/remote behavior,
host receipt, television HDR, spatial audio, live Sunshine, latency,
performance, power, or thermal acceptance.

## Task 3.7 complete tvOS input regression and provider wire closure

Task 3.7 audits every tvOS input behavior from Tasks 3.1 through 3.6 across
the reducer, actual surface owner, AppModel, controller runtime, and existing
Moonlight input provider. The audit found that the application and fake media
environment preserved balanced `.tvRemote` order, but the production provider
still passed that UI event to `RemoteInputWireCodec`, where it was explicitly
unsupported.

The provider now resolves admitted tvOS presses before encoding:

- directional presses become the corresponding Win32 arrow virtual keys;
- Select becomes Return;
- Play/Pause becomes the media Play/Pause virtual key; and
- Menu and SwiftUI focus identity remain unsupported at the provider boundary.

The resolved keyboard event, rather than the UI-specific source event, enters
the existing held-key registry and Moonlight keyboard wire codec. This reuses
the existing reliable channel and ordered release barrier, produces reverse
admission-order key-up packets exactly once, and introduces no tvOS-specific
protocol packet. The legacy value adapter also reserves Menu locally in every
stream state and never serializes SwiftUI focus item identity.

Final retained evidence is:

- focused `/tmp/LuneX-18-3_7-focused-r3.g0X36e`: `7/7` passed;
- related `/tmp/LuneX-18-3_7-related-r2.2QaiwN`: `236/236` passed across the
  eight actual tvOS input-related test suites;
- normal `/tmp/LuneX-18-3_7-normal.WCovl0`: `1027 total / 1026 passed / 1
  exact real-Keychain opt-in skip / 0 failed`;
- fixed Apple TV build `/tmp/LuneX-18-3_7-tvos.PwAk1O`: zero structured
  diagnostics and one AIR/metallib pair; and
- five-platform Debug builds `/tmp/LuneX-18-3_7-builds.N3IHzH`: macOS, fixed
  iPhone, fixed iPad, fixed Apple TV, and fixed Vision Pro all have zero
  structured diagnostics and one AIR/metallib pair each.

The first focused wire candidate stopped during test compilation because an
expected key-code array inferred `Int` instead of `UInt16`. The first related
candidate then showed that an old inactive-stream test used Menu to assert a
generic inactive reason; it now uses supported Select, preserving both the
inactive-stream and always-local Menu contracts. Neither candidate is final
evidence.

Repository acceptance is retained in:

- pre-mark `/tmp/LuneX-18-3_7-repository-pre-r3.QRSRb6`, which passed fixture
  self/tree, strict `9/9`, `18/50 next 3.7`, four stable generator hashes,
  exact twelve-file scope, membership, current input semantics, all retained
  results, and repository boundaries; and
- post-mark `/tmp/LuneX-18-3_7-final-state.fKKBFH`, which read back strict
  `9/9`, `19/50 next 4.1`, the unchanged project hash, exact thirteen-file
  scope, current source/task/tests, all retained results, and the same
  boundaries without rerunning tests, builds, the generator, or simulator
  operations.

The fixed UUIDs were build destinations only. Task 3.7 did not query, create,
clone, boot, install, launch, run, shut down, or delete a simulator. Real
Keychain and live-host opt-ins remained disabled. These results prove local
focus privacy, provider-side canonical packet order, deterministic controller
ownership, stale-callback rejection, and unsigned SDK compatibility. They do
not prove Siri Remote feel, host receipt, a simulator callback, signed install,
physical controller feedback, HDR, spatial audio, latency, performance, power,
or thermal behavior.

## Task 4.1 actual tvOS frame presentation

The task 4.1 candidate connects the existing production coordinator to the
actual Metal presenter without adding another decoder, frame source, queue, or
platform transport. `AppModel` creates one `TVVisionMetalPresentationOwner`
and injects it into the default `NativeSessionMediaEnvironment`. The actual
SwiftUI tvOS/visionOS Metal surface binds that same owner to its presenter and
checked surface generation.

Once the owner binds a presenter, platform frame admission is closed by
default. `StreamMetalPresenter` no longer reads
`StreamVideoPresentationSource.currentFrame()` in that mode. Only a decoded
frame application accepted by the coordinator owner becomes presentable. The
owner checks exact platform and session identity, lexicographically newer
media/presentation/input replacement ownership, nondecreasing action,
platform and delivery revisions, consistent decoder/frame identity, and an
exact coordinator/presenter/frame surface generation. A foreign session with
a higher media generation remains inert; a same-session input-only replacement
is valid when newer.

Scene detach, inactivity, invisibility, invalid geometry, explicit display
unavailability, clear, terminal teardown, surface unbind, and presenter stop
all close actual presentation. Surface rebind restores a retained frame only
when the presenter, scene, frame, and coordinator surface generations match.
Geometry may resubmit the same current delivery under a newer platform
revision; accepting a new platform frame advances the presenter's draw fence
so an in-flight old frame cannot submit afterward. Repeated clear while
already blank is idempotent.

Display state may still be unknown in task 4.1 because the actual public tvOS
probe belongs to 4.2. Unknown permits only the existing baseline SDR path; it
does not publish HDR capability, EDR headroom, or active HDR. Explicitly
unavailable display state clears video and suppresses a late frame.

Retained pre-mark evidence is:

- focused `/tmp/LuneX-18-4_1-focused-r6.EoFPrA`: `8/8` passed with zero
  structured diagnostics;
- related `/tmp/LuneX-18-4_1-related-r2.ymJCRP`: `241/241` passed across the
  presenter, coordinator/state, environment, AppModel, frame, and HDR-related
  suites with zero structured diagnostics;
- normal `/tmp/LuneX-18-4_1-normal.nHnZZj`: `1035 total / 1034 passed / 1
  exact real-Keychain opt-in skip / 0 failed`, with zero structured
  diagnostics;
- fixed Apple TV build `/tmp/LuneX-18-4_1-tvos.4dvUQ4`: zero structured
  diagnostics and one AIR/metallib pair; and
- unsigned five-platform Debug matrix
  `/tmp/LuneX-18-4_1-builds-r2.Pl3YcW`: macOS, fixed iPhone, fixed iPad,
  fixed Apple TV, and fixed Vision Pro all succeeded with zero structured
  diagnostics and one AIR/metallib pair each.

The first five-platform candidate stopped before source compilation because
the macOS entitlement required a development certificate. The retained matrix
uses `CODE_SIGNING_ALLOWED=NO` and is explicitly unsigned build proof, not a
signed artifact. Fixed simulator UUIDs were build destinations only; task 4.1
did not query, create, clone, boot, install, launch, run, shut down, or delete a
simulator. Real Keychain and live-host opt-ins remained disabled. These gates
do not prove an Apple TV drawable or television output, signed installation,
live Sunshine, HDR/EDR, spatial audio, latency, performance, power, or thermal
behavior. Repository pre-gate
`/tmp/LuneX-18-4_1-repository-pre.cIhA16` passed fixture self/tree, OpenSpec
strict `9/9`, pre-mark `19/50 next 4.1`, four stable generator hashes, exact
thirteen-file scope, source/project membership, current owner/admission/
revision/clear/replacement semantics, every retained result, and privacy,
clean-room, reference, opt-in, process, and diff boundaries. Task 4.1 is now
marked complete; the expected authoritative state is `20/50 next 4.2` pending
read-only final-state verification. Post-mark final-state
`/tmp/LuneX-18-4_1-final-state-r2.BFSidM` then confirmed strict `9/9`, exact
`20/50 next 4.2`, the stable project hash, exact fourteen-file scope, current
task/source/test/docs semantics, all retained evidence, and the same repository
boundaries without rerunning tests, builds, the generator, or simulator
operations.

## Task 4.2 public tvOS dynamic-range capability

Task 4.2 establishes a public, injectable tvOS 26.4 display/layer/color
capability and a rollback-capable Metal surface transaction. It does not yet
observe the actual stream scene or publish an AppModel HDR revision; that
application boundary remains task 4.3.

The public tvOS path is distinct from the legacy macOS/iOS/visionOS
`wantsExtendedDynamicRangeContent` and EDR metadata path. It uses:

- `CALayer.preferredDynamicRange` with `.high` for admitted EDR and `.standard`
  for SDR;
- `CALayer.toneMapMode` with `.never` for admitted EDR and `.automatic` for
  SDR;
- `CALayer.contentsHeadroom`, carrying a finite admitted current headroom for
  EDR and zero for SDR;
- `UIScreen.currentEDRHeadroom` and `potentialEDRHeadroom`; and
- constructible extended-linear Display P3 or ITU-R 2020 CoreGraphics color
  spaces.

`TVOSDisplayHDRCapabilityResolver` admits direct EDR only when the actual
output and layer exist, all three layer controls are available, at least one
extended-linear gamut is available, and headroom satisfies
`1 < current <= potential <= 64`. Missing headroom is distinct from invalid
headroom and from finite SDR-only headroom. Nonfinite and out-of-range values
are normalized to `nil` before they enter the `Equatable` capability snapshot,
while the resolution preserves its typed `.invalidHeadroom` reason. This keeps
future semantic revision deduplication stable.

The shared render capability now models this as
`preferredDynamicRangeAndHeadroom`, rather than claiming the legacy
`intentAndMetadata` contract. An EDR `HDRSurfaceContract` for this path must
carry finite current content headroom greater than one; an untagged preferred
EDR contract is unsupported, and SDR contracts cannot carry content headroom.
The EDR transaction orders float drawable format, extended-linear color space,
tone-map `.never`, finite content headroom, then preferred range `.high`.
Returning to SDR first selects standard range, then automatic tone mapping,
zero headroom, SDR format, and sRGB. Native snapshots and rollback cover view
and layer pixel formats, color space, legacy intent/metadata, preferred dynamic
range, tone-map mode, and content headroom.

Fresh pre-mark evidence after the final headroom-normalization revision is:

- focused `/tmp/LuneX-18-4_2-focused-r3.uUoogT`: `54/54 passed / 0 skipped /
  0 failed / 0 expected failure`, with zero structured build diagnostics;
- related `/tmp/LuneX-18-4_2-related-r2.X5RkJV`: `209/209 passed` across HDR
  contract/resolver/surface, Metal pipeline/shader/renderer/status, frame
  delivery, presenter, macOS/mobile display, and tvOS state/coordinator suites,
  with zero structured and source diagnostics;
- normal `/tmp/LuneX-18-4_2-normal-r2.q9nMOC`: `1040 total / 1039 passed / 1
  exact real-Keychain opt-in skip / 0 failed / 0 expected failure`, with zero
  structured and source diagnostics;
- fixed Apple TV direct build `/tmp/LuneX-18-4_2-tvos-r2.gAirdH`: unsigned
  Debug success with zero structured/source diagnostics and one AIR/metallib
  pair; and
- unsigned five-platform Debug matrix
  `/tmp/LuneX-18-4_2-builds-r2.9ndfoH`: macOS, fixed iPhone, fixed iPad, fixed
  Apple TV, and fixed Vision Pro all succeeded with zero structured/source
  diagnostics and one AIR/metallib pair each.

The fixed UUIDs were build destinations only. Task 4.2 did not query, create,
clone, boot, install, launch, run, shut down, or delete a simulator. Real
Keychain and live-host opt-ins remained unset. These results prove deterministic
capability/fallback semantics, public SDK compilation, surface transaction and
rollback behavior, and cross-platform source compatibility. They do not prove
that an Apple TV compositor entered HDR, television panel brightness or color,
HDMI mode negotiation, a signed install, physical hardware, live Sunshine HDR,
latency, performance, power, or thermal behavior. Repository pre-gate
`/tmp/LuneX-18-4_2-repository-pre.IRGscf` passed fixture self/tree, OpenSpec
strict `9/9`, pre-mark `20/50 next 4.2`, four stable generator hashes, exact
fifteen-file scope, generator/project membership, current capability/fallback/
transaction/rollback semantics, every retained result, and privacy, clean-room,
reference, opt-in, process, and diff boundaries. Task 4.2 is now marked complete;
post-mark final-state `/tmp/LuneX-18-4_2-final-state-r2.l4fp0g` confirmed
OpenSpec strict `9/9`, exact `21/50 next 4.3`, the stable project hash, exact
sixteen-file scope, current source/task/docs and retained evidence, and the same
repository boundaries without rerunning tests, builds, the generator, or
simulator operations. Post-record
`/tmp/LuneX-18-4_2-post-record.YjRjuV` then confirmed `21/50 next 4.3`, strict
`9/9`, the same project hash and sixteen-file scope, all five authority records,
retained evidence, and opt-in/process/reference/diff boundaries.

## Task 4.3 actual tvOS display application

Task 4.3 connects the task 4.2 capability and surface contract to the actual
stream surface and current media generation. `TVVisionStreamMetalView` samples
only its own `window.windowScene.screen` and underlying `CAMetalLayer`. It
observes `UIScreen.modeDidChangeNotification` and
`UIScreen.brightnessDidChangeNotification` with a surface observation lease;
detach, surface replacement, dismantle, and stop remove the handlers before an
old callback can publish current state.

`TVOSDisplayHDRSnapshotPublisher` owns a checked display generation and bounded
semantic revision. Equivalent normalized capability snapshots deduplicate. A
stale surface generation is rejected, unavailable output carries no current or
potential headroom, and revision exhaustion closes publication. An available
output with invalid or absent current headroom may retain valid potential
headroom for truthful diagnostics, but the renderer still uses conservative
`1/1` headroom and typed SDR fallback.

The production coordinator publishes display independently from the later
audio component and records only bounded `.displayDirectEDR` or
`.displayFallback(reason)` diagnostics. `AppModel` serializes display
application after activation, scene, and input eligibility. It accepts only a
component whose platform, display generation, output availability, headroom
source/values, layer capability, and tvOS resolution match the current surface
source. The coordinator may rebrand semantic revision, so revision itself is
not treated as source identity. A newly accepted source synchronously closes
the previous render display and fallback before asynchronous application;
surface replacement, application failure, semantic-revision exhaustion,
reconnect, remote termination, and stop clear render headroom and capability.

Fresh pre-mark evidence is:

- focused `/tmp/LuneX-18-4_3-focused-final.BN6ZYp`: `190/190 passed / 0 skipped /
  0 failed / 0 expected failure`, with zero structured build diagnostics;
- related `/tmp/LuneX-18-4_3-related-final.ztmMov`: `361/361 passed / 0 skipped /
  0 failed / 0 expected failure`, with zero structured build diagnostics;
- normal `/tmp/LuneX-18-4_3-normal-final.kN6LiU`: `1047 total / 1046 passed / 1
  exact real-Keychain opt-in skip / 0 failed / 0 expected failure`, with zero
  structured build diagnostics;
- fixed Apple TV direct build `/tmp/LuneX-18-4_3-tvos-final.UlXTWd`: unsigned
  Debug success with zero structured diagnostics and one AIR/metallib pair; and
- unsigned five-platform Debug matrix
  `/tmp/LuneX-18-4_3-builds-final.u2xQ44`: macOS, fixed iPhone, fixed iPad,
  fixed Apple TV, and fixed Vision Pro all succeeded with zero structured
  Swift/Clang/Metal/analyzer diagnostics and one AIR/metallib pair each.

The five raw build logs each contain only the AppIntents metadata-tool notice
`Metadata extraction skipped. No AppIntents.framework dependency found.`; the
corresponding structured warning count is zero. Fixed UUIDs were build
destinations only. No simulator was queried, created, cloned, booted, installed,
launched, run, shut down, or deleted during task 4.3, and real-Keychain and
live-host opt-ins remained unset.

These results prove static contracts, injected current-generation behavior,
and unsigned SDK compilation/linking. They do not prove signed installation, a
running simulator, physical Apple TV screen/compositor/HDMI HDR, television
brightness or color, live Sunshine, latency, performance, power, or thermal
behavior. The shared geometry replay needed when the same `MTKView` survives a
media reconnect remains task 4.5. At the task 4.3 checkpoint, tvOS route,
spatial audio, head tracking, interruption, media reset, and recovery remained
task 4.4; the next section records its completed offline implementation.

## Task 4.4 current tvOS audio route application

Task 4.4 reuses the stage 16 audio stack rather than creating a second platform
observer or graph. `SpatialAudioPlatformNotificationSource` remains the single
source for AVAudioSession route change, interruption, media-services lost/reset,
and spatial-capability notifications. `AudioEngineRouteCapabilityReader` reads
actual output availability, current/maximum channels, and spatial support from
the production engine client. `NativeSessionAudioProcessor` serializes those
changes with preferences, entitlement, canonical graph rebuild, listener head-
tracking readback, scheduled-buffer completion isolation, and monotonic graph
generation.

`SessionAudioRuntimeEvent` now carries the actual route-capability snapshot and
entitlement alongside stage, cause, spatial runtime/readback, preferences, and
graph generation. `TVOSAudioRouteSnapshotPublisher` converts only a valid tvOS
runtime into a checked platform snapshot. It rejects duplicate event sequence,
older graph generation, mismatched route/spatial revision, invalid channel
counts, visionOS strategy, spatial mode without a compatible strategy, and
head tracking without granted entitlement. Equivalent normalized states
deduplicate; interruption retains the route while marking the runtime stage,
media-service loss publishes unavailable output with no active spatial claim,
and reset/recovery must use the current graph generation. Revision exhaustion
is distinct from invalid runtime and permanently closes that publisher.

`NativeSessionMediaEnvironment` stores one publisher per media generation. It
replays the latest valid runtime when current tvOS presentation ownership
activates or is replaced, applies later runtime events only while session,
media generation, platform, ownership, and event session still match, and
publishes the coordinator result to AppModel. Invalid runtime becomes
`.invalidComponent(.audioRoute)`; an action-client failure becomes
`.actionFailed(.audioRoute)`; semantic exhaustion remains typed. Active
coordinator snapshots expose audio independently and complete presentation
snapshots rebrand it with the shared revision. Failure and stop clear both the
independent route and complete presentation, cancel the current video
subscription, and keep late old-generation events inert.

Final offline evidence is:

- publisher tests: `/tmp/LuneX-18-4_4-publisher-r1.vvbAXA`, `27/27 passed`;
- environment tests: `/tmp/LuneX-18-4_4-environment-r1.fhwxMz`, `3/3 passed`,
  with zero structured build diagnostics;
- AppModel tests: `/tmp/LuneX-18-4_4-appmodel-r2.FpHLzs`, `2/2 passed`, with
  zero structured build diagnostics;
- focused `/tmp/LuneX-18-4_4-focused-final.RfLgmT`: `248/248 passed / 0
  skipped / 0 failed / 0 expected failure`, with zero structured diagnostics;
- related `/tmp/LuneX-18-4_4-related-final.dg14Fj`: `332/332 passed / 0 skipped
  / 0 failed / 0 expected failure`, with zero structured diagnostics;
- normal `/tmp/LuneX-18-4_4-normal-final.NH3JbN`: `1054 total / 1053 passed /
  1 exact real-Keychain opt-in skip / 0 failed / 0 expected failure`, with zero
  structured diagnostics;
- fixed Apple TV direct build `/tmp/LuneX-18-4_4-tvos-final.3bnJ39`: unsigned
  Debug success, zero structured diagnostics, and one AIR/metallib pair; and
- unsigned five-platform Debug matrix
  `/tmp/LuneX-18-4_4-builds-final.OmDAeS`: macOS, fixed iPhone, fixed iPad,
  fixed Apple TV, and fixed Vision Pro all succeeded with zero structured
  Swift/Clang/Metal/analyzer diagnostics and one AIR/metallib pair each; and
- repository pre-gate `/tmp/LuneX-18-4_4-repository-pre-r3.FrvzgU`, which
  passed fixture self/tree, OpenSpec strict `9/9`, pre-mark `22/50 next 4.4`,
  three identical generator hashes, exact 18-file scope, source/test
  membership, current-generation/replay/failure/terminal semantics, all
  retained result evidence, privacy/clean-room/reference/dependency boundaries,
  disabled opt-ins, no residual test process, and `git diff --check`.

The read-only post-mark final-state at
`/tmp/LuneX-18-4_4-final-state.gObCd6` confirmed OpenSpec strict `9/9`,
`23/50 next 4.5`, task 4.4 done, the stable project hash, exact 19-file scope,
all retained evidence, and repository boundaries without rerunning tests,
builds, the generator, or any simulator operation.

Real-Keychain and live-host opt-ins remained unset. Fixed UUIDs were build
destinations only; task 4.4 did not query, create, clone, boot, install, launch,
run, shut down, or delete a simulator. The tests and unsigned builds prove the
actual notification-to-canonical-runtime data contract, deterministic graph
generation/recovery, current-generation application, stale/replacement
isolation, terminal clearing, AppModel projection, and SDK compatibility. They
do not prove a signed Apple TV installation, a physical route transition,
AirPods spatial audio, audible channel correctness, listener head-tracking
motion, live Sunshine, latency, performance, power, or thermal behavior.
visionOS intended-spatial application remains task 6.4. Same-view reconnect
replay and one shared video/audio/input teardown remain task 4.5.

## Task 4.5 shared generation reconnect and teardown

Task 4.5 closes the same-view reconnect gap without adding a parallel runtime.
`TVVisionUIKitStreamGeometryBindingOwner.replayCurrentUpdate` requires the
exact current surface identity and surface generation, rejects invalidated
ownership, republishes only its current normalized update, and does not advance
the geometry semantic revision. `TVOSDisplayHDRObserver.replayCurrentEvent`
requires the same current surface generation, rejects invalidation, republishes
the current display snapshot or the already-exhausted typed terminal event, and
does not advance the display semantic revision.

When `TVVisionStreamMetalView` receives a new application binding for unchanged
render inputs, it replays geometry first and then the tvOS display event. A
newly published geometry update already invokes the current handler and is not
duplicated. Closed, stale, exhausted, or invalidated geometry stops the replay
before display. This preserves one surface owner and one display observer and
lets `AppModel`'s current session/media/ownership admission rebuild replacement
application in the order `activate`, scene, input, display. The current audio
route remains independently replayed by the existing single native media
environment and bounded audio publisher; task 4.5 adds no decoder, frame queue,
audio observer, or audio graph.

The shared terminal path remains coordinator- and environment-owned. A remote
termination racing local environment stop preserves `.remoteTermination`,
publishes one terminal snapshot, runs one coordinator teardown effect, clears
presentation/display/audio route and video presentation, cancels the decoded
frame subscription, and stops each video receiver, audio receiver, input
receiver, video processor, and audio processor exactly once. Provider failure,
local/concurrent stop, replacement, and late frame/callback coverage continue
to use that same bounded terminal and resource ownership.

Final offline evidence is:

- current-value replay `/tmp/LuneX-18-4_5-minimal.Jo7NGA`: `2/2 passed`;
- AppModel reconnect `/tmp/LuneX-18-4_5-reconnect.fzySX5`: `1/1 passed`;
- remote/local terminal race `/tmp/LuneX-18-4_5-remote-r2.MSafes`: `1/1
  passed`;
- focused `/tmp/LuneX-18-4_5-focused-final.EhLafe`: `248/248 passed / 0
  skipped / 0 failed / 0 expected failure`, with zero structured diagnostics;
- related `/tmp/LuneX-18-4_5-related-final.C3tjgy`: `474/474 passed / 0
  skipped / 0 failed / 0 expected failure`, with zero structured diagnostics;
- normal `/tmp/LuneX-18-4_5-normal-final.1mF6gc`: `1055 total / 1054 passed /
  1 exact real-Keychain opt-in skip / 0 failed / 0 expected failure`, with zero
  structured diagnostics;
- fixed Apple TV direct `/tmp/LuneX-18-4_5-tvos-final.UNpi51`: unsigned Debug
  success, zero structured diagnostics, and one AIR/metallib pair; and
- unsigned five-platform Debug `/tmp/LuneX-18-4_5-builds-final.13Nwur`:
  macOS, fixed iPhone, fixed iPad, fixed Apple TV, and fixed Vision Pro all
  succeeded with zero structured diagnostics and one AIR/metallib pair each.

Repository pre-gate `/tmp/LuneX-18-4_5-repository-pre.4s9qBy` passed fixture
self/tree validation, OpenSpec strict `9/9`, pre-mark `23/50 next 4.5`, three
stable generator hashes, exact 13-file scope, source/test membership,
current-value replay/order/generation/shared-teardown semantics, all retained
test/build evidence, and privacy, clean-room, reference, dependency, opt-in,
process, and diff boundaries. Task 4.5 is therefore marked complete; OpenSpec
is `24/50 ready`, with task 4.6 next.

The read-only post-mark final-state at
`/tmp/LuneX-18-4_5-final-state.5ZgeJt` confirmed OpenSpec strict `9/9`,
`24/50 next 4.6`, task 4.5 done, the stable project hash, exact 14-file scope,
final authority records, all retained evidence, and repository boundaries
without rerunning tests, builds, the generator, or any simulator operation.

Post-record `/tmp/LuneX-18-4_5-post-record.5B9rw1` and final audit
`/tmp/LuneX-18-4_5-final-audit.ASK927` confirmed the 14-file authority scope,
the two production and four test files, replay identity/generation/revision
ordering, replacement terminal/resource teardown, no second runtime, no new
optional error suppression or privacy sink, retained evidence, and proof
boundaries. No additional implementation issue was found.

Real-Keychain and live-host opt-ins remained unset, so normal tests continued
to use file or in-memory persistence. Fixed simulator UUIDs were destinations
only; task 4.5 did not query, create, clone, boot, install, launch, run, shut
down, or delete a simulator. These tests and unsigned builds prove deterministic
replay, generation admission, terminal/resource idempotence, and SDK
compatibility. They do not prove signed installation, Simulator runtime,
physical Apple TV input/HDR/audio/head tracking, live Sunshine, latency,
performance, power, or thermal behavior. Task 4.6 remains the consolidated
tvOS media regression matrix, and visionOS work remains in tasks 5.x and 6.x.

## Task 4.6 consolidated tvOS media regression matrix

Task 4.6 adds no production source or alternate media path. The new coordinator
regression uses the existing scene, display, frame, audio-route, and stop APIs
as one ordered current-generation sequence. It begins with nonfinite current
headroom and a typed HDR-to-SDR resolution, presents decoder generation 7 frame
90, resubmits that frame after geometry revision 2, applies current direct EDR,
starts decoder generation 8, and rejects a late generation 7 frame. It then
applies interruption, media-services loss with unavailable output, graph
generation 2 reset/head tracking, current-graph recovery, and one local stop.
The terminal state has no presentation, display, or audio route, no presented
video, teardown count one, and exactly one recorded coordinator teardown
effect.

The existing AppModel current/reconnect/replacement/remote-termination workflow
now also observes public actual render and audio state: direct headroom `2`, no
fallback diagnostic, current head-tracked presentation, replacement audio
route generation `2` with fixed spatial presentation, and render/fallback
clearing during reconnect and terminal teardown. Test helpers retain their old
defaults, and no production seam or state was added for the tests.

Fresh offline evidence is:

- coordinator matrix `/tmp/LuneX-18-4_6-matrix-r2.v9KJoh`: `1/1 passed`;
- cross-layer matrix `/tmp/LuneX-18-4_6-cross-layer.NGWR17`: `2/2 passed`;
- focused `/tmp/LuneX-18-4_6-focused-final.snkyaA`: `249/249 passed / 0
  skipped / 0 failed / 0 expected failure`, with zero structured diagnostics;
- related `/tmp/LuneX-18-4_6-related-final-r2.gN1qLv`: `474/474 passed / 0
  skipped / 0 failed / 0 expected failure`, with zero structured diagnostics;
- normal `/tmp/LuneX-18-4_6-normal-final.FweI69`: `1056 total / 1055 passed /
  1 exact real-Keychain opt-in skip / 0 failed / 0 expected failure`, with zero
  structured diagnostics;
- fixed Apple TV direct `/tmp/LuneX-18-4_6-tvos-final.bVvyiw`: unsigned Debug
  success, zero structured diagnostics, and one AIR/metallib pair; and
- unsigned five-platform Debug `/tmp/LuneX-18-4_6-builds-final.njC11Q`:
  macOS, fixed iPhone, fixed iPad, fixed Apple TV, and fixed Vision Pro all
  succeeded with zero structured diagnostics and one AIR/metallib pair each.

Real-Keychain and live-host opt-ins remained unset. The fixed device UUIDs were
build destinations only; task 4.6 did not query, create, clone, boot, install,
launch, run, shut down, or delete a simulator. This evidence proves deterministic
offline sequencing, public-state projection, terminal clearing, and SDK
compatibility only. It does not prove signed installation, Simulator runtime,
physical Apple TV SDR/HDR, spatial audio or listener head tracking, live
Sunshine, latency, performance, power, or thermal behavior. At this pre-mark
checkpoint task 4.6 remained unchecked pending the fresh repository gate.

Repository pre-gate `/tmp/LuneX-18-4_6-repository-pre.jpqOgA` passed fixture
self/tree validation, OpenSpec strict `9/9`, pre-mark `24/50 next 4.6`, four
stable generator hashes, exact nine-file test-and-authority scope, consolidated
sequence and public-state semantics, all retained test/build evidence, and
privacy, clean-room, reference, dependency, opt-in, process, and diff
boundaries. Task 4.6 is therefore marked complete; OpenSpec is `25/50 ready`,
with visionOS task 5.1 next.

Post-mark final-state `/tmp/LuneX-18-4_6-final-state-r2.0Oe6dd` read-only
confirmed OpenSpec strict `9/9`, `25/50 next 5.1`, task 4.6 done, the stable
project SHA-256, exact ten-file test-and-authority scope, empty production and
project-graph diff, all retained behavioral and build evidence, the exact
Keychain skip, and privacy, reference, dependency, opt-in, process, and diff
boundaries. It did not rerun tests, builds, the generator, or Simulator work.

Post-record `/tmp/LuneX-18-4_6-post-record.4dFTZB` and final audit
`/tmp/LuneX-18-4_6-final-audit.mNUBR2` confirmed the same ten-file scope,
two test files and eight authority files, helper-default compatibility,
connected matrix and public-state assertions, no async XCTest autoclosure,
no production or project-graph change, no removed contract, and all proof
boundaries. Task 4.6 is ready for its independent commit and push.

## Task 5.1 actual visionOS window observation

Task 5.1 extends the existing `TVVisionStreamMetalView`; it does not create a
second stream surface, scene runtime, geometry owner, decoder, presenter, or
input adapter. A checked surface-generation observer weakly owns the current
`UIWindow` and `UIWindowScene` identities and installs the public visible,
hidden, key, resign-key, active, inactive, background, and foreground
notifications. Replacement of either identity removes the complete old token
set before installing the new one. Each queued callback also carries an
observation UUID and must match the current UUID, generation, live weak window,
and live weak scene before it can publish an existing surface callback.

The actual surface callback reader continues to derive attachment, scene,
visibility, scale, and drawable size from the current `MTKView` and its window.
visionOS focus eligibility is true only for a visible, user-interactive stream
surface in the current key window. tvOS retains its existing visible,
interactive, focus-engine `canBecomeFocused` rule. The observer itself does not
write drawable size or advance geometry revisions; the existing generation
owner validates actual state and the existing geometry binding owner remains
the single drawable and semantic-revision writer. Current visionOS AppModel
coverage confirms `activate` then scene application, newer surface replacement,
old-generation rejection, current detach publication, and terminal clearing,
without producing a tvOS input action.

Fresh deterministic and build evidence is:

- observer and AppModel minimal `/tmp/LuneX-18-5_1-minimal-r2.rTbf7R`: `2/2
  passed`, zero structured diagnostics;
- focused `/tmp/LuneX-18-5_1-focused.2cR6CT`: `219/219 passed / 0 skipped / 0
  failed / 0 expected failure`, zero structured diagnostics;
- related `/tmp/LuneX-18-5_1-related.52fA7X`: `121/121 passed / 0 skipped / 0
  failed / 0 expected failure`, zero structured diagnostics;
- normal `/tmp/LuneX-18-5_1-normal.CJi9Ut`: `1058 total / 1057 passed / 1
  exact real-Keychain opt-in skip / 0 failed / 0 expected failure`, zero
  structured diagnostics;
- fixed Vision Pro direct `/tmp/LuneX-18-5_1-visionos-compile.8NsiO6` and
  fixed Apple TV direct `/tmp/LuneX-18-5_1-tvos.r5KL4H`: unsigned Debug
  success, zero structured diagnostics, and one AIR/metallib pair each; and
- unsigned five-platform Debug `/tmp/LuneX-18-5_1-builds.K3hUMY`: macOS,
  fixed iPhone, fixed iPad, fixed Apple TV, and fixed Vision Pro all succeeded
  with zero structured diagnostics and one AIR/metallib pair each.

Real-Keychain and live-host opt-ins remained unset. Fixed UUIDs were used only
as build destinations; task 5.1 did not query, create, clone, boot, install,
launch, run, shut down, or delete a simulator. These tests prove deterministic
observer ownership, replacement admission, shared presentation application,
public SDK compilation, and cross-target compatibility. They do not prove a
Simulator window session, signed installation, physical Vision Pro focus or
resize behavior, keyboard/pointer/controller input, gaze/hand interaction,
HDR, intended spatial audio, live Sunshine, comfort, latency, performance,
power, or thermal behavior. Tasks 5.2, 5.3, and 6.x remain separate.

Repository pre-gate `/tmp/LuneX-18-5_1-repository-pre.v1iwKK` passed fixture
self/tree validation, OpenSpec strict `9/9`, pre-mark `25/50 next 5.1`, three
stable generator runs at project SHA-256
`ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`, exact
ten-file implementation, test, and authority scope, observer/generation/owner
semantics, all retained test and build evidence, and privacy, clean-room,
reference, dependency, opt-in, process, and diff boundaries. Task 5.1 is
therefore marked complete; OpenSpec is expected to be `26/50 ready` with task
5.2 next, subject to the read-only post-mark final-state gate.

Post-mark final-state `/tmp/LuneX-18-5_1-final-state.BQG3yQ` read-only
confirmed OpenSpec strict `9/9`, `26/50 ready`, task 5.1 done, task 5.2 next,
the same stable project SHA-256, exact eleven-file implementation, test, and
authority scope, observer ownership and platform focus boundaries, all
retained test/build evidence, the exact Keychain skip, and opt-in, process,
reference, dependency, and diff boundaries. It did not rerun tests, builds,
the generator, or Simulator work.

Post-record `/tmp/LuneX-18-5_1-post-record-r3.jAEfZ5` and final audit
`/tmp/LuneX-18-5_1-final-audit.U5fWgQ` confirmed the same eleven-file scope,
one production file, two test files, and eight authority files; checked
generation, weak window/scene ownership, token replacement, observation-UUID
late admission, platform-specific focus eligibility, single geometry writer,
test membership, no async XCTest autoclosure, no out-of-scope input/media
runtime, no removed contract, and all proof boundaries. Task 5.1 is ready for
its independent commit and push.

## Task 5.2 visionOS geometry render and input binding

Task 5.2 deliberately adds no production mapper. Task 2.3 already established
`TVVisionUIKitStreamGeometryBindingOwner` as the single actual-view owner for
finite normalized bounds/scale, drawable sizing, fit/fill
`StreamCoordinateSnapshot`, resolved video rectangle/source crop, input
reference size, and `TVVisionStreamAbsoluteInputMapping`. Task 5.1 connected
that owner to actual visionOS window identity and lifecycle. Creating a second
visionOS geometry or input owner here would split revisions and violate the
single-writer contract.

The actual SwiftUI surface update order is part of the contract. It first
synchronizes source size and requested fit/fill mode into the current render
state, then calls the existing geometry binding owner and applies its exact
coordinate snapshot through `MobileStreamSurfaceCoordinator`. A matching
render snapshot and absolute input mapping therefore carry the same
`TVVisionSemanticRevision`. A mode mismatch fails closed rather than allowing
rendering and input to observe different crops. Detach, unavailable
coordinates, nonfinite bounds, or invalid drawable geometry clear drawable
size, presenter coordinates, and absolute input mapping together; a later
valid attachment may establish a new current revision.

`testVisionGeometryBindsFitFillRenderAndAbsoluteInputThenCloses` provides the
integrated deterministic receipt. With a 1920 by 1080 source and 800 by 600
drawable, fit maps the local left-center point to remote `(0, 540)`. After the
render state is changed to fill before geometry publication, the next shared
revision maps the same point to approximately `(240, 540)`, proving that input
uses the presenter's crop-aware resolved rectangle. Detach clears drawable,
render coordinates, and mapping; reattachment restores them; a subsequent
nonfinite view bound produces `invalidViewBounds` and clears all three again.
This verifies the existing production binding without installing a test-only
production seam or completing task 5.3 input adapters.

Fresh retained evidence is:

- minimal integrated test `/tmp/LuneX-18-5_2-minimal-r3.luBq4W`: `1/1`
  passed, no skip/failure/expected failure, and all four structured build
  diagnostic counts zero;
- complete presenter `/tmp/LuneX-18-5_2-presenter.7h2rAT`: `71/71`, cross-layer
  focused `/tmp/LuneX-18-5_2-focused.wM0NK4`: `220/220`, and related
  `/tmp/LuneX-18-5_2-related.slZmgu`: `121/121`, all passed with zero structured
  build diagnostics;
- normal `/tmp/LuneX-18-5_2-normal.TjccHx`: `1059 total / 1058 passed / 1
  skipped / 0 failed / 0 expected failure`; the only skipped test is the
  explicitly opt-in real-Keychain round trip;
- fixed Vision Pro direct `/tmp/LuneX-18-5_2-visionos.ags3s2` and unsigned
  five-platform Debug `/tmp/LuneX-18-5_2-builds.gqJzlP`: macOS, fixed iPhone,
  iPad, Apple TV, and Vision Pro all succeeded with zero warning, error, or
  analyzer-warning diagnostics and each produced one AIR plus one metallib.

The fixed device UUIDs were used only as build destinations. No simulator was
queried, created, booted, installed, launched, shut down, or deleted, and the
real-Keychain/live-host opt-ins remained disabled. These receipts prove
deterministic mapping semantics and unsigned SDK compatibility only. They do
not prove signed install, simulator runtime, physical Vision Pro resize,
keyboard/pointer/controller delivery, gaze or hand interaction, HDR, spatial
audio, live Sunshine, latency, comfort, performance, power, or thermal
behavior. Task 5.3 still owns actual public input adapters and current-
generation event admission; tasks 6.x still own visionOS media, HDR, and audio.

Fresh repository pre-gate
`/tmp/LuneX-18-5_2-repository-pre-r2.Jwvbum` passed fixture self/tree,
OpenSpec strict `9/9`, pre-mark `26/50` with task 5.2 next, three stable project
generations at SHA-256
`ef2e3e615f1dbd84b76bfe4c8681fab7d44291176f06324acd757fa1c1008353`,
the exact eight-file test/authority scope, zero production/dependency/reference
diff, test membership, integrated fit/fill/revision/close semantics, all
retained structured test/build/Metal evidence, the exact Keychain skip,
disabled opt-ins, no owned test/build process, and `git diff --check`. Task 5.2
is ready to mark complete; the required post-mark gate is read-only and must
not repeat tests, builds, generator work, Keychain access, or Simulator work.

The corrected read-only post-mark final-state
`/tmp/LuneX-18-5_2-final-state-r2.0VX1j5` confirmed OpenSpec strict `9/9`,
`27/50 ready`, task 5.2 done, task 5.3 next, the stable project SHA-256, the
exact nine-file test/authority scope, zero production/dependency/reference
diff, every retained test/build result, the exact Keychain skip, disabled
opt-ins, no owned test/build process, and `git diff --check`. It did not rerun
tests, builds, the generator, Keychain access, or Simulator work.

Post-record `/tmp/LuneX-18-5_2-post-record-r2.d3bpX7` and final audit
`/tmp/LuneX-18-5_2-final-audit.YC6Bfa` confirmed the exact nine-file scope:
one test file, eight authority files, and no production file. The audit checked
the actual render-mode-before-geometry order, fit/fill render/input revision
identity, both detach and invalid-geometry closures, the single expected task
checkbox replacement, no asynchronous XCTest autoclosure or `try?`, no second
mapper or project/dependency/reference change, and all physical/live proof
boundaries. No finding blocks the independent task 5.2 commit and push.

## Task 5.3 public visionOS input adapters and admission

Direct XROS 26.4 warnings-as-errors probes confirmed public compilation of
`UIPress.key` and `UIKey`, `.indirectPointer` hover filtering, scroll-only pan
recognizers, and GameController extended/micro handlers. The SDK does not expose
`UIPress.isRepeat`; production therefore sends one balanced down/up pair per
supported public hardware-key press with `isRepeat` false. Escape and
Command-Q/H/Tab remain local, while unsupported HID usages are dropped by a
typed value adapter rather than guessed from characters.

`TVVisionStreamMetalView` becomes first responder only for its current key
window while visible and interactive. Window key/resign-key notifications and
view hidden, alpha, or interaction changes all re-evaluate the same policy.
Hover and scroll recognizers accept only `.indirectPointer`; direct touch,
gaze, hand, and other spatial interactions have no synthetic remote event
source in this task. Absolute move, button, and finite scroll events reuse the
current crop-aware `TVVisionStreamAbsoluteInputMapping`. Handler invalidation
first clears local key/button state, resigns responder ownership, and removes
recognizers before window, geometry, surface, and relay ownership are removed.

`AppModel` captures only a typed supported path whose presentation, surface,
input generation, capability set, active scene, visibility, and focus all
match. The serialized delivery task repeats the full admission immediately
before calling the existing canonical remote-input provider, so replacement or
focus loss makes queued events inert. The existing GameController owner now
accepts an explicit platform while defaulting to tvOS. visionOS controller
leases, complete roster snapshots, motion, and supported feedback reuse the
same registry and opaque routing identity. Routed roster state means the last
state successfully delivered to the host: valid intermediate completions must
be recorded so later disconnect differences are correct, while cancellation,
generation loss, release closure, or focus loss rejects late write-back. The
tvOS-only `TVPlatformInputReleasePlan` platform guard is unchanged.

Fresh retained evidence is:

- pure adapter/controller contracts
  `/tmp/LuneX-18-5_3-adapter-r4.UYHFT3`: `21/21`;
- final first-responder and application focused bundle
  `/tmp/LuneX-18-5_3-focused-r3.73l4R8/Focused.xcresult`: `23/23`, plus routing
  fix `/tmp/LuneX-18-5_3-routing-fix.w0dfTC/Routing.xcresult`: `2/2`;
- final related `/tmp/LuneX-18-5_3-related-r3.OSGzhI/Related.xcresult`:
  `100/100`, and normal `/tmp/LuneX-18-5_3-normal.d3en1d/Normal.xcresult`:
  `1065 total / 1064 passed / 1 skipped / 0 failed / 0 expected failure`;
  the only skip is the explicitly disabled real-Keychain test and every
  structured build diagnostic count is zero;
- fixed Vision Pro direct
  `/tmp/LuneX-18-5_3-visionos-direct.kJobJV/VisionOS.xcresult` and fresh
  five-platform unsigned Debug `/tmp/LuneX-18-5_3-builds.BSj3P1`: every build
  succeeded with zero warning, error, or analyzer-warning diagnostics and one
  AIR plus one metallib.

The real-Keychain and live-host opt-ins were unset. Fixed UUIDs were only build
destinations; no Simulator lifecycle operation was performed. Task 5.3 does
not complete task 5.4 system gesture, recenter, capture, safety, volume,
escape, gaze, or hand policy, nor task 5.5 ordered held-state release and local
UI restoration. It also does not prove Simulator runtime, signed installation,
physical Vision Pro keyboard/pointer/controller behavior, HDR, spatial audio,
live Sunshine, latency, comfort, performance, power, or thermal behavior.

Fresh repository pre-gate
`/tmp/LuneX-18-5_3-repository-pre-r3.K2qbMj` passed fixture self/tree,
OpenSpec strict `9/9`, pre-mark `27/50` with task 5.3 next, three stable project
generations at SHA-256
`e6a88cd00f4364b7e3a8011841abba9344a9ae3ac1c411e18d1ce426b9b739cb`, the
exact seventeen-file scope, generator/project membership, first-responder,
indirect-only pointer, double admission, controller routing and tvOS release
guard semantics, privacy/clean-room/reference/dependency boundaries, all
retained structured test/build/Metal evidence, the exact Keychain skip,
disabled opt-ins, no owned test/build process, and `git diff --check`. Task 5.3
is marked complete; the post-mark gate is read-only and must not repeat tests,
builds, generator work, Keychain access, or Simulator work.

The fresh read-only post-mark final-state at
`/tmp/LuneX-18-5_3-final-state.bsTiTn` confirmed OpenSpec `28/50 ready`, task
5.3 done, task 5.4 next, and the exact eighteen-file scope. It did not repeat
tests, builds, generator work, Keychain access, or Simulator lifecycle work.

Fresh post-record `/tmp/LuneX-18-5_3-post-record-r3.HJheG4` confirmed the same
OpenSpec state and scope together with the stable project hash, five authority
records, retained test/build/Metal evidence, the exact Keychain skip, disabled
opt-ins, no owned test/build process, and dependency/reference/diff boundaries.
Final audit `/tmp/LuneX-18-5_3-final-audit.TNi2hb` then passed the public event
source, first-responder/teardown, double-admission, host-visible controller
routing, tvOS-only release guard, test/project membership, pending-task, and
repository-boundary checks. No finding blocks the task 5.3 commit.

## Task 5.4 reserved visionOS system interaction

The existing bounded `VisionSystemInteractionDecision` remains the single
policy for system gesture, recenter, capture, safety, volume, escape, gaze,
hand, and unsupported interaction classes. Task 5.4 does not intercept
platform-owned behavior. The only actual event source added to this policy is
the public hardware-key path already owned by the current Metal surface:
Escape, keyboard mute/volume HID usages, Print Screen,
Command-Shift-3/4/5 capture, and Command-Q/H/Tab resolve to canonical local
decisions and produce no `RemoteInputEvent`.

The surface event carries its checked surface generation. `AppModel` records
the bounded decision only for the current visionOS surface, rejects an old
surface after replacement, and clears state on replacement or stop. Digital
Crown recentering, safety behavior, system-owned capture and volume buttons,
gaze, and hand interaction have no selected LuneX event source. No ARKit,
direct-touch, spatial-event, or gaze/hand recognizer was added; hover and
scroll remain restricted to `.indirectPointer`. This task does not implement
task 5.5 held-state release or local-navigation restoration.

Fresh retained evidence is:

- focused `/tmp/LuneX-18-5_4-focused-r2.oBJfvC/Focused.xcresult`:
  `24/24 passed / 0 skipped / 0 failed / 0 expected failure`;
- related `/tmp/LuneX-18-5_4-related.KdKMLz/Related.xcresult`:
  `101/101 passed / 0 skipped / 0 failed / 0 expected failure`;
- normal `/tmp/LuneX-18-5_4-normal.2eEluq/Normal.xcresult`:
  `1066 total / 1065 passed / 1 skipped / 0 failed / 0 expected failure`, with
  the only skip exactly the disabled real-Keychain test;
- fixed Vision Pro direct
  `/tmp/LuneX-18-5_4-visionos-direct.CsJwFj/VisionOS.xcresult` and fresh
  five-platform unsigned Debug `/tmp/LuneX-18-5_4-builds.pGfMJ3`: every build
  succeeded with zero warning, error, or analyzer-warning diagnostics and one
  AIR plus one metallib.

Both real opt-ins were unset and fixed UUIDs were only build destinations. No
Simulator lifecycle operation was performed. These results prove deterministic
policy/application behavior and unsigned SDK compatibility, not Simulator
runtime, signed install, physical recenter/capture/volume/safety behavior,
gaze/hand behavior, live Sunshine, latency, comfort, performance, power, or
thermal acceptance. Task 5.4 remains pre-mark until the repository gate passes.

The fresh repository pre-gate at
`/tmp/LuneX-18-5_4-repository-pre.sSXJDF` passed fixture self/tree, OpenSpec
strict `9/9`, pre-mark `28/50 next 5.4`, three byte-stable generator runs with
project SHA-256
`e6a88cd00f4364b7e3a8011841abba9344a9ae3ac1c411e18d1ce426b9b739cb`,
the exact thirteen-file scope, current source/test/document semantics, retained
test/build/Metal evidence, the single disabled real-Keychain skip, and the
privacy, clean-room, dependency, reference, opt-in, process, and diff
boundaries. Task 5.4 is now checked complete.

The read-only post-mark final-state at
`/tmp/LuneX-18-5_4-final-state.GcQmvO` confirmed OpenSpec `29/50 ready`, task
5.4 done, task 5.5 next, the same stable project hash, and the exact
fourteen-file scope. It did not repeat generator, test, build, Keychain, or
Simulator lifecycle work. Ordered held-state release and local-navigation
restoration remain task 5.5.

Post-record `/tmp/LuneX-18-5_4-post-record.7WByk7` confirmed that all five
authority records reference both gates and preserve the same current state,
scope, implementation semantics, retained evidence, and repository boundaries.
Final diff audit `/tmp/LuneX-18-5_4-final-audit.CbmtKb` classified the exact
scope as four production, two test, and eight authority files, verified that
the task checkbox is the only task-list replacement, and found no issue that
blocks the task 5.4 commit.

## Task 5.5 ordered visionOS input release and local restoration

`AppModel` now owns one serial `VisionInputRuntimeTarget` reconciliation chain
around the task 1.4 `VisionWindowInputOwnershipState`. Losing focus, scene
activity, input readiness, or the current surface closes capture admission
synchronously. Provider failure, remote termination, and stop additionally
latch terminal closure until a new media runtime begins. The canonical release
effects cancel bounded system state, quiesce controller handlers, wait for the
keyboard/pointer FIFO plus controller roster/motion delivery chains, call the
shared held-input release once, release the surface lease when required, and
only then publish a fixed local restoration reason.

The internal inconsistency fallback preserves that safety order instead of
restoring UI immediately: it drains controller and keyboard/pointer work,
attempts one held-input release, and restores bounded local state last. A held
release provider failure terminal-latches `inputUnavailable`, keeps capture
closed across late eligible geometry, and does not ask the shared coordinator
to retry the host release.

`RootView` passes current capture eligibility only to the visionOS Metal
surface. Closing it clears active key presses and pointer buttons, resigns first
responder, and removes hover/scroll recognizers. A later current, visible,
interactive key window reinstalls the `.indirectPointer` recognizers and
responder idempotently. No direct, gaze, hand, or system-owned interaction is
synthesized.

The shared `MacSessionInputCoordinator.terminate` keeps
`requiresReleaseBarrier: true` as its default. After a tvOS/visionOS platform
owner has already completed its ordered barrier, `AppModel` passes `false` so
the coordinator still drains one in-flight send, drops its queued samples,
closes admission/generation, and runs capture cleanup exactly once without a
second sink release. macOS termination paths retain the default barrier.

Fresh post-audit retained evidence is:

- focused
  `/tmp/LuneX-18-5_5-audit-focused.7SdLvE/Focused.xcresult`:
  `42/42 passed / 0 skipped / 0 failed / 0 expected failure`;
- related
  `/tmp/LuneX-18-5_5-audit-related.hmvlgf/Related.xcresult`:
  `189/189 passed / 0 skipped / 0 failed / 0 expected failure`;
- normal `/tmp/LuneX-18-5_5-audit-normal.4HpgIt/Normal.xcresult`:
  `1069 total / 1068 passed / 1 skipped / 0 failed / 0 expected failure`, with
  the only skip exactly the disabled real-Keychain test;
- fresh five-platform unsigned Debug
  `/tmp/LuneX-18-5_5-audit-builds.ccZsdc`, including the fixed Vision Pro
  destination: every build
  succeeded with zero warning, error, or analyzer-warning diagnostics and one
  AIR plus one metallib.

Both real opt-ins were unset. Fixed UUIDs were build destinations only; no
Simulator lifecycle operation was performed. These results prove deterministic
contract/application behavior and unsigned SDK compilation, not Simulator
runtime, signed installation, physical Vision Pro input/focus behavior, live
Sunshine host receipt, HDR, spatial audio, latency, comfort, performance,
power, or thermal behavior. Task 5.5 remains pre-mark until the repository gate
passes; task 5.6 and 6.x-8.x remain pending.

Fresh repository pre-gate
`/tmp/LuneX-18-5_5-repository-pre-r3.GP0fhH` passed fixture self/tree, OpenSpec
strict `9/9`, pre-mark `29/50` with task 5.5 next, three byte-stable project
generations, exact thirteen-file scope, membership and ordered-release
semantics, all retained post-audit test/build evidence, the exact Keychain
skip, and privacy, clean-room, reference, dependency, opt-in, process, and
diff boundaries. Task 5.5 is therefore marked complete; task 5.6 remains
pending and no proof tier is promoted.

The read-only post-mark final-state at
`/tmp/LuneX-18-5_5-final-state.QP2qUU` confirmed OpenSpec strict `9/9`,
`30/50 ready`, task 5.5 done, task 5.6 next, exact fourteen-file scope, and the
single task 5.5 checkbox replacement. It retained all post-audit evidence,
disabled both real opt-ins, found no test process, and confirmed unchanged
reference, dependency, and diff boundaries without rerunning tests, builds,
the generator, Keychain, or any Simulator operation.

Post-record `/tmp/LuneX-18-5_5-post-record.xbp4eR` and final audit
`/tmp/LuneX-18-5_5-final-audit.7fk9HU` confirmed the five authority indexes,
exact fourteen-file classification as four production, two test, and eight
authority files, the single task 5.5 checkbox replacement, typed release
effect order, release-failure terminal closure, no second shared-coordinator
barrier, local surface capture suspension/recovery, and task 5.6 remaining
pending. No issue blocks the independent task 5.5 commit.

## Task 5.6 connected visionOS window and input regression matrix

Task 5.6 adds no production runtime. Three deterministic connected matrices
verify the completed task 5.1-5.5 ownership boundaries:

- the AppModel matrix admits one held key, applies two same-generation resize
  and fit/fill revisions without releasing capture, keeps a reserved volume
  decision local, then releases exactly once for surface replacement, rejects
  the old surface, and releases the replacement exactly once on terminal stop;
- the surface matrix filters foreign window and scene notifications, advances
  geometry, drawable, render, and absolute-input mapping through two resize
  revisions together, rejects a stale surface generation, and leaves window
  callbacks and mapping inert after detach and idempotent invalidation;
- the value matrix admits every declared visionOS input capability, rejects a
  missing pointer capability, preserves crop-aware absolute pointer output,
  keeps every system or unsupported interaction local, orders controller,
  monitor, held-input, and surface release effects, and proves repeated release
  emits no second effect.

Fresh retained evidence is:

- focused `/tmp/LuneX-18-5_6-focused-r2.Es1RDS/Focused.xcresult`:
  `3/3 passed / 0 skipped / 0 failed / 0 expected failure`;
- related `/tmp/LuneX-18-5_6-related.yIYDyZ/Related.xcresult`:
  `213/213 passed / 0 skipped / 0 failed / 0 expected failure`;
- normal `/tmp/LuneX-18-5_6-normal.4E7C3M/Normal.xcresult`:
  `1072 total / 1071 passed / 1 skipped / 0 failed / 0 expected failure`, with
  the only skip exactly the disabled real-Keychain test;
- five-platform unsigned Debug `/tmp/LuneX-18-5_6-builds.ijxOfl`: macOS and the
  fixed iPhone, iPad, Apple TV, and Vision Pro destinations all succeeded with
  zero warning, error, or analyzer-warning diagnostics and one AIR plus one
  metallib.

Both real opt-ins were unset. Fixed UUIDs were build destinations only; no
Simulator lifecycle operation occurred. The evidence proves deterministic
contracts, application sequencing, and unsigned SDK compilation. It does not
prove Simulator runtime, signed installation, physical Vision Pro window,
focus, keyboard, pointer, controller, HDR, or spatial-audio behavior, live
Sunshine receipt, latency, comfort, performance, power, or thermal behavior.
Fresh repository pre-gate
`/tmp/LuneX-18-5_6-repository-pre-r3.FltJEs` passed fixture self/tree, OpenSpec
strict `9/9`, pre-mark `30/50` with task 5.6 next, three byte-stable project
generations, exact ten-file scope, target membership and all three connected
matrix semantics, retained test/build/Metal evidence, the exact Keychain skip,
and privacy, clean-room, reference, dependency, opt-in, process, and diff
boundaries.

The read-only post-mark final-state at
`/tmp/LuneX-18-5_6-final-state-r2.ZtO9JF` confirmed OpenSpec strict `9/9`,
`31/50 ready`, task 5.6 done, task 6.1 next, exact eleven-file scope, and the
single task 5.6 checkbox replacement. It retained every prior evidence tier,
kept both real opt-ins disabled, and found no test/build process without
rerunning tests, builds, the generator, Keychain, live-host I/O, or any
Simulator operation. Task 5.6 is complete; tasks 6.x-8.x stay pending and no
proof tier is promoted.

Post-record `/tmp/LuneX-18-5_6-post-record-r2.omtl07` confirmed the five
authority indexes, exact eleven-file classification as three test and eight
authority files, current matrix semantics, retained evidence, stable project,
and repository boundaries. Final diff audit
`/tmp/LuneX-18-5_6-final-audit.cNq2is` found no weakened/disabled test path,
sensitive test literal, production change, second checkbox, or proof-tier
promotion. No issue blocks the independent task 5.6 commit.

## Task 6.1 current visionOS windowed presentation state

Task 6.1 reuses the checked value contract from task 1.4 and adds no immersive
runtime. `TVVisionPlatformPresentationCoordinator` now derives one actual
`VisionWindowedPresentationState` only after the current visionOS scene is
attached. The value owns the current presentation and surface generations,
reports only `.windowed`, and carries the exact typed unavailable set for
immersive, passthrough, stereoscopic, and volumetric presentation.

The coordinator rebrands this value to its single semantic revision whenever a
current input, display, audio, or video component advances. Replacement
activation publishes no inherited window state; old ownership callbacks remain
stale, and detach, failure, remote termination, or stop clears the state. tvOS
snapshots always publish `nil`. `AppModel.visionWindowedPresentationState`
further requires the current stream/media session, media generation,
presentation ownership, embedded ownership, active phase, and matching
revision before exposing the value.

Fresh retained evidence after audit is:

- focused `/tmp/LuneX-18-6_1-audit-focused.u9HXzp/Focused.xcresult`:
  `1/1 passed / 0 skipped / 0 failed / 0 expected failure`, including
  cross-component semantic-revision rebranding;
- related `/tmp/LuneX-18-6_1-audit-related.3Whib6/Related.xcresult`:
  `251/251 passed / 0 skipped / 0 failed / 0 expected failure`;
- normal `/tmp/LuneX-18-6_1-audit-normal.VXSI3H/Normal.xcresult`:
  `1074 total / 1073 passed / 1 skipped / 0 failed / 0 expected failure`, with
  the only skip exactly the disabled real-Keychain test;
- five-platform unsigned Debug `/tmp/LuneX-18-6_1-builds.APF2yT`: macOS and the
  fixed iPhone, iPad, Apple TV, and Vision Pro destinations all succeeded with
  zero warning, error, or analyzer-warning diagnostics and one AIR plus one
  metallib.

Both real opt-ins remained unset and fixed UUIDs were build destinations only;
no Simulator lifecycle operation occurred. These results prove deterministic
state ownership, replacement/terminal clearing, cross-component revision
coherence, AppModel admission, and unsigned SDK compilation. They do not prove
Simulator runtime, signed installation, an actual immersive runtime, decoded
frame presentation on Vision Pro, physical HDR/spatial audio/input, live
Sunshine, latency, comfort, performance, power, or thermal behavior. Tasks
6.2-8.x and physical/live acceptance remain pending.

The fresh repository pre-gate
`/tmp/LuneX-18-6_1-repository-pre-r2.nZ4iKX` additionally passed the protocol
fixture self-test and complete fixture tree, OpenSpec strict `9/9`, pre-mark
`31/50 next 6.1`, three byte-stable project generations at SHA-256
`e6a88cd00f4364b7e3a8011841abba9344a9ae3ac1c411e18d1ce426b9b739cb`, exact
eleven-file scope, generator/project membership, retained structured test and
five-platform Metal evidence, the exact Keychain skip, and privacy,
clean-room, dependency, opt-in, idle-process, diff, and proof boundaries. An
earlier boundary wrapper exited only because it expected different prose
capitalization and a different `tasks` prefix; the corrected fresh gate reran
from the beginning and passed without rerunning tests or builds.

After that gate, only task 6.1 was checked. The read-only post-mark final-state
`/tmp/LuneX-18-6_1-final-state.D3kVOH` confirmed OpenSpec strict `9/9`,
`32/50 ready`, task 6.1 complete, task 6.2 next, exact twelve-file scope, and
one checkbox replacement. No test, build, generator, Keychain, live-host, or
Simulator lifecycle operation was repeated by that final-state check.

Post-record `/tmp/LuneX-18-6_1-post-record-r2.aMya2c` and final diff audit
`/tmp/LuneX-18-6_1-final-audit-r2.nVb6kC` confirmed the exact two-production,
two-test, eight-authority classification; all five authority evidence indexes;
the current ownership, cross-component revision, replacement, terminal, and
tvOS-nil semantics; and no weakened test, parallel visionOS media owner, early
task 6.2 implementation, second checkbox, sensitive literal, reference,
dependency, or generated-project drift. Task 6.1 is independently committable.

## Task 6.2 current visionOS frame presentation

Task 6.2 reuses the task 4.1 production path rather than creating a visionOS
decoder or presenter. `StreamVideoPresentationSource` remains the one decoded
frame source, `TVVisionPlatformPresentationCoordinator` the one checked media
owner, `TVVisionMetalPresentationOwner` the one main-actor bridge, and the
actual `TVVisionStreamMetalView`/`StreamMetalPresenter` the current window
surface. The visionOS matrix covers windowed activation, decoder/frame
delivery, geometry revision resubmission, surface replacement, stale surface,
detach/resume, explicit clear, stale decoder frame, newer decoder recovery,
presentation replacement, late old ownership, and stop.

Replacement deliberately preserves `requiresClearBeforePresentation`. The
first draw after replacement clears the old drawable; only a subsequent draw
may present the replacement frame. The initial focused failure that expected
frame 44 on the first draw was a test-order error, not evidence to remove this
production fence.

The resumed production audit found a separate ordering defect in
`NativeSessionMediaEnvironment`: the single source subscription created an
independent unstructured `Task` for every delivery. Task scheduling could
therefore reorder decoder-start, frame, and clear operations even though the
source revisions were ordered. The replacement is one ownership-scoped,
cancellable FIFO pump with one consumer and at most 64 pending deliveries.
Replacement, failure, stop, and teardown cancel both pump and subscription.
Overflow clears pending work and, through the same consumer, publishes a typed
`.invalidComponent(.video)` failure only for the matching current pump ID;
late overflow from an old ownership is inert.

Fresh retained post-audit evidence is:

- focused `/tmp/LuneX-18-6_2-audit-focused-r4.vj6AKw/Focused.xcresult`:
  `4/4 passed / 0 skipped / 0 failed / 0 expected failure`;
- related `/tmp/LuneX-18-6_2-audit-related.xqXKjd/Related.xcresult`:
  `255/255 passed / 0 skipped / 0 failed / 0 expected failure`;
- normal `/tmp/LuneX-18-6_2-audit-normal.rwmq84/Normal.xcresult`:
  `1078 total / 1077 passed / 1 skipped / 0 failed / 0 expected failure`, with
  the only skip exactly the disabled real-Keychain test;
- five-platform unsigned Debug `/tmp/LuneX-18-6_2-audit-builds.jvlO3v`: macOS
  and the fixed iPhone, iPad, Apple TV, and Vision Pro destinations all
  succeeded with zero warning, error, or analyzer-warning diagnostics and one
  `CompileMetalFile` plus one `MetalLink` each.

One combined diagnostic run was intentionally interrupted after an indefinite
test wait, and one isolated run then proved that the test had waited for a
video effect on decoder-start even though only decoded frames create that
effect. Those bundles are not retained as passing evidence. The corrected
test submits frame zero before blocking and uses bounded state waiting.

Both real opt-ins remained unset. Fixed simulator UUIDs were build destinations
only; no Simulator lifecycle command ran. These gates prove deterministic
ownership, bounded FIFO delivery, replacement fences, stale rejection, typed
overflow failure, complete normal regression, and unsigned SDK compilation.
They do not prove Simulator runtime, signed installation, physical Vision Pro
window/compositor behavior, HDR, spatial audio, live Sunshine, latency,
comfort, performance, power, or thermal behavior. Tasks 6.3-8.x and
physical/live acceptance remain pending.

The fresh repository pre-gate
`/tmp/LuneX-18-6_2-repository-pre-r2.qw8ka9` and post-mark final-state gate
`/tmp/LuneX-18-6_2-final-state.Dx3op0` verify the transition from `32/50 next
6.2` to `33/50 next 6.3`, the exact ten-file pre-mark and eleven-file post-mark
scopes, the single task checkbox change, stable generated project membership,
retained evidence, disabled opt-ins, and the same proof boundaries.

The post-record gate `/tmp/LuneX-18-6_2-post-record.cDfHFy` and final diff audit
`/tmp/LuneX-18-6_2-final-audit.k3rz0Z` verify the final one-production,
two-test, eight-authority classification, complete authority indexing, the
single bounded pump and cancellation semantics, unchanged tests, the one task
checkbox transition, and repository privacy and dependency boundaries.

The final record `/tmp/LuneX-18-6_2-final-record.Q9ZZvx` confirms the same
`33/50 next 6.3` state, final scope and authority classification, retained
evidence, implementation semantics, disabled opt-ins, and repository proof
boundaries before the task-level commit.

## Task 6.3 visionOS public HDR capability

Task 6.3 extends the existing platform display contract rather than creating a
visionOS HDR resolver or rendering pipeline. `TVVisionDisplaySnapshot` now
stores mutually exclusive tvOS and visionOS capability resolutions, derives one
platform-neutral checked resolution for render headroom and diagnostics, and
preserves the matching field whenever the platform coordinator rebrands a
component to its current semantic revision.

The actual visionOS `TVVisionStreamMetalView` owns one layer-only display
observer. It never accesses `UIScreen`, `UIWindowScene.screen`, or a private
compositor API. Attachment, layout, and trait callbacks sample the current
`CAMetalLayer`; replacement advances display generation; detach publishes
output unavailable; stale surface generations and work after invalidation are
inert. The public native probe confirms layer dynamic-range, tone-map,
content-headroom, legacy intent/metadata, and extended-linear color-space API
availability, but leaves current and potential headroom `nil`. The resulting
native capability is therefore `.headroomUnavailable`, uses conservative
`DisplayHeadroom()`, and cannot claim direct EDR.

Fresh retained pre-mark evidence is:

- focused `/tmp/LuneX-18-6_3-focused-r2.nLEOjb/Focused.xcresult`:
  `31/31 passed / 0 skipped / 0 failed / 0 expected failure`;
- XROS 26.4 API probe `/tmp/LuneX-18-6_3-xros-probe.KqmYxE`: all seven public
  layer/color expressions typecheck with warnings as errors, while the expected
  negative probe rejects both `UIScreen` and `UIWindowScene.screen`;
- fixed Vision Pro unsigned Debug
  `/tmp/LuneX-18-6_3-visionos-direct.1gbruA/VisionOS.xcresult`: succeeded with
  zero warning, error, or analyzer-warning diagnostics and one AIR plus one
  metallib;
- related `/tmp/LuneX-18-6_3-related.sM3JhP/Related.xcresult`:
  `258/258 passed / 0 skipped / 0 failed / 0 expected failure`;
- normal `/tmp/LuneX-18-6_3-normal.culXSh/Normal.xcresult`:
  `1082 total / 1081 passed / 1 skipped / 0 failed / 0 expected failure`, with
  the only skip exactly the disabled real-Keychain test;
- five-platform unsigned Debug `/tmp/LuneX-18-6_3-builds.O6tTU8`: macOS and the
  fixed iPhone, iPad, Apple TV, and Vision Pro destinations all succeeded with
  zero warning, error, or analyzer-warning diagnostics and one AIR plus one
  metallib each.

Both real opt-ins remained unset. Fixed UUIDs were used only as build
destinations, and no Simulator inventory or lifecycle operation ran. These
results prove deterministic value/observer/coordinator ownership, typed native
fallback, SDK availability, and unsigned cross-platform compilation. They do
not prove Simulator runtime, signed installation, current Vision Pro compositor
headroom, physical HDR brightness/color, spatial audio, live Sunshine, latency,
comfort, performance, power, or thermal behavior. Task 6.4 still owns visionOS
audio, task 6.5 still owns AppModel/RootView display coordination and complete
teardown, and tasks 6.6-8.x remain pending.

The fresh pre-mark repository gate
`/tmp/LuneX-18-6_3-repository-pre.ioYbts` passed the protocol fixture self-test
and tree, OpenSpec strict `9/9`, `33/50 next 6.3`, exact twelve-file scope,
three byte-stable project generations at SHA-256
`e6a88cd00f4364b7e3a8011841abba9344a9ae3ac1c411e18d1ce426b9b739cb`,
generator/project membership, layer-only and typed-fallback semantics, all
retained test/probe/build evidence, the exact Keychain skip, and privacy,
clean-room, reference, dependency, opt-in, process, diff, and proof boundaries.
Only task 6.3 may be checked after this gate.

After that gate, only task 6.3 was checked. The read-only post-mark final-state
`/tmp/LuneX-18-6_3-final-state.dySg9y` confirmed OpenSpec strict `9/9`,
`34/50 ready`, task 6.3 complete, task 6.4 next, exact thirteen-file scope, the
single checkbox replacement, stable generated project, and unchanged
reference, dependency, configuration, and diff boundaries. It did not repeat
tests, builds, generation, Keychain, live-host, or Simulator operations.

The final diff audit `/tmp/LuneX-18-6_3-final-audit.c5MAQz` confirmed the
thirteen-file scope as three production, two test, and eight authority files;
the mutually exclusive resolution, layer-only observer, native nil-headroom,
replacement, stale, detach, and invalidation semantics; all four focused tests
without weakening; the single task checkbox; and stable privacy, reference,
dependency, opt-in, process, project, and proof boundaries.

The final record `/tmp/LuneX-18-6_3-final-record.7lzi44` confirmed the same
`34/50 next 6.4` state, thirteen-file `3/2/8` classification, complete
pre/final authority indexes, stable project and retained evidence, disabled
opt-ins, and implementation, task, privacy, dependency, and proof boundaries
before the task-level commit.

## Task 6.4 current visionOS audio route application

Task 6.4 generalizes the task 4.4 publisher at the platform-application edge;
it does not add an audio graph, route observer, AVAudioSession notification
source, PCM path, or event stream. `TVVisionAudioRouteSnapshotPublisher` fixes
one `TVVisionPlatform` at initialization. `NativeSessionMediaEnvironment`
creates or reuses that publisher only for matching current presentation
ownership, replays the latest current-session route on activation or
replacement, and consumes later events from the same canonical audio runtime.

The publisher validates platform policy before creating checked coordinator
state. tvOS accepts `.none` or `.environmentListener`, rejects vision output
experience, and continues to require granted listener entitlement before
reporting head tracking. visionOS accepts `.none` or
`.visionOutputExperience`, rejects the tvOS environment-listener strategy, and
does not apply listener entitlement. Matching visionOS fixed or head-tracked
readback publishes `.intendedSpatialExperience`. Both platforms require the
route and spatial runtime to share revision and route support, validate actual
current and maximum output channel counts, reject duplicate event sequence or
older graph generation, and normalize unavailable output without retaining a
false spatial claim.

Interruption keeps the checked current route with its runtime stage. Media
services lost closes output and active spatial presentation. Reset accepts only
the replacement graph generation and permits current fixed or head-tracked
intended experience to recover. Presentation replacement replays current state
into the new ownership without advancing a separate graph. Invalid runtime,
publisher revision exhaustion, audio-route action failure, coordinator
failure, remote termination, and stop clear current route/presentation state;
late old-platform, old-ownership, old-sequence, or old-graph events remain
inert.

Fresh retained pre-mark evidence is:

- focused `/tmp/LuneX-18-6_4-focused-r2.BZF9w4/Focused.xcresult`:
  `5/5 passed / 0 skipped / 0 failed / 0 expected failure`, with zero warning,
  error, or analyzer-warning diagnostics;
- related `/tmp/LuneX-18-6_4-related.YQ4rA2/Related.xcresult`:
  `182/182 passed / 0 skipped / 0 failed / 0 expected failure`, with zero
  warning, error, or analyzer-warning diagnostics;
- XROS 26.4 API probe `/tmp/LuneX-18-6_4-xros-probe.2UK3No`: public output-node
  intended fixed, head-tracked, and bypassed experiences typecheck with
  warnings as errors, while the expected negative probe reports the listener
  head-tracking property unavailable on visionOS;
- fixed Vision Pro unsigned Debug
  `/tmp/LuneX-18-6_4-visionos-direct.6wtjPE/VisionOS.xcresult`: succeeded with
  zero warning, error, or analyzer-warning diagnostics and one AIR plus one
  metallib;
- normal `/tmp/LuneX-18-6_4-normal.9YKcpI/Normal.xcresult`:
  `1084 total / 1083 passed / 1 skipped / 0 failed / 0 expected failure`, with
  the only skip exactly the disabled real-Keychain round-trip and file fallback
  tests passing; and
- five-platform unsigned Debug `/tmp/LuneX-18-6_4-builds.Vi0CJb`: macOS and the
  fixed iPhone, iPad, Apple TV, and Vision Pro destinations all succeeded with
  zero warning, error, or analyzer-warning diagnostics and one AIR plus one
  metallib each.

Both real opt-ins remained unset. Fixed UUIDs were used only as build
destinations; no app was launched and no Simulator inventory or lifecycle
operation ran. These results prove deterministic publisher/environment/current
ownership behavior, recovery and replacement contracts, public SDK
availability, and unsigned cross-platform compilation. They do not prove
Simulator runtime, signed installation, physical receiver, speaker, or AirPods
routes, audible fixed or head-tracked spatial audio, live Sunshine, latency,
comfort, performance, power, or thermal behavior. Task 6.5 still owns complete
scene/video/HDR/audio/input/diagnostics coordination and terminal orchestration,
task 6.6 owns the connected regression, task 7.2 owns actual-state UI, and task
8.7 owns signed physical/live acceptance.

The fresh repository pre-gate
`/tmp/LuneX-18-6_4-repository-pre-r4.8oI8VY` passed fixture self/tree, OpenSpec
strict `9/9`, pre-mark `34/50 next 6.4`, three byte-stable project generations
at SHA-256
`e6a88cd00f4364b7e3a8011841abba9344a9ae3ac1c411e18d1ce426b9b739cb`, exact
eleven-file scope, project membership, platform policy, route/runtime
consistency, current ownership and replay semantics, all retained
test/probe/build/Metal evidence, the exact Keychain skip, disabled opt-ins, no
residual process, and clean-room, reference, dependency, privacy, diff, and
proof-tier boundaries. Only task 6.4 may be checked after this gate.

After that gate, only task 6.4 was checked. The read-only post-mark final-state
`/tmp/LuneX-18-6_4-final-state.1Gh0gg` confirmed OpenSpec strict `9/9`, `35/50
ready`, task 6.4 complete, task 6.5 next, exact twelve-file scope, the single
checkbox replacement, stable generated project, retained evidence presence,
disabled opt-ins, no residual process, and unchanged reference, dependency,
configuration, diff, and proof boundaries. It did not repeat tests, builds,
generation, Keychain, live-host, or Simulator operations.

The corrected post-record
`/tmp/LuneX-18-6_4-post-record-r4.onEV9k` confirmed `35/50 next 6.5`, strict
`9/9`, final twelve-file classification as two production, two test, and eight
authority files, both gate indexes in all five authority records, stable
project and retained evidence, disabled opt-ins, and repository boundaries.
The final diff audit `/tmp/LuneX-18-6_4-final-audit.ZathRe` then confirmed the
fixed-platform publisher, mutually exclusive strategies, route/runtime
consistency, current ownership replay, recovery/replacement/terminal behavior,
both connected tests without weakening, the single task checkbox, and stable
privacy, reference, dependency, configuration, opt-in, and proof boundaries.

The final record `/tmp/LuneX-18-6_4-final-record.0FZsJc` confirmed the same
`35/50 next 6.5` state, twelve-file `2/2/8` classification, complete
pre/final/post-record/audit authority indexes, stable project and retained
evidence, disabled opt-ins, and implementation, task, privacy, dependency, and
proof boundaries before the task-level commit.

## Task 6.5 complete visionOS presentation coordination

Task 6.5 keeps the one `TVVisionPlatformPresentationCoordinator`, actual
`MetalStreamSurface`, `StreamMetalPresenter`, decoded-frame source, HDR
resolver, canonical audio graph, and vision input owner established by earlier
tasks. The visionOS `RootView` surface now forwards its actual layer display
event into a platform-generic `AppModel` entry. The previous tvOS entry remains
a tvOS-only compatibility wrapper; shared private display source, application,
fallback, revision-exhaustion, matching, and cleanup state is fixed to the
current expected TV/Vision platform.

An attached visionOS geometry application now derives the current
`VisionWindowInputSnapshot` capability and applies one ordered sequence:
`activate`, scene, input, then display. tvOS alone still updates the Siri Remote
surface capture owner. The existing media environment continues to inject the
current decoded video and canonical audio route into that same coordinator.
The resulting snapshot can therefore contain the actual windowed scene,
eligible input capability, current decoded frame, platform-branded
`.headroomUnavailable` HDR-to-SDR fallback, public vision output intended
spatial experience, and bounded diagnostics under one ownership and semantic
revision.

Display application remains serialized behind geometry. A replacement surface
cancels pending application and clears its source. During review, a
same-surface race was found: a newer geometry admission could correctly reject
an already queued display application but leave its still-current source
unapplied. The geometry path now reschedules a matching current-platform source
behind the newest geometry task. Operation ID, exact admission, session, media
generation, surface, display generation, and revision checks keep old work
inert. A deterministic test blocks the first activation and verifies that only
the latest scene/input revision and current display are applied.

Reconnect first clears current presentation, render/HDR, and input state and
applies `.stop(.reconnect)`. The surviving actual view may replay unchanged
geometry and display values only into media generation 2; a generation 1 state
is rejected. Remote termination applies `.stop(.remoteTermination)`, local stop
applies `.stop(.localStop)`, and both clear windowed, input, display, render,
and fallback state. A display action failure clears the source/render state and
applies `.fail(.actionFailed(.display))` to the matching current ownership.

Fresh post-audit pre-mark evidence is:

- focused `/tmp/LuneX-18-6_5-focused-r3.6pazwk/Focused.xcresult`:
  `7/7 passed / 0 skipped / 0 failed / 0 expected failure`, with zero warning,
  error, or analyzer-warning diagnostics;
- related `/tmp/LuneX-18-6_5-related-r2.lmoqpY/Related.xcresult`:
  `324/324 passed / 0 skipped / 0 failed / 0 expected failure`, with zero
  warning, error, or analyzer-warning diagnostics;
- normal `/tmp/LuneX-18-6_5-normal.CV3Nzw/Normal.xcresult`:
  `1088 total / 1087 passed / 1 skipped / 0 failed / 0 expected failure`, with
  the only skip exactly the disabled real-Keychain round-trip and zero warning,
  error, or analyzer-warning diagnostics;
- fixed Vision Pro unsigned Debug
  `/tmp/LuneX-18-6_5-visionos-direct.vMBJUC/VisionOS.xcresult`: succeeded with
  zero warning, error, or analyzer-warning diagnostics and one AIR plus one
  metallib; and
- five-platform unsigned Debug `/tmp/LuneX-18-6_5-builds.1uxfoD`: macOS and the
  fixed iPhone, iPad, Apple TV, and Vision Pro destinations all succeeded with
  zero warning, error, or analyzer-warning diagnostics, one AIR plus one
  metallib each, and Metal `-Werror` present.

Both real opt-ins remained unset and normal tests continued to use the file
fallback. Fixed UUIDs were used only as build destinations; no Simulator
inventory or lifecycle command ran. These results prove deterministic current
ownership, ordering, stale rejection, reconnect replay, failure, terminal
cleanup, shared-regression behavior, and unsigned cross-platform compilation.
They do not prove Simulator runtime, signed installation, physical Vision Pro
window/input behavior, headset HDR, audible fixed or head-tracked spatial
audio, live Sunshine, latency, comfort, performance, power, or thermal state.
Task 6.6 retains the broader connected resource regression, task 7.2 retains
actual-state UI, and tasks 8.5-8.7 retain simulator and signed physical/live
acceptance. OpenSpec remains pre-mark `35/50 ready`, task 6.5 next, until the
repository gate passes.

The fresh repository pre-gate
`/tmp/LuneX-18-6_5-repository-pre.QOi58Z` passed fixture self/tree, OpenSpec
strict `9/9`, pre-mark `35/50 next 6.5`, three byte-stable project generations,
exact ten-file scope, generator/project membership, current platform/input/
display/replay/terminal semantics, all retained focused/related/normal/direct/
five-platform Metal evidence, the exact Keychain skip, disabled opt-ins, no
residual process, and clean-room, reference, dependency, privacy, diff, and
proof-tier boundaries. Only task 6.5 was then checked; task 6.6 and all 7.x-8.x
work remain pending.

The read-only post-mark final-state
`/tmp/LuneX-18-6_5-final-state.UppBOq` confirmed OpenSpec strict `9/9`, `36/50
ready`, task 6.5 complete, task 6.6 next, exact eleven-file scope, the single
6.5 checkbox replacement, stable generated project and retained evidence,
disabled opt-ins, no residual process, and unchanged reference, dependency,
diff, and proof boundaries. It did not repeat tests, builds, generation,
Keychain, live-host, or Simulator operations.

The final diff audit `/tmp/LuneX-18-6_5-final-audit.B4HJVK` confirmed the final
eleven files as two production, one test, and eight authority files; the
RootView display connection, platform-generic display ownership, visionOS input
application, same-surface display replay, replacement and terminal cleanup;
all four connected tests without weakening; the single 6.5 checkbox; and
stable privacy, reference, dependency, opt-in, process, project, and proof
boundaries. No issue blocks the task-level commit.

The final record `/tmp/LuneX-18-6_5-final-record.7HghDO` confirmed the same
`36/50 next 6.6` state, final eleven-file `2/1/8` classification, complete
pre-mark/final-state/audit authority indexes, stable project and retained
evidence, disabled opt-ins, and implementation, task, privacy, dependency,
process, and proof boundaries before the task-level commit.

Task 6.6 adds no production owner. Its connected coordinator matrix covers
windowed mode and all typed immersive-unavailable values, current frame
presentation and same-surface resubmission, visionOS headroom-unavailable HDR
fallback, public intended spatial experience, interruption/media-service
loss/reset/recovery, full ownership replacement, stale callback rejection, and
idempotent owner teardown. The media-environment gate separately proves one
active replacement subscription, four cancelled consumer tasks, five stopped
resources, cleared terminal coordinator state, and zero active task/resource
counts after stop.

The final focused `/tmp/LuneX-18-6_6-focused-final.0pDNP0` passed `3/3`; the
related `/tmp/LuneX-18-6_6-related.PwaltL` passed `325/325`; fresh normal
`/tmp/LuneX-18-6_6-normal.dnnNlV` passed `1089/1088/1/0` with only the explicit
real-Keychain opt-in skipped. Fixed Vision Pro direct
`/tmp/LuneX-18-6_6-visionos-direct.8Muuwq` and five-platform unsigned Debug
`/tmp/LuneX-18-6_6-builds.SOVzea` all succeeded with zero structured
diagnostics and one AIR/metallib per build. The UUIDs were build destinations
only: no simulator inventory or lifecycle operation was performed. These are
offline test and unsigned build receipts, not simulator runtime, signed
artifact, physical HDR/spatial/input, live Sunshine, latency, comfort,
performance, power, or thermal proof.

## Task 7.1 accessible tvOS actual-state controls

Task 7.1 adds `TVStreamControlPresentationState` as a read-only value
projection. It does not create another session, decoder, presenter, input
owner, controller registry, HDR resolver, audio graph, or diagnostics store.
`AppModel.tvStreamControlPresentationState` accepts an active tvOS stream only
when stream/media ownership is current, accepts video and audio only from the
matching platform coordinator, derives capture from the actual current surface
press owner, and uses the current controller rosters, render policy, HDR
fallback, and spatial presentation status.

The projection always emits eight rows in this order:

1. Focus
2. Capture
3. Controllers
4. Surface
5. Render
6. HDR
7. Audio
8. Failure

Foreign-platform state, invalid controller counts, missing current ownership,
and inactive sessions fail closed. The projection does not expose host,
session, generation, revision, frame, controller lease/vendor, display, or
route identity, nor arbitrary runtime reason strings. Typed HDR fallback takes
precedence over a generic EDR presentation status, so desired HDR cannot be
misreported as actual direct HDR.

`TVStreamControls` is compiled only for tvOS and uses native SwiftUI buttons.
Its `@FocusState` order is Hide Controls followed by Disconnect, with Hide
Controls as the default focus inside one focus section. Each status row has a
dedicated accessibility label/value and no hover handler or mouse-preference
dependency. Hiding the overlay returns control to the existing stream surface
focus path; opening it continues to restore local focus before commands.

Retained offline evidence:

- focused `/tmp/LuneX-18-7_1-focused-r2.w2xsDG`: `8/8` passed with zero
  structured build diagnostics;
- related `/tmp/LuneX-18-7_1-related.xgCDkd`: 12 classes, `241/241` passed with
  zero structured build diagnostics;
- normal `/tmp/LuneX-18-7_1-normal.e5qCg3`: `1097 total / 1096 passed / 1`
  exact real-Keychain opt-in skip / zero failures and expected failures;
- fixed Apple TV direct `/tmp/LuneX-18-7_1-tvos-direct.Zs7dNK`: unsigned Debug,
  zero structured diagnostics, one AIR, and one metallib;
- five-platform `/tmp/LuneX-18-7_1-builds-r2.KWXQQF`: macOS and fixed
  iPhone/iPad/Apple TV/Vision Pro unsigned Debug all have zero structured
  diagnostics, one AIR, and one metallib each.

The Keychain and live-host opt-ins remained unset. Fixed UUIDs were build
destinations only; no Simulator lifecycle action was performed. These results
prove deterministic projection, shared-owner regression, and target
compilation. They do not prove simulator navigation, physical focus/remote
behavior, television HDR, audible spatial audio, signed installation, live
Sunshine, latency, performance, power, or thermal behavior. Tasks 7.2-8.8
remain responsible for those separate product and acceptance layers.

## Task 7.2 accessible visionOS actual-state controls

Task 7.2 adds `VisionStreamControlPresentationState` as a read-only value
projection. It does not create another session, surface, decoder, presenter,
input owner, controller registry, HDR resolver, audio graph, coordinator, or
diagnostics store. `AppModel.visionStreamControlPresentationState` accepts an
active visionOS stream only when stream/media ownership is current. Its
window, input, controller, video, HDR, audio, spatial, immersive, and failure
inputs come only from existing current owners.

The projection always emits eight rows in this order:

1. Window
2. Input
3. Controllers
4. Render
5. HDR
6. Spatial
7. Immersive
8. Failure

Window state requires matching visionOS windowed-presentation and scene-surface
revision plus surface generation. Input requires the same presentation/input
revision and input generation. Controller rosters must match the current input
generation and contain only visionOS leases; routed count may not exceed the
bounded connected count. Coordinator video/audio must match the current
session, media generation, and platform. Any replacement or foreign-platform
mismatch fails the affected row closed rather than combining two owners.

Typed visionOS HDR fallback precedes the generic HDR presentation. Spatial
state is active only for an actual available visionOS route with a bounded
channel count and `.visionFixed` or `.visionHeadTracked` presentation.
Immersive state reports windowed-only only when immersive, passthrough,
stereoscopic, and volumetric unavailable features are all present. The
projection exposes fixed bounded copy and never host, session, generation,
revision, frame, controller lease/vendor, display, route, or arbitrary failure
identity.

`VisionStreamControls` is compiled only for visionOS. It uses native SwiftUI,
one destructive Disconnect command, a stable responsive maximum width, and an
accessibility label/value for each status row. It has no hover handler,
relative-mouse preference, `ImmersiveSpace`, `RealityView`, or second media
surface.

Retained offline evidence:

- focused `/tmp/LuneX-18-7_2-focused-r4.TEoRbz`: `10/10` passed with zero
  structured build diagnostics;
- related `/tmp/LuneX-18-7_2-related.uFebig`: 12 current-owner classes,
  `235/235` passed with zero structured build diagnostics;
- normal `/tmp/LuneX-18-7_2-normal.NqSJtS`: `1107 total / 1106 passed / 1`
  exact real-Keychain opt-in skip / zero failures and expected failures;
- fixed Vision Pro direct `/tmp/LuneX-18-7_2-vision-direct.DcmiIV`: unsigned
  Debug, zero structured diagnostics, one AIR, and one metallib before the
  final revision-coherence refinement;
- final five-platform `/tmp/LuneX-18-7_2-builds.ewkEpO`: macOS and fixed
  iPhone/iPad/Apple TV/Vision Pro unsigned Debug all have zero structured
  diagnostics, one AIR, and one metallib each after that refinement.

The Keychain and live-host opt-ins remained unset. Fixed UUIDs were build
destinations only; no Simulator inventory or lifecycle action was performed.
These results prove deterministic projection, current-owner regression, and
target compilation. They do not prove simulator window/input behavior,
physical Vision Pro HDR brightness, audible spatial audio or head tracking,
signed installation, live Sunshine, comfort, latency, performance, power, or
thermal behavior. Tasks 7.3-8.8 remain responsible for those layers.

The repository pre-gate
`/tmp/LuneX-18-7_2-repository-pre-r3.kVhSoZ` and post-mark final-state
`/tmp/LuneX-18-7_2-final-state.McIoFj` confirm stable generated project
membership, the complete retained evidence above, one 7.2 checkbox change,
and OpenSpec `39/50` with 7.3 next. No test, build, Keychain, live-host, or
Simulator lifecycle operation was repeated for the post-mark gate.

## Task 7.3 platform Settings with desired and actual state

Task 7.3 adds `TVVisionPlatformSettingsPresentationState` as a read-only value
projection. It creates no runtime owner, diagnostics store, or new persisted
field. Input capture and controller routing remain the existing automatic
capability-, focus-, platform-, and generation-gated behavior. tvOS and
visionOS Settings show this desired automatic behavior next to current bounded
Capture/Input and Controllers state; they do not show macOS relative-mouse or
system-shortcut controls, the iOS virtual-controller control, or a new toggle
that runtime admission does not enforce.

The projection always emits five rows in this order:

1. Input
2. Controllers
3. Render
4. HDR
5. Spatial Audio

Render desired state comes from the existing fit/fill preference, HDR from the
existing enabled preference, and Spatial Audio from the existing spatial and
head-tracking preferences. Current values come only from the 7.1 tvOS or 7.2
visionOS actual-state projection. A tvOS Settings projection rejects a visionOS
actual state, a visionOS projection rejects a tvOS state, and mixed state fails
all actual values closed. The result never exposes host, session, generation,
revision, frame, controller, display, or route identity.

`SettingsView` keeps macOS/iOS controls on their prior branch. On tvOS and
visionOS, each platform item uses native `LabeledContent` for `Desired
behavior` and `Current state`, fixed bounded detail, and one accessibility
label/value. Render, HDR, and spatial controls continue to mutate and save the
same `AppSettings`; input and controller automatic behavior is read-only.

Retained offline evidence:

- focused `/tmp/LuneX-18-7_3-focused-r2.bz5JHc`: `8/8` passed with zero
  structured build diagnostics;
- related `/tmp/LuneX-18-7_3-related.borVj3`: `164 total / 163 passed / 1`
  exact real-Keychain opt-in skip / zero failures and expected failures;
- normal `/tmp/LuneX-18-7_3-normal.nbTbVF`: `1115 total / 1114 passed / 1`
  exact real-Keychain opt-in skip / zero failures and expected failures;
- fixed Apple TV and Vision Pro direct `/tmp/LuneX-18-7_3-direct.J396Zs`:
  unsigned Debug, zero structured diagnostics, one AIR and one metallib each;
- five-platform `/tmp/LuneX-18-7_3-builds.1DhVeP`: macOS and fixed
  iPhone/iPad/Apple TV/Vision Pro unsigned Debug all have zero structured
  diagnostics, one AIR, and one metallib each.

The Keychain and live-host opt-ins remained unset. Fixed UUIDs were build
destinations only; no Simulator inventory or lifecycle action was performed.
These results prove deterministic Settings projection, persisted-preference
reuse, related migration/runtime behavior, and target compilation. They do not
prove Simulator navigation, signed installation, physical input/controller,
HDR, audible spatial audio/head tracking, live Sunshine, comfort, latency,
performance, power, or thermal behavior. Tasks 7.4-8.8 remain responsible for
those layers.

The repository pre-gate `/tmp/LuneX-18-7_3-repository-pre.gu3Wdy` and
post-mark final-state `/tmp/LuneX-18-7_3-final-state.8JTYco` confirm stable
generated project membership, the retained evidence above, one 7.3 checkbox
change, and OpenSpec `40/50` with 7.4 next. No test, build, Keychain,
live-host, or Simulator lifecycle operation was repeated for the post-mark
gate.

## Task 7.4 privacy-bounded platform diagnostics

Task 7.4 extends the existing `DiagnosticsStore`; it does not create another
coordinator log, export store, or runtime owner. `AppModel` publishes a platform
value only after the existing current session, media generation, platform,
presentation ownership, and sequence checks accept the coordinator snapshot.
It begins one opaque lease per accepted presentation ownership and ends that
lease through the same replacement, failure, reconnect, remote-termination,
and stop clear path.

The lease enforces monotonic source revisions. A later revision with the same
platform and semantic state advances the fence without appending an event; an
older revision, a conflicting value at the same revision, or an old lease is
inert. Actionable current state also records its lease. Recovery or lease end
clears only actions still owned by that lease. A different runtime action, and
an identical current action reasserted by a non-platform runtime, both remove
platform ownership so later platform recovery cannot clear them. History is
never removed by recovery and remains bounded by the store's single global
capacity.

Every platform diagnostic is fixed category, severity, code, summary, and
recovery action text. It contains no host, session, generation, revision,
frame, controller, display, or route identity. Export omits `DiagnosticEvent.id`
and all runtime ownership fields, then re-redacts every textual column for
embedded secrets, UUIDs, URLs/network locations, and identity assignments.
macOS, iOS/iPadOS, and visionOS use native `ShareLink`. tvOS 26.4, where
`ShareLink` is unavailable, displays an accessible disabled `Export
Unavailable` toolbar state and does not synthesize another transport.

Retained offline evidence:

- focused `/tmp/LuneX-18-7_4-focused-r5.wyn9qr`: `32/32` passed with zero
  structured build diagnostics, one AIR, and one metallib;
- related `/tmp/LuneX-18-7_4-related.9efE6X`: `152/152` passed with zero
  skips, failures, expected failures, or structured build diagnostics;
- normal `/tmp/LuneX-18-7_4-normal.AHM4Rr`: `1122 total / 1121 passed / 1`
  exact real-Keychain opt-in skip / zero failures and expected failures;
- fixed Apple TV and Vision Pro direct
  `/tmp/LuneX-18-7_4-direct-r2.2mQR5s`: unsigned Debug, zero structured
  diagnostics, one AIR and one metallib each;
- five-platform `/tmp/LuneX-18-7_4-builds.HlcDxq`: macOS and fixed
  iPhone/iPad/Apple TV/Vision Pro unsigned Debug all have zero structured
  diagnostics, one AIR, and one metallib each.

The Keychain and live-host opt-ins remained unset, so the permitted Keychain
test was skipped and normal tests continued to use file fallback. Fixed UUIDs
were build destinations only; no Simulator inventory or lifecycle action was
performed. These results prove deterministic ownership, deduplication,
replacement, recovery, redaction, application wiring, and target compilation.
They do not prove app or Simulator runtime, signed installation, physical
input/HDR/spatial audio, live Sunshine, latency, performance, power, or thermal
behavior. Tasks 7.5-8.8 remain responsible for those layers.

## Task 7.5 localized and adaptive application regression

Task 7.5 retains the existing tvOS and visionOS runtime, presentation,
Settings, and diagnostics owners. `TVStreamControlPresentationState`,
`VisionStreamControlPresentationState`, and
`TVVisionPlatformSettingsPresentationState` now expose fixed display fields as
`LocalizedStringResource`. Controller counts, routed counts, and audio channel
counts remain interpolated inside the localization resource path. SwiftUI uses
localized `Text` and `Label` values, including explicit localized accessibility
labels and values; no host, session, generation, revision, frame, controller,
display, route, or arbitrary reason becomes user-visible copy.

`TVVisionStreamControlsLayout` selects compact vertical status rows for a
compact horizontal size class or an accessibility Dynamic Type size, and wide
grid rows otherwise. `ViewThatFits(in: .horizontal)` provides a final compact
fallback when the wide grid cannot fit. tvOS removes the old fixed minimum
width that could defeat this fallback, retains Hide Controls before Disconnect,
and keeps Hide Controls as default focus. visionOS keeps one Disconnect command
and does not create `ImmersiveSpace` or `RealityView`.

The application audit exposed one actual-state defect. The geometry input
snapshot retains its source revision, while the platform coordinator rebrands
scene, input, display, audio, and video under one current semantic revision.
The old visionOS UI path compared the source presentation object with the
coordinator's rebranded windowed presentation and therefore reported Window
and Input unavailable for a complete current coordinator state. The corrected
projection takes synchronized scene and input presentation only from the
already validated current coordinator, requires matching presentation
ownership, current revision, and surface generation, then assembles the
read-only input snapshot used by the UI. Capture remains derived from the live
input owner. Missing synchronized components, an old revision, a replacement
surface, or foreign ownership still fails closed.

Connected application tests cover:

- tvOS default focus, focus section, Hide Controls-before-Disconnect order,
  overlay/local/remote ownership, balanced remote commands, and clean clearing;
- visionOS synchronized current Window/Input state, partial coordinator state,
  stale and replacement ownership, compact/wide layout, and the single command;
- localized resources, plural/count interpolation, accessibility label/value,
  bounded privacy copy, desired/actual Settings separation, supported legacy
  audio-settings migration, and the absence of unsupported toggles or
  immersive runtime; and
- local stop, remote termination, and reconnect clearing of application
  projections without erasing persisted desired settings.

Retained offline evidence:

- focused `/tmp/LuneX-18-7_5-focused-r6.MlK4I5/Focused.xcresult`: `33/33`
  passed, zero skips, failures, expected failures, or structured build
  diagnostics, with one AIR and one metallib;
- related `/tmp/LuneX-18-7_5-related.UQqYF6/Related.xcresult`: `217 total /
  216 passed / 1` exact real-Keychain opt-in skip / zero failures and expected
  failures, with zero structured build diagnostics, one AIR, and one metallib;
- normal `/tmp/LuneX-18-7_5-normal.9MVpwm/Normal.xcresult`: `1123 total / 1122
  passed / 1` exact real-Keychain opt-in skip / zero failures and expected
  failures, with zero structured build diagnostics, one AIR, and one metallib;
- fixed Apple TV and Vision Pro direct
  `/tmp/LuneX-18-7_5-direct-r2.l0qZ4X`: unsigned Debug, zero structured
  diagnostics, one AIR and one metallib each; and
- five-platform `/tmp/LuneX-18-7_5-builds.g4vZQT`: macOS and fixed
  iPhone/iPad/Apple TV/Vision Pro unsigned Debug all succeeded with zero
  structured diagnostics, one AIR, and one metallib each.

The generator was byte-stable before and after the task at SHA-256
`aee5f8cb55fffe616537d30eb933012a068658cea6e67ac48d06c3b236d8ed5e`.
The Keychain and live-host opt-ins remained unset, so normal and related tests
used file fallback and the only skip was the explicit real-Keychain test. Fixed
UUIDs were build destinations only; no Simulator inventory or lifecycle action
was performed. The normal run is task 7.5 regression evidence and does not
complete task 8.1. None of this proves Simulator runtime, signed artifacts,
physical Siri Remote/controller/window/input behavior, television or headset
HDR, audible spatial audio or head tracking, live Sunshine, comfort, latency,
performance, power, or thermal behavior. Tasks 8.1-8.8 remain responsible for
those separate acceptance layers.

The corrected repository pre-gate
`/tmp/LuneX-18-7_5-repository-pre-r3.1O8JBJ` passed fixture self/tree
validation, OpenSpec strict `9/9`, pre-mark `41/50` with task 7.5 next, three
identical generator hashes, exact 20-file scope, generated-project membership,
localization, adaptive layout, focus, current visionOS projection, migration,
accessibility, privacy, retained test/build/Metal, Keychain skip, clean-room,
dependency, opt-in, process, and proof-tier gates. Only task 7.5 was then marked
complete; task 8.1 and all later acceptance tasks remain pending.

Post-mark final-state `/tmp/LuneX-18-7_5-final-state.cb0UO9` confirmed OpenSpec
strict `9/9`, exact `42/50` with task 8.1 next, exact 21-file final scope, the
single task 7.5 checkbox replacement, stable generated project and retained
evidence, disabled opt-ins, no residual build process, and unchanged proof
boundaries. It did not rerun the generator, tests, builds, or any Simulator
lifecycle action.

Corrected final diff audit `/tmp/LuneX-18-7_5-final-audit-r2.7dsVBW`
confirmed the 21-file scope as five production, five test, six OpenSpec, two
runtime-document, and three planning files. The test diff adds 69 assertions
while replacing 37 direct String assertions with localized-resource
equivalents, adds one test function, removes none, and introduces no skip or
disable path. Production ownership, the single task 7.5 checkbox, generated
project, reference, dependency, opt-in, process, and proof boundaries remain
unchanged.

Final record `/tmp/LuneX-18-7_5-final-record.fepytG` reconfirmed baseline remote
parity, OpenSpec strict `9/9`, `42/50` with task 8.1 next, the final file
classification, the only 7.5 checkbox change, stable project membership, all
three final gates, retained evidence, disabled opt-ins, and proof boundaries.

## Task 8.1 complete normal-suite verification

Task 8.1 runs the complete `LuneXCoreTests` normal suite from a fresh evidence
directory on the macOS test destination. The command explicitly removes
`LUNEX_RUN_KEYCHAIN_TEST` and `LUNEX_RUN_LIVE_HOST_TEST`; it therefore exercises
the normal Debug file identity fallback and does not request real Keychain or
live Sunshine access. It performs no Simulator inventory or lifecycle action.

Fresh `/tmp/LuneX-18-8_1-normal.GjIqrj/Normal.xcresult` reports `1123 total /
1122 passed / 1 skipped / 0 failed / 0 expected failure`. The sole skip is
exactly
`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`.
Structured build results report `succeeded`, zero warnings, errors, and analyzer
warnings, with one AIR and one metallib in the isolated DerivedData.

This evidence proves the current complete normal deterministic suite with the
two opt-ins disabled and file fallback active. It does not prove real Keychain
authorization, live-host interoperability, Simulator runtime, signed
installation, physical Apple TV or Vision Pro input/HDR/spatial audio,
performance, power, or thermal behavior. Tasks 8.2-8.8 remain responsible for
those separate gates.

Corrected repository pre-gate
`/tmp/LuneX-18-8_1-repository-pre-r2.gPOMhm` passed fixture self/tree,
OpenSpec strict `9/9`, pre-mark `42/50` with task 8.1 next, three identical
generator hashes, exact six-file authority scope, the fresh normal summary and
single skip, zero structured build diagnostics, Metal artifacts, disabled
opt-ins, file fallback, clean-room, dependency, process, and proof-tier gates.
Only task 8.1 was then marked complete; tasks 8.2-8.8 remain pending.

Post-mark final-state `/tmp/LuneX-18-8_1-final-state.uybdfA` confirmed OpenSpec
strict `9/9`, exact `43/50` with task 8.2 next, exact seven-file authority
scope, the single task 8.1 checkbox replacement, stable project and normal
evidence, disabled opt-ins, no residual build process, and unchanged proof
boundaries. It did not rerun the generator, normal suite, or any Simulator
lifecycle action.

Final audit `/tmp/LuneX-18-8_1-final-audit.fk0oho` confirmed a seven-file
authority-only scope with no production or test diff, the single task 8.1
checkbox replacement, OpenSpec `43/50` with task 8.2 next, all normal/pre/post
evidence, stable project/reference/dependency state, disabled opt-ins, and the
same proof boundaries.

Final record `/tmp/LuneX-18-8_1-final-record.w4fV2U` reconfirmed baseline remote
parity, OpenSpec strict `9/9`, `43/50` with task 8.2 next, the seven-file
authority-only scope, the only 8.1 checkbox change, fresh normal/pre/post/audit
evidence, stable project/reference/dependency state, disabled opt-ins, and proof
boundaries.

## Task 8.2 five-platform Debug and Release builds

Task 8.2 runs ten fresh isolated unsigned build actions from current commit
`97e932af8857022f9df653536dd5b5981445e1f9`: macOS and the fixed iPhone, iPad,
Apple TV, and Vision Pro destinations in both Debug and Release. Each action
uses its own DerivedData, log, and `.xcresult`, sets
`CODE_SIGNING_ALLOWED=NO`, and enables Swift, Clang, and Metal
warnings-as-errors. The fixed UUIDs are passed only to `xcodebuild
-destination`; no Simulator inventory or lifecycle command is executed.

Fresh `/tmp/LuneX-18-8_2-builds.Dvqg9S` contains all ten results. Structured
verification reports the following for every platform/configuration pair:
`succeeded / 0 warnings / 0 errors / 0 analyzer warnings / 1 AIR / 1
metallib`. This includes macOS, iPhone, iPad, tvOS, and visionOS Debug and
Release without reusing task 7.5's Debug-only evidence.

The matrix proves current unsigned SDK compilation, warnings-as-errors, and
Metal artifact production. It does not prove code signing, provisioning,
installation, launch, Simulator runtime, physical television/headset HDR,
audible spatial audio or head tracking, remote/controller/window input, live
Sunshine, latency, comfort, performance, power, or thermal behavior. Tasks
8.3-8.8 remain responsible for those separate gates.

Repository pre-gate `/tmp/LuneX-18-8_2-repository-pre.GRQL3w` passed fixture
self/tree, OpenSpec strict `9/9`, pre-mark `43/50` with task 8.2 next, three
identical generator hashes, exact six-file authority scope, all ten structured
build results, ten AIR and ten metallib artifacts, disabled opt-ins, no residual
process, and repository/proof-tier gates. Only task 8.2 was then marked
complete; tasks 8.3-8.8 remain pending.

Post-mark final-state `/tmp/LuneX-18-8_2-final-state.tVJVek` confirmed OpenSpec
strict `9/9`, exact `44/50` with task 8.3 next, exact seven-file authority
scope, the single task 8.2 checkbox replacement, stable project/build/pre-gate
evidence, disabled opt-ins, no residual build process, and unchanged proof
boundaries. It did not rerun the generator, builds, or any Simulator lifecycle
action.

Final audit `/tmp/LuneX-18-8_2-final-audit.WMG1HZ` confirmed the seven-file
authority-only scope, no production or test diff, the single task 8.2 checkbox
replacement, OpenSpec `44/50` with task 8.3 next, the complete ten-row build
summary and pre/post evidence, stable project/reference/dependency state,
disabled opt-ins, and unchanged proof boundaries.

Final record `/tmp/LuneX-18-8_2-final-record.hv5iVY` reconfirmed baseline remote
parity, OpenSpec strict `9/9`, `44/50` with task 8.3 next, the authority-only
scope, the only 8.2 checkbox change, all ten builds and pre/post/audit evidence,
stable project/reference/dependency state, disabled opt-ins, and proof
boundaries.

## Task 8.3 repository and analyzer gates

Fresh macOS Analyze evidence is retained at
`/tmp/LuneX-18-8_3-analyzer.1Edacz`. Debug and Release each use an independent
DerivedData directory, log, and `.xcresult`; both structured build results are
`succeeded / 0 errors / 0 compiler warnings / 4 analyzer findings`. Their
normalized findings are identical. All four belong to the byte-identical
pinned ENet dependency: dead stores at `compress.c:320`, `unix.c:521`, and
`unix.c:526`, plus the existing null-dereference path at `unix.c:867`. LuneX
first-party source and both repository-owned bridges have zero findings. These
are Analyze actions, not the zero analyzer-warning field from task 8.2's normal
build actions.

Repository pre-gate `/tmp/LuneX-18-8_3-repository-pre.1yCWep` passes fixture
self/tree validation, OpenSpec strict `9/9`, pre-mark `44/50` with task 8.3
next, and generator stability. The baseline plus three generated
`project.pbxproj` files have the same SHA-256
`aee5f8cb55fffe616537d30eb933012a068658cea6e67ac48d06c3b236d8ed5e`.
Exact generated membership covers 114 production compile sources and 83 test
sources. `references/` remains ignored and untracked; there is no package,
submodule, tracked binary framework, or GPL production input. Eighteen shipped
ENet source/header/license files are byte-identical to pinned revision
`aca87840b57f045a1f7f9299e4b1b9b8e2a5e2f1`, and the retained license contains
the complete MIT grant.

Configuration checks retain the head-pose entitlement only for macOS, iOS, and
tvOS, no visionOS entitlement file or build setting, and the single iOS/iPadOS
`UIBackgroundModes = ["audio"]` declaration. Both diagnostic stores remain
finite and apply runtime plus export redaction; source contains no global
`UIScreen.main`/`connectedScenes` scan or dynamic private-framework lookup.
The retained task 1.6 probe at `/tmp/LuneX-18-1_6-api.ZD2a58` remains readable
and source-hash valid: 24 positive device/simulator compiles, 12 expected
negative compiles, zero unexpected results, and zero runtime, Simulator
lifecycle, signing, physical-device, or Keychain action. Current tvOS/visionOS
26.4 availability is additionally bounded by task 8.2's ten current-source
builds and strict C/Objective-C bridge/vendor compilation against macOS, iOS
Simulator, tvOS Simulator, and visionOS Simulator SDK 26.4.

Both real-Keychain and live-host opt-ins remain unset and no residual build
process, staged change, generated-project drift, reference drift, or tracked
artifact exists. No Simulator inventory or lifecycle action was run for task
8.3. This proves repository/static/API-compile/analyzer integrity only. It does
not prove Simulator runtime, signed installation, physical remote/controller/
window behavior, HDR brightness, audible spatial audio or head tracking, live
Sunshine, latency, comfort, performance, power, or thermal behavior. Tasks
8.4-8.8 remain separate.

## Task 8.4 sanitizer and resource gates

The first fresh complete AddressSanitizer run at
`/tmp/LuneX-18-8_4-asan.x8oZgs` completed 1,123 tests as 1,121 passed, one
explicit real-Keychain skip, and one failed application integration test. Its
structured build result succeeded with zero warnings, errors, and analyzer
warnings, and its log contained no AddressSanitizer or LeakSanitizer error or
summary. The failure occurred before the initial spatial-audio runtime state was
observed because the test helper allowed only one hundred `Task.yield()` calls;
it was a scheduling assumption, not a finite wall-clock wait or a reported
memory error.

Fresh isolated AddressSanitizer evidence at
`/tmp/LuneX-18-8_4-asan-isolated.bEFRLG` passed the same test in 0.027 seconds.
The correction is test-only: the initial video receiver, audio receiver, audio
engine, and AppModel audio-runtime wait in that integration test now uses a
two-second `ContinuousClock` deadline with one-millisecond cooperative sleep.
On timeout it records all four sub-states plus the session phase and returns
before producing a secondary unwrap failure. Production state, the shared test
helper, and all other call sites remain unchanged. Post-fix targeted ASan at
`/tmp/LuneX-18-8_4-asan-targeted.Cgh65F` passed 1/1 with zero build and sanitizer
diagnostics.

The new complete ASan result at
`/tmp/LuneX-18-8_4-asan-complete.kglBGp/Complete-ASan.xcresult` is `1123 total /
1122 passed / 1 skipped / 0 failed / 0 expected failure`. The only skip is
`HostAndPersistenceTests.testRealKeychainIdentityRoundTripWhenExplicitlyEnabled()`.
Structured build results are `succeeded / 0 warnings / 0 errors / 0 analyzer
warnings`; the log contains zero AddressSanitizer errors, LeakSanitizer errors,
or sanitizer summaries. Both real-Keychain and live-host opt-ins were unset.

The independent complete TSan result at
`/tmp/LuneX-18-8_4-tsan-complete.SlgWeu/Complete-TSan.xcresult` has the same
`1123 / 1122 / 1 / 0 / 0` result and exact skip. Its structured build results
are also zero-diagnostic, and the log contains zero ThreadSanitizer warning,
error, or summary and no data-race mention. ASan and TSan use separate fresh
DerivedData and result-bundle ownership.

The first 413-test malloc selection at
`/tmp/LuneX-18-8_4-malloc-resource.qymDw4` passed, but it was not accepted as
the resource proof because its stack-logging messages came from build tools and
did not directly establish the `xctest` environment. The corrected evidence at
`/tmp/LuneX-18-8_4-malloc-explicit.DYbtJZ` first completes a fresh
`build-for-testing`, then explicitly places `MallocScribble=1`,
`MallocPreScribble=1`, `MallocGuardEdges=1`, and `MallocStackLogging=1` in the
generated test target `EnvironmentVariables` and disables parallelization. The
saved and executed `.xctestrun` SHA-256 is
`e7b6593d35cc29e65cba00edd8a7776d08a9699208960610cffe2807cc6ccd81`.

The actual `xctest` process reports guard pages, freed-block scribbling, and
MallocStackLogging lite mode. `Explicit-Malloc.xcresult` contains exactly the
thirteen selected suites and reports `413/413 passed`, zero skips, failures, or
expected failures. The test-without-building action requests no build and has
zero structured warning, error, and analyzer-warning diagnostics; the log has
no malloc corruption, invalid or double free, abort, segmentation fault, or
`EXC_BAD_ACCESS`. Of those tests, 226 identifiers directly match observer or
handler cancellation, held release, frame/audio completion, replacement, late
callback, resource, stop, or teardown behavior.

This is bounded offline macOS sanitizer/resource evidence. It means the tested
paths passed under the named diagnostics without a corresponding report; it is
not proof that every process allocation is leak-free. No Simulator inventory or
lifecycle command was used for task 8.4. These results do not prove a signed
artifact, physical remote/controller/window behavior, HDR brightness, audible
spatial audio or head tracking, live Sunshine, latency, comfort, performance,
power, or thermal behavior. Tasks 8.5-8.8 remain separate.

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
