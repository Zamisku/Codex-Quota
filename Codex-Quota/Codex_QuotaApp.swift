import AppKit
import SwiftUI

@main
struct Codex_QuotaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: HostModel

    init() {
        let model = HostModel()
        _model = StateObject(wrappedValue: model)
        AppDelegate.model = model
    }

    var body: some Scene {
        Window("Codex Quota", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 530, idealWidth: 530, maxWidth: 530,
                       minHeight: 450, idealHeight: 450, maxHeight: 450)
                .onOpenURL { url in
                    guard url.scheme?.lowercased() == "codexquota" else { return }
                    Task { await model.refresh(forceWidgetReload: true) }
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("刷新 Codex 额度") {
                    Task { await model.refresh() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }

        MenuBarExtra("Codex Quota", systemImage: "gauge.with.dots.needle.33percent") {
            MenuBarContent(model: model)
        }
    }
}

private struct MenuBarContent: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var model: HostModel

    var body: some View {
        Text(model.menuStatus)
        Divider()
        Button("打开设置") {
            openWindow(id: "main")
            NSApp.activate(ignoringOtherApps: true)
            for window in NSApp.windows where window.title == "Codex Quota" {
                window.deminiaturize(nil)
                window.makeKeyAndOrderFront(nil)
            }
        }
        Button("立即刷新") { Task { await model.refresh() } }
        Button("退出 Codex Quota") { NSApp.terminate(nil) }
    }
}

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    static weak var model: HostModel?

    func applicationWillFinishLaunching(_ notification: Notification) {
        registerURLHandler()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerURLHandler()
        Self.model?.start()
    }

    private func registerURLHandler() {
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:withReplyEvent:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    @objc private func handleGetURL(
        _ event: NSAppleEventDescriptor,
        withReplyEvent replyEvent: NSAppleEventDescriptor
    ) {
        guard let rawURL = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: rawURL),
              url.scheme?.lowercased() == "codexquota" else {
            return
        }
        Task { await Self.model?.refresh(forceWidgetReload: true) }
    }
}
