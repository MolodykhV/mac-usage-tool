import AppKit
import OSLog
import PlumageBarCore
import SwiftUI

@MainActor
final class StatusItemController: NSObject {

    nonisolated private static let log = Logger(
        subsystem: "com.molodykh.PlumageBar", category: "menubar")

    private let viewModel: DashboardViewModel
    private let settingsStore: SettingsStore
    private let onOpenSettings: () -> Void
    private var statusItem: NSStatusItem?
    private var panelController: PopoverPanelController<PopoverView>?
    private var rightClickMenu: NSMenu?
    private var appearanceObservation: NSKeyValueObservation?
    /// Captures every input that affects the rasterised icon. Compared via
    /// Equatable on each call to short-circuit the ImageRenderer hot path
    /// when integer-rounded values, threshold states, or visible metrics
    /// haven't actually changed since the previous tick.
    private var lastRenderState: MenuBarIconRenderState?
    private static let iconHeight: CGFloat = 22

    init(
        viewModel: DashboardViewModel,
        settingsStore: SettingsStore,
        onOpenSettings: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.settingsStore = settingsStore
        self.onOpenSettings = onOpenSettings
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
        let settingsItem = NSMenuItem(
            title: NSLocalizedString("menu.settings", comment: ""),
            action: #selector(openSettings(_:)),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(
            NSMenuItem(
                title: NSLocalizedString("menu.quit", comment: ""),
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            ))

        let panel = PopoverPanelController(
            rootView: PopoverView(
                viewModel: viewModel,
                settingsStore: settingsStore,
                onOpenSettings: { [weak self] in
                    self?.panelController?.close()
                    self?.onOpenSettings()
                }
            ),
            size: NSSize(width: Theme.popoverWidth + 16, height: 420)
        )

        self.statusItem = item
        self.panelController = panel
        self.rightClickMenu = menu

        renderIconImage()
        observeSnapshot()
        observeSettings()
        observeAppearance()

        Self.log.info("Status item installed")
    }

    func teardown() {
        panelController?.close()
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        appearanceObservation?.invalidate()
        appearanceObservation = nil
        statusItem = nil
        panelController = nil
        rightClickMenu = nil
        // If install() is ever re-invoked on the same instance, the cached
        // state must not short-circuit the first render against a fresh
        // status item that has no image set yet.
        lastRenderState = nil
    }

    /// Render the SwiftUI menu-bar view into an `NSImage` and assign it to the
    /// status item's button.
    ///
    /// When all metrics are below their warning bands the rendered image is
    /// a clean template that AppKit tints with the menu-bar foreground colour.
    /// As soon as any metric reaches warning or exceeded state we switch the
    /// image off `isTemplate` so the orange/red colour survives — and render
    /// the rest of the icon using the system's current `effectiveAppearance`
    /// so the surrounding icons and digits still match dark/light mode.
    private func renderIconImage() {
        let menuBarSettings = settingsStore.settings.menuBar
        let thresholds = settingsStore.settings.thresholds
        let snapshot = viewModel.latest
        let scheme = currentColorScheme()
        let coreScheme: MenuBarIconRenderState.ColorScheme =
            scheme == .dark ? .dark : .light

        let state = MenuBarIconRenderState.from(
            snapshot: snapshot,
            menuBar: menuBarSettings,
            thresholds: thresholds,
            scheme: coreScheme
        )
        if state == lastRenderState { return }
        lastRenderState = state

        let usesAccentColour = state.slots.contains { $0.state != .normal }
        let view = MenuBarIconView(
            snapshot: snapshot,
            metrics: menuBarSettings.visibleMetrics,
            ramFormat: menuBarSettings.ramFormat,
            thresholds: thresholds
        )
        .environment(\.colorScheme, scheme)
        .frame(height: Self.iconHeight)

        let renderer = ImageRenderer(content: view)
        renderer.scale =
            statusItem?.button?.window?.screen?.backingScaleFactor
            ?? NSScreen.main?.backingScaleFactor ?? 2

        guard let image = renderer.nsImage else { return }
        image.isTemplate = !usesAccentColour
        statusItem?.button?.image = image
    }

    private func currentColorScheme() -> ColorScheme {
        let appearance = statusItem?.button?.window?.effectiveAppearance ?? NSApp.effectiveAppearance
        let match = appearance.bestMatch(from: [.darkAqua, .vibrantDark, .aqua, .vibrantLight])
        switch match {
        case .darkAqua, .vibrantDark: return .dark
        default: return .light
        }
    }

    private func observeSnapshot() {
        withObservationTracking {
            _ = viewModel.latest
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.observeSnapshot()
                self.renderIconImage()
            }
        }
    }

    private func observeSettings() {
        withObservationTracking {
            _ = settingsStore.settings.menuBar
            _ = settingsStore.settings.thresholds
        } onChange: { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                self.observeSettings()
                self.renderIconImage()
            }
        }
    }

    private func observeAppearance() {
        appearanceObservation?.invalidate()
        appearanceObservation = NSApp.observe(\.effectiveAppearance, options: [.new]) {
            [weak self] _, _ in
            Task { @MainActor in self?.renderIconImage() }
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

    @objc
    private func openSettings(_ sender: Any?) {
        onOpenSettings()
    }

    private func showContextMenu(relativeTo button: NSStatusBarButton, with event: NSEvent) {
        guard let menu = rightClickMenu else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: button)
    }
}
