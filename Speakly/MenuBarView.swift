//
//  MenuBarView.swift
//  WhisperDictation
//
//  SwiftUI view for the menu bar contents.
//

import SwiftUI

struct MenuBarView: View {
    @StateObject private var viewModel: MenuBarViewModel
    private let menuWidth: CGFloat = 260

    init(viewModel: MenuBarViewModel = MenuBarViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Status
            statusSection
            
            Divider()
                .padding(.bottom, 2)
                .padding(.top, 6)
        
            // History
            historySection
                .padding(.vertical, 4)
            
            Divider()
                .padding(.bottom, 4)
            
            // Microphone selection
            microphoneSection

            Divider()
                .padding(.vertical, 4)

            // Translation hint (shown above Settings)
            if viewModel.shouldShowTranslationHint {
                TranslationHintBanner {
                    viewModel.dismissTranslationHint()
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
            
            // Settings
            SettingsLink {
                HStack {
                    Image(systemName: "gear")
                    Text("Settings")
                        .lineLimit(1)
                        .truncationMode(.tail)
                        
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            
            Divider()
                .padding(.vertical, 4)

            // Quit
            Button {
                viewModel.quitApp()
            } label: {
                HStack {
                    Text("Quit Speakly")
                    Spacer()
                    Image(systemName: "xmark")
                        .padding(.trailing, 12)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                }
            }
            .buttonStyle(.plain)
            .padding(.leading, 12)
            .padding(.top, 4)
            .padding(.bottom, 2)
        }
        .frame(width: menuWidth)
        .padding(.vertical, 8)
        .background(MenuBarWindowAccessor())
    }

    // MARK: - Status Section

    @ViewBuilder
    private var statusSection: some View {
        HStack {
            Circle()
                .fill(viewModel.hasValidKey ? .green : .orange)
                .frame(width: 8, height: 8)
                .padding(.leading, 4)

            Text(viewModel.hasValidKey ? "Ready" : "API Key Required")
                .font(.caption)

            Spacer(minLength: 8)

            Text("⌥")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.secondary.opacity(0.15))
                .cornerRadius(4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: "book.pages")
                    .padding(.leading, 10)
                    .padding(.bottom, 2)
                    .font(.body)
                Text("History")
                    .font(.body)
                    .fontWeight(.semibold)
                    .padding(.bottom, 2)
            }
            
            if viewModel.historyItems.isEmpty {
                Text("No transcriptions yet")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
            } else {
                ForEach(viewModel.historyItems) { item in
                    HistoryRowView(item: item) {
                        viewModel.copyToPasteboard(text: item.text)
                    }
                }
            }
        }
    }

    // MARK: - Microphone Section

    private var microphoneSection: some View {
        Menu {
            ForEach(viewModel.availableDevices) { device in
                Button {
                    viewModel.selectDevice(device)
                } label: {
                    HStack {
                        if device.uid == viewModel.selectedDeviceUID {
                            Image(systemName: "checkmark")
                        }
                        Text(device.name)
                    }
                }
            }

            if viewModel.availableDevices.isEmpty {
                Text("No microphones found")
                    .foregroundColor(.secondary)
            }

            Divider()

            Button("Refresh Devices") {
                viewModel.refreshDevices()
            }
        } label: {
            HStack {
                Image(systemName: "mic.fill")
                Text(viewModel.selectedMicrophoneName)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .padding(.leading, 2)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.trailing, 4)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
}

private struct HistoryRowView: View {
    let item: TranscriptionHistoryStore.Item
    let copyAction: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: copyAction) {
            HStack(spacing: 4) {
                Text(item.text)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "doc.on.doc")
                    .font(.system(size: 9))
                    .foregroundColor(isHovered ? .primary : .clear)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 1)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Translation Hint Banner

private struct TranslationHintBanner: View {
    let onDismiss: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "globe")
                    .font(.caption)
                    .foregroundColor(.blue)
                Text("Auto Translation Available")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            Text("Enable in Settings to translate speech to your keyboard language.")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
    }
}

// MARK: - Menu Bar Window Accessor

private struct MenuBarWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.setupMonitors(for: view)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator {
        private var clickMonitor: Any?
        private var appDeactivationObserver: NSObjectProtocol?
        private weak var window: NSWindow?
        
        func setupMonitors(for view: NSView) {
            guard let window = view.window else { return }
            self.window = window
            
            // Monitor for clicks outside the window
            clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                self?.closeWindow()
            }
            
            // Monitor for app deactivation (switching to another app)
            appDeactivationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.closeWindow()
            }
        }
        
        private func closeWindow() {
            window?.close()
        }
        
        deinit {
            if let monitor = clickMonitor {
                NSEvent.removeMonitor(monitor)
            }
            if let observer = appDeactivationObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }
    }
}
