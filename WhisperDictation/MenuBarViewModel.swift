//
//  MenuBarViewModel.swift
//  WhisperDictation
//
//  ViewModel for menu bar content.
//

import AppKit
import Combine
import Foundation

final class MenuBarViewModel: ObservableObject {
    @Published private(set) var hasValidKey: Bool
    @Published private(set) var availableDevices: [AudioInputDevice]
    @Published private(set) var selectedDeviceUID: String
    @Published private(set) var historyItems: [TranscriptionHistoryStore.Item]

    private let apiKeyStore: APIKeyStore
    private let microphoneManager: MicrophoneManager
    private let historyStore: TranscriptionHistoryStore

    init(
        apiKeyStore: APIKeyStore = .shared,
        microphoneManager: MicrophoneManager = .shared,
        historyStore: TranscriptionHistoryStore = .shared
    ) {
        self.apiKeyStore = apiKeyStore
        self.microphoneManager = microphoneManager
        self.historyStore = historyStore
        self.hasValidKey = apiKeyStore.hasValidKey
        self.availableDevices = microphoneManager.availableDevices
        self.selectedDeviceUID = microphoneManager.selectedDeviceUID
        self.historyItems = historyStore.items

        bindStores()
    }

    var selectedMicrophoneName: String {
        guard selectedDeviceUID != AudioInputDevice.systemDefault.uid else {
            return AudioInputDevice.systemDefault.name
        }
        return availableDevices.first(where: { $0.uid == selectedDeviceUID })?.name
            ?? "Select Microphone"
    }

    func selectDevice(_ device: AudioInputDevice) {
        microphoneManager.selectDevice(device)
    }

    func refreshDevices() {
        microphoneManager.refreshDevices()
    }

    func copyToPasteboard(text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func bindStores() {
        apiKeyStore.$apiKey
            .map { [weak apiKeyStore] key in
                guard let apiKeyStore else { return false }
                guard let key else { return false }
                return apiKeyStore.isValidAPIKeyFormat(key)
            }
            .receive(on: DispatchQueue.main)
            .assign(to: &$hasValidKey)

        microphoneManager.$availableDevices
            .receive(on: DispatchQueue.main)
            .assign(to: &$availableDevices)

        microphoneManager.$selectedDeviceUID
            .receive(on: DispatchQueue.main)
            .assign(to: &$selectedDeviceUID)

        historyStore.$items
            .receive(on: DispatchQueue.main)
            .assign(to: &$historyItems)
    }
}
