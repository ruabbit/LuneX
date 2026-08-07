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

#### Scenario: Window identity changes within one scene
- **WHEN** the actual stream surface moves to a replacement window in the same window scene
- **THEN** LuneX SHALL replace the window observation, publish only replacement-window state, and make queued or later old-window events inert

#### Scenario: Window key eligibility changes
- **WHEN** the actual visible interactive visionOS stream window becomes or resigns key status
- **THEN** LuneX SHALL re-read focus eligibility from that current window without changing tvOS focus-engine semantics

### Requirement: visionOS geometry SHALL synchronize rendering and input
One normalized semantic revision SHALL drive drawable sizing, video fit/fill,
and supported indirect or absolute input mapping. Detached or invalid geometry
SHALL suppress presentation and input.

#### Scenario: Window resizes
- **WHEN** the user changes the window size continuously
- **THEN** LuneX SHALL deduplicate equivalent snapshots and use the same final revision for rendering and input

#### Scenario: Fit or fill mode changes
- **WHEN** the current visionOS window changes between fit and fill for the same finite source and drawable geometry
- **THEN** LuneX SHALL apply one new semantic revision to both the resolved Metal video rectangle and crop-aware absolute input mapping

#### Scenario: Geometry closes
- **WHEN** the actual visionOS stream surface detaches or publishes nonfinite or otherwise invalid geometry
- **THEN** LuneX SHALL clear drawable sizing, render coordinates, and absolute input mapping together until a later valid current surface revision

### Requirement: visionOS system interaction SHALL remain reserved
LuneX SHALL keep system gestures, recentering, capture, safety, volume, and
platform escape behavior local. LuneX SHALL NOT synthesize or forward an
unsupported gaze, hand, or system gesture as Moonlight input.

#### Scenario: Unsupported spatial gesture occurs
- **WHEN** the platform reports interaction that has no public supported LuneX mapping
- **THEN** LuneX SHALL reserve or drop it locally with typed bounded state

#### Scenario: Public reserved hardware key occurs
- **WHEN** the current stream surface receives Escape, keyboard volume, capture, or another declared system shortcut through `UIPress.key`
- **THEN** LuneX SHALL publish only a canonical current-surface local decision and SHALL emit no Moonlight input event

#### Scenario: Interaction is owned by visionOS
- **WHEN** recentering, safety, system capture or volume, gaze, or hand behavior has no selected public LuneX event source
- **THEN** LuneX SHALL install no synthetic source or direct spatial recognizer and SHALL leave the interaction to the system

### Requirement: Supported visionOS input SHALL be capability gated
Controller, keyboard, pointer, and indirect input SHALL be admitted only when a
public adapter reports support and the current session/input/surface generation
is active and focused.

#### Scenario: Controller is active
- **WHEN** a supported controller is leased to the current focused stream
- **THEN** LuneX SHALL use the existing controller registry and ordered delivery contract

#### Scenario: Hardware keyboard press is supported
- **WHEN** the current key window receives a public hardware-key press with a supported HID usage
- **THEN** LuneX SHALL emit one balanced canonical key down/up pair under current-generation admission and SHALL keep reserved local commands out of the remote path

#### Scenario: Indirect pointer moves or scrolls
- **WHEN** a public indirect-pointer hover or scroll recognizer reports finite input inside current render geometry
- **THEN** LuneX SHALL map it through the current crop-aware absolute reference and SHALL NOT treat direct touch, gaze, or hand interaction as a mouse event

#### Scenario: Queued input becomes stale
- **WHEN** focus, surface generation, input generation, or presentation ownership changes before an admitted event is delivered
- **THEN** LuneX SHALL reject the queued event without sending it to the current host

#### Scenario: Window loses focus
- **WHEN** the stream window loses input eligibility
- **THEN** LuneX SHALL close admission, drain already accepted keyboard, pointer, and controller work, release held input exactly once, and only then restore local navigation

#### Scenario: Input provider fails
- **WHEN** a current keyboard, pointer, controller-roster, or controller-motion delivery fails
- **THEN** LuneX SHALL latch terminal input closure, run the same ordered release barrier, restore a bounded input-unavailable local state, and reject late geometry from reopening capture

#### Scenario: Held-input release provider fails
- **WHEN** the current ordered held-input release attempt fails
- **THEN** LuneX SHALL make only that one release attempt, latch terminal input closure, restore bounded input-unavailable local state, reject late geometry from reopening capture, and SHALL NOT ask the shared coordinator to issue a second release

#### Scenario: Platform release precedes shared input termination
- **WHEN** the visionOS ordered release barrier has completed before the shared input generation terminates
- **THEN** the shared coordinator SHALL close its queue, capture, and generation without issuing a second held-input release, while non-visionOS callers retain the default release barrier

### Requirement: visionOS input ownership SHALL teardown deterministically
LuneX SHALL cancel observer tokens, controller handlers, keyboard/pointer
monitors, held state, and surface leases idempotently on replacement and stop.

#### Scenario: Stop repeats
- **WHEN** stop or detach is requested more than once
- **THEN** LuneX SHALL perform at most one release/teardown operation and leave no current input owner

#### Scenario: Capture ownership closes and recovers
- **WHEN** ordered release closes actual visionOS capture and a later current media generation becomes eligible
- **THEN** the Metal surface SHALL clear local held key/button state, resign responder ownership, remove indirect recognizers, and reinstall them idempotently only for the new eligible capture

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

#### Scenario: Connected window and input regression completes
- **WHEN** deterministic tests exercise foreign-window filtering, same-generation resize, focus and capability admission, reserved interaction, crop-aware mapping, held release, stale callbacks, surface replacement, and repeated teardown as connected sequences
- **THEN** LuneX SHALL keep render/input revisions aligned, avoid release during eligible resize, release exactly once per replacement or terminal owner, keep old callbacks and mappings inert, and retain physical-device proof as pending
