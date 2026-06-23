# Changelog

所有值得注意的变更都会记录在这里。版本遵循 [Semantic Versioning](https://semver.org/)。

## [Unreleased]

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
