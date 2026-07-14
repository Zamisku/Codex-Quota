import AppIntents

extension WidgetThemeChoice: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Widget 主题"

    static var caseDisplayRepresentations: [WidgetThemeChoice: DisplayRepresentation] = [
        .followApp: "跟随应用",
        .crystal: "晶透玻璃",
        .aquarium: "整卡水族箱",
        .orbit: "双轨星环",
        .aurora: "极光简约"
    ]
}

struct QuotaWidgetConfigurationIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Codex Quota 外观"
    static var description = IntentDescription("为这一枚 Codex Quota 小组件单独选择主题。")

    @Parameter(title: "主题", default: .followApp)
    var theme: WidgetThemeChoice

    static var parameterSummary: some ParameterSummary {
        Summary("使用 \(\.$theme)")
    }

    init() {
        theme = .followApp
    }

    init(theme: WidgetThemeChoice) {
        self.theme = theme
    }
}
