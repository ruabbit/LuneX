#if os(macOS)
import AppKit
import MetalKit
import OSLog

enum AppKitWindowVisibilityResolver {
    static func resolve(
        isOrderedVisible: Bool,
        isMiniaturized: Bool,
        isOcclusionVisible: Bool,
        isKeyWindow: Bool,
        isApplicationActive: Bool
    ) -> Bool {
        guard isOrderedVisible, !isMiniaturized else { return false }
        return isOcclusionVisible || (isKeyWindow && isApplicationActive)
    }
}

@MainActor
protocol AppKitLifecycleMonitoring: AnyObject {
    func attach(to window: NSWindow, surface: NSView)
    func surfaceGeometryDidChange()
    func detach()
}

@MainActor
final class AppKitLifecycleMonitor: AppKitLifecycleMonitoring {
    typealias WindowVisibilityProvider = @MainActor (NSWindow) -> Bool
    typealias MaximumFramesPerSecondProvider = @MainActor (NSScreen?) -> Int?

    private let logger = Logger(subsystem: "dev.lunex.client.macos", category: "window.lifecycle")
    private weak var window: NSWindow?
    private weak var surface: NSView?
    private let lifecycle: PlatformLifecycleState
    private let windowVisibilityProvider: WindowVisibilityProvider
    private let maximumFramesPerSecondProvider: MaximumFramesPerSecondProvider
    private let attachmentID = UUID()
    private var observers: [NSObjectProtocol] = []

    init(
        lifecycle: PlatformLifecycleState,
        windowVisibilityProvider: @escaping WindowVisibilityProvider = {
            AppKitWindowVisibilityResolver.resolve(
                isOrderedVisible: $0.isVisible,
                isMiniaturized: $0.isMiniaturized,
                isOcclusionVisible: $0.occlusionState.contains(.visible),
                isKeyWindow: $0.isKeyWindow,
                isApplicationActive: NSApp.isActive
            )
        },
        maximumFramesPerSecondProvider: @escaping MaximumFramesPerSecondProvider = {
            $0?.maximumFramesPerSecond
        }
    ) {
        self.lifecycle = lifecycle
        self.windowVisibilityProvider = windowVisibilityProvider
        self.maximumFramesPerSecondProvider = maximumFramesPerSecondProvider
    }

    func attach(to window: NSWindow, surface: NSView) {
        if self.window === window,
           self.surface === surface,
           !observers.isEmpty {
            refreshVisibility()
            refreshFocus()
            refreshSurfaceState()
            return
        }
        detach(resetLifecycle: false)
        self.window = window
        self.surface = surface
        lifecycle.claimSurfaceAttachment(attachmentID)
        logger.info("Attached lifecycle monitor to stream surface")

        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSWindow.didChangeOcclusionStateNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshVisibility()
                }
            },
            center.addObserver(forName: NSWindow.didExposeNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshVisibility()
                }
            },
            center.addObserver(forName: NSWindow.didBecomeKeyNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.setFocused(true)
                }
            },
            center.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.setFocused(false)
                }
            },
            center.addObserver(forName: NSWindow.didChangeScreenNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshSurfaceState()
                }
            },
            center.addObserver(forName: NSWindow.didEndLiveResizeNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshSurfaceState()
                }
            },
            center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshSurfaceState()
                }
            },
            center.addObserver(forName: NSWindow.didChangeBackingPropertiesNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshSurfaceState()
                }
            },
            center.addObserver(forName: NSWindow.didMiniaturizeNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshVisibility()
                }
            },
            center.addObserver(forName: NSWindow.didDeminiaturizeNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshVisibility()
                }
            },
            center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshVisibility()
                    self?.refreshFocus()
                    self?.refreshSurfaceState()
                }
            },
            center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.setFocused(false)
                }
            },
            center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshSurfaceState()
                }
            }
        ]

        refreshVisibility()
        refreshFocus()
        refreshSurfaceState()
        logger.info("Lifecycle ready: visible=\(self.lifecycle.isVisible, privacy: .public) focused=\(self.lifecycle.isFocused, privacy: .public) drawable=\(self.lifecycle.drawableSize.width, privacy: .public)x\(self.lifecycle.drawableSize.height, privacy: .public) EDR=\(self.lifecycle.headroom.current, privacy: .public)")
        schedulePostAttachmentRefresh(window: window, surface: surface)
    }

    func surfaceGeometryDidChange() {
        refreshSurfaceState()
    }

    func detach() {
        detach(resetLifecycle: true)
    }

    private func detach(resetLifecycle: Bool) {
        let wasAttached = window != nil || surface != nil || !observers.isEmpty
        let center = NotificationCenter.default
        observers.forEach(center.removeObserver)
        observers.removeAll()
        window = nil
        surface = nil
        guard resetLifecycle,
              wasAttached,
              lifecycle.clearSurfaceAttachment(attachmentID) else { return }
    }

    private func refreshVisibility() {
        guard lifecycle.isCurrentSurfaceAttachment(attachmentID),
              let window else { return }
        lifecycle.isVisible = windowVisibilityProvider(window)
        logger.debug("Window visibility changed: \(self.lifecycle.isVisible, privacy: .public)")
        lifecycle.updateRenderPolicy()
    }

    private func schedulePostAttachmentRefresh(
        window: NSWindow,
        surface: NSView
    ) {
        DispatchQueue.main.async { @MainActor [weak self, weak window, weak surface] in
            guard let self,
                  let window,
                  let surface,
                  self.window === window,
                  self.surface === surface else { return }
            self.refreshVisibility()
            self.refreshFocus()
            self.refreshSurfaceState()
            self.logger.info("Lifecycle post-attach refresh: visible=\(self.lifecycle.isVisible, privacy: .public) focused=\(self.lifecycle.isFocused, privacy: .public) drawable=\(self.lifecycle.drawableSize.width, privacy: .public)x\(self.lifecycle.drawableSize.height, privacy: .public)")
        }
    }

    private func setFocused(_ focused: Bool) {
        guard lifecycle.isCurrentSurfaceAttachment(attachmentID) else { return }
        lifecycle.isFocused = focused
        logger.debug("Window focus changed: \(focused, privacy: .public)")
        lifecycle.updateRenderPolicy()
    }

    private func refreshFocus() {
        setFocused(window?.isKeyWindow == true && NSApp.isActive)
    }

    private func refreshSurfaceState() {
        guard lifecycle.isCurrentSurfaceAttachment(attachmentID),
              let window,
              let surface,
              surface.window === window else { return }
        let backingBounds = surface.convertToBacking(surface.bounds)
        let drawableSize = PixelSize(
            width: pixelDimension(backingBounds.width),
            height: pixelDimension(backingBounds.height)
        )
        if let metalView = surface as? MTKView {
            metalView.drawableSize = CGSize(
                width: drawableSize.width,
                height: drawableSize.height
            )
        }
        guard lifecycle.updateSurface(
            for: attachmentID,
            displayID: displayIdentity(window.screen),
            maximumDisplayFramesPerSecond:
                maximumFramesPerSecondProvider(window.screen),
            headroom: DisplayHeadroomReader.read(screen: window.screen),
            drawableSize: drawableSize
        ) != nil else { return }
        logger.debug("Surface changed: attached=\(self.lifecycle.displaySnapshot != nil, privacy: .public) revision=\(self.lifecycle.displayRevision.rawValue, privacy: .public) drawable=\(drawableSize.width, privacy: .public)x\(drawableSize.height, privacy: .public) EDR=\(self.lifecycle.headroom.current, privacy: .public)")
    }

    private func displayIdentity(_ screen: NSScreen?) -> String? {
        guard let number = screen?.deviceDescription[
            NSDeviceDescriptionKey("NSScreenNumber")
        ] as? NSNumber else {
            return nil
        }
        return String(number.uint32Value)
    }

    private func pixelDimension(_ value: CGFloat) -> Int {
        guard value.isFinite,
              value > 0,
              value <= CGFloat(Int.max) else { return 0 }
        return Int(value.rounded())
    }
}
#endif
