#if os(macOS)
import AppKit

@MainActor
final class AppKitLifecycleMonitor {
    private weak var window: NSWindow?
    private let lifecycle: PlatformLifecycleState
    private var observers: [NSObjectProtocol] = []

    init(lifecycle: PlatformLifecycleState) {
        self.lifecycle = lifecycle
    }

    func attach(to window: NSWindow) {
        detach()
        self.window = window

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
            center.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in
                    self?.refreshDisplay()
                }
            }
        ]

        refreshVisibility()
        refreshDisplay()
        refreshDrawableSize()
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
        lifecycle.updateRenderPolicy()
    }

    private func setFocused(_ focused: Bool) {
        lifecycle.isFocused = focused
        lifecycle.updateRenderPolicy()
    }

    private func refreshDisplay() {
        lifecycle.displayID = window?.screen?.localizedName
        lifecycle.updateRenderPolicy()
    }

    private func refreshDrawableSize() {
        guard let window else { return }
        let scale = window.backingScaleFactor
        lifecycle.drawableSize = PixelSize(
            width: Int((window.contentView?.bounds.width ?? 0) * scale),
            height: Int((window.contentView?.bounds.height ?? 0) * scale)
        )
    }
}
#endif
