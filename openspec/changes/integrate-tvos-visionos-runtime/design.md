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
colorspace, layer, and display-mode APIs. If tvOS cannot configure the existing
Metal layer for extended range, HDR input uses the established HDR-to-SDR path.
If visionOS cannot provide current headroom, it also remains typed SDR fallback
even when the layer accepts extended-range intent. No setting or stream
metadata alone publishes active HDR.

A separate platform decoder or an unverified private compositor API was
rejected. Physical television/headset HDR remains a hardware gate.

### Reuse the session-owned audio graph and platform route adapters

tvOS and visionOS reuse canonical PCM, one AVAudioEngine graph, route and
interruption recovery, generation replacement, and AppModel actual state from
stage 16. tvOS uses public route/head-tracking capability where available.
visionOS uses the public intended-spatial-experience path and does not claim the
listener head-tracking property that its SDK does not expose. Route or media
reset rebuilds the current graph once and makes old completions inert.

### Integrate through one platform presentation coordinator

`NativeSessionMediaEnvironment` owns one platform presentation coordinator per
media generation. It combines scene/surface, input eligibility, decoded-frame
presentation, display/HDR, audio route, and teardown effects, while `AppModel`
accepts only current-generation snapshots. Platform UI renders that actual
state and commands the current coordinator rather than fabricating status from
preferences.

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
