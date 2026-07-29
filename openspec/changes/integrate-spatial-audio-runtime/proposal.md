## Why

LuneX decodes and schedules PCM through a session-owned audio runtime, but production playback bypasses the existing `AVAudioEnvironmentNode`; the isolated head-tracking controller and capability policy therefore do not spatialize stream audio. Stage 16 connects negotiated stereo and multichannel audio to one truthful native spatial graph, with platform, route, entitlement, recovery, diagnostics, and physical-device proof kept distinct.

## What Changes

- Preserve negotiated channel-layout semantics from Sunshine Opus configuration through decoded PCM and the actual `AVAudioEngine` connection format.
- Insert a session-owned `AVAudioEnvironmentNode` into the production graph, use an ambience-bed source for multichannel game audio, and retain explicit mono/stereo fallback behavior.
- Resolve spatial playback and head tracking from user preference, channel layout, active route, embedded entitlement, platform SDK, applicable rendering algorithms, and the actual configured graph.
- On macOS, iOS/iPadOS, and tvOS, enable `isListenerHeadTrackingEnabled` only when eligible; on visionOS 26+, use the platform spatial-experience API instead of the unavailable listener property.
- Rebuild spatial state atomically on route/capability/interruption/reconnect changes and prevent stale callbacks from mutating replacement session generations.
- Publish privacy-bounded audio state in diagnostics, stream status, and Settings, while retaining AirPods, speaker, multichannel hardware, entitlement, and audible-position acceptance as explicit physical-device gates.

## Capabilities

### New Capabilities

- `spatial-audio-graph`: Negotiated channel layouts, decoded PCM formats, environment-node graph topology, ambience-bed rendering, fallback, scheduling, and resource ownership.
- `spatial-audio-platform-routing`: Apple-platform route inspection, multichannel-content declaration, capability notifications, entitlement gating, listener head tracking, visionOS spatial experience, and route fallback.
- `spatial-audio-runtime-integration`: Session-generation ownership, interruption/recovery/replacement behavior, diagnostics, native product state, deterministic verification, and physical hardware acceptance.

### Modified Capabilities

None. The earlier change-local spatial-audio skeleton remains historical; this change adds the runtime requirements that replace its disconnected controller and policy-only proof.

## Impact

- Affects `LuneXAudio`, negotiated audio contracts in `LuneXCore`/`LuneXNetworking`, `NativeSessionMediaEnvironment`, `AppModel`, settings persistence, diagnostics, SwiftUI status/settings, app entitlements, tests, and generator-owned Xcode source/build settings.
- Uses AVFAudio, AudioToolbox, CoreAudio channel layouts, Security entitlement inspection, and platform route notifications. It adds no third-party or GPL-linked dependency.
- Keeps the production stream inventory fail closed while concrete video/audio network receivers remain absent; deterministic injected media tests do not claim live Sunshine playback.
- Requires provisioning approval and compatible physical output hardware before head-tracking or audible spatial behavior can be marked complete.
