import Darwin
import Foundation

public struct VMStats: Sendable, Equatable {
    public let pageSize: UInt64
    public let free: UInt64
    public let active: UInt64
    public let inactive: UInt64
    public let wired: UInt64
    public let compressed: UInt64
    public let speculative: UInt64

    public init(
        pageSize: UInt64,
        free: UInt64,
        active: UInt64,
        inactive: UInt64,
        wired: UInt64,
        compressed: UInt64,
        speculative: UInt64
    ) {
        self.pageSize = pageSize
        self.free = free
        self.active = active
        self.inactive = inactive
        self.wired = wired
        self.compressed = compressed
        self.speculative = speculative
    }
}

public enum RAMReadError: Error, Equatable, Sendable {
    case hostStatisticsFailed(Int32)
}

public final class RAMReader {
    public init() {}

    public func read() throws -> RAMUsage {
        let stats = try Self.sampleVMStats()
        let total = ProcessInfo.processInfo.physicalMemory
        return Self.computeUsage(stats: stats, totalBytes: total)
    }

    static func computeUsage(stats: VMStats, totalBytes: UInt64) -> RAMUsage {
        let usedPages = stats.active &+ stats.wired &+ stats.compressed
        let usedBytes = usedPages &* stats.pageSize
        let cappedUsed = min(usedBytes, totalBytes)
        let freeBytes = totalBytes &- cappedUsed
        let percent =
            totalBytes > 0
            ? Double(cappedUsed) / Double(totalBytes) * 100.0
            : 0
        return RAMUsage(
            totalBytes: totalBytes,
            usedBytes: cappedUsed,
            freeBytes: freeBytes,
            usedPercent: percent
        )
    }

    private static func sampleVMStats() throws -> VMStats {
        let layoutCount = MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        var count = mach_msg_type_number_t(layoutCount)
        var stats = vm_statistics64_data_t()
        let kr = withUnsafeMutablePointer(to: &stats) { statsPtr in
            statsPtr.withMemoryRebound(to: integer_t.self, capacity: layoutCount) { rebound in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, rebound, &count)
            }
        }
        guard kr == KERN_SUCCESS else {
            throw RAMReadError.hostStatisticsFailed(Int32(kr))
        }
        return VMStats(
            pageSize: UInt64(getpagesize()),
            free: UInt64(stats.free_count),
            active: UInt64(stats.active_count),
            inactive: UInt64(stats.inactive_count),
            wired: UInt64(stats.wire_count),
            compressed: UInt64(stats.compressor_page_count),
            speculative: UInt64(stats.speculative_count)
        )
    }
}
