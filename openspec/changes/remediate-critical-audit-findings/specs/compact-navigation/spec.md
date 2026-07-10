## ADDED Requirements

### Requirement: Compact devices shall expose direct primary navigation
The iPhone and compact-width iPad interface SHALL provide direct access to Library, Stream, Diagnostics, and Settings without requiring an inaccessible split-view detail transition.

#### Scenario: iPhone app launches
- **WHEN** the application launches on a compact-width iPhone
- **THEN** Library SHALL be the visible initial screen and Add Host SHALL be reachable

#### Scenario: User changes compact tab
- **WHEN** the user selects Stream, Diagnostics, or Settings
- **THEN** the corresponding content SHALL become visible and the selected navigation state SHALL remain synchronized

### Requirement: Compact library shall use a readable vertical layout
The compact Library SHALL stack host, app, pairing, and launch content vertically instead of forcing the desktop two-column grid.

#### Scenario: Library is shown on iPhone
- **WHEN** the available horizontal width is compact
- **THEN** each primary panel SHALL receive the full content width without horizontal clipping
