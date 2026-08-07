## ADDED Requirements

### Requirement: tvOS focus navigation SHALL remain locally owned when appropriate
LuneX SHALL keep directional, select, and focus movement owned by native tvOS
navigation whenever no stream input generation is active or the stream overlay
requires focus. Focus identity SHALL NOT be serialized as a remote host event.

#### Scenario: Browser is visible
- **WHEN** the user navigates hosts, apps, settings, or pairing UI
- **THEN** Siri Remote and controller navigation SHALL move native focus and SHALL NOT send stream input

#### Scenario: Stream overlay opens
- **WHEN** the overlay becomes visible during a stream
- **THEN** local focus ownership SHALL be restored before the overlay accepts commands

### Requirement: Stream remote presses SHALL use current-generation admission
Supported Siri Remote press begin, end, and cancellation events SHALL be
forwarded only while the current stream/input generation owns an eligible
surface and local focus UI is dismissed.

The provider SHALL resolve directional presses to canonical remote arrow keys,
Select to remote Return, and Play/Pause to remote media Play/Pause before using
the existing Moonlight keyboard wire and held-state release path. It SHALL NOT
add a tvOS-specific wire packet type.

#### Scenario: Supported press is completed
- **WHEN** an admitted play/pause, select, or directional press begins and ends
- **THEN** LuneX SHALL deliver one balanced current-generation remote press sequence

#### Scenario: Old surface callback arrives
- **WHEN** a press callback belongs to a replaced or stopped surface generation
- **THEN** LuneX SHALL discard it without mutating current held state

### Requirement: System-reserved tvOS commands SHALL remain local
Back/Menu/Home, volume, capture, power, and other system-reserved commands SHALL
NOT be forwarded to the host or consumed to defeat native escape behavior.

#### Scenario: User requests native back
- **WHEN** the current remote emits the platform back or menu escape command
- **THEN** LuneX SHALL keep it local and close capture or reveal native stream controls

### Requirement: Game controllers SHALL have bounded generation-owned slots
The tvOS runtime SHALL observe actual supported controller profiles, assign
bounded current-generation remote slots, normalize complete state, and reject
callbacks and feedback for disconnected or replaced controller leases.

#### Scenario: Extended controller connects
- **WHEN** an extended gamepad connects during a current stream
- **THEN** LuneX SHALL publish one slot and forward supported complete state through the existing remote input registry

#### Scenario: Controller disconnects
- **WHEN** a controller disconnects with held buttons or nonzero axes
- **THEN** LuneX SHALL close its handlers and enqueue ordered neutral/release state before freeing the slot

### Requirement: Input teardown SHALL release held state exactly once
LuneX SHALL close admission and join the existing ordered release barrier on
focus loss, overlay activation, scene loss, provider failure, replacement, or
stop.

#### Scenario: Scene resigns active
- **WHEN** tvOS scene activity is lost while input is held
- **THEN** LuneX SHALL stop new input and complete one bounded release operation for the current generation

### Requirement: tvOS input UI and diagnostics SHALL expose bounded actual state
Native UI SHALL expose current local-focus, remote-capture, controller-count,
and typed failure state accessibly. Diagnostics SHALL exclude raw focus item,
controller object, vendor, host, and payload identities.

#### Scenario: Controller callback becomes stale
- **WHEN** a stale controller event is rejected
- **THEN** diagnostics SHALL record a fixed stale-generation class without persisting controller identity

#### Scenario: Platform diagnostics are exported on a supported Apple platform
- **WHEN** a diagnostics report contains tvOS focus, input, controller, presentation, or recovery state
- **THEN** the export SHALL omit event and runtime ownership identities and re-redact secrets, UUIDs, network locations, and host, session, generation, revision, frame, controller, display, and route assignments

#### Scenario: Stream controls receive local focus
- **WHEN** the overlay opens during a current stream
- **THEN** native focus SHALL move predictably from Hide Controls to Disconnect while actual focus, capture, and controller count remain separately accessible

#### Scenario: tvOS Settings display input and controller policy
- **WHEN** Settings displays tvOS input capture and controller routing
- **THEN** LuneX SHALL show the supported automatic behavior beside current bounded Capture and Controllers state, SHALL NOT expose macOS relative-mouse or system-shortcut controls or the iOS virtual-controller control, and SHALL NOT add a toggle that current runtime admission does not enforce

### Requirement: tvOS input verification SHALL preserve hardware boundaries
LuneX SHALL keep Siri Remote feel, physical controller mapping/feedback, and
live host receipt incomplete until authorized Apple TV hardware evidence
exists, even when deterministic and simulator ownership checks pass.

#### Scenario: Offline tests pass
- **WHEN** reducers, adapters, builds, and simulator navigation pass
- **THEN** LuneX SHALL NOT report physical Siri Remote or controller acceptance complete
