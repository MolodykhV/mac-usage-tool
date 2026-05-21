import Testing

@testable import PlumageBarCore

@Suite("GPUReader.parseUtilization")
struct GPUReaderTests {

    @Test("All-idle channel reports 0%")
    func allIdle() {
        let channels = [
            GPUStateChannel(
                group: "GPU Stats",
                channelName: "GPU PerfStates",
                states: [
                    .init(name: "IDLE", residencyNanoseconds: 1_000_000_000),
                    .init(name: "P1", residencyNanoseconds: 0),
                    .init(name: "P2", residencyNanoseconds: 0),
                ]
            )
        ]
        let usage = GPUReader.parseUtilization(from: channels)
        #expect(usage == GPUUsage(utilizationPercent: 0))
    }

    @Test("DOWN residency is also treated as idle")
    func downStateIsIdle() {
        let channels = [
            GPUStateChannel(
                group: "GPU Stats",
                channelName: "GPU PerfStates",
                states: [
                    .init(name: "DOWN", residencyNanoseconds: 800_000_000),
                    .init(name: "P1", residencyNanoseconds: 200_000_000),
                ]
            )
        ]
        let usage = GPUReader.parseUtilization(from: channels)
        #expect(usage != nil)
        #expect(abs((usage?.utilizationPercent ?? -1) - 20.0) < 0.001)
    }

    @Test("Multiple idle states (IDLE + DOWN) are summed before dividing")
    func multipleIdleStates() {
        let channels = [
            GPUStateChannel(
                group: "GPU Stats",
                channelName: "GPU PerfStates",
                states: [
                    .init(name: "IDLE", residencyNanoseconds: 300_000_000),
                    .init(name: "DOWN", residencyNanoseconds: 200_000_000),
                    .init(name: "P1", residencyNanoseconds: 500_000_000),
                ]
            )
        ]
        let usage = GPUReader.parseUtilization(from: channels)
        #expect(usage != nil)
        #expect(abs((usage?.utilizationPercent ?? -1) - 50.0) < 0.001)
    }

    @Test("No idle residency reports 100%")
    func allActive() {
        let channels = [
            GPUStateChannel(
                group: "GPU Stats",
                channelName: "GPU PerfStates",
                states: [
                    .init(name: "IDLE", residencyNanoseconds: 0),
                    .init(name: "P1", residencyNanoseconds: 700_000_000),
                    .init(name: "P2", residencyNanoseconds: 300_000_000),
                ]
            )
        ]
        let usage = GPUReader.parseUtilization(from: channels)
        #expect(usage == GPUUsage(utilizationPercent: 100))
    }

    @Test("70% active when 30% residency sits in IDLE")
    func mixedActivity() {
        let channels = [
            GPUStateChannel(
                group: "GPU Stats",
                channelName: "GPU PerfStates",
                states: [
                    .init(name: "IDLE", residencyNanoseconds: 300_000_000),
                    .init(name: "P1", residencyNanoseconds: 400_000_000),
                    .init(name: "P2", residencyNanoseconds: 300_000_000),
                ]
            )
        ]
        let usage = GPUReader.parseUtilization(from: channels)
        #expect(usage != nil)
        #expect(abs((usage?.utilizationPercent ?? -1) - 70.0) < 0.001)
    }

    @Test("Empty channels list returns nil")
    func emptyChannels() {
        #expect(GPUReader.parseUtilization(from: []) == nil)
    }

    @Test("Channels in non-GPU groups are ignored")
    func nonGPUGroupsIgnored() {
        let channels = [
            GPUStateChannel(
                group: "Energy Model",
                channelName: "CPU Energy",
                states: [.init(name: "ON", residencyNanoseconds: 1_000)]
            )
        ]
        #expect(GPUReader.parseUtilization(from: channels) == nil)
    }

    @Test("Idle-state detection is case-insensitive and recognises common labels")
    func idleStateNames() {
        #expect(GPUReader.isIdleStateName("IDLE"))
        #expect(GPUReader.isIdleStateName("idle"))
        #expect(GPUReader.isIdleStateName("OFF"))
        #expect(GPUReader.isIdleStateName("off"))
        #expect(GPUReader.isIdleStateName("DOWN"))
        #expect(GPUReader.isIdleStateName("down"))
        // P-state labels are active states on Apple Silicon (P0 is the
        // highest-performance perf state on Intel; modern Apple GPUs label
        // perf states P1, P2, … with idle exposed separately).
        #expect(!GPUReader.isIdleStateName("P0"))
        #expect(!GPUReader.isIdleStateName("P1"))
        #expect(!GPUReader.isIdleStateName("Active"))
        #expect(!GPUReader.isIdleStateName(""))
    }

    @Test("First GPU Stats channel wins when multiple present")
    func firstChannelWins() {
        let channels = [
            GPUStateChannel(
                group: "GPU Stats",
                channelName: "First",
                states: [
                    .init(name: "IDLE", residencyNanoseconds: 0),
                    .init(name: "P1", residencyNanoseconds: 100),
                ]
            ),
            GPUStateChannel(
                group: "GPU Stats",
                channelName: "Second",
                states: [
                    .init(name: "IDLE", residencyNanoseconds: 100),
                    .init(name: "P1", residencyNanoseconds: 0),
                ]
            ),
        ]
        let usage = GPUReader.parseUtilization(from: channels)
        #expect(usage == GPUUsage(utilizationPercent: 100))
    }
}
