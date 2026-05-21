import AppKit
import OSLog
import PlumageBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private static let log = Logger(subsystem: "com.molodykh.PlumageBar", category: "app")
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.log.info("PlumageBar \(PlumageBarCore.version, privacy: .public) starting up")
        installStatusItem()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.log.info("PlumageBar terminating")
    }

    private func installStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = item.button {
            button.image = NSImage(
                systemSymbolName: "gauge.with.dots.needle.50percent",
                accessibilityDescription: "Plumage Bar"
            )
            button.imagePosition = .imageOnly
        }

        let menu = NSMenu()
        menu.addItem(
            NSMenuItem(
                title: "Quit Plumage Bar",
                action: #selector(NSApplication.terminate(_:)),
                keyEquivalent: "q"
            ))
        item.menu = menu

        self.statusItem = item
    }
}
