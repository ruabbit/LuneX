## 1. Color and luminance contract foundation

- [x] 1.1 Inventory current decoded formats, metadata ownership, renderer behavior, Apple EDR APIs, platform capability differences, and hardware proof limits without changing runtime behavior
- [ ] 1.2 Define immutable render color signatures, display revisions, platform output capabilities, mapping modes, surface contracts, and closed resolution errors
- [ ] 1.3 Implement decoded pixel-format, plane, bit-depth, range, codec, primaries, transfer, matrix, and metadata compatibility validation
- [ ] 1.4 Implement platform-neutral video-range normalization, Rec.709/BT.2020 matrices, SDR transfer, ST 2084 PQ, gamut conversion, and finite-bound reference math
- [ ] 1.5 Implement mastering/MaxCLL source-peak resolution and a monotonic reference-white-preserving EDR/SDR shoulder bounded by current headroom
- [ ] 1.6 Add deterministic invalid-combination, known-vector, monotonicity, continuity, gamut, missing-metadata, headroom, and numeric-bound tests

## 2. Generation-owned decoded and Metal frame contract

- [ ] 2.1 Bind immutable color signatures and render-configuration compatibility to decoded and mapped Metal frames without duplicating raw metadata ownership
- [ ] 2.2 Make the Metal mapper validate 8-bit and 10-bit CoreVideo plane layouts, Metal formats, dimensions, device ownership, and color signatures
- [ ] 2.3 Extend the bounded frame queue to reject stale color/display revisions and flush incompatible frames on generation or render-contract changes
- [ ] 2.4 Add SDR/HDR mapping, layout mismatch, stale generation/revision, replacement, cache flush, and teardown tests

## 3. Explicit Metal color and tone-mapping pipeline

- [ ] 3.1 Add repository-owned Metal shader resources for video-range sampling, YCbCr conversion, transfer decoding, gamut conversion, luminance mapping, and opaque output
- [ ] 3.2 Add typed shader uniforms and a bounded pipeline-state cache keyed by input layout, mapping mode, and output pixel format
- [ ] 3.3 Implement an injectable generation/revision-owned Metal video renderer using zero-copy luma/chroma planes and explicit viewport/video-rectangle presentation
- [ ] 3.4 Add offscreen shader readback tests against CPU reference vectors for black, reference white, primaries, near-black, peak highlights, SDR fallback, and finite bounds
- [ ] 3.5 Replace fixed-sRGB Core Image production presentation with the explicit renderer while retaining deterministic clear, fit/fill, throttled, pause, and stale-frame behavior
- [ ] 3.6 Add presenter configuration, pipeline failure, drawable mismatch, resize, pause/resume, replacement, and resource-release tests

## 4. Display, surface, and headroom adaptation

- [ ] 4.1 Implement injectable platform surface adapters that atomically apply SDR or EDR drawable format, colorspace, and extended-range intent only where supported
- [ ] 4.2 Extend lifecycle/display state with monotonic display revisions and semantic headroom updates independent from stream HDR state
- [ ] 4.3 Resolve one active surface/render configuration from stream metadata, user preference, platform capability, actual display headroom, drawable state, and decoder generation
- [ ] 4.4 Clear incompatible presentation and rebuild surface/pipeline state across screen, backing, headroom, metadata, user-setting, stop, and replacement transitions
- [ ] 4.5 Add macOS screen/headroom, same-display headroom, stale-window, surface transition, SDR-on-EDR, HDR-on-SDR, HDR-on-EDR, and teardown tests
- [ ] 4.6 Add compile-safe iOS/iPadOS, tvOS, and visionOS capability adapters with explicit unsupported/fallback results rather than AppKit assumptions

## 5. Application, diagnostics, and product integration

- [ ] 5.1 Connect negotiated/decoded color metadata and lifecycle headroom through `AppModel`, media environment, presentation source, actual stream surface, and active renderer revision
- [ ] 5.2 Derive HDR/EDR eligibility from active session, user preference, valid source contract, platform support, display capability, and current headroom without synthetic settings fallback
- [ ] 5.3 Publish deduplicated privacy-bounded active-SDR, active-EDR, SDR-fallback, invalid-input, unsupported-output, stale-revision, and pipeline-failure diagnostics with scoped recovery clearing
- [ ] 5.4 Add an application integration gate covering SDR presentation, HDR EDR mapping, headroom downgrade/recovery, metadata change, cross-display revision, stale-frame rejection, and clean stop
- [ ] 5.5 Add accessibility-safe native stream status/settings presentation for current HDR mode and fallback without exposing raw metadata, frame values, host identity, or display identifiers

## 6. Verification and tracking

- [ ] 6.1 Run normal tests with live-host and real-Keychain paths disabled and verify the only allowed skip
- [ ] 6.2 Build macOS Debug/Release and fixed iPhone, iPad, tvOS, and visionOS targets with warnings as errors and isolated DerivedData
- [ ] 6.3 Run OpenSpec strict, generator, clean-room/dependency, Metal compilation, static analyzer, ASan, TSan, malloc ownership, and renderer resource-release gates
- [ ] 6.4 Verify fixed simulator identities remain unique and `Shutdown` without creating or explicitly booting devices
- [ ] 6.5 Validate SDR-on-HDR, HDR-on-SDR, HDR-on-HDR, current-headroom changes, and cross-display transitions on authorized physical displays with redacted reference-pattern or measurement evidence
- [ ] 6.6 Update planning and roadmap evidence, document platform/hardware limits, commit each completed task, and push
