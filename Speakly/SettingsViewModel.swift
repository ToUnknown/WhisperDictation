//
//  SettingsViewModel.swift
//  WhisperDictation
//
//  ViewModel for settings screen.
//

import AppKit
import Combine
import Foundation
import ServiceManagement
import SwiftUI

final class SettingsViewModel: ObservableObject {
    @Published var showSavedMessage: Bool = false
    @Published private(set) var hasValidKey: Bool = false
    @Published private(set) var hasStoredKey: Bool = false
    @Published private(set) var maskedKey: String = ""
    @Published var launchAtLoginEnabled: Bool = false
    @Published var launchAtLoginErrorMessage: String? = nil
    
    // Translation settings
    @AppStorage("autoTranslateEnabled") var autoTranslateEnabled: Bool = false
    @AppStorage("hasSeenTranslationHint") private var hasSeenTranslationHint: Bool = false
    
    /// Returns the current keyboard language display name (e.g., "English", "Українська")
    var keyboardLanguageDisplayName: String {
        KeyboardLanguageProvider.currentLanguageDisplayName()
    }

    private let store: APIKeyStore
    
    init(store: APIKeyStore = .shared) {
        self.store = store
        bindStore()
        updateMaskedKey()
        updateLaunchAtLoginStatus()
    }

    func pasteKeyFromClipboard() {
        guard let clipboardString = NSPasteboard.general.string(forType: .string) else {
            return
        }
        
        let key = clipboardString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        
        store.apiKey = key
        updateMaskedKey()
        showSaveConfirmation()
    }

    func clearKey() {
        store.apiKey = nil
        updateMaskedKey()
        showSaveConfirmation()
    }

    func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginEnabled = isEnabled
        } catch {
            updateLaunchAtLoginStatus()
            launchAtLoginErrorMessage = "Unable to update login item. Please try again."
        }
    }

    func resetPopovers() {
        hasSeenTranslationHint = false
    }

    private func updateMaskedKey() {
        guard let key = store.apiKey, !key.isEmpty else {
            maskedKey = ""
            return
        }
        
        // Show first 7 chars (sk-...) and last 4 chars, mask the rest
        if key.count > 12 {
            let prefix = String(key.prefix(7))
            let suffix = String(key.suffix(4))
            maskedKey = "\(prefix)•••••••••\(suffix)"
        } else {
            maskedKey = String(repeating: "•", count: key.count)
        }
    }

    private func showSaveConfirmation() {
        showSavedMessage = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.showSavedMessage = false
        }
    }

    private func bindStore() {
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
        
        store.$apiKey
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.updateMaskedKey()
            }
            .store(in: &cancellables)
    }

    private func updateLaunchAtLoginStatus() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }
    
    private var cancellables = Set<AnyCancellable>()
}
