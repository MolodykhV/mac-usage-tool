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
    private let thresholdEngine = ThresholdEngine()
    private let notificationAdapter = NotificationCenterAdapter()
    private lazy var settingsWindowController = SettingsWindowController(
        store: settingsStore,
        autostartManager: autostartManager,
        notificationAdapter: notificationAdapter
    )
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

        Task {
            await self.notificationAdapter.requestAuthorization()
        }

        observeIntervalChanges()
        observeSettingsForEngine()
        observeSnapshotsForEngine()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.log.info("PlumageBar terminating")
    }

    private func openSettings() {
        settingsWindowController.show()
    }

    /// Propagate sampling-interval changes from settings into the live actor.
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

    /// Drop any in-flight episodes when the user changes thresholds or toggles
    /// notification settings — otherwise a tightened threshold could fire
    /// retroactively against history collected under the old setting. The
    /// trade-off is that tightening a threshold below the current reading
    /// won't alert until the new value has been sustained for the full dwell
    /// time. Intentional: matches the "notify on sustained excursion"
    /// contract rather than "notify on any current breach".
    private func observeSettingsForEngine() {
        withObservationTracking {
            _ = settingsStore.settings.thresholds
            _ = settingsStore.settings.notifications
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.observeSettingsForEngine()
                self.thresholdEngine.reset()
            }
        }
    }

    /// Feed every snapshot into the threshold engine and deliver any alerts
    /// it returns. The view model is the canonical consumer of the stream; we
    /// piggyback on its @Observable `latest` to avoid spawning a second
    /// AsyncStream subscriber.
    private func observeSnapshotsForEngine() {
        withObservationTracking {
            _ = viewModel.latest
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self, let snapshot = self.viewModel.latest else { return }
                self.observeSnapshotsForEngine()
                let alerts = self.thresholdEngine.process(
                    snapshot: snapshot,
                    thresholds: self.settingsStore.settings.thresholds,
                    notifications: self.settingsStore.settings.notifications
                )
                for alert in alerts {
                    self.notificationAdapter.deliver(alert)
                }
            }
        }
    }
}
