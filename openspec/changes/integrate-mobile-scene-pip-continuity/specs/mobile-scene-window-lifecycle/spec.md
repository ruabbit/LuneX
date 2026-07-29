## ADDED Requirements

### Requirement: Mobile scene state SHALL belong to the active stream surface generation
The iOS/iPadOS scene observer and its resources SHALL belong to one active
stream-surface generation, including the attached window, stream view,
lifecycle state, geometry revisions, and cancellation resources, and SHALL
NOT be mutated by callbacks from a detached or replaced generation.

#### Scenario: Stream surface is replaced
- **WHEN** a new stream surface attaches before callbacks from the prior surface have drained
- **THEN** the prior observer SHALL detach and its late callbacks SHALL NOT change the current scene or geometry state

#### Scenario: Active session stops
- **WHEN** the active stream session tears down
- **THEN** scene observation SHALL stop, current mobile presentation state SHALL clear, and repeated teardown SHALL remain safe

### Requirement: Scene and window observations SHALL come from the actual stream view
The mobile adapter SHALL derive its `UIWindowScene`, `UIWindow`, `UIScreen`,
window attachment, and foreground state from the actual UIKit stream view and
its current window instead of from a global screen, a synthetic SwiftUI phase,
or an unrelated scene.

#### Scenario: Stream view moves into a window
- **WHEN** UIKit invokes the stream view attachment lifecycle with an actual window and window scene
- **THEN** the adapter SHALL publish an attached snapshot for that scene, window, and screen generation

#### Scenario: Stream view moves between displays
- **WHEN** the stream view becomes attached to a window whose screen differs from the prior attachment
- **THEN** the adapter SHALL publish one semantic display revision and SHALL stop using the prior screen immediately

#### Scenario: Stream view detaches
- **WHEN** the stream view no longer has a window or window scene
- **THEN** the adapter SHALL publish a detached state and SHALL NOT infer attachment from another connected scene

### Requirement: Mobile geometry SHALL track continuous window changes
The iOS/iPadOS adapter SHALL publish finite, bounded view bounds, window bounds,
safe-area insets, native scale, drawable pixel size, interface orientation, and
trait revisions whenever the actual stream surface changes. Equivalent samples
SHALL be deduplicated.

#### Scenario: iPad Stage Manager continuously resizes the window
- **WHEN** repeated layout callbacks report distinct finite stream-view bounds
- **THEN** each semantic geometry change SHALL produce a monotonic revision whose drawable size is computed from the actual bounds and screen scale

#### Scenario: Layout callback repeats the same values
- **WHEN** a layout, safe-area, or trait callback does not change the normalized snapshot
- **THEN** the adapter SHALL NOT publish a duplicate revision or recreate renderer resources

#### Scenario: Geometry is empty or nonfinite
- **WHEN** the stream view reports zero, negative, nonfinite, or overflowing geometry
- **THEN** rendering and remote-input mapping SHALL fail closed until a valid geometry revision arrives

### Requirement: Scene lifecycle SHALL use current UIKit notifications
The active adapter SHALL observe activation, deactivation, foreground, and
background changes for its own `UIScene`, convert them into a bounded semantic
activity state, and cancel all notification ownership on replacement or
teardown.

#### Scenario: Active scene enters background
- **WHEN** the attached scene posts its background transition
- **THEN** the current generation SHALL publish background activity and reevaluate the mobile continuity policy

#### Scenario: Notification belongs to another scene
- **WHEN** a lifecycle notification is emitted for a scene other than the attached stream scene
- **THEN** the adapter SHALL ignore it

#### Scenario: Scene returns to foreground
- **WHEN** the attached scene enters foreground and becomes active
- **THEN** the adapter SHALL resample attachment, geometry, traits, display, and continuity state before foreground rendering resumes

### Requirement: Rendering and input SHALL consume one geometry contract
The Metal drawable size SHALL use the same current normalized mobile geometry
snapshot as video fit/fill transforms, touch/absolute-pointer mapping, and
remote resolution mapping.

#### Scenario: Window resize changes drawable size
- **WHEN** a valid geometry revision changes the stream surface pixel dimensions
- **THEN** the Metal surface and remote-input coordinate transform SHALL update from the same revision without stretching or using stale dimensions

#### Scenario: Input arrives during invalid geometry
- **WHEN** the current surface is detached or has no valid drawable dimensions
- **THEN** remote absolute input SHALL be suppressed rather than mapped through a fallback global-screen size

### Requirement: Mobile scene diagnostics SHALL be bounded and private
Scene and resize diagnostics SHALL use stable codes and fixed summaries for
attached, detached, active, inactive, background, resizing, invalid geometry,
display change, and stale-generation events without exposing raw scene,
window, display, host, or frame identifiers.

#### Scenario: Resize state is shown
- **WHEN** a current-generation semantic resize is active or has settled
- **THEN** native UI MAY show bounded status and pixel dimensions but SHALL NOT expose object identities or notification payloads

#### Scenario: Equivalent lifecycle event repeats
- **WHEN** repeated callbacks resolve to the same semantic state
- **THEN** the diagnostic store SHALL deduplicate the active action according to its bounded history policy

### Requirement: Verification SHALL preserve mobile lifecycle proof boundaries
The change SHALL pass deterministic contract tests, UIKit adapter tests,
warnings-as-errors platform builds, sanitizers, and fixed-simulator checks,
while real Stage Manager, external-display, rotation, keyboard, and touch
behavior remain incomplete until authorized physical-device acceptance.

#### Scenario: Simulator verification passes
- **WHEN** fixed iPhone and iPad simulator builds and deterministic injected lifecycle tests succeed
- **THEN** offline tasks MAY complete but physical Stage Manager and external-display acceptance SHALL remain pending

#### Scenario: Physical acceptance is performed
- **WHEN** an authorized iPhone and iPad exercise resize, rotation, background restoration, external display, and input mapping
- **THEN** evidence SHALL correlate the LuneX commit, device/window state, drawable dimensions, mapped coordinates, and clean teardown
