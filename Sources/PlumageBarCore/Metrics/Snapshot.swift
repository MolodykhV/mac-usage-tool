public import Foundation

public struct Snapshot: Sendable, Codable, Equatable {
    public let timestamp: Date
    public let cpu: CPUUsage
    public let ram: RAMUsage
    public let gpu: GPUUsage?
    public let processes: ProcessReport?

    public init(
        timestamp: Date,
        cpu: CPUUsage,
        ram: RAMUsage,
        gpu: GPUUsage?,
        processes: ProcessReport? = nil
    ) {
        self.timestamp = timestamp
        self.cpu = cpu
        self.ram = ram
        self.gpu = gpu
        self.processes = processes
    }
}

public struct CPUUsage: Sendable, Codable, Equatable {
    public let userPercent: Double
    public let systemPercent: Double
    public let idlePercent: Double
    public let totalPercent: Double
    public let perCoreTotalPercent: [Double]

    public init(
        userPercent: Double,
        systemPercent: Double,
        idlePercent: Double,
        totalPercent: Double,
        perCoreTotalPercent: [Double]
    ) {
        self.userPercent = userPercent
        self.systemPercent = systemPercent
        self.idlePercent = idlePercent
        self.totalPercent = totalPercent
        self.perCoreTotalPercent = perCoreTotalPercent
    }
}

public struct RAMUsage: Sendable, Codable, Equatable {
    public let totalBytes: UInt64
    public let usedBytes: UInt64
    public let freeBytes: UInt64
    public let usedPercent: Double

    public init(totalBytes: UInt64, usedBytes: UInt64, freeBytes: UInt64, usedPercent: Double) {
        self.totalBytes = totalBytes
        self.usedBytes = usedBytes
        self.freeBytes = freeBytes
        self.usedPercent = usedPercent
    }
}

public struct GPUUsage: Sendable, Codable, Equatable {
    public let utilizationPercent: Double

    public init(utilizationPercent: Double) {
        self.utilizationPercent = utilizationPercent
    }
}
