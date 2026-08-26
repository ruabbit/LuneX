## ADDED Requirements

### Requirement: macOS-exclusive product completion
The project SHALL treat macOS 26+ as the only product-completion target until the accepted macOS candidate has been frozen, and SHALL execute macOS work in dependency order from production session transport through release freeze.

#### Scenario: Selecting the next implementation task
- **WHEN** the current macOS gate has an unmet implementable prerequisite
- **THEN** that prerequisite is selected before any iOS, iPadOS, tvOS, or visionOS product feature

#### Scenario: Existing stage order conflicts
- **WHEN** an older stage number or next-task marker points to cross-platform work that does not advance the current macOS gate
- **THEN** the macOS-first backlog takes precedence and the older marker is recorded as deferred rather than executed

### Requirement: non-macOS maintenance freeze
The project SHALL preserve existing iOS, iPadOS, tvOS, and visionOS targets and completed work while allowing changes on those platforms only to keep shared changes build-compatible or to remove a documented blocker to macOS completion.

#### Scenario: Platform-specific feature request before macOS freeze
- **WHEN** a proposed change adds or expands product behavior only for iOS, iPadOS, tvOS, or visionOS
- **THEN** the change is deferred without deleting its existing implementation or falsifying its OpenSpec status

#### Scenario: Shared core change affects other targets
- **WHEN** a macOS task changes shared code or generated project membership
- **THEN** affected non-macOS targets receive the minimum generic build verification needed to detect compatibility regressions, without Simulator, signed, physical, or product-feature expansion

#### Scenario: Non-macOS fix is proposed as a macOS blocker
- **WHEN** a non-macOS or shared edit is admitted before macOS freeze
- **THEN** the active task record identifies the concrete macOS blocker or compatibility failure that justifies it

### Requirement: evidence-tier integrity
The project SHALL classify every completion claim as deterministic implementation, generic build, Simulator, signed artifact, physical hardware, assistive technology, live Sunshine, or externally blocked, and SHALL NOT substitute one tier for another.

#### Scenario: Deterministic test passes
- **WHEN** a lifecycle, HDR, audio, input, workflow, or transport contract passes offline tests
- **THEN** only the deterministic tier is satisfied and any signed, physical, assistive-technology, or live-host row remains pending

#### Scenario: Generic platform build passes
- **WHEN** a target compiles for a generic destination
- **THEN** compatibility is recorded without claiming application runtime, device behavior, signing, or end-to-end streaming

#### Scenario: Physical evidence is recorded
- **WHEN** hardware or live-host acceptance is performed
- **THEN** the receipt binds the result to the exact Git SHA, candidate artifact where applicable, environment class, scenario, and privacy-bounded outcome

### Requirement: macOS completion gate
The macOS client SHALL NOT be declared functionally complete until an authorized live Sunshine workflow proves pairing, catalog, launch, sustained video, audible synchronized audio, remote input, reconnect, termination, stop, and clean resource teardown through the production runtime.

The client SHALL NOT restrict users through a Sunshine package-version allowlist. Compatibility SHALL be selected from server-advertised protocol and codec capabilities and validated by actual negotiation and live behavior. A Sunshine package version MAY be recorded as diagnostic metadata when available, but SHALL NOT be a prerequisite for attempting a compatible session.

All Moonlight HTTP commands SHALL use the same 16-character protocol client identifier across pairing, catalog, artwork, launch, resume, and cancel. The persisted LuneX identity UUID SHALL remain a local storage identifier and SHALL NOT replace the protocol identifier on the wire. An explicitly imported Moonlight-qt certificate/private-key identity SHALL reproduce Moonlight-qt's protocol identifier without exposing or rewriting unrelated identity material.

Every production network URL SHALL preserve the parsed endpoint port even when the persisted or user-facing address omits the default GameStream port. The macOS application SHALL declare a non-empty Local Network usage description and every Bonjour service type it browses, including `_nvstream._tcp`, in its product Info.plist.

#### Scenario: Default GameStream address is used
- **WHEN** a stored host address omits the default port and LuneX requests server info
- **THEN** the request SHALL target that host on TCP `47989` rather than relying on HTTP port `80`

#### Scenario: macOS product browses Sunshine hosts
- **WHEN** the macOS product uses Network.framework to browse `_nvstream._tcp` or connects to a local Sunshine endpoint
- **THEN** the built application SHALL contain `NSLocalNetworkUsageDescription` and an `NSBonjourServices` array containing `_nvstream._tcp`, while signed application acceptance remains distinct from bare XCTest or command-line evidence

#### Scenario: Existing Moonlight-qt identity is reused
- **WHEN** the user explicitly imports the local Moonlight-qt client certificate/private key into the Debug file fallback
- **THEN** LuneX SHALL validate the material, preserve private file permissions, send `0123456789ABCDEF` for every Moonlight HTTP command, present the persisted client identity during pinned HTTPS catalog/launch/resume/cancel authentication, and rely on the paired client certificate for live authorization without requiring re-pairing unless authentication actually fails

#### Scenario: Persisted client identity is missing or invalid
- **WHEN** catalog, artwork, launch, resume, or cancel needs pinned HTTPS authentication but the selected identity store cannot return valid client material
- **THEN** the production request SHALL fail before network access without silently using unauthenticated TLS, generating a replacement identity, or weakening the server certificate pin

#### Scenario: LuneX identity is restored after restart
- **WHEN** an existing LuneX identity is decoded from the backward-compatible file or Keychain representation
- **THEN** catalog, artwork, launch, resume, and cancel SHALL use the same protocol client identifier as pairing rather than the stored UUID string

#### Scenario: Sunshine package version is unknown or new
- **WHEN** a paired host does not expose its package version, or reports a version not previously recorded by LuneX
- **THEN** LuneX SHALL continue capability-based negotiation and SHALL fail only for an unsupported advertised requirement or observed protocol/runtime incompatibility, not for the package version itself

#### Scenario: Diagnostic version metadata is available
- **WHEN** a Sunshine package version is available without changing host state
- **THEN** it MAY be attached to a defect or acceptance receipt for reproducibility without changing compatibility eligibility

#### Scenario: Production video or audio provider is absent
- **WHEN** the default macOS runtime inventory cannot create both concrete video and audio receive providers
- **THEN** macOS remains incomplete even if packet parsers, decoders, renderers, audio processors, mocks, or fixtures pass

#### Scenario: End-to-end workflow passes
- **WHEN** the exact candidate completes the full authorized Sunshine workflow with sustained media and actual host-received input
- **THEN** the live session gate may pass only if reconnect, termination, repeated stop, and resource cleanup receipts also pass

### Requirement: native macOS acceptance gate
The macOS candidate SHALL pass native window, display, input, HDR/EDR, audio, product workflow, diagnostics, accessibility, packaging, and quality acceptance before freeze.

#### Scenario: Window and display lifecycle acceptance
- **WHEN** the stream window is occluded, minimized, unfocused, resized, made full screen, or moved across representative displays
- **THEN** rendering and input ownership follow actual visibility/focus, drawable and pointer transforms match the current surface, cursor ownership remains balanced, and the stream resumes without stale presentation

#### Scenario: HDR and spatial audio acceptance
- **WHEN** representative HDR/SDR displays and supported/non-supported audio routes are exercised
- **THEN** EDR mapping, SDR fallback, headroom transitions, spatial/fixed fallback, listener head tracking where entitled, route recovery, audible synchronization, and teardown match the recorded capability state

#### Scenario: Product and release acceptance
- **WHEN** the candidate is evaluated for freeze
- **THEN** native SwiftUI workflows, privacy redaction/export, keyboard navigation, VoiceOver/Voice Control, Debug/Release regressions, analyzer/sanitizer/resource gates, signing, notarization, stapling, Gatekeeper, latency, memory, power, thermal, weak-network, and long-run criteria all have exact-candidate results or the freeze fails

### Requirement: reproducible macOS freeze
The project SHALL freeze macOS only by recording an immutable manifest and obtaining acceptance of the exact candidate; other platforms SHALL remain deferred until that freeze is complete.

#### Scenario: Freeze manifest creation
- **WHEN** all macOS completion and acceptance gates pass
- **THEN** the project records the exact Git SHA, dependency hashes, Xcode and macOS versions, artifact hash, signing/notarization receipts, acceptance matrix, measured baselines, known limitations, and rollback point

#### Scenario: Freeze naming
- **WHEN** a freeze tag or release branch is ready to be created
- **THEN** its name and release semantics are confirmed with the user before repository refs are mutated

#### Scenario: Post-freeze platform reassessment
- **WHEN** the accepted macOS manifest and repository ref are immutable
- **THEN** iOS/iPadOS, tvOS, and visionOS priorities are reassessed from their preserved implementation and open evidence gaps rather than automatically resuming the old order
