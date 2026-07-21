## 1. Coordinate and AppKit contract foundation

- [x] 1.1 Inventory macOS event, modifier, shortcut, cursor, coordinate, and multi-window ownership contracts without changing runtime behavior
- [x] 1.2 Implement immutable revisioned stream coordinate snapshots and a shared fit/fill video-rectangle resolver
- [x] 1.3 Make renderer presentation and `InputMapper` consume the same resolved coordinate contract
- [x] 1.4 Add deterministic fit, fill, letterbox rejection, crop, backing-scale, invalid-geometry, resize, and stale-revision tests

## 2. Session lifecycle directives

- [x] 2.1 Define closed render, video-processing, presentation, and input lifecycle directives from active/visible/focused/drawable state
- [x] 2.2 Add generation-scoped lifecycle application to the session media environment without exposing providers to SwiftUI
- [x] 2.3 Pause decoded-video submission while draining transport, clear presentation, and request a fresh IDR on visible resume
- [x] 2.4 Add occlusion, focus, zero-drawable, resume, stop, replacement, and stale-directive lifecycle tests

## 3. Ordered macOS session input coordination

- [x] 3.1 Add an application input sink that derives the active session generation internally and fails closed when input is unavailable
- [x] 3.2 Implement a bounded generation-owned FIFO for synchronous platform samples and ordered remote-provider delivery
- [x] 3.3 Implement focus-loss admission closure and one shared held-input `releaseAll` barrier before eligible reactivation
- [x] 3.4 Converge send failure, input-channel failure, stop, remote termination, and replacement without stale delivery or cursor ownership
- [x] 3.5 Add ordering, backpressure, focus-release, failure, teardown, and generation-race tests for platform input coordination

## 4. Native AppKit capture and cursor ownership

- [x] 4.1 Implement an injectable main-actor cursor owner with balanced hide/show and relative association restore
- [x] 4.2 Implement a flipped first-responder stream capture view for key, modifier, repeat, and reserved-shortcut samples
- [ ] 4.3 Capture relative/absolute pointer movement, buttons, and scrolling with explicit view-to-backing conversion
- [ ] 4.4 Attach input capture and lifecycle observation to the actual macOS stream surface and detach them idempotently on SwiftUI replacement
- [ ] 4.5 Add AppKit-focused cursor transition, responder, event translation, attachment, and dismantle tests

## 5. Application and media integration

- [ ] 5.1 Derive actual stream-view drawable geometry and display state across screen, backing, and live-resize notifications
- [ ] 5.2 Connect lifecycle directives to `AppModel`, renderer, presentation source, media environment, and active input coordinator
- [ ] 5.3 Derive direct/relative capture eligibility from active session, focus, visibility, and persisted input settings
- [ ] 5.4 Surface privacy-bounded input/lifecycle diagnostics and clear stale actions on recovery or stop
- [ ] 5.5 Add an application integration gate proving fake-provider delivery, focus release, occlusion pause/resume, resize mapping, and clean teardown

## 6. Verification and tracking

- [ ] 6.1 Run normal tests with live-host and real-Keychain paths disabled and verify the only allowed skip
- [ ] 6.2 Build macOS Debug/Release and fixed iPhone, iPad, tvOS, and visionOS targets with warnings as errors and isolated DerivedData
- [ ] 6.3 Run OpenSpec strict, generator, clean-room/dependency, static analyzer, ASan, TSan, malloc ownership, and resource-release gates
- [ ] 6.4 Verify fixed simulator identities remain unique and `Shutdown` without creating or explicitly booting devices
- [ ] 6.5 Prove real macOS key, relative/direct pointer, scroll, focus release, occlusion resume, resize, and multi-display mapping against an authorized Sunshine host and hardware
- [ ] 6.6 Update planning and roadmap evidence, document remaining hardware limits, commit each completed task, and push
