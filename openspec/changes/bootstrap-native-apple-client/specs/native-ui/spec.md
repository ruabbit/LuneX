## ADDED Requirements

### Requirement: App shell shall be native SwiftUI

The client SHALL provide native SwiftUI shells for macOS, iOS, iPadOS, tvOS, and visionOS with platform-appropriate navigation.

#### Scenario: macOS app launches
- **WHEN** the macOS app launches
- **THEN** it SHALL show a native window with host library, connection actions, settings, and diagnostics access

#### Scenario: iOS app launches
- **WHEN** the iOS app launches
- **THEN** it SHALL show touch-first host and app navigation with settings reachable without blocking stream start

### Requirement: Stream UI shall stay usable during playback

The stream view SHALL provide overlays for connection status, controls, input mode, performance, HDR/audio status, and disconnect actions.

#### Scenario: Stream is connecting
- **WHEN** a stream is connecting
- **THEN** the UI SHALL show progress and current subsystem without covering permanent controls needed to cancel

#### Scenario: Stream is active
- **WHEN** a stream is active
- **THEN** transient controls SHALL be available without permanently occluding the video surface

### Requirement: Settings shall expose quality and platform behavior

The app SHALL expose settings for resolution, frame rate, bitrate, codec/HDR preference, audio mode, input mode, background continuity, and diagnostics.

#### Scenario: User changes stream quality
- **WHEN** the user edits quality settings before stream start
- **THEN** the selected settings SHALL be applied to the next negotiation and persisted per user preference
