import AppKit
import SwiftUI
import WidgetKit

private enum PreviewRenderError: Error {
    case imageUnavailable
    case pngEncodingFailed
}

@main
@MainActor
struct WidgetPreviewRenderer {
    static func main() throws {
        let root = URL(
            fileURLWithPath: FileManager.default.currentDirectoryPath,
            isDirectory: true
        )
        let assets = root.appendingPathComponent("docs/assets", isDirectory: true)
        let now = Date()
        let snapshot = ProviderSnapshot(
            plan: "PLUS",
            shortWindow: UsageWindow(
                remainingPercent: 72,
                resetsAt: now.addingTimeInterval(2.5 * 60 * 60),
                windowSeconds: 18_000
            ),
            weeklyWindow: UsageWindow(
                remainingPercent: 84,
                resetsAt: now.addingTimeInterval(4 * 86_400),
                windowSeconds: 604_800
            ),
            resetCredits: 2,
            resetCreditExpirations: [],
            updatedAt: now,
            status: .ok,
            failure: nil
        )

        try render(
            snapshot: snapshot,
            family: .systemSmall,
            pointSize: CGSize(width: 180, height: 180),
            outputURL: assets.appendingPathComponent("widget-small.png")
        )
        try render(
            snapshot: snapshot,
            family: .systemMedium,
            pointSize: CGSize(width: 360, height: 180),
            outputURL: assets.appendingPathComponent("widget-medium.png")
        )

        print("Rendered crystal Small and Medium widget previews in \(assets.path)")
    }

    private static func render(
        snapshot: ProviderSnapshot,
        family: WidgetFamily,
        pointSize: CGSize,
        outputURL: URL
    ) throws {
        let view = QuotaWidgetThemePreview(
            snapshot: snapshot,
            family: family,
            theme: .crystal
        )
        .frame(width: pointSize.width, height: pointSize.height)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(pointSize)
        renderer.scale = 2

        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            throw PreviewRenderError.imageUnavailable
        }
        guard let png = bitmap.representation(
            using: NSBitmapImageRep.FileType.png,
            properties: [NSBitmapImageRep.PropertyKey.compressionFactor: 0.94]
        ) else {
            throw PreviewRenderError.pngEncodingFailed
        }
        try png.write(to: outputURL, options: Data.WritingOptions.atomic)
    }
}
