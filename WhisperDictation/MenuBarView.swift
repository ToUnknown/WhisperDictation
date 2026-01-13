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
            // Статус
            statusSection

            Divider()
                .padding(.vertical, 4)

            // Вибір мікрофона
            microphoneSection

            Divider()
                .padding(.vertical, 4)

            // Історія
            historySection

            Divider()
                .padding(.vertical, 4)

            // Налаштування
            SettingsLink {
                HStack {
                    Text("Settings...")
                    Spacer()
                    Text("⌘,")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Divider()
                .padding(.vertical, 4)

            // Вихід
            Button {
                viewModel.quitApp()
            } label: {
                HStack {
                    Text("Quit WhisperDictation")
                    Spacer()
                    Text("⌘Q")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("History")
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 8)

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
        .padding(.vertical, 4)
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
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }
}

private struct HistoryRowView: View {
    let item: TranscriptionHistoryStore.Item
    let copyAction: () -> Void
    @State private var isHovered = false

    private let copyButtonWidth: CGFloat = 28

    var body: some View {
        Button(action: copyAction) {
            HStack(spacing: 6) {
                Text(item.text)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Always reserve space for the copy button
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .frame(width: copyButtonWidth, height: 20)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.accentColor.opacity(isHovered ? 1 : 0))
                    )
                    .foregroundColor(isHovered ? .white : .clear)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
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
