import Foundation
import Security

/// A secure keychain storage helper for sensitive data like API keys
class KeychainHelper {

    // MARK: - Constants

    /// Service name used for keychain storage
    private static let serviceName = "com.desktoppet.app"

    /// Account identifier for the API key
    private static let apiAccount = "ai_api_key"

    // MARK: - Errors

    enum KeychainError: Error, LocalizedError {
        case itemNotFound
        case duplicateEntry
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .itemNotFound:
                return "Item not found in keychain"
            case .duplicateEntry:
                return "Duplicate entry found in keychain"
            case .unexpectedStatus(let status):
                return "Unexpected keychain status: \(status)"
            }
        }
    }

    // MARK: - Public Methods

    /// Reads the API key from keychain
    /// - Returns: The API key string, or nil if not found
    static func readApiKey() -> String? {
        do {
            return try read(service: serviceName, account: apiAccount)
        } catch {
            print("Keychain read error: \(error.localizedDescription)")
            return nil
        }
    }

    /// Saves the API key to keychain
    /// - Parameter key: The API key string to save
    /// - Returns: True if successful, false otherwise
    @discardableResult
    static func saveApiKey(_ key: String) -> Bool {
        do {
            try save(service: serviceName, account: apiAccount, value: key)
            return true
        } catch {
            print("Keychain save error: \(error.localizedDescription)")
            return false
        }
    }

    /// Deletes the API key from keychain
    /// - Returns: True if successful, false otherwise
    @discardableResult
    static func deleteApiKey() -> Bool {
        do {
            try delete(service: serviceName, account: apiAccount)
            return true
        } catch {
            print("Keychain delete error: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Generic Keychain Operations

    /// Generic read operation for keychain
    /// - Parameters:
    ///   - service: The service identifier
    ///   - account: The account identifier
    /// - Returns: The stored string value
    /// - Throws: KeychainError if operation fails
    static func read(service: String, account: String) throws -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status != errSecItemNotFound else {
            throw KeychainError.itemNotFound
        }

        guard status == errSecSuccess,
              let resultDict = result as? [String: Any],
              let data = resultDict[kSecValueData as String] as? Data,
              let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedStatus(status)
        }

        return string
    }

    /// Generic save operation for keychain
    /// - Parameters:
    ///   - service: The service identifier
    ///   - account: The account identifier
    ///   - value: The string value to save
    /// - Throws: KeychainError if operation fails
    static func save(service: String, account: String, value: String) throws {
        let data = value.data(using: .utf8)!

        // First, try to update existing item
        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let updateAttributes: [String: Any] = [
            kSecValueData as String: data
        ]

        var status = SecItemUpdate(updateQuery as CFDictionary, updateAttributes as CFDictionary)

        if status == errSecItemNotFound {
            // Item doesn't exist, add it
            let addQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account,
                kSecValueData as String: data,
                kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked
            ]

            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw KeychainError.unexpectedStatus(status)
        }
    }

    /// Generic delete operation for keychain
    /// - Parameters:
    ///   - service: The service identifier
    ///   - account: The account identifier
    /// - Throws: KeychainError if operation fails
    static func delete(service: String, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(status)
        }
    }
}
