//
//  SettingsView.swift
//  WhisperDictation
//
//  SwiftUI View для налаштування API ключа.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject private var store = APIKeyStore.shared
    @State private var tempKey: String = ""
    @State private var showKey: Bool = false
    @State private var showSavedMessage: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Заголовок
            HStack {
                Image(systemName: "key.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("OpenAI API Key")
                    .font(.headline)
            }
            
            // Опис
            Text("Enter your OpenAI API key to enable voice transcription. You can get one at platform.openai.com")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Поле вводу
            HStack {
                Group {
                    if showKey {
                        TextField("sk-...", text: $tempKey)
                    } else {
                        SecureField("sk-...", text: $tempKey)
                    }
                }
                .textFieldStyle(.roundedBorder)
                
                Button {
                    showKey.toggle()
                } label: {
                    Image(systemName: showKey ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help(showKey ? "Hide key" : "Show key")
            }
            
            // Кнопки
            HStack {
                if showSavedMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Saved!")
                            .foregroundColor(.green)
                    }
                    .font(.caption)
                    .transition(.opacity)
                }
                
                Spacer()
                
                Button("Clear") {
                    tempKey = ""
                    store.apiKey = nil
                    showSaveConfirmation()
                }
                .disabled(tempKey.isEmpty && store.apiKey == nil)
                
                Button("Save") {
                    saveKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(tempKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            // Статус
            if store.hasValidKey {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.green)
                        .frame(width: 8, height: 8)
                    Text("API key is configured")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.orange)
                        .frame(width: 8, height: 8)
                    Text("API key not set")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear {
            tempKey = store.apiKey ?? ""
        }
        .animation(.easeInOut(duration: 0.2), value: showSavedMessage)
    }
    
    // MARK: - Actions
    
    private func saveKey() {
        let key = tempKey.trimmingCharacters(in: .whitespacesAndNewlines)
        store.apiKey = key.isEmpty ? nil : key
        showSaveConfirmation()
    }
    
    private func showSaveConfirmation() {
        showSavedMessage = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            showSavedMessage = false
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}


