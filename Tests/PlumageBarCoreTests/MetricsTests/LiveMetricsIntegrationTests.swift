import Foundation
import Testing

@testable import PlumageBarCore

extension Tag {
    @Tag static var integration: Self
}

@Suite("Live metric readers (hardware integration)", .tags(.integration))
struct LiveMetricsIntegrationTests {

    @Test("CPUReader produces plausible values across two reads")
    func liveCPURead() throws {
        let reader = CPUReader()
        _ = try reader.read()
        // Busy-spin briefly so the second sample has measurable user/system ticks.
        let deadline = Date().addingTimeInterval(0.1)
        var counter: UInt64 = 0
        while Date() < deadline {
            counter &+= 1
        }
        _ = counter  // prevent optimisation
        let usage = try reader.read()
        #expect(usage.totalPercent >= 0)
        #expect(usage.totalPercent <= 100)
        #expect(usage.idlePercent >= 0)
        #expect(usage.idlePercent <= 100)
        #expect(!usage.perCoreTotalPercent.isEmpty)
        let rounding: Double = 1.0
        let sum = usage.userPercent + usage.systemPercent + usage.idlePercent
        // user + system + idle should add up to roughly 100 minus the nice slice
        // which is rarely non-zero on workstation kernels.
        #expect(sum <= 100 + rounding)
    }

    @Test("RAMReader returns total > 0 and used <= total")
    func liveRAMRead() throws {
        let reader = RAMReader()
        let usage = try reader.read()
        #expect(usage.totalBytes > 0)
        #expect(usage.usedBytes <= usage.totalBytes)
        #expect(usage.usedPercent >= 0)
        #expect(usage.usedPercent <= 100)
    }

    @Test("GPUReader subscribes and produces a delta on second read")
    func liveGPURead() throws {
        let reader = GPUReader()
        _ = try reader.read()
        // Need a non-zero gap between samples for IOReport to produce residency.
        Thread.sleep(forTimeInterval: 0.05)
        let usage = try reader.read()
        #expect(usage.utilizationPercent >= 0)
        #expect(usage.utilizationPercent <= 100)
    }

    @Test("LiveMetricsProvider emits at least one snapshot within 3s")
    func liveSamplerEmits() async throws {
        let provider = LiveMetricsProvider(interval: .milliseconds(100))
        await provider.start()
        defer { Task { await provider.stop() } }

        var collected: [Snapshot] = []
        let deadline = ContinuousClock.now.advanced(by: .seconds(3))
        for await snap in provider.snapshots {
            collected.append(snap)
            if collected.count >= 2 || ContinuousClock.now >= deadline { break }
        }
        await provider.stop()

        #expect(collected.count >= 1)
        guard let first = collected.first else { return }
        #expect(first.cpu.idlePercent >= 0)
        #expect(first.ram.totalBytes > 0)
    }

    @Test("stop() finishes the AsyncStream so consumers exit the for-await loop")
    func stopFinishesStream() async throws {
        let provider = LiveMetricsProvider(interval: .milliseconds(50))
        await provider.start()

        // Consume one snapshot, then stop and confirm the iterator terminates.
        var iterator = provider.snapshots.makeAsyncIterator()
        let first = await iterator.next()
        #expect(first != nil)

        await provider.stop()

        // The remaining elements must drain to nil — if stop() did not finish
        // the continuation, this for-await would hang until the test timeout.
        var trailing = 0
        while let _ = await iterator.next() {
            trailing += 1
            if trailing > 32 { break }
        }
        // No assertion on `trailing` count: in-flight snapshots already in the
        // buffer may still drain. The pass condition is that the loop above
        // terminates promptly because the stream is finished.
    }
}
