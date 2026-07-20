# Clean-room runtime boundary

## Production rule

LuneX production targets shall contain independently written Swift/Objective-C bridging code and Apple platform frameworks. GPL Moonlight repositories are behavioral references only. No GPL source file, compiled object, generated protocol implementation, or linked library may enter the production target without a separate license and distribution decision approved in OpenSpec.

## Allowed evidence

- Publicly observable network behavior and protocol fields.
- Apple SDK headers and documentation.
- Sanitized byte fixtures captured from an explicitly authorized local Sunshine host.
- Independently written parsers, serializers, state machines, tests, and documentation.
- Small protocol constants documented with their meaning and validated against observable behavior.
- Permissively licensed dependencies only after license, maintenance, platform, and API-surface review.

## Forbidden transfer

- Copying functions, structs, comments, or control flow from `moonlight-common-c`, Moonlight iOS, or Moonlight Qt into `Sources/`.
- Linking or embedding GPL libraries in any LuneX application target under the current distribution decision.
- Committing client keys, host certificates, PINs, tokens, credentials, host addresses, unique IDs, or unredacted packet captures.
- Treating upstream tests as repository-owned clean-room fixtures.

## Current dependency inventory

- The generated Xcode project has no Swift Package Manager product dependency.
- The production source list contains no `moonlight-common-c`, libopus, FFmpeg, SDL, or Qt source or binary.
- `references/` is excluded from Git and Xcode target generation.
- Current application code uses Apple frameworks, repository-owned Swift/C bridge sources, and the reviewed MIT ENet control-transport dependency recorded in `dependency-decisions.md`.

## Review gate for a new dependency

Before adding a dependency, record:

1. The exact package and version.
2. License and required notices.
3. Why an Apple framework or small repository-owned implementation is insufficient.
4. Platforms and architectures supported.
5. The minimal wrapped API surface.
6. Update, vulnerability, and removal strategy.

The identity ASN.1 and Opus decisions remain open until their bounded spikes complete.
