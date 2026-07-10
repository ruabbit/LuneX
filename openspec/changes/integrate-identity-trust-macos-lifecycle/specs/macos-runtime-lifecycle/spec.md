## ADDED Requirements

### Requirement: macOS window events shall drive live renderer state
The macOS SwiftUI window SHALL publish occlusion, key status, screen, backing scale, and resize changes to the active render state.

#### Scenario: Stream window becomes occluded
- **WHEN** the stream window is no longer visible
- **THEN** the renderer policy SHALL become paused without disconnecting session state

#### Scenario: Stream window resigns key
- **WHEN** a visible stream window loses key status
- **THEN** the renderer policy SHALL become throttled

#### Scenario: Window drawable changes
- **WHEN** the window resizes or its backing scale changes
- **THEN** drawable pixel size and render transform SHALL be updated from the actual content bounds

### Requirement: macOS display changes shall refresh EDR headroom
The renderer SHALL read current and potential EDR headroom from the window's active `NSScreen`.

#### Scenario: Window changes screen
- **WHEN** the window moves to another display or display parameters change
- **THEN** the renderer SHALL refresh screen identity, drawable size, EDR headroom, and Metal-layer EDR configuration
