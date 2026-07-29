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
| Metal plane mapping | `CVMetalVideoFrameMapper` maps NV12 to `.r8Unorm/.rg8Unorm` and P010 to `.r16Unorm/.rg16Unorm`; the production presenter runtime consumes those zero-copy planes after validating format, dimensions, device, generation, and color signature | Focused mapper/queue/presenter tests and real offscreen Metal execution | The standalone bounded queue is not yet the application presentation owner; display/surface revision ownership is added by tasks 4.1 through 5.1 |
| Presentation source | `StreamVideoPresentationSource` rejects wrong decoder generations and clears frames across pause, stop, failure, and replacement | Session/lifecycle integration tests | It stores raw `DecodedVideoFrame` only and has no render/display revision fence |
| Actual presenter | `StreamMetalPresenter` maps decoded frames through `CVMetalVideoFrameMapper` and the explicit repository Metal renderer. SDR uses the sRGB pipeline; HDR uses the bounded HDR-to-SDR pipeline until a resolved EDR surface exists | Focused production-runtime GPU execution, shader readback, lifecycle tests, full macOS tests, and five-platform builds | It intentionally fixes the drawable to sRGB and does not yet apply a float EDR drawable, extended-linear colorspace, display-owned headroom, or HDR metadata |
| Display lifecycle | macOS rereads the actual `NSScreen`, potential/current/reference headroom, internal screen identity, backing pixels, and drawable on window/screen/backing/resize notifications; a separate publisher advances only for attached/detached availability, display identity, or semantic headroom changes | AppKit notification, stale-attachment, same-state deduplication, same-display headroom, overflow, and full-suite tests | Task 5.1 must propagate this snapshot through AppModel/render state; task 4.3 defines how it participates in active configuration resolution |
| Surface intent | `StreamMetalPresenter` applies its current SDR contract through an injectable transaction adapter; the adapter owns view/layer pixel format, colorspace, EDR metadata, and extended-range intent together | Focused tests cover ordered SDR/EDR transitions, idempotency, typed unsupported, rollback, rollback failure, real macOS layer fields, and production fail-closed behavior; all five platform targets compile | Tasks 4.2 through 4.6 must add display/headroom revisions, resolve when EDR is eligible, and rebuild presentation across semantic transitions |
| AppModel fallback | Before real platform lifecycle exists, settings synthesize headroom values when the HDR preference is enabled | Existing model tests | Synthetic settings headroom is not display evidence and must not enable production EDR output |

The production truth after task 4.1 is therefore: LuneX presents both SDR and
HDR decoded layouts through the explicit shader and revision-owned Metal
renderer. Surface fields now have one atomic, platform-capability-gated owner,
but the current production resolver still requests only sRGB SDR, so HDR is
deliberately tone-mapped to headroom `1.0`. No production EDR selection, HDR
signaling, or physical HDR result is claimed until tasks 4.2 through 5.4 and the
hardware gate pass.

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

## Presenter lifecycle evidence

OpenSpec task 3.6 makes the production presenter boundary injectable without
adding a public or test-only rendering path. Deterministic tests cover:

- fixed SDR presenter configuration and runtime replacement;
- failed runtime construction without retaining stale ownership;
- partial configuration and render-pipeline failures with atomic mapper and
  renderer cleanup;
- active drawable unavailability, drawable/coordinate mismatch, missing
  coordinates, and missing frames;
- coordinate revision resize and decoded-frame replacement;
- active 60 FPS, throttled 15 FPS, and paused/idle immediate-clear scheduling;
- inactive policy cleanup even when no drawable can be acquired; and
- idempotent stop, invalidation, dismantle, and replacement resource release.

The final task-level evidence is `13/13` focused tests, `558 total / 557 passed /
1 explicit Keychain skip / 0 failed` for the complete macOS suite, five-platform
Debug builds with Metal compilation/linking, and stable repository/simulator
gates. This proves presenter lifecycle ownership and failure convergence. It
does not prove EDR surface configuration, display/headroom revision delivery,
HDR signaling, or physical luminance/color output; those remain in tasks 4.x
through 6.5.

## Surface adapter evidence

OpenSpec task 4.1 replaces the former boolean layer helper with one injectable
`HDRSurfaceTransactionAdapter` and a native `AppleMetalSurfaceAdapter`:

- macOS and iOS/iPadOS expose intent plus HDR metadata for Display-P3 and
  ITU-R 2020 EDR contracts; visionOS exposes the same controls for Display-P3;
  tvOS returns a typed unsupported outcome without referencing unavailable APIs;
- entering EDR applies the floating drawable format, extended-linear
  colorspace, HDR10 metadata, and EDR intent in that order;
- returning to SDR disables EDR intent, clears metadata, restores the sRGB
  drawable, and restores the sRGB colorspace;
- equal contracts are idempotent and do not begin a native transaction;
- mutation failure restores the complete native snapshot and retains the prior
  reported contract; rollback failure clears reported ownership; and
- `CATransaction` disables implicit animation while both `MTKView` and its
  `CAMetalLayer` receive the same Metal pixel format.

The production presenter applies its existing SDR contract through this adapter
before creating presentation runtime ownership. Unsupported output, snapshot
failure, mutation failure, or rollback failure invalidates the runtime, removes
the delegate, and pauses the view. Task 4.3 remains the owner of choosing an EDR
contract; task 4.1 does not enable EDR based only on display capability.

The task-level evidence is `22/22` focused tests, including real macOS
`CAMetalLayer` SDR to EDR to SDR field checks; `567 total / 566 passed / 1
explicit Keychain skip / 0 failed` for the complete macOS suite; five-platform
Debug builds that each compiled and linked the Metal shader; and OpenSpec,
fixture, generator, dependency, reference-path, Core Image regression,
whitespace, and simulator-inventory gates. This proves transactional field
application and compile safety, not production EDR eligibility, current
headroom mapping, HDR display signaling, or physical luminance/color output.

## Display revision evidence

OpenSpec task 4.2 separates display capability state from the pre-existing
general lifecycle and coordinate revisions:

- `HDRDisplaySnapshotPublisher` uses checked `UInt64` revisions and publishes
  one immutable display identity/headroom snapshot;
- attached/detached surface availability, internal display identity, or
  potential, current, or reference headroom changes advance the revision;
- stream activity, focus, visibility, render policy, and a geometry-only
  drawable resize do not advance the display revision;
- identical invalid `NaN` component states deduplicate rather than causing
  unbounded notification churn;
- revision exhaustion clears the active snapshot and remains fail closed; and
- stale attachment owners cannot clear or advance a replacement surface; an
  owner replacement with unchanged attached availability, display identity,
  and headroom is deliberately not a revision input.

macOS derives its internal identity from `NSScreenNumber`, which distinguishes
same-name screens, while logs expose only attachment and revision state. iOS and
iPadOS now read `potentialEDRHeadroom` independently from `currentEDRHeadroom`;
their live scene/window ownership remains stage 17 work. No stream HDR flag or
user preference participates in this publisher. Task 4.3 consumes those
separate inputs when resolving an active render configuration.

The task-level evidence is `19/19` focused tests; `571 total / 570 passed / 1
explicit Keychain skip / 0 failed` for the complete macOS suite; five-platform
Debug builds with Metal compilation/linking and no source diagnostics; stable
simulator inventory; and all repository gates. This proves semantic revision
publication and platform compile safety. It does not prove production
configuration propagation, EDR selection, current-headroom tone mapping, HDR
signaling, or physical display output.

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
