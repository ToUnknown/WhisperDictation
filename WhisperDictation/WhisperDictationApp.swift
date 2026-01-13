//
//  WhisperDictationApp.swift
//  WhisperDictation
//
//  Точка входу додатка - меню-барний застосунок.
//

import SwiftUI
import AppKit

@main
struct WhisperDictationApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var apiKeyStore = APIKeyStore.shared
    @StateObject private var microphoneManager = MicrophoneManager.shared
    @StateObject private var historyStore = TranscriptionHistoryStore.shared
    
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
            
            // Історія
            historySection
            
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
    
    // MARK: - History Section
    
    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("History")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)
            
            if historyStore.items.isEmpty {
                Text("No transcriptions yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            } else {
                ForEach(historyStore.items) { item in
                    HistoryRowView(item: item)
                }
            }
        }
        .padding(.vertical, 4)
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

private struct HistoryRowView: View {
    let item: TranscriptionHistoryStore.Item
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 8) {
            Text(item.text)
                .font(.caption)
                .lineLimit(isHovered ? 5 : 1)
                .truncationMode(.tail)
                .animation(.easeInOut(duration: 0.2), value: isHovered)
            
            Spacer(minLength: 8)
            
            Button("Copy") {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(item.text, forType: .string)
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .opacity(isHovered ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)
        }
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
