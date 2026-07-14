import SwiftUI
import WidgetKit

private enum QuotaThemePalette {
    static let ink = Color(red: 0.06, green: 0.10, blue: 0.17)
    static let secondaryInk = Color(red: 0.22, green: 0.29, blue: 0.34)
    static let orbitInk = Color.white
    static let orbitSecondary = Color.white.opacity(0.70)

    static func levelColor(_ value: Double) -> Color {
        if value <= 15 { return Color(red: 0.95, green: 0.29, blue: 0.21) }
        if value <= 35 { return Color(red: 0.96, green: 0.61, blue: 0.18) }
        return Color(red: 0.12, green: 0.47, blue: 0.96)
    }

    static func waterColors(_ value: Double) -> [Color] {
        if value <= 15 {
            return [
                Color(red: 1.00, green: 0.54, blue: 0.42),
                Color(red: 0.92, green: 0.23, blue: 0.24)
            ]
        }
        if value <= 35 {
            return [
                Color(red: 1.00, green: 0.79, blue: 0.34),
                Color(red: 0.96, green: 0.48, blue: 0.16)
            ]
        }
        return [
            Color(red: 0.25, green: 0.78, blue: 0.98),
            Color(red: 0.10, green: 0.53, blue: 0.94)
        ]
    }
}

struct QuotaThemeBackground: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    let snapshot: ProviderSnapshot
    let theme: QuotaVisualTheme
    var motionPhase = false

    var body: some View {
        Group {
            if renderingMode == .fullColor {
                fullColorBackground
            } else {
                accentedBackground
            }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var fullColorBackground: some View {
        switch theme {
        case .crystal:
            crystalBackground
        case .aquarium:
            aquariumBackground
        case .orbit:
            orbitBackground
        case .aurora:
            auroraBackground
        }
    }

    private var accentedBackground: some View {
        ZStack {
            Color.accentColor.opacity(reduceTransparency ? 0.24 : 0.12)
            LinearGradient(
                colors: [.white.opacity(0.14), .clear, .black.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if theme == .aquarium, let value = snapshot.primaryWindow?.remainingPercent {
                GeometryReader { proxy in
                    WaveShape(
                        level: normalized(value),
                        phase: wavePhase,
                        amplitude: reduceMotion ? 0 : 3
                    )
                    .fill(Color.accentColor.opacity(0.24))
                    .animation(levelAnimation, value: normalized(value))
                    .animation(phaseAnimation, value: motionPhase)
                    .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
        }
    }

    private var crystalBackground: some View {
        ZStack {
            Color(red: 0.82, green: 0.92, blue: 0.98)
            LinearGradient(
                colors: [
                    Color(red: 0.75, green: 0.89, blue: 1.00),
                    Color(red: 0.91, green: 0.96, blue: 1.00),
                    Color(red: 0.73, green: 0.96, blue: 0.89)
                ],
                startPoint: motionPhase ? .topTrailing : .topLeading,
                endPoint: motionPhase ? .bottomLeading : .bottomTrailing
            )
            Circle()
                .fill(Color.white.opacity(reduceTransparency ? 0.18 : 0.48))
                .frame(width: 170, height: 170)
                .blur(radius: reduceTransparency ? 8 : 28)
                .offset(x: motionPhase ? 92 : 58, y: motionPhase ? -54 : -78)
            Circle()
                .fill(Color.cyan.opacity(reduceTransparency ? 0.10 : 0.20))
                .frame(width: 130, height: 130)
                .blur(radius: reduceTransparency ? 8 : 24)
                .offset(x: motionPhase ? -70 : -102, y: motionPhase ? 70 : 48)
        }
        .animation(ambientAnimation, value: motionPhase)
    }

    private var aquariumBackground: some View {
        GeometryReader { proxy in
            let value = snapshot.primaryWindow?.remainingPercent ?? 0
            ZStack {
                LinearGradient(
                    colors: colorScheme == .dark
                        ? [Color(red: 0.73, green: 0.84, blue: 0.88), Color(red: 0.88, green: 0.93, blue: 0.92)]
                        : [Color(red: 0.91, green: 0.97, blue: 0.98), Color(red: 0.77, green: 0.91, blue: 0.94)],
                    startPoint: .top,
                    endPoint: .bottom
                )

                WaveShape(
                    level: normalized(value),
                    phase: wavePhase,
                    amplitude: reduceMotion ? 0 : 4
                )
                .fill(
                    LinearGradient(
                        colors: QuotaThemePalette.waterColors(value).map { $0.opacity(reduceTransparency ? 0.88 : 0.72) },
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .animation(levelAnimation, value: normalized(value))
                .animation(phaseAnimation, value: motionPhase)

                WaveShape(
                    level: min(1, normalized(value) + 0.018),
                    phase: wavePhase + .pi,
                    amplitude: reduceMotion ? 0 : 2.4
                )
                .fill(Color.white.opacity(reduceTransparency ? 0.12 : 0.22))
                .animation(levelAnimation, value: normalized(value))
                .animation(phaseAnimation, value: motionPhase)

                if value > 8, !reduceMotion {
                    AquariumBubbles(level: normalized(value), motionPhase: motionPhase)
                        .transition(.opacity)
                }

                LinearGradient(
                    colors: [.white.opacity(0.32), .clear, .black.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }

    private var orbitBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.08, blue: 0.19),
                    Color(red: 0.10, green: 0.16, blue: 0.34),
                    Color(red: 0.05, green: 0.27, blue: 0.34)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Circle()
                .fill(Color.cyan.opacity(reduceTransparency ? 0.10 : 0.24))
                .frame(width: 180, height: 180)
                .blur(radius: reduceTransparency ? 10 : 36)
                .offset(x: motionPhase ? 92 : 58, y: -68)
            Circle()
                .fill(Color.indigo.opacity(reduceTransparency ? 0.10 : 0.25))
                .frame(width: 150, height: 150)
                .blur(radius: reduceTransparency ? 10 : 34)
                .offset(x: motionPhase ? -94 : -66, y: 72)
        }
        .animation(ambientAnimation, value: motionPhase)
    }

    private var auroraBackground: some View {
        ZStack {
            LinearGradient(
                colors: auroraColors,
                startPoint: motionPhase ? .top : .topLeading,
                endPoint: motionPhase ? .bottomTrailing : .bottom
            )
            Circle()
                .fill(Color.white.opacity(reduceTransparency ? 0.16 : 0.40))
                .frame(width: 190, height: 190)
                .blur(radius: reduceTransparency ? 10 : 34)
                .offset(x: motionPhase ? 104 : 68, y: motionPhase ? -68 : -88)
            Circle()
                .fill(Color.green.opacity(reduceTransparency ? 0.08 : 0.17))
                .frame(width: 150, height: 150)
                .blur(radius: reduceTransparency ? 10 : 30)
                .offset(x: motionPhase ? -74 : -102, y: motionPhase ? 58 : 82)
        }
        .animation(ambientAnimation, value: motionPhase)
    }

    private var auroraColors: [Color] {
        guard snapshot.status == .ok || snapshot.status == .stale,
              let value = snapshot.primaryWindow?.remainingPercent else {
            return [Color(red: 0.72, green: 0.77, blue: 0.84), Color(red: 0.84, green: 0.86, blue: 0.88)]
        }
        if value <= 15 {
            return [Color(red: 0.79, green: 0.85, blue: 0.94), Color(red: 0.99, green: 0.58, blue: 0.47)]
        }
        if value <= 35 {
            return [Color(red: 0.73, green: 0.86, blue: 0.97), Color(red: 0.99, green: 0.83, blue: 0.52)]
        }
        return [Color(red: 0.70, green: 0.85, blue: 0.98), Color(red: 0.69, green: 0.94, blue: 0.80)]
    }

    private var wavePhase: CGFloat {
        let base = snapshot.updatedAt.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: Double.pi * 2)
        return CGFloat(base) + (motionPhase ? .pi * 1.35 : 0)
    }

    private var levelAnimation: Animation? {
        reduceMotion ? nil : .spring(duration: 1.75, bounce: 0.24)
    }

    private var phaseAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 1.6)
    }

    private var ambientAnimation: Animation? {
        reduceMotion ? nil : .easeInOut(duration: 1.65)
    }

    private func normalized(_ value: Double) -> CGFloat {
        CGFloat(min(100, max(0, value)) / 100)
    }
}

struct QuotaThemeRenderer: View {
    @Environment(\.widgetRenderingMode) private var renderingMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    let snapshot: ProviderSnapshot
    let family: WidgetFamily
    let theme: QuotaVisualTheme
    var motionPhase = false

    var body: some View {
        Group {
            if let primary = snapshot.primaryWindow {
                if family == .systemMedium {
                    mediumContent(primary: primary)
                } else {
                    smallContent(primary: primary)
                }
            } else {
                failureContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(primaryColor)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func smallContent(primary: UsageWindow) -> some View {
        switch theme {
        case .crystal:
            VStack(spacing: 0) {
                QuotaHeader(snapshot: snapshot, color: primaryColor, secondaryColor: secondaryColor, compact: true)
                Spacer(minLength: 3)
                LensGauge(value: primary.remainingPercent, size: 80, foreground: primaryColor)
                Spacer(minLength: 3)
                SmallFooter(snapshot: snapshot, primary: primary, color: secondaryColor)
            }
        case .aquarium:
            VStack(alignment: .leading, spacing: 0) {
                QuotaHeader(snapshot: snapshot, color: primaryColor, secondaryColor: secondaryColor, compact: true)
                Spacer(minLength: 5)
                Text(primaryLabel.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.9)
                    .foregroundStyle(secondaryColor)
                PercentText(value: primary.remainingPercent, numberSize: 41, color: primaryColor)
                Spacer(minLength: 4)
                SmallFooter(snapshot: snapshot, primary: primary, color: secondaryColor)
            }
        case .orbit:
            VStack(spacing: 0) {
                QuotaHeader(snapshot: snapshot, color: primaryColor, secondaryColor: secondaryColor, compact: true)
                Spacer(minLength: 3)
                OrbitGauge(
                    primary: primary,
                    secondary: secondaryWindow,
                    size: 82,
                    foreground: primaryColor,
                    accent: accentColor
                )
                Spacer(minLength: 3)
                SmallFooter(snapshot: snapshot, primary: primary, color: secondaryColor)
            }
        case .aurora:
            VStack(alignment: .leading, spacing: 0) {
                QuotaHeader(snapshot: snapshot, color: primaryColor, secondaryColor: secondaryColor, compact: true)
                Spacer(minLength: 6)
                Text(primaryLabel.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(secondaryColor)
                PercentText(value: primary.remainingPercent, numberSize: 41, color: primaryColor)
                QuotaProgressBar(value: primary.remainingPercent, accent: accentColor)
                    .padding(.top, 4)
                Spacer(minLength: 5)
                SmallFooter(snapshot: snapshot, primary: primary, color: secondaryColor)
            }
        }
    }

    @ViewBuilder
    private func mediumContent(primary: UsageWindow) -> some View {
        switch theme {
        case .crystal:
            VStack(alignment: .leading, spacing: 0) {
                QuotaHeader(snapshot: snapshot, color: primaryColor, secondaryColor: secondaryColor, compact: false)
                Spacer(minLength: 3)
                HStack(spacing: 10) {
                    LensGauge(value: primary.remainingPercent, size: 92, foreground: primaryColor)
                    VStack(alignment: .leading, spacing: 5) {
                        Text(primaryLabel)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryColor)
                        ResetLabel(date: primary.resetsAt, color: secondaryColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    MediumMetrics(snapshot: snapshot, primary: primary, color: primaryColor, secondaryColor: secondaryColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 2)
                MediumFooter(snapshot: snapshot, color: primaryColor, secondaryColor: secondaryColor, reduceTransparency: reduceTransparency)
            }
        case .aquarium:
            VStack(alignment: .leading, spacing: 0) {
                QuotaHeader(snapshot: snapshot, color: primaryColor, secondaryColor: secondaryColor, compact: false)
                Spacer(minLength: 5)
                HStack(alignment: .center, spacing: 18) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(primaryLabel)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryColor)
                        PercentText(value: primary.remainingPercent, numberSize: 37, color: primaryColor)
                        ResetLabel(date: primary.resetsAt, color: secondaryColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    MediumMetrics(snapshot: snapshot, primary: primary, color: primaryColor, secondaryColor: secondaryColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 4)
                MediumFooter(snapshot: snapshot, color: primaryColor, secondaryColor: secondaryColor, reduceTransparency: reduceTransparency)
            }
        case .orbit:
            VStack(alignment: .leading, spacing: 0) {
                QuotaHeader(snapshot: snapshot, color: primaryColor, secondaryColor: secondaryColor, compact: false)
                Spacer(minLength: 2)
                HStack(spacing: 16) {
                    OrbitGauge(
                        primary: primary,
                        secondary: secondaryWindow,
                        size: 96,
                        foreground: primaryColor,
                        accent: accentColor
                    )
                    VStack(alignment: .leading, spacing: 5) {
                        Text(primaryLabel)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryColor)
                        ResetLabel(date: primary.resetsAt, color: secondaryColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    MediumMetrics(snapshot: snapshot, primary: primary, color: primaryColor, secondaryColor: secondaryColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 2)
                MediumFooter(snapshot: snapshot, color: primaryColor, secondaryColor: secondaryColor, reduceTransparency: reduceTransparency)
            }
        case .aurora:
            VStack(alignment: .leading, spacing: 0) {
                QuotaHeader(snapshot: snapshot, color: primaryColor, secondaryColor: secondaryColor, compact: false)
                Spacer(minLength: 4)
                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(primaryLabel)
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryColor)
                        PercentText(value: primary.remainingPercent, numberSize: 36, color: primaryColor)
                        QuotaProgressBar(value: primary.remainingPercent, accent: accentColor)
                        ResetLabel(date: primary.resetsAt, color: secondaryColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    MediumMetrics(snapshot: snapshot, primary: primary, color: primaryColor, secondaryColor: secondaryColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Spacer(minLength: 4)
                MediumFooter(snapshot: snapshot, color: primaryColor, secondaryColor: secondaryColor, reduceTransparency: reduceTransparency)
            }
        }
    }

    private var failureContent: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 2)
            FailureMotif(theme: theme, color: primaryColor)
            Text(snapshot.status == .signedOut ? "请登录 Codex" : "等待首次同步")
                .font(.system(size: 14, weight: .bold, design: .rounded))
            Text(failureMessage)
                .font(.system(size: 9, design: .rounded))
                .foregroundStyle(secondaryColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Link(destination: URL(string: "codexquota://refresh")!) {
                Label("打开并同步", systemImage: "arrow.clockwise")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .quotaGlassControl(in: Capsule(), opaque: reduceTransparency)
            }
            .buttonStyle(.plain)
            .foregroundStyle(primaryColor)
            Spacer(minLength: 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }

    private var primaryLabel: String {
        snapshot.primaryWindowKind == .short ? "5 小时剩余" : "本周剩余"
    }

    private var secondaryWindow: UsageWindow? {
        snapshot.primaryWindowKind == .short ? snapshot.weeklyWindow : nil
    }

    private var primaryColor: Color {
        guard renderingMode == .fullColor else { return .primary }
        return theme == .orbit ? QuotaThemePalette.orbitInk : QuotaThemePalette.ink
    }

    private var secondaryColor: Color {
        guard renderingMode == .fullColor else { return .secondary }
        return theme == .orbit ? QuotaThemePalette.orbitSecondary : QuotaThemePalette.secondaryInk
    }

    private var accentColor: Color {
        guard renderingMode == .fullColor else { return .accentColor }
        if theme == .orbit { return Color(red: 0.28, green: 0.86, blue: 1.00) }
        return QuotaThemePalette.levelColor(snapshot.primaryWindow?.remainingPercent ?? 0)
    }

    private var failureMessage: String {
        switch snapshot.failure {
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

struct QuotaWidgetThemePreview: View {
    let snapshot: ProviderSnapshot
    let family: WidgetFamily
    let theme: QuotaVisualTheme
    var motionPhase = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: family == .systemSmall ? 28 : 25, style: .continuous)
        ZStack {
            QuotaThemeBackground(snapshot: snapshot, theme: theme, motionPhase: motionPhase)
            QuotaThemeRenderer(snapshot: snapshot, family: family, theme: theme, motionPhase: motionPhase)
                .padding(family == .systemSmall ? 15 : 16)
        }
        .clipShape(shape)
        .overlay(shape.stroke(.white.opacity(0.54), lineWidth: 1))
        .shadow(color: .black.opacity(0.13), radius: 12, y: 6)
        .aspectRatio(family == .systemSmall ? 1 : 2, contentMode: .fit)
    }
}

private struct QuotaHeader: View {
    let snapshot: ProviderSnapshot
    let color: Color
    let secondaryColor: Color
    let compact: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "gauge.with.dots.needle.33percent")
                .font(.system(size: compact ? 11 : 12, weight: .semibold))
                .accessibilityHidden(true)
            Text("CODEX")
                .font(.system(size: compact ? 10 : 11, weight: .bold, design: .rounded))
                .tracking(1.3)
                .lineLimit(1)
            if !compact, let plan = snapshot.plan {
                Text(plan)
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.white.opacity(0.28), in: Capsule())
            }
            Spacer(minLength: 2)
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .shadow(color: statusColor.opacity(0.55), radius: 3)
                .accessibilityLabel("同步状态")
                .accessibilityValue(statusDescription)
        }
        .foregroundStyle(color)
    }

    private var statusColor: Color {
        switch snapshot.status {
        case .ok: return .green
        case .stale: return .orange
        case .signedOut: return .orange
        case .unavailable: return .red
        }
    }

    private var statusDescription: String {
        switch snapshot.status {
        case .ok: return "已同步"
        case .stale: return "显示上次同步的数据"
        case .signedOut: return "未登录"
        case .unavailable: return "暂不可用"
        }
    }
}

private struct PercentText: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let value: Double
    let numberSize: CGFloat
    let color: Color

    var body: some View {
        let rounded = Int(value.rounded())
        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text("\(rounded)")
                .font(.system(size: numberSize, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .minimumScaleFactor(0.72)
                .contentTransition(.numericText())
            Text("%")
                .font(.system(size: max(10, numberSize * 0.31), weight: .bold, design: .rounded))
        }
        .foregroundStyle(color)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.45), value: rounded)
        .privacySensitive()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("剩余额度")
        .accessibilityValue("百分之 \(rounded)")
    }
}

private struct LensGauge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let value: Double
    let size: CGFloat
    let foreground: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.20))
                .overlay(Circle().stroke(.white.opacity(0.52), lineWidth: 1))
                .shadow(color: .white.opacity(0.48), radius: 7, x: -3, y: -3)
                .shadow(color: .blue.opacity(0.15), radius: 8, x: 4, y: 5)
            Circle()
                .stroke(.white.opacity(0.28), lineWidth: 6)
                .padding(6)
            Circle()
                .trim(from: 0, to: min(1, max(0, value / 100)))
                .stroke(
                    AngularGradient(
                        colors: [Color.cyan, Color.blue, Color.mint, Color.cyan],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .padding(6)
                .animation(reduceMotion ? nil : .spring(duration: 1.2, bounce: 0.20), value: value)
            Circle()
                .trim(from: 0.03, to: 0.18)
                .stroke(.white.opacity(0.72), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .rotationEffect(.degrees(-38))
                .padding(3)
            PercentText(value: value, numberSize: size * 0.34, color: foreground)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .contain)
    }
}

private struct OrbitGauge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let primary: UsageWindow
    let secondary: UsageWindow?
    let size: CGFloat
    let foreground: Color
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.12), lineWidth: 7)
                .padding(9)
            Circle()
                .trim(from: 0, to: normalized(primary.remainingPercent))
                .stroke(accent, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(9)
                .shadow(color: accent.opacity(0.48), radius: 5)
                .animation(reduceMotion ? nil : .spring(duration: 1.2, bounce: 0.22), value: primary.remainingPercent)
            if let secondary {
                Circle()
                    .stroke(.white.opacity(0.08), lineWidth: 2.5)
                    .padding(2)
                Circle()
                    .trim(from: 0, to: normalized(secondary.remainingPercent))
                    .stroke(Color.mint.opacity(0.88), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(2)
                    .animation(reduceMotion ? nil : .easeInOut(duration: 1.35), value: secondary.remainingPercent)
            }
            PercentText(value: primary.remainingPercent, numberSize: size * 0.31, color: foreground)
        }
        .frame(width: size, height: size)
    }

    private func normalized(_ value: Double) -> CGFloat {
        CGFloat(min(100, max(0, value)) / 100)
    }
}

private struct QuotaProgressBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let value: Double
    let accent: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.34))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.74), accent],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(4, geometry.size.width * min(100, max(0, value)) / 100))
                    .animation(reduceMotion ? nil : .spring(duration: 1.25, bounce: 0.18), value: value)
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

private struct SmallFooter: View {
    let snapshot: ProviderSnapshot
    let primary: UsageWindow
    let color: Color

    var body: some View {
        HStack(spacing: 3) {
            footerLabel
            Spacer(minLength: 3)
            Text(snapshot.updatedAt, style: .time)
        }
        .font(.system(size: 8, weight: .semibold, design: .rounded))
        .foregroundStyle(color)
        .lineLimit(1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("额度周期与更新时间")
        .accessibilityValue(accessibilityValue)
    }

    @ViewBuilder
    private var footerLabel: some View {
        if snapshot.primaryWindowKind == .short, let weekly = snapshot.weeklyWindow {
            Label("周 \(Int(weekly.remainingPercent.rounded()))%", systemImage: "calendar")
        } else if let reset = primary.resetsAt {
            Label {
                Text(reset, style: .relative)
            } icon: {
                Image(systemName: "calendar")
            }
        } else {
            Label(snapshot.primaryWindowKind == .short ? "5 小时" : "每周", systemImage: "calendar")
        }
    }

    private var accessibilityValue: String {
        let period = snapshot.primaryWindowKind == .short ? "5 小时" : "每周"
        if snapshot.primaryWindowKind == .short, let weekly = snapshot.weeklyWindow {
            return "\(period)，本周剩余百分之 \(Int(weekly.remainingPercent.rounded()))，更新于 \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))"
        }
        return "\(period)，更新于 \(snapshot.updatedAt.formatted(date: .omitted, time: .shortened))"
    }
}

private struct MediumMetrics: View {
    let snapshot: ProviderSnapshot
    let primary: UsageWindow
    let color: Color
    let secondaryColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            if snapshot.primaryWindowKind == .short, let weekly = snapshot.weeklyWindow {
                metric(title: "本周剩余", value: "\(Int(weekly.remainingPercent.rounded()))%", icon: "calendar")
            } else {
                metric(title: "额度周期", value: snapshot.primaryWindowKind == .short ? "5 小时" : "每周", icon: "calendar")
            }
            metric(
                title: "重置额度",
                value: snapshot.resetCredits.map(String.init) ?? "—",
                icon: "arrow.counterclockwise.circle"
            )
        }
    }

    private func metric(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .frame(width: 19, height: 19)
                .background(.white.opacity(0.20), in: RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.system(size: 7, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryColor)
                Text(value)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(color)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ResetLabel: View {
    let date: Date?
    let color: Color

    var body: some View {
        Group {
            if let date {
                HStack(spacing: 2) {
                    Text("重置")
                    Text(date, style: .relative)
                }
            } else {
                Text("重置时间未知")
            }
        }
        .font(.system(size: 7, weight: .medium, design: .rounded))
        .foregroundStyle(color)
        .lineLimit(1)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("重置时间")
        .accessibilityValue(accessibilityDescription)
    }

    private var accessibilityDescription: String {
        guard let date else { return "未知" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct MediumFooter: View {
    let snapshot: ProviderSnapshot
    let color: Color
    let secondaryColor: Color
    let reduceTransparency: Bool

    var body: some View {
        HStack(spacing: 3) {
            Label(
                snapshot.status == .stale ? "上次更新" : "更新于",
                systemImage: snapshot.status == .stale ? "clock.arrow.circlepath" : "checkmark.circle.fill"
            )
            Text(snapshot.updatedAt, style: .time)
            Spacer()
            Link(destination: URL(string: "codexquota://refresh")!) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 8, weight: .semibold))
                    .frame(width: 18, height: 18)
                    .quotaGlassControl(in: Circle(), opaque: reduceTransparency)
            }
            .buttonStyle(.plain)
            .foregroundStyle(color)
            .accessibilityLabel("打开 Codex Quota 并刷新")
        }
        .font(.system(size: 7, weight: .semibold, design: .rounded))
        .foregroundStyle(secondaryColor)
        .lineLimit(1)
    }
}

private struct FailureMotif: View {
    let theme: QuotaVisualTheme
    let color: Color

    var body: some View {
        ZStack {
            switch theme {
            case .crystal:
                Circle().stroke(.white.opacity(0.42), lineWidth: 5)
                Circle().trim(from: 0.05, to: 0.44).stroke(color.opacity(0.58), style: StrokeStyle(lineWidth: 5, lineCap: .round))
            case .aquarium:
                Image(systemName: "water.waves")
                    .font(.system(size: 28, weight: .medium))
            case .orbit:
                Circle().stroke(color.opacity(0.25), style: StrokeStyle(lineWidth: 3, dash: [4, 4]))
                Circle().trim(from: 0.08, to: 0.30).stroke(Color.cyan, style: StrokeStyle(lineWidth: 4, lineCap: .round))
            case .aurora:
                Image(systemName: "sparkles")
                    .font(.system(size: 27, weight: .medium))
            }
        }
        .frame(width: 42, height: 42)
        .foregroundStyle(color)
        .accessibilityHidden(true)
    }
}

private struct AquariumBubbles: View {
    let level: CGFloat
    let motionPhase: Bool

    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<6, id: \.self) { index in
                let size = CGFloat(3 + (index % 3) * 2)
                let x = proxy.size.width * CGFloat(0.14 + Double(index) * 0.145)
                let waterTop = proxy.size.height * (1 - level)
                let available = max(8, proxy.size.height - waterTop)
                let baseY = waterTop + available * CGFloat(0.28 + Double(index % 3) * 0.24)
                Circle()
                    .stroke(.white.opacity(0.45), lineWidth: 1)
                    .frame(width: size, height: size)
                    .position(x: x, y: baseY)
                    .offset(y: motionPhase ? -10 : 7)
                    .opacity(level > 0.08 ? 1 : 0)
            }
        }
        .animation(.easeInOut(duration: 1.55), value: motionPhase)
        .accessibilityHidden(true)
    }
}

private struct WaveShape: Shape {
    var level: CGFloat
    var phase: CGFloat
    var amplitude: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(level, phase) }
        set {
            level = newValue.first
            phase = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        guard level > 0 else { return Path() }
        var path = Path()
        let baseline = rect.height * (1 - min(1, max(0, level)))
        let wavelength = max(48, rect.width * 0.62)
        let steps = max(24, Int(rect.width / 3))

        path.move(to: CGPoint(x: rect.minX, y: baseline + sin(phase) * amplitude))
        for step in 1...steps {
            let x = rect.width * CGFloat(step) / CGFloat(steps)
            let angle = (x / wavelength) * .pi * 2 + phase
            let y = baseline + sin(angle) * amplitude
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

extension View {
    @ViewBuilder
    func quotaGlassControl<S: Shape>(in shape: S, opaque: Bool = false) -> some View {
        if opaque {
            background(Color.white.opacity(0.82), in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.76), lineWidth: 1))
        } else if #available(macOS 26.0, *) {
            glassEffect(.regular.interactive(), in: shape)
        } else {
            background(.regularMaterial, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.48), lineWidth: 1))
        }
    }
}
