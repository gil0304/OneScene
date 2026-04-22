//
//  OpenAIConfigurationStore.swift
//  OneScene
//
//  Created by Codex on 2026/04/22.
//

import Foundation
import Security

struct OpenAIConfiguration {
    static let defaultModelID = "gpt-4.1-mini"

    let apiKey: String
    let modelID: String
}

final class OpenAIConfigurationStore {
    private let defaults = UserDefaults.standard
    private let keychain = KeychainSecretStore(service: "app.Ochiai.gil.OneScene.openai")
    private let modelKey = "onescene.openai.model"
    private let apiKeyAccount = "openai_api_key"

    var savedModelID: String {
        let saved = defaults.string(forKey: modelKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return saved?.isEmpty == false ? saved! : OpenAIConfiguration.defaultModelID
    }

    var hasSavedAPIKey: Bool {
        guard let key = try? keychain.load(account: apiKeyAccount) else {
            return false
        }

        return !key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func loadConfiguration() throws -> OpenAIConfiguration {
        guard let apiKey = try keychain.load(account: apiKeyAccount)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !apiKey.isEmpty else {
            throw OpenAIStoryGenerationError.missingAPIKey
        }

        return OpenAIConfiguration(apiKey: apiKey, modelID: savedModelID)
    }

    func loadSavedAPIKey() -> String {
        (try? keychain.load(account: apiKeyAccount)) ?? ""
    }

    func save(apiKey: String, modelID: String) throws {
        let normalizedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedModel = modelID.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedKey.isEmpty else {
            throw OpenAIStoryGenerationError.missingAPIKey
        }

        try keychain.save(normalizedKey, account: apiKeyAccount)
        defaults.set(normalizedModel.isEmpty ? OpenAIConfiguration.defaultModelID : normalizedModel, forKey: modelKey)
    }

    func clear() throws {
        try keychain.delete(account: apiKeyAccount)
        defaults.removeObject(forKey: modelKey)
    }
}

private final class KeychainSecretStore {
    private let service: String

    init(service: String) {
        self.service = service
    }

    func save(_ value: String, account: String) throws {
        let encoded = Data(value.utf8)
        let baseQuery = query(account: account)

        let attributes: [CFString: Any] = [
            kSecValueData: encoded
        ]

        let status: OSStatus

        if try load(account: account) != nil {
            status = SecItemUpdate(baseQuery as CFDictionary, attributes as CFDictionary)
        } else {
            var addQuery = baseQuery
            addQuery[kSecValueData] = encoded
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }

        guard status == errSecSuccess else {
            throw KeychainStoreError.unhandledStatus(status)
        }
    }

    func load(account: String) throws -> String? {
        var lookup = query(account: account)
        lookup[kSecMatchLimit] = kSecMatchLimitOne
        lookup[kSecReturnData] = kCFBooleanTrue

        var item: CFTypeRef?
        let status = SecItemCopyMatching(lookup as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            guard let data = item as? Data,
                  let value = String(data: data, encoding: .utf8) else {
                throw KeychainStoreError.invalidData
            }

            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainStoreError.unhandledStatus(status)
        }
    }

    func delete(account: String) throws {
        let status = SecItemDelete(query(account: account) as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainStoreError.unhandledStatus(status)
        }
    }

    private func query(account: String) -> [CFString: Any] {
        [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account
        ]
    }
}

private enum KeychainStoreError: Error {
    case invalidData
    case unhandledStatus(OSStatus)
}
