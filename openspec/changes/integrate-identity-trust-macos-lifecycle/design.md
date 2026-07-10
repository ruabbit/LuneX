## Context

The current Keychain store is unit-testable only through an in-memory substitute and is not selected by the app. Repeated unsigned/debug rebuilds can trigger authorization friction, so development needs a deliberate fallback after Keychain functionality is confirmed. HTTPS clients currently use `URLSession.shared`, which cannot authenticate Sunshine's self-signed certificate using the host's imported pin. The AppKit lifecycle monitor is never attached to a window.

## Goals / Non-Goals

**Goals:**

- Verify the real Keychain implementation once without making every test touch Keychain.
- Use a private Debug file store for the remainder of iterative testing while retaining Keychain as the Release default.
- Authenticate Moonlight HTTPS endpoints by exact leaf-certificate pin.
- Drive renderer policy, drawable size, and EDR state from the actual macOS window and screen.

**Non-Goals:**

- Generate a final Moonlight-compatible certificate or complete pairing.
- Implement media transport or decoding.
- Enable insecure trust-all TLS behavior.

## Decisions

- `ClientIdentityStoreFactory` selects a JSON file store in Debug and Keychain outside Debug. The Debug file is stored in Application Support with POSIX mode `0600` and is explicitly named as test-only.
- A Keychain integration test is skipped unless `LUNEX_RUN_KEYCHAIN_TEST=1`. It uses a unique service/account and deletes its test item after round-trip verification.
- HTTPS clients require a `PinnedHostIdentity`, compare the server leaf DER exactly, and reject missing/mismatched pins. They never disable trust globally.
- `AppKitLifecycleAttachment` uses an invisible `NSViewRepresentable` to discover the owning `NSWindow` and retain `AppKitLifecycleMonitor` for the scene lifetime.
- `PlatformLifecycleState` publishes display headroom and drawable size; RootView forwards changes into AppModel's render state.

## Risks / Trade-offs

- [Risk] Debug identity data is file-backed. → Mitigation: Debug-only selection, Application Support isolation, `0600` permissions, and explicit test-only filename.
- [Risk] Exact certificate pins fail after a legitimate host certificate rotation. → Mitigation: fail closed and require a future authenticated re-pair flow.
- [Risk] SwiftUI window attachment can occur after initial rendering. → Mitigation: attach when the representable moves to a window and publish a full initial snapshot.

## Migration Plan

1. Run the opt-in Keychain round-trip once.
2. Continue Debug testing with the file fallback.
3. Route HTTPS clients through pinned sessions.
4. Attach macOS lifecycle state and verify occlusion/focus/screen changes.

## Open Questions

- Final certificate generation/import format remains part of real pairing.
- Host certificate rotation UX will be specified with pairing recovery.
