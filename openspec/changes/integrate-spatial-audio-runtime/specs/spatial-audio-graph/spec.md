## ADDED Requirements

### Requirement: Negotiated audio SHALL have an explicit channel layout
The client SHALL resolve negotiated Moonlight audio to an immutable semantic channel layout before decoder and engine creation, and SHALL reject channel configurations whose speaker order cannot be represented truthfully.

#### Scenario: Stereo layout is negotiated
- **WHEN** the negotiated stream contains two channels in Moonlight left/right order
- **THEN** the runtime SHALL use an explicit stereo Core Audio layout with the same order

#### Scenario: Surround layout is negotiated
- **WHEN** the negotiated stream contains six or eight channels in the Moonlight WAVE order
- **THEN** the runtime SHALL use the matching 5.1 or 7.1 WAVE layout without silently swapping rear and side channels

#### Scenario: Ambiguous channel count is negotiated
- **WHEN** a negotiated channel count has no supported immutable speaker layout
- **THEN** audio configuration SHALL fail closed before audible scheduling

### Requirement: Spatial playback SHALL use the session-owned engine graph
The production audio engine owner SHALL attach and connect the player, environment, mixer, and output nodes used by decoded session PCM; a disconnected controller or property-only adapter SHALL NOT be reported as active spatial playback.

#### Scenario: Eligible multichannel audio starts
- **WHEN** a valid spatial-eligible stream is configured on a supported graph
- **THEN** decoded PCM SHALL be scheduled on the player connected through the active environment node to the output graph

#### Scenario: Mono audio starts
- **WHEN** a valid mono stream is configured
- **THEN** the runtime SHALL use a nonspatial mixer path and report the channel-layout limitation

### Requirement: Multichannel game audio SHALL preserve ambience-bed semantics
The environment graph SHALL render labeled stereo and surround input as an ambience bed and SHALL NOT collapse the whole input bus into one point source.

#### Scenario: 7.1 bed is configured
- **WHEN** the graph accepts a valid 7.1 WAVE input format
- **THEN** the player source mode SHALL be ambience-bed and the selected rendering algorithm SHALL be applicable to the connected environment output

#### Scenario: Environment rendering is unavailable
- **WHEN** the current graph cannot apply a supported spatial rendering algorithm
- **THEN** the runtime SHALL select a typed nonspatial PCM fallback or fail closed without falsely reporting spatial activation

### Requirement: PCM scheduling SHALL remain bounded and generation-owned
Spatial graph insertion SHALL preserve existing PCM validation, scheduled-buffer capacity, completion ownership, media-clock observation, and teardown semantics.

#### Scenario: Valid current-generation PCM arrives
- **WHEN** decoded PCM matches the active sample rate, channel layout, and generation
- **THEN** the runtime SHALL schedule it exactly once and release its capacity only from the matching completion generation

#### Scenario: Graph is rebuilt with buffers pending
- **WHEN** route or interruption recovery replaces the graph
- **THEN** the runtime SHALL invalidate pending-buffer ownership so late completions cannot mutate the rebuilt graph

### Requirement: Graph resources SHALL be released deterministically
Stop, failure, reconfiguration, and replacement SHALL detach or reset graph state, cancel playback, clear configuration, and deactivate platform audio-session declarations without leaking player, environment, engine, or scheduled-buffer ownership.

#### Scenario: Session stops cleanly
- **WHEN** the active media session is stopped
- **THEN** the audio graph SHALL stop once, clear pending scheduling state, release session resources, and remain idempotently stopped

#### Scenario: Configuration fails partway
- **WHEN** layout, connection, platform-session, or algorithm configuration throws
- **THEN** the partially configured graph SHALL be atomically cleaned and SHALL publish no active spatial state
