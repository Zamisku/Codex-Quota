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

    func testParsesWeeklyOnlySecondaryWindow() throws {
        let usage = data(#"{"rate_limit":{"secondary_window":{"remaining_percent":81,"limit_window_seconds":604800}}}"#)
        let result = try QuotaResponseParser.parse(usageData: usage)

        XCTAssertNil(result.shortWindow)
        XCTAssertEqual(result.weeklyWindow?.remainingPercent, 81)
        XCTAssertEqual(result.primaryWindowKind, .weekly)
    }

    func testClassifiesWeeklyOnlyPrimaryWindowByDuration() throws {
        let usage = data(#"{"rate_limit":{"primary_window":{"remaining_percent":79,"limit_window_seconds":604800}}}"#)
        let result = try QuotaResponseParser.parse(usageData: usage)

        XCTAssertNil(result.shortWindow)
        XCTAssertEqual(result.weeklyWindow?.remainingPercent, 79)
    }

    func testDurationWinsOverLegacyFieldNames() throws {
        let usage = data(#"""
        {"rate_limit":{
          "primary_window":{"remaining_percent":77,"limit_window_seconds":604800},
          "secondary_window":{"remaining_percent":63,"limit_window_seconds":18000}
        }}
        """#)
        let result = try QuotaResponseParser.parse(usageData: usage)

        XCTAssertEqual(result.shortWindow?.remainingPercent, 63)
        XCTAssertEqual(result.weeklyWindow?.remainingPercent, 77)
    }

    func testDistinguishesPercentAndRatio() throws {
        let percent = data(#"{"rate_limit":{"primary_window":{"remaining_percent":0.4}}}"#)
        let ratio = data(#"{"rate_limit":{"primary_window":{"remaining":0.4}}}"#)
        let percentResult = try QuotaResponseParser.parse(usageData: percent)
        let ratioResult = try QuotaResponseParser.parse(usageData: ratio)

        XCTAssertNil(percentResult.shortWindow)
        XCTAssertEqual(percentResult.weeklyWindow?.remainingPercent, 0.4)
        XCTAssertNil(ratioResult.shortWindow)
        XCTAssertEqual(ratioResult.weeklyWindow?.remainingPercent, 40)
    }

    func testDedicatedCreditsOverrideEmbedded() throws {
        let usage = data(#"{"rate_limit":{"primary_window":{"remaining_percent":50}},"rate_limit_reset_credits":{"available_count":1}}"#)
        let credits = data(#"{"availableCount":3}"#)
        XCTAssertEqual(try QuotaResponseParser.parse(usageData: usage, creditsData: credits).resetCredits, 3)
    }

    func testSupportsShortOnlyForFutureCompatibility() throws {
        let result = try QuotaResponseParser.parse(
            usageData: data(#"{"rate_limit":{"primary_window":{"remaining_percent":52,"limit_window_seconds":18000}}}"#)
        )

        XCTAssertEqual(result.shortWindow?.remainingPercent, 52)
        XCTAssertNil(result.weeklyWindow)
        XCTAssertEqual(result.primaryWindowKind, .short)
    }

    func testRejectsMissingOrBooleanWindow() {
        for usage in [
            #"{"rate_limit":{}}"#,
            #"{"rate_limit":{"primary_window":{"remaining":true}}}"#
        ] {
            XCTAssertThrowsError(try QuotaResponseParser.parse(
                usageData: data(usage)
            )) { error in
                XCTAssertEqual(error as? QuotaFailure, .responseChanged)
            }
        }
    }

    func testKeepsLegacyMissingShortWindowSnapshotDecodable() throws {
        let fixture = data(#"""
        {
          "failure":"missingShortWindow",
          "plan":null,
          "resetCreditExpirations":[],
          "resetCredits":null,
          "shortWindow":null,
          "status":"unavailable",
          "updatedAt":"2001-01-01T00:02:03Z",
          "weeklyWindow":null
        }
        """#)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ProviderSnapshot.self, from: fixture)

        XCTAssertEqual(decoded.failure, .missingShortWindow)
        XCTAssertEqual(decoded.updatedAt, Date(timeIntervalSinceReferenceDate: 123))
    }

    func testPrimaryWindowPrefersRestoredShortWindow() throws {
        let weeklyOnly = try QuotaResponseParser.parse(
            usageData: data(#"{"rate_limit":{"weekly_window":{"remaining_percent":82,"limit_window_seconds":604800}}}"#)
        )
        let dual = try QuotaResponseParser.parse(
            usageData: data(#"""
            {"rate_limit":{
              "primary_window":{"remaining_percent":54,"limit_window_seconds":18000},
              "weekly_window":{"remaining_percent":82,"limit_window_seconds":604800}
            }}
            """#)
        )

        XCTAssertEqual(weeklyOnly.primaryWindow, weeklyOnly.weeklyWindow)
        XCTAssertEqual(weeklyOnly.primaryWindowKind, .weekly)
        XCTAssertTrue(weeklyOnly.hasUsageWindow)
        XCTAssertEqual(dual.primaryWindow, dual.shortWindow)
        XCTAssertEqual(dual.primaryWindowKind, .short)
    }

    func testDurationlessLegacyDualWindowsStillRestoreShortWindow() throws {
        let result = try QuotaResponseParser.parse(
            usageData: data(#"""
            {"rate_limit":{
              "primary_window":{"remaining_percent":48},
              "secondary_window":{"remaining_percent":76}
            }}
            """#)
        )

        XCTAssertEqual(result.shortWindow?.remainingPercent, 48)
        XCTAssertEqual(result.weeklyWindow?.remainingPercent, 76)
    }

    func testIgnoresUnknownDirectWindowFields() throws {
        let valid = try QuotaResponseParser.parse(
            usageData: data(#"""
            {"rate_limit":{
              "unknown_window":{"remaining_percent":1,"limit_window_seconds":604800},
              "weekly_window":{"remaining_percent":83,"limit_window_seconds":604800}
            }}
            """#)
        )
        XCTAssertEqual(valid.weeklyWindow?.remainingPercent, 83)

        XCTAssertThrowsError(try QuotaResponseParser.parse(
            usageData: data(#"{"rate_limit":{"unknown_window":{"remaining_percent":1,"limit_window_seconds":604800}}}"#)
        )) { error in
            XCTAssertEqual(error as? QuotaFailure, .responseChanged)
        }
    }

    func testMarksOnlyExpiredSuccessfulSnapshotAsStale() {
        let now = Date(timeIntervalSince1970: 2_000_000)
        let old = ProviderSnapshot(
            plan: "PLUS",
            shortWindow: nil,
            weeklyWindow: UsageWindow(remainingPercent: 60, resetsAt: nil, windowSeconds: 604_800),
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
        XCTAssertEqual(stale.weeklyWindow, old.weeklyWindow)
        XCTAssertEqual(fresh.markedStaleIfExpired(at: now, maximumAge: 2_700), fresh)
    }

    private func data(_ string: String) -> Data { Data(string.utf8) }
}
