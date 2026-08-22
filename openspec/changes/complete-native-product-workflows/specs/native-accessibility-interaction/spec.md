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

#### Scenario: System shortcut
- **WHEN** the user invokes a system-reserved window or accessibility shortcut
- **THEN** it remains local and is not forwarded as remote keyboard input

### Requirement: Touch and focus targets
iOS/iPadOS actions SHALL meet native touch target expectations, and tvOS/visionOS actions SHALL expose deterministic focus order, focus restoration, and reachability consistent with actual command eligibility.

#### Scenario: tvOS overlay focus
- **WHEN** the stream overlay opens on tvOS
- **THEN** focus moves to an eligible local command and returns to the declared prior destination when the overlay closes

#### Scenario: visionOS unavailable input
- **WHEN** visionOS input capture is ineligible
- **THEN** the UI communicates the unavailable state semantically and does not focus a command that would claim unavailable capture

### Requirement: Reduced motion and contrast independence
The application SHALL respect Reduce Motion and SHALL not communicate pairing, reachability, failure, HDR, audio, or session state by color or animation alone.

#### Scenario: Failure presentation
- **WHEN** a workflow fails with Reduce Motion enabled
- **THEN** a textual semantic status and valid action are presented without required animated transition

### Requirement: Evidence-bounded accessibility validation
Deterministic tests SHALL validate semantic contracts and layout state generation, while physical VoiceOver, Voice Control, hardware keyboard, tvOS remote, and visionOS interaction SHALL remain separately identified acceptance evidence.

#### Scenario: Offline accessibility test passes
- **WHEN** source-contract and application tests pass
- **THEN** reporting claims only deterministic accessibility coverage and not physical assistive-technology acceptance
