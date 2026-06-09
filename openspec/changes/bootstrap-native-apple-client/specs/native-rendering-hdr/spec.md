## ADDED Requirements

### Requirement: Renderer shall use native Metal presentation

The client SHALL present video through native Metal-backed views and SHALL avoid Qt, SDL, or storyboard rendering surfaces in LuneX-owned UI.

#### Scenario: Stream surface is created on macOS
- **WHEN** a stream view appears on macOS
- **THEN** the app SHALL create a Metal-capable native view with a `CAMetalLayer` or equivalent Metal presentation surface

#### Scenario: Stream surface is created on iOS family platforms
- **WHEN** a stream view appears on iOS, iPadOS, tvOS, or visionOS
- **THEN** the app SHALL create a UIKit/SwiftUI-compatible Metal surface and bind it to the shared renderer state

### Requirement: Renderer shall fill available stream area correctly

The renderer SHALL maintain aspect-fit, aspect-fill, and integer/low-latency presentation policies without incorrect mouse-coordinate scaling.

#### Scenario: User selects fill mode
- **WHEN** the user selects fill mode for a stream whose aspect ratio differs from the window
- **THEN** the frame SHALL fill the visible stream area and input mapping SHALL account for any crop or scale

#### Scenario: User selects fit mode
- **WHEN** the user selects fit mode
- **THEN** the full remote frame SHALL remain visible and pointer/touch mapping SHALL account for letterboxing

### Requirement: HDR streams shall use display headroom

The renderer SHALL detect HDR-capable streams and platform display headroom, enable EDR-capable presentation when available, and fall back to SDR tone mapping when unavailable.

#### Scenario: macOS display supports current EDR headroom
- **WHEN** a 10-bit HDR stream is active on a macOS screen whose current EDR maximum is greater than 1.0
- **THEN** the Metal layer SHALL enable extended dynamic range content and tone mapping SHALL use current and reference headroom values

#### Scenario: iOS display reports EDR headroom
- **WHEN** a 10-bit HDR stream is active on an iOS-family screen with EDR headroom above SDR
- **THEN** the renderer SHALL enable EDR presentation and expose the current headroom to the tone mapper

#### Scenario: HDR unavailable
- **WHEN** the stream is HDR but the platform or display cannot present EDR
- **THEN** the renderer SHALL tone-map to SDR without disabling the session

### Requirement: Rendering shall pause safely

The renderer SHALL support lifecycle-driven pause, resume, and surface reconfiguration without corrupting decoder state.

#### Scenario: Presentation is paused for occlusion
- **WHEN** lifecycle policy pauses presentation
- **THEN** the renderer SHALL stop requesting expensive drawables while preserving enough state to resume without restarting pairing or app launch
