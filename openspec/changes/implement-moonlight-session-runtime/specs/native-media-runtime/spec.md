## ADDED Requirements

### Requirement: Video shall use a native hardware decode path
LuneX SHALL receive negotiated video packets, rebuild codec access units, configure VideoToolbox for the negotiated H.264, HEVC, or AV1 stream where supported, and deliver decoded pixel buffers to Metal without unnecessary CPU copies.

#### Scenario: Decoder receives valid format data
- **WHEN** complete codec parameter sets and an IDR are available
- **THEN** LuneX SHALL create or update the decompression session and present the first valid frame

#### Scenario: Format changes during a session
- **WHEN** codec parameters, resolution, bit depth, or HDR metadata change
- **THEN** LuneX SHALL drain and recreate affected decode/render resources without presenting frames under stale metadata

### Requirement: Audio shall be decoded, synchronized, and route-aware
LuneX SHALL decode the negotiated Moonlight audio format, schedule PCM through a session-owned audio engine, and maintain bounded audio/video synchronization.

#### Scenario: Audio route changes
- **WHEN** the active output route or channel layout changes
- **THEN** LuneX SHALL rebuild the affected audio format and publish the new route without leaking the prior engine graph

#### Scenario: Audio packets arrive late
- **WHEN** jitter exceeds the configured latency budget
- **THEN** LuneX SHALL apply a documented drop, concealment, or resynchronization policy and record a diagnostic

### Requirement: Media teardown shall release expensive resources
The runtime SHALL invalidate network receivers, decompression sessions, texture caches, audio nodes, timers, and queued frames when a session stops.

#### Scenario: User disconnects
- **WHEN** the user requests disconnect
- **THEN** media presentation SHALL stop promptly and resource ownership tests SHALL observe no surviving session tasks
