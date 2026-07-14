import SwiftUI
import WidgetKit

struct QuotaEntry: TimelineEntry {
    let date: Date
    let snapshot: ProviderSnapshot
    let theme: QuotaVisualTheme

    var motionPhase: Bool {
        let milliseconds = Int64(snapshot.updatedAt.timeIntervalSinceReferenceDate * 1_000)
        return milliseconds.isMultiple(of: 2)
    }
}

private enum QuotaEntrySource {
    static var currentSnapshot: ProviderSnapshot {
        guard let snapshot = SharedSnapshotStore.load() else { return .failure(.noSnapshot) }
        return snapshot.markedStaleIfExpired(maximumAge: 45 * 60)
    }

    static func entry(
        context: TimelineProviderContext,
        theme: QuotaVisualTheme,
        date: Date = Date()
    ) -> QuotaEntry {
        QuotaEntry(
            date: date,
            snapshot: context.isPreview ? .themePreview : currentSnapshot,
            theme: theme
        )
    }
}

struct QuotaProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuotaEntry {
        QuotaEntry(date: Date(), snapshot: .themePreview, theme: resolvedTheme)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuotaEntry) -> Void) {
        completion(QuotaEntrySource.entry(context: context, theme: resolvedTheme))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuotaEntry>) -> Void) {
        let now = Date()
        let entry = QuotaEntrySource.entry(context: context, theme: resolvedTheme, date: now)
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(30 * 60))))
    }

    private var resolvedTheme: QuotaVisualTheme {
        QuotaWidgetThemeResolver.resolve(
            widgetKind: CodexQuotaWidgetKind.legacy,
            globalTheme: QuotaThemePreferences.globalTheme
        )
    }
}

struct ConfigurableQuotaProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> QuotaEntry {
        QuotaEntry(date: Date(), snapshot: .themePreview, theme: QuotaThemePreferences.globalTheme)
    }

    func snapshot(for configuration: QuotaWidgetConfigurationIntent, in context: Context) async -> QuotaEntry {
        QuotaEntrySource.entry(context: context, theme: resolvedTheme(configuration))
    }

    func timeline(for configuration: QuotaWidgetConfigurationIntent, in context: Context) async -> Timeline<QuotaEntry> {
        let now = Date()
        let entry = QuotaEntrySource.entry(context: context, theme: resolvedTheme(configuration), date: now)
        return Timeline(entries: [entry], policy: .after(now.addingTimeInterval(30 * 60)))
    }

    private func resolvedTheme(_ configuration: QuotaWidgetConfigurationIntent) -> QuotaVisualTheme {
        QuotaWidgetThemeResolver.resolve(
            widgetKind: CodexQuotaWidgetKind.configurable,
            globalTheme: QuotaThemePreferences.globalTheme,
            choice: configuration.theme
        )
    }
}

struct QuotaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuotaEntry

    var body: some View {
        QuotaThemeRenderer(
            snapshot: entry.snapshot,
            family: family,
            theme: entry.theme,
            motionPhase: entry.motionPhase
        )
    }
}

struct CodexQuotaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: CodexQuotaWidgetKind.legacy, provider: QuotaProvider()) { entry in
            widgetContent(entry)
        }
        .configurationDisplayName("Codex Quota")
        .description("显示额度并跟随 Codex Quota 应用中的全局主题。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable(true)
    }

    private func widgetContent(_ entry: QuotaEntry) -> some View {
        QuotaWidgetView(entry: entry)
            .containerBackground(for: .widget) {
                QuotaThemeBackground(
                    snapshot: entry.snapshot,
                    theme: entry.theme,
                    motionPhase: entry.motionPhase
                )
            }
            .widgetURL(URL(string: "codexquota://refresh"))
    }
}

struct ConfigurableCodexQuotaWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: CodexQuotaWidgetKind.configurable,
            intent: QuotaWidgetConfigurationIntent.self,
            provider: ConfigurableQuotaProvider()
        ) { entry in
            widgetContent(entry)
        }
        .configurationDisplayName("Codex Quota · 自定义")
        .description("为这一枚小组件单独选择主题，或跟随应用中的全局主题。")
        .supportedFamilies([.systemSmall, .systemMedium])
        .containerBackgroundRemovable(true)
    }

    private func widgetContent(_ entry: QuotaEntry) -> some View {
        QuotaWidgetView(entry: entry)
            .containerBackground(for: .widget) {
                QuotaThemeBackground(
                    snapshot: entry.snapshot,
                    theme: entry.theme,
                    motionPhase: entry.motionPhase
                )
            }
            .widgetURL(URL(string: "codexquota://refresh"))
    }
}

@main
struct CodexQuotaWidgetBundle: WidgetBundle {
    var body: some Widget {
        CodexQuotaWidget()
        ConfigurableCodexQuotaWidget()
    }
}

private enum QuotaPreviewFixtures {
    static let weekly84 = snapshot(short: nil, weekly: 84)
    static let warning34 = snapshot(short: 34, weekly: 84)
    static let critical15 = snapshot(short: 15, weekly: 34)
    static let empty = snapshot(short: 0, weekly: 15)
    static let stale = snapshot(short: nil, weekly: 34)
        .markedStale(with: .networkUnavailable)
    static let signedOut = ProviderSnapshot.failure(.loginNotFound)
    static let noSnapshot = ProviderSnapshot.failure(.noSnapshot)

    private static func snapshot(short: Double?, weekly: Double?) -> ProviderSnapshot {
        let now = Date()
        return ProviderSnapshot(
            plan: "PLUS",
            shortWindow: short.map {
                UsageWindow(
                    remainingPercent: $0,
                    resetsAt: now.addingTimeInterval(2.5 * 60 * 60),
                    windowSeconds: 18_000
                )
            },
            weeklyWindow: weekly.map {
                UsageWindow(
                    remainingPercent: $0,
                    resetsAt: now.addingTimeInterval(4 * 86_400),
                    windowSeconds: 604_800
                )
            },
            resetCredits: 2,
            resetCreditExpirations: [],
            updatedAt: now,
            status: .ok,
            failure: nil
        )
    }
}

#Preview("晶透 · Small", as: .systemSmall, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: .themePreview, theme: .crystal)
})

#Preview("水族箱 · Small", as: .systemSmall, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: .themePreview, theme: .aquarium)
})

#Preview("星环 · Small", as: .systemSmall, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: .themePreview, theme: .orbit)
})

#Preview("极光 · Small", as: .systemSmall, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: .themePreview, theme: .aurora)
})

#Preview("晶透 · Medium", as: .systemMedium, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: .themePreview, theme: .crystal)
})

#Preview("水族箱 · Medium", as: .systemMedium, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: .themePreview, theme: .aquarium)
})

#Preview("星环 · Medium", as: .systemMedium, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: .themePreview, theme: .orbit)
})

#Preview("极光 · Medium", as: .systemMedium, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: .themePreview, theme: .aurora)
})

#Preview("Weekly-only 84% · Small", as: .systemSmall, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: QuotaPreviewFixtures.weekly84, theme: .crystal)
})

#Preview("Weekly-only 84% · Medium", as: .systemMedium, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: QuotaPreviewFixtures.weekly84, theme: .crystal)
})

#Preview("水族箱 · 34%", as: .systemSmall, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: QuotaPreviewFixtures.warning34, theme: .aquarium)
})

#Preview("水族箱 · 15%", as: .systemSmall, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: QuotaPreviewFixtures.critical15, theme: .aquarium)
})

#Preview("水族箱 · 0%", as: .systemSmall, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: QuotaPreviewFixtures.empty, theme: .aquarium)
})

#Preview("极光 · Stale", as: .systemMedium, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: QuotaPreviewFixtures.stale, theme: .aurora)
})

#Preview("晶透 · 无快照", as: .systemSmall, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: QuotaPreviewFixtures.noSnapshot, theme: .crystal)
})

#Preview("水族箱 · 未登录", as: .systemSmall, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: QuotaPreviewFixtures.signedOut, theme: .aquarium)
})

#Preview("星环 · 无快照", as: .systemSmall, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: QuotaPreviewFixtures.noSnapshot, theme: .orbit)
})

#Preview("极光 · 未登录", as: .systemSmall, widget: {
    CodexQuotaWidget()
}, timeline: {
    QuotaEntry(date: Date(), snapshot: QuotaPreviewFixtures.signedOut, theme: .aurora)
})
