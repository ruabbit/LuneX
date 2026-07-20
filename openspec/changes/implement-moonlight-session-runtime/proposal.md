## Why

LuneX currently exposes native UI and policy models but deliberately disables pairing and streaming because no authenticated Moonlight runtime, media transport, decoder, or remote-input sender exists. A real session runtime is the blocking dependency for validating every promised macOS, HDR, audio, input, and mobile-continuity experience against an actual Sunshine host.

## What Changes

- Implement a clean-room native Swift pairing runtime that creates a persistent client certificate/key identity, performs the Moonlight PIN challenge exchange, verifies the server, and persists the resulting host pin.
- Implement Sunshine-compatible launch, RTSP negotiation, control, keepalive, reconnect, stop, and failure handling without reporting `Streaming` before media transport is operational.
- Implement native video and audio receive pipelines using Network.framework, VideoToolbox, Metal/CoreVideo, AVFoundation/AVFAudio, and supported Apple codecs.
- Implement authenticated remote keyboard, pointer, touch, controller, motion, rumble, and clipboard event delivery over the negotiated input channel.
- Replace the hard-coded unavailable runtime flags with injected production providers and session-owned lifecycle management.
- Add protocol fixtures, local deterministic tests, diagnostics, and opt-in end-to-end tests against explicitly configured Sunshine hosts.
- Do not copy or link GPL Moonlight client code. Any future reuse of `moonlight-common-c` requires a separate explicit license and distribution decision.

## Capabilities

### New Capabilities

- `authenticated-pairing-runtime`: Native client identity generation and the authenticated PIN/certificate pairing exchange.
- `moonlight-session-transport`: Launch, RTSP/control negotiation, keepalive, reconnect, cancellation, and truthful session state.
- `native-media-runtime`: Native packet receive, hardware video decode, Metal frame delivery, audio decode, synchronization, and teardown.
- `remote-input-runtime`: Authenticated delivery of keyboard, pointer, touch, controller, motion, rumble, and clipboard events.
- `runtime-interoperability-validation`: Deterministic fixtures and opt-in Sunshine interoperability tests with explicit proof boundaries.

### Modified Capabilities

- None. The prior bootstrap change has not been archived into baseline specs; this change supersedes its runtime skeleton behavior through new capabilities.

## Impact

- Affects client identity generation/storage, host pairing state, networking, RTSP/control parsing, stream state, rendering, audio, input, diagnostics, AppModel dependency injection, tests, and local Sunshine test infrastructure.
- Introduces protocol and codec implementation risk and requires bounded interoperability fixtures before live-host execution.
- Preserves SwiftUI as the application UI and Apple-native runtime frameworks as the production implementation path.
