//
//  APIKeyStore.swift
//  WhisperDictation
//
//  Сервіс для зберігання API ключа OpenAI.
//  Поточна реалізація використовує UserDefaults, але легко замінюється на Keychain.
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
    
    private init() {
        self.apiKey = load()
    }
    
    func save(key: String?) {
        if let key = key, !key.isEmpty {
            UserDefaults.standard.set(key, forKey: storageKey)
        } else {
            UserDefaults.standard.removeObject(forKey: storageKey)
        }
    }
    
    func load() -> String? {
        UserDefaults.standard.string(forKey: storageKey)
    }
    
    var hasValidKey: Bool {
        guard let key = apiKey else { return false }
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedKey.isEmpty && isValidAPIKeyFormat(trimmedKey)
    }
    
    /// Validates that the API key has a reasonable format (non-empty, minimum length).
    func isValidAPIKeyFormat(_ key: String) -> Bool {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let minimumLength = 10
        return trimmedKey.count >= minimumLength
    }
}
