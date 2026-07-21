## ADDED Requirements

### Requirement: macOS input capture shall be scoped to the active stream view
LuneX SHALL capture supported keyboard, pointer, button, and scroll events only from the attached stream view while its session generation is active and input admission is enabled.

#### Scenario: Focused stream view receives input
- **WHEN** the active stream view is visible, key, first responder, and configured for remote input
- **THEN** supported AppKit samples SHALL be converted to typed events and delivered in acceptance order to that session generation

#### Scenario: Detached or stale view emits an event
- **WHEN** an event arrives from a detached view or an earlier session generation
- **THEN** LuneX SHALL reject it without sending, changing held-state ownership, or affecting the replacement session

### Requirement: Keyboard and system shortcut handling shall remain explicit
LuneX SHALL preserve key-down, key-up, modifier, repeat, and character information and SHALL keep reserved macOS shortcuts local unless a supported forwarding policy explicitly allows them.

#### Scenario: Remote key transition is accepted
- **WHEN** a supported non-reserved key transition occurs in the focused stream view
- **THEN** the transition SHALL be enqueued once with its modifier and repeat state for authenticated remote delivery

#### Scenario: Reserved shortcut is pressed
- **WHEN** a shortcut reserved by the current local policy is pressed
- **THEN** the event SHALL remain local and SHALL NOT enter remote held-state ownership

### Requirement: Cursor capture shall be balanced and reversible
LuneX SHALL hide and disassociate the system cursor only while active relative remote-pointer policy requires capture, and SHALL restore only state that LuneX itself changed.

#### Scenario: Relative remote pointer becomes eligible
- **WHEN** the active stream view becomes visible and focused with relative remote-pointer mode enabled
- **THEN** LuneX SHALL hide the cursor and enable relative capture exactly once

#### Scenario: Capture eligibility ends
- **WHEN** focus, visibility, session, mode, attachment, or input-channel state no longer permits capture
- **THEN** LuneX SHALL immediately stop admission and restore cursor visibility and association exactly once

### Requirement: Focus loss shall release remote held state through an ordered barrier
LuneX SHALL stop accepting new platform events and SHALL release held remote keys, pointer buttons, and controller state for the active generation when the stream window loses key status or the application resigns active.

#### Scenario: Window resigns key with held input
- **WHEN** focus is lost after accepted state transitions
- **THEN** LuneX SHALL finish accepted deliveries, execute one shared `releaseAll` barrier, restore the cursor, and reject later events until focus eligibility returns

#### Scenario: Focus loss races session replacement
- **WHEN** a focus-release operation suspends while a replacement session becomes active
- **THEN** the old operation SHALL NOT release, disable, or restore input state owned by the replacement generation

### Requirement: Input failure and teardown shall converge without surviving capture
Input send failure, channel failure, local stop, remote termination, and view dismantle SHALL close platform admission and converge on idempotent cursor and held-state cleanup.

#### Scenario: Remote input send fails
- **WHEN** the active provider rejects an accepted platform event
- **THEN** LuneX SHALL publish a safe typed diagnostic, close capture for that generation, clear local ownership through the existing provider failure path, and restore the system cursor

#### Scenario: Stop is requested more than once
- **WHEN** multiple teardown triggers target the same generation
- **THEN** LuneX SHALL execute one effective capture cleanup and SHALL leave no event consumer or cursor ownership behind
