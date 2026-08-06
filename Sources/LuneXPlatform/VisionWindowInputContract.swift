import Foundation

enum VisionWindowInputContractError: Error, Equatable, Sendable {
    case platformMismatch
    case revisionMismatch
    case presentationGenerationMismatch
    case surfaceGenerationMismatch
    case inputGenerationMismatch
    case invalidUnavailableFeatureSet
    case duplicateUnavailableFeature(VisionUnavailablePresentationFeature)
    case eligibleSurfaceRequired
    case invalidMonitorPath(VisionInputPath)
    case controllerPlatformMismatch
    case controllerInputGenerationMismatch
    case duplicateControllerSlot(UInt8)
    case duplicateControllerLease(UInt64)
    case restoreReasonRequired
}

enum VisionPresentationMode: String, Codable, Hashable, Sendable {
    case windowed
}

enum VisionUnavailablePresentationFeature:
    String,
    Codable,
    CaseIterable,
    Comparable,
    Hashable,
    Sendable
{
    case immersive
    case passthrough
    case stereoscopic
    case volumetric

    static func < (
        lhs: VisionUnavailablePresentationFeature,
        rhs: VisionUnavailablePresentationFeature
    ) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum VisionPresentationUnavailableReason:
    String,
    Codable,
    Hashable,
    Sendable
{
    case stage18WindowedOnly = "stage-18-windowed-only"
    case runtimeUnavailable = "runtime-unavailable"
    case publicCapabilityUnavailable = "public-capability-unavailable"
}

struct VisionUnavailablePresentationState: Equatable, Hashable, Sendable {
    let feature: VisionUnavailablePresentationFeature
    let reason: VisionPresentationUnavailableReason
}

struct VisionWindowedPresentationState: Equatable, Hashable, Sendable {
    let ownership: TVVisionPresentationOwnership
    let revision: TVVisionSemanticRevision
    let surfaceGeneration: TVVisionGeneration
    let mode: VisionPresentationMode
    let unavailableFeatures: [VisionUnavailablePresentationState]

    init(
        ownership: TVVisionPresentationOwnership,
        revision: TVVisionSemanticRevision,
        surfaceGeneration: TVVisionGeneration,
        unavailableFeatures: [VisionUnavailablePresentationState]
    ) throws {
        guard ownership.platform == .visionOS else {
            throw VisionWindowInputContractError.platformMismatch
        }
        try surfaceGeneration.require(.surface)

        var features = Set<VisionUnavailablePresentationFeature>()
        for state in unavailableFeatures {
            guard features.insert(state.feature).inserted else {
                throw VisionWindowInputContractError.duplicateUnavailableFeature(
                    state.feature
                )
            }
        }
        guard features == Set(VisionUnavailablePresentationFeature.allCases) else {
            throw VisionWindowInputContractError.invalidUnavailableFeatureSet
        }

        self.ownership = ownership
        self.revision = revision
        self.surfaceGeneration = surfaceGeneration
        mode = .windowed
        self.unavailableFeatures = unavailableFeatures.sorted {
            $0.feature < $1.feature
        }
    }

    static func windowedOnly(
        ownership: TVVisionPresentationOwnership,
        revision: TVVisionSemanticRevision,
        surfaceGeneration: TVVisionGeneration,
        reason: VisionPresentationUnavailableReason = .stage18WindowedOnly
    ) throws -> VisionWindowedPresentationState {
        try VisionWindowedPresentationState(
            ownership: ownership,
            revision: revision,
            surfaceGeneration: surfaceGeneration,
            unavailableFeatures: VisionUnavailablePresentationFeature.allCases.map {
                VisionUnavailablePresentationState(feature: $0, reason: reason)
            }
        )
    }
}

enum VisionInputPath:
    String,
    Codable,
    CaseIterable,
    Comparable,
    Hashable,
    Sendable
{
    case extendedGamepad = "extended-gamepad"
    case indirectPointer = "indirect-pointer"
    case keyboard
    case microGamepad = "micro-gamepad"
    case pointer

    var capability: TVVisionInputCapability {
        switch self {
        case .extendedGamepad: .extendedGamepad
        case .microGamepad: .microGamepad
        case .keyboard: .keyboard
        case .pointer: .pointer
        case .indirectPointer: .indirectPointer
        }
    }

    var usesControllerHandler: Bool {
        switch self {
        case .extendedGamepad, .microGamepad: true
        case .keyboard, .pointer, .indirectPointer: false
        }
    }

    static func < (lhs: VisionInputPath, rhs: VisionInputPath) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

struct VisionWindowInputSnapshot: Equatable, Sendable {
    let presentation: VisionWindowedPresentationState
    let sceneSurface: TVVisionSceneSurfaceSnapshot
    let inputCapabilities: TVVisionInputCapabilitySnapshot

    init(
        presentation: VisionWindowedPresentationState,
        sceneSurface: TVVisionSceneSurfaceSnapshot,
        inputCapabilities: TVVisionInputCapabilitySnapshot
    ) throws {
        guard sceneSurface.platform == .visionOS,
              inputCapabilities.platform == .visionOS else {
            throw VisionWindowInputContractError.platformMismatch
        }
        guard sceneSurface.revision == presentation.revision,
              inputCapabilities.revision == presentation.revision else {
            throw VisionWindowInputContractError.revisionMismatch
        }
        guard sceneSurface.surfaceGeneration
                == presentation.surfaceGeneration else {
            throw VisionWindowInputContractError.surfaceGenerationMismatch
        }
        guard inputCapabilities.inputGeneration
                == presentation.ownership.inputGeneration else {
            throw VisionWindowInputContractError.inputGenerationMismatch
        }
        if inputCapabilities.focusEligibility == .eligible {
            guard sceneSurface.attachment == .attached,
                  sceneSurface.activity == .active,
                  sceneSurface.isVisible else {
                throw VisionWindowInputContractError.eligibleSurfaceRequired
            }
        }
        self.presentation = presentation
        self.sceneSurface = sceneSurface
        self.inputCapabilities = inputCapabilities
    }
}

struct VisionInputAdmissionRequest: Equatable, Hashable, Sendable {
    let presentationGeneration: TVVisionGeneration
    let surfaceGeneration: TVVisionGeneration
    let inputGeneration: TVVisionGeneration
    let path: VisionInputPath

    init(
        presentationGeneration: TVVisionGeneration,
        surfaceGeneration: TVVisionGeneration,
        inputGeneration: TVVisionGeneration,
        path: VisionInputPath
    ) throws {
        try presentationGeneration.require(.presentation)
        try surfaceGeneration.require(.surface)
        try inputGeneration.require(.input)
        self.presentationGeneration = presentationGeneration
        self.surfaceGeneration = surfaceGeneration
        self.inputGeneration = inputGeneration
        self.path = path
    }
}

enum VisionInputAdmissionUnavailableReason: Equatable, Sendable {
    case stalePresentationGeneration
    case staleSurfaceGeneration
    case staleInputGeneration
    case surfaceDetached
    case sceneInactive
    case surfaceHidden
    case focusIneligible(TVVisionFocusIneligibilityReason)
    case capabilityUnavailable(TVVisionInputCapability)
}

enum VisionInputAdmissionDecision: Equatable, Sendable {
    case admit(path: VisionInputPath, inputGeneration: TVVisionGeneration)
    case unavailable(
        path: VisionInputPath,
        reason: VisionInputAdmissionUnavailableReason
    )
}

enum VisionInputAdmissionResolver {
    static func resolve(
        _ request: VisionInputAdmissionRequest,
        snapshot: VisionWindowInputSnapshot
    ) -> VisionInputAdmissionDecision {
        let presentation = snapshot.presentation
        if request.presentationGeneration
            != presentation.ownership.presentationGeneration {
            return .unavailable(
                path: request.path,
                reason: .stalePresentationGeneration
            )
        }
        if request.surfaceGeneration != presentation.surfaceGeneration {
            return .unavailable(
                path: request.path,
                reason: .staleSurfaceGeneration
            )
        }
        if request.inputGeneration
            != presentation.ownership.inputGeneration {
            return .unavailable(
                path: request.path,
                reason: .staleInputGeneration
            )
        }

        let scene = snapshot.sceneSurface
        guard scene.attachment == .attached else {
            return .unavailable(
                path: request.path,
                reason: .surfaceDetached
            )
        }
        guard scene.activity == .active else {
            return .unavailable(
                path: request.path,
                reason: .sceneInactive
            )
        }
        guard scene.isVisible else {
            return .unavailable(
                path: request.path,
                reason: .surfaceHidden
            )
        }
        switch snapshot.inputCapabilities.focusEligibility {
        case .eligible:
            break
        case let .ineligible(reason):
            return .unavailable(
                path: request.path,
                reason: .focusIneligible(reason)
            )
        }
        guard snapshot.inputCapabilities.supported.contains(
            request.path.capability
        ) else {
            return .unavailable(
                path: request.path,
                reason: .capabilityUnavailable(request.path.capability)
            )
        }
        return .admit(
            path: request.path,
            inputGeneration: request.inputGeneration
        )
    }
}

enum VisionSystemReservedInteraction:
    String,
    Codable,
    CaseIterable,
    Hashable,
    Sendable
{
    case systemGesture = "system-gesture"
    case recenter
    case capture
    case safety
    case volume
    case escape
    case gaze
    case hand
    case unsupported
}

enum VisionSystemInteractionDisposition:
    String,
    Codable,
    Hashable,
    Sendable
{
    case reserveLocally = "reserve-locally"
    case dropUnsupportedLocally = "drop-unsupported-locally"
}

struct VisionSystemInteractionDecision: Equatable, Hashable, Sendable {
    let interaction: VisionSystemReservedInteraction
    let disposition: VisionSystemInteractionDisposition

    static func resolve(
        _ interaction: VisionSystemReservedInteraction
    ) -> VisionSystemInteractionDecision {
        let disposition: VisionSystemInteractionDisposition
        switch interaction {
        case .systemGesture, .recenter, .capture, .safety, .volume, .escape:
            disposition = .reserveLocally
        case .gaze, .hand, .unsupported:
            disposition = .dropUnsupportedLocally
        }
        return VisionSystemInteractionDecision(
            interaction: interaction,
            disposition: disposition
        )
    }
}

enum VisionInputReleaseScope: String, Codable, Hashable, Sendable {
    case focusLoss = "focus-loss"
    case teardown
}

enum VisionInputOwnershipPhase: String, Codable, Hashable, Sendable {
    case active
    case released
}

struct VisionInputReleaseRequest: Equatable, Sendable {
    let presentationGeneration: TVVisionGeneration
    let surfaceGeneration: TVVisionGeneration
    let inputGeneration: TVVisionGeneration
    let scope: VisionInputReleaseScope
    let controllerLeases: [TVVisionControllerLease]
    let monitoredPaths: Set<VisionInputPath>
    let restoreReason: TVVisionFocusIneligibilityReason?

    init(
        presentationGeneration: TVVisionGeneration,
        surfaceGeneration: TVVisionGeneration,
        inputGeneration: TVVisionGeneration,
        scope: VisionInputReleaseScope,
        controllerLeases: [TVVisionControllerLease],
        monitoredPaths: Set<VisionInputPath>,
        restoreReason: TVVisionFocusIneligibilityReason?
    ) throws {
        try presentationGeneration.require(.presentation)
        try surfaceGeneration.require(.surface)
        try inputGeneration.require(.input)
        if scope == .focusLoss, restoreReason == nil {
            throw VisionWindowInputContractError.restoreReasonRequired
        }
        for path in monitoredPaths where path.usesControllerHandler {
            throw VisionWindowInputContractError.invalidMonitorPath(path)
        }
        self.presentationGeneration = presentationGeneration
        self.surfaceGeneration = surfaceGeneration
        self.inputGeneration = inputGeneration
        self.scope = scope
        self.controllerLeases = controllerLeases
        self.monitoredPaths = monitoredPaths
        self.restoreReason = restoreReason
    }
}

enum VisionInputReleaseEffect: Equatable, Sendable {
    case closeAdmission(inputGeneration: TVVisionGeneration)
    case cancelSystemInteractionObservers
    case removeControllerHandlers([TVVisionControllerLease])
    case cancelInputMonitors([VisionInputPath])
    case awaitHeldInputRelease(inputGeneration: TVVisionGeneration)
    case releaseSurfaceLease(surfaceGeneration: TVVisionGeneration)
    case restoreLocalNavigation(TVVisionFocusIneligibilityReason)
}

struct VisionInputReleaseTransition: Equatable, Sendable {
    let state: VisionWindowInputOwnershipState
    let effects: [VisionInputReleaseEffect]
}

struct VisionWindowInputOwnershipState: Equatable, Sendable {
    let presentationGeneration: TVVisionGeneration
    let surfaceGeneration: TVVisionGeneration
    let inputGeneration: TVVisionGeneration
    let phase: VisionInputOwnershipPhase

    init(snapshot: VisionWindowInputSnapshot) {
        presentationGeneration = snapshot.presentation
            .ownership.presentationGeneration
        surfaceGeneration = snapshot.presentation.surfaceGeneration
        inputGeneration = snapshot.presentation.ownership.inputGeneration
        phase = .active
    }

    private init(
        presentationGeneration: TVVisionGeneration,
        surfaceGeneration: TVVisionGeneration,
        inputGeneration: TVVisionGeneration,
        phase: VisionInputOwnershipPhase
    ) {
        self.presentationGeneration = presentationGeneration
        self.surfaceGeneration = surfaceGeneration
        self.inputGeneration = inputGeneration
        self.phase = phase
    }

    func releasing(
        _ request: VisionInputReleaseRequest
    ) throws -> VisionInputReleaseTransition {
        guard phase == .active else {
            return VisionInputReleaseTransition(state: self, effects: [])
        }
        guard request.presentationGeneration == presentationGeneration else {
            throw VisionWindowInputContractError.presentationGenerationMismatch
        }
        guard request.surfaceGeneration == surfaceGeneration else {
            throw VisionWindowInputContractError.surfaceGenerationMismatch
        }
        guard request.inputGeneration == inputGeneration else {
            throw VisionWindowInputContractError.inputGenerationMismatch
        }
        guard request.controllerLeases.allSatisfy({
            $0.platform == .visionOS
        }) else {
            throw VisionWindowInputContractError.controllerPlatformMismatch
        }
        guard request.controllerLeases.allSatisfy({
            $0.inputGeneration == inputGeneration
        }) else {
            throw VisionWindowInputContractError.controllerInputGenerationMismatch
        }

        var slots = Set<UInt8>()
        var leases = Set<UInt64>()
        for controller in request.controllerLeases {
            guard slots.insert(controller.slot.rawValue).inserted else {
                throw VisionWindowInputContractError.duplicateControllerSlot(
                    controller.slot.rawValue
                )
            }
            guard leases.insert(
                controller.leaseGeneration.rawValue
            ).inserted else {
                throw VisionWindowInputContractError.duplicateControllerLease(
                    controller.leaseGeneration.rawValue
                )
            }
        }

        var effects: [VisionInputReleaseEffect] = [
            .closeAdmission(inputGeneration: inputGeneration)
        ]
        if request.scope == .teardown {
            effects.append(.cancelSystemInteractionObservers)
        }
        let controllers = request.controllerLeases.sorted {
            $0.slot < $1.slot
        }
        if !controllers.isEmpty {
            effects.append(.removeControllerHandlers(controllers))
        }
        let monitoredPaths = request.monitoredPaths.sorted()
        if !monitoredPaths.isEmpty {
            effects.append(.cancelInputMonitors(monitoredPaths))
        }
        effects.append(.awaitHeldInputRelease(
            inputGeneration: inputGeneration
        ))
        if request.scope == .teardown {
            effects.append(.releaseSurfaceLease(
                surfaceGeneration: surfaceGeneration
            ))
        }
        if let restoreReason = request.restoreReason {
            effects.append(.restoreLocalNavigation(restoreReason))
        }

        let released = VisionWindowInputOwnershipState(
            presentationGeneration: presentationGeneration,
            surfaceGeneration: surfaceGeneration,
            inputGeneration: inputGeneration,
            phase: .released
        )
        return VisionInputReleaseTransition(
            state: released,
            effects: effects
        )
    }
}
