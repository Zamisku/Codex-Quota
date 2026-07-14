import SwiftUI
import WidgetKit

private enum AppPalette {
    static let primaryText = Color(red: 0.08, green: 0.11, blue: 0.16)
    static let secondaryText = Color(red: 0.25, green: 0.31, blue: 0.34)
    static let warningText = Color(red: 0.53, green: 0.23, blue: 0.08)
    static let accent = Color(red: 0.12, green: 0.40, blue: 0.82)
}

enum ProjectLinks {
    static let repository = URL(string: "https://github.com/Zamisku/Codex-Quota")!
}

struct ContentView: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @ObservedObject var model: HostModel
    @State private var selectedTheme: QuotaVisualTheme
    @State private var showingThemeGallery = false

    init(model: HostModel) {
        self.model = model
        _selectedTheme = State(initialValue: QuotaThemePreferences.globalTheme)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.78, green: 0.89, blue: 0.98),
                    Color(red: 0.89, green: 0.96, blue: 0.94),
                    Color(red: 0.80, green: 0.93, blue: 0.83)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 21) {
                HStack(spacing: 14) {
                    Image(systemName: "gauge.with.dots.needle.33percent")
                        .font(.system(size: 30, weight: .semibold))
                        .frame(width: 54, height: 54)
                        .background(.white.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Codex Quota")
                            .font(.system(size: 27, weight: .bold, design: .rounded))
                        Text("原生 macOS WidgetKit 桌面小组件")
                            .foregroundStyle(AppPalette.secondaryText)
                    }
                }

                statusCard

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("添加到桌面", systemImage: "square.grid.2x2")
                            .font(.headline)
                        Spacer()
                        Button {
                            showingThemeGallery = true
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: selectedTheme.symbolName)
                                Text(selectedTheme.displayName)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 8, weight: .bold))
                                    .opacity(0.58)
                            }
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .quotaGlassControl(in: Capsule(), opaque: reduceTransparency)
                        }
                        .buttonStyle(.plain)
                        .help("预览并选择 Widget 的全局默认主题")
                    }
                    Text("1. 在桌面空白处按住 Control 点击\n2. 选择“编辑小组件”\n3. 搜索“Codex Quota”并选择 Small 或 Medium")
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(AppPalette.secondaryText)
                        .lineSpacing(5)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.38), in: RoundedRectangle(cornerRadius: 18))

                HStack(spacing: 12) {
                    Toggle("登录时保持同步", isOn: Binding(
                        get: { model.launchAtLoginEnabled },
                        set: { model.setLaunchAtLogin($0) }
                    ))
                    .toggleStyle(.switch)
                    .help("宿主在登录后运行，定期写入不含令牌的额度快照。")

                    Spacer()

                    Button {
                        Task { await model.refresh() }
                    } label: {
                        if model.isLoading {
                            ProgressView().controlSize(.small)
                        } else {
                            Label("检查并刷新", systemImage: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(model.isLoading)
                }

                HStack(spacing: 7) {
                    Image(systemName: "star.fill")
                        .foregroundStyle(.yellow)
                    Text("觉得 Codex Quota 有用？")
                    Link("在 GitHub 点 Star 支持项目", destination: ProjectLinks.repository)
                        .fontWeight(.semibold)
                }
                .font(.caption)
                .foregroundStyle(AppPalette.secondaryText)

                Text(model.notice ?? "WidgetKit 的刷新由系统调度，宿主更新快照后会请求刷新桌面组件。")
                    .font(.caption)
                    .foregroundStyle(model.notice == nil ? AppPalette.secondaryText : AppPalette.warningText)
            }
            .padding(28)
            .foregroundStyle(AppPalette.primaryText)
            .tint(AppPalette.accent)
        }
        .onAppear {
            selectedTheme = QuotaThemePreferences.globalTheme
        }
        .sheet(isPresented: $showingThemeGallery) {
            ThemeGalleryView(
                selectedTheme: $selectedTheme,
                snapshot: themePreviewSnapshot,
                onSelect: applyTheme
            )
        }
    }

    private var themePreviewSnapshot: ProviderSnapshot {
        guard let snapshot = model.snapshot, snapshot.hasUsageWindow else { return .themePreview }
        return snapshot
    }

    private func applyTheme(_ theme: QuotaVisualTheme) {
        QuotaThemePreferences.save(theme)
        for kind in CodexQuotaWidgetKind.all {
            WidgetCenter.shared.reloadTimelines(ofKind: kind)
        }
    }

    private var statusCard: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(statusColor)
                .frame(width: 11, height: 11)
                .shadow(color: statusColor.opacity(0.55), radius: 5)
            VStack(alignment: .leading, spacing: 3) {
                Text(statusTitle)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                if let usageSummary {
                    Text(usageSummary)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppPalette.secondaryText)
                } else {
                    Text(statusDetail)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(AppPalette.secondaryText)
                }
            }
            Spacer()
            if SharedSnapshotStore.snapshotURL != nil {
                Image(systemName: "checkmark.icloud.fill")
                    .foregroundStyle(.green)
                    .help("App Group 已连接")
            }
        }
        .padding(16)
        .background(.white.opacity(0.5), in: RoundedRectangle(cornerRadius: 18))
    }

    private var usageSummary: String? {
        switch (model.snapshot?.shortWindow, model.snapshot?.weeklyWindow) {
        case let (.some(short), .some(weekly)):
            return "5 小时剩余 \(percent(short)) · 周剩余 \(percent(weekly))"
        case let (.some(short), .none):
            return "5 小时剩余 \(percent(short))"
        case let (.none, .some(weekly)):
            return "本周剩余 \(percent(weekly))"
        case (.none, .none):
            return nil
        }
    }

    private func percent(_ window: UsageWindow) -> String {
        "\(Int(window.remainingPercent.rounded()))%"
    }

    private var statusColor: Color {
        if model.isLoading { return .blue }
        switch model.snapshot?.status {
        case .ok: return .green
        case .signedOut: return .orange
        case .unavailable, .stale: return .red
        case nil: return .gray
        }
    }

    private var statusTitle: String {
        if model.isLoading { return "正在读取 Codex 额度…" }
        switch model.snapshot?.status {
        case .ok: return "Codex 连接正常，脱敏快照已共享"
        case .signedOut: return "请先登录 Codex Desktop"
        case .unavailable: return "额度服务暂不可用"
        case .stale: return "当前显示上次数据"
        case nil: return "等待检查"
        }
    }

    private var statusDetail: String {
        switch model.snapshot?.failure {
        case .noSnapshot: return "尚未生成组件快照"
        case .loginNotFound: return "没有找到 ~/.codex/auth.json"
        case .loginExpired: return "登录已过期，请在 Codex Desktop 中重新登录"
        case .invalidLogin: return "登录文件不可读或格式已变化"
        case .networkUnavailable: return "网络不可用"
        case .rateLimited: return "请求过于频繁，请稍后重试"
        case .serviceUnavailable: return "服务暂时不可用"
        case .responseChanged, .missingShortWindow: return "额度响应格式已变化"
        case nil: return "启动后会自动检查"
        }
    }
}

#Preview {
    ContentView(model: HostModel(autoStart: false))
}
