## ADDED Requirements

### Requirement: Spatial audio state SHALL belong to the active media generation
Audio graph state, route revisions, observation tasks, and diagnostics SHALL be bound to one session/media/audio generation and SHALL NOT be mutated by callbacks from stopped or replaced generations.

#### Scenario: Session is replaced during route rebuild
- **WHEN** an old audio generation completes a route rebuild after a replacement starts
- **THEN** its result SHALL be discarded and SHALL NOT change the replacement graph or application state

#### Scenario: Late schedule completion arrives after stop
- **WHEN** a stopped generation receives a buffer-consumed callback
- **THEN** the callback SHALL have no effect on current scheduling capacity or spatial state

### Requirement: Recovery SHALL preserve negotiated spatial intent
Route changes, interruptions, underruns, and graph recovery SHALL rebuild from the immutable negotiated configuration and current user/platform policy rather than from stale graph objects.

#### Scenario: Interruption resumes on the same route
- **WHEN** the system ends a resumable interruption
- **THEN** the runtime SHALL rebuild the graph, re-resolve current entitlement/route state, and resume only after a running snapshot is current

#### Scenario: Route changes while interrupted
- **WHEN** route capability changes during an interruption
- **THEN** the runtime SHALL defer the rebuild and apply the latest semantic route revision at resume

### Requirement: Application state SHALL reflect the actual runtime
`NativeSessionMediaEnvironment` SHALL forward current-generation audio runtime state, and `AppModel` SHALL expose only state produced by the active processor rather than synthesizing availability from settings.

#### Scenario: First PCM is scheduled
- **WHEN** the active audio processor successfully schedules current-generation decoded PCM
- **THEN** media readiness and the current audio/spatial runtime state SHALL be associated with the same session generation

#### Scenario: Media environment stops
- **WHEN** the active media environment tears down
- **THEN** AppModel SHALL clear current audio/spatial presentation while preserving bounded diagnostic history

### Requirement: User preferences SHALL be persistent and backward compatible
The client SHALL persist separate spatial-audio and head-tracking preferences, SHALL supply defaults when older settings files lack them, and SHALL re-resolve the current graph without corrupting other settings.

#### Scenario: Existing settings file is loaded
- **WHEN** a stored settings document predates spatial-audio preference fields
- **THEN** loading SHALL preserve existing values and apply documented spatial defaults

#### Scenario: Preference changes during a stream
- **WHEN** the user toggles spatial playback or head tracking
- **THEN** the active generation SHALL apply one serialized semantic reconfiguration or report why it cannot be applied

### Requirement: Diagnostics SHALL be bounded, semantic, and scoped
Spatial audio diagnostics SHALL use stable codes and fixed summaries for active, fixed, head-tracked, visionOS, fallback, missing-entitlement, unsupported-route/layout, recovery, and graph-failure states without exposing sensitive runtime payloads.

#### Scenario: Equivalent state repeats
- **WHEN** repeated callbacks resolve to the same semantic state
- **THEN** the store SHALL deduplicate the current audio action while retaining its bounded history policy

#### Scenario: Spatial state recovers
- **WHEN** an audio-only spatial failure returns to an active state
- **THEN** recovery SHALL clear only the current audio action and SHALL preserve transport, decoder, HDR, input, and pairing actions

### Requirement: Native UI SHALL expose actual spatial state accessibly
The stream status and Settings UI SHALL present the active runtime mode, selected preferences, and bounded fallback reason with platform-appropriate SwiftUI controls and explicit accessibility labels and values.

#### Scenario: Head tracking is active
- **WHEN** the active runtime reports observed head tracking
- **THEN** the stream status SHALL display a concise active mode whose accessibility value distinguishes it from fixed spatial playback

#### Scenario: No active stream exists
- **WHEN** settings are displayed outside a session
- **THEN** preference controls SHALL remain available while status text SHALL avoid claiming a compatible route or active graph

### Requirement: Verification SHALL preserve proof boundaries
The change SHALL pass deterministic normal, five-platform build, analyzer, sanitizer, resource, and simulator-inventory gates, while physical audible behavior remains incomplete until authorized hardware evidence exists.

#### Scenario: Offline verification passes
- **WHEN** contracts, injected graph tests, platform compilation, and resource gates succeed
- **THEN** the change MAY mark offline tasks complete but SHALL NOT mark the physical hardware task complete

#### Scenario: Physical acceptance is performed
- **WHEN** authorized AirPods, built-in speakers, nonspatial output, and multichannel hardware are exercised with redacted channel-identification evidence
- **THEN** acceptance SHALL correlate the LuneX commit, signed entitlements, route transitions, runtime state, audible result, and clean teardown
