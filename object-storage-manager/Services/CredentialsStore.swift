//
//  CredentialsStore.swift
//  object-storage-manager
//
//  Created by Codex on 2024/11/28.
//

import Foundation
import Security

struct StorageCredentials {
    let accessKey: String
    let secretKey: String
}

/// Wraps Keychain access for storing credentials tied to a StorageSource.
final class CredentialsStore {
    private let service = "object-storage-manager.credentials"

    func save(credentials: StorageCredentials, for reference: String) throws {
        let key = reference
        let payload = ["accessKey": credentials.accessKey, "secretKey": credentials.secretKey]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [])

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]

        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlock
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw NSError(domain: NSOSStatusErrorDomain, code: Int(addStatus))
            }
        } else if status != errSecSuccess {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    func load(for reference: String) throws -> StorageCredentials {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: reference,
            kSecReturnData: kCFBooleanTrue as Any,
            kSecMatchLimit: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }

        guard
            let data = item as? Data,
            let json = try JSONSerialization.jsonObject(with: data) as? [String: String],
            let accessKey = json["accessKey"],
            let secretKey = json["secretKey"]
        else {
            throw NSError(domain: "CredentialsStore", code: -1, userInfo: [NSLocalizedDescriptionKey: "Malformed credentials payload"])
        }

        return StorageCredentials(accessKey: accessKey, secretKey: secretKey)
    }

    func delete(for reference: String) {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: reference
        ]
        SecItemDelete(query as CFDictionary)
    }
}
