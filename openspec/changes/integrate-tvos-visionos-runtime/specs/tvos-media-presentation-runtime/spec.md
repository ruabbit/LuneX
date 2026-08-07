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

#### Scenario: Complete public EDR capability is available
- **WHEN** the current tvOS screen and Metal layer expose preferred dynamic range, tone-map control, content-headroom control, an extended-linear supported gamut, and finite `1 < current <= potential` headroom
- **THEN** LuneX SHALL create a headroom-tagged EDR surface contract and apply the float drawable, extended-linear color space, disabled layer tone mapping, finite content headroom, and high dynamic-range preference transactionally

#### Scenario: Display headroom is missing or invalid
- **WHEN** current or potential headroom is missing, nonfinite, out of range, inverted, or current headroom is not greater than SDR reference white
- **THEN** LuneX SHALL publish a stable typed fallback, normalize invalid stored headroom, and SHALL NOT claim direct HDR output

#### Scenario: Actual display capability changes
- **WHEN** the actual current tvOS stream screen changes mode or brightness and its normalized output, layer, gamut, or headroom capability changes
- **THEN** LuneX SHALL publish one deduplicated surface-owned display revision and apply only its matching current-generation coordinator component

#### Scenario: Display source is replaced
- **WHEN** a replacement surface or newer display source is accepted while an older display application or coordinator snapshot is pending
- **THEN** LuneX SHALL close the old render display state immediately and SHALL reject any rebranded or late component whose source identity does not match

#### Scenario: Display revision is exhausted
- **WHEN** the bounded display semantic revision can no longer advance
- **THEN** LuneX SHALL close display rendering, publish one bounded semantic-revision failure, and SHALL NOT recover until current ownership is replaced

#### Scenario: EDR surface mutation fails
- **WHEN** any preferred-dynamic-range, tone-map, headroom, color-space, or drawable mutation fails
- **THEN** LuneX SHALL restore every captured legacy and current layer field and SHALL NOT retain the failed surface contract as active

### Requirement: tvOS audio SHALL use the current route-owned graph
The current media generation SHALL reuse canonical PCM, the session-owned
audio graph, AVAudioSession route state, interruption/media-reset recovery, and
typed spatial/head-tracking capability.

#### Scenario: Audio route changes
- **WHEN** the active tvOS route changes during playback
- **THEN** LuneX SHALL serialize one graph reconfiguration and make old scheduled completions inert

#### Scenario: Presentation ownership activates after audio runtime
- **WHEN** a valid current-session audio runtime exists before tvOS presentation activation or presentation replacement
- **THEN** LuneX SHALL replay one normalized current route snapshot into that ownership without creating another graph or observer

#### Scenario: Interruption and media services recovery
- **WHEN** the current AVAudioSession reports interruption begin/end, media services lost, or media services reset
- **THEN** LuneX SHALL publish checked runtime stage and cause, normalize unavailable output while services are lost, and accept recovery only from the current graph generation

#### Scenario: Audio runtime is stale or invalid
- **WHEN** route state has a duplicate sequence, older graph generation, inconsistent route/spatial revision, invalid channel count, incompatible tvOS strategy, or unauthorized head tracking
- **THEN** LuneX SHALL reject stale state, fail the current presentation on invalid state, and SHALL NOT preserve a false active spatial claim

#### Scenario: Audio application fails or terminates
- **WHEN** the current audio-route effect fails, semantic revision exhausts, presentation fails, or the session stops
- **THEN** LuneX SHALL run bounded shared teardown, clear the platform audio route from terminal snapshots, and prevent late events from reopening it

### Requirement: tvOS media integration SHALL be generation scoped
Scene, video, display, audio, input eligibility, diagnostics, and teardown SHALL
belong to one current media presentation coordinator and clear on failure,
replacement, remote termination, or stop.

#### Scenario: Media generation is replaced
- **WHEN** reconnect replaces the tvOS media generation
- **THEN** old scene, frame, route, and presentation callbacks SHALL NOT mutate the replacement

#### Scenario: Same surface survives reconnect
- **WHEN** the actual tvOS stream view remains attached with semantically unchanged geometry and display capability while the media generation is replaced
- **THEN** LuneX SHALL replay current geometry followed by current display into the replacement ownership without advancing either semantic revision or creating another surface owner, display observer, decoder, or audio graph

#### Scenario: Current values rebuild replacement presentation
- **WHEN** current geometry and display values are replayed for the replacement media generation
- **THEN** current-generation application SHALL proceed as activation, scene, input eligibility, and display while audio remains owned by the single native audio publisher

#### Scenario: Remote termination races local stop
- **WHEN** remote termination and local environment stop concurrently target the same media generation
- **THEN** LuneX SHALL preserve one terminal reason and snapshot, execute coordinator teardown once, release each owned video, audio, and input resource once, and keep late callbacks inert

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
