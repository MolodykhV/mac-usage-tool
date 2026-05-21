import Foundation
import PlumageBarCore
import SwiftUI

struct MenuBarIconView: View {
    let snapshot: Snapshot?
    let metrics: [MenuBarMetric]
    let ramFormat: RAMFormat
    let thresholds: ThresholdSettings

    /// Reserve enough horizontal space for the widest value string we expect
    /// so the layout never jitters as numbers cycle. 22pt fits both "100" in
    /// rounded-monospaced 11pt and a short abbreviated byte count like "8.2G".
    private static let valueWidth: CGFloat = 22

    private static let absoluteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.zeroPadsFractionDigits = false
        formatter.isAdaptive = true
        return formatter
    }()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(metrics) { metric in
                badge(for: metric)
            }
        }
    }

    @ViewBuilder
    private func badge(for metric: MenuBarMetric) -> some View {
        let state = state(for: metric)
        HStack(spacing: 3) {
            Image(systemName: metric.systemImageName)
                .font(Theme.menuBarSymbolFont)
                .foregroundStyle(.primary)
                .accessibilityHidden(true)
            Text(text(for: metric))
                .font(Theme.menuBarValueFont)
                .monospacedDigit()
                .foregroundStyle(state.color)
                .frame(width: Self.valueWidth, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("\(metric.accessibilityFallback) \(text(for: metric))")
        )
    }

    private func text(for metric: MenuBarMetric) -> String {
        if metric == .ram, ramFormat == .absolute, let bytes = snapshot?.ram.usedBytes {
            return Self.absoluteFormatter
                .string(fromByteCount: Int64(clamping: bytes))
                .replacingOccurrences(of: " ", with: "")
        }
        guard let value = metric.value(in: snapshot) else { return "—" }
        return String(format: "%.0f", value)
    }

    private func state(for metric: MenuBarMetric) -> ThresholdState {
        let threshold: Double
        switch metric {
        case .cpu: threshold = thresholds.cpuPercent
        case .gpu: threshold = thresholds.gpuPercent
        case .ram: threshold = thresholds.ramPercent
        }
        // RAM in absolute mode still uses the percentage value internally for
        // threshold checks — that's the field the user-facing slider edits.
        let percentValue = metric.value(in: snapshot)
        return ThresholdState(value: percentValue, threshold: threshold)
    }
}

#Preview("MenuBarIconView") {
    let snap = Snapshot(
        timestamp: Date(),
        cpu: .init(
            userPercent: 12, systemPercent: 5, idlePercent: 18, totalPercent: 82,
            perCoreTotalPercent: []
        ),
        ram: .init(
            totalBytes: 16_000_000_000, usedBytes: 14_400_000_000, freeBytes: 1_600_000_000,
            usedPercent: 90
        ),
        gpu: .init(utilizationPercent: 28)
    )
    return VStack(spacing: 8) {
        MenuBarIconView(
            snapshot: snap, metrics: MenuBarMetric.allCases, ramFormat: .percent,
            thresholds: .default
        )
        MenuBarIconView(
            snapshot: snap, metrics: MenuBarMetric.allCases, ramFormat: .absolute,
            thresholds: .default
        )
    }
    .padding(6)
    .background(.regularMaterial)
}
