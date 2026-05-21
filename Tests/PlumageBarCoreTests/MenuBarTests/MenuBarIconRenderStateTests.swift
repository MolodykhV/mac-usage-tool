import Foundation
import Testing

@testable import PlumageBarCore

@Suite("MenuBarIconRenderState equality")
struct MenuBarIconRenderStateTests {

    private let menuBar = MenuBarSettings(
        visibleMetrics: [.cpu, .gpu, .ram], ramFormat: .percent)
    private let absoluteMenuBar = MenuBarSettings(
        visibleMetrics: [.cpu, .gpu, .ram], ramFormat: .absolute)
    private let thresholds = ThresholdSettings(
        cpuPercent: 80, ramPercent: 90, gpuPercent: 85, sustainedSeconds: 30)

    @Test("Identical inputs produce equal states")
    func identicalEqual() {
        let snap = makeSnap(cpu: 12.4, ramPct: 50, ramBytes: 8_000_000_000, gpu: 30)
        let a = MenuBarIconRenderState.from(
            snapshot: snap, menuBar: menuBar, thresholds: thresholds, scheme: .light)
        let b = MenuBarIconRenderState.from(
            snapshot: snap, menuBar: menuBar, thresholds: thresholds, scheme: .light)
        #expect(a == b)
    }

    @Test("Different rounded CPU percent ↔ different state")
    func cpuRoundedChange() {
        let s1 = makeSnap(cpu: 12.4, ramPct: 50, ramBytes: 8_000_000_000, gpu: 30)
        let s2 = makeSnap(cpu: 12.6, ramPct: 50, ramBytes: 8_000_000_000, gpu: 30)
        let a = MenuBarIconRenderState.from(
            snapshot: s1, menuBar: menuBar, thresholds: thresholds, scheme: .light)
        let b = MenuBarIconRenderState.from(
            snapshot: s2, menuBar: menuBar, thresholds: thresholds, scheme: .light)
        // 12.4 → 12, 12.6 → 13 (rounded)
        #expect(a != b)
    }

    @Test("Sub-rounding CPU drift does not change state")
    func cpuSubRoundingNoChange() {
        let s1 = makeSnap(cpu: 12.2, ramPct: 50, ramBytes: 8_000_000_000, gpu: 30)
        let s2 = makeSnap(cpu: 12.4, ramPct: 50, ramBytes: 8_000_000_000, gpu: 30)
        let a = MenuBarIconRenderState.from(
            snapshot: s1, menuBar: menuBar, thresholds: thresholds, scheme: .light)
        let b = MenuBarIconRenderState.from(
            snapshot: s2, menuBar: menuBar, thresholds: thresholds, scheme: .light)
        // Both round to 12.
        #expect(a == b)
    }

    @Test("Threshold-crossing flips the slot state")
    func thresholdCrossing() {
        let snap = makeSnap(cpu: 75, ramPct: 50, ramBytes: 8_000_000_000, gpu: 30)
        let strict = ThresholdSettings(
            cpuPercent: 60, ramPercent: 90, gpuPercent: 85, sustainedSeconds: 30)
        let normalState = MenuBarIconRenderState.from(
            snapshot: snap, menuBar: menuBar, thresholds: thresholds, scheme: .light)
        let crossedState = MenuBarIconRenderState.from(
            snapshot: snap, menuBar: menuBar, thresholds: strict, scheme: .light)
        // 75% > 60% but < 80%: threshold severity differs even though the
        // displayed digits are the same.
        #expect(normalState != crossedState)
    }

    @Test("Visible-metrics order swap changes state")
    func metricsOrderSwap() {
        let snap = makeSnap(cpu: 12, ramPct: 50, ramBytes: 8_000_000_000, gpu: 30)
        let original = MenuBarIconRenderState.from(
            snapshot: snap,
            menuBar: MenuBarSettings(visibleMetrics: [.cpu, .ram, .gpu], ramFormat: .percent),
            thresholds: thresholds,
            scheme: .light
        )
        let swapped = MenuBarIconRenderState.from(
            snapshot: snap,
            menuBar: MenuBarSettings(visibleMetrics: [.gpu, .cpu, .ram], ramFormat: .percent),
            thresholds: thresholds,
            scheme: .light
        )
        #expect(original != swapped)
    }

    @Test("Toggling RAM format from percent to absolute changes state")
    func ramFormatToggle() {
        let snap = makeSnap(cpu: 12, ramPct: 50, ramBytes: 8_000_000_000, gpu: 30)
        let pct = MenuBarIconRenderState.from(
            snapshot: snap, menuBar: menuBar, thresholds: thresholds, scheme: .light)
        let abs = MenuBarIconRenderState.from(
            snapshot: snap, menuBar: absoluteMenuBar, thresholds: thresholds, scheme: .light)
        #expect(pct != abs)
    }

    @Test("Light vs dark colour scheme changes state")
    func schemeChange() {
        let snap = makeSnap(cpu: 12, ramPct: 50, ramBytes: 8_000_000_000, gpu: 30)
        let light = MenuBarIconRenderState.from(
            snapshot: snap, menuBar: menuBar, thresholds: thresholds, scheme: .light)
        let dark = MenuBarIconRenderState.from(
            snapshot: snap, menuBar: menuBar, thresholds: thresholds, scheme: .dark)
        #expect(light != dark)
    }

    @Test("nil snapshot vs non-nil snapshot differs")
    func nilVsNonNilSnapshot() {
        let snap = makeSnap(cpu: 12, ramPct: 50, ramBytes: 8_000_000_000, gpu: 30)
        let withNone = MenuBarIconRenderState.from(
            snapshot: nil, menuBar: menuBar, thresholds: thresholds, scheme: .light)
        let withSnap = MenuBarIconRenderState.from(
            snapshot: snap, menuBar: menuBar, thresholds: thresholds, scheme: .light)
        #expect(withNone != withSnap)
    }

    @Test("Missing GPU sample changes state vs present GPU")
    func gpuPresenceChange() {
        let withGpu = makeSnap(cpu: 12, ramPct: 50, ramBytes: 8_000_000_000, gpu: 30)
        let withoutGpu = makeSnap(cpu: 12, ramPct: 50, ramBytes: 8_000_000_000, gpu: nil)
        let a = MenuBarIconRenderState.from(
            snapshot: withGpu, menuBar: menuBar, thresholds: thresholds, scheme: .light)
        let b = MenuBarIconRenderState.from(
            snapshot: withoutGpu, menuBar: menuBar, thresholds: thresholds, scheme: .light)
        #expect(a != b)
    }

    @Test("RAM absolute mode: 50MB drift within the same 100MB bucket does not change state")
    func ramAbsoluteSubBucketStable() {
        let s1 = makeSnap(cpu: 0, ramPct: 50, ramBytes: 8_000_000_000, gpu: nil)
        let s2 = makeSnap(cpu: 0, ramPct: 50, ramBytes: 8_050_000_000, gpu: nil)
        let a = MenuBarIconRenderState.from(
            snapshot: s1, menuBar: absoluteMenuBar, thresholds: thresholds, scheme: .light)
        let b = MenuBarIconRenderState.from(
            snapshot: s2, menuBar: absoluteMenuBar, thresholds: thresholds, scheme: .light)
        // Both round to the same 100 MB tier (80).
        #expect(a == b)
    }

    @Test("RAM absolute mode: crossing the 100MB bucket boundary changes state")
    func ramAbsoluteCrossesBucket() {
        let s1 = makeSnap(cpu: 0, ramPct: 50, ramBytes: 8_000_000_000, gpu: nil)
        let s2 = makeSnap(cpu: 0, ramPct: 50, ramBytes: 8_150_000_000, gpu: nil)
        let a = MenuBarIconRenderState.from(
            snapshot: s1, menuBar: absoluteMenuBar, thresholds: thresholds, scheme: .light)
        let b = MenuBarIconRenderState.from(
            snapshot: s2, menuBar: absoluteMenuBar, thresholds: thresholds, scheme: .light)
        #expect(a != b)
    }

    // MARK: - Helpers

    private func makeSnap(
        cpu: Double, ramPct: Double, ramBytes: UInt64, gpu: Double?
    )
        -> Snapshot
    {
        Snapshot(
            timestamp: Date(timeIntervalSince1970: 0),
            cpu: CPUUsage(
                userPercent: 0, systemPercent: 0, idlePercent: 100 - cpu,
                totalPercent: cpu, perCoreTotalPercent: []
            ),
            ram: RAMUsage(
                totalBytes: 16_000_000_000, usedBytes: ramBytes,
                freeBytes: 16_000_000_000 - ramBytes, usedPercent: ramPct
            ),
            gpu: gpu.map(GPUUsage.init(utilizationPercent:))
        )
    }
}
