//
//  SettingsView.swift
//  WhisperDictation
//
//  SwiftUI View для налаштування API ключа.
//

import SwiftUI

struct SettingsView: View {
    @StateObject private var viewModel: SettingsViewModel

    init(viewModel: SettingsViewModel = SettingsViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
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
                    if viewModel.showKey {
                        TextField("sk-...", text: $viewModel.tempKey)
                    } else {
                        SecureField("sk-...", text: $viewModel.tempKey)
                    }
                }
                .textFieldStyle(.roundedBorder)
                
                Button {
                    viewModel.showKey.toggle()
                } label: {
                    Image(systemName: viewModel.showKey ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
                .help(viewModel.showKey ? "Hide key" : "Show key")
            }
            
            // Кнопки
            HStack {
                if viewModel.showSavedMessage {
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
                    viewModel.clearKey()
                }
                .disabled(viewModel.tempKey.isEmpty && !viewModel.hasStoredKey)
                
                Button("Save") {
                    viewModel.saveKey()
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.tempKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            
            // Статус
            if viewModel.hasValidKey {
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
        .animation(.easeInOut(duration: 0.2), value: viewModel.showSavedMessage)
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
