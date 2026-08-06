## Why

LuneX already compiles tvOS and visionOS application targets, but their product
paths remain mostly shared SwiftUI scaffolding and value-level adapters. Stage
18 must connect actual platform focus, remote/controller input, window and
scene lifecycle, Metal presentation, audio routing, diagnostics, and teardown
without claiming that a successful build proves Apple TV or Apple Vision Pro
runtime behavior.

## What Changes

- Add a generation-owned tvOS input runtime that distinguishes local SwiftUI
  focus navigation from remote stream input, maps supported Siri Remote presses
  and GameController profiles, releases held state on focus/session loss, and
  keeps system-reserved escape/menu behavior local.
- Add tvOS stream-surface lifecycle and media presentation ownership using the
  existing decoder and Metal pipeline, platform-supported drawable/display
  state, typed HDR-to-SDR fallback, AVAudioSession route state, and bounded
  actual-state diagnostics.
- Add a generation-owned visionOS window/scene/surface runtime that tracks
  actual window geometry and visibility, keeps system gestures reserved, and
  admits only supported controller, keyboard, pointer, and indirect-input paths
  under current focus and session ownership.
- Add visionOS Metal and spatial-audio presentation policy with explicit
  windowed-volume limits, typed capability fallback, interruption/recovery,
  replacement, and clean teardown. Immersive-space streaming is not silently
  enabled by this change.
- Route actual tvOS/visionOS platform state through `NativeSessionMediaEnvironment`,
  `AppModel`, stream controls, Settings, accessibility, and privacy-bounded
  diagnostics while preserving macOS and iOS/iPadOS behavior.
- Add deterministic reducer, application, replacement, resource, build, and
  fixed-simulator gates. Keep Siri Remote feel, controller mapping, television
  HDR, spatial audio, Vision Pro interaction, power/thermal behavior, signed
  installation, and live Sunshine proof pending until authorized hardware
  acceptance exists.
- Continue clean-room implementation. Moonlight iOS and Moonlight Qt remain
  read-only behavioral references; no GPL source is copied, linked, or vendored.

## Capabilities

### New Capabilities

- `tvos-remote-focus-runtime`: Current-generation Siri Remote, SwiftUI focus,
  GameController, reserved-system-command, held-state, and session input
  ownership on tvOS.
- `tvos-media-presentation-runtime`: Actual tvOS stream-surface lifecycle,
  Metal/video presentation, typed HDR output policy, audio route state,
  diagnostics, and teardown.
- `visionos-window-input-runtime`: Actual visionOS window/scene geometry,
  visibility/focus, supported indirect and controller/keyboard input, reserved
  system gesture, generation, and teardown ownership.
- `visionos-media-presentation-runtime`: visionOS windowed Metal presentation,
  typed HDR capability policy, spatial-audio route/recovery, diagnostics, and
  clean replacement/stop behavior.

### Modified Capabilities

None.

## Impact

- Affects `LuneXApp`, `LuneXCore`, `LuneXPlatform`, `LuneXInput`,
  `LuneXRendering`, `LuneXAudio`, diagnostics, settings, generator membership,
  tvOS entitlements/configuration, and deterministic test support.
- Introduces tvOS/visionOS-only UIKit, SwiftUI focus/press, GameController,
  Metal, AVFoundation/AVFAudio, and scene/window adapters behind immutable
  Sendable value contracts and main-actor platform-object ownership.
- Reuses the existing Moonlight control/input transport, decoded-frame source,
  Metal renderer, audio graph, HDR resolver, and spatial-audio contracts; it
  does not add a second decoder, proprietary protocol path, or GPL dependency.
- Requires macOS, iOS/iPadOS, tvOS, and visionOS regression builds plus fixed
  simulator inventory discipline. Signed Apple TV/Vision Pro and physical/live
  acceptance remain a separate proof tier.
