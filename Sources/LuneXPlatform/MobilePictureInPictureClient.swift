import Foundation

enum MobilePictureInPictureClientComponentState:
    String,
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case unavailable
    case ready
    case invalidated
}

struct MobilePictureInPictureClientComponents:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    let controller: MobilePictureInPictureClientComponentState
    let contentSource: MobilePictureInPictureClientComponentState
    let playbackDelegate: MobilePictureInPictureClientComponentState

    static let unprepared = MobilePictureInPictureClientComponents(
        controller: .unavailable,
        contentSource: .unavailable,
        playbackDelegate: .unavailable
    )

    static let ready = MobilePictureInPictureClientComponents(
        controller: .ready,
        contentSource: .ready,
        playbackDelegate: .ready
    )

    static let invalidated = MobilePictureInPictureClientComponents(
        controller: .invalidated,
        contentSource: .invalidated,
        playbackDelegate: .invalidated
    )

    var allReady: Bool {
        controller == .ready
            && contentSource == .ready
            && playbackDelegate == .ready
    }

    var allInvalidated: Bool {
        controller == .invalidated
            && contentSource == .invalidated
            && playbackDelegate == .invalidated
    }
}

struct MobilePictureInPictureClientPreparationSnapshot:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    let generation: MobilePictureInPictureGeneration
    let components: MobilePictureInPictureClientComponents
    let capability: MobilePictureInPictureCapability

    init?(
        generation: MobilePictureInPictureGeneration,
        components: MobilePictureInPictureClientComponents,
        capability: MobilePictureInPictureCapability
    ) {
        if components.allReady {
            guard capability != .unknown else { return nil }
        } else {
            guard !capability.isPossible else { return nil }
        }
        if components.allInvalidated {
            guard capability == .unavailable(.invalidated) else {
                return nil
            }
        }
        self.generation = generation
        self.components = components
        self.capability = capability
    }
}

enum MobilePictureInPicturePlaybackTimeline:
    String,
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case unavailable
    case live
}

enum MobilePictureInPictureBackgroundAudioPolicy:
    String,
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case permitted
    case prohibited
}

struct MobilePictureInPicturePlaybackState:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    let timeline: MobilePictureInPicturePlaybackTimeline
    let isPaused: Bool
    let backgroundAudioPolicy:
        MobilePictureInPictureBackgroundAudioPolicy

    init?(
        timeline: MobilePictureInPicturePlaybackTimeline,
        isPaused: Bool,
        backgroundAudioPolicy:
            MobilePictureInPictureBackgroundAudioPolicy
    ) {
        guard timeline != .unavailable || isPaused else {
            return nil
        }
        self.timeline = timeline
        self.isPaused = isPaused
        self.backgroundAudioPolicy = backgroundAudioPolicy
    }
}

struct MobilePictureInPictureRenderSize:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    static let maximumDimension: Int32 = 16_384

    let width: Int32
    let height: Int32

    init?(width: Int32, height: Int32) {
        guard (1...Self.maximumDimension).contains(width),
              (1...Self.maximumDimension).contains(height) else {
            return nil
        }
        self.width = width
        self.height = height
    }
}

struct MobilePictureInPictureSkipInterval:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    static let maximumMagnitudeNanoseconds: Int64 =
        86_400_000_000_000

    let nanoseconds: Int64

    init?(nanoseconds: Int64) {
        guard nanoseconds != 0,
              nanoseconds != .min,
              abs(nanoseconds) <= Self.maximumMagnitudeNanoseconds else {
            return nil
        }
        self.nanoseconds = nanoseconds
    }
}

enum MobilePictureInPictureClientCallbackKind:
    String,
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    case restoreInterface = "restore-interface"
    case skip
}

struct MobilePictureInPictureClientCallbackLease:
    Codable,
    Equatable,
    Hashable,
    Sendable
{
    let generation: MobilePictureInPictureGeneration
    let kind: MobilePictureInPictureClientCallbackKind
    let ordinal: UInt64

    init?(
        generation: MobilePictureInPictureGeneration,
        kind: MobilePictureInPictureClientCallbackKind,
        ordinal: UInt64
    ) {
        guard ordinal > 0 else { return nil }
        self.generation = generation
        self.kind = kind
        self.ordinal = ordinal
    }
}

enum MobilePictureInPictureClientCallbackCompletion:
    Equatable,
    Sendable
{
    case restoreInterface(restored: Bool)
    case skip

    var kind: MobilePictureInPictureClientCallbackKind {
        switch self {
        case .restoreInterface:
            .restoreInterface
        case .skip:
            .skip
        }
    }
}

enum MobilePictureInPictureClientCallbackOutcome:
    Equatable,
    Sendable
{
    case completed
    case staleGeneration
    case kindMismatch
    case alreadyCompleted
    case invalidated
}

enum MobilePictureInPictureClientEvent: Equatable, Sendable {
    case prepared(MobilePictureInPictureClientPreparationSnapshot)
    case capabilityChanged(MobilePictureInPictureCapability)
    case willStart
    case didStart
    case startFailed(MobilePictureInPictureFailureClass)
    case willStop
    case didStop
    case restoreInterfaceRequested(
        MobilePictureInPictureClientCallbackLease
    )
    case setPlaying(Bool)
    case skipRequested(
        interval: MobilePictureInPictureSkipInterval,
        completion: MobilePictureInPictureClientCallbackLease
    )
    case renderSizeChanged(MobilePictureInPictureRenderSize)
    case invalidated

    fileprivate var boundGeneration:
        MobilePictureInPictureGeneration?
    {
        switch self {
        case let .prepared(snapshot):
            snapshot.generation
        case let .restoreInterfaceRequested(lease):
            lease.generation
        case let .skipRequested(_, completion):
            completion.generation
        case .capabilityChanged, .willStart, .didStart, .startFailed,
             .willStop, .didStop, .setPlaying, .renderSizeChanged,
             .invalidated:
            nil
        }
    }
}

struct MobilePictureInPictureClientEventEnvelope:
    Equatable,
    Sendable
{
    let generation: MobilePictureInPictureGeneration
    let event: MobilePictureInPictureClientEvent

    init?(
        generation: MobilePictureInPictureGeneration,
        event: MobilePictureInPictureClientEvent
    ) {
        guard event.boundGeneration == nil
                || event.boundGeneration == generation else {
            return nil
        }
        self.generation = generation
        self.event = event
    }
}

typealias MobilePictureInPictureClientEventHandler =
    @MainActor (MobilePictureInPictureClientEventEnvelope) -> Void

@MainActor
protocol MobilePictureInPictureControllerClient: AnyObject {
    var generation: MobilePictureInPictureGeneration { get }
    var preparationSnapshot:
        MobilePictureInPictureClientPreparationSnapshot? { get }

    func setEventHandler(
        _ handler: MobilePictureInPictureClientEventHandler?
    )
    func prepare()
    func requestStart()
    func requestStop()
    func updatePlaybackState(
        _ state: MobilePictureInPicturePlaybackState
    )
    func invalidatePlaybackState()
    func completeCallback(
        _ lease: MobilePictureInPictureClientCallbackLease,
        with completion: MobilePictureInPictureClientCallbackCompletion
    ) -> MobilePictureInPictureClientCallbackOutcome
    func invalidate()
}
