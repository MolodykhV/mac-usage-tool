import AppKit
import OSLog
import PlumageBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    nonisolated private static let log = Logger(
        subsystem: "com.molodykh.PlumageBar", category: "app")
    private var statusItem: NSStatusItem?
    private var metrics: (any MetricsProvider)?
    private var streamObserverTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.log.info("PlumageBar \(PlumageBarCore.version, privacy: .public) starting up")
        installStatusItem()
        startMetrics()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // AppKit returns from this delegate and calls exit() synchronously;
        // a detached async cleanup would never run. The process tear-down
        // releases the CFTypeRef-backed IOReport subscription cleanly, so
        // no explicit work is required here beyond logging.
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

    private func startMetrics() {
        let provider = LiveMetricsProvider(interval: .seconds(1))
        self.metrics = provider
        let stream = provider.snapshots
        streamObserverTask = Task.detached(priority: .utility) { [weak provider] in
            await provider?.start()
            for await snap in stream {
                Self.log.debug(
                    "snapshot cpu=\(snap.cpu.totalPercent, privacy: .public)% ram=\(snap.ram.usedPercent, privacy: .public)% gpu=\(snap.gpu?.utilizationPercent ?? -1, privacy: .public)%"
                )
            }
        }
    }
}
