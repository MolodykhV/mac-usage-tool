import AppKit
import OSLog
import PlumageBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    nonisolated private static let log = Logger(
        subsystem: "com.molodykh.PlumageBar", category: "app")

    private let viewModel = DashboardViewModel()
    private lazy var statusItemController = StatusItemController(viewModel: viewModel)
    private var metrics: (any MetricsProvider)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.log.info("PlumageBar \(PlumageBarCore.version, privacy: .public) starting up")

        let provider = LiveMetricsProvider(interval: .seconds(1))
        self.metrics = provider
        viewModel.bind(to: provider)
        statusItemController.install()

        Task.detached(priority: .utility) {
            await provider.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.log.info("PlumageBar terminating")
        // Process tear-down releases the CFTypeRef-backed IOReport subscription
        // and the sampling task cleanly; nothing async is needed here.
    }
}
