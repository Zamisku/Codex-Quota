import CoreFoundation
import Foundation

enum QuotaResponseParser {
    private typealias JSONObject = [String: Any]
    private struct WindowCandidate {
        let identifiers: [String]
        let window: UsageWindow
    }

    private static let shortWindowNames = [
        "primary_window", "primaryWindow", "short_window", "shortWindow",
        "five_hour_window", "fiveHourWindow", "5h", "primary"
    ]
    private static let weeklyWindowNames = [
        "secondary_window", "secondaryWindow", "weekly_window", "weeklyWindow",
        "week_window", "weekWindow", "weekly", "secondary"
    ]
    private static let primaryWindowNames = ["primary_window", "primaryWindow", "primary"]
    private static let windowArrayNames = ["windows", "limit_windows", "limitWindows", "limits", "buckets"]

    static func parse(usageData: Data, creditsData: Data? = nil, now: Date = Date()) throws -> ProviderSnapshot {
        guard let usage = try JSONSerialization.jsonObject(with: usageData) as? JSONObject else {
            throw QuotaFailure.responseChanged
        }
        let rateLimit = dictionary(usage["rate_limit"]) ?? dictionary(usage["rateLimit"]) ?? usage
        let candidates = windowCandidates(in: rateLimit)
        var short = findWindow(
            in: candidates,
            names: shortWindowNames,
            expectedSeconds: 18_000
        )
        var weekly = findWindow(
            in: candidates,
            names: weeklyWindowNames,
            expectedSeconds: 604_800
        )

        // With the current weekly-only policy, a lone durationless primary window
        // is ambiguous. Default it to weekly; explicit labels, durations, or a
        // simultaneous secondary window still restore the legacy short-window path.
        if weekly == nil, short != nil, isLoneAmbiguousPrimary(candidates) {
            weekly = short
            short = nil
        }
        guard short != nil || weekly != nil else { throw QuotaFailure.responseChanged }

        let embedded = dictionary(usage["rate_limit_reset_credits"])
            ?? dictionary(usage["rateLimitResetCredits"])
        var count = embedded.flatMap(creditCount)
        var expirations = embedded.map(collectExpirations) ?? []
        if let creditsData,
           let credits = try? JSONSerialization.jsonObject(with: creditsData) as? JSONObject {
            count = creditCount(credits) ?? count
            let dedicated = collectExpirations(credits)
            if !dedicated.isEmpty { expirations = dedicated }
        }
        return ProviderSnapshot(
            plan: pickString(usage, keys: ["plan_type", "planType"])?.uppercased(),
            shortWindow: short,
            weeklyWindow: weekly,
            resetCredits: count,
            resetCreditExpirations: Array(Set(expirations)).sorted(),
            updatedAt: now,
            status: .ok,
            failure: nil
        )
    }

    private static func windowCandidates(in value: JSONObject) -> [WindowCandidate] {
        var output: [WindowCandidate] = []
        for name in shortWindowNames + weeklyWindowNames {
            guard let candidate = dictionary(value[name]), let window = parseWindow(candidate) else { continue }
            output.append(WindowCandidate(identifiers: [name], window: window))
        }
        for key in windowArrayNames {
            guard let items = value[key] as? [Any] else { continue }
            for item in items {
                guard let candidate = dictionary(item), let window = parseWindow(candidate) else { continue }
                let label = pickString(candidate, keys: ["name", "type", "id", "window", "label"])
                output.append(WindowCandidate(identifiers: label.map { [$0] } ?? [], window: window))
            }
        }
        return output
    }

    private static func findWindow(
        in candidates: [WindowCandidate],
        names: [String],
        expectedSeconds: UInt64
    ) -> UsageWindow? {
        // Prefer a matching duration attached to the expected semantic name.
        if let candidate = candidates.first(where: {
            matchesIdentifier($0, names: names) && matchesDuration($0.window, expectedSeconds: expectedSeconds)
        }) {
            return candidate.window
        }

        // Duration is authoritative even when legacy primary/secondary names swap.
        if let candidate = candidates.first(where: {
            matchesDuration($0.window, expectedSeconds: expectedSeconds)
        }) {
            return candidate.window
        }

        // Legacy responses did not always include duration metadata.
        return candidates.first(where: {
            $0.window.windowSeconds == 0 && matchesIdentifier($0, names: names)
        })?.window
    }

    private static func matchesIdentifier(_ candidate: WindowCandidate, names: [String]) -> Bool {
        candidate.identifiers.contains { identifier in
            let lower = identifier.lowercased()
            return names.contains { lower == $0.lowercased() || lower.contains($0.lowercased()) }
        }
    }

    private static func isLoneAmbiguousPrimary(_ candidates: [WindowCandidate]) -> Bool {
        guard candidates.count == 1, let candidate = candidates.first,
              candidate.window.windowSeconds == 0 else { return false }
        return matchesIdentifier(candidate, names: primaryWindowNames)
    }

    private static func matchesDuration(_ window: UsageWindow, expectedSeconds: UInt64) -> Bool {
        expectedSeconds > 0
            && window.windowSeconds > 0
            && difference(window.windowSeconds, expectedSeconds) <= 60
    }

    private static func parseWindow(_ value: JSONObject?) -> UsageWindow? {
        guard let value else { return nil }
        let remainingKeys = [
            "remaining_percent", "remainingPercent", "remaining_pct", "remainingPct",
            "remaining_ratio", "remainingRatio", "remaining"
        ]
        let usedKeys = [
            "used_percent", "usedPercent", "used_pct", "usedPct", "used_ratio", "usedRatio",
            "utilization", "used"
        ]
        let remaining: Double
        if let (key, number) = number(value, keys: remainingKeys) {
            remaining = shouldScale(key, number) ? number * 100 : number
        } else if let (key, number) = number(value, keys: usedKeys) {
            let used = shouldScale(key, number) ? number * 100 : number
            remaining = 100 - used
        } else {
            return nil
        }
        return UsageWindow(
            remainingPercent: remaining,
            resetsAt: timestamp(value, keys: ["reset_at", "resetAt", "resets_at", "resetsAt", "reset_time", "resetTime"]),
            windowSeconds: integer(
                value,
                keys: [
                    "limit_window_seconds", "limitWindowSeconds", "window_seconds", "windowSeconds",
                    "duration_seconds", "durationSeconds", "period_seconds", "periodSeconds"
                ]
            ) ?? 0
        )
    }

    private static func shouldScale(_ key: String, _ value: Double) -> Bool {
        ["remaining_ratio", "remainingRatio", "used_ratio", "usedRatio", "utilization"].contains(key)
            || (!key.contains("percent") && !key.contains("pct") && value <= 1)
    }

    private static func collectExpirations(_ value: Any) -> [Date] {
        var output: [Date] = []
        func visit(_ value: Any) {
            if let array = value as? [Any] { array.forEach(visit); return }
            guard let object = dictionary(value) else { return }
            if let date = timestamp(
                object,
                keys: ["expires_at", "expiresAt", "expiration_time", "expirationTime", "expires"]
            ) { output.append(date) }
            for key in ["credits", "reset_credits", "resetCredits", "available", "items", "grants"] {
                if let child = object[key] { visit(child) }
            }
        }
        visit(value)
        return output
    }

    private static func creditCount(_ value: JSONObject) -> UInt64? {
        integer(value, keys: ["available_count", "availableCount", "remaining", "count", "quantity"])
    }

    private static func number(_ value: JSONObject, keys: [String]) -> (String, Double)? {
        for key in keys {
            guard let item = value[key] as? NSNumber, CFGetTypeID(item) != CFBooleanGetTypeID() else { continue }
            return (key, item.doubleValue)
        }
        return nil
    }

    private static func integer(_ value: JSONObject, keys: [String]) -> UInt64? {
        for key in keys {
            guard let item = value[key] as? NSNumber,
                  CFGetTypeID(item) != CFBooleanGetTypeID(), item.doubleValue >= 0 else { continue }
            return item.uint64Value
        }
        return nil
    }

    private static func timestamp(_ value: JSONObject, keys: [String]) -> Date? {
        for key in keys {
            guard let item = value[key] else { continue }
            if let text = item as? String,
               let date = ISO8601DateFormatter.fractional.date(from: text)
                    ?? ISO8601DateFormatter.standard.date(from: text) { return date }
            if let number = item as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
                return Date(timeIntervalSince1970: number.doubleValue)
            }
        }
        return nil
    }

    private static func pickString(_ value: JSONObject, keys: [String]) -> String? {
        keys.lazy.compactMap { value[$0] as? String }.first
    }
    private static func dictionary(_ value: Any?) -> JSONObject? { value as? JSONObject }
    private static func difference(_ lhs: UInt64, _ rhs: UInt64) -> UInt64 { lhs >= rhs ? lhs - rhs : rhs - lhs }
}

private extension ISO8601DateFormatter {
    static let standard: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()
    static let fractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()
}
