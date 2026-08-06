## ADDED Requirements

### Requirement: visionOS window state SHALL come from the actual stream surface
The visionOS runtime SHALL derive current window scene, attachment, visibility,
focus eligibility, bounds, scale, and drawable geometry only from the actual
windowed stream surface under one checked generation.

#### Scenario: Windowed surface attaches
- **WHEN** the stream Metal view attaches to an active visionOS window
- **THEN** LuneX SHALL publish a finite current-generation geometry and lifecycle snapshot

#### Scenario: Old window callback arrives
- **WHEN** an old attachment emits after window or session replacement
- **THEN** LuneX SHALL reject it without changing current presentation or input

### Requirement: visionOS geometry SHALL synchronize rendering and input
One normalized semantic revision SHALL drive drawable sizing, video fit/fill,
and supported indirect or absolute input mapping. Detached or invalid geometry
SHALL suppress presentation and input.

#### Scenario: Window resizes
- **WHEN** the user changes the window size continuously
- **THEN** LuneX SHALL deduplicate equivalent snapshots and use the same final revision for rendering and input

### Requirement: visionOS system interaction SHALL remain reserved
LuneX SHALL keep system gestures, recentering, capture, safety, volume, and
platform escape behavior local. LuneX SHALL NOT synthesize or forward an
unsupported gaze, hand, or system gesture as Moonlight input.

#### Scenario: Unsupported spatial gesture occurs
- **WHEN** the platform reports interaction that has no public supported LuneX mapping
- **THEN** LuneX SHALL reserve or drop it locally with typed bounded state

### Requirement: Supported visionOS input SHALL be capability gated
Controller, keyboard, pointer, and indirect input SHALL be admitted only when a
public adapter reports support and the current session/input/surface generation
is active and focused.

#### Scenario: Controller is active
- **WHEN** a supported controller is leased to the current focused stream
- **THEN** LuneX SHALL use the existing controller registry and ordered delivery contract

#### Scenario: Window loses focus
- **WHEN** the stream window loses input eligibility
- **THEN** LuneX SHALL close admission and release held input before local navigation resumes

### Requirement: visionOS input ownership SHALL teardown deterministically
LuneX SHALL cancel observer tokens, controller handlers, keyboard/pointer
monitors, held state, and surface leases idempotently on replacement and stop.

#### Scenario: Stop repeats
- **WHEN** stop or detach is requested more than once
- **THEN** LuneX SHALL perform at most one release/teardown operation and leave no current input owner

### Requirement: visionOS window/input UI SHALL expose actual bounded state
Native UI SHALL distinguish window attached/detached, active/inactive, input
available/unavailable, controller count, and typed failure without persisting
raw window, scene, controller, gesture, or host identity.

#### Scenario: Input API is unavailable
- **WHEN** a requested input path is unavailable on the current SDK or device
- **THEN** UI and diagnostics SHALL expose a stable unavailable class and SHALL NOT claim capture

### Requirement: visionOS input verification SHALL preserve device boundaries
Offline and simulator proof SHALL NOT be reported as physical gaze/hand,
controller/keyboard, focus comfort, or live Sunshine acceptance.

#### Scenario: Simulator checks pass
- **WHEN** window, navigation, reducer, and build checks pass in a fixed simulator
- **THEN** physical Vision Pro input and comfort acceptance SHALL remain pending
