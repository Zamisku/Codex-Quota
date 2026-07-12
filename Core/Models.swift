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
        shortWindow: UsageWindow(
            remainingPercent: 72,
            resetsAt: Date().addingTimeInterval(2.5 * 3600),
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
