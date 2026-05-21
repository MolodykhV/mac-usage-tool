public import Foundation
import OSLog
public import Observation

@MainActor
@Observable
public final class SettingsStore {

    public private(set) var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            persist(settings)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let key: String
    @ObservationIgnored
    private static let log = Logger(subsystem: "com.molodykh.PlumageBar", category: "settings")

    public init(defaults: UserDefaults = .standard, key: String = "AppSettings.v1") {
        self.defaults = defaults
        self.key = key
        self.settings = Self.load(from: defaults, key: key)
    }

    public func update(_ mutate: (inout AppSettings) -> Void) {
        var copy = settings
        mutate(&copy)
        settings = copy
    }

    public func resetToDefaults() {
        settings = .default
    }

    private static func load(from defaults: UserDefaults, key: String) -> AppSettings {
        guard let data = defaults.data(forKey: key) else { return .default }
        do {
            return try JSONDecoder().decode(AppSettings.self, from: data)
        } catch {
            log.error(
                "Failed to decode settings, falling back to defaults: \(String(describing: error), privacy: .public)"
            )
            return .default
        }
    }

    private func persist(_ value: AppSettings) {
        do {
            let data = try JSONEncoder().encode(value)
            defaults.set(data, forKey: key)
        } catch {
            Self.log.error(
                "Failed to encode settings: \(String(describing: error), privacy: .public)")
        }
    }
}
