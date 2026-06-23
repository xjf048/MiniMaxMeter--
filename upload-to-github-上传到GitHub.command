#!/bin/bash
# upload-to-github-上传到GitHub.command
# 第一次上传项目到 GitHub 仓库
#
# 使用方法：
#   1. 在 https://github.com/new 创建一个空仓库（不勾 README/.gitignore/license）
#   2. 双击运行本脚本
#   3. 按提示输入仓库 URL（git@github.com:USER/REPO.git 形式）
#   4. 等 push 完成

set -e
cd "$(dirname "$0")"

echo "========================================"
echo "  MiniMaxMeter 上传到 GitHub"
echo "========================================"
echo ""

# 检查 git 是否安装
if ! command -v git >/dev/null 2>&1; then
    echo "❌ git 未安装"
    echo "   请先运行：xcode-select --install"
    read -p "按回车关闭窗口..."
    exit 1
fi

# 检查 git 用户配置
if ! git config --global user.name >/dev/null 2>&1; then
    echo "⚠️  未配置 git 用户名"
    read -p "请输入你的名字（用于 commit）: " GIT_NAME
    read -p "请输入你的邮箱（用于 commit）: " GIT_EMAIL
    git config --global user.name "$GIT_NAME"
    git config --global user.email "$GIT_EMAIL"
    echo "✅ 已配置"
    echo ""
fi

# 询问仓库 URL
echo "请输入 GitHub 仓库 URL："
echo "  SSH 格式:   git@github.com:用户名/MiniMaxMeter.git"
echo "  HTTPS 格式: https://github.com/用户名/MiniMaxMeter.git"
echo ""
read -p "仓库 URL: " REPO_URL
echo ""

if [ -z "$REPO_URL" ]; then
    echo "❌ URL 不能为空"
    read -p "按回车关闭窗口..."
    exit 1
fi

# 验证 URL 格式
if [[ ! "$REPO_URL" =~ ^(git@github.com:|https://github.com/) ]]; then
    echo "❌ URL 格式不对，应该以 git@github.com: 或 https://github.com/ 开头"
    read -p "按回车关闭窗口..."
    exit 1
fi

# 初始化 git 仓库（如果还没）
if [ ! -d .git ]; then
    echo "==> 初始化 git 仓库..."
    git init
    git branch -m main
else
    echo "==> 已存在 git 仓库"
    # 确保分支叫 main
    CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")
    if [ "$CURRENT_BRANCH" != "main" ]; then
        git branch -m main 2>/dev/null || true
    fi
fi

# 检查敏感信息（防御性）
echo "==> 检查是否有敏感信息..."
if grep -rn "eyJhbGciOiJIUzI1NiI" Sources/ 2>/dev/null; then
    echo ""
    echo "❌ 警告：源码里发现疑似 JWT token！"
    echo "   请删除后再 push"
    read -p "按回车关闭窗口..."
    exit 1
fi
echo "✅ 无敏感信息"
echo ""

# 添加远程
if git remote get-url origin >/dev/null 2>&1; then
    echo "==> remote origin 已存在，更新 URL..."
    git remote set-url origin "$REPO_URL"
else
    echo "==> 添加 remote origin..."
    git remote add origin "$REPO_URL"
fi

# 添加并提交
echo "==> 添加文件..."
git add -A

# 检查有没有要提交的
if git diff --cached --quiet; then
    echo "⚠️  没有要提交的变更（可能已经提交过了）"
else
    echo "==> 提交..."
    git commit -m "Initial commit: MiniMaxMeter v1.0.0

macOS 菜单栏小工具，实时监控 platform.minimaxi.com Token Plan 用量。

- 菜单栏显示 5h 限额 + 周限额已用百分比
- 点击展开进度条 + 倒计时
- Popover 内嵌设置（Cookie / 刷新频率 / 清除）
- Cookie 存 macOS Keychain
- 一键安装脚本 install-安装.command"
fi

# Push
echo "==> 推送到 GitHub..."
git push -u origin main

echo ""
echo "✅ 上传完成！"
echo "   访问你的仓库：$(echo "$REPO_URL" | sed -E 's/\.git$//' | sed 's|git@github.com:|https://github.com/|')"
echo ""
read -p "按回车关闭窗口..."
