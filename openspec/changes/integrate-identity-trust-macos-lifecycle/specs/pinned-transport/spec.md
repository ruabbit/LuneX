## ADDED Requirements

### Requirement: Moonlight HTTPS shall require the pinned leaf certificate
HTTPS requests to paired hosts SHALL authenticate the server by exact comparison with the persisted leaf certificate.

#### Scenario: Server certificate matches
- **WHEN** the TLS server leaf certificate exactly matches the host pin
- **THEN** the client SHALL accept the authentication challenge

#### Scenario: Server certificate is missing or mismatched
- **WHEN** no pin exists or the presented leaf differs from the pin
- **THEN** the client SHALL cancel authentication and report a structured transport error

### Requirement: Trust-all TLS shall not be used
The client SHALL NOT globally disable certificate validation or accept an arbitrary self-signed certificate.

#### Scenario: Unpinned self-signed server responds
- **WHEN** an HTTPS endpoint presents a certificate that was not pinned during pairing/import
- **THEN** the connection SHALL fail closed
