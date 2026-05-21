public protocol MetricsProvider: AnyObject, Sendable {
    nonisolated var snapshots: AsyncStream<Snapshot> { get }
    func start() async
    func stop() async
}
