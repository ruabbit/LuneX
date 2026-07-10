## Why

LuneX needs a stable client identity and pinned-certificate HTTPS path before real Moonlight pairing and transport can be implemented safely. The macOS lifecycle and EDR adapters also exist only as isolated types and currently do not control the live render state.

## What Changes

- Add a production Keychain identity store path and a Debug-only `0600` file fallback for iterative testing.
- Add an opt-in Keychain round-trip integration test that runs only once when explicitly enabled.
- Add pinned leaf-certificate authentication for Moonlight HTTPS app-list, artwork, launch, and stop requests.
- Attach the macOS window lifecycle monitor to the SwiftUI window and publish occlusion, focus, screen, resize, drawable-size, and EDR headroom changes to the renderer.
- Reconfigure the Metal layer when HDR/headroom or lifecycle policy changes.

## Capabilities

### New Capabilities

- `identity-storage`: Stable client identity storage with production Keychain and controlled Debug file fallback behavior.
- `pinned-transport`: Exact pinned-certificate server authentication for Moonlight HTTPS requests.
- `macos-runtime-lifecycle`: Live macOS window, drawable, render-policy, and EDR integration.

### Modified Capabilities

- None. The bootstrap change has not been archived into baseline specs.

## Impact

- Affects persistence, networking clients, AppModel initialization, AppKit lifecycle adapters, Metal surface behavior, tests, Xcode project generation, and local Debug Application Support data.
- Does not implement real pairing exchange, RTSP, media decode, or remote input transport.
- No upstream GPL code is copied or linked.
