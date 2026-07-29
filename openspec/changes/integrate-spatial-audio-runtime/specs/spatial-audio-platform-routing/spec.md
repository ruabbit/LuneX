## ADDED Requirements

### Requirement: Spatial eligibility SHALL be derived from current observed capability
The client SHALL resolve spatial playback from user preference, supported channel layout, successful graph configuration, platform route capability, and applicable rendering algorithms; output names or device-brand strings SHALL NOT grant eligibility.

#### Scenario: Compatible route and graph are active
- **WHEN** every required eligibility input is current and true
- **THEN** the runtime SHALL report active spatial playback for the current route revision

#### Scenario: Route name resembles compatible hardware
- **WHEN** the output name contains a known product name but the capability or graph requirement is absent
- **THEN** the runtime SHALL remain unavailable or in typed fallback

### Requirement: Mobile-family platforms SHALL declare multichannel content
On iOS, iPadOS, tvOS, and visionOS, the active audio owner SHALL configure `AVAudioSession` for playback, declare whether it supplies multichannel content, and use supported preferred output-channel APIs without exceeding hardware limits.

#### Scenario: Surround content is configured
- **WHEN** a six- or eight-channel session becomes active
- **THEN** the platform adapter SHALL declare multichannel content and request no more output channels than the route reports as supported

#### Scenario: Audio stops
- **WHEN** the session releases the graph
- **THEN** the platform adapter SHALL clear its multichannel declaration and deactivate the session according to the current continuity policy

### Requirement: Head tracking SHALL require an embedded entitlement
On macOS, iOS/iPadOS, and tvOS, listener head tracking SHALL be eligible only when the signed process contains a true `com.apple.developer.coremotion.head-pose` entitlement, the active spatial graph is eligible, the user enables it, and the platform API accepts the setting.

#### Scenario: Entitlement is present
- **WHEN** every head-tracking input is eligible
- **THEN** the active environment node SHALL set and read back `isListenerHeadTrackingEnabled` and publish the observed result

#### Scenario: Entitlement is absent or unreadable
- **WHEN** the signed entitlement is missing, false, or cannot be read
- **THEN** fixed spatial playback MAY remain active but listener head tracking SHALL remain disabled with a stable reason

### Requirement: visionOS SHALL use its supported spatial-experience path
On visionOS 26+, the client SHALL use the output-node intended spatial experience and SHALL NOT call or imply use of the unavailable environment listener-head-tracking property.

#### Scenario: visionOS head-tracked preference is enabled
- **WHEN** a spatial-eligible visionOS session starts with head tracking enabled
- **THEN** the output node SHALL receive a head-tracked intended spatial experience and the runtime SHALL report the visionOS strategy

#### Scenario: visionOS fixed preference is selected
- **WHEN** spatial playback is active but head tracking is disabled
- **THEN** the output node SHALL receive a fixed intended spatial experience

### Requirement: Route and capability changes SHALL be observed
The active platform adapter SHALL observe route, interruption, media-services, and spatial-playback-capability changes available on its platform and SHALL convert them into bounded semantic revisions.

#### Scenario: Spatial-capable output is replaced
- **WHEN** the active output route changes from spatial-capable to unsupported
- **THEN** the session runtime SHALL rebuild or downgrade the graph and publish a new nonspatial state

#### Scenario: Equivalent duplicate notification arrives
- **WHEN** a notification does not change semantic route or capability state
- **THEN** the adapter SHALL NOT cause an additional graph revision or duplicate diagnostic

### Requirement: Platform fallbacks SHALL remain truthful
The runtime SHALL distinguish fixed spatial playback, listener-head-tracked playback, visionOS intended spatial experience, nonspatial PCM fallback, unavailable route, missing entitlement, unsupported layout, and graph failure.

#### Scenario: Spatial processing is unavailable but PCM is valid
- **WHEN** the base PCM graph can play but spatial eligibility is not met
- **THEN** the session SHALL continue through the typed nonspatial path and expose the precise bounded fallback class
