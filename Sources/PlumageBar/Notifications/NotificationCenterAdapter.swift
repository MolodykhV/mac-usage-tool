import AppKit
import Foundation
import OSLog
import Observation
import PlumageBarCore
import UserNotifications

@MainActor
@Observable
final class NotificationCenterAdapter {

    nonisolated private static let log = Logger(
        subsystem: "com.molodykh.PlumageBar", category: "notifications")

    @ObservationIgnored private let center = UNUserNotificationCenter.current()
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional
    }

    /// Status localization key for the settings UI to map through xcstrings.
    var statusLocalizationKey: String {
        switch authorizationStatus {
        case .authorized: return "notifications.status.authorized"
        case .denied: return "notifications.status.denied"
        case .provisional: return "notifications.status.provisional"
        case .notDetermined: return "notifications.status.notDetermined"
        case .ephemeral: return "notifications.status.ephemeral"
        @unknown default: return "notifications.status.notDetermined"
        }
    }

    /// Asks the system to prompt for permission. Apple silently denies for
    /// ad-hoc-signed apps; we refresh the cached status afterwards so the UI
    /// can tell the user to grant manually in System Settings.
    func requestAuthorization() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            Self.log.info("UN requestAuthorization returned granted=\(granted, privacy: .public)")
        } catch {
            Self.log.error(
                "UN authorization failed: \(String(describing: error), privacy: .public)")
        }
        await refreshStatus()
    }

    func refreshStatus() async {
        let settings = await center.notificationSettings()
        self.authorizationStatus = settings.authorizationStatus
        Self.log.info(
            "UN status=\(self.authorizationStatus.rawValue, privacy: .public)")
    }

    func deliver(_ alert: ThresholdAlert) {
        guard isAuthorized else {
            Self.log.debug("Suppressing alert (not authorized)")
            return
        }
        let request = UNNotificationRequest(
            identifier: "threshold.\(alert.metric.rawValue)",
            content: makeContent(
                titleKey: titleKey(for: alert.metric),
                value: alert.value,
                threshold: alert.threshold),
            trigger: nil
        )
        Task { [center] in
            do {
                try await center.add(request)
            } catch {
                Self.log.error(
                    "Delivery failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    /// Sends a sample notification with the same content the real engine
    /// would. Bypasses the authorization gate for diagnostics: if delivery
    /// is silently dropped, the user sees nothing — which is itself the
    /// signal that they need to grant permission in System Settings.
    func sendTestNotification() {
        // Stable identifier so repeated taps replace the previous test instead
        // of stacking up in Notification Center.
        let request = UNNotificationRequest(
            identifier: "threshold.test",
            content: makeContent(titleKey: "alert.cpu.title", value: 95, threshold: 80),
            trigger: nil
        )
        Task { [center] in
            try? await center.add(request)
        }
    }

    private func makeContent(
        titleKey: String, value: Double, threshold: Double
    )
        -> UNMutableNotificationContent
    {
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString(titleKey, comment: "")
        content.body = String(
            format: NSLocalizedString("alert.body", comment: ""),
            value,
            threshold
        )
        content.sound = .default
        // `.active` is the default but stating it makes Focus modes treat the
        // alert as a regular interruption rather than potentially silencing
        // it. `relevanceScore` raises ranking inside Notification Center so
        // the user sees the latest threshold breach at the top.
        content.interruptionLevel = .active
        content.relevanceScore = 1.0
        return content
    }

    /// Opens the system Notifications panel for this app so the user can
    /// grant permission when our in-app prompt was suppressed (typical for
    /// ad-hoc-signed development builds).
    func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }

    private func titleKey(for metric: ThresholdAlert.Metric) -> String {
        switch metric {
        case .cpu: return "alert.cpu.title"
        case .gpu: return "alert.gpu.title"
        case .ram: return "alert.ram.title"
        }
    }
}
