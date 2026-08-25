## ADDED Requirements

### Requirement: Protocol behavior shall have deterministic fixture coverage
Pairing, RTSP, control, video packet assembly, audio packet handling, and input serialization SHALL be testable from repository-owned sanitized fixtures without requiring a live host.

#### Scenario: Fixture suite runs in CI
- **WHEN** the normal test suite executes
- **THEN** it SHALL validate parser boundaries, cryptographic verification, state transitions, malformed input handling, and teardown without contacting Keychain or a host

### Requirement: Live-host tests shall be explicit and non-destructive
End-to-end Sunshine tests SHALL run only when an explicit environment configuration identifies the host and permitted operations.

Live-host eligibility SHALL be based on server-advertised protocol/capability data and observed behavior, not a Sunshine package-version allowlist. Package version metadata MAY be recorded for reproducibility but SHALL NOT be required to start a compatible live test.

#### Scenario: Normal tests run without live configuration
- **WHEN** live-host environment variables are absent
- **THEN** every live interoperability test SHALL be skipped without network discovery, pairing, launch, or Keychain access

#### Scenario: Authorized live test runs
- **WHEN** a configured test host and credentials are provided
- **THEN** the test SHALL pair or use an isolated test identity, launch the matrix-designated non-destructive test app, prove video/audio/input operation, stop cleanly, and emit an evidence summary that excludes credentials, private keys, certificate bytes, tokens, and raw payloads

#### Scenario: Package version is unavailable or previously unseen
- **WHEN** the configured host does not expose its Sunshine package version or uses a release not previously recorded by the client
- **THEN** the test SHALL proceed from advertised capabilities and fail only on an unsupported requirement or observed interoperability failure

### Requirement: Completion claims shall follow proof gates
A build, policy unit test, launch response, or first decoded frame SHALL NOT independently count as a complete streaming workflow.

#### Scenario: Runtime completion is reported
- **WHEN** the change is marked complete
- **THEN** evidence SHALL include authenticated pairing, launch, RTSP/control readiness, sustained decoded video, audible synchronized audio, delivered input, clean stop, and no leaked session tasks
