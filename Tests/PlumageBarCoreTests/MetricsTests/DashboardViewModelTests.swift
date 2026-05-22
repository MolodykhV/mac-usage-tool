import Foundation
import Testing

@testable import PlumageBarCore

@Suite("DashboardViewModel")
struct DashboardViewModelTests {

    @Test("bind() drains the provider's AsyncStream into history")
    @MainActor
    func bindDrainsStream() async throws {
        let provider = MockMetricsProvider()
        let vm = DashboardViewModel()
        vm.bind(to: provider)

        provider.yield(snap(at: 0, cpu: 10))
        provider.yield(snap(at: 1, cpu: 20))
        provider.yield(snap(at: 2, cpu: 30))

        try await waitForCondition(timeoutSeconds: 1) {
            vm.history.count >= 3
        }
        #expect(vm.history.cpuTotalSeries() == [10, 20, 30])
        #expect(vm.latest?.cpu.totalPercent == 30)

        await vm.unbind()
        provider.finish()
    }

    @Test("unbind() stops consuming from the stream")
    @MainActor
    func unbindStops() async throws {
        let provider = MockMetricsProvider()
        let vm = DashboardViewModel()
        vm.bind(to: provider)

        provider.yield(snap(at: 0, cpu: 5))
        try await waitForCondition(timeoutSeconds: 1) {
            vm.history.count >= 1
        }
        await vm.unbind()

        provider.yield(snap(at: 1, cpu: 50))
        try? await Task.sleep(for: .milliseconds(150))
        #expect(vm.history.count == 1)
        provider.finish()
    }

    // MARK: - Helpers

    private func snap(at seconds: TimeInterval, cpu: Double) -> Snapshot {
        Snapshot(
            timestamp: Date(timeIntervalSince1970: seconds),
            cpu: CPUUsage(
                userPercent: 0, systemPercent: 0, idlePercent: 100 - cpu,
                totalPercent: cpu, perCoreTotalPercent: []
            ),
            ram: RAMUsage(totalBytes: 0, usedBytes: 0, freeBytes: 0, usedPercent: 0),
            gpu: nil
        )
    }

    @MainActor
    private func waitForCondition(
        timeoutSeconds: Double,
        check: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(timeoutSeconds))
        while ContinuousClock.now < deadline {
            if check() { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(check())
    }
}

@MainActor
private final class MockMetricsProvider: MetricsProvider {
    let snapshots: AsyncStream<Snapshot>
    private let continuation: AsyncStream<Snapshot>.Continuation

    init() {
        let (stream, continuation) = AsyncStream<Snapshot>.makeStream()
        self.snapshots = stream
        self.continuation = continuation
    }

    nonisolated func yield(_ snapshot: Snapshot) {
        continuation.yield(snapshot)
    }

    nonisolated func finish() {
        continuation.finish()
    }

    func start() async {}
    func stop() async {}
}
