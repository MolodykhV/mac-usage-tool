import Darwin
import Foundation

public struct CPUTicks: Sendable, Equatable {
    public let user: UInt64
    public let system: UInt64
    public let idle: UInt64
    public let nice: UInt64

    public init(user: UInt64, system: UInt64, idle: UInt64, nice: UInt64) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }

    public var total: UInt64 { user &+ system &+ idle &+ nice }
}

public enum CPUReadError: Error, Equatable, Sendable {
    case hostInfoFailed(Int32)
}

public final class CPUReader {
    private var previous: [CPUTicks]?

    public init() {}

    public func read() throws -> CPUUsage {
        let current = try Self.sampleTicks()
        defer { self.previous = current }
        guard let previous else {
            return Self.fullIdle(coreCount: current.count)
        }
        return Self.computeUsage(previous: previous, current: current)
    }

    public func reset() {
        self.previous = nil
    }

    static func computeUsage(previous: [CPUTicks], current: [CPUTicks]) -> CPUUsage {
        let coreCount = min(previous.count, current.count)
        var perCoreTotal: [Double] = []
        perCoreTotal.reserveCapacity(coreCount)

        var sumUser: UInt64 = 0
        var sumSystem: UInt64 = 0
        var sumIdle: UInt64 = 0
        var sumNice: UInt64 = 0

        for i in 0..<coreCount {
            let p = previous[i]
            let c = current[i]
            let dUser = c.user &- p.user
            let dSystem = c.system &- p.system
            let dIdle = c.idle &- p.idle
            let dNice = c.nice &- p.nice
            let dTotal = dUser &+ dSystem &+ dIdle &+ dNice

            sumUser &+= dUser
            sumSystem &+= dSystem
            sumIdle &+= dIdle
            sumNice &+= dNice

            if dTotal == 0 {
                perCoreTotal.append(0)
            } else {
                let active = dUser &+ dSystem &+ dNice
                perCoreTotal.append(Double(active) / Double(dTotal) * 100.0)
            }
        }

        let totalTicks = sumUser &+ sumSystem &+ sumIdle &+ sumNice
        guard totalTicks > 0 else {
            return fullIdle(coreCount: coreCount)
        }
        let activeTicks = sumUser &+ sumSystem &+ sumNice
        return CPUUsage(
            userPercent: Double(sumUser) / Double(totalTicks) * 100.0,
            systemPercent: Double(sumSystem) / Double(totalTicks) * 100.0,
            idlePercent: Double(sumIdle) / Double(totalTicks) * 100.0,
            totalPercent: Double(activeTicks) / Double(totalTicks) * 100.0,
            perCoreTotalPercent: perCoreTotal
        )
    }

    private static func fullIdle(coreCount: Int) -> CPUUsage {
        CPUUsage(
            userPercent: 0,
            systemPercent: 0,
            idlePercent: 100,
            totalPercent: 0,
            perCoreTotalPercent: Array(repeating: 0, count: coreCount)
        )
    }

    private static func sampleTicks() throws -> [CPUTicks] {
        var cpuCount: natural_t = 0
        var infoArray: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0

        let kr = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &cpuCount,
            &infoArray,
            &infoCount
        )
        guard kr == KERN_SUCCESS, let infoArray else {
            throw CPUReadError.hostInfoFailed(Int32(kr))
        }
        defer {
            let address = vm_address_t(UInt(bitPattern: UnsafeRawPointer(infoArray)))
            let size = vm_size_t(infoCount) * vm_size_t(MemoryLayout<integer_t>.size)
            vm_deallocate(mach_task_self_, address, size)
        }
        // host_processor_info has reported success with 0 CPUs in the wild
        // (mostly on bring-up of new hardware); guard so we don't quietly
        // freeze the sampler at "all idle" forever.
        guard cpuCount > 0 else {
            throw CPUReadError.hostInfoFailed(Int32(KERN_FAILURE))
        }

        let states = Int(CPU_STATE_MAX)
        var ticks: [CPUTicks] = []
        ticks.reserveCapacity(Int(cpuCount))
        for i in 0..<Int(cpuCount) {
            let base = i * states
            ticks.append(
                CPUTicks(
                    user: UInt64(UInt32(bitPattern: infoArray[base + Int(CPU_STATE_USER)])),
                    system: UInt64(UInt32(bitPattern: infoArray[base + Int(CPU_STATE_SYSTEM)])),
                    idle: UInt64(UInt32(bitPattern: infoArray[base + Int(CPU_STATE_IDLE)])),
                    nice: UInt64(UInt32(bitPattern: infoArray[base + Int(CPU_STATE_NICE)]))
                )
            )
        }
        return ticks
    }
}
