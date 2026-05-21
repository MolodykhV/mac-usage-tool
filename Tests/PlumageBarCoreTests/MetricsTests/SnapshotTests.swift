import Foundation
import Testing

@testable import PlumageBarCore

@Suite("Snapshot Codable round-trip")
struct SnapshotTests {

    @Test("Full snapshot survives JSON encode/decode")
    func fullRoundTrip() throws {
        let snap = Snapshot(
            timestamp: Date(timeIntervalSince1970: 1_700_000_000),
            cpu: CPUUsage(
                userPercent: 12.5,
                systemPercent: 7.5,
                idlePercent: 80.0,
                totalPercent: 20.0,
                perCoreTotalPercent: [25, 15]
            ),
            ram: RAMUsage(
                totalBytes: 16 * 1024 * 1024 * 1024,
                usedBytes: 8 * 1024 * 1024 * 1024,
                freeBytes: 8 * 1024 * 1024 * 1024,
                usedPercent: 50.0
            ),
            gpu: GPUUsage(utilizationPercent: 35.0)
        )
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(Snapshot.self, from: data)
        #expect(snap == decoded)
    }

    @Test("Snapshot with nil GPU encodes and decodes correctly")
    func nilGPURoundTrip() throws {
        let snap = Snapshot(
            timestamp: Date(timeIntervalSince1970: 0),
            cpu: CPUUsage(
                userPercent: 0,
                systemPercent: 0,
                idlePercent: 100,
                totalPercent: 0,
                perCoreTotalPercent: []
            ),
            ram: RAMUsage(totalBytes: 0, usedBytes: 0, freeBytes: 0, usedPercent: 0),
            gpu: nil
        )
        let data = try JSONEncoder().encode(snap)
        let decoded = try JSONDecoder().decode(Snapshot.self, from: data)
        #expect(decoded.gpu == nil)
        #expect(snap == decoded)
    }

    @Test("Snapshot JSON without an explicit gpu key decodes as gpu = nil")
    func missingGPUKeyDecodes() throws {
        let json = #"""
            {
                "timestamp": 0,
                "cpu": {
                    "userPercent": 0,
                    "systemPercent": 0,
                    "idlePercent": 100,
                    "totalPercent": 0,
                    "perCoreTotalPercent": []
                },
                "ram": {
                    "totalBytes": 0,
                    "usedBytes": 0,
                    "freeBytes": 0,
                    "usedPercent": 0
                }
            }
            """#
        let data = Data(json.utf8)
        let decoded = try JSONDecoder().decode(Snapshot.self, from: data)
        #expect(decoded.gpu == nil)
    }
}
