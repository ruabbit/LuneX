## ADDED Requirements

### Requirement: Host-centric library navigation
The macOS library window SHALL organize primary navigation around hosts: the collapsible, adaptive sidebar SHALL list hosts (not screen categories), and the content area SHALL present the selected host's application catalog without being constrained below the minimum supported layout. The application SHALL NOT present Library, Stream, Diagnostics, or Settings as permanent sidebar destinations on macOS.

#### Scenario: Window opens with saved hosts
- **WHEN** a macOS library window opens and persisted hosts exist
- **THEN** the sidebar lists those hosts, exactly one host is selected, and the content area presents that host's catalog or its required contextual flow
- **AND** no sidebar row navigates to a Stream, Diagnostics, or Settings screen

#### Scenario: Automatic host selection follows launch readiness
- **WHEN** a workspace has no valid explicit host selection or its provisional automatic selection is reconciled after reachability resolves
- **THEN** the shell prefers an online paired host, then another online host, then a paired host still being checked, followed by a deterministic fallback
- **AND** an explicit user-selected host remains selected while it exists even if it is offline

#### Scenario: No hosts exist
- **WHEN** the library loads with zero hosts
- **THEN** automatic discovery remains active, the content area presents a first-use state offering manual host entry, and the sidebar presents an add-host affordance
- **AND** an explicit discovery retry appears only after discovery reports a failure

#### Scenario: Host management is contextual
- **WHEN** the user opens a host row's context menu
- **THEN** pairing, trust reset, and removal are available with their existing confirmations, and the shell presents no permanent always-visible button row for these actions

### Requirement: Honest host status presentation
Host rows SHALL present automatically reconciled reachability as a bounded checking/online/offline indicator distinct from pairing state, SHALL surface pairing state only when it requires action, and SHALL NOT present duplicate or steady-state-unknown status text. Normal library use SHALL NOT require a visible refresh button.

Discovery SHALL merge a uniquely matching saved host by canonical address or normalized host name, add the discovered address without replacing existing addresses, and preserve pairing and pinned trust. If an earlier discovery pass created an unpaired same-name duplicate beside one uniquely trusted saved host, a subsequent matching discovery event SHALL collapse the duplicate into the trusted host instead of presenting two ambiguous rows. Multiple trusted hosts with the same name SHALL remain distinct unless an address matches.

#### Scenario: Discovery enriches an imported paired host without duplicating it
- **WHEN** a paired saved host uses a numeric or VPN address and Bonjour discovers the same uniquely named host at a `.local` address
- **THEN** the library keeps the paired host identity, appends the mDNS address, and presents one online host row

#### Scenario: Same-name collisions do not merge two trusted hosts
- **WHEN** more than one paired or pinned saved host has the same normalized name and no canonical address matches the discovery event
- **THEN** discovery does not merge either trusted host based on name alone

#### Scenario: Reachability before first result
- **WHEN** a host's reachability has not yet been determined
- **THEN** the row presents a checking state rather than the literal text "Unknown", and resolves to online or offline within the bounded reconciliation interval

#### Scenario: Paired host row
- **WHEN** a host is paired
- **THEN** the row does not add a textual "Paired" label duplicating an icon; an unpaired host is marked with a single affordance indicating pairing is required

### Requirement: Direct application launch
The macOS catalog SHALL make launching an application a direct action on its tile — double-click and keyboard Return on the selected tile SHALL launch through the existing session command path — and the launch affordance SHALL be reachable without scrolling at the minimum supported window size. The shell SHALL NOT devote a permanent panel to launch parameters; the effective stream summary (mode, bitrate, HDR) SHALL be available at the launch point or in the active-session presentation.

#### Scenario: Reachable paired host is selected
- **WHEN** the user selects a paired host that resolves online
- **THEN** its catalog loads or refreshes automatically without a normal-use refresh action
- **AND** explicit retry is presented only if the automatic catalog operation fails

#### Scenario: Launch by double-click
- **WHEN** the selected host is paired and reachable and the user double-clicks an app tile (or presses Return on the selected tile)
- **THEN** the existing launch workflow starts for that app without visiting any other screen

#### Scenario: Launch is not launch-ready
- **WHEN** the selected host is offline or the catalog is cached-only
- **THEN** tiles present a non-launchable state and launch attempts are rejected by the existing command availability, with the reason presented at the tile or catalog level

#### Scenario: Selection has one visual expression
- **WHEN** an app tile is selected
- **THEN** selection is expressed by a single accent treatment, tiles keep uniform dimensions, and no in-tile "Selected" caption is added

### Requirement: Contextual pairing flow
The macOS shell SHALL present pairing in the content area only while the selected host is unpaired or a pairing attempt is active, mapping every `ProductPairingSurface` phase to that single view, and SHALL return to the catalog automatically when pairing completes. Completed or cancelled pairing SHALL NOT persist as an ambient status panel.

#### Scenario: Unpaired host selected
- **WHEN** the user selects an unpaired host
- **THEN** the content area presents the pairing flow with a primary start action instead of an app catalog

#### Scenario: PIN stage prominence
- **WHEN** a pairing attempt reaches the waiting-for-PIN stage
- **THEN** the PIN presentation/entry is the visually dominant element of the content area with cancel available, reusing the existing attempt-generation ownership

#### Scenario: Pairing completes
- **WHEN** the active pairing attempt completes successfully
- **THEN** the content area transitions to that host's catalog without a persistent "Pairing complete" panel remaining anywhere in the shell

### Requirement: Session-owned stream surface
While a workspace's session is active, connecting, or recoverable, the stream surface plus its overlay SHALL own the full content of the owning macOS window; when the session ends, the window SHALL return to the library presentation automatically. When no session exists the shell SHALL NOT expose a navigable stream destination or render a blank stream region.

#### Scenario: Launch takes over the window
- **WHEN** a stream session starts in a window
- **THEN** that window's content becomes the stream surface with the existing overlay controls, and library chrome does not compete with the video

#### Scenario: Disconnect returns to library
- **WHEN** the session stops, tears down, or fails without recovery
- **THEN** the window returns to the library presentation for the previously selected host without manual navigation

#### Scenario: No session, no black screen
- **WHEN** no session exists in a window
- **THEN** no user action inside that window can present an empty black stream area

#### Scenario: Session commands are session-scoped
- **WHEN** a window has no session
- **THEN** its toolbar and menus present no disabled session-only placeholder controls; session commands appear or enable only while a session exists

### Requirement: Native macOS settings surface
macOS SHALL present settings through the native Settings scene (App menu, Cmd+,) using grouped form styling; changes SHALL persist immediately without a save button. Resolution and frame rate SHALL be selected from named presets (including a display-derived native option and a custom representation for previously persisted arbitrary values), bitrate SHALL use a slider with an Mbps readout, and macOS settings SHALL NOT include mobile-only status rows.

#### Scenario: Opening settings
- **WHEN** the user presses Cmd+, or chooses Settings from the application menu
- **THEN** the settings window opens with grouped macOS form styling and no in-window sidebar destination duplicates it

#### Scenario: Immediate persistence
- **WHEN** the user changes any setting
- **THEN** the change is applied and persisted through the existing settings path without requiring a save action

#### Scenario: Preset round-trip
- **WHEN** a persisted configuration contains a width/height/frame-rate combination matching no named preset
- **THEN** the settings present it as a custom value without altering the stored configuration

#### Scenario: macOS scope
- **WHEN** settings render on macOS
- **THEN** Scene, Picture in Picture, and Background continuity status rows are absent, while HDR output and spatial audio actual-state rows remain bounded and compact

### Requirement: On-demand diagnostics
macOS SHALL open diagnostics on demand from the Window menu (or an equivalent explicit affordance) as its own surface reusing the existing diagnostics content and privacy-safe export, not as a permanent sidebar destination.

#### Scenario: Opening diagnostics
- **WHEN** the user invokes the diagnostics menu item
- **THEN** the diagnostics surface opens with current runtime state and export, and closing it returns focus to the library window unchanged

### Requirement: macOS control-idiom fidelity
The macOS shell SHALL reserve keyboard focus rings for interactive controls, SHALL NOT make non-interactive containers focusable, and SHALL use native selection, list, and form idioms rather than custom flat panels for primary surfaces. Existing accessibility labels, keyboard shortcuts, Reduce Motion behavior, and per-window workspace isolation SHALL be preserved through the redesign.

#### Scenario: Focus traversal
- **WHEN** the user tabs through the library window
- **THEN** focus visits interactive controls only and no container-sized focus ring appears around informational panels

#### Scenario: Frozen platforms unaffected
- **WHEN** the macOS shell changes land
- **THEN** iOS/iPadOS, tvOS, and visionOS targets still compile with their existing navigation and presentation, receiving only the minimum shared-code adjustments

#### Scenario: Multiwindow isolation
- **WHEN** two macOS library windows are open
- **THEN** each window keeps its own host selection, contextual flow, and session-owned presentation without cross-window mutation
