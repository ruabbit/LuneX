# Runtime dependency decisions

This document records protocol-adjacent dependency choices before code enters a
production LuneX target. Moonlight client and Sunshine sources remain behavioral
references only and are not copied or linked.

## X.509 certificate encoding

**Decision:** use Security.framework for RSA private-key operations and
certificate parsing, with a small repository-owned DER writer for the fixed
client-certificate profile. Do not add a general ASN.1 dependency.

**Status:** approved for the production identity implementation.

### Required profile

The writer is limited to the structures needed for a self-signed pairing
identity:

- RSA-2048 public key in `SubjectPublicKeyInfo`;
- X.509 version 3 (`version = 2`);
- positive random serial of at most 20 DER bytes;
- issuer and subject containing one UTF-8 common name;
- current `notBefore` and approximately 20-year `notAfter` validity;
- `sha256WithRSAEncryption` for both TBS and outer signature algorithms;
- PKCS#1 v1.5 SHA-256 signature created by `SecKey`.

The implementation must not grow into a general ASN.1 parser. Lengths are
definite, inputs are bounded, OIDs are constants, and parsing of the completed
certificate remains the responsibility of `SecCertificateCreateWithData`.

### Evidence

`Tools/IdentitySpike/main.swift` proves the following with an ephemeral key:

- `SecKeyCreateRandomKey` creates the RSA-2048 private key without permanent
  storage;
- the fixed DER profile is accepted by `SecCertificateCreateWithData`;
- the certificate public key matches the generated key;
- that public key verifies both the self-signed TBS bytes and an independent
  challenge signature;
- compilation succeeds with Swift warnings treated as errors.

The spike performs no Keychain item operation, does not call the identity-store
abstraction, writes no key material, and contacts no host.

### License and maintenance

Security.framework and Foundation are Apple platform SDK frameworks already used
by the product. The DER writer is original repository code under the LuneX
project's license. This decision adds no third-party package, binary, transitive
dependency, license notice, architecture slice, or external update channel.

The production encoder must have deterministic structure tests, malformed-input
bounds where applicable, Security.framework parse/signature tests, persistence
reload tests, and an explicit identity reset test. Protocol interoperability is
still subject to the authorized Sunshine live-pairing gate; successful local
certificate parsing alone is not live compatibility proof.

## Opus decoding

**Decision:** use the platform `AudioConverter` Opus decoder from AudioToolbox.
Do not add libopus to a production target.

**Status:** approved for the production audio implementation.

### Negotiated input contract

The production wrapper will accept one post-RTP raw Opus packet plus the
negotiated 48 kHz configuration: channel count, stream count, coupled-stream
count, channel mapping, and samples per encoded frame. It will synthesize the
bounded `OpusHead` magic cookie required by `AudioConverter` and emit
interleaved PCM together with the actual decoded frame count.

The wrapper must not assume that one 5 ms packet immediately emits 240 PCM
frames. The system decoder emitted 120 frames for the first packet in every
spike profile because of decoder priming. Audio clocking and jitter management
must use actual frame counts, and packet-loss concealment behavior remains an
explicit task in the audio runtime.

### Evidence

`Tools/OpusSpike/main.swift` decoded fully synthetic raw packets matching the
post-RTP Sunshine boundary. Runtime checks on macOS passed for every current
Sunshine 5 ms profile:

| Profile | Channels | Streams | Coupled | Bitrate | Packet bytes |
|---|---:|---:|---:|---:|---:|
| stereo | 2 | 1 | 1 | 96 kbps | 60 |
| 5.1 normal | 6 | 4 | 2 | 256 kbps | 160 |
| 5.1 high quality | 6 | 6 | 0 | 1536 kbps | 960 |
| 7.1 normal | 8 | 5 | 3 | 450 kbps | 281 |
| 7.1 high quality | 8 | 8 | 0 | 2048 kbps | 1280 |

All profiles used Sunshine's identity channel mapping, produced non-silent PCM,
and remained within the 1400-byte audio-packet limit. The same Swift decoder
surface typechecks with warnings as errors against the iOS 26, tvOS 26, and
visionOS 26 simulator SDKs. That is compile-time availability evidence only;
platform runtime and route behavior remain later validation gates.

### License, architecture, and updates

AudioToolbox, CoreAudioTypes, CryptoKit, and Foundation are Apple platform SDK
frameworks. The choice adds no package, binary architecture slice, transitive
license, or third-party update feed. The decoder is available through the same
API surface on all LuneX targets.

`Tools/OpusSpike/generate_fixture.c` uses a local libopus 1.6.1 installation only
to create synthetic protocol fixtures with explicit Sunshine encoder settings.
The generator and its development library are not linked by any Xcode target and
are not part of the shipped app.

Each Xcode/OS update must rerun the checked-in stereo fixture, the synthetic
multichannel matrix where the generator is available, cross-SDK typechecks, and
later production decoder tests. A libopus fallback requires a new explicit
decision only if deterministic or authorized live tests expose a system-decoder
compatibility gap; it must not be added opportunistically.

## ENet control transport

**Decision:** vendor `cgutman/enet` commit
`aca87840b57f045a1f7f9299e4b1b9b8e2a5e2f1` and expose only a repository-owned
opaque C bridge for the Sunshine control channel.

**Status:** approved for the production control runtime.

### Why Network.framework is insufficient

Current Sunshine GameStream protocol `7.1.431` negotiates the control stream as
ENet reliable UDP. Network.framework can provide UDP datagrams, but it does not
implement the ENet handshake, channels, acknowledgement, retransmission,
fragmentation, peer timeout, or ping state machine. Sending control payloads as
raw UDP would compile but would not interoperate, and independently recreating
ENet would add a large reliability protocol with no product advantage.

### Version, license, and notice

- Repository: `https://github.com/cgutman/enet.git`.
- Revision: `aca87840b57f045a1f7f9299e4b1b9b8e2a5e2f1`.
- License: MIT, copyright Lee Salzman; the complete upstream `LICENSE` is
  retained beside the vendored source and must ship with required notices.
- Scope: eight portable C implementation files and their public headers; no
  Moonlight GPL source or compiled artifact is included.

### Wrapped API and platform evidence

Swift does not import or manipulate ENet structs. `LuneXENetBridge` exposes an
opaque connection plus bounded connect, reliable/unreliable send, event service,
and disconnect calls. Control message encryption, validation, state, diagnostics,
and cancellation remain repository-owned Swift.

The fixed revision passes `clang -std=c11 -Wall -Wextra -Werror` syntax checks
against macOS 26.4, iOS Simulator 26.4, tvOS Simulator 26.4, and visionOS
Simulator 26.4 after suppressing only the upstream unused-parameter warning.
The fork contains Apple IPv6, QoS/DSCP, and socket workarounds used by its
maintainers for Moonlight-compatible transports.

### Update and removal strategy

Updates require a new pinned revision, license diff, upstream change review,
cross-SDK strict compile, deterministic loopback/control codec tests, and the
authorized Sunshine interoperability gate. The dependency can be removed if
Sunshine negotiates a documented control transport implemented by an Apple
framework or if a separately reviewed native replacement proves full ENet wire
compatibility and reliability behavior.
