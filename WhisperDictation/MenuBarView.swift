//
//  MenuBarView.swift
//  WhisperDictation
//
//  SwiftUI view for the menu bar contents.
//

import SwiftUI

struct MenuBarView: View {
    @StateObject private var viewModel: MenuBarViewModel

    init(viewModel: MenuBarViewModel = MenuBarViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
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
                viewModel.quitApp()
            }
            .keyboardShortcut("q", modifiers: .command)
        }
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
            Label {
                Text(viewModel.selectedMicrophoneName)
            } icon: {
                Image(systemName: "mic.fill")
            }
        }
    }
}

private struct HistoryRowView: View {
    let item: TranscriptionHistoryStore.Item
    let copyAction: () -> Void
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
                copyAction()
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
