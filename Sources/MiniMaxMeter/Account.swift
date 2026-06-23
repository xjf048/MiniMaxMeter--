import Foundation

// MARK: - Account Model

struct Account: Identifiable, Codable, Equatable, Hashable {
    let id: String           // UUID
    var displayName: String  // "工作" / "个人" / 用户自定义
    var groupId: String      // X-Group-Id（从 cookie 提取）
    let createdAt: Date

    var keychainKey: String { "account:\(id)" }
}
