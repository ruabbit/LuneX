## ADDED Requirements

### Requirement: macOS window visibility shall drive render policy

The macOS client SHALL observe stream window visibility and key-window state using AppKit notifications and SHALL publish a render policy that distinguishes visible, fully occluded, minimized, background, focused, and unfocused states.

#### Scenario: Window becomes fully occluded
- **WHEN** the active stream window receives an occlusion-state change and its occlusion state no longer contains visible
- **THEN** the render policy SHALL pause or throttle expensive presentation work while keeping the network session state explicit

#### Scenario: Window becomes visible again
- **WHEN** an occluded stream window becomes visible
- **THEN** the render policy SHALL resume presentation and request a fresh drawable-size/display-headroom evaluation before rendering the next frame

#### Scenario: Stream window loses key status
- **WHEN** the stream window resigns key status
- **THEN** local system cursor behavior SHALL return to the platform default unless an active capture mode requires otherwise

#### Scenario: Stream window becomes key
- **WHEN** the stream window becomes key and remote pointer mode is active
- **THEN** the client SHALL hide or capture the local pointer according to the selected input mode

### Requirement: macOS display changes shall update stream geometry

The macOS client SHALL observe display configuration changes, stream-window screen changes, backing-scale changes, and resize completion to keep remote input scaling and render size aligned with the actual display.

#### Scenario: Display configuration changes
- **WHEN** the system posts a screen-parameter change
- **THEN** the client SHALL recompute screen bounds, backing scale, refresh metadata, EDR headroom, and remote pointer coordinate mapping

#### Scenario: Window moves to another screen
- **WHEN** the stream window changes its screen
- **THEN** the renderer SHALL update drawable size and screen metadata before presenting subsequent frames

### Requirement: iPadOS and iOS scene geometry shall drive render sizing

The iOS and iPadOS clients SHALL track scene phase, view geometry, trait changes, safe areas, and multi-window resizing where supported.

#### Scenario: iPad window is resized
- **WHEN** an iPadOS stream scene changes size
- **THEN** the client SHALL update drawable pixel size, remote aspect-fit/fill policy, and touch/pointer coordinate mapping

#### Scenario: Mobile scene becomes inactive
- **WHEN** the stream scene moves from active to inactive or background
- **THEN** the session SHALL enter the configured continuity policy rather than silently continuing full-rate rendering

### Requirement: tvOS and visionOS lifecycle shall be explicit

The tvOS and visionOS clients SHALL expose platform lifecycle states to the shared session core even when a platform does not support the same window APIs as macOS or iPadOS.

#### Scenario: Platform lacks key-window semantics
- **WHEN** a platform adapter cannot provide a macOS-style key-window event
- **THEN** it SHALL publish the closest platform focus/activation state with source metadata
