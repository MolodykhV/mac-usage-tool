import AppKit
import PlumageBarCore
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject {

    private let store: SettingsStore
    private let autostartManager: AutostartManager
    private var window: NSWindow?

    init(store: SettingsStore, autostartManager: AutostartManager) {
        self.store = store
        self.autostartManager = autostartManager
    }

    func show() {
        if let window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(
            rootView: SettingsView(store: store, autostartManager: autostartManager)
        )
        let newWindow = NSWindow(contentViewController: hosting)
        newWindow.title = NSLocalizedString("settings.window.title", comment: "")
        newWindow.styleMask = [.titled, .closable]
        newWindow.isReleasedWhenClosed = false
        newWindow.center()
        newWindow.delegate = self
        self.window = newWindow
        newWindow.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

extension SettingsWindowController: NSWindowDelegate {
    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor [weak self] in
            self?.window = nil
        }
    }
}
