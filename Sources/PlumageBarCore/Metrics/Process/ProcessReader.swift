import Darwin
import Foundation

public struct ProcessUsage: Sendable, Codable, Equatable, Identifiable {
    public let pid: Int32
    public let name: String
    public let cpuPercent: Double
    public let residentBytes: UInt64

    public var id: Int32 { pid }

    public init(pid: Int32, name: String, cpuPercent: Double, residentBytes: UInt64) {
        self.pid = pid
        self.name = name
        self.cpuPercent = cpuPercent
        self.residentBytes = residentBytes
    }
}

public struct ProcessReport: Sendable, Codable, Equatable {
    public let topByCPU: [ProcessUsage]
    public let topByMemory: [ProcessUsage]

    public init(topByCPU: [ProcessUsage], topByMemory: [ProcessUsage]) {
        self.topByCPU = topByCPU
        self.topByMemory = topByMemory
    }
}

public enum ProcessReadError: Error, Equatable, Sendable {
    case listFailed
}

public final class ProcessReader {
    private var previousCPUNs: [pid_t: UInt64] = [:]
    private var lastSampleAt: ContinuousClock.Instant?
    private let timebaseNumer: UInt64
    private let timebaseDenom: UInt64
    // Reused across every pid in every sample so we don't allocate one
    // MAXPATHLEN (1 KiB) buffer per process per scan.
    private var pathScratch: [CChar] = Array(repeating: 0, count: Int(MAXPATHLEN))

    public init() {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        self.timebaseNumer = UInt64(info.numer)
        self.timebaseDenom = UInt64(info.denom)
    }

    public func read(topN: Int = 3) throws -> ProcessReport {
        let now = ContinuousClock.now
        let elapsedNs: UInt64
        if let last = lastSampleAt {
            let nanoseconds =
                (now - last).components.seconds * 1_000_000_000
                + Int64((now - last).components.attoseconds / 1_000_000_000)
            elapsedNs = UInt64(max(0, nanoseconds))
        } else {
            elapsedNs = 0
        }
        lastSampleAt = now

        let pids = try Self.listAllPIDs()
        var current: [ProcessUsage] = []
        current.reserveCapacity(pids.count)
        var nextPrevious: [pid_t: UInt64] = [:]
        nextPrevious.reserveCapacity(pids.count)

        for pid in pids where pid > 0 {
            guard let raw = sampleProcess(pid: pid) else { continue }
            nextPrevious[pid] = raw.totalCPUNs

            let cpuPercent: Double
            if elapsedNs > 0, let prev = previousCPUNs[pid] {
                let deltaNs = raw.totalCPUNs &- prev
                cpuPercent = Double(deltaNs) / Double(elapsedNs) * 100.0
            } else {
                cpuPercent = 0
            }

            current.append(
                ProcessUsage(
                    pid: pid,
                    name: raw.name,
                    cpuPercent: max(0, cpuPercent),
                    residentBytes: raw.rssBytes
                )
            )
        }
        previousCPUNs = nextPrevious

        return ProcessReport(
            topByCPU: Self.rankTopByCPU(current, top: topN),
            topByMemory: Self.rankTopByMemory(current, top: topN)
        )
    }

    public func reset() {
        previousCPUNs.removeAll(keepingCapacity: true)
        lastSampleAt = nil
    }

    static func rankTopByCPU(_ usages: [ProcessUsage], top n: Int) -> [ProcessUsage] {
        guard n > 0 else { return [] }
        return Array(usages.sorted { $0.cpuPercent > $1.cpuPercent }.prefix(n))
    }

    static func rankTopByMemory(_ usages: [ProcessUsage], top n: Int) -> [ProcessUsage] {
        guard n > 0 else { return [] }
        return Array(usages.sorted { $0.residentBytes > $1.residentBytes }.prefix(n))
    }

    private struct RawProcessInfo {
        let name: String
        let totalCPUNs: UInt64
        let rssBytes: UInt64
    }

    private func sampleProcess(pid: pid_t) -> RawProcessInfo? {
        var taskInfo = proc_taskinfo()
        let size = Int32(MemoryLayout<proc_taskinfo>.size)
        let written = withUnsafeMutablePointer(to: &taskInfo) { ptr in
            proc_pidinfo(pid, PROC_PIDTASKINFO, 0, ptr, size)
        }
        guard written == size else { return nil }

        let totalTicks = taskInfo.pti_total_user &+ taskInfo.pti_total_system
        let totalNs = totalTicks &* timebaseNumer / max(1, timebaseDenom)

        // proc_pidpath writes a NUL-terminated string into the buffer. Resetting
        // only the first byte is enough because validatingCString stops at the
        // NUL it just wrote — no need to memset the whole MAXPATHLEN.
        pathScratch[0] = 0
        let pathBytes = pathScratch.withUnsafeMutableBufferPointer { buf -> Int32 in
            proc_pidpath(pid, buf.baseAddress, UInt32(buf.count))
        }
        let name: String
        if pathBytes > 0,
            let path = pathScratch.withUnsafeBufferPointer({ buf -> String? in
                buf.baseAddress.flatMap { String(validatingCString: $0) }
            })
        {
            name = (path as NSString).lastPathComponent
        } else {
            name = "pid \(pid)"
        }

        return RawProcessInfo(
            name: name,
            totalCPUNs: totalNs,
            rssBytes: taskInfo.pti_resident_size
        )
    }

    private static func listAllPIDs() throws -> [pid_t] {
        let probeBytes = proc_listallpids(nil, 0)
        guard probeBytes > 0 else { throw ProcessReadError.listFailed }
        // Overprovision in case processes are created between the probe and
        // the real call. proc_listallpids returns bytes written, not count.
        let capacity = Int(probeBytes) / MemoryLayout<pid_t>.size + 32
        var buffer = [pid_t](repeating: 0, count: capacity)
        let actualBytes = buffer.withUnsafeMutableBufferPointer { buf -> Int32 in
            proc_listallpids(buf.baseAddress, Int32(buf.count * MemoryLayout<pid_t>.size))
        }
        guard actualBytes > 0 else { throw ProcessReadError.listFailed }
        let count = Int(actualBytes) / MemoryLayout<pid_t>.size
        return Array(buffer.prefix(count))
    }
}
