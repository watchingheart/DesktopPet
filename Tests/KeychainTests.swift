#!/usr/bin/env swift

import Foundation
import Security

// This is a simple test script to verify Keychain operations
// Run with: swift Tests/KeychainTests.swift

print("Testing KeychainHelper...")

// Test 1: Save an API key
print("\n1. Testing saveApiKey...")
let testKey = "test-api-key-12345"
if saveApiKey(testKey) {
    print("   Successfully saved API key")
} else {
    print("   Failed to save API key")
    exit(1)
}

// Test 2: Read the API key
print("\n2. Testing readApiKey...")
if let readKey = readApiKey() {
    if readKey == testKey {
        print("   Successfully read API key: \(readKey)")
    } else {
        print("   ERROR: Read key doesn't match! Expected: \(testKey), Got: \(readKey)")
        exit(1)
    }
} else {
    print("   Failed to read API key")
    exit(1)
}

// Test 3: Update the API key
print("\n3. Testing update (save new key)...")
let updatedKey = "updated-api-key-67890"
if saveApiKey(updatedKey) {
    print("   Successfully updated API key")
} else {
    print("   Failed to update API key")
    exit(1)
}

// Test 4: Verify the updated key
print("\n4. Verifying updated key...")
if let readKey = readApiKey() {
    if readKey == updatedKey {
        print("   Updated key verified: \(readKey)")
    } else {
        print("   ERROR: Updated key doesn't match!")
        exit(1)
    }
} else {
    print("   Failed to read updated key")
    exit(1)
}

// Test 5: Delete the API key
print("\n5. Testing deleteApiKey...")
if deleteApiKey() {
    print("   Successfully deleted API key")
} else {
    print("   Failed to delete API key")
    exit(1)
}

// Test 6: Verify deletion
print("\n6. Verifying deletion...")
if let readKey = readApiKey() {
    print("   ERROR: Key still exists after deletion: \(readKey)")
    exit(1)
} else {
    print("   Key successfully deleted")
}

print("\nAll tests passed!")

// MARK: - Helper Functions (simplified versions of KeychainHelper)

private let serviceName = "com.desktoppet.app"
private let apiAccount = "ai_api_key"

private func saveApiKey(_ key: String) -> Bool {
    do {
        try save(service: serviceName, account: apiAccount, value: key)
        return true
    } catch {
        print("Error saving: \(error)")
        return false
    }
}

private func readApiKey() -> String? {
    do {
        return try read(service: serviceName, account: apiAccount)
    } catch {
        return nil
    }
}

private func deleteApiKey() -> Bool {
    do {
        try delete(service: serviceName, account: apiAccount)
        return true
    } catch {
        print("Error deleting: \(error)")
        return false
    }
}

private func save(service: String, account: String, value: String) throws {
    let data = value.data(using: .utf8)!

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
        throw NSError(domain: "KeychainError", code: Int(status))
    }
}

private func read(service: String, account: String) throws -> String {
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
        throw NSError(domain: "KeychainError", code: Int(status))
    }

    guard status == errSecSuccess,
          let resultDict = result as? [String: Any],
          let data = resultDict[kSecValueData as String] as? Data,
          let string = String(data: data, encoding: .utf8) else {
        throw NSError(domain: "KeychainError", code: Int(status))
    }

    return string
}

private func delete(service: String, account: String) throws {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: service,
        kSecAttrAccount as String: account
    ]

    let status = SecItemDelete(query as CFDictionary)

    guard status == errSecSuccess || status == errSecItemNotFound else {
        throw NSError(domain: "KeychainError", code: Int(status))
    }
}
