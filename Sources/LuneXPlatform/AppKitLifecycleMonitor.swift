#if os(macOS)
import AppKit
import OSLog
import SwiftUI

@MainActor
final class AppKitLifecycleMonitor {
    private let logger = Logger(subsystem: "dev.lunex.client.macos", category: "window.lifecycle")
    private weak var window: NSWindow?
    private let lifecycle: PlatformLifecycleState
    private var observers: [NSObjectProtocol] = []

    init(lifecycle: PlatformLifecycleState) {
        self.lifecycle = lifecycle
    }

    func attach(to window: NSWindow) {
        if self.window === window, !observers.isEmpty {
            refreshVisibility()
            refreshFocus()
            refreshDisplay()
            return
        }
        detach()
        self.window = window
        logger.info("Attached lifecycle monitor to window")

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
                    self?.refreshDisplay()
                }
            },
            center.addObserver(forName: NSWindow.didEndLiveResizeNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshDrawableSize()
                }
            },
            center.addObserver(forName: NSWindow.didResizeNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshDrawableSize()
                }
            },
            center.addObserver(forName: NSWindow.didChangeBackingPropertiesNotification, object: window, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshDisplay()
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
                    self?.refreshDisplay()
                }
            }
        ]

        refreshVisibility()
        refreshFocus()
        refreshDisplay()
        refreshDrawableSize()
        logger.info("Lifecycle ready: visible=\(self.lifecycle.isVisible, privacy: .public) focused=\(self.lifecycle.isFocused, privacy: .public) drawable=\(self.lifecycle.drawableSize.width, privacy: .public)x\(self.lifecycle.drawableSize.height, privacy: .public) EDR=\(self.lifecycle.headroom.current, privacy: .public)")
    }

    func detach() {
        let center = NotificationCenter.default
        observers.forEach(center.removeObserver)
        observers.removeAll()
        window = nil
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

    private func refreshDisplay() {
        lifecycle.displayID = window?.screen?.localizedName
        lifecycle.headroom = DisplayHeadroomReader.read(screen: window?.screen)
        logger.debug("Display changed; EDR current=\(self.lifecycle.headroom.current, privacy: .public) potential=\(self.lifecycle.headroom.potential, privacy: .public)")
        refreshDrawableSize()
        lifecycle.updateRenderPolicy()
    }

    private func refreshDrawableSize() {
        guard let window else { return }
        let scale = window.backingScaleFactor
        lifecycle.drawableSize = PixelSize(
            width: Int((window.contentView?.bounds.width ?? 0) * scale),
            height: Int((window.contentView?.bounds.height ?? 0) * scale)
        )
        logger.debug("Drawable changed: \(self.lifecycle.drawableSize.width, privacy: .public)x\(self.lifecycle.drawableSize.height, privacy: .public)")
        lifecycle.updateRenderPolicy()
    }
}

@MainActor
struct AppKitLifecycleAttachment: NSViewRepresentable {
    let lifecycle: PlatformLifecycleState

    func makeCoordinator() -> Coordinator {
        Coordinator(lifecycle: lifecycle)
    }

    func makeNSView(context: Context) -> WindowObservationView {
        let view = WindowObservationView()
        view.onWindowChange = { [weak coordinator = context.coordinator] window in
            guard let window else {
                coordinator?.monitor.detach()
                return
            }
            coordinator?.monitor.attach(to: window)
        }
        return view
    }

    func updateNSView(_ nsView: WindowObservationView, context: Context) {
        if let window = nsView.window {
            context.coordinator.monitor.attach(to: window)
        }
    }

    static func dismantleNSView(_ nsView: WindowObservationView, coordinator: Coordinator) {
        coordinator.monitor.detach()
        nsView.onWindowChange = nil
    }

    @MainActor
    final class Coordinator {
        let monitor: AppKitLifecycleMonitor

        init(lifecycle: PlatformLifecycleState) {
            monitor = AppKitLifecycleMonitor(lifecycle: lifecycle)
        }
    }
}

@MainActor
final class WindowObservationView: NSView {
    var onWindowChange: ((NSWindow?) -> Void)?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        onWindowChange?(window)
    }
}
#endif
