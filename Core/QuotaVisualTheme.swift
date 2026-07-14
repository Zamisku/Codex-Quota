import Foundation

enum QuotaVisualTheme: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case crystal
    case aquarium
    case orbit
    case aurora

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .crystal: return "晶透玻璃"
        case .aquarium: return "整卡水族箱"
        case .orbit: return "双轨星环"
        case .aurora: return "极光简约"
        }
    }

    var summary: String {
        switch self {
        case .crystal: return "透镜进度环与折射高光"
        case .aquarium: return "液位随剩余额度升降"
        case .orbit: return "双额度轨道同时呈现"
        case .aurora: return "安静明亮的渐变信息层"
        }
    }

    var symbolName: String {
        switch self {
        case .crystal: return "circle.hexagongrid.fill"
        case .aquarium: return "water.waves"
        case .orbit: return "circle.dotted.circle.fill"
        case .aurora: return "sparkles"
        }
    }
}

enum WidgetThemeChoice: String, CaseIterable, Codable, Hashable, Sendable {
    case followApp
    case crystal
    case aquarium
    case orbit
    case aurora

    func resolved(globalTheme: QuotaVisualTheme) -> QuotaVisualTheme {
        switch self {
        case .followApp: return globalTheme
        case .crystal: return .crystal
        case .aquarium: return .aquarium
        case .orbit: return .orbit
        case .aurora: return .aurora
        }
    }
}

enum QuotaThemePreferences {
    static let defaultsKey = "widget.theme.default.v1"
    static let fallbackTheme = QuotaVisualTheme.crystal

    static var globalTheme: QuotaVisualTheme {
        load(from: sharedDefaults)
    }

    static func load(from defaults: UserDefaults) -> QuotaVisualTheme {
        guard let rawValue = defaults.string(forKey: defaultsKey),
              let theme = QuotaVisualTheme(rawValue: rawValue) else {
            return fallbackTheme
        }
        return theme
    }

    static func save(_ theme: QuotaVisualTheme, to defaults: UserDefaults? = nil) {
        (defaults ?? sharedDefaults).set(theme.rawValue, forKey: defaultsKey)
    }

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: SharedSnapshotStore.appGroupIdentifier) ?? .standard
    }
}

enum CodexQuotaWidgetKind {
    static let legacy = "com.Zamisku.Codex-Quota.quota"
    static let configurable = "com.Zamisku.Codex-Quota.quota.configurable"
    static let all = [legacy, configurable]

    // Backward-compatible name for existing host code.
    static let value = legacy
}

enum QuotaWidgetThemeResolver {
    static func resolve(
        widgetKind: String,
        globalTheme: QuotaVisualTheme,
        choice: WidgetThemeChoice = .followApp
    ) -> QuotaVisualTheme {
        guard widgetKind == CodexQuotaWidgetKind.configurable else {
            return globalTheme
        }
        return choice.resolved(globalTheme: globalTheme)
    }
}
