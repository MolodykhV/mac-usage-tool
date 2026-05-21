import Testing

@testable import PlumageBarCore

@Suite("RAMReader.computeUsage")
struct RAMReaderTests {

    @Test("Half-used 16 GB system")
    func halfUsed16GB() {
        let pageSize: UInt64 = 16_384
        let totalBytes: UInt64 = 16 * 1024 * 1024 * 1024  // 16 GiB
        let halfPages = (totalBytes / 2) / pageSize
        let stats = VMStats(
            pageSize: pageSize,
            free: halfPages,
            active: halfPages,
            inactive: 0,
            wired: 0,
            compressed: 0,
            speculative: 0
        )
        let usage = RAMReader.computeUsage(stats: stats, totalBytes: totalBytes)
        #expect(usage.totalBytes == totalBytes)
        #expect(usage.usedBytes == totalBytes / 2)
        #expect(usage.freeBytes == totalBytes / 2)
        #expect(abs(usage.usedPercent - 50.0) < 0.001)
    }

    @Test("Used = active + wired + compressed")
    func usedAccounting() {
        let pageSize: UInt64 = 4_096
        let totalBytes: UInt64 = 1 * 1024 * 1024 * 1024  // 1 GiB
        let stats = VMStats(
            pageSize: pageSize,
            free: 100,
            active: 100,
            inactive: 500,  // explicitly NOT counted
            wired: 200,
            compressed: 300,
            speculative: 400  // explicitly NOT counted
        )
        let usage = RAMReader.computeUsage(stats: stats, totalBytes: totalBytes)
        let expectedUsedPages: UInt64 = 100 + 200 + 300
        #expect(usage.usedBytes == expectedUsedPages * pageSize)
    }

    @Test("usedBytes is capped at totalBytes (pathological inputs)")
    func usedCappedAtTotal() {
        let pageSize: UInt64 = 4_096
        let totalBytes: UInt64 = 4_096  // 1 page total
        let stats = VMStats(
            pageSize: pageSize,
            free: 0,
            active: 10,
            inactive: 0,
            wired: 10,
            compressed: 10,
            speculative: 0
        )
        let usage = RAMReader.computeUsage(stats: stats, totalBytes: totalBytes)
        #expect(usage.usedBytes == totalBytes)
        #expect(usage.freeBytes == 0)
        #expect(usage.usedPercent == 100)
    }

    @Test("Zero total memory returns zero percent without crashing")
    func zeroTotalMemory() {
        let stats = VMStats(
            pageSize: 4_096,
            free: 0,
            active: 100,
            inactive: 0,
            wired: 0,
            compressed: 0,
            speculative: 0
        )
        let usage = RAMReader.computeUsage(stats: stats, totalBytes: 0)
        #expect(usage.usedBytes == 0)
        #expect(usage.freeBytes == 0)
        #expect(usage.usedPercent == 0)
    }
}
