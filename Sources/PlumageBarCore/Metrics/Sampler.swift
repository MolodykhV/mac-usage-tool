import Foundation
import OSLog

public actor LiveMetricsProvider: MetricsProvider {
    public nonisolated let snapshots: AsyncStream<Snapshot>
    private nonisolated let continuation: AsyncStream<Snapshot>.Continuation

    private var interval: Duration
    // Process scanning is the most expensive part of a tick (proc_listallpids +
    // proc_pidinfo per PID). Run it every Nth tick to keep the steady-state CPU
    // budget low; 2 → twice the sample interval is responsive enough for a
    // top-3 dashboard while halving the iteration cost.
    private let processSamplingStride: Int
    private var tickCounter: Int = 0

    private let cpu: CPUReader
    private let ram: RAMReader
    private let gpu: GPUReader
    private let processes: ProcessReader
    private var samplingTask: Task<Void, Never>?
    private var gpuDisabled = false
    private var lastProcessReport: ProcessReport?

    private static let log = Logger(subsystem: "com.molodykh.PlumageBar", category: "sampler")

    public init(interval: Duration = .seconds(1), processSamplingStride: Int = 2) {
        self.interval = interval
        self.processSamplingStride = max(1, processSamplingStride)
        self.cpu = CPUReader()
        self.ram = RAMReader()
        self.gpu = GPUReader()
        self.processes = ProcessReader()
        let (stream, continuation) = AsyncStream<Snapshot>.makeStream(
            bufferingPolicy: .bufferingNewest(8)
        )
        self.snapshots = stream
        self.continuation = continuation
    }

    deinit {
        continuation.finish()
    }

    public func start() {
        guard samplingTask == nil else { return }
        samplingTask = Task { [weak self] in
            // SuspendingClock pauses while the Mac sleeps, so wake-from-sleep
            // does not produce a burst of "missed" ticks. The fixed-cadence
            // sleep(until:) prevents drift from accumulating tick latency.
            var next = SuspendingClock.now
            while !Task.isCancelled {
                guard let self else { return }
                let currentInterval = await self.interval
                await self.tick()
                next = next.advanced(by: currentInterval)
                do {
                    try await Task.sleep(until: next, clock: .suspending)
                } catch {
                    return
                }
            }
        }
    }

    public func stop() {
        samplingTask?.cancel()
        samplingTask = nil
        continuation.finish()
    }

    /// Updates the sample cadence. Takes effect on the next tick (the current
    /// in-flight sleep finishes against the previous interval, then the new
    /// value is read).
    public func setInterval(_ newInterval: Duration) {
        self.interval = newInterval
    }

    private func tick() {
        let cpuUsage: CPUUsage
        do {
            cpuUsage = try cpu.read()
        } catch {
            Self.log.error("CPU read failed: \(String(describing: error), privacy: .public)")
            cpuUsage = Self.defaultCPU
        }

        let ramUsage: RAMUsage
        do {
            ramUsage = try ram.read()
        } catch {
            Self.log.error("RAM read failed: \(String(describing: error), privacy: .public)")
            ramUsage = Self.defaultRAM
        }

        let gpuUsage: GPUUsage?
        if gpuDisabled {
            gpuUsage = nil
        } else {
            do {
                gpuUsage = try gpu.read()
            } catch {
                Self.log.error("GPU read failed: \(String(describing: error), privacy: .public)")
                Self.log.error("Disabling GPU sampling for the rest of this session")
                gpuDisabled = true
                gpuUsage = nil
            }
        }

        if tickCounter % processSamplingStride == 0 {
            do {
                lastProcessReport = try processes.read(topN: 3)
            } catch {
                Self.log.error(
                    "Process read failed: \(String(describing: error), privacy: .public)")
                lastProcessReport = nil
            }
        }
        tickCounter &+= 1

        let snap = Snapshot(
            timestamp: Date(),
            cpu: cpuUsage,
            ram: ramUsage,
            gpu: gpuUsage,
            processes: lastProcessReport
        )
        continuation.yield(snap)
    }

    private static let defaultCPU = CPUUsage(
        userPercent: 0,
        systemPercent: 0,
        idlePercent: 100,
        totalPercent: 0,
        perCoreTotalPercent: []
    )

    private static let defaultRAM = RAMUsage(
        totalBytes: 0,
        usedBytes: 0,
        freeBytes: 0,
        usedPercent: 0
    )
}
