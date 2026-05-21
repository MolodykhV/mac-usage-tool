/// Value snapshot of every input that affects the rasterised menu-bar icon.
///
/// The `StatusItemController` builds one of these on every snapshot tick
/// and compares to the previously rendered state. If they match, the
/// `ImageRenderer` call is skipped — which is the common idle-machine case
/// where integer-rounded values stay flat between samples.
///
/// The struct lives in `PlumageBarCore` (rather than next to the controller)
/// so it can be unit-tested in isolation: every visual input needs to be in
/// the state, and we want a test for each independent axis.
public struct MenuBarIconRenderState: Sendable, Hashable {

    public enum ColorScheme: Sendable, Hashable, CaseIterable {
        case light
        case dark
    }

    public struct Slot: Sendable, Hashable {
        public let metric: MenuBarMetric
        /// `Int` rounded percentage shown in the badge, or nil when no
        /// snapshot is available yet / GPU sample missing.
        public let roundedPercent: Int?
        /// 100 MB tier of the RAM byte count, only populated when the user
        /// asked for `.absolute` RAM format. ByteCountFormatter shifts to GB
        /// units at this resolution, so smaller deltas don't change the
        /// rendered text.
        public let absoluteByteTier: Int?
        public let state: ThresholdState

        public init(
            metric: MenuBarMetric,
            roundedPercent: Int?,
            absoluteByteTier: Int?,
            state: ThresholdState
        ) {
            self.metric = metric
            self.roundedPercent = roundedPercent
            self.absoluteByteTier = absoluteByteTier
            self.state = state
        }
    }

    public let scheme: ColorScheme
    public let ramFormat: RAMFormat
    public let slots: [Slot]

    public init(scheme: ColorScheme, ramFormat: RAMFormat, slots: [Slot]) {
        self.scheme = scheme
        self.ramFormat = ramFormat
        self.slots = slots
    }

    public static func from(
        snapshot: Snapshot?,
        menuBar: MenuBarSettings,
        thresholds: ThresholdSettings,
        scheme: ColorScheme
    ) -> MenuBarIconRenderState {
        let slots = menuBar.visibleMetrics.map { metric -> Slot in
            let value = metric.value(in: snapshot)
            let rounded = value.map { Int($0.rounded()) }
            var absTier: Int? = nil
            if metric == .ram, menuBar.ramFormat == .absolute,
                let bytes = snapshot?.ram.usedBytes
            {
                // 100 MB buckets: matches the ByteCountFormatter granularity
                // once usage crosses ~1 GB (the only realistic regime on
                // 8-128 GB Macs). At sub-GB the rendered text changes less
                // than once per bucket, so a few "missed" tiny renders are
                // imperceptible.
                absTier = Int(bytes / 100_000_000)
            }
            let threshold: Double
            switch metric {
            case .cpu: threshold = thresholds.cpuPercent
            case .gpu: threshold = thresholds.gpuPercent
            case .ram: threshold = thresholds.ramPercent
            }
            return Slot(
                metric: metric,
                roundedPercent: rounded,
                absoluteByteTier: absTier,
                state: ThresholdState(value: value, threshold: threshold)
            )
        }
        return MenuBarIconRenderState(
            scheme: scheme, ramFormat: menuBar.ramFormat, slots: slots)
    }
}
