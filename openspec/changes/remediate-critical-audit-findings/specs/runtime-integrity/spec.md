## ADDED Requirements

### Requirement: Placeholder pairing shall fail closed
The application SHALL NOT mark a host paired or replace a pinned host identity unless a real server-authenticated pairing exchange succeeds.

#### Scenario: Pairing transport is unavailable
- **WHEN** the user attempts to pair while real pairing transport is unavailable
- **THEN** the application SHALL preserve the host pairing state and pinned identity and SHALL present an unavailable explanation

#### Scenario: Existing paired host is selected
- **WHEN** a host already has a pinned identity
- **THEN** the application SHALL NOT offer a placeholder action that can overwrite that identity

### Requirement: Streaming state shall represent active transport
The application SHALL report `Streaming` only after a real media transport has started successfully.

#### Scenario: Transport implementation is unavailable
- **WHEN** the user attempts to launch a stream without a transport implementation
- **THEN** the application SHALL NOT send a launch request and SHALL remain disconnected with an actionable explanation

### Requirement: Imported test data shall not duplicate private keys
The Moonlight-qt import workflow SHALL NOT write private-key material into plaintext fixture files by default.

#### Scenario: Default import runs
- **WHEN** the importer reads Moonlight-qt preferences
- **THEN** it SHALL write host, settings, and app-cache fixtures without writing client private-key material

#### Scenario: Legacy generated identity fixture exists
- **WHEN** the default importer runs and finds its legacy plaintext identity output
- **THEN** it SHALL remove that derived file without modifying the authoritative Moonlight-qt preferences
