import SwiftUI

/// 永远显示在菜单栏的精简 label
/// 多账户时显示当前账户名前缀：`[工作] 5h 25% / 周 18%`
struct MenuBarLabel: View {
    @ObservedObject var store: UsageStore
    @ObservedObject var accountStore: AccountStore

    var body: some View {
        HStack(spacing: 4) {
            if store.snapshot == nil {
                Image(systemName: "wifi.exclamationmark")
                    .foregroundStyle(.secondary)
                Text("MiniMax").font(.system(size: 12, weight: .medium))
            } else {
                Text(labelText)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
            }
        }
    }

    private var labelText: String {
        guard let s = store.snapshot else { return "—" }
        let h = s.fiveHour.usedPercent
        let w = s.weekly.usedPercent
        let stats = "5h \(h)% / 周 \(w)%"
        // 多账户时加账户名前缀
        if accountStore.accounts.count > 1, let acc = accountStore.activeAccount {
            return "[\(acc.displayName)] \(stats)"
        }
        return stats
    }
}
