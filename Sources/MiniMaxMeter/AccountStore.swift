import Foundation
import SwiftUI

@MainActor
final class AccountStore: ObservableObject {
    @Published private(set) var accounts: [Account] = []
    @Published var activeAccountId: String? {
        didSet { UserDefaults.standard.set(activeAccountId, forKey: Self.activeKey) }
    }

    private static let accountsKey = "MiniMaxMeter.accounts.v1"
    private static let activeKey   = "MiniMaxMeter.activeAccountId.v1"

    init() {
        load()
        migrateFromLegacyIfNeeded()
    }

    // MARK: - Public API

    /// 添加新账户。返回新账户 ID，失败返回 nil
    @discardableResult
    func addAccount(cookie: String, displayName: String? = nil) -> Account? {
        let trimmed = cookie.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let groupId = UsageFetcher.extractGroupId(from: trimmed) else {
            return nil
        }
        let id = UUID().uuidString
        // 智能命名：同名 groupId 自动加序号
        var name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if name?.isEmpty ?? true {
            name = defaultName(for: groupId)
        }
        let acc = Account(id: id, displayName: name!, groupId: groupId, createdAt: Date())
        Keychain.saveCookie(trimmed, for: id)
        accounts.append(acc)
        if activeAccountId == nil { activeAccountId = id }
        save()
        return acc
    }

    func removeAccount(_ id: String) {
        guard let idx = accounts.firstIndex(where: { $0.id == id }) else { return }
        Keychain.deleteCookie(for: id)
        accounts.remove(at: idx)
        if activeAccountId == id { activeAccountId = accounts.first?.id }
        save()
    }

    func renameAccount(_ id: String, to newName: String) {
        guard let idx = accounts.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        accounts[idx].displayName = trimmed
        save()
    }

    func setActive(_ id: String) {
        guard accounts.contains(where: { $0.id == id }) else { return }
        activeAccountId = id
    }

    /// 当前激活账户的 cookie
    func activeCookie() -> String? {
        guard let id = activeAccountId else { return nil }
        return Keychain.loadCookie(for: id)
    }

    var hasAnyAccount: Bool { !accounts.isEmpty }
    var activeAccount: Account? {
        guard let id = activeAccountId else { return nil }
        return accounts.first(where: { $0.id == id })
    }

    // MARK: - Private

    private func defaultName(for groupId: String) -> String {
        // 同 groupId 的已经有多少个了，加序号
        let sameCount = accounts.filter { $0.groupId == groupId }.count
        return sameCount == 0 ? "账户 \(accounts.count + 1)" : "账户 \(accounts.count + 1) (\(sameCount + 1))"
    }

    private func save() {
        if let data = try? JSONEncoder().encode(accounts) {
            UserDefaults.standard.set(data, forKey: Self.accountsKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: Self.accountsKey),
           let decoded = try? JSONDecoder().decode([Account].self, from: data) {
            accounts = decoded
        }
        activeAccountId = UserDefaults.standard.string(forKey: Self.activeKey)
    }

    /// 从老的单 cookie Keychain 自动迁移
    private func migrateFromLegacyIfNeeded() {
        // 已有账户就跳过
        guard accounts.isEmpty else { return }
        guard let legacy = Keychain.loadLegacyCookie() else { return }
        if addAccount(cookie: legacy, displayName: "默认账户") != nil {
            Keychain.deleteLegacyCookie()
        }
    }
}
