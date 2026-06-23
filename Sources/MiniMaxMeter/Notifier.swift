import Foundation
import UserNotifications
import AppKit

@MainActor
final class Notifier {
    static let shared = Notifier()

    private let center = UNUserNotificationCenter.current()
    private(set) var permissionGranted: Bool = false

    private init() {
        Task { await refreshPermissionStatus() }
    }

    /// 首次启动时调用，请求通知权限
    func requestPermission() async {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            self.permissionGranted = granted
        } catch {
            self.permissionGranted = false
        }
    }

    /// 重新查询权限状态（设置面板里需要）
    func refreshPermissionStatus() async {
        let settings = await center.notificationSettings()
        self.permissionGranted = settings.authorizationStatus == .authorized
    }

    /// 发送通知
    func notify(title: String, body: String, identifier: String? = nil) {
        guard permissionGranted else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let req = UNNotificationRequest(
            identifier: identifier ?? UUID().uuidString,
            content: content,
            trigger: nil   // 立即发送
        )
        center.add(req) { _ in }
    }

    /// 打开系统通知设置
    static func openSystemSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
            NSWorkspace.shared.open(url)
        }
    }
}
