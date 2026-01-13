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
            Text("Copy your OpenAI API key and click the button below to paste it. You can get one at platform.openai.com")
                .font(.caption)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            
            // Current key display
            if viewModel.hasStoredKey {
                HStack {
                    Text(viewModel.maskedKey)
                        .font(.system(.body, design: .monospaced))
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Button {
                        viewModel.clearKey()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Remove API key")
                }
                .padding(10)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            // Paste button
            Button {
                viewModel.pasteKeyFromClipboard()
            } label: {
                HStack {
                    Image(systemName: "doc.on.clipboard")
                    Text(viewModel.hasStoredKey ? "Paste New Key from Clipboard" : "Paste Key from Clipboard")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            // Status
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

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Open WhisperDictation at login", isOn: Binding(
                    get: { viewModel.launchAtLoginEnabled },
                    set: { viewModel.setLaunchAtLoginEnabled($0) }
                ))
                .toggleStyle(.switch)

                Text("Launch the app automatically when you sign in.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(20)
        .frame(width: 340)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showSavedMessage)
        .alert("Login Item Error", isPresented: Binding(
            get: { viewModel.launchAtLoginErrorMessage != nil },
            set: { if !$0 { viewModel.launchAtLoginErrorMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.launchAtLoginErrorMessage ?? "Unable to update login item.")
        }
        .background(WindowAccessor())
    }
}

// MARK: - Window Accessor

private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            configureWindow(for: view, coordinator: context.coordinator)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func configureWindow(for view: NSView, coordinator: Coordinator) {
        guard let window = view.window else { return }
        
        // Set window to float above all other windows
        window.level = .floating
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
        window.delegate = coordinator
        
        // Activate the app and bring window to front
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        
        // Center the window on screen
        window.center()
    }

    final class Coordinator: NSObject, NSWindowDelegate {
        func windowWillClose(_ notification: Notification) {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
