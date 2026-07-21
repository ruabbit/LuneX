## Why

LuneX already preserves HDR10 negotiation metadata and decodes 10-bit bi-planar frames, but the production presenter always renders into an sRGB surface and enables EDR from display capability rather than active stream dynamic range. Stage 15 adds a truthful native HDR/EDR output contract so HDR content is mapped through current Apple display headroom without changing SDR appearance or overstating missing physical-display evidence.

## What Changes

- Carry validated stream color metadata with each current-generation decoded frame into one render policy that distinguishes stream HDR state from display EDR capability.
- Configure 10-bit-capable Metal drawable formats and explicit linear/extended color spaces on supported Apple platforms, with platform-specific fallback where a layer API is unavailable.
- Implement bounded PQ-to-linear luminance mapping, reference-white normalization, current-headroom scaling, and deterministic HDR-to-SDR tone mapping without clipping SDR content into an EDR path.
- Apply MDCV, CLL, maximum full-frame luminance, pixel format, display headroom, window screen, and generation changes atomically to presentation; stale frames or policies cannot reconfigure replacement sessions.
- Surface privacy-bounded HDR activation and fallback diagnostics, and verify SDR-on-HDR, HDR-on-SDR, headroom changes, resize, display migration, teardown, and cross-platform builds.
- Keep real HDR display brightness, tone-map quality, power, and cross-screen visual acceptance as explicit hardware gates.

## Capabilities

### New Capabilities

- `hdr-color-pipeline`: Validated 8/10-bit color metadata, PQ/BT.2020 conversion, mastering/content-light bounds, reference white, and SDR/HDR tone-map behavior.
- `apple-edr-output`: Apple-platform Metal drawable format, output color space, EDR enablement, current display headroom, and supported fallback behavior.
- `hdr-runtime-reconfiguration`: Session-generation and display-revision ownership for HDR frame presentation, dynamic headroom changes, diagnostics, teardown, and replacement safety.

### Modified Capabilities

None. Earlier change-local media and lifecycle specs remain historical contracts; this change adds the native HDR output requirements that consume their validated metadata and display state.

## Impact

- Affects `LuneXRendering`, decoded-frame presentation contracts in `LuneXNetworking`, `LuneXCore` render/session state, lifecycle display updates, diagnostics, tests, and generator-owned Xcode source lists.
- Requires explicit Apple SDK availability gates because macOS/iOS, tvOS, and visionOS do not expose identical `CAMetalLayer` EDR controls.
- Keeps the existing production stream provider inventory fail closed; it does not add placeholder video/audio receivers or claim live Sunshine HDR playback.
- Uses Apple Core Image/Core Graphics/Core Video/Metal/QuartzCore/VideoToolbox APIs and repository-owned Swift only. No new third-party or GPL-linked dependency is introduced.
