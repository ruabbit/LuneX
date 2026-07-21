## ADDED Requirements

### Requirement: AppKit window state shall drive one session lifecycle directive
LuneX SHALL resolve window occlusion, minimization, focus, application activation, drawable readiness, and active-session state into one directive consumed by rendering, video processing, presentation, and input capture.

#### Scenario: Stream window becomes occluded or minimized
- **WHEN** the active stream window is no longer visible or has no valid drawable
- **THEN** LuneX SHALL pause drawable acquisition and decoded-video submission, clear stale presentation, disable input capture, and keep the control session available for recovery

#### Scenario: Visible window loses key status
- **WHEN** the stream remains visible but its window or application loses focus
- **THEN** LuneX SHALL use throttled presentation policy, keep media transport ownership, disable platform input, and execute the held-input release barrier

### Requirement: Visible resume shall require current-generation video recovery
Resuming from a video-processing pause SHALL reject pre-pause frames and require a current-generation IDR before new decoded presentation becomes ready.

#### Scenario: Occluded stream becomes visible
- **WHEN** a paused active stream regains a positive drawable and visible window state
- **THEN** LuneX SHALL request a bounded fresh IDR, keep old presentation cleared, and resume only current-generation decoded frames

#### Scenario: Resume races stop or replacement
- **WHEN** lifecycle recovery suspends while the session stops or is replaced
- **THEN** the stale recovery SHALL NOT request or publish readiness for the new generation

### Requirement: Display and geometry changes shall publish atomic lifecycle state
Screen, backing-scale, stream-view drawable, decoded-source, and scale-mode changes SHALL produce an atomic coordinate snapshot before absolute input is admitted with the new revision.

#### Scenario: Window moves to another display
- **WHEN** `NSApplicationDidChangeScreenParametersNotification`, window screen change, or backing-property change affects the active stream view
- **THEN** LuneX SHALL refresh display identity, headroom, actual drawable pixels, coordinate snapshot, and renderer configuration as one ordered update

#### Scenario: Stream view resizes continuously
- **WHEN** live resize changes the stream view bounds
- **THEN** presentation and newly accepted absolute input SHALL use the same latest valid geometry without combining dimensions from different revisions

### Requirement: Lifecycle ownership shall follow window attachment and session generation
Only notifications from the currently attached stream window SHALL mutate active lifecycle policy, and teardown SHALL detach every observer and invalidate pending work.

#### Scenario: SwiftUI replaces the observed window
- **WHEN** the observation view moves from one `NSWindow` to another
- **THEN** LuneX SHALL remove old observers before attaching new ones and SHALL ignore delayed notifications from the old window

#### Scenario: Lifecycle attachment is dismantled
- **WHEN** SwiftUI removes the macOS stream attachment
- **THEN** LuneX SHALL detach observers, close input admission, restore cursor state, and prevent later callbacks from mutating the application model
