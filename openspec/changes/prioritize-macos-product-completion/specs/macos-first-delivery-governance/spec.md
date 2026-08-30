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

#### Scenario: Live media failure remains diagnosable and privacy bounded
- **WHEN** an exact-SHA live session fails before sustained video and audible synchronized audio are accepted
- **THEN** the test receipt identifies `video_receive` or `audio_receive` and a finite enumerated transport, media-runtime, or packet-parser cause
- **AND** the failure receipt excludes endpoint addresses, payload bytes, credentials, certificates, arbitrary numeric transport-error details, arbitrary operation names, and arbitrary error descriptions
- **AND** consumer termination, task cancellation, and an explicitly cancelled network channel are not recorded as production media failures

#### Scenario: Live media idle path remains diagnosable before cleanup
- **WHEN** an exact-SHA live session keeps control ready but video or audio readiness does not arrive before the bounded acceptance deadline
- **THEN** a test-only forwarding wrapper around the production datagram channel records only the channel kind, negotiated UDP port, custom-versus-legacy ping selection, and saturated counts for successful connections, ping sends, received datagrams, and parser-produced events
- **AND** when parser-produced video events remain active without a published frame, a test-only forwarding wrapper around the real production video processor runs the same bounded normalized assembler in shadow while forwarding every original event unchanged to the real processor
- **AND** when the direct XCTest harness has no AppKit window, it applies an explicit test-owned active, visible, focused, nonzero-drawable lifecycle state through the same production resolver before launch, without weakening product occlusion, minimize, drawable-loss, or focus behavior
- **AND** the video-processing receipt records only the finite negotiated codec, saturated packet, first-packet, last-packet, transport-loss, assembled-access-unit, finite frame-loss/discard-reason, and successful production-submission counts plus the latest production decode-pipeline booleans and saturated session/reset/format/color/IDR/drop/failure/teardown/pause/resume counts
- **AND** the receipt captures the AppModel phase, published-frame count, and finite audio runtime stage before local cleanup changes observable state
- **AND** the receipt does not store host addresses, ping or media payloads, frame indexes, decoder-generation values, sequence numbers, RTP timestamps, keys, credentials, certificates, identity material, OSStatus values, or arbitrary error descriptions
- **AND** this diagnostic receipt does not by itself satisfy sustained decoded video, audible synchronized audio, physical input feedback, reconnect, remote termination, repeated stop, or clean-teardown acceptance

### Requirement: macOS completion gate
The macOS client SHALL NOT be declared functionally complete until an authorized live Sunshine workflow proves pairing, catalog, launch, sustained video, audible synchronized audio, remote input, reconnect, termination, stop, and clean resource teardown through the production runtime.

The client SHALL NOT restrict users through a Sunshine package-version allowlist. Compatibility SHALL be selected from server-advertised protocol and codec capabilities and validated by actual negotiation and live behavior. A Sunshine package version MAY be recorded as diagnostic metadata when available, but SHALL NOT be a prerequisite for attempting a compatible session.

#### Scenario: Continuous macOS pointer input remains realtime
- **WHEN** Direct or Relative pointer movement arrives faster than the authenticated transport completes individual sends
- **THEN** the first serialized macOS input queue coalesces only adjacent compatible movement before transport admission
- **AND** Relative mode preserves the summed movement delta while Direct mode preserves the newest mapped position
- **AND** coordinate-reference changes, pointer-button snapshots, keyboard events, button transitions, scroll events, focus release, and termination remain ordering barriers
- **AND** a button transition is not delayed behind a long FIFO history of stale pointer movement
- **AND** bounded overload does not silently discard the accumulated Relative displacement
- **AND** every active AppKit capture surface participates in replacement-safe window mouse-movement delivery ownership, restoring the prior window policy only after the final owner detaches

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

#### Scenario: Paired host is busy during catalog acceptance
- **WHEN** the designated host already has an application running and the catalog-only live gate is explicitly enabled
- **THEN** LuneX MAY perform the read-only pinned-mTLS server-info and catalog requests without treating the busy state as a client-session mutex

#### Scenario: Initial session does not treat host state as client capacity
- **WHEN** the separate session opt-in is enabled, the host explicitly reports an application running, and `currentgame` matches the selected application ID
- **THEN** LuneX SHALL create another client streaming session for that application through `/resume`
- **WHEN** `currentgame` does not identify the selected application, or the advertised host state is free, unknown, missing, or inconsistent
- **THEN** LuneX SHALL attempt the selected application through `/launch` and let the authenticated server response determine whether that operation is supported
- **AND** LuneX SHALL NOT reject a user-selected application solely because the host reports busy, assume that busy represents exclusive client capacity, or call `/cancel` to make the host appear free

#### Scenario: RTSP transactions follow Sunshine connection lifetime
- **WHEN** LuneX negotiates OPTIONS, DESCRIBE, or SETUP with Sunshine
- **THEN** each RTSP request SHALL use a fresh TCP connection and consume the complete response delivered before or with peer close
- **AND** a terminal Network.framework error SHALL NOT discard nonempty response bytes delivered by the same receive callback
- **AND** a plaintext response without `Content-Length` SHALL treat every byte after the header terminator through peer close as its body
- **AND** a plaintext response with `Content-Length` SHALL consume exactly that declared body without accepting trailing or incomplete bytes
- **AND** an encrypted response SHALL remain authenticated-frame-length delimited without waiting unnecessarily for peer close
- **AND** encrypted RTSP send sequence and client/host nonce direction SHALL remain continuous across those per-request TCP connections
- **AND** cancellation SHALL close the current transaction connection and prevent any later request from that cancelled RTSP session

#### Scenario: RTSP establishes the Sunshine stream session before control transport
- **WHEN** OPTIONS, DESCRIBE, and the audio, video, and control SETUP transactions succeed
- **THEN** LuneX SHALL send ANNOUNCE with the negotiated session token and a bounded Sunshine-compatible SDP description
- **AND** LuneX SHALL send PLAY only after ANNOUNCE succeeds
- **AND** LuneX SHALL connect the ENet control transport only after PLAY succeeds
- **AND** an unsupported required control-encryption capability or a rejected ANNOUNCE or PLAY SHALL fail closed before ENet connection
- **AND** the SDP feature mask SHALL advertise only protocol features whose corresponding client behavior LuneX actually implements

#### Scenario: Audio encryption follows the negotiated Sunshine capability
- **WHEN** the SDP requests control-v2 plus audio encryption and advertises both capabilities as supported
- **THEN** LuneX SHALL retain control-v2 protection, declare the audio bit in ANNOUNCE, and attach the negotiated AES-128 key material only to the in-memory audio receive configuration
- **AND** the audio receiver SHALL decrypt only the Opus payload with AES-128-CBC using the negotiated key ID plus RTP sequence IV construction, while preserving the RTP header
- **AND** audio key bytes and key IDs SHALL be excluded from Codable snapshots, diagnostics, and exported state
- **WHEN** the SDP requests video encryption or any unknown encryption bit
- **THEN** LuneX SHALL fail closed before ENet connection because video encryption is not implemented
- **WHEN** an encrypted audio configuration lacks a 16-byte key or an unsigned 32-bit key ID
- **THEN** LuneX SHALL reject the configuration before creating a media channel

#### Scenario: Established Sunshine control session remains alive
- **WHEN** encrypted ENet control transport completes START A and START B
- **THEN** LuneX SHALL immediately send the reliable `0x0200` periodic-ping message on the generic control channel and continue sending it at the Moonlight 100-millisecond interval while that control generation remains active
- **AND** periodic ping, IDR, and remote-input frames SHALL share one monotonic authenticated client sequence
- **AND** keepalive send failure SHALL fail or reconnect the current generation, while stop, replacement, and teardown SHALL prevent any later keepalive from that generation

#### Scenario: Long-lived media UDP is temporarily idle
- **WHEN** a negotiated video or audio UDP receiver is waiting and no datagram arrives within an arbitrary polling window
- **THEN** LuneX SHALL keep the media channel active instead of cancelling the Network.framework connection or publishing a terminal transport failure solely because the receive was idle
- **AND** explicit session stop, consumer cancellation, send failure, actual receive failure, invalid or oversized data, and buffer overflow SHALL retain bounded fail-closed teardown
- **AND** connect and send deadlines plus every TCP/RTSP transaction deadline and terminal-close rule SHALL remain unchanged

#### Scenario: Local client disconnect preserves the remote application
- **WHEN** the user disconnects, a stream consumer cancels, a generation is replaced, or local session setup fails
- **THEN** LuneX SHALL release only that client's control, RTSP, media, audio, decoder, and input resources and SHALL NOT call Sunshine `/cancel`
- **AND** terminating the shared remote application through `/cancel` SHALL require a separate explicitly confirmed product action

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

#### Scenario: Sunshine video parity carries generated header bytes
- **WHEN** a bounded video shard's `fecInfo` classifies it as parity
- **THEN** LuneX SHALL validate its FEC block, data/total shard counts, percentage, and shard index without requiring the data-shard `multiFecFlags=0x10` marker from the Reed-Solomon-generated parity byte
- **AND** every data shard SHALL still require `multiFecFlags=0x10`, valid frame flags, and consistent packet sequencing before codec payload admission

#### Scenario: FEC parity gaps do not break data assembly
- **WHEN** parity shards are discarded and their original stream sequence numbers leave gaps between valid data shards
- **THEN** LuneX SHALL assemble a frame by validated FEC block/shard order rather than requiring raw sequence-number contiguity
- **AND** a frame with missing data shards, block-envelope violations, metadata drift, or conflicting shard content SHALL fail closed and request recovery instead of emitting a partial access unit

#### Scenario: End-to-end workflow passes
- **WHEN** the exact candidate completes the full authorized Sunshine workflow with sustained media and actual host-received input
- **THEN** the live session gate may pass only if reconnect, termination, repeated stop, and resource cleanup receipts also pass

### Requirement: native macOS acceptance gate
The macOS candidate SHALL pass native window, display, input, HDR/EDR, audio, product workflow, diagnostics, accessibility, packaging, and quality acceptance before freeze.

#### Scenario: Library reflects the primary user task
- **WHEN** no stream session owns the macOS workspace
- **THEN** the product presents one Library workbench that prioritizes current host availability, host selection, the selected host's application catalog, pairing only when required, and direct launch
- **AND** Stream, Diagnostics, and Settings SHALL NOT occupy equal permanent sidebar destinations
- **AND** an active or recoverable session MAY temporarily own the full content surface while stop or successful teardown returns the user to Library

#### Scenario: Host and catalog state stays current without manual refresh
- **WHEN** a saved or Bonjour-discovered host changes availability while the Library window is alive
- **THEN** LuneX automatically reconciles the host as checking, online, or offline within a bounded polling/discovery interval and updates the selected paired host's catalog without requiring a normal-use refresh action
- **AND** green availability treatment means reachable, pairing/trust is shown separately, cached offline apps do not appear launch-ready, and explicit retry is reserved for an actual failed operation

#### Scenario: Active stream controls prioritize session actions
- **WHEN** a macOS workspace owns an active or connecting stream and its controls are visible
- **THEN** the overlay identifies the selected application and host, summarizes the configured resolution, frame rate, and bitrate, and exposes live pointer-mode, scaling, HDR/EDR, spatial-audio, hide, and disconnect controls
- **AND** pointer, scaling, HDR/EDR, and spatial-audio changes apply through their real runtime paths and persist as preferences
- **AND** a wide macOS stream window presents a width-bounded overlay at the top center below the title bar instead of vertically centering it over remote content
- **AND** when requested spatial audio falls back or fails, the spatial-audio control shows a compact subordinate reason below the switch, while healthy or disabled output does not reserve space for status prose
- **AND** the same spatial-audio reason SHALL NOT be duplicated in the connecting or failure footer
- **AND** normal streaming SHALL NOT use primary overlay space for standalone pointer, SDR, fixed-spatial, entitlement, or general diagnostic-summary labels
- **AND** current output detail remains available to assistive technology and through on-demand Settings or Diagnostics, while a connecting or failed session MAY show the bounded actionable state needed to recover

#### Scenario: Low-frequency support surfaces remain bounded
- **WHEN** the user requests Settings or Diagnostics on macOS
- **THEN** Settings opens through the native application settings affordance with bounded preference groups and persistent changes, while Diagnostics opens on demand with current runtime state and privacy-safe export
- **AND** inactive runtime telemetry, mobile-only continuity state, and unrelated preferences do not create a sparse or unbounded macOS settings layout

#### Scenario: Window and display lifecycle acceptance
- **WHEN** the stream window is occluded, minimized, unfocused, resized, made full screen, or moved across representative displays
- **THEN** rendering and input ownership follow actual visibility/focus, drawable and pointer transforms match the current surface, cursor ownership remains balanced, and the stream resumes without stale presentation

#### Scenario: Relative pointer direction matches remote screen coordinates
- **WHEN** AppKit reports moved or dragged relative pointer deltas on the active macOS stream surface
- **THEN** LuneX converts the vertical delta at the macOS capture boundary so positive Moonlight relative Y moves down and negative Y moves up on the remote screen
- **AND** horizontal relative motion, Direct absolute coordinates, scroll direction, shared input adapters, and non-macOS behavior remain unchanged

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
