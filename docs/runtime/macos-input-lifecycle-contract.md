# macOS input and lifecycle contract inventory

This inventory freezes the Apple SDK and repository ownership rules that stage
14 must satisfy before native AppKit input is connected to a live session. It
does not claim runtime input delivery or change application behavior.

## Evidence boundary

- Platform contracts were checked against the installed Xcode 26.4 macOS SDK
  headers for AppKit and CoreGraphics.
- Existing LuneX behavior was inspected only in repository-owned production
  sources. Moonlight repositories under `references/` remain read-only
  behavioral references and are not production dependencies.
- The rules below are implementation requirements for later stage 14 tasks.
  They are not live Sunshine or hardware evidence.

## Window and application notifications

| Signal | SDK scope | Required LuneX response |
|---|---|---|
| `NSWindow.didChangeOcclusionStateNotification` | One observed `NSWindow` when registered with that window as `object` | Recompute visibility from `.occlusionState.contains(.visible)` and minimization. Stop presentation and video-processing submission when invisible while allowing the transport/control session to drain. |
| `NSWindow.didBecomeKeyNotification` | One observed window | Recompute focus with `NSApp.isActive`; only the active stream surface may become eligible for remote pointer capture. |
| `NSWindow.didResignKeyNotification` | One observed window | Close input admission, drain accepted input, issue one generation-owned `releaseAll` barrier, and restore the system cursor before any later reactivation. |
| screen/backing/resize notifications | One observed window | Re-read screen and EDR state, then publish actual stream-view backing-pixel geometry. Zero size disables presentation and absolute input. |
| minimize and restore notifications | One observed window | Recompute visibility through the same lifecycle state machine as occlusion. |
| `NSApplication.didChangeScreenParametersNotification` | Application-wide | Re-read the attached stream window and view because displays, modes, geometry, scale, color profile, and EDR headroom may have changed. |
| application active/resign-active notifications | Application-wide | Combine application activity with key-window ownership. Resign closes admission and restores cursor ownership even if a window notification is delayed. |

Application-wide callbacks act only on the monitor's currently attached window
and session generation. Every `attach` first removes observers for the old
window; `detach` removes all tokens and is idempotent. A callback from an old
window, view, coordinate revision, or session generation is rejected rather
than allowed to affect its replacement.

## Scoped event capture

Native input belongs to a flipped, first-responder-capable `NSView` associated
with the actual stream `MTKView`, not to a zero-sized navigation-root observer
or a global Accessibility event tap. View overrides capture key, modifier,
pointer button, movement, drag, and scroll events only while that stream surface
owns the active session.

`NSEvent.locationInWindow` is a window coordinate. Absolute input must first be
converted into stream-view coordinates and then passed through
`convertPointToBacking` or the corresponding backing rectangle conversion. The
resulting backing-pixel point and the renderer consume the same immutable
coordinate snapshot and resolved video rectangle.

Local or global event monitors are not the selected capture mechanism. If a
later bounded use is approved, the opaque value returned by the add API must be
retained and passed to `NSEvent.removeMonitor` during detach.

## Keyboard and modifiers

- `NSEvent.keyCode` is a macOS device-independent virtual key number. It is not
  a Win32 virtual-key code and is not directly valid on the GameStream wire.
- LuneX translates supported macOS virtual keys through an explicit,
  deterministic macOS-to-remote key table before constructing the remote
  keyboard event. Unknown keys fail closed or use a separately specified text
  path; raw `NSEvent.keyCode` passthrough is forbidden.
- Modifier state uses only `deviceIndependentFlagsMask`, followed by an
  explicit mapping into the repository's remote modifier bit set. Device and
  event-coalescing bits are never serialized.
- `flagsChanged` generates balanced modifier transitions. Auto-repeat is
  represented from `isARepeat` without manufacturing an extra key-up.
- Command-Q, Command-Tab, Command-H, Escape-to-exit-capture, and other declared
  local/system shortcuts remain local unless a later explicit user setting and
  specification allow forwarding. Secure-input fields and global events are
  outside this stage.
- Focus loss, failure, stop, detach, and replacement converge on the same
  held-input release barrier; no callback creates an unordered task that can
  overtake earlier key transitions.

The current implementation violates the translation boundary if connected
unchanged: `MacInputAdapter.keyboard` copies `MacKeyboardSample.rawKeyCode` into
`KeyboardInputEvent.rawKeyCode`, and `RemoteInputWireCodec` serializes that
value directly. Later integration must add translation before enabling the
native keyboard production path.

## Pointer and cursor ownership

- Relative motion uses event deltas and never reconstructs movement from a
  constant absolute cursor position.
- Absolute motion uses the revisioned stream-view backing-pixel point. In
  `.fit`, letterbox points are rejected; in `.fill`, cropped source coordinates
  are resolved from the shared video rectangle. Invalid or stale geometry fails
  closed.
- `scrollingDeltaX` and `scrollingDeltaY` are the preferred scroll values. When
  `hasPreciseScrollingDeltas` is false, they represent row/column units and
  require one documented normalization policy instead of being treated as
  pixels. The system's direction-adjusted values are preserved unless the wire
  specification explicitly requires device direction.
- Button state is tracked independently of movement so a focus-loss release can
  release every held button even when no final motion sample arrives.

One main-actor cursor owner tracks only operations performed by LuneX. It calls
`NSCursor.hide()` at most once for each owned hidden interval and
`NSCursor.unhide()` exactly once when leaving it. Relative capture similarly
owns a successful `CGAssociateMouseAndMouseCursorPosition(false)` operation and
restores association with `true` exactly once. Both CoreGraphics return values
are checked. A failed disconnect never records ownership; a failed restore is
reported through privacy-bounded diagnostics and retried only through a defined
state transition, not an unbounded loop.

Cursor capture is eligible only when all of these are true:

1. The view is attached to the active stream window and current session generation.
2. The session and input provider are active.
3. The application is active, the window is key, and the window is visible.
4. Drawable geometry is valid.
5. The persisted remote-pointer mode enables relative capture.

Escape, focus loss, occlusion, minimization, zero drawable size, stop, provider
failure, detach, and generation replacement all disable eligibility and restore
the cursor before ownership is discarded.

## Coordinate and presentation ownership

A coordinate snapshot is an immutable value containing at least:

- a monotonically increasing revision;
- the session generation that owns it;
- decoded source pixel size;
- actual stream drawable size in backing pixels;
- fit/fill mode;
- the resolved drawable video rectangle and source crop;
- validity needed to reject zero, non-finite, overflowed, or stale geometry.

The renderer uses the resolved rectangle from this snapshot. Absolute pointer
mapping uses the same snapshot captured when the synchronous platform sample is
accepted. It does not independently recompute scale after a resize. A sample
whose snapshot or generation is stale is rejected, preventing resize and
multi-display changes from mapping an old point with new geometry.

## Ordered delivery and multi-window ownership

The synchronous AppKit view callback submits a Sendable value sample into one
bounded, generation-owned FIFO. One consumer performs shortcut policy,
translation, coordinate mapping, and awaited remote-provider delivery in FIFO
order. State transitions are never dropped or coalesced. Backpressure may
coalesce only compatible adjacent movement under the already specified provider
rules; overflow fails closed and releases held state.

Focus loss first closes admission, then waits for already accepted samples, then
delivers one shared `releaseAll` barrier. Focus regain cannot reopen admission
until the barrier has completed and all cursor/window/session eligibility checks
still match. Send failure, input-channel failure, remote termination, stop,
detach, and session replacement use the same terminal ownership path.

Only the stream surface that matches the application's active session
generation may attach capture. A second window may render library or settings
content, but it cannot steal the cursor or deliver input for another stream.
Late callbacks are rejected by both attachment identity and generation, not by
assuming observer removal cancels an already queued callback.

## Current repository gaps

- The actual `MacStreamInputCaptureView` now owns Metal presentation, AppKit
  events, window attachment, and backing-pixel geometry. Screen, backing,
  surface layout, and live-resize changes refresh one lifecycle display state.
- Renderer and input mapping now share a revisioned fit/fill coordinate
  resolver, and fit-mode letterbox input is rejected instead of clamped.
- First-responder capture, balanced cursor ownership, the active-session input
  sink, generation-owned FIFO, focus-release barrier, and decoder pause/resume
  policies exist with deterministic tests.
- The remaining stage 14 gap is production application integration: current
  lifecycle directives and input samples are not yet connected through
  `AppModel` to the active media environment, renderer/presentation source,
  session input coordinator, cursor eligibility, or user-facing diagnostics.

Those integration gaps are assigned to stage 14 tasks 5.2 through 5.5.
Production stream availability remains fail closed while concrete video and
audio receivers are absent; this inventory does not satisfy any live-host or
hardware acceptance task.
