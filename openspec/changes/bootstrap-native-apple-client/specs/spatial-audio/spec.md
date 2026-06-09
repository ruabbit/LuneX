## ADDED Requirements

### Requirement: Audio pipeline shall be low-latency and session-scoped

The client SHALL decode and play stream audio with a session-scoped audio engine whose lifecycle follows session state.

#### Scenario: Stream starts with audio enabled
- **WHEN** a streaming session reaches media playback
- **THEN** the audio engine SHALL start with the negotiated sample rate, channel layout, and latency policy

#### Scenario: Stream stops
- **WHEN** the session stops
- **THEN** audio playback SHALL drain or stop according to the stop reason and release session resources

### Requirement: Spatial audio shall be capability-gated

The client SHALL expose spatial audio only when platform, route, entitlement, and channel-layout requirements are satisfied.

#### Scenario: Head tracking is available
- **WHEN** a compatible route and required entitlement are available
- **THEN** the audio engine SHALL enable listener head tracking when the user setting is enabled

#### Scenario: Head tracking is unavailable
- **WHEN** entitlement or hardware support is missing
- **THEN** the app SHALL keep playback functional and show the unavailable reason in diagnostics/settings
