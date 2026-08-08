## 1. Product State Foundations

- [x] 1.1 Audit the existing `AppModel`, root scenes, workflow views, endpoint parser, diagnostics, tests, and platform targets; record the exact compatibility and proof boundaries before production edits.
- [x] 1.2 Define stable product issue, presentation, severity, and checked action-token value contracts with no arbitrary provider strings or private host context.
- [x] 1.3 Add manual-host draft normalization and typed validation through `HostEndpointParser`, including whitespace, hostname, IPv4, bracketed IPv6, explicit port, credential, and invalid-input cases.
- [x] 1.4 Define `ProductWorkspaceID`, generation, workspace-local navigation/presentation state, and checked workspace references without duplicating runtime owners.
- [x] 1.5 Add a process-level workspace registry that creates, restores, replaces, reconciles, and closes workspaces with monotonic generation and fail-closed stale references.
- [x] 1.6 Add focused deterministic tests for issue/action privacy, endpoint validation, workspace identity, replacement, reconciliation, and close behavior.

## 2. Host, Pairing, And Catalog Workflows

- [x] 2.1 Migrate host selection, first-use presentation, refresh state, and manual-add draft/result state from global fields to the owning workspace.
- [x] 2.2 Keep Add Host presentation open until awaited validation and persistence succeed, select the normalized host on success, and present field-safe correction on failure.
- [x] 2.3 Bind catalog loading, cached/empty/current/failure presentation, selection, and retry actions to workspace and selected-host generations.
- [x] 2.4 Bind pairing progress, PIN entry, cancellation, failure, retry, and late-event rejection to checked workspace, host, and attempt generations.
- [x] 2.5 Define typed host removal and trust-reset confirmation workflows that preserve unrelated hosts and require clean teardown before destructive mutation of an active owner.
- [x] 2.6 Recompose the SwiftUI host, pairing, and catalog surfaces for first-use, loading, empty, cached, failed, retry, confirmation, and completed states.
- [x] 2.7 Add application tests for first-use restoration, valid/invalid manual entry, host-switch staleness, pairing cancel/retry/replacement, catalog recovery, trust reset, and stop-and-remove sequencing.

## 3. Session Recovery And Stream Controls

- [x] 3.1 Record and validate the initiating workspace identity/generation alongside the existing active session and media/input generation owners.
- [x] 3.2 Define an actual-state session command reducer for launch, reconnect, resume, stop, unavailable providers, remote termination, reconnect exhaustion, and terminal failures.
- [x] 3.3 Replace launch/recovery display strings with typed product issues and checked actions that revalidate workspace and session ownership at invocation.
- [x] 3.4 Make cancel, retry, reconnect, and repeated stop idempotent across overlay, window close, scene transition, and replacement completion paths.
- [ ] 3.5 Bind stream overlay visibility, focus handoff, local commands, and stop confirmation to the owning workspace while keeping system-reserved commands out of remote input.
- [ ] 3.6 Recompose compact and wide stream presentation so controls remain reachable without permanently obscuring video and without relying on hover.
- [ ] 3.7 Add application tests for provider absence, duplicate launch, owner and non-owner commands, recoverable interruption, remote termination, stale termination, reconnect exhaustion, repeated stop, and clean teardown.

## 4. Native Multiwindow Workspaces

- [ ] 4.1 Add scene/workspace creation and restoration wiring for macOS and iPadOS while retaining a single checked workspace on unsupported configurations.
- [ ] 4.2 Migrate navigation selection, selected host, sheets, dialogs, validation, retry state, and overlay presentation to workspace-local bindings.
- [ ] 4.3 Reconcile shared host, trust, catalog, and settings repository mutations into every live workspace without transferring session ownership.
- [ ] 4.4 Implement and test the owning-window close policy for inactive, launching, streaming, reconnecting, replaced, and already-stopping sessions.
- [ ] 4.5 Hide unsupported window commands on tvOS/visionOS and preserve typed single-workspace ownership for platform focus/input adapters.
- [ ] 4.6 Add deterministic two-workspace application tests for isolated navigation/selection/presentation, shared data updates, stale generation rejection, non-owner commands, and close policy.

## 5. Accessibility And Adaptive Interaction

- [ ] 5.1 Define localized semantic descriptors for every host, pairing, catalog, stream, settings, and diagnostics state and action, including roles, values, eligibility, and destructive status.
- [ ] 5.2 Replace fixed dashboard and compact control assumptions with adaptive layouts that remain nonoverlapping at accessibility Dynamic Type and narrow macOS/iPadOS window sizes.
- [ ] 5.3 Add predictable macOS/iPadOS keyboard focus, default/cancel actions, Voice Control names, and local handling for system-reserved shortcuts.
- [ ] 5.4 Enforce native touch target sizing, text expansion, state communication independent of color, and reduced-motion transitions.
- [ ] 5.5 Complete tvOS overlay focus order/restoration and visionOS reachability semantics from actual focus/input eligibility.
- [ ] 5.6 Add deterministic accessibility descriptor, focus-policy, reduced-motion, longest-localized-text, Dynamic Type, compact/wide, touch-target, tvOS, and visionOS application tests.

## 6. Privacy-Bounded Diagnostics And Export

- [ ] 6.1 Map pairing, host, catalog, launch, recovery, input, media, HDR, audio, and platform failures into stable privacy-bounded product issues and actions.
- [ ] 6.2 Remove workflow-facing `Error.localizedDescription`, arbitrary provider text, endpoint/identity echoes, and untyped error/action strings from observable UI state and views.
- [ ] 6.3 Specify and enforce bounded diagnostic retention, deterministic deduplication, category-specific clearing, and stable privacy-safe export records.
- [ ] 6.4 Add a native diagnostics export/share workflow that requires neither Keychain access nor live-host communication and labels offline/Simulator proof tiers honestly.
- [ ] 6.5 Add adversarial redaction and stale-action tests covering PIN, endpoints, certificates, key material, host/device identity, provider bodies, replaced workspaces, and replaced sessions.

## 7. Integrated Product Workflow Validation

- [ ] 7.1 Add deterministic end-to-end application tests for first use, restored/imported data, manual host, pairing, app refresh, launch, input-mode transition, reconnect, remote termination, stop, removal, and recovery.
- [ ] 7.2 Verify settings, diagnostics, host, pairing, catalog, stream, and overlay navigation in compact iPhone, wide iPad/macOS, tvOS focus, and visionOS windowed-state application harnesses.
- [ ] 7.3 Run the normal test suite with `LUNEX_RUN_KEYCHAIN_TEST` and `LUNEX_RUN_LIVE_HOST_TEST` unset; confirm the only accepted skip remains the explicit real-Keychain test.
- [ ] 7.4 Run macOS, iOS/iPadOS, tvOS, and visionOS Debug and Release build gates without changing signing or representing unsigned builds as signed artifacts.
- [ ] 7.5 Run strict concurrency, generator/dependency drift, analyzer, sanitizer, malloc/resource, and privacy/static-contract gates appropriate to the changed ownership and UI surface.
- [ ] 7.6 Reuse the bounded existing Simulator inventory to exercise only real workflow targets that exist; do not create a launch-only UI target or duplicate/start a second device of any class.
- [ ] 7.7 On authorized physical macOS, iPhone/iPad, Apple TV, and Vision Pro configurations, validate VoiceOver/Voice Control, hardware keyboard/touch/remote/focus, multiwindow, live Sunshine recovery, and clean stop without conflating unavailable hardware tiers.

## 8. Documentation And Stage Acceptance

- [ ] 8.1 Document the workspace/session ownership, native workflow, accessibility, privacy/redaction, and diagnostic export contracts with migration and rollback boundaries.
- [ ] 8.2 Synchronize OpenSpec, completion roadmap, planning files, feature matrix, and user-facing documentation with the implemented behavior and remaining signed/physical/live gaps.
- [ ] 8.3 Run strict OpenSpec validation and a fresh stage-level deterministic regression; audit source, tests, configuration, references, simulator lifecycle, Keychain opt-ins, and proof-tier claims.
- [ ] 8.4 Record a stage 19 acceptance matrix separating offline deterministic, Simulator, signed artifact, physical device, assistive technology, and live-host evidence; keep unmet physical tasks pending.
