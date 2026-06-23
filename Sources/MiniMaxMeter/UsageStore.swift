import Foundation
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var lastError: String?
    @Published var refreshInterval: TimeInterval = 60
    @Published var enabledThresholds: Set<Int> = [50, 75, 90] { didSet { UserDefaults.standard.set(Array(enabledThresholds), forKey: Self.thresholdsKey) } }

    let accountStore: AccountStore

    private var fetcher: UsageFetcher?
    private var timer: Timer?
    private var lastActiveAccountId: String?
    private var lastUsedPercent: [String: Int] = [:]
    private var lastNotified: [String: Set<Int>] = [:]
    private var lastResetAt: [String: Date] = [:]

    private static let thresholdsKey = "MiniMaxMeter.enabledThresholds.v1"

    init(accountStore: AccountStore) {
        self.accountStore = accountStore
        if let arr = UserDefaults.standard.array(forKey: Self.thresholdsKey) as? [Int] {
            self.enabledThresholds = Set(arr)
        }
        start()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 100_000_000)
            await Notifier.shared.requestPermission()
            await observeAccountChanges()
        }
    }

    var hasCookie: Bool { accountStore.activeCookie() != nil }

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

    // MARK: - Lifecycle

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

    // MARK: - Account helpers

    /// 添加新账户并切换为活跃
    @discardableResult
    func addAccount(cookie: String, displayName: String? = nil) -> Account? {
        let acc = accountStore.addAccount(cookie: cookie, displayName: displayName)
        if acc != nil {
            accountStore.setActive(acc!.id)
            fetcher = nil   // 重建 fetcher
            Task { await refresh() }
        }
        return acc
    }

    func removeAccount(_ id: String) {
        accountStore.removeAccount(id)
        // 如果删的是活跃账户，切换 fetcher
        if accountStore.activeAccountId != lastActiveAccountId {
            fetcher = nil
            Task { await refresh() }
        }
    }

    func switchActiveAccount(_ id: String) {
        accountStore.setActive(id)
        fetcher = nil
        Task { await refresh() }
    }

    // MARK: - 刷新

    private func schedule() {
        timer?.invalidate()
        Task { await refresh() }
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { await self?.refresh() }
        }
    }

    func refresh() async {
        let currentActive = accountStore.activeAccountId
        lastActiveAccountId = currentActive

        guard let cookie = accountStore.activeCookie(), !cookie.isEmpty else {
            self.lastError = "未配置 Cookie（点菜单栏 → 设置 → 添加账户）"
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
            checkThresholds(for: s)
        } catch {
            self.lastError = error.localizedDescription
            // 失败时降级用缓存
            if self.snapshot == nil { self.snapshot = Cache.load() }
        }
    }

    // MARK: - 阈值通知

    private func checkThresholds(for s: UsageSnapshot) {
        checkOne(quota: s.fiveHour, kind: "fiveHour", displayName: "5h")
        checkOne(quota: s.weekly,   kind: "weekly",   displayName: "周")
    }

    private func checkOne(quota: Quota, kind: String, displayName: String) {
        // 检测窗口重置（resetAt 变了 → 新窗口 → 清状态）
        if let prev = lastResetAt[kind], prev != quota.resetAt {
            lastUsedPercent[kind] = nil
            lastNotified[kind] = nil
        }
        lastResetAt[kind] = quota.resetAt

        let current = Int(quota.usedFraction * 100)
        let prev = lastUsedPercent[kind] ?? 0
        var notified = lastNotified[kind] ?? []

        for threshold in enabledThresholds.sorted() {
            // 跨过：上 < 阈值，当前 >= 阈值，且还没通知过
            if prev < threshold && current >= threshold && !notified.contains(threshold) {
                Notifier.shared.notify(
                    title: "MiniMax \(displayName) 限额提醒",
                    body: "已用 \(current)%，请注意用量",
                    identifier: "MiniMaxMeter.\(kind).\(threshold)"
                )
                notified.insert(threshold)
            }
        }
        lastUsedPercent[kind] = current
        lastNotified[kind] = notified
    }

    /// 监控 activeAccountId 变化
    private func observeAccountChanges() async {
        while !Task.isCancelled {
            if accountStore.activeAccountId != lastActiveAccountId {
                fetcher = nil
                await refresh()
            }
            try? await Task.sleep(nanoseconds: 500_000_000)  // 每 0.5s 检查
        }
    }
}
