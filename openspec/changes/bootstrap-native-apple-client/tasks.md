## 1. Research and contracts

- [x] 1.1 Finish targeted upstream analysis of `moonlight-ios` Network/Stream/Input/Crypto/ViewController boundaries and record findings.
- [x] 1.2 Finish targeted Moonlight-qt macOS renderer/input/window behavior analysis and record reusable behavior requirements.
- [x] 1.3 Confirm Apple SDK API availability against Xcode 26.4 for AppKit/UIKit/SwiftUI/Metal/VideoToolbox/AVFoundation/GameController.
- [x] 1.4 Validate OpenSpec artifacts and keep `task_plan.md`, `findings.md`, and `progress.md` synchronized.

## 2. Project scaffolding

- [x] 2.1 Create the native SwiftUI multi-platform app project with macOS, iOS, iPadOS, tvOS, and visionOS target structure.
- [x] 2.2 Create shared modules for session core, platform lifecycle, rendering, input, audio, networking, persistence, diagnostics, and UI features.
- [x] 2.3 Add build settings for macOS 26+ and iOS/iPadOS/tvOS/visionOS 26+ deployment targets where supported by the installed SDK.
- [x] 2.4 Add placeholder app icons/assets/configuration without importing upstream Moonlight assets.

## 3. Platform lifecycle implementation

- [x] 3.1 Implement macOS `NSWindow` observer adapter for occlusion, key/resign, screen changes, resize, backing scale, and app activation.
- [x] 3.2 Implement iOS/iPadOS scene and geometry adapter for scene phase, view size, traits, safe areas, and window resizing.
- [x] 3.3 Implement tvOS and visionOS lifecycle adapter stubs with focus/activation metadata.
- [x] 3.4 Add unit tests for lifecycle-to-render-policy state transitions.

## 4. Native rendering and HDR

- [x] 4.1 Implement SwiftUI-wrapped Metal stream surface for macOS and iOS-family platforms.
- [x] 4.2 Implement render sizing and transform model for fit/fill/crop with input coordinate mapping.
- [x] 4.3 Implement EDR/HDR capability model for `NSScreen`, `UIScreen`, and `CAMetalLayer`.
- [x] 4.4 Implement renderer pause/resume/reconfigure path driven by lifecycle policy.

## 5. Session and networking core

- [x] 5.1 Implement host model, secure identity storage abstraction, and persisted settings.
- [x] 5.2 Implement discovery and manual host-add flow.
- [x] 5.3 Implement pairing state machine with structured errors.
- [x] 5.4 Implement app-list retrieval and artwork cache abstraction.
- [x] 5.5 Implement stream negotiation/session state skeleton before media transport details.

## 6. Input and controls

- [x] 6.1 Implement macOS keyboard and pointer adapters with cursor/capture policy.
- [x] 6.2 Implement iOS/iPadOS touch, pointer, and virtual controller overlay event model.
- [x] 6.3 Implement GameController binding for controllers and tvOS remote/focus input.
- [x] 6.4 Add diagnostics for unsupported or reserved input events.

## 7. Audio and continuity

- [ ] 7.1 Implement AVAudioEngine session pipeline skeleton and route diagnostics.
- [ ] 7.2 Implement entitlement-gated spatial audio/head-tracking availability model.
- [ ] 7.3 Implement iOS/iPadOS background/PiP continuity policy skeleton and Info.plist capability wiring.
- [ ] 7.4 Implement macOS visibility-based background performance policy.

## 8. Native UI

- [ ] 8.1 Implement host library and pairing UI for macOS and iOS/iPadOS.
- [ ] 8.2 Implement app grid/list, stream settings, and launch flow.
- [ ] 8.3 Implement stream overlay for status, controls, input mode, HDR/audio state, and disconnect.
- [ ] 8.4 Implement diagnostics and settings screens.

## 9. Verification

- [x] 9.1 Run OpenSpec strict validation.
- [x] 9.2 Build macOS target.
- [x] 9.3 Build and run one iOS 26.4 iPhone simulator instance.
- [x] 9.4 Build and run one iPadOS 26.4 iPad simulator instance.
- [x] 9.5 Record test results and remaining gaps in planning files.
