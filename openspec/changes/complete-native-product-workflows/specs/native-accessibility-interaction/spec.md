## ADDED Requirements

### Requirement: Semantic workflow controls
Every interactive product action SHALL have a localized accessibility label, value where state is material, enabled state matching command eligibility, and a stable semantic role without requiring visual icon recognition.

#### Scenario: Icon-only command
- **WHEN** a familiar symbol is used without visible text
- **THEN** assistive technologies receive a localized command label and any destructive role or disabled reason

#### Scenario: Session state change
- **WHEN** the actual stream state changes
- **THEN** the owning view exposes the updated state without repeatedly announcing frame-level telemetry

#### Scenario: Semantic privacy and checked eligibility
- **WHEN** a host, pairing, stream, settings, or diagnostics action is unavailable or in progress
- **THEN** its stable semantic descriptor exposes the actual eligibility and a localized reason without including an endpoint, PIN, key, certificate, device identity, or arbitrary provider text

#### Scenario: Destructive workflow status
- **WHEN** a destructive host, trust, or stream operation is represented as both an action and a workflow status
- **THEN** only the actionable command carries destructive status while the descriptive status remains non-destructive

### Requirement: Scalable nonoverlapping layout
Workflow views SHALL support accessibility Dynamic Type, localized text expansion, compact iPhone and resized iPad/macOS windows without clipped controls, incoherent overlap, or horizontal scrolling for primary commands.

#### Scenario: Accessibility text size
- **WHEN** the user selects an accessibility text size
- **THEN** panels reflow into a readable vertical or adaptive layout and every primary action remains reachable

#### Scenario: Narrow or invalid dashboard width
- **WHEN** a macOS or iPadOS dashboard reports a finite width below the wide-layout threshold, a compact horizontal size class, or an invalid width
- **THEN** host, catalog, pairing, and launch panels use one vertical composition and primary command groups fall back from horizontal to vertical without platform-specific assumptions

### Requirement: Keyboard and voice operation
macOS and iPadOS workflows SHALL support predictable keyboard focus, default and cancel actions, and named Voice Control targets while preserving system-reserved shortcuts locally.

#### Scenario: Pairing by keyboard
- **WHEN** a keyboard user enters a valid PIN and invokes the default action
- **THEN** pairing submission occurs once and focus moves to meaningful progress or result content

#### Scenario: Initial workflow focus
- **WHEN** Add Host, pairing, or the owning stream overlay becomes available on macOS or iPadOS
- **THEN** focus moves respectively to the address field, the current pairing action or status, or Hide Stream Controls without changing remote input ownership

#### Scenario: Pairing focus transition
- **WHEN** pairing moves between ready, PIN entry, progress, retryable failure, and terminal result phases
- **THEN** focus follows a typed phase policy to Start Pairing, Pairing PIN, progress status, Retry Pairing, or result content

#### Scenario: Native default and cancel actions
- **WHEN** a macOS or iPadOS user invokes the native default or cancel action in Add Host, pairing, stream controls, or a confirmation workflow
- **THEN** the visible eligible primary or cancellation command executes once and stale ownership checks remain unchanged

#### Scenario: Voice Control name
- **WHEN** a keyboard workflow field or primary command is visible
- **THEN** it exposes an explicit localized accessibility name that remains stable when its icon or label composition changes

#### Scenario: System shortcut
- **WHEN** the user invokes a system-reserved window or accessibility shortcut
- **THEN** it remains local and is not forwarded as remote keyboard input

### Requirement: Touch and focus targets
iOS/iPadOS actions SHALL meet native touch target expectations, and tvOS/visionOS actions SHALL expose deterministic focus order, focus restoration, and reachability consistent with actual command eligibility.

#### Scenario: iOS workflow action target
- **WHEN** an iPhone or iPad user invokes a custom host, pairing, catalog, launch, stream, diagnostics, settings, navigation, app-selection, or Picture in Picture action
- **THEN** its interactive frame is at least 44 by 44 points and its visible label can expand vertically without changing command ownership or eligibility

#### Scenario: tvOS overlay focus
- **WHEN** the stream overlay opens on tvOS
- **THEN** the shared focus scope moves to Hide Controls before Disconnect, and closing the overlay restores the stream surface only from a current handoff or stream-surface state

#### Scenario: tvOS unavailable focus restoration
- **WHEN** the tvOS focus presentation is unavailable or does not match the actual overlay state
- **THEN** the focus policy fails closed without selecting a stale overlay command or stream surface

#### Scenario: visionOS unavailable input
- **WHEN** visionOS input capture is ineligible
- **THEN** Hide Controls is disabled, communicates the actual unavailable state semantically, and cannot receive focus while claiming unavailable capture

#### Scenario: visionOS eligible input restoration
- **WHEN** the current visible visionOS window has matching presentation and input generations, the overlay is the actual local-input reason, and at least one current remote input capability is available
- **THEN** Hide Controls is enabled and exposes the number of remote input paths that become available after the overlay closes

### Requirement: Reduced motion and contrast independence
The application SHALL respect Reduce Motion and SHALL not communicate pairing, reachability, failure, HDR, audio, or session state by color or animation alone.

#### Scenario: Stream overlay motion
- **WHEN** stream controls appear or disappear
- **THEN** the overlay may use a bounded opacity transition normally and uses an immediate identity transition with no animation when Reduce Motion is enabled

#### Scenario: Selected and diagnostic state without color
- **WHEN** navigation or app selection changes, or a diagnostic event is presented
- **THEN** a visible text or symbol marker and semantic value communicate the selected or severity state without requiring color perception

#### Scenario: Failure presentation
- **WHEN** a workflow fails with Reduce Motion enabled
- **THEN** a textual semantic status and valid action are presented without required animated transition

### Requirement: Evidence-bounded accessibility validation
Deterministic tests SHALL validate semantic contracts and layout state generation, while physical VoiceOver, Voice Control, hardware keyboard, tvOS remote, and visionOS interaction SHALL remain separately identified acceptance evidence.

#### Scenario: Offline accessibility test passes
- **WHEN** source-contract and application tests pass
- **THEN** reporting claims only deterministic accessibility coverage and not physical assistive-technology acceptance

#### Scenario: Complete application accessibility matrix
- **WHEN** deterministic application tests exercise semantic descriptors, keyboard focus, longest localized text, Dynamic Type, compact and wide layout, touch targets, reduced motion, tvOS focus restoration, and visionOS overlay reachability
- **THEN** every value is derived from the current checked workspace and actual platform presentation, stale owner or surface state fails closed, and physical VoiceOver, Voice Control, remote, gaze, hand, signed-device, and live-host acceptance remain unclaimed
