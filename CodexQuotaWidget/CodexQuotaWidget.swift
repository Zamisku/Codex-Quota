import SwiftUI
import WidgetKit

private enum WidgetConstants {
    static let kind = "com.Zamisku.Codex-Quota.quota"
}

private enum WidgetPalette {
    static let primaryText = Color(red: 0.08, green: 0.11, blue: 0.16)
    static let secondaryText = Color(red: 0.20, green: 0.25, blue: 0.28)
}

struct QuotaEntry: TimelineEntry {
    let date: Date
    let snapshot: ProviderSnapshot
}

struct QuotaProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuotaEntry {
        QuotaEntry(date: Date(), snapshot: .preview)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuotaEntry) -> Void) {
        if context.isPreview {
            completion(QuotaEntry(date: Date(), snapshot: .preview))
        } else {
            completion(QuotaEntry(date: Date(), snapshot: currentSnapshot))
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<QuotaEntry>) -> Void) {
        let now = Date()
        let entry = QuotaEntry(date: now, snapshot: currentSnapshot)
        completion(Timeline(entries: [entry], policy: .after(now.addingTimeInterval(30 * 60))))
    }

    private var currentSnapshot: ProviderSnapshot {
        guard let snapshot = SharedSnapshotStore.load() else { return .failure(.noSnapshot) }
        return snapshot.markedStaleIfExpired(maximumAge: 45 * 60)
    }
}

@main
struct CodexQuotaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetConstants.kind, provider: QuotaProvider()) { entry in
            QuotaWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    QuotaWidgetBackground(snapshot: entry.snapshot)
                }
                .widgetURL(URL(string: "codexquota://refresh"))
        }
        .configurationDisplayName("Codex Quota")
        .description("在桌面查看 Codex 5 小时与每周额度。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct QuotaWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: QuotaEntry

    var body: some View {
        Group {
            if let short = entry.snapshot.shortWindow {
                if family == .systemMedium { mediumContent(short: short) }
                else { smallContent(short: short) }
            } else {
                failureContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(WidgetPalette.primaryText)
    }

    private func smallContent(short: UsageWindow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(showsPlan: false)
            Spacer(minLength: 8)
            Text("5H REMAINING")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(WidgetPalette.secondaryText)
            HStack(alignment: .lastTextBaseline, spacing: 2) {
                Text("\(Int(short.remainingPercent.rounded()))")
                    .font(.system(size: 45, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
            }
            .privacySensitive()
            QuotaBar(value: short.remainingPercent)
                .padding(.top, 7)
            Spacer(minLength: 9)
            HStack {
                Label("周 \(weeklyPercent)", systemImage: "calendar")
                Spacer()
                Text(entry.snapshot.updatedAt, style: .time)
            }
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(WidgetPalette.secondaryText)
        }
    }

    private func mediumContent(short: UsageWindow) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(showsPlan: true)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(2)
            Spacer(minLength: 4)
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("5 小时剩余")
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(WidgetPalette.secondaryText)
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(Int(short.remainingPercent.rounded()))")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                        Text("%").font(.system(size: 11, weight: .bold, design: .rounded))
                    }
                    .privacySensitive()
                    QuotaBar(value: short.remainingPercent)
                    resetLabel(short.resetsAt)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 6) {
                    metric(title: "本周剩余", value: weeklyPercent, icon: "calendar")
                    metric(
                        title: "重置额度",
                        value: entry.snapshot.resetCredits.map(String.init) ?? "—",
                        icon: "arrow.counterclockwise.circle"
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 4)
            HStack(spacing: 4) {
                Label(entry.snapshot.status == .stale ? "上次更新" : "更新于",
                      systemImage: entry.snapshot.status == .stale ? "clock.arrow.circlepath" : "checkmark.circle.fill")
                Text(entry.snapshot.updatedAt, style: .time)
                Spacer()
                Link(destination: URL(string: "codexquota://refresh")!) {
                    Image(systemName: "arrow.clockwise")
                        .frame(width: 18, height: 18)
                        .background(.white.opacity(0.36), in: Circle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(WidgetPalette.primaryText)
                .accessibilityLabel("打开 Codex Quota 并刷新")
            }
            .font(.system(size: 8, weight: .semibold, design: .rounded))
            .foregroundStyle(WidgetPalette.secondaryText)
            .lineLimit(1)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func header(showsPlan: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: 13, weight: .semibold))
            Text("CODEX")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.5)
                .lineLimit(1)
                .layoutPriority(2)
            if showsPlan, let plan = entry.snapshot.plan {
                Text(plan)
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.38), in: Capsule())
            }
            Spacer()
            Circle()
                .fill(entry.snapshot.status == .ok ? Color.green : Color.orange)
                .frame(width: 7, height: 7)
        }
    }

    private func metric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .semibold))
                .frame(width: 20, height: 20)
                .background(.white.opacity(0.32), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .foregroundStyle(WidgetPalette.secondaryText)
                Text(value)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private func resetLabel(_ date: Date?) -> some View {
        if let date {
            HStack(spacing: 3) {
                Text("重置")
                Text(date, style: .relative)
            }
            .font(.system(size: 8, weight: .medium, design: .rounded))
            .foregroundStyle(WidgetPalette.secondaryText)
        } else {
            Text("重置时间未知")
                .font(.system(size: 8, design: .rounded))
                .foregroundStyle(WidgetPalette.secondaryText)
        }
    }

    private var weeklyPercent: String {
        entry.snapshot.weeklyWindow.map { "\(Int($0.remainingPercent.rounded()))%" } ?? "—"
    }

    private var failureContent: some View {
        VStack(spacing: 11) {
            Spacer()
            Image(systemName: entry.snapshot.status == .signedOut
                  ? "person.crop.circle.badge.exclamationmark"
                  : "arrow.triangle.2.circlepath.icloud")
                .font(.system(size: 29, weight: .medium))
            Text(entry.snapshot.status == .signedOut ? "请登录 Codex" : "等待首次同步")
                .font(.system(size: 15, weight: .bold, design: .rounded))
            Text(failureMessage)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(WidgetPalette.secondaryText)
                .multilineTextAlignment(.center)
            Link(destination: URL(string: "codexquota://refresh")!) {
                Label("打开并同步", systemImage: "arrow.clockwise")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.38), in: Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var failureMessage: String {
        switch entry.snapshot.failure {
        case .noSnapshot: return "先启动 Codex Quota 宿主应用"
        case .loginNotFound: return "打开 Codex Desktop 登录后重试"
        case .loginExpired: return "登录已过期，请重新登录"
        case .invalidLogin: return "登录数据格式已变化"
        case .rateLimited: return "请求过于频繁，稍后自动重试"
        case .networkUnavailable: return "请检查网络连接"
        default: return "稍后会自动重试"
        }
    }
}

private struct QuotaBar: View {
    let value: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.35))
                Capsule().fill(barColor).frame(width: max(5, geometry.size.width * value / 100))
            }
        }
        .frame(height: 5)
        .accessibilityValue("\(Int(value.rounded())) percent")
    }

    private var barColor: Color {
        if value <= 15 { return .red }
        if value <= 35 { return .orange }
        return Color(red: 0.18, green: 0.44, blue: 0.87)
    }
}

private struct QuotaWidgetBackground: View {
    let snapshot: ProviderSnapshot

    var body: some View {
        ContainerRelativeShape()
            .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
    }

    private var colors: [Color] {
        guard snapshot.status == .ok || snapshot.status == .stale,
              let value = snapshot.shortWindow?.remainingPercent else {
            return [Color(red: 0.70, green: 0.78, blue: 0.90), Color(red: 0.95, green: 0.72, blue: 0.67)]
        }
        if value <= 15 {
            return [Color(red: 0.82, green: 0.85, blue: 0.92), Color(red: 0.98, green: 0.55, blue: 0.43)]
        }
        if value <= 35 {
            return [Color(red: 0.72, green: 0.84, blue: 0.95), Color(red: 0.98, green: 0.82, blue: 0.51)]
        }
        return [Color(red: 0.71, green: 0.84, blue: 0.96), Color(red: 0.70, green: 0.93, blue: 0.79)]
    }
}
