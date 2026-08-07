## Context

LuneX has tvOS and visionOS application targets, shared SwiftUI navigation,
VideoToolbox/Metal/audio foundations, value-level Siri Remote/focus and
GameController adapters, typed HDR platform capability resolution, and stage 16
spatial-audio policy. The targets compile, but neither platform owns an actual
session-scoped product runtime comparable to the macOS or iOS/iPadOS paths.

The current `GameControllerPlatformMonitor` only publishes a connection list;
it does not own element handlers, player-slot registration, held state,
feedback, or session replacement. `TVRemoteFocusInputAdapter` maps synthetic
values and a small `UIPress` enum, but no actual stream surface admits presses
or coordinates SwiftUI focus with remote delivery. visionOS shares the generic
UIKit/Metal surface without an explicit window/scene/input contract. Existing
HDR policy intentionally falls back on tvOS when layer EDR is unavailable and
on visionOS when current headroom is unavailable. Those fallbacks are truthful
compile-time decisions, not physical-output proof.

The implementation must preserve Swift 6 concurrency isolation, one decoder,
the existing Moonlight input/control transport, clean-room licensing, normal
test Keychain fallback, fixed simulator discipline, and separate offline,
simulator, signed-artifact, physical-device, and live-host proof tiers.

## Goals / Non-Goals

**Goals:**

- Make actual tvOS focus, remote presses, controllers, scene/surface lifecycle,
  Metal presentation, HDR policy, and audio route state belong to the current
  session/media/input generations.
- Make actual visionOS window/scene/surface geometry, visibility, supported
  input, Metal presentation, HDR policy, and spatial-audio route state belong
  to the current generation.
- Reuse the existing decoder, frame source, input provider, presenter, audio
  graph, diagnostics, AppModel, and teardown rather than creating parallel
  platform stacks.
- Publish accessible native controls and truthful actual state while keeping
  raw controller, focus, scene, window, display, route, and host identity out of
  persistent diagnostics.
- Pass deterministic, cross-platform, sanitizer/resource, and fixed-simulator
  gates, with signed and physical behavior separately accepted.

**Non-Goals:**

- Treating target compilation, a connected controller, a simulator launch, or
  a user setting as proof of remote delivery, HDR, spatial audio, or live
  streaming on Apple TV or Apple Vision Pro.
- Forwarding system-reserved Back/Menu/Home, recenter, capture, volume, or
  safety gestures to the host.
- Adding a second decoder, an AVPlayer placeholder, a software-frame copy path,
  or a platform-specific Moonlight transport.
- Enabling immersive-space streaming, stereoscopic/volumetric video, or
  passthrough composition without a later explicit design and hardware gate.
- Copying or linking Moonlight GPL implementation code.

## Decisions

### Use immutable platform snapshots and generation leases

Each platform gets main-actor owners for actual framework objects and shared
Sendable snapshots for scene activity, surface geometry, focus/input
eligibility, controller slots, display capability, audio route, and bounded
failure state. Snapshots carry checked session/media/input/surface generations
and semantic revisions. Replacement first invalidates handlers and observers,
then publishes replacement state.

Passing `UIWindowScene`, `UIFocusEnvironment`, `UIPress`, `GCController`,
`UIScreen`, or audio-route objects into actors was rejected because those
objects are mutable, identity-sensitive, and not Sendable.

### Separate tvOS navigation focus from stream input capture

Outside an active stream, the Siri Remote and controller D-pad/select remain
owned by SwiftUI focus navigation. During a stream, a dedicated surface input
owner admits only explicitly supported presses while the overlay is dismissed
and the current input generation is ready. Overlay presentation immediately
returns directional/select ownership to local focus. Back/Menu and other
system-reserved commands always remain local and may stop capture or reveal the
overlay through native behavior.

At the existing remote-input provider boundary, admitted directional presses
resolve to the corresponding Win32 arrow virtual keys, Select resolves to
Return, and Play/Pause resolves to the media Play/Pause virtual key. The
resulting canonical keyboard events use the existing Moonlight keyboard wire
codec and held-key registry. UI-specific remote and focus identities never
become new protocol packet types.

Globally intercepting all remote presses was rejected because it breaks tvOS
navigation and system escape semantics. Mapping SwiftUI focus movement itself
to host input was rejected because focus identity is local UI state, not a
remote game event.

### Bind real GameController profiles to the existing remote registry

A main-actor controller owner assigns deterministic current-generation slots,
installs extended/micro gamepad value handlers, normalizes analog/dead-zone
values, sends complete snapshots through the existing controller registry, and
applies supported feedback only to the matching live controller lease. Held
state is released through the existing ordered release barrier on disconnect,
focus loss, scene loss, provider failure, replacement, and stop.

Using vendor names as durable controller identity was rejected. Opaque runtime
leases and bounded slot indices are sufficient; marketing names may be shown
ephemerally but are not persisted in diagnostics.

### Make the actual platform stream surface the lifecycle authority

tvOS and visionOS extend the current `MTKView` bridge with attachment, layout,
window-scene activity, visibility, scale, drawable, and focus eligibility
callbacks. One normalized revision drives drawable size, fit/fill rendering,
and any absolute/indirect input mapping. Invalid or detached geometry clears
presentation and closes input.

Scanning `connectedScenes`, using a global screen size, or deriving geometry
from requested stream resolution was rejected because multiwindow, resizing,
display changes, and view attachment would diverge.

Task 5.1 keeps that single actual-view owner and adds a generation-owned
window observation around it. The observer weakly tracks the current
`UIWindow` and `UIWindowScene`, replaces all tokens when either identity
changes, and maps public visible, hidden, key, resign-key, active, inactive,
background, and foreground notifications back into the existing surface
callbacks. Every queued notification also carries a private observation UUID,
so removal of the old token is not the only late-event barrier. visionOS focus
eligibility is the actual visible, interactive, current key window; tvOS keeps
its existing focus-engine `canBecomeFocused` rule. The observer never advances
geometry or writes drawable state: the existing geometry owner remains the
single semantic-revision and drawable writer.

Task 5.2 reuses that owner rather than introducing a visionOS-specific mapper.
The actual SwiftUI update order first synchronizes the requested source size
and fit/fill mode into `StreamMetalPresenter`, then publishes the exact
coordinate snapshot from `TVVisionUIKitStreamGeometryBindingOwner` through
`MobileStreamSurfaceCoordinator`. Render coordinates and
`TVVisionStreamAbsoluteInputMapping` therefore carry the same
`TVVisionSemanticRevision`, resolved video rectangle, source crop, and input
reference size. A fit-to-fill transition advances that shared semantic
revision and changes crop-aware absolute mapping without creating an
independent presenter or input revision. Detach, nonfinite bounds, invalid
drawable geometry, or unavailable coordinates clear drawable size, render
coordinates, and absolute mapping together. Task 5.3 remains responsible for
installing public keyboard, pointer, indirect-input, and controller adapters
and admitting their events to the current generation.

Task 5.3 uses direct XROS 26.4 compile probes rather than header-name inference.
The actual Metal view reads public `UIPress.key` hardware keys, becomes first
responder only while its current window is key and the view is visible and
interactive, and installs hover plus scroll recognizers whose touch type is
restricted to `.indirectPointer`. `UIPress` exposes no public repeat flag on
this SDK, so a supported key produces one balanced down/up pair with repeat
set false; Escape and Command-Q/H/Tab remain local. Direct touch and unsupported
spatial interaction are not converted into pointer events. A framework-free
adapter maps supported HID usages and current crop-aware absolute coordinates
to the existing canonical input events. `AppModel` performs capability,
ownership, surface/input generation, and focus admission both when the UIKit
event is captured and immediately before serialized asynchronous delivery.

The existing GameController slot owner is parameterized with a platform while
retaining tvOS as its default. visionOS leases use the same complete-snapshot
registry, opaque routing identity, motion, and feedback contracts. Routed
roster state records the last state successfully delivered to the host, so
valid intermediate sends remain the base for later disconnect differences;
late completion is rejected after cancellation, generation replacement,
release admission closure, or focus loss. Task 5.3 cancels surface handlers and
current deliveries on replacement, but task 5.5 still owns the complete ordered
held-state release barrier and restoration of local UI ownership.

### Keep visionOS windowed streaming explicit

Stage 18 supports the actual SwiftUI window containing the Metal stream
surface. It records window geometry and scene activity, respects system gesture
reservations, and admits only SDK-supported controller, keyboard, pointer, or
indirect events. No `ImmersiveSpace`, `RealityView`, stereoscopic surface, or
volumetric promise is created by this change.

This bounded scope provides a usable native visionOS client without hiding the
additional comfort, recentering, depth, safety, and rendering work required for
immersive streaming.

### Resolve video and HDR from actual platform capability

Both platforms reuse `StreamVideoPresentationSource`,
`HDRRenderConfigurationResolver`, `HDRSurfaceAdapter`, and
`StreamMetalPresenter`. Direct SDK probes determine available screen/headroom,
colorspace, layer, and display-mode APIs. On tvOS 26.4 the public layer contract
uses `preferredDynamicRange`, `toneMapMode`, and `contentsHeadroom`, not the
legacy extended-range intent/metadata properties that tvOS does not expose.
Direct tvOS EDR requires an attached screen and Metal layer, both tone-map and
content-headroom controls, an available extended-linear Display P3 or ITU-R
2020 color space, and finite `1 < current <= potential <= 64` headroom. Missing,
nonfinite, out-of-range, inverted, or SDR-only headroom remains a typed fallback.

The preferred-dynamic-range surface contract carries the resolved current
headroom and applies pixel format, color space, tone-map mode, content headroom,
and dynamic-range preference as one rollback-capable transaction. Returning to
SDR selects standard dynamic range, automatic tone mapping, zero content
headroom, and the SDR surface. Legacy macOS, iOS, and visionOS intent/metadata
transactions remain separate. Task 4.2 establishes this public capability and
surface foundation. Task 4.3 observes only the actual tvOS stream screen and
Metal layer, publishes deduplicated surface-owned display revisions, and applies
only a matching current component through the coordinator and AppModel. A new
source closes old render state before asynchronous application, and surface
replacement, revision exhaustion, failure, reconnect, and stop clear display
ownership. No setting or stream metadata alone publishes active HDR.

If visionOS cannot provide current headroom, it remains typed SDR fallback even
when the layer accepts extended-range intent.

A separate platform decoder or an unverified private compositor API was
rejected. Physical television/headset HDR remains a hardware gate.

### Reuse the session-owned audio graph and platform route adapters

tvOS and visionOS reuse canonical PCM, one AVAudioEngine graph, route and
interruption recovery, generation replacement, and AppModel actual state from
stage 16. tvOS uses public route/head-tracking capability where available.
visionOS uses the public intended-spatial-experience path and does not claim the
listener head-tracking property that its SDK does not expose. Route or media
reset rebuilds the current graph once and makes old completions inert.

Task 4.4 does not add another AVAudioSession observer or audio graph. The
existing notification source, route-capability reader, entitlement reader,
native audio processor, and canonical graph publish one checked runtime event
containing actual route counts/support, graph generation, runtime stage, event
cause, spatial presentation/readback, fallback, and entitlement. A bounded
tvOS publisher rejects stale sequence or graph generation, semantically
deduplicates equivalent state, and normalizes interruption, media-service loss,
reset, and recovery. `NativeSessionMediaEnvironment` replays the latest valid
snapshot when current tvOS presentation ownership activates or is replaced,
then applies later events only to that ownership. Invalid runtime, revision
exhaustion, or audio action failure closes the current coordinator; failed or
stopped snapshots contain no audio route. visionOS application remains task
6.4.

Task 4.5 keeps the existing surface owner, display observer, decoder, audio
graph, input owner, coordinator, and resource teardown. When the same actual
stream view survives a media-generation reconnect, it explicitly replays the
current normalized geometry and then the current tvOS display event without
advancing either semantic revision. `AppModel` admits those values only into
the new current media ownership, preserving the application order `activate`,
scene, input, then display; the latest audio route continues to replay through
the single native media environment and audio publisher. Failure, replacement,
remote termination, local stop, and concurrent terminal requests converge on
the coordinator's one terminal snapshot and the environment's one five-resource
teardown. Old-generation callbacks, state, frames, and completions remain inert.

Task 4.6 verifies that completed tvOS media behavior as one connected sequence,
not as an inventory of isolated unit cases. One coordinator regression starts
with invalid current headroom and typed HDR-to-SDR output, presents a current
frame, resubmits it after geometry change, applies a direct-EDR display change,
rejects an old decoder frame, then carries audio interruption, media-services
loss, graph replacement on reset, and current-graph recovery into one clean
local stop. The terminal snapshot clears presentation, display, audio route,
and video state and runs the coordinator teardown effect once. Existing
`AppModel` workflow coverage observes current direct headroom and spatial mode,
replacement graph and route state, and reconnect or remote-termination
clearing through public actual state. This task adds no production bypass or
parallel runtime.

### Integrate through one platform presentation coordinator

`NativeSessionMediaEnvironment` owns one platform presentation coordinator per
media generation. It combines scene/surface, input eligibility, decoded-frame
presentation, display/HDR, audio route, and teardown effects, while `AppModel`
accepts only current-generation snapshots. Platform UI renders that actual
state and commands the current coordinator rather than fabricating status from
preferences.

The actual Metal surface and the coordinator meet at one main-actor
presentation owner. `AppModel` injects that same owner into the production
coordinator and SwiftUI surface; once bound, `StreamMetalPresenter` accepts
only coordinator-admitted frames and never falls back to the shared latest
frame. The owner validates platform, session, media/presentation/input
ownership, action sequence, platform and delivery revisions, decoder/frame
identity, and surface generation. Scene loss, invalid geometry, explicit
display unavailability, clear, teardown, unbind, and presenter stop close the
actual presentation; a matching rebind or newer geometry revision may
resubmit only the current admitted frame.

An as-yet-unprobed display is intentionally sufficient only for baseline SDR
video in task 4.1. It is not HDR capability or headroom proof. Task 4.2 defines
the public tvOS layer/display capability and transactional render contract;
task 4.3 connects actual screen mode/brightness observation, checked semantic
display revisions, current-source identity admission, render configuration,
and privacy-bounded direct-EDR or typed fallback state through the coordinator
and AppModel. Task 4.5 completes same-view reconnect through current-value
geometry followed by display replay at unchanged semantic revisions; it does
not create a display-specific bypass or a second platform runtime.

### Preserve proof tiers and simulator discipline

Deterministic tests and fixed simulator checks prove reducers, ownership,
navigation, and build compatibility only. Simulator inventory is read once per
gate and existing fixed devices are reused; no duplicate device class is
created or booted. Signed installation, Siri Remote feel, controller feedback,
television/headset HDR, spatial audio, Vision Pro interaction, performance,
thermal state, and live Sunshine require authorized physical receipts.

## Risks / Trade-offs

- [Risk] tvOS focus and stream capture may both react to one press. ->
  Mitigation: one current-generation admission owner, overlay-first local
  ownership, balanced begin/end/cancel tracking, and reserved-command tests.
- [Risk] controller callbacks may arrive after disconnect or replacement. ->
  Mitigation: per-controller leases, current slot generation checks, handler
  removal before release, and ordered held-state cleanup.
- [Risk] visionOS input APIs differ from UIKit assumptions. -> Mitigation:
  direct public SDK probes, protocol-driven adapters, and typed unavailable
  states rather than conditional compilation that silently admits nothing.
- [Risk] drawable/focus callbacks can churn during window changes. ->
  Mitigation: finite normalization, semantic deduplication, and one revision
  shared by renderer and input.
- [Risk] platform HDR capability is weaker than desired. -> Mitigation: retain
  correct HDR-to-SDR rendering and expose actual fallback; only add direct HDR
  after public API and physical proof.
- [Risk] platform audio route changes can race session teardown. -> Mitigation:
  reuse serialized graph generations and shared teardown operations.
- [Risk] simulator behavior differs materially from Apple TV/Vision Pro. ->
  Mitigation: keep physical and live tasks unchecked and label evidence tiers.

## Migration Plan

1. Inventory current source ownership and public tvOS/visionOS 26.4 APIs without
   changing runtime behavior.
2. Add immutable scene/surface/focus/input/controller/display/audio contracts
   and deterministic reducers.
3. Implement tvOS actual focus/press/controller and surface lifecycle owners.
4. Implement visionOS actual window/surface and supported input owners.
5. Connect platform video/HDR/audio presentation to the current media
   generation and AppModel, including failure/replacement/stop cleanup.
6. Add native controls/status, accessibility, diagnostics, and settings.
7. Run normal, cross-platform, analyzer, sanitizer/resource, generator,
   OpenSpec, and fixed-simulator gates.
8. Complete separately authorized signed Apple TV/Vision Pro and live Sunshine
   acceptance. Until then, rollback is local focus plus typed unsupported input,
   SDR fallback, and clean stream suspension/stop.

## Open Questions

- Which Apple TV model, Siri Remote generation, controllers, television HDR
  modes, audio routes, and Sunshine host will provide physical acceptance?
- Which Apple Vision Pro OS/build, controllers/keyboards, window sizes, audio
  route, and comfort-duration budget will provide physical acceptance?
- Should a later change add an immersive-space presentation mode after the
  windowed path, or remain window-only for the first product release?
