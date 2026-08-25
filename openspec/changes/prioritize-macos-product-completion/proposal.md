## Why

Parallel product completion across five Apple platforms is spreading verification effort across hardware and runtime tiers while the macOS client still lacks a complete production media-receive path and live end-to-end acceptance. LuneX needs one authoritative delivery sequence that finishes, accepts, and freezes macOS before any other platform resumes feature development.

## What Changes

- Make macOS 26+ the only product-completion priority until a reproducible macOS freeze baseline is accepted.
- Put iOS, iPadOS, tvOS, and visionOS product work into maintenance freeze; only shared-core fixes required by macOS and generic target build preservation remain allowed.
- Replace stage-number rotation with a serial macOS backlog covering live Moonlight transport, native media/input integration, lifecycle/HDR/audio behavior, product workflows, release quality, physical/live acceptance, and freeze provenance.
- Define evidence tiers so deterministic tests, generic builds, Simulator runs, signed artifacts, physical hardware, assistive technology, and live Sunshine results cannot substitute for one another.
- Define explicit freeze and post-freeze gates; other platforms may be reprioritized only after the exact macOS candidate, evidence, limitations, and toolchain are recorded and accepted.
- Preserve all completed cross-platform work and existing OpenSpec history without deleting prior implementation or marking unmet physical/live tasks complete.
- Keep Moonlight iOS and Moonlight-qt as read-only behavioral references; this change does not authorize copying or linking GPL source.

## Capabilities

### New Capabilities

- `macos-first-delivery-governance`: Defines macOS-exclusive execution order, non-macOS maintenance freeze, evidence tiers, acceptance gates, and the reproducible macOS freeze baseline.

### Modified Capabilities

None. Existing capability requirements and completed history remain intact; this change governs execution order and acceptance dependencies.

## Impact

- Planning authority: `task_plan.md`, `findings.md`, `progress.md`, and `docs/runtime-completion-roadmap.md`.
- OpenSpec execution: active macOS-related changes are sequenced under this change; mobile, tvOS, and visionOS changes remain open but deferred where their physical/live tasks are unmet.
- Engineering workflow: macOS behavior and release gates receive implementation effort; other platform targets receive compatibility builds only when shared changes could affect them.
- Acceptance and release: live Sunshine, physical display/audio/input, accessibility, signing/notarization, performance, and freeze-manifest evidence become mandatory before macOS is declared complete.
