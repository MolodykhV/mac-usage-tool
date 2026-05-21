import Foundation
import Testing

@testable import PlumageBarCore

@Suite("SnapshotHistory ring buffer")
struct SnapshotHistoryTests {

    private func makeSnap(
        cpu: Double, ram: Double, gpu: Double?, at seconds: TimeInterval
    )
        -> Snapshot
    {
        Snapshot(
            timestamp: Date(timeIntervalSince1970: seconds),
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

    @Test("Appending below capacity preserves all snapshots")
    func belowCapacity() {
        var history = SnapshotHistory(capacity: 5)
        for i in 0..<3 {
            history.append(makeSnap(cpu: Double(i * 10), ram: 50, gpu: nil, at: Double(i)))
        }
        #expect(history.count == 3)
        #expect(history.cpuTotalSeries() == [0, 10, 20])
    }

    @Test("Overflow evicts oldest snapshots")
    func evictsOldest() {
        var history = SnapshotHistory(capacity: 3)
        for i in 0..<5 {
            history.append(makeSnap(cpu: Double(i * 10), ram: 50, gpu: nil, at: Double(i)))
        }
        #expect(history.count == 3)
        #expect(history.cpuTotalSeries() == [20, 30, 40])
    }

    @Test("clear() empties the buffer but keeps capacity")
    func clearKeepsCapacity() {
        var history = SnapshotHistory(capacity: 3)
        history.append(makeSnap(cpu: 50, ram: 50, gpu: nil, at: 0))
        history.clear()
        #expect(history.isEmpty)
        #expect(history.capacity == 3)
        history.append(makeSnap(cpu: 60, ram: 60, gpu: nil, at: 1))
        #expect(history.count == 1)
    }

    @Test("latest returns the most recent append")
    func latestIsLastAppended() {
        var history = SnapshotHistory(capacity: 10)
        history.append(makeSnap(cpu: 10, ram: 50, gpu: nil, at: 0))
        history.append(makeSnap(cpu: 20, ram: 60, gpu: nil, at: 1))
        #expect(history.latest?.cpu.totalPercent == 20)
    }

    @Test("gpuSeries treats missing GPU as 0")
    func gpuMissingFillsZero() {
        var history = SnapshotHistory(capacity: 5)
        history.append(makeSnap(cpu: 0, ram: 0, gpu: 10, at: 0))
        history.append(makeSnap(cpu: 0, ram: 0, gpu: nil, at: 1))
        history.append(makeSnap(cpu: 0, ram: 0, gpu: 20, at: 2))
        #expect(history.gpuSeries() == [10, 0, 20])
    }

    @Test("Capacity = 1 keeps only the latest")
    func capacityOne() {
        var history = SnapshotHistory(capacity: 1)
        history.append(makeSnap(cpu: 10, ram: 0, gpu: nil, at: 0))
        history.append(makeSnap(cpu: 20, ram: 0, gpu: nil, at: 1))
        history.append(makeSnap(cpu: 30, ram: 0, gpu: nil, at: 2))
        #expect(history.count == 1)
        #expect(history.cpuTotalSeries() == [30])
    }
}
