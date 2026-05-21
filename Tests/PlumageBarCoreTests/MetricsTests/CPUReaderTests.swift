import Testing

@testable import PlumageBarCore

@Suite("CPUReader.computeUsage")
struct CPUReaderTests {

    @Test("Zero delta returns full idle")
    func zeroDelta() {
        let ticks = CPUTicks(user: 100, system: 50, idle: 800, nice: 0)
        let usage = CPUReader.computeUsage(previous: [ticks], current: [ticks])
        #expect(usage.totalPercent == 0)
        #expect(usage.idlePercent == 100)
        #expect(usage.userPercent == 0)
        #expect(usage.systemPercent == 0)
        #expect(usage.perCoreTotalPercent == [0])
    }

    @Test("100% idle delta")
    func fullyIdleDelta() {
        let previous = [CPUTicks(user: 0, system: 0, idle: 0, nice: 0)]
        let current = [CPUTicks(user: 0, system: 0, idle: 1000, nice: 0)]
        let usage = CPUReader.computeUsage(previous: previous, current: current)
        #expect(usage.idlePercent == 100)
        #expect(usage.totalPercent == 0)
        #expect(usage.perCoreTotalPercent == [0])
    }

    @Test("50/50 user vs idle delta")
    func halfLoadDelta() {
        let previous = [CPUTicks(user: 0, system: 0, idle: 0, nice: 0)]
        let current = [CPUTicks(user: 500, system: 0, idle: 500, nice: 0)]
        let usage = CPUReader.computeUsage(previous: previous, current: current)
        #expect(usage.userPercent == 50)
        #expect(usage.idlePercent == 50)
        #expect(usage.totalPercent == 50)
        #expect(usage.perCoreTotalPercent == [50])
    }

    @Test("System and nice count towards total active")
    func systemAndNiceCount() {
        let previous = [CPUTicks(user: 0, system: 0, idle: 0, nice: 0)]
        let current = [CPUTicks(user: 100, system: 200, idle: 300, nice: 400)]
        let usage = CPUReader.computeUsage(previous: previous, current: current)
        #expect(usage.userPercent == 10)
        #expect(usage.systemPercent == 20)
        #expect(usage.idlePercent == 30)
        // user + system + nice = 700, total 1000
        #expect(usage.totalPercent == 70)
    }

    @Test("Per-core values reflect each core independently")
    func perCoreIndependence() {
        let previous = [
            CPUTicks(user: 0, system: 0, idle: 0, nice: 0),
            CPUTicks(user: 0, system: 0, idle: 0, nice: 0),
        ]
        let current = [
            CPUTicks(user: 200, system: 0, idle: 800, nice: 0),
            CPUTicks(user: 800, system: 0, idle: 200, nice: 0),
        ]
        let usage = CPUReader.computeUsage(previous: previous, current: current)
        #expect(usage.perCoreTotalPercent == [20, 80])
        // System-wide should be the average of equal-weighted cores: 50%
        #expect(usage.totalPercent == 50)
    }

    @Test("Counter wraparound is tolerated via wrapping subtraction")
    func wraparoundTolerated() {
        // natural_t (UInt32) wraps; CPUReader stores as UInt64 but does &-
        // arithmetic, so a near-max previous tick subtracted from a small
        // current tick still produces a sensible delta.
        let previous = [CPUTicks(user: UInt64.max - 10, system: 0, idle: 0, nice: 0)]
        let current = [CPUTicks(user: 100, system: 0, idle: 1000, nice: 0)]
        let usage = CPUReader.computeUsage(previous: previous, current: current)
        // Delta user = 100 -(max-10) under wrapping = 111
        // Delta idle = 1000
        // Total = 1111
        let expectedUserPct = Double(111) / Double(1111) * 100.0
        #expect(abs(usage.userPercent - expectedUserPct) < 0.001)
    }

    @Test("Core count mismatch uses the shorter array")
    func coreCountMismatch() {
        let previous = [
            CPUTicks(user: 0, system: 0, idle: 0, nice: 0),
            CPUTicks(user: 0, system: 0, idle: 0, nice: 0),
        ]
        let current = [
            CPUTicks(user: 100, system: 0, idle: 900, nice: 0)
        ]
        let usage = CPUReader.computeUsage(previous: previous, current: current)
        #expect(usage.perCoreTotalPercent.count == 1)
        #expect(usage.perCoreTotalPercent == [10])
    }
}
