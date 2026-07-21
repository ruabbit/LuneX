## Context

Stage 13 preserves validated `VideoColorMetadata` through negotiation, decoder generation, decoded frames, and the Metal-frame mapper. VideoToolbox already requests bi-planar 8-bit video-range output for SDR and bi-planar 10-bit video-range output for HDR, while `CVMetalVideoFrameMapper` exposes the matching `.r8Unorm/.rg8Unorm` or `.r16Unorm/.rg16Unorm` planes. Stage 14 publishes the actual stream drawable, display identity, and current/potential/reference headroom whenever the screen, backing scale, or surface geometry changes.

The production presenter does not consume that contract. It creates a `CIImage` from each pixel buffer, renders through a fixed sRGB `CIContext`, and leaves the `MTKView` output format and colorspace at their defaults. `DisplayHeadroomReader.configure` toggles extended-range intent only on selected platforms and is not bound atomically to stream metadata, decoded pixel format, frame generation, display revision, or tone mapping. As a result, a decoded Main10/PQ frame can be accepted without proving that it is rendered as HDR, and HDR content on an SDR/currently constrained display has no defined luminance mapping.

The implementation must remain native Swift/Metal/VideoToolbox, preserve the clean-room and no-new-dependency boundary, compile on macOS 26+, iOS/iPadOS 26+, tvOS 26+, and visionOS 26+, and keep physical brightness/HDR signaling claims separate from deterministic tests.

## Goals / Non-Goals

**Goals:**

- Bind decoded pixel format, color metadata, frame generation, stream preference, display capability, current headroom, target gamut, and surface format into one validated immutable render configuration.
- Render SDR Rec.709 and HDR10 BT.2020/PQ bi-planar frames through a repository-owned Metal pipeline with explicit video-range normalization, matrix conversion, transfer decoding, gamut conversion, and luminance mapping.
- Preserve SDR reference white on EDR displays, retain HDR highlights up to safe current headroom, and provide deterministic SDR fallback when HDR output is unavailable or disabled.
- Reconfigure the actual stream surface atomically across metadata, decoder-generation, headroom, display, and window transitions without presenting stale frames under a new color contract.
- Publish bounded diagnostics and comprehensive deterministic tests, followed by explicit physical HDR/SDR display acceptance.

**Non-Goals:**

- Claiming Dolby Vision, HLG, arbitrary ICC authoring workflows, every historical Moonlight HDR variant, or HDR screenshots/recording.
- Replacing VideoToolbox, implementing a software video decoder, or adding a third-party color-management/tone-mapping dependency.
- Treating simulator output, shader unit tests, pixel-buffer metadata, or `wantsExtendedDynamicRangeContent` alone as proof that a display entered HDR mode or reached a measured luminance.
- Completing mobile scene continuity, tvOS/visionOS product adaptation, performance/power qualification, or release signing; later stages own those workflows.

## Decisions

### Resolve one generation- and display-revision-owned render configuration

`HDRRenderConfigurationResolver` will accept the validated stream/frame metadata, actual decoded `CVPixelBuffer` format, active decoder generation, user HDR preference, platform output capability, display identity/revision, and `DisplayHeadroom`. It will produce either a closed rejection or an immutable configuration containing input layout, transfer, matrix, source/target gamut, source luminance bounds, target reference white/headroom, mapping mode, drawable format, layer colorspace, and EDR intent.

The presenter will accept a frame only when its generation and metadata-derived signature match the current configuration. A screen/headroom or metadata change clears presentation, rebuilds surface/pipeline state if required, and resumes only with a matching current-generation frame. Independently reading frame metadata in the shader and headroom in SwiftUI was rejected because it can combine unrelated revisions during window movement or decoder replacement.

### Fail closed on decoded layout and metadata mismatches

SDR Rec.709 video-range input requires the 8-bit bi-planar layout. HDR10 requires HEVC/AV1-capable 10-bit negotiation, BT.2020 primaries, PQ transfer, an accepted BT.2020 matrix, and the 10-bit bi-planar layout. HDR metadata paired with an 8-bit buffer, a 10-bit buffer paired with SDR metadata, unsupported full-range/plane counts, non-finite luminance values, or stale generations will not enter the HDR shader path.

The renderer may use an explicitly diagnosed SDR fallback only when the input contract is valid and the selected fallback supports it; it will not silently relabel malformed HDR as SDR. This preserves the fail-closed behavior established by the decoder and avoids bright, desaturated, or incorrectly ranged output.

### Replace fixed-sRGB Core Image presentation with an explicit Metal color pipeline

The stream presenter will consume the existing zero-copy luma/chroma Metal planes. A small repository-owned `.metal` shader will:

1. normalize 8-bit or 10-bit video-range YCbCr values;
2. apply the selected Rec.709 or BT.2020 non-constant-luminance matrix;
3. decode the SDR transfer or ST 2084 PQ EOTF into scene/display-linear values;
4. convert BT.2020 RGB into the selected linear output gamut;
5. apply the resolved luminance mapping; and
6. write premultiplied opaque linear output into the drawable.

HDR/EDR output uses a floating-point drawable and an extended-linear Apple colorspace; SDR output uses a standard sRGB drawable/colorspace. Pipeline state is cached by a bounded key containing input layout and output format. Continuing to rely on Core Image's implicit attachment interpretation was rejected because the required range, reference-white, headroom, and fallback behavior would remain untestable and revision ownership would be ambiguous.

### Map PQ luminance against reference white and safe current headroom

PQ decoding produces absolute luminance in nits. The resolver derives a bounded source peak from validated mastering maximum and MaxCLL, falling back to a documented conservative HDR10 peak when neither is present; invalid zero/negative/inverted metadata is already rejected upstream. Target reference white defaults to the Apple EDR convention represented by component value `1.0`, while display headroom supplies the maximum safe relative component value.

Values at or below reference white remain monotonic and stable. Highlights above reference white use a continuous monotonic shoulder from source peak into `currentHeadroom`; SDR fallback uses the same mapping with target headroom `1.0`. The mapping clamps only after transfer and gamut conversion, never before PQ decoding. Potential headroom is diagnostic/capability evidence, while current headroom is the presentation limit; the renderer will not emit to potential headroom that is not currently available.

A deterministic resolver and CPU reference implementation will share constants with the shader tests. An unbounded `nits / 80` mapping was rejected because it clips on constrained displays; a purely global linear scale was rejected because it unnecessarily dims SDR reference content.

### Treat surface capability and stream HDR state as independent

`streamIsHDR`, `userAllowsHDR`, `displaySupportsEDR`, `currentHeadroom`, and `platformSupportsHDRSurface` remain separate inputs. SDR content always uses the SDR mapping even on an EDR display. HDR content uses EDR only when every eligibility input is true; otherwise it uses a typed SDR tone-map fallback or a closed unsupported path.

The platform adapter owns `MTKView`/`CAMetalLayer` pixel format, colorspace, and extended-range intent on APIs supported by that OS. macOS and iOS/iPadOS receive the first runtime connection. tvOS and visionOS retain compile-safe adapters and explicit capability results rather than inheriting an AppKit/UIKit assumption; later platform stages can enable physical-device paths after their supported layer/display APIs are verified.

### Keep diagnostics semantic and privacy bounded

Diagnostics will expose stable codes for active SDR, active EDR, SDR fallback, incompatible pixel format, unsupported platform output, invalid metadata, stale revision, and pipeline failure. They may include coarse bit-depth/gamut/mapping enums and bounded numeric headroom/peak buckets, but never host identity, endpoint, application name, frame contents, display serial identifiers, or raw metadata blobs. Repeated equivalent state is deduplicated, recovery clears only the current HDR action, and teardown preserves bounded history while releasing pipeline/surface ownership.

## Risks / Trade-offs

- [Risk] A custom color shader can produce visible color or luminance errors. -> Mitigation: use published transfer/matrix constants, CPU reference vectors, shader readback fixtures, monotonic/bound tests, and physical color-pattern measurements before hardware completion.
- [Risk] Reconfiguring drawable format/colorspace while frames are queued can present a stale frame under a new contract. -> Mitigation: bind configuration to generation and display revision, clear presentation on transition, and reject mismatched frames on both sides of asynchronous work.
- [Risk] `maximumExtendedDynamicRangeColorComponentValue` changes dynamically with window/display state. -> Mitigation: treat current headroom as a revisioned presentation input, never as a one-time capability flag, and rebuild only when the semantic configuration changes.
- [Risk] Floating-point drawables and shader work increase bandwidth and GPU cost. -> Mitigation: use the SDR 8-bit path when HDR is inactive, retain zero-copy plane mapping, cache bounded pipeline states, and defer measured performance/power acceptance to stage 20.
- [Risk] HDR layer APIs and signaling differ across Apple platforms and hardware. -> Mitigation: isolate platform adapters, fail closed when support is unverified, and retain separate device acceptance tasks instead of compile-time inference.
- [Risk] Mastering and content-light metadata can be absent or misleading. -> Mitigation: validate bounds, use a documented conservative fallback peak, expose the fallback diagnostically, and never exceed safe current display headroom.

## Migration Plan

1. Add platform-neutral color, luminance, capability, and render-configuration value models plus deterministic reference tests while the existing presenter remains active.
2. Add explicit decoded-layout validation and bind the existing Metal plane mapper to color/generation signatures.
3. Add Metal shader resources and an injectable renderer, initially exercising offscreen deterministic readback.
4. Connect the actual stream surface, layer adapter, AppModel lifecycle/headroom state, presentation source, and diagnostics behind fail-closed eligibility.
5. Run full tests, Debug/Release five-platform builds, analyzer/sanitizer/resource gates, and independent simulator inventory validation.
6. Complete physical HDR/SDR, headroom, and cross-display acceptance. Rollback before that gate is selecting the existing diagnosed SDR presentation path, not silently treating HDR as correctly displayed.

## Open Questions

- Which authorized macOS HDR and SDR displays, calibrated test patterns, and luminance/color measurement method will be used for final acceptance?
- Which tvOS and visionOS hardware/API combinations will be enabled in stage 18 after verifying their supported HDR surface and display-mode behavior?
- Whether the user should be offered multiple creative tone-map looks is deferred; the initial implementation uses one deterministic accuracy-oriented policy plus explicit SDR fallback.
