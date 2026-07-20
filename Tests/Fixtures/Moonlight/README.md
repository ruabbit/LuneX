# Sanitized Moonlight protocol fixtures

This tree contains repository-owned fixtures for deterministic protocol tests. Every fixture must use documentation-only identities and addresses and must pass `python3 Tools/validate_protocol_fixtures.py` before commit.

## Layout

- `pairing/`: cryptographic vectors and redacted pairing responses.
- `rtsp/`: RTSP requests, responses, and session-description samples.
- `control/`: control-channel framing and state transitions.
- `video/`: bounded packet assembly and codec-configuration samples.
- `audio/`: bounded packet framing and decoder input samples.
- `input/`: byte-exact input serialization samples.

## Required metadata

Each fixture set must document its origin class, redaction method, expected parser result, and whether it was generated or captured from an explicitly authorized test session. Raw packet captures are not committed.
