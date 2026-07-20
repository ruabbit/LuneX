## ADDED Requirements

### Requirement: Input events shall be delivered over the negotiated authenticated channel
LuneX SHALL serialize supported keyboard, pointer, touch, controller, motion, and clipboard events using session key material and SHALL send them only while the corresponding session is operational.

#### Scenario: Focused macOS stream sends relative pointer input
- **WHEN** cursor capture policy selects remote relative mode and the window is key
- **THEN** pointer deltas and button state SHALL be serialized and delivered to the active host

#### Scenario: Window loses key status
- **WHEN** the macOS stream window resigns key
- **THEN** relative input delivery SHALL stop immediately and any held remote buttons or keys SHALL be released

### Requirement: Input backpressure and loss shall be explicit
High-rate motion and pointer input SHALL be coalesced where safe, while state transitions such as key-up and button-up SHALL remain ordered and reliable.

#### Scenario: Pointer samples exceed transport capacity
- **WHEN** new move samples arrive faster than they can be sent
- **THEN** LuneX SHALL coalesce obsolete movement without dropping button transitions

### Requirement: Remote feedback shall reach platform controllers
The runtime SHALL map supported host rumble, trigger-rumble, motion-rate, and LED commands to the originating GameController device.

#### Scenario: Host sends rumble
- **WHEN** a rumble command targets a connected controller
- **THEN** LuneX SHALL apply bounded motor values or publish a diagnostic when the device lacks the requested capability
