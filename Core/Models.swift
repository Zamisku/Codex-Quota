import Foundation

enum SnapshotStatus: String, Codable, Sendable {
    case ok
    case signedOut
    case unavailable
    case stale
}

struct UsageWindow: Codable, Equatable, Sendable {
    let remainingPercent: Double
    let resetsAt: Date?
    let windowSeconds: UInt64

    init(remainingPercent: Double, resetsAt: Date?, windowSeconds: UInt64) {
        self.remainingPercent = min(100, max(0, remainingPercent))
        self.resetsAt = resetsAt
        self.windowSeconds = windowSeconds
    }
}

enum UsageWindowKind: Equatable, Sendable {
    case short
    case weekly
}

struct ProviderSnapshot: Codable, Equatable, Sendable {
    let plan: String?
    let shortWindow: UsageWindow?
    let weeklyWindow: UsageWindow?
    let resetCredits: UInt64?
    let resetCreditExpirations: [Date]
    let updatedAt: Date
    let status: SnapshotStatus
    let failure: QuotaFailure?

    static func failure(_ failure: QuotaFailure, at date: Date = Date()) -> ProviderSnapshot {
        ProviderSnapshot(
            plan: nil,
            shortWindow: nil,
            weeklyWindow: nil,
            resetCredits: nil,
            resetCreditExpirations: [],
            updatedAt: date,
            status: failure.isAuthenticationFailure ? .signedOut : .unavailable,
            failure: failure
        )
    }

    static let preview = ProviderSnapshot(
        plan: "PLUS",
        shortWindow: nil,
        weeklyWindow: UsageWindow(
            remainingPercent: 84,
            resetsAt: Date().addingTimeInterval(4 * 86_400),
            windowSeconds: 604_800
        ),
        resetCredits: 2,
        resetCreditExpirations: [],
        updatedAt: Date(),
        status: .ok,
        failure: nil
    )

    static let themePreview = ProviderSnapshot(
        plan: "PLUS",
        shortWindow: UsageWindow(
            remainingPercent: 72,
            resetsAt: Date().addingTimeInterval(2.5 * 60 * 60),
            windowSeconds: 18_000
        ),
        weeklyWindow: UsageWindow(
            remainingPercent: 84,
            resetsAt: Date().addingTimeInterval(4 * 86_400),
            windowSeconds: 604_800
        ),
        resetCredits: 2,
        resetCreditExpirations: [],
        updatedAt: Date(),
        status: .ok,
        failure: nil
    )

    /// The most time-sensitive quota window currently returned by the service.
    /// A restored short window automatically takes priority over the weekly window.
    var primaryWindow: UsageWindow? { shortWindow ?? weeklyWindow }

    var primaryWindowKind: UsageWindowKind? {
        if shortWindow != nil { return .short }
        if weeklyWindow != nil { return .weekly }
        return nil
    }

    var hasUsageWindow: Bool { primaryWindow != nil }

    func markedStale(with failure: QuotaFailure) -> ProviderSnapshot {
        ProviderSnapshot(
            plan: plan,
            shortWindow: shortWindow,
            weeklyWindow: weeklyWindow,
            resetCredits: resetCredits,
            resetCreditExpirations: resetCreditExpirations,
            updatedAt: updatedAt,
            status: .stale,
            failure: failure
        )
    }

    func markedStaleIfExpired(
        at now: Date = Date(),
        maximumAge: TimeInterval
    ) -> ProviderSnapshot {
        guard status == .ok, now.timeIntervalSince(updatedAt) > maximumAge else { return self }
        return markedStale(with: .serviceUnavailable)
    }
}

enum QuotaFailure: String, Error, Codable, Equatable, Sendable {
    case noSnapshot
    case loginNotFound
    case loginExpired
    case invalidLogin
    case networkUnavailable
    case rateLimited
    case serviceUnavailable
    case responseChanged
    // Kept so snapshots written by older releases remain decodable.
    case missingShortWindow

    var isAuthenticationFailure: Bool {
        switch self {
        case .loginNotFound, .loginExpired, .invalidLogin:
            return true
        default:
            return false
        }
    }
}
