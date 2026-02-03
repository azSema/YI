import Foundation
import Security

/// Keychain storage for YI credentials
enum YIKeychain {
    
    private static let service = "com.yi.credentials"
    
    enum Key: String {
        case token
        case tokenSecret
        case userId
        case userJson
    }
    
    // MARK: - Save
    
    static func save(_ value: String, for key: Key) {
        guard let data = value.data(using: .utf8) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        
        SecItemDelete(query as CFDictionary)
        
        var newQuery = query
        newQuery[kSecValueData as String] = data
        
        SecItemAdd(newQuery as CFDictionary, nil)
    }
    
    // MARK: - Load
    
    static func load(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    // MARK: - Delete
    
    static func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue
        ]
        
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Clear All
    
    static func clearAll() {
        for key in [Key.token, .tokenSecret, .userId, .userJson] {
            delete(key)
        }
    }
    
    // MARK: - Has Credentials
    
    static var hasCredentials: Bool {
        load(.token) != nil && load(.tokenSecret) != nil && load(.userId) != nil
    }
}
