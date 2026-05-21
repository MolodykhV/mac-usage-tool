public enum MenuBarMetric: String, CaseIterable, Identifiable, Sendable, Codable {
    case cpu
    case gpu
    case ram

    public var id: String { rawValue }

    public func value(in snapshot: Snapshot?) -> Double? {
        guard let snapshot else { return nil }
        switch self {
        case .cpu: return snapshot.cpu.totalPercent
        case .gpu: return snapshot.gpu?.utilizationPercent
        case .ram: return snapshot.ram.usedPercent
        }
    }
}
