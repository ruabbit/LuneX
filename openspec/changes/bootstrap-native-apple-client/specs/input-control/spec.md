## ADDED Requirements

### Requirement: Pointer input shall support remote and local modes

The client SHALL support direct mouse, relative mouse, and touch-derived pointer modes where platform APIs allow.

#### Scenario: Direct mouse mode is active
- **WHEN** the user moves a local pointer over the stream view
- **THEN** the client SHALL map local coordinates into remote desktop coordinates using the current render transform

#### Scenario: Relative mouse mode is active
- **WHEN** relative pointer capture is active
- **THEN** the client SHALL send movement deltas and keep local cursor visibility consistent with platform focus rules

### Requirement: Keyboard input shall support game and desktop use

The client SHALL translate local keyboard input into remote key events and SHALL provide a policy for system shortcut capture on platforms that allow it.

#### Scenario: Stream window is focused on macOS
- **WHEN** the stream window is key and keyboard capture is enabled
- **THEN** the client SHALL forward supported key presses to the remote session and keep unsupported system-reserved shortcuts visible in diagnostics

### Requirement: Touch and virtual controls shall support iOS gameplay

The iOS and iPadOS clients SHALL provide touch, gesture, and configurable on-screen controller overlays.

#### Scenario: User enables virtual controller
- **WHEN** a mobile stream starts with virtual controls enabled
- **THEN** the overlay SHALL render controls without resizing the stream surface and SHALL send matching controller events

### Requirement: Game controllers and remotes shall be first-class inputs

The client SHALL use GameController APIs to support controllers across Apple platforms and remote/focus behavior on tvOS.

#### Scenario: Controller connects during a session
- **WHEN** a compatible controller connects
- **THEN** the app SHALL bind it to the active stream and publish controller status in the overlay or diagnostics
