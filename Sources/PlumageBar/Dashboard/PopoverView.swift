import PlumageBarCore
import SwiftUI

struct PopoverView: View {
    @Bindable var viewModel: DashboardViewModel
    @Bindable var settingsStore: SettingsStore
    var onOpenSettings: () -> Void

    private static let memoryFormatter: ByteCountFormatter = {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        formatter.allowedUnits = [.useGB, .useMB]
        formatter.zeroPadsFractionDigits = true
        return formatter
    }()

    var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            settingsButton

            MetricCard(
                title: "metric.cpu",
                systemImage: "cpu",
                valueText: percent(viewModel.latest?.cpu.totalPercent),
                series: viewModel.history.cpuTotalSeries(),
                valueColor: state(
                    value: viewModel.latest?.cpu.totalPercent,
                    threshold: settingsStore.settings.thresholds.cpuPercent
                ).color
            )

            if viewModel.latest?.gpu != nil {
                MetricCard(
                    title: "metric.gpu",
                    systemImage: "display",
                    valueText: percent(viewModel.latest?.gpu?.utilizationPercent),
                    series: viewModel.history.gpuSeries(),
                    valueColor: state(
                        value: viewModel.latest?.gpu?.utilizationPercent,
                        threshold: settingsStore.settings.thresholds.gpuPercent
                    ).color
                )
            }

            MetricCard(
                title: "metric.ram",
                systemImage: "memorychip",
                valueText: percent(viewModel.latest?.ram.usedPercent),
                subtitle: ramAbsolute(viewModel.latest?.ram),
                series: viewModel.history.ramUsedSeries(),
                valueColor: state(
                    value: viewModel.latest?.ram.usedPercent,
                    threshold: settingsStore.settings.thresholds.ramPercent
                ).color
            )

            ProcessListView(report: viewModel.latest?.processes)
        }
        .padding(Theme.popoverPadding)
        .frame(width: Theme.popoverWidth)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color.clear)
    }

    private var settingsButton: some View {
        Button(action: onOpenSettings) {
            Image(systemName: "gearshape")
                .font(.system(size: 13, weight: .medium))
                .symbolRenderingMode(.hierarchical)
                .padding(6)
        }
        .buttonStyle(.plain)
        .background(
            Circle().fill(.thinMaterial)
        )
        .overlay(
            Circle().stroke(Color.primary.opacity(0.12), lineWidth: 0.5)
        )
        .accessibilityLabel(Text("menu.settings"))
        .help(Text("menu.settings"))
    }

    private func percent(_ value: Double?) -> String {
        guard let value else { return "—" }
        return String(format: "%.0f%%", value)
    }

    private func ramAbsolute(_ ram: RAMUsage?) -> String? {
        guard let ram, ram.totalBytes > 0 else { return nil }
        let used = Self.memoryFormatter.string(fromByteCount: Int64(clamping: ram.usedBytes))
        let total = Self.memoryFormatter.string(fromByteCount: Int64(clamping: ram.totalBytes))
        return "\(used) / \(total)"
    }

    private func state(value: Double?, threshold: Double) -> ThresholdState {
        ThresholdState(value: value, threshold: threshold)
    }
}

#Preview("PopoverView with synthetic data") {
    let vm = DashboardViewModel()
    let store = SettingsStore(
        defaults: UserDefaults(suiteName: "preview-\(UUID().uuidString)") ?? .standard,
        key: "AppSettings.v1"
    )
    let cpu = CPUUsage(
        userPercent: 8, systemPercent: 4, idlePercent: 12, totalPercent: 88,
        perCoreTotalPercent: []
    )
    let ram = RAMUsage(
        totalBytes: 16_000_000_000,
        usedBytes: 9_900_000_000,
        freeBytes: 6_100_000_000,
        usedPercent: 62
    )
    let gpu = GPUUsage(utilizationPercent: 92)
    let processes = ProcessReport(
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
    for i in 0..<40 {
        vm.history.append(
            Snapshot(
                timestamp: Date().addingTimeInterval(Double(i)),
                cpu: cpu, ram: ram, gpu: gpu, processes: processes
            )
        )
    }
    return PopoverView(viewModel: vm, settingsStore: store, onOpenSettings: {})
}
