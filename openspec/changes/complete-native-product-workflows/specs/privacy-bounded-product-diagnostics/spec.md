## ADDED Requirements

### Requirement: Typed product failures
Product workflows SHALL consume typed error categories and safe presentation descriptors rather than display arbitrary `Error.localizedDescription`, provider strings, host responses, or transport payloads.

#### Scenario: Unknown provider error
- **WHEN** a provider returns an unmapped internal error
- **THEN** the UI presents a stable generic category and correlation-safe action while detailed arbitrary text remains outside user-facing state

#### Scenario: Typed failure mapping matrix
- **WHEN** host, pairing, catalog, launch, recovery, input, media, HDR, audio, or platform presentation fails
- **THEN** a closed product issue code and checked action are selected from typed context, diagnostic category, and action only, without consuming the diagnostic code, summary, endpoint, identity, or provider payload

### Requirement: Secret and identity redaction
UI state, logs, diagnostics, tests, and exports SHALL exclude PINs, private keys, certificates, pinned trust material, host endpoints, host identity, device identifiers, and authentication payloads except where an explicitly bounded local input field requires transient entry.

#### Scenario: Pairing failure export
- **WHEN** diagnostics are exported after pairing failure
- **THEN** the export contains typed stage and bounded error code but no PIN, endpoint, certificate, key, or host-provided body

### Requirement: Safe recovery actions
Every actionable diagnostic SHALL identify a finite local command whose eligibility is revalidated against current workspace and session generation at invocation time.

#### Scenario: Stale retry action
- **WHEN** the user invokes a retry action created for a replaced workspace or session generation
- **THEN** the action fails closed and cannot mutate the current owner

### Requirement: Bounded diagnostic history
Product diagnostics SHALL use an explicit retention bound, deterministic deduplication, and category-specific clearing so repeated telemetry cannot grow memory without limit or erase unrelated failures.

#### Scenario: Repeated equivalent event
- **WHEN** the same bounded event is recorded repeatedly without a material state transition
- **THEN** the store deduplicates it according to the declared policy and retains unrelated categories

### Requirement: Privacy-preserving export
The application SHALL provide a native export surface for redacted diagnostic snapshots, SHALL declare the included categories and proof tier, and SHALL not require Keychain access or live-host communication to generate the export.

#### Scenario: Offline export
- **WHEN** the user exports diagnostics while disconnected
- **THEN** a deterministic redacted snapshot is produced locally without prompting for Keychain authorization

#### Scenario: Evidence tier
- **WHEN** an export contains only offline or Simulator observations
- **THEN** its metadata does not label them as signed artifact, physical-device, or live-host proof
