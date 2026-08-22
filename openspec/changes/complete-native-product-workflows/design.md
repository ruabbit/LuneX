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

Shared host, trust, catalog, and settings values remain process-level repository projections. Successful host mutations first run checked selection reconciliation, then publish only host-count-derived library phase to every live workspace. A trust reset clears stale pairing presentation only in workspaces selecting that host; authenticated pairing preserves its initiating pairing owner long enough to publish the local completed state while clearing other matching terminal presentation. Catalog mutation keeps its existing owner-keyed current-versus-cached broadcast, and settings remains one observable process value rather than being copied into workspaces. None of these reconciliation paths writes scene attachment, session, media, or input ownership.

### Attach serialized native scenes to checked workspaces

macOS and iOS/iPadOS use a typed `WindowGroup` restoration value containing the `ProductWorkspaceID`. A main-actor scene coordinator owns only ephemeral scene attachments: the first supported scene uses or adopts the primary workspace, later scenes without a restoration value create distinct workspaces, and a disconnected scene that reconnects with the same serialized ID restores the durable navigation/host/app values at the next workspace generation while clearing transient presentation. An ID already attached to a live scene fails closed before registry replacement.

The scene root reads `supportsMultipleWindows` at runtime. Unsupported configurations ignore external scene identities and continue through the one checked primary workspace. tvOS retains one ordinary `WindowGroup`, while visionOS uses one explicitly identified `Window` scene; neither branch exposes application create-window, dismiss-window, or window-menu commands. Scene disconnect validates the ephemeral attachment token before changing session state. Inactive and non-owning scenes only detach, while stale or replaced attachments fail closed. This separates native scene identity from repository/runtime ownership while keeping compatibility projections valid for callers outside the explicit per-scene view path.

The scene workspace is passed through the complete root workflow tree. Navigation selection, selected host/app derivation, Add Host sheet state, destructive confirmation, validation, retry, pairing, catalog, launch, and stream presentation all read or mutate the checked reference supplied by that scene. `AppModel` keeps its legacy primary properties only as single-window compatibility projections; `RootView` and its workflow panels do not rediscover the primary workspace. Add Host dismissal clears only the owning workspace draft after submission is no longer in progress, and stale-generation bindings fail closed at the registry boundary.

### Make one workspace the explicit active-session owner

Session start records the initiating workspace identity/generation alongside the existing session generation. Stop, reconnect, overlay, and input-capture commands validate both owners. Closing an owning scene is reduced from current attachment, owner, actual session phase, and retained-presentation state. A second attachment for the same workspace or actual current-session mobile continuity in picture-in-picture/audio-only retains the original owner; a different workspace never does. Without a retained surface, launching, streaming, and reconnecting owners synchronously reserve the existing owner-keyed stop operation before detach and await clean teardown. An already-stopping close joins that operation, and a stale attachment cannot stop its replacement. There is no implicit ownership transfer in this change.

tvOS focus and remote-command presentation and visionOS input/presentation admission additionally pass through one single-workspace platform-owner check. It accepts only the current active session owner whose checked workspace reference equals the current primary reference. A test-only or internal session started from another live workspace can still use the ordinary checked stop path, but it cannot create a second platform focus/input owner, change the primary overlay/focus state, or serialize input through the product adapter.

The deterministic application matrix uses one `AppModel` with two actual scene attachments rather than parallel runtime owners. It proves independent navigation, selection, sheet, and draft state while catalog, settings, and host mutations remain shared. Disconnecting and restoring the second scene advances its workspace generation, preserves durable local values, clears transient presentation, and makes the prior bindings and attachment inert. A separate timeline starts the only session from one workspace, rejects overlay and stop commands from the other, detaches the non-owner without affecting the session, and closes the owner through the existing clean-stop operation.

This is preferred over broadcasting one session to every window because command and input ownership would be ambiguous. Supporting concurrent remote sessions is deferred because the existing runtime is intentionally single-owner.

### Keep stream controls local to the owning workspace

Store requested stream-overlay visibility and stop confirmation in the owning `ProductWorkspaceState`, while deriving actual visibility from the current session owner and any platform input-release barrier. Every show, hide, input, focus, and confirmation command revalidates the complete workspace generation and session identifier. Non-owning, replaced, and stale workspaces fail closed without changing the active session.

Showing controls closes macOS and visionOS remote-input admission and uses the existing tvOS focus/release coordinator; hiding controls can restore capture only when lifecycle, geometry, media generation, focus, and session ownership are still current. macOS Escape, tvOS Menu/Back, and visionOS Escape remain local commands and never enter remote serialization. Confirmed stop clears the workspace-local dialog and joins the existing owner-keyed stop operation so media, input, and control teardown still occur exactly once.

This keeps requested presentation state separate from actual platform eligibility and avoids a second focus or input owner. Stream composition is selected by a pure layout value that treats compact horizontal size class, accessibility Dynamic Type, an actual finite container width below 900 points, or an invalid width as compact. Compact controls stay in the bottom safe area, scroll within at most 48 percent of the container height, and reflow their command header. Wide controls remain top-leading, use a restrained 640...1040 point width derived from the container, and consume at most 82 percent of its height. tvOS and visionOS receive the outer geometry decision so their command groups also reflow for genuinely narrow windows rather than relying only on size class.

Visible controls and the virtual controller are mutually exclusive, and hidden controls always expose an explicit non-hover restore command. This preserves reachable local commands without permanently covering decoded video. Every Disconnect entry still requests the owning workspace's stop confirmation, tvOS keeps Hide Controls before Disconnect in focus order, and the existing session/input owner checks remain the only authority for restoring capture.

### Use typed product issues and action tokens

Replace workflow-facing message strings with `ProductIssue` values containing a stable code, localized presentation key, severity, bounded context enum, and optional `ProductActionToken`. Tokens include workspace/session ownership snapshots and are revalidated at invocation. Provider errors map at the application boundary; arbitrary descriptions and response bodies are never copied into observable UI state. Task 6.1 closes the mapping gaps for launch pairing, decoder/media, and platform presentation failures, and centralizes runtime mapping on typed diagnostic category/action only; diagnostic code, summary, endpoint, identity, and provider payload are not mapper inputs.

This is preferred over sanitizing strings after presentation because secrets and provider text would already have crossed the product-state boundary. Existing typed `ApplicationDiagnosticEvent` remains the telemetry source and will be adapted rather than replaced.

### Parse host endpoints through the networking domain

Manual entry uses `HostEndpoint` parsing/normalization and returns field-safe validation reasons. SwiftUI does not perform ad hoc address splitting. Persistence occurs only after successful normalization, and the sheet dismisses only after the awaited add operation succeeds.

This reuses a structured domain parser and avoids inconsistent handling of IPv6, ports, whitespace, and credential-bearing URLs.

### Model destructive actions as confirmed asynchronous workflows

Host removal and trust reset use typed confirmation requests. If the target owns an active or transitioning session, the only destructive path is an explicit stop-and-remove operation that awaits idempotent teardown before repository mutation. Cancel leaves all owners unchanged.

This is preferred over immediate toolbar deletion because removing trust or host data during a session can orphan runtime state and makes accidental activation too easy.

### Keep accessibility derived from command and actual state

`ProductSemanticDescriptor` is the typed presentation contract for an accessibility label, value, hint, stable role, actual eligibility, and destructive status. Host, pairing, catalog, stream, settings, and diagnostics surfaces expose stable typed item IDs so views do not reconstruct semantic state from display strings. Labels, values, and hints are `LocalizedStringResource` values. Eligibility distinguishes enabled, in-progress, and disabled with a localized reason; it derives from the same product surface or checked command disposition used for invocation.

Host removal, trust reset, and stream stop descriptors are destructive actions, but a status that describes one of those workflows is not itself a destructive action. Stream controls fail closed for a missing session, non-owner, or stale workspace. Head tracking is disabled when spatial audio is off, diagnostics export distinguishes empty from unsupported state, pairing PIN semantics never include the PIN value, and host semantics never include an address or endpoint.

Views expose those localized semantic labels, values, roles, focus order, and disabled states rather than relying on visual icon recognition. Adaptive layouts use stable grid/list constraints and switch to vertical composition at bounded container states rather than viewport-scaled fonts. Reduce Motion selects reduced transitions, and state never relies on color alone. Task 5.1 establishes the typed/localized descriptor layer. Task 5.2 makes the library dashboard consume actual container width, horizontal size class, and accessibility Dynamic Type through a pure compact/wide policy; compact composition is available on every platform, and fixed host, pairing, and catalog command rows reflow through horizontal-first/vertical-fallback groups. Task 5.3 adds a typed macOS/iPadOS focus policy for Add Host, pairing, and stream controls, native default/cancel actions, and explicit accessibility names for stable Voice Control targets. The persisted legacy shortcut-forwarding field remains decodable, but new defaults, runtime admission, the lower macOS adapter, settings UI, and settings semantics all keep system-reserved shortcuts local. Task 5.4 applies a shared 44-point iOS action target with vertical text expansion, removes app-name truncation, gives navigation/app selection and diagnostic severity non-color markers, and resolves stream-overlay motion to opacity or immediate from Reduce Motion. Task 5.5 gives the tvOS stream surface and overlay one typed focus scope: eligible local controls open on Hide Controls, and closing controls restores the stream surface only from a current handoff/surface state. Its visionOS reachability projection enables Hide Controls only for a visible current window whose actual input state is local solely because the overlay is visible and whose current capability set is nonempty; releasing, captured, unavailable, stale, or capability-empty states remain disabled with a semantic reason. Task 5.6 connects all nine dimensions in two real-`AppModel` application matrices: six semantic surfaces plus longest localized text, keyboard focus, Dynamic Type, compact/wide layouts, touch targets, reduced motion, tvOS focus restoration, and visionOS actual overlay eligibility. The vision projection validates the current owner, surface, scene geometry, input generation, and capability set before reprojecting current runtime focus eligibility under the coordinator's semantic revision; source geometry revisions are not treated as the coordinator revision.

Semantic/source tests prove deterministic contracts only. Physical assistive-technology and hardware input evidence remains a separate acceptance tier.

### Add deterministic application workflow harnesses, not launch-only UI claims

Extend application tests around workspace generation, action revalidation, host parsing, destructive sequencing, pairing/catalog staleness, session recovery, diagnostics redaction, accessibility descriptors, and adaptive presentation state. Platform builds and the fixed Simulator inventory are separate gates. A real XCUITest target is considered only if it exercises bounded product workflows; a launch-only target will not be created to manufacture a UI-test claim.

The session application matrix covers provider absence, duplicate launch, owner and non-owner commands, recoverable interruption, remote and stale termination, reconnect exhaustion, repeated stop, and clean teardown. Existing application tests already covered every case except a stopped generation delivering a late terminal event after its replacement had reached streaming. A test-only provider option, disabled by default, retains that stopped continuation so the race can be injected deterministically; production ownership and teardown code remain unchanged. Offline application tests prove checked generation behavior only and do not replace live-host, signed, physical-device, or platform interaction evidence.

## Risks / Trade-offs

- [Migrating global UI fields can regress existing single-window behavior] -> Introduce a compatibility projection, migrate one workflow at a time, and keep deterministic equivalence tests until direct fields are removed.
- [A process-wide single session limits concurrent windows] -> Make ownership explicit and fail closed; concurrent sessions require a separate runtime architecture change.
- [Typed issue mapping can hide useful debugging details] -> Preserve internal privacy-safe diagnostic codes and bounded metadata while excluding arbitrary payloads and identities.
- [Window close policy differs by platform lifecycle] -> The pure policy reducer consumes only current attachment, checked owner, actual phase, and declared retained presentation; application tests cover inactive, launching, streaming, reconnecting, replaced, retained, and already-stopping paths independently of physical window presentation.
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
