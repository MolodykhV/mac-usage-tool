import Foundation
import Testing

@testable import PlumageBarCore

@Suite("ThresholdEngine")
struct ThresholdEngineTests {

    private let thresholds = ThresholdSettings(
        cpuPercent: 80,
        ramPercent: 90,
        gpuPercent: 85,
        sustainedSeconds: 10
    )
    private let notifications = NotificationSettings(
        enabled: true, cpu: true, gpu: true, ram: true)

    @Test("Brief spike below sustained window does not fire")
    func briefSpikeIgnored() {
        let engine = ThresholdEngine()
        let t0 = Date(timeIntervalSince1970: 1000)
        let alertsT0 = engine.process(
            snapshot: snap(cpu: 95, ram: 50, gpu: 10, at: t0),
            thresholds: thresholds, notifications: notifications)
        let alertsT9 = engine.process(
            snapshot: snap(cpu: 95, ram: 50, gpu: 10, at: t0.addingTimeInterval(9)),
            thresholds: thresholds, notifications: notifications)
        #expect(alertsT0.isEmpty)
        #expect(alertsT9.isEmpty)
    }

    @Test("Sustained excursion fires exactly once when window elapses")
    func sustainedExcursionFiresOnce() {
        let engine = ThresholdEngine()
        let t0 = Date(timeIntervalSince1970: 1000)
        _ = engine.process(
            snapshot: snap(cpu: 95, ram: 50, gpu: 10, at: t0),
            thresholds: thresholds, notifications: notifications)
        let firing = engine.process(
            snapshot: snap(cpu: 95, ram: 50, gpu: 10, at: t0.addingTimeInterval(10)),
            thresholds: thresholds, notifications: notifications)
        let after = engine.process(
            snapshot: snap(cpu: 95, ram: 50, gpu: 10, at: t0.addingTimeInterval(20)),
            thresholds: thresholds, notifications: notifications)

        #expect(firing.count == 1)
        #expect(firing.first?.metric == .cpu)
        #expect(firing.first?.value == 95)
        #expect(firing.first?.threshold == 80)
        // Already-alerted episode: no re-fire while still exceeding.
        #expect(after.isEmpty)
    }

    @Test("Recovery resets the episode and the next crossing alerts again")
    func recoveryRearms() {
        let engine = ThresholdEngine()
        let t0 = Date(timeIntervalSince1970: 1000)
        _ = engine.process(
            snapshot: snap(cpu: 95, ram: 50, gpu: 10, at: t0),
            thresholds: thresholds, notifications: notifications)
        _ = engine.process(
            snapshot: snap(cpu: 95, ram: 50, gpu: 10, at: t0.addingTimeInterval(10)),
            thresholds: thresholds, notifications: notifications)
        // Drop back to safe range — episode ends.
        let recovery = engine.process(
            snapshot: snap(cpu: 20, ram: 50, gpu: 10, at: t0.addingTimeInterval(15)),
            thresholds: thresholds, notifications: notifications)
        // New excursion starts at t=30.
        _ = engine.process(
            snapshot: snap(cpu: 95, ram: 50, gpu: 10, at: t0.addingTimeInterval(30)),
            thresholds: thresholds, notifications: notifications)
        let secondFire = engine.process(
            snapshot: snap(cpu: 95, ram: 50, gpu: 10, at: t0.addingTimeInterval(40)),
            thresholds: thresholds, notifications: notifications)

        #expect(recovery.isEmpty)
        #expect(secondFire.count == 1)
        #expect(secondFire.first?.metric == .cpu)
    }

    @Test("Each enabled metric tracks independently")
    func metricsIndependent() {
        let engine = ThresholdEngine()
        let t0 = Date(timeIntervalSince1970: 1000)
        _ = engine.process(
            snapshot: snap(cpu: 95, ram: 95, gpu: 90, at: t0),
            thresholds: thresholds, notifications: notifications)
        let alerts = engine.process(
            snapshot: snap(cpu: 95, ram: 95, gpu: 90, at: t0.addingTimeInterval(10)),
            thresholds: thresholds, notifications: notifications)
        let metrics = Set(alerts.map(\.metric))
        #expect(metrics == [.cpu, .ram, .gpu])
        #expect(alerts.count == 3)
    }

    @Test("Disabled metric never fires even if exceeding for long")
    func disabledMetricSilenced() {
        let engine = ThresholdEngine()
        let t0 = Date(timeIntervalSince1970: 1000)
        let only = NotificationSettings(enabled: true, cpu: false, gpu: true, ram: true)
        _ = engine.process(
            snapshot: snap(cpu: 99, ram: 50, gpu: 10, at: t0),
            thresholds: thresholds, notifications: only)
        let alerts = engine.process(
            snapshot: snap(cpu: 99, ram: 50, gpu: 10, at: t0.addingTimeInterval(30)),
            thresholds: thresholds, notifications: only)
        #expect(alerts.isEmpty)
    }

    @Test("Master toggle off silences every metric")
    func masterToggleOff() {
        let engine = ThresholdEngine()
        let t0 = Date(timeIntervalSince1970: 1000)
        let off = NotificationSettings(enabled: false)
        _ = engine.process(
            snapshot: snap(cpu: 99, ram: 99, gpu: 99, at: t0),
            thresholds: thresholds, notifications: off)
        let alerts = engine.process(
            snapshot: snap(cpu: 99, ram: 99, gpu: 99, at: t0.addingTimeInterval(60)),
            thresholds: thresholds, notifications: off)
        #expect(alerts.isEmpty)
    }

    @Test("Missing GPU sample doesn't fire and clears any prior episode")
    func missingGPUSampleClears() {
        let engine = ThresholdEngine()
        let t0 = Date(timeIntervalSince1970: 1000)
        // First, build up a GPU episode.
        _ = engine.process(
            snapshot: snap(cpu: 0, ram: 0, gpu: 95, at: t0),
            thresholds: thresholds, notifications: notifications)
        // Sampler now reports gpu = nil (GPU disabled mid-session).
        let alerts = engine.process(
            snapshot: snap(cpu: 0, ram: 0, gpu: nil, at: t0.addingTimeInterval(20)),
            thresholds: thresholds, notifications: notifications)
        #expect(alerts.isEmpty)
    }

    @Test("A backwards clock jump re-anchors the episode rather than stalling")
    func clockBackwardsRecovery() {
        let engine = ThresholdEngine()
        let t0 = Date(timeIntervalSince1970: 1000)
        // Start an episode at t0 — exceedingSince = t0.
        _ = engine.process(
            snapshot: snap(cpu: 95, ram: 0, gpu: nil, at: t0),
            thresholds: thresholds, notifications: notifications)
        // Wall clock steps backwards 60s — episode re-anchors to the new "now".
        let backwards = t0.addingTimeInterval(-60)
        _ = engine.process(
            snapshot: snap(cpu: 95, ram: 0, gpu: nil, at: backwards),
            thresholds: thresholds, notifications: notifications)
        // Sustain window measured from the new anchor: 10s after `backwards`.
        let firing = engine.process(
            snapshot: snap(cpu: 95, ram: 0, gpu: nil, at: backwards.addingTimeInterval(10)),
            thresholds: thresholds, notifications: notifications)
        #expect(firing.count == 1)
        #expect(firing.first?.metric == .cpu)
    }

    @Test("reset() drops all in-flight episodes")
    func resetClearsEpisodes() {
        let engine = ThresholdEngine()
        let t0 = Date(timeIntervalSince1970: 1000)
        _ = engine.process(
            snapshot: snap(cpu: 95, ram: 95, gpu: 95, at: t0),
            thresholds: thresholds, notifications: notifications)
        engine.reset()
        // Even at t=t0+20 (would be 20s sustained), no alert because episode was reset.
        let alerts = engine.process(
            snapshot: snap(cpu: 95, ram: 95, gpu: 95, at: t0.addingTimeInterval(20)),
            thresholds: thresholds, notifications: notifications)
        // The post-reset snapshot starts a fresh episode at t=20, hasn't sustained yet.
        #expect(alerts.isEmpty)
    }

    // MARK: - Helpers

    private func snap(cpu: Double, ram: Double, gpu: Double?, at when: Date) -> Snapshot {
        Snapshot(
            timestamp: when,
            cpu: CPUUsage(
                userPercent: 0, systemPercent: 0, idlePercent: 100 - cpu,
                totalPercent: cpu, perCoreTotalPercent: []
            ),
            ram: RAMUsage(
                totalBytes: 100, usedBytes: UInt64(ram), freeBytes: UInt64(100 - ram),
                usedPercent: ram
            ),
            gpu: gpu.map(GPUUsage.init(utilizationPercent:))
        )
    }
}
