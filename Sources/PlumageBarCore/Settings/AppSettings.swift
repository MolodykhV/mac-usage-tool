import Foundation

public struct AppSettings: Codable, Sendable, Equatable {
    public var menuBar: MenuBarSettings
    public var sampling: SamplingSettings
    public var thresholds: ThresholdSettings
    public var notifications: NotificationSettings
    public var autostart: Bool

    public init(
        menuBar: MenuBarSettings = .default,
        sampling: SamplingSettings = .default,
        thresholds: ThresholdSettings = .default,
        notifications: NotificationSettings = .default,
        autostart: Bool = false
    ) {
        self.menuBar = menuBar
        self.sampling = sampling
        self.thresholds = thresholds
        self.notifications = notifications
        self.autostart = autostart
    }

    // Tolerate older blobs that don't have a `notifications` key — pre-Stage 5
    // settings simply default to "all on".
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            menuBar: try container.decode(MenuBarSettings.self, forKey: .menuBar),
            sampling: try container.decode(SamplingSettings.self, forKey: .sampling),
            thresholds: try container.decode(ThresholdSettings.self, forKey: .thresholds),
            notifications: try container.decodeIfPresent(
                NotificationSettings.self, forKey: .notifications) ?? .default,
            autostart: try container.decodeIfPresent(Bool.self, forKey: .autostart) ?? false
        )
    }

    private enum CodingKeys: String, CodingKey {
        case menuBar, sampling, thresholds, notifications, autostart
    }

    public static let `default` = AppSettings()
}

public struct MenuBarSettings: Codable, Sendable, Equatable {
    /// Metrics shown in the menu bar, in user-chosen display order.
    public var visibleMetrics: [MenuBarMetric]
    /// How to render the RAM badge: percent of total or absolute usage.
    public var ramFormat: RAMFormat

    public init(
        visibleMetrics: [MenuBarMetric] = MenuBarMetric.allCases,
        ramFormat: RAMFormat = .percent
    ) {
        self.visibleMetrics = visibleMetrics
        self.ramFormat = ramFormat
    }

    public static let `default` = MenuBarSettings()
}

public enum RAMFormat: String, Codable, Sendable, CaseIterable {
    case percent
    case absolute
}

public struct SamplingSettings: Codable, Sendable, Equatable {
    /// Seconds between samples. Clamped to a safe range on load.
    public var intervalSeconds: Double

    public init(intervalSeconds: Double = 1.0) {
        self.intervalSeconds = Self.clamp(intervalSeconds)
    }

    // Decoded values are re-routed through the clamping initializer so a
    // tampered or future-format JSON blob can't drive the sampler into a
    // multi-hour sleep.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let raw = try container.decode(Double.self, forKey: .intervalSeconds)
        self.init(intervalSeconds: raw)
    }

    private enum CodingKeys: String, CodingKey {
        case intervalSeconds
    }

    public static let `default` = SamplingSettings()

    public static let allowedRange: ClosedRange<Double> = 1.0...10.0

    public static func clamp(_ value: Double) -> Double {
        min(max(allowedRange.lowerBound, value), allowedRange.upperBound)
    }
}

public struct ThresholdSettings: Codable, Sendable, Equatable {
    public var cpuPercent: Double
    public var ramPercent: Double
    public var gpuPercent: Double
    public var sustainedSeconds: Double

    public init(
        cpuPercent: Double = 80,
        ramPercent: Double = 90,
        gpuPercent: Double = 85,
        sustainedSeconds: Double = 30
    ) {
        self.cpuPercent = Self.clampPercent(cpuPercent)
        self.ramPercent = Self.clampPercent(ramPercent)
        self.gpuPercent = Self.clampPercent(gpuPercent)
        self.sustainedSeconds = Self.clampSustained(sustainedSeconds)
    }

    // Funnels decoded values back through the clamping initializer so an
    // out-of-range JSON blob can't bypass the validation the manual init
    // performs.
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            cpuPercent: try container.decode(Double.self, forKey: .cpuPercent),
            ramPercent: try container.decode(Double.self, forKey: .ramPercent),
            gpuPercent: try container.decode(Double.self, forKey: .gpuPercent),
            sustainedSeconds: try container.decode(Double.self, forKey: .sustainedSeconds)
        )
    }

    private enum CodingKeys: String, CodingKey {
        case cpuPercent, ramPercent, gpuPercent, sustainedSeconds
    }

    public static let `default` = ThresholdSettings()

    public static func clampPercent(_ v: Double) -> Double {
        min(max(0, v), 100)
    }

    public static func clampSustained(_ v: Double) -> Double {
        max(5, min(v, 600))
    }
}
