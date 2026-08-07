## ADDED Requirements

### Requirement: visionOS presentation SHALL be explicitly windowed
Stage 18 SHALL present the current decoded stream in the actual SwiftUI window
Metal surface. It SHALL NOT report immersive, stereoscopic, volumetric, or
passthrough presentation without a separately owned runtime.

#### Scenario: Stream starts on Vision Pro
- **WHEN** a valid media generation starts in the windowed product path
- **THEN** LuneX SHALL create one current-generation Metal presentation owner and report windowed mode

#### Scenario: Current component revision advances
- **WHEN** current input, display, audio, or video state advances the platform coordinator semantic revision after an attached visionOS scene reported windowed mode
- **THEN** LuneX SHALL retain the same surface generation and rebrand the complete typed windowed state to the new current revision

#### Scenario: Window ownership is replaced or terminated
- **WHEN** replacement activation begins, the current scene detaches, or the current coordinator terminates
- **THEN** LuneX SHALL clear windowed mode immediately and SHALL NOT restore it from an old ownership callback

### Requirement: visionOS frames SHALL use the shared decoder and render identity
visionOS SHALL consume the existing decoded-frame source and validate decoder,
color, surface, display, and presentation revisions before presenting. It SHALL
NOT create a second decoder or unbounded frame queue.

#### Scenario: Stale frame completes
- **WHEN** a frame from an old decoder or surface revision completes after replacement
- **THEN** LuneX SHALL reject it and SHALL NOT present it in the current window

#### Scenario: Current frame follows window geometry
- **WHEN** the current decoder publishes a frame and the actual attached window advances its geometry revision
- **THEN** LuneX SHALL present and resubmit that frame only through the matching current surface and platform revision

#### Scenario: Presentation ownership is replaced
- **WHEN** a newer presentation ownership replaces a window that still has an admitted frame
- **THEN** LuneX SHALL clear the old drawable before presenting the replacement frame, cancel the old delivery ownership, and reject late old surface or frame callbacks

#### Scenario: Pending frame delivery exceeds the bounded queue
- **WHEN** more than 64 decoded-frame deliveries remain pending behind the current platform action
- **THEN** LuneX SHALL discard queued work, fail the matching current video component through one ordered consumer, cancel its subscription, and SHALL NOT affect replacement ownership

### Requirement: visionOS HDR SHALL fail closed from actual capability
LuneX SHALL use public visionOS surface/color capability and actual bounded
headroom when available. Without current headroom proof, HDR input SHALL use a
typed HDR-to-SDR path even if extended-range surface intent compiles.

#### Scenario: Current headroom is unavailable
- **WHEN** the platform cannot provide a finite current display headroom
- **THEN** LuneX SHALL select HDR-to-SDR and UI SHALL NOT claim EDR active

#### Scenario: Actual Metal layer changes or detaches
- **WHEN** the current visionOS window attaches, changes layout or traits, replaces its Metal layer, or detaches
- **THEN** LuneX SHALL sample only the current layer, advance replacement ownership, publish output unavailable on detach, and reject stale or invalidated callbacks without registering a screen notification

#### Scenario: Finite capability is supplied for checked validation
- **WHEN** a public source supplies finite headroom satisfying `1 < current <= potential <= 64` together with the complete layer and color capability
- **THEN** LuneX MAY construct the shared checked direct-EDR contract but SHALL NOT treat injected values, layer intent, compilation, or simulator output as current physical headset headroom proof

### Requirement: visionOS audio SHALL use intended spatial experience
The current media generation SHALL reuse the canonical session-owned audio
graph and public visionOS intended spatial experience, route, interruption, and
media-reset behavior without claiming unavailable listener head tracking.

#### Scenario: Spatial route is available
- **WHEN** a stereo or multichannel stream and supported visionOS route are active
- **THEN** LuneX SHALL apply the public intended spatial experience and publish actual route state

#### Scenario: Presentation activates after the audio runtime
- **WHEN** a valid current-session audio runtime exists before visionOS presentation activation or replacement
- **THEN** LuneX SHALL replay its normalized current route into that ownership without creating another graph, route observer, or notification source

#### Scenario: Interruption or media-service loss occurs
- **WHEN** the current visionOS audio runtime reports interruption or media services lost
- **THEN** LuneX SHALL publish the checked runtime stage, retain or close output according to the event, and SHALL NOT preserve a false active spatial claim while output is unavailable

#### Scenario: Media services reset
- **WHEN** the audio service resets during the current stream
- **THEN** LuneX SHALL rebuild one current graph and reject old scheduling completions

#### Scenario: Audio runtime is stale or incompatible
- **WHEN** an event has an old graph, duplicate sequence, inconsistent route/spatial revision or support, invalid channel count, tvOS-only environment-listener strategy, or spatial mode without matching intended experience
- **THEN** LuneX SHALL reject stale state, fail current presentation on invalid state, and SHALL NOT apply listener entitlement semantics to visionOS

#### Scenario: Audio ownership stops or fails
- **WHEN** the current audio action fails, presentation terminates, ownership is replaced, or the session stops
- **THEN** LuneX SHALL clear route and spatial state through the shared coordinator and make late old-generation events inert

### Requirement: visionOS media ownership SHALL be generation scoped
LuneX SHALL bind window scene, surface, decoded frames, HDR policy, audio route,
diagnostics, and teardown to one current media presentation coordinator.

#### Scenario: Current platform components are coordinated
- **WHEN** the current visionOS media generation has an attached active scene, eligible input, decoded frame, typed HDR resolution, and canonical audio route
- **THEN** LuneX SHALL publish them through one matching presentation ownership and bounded coordinator snapshot without creating a second media or input owner

#### Scenario: Display arrives before a same-surface resize completes
- **WHEN** a current display source is pending behind one geometry application and a newer geometry revision replaces it on the same surface
- **THEN** LuneX SHALL reject the superseded application, apply the latest scene and input first, and replay the current display source behind that latest geometry

#### Scenario: Surface generation changes
- **WHEN** a replacement surface generation supersedes the current geometry
- **THEN** LuneX SHALL cancel pending display application, clear the old display source, and SHALL NOT replay it into the replacement surface

#### Scenario: Media generation reconnects
- **WHEN** the current session enters reconnect and starts a replacement media generation on the surviving actual window
- **THEN** LuneX SHALL clear old windowed, render, HDR, and input state, apply a reconnect stop, replay current surface values only into the replacement generation, and reject late old-generation coordinator state

#### Scenario: Current display application fails
- **WHEN** the current visionOS display action cannot be applied
- **THEN** LuneX SHALL clear render and HDR source state and fail the matching current presentation through the shared coordinator

#### Scenario: Stream stops
- **WHEN** local or remote stop completes
- **THEN** LuneX SHALL apply the matching typed stop reason, clear windowed, input, display, render, frame, audio, observer, and coordinator ownership, and make late state inert

#### Scenario: Connected media regression sequence completes
- **WHEN** one current visionOS presentation exercises windowed and complete immersive-unavailable state, frame presentation and same-surface resubmission, typed HDR fallback, spatial route interruption/loss/reset/recovery, full ownership replacement, late old callbacks, and repeated local stop
- **THEN** LuneX SHALL retain only current scene, surface, frame, display, graph, and input ownership, resume only the replacement, clear every terminal component, and execute each owner teardown exactly once

#### Scenario: Presentation subscription is replaced and stopped
- **WHEN** the current visionOS media environment replaces its frame subscription and later stops
- **THEN** LuneX SHALL retain exactly one active subscription and bounded delivery pump, cancel every consumer task, clear coordinator component state, and stop each owned video receiver, audio receiver, video processor, audio processor, and input provider exactly once

### Requirement: visionOS media UI SHALL expose actual state accessibly
Stream controls and Settings SHALL show actual windowed mode, render state, HDR
fallback, spatial-audio route, input capability, and bounded failures using
native accessible SwiftUI controls.

#### Scenario: Requested feature is unavailable
- **WHEN** HDR, immersive presentation, head tracking, or input is not actually available
- **THEN** UI SHALL show typed fallback/unavailable state rather than the preference as active

### Requirement: visionOS media verification SHALL preserve physical proof boundaries
Builds, injected tests, and simulator windows SHALL NOT prove headset HDR,
spatial audio, comfort, interaction latency, thermal behavior, signed install,
or live Sunshine operation.

#### Scenario: Physical acceptance is performed
- **WHEN** an authorized signed Vision Pro exercises window resize, supported input, video/audio, route recovery, live Sunshine, comfort duration, resources, and clean stop
- **THEN** evidence SHALL correlate commit, sanitized conditions, actual state, observed result, performance/thermal observations, and teardown
