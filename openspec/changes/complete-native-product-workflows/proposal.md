## Why

LuneX now has the platform session, media, input, HDR, spatial-audio, and lifecycle foundations needed to expose a coherent native product, but its user-facing workflows do not yet provide complete recovery, per-window ownership, accessibility, or privacy-bounded failure handling. This change turns those foundations into dependable SwiftUI workflows for macOS and iOS/iPadOS while preserving honest tvOS and visionOS behavior and existing proof boundaries.

## What Changes

- Complete first-use, manual-host, pairing, trust-reset, app-catalog, launch, reconnect, remote-termination, and stop workflows with typed validation and recoverable actions.
- Make stream controls and overlays reflect actual session ownership and state without obscuring video or forwarding system-reserved commands as remote input.
- Introduce checked per-window workspace identity and generation ownership so macOS and iPadOS windows cannot mutate or display another window's host or session state.
- Establish native accessibility behavior for VoiceOver, Voice Control, Dynamic Type, Reduce Motion, keyboard navigation, touch targets, tvOS focus, and visionOS semantics.
- Present and export only typed, redacted product errors and diagnostics; secrets, pairing material, host identity, and arbitrary provider strings remain outside the UI.
- Add deterministic application workflow tests and bounded platform validation without representing source checks, unsigned builds, or Simulator results as signed, physical-device, or live-host proof.

## Capabilities

### New Capabilities

- `native-host-pairing-workflows`: First-use, host discovery/manual entry, pairing, cancellation, retry, trust reset, app-catalog loading, and safe host removal behavior.
- `native-session-recovery-controls`: Launch, reconnect, remote termination, local stop, stream overlay commands, and actual-state recovery behavior.
- `native-multiwindow-workspaces`: Per-window navigation, host selection, session ownership, replacement generations, and isolated macOS/iPadOS workspaces.
- `native-accessibility-interaction`: Cross-platform accessibility semantics, scalable layout, reduced motion, keyboard/touch interaction, tvOS focus, and visionOS reachability.
- `privacy-bounded-product-diagnostics`: Typed user-facing failures, safe recovery actions, redacted diagnostics, and privacy-preserving export boundaries.

### Modified Capabilities

None.

## Impact

- Affects the SwiftUI application shell and views, `AppModel` workflow ownership, session/host action contracts, diagnostics presentation, localization, and application tests.
- Reuses the existing pairing, session, media, input, HDR, spatial-audio, and lifecycle owners; it does not introduce a second protocol, decoder, media graph, input path, or persistence stack.
- Keeps desired and actual runtime state separate and retains the Debug file identity fallback for ordinary testing after the one-time real Keychain check.
- Adds no copied Moonlight source and makes no GPL linkage decision; Moonlight iOS and Moonlight Qt remain read-only behavioral references.
- Does not complete outstanding signed artifact, physical-device, live Sunshine, HDR-display, audio-route, or performance acceptance tasks from stages 13 through 18.
