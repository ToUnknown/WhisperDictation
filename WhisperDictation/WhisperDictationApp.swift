//
//  WhisperDictationApp.swift
//  WhisperDictation
//
//  Точка входу додатка - меню-барний застосунок.
//

import SwiftUI

@main
struct WhisperDictationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var apiKeyStore = APIKeyStore.shared
    @StateObject private var microphoneManager = MicrophoneManager.shared
    
    var body: some Scene {
        // Меню-бар
        MenuBarExtra {
            menuContent
        } label: {
            menuBarIcon
        }
        .menuBarExtraStyle(.menu)
        
        // Вікно налаштувань
        Settings {
            SettingsView()
        }
    }
    
    // MARK: - Menu Bar Icon
    
    private var menuBarIcon: some View {
        Image(systemName: "waveform.circle.fill")
            .symbolRenderingMode(.hierarchical)
    }
    
    // MARK: - Menu Content
    
    private var menuContent: some View {
        Group {
            // Статус
            statusSection
            
            Divider()
            
            // Вибір мікрофона
            microphoneSection
            
            Divider()
            
            // Інструкція
            instructionSection
            
            Divider()
            
            // Налаштування
            SettingsLink {
                Text("Settings...")
            }
            .keyboardShortcut(",", modifiers: .command)
            
            Divider()
            
            // Вихід
            Button("Quit WhisperDictation") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
    
    // MARK: - Status Section
    
    @ViewBuilder
    private var statusSection: some View {
        HStack {
            Circle()
                .fill(apiKeyStore.hasValidKey ? .green : .orange)
                .frame(width: 8, height: 8)
            
            Text(apiKeyStore.hasValidKey ? "Ready" : "API Key Required")
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
    
    // MARK: - Instruction Section
    
    private var instructionSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("How to use:")
                .font(.caption)
                .fontWeight(.semibold)
            
            Text("Hold ⌥ Option to record")
                .font(.caption)
            
            Text("Release to transcribe")
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .foregroundColor(.secondary)
    }
    
    // MARK: - Microphone Section
    
    private var microphoneSection: some View {
        Menu {
            ForEach(microphoneManager.availableDevices) { device in
                Button {
                    microphoneManager.selectDevice(device)
                } label: {
                    HStack {
                        if device.uid == microphoneManager.selectedDeviceUID {
                            Image(systemName: "checkmark")
                        }
                        Text(device.name)
                    }
                }
            }
            
            if microphoneManager.availableDevices.isEmpty {
                Text("No microphones found")
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            Button("Refresh Devices") {
                microphoneManager.refreshDevices()
            }
        } label: {
            Label {
                Text(selectedMicrophoneName)
            } icon: {
                Image(systemName: "mic.fill")
            }
        }
    }
    
    private var selectedMicrophoneName: String {
        if let device = microphoneManager.selectedDevice {
            return device.name
        }
        return "Select Microphone"
    }
}
