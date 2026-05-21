import AppKit
import OSLog
import PlumageBarCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    nonisolated private static let log = Logger(
        subsystem: "com.molodykh.PlumageBar", category: "app")

    private let settingsStore = SettingsStore()
    private let viewModel = DashboardViewModel()
    private let autostartManager = AutostartManager()
    private lazy var settingsWindowController = SettingsWindowController(
        store: settingsStore, autostartManager: autostartManager)
    private lazy var statusItemController = StatusItemController(
        viewModel: viewModel,
        settingsStore: settingsStore,
        onOpenSettings: { [weak self] in self?.openSettings() }
    )
    private var metrics: LiveMetricsProvider?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.log.info("PlumageBar \(PlumageBarCore.version, privacy: .public) starting up")

        let initialInterval = Duration.seconds(settingsStore.settings.sampling.intervalSeconds)
        let provider = LiveMetricsProvider(interval: initialInterval)
        self.metrics = provider
        viewModel.bind(to: provider)
        statusItemController.install()

        Task.detached(priority: .utility) {
            await provider.start()
        }
        observeIntervalChanges()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.log.info("PlumageBar terminating")
    }

    private func openSettings() {
        settingsWindowController.show()
    }

    /// Propagate sampling-interval changes from settings into the live actor.
    /// Other UI-level settings (visible metrics, RAM format) are observed
    /// inside StatusItemController; only the sampler needs an explicit hand-
    /// off because it owns its own timer task.
    private func observeIntervalChanges() {
        withObservationTracking {
            _ = settingsStore.settings.sampling.intervalSeconds
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observeIntervalChanges()
                guard let metrics = self.metrics else { return }
                let newInterval = Duration.seconds(
                    self.settingsStore.settings.sampling.intervalSeconds)
                await metrics.setInterval(newInterval)
            }
        }
    }
}
