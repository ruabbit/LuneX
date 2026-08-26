# macOS Sunshine Live Acceptance Matrix

## Evidence Boundary

This document is the execution and evidence authority for M1 Tasks 2.2 and
2.3. Host and application names are retained because they identify the actual
test target and are not secrets in this environment. Repository evidence must
still exclude private keys, certificate bytes, credentials, tokens, pairing
material, and unreviewed raw payloads or logs.

Inventory timestamp: `2026-08-26 04:48 CST`

Repository candidate at inventory time:

- Git SHA: `11a9b8502d52f5d9a6c2cee86b32c238e6380621`
- Branch/remote: `main`, `git@github.com:ruabbit/LuneX.git`
- Build tier: unsigned deterministic/generic-build evidence only
- Client hardware: Mac Studio (`Mac13,2`), Apple M1 Ultra, 20 cores, 128 GB
- Client software: macOS `27.0 (26A5416b)`, Xcode `26.4 (17E192)`, Swift `6.3`

The inventory used existing imported LuneX/Moonlight host and catalog records
plus bounded reads of configured endpoints. It did not perform discovery,
pairing, unpairing, catalog refresh, launch, resume, cancel, input delivery,
configuration changes, Simulator operations, Keychain access, signing, or
physical acceptance.

## Compatibility Policy

LuneX does not use a Sunshine package-version allowlist. Compatibility is
determined from server-advertised Moonlight/GameStream protocol and codec
capabilities, the requirements selected during negotiation, and observed live
behavior. A Sunshine package version may be attached to a defect or acceptance
receipt when readily available, but an unknown or previously unseen package
version is not a reason to reject a host or block Task 2.3.

## Host And Catalog Inventory

| Host | Read-only status | Cached applications | Interpretation |
|---|---|---|---|
| `PC-20260610OBZH` | Configured endpoint timed out | `Desktop`, `Steam Big Picture` | Expected offline result; only one of the three imported hosts was online |
| `tanmy-deck` | Configured endpoint timed out | `Desktop` | Expected offline result; not a failure or Task 2.2 blocker |
| `tanmy-white` | GameStream endpoint accepted TCP and returned HTTP `200` from `GET /serverinfo` | `Desktop`, `Steam Big Picture`, `War Thunder` | Sole online candidate; selected for Task 2.3 |

`Desktop` is the designated non-destructive Task 2.3 application on
`tanmy-white`. Its cached presence was directly verified; it is not an unknown
or arbitrary application requiring a separate approval gate.

## tanmy-white Capability Inventory

| Field | Read-only result | Status |
|---|---|---|
| Imported trust state | Previously imported paired record with a persisted server certificate pin | Existing state reused; not rewritten |
| Certificate continuity | Sunshine Web TLS peer certificate SHA-256 matched the imported pin | Pin match proved |
| GameStream protocol version | Server-advertised `appversion` `7.1.431.-1` | Capability/diagnostic field recorded |
| Compatibility field | Server-advertised `GfeVersion` `3.23.0.74` | Capability/diagnostic field recorded |
| Video codec modes | `0x00070301`: H.264, HEVC Main8/Main10, AV1 Main8/Main10, H.264 High8 4:4:4 | Advertised capability recorded |
| HEVC luma limit | `1869449984` | Advertised capability recorded |
| Sunshine package version | Not exposed by the read-only unauthenticated pinned endpoints | Not required; optional diagnostic metadata only |
| Host state | Server reported busy with a nonzero current-game identifier during inventory | Wait for the existing session to end before Task 2.3; not a Task 2.2 failure |
| Web configuration API | Pinned TLS succeeded; unauthenticated `GET /` and `GET /api/config` returned `401` | No credentials guessed, requested, or retrieved |

## M1 Live Matrix

| Scenario | Required observation | Current result |
|---|---|---|
| Host inventory | `tanmy-white` advertised protocol/codec modes and host-free precondition | Capabilities recorded; host was busy at inventory time |
| Pairing or identity reuse | Existing isolated LuneX identity authenticates, or one bounded pairing operation completes, without changing unrelated clients | Moonlight-qt identity imported and validated locally; production pinned HTTPS now loads and presents it for mTLS, but live authentication has not run |
| Catalog | Live pinned HTTPS catalog succeeds and contains `Desktop` | 2026-08-26 18:03 CST: the corrected production URL reached `:47989` and returned `SUNSHINE_SERVER_BUSY` with current `Desktop` in 0.020 seconds; the gate skipped before catalog, so cached `Desktop` is not counted as live evidence |
| Launch | Exactly one `Desktop` session launches through the production runtime | Not run |
| RTSP negotiation | Launch URL, DESCRIBE, audio/video/control SETUP, negotiated endpoints, and control readiness succeed | Not run |
| Sustained video | Decoded and presented frames remain continuous for the fixed duration; frame/loss counters are recorded | Not run |
| Audible synchronized audio | Audio is audible, synchronized, and stops cleanly on the selected route | Not run |
| Remote input and feedback | Harmless keyboard, pointer, scroll, controller, and feedback sequence is observed in `Desktop` | Not run |
| Reconnect | One bounded interruption uses fresh authenticated material and resumes without a second launch | Not run |
| Remote termination | Host-side termination is observed without redundant remote cancel | Not run |
| Repeated stop | Local stop is repeated and remains idempotent | Not run |
| Clean teardown | Socket/task/decoder/audio/input/resource ownership returns to zero and relaunch remains possible | Not run |

## Task 2.3 Preconditions

Task 2.3 may start only after all of these are true:

1. `tanmy-white` reports free and the existing unrelated session has ended
   without LuneX intervention.
2. Reuse the imported Moonlight-qt identity from the Debug file fallback. The
   fallback has passed local Codable, certificate/private-key match, and
   signing verification. Live mTLS authentication remains pending; perform one
   bounded pairing operation only if certificate reuse fails. No existing
   client may be removed or disabled.
3. The harmless input sequence, reconnect interruption, remote-termination
   action, sustained-media duration, and abort conditions are fixed before the
   first `Desktop` launch.

A Sunshine package version is not a precondition. The two expected offline-host
timeouts are not preconditions or failures either.

## Explicit Live Harness

`AppModelWorkflowTests.testLiveTanmyWhiteProductionAcceptanceWhenExplicitlyEnabled`
is the only automated Task 2.3 entry point. It hard-codes the persisted
`tanmy-white` host ID, name, and address plus the exact `Desktop` app ID and
name. With neither opt-in set it skips before loading local state. The normal
suite therefore keeps both live variables unset.

The catalog-only gate performs exactly one HTTP server-info preflight. A busy
host skips before catalog; an unreachable or malformed response fails. Only a
free host proceeds to the production pinned-mTLS catalog client. The catalog
snapshot repository is in memory so the gate does not rewrite hosts, settings,
catalog, or identity files:

```bash
LLVM_PROFILE_FILE=/private/tmp/LuneX-live-catalog-%p.profraw \
LUNEX_RUN_LIVE_HOST_TEST=1 \
xcrun xctest \
  -XCTest AppModelWorkflowTests/testLiveTanmyWhiteProductionAcceptanceWhenExplicitlyEnabled \
  /path/to/DerivedData/Build/Products/Debug/LuneXCoreTests.xctest
```

The `Desktop` session is admitted only when both exact opt-ins equal `1`:

```bash
LLVM_PROFILE_FILE=/private/tmp/LuneX-live-session-%p.profraw \
LUNEX_RUN_LIVE_HOST_TEST=1 \
LUNEX_RUN_LIVE_DESKTOP_SESSION=1 \
xcrun xctest \
  -XCTest AppModelWorkflowTests/testLiveTanmyWhiteProductionAcceptanceWhenExplicitlyEnabled \
  /path/to/DerivedData/Build/Products/Debug/LuneXCoreTests.xctest
```

That automated session observes production launch/negotiation, streaming state,
decoded-frame growth, a running audio runtime, a no-button relative-pointer
`+1/-1` round trip, input release, one remote cancel, repeated local stop, and
observable model teardown. It does not prove that audio was physically audible
and synchronized, that the host visibly received the pointer movement, or that
real reconnect and host-side termination worked. Those rows remain manual live
acceptance requirements even if the automated session passes.

The first actual catalog-only run at 17:41 CST on 2026-08-26 inherited the
explicit opt-in and made one request. Its retained NSError shows the generated
URL was `http://10.1.100.69/serverinfo`, without Sunshine's `:47989`, so it
reached TCP 80 and timed out at the five-second boundary. This was an endpoint
construction defect, not evidence that the host was unreachable or that TCC
denied the request. No pinned catalog, launch, resume, cancel, stop, or input
request followed, and the four local data-file hashes and modes were unchanged.

At 17:51 CST, one read-only terminal request to the correct
`http://10.1.100.69:47989/serverinfo` endpoint returned HTTP `200` and reported
`SUNSHINE_SERVER_BUSY` with current game `881448767` (`Desktop`). LuneX did not
send catalog or session operations and must wait for that session to end
naturally. The endpoint fix keeps the UI/persistence form unchanged while
always including the actual port in the network URL. The macOS product also
declares its Local Network purpose and `_nvstream._tcp` Bonjour browse type;
final live evidence must still run under the actual app's stable signed identity
rather than treating a bare ad-hoc XCTest bundle as product TCC acceptance.

After the endpoint and product-privacy fix, the one permitted corrected
catalog-only preflight ran at 18:03 CST from a fresh Debug test product. It
reached the production `serverInfoURL` on `:47989`, received
`SUNSHINE_SERVER_BUSY` with current game `881448767`, and skipped in 0.020
seconds before pinned catalog. The four local state-file hashes and modes were
identical before and after. This proves the corrected URL is reachable in the
direct test context; it does not substitute for stable signed-App TCC or live
catalog/session acceptance.

## Debug Identity Reuse

Normal Debug testing uses the file fallback and does not access Keychain. The
existing Moonlight-qt client identity is imported explicitly and without
rewriting current LuneX hosts, settings, or catalog data:

```bash
python3 Tools/import_moonlight_qt_data.py \
  --include-client-identity \
  --identity-only
```

Without `--include-client-identity`, the importer does not copy private-key
material. `--identity-only` is rejected unless the explicit identity flag is
also present. The importer converts the Qt PKCS#8 PEM private key to the DER
format consumed by Security, checks the certificate/private-key public-key
match and expected subject, then atomically writes
`~/Library/Application Support/LuneX/client_identity.debug.json`. The directory
mode is `0700` and the file mode is `0600`.

Local acceptance on 2026-08-26 proved Foundation decoding, Security certificate
and private-key parsing, matching public keys, a fresh signature/verification
round trip, and the expected certificate subject. The production pinned HTTPS
executor now requires this persisted identity, validates it before network
access, preserves the server leaf pin, and answers the client-certificate TLS
challenge for catalog, artwork, launch, resume, and cancel. Deterministic tests
also prove missing or invalid material fails before network access. This is
local identity and production-wiring evidence only. It does not prove Sunshine
accepted the mTLS identity; the live matrix row remains pending until the host
is free and pinned catalog access succeeds through the production provider.

## Permitted And Prohibited Operations

Permitted for the explicit Task 2.3 gate:

- bounded pinned reads of `tanmy-white` server info and live app catalog;
- at most one identity operation if the imported identity cannot authenticate;
- exactly one initial launch of `Desktop`;
- the predeclared harmless input sequence and one bounded reconnect scenario;
- local stop, one remote termination, repeated local stop, and teardown
  verification.

Prohibited:

- host discovery or scanning outside persisted configured endpoints;
- `unpair-all`, removal, or disablement of unrelated clients;
- Sunshine app/config/password edits, restart, service changes, OS settings,
  display changes, or driver installation;
- launching a non-`Desktop` application during this matrix or interrupting the
  session that was already active during inventory;
- copying credentials, private keys, certificate bytes, tokens, pairing
  material, or unreviewed raw payloads/logs into the repository.

## Evidence Format

Every result must bind to the exact Git SHA and include start/end time,
environment class, host name, application name, scenario identifier, bounded
counts/durations, typed result, and cleanup outcome. Evidence may include
`tanmy-white`, `Desktop`, server-advertised protocol/software fields, codec
names, dimensions, frame/audio/input counters, and stable error codes. It must
exclude credentials, private keys, certificate bytes, tokens, pairing material,
and unreviewed raw payloads or logs.
