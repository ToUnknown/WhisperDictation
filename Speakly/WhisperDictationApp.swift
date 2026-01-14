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
    
    var body: some Scene {
        // Меню-бар
        MenuBarExtra {
            MenuBarView()
        } label: {
            menuBarIcon
        }
        .menuBarExtraStyle(.window)
        
        // Вікно налаштувань
        Settings {
            SettingsView()
        }
    }
    
    // MARK: - Menu Bar Icon
    
    private var menuBarIcon: some View {
        Image(systemName: "message.badge.waveform.fill")
            .symbolRenderingMode(.hierarchical)
    }
    
}
