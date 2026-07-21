#if os(macOS)
import AppKit
import MetalKit
import OSLog

@MainActor
protocol AppKitLifecycleMonitoring: AnyObject {
    func attach(to window: NSWindow, surface: NSView)
    func surfaceGeometryDidChange()
    func detach()
}

@MainActor
final class AppKitLifecycleMonitor: AppKitLifecycleMonitoring {
    private let logger = Logger(subsystem: "dev.lunex.client.macos", category: "window.lifecycle")
    private weak var window: NSWindow?
    private weak var surface: NSView?
    private let lifecycle: PlatformLifecycleState
    private let attachmentID = UUID()
    private var observers: [NSObjectProtocol] = []

    init(lifecycle: PlatformLifecycleState) {
        self.lifecycle = lifecycle
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
                    self?.refreshFocus()
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
        guard let window else { return }
        lifecycle.isVisible = window.occlusionState.contains(.visible) && !window.isMiniaturized
        logger.debug("Window visibility changed: \(self.lifecycle.isVisible, privacy: .public)")
        lifecycle.updateRenderPolicy()
    }

    private func setFocused(_ focused: Bool) {
        lifecycle.isFocused = focused
        logger.debug("Window focus changed: \(focused, privacy: .public)")
        lifecycle.updateRenderPolicy()
    }

    private func refreshFocus() {
        setFocused(window?.isKeyWindow == true && NSApp.isActive)
    }

    private func refreshSurfaceState() {
        guard let window,
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
        lifecycle.updateSurface(
            displayID: window.screen?.localizedName,
            headroom: DisplayHeadroomReader.read(screen: window.screen),
            drawableSize: drawableSize
        )
        logger.debug("Surface changed: display=\(self.lifecycle.displayID ?? "none", privacy: .public) drawable=\(drawableSize.width, privacy: .public)x\(drawableSize.height, privacy: .public) EDR=\(self.lifecycle.headroom.current, privacy: .public)")
    }

    private func pixelDimension(_ value: CGFloat) -> Int {
        guard value.isFinite,
              value > 0,
              value <= CGFloat(Int.max) else { return 0 }
        return Int(value.rounded())
    }
}
#endif
