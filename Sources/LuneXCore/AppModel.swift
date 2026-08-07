import Foundation
import Observation
import OSLog
#if os(iOS)
import AVKit
import UIKit
#endif

enum AppNavigationSelection: Hashable {
    case library
    case stream
    case diagnostics
    case settings
}

struct PairingUIState: Equatable {
    var hostID: MoonlightHost.ID?
    var attemptID: UUID?
    var stage: PairingStage = .idle
    var pin: String = ""
    var isRunning = false
    var message: String?
    var actionMessage: String?
}

private enum PairingApplicationError: Error {
    case incompleteRuntimeStream
    case invalidAuthenticatedCompletion
}

private enum SessionApplicationError: Error {
    case incompleteControlStream
}

struct AppCatalogUIState: Equatable {
    var isRefreshing = false
    var lastUpdatedAt: Date?
    var errorMessage: String?
}

struct StreamLaunchUIState: Equatable {
    var selectedAppID: RemoteApp.ID?
    var isLaunching = false
    var errorMessage: String?
    var actionMessage: String?
}

struct RuntimeProviderAvailability: OptionSet, Equatable, Sendable {
    let rawValue: UInt8

    static let pairing = RuntimeProviderAvailability(rawValue: 1 << 0)
    static let sessionControl = RuntimeProviderAvailability(rawValue: 1 << 1)
    static let videoReceive = RuntimeProviderAvailability(rawValue: 1 << 2)
    static let audioReceive = RuntimeProviderAvailability(rawValue: 1 << 3)
    static let remoteInput = RuntimeProviderAvailability(rawValue: 1 << 4)
    static let requiredStream: RuntimeProviderAvailability = [
        .sessionControl,
        .videoReceive,
        .audioReceive,
        .remoteInput
    ]

    var pairingTransportAvailable: Bool {
        contains(.pairing)
    }

    var streamTransportAvailable: Bool {
        contains(.requiredStream)
    }
}

struct RuntimeProviderInventory: Sendable {
    let pairing: (any PairingRuntimeProvider)?
    let sessionControl: (any SessionControlProvider)?
    let videoReceive: (any VideoReceiveProvider)?
    let audioReceive: (any AudioReceiveProvider)?
    let remoteInput: (any RemoteInputProvider)?

    init(
        pairing: (any PairingRuntimeProvider)? = nil,
        sessionControl: (any SessionControlProvider)? = nil,
        videoReceive: (any VideoReceiveProvider)? = nil,
        audioReceive: (any AudioReceiveProvider)? = nil,
        remoteInput: (any RemoteInputProvider)? = nil
    ) {
        self.pairing = pairing
        self.sessionControl = sessionControl
        self.videoReceive = videoReceive
        self.audioReceive = audioReceive
        self.remoteInput = remoteInput
    }

    var availability: RuntimeProviderAvailability {
        var result: RuntimeProviderAvailability = []
        if pairing != nil { result.insert(.pairing) }
        if sessionControl != nil { result.insert(.sessionControl) }
        if videoReceive != nil { result.insert(.videoReceive) }
        if audioReceive != nil { result.insert(.audioReceive) }
        if remoteInput != nil { result.insert(.remoteInput) }
        return result
    }

    static let unavailable = RuntimeProviderInventory()
}

enum ProductionRuntimeProviderFactory {
    static func makeDefault() -> RuntimeProviderInventory {
        let controlChannel = MoonlightControlChannel()
        let pairingProvider = PersistingPairingProvider(
            provider: MoonlightPairingProvider(),
            repository: JSONFileHostRepository(fileURL: AppStorageLocations.hostsFile)
        )
        return RuntimeProviderInventory(
            pairing: pairingProvider,
            sessionControl: MoonlightSessionControlProvider(controlChannel: controlChannel),
            remoteInput: MoonlightRemoteInputProvider(
                sender: controlChannel,
                feedbackSource: controlChannel
            )
        )
    }
}

@MainActor
@Observable
final class AppModel: ApplicationInputSink {
    private struct TVVisionPlatformGeometryAdmission: Equatable {
        let ownership: TVVisionPresentationOwnership
        let update: TVVisionStreamGeometryBindingUpdate
    }

    private let logger = Logger(subsystem: "dev.lunex.client", category: "app.model")
    var hosts: [MoonlightHost] = []
    var settings = AppSettings.defaults {
        didSet {
            if settings.input != oldValue.input {
                refreshMacInputSurfacePolicy()
            }
            if settings.stream != oldValue.stream {
                updateRenderPreferences()
                refreshHDRRenderResolution()
            }
#if os(iOS)
            if settings.continuity != oldValue.continuity {
                refreshMobilePictureInPictureConfiguration()
                queueMobileRuntimeApplication()
            }
#endif
        }
    }
    var session = StreamingSessionState()
    var renderState = StreamRenderState()
    var diagnostics = DiagnosticsStore()
    var navigationSelection: AppNavigationSelection = .library {
        didSet {
            guard navigationSelection != oldValue else { return }
            updateTVRemoteNavigationSelection()
        }
    }
    var selectedHostID: MoonlightHost.ID?
    var appsByHostID: [MoonlightHost.ID: [RemoteApp]] = [:]
    var pairingUI = PairingUIState()
    var appCatalogUI = AppCatalogUIState()
    var streamLaunchUI = StreamLaunchUIState()
    var latestRemoteInputFeedback: RemoteInputFeedback?
    private(set) var macInputSurfacePolicy = MacInputSurfacePolicy.inactive
    private(set) var hdrPresentationStatus = HDRPresentationStatus.inactive
    private(set) var audioRuntimeState: SessionMediaAudioRuntimeState?
    private(set) var mobileRuntimeState: SessionMobileRuntimeState?
    private(set) var mobileSceneWindowSnapshot: MobileSceneWindowSnapshot?
    private(set) var mobileDisplayEDRSnapshot: MobileDisplayEDRSnapshot?
    private(set) var mobilePictureInPictureSnapshot:
        MobilePictureInPictureSnapshot?
    private(set) var mobileAudioSessionActive: Bool?
    private(set) var tvVisionPlatformPresentationState:
        SessionTVVisionPlatformPresentationState?
    private(set) var tvRemoteFocusHandoffState =
        TVRemoteFocusHandoffState.localNavigation
    private(set) var tvRemoteReservedCommandState =
        TVRemoteReservedCommandRuntimeState.idle
    private(set) var tvControllerRosterState: TVControllerRosterSnapshot?
    private(set) var tvControllerRoutedRosterState: TVControllerRosterSnapshot?
    private(set) var tvControllerFeedbackDecisionState:
        TVControllerFeedbackDecision?
    private(set) var tvRemoteInputReleasePending = false

    var tvStreamOverlayVisible: Bool {
        tvRemoteFocusHandoffState.isOverlayVisible
            && !isTVRemoteInputReleasePending
    }

    var tvVisionPlatformPresentationSnapshot:
        TVVisionPlatformPresentationSnapshot?
    {
        guard let state = tvVisionPlatformPresentationState,
              state.sessionID == activeStreamSessionID,
              state.sessionID == activeMediaSessionID,
              state.mediaGeneration == activeMediaGeneration,
              state.snapshot.phase == .active else { return nil }
        return state.snapshot.presentation
    }

    var spatialAudioPresentationStatus: SpatialAudioPresentationStatus {
        SpatialAudioPresentationStatus(audioRuntimeState)
    }

    var mobileExperiencePresentationStatus: MobileExperiencePresentationStatus {
        MobileExperiencePresentationStatusResolver.resolve(
            hasActiveSession: activeStreamSessionID != nil
                && activeMediaSessionID == activeStreamSessionID
                && activeMediaGeneration != nil,
            scene: mobileSceneWindowSnapshot?.state,
            pictureInPicture: mobilePictureInPictureSnapshot?.state,
            continuityPath: mobileRuntimeState?.continuityPath,
            streamDirective: mobileRuntimeState?.media.plan.stream,
            displayEDR: mobileDisplayEDRSnapshot?.state,
            hdrPresentation: hdrPresentationStatus,
            preferences: settings.continuity
        )
    }

    @discardableResult
    func performMobilePictureInPictureCommand(
        _ command: MobilePictureInPictureCommand
    ) -> MobilePictureInPictureCommandResult {
#if os(iOS)
        let availability = mobileExperiencePresentationStatus
            .pictureInPictureCommand
        switch (command, availability) {
        case (.start, .start), (.stop, .stop):
            break
        case (.start, _), (.stop, _):
            return .unavailable
        }
        guard let coordinator = mobilePictureInPictureCoordinator,
              let snapshot = mobilePictureInPictureSnapshot,
              coordinator.generation == snapshot.generation,
              snapshot.generation.mediaGeneration == activeMediaGeneration else {
            return .unavailable
        }
        let outcome = switch command {
        case .start: coordinator.requestStart()
        case .stop: coordinator.requestStop()
        }
        switch outcome {
        case .unchanged:
            return .unchanged
        case .applied:
            return .accepted
        case .rejected:
            return .rejected
        case .revisionExhausted:
            return .revisionExhausted
        case .invalidated:
            return .unavailable
        }
#else
        _ = command
        return .unsupportedPlatform
#endif
    }

    let videoPresentationSource: StreamVideoPresentationSource

    private let hostLibraryManager: HostLibraryManager
    private let settingsRepository: AppSettingsRepository
    private let appCatalogManager: AppCatalogManager
    private let appCatalogRepository: AppCatalogSnapshotRepository
    private let streamSessionCoordinator: StreamSessionCoordinator
    private let runtimeProviders: RuntimeProviderInventory
    private let sessionMediaEnvironment: any SessionMediaEnvironment
    private let configuredTVVisionPlatform: TVVisionPlatform?
    private let clientIdentityStore: any ClientIdentityStore
    private let clientIdentityProvisioner: any ClientIdentityProvisioning
    private var clientUniqueID: String
    private var preparedPairingIdentity: ClientIdentityMaterial?
    private var activeStreamSessionID: UUID?
    private var activeMediaSessionID: UUID?
    private var activeMediaGeneration: UInt64?
    @ObservationIgnored private var activeDecodedSourceSize: PixelSize?
    @ObservationIgnored private var activeVideoPresentationRevision: UInt64 = 0
    @ObservationIgnored private var activeVideoDecoderGeneration: UInt64?
    @ObservationIgnored private var highestVideoDecoderGeneration: UInt64 = 0
    @ObservationIgnored private var lastHDRPresentationDiagnosticState:
        HDRPresentationDiagnosticState = .inactive
    @ObservationIgnored private var activeHDRPresentationDiagnosticOwnerID: UUID?
    private var activeControlReadiness: SessionChannelReadiness = []
    private var activeMediaReadiness: SessionChannelReadiness = []
    private var mediaConsumerTask: Task<Void, Never>?
    private let remoteInputKeyOverride: RemoteInputKeyMaterial?
    private let remoteInputKeyGenerator: any RemoteInputKeyMaterialGenerating
    @ObservationIgnored private var hasPlatformLifecycle = false
    @ObservationIgnored private var latestLifecycleRevision: UInt64 = 0
    @ObservationIgnored private var latestLifecycleDirective =
        SessionLifecycleDirectiveResolver.resolve(
            isStreamActive: false,
            isVisible: false,
            isFocused: false,
            drawableSize: .zero
        )
    @ObservationIgnored private var appliedLifecycleApplication: SessionLifecycleApplication?
    @ObservationIgnored private var lifecycleApplicationTask: Task<Void, Never>?
    @ObservationIgnored private var lifecycleApplicationOperationID: UUID?
    @ObservationIgnored private lazy var macSessionInputCoordinator =
        MacSessionInputCoordinator(sink: self)
    @ObservationIgnored private var activeMacInputGeneration: MacSessionInputGeneration?
    @ObservationIgnored private var isMacInputGenerationFailed = false
    @ObservationIgnored private var mobileSurfaceGeneration:
        MobileSceneSurfaceGeneration?
    @ObservationIgnored private var mobileSceneActivity: AppSceneActivity = .inactive
    @ObservationIgnored private var mobileRuntimeRevision: UInt64 = 0
    @ObservationIgnored private var appliedMobileRuntimeRevision: UInt64 = 0
    @ObservationIgnored private var failedMobileRuntimeRevision: UInt64 = 0
    @ObservationIgnored private var isMobileRuntimeRevisionExhausted = false
    @ObservationIgnored private var latestMobileRuntimeApplication:
        SessionMobileRuntimeApplication?
    @ObservationIgnored private var mobileRuntimeApplicationTask:
        Task<Void, Never>?
    @ObservationIgnored private var mobileRuntimeApplicationOperationID: UUID?
    @ObservationIgnored private var mobilePictureInPictureGenerationOrdinal:
        UInt64 = 0
    @ObservationIgnored private var highestMobilePictureInPictureDecoderGeneration:
        UInt64 = 0
    @ObservationIgnored private var isMobilePictureInPictureGenerationExhausted = false
    @ObservationIgnored private var lastMobileDiagnosticCodes: [String: String] = [:]
    @ObservationIgnored private var tvVisionPlatformPresentationOwnership:
        TVVisionPresentationOwnership?
    @ObservationIgnored private var tvVisionPlatformApplicationTask:
        Task<Void, Never>?
    @ObservationIgnored private var tvVisionPlatformApplicationOperationID:
        UUID?
    @ObservationIgnored private var tvVisionPlatformGeometryAdmission:
        TVVisionPlatformGeometryAdmission?
    @ObservationIgnored private var tvRemoteSurfacePressCaptureOwner:
        TVRemoteSurfacePressCaptureOwner?
    @ObservationIgnored private var tvControllerRosterApplicationTask:
        Task<Void, Never>?
    @ObservationIgnored private var tvControllerRosterApplicationOperationID:
        UUID?
    @ObservationIgnored private var tvControllerRoutingTask: Task<Void, Never>?
    @ObservationIgnored private var tvControllerRoutingOperationID: UUID?
    @ObservationIgnored private var tvControllerMotionDeliveryTask:
        Task<Void, Never>?
    @ObservationIgnored private var tvPendingControllerMotionSamples:
        [String: TVGameControllerMotionSample] = [:]
#if os(tvOS)
    @ObservationIgnored private var tvGameControllerRuntimeOwner:
        TVGameControllerRuntimeOwner?
#endif
#if os(iOS)
    @ObservationIgnored private var mobilePictureInPictureCoordinator:
        MobilePictureInPicturePresentationCoordinator?
#endif
#if os(macOS)
    @ObservationIgnored private var lastMacLifecycleDiagnosticState: MacLifecycleDiagnosticState?
    @ObservationIgnored private var lastMacInputDiagnosticState: MacInputDiagnosticState?
#endif

    init(
        hostLibraryManager: HostLibraryManager = HostLibraryManager(
            repository: JSONFileHostRepository(fileURL: AppStorageLocations.hostsFile),
            serverInfoClient: HTTPServerInfoClient()
        ),
        settingsRepository: AppSettingsRepository = JSONFileAppSettingsRepository(fileURL: AppStorageLocations.settingsFile),
        appCatalogManager: AppCatalogManager = AppCatalogManager(
            appListClient: HTTPAppListClient(),
            artworkCache: InMemoryArtworkCache()
        ),
        appCatalogRepository: AppCatalogSnapshotRepository = JSONFileAppCatalogSnapshotRepository(fileURL: AppStorageLocations.appCatalogFile),
        streamSessionCoordinator: StreamSessionCoordinator = StreamSessionCoordinator(
            launchClient: HTTPStreamLaunchClient()
        ),
        runtimeProviders: RuntimeProviderInventory = ProductionRuntimeProviderFactory.makeDefault(),
        sessionMediaEnvironment: (any SessionMediaEnvironment)? = nil,
        videoPresentationSource: StreamVideoPresentationSource? = nil,
        tvVisionPlatform: TVVisionPlatform? = nil,
        clientIdentityStore: any ClientIdentityStore = ClientIdentityStoreFactory.makeDefault(),
        clientIdentityProvisioner: (any ClientIdentityProvisioning)? = nil,
        clientUniqueID: String = "LuneX-\(UUID().uuidString)",
        remoteInputKey: RemoteInputKeyMaterial? = nil,
        remoteInputKeyGenerator: any RemoteInputKeyMaterialGenerating = SecureRemoteInputKeyMaterialGenerator()
    ) {
        self.hostLibraryManager = hostLibraryManager
        self.settingsRepository = settingsRepository
        self.appCatalogManager = appCatalogManager
        self.appCatalogRepository = appCatalogRepository
        self.streamSessionCoordinator = streamSessionCoordinator
        self.runtimeProviders = runtimeProviders
        let presentationSource = videoPresentationSource ?? StreamVideoPresentationSource()
        self.videoPresentationSource = presentationSource
#if os(tvOS)
        configuredTVVisionPlatform = tvVisionPlatform ?? .tvOS
#elseif os(visionOS)
        configuredTVVisionPlatform = tvVisionPlatform ?? .visionOS
#else
        configuredTVVisionPlatform = tvVisionPlatform
#endif
        self.sessionMediaEnvironment = sessionMediaEnvironment
            ?? NativeSessionMediaEnvironment(
                videoReceiveProvider: runtimeProviders.videoReceive,
                audioReceiveProvider: runtimeProviders.audioReceive,
                remoteInputProvider: runtimeProviders.remoteInput,
                videoProcessorFactory: NativeSessionVideoProcessorFactory(
                    presentationSource: presentationSource
                ),
                audioProcessorFactory: NativeSessionAudioProcessorFactory(),
                videoPresentationSource: presentationSource
            )
        self.clientIdentityStore = clientIdentityStore
        self.clientIdentityProvisioner = clientIdentityProvisioner
            ?? ClientIdentityManager(store: clientIdentityStore)
        self.clientUniqueID = clientUniqueID
        self.remoteInputKeyOverride = remoteInputKey
        self.remoteInputKeyGenerator = remoteInputKeyGenerator
    }

    var selectedHost: MoonlightHost? {
        guard let selectedHostID else { return hosts.first }
        return hosts.first { $0.id == selectedHostID }
    }

    var selectedApps: [RemoteApp] {
        guard let hostID = selectedHost?.id else { return [] }
        return appsByHostID[hostID] ?? []
    }

    var selectedApp: RemoteApp? {
        selectedApps.first { $0.id == streamLaunchUI.selectedAppID } ?? selectedApps.first
    }

    var spatialAudioPreferences: SessionSpatialAudioPreferences {
        settings.audio.sessionPreferences
    }

    var runtimeProviderAvailability: RuntimeProviderAvailability {
        runtimeProviders.availability
    }

    var isPairingTransportAvailable: Bool {
        runtimeProviderAvailability.pairingTransportAvailable
    }

    var isStreamTransportAvailable: Bool {
        runtimeProviderAvailability.streamTransportAvailable
    }

    var hasActiveStreamSession: Bool {
        activeStreamSessionID != nil
    }

    var isPairingPINValid: Bool {
        let bytes = Array(pairingUI.pin.utf8)
        return bytes.count == 4 && bytes.allSatisfy { (48...57).contains($0) }
    }

    func loadInitialState() async {
        await loadClientIdentity()
        await loadSettings()
        await loadHosts()
        await loadCachedApps()
    }

    func loadClientIdentity() async {
        do {
            guard let identity = try await clientIdentityStore.loadIdentity() else {
                diagnostics.record("No persisted client identity; pairing remains unavailable", subsystem: "identity")
                logger.info("No persisted client identity in selected store")
                return
            }
            clientUniqueID = identity.id.uuidString
            diagnostics.record("Loaded persisted client identity", subsystem: "identity")
            logger.info("Loaded persisted client identity")
        } catch {
            diagnostics.record(
                "The persisted client identity could not be loaded.",
                subsystem: "identity",
                severity: .error,
                code: "identity_load_failed"
            )
            logger.error("Failed to load client identity")
        }
    }

    func applyPlatformLifecycle(_ lifecycle: PlatformLifecycleState) {
        let directive = SessionLifecycleDirectiveResolver.resolve(
            isStreamActive: lifecycle.isStreamActive,
            isVisible: lifecycle.isVisible,
            isFocused: lifecycle.isFocused,
            drawableSize: lifecycle.drawableSize
        )
        hasPlatformLifecycle = true
        latestLifecycleRevision &+= 1
        latestLifecycleDirective = directive
        renderState.policy = directive.renderPolicy
        renderState.transform.drawableSize = lifecycle.drawableSize
        renderState.headroom = lifecycle.headroom
        renderState.displaySnapshot = lifecycle.displaySnapshot
        renderState.isDisplayRevisionExhausted = lifecycle.isDisplayRevisionExhausted
        refreshHDRRenderResolution()
#if os(macOS)
        publishMacLifecycleDiagnostic(for: directive)
#endif
        applyInputLifecycle(directive.input)
        clearPresentationIfRequired(directive.presentation)
        refreshMacInputSurfacePolicy()
        scheduleLifecycleApplication()
    }

#if os(iOS)
    func receiveMobileSurfaceAttachment(
        surfaceGeneration: MobileSceneSurfaceGeneration,
        isAttached: Bool
    ) {
        guard !isMobileRuntimeRevisionExhausted,
              activeMediaSessionID == activeStreamSessionID,
              activeMediaGeneration != nil,
              acceptMobileSurfaceGeneration(surfaceGeneration) else {
            publishMobileDiagnostic(
                domain: "continuity",
                ApplicationDiagnosticFactory.mobileContinuityState(.stale)
            )
            return
        }
        if !isAttached {
            mobileSceneWindowSnapshot = nil
            mobileDisplayEDRSnapshot = nil
        }
        publishMobileDiagnostic(
            domain: "scene",
            ApplicationDiagnosticFactory.mobileSceneState(
                isAttached ? .inactive : .detached
            )
        )
        queueMobileRuntimeApplication()
    }

    func receiveMobileSceneLifecycle(
        _ update: MobileStreamSceneLifecycleUpdate
    ) {
        guard !isMobileRuntimeRevisionExhausted,
              activeMediaSessionID == activeStreamSessionID,
              activeMediaGeneration != nil,
              acceptMobileSurfaceGeneration(update.surfaceGeneration) else {
            publishMobileDiagnostic(
                domain: "continuity",
                ApplicationDiagnosticFactory.mobileContinuityState(.stale)
            )
            return
        }
        switch update.observation {
        case let .attached(activity):
            mobileSceneActivity = activity
            publishMobileSceneActivityDiagnostic(activity)
        case .detached, .invalidated:
            mobileSceneActivity = .inactive
            mobileSceneWindowSnapshot = nil
            mobileDisplayEDRSnapshot = nil
            publishMobileDiagnostic(
                domain: "scene",
                ApplicationDiagnosticFactory.mobileSceneState(.detached)
            )
        }
        queueMobileRuntimeApplication()
    }

    func receiveMobileSceneWindowSnapshot(
        _ snapshot: MobileSceneWindowSnapshot
    ) {
        guard !isMobileRuntimeRevisionExhausted,
              activeMediaSessionID == activeStreamSessionID,
              activeMediaGeneration != nil,
              acceptMobileSurfaceGeneration(snapshot.surfaceGeneration) else {
            publishMobileDiagnostic(
                domain: "continuity",
                ApplicationDiagnosticFactory.mobileContinuityState(.stale)
            )
            return
        }
        if let current = mobileSceneWindowSnapshot,
           current.surfaceGeneration == snapshot.surfaceGeneration,
           snapshot.revision.rawValue <= current.revision.rawValue {
            if snapshot != current {
                publishMobileDiagnostic(
                    domain: "continuity",
                    ApplicationDiagnosticFactory.mobileContinuityState(.stale)
                )
            }
            return
        }
        mobileSceneWindowSnapshot = snapshot
        mobileSceneActivity = snapshot.state.activity
        switch snapshot.state {
        case .detached:
            publishMobileDiagnostic(
                domain: "scene",
                ApplicationDiagnosticFactory.mobileSceneState(.detached)
            )
        case let .attached(_, _, geometry):
            publishMobileDiagnostic(
                domain: "scene",
                ApplicationDiagnosticFactory.mobileSceneState(
                    geometry.resizePhase == .resizing ? .resizing : .settled
                )
            )
        case .unavailable:
            publishMobileDiagnostic(
                domain: "scene",
                ApplicationDiagnosticFactory.mobileSceneState(.invalidGeometry)
            )
        }
        queueMobileRuntimeApplication()
    }

    func receiveMobileDisplayEDREvent(
        _ event: MobileDisplayEDRObserverEvent
    ) {
        guard !isMobileRuntimeRevisionExhausted,
              activeMediaSessionID == activeStreamSessionID,
              activeMediaGeneration != nil,
              acceptMobileSurfaceGeneration(event.surfaceGeneration) else {
            publishMobileDiagnostic(
                domain: "continuity",
                ApplicationDiagnosticFactory.mobileContinuityState(.stale)
            )
            return
        }
        switch event {
        case let .snapshot(snapshot):
            if let current = mobileDisplayEDRSnapshot,
               current.surfaceGeneration == snapshot.surfaceGeneration,
               snapshot.revision.rawValue <= current.revision.rawValue {
                if snapshot != current {
                    publishMobileDiagnostic(
                        domain: "continuity",
                        ApplicationDiagnosticFactory.mobileContinuityState(.stale)
                    )
                }
                return
            }
            mobileDisplayEDRSnapshot = snapshot
            publishMobileDisplayDiagnostic(snapshot.state)
        case .revisionExhausted:
            mobileDisplayEDRSnapshot = nil
            publishMobileDiagnostic(
                domain: "display",
                ApplicationDiagnosticFactory.mobileDisplayState(.fallback)
            )
        }
        queueMobileRuntimeApplication()
    }
#endif

    func receiveTVVisionGeometryUpdate(
        _ update: TVVisionStreamGeometryBindingUpdate
    ) {
        guard let platform = expectedTVVisionPlatform,
              update.platform == platform,
              update.surfaceGeneration.domain == .surface,
              let sessionID = activeStreamSessionID,
              activeMediaSessionID == sessionID,
              let mediaGeneration = activeMediaGeneration,
              let presentationGeneration = try? TVVisionGeneration(
                  domain: .presentation,
                  rawValue: update.surfaceGeneration.rawValue
              ),
              let inputGeneration = try? TVVisionGeneration(
                  domain: .input,
                  rawValue: mediaGeneration
              ),
              let ownership = try? TVVisionPresentationOwnership(
                  platform: platform,
                  sessionID: sessionID,
                  mediaGeneration: mediaGeneration,
                  presentationGeneration: presentationGeneration,
                  inputGeneration: inputGeneration
              ) else { return }

        let previousAdmission = tvVisionPlatformGeometryAdmission
        if let admission = previousAdmission,
           admission.ownership.sessionID == sessionID,
           admission.ownership.mediaGeneration == mediaGeneration {
            if ownership.presentationGeneration
                < admission.ownership.presentationGeneration {
                return
            }
            if ownership == admission.ownership,
               update.revision.rawValue <= admission.update.revision.rawValue {
                return
            }
        } else if let current = tvVisionPlatformPresentationOwnership,
                  current.sessionID == sessionID,
                  current.mediaGeneration == mediaGeneration,
                  ownership.presentationGeneration
                    < current.presentationGeneration {
            return
        }
        tvVisionPlatformGeometryAdmission = TVVisionPlatformGeometryAdmission(
            ownership: ownership,
            update: update
        )
        if platform == .tvOS,
           let stamp = try? TVRemoteSurfaceFocusStamp(
            surfaceGeneration: update.surfaceGeneration,
            revision: update.revision
           ) {
            tvRemoteFocusHandoffState = tvRemoteFocusHandoffState
                .observingSurfaceFocus(
                    stamp: stamp,
                    actualEligibility:
                        actualTVRemoteSurfaceFocusEligibility(update)
                )
            closeTVRemoteSurfaceAdmissionIfNeeded(
                previousAdmission: previousAdmission,
                update: update,
                ownership: ownership
            )
        }
        scheduleTVVisionPlatformGeometryApplication(
            update,
            ownership: ownership
        )
        if let roster = tvControllerRosterState {
            scheduleTVGameControllerRouting(roster)
        }
    }

    func receiveTVRemoteSurfacePressEvent(
        _ event: TVRemoteSurfacePressEvent
    ) -> TVRemoteSurfacePressDisposition {
        tvRemoteSurfacePressCaptureOwner?.handle(event) ?? .local
    }

    func receiveTVRemoteReservedCommand(_ command: TVRemoteReservedCommand) {
        guard expectedTVVisionPlatform == .tvOS else { return }
        tvRemoteReservedCommandState = .resolve(command)
        guard command == .backMenu else { return }
        setTVStreamOverlayVisible(true)
    }

    func receiveTVGameControllerRoster(
        _ roster: TVControllerRosterSnapshot
    ) {
        guard expectedTVVisionPlatform == .tvOS,
              !isTVRemoteInputReleasePending,
              activeMediaGeneration == roster.inputGeneration.rawValue,
              roster.controllers.allSatisfy({ $0.lease.platform == .tvOS }) else {
            return
        }
        guard roster != tvControllerRosterState else { return }
        tvControllerRosterState = roster
        refreshTVRemoteSurfacePressOwnership()
        scheduleTVGameControllerRosterApplication(roster)
        scheduleTVGameControllerRouting(roster)
    }

    func receiveTVGameControllerMotion(
        _ sample: TVGameControllerMotionSample
    ) {
        guard expectedTVVisionPlatform == .tvOS,
              !isTVRemoteInputReleasePending,
              activeMediaGeneration == sample.lease.inputGeneration.rawValue,
              tvControllerRosterState?.controllers.contains(where: {
                  $0.lease == sample.lease
              }) == true,
              currentTVRemoteInputSnapshot?.focusEligibility == .eligible else {
            return
        }
        let key = [
            TVGameControllerRoutingIdentity(lease: sample.lease).rawValue,
            String(sample.type.rawValue)
        ].joined(separator: ":")
        tvPendingControllerMotionSamples[key] = sample
        startTVGameControllerMotionDrainIfNeeded()
    }

    func tvRemoteSurfacePressDisposition(
        for surfaceGeneration: TVVisionGeneration
    ) -> TVRemoteSurfacePressDisposition {
        tvRemoteSurfacePressCaptureOwner?.disposition(
            for: surfaceGeneration
        ) ?? .local
    }

    func setTVStreamWorkspaceVisible(_ visible: Bool) {
        guard expectedTVVisionPlatform == .tvOS else { return }
        applyTVRemoteFocusHandoffState(
            tvRemoteFocusHandoffState.settingWorkspaceVisible(
                visible,
                currentGeometryStamp: currentTVVisionGeometryStamp
            )
        )
    }

    func setTVStreamOverlayVisible(_ visible: Bool) {
        guard expectedTVVisionPlatform == .tvOS else { return }
        applyTVRemoteFocusHandoffState(
            tvRemoteFocusHandoffState.settingOverlayVisible(
                visible,
                currentGeometryStamp: currentTVVisionGeometryStamp
            )
        )
    }

    func publishHDRPresentationDiagnostic(
        _ state: HDRPresentationDiagnosticState
    ) {
        let presentationStatus = HDRPresentationStatus(state)
        if presentationStatus != hdrPresentationStatus {
            hdrPresentationStatus = presentationStatus
        }
        guard state != lastHDRPresentationDiagnosticState else { return }
        lastHDRPresentationDiagnosticState = state
        switch state {
        case .inactive:
            diagnostics.clearActionableEvents(in: [.hdr])
        case .activeSDR, .activeEDR:
            diagnostics.clearActionableEvents(in: [.hdr])
            if let diagnostic = ApplicationDiagnosticFactory.hdrPresentationState(state) {
                diagnostics.record(diagnostic)
            }
        case .sdrFallback, .invalidInput, .unsupportedOutput,
             .staleRevision, .pipelineFailure:
            if let diagnostic = ApplicationDiagnosticFactory.hdrPresentationState(state) {
                diagnostics.record(diagnostic)
            }
        }
    }

    func claimHDRPresentationDiagnosticOwnership(_ ownerID: UUID) {
        activeHDRPresentationDiagnosticOwnerID = ownerID
    }

    func publishHDRPresentationDiagnostic(
        _ state: HDRPresentationDiagnosticState,
        ownerID: UUID
    ) {
        guard activeHDRPresentationDiagnosticOwnerID == ownerID else { return }
        publishHDRPresentationDiagnostic(state)
    }

    func releaseHDRPresentationDiagnosticOwnership(_ ownerID: UUID) {
        guard activeHDRPresentationDiagnosticOwnerID == ownerID else { return }
        activeHDRPresentationDiagnosticOwnerID = nil
    }

    @discardableResult
    func submitMacPlatformInput(
        _ sample: MacPlatformInputSample
    ) -> MacSessionInputEnqueueResult {
        guard let generation = activeMacInputGeneration else {
            return .rejected(.inactiveGeneration)
        }
        guard let sessionID = activeStreamSessionID,
              activeMediaSessionID == sessionID,
              activeMediaGeneration != nil,
              activeMediaReadiness.contains(.input),
              macInputSurfacePolicy.admitsInput,
              let coordinateSnapshot = renderState.coordinateSnapshot else {
            return .rejected(.admissionClosed)
        }
        let result = macSessionInputCoordinator.enqueue(
            MacInputSampleEnvelope(
                sample: sample,
                coordinateSnapshot: coordinateSnapshot,
                cursorPolicy: macInputSurfacePolicy.cursorPolicy,
                forwardsSystemShortcuts: macInputSurfacePolicy.forwardsSystemShortcuts
            ),
            generation: generation
        )
        if result == .rejected(.inactiveGeneration)
            || result == .rejected(.staleGeneration) {
            activeMacInputGeneration = nil
        }
        return result
    }

    func macSessionInputSnapshot() -> MacSessionInputCoordinatorSnapshot {
        macSessionInputCoordinator.snapshot()
    }

    func exitMacRelativePointerCapture() {
        guard settings.input.preferRelativeMouseMode else { return }
        settings.input.preferRelativeMouseMode = false
        refreshMacInputSurfacePolicy()
    }

    func loadHosts() async {
        do {
            hosts = try await hostLibraryManager.loadHosts()
            if selectedHostID == nil {
                selectedHostID = hosts.first?.id
            }
            diagnostics.record("Loaded \(hosts.count) saved hosts")
            logger.info("Loaded \(self.hosts.count, privacy: .public) saved hosts")
        } catch {
            diagnostics.record(
                "The saved host library could not be loaded.",
                subsystem: "hosts",
                severity: .error,
                code: "host_library_load_failed"
            )
            logger.error("Failed to load saved hosts")
        }
    }

    func loadSettings() async {
        do {
            settings = try await settingsRepository.loadSettings()
            updateRenderPreferences()
            refreshMacInputSurfacePolicy()
            diagnostics.record("Loaded stream and platform settings", subsystem: "settings")
        } catch {
            diagnostics.record(
                "Stream and platform settings could not be loaded.",
                subsystem: "settings",
                severity: .error,
                code: "settings_load_failed"
            )
        }
    }

    func loadCachedApps() async {
        do {
            let snapshots = try await appCatalogRepository.loadSnapshots()
            appsByHostID = Dictionary(uniqueKeysWithValues: snapshots.map { ($0.hostID, $0.apps) })
            if let selectedHostID, streamLaunchUI.selectedAppID == nil {
                streamLaunchUI.selectedAppID = appsByHostID[selectedHostID]?.first?.id
            }
            diagnostics.record("Loaded cached app lists for \(snapshots.count) hosts", subsystem: "apps")
        } catch {
            diagnostics.record(
                "Cached app lists could not be loaded.",
                subsystem: "apps",
                severity: .error,
                code: "app_cache_load_failed"
            )
        }
    }

    func saveSettings() async {
        do {
            try await settingsRepository.saveSettings(settings)
            updateRenderPreferences()
            refreshMacInputSurfacePolicy()
            diagnostics.record("Saved settings", subsystem: "settings")
        } catch {
            diagnostics.record(
                "Stream and platform settings could not be saved.",
                subsystem: "settings",
                severity: .error,
                code: "settings_save_failed"
            )
        }
    }

    func addManualHost(name: String? = nil, address: String) async {
        do {
            hosts = try await hostLibraryManager.addManualHost(name: name, address: address)
            selectedHostID = hosts.first { $0.address == address }?.id ?? selectedHostID ?? hosts.first?.id
            diagnostics.record("Added a host", subsystem: "hosts", code: "host_added")
        } catch {
            diagnostics.record(
                "The host could not be added.",
                subsystem: "hosts",
                severity: .error,
                code: "host_add_failed"
            )
        }
    }

    func removeSelectedHost() async {
        guard let hostID = selectedHost?.id else { return }
        do {
            hosts = try await hostLibraryManager.removeHost(id: hostID)
            appsByHostID[hostID] = nil
            if selectedHostID == hostID {
                selectedHostID = hosts.first?.id
            }
            diagnostics.record("Removed host", subsystem: "hosts")
        } catch {
            diagnostics.record(
                "The selected host could not be removed.",
                subsystem: "hosts",
                severity: .error,
                code: "host_remove_failed"
            )
        }
    }

    func beginPairing(host: MoonlightHost) async {
        guard runtimeProviders.pairing != nil else {
            let diagnostic = ApplicationDiagnosticFactory.pairingUnavailable
            pairingUI = PairingUIState(
                hostID: host.id,
                stage: .failed,
                message: diagnostic.summary,
                actionMessage: diagnostic.action?.label
            )
            session.phase = .disconnected
            diagnostics.record(diagnostic)
            return
        }

        await cancelPairing(showCancelledState: false)
        diagnostics.clearActionableEvents(in: [.pairing])
        let attemptID = UUID()
        pairingUI = PairingUIState(
            hostID: host.id,
            attemptID: attemptID,
            stage: .idle,
            isRunning: true,
            message: "Preparing client identity..."
        )
        session.phase = .pairing(pin: "")
        preparedPairingIdentity = nil

        do {
            let identity = try await clientIdentityProvisioner.loadOrCreateIdentity(
                createdAt: Date()
            )
            guard pairingUI.attemptID == attemptID else { return }
            preparedPairingIdentity = identity
            clientUniqueID = identity.id.uuidString
            pairingUI.stage = .waitingForPIN
            pairingUI.isRunning = false
            pairingUI.message = "Enter the PIN shown on \(host.name)."
            diagnostics.record("Prepared client identity for pairing", subsystem: "pairing")
        } catch {
            guard pairingUI.attemptID == attemptID else { return }
            failPairingAttempt(
                attemptID: attemptID,
                diagnostic: ApplicationDiagnosticFactory.pairingIdentityUnavailable
            )
        }
    }

    func submitPairingPIN() async {
        guard let hostID = pairingUI.hostID,
              let host = hosts.first(where: { $0.id == hostID }),
              let attemptID = pairingUI.attemptID
        else { return }

        guard !pairingUI.isRunning,
              pairingUI.stage == .waitingForPIN else {
            return
        }

        guard let provider = runtimeProviders.pairing else {
            failPairingAttempt(
                attemptID: attemptID,
                diagnostic: ApplicationDiagnosticFactory.pairingUnavailable
            )
            return
        }
        guard let identity = preparedPairingIdentity else {
            failPairingAttempt(
                attemptID: attemptID,
                diagnostic: ApplicationDiagnosticFactory.pairingIdentityUnavailable
            )
            return
        }

        let pin = pairingUI.pin
        guard isPairingPINValid else {
            pairingUI.message = "PIN must contain exactly four digits."
            return
        }

        let request = PairingRuntimeRequest(
            attemptID: attemptID,
            host: host,
            pin: pin,
            clientIdentity: identity
        )
        pairingUI.pin = ""
        pairingUI.isRunning = true
        pairingUI.stage = .exchangingSecrets
        pairingUI.message = pairingMessage(for: .exchangingSecrets, hostName: host.name)
        session.phase = .pairing(pin: "")

        var completedResult: PairingResult?
        do {
            let events = await provider.pair(request)
            for try await event in events {
                guard pairingUI.attemptID == attemptID else { return }
                switch event {
                case let .progress(snapshot):
                    guard snapshot.attemptID == attemptID,
                          snapshot.hostID == hostID else {
                        throw PairingApplicationError.invalidAuthenticatedCompletion
                    }
                    if let failure = snapshot.failure {
                        throw failure
                    }
                    pairingUI.stage = snapshot.stage
                    pairingUI.message = pairingMessage(for: snapshot.stage, hostName: host.name)
                    pairingUI.actionMessage = nil
                case let .completed(result):
                    try validatePairingCompletion(result, expectedHostID: hostID)
                    completedResult = result
                }
            }
            guard let result = completedResult else {
                throw PairingApplicationError.incompleteRuntimeStream
            }
            guard pairingUI.attemptID == attemptID else { return }
            applyPairingCompletion(result)
        } catch {
            guard pairingUI.attemptID == attemptID else { return }
            if let failure = error as? PairingFailure, failure.code == .cancelled {
                await cancelPairing(showCancelledState: true)
                return
            }
            failPairingAttempt(
                attemptID: attemptID,
                diagnostic: ApplicationDiagnosticFactory.pairingFailure(error)
            )
            await provider.cancelPairing(attemptID: attemptID)
        }
    }

    func cancelPairing() async {
        await cancelPairing(showCancelledState: true)
    }

    func refreshAppsForSelectedHost() async {
        guard let host = selectedHost else { return }
        guard host.pairingState == .paired else {
            appCatalogUI.errorMessage = "Pair the host before refreshing apps."
            diagnostics.record("App refresh requires a paired host", subsystem: "apps")
            return
        }

        appCatalogUI.isRefreshing = true
        appCatalogUI.errorMessage = nil
        defer { appCatalogUI.isRefreshing = false }

        do {
            let snapshot = try await appCatalogManager.refreshApps(for: host, clientUniqueID: clientUniqueID)
            appsByHostID[host.id] = snapshot.apps
            let snapshots = appsByHostID.map { hostID, apps in
                AppListSnapshot(hostID: hostID, apps: apps, updatedAt: hostID == host.id ? snapshot.updatedAt : Date())
            }
            try await appCatalogRepository.saveSnapshots(snapshots)
            streamLaunchUI.selectedAppID = snapshot.apps.first?.id
            appCatalogUI.lastUpdatedAt = snapshot.updatedAt
            diagnostics.record(
                "Loaded \(snapshot.apps.count) apps",
                subsystem: "apps",
                code: "app_catalog_refreshed"
            )
        } catch {
            appCatalogUI.errorMessage = "The app catalog could not be refreshed."
            diagnostics.record(
                "The app catalog could not be refreshed.",
                subsystem: "apps",
                severity: .error,
                code: "app_catalog_refresh_failed"
            )
        }
    }

    func select(host: MoonlightHost) {
        selectedHostID = host.id
        streamLaunchUI.selectedAppID = appsByHostID[host.id]?.first?.id
    }

    func select(app: RemoteApp) {
        streamLaunchUI.selectedAppID = app.id
    }

    func launchSelectedApp() async {
        guard let host = selectedHost, let app = selectedApp else {
            streamLaunchUI.errorMessage = "Select a host and app first."
            return
        }

        guard activeStreamSessionID == nil else {
            return
        }

        guard isStreamTransportAvailable,
              let sessionControlProvider = runtimeProviders.sessionControl else {
            let diagnostic = ApplicationDiagnosticFactory.streamUnavailable
            streamLaunchUI.errorMessage = diagnostic.summary
            streamLaunchUI.actionMessage = diagnostic.action?.label
            session.activeHostID = nil
            session.phase = .disconnected
            renderState.policy = .idle
            diagnostics.record(diagnostic)
            return
        }

        let request: StreamLaunchRequest
        do {
            let remoteInputKey = try remoteInputKeyOverride ?? remoteInputKeyGenerator.generate()
            request = StreamLaunchRequest(
                host: host,
                app: app,
                preferences: settings.stream,
                clientUniqueID: clientUniqueID,
                remoteInputKey: remoteInputKey,
                audioPlaybackMode: .clientOnly,
                controllerBitmap: 0,
                optimizeGameSettings: true
            )
        } catch {
            let contextualError: Error
            if error is StreamNegotiationFailure {
                contextualError = error
            } else {
                contextualError = StreamNegotiationFailure(
                    code: .invalidInputKey,
                    subsystem: "stream.input",
                    message: "Remote input key generation failed."
                )
            }
            failStreamSession(contextualError, sessionID: nil)
            return
        }

        let sessionID = UUID()
        var didPrepareSession = false
        do {
            let snapshot = try await streamSessionCoordinator.prepare(
                request,
                sessionID: sessionID
            )
            activeStreamSessionID = sessionID
            didPrepareSession = true
            activeControlReadiness = []
            activeMediaReadiness = []
            clearStreamActionPresentation()
            streamLaunchUI.isLaunching = true
            session.activeHostID = host.id
            session.lastError = nil
            navigationSelection = .stream
            applySessionSnapshot(snapshot)

            var receivedTerminalEvent = false
            let events = await sessionControlProvider.start(
                sessionID: sessionID,
                request: request
            )
            for try await event in events {
                guard activeStreamSessionID == sessionID else { return }
                try await consumeSessionControlEvent(
                    event,
                    sessionID: sessionID,
                    sessionControlProvider: sessionControlProvider
                )
                if case .terminated = event {
                    receivedTerminalEvent = true
                }
            }

            guard activeStreamSessionID == sessionID else { return }
            guard receivedTerminalEvent else {
                throw SessionApplicationError.incompleteControlStream
            }
            activeStreamSessionID = nil
            streamLaunchUI.isLaunching = false
        } catch {
            guard activeStreamSessionID == nil || activeStreamSessionID == sessionID else {
                return
            }
            guard activeStreamSessionID == sessionID else {
                if !didPrepareSession {
                    failStreamSession(error, sessionID: nil)
                }
                return
            }
            await stopMediaEnvironment(sessionID: sessionID)
            _ = try? await streamSessionCoordinator.fail(
                error,
                sessionID: sessionID
            )
            failStreamSession(error, sessionID: sessionID)
            await sessionControlProvider.stop(sessionID: sessionID)
        }
    }

    func stopStream() async {
        clearStreamActionPresentation()
        guard let sessionID = activeStreamSessionID,
              let sessionControlProvider = runtimeProviders.sessionControl else {
            return
        }
        await releaseTVRemoteInputForTerminal()
        await terminateMacInputGeneration(reason: .stop)
        activeStreamSessionID = nil
        streamLaunchUI.isLaunching = false
        session.phase = .stopping
        _ = try? await streamSessionCoordinator.beginLocalStop(sessionID: sessionID)
        await stopMediaEnvironment(sessionID: sessionID, inputReason: .stop)
        await sessionControlProvider.stop(sessionID: sessionID)
        _ = try? await streamSessionCoordinator.completeLocalStop(sessionID: sessionID)
        diagnostics.record("Stopped stream session", subsystem: "stream")
        session.activeHostID = nil
        session.lastError = nil
        session.phase = .disconnected
        renderState.policy = .idle
    }

    func updateSpatialAudioPreferences(
        _ preferences: SessionSpatialAudioPreferences
    ) async throws {
        guard preferences != spatialAudioPreferences else { return }
        settings.audio = AudioPreferences(preferences)
        guard let sessionID = activeStreamSessionID,
              activeMediaSessionID == sessionID,
              let mediaGeneration = activeMediaGeneration else {
            return
        }
        try await applySpatialAudioPreferences(
            preferences,
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        )
    }

    func sendRemoteInput(_ event: RemoteInputEvent) async throws {
        guard let sessionID = activeStreamSessionID,
              activeMediaSessionID == sessionID,
              let mediaGeneration = activeMediaGeneration else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        guard activeMediaReadiness.contains(.input) else {
            throw SessionMediaEnvironmentError.inputUnavailable
        }
        let application = SessionInputApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            event: event
        )
        do {
            try await sessionMediaEnvironment.sendInput(application)
        } catch {
            if activeStreamSessionID == sessionID,
               activeMediaSessionID == sessionID,
               activeMediaGeneration == mediaGeneration {
                isMacInputGenerationFailed = true
                refreshMacInputSurfacePolicy()
                diagnostics.record(ApplicationDiagnosticFactory.streamFailure(error))
            }
            throw error
        }
    }

    func releaseRemoteInput() async throws {
        guard let sessionID = activeMediaSessionID,
              activeStreamSessionID == nil
                || activeStreamSessionID == sessionID,
              let mediaGeneration = activeMediaGeneration else {
            throw SessionMediaEnvironmentError.inactiveSession
        }
        let application = SessionInputReleaseApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        )
        do {
            try await sessionMediaEnvironment.releaseInput(application)
        } catch {
            if activeStreamSessionID == sessionID,
               activeMediaSessionID == sessionID,
               activeMediaGeneration == mediaGeneration {
                isMacInputGenerationFailed = true
                refreshMacInputSurfacePolicy()
                diagnostics.record(ApplicationDiagnosticFactory.streamFailure(error))
            }
            throw error
        }
    }

    func toggleDemoSession() {
        if session.isStreaming {
            session.phase = .disconnected
            renderState.policy = .idle
            diagnostics.record("Stopped demo stream", subsystem: "stream")
        } else {
            session.phase = .streaming
            renderState.policy = .active
            updateRenderPreferences()
            diagnostics.record("Started demo stream", subsystem: "stream")
        }
    }

    private func cancelPairing(showCancelledState: Bool) async {
        guard let attemptID = pairingUI.attemptID else { return }
        let hostID = pairingUI.hostID
        pairingUI.attemptID = nil
        pairingUI.pin = ""
        pairingUI.isRunning = false
        preparedPairingIdentity = nil
        session.phase = .disconnected

        if showCancelledState {
            pairingUI.stage = .cancelled
            pairingUI.message = "Pairing was cancelled."
            diagnostics.record("Cancelled pairing attempt", subsystem: "pairing")
        } else if !showCancelledState {
            pairingUI = PairingUIState(hostID: hostID)
        }

        if let provider = runtimeProviders.pairing {
            await provider.cancelPairing(attemptID: attemptID)
        }
    }

    private func applyPairingCompletion(_ result: PairingResult) {
        if let index = hosts.firstIndex(where: { $0.id == result.host.id }) {
            hosts[index] = result.host
        } else {
            hosts.append(result.host)
        }
        selectedHostID = result.host.id
        pairingUI = PairingUIState(
            hostID: result.host.id,
            stage: .paired,
            message: "Paired with \(result.host.name)."
        )
        preparedPairingIdentity = nil
        session.phase = .disconnected
        diagnostics.clearActionableEvents(in: [.pairing])
        diagnostics.record("Authenticated pairing completed", subsystem: "pairing")
    }

    private func failPairingAttempt(
        attemptID: UUID,
        diagnostic: ApplicationDiagnostic
    ) {
        guard pairingUI.attemptID == attemptID else { return }
        pairingUI.attemptID = nil
        pairingUI.stage = .failed
        pairingUI.pin = ""
        pairingUI.isRunning = false
        pairingUI.message = diagnostic.summary
        pairingUI.actionMessage = diagnostic.action?.label
        preparedPairingIdentity = nil
        let failure = SessionError(subsystem: diagnostic.subsystem, message: diagnostic.summary)
        session.phase = .failed(failure)
        diagnostics.record(diagnostic)
    }

    private func validatePairingCompletion(
        _ result: PairingResult,
        expectedHostID: MoonlightHost.ID
    ) throws {
        guard result.host.id == expectedHostID,
              result.host.pairingState == .paired,
              let pin = result.host.pinnedIdentity,
              pin.serverCertificateDER == result.serverIdentity.certificateDER,
              pin.certificateSHA256.caseInsensitiveCompare(
                  result.serverIdentity.certificateSHA256
              ) == .orderedSame else {
            throw PairingApplicationError.invalidAuthenticatedCompletion
        }
    }

    private func pairingMessage(for stage: PairingStage, hostName: String) -> String {
        switch stage {
        case .idle:
            return "Preparing pairing with \(hostName)..."
        case .waitingForPIN:
            return "Preparing PIN exchange with \(hostName)..."
        case .exchangingSecrets:
            return "Exchanging authenticated pairing secrets..."
        case .verifyingServer:
            return "Verifying the host identity..."
        case .pinningIdentity:
            return "Saving the verified host identity..."
        case .paired:
            return "Authenticated pairing completed."
        case .failed:
            return "Authenticated pairing failed."
        case .cancelled:
            return "Pairing was cancelled."
        }
    }

    private func applySessionSnapshot(_ snapshot: StreamSessionSnapshot) {
        defer {
            refreshMacInputSurfacePolicy()
            refreshHDRRenderResolution()
        }
        switch snapshot.stage {
        case .idle, .disconnected:
            clearActiveVideoPresentation()
            clearActiveAudioRuntime()
            activeStreamSessionID = nil
            activeControlReadiness = []
            activeMediaReadiness = []
            streamLaunchUI.isLaunching = false
            clearStreamActionPresentation()
            session.activeHostID = nil
            session.lastError = nil
            session.phase = .disconnected
            renderState.policy = .idle
            if let reason = snapshot.terminationReason {
                _ = reason
                diagnostics.record(ApplicationDiagnostic(
                    category: .transport,
                    severity: .info,
                    code: "host_terminated_session",
                    summary: "The host ended the streaming session.",
                    action: nil
                ))
            }

        case .resolvingHost, .validatingPairing, .preparingParameters, .launching:
            session.phase = .connecting(stage: "Launching Stream")
            renderState.policy = .idle

        case .readyForTransport:
            session.phase = .connecting(stage: pendingTransportMessage(for: snapshot))
            renderState.policy = .idle

        case .streaming:
            diagnostics.clearActionableEvents(in: [.transport])
            streamLaunchUI.errorMessage = nil
            streamLaunchUI.actionMessage = nil
            streamLaunchUI.isLaunching = false
            session.phase = .streaming
            renderState.policy = hasPlatformLifecycle
                ? latestLifecycleDirective.renderPolicy
                : .active
            updateRenderPreferences()

        case .reconnecting:
            clearActiveAudioRuntime()
            streamLaunchUI.isLaunching = false
            let suffix = snapshot.reconnectAttempt.map { " (Attempt \($0))" } ?? ""
            session.phase = .connecting(stage: "Reconnecting\(suffix)")
            renderState.policy = .idle

        case .stopping:
            clearActiveAudioRuntime()
            streamLaunchUI.isLaunching = false
            session.phase = .stopping
            renderState.policy = .idle

        case .failed:
            failStreamSession(
                snapshot.failure ?? SessionError(
                    subsystem: "stream.control",
                    message: "Session control failed."
                ),
                sessionID: snapshot.sessionID
            )
        }
    }

    private func consumeSessionControlEvent(
        _ event: SessionControlEvent,
        sessionID: UUID,
        sessionControlProvider: any SessionControlProvider
    ) async throws {
        switch event {
        case let .channelsReady(reportedReadiness):
            activeControlReadiness = reportedReadiness.intersection(.control)
            try await applyAggregatedReadiness(sessionID: sessionID)

        case let .negotiated(configuration):
            let snapshot = try await streamSessionCoordinator.apply(
                event,
                sessionID: sessionID
            )
            applySessionSnapshot(snapshot)
            _ = try await startMediaEnvironment(
                sessionID: sessionID,
                configuration: configuration,
                sessionControlProvider: sessionControlProvider
            )

        case .reconnecting:
            activeControlReadiness = []
            activeMediaReadiness = []
            let snapshot = try await streamSessionCoordinator.apply(
                event,
                sessionID: sessionID
            )
            applySessionSnapshot(snapshot)
            await stopMediaEnvironment(
                sessionID: sessionID,
                inputReason: .replacement
            )
            guard activeStreamSessionID == sessionID else { return }

        case let .videoColorMetadata(metadata):
            let snapshot = try await streamSessionCoordinator.apply(
                event,
                sessionID: sessionID
            )
            applySessionSnapshot(snapshot)
            if activeMediaSessionID == sessionID {
                updateNegotiatedVideoColorMetadata(metadata)
                try await sessionMediaEnvironment.updateVideoColorMetadata(
                    metadata,
                    sessionID: sessionID
                )
            }

        case .terminated:
            await terminateMacInputGeneration(reason: .remoteTermination)
            let snapshot = try await streamSessionCoordinator.apply(
                event,
                sessionID: sessionID
            )
            applySessionSnapshot(snapshot)
            await stopMediaEnvironment(
                sessionID: sessionID,
                inputReason: .remoteTermination
            )

        case .launchAccepted, .rtspReady:
            let snapshot = try await streamSessionCoordinator.apply(
                event,
                sessionID: sessionID
            )
            applySessionSnapshot(snapshot)
        }
    }

    private func startMediaEnvironment(
        sessionID: UUID,
        configuration: NegotiatedSessionConfiguration,
        sessionControlProvider: any SessionControlProvider
    ) async throws -> Bool {
        guard activeMediaSessionID == nil else {
            throw SessionMediaEnvironmentError.sessionAlreadyActive
        }
        let events = try await sessionMediaEnvironment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: sessionControlProvider
        )
        guard activeStreamSessionID == sessionID else {
            clearTVVisionPlatformPresentationRuntime()
            _ = await sessionMediaEnvironment.stop(sessionID: sessionID)
            return false
        }
        let environmentSnapshot = await sessionMediaEnvironment.snapshot()
        guard activeStreamSessionID == sessionID,
              environmentSnapshot.sessionID == sessionID,
              environmentSnapshot.generation > 0 else {
            clearTVVisionPlatformPresentationRuntime()
            _ = await sessionMediaEnvironment.stop(sessionID: sessionID)
            return false
        }
        latestRemoteInputFeedback = nil
        clearActiveAudioRuntime()
        activeMediaSessionID = sessionID
        activeMediaGeneration = environmentSnapshot.generation
        beginTVVisionPlatformPresentationRuntime()
#if os(iOS)
        beginMobileRuntime(mediaGeneration: environmentSnapshot.generation)
#endif
        if let audioRuntime = environmentSnapshot.audioRuntime {
            applyAudioRuntimeState(audioRuntime, sessionID: sessionID)
        }
        try await applySpatialAudioPreferences(
            spatialAudioPreferences,
            sessionID: sessionID,
            mediaGeneration: environmentSnapshot.generation
        )
        beginVideoPresentation(
            negotiatedColorMetadata: configuration.video.colorMetadata
        )
        activeDecodedSourceSize = PixelSize(
            width: configuration.video.width,
            height: configuration.video.height
        )
        renderState.transform.sourceSize = activeDecodedSourceSize ?? .zero
        refreshMacInputSurfacePolicy()
        appliedLifecycleApplication = nil
        let lifecycleTask = scheduleLifecycleApplication()
        await lifecycleTask?.value
        guard activeStreamSessionID == sessionID,
              activeMediaSessionID == sessionID,
              activeMediaGeneration == environmentSnapshot.generation else {
            return false
        }
        mediaConsumerTask = Task { [weak self] in
            do {
                for try await event in events {
                    try Task.checkCancellation()
                    guard let self else { return }
                    await self.consumeMediaEnvironmentEvent(
                        event,
                        sessionID: sessionID,
                        sessionControlProvider: sessionControlProvider
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                await self.failFromMediaEnvironment(
                    error,
                    sessionID: sessionID,
                    sessionControlProvider: sessionControlProvider
                )
            }
        }
        return true
    }

    private func consumeMediaEnvironmentEvent(
        _ event: SessionMediaEnvironmentEvent,
        sessionID: UUID,
        sessionControlProvider: any SessionControlProvider
    ) async {
        guard activeStreamSessionID == sessionID,
              activeMediaSessionID == sessionID else { return }
        switch event {
        case let .readiness(readiness):
            let previousReadiness = activeMediaReadiness
            activeMediaReadiness = readiness.intersection([.video, .audio, .input])
            refreshHDRRenderResolution()
            if previousReadiness.contains(.input),
               !activeMediaReadiness.contains(.input) {
                await terminateMacInputGeneration(reason: .inputChannelFailure)
            } else if activeMediaReadiness.contains(.input) {
                await activateMacInputGenerationIfNeeded()
            }
            refreshTVRemoteSurfacePressOwnership()
            do {
                try await applyAggregatedReadiness(sessionID: sessionID)
            } catch {
                await failFromMediaEnvironment(
                    error,
                    sessionID: sessionID,
                    sessionControlProvider: sessionControlProvider
                )
            }
        case let .feedback(feedback):
            latestRemoteInputFeedback = feedback
            applyTVGameControllerFeedback(feedback)
            if case let .diagnostic(inputDiagnostic) = feedback {
                diagnostics.record(ApplicationDiagnosticFactory.remoteFeedback(inputDiagnostic))
            }
        case let .videoPresentation(presentationEvent):
            applyVideoPresentationEvent(
                presentationEvent,
                sessionID: sessionID
            )
        case let .audioRuntime(audioRuntime):
            applyAudioRuntimeState(audioRuntime, sessionID: sessionID)
        case let .mobileRuntime(mobileRuntime):
            applyMobileRuntimeState(mobileRuntime, sessionID: sessionID)
        case let .tvVisionPlatformPresentation(platformPresentation):
            applyTVVisionPlatformPresentationState(
                platformPresentation,
                sessionID: sessionID
            )
        }
    }

    private func applySpatialAudioPreferences(
        _ preferences: SessionSpatialAudioPreferences,
        sessionID: UUID,
        mediaGeneration: UInt64
    ) async throws {
        let application = SessionSpatialAudioPreferenceApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            preferences: preferences
        )
        do {
            try await sessionMediaEnvironment.updateSpatialAudioPreferences(
                application
            )
        } catch {
            guard activeStreamSessionID == sessionID,
                  activeMediaSessionID == sessionID,
                  activeMediaGeneration == mediaGeneration else {
                throw SessionMediaEnvironmentError.staleAudioApplication
            }
            throw error
        }
        guard activeStreamSessionID == sessionID,
              activeMediaSessionID == sessionID,
              activeMediaGeneration == mediaGeneration else {
            throw SessionMediaEnvironmentError.staleAudioApplication
        }
    }

    private func applyAudioRuntimeState(
        _ state: SessionMediaAudioRuntimeState,
        sessionID: UUID
    ) {
        guard activeStreamSessionID == sessionID,
              activeMediaSessionID == sessionID,
              let mediaGeneration = activeMediaGeneration,
              state.sessionID == sessionID,
              state.mediaGeneration == mediaGeneration,
              state.runtime.sessionID == sessionID else {
            return
        }
        if let current = audioRuntimeState {
            guard current.sessionID == sessionID,
                  current.mediaGeneration == mediaGeneration,
                  state.runtime.sequence > current.runtime.sequence,
                  state.runtime.graphGeneration >= current.runtime.graphGeneration else {
                return
            }
        }
        audioRuntimeState = state
        mobileAudioSessionActive = isMobileRuntimeRevisionExhausted
            ? nil
            : state.runtime.mobileAudioSessionActive
        let diagnosticState = SpatialAudioDiagnosticState(runtime: state.runtime)
        if diagnosticState.clearsCurrentAudioAction {
            diagnostics.clearActionableEvents(in: [.audio])
        }
        diagnostics.record(
            ApplicationDiagnosticFactory.spatialAudioState(
                diagnosticState
            )
        )
#if os(iOS)
        queueMobileRuntimeApplication()
#endif
    }

    private func clearActiveAudioRuntime() {
        guard audioRuntimeState != nil else { return }
        audioRuntimeState = nil
        mobileAudioSessionActive = nil
        diagnostics.record(
            ApplicationDiagnosticFactory.spatialAudioState(.inactive)
        )
    }

    private func applyAggregatedReadiness(sessionID: UUID) async throws {
        let snapshot = try await streamSessionCoordinator.apply(
            .channelsReady(activeControlReadiness.union(activeMediaReadiness)),
            sessionID: sessionID
        )
        applySessionSnapshot(snapshot)
    }

    private func failFromMediaEnvironment(
        _ error: Error,
        sessionID: UUID,
        sessionControlProvider: any SessionControlProvider
    ) async {
        guard activeStreamSessionID == sessionID else { return }
        await releaseTVRemoteInputForTerminal()
        await terminateMacInputGeneration(reason: .inputChannelFailure)
        invalidateLifecycleApplicationPump()
        clearTVVisionPlatformPresentationRuntime(
            preservingTerminalState: true
        )
        clearMobileRuntime()
        mediaConsumerTask = nil
        activeMediaSessionID = nil
        activeMediaGeneration = nil
        activeDecodedSourceSize = nil
        clearActiveAudioRuntime()
        clearActiveVideoPresentation()
        activeMediaReadiness = []
        activeControlReadiness = []
        latestRemoteInputFeedback = nil
        _ = await sessionMediaEnvironment.stop(sessionID: sessionID)
        _ = try? await streamSessionCoordinator.fail(error, sessionID: sessionID)
        failStreamSession(error, sessionID: sessionID)
        await sessionControlProvider.stop(sessionID: sessionID)
    }

    private func stopMediaEnvironment(
        sessionID: UUID,
        inputReason: MacSessionInputTerminationReason = .stop
    ) async {
        await releaseTVRemoteInputForTerminal()
        await terminateMacInputGeneration(reason: inputReason)
        invalidateLifecycleApplicationPump()
        await stopTVVisionPlatformPresentation(
            reason: tvVisionPlatformStopReason(for: inputReason)
        )
        clearMobileRuntime()
        mediaConsumerTask?.cancel()
        mediaConsumerTask = nil
        if let mediaGeneration = activeMediaGeneration {
            videoPresentationSource.clear(
                sessionID: sessionID,
                mediaGeneration: mediaGeneration
            )
        }
        activeMediaSessionID = nil
        activeMediaGeneration = nil
        activeDecodedSourceSize = nil
        clearActiveAudioRuntime()
        clearActiveVideoPresentation()
        activeMediaReadiness = []
        latestRemoteInputFeedback = nil
        _ = await sessionMediaEnvironment.stop(sessionID: sessionID)
    }

    @discardableResult
    private func scheduleLifecycleApplication() -> Task<Void, Never>? {
        guard activeStreamSessionID != nil,
              activeMediaSessionID != nil,
              activeMediaGeneration != nil else {
            return nil
        }
        if let lifecycleApplicationTask { return lifecycleApplicationTask }

        let operationID = UUID()
        lifecycleApplicationOperationID = operationID
        let task = Task { [weak self] in
            guard let self else { return }
            await self.drainLifecycleApplications(operationID: operationID)
        }
        lifecycleApplicationTask = task
        return task
    }

    private func drainLifecycleApplications(operationID: UUID) async {
        while !Task.isCancelled,
              lifecycleApplicationOperationID == operationID,
              let sessionID = activeStreamSessionID,
              activeMediaSessionID == sessionID,
              let mediaGeneration = activeMediaGeneration {
            let application = SessionLifecycleApplication(
                sessionID: sessionID,
                mediaGeneration: mediaGeneration,
                lifecycleRevision: latestLifecycleRevision,
                directive: latestLifecycleDirective
            )
            if let appliedLifecycleApplication,
               appliedLifecycleApplication.sessionID == sessionID,
               appliedLifecycleApplication.mediaGeneration == mediaGeneration,
               appliedLifecycleApplication.lifecycleRevision >= application.lifecycleRevision {
                break
            }

            do {
                try await sessionMediaEnvironment.applyLifecycle(application)
            } catch {
                guard !Task.isCancelled,
                      lifecycleApplicationOperationID == operationID,
                      activeStreamSessionID == sessionID,
                      activeMediaSessionID == sessionID,
                      activeMediaGeneration == mediaGeneration else {
                    break
                }
                if error as? SessionMediaEnvironmentError == .staleLifecycleApplication,
                   latestLifecycleRevision > application.lifecycleRevision {
                    continue
                }
                if let sessionControlProvider = runtimeProviders.sessionControl {
                    await failFromMediaEnvironment(
                        error,
                        sessionID: sessionID,
                        sessionControlProvider: sessionControlProvider
                    )
                }
                break
            }

            guard !Task.isCancelled,
                  lifecycleApplicationOperationID == operationID,
                  activeStreamSessionID == sessionID,
                  activeMediaSessionID == sessionID,
                  activeMediaGeneration == mediaGeneration else {
                break
            }
            appliedLifecycleApplication = application
            if latestLifecycleRevision == application.lifecycleRevision { break }
        }

        guard lifecycleApplicationOperationID == operationID else { return }
        lifecycleApplicationTask = nil
        lifecycleApplicationOperationID = nil
        if let appliedLifecycleApplication,
           appliedLifecycleApplication.lifecycleRevision < latestLifecycleRevision {
            scheduleLifecycleApplication()
        }
    }

    private func invalidateLifecycleApplicationPump() {
        lifecycleApplicationTask?.cancel()
        lifecycleApplicationTask = nil
        lifecycleApplicationOperationID = nil
        appliedLifecycleApplication = nil
    }

    private func activateMacInputGenerationIfNeeded() async {
        guard activeMacInputGeneration == nil,
              let sessionID = activeStreamSessionID,
              activeMediaSessionID == sessionID,
              activeMediaGeneration != nil,
              activeMediaReadiness.contains(.input) else { return }
        let initialEligibility: Bool
        if case .open = latestLifecycleDirective.input {
            initialEligibility = true
        } else {
            initialEligibility = false
        }
        let generation = await macSessionInputCoordinator.activate(
            isFocusEligible: initialEligibility
        )
        guard activeStreamSessionID == sessionID,
              activeMediaSessionID == sessionID,
              activeMediaGeneration != nil,
              activeMediaReadiness.contains(.input) else {
            _ = await macSessionInputCoordinator.terminate(
                generation: generation,
                reason: .replacement
            )
            return
        }
        activeMacInputGeneration = generation
        isMacInputGenerationFailed = false
        diagnostics.clearActionableEvents(in: [.input])
        applyInputLifecycle(latestLifecycleDirective.input)
        refreshMacInputSurfacePolicy()
    }

    private func terminateMacInputGeneration(
        reason: MacSessionInputTerminationReason
    ) async {
        guard let generation = activeMacInputGeneration else { return }
        activeMacInputGeneration = nil
        isMacInputGenerationFailed = false
        refreshMacInputSurfacePolicy()
        _ = await macSessionInputCoordinator.terminate(
            generation: generation,
            reason: reason
        )
    }

    private func applyInputLifecycle(_ directive: InputLifecycleDirective) {
        guard let generation = activeMacInputGeneration else { return }
        switch directive {
        case .open:
            _ = macSessionInputCoordinator.setFocusEligible(
                true,
                generation: generation
            )
        case .closed:
            _ = macSessionInputCoordinator.setFocusEligible(
                false,
                generation: generation
            )
        }
    }

    private func clearPresentationIfRequired(
        _ directive: PresentationLifecycleDirective
    ) {
        guard case .clear = directive,
              let sessionID = activeMediaSessionID,
              let mediaGeneration = activeMediaGeneration else { return }
        if let event = videoPresentationSource.discardFrames(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration
        ) {
            applyVideoPresentationEvent(event, sessionID: sessionID)
        } else {
            activeVideoDecoderGeneration = nil
            renderState.decodedVideoPresentationContract = nil
            refreshHDRRenderResolution()
        }
    }

    private func pendingTransportMessage(for snapshot: StreamSessionSnapshot) -> String {
        guard snapshot.negotiatedConfiguration != nil else {
            return "Negotiating Stream Transport"
        }

        let healthy = snapshot.channelHealth.healthyChannels
        let required = snapshot.channelHealth.requiredChannels
        let channels: [(SessionChannelReadiness, String)] = [
            (.control, "Control"),
            (.video, "Video"),
            (.audio, "Audio"),
            (.input, "Input")
        ]
        let pending = channels.compactMap { channel, name in
            required.contains(channel) && !healthy.contains(channel) ? name : nil
        }
        return pending.isEmpty
            ? "Confirming Stream Readiness"
            : "Waiting for \(pending.joined(separator: ", "))"
    }

    private func failStreamSession(_ error: Error, sessionID: UUID?) {
        if let sessionID,
           activeStreamSessionID != nil,
           activeStreamSessionID != sessionID {
            return
        }

        invalidateLifecycleApplicationPump()
        clearTVVisionPlatformPresentationRuntime(
            preservingTerminalState: true
        )
        clearMobileRuntime()
        let diagnostic = ApplicationDiagnosticFactory.streamFailure(error)
        let sessionError = SessionError(
            subsystem: diagnostic.subsystem,
            message: diagnostic.summary
        )

        activeStreamSessionID = nil
        activeMediaSessionID = nil
        activeMediaGeneration = nil
        activeDecodedSourceSize = nil
        clearActiveAudioRuntime()
        clearActiveVideoPresentation()
        activeControlReadiness = []
        activeMediaReadiness = []
        latestRemoteInputFeedback = nil
        streamLaunchUI.isLaunching = false
        streamLaunchUI.errorMessage = sessionError.message
        streamLaunchUI.actionMessage = diagnostic.action?.label
        session.activeHostID = nil
        session.lastError = sessionError
        session.phase = .failed(sessionError)
        renderState.policy = .idle
        refreshMacInputSurfacePolicy()
        diagnostics.record(diagnostic)
    }

    private func refreshMacInputSurfacePolicy() {
        let lifecycleAllowsInput: Bool
        if case .open = latestLifecycleDirective.input {
            lifecycleAllowsInput = true
        } else {
            lifecycleAllowsInput = false
        }
        let admitsInput = hasPlatformLifecycle
            && session.isStreaming
            && lifecycleAllowsInput
            && activeStreamSessionID != nil
            && activeMediaSessionID == activeStreamSessionID
            && activeMediaGeneration != nil
            && activeMediaReadiness.contains(.input)
            && activeMacInputGeneration != nil
            && !isMacInputGenerationFailed
            && renderState.coordinateSnapshot != nil
        macInputSurfacePolicy = MacInputSurfacePolicy(
            admitsInput: admitsInput,
            cursorPolicy: CursorCapturePolicyResolver.resolve(
                isStreamActive: admitsInput,
                isVisible: admitsInput,
                isFocused: admitsInput,
                prefersRemotePointer: settings.input.preferRelativeMouseMode
            ),
            forwardsSystemShortcuts: settings.input.captureSystemShortcuts
        )
#if os(macOS)
        publishMacInputDiagnosticState()
#endif
    }

    private var expectedTVVisionPlatform: TVVisionPlatform? {
        configuredTVVisionPlatform
    }

    private var isTVRemoteInputReleasePending: Bool {
        tvRemoteInputReleasePending
            || tvRemoteSurfacePressCaptureOwner?.isReleasePending == true
    }

    private func applyTVRemoteCaptureEffect(
        _ effect: TVRemoteCaptureEffect
    ) async throws {
        switch effect {
        case let .closeRemoteAdmission(inputGeneration):
            try requireCurrentTVRemoteInputGeneration(inputGeneration)
            tvRemoteInputReleasePending = true

        case let .removeControllerHandlers(controllerLeases):
            if let inputGeneration = controllerLeases.first?.inputGeneration {
                guard controllerLeases.allSatisfy({
                    $0.platform == .tvOS
                        && $0.inputGeneration == inputGeneration
                }) else {
                    throw SessionMediaEnvironmentError.staleInputApplication
                }
                try requireCurrentTVRemoteInputGeneration(inputGeneration)
            } else {
                guard expectedTVVisionPlatform == .tvOS,
                      activeMediaGeneration != nil else {
                    throw SessionMediaEnvironmentError.staleInputApplication
                }
            }
            tvRemoteInputReleasePending = true
            await quiesceTVGameControllerRuntime()

        case let .awaitRemoteReleaseBarrier(inputGeneration):
            try requireCurrentTVRemoteInputGeneration(inputGeneration)
            try await releaseRemoteInput()

        case let .restoreLocalFocus(reason):
            let completedRelease = tvRemoteInputReleasePending
            if completedRelease, reason != .replacing {
                tvRemoteFocusHandoffState = tvRemoteFocusHandoffState
                    .settingOverlayVisible(
                        true,
                        currentGeometryStamp: currentTVVisionGeometryStamp
                    )
            }
            tvRemoteInputReleasePending = false

        case let .openRemoteAdmission(inputGeneration):
            try requireCurrentTVRemoteInputGeneration(inputGeneration)
            guard currentTVRemoteInputSnapshot?.focusEligibility == .eligible else {
                throw SessionMediaEnvironmentError.inputUnavailable
            }
            tvRemoteInputReleasePending = false
            try startTVGameControllerRuntime(inputGeneration: inputGeneration)

        case .sendRemote, .reserveLocally, .handleReserved, .ignoreUnownedPress:
            break
        }
    }

    private func requireCurrentTVRemoteInputGeneration(
        _ inputGeneration: TVVisionGeneration
    ) throws {
        guard expectedTVVisionPlatform == .tvOS,
              inputGeneration.domain == .input,
              activeMediaGeneration == inputGeneration.rawValue else {
            throw SessionMediaEnvironmentError.staleInputApplication
        }
    }

    private func quiesceTVGameControllerRuntime() async {
#if os(tvOS)
        tvGameControllerRuntimeOwner?.stop()
        tvGameControllerRuntimeOwner = nil
#endif
        tvControllerFeedbackDecisionState = nil
        tvPendingControllerMotionSamples.removeAll()
        let rosterApplicationTask = tvControllerRosterApplicationTask
        let routingTask = tvControllerRoutingTask
        let motionTask = tvControllerMotionDeliveryTask
        await rosterApplicationTask?.value
        await routingTask?.value
        await motionTask?.value
    }

    private func startTVGameControllerRuntime(
        inputGeneration: TVVisionGeneration
    ) throws {
#if os(tvOS)
        guard tvGameControllerRuntimeOwner == nil else { return }
        let controllerOwner = TVGameControllerRuntimeOwner()
        tvGameControllerRuntimeOwner = controllerOwner
        do {
            try controllerOwner.start(
                inputGeneration: inputGeneration,
                rosterHandler: { [weak self] roster in
                    self?.receiveTVGameControllerRoster(roster)
                },
                motionHandler: { [weak self] sample in
                    self?.receiveTVGameControllerMotion(sample)
                }
            )
        } catch {
            controllerOwner.stop()
            tvGameControllerRuntimeOwner = nil
            throw error
        }
#else
        _ = inputGeneration
#endif
    }

    private func releaseTVRemoteInputForTerminal() async {
        guard expectedTVVisionPlatform == .tvOS,
              let owner = tvRemoteSurfacePressCaptureOwner else { return }
        let leases: [TVVisionControllerLease]
        if let mediaGeneration = activeMediaGeneration,
           let inputGeneration = try? TVVisionGeneration(
            domain: .input,
            rawValue: mediaGeneration
           ) {
            leases = currentTVControllerLeases(
                inputGeneration: inputGeneration
            )
        } else {
            leases = []
        }
        await owner.releaseForTerminal(controllerLeases: leases)
        tvRemoteInputReleasePending = false
    }

    private func beginTVVisionPlatformPresentationRuntime() {
        clearTVVisionPlatformPresentationRuntime()
        guard expectedTVVisionPlatform == .tvOS else { return }
        tvRemoteReservedCommandState = .idle
        applyTVRemoteFocusHandoffState(
            tvRemoteFocusHandoffState.settingOverlayVisible(
                true,
                currentGeometryStamp: currentTVVisionGeometryStamp
            )
        )
        tvRemoteSurfacePressCaptureOwner = TVRemoteSurfacePressCaptureOwner(
            effectApplication: { [weak self] effect in
                guard let self else {
                    throw SessionMediaEnvironmentError.inactiveSession
                }
                try await self.applyTVRemoteCaptureEffect(effect)
            },
            delivery: { [weak self] inputGeneration, event in
                guard let self,
                      self.activeMediaGeneration == inputGeneration.rawValue,
                      self.activeMediaReadiness.contains(.input) else {
                    throw SessionMediaEnvironmentError.staleInputApplication
                }
                try await self.sendRemoteInput(.tvRemote(event))
            }
        )
    }

    private func scheduleTVVisionPlatformGeometryApplication(
        _ update: TVVisionStreamGeometryBindingUpdate,
        ownership: TVVisionPresentationOwnership
    ) {
        let previous = tvVisionPlatformApplicationTask
        let operationID = UUID()
        tvVisionPlatformApplicationOperationID = operationID
        tvVisionPlatformApplicationTask = Task { [weak self] in
            await previous?.value
            guard !Task.isCancelled,
                  let self,
                  self.tvVisionPlatformApplicationOperationID == operationID,
                  self.tvVisionPlatformGeometryAdmission
                    == TVVisionPlatformGeometryAdmission(
                        ownership: ownership,
                        update: update
                    ),
                  self.activeStreamSessionID == ownership.sessionID,
                  self.activeMediaSessionID == ownership.sessionID,
                  self.activeMediaGeneration == ownership.mediaGeneration else {
                return
            }
            do {
                if self.tvVisionPlatformPresentationOwnership != ownership {
                    self.tvVisionPlatformPresentationOwnership = ownership
                    try await self.sessionMediaEnvironment
                        .applyTVVisionPlatformPresentation(
                            SessionTVVisionPlatformPresentationApplication(
                                ownership: ownership,
                                action: .activate
                            )
                        )
                }
                guard !Task.isCancelled,
                      self.tvVisionPlatformApplicationOperationID
                        == operationID,
                      self.tvVisionPlatformPresentationOwnership
                        == ownership else { return }
                try await self.sessionMediaEnvironment
                    .applyTVVisionPlatformPresentation(
                        SessionTVVisionPlatformPresentationApplication(
                            ownership: ownership,
                            action: .scene(update)
                        )
                    )
                if ownership.platform == .tvOS,
                   let input = self.makeTVRemoteInputSnapshot(
                    update: update,
                    ownership: ownership
                   ) {
                    if update.binding != nil {
                        try await self.sessionMediaEnvironment
                            .applyTVVisionPlatformPresentation(
                                SessionTVVisionPlatformPresentationApplication(
                                    ownership: ownership,
                                    action: .input(
                                        snapshot: input,
                                        controllerLeases:
                                            self.currentTVControllerLeases(
                                                inputGeneration:
                                                    input.inputGeneration
                                            )
                                    )
                                )
                            )
                    }
                    guard !Task.isCancelled,
                          self.tvVisionPlatformApplicationOperationID
                            == operationID,
                          self.tvVisionPlatformPresentationOwnership
                            == ownership else { return }
                    try self.tvRemoteSurfacePressCaptureOwner?.update(
                        surfaceGeneration: update.surfaceGeneration,
                        input: input,
                        controllerLeases: self.currentTVControllerLeases(
                            inputGeneration: input.inputGeneration
                        )
                    )
                }
            } catch {
                guard !Task.isCancelled,
                      self.tvVisionPlatformApplicationOperationID
                        == operationID,
                      self.tvVisionPlatformPresentationOwnership
                        == ownership else { return }
                self.tvVisionPlatformPresentationOwnership = nil
                if let current = self.tvVisionPlatformPresentationState,
                   current.snapshot.ownership == ownership {
                    switch current.snapshot.phase {
                    case .failed, .stopped(.failure):
                        break
                    case .active, .stopped:
                        self.tvVisionPlatformPresentationState = nil
                    }
                } else {
                    self.tvVisionPlatformPresentationState = nil
                }
                await self.releaseTVRemoteInputForTerminal()
            }
            if self.tvVisionPlatformApplicationOperationID == operationID {
                self.tvVisionPlatformApplicationTask = nil
                self.tvVisionPlatformApplicationOperationID = nil
            }
        }
    }

    private func scheduleTVGameControllerRosterApplication(
        _ roster: TVControllerRosterSnapshot
    ) {
        guard !isTVRemoteInputReleasePending,
              let admission = tvVisionPlatformGeometryAdmission,
              admission.update.binding != nil,
              admission.ownership.platform == .tvOS,
              admission.ownership.inputGeneration == roster.inputGeneration,
              let input = makeTVRemoteInputSnapshot(
                update: admission.update,
                ownership: admission.ownership
              ) else { return }
        let expectedAdmission = admission
        let geometryTask = tvVisionPlatformApplicationTask
        let previous = tvControllerRosterApplicationTask
        let operationID = UUID()
        tvControllerRosterApplicationOperationID = operationID
        tvControllerRosterApplicationTask = Task { [weak self] in
            await previous?.value
            await geometryTask?.value
            guard !Task.isCancelled,
                  let self,
                  self.tvControllerRosterApplicationOperationID == operationID,
                  self.tvControllerRosterState == roster,
                  self.tvVisionPlatformGeometryAdmission == expectedAdmission,
                  self.tvVisionPlatformPresentationOwnership
                    == expectedAdmission.ownership,
                  self.activeMediaGeneration
                    == roster.inputGeneration.rawValue,
                  self.makeTVRemoteInputSnapshot(
                    update: expectedAdmission.update,
                    ownership: expectedAdmission.ownership
                  ) == input else { return }
            _ = try? await self.sessionMediaEnvironment
                .applyTVVisionPlatformPresentation(
                    SessionTVVisionPlatformPresentationApplication(
                        ownership: expectedAdmission.ownership,
                        action: .input(
                            snapshot: input,
                            controllerLeases: roster.controllers.map(\.lease)
                        )
                    )
                )
            if self.tvControllerRosterApplicationOperationID == operationID {
                self.tvControllerRosterApplicationTask = nil
                self.tvControllerRosterApplicationOperationID = nil
            }
        }
    }

    private func scheduleTVGameControllerRouting(
        _ roster: TVControllerRosterSnapshot
    ) {
        guard activeMediaGeneration == roster.inputGeneration.rawValue,
              !isTVRemoteInputReleasePending,
              currentTVRemoteInputSnapshot?.focusEligibility == .eligible,
              tvControllerRoutedRosterState != roster else { return }
        let previous = tvControllerRoutingTask
        let geometryTask = tvVisionPlatformApplicationTask
        let operationID = UUID()
        tvControllerRoutingOperationID = operationID
        tvControllerRoutingTask = Task { [weak self] in
            await previous?.value
            await geometryTask?.value
            guard !Task.isCancelled,
                  let self,
                  self.tvControllerRosterState == roster,
                  self.activeMediaGeneration == roster.inputGeneration.rawValue,
                  !self.isTVRemoteInputReleasePending,
                  self.currentTVRemoteInputSnapshot?.focusEligibility
                    == .eligible else { return }
            let event = TVGameControllerRosterRouter.reconcile(
                previous: self.tvControllerRoutedRosterState,
                current: roster
            )
            do {
                try await self.sendRemoteInput(.controllerRoster(event))
                guard self.activeMediaGeneration
                        == roster.inputGeneration.rawValue else { return }
                self.tvControllerRoutedRosterState = roster
            } catch {
                // The input provider owns delivery failure and session teardown.
            }
            if self.tvControllerRoutingOperationID == operationID {
                self.tvControllerRoutingTask = nil
                self.tvControllerRoutingOperationID = nil
            }
        }
    }

    private func startTVGameControllerMotionDrainIfNeeded() {
        guard tvControllerMotionDeliveryTask == nil else { return }
        tvControllerMotionDeliveryTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled,
                  let key = self.tvPendingControllerMotionSamples.keys
                    .sorted().first,
                  let sample = self.tvPendingControllerMotionSamples
                    .removeValue(forKey: key) {
                guard self.activeMediaGeneration
                        == sample.lease.inputGeneration.rawValue,
                      !self.isTVRemoteInputReleasePending,
                      self.tvControllerRosterState?.controllers.contains(where: {
                          $0.lease == sample.lease
                      }) == true,
                      self.currentTVRemoteInputSnapshot?.focusEligibility
                        == .eligible else { continue }
                do {
                    try await self.sendRemoteInput(sample.remoteEvent)
                } catch {
                    self.tvPendingControllerMotionSamples.removeAll()
                    break
                }
            }
            self.tvControllerMotionDeliveryTask = nil
            if !self.tvPendingControllerMotionSamples.isEmpty {
                self.startTVGameControllerMotionDrainIfNeeded()
            }
        }
    }

    private func applyTVVisionPlatformPresentationState(
        _ state: SessionTVVisionPlatformPresentationState,
        sessionID: UUID
    ) {
        let snapshot = state.snapshot
        guard state.sessionID == sessionID,
              state.mediaGeneration == snapshot.ownership.mediaGeneration,
              activeStreamSessionID == sessionID,
              activeMediaSessionID == sessionID,
              activeMediaGeneration == state.mediaGeneration,
              expectedTVVisionPlatform == snapshot.ownership.platform else {
            return
        }
        if let admission = tvVisionPlatformGeometryAdmission,
           admission.ownership.sessionID == sessionID,
           admission.ownership.mediaGeneration == state.mediaGeneration,
           snapshot.ownership.presentationGeneration
            < admission.ownership.presentationGeneration {
            return
        }
        if let ownership = tvVisionPlatformPresentationOwnership {
            guard ownership == snapshot.ownership else { return }
        } else {
            tvVisionPlatformPresentationOwnership = snapshot.ownership
        }
        if let current = tvVisionPlatformPresentationState,
           current.snapshot.ownership == snapshot.ownership {
            guard snapshot.sequence >= current.snapshot.sequence else { return }
            if state == current { return }
        }
        tvVisionPlatformPresentationState = state
    }

    private func stopTVVisionPlatformPresentation(
        reason: TVVisionPlatformPresentationStopReason
    ) async {
        await tvVisionPlatformApplicationTask?.value
        await releaseTVRemoteInputForTerminal()
        guard let ownership = tvVisionPlatformPresentationOwnership,
              activeMediaSessionID == ownership.sessionID,
              activeMediaGeneration == ownership.mediaGeneration else {
            clearTVVisionPlatformPresentationRuntime()
            return
        }
        _ = try? await sessionMediaEnvironment
            .applyTVVisionPlatformPresentation(
                SessionTVVisionPlatformPresentationApplication(
                    ownership: ownership,
                    action: .stop(reason)
                )
            )
        clearTVVisionPlatformPresentationRuntime()
    }

    private func clearTVVisionPlatformPresentationRuntime(
        preservingTerminalState: Bool = false
    ) {
        if expectedTVVisionPlatform == .tvOS {
            tvRemoteReservedCommandState = .idle
            tvRemoteFocusHandoffState = tvRemoteFocusHandoffState
                .settingOverlayVisible(
                    true,
                    currentGeometryStamp: currentTVVisionGeometryStamp
                )
        }
        tvVisionPlatformApplicationTask?.cancel()
        tvVisionPlatformApplicationTask = nil
        tvVisionPlatformApplicationOperationID = nil
        tvControllerRosterApplicationTask?.cancel()
        tvControllerRosterApplicationTask = nil
        tvControllerRosterApplicationOperationID = nil
        tvControllerRoutingTask?.cancel()
        tvControllerRoutingTask = nil
        tvControllerRoutingOperationID = nil
        tvControllerMotionDeliveryTask?.cancel()
        tvControllerMotionDeliveryTask = nil
        tvPendingControllerMotionSamples.removeAll()
        tvRemoteInputReleasePending = false
        tvVisionPlatformGeometryAdmission = nil
        tvRemoteSurfacePressCaptureOwner?.invalidate()
        tvRemoteSurfacePressCaptureOwner = nil
        tvControllerRosterState = nil
        tvControllerRoutedRosterState = nil
        tvControllerFeedbackDecisionState = nil
#if os(tvOS)
        tvGameControllerRuntimeOwner?.stop()
        tvGameControllerRuntimeOwner = nil
#endif
        tvVisionPlatformPresentationOwnership = nil
        guard preservingTerminalState,
              let phase = tvVisionPlatformPresentationState?.snapshot.phase else {
            tvVisionPlatformPresentationState = nil
            return
        }
        switch phase {
        case .failed, .stopped(.failure):
            break
        case .active, .stopped:
            tvVisionPlatformPresentationState = nil
        }
    }

    private func makeTVRemoteInputSnapshot(
        update: TVVisionStreamGeometryBindingUpdate,
        ownership: TVVisionPresentationOwnership
    ) -> TVVisionInputCapabilitySnapshot? {
        guard ownership.platform == .tvOS,
              ownership.inputGeneration.domain == .input else { return nil }
        let actualEligibility: TVVisionFocusEligibility
        if !activeMediaReadiness.contains(.input) {
            actualEligibility = .ineligible(.inputUnavailable)
        } else if let binding = update.binding {
            if binding.sceneSurfaceSnapshot.activity != .active {
                actualEligibility = .ineligible(.sceneInactive)
            } else if !binding.sceneSurfaceSnapshot.isVisible
                        || !binding.isFocusEligible {
                actualEligibility = .ineligible(.notFocused)
            } else {
                actualEligibility = .eligible
            }
        } else {
            actualEligibility = .ineligible(.detached)
        }
        return try? TVVisionInputCapabilitySnapshot(
            platform: .tvOS,
            revision: update.revision,
            inputGeneration: ownership.inputGeneration,
            supported: [.tvRemote, .extendedGamepad, .microGamepad],
            focusEligibility: tvRemoteFocusHandoffState.resolving(
                actualEligibility: actualEligibility
            )
        )
    }

    private func currentTVControllerLeases(
        inputGeneration: TVVisionGeneration
    ) -> [TVVisionControllerLease] {
        guard let roster = tvControllerRosterState,
              roster.inputGeneration == inputGeneration else { return [] }
        return roster.controllers.map(\.lease)
    }

    private var currentTVRemoteInputSnapshot:
        TVVisionInputCapabilitySnapshot? {
        guard let admission = tvVisionPlatformGeometryAdmission else {
            return nil
        }
        return makeTVRemoteInputSnapshot(
            update: admission.update,
            ownership: admission.ownership
        )
    }

    private func applyTVGameControllerFeedback(
        _ feedback: RemoteInputFeedback
    ) {
        guard expectedTVVisionPlatform == .tvOS,
              !isTVRemoteInputReleasePending,
              let roster = tvControllerRosterState,
              currentTVRemoteInputSnapshot?.focusEligibility == .eligible else {
            tvControllerFeedbackDecisionState = nil
            return
        }
        let remoteControllerID: String
        let payload: TVControllerFeedbackPayload
        switch feedback {
        case let .rumble(value):
            remoteControllerID = value.controllerID
            payload = .rumble(
                lowFrequency: value.lowFrequency,
                highFrequency: value.highFrequency
            )
        case let .triggerRumble(value):
            remoteControllerID = value.controllerID
            payload = .triggerRumble(
                leftMotor: value.leftMotor,
                rightMotor: value.rightMotor
            )
        case let .led(value):
            remoteControllerID = value.controllerID
            payload = .led(red: value.red, green: value.green, blue: value.blue)
        case let .motionRate(controllerID, type, reportRateHz):
            remoteControllerID = controllerID
            payload = .motionRate(type: type, reportRateHz: reportRateHz)
        case .diagnostic:
            return
        }
        guard let lease = TVGameControllerRosterRouter.lease(
            matching: remoteControllerID,
            in: roster
        ),
        let request = try? TVControllerFeedbackRequest(
            lease: lease,
            payload: payload
        ) else {
            tvControllerFeedbackDecisionState = .unavailable(
                .controllerUnavailable
            )
            return
        }
        let decision = TVControllerFeedbackResolver.resolve(
            request,
            roster: roster
        )
        tvControllerFeedbackDecisionState = decision
#if os(tvOS)
        if case .apply = decision {
            tvControllerFeedbackDecisionState = tvGameControllerRuntimeOwner?
                .applyFeedback(request) ?? .unavailable(.controllerUnavailable)
        }
#endif
    }

    private var currentTVVisionGeometryStamp: TVRemoteSurfaceFocusStamp? {
        guard let update = tvVisionPlatformGeometryAdmission?.update else {
            return nil
        }
        return try? TVRemoteSurfaceFocusStamp(
            surfaceGeneration: update.surfaceGeneration,
            revision: update.revision
        )
    }

    private func updateTVRemoteNavigationSelection() {
        guard expectedTVVisionPlatform == .tvOS else { return }
        applyTVRemoteFocusHandoffState(
            tvRemoteFocusHandoffState.selectingStreamNavigation(
                navigationSelection == .stream,
                currentGeometryStamp: currentTVVisionGeometryStamp
            )
        )
    }

    private func applyTVRemoteFocusHandoffState(
        _ nextState: TVRemoteFocusHandoffState
    ) {
        guard nextState != tvRemoteFocusHandoffState else { return }
        tvRemoteFocusHandoffState = nextState
        refreshTVRemoteSurfacePressOwnership()
    }

    private func refreshTVRemoteSurfacePressOwnership() {
        guard expectedTVVisionPlatform == .tvOS,
              let admission = tvVisionPlatformGeometryAdmission,
              admission.ownership == tvVisionPlatformPresentationOwnership,
              let input = makeTVRemoteInputSnapshot(
                update: admission.update,
                ownership: admission.ownership
              ) else { return }
        do {
            try tvRemoteSurfacePressCaptureOwner?.update(
                surfaceGeneration: admission.update.surfaceGeneration,
                input: input,
                controllerLeases: currentTVControllerLeases(
                    inputGeneration: input.inputGeneration
                )
            )
        } catch {
            tvRemoteSurfacePressCaptureOwner?
                .failClosedForContractViolation()
        }
    }

    private func closeTVRemoteSurfaceAdmissionIfNeeded(
        previousAdmission: TVVisionPlatformGeometryAdmission?,
        update: TVVisionStreamGeometryBindingUpdate,
        ownership: TVVisionPresentationOwnership
    ) {
        guard expectedTVVisionPlatform == .tvOS,
              let owner = tvRemoteSurfacePressCaptureOwner else { return }
        let input: TVVisionInputCapabilitySnapshot?
        if let previousAdmission,
           previousAdmission.update.surfaceGeneration
            != update.surfaceGeneration {
            input = try? TVVisionInputCapabilitySnapshot(
                platform: .tvOS,
                revision: update.revision,
                inputGeneration: ownership.inputGeneration,
                supported: [.tvRemote, .extendedGamepad, .microGamepad],
                focusEligibility: .ineligible(.replacing)
            )
        } else {
            let candidate = makeTVRemoteInputSnapshot(
                update: update,
                ownership: ownership
            )
            input = candidate?.focusEligibility == .eligible ? nil : candidate
        }
        guard let input else { return }
        do {
            try owner.update(
                surfaceGeneration: update.surfaceGeneration,
                input: input,
                controllerLeases: currentTVControllerLeases(
                    inputGeneration: input.inputGeneration
                )
            )
        } catch {
            owner.failClosedForContractViolation()
        }
    }

    private func actualTVRemoteSurfaceFocusEligibility(
        _ update: TVVisionStreamGeometryBindingUpdate
    ) -> TVVisionFocusEligibility {
        guard let binding = update.binding else {
            return .ineligible(.detached)
        }
        guard binding.sceneSurfaceSnapshot.activity == .active else {
            return .ineligible(.sceneInactive)
        }
        guard binding.sceneSurfaceSnapshot.isVisible,
              binding.isFocusEligible else {
            return .ineligible(.notFocused)
        }
        return .eligible
    }

    private func tvVisionPlatformStopReason(
        for inputReason: MacSessionInputTerminationReason
    ) -> TVVisionPlatformPresentationStopReason {
        switch inputReason {
        case .replacement:
            .reconnect
        case .remoteTermination:
            .remoteTermination
        case .sendFailure, .inputChannelFailure:
            .failure
        case .stop, .detached:
            .localStop
        }
    }

    private func applyMobileRuntimeState(
        _ state: SessionMobileRuntimeState,
        sessionID: UUID
    ) {
        let application = state.application
        guard !isMobileRuntimeRevisionExhausted,
              activeStreamSessionID == sessionID,
              activeMediaSessionID == sessionID,
              application.sessionID == sessionID,
              application.mediaGeneration == activeMediaGeneration else {
            return
        }
        if let current = mobileRuntimeState {
            guard application.revision.rawValue
                    > current.application.revision.rawValue else {
                return
            }
        }
        if let latest = latestMobileRuntimeApplication,
           application.revision.rawValue < latest.revision.rawValue {
            return
        }
        mobileRuntimeState = state
        mobileSceneWindowSnapshot = application.sceneWindow
        mobileDisplayEDRSnapshot = application.displayEDR
        mobilePictureInPictureSnapshot = application.pictureInPicture
        mobileAudioSessionActive = application.isAudioSessionActive

        switch state.media.plan.foreground {
        case let .baseline(policy), let .restoreAndResample(policy):
            renderState.policy = policy
        case let .suspended(reason):
            renderState.policy = .paused(reason: reason.rawValue)
        case .idle:
            renderState.policy = .idle
        }

        let diagnosticState: MobileContinuityDiagnosticState
        switch state.media.plan.stream {
        case .stopped:
            diagnosticState = .stopped
            if session.isStreaming {
                session.phase = .stopping
            }
        case let .paused(reason):
            diagnosticState = .suspended
            if session.isStreaming {
                session.phase = .suspending(reason: reason.rawValue)
            }
        case .running:
            if session.isStreaming {
                session.phase = .streaming
            }
            switch state.continuityPath {
            case .foreground:
                diagnosticState = .foreground
            case .pictureInPicture:
                diagnosticState = .pictureInPicture
            case .audioOnly:
                diagnosticState = .audioOnly
            case .inactive:
                diagnosticState = .stopped
            case .unavailable:
                diagnosticState = .suspended
            }
        }
        publishMobileDiagnostic(
            domain: "continuity",
            ApplicationDiagnosticFactory.mobileContinuityState(
                diagnosticState
            )
        )
    }

    private func clearMobileRuntime() {
        mobileRuntimeApplicationTask?.cancel()
        mobileRuntimeApplicationTask = nil
        mobileRuntimeApplicationOperationID = nil
        latestMobileRuntimeApplication = nil
        appliedMobileRuntimeRevision = 0
        failedMobileRuntimeRevision = 0
        mobileRuntimeRevision = 0
        isMobileRuntimeRevisionExhausted = false
#if os(iOS)
        invalidateMobilePictureInPicture(queueUpdate: false)
#endif
        mobileRuntimeState = nil
        mobileSceneWindowSnapshot = nil
        mobileDisplayEDRSnapshot = nil
        mobilePictureInPictureSnapshot = nil
        mobileAudioSessionActive = nil
        mobileSurfaceGeneration = nil
        mobileSceneActivity = .inactive
        mobilePictureInPictureGenerationOrdinal = 0
        highestMobilePictureInPictureDecoderGeneration = 0
        isMobilePictureInPictureGenerationExhausted = false
        lastMobileDiagnosticCodes.removeAll(keepingCapacity: false)
    }

    private func publishMobileDiagnostic(
        domain: String,
        _ diagnostic: ApplicationDiagnostic
    ) {
        guard lastMobileDiagnosticCodes[domain] != diagnostic.code else {
            return
        }
        lastMobileDiagnosticCodes[domain] = diagnostic.code
        diagnostics.record(diagnostic)
    }

#if os(iOS)
    private func beginMobileRuntime(mediaGeneration: UInt64) {
        mobileRuntimeState = nil
        mobileSceneWindowSnapshot = nil
        mobileDisplayEDRSnapshot = nil
        mobilePictureInPictureSnapshot = nil
        mobileAudioSessionActive = nil
        mobileSurfaceGeneration = nil
        mobileSceneActivity = .inactive
        mobileRuntimeRevision = 0
        appliedMobileRuntimeRevision = 0
        failedMobileRuntimeRevision = 0
        isMobileRuntimeRevisionExhausted = false
        latestMobileRuntimeApplication = nil
        mobilePictureInPictureGenerationOrdinal = mediaGeneration > 0 ? 1 : 0
        highestMobilePictureInPictureDecoderGeneration = 0
        isMobilePictureInPictureGenerationExhausted = false
        lastMobileDiagnosticCodes.removeAll(keepingCapacity: false)
        queueMobileRuntimeApplication()
    }

    private func acceptMobileSurfaceGeneration(
        _ generation: MobileSceneSurfaceGeneration
    ) -> Bool {
        guard let current = mobileSurfaceGeneration else {
            mobileSurfaceGeneration = generation
            return true
        }
        if generation == current { return true }
        guard generation.rawValue > current.rawValue else { return false }
        mobileSurfaceGeneration = generation
        mobileSceneWindowSnapshot = nil
        mobileDisplayEDRSnapshot = nil
        return true
    }

    private func queueMobileRuntimeApplication() {
        guard !isMobileRuntimeRevisionExhausted else { return }
        guard let sessionID = activeStreamSessionID,
              activeMediaSessionID == sessionID,
              let mediaGeneration = activeMediaGeneration,
              mobilePictureInPictureGenerationOrdinal > 0,
              let generation = MobilePictureInPictureGeneration(
                mediaGeneration: mediaGeneration,
                pictureInPictureGeneration:
                    mobilePictureInPictureGenerationOrdinal
              ) else {
            return
        }
        let nextRevision = mobileRuntimeRevision.addingReportingOverflow(1)
        guard !nextRevision.overflow,
              let revision = SessionMobileRuntimeRevision(
                rawValue: nextRevision.partialValue
              ) else {
            handleMobileRuntimeRevisionExhaustion(sessionID: sessionID)
            return
        }
        mobileRuntimeRevision = nextRevision.partialValue
        let sceneWindow = mobileSceneWindowSnapshot.flatMap {
            $0.surfaceGeneration == mobileSurfaceGeneration ? $0 : nil
        }
        let displayEDR = mobileDisplayEDRSnapshot.flatMap {
            $0.surfaceGeneration == mobileSurfaceGeneration ? $0 : nil
        }
        let pictureInPicture = mobilePictureInPictureSnapshot.flatMap {
            $0.generation == generation ? $0 : nil
        }
        let runtime = audioRuntimeState?.runtime
        latestMobileRuntimeApplication = SessionMobileRuntimeApplication(
            sessionID: sessionID,
            mediaGeneration: mediaGeneration,
            revision: revision,
            generation: generation,
            platform: UIDevice.current.userInterfaceIdiom == .pad
                ? .iPadOS
                : .iOS,
            sceneActivity: mobileSceneActivity,
            surfaceGeneration: mobileSurfaceGeneration,
            sceneWindow: sceneWindow,
            displayEDR: displayEDR,
            pictureInPicture: pictureInPicture,
            isAudioSessionActive: runtime?.mobileAudioSessionActive,
            isAudioContinuityPermitted:
                runtime?.mobileAudioSessionActive == true
                    && runtime?.stage == .running,
            preferences: settings.continuity,
            capabilities: mobileContinuityCapabilities,
            foregroundBaseline: hasPlatformLifecycle
                ? latestLifecycleDirective.renderPolicy
                : .active
        )
        scheduleMobileRuntimeApplication()
    }

    private func handleMobileRuntimeRevisionExhaustion(sessionID: UUID) {
        guard !isMobileRuntimeRevisionExhausted else { return }
        isMobileRuntimeRevisionExhausted = true
        mobileRuntimeApplicationTask?.cancel()
        mobileRuntimeApplicationTask = nil
        mobileRuntimeApplicationOperationID = nil
        latestMobileRuntimeApplication = nil
        mobileRuntimeState = nil
        mobileSceneWindowSnapshot = nil
        mobileDisplayEDRSnapshot = nil
        mobilePictureInPictureSnapshot = nil
        mobileAudioSessionActive = nil
        mobileSurfaceGeneration = nil
        mobileSceneActivity = .inactive
        invalidateMobilePictureInPicture(queueUpdate: false)
        renderState.policy = .paused(reason: "mobile-runtime-revision-exhausted")
        publishMobileDiagnostic(
            domain: "continuity",
            ApplicationDiagnosticFactory.mobileContinuityState(
                .revisionExhausted
            )
        )
        Task { [weak self] in
            guard let self,
                  self.activeStreamSessionID == sessionID else { return }
            await self.stopStream()
        }
    }

    private var mobileContinuityCapabilities:
        PlatformContinuityCapabilities
    {
        let declaredModes = Bundle.main.object(
            forInfoDictionaryKey: "UIBackgroundModes"
        ) as? [String]
        return PlatformContinuityCapabilities(
            supportsAudioBackgroundMode: true,
            supportsPictureInPicture:
                AVPictureInPictureController
                    .isPictureInPictureSupported(),
            hasAudioBackgroundModeDeclared:
                declaredModes?.contains("audio") == true
        )
    }

    private func scheduleMobileRuntimeApplication() {
        guard mobileRuntimeApplicationTask == nil else { return }
        let operationID = UUID()
        mobileRuntimeApplicationOperationID = operationID
        mobileRuntimeApplicationTask = Task { [weak self] in
            guard let self else { return }
            await self.drainMobileRuntimeApplications(
                operationID: operationID
            )
        }
    }

    private func drainMobileRuntimeApplications(operationID: UUID) async {
        while !Task.isCancelled,
              mobileRuntimeApplicationOperationID == operationID,
              let application = latestMobileRuntimeApplication,
              application.revision.rawValue
                > max(
                    appliedMobileRuntimeRevision,
                    failedMobileRuntimeRevision
                ) {
            do {
                try await sessionMediaEnvironment.applyMobileRuntime(
                    application
                )
            } catch {
                guard !Task.isCancelled,
                      mobileRuntimeApplicationOperationID == operationID,
                      activeStreamSessionID == application.sessionID,
                      activeMediaSessionID == application.sessionID,
                      activeMediaGeneration == application.mediaGeneration else {
                    break
                }
                if error as? SessionMediaEnvironmentError
                    == .staleMobileRuntimeApplication,
                   (latestMobileRuntimeApplication?.revision.rawValue ?? 0)
                    > application.revision.rawValue {
                    continue
                }
                publishMobileDiagnostic(
                    domain: "continuity",
                    ApplicationDiagnosticFactory.mobileContinuityState(
                        .applicationFailed
                    )
                )
                renderState.policy = .paused(
                    reason: "mobile-runtime-application-failed"
                )
                if session.isStreaming {
                    session.phase = .suspending(
                        reason: "mobile-runtime-application-failed"
                    )
                }
                failedMobileRuntimeRevision = max(
                    failedMobileRuntimeRevision,
                    application.revision.rawValue
                )
                break
            }
            guard !Task.isCancelled,
                  mobileRuntimeApplicationOperationID == operationID,
                  activeStreamSessionID == application.sessionID,
                  activeMediaSessionID == application.sessionID,
                  activeMediaGeneration == application.mediaGeneration else {
                break
            }
            appliedMobileRuntimeRevision = application.revision.rawValue
        }
        guard mobileRuntimeApplicationOperationID == operationID else { return }
        mobileRuntimeApplicationTask = nil
        mobileRuntimeApplicationOperationID = nil
        if let application = latestMobileRuntimeApplication,
           application.revision.rawValue
            > max(appliedMobileRuntimeRevision, failedMobileRuntimeRevision) {
            scheduleMobileRuntimeApplication()
        }
    }

    private func refreshMobilePictureInPictureConfiguration() {
        guard settings.continuity.pictureInPictureEnabled,
              let decoderGeneration = activeVideoDecoderGeneration else {
            invalidateMobilePictureInPicture()
            return
        }
        prepareMobilePictureInPicture(
            decoderGeneration: decoderGeneration
        )
    }

    private func prepareMobilePictureInPicture(
        decoderGeneration: UInt64
    ) {
        guard !isMobilePictureInPictureGenerationExhausted,
              settings.continuity.pictureInPictureEnabled,
              let sessionID = activeStreamSessionID,
              activeMediaSessionID == sessionID,
              let mediaGeneration = activeMediaGeneration,
              decoderGeneration > 0 else {
            return
        }
        if mobilePictureInPictureCoordinator?.decoderGeneration
            == decoderGeneration {
            return
        }
        invalidateMobilePictureInPicture(queueUpdate: false)
        if highestMobilePictureInPictureDecoderGeneration > 0 {
            let next = mobilePictureInPictureGenerationOrdinal
                .addingReportingOverflow(1)
            guard !next.overflow else {
                isMobilePictureInPictureGenerationExhausted = true
                publishMobileDiagnostic(
                    domain: "pip",
                    ApplicationDiagnosticFactory
                        .mobilePictureInPictureState(.failed)
                )
                queueMobileRuntimeApplication()
                return
            }
            mobilePictureInPictureGenerationOrdinal = next.partialValue
        }
        highestMobilePictureInPictureDecoderGeneration = max(
            highestMobilePictureInPictureDecoderGeneration,
            decoderGeneration
        )
        guard let generation = MobilePictureInPictureGeneration(
            mediaGeneration: mediaGeneration,
            pictureInPictureGeneration:
                mobilePictureInPictureGenerationOrdinal
        ) else { return }

        do {
            let displayClient = MobilePictureInPictureDisplayLayerClient()
            let frameSink = try MobilePictureInPictureDisplayLayerSink(
                generation: generation,
                decoderGeneration: decoderGeneration,
                client: displayClient
            )
            let controller = MobilePictureInPictureAVKitControllerClient(
                generation: generation,
                displayLayer: displayClient.displayLayer
            )
            let coordinator = try MobilePictureInPicturePresentationCoordinator(
                sessionID: sessionID,
                generation: generation,
                decoderGeneration: decoderGeneration,
                source: videoPresentationSource,
                client: controller,
                frameSink: frameSink,
                foregroundBaseline: hasPlatformLifecycle
                    ? latestLifecycleDirective.renderPolicy
                    : .active
            )
            coordinator.setLifecycleEventHandler { [weak self, weak coordinator]
                event in
                guard let self, let coordinator else { return }
                self.consumeMobilePictureInPictureEvent(
                    event,
                    coordinator: coordinator
                )
            }
            if let playback = MobilePictureInPicturePlaybackState(
                timeline: .live,
                isPaused: false,
                backgroundAudioPolicy:
                    settings.continuity.audioContinuityEnabled
                        ? .permitted
                        : .prohibited
            ) {
                _ = coordinator.updatePlaybackState(playback)
            }
            mobilePictureInPictureCoordinator = coordinator
            _ = coordinator.prepare()
        } catch {
            publishMobileDiagnostic(
                domain: "pip",
                ApplicationDiagnosticFactory
                    .mobilePictureInPictureState(.failed)
            )
            mobilePictureInPictureSnapshot = nil
            queueMobileRuntimeApplication()
        }
    }

    private func consumeMobilePictureInPictureEvent(
        _ event: MobilePictureInPictureLifecycleCoordinatorEvent,
        coordinator: MobilePictureInPicturePresentationCoordinator
    ) {
        guard mobilePictureInPictureCoordinator === coordinator else {
            publishMobileDiagnostic(
                domain: "continuity",
                ApplicationDiagnosticFactory.mobileContinuityState(.stale)
            )
            return
        }
        switch event {
        case let .snapshot(snapshot):
            guard snapshot.generation.mediaGeneration
                    == activeMediaGeneration else { return }
            if let current = mobilePictureInPictureSnapshot,
               current.generation == snapshot.generation,
               snapshot.revision.rawValue <= current.revision.rawValue {
                return
            }
            mobilePictureInPictureSnapshot = snapshot
            publishMobilePictureInPictureDiagnostic(
                snapshot.state.lifecycle
            )
            queueMobileRuntimeApplication()
        case let .restoreInterfaceRequested(lease):
            _ = coordinator.completeRestoration(
                lease,
                result: .declined
            )
        case let .skipRequested(_, completion):
            _ = coordinator.completeSkip(completion)
        case .revisionExhausted:
            publishMobileDiagnostic(
                domain: "pip",
                ApplicationDiagnosticFactory
                    .mobilePictureInPictureState(.failed)
            )
            invalidateMobilePictureInPicture()
        case .setPlayingRequested, .renderSizeChanged, .rejected:
            break
        }
    }

    private func invalidateMobilePictureInPicture(
        queueUpdate: Bool = true
    ) {
        guard let coordinator = mobilePictureInPictureCoordinator else {
            mobilePictureInPictureSnapshot = nil
            return
        }
        mobilePictureInPictureCoordinator = nil
        coordinator.setLifecycleEventHandler(nil)
        _ = coordinator.invalidate()
        mobilePictureInPictureSnapshot = nil
        if queueUpdate {
            queueMobileRuntimeApplication()
        }
    }

    private func publishMobileSceneActivityDiagnostic(
        _ activity: AppSceneActivity
    ) {
        let state: MobileSceneDiagnosticState
        switch activity {
        case .active: state = .active
        case .inactive: state = .inactive
        case .background: state = .background
        }
        publishMobileDiagnostic(
            domain: "scene",
            ApplicationDiagnosticFactory.mobileSceneState(state)
        )
    }

    private func publishMobileDisplayDiagnostic(
        _ state: MobileDisplayEDRState
    ) {
        let diagnosticState: MobileDisplayDiagnosticState
        switch state {
        case .detached:
            diagnosticState = .detached
        case let .available(available):
            diagnosticState = available.capability == .edrCapable
                ? .edr
                : .sdr
        case .sdrFallback:
            diagnosticState = .fallback
        case .unknown, .unavailable:
            diagnosticState = .unavailable
        }
        publishMobileDiagnostic(
            domain: "display",
            ApplicationDiagnosticFactory.mobileDisplayState(
                diagnosticState
            )
        )
    }

    private func publishMobilePictureInPictureDiagnostic(
        _ lifecycle: MobilePictureInPictureLifecycle
    ) {
        let state: MobilePictureInPictureDiagnosticState
        switch lifecycle {
        case .unprepared, .preparing:
            state = .preparing
        case .ready:
            state = .possible
        case .unavailable:
            state = .unavailable
        case .startRequested, .starting:
            state = .starting
        case .active:
            state = .active
        case .stopRequested, .stopping:
            state = .stopping
        case .stopped:
            state = .stopped
        case .failed:
            state = .failed
        case .invalidated:
            state = .invalidated
        }
        publishMobileDiagnostic(
            domain: "pip",
            ApplicationDiagnosticFactory
                .mobilePictureInPictureState(state)
        )
    }
#endif

    private func clearStreamActionPresentation() {
        diagnostics.clearStreamActionableEvents()
        streamLaunchUI.errorMessage = nil
        streamLaunchUI.actionMessage = nil
    }

#if os(macOS)
    private func publishMacLifecycleDiagnostic(
        for directive: SessionLifecycleDirective
    ) {
        let state: MacLifecycleDiagnosticState
        switch directive.presentation {
        case .active:
            state = .active
        case .throttled:
            state = .unfocused
        case let .clear(reason):
            switch reason {
            case .streamInactive:
                state = .inactive
            case .notVisible:
                state = .occluded
            case .drawableUnavailable:
                state = .drawableUnavailable
            case .notFocused:
                state = .unfocused
            }
        }
        guard lastMacLifecycleDiagnosticState != state else { return }
        lastMacLifecycleDiagnosticState = state
        diagnostics.record(ApplicationDiagnosticFactory.macLifecycleState(state))
    }

    private func publishMacInputDiagnosticState() {
        let state: MacInputDiagnosticState
        if activeStreamSessionID == nil
            || activeMediaSessionID != activeStreamSessionID
            || activeMediaGeneration == nil
            || !activeMediaReadiness.contains(.input)
            || activeMacInputGeneration == nil
            || isMacInputGenerationFailed {
            state = .unavailable
        } else if !macInputSurfacePolicy.admitsInput {
            state = .closed
        } else if macInputSurfacePolicy.cursorPolicy.capturesRelativePointer {
            state = .relativeReady
        } else {
            state = .directReady
        }
        guard lastMacInputDiagnosticState != state else { return }
        lastMacInputDiagnosticState = state
        diagnostics.record(ApplicationDiagnosticFactory.macInputState(state))
    }
#endif

    private func updateRenderPreferences() {
        renderState.transform.sourceSize = activeDecodedSourceSize ?? PixelSize(
            width: settings.stream.width,
            height: settings.stream.height
        )
        renderState.transform.mode = settings.stream.scaleMode
    }

    private func beginVideoPresentation(
        negotiatedColorMetadata: VideoColorMetadata
    ) {
        activeVideoPresentationRevision = 0
        activeVideoDecoderGeneration = nil
        highestVideoDecoderGeneration = 0
        renderState.negotiatedVideoColorMetadata = negotiatedColorMetadata
        renderState.decodedVideoPresentationContract = nil
        refreshHDRRenderResolution()
    }

    private func updateNegotiatedVideoColorMetadata(
        _ metadata: VideoColorMetadata
    ) {
        renderState.negotiatedVideoColorMetadata = metadata
        activeVideoDecoderGeneration = nil
        renderState.decodedVideoPresentationContract = nil
        refreshHDRRenderResolution()
    }

    private func applyVideoPresentationEvent(
        _ event: StreamVideoPresentationEvent,
        sessionID: UUID
    ) {
        let ownership = event.ownership
        guard activeStreamSessionID == sessionID,
              activeMediaSessionID == sessionID,
              ownership.sessionID == sessionID,
              ownership.mediaGeneration == activeMediaGeneration,
              ownership.revision > activeVideoPresentationRevision else {
            return
        }

        switch event {
        case let .decoderStarted(_, contract):
            guard contract.decoderGeneration > highestVideoDecoderGeneration else {
                return
            }
            activeVideoPresentationRevision = ownership.revision
            activeVideoDecoderGeneration = contract.decoderGeneration
            highestVideoDecoderGeneration = contract.decoderGeneration
            renderState.decodedVideoPresentationContract = nil
#if os(iOS)
            prepareMobilePictureInPicture(
                decoderGeneration: contract.decoderGeneration
            )
#endif

        case let .decodedFrame(_, contract):
            guard contract.decoderGeneration >= highestVideoDecoderGeneration else {
                return
            }
            if contract.decoderGeneration > highestVideoDecoderGeneration {
                activeVideoDecoderGeneration = contract.decoderGeneration
                highestVideoDecoderGeneration = contract.decoderGeneration
#if os(iOS)
                prepareMobilePictureInPicture(
                    decoderGeneration: contract.decoderGeneration
                )
#endif
            }
            guard contract.decoderGeneration == activeVideoDecoderGeneration else {
                return
            }
            activeVideoPresentationRevision = ownership.revision
            renderState.decodedVideoPresentationContract = contract
            activeDecodedSourceSize = PixelSize(
                width: contract.decodedLayout.width,
                height: contract.decodedLayout.height
            )
            renderState.transform.sourceSize = activeDecodedSourceSize ?? .zero

        case let .cleared(_, decoderGeneration):
            if let decoderGeneration {
                guard decoderGeneration == activeVideoDecoderGeneration else {
                    return
                }
            }
            activeVideoPresentationRevision = ownership.revision
            activeVideoDecoderGeneration = nil
            renderState.decodedVideoPresentationContract = nil
#if os(iOS)
            invalidateMobilePictureInPicture()
#endif
        }
        refreshHDRRenderResolution()
    }

    private func clearActiveVideoPresentation() {
        activeVideoPresentationRevision = 0
        activeVideoDecoderGeneration = nil
        highestVideoDecoderGeneration = 0
        renderState.negotiatedVideoColorMetadata = nil
        renderState.decodedVideoPresentationContract = nil
        renderState.hdrRenderResolution = .closed(.inactiveSession)
        publishHDRPresentationDiagnostic(.inactive)
    }

    private func refreshHDRRenderResolution() {
        guard session.isStreaming,
              activeStreamSessionID != nil,
              activeMediaSessionID == activeStreamSessionID,
              activeMediaGeneration != nil,
              activeMediaReadiness.contains(.video),
              let decoded = renderState.decodedVideoPresentationContract else {
            applyHDRRenderResolution(.closed(.inactiveSession))
            return
        }
        guard let activeVideoDecoderGeneration else {
            applyHDRRenderResolution(.closed(.inactiveSession))
            return
        }
        guard decoded.decoderGeneration == activeVideoDecoderGeneration else {
            applyHDRRenderResolution(.closed(.staleDecoderGeneration(
                expected: activeVideoDecoderGeneration,
                actual: decoded.decoderGeneration
            )))
            return
        }
        let drawableSize = renderState.coordinateSnapshot?.drawableSize
        let drawableAvailable = drawableSize.map {
            $0.width > 0 && $0.height > 0
        } ?? false
        applyHDRRenderResolution(StreamHDRRenderResolutionResolver.resolve(
            StreamHDRRenderResolutionResolverInput(
                decodedPresentationContract: decoded,
                negotiatedVideoColorMetadata:
                    renderState.negotiatedVideoColorMetadata,
                userAllowsHDR: settings.stream.hdrEnabled,
                platformCapabilities:
                    HDRPlatformOutputCapabilityAdapter.current.capabilities,
                displaySnapshot: renderState.displaySnapshot,
                isDisplayRevisionExhausted:
                    renderState.isDisplayRevisionExhausted,
                drawableState: HDRDrawableState(
                    isAvailable: drawableAvailable,
                    appliedSurfaceContract: nil
                )
            )
        ))
    }

    private func applyHDRRenderResolution(
        _ resolution: HDRRenderConfigurationResolution
    ) {
        renderState.hdrRenderResolution = resolution
        guard case let .closed(error) = resolution else { return }
        publishHDRPresentationDiagnostic(.closed(error))
    }
}
