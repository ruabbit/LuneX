## ADDED Requirements

### Requirement: Client identity shall be cryptographically valid and persistent
LuneX SHALL generate a Sunshine-compatible client certificate and private key using approved platform cryptography, persist them through the configured identity store, and reuse the same identity until the user explicitly resets it.

#### Scenario: First pairing has no identity
- **WHEN** the user starts pairing and no client identity exists
- **THEN** LuneX SHALL generate, validate, persist, and reload a cryptographically usable identity before presenting a PIN

#### Scenario: Existing identity is available
- **WHEN** LuneX starts after a prior successful identity save
- **THEN** it SHALL reuse the persisted certificate, private key, and client unique ID without generating replacements

### Requirement: Pairing shall execute the authenticated Moonlight exchange
LuneX SHALL execute the version-appropriate PIN, salt, digest, certificate, and challenge-response sequence and SHALL reject any response that cannot be authenticated.

#### Scenario: Pairing succeeds
- **WHEN** the host accepts the PIN and every cryptographic challenge verifies
- **THEN** LuneX SHALL persist the exact server leaf certificate pin and mark the host paired

#### Scenario: Pairing verification fails
- **WHEN** any digest, certificate, signature, or challenge verification fails
- **THEN** LuneX SHALL fail closed, preserve any previously trusted pin, delete incomplete pairing state, and report the failed stage

### Requirement: Pairing cancellation shall be complete
LuneX SHALL cancel outstanding network and cryptographic work when the user dismisses or cancels pairing.

#### Scenario: User cancels during challenge exchange
- **WHEN** the pairing UI is cancelled while a request is in flight
- **THEN** the request SHALL be cancelled and the host SHALL remain unpaired or retain its previously trusted identity
