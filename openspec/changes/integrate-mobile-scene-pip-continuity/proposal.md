## Why

LuneX currently has policy-only mobile continuity types and a minimal
`scenePhase` adapter, but the iOS/iPadOS product path does not own an actual
`UIWindowScene`, continuously track Stage Manager/window geometry, run a real
Picture in Picture controller, or bind mobile EDR and legal background
continuity to the active session generation. Stage 17 must turn those
placeholders into native, fail-closed runtime behavior without claiming that a
background mode declaration grants arbitrary execution.

## What Changes

- Add a generation-owned iOS/iPadOS scene and window lifecycle source that
  publishes active/inactive/background state, actual window/view geometry,
  scale, display identity, safe-area and trait revisions for the current stream
  surface.
- Bind continuous iPad window resizing, Stage Manager, display moves and
  foreground restoration to the same drawable/video/input coordinate contract
  used by the renderer and remote input path.
- Add a production `AVPictureInPictureController` adapter backed by an actual
  supported content source, current media frames and a bounded state machine;
  start, stop, restore, failure and stale callback behavior remain scoped to the
  active session/media generation.
- Apply mobile continuity policy only when an actual audio or PiP path is
  active and permitted. Unsupported background states suspend rendering or
  pause the stream instead of attempting indefinite background execution.
- Read actual iOS/iPadOS screen EDR capability/headroom and drive the current
  Metal surface/display revision through typed supported/fallback states,
  including window moves and headroom changes.
- Surface privacy-bounded continuity, PiP, resize and mobile HDR state in native
  diagnostics and product UI without exposing host, frame, display or scene
  identifiers.
- Add deterministic application, cancellation, replacement, accessibility,
  build, sanitizer and simulator gates while reserving physical-device,
  background-duration, PiP presentation, Stage Manager, external-display, EDR,
  power and live-Sunshine proof for explicit hardware acceptance.
- Preserve macOS, tvOS and visionOS behavior and compile boundaries; no
  Moonlight GPL source is copied or linked.

## Capabilities

### New Capabilities

- `mobile-scene-window-lifecycle`: Current-generation `UIWindowScene`, window,
  stream-surface geometry, trait, display, resize and lifecycle ownership for
  iOS/iPadOS.
- `mobile-pip-background-continuity`: Actual Picture in Picture presentation,
  legal audio/PiP background policy, restoration, failure and teardown scoped
  to the active mobile media generation.
- `mobile-display-edr`: Actual mobile display/EDR capability and headroom
  observation connected to the Metal presentation and diagnostic state.

### Modified Capabilities

None.

## Impact

- Affects `LuneXPlatform`, `LuneXRendering`, `LuneXCore`, `LuneXApp` and their
  test-support source membership.
- Adds iOS/iPadOS-only UIKit, AVKit, AVFoundation/CoreMedia and QuartzCore
  adapters behind injectable value/protocol boundaries; shared core remains
  actor-safe and platform-neutral.
- Extends AppModel/media-environment ownership for scene, PiP and mobile display
  generations, plus native Settings/stream status.
- May refine generated Info.plist/background-mode and target membership, but
  will not treat configuration presence or unsigned builds as runtime proof.
- Requires fixed iPhone/iPad simulator builds without creating or duplicating
  devices, followed by separately authorized physical iPhone/iPad, Stage
  Manager, PiP, background audio, external-display, mobile EDR and live
  Sunshine acceptance.
