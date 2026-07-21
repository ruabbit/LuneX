# Native HDR and EDR implementation contract

This document is the implementation boundary for OpenSpec change
`implement-native-hdr-edr-pipeline`. It records the current production graph,
the Apple SDK 26.4 API surface, platform differences, and the evidence that is
still required before LuneX may claim working HDR output.

## Evidence boundary

- Source behavior was inventoried from the LuneX production source graph at
  commit `65c28eb`.
- API availability was checked against the Xcode 26.4 SDK headers and with
  Swift warnings-as-errors typecheck probes for macOS 26, iOS 26, tvOS 26, and
  visionOS 26.
- Local `references/` checkouts remain read-only behavioral references. No
  reference source, GPL implementation, binary, shader, or linked artifact is
  part of this contract or the production target.
- An API compiling, a layer property being set, a shader readback passing, or a
  simulator target building does not prove HDR signaling, output luminance,
  color accuracy, display behavior, power, or thermal performance.

## Current production graph

| Boundary | Current behavior | Proven | Missing for HDR output |
|---|---|---|---|
| Negotiation/control | `VideoColorMetadata` distinguishes 8-bit Rec.709 SDR and 10-bit BT.2020/PQ HDR10 video range; it validates MDCV, CLL, and maximum full-frame luminance bounds | Typed protocol and deterministic fixture tests | Live Sunshine HDR negotiation remains a stage 13 hardware/live gate |
| CoreMedia metadata | `VideoColorMetadata.coreMediaExtensions()` can encode primaries, transfer, matrix, range, bit depth, MDCV, and CLL | Unit tests validate the dictionary/data encoding | Production `VideoFormatDescriptionFactory` does not currently apply this dictionary to the created H.264/HEVC format description |
| VideoToolbox output | `VideoOutputBitDepth` requests NV12 video range for 8-bit and P010 video range for 10-bit, with IOSurface and Metal compatibility | Factory/decoder tests validate requested attributes and generation ownership | Decoder callback does not revalidate the actual returned pixel format against `VideoColorMetadata` before publishing a frame |
| Decoded frame | `DecodedVideoFrame` retains decoder generation and immutable `VideoColorMetadata` | Decoder and pipeline generation tests | No derived immutable render color signature or display revision is attached |
| Metal plane mapping | `CVMetalVideoFrameMapper` maps NV12 to `.r8Unorm/.rg8Unorm` and P010 to `.r16Unorm/.rg16Unorm`; it checks plane count, dimensions, format, and Metal device | Focused mapper/queue tests | `CVMetalVideoFrameMapper` and `BoundedMetalFrameQueue` have no production consumer |
| Presentation source | `StreamVideoPresentationSource` rejects wrong decoder generations and clears frames across pause, stop, failure, and replacement | Session/lifecycle integration tests | It stores raw `DecodedVideoFrame` only and has no render/display revision fence |
| Actual presenter | `StreamMetalPresenter` creates `CIImage(cvPixelBuffer:)`, scales it to the shared video rectangle, and renders it through a fixed sRGB `CIContext` into the default drawable | SDR presentation geometry and lifecycle behavior | It bypasses mapped luma/chroma textures, explicit range/matrix/transfer/gamut math, PQ luminance mapping, HDR metadata, and a float EDR drawable |
| Display lifecycle | macOS rereads the actual `NSScreen`, headroom, display name, backing pixels, and drawable on window/screen/backing/resize notifications | AppKit notification and stale-attachment tests | Headroom has no monotonic display revision separate from general lifecycle revision |
| Surface intent | `DisplayHeadroomReader.configure` sets `wantsExtendedDynamicRangeContent` on macOS/iOS when requested | The property call compiles on those platforms | Call sites currently pass `renderState.headroom.supportsEDR`, which is display capability, not `streamIsHDR`; no colorspace, pixel format, or `CAEDRMetadata` is applied atomically |
| AppModel fallback | Before real platform lifecycle exists, settings synthesize headroom values when the HDR preference is enabled | Existing model tests | Synthetic settings headroom is not display evidence and must not enable production EDR output |

The production truth at the start of stage 15 is therefore: LuneX can preserve
HDR metadata and request/map a 10-bit decoded layout, but it does not yet render
that layout through an explicit HDR/EDR color pipeline.

## Apple SDK 26.4 API matrix

| Platform | Headroom source verified by typecheck | `CAMetalLayer.wantsExtendedDynamicRangeContent` / `edrMetadata` | Color spaces verified by typecheck | Initial stage 15 policy |
|---|---|---|---|---|
| macOS 26 | `NSScreen.maximumExtendedDynamicRangeColorComponentValue`, `.maximumPotentialExtendedDynamicRangeColorComponentValue`, and `.maximumReferenceExtendedDynamicRangeColorComponentValue` | Available | extended-linear BT.2020, Display-P3, sRGB, and ITU-R 2100 PQ | First complete runtime surface path |
| iOS/iPadOS 26 | `UIScreen.currentEDRHeadroom` and `.potentialEDRHeadroom` | Available from iOS 16 | Same CoreGraphics spaces available | Compile and deterministic adapter path now; scene/window ownership and physical validation continue in stage 17 |
| tvOS 26 | `UIScreen.currentEDRHeadroom` and `.potentialEDRHeadroom` compile | Explicitly unavailable in the tvOS SDK; `CAEDRMetadata` is also unavailable | extended-linear BT.2020 and ITU-R 2100 PQ compile | Explicit unsupported/custom-Metal fallback in stage 15; actual tvOS HDR output path is stage 18 work |
| visionOS 26 | `UIScreen` is explicitly unavailable | Layer EDR intent and `CAEDRMetadata` compile | extended-linear spaces compile | No inferred headroom source; retain an explicit capability/fallback result until stage 18 verifies the supported spatial display path |

The tvOS and visionOS results are not symmetric. tvOS exposes screen headroom
but not the EDR controls on `CAMetalLayer`; visionOS exposes the layer controls
but not `UIScreen`. A shared `#if !os(macOS)` implementation cannot correctly
represent these capabilities.

## Headroom and metadata semantics

The SDK contracts establish separate meanings:

- macOS current maximum is the component value currently usable by an
  extended-range rendering context. It may change and triggers
  `NSApplication.didChangeScreenParametersNotification`.
- macOS potential maximum is the capability when EDR is enabled, regardless of
  current enablement. It is not a safe per-frame output bound.
- macOS reference maximum is the current reference-rendering limit. It is zero
  on displays that do not support reference rendering.
- iOS/iPadOS current headroom is the ratio of the brightest white currently
  producible to SDR white. Potential headroom is the maximum capability and can
  change with display configuration/reference mode.
- `CAMetalLayer.wantsExtendedDynamicRangeContent` changes compositor clamping
  from `1.0` toward current screen headroom. It does not convert YCbCr, decode
  PQ, choose a gamut, configure a float drawable, or prove HDR output by itself.
- `CAMetalLayer.edrMetadata` must be set before `nextDrawable`. Non-nil metadata
  permits system tone mapping for current display characteristics; nil metadata
  can leave values above current EDR headroom clamped.
- `CAEDRMetadata.hdr10` accepts the existing big-endian 24-byte MDCV and 4-byte
  CLL payloads. Its SDK contract is display-referred: buffer value `1.0` maps to
  diffuse white at 100 nits when `opticalOutputScale` is 100 nits, and a 4,000
  nit linear value is `40.0`. A normalized pixel format instead implies a
  10,000 nit scale.

Potential headroom may decide whether EDR is possible. Only current headroom may
bound emitted extended-linear values. Reference headroom is a distinct
diagnostic/mapping input and must not be substituted for either.

## Required immutable ownership

Stage 15 will establish these non-interchangeable values:

1. `VideoColorMetadata`: source protocol/decoder color facts.
2. Render color signature: validated source bit depth, range, primaries,
   transfer, matrix, and luminance metadata identity.
3. Decoder generation: owns the pixel buffer and source signature.
4. Display revision: owns actual display identity, surface capability, current,
   potential, and reference headroom.
5. Render configuration revision: resolved from decoder generation, source
   signature, user preference, platform capability, display revision, and
   drawable readiness.
6. Surface contract: output pixel format, colorspace, EDR intent, EDR metadata,
   and mapping mode applied together before drawable acquisition.

A frame is presentable only when its decoder generation and render color
signature match the current render configuration, and the current surface
contract was applied for the same display/configuration revision.

## Initial supported input contracts

| Contract | Required metadata | Required decoded layout | Render result |
|---|---|---|---|
| SDR Rec.709 video range | 8-bit, non-HDR, Rec.709 primaries/transfer/matrix, video range, no HDR light metadata | two-plane NV12; `.r8Unorm/.rg8Unorm` Metal textures | explicit Rec.709-to-linear/sRGB path; ordinary white remains component `1.0` on EDR displays |
| HDR10 BT.2020/PQ video range | 10-bit, HDR, BT.2020 primaries/matrix, ST 2084 PQ, video range, optional validated MDCV/CLL/full-frame maximum | two-plane P010; `.r16Unorm/.rg16Unorm` Metal textures | explicit PQ-to-absolute-luminance, gamut conversion, and EDR or diagnosed SDR-fallback mapping |

Full-range input, HLG, Dolby Vision, unsupported matrices/primaries/transfers,
8-bit HDR, and a mismatched actual pixel buffer are closed paths rather than
guessed transforms.

## Rendering requirements derived from the inventory

- Replace production fixed-sRGB Core Image presentation with a renderer that
  consumes the validated zero-copy luma/chroma planes.
- Normalize video-range samples before matrix conversion. P010 storage and its
  effective 10-bit code values must be covered by reference/readback tests.
- Decode PQ before applying luminance limits or gamut conversion. Do not clamp
  encoded PQ samples to display headroom.
- Keep SDR reference content stable when EDR headroom is available.
- Map HDR highlights monotonically into safe current headroom, with an explicit
  SDR fallback at headroom `1.0`.
- Apply drawable format, colorspace, EDR intent, and `CAEDRMetadata` as one
  platform adapter transaction before requesting the next drawable.
- Clear presentation across incompatible metadata, generation, display,
  headroom, surface, or user-setting revisions.
- Deduplicate semantic diagnostics and exclude raw frame values, metadata blobs,
  host/app identity, endpoint, and display identifiers.

## Verification matrix

### Deterministic evidence

- Invalid source/pixel/surface combinations reject closed.
- CPU reference vectors cover black, video black/white, near-black, primaries,
  SDR reference white, PQ reference luminance, content peak, and finite bounds.
- Mapping is finite, monotonic, continuous at the reference-white/shoulder
  boundary, and never exceeds safe current headroom.
- Offscreen Metal readback agrees with the CPU reference within an explicit
  tolerance for SDR, EDR, and SDR-fallback modes.
- Generation, display revision, headroom change, resize, stop, failure, and
  replacement tests reject stale output and release resources.
- Normal tests, five-platform Debug/Release, analyzer, sanitizer, malloc,
  generator, dependency, and simulator-inventory gates pass without real
  Keychain or live-host side effects.

### Physical evidence required for completion

- Authorized HDR10 Sunshine stream with a documented source/test pattern.
- SDR content on an HDR-capable display with stable reference white/color.
- HDR content on an SDR display with diagnosed bounded fallback.
- HDR content on an HDR display with confirmed HDR/EDR state and highlight
  retention, preferably with a reference pattern and measured or otherwise
  auditable luminance/color outcome.
- Current headroom reduction/recovery on the same display.
- Window movement between representative SDR/HDR or different-headroom displays
  without stale flashes, reconnect, or mismatched color.
- Clean stop, sleep/wake, display disconnect/reconnect, and no surviving EDR
  surface ownership.

Until those physical checks exist, stage 15 may report deterministic HDR/EDR
implementation readiness but remains `in_progress` and must not claim verified
HDR display output.
