import Foundation
import XCTest

final class QuotaResponseParserTests: XCTestCase {
    func testParsesSnakeCaseAndCredits() throws {
        let usage = data(#"""
        {
          "plan_type": "plus",
          "rate_limit": {
            "primary_window": {"used_percent": 26, "reset_at": 1738300000, "limit_window_seconds": 18000},
            "secondary_window": {"remaining_percent": 88, "reset_at": "2026-07-19T00:00:00Z", "limit_window_seconds": 604800}
          },
          "rate_limit_reset_credits": {"available_count": 2, "credits": [{"expires_at": "2026-08-01T00:00:00Z"}]}
        }
        """#)
        let result = try QuotaResponseParser.parse(usageData: usage)
        XCTAssertEqual(result.plan, "PLUS")
        XCTAssertEqual(result.shortWindow?.remainingPercent, 74)
        XCTAssertEqual(result.weeklyWindow?.remainingPercent, 88)
        XCTAssertEqual(result.resetCredits, 2)
        XCTAssertEqual(result.resetCreditExpirations.count, 1)
    }

    func testFindsArrayWindows() throws {
        let usage = data(#"""
        {"rateLimit":{"windows":[
          {"name":"weekly","remainingRatio":0.8,"windowSeconds":604800},
          {"name":"primary","utilization":0.4,"windowSeconds":18000}
        ]}}
        """#)
        let result = try QuotaResponseParser.parse(usageData: usage)
        XCTAssertEqual(result.shortWindow?.remainingPercent, 60)
        XCTAssertEqual(result.weeklyWindow?.remainingPercent, 80)
    }

    func testDistinguishesPercentAndRatio() throws {
        let percent = data(#"{"rate_limit":{"primary_window":{"remaining_percent":0.4}}}"#)
        let ratio = data(#"{"rate_limit":{"primary_window":{"remaining":0.4}}}"#)
        XCTAssertEqual(try QuotaResponseParser.parse(usageData: percent).shortWindow?.remainingPercent, 0.4)
        XCTAssertEqual(try QuotaResponseParser.parse(usageData: ratio).shortWindow?.remainingPercent, 40)
    }

    func testDedicatedCreditsOverrideEmbedded() throws {
        let usage = data(#"{"rate_limit":{"primary_window":{"remaining_percent":50}},"rate_limit_reset_credits":{"available_count":1}}"#)
        let credits = data(#"{"availableCount":3}"#)
        XCTAssertEqual(try QuotaResponseParser.parse(usageData: usage, creditsData: credits).resetCredits, 3)
    }

    func testRejectsMissingShortWindowAndBoolean() {
        XCTAssertThrowsError(try QuotaResponseParser.parse(
            usageData: data(#"{"rate_limit":{"secondary_window":{"remaining_percent":50}}}"#)
        ))
        XCTAssertThrowsError(try QuotaResponseParser.parse(
            usageData: data(#"{"rate_limit":{"primary_window":{"remaining":true}}}"#)
        ))
    }

    func testMarksOnlyExpiredSuccessfulSnapshotAsStale() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let old = ProviderSnapshot(
            plan: "PLUS",
            shortWindow: UsageWindow(remainingPercent: 60, resetsAt: nil, windowSeconds: 18_000),
            weeklyWindow: nil,
            resetCredits: nil,
            resetCreditExpirations: [],
            updatedAt: now.addingTimeInterval(-2_701),
            status: .ok,
            failure: nil
        )
        let fresh = ProviderSnapshot(
            plan: old.plan,
            shortWindow: old.shortWindow,
            weeklyWindow: old.weeklyWindow,
            resetCredits: old.resetCredits,
            resetCreditExpirations: old.resetCreditExpirations,
            updatedAt: now.addingTimeInterval(-2_699),
            status: .ok,
            failure: nil
        )

        let stale = old.markedStaleIfExpired(at: now, maximumAge: 2_700)
        XCTAssertEqual(stale.status, .stale)
        XCTAssertEqual(stale.failure, .serviceUnavailable)
        XCTAssertEqual(stale.shortWindow, old.shortWindow)
        XCTAssertEqual(fresh.markedStaleIfExpired(at: now, maximumAge: 2_700), fresh)
    }

    private func data(_ string: String) -> Data { Data(string.utf8) }
}
