## Context

The current app has native UI, host persistence, pinned HTTPS requests, policy models, and a truthful fail-closed capability gate. It does not have a production pairing provider, RTSP/control transport, media receiver, hardware decoder, audio playback path, or input sender. Imported Moonlight-qt host pins are useful fixtures but do not supply a LuneX client private key, so production streaming still requires a valid native identity and pairing flow.

The implementation must remain SwiftUI at the product layer and use Apple-native frameworks for platform integration. Moonlight client repositories are GPL behavioral references only; their source will not be copied or linked in this change.

## Goals / Non-Goals

**Goals:**

- Establish a real Sunshine-compatible session from native identity generation through clean disconnect.
- Make pairing, session, video, audio, and input independently testable and owned by one session lifetime.
- Provide truthful state and diagnostics that later macOS, HDR, spatial-audio, and mobile-continuity changes can consume.
- Validate both deterministic protocol fixtures and an explicitly authorized live Sunshine host.

**Non-Goals:**

- Final cursor capture, HDR tone mapping, spatial-audio presentation, PiP, or Stage Manager UX; those are dependent follow-up changes.
- Copying or linking GPL Moonlight client code.
- Claiming every historical GeForce Experience protocol variant in the first runtime. The initial live compatibility target is the configured current Sunshine test host.

## Decisions

### Use clean-room layered native transports

The runtime will be split into `PairingRuntime`, `SessionControlRuntime`, `VideoReceivePipeline`, `AudioReceivePipeline`, and `RemoteInputRuntime`, coordinated by a `MoonlightSession` actor. Parsers and serializers will be value types; sockets, timers, decoder sessions, and mutable state will be actor-owned.

This keeps platform UI independent from protocol details and permits fixture tests without network access. Linking `moonlight-common-c` would accelerate compatibility but creates a GPL distribution decision and is therefore excluded.

### Prove protocol contracts before live I/O

Each binary/XML/RTSP boundary will have sanitized fixtures, length limits, malformed-input tests, and byte-exact serialization assertions. Live-host work starts only after the relevant fixture layer passes. Captured fixtures must be reviewed to remove certificates, private keys, IP addresses, host names, and bearer material.

### Generate identity with Security framework and a bounded certificate layer

Private-key operations remain in Security framework and persisted by the existing identity-store abstraction. A spike will determine whether the required self-signed X.509 encoding can be implemented with a small repository-owned DER encoder or needs a vetted permissively licensed ASN.1 package. No dependency is accepted before license, maintenance, platform, and deterministic-encoding review.

### Use native transports with a narrow ENet control dependency

TCP and ordinary UDP channels use Network.framework wrappers exposing async sequences and explicit cancellation. Current Sunshine control traffic requires the ENet reliable-UDP protocol, which Network.framework does not implement. The control channel therefore uses a narrowly wrapped, fixed MIT-licensed ENet source revision; the Swift runtime sees only opaque connect, send, service, and disconnect operations. A session cancellation tree owns every connection, receive loop, keepalive timer, decoder callback bridge, and input queue. Disconnect waits for teardown and reports any ownership leak in tests.

### Reconnect through resume with fresh authenticated session material

The control channel never reconnects by resetting an AES-GCM sequence under the same `rikey`. An uncertain send or a peer-side sequence reset could otherwise reuse a nonce. Every bounded recovery attempt generates a fresh 16-byte `rikey` and UInt32 `rikeyid`, calls the pinned HTTPS `/resume` endpoint rather than `/launch`, and rebuilds RTSP plus control transport from the returned session URL. The default retry delays are 100, 250, and 500 milliseconds; transport failures may retry, while certificate pin, authenticated-frame, parser, and invalid-state failures fail immediately.

Channel health is a current set, not a monotonic readiness latch. Empty health is unavailable, a required-channel subset is degraded, and only a set satisfying every required control/video/audio/input channel permits streaming. Any control failure publishes an empty health set before recovery or terminal failure, and exhausted recovery performs local teardown plus a best-effort remote cancel without issuing a second launch.

### Use VideoToolbox, CoreVideo, and Metal for video

Packet assembly produces codec access units and configuration metadata. VideoToolbox returns `CVPixelBuffer` objects; `CVMetalTextureCache` exposes textures to the renderer without a CPU color conversion. Codec, resolution, bit-depth, colorspace, and HDR changes rebuild the affected format/decompression state. HDR output mapping remains a later change, but metadata must be preserved now.

### Select audio decode only after an interoperability spike

The first task compares system AudioToolbox/AVFoundation Opus support with the packet form delivered by Sunshine. If it cannot decode the negotiated stream reliably, use a narrowly wrapped, permissively licensed libopus distribution with license and architecture validation. Decoded PCM is scheduled through a session-owned `AVAudioEngine`.

### Keep UI state derived and fail closed

`AppModel` receives production runtime providers through injection. `Streaming` requires negotiated control plus operational media readiness; a launch response alone remains `connecting`. Any missing provider, authentication failure, or exhausted reconnect budget leaves the session disconnected/failed and releases resources.

## Risks / Trade-offs

- [Risk] Clean-room protocol work is larger than wrapping the existing C core. → Mitigation: implement current Sunshine compatibility first, use fixture-first boundaries, and keep GPL reuse as a separate explicit decision.
- [Risk] Certificate construction may need an external ASN.1 dependency. → Mitigation: perform a bounded spike and require a permissive license and minimal API surface before adoption.
- [Risk] Raw Opus delivery may not fit system decoder APIs. → Mitigation: prove AudioToolbox first, then use a narrowly isolated libopus fallback.
- [Risk] UDP loss and decoder resynchronization can create false streaming states. → Mitigation: readiness and health are channel-derived, with IDR requests, bounded queues, and sustained-frame live gates.
- [Risk] Live tests could alter the user's host session. → Mitigation: opt-in configuration, designated test app, isolated identity where possible, clean-stop cleanup, and no automatic execution.
- [Risk] Session actors can retain callback resources. → Mitigation: explicit ownership graph, cancellation tests, weak callback bridges, and teardown counters.
- [Risk] Reimplementing ENet over raw UDP would create an untested reliability stack, while an unpinned dependency could drift. → Mitigation: vendor the reviewed MIT revision, retain its notice, expose a minimal C bridge, and run cross-SDK compile plus deterministic control-channel tests.

## Migration Plan

1. Keep `RuntimeCapabilityAvailability.current` fail-closed while protocol fixtures and identity generation are implemented.
2. Enable pairing provider only after identity and authenticated exchange live tests pass.
3. Enable session control for an imported or newly paired test host while the UI remains in connecting state.
4. Enable streaming capability only after sustained video, audio, input, and teardown gates pass.
5. Preserve existing host and settings JSON; migrate identity records only through versioned decoding and never rewrite imported host pins without authenticated pairing.
6. Roll back by returning production capability selection to unavailable; persisted trusted pins remain intact.

## Open Questions

- Whether Security framework plus a small DER layer is sufficient for the exact client certificate accepted by the target Sunshine version.
- Whether system Opus decoding accepts Sunshine's negotiated packet framing on every target platform.
- Which AV1 hardware/software fallback policy is acceptable on devices without supported VideoToolbox AV1 decode.
- Whether the deterministic 100/250/500 ms reconnect delays should be tuned after authorized live LAN measurements; the three-attempt bound remains mandatory.
