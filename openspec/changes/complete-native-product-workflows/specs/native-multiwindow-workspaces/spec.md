## ADDED Requirements

### Requirement: Checked workspace identity
Each macOS and iPadOS window SHALL own a stable workspace identifier and a monotonic generation used to validate navigation, selected host, catalog, pairing presentation, session commands, and async results.

#### Scenario: New window
- **WHEN** the user creates a second supported window
- **THEN** it receives a distinct workspace identifier and independent navigation and host selection

#### Scenario: Workspace replacement
- **WHEN** a scene reconnects with a replacement generation
- **THEN** async results from the prior generation cannot mutate the replacement workspace

### Requirement: Session ownership isolation
An active session SHALL have one checked workspace owner, and a non-owning window SHALL not stop, reconnect, present controls for, or claim input for that session without an explicit transfer contract.

#### Scenario: Non-owner stop command
- **WHEN** a second window requests stop for a session it does not own
- **THEN** the command fails closed with a typed local action and the owning session remains unchanged

#### Scenario: Owner window closes
- **WHEN** the owning window closes during an active session
- **THEN** the application follows the declared close policy to retain or stop the session without silently transferring ownership

### Requirement: Window-local presentation state
Transient presentation state including sheets, confirmation dialogs, navigation selection, overlay visibility, validation, and retry state SHALL be stored per workspace rather than globally.

#### Scenario: Pairing sheet isolation
- **WHEN** one window presents or cancels pairing UI
- **THEN** other windows do not present, dismiss, or inherit that transient state

#### Scenario: Host selection isolation
- **WHEN** one window selects another host
- **THEN** another window's selected host and visible catalog remain unchanged

### Requirement: Shared data consistency
Host records, trust state, cached apps, and settings SHALL remain shared repository data, and repository mutations SHALL publish reconciled updates to every live workspace without copying session ownership.

#### Scenario: Host removed elsewhere
- **WHEN** a host is removed from one inactive workspace
- **THEN** all workspaces remove that shared record and independently select a valid fallback or empty state

### Requirement: Unsupported multiwindow behavior
Platforms or configurations without product multiwindow support SHALL use one workspace without exposing nonfunctional window commands, while preserving the same checked ownership contracts internally.

#### Scenario: tvOS root scene
- **WHEN** LuneX runs on tvOS
- **THEN** the root scene uses a single checked workspace and does not advertise create-window behavior
