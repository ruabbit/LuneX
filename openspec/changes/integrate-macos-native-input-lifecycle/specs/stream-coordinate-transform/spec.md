## ADDED Requirements

### Requirement: Presentation and input shall share one resolved video rectangle
LuneX SHALL resolve decoded source size, actual drawable pixel size, and fit/fill mode into one immutable video rectangle used by both presentation and absolute input mapping.

#### Scenario: Aspect-fit video is letterboxed
- **WHEN** the drawable and source aspect ratios differ in fit mode
- **THEN** the resolver SHALL center the full source image and both renderer and input mapper SHALL use the same letterboxed video rectangle

#### Scenario: Aspect-fill video is cropped
- **WHEN** the drawable and source aspect ratios differ in fill mode
- **THEN** the resolver SHALL describe the cropped source mapping and both renderer and input mapper SHALL use that same crop

### Requirement: Absolute pointer mapping shall reject non-video regions
Absolute pointer mapping SHALL use a view-relative backing-pixel point and its enqueue-time coordinate snapshot, rejecting invalid or non-video input rather than silently mapping it to an unrelated remote edge.

#### Scenario: Pointer is inside fit-mode video
- **WHEN** a backing-pixel point lies inside the resolved video rectangle
- **THEN** LuneX SHALL map it proportionally into the decoded source coordinate system and retain the matching source reference size

#### Scenario: Pointer is in fit-mode letterbox
- **WHEN** a point lies outside the video rectangle but inside the drawable
- **THEN** LuneX SHALL drop the absolute movement and SHALL NOT synthesize a remote edge coordinate

### Requirement: Transform snapshots shall be valid, bounded, and revisioned
LuneX SHALL publish coordinate snapshots only for positive finite geometry, SHALL clamp final mapped source coordinates to legal bounds, and SHALL monotonically revise snapshots when any input changes.

#### Scenario: Drawable becomes zero during resize
- **WHEN** the stream view temporarily has zero backing width or height
- **THEN** LuneX SHALL mark coordinate mapping unavailable and reject absolute input until a later valid snapshot is published

#### Scenario: Event spans a resize boundary
- **WHEN** an absolute sample is enqueued before a resize and delivered after the resize
- **THEN** it SHALL use its captured pre-resize snapshot or be rejected as stale, but SHALL NOT mix its point with post-resize geometry

### Requirement: AppKit point conversion shall be explicit
The macOS capture view SHALL define a consistent top-left view coordinate convention and SHALL convert points to backing pixels before coordinate resolution.

#### Scenario: Backing scale changes
- **WHEN** the stream window moves between displays with different backing scales
- **THEN** newly captured points and drawable size SHALL use the new scale in the same snapshot revision while earlier events retain or reject their old revision consistently
