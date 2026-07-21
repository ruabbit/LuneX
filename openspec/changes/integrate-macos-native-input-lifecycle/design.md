## Context

`AppKitLifecycleMonitor` already observes occlusion, key-window, application activation, screen, backing, minimization, and resize notifications. Today those observations update only `StreamRenderState`; the active media environment continues receiving and decoding video, no real `NSEvent` source calls `MacInputAdapter`, cursor policy is not applied, and focus loss does not call the active `RemoteInputProvider.releaseAll`. Drawable size is derived from the whole window content view rather than the actual stream surface, while `InputMapper` independently reconstructs its video rectangle and clamps fit-mode letterbox clicks into the remote image.

The session runtime now provides generation-scoped control/media/input ownership and ordered `send`/`releaseAll` behavior. Stage 14 must connect AppKit to those boundaries without allowing a detached view, stale window, or asynchronous event task to affect a replacement session. Production still lacks video/audio network receivers, so deterministic integration must be injectable and live Sunshine receipt remains a separate proof gate.

## Goals / Non-Goals

**Goals:**

- Capture real macOS keyboard, pointer movement, buttons, and scrolling from the stream surface and deliver ordered typed input to the active session.
- Own cursor visibility and relative association as a balanced, reversible, generation-scoped resource.
- Make focus loss establish a release barrier before input is disabled or a replacement generation accepts events.
- Apply window visibility/focus/geometry changes to render, video-processing, presentation, and input policies without dropping the control session.
- Use one immutable coordinate snapshot for presentation and absolute input, based on actual stream-view backing pixels and decoded source geometry.
- Prove stale-event rejection, ordering, teardown, pause/resume, and transform behavior with deterministic tests and macOS integration gates.

**Non-Goals:**

- Adding placeholder video/audio receivers or making the production provider inventory report stream availability.
- Proving a Sunshine host received input or sustained video; those remain stage 13 live tasks.
- Forwarding secure input, password fields, arbitrary global events, or every macOS system shortcut.
- Implementing HDR tone mapping, spatial audio, PiP, mobile scene continuity, or final controller feedback hardware behavior.
- Using private APIs, accessibility event taps, GPL source, or a new third-party dependency.

## Decisions

### Capture events in a stream-surface AppKit view, not a global event tap

A flipped, first-responder-capable `NSView` attached to the actual stream surface will override key, flags, mouse, button, and scroll handlers. It emits repository-owned value samples and uses `convertToBacking` for absolute points. This keeps capture scoped to the LuneX window and avoids Accessibility permission, global-event privacy exposure, and ambiguity over which stream window owns an event. A local/global `NSEvent` monitor was rejected because monitor callbacks are harder to bind atomically to view geometry and replacement-window ownership.

### Serialize application input through one generation-owned actor

The synchronous AppKit callback enqueues a value event into a bounded FIFO owned by a `MacSessionInputCoordinator`. One consumer maps the event using the coordinate snapshot captured at enqueue time and awaits the existing remote provider. State transitions are never coalesced; only compatible adjacent movement can use the provider's existing bounded coalescing. Focus loss closes admission, queues one `releaseAll` barrier after accepted events, restores the cursor, and allows admission again only for the same active generation after focus returns. Creating one unstructured `Task` per `NSEvent` was rejected because scheduling could reorder key/button transitions.

### Treat cursor state as an explicit balanced resource

A main-actor cursor controller tracks whether LuneX itself hid `NSCursor` and disabled pointer association. It calls each inverse exactly once on policy transition or teardown and never tries to compensate for cursor operations owned by another component. Capture is allowed only when the view is attached to the active stream window, the application and window are focused, the window is visible, and remote relative mode is enabled. Escape exits capture locally; focus, occlusion, stop, detach, and failure always restore the system cursor.

### Reduce occluded video cost while continuing to drain transport

Lifecycle resolution produces a closed directive for rendering, video processing, and input. An occluded, minimized, or zero-drawable stream pauses drawable acquisition and VideoToolbox submission but keeps the receiver consumer draining bounded packets so UDP/control ownership cannot deadlock. Resume invalidates pre-pause presentation, requests a fresh IDR through the session video processor, and only publishes new frames from the current generation. A merely non-key but visible window keeps video active at throttled presentation policy while input capture is disabled and held input is released. Disconnecting on occlusion was rejected because it defeats fast native window recovery.

### Resolve and publish one coordinate snapshot

`StreamCoordinateSnapshot` contains decoded source size, actual drawable size, scale mode, and a resolved video rectangle in drawable pixels. The renderer and `InputMapper` consume the same resolver output. Fit-mode points outside the video rectangle are rejected rather than clamped; fill-mode points map through the cropped rectangle and clamp only the final source coordinate to the legal edge. Each input sample captures the snapshot revision that existed with its view-relative backing point, so a resize or display transition cannot combine old coordinates with new geometry.

### Keep AppKit and provider dependencies injectable

Policy resolution, coordinate mapping, queue state, generation checks, and lifecycle directives remain platform-neutral value/actor code testable in `LuneXCoreTests`. Thin AppKit types own `NSView`, `NSWindow`, `NSCursor`, and CoreGraphics calls behind protocols. `AppModel` exposes bounded session input/lifecycle commands and derives the active session ID internally; SwiftUI never receives provider references or session keys.

## Risks / Trade-offs

- [Risk] Cursor hide/association calls are process-global and can become unbalanced. → Mitigation: one main-actor owner records only operations it performed, restores on every terminal path, and has idempotent transition tests.
- [Risk] Actor reentrancy during focus release could admit later events or release a replacement session. → Mitigation: close admission and capture generation synchronously before awaiting, then validate generation at every suspension boundary.
- [Risk] Pausing decoder submission while draining compressed packets loses reference frames. → Mitigation: discard bounded compressed input while paused, clear presentation, and require a fresh IDR before resuming decoded output.
- [Risk] AppKit coordinates, backing scale, Metal drawable size, and remote source size can update at different times. → Mitigation: publish revisioned immutable snapshots only when all dimensions are positive and bind each absolute event to its enqueue-time snapshot.
- [Risk] Reserved shortcuts or IME behavior can conflict with remote desktop expectations. → Mitigation: keep system-reserved shortcuts local by default, expose explicit forwarding policy, and preserve typed diagnostics for unsupported paths.
- [Risk] Deterministic providers can prove ordering but not host receipt or cursor feel. → Mitigation: keep stage 13 live input and stage 14 hardware/window acceptance tasks pending until authorized evidence exists.

## Migration Plan

1. Add coordinate snapshot and lifecycle directive types with compatibility adapters for the current render state.
2. Add generation-owned input coordination and injectable cursor operations while leaving capture disabled by default.
3. Connect `AppModel` and the media environment, then attach the AppKit input view only to the stream workspace.
4. Enable capture from existing user input settings after deterministic teardown, focus, resize, and replacement tests pass.
5. Validate macOS Debug/Release and all unchanged platform targets; rollback is removal of the attachment while retaining the value policies and existing fail-closed runtime.

## Open Questions

- Which macOS hardware and authorized Sunshine app will be used for final relative-pointer acceleration and live key/button receipt evidence?
- Whether Command-Tab and other process-switching shortcuts should ever be forwardable remains a product setting decision; the initial implementation keeps them local.
