import AppKit
import Foundation
import SwiftUI
import WidgetKit

private enum ThemeAssetError: Error, CustomStringConvertible {
    case missingImage(String)
    case imageRendererFailed
    case bitmapCreationFailed
    case pngEncodingFailed

    var description: String {
        switch self {
        case .missingImage(let path): return "Unable to load image at \(path)"
        case .imageRendererFailed: return "SwiftUI ImageRenderer did not return an image"
        case .bitmapCreationFailed: return "Unable to create a bitmap graphics context"
        case .pngEncodingFailed: return "Unable to encode a PNG"
        }
    }
}

private struct ShowcaseCopy {
    let eyebrow: String
    let title: String
    let subtitle: String
    let badges: [String]
    let themes: [(name: String, detail: String)]
}

private struct AquariumCopy {
    let eyebrow: String
    let title: String
    let subtitle: String
    let legend: String
    let states: [String]
    let footnote: String
}

private let navy = NSColor(srgbRed: 8 / 255, green: 25 / 255, blue: 51 / 255, alpha: 1)
private let slate = NSColor(srgbRed: 42 / 255, green: 65 / 255, blue: 88 / 255, alpha: 1)
private let blue = NSColor(srgbRed: 46 / 255, green: 113 / 255, blue: 226 / 255, alpha: 1)
private let cyan = NSColor(srgbRed: 28 / 255, green: 191 / 255, blue: 209 / 255, alpha: 1)
private let indigo = NSColor(srgbRed: 91 / 255, green: 97 / 255, blue: 217 / 255, alpha: 1)
private let mint = NSColor(srgbRed: 92 / 255, green: 203 / 255, blue: 155 / 255, alpha: 1)
private let amber = NSColor(srgbRed: 245 / 255, green: 156 / 255, blue: 46 / 255, alpha: 1)
private let coral = NSColor(srgbRed: 239 / 255, green: 74 / 255, blue: 60 / 255, alpha: 1)

@main
@MainActor
struct ThemeAssetRenderer {
    static func main() throws {
        let root = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let assets = root.appendingPathComponent("docs/assets", isDirectory: true)
        let galleryBackground = try loadImage(
            assets.appendingPathComponent("theme-showcase-background-v1.png")
        )
        let socialBackground = try loadImage(
            assets.appendingPathComponent("theme-social-background-v1.png")
        )
        let appIcon = try loadImage(root.appendingPathComponent(
            "Codex-Quota/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png"
        ))

        let showcaseSnapshot = dualWindowSnapshot(primary: 72, weekly: 84)
        let themes = QuotaVisualTheme.allCases
        let mediumWidgets = try themes.map {
            try widgetImage(
                snapshot: showcaseSnapshot,
                family: .systemMedium,
                theme: $0,
                pointSize: CGSize(width: 360, height: 180)
            )
        }

        let englishShowcase = ShowcaseCopy(
            eyebrow: "CODEX QUOTA · WIDGET GALLERY",
            title: "Four themes. One accurate snapshot.",
            subtitle: "Choose once for every widget, or give each Custom widget its own look.",
            badges: ["GLOBAL THEME", "PER-WIDGET OVERRIDE"],
            themes: [
                ("Crystal Glass", "Refractive lens · precise percentage"),
                ("Full-card Aquarium", "Water level equals remaining quota"),
                ("Dual-track Orbit", "Primary and weekly limits in one gauge"),
                ("Minimal Aurora", "Low-density type · soft progress field")
            ]
        )
        let chineseShowcase = ShowcaseCopy(
            eyebrow: "CODEX QUOTA · WIDGET 主题画廊",
            title: "四套主题，同一份精确额度。",
            subtitle: "可为全部 Widget 统一选择，也可让每个“自定义”组件拥有独立主题。",
            badges: ["全局主题", "单组件覆盖"],
            themes: [
                ("晶透玻璃", "折射透镜 · 精确百分比"),
                ("整卡水族箱", "整张卡片的水位等于剩余额度"),
                ("双轨星环", "主额度与周额度同时呈现"),
                ("极光简约", "低信息密度 · 柔和进度色场")
            ]
        )

        try renderShowcase(
            copy: englishShowcase,
            background: galleryBackground,
            appIcon: appIcon,
            widgets: mediumWidgets,
            outputURL: assets.appendingPathComponent("theme-showcase.png")
        )
        try renderShowcase(
            copy: chineseShowcase,
            background: galleryBackground,
            appIcon: appIcon,
            widgets: mediumWidgets,
            outputURL: assets.appendingPathComponent("theme-showcase-zh.png")
        )

        let levels: [Double] = [84, 34, 15, 0]
        let aquariumWidgets = try levels.map {
            try widgetImage(
                snapshot: weeklySnapshot(remaining: $0),
                family: .systemSmall,
                theme: .aquarium,
                pointSize: CGSize(width: 180, height: 180)
            )
        }
        let englishAquarium = AquariumCopy(
            eyebrow: "FULL-CARD AQUARIUM",
            title: "The card is the gauge.",
            subtitle: "Water falls with your remaining quota; exact numbers stay visible at every level.",
            legend: "BLUE  > 35%     ·     AMBER  16–35%     ·     CORAL  ≤ 15%",
            states: ["84% · Healthy", "34% · Attention", "15% · Critical", "0% · Empty"],
            footnote: "SYNTHETIC PREVIEW DATA · NO ACCOUNT INFORMATION"
        )
        let chineseAquarium = AquariumCopy(
            eyebrow: "整卡水族箱",
            title: "整张卡片，就是进度条。",
            subtitle: "水位随剩余额度下降，任何水位都保留准确数字与清晰状态。",
            legend: "青蓝  > 35%     ·     琥珀  16–35%     ·     珊瑚红  ≤ 15%",
            states: ["84% · 充足", "34% · 注意", "15% · 紧急", "0% · 已用尽"],
            footnote: "合成预览数据 · 不含账号信息"
        )

        try renderAquariumLevels(
            copy: englishAquarium,
            background: galleryBackground,
            widgets: aquariumWidgets,
            outputURL: assets.appendingPathComponent("aquarium-levels.png")
        )
        try renderAquariumLevels(
            copy: chineseAquarium,
            background: galleryBackground,
            widgets: aquariumWidgets,
            outputURL: assets.appendingPathComponent("aquarium-levels-zh.png")
        )

        let smallWidgets = try themes.map {
            try widgetImage(
                snapshot: showcaseSnapshot,
                family: .systemSmall,
                theme: $0,
                pointSize: CGSize(width: 180, height: 180)
            )
        }
        try renderSocialPreview(
            background: socialBackground,
            appIcon: appIcon,
            widgets: smallWidgets,
            outputURL: assets.appendingPathComponent("github-social-preview-themes.png")
        )

        print("Rendered four-theme promotional assets in \(assets.path)")
    }

    private static func dualWindowSnapshot(primary: Double, weekly: Double) -> ProviderSnapshot {
        let now = Date()
        return ProviderSnapshot(
            plan: "PLUS",
            shortWindow: UsageWindow(
                remainingPercent: primary,
                resetsAt: now.addingTimeInterval(2.5 * 60 * 60),
                windowSeconds: 18_000
            ),
            weeklyWindow: UsageWindow(
                remainingPercent: weekly,
                resetsAt: now.addingTimeInterval(4 * 86_400),
                windowSeconds: 604_800
            ),
            resetCredits: 2,
            resetCreditExpirations: [],
            updatedAt: now,
            status: .ok,
            failure: nil
        )
    }

    private static func weeklySnapshot(remaining: Double) -> ProviderSnapshot {
        let now = Date()
        return ProviderSnapshot(
            plan: "PLUS",
            shortWindow: nil,
            weeklyWindow: UsageWindow(
                remainingPercent: remaining,
                resetsAt: now.addingTimeInterval(4 * 86_400),
                windowSeconds: 604_800
            ),
            resetCredits: 2,
            resetCreditExpirations: [],
            updatedAt: now,
            status: .ok,
            failure: nil
        )
    }

    private static func widgetImage(
        snapshot: ProviderSnapshot,
        family: WidgetFamily,
        theme: QuotaVisualTheme,
        pointSize: CGSize
    ) throws -> NSImage {
        let view = QuotaWidgetThemePreview(
            snapshot: snapshot,
            family: family,
            theme: theme
        )
        .frame(width: pointSize.width, height: pointSize.height)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(pointSize)
        renderer.scale = 2
        guard let image = renderer.nsImage else {
            throw ThemeAssetError.imageRendererFailed
        }
        return image
    }

    private static func renderShowcase(
        copy: ShowcaseCopy,
        background: NSImage,
        appIcon: NSImage,
        widgets: [NSImage],
        outputURL: URL
    ) throws {
        try renderCanvas(size: NSSize(width: 1600, height: 1000), outputURL: outputURL) { size in
            drawBackground(background, size: size)
            drawVeil(size: size, color: .white, alpha: 0.17)

            drawImage(appIcon, rect: topRect(x: 72, top: 50, width: 82, height: 82, canvas: size), shadow: 22)
            drawSingleLine(copy.eyebrow, x: 178, top: 54, canvas: size,
                           font: .systemFont(ofSize: 15, weight: .bold), color: blue, tracking: 1.5)
            drawSingleLine(copy.title, x: 178, top: 78, canvas: size,
                           font: .systemFont(ofSize: 42, weight: .bold), color: navy, tracking: -0.7)
            drawSingleLine(copy.subtitle, x: 178, top: 128, canvas: size,
                           font: .systemFont(ofSize: 18, weight: .medium), color: slate)
            drawBadges(copy.badges, right: 1528, top: 76, canvas: size)

            let positions: [(x: CGFloat, labelTop: CGFloat, widgetTop: CGFloat)] = [
                (100, 190, 250), (860, 190, 250),
                (100, 604, 664), (860, 604, 664)
            ]
            let accents = [blue, cyan, indigo, mint]

            for index in widgets.indices {
                let position = positions[index]
                drawThemeLabel(
                    name: copy.themes[index].name,
                    detail: copy.themes[index].detail,
                    accent: accents[index],
                    rect: topRect(x: position.x, top: position.labelTop, width: 640, height: 52, canvas: size)
                )
                drawImage(
                    widgets[index],
                    rect: topRect(x: position.x, top: position.widgetTop, width: 640, height: 320, canvas: size),
                    shadow: 28
                )
            }
        }
    }

    private static func renderAquariumLevels(
        copy: AquariumCopy,
        background: NSImage,
        widgets: [NSImage],
        outputURL: URL
    ) throws {
        try renderCanvas(size: NSSize(width: 1600, height: 680), outputURL: outputURL) { size in
            drawBackground(background, size: size)
            drawVeil(size: size, color: .white, alpha: 0.42)

            drawSingleLine(copy.eyebrow, x: 80, top: 45, canvas: size,
                           font: .systemFont(ofSize: 15, weight: .bold), color: blue, tracking: 1.7)
            drawSingleLine(copy.title, x: 80, top: 70, canvas: size,
                           font: .systemFont(ofSize: 40, weight: .bold), color: navy, tracking: -0.6)
            drawSingleLine(copy.subtitle, x: 80, top: 119, canvas: size,
                           font: .systemFont(ofSize: 18, weight: .medium), color: slate)
            drawLegend(copy.legend, right: 1520, top: 84, canvas: size)

            let xs: [CGFloat] = [80, 460, 840, 1220]
            let stateColors = [blue, amber, coral, coral]
            for index in widgets.indices {
                drawImage(
                    widgets[index],
                    rect: topRect(x: xs[index], top: 200, width: 300, height: 300, canvas: size),
                    shadow: 27
                )
                drawStateLabel(
                    copy.states[index],
                    accent: stateColors[index],
                    centerX: xs[index] + 150,
                    top: 535,
                    canvas: size
                )
            }
            drawSingleLine(copy.footnote, x: 80, top: 629, canvas: size,
                           font: .monospacedSystemFont(ofSize: 11, weight: .medium),
                           color: slate.withAlphaComponent(0.72), tracking: 0.5)
        }
    }

    private static func renderSocialPreview(
        background: NSImage,
        appIcon: NSImage,
        widgets: [NSImage],
        outputURL: URL
    ) throws {
        try renderCanvas(size: NSSize(width: 1280, height: 640), outputURL: outputURL) { size in
            drawBackground(background, size: size)
            drawVeil(size: size, color: navy, alpha: 0.10)

            drawImage(appIcon, rect: topRect(x: 64, top: 58, width: 78, height: 78, canvas: size), shadow: 24)
            drawSingleLine("OPEN SOURCE · NATIVE macOS", x: 164, top: 65, canvas: size,
                           font: .systemFont(ofSize: 14, weight: .bold), color: NSColor.white.withAlphaComponent(0.82), tracking: 1.5)
            drawSingleLine("Codex Quota", x: 64, top: 176, canvas: size,
                           font: .systemFont(ofSize: 58, weight: .bold), color: .white, tracking: -1.4)
            drawSingleLine("Four themes. One glance.", x: 64, top: 250, canvas: size,
                           font: .systemFont(ofSize: 27, weight: .semibold), color: NSColor.white.withAlphaComponent(0.90))
            drawSingleLine("Global theme  ·  Per-widget override  ·  Local-first", x: 64, top: 300, canvas: size,
                           font: .systemFont(ofSize: 16, weight: .medium), color: NSColor.white.withAlphaComponent(0.72))
            drawSocialBadges(["CRYSTAL", "AQUARIUM", "ORBIT", "AURORA"], x: 64, top: 364, canvas: size)
            drawSingleLine("github.com/Zamisku/Codex-Quota", x: 64, top: 550, canvas: size,
                           font: .monospacedSystemFont(ofSize: 14, weight: .medium),
                           color: NSColor.white.withAlphaComponent(0.64))

            let positions: [(CGFloat, CGFloat, CGFloat)] = [
                (770, 54, -7), (1007, 78, 5),
                (745, 312, 5), (982, 332, -5)
            ]
            for index in widgets.indices {
                let (x, top, rotation) = positions[index]
                drawRotatedImage(
                    widgets[index],
                    center: topPoint(x: x + 108, top: top + 108, canvas: size),
                    size: NSSize(width: 216, height: 216),
                    degrees: rotation,
                    shadow: 24
                )
            }
        }
    }
}

private func loadImage(_ url: URL) throws -> NSImage {
    guard let image = NSImage(contentsOf: url) else {
        throw ThemeAssetError.missingImage(url.path)
    }
    return image
}

private func renderCanvas(
    size: NSSize,
    outputURL: URL,
    draw: (NSSize) -> Void
) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw ThemeAssetError.bitmapCreationFailed
    }

    let previous = NSGraphicsContext.current
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.current = previous }
    context.imageInterpolation = .high
    draw(size)
    context.flushGraphics()

    guard let png = bitmap.representation(
        using: .png,
        properties: [.compressionFactor: 0.94]
    ) else {
        throw ThemeAssetError.pngEncodingFailed
    }
    try png.write(to: outputURL, options: .atomic)
}

private func topRect(
    x: CGFloat,
    top: CGFloat,
    width: CGFloat,
    height: CGFloat,
    canvas: NSSize
) -> NSRect {
    NSRect(x: x, y: canvas.height - top - height, width: width, height: height)
}

private func topPoint(x: CGFloat, top: CGFloat, canvas: NSSize) -> NSPoint {
    NSPoint(x: x, y: canvas.height - top)
}

private func aspectFillSourceRect(image: NSImage, destination: NSSize) -> NSRect {
    let source = image.size
    let sourceAspect = source.width / source.height
    let destinationAspect = destination.width / destination.height
    if sourceAspect > destinationAspect {
        let width = source.height * destinationAspect
        return NSRect(x: (source.width - width) / 2, y: 0, width: width, height: source.height)
    }
    let height = source.width / destinationAspect
    return NSRect(x: 0, y: (source.height - height) / 2, width: source.width, height: height)
}

private func drawBackground(_ image: NSImage, size: NSSize) {
    let bounds = NSRect(origin: .zero, size: size)
    image.draw(
        in: bounds,
        from: aspectFillSourceRect(image: image, destination: size),
        operation: .copy,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )
}

private func drawVeil(size: NSSize, color: NSColor, alpha: CGFloat) {
    color.withAlphaComponent(alpha).setFill()
    NSBezierPath(rect: NSRect(origin: .zero, size: size)).fill()
}

private func withShadow(blur: CGFloat, color: NSColor = navy.withAlphaComponent(0.24), draw: () -> Void) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.shadowBlurRadius = blur
    shadow.shadowColor = color
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

private func drawImage(_ image: NSImage, rect: NSRect, shadow: CGFloat) {
    withShadow(blur: shadow) {
        image.draw(
            in: rect,
            from: NSRect(origin: .zero, size: image.size),
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }
}

private func drawRotatedImage(
    _ image: NSImage,
    center: NSPoint,
    size: NSSize,
    degrees: CGFloat,
    shadow: CGFloat
) {
    NSGraphicsContext.saveGraphicsState()
    let transform = NSAffineTransform()
    transform.translateX(by: center.x, yBy: center.y)
    transform.rotate(byDegrees: degrees)
    transform.translateX(by: -center.x, yBy: -center.y)
    transform.concat()
    drawImage(
        image,
        rect: NSRect(x: center.x - size.width / 2, y: center.y - size.height / 2,
                     width: size.width, height: size.height),
        shadow: shadow
    )
    NSGraphicsContext.restoreGraphicsState()
}

@discardableResult
private func drawSingleLine(
    _ text: String,
    x: CGFloat,
    top: CGFloat,
    canvas: NSSize,
    font: NSFont,
    color: NSColor,
    tracking: CGFloat = 0
) -> NSSize {
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .kern: tracking
    ]
    let size = (text as NSString).size(withAttributes: attributes)
    (text as NSString).draw(
        at: NSPoint(x: x, y: canvas.height - top - size.height),
        withAttributes: attributes
    )
    return size
}

private func drawBadges(_ labels: [String], right: CGFloat, top: CGFloat, canvas: NSSize) {
    var cursor = right
    for label in labels.reversed() {
        let font = NSFont.systemFont(ofSize: 12, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: navy]
        let textSize = (label as NSString).size(withAttributes: attributes)
        let width = textSize.width + 30
        cursor -= width
        let rect = topRect(x: cursor, top: top, width: width, height: 36, canvas: canvas)
        let path = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
        NSColor.white.withAlphaComponent(0.72).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.78).setStroke()
        path.lineWidth = 1
        path.stroke()
        (label as NSString).draw(
            at: NSPoint(x: rect.minX + 15, y: rect.midY - textSize.height / 2 + 1),
            withAttributes: attributes
        )
        cursor -= 10
    }
}

private func drawThemeLabel(name: String, detail: String, accent: NSColor, rect: NSRect) {
    let path = NSBezierPath(roundedRect: rect, xRadius: 18, yRadius: 18)
    withShadow(blur: 14, color: navy.withAlphaComponent(0.13)) {
        NSColor.white.withAlphaComponent(0.78).setFill()
        path.fill()
    }
    NSColor.white.withAlphaComponent(0.86).setStroke()
    path.lineWidth = 1
    path.stroke()

    let dot = NSBezierPath(ovalIn: NSRect(x: rect.minX + 18, y: rect.midY - 5, width: 10, height: 10))
    accent.setFill()
    dot.fill()
    let nameAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 20, weight: .bold),
        .foregroundColor: navy
    ]
    let detailAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        .foregroundColor: slate
    ]
    let nameSize = (name as NSString).size(withAttributes: nameAttributes)
    let detailSize = (detail as NSString).size(withAttributes: detailAttributes)
    (name as NSString).draw(
        at: NSPoint(x: rect.minX + 40, y: rect.midY - nameSize.height / 2 + 1),
        withAttributes: nameAttributes
    )
    (detail as NSString).draw(
        at: NSPoint(x: rect.maxX - 18 - detailSize.width, y: rect.midY - detailSize.height / 2 + 1),
        withAttributes: detailAttributes
    )
}

private func drawLegend(_ text: String, right: CGFloat, top: CGFloat, canvas: NSSize) {
    let font = NSFont.systemFont(ofSize: 12, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: navy,
        .kern: 0.4
    ]
    let textSize = (text as NSString).size(withAttributes: attributes)
    let width = textSize.width + 32
    let rect = topRect(x: right - width, top: top, width: width, height: 38, canvas: canvas)
    let path = NSBezierPath(roundedRect: rect, xRadius: 19, yRadius: 19)
    NSColor.white.withAlphaComponent(0.70).setFill()
    path.fill()
    (text as NSString).draw(
        at: NSPoint(x: rect.minX + 16, y: rect.midY - textSize.height / 2 + 1),
        withAttributes: attributes
    )
}

private func drawStateLabel(
    _ text: String,
    accent: NSColor,
    centerX: CGFloat,
    top: CGFloat,
    canvas: NSSize
) {
    let font = NSFont.systemFont(ofSize: 17, weight: .bold)
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: navy]
    let textSize = (text as NSString).size(withAttributes: attributes)
    let width = textSize.width + 42
    let rect = topRect(x: centerX - width / 2, top: top, width: width, height: 42, canvas: canvas)
    let path = NSBezierPath(roundedRect: rect, xRadius: 21, yRadius: 21)
    NSColor.white.withAlphaComponent(0.78).setFill()
    path.fill()
    let dot = NSBezierPath(ovalIn: NSRect(x: rect.minX + 14, y: rect.midY - 5, width: 10, height: 10))
    accent.setFill()
    dot.fill()
    (text as NSString).draw(
        at: NSPoint(x: rect.minX + 30, y: rect.midY - textSize.height / 2 + 1),
        withAttributes: attributes
    )
}

private func drawSocialBadges(_ labels: [String], x: CGFloat, top: CGFloat, canvas: NSSize) {
    var cursor = x
    for label in labels {
        let font = NSFont.systemFont(ofSize: 11, weight: .bold)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white.withAlphaComponent(0.90),
            .kern: 0.6
        ]
        let textSize = (label as NSString).size(withAttributes: attributes)
        let width = textSize.width + 24
        let rect = topRect(x: cursor, top: top, width: width, height: 32, canvas: canvas)
        let path = NSBezierPath(roundedRect: rect, xRadius: 16, yRadius: 16)
        NSColor.white.withAlphaComponent(0.12).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.22).setStroke()
        path.lineWidth = 1
        path.stroke()
        (label as NSString).draw(
            at: NSPoint(x: rect.minX + 12, y: rect.midY - textSize.height / 2 + 1),
            withAttributes: attributes
        )
        cursor += width + 8
    }
}
