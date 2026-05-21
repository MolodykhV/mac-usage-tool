import CIOReport
import CoreFoundation
import Foundation
import OSLog

public enum GPUReadError: Error, Equatable, Sendable {
    case channelDiscoveryFailed
    case subscriptionFailed
    case sampleFailed
    case noResidencyChannelFound
}

public struct GPUStateChannel: Sendable, Equatable {
    public let group: String
    public let channelName: String
    public let states: [State]

    public struct State: Sendable, Equatable {
        public let name: String
        public let residencyNanoseconds: Int64

        public init(name: String, residencyNanoseconds: Int64) {
            self.name = name
            self.residencyNanoseconds = residencyNanoseconds
        }
    }

    public init(group: String, channelName: String, states: [State]) {
        self.group = group
        self.channelName = channelName
        self.states = states
    }
}

public final class GPUReader {
    private static let log = Logger(subsystem: "com.molodykh.PlumageBar", category: "gpu")

    // CFTypeRef-bridged. ARC balances the +1 retain from IOReportCreateSubscription
    // when this property is reassigned or the reader is deallocated.
    private var subscription: IOReportSubscription?
    private var subscribedChannels: CFMutableDictionary?
    private var lastSample: CFDictionary?

    public init() {}

    public func read() throws -> GPUUsage {
        try ensureSubscribed()
        guard let subscription, let subscribedChannels else {
            throw GPUReadError.subscriptionFailed
        }
        guard let current = IOReportCreateSamples(subscription, subscribedChannels, nil) else {
            throw GPUReadError.sampleFailed
        }
        guard let previous = self.lastSample else {
            self.lastSample = current
            return GPUUsage(utilizationPercent: 0)
        }
        guard let delta = IOReportCreateSamplesDelta(previous, current, nil) else {
            throw GPUReadError.sampleFailed
        }
        // Only adopt the new baseline once the delta succeeded — a transient
        // delta failure should not discard the previous sample and force the
        // next read to start over from zero.
        self.lastSample = current
        let channels = Self.extractStateChannels(from: delta)
        guard let usage = Self.parseUtilization(from: channels) else {
            throw GPUReadError.noResidencyChannelFound
        }
        return usage
    }

    public func reset() {
        self.lastSample = nil
    }

    static func parseUtilization(from channels: [GPUStateChannel]) -> GPUUsage? {
        guard let gpuChannel = channels.first(where: { $0.group == "GPU Stats" && !$0.states.isEmpty })
        else {
            return nil
        }
        let totalNs = gpuChannel.states.reduce(Int64(0)) { $0 &+ $1.residencyNanoseconds }
        guard totalNs > 0 else { return GPUUsage(utilizationPercent: 0) }
        let idleNs = gpuChannel.states
            .filter { Self.isIdleStateName($0.name) }
            .reduce(Int64(0)) { $0 &+ $1.residencyNanoseconds }
        let activeNs = max(0, totalNs &- idleNs)
        let pct = Double(activeNs) / Double(totalNs) * 100.0
        return GPUUsage(utilizationPercent: min(100.0, max(0.0, pct)))
    }

    static func isIdleStateName(_ name: String) -> Bool {
        // Apple Silicon GPU residency channels label the off/idle state with
        // one of these names (verified against macmon and Stats). P-state
        // labels like "P1", "P2" are active states and must NOT match here.
        let lower = name.lowercased()
        return lower == "idle" || lower == "off" || lower == "down"
    }

    private static func extractStateChannels(from delta: CFDictionary) -> [GPUStateChannel] {
        var collected: [GPUStateChannel] = []
        IOReportIterate(delta) { sample -> Int32 in
            guard let sample else { return 0 }
            let group = (IOReportChannelGetGroup(sample) as String?) ?? ""
            let channelName = (IOReportChannelGetChannelName(sample) as String?) ?? ""
            let stateCount = IOReportStateGetCount(sample)
            guard stateCount > 0 else { return 0 }
            var states: [GPUStateChannel.State] = []
            states.reserveCapacity(Int(stateCount))
            for i in 0..<stateCount {
                let name = (IOReportStateGetNameForIndex(sample, i) as String?) ?? "state-\(i)"
                let residency = IOReportStateGetResidency(sample, i)
                states.append(.init(name: name, residencyNanoseconds: residency))
            }
            collected.append(
                GPUStateChannel(group: group, channelName: channelName, states: states)
            )
            return 0
        }
        return collected
    }

    private func ensureSubscribed() throws {
        if subscription != nil { return }
        let group = "GPU Stats" as CFString
        guard let desired = IOReportCopyChannelsInGroup(group, nil, 0, 0, 0) else {
            throw GPUReadError.channelDiscoveryFailed
        }
        var subbed: Unmanaged<CFMutableDictionary>?
        guard let sub = IOReportCreateSubscription(nil, desired, &subbed, 0, nil) else {
            throw GPUReadError.subscriptionFailed
        }
        guard let subbedRef = subbed?.takeRetainedValue() else {
            throw GPUReadError.subscriptionFailed
        }
        self.subscription = sub
        self.subscribedChannels = subbedRef
    }
}
