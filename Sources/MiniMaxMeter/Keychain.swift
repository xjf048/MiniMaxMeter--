import Foundation
import Security

enum Keychain {
    private static let service = "com.MiniMax.MiniMaxMeter"
    private static let legacyAccount = "session-cookie"  // 旧格式（v1.0~v1.1），首次启动自动迁移

    // MARK: - Per-account (v1.2+)

    static func saveCookie(_ s: String, for accountId: String) {
        let data = Data(s.utf8)
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "account:\(accountId)",
            kSecValueData as String: data
        ]
        SecItemDelete(q as CFDictionary)
        SecItemAdd(q as CFDictionary, nil)
    }

    static func loadCookie(for accountId: String) -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "account:\(accountId)",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let d = item as? Data,
              let s = String(data: d, encoding: .utf8) else { return nil }
        return s
    }

    static func deleteCookie(for accountId: String) {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "account:\(accountId)"
        ]
        SecItemDelete(q as CFDictionary)
    }

    // MARK: - Legacy single-cookie (v1.0~v1.1) —— 一次性迁移用

    static func loadLegacyCookie() -> String? {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: legacyAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let d = item as? Data,
              let s = String(data: d, encoding: .utf8) else { return nil }
        return s
    }

    static func deleteLegacyCookie() {
        let q: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: legacyAccount
        ]
        SecItemDelete(q as CFDictionary)
    }
}
