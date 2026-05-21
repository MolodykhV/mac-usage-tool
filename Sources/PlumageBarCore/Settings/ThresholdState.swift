public enum ThresholdState: Sendable, Equatable {
    case normal
    case warning
    case exceeded

    /// Margin (in raw percentage points) before the exceeded threshold that
    /// counts as "approaching" / warning. 5 points keeps the visual cue from
    /// flickering on tiny CPU bumps near the boundary.
    public static let warningMargin: Double = 5

    public init(value: Double?, threshold: Double, marginBefore: Double = warningMargin) {
        guard let v = value else {
            self = .normal
            return
        }
        if v >= threshold {
            self = .exceeded
        } else if v >= threshold - marginBefore {
            self = .warning
        } else {
            self = .normal
        }
    }
}
