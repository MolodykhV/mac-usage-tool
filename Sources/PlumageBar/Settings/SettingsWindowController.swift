import AppKit
import PlumageBarCore
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject {

    private let store: SettingsStore
    private let autostartManager: AutostartManager
    private let notificationAdapter: NotificationCenterAdapter
    private var window: NSWindow?

    init(
        store: SettingsStore,
        autostartManager: AutostartManager,
        notificationAdapter: NotificationCenterAdapter
    ) {
        self.store = store
        self.autostartManager = autostartManager
        self.notificationAdapter = notificationAdapter
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(
                rootView: SettingsView(
                    store: store,
                    autostartManager: autostartManager,
                    notificationAdapter: notificationAdapter
                )
            )
            let newWindow = NSWindow(contentViewController: hosting)
            newWindow.title = NSLocalizedString("settings.window.title", comment: "")
            newWindow.styleMask = [.titled, .closable]
            newWindow.isReleasedWhenClosed = false
            newWindow.center()
            newWindow.delegate = self
            self.window = newWindow
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // Re-poll authorization every time the user opens the panel so the
        // status reflects whatever they may have changed in System Settings,
        // including when an already-created window is being brought forward
        // from hidden state.
        Task { [notificationAdapter] in
            await notificationAdapter.refreshStatus()
        }
    }
}

extension SettingsWindowController: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.window = nil
        }
    }
}
