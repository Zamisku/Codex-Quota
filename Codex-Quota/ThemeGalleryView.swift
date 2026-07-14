import SwiftUI
import WidgetKit

struct ThemeGalleryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var selectedTheme: QuotaVisualTheme
    let snapshot: ProviderSnapshot
    let onSelect: (QuotaVisualTheme) -> Void

    @State private var previewFamily = WidgetFamily.systemSmall
    @State private var motionPhase = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Widget 外观")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                    Text("选择全局默认主题；“Codex Quota · 自定义”可在编辑小组件时单独覆盖。")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            HStack {
                Picker("预览尺寸", selection: $previewFamily) {
                    Text("Small").tag(WidgetFamily.systemSmall)
                    Text("Medium").tag(WidgetFamily.systemMedium)
                }
                .pickerStyle(.segmented)
                .frame(width: 210)
                Spacer()
                Label("动效预览", systemImage: reduceMotion ? "figure.walk.motion" : "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)],
                spacing: 14
            ) {
                ForEach(QuotaVisualTheme.allCases) { theme in
                    themeTile(theme)
                }
            }
        }
        .padding(24)
        .frame(width: 760, height: 580)
        .background(Color(nsColor: .windowBackgroundColor))
        .task(id: reduceMotion) {
            guard !reduceMotion else {
                motionPhase = false
                return
            }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 2_600_000_000)
                } catch {
                    return
                }
                withAnimation(.easeInOut(duration: 1.6)) {
                    motionPhase.toggle()
                }
            }
        }
    }

    private func themeTile(_ theme: QuotaVisualTheme) -> some View {
        let selected = selectedTheme == theme
        return VStack(alignment: .leading, spacing: 10) {
            ZStack {
                QuotaWidgetThemePreview(
                    snapshot: snapshot,
                    family: previewFamily,
                    theme: theme,
                    motionPhase: motionPhase
                )
                .allowsHitTesting(false)
                .frame(
                    width: previewFamily == .systemSmall ? 150 : 294,
                    height: previewFamily == .systemSmall ? 150 : 147
                )
            }
            .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 150)

            HStack(spacing: 9) {
                Image(systemName: theme.symbolName)
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 28, height: 28)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 1) {
                    Text(theme.displayName)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                    Text(theme.summary)
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary.opacity(0.45))
            }
        }
        .padding(12)
        .background(
            selected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.035),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(selected ? Color.accentColor.opacity(0.78) : Color.primary.opacity(0.08), lineWidth: selected ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture {
            guard selectedTheme != theme else { return }
            selectedTheme = theme
            onSelect(theme)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction {
            selectedTheme = theme
            onSelect(theme)
        }
    }
}
