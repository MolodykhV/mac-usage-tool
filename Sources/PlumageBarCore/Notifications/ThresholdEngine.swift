public import Foundation

public struct ThresholdAlert: Sendable, Equatable {
    public enum Metric: String, Sendable, Codable, CaseIterable {
        case cpu
        case gpu
        case ram
    }

    public let metric: Metric
    public let value: Double
    public let threshold: Double
    public let timestamp: Date

    public init(metric: Metric, value: Double, threshold: Double, timestamp: Date) {
        self.metric = metric
        self.value = value
        self.threshold = threshold
        self.timestamp = timestamp
    }
}

public struct NotificationSettings: Codable, Sendable, Equatable {
    /// Master toggle. When false, no alerts are produced regardless of the
    /// per-metric flags.
    public var enabled: Bool
    public var cpu: Bool
    public var gpu: Bool
    public var ram: Bool

    public init(enabled: Bool = true, cpu: Bool = true, gpu: Bool = true, ram: Bool = true) {
        self.enabled = enabled
        self.cpu = cpu
        self.gpu = gpu
        self.ram = ram
    }

    public static let `default` = NotificationSettings()

    public func isEnabled(for metric: ThresholdAlert.Metric) -> Bool {
        guard enabled else { return false }
        switch metric {
        case .cpu: return cpu
        case .gpu: return gpu
        case .ram: return ram
        }
    }
}

/// Pure logic: given a stream of snapshots, decide when to alert the user.
///
/// Behaviour per metric:
/// - On each snapshot, the metric is either *exceeding* its threshold or not.
/// - The first snapshot that crosses the threshold starts an "episode".
/// - The engine fires exactly one alert per episode, once the metric has
///   been over the threshold for at least `sustainedSeconds`.
/// - The episode ends when the metric drops back to or below the threshold.
///   The next crossing starts a new episode and is eligible to fire again.
///
/// This dedup model prevents notification spam during sustained loads (no
/// repeated alerts every second while CPU pegged at 100%) while still
/// alerting on each new excursion.
public final class ThresholdEngine {

    private struct MetricState {
        var exceedingSince: Date?
        var notifiedAt: Date?
    }

    private var cpu = MetricState()
    private var gpu = MetricState()
    private var ram = MetricState()

    public init() {}

    public func process(
        snapshot: Snapshot,
        thresholds: ThresholdSettings,
        notifications: NotificationSettings
    ) -> [ThresholdAlert] {
        var alerts: [ThresholdAlert] = []

        if notifications.isEnabled(for: .cpu) {
            if let alert = process(
                metric: .cpu,
                value: snapshot.cpu.totalPercent,
                threshold: thresholds.cpuPercent,
                sustainedSeconds: thresholds.sustainedSeconds,
                at: snapshot.timestamp,
                state: &cpu
            ) {
                alerts.append(alert)
            }
        } else {
            cpu = MetricState()
        }

        if notifications.isEnabled(for: .gpu) {
            if let value = snapshot.gpu?.utilizationPercent {
                if let alert = process(
                    metric: .gpu,
                    value: value,
                    threshold: thresholds.gpuPercent,
                    sustainedSeconds: thresholds.sustainedSeconds,
                    at: snapshot.timestamp,
                    state: &gpu
                ) {
                    alerts.append(alert)
                }
            } else {
                // Missing GPU sample means the reader is disabled or this
                // hardware doesn't expose residency; treat as "not exceeding"
                // so we don't accidentally alert on stale state.
                gpu = MetricState()
            }
        } else {
            gpu = MetricState()
        }

        if notifications.isEnabled(for: .ram) {
            if let alert = process(
                metric: .ram,
                value: snapshot.ram.usedPercent,
                threshold: thresholds.ramPercent,
                sustainedSeconds: thresholds.sustainedSeconds,
                at: snapshot.timestamp,
                state: &ram
            ) {
                alerts.append(alert)
            }
        } else {
            ram = MetricState()
        }

        return alerts
    }

    public func reset() {
        cpu = MetricState()
        gpu = MetricState()
        ram = MetricState()
    }

    private func process(
        metric: ThresholdAlert.Metric,
        value: Double,
        threshold: Double,
        sustainedSeconds: Double,
        at timestamp: Date,
        state: inout MetricState
    ) -> ThresholdAlert? {
        guard value > threshold else {
            // Recovery: episode ends, next crossing will re-arm.
            state = MetricState()
            return nil
        }
        // If the wall clock jumped backwards (NTP correction, manual change)
        // the existing `exceedingSince` is in the future relative to the new
        // timestamp. Re-anchor the episode to "now" so it doesn't stall
        // indefinitely waiting for `elapsed >= sustainedSeconds`.
        if let since = state.exceedingSince, timestamp < since {
            state = MetricState(exceedingSince: timestamp, notifiedAt: nil)
        }
        if state.exceedingSince == nil {
            state.exceedingSince = timestamp
        }
        guard let since = state.exceedingSince else { return nil }
        let elapsed = max(0, timestamp.timeIntervalSince(since))
        guard elapsed >= sustainedSeconds else { return nil }
        // notifiedAt is the in-episode dedup gate — without it every snapshot
        // past the sustained window would re-fire.
        guard state.notifiedAt == nil else { return nil }
        state.notifiedAt = timestamp
        return ThresholdAlert(
            metric: metric,
            value: value,
            threshold: threshold,
            timestamp: timestamp
        )
    }
}
