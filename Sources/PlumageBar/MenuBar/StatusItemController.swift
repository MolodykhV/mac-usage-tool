import AppKit
import OSLog
import PlumageBarCore
import SwiftUI

@MainActor
final class StatusItemController: NSObject {

    nonisolated private static let log = Logger(
        subsystem: "com.molodykh.PlumageBar", category: "menubar")

    private let viewModel: DashboardViewModel
    private var statusItem: NSStatusItem?
    private var panelController: PopoverPanelController<PopoverView>?
    private var rightClickMenu: NSMenu?
    private let displayMetrics: [MenuBarMetric] = MenuBarMetric.allCases
    private static let iconHeight: CGFloat = 22

    init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = item.button {
            button.image = nil
            button.imagePosition = .imageOnly
            button.target = self
            button.action = #selector(handleButtonClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Quit Plumage Bar",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            ))

        let panel = PopoverPanelController(
            rootView: PopoverView(viewModel: viewModel),
            size: NSSize(width: Theme.popoverWidth + 16, height: 400)
        )

        self.statusItem = item
        self.panelController = panel
        self.rightClickMenu = menu

        renderIconImage()
        observeViewModel()

        Self.log.info("Status item installed")
    }

    func teardown() {
        panelController?.close()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        panelController = nil
        rightClickMenu = nil
    }

    /// Render the SwiftUI menu-bar view into an `NSImage` and assign it to the
    /// status item's button. Using a template image lets AppKit handle the
    /// system menu-bar padding, dark/light tinting, and click hit-testing
    /// without us fighting auto-layout inside `NSStatusBarButton`.
    private func renderIconImage() {
        let view = MenuBarIconView(
            snapshot: viewModel.latest,
            metrics: displayMetrics,
            renderForTemplate: true
        )
        .frame(height: Self.iconHeight)

        let renderer = ImageRenderer(content: view)
        // Use the screen the menu-bar button actually lives on. For LSUIElement
        // apps, `NSScreen.main` is whichever screen owns the focused app, which
        // can differ from the screen containing the status item on multi-display
        // setups — and that would produce wrong scale (blurry icons).
        renderer.scale =
            statusItem?.button?.window?.screen?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor ?? 2

        guard let image = renderer.nsImage else { return }
        image.isTemplate = true
        statusItem?.button?.image = image
    }

    // The menu bar icon is an NSImage produced by ImageRenderer, which is not
    // hooked into SwiftUI's body-evaluation cycle. We drive refreshes
    // manually: each onChange re-arms the observer first (so we never miss a
    // tick during the render call), then re-renders. The outer `[weak self]`
    // suffices — the inner Task closure is owned by the outer captured self.
    private func observeViewModel() {
        withObservationTracking {
            _ = viewModel.latest
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.observeViewModel()
                self.renderIconImage()
            }
        }
    }

    @objc
    private func handleButtonClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            panelController?.toggle(relativeTo: sender)
            return
        }
        switch event.type {
        case .rightMouseUp:
            showContextMenu(relativeTo: sender, with: event)
        default:
            panelController?.toggle(relativeTo: sender)
        }
    }

    private func showContextMenu(relativeTo button: NSStatusBarButton, with event: NSEvent) {
        guard let menu = rightClickMenu else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }
}
