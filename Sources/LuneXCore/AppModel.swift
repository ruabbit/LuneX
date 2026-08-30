import Foundation
import Observation
import OSLog
#if os(iOS)
import AVKit
import UIKit
#endif

enum AppNavigationSelection: Hashable, Sendable {
    case library
    case stream
    case diagnostics
    case settings
}

private enum PairingApplicationError: Error {
    case incompleteRuntimeStream
    case invalidAuthenticatedCompletion
}

enum SessionApplicationError: Error {
    case incompleteControlStream
    case staleProductSessionOwner
}

struct StreamLaunchUIState: Equatable {
    var isLaunching = false
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
    let realtimeSources: RuntimeProviderRealtimeSources

    init(
        pairing: (any PairingRuntimeProvider)? = nil,
        sessionControl: (any SessionControlProvider)? = nil,
        videoReceive: (any VideoReceiveProvider)? = nil,
        audioReceive: (any AudioReceiveProvider)? = nil,
        remoteInput: (any RemoteInputProvider)? = nil,
        realtimeSources: RuntimeProviderRealtimeSources = .unavailable
    ) {
        self.pairing = pairing
        self.sessionControl = sessionControl
        self.videoReceive = videoReceive
        self.audioReceive = audioReceive
        self.remoteInput = remoteInput
        self.realtimeSources = realtimeSources
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

struct RuntimeProviderRealtimeSources: Sendable {
    var videoReceive: (@Sendable () async -> MoonlightMediaReceiveSnapshot?)?
    var audioReceive: (@Sendable () async -> MoonlightMediaReceiveSnapshot?)?
    var remoteInput: (@Sendable () async -> RemoteInputRuntimeSnapshot?)?
    var controlTransport: (@Sendable () async -> ENetConnectionDriverSnapshot?)?

    static let unavailable = RuntimeProviderRealtimeSources()
}

struct ApplicationStreamRealtimeSnapshot: Equatable, Sendable {
    var input: MacSessionInputCoordinatorSnapshot
    var remoteInput: RemoteInputRuntimeSnapshot?
    var controlTransport: ENetConnectionDriverSnapshot?
    var videoReceive: MoonlightMediaReceiveSnapshot?
    var audioReceive: MoonlightMediaReceiveSnapshot?
    var videoDecode: VideoDecodePipelineSnapshot?
    var videoPresentation: StreamVideoPresentationSnapshot
}

enum ProductionRuntimeProviderFactory {
    static func makeDefault() -> RuntimeProviderInventory {
        let controlDriver = ENetConnectionDriver()
        let controlChannel = MoonlightControlChannel(driver: controlDriver)
        let audioDatagramReservations = MoonlightAudioDatagramReservationStore()
        let videoReceive = MoonlightVideoReceiveProvider()
        let audioReceive = MoonlightAudioReceiveProvider(
            reservationStore: audioDatagramReservations
        )
        let remoteInput = MoonlightRemoteInputProvider(
            sender: controlChannel,
            feedbackSource: controlChannel
        )
        let pairingProvider = PersistingPairingProvider(
            provider: MoonlightPairingProvider(),
            repository: JSONFileHostRepository(fileURL: AppStorageLocations.hostsFile)
        )
        return RuntimeProviderInventory(
            pairing: pairingProvider,
            sessionControl: MoonlightSessionControlProvider(
                controlChannel: controlChannel,
                audioDatagramReservations: audioDatagramReservations
            ),
            videoReceive: videoReceive,
            audioReceive: audioReceive,
            remoteInput: remoteInput,
            realtimeSources: RuntimeProviderRealtimeSources(
                videoReceive: { await videoReceive.snapshot() },
                audioReceive: { await audioReceive.snapshot() },
                remoteInput: { await remoteInput.snapshot() },
                controlTransport: { await controlDriver.snapshot() }
            )
        )
    }
}

@MainActor
@Observable
final class AppModel: ApplicationInputSink {
    private struct PreparedPairingIdentity {
        let owner: ProductPairingOwner
        let material: ClientIdentityMaterial
    }

    private struct ProductStreamLaunchSelection {
        let workspace: ProductWorkspaceReference
        let host: MoonlightHost
        let app: RemoteApp
        let hostSelectionGeneration: ProductHostSelectionGeneration
    }

    private struct ProductSessionStopOperation {
        let id: UUID
        let owner: ProductSessionOwner
        let actionToken: ProductActionToken?
        let task: Task<Bool, Never>
    }

    private enum ProductActionAdmission {
        case navigate(ProductWorkspaceReference, AppNavigationSelection)
        case launch(ProductWorkspaceReference)
        case stop(ProductSessionOwner)
    }

    private struct TVVisionPlatformGeometryAdmission: Equatable {
        let ownership: TVVisionPresentationOwnership
        let update: TVVisionStreamGeometryBindingUpdate
    }

    private enum VisionInputRuntimeTarget: Equatable {
        case active(VisionWindowInputSnapshot)
        case released(
            scope: VisionInputReleaseScope,
            reason: TVVisionFocusIneligibilityReason
        )
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
    let workspaceRegistry: ProductWorkspaceRegistry
    @ObservationIgnored private let workspaceSceneCoordinator:
        ProductWorkspaceSceneCoordinator
    @ObservationIgnored private var explicitHostSelectionByWorkspace:
        [ProductWorkspaceReference: MoonlightHost.ID] = [:]
    @ObservationIgnored private var knownHostSelectionWorkspaces:
        Set<ProductWorkspaceReference> = []
    var primaryWorkspaceReference: ProductWorkspaceReference {
        workspaceSceneCoordinator.primaryWorkspaceReference
    }
    var navigationSelection: AppNavigationSelection {
        get { navigationSelection(in: primaryWorkspaceReference) }
        set { _ = setNavigationSelection(newValue, in: primaryWorkspaceReference) }
    }
    var selectedHostID: MoonlightHost.ID? {
        get { selectedHostID(in: primaryWorkspaceReference) }
        set { _ = setSelectedHostID(newValue, in: primaryWorkspaceReference) }
    }
    var selectedAppID: RemoteApp.ID? {
        selectedAppID(in: primaryWorkspaceReference)
    }
    var appsByHostID: [MoonlightHost.ID: [RemoteApp]] = [:]
    private var appCatalogUpdatedAtByHostID: [MoonlightHost.ID: Date] = [:]
    var pairingUI: PairingUIState {
        workspaceRegistry.state(for: primaryWorkspaceReference)?.pairing
            ?? PairingUIState()
    }
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
    private(set) var tvVisionDisplayHDRFallbackReason:
        TVVisionDisplayHDRFallbackReason?
    var tvOSDisplayHDRFallbackReason: TVOSDisplayHDRFallbackReason? {
        expectedTVVisionPlatform == .tvOS
            ? tvVisionDisplayHDRFallbackReason
            : nil
    }
    private(set) var tvRemoteFocusHandoffState =
        TVRemoteFocusHandoffState.localNavigation
    private(set) var tvRemoteReservedCommandState =
        TVRemoteReservedCommandRuntimeState.idle
    private(set) var visionSystemInteractionDecisionState:
        VisionSystemInteractionDecision?
    private(set) var visionInputOwnershipState:
        VisionWindowInputOwnershipState?
    private(set) var visionInputReleaseEffects: [VisionInputReleaseEffect] = []
    private(set) var visionLocalNavigationRestoreReason:
        TVVisionFocusIneligibilityReason?
    private(set) var visionInputReleasePending = false
    private(set) var tvControllerRosterState: TVControllerRosterSnapshot?
    private(set) var tvControllerRoutedRosterState: TVControllerRosterSnapshot?
    private(set) var tvControllerFeedbackDecisionState:
        TVControllerFeedbackDecision?
    private(set) var tvRemoteInputReleasePending = false

    var tvStreamOverlayVisible: Bool {
        streamOverlayVisibility(in: primaryWorkspaceReference) == .visible
    }

    var visionInputCaptureEnabled: Bool {
        visionInputCaptureEnabled(in: primaryWorkspaceReference)
    }

    func visionInputCaptureEnabled(
        in workspace: ProductWorkspaceReference
    ) -> Bool {
        guard expectedTVVisionPlatform == .visionOS,
              activeSingleWorkspacePlatformOwner(in: workspace) != nil,
              !streamOverlayIsRequestedVisible(in: workspace),
              !visionInputReleasePending,
              let snapshot = currentVisionWindowInputSnapshot,
              snapshot.inputCapabilities.focusEligibility == .eligible,
              visionInputOwnershipState
                == VisionWindowInputOwnershipState(snapshot: snapshot) else {
            return false
        }
        return true
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

    var visionWindowedPresentationState:
        VisionWindowedPresentationState?
    {
        guard expectedTVVisionPlatform == .visionOS,
              let state = tvVisionPlatformPresentationState,
              state.sessionID == activeStreamSessionID,
              state.sessionID == activeMediaSessionID,
              state.mediaGeneration == activeMediaGeneration,
              state.snapshot.phase == .active,
              state.snapshot.ownership
                == tvVisionPlatformPresentationOwnership,
              let windowed = state.snapshot.visionWindowedPresentation,
              windowed.ownership == state.snapshot.ownership,
              windowed.revision == state.snapshot.revision else {
            return nil
        }
        return windowed
    }

    var spatialAudioPresentationStatus: SpatialAudioPresentationStatus {
        SpatialAudioPresentationStatus(audioRuntimeState)
    }

    var tvStreamControlPresentationState: TVStreamControlPresentationState {
        tvStreamControlPresentationState(in: primaryWorkspaceReference)
    }

    func tvStreamControlPresentationState(
        in workspace: ProductWorkspaceReference
    ) -> TVStreamControlPresentationState {
        let hasCurrentOwner =
            activeSingleWorkspacePlatformOwner(in: workspace) != nil
        let hasActiveSession = expectedTVVisionPlatform == .tvOS
            && session.isStreaming
            && hasCurrentOwner
            && activeStreamSessionID != nil
            && activeMediaSessionID == activeStreamSessionID
            && activeMediaGeneration != nil

        let hasSessionFailure: Bool
        if case .failed = session.phase {
            hasSessionFailure = true
        } else {
            hasSessionFailure = false
        }

        let storedCoordinator = tvVisionPlatformPresentationState?.snapshot
        let coordinatorIsCurrent = expectedTVVisionPlatform == .tvOS
            && tvVisionPlatformPresentationState?.sessionID == activeStreamSessionID
            && tvVisionPlatformPresentationState?.sessionID == activeMediaSessionID
            && tvVisionPlatformPresentationState?.mediaGeneration
                == activeMediaGeneration
            && storedCoordinator?.ownership.platform == .tvOS
        let coordinator = coordinatorIsCurrent
            || (hasSessionFailure && storedCoordinator?.ownership.platform == .tvOS)
                ? storedCoordinator
                : nil

        let sceneSurface: TVVisionSceneSurfaceSnapshot?
        if hasActiveSession,
           let admission = tvVisionPlatformGeometryAdmission,
           admission.ownership == tvVisionPlatformPresentationOwnership,
           admission.ownership.platform == .tvOS {
            sceneSurface = admission.update.binding?.sceneSurfaceSnapshot
        } else {
            sceneSurface = nil
        }

        let captureDisposition = sceneSurface.map {
            tvRemoteSurfacePressDisposition(for: $0.surfaceGeneration)
        } ?? .local
        let presentationFailure: TVVisionPlatformPresentationFailure?
        if case let .failed(failure) = coordinator?.phase {
            presentationFailure = failure
        } else {
            presentationFailure = nil
        }

        return TVStreamControlPresentationStateResolver.resolve(
            TVStreamControlPresentationInput(
                hasActiveSession: hasActiveSession,
                hasSessionFailure: hasSessionFailure,
                focusHandoff: tvRemoteFocusHandoffState,
                remoteCaptureDisposition: captureDisposition,
                isRemoteReleasePending: isTVRemoteInputReleasePending,
                sceneSurface: sceneSurface,
                connectedControllerCount:
                    tvControllerRosterState?.controllers.count ?? 0,
                routedControllerCount:
                    tvControllerRoutedRosterState?.controllers.count ?? 0,
                renderPolicy: renderState.policy,
                video: coordinatorIsCurrent ? coordinator?.video : nil,
                hdrPresentation: hdrPresentationStatus,
                hdrFallbackReason: tvOSDisplayHDRFallbackReason,
                audioRoute: coordinatorIsCurrent ? coordinator?.audioRoute : nil,
                spatialAudio: spatialAudioPresentationStatus,
                presentationFailure: presentationFailure
            )
        )
    }

    var visionStreamControlPresentationState:
        VisionStreamControlPresentationState
    {
        visionStreamControlPresentationState(in: primaryWorkspaceReference)
    }

    func visionStreamControlPresentationState(
        in workspace: ProductWorkspaceReference
    ) -> VisionStreamControlPresentationState {
        let hasCurrentOwner =
            activeSingleWorkspacePlatformOwner(in: workspace) != nil
        let hasActiveSession = expectedTVVisionPlatform == .visionOS
            && session.isStreaming
            && hasCurrentOwner
            && activeStreamSessionID != nil
            && activeMediaSessionID == activeStreamSessionID
            && activeMediaGeneration != nil

        let hasSessionFailure: Bool
        if case .failed = session.phase {
            hasSessionFailure = true
        } else {
            hasSessionFailure = false
        }

        let storedCoordinator = tvVisionPlatformPresentationState?.snapshot
        let coordinatorIsCurrent = expectedTVVisionPlatform == .visionOS
            && tvVisionPlatformPresentationState?.sessionID == activeStreamSessionID
            && tvVisionPlatformPresentationState?.sessionID == activeMediaSessionID
            && tvVisionPlatformPresentationState?.mediaGeneration
                == activeMediaGeneration
            && storedCoordinator?.ownership.platform == .visionOS
        let coordinator = coordinatorIsCurrent
            || (hasSessionFailure
                && storedCoordinator?.ownership.platform == .visionOS)
                ? storedCoordinator
                : nil

        let windowedPresentation = visionWindowedPresentationState
        let windowInput: VisionWindowInputSnapshot?
        if hasActiveSession,
           let windowedPresentation,
           let presentation = coordinator?.presentation,
           let currentWindowInput = currentVisionWindowInputSnapshot,
           presentation.ownership == windowedPresentation.ownership,
           presentation.revision == windowedPresentation.revision,
           presentation.sceneSurface.surfaceGeneration
                == windowedPresentation.surfaceGeneration,
           currentWindowInput.presentation.ownership
                == windowedPresentation.ownership,
           currentWindowInput.presentation.surfaceGeneration
                == windowedPresentation.surfaceGeneration,
           currentWindowInput.sceneSurface.platform
                == presentation.sceneSurface.platform,
           currentWindowInput.sceneSurface.surfaceGeneration
                == presentation.sceneSurface.surfaceGeneration,
           currentWindowInput.sceneSurface.activity
                == presentation.sceneSurface.activity,
           currentWindowInput.sceneSurface.attachment
                == presentation.sceneSurface.attachment,
           currentWindowInput.sceneSurface.isVisible
                == presentation.sceneSurface.isVisible,
           currentWindowInput.sceneSurface.geometry
                == presentation.sceneSurface.geometry,
           currentWindowInput.inputCapabilities.platform
                == presentation.inputCapabilities.platform,
           currentWindowInput.inputCapabilities.inputGeneration
                == presentation.inputCapabilities.inputGeneration,
           currentWindowInput.inputCapabilities.supported
                == presentation.inputCapabilities.supported,
           let currentCapabilities = try? TVVisionInputCapabilitySnapshot(
                platform: presentation.inputCapabilities.platform,
                revision: presentation.inputCapabilities.revision,
                inputGeneration:
                    presentation.inputCapabilities.inputGeneration,
                supported: presentation.inputCapabilities.supported,
                focusEligibility:
                    currentWindowInput.inputCapabilities.focusEligibility
           ) {
            windowInput = try? VisionWindowInputSnapshot(
                presentation: windowedPresentation,
                sceneSurface: presentation.sceneSurface,
                inputCapabilities: currentCapabilities
            )
        } else {
            windowInput = nil
        }
        let currentInputGeneration = windowInput?
            .inputCapabilities.inputGeneration
        let controllerRoster = tvControllerRosterState.flatMap { roster in
            roster.inputGeneration == currentInputGeneration
                && roster.controllers.allSatisfy {
                    $0.lease.platform == .visionOS
                }
                    ? roster
                    : nil
        }
        let routedControllerRoster = tvControllerRoutedRosterState.flatMap {
            roster in
            roster.inputGeneration == currentInputGeneration
                && roster.controllers.allSatisfy {
                    $0.lease.platform == .visionOS
                }
                    ? roster
                    : nil
        }
        let presentationFailure: TVVisionPlatformPresentationFailure?
        if case let .failed(failure) = coordinator?.phase {
            presentationFailure = failure
        } else {
            presentationFailure = nil
        }

        return VisionStreamControlPresentationStateResolver.resolve(
            VisionStreamControlPresentationInput(
                hasActiveSession: hasActiveSession,
                hasSessionFailure: hasSessionFailure,
                windowedPresentation: windowedPresentation,
                sceneSurface: windowInput?.sceneSurface,
                inputCapabilities: windowInput?.inputCapabilities,
                inputCaptureEnabled: visionInputCaptureEnabled(in: workspace),
                inputReleasePending: visionInputReleasePending,
                connectedControllerCount:
                    controllerRoster?.controllers.count ?? 0,
                routedControllerCount:
                    routedControllerRoster?.controllers.count ?? 0,
                renderPolicy: renderState.policy,
                video: coordinatorIsCurrent ? coordinator?.video : nil,
                hdrPresentation: hdrPresentationStatus,
                hdrFallbackReason: expectedTVVisionPlatform == .visionOS
                    ? tvVisionDisplayHDRFallbackReason
                    : nil,
                audioRoute: coordinatorIsCurrent
                    ? coordinator?.audioRoute
                    : nil,
                spatialAudio: spatialAudioPresentationStatus,
                presentationFailure: presentationFailure
            )
        )
    }

    var tvVisionPlatformSettingsPresentationState:
        TVVisionPlatformSettingsPresentationState?
    {
        guard let platform = expectedTVVisionPlatform else { return nil }
        return TVVisionPlatformSettingsPresentationStateResolver.resolve(
            TVVisionPlatformSettingsPresentationInput(
                platform: platform,
                settings: settings,
                tvActualState: platform == .tvOS
                    ? tvStreamControlPresentationState
                    : nil,
                visionActualState: platform == .visionOS
                    ? visionStreamControlPresentationState
                    : nil
            )
        )
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
              let owner = activeProductSessionOwner,
              productSessionOwnerIsCurrent(owner),
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
    let tvVisionMetalPresentationOwner: TVVisionMetalPresentationOwner

    private let hostLibraryManager: HostLibraryManager
    private let hostDiscoveryService: any HostDiscoveryService
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
    private var activePairingOwner: ProductPairingOwner?
    private var preparedPairingIdentity: PreparedPairingIdentity?
    private var activeHostDestructiveOwner: ProductHostActionOwner?
    private var hostDestructiveOperationInFlight = false
    private(set) var activeProductSessionOwner: ProductSessionOwner?
    private(set) var productSessionActualPhase: ProductSessionActualPhase = .idle
    private var activeStreamSessionID: UUID?
    @ObservationIgnored private var productSessionStopOperation:
        ProductSessionStopOperation?
    @ObservationIgnored private var hostMonitoringTask: Task<Void, Never>?
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
    @ObservationIgnored private var tvVisionPlatformDiagnosticOwnership:
        TVVisionPresentationOwnership?
    @ObservationIgnored private var tvVisionPlatformDiagnosticLease:
        TVVisionPlatformDiagnosticLease?
    @ObservationIgnored private var tvVisionPlatformApplicationTask:
        Task<Void, Never>?
    @ObservationIgnored private var tvVisionPlatformApplicationOperationID:
        UUID?
    @ObservationIgnored private var tvVisionPlatformGeometryAdmission:
        TVVisionPlatformGeometryAdmission?
    @ObservationIgnored private var tvVisionDisplayHDRSourceSnapshot:
        TVVisionDisplaySnapshot?
    @ObservationIgnored private var tvVisionDisplayHDRApplicationTask:
        Task<Void, Never>?
    @ObservationIgnored private var tvVisionDisplayHDRApplicationOperationID:
        UUID?
    @ObservationIgnored private var isTVVisionDisplayHDRRevisionExhausted = false
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
    @ObservationIgnored private var visionInputDeliveryTask: Task<Void, Never>?
    @ObservationIgnored private var visionInputRuntimeTarget:
        VisionInputRuntimeTarget?
    @ObservationIgnored private var visionInputReconciliationTask:
        Task<Void, Never>?
    @ObservationIgnored private var visionInputReconciliationOperationID: UUID?
    @ObservationIgnored private var visionInputPendingReleaseScope:
        VisionInputReleaseScope?
    @ObservationIgnored private var visionInputPendingRestoreReason:
        TVVisionFocusIneligibilityReason?
    @ObservationIgnored private var visionInputTerminalReleaseRequested = false
#if os(tvOS) || os(visionOS)
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
        hostDiscoveryService: any HostDiscoveryService =
            BonjourHostDiscoveryService(),
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
        clientUniqueID: String = ClientIdentityMaterial.protocolUniqueID,
        remoteInputKey: RemoteInputKeyMaterial? = nil,
        remoteInputKeyGenerator: any RemoteInputKeyMaterialGenerating = SecureRemoteInputKeyMaterialGenerator()
    ) {
        let primaryWorkspaceID = ProductWorkspaceID()
        let workspaceRegistry = ProductWorkspaceRegistry(
            primaryWorkspaceID: primaryWorkspaceID
        )
        let primaryWorkspaceReference = ProductWorkspaceReference(
            id: primaryWorkspaceID,
            generation: .initial
        )
        self.workspaceRegistry = workspaceRegistry
        workspaceSceneCoordinator = ProductWorkspaceSceneCoordinator(
            registry: workspaceRegistry,
            primaryWorkspaceReference: primaryWorkspaceReference
        )
        knownHostSelectionWorkspaces = [primaryWorkspaceReference]
        self.hostLibraryManager = hostLibraryManager
        self.hostDiscoveryService = hostDiscoveryService
        self.settingsRepository = settingsRepository
        self.appCatalogManager = appCatalogManager
        self.appCatalogRepository = appCatalogRepository
        self.streamSessionCoordinator = streamSessionCoordinator
        self.runtimeProviders = runtimeProviders
        let presentationSource = videoPresentationSource ?? StreamVideoPresentationSource()
        self.videoPresentationSource = presentationSource
        let tvVisionMetalPresentationOwner = TVVisionMetalPresentationOwner()
        self.tvVisionMetalPresentationOwner = tvVisionMetalPresentationOwner
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
                videoPresentationSource: presentationSource,
                tvVisionPlatformCoordinatorFactory: {
                    try TVVisionPlatformPresentationCoordinator(
                        actionClient: tvVisionMetalPresentationOwner
                    )
                }
            )
        self.clientIdentityStore = clientIdentityStore
        self.clientIdentityProvisioner = clientIdentityProvisioner
            ?? ClientIdentityManager(store: clientIdentityStore)
        self.clientUniqueID = clientUniqueID
        self.remoteInputKeyOverride = remoteInputKey
        self.remoteInputKeyGenerator = remoteInputKeyGenerator
    }

    var selectedHost: MoonlightHost? {
        selectedHost(in: primaryWorkspaceReference)
    }

    var primaryWorkspaceState: ProductWorkspaceState? {
        workspaceRegistry.state(for: primaryWorkspaceReference)
    }

    func workspaceState(
        for reference: ProductWorkspaceReference
    ) -> ProductWorkspaceState? {
        workspaceRegistry.state(for: reference)
    }

    func navigationSelection(
        in workspace: ProductWorkspaceReference
    ) -> AppNavigationSelection {
        workspaceRegistry.state(for: workspace)?.navigationSelection ?? .library
    }

    @discardableResult
    func setNavigationSelection(
        _ selection: AppNavigationSelection,
        in workspace: ProductWorkspaceReference
    ) -> Bool {
        guard let state = workspaceRegistry.state(for: workspace) else {
            return false
        }
        guard state.navigationSelection != selection else { return true }
        do {
            try workspaceRegistry.update(workspace) {
                $0.navigationSelection = selection
            }
        } catch {
            return false
        }
        if workspace == primaryWorkspaceReference {
            updateTVRemoteNavigationSelection()
        }
        return true
    }

    func selectedHostID(
        in workspace: ProductWorkspaceReference
    ) -> MoonlightHost.ID? {
        workspaceRegistry.state(for: workspace)?.selectedHostID
    }

    @discardableResult
    func setSelectedHostID(
        _ hostID: MoonlightHost.ID?,
        in workspace: ProductWorkspaceReference
    ) -> Bool {
        guard let state = workspaceRegistry.state(for: workspace) else {
            return false
        }
        if let hostID {
            explicitHostSelectionByWorkspace[workspace] = hostID
        } else {
            explicitHostSelectionByWorkspace[workspace] = nil
        }
        guard state.selectedHostID != hostID else { return true }
        do {
            try workspaceRegistry.update(workspace) { state in
                state.selectedHostID = hostID
                applyCachedCatalog(to: &state)
            }
        } catch {
            return false
        }
        invalidateActivePairingIfOwnerStale()
        return true
    }

    func selectedAppID(
        in workspace: ProductWorkspaceReference
    ) -> RemoteApp.ID? {
        workspaceRegistry.state(for: workspace)?.selectedAppID
    }

    func selectedHost(
        in workspace: ProductWorkspaceReference
    ) -> MoonlightHost? {
        guard let hostID = selectedHostID(in: workspace) else { return nil }
        return hosts.first { $0.id == hostID }
    }

    func selectedApps(
        in workspace: ProductWorkspaceReference
    ) -> [RemoteApp] {
        guard let hostID = selectedHostID(in: workspace) else { return [] }
        return appsByHostID[hostID] ?? []
    }

    func selectedApp(
        in workspace: ProductWorkspaceReference
    ) -> RemoteApp? {
        let apps = selectedApps(in: workspace)
        let appID = selectedAppID(in: workspace)
        return apps.first { $0.id == appID } ?? apps.first
    }

    func workspaceSheet(
        in workspace: ProductWorkspaceReference
    ) -> ProductWorkspaceSheet? {
        workspaceRegistry.state(for: workspace)?.presentation.sheet
    }

    @discardableResult
    func presentAddHostSheet(
        in workspace: ProductWorkspaceReference
    ) -> Bool {
        do {
            try workspaceRegistry.update(workspace) { state in
                state.hostLibrary.manualHostDraft = ManualHostDraft()
                state.hostLibrary.manualHostSubmission = .idle
                state.presentation.sheet = .addHost
            }
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func dismissAddHostSheet(
        in workspace: ProductWorkspaceReference
    ) -> Bool {
        guard let state = workspaceRegistry.state(for: workspace),
              state.presentation.sheet == .addHost,
              !state.hostLibrary.manualHostSubmission.isSubmitting else {
            return false
        }
        do {
            try workspaceRegistry.update(workspace) { current in
                guard current.presentation.sheet == .addHost else { return }
                current.presentation.sheet = nil
                current.hostLibrary.manualHostDraft = ManualHostDraft()
                current.hostLibrary.manualHostSubmission = .idle
            }
            return true
        } catch {
            return false
        }
    }

    func connectProductWorkspaceScene(
        restoring identity: ProductWorkspaceSceneIdentity?,
        supportsMultipleWindows: Bool
    ) throws -> ProductWorkspaceSceneAttachment {
        try workspaceSceneCoordinator.connect(
            restoring: identity,
            supportsMultipleWindows: supportsMultipleWindows
        )
    }

    func disconnectProductWorkspaceScene(
        _ attachment: ProductWorkspaceSceneAttachment
    ) async -> ProductWorkspaceSceneCloseOutcome {
        let isAttachmentCurrent = workspaceSceneCoordinator
            .isAttached(attachment)
        let closeOwner = activeProductSessionOwner
            ?? productSessionStopOperation?.owner
        let ownsSession = closeOwner?.workspace == attachment.workspace
        let hasRetainedPresentationSurface = closeOwner.map {
            hasRetainedProductSessionPresentation(
                for: $0,
                excluding: attachment
            )
        } ?? false
        let disposition = ProductWorkspaceSceneClosePolicy.resolve(
            isAttachmentCurrent: isAttachmentCurrent,
            ownsSession: ownsSession,
            phase: ownsSession ? productSessionActualPhase : nil,
            hasRetainedPresentationSurface: hasRetainedPresentationSurface
        )

        switch disposition {
        case .rejectStaleAttachment:
            return .rejectedStaleAttachment
        case .detach:
            return workspaceSceneCoordinator.disconnect(attachment)
                ? .detached
                : .rejectedStaleAttachment
        case .retainSession:
            return workspaceSceneCoordinator.disconnect(attachment)
                ? .retainedSession
                : .rejectedStaleAttachment
        case .stopSession, .awaitSessionStop:
            guard let closeOwner,
                  let operation = beginProductSessionStop(
                    expectedOwner: closeOwner,
                    actionToken: currentStopActionToken(for: closeOwner)
                  ) else {
                _ = workspaceSceneCoordinator.disconnect(attachment)
                return .stopFailed
            }
            guard workspaceSceneCoordinator.disconnect(attachment) else {
                return .rejectedStaleAttachment
            }
            return await awaitProductSessionStopOperation(operation)
                ? .stoppedSession
                : .stopFailed
        }
    }

    private func hasRetainedProductSessionPresentation(
        for owner: ProductSessionOwner,
        excluding attachment: ProductWorkspaceSceneAttachment
    ) -> Bool {
        if workspaceSceneCoordinator.hasOtherAttachment(
            for: owner.workspace,
            excluding: attachment
        ) {
            return true
        }
        guard activeProductSessionOwner == owner,
              activeStreamSessionID == owner.sessionID,
              activeMediaSessionID == owner.sessionID else {
            return false
        }
        switch mobileRuntimeState?.continuityPath {
        case .pictureInPicture, .audioOnly:
            return true
        case .inactive, .foreground, .unavailable, nil:
            return false
        }
    }

    func streamOverlayVisibility(
        in workspace: ProductWorkspaceReference
    ) -> ProductStreamOverlayVisibility {
        guard activeStreamOwner(in: workspace) != nil,
              streamOverlayIsRequestedVisible(in: workspace) else {
            return .hidden
        }
        switch expectedTVVisionPlatform {
        case .tvOS where isTVRemoteInputReleasePending:
            return .hidden
        case .visionOS where visionInputReleasePending:
            return .hidden
        case .tvOS, .visionOS, nil:
            return .visible
        }
    }

    func stopStreamConfirmationSessionID(
        in workspace: ProductWorkspaceReference
    ) -> UUID? {
        guard let owner = activeStreamOwner(in: workspace),
              case let .stopStream(sessionID) = workspaceRegistry
                .state(for: workspace)?.presentation.dialog,
              owner.sessionID == sessionID else {
            return nil
        }
        return sessionID
    }

    @discardableResult
    func setStreamOverlayVisibility(
        _ visibility: ProductStreamOverlayVisibility,
        in workspace: ProductWorkspaceReference
    ) -> Bool {
        guard let owner = activeStreamOwner(in: workspace) else { return false }
        setStreamOverlayVisibilityUnchecked(
            visibility,
            for: owner,
            dismissingStopConfirmation: visibility == .hidden
        )
        return true
    }

    @discardableResult
    func requestStopStreamConfirmation(
        in workspace: ProductWorkspaceReference
    ) -> Bool {
        guard let owner = activeStreamOwner(in: workspace),
              sessionCommandState(in: workspace).stop == .available else {
            return false
        }
        do {
            try workspaceRegistry.update(workspace) { state in
                state.presentation.dialog = .stopStream(
                    sessionID: owner.sessionID
                )
            }
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func cancelStopStreamConfirmation(
        in workspace: ProductWorkspaceReference
    ) -> Bool {
        guard case .stopStream = workspaceRegistry.state(for: workspace)?
            .presentation.dialog else {
            return false
        }
        do {
            try workspaceRegistry.update(workspace) {
                $0.presentation.dialog = nil
            }
            return true
        } catch {
            return false
        }
    }

    @discardableResult
    func confirmStopStream(
        in workspace: ProductWorkspaceReference
    ) async -> Bool {
        guard let task = beginConfirmedStopStream(in: workspace) else {
            return false
        }
        return await task.value
    }

    @discardableResult
    func beginConfirmedStopStream(
        in workspace: ProductWorkspaceReference
    ) -> Task<Bool, Never>? {
        guard case let .stopStream(sessionID) = workspaceRegistry
            .state(for: workspace)?.presentation.dialog else {
            return nil
        }
        let expectedOwner = ProductSessionOwner(
            workspace: workspace,
            sessionID: sessionID
        )
        guard productSessionOwnerIsCurrent(expectedOwner)
                || productSessionStopOperation?.owner == expectedOwner else {
            _ = cancelStopStreamConfirmation(in: workspace)
            return nil
        }
        _ = cancelStopStreamConfirmation(in: workspace)
        return Task { [weak self] in
            guard let self else { return false }
            return await self.stopStream(in: workspace)
        }
    }

    var primaryCatalogState: ProductAppCatalogWorkspaceState? {
        primaryWorkspaceState?.catalog
    }

    func catalogState(
        for reference: ProductWorkspaceReference
    ) -> ProductAppCatalogWorkspaceState? {
        workspaceState(for: reference)?.catalog
    }

    var primaryPairingState: PairingUIState? {
        primaryWorkspaceState?.pairing
    }

    func pairingState(
        for reference: ProductWorkspaceReference
    ) -> PairingUIState? {
        workspaceState(for: reference)?.pairing
    }

    func hostDestructiveState(
        for reference: ProductWorkspaceReference
    ) -> ProductHostDestructiveState? {
        workspaceState(for: reference)?.hostLibrary.destructiveAction
    }

    private func reconcileWorkspaceSelections() {
        #if os(macOS)
        for workspace in workspaceRegistry.states
        where !knownHostSelectionWorkspaces.contains(workspace.reference) {
            knownHostSelectionWorkspaces.insert(workspace.reference)
            if let selectedHostID = workspace.selectedHostID {
                explicitHostSelectionByWorkspace[workspace.reference] =
                    selectedHostID
            }
        }
        let availableHostIDs = ProductMacOSHostSelectionPolicy.orderedHostIDs(
            from: hosts
        )
        #else
        let availableHostIDs = hosts.map(\.id)
        #endif
        workspaceRegistry.reconcile(
            availableHostIDs: availableHostIDs,
            availableAppIDsByHostID: appsByHostID.mapValues {
                Set($0.map(\.id))
            }
        )
        #if os(macOS)
        let availableHosts = Set(availableHostIDs)
        let preferredHostID = availableHostIDs.first
        for workspace in workspaceRegistry.states {
            if let explicitHostID = explicitHostSelectionByWorkspace[
                workspace.reference
            ], workspace.selectedHostID == explicitHostID,
               availableHosts.contains(explicitHostID) {
                continue
            }
            explicitHostSelectionByWorkspace[workspace.reference] = nil
            guard workspace.selectedHostID != preferredHostID else { continue }
            _ = try? workspaceRegistry.update(workspace.reference) { state in
                state.selectedHostID = preferredHostID
                applyCachedCatalog(to: &state)
            }
        }
        #endif
        invalidateActivePairingIfOwnerStale()
    }

    private func reconcileSharedHostRepositoryState(
        trustChangedHostID: MoonlightHost.ID? = nil,
        preservingPairingOwner: ProductPairingOwner? = nil
    ) {
        reconcileWorkspaceSelections()
        let phase: ProductHostLibraryPhase = hosts.isEmpty
            ? .firstUse
            : .available
        for workspace in workspaceRegistry.states {
            _ = try? workspaceRegistry.update(workspace.reference) { state in
                state.hostLibrary.phase = phase
                guard let trustChangedHostID,
                      state.selectedHostID == trustChangedHostID else { return }
                if let preservingPairingOwner,
                   state.reference == preservingPairingOwner.workspace,
                   state.pairing.owner == preservingPairingOwner {
                    return
                }
                state.pairing = PairingUIState()
            }
        }
    }

    private func applyCachedCatalog(
        to state: inout ProductWorkspaceState
    ) {
        guard let owner = state.catalogOwner else {
            state.catalog = ProductAppCatalogWorkspaceState()
            return
        }
        let apps = appsByHostID[owner.hostID] ?? []
        let updatedAt = appCatalogUpdatedAtByHostID[owner.hostID]
        if let selectedAppID = state.selectedAppID,
           !apps.contains(where: { $0.id == selectedAppID }) {
            state.selectedAppID = nil
        }
        if state.selectedAppID == nil {
            state.selectedAppID = apps.first?.id
        }
        let phase: ProductAppCatalogPhase
        if updatedAt == nil {
            phase = .idle
        } else if apps.isEmpty {
            phase = .empty(source: .cached)
        } else {
            phase = .cached
        }
        state.catalog = ProductAppCatalogWorkspaceState(
            owner: owner,
            phase: phase,
            updatedAt: updatedAt
        )
    }

    private func publishCatalogStateToWorkspaces(
        currentOwner: ProductCatalogOwner? = nil
    ) {
        for workspace in workspaceRegistry.states {
            _ = try? workspaceRegistry.update(workspace.reference) { state in
                guard let owner = state.catalogOwner else {
                    state.catalog = ProductAppCatalogWorkspaceState()
                    return
                }
                if owner == currentOwner {
                    let apps = appsByHostID[owner.hostID] ?? []
                    if let selectedAppID = state.selectedAppID,
                       !apps.contains(where: { $0.id == selectedAppID }) {
                        state.selectedAppID = nil
                    }
                    if state.selectedAppID == nil {
                        state.selectedAppID = apps.first?.id
                    }
                    state.catalog = ProductAppCatalogWorkspaceState(
                        owner: owner,
                        phase: apps.isEmpty
                            ? .empty(source: .current)
                            : .current,
                        updatedAt: appCatalogUpdatedAtByHostID[owner.hostID]
                    )
                } else {
                    applyCachedCatalog(to: &state)
                }
            }
        }
    }

    private func catalogOwnerIsCurrent(_ owner: ProductCatalogOwner) -> Bool {
        workspaceRegistry.state(for: owner.workspace)?.catalogOwner == owner
    }

    private func makePairingOwner(
        in workspace: ProductWorkspaceReference,
        hostID: MoonlightHost.ID
    ) -> ProductPairingOwner? {
        guard let state = workspaceRegistry.state(for: workspace),
              state.selectedHostID == hostID else { return nil }
        return ProductPairingOwner(
            workspace: workspace,
            hostID: hostID,
            hostSelectionGeneration: state.hostSelectionGeneration,
            attemptGeneration: ProductPairingAttemptGeneration()
        )
    }

    private func makeHostActionOwner(
        in workspace: ProductWorkspaceReference,
        hostID: MoonlightHost.ID
    ) -> ProductHostActionOwner? {
        guard let state = workspaceRegistry.state(for: workspace),
              state.selectedHostID == hostID else { return nil }
        return ProductHostActionOwner(
            workspace: workspace,
            hostID: hostID,
            hostSelectionGeneration: state.hostSelectionGeneration
        )
    }

    private func hostActionOwnerIsCurrent(
        _ owner: ProductHostActionOwner
    ) -> Bool {
        guard let state = workspaceRegistry.state(for: owner.workspace) else {
            return false
        }
        return state.selectedHostID == owner.hostID
            && state.hostSelectionGeneration == owner.hostSelectionGeneration
    }

    private func pairingOwnerMatchesCurrentSelection(
        _ owner: ProductPairingOwner
    ) -> Bool {
        guard let state = workspaceRegistry.state(for: owner.workspace) else {
            return false
        }
        return state.selectedHostID == owner.hostID
            && state.hostSelectionGeneration == owner.hostSelectionGeneration
    }

    private func pairingOwnerIsCurrent(
        _ owner: ProductPairingOwner,
        requireActiveAttempt: Bool = true
    ) -> Bool {
        guard pairingOwnerMatchesCurrentSelection(owner),
              let state = workspaceRegistry.state(for: owner.workspace),
              state.pairing.owner == owner else { return false }
        guard requireActiveAttempt else { return true }
        return activePairingOwner == owner
            && state.pairing.attemptID == owner.attemptGeneration.rawValue
    }

    private func invalidateActivePairingIfOwnerStale() {
        guard let owner = activePairingOwner,
              !pairingOwnerIsCurrent(owner) else { return }
        activePairingOwner = nil
        if preparedPairingIdentity?.owner == owner {
            preparedPairingIdentity = nil
        }
        if case .pairing = session.phase {
            session.phase = .disconnected
        }
        guard let provider = runtimeProviders.pairing else { return }
        Task {
            await provider.cancelPairing(
                attemptID: owner.attemptGeneration.rawValue
            )
        }
    }

    var selectedApps: [RemoteApp] {
        selectedApps(in: primaryWorkspaceReference)
    }

    var selectedApp: RemoteApp? {
        selectedApp(in: primaryWorkspaceReference)
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

    func ownsStreamPresentation(
        in workspace: ProductWorkspaceReference
    ) -> Bool {
        activeStreamOwner(in: workspace) != nil
    }

    func macOSContentMode(
        in workspace: ProductWorkspaceReference
    ) -> ProductMacOSWorkspaceContentMode {
        ProductMacOSWorkspaceContentModeResolver.resolve(
            selectedHost: selectedHost(in: workspace),
            ownsStreamPresentation: ownsStreamPresentation(in: workspace)
        )
    }

    var isPlatformStreamLifecycleActive: Bool {
        hasActiveStreamSession
    }

    func sessionCommandState(
        in workspace: ProductWorkspaceReference
    ) -> ProductSessionCommandState {
        let workspaceIsCurrent = workspaceRegistry.state(for: workspace) != nil
        let ownership: ProductSessionWorkspaceOwnership
        if let owner = activeProductSessionOwner {
            if !productSessionOwnerOwnsActiveReservation(owner)
                || workspaceRegistry.state(for: owner.workspace) == nil {
                ownership = .staleReservation
            } else if owner.workspace == workspace {
                ownership = .current
            } else {
                ownership = .otherWorkspace
            }
        } else if activeStreamSessionID != nil {
            ownership = .staleReservation
        } else {
            ownership = .none
        }
        return ProductSessionCommandState(ProductSessionCommandInput(
            workspaceIsCurrent: workspaceIsCurrent,
            ownership: ownership,
            phase: productSessionActualPhase,
            hasLaunchSelection: streamLaunchSelection(in: workspace) != nil,
            canLaunchTransport: isStreamTransportAvailable,
            canControlSession: runtimeProviders.sessionControl != nil
        ))
    }

    var streamProductIssue: ProductIssue? {
        streamProductIssue(in: primaryWorkspaceReference)
    }

    func streamProductIssue(
        in workspace: ProductWorkspaceReference
    ) -> ProductIssue? {
        guard let issue = workspaceRegistry.state(for: workspace)?
            .presentation.issue,
              issue.domain == .session else {
            return nil
        }
        return issue
    }

    func canPerformProductAction(_ token: ProductActionToken) -> Bool {
        productActionAdmission(for: token) != nil
    }

    @discardableResult
    func performProductAction(
        _ token: ProductActionToken
    ) async -> ProductActionInvocationResult {
        if let operation = productSessionStopOperation,
           operation.actionToken == token,
           workspaceRegistry.state(for: operation.owner.workspace) != nil {
            return await awaitProductSessionStopOperation(operation)
                ? .performed
                : .rejected(ProductIssue(code: .staleAction))
        }
        guard let admission = productActionAdmission(for: token) else {
            return .rejected(ProductIssue(code: .staleAction))
        }
        switch admission {
        case let .navigate(workspace, destination):
            clearStreamIssue(in: workspace, matching: token)
            _ = try? workspaceRegistry.update(workspace) {
                $0.navigationSelection = destination
            }
        case let .launch(workspace):
            clearStreamIssue(in: workspace, matching: token)
            await launchSelectedApp(in: workspace)
        case let .stop(owner):
            guard await stopStreamInternally(
                expectedOwner: owner,
                actionToken: token
            ) else {
                return .rejected(ProductIssue(code: .staleAction))
            }
        }
        return .performed
    }

    private func productActionAdmission(
        for token: ProductActionToken
    ) -> ProductActionAdmission? {
        guard let workspace = productActionWorkspace(for: token.scope),
              let state = workspaceRegistry.state(for: workspace),
              state.presentation.issue?.action == token else {
            return nil
        }

        let scopedOwner: ProductSessionOwner?
        switch token.scope {
        case let .session(scopedWorkspace, sessionID):
            guard scopedWorkspace == workspace else { return nil }
            let owner = ProductSessionOwner(
                workspace: scopedWorkspace,
                sessionID: sessionID
            )
            if activeProductSessionOwner != nil || activeStreamSessionID != nil {
                guard productSessionOwnerIsCurrent(owner) else { return nil }
            } else {
                switch productSessionActualPhase {
                case .remoteTerminated, .reconnectExhausted, .failed:
                    break
                case .idle, .launching, .waitingForTransport, .streaming,
                     .reconnecting, .stopping:
                    return nil
                }
            }
            scopedOwner = owner
        case let .workspace(scopedWorkspace):
            guard scopedWorkspace == workspace else { return nil }
            scopedOwner = nil
        case .application, .catalog, .pairing, .host:
            return nil
        }

        let commands = sessionCommandState(in: workspace)
        switch token.kind {
        case .chooseHostAndApp:
            return .navigate(workspace, .library)
        case .reconnectStream:
            guard scopedOwner != nil,
                  commands.reconnect == .available else { return nil }
            return .launch(workspace)
        case .stopStream:
            guard let scopedOwner,
                  commands.stop == .available else { return nil }
            return .stop(scopedOwner)
        case .reconnectInput:
            if scopedOwner == nil {
                guard commands.launch == .available else { return nil }
            } else {
                guard commands.reconnect == .available else { return nil }
            }
            return .launch(workspace)
        case .reviewStreamSettings, .reviewHDRSettings, .checkAudioOutput:
            return .navigate(workspace, .settings)
        case .updateBuild:
            return .navigate(workspace, .diagnostics)
        case .correctHostAddress, .refreshHosts, .retryHostAdd,
             .retryHostRemoval, .resetHostTrust, .retryPairing,
             .refreshCatalog, .retrySettingsSave, .exportDiagnostics:
            return nil
        }
    }

    private func productActionWorkspace(
        for scope: ProductActionScope
    ) -> ProductWorkspaceReference? {
        switch scope {
        case let .workspace(workspace),
             let .session(workspace, _):
            return workspace
        case .application, .catalog, .pairing, .host:
            return nil
        }
    }

    var isPairingPINValid: Bool {
        isPairingPINValid(in: primaryWorkspaceReference)
    }

    func isPairingPINValid(
        in workspace: ProductWorkspaceReference
    ) -> Bool {
        guard let pin = workspaceRegistry.state(for: workspace)?.pairing.pin else {
            return false
        }
        let bytes = Array(pin.utf8)
        return bytes.count == 4 && bytes.allSatisfy { (48...57).contains($0) }
    }

    func updatePairingPIN(
        _ pin: String,
        in workspace: ProductWorkspaceReference
    ) {
        _ = try? workspaceRegistry.update(workspace) { state in
            guard let owner = state.pairing.owner,
                  activePairingOwner == owner,
                  state.selectedHostID == owner.hostID,
                  state.hostSelectionGeneration == owner.hostSelectionGeneration,
                  state.pairing.stage == .waitingForPIN,
                  !state.pairing.isRunning else { return }
            state.pairing.pin = pin
            state.pairing.issue = nil
            state.pairing.actionMessage = nil
        }
    }

    func loadInitialState() async {
        await loadInitialState(in: primaryWorkspaceReference)
    }

    func loadInitialState(
        in workspace: ProductWorkspaceReference
    ) async {
        guard workspaceRegistry.state(for: workspace) != nil else { return }
        await loadClientIdentity()
        await loadSettings()
        await loadHosts(in: workspace)
        await loadCachedApps(in: workspace)
    }

    func startHostMonitoring() {
        guard hostMonitoringTask == nil else { return }
        hostMonitoringTask = Task { [weak self] in
            guard let self else { return }
            async let reachability: Void = monitorSavedHostReachability()
            async let discovery: Void = monitorBonjourHosts()
            _ = await (reachability, discovery)
        }
    }

    private func monitorSavedHostReachability() async {
        while !Task.isCancelled {
            await refreshHostReachability()
            do {
                try await Task.sleep(for: .seconds(15))
            } catch {
                return
            }
        }
    }

    private func monitorBonjourHosts() async {
        for await candidate in hostDiscoveryService.candidates() {
            guard !Task.isCancelled else { return }
            guard settings.discoveryEnabled else { continue }
            do {
                hosts = try await hostLibraryManager.mergeDiscoveredHost(
                    candidate
                )
                reconcileSharedHostRepositoryState()
            } catch {
                diagnostics.record(
                    "Automatic host discovery could not update the library.",
                    subsystem: "hosts",
                    severity: .warning,
                    code: "host_discovery_merge_failed"
                )
            }
        }
    }

    func refreshHostReachability() async {
        guard !hosts.isEmpty else { return }
        for workspace in workspaceRegistry.states {
            _ = try? workspaceRegistry.update(workspace.reference) { state in
                state.hostLibrary.isRefreshing = true
            }
        }
        do {
            hosts = try await hostLibraryManager.refreshReachability()
            reconcileSharedHostRepositoryState()
            for workspace in workspaceRegistry.states {
                _ = try? workspaceRegistry.update(workspace.reference) { state in
                    state.hostLibrary.isRefreshing = false
                    state.hostLibrary.refreshIssue = nil
                }
            }
        } catch is CancellationError {
            return
        } catch {
            for workspace in workspaceRegistry.states {
                _ = try? workspaceRegistry.update(workspace.reference) { state in
                    state.hostLibrary.isRefreshing = false
                    state.hostLibrary.refreshIssue = ProductIssue(
                        code: .hostLibraryLoadFailed,
                        actionScope: .workspace(workspace.reference)
                    )
                }
            }
            diagnostics.record(
                "Automatic host status could not be updated.",
                subsystem: "hosts",
                severity: .warning,
                code: "host_reachability_refresh_failed"
            )
        }
    }

    func loadClientIdentity() async {
        do {
            guard let identity = try await clientIdentityStore.loadIdentity() else {
                diagnostics.record("No persisted client identity; pairing remains unavailable", subsystem: "identity")
                logger.info("No persisted client identity in selected store")
                return
            }
            clientUniqueID = identity.protocolUniqueID
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
        renderState.maximumDisplayFramesPerSecond =
            lifecycle.maximumDisplayFramesPerSecond
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
              let owner = activeProductSessionOwner,
              productSessionOwnerIsCurrent(owner),
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
        if previousAdmission?.update.surfaceGeneration
            != update.surfaceGeneration {
            clearTVVisionDisplayHDRState(cancelApplication: true)
            if platform == .visionOS {
                visionSystemInteractionDecisionState = nil
            }
        }
        let admission = TVVisionPlatformGeometryAdmission(
            ownership: ownership,
            update: update
        )
        tvVisionPlatformGeometryAdmission = admission
        if platform == .visionOS {
            updateVisionInputRuntimeTarget(
                update: update,
                ownership: ownership
            )
        }
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
        if let display = tvVisionDisplayHDRSourceSnapshot,
           display.platform == platform {
            scheduleTVVisionDisplayHDRApplication(
                display,
                admission: admission
            )
        }
        if let roster = tvControllerRosterState {
            scheduleTVGameControllerRouting(roster)
        }
        refreshVisionGameControllerRuntime()
    }

    func receiveTVVisionDisplayHDREvent(
        _ event: TVVisionDisplayHDREvent
    ) {
        guard let platform = expectedTVVisionPlatform,
              !isTVVisionDisplayHDRRevisionExhausted,
              event.surfaceGeneration.domain == .surface,
              let admission = tvVisionPlatformGeometryAdmission,
              admission.ownership.platform == platform,
              admission.update.surfaceGeneration == event.surfaceGeneration,
              activeStreamSessionID == admission.ownership.sessionID,
              activeMediaSessionID == admission.ownership.sessionID,
              activeMediaGeneration == admission.ownership.mediaGeneration else {
            return
        }

        switch event {
        case let .snapshot(_, snapshot):
            guard snapshot.platform == platform,
                  snapshot.displayGeneration.domain == .display else { return }
            if let current = tvVisionDisplayHDRSourceSnapshot {
                if snapshot.displayGeneration == current.displayGeneration {
                    guard snapshot.revision > current.revision else { return }
                } else {
                    guard snapshot.displayGeneration
                        > current.displayGeneration else { return }
                }
            }
            tvVisionDisplayHDRSourceSnapshot = snapshot
            tvVisionDisplayHDRFallbackReason = nil
            renderState.displaySnapshot = nil
            renderState.headroom = DisplayHeadroom()
            refreshHDRRenderResolution()
            scheduleTVVisionDisplayHDRApplication(snapshot, admission: admission)
        case .revisionExhausted:
            tvVisionDisplayHDRSourceSnapshot = nil
            isTVVisionDisplayHDRRevisionExhausted = true
            tvVisionDisplayHDRFallbackReason = nil
            renderState.displaySnapshot = nil
            renderState.headroom = DisplayHeadroom()
            renderState.isDisplayRevisionExhausted = true
            refreshHDRRenderResolution()
            scheduleTVVisionDisplayHDRFailure(
                .semanticRevisionExhausted,
                admission: admission
            )
        }
    }

    func receiveTVOSDisplayHDREvent(
        _ event: TVOSDisplayHDRObserverEvent
    ) {
        guard expectedTVVisionPlatform == .tvOS else { return }
        receiveTVVisionDisplayHDREvent(event)
    }

    func receiveTVRemoteSurfacePressEvent(
        _ event: TVRemoteSurfacePressEvent
    ) -> TVRemoteSurfacePressDisposition {
        receiveTVRemoteSurfacePressEvent(
            event,
            in: primaryWorkspaceReference
        )
    }

    func receiveTVRemoteSurfacePressEvent(
        _ event: TVRemoteSurfacePressEvent,
        in workspace: ProductWorkspaceReference
    ) -> TVRemoteSurfacePressDisposition {
        guard activeSingleWorkspacePlatformOwner(in: workspace) != nil else {
            return .local
        }
        return tvRemoteSurfacePressCaptureOwner?.handle(event) ?? .local
    }

    func receiveTVRemoteReservedCommand(_ command: TVRemoteReservedCommand) {
        receiveTVRemoteReservedCommand(
            command,
            in: primaryWorkspaceReference
        )
    }

    func receiveTVRemoteReservedCommand(
        _ command: TVRemoteReservedCommand,
        in workspace: ProductWorkspaceReference
    ) {
        guard expectedTVVisionPlatform == .tvOS,
              activeSingleWorkspacePlatformOwner(in: workspace) != nil else {
            return
        }
        tvRemoteReservedCommandState = .resolve(command)
        guard command == .backMenu else { return }
        _ = setStreamOverlayVisibility(.visible, in: workspace)
    }

    func receiveVisionSystemInteractionEvent(
        _ event: VisionSurfaceSystemInteractionEvent
    ) {
        receiveVisionSystemInteractionEvent(
            event,
            in: primaryWorkspaceReference
        )
    }

    func receiveVisionSystemInteractionEvent(
        _ event: VisionSurfaceSystemInteractionEvent,
        in workspace: ProductWorkspaceReference
    ) {
        guard expectedTVVisionPlatform == .visionOS,
              visionInputCaptureEnabled(in: workspace),
              let snapshot = currentVisionWindowInputSnapshot,
              snapshot.presentation.surfaceGeneration
                == event.surfaceGeneration else { return }
        visionSystemInteractionDecisionState = event.decision
        if event.decision.interaction == .escape {
            _ = setStreamOverlayVisibility(.visible, in: workspace)
        }
    }

    func receiveVisionSurfaceInputEvent(
        _ event: VisionSurfaceInputEvent
    ) -> VisionSurfaceInputDisposition {
        receiveVisionSurfaceInputEvent(event, in: primaryWorkspaceReference)
    }

    func receiveVisionSurfaceInputEvent(
        _ event: VisionSurfaceInputEvent,
        in workspace: ProductWorkspaceReference
    ) -> VisionSurfaceInputDisposition {
        guard expectedTVVisionPlatform == .visionOS,
              visionInputCaptureEnabled(in: workspace),
              let snapshot = currentVisionWindowInputSnapshot,
              let request = try? VisionInputAdmissionRequest(
                presentationGeneration:
                    snapshot.presentation.ownership.presentationGeneration,
                surfaceGeneration: event.surfaceGeneration,
                inputGeneration:
                    snapshot.presentation.ownership.inputGeneration,
                path: event.path
              ),
              case .admit = VisionInputAdmissionResolver.resolve(
                request,
                snapshot: snapshot
              ) else {
            return .local
        }
        let expectedOwnership = snapshot.presentation.ownership
        let previous = visionInputDeliveryTask
        visionInputDeliveryTask = Task { [weak self] in
            await previous?.value
            guard !Task.isCancelled,
                  let self,
                  self.visionInputCaptureEnabled(in: workspace),
                  let current = self.currentVisionWindowInputSnapshot,
                  current.presentation.ownership == expectedOwnership,
                  case .admit = VisionInputAdmissionResolver.resolve(
                    request,
                    snapshot: current
                  ) else { return }
            do {
                try await self.sendRemoteInput(event.event)
            } catch {
                self.requestVisionInputTerminalRelease(
                    reason: .inputUnavailable
                )
            }
        }
        return .captured
    }

    func receiveTVGameControllerRoster(
        _ roster: TVControllerRosterSnapshot
    ) {
        guard let platform = expectedTVVisionPlatform,
              !isTVVisionInputReleasePending,
              activeMediaGeneration == roster.inputGeneration.rawValue,
              roster.controllers.allSatisfy({ $0.lease.platform == platform }),
              currentControllerInputSnapshot?.focusEligibility == .eligible else {
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
        guard let platform = expectedTVVisionPlatform,
              !isTVVisionInputReleasePending,
              sample.lease.platform == platform,
              activeMediaGeneration == sample.lease.inputGeneration.rawValue,
              tvControllerRosterState?.controllers.contains(where: {
                  $0.lease == sample.lease
              }) == true,
              currentControllerInputSnapshot?.focusEligibility == .eligible else {
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
        setTVStreamWorkspaceVisible(
            visible,
            in: primaryWorkspaceReference
        )
    }

    func setTVStreamWorkspaceVisible(
        _ visible: Bool,
        in workspace: ProductWorkspaceReference
    ) {
        guard expectedTVVisionPlatform == .tvOS,
              activeSingleWorkspacePlatformOwner(in: workspace) != nil else {
            return
        }
        applyTVRemoteFocusHandoffState(
            tvRemoteFocusHandoffState.settingWorkspaceVisible(
                visible,
                currentGeometryStamp: currentTVVisionGeometryStamp
            )
        )
    }

    func setTVStreamOverlayVisible(_ visible: Bool) {
        _ = setStreamOverlayVisibility(
            visible ? .visible : .hidden,
            in: primaryWorkspaceReference
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
        submitMacPlatformInput(sample, in: primaryWorkspaceReference)
    }

    @discardableResult
    func submitMacPlatformInput(
        _ sample: MacPlatformInputSample,
        in workspace: ProductWorkspaceReference
    ) -> MacSessionInputEnqueueResult {
        guard let owner = activeProductSessionOwner,
              owner.workspace == workspace,
              productSessionOwnerIsCurrent(owner),
              let generation = activeMacInputGeneration else {
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

    func streamRealtimeSnapshot() async -> ApplicationStreamRealtimeSnapshot {
        let input = macSessionInputCoordinator.snapshot()
        let presentation = videoPresentationSource.snapshot()
        async let remoteInput = runtimeProviders.realtimeSources.remoteInput?()
        async let controlTransport = runtimeProviders.realtimeSources.controlTransport?()
        async let videoReceive = runtimeProviders.realtimeSources.videoReceive?()
        async let audioReceive = runtimeProviders.realtimeSources.audioReceive?()
        async let videoDecode = sessionMediaEnvironment.videoDecodePipelineSnapshot()
        return await ApplicationStreamRealtimeSnapshot(
            input: input,
            remoteInput: remoteInput ?? nil,
            controlTransport: controlTransport ?? nil,
            videoReceive: videoReceive ?? nil,
            audioReceive: audioReceive ?? nil,
            videoDecode: videoDecode,
            videoPresentation: presentation
        )
    }

    func exitMacRelativePointerCapture() {
        exitMacRelativePointerCapture(in: primaryWorkspaceReference)
    }

    func exitMacRelativePointerCapture(
        in workspace: ProductWorkspaceReference
    ) {
        guard activeStreamOwner(in: workspace) != nil else { return }
        _ = setStreamOverlayVisibility(.visible, in: workspace)
        guard settings.input.preferRelativeMouseMode else { return }
        settings.input.preferRelativeMouseMode = false
        refreshMacInputSurfacePolicy()
    }

    func loadHosts() async {
        await loadHosts(in: primaryWorkspaceReference)
    }

    func loadHosts(in workspace: ProductWorkspaceReference) async {
        guard workspaceRegistry.state(for: workspace) != nil else { return }
        _ = try? workspaceRegistry.update(workspace) { state in
            state.hostLibrary.isRefreshing = true
            state.hostLibrary.refreshIssue = nil
        }
        do {
            let loadedHosts = try await hostLibraryManager.loadHosts()
            guard workspaceRegistry.state(for: workspace) != nil else { return }
            hosts = loadedHosts.map { host in
                var checkingHost = host
                checkingHost.reachability = .unknown
                return checkingHost
            }
            reconcileSharedHostRepositoryState()
            _ = try? workspaceRegistry.update(workspace) { state in
                state.hostLibrary.phase = loadedHosts.isEmpty ? .firstUse : .available
                state.hostLibrary.isRefreshing = false
                state.hostLibrary.refreshIssue = nil
            }
            diagnostics.record("Loaded \(hosts.count) saved hosts")
            logger.info("Loaded \(self.hosts.count, privacy: .public) saved hosts")
        } catch {
            guard workspaceRegistry.state(for: workspace) != nil else { return }
            _ = try? workspaceRegistry.update(workspace) { state in
                state.hostLibrary.phase = .failed
                state.hostLibrary.isRefreshing = false
                state.hostLibrary.refreshIssue = ProductIssue(
                    code: .hostLibraryLoadFailed,
                    actionScope: .workspace(workspace)
                )
            }
            diagnostics.record(
                "The saved host library could not be loaded.",
                subsystem: "hosts",
                severity: .error,
                code: "host_library_load_failed"
            )
            logger.error("Failed to load saved hosts")
        }
    }

    @discardableResult
    func retryHostLibraryLoad(
        in workspace: ProductWorkspaceReference
    ) async -> Bool {
        guard let library = workspaceRegistry.state(for: workspace)?.hostLibrary,
              library.phase == .failed,
              !library.isRefreshing,
              let action = library.refreshIssue?.action,
              action.kind == .refreshHosts,
              action.scope == .workspace(workspace) else {
            return false
        }
        await loadHosts(in: workspace)
        return true
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
        await loadCachedApps(in: primaryWorkspaceReference)
    }

    func loadCachedApps(in workspace: ProductWorkspaceReference) async {
        guard let initialState = workspaceRegistry.state(for: workspace) else { return }
        let initialOwner = initialState.catalogOwner
        if let owner = initialOwner {
            _ = try? workspaceRegistry.update(workspace) { state in
                state.catalog = ProductAppCatalogWorkspaceState(
                    owner: owner,
                    phase: .loading(
                        hasCachedApps: !(appsByHostID[owner.hostID] ?? []).isEmpty
                    ),
                    updatedAt: appCatalogUpdatedAtByHostID[owner.hostID]
                )
            }
        }
        do {
            let snapshots = try await appCatalogRepository.loadSnapshots()
            guard workspaceRegistry.state(for: workspace) != nil,
                  initialOwner == nil || initialOwner.map(catalogOwnerIsCurrent) == true
            else { return }
            var loadedApps: [MoonlightHost.ID: [RemoteApp]] = [:]
            var loadedDates: [MoonlightHost.ID: Date] = [:]
            for snapshot in snapshots {
                if let currentDate = loadedDates[snapshot.hostID],
                   currentDate > snapshot.updatedAt {
                    continue
                }
                loadedApps[snapshot.hostID] = snapshot.apps
                loadedDates[snapshot.hostID] = snapshot.updatedAt
            }
            appsByHostID = loadedApps
            appCatalogUpdatedAtByHostID = loadedDates
            reconcileWorkspaceSelections()
            publishCatalogStateToWorkspaces()
            diagnostics.record("Loaded cached app lists for \(snapshots.count) hosts", subsystem: "apps")
        } catch {
            guard let owner = initialOwner, catalogOwnerIsCurrent(owner) else { return }
            _ = try? workspaceRegistry.update(workspace) { state in
                state.catalog = ProductAppCatalogWorkspaceState(
                    owner: owner,
                    phase: .failed(
                        hasCachedApps: !(appsByHostID[owner.hostID] ?? []).isEmpty
                    ),
                    updatedAt: appCatalogUpdatedAtByHostID[owner.hostID],
                    issue: ProductIssue(
                        code: .catalogRefreshFailed,
                        actionScope: .catalog(owner)
                    )
                )
            }
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

    func setManualHostDraft(
        _ draft: ManualHostDraft,
        in workspace: ProductWorkspaceReference
    ) {
        guard workspaceRegistry.state(for: workspace) != nil else { return }
        _ = try? workspaceRegistry.update(workspace) { state in
            state.hostLibrary.manualHostDraft = draft
            state.hostLibrary.manualHostSubmission = .idle
        }
    }

    func addManualHost(name: String? = nil, address: String) async {
        setManualHostDraft(
            ManualHostDraft(name: name ?? "", address: address),
            in: primaryWorkspaceReference
        )
        _ = await addManualHost(in: primaryWorkspaceReference)
    }

    @discardableResult
    func addManualHost(
        in workspace: ProductWorkspaceReference
    ) async -> ManualHostSubmissionState {
        guard let workspaceState = workspaceRegistry.state(for: workspace) else {
            return .failed(ProductIssue(code: .staleAction))
        }
        guard !workspaceState.hostLibrary.manualHostSubmission.isSubmitting else {
            return workspaceState.hostLibrary.manualHostSubmission
        }
        _ = try? workspaceRegistry.update(workspace) {
            $0.hostLibrary.manualHostSubmission = .validating
        }
        let validation = workspaceState.hostLibrary.manualHostDraft.validate()
        guard case let .success(submission) = validation else {
            let issueCode: ProductIssueCode
            if case let .failure(failure) = validation {
                issueCode = failure.issueCode
            } else {
                issueCode = .hostAddressInvalid
            }
            let result = ManualHostSubmissionState.failed(ProductIssue(
                code: issueCode,
                actionScope: .workspace(workspace)
            ))
            _ = try? workspaceRegistry.update(workspace) {
                $0.hostLibrary.manualHostSubmission = result
            }
            return result
        }
        _ = try? workspaceRegistry.update(workspace) {
            $0.hostLibrary.manualHostSubmission = .saving
        }
        do {
            let updatedHosts = try await hostLibraryManager.addManualHost(
                name: submission.name,
                address: submission.normalizedAddress
            )
            guard workspaceRegistry.state(for: workspace) != nil else {
                return .failed(ProductIssue(code: .staleAction))
            }
            hosts = updatedHosts
            reconcileSharedHostRepositoryState()
            let addedHostID = updatedHosts.first {
                $0.addresses.contains { $0.rawValue == submission.normalizedAddress }
            }?.id
            guard let addedHostID else {
                let result = ManualHostSubmissionState.failed(ProductIssue(
                    code: .hostAddFailed,
                    actionScope: .workspace(workspace)
                ))
                _ = try? workspaceRegistry.update(workspace) {
                    $0.hostLibrary.manualHostSubmission = result
                }
                return result
            }
            let result = ManualHostSubmissionState.succeeded(hostID: addedHostID)
            _ = try? workspaceRegistry.update(workspace) { state in
                state.selectedHostID = addedHostID
                state.selectedAppID = nil
                state.hostLibrary.phase = .available
                state.hostLibrary.manualHostDraft = ManualHostDraft()
                state.hostLibrary.manualHostSubmission = result
            }
            diagnostics.record("Added a host", subsystem: "hosts", code: "host_added")
            return result
        } catch {
            guard workspaceRegistry.state(for: workspace) != nil else {
                return .failed(ProductIssue(code: .staleAction))
            }
            let result = ManualHostSubmissionState.failed(ProductIssue(
                code: .hostAddFailed,
                actionScope: .workspace(workspace)
            ))
            _ = try? workspaceRegistry.update(workspace) {
                $0.hostLibrary.manualHostSubmission = result
            }
            diagnostics.record(
                "The host could not be added.",
                subsystem: "hosts",
                severity: .error,
                code: "host_add_failed"
            )
            return result
        }
    }

    @discardableResult
    func requestHostRemoval(
        in workspace: ProductWorkspaceReference
    ) -> ProductHostDestructiveConfirmation? {
        requestHostDestructiveAction(.remove, in: workspace)
    }

    @discardableResult
    func requestHostTrustReset(
        in workspace: ProductWorkspaceReference
    ) -> ProductHostDestructiveConfirmation? {
        guard let hostID = workspaceRegistry.state(for: workspace)?.selectedHostID,
              let host = hosts.first(where: { $0.id == hostID }),
              host.pairingState == .paired || host.pinnedIdentity != nil else {
            return nil
        }
        return requestHostDestructiveAction(.resetTrust, in: workspace)
    }

    func cancelHostDestructiveAction(
        in workspace: ProductWorkspaceReference
    ) {
        _ = try? workspaceRegistry.update(workspace) { state in
            switch state.hostLibrary.destructiveAction {
            case .performing:
                guard !hostDestructiveOperationInFlight,
                      activeHostDestructiveOwner?.workspace == workspace else {
                    return
                }
                activeHostDestructiveOwner = nil
            case .awaitingConfirmation, .failed:
                break
            case .idle, .succeeded:
                return
            }
            state.hostLibrary.destructiveAction = .idle
            switch state.presentation.dialog {
            case .removeHost, .resetHostTrust:
                state.presentation.dialog = nil
            case .stopStream, nil:
                break
            }
        }
    }

    @discardableResult
    func retryHostDestructiveAction(
        in workspace: ProductWorkspaceReference
    ) -> ProductHostDestructiveConfirmation? {
        guard let state = workspaceRegistry.state(for: workspace),
              case let .failed(confirmation, issue) =
                state.hostLibrary.destructiveAction,
              hostActionOwnerIsCurrent(confirmation.owner),
              issue.action?.scope == .host(confirmation.owner) else {
            return nil
        }
        return requestHostDestructiveAction(
            confirmation.kind,
            in: workspace
        )
    }

    @discardableResult
    func beginHostDestructiveAction(
        in workspace: ProductWorkspaceReference
    ) -> ProductHostDestructiveConfirmation? {
        guard let state = workspaceRegistry.state(for: workspace),
              case let .awaitingConfirmation(confirmation) =
                state.hostLibrary.destructiveAction,
              activeHostDestructiveOwner == nil,
              confirmation.owner.workspace == workspace,
              hostActionOwnerIsCurrent(confirmation.owner),
              hosts.contains(where: { $0.id == confirmation.owner.hostID }) else {
            return nil
        }

        do {
            try workspaceRegistry.update(workspace) { current in
                current.hostLibrary.destructiveAction = .performing(confirmation)
                current.presentation.dialog = nil
            }
        } catch {
            return nil
        }
        activeHostDestructiveOwner = confirmation.owner
        hostDestructiveOperationInFlight = false
        return confirmation
    }

    @discardableResult
    func confirmHostDestructiveAction(
        in workspace: ProductWorkspaceReference
    ) async -> ProductHostDestructiveState {
        guard let confirmation = beginHostDestructiveAction(in: workspace) else {
            return .idle
        }
        return await performHostDestructiveAction(confirmation)
    }

    @discardableResult
    func performHostDestructiveAction(
        _ confirmation: ProductHostDestructiveConfirmation
    ) async -> ProductHostDestructiveState {
        guard workspaceRegistry.state(for: confirmation.owner.workspace)?
            .hostLibrary.destructiveAction == .performing(confirmation),
              activeHostDestructiveOwner == confirmation.owner,
              !hostDestructiveOperationInFlight else {
            return .idle
        }
        hostDestructiveOperationInFlight = true
        defer {
            if activeHostDestructiveOwner == confirmation.owner {
                activeHostDestructiveOwner = nil
            }
            hostDestructiveOperationInFlight = false
        }

        let sessionIsActive = session.activeHostID == confirmation.owner.hostID
        if sessionIsActive && !confirmation.requiresSessionStop {
            return failHostDestructiveAction(
                confirmation,
                code: destructiveFailureCode(for: confirmation.kind)
            )
        }
        if sessionIsActive {
            _ = await stopStreamInternally()
            guard hostDestructiveOwnerCanMutate(confirmation.owner) else {
                return failHostDestructiveAction(
                    confirmation,
                    code: destructiveFailureCode(for: confirmation.kind)
                )
            }
        }

        guard hostDestructiveOwnerCanMutate(confirmation.owner) else {
            return failHostDestructiveAction(
                confirmation,
                code: .staleAction
            )
        }

        if let pairingOwner = activePairingOwner,
           pairingOwner.hostID == confirmation.owner.hostID {
            await cancelPairing(owner: pairingOwner, showCancelledState: false)
            guard hostDestructiveOwnerCanMutate(confirmation.owner),
                  activePairingOwner?.hostID != confirmation.owner.hostID else {
                return failHostDestructiveAction(
                    confirmation,
                    code: destructiveFailureCode(for: confirmation.kind)
                )
            }
        }

        do {
            switch confirmation.kind {
            case .remove:
                try await removeHostAndCatalog(owner: confirmation.owner)
            case .resetTrust:
                try await resetHostTrust(owner: confirmation.owner)
            }
            let result = ProductHostDestructiveState.succeeded(
                kind: confirmation.kind,
                hostID: confirmation.owner.hostID
            )
            _ = try? workspaceRegistry.update(
                confirmation.owner.workspace
            ) { current in
                current.hostLibrary.destructiveAction = result
                current.presentation.dialog = nil
            }
            return result
        } catch HostDestructiveApplicationError.staleOwner {
            return failHostDestructiveAction(
                confirmation,
                code: .staleAction
            )
        } catch {
            return failHostDestructiveAction(
                confirmation,
                code: destructiveFailureCode(for: confirmation.kind)
            )
        }
    }

    private func requestHostDestructiveAction(
        _ kind: ProductHostDestructiveKind,
        in workspace: ProductWorkspaceReference
    ) -> ProductHostDestructiveConfirmation? {
        guard activeHostDestructiveOwner == nil,
              let state = workspaceRegistry.state(for: workspace),
              let hostID = state.selectedHostID,
              hosts.contains(where: { $0.id == hostID }),
              let owner = makeHostActionOwner(in: workspace, hostID: hostID) else {
            return nil
        }
        if case let .awaitingConfirmation(existing) =
            state.hostLibrary.destructiveAction,
           existing.owner == owner,
           existing.kind == kind {
            return existing
        }
        let confirmation = ProductHostDestructiveConfirmation(
            owner: owner,
            kind: kind,
            requiresSessionStop: session.activeHostID == hostID
        )
        _ = try? workspaceRegistry.update(workspace) { state in
            state.hostLibrary.destructiveAction = .awaitingConfirmation(
                confirmation
            )
            state.presentation.dialog = switch kind {
            case .remove:
                .removeHost(confirmation)
            case .resetTrust:
                .resetHostTrust(confirmation)
            }
        }
        return confirmation
    }

    private func removeHostAndCatalog(
        owner: ProductHostActionOwner
    ) async throws {
        guard let originalHost = hosts.first(where: { $0.id == owner.hostID }),
              hostDestructiveOwnerCanMutate(owner) else {
            throw HostDestructiveApplicationError.staleOwner
        }
        let originalSnapshots = try await appCatalogRepository.loadSnapshots()
        guard hostDestructiveOwnerCanMutate(owner) else {
            throw HostDestructiveApplicationError.staleOwner
        }
        let retainedSnapshots = originalSnapshots.filter { $0.hostID != owner.hostID }
        try await appCatalogRepository.saveSnapshots(retainedSnapshots)
        guard hostDestructiveOwnerCanMutate(owner) else {
            try? await appCatalogRepository.saveSnapshots(originalSnapshots)
            throw HostDestructiveApplicationError.staleOwner
        }
        let updatedHosts: [MoonlightHost]
        do {
            updatedHosts = try await hostLibraryManager.removeHost(id: owner.hostID)
        } catch {
            try? await appCatalogRepository.saveSnapshots(originalSnapshots)
            throw error
        }
        guard hostDestructiveOwnerCanMutate(owner) else {
            _ = try? await hostLibraryManager.replaceHost(originalHost)
            try? await appCatalogRepository.saveSnapshots(originalSnapshots)
            throw HostDestructiveApplicationError.staleOwner
        }
        hosts = updatedHosts
        appsByHostID[owner.hostID] = nil
        appCatalogUpdatedAtByHostID[owner.hostID] = nil
        reconcileSharedHostRepositoryState()
        publishCatalogStateToWorkspaces()
        diagnostics.record("Removed host", subsystem: "hosts", code: "host_removed")
    }

    private func resetHostTrust(
        owner: ProductHostActionOwner
    ) async throws {
        guard let originalHost = hosts.first(where: { $0.id == owner.hostID }),
              hostDestructiveOwnerCanMutate(owner) else {
            throw HostDestructiveApplicationError.missingHost
        }
        var host = originalHost
        host.pairingState = .unpaired
        host.pinnedIdentity = nil
        let updatedHosts = try await hostLibraryManager.replaceHost(host)
        guard hostDestructiveOwnerCanMutate(owner) else {
            _ = try? await hostLibraryManager.replaceHost(originalHost)
            throw HostDestructiveApplicationError.staleOwner
        }
        hosts = updatedHosts
        reconcileSharedHostRepositoryState(
            trustChangedHostID: owner.hostID
        )
        diagnostics.record(
            "Reset host trust",
            subsystem: "hosts",
            code: "host_trust_reset"
        )
    }

    private enum HostDestructiveApplicationError: Error {
        case missingHost
        case staleOwner
    }

    private func hostDestructiveOwnerCanMutate(
        _ owner: ProductHostActionOwner
    ) -> Bool {
        activeHostDestructiveOwner == owner
            && hostActionOwnerIsCurrent(owner)
            && session.activeHostID != owner.hostID
    }

    private func failHostDestructiveAction(
        _ confirmation: ProductHostDestructiveConfirmation,
        code: ProductIssueCode
    ) -> ProductHostDestructiveState {
        let issue = ProductIssue(
            code: code,
            actionScope: .host(confirmation.owner)
        )
        let result = ProductHostDestructiveState.failed(confirmation, issue)
        _ = try? workspaceRegistry.update(confirmation.owner.workspace) { state in
            guard state.hostLibrary.destructiveAction.confirmation == confirmation else {
                return
            }
            state.hostLibrary.destructiveAction = result
            state.presentation.dialog = nil
        }
        diagnostics.record(
            confirmation.kind == .remove
                ? "The selected host could not be removed."
                : "The selected host trust could not be reset.",
            subsystem: "hosts",
            severity: .error,
            code: code.rawValue
        )
        return result
    }

    private func destructiveFailureCode(
        for kind: ProductHostDestructiveKind
    ) -> ProductIssueCode {
        switch kind {
        case .remove:
            .hostRemoveFailed
        case .resetTrust:
            .hostTrustResetFailed
        }
    }

    func beginPairing(host: MoonlightHost) async {
        await beginPairing(host: host, in: primaryWorkspaceReference)
    }

    func beginPairing(
        host: MoonlightHost,
        in workspace: ProductWorkspaceReference
    ) async {
        guard workspaceRegistry.state(for: workspace)?.selectedHostID == host.id,
              activeHostDestructiveOwner?.hostID != host.id,
              hosts.contains(where: { $0.id == host.id }) else { return }
        if let activePairingOwner {
            await cancelPairing(owner: activePairingOwner, showCancelledState: false)
        }
        guard let owner = makePairingOwner(in: workspace, hostID: host.id),
              hosts.contains(where: { $0.id == host.id }) else { return }

        guard runtimeProviders.pairing != nil else {
            let diagnostic = ApplicationDiagnosticFactory.pairingUnavailable
            _ = try? workspaceRegistry.update(workspace) { state in
                guard state.selectedHostID == owner.hostID,
                      state.hostSelectionGeneration == owner.hostSelectionGeneration else {
                    return
                }
                state.pairing = PairingUIState(
                    owner: owner,
                    stage: .failed,
                    message: diagnostic.summary,
                    actionMessage: diagnostic.action?.label,
                    issue: ProductIssue(
                        code: .pairingUnavailable,
                        actionScope: .pairing(owner)
                    )
                )
            }
            session.phase = .disconnected
            diagnostics.record(diagnostic)
            return
        }

        diagnostics.clearActionableEvents(in: [.pairing])
        activePairingOwner = owner
        preparedPairingIdentity = nil
        _ = try? workspaceRegistry.update(workspace) { state in
            state.pairing = PairingUIState(
                owner: owner,
                attemptID: owner.attemptGeneration.rawValue,
                stage: .idle,
                isRunning: true,
                message: "Preparing client identity..."
            )
        }
        session.phase = .pairing(pin: "")

        do {
            let identity = try await clientIdentityProvisioner.loadOrCreateIdentity(
                createdAt: Date()
            )
            guard pairingOwnerIsCurrent(owner) else {
                invalidateActivePairingIfOwnerStale()
                return
            }
            preparedPairingIdentity = PreparedPairingIdentity(
                owner: owner,
                material: identity
            )
            clientUniqueID = identity.protocolUniqueID
            _ = try? workspaceRegistry.update(workspace) { state in
                guard state.pairing.owner == owner else { return }
                state.pairing.stage = .waitingForPIN
                state.pairing.isRunning = false
                state.pairing.message = "Enter the PIN shown on \(host.name)."
                state.pairing.issue = nil
            }
            diagnostics.record("Prepared client identity for pairing", subsystem: "pairing")
        } catch {
            guard pairingOwnerIsCurrent(owner) else {
                invalidateActivePairingIfOwnerStale()
                return
            }
            failPairingAttempt(
                owner: owner,
                diagnostic: ApplicationDiagnosticFactory.pairingIdentityUnavailable
            )
        }
    }

    func submitPairingPIN() async {
        await submitPairingPIN(in: primaryWorkspaceReference)
    }

    func submitPairingPIN(
        in workspace: ProductWorkspaceReference
    ) async {
        guard let state = workspaceRegistry.state(for: workspace),
              let owner = state.pairing.owner,
              pairingOwnerIsCurrent(owner),
              let host = hosts.first(where: { $0.id == owner.hostID }),
              state.pairing.stage == .waitingForPIN,
              !state.pairing.isRunning else { return }

        guard let provider = runtimeProviders.pairing else {
            failPairingAttempt(
                owner: owner,
                diagnostic: ApplicationDiagnosticFactory.pairingUnavailable,
                issueCode: .pairingUnavailable
            )
            return
        }
        guard let preparedPairingIdentity,
              preparedPairingIdentity.owner == owner else {
            failPairingAttempt(
                owner: owner,
                diagnostic: ApplicationDiagnosticFactory.pairingIdentityUnavailable
            )
            return
        }

        let pin = state.pairing.pin
        guard isPairingPINValid(in: workspace) else {
            _ = try? workspaceRegistry.update(workspace) { current in
                guard current.pairing.owner == owner else { return }
                current.pairing.message = "PIN must contain exactly four digits."
                current.pairing.issue = ProductIssue(
                    code: .pairingPINInvalid,
                    actionScope: .pairing(owner)
                )
            }
            return
        }

        let request = PairingRuntimeRequest(
            attemptID: owner.attemptGeneration.rawValue,
            host: host,
            pin: pin,
            clientIdentity: preparedPairingIdentity.material
        )
        _ = try? workspaceRegistry.update(workspace) { current in
            guard current.pairing.owner == owner else { return }
            current.pairing.pin = ""
            current.pairing.isRunning = true
            current.pairing.stage = .exchangingSecrets
            current.pairing.message = pairingMessage(
                for: .exchangingSecrets,
                hostName: host.name
            )
            current.pairing.issue = nil
        }
        session.phase = .pairing(pin: "")

        var completedResult: PairingResult?
        do {
            let events = await provider.pair(request)
            for try await event in events {
                guard pairingOwnerIsCurrent(owner) else {
                    invalidateActivePairingIfOwnerStale()
                    return
                }
                switch event {
                case let .progress(snapshot):
                    guard snapshot.attemptID == owner.attemptGeneration.rawValue,
                          snapshot.hostID == owner.hostID else {
                        throw PairingApplicationError.invalidAuthenticatedCompletion
                    }
                    if let failure = snapshot.failure {
                        throw failure
                    }
                    _ = try? workspaceRegistry.update(workspace) { current in
                        guard current.pairing.owner == owner else { return }
                        current.pairing.stage = snapshot.stage
                        current.pairing.message = pairingMessage(
                            for: snapshot.stage,
                            hostName: host.name
                        )
                        current.pairing.actionMessage = nil
                        current.pairing.issue = nil
                    }
                case let .completed(result):
                    try validatePairingCompletion(
                        result,
                        expectedHostID: owner.hostID
                    )
                    completedResult = result
                }
            }
            guard let result = completedResult else {
                throw PairingApplicationError.incompleteRuntimeStream
            }
            guard pairingOwnerIsCurrent(owner) else {
                invalidateActivePairingIfOwnerStale()
                return
            }
            applyPairingCompletion(result, owner: owner)
        } catch {
            guard pairingOwnerIsCurrent(owner) else {
                invalidateActivePairingIfOwnerStale()
                return
            }
            if let failure = error as? PairingFailure, failure.code == .cancelled {
                await cancelPairing(owner: owner, showCancelledState: true)
                return
            }
            failPairingAttempt(
                owner: owner,
                diagnostic: ApplicationDiagnosticFactory.pairingFailure(error)
            )
            await provider.cancelPairing(
                attemptID: owner.attemptGeneration.rawValue
            )
        }
    }

    @discardableResult
    func retryPairing(
        in workspace: ProductWorkspaceReference
    ) async -> Bool {
        guard let state = workspaceRegistry.state(for: workspace),
              state.pairing.stage == .failed,
              let owner = state.pairing.owner,
              pairingOwnerIsCurrent(owner, requireActiveAttempt: false),
              let action = state.pairing.issue?.action,
              action.kind == .retryPairing,
              action.scope == .pairing(owner),
              let host = hosts.first(where: { $0.id == owner.hostID }) else {
            return false
        }
        await beginPairing(host: host, in: workspace)
        return pairingState(for: workspace)?.owner != owner
    }

    func cancelPairing() async {
        await cancelPairing(in: primaryWorkspaceReference)
    }

    func cancelPairing(
        in workspace: ProductWorkspaceReference
    ) async {
        guard let owner = activePairingOwner,
              owner.workspace == workspace else { return }
        await cancelPairing(owner: owner, showCancelledState: true)
    }

    func refreshAppsForSelectedHost() async {
        await refreshAppsForSelectedHost(in: primaryWorkspaceReference)
    }

    @discardableResult
    func retryAppCatalog(
        in workspace: ProductWorkspaceReference
    ) async -> Bool {
        guard let state = workspaceRegistry.state(for: workspace),
              let owner = state.catalogOwner,
              state.catalog.owner == owner,
              case .failed = state.catalog.phase,
              !state.catalog.phase.isRefreshing,
              let action = state.catalog.issue?.action,
              action.kind == .refreshCatalog,
              action.scope == .catalog(owner),
              catalogOwnerIsCurrent(owner) else {
            return false
        }
        await refreshAppsForSelectedHost(in: workspace)
        return true
    }

    func refreshAppsForSelectedHost(
        in workspace: ProductWorkspaceReference
    ) async {
        guard let state = workspaceRegistry.state(for: workspace),
              let owner = state.catalogOwner,
              let host = hosts.first(where: { $0.id == owner.hostID }) else {
            return
        }
        guard !state.catalog.phase.isRefreshing else { return }
        guard host.pairingState == .paired else {
            _ = try? workspaceRegistry.update(workspace) { current in
                current.catalog = ProductAppCatalogWorkspaceState(
                    owner: owner,
                    phase: .failed(
                        hasCachedApps: !(appsByHostID[owner.hostID] ?? []).isEmpty
                    ),
                    updatedAt: appCatalogUpdatedAtByHostID[owner.hostID],
                    issue: ProductIssue(
                        code: .catalogRequiresPairing,
                        actionScope: .catalog(owner)
                    )
                )
            }
            diagnostics.record("App refresh requires a paired host", subsystem: "apps")
            return
        }

        _ = try? workspaceRegistry.update(workspace) { current in
            current.catalog = ProductAppCatalogWorkspaceState(
                owner: owner,
                phase: .loading(
                    hasCachedApps: !(appsByHostID[owner.hostID] ?? []).isEmpty
                ),
                updatedAt: appCatalogUpdatedAtByHostID[owner.hostID]
            )
        }

        do {
            let snapshot = try await appCatalogManager.refreshApps(for: host, clientUniqueID: clientUniqueID)
            guard snapshot.hostID == owner.hostID,
                  catalogOwnerIsCurrent(owner) else { return }
            var updatedApps = appsByHostID
            var updatedDates = appCatalogUpdatedAtByHostID
            updatedApps[owner.hostID] = snapshot.apps
            updatedDates[owner.hostID] = snapshot.updatedAt
            let snapshots = updatedApps.map { hostID, apps in
                AppListSnapshot(
                    hostID: hostID,
                    apps: apps,
                    updatedAt: updatedDates[hostID] ?? snapshot.updatedAt
                )
            }
            try await appCatalogRepository.saveSnapshots(snapshots)
            guard catalogOwnerIsCurrent(owner) else { return }
            appsByHostID = updatedApps
            appCatalogUpdatedAtByHostID = updatedDates
            reconcileWorkspaceSelections()
            publishCatalogStateToWorkspaces(currentOwner: owner)
            diagnostics.record(
                "Loaded \(snapshot.apps.count) apps",
                subsystem: "apps",
                code: "app_catalog_refreshed"
            )
        } catch {
            guard catalogOwnerIsCurrent(owner) else { return }
            _ = try? workspaceRegistry.update(workspace) { current in
                current.catalog = ProductAppCatalogWorkspaceState(
                    owner: owner,
                    phase: .failed(
                        hasCachedApps: !(appsByHostID[owner.hostID] ?? []).isEmpty
                    ),
                    updatedAt: appCatalogUpdatedAtByHostID[owner.hostID],
                    issue: ProductIssue(
                        code: .catalogRefreshFailed,
                        actionScope: .catalog(owner)
                    )
                )
            }
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
    }

    func select(app: RemoteApp) {
        _ = select(app: app, in: primaryWorkspaceReference)
    }

    @discardableResult
    func select(
        app: RemoteApp,
        in workspace: ProductWorkspaceReference
    ) -> Bool {
        guard let state = workspaceRegistry.state(for: workspace),
              let owner = state.catalogOwner,
              appsByHostID[owner.hostID]?.contains(where: { $0.id == app.id }) == true
        else { return false }
        _ = try? workspaceRegistry.update(workspace) {
            $0.selectedAppID = app.id
        }
        return true
    }

    private func streamLaunchSelection(
        in workspace: ProductWorkspaceReference
    ) -> ProductStreamLaunchSelection? {
        guard let state = workspaceRegistry.state(for: workspace),
              let hostID = state.selectedHostID,
              let host = hosts.first(where: { $0.id == hostID }) else {
            return nil
        }
        let apps = appsByHostID[hostID] ?? []
        let app = state.selectedAppID.flatMap { selectedAppID in
            apps.first { $0.id == selectedAppID }
        } ?? apps.first
        guard let app else { return nil }
        return ProductStreamLaunchSelection(
            workspace: workspace,
            host: host,
            app: app,
            hostSelectionGeneration: state.hostSelectionGeneration
        )
    }

    private func productSessionLaunchIsCurrent(
        owner: ProductSessionOwner,
        selection: ProductStreamLaunchSelection
    ) -> Bool {
        guard productSessionOwnerIsCurrent(owner),
              owner.workspace == selection.workspace,
              let current = streamLaunchSelection(in: selection.workspace) else {
            return false
        }
        return current.host.id == selection.host.id
            && current.app.id == selection.app.id
            && current.hostSelectionGeneration == selection.hostSelectionGeneration
    }

    private func productSessionOwnerIsCurrent(
        _ owner: ProductSessionOwner
    ) -> Bool {
        productSessionOwnerOwnsActiveReservation(owner)
            && workspaceRegistry.state(for: owner.workspace) != nil
    }

    private func activeStreamOwner(
        in workspace: ProductWorkspaceReference
    ) -> ProductSessionOwner? {
        guard let owner = activeProductSessionOwner,
              owner.workspace == workspace,
              productSessionOwnerIsCurrent(owner) else {
            return nil
        }
        return owner
    }

    private func activeSingleWorkspacePlatformOwner(
        in workspace: ProductWorkspaceReference
    ) -> ProductSessionOwner? {
        guard expectedTVVisionPlatform != nil,
              workspace == primaryWorkspaceReference else { return nil }
        return activeStreamOwner(in: workspace)
    }

    private func streamOverlayIsRequestedVisible(
        in workspace: ProductWorkspaceReference
    ) -> Bool {
        workspaceRegistry.state(for: workspace)?.presentation.streamOverlay
            == .visible
    }

    private func setStreamOverlayVisibilityUnchecked(
        _ visibility: ProductStreamOverlayVisibility,
        for owner: ProductSessionOwner,
        dismissingStopConfirmation: Bool = false
    ) {
        guard productSessionOwnerIsCurrent(owner) else { return }
        _ = try? workspaceRegistry.update(owner.workspace) { state in
            state.presentation.streamOverlay = visibility
            if dismissingStopConfirmation,
               case .stopStream = state.presentation.dialog {
                state.presentation.dialog = nil
            }
        }
        synchronizeStreamOverlayInputOwnership(for: owner)
    }

    private func clearStreamTransientPresentation(
        for owner: ProductSessionOwner
    ) {
        _ = try? workspaceRegistry.update(owner.workspace) { state in
            state.presentation.streamOverlay = .hidden
            if case .stopStream = state.presentation.dialog {
                state.presentation.dialog = nil
            }
        }
    }

    private func synchronizeStreamOverlayInputOwnership(
        for owner: ProductSessionOwner
    ) {
        guard productSessionOwnerIsCurrent(owner) else { return }
        applyInputLifecycle(latestLifecycleDirective.input)
        refreshMacInputSurfacePolicy()
        switch expectedTVVisionPlatform {
        case .tvOS:
            guard activeSingleWorkspacePlatformOwner(
                in: owner.workspace
            ) != nil else { return }
            applyTVRemoteFocusHandoffState(
                tvRemoteFocusHandoffState.settingOverlayVisible(
                    streamOverlayIsRequestedVisible(in: owner.workspace),
                    currentGeometryStamp: currentTVVisionGeometryStamp
                )
            )
        case .visionOS:
            guard activeSingleWorkspacePlatformOwner(
                in: owner.workspace
            ) != nil else { return }
            guard let admission = tvVisionPlatformGeometryAdmission,
                  admission.ownership == tvVisionPlatformPresentationOwnership else {
                refreshVisionGameControllerRuntime()
                return
            }
            updateVisionInputRuntimeTarget(
                update: admission.update,
                ownership: admission.ownership
            )
            refreshVisionGameControllerRuntime()
        case nil:
            break
        }
    }

    private func productSessionOwnerOwnsActiveReservation(
        _ owner: ProductSessionOwner
    ) -> Bool {
        activeProductSessionOwner == owner
            && activeStreamSessionID == owner.sessionID
    }

    private func invalidatePreparedProductSession(
        _ owner: ProductSessionOwner
    ) async {
        guard activeProductSessionOwner == owner,
              activeStreamSessionID == owner.sessionID else { return }
        _ = try? await streamSessionCoordinator.fail(
            SessionApplicationError.staleProductSessionOwner,
            sessionID: owner.sessionID
        )
        guard activeProductSessionOwner == owner,
              activeStreamSessionID == owner.sessionID else { return }
        activeProductSessionOwner = nil
        activeStreamSessionID = nil
        productSessionActualPhase = .idle
        activeControlReadiness = []
        activeMediaReadiness = []
        streamLaunchUI.isLaunching = false
        clearStreamActionPresentation(in: owner.workspace)
        clearStreamTransientPresentation(for: owner)
        session.activeHostID = nil
        session.lastError = nil
        session.phase = .disconnected
        renderState.policy = .idle
        refreshMacInputSurfacePolicy()
    }

    func launchSelectedApp() async {
        await launchSelectedApp(in: primaryWorkspaceReference)
    }

    func launchSelectedApp(in workspace: ProductWorkspaceReference) async {
        guard let launchSelection = streamLaunchSelection(in: workspace) else {
            presentStreamIssue(.launchSelectionRequired, in: workspace)
            return
        }
        let host = launchSelection.host
        let app = launchSelection.app

        guard activeHostDestructiveOwner?.hostID != host.id else {
            return
        }

        guard activeProductSessionOwner == nil,
              activeStreamSessionID == nil,
              productSessionStopOperation == nil else {
            return
        }

        guard isStreamTransportAvailable,
              let sessionControlProvider = runtimeProviders.sessionControl else {
            let diagnostic = ApplicationDiagnosticFactory.streamUnavailable
            presentStreamIssue(.streamUnavailable, in: workspace)
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
            failStreamSession(
                contextualError,
                sessionID: nil,
                workspace: workspace
            )
            return
        }

        let sessionID = UUID()
        let owner = ProductSessionOwner(
            workspace: workspace,
            sessionID: sessionID
        )
        activeProductSessionOwner = owner
        activeStreamSessionID = sessionID
        productSessionActualPhase = .launching
        activeControlReadiness = []
        activeMediaReadiness = []
        clearStreamActionPresentation(in: workspace)
        setStreamOverlayVisibilityUnchecked(
            expectedTVVisionPlatform == .tvOS ? .visible : .hidden,
            for: owner
        )
        streamLaunchUI.isLaunching = true
        session.activeHostID = host.id
        session.lastError = nil
        if workspace == primaryWorkspaceReference {
            navigationSelection = .stream
        } else {
            _ = try? workspaceRegistry.update(workspace) {
                $0.navigationSelection = .stream
            }
        }
        var didStartProvider = false
        do {
            let snapshot = try await streamSessionCoordinator.prepare(
                request,
                sessionID: sessionID
            )
            guard productSessionLaunchIsCurrent(
                owner: owner,
                selection: launchSelection
            ) else {
                await invalidatePreparedProductSession(owner)
                return
            }
            applySessionSnapshot(snapshot)

            var receivedTerminalEvent = false
            let events = await sessionControlProvider.start(
                sessionID: sessionID,
                request: request
            )
            didStartProvider = true
            guard productSessionOwnerIsCurrent(owner) else {
                await stopStreamInternally(expectedOwner: owner)
                return
            }
            for try await event in events {
                guard productSessionOwnerIsCurrent(owner) else {
                    await stopStreamInternally(expectedOwner: owner)
                    return
                }
                try await consumeSessionControlEvent(
                    event,
                    owner: owner,
                    sessionControlProvider: sessionControlProvider
                )
                guard productSessionOwnerIsCurrent(owner) else {
                    await stopStreamInternally(expectedOwner: owner)
                    return
                }
                if case .terminated = event {
                    receivedTerminalEvent = true
                }
            }

            guard productSessionOwnerIsCurrent(owner) else { return }
            guard receivedTerminalEvent else {
                throw SessionApplicationError.incompleteControlStream
            }
            clearStreamTransientPresentation(for: owner)
            activeProductSessionOwner = nil
            activeStreamSessionID = nil
            streamLaunchUI.isLaunching = false
        } catch {
            guard activeProductSessionOwner == nil
                    || activeProductSessionOwner == owner else {
                return
            }
            guard activeProductSessionOwner == owner,
                  activeStreamSessionID == sessionID else {
                return
            }
            if !productSessionOwnerIsCurrent(owner),
               error is SessionApplicationError {
                await stopStreamInternally(expectedOwner: owner)
                return
            }
            await stopMediaEnvironment(sessionID: sessionID)
            _ = try? await streamSessionCoordinator.fail(
                error,
                sessionID: sessionID
            )
            failStreamSession(error, sessionID: sessionID)
            if didStartProvider {
                await sessionControlProvider.stop(sessionID: sessionID)
            }
        }
    }

    func stopStream() async {
        _ = await stopStream(in: primaryWorkspaceReference)
    }

    @discardableResult
    func stopStream(in workspace: ProductWorkspaceReference) async -> Bool {
        guard workspaceRegistry.state(for: workspace) != nil else {
            return false
        }
        if let operation = productSessionStopOperation,
           operation.owner.workspace == workspace {
            return await awaitProductSessionStopOperation(operation)
        }
        guard let owner = activeProductSessionOwner,
              owner.workspace == workspace,
              productSessionOwnerIsCurrent(owner) else {
            return false
        }
        return await stopStreamInternally(
            expectedOwner: owner,
            actionToken: currentStopActionToken(for: owner)
        )
    }

    @discardableResult
    private func stopStreamInternally(
        expectedOwner: ProductSessionOwner? = nil,
        actionToken: ProductActionToken? = nil
    ) async -> Bool {
        guard let operation = beginProductSessionStop(
            expectedOwner: expectedOwner,
            actionToken: actionToken
        ) else { return false }
        return await awaitProductSessionStopOperation(operation)
    }

    private func beginProductSessionStop(
        expectedOwner: ProductSessionOwner? = nil,
        actionToken: ProductActionToken? = nil
    ) -> ProductSessionStopOperation? {
        if let operation = productSessionStopOperation {
            guard expectedOwner == nil || expectedOwner == operation.owner else {
                return nil
            }
            return operation
        }
        guard let owner = activeProductSessionOwner,
              expectedOwner == nil || expectedOwner == owner,
              let sessionID = activeStreamSessionID,
              owner.sessionID == sessionID,
              let sessionControlProvider = runtimeProviders.sessionControl else {
            return nil
        }
        let operationID = UUID()
        let admittedActionToken = actionToken ?? currentStopActionToken(for: owner)
        let task = Task { [weak self] in
            guard let self else { return false }
            return await self.performProductSessionStop(
                owner: owner,
                sessionControlProvider: sessionControlProvider
            )
        }
        let operation = ProductSessionStopOperation(
            id: operationID,
            owner: owner,
            actionToken: admittedActionToken,
            task: task
        )
        productSessionStopOperation = operation
        return operation
    }

    private func awaitProductSessionStopOperation(
        _ operation: ProductSessionStopOperation
    ) async -> Bool {
        let result = await operation.task.value
        if productSessionStopOperation?.id == operation.id {
            productSessionStopOperation = nil
        }
        return result
    }

    private func currentStopActionToken(
        for owner: ProductSessionOwner
    ) -> ProductActionToken? {
        guard let token = workspaceRegistry.state(for: owner.workspace)?
            .presentation.issue?.action,
              token.kind == .stopStream,
              token.scope == .session(
                workspace: owner.workspace,
                sessionID: owner.sessionID
              ) else {
            return nil
        }
        return token
    }

    private func performProductSessionStop(
        owner: ProductSessionOwner,
        sessionControlProvider: any SessionControlProvider
    ) async -> Bool {
        let sessionID = owner.sessionID
        clearStreamActionPresentation(in: owner.workspace)
        clearStreamTransientPresentation(for: owner)
        productSessionActualPhase = .stopping
        let platformOwnsReleaseBarrier = await releasePlatformInputForTerminal(
            reason: .stopped
        )
        await terminateMacInputGeneration(
            reason: .stop,
            requiresReleaseBarrier: !platformOwnsReleaseBarrier
        )
        clearStreamTransientPresentation(for: owner)
        guard productSessionStopOperation?.owner == owner else {
            return false
        }
        if activeProductSessionOwner == owner,
           activeStreamSessionID == sessionID {
            activeProductSessionOwner = nil
            activeStreamSessionID = nil
        } else if activeProductSessionOwner != nil || activeStreamSessionID != nil {
            return false
        }
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
        productSessionActualPhase = .idle
        return true
    }

    func updateSpatialAudioPreferences(
        _ preferences: SessionSpatialAudioPreferences
    ) async throws {
        guard preferences != spatialAudioPreferences else { return }
        settings.audio = AudioPreferences(preferences)
        guard let owner = activeProductSessionOwner,
              productSessionOwnerIsCurrent(owner),
              let sessionID = activeStreamSessionID,
              activeMediaSessionID == sessionID,
              let mediaGeneration = activeMediaGeneration else {
            return
        }
        try await applySpatialAudioPreferences(
            preferences,
            owner: owner,
            mediaGeneration: mediaGeneration
        )
    }

    func sendRemoteInput(_ event: RemoteInputEvent) async throws {
        guard let owner = activeProductSessionOwner,
              productSessionOwnerIsCurrent(owner),
              let sessionID = activeStreamSessionID,
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
            let environmentOwnsGeneration = await mediaEnvironmentOwns(
                sessionID: sessionID,
                mediaGeneration: mediaGeneration
            )
            if environmentOwnsGeneration,
               productSessionOwnerIsCurrent(owner),
               activeStreamSessionID == sessionID,
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
            let environmentOwnsGeneration = await mediaEnvironmentOwns(
                sessionID: sessionID,
                mediaGeneration: mediaGeneration
            )
            if environmentOwnsGeneration,
               activeStreamSessionID == sessionID,
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

    private func cancelPairing(
        owner: ProductPairingOwner,
        showCancelledState: Bool
    ) async {
        guard activePairingOwner == owner else { return }
        let ownerWasCurrent = pairingOwnerIsCurrent(owner)
        activePairingOwner = nil
        if preparedPairingIdentity?.owner == owner {
            preparedPairingIdentity = nil
        }
        if case .pairing = session.phase {
            session.phase = .disconnected
        }

        if ownerWasCurrent {
            _ = try? workspaceRegistry.update(owner.workspace) { state in
                guard state.pairing.owner == owner else { return }
                if showCancelledState {
                    state.pairing = PairingUIState(
                        owner: owner,
                        stage: .cancelled,
                        message: "Pairing was cancelled.",
                        issue: ProductIssue(
                            code: .pairingCancelled,
                            actionScope: .pairing(owner)
                        )
                    )
                } else {
                    state.pairing = PairingUIState()
                }
            }
        }
        if showCancelledState {
            diagnostics.record("Cancelled pairing attempt", subsystem: "pairing")
        }

        if let provider = runtimeProviders.pairing {
            await provider.cancelPairing(
                attemptID: owner.attemptGeneration.rawValue
            )
        }
    }

    private func applyPairingCompletion(
        _ result: PairingResult,
        owner: ProductPairingOwner
    ) {
        guard pairingOwnerIsCurrent(owner) else { return }
        activePairingOwner = nil
        if preparedPairingIdentity?.owner == owner {
            preparedPairingIdentity = nil
        }
        if let index = hosts.firstIndex(where: { $0.id == result.host.id }) {
            hosts[index] = result.host
        } else {
            hosts.append(result.host)
        }
        reconcileSharedHostRepositoryState(
            trustChangedHostID: owner.hostID,
            preservingPairingOwner: owner
        )
        _ = try? workspaceRegistry.update(owner.workspace) { state in
            guard state.selectedHostID == owner.hostID,
                  state.hostSelectionGeneration == owner.hostSelectionGeneration,
                  state.pairing.owner == owner else { return }
            state.pairing = PairingUIState(
                owner: owner,
                stage: .paired,
                message: "Paired with \(result.host.name)."
            )
        }
        session.phase = .disconnected
        diagnostics.clearActionableEvents(in: [.pairing])
        diagnostics.record("Authenticated pairing completed", subsystem: "pairing")
    }

    private func failPairingAttempt(
        owner: ProductPairingOwner,
        diagnostic: ApplicationDiagnostic,
        issueCode: ProductIssueCode = .pairingFailed
    ) {
        guard pairingOwnerIsCurrent(owner) else { return }
        activePairingOwner = nil
        if preparedPairingIdentity?.owner == owner {
            preparedPairingIdentity = nil
        }
        _ = try? workspaceRegistry.update(owner.workspace) { state in
            guard state.pairing.owner == owner else { return }
            state.pairing = PairingUIState(
                owner: owner,
                stage: .failed,
                message: diagnostic.summary,
                actionMessage: diagnostic.action?.label,
                issue: ProductIssue(
                    code: issueCode,
                    actionScope: .pairing(owner)
                )
            )
        }
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

    private func applySessionSnapshot(
        _ snapshot: StreamSessionSnapshot,
        remoteTermination: Bool = false
    ) {
        guard let owner = activeProductSessionOwner,
              owner.sessionID == snapshot.sessionID,
              activeStreamSessionID == snapshot.sessionID,
              productSessionStopOperation?.owner != owner else {
            return
        }
        defer {
            refreshMacInputSurfacePolicy()
            refreshHDRRenderResolution()
        }
        switch snapshot.stage {
        case .idle, .disconnected:
            productSessionActualPhase = remoteTermination
                ? .remoteTerminated
                : .idle
            clearActiveVideoPresentation()
            clearActiveAudioRuntime()
            activeProductSessionOwner = nil
            activeStreamSessionID = nil
            activeControlReadiness = []
            activeMediaReadiness = []
            streamLaunchUI.isLaunching = false
            clearStreamActionPresentation(in: owner.workspace)
            clearStreamTransientPresentation(for: owner)
            session.activeHostID = nil
            session.lastError = nil
            session.phase = .disconnected
            renderState.policy = .idle
            if remoteTermination {
                presentStreamIssue(
                    .streamTerminated,
                    in: owner.workspace,
                    sessionID: owner.sessionID
                )
            }
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
            productSessionActualPhase = .launching
            session.phase = .connecting(stage: "Launching Stream")
            renderState.policy = .idle

        case .readyForTransport:
            productSessionActualPhase = .waitingForTransport
            session.phase = .connecting(stage: pendingTransportMessage(for: snapshot))
            renderState.policy = .idle

        case .streaming:
            productSessionActualPhase = .streaming
            diagnostics.clearActionableEvents(in: [.transport])
            clearStreamIssue(in: owner.workspace)
            streamLaunchUI.isLaunching = false
            session.phase = .streaming
            renderState.policy = hasPlatformLifecycle
                ? latestLifecycleDirective.renderPolicy
                : .active
            updateRenderPreferences()

        case .reconnecting:
            productSessionActualPhase = .reconnecting(
                attempt: snapshot.reconnectAttempt
            )
            clearActiveAudioRuntime()
            streamLaunchUI.isLaunching = false
            presentStreamIssue(
                .streamInterrupted,
                in: owner.workspace,
                sessionID: owner.sessionID
            )
            let suffix = snapshot.reconnectAttempt.map { " (Attempt \($0))" } ?? ""
            session.phase = .connecting(stage: "Reconnecting\(suffix)")
            renderState.policy = .idle

        case .stopping:
            productSessionActualPhase = .stopping
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
        owner: ProductSessionOwner,
        sessionControlProvider: any SessionControlProvider
    ) async throws {
        guard productSessionOwnerIsCurrent(owner) else {
            throw SessionApplicationError.staleProductSessionOwner
        }
        let sessionID = owner.sessionID
        switch event {
        case let .channelsReady(reportedReadiness):
            activeControlReadiness = reportedReadiness.intersection(.control)
            try await applyAggregatedReadiness(owner: owner)

        case let .negotiated(configuration):
            let snapshot = try await streamSessionCoordinator.apply(
                event,
                sessionID: sessionID
            )
            guard productSessionOwnerIsCurrent(owner) else {
                throw SessionApplicationError.staleProductSessionOwner
            }
            applySessionSnapshot(snapshot)
            _ = try await startMediaEnvironment(
                owner: owner,
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
            guard productSessionOwnerIsCurrent(owner) else {
                throw SessionApplicationError.staleProductSessionOwner
            }
            applySessionSnapshot(snapshot)
            await stopMediaEnvironment(
                sessionID: sessionID,
                inputReason: .replacement
            )
            guard productSessionOwnerIsCurrent(owner) else {
                throw SessionApplicationError.staleProductSessionOwner
            }

        case let .videoColorMetadata(metadata):
            let snapshot = try await streamSessionCoordinator.apply(
                event,
                sessionID: sessionID
            )
            guard productSessionOwnerIsCurrent(owner) else {
                throw SessionApplicationError.staleProductSessionOwner
            }
            applySessionSnapshot(snapshot)
            if activeMediaSessionID == sessionID {
                updateNegotiatedVideoColorMetadata(metadata)
                try await sessionMediaEnvironment.updateVideoColorMetadata(
                    metadata,
                    sessionID: sessionID
                )
                guard productSessionOwnerIsCurrent(owner) else {
                    throw SessionApplicationError.staleProductSessionOwner
                }
            }

        case .terminated:
            let snapshot = try await streamSessionCoordinator.apply(
                event,
                sessionID: sessionID
            )
            guard productSessionOwnerIsCurrent(owner) else {
                throw SessionApplicationError.staleProductSessionOwner
            }
            guard productSessionStopOperation?.owner != owner else { return }
            applySessionSnapshot(snapshot, remoteTermination: true)
            await stopMediaEnvironment(
                sessionID: sessionID,
                inputReason: .remoteTermination
            )

        case .launchAccepted, .rtspReady:
            let snapshot = try await streamSessionCoordinator.apply(
                event,
                sessionID: sessionID
            )
            guard productSessionOwnerIsCurrent(owner) else {
                throw SessionApplicationError.staleProductSessionOwner
            }
            applySessionSnapshot(snapshot)
        }
    }

    private func startMediaEnvironment(
        owner: ProductSessionOwner,
        configuration: NegotiatedSessionConfiguration,
        sessionControlProvider: any SessionControlProvider
    ) async throws -> Bool {
        let sessionID = owner.sessionID
        guard productSessionOwnerIsCurrent(owner) else {
            throw SessionApplicationError.staleProductSessionOwner
        }
        guard activeMediaSessionID == nil else {
            throw SessionMediaEnvironmentError.sessionAlreadyActive
        }
        let events = try await sessionMediaEnvironment.start(
            sessionID: sessionID,
            configuration: configuration,
            controlProvider: sessionControlProvider
        )
        guard productSessionOwnerIsCurrent(owner) else {
            clearTVVisionPlatformPresentationRuntime()
            _ = await sessionMediaEnvironment.stop(sessionID: sessionID)
            return false
        }
        let environmentSnapshot = await sessionMediaEnvironment.snapshot()
        guard productSessionOwnerIsCurrent(owner),
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
        let consumerTask = Task { [weak self] in
            do {
                for try await event in events {
                    try Task.checkCancellation()
                    guard let self else { return }
                    await self.consumeMediaEnvironmentEvent(
                        event,
                        owner: owner,
                        sessionControlProvider: sessionControlProvider
                    )
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self else { return }
                await self.failFromMediaEnvironment(
                    error,
                    owner: owner,
                    sessionControlProvider: sessionControlProvider
                )
            }
        }
        mediaConsumerTask = consumerTask
        beginTVVisionPlatformPresentationRuntime()
#if os(iOS)
        beginMobileRuntime(mediaGeneration: environmentSnapshot.generation)
#endif
        if let audioRuntime = environmentSnapshot.audioRuntime {
            applyAudioRuntimeState(audioRuntime, sessionID: sessionID)
        }
        do {
            try await applySpatialAudioPreferences(
                spatialAudioPreferences,
                owner: owner,
                mediaGeneration: environmentSnapshot.generation
            )
        } catch {
            if await mediaTerminalOwnsSecondaryApplicationFailure(
                error,
                owner: owner,
                mediaGeneration: environmentSnapshot.generation,
                consumerTask: consumerTask
            ) {
                return false
            }
            throw error
        }
        beginVideoPresentation(
            negotiatedColorMetadata: configuration.video.colorMetadata,
            negotiatedFramesPerSecond: configuration.video.frameRate
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
        guard productSessionOwnerIsCurrent(owner),
              activeMediaSessionID == sessionID,
              activeMediaGeneration == environmentSnapshot.generation else {
            return false
        }
        return true
    }

    private func mediaTerminalOwnsSecondaryApplicationFailure(
        _ error: Error,
        owner: ProductSessionOwner,
        mediaGeneration: UInt64,
        consumerTask: Task<Void, Never>? = nil
    ) async -> Bool {
        guard let applicationError = error as? SessionMediaEnvironmentError,
              applicationError == .inactiveSession
                || applicationError == .staleLifecycleApplication
                || applicationError == .staleAudioApplication else {
            return false
        }
        guard !(await mediaEnvironmentOwns(
            sessionID: owner.sessionID,
            mediaGeneration: mediaGeneration
        )) else {
            return false
        }

        let terminalConsumer = consumerTask ?? mediaConsumerTask
        await terminalConsumer?.value
        return !productSessionOwnerIsCurrent(owner)
            || activeMediaSessionID != owner.sessionID
            || activeMediaGeneration != mediaGeneration
    }

    private func mediaEnvironmentOwns(
        sessionID: UUID,
        mediaGeneration: UInt64
    ) async -> Bool {
        let snapshot = await sessionMediaEnvironment.snapshot()
        return snapshot.sessionID == sessionID
            && snapshot.generation == mediaGeneration
    }

    private func consumeMediaEnvironmentEvent(
        _ event: SessionMediaEnvironmentEvent,
        owner: ProductSessionOwner,
        sessionControlProvider: any SessionControlProvider
    ) async {
        let sessionID = owner.sessionID
        guard productSessionOwnerOwnsActiveReservation(owner),
              activeMediaSessionID == sessionID else { return }
        guard productSessionOwnerIsCurrent(owner) else {
            _ = await stopStreamInternally(expectedOwner: owner)
            return
        }
        switch event {
        case let .readiness(readiness):
            let previousReadiness = activeMediaReadiness
            activeMediaReadiness = readiness.intersection([.video, .audio, .input])
            refreshHDRRenderResolution()
            if previousReadiness.contains(.input),
               !activeMediaReadiness.contains(.input) {
                let platformOwnsReleaseBarrier =
                    await releasePlatformInputForTerminal(
                        reason: .inputUnavailable
                    )
                await terminateMacInputGeneration(
                    reason: .inputChannelFailure,
                    requiresReleaseBarrier: !platformOwnsReleaseBarrier
                )
            } else if activeMediaReadiness.contains(.input) {
                await activateMacInputGenerationIfNeeded()
            }
            if expectedTVVisionPlatform == .visionOS,
               let admission = tvVisionPlatformGeometryAdmission {
                updateVisionInputRuntimeTarget(
                    update: admission.update,
                    ownership: admission.ownership
                )
                await visionInputReconciliationTask?.value
            }
            refreshTVRemoteSurfacePressOwnership()
            do {
                try await applyAggregatedReadiness(owner: owner)
            } catch {
                await failFromMediaEnvironment(
                    error,
                    owner: owner,
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
        owner: ProductSessionOwner,
        mediaGeneration: UInt64
    ) async throws {
        let sessionID = owner.sessionID
        guard productSessionOwnerIsCurrent(owner) else {
            throw SessionMediaEnvironmentError.staleAudioApplication
        }
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
            guard productSessionOwnerIsCurrent(owner),
                  activeMediaSessionID == sessionID,
                  activeMediaGeneration == mediaGeneration else {
                throw SessionMediaEnvironmentError.staleAudioApplication
            }
            throw error
        }
        guard productSessionOwnerIsCurrent(owner),
              activeMediaSessionID == sessionID,
              activeMediaGeneration == mediaGeneration else {
            throw SessionMediaEnvironmentError.staleAudioApplication
        }
    }

    private func applyAudioRuntimeState(
        _ state: SessionMediaAudioRuntimeState,
        sessionID: UUID
    ) {
        guard let owner = activeProductSessionOwner,
              productSessionOwnerIsCurrent(owner),
              activeStreamSessionID == sessionID,
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

    private func applyAggregatedReadiness(
        owner: ProductSessionOwner
    ) async throws {
        guard productSessionOwnerIsCurrent(owner) else {
            throw SessionApplicationError.staleProductSessionOwner
        }
        let sessionID = owner.sessionID
        let snapshot = try await streamSessionCoordinator.apply(
            .channelsReady(activeControlReadiness.union(activeMediaReadiness)),
            sessionID: sessionID
        )
        guard productSessionOwnerIsCurrent(owner) else {
            throw SessionApplicationError.staleProductSessionOwner
        }
        applySessionSnapshot(snapshot)
    }

    private func failFromMediaEnvironment(
        _ error: Error,
        owner: ProductSessionOwner,
        sessionControlProvider: any SessionControlProvider
    ) async {
        let sessionID = owner.sessionID
        guard productSessionStopOperation?.owner != owner else { return }
        guard productSessionOwnerOwnsActiveReservation(owner) else { return }
        guard productSessionOwnerIsCurrent(owner) else {
            _ = await stopStreamInternally(expectedOwner: owner)
            return
        }
        let platformOwnsReleaseBarrier = await releasePlatformInputForTerminal(
            reason: .inputUnavailable
        )
        await terminateMacInputGeneration(
            reason: .inputChannelFailure,
            requiresReleaseBarrier: !platformOwnsReleaseBarrier
        )
        guard productSessionStopOperation?.owner != owner else { return }
        guard productSessionOwnerOwnsActiveReservation(owner) else { return }
        guard productSessionOwnerIsCurrent(owner) else {
            _ = await stopStreamInternally(expectedOwner: owner)
            return
        }
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
        let platformOwnsReleaseBarrier = await releasePlatformInputForTerminal(
            reason: visionInputRestoreReason(for: inputReason)
        )
        await terminateMacInputGeneration(
            reason: inputReason,
            requiresReleaseBarrier: !platformOwnsReleaseBarrier
        )
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
        guard let owner = activeProductSessionOwner,
              productSessionOwnerIsCurrent(owner),
              activeStreamSessionID != nil,
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
              let owner = activeProductSessionOwner,
              productSessionOwnerIsCurrent(owner),
              let sessionID = activeStreamSessionID,
              owner.sessionID == sessionID,
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
                      productSessionOwnerIsCurrent(owner),
                      activeStreamSessionID == sessionID,
                      activeMediaSessionID == sessionID,
                      activeMediaGeneration == mediaGeneration else {
                    break
                }
                if error as? SessionMediaEnvironmentError == .staleLifecycleApplication,
                   latestLifecycleRevision > application.lifecycleRevision {
                    continue
                }
                if await mediaTerminalOwnsSecondaryApplicationFailure(
                    error,
                    owner: owner,
                    mediaGeneration: mediaGeneration
                ) {
                    break
                }
                if let sessionControlProvider = runtimeProviders.sessionControl {
                    await failFromMediaEnvironment(
                        error,
                        owner: owner,
                        sessionControlProvider: sessionControlProvider
                    )
                }
                break
            }

            guard !Task.isCancelled,
                  lifecycleApplicationOperationID == operationID,
                  productSessionOwnerIsCurrent(owner),
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
        guard let owner = activeProductSessionOwner,
              productSessionOwnerIsCurrent(owner),
              activeMacInputGeneration == nil,
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
        guard productSessionOwnerIsCurrent(owner),
              activeStreamSessionID == sessionID,
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
        reason: MacSessionInputTerminationReason,
        requiresReleaseBarrier: Bool = true
    ) async {
        guard let generation = activeMacInputGeneration else { return }
        activeMacInputGeneration = nil
        isMacInputGenerationFailed = false
        refreshMacInputSurfacePolicy()
        _ = await macSessionInputCoordinator.terminate(
            generation: generation,
            reason: reason,
            requiresReleaseBarrier: requiresReleaseBarrier
        )
    }

    private func applyInputLifecycle(_ directive: InputLifecycleDirective) {
        guard let generation = activeMacInputGeneration else { return }
        let ownerAllowsInput = activeProductSessionOwner.map {
            productSessionOwnerIsCurrent($0)
                && !streamOverlayIsRequestedVisible(in: $0.workspace)
        } ?? false
        switch (directive, ownerAllowsInput) {
        case (.open, true):
            _ = macSessionInputCoordinator.setFocusEligible(
                true,
                generation: generation
            )
        case (.open, false), (.closed, _):
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

    private func failStreamSession(
        _ error: Error,
        sessionID: UUID?,
        workspace: ProductWorkspaceReference? = nil
    ) {
        if let sessionID,
           activeStreamSessionID != nil,
           activeStreamSessionID != sessionID {
            return
        }
        if let sessionID,
           activeProductSessionOwner != nil,
           activeProductSessionOwner?.sessionID != sessionID {
            return
        }

        let errorType = String(reflecting: type(of: error))
        logger.error("Stream failed with type \(errorType, privacy: .public)")

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
        let issueOwner = activeProductSessionOwner
        let issueWorkspace = issueOwner?.workspace ?? workspace

        if let issueOwner {
            clearStreamTransientPresentation(for: issueOwner)
        }

        activeProductSessionOwner = nil
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
        session.activeHostID = nil
        session.lastError = sessionError
        session.phase = .failed(sessionError)
        renderState.policy = .idle
        if let failure = error as? StreamNegotiationFailure,
           failure.code == .reconnectExhausted {
            productSessionActualPhase = .reconnectExhausted
        } else {
            productSessionActualPhase = .failed
        }
        if let issueWorkspace {
            presentStreamIssue(
                productIssueCode(for: error, diagnostic: diagnostic),
                in: issueWorkspace,
                sessionID: issueOwner?.sessionID
            )
        }
        refreshMacInputSurfacePolicy()
        diagnostics.record(diagnostic)
    }

    private func productIssueCode(
        for error: Error,
        diagnostic: ApplicationDiagnostic
    ) -> ProductIssueCode {
        if let failure = error as? StreamNegotiationFailure {
            switch failure.code {
            case .hostNotPaired:
                return .streamRequiresPairing
            case .invalidResolution, .invalidBitrate:
                return .streamSettingsInvalid
            case .reconnectExhausted:
                return .reconnectExhausted
            case .invalidInputKey, .reconnectKeyGenerationFailed:
                return .inputUnavailable
            case .missingHostAddress, .launchRejected, .resumeRejected,
                 .cancelRejected, .transportUnavailable, .invalidTransition:
                return .streamInterrupted
            }
        }
        if let failure = error as? SessionMediaEnvironmentError,
           case .missingProvider = failure {
            return .streamUnavailable
        }
        return ProductIssueFailureMapper.code(for: diagnostic)
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
            && (activeProductSessionOwner.map {
                productSessionOwnerIsCurrent($0)
            } ?? false)
            && lifecycleAllowsInput
            && (activeProductSessionOwner.map {
                !streamOverlayIsRequestedVisible(in: $0.workspace)
            } ?? false)
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
            forwardsSystemShortcuts: false
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

    private var isTVVisionInputReleasePending: Bool {
        isTVRemoteInputReleasePending || visionInputReleasePending
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
                if let owner = activeProductSessionOwner,
                   productSessionOwnerIsCurrent(owner) {
                    _ = try? workspaceRegistry.update(owner.workspace) {
                        $0.presentation.streamOverlay = .visible
                    }
                }
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
#if os(tvOS) || os(visionOS)
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
        inputGeneration: TVVisionGeneration,
        platform: TVVisionPlatform = .tvOS
    ) throws {
#if os(tvOS) || os(visionOS)
        guard tvGameControllerRuntimeOwner == nil else { return }
        let controllerOwner = TVGameControllerRuntimeOwner()
        tvGameControllerRuntimeOwner = controllerOwner
        do {
            try controllerOwner.start(
                inputGeneration: inputGeneration,
                platform: platform,
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
        _ = (inputGeneration, platform)
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

    private func releasePlatformInputForTerminal(
        reason: TVVisionFocusIneligibilityReason
    ) async -> Bool {
        switch expectedTVVisionPlatform {
        case .tvOS:
            await releaseTVRemoteInputForTerminal()
            return true
        case .visionOS:
            requestVisionInputTerminalRelease(reason: reason)
            await visionInputReconciliationTask?.value
            return true
        case nil:
            return false
        }
    }

    private func beginTVVisionPlatformPresentationRuntime() {
        clearTVVisionPlatformPresentationRuntime()
        if expectedTVVisionPlatform == .visionOS {
            visionInputTerminalReleaseRequested = false
            visionLocalNavigationRestoreReason = nil
            visionInputReleaseEffects = []
            return
        }
        guard expectedTVVisionPlatform == .tvOS else { return }
        tvRemoteReservedCommandState = .idle
        let overlayVisible = activeProductSessionOwner.map {
            streamOverlayIsRequestedVisible(in: $0.workspace)
        } ?? true
        applyTVRemoteFocusHandoffState(
            tvRemoteFocusHandoffState.settingOverlayVisible(
                overlayVisible,
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
                if let input = self.makeControllerInputSnapshot(
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
                    if ownership.platform == .tvOS {
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
                _ = await self.releasePlatformInputForTerminal(
                    reason: .inputUnavailable
                )
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
        guard !isTVVisionInputReleasePending,
              let admission = tvVisionPlatformGeometryAdmission,
              admission.update.binding != nil,
              admission.ownership.platform == expectedTVVisionPlatform,
              admission.ownership.inputGeneration == roster.inputGeneration,
              let input = makeControllerInputSnapshot(
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
                  self.makeControllerInputSnapshot(
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

    private func scheduleTVVisionDisplayHDRApplication(
        _ snapshot: TVVisionDisplaySnapshot,
        admission: TVVisionPlatformGeometryAdmission
    ) {
        let geometryTask = tvVisionPlatformApplicationTask
        let previous = tvVisionDisplayHDRApplicationTask
        let operationID = UUID()
        tvVisionDisplayHDRApplicationOperationID = operationID
        tvVisionDisplayHDRApplicationTask = Task { [weak self] in
            await previous?.value
            await geometryTask?.value
            guard !Task.isCancelled,
                  let self,
                  self.tvVisionDisplayHDRApplicationOperationID == operationID,
                  self.tvVisionDisplayHDRSourceSnapshot == snapshot,
                  self.tvVisionPlatformGeometryAdmission == admission,
                  self.tvVisionPlatformPresentationOwnership
                    == admission.ownership,
                  self.activeStreamSessionID == admission.ownership.sessionID,
                  self.activeMediaSessionID == admission.ownership.sessionID,
                  self.activeMediaGeneration
                    == admission.ownership.mediaGeneration else { return }
            do {
                try await self.sessionMediaEnvironment
                    .applyTVVisionPlatformPresentation(
                        SessionTVVisionPlatformPresentationApplication(
                            ownership: admission.ownership,
                            action: .display(snapshot)
                        )
                    )
            } catch {
                guard !Task.isCancelled,
                      self.tvVisionDisplayHDRApplicationOperationID == operationID,
                      self.tvVisionDisplayHDRSourceSnapshot == snapshot,
                      self.tvVisionPlatformGeometryAdmission == admission,
                      self.tvVisionPlatformPresentationOwnership
                        == admission.ownership else { return }
                self.tvVisionDisplayHDRSourceSnapshot = nil
                self.tvVisionDisplayHDRFallbackReason = nil
                self.renderState.displaySnapshot = nil
                self.renderState.headroom = DisplayHeadroom()
                self.refreshHDRRenderResolution()
                _ = try? await self.sessionMediaEnvironment
                    .applyTVVisionPlatformPresentation(
                        SessionTVVisionPlatformPresentationApplication(
                            ownership: admission.ownership,
                            action: .fail(.actionFailed(.display))
                        )
                    )
            }
            if self.tvVisionDisplayHDRApplicationOperationID == operationID {
                self.tvVisionDisplayHDRApplicationTask = nil
                self.tvVisionDisplayHDRApplicationOperationID = nil
            }
        }
    }

    private func scheduleTVVisionDisplayHDRFailure(
        _ failure: TVVisionPlatformPresentationFailure,
        admission: TVVisionPlatformGeometryAdmission
    ) {
        let geometryTask = tvVisionPlatformApplicationTask
        let previous = tvVisionDisplayHDRApplicationTask
        previous?.cancel()
        let operationID = UUID()
        tvVisionDisplayHDRApplicationOperationID = operationID
        tvVisionDisplayHDRApplicationTask = Task { [weak self] in
            await previous?.value
            await geometryTask?.value
            guard !Task.isCancelled,
                  let self,
                  self.tvVisionDisplayHDRApplicationOperationID == operationID,
                  self.isTVVisionDisplayHDRRevisionExhausted,
                  self.tvVisionPlatformGeometryAdmission == admission,
                  self.tvVisionPlatformPresentationOwnership
                    == admission.ownership,
                  self.activeStreamSessionID == admission.ownership.sessionID,
                  self.activeMediaSessionID == admission.ownership.sessionID,
                  self.activeMediaGeneration
                    == admission.ownership.mediaGeneration else { return }
            _ = try? await self.sessionMediaEnvironment
                .applyTVVisionPlatformPresentation(
                    SessionTVVisionPlatformPresentationApplication(
                        ownership: admission.ownership,
                        action: .fail(failure)
                    )
                )
            if self.tvVisionDisplayHDRApplicationOperationID == operationID {
                self.tvVisionDisplayHDRApplicationTask = nil
                self.tvVisionDisplayHDRApplicationOperationID = nil
            }
        }
    }

    private func scheduleTVGameControllerRouting(
        _ roster: TVControllerRosterSnapshot
    ) {
        guard activeMediaGeneration == roster.inputGeneration.rawValue,
              !isTVVisionInputReleasePending,
              currentControllerInputSnapshot?.focusEligibility == .eligible,
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
                  !self.isTVVisionInputReleasePending,
                  self.currentControllerInputSnapshot?.focusEligibility
                    == .eligible else { return }
            let event = TVGameControllerRosterRouter.reconcile(
                previous: self.tvControllerRoutedRosterState,
                current: roster
            )
            do {
                try await self.sendRemoteInput(.controllerRoster(event))
                guard !Task.isCancelled,
                      self.activeMediaGeneration
                        == roster.inputGeneration.rawValue,
                      !self.isTVVisionInputReleasePending,
                      self.currentControllerInputSnapshot?.focusEligibility
                        == .eligible else { return }
                self.tvControllerRoutedRosterState = roster
            } catch {
                if self.expectedTVVisionPlatform == .visionOS {
                    self.requestVisionInputTerminalRelease(
                        reason: .inputUnavailable
                    )
                }
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
                      !self.isTVVisionInputReleasePending,
                      self.tvControllerRosterState?.controllers.contains(where: {
                          $0.lease == sample.lease
                      }) == true,
                      self.currentControllerInputSnapshot?.focusEligibility
                        == .eligible else { continue }
                do {
                    try await self.sendRemoteInput(sample.remoteEvent)
                } catch {
                    self.tvPendingControllerMotionSamples.removeAll()
                    if self.expectedTVVisionPlatform == .visionOS {
                        self.requestVisionInputTerminalRelease(
                            reason: .inputUnavailable
                        )
                    }
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
        guard let owner = activeProductSessionOwner,
              productSessionOwnerIsCurrent(owner),
              state.sessionID == sessionID,
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
        publishTVVisionPlatformDiagnostic(snapshot)
        tvVisionPlatformPresentationState = state
        applyTVVisionDisplayHDRState(snapshot)
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
        clearTVVisionPlatformDiagnostics()
        visionSystemInteractionDecisionState = nil
        visionInputRuntimeTarget = nil
        visionInputReconciliationTask?.cancel()
        visionInputReconciliationTask = nil
        visionInputReconciliationOperationID = nil
        visionInputPendingReleaseScope = nil
        visionInputPendingRestoreReason = nil
        visionInputOwnershipState = nil
        visionInputReleasePending = false
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
        clearTVVisionDisplayHDRState(cancelApplication: true)
        tvControllerRosterApplicationTask?.cancel()
        tvControllerRosterApplicationTask = nil
        tvControllerRosterApplicationOperationID = nil
        tvControllerRoutingTask?.cancel()
        tvControllerRoutingTask = nil
        tvControllerRoutingOperationID = nil
        tvControllerMotionDeliveryTask?.cancel()
        tvControllerMotionDeliveryTask = nil
        tvPendingControllerMotionSamples.removeAll()
        visionInputDeliveryTask?.cancel()
        visionInputDeliveryTask = nil
        tvRemoteInputReleasePending = false
        tvVisionPlatformGeometryAdmission = nil
        tvRemoteSurfacePressCaptureOwner?.invalidate()
        tvRemoteSurfacePressCaptureOwner = nil
        tvControllerRosterState = nil
        tvControllerRoutedRosterState = nil
        tvControllerFeedbackDecisionState = nil
#if os(tvOS) || os(visionOS)
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

    private func publishTVVisionPlatformDiagnostic(
        _ snapshot: TVVisionPlatformPresentationCoordinatorSnapshot
    ) {
        if tvVisionPlatformDiagnosticOwnership != snapshot.ownership
            || tvVisionPlatformDiagnosticLease == nil {
            if let lease = tvVisionPlatformDiagnosticLease {
                diagnostics.endTVVisionPlatformDiagnosticOwnership(lease)
            }
            tvVisionPlatformDiagnosticOwnership = snapshot.ownership
            tvVisionPlatformDiagnosticLease = diagnostics
                .beginTVVisionPlatformDiagnosticOwnership()
        }
        guard let lease = tvVisionPlatformDiagnosticLease else { return }
        diagnostics.record(
            tvVisionPlatform: TVVisionPlatformDiagnosticValue(snapshot: snapshot),
            owner: lease
        )
    }

    private func clearTVVisionPlatformDiagnostics() {
        if let lease = tvVisionPlatformDiagnosticLease {
            diagnostics.endTVVisionPlatformDiagnosticOwnership(lease)
        }
        tvVisionPlatformDiagnosticLease = nil
        tvVisionPlatformDiagnosticOwnership = nil
    }

    private func applyTVVisionDisplayHDRState(
        _ snapshot: TVVisionPlatformPresentationCoordinatorSnapshot
    ) {
        guard expectedTVVisionPlatform != nil else { return }
        guard !isTVVisionDisplayHDRRevisionExhausted,
              snapshot.phase == .active,
              let display = snapshot.display,
              let source = tvVisionDisplayHDRSourceSnapshot,
              displayMatchesTVVisionDisplayHDRSource(
                display,
                source: source
              ) else {
            renderState.displaySnapshot = nil
            renderState.headroom = DisplayHeadroom()
            renderState.isDisplayRevisionExhausted =
                isTVVisionDisplayHDRRevisionExhausted
                    || snapshot.isSemanticRevisionExhausted
            tvVisionDisplayHDRFallbackReason = nil
            refreshHDRRenderResolution()
            return
        }
        let renderSnapshot = display.hdrRenderSnapshot
        renderState.displaySnapshot = renderSnapshot
        renderState.headroom = renderSnapshot?.headroom ?? DisplayHeadroom()
        renderState.isDisplayRevisionExhausted =
            isTVVisionDisplayHDRRevisionExhausted
                || snapshot.isSemanticRevisionExhausted
        tvVisionDisplayHDRFallbackReason =
            display.displayHDRCapabilityResolution?.fallbackReason
        refreshHDRRenderResolution()
    }

    private func displayMatchesTVVisionDisplayHDRSource(
        _ display: TVVisionDisplaySnapshot,
        source: TVVisionDisplaySnapshot
    ) -> Bool {
        display.platform == source.platform
            && display.displayGeneration == source.displayGeneration
            && display.isOutputAvailable == source.isOutputAvailable
            && display.headroomSource == source.headroomSource
            && display.currentEDRHeadroom == source.currentEDRHeadroom
            && display.potentialEDRHeadroom == source.potentialEDRHeadroom
            && display.layerCapability == source.layerCapability
            && display.displayHDRCapabilityResolution
                == source.displayHDRCapabilityResolution
    }

    private func clearTVVisionDisplayHDRState(
        cancelApplication: Bool
    ) {
        if cancelApplication {
            tvVisionDisplayHDRApplicationTask?.cancel()
            tvVisionDisplayHDRApplicationTask = nil
            tvVisionDisplayHDRApplicationOperationID = nil
        }
        tvVisionDisplayHDRSourceSnapshot = nil
        isTVVisionDisplayHDRRevisionExhausted = false
        tvVisionDisplayHDRFallbackReason = nil
        guard expectedTVVisionPlatform != nil else { return }
        renderState.displaySnapshot = nil
        renderState.headroom = DisplayHeadroom()
        renderState.isDisplayRevisionExhausted = false
        refreshHDRRenderResolution()
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

    private var currentControllerInputSnapshot:
        TVVisionInputCapabilitySnapshot? {
        switch expectedTVVisionPlatform {
        case .tvOS:
            currentTVRemoteInputSnapshot
        case .visionOS:
            currentVisionWindowInputSnapshot?.inputCapabilities
        case nil:
            nil
        }
    }

    private func makeControllerInputSnapshot(
        update: TVVisionStreamGeometryBindingUpdate,
        ownership: TVVisionPresentationOwnership
    ) -> TVVisionInputCapabilitySnapshot? {
        switch ownership.platform {
        case .tvOS:
            makeTVRemoteInputSnapshot(update: update, ownership: ownership)
        case .visionOS:
            makeVisionWindowInputSnapshot(
                update: update,
                ownership: ownership
            )?.inputCapabilities
        }
    }

    private var currentVisionWindowInputSnapshot: VisionWindowInputSnapshot? {
        guard let admission = tvVisionPlatformGeometryAdmission else {
            return nil
        }
        return makeVisionWindowInputSnapshot(
            update: admission.update,
            ownership: admission.ownership
        )
    }

    private func makeVisionWindowInputSnapshot(
        update: TVVisionStreamGeometryBindingUpdate,
        ownership: TVVisionPresentationOwnership
    ) -> VisionWindowInputSnapshot? {
        guard ownership.platform == .visionOS,
              update.platform == .visionOS,
              ownership.inputGeneration.domain == .input,
              let binding = update.binding else { return nil }
        let eligibility: TVVisionFocusEligibility
        if !activeMediaReadiness.contains(.input) {
            eligibility = .ineligible(.inputUnavailable)
        } else if binding.sceneSurfaceSnapshot.activity != .active {
            eligibility = .ineligible(.sceneInactive)
        } else if let owner = activeProductSessionOwner,
                  productSessionOwnerIsCurrent(owner),
                  streamOverlayIsRequestedVisible(in: owner.workspace) {
            eligibility = .ineligible(.overlayVisible)
        } else if !binding.sceneSurfaceSnapshot.isVisible
                    || !binding.isFocusEligible {
            eligibility = .ineligible(.notFocused)
        } else {
            eligibility = .eligible
        }
        guard let presentation = try? VisionWindowedPresentationState.windowedOnly(
                ownership: ownership,
                revision: update.revision,
                surfaceGeneration: update.surfaceGeneration
              ),
              let input = try? TVVisionInputCapabilitySnapshot(
                platform: .visionOS,
                revision: update.revision,
                inputGeneration: ownership.inputGeneration,
                supported: [
                    .extendedGamepad,
                    .microGamepad,
                    .keyboard,
                    .pointer,
                    .indirectPointer
                ],
                focusEligibility: eligibility
              ) else { return nil }
        return try? VisionWindowInputSnapshot(
            presentation: presentation,
            sceneSurface: binding.sceneSurfaceSnapshot,
            inputCapabilities: input
        )
    }

    private func updateVisionInputRuntimeTarget(
        update: TVVisionStreamGeometryBindingUpdate,
        ownership: TVVisionPresentationOwnership
    ) {
        guard expectedTVVisionPlatform == .visionOS,
              !visionInputTerminalReleaseRequested else { return }
        if let snapshot = makeVisionWindowInputSnapshot(
            update: update,
            ownership: ownership
        ), snapshot.inputCapabilities.focusEligibility == .eligible {
            let nextState = VisionWindowInputOwnershipState(snapshot: snapshot)
            if let current = visionInputOwnershipState,
               current.phase == .active,
               current != nextState {
                markVisionInputReleaseRequired(
                    scope: .teardown,
                    reason: .replacing
                )
            }
            visionInputRuntimeTarget = .active(snapshot)
        } else {
            let reason = visionInputRestoreReason(
                update: update,
                ownership: ownership
            )
            if visionInputOwnershipState?.phase == .active {
                markVisionInputReleaseRequired(
                    scope: .focusLoss,
                    reason: reason
                )
            }
            visionInputRuntimeTarget = .released(
                scope: .focusLoss,
                reason: reason
            )
        }
        scheduleVisionInputReconciliation()
    }

    private func visionInputRestoreReason(
        update: TVVisionStreamGeometryBindingUpdate,
        ownership: TVVisionPresentationOwnership
    ) -> TVVisionFocusIneligibilityReason {
        guard activeMediaReadiness.contains(.input) else {
            return .inputUnavailable
        }
        guard let binding = update.binding else { return .detached }
        guard binding.sceneSurfaceSnapshot.activity == .active else {
            return .sceneInactive
        }
        guard binding.sceneSurfaceSnapshot.isVisible,
              binding.isFocusEligible else {
            return .notFocused
        }
        guard ownership == tvVisionPlatformGeometryAdmission?.ownership else {
            return .replacing
        }
        return .inputUnavailable
    }

    private func markVisionInputReleaseRequired(
        scope: VisionInputReleaseScope,
        reason: TVVisionFocusIneligibilityReason
    ) {
        visionInputReleasePending = true
        if visionInputPendingReleaseScope != .teardown {
            visionInputPendingReleaseScope = scope
        }
        if scope == .teardown
            || visionInputPendingRestoreReason == nil {
            visionInputPendingRestoreReason = reason
        }
    }

    private func requestVisionInputTerminalRelease(
        reason: TVVisionFocusIneligibilityReason
    ) {
        guard expectedTVVisionPlatform == .visionOS else { return }
        visionInputTerminalReleaseRequested = true
        markVisionInputReleaseRequired(scope: .teardown, reason: reason)
        visionInputRuntimeTarget = .released(
            scope: .teardown,
            reason: reason
        )
        scheduleVisionInputReconciliation()
    }

    private func scheduleVisionInputReconciliation() {
        let previous = visionInputReconciliationTask
        let operationID = UUID()
        visionInputReconciliationOperationID = operationID
        visionInputReconciliationTask = Task { [weak self] in
            await previous?.value
            guard !Task.isCancelled,
                  let self,
                  self.visionInputReconciliationOperationID
                    == operationID else { return }
            await self.reconcileVisionInputRuntime()
            if self.visionInputReconciliationOperationID == operationID {
                self.visionInputReconciliationTask = nil
                self.visionInputReconciliationOperationID = nil
            }
        }
    }

    private func reconcileVisionInputRuntime() async {
        guard expectedTVVisionPlatform == .visionOS,
              let target = visionInputRuntimeTarget else { return }
        if visionInputReleasePending,
           visionInputOwnershipState?.phase == .active {
            await performVisionInputRelease()
        }
        guard target == visionInputRuntimeTarget else { return }
        switch target {
        case let .active(snapshot):
            guard currentVisionWindowInputSnapshot == snapshot,
                  snapshot.inputCapabilities.focusEligibility == .eligible else {
                return
            }
            visionInputOwnershipState = VisionWindowInputOwnershipState(
                snapshot: snapshot
            )
            visionInputReleasePending = false
            visionInputPendingReleaseScope = nil
            visionInputPendingRestoreReason = nil
            visionLocalNavigationRestoreReason = nil
            refreshVisionGameControllerRuntime()

        case let .released(_, reason):
            if visionInputOwnershipState?.phase == .active {
                markVisionInputReleaseRequired(
                    scope: .focusLoss,
                    reason: reason
                )
                await performVisionInputRelease()
            } else if visionLocalNavigationRestoreReason != reason {
                visionLocalNavigationRestoreReason = reason
            }
            visionInputReleasePending = false
            visionInputPendingReleaseScope = nil
            visionInputPendingRestoreReason = nil
        }
    }

    private func performVisionInputRelease() async {
        guard let state = visionInputOwnershipState,
              state.phase == .active,
              let scope = visionInputPendingReleaseScope,
              let restoreReason = visionInputPendingRestoreReason else {
            return
        }
        let controllerLeases = tvControllerRosterState?.controllers
            .map(\.lease)
            .filter {
                $0.platform == .visionOS
                    && $0.inputGeneration == state.inputGeneration
            } ?? []
        guard let request = try? VisionInputReleaseRequest(
            presentationGeneration: state.presentationGeneration,
            surfaceGeneration: state.surfaceGeneration,
            inputGeneration: state.inputGeneration,
            scope: scope,
            controllerLeases: controllerLeases,
            monitoredPaths: [.keyboard, .pointer, .indirectPointer],
            restoreReason: restoreReason
        ), let transition = try? state.releasing(request) else {
            visionInputTerminalReleaseRequested = true
            visionInputRuntimeTarget = .released(
                scope: .teardown,
                reason: .inputUnavailable
            )
            visionSystemInteractionDecisionState = nil
            await quiesceTVGameControllerRuntime()
            tvControllerRosterState = nil
            tvControllerRoutedRosterState = nil
            await visionInputDeliveryTask?.value
            visionInputDeliveryTask = nil
            _ = try? await releaseRemoteInput()
            visionInputOwnershipState = nil
            visionInputReleasePending = false
            visionLocalNavigationRestoreReason = .inputUnavailable
            return
        }
        visionInputOwnershipState = transition.state
        visionInputReleaseEffects = transition.effects
        var releaseFailed = false
        for effect in transition.effects {
            let succeeded = await applyVisionInputReleaseEffect(effect)
            if !succeeded {
                releaseFailed = true
            }
        }
        if releaseFailed {
            visionInputTerminalReleaseRequested = true
            visionInputRuntimeTarget = .released(
                scope: .teardown,
                reason: .inputUnavailable
            )
            visionSystemInteractionDecisionState = nil
            visionLocalNavigationRestoreReason = .inputUnavailable
        }
        visionInputReleasePending = false
    }

    @discardableResult
    private func applyVisionInputReleaseEffect(
        _ effect: VisionInputReleaseEffect
    ) async -> Bool {
        switch effect {
        case .closeAdmission:
            return true

        case .cancelSystemInteractionObservers:
            visionSystemInteractionDecisionState = nil
            return true

        case .removeControllerHandlers:
            await quiesceTVGameControllerRuntime()
            tvControllerRosterState = nil
            tvControllerRoutedRosterState = nil
            return true

        case .cancelInputMonitors:
            await visionInputDeliveryTask?.value
            visionInputDeliveryTask = nil
            return true

        case .awaitHeldInputRelease:
            do {
                try await releaseRemoteInput()
                return true
            } catch {
                return false
            }

        case .releaseSurfaceLease:
            return true

        case let .restoreLocalNavigation(reason):
            visionLocalNavigationRestoreReason = reason
            return true
        }
    }

    private func refreshVisionGameControllerRuntime() {
        guard expectedTVVisionPlatform == .visionOS else { return }
        guard !visionInputReleasePending,
              visionInputCaptureEnabled,
              let snapshot = currentVisionWindowInputSnapshot,
              snapshot.inputCapabilities.focusEligibility == .eligible else {
#if os(visionOS)
            if !visionInputReleasePending {
                tvGameControllerRuntimeOwner?.stop()
                tvGameControllerRuntimeOwner = nil
            }
#endif
            if !visionInputReleasePending {
                tvControllerRosterState = nil
                tvControllerRoutedRosterState = nil
                tvPendingControllerMotionSamples.removeAll()
            }
            return
        }
#if os(visionOS)
        try? startTVGameControllerRuntime(
            inputGeneration: snapshot.inputCapabilities.inputGeneration,
            platform: .visionOS
        )
#endif
    }

    private func applyTVGameControllerFeedback(
        _ feedback: RemoteInputFeedback
    ) {
        guard let platform = expectedTVVisionPlatform,
              !isTVVisionInputReleasePending,
              let roster = tvControllerRosterState,
              roster.controllers.allSatisfy({ $0.lease.platform == platform }),
              currentControllerInputSnapshot?.focusEligibility == .eligible else {
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
#if os(tvOS) || os(visionOS)
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
        let streamIsSelected = activeProductSessionOwner.flatMap { owner in
            guard productSessionOwnerIsCurrent(owner) else { return nil }
            return workspaceRegistry.state(for: owner.workspace)?
                .navigationSelection == .stream
        } ?? false
        applyTVRemoteFocusHandoffState(
            tvRemoteFocusHandoffState.selectingStreamNavigation(
                streamIsSelected,
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

    private func visionInputRestoreReason(
        for inputReason: MacSessionInputTerminationReason
    ) -> TVVisionFocusIneligibilityReason {
        switch inputReason {
        case .replacement:
            .replacing
        case .remoteTermination, .stop:
            .stopped
        case .detached:
            .detached
        case .sendFailure, .inputChannelFailure:
            .inputUnavailable
        }
    }

    private func applyMobileRuntimeState(
        _ state: SessionMobileRuntimeState,
        sessionID: UUID
    ) {
        let application = state.application
        guard let owner = activeProductSessionOwner,
              productSessionOwnerIsCurrent(owner),
              !isMobileRuntimeRevisionExhausted,
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
        guard let owner = activeProductSessionOwner,
              productSessionOwnerIsCurrent(owner),
              let sessionID = activeStreamSessionID,
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
                  let owner = self.activeProductSessionOwner,
                  owner.sessionID == sessionID else { return }
            _ = await self.stopStreamInternally(expectedOwner: owner)
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
              let owner = activeProductSessionOwner,
              productSessionOwnerIsCurrent(owner),
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

    private func presentStreamIssue(
        _ code: ProductIssueCode,
        in workspace: ProductWorkspaceReference,
        sessionID: UUID? = nil
    ) {
        let scope: ProductActionScope = sessionID.map {
            .session(workspace: workspace, sessionID: $0)
        } ?? .workspace(workspace)
        _ = try? workspaceRegistry.update(workspace) { state in
            let current = state.presentation.issue
            guard current?.code != code || current?.action?.scope != scope else {
                return
            }
            state.presentation.issue = ProductIssue(
                code: code,
                actionScope: scope
            )
        }
    }

    private func clearStreamIssue(
        in workspace: ProductWorkspaceReference,
        matching token: ProductActionToken? = nil
    ) {
        _ = try? workspaceRegistry.update(workspace) { state in
            guard let issue = state.presentation.issue,
                  issue.domain == .session,
                  token == nil || issue.action == token else {
                return
            }
            state.presentation.issue = nil
        }
    }

    private func clearStreamActionPresentation(
        in workspace: ProductWorkspaceReference
    ) {
        diagnostics.clearStreamActionableEvents()
        clearStreamIssue(in: workspace)
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
        negotiatedColorMetadata: VideoColorMetadata,
        negotiatedFramesPerSecond: Int
    ) {
        activeVideoPresentationRevision = 0
        activeVideoDecoderGeneration = nil
        highestVideoDecoderGeneration = 0
        renderState.negotiatedVideoColorMetadata = negotiatedColorMetadata
        renderState.negotiatedVideoFramesPerSecond = negotiatedFramesPerSecond
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
        guard let owner = activeProductSessionOwner,
              productSessionOwnerIsCurrent(owner),
              activeStreamSessionID == sessionID,
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
        renderState.negotiatedVideoFramesPerSecond = nil
        renderState.decodedVideoPresentationContract = nil
        renderState.hdrRenderResolution = .closed(.inactiveSession)
        publishHDRPresentationDiagnostic(.inactive)
    }

    private func refreshHDRRenderResolution() {
        guard session.isStreaming,
              let owner = activeProductSessionOwner,
              productSessionOwnerIsCurrent(owner),
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
                    currentHDRPlatformOutputCapabilities,
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

    private var currentHDRPlatformOutputCapabilities:
        HDRPlatformOutputCapabilities
    {
        if expectedTVVisionPlatform != nil,
           let display = tvVisionPlatformPresentationState?.snapshot.display,
           let source = tvVisionDisplayHDRSourceSnapshot,
           displayMatchesTVVisionDisplayHDRSource(display, source: source) {
            return display.hdrPlatformCapabilities
        }
        return HDRPlatformOutputCapabilityAdapter.current.capabilities
    }

    private func applyHDRRenderResolution(
        _ resolution: HDRRenderConfigurationResolution
    ) {
        renderState.hdrRenderResolution = resolution
        guard case let .closed(error) = resolution else { return }
        publishHDRPresentationDiagnostic(.closed(error))
    }
}
