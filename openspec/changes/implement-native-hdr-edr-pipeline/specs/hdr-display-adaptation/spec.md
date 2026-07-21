## ADDED Requirements

### Requirement: Stream HDR state and display EDR capability shall remain independent
LuneX SHALL resolve HDR presentation eligibility from separate stream metadata, user preference, platform support, display capability, and current headroom inputs.

#### Scenario: HDR stream and eligible EDR display
- **WHEN** valid HDR input, enabled user preference, supported platform surface, and current display headroom greater than `1.0` are all present
- **THEN** LuneX SHALL configure the active stream surface for the EDR mapping selected by the current render revision

#### Scenario: SDR stream and EDR display
- **WHEN** the display supports EDR but the current stream is SDR
- **THEN** LuneX SHALL keep the surface and mapping in the SDR content path

#### Scenario: HDR stream and ineligible display
- **WHEN** valid HDR input is present but platform support, user preference, or current headroom does not permit EDR
- **THEN** LuneX SHALL select an explicit supported SDR fallback or a typed closed state and SHALL NOT claim active HDR output

### Requirement: Actual stream surface shall use a matching output contract
The active stream surface SHALL apply the resolved drawable format, extended-range intent, and output colorspace together and SHALL present only frames whose render configuration matches that surface state.

#### Scenario: Surface enters EDR mode
- **WHEN** the resolver transitions from SDR to eligible EDR output
- **THEN** LuneX SHALL clear stale presentation, apply the floating-point drawable and extended-linear colorspace through the platform adapter, rebuild matching pipeline state, and then accept matching frames

#### Scenario: Surface returns to SDR mode
- **WHEN** HDR eligibility ends because the stream, preference, display, or headroom changes
- **THEN** LuneX SHALL clear EDR presentation, restore the SDR drawable/colorspace contract, and prevent an old HDR frame from re-enabling EDR

#### Scenario: Platform cannot apply the requested surface
- **WHEN** a target OS or device cannot support the resolved HDR surface contract
- **THEN** LuneX SHALL fail closed to an explicit supported fallback and publish a stable unsupported-output diagnostic

### Requirement: Display and headroom changes shall be revisioned atomically
Screen, display identity, current/potential/reference headroom, drawable, and HDR surface capability changes SHALL create an ordered display revision consumed atomically by mapping and presentation.

#### Scenario: macOS window moves between displays
- **WHEN** the active stream window moves between displays or receives screen/backing/parameter notifications
- **THEN** LuneX SHALL reread the actual screen and headroom, resolve a new surface/mapping revision, clear incompatible presentation, and preserve session/control ownership

#### Scenario: Headroom changes without a display identity change
- **WHEN** current EDR headroom changes on the same display
- **THEN** LuneX SHALL update the luminance bound and reject work completed for the old headroom revision without requiring a session reconnect

#### Scenario: Detached view reports a late display update
- **WHEN** a previous window or surface reports a delayed headroom or screen callback after replacement
- **THEN** LuneX SHALL ignore it and SHALL NOT mutate the replacement surface or mapping

### Requirement: HDR diagnostics shall be bounded and recoverable
LuneX SHALL expose semantic current HDR state and bounded history for active SDR, active EDR, SDR fallback, invalid input, unsupported output, stale revision, and pipeline failure without recording sensitive frame, host, app, or display identity data.

#### Scenario: HDR falls back and later recovers
- **WHEN** current headroom temporarily removes EDR eligibility and later returns
- **THEN** LuneX SHALL show a typed fallback action while constrained, clear that current action after a matching EDR revision becomes active, and retain only bounded redacted history

#### Scenario: Equivalent HDR state repeats
- **WHEN** resize or frame delivery repeats the same semantic HDR state
- **THEN** LuneX SHALL deduplicate diagnostics rather than logging per-frame metadata, pixel values, or display identifiers

### Requirement: Hardware HDR completion shall require physical evidence
LuneX SHALL keep HDR hardware acceptance incomplete until output is measured or visibly validated on authorized physical HDR and SDR displays across representative headroom and display transitions.

#### Scenario: Deterministic and simulator gates pass
- **WHEN** mapping tests, shader readback, app tests, and simulator builds pass without physical display evidence
- **THEN** LuneX SHALL report deterministic implementation readiness but SHALL NOT claim verified peak luminance, HDR signaling, color accuracy, cross-display appearance, or device performance

#### Scenario: Physical display acceptance is executed
- **WHEN** authorized hardware exercises SDR-on-HDR, HDR-on-SDR, HDR-on-HDR, current-headroom change, and cross-display transitions with redacted measurements
- **THEN** LuneX SHALL record the display/platform matrix, mapping revision behavior, measured or reference-pattern outcome, fallback behavior, and remaining limitations before marking hardware acceptance complete
