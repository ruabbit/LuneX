## ADDED Requirements

### Requirement: Production identity storage shall use Keychain
Non-Debug application builds SHALL store client identity material in Keychain using device-local accessibility.

#### Scenario: Release identity is saved
- **WHEN** a non-Debug build persists client identity material
- **THEN** the identity SHALL be written through `KeychainClientIdentityStore`

### Requirement: Iterative Debug testing shall support a private file fallback
Debug builds SHALL support a test-only file identity store that does not require repeated Keychain authorization.

#### Scenario: Debug identity is saved
- **WHEN** a Debug build persists client identity material after Keychain verification
- **THEN** it SHALL write the test-only identity file under Application Support with mode `0600`

### Requirement: Real Keychain tests shall be opt-in
The test suite SHALL access the real Keychain only when an explicit integration-test environment variable is enabled.

#### Scenario: Normal tests run
- **WHEN** `LUNEX_RUN_KEYCHAIN_TEST` is not `1`
- **THEN** the real Keychain round-trip test SHALL be skipped

#### Scenario: Authorized Keychain verification runs
- **WHEN** `LUNEX_RUN_KEYCHAIN_TEST=1`
- **THEN** the test SHALL save, load, compare, and delete a unique Keychain identity item
