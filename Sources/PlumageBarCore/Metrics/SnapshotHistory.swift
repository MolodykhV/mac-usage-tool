public struct SnapshotHistory: Sendable {
    public let capacity: Int
    private var storage: [Snapshot] = []

    public init(capacity: Int) {
        precondition(capacity > 0, "SnapshotHistory capacity must be positive")
        self.capacity = capacity
        self.storage.reserveCapacity(capacity)
    }

    public mutating func append(_ snapshot: Snapshot) {
        if storage.count >= capacity {
            storage.removeFirst(storage.count - capacity + 1)
        }
        storage.append(snapshot)
    }

    public mutating func clear() {
        storage.removeAll(keepingCapacity: true)
    }

    public var snapshots: [Snapshot] { storage }
    public var count: Int { storage.count }
    public var isEmpty: Bool { storage.isEmpty }
    public var latest: Snapshot? { storage.last }

    public func cpuTotalSeries() -> [Double] {
        storage.map(\.cpu.totalPercent)
    }

    public func ramUsedSeries() -> [Double] {
        storage.map(\.ram.usedPercent)
    }

    public func gpuSeries() -> [Double] {
        storage.map { $0.gpu?.utilizationPercent ?? 0 }
    }
}
