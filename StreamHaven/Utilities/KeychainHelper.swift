import Foundation
import Security

/// A helper class for securely storing and retrieving data from the Keychain.
public class KeychainHelper {

    /// Saves a password to the Keychain.
    ///
    /// - Parameters:
    ///   - password: The password to save.
    ///   - account: The account to associate the password with.
    ///   - service: The service to associate the password with.
    public static func savePassword(password: String, for account: String, service: String) {
        let passwordData = password.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: passwordData
        ]

        let status = SecItemAdd(query as CFDictionary, nil)

        if status == errSecDuplicateItem {
            // Item already exists, update it
            let updateQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]

            let attributesToUpdate: [String: Any] = [
                kSecValueData as String: passwordData
            ]

            SecItemUpdate(updateQuery as CFDictionary, attributesToUpdate as CFDictionary)
        }
    }

    /// Retrieves a password from the Keychain.
    ///
    /// - Parameters:
    ///   - account: The account associated with the password.
    ///   - service: The service associated with the password.
    /// - Returns: The password, or `nil` if it is not found.
    public static func getPassword(for account: String, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess, let data = item as? Data else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// Deletes a password from the Keychain.
    ///
    /// - Parameters:
    ///   - account: The account associated with the password.
    ///   - service: The service associated with the password.
    public static func deletePassword(for account: String, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}
