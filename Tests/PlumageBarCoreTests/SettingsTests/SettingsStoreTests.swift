import Foundation
import Testing

@testable import PlumageBarCore

@Suite("SettingsStore")
struct SettingsStoreTests {

    @MainActor
    private func makeStore(
        suiteName: String = "PlumageBarTest-\(UUID().uuidString)"
    )
        -> (SettingsStore, UserDefaults)
    {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            fatalError("Could not create scratch UserDefaults suite")
        }
        defaults.removePersistentDomain(forName: suiteName)
        return (SettingsStore(defaults: defaults, key: "AppSettings.v1"), defaults)
    }

    @Test("Fresh store loads defaults when no persisted blob exists")
    @MainActor
    func freshStoreLoadsDefaults() {
        let (store, _) = makeStore()
        #expect(store.settings == .default)
    }

    @Test("update() persists changes and the next store instance reads them back")
    @MainActor
    func updatePersistsAndReloads() {
        let suite = "PlumageBarTest-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suite)

        let storeA = SettingsStore(defaults: defaults, key: "AppSettings.v1")
        storeA.update {
            $0.sampling.intervalSeconds = 4
            $0.menuBar.ramFormat = .absolute
            $0.menuBar.visibleMetrics = [.cpu, .ram]
        }

        let storeB = SettingsStore(defaults: defaults, key: "AppSettings.v1")
        #expect(storeB.settings.sampling.intervalSeconds == 4)
        #expect(storeB.settings.menuBar.ramFormat == .absolute)
        #expect(storeB.settings.menuBar.visibleMetrics == [.cpu, .ram])
    }

    @Test("Corrupted persisted blob falls back to defaults without throwing")
    @MainActor
    func corruptedBlobFallsBack() {
        let suite = "PlumageBarTest-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            Issue.record("Could not create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suite)
        defaults.set(Data("not valid json".utf8), forKey: "AppSettings.v1")

        let store = SettingsStore(defaults: defaults, key: "AppSettings.v1")
        #expect(store.settings == .default)
    }

    @Test("resetToDefaults clears in-memory settings")
    @MainActor
    func resetToDefaults() {
        let (store, _) = makeStore()
        store.update { $0.autostart = true }
        #expect(store.settings.autostart == true)
        store.resetToDefaults()
        #expect(store.settings == .default)
    }

    @Test("Identical updates do not trigger a redundant persistence write")
    @MainActor
    func noOpUpdateSkipsWrite() {
        // We can't directly observe the encoder, but if the setter early-outs
        // when newValue == oldValue, settings stays referentially the same and
        // no error is logged. This is mainly a sanity test.
        let (store, defaults) = makeStore()
        defaults.set(Data(), forKey: "AppSettings.v1")  // poison: any later write would replace it
        store.update { _ in /* no change */ }
        // didSet didn't fire because Equatable found no diff → the poisoned
        // blob is untouched.
        #expect(defaults.data(forKey: "AppSettings.v1") == Data())
    }
}
