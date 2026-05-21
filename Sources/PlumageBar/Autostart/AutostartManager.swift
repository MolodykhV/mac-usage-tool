import Foundation
import OSLog
import ServiceManagement

enum AutostartStatus: String, Sendable {
    case notRegistered
    case enabled
    case requiresApproval
    case notFound
    case unknown

    var localizationKey: String {
        switch self {
        case .notRegistered: return "autostart.status.notRegistered"
        case .enabled: return "autostart.status.enabled"
        case .requiresApproval: return "autostart.status.requiresApproval"
        case .notFound: return "autostart.status.notFound"
        case .unknown: return "autostart.status.unknown"
        }
    }
}

@MainActor
final class AutostartManager {

    nonisolated private static let log = Logger(
        subsystem: "com.molodykh.PlumageBar", category: "autostart")

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    var status: AutostartStatus {
        switch SMAppService.mainApp.status {
        case .notRegistered: return .notRegistered
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notFound: return .notFound
        @unknown default: return .unknown
        }
    }

    /// Aligns SMAppService registration with `desired`. Returns whether the
    /// final state matches `desired`; on failure we keep the prior setting
    /// untouched so the UI can offer a retry.
    @discardableResult
    func setEnabled(_ desired: Bool) -> Bool {
        let service = SMAppService.mainApp
        do {
            if desired {
                if service.status == .enabled { return true }
                try service.register()
            } else {
                if service.status == .notRegistered { return true }
                try service.unregister()
            }
            Self.log.info(
                "SMAppService updated → desired=\(desired, privacy: .public) status=\(self.status.rawValue, privacy: .public)"
            )
            return service.status == (desired ? .enabled : .notRegistered)
        } catch {
            Self.log.error(
                "SMAppService update failed: \(String(describing: error), privacy: .public)")
            return false
        }
    }
}
