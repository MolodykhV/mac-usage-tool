import PlumageBarCore
import SwiftUI

struct ProcessListView: View {
    let report: ProcessReport?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            section(
                title: "popover.section.topCPU",
                processes: report?.topByCPU ?? [],
                trailing: { String(format: "%.0f%%", $0.cpuPercent) }
            )
            section(
                title: "popover.section.topMemory",
                processes: report?.topByMemory ?? [],
                trailing: { Self.formatBytes($0.residentBytes) }
            )
        }
        .padding(.horizontal, Theme.cardPaddingHorizontal)
        .padding(.vertical, Theme.cardPaddingVertical)
        .frame(maxWidth: .infinity, alignment: .leading)
        .plumageGlass()
    }

    @ViewBuilder
    private func section(
        title: LocalizedStringKey,
        processes: [ProcessUsage],
        trailing: @escaping (ProcessUsage) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(Theme.sectionTitleFont)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            if processes.isEmpty {
                Text("—")
                    .font(Theme.processNameFont)
                    .foregroundStyle(.tertiary)
            } else {
                ForEach(processes) { process in
                    HStack(spacing: 8) {
                        Text(process.name)
                            .font(Theme.processNameFont)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer(minLength: 8)
                        Text(trailing(process))
                            .font(Theme.processValueFont)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private static let byteFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useMB, .useGB]
        return formatter
    }()

    static func formatBytes(_ bytes: UInt64) -> String {
        byteFormatter.string(fromByteCount: Int64(clamping: bytes))
    }
}

#Preview("ProcessListView samples") {
    ProcessListView(
        report: ProcessReport(
            topByCPU: [
                .init(pid: 1, name: "Xcode", cpuPercent: 85, residentBytes: 3_500_000_000),
                .init(pid: 2, name: "Safari", cpuPercent: 30, residentBytes: 2_500_000_000),
                .init(pid: 3, name: "WindowServer", cpuPercent: 12, residentBytes: 500_000_000),
            ],
            topByMemory: [
                .init(pid: 1, name: "Xcode", cpuPercent: 85, residentBytes: 3_500_000_000),
                .init(pid: 2, name: "Safari", cpuPercent: 30, residentBytes: 2_500_000_000),
                .init(pid: 4, name: "kernel_task", cpuPercent: 5, residentBytes: 1_000_000_000),
            ]
        )
    )
    .padding()
    .frame(width: 280)
}
