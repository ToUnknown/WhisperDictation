//
//  SettingsViewModel.swift
//  WhisperDictation
//
//  ViewModel for settings screen.
//

import Combine
import Foundation

final class SettingsViewModel: ObservableObject {
    @Published var tempKey: String = ""
    @Published var showKey: Bool = false
    @Published var showSavedMessage: Bool = false
    @Published private(set) var hasValidKey: Bool = false
    @Published private(set) var hasStoredKey: Bool = false

    private let store: APIKeyStore
    init(store: APIKeyStore = .shared) {
        self.store = store
        bindStore()
        tempKey = store.apiKey ?? ""
        hasValidKey = store.hasValidKey
    }

    func saveKey() {
        let key = tempKey.trimmingCharacters(in: .whitespacesAndNewlines)
        store.apiKey = key.isEmpty ? nil : key
        showSaveConfirmation()
    }

    func clearKey() {
        tempKey = ""
        store.apiKey = nil
        showSaveConfirmation()
    }

    private func showSaveConfirmation() {
        showSavedMessage = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showSavedMessage = false
        }
    }

    private func bindStore() {
        store.$apiKey
            .map { $0 ?? "" }
            .receive(on: DispatchQueue.main)
            .assign(to: &$tempKey)

        store.$apiKey
            .map { $0 != nil }
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasStoredKey)

        store.$apiKey
            .map { [weak store] key in
                guard let store else { return false }
                guard let key else { return false }
                return store.isValidAPIKeyFormat(key)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasValidKey)
    }
}
