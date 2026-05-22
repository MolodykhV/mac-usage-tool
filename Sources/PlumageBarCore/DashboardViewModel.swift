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
        // The previous consumer might be mid-iteration on its stream; cancel
        // it eagerly so it stops appending, but don't wait for it here. The
        // cancelled task may still drain one buffered value from the old
        // stream before noticing cancellation. Callers that need a hard
        // boundary should `await unbind()` before rebinding.
        observerTask?.cancel()
        let stream = provider.snapshots
        observerTask = Task { @MainActor [weak self] in
            for await snap in stream {
                guard let self else { return }
                if Task.isCancelled { return }
                self.history.append(snap)
            }
        }
    }

    /// Cancels the snapshot consumer and waits for it to fully exit before
    /// returning. After this point any new value yielded into the stream is
    /// guaranteed not to land in `history` — the for-await loop has already
    /// observed cancellation.
    public func unbind() async {
        let task = observerTask
        observerTask = nil
        task?.cancel()
        _ = await task?.value
    }
}
