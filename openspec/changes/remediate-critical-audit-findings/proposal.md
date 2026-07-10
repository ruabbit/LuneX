## Why

The current native shell can persist a fabricated pairing identity and report a stream as active before any Moonlight transport exists. The compact iPhone shell also opens on a sidebar that does not advance to the working detail view, while the local data importer copies private-key material into a plaintext JSON file.

## What Changes

- Prevent placeholder pairing logic from marking or persisting a host as paired.
- Prevent launch controls from starting a remote app or reporting `Streaming` until a real transport implementation is available.
- Stop exporting Moonlight-qt private-key material to plaintext JSON by default and remove the legacy generated identity copy.
- Provide compact iPhone navigation that directly exposes Library, Stream, Diagnostics, Settings, and Add Host.
- Make unavailable protocol functionality explicit in the UI and diagnostics instead of presenting false success.
- Add regression tests for pairing-state preservation and unavailable transport behavior.

## Capabilities

### New Capabilities

- `runtime-integrity`: Safety requirements for pairing, launch state, local identity handling, and honest capability reporting while protocol transport remains incomplete.
- `compact-navigation`: Touch-first compact-width navigation and host-management accessibility for iPhone and narrow iPad windows.

### Modified Capabilities

- None. The original bootstrap change remains an implementation scaffold and has not been archived into baseline specs.

## Impact

- Affects `AppModel`, the SwiftUI root/library/stream UI, Moonlight-qt import tooling, workflow tests, and project tracking files.
- This change deliberately disables unsafe placeholder actions; it does not claim to implement real Moonlight pairing or media transport.
- No upstream GPL source is copied or linked.
