## 1. Governance Migration And Audit

- [x] 1.1 Audit active OpenSpec tasks, default production runtime providers, macOS platform adapters, product workflows, release gates, and current proof tiers without changing runtime, Keychain, Simulator, host, or device state.
- [x] 1.2 Publish an authoritative macOS gap matrix and M0-M9 serial backlog that distinguishes implemented deterministic behavior from generic-build, Simulator, signed, physical, assistive-technology, live Sunshine, and externally blocked evidence.
- [x] 1.3 Put iOS, iPadOS, tvOS, and visionOS product work into maintenance freeze while preserving existing targets, implementation, completed history, and minimum shared-code compatibility gates.
- [x] 1.4 Synchronize OpenSpec context, `task_plan.md`, `findings.md`, `progress.md`, and `docs/runtime-completion-roadmap.md` with the macOS-first precedence and rollback rules.
- [x] 1.5 Run strict OpenSpec validation, documentation cross-reference checks, diff hygiene, and a clean Git/remote audit for the planning migration.

## 2. M1 Production Session And Live Transport

- [x] 2.1 Implement concrete production `VideoReceiveProvider` and `AudioReceiveProvider` paths, install them in the default macOS runtime inventory, and verify bounded cancellation and teardown deterministically.
- [ ] 2.2 Record the authorized Sunshine version and privacy-bounded live test matrix without mutating unrelated host state.
- [ ] 2.3 Prove live pairing, catalog, launch, negotiated channels, sustained decoded video, audible synchronized audio, actual remote input/feedback, reconnect, remote termination, repeated stop, and clean teardown on macOS.

## 3. M2 Native macOS Media And Input Integration

- [ ] 3.1 Close any production gaps between live video/audio receive, VideoToolbox/Metal, AVAudioEngine, and the single generation-owned session environment.
- [ ] 3.2 Prove real keyboard, direct and relative pointer, buttons, dual-axis scroll, controller, cursor ownership, focus release, resize, full-screen, and multi-display coordinate mapping against the authorized host.

## 4. M3 Window Display HDR And Audio Lifecycle

- [ ] 4.1 Prove occlusion/minimize pause, visible resume, key/resign-key cursor and input ownership, screen-parameter changes, backing-scale changes, full-screen, sleep/wake, display reconnect, and stale-window isolation on physical macOS hardware.
- [ ] 4.2 Prove SDR-on-HDR, HDR-on-SDR fallback, HDR-on-EDR mapping, dynamic headroom, cross-display transitions, first opaque clear, and clean SDR restoration on representative physical displays.
- [ ] 4.3 Prove stereo and multichannel routes, entitled listener head tracking, fixed/nonspatial fallback, AirPods/built-in/wired/HDMI transitions where available, audible synchronization, interruption recovery, and clean audio teardown.

## 5. M4 Native macOS Product Workflows

- [ ] 5.1 Complete the macOS portions of host, pairing, catalog, launch, recovery, overlay, multiwindow, settings, and destructive confirmation workflows without advancing frozen-platform-only behavior.
- [ ] 5.2 Remove arbitrary workflow error text and endpoint/identity echoes; implement bounded retention, deterministic deduplication, privacy-safe export/share, and adversarial redaction tests.
- [ ] 5.3 Complete macOS keyboard navigation, Reduce Motion, localization expansion, VoiceOver, Voice Control, and physical multiwindow application acceptance.

## 6. M5 Deterministic macOS Regression

- [ ] 6.1 Run macOS-focused unit, fixture, application, Debug/Release, strict concurrency, generator/dependency, analyzer, sanitizer, malloc/resource, privacy, and teardown gates with real Keychain and live-host opt-ins disabled except in their explicit isolated gates.
- [ ] 6.2 Run generic non-macOS compatibility builds only where shared code or generated project changes require them, and record that they do not advance frozen platform product status.

## 7. M6 Signed And Notarized Release Candidate

- [ ] 7.1 Produce an exact-SHA macOS Release candidate with the intended entitlements and signing identity.
- [ ] 7.2 Verify notarization, stapling, Gatekeeper assessment, clean-machine launch, update/rollback assumptions, and artifact hashes without describing an unsigned build as a release candidate.

## 8. M7 Physical And Live Acceptance

- [ ] 8.1 Execute the exact-candidate physical/live Sunshine matrix for session, media, input, window/display, HDR/EDR, audio, diagnostics, accessibility, failure recovery, and teardown.
- [ ] 8.2 Review every result by evidence tier and keep any unavailable hardware or authorization row explicitly pending rather than substituting adjacent evidence.

## 9. M8 Performance And Endurance Acceptance

- [ ] 9.1 Fix measurable thresholds for latency, frame pacing, memory, CPU/GPU, power, thermal state, weak-network recovery, and long-run duration before running the release-candidate gate.
- [ ] 9.2 Prove the exact candidate meets those thresholds and preserves cleanup/relaunch behavior after weak-network and long-run scenarios.

## 10. M9 Freeze And Post-Freeze Review

- [ ] 10.1 Create the macOS freeze manifest with exact Git SHA, dependency/toolchain versions and hashes, artifact hash, signing/notarization receipts, acceptance matrix, performance baselines, known limitations, and rollback point.
- [ ] 10.2 Obtain user confirmation for freeze tag/release branch naming and release semantics before mutating repository refs.
- [ ] 10.3 Freeze the accepted macOS baseline, verify its reproducibility, and only then reassess iOS/iPadOS, tvOS, and visionOS priorities from their preserved state.
