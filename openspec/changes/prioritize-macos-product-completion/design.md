## Context

LuneX has substantial deterministic implementation across macOS, iOS/iPadOS, tvOS, and visionOS, but the evidence is uneven. The macOS path has native lifecycle, input, Metal/HDR, and spatial-audio integration, while the shared session runtime still lacks concrete production video and audio receive providers and the project has no accepted live Sunshine release candidate. The current numbered roadmap permits later platform work while earlier physical/live gates remain open, so task order no longer reflects the shortest path to a shippable client.

This change is a delivery-governance migration, not a source-code rollback. Existing platform targets, tests, OpenSpec changes, and completed evidence remain valid at their recorded tier. The normal test environment continues to use the file identity fallback with `LUNEX_RUN_KEYCHAIN_TEST` and `LUNEX_RUN_LIVE_HOST_TEST` unset. Simulator instances are not required for this migration and must not be created or booted merely to prove a planning change.

## Goals / Non-Goals

**Goals:**

- Establish macOS as the sole product-completion target until formal freeze.
- Produce one serial, dependency-ordered macOS backlog and a proof-tiered gap matrix.
- Limit non-macOS work to shared macOS blockers and target build preservation.
- Define complete, acceptance, release-candidate, and freeze gates that cannot be satisfied by adjacent evidence.
- Preserve exact history and provide a reversible governance change.

**Non-Goals:**

- Remove existing iOS/iPadOS, tvOS, or visionOS source, tests, targets, or completed OpenSpec records.
- Mark any existing physical, signed, assistive-technology, or live-host task complete.
- Complete macOS runtime implementation or perform hardware/live acceptance as part of this planning-only change.
- Select post-freeze platform order before the macOS freeze review.
- Authorize source copying or GPL linking from Moonlight reference repositories.

## Decisions

### 1. Use a serial macOS execution lane

The authoritative lane is M0 through M9: audit; live session transport; native media/input integration; lifecycle/HDR/audio; native product workflows; deterministic regression; signed/notarized candidate; physical/live acceptance; performance/long-run acceptance; freeze manifest. A task may move earlier only when it is a prerequisite for the current gate.

Alternative considered: keep stages 13-20 and merely label macOS tasks P0. This leaves cross-platform stage rotation ambiguous and continues to invite work that cannot advance the macOS release candidate.

### 2. Freeze non-macOS product work without deleting it

iOS, iPadOS, tvOS, and visionOS become `deferred/frozen pending macOS freeze`. Shared changes must preserve their generic build compatibility, but platform-specific tests, UI, features, Simulator runs, signed artifacts, and physical acceptance are not scheduled. A non-macOS edit requires a written macOS blocker or compatibility rationale in the active task record.

Alternative considered: remove non-macOS targets temporarily. That would destroy useful implementation, increase later integration risk, and make shared regressions harder to detect.

### 3. Make the production media receive path the first implementation blocker

The session runtime audit distinguishes protocol/parser/processor coverage from a concrete production provider. Pairing, RTSP/control, and remote input have concrete runtime providers, but video and audio receive providers are not installed in the default runtime inventory. M1 therefore closes production video/audio network receive and then proves pairing through clean stop against an authorized Sunshine host before UI polish can claim product completion.

Alternative considered: finish the remaining diagnostics work first. Diagnostics remain required, but they do not make a session deliver sustained video and audible synchronized audio.

### 4. Treat proof tiers as non-substitutable

Every acceptance row records one of: deterministic implementation, generic build, Simulator, signed artifact, physical hardware, assistive technology, live Sunshine, or externally blocked. A higher or adjacent tier does not retroactively complete another tier. Evidence must name the exact Git SHA and candidate where applicable.

Alternative considered: one aggregate pass/fail column. That obscures what was actually exercised and previously allowed build or Simulator evidence to resemble physical completion.

### 5. Freeze an exact candidate, not a moving branch

M9 produces a manifest with Git SHA, dependency hashes, Xcode/macOS versions, artifact hash, signing/notarization/stapling/Gatekeeper receipts, acceptance matrix, performance baselines, known limitations, and rollback point. A freeze tag or release branch requires user confirmation of naming and release semantics. After freeze, unrelated changes cannot be described as part of the accepted candidate.

Alternative considered: call `main` frozen after tests pass. A moving branch cannot provide reproducible acceptance or bind physical results to exact bytes.

### 6. Keep existing OpenSpec changes truthful

Completed checkboxes remain unchanged. Active platform-specific changes remain open with their unmet physical/live tasks pending and are annotated by the new planning authority as deferred. `complete-native-product-workflows` is split operationally: macOS-applicable work may be pulled into M4, while cross-platform-only expansion is deferred. This governance change does not archive or falsify those changes.

### 7. Organize the macOS product around the streaming task

The macOS product uses one Library workbench for the repeated path: observe current host availability, choose a host, browse its application catalog, and launch. An active session temporarily owns the content surface. Pairing and host addition are setup flows; Settings use the native low-frequency settings surface; Diagnostics is opened only for support and recovery. Reachability and pairing remain separate state dimensions, and automatic background orchestration keeps them current without requiring a normal-use refresh button.

The in-session overlay is an action surface rather than a diagnostic banner. It identifies the current application and host, summarizes the configured stream profile, and exposes controls that take effect during the session: pointer mode, scaling, HDR/EDR permission, spatial audio, hide, and disconnect. On a wide macOS window it is width-bounded and anchored at the top center immediately below the title bar, rather than vertically centered over remote content. Normal streaming does not reserve primary canvas space for read-only implementation labels or entitlement prose; a requested spatial-audio fallback or failure may add one compact subordinate reason directly below its switch, and the same spatial diagnostic is not repeated in the connecting footer. Actual output detail remains available through accessibility semantics and the on-demand Settings or Diagnostics surfaces.

Alternative considered: retain `Library`, `Stream`, `Diagnostics`, and `Settings` as equal permanent sidebar destinations. That structure gives the lowest-frequency surfaces the same weight as launch, wastes the stream canvas when no session exists, and makes the navigation hierarchy describe implementation modules instead of user goals.

### 8. Coalesce pointer motion at the first serialized macOS input boundary

The macOS input coordinator uses a bounded realtime queue that coalesces only adjacent compatible pointer movement before awaiting the authenticated transport. Relative movement accumulates the complete delta; absolute movement keeps the newest mapped position. A coordinate-reference change, pointer-button snapshot change, keyboard event, button transition, scroll event, focus-release barrier, or terminal transition prevents coalescing across that boundary. The production bound is intentionally small enough that an input state transition cannot sit behind a long history of stale motion. The active AppKit capture surface also owns `NSWindow.acceptsMouseMovedEvents` through a shared per-window owner set, so SwiftUI surface replacement cannot let a stale view disable movement delivery for its successor and the original window value is restored after the final owner detaches.

AppKit pointer-motion `deltaY` is converted at the macOS capture boundary into Moonlight's screen-coordinate convention, where positive relative Y moves down. The conversion applies uniformly to moved and dragged mouse events but does not alter Direct absolute coordinates, horizontal motion, or scroll-wheel normalization. Shared adapters and wire serialization therefore retain platform-neutral Moonlight semantics.

The production ENet driver owns its host on one serial pump. Long receive waits are divided into at most one-millisecond service slices so queued outbound input can run between slices. Outbound packets enter a bounded mailbox, are queued to ENet together, and cause one flush per drained batch; connection teardown rejects and resumes every pending send/service continuation. Saturated packet, flush, rejection, service-slice, and maximum send-queue-delay counters provide a finite discriminator without retaining payloads, endpoints, identities, or arbitrary errors.

Alternative considered: rely only on `MoonlightRemoteInputProvider` coalescing. The macOS coordinator serially awaits every provider send, so the provider normally sees only one macOS call at a time and cannot coalesce the backlog that already formed upstream. Increasing pointer sensitivity would magnify movement while leaving stale-event and click latency unchanged.

### 9. Keep realtime media live by discarding obsolete buffered events

The production audio and video datagram receivers use fixed-capacity newest-event buffers. When a consumer falls behind, the receiver discards the oldest buffered event, retains the new event, increments a saturated discard counter, and continues the session. The downstream video assembler already supersedes an incomplete older frame when a newer frame index arrives and requests IDR recovery for loss, so replaying an obsolete packet history or terminating the entire session would increase latency without improving recovery. Network, parser, configuration, cancellation, and unexpected-termination failures retain their existing fail-closed behavior.

Alternative considered: terminate the media stream when its receive FIFO fills. At high negotiated frame rates and bitrates, a transient scheduling delay can fill that FIFO even when the host and network remain healthy; converting this recoverable realtime backlog into a terminal session error produces avoidable disconnects and diverges from Moonlight's latest-media-first behavior.

### 10. Diagnose latency by layer without logging realtime payloads

The on-demand Diagnostics window polls one fixed-size realtime snapshot at a low rate. The snapshot separates macOS capture queue age and sink-delivery duration from the remote-input queue and ENet send delay, then reports receiver discards, decoder drops/failures, published frames, actually presented frames, frames superseded before presentation, and monotonic publish-to-present delay. Counters saturate and clocks are monotonic; no endpoint, identity, payload, frame content, credential, or arbitrary error string enters the snapshot or event history.

Alternative considered: infer the cause from cursor appearance or append an event for every input and video frame. Visual inspection alone cannot distinguish host input from client presentation pacing, while high-frequency diagnostic events would add allocation and observation work to the path being measured.

### 11. Pace active macOS presentation from the source and display

The active macOS Metal surface carries the successfully negotiated video frame rate and the currently attached `NSScreen.maximumFramesPerSecond` through the existing lifecycle/render revision path. Its requested cadence is the lower valid value, with a 60 fps fallback until both are known. A single surface-owned `CAMetalDisplayLink` drives presentation from the layer's callback drawable, requests one-frame latency, and consumes the existing latest decoded frame without an asynchronous actor hop. Surface creation alone does not start the display link: it remains paused and unattached until the current render state has a decoded presentation contract, then attaches for actual frames. Clearing that contract during reset, replacement, or teardown pauses, invalidates, and detaches the display link before the surface returns to its immediate-clear state. Window screen changes, backing-property changes, and application screen-parameter notifications refresh the attached-display value. Throttled presentation remains 15 fps, while idle and paused presentation pause the display link and perform the required immediate clear. The prior MTKView scheduler remains only as a bounded fallback when no display-link runtime can attach to the Metal layer after decoded-frame readiness.

Alternative considered: always request the configured preference or a fixed 60 fps through `MTKView.preferredFramesPerSecond`. The setting can differ from the negotiated stream, while a 60 fps ceiling visibly undersamples high-refresh streams, a source-only request can exceed the current display capability, and the view timer does not provide the same explicit one-frame drawable deadline as `CAMetalDisplayLink`.

## Risks / Trade-offs

- [Shared code may drift on frozen platforms] -> Run generic non-macOS target builds only when shared code or project generation changes could break them; do not treat those builds as product progress.
- [macOS hardware/live acceptance can block the lane] -> Surface the blocker explicitly and prepare deterministic tooling and secret-safe evidence templates, but do not switch to unrelated platform features to manufacture progress.
- [Sunshine releases evolve independently of LuneX] -> Never gate users through a Sunshine package-version allowlist. Select protocol paths from server-advertised capabilities and validate actual negotiation/behavior; record a package version only when it is readily available and useful for reproducing a defect.
- [Existing stage documents may conflict] -> Make the macOS-first plan the precedence rule and synchronize all four planning authorities in one reviewed change.
- [A macOS-specific shortcut could damage portability] -> Keep shared protocol/media abstractions platform-neutral and require a written macOS blocker rationale for conditional platform changes.
- [Freeze criteria may expand indefinitely] -> Record measurable thresholds before the release-candidate run and require explicit change control for new gates.

## Migration Plan

1. Audit active OpenSpec tasks, production provider inventory, platform adapters, and current evidence tiers.
2. Publish the macOS gap matrix, M0-M9 serial backlog, non-macOS maintenance rules, and freeze definition.
3. Update `task_plan.md`, `findings.md`, `progress.md`, OpenSpec context, and the completion roadmap to reference the new authority.
4. Validate OpenSpec strictly, check planning cross-references, and commit the planning migration independently.
5. Begin M1 with production video/audio receive providers; do not resume the previous cross-platform next-task rotation.

Rollback is documentation-only: revert this governance change and restore the previous stage ordering. No application data, identity material, simulator state, or runtime configuration is mutated by the migration.

## Open Questions

- Exact performance, power, thermal, weak-network, and long-run thresholds must be fixed before M8 begins.
- The server-advertised protocol/capability matrix and available physical HDR/SDR displays, audio routes, input devices, and assistive-technology setup must be recorded before M7. Sunshine package versions are optional diagnostic metadata, not acceptance prerequisites.
- Freeze tag and release branch names require user confirmation after M8 passes.
