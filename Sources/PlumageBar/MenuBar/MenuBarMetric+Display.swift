import PlumageBarCore

extension MenuBarMetric {
    var systemImageName: String {
        switch self {
        case .cpu: return "cpu"
        case .gpu: return "display"
        case .ram: return "memorychip"
        }
    }

    var localizationKey: String {
        switch self {
        case .cpu: return "metric.cpu"
        case .gpu: return "metric.gpu"
        case .ram: return "metric.ram"
        }
    }

    var accessibilityFallback: String {
        switch self {
        case .cpu: return "CPU"
        case .gpu: return "GPU"
        case .ram: return "Memory"
        }
    }
}
