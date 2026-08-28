## 1. Research And Scaffolding

- [x] 1.1 Audit current macOS shell composition (`RootView.swift`, `LuneXApp.swift`, `ProductWorkflowState.swift`) and list every consumer of `AppNavigationSelection`, the panel views, and the settings/diagnostics sidebar destinations, without changing behavior.
- [x] 1.2 Split the macOS shell out of the monolithic `RootView.swift` into focused view files (library shell, host sidebar, catalog, pairing flow, stream container, settings, diagnostics) behind the existing platform conditionals, preserving current behavior as an intermediate step.

## 2. Host Sidebar And Library Shell

- [x] 2.1 Replace the macOS screen-category sidebar with the host-list sidebar: status dot (checking/online/offline), unpaired lock affordance, per-row context menu (pair, reset trust, remove) wired to the existing confirmation and destructive surfaces, and add-host affordances (sidebar bottom, File menu, toolbar).
- [x] 2.2 Retire the permanent Hosts panel and its four-button row; automatically reconcile and de-duplicate discovery with saved-host reachability, prefer a launch-ready host only while selection remains automatic, preserve explicit per-workspace host choices, keep explicit refresh reachable only as a menu recovery command, and retire steady-state "Unknown" plus duplicate "Paired" text per the spec.
- [x] 2.3 Derive the macOS content mode (first-use, pairing, catalog, stream) from selected host, pairing surface, and session phase; keep `AppNavigationSelection` only for frozen-platform navigation.

## 3. Catalog And Direct Launch

- [x] 3.1 Rebuild the catalog grid as the main content: automatically refresh the selected reachable paired host, uniform tiles, single-expression selection, hover play affordance, double-click and Return launching through the existing session command path, and non-launchable presentation for offline/cached-only hosts.
- [x] 3.2 Remove the Launch panel; surface the effective mode/bitrate/HDR summary at the launch point or session presentation; keep catalog loading/empty/failed/cached states mapped from `ProductAppCatalogSurface`.

## 4. Contextual Pairing

- [x] 4.1 Implement the single pairing content view mapping all `ProductPairingSurface` phases, with prominent PIN stage, cancel/retry, automatic return to catalog on completion, and no ambient completed/cancelled panels.
- [x] 4.2 Remove the container `.focusable()` workaround; verify keyboard focus traverses interactive controls only.

## 5. Stream Mode And Toolbar Honesty

- [x] 5.1 Make an active/connecting/recoverable session own the full window content (existing `MetalStreamSurface` + overlay + `PlatformLifecycleState` wiring), and return to the library automatically on stop, teardown, or unrecovered failure.
- [x] 5.2 Remove the sidebar Stream destination and any reachable blank stream region; scope Disconnect and other session commands to windows that actually own a session.

## 6. Native Settings And On-Demand Diagnostics

- [x] 6.1 Move macOS settings to a `Settings` scene with grouped form style and immediate persistence; remove the Save button and the sidebar Settings destination.
- [x] 6.2 Replace pixel steppers with resolution/frame-rate preset pickers (native display-derived option plus custom round-trip of persisted arbitrary values) and a bitrate slider with Mbps readout; exclude mobile-only status rows from macOS while keeping HDR and spatial-audio actual-state rows bounded.
- [x] 6.3 Open Diagnostics on demand from the Window menu (and optional toolbar item) as its own window reusing existing content and export; remove the sidebar Diagnostics destination.

## 7. Verification

- [x] 7.1 Rewrite presentation-state tests against the derived macOS content mode (first-use, pairing, catalog, stream) and update workspace/multiwindow tests for per-window isolation, without deleting still-valid workflow coverage.
- [x] 7.2 Run the macOS deterministic test suite and generic non-macOS compatibility builds; confirm frozen-platform presentation is unchanged.
- [x] 7.3 Visually verify on macOS via `script/build_and_run.sh`: default-size window shows hosts + catalog with launch reachable without scrolling; unpaired host shows pairing flow; no blank stream screen; Cmd+, opens grouped settings; Window menu opens diagnostics; no permanently disabled toolbar controls; focus rings on controls only.
- [x] 7.4 Run strict OpenSpec validation for this change and synchronize `task_plan.md`, `findings.md`, and `progress.md` with the shell redesign status.
