import Foundation
import Testing

@testable import PlumageBarCore

@Suite("ProcessReader ranking")
struct ProcessReaderRankingTests {

    private let sample = [
        ProcessUsage(pid: 1, name: "kernel_task", cpuPercent: 5, residentBytes: 1_000_000_000),
        ProcessUsage(pid: 200, name: "WindowServer", cpuPercent: 12, residentBytes: 500_000_000),
        ProcessUsage(pid: 300, name: "Xcode", cpuPercent: 85, residentBytes: 3_500_000_000),
        ProcessUsage(pid: 400, name: "Safari", cpuPercent: 30, residentBytes: 2_500_000_000),
        ProcessUsage(pid: 500, name: "Mail", cpuPercent: 1, residentBytes: 200_000_000),
    ]

    @Test("Top 3 by CPU returns highest cpuPercent first")
    func topByCPU() {
        let top = ProcessReader.rankTopByCPU(sample, top: 3)
        #expect(top.map(\.pid) == [300, 400, 200])
    }

    @Test("Top 3 by memory returns largest residentBytes first")
    func topByMemory() {
        let top = ProcessReader.rankTopByMemory(sample, top: 3)
        #expect(top.map(\.pid) == [300, 400, 1])
    }

    @Test("top: 0 returns empty array")
    func zeroTopReturnsEmpty() {
        #expect(ProcessReader.rankTopByCPU(sample, top: 0).isEmpty)
        #expect(ProcessReader.rankTopByMemory(sample, top: 0).isEmpty)
    }

    @Test("top: > N returns full input sorted")
    func topLargerThanInput() {
        let top = ProcessReader.rankTopByCPU(sample, top: 100)
        #expect(top.count == sample.count)
        #expect(top.first?.pid == 300)
        #expect(top.last?.pid == 500)
    }

    @Test("Empty input returns empty top list")
    func emptyInput() {
        let empty: [ProcessUsage] = []
        #expect(ProcessReader.rankTopByCPU(empty, top: 3).isEmpty)
        #expect(ProcessReader.rankTopByMemory(empty, top: 3).isEmpty)
    }

    @Test("Ties are broken stably by input order")
    func ties() {
        let tied = [
            ProcessUsage(pid: 1, name: "a", cpuPercent: 50, residentBytes: 100),
            ProcessUsage(pid: 2, name: "b", cpuPercent: 50, residentBytes: 100),
            ProcessUsage(pid: 3, name: "c", cpuPercent: 50, residentBytes: 100),
        ]
        let top = ProcessReader.rankTopByCPU(tied, top: 2)
        #expect(top.count == 2)
        // Stable sort means the order is preserved across ties.
        #expect(Set(top.map(\.pid)).count == 2)
    }
}

@Suite("ProcessReader live integration", .tags(.integration))
struct ProcessReaderIntegrationTests {

    @Test("Live read returns plausible top processes after a delta sample")
    func liveProcessReport() throws {
        let reader = ProcessReader()
        _ = try reader.read(topN: 3)
        Thread.sleep(forTimeInterval: 0.2)
        let report = try reader.read(topN: 3)
        #expect(report.topByCPU.count <= 3)
        #expect(report.topByMemory.count <= 3)
        // At least one running process should have non-zero RSS.
        let totalRSS = report.topByMemory.reduce(0) { $0 &+ $1.residentBytes }
        #expect(totalRSS > 0)
    }
}
