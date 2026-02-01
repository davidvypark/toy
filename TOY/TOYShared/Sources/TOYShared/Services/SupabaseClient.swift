import Foundation
import Supabase

/// Shared Supabase client instance for all backend operations.
/// This is the single source of truth for Supabase connectivity.
public let supabase: SupabaseClient = {
    let urlString = Configuration.supabaseURL
    let key = Configuration.supabaseAnonKey

    guard let url = URL(string: urlString) else {
        fatalError("Invalid Supabase URL: \(urlString)")
    }

    #if DEBUG
    print("🔧 Supabase URL: \(urlString)")
    print("🔧 Supabase Key: \(key.prefix(20))...")
    #endif

    // Use simple initialization with defaults
    return SupabaseClient(
        supabaseURL: url,
        supabaseKey: key
    )
}()

/// Keychain-based storage for auth tokens (more secure than UserDefaults)
private struct KeychainLocalStorage: AuthLocalStorage {
    private let service = "com.toy.auth"

    func store(key: String, value: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: value
        ]

        // Delete any existing item
        SecItemDelete(query as CFDictionary)

        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    func retrieve(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }

    func remove(key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }

    enum KeychainError: Error {
        case unhandledError(status: OSStatus)
    }
}
