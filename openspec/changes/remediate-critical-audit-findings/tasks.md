## 1. Runtime integrity

- [x] 1.1 Add explicit pairing and stream transport availability to the app model
- [x] 1.2 Prevent placeholder pairing from mutating host state or pinned identities
- [x] 1.3 Prevent launch requests and `Streaming` state while media transport is unavailable
- [x] 1.4 Stop plaintext private-key fixture output and remove the legacy generated copy

## 2. Compact navigation

- [x] 2.1 Add compact tab navigation with Library as the initial screen
- [x] 2.2 Make Add Host reachable from compact Library
- [x] 2.3 Stack Library panels vertically at compact widths
- [x] 2.4 Disable unavailable pairing and launch controls with honest status text

## 3. Verification and tracking

- [x] 3.1 Add regression tests for fail-closed pairing and launch behavior
- [x] 3.2 Validate OpenSpec and run the macOS test suite
- [x] 3.3 Build macOS, fixed iPhone, tvOS, and visionOS targets without duplicate simulators
- [x] 3.4 Run and visually verify the fixed iPhone compact UI
- [ ] 3.5 Update planning files, commit, and push the first remediation batch
