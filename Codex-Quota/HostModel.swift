import Foundation
import ServiceManagement
import WidgetKit

@MainActor
final class HostModel: ObservableObject {
    @Published private(set) var snapshot = SharedSnapshotStore.load()
    @Published private(set) var isLoading = false
    @Published private(set) var launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    @Published private(set) var notice: String? = SMAppService.mainApp.status == .requiresApproval
        ? "登录启动等待批准；请前往“系统设置 → 通用 → 登录项”允许 Codex Quota。"
        : nil

    private let service = CodexQuotaService()
    private var refreshLoop: Task<Void, Never>?
    private var lastWidgetReloadAt: Date?

    init(autoStart: Bool = true) {
        guard autoStart else { return }
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.start()
        }
    }

    var menuStatus: String {
        guard let short = snapshot?.shortWindow else { return "额度暂不可用" }
        return "5 小时剩余 \(Int(short.remainingPercent.rounded()))%"
    }

    func start() {
        guard refreshLoop == nil else { return }
        refreshLoop = Task { [weak self] in
            guard let self else { return }
            await refresh(forceWidgetReload: true)
            while !Task.isCancelled {
                do { try await Task.sleep(nanoseconds: nextRefreshDelayNanoseconds) }
                catch { return }
                await refresh(forceWidgetReload: false)
            }
        }
    }

    func refresh(forceWidgetReload: Bool = true) async {
        guard !isLoading else { return }
        isLoading = true
        notice = nil
        let previous = snapshot
        let incoming = await service.fetchSnapshot()
        let value: ProviderSnapshot
        if incoming.status != .ok,
           !incoming.failure.isAuthenticationFailure,
           let current = SharedSnapshotStore.load(),
           current.shortWindow != nil,
           Date().timeIntervalSince(current.updatedAt) < 30 * 60,
           let failure = incoming.failure {
            value = current.markedStale(with: failure)
        } else {
            value = incoming
        }
        do {
            try SharedSnapshotStore.save(value)
            snapshot = value
            let now = Date()
            let reloadIsDue = lastWidgetReloadAt.map { now.timeIntervalSince($0) >= 30 * 60 } ?? true
            if forceWidgetReload || reloadIsDue || previous?.status != value.status {
                WidgetCenter.shared.reloadTimelines(ofKind: CodexQuotaWidgetKind.value)
                lastWidgetReloadAt = now
            }
        } catch {
            snapshot = value
            notice = "App Group 快照写入失败，请检查两个 Target 的签名与 App Groups capability。"
        }
        isLoading = false
    }

    private var nextRefreshDelayNanoseconds: UInt64 {
        switch snapshot?.failure {
        case .rateLimited, .loginNotFound, .loginExpired, .invalidLogin:
            return 1_800_000_000_000
        default:
            return 900_000_000_000
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
            let status = SMAppService.mainApp.status
            launchAtLoginEnabled = status == .enabled
            notice = status == .requiresApproval
                ? "登录启动等待批准；请前往“系统设置 → 通用 → 登录项”允许 Codex Quota。"
                : nil
        } catch {
            launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
            notice = "无法更改登录启动设置；请先将应用安装到“应用程序”文件夹。"
        }
    }
}

enum CodexQuotaWidgetKind {
    static let value = "com.Zamisku.Codex-Quota.quota"
}

private extension Optional where Wrapped == QuotaFailure {
    var isAuthenticationFailure: Bool { self?.isAuthenticationFailure ?? false }
}
