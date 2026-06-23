import SwiftUI
import AppKit

@main
struct MiniMaxMeterApp: App {
    @StateObject private var accountStore: AccountStore
    @StateObject private var store: UsageStore
    @AppStorage("MiniMaxMeter.appearance") private var appearance: String = "system"   // system / light / dark

    init() {
        Self.enforceSingleInstance()
        let accounts = AccountStore()
        _accountStore = StateObject(wrappedValue: accounts)
        _store = StateObject(wrappedValue: UsageStore(accountStore: accounts))
    }

    /// 单实例检测
    static func enforceSingleInstance() {
        let myPID = ProcessInfo.processInfo.processIdentifier
        let myPath = Bundle.main.executablePath ?? ""

        let running = NSWorkspace.shared.runningApplications.filter { app in
            app.processIdentifier != myPID && app.executableURL?.path == myPath
        }

        guard !running.isEmpty else { return }

        for app in running { app.terminate() }

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
                .environmentObject(accountStore)
                .environmentObject(store)
                .preferredColorScheme(colorScheme)
        } label: {
            MenuBarLabel(store: store, accountStore: accountStore)
        }
        .menuBarExtraStyle(.window)
    }

    private var colorScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark":  return .dark
        default:      return nil   // 跟随系统
        }
    }
}
