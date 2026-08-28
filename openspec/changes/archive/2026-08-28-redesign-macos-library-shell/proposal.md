## Why

A visual review of the running macOS client (2026-08-28, Debug build on macOS 26) found that the current shell is organized around internal subsystems instead of the user task "pick a host, pick an app, play":

- The sidebar presents Library, Stream, Diagnostics, and Settings as four permanent peer destinations. Selecting Stream with no session shows an entirely black, empty content area with no state message.
- The Library is a rigid 2x2 dashboard of four co-equal panels (Hosts, Apps, Pairing, Launch). Pairing is a once-per-host transient flow but permanently occupies a quadrant and keeps showing stale "Pairing complete" text. Launch is five read-only rows plus the app's primary call to action, which sits below the fold at the default window size.
- The Settings form renders in the legacy macOS columnar layout (no grouped form style): controls collapse into the right half of the window, trailing text clips at the window edge, and unrelated mobile-only status rows ("Scene", "Picture in Picture", "Background continuity") pad the macOS surface with "No session" noise. A "Save Settings" button contradicts the macOS convention of immediately applied preferences.
- Host rows show reachability as steady-state "Unknown" text and duplicate the paired state (green badge plus green "Paired" text). Host management is a permanent row of four buttons including rare destructive actions (Reset Trust, Remove).
- Selected app tiles express selection three ways (accent border, tint, and an in-tile "Selected" caption) which also makes tile heights unequal; a whole non-interactive panel can take keyboard focus and draws a container-sized focus ring; the toolbar carries a permanently disabled Disconnect button when no session exists.

The governance requirement "Library reflects the primary user task" (`macos-first-delivery-governance`) already rules out a permanent screen-category sidebar, but it is too coarse for implementation. This change specifies the target macOS shell precisely enough to implement and test.

## What Changes

- Replace the screen-category sidebar with a host-centric library shell: the sidebar lists hosts; the content area shows the selected host's app catalog; launching is a direct action on an app tile.
- Make pairing a contextual flow that appears in the content area only while the selected host needs pairing or a pairing attempt is active, and disappears when finished.
- Make the stream a mode, not a place: an active session takes over the owning window's full content surface; stop or teardown returns to the library; no session means no reachable blank stream surface.
- Move Settings to the native macOS Settings scene (App menu, Cmd+,) with grouped form style, immediately persisted changes, resolution/frame-rate presets, and no mobile-only status rows.
- Open Diagnostics on demand from the Window menu or toolbar as its own surface instead of a permanent sidebar peer.
- Clean up state presentation: reachability as a status dot with bounded checking/online/offline semantics, single-expression tile selection with uniform tile sizes, session commands present only while a session exists, focus rings only on interactive controls.
- Preserve the existing `AppModel` workflow ownership, `Product*Surface` state derivations, confirmation dialogs, accessibility semantics, and per-window workspace identity. Frozen platforms (iOS/iPadOS, tvOS, visionOS) keep their current presentation and must only keep compiling.

## Capabilities

### New Capabilities

- `macos-product-shell`: Host-centric macOS library shell, contextual pairing, session-owned stream surface, native Settings and on-demand Diagnostics, and macOS control-idiom fidelity.

### Modified Capabilities

None. Existing workflow, recovery, multiwindow, accessibility, and diagnostics requirements remain valid; this change rearranges the macOS presentation that fulfills them and implements the "Library reflects the primary user task" acceptance scenario of `macos-first-delivery-governance`.

## Impact

- `Sources/LuneXApp/LuneXApp.swift` (scene declarations: Settings scene, on-demand Diagnostics surface, commands) and `Sources/LuneXApp/RootView.swift` (shell decomposition; the macOS shell should be split into focused view files).
- `Sources/LuneXCore/ProductWorkflowState.swift` and related presentation state: the four-way `AppNavigationSelection` no longer drives the macOS shell; macOS presentation derives from host selection and session phase. iOS compact navigation keeps its existing model.
- `Tests/LuneXCoreTests/ProductWorkflowSurfaceTests.swift` and other presentation-state tests tied to the old navigation model.
- Localization strings for new/renamed controls; removed strings for retired panels.
- No protocol, media, input, persistence, or identity changes. No Moonlight source is copied; Moonlight iOS/Qt remain read-only behavioral references.
