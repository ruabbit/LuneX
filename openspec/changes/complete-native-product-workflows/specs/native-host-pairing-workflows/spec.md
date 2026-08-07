## ADDED Requirements

### Requirement: First-use host workflow
The application SHALL present a usable native host workflow when no persisted host exists, and SHALL allow discovery refresh or manual entry without requiring a tutorial or placeholder screen.

#### Scenario: Empty library
- **WHEN** initial state contains no hosts
- **THEN** the library presents actions to refresh discovery and add a host manually

#### Scenario: Restored library
- **WHEN** persisted hosts are loaded
- **THEN** the application restores the library without forcing first-use presentation over existing data

### Requirement: Validated manual host entry
The application SHALL normalize and validate manual host input before persistence, SHALL preserve IPv4, IPv6, hostname, and explicit port forms supported by `HostEndpoint`, and SHALL expose a typed correction without echoing credentials or URL user information.

#### Scenario: Valid endpoint
- **WHEN** the user submits a supported endpoint with surrounding whitespace
- **THEN** the application persists the normalized endpoint and selects the resulting host

#### Scenario: Invalid endpoint
- **WHEN** the user submits an empty, ambiguous, credential-bearing, or unsupported endpoint
- **THEN** the sheet remains open and presents a field-associated typed validation message

### Requirement: Pairing attempt ownership
The application SHALL bind every pairing attempt to one host and one attempt generation, SHALL accept only a four-digit ASCII PIN in the waiting-for-PIN stage, and SHALL reject late progress or completion from cancelled or replaced attempts.

#### Scenario: Cancel pairing
- **WHEN** the user cancels an active pairing attempt
- **THEN** attempt ownership is invalidated before provider cancellation and late events cannot change UI or trust state

#### Scenario: Retry pairing
- **WHEN** a failed attempt is retried
- **THEN** a new attempt generation starts with cleared PIN and failure presentation while the prior generation remains ineligible

### Requirement: Destructive host and trust actions
The application SHALL require explicit confirmation before host removal or trust reset, SHALL describe the local consequence without exposing trust material, and SHALL prevent the action from silently orphaning an owned active session.

#### Scenario: Remove inactive host
- **WHEN** the user confirms removal of a host that owns no active session
- **THEN** the host, cached catalog, and local trust association are removed through the existing repositories

#### Scenario: Remove active host
- **WHEN** the selected host owns an active or transitioning session
- **THEN** the application requires an explicit stop-and-remove action and completes session teardown before repository removal

#### Scenario: Reset trust
- **WHEN** the user confirms trust reset for a paired inactive host
- **THEN** pairing state and pinned trust are cleared while unrelated hosts remain unchanged

### Requirement: App catalog recovery
The application SHALL distinguish loading, empty, cached, failed, and current catalog states and SHALL provide a retry action that remains bound to the selected host generation.

#### Scenario: Empty catalog
- **WHEN** a paired reachable host returns a valid empty app list
- **THEN** the application presents an empty state rather than a transport failure

#### Scenario: Stale response after host switch
- **WHEN** a catalog response completes after selection changed to another host
- **THEN** it cannot replace the visible catalog or action state for the new selection

#### Scenario: Catalog failure
- **WHEN** catalog refresh fails
- **THEN** cached apps remain distinguishable from current data and a typed retry action is available
