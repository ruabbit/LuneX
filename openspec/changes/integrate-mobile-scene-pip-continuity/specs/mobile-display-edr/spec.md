## ADDED Requirements

### Requirement: Mobile display state SHALL come from the attached window screen
On iOS/iPadOS, LuneX SHALL read EDR capability and current headroom from the
actual stream view's attached `UIWindow` screen. It SHALL NOT use
`UIScreen.main`, an arbitrary connected screen, a device-name table, or a
repository setting as runtime proof.

#### Scenario: Stream surface attaches
- **WHEN** the actual stream view attaches to a window and screen
- **THEN** the display adapter SHALL read potential and current EDR headroom from that screen and publish a current-generation snapshot

#### Scenario: Stream surface changes screens
- **WHEN** the actual view/window attachment resolves to a different screen
- **THEN** the adapter SHALL invalidate the prior display snapshot and publish the new screen's normalized EDR state before rendering resumes

#### Scenario: Stream surface detaches
- **WHEN** no actual window screen is available
- **THEN** mobile EDR state SHALL become detached or unknown and SHALL NOT fall back to a global screen

### Requirement: Mobile EDR revisions SHALL track semantic headroom changes
The active display adapter SHALL resample on attachment, layout/display moves,
foreground restoration, supported screen mode changes, brightness changes, and
relevant registered trait changes. Equivalent normalized values SHALL be
deduplicated into one semantic revision stream.

#### Scenario: Current EDR headroom changes
- **WHEN** the attached screen reports a different finite current EDR headroom
- **THEN** the adapter SHALL publish one monotonic display revision and trigger compatible render reconfiguration

#### Scenario: Brightness notification belongs to another screen
- **WHEN** a screen notification does not refer to the currently attached screen
- **THEN** the adapter SHALL ignore it

#### Scenario: Equivalent values repeat
- **WHEN** multiple notifications produce the same normalized display state
- **THEN** the adapter SHALL NOT recreate the Metal pipeline or publish duplicate diagnostics

### Requirement: EDR input values SHALL be finite and bounded
Potential and current headroom SHALL be normalized to finite supported ranges,
current headroom SHALL NOT imply capability beyond potential headroom, and
invalid or overflowing values SHALL fail closed to a typed SDR fallback.

#### Scenario: Screen reports normal SDR
- **WHEN** potential and current EDR headroom are both at most one
- **THEN** the runtime SHALL publish supported SDR state without claiming EDR

#### Scenario: Screen reports nonfinite headroom
- **WHEN** any required headroom component is NaN, infinite, negative, or outside the documented bound
- **THEN** the runtime SHALL publish an invalid-display fallback and configure conservative SDR presentation

### Requirement: Metal presentation SHALL consume current mobile display revisions
The current mobile display revision SHALL participate in the same HDR render
configuration identity used by the decoder and `MetalStreamSurface`. HDR/EDR
presentation SHALL reconfigure atomically when the window screen or headroom
changes and SHALL reject frames bound to stale incompatible configuration.

#### Scenario: HDR frame arrives on an EDR-capable screen
- **WHEN** current frame metadata is supported and current EDR headroom exceeds SDR
- **THEN** the renderer SHALL use the repository's native HDR-to-EDR path with the actual bounded headroom for that display revision

#### Scenario: Headroom drops to SDR
- **WHEN** current EDR headroom falls to one during an HDR stream
- **THEN** the renderer SHALL atomically select the typed HDR-to-SDR fallback without presenting under stale EDR scaling

#### Scenario: Window moves during decode
- **WHEN** a frame completes under the prior display revision after the surface moved
- **THEN** the renderer SHALL validate compatibility and SHALL NOT present the frame under an incompatible replacement configuration

### Requirement: Mobile display ownership SHALL be generation-scoped
Screen notification tokens SHALL be owned by the active stream-surface/media
generation together with trait registrations, snapshots, render
reconfiguration tasks, and diagnostics, and SHALL be cancelled on detach,
replacement, or teardown.

#### Scenario: Display adapter is replaced
- **WHEN** an old screen callback races a replacement surface attachment
- **THEN** its revision SHALL be discarded and SHALL NOT reconfigure the replacement renderer

#### Scenario: Teardown is repeated
- **WHEN** display observation is stopped more than once
- **THEN** cancellation SHALL remain idempotent and release notification, view, window, and screen ownership

### Requirement: Mobile HDR UI SHALL expose actual bounded state
The stream status, Settings, and diagnostics SHALL distinguish detached,
unknown, SDR, EDR-capable, EDR-active, HDR-to-SDR fallback, invalid-headroom,
and reconfiguring states using localized, accessible native UI. They SHALL NOT
claim HDR from the user preference alone.

#### Scenario: EDR is active
- **WHEN** the current renderer reports an EDR presentation configuration for the active display revision
- **THEN** native status SHALL show actual HDR/EDR state and an accessibility value derived from bounded headroom

#### Scenario: HDR preference is enabled on SDR display
- **WHEN** the user requests HDR but current actual headroom is SDR
- **THEN** UI SHALL report the actual HDR-to-SDR fallback rather than an active EDR claim

### Requirement: Mobile display diagnostics SHALL preserve privacy
Display diagnostics SHALL use stable codes and bounded numeric headroom while
excluding raw screen, scene, window, host, frame, and hardware marketing
identifiers.

#### Scenario: Display changes
- **WHEN** the current stream surface moves to another screen
- **THEN** diagnostics SHALL record a semantic display-change action without persisting the screen object identity

#### Scenario: Invalid headroom is observed
- **WHEN** display normalization rejects a value
- **THEN** diagnostics SHALL record a fixed invalid-headroom class and SHALL NOT persist unbounded object descriptions

### Requirement: Verification SHALL preserve mobile HDR proof boundaries
The change SHALL pass deterministic headroom, revision, render-identity,
platform-build, analyzer, sanitizer, and fixed-simulator gates, while visible
HDR luminance, EDR brightness response, external-display mapping, power, and
live Sunshine behavior remain incomplete until authorized hardware evidence
exists.

#### Scenario: Offline verification passes
- **WHEN** injected display snapshots, renderer tests, and simulator builds succeed
- **THEN** offline mobile EDR tasks MAY complete but actual luminance and external-display acceptance SHALL remain pending

#### Scenario: Physical acceptance is performed
- **WHEN** authorized EDR-capable iPhone/iPad and external-display hardware exercise SDR/HDR streams and headroom transitions
- **THEN** evidence SHALL correlate the LuneX commit, device/display conditions, runtime revision, render mode, visible result, power observation, and clean teardown
