import Foundation
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var lastError: String?
    @Published var refreshInterval: TimeInterval = 60

    private var fetcher: UsageFetcher?
    private var timer: Timer?

    init() {
        // 初始化时立即开始定时刷新（之前 bug：start() 从未被调用，所以菜单栏永远 0%）
        start()
    }

    var hasCookie: Bool { Keychain.loadCookie() != nil }

    /// 5h 限额颜色
    var fiveHourColor: Color {
        guard let s = snapshot else { return .secondary }
        if !s.fiveHour.isActive { return .secondary }
        switch s.fiveHour.usedFraction {
        case ..<0.30: return .green
        case ..<0.70: return .orange
        case ..<0.90: return .red
        default:      return .red
        }
    }

    /// 周限额颜色
    var weeklyColor: Color {
        guard let s = snapshot else { return .secondary }
        if !s.weekly.isActive { return .secondary }
        switch s.weekly.usedFraction {
        case ..<0.30: return .green
        case ..<0.70: return .orange
        case ..<0.90: return .red
        default:      return .red
        }
    }

    var statusText: String {
        if let s = snapshot {
            return "5h 已用 \(s.fiveHour.usedPercent)% · 周已用 \(s.weekly.usedPercent)%"
        }
        return lastError ?? "未配置"
    }

    func start() {
        schedule()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func restart() {
        stop()
        start()
    }

    func setCookie(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Keychain.saveCookie(trimmed)
        restart()
    }

    func clearCookie() {
        Keychain.deleteCookie()
        fetcher = nil
        snapshot = nil
        lastError = "Cookie 已清除"
        stop()
    }

    private func schedule() {
        timer?.invalidate()
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func refresh() async {
        guard let cookie = Keychain.loadCookie(), !cookie.isEmpty else {
            self.lastError = "未配置 Cookie（点菜单栏 → 设置）"
            self.snapshot = Cache.load()
            return
        }

        // 每次重建 fetcher 以应用新 cookie
        if fetcher == nil {
            fetcher = UsageFetcher(cookie: cookie)
        }

        do {
            let s = try await fetcher!.fetch()
            self.snapshot = s
            self.lastError = nil
            Cache.save(s)
        } catch {
            self.lastError = error.localizedDescription
            // 失败时降级用缓存
            if self.snapshot == nil { self.snapshot = Cache.load() }
            // 401 直接清理
            if case FetchError.unauthorized = error {
                clearCookie()
            }
        }
    }
}
