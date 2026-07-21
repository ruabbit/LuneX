## ADDED Requirements

### Requirement: PQ luminance mapping shall be explicit and bounded
LuneX SHALL decode ST 2084 PQ into absolute luminance, normalize against a documented reference white, and map highlights through a continuous monotonic function bounded by safe current display headroom.

#### Scenario: HDR highlight fits current EDR headroom
- **WHEN** a PQ sample is above reference white and the current display headroom can represent the resolved highlight
- **THEN** LuneX SHALL preserve the highlight above component value `1.0` without exceeding current headroom

#### Scenario: HDR highlight exceeds current EDR headroom
- **WHEN** decoded luminance exceeds the target peak derived from current headroom
- **THEN** LuneX SHALL compress it through the configured shoulder monotonically and clamp only the final output to the safe target bound

#### Scenario: Current headroom falls during presentation
- **WHEN** current headroom decreases while potential headroom remains higher
- **THEN** LuneX SHALL create a new mapping revision using current headroom and SHALL NOT continue emitting values based only on potential headroom

### Requirement: Mastering and content-light metadata shall bound source luminance
The tone-map resolver SHALL derive a finite positive source peak from validated mastering and content-light metadata and SHALL use a documented conservative HDR10 fallback when those values are absent.

#### Scenario: Mastering and MaxCLL are valid
- **WHEN** both mastering maximum luminance and MaxCLL are present within accepted bounds
- **THEN** LuneX SHALL resolve a bounded source peak deterministically and expose whether mastering or content-light data constrained it

#### Scenario: Light metadata is absent
- **WHEN** a valid HDR10 stream has no mastering maximum or MaxCLL
- **THEN** LuneX SHALL use the documented fallback peak, retain HDR eligibility, and publish a bounded fallback diagnostic

#### Scenario: Light metadata is invalid
- **WHEN** source luminance metadata is non-finite, non-positive, inverted, or outside accepted protocol bounds
- **THEN** LuneX SHALL reject the invalid HDR contract rather than generate an unbounded mapping

### Requirement: SDR reference appearance shall remain stable
LuneX SHALL preserve SDR reference-white and Rec.709 appearance for SDR content regardless of EDR display capability and SHALL avoid scaling all SDR values to available HDR headroom.

#### Scenario: SDR content appears on an EDR display
- **WHEN** a valid SDR frame is presented while the display reports headroom greater than `1.0`
- **THEN** LuneX SHALL use the SDR transfer/gamut path with reference white at component value `1.0` and SHALL NOT promote ordinary SDR white to peak EDR

#### Scenario: HDR content falls back to SDR
- **WHEN** HDR input is valid but EDR output is disabled or unavailable and the platform supports SDR tone mapping
- **THEN** LuneX SHALL map the HDR luminance and gamut into a bounded SDR result and publish an explicit fallback state

### Requirement: Color conversion shall be deterministic and gamut aware
LuneX SHALL explicitly normalize video-range YCbCr, apply the declared matrix, decode the declared transfer, and convert the declared source primaries into the configured linear output gamut before final luminance bounding.

#### Scenario: BT.2020 PQ input renders to an extended-linear output gamut
- **WHEN** a valid HDR10 pixel sample is rendered through an EDR configuration
- **THEN** LuneX SHALL apply the BT.2020 video-range and PQ transforms in a fixed order and produce finite bounded linear output matching reference vectors within declared tolerance

#### Scenario: Rec.709 SDR input renders to sRGB output
- **WHEN** a valid SDR pixel sample is rendered through the SDR configuration
- **THEN** LuneX SHALL apply the Rec.709 video-range and transfer transforms and match reference vectors within declared tolerance

#### Scenario: Transform input is unsupported
- **WHEN** the metadata requests an unsupported range, matrix, transfer, or primaries combination
- **THEN** LuneX SHALL reject the configuration instead of applying a nearest guessed transform
