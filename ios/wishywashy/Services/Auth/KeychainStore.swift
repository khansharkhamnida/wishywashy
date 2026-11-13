//
//  KeychainStore.swift
//  wishywashy
//
//  The only code that touches the Keychain. Tokens go here and nowhere else.
//

import Foundation
import Security

protocol SecureStore: AnyObject {
    func data(forKey key: String) -> Data?
    @discardableResult
    func set(_ data: Data, forKey key: String) -> Bool
    func remove(forKey key: String)
}

final class KeychainStore: SecureStore {
    private let service: String

    init(service: String = (Bundle.main.bundleIdentifier ?? "wishywashy") + ".auth") {
        self.service = service
    }

    func data(forKey key: String) -> Data? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess else { return nil }
        return result as? Data
    }

    @discardableResult
    func set(_ data: Data, forKey key: String) -> Bool {
        let update = SecItemUpdate(baseQuery(key) as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return true }
        guard update == errSecItemNotFound else { return false }
        var add = baseQuery(key)
        add[kSecValueData as String] = data
        // Readable after the first unlock so a refresh can run in the background, and never copied to another device
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
    }

    func remove(forKey key: String) {
        SecItemDelete(baseQuery(key) as CFDictionary)
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: key]
    }
}

/// Keeps the signed-in session in a `SecureStore`
final class AuthSessionStorage {
    static let key = "supabase.session"

    private let store: SecureStore

    init(store: SecureStore = KeychainStore()) {
        self.store = store
    }

    func load() -> AuthSession? {
        guard let data = store.data(forKey: Self.key) else { return nil }
        return try? JSONDecoder().decode(AuthSession.self, from: data)
    }

    func save(_ session: AuthSession) {
        guard let data = try? JSONEncoder().encode(session) else { return }
        store.set(data, forKey: Self.key)
    }

    func clear() {
        store.remove(forKey: Self.key)
    }
}
