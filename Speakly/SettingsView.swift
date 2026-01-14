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
        Form {
            // MARK: - API Key Section
            Section {
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
                }
                
                // Paste button
                Button {
                    viewModel.pasteKeyFromClipboard()
                } label: {
                    HStack {
                        Image(systemName: "doc.on.clipboard")
                        Text(viewModel.hasStoredKey ? "Paste New Key" : "Paste Key from Clipboard")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                
                // Status
                HStack(spacing: 6) {
                    if viewModel.showSavedMessage {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Saved!")
                            .foregroundColor(.green)
                            .font(.caption)
                    } else {
                        Circle()
                            .fill(viewModel.hasValidKey ? .green : .orange)
                            .frame(width: 8, height: 8)
                        Text(viewModel.hasValidKey ? "API key configured" : "API key not set")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Label("OpenAI API Key", systemImage: "key.fill")
            } footer: {
                Text("Copy your API key and click the button to paste it. Get one at [platform.openai.com](https://platform.openai.com)")
            }
            
            // MARK: - Translation Section
            Section {
                Toggle("Translate to Keyboard Language", isOn: $viewModel.autoTranslateEnabled)
            } header: {
                Label("Translation", systemImage: "globe")
            } footer: {
                Text("When enabled, spoken audio will be automatically translated to your current keyboard language (\(viewModel.keyboardLanguageDisplayName)). The app detects what language you're speaking and translates it.")
            }
            
            // MARK: - General Section
            Section {
                Toggle("Open at Login", isOn: Binding(
                    get: { viewModel.launchAtLoginEnabled },
                    set: { viewModel.setLaunchAtLoginEnabled($0) }
                ))
            } header: {
                Label("General", systemImage: "gear")
            } footer: {
                Text("Launch WhisperDictation automatically when you sign in.")
            }
            
            // MARK: - Tips & Popovers
            Section {
                Button {
                    viewModel.resetPopovers()
                } label: {
                    HStack {
                        Image(systemName: "arrow.counterclockwise")
                        Text("Reset Popovers")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
            } header: {
                Label("Tips & Popovers", systemImage: "lightbulb")
            } footer: {
                Text("Show tip popovers again the next time you open the menu.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 420)
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
