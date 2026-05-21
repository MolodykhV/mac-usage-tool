import PlumageBarCore
import SwiftUI

enum MenuBarMetric: String, CaseIterable, Identifiable, Sendable {
    case cpu
    case gpu
    case ram

    var id: String { rawValue }

    var systemImageName: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "display"
        case .ram: return "memorychip"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .ram: return "Memory"
        }
    }

    func value(in snapshot: Snapshot?) -> Double? {
        guard let snapshot else { return nil }
        switch self {
        case .cpu: return snapshot.cpu.totalPercent
        case .gpu: return snapshot.gpu?.utilizationPercent
        case .ram: return snapshot.ram.usedPercent
        }
    }
}

struct MenuBarIconView: View {
    let snapshot: Snapshot?
    let metrics: [MenuBarMetric]

    /// Whether to force black foreground for NSImage `isTemplate` rendering.
    /// When true, all foreground elements render in pure black so the system
    /// can tint them correctly in the menu bar. SwiftUI previews leave this
    /// off so the view looks natural.
    var renderForTemplate: Bool = false

    /// Reserve enough horizontal space for "100" so the layout never jitters
    /// as percentages cycle from one to three digits. Leading alignment keeps
    /// the digits next to their own icon rather than the neighbour's.
    private static let valueWidth: CGFloat = 18

    var body: some View {
        HStack(spacing: 5) {
            ForEach(metrics) { metric in
                badge(for: metric)
            }
        }
    }

    @ViewBuilder
    private func badge(for metric: MenuBarMetric) -> some View {
        HStack(spacing: 3) {
            Image(systemName: metric.systemImageName)
                .font(Theme.menuBarSymbolFont)
                .foregroundStyle(renderForTemplate ? AnyShapeStyle(.black) : AnyShapeStyle(.primary))
                .accessibilityHidden(true)
            Text(text(for: metric))
                .font(Theme.menuBarValueFont)
                .monospacedDigit()
                .foregroundStyle(renderForTemplate ? AnyShapeStyle(.black) : AnyShapeStyle(.primary))
                .frame(width: Self.valueWidth, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            Text("\(metric.accessibilityLabel) \(text(for: metric)) percent")
        )
    }

    private func text(for metric: MenuBarMetric) -> String {
        guard let value = metric.value(in: snapshot) else { return "—" }
        return String(format: "%.0f", value)
    }
}

#Preview("MenuBarIconView CPU+GPU+RAM") {
    let snap = Snapshot(
        timestamp: Date(),
        cpu: .init(
            userPercent: 12, systemPercent: 5, idlePercent: 83, totalPercent: 17,
            perCoreTotalPercent: []),
        ram: .init(
            totalBytes: 16_000_000_000, usedBytes: 10_000_000_000, freeBytes: 6_000_000_000,
            usedPercent: 62),
        gpu: .init(utilizationPercent: 28)
    )
    return MenuBarIconView(snapshot: snap, metrics: MenuBarMetric.allCases)
        .padding(6)
        .background(.regularMaterial)
}
