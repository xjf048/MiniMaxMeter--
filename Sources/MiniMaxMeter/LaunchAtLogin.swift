import Foundation
import ServiceManagement

/// 开机自启（macOS 13+）
/// 用 `SMAppService.mainApp.register/unregister`，用户登录 Mac 时自动启动。
/// 注意：仅在 .app bundle 模式下有效（swift run 模式无效）
@MainActor
enum LaunchAtLogin {
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            if SMAppService.mainApp.status != .enabled {
                try SMAppService.mainApp.register()
            }
        } else {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        }
    }
}
