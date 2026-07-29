## ADDED Requirements

### Requirement: Picture in Picture SHALL use a supported native content source
On iOS/iPadOS, LuneX SHALL own an `AVPictureInPictureController` configured
with an `AVSampleBufferDisplayLayer` content source and a conforming playback
delegate. Policy-only state or a background-mode declaration SHALL NOT be
reported as active Picture in Picture.

#### Scenario: PiP runtime is prepared
- **WHEN** an active mobile media generation has valid decoded video and PiP is supported
- **THEN** the runtime SHALL create one sample-buffer display layer, content source, playback delegate, and controller owned by that generation

#### Scenario: Native controller reports PiP unavailable
- **WHEN** `isPictureInPicturePossible` is false or the controller cannot prepare
- **THEN** LuneX SHALL publish a typed unavailable state and SHALL NOT report PiP active

### Requirement: PiP SHALL reuse current decoded frames
The PiP path SHALL consume the active decoder generation's existing
`CVPixelBuffer` frames and timestamps through a bounded sample-buffer sink. It
SHALL NOT create a second video decoder, retain an unbounded frame queue, or
submit a frame under stale color or media-generation metadata.

#### Scenario: Current decoded frame is submitted
- **WHEN** a valid current-generation decoded frame arrives while the PiP sink accepts data
- **THEN** the runtime SHALL create and enqueue a timed sample buffer that preserves pixel-buffer ownership and relevant color attachments

#### Scenario: Display layer requires media data later
- **WHEN** the layer is not ready for more media data
- **THEN** the sink SHALL retain at most its documented bounded latest-frame policy and SHALL resume submission without blocking the decoder

#### Scenario: Decoder generation changes
- **WHEN** codec configuration or media ownership replaces the decoder generation
- **THEN** the prior PiP queue SHALL flush and SHALL NOT enqueue old frames into the replacement generation

### Requirement: PiP lifecycle SHALL be generation-scoped and truthful
Start and all subsequent PiP callbacks SHALL be serialized through a bounded
state machine and filtered by the active session/media/PiP generation,
including will-start, did-start, failed-start, will-stop, did-stop, restore,
playback-state, skip, and invalidation callbacks.

#### Scenario: User starts PiP
- **WHEN** the controller is possible, prepared, and the user requests Picture in Picture
- **THEN** the runtime SHALL request native start and publish active state only after the controller confirms start

#### Scenario: PiP start fails
- **WHEN** the native controller reports a start error
- **THEN** the runtime SHALL clear pending state, publish a stable failure class, and retain a usable foreground stream when possible

#### Scenario: Old controller callback arrives after replacement
- **WHEN** a stopped PiP generation receives any delayed delegate callback
- **THEN** that callback SHALL NOT mutate AppModel, continuity policy, rendering, or the replacement controller

#### Scenario: System requests interface restoration
- **WHEN** PiP stops and the system asks LuneX to restore its user interface
- **THEN** LuneX SHALL navigate to the current stream surface when the same session remains valid and SHALL invoke the restoration completion exactly once

### Requirement: Background continuity SHALL require an actual legal media path
Mobile background continuation SHALL be selected only when the current
generation has an active permitted audio session or confirmed active PiP path
and the required generated background configuration. Configuration presence
alone SHALL NOT grant arbitrary execution or keepalive.

#### Scenario: Scene backgrounds with confirmed PiP
- **WHEN** current-generation PiP is active and the scene enters background
- **THEN** foreground Metal presentation MAY suspend while decoder, audio, control, and bounded PiP frame delivery continue under the system-managed path

#### Scenario: Scene backgrounds with audio-only continuity
- **WHEN** permitted playback audio is active, PiP is not active, and audio continuity is enabled
- **THEN** the runtime SHALL suspend foreground rendering and continue only the resources required by the legal audio session

#### Scenario: No permitted path is active
- **WHEN** the scene enters background without active PiP or permitted audio continuity
- **THEN** LuneX SHALL suspend rendering and pause or stop the stream according to typed policy instead of attempting indefinite background work

#### Scenario: Continuity path ends in background
- **WHEN** the last permitted audio or PiP path becomes inactive while the scene remains backgrounded
- **THEN** the runtime SHALL immediately reevaluate policy and release unsupported work

### Requirement: Foreground and PiP presentation SHALL coordinate resources
The foreground Metal surface and PiP display layer SHALL share decoder output
without duplicating decode work, and presentation policy SHALL prevent hidden
foreground draws while preserving confirmed PiP playback.

#### Scenario: PiP becomes active
- **WHEN** native PiP start completes
- **THEN** foreground rendering SHALL transition to the documented paused or throttled policy while PiP receives current-generation frames

#### Scenario: PiP stops in foreground
- **WHEN** native PiP stop completes and the stream scene is visible with valid geometry
- **THEN** foreground Metal presentation SHALL resample display state and resume from the latest compatible decoded frame

### Requirement: PiP and continuity controls SHALL expose actual state accessibly
The stream UI and Settings SHALL provide native PiP and background-continuity
controls, current actual state, and bounded failure reasons with explicit
accessibility labels and values. A preference SHALL NOT be presented as active
runtime behavior.

#### Scenario: PiP is available during a stream
- **WHEN** the current runtime reports native PiP possible
- **THEN** an accessible native command SHALL allow the user to request start or stop and reflect pending and active state

#### Scenario: No active stream exists
- **WHEN** Settings is shown outside a session
- **THEN** continuity preferences MAY remain editable but status SHALL NOT claim that PiP or background continuation is active

### Requirement: PiP diagnostics SHALL be bounded and private
PiP and background diagnostics SHALL use stable codes and fixed summaries for
unsupported, preparing, possible, starting, active, stopping, failed,
restoring, audio-only, suspended, paused, and stale-generation states without
exposing host, scene, controller, frame, or sample-buffer identifiers.

#### Scenario: Native error is received
- **WHEN** the controller reports an implementation-specific error
- **THEN** the diagnostic SHALL map it to a bounded semantic class and SHALL NOT persist the raw localized description

#### Scenario: State recovers
- **WHEN** a later current-generation transition becomes healthy
- **THEN** recovery SHALL clear only the active PiP or continuity action while preserving unrelated diagnostics

### Requirement: Verification SHALL preserve PiP and background proof boundaries
The change SHALL pass deterministic state-machine, frame-sink, cancellation,
build, sanitizer, resource, and fixed-simulator gates, while actual PiP
presentation, background duration, audio continuity, thermal behavior, and live
Sunshine operation remain incomplete until authorized physical-device evidence
exists.

#### Scenario: Offline verification passes
- **WHEN** injected controller and sample-buffer tests plus platform builds succeed
- **THEN** LuneX MAY mark offline PiP tasks complete but SHALL NOT claim that system PiP or background continuity works on hardware

#### Scenario: Physical acceptance is performed
- **WHEN** an authorized iPhone and iPad exercise PiP start, background, restore, failure, interruption, and teardown with live Sunshine
- **THEN** evidence SHALL correlate the LuneX commit, signed configuration, native controller callbacks, audible/visible result, bounded resource use, and stream teardown
