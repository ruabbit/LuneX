## ADDED Requirements

### Requirement: tvOS stream lifecycle SHALL come from the actual surface scene
The tvOS stream surface SHALL derive attachment, scene activity, visibility,
focus eligibility, scale, bounds, and drawable size from its actual view and
window scene under one current surface generation.

#### Scenario: Surface attaches
- **WHEN** the actual Metal view enters an active tvOS window scene with finite geometry
- **THEN** LuneX SHALL publish one current-generation lifecycle and drawable snapshot

#### Scenario: Surface detaches
- **WHEN** the actual stream view leaves its window
- **THEN** presentation and input SHALL close without selecting a global scene or screen

### Requirement: tvOS geometry SHALL drive one render contract
Finite normalized drawable geometry SHALL drive Metal surface size, fit/fill
video mapping, and any supported input reference together. Invalid geometry
SHALL fail closed.

#### Scenario: Television mode changes
- **WHEN** scale or drawable geometry changes
- **THEN** LuneX SHALL publish one semantic revision and reject stale incompatible frames

### Requirement: tvOS decoded frames SHALL require current coordinator admission
The actual tvOS Metal presenter SHALL consume the existing decoded-frame
source only through the current platform presentation coordinator. It SHALL
validate session, media, presentation, input, surface, decoder, frame,
delivery-revision, and platform-revision ownership without creating a second
decoder or frame queue.

#### Scenario: Current decoded frame is admitted
- **WHEN** the current active scene and matching surface receive a current decoded-frame delivery
- **THEN** the coordinator-admitted frame SHALL be submitted to the actual presenter

#### Scenario: Shared latest frame bypass is attempted
- **WHEN** the shared source contains a frame that the platform coordinator has not admitted
- **THEN** the bound tvOS presenter SHALL remain blank

#### Scenario: Geometry rebrands the current frame
- **WHEN** valid geometry changes without a newer decoded-frame delivery
- **THEN** the coordinator MAY resubmit that same frame under the newer platform revision and the presenter SHALL reject the old draw fence

#### Scenario: Presentation eligibility closes and resumes
- **WHEN** the scene detaches, becomes inactive or hidden, geometry becomes invalid, the display is explicitly unavailable, or ownership is replaced
- **THEN** the actual presenter SHALL clear and SHALL resume only a matching current-generation admitted frame

### Requirement: tvOS HDR output SHALL reflect actual public capability
LuneX SHALL probe and consume public tvOS display and Metal-layer capability.
When direct extended-range presentation is unavailable, HDR input SHALL use the
typed HDR-to-SDR pipeline and UI SHALL NOT claim HDR output.

#### Scenario: HDR stream uses unsupported surface
- **WHEN** decoded HDR metadata is valid but the current tvOS surface lacks required extended-range support
- **THEN** LuneX SHALL present the existing bounded HDR-to-SDR result and report actual fallback

### Requirement: tvOS audio SHALL use the current route-owned graph
The current media generation SHALL reuse canonical PCM, the session-owned
audio graph, AVAudioSession route state, interruption/media-reset recovery, and
typed spatial/head-tracking capability.

#### Scenario: Audio route changes
- **WHEN** the active tvOS route changes during playback
- **THEN** LuneX SHALL serialize one graph reconfiguration and make old scheduled completions inert

### Requirement: tvOS media integration SHALL be generation scoped
Scene, video, display, audio, input eligibility, diagnostics, and teardown SHALL
belong to one current media presentation coordinator and clear on failure,
replacement, remote termination, or stop.

#### Scenario: Media generation is replaced
- **WHEN** reconnect replaces the tvOS media generation
- **THEN** old scene, frame, route, and presentation callbacks SHALL NOT mutate the replacement

### Requirement: tvOS media UI SHALL show actual state accessibly
Stream controls and Settings SHALL expose actual scene, render, HDR fallback,
audio route/spatial state, controller eligibility, and bounded failures using
native focusable controls and privacy-safe text.

#### Scenario: HDR preference is enabled during fallback
- **WHEN** user preference requests HDR but actual tvOS output is SDR fallback
- **THEN** UI SHALL report SDR fallback rather than active HDR

### Requirement: tvOS media verification SHALL preserve physical proof boundaries
Builds, injected tests, and simulator navigation SHALL NOT prove television HDR,
spatial audio, long-run performance, signed installation, or live Sunshine.

#### Scenario: Physical acceptance is performed
- **WHEN** an authorized signed Apple TV exercises SDR/HDR, audio routes, remote/controller input, live Sunshine, and clean stop
- **THEN** evidence SHALL correlate commit, sanitized conditions, actual state, visible/audible result, resource observations, and teardown
