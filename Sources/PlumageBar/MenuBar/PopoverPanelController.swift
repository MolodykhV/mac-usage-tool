import AppKit
import SwiftUI

/// A Control-Center-style detached panel. NSPopover always installs its own
/// vibrancy chrome around content, which stacks visually on top of the cards'
/// Liquid Glass effect. A borderless NSPanel with a clear background lets each
/// card render directly against the desktop, matching the floating-tile look
/// Apple uses for Control Center on macOS 26.
@MainActor
final class PopoverPanelController<Root: View>: NSObject {

    private let panel: NSPanel
    private let hostingController: NSHostingController<Root>
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var willCloseObserver: (any NSObjectProtocol)?

    init(rootView: Root, size: NSSize) {
        let host = NSHostingController(rootView: rootView)
        host.view.frame = NSRect(origin: .zero, size: size)

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.level = .popUpMenu
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.animationBehavior = .utilityWindow
        panel.contentViewController = host

        self.panel = panel
        self.hostingController = host
        super.init()

        // If AppKit closes the panel for any reason (screen change, app hide,
        // user closing the window via shortcut), tear down our event monitors
        // so they don't keep eating Escape system-wide.
        willCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.removeMonitors()
            }
        }
    }

    // No explicit deinit: the willClose observer block captures `self` weakly,
    // so when this controller is deallocated the block becomes a no-op even if
    // NotificationCenter still holds the registration. AppKit deallocates the
    // panel itself when this controller goes away, which fires willClose and
    // tears down event monitors.

    var isShown: Bool { panel.isVisible }

    func show(relativeTo button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        let buttonRectInScreen = buttonWindow.convertToScreen(
            button.convert(button.bounds, to: nil)
        )

        // Anchor under the button, centred horizontally. Keep at least an 8pt
        // margin from screen edges so the shadow doesn't get cut off.
        let panelSize = panel.frame.size
        var finalOrigin = NSPoint(
            x: buttonRectInScreen.midX - panelSize.width / 2,
            y: buttonRectInScreen.minY - panelSize.height - 6
        )
        if let screen = button.window?.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            let clampedX = max(
                visible.minX + 8, min(finalOrigin.x, visible.maxX - panelSize.width - 8))
            let clampedY = max(visible.minY + 8, finalOrigin.y)
            finalOrigin = NSPoint(x: clampedX, y: clampedY)
        }

        // Slide in from slightly above the final position with a quick fade.
        // 10pt of travel + 0.18s easeOut feels like a Control-Center reveal
        // without being slow enough to feel laggy.
        let startOrigin = NSPoint(x: finalOrigin.x, y: finalOrigin.y + 10)
        panel.setFrameOrigin(startOrigin)
        panel.alphaValue = 0
        panel.orderFrontRegardless()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            panel.animator().setFrameOrigin(finalOrigin)
            panel.animator().alphaValue = 1
        }
        installOutsideDismissMonitors()
    }

    func close() {
        removeMonitors()
        let panel = self.panel
        NSAnimationContext.runAnimationGroup(
            { context in
                context.duration = 0.12
                context.timingFunction = CAMediaTimingFunction(name: .easeIn)
                panel.animator().alphaValue = 0
            },
            completionHandler: {
                // AppKit's completion is delivered on the main thread, but
                // strict concurrency doesn't know that. Re-dispatch onto
                // MainActor via the main dispatch queue so we don't lie to
                // the compiler — and so we don't crash if a future SDK starts
                // delivering completion off-main.
                DispatchQueue.main.async {
                    panel.orderOut(nil)
                    panel.alphaValue = 1
                }
            }
        )
    }

    func toggle(relativeTo button: NSStatusBarButton) {
        if isShown {
            close()
        } else {
            show(relativeTo: button)
        }
    }

    private func installOutsideDismissMonitors() {
        removeMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in
            self?.close()
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) {
            [weak self] event in
            if event.keyCode == 53 {  // Escape
                self?.close()
                return nil
            }
            return event
        }
    }

    private func removeMonitors() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
    }
}
