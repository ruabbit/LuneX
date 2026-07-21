## Why

LuneX now has authenticated remote-input delivery, media ownership, and live AppKit window notifications, but the macOS application still does not capture real `NSEvent` input, own cursor capture, release held remote state on focus loss, or propagate occlusion and display geometry through the active session. Stage 14 closes that native application boundary so the existing runtime can behave correctly in a real macOS stream window without overstating missing live-host evidence.

## What Changes

- Add a session-scoped macOS input coordinator that captures supported keyboard, pointer, button, and scroll events from the actual stream view and sends typed events through the active remote-input provider.
- Implement reversible cursor hide and relative-pointer capture that is enabled only for a visible, key, active stream window and is restored on focus loss, occlusion, stop, detach, or failure.
- Connect window focus loss to an ordered `releaseAll` barrier so held keys, pointer buttons, and controller state cannot remain owned remotely while local input capture is disabled.
- Propagate occlusion, minimization, key status, application activation, screen changes, backing-scale changes, and live resize to renderer, presentation queue, decoder policy, and input capture without disconnecting the control session.
- Use one view-relative, backing-aware transform derived from decoded source size, drawable size, content mode, and the actual video rectangle for direct pointer mapping and resize/display transitions.
- Add deterministic AppKit-free policy tests, focused macOS integration tests, teardown/race tests, diagnostics, and Debug/Release validation. Authorized Sunshine receipt and hardware behavior remain explicit later gates.

## Capabilities

### New Capabilities
- `macos-native-input-capture`: Real macOS keyboard, pointer, scroll, cursor-capture, focus-release, and active-session delivery behavior.
- `macos-session-lifecycle-control`: Session-owned propagation of AppKit visibility, focus, screen, resize, and backing changes to render, decode, presentation, and input policies.
- `stream-coordinate-transform`: A single source/drawable/video-rectangle coordinate contract shared by presentation and absolute remote input.

### Modified Capabilities

None. Existing change-local lifecycle and remote-input specs remain historical contracts; this change adds the production integration requirements that connect them.

## Impact

- Affects `LuneXApp`, `LuneXPlatform`, `LuneXInput`, `LuneXCore`, and `LuneXRendering`, plus generator-owned Xcode source lists and macOS-focused tests.
- Introduces AppKit event-monitor and cursor-association ownership that must remain main-actor isolated, balanced, reversible, and session-generation scoped.
- Extends the injected session environment with bounded platform-input and lifecycle-control interfaces; it does not add a placeholder media receiver or make production streaming available.
- Uses only Apple frameworks and repository-owned Swift. No GPL source, linked Moonlight artifact, or new third-party dependency is introduced.
