import SwiftUI
import AppKit

@main
struct MiniMaxMeterApp: App {
    @StateObject private var store = UsageStore()

    init() {
        // 启动前：检测并终止已运行的同程序实例
        Self.enforceSingleInstance()
    }

    /// 单实例检测
    /// 用可执行文件绝对路径匹配（不依赖 bundle ID，swift run / .app 模式都兼容）
    /// - 同一可执行文件被启动多次 → 旧实例被 terminate，新实例继续
    /// - swift run 和 .app 路径不同 → 互不干扰
    static func enforceSingleInstance() {
        let myPID = ProcessInfo.processInfo.processIdentifier
        let myPath = Bundle.main.executablePath ?? ""

        let running = NSWorkspace.shared.runningApplications.filter { app in
            app.processIdentifier != myPID && app.executableURL?.path == myPath
        }

        guard !running.isEmpty else { return }

        // 优雅终止旧实例
        for app in running {
            app.terminate()
        }

        // 等旧实例退出（最多 1.5 秒，每 50ms 检查一次）
        let deadline = Date().addingTimeInterval(1.5)
        for app in running {
            while !app.isTerminated && Date() < deadline {
                Thread.sleep(forTimeInterval: 0.05)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            PopoverView()
                .environmentObject(store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
