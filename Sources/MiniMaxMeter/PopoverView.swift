import SwiftUI

struct PopoverView: View {
    @EnvironmentObject var store: UsageStore
    @EnvironmentObject var accountStore: AccountStore

    @State private var now = Date()
    @State private var tickTimer: Timer?
    @State private var showSettings: Bool = false
    @State private var showAddForm: Bool = false
    @State private var newCookie: String = ""
    @State private var newName: String = ""
    @State private var addError: String?
    @State private var notifPermissionGranted: Bool = false

    @State private var launchAtLogin: Bool = LaunchAtLogin.isEnabled
    @AppStorage("MiniMaxMeter.appearance") private var appearance: String = "system"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            if let s = store.snapshot {
                QuotaRow(title: "5h 限额", quota: s.fiveHour, color: store.fiveHourColor)
                QuotaRow(title: "周限额", quota: s.weekly, color: store.weeklyColor)
            } else {
                placeholder
            }

            // 用量趋势 sparkline
            if !store.dailyUsage.isEmpty {
                Divider()
                TrendChart(dailyUsage: store.dailyUsage)
            }

            if let err = store.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            }

            if showSettings {
                Divider()
                settingsSection
            }

            Divider()
            toolbar
        }
        .padding(16)
        .frame(width: 380)
        .onAppear {
            startTicking()
            if !store.hasCookie { showSettings = true }   // 首次没账户自动展开
            applyAppearance(appearance)                    // 应用外观
            Task { @MainActor in
                await Notifier.shared.refreshPermissionStatus()
                notifPermissionGranted = Notifier.shared.permissionGranted
            }
        }
        .onDisappear { stopTicking() }
        .onChange(of: appearance) { newValue in
            applyAppearance(newValue)                       // picker 变化时立即应用
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("MiniMax Token").font(.headline)
            Spacer()
            if let s = store.snapshot {
                Text("更新于 \(s.fetchedAt, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Placeholder

    private var placeholder: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("还没有数据").font(.subheadline.bold())
            Text("展开「设置」→ 添加 Cookie 字符串")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Settings (inline)

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 账户列表
            accountListSection

            // 开机自启
            Toggle(isOn: $launchAtLogin) {
                Label("开机自动启动", systemImage: "powerplug.fill")
                    .font(.caption)
            }
            .toggleStyle(.switch)
            .controlSize(.small)
            .onChange(of: launchAtLogin) { newValue in
                do {
                    try LaunchAtLogin.setEnabled(newValue)
                } catch {
                    launchAtLogin = LaunchAtLogin.isEnabled  // 回滚
                }
            }

            // 外观
            HStack {
                Text("外观").font(.caption.bold())
                Picker("外观", selection: $appearance) {
                    Text("跟随系统").tag("system")
                    Text("浅色").tag("light")
                    Text("深色").tag("dark")
                }
                .pickerStyle(.segmented)
                .controlSize(.small)
            }

            // 阈值提醒
            thresholdSection

            Divider()

            // 刷新频率
            Text("刷新频率").font(.caption.bold())
            Picker("刷新频率", selection: $store.refreshInterval) {
                Text("30 秒").tag(TimeInterval(30))
                Text("1 分钟").tag(TimeInterval(60))
                Text("2 分钟").tag(TimeInterval(120))
                Text("5 分钟").tag(TimeInterval(300))
            }
            .pickerStyle(.segmented)
            .onChange(of: store.refreshInterval) { _ in store.restart() }
        }
    }

    private var accountListSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("账户").font(.caption.bold())
                Spacer()
                if !showAddForm {
                    Button {
                        showAddForm = true
                    } label: {
                        Label("添加", systemImage: "plus")
                            .labelStyle(.titleAndIcon)
                            .font(.caption)
                    }
                    .controlSize(.small)
                }
            }

            if accountStore.accounts.isEmpty {
                Text("还没有账户，请添加").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(accountStore.accounts) { acc in
                    AccountRow(
                        account: acc,
                        isActive: acc.id == accountStore.activeAccountId,
                        onActivate: { store.switchActiveAccount(acc.id) },
                        onDelete: {
                            store.removeAccount(acc.id)
                        }
                    )
                }
            }

            if showAddForm {
                addAccountForm
            }
        }
    }

    private var addAccountForm: some View {
        VStack(alignment: .leading, spacing: 6) {
            TextField("账户名（选填，如「工作」「个人」）", text: $newName)
                .textFieldStyle(.roundedBorder)
            SecureField("粘贴 cookie 值（不含 cookie: 前缀）", text: $newCookie)
                .textFieldStyle(.roundedBorder)
            if let err = addError {
                Text(err).font(.caption).foregroundStyle(.red)
            }
            HStack {
                Button("保存为新账户") { commitNewAccount() }
                    .disabled(newCookie.isEmpty)
                Button("取消") {
                    showAddForm = false
                    newCookie = ""
                    newName = ""
                    addError = nil
                }
                .foregroundStyle(.secondary)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }

    private func commitNewAccount() {
        let result = store.addAccount(cookie: newCookie, displayName: newName.isEmpty ? nil : newName)
        if result == nil {
            addError = "Cookie 无效（找不到 minimax_group_id_v2）"
            return
        }
        addError = nil
        newCookie = ""
        newName = ""
        showAddForm = false
    }

    // MARK: - 阈值提醒 UI

    private var thresholdSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("限额阈值提醒").font(.caption.bold())
            HStack(spacing: 12) {
                ForEach([50, 75, 90], id: \.self) { t in
                    Toggle(isOn: thresholdBinding(t)) {
                        Text("\(t)%").font(.caption.monospacedDigit())
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.mini)
                }
            }
            if !notifPermissionGranted {
                Button {
                    Notifier.openSystemSettings()
                } label: {
                    Label("通知权限未开启，点这里去系统设置", systemImage: "bell.slash")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func thresholdBinding(_ t: Int) -> Binding<Bool> {
        Binding(
            get: { store.enabledThresholds.contains(t) },
            set: { isOn in
                if isOn { store.enabledThresholds.insert(t) }
                else    { store.enabledThresholds.remove(t) }
            }
        )
    }

    // MARK: - Toolbar

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                Task { await store.refresh() }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .controlSize(.small)

            Button {
                showSettings.toggle()
            } label: {
                Label(showSettings ? "收起" : "设置", systemImage: showSettings ? "chevron.up" : "gear")
            }
            .controlSize(.small)

            Spacer()

            Button {
                if let url = URL(string: "https://platform.minimaxi.com/console/usage") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                Label("打开网页", systemImage: "safari")
            }
            .controlSize(.small)

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
            }
            .controlSize(.small)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Ticking

    private func startTicking() {
        now = Date()
        tickTimer?.invalidate()
        tickTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            now = Date()
        }
    }

    private func stopTicking() {
        tickTimer?.invalidate()
        tickTimer = nil
    }
}

// MARK: - AccountRow

struct AccountRow: View {
    let account: Account
    let isActive: Bool
    let onActivate: () -> Void
    let onDelete: () -> Void

    private func expiryBadge(for acc: Account) -> (text: String, color: Color)? {
        guard let exp = acc.cookieExpiresAt else { return nil }
        let days = JWT.daysUntilExpiration(exp)
        let formatter = DateFormatter()
        formatter.dateFormat = "M月d日"
        formatter.locale = Locale(identifier: "zh_CN")
        let dateStr = formatter.string(from: exp)

        if days < 0 { return ("⏰ 已过期", .red) }
        if days == 0 { return ("⏰ 今天过期", .red) }
        if days == 1 { return ("⏰ 明天过期", .orange) }
        if days <= 3 { return ("⏰ \(days) 天后", .orange) }
        if days <= 14 { return ("📅 \(dateStr)（\(days) 天）", .secondary) }
        // 始终显示到期日（> 14 天也显示），低权重让用户知道大致什么时候过期
        return ("📅 \(dateStr)", .secondary)
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(isActive ? Color.green : Color.secondary)
                .font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(account.displayName).font(.caption)
                    if let badge = expiryBadge(for: account) {
                        Text(badge.text)
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(badge.color)
                    }
                }
                Text("组: \(account.groupId)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            if !isActive {
                Button("切换", action: onActivate)
                    .controlSize(.mini)
                    .buttonStyle(.borderless)
            }
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption2)
            }
            .controlSize(.mini)
            .buttonStyle(.borderless)
            .foregroundStyle(.red)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - QuotaRow

struct QuotaRow: View {
    let title: String
    let quota: Quota
    let color: Color

    private var liveRemaining: TimeInterval {
        max(0, quota.resetAt.timeIntervalSinceNow)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline.bold())
                Spacer()
                Text("总额度 \(quota.totalPercent)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(2, geo.size.width * quota.usedFraction))
                }
            }
            .frame(height: 8)
            HStack {
                Text("已用 \(quota.usedPercent)%")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(Quota.format(remainingSeconds: liveRemaining)) 后重置")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
