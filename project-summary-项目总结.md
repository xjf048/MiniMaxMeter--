# MiniMaxMeter — 迷你魔 Token 用量监控

macOS 菜单栏小工具，实时监控 platform.minimaxi.com 的 Token Plan 用量。

## 目标

解决「频繁打开网页看自己 token 还剩多少」的痛点。桌面上看一眼菜单栏就知道。

## 核心指标

来自 platform.minimaxi.com/console/usage 页面：
- **5h 限额**（100% 总额度，已用百分比 + 倒计时）
- **周限额**（150% 总额度，含 50% boost，已用百分比 + 倒计时）

## 选型

| 维度 | 决策 | 原因 |
|---|---|---|
| 形态 | macOS 菜单栏 (MenuBarExtra) | "桌面小卡片" 语义最贴，状态栏永远可见 |
| UI 框架 | SwiftUI (macOS 13+) | 原生体验，0 运行时依赖 |
| 数据源 | 复用浏览器 Cookie | 准确率 100% 与官网一致；API Key 只能反推自己跑的那部分 |
| 存储 | macOS Keychain | Cookie 敏感，不明文落盘 |
| 缓存 | UserDefaults (snapshot) | 离线 / 接口失败时降级显示 |
| 刷新 | Timer.publish 60s | 限额窗口以小时计，分钟级足够 |

## 数据源（接口抓包）

通过 Chrome DevTools 抓 platform.minimaxi.com/console/usage 的网络请求：

| 字段 | 值 |
|---|---|
| Endpoint | `https://www.minimaxi.com/v1/api/openplatform/coding_plan/remains` |
| Method | GET |
| Status | 200 |
| 必带 header | Cookie, Origin, Referer, X-Group-Id, User-Agent |

X-Group-Id 由代码从 Cookie 字符串里 `minimax_group_id_v2=...` 自动正则提取，**不需用户单独配置**。

## 字段映射

| 截图显示 | JSON 字段 | 说明 |
|---|---|---|
| 5h 限额 | `model_remains[model_name="general"]` | 数组里第 0 个 |
| 总额度 100% | `current_interval_remaining_percent` 满血值 = 100 | 已用 = 100 - remaining |
| 已用 0%/25% | `100 - current_interval_remaining_percent` | |
| 5h 倒计时 | `remains_time` (毫秒) | |
| 周限额 | 同上对象里的周字段 | |
| 总额度 150% | `weekly_boost_permille / 10` | 1500‰ = 150% |
| 已用 24%/27% | `(weekly_boost_permille/10) * (1 - current_weekly_remaining_percent/100)` | |
| 周倒计时 | `weekly_remains_time` (毫秒) | |

## 文件结构

```
MiniMaxMeter/
├── project-summary-项目总结.md     (本文件)
├── README.md                       (运行/抓包指南)
├── Package.swift                   (SPM 清单)
└── Sources/MiniMaxMeter/
    ├── App.swift                   @main, MenuBarExtra 入口
    ├── MenuBarLabel.swift          菜单栏显示的文字
    ├── PopoverView.swift           点击展开的小卡片 + 内嵌设置
    ├── UsageModel.swift            JSON 解码 + Quota/Snapshot 领域模型
    ├── UsageFetcher.swift          网络层 (actor)，自动提取 X-Group-Id
    ├── UsageStore.swift            @MainActor ObservableObject + 定时刷新
    ├── Keychain.swift              Cookie 安全存取
    └── Cache.swift                 离线 fallback (UserDefaults)
```

## 编译运行

```bash
swift build --package-path ~/AI-Hub/projects/MiniMaxMeter
swift run  --package-path ~/AI-Hub/projects/MiniMaxMeter
```

需要 macOS 13+ 和 Xcode Command Line Tools。

## 配置 Cookie

1. Chrome 打开 https://platform.minimaxi.com/console/usage 并登录
2. F12 → Network → F5 刷新
3. Filter 框输入 `usage`，剩两条
4. 点 **`usage`**（不是 usage_summary）
5. Headers tab → 找 **`cookie:`** 行（全部小写）→ 右键 Copy value
6. 菜单栏点 `5h X%` → 点「⚙ 设置」→ 粘到输入框 → 保存

## 状态色规则

- 已用 0–30% → 绿
- 已用 30–70% → 橙
- 已用 70%+ → 红
- 接口失败 → 灰
- status=3 → 灰（disabled）

## 失败处理

- HTTP 401/403 → 自动清 Keychain，提示重新登录
- 网络断开 → 显示最后一次成功 snapshot + 红色错误提示
- JSON 解析失败 → 提示并保留上次显示

## v2 想法（未实现）

- 多账户支持（切换不同 minimaxi 账号）
- 用量趋势 sparkline（基于 `usage_summary` 的 `daily_token_usage` 数组）
- 限额阈值提醒（macOS 通知中心）
- 开机自启（LaunchAgent）
- 打包为 .app + DMG 分发

## 后续维护注意

如果 minimaxi 接口改版：
1. 改 `UsageFetcher.swift:11` 的 endpoint
2. 改 `UsageModel.swift` 里的 `CodingKeys`（如果字段名变了）
3. 改完后 `swift build` 验证

## 与同类型项目的区别

GitHub 上**没有**现成的、专门针对 minimaxi 开放平台的用量监控项目（搜索过 `MiniMax token usage monitor`、`MiniMax API usage monitor`、`Claude usage monitor mac menubar` 等关键词）。同类可参考的只有 OpenAI / Anthropic / Cursor 用量监控，但认证和接口完全不同，**不能直接复用**。
