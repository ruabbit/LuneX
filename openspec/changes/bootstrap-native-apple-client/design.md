## Context

The repository starts empty. The reference Moonlight iOS client is an Objective-C/UIKit/storyboard app with iOS/tvOS targets and embedded C/C++ libraries for SDL2, FFmpeg, Opus, and Moonlight common protocol code. Moonlight-qt provides desktop behavior references, including HDR streaming, pointer capture/direct mouse control, keyboard shortcut forwarding, VideoToolbox/Metal rendering, and EDR metadata handling on macOS.

LuneX will not copy either codebase. It will define a native SwiftUI application with shared core models and protocol abstractions, then isolate platform-specific behavior behind adapters.

## Goals / Non-Goals

**Goals:**

- Deliver a functionally complete macOS and iOS/iPadOS client first.
- Keep tvOS and visionOS as real targets with platform entry points, even if their feature parity follows after macOS/iOS.
- Use SwiftUI for app structure and native UI.
- Use Swift Concurrency and Observation for session state, host state, settings, diagnostics, and UI updates.
- Use AppKit and UIKit adapters for APIs SwiftUI does not expose directly.
- Use a native Metal/VideoToolbox rendering surface that can react to visibility, resize, display, and HDR/EDR changes.
- Make performance-sensitive lifecycle decisions observable and testable.

**Non-Goals:**

- Directly porting Objective-C/UIKit/storyboard Moonlight iOS code.
- Shipping a Qt, SDL, or cross-platform UI shell.
- Guaranteeing App Store approval before entitlement and background-mode review.
- Implementing closed-source protocol behavior from memory without validation against documented/open behavior and interoperability tests.

## Decisions

- **Architecture:** Split code into shared core, platform adapters, renderer, audio, input, networking/session, and SwiftUI feature modules. Core state must not import AppKit or UIKit.
- **Lifecycle:** macOS uses an `NSWindow` observer adapter for occlusion, key window, screen, resize, and backing-scale changes. iOS/iPadOS/tvOS/visionOS use scene phase, view geometry, trait, and platform controller adapters.
- **Rendering:** Use `CAMetalLayer`/Metal surfaces wrapped in SwiftUI with `NSViewRepresentable` and `UIViewRepresentable`. The renderer consumes decoded frames, updates drawable size from actual backing pixels, and exposes pause/throttle states from lifecycle policy.
- **HDR/EDR:** macOS reads `NSScreen.maximumPotentialExtendedDynamicRangeColorComponentValue`, `maximumExtendedDynamicRangeColorComponentValue`, and `maximumReferenceExtendedDynamicRangeColorComponentValue`; iOS-family devices read `UIScreen.currentEDRHeadroom` and relevant trait/headroom APIs. Metal layers set `wantsExtendedDynamicRangeContent` for HDR streams and publish current headroom to tone mapping.
- **Input:** Use native keyboard/pointer APIs on macOS and iPadOS, touch/virtual controls on iOS, GameController across all platforms, and tvOS remote/focus handling on tvOS. Local cursor visibility must follow key-window/focus and remote-mouse mode.
- **Audio:** Start with low-latency PCM/Opus decode output through AVAudioEngine. Spatial audio uses `AVAudioEnvironmentNode`; head tracking is enabled only when entitlement and compatible route are available.
- **Background:** Mobile background continuity uses only supported APIs: audio background mode, PiP/sample-buffer playback where applicable, short finite background tasks, and explicit suspension/resume policies.
- **Licensing:** Treat upstream GPL protocol libraries as separate decision points. A pure Swift implementation remains preferred until license direction is explicit.

## Risks / Trade-offs

- Moonlight protocol compatibility is broad; a clean Swift implementation may take longer than linking `moonlight-common-c`.
- App Store background/PiP use for game streaming may require careful UX and review justification.
- HDR correctness depends on actual hardware; simulators cannot validate final EDR behavior.
- macOS 26+ and iOS 26+ APIs may differ from older online examples; implementation must build against the installed Xcode 26.4 SDK.
- visionOS and tvOS input/window models differ enough that feature parity should be staged after shared core and macOS/iOS are stable.
