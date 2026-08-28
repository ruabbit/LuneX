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

Alternative considered: retain `Library`, `Stream`, `Diagnostics`, and `Settings` as equal permanent sidebar destinations. That structure gives the lowest-frequency surfaces the same weight as launch, wastes the stream canvas when no session exists, and makes the navigation hierarchy describe implementation modules instead of user goals.

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
