## Context

LuneX has a shared native runtime with checked pairing/session generations, media and input ownership, HDR/EDR presentation, spatial-audio state, platform lifecycle adapters, and typed diagnostics. The SwiftUI shell currently exposes much of that state through one application-wide `AppModel`: navigation selection, selected host, pairing presentation, catalog state, and stream launch state are global even on macOS and iPadOS, and several product errors are still stored as display strings. This change must complete user workflows without introducing parallel protocol or media owners and without weakening the signed/physical/live proof boundaries of stages 13 through 18.

Primary stakeholders are macOS and iOS/iPadOS users; tvOS and visionOS require honest, reachable native behavior. Ordinary tests must keep `LUNEX_RUN_KEYCHAIN_TEST` and `LUNEX_RUN_LIVE_HOST_TEST` unset and use the existing Debug file identity fallback. Simulator validation must reuse at most one existing instance per device class.

## Goals / Non-Goals

**Goals:**

- Provide complete host, pairing, catalog, launch, recovery, stop, settings, and diagnostics workflows with typed recoverable actions.
- Isolate navigation, presentation, selection, and session commands by a checked per-window workspace identity and generation.
- Make accessibility and adaptive-layout behavior part of the product contract and deterministic application test matrix.
- Ensure user-facing errors and diagnostic exports are privacy bounded and cannot replay stale actions.
- Reuse the current session, media, input, HDR, audio, repository, and platform lifecycle owners.

**Non-Goals:**

- Implement a second Moonlight protocol stack, decoder, renderer, audio graph, input transport, or persistence system.
- Claim completion of live Sunshine, signed artifact, physical HDR/display, physical audio route, Apple TV, Vision Pro, assistive-technology, performance, power, or thermal acceptance.
- Copy or link GPL Moonlight source; upstream projects remain behavioral references only.
- Add immersive visionOS presentation or unsupported multiwindow controls.
- Re-run the one-time real Keychain validation during ordinary development.

## Decisions

### Introduce workspace-scoped product state above the existing runtime owner

Add a value-oriented `ProductWorkspaceState` identified by `ProductWorkspaceID` and monotonic generation. A workspace owns navigation, selection, sheets/dialogs, field validation, catalog presentation, launch presentation, overlay visibility, and action descriptors. `AppModel` remains the process-level composition root for shared repositories and the one active runtime, but all UI mutations carry checked workspace identity/generation.

This is preferred over one `AppModel` per window because duplicating `AppModel` would duplicate runtime observers and session/media/input ownership. Retaining the current global UI fields is rejected because one window can currently affect another and stale async completion has no window boundary.

### Make one workspace the explicit active-session owner

Session start records the initiating workspace identity/generation alongside the existing session generation. Stop, reconnect, overlay, and input-capture commands validate both owners. Closing an owning window follows an explicit policy: retain the session only when another declared presentation surface remains attached; otherwise perform idempotent clean stop. There is no implicit ownership transfer in this change.

This is preferred over broadcasting one session to every window because command and input ownership would be ambiguous. Supporting concurrent remote sessions is deferred because the existing runtime is intentionally single-owner.

### Keep stream controls local to the owning workspace

Store requested stream-overlay visibility and stop confirmation in the owning `ProductWorkspaceState`, while deriving actual visibility from the current session owner and any platform input-release barrier. Every show, hide, input, focus, and confirmation command revalidates the complete workspace generation and session identifier. Non-owning, replaced, and stale workspaces fail closed without changing the active session.

Showing controls closes macOS and visionOS remote-input admission and uses the existing tvOS focus/release coordinator; hiding controls can restore capture only when lifecycle, geometry, media generation, focus, and session ownership are still current. macOS Escape, tvOS Menu/Back, and visionOS Escape remain local commands and never enter remote serialization. Confirmed stop clears the workspace-local dialog and joins the existing owner-keyed stop operation so media, input, and control teardown still occur exactly once.

This keeps requested presentation state separate from actual platform eligibility and avoids a second focus or input owner. Compact/wide control composition remains a separate adaptive-layout task.

### Use typed product issues and action tokens

Replace workflow-facing message strings with `ProductIssue` values containing a stable code, localized presentation key, severity, bounded context enum, and optional `ProductActionToken`. Tokens include workspace/session ownership snapshots and are revalidated at invocation. Provider errors map at the application boundary; arbitrary descriptions and response bodies are never copied into observable UI state.

This is preferred over sanitizing strings after presentation because secrets and provider text would already have crossed the product-state boundary. Existing typed `ApplicationDiagnosticEvent` remains the telemetry source and will be adapted rather than replaced.

### Parse host endpoints through the networking domain

Manual entry uses `HostEndpoint` parsing/normalization and returns field-safe validation reasons. SwiftUI does not perform ad hoc address splitting. Persistence occurs only after successful normalization, and the sheet dismisses only after the awaited add operation succeeds.

This reuses a structured domain parser and avoids inconsistent handling of IPv6, ports, whitespace, and credential-bearing URLs.

### Model destructive actions as confirmed asynchronous workflows

Host removal and trust reset use typed confirmation requests. If the target owns an active or transitioning session, the only destructive path is an explicit stop-and-remove operation that awaits idempotent teardown before repository mutation. Cancel leaves all owners unchanged.

This is preferred over immediate toolbar deletion because removing trust or host data during a session can orphan runtime state and makes accidental activation too easy.

### Keep accessibility derived from command and actual state

Views expose localized semantic labels, values, roles, focus order, and disabled states from the same product action eligibility used for invocation. Adaptive layouts use stable grid/list constraints and switch to vertical composition at bounded container states rather than viewport-scaled fonts. Reduce Motion selects reduced transitions, and state never relies on color alone.

Semantic/source tests prove deterministic contracts only. Physical assistive-technology and hardware input evidence remains a separate acceptance tier.

### Add deterministic application workflow harnesses, not launch-only UI claims

Extend application tests around workspace generation, action revalidation, host parsing, destructive sequencing, pairing/catalog staleness, session recovery, diagnostics redaction, accessibility descriptors, and adaptive presentation state. Platform builds and the fixed Simulator inventory are separate gates. A real XCUITest target is considered only if it exercises bounded product workflows; a launch-only target will not be created to manufacture a UI-test claim.

## Risks / Trade-offs

- [Migrating global UI fields can regress existing single-window behavior] -> Introduce a compatibility projection, migrate one workflow at a time, and keep deterministic equivalence tests until direct fields are removed.
- [A process-wide single session limits concurrent windows] -> Make ownership explicit and fail closed; concurrent sessions require a separate runtime architecture change.
- [Typed issue mapping can hide useful debugging details] -> Preserve internal privacy-safe diagnostic codes and bounded metadata while excluding arbitrary payloads and identities.
- [Window close policy differs by platform lifecycle] -> Centralize it in a pure policy reducer and test macOS/iPadOS scene transitions independently of UI presentation.
- [Dynamic Type and localization can destabilize dense dashboards] -> Replace fixed two-row composition with adaptive sections and validate the longest supported localized strings at accessibility sizes.
- [Simulator interaction cannot prove physical focus, VoiceOver, remote, HDR, audio, or live behavior] -> Maintain the five-level proof matrix and leave physical acceptance tasks pending.

## Migration Plan

1. Add workspace identity/state, typed issue/action, endpoint validation, and pure policy reducers behind existing views.
2. Migrate host/pairing/catalog workflows and destructive confirmations, preserving repository formats.
3. Bind launch/recovery/overlay commands to workspace and session ownership, then migrate root navigation and window lifecycle.
4. Recompose SwiftUI views for adaptive accessibility behavior and add redacted diagnostic export.
5. Run focused application tests, normal tests with real Keychain/live-host opt-ins unset, five-platform Debug/Release builds, static/analyzer/sanitizer gates, and bounded existing Simulator workflows.
6. Retain a rollback path by keeping persisted host/settings schemas compatible; code rollback must not require data migration.

## Open Questions

- Whether macOS/iPadOS should later support explicit active-session presentation transfer between windows; this change fails closed instead of implementing transfer.
- Whether a future bounded XCUITest product is justified after deterministic workflow coverage; no launch-only target will be added.
- Physical VoiceOver, Voice Control, hardware keyboard, Apple TV remote, and visionOS interaction acceptance remains dependent on authorized hardware and is not resolved by this design.
