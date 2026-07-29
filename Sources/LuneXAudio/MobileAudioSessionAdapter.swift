import Foundation

#if os(iOS) || os(tvOS) || os(visionOS)
import AVFAudio
#endif

struct MobileAudioSessionPortCapabilitySnapshot: Equatable, Sendable {
    let spatialAudioEnabled: Bool
}

struct MobileAudioSessionRuntimeSnapshot: Equatable, Sendable {
    let isActive: Bool
    let supportsMultichannelContent: Bool
    let requestedOutputChannelCount: Int?
    let preferredOutputChannelCount: Int
    let maximumOutputChannelCount: Int
    let currentOutputChannelCount: Int
    let sampleRate: Double
    let ioBufferDuration: TimeInterval
    let outputNames: [String]
    let outputPorts: [MobileAudioSessionPortCapabilitySnapshot]

    var outputAvailable: Bool {
        !outputPorts.isEmpty
    }

    var systemSpatialSupport: SpatialAudioRouteSupport {
        guard outputAvailable else { return .unknown }
        return outputPorts.contains(where: \.spatialAudioEnabled)
            ? .supported
            : .unsupported
    }

    func routeCapability(
        revision: SpatialAudioSemanticRevision
    ) -> SpatialAudioRouteCapabilitySnapshot {
        SpatialAudioRouteCapabilitySnapshot(
            revision: revision,
            outputAvailable: outputAvailable,
            systemSpatialSupport: systemSpatialSupport,
            currentOutputChannelCount: currentOutputChannelCount,
            maximumOutputChannelCount: maximumOutputChannelCount
        )
    }

    func audioRouteSnapshot(
        preferredConfiguration: StreamAudioConfiguration?
    ) -> AudioRouteSnapshot {
        AudioRouteSnapshot(
            outputNames: outputNames.isEmpty ? ["System Output"] : outputNames,
            sampleRate: sampleRate > 0
                ? sampleRate
                : (preferredConfiguration?.sampleRate ?? 48_000),
            outputChannelCount: currentOutputChannelCount > 0
                ? currentOutputChannelCount
                : (preferredConfiguration?.channelCount ?? 2),
            preferredBufferDuration: ioBufferDuration > 0
                ? ioBufferDuration
                : preferredConfiguration?.latencyPolicy.preferredBufferDuration
        )
    }
}

protocol MobileAudioSessionSystemClient: AnyObject {
    func setPlaybackCategory() throws
    func setSupportsMultichannelContent(_ enabled: Bool) throws
    func setPreferredSampleRate(_ sampleRate: Double) throws
    func setPreferredIOBufferDuration(_ duration: TimeInterval) throws
    func setPreferredOutputNumberOfChannels(_ count: Int) throws
    func setActive(
        _ active: Bool,
        notifyOthersOnDeactivation: Bool
    ) throws

    var supportsMultichannelContent: Bool { get }
    var preferredOutputNumberOfChannels: Int { get }
    var maximumOutputNumberOfChannels: Int { get }
    var outputNumberOfChannels: Int { get }
    var sampleRate: Double { get }
    var ioBufferDuration: TimeInterval { get }
    var outputNames: [String] { get }
    var outputPorts: [MobileAudioSessionPortCapabilitySnapshot] { get }
    var spatialPlaybackCapabilitiesChangedNotificationName:
        Notification.Name? { get }
}

protocol MobileAudioSessionApplying: AnyObject {
    func activate(
        for configuration: StreamAudioConfiguration
    ) throws -> MobileAudioSessionRuntimeSnapshot

    @discardableResult
    func deactivate(
        notifyOthersOnDeactivation: Bool
    ) -> MobileAudioSessionRuntimeSnapshot

    func currentSnapshot() -> MobileAudioSessionRuntimeSnapshot

    var spatialPlaybackCapabilitiesChangedNotificationName:
        Notification.Name? { get }
}

final class MobileAudioSessionAdapter:
    MobileAudioSessionApplying,
    @unchecked Sendable
{
    private let client: any MobileAudioSessionSystemClient
    private let lock = NSLock()
    private var isActive = false
    private var requestedOutputChannelCount: Int?

    init(
        client: any MobileAudioSessionSystemClient =
            ProductionMobileAudioSessionSystemClient()
    ) {
        self.client = client
    }

    func activate(
        for configuration: StreamAudioConfiguration
    ) throws -> MobileAudioSessionRuntimeSnapshot {
        try lock.withLock {
            try activateLocked(for: configuration)
        }
    }

    private func activateLocked(
        for configuration: StreamAudioConfiguration
    ) throws -> MobileAudioSessionRuntimeSnapshot {
        try configuration.validate()
        let suppliesMultichannelContent = configuration.channelCount > 2

        do {
            try client.setPlaybackCategory()
            try client.setSupportsMultichannelContent(
                suppliesMultichannelContent
            )
            try client.setPreferredSampleRate(configuration.sampleRate)
            try client.setPreferredIOBufferDuration(
                configuration.latencyPolicy.preferredBufferDuration
            )

            let maximumOutputChannelCount =
                client.maximumOutputNumberOfChannels
            if maximumOutputChannelCount > 0 {
                let preferredChannelCount = min(
                    configuration.channelCount,
                    maximumOutputChannelCount
                )
                try client.setPreferredOutputNumberOfChannels(
                    preferredChannelCount
                )
                requestedOutputChannelCount = preferredChannelCount
            } else {
                requestedOutputChannelCount = nil
            }

            try client.setActive(
                true,
                notifyOthersOnDeactivation: false
            )
            isActive = true
            return currentSnapshotLocked()
        } catch {
            requestedOutputChannelCount = nil
            try? client.setSupportsMultichannelContent(false)
            try? client.setActive(
                false,
                notifyOthersOnDeactivation: false
            )
            isActive = false
            throw error
        }
    }

    @discardableResult
    func deactivate(
        notifyOthersOnDeactivation: Bool
    ) -> MobileAudioSessionRuntimeSnapshot {
        lock.withLock {
            requestedOutputChannelCount = nil
            try? client.setSupportsMultichannelContent(false)
            try? client.setActive(
                false,
                notifyOthersOnDeactivation: notifyOthersOnDeactivation
            )
            isActive = false
            return currentSnapshotLocked()
        }
    }

    func currentSnapshot() -> MobileAudioSessionRuntimeSnapshot {
        lock.withLock {
            currentSnapshotLocked()
        }
    }

    private func currentSnapshotLocked() -> MobileAudioSessionRuntimeSnapshot {
        MobileAudioSessionRuntimeSnapshot(
            isActive: isActive,
            supportsMultichannelContent:
                client.supportsMultichannelContent,
            requestedOutputChannelCount: requestedOutputChannelCount,
            preferredOutputChannelCount:
                client.preferredOutputNumberOfChannels,
            maximumOutputChannelCount:
                max(client.maximumOutputNumberOfChannels, 0),
            currentOutputChannelCount:
                max(client.outputNumberOfChannels, 0),
            sampleRate: client.sampleRate,
            ioBufferDuration: client.ioBufferDuration,
            outputNames: Array(client.outputNames.prefix(16)),
            outputPorts: Array(client.outputPorts.prefix(16))
        )
    }

    var spatialPlaybackCapabilitiesChangedNotificationName:
        Notification.Name? {
        client.spatialPlaybackCapabilitiesChangedNotificationName
    }
}

enum MobileAudioSessionSystemClientError: Error, Equatable, Sendable {
    case platformUnavailable
}

#if os(iOS) || os(tvOS) || os(visionOS)
final class ProductionMobileAudioSessionSystemClient:
    MobileAudioSessionSystemClient
{
    private let session: AVAudioSession

    init(session: AVAudioSession = .sharedInstance()) {
        self.session = session
    }

    func setPlaybackCategory() throws {
        try session.setCategory(
            .playback,
            mode: .moviePlayback,
            options: []
        )
    }

    func setSupportsMultichannelContent(_ enabled: Bool) throws {
        try session.setSupportsMultichannelContent(enabled)
    }

    func setPreferredSampleRate(_ sampleRate: Double) throws {
        try session.setPreferredSampleRate(sampleRate)
    }

    func setPreferredIOBufferDuration(_ duration: TimeInterval) throws {
        try session.setPreferredIOBufferDuration(duration)
    }

    func setPreferredOutputNumberOfChannels(_ count: Int) throws {
        try session.setPreferredOutputNumberOfChannels(count)
    }

    func setActive(
        _ active: Bool,
        notifyOthersOnDeactivation: Bool
    ) throws {
        let options: AVAudioSession.SetActiveOptions =
            !active && notifyOthersOnDeactivation
                ? .notifyOthersOnDeactivation
                : []
        try session.setActive(active, options: options)
    }

    var supportsMultichannelContent: Bool {
        session.supportsMultichannelContent
    }

    var preferredOutputNumberOfChannels: Int {
        session.preferredOutputNumberOfChannels
    }

    var maximumOutputNumberOfChannels: Int {
        session.maximumOutputNumberOfChannels
    }

    var outputNumberOfChannels: Int {
        session.outputNumberOfChannels
    }

    var sampleRate: Double {
        session.sampleRate
    }

    var ioBufferDuration: TimeInterval {
        session.ioBufferDuration
    }

    var outputNames: [String] {
        session.currentRoute.outputs.map(\.portName)
    }

    var outputPorts: [MobileAudioSessionPortCapabilitySnapshot] {
        session.currentRoute.outputs.map {
            MobileAudioSessionPortCapabilitySnapshot(
                spatialAudioEnabled: $0.isSpatialAudioEnabled
            )
        }
    }

    var spatialPlaybackCapabilitiesChangedNotificationName:
        Notification.Name? {
        AVAudioSession.spatialPlaybackCapabilitiesChangedNotification
    }
}
#else
final class ProductionMobileAudioSessionSystemClient:
    MobileAudioSessionSystemClient
{
    func setPlaybackCategory() throws {
        throw MobileAudioSessionSystemClientError.platformUnavailable
    }

    func setSupportsMultichannelContent(_ enabled: Bool) throws {
        throw MobileAudioSessionSystemClientError.platformUnavailable
    }

    func setPreferredSampleRate(_ sampleRate: Double) throws {
        throw MobileAudioSessionSystemClientError.platformUnavailable
    }

    func setPreferredIOBufferDuration(_ duration: TimeInterval) throws {
        throw MobileAudioSessionSystemClientError.platformUnavailable
    }

    func setPreferredOutputNumberOfChannels(_ count: Int) throws {
        throw MobileAudioSessionSystemClientError.platformUnavailable
    }

    func setActive(
        _ active: Bool,
        notifyOthersOnDeactivation: Bool
    ) throws {
        throw MobileAudioSessionSystemClientError.platformUnavailable
    }

    let supportsMultichannelContent = false
    let preferredOutputNumberOfChannels = 0
    let maximumOutputNumberOfChannels = 0
    let outputNumberOfChannels = 0
    let sampleRate = 0.0
    let ioBufferDuration = 0.0
    let outputNames: [String] = []
    let outputPorts: [MobileAudioSessionPortCapabilitySnapshot] = []
    let spatialPlaybackCapabilitiesChangedNotificationName:
        Notification.Name? = nil
}
#endif
