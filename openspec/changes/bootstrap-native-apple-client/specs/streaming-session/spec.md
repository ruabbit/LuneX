## ADDED Requirements

### Requirement: Client shall manage Moonlight-compatible hosts

The app SHALL support adding, discovering, pairing, refreshing, and removing Moonlight-compatible hosts.

#### Scenario: Host discovery finds a compatible host
- **WHEN** discovery receives a compatible host advertisement or response
- **THEN** the host list SHALL show the host with reachability, pairing state, and last-seen metadata

#### Scenario: User pairs a host
- **WHEN** the user starts pairing with an unpaired host
- **THEN** the client SHALL run the pairing flow, persist client identity material securely, and update pairing state on success or failure

### Requirement: Client shall list and launch remote apps

The app SHALL fetch remote app metadata from paired hosts and allow the user to start a streaming session for a selected app or desktop.

#### Scenario: App list refresh succeeds
- **WHEN** a paired host returns an app list
- **THEN** the UI SHALL display apps with stable identifiers, names, and artwork where available

#### Scenario: User starts a stream
- **WHEN** the user selects a host app and confirms stream settings
- **THEN** the session core SHALL negotiate stream parameters and transition through connecting, streaming, stopping, and disconnected states

### Requirement: Session state shall be observable and recoverable

The session core SHALL expose deterministic state transitions, structured errors, diagnostics, and user-initiated stop/retry actions.

#### Scenario: Network failure occurs during stream
- **WHEN** the stream transport fails
- **THEN** the session SHALL publish an error with failed subsystem metadata and present retry/stop options without losing saved host configuration

#### Scenario: User stops stream
- **WHEN** the user stops an active session
- **THEN** the client SHALL send the appropriate termination/control command where supported and release renderer, input, and audio resources
