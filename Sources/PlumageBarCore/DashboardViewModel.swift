import Foundation
public import Observation

@MainActor
@Observable
public final class DashboardViewModel {
    public static let historyCapacity = 60

    public var history = SnapshotHistory(capacity: DashboardViewModel.historyCapacity)
    @ObservationIgnored private var observerTask: Task<Void, Never>?

    public var latest: Snapshot? { history.latest }

    public init() {}

    public func bind(to provider: any MetricsProvider) {
        observerTask?.cancel()
        let stream = provider.snapshots
        observerTask = Task { @MainActor [weak self] in
            for await snap in stream {
                guard let self else { return }
                self.history.append(snap)
            }
        }
    }

    public func unbind() {
        observerTask?.cancel()
        observerTask = nil
    }
}
