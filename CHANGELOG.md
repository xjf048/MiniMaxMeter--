# Changelog

所有值得注意的变更都会记录在这里。版本遵循 [Semantic Versioning](https://semver.org/)。

## [Unreleased]

## [1.2.0] - 2026-06-23

### ✨ 新增

- **多账户支持**（v2.1）：保存多个 minimaxi 账号 Cookie，一键切换
  - 设置面板「账户」section：列表、添加、切换、删除
  - 菜单栏 label 多账户时显示前缀：`[工作] 5h 25% / 周 18%`
  - **自动迁移**：老用户单 cookie 自动迁移到新格式，零配置升级
- **限额阈值通知**（v2.3）：5h / 周限额跨过 50/75/90% 时弹 macOS 通知
  - 首次启动请求通知权限
  - 每个窗口每个阈值只通知一次（避免刷屏）
  - 窗口重置时清通知状态（新窗口重新触发）
  - 设置区可配置启用哪些阈值
- **开机自启**（v2.4）：用户登录 Mac 后自动启动
  - macOS 13+ 官方 `SMAppService.mainApp` API
  - 设置面板 toggle，状态实时同步

### 🔧 重构
- 拆分 `Keychain`：单 cookie → per-account key（`account:<uuid>`）
- `AccountStore` 独立管理账户列表 + 活跃账户（UserDefaults 持久化）
- `UsageStore` 改为接受 `AccountStore` 注入，切换账户时自动重建 fetcher

## [1.1.1] - 2026-06-23

### 🐛 Bug 修复
- **首次启动不会自动刷新**：之前 `UsageStore.start()` 从未被调用，导致菜单栏永远显示 `0% / 0%`，必须手动点刷新
- 现在 `UsageStore.init()` 自动调用 `start()`，启动后 1 秒内自动拉数据

### 📚 文档
- README 新增「故障排查 / Troubleshooting」章节

## [1.1.0] - 2026-06-23

### ✨ 新增
- **单实例检测**：启动时自动检测并终止已运行的同程序实例
- 启动后**不需要终端保持运行**（用 .app 双击启动即独立运行）

### 🔧 优化
- 单实例匹配用可执行文件绝对路径（不依赖 bundle ID，兼容 swift run 模式）

## [1.0.0] - 2026-06-23

### ✨ 新增
- 菜单栏常驻显示 5h 限额 + 周限额已用百分比
- 点击菜单栏弹出小卡片（5h / 周进度条 + 倒计时）
- Popover 内嵌设置区（填 Cookie / 选刷新频率 / 清除）
- Cookie 存到 macOS Keychain
- 接口失败自动降级到本地缓存
- 401/403 自动清理 Keychain
- 颜色状态：0–30% 绿 / 30–70% 橙 / 70%+ 红
- 倒计时实时刷新（每秒）

### 🔧 工具
- `install-安装.command` — 一键安装 + 桌面替身
- `start-启动.command` — 命令行启动
- `uninstall-卸载.command` — 卸载清理
- GitHub Actions 自动 build 验证

### 📚 文档
- README 中英双语
- 项目总结
- CONTRIBUTING / Issue 模板
