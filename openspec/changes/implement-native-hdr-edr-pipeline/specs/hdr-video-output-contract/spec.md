## ADDED Requirements

### Requirement: Decoded video layout shall match the negotiated color contract
LuneX SHALL validate decoded pixel format, plane count, bit depth, range, primaries, transfer function, matrix, codec capability, and frame metadata before a frame enters an SDR or HDR rendering path.

#### Scenario: Valid SDR frame is accepted
- **WHEN** an active generation produces an 8-bit bi-planar video-range frame with a valid Rec.709 SDR contract
- **THEN** LuneX SHALL select the explicit SDR input layout and preserve the matching color contract for rendering

#### Scenario: Valid HDR10 frame is accepted
- **WHEN** an active generation produces a 10-bit bi-planar video-range frame with valid BT.2020 primaries, PQ transfer, supported matrix, and HDR-capable codec negotiation
- **THEN** LuneX SHALL select the explicit HDR10 input layout and preserve mastering and content-light bounds for rendering

#### Scenario: Pixel format and metadata disagree
- **WHEN** HDR metadata arrives on an 8-bit buffer, SDR metadata arrives on an unsupported 10-bit path, or plane/range layout is incompatible
- **THEN** LuneX SHALL reject the frame from HDR presentation and publish a typed bounded diagnostic without silently relabeling it

### Requirement: Frame color ownership shall be generation scoped
Each renderable frame SHALL retain the decoder generation and immutable color signature that existed when the frame was decoded, and SHALL be rejected when either no longer matches the active render configuration.

#### Scenario: Decoder metadata changes
- **WHEN** bit depth, transfer, primaries, matrix, mastering, or content-light metadata changes for an active stream
- **THEN** LuneX SHALL clear old presentation, establish a new configuration revision, and accept only frames decoded under the matching current generation and signature

#### Scenario: Stale frame arrives after replacement
- **WHEN** a frame from an earlier decoder generation or color signature arrives after replacement
- **THEN** LuneX SHALL drop it without changing the current surface, headroom policy, or diagnostic ownership

### Requirement: Metal plane mapping shall remain zero copy and format explicit
LuneX SHALL map supported bi-planar CoreVideo surfaces to Metal luma/chroma textures with pixel formats appropriate to the validated bit depth and SHALL reject unexpected texture dimensions, formats, or device ownership.

#### Scenario: Eight-bit frame maps to Metal
- **WHEN** a validated SDR frame uses the supported 8-bit bi-planar layout
- **THEN** its planes SHALL map to `.r8Unorm` and `.rg8Unorm` textures on the active Metal device

#### Scenario: Ten-bit frame maps to Metal
- **WHEN** a validated HDR frame uses the supported 10-bit bi-planar layout
- **THEN** its planes SHALL map to `.r16Unorm` and `.rg16Unorm` textures without CPU color conversion

#### Scenario: Mapped texture is inconsistent
- **WHEN** CoreVideo returns an unexpected plane count, size, Metal pixel format, or device
- **THEN** LuneX SHALL fail that frame, release temporary texture ownership, and keep later current-generation frames eligible

### Requirement: Output resources shall teardown with session ownership
HDR mapping, texture cache, pipeline, queued frame, and surface-configuration resources SHALL be bounded and SHALL release on stop, replacement, failure, or view dismantle.

#### Scenario: HDR session stops with queued frames
- **WHEN** stop or replacement occurs while HDR frames or pipeline work remain queued
- **THEN** LuneX SHALL reject late output, flush generation-owned queues and texture caches, clear presentation, and leave no stale resource able to reconfigure the replacement surface
