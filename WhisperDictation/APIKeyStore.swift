//
//  APIKeyStore.swift
//  WhisperDictation
//
//  Сервіс для зберігання API ключа OpenAI.
//  Поточна реалізація використовує Keychain.
//

import Foundation
import SwiftUI
import Combine

// MARK: - Protocol

protocol APIKeyStoring {
    func save(key: String?)
    func load() -> String?
}

// MARK: - Implementation

final class APIKeyStore: APIKeyStoring, ObservableObject {
    static let shared = APIKeyStore()
    
    @Published var apiKey: String? {
        didSet {
            save(key: apiKey)
        }
    }
    
    private let storageKey = "OpenAI_API_Key"
    private let keychainService = "com.whisperdictation.apiKey"
    private lazy var keychainStore = KeychainStore(service: keychainService)
    
    private init() {
        migrateUserDefaultsIfNeeded()
        self.apiKey = load()
    }
    
    func save(key: String?) {
        if let key = key, !key.isEmpty {
            keychainStore.save(key, account: storageKey)
        } else {
            keychainStore.delete(account: storageKey)
        }
    }
    
    func load() -> String? {
        keychainStore.read(account: storageKey)
    }
    
    var hasValidKey: Bool {
        guard let key = apiKey else { return false }
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedKey.isEmpty && isValidAPIKeyFormat(trimmedKey)
    }
    
    /// Validates that the API key has the correct format (starts with "sk-")
    func isValidAPIKeyFormat(_ key: String) -> Bool {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedKey.hasPrefix("sk-") && trimmedKey.count > 10
    }
    
    private func migrateUserDefaultsIfNeeded() {
        guard keychainStore.read(account: storageKey) == nil else { return }
        guard let legacyKey = UserDefaults.standard.string(forKey: storageKey) else { return }
        save(key: legacyKey)
        UserDefaults.standard.removeObject(forKey: storageKey)
    }
}
