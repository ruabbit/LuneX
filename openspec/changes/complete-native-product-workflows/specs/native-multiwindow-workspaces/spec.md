## ADDED Requirements

### Requirement: Checked workspace identity
Each macOS and iPadOS window SHALL own a stable workspace identifier and a monotonic generation used to validate navigation, selected host, catalog, pairing presentation, session commands, and async results.

#### Scenario: New window
- **WHEN** the user creates a second supported window
- **THEN** it receives a distinct workspace identifier and independent navigation and host selection

#### Scenario: Workspace replacement
- **WHEN** a scene reconnects with a replacement generation
- **THEN** async results from the prior generation cannot mutate the replacement workspace

#### Scenario: Native scene restoration
- **WHEN** a disconnected supported scene reconnects with its serialized workspace identifier
- **THEN** the scene restores durable navigation, host, and app values at the next generation while transient presentation is cleared

#### Scenario: Duplicate active scene identity
- **WHEN** a second live scene presents an identifier already attached to another live scene
- **THEN** attachment fails closed before replacing or mutating the current workspace generation

### Requirement: Session ownership isolation
An active session SHALL have one checked workspace owner, and a non-owning window SHALL not stop, reconnect, present controls for, or claim input for that session without an explicit transfer contract.

#### Scenario: Non-owner stop command
- **WHEN** a second window requests stop for a session it does not own
- **THEN** the command fails closed with a typed local action and the owning session remains unchanged

#### Scenario: Owner window closes
- **WHEN** the owning window closes during an active session
- **THEN** the application follows the declared close policy to retain or stop the session without silently transferring ownership

#### Scenario: Owner window retains another presentation
- **WHEN** the owning scene closes while another attachment for the same workspace or actual current-session picture-in-picture/audio-only continuity remains
- **THEN** the session retains its original checked owner without assigning ownership to another workspace

#### Scenario: Owner window requires clean stop
- **WHEN** the owning scene closes while launching, streaming, or reconnecting and no declared retained presentation remains
- **THEN** the application reserves the existing owner-keyed stop operation before detaching and awaits clean teardown

#### Scenario: Owner window closes during stop
- **WHEN** the owning scene closes after the same owner has already begun stopping
- **THEN** the close joins the in-flight stop operation rather than creating another session teardown

#### Scenario: Stale scene close
- **WHEN** a replaced or otherwise stale scene attachment closes after a replacement workspace or session becomes current
- **THEN** the close fails closed without detaching the replacement or stopping its session

### Requirement: Window-local presentation state
Transient presentation state including sheets, confirmation dialogs, navigation selection, overlay visibility, validation, and retry state SHALL be stored per workspace rather than globally.

#### Scenario: Pairing sheet isolation
- **WHEN** one window presents or cancels pairing UI
- **THEN** other windows do not present, dismiss, or inherit that transient state

#### Scenario: Host selection isolation
- **WHEN** one window selects another host
- **THEN** another window's selected host and visible catalog remain unchanged

#### Scenario: Scene-local workflow binding
- **WHEN** a supported scene changes navigation, presents Add Host, validates input, retries a workflow, or opens a confirmation dialog
- **THEN** the action reads and mutates only that scene's checked workspace presentation and selection state

#### Scenario: Replaced scene binding
- **WHEN** a view attempts to mutate navigation, selection, sheet, or dialog state through a replaced workspace generation
- **THEN** the mutation fails closed without changing the replacement workspace or another live scene

### Requirement: Shared data consistency
Host records, trust state, cached apps, and settings SHALL remain shared repository data, and repository mutations SHALL publish reconciled updates to every live workspace without copying session ownership.

#### Scenario: Host removed elsewhere
- **WHEN** a host is removed from one inactive workspace
- **THEN** all workspaces remove that shared record and independently select a valid fallback or empty state

#### Scenario: Shared trust mutation
- **WHEN** pairing succeeds or trust is reset for a host selected in multiple workspaces
- **THEN** every workspace observes the shared trust record, stale matching pairing presentation is cleared, and only the initiating pairing owner may publish its completed state

#### Scenario: Shared catalog and settings mutation
- **WHEN** one workspace persists a catalog or settings change
- **THEN** every live workspace observes the same shared value while retaining its local navigation, sheet, dialog, validation, and retry presentation

#### Scenario: Reconciliation during an unrelated session
- **WHEN** an inactive workspace mutates a host that does not own another workspace's active session
- **THEN** shared data is reconciled without stopping, replacing, or transferring the active session owner

### Requirement: Unsupported multiwindow behavior
Platforms or configurations without product multiwindow support SHALL use one workspace without exposing nonfunctional window commands, while preserving the same checked ownership contracts internally.

#### Scenario: Unsupported runtime configuration
- **WHEN** the native scene environment reports that multiple windows are unsupported
- **THEN** external scene restoration identity is ignored and the checked primary workspace remains the only workspace

#### Scenario: tvOS root scene
- **WHEN** LuneX runs on tvOS
- **THEN** the root scene uses a single checked workspace and does not advertise create-window behavior
