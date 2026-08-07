## ADDED Requirements

### Requirement: Actual-state session commands
The application SHALL derive launch, reconnect, resume, and stop availability from the checked session state and runtime provider inventory rather than optimistic UI flags.

#### Scenario: Provider unavailable
- **WHEN** a required stream provider is absent
- **THEN** launch remains disabled and the UI presents a typed unavailable reason without entering a streaming phase

#### Scenario: Duplicate launch
- **WHEN** launch is requested while the same workspace owns a launch or active session
- **THEN** the application preserves the current generation and does not start a second provider sequence

### Requirement: Recoverable session termination
The application SHALL distinguish local stop, remote termination, recoverable transport interruption, exhausted reconnect, and terminal protocol failure, and SHALL offer only actions valid for the actual state.

#### Scenario: Recoverable interruption
- **WHEN** the active generation reports an interruption within its reconnect budget
- **THEN** the UI presents reconnect progress and a local stop command without creating a second session owner

#### Scenario: Remote termination
- **WHEN** the host terminates the active session
- **THEN** media and input ownership are released, the session returns to a non-streaming state, and the user can relaunch when prerequisites remain valid

#### Scenario: Stale termination
- **WHEN** termination arrives from a replaced generation
- **THEN** it cannot stop or relabel the replacement session

### Requirement: Stream command ownership
The application SHALL route stream overlay commands through the owning workspace and active session generation, and SHALL keep system-reserved commands local on macOS, iOS/iPadOS, tvOS, and visionOS.

#### Scenario: Local overlay command
- **WHEN** the user opens or dismisses stream controls
- **THEN** the command changes local presentation only and is not serialized as remote input

#### Scenario: Stop from overlay
- **WHEN** the user confirms stop from the active stream overlay
- **THEN** the owning generation performs clean input release, media teardown, and control teardown exactly once

### Requirement: Video-safe overlay presentation
The application SHALL keep essential stream controls reachable without permanently obscuring decoded video, SHALL support touch and focus navigation without hover, and SHALL adapt to compact and resized windows.

#### Scenario: Compact window
- **WHEN** the stream window becomes compact
- **THEN** controls remain reachable inside safe areas with no text or command overlap

#### Scenario: Reduced motion
- **WHEN** Reduce Motion is enabled
- **THEN** overlay state changes avoid nonessential motion while preserving command and focus behavior

### Requirement: Session action idempotence
The application SHALL make repeated stop, cancel, and recovery commands idempotent and SHALL prevent late async completion from restoring cleared launch or error state.

#### Scenario: Repeated stop
- **WHEN** stop is invoked concurrently from window close and an overlay command
- **THEN** one teardown owner completes and all callers observe the same terminal result
