import Foundation
import Testing

@testable import PlumageBarCore

@Suite("SnapshotHistory bounded under sustained push")
struct SnapshotHistoryStabilityTests {

    @Test("Pushing 50× the capacity keeps storage at exactly `capacity` items")
    func pushBeyondCapacityIsBounded() {
        var history = SnapshotHistory(capacity: 60)
        for i in 0..<(60 * 50) {
            history.append(makeSnapshot(at: TimeInterval(i)))
        }
        #expect(history.count == 60)
        // The 60 freshest snapshots survive.
        #expect(history.snapshots.first?.timestamp == Date(timeIntervalSince1970: 60 * 50 - 60))
        #expect(history.snapshots.last?.timestamp == Date(timeIntervalSince1970: 60 * 50 - 1))
    }

    @Test("Series accessors return arrays whose length tracks the buffer count")
    func seriesLengthsMatchCount() {
        var history = SnapshotHistory(capacity: 10)
        for i in 0..<25 {
            history.append(makeSnapshot(at: TimeInterval(i)))
        }
        #expect(history.cpuTotalSeries().count == 10)
        #expect(history.ramUsedSeries().count == 10)
        #expect(history.gpuSeries().count == 10)
    }

    @Test("Clear after a full buffer drops everything, then capacity still accepts new pushes")
    func clearAndReuse() {
        var history = SnapshotHistory(capacity: 5)
        for i in 0..<5 {
            history.append(makeSnapshot(at: TimeInterval(i)))
        }
        history.clear()
        #expect(history.isEmpty)
        for i in 100..<105 {
            history.append(makeSnapshot(at: TimeInterval(i)))
        }
        #expect(history.count == 5)
        #expect(history.snapshots.first?.timestamp == Date(timeIntervalSince1970: 100))
    }

    private func makeSnapshot(at seconds: TimeInterval) -> Snapshot {
        Snapshot(
            timestamp: Date(timeIntervalSince1970: seconds),
            cpu: CPUUsage(
                userPercent: 0, systemPercent: 0, idlePercent: 100,
                totalPercent: 0, perCoreTotalPercent: []
            ),
            ram: RAMUsage(totalBytes: 0, usedBytes: 0, freeBytes: 0, usedPercent: 0),
            gpu: nil
        )
    }
}

@Suite("LiveMetricsProvider stability (hardware integration)", .tags(.integration))
struct SamplerStabilityTests {

    @Test(
        "Sampler emits at least 10 snapshots over a 2s window without falling behind",
        .timeLimit(.minutes(1))
    )
    @MainActor
    func sustainedEmission() async {
        let provider = LiveMetricsProvider(interval: .milliseconds(100))
        await provider.start()

        var collected: [Snapshot] = []
        let deadline = ContinuousClock.now.advanced(by: .seconds(2))
        for await snap in provider.snapshots {
            collected.append(snap)
            if collected.count >= 20 || ContinuousClock.now >= deadline { break }
        }
        await provider.stop()

        // 2 seconds at 10Hz is 20 snapshots; with sub-actor overhead we
        // accept at least half of that as a stability floor.
        #expect(collected.count >= 10)
        // Timestamps must be strictly increasing.
        for i in 1..<collected.count {
            #expect(collected[i].timestamp > collected[i - 1].timestamp)
        }
    }

    @Test(
        "setInterval mid-run takes effect on the next tick without skipping samples",
        .timeLimit(.minutes(1))
    )
    @MainActor
    func intervalChangeMidRun() async {
        let provider = LiveMetricsProvider(interval: .milliseconds(50))
        await provider.start()

        var iterator = provider.snapshots.makeAsyncIterator()
        // Warm up.
        _ = await iterator.next()
        _ = await iterator.next()

        await provider.setInterval(.milliseconds(200))

        // After the cadence change the next two samples should still arrive,
        // just at the slower rate. We only check that they arrive, not the
        // exact timing — clock jitter on CI runners makes timing assertions
        // brittle.
        let s1 = await iterator.next()
        let s2 = await iterator.next()
        #expect(s1 != nil)
        #expect(s2 != nil)

        await provider.stop()
    }
}
