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
| Host state | Server reported busy with `currentgame=881448767`, matching `Desktop` | Valid Task 2.3 `/resume` target; busy describes application state, not exclusive client ownership |
| Web configuration API | Pinned TLS succeeded; unauthenticated `GET /` and `GET /api/config` returned `401` | No credentials guessed, requested, or retrieved |

## M1 Live Matrix

| Scenario | Required observation | Current result |
|---|---|---|
| Host inventory | `tanmy-white` advertised protocol/codec modes and current application state | Capabilities recorded; matching busy `Desktop` permits a concurrent `/resume` session |
| Pairing or identity reuse | Existing isolated LuneX identity authenticates, or one bounded pairing operation completes, without changing unrelated clients | Passed at 18:14 CST: the imported Moonlight-qt identity completed live production pinned-mTLS authentication without pairing or local-state mutation |
| Catalog | Live pinned HTTPS catalog succeeds and contains `Desktop` | Passed at 18:14 CST: production `/applist` became current and contained exactly one matching `Desktop` entry with app ID `881448767` |
| Initial session | Exactly one `Desktop` client session starts through production `/launch` or `/resume` routing | Passed on exact SHA `05aa877`: matching busy selected one `/resume`, zero `/launch`, zero `/cancel` |
| RTSP negotiation | Launch URL, DESCRIBE, audio/video/control SETUP, negotiated endpoints, and control readiness succeed | Passed on exact SHA `05aa877`: ANNOUNCE, PLAY, ENet, negotiated configuration, control readiness, and video color metadata completed |
| Sustained video | Decoded and presented frames remain continuous for the fixed duration; frame/loss counters are recorded | Failed before streaming on exact SHA `05aa877`; the UDP complete-message defect now passes deterministic gates in the current candidate, with exact-SHA live confirmation still pending |
| Audible synchronized audio | Audio is audible, synchronized, and stops cleanly on the selected route | Not run |
| Remote input and feedback | Harmless keyboard, pointer, scroll, controller, and feedback sequence is observed in `Desktop` | Not run |
| Reconnect | One bounded interruption uses fresh authenticated material and resumes without a second launch | Not run |
| Remote termination | Host-side termination is observed without redundant remote cancel | Not run |
| Repeated stop | Local stop is repeated and remains idempotent | Not run |
| Clean teardown | Socket/task/decoder/audio/input/resource ownership returns to zero and relaunch remains possible | Not run |

## Task 2.3 Preconditions

The read-only catalog portion may run while the host is busy. A `Desktop`
session may start after all of these are true:

1. `tanmy-white` is reachable and reports either free or busy with
   `currentgame=881448767`. Free selects `/launch`; matching busy selects
   `/resume`. A different current application is rejected without `/cancel`.
2. Reuse the imported Moonlight-qt identity from the Debug file fallback. The
   fallback has passed local Codable, certificate/private-key match, and
   signing verification plus live production pinned-mTLS catalog
   authentication. Do not pair again unless a later authenticated request
   actually rejects this identity. No existing client may be removed or
   disabled.
3. The harmless input sequence, reconnect interruption, remote-termination
   action, sustained-media duration, and abort conditions are fixed before the
   first `Desktop` launch or resume.
4. Normal disconnect, consumer cancellation, replacement, and local failure
   cleanup release only this client's resources. They must issue zero Sunshine
   `/cancel` requests; quitting the shared remote application is a separate,
   explicitly confirmed action and is not part of the automated session stop.

A Sunshine package version is not a precondition. The two expected offline-host
timeouts are not preconditions or failures either.

## Explicit Live Harness

`AppModelWorkflowTests.testLiveTanmyWhiteProductionAcceptanceWhenExplicitlyEnabled`
is the only automated Task 2.3 entry point. It hard-codes the persisted
`tanmy-white` host ID, name, and address plus the exact `Desktop` app ID and
name. With neither opt-in set it skips before loading local state. The normal
suite therefore keeps both live variables unset.

The catalog-only gate performs exactly one HTTP server-info preflight. An
unreachable or malformed response fails. A correctly identified host proceeds
to the production pinned-mTLS catalog client even when busy because `/applist`
is read-only and does not alter the existing session. The catalog snapshot
repository is in memory so the gate does not rewrite hosts, settings, catalog,
or identity files:

```bash
LLVM_PROFILE_FILE=/private/tmp/LuneX-live-catalog-%p.profraw \
LUNEX_RUN_LIVE_HOST_TEST=1 \
xcrun xctest \
  -XCTest AppModelWorkflowTests/testLiveTanmyWhiteProductionAcceptanceWhenExplicitlyEnabled \
  /path/to/DerivedData/Build/Products/Debug/LuneXCoreTests.xctest
```

The `Desktop` session is admitted only when both exact opt-ins equal `1`.
Server state then selects `/launch` for free or `/resume` for matching busy
`Desktop`; it is not used as a global connection-availability gate:

```bash
LLVM_PROFILE_FILE=/private/tmp/LuneX-live-session-%p.profraw \
LUNEX_RUN_LIVE_HOST_TEST=1 \
LUNEX_RUN_LIVE_DESKTOP_SESSION=1 \
xcrun xctest \
  -XCTest AppModelWorkflowTests/testLiveTanmyWhiteProductionAcceptanceWhenExplicitlyEnabled \
  /path/to/DerivedData/Build/Products/Debug/LuneXCoreTests.xctest
```

That automated session observes production launch-or-resume negotiation,
streaming state,
decoded-frame growth, a running audio runtime, a no-button relative-pointer
`+1/-1` round trip, input release, zero remote cancels, repeated local stop, and
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
send catalog or session operations. The earlier conclusion that LuneX had to
wait for that application to end was invalidated: this matching busy state is a
valid `/resume` target for another client session. The endpoint fix keeps the
UI/persistence form unchanged while
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

The 18:12 CST continuation preflight again returned
`SUNSHINE_SERVER_BUSY/currentgame=881448767` and skipped before catalog under
the original conservative gate. That result prompted the narrower admission
rule above. The further assumption that busy must block the session tier was
also invalidated after upstream Qt, iOS, and Sunshine source review: matching
busy selects `/resume`, while normal local stop never selects `/cancel`.

At 18:14 CST, the revised catalog-only gate passed through the production
pinned HTTPS provider in 0.053 seconds. The test requires server-info to
identify `tanmy-white`, requires the production catalog to become current with
no catalog issue, and requires exactly one app matching ID `881448767` and name
`Desktop`; therefore the passing result proves the imported Moonlight-qt
identity was accepted for live mTLS and `/applist` returned that exact entry.
The in-memory catalog repository prevented persistence, and SHA-256 plus mode
receipts for `hosts.json`, `settings.json`, `app_catalog.json`, and
`client_identity.debug.json` were identical before and after. No launch,
resume, input, cancel, or stop path ran. This direct XCTest evidence still does
not prove Local Network TCC acceptance by the actual App under a stable signing
identity.

After the catalog-admission batch was committed and pushed as
`f9cefd74f8584de123541724b952e4b0d4650208`, one bounded read-only preflight
again identified `tanmy-white` as `SUNSHINE_SERVER_BUSY` with current game
`881448767`. The double-opt-in session gate was therefore not run under the
then-current, now-invalidated free-host gate, and no
launch, input, cancel, or stop request was sent. M1 remains at Task 2.3 until
the matching busy `Desktop` session passes the corrected `/resume` live matrix.

The third bounded session attempt was run from exact pushed SHA
`74056ca92d1067742969496ab83517e3c7db6494`. Its production recorder reported
`launch=0`, `resume=1`, `cancel=0`, and session-control stage
`launch_accepted`, followed by `NetworkChannelError.posixFailure(96)` before
`rtspReady`. Darwin errno 96 is `ENODATA`. This is positive live evidence that
Sunshine accepted the additional-client `/resume`; it is not a busy-host or
concurrency rejection. The remaining failure is in the first RTSP transaction:
LuneX reused one TCP channel while Sunshine closes each RTSP response
connection, and its Network.framework adapter could discard response bytes
when terminal error and data arrived together. A further live attempt is held
until the per-transaction connection and terminal-byte behavior pass fresh
deterministic and build gates.

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
also prove missing or invalid material fails before network access. The 18:14
CST live catalog acceptance proves Sunshine accepted this identity for the
production pinned-mTLS `/applist` request. It does not yet prove authenticated
launch/resume/cancel, a full session, or Local Network TCC acceptance by the
actual App under a stable signing identity.

## Permitted And Prohibited Operations

Permitted for the explicit Task 2.3 gate:

- bounded pinned reads of `tanmy-white` server info and live app catalog;
- at most one identity operation if the imported identity cannot authenticate;
- exactly one initial `/launch` when free or `/resume` when `Desktop` is already
  running;
- the predeclared harmless input sequence and one bounded reconnect scenario;
- local stop with zero `/cancel`, one host-side remote termination, repeated
  local stop, and teardown verification.

Prohibited:

- host discovery or scanning outside persisted configured endpoints;
- `unpair-all`, removal, or disablement of unrelated clients;
- Sunshine app/config/password edits, restart, service changes, OS settings,
  display changes, or driver installation;
- launching a non-`Desktop` application during this matrix or interrupting the
  session that was already active during inventory;
- calling `/cancel` as part of disconnect, cancellation, replacement, failure
  cleanup, or automated teardown;
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

## Exact-SHA RTSP Close-Delimited Receipt

The next bounded session attempt ran from exact pushed SHA
`92e9d9e7fb19ecda0361f6d0fd5d2253a0ae7b16`. The production recorder reported
`launch=0`, `resume=1`, `cancel=0`, `controlEvents=launch_accepted`, and
`controlFailure=SunshineRTSPNegotiationError.descriptionTooLarge`. This proves
the per-request connection and terminal-byte fix advanced past the preceding
first-transaction `ENODATA(96)`: Sunshine accepted `/resume`, and RTSP OPTIONS
and DESCRIBE transport completed. It does not prove a negotiated session or any
video, audio, input, reconnect, termination, or repeated-stop acceptance row.

The new failure is a plaintext response-delimiting defect. Sunshine's DESCRIBE
response omits `Content-Length` and uses closure of that request's TCP
connection to delimit the SDP payload. LuneX currently publishes the response
as soon as its headers are complete, so the generic parser supplies an empty
body and later SDP bytes are discarded. The session-description parser then
mislabels that empty body as `descriptionTooLarge`. The fix must preserve exact
`Content-Length` semantics when the header exists, accumulate absent-length
plaintext bodies through peer close, and leave encrypted RTSP frame-length
handling unchanged.

The wrapper for this attempt used `xctest ... | tee` without `pipefail`; its
shell exit `0` was therefore the status of `tee`, while XCTest itself clearly
reported failure. This receipt is recorded as a failed live attempt. It will
not be rerun, and subsequent live wrappers must propagate the upstream XCTest
exit status with `set -o pipefail` or an equivalent explicit status capture.

The close-delimited fix was committed and pushed as exact SHA
`c105414288ce3b2978f839ecf697c7d9b81a52da`. A fresh warnings-as-errors live
bundle build had zero structured errors, warnings, or analyzer warnings. Its
single double-opt-in session gate used `pipefail` and correctly returned XCTest
exit `1` after 11.507 seconds. The receipt was `launch=0`, `resume=1`,
`cancel=0`, `controlEvents=launch_accepted,rtsp_ready`, and
`controlFailure=ENetTransportError.connectionFailed`.

This is positive exact-SHA evidence that close-delimited DESCRIBE processing is
fixed: OPTIONS, DESCRIBE, all three SETUP transactions, SDP parsing, and
negotiated port extraction completed. The next isolated failure is the ENet
control-channel connection. The four local state files retained identical
mode, size, and SHA-256 before and after the attempt, and no xctest process
remained. This exact attempt must not be rerun before the ENet stage is fixed.

## Exact-SHA ANNOUNCE And PLAY Receipt

The ANNOUNCE/PLAY fix was committed and pushed as exact SHA
`05aa8771a15446ae82d925782fc6947b9dc4901b`. A fresh warnings-as-errors live
bundle build had zero structured errors, warnings, or analyzer warnings. The
single double-opt-in session gate used `pipefail`, returned XCTest exit `1`
after 4.703 seconds, and recorded `launch=0`, `resume=1`, `cancel=0`,
`controlEvents=launch_accepted,rtsp_ready,negotiated,channels_1,video_color_metadata`,
and `controlFailure=none`.

This proves the production path completed pinned-mTLS catalog, matching-busy
`/resume`, OPTIONS, DESCRIBE, all three SETUP transactions, ANNOUNCE, PLAY,
ENet control connection, negotiated session publication, control readiness,
and video color metadata publication. It does not prove streaming, decoded
video, audible audio, input delivery, reconnect, host-side termination, or
repeated-stop acceptance. The automated failure cleanup issued zero `/cancel`,
all four local state files retained identical `0600` mode, size, and SHA-256,
and no xctest process remained.

The next deterministic defect is in the generic byte-channel state machine.
Network.framework reports `isComplete=true` for each complete UDP datagram,
but LuneX interpreted that flag as TCP end-of-stream and changed the media
channel to `closed`; the following receive therefore failed before media could
become ready. TCP must retain its current close semantics, while UDP complete
messages must leave the channel ready for subsequent datagrams. No further
live attempt is permitted until this transport distinction passes fresh tests,
normal regression, product builds, and repository gates on a new exact SHA.

The current repair passes that deterministic boundary: focused network-channel
tests are `17/17`, the related media/session matrix is `225 total / 224 passed /
1 explicit live skip / 0 failed`, and macOS normal is `1311 total / 1309 passed /
2 explicit opt-in skips / 0 failed`. All associated structured build diagnostics
are zero, five product compatibility builds succeed, both macOS executables are
universal `x86_64 arm64`, the project generator is stable, and the repository
gate ends in `FINAL_UDP_REPOSITORY_GATE_OK`. These results do not replace the
next single bounded exact-SHA live attempt or any still-pending Task 2.3 row.
