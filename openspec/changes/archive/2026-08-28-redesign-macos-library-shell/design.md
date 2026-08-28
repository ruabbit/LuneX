# Design: macOS Library Shell Redesign

## Context

The macOS client currently reuses one cross-platform `RootView` whose sidebar enumerates screens (Library, Stream, Diagnostics, Settings) and whose Library is a 2x2 grid of subsystem panels. All workflow state machines underneath (`ProductHostLibrarySurface`, `ProductPairingSurface`, `ProductAppCatalogSurface`, session command state, destructive confirmations, diagnostics) are sound and stay as-is. This design changes only how macOS composes them.

Reference model: Finder/App Store column navigation, and Moonlight Qt's host-then-app flow, observed as behavior only.

## Goals / Non-Goals

Goals:

- One obvious macOS path: select host in sidebar → see its apps → double-click to play.
- Transient flows (pairing, launching) appear exactly when relevant and disappear afterwards.
- Native macOS idiom: grouped settings in the Settings scene, context menus for host management, immediate persistence, honest toolbars.

Non-Goals:

- No changes to pairing, session, media, input, HDR, audio, persistence, or diagnostics logic.
- No visual changes for iOS/iPadOS, tvOS, visionOS beyond keeping their targets compiling (maintenance freeze).
- No new artwork pipeline; box-art placeholders stay placeholders in this change.

## Decisions

### D1. Sidebar is the host list

`NavigationSplitView` sidebar rows are hosts, each row showing: status dot (checking = neutral/progress, online = green, offline = gray), host name, and a trailing lock glyph only when the host is unpaired. Reachability and trust are separate axes and never share one label. The steady-state string "Unknown" is retired; before the first bounded reachability result a host renders as checking. The host sidebar is collapsible and adaptive: it earns persistent space only as the high-frequency host selector and must not constrain the catalog below the minimum supported window layout.

An explicit host choice belongs to that workspace and is preserved while the host remains saved, including when the chosen host is offline. When a workspace has no valid explicit choice, automatic selection prefers an online paired host, then another online host, then a paired host whose first reachability check is pending, followed by a deterministic fallback. A provisional automatic choice may promote when the first reachability result reveals a better launch-ready host; automatic reconciliation never overrides an explicit user choice.

Host management moves to a context menu on each row (Pair…, Wake/Refresh as available, Reset Trust…, Remove…) plus an Add Host affordance at the sidebar bottom and in the File menu. Existing destructive confirmation dialogs and `ProductHostDestructiveSurface` states are reused verbatim. The permanent Add/Refresh/Reset Trust/Remove button row is deleted. Discovery, saved-host reachability, and the selected reachable paired host's catalog reconcile automatically; explicit refresh remains reachable only as a menu recovery command and normal use must not require it.

Bonjour results reconcile into the saved library instead of being appended mechanically. Exact addresses remain authoritative; a unique normalized-name match may add the mDNS address while retaining pairing and pinned trust. A uniquely trusted same-name record also absorbs an unpaired duplicate created by an older discovery pass. Ambiguous same-name trusted records are never collapsed without an address match.

### D2. Content area is the selected host's catalog

The detail column renders exactly one of the following, derived from existing surfaces — no user-facing "navigation selection" among screens:

1. No hosts → first-use empty state (add host / discovery), reusing `ProductHostLibrarySurface.content == .firstUse`.
2. Host selected, unpaired or pairing active → contextual pairing view (D3).
3. Host selected, paired → app catalog grid for that host (`ProductAppCatalogSurface` drives loading/cached/empty/failed states, presented with `ContentUnavailableView` where applicable).
4. Session active or recovering in this window → stream surface owns the content (D4).

Selecting a reachable paired host automatically loads or refreshes its catalog; a visible refresh control appears only for explicit failure recovery. App tiles use uniform fixed-height cards; selection is expressed once, never as an in-tile caption; hover reveals a play affordance; double-click or Return launches through the existing launch command path; a compact detail bar or tooltip at the launch point shows the effective mode/bitrate/HDR summary. The permanent Launch panel is deleted. Tiles for a paired-but-offline host render non-launchable (existing "cached apps are not launch-ready" rule).

### D3. Pairing is contextual

When the selected host is unpaired (or `ProductPairingSurface` has an active attempt), the content area shows a single pairing view: host name, one primary Start Pairing action, then the PIN stage with a large, prominent PIN presentation/entry, cancel, retry-on-failure — all states mapped 1:1 from `ProductPairingSurface.phase`. On `.completed`, the view transitions to the catalog automatically; completed/cancelled states do not persist as ambient panels. The `.focusable()` container hack is removed; focus moves between real controls only.

### D4. Stream is a mode that owns the window

`MetalStreamSurface` plus the existing overlay HUD replace the whole window content (sidebar collapses/hides) exactly while this window's workspace owns an active, connecting, or recoverable session. On disconnect/teardown/failure-exit, presentation returns to the library (catalog of the last host). There is no sidebar "Stream" destination and no reachable blank stream screen. Existing overlay visibility, hide-controls, disconnect confirmation, and macOS lifecycle wiring (`PlatformLifecycleState`) carry over unchanged.

The window toolbar shows session commands (Disconnect) only while a session exists; a sessionless window shows no disabled session controls.

### D5. Settings in the Settings scene

macOS gets a `Settings` scene (App menu → Settings…, Cmd+,) with `.formStyle(.grouped)` and tabs/sections: Stream Quality, Input, Audio. Changes persist immediately through the existing settings save path; the Save Settings button is removed. Resolution and frame rate become preset pickers (e.g. 1080p/1440p/4K plus the window/display-derived native option, and the previously stored custom value rendered as a custom entry) instead of pixel steppers; bitrate becomes a slider with an Mbps readout. Actual-state rows (HDR output, spatial audio playback) remain, rendered compactly; mobile-only rows (Scene, Picture in Picture, Background continuity) do not appear on macOS. The in-window Settings sidebar destination is removed.

### D6. Diagnostics on demand

Diagnostics opens from the Window menu (and optionally a toolbar item) as its own auxiliary window using the existing `DiagnosticsView` content and privacy-safe export. It is no longer a sidebar peer.

### D7. Navigation-state consequences

`AppNavigationSelection` (library/stream/diagnostics/settings) stops driving macOS. macOS workspace presentation reduces to: selected host, selected app, pairing activity, and session phase — all already owned by `ProductWorkspaceState`/`AppModel`. The enum and its workspace plumbing remain for the frozen iOS compact TabView; macOS-only code paths must not regress iOS/tvOS/visionOS compilation. Presentation-state tests move from asserting sidebar selection to asserting the derived content mode.

## Risks / Trade-offs

- Test churn: `ProductWorkflowSurfaceTests` and workspace tests assert the old navigation model; they must be rewritten against the derived content mode, not deleted.
- Multiwindow: per-window workspace identity already exists; the shell must keep host selection and session ownership per window. Acceptance includes a two-window scenario.
- Removing the permanent Refresh button relies on the automatic reachability requirement already specified in `macos-first-delivery-governance`; until that lands, Refresh stays reachable from a menu so the product never loses the capability.
- Preset pickers must round-trip previously persisted arbitrary width/height/fps values without data loss (render as Custom).

## Open Questions

None blocking. Box-art artwork and launch-time host wake (WoL) are explicitly out of scope for this change.
