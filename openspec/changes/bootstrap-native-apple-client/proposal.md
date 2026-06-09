## Why

Moonlight on Apple platforms needs a modern native client that can exploit platform-specific window, display, input, HDR, audio, and background-behavior APIs instead of inheriting the limitations of cross-platform UI and rendering layers. Starting from an empty project lets LuneX define a clean SwiftUI architecture while using upstream Moonlight clients only as behavioral references.

## What Changes

- Create a SwiftUI-first Apple client architecture for macOS 26+, iOS 26+, iPadOS 26+, tvOS 26+, and visionOS 26+.
- Add platform lifecycle handling for macOS window occlusion/key/screen changes and mobile scene/window geometry changes.
- Add a native Metal/VideoToolbox rendering path with EDR/HDR display headroom awareness.
- Add Moonlight-compatible host discovery, pairing, app launch, and streaming session state requirements.
- Add native input handling for keyboard, pointer, touch, controller, remote, and platform-specific focus models.
- Add AVFoundation/AVFAudio audio requirements, including entitlement-gated head-tracked spatial audio.
- Add iOS/iPadOS/tvOS/visionOS background continuity requirements using supported Background Modes and Picture in Picture/media behavior.
- Add a native UI requirement set for host library, pairing, settings, stream overlay, diagnostics, and platform-appropriate navigation.
- **License-sensitive:** upstream GPL code may be studied for behavior but must not be copied. Any future direct reuse or linking must be approved as a GPL-compatible product decision.

## Capabilities

### New Capabilities

- `platform-lifecycle`: App/window/scene/display lifecycle tracking across Apple platforms.
- `native-rendering-hdr`: Native Metal/VideoToolbox rendering, resize behavior, and HDR/EDR tone/headroom handling.
- `streaming-session`: Moonlight-compatible host discovery, pairing, app selection, session startup, session control, and disconnect behavior.
- `input-control`: Local keyboard, pointer, touch, controller, remote, and virtual control translation to remote input.
- `spatial-audio`: Audio playback pipeline, channel layout handling, spatial audio, and head tracking.
- `background-continuity`: Supported session continuity behavior while app/window visibility changes or mobile platforms enter background/PiP states.
- `native-ui`: SwiftUI user interface, settings, diagnostics, stream controls, and platform navigation.

### Modified Capabilities

- None. This is the initial OpenSpec contract for an empty repository.

## Impact

- Creates the initial app architecture, OpenSpec requirements, project structure, shared Swift packages/modules, platform targets, renderer adapters, session state models, and validation workflow.
- Requires Apple SDK APIs from AppKit, UIKit, SwiftUI, Metal, QuartzCore, VideoToolbox, AVFoundation, AVFAudio, GameController, Network, and Bonjour/mDNS.
- Requires later decisions for signing, entitlements, App Store background behavior, and protocol-library licensing.
