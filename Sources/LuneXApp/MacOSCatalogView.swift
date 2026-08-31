#if os(macOS)
import SwiftUI

struct MacOSCatalogView: View {
    @Environment(AppModel.self) private var appModel
    let workspace: ProductWorkspaceReference

    var body: some View {
        let host = appModel.selectedHost(in: workspace)
        let catalog = appModel.catalogState(for: workspace)
            ?? ProductAppCatalogWorkspaceState()
        let surface = ProductAppCatalogSurface(
            catalog: catalog,
            selectedHost: host,
            appCount: appModel.selectedApps(in: workspace).count
        )

        VStack(spacing: 0) {
            if let host {
                catalogHeader(host: host, surface: surface)
                Divider()
            }
            catalogContent(host: host, surface: surface)
        }
        .navigationTitle(host?.name ?? "Library")
        .task(id: ProductMacOSAutomaticCatalogRefreshPolicy.taskID(
            selectedHost: host,
            catalogOwner: catalog.owner
        )) {
            guard ProductMacOSAutomaticCatalogRefreshPolicy.taskID(
                selectedHost: host,
                catalogOwner: catalog.owner
            ) != nil else { return }
            await appModel.refreshAppsForSelectedHost(in: workspace)
        }
    }

    private func catalogHeader(
        host: MoonlightHost,
        surface: ProductAppCatalogSurface
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Applications")
                    .font(.title2.weight(.semibold))
                Text(streamSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            switch host.reachability {
            case .unknown:
                Label("Checking", systemImage: "clock")
                    .foregroundStyle(.secondary)
            case .online:
                if isCatalogLoading(surface.content) {
                    ProgressView("Updating")
                        .controlSize(.small)
                } else {
                    Label("Online", systemImage: "circle.fill")
                        .symbolRenderingMode(.monochrome)
                        .foregroundStyle(.green)
                }
            case .offline:
                Label("Offline", systemImage: "circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func catalogContent(
        host: MoonlightHost?,
        surface: ProductAppCatalogSurface
    ) -> some View {
        if surface.showsApps, let host {
            ScrollView {
                if !catalogIsLaunchReady(surface.content, host: host) {
                    catalogAvailabilityNotice(host: host, surface: surface)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 170, maximum: 230), spacing: 16)
                    ],
                    spacing: 16
                ) {
                    ForEach(appModel.selectedApps(in: workspace)) { app in
                        appButton(app, host: host, surface: surface)
                    }
                }
                .padding(20)
            }
        } else {
            emptyContent(surface)
        }
    }

    private func appButton(
        _ app: RemoteApp,
        host: MoonlightHost,
        surface: ProductAppCatalogSurface
    ) -> some View {
        let isSelected = appModel.selectedAppID(in: workspace) == app.id
        let canLaunch = catalogIsLaunchReady(surface.content, host: host)
            && appModel.sessionCommandState(in: workspace).launch == .available

        return Button {
            appModel.select(app: app, in: workspace)
        } label: {
            MacOSAppTile(
                app: app,
                isSelected: isSelected,
                isLaunchReady: canLaunch
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                launch(app, ifAllowed: canLaunch)
            }
        )
        .onKeyPress(.return) {
            guard canLaunch else { return .ignored }
            launch(app, ifAllowed: true)
            return .handled
        }
        .accessibilityLabel("\(app.name) on \(host.name)")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityHint(
            canLaunch
                ? "Double-click or press Return to start streaming."
                : "This application is not currently launchable."
        )
    }

    private func launch(_ app: RemoteApp, ifAllowed: Bool) {
        guard ifAllowed else { return }
        appModel.select(app: app, in: workspace)
        Task.detached { [appModel, workspace] in
            await appModel.launchSelectedApp(in: workspace)
        }
    }

    @ViewBuilder
    private func catalogAvailabilityNotice(
        host: MoonlightHost,
        surface: ProductAppCatalogSurface
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: noticeSystemImage(host: host, surface: surface))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(noticeTitle(host: host, surface: surface))
                    .font(.callout.weight(.semibold))
                Text(noticeMessage(host: host, surface: surface))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if surface.canRetry {
                Button("Retry") {
                    Task {
                        await appModel.retryAppCatalog(in: workspace)
                    }
                }
                .productActionTarget()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    @ViewBuilder
    private func emptyContent(_ surface: ProductAppCatalogSurface) -> some View {
        switch surface.content {
        case .loading, .loadingCached:
            ProgressView("Loading applications...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            ContentUnavailableView {
                Label(
                    surface.issue?.presentation.title ?? "Applications Unavailable",
                    systemImage: surface.issue?.presentation.systemImage
                        ?? "square.grid.3x3"
                )
            } description: {
                Text(
                    surface.issue?.presentation.message
                        ?? "The application catalog could not be updated."
                )
            } actions: {
                if surface.canRetry {
                    Button("Retry") {
                        Task {
                            await appModel.retryAppCatalog(in: workspace)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        case .empty:
            ContentUnavailableView(
                "No Applications",
                systemImage: "square.grid.3x3",
                description: Text("Sunshine returned an empty application list.")
            )
        case .idle:
            ProgressView("Loading applications...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .unavailable, .requiresPairing:
            ContentUnavailableView(
                "Applications Unavailable",
                systemImage: "square.grid.3x3"
            )
        case .cached, .current:
            EmptyView()
        }
    }

    private var streamSummary: String {
        let stream = appModel.settings.stream
        let hdr = stream.hdrEnabled ? "HDR" : "SDR"
        return "\(stream.width) × \(stream.height) at \(stream.frameRate) fps · \(stream.bitrateKbps / 1_000) Mbps · \(hdr)"
    }

    private func isCatalogLoading(
        _ content: ProductAppCatalogContentSurface
    ) -> Bool {
        switch content {
        case .loading, .loadingCached: true
        default: false
        }
    }

    private func catalogIsLaunchReady(
        _ content: ProductAppCatalogContentSurface,
        host: MoonlightHost
    ) -> Bool {
        guard host.reachability == .online else { return false }
        guard case .current = content else { return false }
        return true
    }

    private func noticeTitle(
        host: MoonlightHost,
        surface: ProductAppCatalogSurface
    ) -> LocalizedStringResource {
        if host.reachability == .offline { return "Host Offline" }
        if host.reachability == .unknown { return "Checking Host" }
        if isCatalogLoading(surface.content) { return "Updating Applications" }
        return surface.issue?.presentation.title
            ?? "Saved Applications"
    }

    private func noticeMessage(
        host: MoonlightHost,
        surface: ProductAppCatalogSurface
    ) -> String {
        if host.reachability == .offline {
            return "Saved applications remain visible, but launching waits until the host is online."
        }
        if host.reachability == .unknown {
            return "Launching waits for the current reachability check."
        }
        if isCatalogLoading(surface.content) {
            return "The saved catalog remains visible while LuneX requests the current list."
        }
        return "The saved catalog is not launch-ready until the current list is confirmed."
    }

    private func noticeSystemImage(
        host: MoonlightHost,
        surface: ProductAppCatalogSurface
    ) -> String {
        if host.reachability == .offline { return "desktopcomputer.trianglebadge.exclamationmark" }
        if host.reachability == .unknown { return "clock" }
        if isCatalogLoading(surface.content) { return "arrow.clockwise" }
        return "clock.arrow.circlepath"
    }
}

private struct MacOSAppTile: View {
    let app: RemoteApp
    let isSelected: Bool
    let isLaunchReady: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(.quaternary)
                Image(systemName: app.supportsHDR ? "sparkles.tv" : "app")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.secondary)

                if isHovering, isLaunchReady {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 42))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.white)
                        .shadow(radius: 3)
                }
            }
            .frame(height: 112)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(app.name)
                    .font(.headline)
                    .lineLimit(1)
                Spacer(minLength: 4)
                if app.supportsHDR {
                    Text("HDR")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 170, maxHeight: 170, alignment: .topLeading)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? Color.accentColor : Color.clear,
                    lineWidth: 2
                )
        }
        .opacity(isLaunchReady ? 1 : 0.68)
        .onHover { isHovering = $0 }
    }
}
#endif
