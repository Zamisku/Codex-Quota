import XCTest

final class QuotaVisualThemeTests: XCTestCase {
    private var suiteName: String!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "CodexQuotaTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        suiteName = nil
        super.tearDown()
    }

    func testMissingAndUnknownThemeFallBackToCrystal() {
        XCTAssertEqual(QuotaThemePreferences.load(from: defaults), .crystal)

        defaults.set("future-theme", forKey: QuotaThemePreferences.defaultsKey)
        XCTAssertEqual(QuotaThemePreferences.load(from: defaults), .crystal)
    }

    func testSavedThemeRoundTrips() {
        for theme in QuotaVisualTheme.allCases {
            QuotaThemePreferences.save(theme, to: defaults)
            XCTAssertEqual(QuotaThemePreferences.load(from: defaults), theme)
        }
    }

    func testFollowAppAndExplicitOverridesResolveCorrectly() {
        XCTAssertEqual(WidgetThemeChoice.followApp.resolved(globalTheme: .aurora), .aurora)
        XCTAssertEqual(WidgetThemeChoice.crystal.resolved(globalTheme: .aurora), .crystal)
        XCTAssertEqual(WidgetThemeChoice.aquarium.resolved(globalTheme: .crystal), .aquarium)
        XCTAssertEqual(WidgetThemeChoice.orbit.resolved(globalTheme: .crystal), .orbit)
        XCTAssertEqual(WidgetThemeChoice.aurora.resolved(globalTheme: .crystal), .aurora)
    }

    func testLegacyKindRemainsStableAndConfigurableKindIsDistinct() {
        XCTAssertEqual(CodexQuotaWidgetKind.legacy, "com.Zamisku.Codex-Quota.quota")
        XCTAssertNotEqual(CodexQuotaWidgetKind.legacy, CodexQuotaWidgetKind.configurable)
        XCTAssertEqual(Set(CodexQuotaWidgetKind.all).count, 2)
    }

    func testLegacyWidgetAlwaysUsesGlobalTheme() {
        XCTAssertEqual(
            QuotaWidgetThemeResolver.resolve(
                widgetKind: CodexQuotaWidgetKind.legacy,
                globalTheme: .aurora,
                choice: .aquarium
            ),
            .aurora
        )
    }

    func testConfigurableWidgetFollowsOrOverridesGlobalTheme() {
        XCTAssertEqual(
            QuotaWidgetThemeResolver.resolve(
                widgetKind: CodexQuotaWidgetKind.configurable,
                globalTheme: .orbit,
                choice: .followApp
            ),
            .orbit
        )
        XCTAssertEqual(
            QuotaWidgetThemeResolver.resolve(
                widgetKind: CodexQuotaWidgetKind.configurable,
                globalTheme: .orbit,
                choice: .aquarium
            ),
            .aquarium
        )
    }
}
