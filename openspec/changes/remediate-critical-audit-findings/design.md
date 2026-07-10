## Context

The bootstrap implementation intentionally introduced testable state machines and platform policy types before the Moonlight protocol and media layers existed. The production SwiftUI shell currently calls those placeholders as though they were real operations, allowing a local PIN to overwrite a valid pinned identity and allowing a launch response to become `Streaming` without transport. The iPhone compact presentation also exposes only the split-view sidebar.

## Goals / Non-Goals

**Goals:**

- Make all user-visible state truthful and prevent placeholder code from mutating trusted pairing data.
- Keep imported host and app-cache test data usable without duplicating private-key material.
- Restore a complete compact-width navigation path on iPhone.
- Preserve protocol seams so real pairing and transport can replace the temporary unavailable capability cleanly.

**Non-Goals:**

- Implement Moonlight certificate exchange, RTSP, media decode, audio decode, or remote input transport in this change.
- Claim background, HDR, spatial-audio, or PiP runtime completion.
- Copy or link upstream GPL implementation code.

## Decisions

- Add explicit runtime capability flags to `AppModel`. Pairing and streaming actions fail closed when their real implementations are unavailable. This is preferred over retaining demo behavior behind production-looking controls.
- Keep paired imported hosts readable, but never allow placeholder pairing to replace their pinned identity.
- The import tool writes only non-secret host/settings/catalog fixtures by default. A legacy generated identity JSON is deleted because the authoritative Moonlight-qt preferences remain intact.
- Use a compact `TabView` on iPhone/narrow iPad windows and retain `NavigationSplitView` for regular-width and desktop platforms.
- Compact Library content uses a vertical layout instead of the desktop two-column grid.

## Risks / Trade-offs

- [Risk] Pair and Launch controls become unavailable until real protocol work lands. → Mitigation: explain the exact limitation in the UI and diagnostics instead of reporting false success.
- [Risk] Removing the generated identity JSON could surprise local testing scripts. → Mitigation: the file is derived from the untouched Moonlight-qt source preferences and was never consumed by LuneX.
- [Risk] Platform-specific navigation branches can drift. → Mitigation: add an explicit compact root and verify the fixed iPhone simulator after each UI change.

## Migration Plan

1. Stop writing and remove the legacy `moonlight_qt_identity.json` copy.
2. Deploy fail-closed pairing and transport capability behavior.
3. Replace the iPhone compact root with direct tab navigation.
4. Add regression tests and run the existing platform build matrix.

Rollback is a normal Git revert; no authoritative Moonlight-qt data is modified.

## Open Questions

- The next protocol change must choose between a clean-room Swift implementation and GPL-compatible reuse of `moonlight-common-c`.
- Client certificate/key generation and Keychain migration format will be specified with real pairing transport.
