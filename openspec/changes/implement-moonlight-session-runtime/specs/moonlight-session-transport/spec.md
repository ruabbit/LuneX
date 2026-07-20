## ADDED Requirements

### Requirement: Session state shall reflect real transport readiness
LuneX SHALL derive session state from authenticated launch, RTSP/control negotiation, and media-channel readiness and SHALL NOT report `Streaming` from a launch response alone.

#### Scenario: Launch succeeds but transport is not ready
- **WHEN** the host accepts `/launch` but RTSP or required channels have not started
- **THEN** the session SHALL remain in a connecting stage that identifies the pending transport

#### Scenario: First media path becomes operational
- **WHEN** negotiation completes and the session can receive and present valid media
- **THEN** the session SHALL transition to streaming and publish negotiated codec, resolution, frame rate, HDR, audio, and input parameters

### Requirement: The runtime shall manage session control
LuneX SHALL implement structured RTSP messages, control-channel commands, keepalive, IDR requests, termination, and bounded reconnect behavior.

#### Scenario: Packet loss requires a clean frame
- **WHEN** the video receiver detects an unrecoverable reference-frame gap
- **THEN** the runtime SHALL request an IDR without recreating the whole UI session

#### Scenario: Host stops the stream
- **WHEN** control transport reports remote termination
- **THEN** every media and input task SHALL stop and the UI SHALL report the remote reason

### Requirement: Reconnect shall preserve truth and bounds
Transient loss SHALL use bounded retries and SHALL never leave the UI in streaming state after all required channels are gone.

#### Scenario: Short network interruption recovers
- **WHEN** transport recovers within the configured retry and time budget
- **THEN** LuneX SHALL resynchronize media and return to streaming without launching a duplicate host session

#### Scenario: Reconnect budget expires
- **WHEN** required channels do not recover within the budget
- **THEN** LuneX SHALL stop all session resources, invoke remote cancellation when possible, and enter a structured failed state
