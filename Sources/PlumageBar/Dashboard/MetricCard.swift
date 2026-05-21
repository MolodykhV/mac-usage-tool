import SwiftUI

struct MetricCard: View {
    let title: LocalizedStringKey
    let systemImage: String
    let valueText: String
    var subtitle: String? = nil
    let series: [Double]
    var valueColor: Color = .primary

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemImage)
                .symbolRenderingMode(.hierarchical)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 22, alignment: .leading)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(title)
                        .font(Theme.cardTitleFont)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Spacer()
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if let subtitle {
                            Text(subtitle)
                                .font(.system(size: 10, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.tertiary)
                        }
                        Text(valueText)
                            .font(Theme.cardValueFont)
                            .monospacedDigit()
                            .foregroundStyle(valueColor)
                    }
                }
                Sparkline(values: series)
            }
        }
        .padding(.horizontal, Theme.cardPaddingHorizontal)
        .padding(.vertical, Theme.cardPaddingVertical)
        .frame(maxWidth: .infinity)
        .plumageGlass()
    }
}

#Preview("MetricCard variants") {
    VStack(spacing: 8) {
        MetricCard(
            title: "CPU",
            systemImage: "cpu",
            valueText: "12%",
            series: (0..<60).map { i in 10 + 5 * sin(Double(i) / 4) }
        )
        MetricCard(
            title: "GPU",
            systemImage: "display",
            valueText: "—",
            series: []
        )
        MetricCard(
            title: "Memory",
            systemImage: "memorychip",
            valueText: "62%",
            series: (0..<60).map { _ in Double.random(in: 50...70) }
        )
    }
    .padding()
    .frame(width: 280)
}
