#!/usr/bin/env swift

import AppKit
import Foundation

struct PromoCopy {
    let eyebrow: String
    let tagline: String
    let meta: String
    let pills: [String]
}

private enum PromoError: Error, CustomStringConvertible {
    case missingImage(String)
    case bitmapCreationFailed
    case pngEncodingFailed

    var description: String {
        switch self {
        case .missingImage(let path):
            return "Unable to load image at \(path)"
        case .bitmapCreationFailed:
            return "Unable to create a bitmap graphics context"
        case .pngEncodingFailed:
            return "Unable to encode the rendered image as PNG"
        }
    }
}

private let navy = NSColor(srgbRed: 21 / 255, green: 40 / 255, blue: 63 / 255, alpha: 1)
private let blue = NSColor(srgbRed: 45 / 255, green: 111 / 255, blue: 224 / 255, alpha: 1)
private let mutedNavy = NSColor(srgbRed: 45 / 255, green: 70 / 255, blue: 94 / 255, alpha: 1)

private func loadImage(_ url: URL) throws -> NSImage {
    guard let image = NSImage(contentsOf: url) else {
        throw PromoError.missingImage(url.path)
    }
    return image
}

private func rectFromTop(
    x: CGFloat,
    top: CGFloat,
    width: CGFloat,
    height: CGFloat,
    canvasHeight: CGFloat
) -> NSRect {
    NSRect(x: x, y: canvasHeight - top - height, width: width, height: height)
}

private func aspectFillSourceRect(imageSize: NSSize, destinationSize: NSSize) -> NSRect {
    let sourceAspect = imageSize.width / imageSize.height
    let destinationAspect = destinationSize.width / destinationSize.height

    if sourceAspect > destinationAspect {
        let sourceWidth = imageSize.height * destinationAspect
        return NSRect(
            x: (imageSize.width - sourceWidth) / 2,
            y: 0,
            width: sourceWidth,
            height: imageSize.height
        )
    }

    let sourceHeight = imageSize.width / destinationAspect
    return NSRect(
        x: 0,
        y: (imageSize.height - sourceHeight) / 2,
        width: imageSize.width,
        height: sourceHeight
    )
}

private func drawBackground(_ image: NSImage, in bounds: NSRect) {
    let sourceRect = aspectFillSourceRect(imageSize: image.size, destinationSize: bounds.size)
    image.draw(
        in: bounds,
        from: sourceRect,
        operation: .copy,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )

    NSGradient(colors: [
        NSColor.white.withAlphaComponent(0.48),
        NSColor.white.withAlphaComponent(0.10),
        NSColor.white.withAlphaComponent(0.02)
    ])?.draw(in: bounds, angle: 0)

    let topGlow = NSBezierPath(ovalIn: NSRect(
        x: -bounds.width * 0.12,
        y: bounds.height * 0.35,
        width: bounds.width * 0.70,
        height: bounds.height * 0.92
    ))
    NSColor.white.withAlphaComponent(0.14).setFill()
    topGlow.fill()
}

private func withShadow(
    offset: NSSize,
    blur: CGFloat,
    color: NSColor,
    draw: () -> Void
) {
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowOffset = offset
    shadow.shadowBlurRadius = blur
    shadow.shadowColor = color
    shadow.set()
    draw()
    NSGraphicsContext.restoreGraphicsState()
}

private func drawImageCard(
    _ image: NSImage,
    rect: NSRect,
    cornerRadius: CGFloat,
    shadowBlur: CGFloat
) {
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

    withShadow(
        offset: NSSize(width: 0, height: -10),
        blur: shadowBlur,
        color: navy.withAlphaComponent(0.22)
    ) {
        NSColor.white.withAlphaComponent(0.82).setFill()
        path.fill()
    }

    NSGraphicsContext.saveGraphicsState()
    path.addClip()
    image.draw(
        in: rect,
        from: NSRect(origin: .zero, size: image.size),
        operation: .sourceOver,
        fraction: 1,
        respectFlipped: false,
        hints: [.interpolation: NSImageInterpolation.high]
    )
    NSGraphicsContext.restoreGraphicsState()

    NSColor.white.withAlphaComponent(0.72).setStroke()
    path.lineWidth = 1.5
    path.stroke()
}

@discardableResult
private func drawSingleLine(
    _ text: String,
    x: CGFloat,
    top: CGFloat,
    canvasHeight: CGFloat,
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
        at: NSPoint(x: x, y: canvasHeight - top - size.height),
        withAttributes: attributes
    )
    return size
}

private func drawPills(
    _ labels: [String],
    x: CGFloat,
    top: CGFloat,
    canvasHeight: CGFloat,
    fontSize: CGFloat,
    gap: CGFloat,
    horizontalPadding: CGFloat,
    height: CGFloat
) {
    var cursor = x
    let font = NSFont.systemFont(ofSize: fontSize, weight: .semibold)

    for label in labels {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: navy
        ]
        let textSize = (label as NSString).size(withAttributes: attributes)
        let width = textSize.width + horizontalPadding * 2
        let rect = rectFromTop(
            x: cursor,
            top: top,
            width: width,
            height: height,
            canvasHeight: canvasHeight
        )
        let path = NSBezierPath(roundedRect: rect, xRadius: height / 2, yRadius: height / 2)
        NSColor.white.withAlphaComponent(0.62).setFill()
        path.fill()
        NSColor.white.withAlphaComponent(0.82).setStroke()
        path.lineWidth = 1
        path.stroke()

        let textPoint = NSPoint(
            x: rect.minX + horizontalPadding,
            y: rect.midY - textSize.height / 2 + 1
        )
        (label as NSString).draw(at: textPoint, withAttributes: attributes)
        cursor += width + gap
    }
}

private func renderPromo(
    size: NSSize,
    background: NSImage,
    appIcon: NSImage,
    mediumWidget: NSImage,
    smallWidget: NSImage,
    copy: PromoCopy,
    outputURL: URL,
    compact: Bool
) throws {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: Int(size.width),
        pixelsHigh: Int(size.height),
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: NSColorSpaceName.deviceRGB,
        bitmapFormat: [],
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw PromoError.bitmapCreationFailed
    }

    let previousContext = NSGraphicsContext.current
    NSGraphicsContext.current = context
    defer { NSGraphicsContext.current = previousContext }

    context.imageInterpolation = NSImageInterpolation.high
    let bounds = NSRect(origin: .zero, size: size)
    drawBackground(background, in: bounds)

    let scale = compact ? 0.8 : 1
    let left = compact ? 72.0 : 96.0
    let iconSize = compact ? 96.0 : 120.0
    let iconTop = compact ? 58.0 : 70.0
    let iconRect = rectFromTop(
        x: left,
        top: iconTop,
        width: iconSize,
        height: iconSize,
        canvasHeight: size.height
    )
    drawImageCard(appIcon, rect: iconRect, cornerRadius: iconSize * 0.225, shadowBlur: 24 * scale)

    let eyebrowX = left + iconSize + (compact ? 22 : 28)
    drawSingleLine(
        copy.eyebrow,
        x: eyebrowX,
        top: compact ? 72 : 86,
        canvasHeight: size.height,
        font: NSFont.systemFont(ofSize: compact ? 15 : 18, weight: .bold),
        color: blue,
        tracking: compact ? 1.4 : 1.8
    )
    drawSingleLine(
        "NATIVE · PRIVATE · GLANCEABLE",
        x: eyebrowX,
        top: compact ? 102 : 121,
        canvasHeight: size.height,
        font: NSFont.systemFont(ofSize: compact ? 13 : 15, weight: .semibold),
        color: mutedNavy.withAlphaComponent(0.82),
        tracking: compact ? 0.8 : 1.1
    )

    drawSingleLine(
        "Codex Quota",
        x: left,
        top: compact ? 190 : 230,
        canvasHeight: size.height,
        font: NSFont.systemFont(ofSize: compact ? 62 : 78, weight: .bold),
        color: navy,
        tracking: -1.5
    )

    let taglineFont: NSFont
    if copy.tagline.unicodeScalars.contains(where: { $0.value > 127 }) {
        taglineFont = NSFont(name: "PingFang SC", size: compact ? 27 : 35)
            ?? NSFont.systemFont(ofSize: compact ? 27 : 35, weight: .medium)
    } else {
        taglineFont = NSFont.systemFont(ofSize: compact ? 27 : 34, weight: .medium)
    }

    drawSingleLine(
        copy.tagline,
        x: left,
        top: compact ? 278 : 335,
        canvasHeight: size.height,
        font: taglineFont,
        color: navy.withAlphaComponent(0.94),
        tracking: -0.2
    )
    drawSingleLine(
        copy.meta,
        x: left,
        top: compact ? 326 : 394,
        canvasHeight: size.height,
        font: NSFont.systemFont(ofSize: compact ? 18 : 22, weight: .medium),
        color: mutedNavy
    )

    drawPills(
        copy.pills,
        x: left,
        top: compact ? 382 : 462,
        canvasHeight: size.height,
        fontSize: compact ? 14 : 17,
        gap: compact ? 8 : 10,
        horizontalPadding: compact ? 13 : 17,
        height: compact ? 36 : 44
    )

    drawSingleLine(
        "github.com/Zamisku/Codex-Quota",
        x: left,
        top: compact ? 548 : 686,
        canvasHeight: size.height,
        font: NSFont.monospacedSystemFont(ofSize: compact ? 15 : 18, weight: .medium),
        color: mutedNavy.withAlphaComponent(0.78)
    )

    let mediumRect: NSRect
    let smallRect: NSRect
    if compact {
        mediumRect = rectFromTop(
            x: 652,
            top: 116,
            width: 570,
            height: 285,
            canvasHeight: size.height
        )
        smallRect = rectFromTop(
            x: 926,
            top: 340,
            width: 230,
            height: 230,
            canvasHeight: size.height
        )
    } else {
        mediumRect = rectFromTop(
            x: 800,
            top: 176,
            width: 720,
            height: 360,
            canvasHeight: size.height
        )
        smallRect = rectFromTop(
            x: 1150,
            top: 438,
            width: 300,
            height: 300,
            canvasHeight: size.height
        )
    }

    drawImageCard(
        mediumWidget,
        rect: mediumRect,
        cornerRadius: compact ? 28 : 36,
        shadowBlur: compact ? 30 : 40
    )
    drawImageCard(
        smallWidget,
        rect: smallRect,
        cornerRadius: compact ? 32 : 42,
        shadowBlur: compact ? 28 : 36
    )

    context.flushGraphics()
    guard let png = bitmap.representation(
        using: NSBitmapImageRep.FileType.png,
        properties: [NSBitmapImageRep.PropertyKey.compressionFactor: 0.94]
    ) else {
        throw PromoError.pngEncodingFailed
    }
    try png.write(to: outputURL, options: Data.WritingOptions.atomic)
}

let repositoryRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
let assets = repositoryRoot.appendingPathComponent("docs/assets", isDirectory: true)
let background = try loadImage(assets.appendingPathComponent("promo-background.png"))
let appIcon = try loadImage(repositoryRoot.appendingPathComponent(
    "Codex-Quota/Assets.xcassets/AppIcon.appiconset/icon_512x512@2x.png"
))
let mediumWidget = try loadImage(assets.appendingPathComponent("widget-medium.png"))
let smallWidget = try loadImage(assets.appendingPathComponent("widget-small.png"))

let english = PromoCopy(
    eyebrow: "OPEN SOURCE FOR macOS",
    tagline: "Quota at a glance. Privacy by design.",
    meta: "Native macOS · Menu bar · WidgetKit",
    pills: ["5-hour + weekly", "Desktop widgets", "Local-first"]
)

let simplifiedChinese = PromoCopy(
    eyebrow: "开源 · 原生 macOS",
    tagline: "额度一目了然，隐私边界清晰。",
    meta: "原生 macOS · 菜单栏 · WidgetKit",
    pills: ["5 小时 + 每周额度", "桌面小组件", "本机优先"]
)

try renderPromo(
    size: NSSize(width: 1600, height: 800),
    background: background,
    appIcon: appIcon,
    mediumWidget: mediumWidget,
    smallWidget: smallWidget,
    copy: english,
    outputURL: assets.appendingPathComponent("hero-banner.png"),
    compact: false
)

try renderPromo(
    size: NSSize(width: 1600, height: 800),
    background: background,
    appIcon: appIcon,
    mediumWidget: mediumWidget,
    smallWidget: smallWidget,
    copy: simplifiedChinese,
    outputURL: assets.appendingPathComponent("hero-banner-zh.png"),
    compact: false
)

try renderPromo(
    size: NSSize(width: 1280, height: 640),
    background: background,
    appIcon: appIcon,
    mediumWidget: mediumWidget,
    smallWidget: smallWidget,
    copy: english,
    outputURL: assets.appendingPathComponent("github-social-preview.png"),
    compact: true
)

print("Rendered README and GitHub promotional assets in \(assets.path)")
