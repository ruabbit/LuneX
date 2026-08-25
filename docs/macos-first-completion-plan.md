# LuneX macOS-First Completion Plan

> Authority date: 2026-08-26. This document governs execution order until the accepted macOS candidate is frozen. Older stage numbers remain historical tracking and do not override this plan.

## Decision

macOS 26+ is the only product-completion target. iOS, iPadOS, tvOS, and visionOS are in maintenance freeze until macOS is functionally complete, formally accepted, and captured as a reproducible immutable baseline.

Before that freeze, non-macOS work is allowed only when:

1. a macOS/shared-core change could break an existing target and a generic build is needed to detect compatibility drift; or
2. a shared-core defect directly blocks the active macOS milestone and the task record names that blocker.

No new non-macOS product feature, platform-specific UI expansion, Simulator campaign, signed candidate, or physical acceptance is scheduled. Existing source, tests, targets, completed OpenSpec tasks, and evidence remain preserved.

## Audit Snapshot

Audit scope:

- Git `main` and `origin/main` at `74dda0593f58190650b9b8fcc045bf60393bb9dd` before this planning change.
- 120 source files, including 206 tracked Swift files across source and tests, 90 Swift test files, native C/Objective-C bridges, and Metal shaders.
- Ten existing OpenSpec changes: three complete and seven active before this change.
- Normal deterministic test baseline last accepted on 2026-08-22: `1268 total / 1267 passed / 1 explicit Keychain skip / 0 failed`.
- Normal tests use the JSON identity fallback. `LUNEX_RUN_KEYCHAIN_TEST` and `LUNEX_RUN_LIVE_HOST_TEST` remain unset outside explicit isolated gates.
- No Simulator, Keychain, live host, signing identity, or physical device was operated during this audit.

The repository is not a placeholder client. It already contains native pairing, RTSP/control, input, VideoToolbox/Metal/HDR, AVAudioEngine/spatial-audio, AppKit lifecycle, SwiftUI workflow, diagnostics, and broad deterministic coverage. The critical distinction is that much of this proof is offline and provider-driven rather than a released live-stream candidate.

## Evidence Tiers

| Tier | Meaning | Does not prove |
|---|---|---|
| Deterministic implementation | Production types/path plus unit, fixture, or application tests | Real process/device behavior or Sunshine interoperability |
| Generic build | Target compiles for a generic SDK destination | App launch, signing, device behavior, or feature completeness |
| Simulator | Existing bounded Simulator target actually runs | Signing, physical HDR/audio/input, power, thermal, or live-host behavior |
| Signed artifact | Exact candidate has intended signature and entitlements | Hardware behavior or live Sunshine workflow |
| Physical hardware | Scenario exercised on named hardware class | Live host behavior unless the receipt includes it |
| Assistive technology | VoiceOver/Voice Control or equivalent exercised on exact candidate | Other physical, performance, or live-host rows |
| Live Sunshine | Authorized host workflow exercised end to end | Release packaging or other hardware classes not included in the receipt |
| Externally blocked | Required host, hardware, account, or authorization unavailable | Completion; the row stays pending |

Evidence is non-substitutable. Every physical or live receipt must bind to the exact Git SHA and, after M6, the exact candidate hash.

## macOS Gap Matrix

| Area | Current evidence | Highest current tier | Blocking gap | Milestone |
|---|---|---|---|---|
| A. Identity, trust, pairing, host, catalog | Native identity, pinned HTTPS, pairing state machine, imported local data, deterministic workflow tests | Deterministic implementation | Authorized Sunshine version inventory, live pair/re-pair, catalog/launch continuity | M1 |
| B. RTSP and control | Concrete `MoonlightSessionControlProvider`, RTSP negotiation, control/keepalive/reconnect/teardown tests | Deterministic implementation | Exact-host live negotiation, keepalive, reconnect, remote termination, repeated stop | M1 |
| C. Video network receive | Concrete default `MoonlightVideoReceiveProvider`, bounded UDP receive/ping, packet mapping, parity skip, replacement/cancellation/teardown, decoder and presenter | Deterministic production path | Sustained live frames, packet-loss behavior, live FEC recovery gap and clean host stop | M1 |
| D. Audio network receive | Concrete default `MoonlightAudioReceiveProvider`, bounded UDP receive/ping, strict Opus RTP mapping, FEC skip, cancellation/teardown, jitter/PCM/audio graph | Deterministic production path | Audible synchronized live audio, packet-loss behavior, live FEC recovery gap and route transitions | M1 |
| E. VideoToolbox, Metal, HDR/EDR | Decode, zero-copy delivery, Metal renderer, PQ/EDR mapping, `maximumExtendedDynamicRangeColorComponentValue`, headroom/display transition tests | Deterministic implementation and generic builds | Sustained live frames, compositor/physical HDR and SDR behavior, dynamic headroom, cross-display measurements | M2-M3 |
| F. AVAudioEngine and spatial audio | Session-owned graph, route monitor, multichannel layouts, `isListenerHeadTrackingEnabled` set/readback and fallback tests | Deterministic implementation and generic builds | Audible live audio, signed entitlement, capable routes, head tracking, route interruption/recovery on hardware | M2-M3 |
| G. Keyboard, pointer, controller, cursor | Concrete remote input provider; AppKit capture view; direct/relative mapping; ordered release; balanced cursor ownership tests | Deterministic implementation | Host receipt for key/pointer/scroll/controller/feedback; physical focus loss and multi-display mapping | M2-M3 |
| H. Window and display lifecycle | Actual `NSWindow` occlusion/key/resize/backing/screen notifications plus `NSApplication.didChangeScreenParametersNotification`; shared drawable/input transform | Deterministic implementation | Physical occlusion/minimize, full-screen, sleep/wake, resize, cross-display, stale-window and performance proof | M3 |
| I. Reconnect, stop, termination, cleanup | Generation ownership, resource tracker, idempotent stop, stale completion and replacement tests | Deterministic implementation | Live weak-network recovery, remote termination, repeated teardown/relaunch, leak-free long run | M1, M7-M8 |
| J. Native SwiftUI workflows | Host/pairing/catalog/session/multiwindow/accessibility work through `complete-native-product-workflows` task 6.1 | Deterministic implementation and generic builds | macOS-only completion of tasks 6.2-6.5, application matrix, physical multiwindow and recovery | M4-M5 |
| K. Diagnostics and privacy | Closed typed product issues, bounded diagnostics primitives, redaction tests | Deterministic implementation | Remove remaining arbitrary observable strings; retention/dedup/export/share and adversarial redaction completion | M4-M5 |
| L. Accessibility and keyboard navigation | Typed semantics, adaptive layouts, touch targets, Reduce Motion, macOS keyboard focus, broad deterministic matrix | Deterministic implementation and generic builds | Exact-candidate VoiceOver, Voice Control, keyboard and localization/resize physical acceptance | M4, M7 |
| M. Signing, notarization, packaging | Generic Debug/Release builds only | Generic build | Intended entitlements, signed candidate, notarization, stapling, Gatekeeper and clean-machine launch | M6 |
| N. Latency, memory, power, thermal, weak network, long run | Analyzer, sanitizer and bounded resource gates | Deterministic quality gates | Thresholds and exact-candidate measurements under live sustained workload | M8 |
| O. Freeze provenance | Git history and task-level evidence exist | Source history | Immutable manifest, exact artifact, dependency/toolchain hashes, accepted limitations and repository ref | M9 |

## Critical Path

```mermaid
flowchart LR
    M0["M0 Audit and priority migration"] --> M1["M1 Production session and live transport"]
    M1 --> M2["M2 Native macOS media and input"]
    M2 --> M3["M3 Window, display, HDR and audio lifecycle"]
    M3 --> M4["M4 Native macOS product workflows"]
    M4 --> M5["M5 Deterministic macOS regression"]
    M5 --> M6["M6 Signed and notarized candidate"]
    M6 --> M7["M7 Physical and live acceptance"]
    M7 --> M8["M8 Performance and endurance"]
    M8 --> M9["M9 Freeze manifest and immutable baseline"]
    M9 --> P["Post-freeze platform reassessment"]
```

### M0: Authoritative audit and priority migration

Exit gate:

- OpenSpec governance change is apply-ready and strict-valid.
- This gap matrix, the root planning files, and the completion roadmap agree on precedence.
- Non-macOS work is marked deferred without rewriting old checkboxes.
- Git diff contains planning/OpenSpec changes only.

### M1: Production session and live transport

Work order:

1. Implement concrete production video and audio receive providers with bounded UDP receive, parsing, sequencing, cancellation, and teardown.
2. Install both providers in the default runtime inventory so `requiredStream` can become available without test injection.
3. Close remaining `implement-moonlight-session-runtime` live tasks: host inventory, pair/re-pair, sustained video, audible synchronized audio, actual input/feedback, live interoperability, reconnect, remote termination, stop, and cleanup.

Exit gate: one authorized Sunshine matrix proves pairing through clean stop with sustained decoded video, audible synchronized audio, and host-observed input on the production path.

### M2: Native macOS media and input integration

Exit gate: the live receive path feeds the single generation-owned VideoToolbox/Metal and AVAudioEngine runtime; physical keyboard, pointer, scroll, controller, cursor capture, focus release, resize, and multi-display mapping work against the host.

### M3: Window, display, HDR and audio lifecycle

Exit gate:

- occlusion/minimize stop drawable and presentation work while preserving recoverable control state;
- focus transitions balance system/remote cursor and release held remote input;
- screen/backing/resize/full-screen changes keep drawable fill and pointer transforms current;
- representative HDR/SDR displays prove EDR mapping and fallback;
- representative audio routes prove audible sync, spatial/fixed fallback, entitled head tracking, route recovery, and cleanup.

### M4: Native macOS product workflows

Only the macOS-applicable remainder of `complete-native-product-workflows` is admitted. Cross-platform-only harness or UI expansion stays deferred.

Exit gate: first use, restored/imported data, manual host, pairing, refresh, launch, stream controls, reconnect, remote termination, stop, removal, settings, diagnostics/export, multiwindow, keyboard, VoiceOver, Voice Control, Reduce Motion, and failure recovery form a coherent native SwiftUI macOS application.

### M5: Deterministic macOS regression

Exit gate: focused and full tests, Debug/Release, strict concurrency, generator/dependency drift, analyzer, sanitizers, malloc/resource, privacy, cancellation, stale-generation, and teardown gates pass with the normal file identity fallback. Non-macOS generic builds run only if shared changes affect them and remain compatibility evidence.

### M6: Signed and notarized release candidate

Exit gate: exact-SHA Release artifact has intended entitlements, valid signature, notarization, stapling, Gatekeeper acceptance, clean-machine launch evidence, and recorded artifact hash.

### M7: Physical and live acceptance

Exit gate: the exact M6 artifact passes the combined live Sunshine, window/display/HDR, audio/input, diagnostics, accessibility, failure, and teardown matrix. Missing hardware or authorization remains a blocker.

### M8: Performance and endurance

Before execution, record numeric thresholds for latency, frame pacing, memory, CPU/GPU, power, thermal state, weak-network recovery, and run duration. Exit requires exact-candidate measurements and successful cleanup/relaunch after adverse and long-run cases.

### M9: Freeze and immutable baseline

The manifest must include:

- exact Git SHA and confirmed freeze ref;
- dependency and project-generator hashes;
- Xcode, Swift, SDK, and macOS versions;
- app artifact hash, signing identity class, entitlements, notarization, stapling, and Gatekeeper receipts;
- proof-tiered acceptance matrix and performance baselines;
- known limitations, external constraints, and rollback point.

The user confirms tag/branch naming and release semantics before refs are created. Only after reproducibility is verified may another platform receive a product roadmap.

## Existing OpenSpec Sequencing

| Change | Current role under macOS-first authority |
|---|---|
| `implement-moonlight-session-runtime` | M1 authority; its seven open live/production tasks are first |
| `integrate-macos-native-input-lifecycle` | M2-M3; keep 6.5 pending until physical/live proof |
| `implement-native-hdr-edr-pipeline` | M3; keep 6.5 pending until physical HDR/SDR proof |
| `integrate-spatial-audio-runtime` | M3; macOS hardware subset is required, other-platform-only proof remains deferred |
| `complete-native-product-workflows` | M4-M5 for macOS-applicable tasks; cross-platform-only expansion deferred |
| `integrate-mobile-scene-pip-continuity` | Frozen at 35/36; preserve pending 6.6 |
| `integrate-tvos-visionos-runtime` | Frozen at 49/50; preserve pending 8.7 |

No active change above is archived merely because its work is deferred. No existing pending physical/live checkbox is changed by this planning migration.

## Rollback

This is a documentation and scheduling migration. Reverting its commit restores the prior cross-platform stage order without changing application data, Keychain identity, imported hosts, Simulator inventory, signing state, live host state, or physical devices.
