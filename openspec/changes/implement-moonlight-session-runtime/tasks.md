## 1. Protocol and dependency decisions

- [ ] 1.1 Inventory the exact Sunshine version and protocol features used by the designated local test host without changing host state
- [x] 1.2 Document clean-room protocol boundaries and confirm no GPL source or linked artifact enters the production target
- [x] 1.3 Create sanitized pairing, RTSP, control, media, and input fixture directories with redaction checks
- [x] 1.4 Spike Security-framework client key operations and Sunshine-compatible self-signed certificate encoding
- [x] 1.5 Decide repository-owned DER encoding versus a permissively licensed ASN.1 dependency and record the license decision
- [x] 1.6 Spike system Opus decoding against representative Sunshine packet framing
- [x] 1.7 Decide AudioToolbox versus a narrowly wrapped permissive libopus fallback and record the license decision

## 2. Runtime architecture and network foundation

- [x] 2.1 Define production protocols for pairing, session control, video receive, audio receive, and remote input providers
- [x] 2.2 Implement cancellable Network.framework TCP and UDP channel wrappers with bounded reads and timeouts
- [x] 2.3 Implement session-owned task and resource tracking with deterministic async teardown
- [x] 2.4 Add structured runtime diagnostics with secret redaction and per-stage timing
- [x] 2.5 Add malformed-frame, timeout, cancellation, and resource-release tests for the network foundation

## 3. Client identity and authenticated pairing

- [x] 3.1 Implement native client keypair and certificate generation according to the approved identity decision
- [x] 3.2 Validate generated identity signing, certificate parsing, persistence, reload, and explicit reset
- [x] 3.3 Implement version-aware pairing digest, salt, AES, signature, and challenge primitives from deterministic vectors
- [x] 3.4 Implement the staged pairing request/response transport with pinned failure handling
- [x] 3.5 Persist the server leaf pin only after every pairing verification succeeds
- [x] 3.6 Implement pairing cancellation and rollback without replacing a previously trusted pin
- [ ] 3.7 Add opt-in live pairing and re-pair tests against an isolated Sunshine test identity

## 4. Launch, RTSP, and session control

- [x] 4.1 Implement byte-safe RTSP request/response models, parser limits, and serializer fixtures
- [x] 4.2 Implement Sunshine session description and negotiated stream-parameter parsing
- [x] 4.3 Implement launch-to-RTSP transition without reporting streaming from `/launch` alone
- [x] 4.4 Implement control-channel setup, keepalive, IDR request, termination, and host error messages
- [x] 4.5 Implement bounded reconnect and channel-health aggregation without duplicate host sessions
- [x] 4.6 Implement remote cancel and local cancellation convergence with idempotent teardown
- [x] 4.7 Add deterministic state-machine tests covering success, partial readiness, loss, reconnect, and failure

## 5. Native video runtime

- [x] 5.1 Implement bounded video packet reordering, loss detection, and codec access-unit assembly
- [x] 5.2 Implement H.264 and HEVC parameter-set parsing and VideoToolbox format construction
- [x] 5.3 Implement AV1 capability negotiation and an explicit unsupported-device fallback policy
- [x] 5.4 Implement VideoToolbox decompression-session ownership and callback-to-actor bridging
- [x] 5.5 Implement zero-copy CVPixelBuffer-to-Metal texture delivery with a bounded frame queue
- [x] 5.6 Preserve negotiated colorspace, bit depth, mastering, and content-light metadata for the later HDR change
- [x] 5.7 Implement format-change, decoder-reset, IDR-request, dropped-frame, and teardown tests
- [ ] 5.8 Prove sustained decoded video and clean stop on the authorized Sunshine test host

## 6. Native audio runtime

- [x] 6.1 Implement bounded audio packet ordering and jitter-buffer policy
- [x] 6.2 Implement the approved Opus decode path and PCM format conversion
- [x] 6.3 Connect decoded PCM to a session-owned AVAudioEngine graph
- [x] 6.4 Implement audio/video clock selection, drift measurement, and bounded resynchronization
- [x] 6.5 Implement route-change, interruption, underrun, packet-loss, and teardown handling
- [x] 6.6 Add deterministic audio decode, jitter, synchronization, and resource-release tests
- [ ] 6.7 Prove audible synchronized audio across start, route change, and stop on authorized hardware

## 7. Remote input runtime

- [x] 7.1 Implement negotiated input key setup and byte-exact authenticated event serialization
- [x] 7.2 Implement ordered keyboard, pointer-button, scroll, touch, and clipboard delivery
- [x] 7.3 Implement coalesced relative/absolute pointer movement without dropping state transitions
- [x] 7.4 Implement controller, motion, battery, LED, rumble, and trigger-rumble message handling
- [x] 7.5 Release held remote keys and buttons on focus loss, disconnect, or input-channel failure
- [x] 7.6 Add serialization, ordering, backpressure, focus-loss, and remote-feedback tests
- [ ] 7.7 Prove keyboard, pointer, controller, and remote feedback against the authorized Sunshine test host

## 8. Application integration

- [x] 8.1 Replace hard-coded unavailable runtime flags with injected production provider availability
- [x] 8.2 Connect pairing UI to the authenticated pairing runtime with cancellable stage progress
- [x] 8.3 Connect launch/stop UI to the session actor and derive UI phase from channel readiness
- [x] 8.4 Connect decoded video, audio, and input lifetimes to one session-owned SwiftUI environment
- [ ] 8.5 Surface actionable pairing, transport, decoder, audio, and input diagnostics without secrets
- [ ] 8.6 Preserve fail-closed behavior when any required production provider is absent

## 9. Verification and tracking

- [ ] 9.1 Run normal tests with live-host and real-Keychain integration paths disabled
- [ ] 9.2 Run opt-in live interoperability gates once per approved host state and capture redacted evidence
- [ ] 9.3 Verify authenticated pairing, sustained video, synchronized audio, delivered input, reconnect, and clean stop end to end
- [ ] 9.4 Build macOS Debug/Release and fixed iPhone, iPad, tvOS, and visionOS targets with isolated DerivedData
- [ ] 9.5 Verify no duplicate simulator instances are created or booted
- [ ] 9.6 Run OpenSpec strict validation, sanitizer/static checks, and resource-leak diagnostics
- [ ] 9.7 Update planning files, document remaining platform-experience changes, commit, and push
