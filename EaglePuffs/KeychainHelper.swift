//
//  KeychainHelper.swift
//  EaglePuffs
//
//  Created by Harpreet Athwal on 6/1/25.
//

import Foundation
import Security

func saveCredentialsToKeychain(email: String, password: String) {
    let credentials = "\(email):\(password)"
    let credentialsData = credentials.data(using: .utf8)!
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.yourapp.eaglepuffs",
        kSecAttrAccount as String: "userCredentials",
        kSecValueData as String: credentialsData,
        kSecAttrAccessible as String: kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly
    ]
    SecItemDelete(query as CFDictionary)
    SecItemAdd(query as CFDictionary, nil)
}

func retrieveCredentialsFromKeychain(completion: @escaping (String?, String?) -> Void) {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "com.yourapp.eaglepuffs",
        kSecAttrAccount as String: "userCredentials",
        kSecReturnData as String: true,
        kSecMatchLimit as String: kSecMatchLimitOne
    ]
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecSuccess, let data = item as? Data,
       let credentials = String(data: data, encoding: .utf8),
       let separatorIndex = credentials.firstIndex(of: ":") {
        let email = String(credentials[..<separatorIndex])
        let password = String(credentials[credentials.index(after: separatorIndex)...])
        completion(email, password)
    } else {
        completion(nil, nil)
    }
}
