import Foundation

enum ProductHostLibraryContentSurface: Equatable, Sendable {
    case loading
    case firstUse
    case hosts
    case failed
}

enum ProductHostDestructiveSurface: Equatable, Sendable {
    case idle
    case awaitingConfirmation
    case performing(ProductHostDestructiveKind)
    case failed(ProductIssue)
    case completed(ProductHostDestructiveKind)
}

struct ProductHostLibrarySurface: Equatable, Sendable {
    let content: ProductHostLibraryContentSurface
    let isRefreshing: Bool
    let refreshIssue: ProductIssue?
    let destructive: ProductHostDestructiveSurface
    let canAddHost: Bool
    let canRefresh: Bool
    let canRemove: Bool
    let canResetTrust: Bool

    init(
        library: ProductHostLibraryWorkspaceState,
        hostCount: Int,
        selectedHost: MoonlightHost?
    ) {
        content = switch library.phase {
        case .loading:
            .loading
        case .firstUse:
            .firstUse
        case .available:
            hostCount == 0 ? .firstUse : .hosts
        case .failed:
            hostCount == 0 ? .failed : .hosts
        }
        isRefreshing = library.isRefreshing
        refreshIssue = library.refreshIssue
        destructive = switch library.destructiveAction {
        case .idle:
            .idle
        case .awaitingConfirmation:
            .awaitingConfirmation
        case let .performing(confirmation):
            .performing(confirmation.kind)
        case let .failed(_, issue):
            .failed(issue)
        case let .succeeded(kind, _):
            .completed(kind)
        }

        let destructiveAdmissionOpen: Bool
        switch library.destructiveAction {
        case .idle, .succeeded:
            destructiveAdmissionOpen = true
        case .awaitingConfirmation, .performing, .failed:
            destructiveAdmissionOpen = false
        }
        let libraryAdmissionOpen = library.phase != .loading && !library.isRefreshing
        canAddHost = libraryAdmissionOpen && destructiveAdmissionOpen
        canRefresh = libraryAdmissionOpen
            && library.phase != .failed
            && destructiveAdmissionOpen
        canRemove = selectedHost != nil
            && libraryAdmissionOpen
            && destructiveAdmissionOpen
        canResetTrust = selectedHost?.pairingState == .paired
            && libraryAdmissionOpen
            && destructiveAdmissionOpen
    }
}

enum ProductPairingSurfacePhase: Equatable, Sendable {
    case noHost
    case ready
    case unavailable
    case preparing
    case waitingForPIN
    case exchangingSecrets
    case verifyingServer
    case savingIdentity
    case completed
    case cancelled
    case failed
}

struct ProductPairingSurface: Equatable, Sendable {
    let phase: ProductPairingSurfacePhase
    let issue: ProductIssue?
    let canStart: Bool
    let canSubmitPIN: Bool
    let canCancel: Bool
    let canRetry: Bool

    init(
        selectedHost: MoonlightHost?,
        pairing: PairingUIState,
        transportAvailable: Bool,
        isPINValid: Bool
    ) {
        guard let selectedHost else {
            phase = .noHost
            issue = nil
            canStart = false
            canSubmitPIN = false
            canCancel = false
            canRetry = false
            return
        }

        let ownsSelectedHost = pairing.hostID == selectedHost.id
        let visibleIssue = ownsSelectedHost ? pairing.issue : nil
        let resolvedPhase: ProductPairingSurfacePhase
        if selectedHost.pairingState == .paired
            || (ownsSelectedHost && pairing.stage == .paired) {
            resolvedPhase = .completed
        } else if ownsSelectedHost {
            resolvedPhase = switch pairing.stage {
            case .idle:
                pairing.isRunning ? .preparing : (transportAvailable ? .ready : .unavailable)
            case .waitingForPIN:
                .waitingForPIN
            case .exchangingSecrets:
                .exchangingSecrets
            case .verifyingServer:
                .verifyingServer
            case .pinningIdentity:
                .savingIdentity
            case .paired:
                .completed
            case .failed:
                visibleIssue?.code == .pairingUnavailable ? .unavailable : .failed
            case .cancelled:
                .cancelled
            }
        } else {
            resolvedPhase = transportAvailable ? .ready : .unavailable
        }

        phase = resolvedPhase
        issue = visibleIssue
        canStart = transportAvailable
            && (resolvedPhase == .ready || resolvedPhase == .cancelled)
        canSubmitPIN = resolvedPhase == .waitingForPIN && isPINValid
        let cancellablePhase = switch resolvedPhase {
        case .preparing, .waitingForPIN, .exchangingSecrets,
             .verifyingServer, .savingIdentity:
            true
        case .noHost, .ready, .unavailable, .completed, .cancelled, .failed:
            false
        }
        canCancel = ownsSelectedHost && cancellablePhase
        canRetry = resolvedPhase == .failed
            && pairing.issue?.action?.kind == .retryPairing
            && pairing.owner.map {
                pairing.issue?.action?.scope == .pairing($0)
            } == true
    }
}

enum ProductAppCatalogContentSurface: Equatable, Sendable {
    case unavailable
    case requiresPairing(hasCachedApps: Bool)
    case idle
    case loading
    case loadingCached
    case empty(ProductCatalogContentSource)
    case cached
    case current
    case failed(hasCachedApps: Bool)
}

struct ProductAppCatalogSurface: Equatable, Sendable {
    let content: ProductAppCatalogContentSurface
    let issue: ProductIssue?
    let canRefresh: Bool
    let canRetry: Bool
    let showsApps: Bool

    init(
        catalog: ProductAppCatalogWorkspaceState,
        selectedHost: MoonlightHost?,
        appCount: Int
    ) {
        guard let owner = catalog.owner,
              let selectedHost,
              selectedHost.id == owner.hostID else {
            content = .unavailable
            issue = nil
            canRefresh = false
            canRetry = false
            showsApps = false
            return
        }

        let hasApps = appCount > 0
        if selectedHost.pairingState != .paired {
            content = .requiresPairing(hasCachedApps: hasApps)
        } else {
            content = switch catalog.phase {
            case .unavailable:
                .unavailable
            case .idle:
                .idle
            case let .loading(hasCachedApps):
                hasCachedApps && hasApps ? .loadingCached : .loading
            case let .empty(source):
                .empty(source)
            case .cached:
                hasApps ? .cached : .empty(.cached)
            case .current:
                hasApps ? .current : .empty(.current)
            case let .failed(hasCachedApps):
                .failed(hasCachedApps: hasCachedApps && hasApps)
            }
        }

        issue = catalog.issue
        showsApps = switch content {
        case .loadingCached, .cached, .current, .failed(hasCachedApps: true),
             .requiresPairing(hasCachedApps: true):
            true
        case .unavailable, .requiresPairing(hasCachedApps: false), .idle,
             .loading, .empty, .failed(hasCachedApps: false):
            false
        }
        let regularRefreshState: Bool
        switch content {
        case .idle, .empty, .cached, .current:
            regularRefreshState = true
        default:
            regularRefreshState = false
        }
        let isFailed: Bool
        if case .failed = content {
            isFailed = true
        } else {
            isFailed = false
        }
        canRetry = isFailed
            && selectedHost.pairingState == .paired
            && catalog.issue?.action?.kind == .refreshCatalog
            && catalog.issue?.action?.scope == .catalog(owner)
        canRefresh = selectedHost.pairingState == .paired
            && regularRefreshState
            && !canRetry
    }
}
