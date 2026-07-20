# Moonlight runtime protocol inventory

## Designated host evidence

The designated host is recorded as `local-host-a`; its address, certificate, unique ID, and credentials are deliberately excluded from this repository.

| Field | Read-only evidence | Interpretation |
|---|---:|---|
| Service | `_nvstream._tcp` on port 47989 | Moonlight-compatible GameStream service |
| State | `SUNSHINE_SERVER_FREE` | Sunshine is reachable and has no active game |
| Pair status for inventory identity | `0` | The read-only inventory identity is not paired |
| GameStream protocol version | `7.1.431.-1` | Protocol compatibility value, not Sunshine's release version |
| Emulated GFE version | `3.23.0.74` | Compatibility value exposed by Sunshine |
| HTTPS port | `47984` | Pinned HTTPS Moonlight endpoints |
| Codec mode mask | `0x001F0301` | H.264, HEVC, HEVC Main10, AV1 Main8/Main10, H.264 4:4:4, HEVC 4:4:4 8/10-bit |
| HEVC luma limit | `1869449984` | Host-advertised HEVC luma capacity |

The Sunshine semantic release version is not exposed by unauthenticated `serverinfo`. The configuration API that returns `PROJECT_VERSION` is protected by Web UI Basic authentication. Task 1.1 remains open until the version is confirmed through an explicitly authorized host-side or authenticated read-only query.

## Initial compatibility target

- Current Sunshine protocol generation exposing GameStream `7.1.431.-1`.
- Pinned HTTPS on the advertised port.
- H.264 and HEVC 8-bit as mandatory first video paths.
- HEVC Main10 metadata preservation before HDR output is enabled.
- AV1 capability negotiation with explicit device support gating.
- Opus audio framing to be confirmed by sanitized live fixture capture.
- Keyboard, pointer, controller, and feedback channels required before the session can pass end-to-end acceptance.

## Read-only inventory boundary

Permitted operations are Bonjour browse/resolve, unauthenticated `serverinfo`, TLS certificate observation, and authenticated GET requests only when the user explicitly provides read-only authorization. Pairing, PIN submission, app launch, config mutation, client removal, and server restart are not inventory operations.
