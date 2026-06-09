## ADDED Requirements

### Requirement: Mobile background continuity shall use supported modes

The iOS, iPadOS, tvOS, and visionOS clients SHALL use only supported background execution modes and SHALL make continuity behavior user-visible.

#### Scenario: App enters background with audio continuity enabled
- **WHEN** a mobile stream enters background and audio/PiP continuity is enabled
- **THEN** the app SHALL transition into the supported background playback path and reduce or suspend foreground-only rendering work

#### Scenario: App enters background without supported continuity
- **WHEN** a mobile stream enters background and no supported continuity path is active
- **THEN** the client SHALL pause, stop, or warn according to user settings and platform policy

### Requirement: Picture in Picture shall reflect stream state

Where supported, the client SHALL use sample-buffer Picture in Picture or media playback integration to keep a visible session affordance while backgrounded.

#### Scenario: PiP render size changes
- **WHEN** the system PiP controller reports a render-size transition
- **THEN** the client SHALL update presentation metadata without corrupting the main session state

### Requirement: macOS background behavior shall use window/app visibility

The macOS client SHALL use app activation and window occlusion/key state rather than mobile background modes.

#### Scenario: App resigns active but window remains visible
- **WHEN** the macOS app resigns active while the stream window is still visible
- **THEN** the client SHALL keep rendering according to user performance settings and input focus policy
